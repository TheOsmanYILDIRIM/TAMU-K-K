package.path="./?.lua;./?/init.lua;"..package.path
local b=require("world.biomes");assert(b.validate());assert(#b.order==3)
for _,id in ipairs(b.order) do assert(b.resolve(id,"default")) end
local R=require("world.regions")
local world=R.new({{id="a",biome="meadow",polygon={{0,0},{10,0},{10,10},{0,10}}}})
assert(R.sample(world,5,5).biome.id=="meadow")
assert(R.sample(world,20,20)==nil)
local I=require("world.iso");local x,y=I.project(13,27);local a,c=I.unproject(x,y)
assert(math.abs(a-13)<1e-9 and math.abs(c-27)<1e-9)
local m=require("world.materials");m.register("meadow","default",{height="h.png",normal="n.png"})
assert(m.get("meadow","default").normal=="n.png")
print("biome tests OK")

dofile("tests/creative_build.lua")
