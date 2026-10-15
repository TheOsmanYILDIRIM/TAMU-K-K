-- Player collision authority: placed resources are solid; liquids affect
-- speed/immersion only. The independent shoreline mask remains for dry placement.
local Liquids=require("world.liquids")
local Q={};Q.__index=Q
function Q.new(water,objects)
  assert(water and type(water.obstacles)=="function","placement water mask required")
  assert(objects and type(objects.obstacles)=="function","object query required")
  if water.world then
    assert(type(water.world.sample)=="function","terrain surface sampler required")
  end
  return setmetatable({water=water,objects=objects,terrain=water.world},Q)
end
function Q:obstacles(x1,y1,x2,y2)
  -- Do NOT include water: A* and swept AABB must cross liquid shorelines.
  return self.objects:obstacles(x1,y1,x2,y2)
end
function Q:surface_at(x,y)
  if self.terrain then
    return Liquids.sample(self.terrain,x,y)
  end
  -- Explicit dry surface for isolated object/physics fixtures with no terrain.
  return Liquids.for_feature(nil)
end
return Q
