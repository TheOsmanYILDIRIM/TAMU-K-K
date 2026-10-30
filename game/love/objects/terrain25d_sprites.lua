-- Mobile opt-in atlas sprite batching; original Y-depth/harvest stays authoritative.
-- Only packed, reviewed atlas pages are accessed, and only for visible sprites.
local Sprite={};Sprite.__index=Sprite
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
 return setmetatable({provider=provider,families=fam,
   batches_by_page={},shadow_batches={},shadow_frame=0,
   shadow_cache=nil,shadow_rebuilds=0,shadow_reuses=0,
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
     self.provider:unpin_page(page)
     self.batches_by_page[page]=nil
   end
 end
 self.pending=0;self.current_page=nil;self.pending_reveal=false
 self.selected=nil;self.visible=0;self.culled=0;self.batches=0
end
function Sprite:batch_for(page)
 local entry=self.batches_by_page[page]
 if not entry then
   local image=self.provider:page(page)
   local batch=love.graphics.newSpriteBatch(image,self.limit,"stream")
   self.provider:pin_page(page)
   entry={batch=batch,last_seen=self.frame}
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
   g.draw(batch)
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
function Sprite:appearance(camera,w,h,o)
 -- The compact object atlas is decoded off-thread; never trigger a
 -- synchronous newImage fallback while the worker is still loading it.
 if self.provider.compact and not self.provider.compact_ready then return nil end
 if self.provider.object_reveal and
   self.provider:object_reveal(o.x,o.y)<=0 then return nil end
 local family
 if o.kind=="tree" then
   local variety=hash(o.id)%12
   family=variety==0 and "broadleaf" or
     (variety<=2 and "conifer" or "oak")
 elseif o.kind=="rock" then
   local variety=hash(o.id)%12
   family=variety==0 and "rock_spire" or
     (variety==1 and "rock_cluster" or "boulder")
 else family=self.families[o.kind] and o.kind or "shrub" end
 local choices=self.families[family] or self.families.oak
 local z=camera.zoom
 local n=z<.8 and math.min(#choices,2) or #choices
 local a=choices[1+hash(o.id)%n]
 local x,y=camera:project(o.x,o.y,w,h)
 local scale=Sprite.scale_for(family,z,o.id)
 if x+64*scale<0 or x-64*scale>w or
    y+8*scale<0 or y-124*scale>h then return nil end
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
 g.push()
 g.translate(x-w*.5,y-h*.5)
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
   self.shadow_reuses=self.shadow_reuses+1
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
 self.shadow_rebuilds=self.shadow_rebuilds+1
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
function Sprite:queue(g,camera,w,h,o,selected)
 local a,x,y,scale,family=self:appearance(camera,w,h,o)
 if not a then self.culled=self.culled+1;return end
 local z=camera.zoom
 -- Keep draw order as authored by ObjectRenderer's Y-depth sort.
 if self.pending>=self.limit or
   (self.current_page and self.current_page~=a.page) then self:flush(g) end
 local progress=self.provider.object_reveal and
   self.provider:object_reveal(o.x,o.y) or 1
 local batch=self:batch_for(a.page)
 batch:setColor(1,1,1,progress)
 self.pending_reveal=self.pending_reveal or progress<.999
 batch:add(a.quad,x,y,0,scale,scale,64,124)
 self.current_page=a.page
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
