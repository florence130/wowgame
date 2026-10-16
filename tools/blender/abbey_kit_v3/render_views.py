"""Render the saved candidate without touching geometry or exports."""
import bpy,sys
from pathlib import Path
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import build_v3 as V3
out=Path(sys.argv[sys.argv.index('--')+1]);bpy.ops.wm.open_mainfile(filepath=str(out/'abbey_kit.blend'))
demo=bpy.data.scenes['ABY3_Courtyard']
for name in ('exterior_open','interior_eye','foundation_close'):
    demo.camera=bpy.data.objects[demo['camera_'+name]];V3.render_scene(demo,out/'renders'/f'{name}.png')
for scene_name,name in [('ABY3_Interior_Cutaway','interior_cutaway'),('ABY3_Reuse_Examples','reuse_examples')]:
    V3.render_scene(bpy.data.scenes[scene_name],out/'renders'/f'{name}.png')
bpy.context.window.scene=demo;demo.camera=bpy.data.objects[demo['camera_exterior_open']]
bpy.ops.wm.save_as_mainfile(filepath=str(out/'abbey_kit.blend'))
print('SAVED CANDIDATE VIEWS COMPLETE',out,flush=True)
