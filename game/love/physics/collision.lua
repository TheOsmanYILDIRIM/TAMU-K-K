-- Continuous swept AABB for a player with square footprint/radius.
-- Normal + remaining-motion projection yield wall sliding; no point tunneling.
local W = require('physics.world_query')
local M = {}
local EPS = 1e-6
local function hit_rect(x,y,dx,dy,r,rct)
  local l, t = rct.x-r, rct.y-r
  local rr, bb = rct.x+rct.w+r, rct.y+rct.h+r
  local tx0,tx1,ty0,ty1 = -math.huge,math.huge,-math.huge,math.huge
  if dx == 0 then if x<=l or x>=rr then return nil end
  else tx0,tx1=(l-x)/dx,(rr-x)/dx; if tx0>tx1 then tx0,tx1=tx1,tx0 end end
  if dy == 0 then if y<=t or y>=bb then return nil end
  else ty0,ty1=(t-y)/dy,(bb-y)/dy; if ty0>ty1 then ty0,ty1=ty1,ty0 end end
  local entry, exit = math.max(tx0,ty0),math.min(tx1,ty1)
  if entry > exit or exit < 0 or entry > 1 or entry < 0 then return nil end
  local nx,ny=0,0
  if tx0>=ty0 then nx=dx>0 and -1 or 1
  else ny=dy>0 and -1 or 1 end
  return entry,nx,ny
end
function M.can_stand(query,x,y,r)
  assert(W.finite(x) and W.finite(y) and W.finite(r) and r>=0)
  for _,o in ipairs(W.obstacles(query,x-r,y-r,x+r,y+r)) do
    if x+r>o.x and x-r<o.x+o.w and y+r>o.y and y-r<o.y+o.h then
      return false
    end
  end
  return true
end
function M.move(query,x,y,dx,dy,r)
  assert(W.finite(x) and W.finite(y) and W.finite(dx) and W.finite(dy)
    and W.finite(r) and r>=0, 'invalid move')
  assert(M.can_stand(query,x,y,r), 'player starts inside solid terrain')
  local collided = false
  for _=1,3 do
    if math.abs(dx)+math.abs(dy)<EPS then break end
    local minx,miny=math.min(x,x+dx)-r,math.min(y,y+dy)-r
    local maxx,maxy=math.max(x,x+dx)+r,math.max(y,y+dy)+r
    local best,nx,ny=1+EPS,0,0
    for _,o in ipairs(W.obstacles(query,minx,miny,maxx,maxy)) do
      local t,ax,ay=hit_rect(x,y,dx,dy,r,o)
      if t and (t<best-EPS or (math.abs(t-best)<=EPS and ax<nx)) then
        best,nx,ny=t,ax,ay
      end
    end
    if best>1 then x,y=x+dx,y+dy; break end
    collided=true
    local travel=math.max(0,best-EPS)
    x,y=x+dx*travel,y+dy*travel
    local remain=1-travel
    dx,dy=dx*remain,dy*remain
    local into=dx*nx+dy*ny
    if into<0 then dx,dy=dx-into*nx,dy-into*ny end
  end
  return x,y,collided
end
return M
