shader_type canvas_item;
render_mode unshaded;
// Original user-authored alpha silhouette governs visibility and solar shadow.
uniform sampler2D tree_normal : filter_linear_mipmap, repeat_disable;
uniform vec2 sun_cast_dir = vec2(0.65, 0.25);
uniform float sun_altitude = 51.0;
uniform float sun_light = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.85;
uniform float relight_strength : hint_range(0.0, 1.0) = 0.55;
varying vec4 vertex_tint;
void vertex() {
    vertex_tint = COLOR;
}
void fragment() {
    vec4 base = texture(TEXTURE, UV);
    vec3 n = texture(tree_normal, UV).rgb * 2.0 - 1.0;
    n.xy *= normal_strength;
    n = normalize(vec3(n.xy, max(0.15, n.z)));
    vec2 sun_xy = normalize(-sun_cast_dir);
    float elevation = radians(sun_altitude);
    vec3 incoming = normalize(vec3(sun_xy * cos(elevation), max(sin(elevation), 0.03)));
    float lambert = clamp(dot(n, incoming), 0.0, 1.0);
    float factor = 1.0 + sun_light * relight_strength * (lambert - 0.58) * 0.48;
    COLOR = vec4(base.rgb * clamp(factor, 0.68, 1.24), base.a) * vertex_tint;
}