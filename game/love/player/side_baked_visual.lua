-- Two-view Quaternius Adventurer 3D bake (opt in; render-only).
local Json = require('save.json')
local V = {}
local ROOT = 'assets/character_side_bake/'
local manifest, image, quads

local function prepare()
  if image then return end
  local raw = love.filesystem.read(ROOT .. 'manifest.json')
  assert(raw, 'TAMU_BAKED_3D_AVATAR=1 needs Blender-generated atlas/manifest; see scripts/bake_3d_profile_character.py')
  local m = Json.decode(raw)
  assert(m.version == 1 and m.bottom_center_pivot == true and m.camera_pitch_degrees == 45,
    'Invalid 3D two-view bake contract')
  assert(type(m.frames)=='number' and m.frames>=1 and m.frames<=16 and
    type(m.fps)=='number' and m.fps>0 and type(m.width)=='number' and
    m.width>0 and type(m.height)=='number' and m.height>0,
    'Invalid 3D two-view bake dimensions')
  assert(m.rows and m.rows.front_idle==0 and m.rows.front_walk==1 and
    m.rows.back_idle==2 and m.rows.back_walk==3, 'Invalid two-view row order')
  local path = ROOT .. 'atlas.png'
  assert(love.filesystem.getInfo(path), 'Missing baked 3D atlas: ' .. path)
  local img = love.graphics.newImage(path)
  local iw, ih = img:getDimensions()
  assert(iw == m.width*m.frames and ih == m.height*4, 'Atlas dimensions mismatch')
  local qs = {}
  for row = 0, 3 do
    qs[row] = {}
    for frame = 0, m.frames-1 do
      qs[row][frame] = love.graphics.newQuad(frame*m.width, row*m.height,
        m.width, m.height, iw, ih)
    end
  end
  img:setFilter('linear', 'linear')
  manifest, image, quads = m, img, qs
end

function V.select(facing, moving, time)
  local sides={SE={0,false},SW={0,true},NE={2,false},NW={2,true}}
  local pair=assert(sides[facing or 'SE'], 'Expected diagonal facing')
  local count=manifest and manifest.frames or 8
  local fps=manifest and manifest.fps or 12
  local frame=moving and math.floor(math.max(0,time or 0)*fps)%count or 0
  return pair[1]+(moving and 1 or 0),pair[2],frame
end

function V.draw(g,camera,screen_w,screen_h,player,ctx)
  prepare()  -- no silent fallback to the live Rigby when opt-in assets are missing
  ctx=ctx or {}
  local moving=player.state=='walk' or player.state=='run'
  local face=ctx.facing or player.facing or 'SE'
  if face=='N' then face='NE' elseif face=='S' then face='SE'
  elseif face=='E' then face='SE' elseif face=='W' then face='SW' end
  local row,flip,frame=V.select(face,moving,player.time or 0)
  local px,py=camera:project(player.x,player.y,screen_w,screen_h)
  local scale=camera.zoom*(68/manifest.height)
  local immersion=math.max(0,math.min(1,player.immersion or 0))
  local width,height=manifest.width,manifest.height
  local function draw(alpha)
    g.setColor(1,1,1,alpha)
    g.draw(image,quads[row][frame],px,py,0,flip and -scale or scale,
      scale,width*.5,height-3)
  end
  g.push('all')
  g.setColor(.02,.04,.06,.28*(1-.6*immersion))
  g.ellipse('fill',px,py+2*camera.zoom,13*camera.zoom,5*camera.zoom)
  if immersion>0 then
    local cut=math.max(0,math.min(screen_h,math.floor(py-68*camera.zoom*immersion)))
    g.setScissor(0,0,screen_w,cut)
    draw(1)
    g.setScissor(0,cut,screen_w,screen_h-cut)
    draw(.16)
    g.setScissor()
  else
    draw(1)
  end
  g.pop()
end

return V
