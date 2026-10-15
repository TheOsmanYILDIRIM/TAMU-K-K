-- Pure-Lua player kinematics: a caller supplies WorldQuery and normalized axes.
local W=require('physics.world_query')
local C=require('physics.collision')
local D=require('player.direction')
local Depth=require('player.depth')
local Path=require('navigation.pathfinder')
local M={};M.__index=M
local STEP=1/60
local DEFAULT_SURFACE={speed_multiplier=1,immersion=0}
local function surface_at(query,x,y)
  if type(query.surface_at)~="function" then return DEFAULT_SURFACE end
  local surface=query:surface_at(x,y)
  assert(type(surface)=="table" and W.finite(surface.speed_multiplier)
    and surface.speed_multiplier>0 and surface.speed_multiplier<=1
    and W.finite(surface.immersion) and surface.immersion>=0
    and surface.immersion<=1,"invalid traversal surface")
  return surface
end
function M.new(query,options)
  W.assert_query(query)
  options=options or {}
  local x,y=options.x or 0,options.y or 0
  local r,speed=options.radius or 5,options.speed or 96
  assert(W.finite(x) and W.finite(y) and W.finite(r) and r>=0
    and W.finite(speed) and speed>0, 'invalid player options')
  assert(C.can_stand(query,x,y,r),'initial spawn is blocked')
  local surface=surface_at(query,x,y)
  return setmetatable({query=query,x=x,y=y,radius=r,speed=speed,
    surface_multiplier=surface.speed_multiplier,immersion=surface.immersion,
    facing='S',state='idle',time=0,accumulator=0,path=nil,path_index=1,
    frame=0,blocked=false},M)
end
function M:depth(z) return Depth.key(self.x,self.y,z) end
function M:navigate_to(x,y,cell,max_nodes)
  local path,reason=Path.find(self.query,self.x,self.y,x,y,self.radius,cell,max_nodes)
  if not path then self.path=nil;return false,reason end
  self.path=path;self.path_index=1
  return true
end
function M:stop_navigation() self.path=nil;self.path_index=1 end
function M:step(ax,ay)
  assert(W.finite(ax) and W.finite(ay),'nonfinite input axis')
  if ax~=0 or ay~=0 then self:stop_navigation()
  elseif self.path then
    local dest=self.path[self.path_index]
    while dest do
      local dx,dy=dest.x-self.x,dest.y-self.y
      if dx*dx+dy*dy > (self.speed*STEP*.5)^2 then ax,ay=dx,dy;break end
      self.path_index=self.path_index+1
      dest=self.path[self.path_index]
    end
    if not dest then self:stop_navigation() end
  end
  local len=math.sqrt(ax*ax+ay*ay)
  if len>1 then ax,ay=ax/len,ay/len end
  local surface=surface_at(self.query,self.x,self.y)
  local speed=self.speed*surface.speed_multiplier
  local dx,dy=ax*speed*STEP,ay*speed*STEP
  local ox,oy=self.x,self.y
  self.x,self.y,self.blocked=C.move(self.query,self.x,self.y,dx,dy,self.radius)
  local new_surface=surface_at(self.query,self.x,self.y)
  self.surface_multiplier=new_surface.speed_multiplier
  self.immersion=new_surface.immersion
  local moved_x,moved_y=self.x-ox,self.y-oy
  local moving=math.abs(moved_x)+math.abs(moved_y)>1e-7
  self.state=moving and 'walk' or (self.blocked and 'blocked' or 'idle')
  if moving then self.facing=D.from_world(moved_x,moved_y,self.facing) end
  self.time=self.time+STEP
  self.frame=self.frame+1
end
function M:update(dt,ax,ay)
  assert(W.finite(dt) and dt>=0,'invalid frame delta')
  ax,ay=ax or 0,ay or 0
  -- Deliberately drop pause spikes; bounded catch-up is a game-design policy.
  self.accumulator=self.accumulator+math.min(dt,STEP*6)
  local steps=0
  while self.accumulator+1e-12>=STEP and steps<6 do
    self:step(ax,ay)
    self.accumulator=self.accumulator-STEP
    steps=steps+1
  end
  if self.accumulator<0 then self.accumulator=0 end
  return steps
end
return M
