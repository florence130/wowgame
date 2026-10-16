"""Factory-startup verification and isolated renders for structure.py."""
import json,math,sys
from pathlib import Path
import bpy
from mathutils import Vector
ROOT=Path('E:/wowgame')
sys.path.insert(0,str(ROOT/'tools/blender/abbey_kit'))
sys.path.insert(0,str(ROOT/'tools/blender/abbey_kit_v2'))
sys.path.insert(0,str(ROOT/'tools/blender/abbey_kit_v3'))
import geometry as G
import materials as M
import structure as S
OUT=ROOT/'.local/structure_v3_probe'
OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
palette=json.loads((ROOT/'docs/abbey_kit_v2/palette_architecture.json').read_text())['colors']
M.use_game_palette()
M.COLORS.update({key:palette[key] for key in ('bronze','wood_dark','window_glow')})
M.install(OUT)
G.COL=bpy.context.scene.collection
roots={}
records={}
def make(name,fn,xyz=(0,0,0)):
    root=bpy.data.objects.new(name,None)
    G.COL.objects.link(root)
    root.location=xyz
    G.ROOT=root
    parts=fn()
    roots[name]=root
    records[name]={'parts':parts,'root':root}
    return root
make('strip',S.foundation_strip_4m,(-4.4,-1.8,0))
make('pad',S.support_pad,(-1.3,2,0))
make('pad_right',S.support_pad,(5.3,2,0))
make('column',S.interior_column,(-1.3,2,.8))
make('column_right',S.interior_column,(5.3,2,.8))
make('beam',S.beam_4m,(3.2,-1.8,.6))
make('truss',S.roof_truss_8m,(2,2,6.2))
make('chandelier',S.chandelier,(1.4,-4,2.7))
make('floor_lamp',S.floor_lamp,(-1.25,-4,0))
glow=G.material('window_glow')
for node in glow.node_tree.nodes:
    if node.type=='BSDF_PRINCIPLED':
        node.inputs['Emission Color'].default_value=tuple(G.linear(int(palette['window_glow'][i:i+2],16)) for i in (0,2,4))+(1,)
        node.inputs['Emission Strength'].default_value=1.6
bpy.context.view_layer.update()
deps=bpy.context.evaluated_depsgraph_get()
stats={}
for name,record in records.items():
    coords=[]
    triangles=0
    modifiers=[]
    sockets=[]
    root=record['root']
    for ob in record['parts']:
        modifiers.extend(m.type for m in ob.modifiers)
        if ob.get('socket_kind'):
            sockets.append({'name':ob.name,'position':list(ob.location),'energy_hint':ob['suggested_energy_watts']})
        if ob.type not in ('MESH','CURVE'):continue
        ev=ob.evaluated_get(deps)
        mesh=ev.to_mesh()
        if mesh.validate(verbose=True):raise AssertionError('Invalid mesh '+ob.name)
        mesh.calc_loop_triangles()
        triangles+=len(mesh.loop_triangles)
        matrix=root.matrix_world.inverted()@ev.matrix_world
        coords.extend(matrix@vertex.co for vertex in mesh.vertices)
        assert all(math.isfinite(v) for p in coords for v in p)
        assert all(face.area>1e-11 for face in mesh.polygons),(name,ob.name,'zero area')
        ev.to_mesh_clear()
    lower=[min(p[i] for p in coords) for i in range(3)]
    upper=[max(p[i] for p in coords) for i in range(3)]
    stats[name]={'objects':len(record['parts']),'triangles':triangles,'min':lower,'max':upper,
                 'editable_modifier_types':sorted(set(modifiers)),'light_sockets':sockets}
    if name in ('strip','pad','pad_right'):
        assert abs(lower[2])<1e-5 and abs(upper[2]-.8)<1e-5,(name,lower,upper)
    if name in ('column','column_right'):
        assert abs(lower[2])<1e-5 and abs(upper[2]-5.4)<1e-5,(name,lower,upper)
    if name=='beam':
        assert abs(lower[0]+2)<1e-5 and abs(upper[0]-2)<1e-5,(name,lower,upper)
    if name=='truss':
        assert abs(lower[2])<1e-5 and abs(upper[2]-3.1)<1e-5,(name,lower,upper)
    if name=='chandelier':
        assert abs(lower[2]+1)<1e-5 and abs(upper[2])<1e-5,(name,lower,upper)
        assert len(sockets)==6
    if name=='floor_lamp':
        assert abs(lower[2])<1e-5 and abs(upper[2]-1.8)<1e-5,(name,lower,upper)
        assert len(sockets)==1
(OUT/'stats.json').write_text(json.dumps(stats,indent=2),encoding='utf8')
G.ROOT=None
G.box('Probe stage',(25,24,.16),(1,0,-.08),'ground',.02)
scene=bpy.context.scene
M.light_scene(scene)
scene.cycles.samples=24
scene.render.resolution_x=1500
scene.render.resolution_y=1200
scene.render.resolution_percentage=100
camera=bpy.data.cameras.new('ProbeCamera')
cam=bpy.data.objects.new('ProbeCamera',camera)
scene.collection.objects.link(cam)
cam.location=(17,-25,16)
cam.rotation_euler=(Vector((.5,0,4))-cam.location).to_track_quat('-Z','Y').to_euler()
camera.type='ORTHO';camera.ortho_scale=17
scene.camera=cam
scene.render.filepath=str(OUT/'structure_overview.png')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'structure_probe.blend'))
bpy.ops.render.render(write_still=True)
for name,record in records.items():
    if name not in ('chandelier','floor_lamp'):
        for ob in record['parts']:ob.hide_render=True
cam.location=(6,-13,5)
cam.rotation_euler=(Vector((0,-4,1.5))-cam.location).to_track_quat('-Z','Y').to_euler()
camera.ortho_scale=4.8
scene.render.resolution_x=1400
scene.render.resolution_y=1150
scene.render.filepath=str(OUT/'lighting_geometry.png')
bpy.ops.render.render(write_still=True)
print('STRUCTURE_PROBE_PASS',json.dumps({k:{a:v[a] for a in ('objects','triangles','min','max')} for k,v in stats.items()}),flush=True)
