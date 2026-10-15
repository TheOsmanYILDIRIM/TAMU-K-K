package.path="./?.lua;./?/init.lua;"..package.path
local Query=require("world.world_query")
local Adapter=require("world.collision_adapter")
local Collision=require("physics.collision")
local Controller=require("player.controller")
local Path=require("navigation.pathfinder")
local q=Query.new(20261015)
local a=Adapter.new(q,8)
for _,p in ipairs({{-513,-257},{-256,-256},{0,0},{127,128},{256,-1}}) do
  local first=a:obstacles(p[1],p[2],p[1]+32,p[2]+32)
  local again=a:obstacles(p[1],p[2],p[1]+32,p[2]+32)
  assert(#first==#again,"non-deterministic collision")
end
local ok=pcall(function() a:obstacles(0,0,999999,999999) end)
assert(not ok,"must fail closed on huge query")
local found
for y=-128,128,8 do for x=-128,128,8 do
  if Collision.can_stand(a,x,y,5) then found={x=x,y=y};break end
end if found then break end end
assert(found,"no test spawn")
local p=Controller.new(a,{x=found.x,y=found.y,radius=5})
for _=1,120 do
  p:update(1/60,1,0)
  assert(Collision.can_stand(a,p.x,p.y,5),"player crossed water")
end
local path,reason=Path.find(a,p.x,p.y,p.x,p.y,5,16,128)
assert(path or reason=="goal_blocked",reason or "path failed")
print("WORLD_PLAYER_INTEGRATION_OK",p.x,p.y)

-- Fail-closed / negative-coordinates / chunk-independent collision regression.
local b=Adapter.new(q,8)
local before=a:obstacles(-300,-300,-250,-250)
local after=b:obstacles(-300,-300,-250,-250)
assert(#before==#after,"eviction-independent colliders differ")
local bad=pcall(function() a:obstacles(0/0,0,1,1) end)
assert(not bad,"nonfinite bounds permitted")
for _,r in ipairs(a:obstacles(-128,-128,128,128)) do
  local cx,cy=r.x+r.w*.5,r.y+r.h*.5
  assert(not Collision.can_stand(a,cx,cy,0),"water obstacle did not block")
end
print("WORLD_PLAYER_NEGATIVE_OK")

-- The obstacle cache cannot grow without limit as the camera roams.
local bounded=Adapter.new(q,8)
bounded.max_cache=32
for i=0,120 do bounded:blocked(i,-i) end
assert(bounded.cache_size<=32,"collision cache grew without bound")
-- Ensure A* respects the exact swept-square footprint, not endpoints alone.
local synthetic={obstacles=function(_,x1,y1,x2,y2)
  local wall={x=7,y=-4,w=2,h=8}
  if x1<wall.x+wall.w and x2>wall.x and y1<wall.y+wall.h and y2>wall.y then return {wall} end
  return {}
end}
assert(Collision.can_stand(synthetic,0,0,1) and Collision.can_stand(synthetic,16,0,1))
local sx,sy,hit=Collision.move(synthetic,0,0,16,0,1)
assert(hit and sx<7,"swept wall penetration")
print("WORLD_PLAYER_EDGE_OK")

-- Renderer and collider must consume identical Marching water triangles.
local Marching=require("world.marching")
local synthetic_water={field={channel=function(_,x,y,name)
  assert(name=="water")
  return 15-x  -- vertical shoreline at x=15; crosses a 32-unit cell
end}}
local water_adapter=Adapter.new(synthetic_water,8)
local tris=Marching.build(function(x,y) return synthetic_water.field:channel(x,y,"water") end,0,0,32,32,0).vertices
assert(#tris>0 and #tris%3==0,"missing Marching geometry")
assert(water_adapter:blocked(0,0),"filled water missing collider")
assert(water_adapter:blocked(1,0),"shoreline coverage missing")
assert(not water_adapter:blocked(3,0),"dry region blocked")
assert(water_adapter:blocked(-1,0),"negative coordinate water coverage") 
local twin=Adapter.new(synthetic_water,8)
assert(water_adapter:blocked(1,0)==twin:blocked(1,0),"non deterministic water triangles")
print("WORLD_PLAYER_MARCHING_COLLISION_OK")
-- A* must reject a blocked connector between non-grid start and first grid node.
local thinwall={obstacles=function(_,x1,y1,x2,y2)
  local rect={x=3,y=-2,w=1,h=4}
  if x1<rect.x+rect.w and x2>rect.x and y1<rect.y+rect.h and y2>rect.y then return {rect} end
  return {}
end}
local blocked_path,blocked_reason=Path.find(thinwall,5,0,32,0,0,16,128)
assert(blocked_path==nil and blocked_reason=='start_connector_blocked',tostring(blocked_reason))
print('WORLD_PLAYER_CONNECTOR_OK')

-- World-aligned geometry on either side of a chunk seam at x=256 and x=-256.
local seam_field={field={channel=function(_,x,y,name) return 256-x end}}
local seam=Adapter.new(seam_field,8)
assert(seam:blocked(31,0),"water before positive chunk seam missing")
assert(not seam:blocked(33,0),"dry past positive seam blocked")
local negative_field={field={channel=function(_,x,y,name) return -256-x end}}
local neg=Adapter.new(negative_field,8)
assert(neg:blocked(-33,0),"water before negative seam missing")
assert(not neg:blocked(-31,0),"dry past negative seam blocked")
assert(seam:blocked(31,0)==Adapter.new(seam_field,8):blocked(31,0),"cache regeneration drift")
print("WORLD_PLAYER_CHUNK_SEAM_OK")
