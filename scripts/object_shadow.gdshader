shader_type canvas_item;
render_mode unshaded;

// Preserve exact authored atlas alpha, not a circle replacing the object.
// Orthogonal cast basis prevents the determinant from crossing zero:
// horizontal silhouette width always projects perpendicular to the sun,
// while vertical authored height projects in the sun's ground direction.
// This NEVER inverts or folds the texture at noon or during azimuth changes.
uniform vec2 solar_dir = vec2(0.65, 0.25);
uniform float solar_length : hint_range(0.1, 3.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.35;
uniform float canopy_depth : hint_range(0.2, 0.6) = 0.41;

void vertex() {
    vec2 ray = normalize(solar_dir);
    vec2 cross_ray = vec2(-ray.y, ray.x);
    // The authored sprite foot pivot is near local y=0. Signed local height
    // avoids folding the last pixels of the trunk into a singular line.
    float authored_height = -VERTEX.y;
    float cross_width = mix(0.70, 0.86, canopy_depth);
    VERTEX = vec2(0.0, -9.0)
        + cross_ray * (VERTEX.x * cross_width)
        + ray * (authored_height * solar_length * 0.66);
}

void fragment() {
    float silhouette = texture(TEXTURE, UV).a * COLOR.a;
    COLOR = vec4(0.022, 0.032, 0.038, silhouette * opacity);
}
