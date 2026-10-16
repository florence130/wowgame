shader_type spatial;
render_mode cull_back, specular_disabled;
#include "res://src/render/storybook_light.gdshaderinc"
// 远景地貌 / 远景树：顶点色 + 柔和卡通光；大气透视由环境雾完成（再额外偏蓝一点）。
// 近处（< 350m）叠加与可玩地形相同的手绘草地贴图明暗细节，避免地图边缘外的远景显得平板发白。

uniform bool instance_tint = false;   // MultiMesh 实例色已自动乘入 COLOR，这里仅作标记
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float use_detail = 0.0;
uniform float tile_m = 7.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = COLOR.rgb;
	float d = length(VERTEX);
	if (use_detail > 0.5) {
		vec2 uv = wpos.xz / tile_m;
		vec3 t = texture(detail_tex, uv).rgb * 0.6 + texture(detail_tex, uv * 0.37 + 0.31).rgb * 0.4;
		vec3 avg = textureLod(detail_tex, vec2(0.5), 12.0).rgb;
		float lum_t = dot(t, vec3(0.299, 0.587, 0.114));
		float lum_a = max(dot(avg, vec3(0.299, 0.587, 0.114)), 0.05);
		float k = 1.0 - smoothstep(150.0, 350.0, d);
		c *= mix(1.0, clamp(lum_t / lum_a, 0.8, 1.2), k * 0.65);
		// 近处略加饱和，接近地形草地的颜色
		c = mix(c, c * vec3(0.98, 1.02, 1.04), k * 0.6);
	}
	// 远处轻微偏蓝灰（洛奇M 式远山）
	c = mix(c, vec3(0.23, 0.33, 0.46), smoothstep(500.0, 2600.0, d) * 0.45);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += storybook_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, 0.20);
}
