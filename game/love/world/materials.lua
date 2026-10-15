-- Planned authored assets: albedo/color, height for displacement, normal for illumination.
-- Normal maps alone do not sculpt geometry.
local M={slots={}}
function M.register(id,variant,asset)
 assert(type(asset)=="table")
 for _,key in ipairs({"albedo","height","normal"}) do
  if asset[key]~=nil then assert(type(asset[key])=="string" and #asset[key]>0) end
 end
 M.slots[id.."/"..(variant or "default")]=asset
end
function M.get(id,variant) return M.slots[id.."/"..(variant or "default")] end
return M
