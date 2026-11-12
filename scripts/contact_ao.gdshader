shader_type canvas_item;
render_mode unshaded;

// Cheap but visible grounding: small batched radial AO with a subtle moon
// offset. One MultiMesh, no per-object lighting, ray marching or blur.
uniform float ao_opacity : hint_range(0.0, 1.0) = 0.38;
uniform float moon_level : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec2 p = (UV - vec2(0.5)) * 2.0;
    float radial = max(0.0, 1.0 - dot(p, p));
    float contact = radial * (0.48 + 0.52 * radial);
    vec2 mp = (p - vec2(-0.22, 0.10)) * vec2(0.88, 1.13);
    float moon = max(0.0, 1.0 - dot(mp, mp));
    float combined = min(1.0, contact + moon_level * moon * moon * 0.34);
    COLOR = vec4(0.023, 0.029, 0.030, combined * ao_opacity * COLOR.a);
}
