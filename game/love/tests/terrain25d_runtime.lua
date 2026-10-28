-- Pure Lua mock test: atlas loading, chunk ownership, determinism, sprites.
package.path="./?.lua;./?/init.lua;"..package.path
local uploads,draws=0,0
local image={}
function image:getDimensions() return 1056,396 end
function image:setFilter() end
function image:setWrap() end
local g={
 newImage=function(p) assert(p=="assets/terrain25d/atlas_00.png");return image end,
 newQuad=function(x,y,w,h,aw,ah)
   assert(x>=0 and y>=0 and w>0 and h>0 and x+w<=aw and y+h<=ah)
   return {x,y,w,h}
 end,
 newMesh=function(vertices,mode,usage)
   assert(mode=="triangles" and usage=="static" and #vertices>0
       and #vertices%3==0)
   uploads=uploads+1
   local m={vertices=vertices,released=false}
   function m:setTexture(im) assert(im==image) end
   function m:release() self.released=true end
   return m
 end,
 push=function() end,pop=function() end,translate=function() end,
 scale=function() end,clear=function() end,setColor=function() end,
 setLineWidth=function() end,ellipse=function() end,
 draw=function() draws=draws+1 end
}
love={graphics=g,timer={getTime=function() return 0 end},
 filesystem={read=function(p)
   local f=assert(io.open(p,"rb"));local s=f:read("*a");f:close();return s
 end}}
local Runtime=require("world.terrain25d_runtime")
local Sprite=require("objects.terrain25d_sprites")
local pilot={
 query={
   sample=function(_,x,y) return {biome=x>100 and "rocky" or "forest",
     feature=y<32 and "path" or "meadow"} end,
   water_mask=function(_,x,y) return x>180 and y>180,-24 end
 },
 topography={
   height=function(_,x,y) return .05*x+.03*y end,
   sample=function() return {gradient_x=.05,gradient_y=.03} end
 },
 routes={},render_options={height_scale=.35}
}
local runtime=Runtime.new(pilot)
local sprites=Sprite.new(runtime.atlas,runtime.manifest)
local chunk={x=0,y=0,size=256,cx=0,cy=0,
 layers={water={vertices={{200,200},{232,200},{232,232}}}}}
local stream={visible=function() return {chunk} end}
local cam={x=0,y=0,zoom=1.2,
 project=function(_,x,y,w,h) return w/2+x,h/2+y end}
runtime:draw(stream,cam,360,780)
assert(runtime.built==1 and uploads>1 and runtime.visible==1)
local before=uploads
runtime:draw(stream,cam,360,780)
assert(uploads==before and runtime.uploads_per_frame==0)
assert(chunk._meshes==chunk._25d_meshes)
local released=0
for _,mesh in pairs(chunk._meshes) do
 mesh:release();assert(mesh.released);released=released+1
end
assert(released==before)
sprites:draw(g,cam,360,780,{x=4,y=9,id="tree:1",kind="tree",radius=12},false)
sprites:draw(g,cam,360,780,{x=4,y=19,id="rock:1",kind="rock",radius=8},true)
assert(draws>=2)
print("TERRAIN25D_RUNTIME_OK uploads="..uploads.." released="..released)
