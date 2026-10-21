package.path='./?.lua;./?/init.lua;'..package.path
local C=require('physics.collision')
local Player=require('player.controller')
local J=require('player.joystick')
local Path=require('navigation.pathfinder')
local D=require('player.direction')
local Depth=require('player.depth')
local function near(a,b,eps)
  assert(math.abs(a-b)<(eps or 1e-6), tostring(a)..' ~= '..tostring(b))
end
local function fixture(rects)
  return {obstacles=function(_,l,t,r,b)
    local out={}
    for _,o in ipairs(rects) do
      if o.x<r and o.x+o.w>l and o.y<b and o.y+o.h>t then
        out[#out+1]=o
      end
    end
    return out
  end}
end
local empty=fixture({})
local p=Player.new(empty,{speed=60,radius=2})
assert(p.state=='idle' and p.facing=='S')
assert(p:update(1/60,1,0)==1)
near(p.x,1);near(p.y,0)
assert(p.state=='walk' and p.facing==D.from_world(1,0))
local diag=Player.new(empty,{speed=60,radius=2})
diag:update(1/60,1,1)
near(math.sqrt(diag.x^2+diag.y^2),1)
assert(diag:update(1/60,0,0)==1 and diag.state=='idle')
assert(diag.facing==D.from_world(1,1))
local a,b=Player.new(empty,{speed=60}),Player.new(empty,{speed=60})
a:update(1/30,1,-.25)
b:update(1/60,1,-.25);b:update(1/60,1,-.25)
near(a.x,b.x);near(a.y,b.y);assert(a.frame==b.frame)
assert(a:update(.5,1,0)==6) -- spike bounded to six physics steps
assert(a.frame==8)
local invalid=pcall(function() Player.new({},{}) end)
assert(not invalid,'missing WorldQuery must not become empty world')
assert(not pcall(function() Player.new({obstacles=function() return nil end}) end))
assert(not pcall(function() Player.new(fixture({{x=0,y=0,w=10,h=10}})) end))
local wall=fixture({{x=10,y=-30,w=2,h=60}})
local bx,by,hit=C.move(wall,0,0,1000,0,2)
assert(hit and bx <= 8 and bx>7.9,'sweep must not tunnel')
near(by,0)
local slidex,slidey,slidehit=C.move(wall,0,0,100,12,2)
assert(slidehit and slidex <= 8 and slidey>0,'must slide along wall')
assert(C.can_stand(wall,slidex,slidey,2))
local block=Player.new(wall,{x=0,y=0,speed=600,radius=2})
for _=1,8 do block:update(1/60,1,0) end
assert(block.x<=8 and block.state=='blocked')
local joy=J.new(80,.12)
assert(joy:press(101,200,500))
assert(not joy:press(102,0,0),'secondary touch cannot steal joystick')
assert(joy:move(101,204,500))
local x,y=joy:axis();near(x,0);near(y,0)
assert(joy:move(101,280,500))
x,y=joy:axis();near(x,1);near(y,0)
assert(not joy:release(102))
assert(joy:release(101));x,y=joy:axis();near(x,0);near(y,0)
local ids={};for _,name in ipairs(D.names) do ids[name]=true end
for _,q in ipairs({{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,-1}}) do
  assert(ids[D.from_world(q[1],q[2])])
end
local front={id='b',depth=Depth.key(20,30)}
local back={id='a',depth=Depth.key(-10,-10)}
assert(Depth.before(back,front))
assert(Depth.before({id='a',depth=1},{id='b',depth=1}))
-- Finite rectangular wall, A* must detour without taking diagonal shortcuts.
local mid=fixture({{x=16,y=-8,w=16,h=16}})
local path,why=Path.find(mid,0,0,48,0,1,8,250)
assert(path and not why and #path>6,'find a path around a real wall')
for _,pt in ipairs(path) do assert(C.can_stand(mid,pt.x,pt.y,1)) end
local blocked,reason=Path.find(mid,0,0,24,0,1,8,250)
assert(not blocked and reason=='goal_blocked')
local narrow,limit=Path.find(mid,0,0,400,0,1,8,2)
assert(not narrow and limit=='search_limit')
local nav=Player.new(mid,{x=0,y=0,speed=72,radius=1})
assert(nav:navigate_to(48,0,8,250))
for _=1,280 do nav:update(1/60,0,0) end
assert(math.abs(nav.x-48)<2 and math.abs(nav.y)<2,
  'navigation must follow a detour to its destination')
assert(nav.path==nil)
assert(nav:navigate_to(48,0,8,250))
nav:update(1/60,-1,0)
assert(nav.path==nil,'direct manual input overrides route')
-- Idle optimization must not cache across physics steps or skip collision checks.
local surface_calls,obstacle_calls=0,0
local wet=false
local tracked={
  obstacles=function()
    obstacle_calls=obstacle_calls+1
    return {}
  end,
  surface_at=function()
    surface_calls=surface_calls+1
    return {speed_multiplier=wet and .55 or 1,immersion=wet and .5 or 0}
  end
}
local idle=Player.new(tracked,{x=40,y=40,radius=2,speed=60})
assert(surface_calls==1 and obstacle_calls==1,'spawn validates surface and collision')
surface_calls,obstacle_calls=0,0
for _=1,180 do assert(idle:update(1/60,0,0)==1) end
assert(surface_calls==180,'stationary steps must sample surface exactly once')
assert(obstacle_calls==180,'stationary steps must still validate collision')
assert(idle.x==40 and idle.y==40 and idle.state=='idle'
  and idle.frame==180,'idle fixed-step behavior changed')
wet=true
idle:update(1/60,0,0)
assert(surface_calls==181 and obstacle_calls==181
  and idle.surface_multiplier==.55 and idle.immersion==.5,
  'terrain changes while idle must be visible on the next step')
idle:update(1/60,1,0)
near(idle.x,40.55)
assert(surface_calls==183 and obstacle_calls==182,
  'moving steps must resample their destination surface')
assert(idle.state=='walk' and idle.surface_multiplier==.55)
-- A new solid occupying the player's idle location must still raise an error.
local new_solid=false
local changing={
  obstacles=function()
    return new_solid and {{x=18,y=18,w=4,h=4}} or {}
  end,
  surface_at=function() return {speed_multiplier=1,immersion=0} end
}
local stationary=Player.new(changing,{x=20,y=20,radius=2})
new_solid=true
assert(not pcall(function() stationary:update(1/60,0,0) end),
  'idle collision guard must reject newly introduced solids')
print('PLAYER_IDLE_QUERY_PARITY_OK surface=180 obstacle=180 across 180 steps')
print('player stage3 fixed-step, CCD, slide, direction, joystick, A*, depth tests OK')
