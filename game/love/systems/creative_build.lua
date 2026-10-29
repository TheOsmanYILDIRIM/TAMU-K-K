-- Session-only Creative construction. No Stage5 inventory debit or Stage6 writes.
-- Uses canonical part definitions and a sparse spatial hash; later gameplay can
-- wrap place/remove in authoritative transactions without rewriting rendering.
local Parts=require("systems.building_parts")
local Spatial=require("systems.building_spatial")
local C={};C.__index=C
local CELL=32
local ORDER={
 {id="tamu:foundation_wood",label="TEMEL",shape="foundation"},
 {id="tamu:floor_wood",label="ZEMIN",shape="floor"},
 {id="tamu:wall_wood",label="DUVAR",shape="wall"},
 {id="tamu:window_wood",label="PENCERE",shape="window"},
 {id="tamu:doorway_wood",label="KAPI",shape="doorway"},
 {id="tamu:halfwall_wood",label="YARIM DUVAR",shape="halfwall"},
 {id="tamu:railing_wood",label="KORKULUK",shape="railing"},
 {id="tamu:post_wood",label="DIREK",shape="post"},
 {id="tamu:roof_flat_wood",label="DUZ CATI",shape="roof_flat"},
 {id="tamu:roof_slope_wood",label="EGIMLI CATI",shape="roof_slope"},
 {id="tamu:stairs_wood",label="MERDIVEN",shape="stairs"},
 {id="tamu:fence_wood",label="CIT",shape="fence"},
 {id="tamu:fence_gate_wood",label="CIT KAPISI",shape="fence_gate"}}
local function finite(n)return type(n)=="number" and n==n and math.abs(n)<math.huge end
local function round(n,spacing)return math.floor(n/spacing+.5)*spacing end
local function rotated(w,d,r)if r%2==1 then return d,w end return w,d end
local function overlaps(a,b)
 local e=1e-6
 return a.x<b.x+b.w-e and b.x<a.x+a.w-e and
  a.y<b.y+b.h-e and b.y<a.y+a.h-e and
  a.z<b.z+b.d-e and b.z<a.z+a.d-e
end
function C.menu()return ORDER end
function C.new(world)
 assert(type(world)=="table" and type(world.sample)=="function"
  and type(world.height)=="function","creative terrain adapter required")
 local self=setmetatable({world=world,index=Spatial.new(64),items={},order={},
   active=false,selected=1,page=1,rotation=0,level=0,target=nil,
   revision=0,sequence=0,message="CREATIVE OFF"},C)
 return self
end
function C:current()return ORDER[self.selected] end
function C:toggle()
 self.active=not self.active
 self.target=nil
 self.message=self.active and "Tap ground to preview" or "Creative closed"
 return self.active
end
function C:select(i)
 if i~=math.floor(i) or not ORDER[i] then return false,"invalid_piece" end
 self.selected=i;self.rotation=0;self.target=nil
 self.message=ORDER[i].label.." selected"
 return true,self.message
end
function C:target_xy(wx,wy)
 local kind=self:current().shape
 local x,y=round(wx,CELL),round(wy,CELL)
 -- Linear pieces are mounted exactly on the edge of a 32-unit floor cell.
 if kind=="wall" or kind=="window" or kind=="doorway" or kind=="halfwall"
  or kind=="railing" or kind=="fence" or kind=="fence_gate" then
  if self.rotation%2==0 then y=y+CELL/2 else x=x+CELL/2 end
 end
 return x,y
end
function C:ground(x,y)
 local s=self.world:sample(x,y)
 if not s or s.walkable==false or s.feature=="water" or s.feature=="river"
  or (self.world.is_protected and self.world:is_protected(x,y)) then
  return nil,"unsafe_surface" end
 local h=self.world:height(x,y)
 if not finite(h) then return nil,"missing_height" end
 return h
end
function C:tap_world(sx,sy,camera,w,h)
 assert(finite(sx) and finite(sy),"screen point required")
 -- Iterative screen -> world reconstruction at measured terrain elevation.
 -- Iso projection subtracts z from screen Y; no raster scanning.
 local wx,wy=camera:unproject(sx,sy,w,h)
 for _=1,3 do
   local z=self.world:height(wx,wy)
   if not finite(z) then return false,"missing_height" end
   wx,wy=camera:unproject(sx,sy+(camera.zoom or 1)*z,w,h)
 end
 local x,y=self:target_xy(wx,wy)
 self.target={x=x,y=y}
 local ok,why=self:preview()
 self.message=ok and "Ready: PLACE" or why
 return ok,why
