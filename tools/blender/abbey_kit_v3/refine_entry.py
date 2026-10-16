"""Apply the entry-frame offset correction to an unsubmitted candidate.
Shared source data updates library and placements together, then all views rerender.
"""
import bpy,sys,json,math,hashlib
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import build_v3 as V3
out=Path(sys.argv[sys.argv.index('--')+1]);bpy.ops.wm.open_mainfile(filepath=str(out/'abbey_kit.blend'))
lib=bpy.data.scenes['ABY3_Library'];bpy.context.window.scene=lib
col=bpy.data.collections['ABY_entry_reveal'];root=next(o for o in col.objects if o.get('asset_id')=='entry_reveal')
for ob in root.children_recursive:
    if ob.type=='MESH' and not ob.data.get('entry_frame_offset_applied'):
        for vertex in ob.data.vertices:
            if vertex.co.y>0:vertex.co.y+=.15
        ob.data['entry_frame_offset_applied']=True;ob.data.update()
bpy.context.view_layer.update();V3.B.export_root(root,out/'glb/entry_reveal.glb')
manifest=json.loads((out/'manifest.json').read_text(encoding='utf8'))
for row in manifest['assets']:
    if row['id']=='entry_reveal':row.update(V3.B.evaluated_stats(root))
demo=bpy.data.scenes['ABY3_Courtyard'];bpy.context.window.scene=demo
chapel=demo.objects['Chapel_Open_Interior'];V3.B.export_root(chapel,out/'assemblies/Chapel_Open_Interior.glb')
manifest['geometry_revision_after_base']='Entry reveal covers the full +.15m externally mounted stone frame, following openings.entry_reveal().'
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
reuse=bpy.data.scenes['ABY3_Reuse_Examples'];reuse.camera.data.ortho_scale=21
reuse.camera.rotation_euler=(Vector((0,.7,2.5))-reuse.camera.location).to_track_quat('-Z','Y').to_euler()
bpy.context.window.scene=demo;bpy.ops.wm.save_as_mainfile(filepath=str(out/'abbey_kit.blend'))
for name in ('exterior_open','interior_eye','foundation_close'):
    demo.camera=bpy.data.objects[demo['camera_'+name]];V3.render_scene(demo,out/'renders'/f'{name}.png')
for scene_name,name in [('ABY3_Interior_Cutaway','interior_cutaway'),('ABY3_Reuse_Examples','reuse_examples')]:V3.render_scene(bpy.data.scenes[scene_name],out/'renders'/f'{name}.png')
bpy.context.window.scene=demo;demo.camera=bpy.data.objects[demo['camera_exterior_open']]
bpy.ops.wm.save_as_mainfile(filepath=str(out/'abbey_kit.blend'))
print('FINAL ENTRY AND CAMERA REFINEMENT COMPLETE',flush=True)
