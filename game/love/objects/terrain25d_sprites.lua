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
 oak=.48,broadleaf=.52,conifer=.55,dead_tree=.43,
 boulder=.33,rock_cluster=.38,rock_spire=.41,water_rocks=.28,
 shrub=.24,reeds=.23,stump=.19,fallen_log=.30
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
 self.pending=0;self.current_page=nil
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
   g.draw(batch)
   batch:clear();self.pending=0;self.current_page=nil
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
function Sprite:draw_shadows(g,camera,w,h,objects)
 self.shadow_frame=self.shadow_frame+1
 local sun=self.provider.sun
 -- Keep GPU atlas references alive only while their shadow batches persist.
 for page,entry in pairs(self.shadow_batches) do
   entry.batch:clear();entry.count=0
   if self.shadow_frame-entry.last_seen>2 then
     entry.batch:release()
     self.provider:unpin_page(page)
     self.shadow_batches[page]=nil
   end
 end
 self.shadow_calls,self.shadow_objects=0,0
 if not sun or sun.cast<=0 then return 0 end
 local visible={}
 for _,o in ipairs(objects) do
   local a,x,y,scale,family=self:appearance(camera,w,h,o)
   if a then
     local entry=self:shadow_batch_for(a.page)
     local batch=entry.batch
     -- Prevent batch capacity overflow in an unusually dense authored scene.
     if entry.count+2>self.limit*2 then
       g.setColor(1,1,1,1);g.draw(batch)
       self.shadow_calls=self.shadow_calls+1
       batch:clear();entry.count=0
     end
     local angle,sx,sy=Sprite.shadow_geometry(family,scale,sun)
     -- Feather-like *silhouette layers*: no Gaussian blur and no ground
     -- texture replacement. Two near-/far-contact opacity scales.
     batch:setColor(.035,.048,.048,.13*sun.cast)
     batch:add(a.quad,x,y,angle,sx*1.17,sy*1.12,64,124)
     batch:setColor(.022,.032,.031,.42*sun.cast)
     batch:add(a.quad,x,y,angle,sx*.82,sy*.85,64,124)
     entry.count=entry.count+2
     visible[a.page]=true
     self.shadow_objects=self.shadow_objects+1
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
 return self.shadow_calls
end
function Sprite:queue(g,camera,w,h,o,selected)
 local a,x,y,scale,family=self:appearance(camera,w,h,o)
 if not a then self.culled=self.culled+1;return end
 local z=camera.zoom
 -- Keep draw order as authored by ObjectRenderer's Y-depth sort.
 if self.pending>=self.limit or
   (self.current_page and self.current_page~=a.page) then self:flush(g) end
 local batch=self:batch_for(a.page)
 g.setColor(.06,.09,.08,.20)
 g.ellipse("fill",x,y+2*z,o.radius*z*1.15,o.radius*z*.52)
 batch:add(a.quad,x,y,0,scale,scale,64,124)
 self.current_page=a.page
 self.pending=self.pending+1
 self.visible=self.visible+1
 if selected then self.selected={x=x,y=y,radius=o.radius,zoom=z} end
end
function Sprite:draw(g,camera,w,h,o,selected)
 self:begin_frame()
 self:queue(g,camera,w,h,o,selected)
 self:flush(g)
end
return Sprite
