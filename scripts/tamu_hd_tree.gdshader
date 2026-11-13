shader_type canvas_item;
// Preserve the normal-map CanvasItem light pass for Godot 4.6 PointLight2D.
// 2 texture samples (authored albedo + generated normal map) per pixel.
uniform sampler2D tree_normal : filter_linear_mipmap, repeat_disable;
uniform vec3 sun_vector = vec3(0.2, 0.3, 0.93);
uniform float sun_light = 1.0;
uniform float relight_strength : hint_range(0.0, 2.0) = 1.0;
uniform float normal_strength : hint_range(0.0, 2.5) = 1.0;
uniform float specular_strength : hint_range(0.0, 1.0) = 0.20;
varying vec4 vertex_tint;
void vertex() {
    vertex_tint = COLOR;
}
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec3 encoded_normal = texture(tree_normal, UV).rgb;
    NORMAL_MAP = encoded_normal;
    // Match the validated HTML v4 directional normal-map lighting model.
    vec3 n = normalize(vec3(
        (encoded_normal.r * 2.0 - 1.0) * normal_strength,
        (encoded_normal.g * 2.0 - 1.0) * normal_strength,
        max(0.025, encoded_normal.b * 2.0 - 1.0)
    ));
    vec3 light_dir = normalize(sun_vector);
    float day = clamp(sun_light, 0.0, 1.0);
    float lambert = max(dot(n, light_dir), 0.0);
    // Never replace directed surface lighting with a uniform on/off multiplier.
    float ambient = mix(0.47, 0.56, day);
    float diffuse = relight_strength * mix(0.11, 0.63, day) * lambert;
    vec3 half_vec = normalize(light_dir + vec3(0.0, 0.0, 1.0));
    float sparkle = pow(max(dot(n, half_vec), 0.0), 24.0)
        * specular_strength * day * 0.18;
    vec3 lit_rgb = clamp(base.rgb * (ambient + diffuse) + vec3(sparkle), vec3(0.0), vec3(1.0));
    COLOR = vec4(lit_rgb, base.a) * vertex_tint;
}
