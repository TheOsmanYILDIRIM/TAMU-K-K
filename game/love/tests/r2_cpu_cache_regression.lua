-- Focused CPU-only cache/read + renderer-candidate regression.
-- Run from game/love: lua5.4 tests/r2_cpu_cache_regression.lua
-- Timings are synthetic host measurements, NOT LÖVE GPU or Android FPS.
package.path="./?.lua;./?/init.lua;"..package.path
local now=0
local function advance(ms) now=now+ms/1000 end
local files={}
local function digest(s) return string.rep(string.char(#s%251),32) end
-- Portable 64-byte mock vertex records; LuaJIT 2.1 has no string.pack/unpack.
-- This fixture tests cache bookkeeping, integrity and cooperative timing,
-- not native LÖVE float64 encoding (which remains production-owned).
local function pack_vertex(_,_,...)
 local out={}
 for i=1,select("#",...) do
  local value=string.format("%+08.2f",select(i,...))
  assert(#value==8,"fixture float record overflow")
  out[#out+1]=value
 end
 return table.concat(out)
end
local function unpack_vertex(_,buffer,pos)
 advance(.04)
 local values={}
 for i=0,7 do
  values[i+1]=assert(tonumber(buffer:sub(pos+i*8,pos+i*8+7)))
 end
 return values[1],values[2],values[3],values[4],
   values[5],values[6],values[7],values[8],pos+64
end
love={
 timer={getTime=function() return now end},
 filesystem={
  createDirectory=function() return true end,
  getDirectoryItems=function() return {} end,
  getInfo=function(path) return files[path] and {size=#files[path]} end,
  read=function(path) advance(11);return files[path] end,
  write=function(path,value) files[path]=value;return true end,
  remove=function(path) files[path]=nil;return true end
 },
 data={
  hash=function(_,s) advance(7);return digest(s) end,
  encode=function(_,_,s) return (s:gsub(".",function(c) return string.format("%02x",c:byte()) end)) end,
  compress=function(_,_,s) return s end,
  decompress=function(_,_,s) advance(13);return s end,
  pack=pack_vertex,
  unpack=unpack_vertex
 }
}
local Cache=require("world.chunk_cache")
local c=Cache.new({seed=20261018,stamp="cpu-fixture"})
local source={meadow={},forest={},rocky={},water={},detail={}}
for i=1,300 do source.meadow[i]={i,i+1,.5,.25,.4,.3,.2,1} end
assert(c:write(0,0,source))
local read_co=coroutine.create(function()
 return c:read(0,0,function() coroutine.yield("checkpoint") end)
end)
assert(select(2,coroutine.resume(read_co))=="checkpoint")
advance(1000) -- 1s suspended; MUST NOT count as unpack CPU.
local ok,decoded=coroutine.resume(read_co)
assert(ok and coroutine.status(read_co)=="dead",tostring(decoded))
assert(#decoded.meadow==300 and decoded.meadow[1][1]==1)
assert(c.metrics.hits==1 and c.metrics.loaded_vertices==300)
assert(math.abs(c.metrics.read_io_ms-11)<.001)
assert(math.abs(c.metrics.read_hash_ms-7)<.001)
assert(math.abs(c.metrics.read_lz4_ms-13)<.001)
assert(c.metrics.read_unpack_ms>11 and c.metrics.read_unpack_ms<13,
 "unpack CPU timer included suspended coroutine time")
assert(c.metrics.read_io_max_ms>=11 and c.metrics.read_lz4_max_ms>=13)
assert(c:read(5,5)==nil and c.metrics.misses==1)
local cache_path=c:path(0,0)
files[cache_path]=files[cache_path]:sub(1,5)
assert(c:read(0,0)==nil and c.metrics.invalid==1 and not files[cache_path],
 "corrupt disposable OSC cache was not invalidated")
package.loaded["player.depth"]={key=function(x,y) return x+y end,before=function(a,b) return a.depth<b.depth end}
package.loaded["player.core_visual"]={draw=function() end}
package.loaded["player.axe_strike"]={draw=function() end}
local Render=require("objects.renderer")
local function make_world()
 local w={generator_version=1,blocked={},queries=0}
 function w:is_depleted(id) return self.blocked[id]==true end
 function w:objects_in(bounds,include_depleted)
  assert(include_depleted==true)
  self.queries=self.queries+1
  local cx=math.floor(bounds.min_x/256)
  local list={}
  for i=1,20 do
   list[i]={id="worldobj:v1:"..cx..":0:"..i,
    cx=cx,cy=0,x=cx*256+i*2,y=25,kind="tree",radius=4}
  end
  return list
 end
 return w
end
local w=make_world()
local chunks={}
for cx=0,11 do chunks[#chunks+1]={cx=cx,cy=0,x=cx*256,y=0,size=256} end
local stream={visible=function() return chunks end}
local all=Render.collect(w,stream)
assert(#all==240 and w.queries==12 and Render.metrics.cold_queries==12)
local id=all[1].id
w.blocked[id]=true
for i=1,60 do
 local nextlist=Render.collect(w,stream)
 assert(#nextlist==239 and nextlist[1].id~=id)
end
assert(w.queries==12,"warm object collection re-enumerated sites")
w.blocked[id]=nil -- simulated day-based regrowth, no stale depletion.
assert(#Render.collect(w,stream)==240)
chunks[#chunks+1]={cx=12,cy=0,x=12*256,y=0,size=256}
assert(#Render.collect(w,stream)==260 and w.queries==13,
 "movement should cold-query only new chunk")
local other=make_world()
assert(#Render.collect(other,stream)==260 and other.queries==13,
 "new world identity reused previous world candidates")
assert(Render.metrics.collect_calls>=64 and Render.metrics.cold_query_max_ms>=0)
local function percentiles(a)
 table.sort(a)
 local function p(f) return a[math.max(1,math.ceil(#a*f))] end
 return p(.50),p(.95),p(.99),a[#a]
end
local function bench(movement)
 local samples={}
 for i=1,80 do
  if movement then
   local cx=13+i
   chunks[#chunks+1]={cx=cx,cy=0,x=cx*256,y=0,size=256}
   table.remove(chunks,1)
  end
  local start=os.clock()
  Render.collect(other,stream)
  samples[#samples+1]=(os.clock()-start)*1000
 end
 return percentiles(samples)
end
local s50,s95,s99,smax=bench(false)
local m50,m95,m99,mmax=bench(true)
print(string.format("R2_CPU_CACHE_REGRESSION_OK idle_cpu_ms p50/p95/p99/max=%.3f/%.3f/%.3f/%.3f moving_cpu_ms=%.3f/%.3f/%.3f/%.3f cold=%d",
 s50,s95,s99,smax,m50,m95,m99,mmax,Render.metrics.cold_queries))
