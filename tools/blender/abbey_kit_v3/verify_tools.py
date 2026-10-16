"""Actual Blender sidebar actions, snap/repeat/hinge independence and door sweep."""
import bpy,sys,json,runpy,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
HERE=Path(__file__).resolve().parent
out=Path(sys.argv[sys.argv.index('--')+1]);bpy.ops.wm.open_mainfile(filepath=str(out/'abbey_kit.blend'))
main=bpy.data.scenes['ABY3_Courtyard'];bpy.context.window.scene=main
runpy.run_path(str(HERE/'install_panel.py'),run_name='__main__')
test=bpy.data.scenes.new('ABY3_Actual_Tool_Test');bpy.context.window.scene=test
st=test.aby_settings;st.directory=str(out);bpy.ops.aby.read_catalog();checks=[]
def check(name,ok,**data):checks.append(dict(check=name,passed=bool(ok),**data))
for key,pitch in [('beam_4m',4),('pew_seat_1m',1),('wood_dais_2m',2),('foundation_strip_4m',4)]:
    st.asset=key;test.cursor.location=(0,0,0);bpy.ops.aby.add_component();target=bpy.context.active_object
    test.cursor.location=(3,5,2);bpy.ops.aby.add_component();moving=bpy.context.active_object
    target.select_set(True);bpy.context.view_layer.objects.active=target
    st.target_socket='end';st.moving_socket='start';r=bpy.ops.aby.snap_component();bpy.context.view_layer.update()
    gap=(moving.matrix_world@Vector((-pitch/2,0,0))-target.matrix_world@Vector((pitch/2,0,0))).length
    check(key+'_real_snap',r=={'FINISHED'} and gap<1e-5,gap_metres=gap)
    bpy.ops.object.select_all(action='DESELECT');target.select_set(True);bpy.context.view_layer.objects.active=target
    test.aby3_repeat_count=4;before=set(test.objects);r=bpy.ops.aby3.repeat();added=list(set(test.objects)-before)
    distances=sorted(round((o.location-target.location).length,5) for o in added)
    check(key+'_real_repeat',r=={'FINISHED'} and distances==[pitch,pitch*2,pitch*3],distances=distances)
st.asset='door_hinged';test.cursor.location=(0,0,0);bpy.ops.aby3.add_editable();door_a=bpy.context.active_object
test.cursor.location=(4,0,0);bpy.ops.aby3.add_editable();door_b=bpy.context.active_object
test.aby3_door_angle=105;bpy.ops.aby3.set_door_angle()
angles_a=[round(math.degrees(o.rotation_euler.z),4) for o in door_a.children_recursive if 'open_sign' in o]
angles_b=sorted(round(math.degrees(o.rotation_euler.z),4) for o in door_b.children_recursive if 'open_sign' in o)
check('two_editable_doors_independent',all(a==0 for a in angles_a) and angles_b==[-105,105],first=angles_a,second=angles_b)
bpy.context.window.scene=main;bpy.context.view_layer.update()
door=next(o for o in main.objects if o.get('asset_id')=='door_hinged')
frame=next(o for o in main.objects if o.get('asset_id')=='door_arch')
facade=next(o for o in main.objects if o.get('asset_id')=='facade_8' and o.location.y>0)
def world_bvh(objects):
    bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();vs=[];fs=[]
    for ob in objects:
        if ob.type not in ('MESH','CURVE'):continue
        ev=ob.evaluated_get(dg);me=ev.to_mesh();offset=len(vs)
        vs.extend(ob.matrix_world@v.co for v in me.vertices);fs.extend(tuple(offset+i for i in f.vertices) for f in me.polygons);ev.to_mesh_clear()
    return BVHTree.FromPolygons(vs,fs,all_triangles=False)
reveal=next((o for o in main.objects if o.get('asset_id')=='entry_reveal'),None)
solid=world_bvh(list(frame.children_recursive)+list(facade.children_recursive)+(list(reveal.children_recursive) if reveal else []))
sweep=[]
for angle in range(0,106,5):
    for o in door.children_recursive:
        if 'open_sign' in o:o.rotation_euler.z=math.radians(angle)*o['open_sign']
    leaf=world_bvh([part for hinge in door.children if 'open_sign' in hinge for part in hinge.children_recursive]);hits=leaf.overlap(solid)
    sweep.append(dict(angle=angle,intersecting_triangle_pairs=len(hits)))
check('door_sweep_clear_frame',not any(row['intersecting_triangle_pairs'] for row in sweep),samples=sweep)
for o in door.children_recursive:
    if 'open_sign' in o:o.rotation_euler.z=math.radians(105)*o['open_sign']
manifest=json.loads((out/'manifest.json').read_text(encoding='utf8'))
pews=[r for r in main.objects if r.get('asset_id')=='pew_2m']
groups={}
for r in pews:groups.setdefault(round(r.location.y,4),[]).append(r)
aisles=[]
for y,rs in groups.items():
    # Read actual transformed evaluated geometry, not nominal recipe bounds.
    bounds=[]
    for r in sorted(rs,key=lambda o:o.location.x):
        dg=bpy.context.evaluated_depsgraph_get();xs=[]
        for ob in r.children_recursive:
            if ob.type not in ('MESH','CURVE'):continue
            ev=ob.evaluated_get(dg);me=ev.to_mesh();xs.extend((ob.matrix_world@v.co).x for v in me.vertices);ev.to_mesh_clear()
        bounds.append((min(xs),max(xs)))
    aisles.append(bounds[1][0]-bounds[0][1])
check('central_aisle_measured',len(aisles)==manifest['preset']['pew_rows'] and min(aisles)>manifest['preset']['aisle_clear_width']-.001,measured_widths=aisles)
report=dict(passed=all(c['passed'] for c in checks),source=str(out/'abbey_kit.blend'),checks=checks)
(out/'tool_validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps(report,ensure_ascii=False))
