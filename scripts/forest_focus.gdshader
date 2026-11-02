shader_type canvas_item;
render_mode unshaded;
// Selection-aware depth of field, one mipmapped screen fetch per fragment.
// World-space focus keeps the selected source sharp while vignette softens
// foliage. HUD and selection sprite live on higher canvas layers.
uniform sampler2D world_screen : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 focus_uv = vec2(0.5,0.58);
void fragment() {
    vec2 relative = SCREEN_UV-focus_uv;
    float elliptical = length(relative*vec2(1.0,0.86));
    float blur_level = mix(0.55,2.55,smoothstep(0.12,0.70,elliptical));
    vec3 base = textureLod(world_screen, SCREEN_UV, blur_level).rgb;
    float distance_fade = smoothstep(0.12,0.78,elliptical);
    vec3 toned = base * mix(vec3(0.96,0.94,0.85),vec3(0.75,0.74,0.59),distance_fade);
    COLOR = vec4(toned,1.0);
}
