-- Experimental disposable terrain cache worker.
-- No rendering, WorldQuery, save state or gameplay mutation on this thread.
local queue,replies=...
assert(queue and replies,"cache worker channels required")
while true do
 local job=queue:demand()
 if job==false then break end
 local success,result=pcall(function()
  assert(type(job)=="table" and type(job.raw)=="string"
    and type(job.path)=="string" and type(job.header)=="string"
    and type(job.limit)=="number","invalid cache write job")
  local compressed=love.data.compress("string","lz4",job.raw)
  local digest=love.data.encode("string","hex",
    love.data.hash("sha256",compressed))
  local payload=job.header..digest.."\n"..compressed
  assert(#payload<=job.limit,"cache quota reached")
  -- Only isolated and disposable OSC cache paths; never Stage6 save paths.
  assert(job.path:match("^experimental%-chunk%-cache%-1/[%w_:%-]+/%-?%d+_%-?%d+%.osc$"),
    "invalid experimental cache destination")
  local ok,err=love.filesystem.write(job.path,payload)
  assert(ok,err or "cannot persist terrain cache")
  return #payload
 end)
 replies:push({path=job.path,ok=success,
  bytes=success and result or 0,error=not success and tostring(result) or ""})
end
