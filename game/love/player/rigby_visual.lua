-- LÖVE renderer for live Rigby bones and CPU-skinned meshes; no frame atlas.
local Rig=require('player.rigby_runtime')
local Json=require('save.json')
local V={}
local base='assets/osman_rig/'
local source,directions,display
local textures={}
local instances=setmetatable({},{__mode='k'})
local loop_actions={idle=true,walk=true,run=true,mine=true,chop=true}
local function load_data()
  if source then return end
  local function read(name) return Json.decode(assert(love.filesystem.read(base..name))) end
  source=read('rig.json');directions=read('directions.json').directions;display=read('display.json')
end
function V.direction(face,previous)
  if face=='SE' or face=='SW' or face=='NE' or face=='NW' then return face end
  local choices={N={'NW','NE'},S={'SE','SW'},E={'SE','NE'},W={'SW','NW'}}
  local pair=choices[face or 'S'];assert(pair,'unknown facing')
  if previous==pair[1] or previous==pair[2] then return previous end
  return pair[1]
end
function V.action(state,tool)
  if tool then assert(tool=='axe' or tool=='pickaxe','unknown harvest tool')
    return tool=='axe' and 'chop' or 'mine'
  end
  return state=='run' and 'run' or state=='walk' and 'walk' or 'idle'
end
local Instance={};Instance.__index=Instance
function V.new_instance()
  load_data()
  local instance=setmetatable({rig=Rig.new(source),meshes={},active={},time=0,last_clock=nil,
    direction='SE',action='idle',clip=nil,transition=nil,transition_time=0},Instance)
  instance.rig:evaluate(directions.SE.animations.idle,0,false)
  return instance
end
local function texture(name)
  if not textures[name] then
    local path=base..'images/'..name..'.png'
    assert(love.filesystem.getInfo(path),'Missing original rig part '..path)
    local image=love.graphics.newImage(path)
    image:setFilter('linear','linear');textures[name]=image
  end
  return textures[name]
end
function Instance:sample(direction,action,time,looped,offsets)
  local d=assert(directions[direction],'unknown rig direction')
  local clip=assert(d.animations[action],'unknown rig action')
  self.direction,self.action,self.clip=direction,action,clip
  self.rig:evaluate(clip,time,looped,offsets)
  return self
end
function Instance:prepare()
  self.active=self.rig:quads()
  for _,q in ipairs(self.active) do
    local key=q.slot..'/'..q.attachment;local mesh=self.meshes[key]
    if not mesh then
      mesh=love.graphics.newMesh(q.vertices,'triangles','stream')
      mesh:setVertexMap(q.triangles);mesh:setTexture(texture(q.image))
      self.meshes[key]=mesh
    else mesh:setVertices(q.vertices) end
    q.gpu_mesh=mesh
  end
end
function Instance:socket(x,y,zoom)
  local d=directions[self.direction];local item=d.itemAttachment
  local p=self.rig:socket(d.rightHandBone,item.localX,item.localY)
  if x then
    local s=display.height/display.rig_height*(zoom or 1)
    p.x=x+(p.x-display.anchor.x)*s;p.y=y-(p.y-display.anchor.y)*s
    p.a=p.a*s;p.b=-p.b*s;p.c=p.c*s;p.d=-p.d*s
    p.determinant=p.a*p.d-p.b*p.c
  end
  p.bone=d.rightHandBone;p.direction=self.direction
  return p
end
function Instance:draw_at(g,x,y,zoom,alpha)
  local scale=display.height/display.rig_height*zoom
  g.push('all')
  if g.setMeshCullMode then g.setMeshCullMode('none') end
  g.setColor(1,1,1,alpha or 1)
  g.translate(x,y);g.scale(scale,-scale);g.translate(-display.anchor.x,-display.anchor.y)
  for _,q in ipairs(self.active) do g.draw(q.gpu_mesh) end
  g.pop()
end
function V.instance(player)
  if not instances[player] then instances[player]=V.new_instance() end
  return instances[player]
