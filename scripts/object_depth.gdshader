shader_type canvas_item;

// Cheap sprite-side self shading, normal/light processing kept intact.
// The incoming fragment COLOR already includes the authored atlas texture.
uniform vec2 light_axis = vec2(0.6, -0.8);
uniform float depth_strength : hint_range(0.0, 0.2) = 0.10;
varying vec2 object_local;

void vertex() {
    object_local = VERTEX;
}

void fragment() {
    float side = clamp(object_local.x / 48.0, -1.0, 1.0);
    float raised = clamp((-object_local.y - 8.0) / 96.0, 0.0, 1.0);
    float away = clamp(0.5 - 0.5 * side * light_axis.x, 0.0, 1.0);
    COLOR.rgb *= 1.0 - depth_strength * away * (0.45 + 0.55 * raised);
}
