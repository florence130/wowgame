"""Background-only panel interaction and editable-save/reopen check on a build."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;sys.path.insert(0,str(HERE))
import blender_panel as panel
folder=Path(bpy.data.filepath).parent
if not bpy.app.background:raise RuntimeError('Run against a saved build in background Blender')
panel.register();scene=bpy.data.scenes.new('ABY_Panel_Test');bpy.context.window.scene=scene
scene.aby_settings.directory=str(folder)
assert bpy.ops.aby.read_catalog()=={'FINISHED'}
scene.aby_settings.asset='wall_plain_4'
scene.cursor.location=(4,3,0);assert bpy.ops.aby.add_component()=={'FINISHED'};fixed=bpy.context.object;fixed.rotation_euler.z=math.pi/2
scene.cursor.location=(12,-7,0);assert bpy.ops.aby.add_component()=={'FINISHED'};moved=bpy.context.object
fixed.select_set(True);bpy.context.view_layer.objects.active=fixed;bpy.context.view_layer.update()
assert bpy.ops.aby.snap_component()=={'FINISHED'};bpy.context.view_layer.update()
gap=((fixed.matrix_world@Vector((2,0,0)))-(moved.matrix_world@Vector((-2,0,0)))).length
assert gap<1e-5,gap
source=bpy.data.scenes['ABY_Bridge'];bpy.context.window.scene=source
bridge=next(o for o in source.objects if any(m.type=='CURVE' for m in o.modifiers))
arr=next(m for m in bridge.modifiers if m.type=='ARRAY');before=arr.count;arr.count=before+1
dest=folder/'editable_roundtrip.blend'
if dest.exists():raise FileExistsError(dest)
bpy.ops.wm.save_as_mainfile(filepath=str(dest))
bpy.ops.wm.open_mainfile(filepath=str(dest));s=bpy.data.scenes['ABY_Bridge'];bpy.context.window.scene=s
o=next(o for o in s.objects if any(m.type=='CURVE' for m in o.modifiers));mod=next(m for m in o.modifiers if m.type=='ARRAY')
assert mod.count==before+1
report={'passed':True,'panel_read_add_snap':'executed registered operators on two rotated instances','snap_gap_m':gap,'saved_reopened_file':str(dest),'bridge_array_count_before':before,'after_reopen':mod.count,'note':'This copy intentionally changes count without extending path. It only tests editable persistence; not the selected design candidate.'}
(folder/'roundtrip_validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
print('ROUNDTRIP_PASS',json.dumps(report))
