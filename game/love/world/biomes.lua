local B={
meadow={id="meadow",color={.48,.63,.38},roughness=.18,sculpt=.15,variants={default={relief=1,foliage=.4},wildflower={relief=.85,foliage=.75},dry={relief=.7,foliage=.18}}},
forest={id="forest",color={.27,.44,.31},roughness=.34,sculpt=.28,variants={default={relief=1,foliage=.9},clearing={relief=.65,foliage=.2},dense={relief=1.25,foliage=1}}},
rocky={id="rocky",color={.51,.54,.49},roughness=.82,sculpt=.85,variants={default={relief=1,foliage=.08},ridge={relief=1.45,foliage=.02},gravel={relief=.55,foliage=0}}}
}
local M={definitions=B,order={"meadow","forest","rocky"}}
function M.resolve(id,name)
 local b=assert(B[id],"Unknown biome: "..tostring(id))
 local v=assert(b.variants[name or "default"],"Unknown variant: "..tostring(name))
 return b,v
end
function M.validate()
 assert(#M.order==3)
 for _,id in ipairs(M.order) do
  local b=assert(B[id]);assert(b.id==id and b.variants.default)
  for _,v in pairs(b.variants) do assert(v.relief>=0 and v.foliage>=0 and v.foliage<=1) end
 end
 return true
end
return M
