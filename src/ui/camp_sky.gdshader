shader_type sky;
render_mode use_debanding;
uniform sampler2D cloud_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_detail_tex : filter_linear_mipmap, repeat_enable;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
    vec2 i=floor(p), f=fract(p); f=f*f*(3.0-2.0*f);
    return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void sky() {
    float h=clamp(EYEDIR.y,0.0,1.0);
    vec3 col=mix(vec3(0.012,0.065,0.14),vec3(0.003,0.01,0.04),pow(h,0.45));
    vec2 p=SKY_COORDS*vec2(900,450);
    float star=smoothstep(0.15,0.0,length(fract(p)-0.5))*step(0.991,hash(floor(p)));
    col+=star*vec3(0.55,0.72,1.0)*smoothstep(0.0,0.25,h);
    vec3 d=normalize(vec3(0.08,0.14,-1.0));
    float m=length(EYEDIR-d);
    col+=vec3(0.09,0.24,0.38)*exp(-m*16.0);
    col=mix(col,vec3(0.55,0.87,1.0)*(0.65+0.35*noise(EYEDIR.xy*150.0)),smoothstep(0.027,0.025,m));
    vec2 cloud_uv=EYEDIR.xz/(h+0.18)*0.22+vec2(TIME*0.0006,TIME*0.0002);
    float cloud=texture(cloud_tex,cloud_uv).r*0.84+texture(cloud_detail_tex,cloud_uv*2.1).r*0.16;
    col=mix(col,vec3(0.055,0.12,0.22),smoothstep(0.61,0.7,cloud)*smoothstep(0.01,0.1,h)*0.65);
    COLOR=col;
}
