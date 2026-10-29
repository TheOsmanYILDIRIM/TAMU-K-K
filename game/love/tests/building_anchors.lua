package.path="./?.lua;./?/init.lua;"..package.path
local A=require("systems.building_anchors")
local function near(a,b) return math.abs(a-b)<1e-9 end
assert(A.unit==32 and A.wall_height==24)
local wall=assert(A.piece_line("tamu:wall_wood","top"))
local eave=assert(A.piece_line("tamu:roof_slope_wood","eave"))
local ridge=assert(A.piece_line("tamu:roof_slope_wood","ridge"))
-- Wall base z=6, top z=30; roof center y=32, z=30.
local top=A.transform(wall,{x=0,y=48,z=6,rotation=0})
local bottom=A.transform(eave,{x=0,y=32,z=30,rotation=0})
local ok,why,delta=A.match(top,bottom)
assert(ok and why=="matched" and near(delta,0))
local solved=assert(A.snap_piece("tamu:wall_wood",
  {x=0,y=48,z=6,rotation=0},"top",
  "tamu:roof_slope_wood",0,"eave"))
assert(near(solved.x,0) and near(solved.y,32) and near(solved.z,30))
local solved_north=assert(A.snap_piece("tamu:wall_wood",
  {x=0,y=-16,z=6,rotation=0},"top",
  "tamu:roof_slope_wood",2,"eave"))
assert(near(solved_north.x,0) and near(solved_north.y,0) and near(solved_north.z,30))
local solved_ridge=assert(A.snap_piece("tamu:roof_slope_wood",
  {x=0,y=0,z=30,rotation=2},"ridge",
  "tamu:roof_slope_wood",0,"ridge"))
assert(near(solved_ridge.x,0) and near(solved_ridge.y,32) and near(solved_ridge.z,30))
local bad_height=A.transform(eave,{x=0,y=32,z=31,rotation=0})
assert(A.match(top,bad_height)==false,"1-unit roof height error not rejected")
local wrong_axis=A.transform(eave,{x=0,y=32,z=30,rotation=1})
assert(A.match(top,wrong_axis)==false,"wrong roof axis accepted")
local wrong_type=A.line("x","roof_ridge",top.a,top.b)
assert(A.match(top,wrong_type)==false,"wrong anchor family accepted")
local too_long=A.line("x","roof_eave",top.a,A.point(top.b.x+1,top.b.y,top.b.z))
assert(A.match(top,too_long)==false,"distorted edge was accepted")
-- Ridge is shared by opposing roof panels, not guessed from image bounds.
local north=A.transform(ridge,{x=0,y=0,z=30,rotation=2})
local south=A.transform(ridge,{x=0,y=32,z=30,rotation=0})
assert(A.match(north,south))
local test_move=A.snap_translation(top,A.line("test","roof_eave",
  A.point(16,0,0),A.point(-16,0,0)))
assert(near(test_move.x,0) and near(test_move.y,48) and near(test_move.z,30))
local sx,sy=A.sprite_point(A.point(0,0,0))
assert(near(sx,64) and near(sy,92))
local report={}
for x=0,32,32 do
  local w=A.transform(wall,{x=x,y=48,z=6,rotation=0})
  local r=A.transform(eave,{x=x,y=32,z=30,rotation=0})
  report[#report+1]={w,r}
end
local all,count,maxerr=A.check_pairs(report)
assert(all and count==2 and near(maxerr,0))
print("BUILDING_ANCHORS_OK exact eaves/ridges, wrong height/axis/type/length rejected")
