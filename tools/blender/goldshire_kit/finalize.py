"""Bounded repairs to build_003, preserved as a new build_004. Re-export only changed assemblies."""
import sys,json,shutil,importlib.util,hashlib,math
from pathlib import Path
import bpy
from mathutils import Matrix
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('goldshire_builder',HERE/'build.py');B=importlib.util.module_from_spec(spec);spec.loader.exec_module(B)
src=Path(sys.argv[sys.argv.index('--')+1]);out=Path(sys.argv[sys.argv.index('--')+2])
if out.exists():raise RuntimeError('Output exists; preserve earlier builds')
shutil.copytree(src,out)
bpy.ops.wm.open_mainfile(filepath=str(src/'goldshire_kit.blend'));B.OUT=out
manifest=json.loads((out/'manifest.json').read_text(encoding='utf8'))
changed=[]
for sc in bpy.data.scenes:
    if sc.name not in ('GS_tailor','GS_tavern','GS_Village_Collection'):continue
    bpy.context.window.scene=sc
    for root in [o for o in sc.objects if o.parent is None and o.name.startswith(('tailor','tavern'))]:
        is_tailor=root.name.startswith('tailor')
        for o in list(root.children):
            if o.name.startswith('worktable_instance'):
                o.location.y=-1.6 if is_tailor else 2
            if is_tailor and o.name.startswith(('Fabric sample rail','Fabric hanging sample')):
                # Restore its original recipe-space placement, then orient against the rear workroom wall.
                o.matrix_basis=Matrix.Translation((-5,-2.65,.36))@Matrix.Rotation(math.pi/2,4,'Z')@Matrix.Translation((2.4,0,-.36))@o.matrix_basis
        changed.append(root.name)
    if sc.name in ('GS_tailor','GS_tavern'):
        key=sc.name[3:];root=next(o for o in sc.objects if o.name==key)
        B.export(root,out/'assemblies'/f'{key}.glb')
# Flatten actual instance placements into each preset coordinate system for reconstruction.
ids={m['id'] for m in manifest['modules']};placements=[]
for entry in manifest['assemblies']:
    key=entry['id'];sc=bpy.data.scenes['GS_'+key];bpy.context.window.scene=sc;bpy.context.view_layer.update();root=bpy.data.objects[key]
    for node in root.children_recursive:
        aid=node.name.split('_instance')[0]
        if aid in ids:
            xf=root.matrix_world.inverted()@node.matrix_world
            placements.append({'assembly':key,'asset':aid,'matrix_blender':[list(row) for row in xf]})
manifest['placements']=placements;manifest['build']='build_004';manifest['source_sha256']=hashlib.sha256((HERE/'build.py').read_bytes()).hexdigest()
manifest['incremental_repairs']=['Moved tailor cloth against rear workroom wall','Moved work tables out of side-room circulation','Reconstructed full preset-local instance transforms']
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf8')
bpy.context.window.scene=bpy.data.scenes['GS_Village_Collection'];bpy.ops.wm.save_as_mainfile(filepath=str(out/'goldshire_kit.blend'))
print('FINALIZE_COMPLETE',changed)
