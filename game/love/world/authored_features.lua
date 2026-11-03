-- R2 C: deterministic, author-intent polyline geometry. No Generator v1 mutation.
-- Input must ALSO pass the canonical Python worldbuild validators before activation.
local M = {}
M.__index = M
local EPS = 1e-7

local function finite(n)
  return type(n) == "number" and n == n and n > -math.huge and n < math.huge
end
local function point(p)
  return type(p) == "table" and finite(p[1]) and finite(p[2])
end
local function position(x,y)
  assert(finite(x) and finite(y), "invalid world-space coordinates")
end
local function measure(f,x,y)
  local best
  for i=1,#f.points-1 do
    local a,b=f.points[i],f.points[i+1]
    local vx,vy=b[1]-a[1],b[2]-a[2]
    local length2=vx*vx+vy*vy
    local t=math.max(0,math.min(1,((x-a[1])*vx+(y-a[2])*vy)/length2))
    local px,py=a[1]+t*vx,a[2]+t*vy
    local d=math.sqrt((x-px)^2+(y-py)^2)
    if not best or d<best.distance-EPS then
      local length=math.sqrt(length2)
      best={id=f.id,kind=f.kind,width=f.width,feature=f,
        segment_index=i,t=t,distance=d,signed=f.width/2-d,
        projection_x=px,projection_y=py,tx=vx/length,ty=vy/length}
    end
  end
  return best
end
local function intersection(a,b,c,d)
  local rx,ry=b[1]-a[1],b[2]-a[2]
  local sx,sy=d[1]-c[1],d[2]-c[2]
  local denominator=rx*sy-ry*sx
  local l1,l2=math.sqrt(rx*rx+ry*ry),math.sqrt(sx*sx+sy*sy)
  if math.abs(denominator)<EPS*l1*l2 then return nil end -- no parallel fake crossings
  local qx,qy=c[1]-a[1],c[2]-a[2]
  local t=(qx*sy-qy*sx)/denominator
  local u=(qx*ry-qy*rx)/denominator
  if t< -EPS or t>1+EPS or u< -EPS or u>1+EPS then return nil end
  t=math.max(0,math.min(1,t))
  return {x=a[1]+rx*t,y=a[2]+ry*t,
    path_tx=rx/l1,path_ty=ry/l1,water_tx=sx/l2,water_ty=sy/l2,
    sine=math.abs(denominator)/(l1*l2)}
end

