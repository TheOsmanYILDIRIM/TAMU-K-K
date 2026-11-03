-- Isolated shader GPU test: synthetic PNG and binary mask; not artistic acceptance.
package.path="game/love/?.lua;game/love/?/init.lua;game/love/?.lua;"..package.path
local Crystal=require("player.core_crystal_shader")
local effect
local ticks=0
function love.load()
  love.window.setMode(360,640,{resizable=false})
  local base=love.image.newImageData(128,128)
  local mask=love.image.newImageData(128,128)
  for y=0,127 do
    for x=0,127 do
      local dx,dy=x-64,y-64
      local inside=dx*dx+dy*dy<45*45
      base:setPixel(x,y,inside and .30 or .12,inside and .45 or .15,inside and .51 or .17,1)
      mask:setPixel(x,y,inside and 1 or 0,inside and 1 or 0,inside and 1 or 0,1)
    end
  end
  effect=Crystal.new(love.graphics.newImage(base),love.graphics.newImage(mask),
      {center_px={64,64},extent_px={48,48}})
end
function love.update(dt) ticks=ticks+1; if ticks>8 then love.event.quit() end end
function love.draw()
  love.graphics.clear(.08,.09,.11,1)
  Crystal.draw(effect,180,300,0,2,2,64,64,1.04)
  if ticks==4 then
    love.graphics.captureScreenshot("core-crystal-shader-smoke.png")
  end
end
