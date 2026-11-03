-- 34 authored-by-code placeholders, one atlas upload, viewport-limited SpriteBatch.
-- Artwork is optional and never part of authoritative construction state.
local Json=require("save.json")
local R={};R.__index=R
local function key(id,r)return id..":"..r end
function R.new()
 -- Neither decode the Creative atlas nor allocate GPU buffers on normal
 -- startup. Empty Creative state never enters the graphics setup path.
 return setmetatable({drawn=0,initialized=false},R)
end
function R:ensure_assets()
 if self.initialized then return end
 self.initialized=true
 local root="assets/"
 local data=love.filesystem.read(root.."creative_build_manifest.json")
 if not data then self.fallback=true;return end
 local meta=Json.decode(data)
 assert(meta.canvas[1]==128 and meta.canvas[2]==128 and
   meta.max_visible_rgb_colors==64 and #meta.entries==34 and
   meta.anchor[1]==64 and meta.anchor[2]==92,"invalid creative sprite metadata")
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
 self.image=image;self.views=ids
 self.batch=love.graphics.newSpriteBatch(image,1024,"dynamic")
end
function R:quad(def_id,rotation)
 local group=assert(self.views[def_id],"creative art definition missing: "..tostring(def_id))
 return group[rotation] or group[rotation%2] or group[0]
end
function R:draw(model,camera,w,h)
 -- Existing constructions must still render, even when Creative is off.
 if model.items and next(model.items)==nil
    and not (model.active and model.target) then
   self.drawn=0
   return 0
 end
 local visible=model:visible(camera,w,h)
 if #visible==0 and not (model.active and model.target) then
   self.drawn=0
   return 0
 end
 self:ensure_assets()
 local scale=(camera.zoom or 1)/2
 if self.fallback then
  local g=love.graphics
  g.push("all")
  for _,part in ipairs(visible) do
   local sx,sy=camera:project(part.x,part.y,w,h)
   sy=sy-part.z*camera.zoom
   local radius=16*camera.zoom
   if part.shape=="foundation" or part.shape=="floor" or
     part.shape=="roof_flat" or part.shape=="roof_slope" then
    g.setColor(.55,.40,.28,.92)
    g.polygon("fill",sx,sy-radius*.45,sx+radius,sy,sx,sy+radius*.45,sx-radius,sy)
   else
    g.setColor(.52,.35,.23,.97)
    g.rectangle("fill",sx-radius*.7,sy-radius*.55,radius*1.4,radius*.78)
   end
  end
  g.pop()
  self.drawn=#visible
  return #visible
 end
 local batch=self.batch
 batch:clear()
 local count=0
 for _,part in ipairs(visible) do
  local sx,sy=camera:project(part.x,part.y,w,h)
  sy=sy-part.z*camera.zoom
  if sx>=-160 and sx<=w+160 and sy>=-180 and sy<=h+160 then
   local quad=self:quad(part.def_id,part.rotation)
   if count>=1024 then break end
   batch:add(quad,sx,sy,0,scale,scale,64,92)
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
   local sx,sy=camera:project(part.x,part.y,w,h)
   love.graphics.setColor(.35,1,.55,.65)
   love.graphics.draw(self.image,self:quad(part.def_id,part.rotation),sx,sy-part.z*camera.zoom,
     0,scale,scale,64,92)
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
return R
