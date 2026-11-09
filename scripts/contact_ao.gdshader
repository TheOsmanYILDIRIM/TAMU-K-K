shader_type canvas_item;
render_mode unshaded;

// Ground contact only: one ellipse per R2 tree/rock, batched in MultiMesh2D.
uniform float ao_opacity : hint_range(0.0, 1.0) = 0.18;

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float radial = max(0.0, 1.0 - dot(p, p));
    COLOR = vec4(0.025, 0.033, 0.033, radial * radial * ao_opacity * COLOR.a);
}
