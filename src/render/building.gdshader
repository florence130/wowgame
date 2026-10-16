shader_type spatial;
render_mode cull_back;
#include "res://src/render/storybook_light.gdshaderinc"
// 建筑风格化着色器（洛奇M 重制版 / 塞尔达荒野之息式手绘卡通）
// 世界坐标程序化细节：灰泥 / 红砖 / 石块 / 石板瓦 / 陶瓦 / 铜绿 / 木板 / 金属 / 植物
// 有手绘贴图时用贴图替换程序化细节：RGB「乘数」贴图（每通道均值 0.5，×2 后均值 1），底色保持，逐块色相 / 明度变化来自贴图
// 光照：柔和两段卡通明暗 + 暖色受光 + 冷色背光（由环境光提供）
// 2026-10-10：加入按材质区分的 PBR 参数（粗糙度 / 金属度 / 反射率）：金属有金属反射，木 / 灰泥 / 砖 / 石是粗糙介电体（F0=0.04），瓦片略带釉光；
//   参数来自 pbr uniform（util.gd 按贴图名设置）；没有贴图时用 mtype 的默认值。漫反射仍是手绘卡通明暗，镜面项用标准 GGX。

uniform vec4 base_color : source_color = vec4(0.94, 0.9, 0.82, 1.0);
uniform bool use_vertex_base = false;
// 0 灰泥 1 红砖 2 石块 3 石板瓦 4 陶瓦 5 铜绿 6 木板 7 金属 8 植物 9 浅色石饰
uniform int mtype = 0;
uniform float detail = 1.0;
uniform float ground_ao = 1.0;
// 手绘贴图（assets/textures/building/pt_*.png，RGB 乘数、无缝）
uniform sampler2D tex_detail : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float use_tex = 0.0;
uniform float tex_m = 3.0;          // 一张贴图覆盖的米数
uniform float tex_strength = 0.95;
// 洛奇M 图集模型（M| 材质）：直接按模型自带 UV 取贴图的 albedo，不做程序化细节 / 三向投影
uniform float use_uv = 0.0;
// PBR：x 粗糙度 y 金属度 z 介电反射量（0.5 = 标准 F0 0.04）；x < 0 表示按 mtype 默认值
uniform vec3 pbr = vec3(-1.0, 0.0, 0.5);
// 2026-10-10 PBR 高清贴图（tools/texgen/pbr_maps.py）：切线空间法线 + R 粗糙度乘数 / G 环境遮蔽；与 tex_detail 用同一套 uv 与平铺米数
uniform sampler2D tex_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex_rgh : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float use_nrm = 0.0;
uniform float nrm_str = 1.0;

// 合批街区住宅（src/world/city_houses.gd 的 MultiMesh）：底色取实例数据 INSTANCE_CUSTOM[inst_slot] 指向的调色板颜色
// （墙 / 屋顶 / 饰边各占一个通道），-1 = 用 base_color。调色板写 sRGB，着色器里转线性。
uniform int inst_slot = -1;
uniform vec3 inst_pal[64];

varying vec3 wpos;
varying vec3 wnrm;
varying float hrel;
varying vec3 inst_col;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1, 0)), u.x), mix(hash12(i + vec2(0, 1)), hash12(i + vec2(1, 1)), u.x), u.y);
}

float fbm(vec2 p) {
	return vnoise(p) * 0.55 + vnoise(p * 2.13 + 7.1) * 0.3 + vnoise(p * 4.7 + 3.3) * 0.15;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
	// MultiMesh 时 MODEL_MATRIX 已含实例变换，原点就是这栋房子的地面
	hrel = wpos.y - (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).y;
	inst_col = vec3(1.0);
	if (inst_slot >= 0) {
		int k = clamp(int(INSTANCE_CUSTOM[inst_slot] + 0.5), 0, 63);
		vec3 c = inst_pal[k];
		inst_col = mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
	}
}

// 面内二维坐标：顶面用 xz，立面用 (沿墙方向, 高度)
vec2 face_uv(vec3 p, vec3 n) {
	if (abs(n.y) > 0.75) {
		return p.xz;
	}
	vec2 t = normalize(vec2(-n.z, n.x) + vec2(1e-4));
	return vec2(dot(p.xz, t), p.y);
}

