"""Append completed v3 scenes, preserve every existing user scene."""
from pathlib import Path
import bpy,json,runpy
HERE=Path(__file__).resolve().parent;PROJECT=HERE.parents[2]
folder=Path(json.loads((PROJECT/'assets/models/abbey_kit_v3/LATEST.json').read_text(encoding='utf8'))['build_directory'])
before={s.name for s in bpy.data.scenes}
with bpy.data.libraries.load(str(folder/'abbey_kit.blend'),link=False) as (src,dst):
    dst.scenes=['ABY3_Courtyard','ABY3_Interior_Cutaway','ABY3_Reuse_Examples']
scenes=dst.scenes
for s in scenes:s.name=s.name+'_'+folder.name;s['source_build']=str(folder)
s=scenes[1];bpy.context.window.scene=s
runpy.run_path(str(HERE/'install_panel.py'),run_name='__main__')
for s in scenes:
    s.aby_settings.directory=str(folder);s.aby_settings.target_socket='end';s.aby_settings.moving_socket='start'
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.shading.type='MATERIAL';sp.shading.use_scene_lights=True;sp.shading.use_scene_world=True
            if sp.region_3d:sp.region_3d.view_perspective='CAMERA'
report=dict(scenes=[s.name for s in scenes],active=bpy.context.scene.name,source_build=str(folder),previous_scenes_preserved=before.issubset({s.name for s in bpy.data.scenes}))
(folder/'live_blender_append.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False))
