package.path="./?.lua;./?/init.lua;"..package.path
local Placement=require("objects.placement")
local World=require("objects.world")
local Combined=require("objects.query")
local Collision=require("physics.collision")
local Path=require("navigation.pathfinder")
local Controller=require("player.controller")
local Harvest=require("objects.harvesting")
local Wallet=require("objects.wallet")
local noWater={obstacles=function() return {} end}
local fixture={seed=20261015,sample=function() return {biome="forest",feature=nil,walkable=true} end}
local world=World.new(fixture,noWater)
local obj,negative
for y=-12,12 do for x=-12,12 do
  local o=world:site(x,y)
  if o then
    obj=obj or o
    if x<0 and y<0 then negative=negative or o end
  end
end end
assert(obj and negative,"missing positive/negative fixtures")
assert(negative.gx<0 and negative.gy<0)
assert(world:get(negative.id)==negative)
local original={id=negative.id,x=negative.x,y=negative.y,cx=negative.cx,cy=negative.cy}
local before=world:objects_in({min_x=negative.x-1,min_y=negative.y-1,
  max_x=negative.x+1,max_y=negative.y+1})
assert(#before>=1)
assert(world:deplete(negative.id))
world.site_cache={};world.cache_size=0 -- emulate chunk/cache unload
local same=assert(world:get(original.id),"negative-site regeneration failure")
assert(same.id==original.id and same.x==original.x and same.y==original.y)
assert(same.cx==original.cx and same.cy==original.cy)
assert(world:is_depleted(original.id))
for _,o in ipairs(world:objects_in({min_x=same.x-1,min_y=same.y-1,
  max_x=same.x+1,max_y=same.y+1})) do
  assert(o.id~=same.id,"depleted object reappeared after cache eviction")
end
local state=world:export_delta()
assert(state.version==1 and state.seed==fixture.seed and state.objects[same.id].depleted)
state.objects[same.id].depleted=false
assert(world:is_depleted(same.id),"mutable delta leaked through export")
local anotherSeed={seed=20261016,sample=fixture.sample}
local other=World.new(anotherSeed,noWater)
assert(not other:get(same.id),"cross-world instance lookup succeeded")

-- A* path around a visible object: all path segments obey the same swept geometry.
local wall={x=45,y=-11,w=18,h=22}
local objects={obstacles=function(_,minx,miny,maxx,maxy)
  if maxx>=wall.x and minx<=wall.x+wall.w and
     maxy>=wall.y and miny<=wall.y+wall.h then return {wall} end
  return {}
end}
local combined=Combined.new(noWater,objects)
assert(not Collision.can_stand(combined,53,0,3))
local xp,yp,blocked=Collision.move(combined,0,0,96,0,3)
assert(blocked and xp<wall.x,"swept physics passed through object")
local route,reason=Path.find(combined,0,0,96,0,3,16,2048)
assert(route,reason or "A* failed to route around object")
local x,y=0,0
local detour=false
for _,point in ipairs(route) do
  local nx,ny,hit=Collision.move(combined,x,y,point.x-x,point.y-y,3)
  assert(not hit and math.abs(nx-point.x)<1e-5 and math.abs(ny-point.y)<1e-5,
    "A* segment failed swept AABB")
  if math.abs(point.y)>1 then detour=true end
  x,y=point.x,point.y
end
assert(detour and math.abs(x-96)<1e-5 and math.abs(y)<1e-5)
local p=Controller.new(combined,{x=0,y=0,radius=3,speed=96})
assert(p:navigate_to(96,0,16,2048))
for _=1,240 do
  p:update(1/60,0,0)
  assert(Collision.can_stand(combined,p.x,p.y,3),"player penetrated resource")
end
assert(math.abs(p.x-96)<3 and math.abs(p.y)<3,"path following did not arrive")

-- Continuous progress, interruptions and command replay must not mint extra drops.
local tree=assert(world:get(obj.id))
if world:is_depleted(tree.id) then
  for gx=-20,20 do if not world:is_depleted(tree.id) then break end
    tree=world:site(gx,2) or tree
  end
end
assert(not world:is_depleted(tree.id))
local h=Harvest.new(world,38)
local fromx,fromy=tree.x+tree.radius+12,tree.y
local started=h:begin("deep-1",tree.id,fromx,fromy)
assert(started.ok and h:begin("deep-1",tree.id,fromx,fromy)==started)
h:update(.3,fromx,fromy)
assert(h:progress()>0 and h:progress()<1)
h:update(.1,fromx+1000,fromy)
assert(h:begin("deep-1",tree.id,fromx,fromy).status=="interrupted")
assert(not world:is_depleted(tree.id))
assert(h:begin("deep-2",tree.id,fromx,fromy).ok)
for _=1,30 do h:update(.1,fromx,fromy) end
local events=h:drain_events()
local bag=Wallet.new()
assert(#events==1 and bag:apply(events[1]))
assert(not bag:apply(events[1]),"duplicate transaction credited")
assert(#h:drain_events()==0 and bag:count(events[1].item_id)==events[1].amount)
assert(h:begin("deep-3",tree.id,fromx,fromy).status=="depleted")
assert(not pcall(function() world:objects_in({min_x=-1e7,min_y=-1e7,max_x=1e7,max_y=1e7}) end))
print("STAGE4_DEEP_OK negative reload, A*, swept AABB, player path, idempotent harvest")
