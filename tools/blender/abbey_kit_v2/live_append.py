"""Append only this kit's scene into the user's live Blender; never clear it."""
from pathlib import Path
import bpy, json, runpy
from mathutils import Quaternion
HERE=Path(__file__).resolve().parent
PROJECT=HERE.parents[2]
pointer=json.loads((PROJECT/'assets/models/abbey_kit_v2/LATEST.json').read_text(encoding='utf8'))
folder=Path(pointer['build_directory']);source=folder/'abbey_kit.blend'
before={s.name for s in bpy.data.scenes}
name='ABY2_game_Courtyard'
with bpy.data.libraries.load(str(source),link=False) as (src,dst):
    if name not in src.scenes:raise RuntimeError('Requested scene absent')
    dst.scenes=[name]
s=dst.scenes[0];s.name='ABY2_Architecture_'+folder.name;s['source_build']=str(folder)
bpy.context.window.scene=s
runpy.run_path(str(HERE/'install_panel.py'),run_name='__main__')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            space=area.spaces.active;space.shading.type='MATERIAL';space.shading.use_scene_lights=True;space.shading.use_scene_world=True
            if space.region_3d:space.region_3d.view_perspective='CAMERA'
report=dict(scene=s.name,source_build=str(folder),previous_scenes_preserved=before.issubset({a.name for a in bpy.data.scenes}),objects=len(s.objects),catalog_directory=s.aby_settings.directory,render_camera=s.camera.name)
(folder/'live_blender_append.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False))
