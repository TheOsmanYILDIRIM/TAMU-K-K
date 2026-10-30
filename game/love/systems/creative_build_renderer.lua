-- TAMU Creative: source geometry, supports and 34-view atlas all share world.iso.
-- Model only supplies world poses; no per-frame terrain sampling or pixel alignment guess.
local Json=require("save.json")
local Iso=require("world.iso")
local R={};R.__index=R
local function key(id,r)return id..":"..r end
local fmt={{"VertexPosition","float",2},{"VertexColor","byte",4}}
local function tri(out,a,b,c,color)
 out[#out+1]={a[1],a[2],color[1],color[2],color[3],255}
 out[#out+1]={b[1],b[2],color[1],color[2],color[3],255}
 out[#out+1]={c[1],c[2],color[1],color[2],color[3],255}
end
local function quad(out,a,b,c,d,color)
 tri(out,a,b,c,color);tri(out,a,c,d,color)
end
local function support_vertices(out,s,stone)
 if s.top-s.ground<=0.3 then return end
 local r=1.6
 local lo,hi=s.ground-.6,s.top+.5
 local function p(dx,dy,z)
  local x,y=Iso.project(s.x+dx,s.y+dy,z)
  return {x,y}
 end
 local c1=stone and {93,96,90} or {116,77,52}
 local c2=stone and {125,122,106} or {145,101,65}
 quad(out,p(r,-r,lo),p(r,r,lo),p(r,r,hi),p(r,-r,hi),c1)
 quad(out,p(-r,r,lo),p(r,r,lo),p(r,r,hi),p(-r,r,hi),c2)
end
function R.new()
 local root="assets/"
 local data=love.filesystem.read(root.."creative_build_manifest.json")
 if not data then return setmetatable({fallback=true,drawn=0,support_signature=nil},R) end
 local meta=Json.decode(data)
 assert(meta.canvas[1]==128 and meta.canvas[2]==128 and
   meta.max_visible_rgb_colors==64 and #meta.entries==34 and
   meta.anchor[1]==64 and meta.anchor[2]==92 and
   meta.iso_pixels_per_unit==2,"invalid creative sprite metadata")
 local image=assert(love.graphics.newImage(root..meta.atlas.filename))
 image:setFilter("nearest","nearest")
 local width,height=image:getDimensions()
 assert(width==meta.atlas.size[1] and height==meta.atlas.size[2],"atlas size mismatch")
 local ids={}
 for _,e in ipairs(meta.entries) do
  local name=e.source_def_id or e.def_id
  ids[name]=ids[name] or {}
  ids[name][e.rotation]=love.graphics.newQuad(e.atlas_rect[1],e.atlas_rect[2],
    128,128,width,height)
 end
 return setmetatable({image=image,views=ids,
  batch=love.graphics.newSpriteBatch(image,1024,"dynamic"),
  drawn=0,support_signature=nil,support_mesh=nil,supports_drawn=0},R)
end
function R:quad(def_id,rotation)
 local group=assert(self.views[def_id],"creative art definition missing: "..tostring(def_id))
 return assert(group[rotation] or group[rotation%2] or group[0],
    "creative art orientation missing: "..def_id)
end
function R.project(camera,x,y,z,w,h)
 -- Do not use camera:project here: the R2 camera already subtracts
 -- terrain height, and subtracting the structure's world z a second time
 -- made every part float above the actual 2.5D terrain.
 local sx,sy=Iso.project(x-camera.x,y-camera.y,z)
 return w*.5+sx*camera.zoom,h*.5+sy*camera.zoom
end
function R:rebuild_supports(visible,revision,camera)
 local signature=table.concat({revision,
   math.floor(camera.x/128),math.floor(camera.y/128),
   math.floor(camera.zoom*4)},":")
 if self.support_signature==signature then return end
 self.support_signature=signature
 local vertices,number={},0
 for _,part in ipairs(visible) do
  if part.supports then
   for _,site in ipairs(part.supports) do
    support_vertices(vertices,site,part.shape=="foundation")
    number=number+1
   end
  end
 end
 if self.support_mesh then self.support_mesh:release();self.support_mesh=nil end
 if #vertices>0 then
  self.support_mesh=love.graphics.newMesh(fmt,vertices,"triangles","dynamic")
 end
 self.supports_drawn=number
end
function R:draw_supports(camera,w,h)
 if not self.support_mesh then return end
 local g=love.graphics
 local sx,sy=Iso.project(camera.x,camera.y)
 g.push("all")
 g.setColor(1,1,1,1)
 g.translate(w/2,h/2)
 g.scale(camera.zoom)
 g.translate(-sx,-sy)
 g.draw(self.support_mesh)
 g.pop()
end
function R:draw(model,camera,w,h)
 local visible=model:visible(camera,w,h)
 local scale=camera.zoom/2 -- matches 2 atlas pixels per projected world unit.
 if self.fallback then
  local g=love.graphics
  g.push("all")
  for _,part in ipairs(visible) do
   local sx,sy=R.project(camera,part.x,part.y,part.z,w,h)
   local rad=16*camera.zoom
   g.setColor(.54,.40,.27,.94)
   g.polygon("fill",sx,sy-rad*.5,sx+rad,sy,
       sx,sy+rad*.5,sx-rad,sy)
  end
  g.pop()
  self.drawn=#visible
  return #visible
 end
 self:rebuild_supports(visible,model.revision,camera)
 self:draw_supports(camera,w,h)
 local batch=self.batch
 batch:clear()
 local count=0
 for _,part in ipairs(visible) do
  local sx,sy=R.project(camera,part.x,part.y,part.z,w,h)
  if sx>=-160 and sx<=w+160 and sy>=-180 and sy<=h+160 then
   if count>=1024 then break end
   batch:add(self:quad(part.def_id,part.rotation),sx,sy,
    0,scale,scale,64,92)
   count=count+1
  end
 end
 batch:flush()
 love.graphics.push("all")
 love.graphics.setColor(1,1,1,1)
 love.graphics.draw(batch)
 if model.active and model.target then
  local ok,part=model:preview()
  if ok then
   local sx,sy=R.project(camera,part.x,part.y,part.z,w,h)
   love.graphics.setColor(.35,1,.55,.65)
   love.graphics.draw(self.image,self:quad(part.def_id,part.rotation),
     sx,sy,0,scale,scale,64,92)
  else
   local sx,sy=camera:project(model.target.x,model.target.y,w,h)
   love.graphics.setColor(1,.27,.23,.72)
   love.graphics.circle("line",sx,sy,10)
  end
 end
 love.graphics.pop()
 self.drawn=count
 return count
end
function R:release()
 if self.support_mesh then self.support_mesh:release();self.support_mesh=nil end
 if self.batch then self.batch:release();self.batch=nil end
 if self.image then self.image:release();self.image=nil end
end
return R
