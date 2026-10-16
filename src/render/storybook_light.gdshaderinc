// Broad illustrated value planes, with real light attenuation and scene ambient fill.
// No unlit shadow floor: lamps, night and occlusion must continue to behave normally.
vec3 storybook_diffuse(vec3 normal, vec3 light_dir, vec3 light_color, float attenuation, float wrap) {
	float value = clamp((dot(normal, light_dir) + wrap) / (1.0 + wrap), 0.0, 1.0);
	float plane = smoothstep(0.08, 0.72, value);
	return light_color / PI * mix(value, plane, 0.24) * attenuation;
}
