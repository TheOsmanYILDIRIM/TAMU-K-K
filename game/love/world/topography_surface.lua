-- Optional world-space 2.5D topography queries. No changes to Generator v1,
-- WorldQuery, the active player collider, rendering or persistence.
-- All values are world units. A grade is vertical rise / horizontal distance.
local M = {}
M.__index = M

local function finite(v)
  return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end
local function check(v, message)
  assert(finite(v), message or "expected finite number")
  return v
end
local function positive(v, label)
  assert(finite(v) and v > 0, "invalid " .. label)
  return v
end
local function bounds(x1,y1,x2,y2)
  check(x1);check(y1);check(x2);check(y2)
  assert(x1 <= x2 and y1 <= y2, "invalid world bounds")
end
local function inside(zone,x,y)
  return x >= zone.min_x and x < zone.max_x
     and y >= zone.min_y and y < zone.max_y
end
local function overlap(a,b)
  return a.min_x < b.max_x and b.min_x < a.max_x
     and a.min_y < b.max_y and b.min_y < a.max_y
end

function M.new(opts)
  opts = opts or {}
  assert(type(opts) == "table", "topography options required")
  local sample_height = opts.height_at
  if sample_height == nil then
    local world = opts.world
    assert(type(world) == "table" and type(world.get_height) == "function",
           "height_at(x,y) or WorldQuery:get_height required")
    sample_height = function(x,y) return world:get_height(x,y) end
  end
  assert(type(sample_height) == "function", "height_at must be a function")
  local gentle = opts.gentle_grade or 0.10
  local max_walk = opts.max_walk_grade or 0.45
  local max_ramp = opts.max_ramp_grade or 1.50
  local max_step = opts.max_step_rise or 1.5
  local build_grade = opts.max_build_grade or 0.12
  local build_delta = opts.max_build_delta or 0.8
  assert(finite(gentle) and gentle >= 0 and gentle < max_walk
    and finite(max_walk) and max_walk < max_ramp
    and finite(max_ramp) and max_ramp > 0, "invalid grade thresholds")
  positive(max_step,"step rise")
  positive(build_grade,"build grade")
  positive(build_delta,"build height tolerance")
  local stride = positive(opts.sample_stride or 2,"sample stride")
  local gradient_step = positive(opts.gradient_step or 1,"gradient step")
  local zones,ids = {},{}
  for _,z in ipairs(opts.zones or {}) do
    assert(type(z) == "table" and type(z.id) == "string" and z.id ~= ""
       and not ids[z.id] and (z.kind == "ramp" or z.kind == "steps"),
       "invalid or duplicate topography zone")
    bounds(z.min_x,z.min_y,z.max_x,z.max_y)
    assert(z.min_x < z.max_x and z.min_y < z.max_y,"empty zone")
    ids[z.id] = true
    zones[#zones+1] = {id=z.id,kind=z.kind,min_x=z.min_x,
      min_y=z.min_y,max_x=z.max_x,max_y=z.max_y}
  end
  table.sort(zones,function(a,b) return a.id < b.id end)
  for i=1,#zones do for j=i+1,#zones do
    assert(not overlap(zones[i],zones[j]),"overlapping topography zones")
  end end
  return setmetatable({height_at=sample_height,zones=zones,gentle_grade=gentle,
    max_walk_grade=max_walk,max_ramp_grade=max_ramp,max_step_rise=max_step,
    max_build_grade=build_grade,max_build_delta=build_delta,
    sample_stride=stride,gradient_step=gradient_step,
    -- R2 authored/Generator v1 height is immutable. Dynamic/production
    -- topography MUST leave this disabled, keeping every collider live.
    _collider_cache=opts.static_collider_cache and {
      values={},keys={},count=0,cursor=1,limit=8192,hits=0,misses=0
    } or nil},M)
end

function M:height(x,y)
  check(x,"invalid world x");check(y,"invalid world y")
  return check(self.height_at(x,y),"invalid height sample")
end
function M:zone(x,y)
  check(x);check(y)
  for _,z in ipairs(self.zones) do
    if inside(z,x,y) then return z end
  end
  return nil
end
function M:sample(x,y)
  local h = self:height(x,y)
  local d = self.gradient_step
  local gx = (self:height(x+d,y)-self:height(x-d,y))/(2*d)
  local gy = (self:height(x,y+d)-self:height(x,y-d))/(2*d)
  local grade = math.sqrt(gx*gx+gy*gy)
  local class = grade <= self.gentle_grade and "gentle"
    or (grade <= self.max_walk_grade and "moderate" or "cliff")
  local zone = self:zone(x,y)
  return {height=h,gradient_x=gx,gradient_y=gy,grade=grade,
    class=class,zone_id=zone and zone.id or nil}
end

