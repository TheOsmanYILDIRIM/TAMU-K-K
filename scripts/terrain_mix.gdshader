shader_type canvas_item;
render_mode unshaded;

// Terrain-only material interweaving over the EXISTING packed 168-tile atlas.
// The native mesh UVs/vertices and authored R2 map never change.
// Atlas: 14x12 cells, 132px stride including 2px gutters around 128px tiles.
uniform sampler2D transition_lookup : filter_nearest, repeat_disable;
uniform sampler2D noise_field : filter_linear, repeat_enable;
varying vec2 world_screen;

void vertex() {
    world_screen = VERTEX;
}
void fragment() {
    vec2 slot = floor(clamp(UV * vec2(14.0, 12.0), vec2(0.0), vec2(13.999, 11.999)));
    vec4 target = texture(transition_lookup, (slot + vec2(0.5)) / vec2(14.0, 12.0));
    if (target.a >= 0.5) {
    vec2 tile_uv = clamp((UV * vec2(1848.0,1584.0) - slot * 132.0 - vec2(2.0)) / 128.0,
        vec2(0.005), vec2(0.995));
    vec2 source_slot = floor(target.rg * 255.0 + vec2(0.5));
    vec2 mixed_uv = (source_slot * 132.0 + vec2(2.0) + tile_uv * 128.0) / vec2(1848.0,1584.0);
    float noise = texture(noise_field, world_screen / 720.0).r;
    float cover = smoothstep(0.38, 0.76, noise) * target.b;
    vec3 original = texture(TEXTURE, UV).rgb;
    vec3 secondary = texture(TEXTURE, mixed_uv).rgb;
    COLOR.rgb *= mix(vec3(1.0), secondary / max(original, vec3(0.18)), cover);
    }
}
