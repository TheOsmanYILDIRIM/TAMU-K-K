package.path="./?.lua;./?/init.lua;"..package.path
local Query=require("world.world_query")
local Authored=require("world.authored_regions")
local seed=20261018
local base=Query.new(seed)
local a={id="region:a",biome="meadow",variant="wildflower",
  polygon={{0,0},{10,0},{10,10},{0,10}}}
local b={id="region:b",biome="forest",variant="dense",
  polygon={{10,0},{20,0},{20,10},{10,10}}}
local function map(regions)
  return {format="osman-worldbuild-v1",schema_version=1,generator_version=1,
    projection="iso-45",coordinate_space="world",seed=seed,
    map_id="worldmap:test",regions=regions}
end
local q=Authored.new(map({b,a}),base)
local reversed=Authored.new(map({a,b}),Query.new(seed))
for _,p in ipairs({{5,5},{10,5},{15,5},{-3,8},{25,3},{10,0}}) do
  local x,y=p[1],p[2]
  local got=q:sample(x,y)
  local other=reversed:sample(x,y)
  local raw=base:sample(x,y)
  assert(got.biome==other.biome and got.feature==other.feature)
  assert(got.height==raw.height and got.moisture==raw.moisture)
  assert(got.walkable==raw.walkable and got.feature==raw.feature)
  assert(got.biome==other.biome and got.region_id==other.region_id)
end
assert(q:region_at(10,5).id=="region:a")
assert(q:region_at(-1,5)==nil)
assert(q:sample(-1,5).biome==base:sample(-1,5).biome)
assert(not pcall(function() Authored.new(map({a,a}),base) end))
assert(not pcall(function() Authored.new(map({a}),Query.new(2)) end))
assert(not pcall(function() q:sample(0/0,0) end))
print("authored runtime lookup/fallback/physics invariants OK")
