shader_type sky;

uniform vec3 top_color : source_color = vec3(0.32, 0.55, 0.9);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.87, 0.97);
uniform vec3 ground_color : source_color = vec3(0.45, 0.5, 0.55);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float night = 0.0;
uniform float cloud_cover = 0.3;
uniform vec3 cloud_tint : source_color = vec3(1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// 改编自参考素材的月面与星图（tools/reftexture/adapt_env.py）
uniform sampler2D moon_tex : source_color, filter_linear_mipmap;
uniform sampler2D stars_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float has_moon_tex = 0.0;
uniform float has_stars_tex = 0.0;
// Super Simple Skybox 5.0: gradients, two pan/threshold cloud layers and stars.
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_detail_tex : filter_linear_mipmap, repeat_enable;
uniform float wind_speed = 0.14;
uniform float cloud_time = 0.0;
uniform float overcast = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	// 洛奇M 式三段天空：地平线雾白 → 中段亮蓝 → 天顶深饱和蓝
	vec3 mid = mix(horizon_color, top_color, 0.55);
	vec3 col = mix(horizon_color, mid, smoothstep(-0.02, 0.18, h));
	col = mix(col, top_color, smoothstep(0.18, 0.7, h));
	col = mix(col, ground_color, 1.0 - smoothstep(-0.25, 0.0, h));
	// 太阳
	float sd = dot(d, normalize(sun_dir));
	col += sun_color * smoothstep(0.9990, 0.9994, sd) * 2.0 * (1.0 - overcast * 0.94);
	col += sun_color * pow(max(sd, 0.0), 48.0) * 0.30 * (1.0 - night) * (1.0 - overcast);
	// 月亮
	float md = dot(d, normalize(moon_dir));
	if (has_moon_tex > 0.5) {
		// 月面贴图：在月亮方向建局部切平面，角半径约 2.6°
		vec3 mz = normalize(moon_dir);
		vec3 mx = normalize(cross(abs(mz.y) > 0.98 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0), mz));
		vec3 my = cross(mz, mx);
		vec2 muv = vec2(dot(d, mx), -dot(d, my)) / 0.045 * 0.5 + 0.5;
		if (md > 0.99 && muv.x > 0.0 && muv.y > 0.0 && muv.x < 1.0 && muv.y < 1.0) {
			vec4 mt = texture(moon_tex, muv);
			col = mix(col, mt.rgb * 1.25, mt.a * night * (1.0 - overcast));
		}
	} else {
		col += vec3(0.9, 0.92, 1.0) * smoothstep(0.9993, 0.9996, md) * night * 2.0;
	}
	// A broad, very soft halo keeps the moon readable even when the camera is
	// not pointed directly at the small textured disk.  It also gives clouds
	// and haze a cool rim, which sells moonlight instead of a flat blue filter.
	col += vec3(0.28, 0.38, 0.68) * pow(max(md, 0.0), 24.0) * 0.22 * night * (1.0 - overcast * 0.72);
	col += vec3(0.5, 0.6, 0.9) * pow(max(md, 0.0), 80.0) * 0.30 * night * (1.0 - overcast * 0.55);
	// 星星
	float star_night = smoothstep(0.55, 0.95, night);
	if (star_night > 0.01 && h > 0.0 && has_stars_tex > 0.5) {
		vec2 suv2 = vec2(atan(d.z, d.x) / 6.2832 + 0.5 + TIME * 0.0004, acos(clamp(d.y, -1.0, 1.0)) / 3.1416);
		vec3 st = texture(stars_tex, suv2 * vec2(2.0, 1.6)).rgb;
		float tw = 0.75 + 0.25 * sin(TIME * 1.7 + dot(d, vec3(91.0, 47.0, 13.0)));
		col += st * 0.30 * tw * star_night * (1.0 - overcast) * smoothstep(0.0, 0.3, h);
	} else if (star_night > 0.01 && h > 0.0) {
		vec2 suv = d.xz / (d.y + 0.25) * 90.0;
		vec2 cell = floor(suv);
		float s = hash(cell);
		float tw = 0.6 + 0.4 * sin(TIME * 2.0 + s * 50.0);
		float star = step(0.992, s) * smoothstep(0.35, 0.0, length(fract(suv) - 0.5)) * tw;
		col += vec3(star) * star_night * smoothstep(0.0, 0.3, h);
	}
	// 云层（洛奇M 式手绘积云：边缘柔和、顶部亮白、底部蓝灰，按太阳方向略亮）
	if (h > 0.0) {
		// Planar direction projection has no equirectangular wrap seam.
		vec2 cuv = d.xz / (h + 0.18) * 0.22 + vec2(cloud_time * 0.002, cloud_time * 0.0008);
		float broad = texture(cloud_tex, cuv).r;
		float detail = texture(cloud_detail_tex, cuv * 2.1 - vec2(cloud_time * 0.0007)).r;
		float c = broad * 0.84 + detail * 0.16;
		float thr = mix(0.67, 0.21, cloud_cover);
		float cl = smoothstep(thr, thr + 0.08, c);
		vec3 cloud_key = mix(sun_dir, moon_dir, night);
		float light_side = broad - texture(cloud_tex, cuv + normalize(cloud_key.xz + vec2(0.001)) * 0.025).r;
		float shade = smoothstep(-0.12, 0.15, light_side);
		vec3 dark = cloud_tint * mix(vec3(0.68, 0.78, 0.88), vec3(0.35, 0.43, 0.54), overcast);
		vec3 cc = mix(dark, cloud_tint * 1.08, 0.25 + shade * 0.75);
		cc += sun_color * pow(max(sd, 0.0), 6.0) * 0.08 * (1.0 - night);
		vec3 night_cloud = cc * vec3(0.09, 0.12, 0.20);
		night_cloud += vec3(0.14, 0.20, 0.34) * pow(max(md, 0.0), 8.0) * 0.06 * (1.0 - overcast);
		cc = mix(cc, night_cloud, night);
		col = mix(col, cc, cl * smoothstep(0.0, 0.1, h) * 0.95);
	}
	// Keep the lunar disk readable through the procedural cloud layer.  The
	// cloud pass intentionally comes before this small overlay so a dense cloud
	// bank can soften the halo without hiding the only clear night landmark.
	if (has_moon_tex > 0.5 && night > 0.01) {
		vec3 moon_z_final = normalize(moon_dir);
		vec3 moon_x_final = normalize(cross(abs(moon_z_final.y) > 0.98 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0), moon_z_final));
		vec3 moon_y_final = cross(moon_z_final, moon_x_final);
		vec2 moon_uv_final = vec2(dot(d, moon_x_final), -dot(d, moon_y_final)) / 0.045 * 0.5 + 0.5;
		if (md > 0.99 && moon_uv_final.x > 0.0 && moon_uv_final.y > 0.0 && moon_uv_final.x < 1.0 && moon_uv_final.y < 1.0) {
			vec4 moon_sample_final = texture(moon_tex, moon_uv_final);
			col = mix(col, moon_sample_final.rgb * 1.35, moon_sample_final.a * night * (1.0 - overcast * 0.35));
		}
	}
	COLOR = col;
}
