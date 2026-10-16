shader_type fog;
// Ethereal port: moving noise, height extinction, local density modulation.
// Godot's froxel integrator supplies shadow lookup and anisotropic light scattering.
uniform sampler2D fog_noise : filter_linear_mipmap, repeat_enable;
uniform float density = 0.004;
uniform float ground_height = 0.0;
uniform float height_falloff = 0.028;
uniform vec3 fog_color : source_color = vec3(0.65, 0.78, 0.80);
global uniform float env_motion_time;
void fog() {
	vec2 p = WORLD_POSITION.xz * 0.009 + vec2(env_motion_time * 0.0008, env_motion_time * 0.0003);
	float n = texture(fog_noise, p).r * 0.7 + texture(fog_noise, p * 2.13 + vec2(0.31)).g * 0.3;
	float height = exp(-max(WORLD_POSITION.y - ground_height, 0.0) * height_falloff);
	// Smooth box boundary; the camera remains at its center as it moves.
	vec3 edge = smoothstep(vec3(0.0), vec3(0.12), UVW) * (vec3(1.0) - smoothstep(vec3(0.88), vec3(1.0), UVW));
	DENSITY = density * height * mix(0.65, 1.20, n) * edge.x * edge.y * edge.z;
	// Godot packs local scattering as 11/11/10-bit albedo*density. At thin
	// densities a tinted channel can quantize to zero (visible as green shafts).
	// Thin aerosols scatter neutral light; sun/moon provide their natural tint.
	// Denser weather fog has enough precision to retain the requested color.
	ALBEDO = mix(vec3(1.0), fog_color, smoothstep(0.0025, 0.006, DENSITY));
}
