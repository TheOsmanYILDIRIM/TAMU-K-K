-- Optional code-generated placeholder draw adapter; no R2 or Stage5 coupling.
-- Feed a viewport-filtered list of built kit items; graphics are not serialized.
-- One GPU atlas and one SpriteBatch are allocated lazily; idle camera can reuse.
local Json=require("save.json")
local A={};A.__index=A
local function finite(n) return type(n)=="number" and n==n and n<math.huge and n>-math.huge end
local function key(def_id,rotation) return def_id..":"..rotation end
function A.new(root)
  assert(love and love.graphics and love.filesystem,"LÖVE graphics required")
  root=root or "assets/building_default/"
  assert(type(root)=="string" and root:sub(-1)=="/","directory must end in /")
  local raw=assert(love.filesystem.read(root.."building_default_manifest.json"),
    "run Python placeholder generator before using the atlas")
  local meta=Json.decode(raw)
  assert(meta.schema_version==1 and meta.canvas[1]==128 and meta.canvas[2]==128
    and meta.max_visible_rgb_colors==64 and #meta.entries==76
    and meta.anchor[1]==64 and meta.anchor[2]==92 and
    meta.atlas.size[1]==1024 and meta.atlas.size[2]==1280,
    "unsupported code-generated placeholder manifest")
  local image=assert(love.graphics.newImage(root..meta.atlas.filename))
  image:setFilter("nearest","nearest")
  local iw,ih=image:getDimensions()
  assert(iw==meta.atlas.size[1] and ih==meta.atlas.size[2],"atlas size mismatch")
  local quads={}
  for _,v in ipairs(meta.entries) do
    local r=v.atlas_rect
    assert(not quads[key(v.def_id,v.rotation)] and r[3]==128 and r[4]==128,
      "duplicate or invalid building view")
    quads[key(v.def_id,v.rotation)]=love.graphics.newQuad(r[1],r[2],128,128,iw,ih)
  end
  return setmetatable({image=image,quads=quads,anchor=meta.anchor,
    scale=1/meta.iso_pixels_per_unit,visible={},cached_signature=nil,
    batch=love.graphics.newSpriteBatch(image,2048,"dynamic"),draws=0},A)
end
function A:draw_visible(parts,camera,width,height,revision)
  assert(type(parts)=="table" and type(camera)=="table"
    and type(camera.project)=="function" and finite(width) and finite(height),
    "sorted visible parts/camera required")
  assert(#parts<=2048,"visible building draw budget exceeded")
  local list={}
  for _,part in ipairs(parts) do
    if part.status=="built" then
      local quad=assert(self.quads[key(part.def_id,part.rotation)],
        "no generated placeholder for "..tostring(part.def_id))
      local x,y=camera:project(part.x,part.y,width,height)
      -- Current camera may include 2.5D terrain height; piece z is additive.
      local scale=(camera.zoom or 1)*self.scale
      y=y-part.z*(camera.zoom or 1)
      local dx,dy=128*scale,128*scale
      if x+dx>=0 and x-dx<=width and y+dy>=0 and y-dy<=height then
        list[#list+1]={part=part,quad=quad,x=x,y=y,scale=scale}
      end
    end
  end
  table.sort(list,function(a,b)
    local da=a.part.x+a.part.y+0.0001*a.part.z
    local db=b.part.x+b.part.y+0.0001*b.part.z
    return da<db or (da==db and a.part.id<b.part.id)
  end)
  local batch=self.batch
  batch:clear()
  for _,v in ipairs(list) do
    batch:add(v.quad,v.x,v.y,0,v.scale,v.scale,self.anchor[1],self.anchor[2])
  end
  batch:flush()
  love.graphics.draw(batch)
  self.draws=#list
  return #list
end
function A:release()
  if self.batch then self.batch:release();self.batch=nil end
  if self.image then self.image:release();self.image=nil end
end
return A
