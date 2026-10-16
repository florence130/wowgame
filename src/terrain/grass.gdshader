shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;
#include "res://src/render/storybook_light.gdshaderinc"
// Cartoon Grass and Plants 1.01 Godot port:
// BottomColor/TopColor/GradientHeight + vertex-height wind strength, atlas cutout,
// world-space wind offset and distance LOD. No player displacement.
global uniform float env_wind;
global uniform float env_motion_time;
uniform sampler2D plant_atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D control_a : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D control_b : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D tex0 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex7 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tex8 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 col0 : source_color = vec3(0.47, 0.71, 0.32);
uniform vec3 col1 : source_color = vec3(0.30, 0.52, 0.24);
uniform vec3 col7 : source_color = vec3(0.58, 0.76, 0.36);
uniform vec3 col8 : source_color = vec3(0.27, 0.33, 0.22);
uniform vec3 meadow_color : source_color = vec3(0.40, 0.54, 0.33);
uniform vec2 terrain_origin;
uniform float terrain_size = 512.0;
uniform float tile_m = 7.0;
uniform float fade_start = 48.0;
uniform float fade_end = 66.0;
varying float hfac;
varying vec3 wroot;
varying vec3 tint;
varying vec3 meadow_normal;
void vertex() {
    hfac = clamp(VERTEX.y / 0.56, 0.0, 1.0);
    tint = INSTANCE_CUSTOM.rgb;
    vec3 root = MODEL_MATRIX[3].xyz;
    wroot = root;
    vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float d = distance(root.xz, CAMERA_POSITION_WORLD.xz);
    float keep = 1.0 - smoothstep(fade_start, fade_end, d);
    float gust = texture(noise_tex, root.xz * 0.008 - vec2(env_motion_time * 0.025, env_motion_time * 0.017)).r;
    float wave = sin(env_motion_time * 1.8 + root.x * 0.8 + root.z * 0.6);
    vec2 wind = vec2(0.85, 0.5) * (0.25 + gust + wave * 0.16) * env_wind * hfac * hfac;
    wp.xz += wind;
    wp.y -= length(wind) * 0.25 * hfac;
    wp.y = mix(root.y, wp.y, keep);
    VERTEX = (inverse(MODEL_MATRIX) * vec4(wp, 1.0)).xyz;
    meadow_normal = normalize(mix(vec3(0.0, 1.0, 0.0), normalize(MODEL_NORMAL_MATRIX * NORMAL), 0.20));
}
vec3 terrain_tint(vec3 c, vec3 d) { return clamp(c / max(d, vec3(0.05)), vec3(0.5), vec3(1.6)); }
vec3 samp(sampler2D t, vec2 p, float m) {
    vec2 uv = p / tile_m;
    mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
    return mix(texture(t, uv, 0.8).rgb, texture(t, r * uv * 0.37 + vec2(0.31, 0.17), 0.8).rgb, m);
}
void fragment() {
    vec4 source = texture(plant_atlas, UV);
    if (source.a < 0.55) { discard; }
    vec2 uv = (wroot.xz - terrain_origin) / terrain_size;
    vec4 a = texture(control_a, uv);
    vec4 b = texture(control_b, uv);
    float m = smoothstep(0.35, 0.65, texture(noise_tex, wroot.xz * 0.006 + vec2(0.5)).r);
    vec3 ground = samp(tex0, wroot.xz, m) * terrain_tint(col0, vec3(0.47, 0.71, 0.32));
    ground = mix(ground, samp(tex1, wroot.xz, m) * terrain_tint(col1, vec3(0.30, 0.52, 0.24)), a.r);
    ground = mix(ground, samp(tex7, wroot.xz, m) * terrain_tint(col7, vec3(0.58, 0.76, 0.36)), b.b);
    ground = mix(ground, samp(tex8, wroot.xz, m) * terrain_tint(col8, vec3(0.27, 0.33, 0.22)), b.a);
    ground = mix(ground, meadow_color * terrain_tint(col0, vec3(0.47, 0.71, 0.32)), 0.78);
    float mac = smoothstep(0.3, 0.75, texture(noise_tex, wroot.xz * 0.0045 + vec2(0.17, 0.61)).r);
    ground *= mix(vec3(1.0), mix(vec3(0.94, 1.0, 1.02), vec3(1.06, 1.025, 0.94), mac), 0.6);
    ground *= 0.96 + 0.08 * texture(noise_tex, wroot.xz * 0.013).r;
    vec3 leaf = ground * mix(0.90, 1.12, smoothstep(0.0, 1.0, hfac));
    float foliage = smoothstep(0.005, 0.04, source.g - max(source.r, source.b));
    vec3 petal = mix(source.rgb, vec3(0.95, 0.90, 0.77), 0.16);
    ALBEDO = mix(petal, leaf * tint, foliage);
    NORMAL = normalize((VIEW_MATRIX * vec4(meadow_normal, 0.0)).xyz);
    ROUGHNESS = 1.0;
    AO = mix(0.88, 1.0, hfac);
    AO_LIGHT_AFFECT = 0.12;
}
void light() { DIFFUSE_LIGHT += storybook_diffuse(NORMAL, LIGHT, LIGHT_COLOR, ATTENUATION, 0.22); }
