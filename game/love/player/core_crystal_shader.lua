-- Crystal pulse V3: isolated LÖVE shader, not wired into the world renderer.
-- Exactly one approved base PNG and one aligned mask; no spritesheet/video runtime.
local M={}
local source=[[
extern Image mask_tex;
extern number time_seconds;
extern number strength;
extern vec2 crystal_center;
extern vec2 crystal_extent;
extern vec3 emission_color;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 xy) {
  vec4 base = Texel(tex,uv) * color;
  float selection = Texel(mask_tex,uv).r;
  // Keep metal unchanged outside mask. Edge noise is restricted to the feather.
  float feather = smoothstep(0.02,0.98,selection);
  vec2 rel = (uv-crystal_center) / max(crystal_extent,vec2(0.0001));
  float radial = pow(max(0.0,1.0-length(rel)),0.55);
  float wave = sin(uv.x*488.0+time_seconds*2.5) *
               sin(uv.y*376.0-time_seconds*1.7);
  float edge = clamp(1.0+0.10*wave*(1.0-feather),0.88,1.12);
  float pulse = 0.58+0.42*(0.5-0.5*cos(time_seconds*6.28318530718/2.08));
  float energy = clamp(strength*feather*(0.30+0.70*radial)*edge*pulse,0.0,1.0);
  vec3 emission=clamp(emission_color*energy,0.0,1.0);
  // Blend within the original texel (screen-dominant and modest additive).
  // Source alpha unchanged, avoiding a separate additive draw call.
  vec3 screen_rgb=1.0-(1.0-base.rgb)*(1.0-emission);
  vec3 additive_rgb=min(vec3(1.0),base.rgb+emission*(0.38+0.32*radial));
  vec3 rgb=mix(screen_rgb,additive_rgb,0.38);
  return vec4(rgb,base.a);
}
]]

local function expected_dimension(base,mask)
  return base:getWidth()==mask:getWidth() and base:getHeight()==mask:getHeight()
end

function M.new(base,mask,options)
  assert(base and mask,"core and single mask are required")
  assert(expected_dimension(base,mask),"core/mask dimensions must match")
  options=options or {}
  local shader=love.graphics.newShader(source)
  shader:send("mask_tex",mask)
  shader:send("strength",options.strength or 1)
  shader:send("emission_color",options.color or {0.55,0.9,1})
  local w,h=base:getDimensions()
  local center=options.center_px or {776.43,667.31}
  local extent=options.extent_px or {150,170}
  shader:send("crystal_center",{center[1]/w,center[2]/h})
  shader:send("crystal_extent",{extent[1]/w,extent[2]/h})
  return {base=base,mask=mask,shader=shader}
end

function M.draw(instance,x,y,rotation,sx,sy,ox,oy,seconds,alpha)
  assert(instance and instance.shader,"valid crystal effect required")
  local g=love.graphics
  g.push("all")
  g.setColor(1,1,1,alpha or 1)
  g.setBlendMode("alpha","alphamultiply")
  g.setShader(instance.shader)
  instance.shader:send("time_seconds",seconds or 0)
  g.draw(instance.base,x,y,rotation or 0,sx or 1,sy or sx or 1,ox or 0,oy or 0)
  g.pop()
end

function M.source() return source end
return M
