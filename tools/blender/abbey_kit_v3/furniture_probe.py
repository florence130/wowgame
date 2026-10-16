"""Background-only dimensional/modifier/triangle probe plus lit visual review."""
import sys,json,math
from pathlib import Path
sys.path[:0]=[r'E:\wowgame\tools\blender\abbey_kit_v3',r'E:\wowgame\tools\blender\abbey_kit_v2',r'E:\wowgame\tools\blender\abbey_kit']
import bpy
import numpy as np
from mathutils import Vector
import geometry as G
import materials as M
import furniture as F

OUT=Path(__file__).resolve().parent/'furniture_probe'
OUT.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
G.COL=bpy.context.scene.collection
G.ROOT=None
palette=M.use_game_palette()
for key in ['wood_dark','bronze']:
    M.COLORS[key]=palette['colors'][key]
    M.COLOR_KEYS[key]=key
M.install(OUT)

assets=[]
placements=[('pew_2m',(-3.4,.2,0)),('pew_end',(-5.2,-.7,0)),
            ('pew_seat_1m',(-4.5,-2.7,0)),('lectern',(.2,.2,0)),
            ('altar_table',(3,.3,0)),('wood_dais_2m',(-1.65,-3.1,0)),
            ('wood_stairs',(-1.65,-2.1,0)),('altar_back_panel',(3,-2.8,0))]
for name,location in placements:
    col=bpy.data.collections.new('PROBE_'+name);bpy.context.scene.collection.children.link(col)
    G.COL=col
    objects=getattr(F,name)()
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    vertices=[];triangles=0;degenerates=0
    modifiers={}
    for obj in objects:
        evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
        world=np.array([tuple(obj.matrix_world@v.co) for v in mesh.vertices])
        vertices.extend(world.tolist())
        idx=np.array([list(t.vertices) for t in mesh.loop_triangles],dtype=int)
        if len(idx):
            triangles+=len(idx)
            area=np.linalg.norm(np.cross(world[idx[:,1]]-world[idx[:,0]],world[idx[:,2]]-world[idx[:,0]]),axis=1)
            degenerates+=int(np.sum(area<1e-10))
        for mod in obj.modifiers:modifiers[mod.type]=modifiers.get(mod.type,0)+1
        if obj.type=='CURVE':modifiers['CURVE_BEVEL']=modifiers.get('CURVE_BEVEL',0)+1
        evaluated.to_mesh_clear()
    v=np.array(vertices)
    assert np.isfinite(v).all(),name+' invalid vertices'
    assert degenerates==0,name+' degenerate triangles '+str(degenerates)
    item={'asset':name,'objects':len(objects),'bounds_min':v.min(axis=0).tolist(),
          'bounds_max':v.max(axis=0).tolist(),'triangles':triangles,
          'degenerate_triangles':degenerates,'retained_modifiers':modifiers}
    assets.append(item)
    print('FURNITURE_OK',json.dumps(item),flush=True)
    for obj in objects:obj.location=location

G.COL=bpy.context.scene.collection
G.box('Probe floor',(13,10,.15),(-.6,-1.8,-.075),'ground',.01)
scene=bpy.context.scene
M.light_scene(scene)
scene.cycles.samples=32
scene.render.resolution_x=1800;scene.render.resolution_y=1150;scene.render.resolution_percentage=100
bpy.ops.object.camera_add(location=(10,15,12))
camera=bpy.context.object
camera.rotation_euler=(Vector((-.5,-1.5,.7))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=13.1;scene.camera=camera
scene.render.filepath=str(OUT/'furniture_all.png')
scene.render.image_settings.file_format='PNG'
(OUT/'measurements.json').write_text(json.dumps({'assets':assets,'recipes':F.RECIPES},indent=2),encoding='utf-8')
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'furniture_source.blend'))
bpy.ops.render.render(write_still=True)
for child in scene.collection.children:child.hide_render=True
reuse_col=bpy.data.collections.new('PROBE_Fixed4mRepeatBench')
scene.collection.children.link(reuse_col);G.COL=reuse_col
reuse=[]
for x in (-1.5,-.5,.5,1.5):
    for obj in F.pew_seat_1m():obj.location=(x,0,0);reuse.append(obj)
for x in (-2,2):
    for obj in F.pew_end():obj.location=(x,0,0);reuse.append(obj)
bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get()
rv=[];rt=0;rd=0
for obj in reuse:
    evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh();mesh.calc_loop_triangles()
    world=np.asarray([tuple(obj.matrix_world@v.co) for v in mesh.vertices]);rv.extend(world.tolist())
    ids=np.asarray([list(t.vertices) for t in mesh.loop_triangles],dtype=int);rt+=len(ids)
    area=np.linalg.norm(np.cross(world[ids[:,1]]-world[ids[:,0]],world[ids[:,2]]-world[ids[:,0]]),axis=1)
    rd+=int(np.sum(area<1e-10));evaluated.to_mesh_clear()
rv=np.asarray(rv)
reuse_evidence={'asset':'4m_repeated_pew_with_end_panels','body_centres_x':[-1.5,-.5,.5,1.5],
                'end_panel_centres_x':[-2,2],'bounds_min':rv.min(0).tolist(),'bounds_max':rv.max(0).tolist(),
                'triangles':rt,'degenerate_triangles':rd,'objects':len(reuse),
                'nominal_body_pitch_x':1,'overall_length':float(rv[:,0].max()-rv[:,0].min()),
                'fixed_coplanar_relation':'Former outer end carcass at x=2 shared the seat/apron end face. New carcass exterior x=2.052; foot exterior2.065; seat endpoint2 remains internal.'}
assert rd==0 and abs(reuse_evidence['overall_length']-4.13)<1e-5
(OUT/'measurements.json').write_text(json.dumps({'assets':assets,'recipes':F.RECIPES,'repeat_bench':reuse_evidence},indent=2),encoding='utf-8')
camera.location=(5.5,8,5)
camera.rotation_euler=(Vector((0,0,.55))-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.ortho_scale=4.95
scene.render.resolution_x=1300;scene.render.resolution_y=900
scene.render.filepath=str(OUT/'pew_4m_fixed.png')
bpy.ops.render.render(write_still=True)
print('REPEAT_PEW_OK',json.dumps(reuse_evidence),flush=True)
print('FURNITURE_PROBE_COMPLETE',len(assets),flush=True)
