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
   batches_by_page={},frame=0,current_page=nil,
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
   g.setColor(1,1,1,1)
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
function Sprite:queue(g,camera,w,h,o,selected)
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
 -- Far-zoom sprite LOD: retain stable silhouettes but limit GPU page
 -- diversity to two stable approved variants per family.
 local n=z<.8 and math.min(#choices,2) or #choices
 local a=choices[1+hash(o.id)%n]
 local x,y=camera:project(o.x,o.y,w,h)
 -- Proportional 2.5D silhouettes; collision, harvest, foot pivot unchanged.
 local scale=Sprite.scale_for(family,z,o.id)
 if x+64*scale<0 or x-64*scale>w or
    y+8*scale<0 or y-124*scale>h then
   self.culled=self.culled+1;return
 end
 -- Keep ObjectRenderer Y-depth order when object pages alternate.
 if self.pending>=self.limit or
   (self.current_page and self.current_page~=a.page) then self:flush(g) end
 local batch=self:batch_for(a.page)
 g.setColor(.06,.09,.08,.26)
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
