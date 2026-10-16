shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f); return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y); }
void fragment() {
    float y=1.0-UV.y;
    float n=noise(vec2(UV.x*6.0,UV.y*4.0+TIME*2.2));
    float center=0.5+sin(y*8.0-TIME*3.0)*y*0.07;
    float width=(1.0-y)*0.35+(n-0.5)*0.18;
    float flame=smoothstep(width+0.045,width-0.04,abs(UV.x-center))*smoothstep(0.0,0.12,y);
    flame*=1.0-smoothstep(0.67+n*0.2,1.0,y);
    ALBEDO=mix(vec3(1.0,0.12,0.008),vec3(1.0,0.83,0.25),pow(1.0-y,2.0));
    EMISSION=ALBEDO*2.4;
    ALPHA=flame*0.88;
}
