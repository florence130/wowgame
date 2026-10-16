shader_type spatial;
render_mode cull_disabled;
uniform vec3 water_color : source_color = vec3(0.27, 0.38, 0.59);
varying vec3 world_pos;
void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    VERTEX.y += sin(world_pos.x * 1.2 + TIME * 0.22) * 0.003;
}
void fragment() {
    ALBEDO = water_color;
    ROUGHNESS = 0.055;
    METALLIC = 0.65;
    SPECULAR = 0.8;
    NORMAL_MAP = vec3(0.5 + sin(world_pos.z * 4.1 + sin(world_pos.x * 1.6) + TIME * 0.22) * 0.015, 0.5 + cos(world_pos.x * 2.4 + TIME * 0.18) * 0.012, 1.0);
}
