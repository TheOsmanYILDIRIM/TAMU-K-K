-- Portable R2 diagnostic probe. CPU wall-time is NOT a GPU timer.
-- No gameplay state, disk writes, screenshots, or Stage6 integrations.
local Probe={}
Probe.__index=Probe
local names={"frame","update","stream","terrain","objects","collect","upload","read_io","lz4"}
local modes={"FULL","CULL","NO OBJECTS","NO TERRAIN"}
local size=180
function Probe.new()
  local self=setmetatable({mode=1,history={},current={},total=0,
    cache_lines=nil,lua_mib=0,lua_peak_mib=0,tex_mib=0,ready=0,
    missing_cpu=0,missing_gpu=0,stream_jobs=0,uploaded=0,vertices=0},Probe)
  self:reset()
  return self
end
function Probe:reset()
  self.history={}
  for _,name in ipairs(names) do self.history[name]={} end
  self.total=0
  self.cache_lines=nil
  self.current={}
  self.lua_peak_mib=collectgarbage("count")/1024
end
function Probe:cycle()
  self.mode=self.mode%#modes+1
  self:reset()
end
function Probe:begin(dt)
  self.current={}
  self.current.frame=dt*1000
  self.uploaded,self.vertices=0,0
end
function Probe:add(name,ms)
  if self.current[name]~=nil then
    self.current[name]=self.current[name]+ms
  else
    self.current[name]=ms
  end
end
function Probe:mesh(ms,vertices)
  self:add("upload",ms)
  self.uploaded=self.uploaded+1
  self.vertices=self.vertices+(vertices or 0)
end
local function quantiles(numbers)
  if #numbers==0 then return 0,0,0,0 end
  local sorted={}
  for i,v in ipairs(numbers) do sorted[i]=v end
  table.sort(sorted)
  local function q(p) return sorted[math.max(1,math.ceil(#sorted*p))] end
  return q(.5),q(.95),q(.99),sorted[#sorted]
end
function Probe:quantiles(name)
  assert(self.history[name],"unknown profile field")
  return quantiles(self.history[name])
end
local function formatted(self,name,label)
  local a,b,c,d=self:quantiles(name)
  return string.format("%-7s %5.1f/%5.1f/%5.1f/%5.1f",label,a,b,c,d)
end
function Probe:sample(stream,stats,cache)
  self.total=self.total+1
  local pos=(self.total-1)%size+1
  for _,name in ipairs(names) do
    self.history[name][pos]=self.current[name] or 0
  end
  self.ready,self.stream_jobs=0,0
  for _,chunk in ipairs(stream:visible()) do
    if chunk._terrain_meshes then self.ready=self.ready+1 end
  end
  for _ in pairs(stream.jobs) do self.stream_jobs=self.stream_jobs+1 end
  self.missing_cpu=math.max(0,stats.needed-stats.loaded)
  self.missing_gpu=math.max(0,stats.loaded-self.ready)
  if self.total%20==1 then
    self.lua_mib=collectgarbage("count")/1024
    self.lua_peak_mib=math.max(self.lua_peak_mib,self.lua_mib)
    if love.graphics.getStats then
      local ok,values=pcall(love.graphics.getStats)
      if ok and values then self.tex_mib=(values.texturememory or 0)/1048576 end
    end
  end
  self.metrics=cache and cache.metrics or {}
  self.cache_pending=cache and cache.pending_count or 0
  if self.total%20==0 then self.cache_lines=nil end
  if self.total==30 or self.total%180==0 then
    local a,b,c,d=self:quantiles("frame")
    print(string.format(
      "R2_PERF_PROFILE mode=%s samples=%d frame_p50=%.1f frame_p95=%.1f frame_p99=%.1f frame_max=%.1f ready=%d needed=%d cpu_missing=%d gpu_missing=%d",
      modes[self.mode],math.min(self.total,size),a,b,c,d,self.ready,stats.needed,
      self.missing_cpu,self.missing_gpu))
  end
end
function Probe:lines()
  if self.cache_lines then return self.cache_lines end
  local m=self.metrics
  self.cache_lines={
    string.format("MODE %s (tap to cycle)",modes[self.mode]),
    string.format("Ready %d/%d CPU miss %d GPU wait %d",
      self.ready,self.ready+self.missing_cpu+self.missing_gpu,
      self.missing_cpu,self.missing_gpu),
    string.format("jobs %d | cache H%d M%d W%d I%d P%d",self.stream_jobs,
      m.hits or 0,m.misses or 0,m.writes or 0,m.invalid or 0,
      self.cache_pending or 0),
    string.format("CPU ms: p50/p95/p99/max [%d]",math.min(self.total,size)),
    formatted(self,"frame","Frame"),
    formatted(self,"update","Update"),
    formatted(self,"stream","Stream"),
    formatted(self,"terrain","Terrain"),
    formatted(self,"objects","Objects"),
    formatted(self,"collect","Collect"),
    formatted(self,"upload","newMesh"),
    formatted(self,"read_io","DiskIO"),
    formatted(self,"lz4","LZ4"),
    string.format("Lua %.1fMB peak %.1fMB tex %.1fMB",
      self.lua_mib,self.lua_peak_mib,self.tex_mib),
    string.format("newMesh last %d | verts %d",self.uploaded,self.vertices),
    "GPU timing: not measured (CPU calls only)"
  }
  return self.cache_lines
end
return Probe
