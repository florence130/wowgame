shader_type canvas_item;
uniform float blur_amount = 0.0;
void fragment() {
    vec2 step_uv = TEXTURE_PIXEL_SIZE * blur_amount;
    vec4 c = texture(TEXTURE, UV) * 0.2;
    c += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)) * 0.12;
    c += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)) * 0.12;
    c += texture(TEXTURE, UV + vec2(0.0, step_uv.y)) * 0.12;
    c += texture(TEXTURE, UV - vec2(0.0, step_uv.y)) * 0.12;
    c += texture(TEXTURE, UV + step_uv) * 0.08;
    c += texture(TEXTURE, UV - step_uv) * 0.08;
    c += texture(TEXTURE, UV + vec2(step_uv.x, -step_uv.y)) * 0.08;
    c += texture(TEXTURE, UV + vec2(-step_uv.x, step_uv.y)) * 0.08;
    float vignette = smoothstep(0.22, 0.78, length((UV - 0.5) * vec2(1.15, 0.85)));
    c.rgb = mix(c.rgb, vec3(0.1, 0.16, 0.29), vignette * 0.38);
    COLOR = c;
}
