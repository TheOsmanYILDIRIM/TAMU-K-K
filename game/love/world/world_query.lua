-- Stable Stage 2 <-> Stage 3 contract. Import without requiring LOVE runtime.
-- Use colon methods. Positions are world units, not isometric screen pixels.
local Field = require("world.field")
local Query = {}
Query.__index = Query

function Query.new(seed)
  return setmetatable({seed = seed, generator_version = 1,
                       field = Field.new(seed)}, Query)
end

function Query:sample(x, y)
  return self.field:sample(x, y)
end

function Query:get_biome(x, y)
  return self:sample(x, y).biome -- meadow | forest | rocky
end

function Query:get_height(x, y)
  return self:sample(x, y).height
end

function Query:get_feature(x, y)
  return self:sample(x, y).feature -- water | path | nil
end

function Query:is_walkable(x, y)
  return self:sample(x, y).walkable
end

-- No collidable instances exist in Stage 2. Object collision is a later system.
-- Bounds: {min_x, min_y, max_x, max_y} world units. Validate rather
-- than returning fake obstacles for an unsupported query.
function Query:get_obstacles(bounds)
  assert(type(bounds) == "table"
    and type(bounds.min_x) == "number" and type(bounds.min_y) == "number"
    and type(bounds.max_x) == "number" and type(bounds.max_y) == "number"
    and bounds.min_x == bounds.min_x and bounds.min_y == bounds.min_y
    and bounds.max_x == bounds.max_x and bounds.max_y == bounds.max_y
    and bounds.min_x > -math.huge and bounds.min_y > -math.huge
    and bounds.max_x < math.huge and bounds.max_y < math.huge
    and bounds.min_x <= bounds.max_x and bounds.min_y <= bounds.max_y,
    "invalid obstacle bounds")
  return {}
end

return Query
