-- TAMU: continuous skeletal playback for the approved Rigby snapshot profile.
-- No frame baking, sprite strips or fixed animation sampling rate.
-- Semantics cross-checked against Rigby2D pose.js blob 07ee2d8da26a5a12df190943eb7812fbefb6c892.
-- Supported profile: FK transform timelines, per-component Beziers, regions,
-- weighted/unweighted meshes, slot visibility/color and draw order. The approved
-- 44 clips explicitly disable IK. Active IK/other constraints are rejected,
-- never silently ignored. Gameplay/collision/save state is not owned here.
local R={}; R.__index=R
local rad=math.pi/180
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function mix(a,b,t) return a+(b-a)*t end
local function copy(t) local r={} for k,v in pairs(t) do r[k]=v end return r end
local fields={"x","y","rotation","scale_x","scale_y","shear_x","shear_y"}
-- Immutable animation channel descriptors; do not allocate ten nested
-- descriptor tables for every animated bone on every rendered frame.
local channels={{"translate","x","y",false},{"scale","scale_x","scale_y",true},{"shear","shear_x","shear_y",false}}
local split={{"translateX","x"},{"translateY","y"},{"scaleX","scale_x"},
  {"scaleY","scale_y"},{"shearX","shear_x"},{"shearY","shear_y"}}
local default_color={1,1,1,1}
local function transform(b)
  return {x=b.x or 0,y=b.y or 0,rotation=b.rotation or 0,
    scale_x=b.scale_x or 1,scale_y=b.scale_y or 1,
    shear_x=b.shear_x or 0,shear_y=b.shear_y or 0}
end
local function matrix(t,out)
  local x=(t.rotation+t.shear_x)*rad; local y=(t.rotation+90+t.shear_y)*rad
  out.a=math.cos(x)*t.scale_x; out.b=math.sin(x)*t.scale_x
  out.c=math.cos(y)*t.scale_y; out.d=math.sin(y)*t.scale_y
  out.tx=t.x; out.ty=t.y
  return out
end
local function mul(p,q,o)
  local a,b,c,d=p.a*q.a+p.c*q.b,p.b*q.a+p.d*q.b,p.a*q.c+p.c*q.d,p.b*q.c+p.d*q.d
  local x,y=p.a*q.tx+p.c*q.ty+p.tx,p.b*q.tx+p.d*q.ty+p.ty
  o.a,o.b,o.c,o.d,o.tx,o.ty=a,b,c,d,x,y
  return o
end
local function point(m,x,y) return m.a*x+m.c*y+m.tx,m.b*x+m.d*y+m.ty end
local function cubic(a,b,t) local v=1-t;return 3*v*v*t*a+3*v*t*t*b+t*t*t end
local function deriv(a,b,t) return 3*(1-t)^2*a+6*(1-t)*t*(b-a)+3*t*t*(1-b) end
function R.ease(curve,t,component)
  t=clamp(t,0,1)
  if curve=="stepped" then return 0 end
  local c=type(curve)=="table" and (curve.bezier or
    (curve.beziers and (curve.beziers[component or 1] or curve.beziers[1])))
  if not c then return t end
  local x1,y1,x2,y2=clamp(c[1],0,1),c[2],clamp(c[3],0,1),c[4]
  local u=t
  for _=1,8 do
    local e=cubic(x1,x2,u)-t
    if math.abs(e)<1e-5 then return cubic(y1,y2,u) end
    local d=deriv(x1,x2,u)
    if math.abs(d)<1e-6 then break end
    u=clamp(u-e/d,0,1)
  end
  local lo,hi=0,1;u=t
  for _=1,30 do
    local x=cubic(x1,x2,u)
    if math.abs(x-t)<1e-5 then break end
    if x<t then lo=u else hi=u end
    u=(lo+hi)*.5
  end
  return cubic(y1,y2,u)
end
local function key_index(keys,t)
  local lo,hi=1,#keys
  while lo<=hi do local m=math.floor((lo+hi)/2)
    if keys[m].time<=t then lo=m+1 else hi=m-1 end
  end
  return hi
end
-- Shared accessor avoids allocating a closure for every keyed channel sample.
local function sample_value(k,c)
  return c and type(k.value)=="table" and k.value[c] or k.value
