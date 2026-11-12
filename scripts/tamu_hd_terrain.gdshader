shader_type canvas_item;
render_mode unshaded;
// Fast TAMU terrain: exact native 14x12 mesh UV; 2 samples per pixel.
// Height field was premixed into the pre-normalized RGBA normal atlas offline.
// Normal alpha == 0 for original wetland; never recolor/re-light authored water.
uniform sampler2D hd_normal_atlas : filter_linear_mipmap, repeat_disable;
uniform vec3 sun_vector = vec3(0.2, 0.3, 0.93);
uniform float sun_light = 1.0;
uniform float relight_strength : hint_range(0.0, 1.0) = 0.48;
varying vec4 vertex_tint;
void vertex() {
    vertex_tint = COLOR;
}
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec4 packed_normal = texture(hd_normal_atlas, UV);
    // Baked vectors are already normalized. No per-pixel trig, gradient or sqrt.
    vec3 surface_normal = packed_normal.rgb * 2.0 - 1.0;
    float light_response = clamp(dot(surface_normal, sun_vector), 0.0, 1.0);
    float gain = 1.0 + packed_normal.a * sun_light * relight_strength * (light_response - 0.58);
    COLOR = vec4(base.rgb * clamp(gain, 0.74, 1.20), base.a) * vertex_tint;
}