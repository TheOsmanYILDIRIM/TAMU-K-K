-- Deterministic R2 H opt-in valley shaping, following a validated authored
-- water centerline. Generator v1 and saved height fields remain untouched.
-- Original B world-space topography consumes this offset in its height_at hook.
local M={}
M.__index=M
local function finite(n)
 return type(n)=="number" and n==n and n>-math.huge and n<math.huge
end
function M.new(features,opts)
 opts=opts or {}
 assert(type(features)=="table" and type(features.nearest)=="function"
  and type(features.by_id)=="table","validated C features required")
 local water=features.by_id["feature:fisilti-dere-izi"]
 assert(water and water.kind=="water" and water.width==22
  and #water.points==4 and water.points[3][1]==704
  and water.points[3][2]==128,
  "approved crossing-aligned R2 river data required")
 local depth=opts.depth or 2
 local bank=opts.bank_width or 36
 assert(finite(depth) and depth>0 and depth<=4 and finite(bank)
  and bank>=16 and bank<=128,"invalid R2 valley profile")
 return setmetatable({features=features,depth=depth,
  radius=water.width/2+bank},M)
end
function M:offset(x,y)
 assert(finite(x) and finite(y),"invalid valley world coordinates")
 local hit=self.features:nearest(x,y,"water")
 if not hit or hit.distance>=self.radius then return 0 end
 -- C1-continuous channel, zero derivative at bank boundary and river axis.
 -- No arbitrary per-chunk/viewport noise; bank normals derive from world polyline.
 local t=hit.distance/self.radius
 return -self.depth*(1-t*t)^2
end
function M:height(base,x,y)
 assert(type(base)=="table" and type(base.get_height)=="function",
  "Generator v1/world height source required")
 return base:get_height(x,y)+self:offset(x,y)
end
return M
