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
assert(surface_calls==183 and obstacle_calls==183,
  'moving step must resample destination and recheck swept collision')
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

-- Exact reference A* oracle from the pre-heap algorithm. This checks that
-- faster open ordering and single-search free-cache preserve actual waypoints,
-- corner cutting, failure reasons and max-node budget (not just endpoints).
local function legacy_find(query,sx,sy,gx,gy,r,cell,max_nodes)
  cell=cell or 16;max_nodes=max_nodes or 2048
  local ax,ay=math.floor(sx/cell+.5),math.floor(sy/cell+.5)
  local bx,by=math.floor(gx/cell+.5),math.floor(gy/cell+.5)
  local function key(x,y) return x..','..y end
  local function free(x,y) return C.can_stand(query,x*cell,y*cell,r) end
  local function edge(x0,y0,x1,y1)
    local sx0,sy0=x0*cell,y0*cell
    local ex,ey=x1*cell,y1*cell
    local nx,ny,hit=C.move(query,sx0,sy0,ex-sx0,ey-sy0,r)
    return not hit and math.abs(nx-ex)<1e-5 and math.abs(ny-ey)<1e-5
  end
  local function h(x,y)
    local a,b=math.abs(x-bx),math.abs(y-by)
    return math.max(a,b)+(math.sqrt(2)-1)*math.min(a,b)
  end
  if not C.can_stand(query,sx,sy,r) then return nil,'start_blocked' end
  if not free(ax,ay) then return nil,'start_cell_blocked' end
  if ax~=bx or ay~=by then
    local fx,fy,hit=C.move(query,sx,sy,ax*cell-sx,ay*cell-sy,r)
    if hit or math.abs(fx-ax*cell)>1e-5 or math.abs(fy-ay*cell)>1e-5 then
      return nil,'start_connector_blocked'
    end
  end
  if not free(bx,by) then return nil,'goal_blocked' end
  local dirs={{0,-1},{-1,0},{1,0},{0,1},{-1,-1},{1,-1},{-1,1},{1,1}}
  local start=key(ax,ay)
  local nodes={[start]={x=ax,y=ay,g=0,f=h(ax,ay)}}
  local open={[start]=true};local closed={};local visited=0
  while true do
    local best,cur
    for k in pairs(open) do
      local n=nodes[k]
      if not cur or n.f<cur.f-1e-9 or
        (math.abs(n.f-cur.f)<=1e-9 and (n.g<cur.g-1e-9 or
        (math.abs(n.g-cur.g)<=1e-9 and k<best))) then
        best,cur=k,n
      end
    end
    if not best then return nil,'unreachable' end
    visited=visited+1
    if visited>max_nodes then return nil,'search_limit' end
    if cur.x==bx and cur.y==by then
      local path={}
      while best~=start do
        local n=nodes[best]
        table.insert(path,1,{x=n.x*cell,y=n.y*cell})
        best=n.parent
      end
      return path,nil
    end
    open[best]=nil;closed[best]=true
    for _,d in ipairs(dirs) do
      local x,y=cur.x+d[1],cur.y+d[2]
      local k=key(x,y)
      if not closed[k] and free(x,y) and
        ((d[1]==0 or d[2]==0) or
          (free(cur.x+d[1],cur.y) and free(cur.x,cur.y+d[2])))
        and edge(cur.x,cur.y,x,y) then
        local g=cur.g+((d[1]~=0 and d[2]~=0) and math.sqrt(2) or 1)
        if not nodes[k] or g<nodes[k].g-1e-9 then
          nodes[k]={x=x,y=y,g=g,f=g+h(x,y),parent=best}
          open[k]=true
        end
      end
    end
  end
end

