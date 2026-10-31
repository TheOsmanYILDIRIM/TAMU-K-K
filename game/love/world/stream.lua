-- Camera-centred, bounded, incremental chunk residency.
-- Pure Lua: production renderer owns GPU meshes, logic never calls LOVE.
local Chunks = require("world.chunks")
local Iso = require("world.iso")
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
  local generation_ms = opts.generation_ms or 3
  assert(type(generation_ms)=="number" and generation_ms>0
    and generation_ms<math.huge, "invalid time budget")
  assert(max_loaded > 0 and max_loaded == math.floor(max_loaded)
     and build_budget > 0 and build_budget == math.floor(build_budget),
     "invalid stream budgets")
  return setmetatable({
    query=query,chunker=chunker,
    max_loaded=max_loaded,build_budget=build_budget,
    render_only_25d=opts.render_only_25d==true,
    generation_ms=generation_ms,jobs={},cache=opts.cache,
    prefetch_options=opts.prefetch_options,
    prefetch_done={},prefetch_job=nil,previous_camera=nil,
    resident={}, ordered={}, wanted_count=0,
    -- Bound GPU residency: never release finished nearby authored meshes
    -- immediately on a small camera excursion. Non-25D stays unchanged.
    warm={},warm_count=0,warm_limit=opts.warm_limit or
      (opts.render_only_25d and 24 or 0),warm_tick=0,
    warm_hits=0,warm_evictions=0
  }, Stream)
end

local function view_range(camera,width,height,size,margin)
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
  margin=margin or 1
  return math.floor(min_x/size)-margin,math.floor(min_y/size)-margin,
         math.floor(max_x/size)+margin,math.floor(max_y/size)+margin
end

-- Screen-space overlap is a diamond bounding box, not centre distance.
-- The opt-in path protects foreground silhouettes without changing physics.
local function overlaps_view(cx,cy,size,camera,width,height,padding)
  local x,y=Iso.project(cx*size-camera.x,cy*size-camera.y)
  local z=camera.zoom
  local edge=size*math.sqrt(.5)*z
  local sx,sy=width*.5+x*z,height*.5+y*z
  return sx+edge>=-padding and sx-edge<=width+padding
     and sy+edge>=-padding and sy<=height+padding
end

