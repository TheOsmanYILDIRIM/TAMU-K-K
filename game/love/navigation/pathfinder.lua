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
local function search(query,sx,sy,gx,gy,r,cell,max_nodes,checkpoint)
  W.assert_query(query)
  cell=cell or 16;max_nodes=max_nodes or 2048
  assert(W.finite(cell) and cell>0 and W.finite(r) and r>=0 and
    type(max_nodes)=='number' and max_nodes>=1 and max_nodes%1==0)
  local ax,ay=math.floor(sx/cell+.5),math.floor(sy/cell+.5)
  local bx,by=math.floor(gx/cell+.5),math.floor(gy/cell+.5)
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
  if not free(bx,by) then return nil,'goal_blocked' end

  local start=key(ax,ay)
  local root={key=start,x=ax,y=ay,g=0,f=heuristic(ax,ay,bx,by)}
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
    if cur.x==bx and cur.y==by then
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
          local f=g+heuristic(x,y,bx,by)
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
function P.begin(query,sx,sy,gx,gy,r,cell,max_nodes)
  local worker=coroutine.create(function()
    return search(query,sx,sy,gx,gy,r,cell,max_nodes,coroutine.yield)
  end)
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
      if coroutine.status(worker)=="dead" then
        return true,result,reason
      end
      if clock()>=end_at then break end
    end
    return false
  end
  return run
end
return P
