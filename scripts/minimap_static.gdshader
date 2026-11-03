shader_type canvas_item;
render_mode unshaded;
uniform vec2 player_world = vec2(64.0,128.0);
uniform vec4 map_bounds = vec4(0.0,0.0,256.0,256.0);
uniform float view_span = 1800.0;
void fragment() {
    vec2 local = UV*2.0-1.0;
    if (dot(local,local)>0.94) { COLOR=vec4(0.0); return; }
    vec2 world = player_world + local * view_span * 0.5;
    vec2 map_uv = (world - map_bounds.xy) / map_bounds.zw;
    vec4 ground = vec4(0.08,0.12,0.09,1.0);
    if (all(greaterThanEqual(map_uv,vec2(0.0))) && all(lessThanEqual(map_uv,vec2(1.0)))) {
        ground = texture(TEXTURE,map_uv);
    }
    // Fixed north-up gold player pointer, never follows actor facing.\n    if (local.y > -0.17 && local.y < 0.19 && abs(local.x) < 0.14 &&\n        (local.y > 0.0 || abs(local.x) < (local.y+0.17)*0.65)) {\n        ground=vec4(0.98,0.72,0.12,1.0);\n    }\n    COLOR = ground;
}