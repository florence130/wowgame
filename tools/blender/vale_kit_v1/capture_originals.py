"""Render the project's original GLBs with their actual gen_vale farm colours."""
import bpy, math, pathlib, json
from mathutils import Vector
ROOT=pathlib.Path('E:/wowgame')
OUT=ROOT/'docs/vale_kit_v1/references';OUT.mkdir(parents=True,exist_ok=True)
def color(h):
    return tuple(((int(h[i:i+2],16)/255+.055)/1.055)**2.4 if int(h[i:i+2],16)/255>.04045 else int(h[i:i+2],16)/255/12.92 for i in (0,2,4))+(1,)
records=[('farmhouse','house_0',(12/8.5,9/8,6/5.5),['F0E4C8','B8553A','6A4A30']),('barn','house_1',(16/8.5,11/8,8/5.5),['B04030','5A3A2A','F0E8D8']),('windmill','windmill_0',(1,1,1),['F0E4C8','8A4A3A','6A4A30'])]
for name,src,scale,pal in records:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/f'assets/models/{src}.glb'))
    for o in list(bpy.context.scene.objects):
        if o.parent is None:o.scale=scale
    for m in bpy.data.materials:
        key=m.name.split('.')[0]
        if key in ['A','B','C']:
            c=color(pal[['A','B','C'].index(key)]);m.diffuse_color=c
            for n in m.node_tree.nodes:
                if n.type=='BSDF_PRINCIPLED':n.inputs['Base Color'].default_value=c
    if name=='windmill':
        old=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/models/windmill_blades_0.glb'))
        for o in set(bpy.data.objects)-old:
            if o.parent is None:o.location+=(Vector((0,3.35,11.9)))
    bpy.context.view_layer.update()
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    pts=[o.matrix_world@Vector(c) for o in meshes for c in o.bound_box]
    lo=Vector(tuple(min(p[i] for p in pts) for i in range(3)));hi=Vector(tuple(max(p[i] for p in pts) for i in range(3)));lo.z=0
    ctr=(lo+hi)/2;span=max(hi-lo)
    sc=bpy.context.scene;sc.render.engine='BLENDER_EEVEE';sc.render.resolution_x=1000;sc.render.resolution_y=1000;sc.render.resolution_percentage=100
    sc.world=bpy.data.worlds.new('Reference world');sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs[0].default_value=(.65,.70,.78,1);sc.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    bpy.ops.mesh.primitive_plane_add(size=200);plane=bpy.context.object;plane.name='Ground at actual terrain level'
    m=bpy.data.materials.new('ground');m.diffuse_color=color('E6DECA');plane.data.materials.append(m)
    ld=bpy.data.lights.new('daylight','AREA');ld.energy=2600;ld.shape='DISK';ld.size=10;light=bpy.data.objects.new('daylight',ld);sc.collection.objects.link(light);light.location=(8,10,24);light.rotation_euler=(Vector((0,0,4))-light.location).to_track_quat('-Z','Y').to_euler()
    cd=bpy.data.cameras.new('reference');cam=bpy.data.objects.new('reference',cd);sc.collection.objects.link(cam);cam.location=ctr+Vector((.9,1.5,.7))*span;cam.rotation_euler=(ctr-cam.location).to_track_quat('-Z','Y').to_euler();cd.type='ORTHO';cd.ortho_scale=span*1.4;sc.camera=cam
    sc.view_settings.view_transform='Standard';sc.render.filepath=str(OUT/f'original_{name}.png');bpy.ops.render.render(write_still=True)
(OUT/'source_map.json').write_text(json.dumps({'sources':records,'map_source':'tools/gen_vale.gd::_farms','barn_roof_exception':'Fixed thatch material C8A868 is not recoloured by color_b. Keep golden thatch.','front':'Blender +Y / Godot -Z'},indent=2),encoding='utf-8')
