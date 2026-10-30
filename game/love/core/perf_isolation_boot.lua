-- Hard isolation launcher: no game, world, worker or character modules load
-- before the user selects a mode. Does not modify saves or user settings.
local Boot={}
local options={
 {id='full',label='TAM OYUN'},
 {id='character',label='SADECE KARAKTER'},
 {id='terrain',label='SADECE GERCEK R2 ARAZI'},
 {id='objects',label='SADECE OBJELER'},
 {id='terrain_objects',label='ARAZI + OBJELER'},
 {id='character_objects',label='KARAKTER + OBJELER'},
 {id='none',label='BOS SAHNE / MOTOR TABANI'}
}
local selected=nil
local current=nil
local cam=nil
local assets={}
local count=0
local elapsed=0
local fingers={}
local mouse_drag=nil
local function view() return love.graphics.getDimensions() end
local function region(i)
 local w,h=view()
 local top=math.max(80,h*.13)
 local spacing=math.min(64,(h-top-90)/#options)
 return w*.08,top+(i-1)*spacing,w*.84,spacing-5
end
local function includes(mode,key)
 return mode==key or mode=='terrain_objects' and (key=='terrain' or key=='objects')
  or mode=='character_objects' and (key=='character' or key=='objects')
end
local function prepare(mode)
 cam=require('core.camera').new()
 cam.zoom=1.4
 if mode=='none' then return end
 local m,page
 if includes(mode,'objects') then
   local json=require('save.json')
   m=json.decode(assert(love.filesystem.read('assets/terrain25d/manifest.json')))
   page={}
   for _,p in ipairs(m.atlas_pages) do page[p.filename]=p end
 end
 if includes(mode,'terrain') then
   -- Real authored R2 + production 25D terrain only: no object renderer,
   -- character, harvest, physics update, UI or game simulation.
   local pilot=require('world.r2_playable').new()
   pilot:mount_camera(cam)
   cam.x,cam.y=pilot.spawn_site.anchor[1],pilot.spawn_site.anchor[2]
   local stream=require('world.stream')
   local renderer=require('world.terrain25d_runtime')
   assets.r2=pilot
   assets.stream=stream.new(pilot.query,{
     size=256,step=8,max_loaded=80,warm_limit=16,
     build_budget=12,render_only_25d=true
   })
   assets.terrain_runtime=renderer.new(pilot)
   assets.terrain_stats=nil
 end
 if includes(mode,'objects') then
   local p=assert(page['atlas_01.png'])
   assets.object_img=love.graphics.newImage('assets/terrain25d/atlas_01.png')
   assets.object_quads={}
   for _,a in ipairs(m.assets) do
     if a.kind=='object' and (a.family=='oak' or a.family=='conifer') then
       assets.object_quads[#assets.object_quads+1]=love.graphics.newQuad(
         a.uv_rect[1]*p.width,a.uv_rect[2]*p.height,a.uv_rect[3]*p.width,
         a.uv_rect[4]*p.height,p.width,p.height)
     end
   end
   assert(#assets.object_quads>0)
   local w,h=view()
   local batch=love.graphics.newSpriteBatch(assets.object_img,24,'static')
   local n=#assets.object_quads
   for i=1,24 do
     local x=(i*113)%math.max(1,w)
     local y=h*.20+(i*79)%math.max(1,math.floor(h*.66))
     batch:add(assets.object_quads[(i-1)%n+1],x,y,0,1.05,1.05,64,124)
   end
   assets.object_batch=batch
 end
 if includes(mode,'character') then
   assets.rig=require('player.rigby_visual')
   assets.actor={x=0,y=0,immersion=0,state='idle',facing='SE'}
 end
end
local function draw_scene()
 local g=love.graphics
 local w,h=view()
 g.clear(.065,.105,.11,1)
 if assets.terrain_runtime then
   assets.terrain_runtime:draw(assets.stream,cam,w,h)
 end
 if assets.object_img then
   g.setColor(1,1,1)
   local px,py=cam:project(0,0,w,h)
   local factor=cam.zoom/1.4
   g.draw(assets.object_batch,px-factor*w*.5,py-factor*h*.5,0,factor,factor)
 end
 if assets.rig then assets.rig.draw(g,cam,w,h,assets.actor,{}) end
 g.setColor(1,1,1)
 g.print('IZOLE GORSEL TEST - '..selected,12,14)
 g.print('ESC: MOD SECIMI   FPS '..love.timer.getFPS(),12,34)
 g.print('SURUKLE: KAMERA  |  PINCH: ZOOM  |  WASD/OKLAR',12,54)
 if assets.terrain_runtime then
   g.print(string.format('R2 CHUNKS %d / %d  MISSING %d',
     assets.terrain_stats and assets.terrain_stats.loaded or 0,
     assets.terrain_stats and assets.terrain_stats.needed or 0,
     assets.terrain_runtime.missing_visible or 0),12,74)
 end
end
local function select_mode(mode)
 if mode=='full' then
   _G.TAMU_ISOLATION_SELECTED=true
   local chunk=assert(love.filesystem.load('main.lua'))
   chunk() -- installs original LOVE callbacks, only now requires game modules.
   assert(type(love.load)=='function')
   love.load()
   return
 end
 selected=mode
 assets={}
 count=0
 elapsed=0
 fingers={}
 mouse_drag=nil
 prepare(mode)
end
function Boot.install()
 function love.load() end
 function love.update(dt)
   if selected then
     count=count+1;elapsed=elapsed+dt
     if assets.actor then assets.actor.time=elapsed end
     if assets.terrain_runtime then
       assets.terrain_runtime:advance_sun(dt)
       local w,h=view()
       assets.terrain_stats=assets.stream:update(cam,w,h)
     end
     if cam then
       local speed=420*dt/math.max(.4,cam.zoom)
       local dx=(love.keyboard.isDown('d','right') and 1 or 0)-(love.keyboard.isDown('a','left') and 1 or 0)
       local dy=(love.keyboard.isDown('s','down') and 1 or 0)-(love.keyboard.isDown('w','up') and 1 or 0)
       if dx~=0 or dy~=0 then cam:pan(-dx*speed*cam.zoom,-dy*speed*cam.zoom) end
     end
   end
 end
 function love.draw()
   local g=love.graphics
   if selected then draw_scene();return end
   local w,h=view()
   g.clear(.035,.065,.075,1)
   g.setColor(.9,.96,.95)
   g.printf('TAMU / IZOLASYON TESTI',0,35,w,'center')
   g.printf('Mod secilene kadar oyun yuklenmez',0,62,w,'center')
   for i,o in ipairs(options) do
     local x,y,bw,bh=region(i)
     g.setColor(.13,.24,.26,.96)
     g.rectangle('fill',x,y,bw,bh,9,9)
     g.setColor(1,1,1)
     g.printf(o.label,x,y+bh*.3,bw,'center')
   end
 end
 local function hit(x,y)
   if selected then return end
   for i,o in ipairs(options) do
     local bx,by,bw,bh=region(i)
     if x>=bx and x<=bx+bw and y>=by and y<=by+bh then
       select_mode(o.id);return
     end
   end
 end
 local function positions()
   local points={}
   for _,p in pairs(fingers) do points[#points+1]=p end
   return points
 end
 function love.touchpressed(id,x,y)
   if not selected then hit(x,y);return end
   fingers[id]={x=x,y=y}
 end
 function love.touchmoved(id,x,y)
   local p=fingers[id]
   if not p or not cam then return end
   local others=positions()
   if #others==2 then
     local q=others[1]==p and others[2] or others[1]
     local before=math.sqrt((p.x-q.x)^2+(p.y-q.y)^2)
     local after=math.sqrt((x-q.x)^2+(y-q.y)^2)
     if before>4 and after>4 then
       local w,h=view()
       cam:zoom_at(after/before,(x+q.x)/2,(y+q.y)/2,w,h)
     end
   elseif #others==1 then cam:pan(x-p.x,y-p.y) end
   p.x,p.y=x,y
 end
 function love.touchreleased(id) fingers[id]=nil end
 function love.mousepressed(x,y,b,istouch)
   if istouch or b~=1 then return end
   if not selected then hit(x,y) else mouse_drag={x=x,y=y} end
 end
 function love.mousemoved(x,y,_,_,istouch)
   if istouch or not mouse_drag or not cam then return end
   cam:pan(x-mouse_drag.x,y-mouse_drag.y)
   mouse_drag.x,mouse_drag.y=x,y
 end
 function love.mousereleased(_,_,b) if b==1 then mouse_drag=nil end end
 function love.wheelmoved(_,dy)
   if not selected or not cam then return end
   local x,y=love.mouse.getPosition()
   local w,h=view()
   cam:zoom_at(1.15^dy,x,y,w,h)
 end
 function love.keypressed(key)
   if key=='escape' and selected then
     love.event.quit('restart')
   elseif not selected then
     local i=tonumber(key)
     if i and options[i] then select_mode(options[i].id) end
   end
 end
end
return Boot
