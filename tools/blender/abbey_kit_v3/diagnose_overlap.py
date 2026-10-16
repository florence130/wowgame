"""Read-only per-object BVH diagnosis of the build002 front-right foundation."""
import bpy,json,sys,shutil,time
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
SOURCE=Path('E:/wowgame/assets/models/abbey_kit_v3/build002/abbey_kit.blend')
if '--' in sys.argv:
    arguments=sys.argv[sys.argv.index('--')+1:]
    if arguments:SOURCE=Path(arguments[0])
while not SOURCE.exists():time.sleep(2)
previous=None
for i in range(20):
    st=SOURCE.stat();current=(st.st_size,st.st_mtime_ns)
    if current==previous:break
    previous=current;time.sleep(2)
SNAPSHOT=Path('E:/wowgame/.local/diagnose_overlap_snapshot.blend')
shutil.copyfile(SOURCE,SNAPSHOT)
bpy.ops.wm.open_mainfile(filepath=str(SNAPSHOT))
scene=bpy.data.scenes['ABY3_Courtyard']
bpy.context.window.scene=scene
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
def owner(ob):
    while ob:
        if ob.get('asset_id'):return ob
        ob=ob.parent
    return None
parts=[]
for ob in scene.objects:
    if ob.type!='MESH':continue
    own=owner(ob)
    if not own or own.get('asset_id') not in ('foundation_strip_4m','corner_pad','support_pad','plinth_4'):continue
    ev=ob.evaluated_get(deps)
    mesh=ev.to_mesh()
    verts=[ev.matrix_world@v.co for v in mesh.vertices]
    if not verts:ev.to_mesh_clear();continue
    lo=[min(v[i] for v in verts) for i in range(3)]
    hi=[max(v[i] for v in verts) for i in range(3)]
    if hi[0]<7 or lo[0]>10 or hi[1]<6 or lo[1]>9.5:ev.to_mesh_clear();continue
    polygons=[tuple(p.vertices) for p in mesh.polygons]
    record=dict(object=ob.name,asset=own.name,asset_id=own['asset_id'],asset_world=list(own.matrix_world.translation),
                trimmed=bool(ob.get('assembly_joint_trim',False)),modifiers=[m.type for m in ob.modifiers],
                bounds=[lo,hi],faces=len(polygons),bvh=BVHTree.FromPolygons(verts,polygons))
    parts.append(record)
    ev.to_mesh_clear()
tests=[]
for x,y in [(8.7,7.4),(8.4,7.4),(9,7.4),(8.7,7.15),(8.7,7.8),(8.7,8.2),(8.05,7.45),(8.15,8.5)]:
    hits=[]
    for part in parts:
        point,normal,face,distance=part['bvh'].ray_cast(Vector((x,y,1.2)),Vector((0,0,-1)),2)
        if point is not None:
            hits.append({**{k:part[k] for k in ('object','asset','asset_id','asset_world','trimmed','modifiers','bounds','faces')},
                         'hit':list(point),'normal':list(normal),'face_index':face})
    tests.append(dict(point_xy=[x,y],hits=sorted(hits,key=lambda a:a['hit'][2],reverse=True)))
chapel=next(ob for ob in scene.objects if ob.name.startswith('Chapel_Open_Interior') and ob.type=='EMPTY')
order=[dict(name=ob.name,key=ob.get('asset_id'),world=list(ob.matrix_world.translation)) for ob in chapel.children
       if ob.get('asset_id') in ('foundation_strip_4m','corner_pad','support_pad','plinth_4')]
result=dict(source=str(SOURCE),child_order=order,samples=tests)
out=SOURCE.parent/'foundation_overlap_diagnosis.json'
out.write_text(json.dumps(result,ensure_ascii=False,indent=2),encoding='utf8')
print('DIAGNOSIS_OUTPUT',str(out),flush=True)
for test in tests:
    print('POINT_HITS',json.dumps(dict(point=test['point_xy'],hits=[{k:h[k] for k in ('object','asset_id','trimmed','hit','normal','modifiers')} for h in test['hits']])),flush=True)
print('CHILD_ORDER',json.dumps(order),flush=True)
