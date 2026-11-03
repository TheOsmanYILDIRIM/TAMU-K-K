-- Experimental, disposable, versioned GPU-ready terrain CPU cache.
-- NEVER stores object/simulation/player/save state. Dedicated namespace.
-- Lua data is binary float64; no quantization or water-mask reinterpretation.
local Cache={}
Cache.__index=Cache
local order={"meadow","forest","rocky","water","detail"}
local format="<dddddddd"
local function valid(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
-- unpack() always returns numeric doubles; preserve NaN/Inf rejection without
-- eight dynamic type checks and abs calls per vertex.
local huge=math.huge
local function finite_vertex(v) return v==v and v<huge and v>-huge end
-- Additive diagnostics only. Never include coroutine suspension in CPU timing.
local function sample(metrics,phase,start)
 if not start then return end
 local ms=(love.timer.getTime()-start)*1000
 local key="read_"..phase
 metrics[key.."_ms"]=(metrics[key.."_ms"] or 0)+ms
 metrics[key.."_max_ms"]=math.max(metrics[key.."_max_ms"] or 0,ms)
end
local function sha(src)
 return love.data.encode("string","hex",love.data.hash("sha256",src))
end
local function lines(blob)
 local a,b,c,d=1
 local out={}
 for i=1,4 do
  local p=blob:find("\n",a,true)
  if not p then return nil end
  out[i]=blob:sub(a,p-1)
  a=p+1
 end
 out[5]=blob:sub(a)
 return out
end
function Cache.new(options)
 assert(love and love.filesystem and love.data,"real LOVE filesystem and data required")
 assert(type(options)=="table" and valid(options.seed) and options.seed>=0
  and options.seed==math.floor(options.seed),"invalid seed")
 assert(type(options.stamp)=="string" and options.stamp:match("^[a-z0-9_-]+$"),
  "unsafe world content stamp")
 local size=options.size or 256
 local step=options.step or 8
 assert(size==256 and size%step==0 and step>0,"unsupported pilot geometry")
 local quality=options.quality or "standard"
 assert(quality=="standard","pilot only tests standard full-fidelity meshes")
 local dir="experimental-chunk-cache-1/"..options.seed.."-"..options.stamp.."-s"..step.."-q"..quality
 local ok=love.filesystem.createDirectory(dir)
 assert(ok,"cannot create isolated experimental cache directory")
 local bytes=0
 for _,name in ipairs(love.filesystem.getDirectoryItems(dir)) do
  local info=love.filesystem.getInfo(dir.."/"..name,"file")
  if info then bytes=bytes+info.size end
 end
 local limit=options.max_bytes or 192*1024*1024
 assert(limit>0 and limit<=1024*1024*1024,"invalid cache cap")
 local writer
 -- Compression, hash and disk IO must never block a frame.
 if love.thread and love.thread.newThread and love.thread.newChannel then
  local queue,replies=love.thread.newChannel(),love.thread.newChannel()
  local thread=love.thread.newThread("world/chunk_cache_worker.lua")
  thread:start(queue,replies)
  writer={queue=queue,replies=replies,thread=thread}
 end
 return setmetatable({dir=dir,signature="OSC1:"..options.seed..":"..options.stamp..":"..step..":"..quality,
  bytes=bytes,max_bytes=limit,writer=writer,pending={},pending_count=0,
  reserved_bytes=0,metrics={reads=0,hits=0,misses=0,invalid=0,writes=0,
   write_bytes=0,write_errors=0,loaded_vertices=0}},Cache)
end
function Cache:path(cx,cy)
 assert(cx==math.floor(cx) and cy==math.floor(cy),"invalid chunk coordinates")
 return self.dir.."/"..cx.."_"..cy..".osc"
end
function Cache:has(cx,cy)
 local path=self:path(cx,cy)
 return self.pending[path]~=nil or love.filesystem.getInfo(path,"file")~=nil
end
function Cache:poll()
 local writer=self.writer
 if not writer then return end
 while true do
  local reply=writer.replies:pop()
  if not reply then break end
  local reserve=self.pending[reply.path]
  if reserve then
   self.pending[reply.path]=nil
   self.pending_count=self.pending_count-1
   self.reserved_bytes=math.max(0,self.reserved_bytes-reserve)
   if reply.ok then
    self.bytes=self.bytes+reply.bytes
    self.metrics.writes=self.metrics.writes+1
    self.metrics.write_bytes=self.metrics.write_bytes+reply.bytes
   else
    self.metrics.write_errors=self.metrics.write_errors+1
    print("CHUNK_CACHE_WRITE_ERROR "..tostring(reply.error))
   end
  end
 end
 local err=writer.thread:getError()
 if err and not writer.failed then
  writer.failed=true
  self.metrics.write_errors=self.metrics.write_errors+self.pending_count
  self.pending,self.pending_count,self.reserved_bytes={},0,0
  print("CHUNK_CACHE_WORKER_ERROR "..tostring(err))
 end
end
function Cache:flush(seconds)
 if not self.writer then return true end
 local start=love.timer.getTime()
 while self.pending_count>0 and love.timer.getTime()-start<(seconds or 8) do
  self:poll()
  if self.pending_count>0 then love.timer.sleep(.005) end
 end
 self:poll()
 return self.pending_count==0 and not self.writer.failed
end
function Cache:close()
 if self.writer and not self.writer.closing then
  self:flush(8)
  self.writer.closing=true
  if not self.writer.failed and self.writer.thread:isRunning() then
   self.writer.queue:push(false)
  end
 end
end
function Cache:read(cx,cy,checkpoint)
 local path=self:path(cx,cy)
 self:poll()
 self.metrics.reads=self.metrics.reads+1
 if self.pending[path] then
  self.metrics.misses=self.metrics.misses+1
  return nil -- do not treat a still-written file as corrupt
 end
 local info=love.filesystem.getInfo(path,"file")
 if not info then self.metrics.misses=self.metrics.misses+1;return nil end
 local function decode()
  local clock=love.timer and love.timer.getTime
  assert(info.size>64 and info.size<20*1024*1024,"invalid file length")
  local started=clock and clock()
  local encoded=assert(love.filesystem.read(path))
  sample(self.metrics,"io",started)
  local parts=assert(lines(encoded),"missing cache header")
  assert(parts[1]=="OSMAN-STATIC-CACHE-1" and parts[2]==self.signature,
    "stale cache version/content")
  local counts={}
  local total=0
  for n in parts[3]:gmatch("[^,]+") do
   local count=tonumber(n)
   assert(count and count>=0 and count==math.floor(count) and count<=200000
    and count%3==0,"invalid mesh vertex count")
   counts[#counts+1]=count
   total=total+count
  end
  assert(#counts==#order and total<=500000,"invalid layer layout")
  local started_hash=clock and clock()
  local digest=sha(parts[5])
  sample(self.metrics,"hash",started_hash)
  assert(#parts[4]==64 and digest==parts[4],"cache checksum mismatch")
  local started_lz4=clock and clock()
  local buffer=love.data.decompress("string","lz4",parts[5])
  sample(self.metrics,"lz4",started_lz4)
  assert(#buffer==total*64,"cache vertex byte length mismatch")
  local result={}
  local pos=1
  local unpack_vertex=love.data.unpack
  local started_unpack=clock and clock()
  for i,name in ipairs(order) do
   local out={}
   for j=1,counts[i] do
    local x,y,u,v,r,g,b,a,newpos=unpack_vertex(format,buffer,pos)
    assert(finite_vertex(x) and finite_vertex(y) and
      finite_vertex(u) and finite_vertex(v) and
      finite_vertex(r) and finite_vertex(g) and
      finite_vertex(b) and finite_vertex(a),"cache NaN/Inf")
    pos=newpos
    out[j]={x,y,u,v,r,g,b,a}
    if checkpoint and j%256==0 then
      sample(self.metrics,"unpack",started_unpack)
      checkpoint()
      started_unpack=clock and clock()
    end
   end
   result[name]=out
  end
  sample(self.metrics,"unpack",started_unpack)
  assert(pos==#buffer+1,"trailing cache data")
  return result,total
 end
 local ok,result,total=pcall(decode)
 if not ok then
  self.metrics.invalid=self.metrics.invalid+1
  self.metrics.misses=self.metrics.misses+1
  -- Disposable corrupt cache only: never touch game saves or authored files.
  if love.filesystem.remove(path) then self.bytes=math.max(0,self.bytes-info.size) end
  return nil
 end
 self.metrics.hits=self.metrics.hits+1
 self.metrics.loaded_vertices=self.metrics.loaded_vertices+total
 return result
end
function Cache:write(cx,cy,meshes,checkpoint)
 local path=self:path(cx,cy)
 self:poll()
 if self.pending[path] or love.filesystem.getInfo(path,"file") then
  return true
 end
 if self.bytes>=self.max_bytes then return false,"cache cap reached" end
 if self.writer and (self.writer.failed or self.pending_count>=3) then
  return false,"writer busy or unavailable"
 end
 local buffer,counts={},{}
 local total=0
 for _,name in ipairs(order) do
  local vertices=assert(meshes[name],"missing terrain mesh array")
  assert(#vertices%3==0 and #vertices<=200000,"invalid cache mesh size")
  counts[#counts+1]=#vertices
  total=total+#vertices
  for j,v in ipairs(vertices) do
   assert(#v==8,"invalid vertex")
   buffer[#buffer+1]=love.data.pack("string",format,
    v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8])
   if checkpoint and j%256==0 then checkpoint() end
  end
 end
 assert(total<=500000,"oversized chunk")
 local raw=table.concat(buffer)
 local header="OSMAN-STATIC-CACHE-1\n"..self.signature.."\n"
  ..table.concat(counts,",").."\n"
 if self.writer then
  local reserve=#raw+#header+128
  if self.bytes+self.reserved_bytes+reserve>self.max_bytes then
   return false,"cache cap reached"
  end
  self.pending[path]=reserve
  self.pending_count=self.pending_count+1
  self.reserved_bytes=self.reserved_bytes+reserve
  local ok,err=pcall(function()
   self.writer.queue:push({path=path,raw=raw,header=header,
    limit=self.max_bytes-self.bytes})
  end)
  if not ok then
   self.pending[path]=nil
   self.pending_count=self.pending_count-1
   self.reserved_bytes=self.reserved_bytes-reserve
   return false,tostring(err)
  end
  return true,"queued"
 end
 -- Fallback when love.thread is unavailable (only for non-thread test hosts).
 local compressed=love.data.compress("string","lz4",raw)
 local data=header..sha(compressed).."\n"..compressed
 if self.bytes+#data>self.max_bytes then return false,"cache cap reached" end
 local ok,err=love.filesystem.write(path,data)
 if ok then
  self.bytes=self.bytes+#data
  self.metrics.writes=self.metrics.writes+1
  self.metrics.write_bytes=self.metrics.write_bytes+#data
 end
 return ok,err
end
return Cache
