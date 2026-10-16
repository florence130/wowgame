shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// Stylized Water For URP 1.1.2 adaptation: depth color, Gerstner waves,
// panned dual normals, warped foam, shore intersections, subtle caustics.
global uniform float env_wind;
global uniform float env_motion_time;
global uniform float env_rain;
global uniform float env_night;
global uniform vec4 env_sky_tint : source_color;
// Keep shallow water readable as water instead of exposing the bright sand
// underneath through a half-transparent, milky fringe.
// Keep the lake blue-green and readable at noon.  The former mint values were
// being composited over the sand below, so the whole basin read as a pale
// opaque sheet instead of having a shallow-to-deep water gradient.
uniform vec4 shallow : source_color = vec4(0.24, 0.52, 0.64, 0.92);
uniform vec4 mid_col : source_color = vec4(0.13, 0.39, 0.56, 0.94);
uniform vec4 deep : source_color = vec4(0.045, 0.22, 0.38, 0.98);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D height_tex : hint_default_black, filter_linear, repeat_disable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D caustics_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
uniform vec2 terrain_origin;
uniform float terrain_size = 512.0;
uniform float water_level = 0.0;
uniform float has_height = 0.0;
// Outer-ocean materials receive every loaded terrain rectangle. Their own
// height-aware lake/river surface renders inside, so oceans never flood coarse land.
uniform int land_rect_count = 0;
uniform vec4 land_rects[8];
uniform float wave_strength = 1.0;
uniform float wave_geometry = 1.0;
// Small basins need visible shallow water above their solid stone base.
uniform float minimum_depth = 0.0;
// Shore foam is kept as a thin, broken band.  The source foam texture is a
// high-frequency filament map; using it directly over the whole shallow
// region made every beach read as a solid white strip.
uniform float foam_strength = 0.38;
uniform float foam_scale = 0.055;
varying vec3 wpos;
varying vec3 wave_normal;
vec3 gerstner(vec3 p, vec2 direction, float wavelength, float steepness, float speed, inout vec3 tangent, inout vec3 binormal) {
    vec2 d = normalize(direction);
    float k = 6.283185 / wavelength;
    float phase = k * (dot(d, p.xz) - speed * env_motion_time);
    float s = steepness * wave_strength * (0.65 + env_wind * 2.5) * wave_geometry;
    tangent += vec3(-d.x*d.x*s*sin(phase), d.x*s*cos(phase), -d.x*d.y*s*sin(phase));
    binormal += vec3(-d.x*d.y*s*sin(phase), d.y*s*cos(phase), -d.y*d.y*s*sin(phase));
    return vec3(d.x*cos(phase), sin(phase), d.y*cos(phase)) * (s / k);
}
void vertex() {
    vec3 p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    vec3 tangent = vec3(1.0, 0.0, 0.0);
    vec3 binormal = vec3(0.0, 0.0, 1.0);
    vec3 offset = gerstner(p, vec2(0.8,0.5), 13.0, 0.045, 1.3, tangent, binormal);
    offset += gerstner(p, vec2(-0.3,0.9), 6.0, 0.025, 0.9, tangent, binormal);
    if (has_height > 0.5) {
        vec2 huv = (p.xz - terrain_origin) / terrain_size;
        float edge = max(abs(huv.x - 0.5), abs(huv.y - 0.5)) * 2.0;
        offset *= 1.0 - smoothstep(0.85, 1.0, edge);
    }
    wpos = p + offset;
    VERTEX = (inverse(MODEL_MATRIX) * vec4(wpos, 1.0)).xyz;
    wave_normal = normalize(cross(binormal, tangent));
}
void fragment() {
    for (int i = 0; i < 8; i++) {
        if (i >= land_rect_count) { break; }
        vec4 r = land_rects[i];
        if (wpos.x >= r.x && wpos.z >= r.y && wpos.x <= r.z && wpos.z <= r.w) {
            discard;
        }
    }
    float raw_depth = texture(scene_depth, SCREEN_UV).r;
    vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, raw_depth);
    #if CURRENT_RENDERER == RENDERER_COMPATIBILITY
    ndc.z = raw_depth * 2.0 - 1.0;
    #endif
    vec4 behind = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
    float depth = max(0.0, -behind.z / behind.w + VERTEX.z);
    vec2 huv = (wpos.xz - terrain_origin) / terrain_size;
    if (has_height > 0.5) {
        depth = 30.0;
        if (huv.x > 0.0 && huv.y > 0.0 && huv.x < 1.0 && huv.y < 1.0) {
            float ground_height = texture(height_tex, huv).r;
            if (ground_height > wpos.y + 0.03) { discard; }
            depth = max(0.0, water_level - ground_height);
            float edge = max(abs(huv.x - 0.5), abs(huv.y - 0.5)) * 2.0;
            depth = mix(depth, 30.0, smoothstep(0.9, 1.0, edge));
        }
    }
    depth = clamp(max(depth, minimum_depth), 0.0, 30.0);
    vec4 c = mix(mix(shallow, mid_col, smoothstep(0.0, 3.5, depth)), deep, smoothstep(3.0, 14.0, depth));
    vec2 flow = vec2(env_motion_time * 0.007, env_motion_time * 0.004);
    vec3 n1 = texture(normal_tex, wpos.xz * 0.085 + flow).rgb * 2.0 - 1.0;
    vec3 n2 = texture(normal_tex, wpos.xz * 0.043 - flow * 0.6 + vec2(0.31)).rgb * 2.0 - 1.0;
    vec3 nn = normalize(wave_normal + vec3((n1.x+n2.x)*0.20, 0.0, (n1.y+n2.y)*0.20));
    NORMAL = normalize((VIEW_MATRIX * vec4(nn, 0.0)).xyz);
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
    // Sky reflection supplies a soft highlight, but a large factor washes the
    // whole rim of the lake into the same pale value as the foam.
    vec3 col = mix(c.rgb, env_sky_tint.rgb, fresnel * 0.22);
    // A larger foam pattern gives the shoreline a few readable scallops
    // instead of the dense lace seen when the 512px source is tiled at 0.11.
    vec2 fuv = wpos.xz * foam_scale + flow * 1.15;
    fuv += vec2(sin(fuv.y * 4.0 + env_motion_time * 0.3), cos(fuv.x * 3.5)) * 0.028;
    float texture_foam = texture(foam_tex, fuv).r;
    float foam_detail = texture(foam_tex, fuv * 2.17 - flow * 0.35 + vec2(0.37)).r;
    // Fade in just below the waterline and out before the foam can cover the
    // whole shallow shelf.  The higher threshold and second sample break the
    // source filament map into separated patches.
    float shore_band = smoothstep(0.02, 0.10, depth) * (1.0 - smoothstep(0.32, 0.78, depth));
    // A low-frequency breakup mask prevents the foam texture from tracing a
    // continuous white outline around every lobe of the lake. Let the mask
    // reach zero so some stretches of the calm shoreline have no white lace.
    float shore_break = texture(noise_tex, wpos.xz * 0.018 + flow * 0.12).r;
    float breakup = smoothstep(0.42, 0.66, shore_break);
    float foam_pattern = smoothstep(0.45, 0.70, texture_foam) * (0.62 + foam_detail * 0.38) * breakup;
    float edge_foam = shore_band * foam_pattern * foam_strength;
    float shore_wave = fract(depth * 0.7 - env_motion_time * 0.18);
    float ring = smoothstep(0.84, 0.92, shore_wave) * (1.0 - smoothstep(0.97, 1.0, shore_wave));
    ring *= (1.0 - smoothstep(0.30, 0.78, depth)) * smoothstep(0.58, 0.82, texture_foam) * breakup * 0.26;
    float foam = max(edge_foam, ring);
    // Surface flecks are intentionally restrained; they should suggest wind
    // on open water without turning the lake into a field of white pixels.
    float surface_foam = smoothstep(0.86, 0.96, texture_foam) * (0.018 + env_rain * 0.07);
    vec3 foam_col = mix(vec3(0.76, 0.88, 0.87), vec3(0.86, 0.94, 0.93), env_rain * 0.35);
    col = mix(col, foam_col, clamp(max(foam, surface_foam), 0.0, 1.0));
    float caustic = texture(caustics_tex, wpos.xz * 0.22 + flow).r;
    col += caustic * 0.045 * (1.0 - smoothstep(0.3, 4.0, depth)) * (1.0 - env_night);
    ALBEDO = col;
    // Foam is an albedo accent, not a second transparent surface.  Letting it
    // raise ALPHA made the broken shoreline patches render as opaque white
    // decals and produced the harsh band visible in the lake close-up.
    ALPHA = c.a;
    ROUGHNESS = mix(0.28, 0.48, env_rain);
    SPECULAR = 0.38;
}