function M.new(map)
  assert(type(map)=="table" and map.format=="osman-worldbuild-v1"
    and map.schema_version==1 and map.generator_version==1
    and map.coordinate_space=="world" and map.projection=="iso-45"
    and finite(map.seed) and map.seed==math.floor(map.seed)
    and type(map.map_id)=="string" and
    type(map.features)=="table" and #map.features<=128,
    "validated R2 authored map required")
  local result,used={},{}
  for _,f in ipairs(map.features) do
    assert(type(f)=="table" and type(f.id)=="string"
      and f.id:match("^feature:[a-z][a-z0-9%-]+$")
      and not used[f.id] and (f.kind=="water" or f.kind=="path")
      and f.intent_only==true and finite(f.width) and f.width>0 and f.width<=64
      and type(f.points)=="table" and #f.points>=2 and #f.points<=96,
      "invalid/duplicate authored feature")
    used[f.id]=true
    local copy={id=f.id,kind=f.kind,width=f.width,points={}}
    for _,p in ipairs(f.points) do
      assert(point(p),"invalid authored feature point")
      copy.points[#copy.points+1]={p[1],p[2]}
    end
    for i=2,#copy.points do
      local a,b=copy.points[i-1],copy.points[i]
      local dx,dy=b[1]-a[1],b[2]-a[2]
      assert(dx*dx+dy*dy>EPS*EPS,"zero-length authored segment")
    end
    result[#result+1]=copy
  end
  table.sort(result,function(a,b) return a.id<b.id end)
  return setmetatable({map_id=map.map_id,seed=map.seed,generator_version=1,
    features=result,by_id=(function()
      local d={} for _,f in ipairs(result) do d[f.id]=f end return d
    end)()},M)
end

function M:nearest(x,y,kind)
  position(x,y)
  assert(kind=="path" or kind=="water","invalid feature kind")
  local best
  for _,f in ipairs(self.features) do
    if f.kind==kind then
      local hit=measure(f,x,y)
      if not best or hit.signed>best.signed+EPS or
        (math.abs(hit.signed-best.signed)<=EPS and hit.id<best.id) then
        best=hit
      end
    end
  end
  return best
end
function M:signed(x,y,kind)
  local hit=self:nearest(x,y,kind)
  return hit and hit.signed or -math.huge
end
function M:at(x,y,kind)
  local hit=self:nearest(x,y,kind)
  return hit and hit.signed>0 and hit or nil
end

function M:intersections()
  local out,seen={},{}
  for _,p in ipairs(self.features) do if p.kind=="path" then
    for _,w in ipairs(self.features) do if w.kind=="water" then
      for i=1,#p.points-1 do for j=1,#w.points-1 do
        local c=intersection(p.points[i],p.points[i+1],
                             w.points[j],w.points[j+1])
        if c then
          local key=p.id.."|"..w.id.."|"..string.format("%.7f:%.7f",c.x,c.y)
          if not seen[key] then
            seen[key]=true
            c.path_feature_id=p.id;c.water_feature_id=w.id
            c.path_segment=i;c.water_segment=j
            out[#out+1]=c
          end
        end
      end end
    end end
  end end
  table.sort(out,function(a,b)
    if a.path_feature_id~=b.path_feature_id then
      return a.path_feature_id<b.path_feature_id end
    if a.water_feature_id~=b.water_feature_id then
      return a.water_feature_id<b.water_feature_id end
    if a.x~=b.x then return a.x<b.x end
    return a.y<b.y
  end)
  return out
end

function M:crossing_site_status(site)
  assert(type(site)=="table" and type(site.id)=="string"
    and point(site.anchor),"crossing site/anchor required")
  local x,y=site.anchor[1],site.anchor[2]
  local hit=self:nearest(x,y,"water")
  local bank_gap=hit and math.max(0,-hit.signed) or math.huge
  if site.role~="crossing" then
    return {valid=false,reason="not_crossing_site",water_bank_gap=bank_gap}
  end
  for _,c in ipairs(self:intersections()) do
    if math.sqrt((c.x-x)^2+(c.y-y)^2)<=0.25 and c.sine>=0.15 then
      return {valid=true,reason="verified_intersection",
        water_bank_gap=0,intersection=c}
    end
  end
  return {valid=false,reason="no_path_water_intersection",
    water_bank_gap=bank_gap}
end

-- Explicit approval and exact centerline intersection are required for each crossing.
-- Fords are allowed only if the AUTHORED depth model is actually shallow.
function M:resolve_crossings(sites,declared,max_depth,max_ford_depth)
  assert(type(sites)=="table" and type(declared)=="table"
    and finite(max_depth) and max_depth>0
    and finite(max_ford_depth) and max_ford_depth>0,
    "invalid crossing configuration")
  local site_by_id,used,used_sites={}, {}, {}
  for _,site in ipairs(sites) do
    assert(type(site)=="table" and type(site.id)=="string"
      and point(site.anchor) and not site_by_id[site.id],"invalid crossing site list")
    site_by_id[site.id]=site
  end
  local geometries=self:intersections()
  local result={}
  for _,c in ipairs(declared) do
    assert(type(c)=="table" and type(c.id)=="string"
      and c.id:match("^crossing:[a-z][a-z0-9%-]+$")
      and not used[c.id] and not used_sites[c.site_id]
      and (c.kind=="bridge" or c.kind=="ford")
      and type(c.path_feature_id)=="string"
      and type(c.water_feature_id)=="string"
      and finite(c.width) and c.width>0 and c.width<=64,
      "invalid/duplicate crossing")
    local site=site_by_id[c.site_id]
    local path=self.by_id[c.path_feature_id]
    local water=self.by_id[c.water_feature_id]
    assert(site and site.role=="crossing" and path and path.kind=="path"
      and water and water.kind=="water" and c.width<=path.width,
      "crossing requires valid path/water/crossing site")
    local matched
    for _,g in ipairs(geometries) do
      local dx,dy=site.anchor[1]-g.x,site.anchor[2]-g.y
      if g.path_feature_id==c.path_feature_id
        and g.water_feature_id==c.water_feature_id
        and dx*dx+dy*dy<=0.25*0.25 and g.sine>=0.15 then
        matched=g;break
      end
    end
    assert(matched,"crossing site does not intersect water and path")
    local length
    if c.kind=="bridge" then
      length=c.length
      assert(finite(length) and length>=water.width/matched.sine+4
        and length<=256,"bridge does not span both stream banks")
    else
      assert(max_depth<=max_ford_depth,
        "ford requires verified shallow authored water depth")
      assert(c.length==nil,"ford length is not a bridge deck")
      length=water.width/matched.sine+4
    end
    used[c.id]=true;used_sites[c.site_id]=true
    result[#result+1]={id=c.id,kind=c.kind,site_id=c.site_id,
      path_feature_id=c.path_feature_id,water_feature_id=c.water_feature_id,
      x=matched.x,y=matched.y,tx=matched.path_tx,ty=matched.path_ty,
      width=c.width,length=length}
  end
  table.sort(result,function(a,b) return a.id<b.id end)
  return result
end

return M