local obstacle_fixtures={
  {},
  {{x=64,y=-24,w=16,h=112}},
  {{x=24,y=8,w=24,h=80},{x=72,y=-64,w=24,h=80}},
  {{x=-4,y=-4,w=8,h=8}},
  {{x=124,y=-4,w=8,h=8}},
  {{x=16,y=-8,w=16,h=16}}
}
local cases={
 {0,0,256,256,1,8,900,1},
 {0,0,128,0,1,8,600,2},
 {0,0,128,64,1,8,600,3},
 {0,0,64,0,1,8,250,4},
 {0,0,128,0,1,8,250,5},
 {0,0,48,0,1,8,2,6},
 {0,0,48,0,1,8,250,6},
 {4,4,80,40,1,8,600,1}
}
local total_old,total_new=0,0
local unpack_args=table.unpack or unpack
for i,case in ipairs(cases) do
  local raw=fixture(obstacle_fixtures[case[8]])
  local tracked={calls=0}
  function tracked:obstacles(...)
    self.calls=self.calls+1
    return raw:obstacles(...)
  end
  local args={case[1],case[2],case[3],case[4],case[5],case[6],case[7]}
  local original,reason1=legacy_find(tracked,unpack_args(args))
  local calls_old=tracked.calls
  tracked.calls=0
  local optimized,reason2=Path.find(tracked,unpack_args(args))
  local calls_new=tracked.calls
  assert(reason1==reason2,"A* failure reason differs at case "..i)
  assert((original==nil)==(optimized==nil),"A* path existence differs at case "..i)
  if original then
    assert(#original==#optimized,"A* waypoints differ at case "..i)
    for n=1,#original do
      assert(original[n].x==optimized[n].x and
             original[n].y==optimized[n].y,
             "A* deterministic route differs at case "..i.." node "..n)
    end
  end
  total_old=total_old+calls_old
  total_new=total_new+calls_new
end
assert(total_new<total_old,"pathfinder should reduce repeated collision queries")
print(string.format("PATHFINDER_ASTAR_PARITY_OK cases=%d obstacle_queries_old=%d new=%d",
  #cases,total_old,total_new))


-- R2-only cooperative navigation; Stage5/6 keeps synchronous API.
local slow=fixture({{x=16,y=-8,w=16,h=16}})
local reference,reference_reason=Path.find(slow,0,0,48,0,1,8,250)
local pending=Path.begin(slow,0,0,48,0,1,8,250)
local updates,finished,async_path,async_reason=0,false
while not finished and updates<10000 do
  updates=updates+1
  finished,async_path,async_reason=pending:step(100,1)
end
assert(finished and updates>1 and async_reason==reference_reason)
assert(#async_path==#reference,"cooperative A* route length differs")
for i=1,#reference do
  assert(async_path[i].x==reference[i].x and
    async_path[i].y==reference[i].y,"cooperative A* waypoint differs")
end
local co=Player.new(slow,{x=0,y=0,speed=72,radius=1})
assert(co:navigate_candidates_async({{x=24,y=0},{x=48,y=0}},8,250))
assert(co._nav_pending and not co.path,"touch must not run search synchronously")
local done,loops=nil,0
for _=1,10000 do
  co:update(1/60,0,0)
  loops=loops+1
  done=co:take_navigation_result()
  if done then break end
end
assert(done and done.ok and co.path,"blocked first approach must fall through")
assert(loops>1 and not co._nav_pending,"cooperative attempts need multiple updates")
for _=1,280 do co:update(1/60,0,0) end
assert(math.abs(co.x-48)<2 and math.abs(co.y)<2,"cooperative route not traversed")
local override=Player.new(empty,{x=0,y=0,radius=1})
override:navigate_candidates_async({{x=2048,y=2048}},8,2048)
override:update(1/60,1,0)
assert(not override._nav_pending and not override.path and
  not override:take_navigation_result(),"manual joystick must cancel pending route")
local repeated=Player.new(empty,{x=0,y=0,radius=1})
repeated:navigate_candidates_async({{x=2048,y=2048}},8,2048)
repeated:update(1/60,0,0)
repeated:navigate_candidates_async({{x=16,y=0}},8,200)
local value
for _=1,1000 do
  repeated:update(1/60,0,0)
  value=repeated:take_navigation_result()
  if value then break end
end
assert(value and value.ok and repeated.path and not repeated._nav_pending,
  "new tap should replace pending route without stale completion")
print("R2_COOPERATIVE_ASTAR_OK compare=exact attempts=sequential manual_cancel=pass retap=pass")

-- R2 tap responsiveness: direct open terrain should be ready in just a few
-- updates, using the same swept collision checks as player movement.
local straight={calls=0}
function straight:obstacles(...) self.calls=self.calls+1;return {} end
local baseline_direct=Path.find(straight,0,0,320,0,1,16,1024)
local baseline_calls=straight.calls
straight.calls=0
local quick=Path.begin(straight,0,0,320,0,1,16,1024)
local quick_updates,quick_done,quick_result=0,false
while not quick_done and quick_updates<80 do
  quick_updates=quick_updates+1
  quick_done,quick_result=quick:step(100,8)
end
assert(quick_done and quick_result and #quick_result==1 and
  quick_result[1].x==320 and quick_result[1].y==0,
  'near clear tap did not take safe direct route')
assert(quick_updates<=5 and straight.calls<baseline_calls,
  'near clear route must complete rapidly with fewer collision queries')
local direct_steps=quick_updates
-- A wall must prevent a direct shortcut; original A* detour remains exact.
local around=fixture({{x=48,y=-8,w=16,h=16}})
local original,reason=Path.find(around,0,0,96,0,1,16,450)
local fallback=Path.begin(around,0,0,96,0,1,16,450)
local got,route,why,updates=false,nil,nil,0
repeat
  updates=updates+1
  got,route,why=fallback:step(100,8)
until got or updates>500
assert(got and why==reason and (route==nil)==(original==nil),
  'blocked shortcut failed to fall back to original A*')
if original then
  assert(#original==#route)
  for i=1,#original do
    assert(original[i].x==route[i].x and original[i].y==route[i].y,
      'A* fallback route mismatch')
  end
end
local same=Path.begin(straight,2,0,3,0,1,16,50)
local ok_same,unchanged=false,nil
repeat ok_same,unchanged=same:step(100,8) until ok_same
assert(unchanged and #unchanged==0,
  'same-cell tap must preserve synchronous path semantics')
print(string.format('R2_NEAR_TAP_DIRECT_OK frames=%d queries=%d baseline_queries=%d blocked_fallback=pass',
  direct_steps,straight.calls,baseline_calls))
