"""Open the built Blend in BACKGROUND and produce rear + modular proof images."""
from pathlib import Path
import sys,json,math
import bpy
from mathutils import Vector
HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'abbey_kit'))
import build as B

out=Path(sys.argv[sys.argv.index('--')+1])
bpy.ops.wm.open_mainfile(filepath=str(out/'abbey_kit.blend'))
demo=bpy.data.scenes['ABY2_game_Courtyard'];bpy.context.window.scene=demo
demo.cycles.samples=32
demo.render.resolution_x=1500;demo.render.resolution_y=1200
demo.camera.location=(15,-26,5.5);demo.camera.rotation_euler=(Vector((4,-9.5,2.1))-demo.camera.location).to_track_quat('-Z','Y').to_euler();demo.camera.data.ortho_scale=13
B.render(demo,out/'renders'/'apse_base_closeup.png')
demo.camera.location=(25,-30,21);demo.camera.rotation_euler=(Vector((0,-2,5))-demo.camera.location).to_track_quat('-Z','Y').to_euler();demo.camera.data.ortho_scale=35
B.render(demo,out/'renders'/'rear_apse.png')
# Side-by-side physical join proof: all components appended from the real library.
ns={};exec((HERE/'install_panel.py').read_text(encoding='utf8'),dict(__file__=str(HERE/'install_panel.py'),__name__='__main__'))
new=bpy.data.scenes.new('ABY2_ModuleJoinProof');bpy.context.window.scene=new
new.world=demo.world.copy();new.render.engine='CYCLES';new.cycles.samples=32;new.cycles.use_denoising=True
new.view_settings.view_transform=demo.view_settings.view_transform;new.view_settings.look=demo.view_settings.look;new.view_settings.exposure=demo.view_settings.exposure
for o in demo.objects:
    if o.type=='LIGHT' or o.name=='Presentation ground':new.collection.objects.link(o.copy())
new.aby_settings.directory=str(out);new.aby_settings.target_socket='end';new.aby_settings.moving_socket='start';bpy.ops.aby.read_catalog()
placed=[];results=[]
for key,origin in [('roof_nave_4',(-5,-2,0)),('boundary_4',(6,-3,0)),('wall_clerestory_4',(6,2,0))]:
    new.aby_settings.asset=key;new.cursor.location=origin;bpy.ops.aby.add_component();fixed=bpy.context.active_object
    new.cursor.location=(origin[0]+.7,origin[1]+7,origin[2]);bpy.ops.aby.add_component();moving=bpy.context.active_object
    moving.select_set(True);fixed.select_set(True);new.view_layers[0].objects.active=fixed
    result=bpy.ops.aby.snap_component();bpy.context.view_layer.update()
    axis=1 if key.startswith('roof') else 0
    end=Vector((0,2,0)) if axis==1 else Vector((2,0,0));start=-end
    distance=((fixed.matrix_world@end)-(moving.matrix_world@start)).length
    results.append(dict(asset=key,operator=sorted(result),socket_distance_metres=distance,passed=distance<1e-6))
    placed.extend([fixed,moving]);bpy.ops.object.select_all(action='DESELECT')
B.camera(new,(1,1,2.4),(20,29,22),30,1600)
B.render(new,out/'renders'/'module_join_proof.png')
(out/'panel_join_validation.json').write_text(json.dumps(dict(tests=results,passed=all(r['passed'] for r in results)),indent=2),encoding='utf8')
print('JOIN CHECKS',results)
# Test scene is a separate .blend; never overwrite the clean source kit.
bpy.ops.wm.save_as_mainfile(filepath=str(out/'assembly_check.blend'))
