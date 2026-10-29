-- Canonical pixel/world alignment for prospective modular 2.5D sprite assets.
-- Pure metadata, no PNGs or GPU allocations. A single 1024px geometry reference
-- is used for EVERY direction; visual art cannot redefine a piece's socket geometry.
local Iso=require("world.iso")
local V={}
V.schema_version=1
V.source_px=1024
V.processed_px=256
V.source_ppu=8*math.sqrt(2) -- 32x32 world floor => 512x256 source diamond
V.pivot_x,V.pivot_y=512,768
V.safe_margin=64
V.direction_names={"south","west","north","east"}
V.required_alpha="RGBA8_straight"
V.lighting="neutral_diffuse_no_baked_ground_shadow"
V.sprite_scale=(V.source_px/V.processed_px)/V.source_ppu
local function finite(v)
  return type(v)=="number" and v==v and v<math.huge and v>-math.huge
end
local function rotate(x,y,r)
  if r==0 then return x,y
  elseif r==1 then return -y,x
  elseif r==2 then return -x,-y
  elseif r==3 then return y,-x end
  error("only four authored construction orientations")
end
local function mark(x,y,z)
  local sx,sy=Iso.project(x,y,z)
  return {x=x,y=y,z=z,sx=sx,sy=sy,
    px=V.pivot_x+sx*V.source_ppu,
    py=V.pivot_y+sy*V.source_ppu}
end
function V.layout(def,rotation)
  assert(type(def)=="table" and type(def.size)=="table" and
    type(def.sockets)=="table" and def.visual and def.rotation_steps==4,
    "authored 4-view building definition required")
  assert(type(rotation)=="number" and rotation==math.floor(rotation) and
    rotation>=0 and rotation<4,"invalid orientation")
  local visual_size=def.visual.module_size or def.size
  local w,d,h=visual_size[1],visual_size[2],visual_size[3]
  assert(finite(w) and finite(d) and finite(h) and w>0 and d>0 and h>0)
  local layout={asset_id=("tamu.building.%s.%s.%s"):format(
      def.visual.material,def.visual.shape,V.direction_names[rotation+1]),
    rotation=rotation,direction=V.direction_names[rotation+1],
    source={width=V.source_px,height=V.source_px,
      anchor_x=V.pivot_x,anchor_y=V.pivot_y},
    output={width=V.processed_px,height=V.processed_px,
      runtime_scale=V.sprite_scale},bottom={},top={},sockets={}}
  for _,corner in ipairs({
    {"nw",-w/2,-d/2},{"ne",w/2,-d/2},
    {"se",w/2,d/2},{"sw",-w/2,d/2}
  }) do
    local x,y=rotate(corner[2],corner[3],rotation)
    layout.bottom[corner[1]]=mark(x,y,0)
    local upper=h
    -- Slope and stair silhouette rise toward local -Y, with a level-low front.
    -- Their physical collision stays a conservative AABB in Kit V1.
    if def.visual.shape=="roof_slope" or def.visual.shape=="stairs" then
      upper=h*(d/2-corner[3])/d
    end
    layout.top[corner[1]]=mark(x,y,upper)
  end
  for _,s in ipairs(def.sockets) do
    local x,y=rotate(s.x,s.y,rotation)
    layout.sockets[s.id]=mark(x,y,s.z)
  end
  local minx,miny,maxx,maxy=math.huge,math.huge,-math.huge,-math.huge
  for _,layer in ipairs({layout.bottom,layout.top}) do
    for _,p in pairs(layer) do
      minx=math.min(minx,p.sx);maxx=math.max(maxx,p.sx)
      miny=math.min(miny,p.sy);maxy=math.max(maxy,p.sy)
    end
  end
  layout.screen_bounds={min_x=minx,min_y=miny,max_x=maxx,max_y=maxy}
  return layout
end
function V.precompute(definitions)
  assert(type(definitions)=="table","definitions required")
  local cache={}
  for id,def in pairs(definitions) do
    local views={}
    for rotation=0,3 do
      local layout=V.layout(def,rotation)
      assert(V.check_canvas(layout),"building visual outside safe canvas: "..id)
      views[rotation]=layout
    end
    cache[id]=views
  end
  return cache
end
function V.check_canvas(layout)
  assert(layout and layout.bottom and layout.top,"layout required")
  local lo,hi=V.safe_margin,V.source_px-V.safe_margin
  for _,layer in ipairs({layout.bottom,layout.top}) do
    for _,corner in pairs(layer) do
      if corner.px<lo-1e-6 or corner.px>hi+1e-6 or
         corner.py<lo-1e-6 or corner.py>hi+1e-6 then
        return false,"geometry_outside_safe_canvas"
      end
    end
  end
  return true
end
-- Pixel coordinates are a drawing template, NOT a crop guessed from a generated PNG.
-- Production QA must measure its actual alpha landmarks against these targets.
return V
