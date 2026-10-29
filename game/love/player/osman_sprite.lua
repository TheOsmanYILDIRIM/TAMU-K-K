-- TAMU KOK: 4-direction right-handed pre-rendered Rigby2D character.
-- The original plasma renderer remains available with TAMU_USE_PLASMA=1.
local Json=require("save.json")
local M={}
local dir="assets/osman_rig/"
local clips,cache=nil,{}
local function load()
  if clips then return end
  clips=Json.decode(assert(love.filesystem.read(dir.."clips.json")))
end
local function get(name)
  local cached=cache[name]
  if cached then return cached end
  local info=assert(clips[name],"Missing clip "..name)
  local image=love.graphics.newImage(dir..name..".png")
  image:setFilter("linear","linear")
  local frames={}
  for i=0,info.frames-1 do
    frames[i+1]=love.graphics.newQuad(256*i,0,256,320,image:getDimensions())
  end
  cached={image=image,frames=frames,count=info.frames,duration=info.duration}
  cache[name]=cached
  return cached
end
local function facing(name)
  if name=="N" or name=="NW" then return "back_" end
  if name=="NE" or name=="E" then return "mirror_back_" end
  if name=="W" or name=="SW" then return "mirror_" end
  return ""
end
function M.clip(face,state,tool)
  local action=tool=="axe" and "chop" or tool=="pickaxe" and "mine"
  return facing(face)..(action or (state=="walk" and "walk" or "idle"))
end
function M.draw(g,camera,w,h,player,ctx)
  ctx=ctx or {}
  load()
  local a=get(M.clip(player.facing,player.state,ctx.tool))
  local t=ctx.tool and (ctx.tool_seconds or player.time or 0) or (player.time or 0)
  local index=math.min(a.count,1+math.floor((t%a.duration)/a.duration*a.count))
  local px,py=camera:project(player.x,player.y,w,h)
  local z=camera.zoom*.25
  local x,y=px-128*z,py-311*z
  local immersion=math.max(0,math.min(1,player.immersion or 0))
  g.push("all")
  g.setColor(.02,.04,.06,.28)
  g.ellipse("fill",px,py+2*z,13*camera.zoom,5*camera.zoom)
  g.setColor(1,1,1)
  if immersion>0 then
    local cut=math.max(0,math.min(h,math.floor(py-17*camera.zoom*immersion)))
    g.setScissor(0,0,w,cut)
    g.draw(a.image,a.frames[index],x,y,0,z,z)
    g.setScissor(0,cut,w,h-cut)
    g.setColor(1,1,1,.2)
    g.draw(a.image,a.frames[index],x,y,0,z,z)
    g.setScissor()
  else
    g.draw(a.image,a.frames[index],x,y,0,z,z)
  end
  g.pop()
end
return M
