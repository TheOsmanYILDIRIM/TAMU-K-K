-- Liquid surface rules are gameplay data, not physical solid obstacles.
-- Add future fluid IDs here without modifying movement/renderer.
local M = {}
local definitions = {
  water = {id="water", speed_multiplier=0.55, immersion=0.5}
}
local dry = {id="dry", speed_multiplier=1.0, immersion=0.0}
M.definitions=definitions

function M.for_feature(feature)
  if feature==nil or feature=="path" then return dry end
  local rule=definitions[feature]
  assert(rule, "missing liquid/surface rule for "..tostring(feature))
  return rule
end

function M.sample(terrain,x,y)
  assert(terrain and type(terrain.sample)=="function","terrain query required")
  assert(type(x)=="number" and x==x and math.abs(x)<math.huge
     and type(y)=="number" and y==y and math.abs(y)<math.huge,
     "invalid liquid position")
  local point=terrain:sample(x,y)
  assert(type(point)=="table","terrain sample unavailable")
  return M.for_feature(point.feature)
end

return M
