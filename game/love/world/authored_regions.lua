-- Authored region lookup, opt-in only. No generator, render, collision or save mutation.
-- Input must already pass schemas/worldbuild-region-v1.schema.json and the Python validator.
local Biomes = require("world.biomes")
local M = {}
local function finite(n)
  return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end
local function on_segment(a,b,x,y)
  local dx,dy=b[1]-a[1],b[2]-a[2]
  local cross=(x-a[1])*dy-(y-a[2])*dx
  local scale=math.max(1,math.abs(dx),math.abs(dy))
  return math.abs(cross)<=1e-9*scale and
    x>=math.min(a[1],b[1])-1e-9 and x<=math.max(a[1],b[1])+1e-9 and
    y>=math.min(a[2],b[2])-1e-9 and y<=math.max(a[2],b[2])+1e-9
end
local function contains(poly,x,y)
  local inside=false
  for i=1,#poly do
    local a,b=poly[i],poly[i%#poly+1]
    if on_segment(a,b,x,y) then return true end
    if (a[2]>y)~=(b[2]>y) then
      local at=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2])
      if x<at then inside=not inside end
    end
  end
  return inside
end
function M.new(map, generator)
  assert(type(map)=="table" and map.format=="osman-worldbuild-v1"
    and map.schema_version==1 and map.generator_version==1
    and map.coordinate_space=="world" and map.projection=="iso-45",
    "unsupported authored map format")
  assert(generator and generator.generator_version==1 and
    type(generator.sample)=="function", "Generator v1 query required")
  assert(map.seed==generator.seed,"authored map seed mismatch")
  assert(type(map.regions)=="table","regions required")
  local regions, ids={},{}
  for _,r in ipairs(map.regions) do
    assert(type(r.id)=="string" and r.id:match("^region:[%w%-]+$")
      and not ids[r.id], "invalid or duplicate region ID")
    assert(type(r.polygon)=="table" and #r.polygon>=3 and #r.polygon<=96,
      "invalid region polygon")
    for _,p in ipairs(r.polygon) do
      assert(type(p)=="table" and finite(p[1]) and finite(p[2]),
        "invalid polygon vertex")
    end
    Biomes.resolve(r.biome,r.variant)
    ids[r.id]=true
    regions[#regions+1]=r
  end
  table.sort(regions,function(a,b) return a.id<b.id end)
  return setmetatable({map_id=map.map_id,seed=map.seed,
    generator_version=1,generator=generator,regions=regions}, {__index=M})
end
function M:region_at(x,y)
  assert(finite(x) and finite(y),"invalid authored query coordinates")
  for _,r in ipairs(self.regions) do
    if contains(r.polygon,x,y) then return r end
  end
  return nil
end
function M:sample(x,y)
  -- Preserve water/path, elevation, walkability and moisture exactly.
  -- No intent-only path/water feature is promoted into physical gameplay.
  local baseline=self.generator:sample(x,y)
  local region=self:region_at(x,y)
  if not region then return baseline,nil end
  local result={}
  for k,v in pairs(baseline) do result[k]=v end
  result.biome=region.biome
  result.variant=region.variant
  result.region_id=region.id
  return result,region
end
return M
