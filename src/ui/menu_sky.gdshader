shader_type sky;
render_mode use_debanding;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void sky() {
    float h = clamp(EYEDIR.y * 1.4, 0.0, 1.0);
    vec3 col = mix(vec3(0.58, 0.69, 0.83), vec3(0.08, 0.14, 0.34), pow(h, 0.28));
    vec2 p = SKY_COORDS * vec2(800.0, 400.0);
    vec2 cell = floor(p);
    float star = smoothstep(0.18, 0.0, length(fract(p) - 0.5));
    star *= step(0.985, hash(cell)) * smoothstep(0.01, 0.18, EYEDIR.y);
    col += star * vec3(0.72, 0.82, 0.94);
    vec3 moon_dir = normalize(vec3(0.52, 0.38, -0.78));
    float dist = length(EYEDIR - moon_dir);
    col += vec3(0.46, 0.55, 0.69) * exp(-dist * 18.0);
    col = mix(col, vec3(0.96, 0.99, 1.0), smoothstep(0.034, 0.029, dist));
    COLOR = col;
}
