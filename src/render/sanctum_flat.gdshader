shader_type spatial;
render_mode cull_disabled;
#include "res://src/render/storybook_light.gdshaderinc"
// Local sea-temple palette: broad color planes without surface noise or maps.
uniform vec4 base_color : source_color = vec4(0.72, 0.70, 0.63, 1.0);
uniform int joints_mode = 0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}
void fragment() {
	vec3 color = base_color.rgb;
	if (joints_mode > 0) {
		vec2 p = world_position.xz;
		vec2 cell = vec2(3.2, 3.8);
		if (joints_mode == 2) {
			vec3 n = abs(normalize(world_normal));
			p = vec2(n.x > n.z ? world_position.z : world_position.x, world_position.y);
			cell = vec2(4.2, 2.4);
			p.x += mod(floor(p.y / cell.y), 2.0) * cell.x * 0.5;
		}
		vec2 id = floor(p / cell);
		vec2 edge = min(fract(p / cell), 1.0 - fract(p / cell)) * cell;
		float joint = 1.0 - smoothstep(0.016, 0.035, min(edge.x, edge.y));
		float tone = fract(sin(dot(id, vec2(17.2, 83.7))) * 413.6);
		color *= 0.97 + floor(tone * 3.0) * 0.025;
		color *= 1.0 - joint * 0.11;
		// Large painted weathering planes retain flat-color readability.
		float patch = sin(world_position.x * 0.29 + sin(world_position.z * 0.18))
			* sin(world_position.z * 0.24 + world_position.y * 0.31);
		float weather = smoothstep(0.38, 0.65, patch);
		color = mix(color, color * vec3(0.84, 0.88, 0.80), weather * 0.32);
	}
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
void light() {
	DIFFUSE_LIGHT += storybook_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, 0.12);
}
