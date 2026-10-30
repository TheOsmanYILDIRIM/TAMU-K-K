-- Hard isolation launcher: no game, world, worker or character modules load
-- before the user selects a mode. Does not modify saves or user settings.
local Boot={}
local options={
 {id='full',label='TAM OYUN'},
 {id='character',label='SADECE KARAKTER'},
 {id='terrain',label='SADECE ARAZI DOKUSU'},
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
 if mode=='none' then return end
 cam=require('core.camera').new()
 cam.zoom=1.4
 local m,page
 if includes(mode,'terrain') or includes(mode,'objects') then
   local json=require('save.json')
   m=json.decode(assert(love.filesystem.read('assets/terrain25d/manifest.json')))
   page={}
   for _,p in ipairs(m.atlas_pages) do page[p.filename]=p end
 end
 if includes(mode,'terrain') then
   local terrain=m.assets
   for _,a in ipairs(terrain) do
     if a.kind=='terrain' and a.family=='grass' then
       local p=page[a.atlas_page]
       assets.terrain_img=love.graphics.newImage('assets/terrain25d/'..a.atlas_page)
       assets.terrain_quad=love.graphics.newQuad(a.uv_rect[1]*p.width,a.uv_rect[2]*p.height,
         a.uv_rect[3]*p.width,a.uv_rect[4]*p.height,p.width,p.height)
       break
     end
   end
   assert(assets.terrain_img,'terrain atlas unavailable')
   local w,h=view()
   local batch=love.graphics.newSpriteBatch(assets.terrain_img,(math.ceil(w/95)+1)*(math.ceil(h/95)+1),'static')
   for y=0,h,95 do for x=0,w,95 do
     batch:add(assets.terrain_quad,x,y,0,.75,.75)
   end end
   assets.terrain_batch=batch
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
 if assets.terrain_img then
   -- Static visual baseline: no procedural generator, chunk/worker or ecology.
   g.setColor(1,1,1)
   g.draw(assets.terrain_batch)
 end
 if assets.object_img then
   g.setColor(1,1,1)
   g.draw(assets.object_batch)
 end
 if assets.rig then assets.rig.draw(g,cam,w,h,assets.actor,{}) end
 g.setColor(1,1,1)
 g.print('IZOLE GORSEL TEST - '..selected,12,14)
 g.print('ESC: MOD SECIMI   FPS '..love.timer.getFPS(),12,34)
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
 prepare(mode)
end
function Boot.install()
 function love.load() end
 function love.update(dt)
   if selected then
     count=count+1;elapsed=elapsed+dt
     if assets.actor then assets.actor.time=elapsed end
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
 function love.touchpressed(_,x,y) hit(x,y) end
 function love.mousepressed(x,y,b,istouch) if b==1 and not istouch then hit(x,y) end end
 function love.keypressed(key)
   if key=='escape' and selected then
     -- Re-enter a genuinely fresh process for full cleanup; no stale GPU state.
     love.event.quit('restart')
   elseif not selected then
     local i=tonumber(key)
     if i and options[i] then select_mode(options[i].id) end
   end
 end
end
return Boot
