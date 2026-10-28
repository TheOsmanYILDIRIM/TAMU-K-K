-- Mobile opt-in atlas sprite batching; original Y-depth/harvest stays authoritative.
local Sprite={};Sprite.__index=Sprite
local function hash(id)
 local n=19
 for i=1,#id do n=(n*33+id:byte(i))%2147483647 end
 return n
end
function Sprite.new(image,manifest)
 local w,h=image:getDimensions()
 local fam={}
 for _,a in ipairs(manifest.assets) do
   if a.kind=="object" and a.atlas_page=="atlas_00.png" and a.uv_rect then
     local u=a.uv_rect
     local f=fam[a.family] or {}
     f[#f+1]={id=a.id,quad=love.graphics.newQuad(
       u[1]*w,u[2]*h,u[3]*w,u[4]*h,w,h)}
     fam[a.family]=f
   end
 end
 for _,list in pairs(fam) do
   table.sort(list,function(a,b) return a.id<b.id end)
 end
 assert(fam.oak and fam.conifer and fam.boulder)
 local limit=1024
 return setmetatable({atlas=image,families=fam,
   batch=love.graphics.newSpriteBatch(image,limit,"stream"),
   limit=limit,pending=0,selected=nil,visible=0,culled=0,batches=0},Sprite)
end
function Sprite:begin_frame()
 self.batch:clear()
 self.pending=0;self.selected=nil;self.visible=0;self.culled=0
 self.batches=0
end
function Sprite:flush(g)
 if self.pending>0 then
   g.setColor(1,1,1,1)
   g.draw(self.batch)
   self.batch:clear();self.pending=0
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
   family=(math.floor(o.x/256)+math.floor(o.y/256))%3==0
     and "conifer" or "oak"
 elseif o.kind=="rock" then family="boulder"
 else family=self.families[o.kind] and o.kind or "shrub" end
 local choices=self.families[family] or self.families.oak
 local a=choices[1+hash(o.id)%#choices]
 local x,y=camera:project(o.x,o.y,w,h)
 local z=camera.zoom
 local scale=z*(family=="oak" and .78 or
   (family=="conifer" and .82 or (family=="boulder" and .50 or .40)))
 if x+64*scale<0 or x-64*scale>w or
    y+8*scale<0 or y-124*scale>h then
   self.culled=self.culled+1;return
 end
 if self.pending>=self.limit then self:flush(g) end
 g.setColor(.06,.09,.08,.26)
 g.ellipse("fill",x,y+2*z,o.radius*z*1.15,o.radius*z*.52)
 self.batch:add(a.quad,x,y,0,scale,scale,64,124)
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
