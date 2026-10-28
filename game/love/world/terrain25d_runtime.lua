-- Opt-in, render-only R2 terrain. Stream owns mesh release via chunk._meshes.
local Geo=require("world.terrain25d_geometry")
local Iso=require("world.iso")
local Json=require("save.json")
local Shore=require("world.terrain25d_shore")
local Materials=require("world.terrain25d_materials")
local Runtime={}; Runtime.__index=Runtime
function Runtime.new(pilot)
 assert(pilot and pilot.query and pilot.topography and pilot.routes and pilot.render_options,
   "authored R2 pilot required")
 local m=Json.decode(assert(love.filesystem.read("assets/terrain25d/manifest.json")))
 assert(m.version==1 and #m.assets>=20 and m.atlas_pages[1],"25D manifest invalid")
 -- Keep all Drive IDs in the archive, but accept GPU assets ONLY if reviewed
 -- and physically packed. Metadata-only assets must never be fake-loaded.
 local archive=Json.decode(assert(love.filesystem.read(
   "assets/terrain25d/archive_inventory.json"),"25D source catalog unavailable"))
 assert(archive.version==1 and #archive.assets>=#m.assets,"asset archive invalid")
 local available={}
 for _,a in ipairs(archive.assets) do
   if a.review_status=="pilot_binary_verified" then
     available[a.source_drive_id]=a
   end
 end
 for _,a in ipairs(m.assets) do
   local source=available[a.source_drive_id]
   assert(source and source.sha256==a.sha256 and source.family==a.family,
     "packed atlas material not approved in archive")
 end
 local fam={}
 for _,a in ipairs(m.assets) do
   if a.atlas_page=="atlas_00.png" and a.uv_rect then
     local f=fam[a.family] or {};f[#f+1]=a;fam[a.family]=f
   end
 end
 for _,kind in ipairs({"grass","forest","dirt","rock","wetland","oak","conifer","boulder"}) do
   assert(fam[kind] and #fam[kind]>0,"atlas material absent: "..kind)
   table.sort(fam[kind],function(a,b) return a.id<b.id end)
 end
 local image=love.graphics.newImage("assets/terrain25d/atlas_00.png")
 local w,h=image:getDimensions()
 assert(w==m.atlas_pages[1].width and h==m.atlas_pages[1].height,"atlas dimensions mismatch")
 image:setFilter("nearest","nearest");image:setWrap("clamp","clamp")
 return setmetatable({pilot=pilot,manifest=m,atlas=image,families=fam,
   catalog_counts={total=#archive.assets,packed=#m.assets},
   built=0,visible=0,draw_calls=0,uploads_per_frame=0,build_budget=1,step=32},Runtime)
end
function Runtime:family(x,y)
 local q=self.pilot.query
 local s=q:sample(x,y)
 local wet,dist=q:water_mask(x,y)
 return Materials.family(s,wet or (type(dist)=="number" and dist>-12),x,y)
end
function Runtime:prepare(chunk,checkpoint)
 assert(not chunk._25d_meshes and not chunk._meshes,"chunk already owns GPU meshes")
 local pilot=self.pilot
 local scale=pilot.render_options.height_scale or .35
 local geo=Geo.build_chunk(pilot.query,pilot.topography,{size=chunk.size,
   height_scale=scale,uv_scale=128,ambient=.49,diffuse=.57},
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
 local meshes,order={},{}
 for id,group in pairs(groups) do
   local vertices=Geo.love_vertices({format="terrain25d-v1",
     vertices=geo.vertices,indices=group.indices},group.asset.uv_rect)
   local gpu=love.graphics.newMesh(vertices,"triangles","static")
   gpu:setTexture(self.atlas)
   meshes[id]=gpu;order[#order+1]=id
 end
 table.sort(order)
 for _,layer in ipairs({"path","bank","water"}) do
   local vertices=shore[layer]
   if #vertices>0 then
     meshes["!"..layer]=love.graphics.newMesh(vertices,"triangles","static")
   end
 end
 chunk._25d_meshes=meshes;chunk._25d_ground_order=order
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
 self.visible,self.draw_calls=visible,calls
 return visible
end
return Runtime
