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
 local profiles=Json.decode(assert(love.filesystem.read(
   "assets/terrain25d/color_profiles.json"),"25D CIELAB catalog unavailable"))
 assert(profiles.version==1 and profiles.space=="CIELAB-D65-mean-L-std"
   and type(profiles.assets)=="table","invalid material color profile")
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
 local profiled=0
 for _,a in ipairs(m.assets) do
   if a.kind=="terrain" then
     local color=profiles.assets[a.id]
     assert(type(color)=="table" and #color==4,
       "missing authored CIELAB color/contrast signature: "..a.id)
     profiled=profiled+1
   end
 end
 assert(profiled==168,"lossy ground color profile")
 local self=setmetatable({pilot=pilot,manifest=m,families=fam,
   color_profiles=profiles.assets,
   family_centres=Materials.centres(fam,profiles.assets),
   authored_boundaries=Materials.boundaries(pilot.query,pilot.authored_map),
   page_metadata=pages,page_images={},page_pins={},
   atlas_resident_pages=0,atlas_estimated_gpu_bytes=0,
   catalog_counts={total=#archive.assets,packed=#m.assets,
     pages=#m.atlas_pages},
   built=0,visible=0,draw_calls=0,transition_triangles=0,
   uploads_per_frame=0,build_budget=1,step=32},Runtime)
 -- Keep the pilot page for current sprites; all other pages load on demand.
 self.atlas=self:page("atlas_00.png")
 if os and os.getenv and os.getenv("OSMAN_25D_SMOKE")=="1" then
   print("TERRAIN25D_AUTHORED_BORDERS="..#self.authored_boundaries)
 end
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
-- Select real atlas pixels by their measured CIELAB+contrast distance.
-- Neighbour-family L*a*b* values affect ONLY which source ID is used,
-- never the RGB output, opacity, or physics world state.
function Runtime:material(family,x,y,neighbor_family,proximity)
 local list=assert(self.families[family],"unknown material family: "..tostring(family))
 -- Only source-ID selection changes. No RGB interpolation/blur is performed.
 local weight=proximity and (.28+.64*proximity) or nil
 return Materials.choose(family,x,y,list,self.color_profiles,
   neighbor_family and self.family_centres[neighbor_family],weight)
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
 local groups,ground_pages={},{}

 local function emit(asset,tri,group_map)
   local page=asset.atlas_page
   local group=group_map[page]
   if not group then group={vertices={}};group_map[page]=group end
   local verts=Geo.love_vertices({format="terrain25d-v1",
     vertices=tri,indices={1,2,3}},asset.uv_rect)
   local out=group.vertices
   for _,v in ipairs(verts) do out[#out+1]=v end
   ground_pages[page]=true
 end
 local function midpoint(a,b)
   local v={}
   for i=1,#a do v[i]=(a[i]+b[i])*.5 end
   return v
 end
 -- Bilinear interpolation across the *existing* 32-unit geometry.
 -- Every 8-unit microcell shares the exact same 3D edge coordinates
 -- as its neighbour, including across resident chunk boundaries.
 local function tessellate(a,b,c,d)
   local vertices={}
   for iy=0,4 do
     for ix=0,4 do
       local u,v=ix/4,iy/4
       local uv=(1-u)*(1-v)
       local bv=u*(1-v)
       local cv=(1-u)*v
       local dv=u*v
       local w={}
       for k=1,#a do
         w[k]=a[k]*uv+b[k]*bv+c[k]*cv+d[k]*dv
       end
       vertices[#vertices+1]=w
     end
   end
   return vertices
 end
 local function jittered_family(x,y)
   local delta=Materials.edge_jitter(x,y,1301)
   return self:family(x+delta*.65,y+delta*.37)
 end
 local function choose(x,y,boundary)
   local f=jittered_family(x,y)
   local other,proximity
   -- Authored border has broad, spatially coherent source-ID islands,
   -- without smoothing a pixel or changing gameplay's biome classification.
   f,other,proximity=Materials.interleaved_family(f,boundary,x,y)
   -- Inside a biome, replace obsolete 384-unit clearing silhouettes
   -- with many small source-ID islands whose coverage varies continuously.
   -- Authored edge bands take precedence over interior undergrowth.
   if not proximity or proximity==0 then
     f,other,proximity=Materials.interior_family(f,x,y)
   end
   if not other then
     for _,d in ipairs({{14,0},{-14,0},{0,14},{0,-14}}) do
       local k=jittered_family(x+d[1],y+d[2])
       if k~=f then other=k;break end
     end
   end
   return self:material(f,x,y,other,proximity)
 end
 for iy=0,n-1 do
   for ix=0,n-1 do
     local x,y=chunk.x+ix*self.step,chunk.y+iy*self.step
     -- One polygon-edge search per cell. All micro-triangle decisions use
     -- the same world-space edge, so mesh building stays bounded.
     local boundary,edge_distance=Materials.nearest_boundary(
       self.authored_boundaries,x+self.step*.5,y+self.step*.5)
     local i=iy*(n+1)+ix+1
     local a,b,c,d=geo.vertices[i],geo.vertices[i+1],
       geo.vertices[i+n+1],geo.vertices[i+n+2]
     local checks={
       choose(x+8,y+8,boundary),choose(x+24,y+8,boundary),
       choose(x+8,y+24,boundary),choose(x+24,y+24,boundary)
     }
     local split=false
     local signature=self.color_profiles[checks[1].id]
     for j=2,4 do
       local other=self.color_profiles[checks[j].id]
       if checks[j].family~=checks[1].family or
         (signature and other and
         (signature[1]-other[1])^2+(signature[2]-other[2])^2+
          (signature[3]-other[3])^2>36) then
         split=true;break
       end
     end
     if boundary and edge_distance<146 then
       -- Near authored biome edges, use 8-unit source-ID mosaic samples,
       -- not 32-unit disk-like patches. Each microtriangle is fully opaque
       -- and carries a single untouched source texture (no pixel blending).
       local v=tessellate(a,b,c,d)
       for my=0,3 do
         for mx=0,3 do
           local i0=my*5+mx+1
           local p,q,r,t=v[i0],v[i0+1],v[i0+5],v[i0+6]
           local ax,ay=(p[9]+q[9]+t[9])/3,
                       (p[10]+q[10]+t[10])/3
           local bx,by=(p[9]+t[9]+r[9])/3,
                       (p[10]+t[10]+r[10])/3
           emit(choose(ax,ay,boundary),{p,q,t},groups)
           emit(choose(bx,by,boundary),{p,t,r},groups)
         end
       end
       self.transition_triangles=self.transition_triangles+32
     elseif not split then
       local asset=choose(x+16,y+16,boundary)
       emit(asset,{a,b,d},groups)
       emit(asset,{a,d,c},groups)
     else
       -- Existing sharp boundary triangles for smaller, non-authored
       -- discontinuities such as forest understory material variations.
       local ab,bd,dc,ca=midpoint(a,b),midpoint(b,d),
         midpoint(d,c),midpoint(c,a)
       local centre=midpoint(ab,dc)
       local ring={a,ab,b,bd,d,dc,c,ca}
       for j=1,8 do
         local v1,v2=ring[j],ring[j%8+1]
         local wx=(centre[9]+v1[9]+v2[9])/3
         local wy=(centre[10]+v1[10]+v2[10])/3
         emit(choose(wx,wy,boundary),{centre,v1,v2},groups)
       end
     end
   end
   if checkpoint and iy%2==1 then checkpoint() end
 end
 local meshes,order={},{}
 for page,group in pairs(groups) do
   local gpu=love.graphics.newMesh(group.vertices,"triangles","static")
   gpu:setTexture(self:page(page))
   meshes[page]=gpu;order[#order+1]=page
 end
 table.sort(order)

 -- Render existing authored 8-unit Marching contours with actual atlas
 -- dirt/path and wetland source pixels. Every vertex is fully opaque;
 -- the masks are sharp, and never smear into neighbouring textures.
 local overlays={path={},bank={}}
 local overlay_order={path={},bank={}}
 for _,layer in ipairs({"path","bank"}) do
   local source=shore[layer]
   local group=overlays[layer]
   local family=layer=="path" and "dirt" or "wetland"
   for k=1,#source,3 do
     local v1,v2,v3=source[k],source[k+1],source[k+2]
     local x=(v1[3]+v2[3]+v3[3])*64/3
     local y=(v1[4]+v2[4]+v3[4])*64/3
     local asset=self:material(family,x,y)
     emit(asset,{v1,v2,v3},group)
   end
   for page,item in pairs(group) do
     local gpu=love.graphics.newMesh(item.vertices,"triangles","static")
     gpu:setTexture(self:page(page))
     meshes["!"..layer..":"..page]=gpu
     overlay_order[layer][#overlay_order[layer]+1]=page
   end
   table.sort(overlay_order[layer])
 end
 if #shore.water>0 then
   meshes["!water"]=love.graphics.newMesh(
     shore.water,"triangles","static")
 end
 chunk._25d_overlay_order=overlay_order
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
 for _,layer in ipairs({"path","bank"}) do
   for _,c in ipairs(chunks) do
     if c._25d_meshes and c._25d_overlay_order then
       for _,page in ipairs(c._25d_overlay_order[layer]) do
         g.draw(c._25d_meshes["!"..layer..":"..page]);calls=calls+1
       end
     end
   end
 end
 for _,c in ipairs(chunks) do
   if c._25d_meshes and c._25d_meshes["!water"] then
     g.draw(c._25d_meshes["!water"]);calls=calls+1
   end
 end
 g.pop()
 self:prune_pages(stream,chunks)
 self.visible,self.draw_calls=visible,calls
 return visible
end
return Runtime
