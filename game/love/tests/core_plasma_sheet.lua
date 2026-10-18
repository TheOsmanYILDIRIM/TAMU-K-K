package.path="./?.lua;./?/init.lua;"..package.path
local S=require("player.core_plasma_sheet")
assert(S.frame_index(0)==0 and S.frame_index(1)==12)
assert(S.frame_index(32/12)==0)
assert(S.quad_position(0)==0)
local x,y=S.quad_position(9)
assert(x==512 and y==512)
assert(not pcall(S.frame_index,math.huge))
local log={},images={}
local g={}
function g.newImage(path)
  assert(path:match("^assets/core_plasma_"))
  local im={getDimensions=function() return 4096,2048 end,setFilter=function()end}
  images[#images+1]=path
  return im
end
function g.newQuad(x,y,w,h,iw,ih)
  assert(w==512 and h==512 and iw==4096 and ih==2048)
  return {x=x,y=y}
end
function g.setColor() end
function g.draw(im,q,x,y,r,sx,sy,ox,oy)
  log[#log+1]={q=q,x=x,y=y,sx=sx,sy=sy,ox=ox,oy=oy}
end
love={filesystem={getInfo=function()return {type="file"}end}}
assert(S.draw(g,"back",0,30,40,2,1)==0)
assert(S.draw(g,"front",0,30,40,2,1)==0)
assert(#images==2 and #log==2 and log[1].sx==log[2].sx)
assert(log[1].ox==256 and log[2].oy==256)
S.draw(g,"front",.5,30,40,2,1)
assert(#images==2)
assert(not pcall(S.draw,g,"invalid",0,0,0,1,1))
print("CORE_PLASMA_SHEET_TEST_OK 32-frame quads/cache/depth-alignment")
