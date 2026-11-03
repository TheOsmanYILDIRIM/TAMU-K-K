-- Real LÖVE visual fixture using production CoreVisual + approved AxeStrike PNG.
-- No plasma FX, save writes, gameplay or renderer replacement.
local Core=require("player.core_visual")
local Axe=require("player.axe_strike")
local frame=0
local shot=false
local image
local W,H=320,700
local phaseNames={"prepare","strike","impact","recover"}
local times={.12,.42,.55,.79}
function love.load()
  local vw,vh=(os.getenv("OSMAN_CORE_AXE_VIEWPORT") or "320x700"):match("^(%d+)x(%d+)$")
  W,H=tonumber(vw),tonumber(vh)
  assert((W==320 and H==700) or (W==360 and H==780),"unexpected acceptance viewport")
  assert(love.window.setMode(W,H,{resizable=false}))
  image=love.graphics.newImage("assets/axe_121227.png")
  assert(image:getWidth()>100 and image:getHeight()>100,"real axe PNG required")
end
function love.update(dt) frame=frame+1 end
function love.draw()
  local g=love.graphics
  g.clear(.07,.12,.15,1)
  local camera={zoom=1.3,project=function(_,x,y,w,h) return w/2+x,h/2+y end}
  for i=1,4 do
    local y=90+(i-1)*math.floor((H-135)/4)
    local core={x=W*.38,y=y+28}
    local target={x=W*.64,y=y+8}
    g.setColor(.16,.23,.24,1)
    g.rectangle("fill",12,y-42,W-24,math.floor((H-135)/4)-4,10)
    g.setColor(.29,.22,.15,1)
    g.rectangle("fill",target.x-6,target.y-34,12,65)
    g.setColor(.20,.43,.25,1)
    g.polygon("fill",target.x-24,target.y-12,target.x,target.y-58,target.x+24,target.y-12)
    local player={x=core.x-W/2,y=core.y-H/2+21*camera.zoom,
      time=times[i],state="idle",immersion=0}
    Core.draw(g,camera,W,H,player,{})
    local pose=Axe.pose(times[i],core,target,.034*camera.zoom)
    assert(pose.phase==phaseNames[i],"axe phase mismatch")
    Axe.draw(g,image,times[i]*.88,core,target,.034*camera.zoom)
    g.setColor(1,1,1,1)
    g.print(phaseNames[i].." / "..string.format("%.2f",times[i]),18,y-35)
  end
  g.setColor(1,1,1,1)
  g.print("USER CORE PNG + AXE / NO PLASMA",12,14)
  if frame==12 and not shot then
    shot=true
    g.captureScreenshot("core-axe-"..W.."x"..H..".png")
  end
  if frame>=15 and shot then
    print("CORE_AXE_VISUAL_OK viewport="..W.."x"..H.." png=1 axe=original")
    io.stdout:flush()
    love.event.quit(0)
  end
end
