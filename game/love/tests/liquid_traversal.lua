package.path="./?.lua;./?/init.lua;"..package.path

local Liquids=require("world.liquids")
local Query=require("world.world_query")
local Combined=require("objects.query")
local ObjectWorld=require("objects.world")
local Adapter=require("world.collision_adapter")
local Controller=require("player.controller")
local Collision=require("physics.collision")
local Path=require("navigation.pathfinder")

local function near(a,b,epsilon)
  assert(math.abs(a-b)<(epsilon or 1e-5),tostring(a).." != "..tostring(b))
end
local fixture={
  sample=function(_,x,y)
    return {biome="meadow",feature=(x>=0 and "water" or nil),walkable=true}
  end
}
local fake_water={
  world=fixture,
  obstacles=function(_,x1,y1,x2,y2)
    -- A former water barrier intentionally must NOT block the player.
    if x2>=0 then return {{x=0,y=-100,w=100,h=200}} end
    return {}
  end
}
local empty_objects={obstacles=function() return {} end}
local solid=Combined.new(fake_water,empty_objects)
near(solid:surface_at(-10,0).speed_multiplier,1)
near(solid:surface_at(10,0).speed_multiplier,0.55)
near(solid:surface_at(10,0).immersion,0.5)
assert(Collision.can_stand(solid,50,0,2),"liquid still solid")
local direct=Controller.new(solid,{x=10,y=0,radius=2,speed=60})
local dry_world={sample=function() return {feature=nil,walkable=true} end}
local dry=Combined.new({world=dry_world,obstacles=function()return {} end},empty_objects)
local land=Controller.new(dry,{x=10,y=0,radius=2,speed=60})
for _=1,60 do
  direct:update(1/60,1,0)
  land:update(1/60,1,0)
end
near(direct.x,43)
near(land.x,70)
assert(direct.state=="walk" and direct.immersion==0.5)
near(direct.surface_multiplier,0.55)

local crossing=Controller.new(solid,{x=-20,y=0,speed=60,radius=2})
for _=1,60 do crossing:update(1/60,1,0) end
assert(crossing.x>0 and crossing.x<40,"water shoreline should slow, not block")
near(crossing.immersion,0.5)
for _=1,150 do crossing:update(1/60,-1,0) end
assert(crossing.x<0 and crossing.immersion==0 and crossing.surface_multiplier==1,
  "player did not leave liquid")
local dest=Path.find(solid,-32,0,48,0,2,16,200)
assert(dest and #dest>0,"A* did not cross traversable water")

local rock={x=27,y=-4,w=8,h=8}
local object_world={obstacles=function(_,x1,y1,x2,y2)
  if x1 < rock.x+rock.w and x2 > rock.x and y1 < rock.y+rock.h and y2 > rock.y
    then return {rock} end
  return {}
end}
local mixed=Combined.new(fake_water,object_world)
local nx,ny,hit=Collision.move(mixed,10,0,30,0,2)
assert(hit and nx<rock.x and nx>20,"object collision lost in water")
near(ny,0)
assert(not Collision.can_stand(mixed,30,0,2),"rock no longer solid")
local route=Path.find(mixed,0,0,48,0,2,8,500)
assert(route and #route>0,"A* failed to route around rock across water")

local real=Query.new(20261015)
local mask=Adapter.new(real,8)
local objects=ObjectWorld.new(real,mask)
local gameplay=Combined.new(mask,objects)
local wet
for y=-2048,2048,64 do
  for x=-2048,2048,64 do
    if real:get_feature(x,y)=="water" and Collision.can_stand(gameplay,x,y,3) then
      wet={x=x,y=y};break
    end
  end
  if wet then break end
end
assert(wet,"seed has no walkable water")
assert(real:is_walkable(wet.x,wet.y),"WorldQuery flags water impassable")
local realplayer=Controller.new(gameplay,{x=wet.x,y=wet.y,radius=3,speed=60})
near(realplayer.immersion,0.5)
assert(gameplay:surface_at(wet.x,wet.y).id=="water")
local old=realplayer.x
for _=1,10 do
  realplayer:update(1/60,1,0)
  assert(Collision.can_stand(gameplay,realplayer.x,realplayer.y,3),
    "player crossed solid object while wading")
end
assert(realplayer.x>old)
assert(not pcall(function() Liquids.sample(fixture,0/0,0) end))
assert(not pcall(function() Liquids.for_feature("unknown_liquid") end))
print(string.format("LIQUID_TRAVERSAL_OK water_speed=%.2f immersion=%.2f wet=(%d,%d)",
  direct.surface_multiplier,direct.immersion,wet.x,wet.y))
