-- Opt-in, expensive R2 streaming benchmark driver; never production gameplay.
-- Scripted player/camera locomotion is deterministic and deliberately bypasses
-- collision. It stresses the ACTUAL production Stream/Terrain/Object draw path.
-- It does NOT validate physics, Android, display refresh, or GPU execution time.
local M={}
M.__index=M
-- 10x simulated movement per actual rendered frame; never inflate measured FPS.
-- Two identical laps cover dry terrain, river, dense objects and new chunk seams.
local speed_multiplier=10
local route={{64,128},{704,128},{2048,128},{3328,960},
 {3328,2048},{-1536,2048},{-1536,-896},{64,128}}
local function now() return love.timer.getTime() end
local function cell(x) return math.floor(x/256) end
local function finite(x) return x==x and x<math.huge and x>-math.huge end
local function quote(s)
 s=tostring(s or "")
 return '"'..s:gsub('"','""'):gsub("[\r\n]+"," ")..'"'
end
local function percentile(t,p)
 if #t==0 then return 0 end
 local a={} for i,v in ipairs(t) do a[i]=v end
 table.sort(a)
 return a[math.max(1,math.ceil(#a*p))]
end
local function counts(map) local n=0 for _ in pairs(map) do n=n+1 end return n end
local function num(x) return string.format("%.3f",x or 0) end
local function serialize(items)
 local out={}
 for i,line in ipairs(items) do out[i]=table.concat(line,",") end
 return table.concat(out,"\n").."\n"
end
function M.new(mode,stream,cache)
 assert(mode=="baseline" or mode=="cold" or mode=="warm","bad benchmark mode")
 assert(stream and stream.chunker and stream.update,"Stream required")
 assert((mode=="baseline" and cache==nil) or
   (mode~="baseline" and cache~=nil),"cache scenario mismatch")
 local self=setmetatable({mode=mode,stream=stream,cache=cache,lap=1,segment=2,
  distance=0,frame=0,pos={route[1][1],route[1][2]},last=now(),start=now(),
  samples={},events={},spikes={},unique={},completed=false,
  stats={},phase="outbound",frame_mesh=0,frame_vertices=0,frame_gpu_ms=0,
  terrain_ms=0,objects_ms=0,previous_heap=collectgarbage("count"),
  was_resident={},was_ready={},
  total_meshes=0,total_spikes=0,screenshot_count=0},M)
 local oldbuild=stream.chunker.build
 stream.chunker.build=function(chunker,cx,cy,checkpoint)
  local start=now()
  self:event("build_start",cx,cy,0,"async CPU geometry")
  local result=oldbuild(chunker,cx,cy,checkpoint)
  self:event("build_complete",cx,cy,(now()-start)*1000,
   "elapsed wall time including coroutine yields")
  return result
 end
 local terrain=require("world.terrain_renderer")
 local base_draw=terrain.draw
 terrain.draw=function(...)
  local start=now()
  local result=base_draw(...)
  self.terrain_ms=(now()-start)*1000
  return result
 end
 local objects=require("objects.renderer")
 local base_object_draw=objects.draw
 objects.draw=function(...)
  local start=now()
  local result=base_object_draw(...)
  self.objects_ms=(now()-start)*1000
  return result
 end
 local g=love.graphics
 local mesh=g.newMesh
 g.newMesh=function(vertices,...)
  local t=now()
  local obj=mesh(vertices,...)
  local ms=(now()-t)*1000
  self.frame_mesh=self.frame_mesh+1
  self.frame_vertices=self.frame_vertices+#vertices
  self.frame_gpu_ms=self.frame_gpu_ms+ms
  self.total_meshes=self.total_meshes+1
  if ms>=8 then self:event("gpu_mesh_upload",cell(self.pos[1]),
    cell(self.pos[2]),ms,"vertices="..#vertices) end
  return obj
 end
 if cache then
  for _,name in ipairs({"read","write"}) do
   local old=cache[name]
   cache[name]=function(obj,cx,cy,...)
    local t=now()
    local ret,err=old(obj,cx,cy,...)
    self:event("cache_"..name,cx,cy,(now()-t)*1000,
      (name=="read" and (ret and "hit" or "miss") or
       (ret and "committed" or tostring(err))))
    return ret,err
   end
  end
 end
 return self
end
function M:event(kind,cx,cy,value,context)
 local e={self.frame,num(now()-self.start),quote(kind),cx or 0,cy or 0,
  num(value),quote(context)}
 self.events[#self.events+1]=e
end
function M:advance(player,camera)
 assert(not self.completed,"advance after benchmark completion")
 local remaining=24*speed_multiplier -- 10x route progression, real timings untouched
 while remaining>0 do
  local next=route[self.segment]
  local dx,dy=next[1]-self.pos[1],next[2]-self.pos[2]
  local distance=math.sqrt(dx*dx+dy*dy)
  if distance<=remaining then
   self.pos[1],self.pos[2]=next[1],next[2]
   remaining=remaining-distance
   self.segment=self.segment+1
   if self.segment>#route then
    if self.lap==1 then
     self.lap=2;self.segment=2;self.phase="revisit"
     self:event("revisit_start",cell(self.pos[1]),cell(self.pos[2]),0,
       "repeat identical route")
    else self.completed=true;remaining=0 end
   end
  else
   self.pos[1]=self.pos[1]+remaining*dx/distance
   self.pos[2]=self.pos[2]+remaining*dy/distance
   remaining=0
  end
 end
 player.x,player.y=self.pos[1],self.pos[2]
 camera.x,camera.y=self.pos[1],self.pos[2]
end
function M:beforeUpdate(player,camera)
 self.frame=self.frame+1
 self.frame_mesh,self.frame_vertices,self.frame_gpu_ms=0,0,0
 self.terrain_ms,self.objects_ms=0,0
 self.update_start=now()
 self:advance(player,camera)
 assert(self.frame<=600,"benchmark exceeded hard 600-frame cap")
 local key=cell(camera.x)..":"..cell(camera.y)
 if not self.unique[key] then
  self.unique[key]=true
  self:event("new_camera_chunk",cell(camera.x),cell(camera.y),0,self.phase)
 end
end
function M:afterUpdate(stats)
 self.update_ms=(now()-self.update_start)*1000
 self.stats=stats
 local resident={}
 for key,chunk in pairs(self.stream.resident) do
  resident[key]=true
  if not self.was_resident[key] then
   self:event("chunk_resident",chunk.cx,chunk.cy,0,"loaded from build or cache")
  end
 end
 for key in pairs(self.was_resident) do
  if not resident[key] then
   local cx,cy=key:match("^(-?%d+):(-?%d+)$")
   self:event("chunk_evicted",tonumber(cx),tonumber(cy),0,"resident released")
   self.was_ready[key]=nil
  end
 end
 self.was_resident=resident
end
function M:beforeDraw()
 self.draw_start=now()
end
function M:afterDraw(object_count)
 local finish=now()
 local frame_dt=(finish-self.last)*1000
 self.last=finish
 local draw_ms=(finish-self.draw_start)*1000
 local update_ms=self.update_ms or 0
 local jobs=counts(self.stream.jobs)
 local terrain_jobs=0
 for _,ch in ipairs(self.stream:visible()) do
  if ch._terrain_job then terrain_jobs=terrain_jobs+1 end
 end
 local cm=self.cache and self.cache.metrics or {}
 local gpu=love.graphics.getStats and love.graphics.getStats() or {}
 local ram=collectgarbage("count")
 if ram<self.previous_heap-512 then
  self:event("heap_drop",cell(self.pos[1]),cell(self.pos[2]),
    self.previous_heap-ram,"KiB decrease, possible GC")
 end
 self.previous_heap=ram
 for _,chunk in ipairs(self.stream:visible()) do
  if chunk._terrain_meshes and not self.was_ready[chunk.key] then
   self.was_ready[chunk.key]=true
   self:event("mesh_ready",chunk.cx,chunk.cy,self.terrain_ms,"complete mesh set")
  end
 end
 local row={self.frame,quote(self.phase),self.lap,num(finish-self.start),
  num(self.pos[1]),num(self.pos[2]),cell(self.pos[1]),cell(self.pos[2]),
  num(frame_dt),num(1000/math.max(.001,frame_dt)),num(update_ms),num(draw_ms),
  num(draw_ms+update_ms),self.stats.loaded or 0,self.stats.needed or 0,
  self.stats.pending or 0,jobs,terrain_jobs,cm.hits or 0,cm.misses or 0,
  cm.writes or 0,cm.prefetch_writes or 0,cm.invalid or 0,
  self.frame_mesh,self.frame_vertices,num(self.frame_gpu_ms),
  object_count or 0,num(ram),num(gpu.texturememory or 0),
  gpu.drawcalls or 0,num(self.terrain_ms),num(self.objects_ms)}
 self.samples[#self.samples+1]=row
 if frame_dt>=33.333 or update_ms+draw_ms>=33.333 then
  self.total_spikes=self.total_spikes+1
  self:event("frame_stall",cell(self.pos[1]),cell(self.pos[2]),
   frame_dt,string.format(
    "cpuMs=%.2f update=%.2f draw=%.2f terrain=%.2f objects=%.2f meshAllocMs=%.2f mesh=%d vertices=%d pending=%d jobs=%d terrainJobs=%d heapKiB=%.1f hits=%d misses=%d writes=%d",
    update_ms+draw_ms,update_ms,draw_ms,self.terrain_ms,self.objects_ms,
    self.frame_gpu_ms,self.frame_mesh,
    self.frame_vertices,self.stats.pending or 0,jobs,terrain_jobs,ram,
    cm.hits or 0,cm.misses or 0,cm.writes or 0))
  if self.screenshot_count<3 and self.frame>3 then
   self.screenshot_count=self.screenshot_count+1
   love.graphics.captureScreenshot("r2-long-"..self.mode.."-stall-"..
    self.screenshot_count..".png")
  end
 end
 if self.completed then self:finish() end
end
function M:finish()
 local dt,cpu,updates,draws={}, {}, {}, {}
 local minfps=math.huge
 local peak=0
 for _,r in ipairs(self.samples) do
  local v=tonumber(r[9]);dt[#dt+1]=v
  local fps=tonumber(r[10]);minfps=math.min(minfps,fps)
  cpu[#cpu+1]=tonumber(r[13])
  updates[#updates+1]=tonumber(r[11])
  draws[#draws+1]=tonumber(r[12])
  peak=math.max(peak,tonumber(r[28]))
 end
 local prefix="r2-long-"..self.mode
 local csv={{"frame","phase","lap","elapsed_s","world_x","world_y",
 "chunk_x","chunk_y","frame_ms","fps","update_ms","draw_ms","cpu_ms",
 "loaded","needed","pending","build_jobs","terrain_jobs",
 "cache_hits","cache_misses","cache_writes","prefetch_writes","cache_invalid",
 "mesh_alloc_calls","mesh_vertices","mesh_alloc_cpu_call_ms","objects","lua_heap_kib",
 "gpu_texture_bytes","gpu_drawcalls","terrain_ms","objects_ms"}}
 for _,r in ipairs(self.samples) do csv[#csv+1]=r end
 local log={{"frame","elapsed_s","event","chunk_x","chunk_y","elapsed_ms","context"}}
 for _,v in ipairs(self.events) do log[#log+1]=v end
 assert(love.filesystem.write(prefix.."-frames.csv",serialize(csv)))
 assert(love.filesystem.write(prefix.."-events.csv",serialize(log)))
 local summary={
  mode=self.mode,seed=20261018,frames=self.frame,route_laps=2,
  speed_multiplier=speed_multiplier,max_frame_budget=600,
  distinct_camera_chunks=counts(self.unique),events=#self.events,
  stalls_over_33ms=self.total_spikes,min_fps=minfps,
  frame_ms={p50=percentile(dt,.5),p95=percentile(dt,.95),
    p99=percentile(dt,.99),max=percentile(dt,1)},
  cpu_ms={p50=percentile(cpu,.5),p95=percentile(cpu,.95),
    p99=percentile(cpu,.99),max=percentile(cpu,1)},
  update_ms={p95=percentile(updates,.95)},
  draw_ms={p95=percentile(draws,.95)},
  peak_lua_heap_kib=peak,total_gpu_mesh_allocations=self.total_meshes,
  cache=self.cache and self.cache.metrics or {},
  cache_size_bytes=self.cache and self.cache.bytes or 0,
  synthetic_motion=true,physics_not_tested=true,android_not_tested=true,
  gpu_execution_time_not_measured=true}
 local Json=require("save.json")
 assert(love.filesystem.write(prefix.."-summary.json",Json.encode(summary)))
 print(string.format(
  "R2_LONG_TRAVERSAL_OK mode=%s frames=%d traveledCameraChunks=%d stalls33=%d frame_p95=%.3f frame_p99=%.3f frame_max=%.3f fps_min=%.2f cacheHits=%d cacheWrites=%d",
  self.mode,self.frame,summary.distinct_camera_chunks,self.total_spikes,
  summary.frame_ms.p95,summary.frame_ms.p99,summary.frame_ms.max,minfps,
  summary.cache.hits or 0,summary.cache.writes or 0))
 io.stdout:flush()
 love.event.quit(0)
end
return M
