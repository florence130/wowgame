shader_type spatial;
render_mode specular_disabled;
#include "res://src/render/storybook_light.gdshaderinc"
global uniform float env_night;
// 地形：9 张手绘风格无缝贴图（tools/blender/bake_terrain.py 烘焙）按两张控制图混合
// 防重复：两个尺度/旋转的采样按大尺度噪声混合；陡坡岩石用三向投影；区域 layer_colors 作为色调

uniform sampler2D control_a : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D control_b : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D tex0 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex3 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex4 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex5 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex6 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex7 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex8 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float has_tex = 0.0;
uniform vec2 terrain_origin = vec2(0.0);
uniform float terrain_size = 512.0;
uniform vec3 col0 : source_color = vec3(0.47, 0.71, 0.32);
uniform vec3 col1 : source_color = vec3(0.30, 0.52, 0.24);
uniform vec3 col2 : source_color = vec3(0.71, 0.58, 0.40);
uniform vec3 col3 : source_color = vec3(0.55, 0.53, 0.50);
uniform vec3 col4 : source_color = vec3(0.90, 0.82, 0.62);
uniform vec3 col5 : source_color = vec3(0.66, 0.64, 0.60);
uniform vec3 col6 : source_color = vec3(0.55, 0.40, 0.25);
uniform vec3 col7 : source_color = vec3(0.58, 0.76, 0.36);
uniform vec3 col8 : source_color = vec3(0.27, 0.33, 0.22);
uniform float tile_m = 7.0;   // 一张贴图覆盖的米数
uniform vec3 meadow_color : source_color = vec3(0.40, 0.54, 0.33);
uniform float water_level = -1000.0;   // 地形局部水位（世界高度）：水线附近自动铺沙 / 湿泥，水下渐变成深色泥沙底（湖岸 / 河岸 / 海岸统一，不靠手工涂刷）
uniform float slope_start = 0.38;
uniform float slope_end = 0.58;
uniform vec3 brush_pos = vec3(0.0, -99999.0, 0.0);
uniform float brush_radius = 0.0;

// 默认图层色（与 TerrainData.DEFAULT_COLORS 一致）：区域色 / 默认色 = 色调
const vec3 D0 = vec3(0.47, 0.71, 0.32);
const vec3 D1 = vec3(0.30, 0.52, 0.24);
const vec3 D2 = vec3(0.71, 0.58, 0.40);
const vec3 D3 = vec3(0.55, 0.53, 0.50);
const vec3 D4 = vec3(0.90, 0.82, 0.62);
const vec3 D5 = vec3(0.66, 0.64, 0.60);
const vec3 D6 = vec3(0.55, 0.40, 0.25);
const vec3 D7 = vec3(0.58, 0.76, 0.36);
const vec3 D8 = vec3(0.27, 0.33, 0.22);

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

vec3 tint(vec3 c, vec3 d) {
	return clamp(c / max(d, vec3(0.05)), vec3(0.5), vec3(1.6));
}

// 防重复采样：主采样 + 旋转缩放的副采样，按低频噪声混合
vec3 samp(sampler2D t, vec2 p, float m) {
	vec2 uv = p / tile_m;
	vec3 a = texture(t, uv, 0.8).rgb;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	vec3 b = texture(t, r * uv * 0.37 + vec2(0.31, 0.17), 0.8).rgb;
	return mix(a, b, m);
}

vec3 rock_tri(vec3 p, vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 x = texture(tex3, p.zy / (tile_m * 2.6)).rgb;
	vec3 y = texture(tex3, p.xz / (tile_m * 2.6)).rgb;
	vec3 z = texture(tex3, p.xy / (tile_m * 2.6)).rgb;
	return x * w.x + y * w.y + z * w.z;
}

