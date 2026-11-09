shader_type canvas_item;
render_mode unshaded;

// One small no-texture root ellipse per tree/rock, batched in one MultiMesh2D.
uniform float ao_opacity : hint_range(0.0, 1.0) = 0.19;

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float area = max(0.0, 1.0 - dot(p, p));
    float instance_alpha = COLOR.a;
    COLOR = vec4(0.024, 0.031, 0.031, area * area * ao_opacity * instance_alpha);
}
