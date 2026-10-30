-- 25D terrain CPU worker. No love.graphics and no player/save writes.
-- Packaged authored binary first; otherwise reuse verified disposable cache,
-- or generate the same authored geometry off the render thread.
require('love.filesystem')
require('love.data')
local Json=require('save.json')
local Runtime=require('world.terrain25d_runtime')
local Baked=require('world.terrain25d_baked')
local R2=require('world.r2_playable')
local requests=love.thread.getChannel('tamu25d:binary:requests')
local results=love.thread.getChannel('tamu25d:binary:ready')
local cache_root='25d-terrain-cache-v1/'
local cpu
local function context()
 if not cpu then cpu=Runtime.cpu_new(R2.new()) end
 return cpu
end
local function from_disk(base)
 local meta=love.filesystem.read(base..'.meta.json')
 local compressed=love.filesystem.read(base..'.verts.z')
 if not meta or not compressed then return nil end
 return {meta=meta,raw=love.data.decompress('string','zlib',compressed)}
end
local function get(job)
 local key=tostring(job.cx)..':'..tostring(job.cy)
 local name=('c_%d_%d'):format(job.cx,job.cy)
 local packaged='assets/terrain25d/baked/'..name
 local item=from_disk(packaged)
 if item then
   item.key=key
   return item
 end
 local runtime=context()
 local cached=from_disk(cache_root..name)
 if cached then
   local ok,doc=pcall(Json.decode,cached.meta)
   if ok and doc.stamp==Baked.cpu_stamp(runtime) and
     doc.cx==job.cx and doc.cy==job.cy then
     cached.key=key
     return cached
   end
 end
 local chunk={cx=job.cx,cy=job.cy,key=key,
   x=job.cx*256,y=job.cy*256,size=256,layers={}}
 local prepared=runtime:prepare(chunk,nil,true)
 local encoded=Baked.pack_cpu(runtime,chunk,prepared)
 -- This is a disposable renderer cache, never Stage6 gameplay persistence.
 local compressed=love.data.compress('string','zlib',encoded.raw,6)
 if love.filesystem.createDirectory(cache_root) then
   love.filesystem.write(cache_root..name..'.verts.z',compressed)
   love.filesystem.write(cache_root..name..'.meta.json',encoded.meta)
 end
 encoded.key=key
 encoded.generated=true
 return encoded
end
while true do
 local job=requests:demand()
 if job=='!stop' then break end
 if type(job)=='table' and type(job.cx)=='number'
    and type(job.cy)=='number' and
    math.abs(job.cx)<100000 and math.abs(job.cy)<100000
    and job.cx%1==0 and job.cy%1==0 then
   local ok,item=pcall(get,job)
   if ok then results:push(item)
   else
     results:push({key=tostring(job.cx)..':'..tostring(job.cy),
       missing=true,error=tostring(item)})
   end
 end
end
