local Biomes=require("world.biomes")
local M={}
function M.contains(poly,x,y)
 local inside=false
 for i=1,#poly do
  local a,b=poly[i],poly[i%#poly+1]
  if (a[2]>y)~=(b[2]>y) then
   local px=a[1]+(y-a[2])*(b[1]-a[1])/(b[2]-a[2])
   if x<px then inside=not inside end
  end
 end
 return inside
end
function M.new(regions)
 assert(type(regions)=="table" and #regions>0)
 local ids={}
 for _,r in ipairs(regions) do
  assert(type(r.id)=="string" and not ids[r.id],"Duplicate region")
  ids[r.id]=true
  assert(type(r.polygon)=="table" and #r.polygon>=3,"Invalid polygon")
  Biomes.resolve(r.biome,r.variant)
 end
 return {regions=regions}
end
function M.sample(world,x,y)
 for i=#world.regions,1,-1 do
  local r=world.regions[i]
  if M.contains(r.polygon,x,y) then
   local b,v=Biomes.resolve(r.biome,r.variant)
   return {region=r,biome=b,variant=v}
  end
 end
 return nil
end
return M
