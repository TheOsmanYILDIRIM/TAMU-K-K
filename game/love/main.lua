-- Integrated procedural world and playable placeholder player.
local Query=require("world.world_query")
local Stream=require("world.stream")
local Terrain=require("world.terrain_renderer")
local Adapter=require("world.collision_adapter")
local ObjectWorld=require("objects.world")
local ObjectQuery=require("objects.query")
local Harvest=require("objects.harvesting")
local Wallet=require("objects.wallet")
local ObjectRenderer=require("objects.renderer")
local Controller=require("player.controller")
local Collision=require("physics.collision")
local Joystick=require("player.joystick")
local Camera=require("core.camera")
local Iso=require("world.iso")
local query=Query.new(20261015)
local water=Adapter.new(query,8)
local objects=ObjectWorld.new(query,water)
local solid=ObjectQuery.new(water,objects)
local harvesting=Harvest.new(objects,38)
local wallet=Wallet.new()
local stream=Stream.new(query,{size=256,step=32,max_loaded=100,build_budget=5})
local camera=Camera.new()
local joystick=Joystick.new(64)
local player
local w,h=720,1100
local fingers={}
local pinch_distance=nil
local stage4_smoke=os.getenv("OSMAN_LOVE_STAGE4_SMOKE")=="1"
local smoke=stage4_smoke or os.getenv("OSMAN_LOVE_SMOKE")=="1" or os.getenv("OSMAN_LOVE_INTEGRATION_SMOKE")=="1"
local frames=0
local screenshot_done=false
local stats={loaded=0,needed=0,pending=0}
local joystick_center
local route_status=""
local selected_target=nil
local command_number=0
local safe_area
local object_count=0
local stage4_before=false
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
  if stage4_smoke then
    -- Exercise the real touch-button interaction callback, not direct deplete.
    local selected=false
    for _,o in ipairs(objects:objects_in({min_x=-384,min_y=-384,max_x=384,max_y=384})) do
      for _,direction in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do
        local x=o.x+direction[1]*(o.radius+23)
        local y=o.y+direction[2]*(o.radius+23)
        if Collision.can_stand(solid,x,y,player.radius) then
          player.x,player.y=x,y
          camera.x,camera.y=x,y
          local sx,sy,sw,sh=safe_area()
          local bx,by=joystick_center()
          love.touchpressed("stage4_joystick",bx,by)
          love.touchpressed("stage4_smoke",sx+sw-75,sy+sh-140)
          love.touchreleased("stage4_smoke",sx+sw-75,sy+sh-140)
          love.touchreleased("stage4_joystick",bx,by)
          assert(joystick.id==nil,"joystick owner stuck after touch collection")
          if selected_target then selected=true;break end
        end
      end
      if selected then break end
    end
    assert(selected,"No valid touch-harvest fixture")
  end
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
  if selected_target and not harvesting.active and (not stage4_smoke or stage4_before) then
    local o=objects:get(selected_target)
    if not o or objects:is_depleted(selected_target) then selected_target=nil
    elseif (o.x-player.x)^2+(o.y-player.y)^2<=(harvesting.range+o.radius)^2 then
      command_number=command_number+1
      local result=harvesting:begin("harvest:"..command_number,o.id,player.x,player.y)
      route_status=result.ok and "Gathering "..o.kind or result.status
      selected_target=nil
      player:stop_navigation()
    end
  end
  harvesting:update(dt,player.x,player.y)
  for _,event in ipairs(harvesting:drain_events()) do
    wallet:apply(event)
    route_status="Collected "..event.amount.." "..event.item_id
  end
  if not debug_view then camera.x,camera.y=player.x,player.y end
  stats=stream:update(camera,w,h)
