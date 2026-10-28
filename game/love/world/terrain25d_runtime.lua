-- Opt-in, render-only R2 terrain. Stream owns mesh release via chunk._meshes.
local Geo=require("world.terrain25d_geometry")
local Iso=require("world.iso")
local Json=require("save.json")
local Shore=require("world.terrain25d_shore")
local Materials=require("world.terrain25d_materials")
local Atlas=require("world.terrain25d_atlas")
local Runtime={}; Runtime.__index=Runtime
-- 128px source texture spans 64 world units; 32-unit mesh lattice stays
-- aligned to UV seams. Large grass/stone details no longer rival trees.
local TERRAIN_UV_SCALE=64
Runtime.terrain_uv_scale=TERRAIN_UV_SCALE
function Runtime.new(pilot)
 assert(pilot and pilot.query and pilot.topography and pilot.routes and pilot.render_options,
   "authored R2 pilot required")
 local m=Json.decode(assert(love.filesystem.read("assets/terrain25d/manifest.json")))
 assert(m.version==1 and #m.assets>=20 and m.atlas_pages[1],"25D manifest invalid")
 -- Source PNGs belong to the user and were byte-verified in GitHub.
 -- The manifest explicitly maps every runtime asset to an archived Drive ID.
 local archive=Json.decode(assert(love.filesystem.read(
   "assets/terrain25d/archive_inventory.json"),"25D source catalog unavailable"))
 assert(archive.version==1 and #archive.assets>=#m.assets,"asset archive invalid")
 local available={}
 for _,a in ipairs(archive.assets) do
   if a.review_status=="pilot_binary_verified" or
      a.review_status=="source_binary_verified" then
     available[a.source_drive_id]=a
   end
 end
 for _,a in ipairs(m.assets) do
   local source=available[a.source_drive_id]
   assert(source and source.sha256==a.sha256 and source.family==a.family
     and source.kind==a.kind and source.width==128 and source.height==128
     and source.ownership_status=="user_declared_creator_2026-10-28",
     "packed atlas material has no verified source")
 end
 local pages={}
 for _,page in ipairs(m.atlas_pages) do
   assert(type(page.filename)=="string" and
     page.filename:match("^atlas_%d+%.png$") and
     type(page.width)=="number" and page.width>0 and
     type(page.height)=="number" and page.height>0 and
     not pages[page.filename],"invalid atlas page metadata")
   pages[page.filename]=page
 end
 assert(pages["atlas_00.png"],"pilot atlas missing")
 local mapped_sources={}
 for _,page in ipairs(m.atlas_pages) do
   if page.generated_from_sources then
     assert(type(page.sources)=="table" and #page.sources>0 and
       #page.sources<=16,"invalid sourced page size")
     for _,src in ipairs(page.sources) do
       local archived=assert(available[src.source_drive_id],
         "atlas page references missing source")
       assert(src.sha256==archived.sha256 and
         src.path==archived.source_repo_path:sub(#"game/love/assets/terrain25d/"+1)
         and src.x>=0 and src.y>=0 and src.x+128<=page.width
         and src.y+128<=page.height and
         not mapped_sources[src.source_drive_id],
         "atlas page source/placement mismatch")
       mapped_sources[src.source_drive_id]=page.filename
     end
   end
 end
 local fam={}
 for _,a in ipairs(m.assets) do
   assert(pages[a.atlas_page] and type(a.uv_rect)=="table"
     and #a.uv_rect==4,"packed material missing atlas page/UV")
   if pages[a.atlas_page].generated_from_sources then
     assert(mapped_sources[a.source_drive_id]==a.atlas_page,
       "atlas UV references wrong source page")
   end
   local f=fam[a.family] or {};f[#f+1]=a;fam[a.family]=f
 end
 for _,kind in ipairs({"grass","forest","dirt","rock","wetland","oak","conifer","boulder"}) do
   assert(fam[kind] and #fam[kind]>0,"atlas material absent: "..kind)
 end
 for _,list in pairs(fam) do
   table.sort(list,function(a,b) return a.id<b.id end)
 end
 local self=setmetatable({pilot=pilot,manifest=m,families=fam,
   page_metadata=pages,page_images={},page_pins={},
   atlas_resident_pages=0,atlas_estimated_gpu_bytes=0,
   catalog_counts={total=#archive.assets,packed=#m.assets,
     pages=#m.atlas_pages},
   built=0,visible=0,draw_calls=0,uploads_per_frame=0,build_budget=1,step=32},Runtime)
 -- Keep the pilot page for current sprites; all other pages load on demand.
 self.atlas=self:page("atlas_00.png")
 return self
end
function Runtime:page(name)
 local meta=assert(self.page_metadata[name],"atlas page is not packed")
 local image=self.page_images[name]
 if not image then
   image=Atlas.load(meta)
   local w,h=image:getDimensions()
   assert(w==meta.width and h==meta.height,"atlas dimensions mismatch: "..name)
   image:setFilter("nearest","nearest");image:setWrap("clamp","clamp")
   self.page_images[name]=image
 end
 return image
end
function Runtime:pin_page(name)
 self:page(name)
 self.page_pins[name]=(self.page_pins[name] or 0)+1
end
function Runtime:unpin_page(name)
 local count=assert(self.page_pins[name],"untracked atlas page pin")
 assert(count>0,"atlas page pin underflow")
 self.page_pins[name]=count-1
end
-- Stream owns mesh release. Do not evict textures while resident meshes
-- or sprite batches still reference them.
function Runtime:prune_pages(stream,chunks)
 local used={}
 local function mark(chunk)
   for name in pairs(chunk._25d_ground_pages or {}) do used[name]=true end
 end
 if stream.resident then
   for _,chunk in pairs(stream.resident) do mark(chunk) end
 else
   for _,chunk in ipairs(chunks) do mark(chunk) end
 end
 local count,bytes=0,0
 for name,image in pairs(self.page_images) do
   if name~="atlas_00.png" and not used[name] and
     (self.page_pins[name] or 0)==0 then
     image:release()
     self.page_images[name]=nil
   else
     count=count+1
     local meta=self.page_metadata[name]
     bytes=bytes+meta.width*meta.height*4 -- RGBA8 estimate, not GPU telemetry
   end
 end
 self.atlas_resident_pages=count
 self.atlas_estimated_gpu_bytes=bytes
end
function Runtime:family(x,y)
 local q=self.pilot.query
 local s=q:sample(x,y)
 local wet=q:water_mask(x,y)
 -- The mixed Generator water scalar is not a metric distance (near [-1,1]).
 -- Only the authored river feature signed distance is in world units.
 local features=self.pilot.routes and self.pilot.routes.features
 local bank_distance=features and features:signed(x,y,"water")
 local near=wet or (type(bank_distance)=="number" and bank_distance>-8)
 return Materials.family(s,near,x,y)
end
function Runtime:prepare(chunk,checkpoint)
 assert(not chunk._25d_meshes and not chunk._meshes,"chunk already owns GPU meshes")
 local pilot=self.pilot
 local scale=pilot.render_options.height_scale or .35
 local geo=Geo.build_chunk(pilot.query,pilot.topography,{size=chunk.size,
   height_scale=scale,uv_scale=TERRAIN_UV_SCALE,ambient=.49,diffuse=.57},
   {x=chunk.x,y=chunk.y},self.step)
 -- Complete expensive authored hydrology CPU sampling before ANY GPU
 -- allocation. A partially resumed coroutine can be dropped on eviction.
 local shore=Shore.build(chunk,pilot.query,pilot.topography,pilot.routes,scale,
   checkpoint)
 if checkpoint then checkpoint() end
 local n=chunk.size/self.step
 local groups={}
 for iy=0,n-1 do for ix=0,n-1 do
   local x,y=chunk.x+(ix+.5)*self.step,chunk.y+(iy+.5)*self.step
   local family=self:family(x,y)
   local list=self.families[family]
   local a=list[Materials.variant(family,x,y,#list)]
   local group=groups[a.id]
   if not group then group={asset=a,indices={}};groups[a.id]=group end
   local i=iy*(n+1)+ix+1
   local out=group.indices
   for _,v in ipairs({i,i+1,i+n+2,i,i+n+2,i+n+1}) do out[#out+1]=v end
 end end
 local meshes,order,ground_pages={},{},{}
 for id,group in pairs(groups) do
   local vertices=Geo.love_vertices({format="terrain25d-v1",
     vertices=geo.vertices,indices=group.indices},group.asset.uv_rect)
   local page=group.asset.atlas_page
   local gpu=love.graphics.newMesh(vertices,"triangles","static")
   gpu:setTexture(self:page(page))
   meshes[id]=gpu;order[#order+1]=id;ground_pages[page]=true
 end
 table.sort(order)
 for _,layer in ipairs({"path","bank","water"}) do
   local vertices=shore[layer]
   if #vertices>0 then
     meshes["!"..layer]=love.graphics.newMesh(vertices,"triangles","static")
   end
 end
 chunk._25d_meshes=meshes;chunk._25d_ground_order=order
 chunk._25d_ground_pages=ground_pages
 chunk._meshes=meshes -- Stream:update already releases this map upon eviction.
 self.built=self.built+1
end
function Runtime:draw(stream,camera,w,h)
 assert(stream and stream.visible and camera and camera.zoom>0)
 local chunks=stream:visible()
 local clock=love.timer and love.timer.getTime
 local deadline=clock and clock()+.003
 local uploads,resumes=0,0
 for _,c in ipairs(chunks) do
   if not c._25d_meshes and uploads<self.build_budget
       and (not deadline or clock()<deadline) then
     local job=c._25d_prepare_job
     if not job then
       job=coroutine.create(function()
         self:prepare(c,function() coroutine.yield() end)
       end)
       c._25d_prepare_job=job
     end
     -- Cap resumes even if a mock/low-resolution timer never advances.
     repeat
       local ok,err=coroutine.resume(job)
       assert(ok,err)
       resumes=resumes+1
       if coroutine.status(job)=="dead" then
         c._25d_prepare_job=nil
         uploads=uploads+1
         break
       end
     until resumes>=24 or (deadline and clock()>=deadline)
     if resumes>=24 then break end
   end
 end
 self.uploads_per_frame=uploads
 local g=love.graphics
 g.clear(.075,.115,.128,1);g.push("all")
 g.translate(w/2,h/2);g.scale(camera.zoom)
 local x,y=Iso.project(camera.x,camera.y)
 g.translate(-x,-y);g.setColor(1,1,1,1)
 local calls,visible=0,0
 for _,c in ipairs(chunks) do
   if c._25d_meshes then
     visible=visible+1
     for _,id in ipairs(c._25d_ground_order) do
       g.draw(c._25d_meshes[id]);calls=calls+1
     end
   end
 end
 for _,layer in ipairs({"!path","!bank","!water"}) do
   for _,c in ipairs(chunks) do
     if c._25d_meshes and c._25d_meshes[layer] then
       g.draw(c._25d_meshes[layer]);calls=calls+1
     end
   end
 end
 g.pop()
 self:prune_pages(stream,chunks)
 self.visible,self.draw_calls=visible,calls
 return visible
end
return Runtime
