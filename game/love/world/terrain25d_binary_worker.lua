-- Immutable authored binary vertex IO/decompression off the render thread.
-- Only CPU bytes cross channels; Mesh creation remains on the LÖVE main thread.
require('love.filesystem')
require('love.data')
local input=love.thread.getChannel('tamu25d:binary:requests')
local output=love.thread.getChannel('tamu25d:binary:ready')
while true do
 local job=input:demand()
 if job=='!stop' then break end
 if type(job)=='table' and type(job.cx)=='number' and type(job.cy)=='number'
    and math.abs(job.cx)<100000 and math.abs(job.cy)<100000
    and job.cx%1==0 and job.cy%1==0 then
  local key=tostring(job.cx)..':'..tostring(job.cy)
  local name=('assets/terrain25d/baked/c_%d_%d'):format(job.cx,job.cy)
  local ok,meta,raw=pcall(function()
    local m=love.filesystem.read(name..'.meta.json')
    local compressed=love.filesystem.read(name..'.verts.z')
    if not m or not compressed then return nil,nil end
    return m,love.data.decompress('string','zlib',compressed)
  end)
  if ok and type(meta)=='string' and type(raw)=='string' then
    output:push({key=key,meta=meta,raw=raw})
  else
    output:push({key=key,missing=true,error=ok and nil or tostring(meta)})
  end
 end
end
