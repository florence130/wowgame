import sys,json,struct,math
from pathlib import Path
sys.path[:0]=[r'E:\wowgame\tools\blender\abbey_kit_v3',r'E:\wowgame\tools\blender\abbey_kit_v2',r'E:\wowgame\tools\blender\abbey_kit']
import bpy
from mathutils import Vector
import geometry as G
import details as D
import glass as GL

OUT=Path(r'E:\wowgame\.local\abbey_glass_probe')
SOURCE=Path(r'E:\wowgame\assets\models\abbey_kit_v3\build004\glb\window_clerestory.glb')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
window=list(bpy.context.scene.objects)
window_mats=[m for m in bpy.data.materials if m.get('recipe_key') in GL.WINDOW_COLORS]
assert len(window_mats)==2,[dict(m.items()) for m in bpy.data.materials]
# Prove the separately keyed lantern shader is untouched, without adding a lamp.
lamp=bpy.data.materials.new('ProbeOnly_ProtectedLanternMaterial');lamp.use_nodes=True
lamp.node_tree.nodes.clear();lp=lamp.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
lamp['recipe_key']='window_glow';lp.inputs['Alpha'].default_value=.58;lp.inputs['Emission Strength'].default_value=2.7
protected_before=(lp.inputs['Alpha'].default_value,lp.inputs['Emission Strength'].default_value)
configured=GL.configure()
protected_after=(lp.inputs['Alpha'].default_value,lp.inputs['Emission Strength'].default_value)
assert protected_before==protected_after
bpy.ops.object.select_all(action='DESELECT')
for o in window:o.select_set(True)
bpy.context.view_layer.objects.active=next(o for o in window if o.type=='MESH')
bpy.ops.export_scene.gltf(filepath=str(OUT/'window_transparent.glb'),export_format='GLB',use_selection=True,export_extras=True)
raw=(OUT/'window_transparent.glb').read_bytes();n,t=struct.unpack_from('<II',raw,12);gltf=json.loads(raw[20:20+n])
exported=[]
for m in gltf['materials']:
    if m.get('extras',{}).get('recipe_key') not in GL.WINDOW_COLORS:continue
    e={'name':m['name'],'recipe_key':m['extras']['recipe_key'],'alphaMode':m.get('alphaMode','OPAQUE'),
       'baseColorFactor':m['pbrMetallicRoughness'].get('baseColorFactor'),
       'extensions':m.get('extensions',{}),'emissiveFactor':m.get('emissiveFactor',[0,0,0])}
    assert e['alphaMode']=='BLEND',e
    assert 0<e['baseColorFactor'][3]<1,e
    assert 'KHR_materials_unlit' not in e['extensions'],e
    exported.append(e)
assert len(exported)==2
print('GLASS_GLB_OK',json.dumps(exported),flush=True)
# Geometry is from the shipped GLB; only translate its base to the probe floor.
points=[o.matrix_world@Vector(corner) for o in window if o.type=='MESH' for corner in o.bound_box]
z0=min(p.z for p in points)
for o in window:
    if o.parent not in window:o.location.z-=z0
bpy.context.view_layer.update()
glass_points=[]
for o in window:
    if o.type!='MESH':continue
    for poly in o.data.polygons:
        if o.data.materials[poly.material_index].get('recipe_key')=='glass':
            glass_points.extend(o.matrix_world@o.data.vertices[i].co for i in poly.vertices)
width=max(p.x for p in glass_points)-min(p.x for p in glass_points)
sill=min(p.z for p in glass_points);height=max(p.z for p in glass_points)-sill
G.COL=bpy.context.scene.collection;G.ROOT=None
cache={}
def matte(key):
    if key in cache:return cache[key]
    colors={'wall':(.60,.59,.56,1),'floor':(.72,.70,.64,1),'dark':(.12,.16,.18,1),
            'white':(.86,.84,.78,1),'red':(.55,.055,.025,1),'blue':(.025,.19,.48,1)}
    m=bpy.data.materials.new('Probe_'+key);m.use_nodes=True;m.node_tree.nodes.clear()
    p=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled');p.inputs['Base Color'].default_value=colors[key];p.inputs['Roughness'].default_value=.85
    out=m.node_tree.nodes.new('ShaderNodeOutputMaterial');m.node_tree.links.new(p.outputs['BSDF'],out.inputs['Surface']);cache[key]=m;return m
