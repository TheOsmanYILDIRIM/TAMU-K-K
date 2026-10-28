-- Pure Lua mock test: atlas loading, chunk ownership, determinism, sprites.
package.path="./?.lua;./?/init.lua;"..package.path
local uploads,draws=0,0
local image={}
function image:getDimensions() return 1056,396 end
function image:setFilter() end
function image:setWrap() end
function image:release() self.released=true end
local extra_image={}
function extra_image:getDimensions() return 128,128 end
function extra_image:setFilter() end
function extra_image:setWrap() end
function extra_image:release() self.released=true end
local extra_loads=0
local g={
 newImage=function(p)
   if p=="assets/terrain25d/atlas_00.png" then return image end
   assert(p=="assets/terrain25d/atlas_01.png")
   extra_loads=extra_loads+1
   extra_image.released=false
   return extra_image
 end,
 newQuad=function(x,y,w,h,aw,ah)
   assert(x>=0 and y>=0 and w>0 and h>0 and x+w<=aw and y+h<=ah)
   return {x,y,w,h}
 end,
 newSpriteBatch=function(img,max,usage)
   assert((img==image or img==extra_image) and max>=200 and usage=="stream")
   local batch={count=0}
   function batch:add(quad,x,y,r,sx,sy,ox,oy)
     assert(quad and sx>0 and sy>0 and ox==64 and oy==124)
     self.count=self.count+1
   end
   function batch:clear() self.count=0 end
   function batch:release() self.released=true end
   return batch
 end,
 newMesh=function(vertices,mode,usage)
   assert(mode=="triangles" and usage=="static" and #vertices>0
       and #vertices%3==0)
   uploads=uploads+1
   local m={vertices=vertices,released=false}
   function m:setTexture(im) assert(im==image or im==extra_image) end
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
assert(runtime.catalog_counts.total==228 and runtime.catalog_counts.packed==20)
local sprites=Sprite.new(runtime,runtime.manifest)
assert(runtime:family(20,50)~="wetland",
  "Generator scalar values are not authored bank distances")
assert(runtime:family(220,220)=="wetland",
  "physical water must retain wetland material")
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
sprites:begin_frame()
sprites:queue(g,cam,360,780,{x=4,y=9,id="tree:1",kind="tree",radius=12},false)
sprites:queue(g,cam,360,780,{x=4,y=19,id="rock:1",kind="rock",radius=8},true)
sprites:queue(g,cam,360,780,{x=10000,y=10000,id="off",kind="tree",radius=12},false)
assert(sprites.visible==2 and sprites.culled==1 and sprites.pending==2)
sprites:flush(g)
assert(sprites.batches==1 and sprites.pending==0)
assert(draws>=1)
assert(runtime.atlas_resident_pages==1 and
  runtime.atlas_estimated_gpu_bytes==1056*396*4)

-- A second packed page is simulated in the mock manifest only: no new
-- user assets are approved or packaged by this test.
local Json=require("save.json")
local manifest=Json.decode(assert(love.filesystem.read("assets/terrain25d/manifest.json")))
manifest.atlas_pages[#manifest.atlas_pages+1]={
 filename="atlas_01.png",width=128,height=128,sha256="mock-page"}
for _,a in ipairs(manifest.assets) do
 if a.kind=="object" and a.family=="boulder" then
   a.atlas_page="atlas_01.png"
   a.uv_rect=Json.decode("[0,0,1,1]")
 end
end
local old_read=love.filesystem.read
love.filesystem.read=function(path)
 if path=="assets/terrain25d/manifest.json" then return Json.encode(manifest) end
 return old_read(path)
end
local multi=Runtime.new(pilot)
love.filesystem.read=old_read
local multi_sprites=Sprite.new(multi,multi.manifest)
assert(extra_loads==0,"unused approved page must not be uploaded")
multi_sprites:begin_frame()
multi_sprites:queue(g,cam,360,780,
 {x=5,y=12,id="rock:page1",kind="rock",radius=8},false)
assert(extra_loads==1 and multi_sprites.pending==1)
-- A depth-ordered page switch must flush the first batch.
multi_sprites:queue(g,cam,360,780,
 {x=4,y=22,id="tree:page0",kind="tree",radius=12},false)
multi_sprites:flush(g)
assert(multi_sprites.batches==2,"cross-page depth-order batch flush lost")
multi:prune_pages({resident={}}, {})
assert(not extra_image.released,"live sprite pin must protect its image")
for _=1,3 do multi_sprites:begin_frame() end
local hold={_25d_ground_pages={["atlas_01.png"]=true}}
multi:prune_pages({resident={hold=hold}}, {})
assert(not extra_image.released,"resident terrain mesh must protect page")
multi:prune_pages({resident={}}, {})
assert(extra_image.released and multi.page_images["atlas_01.png"]==nil,
  "idle page must be reclaimed after sprite and terrain release")
assert(multi.atlas_estimated_gpu_bytes==1056*396*4)
print("TERRAIN25D_RUNTIME_OK uploads="..uploads.." released="..released..
  " lazy_page_loads="..extra_loads)
