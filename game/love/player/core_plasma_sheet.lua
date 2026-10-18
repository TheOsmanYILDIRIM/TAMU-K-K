-- Core-agnostic transparent plasma overlay spritesheets (visual-only).
local S={}
local W,H,COLS,FRAMES,FPS=512,512,8,32,12
local paths={
  back="assets/core_plasma_back_spritesheet_32x512.png",
  front="assets/core_plasma_front_spritesheet_32x512.png"
}
local cache={}
function S.frame_index(seconds)
  assert(type(seconds)=="number" and seconds==seconds and math.abs(seconds)<math.huge,
    "plasma time must be finite")
  return math.floor(seconds*FPS)%FRAMES
end
function S.quad_position(index)
  assert(type(index)=="number" and index>=0 and index<FRAMES and index%1==0,
    "plasma frame index out of range")
  return (index%COLS)*W,math.floor(index/COLS)*H
end
local function load(g,name)
  if cache[name] then return cache[name] end
  local path=assert(paths[name],"unknown plasma layer")
  assert(love and love.filesystem and love.filesystem.getInfo(path),
    "missing packaged plasma sheet: "..path)
  local im=g.newImage(path)
  local iw,ih=im:getDimensions()
  assert(iw==W*COLS and ih==H*(FRAMES/COLS),
    "invalid plasma spritesheet dimensions: "..path)
  im:setFilter("linear","linear")
  local quads={}
  for i=0,FRAMES-1 do
    local x,y=S.quad_position(i)
    quads[i+1]=g.newQuad(x,y,W,H,iw,ih)
  end
  cache[name]={image=im,quads=quads}
  return cache[name]
end
-- Target extent: Core is drawn at 25*zoom px diameter; V4 preview Core used
-- 220 px inside a 560 px canvas; both layers use one identical screen anchor.
function S.draw(g,name,seconds,x,y,zoom,alpha)
  local resource=load(g,name)
  local f=S.frame_index(seconds)
  local fit=(25/220)*zoom
  g.setColor(1,1,1,alpha or 1)
  g.draw(resource.image,resource.quads[f+1],x,y,0,fit,fit,W/2,H/2)
  return f
end
return S
