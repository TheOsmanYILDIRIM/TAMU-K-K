-- CPU-only default-asset contract; Python verifies actual RGBA output.
package.path="./?.lua;./?/init.lua;"..package.path
local Parts=require("systems.building_parts")
local Visual=require("systems.building_visual_contract")
local Adapter=require("systems.building_default_atlas")
assert(type(Adapter.new)=="function" and type(Adapter.draw_visible)=="function")
local defs=Parts.all()
assert(#Parts.ids()==19)
assert(Visual.source_px==128 and Visual.processed_px==128)
assert(Visual.pivot_x==64 and Visual.pivot_y==92)
assert(Visual.source_ppu==2 and Visual.sprite_scale==0.5)
local cache=Visual.precompute(defs)
for _,id in ipairs(Parts.ids()) do
  assert(defs[id].visual.status=="procedural_default")
  for rotation=0,3 do
    local layout=cache[id][rotation]
    assert(layout.source.width==128 and layout.output.width==128)
    assert(layout.rotation==rotation and Visual.check_canvas(layout))
  end
end
print("BUILDING_DEFAULT_LUA_OK definitions=19 directions=4 canvas=128 palette_limit=64")
