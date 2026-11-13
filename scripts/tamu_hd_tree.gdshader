shader_type canvas_item;
// Keep the Godot 4.6 CanvasItem light pass active for PointLight2D / DirectionalLight2D.
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
    vec3 normal_rgb = texture(tree_normal, UV).rgb;
    // Generated 3D-style tangent-space normals must be mapped into Godot's 2D light pass.
    NORMAL_MAP = normal_rgb;
    vec3 n = normal_rgb * 2.0 - 1.0;
    float lambert = clamp(dot(n, sun_vector), 0.0, 1.0);
    float daylight = clamp(sun_light, 0.0, 1.0);
    // The old formula returned 1.0 at midnight, leaving trees permanently lit.
    float ambient = mix(0.22, 1.0, daylight);
    float relief = 1.0 + daylight * relight_strength * (lambert - 0.58) * 0.48;
    COLOR = vec4(base.rgb * ambient * clamp(relief, 0.70, 1.20), base.a) * vertex_tint;
}