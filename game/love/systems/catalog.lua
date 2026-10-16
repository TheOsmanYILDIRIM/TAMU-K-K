-- Read-only definitions/recipes; generated exclusively from JSON manifest.
local registry = require("systems.catalog_generated")
local M = {}

local function definition(id)
  local item = registry.items[id]
  assert(item, "missing inventory definition: "..tostring(id))
  return item
end

function M.item(id) return definition(id) end
function M.recipe(id)
  local recipe=registry.recipes[id]
  assert(recipe, "missing recipe: "..tostring(id))
  return recipe
end
function M.version() return registry.catalog_version end
function M.items() return registry.items end
function M.recipes() return registry.recipes end

return M
