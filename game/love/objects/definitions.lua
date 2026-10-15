-- Gameplay definitions are generated from data/catalog/ JSON, not copied by hand.
-- Keep this thin interface so existing world/harvest code and packaged LÖVE work.
local all = require("objects.catalog_generated")
local D = {}
function D.get(id) return assert(all[id], "unknown object definition: " .. tostring(id)) end
function D.all() return all end
return D