end
-- Optional visual-only action API; has no combat/harvest/inventory side effects.
function V.play(player,action,looped)
  local i=V.instance(player)
  assert(directions[i.direction].animations[action],'unknown visual action')
  i.request={action=action,looped=looped==true,start=player.time or 0}
end
function V.right_hand(player,x,y,zoom) return V.instance(player):socket(x,y,zoom) end
function V.update_pose(player,ctx)
  ctx=ctx or {};local i=V.instance(player)
  local clock=player.time or 0
  local dt=i.last_clock and math.max(0,math.min(clock-i.last_clock,.2)) or 0
  i.last_clock=clock
  local direction=V.direction(ctx.facing or player.facing,i.direction)
  local action=ctx.action or V.action(player.state,ctx.tool)
  local looped=loop_actions[action] or false
  local forced_time=ctx.tool and ctx.tool_seconds or ctx.animation_time
  if i.request and not ctx.tool then
    local a=assert(i.rig.animations[directions[direction].animations[i.request.action]])
    if i.request.looped or clock-i.request.start<a.duration then
      action=i.request.action;looped=i.request.looped;forced_time=clock-i.request.start
    else i.request=nil end
  end
  local clip=assert(directions[direction].animations[action],'unknown action')
  -- Animation-only mobile sampling at 30 Hz: maintain full-rate gameplay,
  -- camera, movement and collision while avoiding redundant CPU skinning
  -- and GPU vertex uploads between animation ticks. Actions, facing and
  -- explicit tool frames always sample immediately.
  local mobile=love.system and love.system.getOS and love.system.getOS()=='Android'
  local hz=tonumber(os.getenv('TAMU_RIGBY_POSE_HZ')) or (mobile and 30 or 0)
  if hz>0 and not ctx.bone_offsets and not i.transition and
     not i.request and not ctx.tool and forced_time==nil and
     i.clip==clip and i.direction==direction and
     i.pose_clock and clock-i.pose_clock>=0 and
     clock-i.pose_clock<1/hz then
    return i
  end
  i.pose_clock=clock
  local previous=i.clip
  local changed=clip~=previous
  if changed then
    local same_direction=direction==i.direction
    if previous and same_direction and display.blend_seconds>0 then
      i.transition=i.rig:capture();i.transition_time=0
    else i.transition=nil end
    if previous and action==i.action then
      i.time=(i.time/i.rig.animations[previous].duration)*i.rig.animations[clip].duration
    else i.time=0 end
  end
  if forced_time~=nil then i.time=forced_time else i.time=i.time+dt end
  i:sample(direction,action,i.time,looped,ctx.bone_offsets)
  if i.transition then
    i.transition_time=i.transition_time+dt
    local a=math.min(1,i.transition_time/display.blend_seconds)
    i.rig:blend_from(i.transition,a*a*(3-2*a))
    if a>=1 then i.transition=nil end
  end
  i:prepare()
  return i
end
function V.draw(g,camera,width,height,player,ctx)
  local i=V.update_pose(player,ctx)
  local px,py=camera:project(player.x,player.y,width,height)
  local z=camera.zoom;local immersion=math.max(0,math.min(1,player.immersion or 0))
  g.push('all')
  g.setColor(.02,.04,.06,.28*(1-.6*immersion))
  g.ellipse('fill',px,py+2*z,13*z,5*z)
  if immersion>0 then
    local waterline=py-display.height*z*immersion
    local cut=math.max(0,math.min(height,math.floor(waterline)))
    g.setScissor(0,0,width,cut);i:draw_at(g,px,py,z,1)
    g.setScissor(0,cut,width,height-cut);i:draw_at(g,px,py,z,.16)
    g.setScissor();g.setColor(.4,.79,.86,.72);g.setLineWidth(math.max(1,z))
    g.ellipse('line',px,waterline,13*z,4*z)
  else i:draw_at(g,px,py,z,1) end
  g.pop()
end
return V
