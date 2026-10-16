"""Non-destructive material revision of the completed v3 geometry candidate.

Blender --python upgrade_glass.py -- --source BUILD004 --out BUILD005
Reuses exact source geometry, reexports every GLB and rerenders every scene.
"""
import bpy,sys,argparse,json,shutil,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import build_v3 as V3
import glass
B=V3.B;doors=V3.doors
ap=argparse.ArgumentParser();ap.add_argument('--source',type=Path,required=True);ap.add_argument('--out',type=Path,required=True)
args=ap.parse_args(sys.argv[sys.argv.index('--')+1:]);src=args.source;out=args.out
if src.resolve()==out.resolve():raise ValueError('Use a new candidate directory.')
out.mkdir(parents=True,exist_ok=True)
for sub in ('glb','assemblies','renders'): (out/sub).mkdir(exist_ok=True)
for sub in ('stages','textures','reveal_validation'):
    if (src/sub).exists():shutil.copytree(src/sub,out/sub,dirs_exist_ok=True)
for file in ('manifest.json','assembly_preset.json','palette_mapping.json'):shutil.copy2(src/file,out/file)
for file in ('pew_4m_detail.png','capital_detail.png'):
    if (src/'renders'/file).exists():shutil.copy2(src/'renders'/file,out/'renders'/file)
bpy.ops.wm.open_mainfile(filepath=str(src/'abbey_kit.blend'))
required=['ABY3_Library','ABY3_Courtyard','ABY3_Interior_Cutaway','ABY3_Reuse_Examples']
if not all(name in bpy.data.scenes for name in required):raise RuntimeError('Source build is not complete; wait for all scenes to be saved.')
glass.configure()
manifest=json.loads((out/'manifest.json').read_text(encoding='utf8'))
manifest['material_revision']='User requested transparent, light-transmitting window glass.'
manifest['geometry_source_build']=str(src)
manifest['geometry_source_blend_sha256']=hashlib.sha256((src/'abbey_kit.blend').read_bytes()).hexdigest()
manifest['glass_source_sha256']=hashlib.sha256((HERE/'glass.py').read_bytes()).hexdigest()
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
bpy.context.window.scene=bpy.data.scenes['ABY3_Library']
for row in manifest['assets']:
    key=row['id'];col=bpy.data.collections['ABY_'+key];root=next(o for o in col.objects if o.get('asset_id')==key)
    (doors.export_hierarchy if key in ('door_hinged','chandelier','floor_lamp') else B.export_root)(root,out/'glb'/f'{key}.glb')
demo=bpy.data.scenes['ABY3_Courtyard'];bpy.context.window.scene=demo
for row in manifest['assemblies']:
    root=next(o for o in demo.objects if o.name==row['id']);B.export_root(root,out/'assemblies'/f'{root.name}.glb')
dr=next(o for o in demo.objects if o.get('asset_id')=='door_hinged')
doors.export_hierarchy(dr,out/'assemblies/Door_Open_105deg.glb')
reuse=bpy.data.scenes['ABY3_Reuse_Examples'];bpy.context.window.scene=reuse
rr=next(o for o in reuse.objects if o.name=='InteriorLayout_B_Reusable');B.export_root(rr,out/'assemblies/InteriorLayout_B.glb')
for scene in bpy.data.scenes:
    if scene.render.engine=='CYCLES':scene.cycles.transparent_max_bounces=16;scene.cycles.transmission_bounces=8;scene.cycles.max_bounces=8
bpy.context.window.scene=demo;bpy.ops.wm.save_as_mainfile(filepath=str(out/'abbey_kit.blend'))
for name in ('exterior_open','interior_eye','foundation_close'):
    demo.camera=bpy.data.objects[demo['camera_'+name]];V3.render_scene(demo,out/'renders'/f'{name}.png')
for scene_name,name in [('ABY3_Interior_Cutaway','interior_cutaway'),('ABY3_Reuse_Examples','reuse_examples')]:
    s=bpy.data.scenes[scene_name];V3.render_scene(s,out/'renders'/f'{name}.png')
bpy.context.window.scene=demo;demo.camera=bpy.data.objects[demo['camera_exterior_open']]
bpy.ops.wm.save_as_mainfile(filepath=str(out/'abbey_kit.blend'))
print('GLASS REVISION COMPLETE',out,flush=True)
