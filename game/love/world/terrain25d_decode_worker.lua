-- Read/PNG-decode immutable compact atlas pages off the LÖVE render thread.
-- ImageData crosses the channel; ONLY love.graphics.newImage stays on main.
require('love.image')
local request=love.thread.getChannel('osman25d:decode:req')
while true do
 local name=request:demand()
 if name=='!stop' then break end
 assert(type(name)=='string' and name:match('^atlas_%d+%.png$'))
 local path='assets/terrain25d/'..name
 local ok,data=pcall(love.image.newImageData,path)
 local channel=love.thread.getChannel('osman25d:decode:'..name)
 if ok then channel:push(data)
 else channel:push('ERROR: '..tostring(data)) end
end
