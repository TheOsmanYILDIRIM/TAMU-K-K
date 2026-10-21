-- Finite deterministic 8-neighbor A*; diagonals cannot cut blocked corners.
-- Min-heap O(log V) selection replaces a full O(V) open-set scan per step.
-- Walkability is memoized ONLY within a synchronous find; mutable worlds
-- and live Stage5/6 collision rules are never cached between requests.
local C=require('physics.collision')
local W=require('physics.world_query')
local P={}
local dirs={{0,-1},{-1,0},{1,0},{0,1},{-1,-1},{1,-1},{-1,1},{1,1}}
local SQRT2=math.sqrt(2)
local EPS=1e-9
local function key(x,y) return x..','..y end
local function heuristic(x,y,ex,ey)
  local a,b=math.abs(x-ex),math.abs(y-ey)
  return math.max(a,b)+(SQRT2-1)*math.min(a,b)
end

-- Preserve the original A* tie order: f, then g, then lexicographic key.
local function precedes(a,b)
  if a.f<b.f-EPS then return true end
  if math.abs(a.f-b.f)<=EPS then
    return a.g<b.g-EPS or (math.abs(a.g-b.g)<=EPS and a.key<b.key)
  end
  return false
end

local function open_set()
  local heap,position={},{}
  local function rise(i)
    local item=heap[i]
    while i>1 do
      local parent=math.floor(i/2)
      if not precedes(item,heap[parent]) then break end
      heap[i]=heap[parent]
      position[heap[i].key]=i
      i=parent
    end
    heap[i]=item
    position[item.key]=i
  end
  local function put(item)
    local i=#heap+1
    heap[i]=item
    position[item.key]=i
    rise(i)
  end
  local function take()
    local n=#heap
    if n==0 then return nil end
    local best=heap[1]
    position[best.key]=nil
    local last=heap[n]
    heap[n]=nil
    if n>1 then
      local i=1
      while i*2<n do
        local child=i*2
        if child+1<n and precedes(heap[child+1],heap[child]) then
          child=child+1
        end
        if not precedes(heap[child],last) then break end
        heap[i]=heap[child]
        position[heap[i].key]=i
        i=child
      end
      heap[i]=last
      position[last.key]=i
    end
    return best
  end
  return put,take,rise,position
end

