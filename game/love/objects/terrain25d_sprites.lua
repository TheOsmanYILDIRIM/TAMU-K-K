-- Render-only real atlas sprites; legacy ObjectRenderer retains depth/harvest.
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
 return setmetatable({atlas=image,families=fam},Sprite)
end
function Sprite:draw(g,camera,w,h,o,selected)
 local family
 if o.kind=="tree" then
   family=(math.floor(o.x/256)+math.floor(o.y/256))%3==0
     and "conifer" or "oak"
 elseif o.kind=="rock" then family="boulder"
 else family=self.families[o.kind] and o.kind or "shrub" end
 local variants=self.families[family] or self.families.oak
 local selected_sprite=variants[1+hash(o.id)%#variants]
 local x,y=camera:project(o.x,o.y,w,h)
 local z=camera.zoom
 local scale=z*(family=="oak" and .78 or
   (family=="conifer" and .82 or (family=="boulder" and .50 or .40)))
 g.setColor(.06,.09,.08,.26)
 g.ellipse("fill",x,y+2*z,o.radius*z*1.15,o.radius*z*.52)
 g.setColor(1,1,1,1)
 g.draw(self.atlas,selected_sprite.quad,x,y,0,scale,scale,64,124)
 if selected then
   g.setColor(1,.82,.3,.9);g.setLineWidth(2)
   g.ellipse("line",x,y,o.radius*z*1.5,o.radius*z*.8)
 end
end
return Sprite
