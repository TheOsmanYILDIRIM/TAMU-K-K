shader_type canvas_item;
render_mode unshaded;

// Padded original RGBA silhouette: no rectangular selection bounds.
// Only the currently selected object has this material.
uniform vec4 gold : source_color = vec4(1.0, 0.82, 0.21, 1.0);

void fragment() {
    float alpha = texture(TEXTURE, UV).a;
    vec2 px = TEXTURE_PIXEL_SIZE;
    float border = 0.0;
    float halo = 0.0;
    for (int i = 0; i < 8; i++) {
        float theta = 6.2831853 * float(i) / 8.0;
        vec2 axis = vec2(cos(theta), sin(theta));
        border = max(border, texture(TEXTURE, UV + axis * px * 1.8).a);
        halo = max(halo, texture(TEXTURE, UV + axis * px * 3.8).a);
    }
    float fine = clamp((border - alpha) * 1.8, 0.0, 1.0);
    float soft = clamp((halo - alpha) * 0.45, 0.0, 1.0);
    float fill = alpha * 0.10;
    float pulse = 0.93 + 0.07 * sin(TIME * 2.4);
    float result_alpha = max(max(fine * 0.98, soft), fill) * pulse;
    COLOR = vec4(mix(vec3(0.91, 0.53, 0.07), gold.rgb, fine),
        result_alpha * gold.a);
}