end
function C:pose()
 local target=self.target
 if not target then return nil,"tap_ground" end
 local ground,why=self:ground(target.x,target.y)
 if not ground then return nil,why end
 local kind=self:current().shape
 local delta=0
 if kind=="floor" then delta=4
 elseif kind=="wall" or kind=="window" or kind=="doorway" or
  kind=="halfwall" or kind=="railing" or kind=="post" then delta=6
 elseif kind=="roof_slope" or kind=="roof_flat" then delta=30
 elseif kind=="stairs" then delta=6 end
 return {x=target.x,y=target.y,z=ground+delta+self.level*24,
   rotation=self.rotation,ground=ground}
end
function C:preview()
 local pose,why=self:pose()
 if not pose then return false,why end
 local item=self:current();local def=assert(Parts.get(item.id))
 local sw,sd=rotated(def.size[1],def.size[2],pose.rotation)
 local box={x=pose.x-sw/2,y=pose.y-sd/2,w=sw,h=sd,z=pose.z,d=def.size[3]}
 -- Footprint corners must be safe; never modify the terrain.
 if self.level==0 and (item.shape=="foundation" or item.shape=="fence"
   or item.shape=="fence_gate") then
  for _,dx in ipairs({-sw/2+1,sw/2-1}) do
   for _,dy in ipairs({-sd/2+1,sd/2-1}) do
    local h,err=self:ground(pose.x+dx,pose.y+dy)
    if not h then return false,err end
    if math.abs(h-pose.ground)>16 then return false,"steep_ground" end
   end
  end
 end
 for _,existing in ipairs(self.index:query(box)) do
  if overlaps(box,existing.box) then return false,"occupied" end
 end
 if self.level==0 and self.world.obstacles and pose.z<=pose.ground+6 then
  for _,o in ipairs(self.world:obstacles(box.x,box.y,box.x+box.w,box.y+box.h)) do
   if o.w and o.h and box.x<o.x+o.w and o.x<box.x+box.w and
    box.y<o.y+o.h and o.y<box.y+box.h then return false,"world_obstacle" end
  end
 end
 return true,{x=pose.x,y=pose.y,z=pose.z,rotation=pose.rotation,
  def_id=item.id,shape=item.shape,box=box,status="built",owner="player:creative"}
end
function C:place()
 if not self.active then return false,"creative_closed" end
 local ok,p=self:preview()
 if not ok then self.message=p;return false,p end
 self.sequence=self.sequence+1
 p.id="creative:"..self.sequence
 self.items[p.id]=p
 self.order[#self.order+1]=p.id
 self.index:insert(p.id,p.box,p)
 self.revision=self.revision+1
 self.message="Placed "..self:current().label
 return true,p
end
function C:undo()
 local id=self.order[#self.order]
 if not id then self.message="Nothing to undo";return false,"empty" end
 self.order[#self.order]=nil
 self.index:remove(id);self.items[id]=nil
 self.revision=self.revision+1;self.message="Removed last piece"
 return true,id
end
function C:visible(camera,w,h)
 -- Small camera-space query, not an O(n) scan of all buildings each frame.
 local corners={{0,0},{w,0},{0,h},{w,h}}
 local minx,maxx,miny,maxy=math.huge,-math.huge,math.huge,-math.huge
 for _,p in ipairs(corners) do
  local x,y=camera:unproject(p[1],p[2],w,h)
  minx=math.min(minx,x);maxx=math.max(maxx,x)
  miny=math.min(miny,y);maxy=math.max(maxy,y)
 end
 local q={x=minx-256,y=miny-256,w=maxx-minx+512,h=maxy-miny+512}
 -- Spatial imposes bounded bucket work. Oversize viewports: use coarse
 -- paged 256-unit queries rather than all-world traversal.
 local seen,out={},{}
 local step=256
 for y=q.y,q.y+q.h,step do
  for x=q.x,q.x+q.w,step do
   local slice={x=x,y=y,w=math.min(step,q.x+q.w-x),h=math.min(step,q.y+q.h-y)}
   if slice.w>0 and slice.h>0 then
    for _,p in ipairs(self.index:query(slice)) do
     if not seen[p.id] then seen[p.id]=true;out[#out+1]=p end
    end
   end
  end
 end
 table.sort(out,function(a,b)
  local az=a.x+a.y+a.z*.001;local bz=b.x+b.y+b.z*.001
  return az<bz or (az==bz and a.id<b.id)
 end)
 return out
end
function C:snapshot()
 local rows={}
 for _,id in ipairs(self.order) do
  local p=self.items[id]
  rows[#rows+1]={id=p.id,def_id=p.def_id,x=p.x,y=p.y,z=p.z,
   rotation=p.rotation,owner=p.owner,status="built"}
 end
 return {version=1,revision=self.revision,sequence=self.sequence,parts=rows}
end
return C
