"""Transparent, light-responsive abbey WINDOW glass, Blender and glTF/Godot.

Call configure() after material creation and before export/render. Selection is
strictly by legacy recipe_key glass / glass_amber. The new window_glow lantern
material is never changed, even though its palette name matches amber glazing.
"""
import bpy


WINDOW_COLORS={'glass':'3F5F86','glass_amber':'FFD98A'}


def _linear(channel):
    v=channel/255
    return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4


def configure(alpha=.28,transmission=.72,roughness=.10,ior=1.33,materials=None):
    """Configure transparent Principled windows; return exact changed-material evidence.

    Alpha blending is the portable glTF/Godot path. Principled transmission/IOR
    additionally give Cycles actual glass refraction and optical transmission.
    No unlit shader, emission or added lamp is used to imitate transparency.
    """
    if not 0<alpha<1 or not 0<=transmission<=1 or not 0<=roughness<=1 or not 1<=ior<=2:
        raise ValueError('Expected 0<alpha<1, transmission/roughness in[0,1], IOR in[1,2]')
    changed=[]
    for mat in (bpy.data.materials if materials is None else materials):
        key=mat.get('recipe_key')
        if key not in WINDOW_COLORS:continue
        mat.use_nodes=True
        principled=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
        if principled is None:raise ValueError('Window material has no Principled BSDF: '+mat.name)
        h=WINDOW_COLORS[key]
        rgb=tuple(_linear(int(h[i:i+2],16)) for i in (0,2,4))
        principled.inputs['Base Color'].default_value=(*rgb,1)
        for name,value in [('Alpha',alpha),('Transmission Weight',transmission),
                           ('Roughness',roughness),('IOR',ior),('Metallic',0),
                           ('Emission Strength',0)]:
            socket=principled.inputs.get(name)
            if socket is None:continue
            for link in list(socket.links):mat.node_tree.links.remove(link)
            socket.default_value=value
        if 'Emission Color' in principled.inputs:principled.inputs['Emission Color'].default_value=(0,0,0,1)
        if 'Coat Weight' in principled.inputs:principled.inputs['Coat Weight'].default_value=.08
        if 'Coat Roughness' in principled.inputs:principled.inputs['Coat Roughness'].default_value=.15
        mat.diffuse_color=(*rgb,alpha)
        if hasattr(mat,'surface_render_method'):mat.surface_render_method='DITHERED'
        elif hasattr(mat,'blend_method'):mat.blend_method='BLEND'
        # Avoid excessive double blending in raster viewports while retaining
        # the original thin solid glass geometry and Cycles transmission.
        if hasattr(mat,'use_transparency_overlap'):mat.use_transparency_overlap=False
        mat.use_backface_culling=False
        mat['window_transparent']=True
        mat['base_color_srgb']=h
        mat['window_alpha']=float(alpha)
        mat['window_transmission']=float(transmission)
        mat['window_ior']=float(ior)
        changed.append({'material':mat.name,'recipe_key':key,'base_color_srgb':h,
                        'alpha':alpha,'transmission':transmission,'roughness':roughness,'ior':ior,
                        'emission_strength':0,'surface_render_method':getattr(mat,'surface_render_method','BLEND')})
    return {'changed':changed,'count':len(changed),'untouched_recipe_key':'window_glow',
            'portable_transparency':'glTF alphaMode BLEND / StandardMaterial3D alpha transparency',
            'optical_transmission':'Principled Transmission Weight plus KHR_materials_transmission when exported'}
