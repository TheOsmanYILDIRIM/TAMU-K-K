shader_type canvas_item;
render_mode unshaded;
// 2:1 R2 mesh and UV remain unchanged. Six authored 512px tiles in a 3x2 atlas.
uniform sampler2D tamu_albedo : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D tamu_normal : filter_linear_mipmap, repeat_disable;
uniform sampler2D tamu_height : filter_linear_mipmap, repeat_disable;
uniform sampler2D family_lookup : filter_nearest, repeat_disable;
uniform vec2 sun_cast_dir = vec2(0.65, 0.25);
uniform float sun_altitude = 51.0;
uniform float sun_light = 1.0;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.72;
uniform float height_strength : hint_range(0.0, 1.0) = 0.20;
varying vec4 vertex_tint;
void vertex() {
    vertex_tint = COLOR;
}
void fragment() {
    vec2 slot = floor(clamp(UV * vec2(14.0, 12.0), vec2(0.0), vec2(13.999, 11.999)));
    vec4 record = texture(family_lookup, (slot + vec2(0.5)) / vec2(14.0, 12.0));
    vec4 original = texture(TEXTURE, UV);
    if (record.a < 0.5) {
        COLOR = original * vertex_tint;
    } else {
        vec2 tile = clamp((UV * vec2(1848.0, 1584.0) - slot * 132.0 - vec2(2.0)) / 128.0, vec2(0.003), vec2(0.997));
        float index = floor(record.r * 255.0 + 0.5);
        vec2 origin = vec2(mod(index, 3.0), floor(index / 3.0));
        vec2 coords = (origin + tile) / vec2(3.0, 2.0);
        vec3 pigment = texture(tamu_albedo, coords).rgb;
        vec3 n = texture(tamu_normal, coords).rgb * 2.0 - 1.0;
        n.xy *= normal_strength;
        n = normalize(vec3(n.xy, max(n.z, 0.18)));
        vec2 texel = vec2(1.0 / 1536.0, 1.0 / 1024.0);
        float h0 = texture(tamu_height, coords).r;
        vec2 gradient = vec2(
            texture(tamu_height, coords + vec2(texel.x, 0.0)).r - h0,
            texture(tamu_height, coords + vec2(0.0, texel.y)).r - h0
        );
        vec2 sun_xy = normalize(-sun_cast_dir);
        float elevation = radians(sun_altitude);
        vec3 incoming = normalize(vec3(sun_xy * cos(elevation), max(sin(elevation), 0.02)));
        float diffuse = clamp(dot(n, incoming), 0.0, 1.0);
        float micro = clamp(dot(gradient, sun_xy) * 9.0, -0.09, 0.09);
        float lighting = 0.88 + sun_light * ((diffuse - 0.55) * 0.43 - micro * height_strength);
        COLOR = vec4(pigment * clamp(lighting, 0.60, 1.19), original.a) * vertex_tint;
    }
}