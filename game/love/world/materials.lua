-- R2 D view-only shaderless materials. Preserve all 18 stable family IDs.
local Biomes=require("world.biomes")
local M={slots={},families={},order={}}
local names={"base","moss","warm","cool","earth","lichen"}
local tones={
 meadow={{.86,.94,.79},{.79,.99,.78},{1,.94,.72},{.76,.91,.89},{.97,.79,.66},{.84,.98,.82}},
 forest={{.79,.91,.77},{.70,.99,.77},{.99,.89,.68},{.70,.87,.97},{.94,.75,.76},{.83,1.04,.84}},
 rocky={{.89,.91,.83},{.79,.91,.84},{1,.94,.79},{.79,.87,.98},{.96,.82,.73},{.85,.99,.87}}
}
local function finite(x) return type(x)=="number" and x==x and x>-math.huge and x<math.huge end
local function clamp(x) return math.max(0,math.min(1,x)) end
local function smooth(x) x=clamp(x);return x*x*(3-2*x) end
local function lerp(a,b,t) return a+(b-a)*t end
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
 for i,label in ipairs(names) do
  local id=biome.."/"..label
  M.families[biome][i]={id=id,tint=tones[biome][i]}
  M.order[#M.order+1]=id
 end
end
-- World-space analytic colors, independent of chunks and random state.
function M.color(biome,x,y)
 assert(finite(x) and finite(y),"finite material coordinates required")
 local base=Biomes.resolve(biome).color
 local palette=assert(M.families[biome],"unknown terrain material")
 local offset=1+5*(.5+.5*math.sin(x/143+y/217))
 local low=math.min(6,math.floor(offset))
 local high=math.min(6,low+1)
 local weight=smooth(offset-low)
 local grain=1+.055*math.sin(x/73-y/107)
              +.025*math.sin(x/29+y/43)
              +.018*math.cos(x/17-y/23)
 local a,b=palette[low].tint,palette[high].tint
 return {clamp(base[1]*lerp(a[1],b[1],weight)*grain),
         clamp(base[2]*lerp(a[2],b[2],weight)*grain),
         clamp(base[3]*lerp(a[3],b[3],weight)*grain)}
end
function M.edge_alpha(signed,band)
 assert(finite(signed) and finite(band) and band>0)
 return smooth(signed/band)
end
-- Directional visual lighting only: no gameplay visibility or path collision.
function M.light(gx,gy)
 assert(finite(gx) and finite(gy))
 local slope=math.sqrt(gx*gx+gy*gy)
 local shade=1-.19*math.min(1,slope/.65)
                +.10*math.max(-1,math.min(1,-gx-gy))
 return math.max(.67,math.min(1.08,shade))
end
-- Deterministic decoration jitter, not the world generator RNG.
function M.fleck(x,y,salt)
 assert(finite(x) and finite(y) and finite(salt))
 local n=math.sin(x*12.9898+y*78.233+salt*37.719)*43758.5453
 return n-math.floor(n)
end

-- Renderer-only authored polygon bounds. Gameplay keeps the exact polygon.
-- Preprocessing once per immutable authored map avoids repeated edge allocation.
function M.authored_edges(regions)
 assert(type(regions)=="table","authored regions required")
 local result={}
 for _,region in ipairs(regions) do
  local polygon=assert(region.polygon,"authored polygon required")
  assert(#polygon>=3,"authored polygon too short")
  for i=1,#polygon do
   local a,b=polygon[i],polygon[i%#polygon+1]
   local ax,ay,bx,by=a[1],a[2],b[1],b[2]
   assert(finite(ax) and finite(ay) and finite(bx) and finite(by),
     "nonfinite authored polygon")
   local dx,dy=bx-ax,by-ay
   local length2=dx*dx+dy*dy
   if length2>0 then
    result[#result+1]={ax=ax,ay=ay,dx=dx,dy=dy,length2=length2,
     minx=math.min(ax,bx),maxx=math.max(ax,bx),
     miny=math.min(ay,by),maxy=math.max(ay,by)}
   end
  end
 end
 return result
end
-- Softens only the DRAWN biome overlay. No region membership or collision
-- changes; all noise is continuous in absolute world space (camera/chunk safe).
function M.authored_feather(edges,x,y,band)
 assert(type(edges)=="table" and finite(x) and finite(y)
   and finite(band) and band>0,"invalid authored feather arguments")
 local reach=band*1.25
 local closest=reach*reach
 for _,e in ipairs(edges) do
  if x>=e.minx-reach and x<=e.maxx+reach
   and y>=e.miny-reach and y<=e.maxy+reach then
   local t=clamp(((x-e.ax)*e.dx+(y-e.ay)*e.dy)/e.length2)
   local ddx=x-e.ax-t*e.dx
   local ddy=y-e.ay-t*e.dy
   closest=math.min(closest,ddx*ddx+ddy*ddy)
  end
 end
 if closest==reach*reach then return 1 end
 local irregularity=.12*math.sin(x/17+y/23)+.075*math.cos(x/11-y/19)
 return M.edge_alpha(math.sqrt(closest)*(1+irregularity),band)
end
return M