end
function R.sample(keys,t,c)
  if not keys or #keys==0 then return nil end
  if t<=keys[1].time then return sample_value(keys[1],c) end
  local at=key_index(keys,t);local a,b=keys[at],keys[at+1]
  if not b then return sample_value(a,c) end
  local v,w=sample_value(a,c),sample_value(b,c)
  if type(v)~="number" then return v end
  return mix(v,w,R.ease(a.curve,(t-a.time)/(b.time-a.time),c))
end
local function order_for(count,offsets)
  local order={};if not offsets or #offsets==0 then for i=1,count do order[i]=i end;return order end
  local keys={}; for i,k in ipairs(offsets) do keys[i]=k end
  table.sort(keys,function(a,b)return a.slot<b.slot end)
  local remaining={};local original=1
  for _,k in ipairs(keys) do
    local slot=k.slot+1
    assert(slot>=original and slot<=count,"invalid draw-order slot")
    while original<slot do remaining[#remaining+1]=original;original=original+1 end
    local target=original+k.offset
    if target>=1 and target<=count and not order[target] then order[target]=original
    else remaining[#remaining+1]=original end
    original=original+1
  end
  while original<=count do remaining[#remaining+1]=original;original=original+1 end
  for i=count,1,-1 do if not order[i] then order[i]=table.remove(remaining) end end
  return order
end
local supported={bone=true,rotate=true,translate=true,scale=true,shear=true,
  translateX=true,translateY=true,scaleX=true,scaleY=true,shearX=true,shearY=true,inherit=true}
local function validate_keys(keys,duration)
  local previous=-math.huge
  for _,k in ipairs(keys) do
    assert(finite(k.time) and k.time>=0 and k.time<=duration+1e-8 and k.time>previous,"invalid key time")
    previous=k.time
    if type(k.value)=="number" then assert(finite(k.value),"invalid key value") end
    local c=k.curve
    if type(c)=="table" then
      local curves=c.beziers or {c.bezier}
      assert(#curves>0,"unsupported curve")
      for _,b in ipairs(curves) do
        assert(#b==4,"invalid Bezier")
        for _,n in ipairs(b) do assert(finite(n),"invalid Bezier component") end
      end
    else assert(c==nil or c=="linear" or c=="stepped","unsupported curve") end
  end
end
function R.new(data)
  assert(data.format=="tamu-rigby-fk/1","unsupported runtime rig format")
  local self=setmetatable({data=data,bones=data.bones,slots=data.slots,
    animations={},bone_ids={},local_pose={},world={},attachment={},colors={},geometry={},scratch={},
    draw_order={},vertices={},evaluations=0},R)
  for i,b in ipairs(self.bones) do
    assert(not self.bone_ids[b.name],"duplicate bone name")
    self.bone_ids[b.name]=i
    assert(b.parent==nil or b.parent==false or
      (b.parent>=0 and b.parent<i-1 and b.parent%1==0),"bones must be topologically ordered")
    b._setup=transform(b)
    for _,f in ipairs(fields) do assert(finite(b._setup[f]),"invalid bone transform") end
    self.local_pose[i]=copy(b._setup);self.world[i]={}
    assert(({normal=true,onlyTranslation=true,noScale=true,noScaleOrReflection=true,
      noRotationOrReflection=true})[b.inherit or "normal"],"unsupported inheritance")
  end
  self.base_order=order_for(#self.slots)
  for i,s in ipairs(self.slots) do
    assert(self.bones[s.bone+1],"invalid slot bone")
    self.colors[i]={1,1,1,1};self.geometry[i]={}
    assert(not s.blend or s.blend=="normal","unsupported blend mode")
    for _,a in ipairs(s.attachments) do
      local g={image=a.image or a.name,slot=i,attachment=a.name,
        source=a,kind=a.type or "region",vertices={},triangles={},local_matrix=matrix(transform(a),{}),positions={}}
      if g.kind=="region" then
        assert(finite(a.width) and finite(a.height) and a.width>0 and a.height>0,"invalid region size")
        local w,h=a.width/2,a.height/2
        g.local_points={{-w,h},{w,h},{w,-h},{-w,-h}}
        g.uvs={{0,0},{1,0},{1,1},{0,1}};g.triangles={1,2,3,1,3,4}
      else
        assert(g.kind=="mesh" and #a.uvs%2==0,"unsupported attachment type")
        g.uvs={};for n=1,#a.uvs,2 do g.uvs[#g.uvs+1]={a.uvs[n],a.uvs[n+1]} end
        for _,n in ipairs(a.triangles) do
          assert(n>=0 and n<#g.uvs and n%1==0,"invalid triangle index")
          g.triangles[#g.triangles+1]=n+1
        end
        if a.weights then
          assert(#a.weights==#g.uvs,"weight/UV length mismatch")
          for _,v in ipairs(a.weights) do
            local sum=0
            for _,w in ipairs(v) do
              assert(self.bones[w.bone+1] and finite(w.x) and finite(w.y) and finite(w.weight) and w.weight>=0,"invalid influence")
              sum=sum+w.weight
            end
            assert(math.abs(sum-1)<1e-5,"weights not normalized")
          end
        else assert(a.vertices and #a.vertices==#a.uvs,"vertex/UV mismatch") end
      end
      for n,uv in ipairs(g.uvs) do
        g.vertices[n]={0,0,uv[1],uv[2],1,1,1,1};g.positions[n]={0,0}
      end
      self.geometry[i][a.name]=g
    end
  end
  for _,a in ipairs(data.animations) do
    assert(type(a.name)=="string" and not self.animations[a.name] and finite(a.duration) and a.duration>0,"invalid animation")
    assert(not a.deform or #a.deform==0,"deform timelines outside this profile")
    assert(not a.extra or next(a.extra)==nil,"extra constraints outside this profile")
    for _,tl in ipairs(a.bones or {}) do
      assert(self.bones[tl.bone+1],"invalid timeline bone")
      for ch,keys in pairs(tl) do
        assert(supported[ch],"unsupported bone channel: "..ch)
        if ch~="bone" then validate_keys(keys,a.duration) end
      end
    end
    local disabled={}
    for _,tl in ipairs(a.ik or {}) do
      validate_keys(tl.keys,a.duration)
      assert(tl.keys[1] and tl.keys[1].time==0,"IK profile must be explicit from time zero")
      for _,k in ipairs(tl.keys) do assert(k.value.mix==0,"active IK outside approved FK profile") end
      disabled[tl.constraint+1]=true
    end
    for n,ik in ipairs(data.ik or {}) do assert((ik.mix or 1)==0 or disabled[n],"unhandled setup IK") end
    for _,tl in ipairs(a.slots or {}) do
      assert(self.slots[tl.slot+1],"invalid timeline slot")
      for ch,keys in pairs(tl) do
        assert(ch=="slot" or ch=="attachment" or ch=="color" or ch=="alpha","unsupported slot channel")
        if ch~="slot" then validate_keys(keys,a.duration) end
      end
      for _,k in ipairs(tl.attachment or {}) do
        assert(k.value==false or self.geometry[tl.slot+1][k.value],"missing attachment")
      end
    end
    for _,k in ipairs(a.drawOrder or {}) do k._order=order_for(#self.slots,k.value) end
    self.animations[a.name]=a
  end
  return self
end
function R:update_world()
  for i,b in ipairs(self.bones) do
    local m=matrix(self.local_pose[i],self.scratch)
    local out=self.world[i]
    if b.parent==nil or b.parent==false then
      for k,v in pairs(m) do out[k]=v end
    else
      local p=self.world[b.parent+1];local mode=b.inherit or "normal"
      if mode=="normal" then mul(p,m,out)
      else
        local x,y=point(p,m.tx,m.ty)
        local a,bb,c,d=1,0,0,1
        if mode=="noRotationOrReflection" then
          a=math.sqrt(p.a*p.a+p.b*p.b);d=a>1e-12 and math.abs(p.a*p.d-p.b*p.c)/a or 0
        elseif mode=="noScale" or mode=="noScaleOrReflection" then
          local len=math.sqrt(p.a*p.a+p.b*p.b)
          a=len>1e-12 and p.a/len or 1;bb=len>1e-12 and p.b/len or 0
          local sign=mode=="noScale" and p.a*p.d-p.b*p.c<0 and -1 or 1
          c=-bb*sign;d=a*sign
        end
        out.a=a*m.a+c*m.b;out.b=bb*m.a+d*m.b
        out.c=a*m.c+c*m.d;out.d=bb*m.c+d*m.d;out.tx=x;out.ty=y
      end
    end
  end
end
function R:evaluate(name,time,looped,offsets)
  local a=assert(self.animations[name],"unknown rig animation: "..tostring(name))
  assert(finite(time),"invalid animation time")
  local t=looped and time%a.duration or clamp(time,0,a.duration)
  for i,b in ipairs(self.bones) do for _,f in ipairs(fields) do self.local_pose[i][f]=b._setup[f] end end
  for i,s in ipairs(self.slots) do
    self.attachment[i]=s.attachment or false
    local col=s.color or default_color
    for c=1,4 do self.colors[i][c]=col[c] end
  end
  for _,tl in ipairs(a.bones or {}) do
    local l=self.local_pose[tl.bone+1];local s=self.bones[tl.bone+1]._setup
    local v=R.sample(tl.rotate,t,1);if v~=nil then l.rotation=s.rotation+v end
    for _,ch in ipairs(channels) do for c=1,2 do
      local n=R.sample(tl[ch[1]],t,c);local f=ch[c+1]
      if n~=nil then l[f]=ch[4] and s[f]*n or s[f]+n end
    end end
    for _,ch in ipairs(split) do local n=R.sample(tl[ch[1]],t,1)
      if n~=nil then l[ch[2]]=ch[1]:sub(1,5)=="scale" and s[ch[2]]*n or s[ch[2]]+n end
    end
    assert(not tl.inherit or #tl.inherit==0,"animated inheritance outside this profile")
  end
  for _,tl in ipairs(a.slots or {}) do
    local v=R.sample(tl.attachment,t)
    if v~=nil then self.attachment[tl.slot+1]=v end
    for c=1,4 do local n=R.sample(tl.color,t,c);if n~=nil then self.colors[tl.slot+1][c]=n end end
    v=R.sample(tl.alpha,t,1);if v~=nil then self.colors[tl.slot+1][4]=v end
  end
  self.draw_order=self.base_order
  local at=a.drawOrder and key_index(a.drawOrder,t) or 0
  if at>0 then self.draw_order=a.drawOrder[at]._order end
  if offsets then for name,v in pairs(offsets) do
    local i=assert(self.bone_ids[name],"unknown procedural bone override")
    for _,f in ipairs(fields) do if v[f]~=nil then
      assert(finite(v[f]),"invalid procedural offset")
      local p=self.local_pose[i]
      p[f]=(f=="scale_x" or f=="scale_y") and p[f]*v[f] or p[f]+v[f]
    end end
  end end
  self:update_world();self.evaluations=self.evaluations+1
  self.animation=name;self.time=t
  return self
end
function R:capture()
  local out={} for i,v in ipairs(self.local_pose) do out[i]=copy(v) end return out
end
function R:blend_from(previous,alpha)
  alpha=clamp(alpha,0,1)
  for i,p in ipairs(self.local_pose) do
    local old=previous[i]
    for _,f in ipairs(fields) do
      -- Never cross zero scale when a mirrored facing is selected.
      if not ((f=="scale_x" or f=="scale_y") and old[f]*p[f]<0) then p[f]=mix(old[f],p[f],alpha) end
    end
  end
  self:update_world()
end
function R:quads()
  local out=self.vertices
  for i=#out,1,-1 do out[i]=nil end
  for _,s in ipairs(self.draw_order) do
    local name=self.attachment[s];local g=name and self.geometry[s][name]
    if g then
      local a=g.source;local col=self.colors[s]
      local m
      if g.kind=="region" then m=mul(self.world[self.slots[s].bone+1],g.local_matrix,self.scratch) end
      for n,v in ipairs(g.vertices) do
        local x,y=0,0
        if m then x,y=point(m,g.local_points[n][1],g.local_points[n][2])
        elseif a.weights then
          for _,w in ipairs(a.weights[n]) do local xx,yy=point(self.world[w.bone+1],w.x,w.y)
            x=x+xx*w.weight;y=y+yy*w.weight
          end
        else x,y=point(self.world[self.slots[s].bone+1],a.vertices[2*n-1],a.vertices[2*n]) end
        v[1],v[2]=x,y;g.positions[n][1],g.positions[n][2]=x,y
        for c=1,4 do v[c+4]=col[c]*(a.color and a.color[c] or 1) end
      end
      out[#out+1]=g
    end
  end
  return out
end
function R:socket(name,x,y)
  local m=assert(self.world[assert(self.bone_ids[name],"unknown socket bone")])
  local px,py=point(m,x or 0,y or 0)
  return {x=px,y=py,a=m.a,b=m.b,c=m.c,d=m.d,determinant=m.a*m.d-m.b*m.c}
end
return R
