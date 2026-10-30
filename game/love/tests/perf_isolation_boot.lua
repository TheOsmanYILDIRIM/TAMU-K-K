-- Startup menu must not require gameplay subsystems or touch the save dir.
package.path='./?.lua;./?/init.lua;'..package.path
local active={}
local oldrequire=require
require=function(name)
 if name~='core.perf_isolation_boot' then active[#active+1]=name end
 return oldrequire(name)
end
local dims={360,780}
love={graphics={
 getDimensions=function() return dims[1],dims[2] end,
 clear=function()end,setColor=function()end,printf=function()end,
 rectangle=function()end,print=function()end
},timer={getFPS=function()return 60 end},event={quit=function()end}}
local Boot=require('core.perf_isolation_boot')
Boot.install()
assert(#active==0,'no gameplay dependency may load at startup')
love.load()
love.update(.016)
love.draw()
assert(#active==0,'menu draw/update unexpectedly loads gameplay')
assert(type(love.touchpressed)=='function')
print('TAMU_ISOLATION_BOOT_NO_GAME_MODULES_OK')
