"""Isolated factory-startup roof verification; never connects to live Blender."""
import sys, pathlib, json, math
import bpy
from mathutils import Vector
ROOT=pathlib.Path('E:/wowgame')
sys.path.insert(0,str(ROOT/'tools/blender/abbey_kit'))
sys.path.insert(0,str(ROOT/'tools/blender/abbey_kit_v2'))
import geometry as G
import materials
import roofs
out=ROOT/('.local/roof_spire_probe' if '--spire' in sys.argv else '.local/roof_probe')
out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
G.COL=bpy.data.collections.new('ROOF_PROBE')
bpy.context.scene.collection.children.link(G.COL)
G.ROOT=None
materials.install(out)
stats={}
def place(name,func,location=(0,0,0),**kwargs):
    objects=func(**kwargs)
    for ob in objects:ob.location+=Vector(location)
    stats[name]={'objects':len(objects),'vertices':sum(len(ob.data.vertices) for ob in objects if ob.type=='MESH'),
                 'faces':sum(len(ob.data.polygons) for ob in objects if ob.type=='MESH')}
    return objects
first=place('pitch',roofs.pitched_roof,(0,-2,1),width=8,length=4,rise=3.4)
place('pitch_repeat',roofs.pitched_roof,(0,2,1),width=8,length=4,rise=3.4)
place('fascia_front',roofs.gable_fascia,(0,-4,1),width=8,rise=3.4)
place('fascia_back',roofs.gable_fascia,(0,4,1),width=8,rise=3.4)
place('hip',roofs.hip_roof,(-7,1,1),width=4.8,rise=2)
place('shed',roofs.shed_roof,(5.6,.3,1),run=2.8,length=4,rise=1.4)
place('cross',roofs.ridge_cross,(-7,1,3.5),size=.8)
place('chimney',roofs.roof_chimney,(-2.1,1.8,3.2))
dormers=place('dormer',roofs.dormer,(0,0,0))
for ob in dormers:
    # Parent-level transform applies to already baked mesh vertices and beams.
    pass
droot=bpy.data.objects.new('DormerPlacement',None)
G.COL.objects.link(droot)
for ob in dormers:ob.parent=droot
droot.rotation_euler.z=math.pi/2
droot.location=(3.0,-1.7,2.0)
# The unusually short repeatable end module must still build with exact Y bounds.
short=place('pitch_short',roofs.pitched_roof,(0,0,-12),width=8,length=.3,rise=3.4)
for ob in short:ob.hide_render=True
bpy.context.view_layer.update()
for ob in first:
    if ob.type=='MESH':
        for vertex in ob.data.vertices:
            if abs(vertex.co.y)>2.00001:raise AssertionError((ob.name,vertex.co.y))
for ob in short:
    if ob.type=='MESH':
        for vertex in ob.data.vertices:
            if abs(vertex.co.y)>.15001:raise AssertionError((ob.name,vertex.co.y))
for ob in G.COL.objects:
    if ob.type=='MESH':
        if ob.data.validate(verbose=True):raise AssertionError('Invalid mesh '+ob.name)
        for face in ob.data.polygons:
            if not math.isfinite(face.area) or face.area<1e-10:raise AssertionError(('Degenerate',ob.name,face.index,face.area))
G.box('Stage',(26,20,.18),(-.3,0,-.20),'ground',.08)
G.box('RoofVolume',(8,8,1),(0,0,.5),'plaster')
G.box('TowerVolume',(4,4,1),(-7,1,.5),'plaster')
scene=bpy.context.scene
materials.light_scene(scene)
scene.cycles.samples=24
scene.render.resolution_x=1400
scene.render.resolution_y=1000
scene.render.resolution_percentage=100
camera=bpy.data.cameras.new('RoofProbeCamera')
ob=bpy.data.objects.new('RoofProbeCamera',camera)
scene.collection.objects.link(ob)
ob.location=(17,-23,18)
ob.rotation_euler=(Vector((-.6,.2,1.7))-ob.location).to_track_quat('-Z','Y').to_euler()
camera.type='ORTHO'
camera.ortho_scale=24
scene.camera=ob
if '--spire' in sys.argv:
    for item in list(G.COL.objects):bpy.data.objects.remove(item,do_unlink=True)
    stats.clear()
    spire=place('spire',roofs.spire_roof,(0,0,1),width=4.8,rise=4.5,seed=3)
    for item in spire:
        if item.type=='MESH':
            if item.data.validate(verbose=True):raise AssertionError('Invalid spire mesh '+item.name)
            for face in item.data.polygons:
                if face.area<1e-10:raise AssertionError(('Spire zero-area face',item.name,face.index))
            if min(vertex.co.z for vertex in item.data.vertices)<-1e-6:
                raise AssertionError('Spire below local eave datum')
    G.box('SpireTowerStub',(3.9,3.9,1),(0,0,.5),'plaster',.035)
    G.box('SpireProbeStage',(10,10,.15),(0,0,-.16),'ground',.04)
    ob.location=(9,-12,8)
    ob.rotation_euler=(Vector((0,0,2.55))-ob.location).to_track_quat('-Z','Y').to_euler()
    camera.ortho_scale=9
    scene.render.resolution_x=1100
    scene.render.resolution_y=1100
scene.render.filepath=str(out/'roof_probe.png')
(out/'stats.json').write_text(json.dumps(stats,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(out/'roof_probe.blend'))
bpy.ops.render.render(write_still=True)
print('ROOF_PROBE_PASS',json.dumps(stats))
