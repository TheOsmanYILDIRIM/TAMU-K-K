-- Camera-centred, bounded, incremental chunk residency.
-- Pure Lua: production renderer owns GPU meshes, logic never calls LOVE.
local Chunks = require("world.chunks")
local Stream = {}
Stream.__index = Stream

local function less(a,b)
  if a.distance ~= b.distance then return a.distance < b.distance end
  if a.cy ~= b.cy then return a.cy < b.cy end
  return a.cx < b.cx
end

function Stream.new(query, opts)
  opts = opts or {}
  local chunker = Chunks.new(query, opts)
  local max_loaded = opts.max_loaded or 144
  local build_budget = opts.build_budget or 4
  assert(max_loaded > 0 and max_loaded == math.floor(max_loaded)
     and build_budget > 0 and build_budget == math.floor(build_budget),
     "invalid stream budgets")
  return setmetatable({
    query=query,chunker=chunker,
    max_loaded=max_loaded, build_budget=build_budget,
    resident={}, ordered={}, wanted_count=0
  }, Stream)
end

local function view_range(camera,width,height,size)
  assert(type(width)=="number" and width > 0 and type(height)=="number" and height > 0,
         "invalid viewport")
  local min_x,min_y,max_x,max_y
  for _,p in ipairs({{0,0},{width,0},{width,height},{0,height}}) do
    local x,y=camera:unproject(p[1],p[2],width,height)
    assert(x == x and y == y and math.abs(x) < math.huge
       and math.abs(y) < math.huge, "invalid camera projection")
    min_x=math.min(min_x or x,x); min_y=math.min(min_y or y,y)
    max_x=math.max(max_x or x,x); max_y=math.max(max_y or y,y)
  end
  return math.floor(min_x/size)-1,math.floor(min_y/size)-1,
         math.floor(max_x/size)+1,math.floor(max_y/size)+1
end

function Stream:needed(camera,width,height)
  assert(camera and type(camera.unproject)=="function"
     and type(camera.x)=="number" and type(camera.y)=="number",
     "camera required")
  local size=self.chunker.size
  local min_x,min_y,max_x,max_y=view_range(camera,width,height,size)
  local candidates={}
  for cy=min_y,max_y do for cx=min_x,max_x do
    local midx,midy=(cx+0.5)*size,(cy+0.5)*size
    candidates[#candidates+1]={
      key=Chunks.key(cx,cy),cx=cx,cy=cy,
      distance=(midx-camera.x)^2+(midy-camera.y)^2
    }
  end end
  table.sort(candidates,less)
  while #candidates > self.max_loaded do
    candidates[#candidates]=nil
  end
  return candidates
end

function Stream:update(camera,width,height,budget)
  budget=budget or self.build_budget
  assert(type(budget)=="number" and budget>=0 and budget==math.floor(budget),
         "invalid generation budget")
  local candidates=self:needed(camera,width,height)
  local want={}
  for _,c in ipairs(candidates) do want[c.key]=true end
  for key,chunk in pairs(self.resident) do
    if not want[key] then
      -- Mesh resources are owned by cached chunks and must be released on eviction.
      if chunk._meshes then
        for _,mesh in pairs(chunk._meshes) do
          if mesh and mesh.release then mesh:release() end
        end
      end
      self.resident[key]=nil
    end
  end
  local created=0
  for _,c in ipairs(candidates) do
    if not self.resident[c.key] and created<budget then
      self.resident[c.key]=self.chunker:build(c.cx,c.cy)
      created=created+1
    end
  end
  local ordered={}
  for _,c in ipairs(candidates) do
    local chunk=self.resident[c.key]
    if chunk then ordered[#ordered+1]=chunk end
  end
  self.ordered,self.wanted_count=ordered,#candidates
  return {created=created, loaded=#ordered, needed=#candidates,
          pending=#candidates-#ordered}
end

function Stream:visible()
  return self.ordered
end

function Stream:get_loaded(cx,cy)
  return self.resident[Chunks.key(cx,cy)]
end

return Stream