function Stream:needed(camera,width,height)
  assert(camera and type(camera.unproject)=="function"
     and type(camera.x)=="number" and type(camera.y)=="number",
     "camera required")
  local size=self.chunker.size
  local min_x,min_y,max_x,max_y=view_range(camera,width,height,size,
    self.render_only_25d and 3 or 1)
  local candidates={}
  for cy=min_y,max_y do for cx=min_x,max_x do
    local midx,midy=(cx+0.5)*size,(cy+0.5)*size
    candidates[#candidates+1]={
      key=Chunks.key(cx,cy),cx=cx,cy=cy,
      distance=(midx-camera.x)^2+(midy-camera.y)^2
    }
  end end
  table.sort(candidates,less)
  if self.render_only_25d then
    -- Strict draw priority: include EVERY screen-intersecting chunk before
    -- allocating the bounded off-screen prefetch halo. The old centre-distance
    -- truncation could drop visible corners at portrait/zoom-out viewports.
    local visible,halo={},{}
    local visible_pad=12
    local prefetch_pad=math.max(72*camera.zoom+16,size*camera.zoom*1.6)
    for _,c in ipairs(candidates) do
      if overlaps_view(c.cx,c.cy,size,camera,width,height,visible_pad) then
        visible[#visible+1]=c
      elseif overlaps_view(c.cx,c.cy,size,camera,width,height,prefetch_pad) then
        halo[#halo+1]=c
      end
    end
    -- Choose the bounded halo towards camera motion, not by distance
    -- behind the player. The next viewport edge can reveal six diagonal
    -- terrain chunks in one frame; preload those before they become visible.
    local prev=self._25d_prefetch_camera
    local dx=prev and camera.x-prev.x or 0
    local dy=prev and camera.y-prev.y or 0
    self._25d_prefetch_camera={x=camera.x,y=camera.y}
    local distance=math.sqrt(dx*dx+dy*dy)
    if distance>0.05 then
      self._25d_prefetch_dir={x=dx/distance,y=dy/distance}
    end
    local direction=self._25d_prefetch_dir
    if direction then
      local lookx=camera.x+direction.x*size*2
      local looky=camera.y+direction.y*size*2
      local function lookscore(c)
        local x=(c.cx+.5)*size-lookx
        local y=(c.cy+.5)*size-looky
        return x*x+y*y
      end
      table.sort(halo,function(a,b)
        local va,vb=lookscore(a),lookscore(b)
        if va~=vb then return va<vb end
        return less(a,b)
      end)
    end
    -- Keep all screen-visible cells, even when max_loaded is exceeded.
    -- Never append halo to the screen-visible array: Lua tables alias.
    -- Coverage diagnostics and the render readiness gate must count only
    -- chunks intersecting the viewport, not prefetched off-screen cells.
    local required={}
    for i,c in ipairs(visible) do required[i]=c end
    -- Keep a bounded forward staging buffer even at tall portrait zooms.
    -- The old max_loaded=80 left just three halo slots when 77 chunks
    -- intersected the viewport, so 6-7 new diagonal chunks arrived cold.
    local residency_cap=math.max(self.max_loaded,#visible+24)
    for _,c in ipairs(halo) do
      if #required>=residency_cap then break end
      required[#required+1]=c
    end
    local visible_keys={}
    for _,c in ipairs(visible) do visible_keys[c.key]=true end
    self.visible_required_keys=visible_keys
    self.visible_required_count=#visible
    self.coverage_over_budget=#visible>self.max_loaded and
      (#visible-self.max_loaded) or 0
    return required
  end
  if self.viewport_cover then
    -- Render-only R2 opt-in: no foreground-screen chunk may be sacrificed
    -- to the historical 48-nearest-centres cap. Noncritical halo is capped.
    -- This may require >48 chunks at extreme zoom-out: monitor memory.
    local required,halo={},{}
    local pad=120*camera.zoom+16
    for _,c in ipairs(candidates) do
      if overlaps_view(c.cx,c.cy,size,camera,width,height,pad) then
        required[#required+1]=c
      else halo[#halo+1]=c end
    end
    for _,c in ipairs(halo) do
      if #required>=self.max_loaded then break end
      required[#required+1]=c
    end
    return required
  end
  while #candidates > self.max_loaded do
    candidates[#candidates]=nil
  end
  return candidates
end

local function release_chunk(chunk)
  if chunk._meshes then
    for _,mesh in pairs(chunk._meshes) do
      if mesh and mesh.release then mesh:release() end
    end
  end
  if chunk._25d_staging_meshes then
    for _,mesh in pairs(chunk._25d_staging_meshes) do
      if mesh and mesh.release then mesh:release() end
    end
    chunk._25d_staging_meshes=nil
  end
  if chunk._terrain_stage then
    for _,mesh in pairs(chunk._terrain_stage) do
      if mesh and mesh.release then mesh:release() end
    end
    chunk._terrain_stage=nil
  end
  chunk._terrain_job=nil
  chunk._25d_prepare_job=nil
end

function Stream:update(camera,width,height,budget)
  if self.cache and self.cache.poll then self.cache:poll() end
  budget=budget or self.build_budget
  assert(type(budget)=="number" and budget>=0 and budget==math.floor(budget),
         "invalid generation budget")
  local candidates=self:needed(camera,width,height)
  local want={}
  for _,c in ipairs(candidates) do want[c.key]=true end
  for key,chunk in pairs(self.resident) do
    if not want[key] then
      -- Keep only FINISHED GPU chunks; never cache a suspended mesh job.
      if self.render_only_25d and self.warm_limit>0 and chunk._25d_meshes
         and not chunk._25d_prepare_job then
        self.warm_tick=self.warm_tick+1
        self.warm[key]={chunk=chunk,tick=self.warm_tick}
        self.warm_count=self.warm_count+1
      else
        release_chunk(chunk)
      end
      self.resident[key]=nil
    end
  end
  -- If the camera returns, adopt the exact previous GPU mesh; no decode,
  -- no GPU upload and no authored hydrology generation.
  for _,c in ipairs(candidates) do
    if not self.resident[c.key] then
      local cached=self.warm[c.key]
      if cached then
        self.resident[c.key]=cached.chunk
        self.warm[c.key]=nil
        self.warm_count=self.warm_count-1
        self.warm_hits=self.warm_hits+1
      end
    end
  end
  -- Deterministic LRU bounded by warm_limit, in addition to visible residents.
  while self.warm_count>self.warm_limit do
    local oldest_key,oldest_tick
    for key,item in pairs(self.warm) do
      if not oldest_tick or item.tick<oldest_tick then
        oldest_key,oldest_tick=key,item.tick
      end
    end
    if not oldest_key then break end
    release_chunk(self.warm[oldest_key].chunk)
    self.warm[oldest_key]=nil
    self.warm_count=self.warm_count-1
    self.warm_evictions=self.warm_evictions+1
  end
  for key in pairs(self.jobs) do
    if not want[key] then self.jobs[key]=nil end
  end
  local clock=love and love.timer and love.timer.getTime
  if type(clock)~="function" then clock=nil end
  local deadline=clock and clock()+self.generation_ms/1000
  local created=0
  for _,c in ipairs(candidates) do
    if not self.resident[c.key] and created<budget then
      if clock then
        local job=self.jobs[c.key]
        if not job then
          job=coroutine.create(function()
            local checkpoint=function() coroutine.yield() end
            if self.cache then
              local vertices=self.cache:read(c.cx,c.cy,checkpoint)
              if vertices then
                return {key=c.key,cx=c.cx,cy=c.cy,x=c.cx*self.chunker.size,
                  y=c.cy*self.chunker.size,size=self.chunker.size,layers={},
                  _cache_vertices=vertices}
              end
            end
            if self.render_only_25d then
              -- The 25D renderer constructs its own authored terrain, water,
              -- path and bank. Avoid the three discarded legacy Marching passes.
              return {key=c.key,cx=c.cx,cy=c.cy,
                x=c.cx*self.chunker.size,y=c.cy*self.chunker.size,
                size=self.chunker.size,layers={},_25d_lite=true}
            end
            return self.chunker:build(c.cx,c.cy,checkpoint)
          end)
          self.jobs[c.key]=job
        end
        repeat
          local ok,value=coroutine.resume(job)
          assert(ok,value)
          if coroutine.status(job)=="dead" then
            self.resident[c.key]=value
            self.jobs[c.key]=nil
            created=created+1
            break
          end
        until clock()>=deadline
        if clock()>=deadline then break end
      else
        local v=self.cache and self.cache:read(c.cx,c.cy)
        if v then
          self.resident[c.key]={key=c.key,cx=c.cx,cy=c.cy,
            x=c.cx*self.chunker.size,y=c.cy*self.chunker.size,
            size=self.chunker.size,layers={},_cache_vertices=v}
        elseif self.render_only_25d then
          self.resident[c.key]={key=c.key,cx=c.cx,cy=c.cy,
            x=c.cx*self.chunker.size,y=c.cy*self.chunker.size,
            size=self.chunker.size,layers={},_25d_lite=true}
        else
          self.resident[c.key]=self.chunker:build(c.cx,c.cy)
        end
        created=created+1
      end
    end
  end
  local ordered={}
  for _,c in ipairs(candidates) do
    local chunk=self.resident[c.key]
    if chunk then ordered[#ordered+1]=chunk end
  end
  self.ordered,self.wanted_count=ordered,#candidates
  -- Saving uses leftover frame budget and only fully completed geometry.
  -- Save files are disposable and entirely separate from Stage6 persistence.
  -- Flush any fully prepared chunk independently of unrelated pending chunks.
  -- The previous all-visible gate discarded completed CPU vertices on fast
  -- camera travel before they could be persisted, causing repeat cache misses.
  -- Work remains cooperative and bounded to 2ms of resume time per update.
  if self.cache and clock and #ordered>0 then
    local save_deadline=clock()+.002
    for _,chunk in ipairs(ordered) do
      if chunk._cache_payload then
        if not chunk._cache_job then
          chunk._cache_job=coroutine.create(function()
            return self.cache:write(chunk.cx,chunk.cy,chunk._cache_payload,
              function() coroutine.yield() end)
          end)
        end
        repeat
          local ok,why=coroutine.resume(chunk._cache_job)
          assert(ok,why)
          if coroutine.status(chunk._cache_job)=="dead" then
            if why==true then chunk._cache_payload=nil end
            chunk._cache_job=nil
            break
          end
        until clock()>=save_deadline
        if clock()>=save_deadline then break end
      end
    end
  end
  -- Low-priority prefetch: builds complete CPU geometry for nearby unseen
  -- chunks, writes immutable cache files, and NEVER creates GPU resources.
  -- Do not compete with visibility or outstanding mesh creation.
  if self.cache and self.prefetch_options and clock
    and #ordered==#candidates then
    local ready=true
    for _,chunk in ipairs(ordered) do
      if not chunk._terrain_meshes or chunk._cache_payload then
        ready=false;break
      end
    end
    if ready then
      local job=self.prefetch_job
      if job and want[job.key] then self.prefetch_job=nil;job=nil end
      if not job then
        local minx,miny,maxx,maxy=view_range(camera,width,height,self.chunker.size)
        local lookx,looky=0,0
        if self.previous_camera then
          lookx=camera.x-self.previous_camera.x
          looky=camera.y-self.previous_camera.y
        end
        local best,best_score
        for cy=miny-1,maxy+1 do for cx=minx-1,maxx+1 do
          local key=Chunks.key(cx,cy)
          if not want[key] and not self.prefetch_done[key]
            and not self.cache:has(cx,cy) then
            local dx=(cx+.5)*self.chunker.size-camera.x
            local dy=(cy+.5)*self.chunker.size-camera.y
            local score=dx*dx+dy*dy-2*self.chunker.size*
              (dx*math.max(-1,math.min(1,lookx/64))+
               dy*math.max(-1,math.min(1,looky/64)))
            if not best or score<best_score then
              best={key=key,cx=cx,cy=cy};best_score=score
            end
          end
        end end
        if best then
          local item=best
          job={key=item.key,thread=coroutine.create(function()
            local checkpoint=function() coroutine.yield() end
            local chunk=self.chunker:build(item.cx,item.cy,checkpoint)
            local Terrain=require("world.terrain_renderer")
            Terrain.prepare_cpu(chunk,self.query,self.prefetch_options,checkpoint)
            return self.cache:write(item.cx,item.cy,chunk._cache_payload,checkpoint)
          end)}
          self.prefetch_job=job
        end
      end
      if job then
        local until_time=clock()+.001
        repeat
          local ok,result=coroutine.resume(job.thread)
          assert(ok,result)
          if coroutine.status(job.thread)=="dead" then
            self.prefetch_done[job.key]=true
            if result then
              self.cache.metrics.prefetch_writes=(self.cache.metrics.prefetch_writes or 0)+1
            end
            self.prefetch_job=nil
            break
          end
        until clock()>=until_time
      end
    end
    self.previous_camera={x=camera.x,y=camera.y}
  end
  return {created=created, loaded=#ordered, needed=#candidates,
          pending=#candidates-#ordered}
end

function Stream:visible()
  return self.ordered
end

-- Render culling does not evict the prefetch halo. Actual GPU vertex bounds
-- include authored height, path, banks and water. The source R2 physics is
-- unchanged, and no per-frame mesh rebuilding is needed.
function Stream:render_visible(camera,width,height,padding)
  if not self.render_only_25d then return self.ordered end
  local result={}
  local z=camera.zoom
  local ox,oy=Iso.project(camera.x,camera.y)
  padding=padding or 12
  for _,c in ipairs(self.ordered) do
    local bounds=c._25d_bounds
    local hit
    if bounds then
      local minx=width*.5+(bounds[1]-ox)*z
      local miny=height*.5+(bounds[2]-oy)*z
      local maxx=width*.5+(bounds[3]-ox)*z
      local maxy=height*.5+(bounds[4]-oy)*z
      hit=maxx>=-padding and minx<=width+padding and
          maxy>=-padding and miny<=height+padding
    else
      hit=overlaps_view(c.cx,c.cy,c.size,camera,width,height,padding+100*z)
    end
    if hit then result[#result+1]=c end
  end
  return result
end

function Stream:get_loaded(cx,cy)
  return self.resident[Chunks.key(cx,cy)]
end

return Stream
