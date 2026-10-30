package.path="./?.lua;./?/init.lua;"..package.path
local C=require("systems.creative_build")
local H=require("core.creative_build_hud")
local Renderer=require("systems.creative_build_renderer")
local Iso=require("world.iso")
local count=0
local function near(a,b,tol) assert(math.abs(a-b)<(tol or 1e-7),
  tostring(a).." vs "..tostring(b)) end
local world={
 sample=function(_,x,y) return {walkable=x<200,feature=y>200 and "water" or nil} end,
 height=function(_,x,y) count=count+1; return x/64 end,
 obstacles=function()return {} end,
 is_protected=function(_,x,y)return x<-160 end
}
local c=C.new(world)
assert(#c.menu()==13)
assert(c:toggle())
local camera={zoom=1,unproject=function(_,x,y,w,h)return x-w/2,y-h/2 end}
assert(c:select(3))
c.target={x=0,y=16}
local ok,why=c:preview()
assert(not ok and why=="needs_foundation","wall may not float without foundation")
assert(c:select(9));c.target={x=0,y=0}
ok,why=c:preview();assert(not ok and why=="needs_foundation",
  "roof is not free-standing")
assert(c:select(1))
assert(c:tap_world(180,180,camera,360,360))
local yes,a=c:preview()
assert(yes and a.def_id=="tamu:foundation_wood")
assert(a.z>0 and a.z<1 and #a.supports>=2)
for _,support in ipairs(a.supports) do
 assert(support.top==a.z and support.ground<a.z)
 assert(support.top-support.ground<=16)
end
assert(c:place())
assert(c:preview()==false)
assert(c.revision==1 and #c:snapshot().parts==1)
local sampled=count
assert(#c:visible(camera,360,360)==1)
assert(sampled==count,"render/visible must never resample terrain")
assert(c:select(2));c.target={x=0,y=0}
yes,a=c:preview();assert(yes and a.z>4)
assert(c:place())
-- Opposite wall faces must use different orientations and opposite edges.
assert(c:select(3))
for r=0,3 do
 c.rotation=r
 local x,y=c:target_xy(0,0)
 local expect={{0,16},{-16,0},{0,-16},{16,0}}
 near(x,expect[r+1][1]);near(y,expect[r+1][2])
 c.target={x=x,y=y}
 local valid,w=c:preview()
 assert(valid and w.rotation==r,"rotated wall on foundation edge")
 near(w.z,a.z+2) -- floor 4, wall 6 from foundation
end
c.rotation=1;c.target={x=-16,y=0}
yes,a=c:preview();assert(yes);assert(c:place())
assert(c:select(4));c.rotation=1;c.target={x=-16,y=0}
local can,reason=c:preview();assert(not can and reason=="occupied",
 "same wall slot must reject different panel")
assert(c:select(10));c.target={x=0,y=0}
can,reason=c:preview();assert(not can or reason~="needs_roof_support",
 "roof has supporting wall")
-- Unsupported upper slab should fail unless supported by a wall/post.
local solo=C.new(world);solo:toggle();solo:select(1)
solo.target={x=0,y=0};assert(solo:place())
solo:select(2);solo.level=1;solo.target={x=0,y=0}
can,reason=solo:preview()
assert(not can and reason=="needs_upper_support")
-- Height-matched foundations can extend downhill, with supporting posts.
local slope={
 sample=function(_,x,y)return {walkable=true} end,
 height=function(_,x,y) return x*.1+y*.025 end,
 obstacles=function()return {} end
}
local pair=C.new(slope)
pair:toggle();assert(pair:select(1))
pair.target={x=0,y=0}
local good,first=pair:preview();assert(good)
near(first.z,14*.1+14*.025)
assert(pair:place())
pair.target={x=-32,y=0}
local good,second=pair:preview();assert(good)
near(second.z,first.z)
assert(#second.supports>0 and second.supports[1].top==first.z)
assert(pair:place())
pair:select(3);pair.target={x=0,y=16}
local good,w=pair:preview();assert(good);near(w.z,first.z+6)
-- Neighbour uphill would penetrate the earth; must be rejected rather than
-- embedding into the hillside or silently moving the whole structure.
pair:select(1);pair.target={x=32,y=0}
can,reason=pair:preview()
assert(not can and reason=="terrain_intersects_foundation")
local too_steep=C.new({
 sample=function()return {walkable=true} end,
 height=function(_,x,y)return x end,
 obstacles=function()return {} end
})
too_steep:toggle();too_steep:select(1)
too_steep.target={x=0,y=0}
can,reason=too_steep:preview()
assert(not can and reason=="pier_too_long")
-- A fence remains free-standing and gets its own terrain-following legs.
local fence=C.new(slope)
fence:toggle();fence:select(12);fence.target={x=0,y=0}
good,w=fence:preview()
assert(good and #w.supports==1)
assert(w.supports[1].ground<w.supports[1].top)
-- Critical projection invariant: sprite art is 2px per ISO projected unit,
-- renderer draws at zoom/2. 32-world-unit diamond has exactly 2:1 slopes.
local project={zoom=1.8,x=0,y=0,project=function(_,x,y,w,h)
 local sx,sy=Iso.project(x,y)
 return w*.5+sx*1.8,h*.5+sy*1.8
end}
local s1,t1=Renderer.project(project,0,0,0,360,780)
local s2,t2=Renderer.project(project,32,0,0,360,780)
local s3,t3=Renderer.project(project,0,32,0,360,780)
near(s2-s1,-(s3-s1));near(t2-t1,t3-t1)
near(math.abs(s2-s1)/(t2-t1),2)
local sz,tz=Renderer.project(project,0,0,11,360,780)
near(sz,s1);near(tz,t1-11*project.zoom)
-- Mounted R2 camera has terrain-aware project/unproject. Creative renderer
-- must NOT call the already-height-corrected camera:project and subtract z.
local project_calls=0
local mounted={zoom=2,x=10,y=-8,_r2_mounted=true,
 project=function()
  project_calls=project_calls+1
  return -999,-999
 end,
 unproject=function(_,sx,sy,w,h)
  return 0,0
 end}
local px,py=Renderer.project(mounted,10,-8,7,360,780)
near(px,180);near(py,390-14)
assert(project_calls==0,"double R2 projection called camera:project")
local mount_world=C.new({
 sample=function()return {walkable=true} end,
 height=function()return 4 end,
 obstacles=function()return {} end
})
mount_world:toggle()
local inverse_calls=0
mounted.unproject=function()
 inverse_calls=inverse_calls+1
 return 0,0
end
local ok=mount_world:tap_world(180,390,mounted,360,780)
assert(ok and inverse_calls==1,
 "R2 camera:unproject already compensated ground; must be called once")
-- HUD remains pointer-safe in portrait.
local h=H.new();local safe={x=0,y=0,w=360,h=780}
local controls=h:layout(safe,c);local place
for _,b in ipairs(controls) do if b.id=="creative_place" then place=b end end
assert(place and h:hit(place.x+4,place.y+4,safe,c)=="creative_place")
local before=c.rotation
assert(h:action("creative_rotate",c) and c.rotation==(before+1)%4)
local lv=c.level
assert(h:action("creative_level_up",c) and c.level==math.min(3,lv+1))
assert(h:action("creative_toggle",c) and not c.active)
assert(not c:place())
print("TAMU_CREATIVE_GROUNDED_OK 13 kinds; zero floating support; 4 faces; 2:1 projection; touch")