-- Advisory traverse result: NOT installed into player/controller.lua.
-- Samples the entire segment to prevent endpoint-only cliff tunneling.
function M:transition(x1,y1,x2,y2)
  bounds(math.min(x1,x2),math.min(y1,y2),math.max(x1,x2),math.max(y1,y2))
  local dx,dy = x2-x1,y2-y1
  local distance = math.sqrt(dx*dx+dy*dy)
  local n = math.max(1,math.ceil(distance/self.sample_stride))
  assert(n <= 4096,"topography transition budget exceeded")
  local h0 = self:height(x1,y1)
  if distance == 0 then return {walkable=true,reason="stationary",speed_multiplier=1,
    rise=0,max_grade=0} end
  local speed,steepest = 1,0
  for i=1,n do
    local t = i/n
    local x,y = x1+dx*t,y1+dy*t
    local h = self:height(x,y)
    local rise = h-h0
    local grade = math.abs(rise)/(distance/n)
    steepest = math.max(steepest,grade)
    local px,py = x1+dx*(i-1)/n,y1+dy*(i-1)/n
    local a,b = self:zone(px,py),self:zone(x,y)
    local z = a and b and a.id == b.id and a or nil
    local allowed = grade <= self.max_walk_grade
    local factor = 1
    if z and z.kind == "ramp" then
      allowed = grade <= self.max_ramp_grade
      factor = 0.55
    elseif z and z.kind == "steps" then
      allowed = math.abs(rise) <= self.max_step_rise
      factor = 0.65
    elseif grade > self.gentle_grade then
      local fraction = math.min(1,(grade-self.gentle_grade)/
        (self.max_walk_grade-self.gentle_grade))
      factor = rise >= 0 and (1-0.35*fraction) or (1-0.10*fraction)
    end
    if not allowed then return {walkable=false,reason="cliff",speed_multiplier=0,
      blocked_at={x=x,y=y},rise=self:height(x2,y2)-self:height(x1,y1),
      max_grade=steepest} end
    speed = math.min(speed,factor)
    h0 = h
  end
  return {walkable=true,reason="passable",speed_multiplier=speed,
    rise=self:height(x2,y2)-self:height(x1,y1),max_grade=steepest}
end

-- Elevated terrain occludes the interpolated eye-to-target ray.
-- Returns a pure bool and optional first terrain occluder position.
function M:line_of_sight(x1,y1,x2,y2,eye_offset,target_offset)
  check(x1);check(y1);check(x2);check(y2)
  eye_offset = eye_offset == nil and 2 or check(eye_offset)
  target_offset = target_offset == nil and 2 or check(target_offset)
  assert(eye_offset >= 0 and target_offset >= 0,"negative eye clearance")
  local dx,dy=x2-x1,y2-y1
  local distance=math.sqrt(dx*dx+dy*dy)
  local n=math.max(1,math.ceil(distance/self.sample_stride))
  assert(n <= 4096,"line-of-sight query budget exceeded")
  local a,b=self:height(x1,y1)+eye_offset,self:height(x2,y2)+target_offset
  for i=1,n-1 do
    local t=i/n
    local x,y=x1+dx*t,y1+dy*t
    if self:height(x,y) >= a+(b-a)*t then return false,{x=x,y=y} end
  end
  return true,nil
end

-- Flat, stable footprint check; no placement or save side effects.
function M:can_build(x,y,width,height,spacing)
  check(x);check(y)
  positive(width,"build width");positive(height,"build height")
  spacing=positive(spacing or 4,"build grid spacing")
  local nx,ny=math.max(1,math.ceil(width/spacing)),
              math.max(1,math.ceil(height/spacing))
  assert((nx+1)*(ny+1) <= 4096,"build sampling budget exceeded")
  local lowest,highest=math.huge,-math.huge
  for iy=0,ny do for ix=0,nx do
    local px,py=x+width*ix/nx,y+height*iy/ny
    if self:zone(px,py) then return false,"reserved_topography_zone" end
    local s=self:sample(px,py)
    if s.grade > self.max_build_grade then return false,"steep_footprint" end
    lowest=math.min(lowest,s.height);highest=math.max(highest,s.height)
  end end
  if highest-lowest > self.max_build_delta then
    return false,"uneven_footprint"
  end
  return true,"buildable"
end

-- Conservative collision candidate rectangles on a global fixed lattice.
-- Later integration must merge them with existing obstacle/collision queries;
-- they are deliberately NOT installed into WorldQuery or real player physics.
function M:colliders(min_x,min_y,max_x,max_y,cell)
  bounds(min_x,min_y,max_x,max_y)
  cell=positive(cell or 8,"collider cell")
  local ix0,iy0=math.floor(min_x/cell),math.floor(min_y/cell)
  local ix1,iy1=math.ceil(max_x/cell)-1,math.ceil(max_y/cell)-1
  local n=math.max(0,ix1-ix0+1)*math.max(0,iy1-iy0+1)
  assert(n <= 4096,"collider query budget exceeded")
  local result={}
  for iy=iy0,iy1 do for ix=ix0,ix1 do
    local x,y=ix*cell,iy*cell
    local cache=self._collider_cache
    local id=cache and (cell..":"..ix..":"..iy)
    local cliff=cache and cache.values[id]
    if cliff==nil then
      -- Multi-point sampling is conservative for narrow cliff strips.
      -- Cache only the immutable *boolean*, not mutable obstacle rectangles.
      local points={{x,y},{x+cell,y},{x,y+cell},{x+cell,y+cell},{x+cell/2,y+cell/2}}
      cliff=false
      for _,p in ipairs(points) do
        if not self:zone(p[1],p[2]) and
           self:sample(p[1],p[2]).class == "cliff" then cliff=true;break end
      end
      if cache then
        if cache.count < cache.limit then
          cache.count=cache.count+1
          cache.keys[cache.count]=id
        else
          local pos=cache.cursor
          cache.values[cache.keys[pos]]=nil
          cache.keys[pos]=id
          cache.cursor=pos%cache.limit+1
        end
        cache.values[id]=cliff
        cache.misses=cache.misses+1
      end
    else
      cache.hits=cache.hits+1
    end
    if cliff then result[#result+1]={x=x,y=y,w=cell,h=cell} end
  end end
  return result
end
return M
