shader_type canvas_item;
render_mode unshaded;
// Two texture reads per sprite fragment. No fragment trigonometry or normalization.
// Normal vectors are pre-renormalized when mobile textures are baked.
uniform sampler2D tree_normal : filter_linear_mipmap, repeat_disable;
uniform vec3 sun_vector = vec3(0.2, 0.3, 0.93);
uniform float sun_light = 1.0;
uniform float relight_strength : hint_range(0.0, 1.0) = 0.48;
varying vec4 vertex_tint;
void vertex() {
    vertex_tint = COLOR;
}
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec3 n = texture(tree_normal, UV).rgb * 2.0 - 1.0;
    float lambert = clamp(dot(n, sun_vector), 0.0, 1.0);
    float factor = 1.0 + sun_light * relight_strength * (lambert - 0.58) * 0.48;
    COLOR = vec4(base.rgb * clamp(factor,0.70,1.20),base.a) * vertex_tint;
}