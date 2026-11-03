package.path="./?.lua;./?/init.lua;"..package.path
local Query=require("world.world_query")
local Facade=require("world.authored_world")
local Chunks=require("world.chunks")
local Collision=require("world.collision_adapter")
local Liquids=require("world.liquids")
local seed=20261018
local base=Query.new(seed)
local map={format="osman-worldbuild-v1",schema_version=1,generator_version=1,
  projection="iso-45",coordinate_space="world",seed=seed,map_id="worldmap:test",
  regions={{id="region:one",biome="forest",variant="dense",
    polygon={{0,0},{128,0},{128,128},{0,128}}}}}
local world=Facade.new(map,base)
assert(world:get_biome(64,64)=="forest")
assert(world:get_biome(-100,64)==base:get_biome(-100,64))
for _,p in ipairs({{64,64},{-64,-64},{0,0},{128,64},{300,300}}) do
 local x,y=p[1],p[2]
 local sample,orig=world:sample(x,y),base:sample(x,y)
 assert(sample.feature==orig.feature and sample.walkable==orig.walkable)
 assert(sample.height==orig.height and sample.moisture==orig.moisture)
 assert(world.field:channel(x,y,"water")==base.field:channel(x,y,"water"))
 assert(Liquids.sample(world,x,y).speed_multiplier==Liquids.sample(base,x,y).speed_multiplier)
 assert(Liquids.sample(world,x,y).immersion==Liquids.sample(base,x,y).immersion)
end
local ca,cb=Collision.new(world),Collision.new(base)
for _,p in ipairs({{0,0},{8,8},{16,0},{-8,-8},{128,128}}) do
 local x,y=p[1],p[2]
 assert(ca:blocked(x,y)==cb:blocked(x,y))
end
local ac,bc=Chunks.new(world):build(0,0),Chunks.new(base):build(0,0)
assert(#ac.layers.water.vertices==#bc.layers.water.vertices)
for i,v in ipairs(ac.layers.water.vertices) do
 assert(v[1]==bc.layers.water.vertices[i][1] and v[2]==bc.layers.water.vertices[i][2])
end
local reversed=Facade.new(map,Query.new(seed))
assert(reversed.field:channel(64,64,"forest")==world.field:channel(64,64,"forest"))
print("authored facade: mesh/water/collision/physics invariants OK")
