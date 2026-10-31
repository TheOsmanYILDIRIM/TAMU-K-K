package.path='./?.lua;./?/init.lua;'..package.path
local V=require('player.side_baked_visual')
local expected={SE={0,false},SW={0,true},NE={2,false},NW={2,true}}
for face,want in pairs(expected) do
  local row,flip,frame=V.select(face,false,2)
  assert(row==want[1] and flip==want[2] and frame==0,face..' idle')
  row,flip,frame=V.select(face,true,.25)
  assert(row==want[1]+1 and flip==want[2] and frame==3,face..' walk')
end
assert(not pcall(function() V.select('INVALID',false,0) end))
print('TAMU_SIDE_BAKED_4DIR_MIRROR_OK')