// 砌块图案：返回 (砖内亮度变化, 灰缝遮罩)
vec2 bond(vec2 uv, vec2 cell, float joint) {
	float row = floor(uv.y / cell.y);
	uv.x += mod(row, 2.0) * cell.x * 0.5;
	vec2 id = vec2(floor(uv.x / cell.x), row);
	vec2 f = fract(uv / cell);
	vec2 jw = joint / cell;
	float m = step(jw.x, f.x) * step(jw.y, f.y);
	return vec2(hash12(id + 17.0), m);
}

void fragment() {
	vec3 p = wpos;
	vec3 n = normalize(wnrm);
	vec3 col = inst_slot >= 0 ? inst_col : base_color.rgb;
	if (use_vertex_base) { col *= COLOR.rgb; }
	vec3 base_c = col;
	float dist = length(VERTEX);
	float fade = (1.0 - smoothstep(45.0, 140.0, dist)) * detail;
	vec2 uv = face_uv(p, n);
	float big = fbm(p.xz * 0.05 + p.y * 0.03);
	float rough = 0.9;
	float metal = 0.0;
	float specv = 0.35;

	// Textured/atlas materials replace the procedural colour below. Avoid
	// calculating several octaves of noise whose result will be discarded.
	if (use_tex < 0.5 && use_uv < 0.5) {
	if (mtype == 0) {
		// 灰泥：大块色斑 + 细颗粒 + 底部雨渍
		float g = fbm(uv * 0.7);
		col *= 0.93 + 0.1 * g + 0.05 * (big - 0.5);
		float grain = vnoise(uv * 9.0);
		col *= 1.0 - 0.035 * grain * fade;
		// 墙角缝线（每层楼 3.4m 一道浅色腰线阴影）
		float stain = (1.0 - smoothstep(0.0, 2.2, hrel)) * (0.5 + 0.5 * vnoise(vec2(uv.x * 1.3, 0.0)));
		col = mix(col, col * vec3(0.86, 0.84, 0.8), stain * 0.35);
	} else if (mtype == 1) {
		vec2 b = bond(uv, vec2(0.52, 0.2), 0.035);
		vec3 brick = col * (0.82 + 0.3 * b.x) * (0.94 + 0.12 * vnoise(uv * 3.0));
		vec3 mortar = mix(col, vec3(0.86, 0.82, 0.74), 0.7);
		col = mix(col * (0.95 + 0.1 * big), mix(mortar, brick, b.y), fade);
	} else if (mtype == 2 || mtype == 9) {
		vec2 cell = mtype == 2 ? vec2(1.25, 0.62) : vec2(2.4, 1.2);
		vec2 b = bond(uv, cell, 0.05);
		float v = (0.9 + 0.16 * b.x) * (0.95 + 0.1 * fbm(uv * 1.7));
		col *= mix(1.0, v, fade);
		col = mix(col, col * 0.78, (1.0 - b.y) * fade * (mtype == 2 ? 0.8 : 0.35));
	} else if (mtype == 3 || mtype == 4) {
		// 屋顶瓦片：沿坡面向下的行 + 交错瓦缝 + 每片明暗
		vec2 t = normalize(vec2(-n.z, n.x) + vec2(1e-4));
		float along = dot(p.xz, t);
		float rowh = mtype == 3 ? 0.34 : 0.3;
		float tw = mtype == 3 ? 0.48 : 0.36;
		float r = p.y / rowh;
		if (abs(n.y) > 0.92) { r = p.z / rowh; along = p.x; }
		float row = floor(r);
		float fr = fract(r);
		float x = along / tw + mod(row, 2.0) * 0.5;
		float id = hash12(vec2(floor(x), row));
		float fx = fract(x);
		float tile = 0.88 + 0.22 * id;
		float lip = smoothstep(0.0, 0.22, fr);            // 每行下缘阴影
		float gap = smoothstep(0.0, 0.06, fx) * smoothstep(1.0, 0.94, fx);
		vec3 rc = col * tile * mix(0.72, 1.0, lip) * mix(0.82, 1.0, gap);
		if (mtype == 4) {
			rc *= 0.9 + 0.2 * smoothstep(0.2, 0.8, sin(fx * 3.14159));
		}
		col = mix(col * (0.95 + 0.08 * big), rc, fade);
	rough = mtype == 3 ? 0.62 : 0.5;
	specv = mtype == 3 ? 0.45 : 0.6;
		// 苔痕与褪色
		col = mix(col, col * vec3(0.9, 0.97, 0.88), smoothstep(0.55, 0.8, big) * 0.4);
	} else if (mtype == 5) {
		// 铜绿：竖向流痕 + 斑驳
		float s = fbm(vec2(uv.x * 2.5, uv.y * 0.35));
		col *= 0.85 + 0.25 * s;
		col = mix(col, col * vec3(1.15, 1.08, 0.9), smoothstep(0.6, 0.85, fbm(uv * 1.2)) * 0.5);
		rough = 0.5;
	metal = 0.55;
	} else if (mtype == 6) {
		rough = 0.8;
	specv = 0.3;
	float pl = uv.x / 0.24;
		float id = hash12(vec2(floor(pl), 3.0));
		float grain = vnoise(vec2(fract(pl) * 4.0 + id * 9.0, uv.y * 0.9));
		float edge = smoothstep(0.0, 0.08, fract(pl)) * smoothstep(1.0, 0.92, fract(pl));
		col *= mix(1.0, (0.85 + 0.25 * id) * (0.9 + 0.15 * grain) * mix(0.7, 1.0, edge), fade);
	} else if (mtype == 7) {
		col *= 0.92 + 0.12 * vnoise(uv * 2.0);
		rough = 0.45;
	metal = 0.7;
	specv = 0.5;
	} else if (mtype == 8) {
		// 植物：先按洛奇M 树冠色校正（去饱和 + 偏纯绿 + 压暗），再做团块明暗与顶部暖色高光
		float lum = dot(col, vec3(0.299, 0.587, 0.114));
		col = mix(vec3(lum), col, 0.72) * vec3(0.88, 0.95, 0.9);
		base_c = col;
		float lv = fbm(p.xz * 1.1 + p.y * 0.9);
		col *= 0.75 + 0.45 * lv;
	rough = 0.7;
	specv = 0.4;
		col = mix(col, col * vec3(1.08, 1.1, 0.88), smoothstep(0.55, 0.75, n.y * 0.5 + lv * 0.5) * 0.45);
	}
	} else {
		if (mtype == 3 || mtype == 4) { rough = mtype == 3 ? 0.62 : 0.5; specv = mtype == 3 ? 0.45 : 0.6; }
		else if (mtype == 5) { rough = 0.5; metal = 0.55; }
		else if (mtype == 6) { rough = 0.8; specv = 0.3; }
		else if (mtype == 7) { rough = 0.45; metal = 0.7; specv = 0.5; }
		else if (mtype == 8) {
			float lum = dot(col, vec3(0.299, 0.587, 0.114));
			base_c = mix(vec3(lum), col, 0.72) * vec3(0.88, 0.95, 0.9);
			rough = 0.7; specv = 0.4;
		}
	}
	float tex_l = 1.0;
	float rgh_m = 1.0;
	if (use_tex > 0.5) {
		vec2 tuv = uv;
		if (mtype == 3 || mtype == 4 || mtype == 5) {
			// 屋顶：u 沿屋檐方向，v 沿坡面向下（瓦片行水平）
			vec2 t2 = normalize(vec2(-n.z, n.x) + vec2(1e-4));
			float sl = max(length(n.xz), 0.25);
			tuv = abs(n.y) > 0.92 ? p.xz : vec2(dot(p.xz, t2), -p.y / sl);
		}
		// 手绘 RGB「乘数」贴图：×2 后均值 1，底色保持；逐块的色相 / 明度变化、笔触、边缘明暗全来自贴图
		vec3 tx = texture(tex_detail, tuv / tex_m).rgb;
		tex_l = dot(tx, vec3(0.3333)) * 2.0;
		vec3 tint = clamp(tx * 2.0, vec3(0.3), vec3(1.9));
		// 远处逐渐收敛到均值，避免瓦片 / 砖缝闪烁；近处全强度
		float strength = tex_strength * mix(0.55, 1.0, fade);
		col = base_c * mix(vec3(1.0), tint, strength);
		// 大尺度手绘色块：冷暖交替的整片水洗，打散贴图重复
		float wash = fbm(p.xz * 0.045 + p.y * 0.05 + 11.0);
		col *= mix(vec3(0.96, 0.97, 1.03), vec3(1.04, 1.02, 0.96), wash);
		col *= 0.96 + 0.08 * big;
		if (use_nrm > 0.5) {
			// 切线系和上面取 tuv 的方式一一对应：T = u 增大的世界方向，V = v 增大的世界方向（法线图 = N + nx·T + ny·V，见 pbr_maps.py）
			bool roof = mtype == 3 || mtype == 4 || mtype == 5;
			vec3 T = vec3(1.0, 0.0, 0.0);
			vec3 V = vec3(0.0, 0.0, 1.0);
			if (abs(n.y) <= (roof ? 0.92 : 0.75)) {
				T = normalize(vec3(-n.z, 0.0, n.x) + vec3(1e-4, 0.0, 0.0));
				V = roof ? normalize(vec3(0.0, -1.0, 0.0) - n * dot(vec3(0.0, -1.0, 0.0), n)) : vec3(0.0, 1.0, 0.0);
			}
			vec2 nxy = (texture(tex_nrm, tuv / tex_m).xy * 2.0 - 1.0) * nrm_str * (1.0 - smoothstep(35.0, 110.0, dist));
			vec3 nw = normalize(n + T * nxy.x + V * nxy.y);
			NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
			vec2 rg = texture(tex_rgh, tuv / tex_m).rg;
			rgh_m = mix(1.0, 0.5 + rg.x, 0.9);
			AO = mix(1.0, rg.y, 0.8);
			AO_LIGHT_AFFECT = 0.6;
		}
	}
	if (use_uv > 0.5) {
		col = texture(tex_detail, UV).rgb * base_color.rgb;
	}
	// 亮色上限：浅色墙在日光下不能冲成纯白（洛奇M 受光灰泥 / 石墙仍保留材质色），只压最亮的那一段
	float lum_c = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(1.0, 0.86, smoothstep(0.62, 0.92, lum_c));
	// 接地 AO 与顶部提亮
	float ao = mix(0.84, 1.0, smoothstep(0.0, 1.6, hrel));
	col *= mix(1.0, ao, ground_ao);
	col *= 1.0 + 0.04 * smoothstep(4.0, 18.0, hrel);
	ALBEDO = col;
	// PBR：按材质（贴图名 / mtype）给粗糙度 / 金属度 / 反射率；贴图明暗微调粗糙度（亮处 = 磨亮 / 擦痕 → 更光滑）
	if (pbr.x >= 0.0) {
		rough = pbr.x;
		metal = pbr.y;
		specv = pbr.z;
	} else if (mtype == 0) {
		rough = 0.95;
		specv = 0.2;
	} else if (mtype == 1) {
		rough = 0.88;
		specv = 0.3;
	} else if (mtype == 2 || mtype == 9) {
		rough = 0.82;
		specv = 0.4;
	}
	if (use_tex > 0.5) {
		rough = clamp(rough + (1.0 - tex_l) * 0.18, 0.12, 1.0);
		rough = clamp(rough * rgh_m, 0.1, 1.0);
	}
	if (use_uv > 0.5) {
		rough = 0.95;
		metal = 0.0;
		specv = 0.2;
	}
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = specv;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	DIFFUSE_LIGHT += storybook_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, 0.06);
	// 镜面项：标准 GGX（法线分布 + Smith 几何项 + Schlick 菲涅尔）。介电体 F0 = 0.04 × 反射量，金属用底色当 F0
	float nl = clamp(ndl, 0.0, 1.0);
	if (nl > 0.0 && ROUGHNESS < 0.97) {
		vec3 hv = normalize(LIGHT + VIEW);
		float nh = clamp(dot(NORMAL, hv), 0.0, 1.0);
		float nv = clamp(dot(NORMAL, VIEW), 0.001, 1.0);
		float vh = clamp(dot(VIEW, hv), 0.0, 1.0);
		float a = max(ROUGHNESS * ROUGHNESS, 0.03);
		float a2 = a * a;
		float dd = nh * nh * (a2 - 1.0) + 1.0;
		float D = a2 / (PI * dd * dd);
		float kk = (ROUGHNESS + 1.0) * (ROUGHNESS + 1.0) / 8.0;
		float G = (nl / (nl * (1.0 - kk) + kk)) * (nv / (nv * (1.0 - kk) + kk));
		vec3 f0 = mix(vec3(0.04 * SPECULAR_AMOUNT), ALBEDO, METALLIC);
		vec3 F = f0 + (vec3(1.0) - f0) * pow(1.0 - vh, 5.0);
		SPECULAR_LIGHT += min(D * G, 40.0) * F / max(4.0 * nv, 0.01) * LIGHT_COLOR * ATTENUATION;
	}	// 受光面一圈很柔的暖色边缘（BotW 式「软轮廓光」，只提亮明暗交界，不产生白斑）
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0) * smoothstep(0.1, 0.6, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * rim * 0.05 * ATTENUATION * vec3(1.0, 0.92, 0.8);
}
