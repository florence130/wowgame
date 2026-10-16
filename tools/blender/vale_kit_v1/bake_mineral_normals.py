"""Bake native procedural mineral microrelief into glTF-compatible normal maps.
This creates data textures from Blender shaders, without altering the generated albedo images.
"""
import bpy,pathlib
folder=pathlib.Path('E:/wowgame/assets/models/vale_kit_v1/textures')
for prefix,fine,coarse,distance in [('sandstone_grain',170,24,.009),('brick_porous',115,16,.014)]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=8
    bpy.ops.mesh.primitive_plane_add(size=2);o=bpy.context.object
    m=bpy.data.materials.new(prefix);m.use_nodes=True;o.data.materials.append(m)
    n=m.node_tree.nodes;link=m.node_tree.links;bs=n.get('Principled BSDF')
    uv=n.new('ShaderNodeTexCoord')
    noises=[]
    for scale in [fine,coarse]:
        noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=scale;noise.inputs['Detail'].default_value=3;noise.inputs['Roughness'].default_value=.72
        link.new(uv.outputs['UV'],noise.inputs['Vector']);noises.append(noise)
    mix=n.new('ShaderNodeMixRGB');mix.blend_type='MIX';mix.inputs[0].default_value=.22
    link.new(noises[0].outputs['Fac'],mix.inputs[1]);link.new(noises[1].outputs['Fac'],mix.inputs[2])
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.7;bump.inputs['Distance'].default_value=distance
    link.new(mix.outputs[0],bump.inputs['Height']);link.new(bump.outputs['Normal'],bs.inputs['Normal'])
    im=bpy.data.images.new(prefix+'_normal',1024,1024);im.colorspace_settings.name='Non-Color'
    target=n.new('ShaderNodeTexImage');target.image=im;n.active=target
    bpy.ops.object.bake(type='NORMAL',normal_space='TANGENT',margin=8)
    im.filepath_raw=str(folder/(prefix+'_normal.png'));im.file_format='PNG';im.save()
    print('BAKED',im.filepath_raw)
