-- Explicit authored WorldQuery facade: existing Generator v1 remains untouched.
-- Pass facade to Chunks.new and CollisionAdapter.new together with gameplay consumers.
local Authored=require("world.authored_regions")
local M={}
M.__index=M
function M.new(map,base)
  assert(base and base.field and type(base.field.channel)=="function"
    and type(base.get_obstacles)=="function","complete Generator v1 query required")
  local authored=Authored.new(map,base)
  local field={}
  function field:channel(x,y,name)
    -- Keep water mesh and conservative placement collision bit-compatible.
    local source=base.field:channel(x,y,name)
    if name=="water" then return source end
    local region=authored:region_at(x,y)
    if not region then return source end
    -- Marching contour uses the same region selection as WorldQuery.sample.
    -- Discrete polygon masks require exact clipping for precise visual seams.
    if name=="forest" then return region.biome=="forest" and 1 or -1 end
    if name=="rocky" then return region.biome=="rocky" and 1 or -1 end
    return source
  end
  return setmetatable({field=field,seed=base.seed,generator_version=1,
    authored=authored,base=base,map_id=map.map_id},M)
end
function M:sample(x,y) return self.authored:sample(x,y) end
function M:get_biome(x,y) return self:sample(x,y).biome end
function M:get_feature(x,y) return self:sample(x,y).feature end
function M:get_height(x,y) return self:sample(x,y).height end
function M:is_walkable(x,y) return self:sample(x,y).walkable end
function M:get_obstacles(bounds) return self.base:get_obstacles(bounds) end
return M
