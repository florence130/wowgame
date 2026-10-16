"""Independent background Blender smoke check and lit contact-shadow render."""
import sys, math, os
sys.path[:0] = [r'E:\wowgame\tools\blender\abbey_kit_v2',r'E:\wowgame\tools\blender\abbey_kit']
import bpy
from mathutils import Vector
import geometry as G
import details as D

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
G.COL=bpy.context.scene.collection
G.ROOT=None
def lit_material(key):
    if key in G.MATS: return G.MATS[key]
    h=G.PALETTE[key]
    color=tuple(G.linear(int(h[i:i+2],16)) for i in (0,2,4))+(1,)
    m=bpy.data.materials.new('ABY_probe_'+key)
    m.diffuse_color=color
    m.use_nodes=True
    m.node_tree.nodes.clear()
    out=m.node_tree.nodes.new('ShaderNodeOutputMaterial')
    bs=m.node_tree.nodes.new('ShaderNodeBsdfPrincipled')
    m.node_tree.links.new(bs.outputs['BSDF'],out.inputs['Surface'])
    bs.inputs['Base Color'].default_value=color
    bs.inputs['Roughness'].default_value=.86
    G.MATS[key]=m
    return m
G.material=lit_material

objects=[]
for fn,kwargs,offset in [
    (D.stone_arch,{},(-4,0,0)),
    (D.oak_double_door,{},(-4,-.04,0)),
    (D.pointed_window,{},(0,0,0)),
    (D.rose_window,{},(3.4,0,2.3)),
    (D.quoin_column,{'height':3.3},(5.5,0,0)),
    (D.ivy_patch,{},(7.0,0,0)),
    (D.wall_banner,{},(8.6,0,0)),
    (D.corbel,{},(8.6,0,3.3)),
    (D.vegetation_shrub,{},(-6.8,0,0)),
    (D.cypress,{},(-8.5,0,0)),
]:
    result=fn(**kwargs)
    assert isinstance(result,list) and result
    for o in result:
        o.location=offset
        assert len(o.data.polygons)>0
        assert all(math.isfinite(c) for v in o.data.vertices for c in v.co)
        assert all(p.material_index<len(o.data.materials) for p in o.data.polygons)
        objects.append(o)
        print('DETAIL_OK',o.name,len(o.data.vertices),len(o.data.polygons),len(o.data.materials),flush=True)

G.box('Backdrop',(21,.14,5.6),(0,-.28,2.75),'plaster')
G.box('Ground',(24,8,.14),(0,0,-.12),'stone_light')
scene=bpy.context.scene
scene.render.engine='CYCLES'
scene.cycles.samples=24
scene.cycles.use_denoising=True
scene.render.resolution_x=2200
scene.render.resolution_y=780
scene.render.resolution_percentage=100
scene.world.color=(.28,.28,.28)
bpy.ops.object.light_add(type='AREA',location=(-3,5,10))
light=bpy.context.object
light.data.energy=1900
light.data.shape='DISK'
light.data.size=5
light.rotation_euler=(Vector((1,0,1.5))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.light_add(type='AREA',location=(7,3,5))
light=bpy.context.object
light.data.energy=400
light.data.size=5
light.rotation_euler=(Vector((2,0,2))-light.location).to_track_quat('-Z','Y').to_euler()
bpy.ops.object.camera_add(location=(-.5,19,8.3))
cam=bpy.context.object
cam.rotation_euler=(Vector((0,0,2))-cam.location).to_track_quat('-Z','Y').to_euler()
cam.data.type='ORTHO'
cam.data.ortho_scale=21
scene.camera=cam
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG'
scene.render.filepath=r'E:\wowgame\tools\blender\abbey_kit_v2\detail_probe.png'
bpy.ops.wm.save_as_mainfile(filepath=r'E:\wowgame\tools\blender\abbey_kit_v2\detail_probe.blend')
bpy.ops.render.render(write_still=True)
print('DETAIL_PROBE_COMPLETE',len(objects),flush=True)
