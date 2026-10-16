"""Read-only loaded-scene reveal diagnosis, isolated inserts and visual proof."""
import bpy,sys,json,shutil,math,bmesh
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=Path('E:/wowgame')
SOURCE=ROOT/'assets/models/abbey_kit_v3/build002/abbey_kit.blend'
OUT=ROOT/'.local/openings_v3_probe'
OUT.mkdir(parents=True,exist_ok=True)
snapshot=OUT/'input_snapshot.blend'
shutil.copyfile(SOURCE,snapshot)
bpy.ops.wm.open_mainfile(filepath=str(snapshot))
scene=bpy.data.scenes['ABY3_Courtyard']
bpy.context.window.scene=scene
sys.path.insert(0,str(ROOT/'tools/blender/abbey_kit'))
sys.path.insert(0,str(ROOT/'tools/blender/abbey_kit_v3'))
import geometry as G
import openings as O
def material(key):
    found=next((m for m in bpy.data.materials if m.get('recipe_key')==key),None)
    if found is None:raise RuntimeError('Missing loaded lit material '+key)
    return found
G.material=material
G.COL=scene.collection
def owner(ob):
    while ob:
        if ob.get('asset_id'):return ob
        ob=ob.parent
    return None
tests=[('Window jamb',(-.19,6,4.12),(0,1,0)),
       ('Rear left jamb',(2,-7.84,2.18),(-1,0,0)),
       ('Rear left jamb second course',(2,-7.84,2.55),(-1,0,0)),
       ('Rear right jamb',(6,-7.84,2.18),(1,0,0))]
def diagnose():
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    result=[]
    objects=[]
    for ob in scene.objects:
        if ob.type!='MESH':continue
        root=owner(ob)
        if not root or root.get('asset_id') not in ('window_clerestory','wall_clerestory_4','rear_portal','apse',
                                                     'window_reveal','portal_reveal'):continue
        ev=ob.evaluated_get(deps);mesh=ev.to_mesh()
        verts=[ev.matrix_world@v.co for v in mesh.vertices]
        faces=[tuple(p.vertices) for p in mesh.polygons]
        if faces:objects.append((ob.name,root.get('asset_id'),BVHTree.FromPolygons(verts,faces)))
        ev.to_mesh_clear()
    for label,origin,direction in tests:
        hits=[]
        for name,key,bvh in objects:
            position,normal,face,distance=bvh.ray_cast(Vector(origin),Vector(direction),1.2)
            if position is not None:hits.append(dict(object=name,asset_id=key,position=list(position),normal=list(normal),distance=distance))
        result.append(dict(label=label,hits=sorted(hits,key=lambda h:h['distance'])))
    return result
before=diagnose()
created=[]
roots=[ob for ob in list(scene.objects) if ob.type=='EMPTY' and ob.get('asset_id')]
for original in roots:
    key=original['asset_id']
    if key not in ('window_clerestory','rear_portal','facade_8'):continue
    if key=='facade_8' and original.matrix_world.translation.y<0:continue
    name='window_reveal' if key=='window_clerestory' else 'portal_reveal' if key=='rear_portal' else 'entry_reveal'
    parent=bpy.data.objects.new('Probe_'+name,None)
    G.COL.objects.link(parent)
    parent.matrix_world=original.matrix_world.copy()
    parent['asset_id']=name
    G.ROOT=parent
    objects=(O.window_reveal() if name=='window_reveal' else O.portal_reveal() if name=='portal_reveal' else O.entry_reveal())
    created.extend(objects)
    for ob in objects:
        if ob.data.validate(verbose=True):raise AssertionError('Invalid reveal mesh')
        bm=bmesh.new();bm.from_mesh(ob.data)
        assert all(e.is_manifold for e in bm.edges),'Nonmanifold reveal'
        assert all(f.calc_area()>1e-10 for f in bm.faces),'Zero area reveal'
        assert bm.calc_volume(signed=True)>0,'Wrong reveal winding'
        bm.free()
after=diagnose()
for row in after:
    assert row['hits'] and row['hits'][0]['asset_id'] in ('window_reveal','portal_reveal'),row
report=dict(source=str(SOURCE),before=before,after=after,created_reveals=len(created),
            topology='all base rings closed manifold, positive signed volume, no zero-area faces')
(OUT/'opening_diagnosis.json').write_text(json.dumps(report,indent=2),encoding='utf8')
for row in before:print('BEFORE',json.dumps(row),flush=True)
for row in after:print('AFTER',json.dumps(row),flush=True)
cam=scene.camera
cam.data.type='PERSP';cam.data.lens=20
cam.location=(4,7.35,2.4)
cam.rotation_euler=(Vector((4,-5.8,2.7))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.resolution_x=960;scene.render.resolution_y=720;scene.render.resolution_percentage=100
scene.cycles.samples=12
scene.render.filepath=str(OUT/'interior_reveals_after.png')
bpy.ops.render.render(write_still=True)
cam.location=(4,-3.8,2.7)
cam.data.lens=24
cam.rotation_euler=(Vector((4,-8,3.2))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(OUT/'portal_reveal_close.png')
bpy.ops.render.render(write_still=True)
print('OPENINGS_PROBE_PASS',str(OUT),flush=True)
