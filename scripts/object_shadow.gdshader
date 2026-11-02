shader_type canvas_item;
render_mode unshaded;

// Uses the authored object's exact atlas alpha rather than an ellipse.
// Vertex flattening projects the original silhouette over the ground.
// One shared material = one solar update for all shadow sprites.
uniform vec2 solar_dir = vec2(0.65, 0.25);
uniform float solar_length : hint_range(0.1, 3.0) = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.42;

void vertex() {
    float height = max(-VERTEX.y, 0.0);
    VERTEX.x += height * solar_dir.x * solar_length;
    VERTEX.y = VERTEX.y * 0.12 + height * solar_dir.y * solar_length;
}
void fragment() {
    float silhouette = texture(TEXTURE, UV).a * COLOR.a;
    COLOR = vec4(0.022, 0.032, 0.038, silhouette * opacity);
}
