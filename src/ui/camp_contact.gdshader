shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
void fragment() {
    ALBEDO = vec3(0.08, 0.055, 0.025);
    ALPHA = (1.0 - smoothstep(0.05, 0.5, length(UV - 0.5))) * 0.42;
}
