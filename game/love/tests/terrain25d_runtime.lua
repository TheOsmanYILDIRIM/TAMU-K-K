-- Pure Lua regression: all 228 source IDs, lazy multi-page images, GPU eviction.
package.path="./?.lua;./?/init.lua;"..package.path
local uploads,draws,pastes,decoded,created=0,0,0,0,0
local function fakeImage(w,h)
 local v={w=w,h=h,released=false}
 function v:getDimensions() return self.w,self.h end
 function v:setFilter() end
 function v:setWrap() end
 function v:release() self.released=true end
 return v
end
local pilotImage=fakeImage(1056,396)
local generatedImages={}
local function fakeData(w,h)
 local d={w=w,h=h,released=false}
 function d:getDimensions() return self.w,self.h end
 function d:paste(other,x,y,sx,sy,pw,ph)
   assert(not self.released and not other.released)
   assert(x>=0 and y>=0 and x+pw<=self.w and y+ph<=self.h)
   assert(other.w==128 and other.h==128 and
     sx==0 and sy==0 and pw==128 and ph==128)
   pastes=pastes+1
 end
 function d:release() self.released=true end
 return d
end
local g={
 newImage=function(input)
   if type(input)=="string" then
     assert(input=="assets/terrain25d/atlas_00.png")
     return pilotImage
   end
   assert(type(input)=="table" and input.w and input.h)
   created=created+1
   local im=fakeImage(input.w,input.h)
   generatedImages[#generatedImages+1]=im
   return im
 end,
 newQuad=function(x,y,w,h,aw,ah)
   assert(x>=0 and y>=0 and w>0 and h>0 and
     x+w<=aw+0.00001 and y+h<=ah+0.00001)
   return {x,y,w,h}
 end,
 newSpriteBatch=function(im,max,usage)
   assert(im and max>=200 and usage=="stream")
   local b={count=0}
   function b:add(quad,x,y,r,sx,sy,ox,oy)
     assert(quad and sx>0 and sy>0 and ox==64 and oy==124)
     self.count=self.count+1
   end
   function b:clear() self.count=0 end
   function b:release() self.released=true end
   return b
 end,
 newMesh=function(vertices,mode,usage)
   assert(mode=="triangles" and usage=="static" and
     #vertices>0 and #vertices%3==0)
   uploads=uploads+1
   local m={released=false}
   function m:setTexture(im) assert(im and im.getDimensions) end
   function m:release() self.released=true end
   return m
 end,
 push=function() end,pop=function() end,translate=function() end,
 scale=function() end,clear=function() end,setColor=function() end,
 setLineWidth=function() end,ellipse=function() end,
 draw=function() draws=draws+1 end
}
love={graphics=g,timer={getTime=function() return 0 end},
 image={newImageData=function(a,b)
   if type(a)=="string" then
     assert(a:match("^assets/terrain25d/source_png/"))
     local fp=assert(io.open(a,"rb"),"missing sourced PNG: "..a)
     assert(fp:read(8)=="\137PNG\r\n\26\n","not a PNG: "..a)
     fp:close()
     decoded=decoded+1
     return fakeData(128,128)
   end
   assert(type(a)=="number" and type(b)=="number" and a>0 and b>0)
   return fakeData(a,b)
 end},
 filesystem={
   read=function(p)
     local f=assert(io.open(p,"rb"));local s=f:read("*a");f:close();return s
   end,
   getInfo=function(p)
     if p=="assets/terrain25d/atlas_00.png" then return {type="file"} end
     return nil
   end
 }
}
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
local rt=Runtime.new(pilot)
assert(#rt.manifest.assets==228)
local colors=rt.color_profiles
local total=0
for _,a in ipairs(rt.manifest.assets) do
 if a.kind=="terrain" then
   assert(colors[a.id] and #colors[a.id]==4)
   total=total+1
 end
end
assert(total==168,"real source-CIELAB signatures missing")
assert(rt.catalog_counts.total==228 and rt.catalog_counts.packed==228
  and rt.catalog_counts.pages==25,"lossy 228-asset manifest")
assert(#rt.manifest.atlas_pages==25 and #rt.manifest.assets==228)
local allIds={}
for _,a in ipairs(rt.manifest.assets) do
 assert(a.source_drive_id and not allIds[a.source_drive_id])
 allIds[a.source_drive_id]=true
end
assert(created==0 and decoded==0,"boot eagerly assembled an atlas")
local sprites=Sprite.new(rt,rt.manifest)
assert(created==0,"constructing SpriteBatch metadata eagerly uploaded images")
-- Terrain motif vs sprite silhouette proportions are render-only.
assert(rt.terrain_uv_scale==64,"terrain texture detail is at object scale")
local tree=Sprite.scale_for("oak",1,"tree:ratio")
local shrub=Sprite.scale_for("shrub",1,"shrub:ratio")
local conifer=Sprite.scale_for("conifer",1,"conifer:ratio")
local boulder=Sprite.scale_for("boulder",1,"rock:ratio")
local spire=Sprite.scale_for("rock_spire",1,"spire:ratio")
local stump=Sprite.scale_for("stump",1,"stump:ratio")
assert(tree>shrub*1.7 and conifer>boulder*1.45
  and spire>stump*1.8,"uneven 25D object family proportions")
assert(Sprite.scale_for("oak",.5,"tree:ratio")==tree*.5,
  "zoom must scale every object consistently")
assert(Sprite.scale_for("oak",1,"tree:ratio")==tree,
  "scale must not depend on frame ordering")
assert(rt:family(20,50)~="wetland")
assert(rt:family(220,220)=="wetland")
-- Bring in one authored route to exercise textured path coverage in
-- the actual runtime, without changing the gameplay's water query.
pilot.routes={features={
 features={{kind="path",width=18,points={{48,-40},{48,300}}}},
 signed=function(_,x,y,kind)
   if kind=="path" then return 9-math.abs(x-48) end
   return -100
 end
}}
local chunk={x=0,y=0,size=256,cx=0,cy=0,
 layers={water={vertices={{200,200},{232,200},{232,232}}}}}
local stream={visible=function() return {chunk} end}
local cam={x=0,y=0,zoom=1.2,
 project=function(_,x,y,w,h) return w/2+x,h/2+y end}
rt:draw(stream,cam,360,780)
assert(rt.built==1 and uploads>1 and rt.visible==1)
assert(chunk._25d_overlay_order and
  #chunk._25d_overlay_order.path>=1,
  "authored path must create a real dirt-texture atlas mesh")
for _,page in ipairs(chunk._25d_overlay_order.path) do
 assert(chunk._meshes["!path:"..page],
   "authored path overlay mesh missing sourced page")
end
local before=uploads
rt:draw(stream,cam,360,780)
assert(uploads==before and rt.uploads_per_frame==0)
assert(chunk._meshes==chunk._25d_meshes)
local released=0
for _,mesh in pairs(chunk._meshes) do
 mesh:release();assert(mesh.released);released=released+1
end
assert(released==before)
assert(rt.atlas_resident_pages>=1 and
  rt.atlas_estimated_gpu_bytes>=1056*396*4)
-- The boulder page is separate from the preserved pilot atlas. It must
-- assemble only when selected and keep source PNG pixels distinct.
local srcpage=rt.page_metadata["atlas_01.png"]
assert(srcpage and #srcpage.sources==2 and
  srcpage.width==264 and srcpage.height==132)
local priorDecodes=decoded
local img=rt:page("atlas_01.png")
assert(img:getDimensions()==srcpage.width, "invalid generated atlas width")
assert(decoded==priorDecodes+2 and pastes>=2)
assert(rt:page("atlas_01.png")==img,"atlas page rebuilt while cached")
-- Direct a real object to the new approved page, preserving renderer API.
local choices={}
for _,a in ipairs(sprites.families.boulder) do
 if a.page=="atlas_01.png" then choices[#choices+1]=a end
end
assert(#choices==2)
sprites.families.boulder=choices
sprites:begin_frame()
sprites:queue(g,cam,360,780,
  {x=4,y=19,id="rock:page01",kind="rock",radius=8},false)
sprites:queue(g,cam,360,780,
  {x=10000,y=10000,id="off",kind="rock",radius=8},false)
assert(sprites.visible==1 and sprites.culled==1 and
  rt.page_pins["atlas_01.png"]==1)
sprites:flush(g)
rt:prune_pages({resident={}}, {})
assert(rt.page_images["atlas_01.png"]==img and not img.released,
  "pinned sprite page evicted")
for i=1,3 do sprites:begin_frame() end
rt:prune_pages({resident={held={_25d_ground_pages={
  ["atlas_01.png"]=true}}}}, {})
assert(not img.released,"resident terrain mesh lost its atlas")
rt:prune_pages({resident={}}, {})
assert(img.released and rt.page_images["atlas_01.png"]==nil,
  "orphaned page not evicted")
local old=decoded
local reloaded=rt:page("atlas_01.png")
assert(reloaded~=img and decoded==old+2,
  "page was not reconstructed after eviction")
rt:prune_pages({resident={}}, {})
assert(reloaded.released)
assert(draws>0 and rt.atlas_resident_pages==1)
print("TERRAIN25D_RUNTIME_OK uploads="..uploads.." released="..released..
  " pages="..rt.catalog_counts.pages.." assets="..rt.catalog_counts.packed..
  " decoded="..decoded.." generated="..created)
