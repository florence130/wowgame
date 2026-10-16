import bpy,sys,importlib.util,json,hashlib
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('gsbuilder',HERE/'build.py');B=importlib.util.module_from_spec(spec);spec.loader.exec_module(B)
out=Path(sys.argv[sys.argv.index('--')+1]);bpy.ops.wm.open_mainfile(filepath=str(out/'goldshire_kit.blend'))
count=0
for o in bpy.data.objects:
    if o.name.startswith('Fabric hanging sample'):
        for m in o.modifiers:
            if m.type=='BEVEL':m.width=.004;count+=1
bpy.context.window.scene=bpy.data.scenes['GS_tailor'];B.export(bpy.data.objects['tailor'],out/'assemblies/tailor.glb')
bpy.context.window.scene=bpy.data.scenes['GS_Village_Collection'];bpy.ops.wm.save_as_mainfile(filepath=str(out/'goldshire_kit.blend'))
m=json.loads((out/'manifest.json').read_text(encoding='utf8'));m['source_sha256']=hashlib.sha256((HERE/'build.py').read_bytes()).hexdigest();m['incremental_repairs'].append('Thin cloth bevel reduced to 4mm to avoid clamped degenerate triangles')
(out/'manifest.json').write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding='utf8');print('THIN_BEVEL_FIXED',count)
