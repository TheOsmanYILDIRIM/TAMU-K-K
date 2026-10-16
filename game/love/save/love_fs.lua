-- LÖVE sandbox backend. Deliberately no claimed rename/fsync primitive.
local M={}
function M.new()
  assert(love and love.filesystem,"requires live love.filesystem")
  local F={}
  function F:read(path)
    local data=love.filesystem.read(path)
    return data
  end
  function F:write(path,data)
    local ok=love.filesystem.write(path,data)
    return ok==true
  end
  function F:mkdir(path)
    return love.filesystem.createDirectory(path)==true
  end
  return F
end
return M
