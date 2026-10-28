-- Render-only world-space slope illumination. No physics or LÖVE dependencies.
local M={}
local sqrt=math.sqrt
local function finite(v)
 return type(v)=="number" and v==v and v>-math.huge and v<math.huge
end
local SUN={x=-0.55,y=-0.35,z=0.76}
local sl=sqrt(SUN.x*SUN.x+SUN.y*SUN.y+SUN.z*SUN.z)
SUN.x,SUN.y,SUN.z=SUN.x/sl,SUN.y/sl,SUN.z/sl
M.sun={SUN.x,SUN.y,SUN.z}
function M.normal(gx,gy,height_scale)
 height_scale=height_scale or 0.35
 assert(finite(gx) and finite(gy) and finite(height_scale) and height_scale>=0 and height_scale<=4,
  "invalid slope or height scale")
 local x,y=-gx*height_scale,-gy*height_scale
 local length=sqrt(x*x+y*y+1)
 return x/length,y/length,1/length
end
function M.shade(nx,ny,nz,options)
 options=options or {}
 local ambient=options.ambient == nil and .36 or options.ambient
 local diffuse=options.diffuse == nil and .64 or options.diffuse
 assert(finite(nx) and finite(ny) and finite(nz) and finite(ambient)
  and finite(diffuse) and ambient>=0 and diffuse>=0 and ambient+diffuse<=1.5,
  "invalid lighting parameters")
 local dot=nx*SUN.x+ny*SUN.y+nz*SUN.z
 return math.min(1,ambient+diffuse*math.max(0,dot))
end
return M
