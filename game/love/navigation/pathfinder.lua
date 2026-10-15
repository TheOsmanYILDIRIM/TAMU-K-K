-- Finite deterministic 8-neighbor A*; diagonals cannot cut blocked corners.
local C=require('physics.collision')
local W=require('physics.world_query')
local P={}
local dirs={{0,-1},{-1,0},{1,0},{0,1},{-1,-1},{1,-1},{-1,1},{1,1}}
local function key(x,y) return x..','..y end
local function heuristic(x,y,ex,ey)
  local a,b=math.abs(x-ex),math.abs(y-ey)
  return math.max(a,b)+(math.sqrt(2)-1)*math.min(a,b)
end
function P.find(query,sx,sy,gx,gy,r,cell,max_nodes)
  W.assert_query(query)
  cell=cell or 16;max_nodes=max_nodes or 2048
  assert(W.finite(cell) and cell>0 and W.finite(r) and r>=0 and
    type(max_nodes)=='number' and max_nodes>=1 and max_nodes%1==0)
  local ax,ay=math.floor(sx/cell+.5),math.floor(sy/cell+.5)
  local bx,by=math.floor(gx/cell+.5),math.floor(gy/cell+.5)
  local function free(x,y) return C.can_stand(query,x*cell,y*cell,r) end
  local function clear_edge(x0,y0,x1,y1)
    local sx,sy=x0*cell,y0*cell
    local ex,ey=x1*cell,y1*cell
    local nx,ny,hit=C.move(query,sx,sy,ex-sx,ey-sy,r)
    return not hit and math.abs(nx-ex)<1e-5 and math.abs(ny-ey)<1e-5
  end
  if not C.can_stand(query,sx,sy,r) then return nil,'start_blocked' end
  if not free(ax,ay) then return nil,'start_cell_blocked' end
  -- The real player may stand between grid nodes; its first waypoint must
  -- be reachable by the same swept-footprint physics.
  if ax~=bx or ay~=by then
    local fx,fy,hit=C.move(query,sx,sy,ax*cell-sx,ay*cell-sy,r)
    if hit or math.abs(fx-ax*cell)>1e-5 or math.abs(fy-ay*cell)>1e-5 then
      return nil,'start_connector_blocked'
    end
  end
  if not free(bx,by) then return nil,'goal_blocked' end
  local start=key(ax,ay)
  local nodes={[start]={x=ax,y=ay,g=0,f=heuristic(ax,ay,bx,by)}}
  local open={[start]=true};local closed={};local visited=0
  while true do
    local best,cur
    for k in pairs(open) do
      local n=nodes[k]
      if not cur or n.f<cur.f-1e-9 or
         (math.abs(n.f-cur.f)<=1e-9 and (n.g<cur.g-1e-9 or
         (math.abs(n.g-cur.g)<=1e-9 and k<best))) then best,cur=k,n end
    end
    if not best then return nil,'unreachable' end
    visited=visited+1
    if visited>max_nodes then return nil,'search_limit' end
    if cur.x==bx and cur.y==by then
      local result={}
      while best~=start do
        local n=nodes[best]
        table.insert(result,1,{x=n.x*cell,y=n.y*cell})
        best=n.parent
      end
      return result,nil
    end
    open[best]=nil;closed[best]=true
    for _,d in ipairs(dirs) do
      local x,y=cur.x+d[1],cur.y+d[2]
      local k=key(x,y)
      if not closed[k] and free(x,y) and
        ((d[1]==0 or d[2]==0) or
        (free(cur.x+d[1],cur.y) and free(cur.x,cur.y+d[2])))
        and clear_edge(cur.x,cur.y,x,y) then
        local g=cur.g+((d[1]~=0 and d[2]~=0) and math.sqrt(2) or 1)
        if not nodes[k] or g<nodes[k].g-1e-9 then
          nodes[k]={x=x,y=y,g=g,f=g+heuristic(x,y,bx,by),parent=best}
          open[k]=true
        end
      end
    end
  end
end
return P