void fragment() {
	vec2 uv = (wpos.xz - terrain_origin) / terrain_size;
	vec4 a = texture(control_a, uv);
	vec4 b = texture(control_b, uv);
	// 控制图的泥路肩部保留渐变，再用两尺度噪声形成碎土/草边；石板
	// 核心稍硬，泥土不以狭窄阈值切成平滑硬边色带。
	float en = texture(noise_tex, wpos.xz * 0.11).r - 0.5;
	float en2 = texture(noise_tex, wpos.xz * 0.37 + vec2(0.2, 0.6)).r - 0.5;
	float th = 0.5 + en * 0.34 + en2 * 0.16;
	float raw_dirt = a.g;
	a.g = smoothstep(0.04, 0.94, clamp(raw_dirt + (en * 0.22 + en2 * 0.09) * raw_dirt * (1.0 - raw_dirt) * 2.0, 0.0, 1.0));
	b.r = smoothstep(th - 0.15, th + 0.15, b.r);
	b.g = smoothstep(th - 0.18, th + 0.18, b.g);
	float n1 = texture(noise_tex, wpos.xz * 0.013).r;
	float n2 = texture(noise_tex, wpos.xz * 0.071 + vec2(0.37, 0.11)).r;
	float m = smoothstep(0.35, 0.65, texture(noise_tex, wpos.xz * 0.006 + vec2(0.5)).r);
	vec3 col;
	if (has_tex > 0.5) {
		vec2 p = wpos.xz;
		col = samp(tex0, p, m) * tint(col0, D0);
		col = mix(col, samp(tex1, p, m) * tint(col1, D1), a.r);
		col = mix(col, samp(tex2, p, m) * tint(col2, D2), a.g);
		col = mix(col, samp(tex3, p, m) * tint(col3, D3), a.b);
		col = mix(col, samp(tex4, p, m) * tint(col4, D4), a.a);
		col = mix(col, texture(tex5, p / (tile_m * 0.75)).rgb * tint(col5, D5), b.r);
		// Furrows have an authored direction; rotating and mixing two scales erases the rows.
		col = mix(col, texture(tex6, p / tile_m).rgb * tint(col6, D6), b.g);
		col = mix(col, samp(tex7, p, m) * tint(col7, D7), b.b);
		col = mix(col, samp(tex8, p, m) * tint(col8, D8), b.a);
		// 路面使用真实泥土贴图的多尺度细节，并在边缘保留草/泥肩部过渡。
		// 这样道路不再是单一纯色带，也不会出现硬切直边。
		float road_w = clamp(a.g, 0.0, 1.0);
		float road_edge = smoothstep(0.32, 0.82, road_w);
		float grit = texture(noise_tex, wpos.xz * 0.22 + vec2(0.17, 0.61)).r;
		vec3 road_detail = samp(tex2, p, m) * tint(col2, D2);
		road_detail *= 0.84 + grit * 0.28;
		col = mix(col, road_detail, road_edge * 0.38);
		col = mix(col, road_detail * vec3(0.9, 0.86, 0.76), road_w * (1.0 - road_edge) * 0.22);
		// 大尺度色斑：草地区域在暖黄绿与冷绿之间起伏（洛奇M 的草坡色块），整体明暗也略有起伏
		float grassw = clamp(1.0 - (a.g + a.b + a.a + b.r + b.g), 0.0, 1.0);
		// 泥路草肩的裸土/草颜色过渡要随权重淡出，避免浅色泥土被草底色洗平。
		grassw *= 1.0 - smoothstep(0.10, 0.72, road_w);
		// 把细碎笔触收进底色，保留涂刷层与坡地，草和地表使用同一组灰绿。
		col = mix(col, meadow_color * tint(col0, D0), grassw * 0.78);
		float mac = smoothstep(0.3, 0.75, texture(noise_tex, wpos.xz * 0.0045 + vec2(0.17, 0.61)).r);
		col = mix(col, col * mix(vec3(0.94, 1.0, 1.02), vec3(1.06, 1.025, 0.94), mac), grassw * 0.6);
		col *= 0.96 + 0.08 * n1;
		if (water_level > -500.0) {
			float hh = wpos.y - water_level;
			float band_top = 1.15 + (n1 - 0.5) * 1.1;                      // 沙滩上沿随噪声起伏
			float slope_s = 1.0 - clamp(wnrm.y, 0.0, 1.0);
			float sand = (1.0 - smoothstep(band_top - 0.7, band_top + 0.5, hh)) * (1.0 - smoothstep(0.3, 0.55, slope_s));
			vec3 sandc = samp(tex4, wpos.xz, m) * tint(col4, D4);
			col = mix(col, sandc, sand * 0.92);
			float wet = 1.0 - smoothstep(-0.2, 0.55 + 0.3 * n2, hh);        // 水线附近的湿沙：更深更饱和
			col *= mix(1.0, 0.74, wet * (1.0 - smoothstep(0.0, 1.5, -hh)));
			float depth = clamp(-hh / 7.0, 0.0, 1.0);                        // 水下：渐变成青灰泥沙底
			col = mix(col, col * vec3(0.5, 0.7, 0.72) + vec3(0.0, 0.02, 0.03), depth);
		}
		float slope = 1.0 - clamp(wnrm.y, 0.0, 1.0);
		// 草坡 → 碎石土（中等坡度）→ 岩壁（陡坡），不再从草地直接跳到灰色岩石
		float soil = smoothstep(0.14, 0.3, slope + (n2 - 0.5) * 0.1);
		col = mix(col, samp(tex2, p, m) * tint(col2, D2) * vec3(0.9, 0.92, 0.95), soil * 0.5);
		float rock = smoothstep(slope_start, slope_end, slope + (n2 - 0.5) * 0.08);
		// 崖壁：偏暖的浅砂岩灰（洛奇M 的崖石是明亮的暖灰，不是蓝灰），按高度做水平地层带 + 噪声斑驳，避免一整块暗色糊面
		vec3 cliff = rock_tri(wpos, wnrm) * tint(col3, D3) * vec3(1.22, 1.14, 1.02);
		float strata = sin(wpos.y * 1.55 + n1 * 5.0) * 0.5 + 0.5;
		cliff *= 0.88 + 0.2 * strata + 0.1 * (n2 - 0.5);
		col = mix(col, cliff, rock);
		// 岩壁顶缘与坡脚的草 / 土过渡：崖面上缘（朝上的小平台）回到草色，避免一刀切
		col = mix(col, col * vec3(0.96, 1.04, 0.92), rock * smoothstep(0.55, 0.9, wnrm.y) * 0.5);
	} else {
		col = col0 * (0.92 + 0.16 * n1);
		col = mix(col, col1, a.r);
		col = mix(col, col2, a.g);
		col = mix(col, col3, a.b);
		col = mix(col, col4, a.a);
		col = mix(col, col5, b.r);
		col = mix(col, col6, b.g);
		col = mix(col, col7, b.b);
		col = mix(col, col8, b.a);
	}
	// 编辑器笔刷指示圈
	if (brush_radius > 0.0) {
		float d = length(wpos.xz - brush_pos.xz);
		float ring = smoothstep(brush_radius - 0.6, brush_radius - 0.2, d) * (1.0 - smoothstep(brush_radius, brush_radius + 0.3, d));
		col = mix(col, vec3(1.0, 0.85, 0.3), ring);
		col = mix(col, col * 1.1, step(d, brush_radius) * 0.5);
	}
	ALBEDO = col;
	// 背光面补一层天空漫射（半球光）：山坡背阴面不再是一整块死黑的蓝灰。
	// 夜间仍保留 42% 的冷色基底，交给月光/阴影塑形；完全切断自发光会
	// 让月光未覆盖的草坡和道路压成纯黑，角色与可交互物也失去分离度。
	float night_fill = mix(1.0, 0.42, clamp(env_night, 0.0, 1.0));
	EMISSION = col * (0.1 + 0.07 * (1.0 - clamp(wnrm.y, 0.0, 1.0))) * night_fill;
	ROUGHNESS = 1.0;
}

void light() {
	// Keep terrain planes distinct from the sky fill.  A 0.3 wrap value made
	// grass, road and slope receive nearly the same broad light and flattened
	// the foreground; the moon/ambient fill still keeps the night readable.
	DIFFUSE_LIGHT += storybook_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, 0.22);
}




