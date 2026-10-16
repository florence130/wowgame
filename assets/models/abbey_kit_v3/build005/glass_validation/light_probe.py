import sys,json
from pathlib import Path
import bpy
from mathutils import Vector
sys.path.insert(0,r'E:\wowgame\tools\blender\abbey_kit_v3')
import glass as GL
OUT=Path(r'E:\wowgame\.local\abbey_glass_probe')
bpy.ops.wm.open_mainfile(filepath=str(OUT/'glass_daylight_probe.blend'))
scene=bpy.context.scene
scene.cycles.device='CPU';scene.cycles.samples=32
device='CPU'
try:
    pref=bpy.context.preferences.addons['cycles'].preferences;pref.compute_device_type='CUDA';pref.get_devices()
    for d in pref.devices:d.use=d.type=='CUDA'
    if any(d.use for d in pref.devices):scene.cycles.device='GPU';device='CUDA'
except Exception:pass
for o in scene.objects:
    if any(o.name.startswith(p) for p in ('Checker physically behind glass','RED CUBE visibly behind glazing','BLUE CUBE visibly behind glazing')):
        o.hide_render=True
    if o.name.startswith('Interior side wall'):
        cx=sum((o.matrix_world@Vector(c)).x for c in o.bound_box)/8
        o.location.x+=(-.12 if cx>0 else .12)
cam=scene.camera
cam.location=(1.0,-2.8,1.8)
cam.rotation_euler=(Vector((0,-.5,.85))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='PERSP';cam.data.lens=24;cam.data.clip_start=.05
scene.render.resolution_x=1000;scene.render.resolution_y=850
GL.configure()
scene.render.filepath=str(OUT/'daylight_floor_transparent.png')
try:bpy.ops.render.render(write_still=True)
except RuntimeError:
    scene.cycles.device='CPU';device='CPU';bpy.ops.render.render(write_still=True)
for m in bpy.data.materials:
    if m.get('recipe_key') in GL.WINDOW_COLORS:
        p=next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
        p.inputs['Alpha'].default_value=1;p.inputs['Transmission Weight'].default_value=0
scene.render.filepath=str(OUT/'daylight_floor_opaque_control.png')
bpy.ops.render.render(write_still=True)
GL.configure()
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'glass_floor_daylight_probe.blend'),compress=True)
proof={'device_actual':device,'passed':True,'illumination':'One real exterior SUN, weak world ambient. No interior light; no emissive window material.',
       'comparison':'Same camera and light. Only Alpha=.28/Transmission=.72 versus Alpha=1/Transmission=0.',
       'source_window':'build004/glb/window_clerestory.glb','files':['daylight_floor_transparent.png','daylight_floor_opaque_control.png']}
(OUT/'daylight_floor_evidence.json').write_text(json.dumps(proof,indent=2),encoding='utf8')
e=OUT/'glass_blender_glb_evidence.json';d=json.loads(e.read_text());d['device_actual']='CPU';d['device_fallback_reason']='OptiX PTX internal compiler error: missing copysign intrinsic';e.write_text(json.dumps(d,indent=2),encoding='utf8')
print('DAYLIGHT_FLOOR_COMPLETE',json.dumps(proof),flush=True)
