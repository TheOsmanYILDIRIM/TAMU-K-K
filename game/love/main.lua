-- Integrated procedural world and playable placeholder player.
local Query=require("world.world_query")
local Stream=require("world.stream")
local Terrain=require("world.terrain_renderer")
local Adapter=require("world.collision_adapter")
local Controller=require("player.controller")
local Joystick=require("player.joystick")
local Camera=require("core.camera")
local Iso=require("world.iso")
local query=Query.new(20261015)
local solid=Adapter.new(query,8)
local stream=Stream.new(query,{size=256,step=32,max_loaded=100,build_budget=5})
local camera=Camera.new()
local joystick=Joystick.new(64)
local player
local w,h=720,1100
local fingers={}
local pinch_distance=nil
local smoke=os.getenv("OSMAN_LOVE_SMOKE")=="1" or os.getenv("OSMAN_LOVE_INTEGRATION_SMOKE")=="1"
local frames=0
local screenshot_done=false
local stats={loaded=0,needed=0,pending=0}
local joystick_center
local route_status=""
local debug_view=os.getenv("OSMAN_LOVE_BIOME_SMOKE")=="1"
local function spawn()
  for radius=0,512,16 do
    for y=-radius,radius,16 do for x=-radius,radius,16 do
      if radius==0 or math.max(math.abs(x),math.abs(y))==radius then
        local ok,p=pcall(Controller.new,solid,{x=x,y=y,radius=5,speed=96})
        if ok then return p end
      end
    end end
  end
  error("No safe player spawn found within 512 world units")
end
function love.load()
  w,h=love.graphics.getDimensions()
  player=spawn()
  camera.x,camera.y=player.x,player.y
  if debug_view then camera.x,camera.y=-960,-960 end
end
function love.resize(width,height) w,h=width,height end
local function keyboard()
  local sx=(love.keyboard.isDown("d","right") and 1 or 0)-(love.keyboard.isDown("a","left") and 1 or 0)
  local sy=(love.keyboard.isDown("s","down") and 1 or 0)-(love.keyboard.isDown("w","up") and 1 or 0)
  local jx,jy=joystick:axis()
  if joystick.id~=nil then sx,sy=jx,jy end
  local wx,wy=Iso.unproject(sx,sy)
  local mag=math.sqrt(wx*wx+wy*wy)
  if mag>0 and (sx~=0 or sy~=0) then wx,wy=wx/mag,wy/mag end
  return wx,wy
end
function love.update(dt)
  local ax,ay=keyboard()
  player:update(dt,ax,ay)
  if not debug_view then camera.x,camera.y=player.x,player.y end
  stats=stream:update(camera,w,h)
end
function love.draw()
  Terrain.draw(stream,camera,w,h)
  local px,py=camera:project(player.x,player.y,w,h)
  local g=love.graphics
  g.setColor(.06,.12,.15,.55)
  g.ellipse("fill",px,py+4,player.radius*camera.zoom*1.4,player.radius*camera.zoom*.65)
  g.setColor(.98,.76,.28)
  g.polygon("fill",px,py-31,px-11,py-4,px,py+2,px+11,py-4)
  g.setColor(.19,.22,.29)
  g.circle("fill",px,py-36,8)
  g.setColor(1,1,1)
  g.print("WORLD + PLAYER / seed "..query.seed,16,18)
  g.print(string.format("Chunks %d/%d  State %s  Direction %s",stats.loaded,stats.needed,player.state,player.facing),16,40)
  g.print("WASD / arrows | Tap to walk | Wheel zoom | Touch joystick",16,62)
  if route_status~="" then g.print(route_status,16,84) end
  local bx,by=joystick_center()
  g.setColor(.2,.3,.34,.6)
  g.circle("fill",bx,by,72)
  g.setColor(.95,.95,.9,.7)
  g.circle("fill",bx+joystick.dx*55,by+joystick.dy*55,22)
  g.setColor(1,1,1)
  frames=frames+1
  if smoke and frames>=20 and stats.loaded>0 and stats.pending==0 then
    if not screenshot_done then
      screenshot_done=true
      love.graphics.captureScreenshot(debug_view and "world-player-biome-smoke.png" or "world-player-smoke.png")
    end
    print(string.format("LOVE_INTEGRATION_SMOKE_OK frames=%d chunks=%d player=(%.1f,%.1f)",frames,stats.loaded,player.x,player.y))
    io.stdout:flush()
    love.event.quit()
  end
end
local function safe_area()
  if love.window and love.window.getSafeArea then
    local sx,sy,sw,sh=love.window.getSafeArea()
    if sx and sy and sw and sh and sw>0 and sh>0 then return sx,sy,sw,sh end
  end
  return 0,0,w,h
end
joystick_center=function()
  local sx,sy,sw,sh=safe_area()
  return sx+math.min(94,sw*.25),sy+sh-112
end
local function press(id,x,y)
  fingers[id]={x=x,y=y,origin_x=x,origin_y=y,move=false}
  local bx,by=joystick_center()
  if (x-bx)^2+(y-by)^2<90^2 and joystick.id==nil then
    joystick:press(id,bx,by)
    joystick:move(id,x,y)
    fingers[id].joystick=true
  else
    local n=0
    for _,p in pairs(fingers) do if not p.joystick then n=n+1 end end
    if n>=2 then
      for _,p in pairs(fingers) do if not p.joystick then p.multi=true end end
      pinch_distance=nil
    end
  end
end
local function move(id,x,y)
  local p=fingers[id];if not p then return end
  if p.joystick then joystick:move(id,x,y);return end
  if p.multi then
    local partner
    for other,q in pairs(fingers) do if other~=id and not q.joystick then partner=q;break end end
    if partner then
      local old=math.sqrt((p.x-partner.x)^2+(p.y-partner.y)^2)
      local new=math.sqrt((x-partner.x)^2+(y-partner.y)^2)
      if old>1 and new>1 then camera:zoom_at(new/old,(x+partner.x)/2,(y+partner.y)/2,w,h) end
    end
  end
  if (x-p.origin_x)^2+(y-p.origin_y)^2>100 then p.move=true end
  p.x,p.y=x,y
end
local function release(id,x,y)
  local p=fingers[id];if not p then return end
  if p.joystick then joystick:release(id)
  elseif not p.move and not p.multi then
    local gx,gy=camera:unproject(x,y,w,h)
    local ok,reason=player:navigate_to(gx,gy,16,1024)
    route_status=ok and "Navigating" or ("No path: "..tostring(reason))
  end
  fingers[id]=nil
  pinch_distance=nil
  local n=0
  for _,q in pairs(fingers) do n=n+1 end
  if n==1 then for _,q in pairs(fingers) do q.multi=true end end
end
function love.touchpressed(id,x,y) press(id,x,y) end
function love.touchmoved(id,x,y) move(id,x,y) end
function love.touchreleased(id,x,y) release(id,x,y) end
function love.mousepressed(x,y,b,istouch) if b==1 and not istouch then press("mouse",x,y) end end
function love.mousemoved(x,y,_,_,istouch) if not istouch then move("mouse",x,y) end end
function love.mousereleased(x,y,b,istouch) if b==1 and not istouch then release("mouse",x,y) end end
function love.wheelmoved(_,dy)
  local x,y=love.mouse.getPosition()
  camera:zoom_at(1.15^dy,x,y,w,h)
end
function love.keypressed(key)
  if key=="r" then camera.x,camera.y=player.x,player.y;camera.zoom=1.7 end
  if key=="escape" then player:stop_navigation() end
end
