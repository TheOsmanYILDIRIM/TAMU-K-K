shader_type canvas_item;
render_mode unshaded;
// One mipmapped world sample while a resource is selected; no per-frame CPU blur.
uniform sampler2D world_screen : hint_screen_texture, repeat_disable, filter_linear_mipmap;
void fragment() {
    vec3 source = textureLod(world_screen,SCREEN_UV,1.90).rgb;
    vec2 p = (SCREEN_UV - vec2(0.5)) * vec2(1.20,1.05);
    float vignette = smoothstep(0.82,0.15,length(p));
    vec3 tinted = mix(source*vec3(0.66,0.65,0.51),
                      source*vec3(0.88,0.86,0.73),vignette);
    COLOR = vec4(tinted,1.0);
}
