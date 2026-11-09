shader_type canvas_item;
render_mode unshaded;

// Uses the authored object's exact atlas alpha rather than an ellipse.
// Vertex flattening projects the original silhouette over the ground.
// One shared material = one solar update for all shadow sprites.
uniform vec2 solar_dir = vec2(0.65, 0.25);
uniform float solar_length : hint_range(0.1, 3.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.42;
uniform float canopy_depth : hint_range(0.2, 0.6) = 0.4;

void vertex() {
    float height = max(-VERTEX.y, 0.0);
    VERTEX.x += height * solar_dir.x * solar_length;
    // Offset projected alpha inside the sprite; do not start at the crop boundary.
    // Retain crown footprint at noon; no nearly one-pixel 2D collapse.
    float crown = smoothstep(0.0, 1.0, clamp(height / 100.0, 0.0, 1.0));
    float depth = mix(0.30, canopy_depth, crown);
    VERTEX.y = -12.0 + VERTEX.y * depth + height * solar_dir.y * solar_length;
}
void fragment() {
    float silhouette = texture(TEXTURE, UV).a * COLOR.a;
    COLOR = vec4(0.022, 0.032, 0.038, silhouette * opacity);
}
