shader_type canvas_item;
render_mode unshaded;
void fragment() {
  vec2 p=UV;
  float wave=sin(p.y*65.0-TIME*2.5+sin(p.x*17.0))*0.055;
  float shimmer=sin(p.x*36.0+TIME*1.8)*0.025;
  COLOR=vec4(mix(vec3(0.02,0.23,0.33),vec3(0.1,0.70,0.70),clamp(0.48+wave+shimmer,0.0,1.0)),0.94);
}
