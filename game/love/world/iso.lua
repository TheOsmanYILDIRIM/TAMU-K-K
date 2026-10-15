local M={}
local X=math.sqrt(.5)
local Y=X/2
function M.project(x,y,z) return (x-y)*X,(x+y)*Y-(z or 0) end
function M.unproject(sx,sy) return (sx/X+sy/Y)/2,(sy/Y-sx/X)/2 end
return M