-- Production synchronous API stays exact. R2 can drive the same search
-- cooperatively by checkpointing after each collision call.
local function search(query,sx,sy,gx,gy,r,cell,max_nodes,checkpoint,goals)
  W.assert_query(query)
  cell=cell or 16;max_nodes=max_nodes or 2048
  assert(W.finite(cell) and cell>0 and W.finite(r) and r>=0 and
    type(max_nodes)=='number' and max_nodes>=1 and max_nodes%1==0)
  local ax,ay=math.floor(sx/cell+.5),math.floor(sy/cell+.5)
  local bx,by=math.floor(gx/cell+.5),math.floor(gy/cell+.5)
  -- A single A* for any valid approach cell. No shared/world-persistent
  -- walkability state: live obstacles are checked by the normal collision API.
  local target_list,target_keys
  if goals then
    target_list,target_keys={},{}
    for _,goal in ipairs(goals) do
      assert(type(goal)=='table' and W.finite(goal.x) and W.finite(goal.y),
        'invalid approach goal')
      local tx,ty=math.floor(goal.x/cell+.5),math.floor(goal.y/cell+.5)
      local id=key(tx,ty)
      if not target_keys[id] then
        target_list[#target_list+1]={x=tx,y=ty}
        target_keys[id]=true
      end
    end
    assert(#target_list>0 and #target_list<=16,'unsupported approach goal count')
  end
  local function estimate(x,y)
    if not target_list then return heuristic(x,y,bx,by) end
    local best=math.huge
    for _,target in ipairs(target_list) do
      local h=heuristic(x,y,target.x,target.y)
      if h<best then best=h end
    end
    return best
  end
  local function checked_stand(x,y)
    local result=C.can_stand(query,x,y,r)
    if checkpoint then checkpoint() end
    return result
  end
  local function checked_move(x,y,dx,dy)
    local nx,ny,hit=C.move(query,x,y,dx,dy,r)
    if checkpoint then checkpoint() end
    return nx,ny,hit
  end
  local free_cells={}
  local function free(x,y)
    local k=key(x,y)
    local value=free_cells[k]
    if value==nil then
      value=checked_stand(x*cell,y*cell)
      free_cells[k]=value
    end
    return value
  end
  local function clear_edge(x0,y0,x1,y1)
    local startx,starty=x0*cell,y0*cell
    local ex,ey=x1*cell,y1*cell
    local nx,ny,hit=checked_move(startx,starty,ex-startx,ey-starty)
    return not hit and math.abs(nx-ex)<1e-5 and math.abs(ny-ey)<1e-5
  end
  if not checked_stand(sx,sy) then return nil,'start_blocked' end
  if not free(ax,ay) then return nil,'start_cell_blocked' end
  if ax~=bx or ay~=by then
    local fx,fy,hit=checked_move(sx,sy,ax*cell-sx,ay*cell-sy)
    if hit or math.abs(fx-ax*cell)>1e-5 or math.abs(fy-ay*cell)>1e-5 then
      return nil,'start_connector_blocked'
    end
  end
  if not target_list and not free(bx,by) then return nil,'goal_blocked' end

  local start=key(ax,ay)
  local root={key=start,x=ax,y=ay,g=0,f=estimate(ax,ay)}
  local nodes={[start]=root}
  local closed={}
  local put,take,rise,position=open_set()
  put(root)
  local visited=0
  while true do
    local cur=take()
    if not cur then return nil,'unreachable' end
    visited=visited+1
    if visited>max_nodes then return nil,'search_limit' end
    if (target_keys and target_keys[cur.key]) or
      (not target_list and cur.x==bx and cur.y==by) then
      local result={}
      while cur.key~=start do
        result[#result+1]={x=cur.x*cell,y=cur.y*cell}
        cur=nodes[cur.parent]
      end
      for i=1,math.floor(#result/2) do
        local j=#result-i+1
        result[i],result[j]=result[j],result[i]
      end
      return result,nil
    end
    closed[cur.key]=true
    for _,d in ipairs(dirs) do
      local x,y=cur.x+d[1],cur.y+d[2]
      local k=key(x,y)
      if not closed[k] then
        local g=cur.g+((d[1]~=0 and d[2]~=0) and SQRT2 or 1)
        local node=nodes[k]
        -- A candidate that cannot improve g needs no terrain/collision work.
        if (not node or g<node.g-EPS) and free(x,y) and
          ((d[1]==0 or d[2]==0) or
            (free(cur.x+d[1],cur.y) and free(cur.x,cur.y+d[2])))
          and clear_edge(cur.x,cur.y,x,y) then
          local f=g+estimate(x,y)
          if node then
            node.g,node.f,node.parent=g,f,cur.key
            rise(assert(position[k],'an open candidate lost its heap slot'))
          else
            node={key=k,x=x,y=y,g=g,f=f,parent=cur.key}
            nodes[k]=node
            put(node)
          end
        end
      end
    end
  end
end

function P.find(query,sx,sy,gx,gy,r,cell,max_nodes)
  return search(query,sx,sy,gx,gy,r,cell,max_nodes)
end

-- R2-only cooperative search. An individual collision call is not preemptible,
-- but elapsed time and count are bounded between coroutine checkpoints.
local function make_runner(worker)
  local run={}
  function run:step(budget_ms,max_queries)
    assert(coroutine.status(worker)~="dead","completed path search")
    budget_ms=budget_ms or 2
    max_queries=max_queries or 8
    assert(type(budget_ms)=="number" and budget_ms>0 and budget_ms<math.huge)
    assert(type(max_queries)=="number" and max_queries>=1 and
      max_queries%1==0)
    local clock=(love and love.timer and love.timer.getTime) or os.clock
    local end_at=clock()+budget_ms/1000
    for _=1,max_queries do
      local ok,result,reason=coroutine.resume(worker)
      if not ok then error(result,2) end
      if coroutine.status(worker)=="dead" then return true,result,reason end
      if clock()>=end_at then break end
    end
    return false
  end
  return run
end

function P.begin(query,sx,sy,gx,gy,r,cell,max_nodes)
  local worker=coroutine.create(function()
    -- R2-only tap shortcut: prove a clear, short direct line with the same
    -- swept collision primitive as the player. Never speculate through walls.
    -- Limit the sweep rectangle with <=32-unit sections so each R2 topography
    -- query examines a small number of lattice cells.
    local grid=cell or 16
    local tx=math.floor(gx/grid+.5)*grid
    local ty=math.floor(gy/grid+.5)*grid
    local dx,dy=tx-sx,ty-sy
    local length=math.sqrt(dx*dx+dy*dy)
    local start_grid_x=math.floor(sx/grid+.5)*grid
    local start_grid_y=math.floor(sy/grid+.5)*grid
    if length>0 and length<=640 and
       (start_grid_x~=tx or start_grid_y~=ty) then
      local start_ok=C.can_stand(query,sx,sy,r)
      coroutine.yield()
      if start_ok then
        -- Preserve the legacy requirement that the start grid cell is clear.
        local ax,ay=start_grid_x,start_grid_y
        local cell_ok=C.can_stand(query,ax,ay,r)
        coroutine.yield()
        if cell_ok then
          local connector_ok=true
          if ax~=sx or ay~=sy then
            local cx,cy,hit=C.move(query,sx,sy,ax-sx,ay-sy,r)
            connector_ok=not hit and math.abs(cx-ax)<1e-5 and math.abs(cy-ay)<1e-5
            coroutine.yield()
          end
          if connector_ok then
            local goal_ok=C.can_stand(query,tx,ty,r)
            coroutine.yield()
            if goal_ok then
              local n=math.ceil(length/32)
              local previous_x,previous_y=sx,sy
              local clear=true
              for i=1,n do
                local x=sx+dx*i/n
                local y=sy+dy*i/n
                local nx,ny,hit=C.move(query,previous_x,previous_y,
                  x-previous_x,y-previous_y,r)
                coroutine.yield()
                if hit or math.abs(nx-x)>1e-5 or math.abs(ny-y)>1e-5 then
                  clear=false;break
                end
                previous_x,previous_y=x,y
              end
              if clear then return {{x=tx,y=ty}},nil end
            end
          end
        end
      end
    end
    -- If direct travel is blocked, the original deterministic A* searches
    -- exactly as before. Stage5/6 still call unchanged synchronous P.find.
    return search(query,sx,sy,gx,gy,r,cell,max_nodes,coroutine.yield)
  end)
  return make_runner(worker)
end

-- R2-only object interaction. Evaluate all approach points in ONE search,
-- not up to eight independent 1024-node A* searches per tap. A short, live
-- collision-validated approach is tried first. A blocked line falls back to
-- one shared search with admissible minimum-of-goals octile heuristic.
function P.begin_any(query,sx,sy,goals,r,cell,max_nodes)
  W.assert_query(query)
  assert(type(goals)=='table' and #goals>0 and #goals<=16,
    'invalid approach destinations')
  assert(W.finite(sx) and W.finite(sy) and W.finite(r) and r>=0)
  cell=cell or 16
  assert(W.finite(cell) and cell>0)
  local targets={}
  local seen={}
  for i,g in ipairs(goals) do
    assert(type(g)=='table' and W.finite(g.x) and W.finite(g.y),
      'nonfinite approach destination')
    local x=math.floor(g.x/cell+.5)*cell
    local y=math.floor(g.y/cell+.5)*cell
    local k=key(x,y)
    if not seen[k] then
      targets[#targets+1]={x=x,y=y,dist=(x-sx)^2+(y-sy)^2,index=i}
      seen[k]=true
    end
  end
  table.sort(targets,function(a,b)
    if a.dist~=b.dist then return a.dist<b.dist end
    return a.index<b.index
  end)
  local worker=coroutine.create(function()
    -- A 32-unit sweep keeps R2 topography collider bounds small. Yield after
    -- each real collision; the player's own CCD remains authoritative.
    local initial=C.can_stand(query,sx,sy,r)
    coroutine.yield()
    if initial then
      local ax=math.floor(sx/cell+.5)*cell
      local ay=math.floor(sy/cell+.5)*cell
      local start_ok=C.can_stand(query,ax,ay,r)
      coroutine.yield()
      if start_ok then
        local connector=true
        if ax~=sx or ay~=sy then
          local ex,ey,hit=C.move(query,sx,sy,ax-sx,ay-sy,r)
          connector=not hit and math.abs(ex-ax)<1e-5 and math.abs(ey-ay)<1e-5
          coroutine.yield()
        end
        if connector then
          for _,goal in ipairs(targets) do
            local delta_x,delta_y=goal.x-sx,goal.y-sy
            local length=math.sqrt(goal.dist)
            if length<=640 then
              local valid=C.can_stand(query,goal.x,goal.y,r)
              coroutine.yield()
              if valid then
                local n=math.max(1,math.ceil(length/32))
                local px,py=sx,sy
                local clear=true
                for k=1,n do
                  local x=sx+delta_x*k/n
                  local y=sy+delta_y*k/n
                  local ex,ey,hit=C.move(query,px,py,x-px,y-py,r)
                  coroutine.yield()
                  if hit or math.abs(ex-x)>1e-5 or math.abs(ey-y)>1e-5 then
                    clear=false;break
                  end
                  px,py=x,y
                end
                if clear then
                  if length<1e-7 then return {},nil end
                  return {{x=goal.x,y=goal.y}},nil
                end
              end
            end
          end
        end
      end
    end
    return search(query,sx,sy,0,0,r,cell,max_nodes,coroutine.yield,targets)
  end)
  return make_runner(worker)
end
return P
