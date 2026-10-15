-- Stage 4 domain definitions. Stable IDs mirror data/catalog/definitions.
-- Lua constants keep simulation independent of LOVE and JSON parsers.
local D={}
local all={
 ["core:oak_tree"]={id="core:oak_tree",kind="tree",biomes={forest=true,meadow=true},radius=11,duration_ticks=90,drops={{def_id="core:wood_log",count=3}}},
 ["core:stone_rock"]={id="core:stone_rock",kind="rock",biomes={rocky=true,meadow=true},radius=12,duration_ticks=120,drops={{def_id="core:stone",count=2}}}
}
function D.get(id) return assert(all[id],"unknown object definition: "..tostring(id)) end
function D.all() return all end
return D
