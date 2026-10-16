shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;
#include "res://src/render/storybook_light.gdshaderinc"
// 风格化树冠 / 树干（tools/blender/build_trees.py 的模型）：
// 顶点色 R = 每团明暗、G = 内部 AO、B = 树冠内的高度（0 底 → 1 顶）；树冠法线已在 Blender 中做成球面法线。
// 颜色按色板（docs/palette）：暗部 leaf_dark → 中 base_color → 顶部高光 hi_color；受光面柔和分两阶，背光面偏冷。

uniform vec3 base_color : source_color = vec3(0.247, 0.478, 0.227);   // leaf_mid #3f7a3a
uniform vec3 dark_color : source_color = vec3(0.141, 0.314, 0.173);   // leaf_dark #24502c
uniform vec3 hi_color : source_color = vec3(0.58, 0.72, 0.38);        // 比色板 leaf_hi #a6c95c 收一点黄、降饱和（洛奇M 取色）
uniform vec3 shadow_tint : source_color = vec3(0.32, 0.42, 0.52);     // 暗部冷色
uniform float is_leaf = 1.0;
uniform float sway = 1.0;
// Linear data: painted volume R / soft light G / original cutout A.
uniform sampler2D leaf_mask : filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool use_leaf_mask = false;
uniform bool painted_mask = false;

varying vec3 vc;
varying float inst;
varying vec3 crown_normal;

void vertex() {
	crown_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	vc = COLOR.rgb;
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	inst = fract(sin(dot(root.xz, vec2(12.9898, 78.233))) * 43758.5453);
	if (is_leaf > 0.5) {
		float h = max(VERTEX.y, 0.0);
		float ph = TIME * 1.1 + root.x * 0.13 + root.z * 0.11;
		float bend = h * smoothstep(0.0, 4.0, h) * sway;
		VERTEX.x += sin(ph) * 0.025 * bend;
		VERTEX.z += cos(ph * 0.8 + 1.3) * 0.020 * bend;
		VERTEX += NORMAL * sin(TIME * 2.3 + VERTEX.y * 1.7 + root.x) * 0.025 * sway;
	}
}

void fragment() {
	// Alpha cards keep the same soft canopy normals on both sides.
	if (use_leaf_mask) {
		NORMAL = normalize((VIEW_MATRIX * vec4(crown_normal, 0.0)).xyz);
	}
	vec4 leaf = use_leaf_mask ? texture(leaf_mask, UV) : vec4(1.0, 0.5, 1.0, 1.0);
	if (!painted_mask) {
		leaf.rgb = vec3(1.0, 0.5, 1.0);
	}
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = 0.42;
	ALPHA_ANTIALIASING_EDGE = 0.15;
	if (is_leaf > 0.5) {
		float shade = vc.r;
		float ao = vc.g;
		float hy = vc.b;
		vec3 c = mix(dark_color, base_color, smoothstep(0.12, 0.85, hy * 0.7 + ao * 0.3));
		c = mix(c, hi_color, smoothstep(0.48, 1.0, hy) * 0.50);
		// Broad leaf lobes remain readable inside the silhouette.
		c *= 0.74 + leaf.r * 0.22 + leaf.g * 0.14;
		c *= mix(0.88, 1.05, shade) * (0.97 + inst * 0.06);
		c *= mix(0.84, 1.0, ao);
		ALBEDO = c;
		AO = mix(0.82, 1.0, ao);
		AO_LIGHT_AFFECT = 0.0;
	} else {
		ALBEDO = base_color * mix(0.85, 1.05, inst);
	}
	ROUGHNESS = 1.0;
}

void light() {
	DIFFUSE_LIGHT += storybook_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, is_leaf > 0.5 ? 0.20 : 0.08);
}
