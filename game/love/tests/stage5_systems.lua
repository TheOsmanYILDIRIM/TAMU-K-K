package.path="./?.lua;./?/init.lua;"..package.path

local Catalog=require("systems.catalog")
local Inv=require("systems.inventory")
local Craft=require("systems.crafting")
local Building=require("systems.building")
local Collision=require("physics.collision")
local Path=require("navigation.pathfinder")

local function event(id,item,amount)
  return {type="HarvestCompleted",transaction_id=id,
    item_id=item,amount=amount}
end
local uuid="12345678-1234-4abc-8abc-123456789abc"
local uuid2="12345678-1234-4abc-9abc-123456789abd"

assert(Catalog.version()==1)
assert(Catalog.item("core:wood_log").max_stack==99)
assert(Catalog.item("core:workbench").max_stack==1)
assert(Catalog.recipe("core:planks_from_log").outputs[1].count==4)
assert(not pcall(function() Catalog.item("core:unregistered") end))
assert(not pcall(function() Catalog.recipe("core:not_a_recipe") end))

local inv=Inv.new(4)
assert(inv:credit_harvest(event("h1","core:wood_log",2)))
assert(inv:count("core:wood_log")==2)
assert(not inv:credit_harvest(event("h1","core:wood_log",2)))
assert(inv:count("core:wood_log")==2)
assert(inv:credit_harvest(event("h2","core:wood_log",100)))
assert(inv:count("core:wood_log")==102)
assert(inv:credit_harvest(event("h3","core:stone",1)))
assert(inv:count("core:stone")==1)
assert(inv:count("core:wood_log")==102)
assert(inv:credit_harvest(event("h4","core:wood_log",1)))
assert(not pcall(function() inv:credit_harvest(event("bad","core:missing",2)) end))
assert(not pcall(function() inv:credit_harvest(event("bad2","core:stone",0)) end))
local snap=inv:snapshot()
assert(snap.slots[1].slot==1 and snap.catalog_version==Catalog.version())
snap.slots[1].count=1
assert(inv:count("core:wood_log")==103,"snapshot leaked mutable slots")

local craft=Craft.new(inv)
local a=craft:execute("craft-1","core:planks_from_log")
assert(a.ok and a.status=="crafted")
assert(craft:execute("craft-1","core:planks_from_log")==a)
assert(inv:count("core:wood_plank")==4)
assert(inv:count("core:wood_log")==102)
-- workbench consumes four planks, emits a structure instance item
local bench=craft:execute("craft-2","core:bench_from_planks")
assert(bench.ok)
assert(inv:count("core:wood_plank")==0)
assert(inv:count("core:workbench")==1)
local attempt=craft:execute("craft-3","core:bench_from_planks")
assert(not attempt.ok and attempt.status=="insufficient_materials")
assert(inv:count("core:workbench")==1)
assert(craft:execute("craft-3","core:bench_from_planks")==attempt)

local thin=Inv.new(1)
assert(thin:credit_harvest(event("a","core:stone",99)))
local full=Craft.new(thin)
local bad=full:execute("failure","core:planks_from_log")
assert(not bad.ok and bad.status=="insufficient_materials")
assert(thin:count("core:stone")==99)

local manual=Inv.new(2)
assert(manual:credit_harvest(event("b1","core:wood_log",2)))
assert(manual:credit_harvest(event("b2","core:stone",99)))
-- Input is consumed but outputs would exceed available slots; reject atomically.
local fail=Craft.new(manual):execute("no-space","core:planks_from_log")
assert(not fail.ok and fail.status=="inventory_full")
assert(manual:count("core:wood_log")==2 and manual:count("core:stone")==99)

local terrain={sample=function(_,x,y)
  return {walkable=true,feature=(x>125 and "water" or nil)}
end}
local wall={x=90,y=-10,w=20,h=20}
local solid={obstacles=function(_,x1,y1,x2,y2)
  if x1<wall.x+wall.w and x2>wall.x and y1<wall.y+wall.h and y2>wall.y
    then return {wall} end
  return {}
end}
local world=Building.new(inv,terrain,solid,uuid2)
local r=world:place("place-1",uuid,"core:workbench",32,0,0,-40,0,"local-player")
assert(r.ok and r.status=="placed" and r.revision==1)
assert(world:place("place-1",uuid,"core:workbench",32,0,0,-40,0,"local-player")==r)
assert(inv:count("core:workbench")==0)
assert(not Collision.can_stand(world,32,0,1))
assert(#world:station_tags_near(32,0,16)==1)
assert(world:station_tags_near(32,0,16)[1]=="core:bench")
local duplicate=world:place("place-2",uuid,"core:workbench",80,0,0,0,0,"local-player")
assert(not duplicate.ok and duplicate.status=="instance_id_conflict")
assert(world.revision==1)
assert(world:snapshot().placed[uuid].def_id=="core:workbench")
local s=world:snapshot()
s.placed[uuid].x=999
assert(world.placed[uuid].x==32)
local pass=Path.find(world,-32,-48,96,-48,1,16,600)
assert(pass,"A* must work alongside placed obstacle query")
assert(not pcall(function()
  world:place("bad-uuid","anything","core:workbench",32,0,0,0,0,"local-player")
end))
assert(not pcall(function()
  world:place("bad-rotation",uuid2,"core:workbench",32,0,4,0,0,"local-player")
end))
-- Water placement is invalid even though swimming is allowed.
local more=Inv.new(3)
assert(more:credit_harvest(event("w","core:workbench",1)))
local wb=Building.new(more,terrain,solid,uuid2)
local invalid=wb:place("wet",uuid,"core:workbench",160,0,0,120,0,"local-player")
assert(not invalid.ok and invalid.status=="invalid_surface")
assert(more:count("core:workbench")==1)
local blocked=wb:place("blocked",uuid,"core:workbench",96,0,0,40,0,"local-player")
assert(not blocked.ok and blocked.status=="obstructed")
assert(more:count("core:workbench")==1)
local far=wb:place("far",uuid,"core:workbench",0,0,0,300,0,"local-player")
assert(not far.ok and far.status=="out_of_range")

print("STAGE5_SYSTEMS_OK canonical catalog, slots, no-dupe transactions, craft, UUID placed world")
