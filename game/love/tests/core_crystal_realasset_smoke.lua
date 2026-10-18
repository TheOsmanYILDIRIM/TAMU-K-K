local Crystal=require("player.core_crystal_shader")
local fx,frames= nil,0
local requested,saved=false,false
function love.load()
 love.window.setMode(360,720,{resizable=false})
 local root="assets/"
 local base=love.graphics.newImage(root.."file_000000007cf082119c4dde3e346c2bcb.png")
 local mask=love.graphics.newImage(root.."core_crystal_mask_aligned.png")
 assert(base:getWidth()==1254 and base:getHeight()==1254,"Core resolution mismatch")
 assert(mask:getWidth()==1254 and mask:getHeight()==1254,"mask resolution mismatch")
 fx=Crystal.new(base,mask)
end
function love.update(dt)
 frames=frames+1
 if saved and frames>16 then love.event.quit(0) end
 if frames>180 then error("screenshot callback did not finish") end
end
function love.draw()
 love.graphics.clear(.08,.09,.11,1)
 Crystal.draw(fx,180,315,0,.24,.24,627,627,1.04)
 if not requested and frames>=4 then
  requested=true
  love.graphics.captureScreenshot(function(data)
   data:encode("png","core-crystal-realasset.png")
   saved=true
   print("CORE_REALASSET_SCREENSHOT_OK")
   io.stdout:flush()
  end)
 end
end
