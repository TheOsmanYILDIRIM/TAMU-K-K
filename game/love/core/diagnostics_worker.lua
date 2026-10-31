-- Asynchronous bounded diagnostics writer. No graphics or gameplay state.
require('love.filesystem')
require('love.timer')
local channel=assert(...,'diagnostics writer channel missing')
local requests=love.thread.getChannel(channel..':req')
local replies=love.thread.getChannel(channel..':ack')
local file_index=0
while true do
  local data=requests:demand()
  if data=='!stop' then break end
  if type(data)=='string' then
    local started=love.timer.getTime()
    local ok=pcall(function()
      local function path(i)
        return 'diagnostics/tamu-trace-'..tostring(i)..'.jsonl'
      end
      local info=love.filesystem.getInfo(path(file_index))
      if info and info.size>=4*1024*1024 then
        file_index=(file_index+1)%3
        if love.filesystem.getInfo(path(file_index)) then
          assert(love.filesystem.remove(path(file_index)))
        end
      end
      assert(love.filesystem.append(path(file_index),data))
    end)
    replies:push({ok=ok,ms=(love.timer.getTime()-started)*1000})
    if not ok then break end
  end
end
