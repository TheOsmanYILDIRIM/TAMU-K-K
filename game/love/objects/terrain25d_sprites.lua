-- Mobile opt-in atlas sprite batching; original Y-depth/harvest stays authoritative.
-- Only packed, reviewed atlas pages are accessed, and only for visible sprites.
local Sprite={};Sprite.__index=Sprite
local StaticJson=require('save.json')
local SHADOW_ROOT='assets/terrain25d/static_shadow/'
local function hash(id)
 local n=19
 for i=1,#id do n=(n*33+id:byte(i))%2147483647 end
 return n
end
-- All 128px authored sprites share a foot pivot (64,124). These are
-- WORLD-scale proportions, not pixel sizes or collision radii.
-- Tree silhouettes lead, large rocks are smaller, undergrowth stays low.
local BASE_SCALE={
 -- Character/world transform stays unchanged. Authored 128px tree sprites
 -- were underscaled (~0.5x); enlarge the ecosystem rather than the avatar.
 oak=1.04,broadleaf=1.12,conifer=1.20,dead_tree=.94,
 boulder=.44,rock_cluster=.50,rock_spire=.53,water_rocks=.38,
 shrub=.30,reeds=.28,stump=.26,fallen_log=.41
}
function Sprite.scale_for(family,zoom,id)
 local base=assert(BASE_SCALE[family],"unknown 25D sprite family: "..tostring(family))
 assert(type(zoom)=="number" and zoom>0 and type(id)=="string")
 -- Restrained deterministic variation preserves ecology and instance IDs.
 return zoom*base*(.96+(hash(id)%9)*.01)
end
function Sprite.new(provider,manifest)
 assert(provider and type(provider.page)=="function" and manifest)
 local pages={}
 for _,p in ipairs(manifest.atlas_pages) do pages[p.filename]=p end
 local fam={}
 for _,a in ipairs(manifest.assets) do
   if a.kind=="object" and a.uv_rect then
     local page=assert(pages[a.atlas_page],"object atlas page is not packed")
     local u=a.uv_rect
     local f=fam[a.family] or {}
     f[#f+1]={id=a.id,page=a.atlas_page,quad=love.graphics.newQuad(
       u[1]*page.width,u[2]*page.height,
       u[3]*page.width,u[4]*page.height,page.width,page.height)}
     fam[a.family]=f
   end
 end
 for _,list in pairs(fam) do
   table.sort(list,function(a,b) return a.id<b.id end)
 end
 assert(fam.oak and fam.conifer and fam.boulder)
 local limit=1024
 local static_manifest
 if love.filesystem and love.filesystem.getInfo and
   love.filesystem.getInfo(SHADOW_ROOT..'objects_shadow_manifest.json','file') then
   local raw=love.filesystem.read(SHADOW_ROOT..'objects_shadow_manifest.json')
   local ok,m=pcall(StaticJson.decode,raw or '')
   if ok and m and m.version==3 and #m.pages==8 and m.objects then
     static_manifest=m
   end
 end
 return setmetatable({provider=provider,families=fam,bundles={},
   static_manifest=static_manifest,static_images={},
   batches_by_page={},shadow_batches={},shadow_frame=0,
   shadow_cache=nil,static_shadow_cache=nil,shadow_rebuilds=0,shadow_reuses=0,
   contact_batch=nil,contact_cache=nil,contact_calls=0,
   contact_objects=0,contact_rebuilds=0,contact_reuses=0,
   frame=0,current_page=nil,shadow_calls=0,shadow_objects=0,
   limit=limit,pending=0,selected=nil,visible=0,culled=0,batches=0},Sprite)
end
function Sprite:begin_frame()
 self.frame=self.frame+1
 -- Retain two idle frames for camera jitter; release both batch and pin.
 for page,entry in pairs(self.batches_by_page) do
   if self.frame-entry.last_seen>2 then
     entry.batch:release()
     if entry.static then
       entry.image:release()
       self.static_images[page]=nil
     else self.provider:unpin_page(page) end
     self.batches_by_page[page]=nil
   end
 end
 if self.frame%120==0 then
   for id,b in pairs(self.bundles or {}) do
     if self.frame-(b.last_seen or 0)>120 then self.bundles[id]=nil end
   end
 end
 self.pending=0;self.current_page=nil;self.pending_reveal=false
 self.selected=nil;self.visible=0;self.culled=0;self.batches=0
