package.path="./?.lua;./?/init.lua;"..package.path
local C=require("systems.creative_build")
local H=require("core.creative_build_hud")
local tests=0
local world={
 sample=function(_,x,y)return {height=0,walkable=x<200,feature=y>200 and "water" or nil} end,
 height=function(_,x,y)return x/64 end,
 obstacles=function()return {} end,
 is_protected=function(_,x,y)return x<-160 end
}
local c=C.new(world)
assert(#c.menu()==13)
assert(not c.active and c:toggle())
local camera={zoom=1,unproject=function(_,x,y,w,h)return x-w/2,y-h/2 end}
local ok=c:select(1);assert(ok)
assert(c:tap_world(180,180,camera,360,360))
local yes,a=c:preview();assert(yes and a.def_id=="tamu:foundation_wood")
assert(c:place())
assert(c:preview()==false)
assert(c.revision==1 and #c:snapshot().parts==1)
assert(#c:visible(camera,360,360)==1)
assert(c:undo());assert(#c:snapshot().parts==0)
assert(c:select(3));c.rotation=1
assert(c:tap_world(180,180,camera,360,360))
local yes,b=c:preview();assert(yes and b.rotation==1 and b.x%32==16)
assert(c:place())
assert(c:select(4));c.rotation=1
local can_place,reason=c:tap_world(180,180,camera,360,360)
assert(not can_place and reason=="occupied","different wall must be rejected")
assert(c:preview()==false,"different wall cannot occupy identical space")
assert(c:select(11));c.level=1
assert(c:tap_world(210,180,camera,360,360))
local valid,stair=c:preview();assert(valid and stair.z>24)
assert(c:place())
assert(c:snapshot().parts[2].def_id=="tamu:stairs_wood")
-- A neighbouring foundation snaps to the previously established elevation
-- even when 2.5D terrain sampling varies by several world units.
local slope={
 sample=function(_,x,y)return {walkable=true} end,
 height=function(_,x,y)return x*.1+y*.025 end,
 obstacles=function()return {} end
}
local pair=C.new(slope)
pair:toggle();assert(pair:select(1))
pair.target={x=0,y=0}
local ok,first=pair:preview();assert(ok and first.z==0)
assert(pair:place())
pair.target={x=32,y=0}
local ok,second=pair:preview();assert(ok and math.abs(second.z)<1e-8)
assert(pair:place())
pair:select(3);pair.target={x=0,y=16}
local ok,w=pair:preview();assert(ok and math.abs(w.z-6)<1e-8)
local h=H.new();local safe={x=0,y=0,w=360,h=780}
local controls=h:layout(safe,c)
local place
for _,item in ipairs(controls) do if item.id=="creative_place" then place=item end end
assert(place and h:hit(place.x+4,place.y+4,safe,c)=="creative_place")
local before=c.rotation
assert(h:action("creative_rotate",c) and c.rotation==(before+1)%4)
local n=c.level;assert(h:action("creative_level_up",c) and c.level==math.min(3,n+1))
assert(h:action("creative_toggle",c) and not c.active)
assert(not c:place())
print("TAMU_CREATIVE_CORE_OK 13 catalog, preview, placement, collision, undo, 3D height, touch HUD")