G.material=matte
wall=G.box('Actual aperture surround',(3.7,.26,3.5),(0,-.085,1.7),'wall')
cutter=G.profile('Matching actual pointed aperture',D.pointed_outline(width+.006,height+.006,sill-.003),.8,None)
G.subtract(wall,cutter)
G.box('Interior daylight receiving floor',(4.0,6,.10),(0,-1.5,-.05),'floor')
G.box('Interior ceiling light baffle',(4,3.2,.1),(0,-1.7,3.4),'wall')
G.box('Interior back wall',(4,.1,3.4),(0,-3.25,1.7),'wall')
for x in (-1.95,1.95):G.box('Interior side wall',(.10,3.2,3.4),(x,-1.7,1.7),'wall')
for col in range(4):
    for row in range(6):
        G.box('Checker physically behind glass',(.235,.028,.235),(-.3525+col*.235,-1.25,.48+row*.235),'white' if (row+col)%2==0 else 'dark')
G.box('RED CUBE visibly behind glazing',(.27,.27,.27),(-.25,-.62,.73),'red',.015)
G.box('BLUE CUBE visibly behind glazing',(.23,.23,.38),(.27,-.73,1.18),'blue',.015)
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
scene.cycles.max_bounces=10;scene.cycles.transmission_bounces=8;scene.cycles.transparent_max_bounces=16
device='CPU'
try:
    pref=bpy.context.preferences.addons['cycles'].preferences;pref.compute_device_type='OPTIX';pref.get_devices()
    for d in pref.devices:d.use=d.type=='OPTIX'
    if any(d.use for d in pref.devices):scene.cycles.device='GPU';device='OPTIX'
except Exception:pass
world=bpy.data.worlds.new('Low ambient proof');world.use_nodes=True;world.node_tree.nodes.clear()
bg=world.node_tree.nodes.new('ShaderNodeBackground');bg.inputs[0].default_value=(.65,.75,1,1);bg.inputs[1].default_value=.035
wo=world.node_tree.nodes.new('ShaderNodeOutputWorld');world.node_tree.links.new(bg.outputs[0],wo.inputs[0]);scene.world=world
bpy.ops.object.light_add(type='SUN',location=(-2,5,7));sun=bpy.context.object;sun.name='ONLY_REAL_EXTERIOR_DAYLIGHT'
sun.data.energy=3.2;sun.data.angle=.055;sun.rotation_euler=Vector((.08,-1,-.63)).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(.55,5.2,1.90));cam=bpy.context.object
cam.rotation_euler=(Vector((0,-.65,1.25))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO';cam.data.ortho_scale=3.2;scene.camera=cam
scene.view_settings.view_transform='AgX';scene.view_settings.look='AgX - Medium High Contrast'
scene.render.resolution_x=950;scene.render.resolution_y=1050;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
def render(name):
    scene.render.filepath=str(OUT/name)
    try:bpy.ops.render.render(write_still=True)
    except RuntimeError:
        scene.cycles.device='CPU';bpy.ops.render.render(write_still=True)
render('transparent_window_daylight.png')
transparent_scene_materials=[(m,next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')) for m in window_mats]
for m,p in transparent_scene_materials:p.inputs['Alpha'].default_value=1;p.inputs['Transmission Weight'].default_value=0
render('opaque_control_same_sun.png')
GL.configure()
scene.render.filepath=str(OUT/'transparent_window_daylight.png')
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'glass_daylight_probe.blend'),compress=True)
report={'passed':True,'actual_source':str(SOURCE),'configured':configured,'glb_materials':exported,
        'protected_window_glow_unchanged':protected_before==protected_after,
        'lighting':'One exterior SUN plus weak world ambient; no interior lights and no emissive glass',
        'control':'Same geometry/camera/sun with only window alpha=1 and transmission=0',
        'device_requested':device,'renders':['transparent_window_daylight.png','opaque_control_same_sun.png']}
(OUT/'glass_blender_glb_evidence.json').write_text(json.dumps(report,indent=2),encoding='utf8')
print('GLASS_PROBE_COMPLETE',json.dumps(report),flush=True)
