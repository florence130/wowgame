shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley, specular_disabled;
// 环境小动物粒子（蝴蝶 / 飞鸟）：面向相机的公告板，图集取自 assets/textures/env/fx_*.png
// mode 0 = 蝴蝶：图集一行 4 种花色（按粒子动画帧随机选色），翅膀横向周期压缩表现扇动
// mode 1 = 飞鸟：图集两帧交替扇翅
uniform sampler2D atlas : source_color, filter_linear_mipmap;
uniform float cols = 4.0;
uniform float row_scale = 0.5;
uniform int mode = 0;
uniform vec4 tint : source_color = vec4(1.0);

void vertex() {
	float id = float(INSTANCE_ID);
	if (mode == 0) {
		VERTEX.x *= mix(0.22, 1.0, abs(sin(TIME * 13.0 + id * 1.7)));
		UV.x = (UV.x + floor(INSTANCE_CUSTOM.z * cols + 0.001)) / cols;
	} else {
		UV.x = (UV.x + step(0.5, fract(TIME * 2.6 + id * 0.37))) / cols;
	}
	UV.y *= row_scale;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec4 c = texture(atlas, UV);
	if (c.a < 0.5) discard;
	ALBEDO = c.rgb * tint.rgb;
	ROUGHNESS = 0.9;
}
