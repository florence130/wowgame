"""Render actual saved assemblies; no reconstruction or image generation."""
import sys,math
from pathlib import Path
import bpy
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:];out=Path(args[0]);names=args[1].split(',') if len(args)>1 else []
bpy.ops.wm.open_mainfile(filepath=str(out/'goldshire_kit.blend'))
for sc in list(bpy.data.scenes):
    if not sc.name.startswith('GS_') or sc.name=='GS_Module_Library':continue
    key=sc.name[3:]
    if names and key not in names:continue
    if not sc.camera:continue
    bpy.context.window.scene=sc
    cam=sc.camera
    overview=key=='Village_Collection'
    target=Vector((27,23,2) if overview else (0,0,4 if key in ('tailor','tavern','guard_tower','home_loft') else 2.5))
    cam.location=(96,122,95) if overview else (16,23,16)
    cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO'
    cam.data.ortho_scale=103 if overview else 25 if key in ('tailor','tavern','general_store') else 23 if key in ('guard_tower','home_loft') else 19
    sc.render.engine='CYCLES';sc.cycles.samples=16;sc.render.resolution_x=1600 if overview else 1100;sc.render.resolution_y=1200 if overview else 900;sc.render.resolution_percentage=100
    sc.render.filepath=str(out/'renders'/('village_overview.png' if overview else key+'.png'));bpy.ops.render.render(write_still=True)
print('SAVED_RENDERS_COMPLETE')
