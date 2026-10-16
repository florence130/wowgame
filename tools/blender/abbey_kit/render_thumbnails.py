"""Render real model thumbnails and selected orthographic turnarounds from a saved kit."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import build as B
folder=Path(bpy.data.filepath).parent;man=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
out=folder/'renders'/'thumbnails';out.mkdir(exist_ok=True)
if any(out.iterdir()):raise FileExistsError('Thumbnails already exist; keep evidence and choose another output directory')
lib=bpy.data.scenes['ABY_Library']
B.ASSETS={a['id']:next(o for o in lib.objects if o.get('asset_id')==a['id']) for a in man['assets']}
s=B.make_scene('ABY_Thumbnails')
s.cycles.samples=2
for a in man['assets']:
    bpy.context.window.scene=s
    for o in list(s.objects):bpy.data.objects.remove(o,do_unlink=True)
    root=B.instance(a['id']);lo=Vector(a['bounds_min']);hi=Vector(a['bounds_max']);center=(lo+hi)/2;dim=hi-lo
    scale=max(dim.x,dim.y,dim.z)*1.6+.35
    B.camera(s,center,center+Vector((7,10,6)),scale,384);s.render.resolution_y=320
    B.render(s,out/(a['id']+'.png'))
    if a['id'] in ('wall_window_4','window_arch_frame','window_arch_glass','door_arch_frame','door_wood_double','roof_gable_8x4','column_3','bridge_segment_4','dome_frame_4','dome_glass_4'):
        for view,direction in [('front',(0,10,0)),('side',(10,0,0)),('back',(0,-10,0))]:
            cam=s.camera;cam.location=center+Vector(direction);cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale
            B.render(s,out/(a['id']+'_'+view+'.png'))
print('THUMBNAILS_OK',str(out))
