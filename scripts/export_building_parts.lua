-- Export only the existing authoritative building_parts.lua definitions for
-- deterministic, optional code-generated sprite previews. No mutations.
package.path="./game/love/?.lua;./game/love/?/init.lua;"..package.path
local Parts=require("systems.building_parts")
local Json=require("save.json")
local function serializable(v)
  if type(v)~="table" then return v end
  local max,count,is_array=0,0,true
  for k in pairs(v) do
    count=count+1
    if type(k)~="number" or k<1 or k~=math.floor(k) then is_array=false
    else max=math.max(max,k) end
  end
  local out={}
  if is_array and count>0 and max==count then
    for i=1,count do out[i]=serializable(v[i]) end
    return Json.array(out)
  end
  for k,val in pairs(v) do out[k]=serializable(val) end
  return out
end
assert(#Parts.ids()==19,"unexpected canonical kit count")
io.write(Json.encode({definitions=serializable(Parts.all())}),"\n")