end
function Sprite:batch_for(page)
 local entry=self.batches_by_page[page]
 if not entry then
   local static=page:sub(1,13)=='staticshadow:'
   local image
   if static then
     image=love.graphics.newImage(SHADOW_ROOT..page:sub(14))
     image:setFilter('linear','linear')
     self.static_images[page]=image
   else
     image=self.provider:page(page)
     self.provider:pin_page(page)
   end
   local batch=love.graphics.newSpriteBatch(image,self.limit,"stream")
   entry={batch=batch,last_seen=self.frame,static=static,image=static and image or nil}
   self.batches_by_page[page]=entry
 end
 entry.last_seen=self.frame
 return entry.batch
end
function Sprite:flush(g)
 if self.pending>0 then
   local batch=assert(self.batches_by_page[self.current_page]).batch
   -- Apply the same time-of-day illumination to source sprite RGB as
   -- the terrain. The sprite's original alpha, silhouette and scale remain.
   local tint=self.provider.sun and self.provider.sun.tint
   if tint then g.setColor(tint[1],tint[2],tint[3],1)
   else g.setColor(1,1,1,1) end
   local shader=self.provider.reveal_shader
   if self.pending_reveal and shader then
     shader:send('radial',0)
     g.setShader(shader)
   end
   if not self.skip_gpu_draw then g.draw(batch) end
   if self.pending_reveal and shader then g.setShader() end
   batch:clear();self.pending=0;self.current_page=nil
   self.pending_reveal=false
   self.batches=self.batches+1
 end
 if self.selected then
   local o=self.selected
   g.setColor(1,.82,.3,.9);g.setLineWidth(2)
   g.ellipse("line",o.x,o.y,o.radius*o.zoom*1.5,o.radius*o.zoom*.8)
   self.selected=nil
 end
end
-- Identical approved sprite family, variant, scale and culling in the
-- opaque sprite pass and alpha-silhouette shadow prepass.
-- Chunk Render Bundle: immutable world chunk origin + chunk-local coordinates.
-- Both object sprites and their attached shadows use this projection.
function Sprite.chunk_key(o)
 local cx=o.cx or math.floor(o.x/256)
 local cy=o.cy or math.floor(o.y/256)
 return cx..':'..cy,cx*256,cy*256
end
function Sprite.project_chunk_local(camera,w,h,o)
 local _,ox,oy=Sprite.chunk_key(o)
 local lx,ly=o.x-ox,o.y-oy
 -- Camera is authoritative; no chunk-relative camera reset is permitted.
 return camera:project(ox+lx,oy+ly,w,h)
end
-- Parametric object record is immutable until the authored identity or
-- world coordinates actually change. GPU shadow/object paths share this
-- identity and origin; Y-depth sorting remains authoritative in Renderer.
function Sprite:bundle_for(o)
 self.bundles=self.bundles or {}
 local key,ox,oy=Sprite.chunk_key(o)
 local b=self.bundles[o.id]
 if not b or b.x~=o.x or b.y~=o.y or b.kind~=o.kind
     or b.radius~=o.radius or b.chunk~=key then
   local h=hash(o.id)
   local family
   if o.kind=='tree' then
     local variety=h%12
     family=variety==0 and 'broadleaf' or
       (variety<=2 and 'conifer' or 'oak')
   elseif o.kind=='rock' then
     local variety=h%12
     family=variety==0 and 'rock_spire' or
       (variety==1 and 'rock_cluster' or 'boulder')
   else family=self.families[o.kind] and o.kind or 'shrub' end
   b={id=o.id,x=o.x,y=o.y,kind=o.kind,radius=o.radius,
      chunk=key,origin_x=ox,origin_y=oy,
      local_x=o.x-ox,local_y=o.y-oy,hash=h,family=family}
   self.bundles[o.id]=b
 end
 b.last_seen=self.frame or 0
 return b