end
function love.draw()
  Terrain.draw(stream,camera,w,h)
  object_count=ObjectRenderer.draw(objects,stream,camera,w,h,player,selected_target)
  local g=love.graphics
  local safe_x,safe_y,safe_w,safe_h=safe_area()
  g.setColor(.05,.12,.12,.75)
  g.rectangle("fill",safe_x+8,safe_y+8,math.min(safe_w-16,600),124,12,12)
  g.setColor(1,1,1)
  g.print("WORLD OBJECTS / seed "..query.seed,safe_x+18,safe_y+15)
  g.print(string.format("Chunks %d/%d  Objects %d  State %s",stats.loaded,stats.needed,object_count,player.state),safe_x+18,safe_y+38)
  g.print(string.format("Wood %d  Stone %d  (E / tap object)",wallet:count("core:wood_log"),wallet:count("core:stone")),safe_x+18,safe_y+61)
  if route_status~="" then g.print(route_status,safe_x+18,safe_y+84) end
  if harvesting.active then
    g.setColor(.14,.25,.23,.85)
    g.rectangle("fill",safe_x+18,safe_y+106,190,9)
    g.setColor(.96,.75,.28)
    g.rectangle("fill",safe_x+18,safe_y+106,190*harvesting:progress(),9)
  end
  g.setColor(.12,.30,.31,.76)
  g.rectangle("fill",safe_x+safe_w-136,safe_y+safe_h-175,122,66,13,13)
  g.setColor(1,.95,.83)
  g.print("COLLECT",safe_x+safe_w-120,safe_y+safe_h-149)
  local bx,by=joystick_center()
  g.setColor(.2,.3,.34,.6)
  g.circle("fill",bx,by,72)
  g.setColor(.95,.95,.9,.7)
  g.circle("fill",bx+joystick.dx*55,by+joystick.dy*55,22)
  g.setColor(1,1,1)
  frames=frames+1
  if stage4_smoke and not stage4_before and frames>=20
     and stats.loaded>0 and stats.pending==0 then
    stage4_before=true
    love.graphics.captureScreenshot("world-objects-before.png")
  end
  if stage4_smoke and frames>1800 then error("Harvest smoke timed out before resource credit") end
  if smoke and frames>=20 and stats.loaded>0 and stats.pending==0
    and (not stage4_smoke or (stage4_before and
      wallet:count("core:wood_log")+wallet:count("core:stone")>0)) then
    if not screenshot_done then
      screenshot_done=true
      love.graphics.captureScreenshot(stage4_smoke and "world-objects-smoke.png" or (debug_view and "world-player-biome-smoke.png" or "world-player-smoke.png"))
    end
    print(string.format("%s frames=%d chunks=%d objects=%d wood=%d stone=%d player=(%.1f,%.1f)",stage4_smoke and "LOVE_STAGE4_SMOKE_OK" or "LOVE_INTEGRATION_SMOKE_OK",frames,stats.loaded,object_count,wallet:count("core:wood_log"),wallet:count("core:stone"),player.x,player.y))
    io.stdout:flush()
    love.event.quit()
  end
end
safe_area=function()
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
local function select_object(o)
  if harvesting.active then route_status="Already gathering";return end
  selected_target=o.id
  local distance=(o.x-player.x)^2+(o.y-player.y)^2
  if distance<=(harvesting.range+o.radius)^2 then return end
  -- Navigate to an approach ring outside the object's shared collision box.
  local reached=false
  for _,d in ipairs({{1,0},{0,1},{-1,0},{0,-1},{1,1},{-1,1},{-1,-1},{1,-1}}) do
    local mag=math.sqrt(d[1]*d[1]+d[2]*d[2])
    local px=o.x+d[1]/mag*(o.radius+24)
    local py=o.y+d[2]/mag*(o.radius+24)
    if math.abs(px-player.x)+math.abs(py-player.y)<2048 then
      local ok=player:navigate_to(px,py,16,1024)
      if ok then reached=true;break end
    end
  end
  if not reached then selected_target=nil;route_status="No approach route"
  else route_status="Approaching "..o.kind end
end
local function interact_nearest()
  local best,dist=nil,math.huge
  for _,o in ipairs(objects:objects_in({min_x=player.x-65,min_y=player.y-65,
    max_x=player.x+65,max_y=player.y+65})) do
    local d=(player.x-o.x)^2+(player.y-o.y)^2
    if d<dist and d<=(harvesting.range+o.radius)^2 then best,dist=o,d end
  end
  if best then select_object(best) else route_status="Move closer to a resource" end
end
local function press(id,x,y)
  fingers[id]={x=x,y=y,origin_x=x,origin_y=y,move=false}
  local sx,sy,sw,sh=safe_area()
  if x>=sx+sw-136 and x<=sx+sw-14 and y>=sy+sh-175 and y<=sy+sh-109 then
    fingers[id].button=true
    return
  end
  local bx,by=joystick_center()
  if (x-bx)^2+(y-by)^2<90^2 and joystick.id==nil then
    joystick:press(id,bx,by)
    joystick:move(id,x,y)
    fingers[id].joystick=true
  else
    local n=0
    for _,p in pairs(fingers) do if not p.joystick and not p.button then n=n+1 end end
    if n>=2 then
      for _,p in pairs(fingers) do if not p.joystick and not p.button then p.multi=true end end
      pinch_distance=nil
    end
  end
end
local function move(id,x,y)
  local p=fingers[id];if not p then return end
  if p.joystick then joystick:move(id,x,y);return end
  if p.button then return end
  if p.multi then
    local partner
    for other,q in pairs(fingers) do if other~=id and not q.joystick and not q.button then partner=q;break end end
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
  elseif p.button then interact_nearest()
  elseif not p.move and not p.multi then
    local target=ObjectRenderer.pick(objects,stream,camera,w,h,x,y)
    if target then select_object(target)
    else
      selected_target=nil
      local gx,gy=camera:unproject(x,y,w,h)
      local ok,reason=player:navigate_to(gx,gy,16,1024)
      route_status=ok and "Navigating" or ("No path: "..tostring(reason))
    end
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
  if key=="escape" then player:stop_navigation();selected_target=nil end
  if key=="e" then interact_nearest() end
end
