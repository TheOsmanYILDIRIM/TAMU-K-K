-- Pure-Lua probe contract: frame quantiles, chunk-stage accounting and A/B reset.
package.path="./?.lua;./?/init.lua;"..package.path
local now=0
love={
  timer={getTime=function() now=now+.001;return now end},
  graphics={getStats=function() return {texturememory=2097152} end}
}
local Probe=require("core.r2_android_probe")
local p=Probe.new()
local chunks={{_terrain_meshes={}}, {_terrain_job=true}}
local stream={jobs={pending=true},visible=function() return chunks end}
local stats={needed=4,loaded=2}
local cache={metrics={hits=5,misses=0,writes=0,invalid=0},pending_count=0}
for i=1,35 do
  p:begin(i/1000)
  p:add("stream",i/2)
  p:add("terrain",i/3)
  p:mesh(1,100)
  p:sample(stream,stats,cache)
end
local p50,p95,p99,maximum=p:quantiles("frame")
assert(p50==18 and p95==34 and p99==35 and maximum==35,
  "deterministic nearest-rank quantiles")
assert(p.ready==1 and p.missing_cpu==2 and p.missing_gpu==1 and p.stream_jobs==1)
assert(p.tex_mib==2 and p.metrics.hits==5)
assert(p:lines()[1]:find("FULL",1,true))
p:cycle()
assert(p.mode==2 and p.total==0 and #p.history.frame==0)
p:cycle()
assert(p.mode==3)
p:cycle()
assert(p.mode==4)
p:cycle()
assert(p.mode==1)
print("R2_ANDROID_PROBE_LUA_OK")
