"""Painted base colour maps plus rough, light-responsive game materials.

User correction 2026-10-05 supersedes the v1 unlit display direction.
Textures contain pigment variation only: no baked shadows or directional light.
"""
import bpy, math, struct, zlib, json
from pathlib import Path
import numpy as np
import geometry as G

COLORS={
 'plaster':'E4C6A4','plaster_patch':'D6B695','timber':'533D2C','wood':'896243',
 'terracotta':'B96643','tile_dark':'9E5038','tile_light':'CB7A50','tile_warm':'B9764E',
 'sandstone':'C9B696','stone_dark':'AB9779','stone_light':'DFCEAE','stone_mid':'BDA987',
 'iron':'494941','glass':'529C9D','glass_amber':'D8AF64','moss':'72814D',
 'leaf':'637B43','leaf_light':'819055','leaf_dark':'4C6338','cloth':'A95137','flower':'D7A797',
 'ground':'D8C8AA','grout':'AB9B80','interior':'796C57'}
COLOR_KEYS={}
LIGHT_PALETTE=None

def use_game_palette():
    global LIGHT_PALETTE,COLOR_KEYS
    source=Path(__file__).resolve().parents[3]/'docs/abbey_kit_v2/palette_architecture.json'
    data=json.loads(source.read_text(encoding='utf8'));COLOR_KEYS=data['material_mapping']
    for recipe,palette in COLOR_KEYS.items():COLORS[recipe]=data['colors'][palette]
    LIGHT_PALETTE=data['colors']
    return data

def light_rgb(key,fallback):
    if LIGHT_PALETTE is None:return fallback
    h=LIGHT_PALETTE[key];return tuple(G.linear(int(h[i:i+2],16)) for i in (0,2,4))

def write_png(path,array):
    h,w,c=array.shape
    def chunk(name,data):return struct.pack('>I',len(data))+name+data+struct.pack('>I',zlib.crc32(name+data)&0xffffffff)
    raw=b''.join(b'\0'+array[y].tobytes() for y in range(h))
    Path(path).write_bytes(b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>IIBBBBB',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(raw,8))+chunk(b'IEND',b''))

def pigment(key,path):
    n=256;y,x=np.mgrid[0:n,0:n]/n
    rng=np.random.default_rng(sum((i+1)*ord(c) for i,c in enumerate(key)))
    # All periodic pigment variation, so each map repeats without seams.
    variation=np.zeros((n,n))
    for k in range(6):
        a,b=rng.integers(1,8,size=2);phase=rng.uniform(0,math.tau)
        variation += np.sin(math.tau*(a*x+b*y)+phase)*(.0035 if k>2 else .009)
    if key in ('wood','timber'):
        w=x+.016*np.sin(math.tau*y)+.008*np.sin(math.tau*(3*y+x))
        grain=np.sin(math.tau*19*w)+.4*np.sin(math.tau*43*w)
        variation += .016*grain + .01*np.sin(math.tau*(3*x+y))
    elif key.startswith('tile') or key=='terracotta':
        variation+=.012*np.sin(math.tau*(4*x+.12*np.sin(math.tau*y)))
    elif 'stone' in key or 'plaster' in key:
        # Coarse brush patches; no photoreal pores or high frequency grit.
        variation += .012*np.sign(np.sin(math.tau*3*x+.6*np.sin(math.tau*y))*np.sin(math.tau*5*y))
    base=np.array([int(COLORS[key][i:i+2],16)/255 for i in (0,2,4)])
    rgb=np.clip(base[None,None,:]+variation[:,:,None]*np.array([1,.91,.73]),0,1)
    write_png(path,np.round(rgb*255).astype(np.uint8))

def install(out):
    folder=Path(out)/'textures';folder.mkdir(parents=True,exist_ok=True);cache={}
    G.PALETTE.update(COLORS);G.MATS.clear()
    def material(key):
        if key in cache:return cache[key]
        if key not in COLORS:COLORS[key]=G.PALETTE[key]
        h=COLORS[key];linear=tuple(G.linear(int(h[i:i+2],16)) for i in (0,2,4))+(1,)
        m=bpy.data.materials.new('ABY2_'+COLOR_KEYS.get(key,key));m.use_nodes=True;m.diffuse_color=linear
        m['recipe_key']=key;m['palette_key']=COLOR_KEYS.get(key,key);m['base_color_srgb']=h
        nodes=m.node_tree.nodes;nodes.clear();outnode=nodes.new('ShaderNodeOutputMaterial');p=nodes.new('ShaderNodeBsdfPrincipled')
        p.inputs['Base Color'].default_value=linear;p.inputs['Roughness'].default_value=.88
        p.inputs['Specular IOR Level'].default_value=.22
        if key in ('glass','glass_amber'):
            p.inputs['Roughness'].default_value=.3;p.inputs['Specular IOR Level'].default_value=.38
            # Stained glass is a stylized coloured surface, not emissive/unlit paint.
            p.inputs['Coat Weight'].default_value=.18;p.inputs['Coat Roughness'].default_value=.25
        elif key=='iron':p.inputs['Metallic'].default_value=.52;p.inputs['Roughness'].default_value=.64
        else:
            file=folder/f'{key}_basecolor.png';pigment(key,file)
            im=bpy.data.images.load(str(file),check_existing=True);im.pack();tex=nodes.new('ShaderNodeTexImage');tex.image=im;tex.extension='REPEAT';tex.interpolation='Linear'
            m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
        m.node_tree.links.new(p.outputs['BSDF'],outnode.inputs['Surface']);cache[key]=m;return m
    G.material=material
    return cache

def light_scene(scene):
    world=bpy.data.worlds.new('ABY2_warm_studio');world.use_nodes=True
    nodes=world.node_tree.nodes;nodes.clear();bg=nodes.new('ShaderNodeBackground');out=nodes.new('ShaderNodeOutputWorld')
    bg.inputs[0].default_value=light_rgb('ambient',(.72,.79,.88))+(1,);bg.inputs[1].default_value=.48;world.node_tree.links.new(bg.outputs[0],out.inputs[0]);scene.world=world
    scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
    scene.cycles.max_bounces=5;scene.cycles.diffuse_bounces=3;scene.cycles.glossy_bounces=3
    scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast';scene.view_settings.exposure=-.15
    from mathutils import Vector
    for name,loc,power,size,color in [
      ('KEY_soft_daylight',(-15,6,26),4400,11,(1,.87,.70)),
      ('FILL_cool_sky',(14,8,18),1100,14,(.77,.87,1)),
      ('RIM_soft_sky',(-6,-18,23),2000,12,(1,.93,.82))]:
        d=bpy.data.lights.new(name,'AREA');d.energy=power;d.shape='DISK';d.size=size;d.color=light_rgb('ambient' if 'FILL' in name else 'sun',color)
        o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((-1,0,3))-o.location).to_track_quat('-Z','Y').to_euler()
    sun=bpy.data.lights.new('SOFT_SUN','SUN');sun.energy=1.35;sun.angle=math.radians(13);sun.color=light_rgb('sun',(1,.88,.72))
    o=bpy.data.objects.new('SOFT_SUN',sun);scene.collection.objects.link(o);o.rotation_euler=(math.radians(26),math.radians(-30),math.radians(-25))
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
