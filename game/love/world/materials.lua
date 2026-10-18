-- Terrain appearance only. Gameplay biome variants remain in world.biomes.
-- Six seamless tint families per biome = 18 procedural material variants.
-- No texture dependency, RNG state, save changes or cell boundaries.
local Biomes = require("world.biomes")
local M = {slots={}, families={}, order={}}
local tones = {
  meadow={{1,1,1},{.92,1.04,.88},{1.08,1.03,.86},{.94,.96,1.08},{1.09,.96,.93},{.91,1.05,1.01}},
  forest={{1,1,1},{.88,1.07,.90},{1.05,1.02,.89},{.94,.96,1.12},{1.09,.93,.95},{.93,1.08,1.03}},
  rocky={{1,1,1},{.91,1.00,.93},{1.05,1.04,.91},{.93,.97,1.08},{1.08,.95,.92},{.97,1.03,1.05}}
}
local labels={"base","moss","warm","cool","earth","lichen"}
local function clamp(v) return math.max(0,math.min(1,v)) end
function M.register(id,variant,asset)
  assert(type(id)=="string" and type(asset)=="table")
  for _,key in ipairs({"albedo","height","normal"}) do
    if asset[key]~=nil then assert(type(asset[key])=="string" and #asset[key]>0) end
  end
  M.slots[id.."/"..(variant or "default")]=asset
end
function M.get(id,variant) return M.slots[id.."/"..(variant or "default")] end

for _,biome in ipairs(Biomes.order) do
  M.families[biome]={}
  for i,label in ipairs(labels) do
    local id=biome.."/"..label
    M.families[biome][i]={id=id,tint=tones[biome][i]}
    M.order[#M.order+1]=id
  end
end

-- Continuous analytic modulation: identical world coordinates at chunk seams
-- always produce identical colors (regardless of stream ordering).
function M.color(biome,x,y)
  assert(type(x)=="number" and type(y)=="number")
  local base=Biomes.resolve(biome).color
  local palette=assert(M.families[biome],"unknown terrain material")
  local u=(math.sin(x/131+y/211)+1)*.5
  local v=(math.sin(x/307-y/173)+1)*.5
  local offset=1+5*u
  local low=math.min(6,math.floor(offset))
  local high=math.min(6,low+1)
  local t=offset-low
  t=t*t*(3-2*t)
  local grain=.965+.07*v
  local a,b=palette[low].tint,palette[high].tint
  return {clamp(base[1]*(a[1]+(b[1]-a[1])*t)*grain),
          clamp(base[2]*(a[2]+(b[2]-a[2])*t)*grain),
          clamp(base[3]*(a[3]+(b[3]-a[3])*t)*grain)}
end
return M
