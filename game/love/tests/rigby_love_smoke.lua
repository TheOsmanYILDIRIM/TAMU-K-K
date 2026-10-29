-- Real LÖVE GPU smoke. This module is selected only by TAMU_RIGBY_SMOKE=1.
local V=require('player.rigby_visual')
local actions={'idle','nod','head_tilt','shrug','walk','run','punch','mine','chop','slash','thrust'}
local dirs={'SE','SW','NW','NE'}
local actors={};local frame=0;local fps=24;local pending=false;local finished=false
local samples={};local last_action
local function fail(message) io.stderr:write(message..'\n');io.stderr:flush();return 1 end
function love.errorhandler(message) return fail(debug.traceback(tostring(message))) end
function love.load()
  love.window.setMode(960,680,{resizable=false,vsync=0,highdpi=false})
  love.window.setTitle('TAMU — live Rigby runtime validation')
  love.filesystem.createDirectory('rigby_frames')
  for n=1,4 do actors[n]=V.new_instance() end
  for _,action in ipairs(actions) do
    local a=actors[1].rig.animations[action]
    samples[#samples+1]={action=action,frames=math.max(2,math.ceil(a.duration*fps)),duration=a.duration}
  end
  print('RIGBY_LOVE_ENGINE '..table.concat({love.getVersion()},'.'))
  print('RIGBY_LOVE_GPU '..tostring(love.graphics.getRendererInfo()))
end
local function current()
  local at=frame
  for _,entry in ipairs(samples) do
    if at<entry.frames then return entry,at/entry.frames*entry.duration end
    at=at-entry.frames
  end
end
function love.update()
  if finished then love.event.quit(0) end
end
function love.draw()
  if pending or finished then return end
  local entry,t=current()
  if not entry then
    print('RIGBY_LOVE_SMOKE_OK clips=44 frames='..frame..' live_mesh=true')
    io.stdout:flush();finished=true;return
  end
  local g=love.graphics
  g.clear(.075,.09,.12,1)
  g.setColor(.9,.93,1,1);g.print('TAMU KOK / LIVE BONES + WEIGHTED MESH',30,25,0,1.6,1.6)
  g.setColor(.55,.75,.9,1);g.print('44 clips / original body parts / no animation frames or flipX',30,65)
  for n,dir in ipairs(dirs) do
    local actor=actors[n];actor:sample(dir,entry.action,t,false);actor:prepare()
    local x=(n-.5)*240
    g.setColor(.14,.17,.22,1);g.rectangle('fill',(n-1)*240+12,110,216,465,12,12)
    g.setColor(.05,.06,.08,.8);g.ellipse('fill',x,520,68,16)
    actor:draw_at(g,x,520,4,1)
    local socket=actor:socket(x,520,4)
    assert(socket.x==socket.x and socket.y==socket.y,'invalid right-hand socket')
    g.setColor(.85,.9,1,1);g.print(dir,x-13,132,0,1.3,1.3)
    g.setColor(.5,.7,.85,1);g.printf(socket.bone,(n-1)*240+15,548,210,'center')
  end
  g.setColor(1,1,1,1);g.print(entry.action,30,604,0,1.7,1.7)
  g.setColor(.65,.75,.85,1);g.print(string.format('t = %.3f / %.2f seconds',t,entry.duration),300,610)
  pending=true
  local filename=string.format('rigby_frames/%05d.png',frame)
  local representative=entry.action~=last_action
  last_action=entry.action
  g.captureScreenshot(function(image)
    image:encode('png',filename)
    if representative then image:encode('png','rigby-'..entry.action..'.png') end
    pending=false;frame=frame+1
  end)
end
