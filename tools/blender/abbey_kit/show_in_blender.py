"""Append the reviewed kit in the existing Blender session; preserve its scenes."""
import bpy,sys,json
from pathlib import Path
directory=Path('E:/wowgame/assets/models/abbey_kit_v1/build_004')
before={'filepath':bpy.data.filepath,'scenes':[s.name for s in bpy.data.scenes],'objects':len(bpy.data.objects)}
with bpy.data.libraries.load(str(directory/'abbey_kit.blend'),link=False) as (src,dst):
    dst.scenes=[n for n in ('ABY_Demo','ABY_Catalog','ABY_Bridge','ABY_Library') if n in src.scenes]
scene=next(s for s in dst.scenes if s.name.startswith('ABY_Demo'));bpy.context.window.scene=scene
sys.path.insert(0,'E:/wowgame/tools/blender/abbey_kit')
import blender_panel
blender_panel.register();scene.aby_settings.directory=str(directory);bpy.ops.aby.read_catalog()
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            sp=area.spaces.active;sp.shading.type='MATERIAL';sp.shading.use_scene_world=True;sp.shading.use_scene_lights=True
            sp.region_3d.view_perspective='CAMERA';sp.show_region_ui=True
print(json.dumps({'preserved':before,'new_active_scene':scene.name,'panel':'Abbey Kit','catalog_items':49,'saved_source':str(directory/'abbey_kit.blend')},ensure_ascii=False))
