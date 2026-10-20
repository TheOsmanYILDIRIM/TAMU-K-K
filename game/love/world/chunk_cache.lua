-- Experimental, disposable, versioned GPU-ready terrain CPU cache.
-- NEVER stores object/simulation/player/save state. Dedicated namespace.
-- Lua data is binary float64; no quantization or water-mask reinterpretation.
local Cache={}
Cache.__index=Cache
local order={"meadow","forest","rocky","water","detail"}
local format="<dddddddd"
local function valid(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
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
 return setmetatable({dir=dir,signature="OSC1:"..options.seed..":"..options.stamp..":"..step..":"..quality,
  bytes=bytes,max_bytes=limit,metrics={reads=0,hits=0,misses=0,invalid=0,writes=0,write_bytes=0,loaded_vertices=0}},Cache)
end
function Cache:path(cx,cy)
 assert(cx==math.floor(cx) and cy==math.floor(cy),"invalid chunk coordinates")
 return self.dir.."/"..cx.."_"..cy..".osc"
end
function Cache:has(cx,cy)
 return love.filesystem.getInfo(self:path(cx,cy),"file")~=nil
end
function Cache:read(cx,cy,checkpoint)
 local path=self:path(cx,cy)
 self.metrics.reads=self.metrics.reads+1
 local info=love.filesystem.getInfo(path,"file")
 if not info then self.metrics.misses=self.metrics.misses+1;return nil end
 local function decode()
  assert(info.size>64 and info.size<20*1024*1024,"invalid file length")
  local encoded=assert(love.filesystem.read(path))
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
  assert(#parts[4]==64 and sha(parts[5])==parts[4],"cache checksum mismatch")
  local buffer=love.data.decompress("string","lz4",parts[5])
  assert(#buffer==total*64,"cache vertex byte length mismatch")
  local result={}
  local pos=1
  for i,name in ipairs(order) do
   local out={}
   for j=1,counts[i] do
    local x,y,u,v,r,g,b,a,newpos=love.data.unpack(format,buffer,pos)
    assert(valid(x) and valid(y) and valid(u) and valid(v)
      and valid(r) and valid(g) and valid(b) and valid(a),"cache NaN/Inf")
    pos=newpos
    out[j]={x,y,u,v,r,g,b,a}
    if checkpoint and j%256==0 then checkpoint() end
   end
   result[name]=out
  end
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
 if love.filesystem.getInfo(path,"file") then return true end
 if self.bytes>=self.max_bytes then return false,"cache cap reached" end
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
 local compressed=love.data.compress("string","lz4",raw)
 local data="OSMAN-STATIC-CACHE-1\n"..self.signature.."\n"
  ..table.concat(counts,",").."\n"..sha(compressed).."\n"..compressed
 if self.bytes+#data>self.max_bytes then return false,"cache cap reached" end
 -- Cache is disposable. A torn write is rejected by hash, never a save file.
 local ok,err=love.filesystem.write(path,data)
 if ok then
  self.bytes=self.bytes+#data
  self.metrics.writes=self.metrics.writes+1
  self.metrics.write_bytes=self.metrics.write_bytes+#data
 end
 return ok,err
end
return Cache
