"""Exercise the installed Blender add/snap operators on actual exported-library collections."""
import bpy,json,sys,math
from pathlib import Path
from mathutils import Vector
HERE=Path(__file__).resolve().parent;out=Path(sys.argv[sys.argv.index('--')+1])
bpy.ops.wm.read_factory_settings(use_empty=True)
exec(compile((HERE/'install_panel.py').read_text(encoding='utf8'),str(HERE/'install_panel.py'),'exec'))
checks=[];keys=['wall_plain_2','roof_8_terracotta','rail_2']
for row,key in enumerate(keys):
    bpy.context.scene.gs_module=key;bpy.context.scene.cursor.location=(row*12,0,0);bpy.ops.gs.add_module();a=bpy.context.active_object
    bpy.context.scene.cursor.location=(row*12,9,0);bpy.ops.gs.add_module();b=bpy.context.active_object
    a.select_set(True);bpy.context.view_layer.objects.active=a;bpy.ops.gs.snap_end();bpy.context.view_layer.update()
    sockets=ASSETS[key]['sockets'];p=a.matrix_world@Vector(sockets[1]['position_blender']);q=b.matrix_world@Vector(sockets[0]['position_blender'])
    checks.append({'asset':key,'operator':'gs.snap_end','measured_gap_m':(p-q).length,'passed':(p-q).length<1e-5})
# Rotated repeat tests do not silently use a world-X-only offset.
a.rotation_euler.z=math.pi/2;bpy.context.view_layer.objects.active=a;bpy.ops.gs.snap_end();bpy.context.view_layer.update()
p=a.matrix_world@Vector(sockets[1]['position_blender']);q=b.matrix_world@Vector(sockets[0]['position_blender'])
checks.append({'asset':'rail_2','operator':'rotated gs.snap_end','measured_gap_m':(p-q).length,'passed':(p-q).length<1e-5})
bpy.ops.wm.save_as_mainfile(filepath=str(out/'assembly_tool_check.blend'))
(out/'tool_validation.json').write_text(json.dumps({'passed':all(c['passed'] for c in checks),'checks':checks},indent=2),encoding='utf8')
print('TOOL_CHECK',checks)
