-- Opt-in, render-only R2 terrain. Stream owns mesh release via chunk._meshes.
local Geo=require("world.terrain25d_geometry")
local Iso=require("world.iso")
local Json=require("save.json")
local Shore=require("world.terrain25d_shore")
local Materials=require("world.terrain25d_materials")
local Atlas=require("world.terrain25d_atlas")
local Sun=require("world.terrain25d_sun")
local Reveal=require("world.terrain25d_reveal")
local Baked=require("world.terrain25d_baked")
local Runtime={}; Runtime.__index=Runtime
-- 128px source texture spans 64 world units; 32-unit mesh lattice stays
-- aligned to UV seams. Large grass/stone details no longer rival trees.
local TERRAIN_UV_SCALE=64
Runtime.terrain_uv_scale=TERRAIN_UV_SCALE

local function clamp01(x)
 return x<0 and 0 or (x>1 and 1 or x)
end
local function ease_out_cubic(t)
 t=clamp01(t)
 return 1-(1-t)^3
end
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
 local initial=os.getenv("OSMAN_25D_SUN_HOUR")
 local initial_hour=initial and tonumber(initial) or Sun.initial_hour
 assert(initial_hour and initial_hour>=0 and initial_hour<24,
   "invalid opt-in visual sun hour (0..24)")
 local compact=m.compact_mobile_atlas==true
 local self=setmetatable({pilot=pilot,manifest=m,families=fam,
   compact=compact,compact_pending={},compact_ready=not compact,
   compact_started_at=love.timer and love.timer.getTime and love.timer.getTime() or 0,
   creation_enabled=compact,
   sun_hour=initial_hour,sun=Sun.at(initial_hour),
   sun_day_seconds=Sun.day_seconds,sun_locked=initial~=nil,
   color_profiles=profiles.assets,
   family_centres=Materials.centres(fam,profiles.assets),
   authored_boundaries=Materials.boundaries(pilot.query,pilot.authored_map),
   page_metadata=pages,page_images={},page_pins={},
   atlas_resident_pages=0,atlas_estimated_gpu_bytes=0,
   catalog_counts={total=#archive.assets,packed=#m.assets,
     pages=#m.atlas_pages},
   built=0,visible=0,draw_calls=0,transition_triangles=0,
   baked_written=0,baked_loaded=0,
   bake_mode=os.getenv("OSMAN_25D_BAKE")=="1",
   uploads_per_frame=0,build_budget=3,step=32,
   build_time_budget=.002,build_time_budget_idle=.0035,
   moving_resume_cap=5,idle_resume_cap=14,
   binary_worker=nil,binary_pending={},binary_ready={},binary_inflight=0,
   binary_max_inflight=12,
   reveal_seconds=.85,last_camera_x=nil,last_camera_y=nil,
   frame_now=0,reveal_shader=compact and Reveal.new() or nil},Runtime)
 -- Separate immutable terrain byte decompression from graphics uploads.
 -- CI bake/verify and forced JSON tests continue using the original path.
 if not self.bake_mode and os.getenv('TAMU_25D_FULL_AUTHORED_BAKE')~='1'
     and os.getenv('OSMAN_25D_BAKE_VERIFY')~='1'
     and os.getenv('TAMU_25D_FORCE_JSON')~='1'
     and love.thread and love.thread.newThread then
   self.binary_worker=love.thread.newThread('world/terrain25d_binary_worker.lua')
   self.binary_worker:start()
 end
 -- Compact mobile atlas: decoded in a real LÖVE worker thread. Main only
 -- performs one bounded GPU upload per frame, with no 228 source PNG paste.
 if compact then
   if love.thread and love.thread.newThread then
     self.decode_thread=love.thread.newThread('world/terrain25d_decode_worker.lua')
     self.decode_thread:start()
     local req=love.thread.getChannel('osman25d:decode:req')
     for _,p in ipairs(m.atlas_pages) do
       self.compact_pending[p.filename]=true
       req:push(p.filename)
     end
     req:push('!stop')
   else
     -- Headless tests: exact same baked PNGs, no thread API available.
     for _,p in ipairs(m.atlas_pages) do self.compact_pending[p.filename]=true end
   end
 else
   self.atlas=self:page('atlas_00.png')
 end
 if os and os.getenv and os.getenv("OSMAN_25D_SMOKE")=="1" then
   print("TERRAIN25D_AUTHORED_BORDERS="..#self.authored_boundaries)
 end
 return self
end
function Runtime:poll_compact_images()
 if not self.compact or self.compact_ready then return true end
 local uploaded=0
 for _,meta in ipairs(self.manifest.atlas_pages) do
   local name=meta.filename
   if self.compact_pending[name] then
     local image
     if self.decode_thread then
       local data=love.thread.getChannel('osman25d:decode:'..name):pop()
       if type(data)=='string' then
         print('OSMAN_25D_ATLAS_WORKER_ERROR '..data)
       elseif data then
         image=love.graphics.newImage(data)
         if data.release then data:release() end
       end
       -- On Android a thread can terminate or its ImageData message may
       -- never arrive. Never leave the default world blank indefinitely.
       local now=love.timer and love.timer.getTime and love.timer.getTime() or 0
       local thread_error=self.decode_thread.getError and self.decode_thread:getError()
       local expired=now-self.compact_started_at>3
       if not image and (thread_error or expired or type(data)=='string') then
         if thread_error then print('OSMAN_25D_ATLAS_THREAD_ERROR '..thread_error) end
         image=Atlas.load(meta)
         print('OSMAN_25D_ATLAS_MAIN_FALLBACK '..name)
       end
     else
       image=Atlas.load(meta)
     end
     if image then
       local w,h=image:getDimensions()
       assert(w==meta.width and h==meta.height,'compact atlas dimension mismatch')
       image:setFilter('nearest','nearest')
       image:setWrap('clamp','clamp')
       self.page_images[name]=image
       if name=='atlas_01.png' then
         self.object_atlas_ready_time=love.timer and love.timer.getTime() or 0
       end
       -- Both images are shared by all resident chunks/sprites; stay pinned
       -- for the duration of the portable scene (15.5 MiB RGBA8 ceiling).
       self.page_pins[name]=(self.page_pins[name] or 0)+1
       self.compact_pending[name]=nil
       uploaded=uploaded+1
       if uploaded>=1 then break end
     end
   end
 end
 self.compact_ready=next(self.compact_pending)==nil
 -- All 168 ground sources are already baked into atlas_00. Begin terrain
 -- preparation as soon as THIS page is decoded. Atlas_01 objects finish
 -- asynchronously; don't hold the first playable terrain frame for them.
 return self.page_images['atlas_00.png']~=nil
end
function Runtime:chunk_reveal(chunk,now)
 if not self.creation_enabled then return 1 end
 local started=chunk and chunk._25d_reveal_start
 if not started then return 1 end
 return clamp01((now-started)/self.reveal_seconds)
end
-- These values are used by the ground shader and per-object vertex reveal.
-- The visual timer never touches generator, game calendar or save state.
function Runtime:object_reveal(x,y)
 if not self.creation_enabled or
    not (self.stream and self.current_camera) then return 1 end
 local cx,cy=math.floor(x/256),math.floor(y/256)
 local chunk=self.stream:get_loaded(cx,cy)
 if not chunk or not chunk._25d_meshes then return 0 end
 local started=chunk._25d_reveal_start
 if not started then return 1 end
 local effective_start=math.max(started,self.object_atlas_ready_time or started)
 local elapsed=math.max(0,self.frame_now-effective_start)
 -- Same pixel-wave radius as the terrain shader, centred on the
 -- corresponding chunk rather than its corner or the camera origin.
 local zoom=self.current_camera.zoom
 local ox,oy=(cx+.5)*chunk.size,(cy+.5)*chunk.size
 local dx,dy=Iso.project(x-ox,y-oy)
 local distance=math.sqrt(dx*dx+dy*dy)*zoom
 local radius=chunk.size*.707106781186548*zoom+32*zoom
 local front=clamp01(elapsed/self.reveal_seconds)*radius
 local feather=math.max(12,18*zoom)
 return clamp01((front-distance+feather)/feather)
end
function Runtime:objects_fully_revealed(objects)
 for _,o in ipairs(objects) do
   if self:object_reveal(o.x,o.y)<.999 then return false end
 end
 return true
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
-- The clock is rendering-only. No source game-world or Stage6 time is changed.
function Runtime:set_sun_hour(hour)
 local s=Sun.at(hour)
 self.sun_hour=s.hour
 self.sun=s
end
function Runtime:advance_sun(dt)
 assert(type(dt)=="number" and dt==dt and dt>=0 and dt<math.huge,
   "invalid 25D visual tick")
 if not self.sun_locked then
   self:set_sun_hour(self.sun_hour+dt*24/self.sun_day_seconds)
 end
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
function Runtime:prepare(chunk,checkpoint,cpu_only)
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
 local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
 local function capture(v)
   local x,y=v[1],v[2]
   if x<minx then minx=x end
   if x>maxx then maxx=x end
   if y<miny then miny=y end
   if y>maxy then maxy=y end
 end

 local function emit(asset,tri,group_map)
   local page=asset.atlas_page
   local group=group_map[page]
   if not group then group={vertices={}};group_map[page]=group end
   local verts=Geo.love_vertices({format="terrain25d-v1",
     vertices=tri,indices={1,2,3}},asset.uv_rect)
   local out=group.vertices
   for _,v in ipairs(verts) do
     out[#out+1]=v
     capture(v)
   end
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
         if checkpoint then checkpoint() end
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
         if checkpoint and j%4==0 then checkpoint() end
       end
     end
     if checkpoint then checkpoint() end
   end
   if checkpoint then checkpoint() end
 end
 local meshes,order={},{}
 if not cpu_only then chunk._25d_staging_meshes=meshes end
 for page,group in pairs(groups) do
   if cpu_only then
     meshes[page]=group.vertices
   else
     local gpu=love.graphics.newMesh(group.vertices,"triangles","static")
     gpu:setTexture(self:page(page))
     meshes[page]=gpu
   end
   order[#order+1]=page
   if checkpoint then checkpoint() end
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
     if checkpoint and k%24==1 then checkpoint() end
   end
   for page,item in pairs(group) do
     if cpu_only then
       meshes["!"..layer..":"..page]=item.vertices
     else
       local gpu=love.graphics.newMesh(item.vertices,"triangles","static")
       gpu:setTexture(self:page(page))
       meshes["!"..layer..":"..page]=gpu
     end
     overlay_order[layer][#overlay_order[layer]+1]=page
     if checkpoint then checkpoint() end
   end
   table.sort(overlay_order[layer])
 end
 if #shore.water>0 then
   for _,v in ipairs(shore.water) do capture(v) end
   if cpu_only then meshes["!water"]=shore.water
   else meshes["!water"]=love.graphics.newMesh(
     shore.water,"triangles","static") end
   if checkpoint then checkpoint() end
 end
 assert(minx<=maxx and miny<=maxy,"empty 25D render bounds")
 if cpu_only then
   return {meshes=meshes,bounds={minx,miny,maxx,maxy},
     ground_order=order,overlay_order=overlay_order,
     ground_pages=ground_pages}
 end
 chunk._25d_bounds={minx,miny,maxx,maxy}
 chunk._25d_overlay_order=overlay_order
 chunk._25d_meshes=meshes;chunk._25d_ground_order=order
 chunk._25d_ground_pages=ground_pages
 chunk._meshes=meshes -- Stream:update already releases this map upon eviction.
 chunk._25d_staging_meshes=nil
 chunk._25d_reveal_start=love.timer and love.timer.getTime() or 0
 self.built=self.built+1
end
-- CPU worker context: same reviewed material selection and authored R2
-- geometry, but no GPU/shader creation or image decoding.
function Runtime.cpu_new(pilot)
 local m=Json.decode(assert(love.filesystem.read(
   'assets/terrain25d/manifest.json')))
 local profiles=Json.decode(assert(love.filesystem.read(
   'assets/terrain25d/color_profiles.json')))
 local families={}
 for _,asset in ipairs(m.assets) do
   local group=families[asset.family] or {}
   group[#group+1]=asset
   families[asset.family]=group
 end
 for _,group in pairs(families) do
   table.sort(group,function(a,b)return a.id<b.id end)
 end
 return setmetatable({pilot=pilot,manifest=m,families=families,
   color_profiles=profiles.assets,
   family_centres=Materials.centres(families,profiles.assets),
   authored_boundaries=Materials.boundaries(pilot.query,pilot.authored_map),
   transition_triangles=0,step=32},Runtime)
end
-- CI-only immutable authored polygon sweep. The huge worldmap bounds are
-- design-only; never bake 16K+ procedural tiles as if authored content.
function Runtime:bake_authored_step()
 if not self.authored_bake_queue then
   local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
   for _,region in ipairs(self.pilot.authored_map.regions or {}) do
     for _,point in ipairs(region.polygon or {}) do
       minx=math.min(minx,point[1]);maxx=math.max(maxx,point[1])
       miny=math.min(miny,point[2]);maxy=math.max(maxy,point[2])
     end
   end
   assert(minx<maxx and miny<maxy,'no authored polygon footprint')
   local margin=3 -- three full chunks beyond authored polygon in each direction
   local x0=math.floor(minx/256)-margin
   local x1=math.floor(maxx/256)+margin
   local y0=math.floor(miny/256)-margin
   local y1=math.floor(maxy/256)+margin
   local queue={}
   for cy=y0,y1 do for cx=x0,x1 do
     queue[#queue+1]={cx=cx,cy=cy,x=cx*256,y=cy*256,
       key=cx..':'..cy,size=256,layers={}}
   end end
   self.authored_bake_queue=queue
   self.authored_bake_index=1
   print(string.format('TAMU_AUTHORED_BAKE_PLAN chunks=%d cx=%d..%d cy=%d..%d',
     #queue,x0,x1,y0,y1))
 end
 local index=self.authored_bake_index
 local queue=self.authored_bake_queue
 if index>#queue then return true end
 -- The offline authored bake and the runtime worker must use the same
 -- canonical CPU geometry and byte packing. Do not round-trip through
 -- newMesh:getVertex: GPU vertex/color quantization may differ.
 self.authored_cpu=self.authored_cpu or Runtime.cpu_new(self.pilot)
 local chunk=queue[index]
 local prepared=self.authored_cpu:prepare(chunk,nil,true)
 local bytes=Baked.pack_cpu(self.authored_cpu,chunk,prepared)
 assert(love.filesystem.createDirectory('25d-bake/'))
 local base=('25d-bake/c_%d_%d'):format(chunk.cx,chunk.cy)
 assert(love.filesystem.write(base..'.meta.json',bytes.meta))
 assert(love.filesystem.write(base..'.verts.z',
   love.data.compress('string','zlib',bytes.raw,6)))
 self.authored_bake_index=index+1
 if index%10==0 or index==#queue then
   print(string.format('TAMU_AUTHORED_BAKE_PROGRESS done=%d total=%d',
     index,#queue))
   io.stdout:flush()
 end
 return index==#queue
end
function Runtime:poll_binary_results()
 if not self.binary_worker then return end
 local ready=love.thread.getChannel('tamu25d:binary:ready')
 for i=1,8 do
   local item=ready:pop()
   if not item then break end
   -- A previously cancelled worker result cannot fulfill a newer request.
   if item.ticket and self.binary_pending[item.key]==item.ticket then
     self.binary_pending[item.key]=nil
     self.binary_inflight=math.max(0,self.binary_inflight-1)
     self.binary_ready[item.key]=item
   end
 end
end
function Runtime:enqueue_binary(chunks)
 if not self.binary_worker then return end
 local worker_error=self.binary_worker.getError and
   self.binary_worker:getError()
 if worker_error then
   print('TAMU_BINARY_THREAD_ERROR '..tostring(worker_error))
   self.binary_worker=nil
   self.binary_pending={}
   self.binary_ready={}
   self.binary_inflight=0
   return
 end
 -- Visible chunks are first in Stream:needed. Cancel queued offscreen
 -- work that is no longer wanted instead of starving the newest viewport
 -- behind the fixed in-flight cap. In-progress worker replies use tickets.
 local wanted={}
 for _,c in ipairs(chunks) do wanted[c.key]=true end
 for key in pairs(self.binary_ready) do
   if not wanted[key] then self.binary_ready[key]=nil end
 end
 local requests=love.thread.getChannel('tamu25d:binary:requests')
 local stale=false
 for key in pairs(self.binary_pending) do
   if not wanted[key] then stale=true;break end
 end
 if stale then
   -- A disappearing halo cell must not cancel unrelated visible work.
   -- Drain only queued requests; worker-owned requests remain tracked
   -- by their tickets until poll_binary_results validates them.
   local keep={}
   while true do
     local item=requests:pop()
     if not item then break end
     local key=tostring(item.cx)..':'..tostring(item.cy)
     if wanted[key] and self.binary_pending[key]==item.ticket then
       keep[#keep+1]=item
     end
   end
   for _,item in ipairs(keep) do requests:push(item) end
   local count=0
   for key in pairs(self.binary_pending) do
     if wanted[key] then count=count+1
     else self.binary_pending[key]=nil end
   end
   self.binary_inflight=count
 end
 for _,c in ipairs(chunks) do
   if self.binary_inflight>=self.binary_max_inflight then break end
   if not c._25d_meshes and not c._25d_prepare_job and
      not self.binary_pending[c.key] and not self.binary_ready[c.key] then
     self.binary_ticket=(self.binary_ticket or 0)+1
     local ticket=self.binary_ticket
     self.binary_pending[c.key]=ticket
     self.binary_inflight=self.binary_inflight+1
     requests:push({cx=c.cx,cy=c.cy,ticket=ticket})
   end
 end
end
-- Stable-view render-only aggregation. The original meshes remain authoritative
-- and owned by Stream. Aggregates preserve the exact pass and page ordering.
local function same_chunks(a,b,meshes)
 if not a or #a~=#b then return false end
 for i,c in ipairs(a) do
   if c~=b[i] or c._25d_meshes~=meshes[i] then return false end
 end
 return true
end
local function release_merged(cache)
 if not cache then return end
 for _,entry in ipairs(cache) do
   if entry.owned and entry.mesh.release then entry.mesh:release() end
 end
end
local function flatten_pass(chunks,layer)
 local runs,group={},nil
 local function append(mesh,page)
   if not group or group.page~=page then
     group={page=page,meshes={}}
     runs[#runs+1]=group
   end
   group.meshes[#group.meshes+1]=mesh
 end
 for _,c in ipairs(chunks) do
   if c._25d_meshes then
     if layer=='ground' then
       for _,page in ipairs(c._25d_ground_order) do
         append(c._25d_meshes[page],page)
       end
     elseif layer=='water' then
       if c._25d_meshes['!water'] then append(c._25d_meshes['!water'],'!water') end
     else
       for _,page in ipairs((c._25d_overlay_order or {})[layer] or {}) do
         append(c._25d_meshes['!'..layer..':'..page],page)
       end
     end
   end
 end
 return runs
end
local function aggregate_pass(runtime,runs,output)
 assert(output and #output==0,'empty owned mesh staging required')
 for _,run in ipairs(runs) do
   if #run.meshes<2 then
     output[#output+1]={mesh=run.meshes[1],owned=false}
   else
     local count=0
     for _,mesh in ipairs(run.meshes) do count=count+mesh:getVertexCount() end
     -- Bound temporary CPU/GPU duplication on mobile; oversized runs fall
     -- back to their original meshes without losing draw order.
     if count>96000 then
       for _,mesh in ipairs(run.meshes) do output[#output+1]={mesh=mesh,owned=false} end
     else
       local vertices={}
       for _,mesh in ipairs(run.meshes) do
         for i=1,mesh:getVertexCount() do
           vertices[#vertices+1]={mesh:getVertex(i)}
           if #vertices%1024==0 then coroutine.yield() end
         end
       end
       local merged=love.graphics.newMesh(vertices,'triangles','static')
       if run.page~='!water' then merged:setTexture(runtime:page(run.page)) end
       output[#output+1]={mesh=merged,owned=true}
       coroutine.yield()
     end
   end
 end
 return output
end
function Runtime:update_ground_batch(draw_chunks,now)
 if not self.compact or os.getenv('TAMU_DISABLE_TERRAIN_BATCH')=='1' then return nil end
 for _,c in ipairs(draw_chunks) do
   if not c._25d_meshes or self:chunk_reveal(c,now)<.999 then
     self:invalidate_ground_batch()
     return nil
   end
 end
 local previous=self.ground_batch_view
 if not same_chunks(previous,draw_chunks,self.ground_batch_meshes or {}) then
   self:invalidate_ground_batch()
   self.ground_batch_view={}
   self.ground_batch_meshes={}
   for i,c in ipairs(draw_chunks) do
     self.ground_batch_view[i]=c
     self.ground_batch_meshes[i]=c._25d_meshes
   end
   self.ground_batch_stable=0
   return nil
 end
 self.ground_batch_stable=(self.ground_batch_stable or 0)+1
 if self.ground_batch then return self.ground_batch end
 if self.ground_batch_stable<12 then return nil end
 if not self.ground_batch_job then
   self.ground_batch_staging={}
   self.ground_batch_job=coroutine.create(function()
     for _,layer in ipairs({'ground','path','bank','water'}) do
       local output={}
       self.ground_batch_staging[layer]=output
       aggregate_pass(self,flatten_pass(draw_chunks,layer),output)
     end
   end)
 end
 local start=love.timer.getTime()
 repeat
   local ok,err=coroutine.resume(self.ground_batch_job)
   if not ok then
     self:invalidate_ground_batch()
     print('TAMU_TERRAIN_BATCH_REJECT '..tostring(err))
     return nil
   end
   if coroutine.status(self.ground_batch_job)=='dead' then
     self.ground_batch=self.ground_batch_staging
     self.ground_batch_staging=nil
     self.ground_batch_job=nil
     return self.ground_batch
   end
 until love.timer.getTime()-start>=.001
 return nil
end
function Runtime:invalidate_ground_batch()
 if self.ground_batch then
   for _,layer in ipairs({'ground','path','bank','water'}) do
     release_merged(self.ground_batch[layer])
   end
 end
 if self.ground_batch_staging then
   for _,layer in ipairs({'ground','path','bank','water'}) do
     release_merged(self.ground_batch_staging[layer])
   end
 end
 self.ground_batch=nil
 self.ground_batch_staging=nil
 self.ground_batch_job=nil
 self.ground_batch_view=nil
 self.ground_batch_meshes=nil
 self.ground_batch_stable=0
end
function Runtime:draw(stream,camera,w,h)
 assert(stream and stream.visible and camera and camera.zoom>0)
 local chunks=stream:visible()
 self:poll_binary_results()
 self:enqueue_binary(chunks)
 -- WALK_PROBE: distinguish CPU-ready arrival from GPU upload selection.
 -- This instrumentation is inactive outside the existing probe environment.
 local walk_probe=os.getenv('TAMU_25D_WALK_PROBE')=='1'
 if walk_probe then
   self.walk_probe_frame=(self.walk_probe_frame or 0)+1
   self.walk_ready_since=self.walk_ready_since or {}
   for key in pairs(self.binary_ready) do
     if not self.walk_ready_since[key] then
       self.walk_ready_since[key]=self.walk_probe_frame
     end
   end
   for key in pairs(self.walk_ready_since) do
     if not self.binary_ready[key] then self.walk_ready_since[key]=nil end
   end
 end
 self.stream=stream
 self.current_camera=camera
 local image_ready=self:poll_compact_images()
 local clock=love.timer and love.timer.getTime
 local now=clock and clock() or 0
 self.frame_now=now
 local motion=0
 if self.last_camera_x then
   motion=math.abs(camera.x-self.last_camera_x)+math.abs(camera.y-self.last_camera_y)
 end
 self.last_camera_x,self.last_camera_y=camera.x,camera.y
 local moving=motion>1.5
 local budget=self.bake_mode and .03 or (moving and self.build_time_budget or
   self.build_time_budget_idle)
 local deadline=clock and now+budget
 -- Avoid uploading several new GPU meshes in one moving-camera frame.
 -- Keep the existing upload throughput during baking and stationary scenes.
 local upload_cap=self.bake_mode and self.build_budget
   or (moving and math.min(1,self.build_budget) or self.build_budget)
 local uploads,resumes=0,0
 local mesh_prepare_started=clock and clock()
 local resume_cap=self.bake_mode and 800 or
   (moving and self.moving_resume_cap or self.idle_resume_cap)
 for _,c in ipairs(chunks) do
   if image_ready and not c._25d_meshes and uploads<upload_cap
       and (not deadline or clock()<deadline) then
     local job=c._25d_prepare_job
     local loaded=false
     local waiting=false
     if not job and not self.bake_mode then
       if self.binary_worker then
         local result=self.binary_ready[c.key]
         if result then
           self.binary_ready[c.key]=nil
           if result.missing then
             print('TAMU_25D_CPU_WORKER_REJECT '..c.key..' '..
               tostring(result.error))
             -- Worker failures preserve the original cooperative renderer.
             waiting=false
           else
             loaded=Baked.load_ready(self,c,result)
             if walk_probe then
               print(string.format('TAMU_WALK_GPU_UPLOAD frame=%d key=%s ready_since=%s loaded=%s visible=%s',
                 self.walk_probe_frame,c.key,tostring(self.walk_ready_since[c.key]),
                 tostring(loaded),tostring((stream.visible_required_keys or {})[c.key]==true)))
             end
             if loaded and result.generated then
               self.worker_generated=(self.worker_generated or 0)+1
               print('TAMU_25D_CPU_WORKER_LOADED key='..c.key)
             end
           end
         elseif self.binary_pending[c.key] then
           waiting=true
         end
       else
         loaded=Baked.load(self,c)
       end
       if loaded then uploads=uploads+1 end
     end
     if not loaded and not waiting then
       if not job then
         job=coroutine.create(function()
           self:prepare(c,function() coroutine.yield() end)
         end)
         c._25d_prepare_job=job
       end
       repeat
         local ok,err=coroutine.resume(job)
         assert(ok,err)
         resumes=resumes+1
         if coroutine.status(job)=="dead" then
           c._25d_prepare_job=nil
           uploads=uploads+1
           if self.bake_mode then
             local bytes=Baked.save(self,c)
             local binary_bytes=Baked.save_binary(self,c)
             print(string.format('TAMU_25D_BINARY_WRITE cx=%d cy=%d bytes=%d',c.cx,c.cy,binary_bytes))
             self.baked_written=self.baked_written+1
             print(string.format("TAMU_25D_BAKED_WRITE cx=%d cy=%d bytes=%d",c.cx,c.cy,bytes))
             io.stdout:flush()
           end
           break
         end
       until resumes>=resume_cap or (deadline and clock()>=deadline)
       if resumes>=resume_cap then break end
     end
   end
 end
 if walk_probe then
   local selected={}
   for _,c in ipairs(chunks) do
     if (stream.visible_required_keys or {})[c.key] and not c._25d_meshes then
       selected[#selected+1]=c.key..':ready='..
         tostring(self.binary_ready[c.key]~=nil)..':since='..
         tostring(self.walk_ready_since[c.key])
     end
   end
   if #selected>0 then
     print(string.format('TAMU_WALK_GPU_WAIT frame=%d uploads=%d cap=%d missing=%s',
       self.walk_probe_frame,uploads,upload_cap,table.concat(selected,',')))
   end
 end
 self.uploads_per_frame=uploads
 -- Wall-clock time of the bounded preparation/upload loop; not GPU timing.
 self.mesh_prepare_ms=mesh_prepare_started and (clock()-mesh_prepare_started)*1000 or 0
 self.mesh_resumes_per_frame=resumes
 -- Count missing screen-intersecting chunks including pending Stream chunks,
 -- not merely chunks that already have a resident mesh.
 local ready_visible=0
 local required=stream.visible_required_keys or {}
 for _,c in ipairs(chunks) do
   if required[c.key] and c._25d_meshes then ready_visible=ready_visible+1 end
 end
 self.missing_visible=math.max(0,(stream.visible_required_count or 0)-ready_visible)
 self.required_visible=stream.visible_required_count or 0
 self.coverage_over_budget=stream.coverage_over_budget or 0
 if os.getenv('TAMU_25D_COVERAGE_TRACE')=='1' and
    (self.missing_visible~=self.previous_missing_visible or
     self.coverage_over_budget>0) then
   print(string.format(
     'TAMU_25D_COVERAGE missing=%d required=%d resident=%d uploads=%d over_cap=%d',
     self.missing_visible,self.required_visible,#chunks,uploads,self.coverage_over_budget))
   io.stdout:flush()
 end
 self.previous_missing_visible=self.missing_visible
 local draw_chunks=stream.render_visible and stream:render_visible(camera,w,h)
   or chunks
 self.rendered_chunks=draw_chunks
 -- Tall sprites near the screen edge may overlap the viewport even when
 -- their source terrain chunk is just outside it. Keep object culling
 -- slightly more generous than the exact terrain mesh frustum.
 self.object_chunks=stream.render_visible and
   stream:render_visible(camera,w,h,80*camera.zoom+16) or chunks
 self.culled_chunks=#chunks-#draw_chunks
 -- The full terrain pipeline still prepares identical resident chunks in
 -- matched render tests. Suppress only terrain GPU drawing when disabled.
 if self.suppress_terrain_draw then
   self.visible=#draw_chunks
   self.draw_calls=0
   return self.visible
 end
 local g=love.graphics
 g.clear(.075,.115,.128,1);g.push("all")
 g.translate(w/2,h/2);g.scale(camera.zoom)
 local x,y=Iso.project(camera.x,camera.y)
 g.translate(-x,-y)
 local tint=self.sun.tint
 local calls,visible=0,0
 local merged=self:update_ground_batch(draw_chunks,now)
 local shader=self.reveal_shader
 -- Render-only style cache: each chunk is drawn for ground, overlays and
 -- water within the same frame. Avoid redoing projection, reveal sampling
 -- and uniform vectors for the same chunk on every layer.
 local styles={}
 local active_shader=false
 g.setColor(tint[1],tint[2],tint[3],1)
 local function prepare_style(chunk)
   if not shader then return end
   local style=styles[chunk]
   if style==nil then
     local progress=self:chunk_reveal(chunk,now)
     if progress<.999 then
       local cx,cy=chunk.x+chunk.size*.5,chunk.y+chunk.size*.5
       local sx,sy=camera:project(cx,cy,w,h)
       local radius=(chunk.size*.707106781186548+32)*camera.zoom
       style={origin={sx,sy},front=progress*radius}
     else
       style=false
     end
     styles[chunk]=style
   end
   if style then
     shader:send('radial',1)
     shader:send('waveOrigin',style.origin)
     shader:send('waveFront',style.front)
     if not active_shader then g.setShader(shader);active_shader=true end
   elseif active_shader then
     g.setShader();active_shader=false
   end
 end
 if merged then
   visible=#draw_chunks
   for _,layer in ipairs({'ground','path','bank','water'}) do
     for _,entry in ipairs(merged[layer]) do
       g.draw(entry.mesh)
       calls=calls+1
     end
   end
 else
 for _,c in ipairs(draw_chunks) do
   if c._25d_meshes then
     visible=visible+1
     prepare_style(c)
     for _,id in ipairs(c._25d_ground_order) do
       g.draw(c._25d_meshes[id]);calls=calls+1
     end
   end
 end
 for _,layer in ipairs({'path','bank'}) do
   for _,c in ipairs(draw_chunks) do
     if c._25d_meshes and c._25d_overlay_order then
       prepare_style(c)
       for _,page in ipairs(c._25d_overlay_order[layer]) do
         g.draw(c._25d_meshes['!'..layer..':'..page]);calls=calls+1
       end
     end
   end
 end
 for _,c in ipairs(draw_chunks) do
   if c._25d_meshes and c._25d_meshes['!water'] then
     prepare_style(c)
     g.draw(c._25d_meshes['!water']);calls=calls+1
   end
 end
 end
 if active_shader then g.setShader() end
 g.setColor(1,1,1,1)
 g.pop()
 -- Pruning scans every resident chunk and its texture pages. Performing
 -- this traversal at 60 Hz creates CPU/GC work even for a static world.
 -- Throttle to 2 Hz; all pages remain pinned by resident mesh ownership.
 -- The delayed release is bounded and does not affect visible terrain.
 self.page_prune_elapsed=(self.page_prune_elapsed or 0)+(love.timer and love.timer.getDelta and love.timer.getDelta() or 1/60)
 if self.page_prune_elapsed>=.5 then
   self.page_prune_elapsed=0
   self:prune_pages(stream,chunks)
 end
 self.visible,self.draw_calls=visible,calls
 return visible
end
return Runtime
