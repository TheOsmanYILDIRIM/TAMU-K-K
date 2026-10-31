-- Export only canonical R2 object records; never synthesize replacements.
package.path='./?.lua;./?/init.lua;'..package.path
local JSON=require('save.json')
local R2=require('world.r2_playable')
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
    out[#out+1]={id=o.id,x=o.x,y=o.y,kind=o.kind,radius=o.radius,
      cx=math.floor(o.x/256),cy=math.floor(o.y/256)}
   end
  end
 end
end
table.sort(out,function(a,b) return a.id<b.id end)
assert(#out>10,'canonical R2 ecology returned no usable objects')
local file=assert(io.open('chunks/r2_objects.json','wb'))
file:write(JSON.encode({seed=20261018,objects=out}))
file:close()
print('TAMU_CANONICAL_OBJECT_EXPORT_OK count='..#out)
