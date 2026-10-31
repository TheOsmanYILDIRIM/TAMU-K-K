-- Export only canonical R2 object records; never synthesize replacements.
package.path='./?.lua;./?/init.lua;'..package.path
local JSON=require('save.json')
local R2=require('world.r2_playable')
local Iso=require('world.iso')
local p=R2.new({read=function(name)
 local f=assert(io.open('assets/worldbuild/'..name,'rb'))
 local bytes=f:read('*a');f:close()
 return bytes
end})
local out={}
local seen={}
for cy=-1,2 do
 for cx=-1,2 do
  local list=p.objects:objects_in({
   min_x=cx*256,min_y=cy*256,max_x=(cx+1)*256,max_y=(cy+1)*256
  },true)
  for _,o in ipairs(list) do
   if not seen[o.id] and o.x>=-256 and o.x<768 and o.y>=-256 and o.y<768 then
    seen[o.id]=true
    local sx,sy=Iso.project(o.x,o.y,p.topography:height(o.x,o.y)*.35)
    out[#out+1]={id=o.id,x=o.x,y=o.y,sx=sx,sy=sy,kind=o.kind,radius=o.radius,
      cx=math.floor(o.x/256),cy=math.floor(o.y/256)}
   end
  end
 end
end
table.sort(out,function(a,b) return a.id<b.id end)
assert(#out>10,'canonical R2 ecology returned no usable objects')
local file=assert(io.open('chunks/r2_objects.json','wb'))
file:write('{"seed":20261018,"objects":[')
for i,o in ipairs(out) do
 if i>1 then file:write(',') end
 assert(o.id:match('^[%w:_./%-]+$') and o.kind:match('^[%w_%-]+$'))
 file:write(string.format('{"id":"%s","x":%.8f,"y":%.8f,"sx":%.8f,"sy":%.8f,"kind":"%s","radius":%.8f,"cx":%d,"cy":%d}',
   o.id,o.x,o.y,o.sx,o.sy,o.kind,o.radius,o.cx,o.cy))
end
file:write(']}')
file:close()
print('TAMU_CANONICAL_OBJECT_EXPORT_OK count='..#out)