end
function Sprite:appearance(camera,w,h,o,skip_cull)
 -- The compact object atlas is decoded off-thread; never trigger a
 -- synchronous newImage fallback while the worker is still loading it.
 if self.provider.compact and not self.provider.compact_ready then return nil end
 if self.provider.object_reveal and
   self.provider:object_reveal(o.x,o.y)<=0 then return nil end
 local bundle=self:bundle_for(o)
 local family=bundle.family
 local choices=self.families[family] or self.families.oak
 local z=camera.zoom
 local n=z<.8 and math.min(#choices,2) or #choices
 local a=choices[1+bundle.hash%n]
 local x,y=Sprite.project_chunk_local(camera,w,h,o)
 local scale=Sprite.scale_for(family,z,o.id)
 if not skip_cull and (x+64*scale<0 or x-64*scale>w or
    y+8*scale<0 or y-124*scale>h) then return nil end
 return a,x,y,scale,family
end
-- Actual sprite RGBA alpha becomes a projected ground silhouette.
-- Rotation and length are computed from the visual sun, not an image blur.
function Sprite.shadow_geometry(family,scale,sun)
 assert(sun and sun.length and sun.rotation and sun.cast)
 local height=(family=="oak" or family=="conifer"
   or family=="broadleaf" or family=="dead_tree") and 1 or
   ((family=="rock_spire" or family=="rock_cluster") and .82 or .65)
 return sun.rotation,scale*.85,-scale*sun.length*height
end
function Sprite:shadow_batch_for(page)
 local entry=self.shadow_batches[page]
 if not entry then
   local image=self.provider:page(page)
   local batch=love.graphics.newSpriteBatch(image,self.limit*2,"stream")
   self.provider:pin_page(page)
   entry={batch=batch,last_seen=self.shadow_frame,count=0}
   self.shadow_batches[page]=entry
 end
 entry.last_seen=self.shadow_frame
 return entry
end
-- Only visual ID and geometry matter; R2 can re-materialize equal
-- records without invalidating the rendered scene.
local function same_scene(cache,camera,w,h,objects)
 -- Screen-space batch geometry remains valid when only the camera pans.
 -- Translate the cached batch by the projected camera displacement.
 if not cache or cache.zoom~=camera.zoom or cache.w~=w or cache.h~=h
   or #cache.objects~=#objects then return false end
 for i,o in ipairs(objects) do
   local v=cache.objects[i]
   if v[1]~=o.id or v[2]~=o.x or v[3]~=o.y
     or v[4]~=o.kind or v[5]~=o.radius then return false end
 end
 return true
end
local function draw_camera_batch(g,batch,cache,camera,w,h)
 -- camera:project is authoritative for the game's isometric transform.
 -- The old camera centre, projected using the new camera, gives the exact
 -- translation needed by every cached screen-space sprite vertex.
 local x,y=camera:project(cache.x,cache.y,w,h)
 -- Exactly the same unrounded projection as the first (uncached) draw.
 -- Rounding only cached frames caused a position jump on cache transitions.
 local dx,dy=x-w*.5,y-h*.5
 g.push()
 g.translate(dx,dy)
 g.draw(batch)
 g.pop()
end
local function scene_snapshot(camera,w,h,objects)
 local snapshot={}
 for i,o in ipairs(objects) do
   snapshot[i]={o.id,o.x,o.y,o.kind,o.radius}
 end
 return {x=camera.x,y=camera.y,zoom=camera.zoom,w=w,h=h,objects=snapshot}
end
-- Replace per-object filled ellipses with one 48x48 alpha-oval batch.
-- Nine KiB of visual-only RGBA8; no change to collision, save, source PNGs
-- or the approved two-layer projected sunlight silhouettes.
function Sprite:draw_contacts(g,camera,w,h,objects,stable_hint)
 self.contact_calls=0
 if #objects==0 then
   self.contact_objects=0
   self.contact_cache=nil
   return
 end
 -- The shadow pass already checked this visible set. Do not scan
 -- reveal state twice during every moving-camera frame.
 local stable=stable_hint
 if stable==nil then
   stable=not self.provider.objects_fully_revealed
     or self.provider:objects_fully_revealed(objects)
 end
 if stable and self.contact_batch and
    same_scene(self.contact_cache,camera,w,h,objects) then
   self.contact_reuses=self.contact_reuses+1
   if self.contact_objects>0 then
     g.setColor(1,1,1,1)
     draw_camera_batch(g,self.contact_batch,self.contact_cache,camera,w,h)
     self.contact_calls=1
   end
   return
 end
 self.contact_rebuilds=self.contact_rebuilds+1
 if not self.contact_batch then
   local size=48
   local pixels=love.image.newImageData(size,size)
   for py=0,size-1 do for px=0,size-1 do
     local dx=(px+.5-size/2)/(size/2)
     local dy=(py+.5-size/2)/(size/2)
     local alpha=math.max(0,math.min(1,(1-math.sqrt(dx*dx+dy*dy))*size/2))
     pixels:setPixel(px,py,1,1,1,alpha)
   end end
   local image=g.newImage(pixels)
   pixels:release()
   image:setFilter("linear","linear")
   self.contact_batch=g.newSpriteBatch(image,self.limit*2,"stream")
   self.contact_quad=g.newQuad(0,0,size,size,size,size)
   self.contact_image=image
 end
 local batch=self.contact_batch
 batch:clear()
 batch:setColor(.06,.09,.08,.20)
 local count,total,overflow=0,0,false
 for _,o in ipairs(objects) do
   local ready=not self.provider.object_reveal or
     self.provider:object_reveal(o.x,o.y)>=.999
   local a,x,y
   if ready then a,x,y=self:appearance(camera,w,h,o) end
   if a then
     if count>=self.limit*2 then
       g.setColor(1,1,1,1);g.draw(batch)
       self.contact_calls=self.contact_calls+1
       batch:clear();count=0;overflow=true
     end
     local z=camera.zoom
     batch:add(self.contact_quad,x,y+2*z,0,
       o.radius*z*1.15/24,o.radius*z*.52/24,24,24)
     count=count+1
     total=total+1
   end
 end
 self.contact_objects=total
 g.setColor(1,1,1,1)
 if count>0 then
   g.draw(batch)
   self.contact_calls=self.contact_calls+1
 end
 -- An overflow flushes partial contents; it is intentionally not cacheable.
 self.contact_cache=stable and not overflow and
   scene_snapshot(camera,w,h,objects) or nil
end
-- Reuse immutable GPU shadow batches while a fixed view's moving sun
-- changes by less than a third of a screen pixel. A changed camera, object
-- or appreciable solar motion always rebuilds the original two RGBA layers.
function Sprite:draw_shadows(g,camera,w,h,objects)
 if self.static_manifest then
   -- Immutable, full-chunk shadow geometry is built once and reused on
   -- camera pans. Never bake viewport culling into a reusable screen batch:
   -- objects outside the original viewport may enter it after a pan.
   self.shadow_calls,self.shadow_objects=0,0
   local sun=self.provider.sun
   if not sun or sun.cast<=0 then
     self.static_shadow_cache=nil
     return 0
   end
   -- One world-cell batch per immutable object group. Entering a new
   -- chunk only builds that chunk; unchanged neighbours retain GPU geometry.
   -- Shadows share their source object's world coordinate and camera matrix.
   local slot=(math.floor(sun.hour/3+.5)*3)%24
   local name='shadows_'..string.format('%02d',slot)..'.png'
   local stable=not self.provider.objects_fully_revealed
     or self.provider:objects_fully_revealed(objects)
   self.shadow_chunk_cache=self.shadow_chunk_cache or {}
   self.shadow_chunk_images=self.shadow_chunk_images or {}
   local image=self.shadow_chunk_images[name]
   if not image then
     image=love.graphics.newImage(SHADOW_ROOT..name)
     image:setFilter('linear','linear')
     self.shadow_chunk_images[name]=image
   end
   local groups,keys={},{}
   for _,o in ipairs(objects) do
     local key=Sprite.chunk_key(o)
     if not groups[key] then groups[key]={};keys[#keys+1]=key end
     groups[key][#groups[key]+1]=o
   end
   table.sort(keys)
   for _,key in ipairs(keys) do
     local group=groups[key]
     local cache_key=name..':'..key
     local cache=self.shadow_chunk_cache[cache_key]
     local reuse=stable and cache and cache.image==image
       and same_scene(cache,camera,w,h,group)
     if not reuse then
       self.shadow_rebuilds=(self.shadow_rebuilds or 0)+1
       if cache and cache.batch then cache.batch:release() end
       local batch=love.graphics.newSpriteBatch(image,math.max(1,#group),'dynamic')
       local count=0
       for _,o in ipairs(group) do
         local a,x,y,scale=self:appearance(camera,w,h,o,true)
         if a then
           local index=assert(self.static_manifest.objects[a.id],
             'missing shadow mask '..a.id)
           if not index.quad then
             index.quad=love.graphics.newQuad(index.u,index.v,32,32,
               self.static_manifest.width,self.static_manifest.height)
           end
           batch:setColor(1,1,1,1)
           batch:add(index.quad,x,y,0,scale*4,scale*4,16,24)
           count=count+1
         end
       end
       cache=scene_snapshot(camera,w,h,group)
       cache.batch,cache.image,cache.count=batch,image,count
       cache.last_seen=self.shadow_chunk_frame or 0
       if stable then self.shadow_chunk_cache[cache_key]=cache end
     else
       self.shadow_reuses=(self.shadow_reuses or 0)+1
     end
     self.shadow_objects=self.shadow_objects+cache.count
     if cache.count>0 and not self.skip_gpu_draw then
       g.setColor(1,1,1,1)
       if reuse then draw_camera_batch(g,cache.batch,cache,camera,w,h)
       else g.draw(cache.batch) end
       self.shadow_calls=self.shadow_calls+1
     end
     if not stable then
       self.shadow_chunk_cache[cache_key]=nil
       cache.batch:release()
     end
   end
   -- Bounded lifetime for chunks left behind; keep recent neighbours hot.
   self.shadow_chunk_frame=(self.shadow_chunk_frame or 0)+1
   for key,cache in pairs(self.shadow_chunk_cache) do
     if groups[key:match('^[^:]+:(.+)$')] and
        key:sub(1,#name+1)==name..':' then
       cache.last_seen=self.shadow_chunk_frame
     elseif self.shadow_chunk_frame-(cache.last_seen or 0)>120 then
       cache.batch:release()
       self.shadow_chunk_cache[key]=nil
     end
   end
   return self.shadow_calls
 end
 self.shadow_frame=self.shadow_frame+1
 local sun=self.provider.sun
 for page,entry in pairs(self.shadow_batches) do
   if self.shadow_frame-entry.last_seen>2 then
     entry.batch:release()
     self.provider:unpin_page(page)
     self.shadow_batches[page]=nil
   end
 end
 self.shadow_calls,self.shadow_objects=0,0
 if not sun or sun.cast<=0 then
   self.shadow_cache=nil
   self:draw_contacts(g,camera,w,h,objects)
   return 0
 end
 local stable=not self.provider.objects_fully_revealed
   or self.provider:objects_fully_revealed(objects)
 local cache=self.shadow_cache
 local reuse=stable and same_scene(cache,camera,w,h,objects)
 if reuse then
   local turn=math.abs(sun.rotation-cache.rotation)
   turn=math.min(turn,2*math.pi-turn)
   local error_px=turn*cache.extent
     +math.abs(sun.length-cache.length)*cache.extent
     +math.abs(sun.cast-cache.cast)*40
   reuse=error_px<.33
 end
 if reuse then
   for _,page in ipairs(cache.pages) do
     if not self.shadow_batches[page] then reuse=false;break end
   end
 end
 if reuse then
   self.shadow_reuses=(self.shadow_reuses or 0)+1
   self.shadow_objects=cache.count
   g.setColor(1,1,1,1)
   for _,page in ipairs(cache.pages) do
     local entry=self.shadow_batches[page]
     entry.last_seen=self.shadow_frame
     draw_camera_batch(g,entry.batch,cache,camera,w,h)
     self.shadow_calls=self.shadow_calls+1
   end
   self:draw_contacts(g,camera,w,h,objects,stable)
   return self.shadow_calls
 end
 self.shadow_rebuilds=(self.shadow_rebuilds or 0)+1
 for _,entry in pairs(self.shadow_batches) do
   entry.batch:clear()
   entry.count=0
 end
 local visible,overflowed,max_extent={},false,1
 for _,o in ipairs(objects) do
   local ready=not self.provider.object_reveal or
     self.provider:object_reveal(o.x,o.y)>=.999
   local a,x,y,scale,family
   if ready then a,x,y,scale,family=self:appearance(camera,w,h,o) end
   if a then
     local entry=self:shadow_batch_for(a.page)
     local batch=entry.batch
     -- Capacity overflow needs immediate drawing and disables caching;
     -- otherwise a reused batch would omit its earlier flushed sprites.
     if entry.count+2>self.limit*2 then
       g.setColor(1,1,1,1);g.draw(batch)
       self.shadow_calls=self.shadow_calls+1
       batch:clear();entry.count=0
       overflowed=true
     end
     local angle,sx,sy=Sprite.shadow_geometry(family,scale,sun)
     -- Keep the approved two-layer alpha silhouette fully intact.
     batch:setColor(.035,.048,.048,.13*sun.cast)
     batch:add(a.quad,x,y,angle,sx*1.17,sy*1.12,64,124)
     batch:setColor(.022,.032,.031,.42*sun.cast)
     batch:add(a.quad,x,y,angle,sx*.82,sy*.85,64,124)
     entry.count=entry.count+2
     visible[a.page]=true
     self.shadow_objects=self.shadow_objects+1
     max_extent=math.max(max_extent,math.abs(sy)*128)
   end
 end
 local pages={}
 for page in pairs(visible) do pages[#pages+1]=page end
 table.sort(pages)
 g.setColor(1,1,1,1)
 for _,page in ipairs(pages) do
   local entry=self.shadow_batches[page]
   if entry and entry.count>0 then
     g.draw(entry.batch)
     self.shadow_calls=self.shadow_calls+1
   end
 end
 if overflowed or not stable then
   self.shadow_cache=nil
 else
   self.shadow_cache=scene_snapshot(camera,w,h,objects)
   self.shadow_cache.rotation=sun.rotation
   self.shadow_cache.length=sun.length
   self.shadow_cache.cast=sun.cast
   self.shadow_cache.extent=max_extent
   self.shadow_cache.count=self.shadow_objects
   self.shadow_cache.pages=pages
 end
 self:draw_contacts(g,camera,w,h,objects,stable)
 return self.shadow_calls
end
-- Static world objects share one approved atlas page. Reuse two persistent
-- batches split at the player's Y-depth; only the player moves between them.
-- This is intentionally disabled while the chunk reveal is animating.
-- Exact ordered scene signature: saves a previously built GPU batch when a
-- camera revisits the same stable chunk set. Never reorder Y-depth objects.
local function object_scene_key(camera,w,h,objects)
 local parts={tostring(camera.zoom),tostring(w),tostring(h)}
 for _,o in ipairs(objects) do
   parts[#parts+1]=table.concat({o.id,o.x,o.y,o.kind,o.radius},':')
 end
 return table.concat(parts,'|')
end
function Sprite:prepare_cached_objects(camera,w,h,order)
 if not self.provider.compact_ready or
    not self.provider.objects_fully_revealed then return false end
 local objects={}
 local player_slot=0
 for i,entry in ipairs(order) do
   if entry.player then player_slot=i
   else objects[#objects+1]=entry.object end
 end
 if player_slot==0 or not self.provider:objects_fully_revealed(objects) then
   if self.object_static_cache then self.object_static_cache.valid=false end
   return false
 end
 local key=object_scene_key(camera,w,h,objects)
 self.object_scene_cache=self.object_scene_cache or {}
 local cache=self.object_scene_cache[key]
 if cache and cache.valid~=false and
    same_scene(cache,camera,w,h,objects) then
   self.object_static_cache=cache
   cache.last_seen=self.frame or 0
   -- Object ordering is invariant while only player depth slot changes.
   cache.split=cache.prefix[player_slot-1] or 0
   self.object_cache_reuses=(self.object_cache_reuses or 0)+1
   return true
 end
 self.object_cache_rebuilds=(self.object_cache_rebuilds or 0)+1
 if not self.object_atlas_pinned then
   self.provider:pin_page('atlas_01.png')
   self.object_atlas_pinned=true
 end
 local image=self.provider:page('atlas_01.png')
 if not cache or cache.image~=image then
   if cache and cache.batch then cache.batch:release() end
   cache={image=image,
     batch=love.graphics.newSpriteBatch(image,self.limit*4,'dynamic')}
 end
 local batch=cache.batch
 batch:clear();batch:setColor(1,1,1,1)
 local count,seen=0,0
 local prefix={[0]=0}
 for _,entry in ipairs(order) do
   if not entry.player then
     seen=seen+1
     -- Prefix counts handle object records that have no drawable sprite.
     local a,x,y,scale=self:appearance(camera,w,h,entry.object,true)
     if a then
       assert(a.page=='atlas_01.png','mixed object atlas pages')
       batch:add(a.quad,x,y,0,scale,scale,64,124)
       count=count+1
     end
     prefix[seen]=count
   end
 end
 cache.x,cache.y=camera.x,camera.y
 cache.zoom,cache.w,cache.h=camera.zoom,w,h
 cache.objects={}
 for i,o in ipairs(objects) do
   cache.objects[i]={o.id,o.x,o.y,o.kind,o.radius}
 end
 cache.prefix=prefix;cache.count=count
 cache.split=prefix[player_slot-1] or 0
 cache.valid=true
 cache.last_seen=self.frame or 0
 self.object_scene_cache[key]=cache
 self.object_static_cache=cache
 -- An explicit upper bound keeps GPU batches from accumulating indefinitely.
 local size=0
 for _ in pairs(self.object_scene_cache) do size=size+1 end
 if size>6 then
   local oldest_key,oldest_frame
   for k,v in pairs(self.object_scene_cache) do
     if v~=cache and (not oldest_frame or v.last_seen<oldest_frame) then
       oldest_key,oldest_frame=k,v.last_seen
     end
   end
   if oldest_key then
     self.object_scene_cache[oldest_key].batch:release()
     self.object_scene_cache[oldest_key]=nil
   end
 end
 return true
end
function Sprite:draw_selection(g,camera,w,h,o)
  local a,x,y=self:appearance(camera,w,h,o)
  if not a then return false end
  local z=camera.zoom
  g.setColor(1,.82,.3,.9);g.setLineWidth(2)
  g.ellipse('line',x,y,o.radius*z*1.5,o.radius*z*.8)
  return true
end
function Sprite:draw_cached_objects(g,camera,w,h,side)
 local cache=assert(self.object_static_cache,'no prepared object batch')
 local start,count
 if side==1 then start,count=1,cache.split
 else start,count=cache.split+1,cache.count-cache.split end
 if count<=0 or self.skip_gpu_draw then return end
 local tint=self.provider.sun and self.provider.sun.tint
 if tint then g.setColor(tint[1],tint[2],tint[3],1)
 else g.setColor(1,1,1,1) end
 cache.batch:setDrawRange(start,count)
 draw_camera_batch(g,cache.batch,cache,camera,w,h)
 self.batches=self.batches+1
 self.visible=self.visible+count
end

function Sprite:queue(g,camera,w,h,o,selected)
 local a,x,y,scale,family=self:appearance(camera,w,h,o)
 if not a then self.culled=self.culled+1;return end
 local z=camera.zoom
 -- Keep draw order as authored by ObjectRenderer's Y-depth sort.
 if self.pending>=self.limit then self:flush(g) end
 local progress=self.provider.object_reveal and
   self.provider:object_reveal(o.x,o.y) or 1
 local page=a.page
 local quad=a.quad
 local pivot_x,pivot_y=64,124
 if self.current_page and self.current_page~=page then self:flush(g) end
 local batch=self:batch_for(page)
 batch:setColor(1,1,1,progress)
 self.pending_reveal=self.pending_reveal or progress<.999
 batch:add(quad,x,y,0,scale,scale,pivot_x,pivot_y)
 self.current_page=page
 self.pending=self.pending+1
 self.visible=self.visible+1
 if selected then self.selected={x=x,y=y,radius=o.radius,zoom=z} end
end
function Sprite:draw(g,camera,w,h,o,selected)
 self:begin_frame()
 self:draw_shadows(g,camera,w,h,{o})
 self:queue(g,camera,w,h,o,selected)
 self:flush(g)
end
return Sprite
