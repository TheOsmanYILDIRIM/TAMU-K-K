shader_type canvas_item;
// Exact TAMU atlas UV, 2 texture reads (albedo + prepacked normal) per pixel.
// Preserve wetland authored color where normal alpha is zero.
uniform sampler2D hd_normal_atlas : filter_linear_mipmap, repeat_disable;
uniform vec3 sun_vector = vec3(0.2, 0.3, 0.93);
uniform float sun_light = 1.0;
uniform float relight_strength : hint_range(0.0, 2.0) = 1.0;
varying vec4 vertex_tint;
void vertex() {
    vertex_tint = COLOR;
}
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec4 packed_normal = texture(hd_normal_atlas, UV);
    // Wetland slots have no editable HD normals.
    NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), packed_normal.rgb, packed_normal.a);
    vec3 n = normalize(packed_normal.rgb * 2.0 - 1.0);
    float day = clamp(sun_light, 0.0, 1.0);
    float ambient = mix(0.47, 0.56, day);
    float lambert = max(dot(n, normalize(sun_vector)), 0.0);
    float diffuse = relight_strength * mix(0.11, 0.63, day) * lambert;
    float irradiance = mix(1.0, ambient + diffuse, packed_normal.a);
    COLOR = vec4(clamp(base.rgb * irradiance, vec3(0.0), vec3(1.0)), base.a) * vertex_tint;
}
