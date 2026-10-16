"""Retain Kenney low-poly topology, rebuild material groups for the game palette."""
from pathlib import Path
import bpy, json, math

ROOT=Path('E:/wowgame')
SOURCE=ROOT/'assets/models/roadside_cc0'
OUTPUT=ROOT/'assets/models/roadside_cc0/rebuilt'
OUTPUT.mkdir(parents=True,exist_ok=True)
HEIGHTS={'cart':1.1,'cart-high':1.35,'stall':.95,'stall-bench':.50,'banner-green':3.1}
report=[]
MATERIAL_CACHE={}

def material(name, color, kind, texture, metres):
    value=MATERIAL_CACHE.get(name)
    if value:return value
    value=bpy.data.materials.new(name)
    value.diffuse_color=(*color,1)
    value.use_nodes=True
    shader=value.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1)
    shader.inputs['Roughness'].default_value=.82 if kind!=7 else .58
    shader.inputs['Metallic'].default_value=.65 if kind==7 else 0
    rgb=''.join(f'{round(c*255):02x}' for c in color)
    value.name=f'K|{kind}|{rgb}|{texture}|{metres}'
    MATERIAL_CACHE[name]=value
    return value

for stem,height in HEIGHTS.items():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE/(stem+'.glb')))
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    polygons=0;triangles=0;bounds=[];colors=set()
    for obj in objects:
        obj.data=obj.data.copy()
        for polygon in obj.data.polygons:
            mat=obj.material_slots[polygon.material_index].material
            image_node=next((n for n in mat.node_tree.nodes if n.type=='TEX_IMAGE' and n.image),None) if mat and mat.use_nodes else None
            color=tuple(mat.diffuse_color[:3]) if mat else (.5,.35,.2)
            if image_node and obj.data.uv_layers.active:
                uv=obj.data.uv_layers.active.data[polygon.loop_start].uv
                image=image_node.image
                x=min(image.size[0]-1,max(0,int(uv.x*image.size[0])))
                y=min(image.size[1]-1,max(0,int(uv.y*image.size[1])))
                offset=(y*image.size[0]+x)*image.channels
                color=tuple(image.pixels[offset:offset+3])
            colors.add(tuple(round(c,2) for c in color))
            r,g,b=color
            if g>r*1.18 and g>b*1.1:
                target=material('cloth_sage',(.27,.43,.36),0,'pt_plaster',2.0)
            elif max(color)-min(color)<.13 and max(color)<.4:
                target=material('forged_iron',(.16,.19,.22),7,'',0)
            elif max(color)>.85 and min(color)>.68:
                target=material('canvas',(.73,.67,.52),0,'pt_plaster',1.6)
            else:
                shade=.8 if sum(color)<1.1 else 1.0 if sum(color)<1.8 else 1.13
                target=material('oak_'+str(shade),tuple(c*shade for c in (.42,.29,.17)),6,'pt_wood',1.8)
            if target.name not in [m.name for m in obj.data.materials]:obj.data.materials.append(target)
            polygon.material_index=obj.data.materials.find(target.name)
        # Remove unused source slots so original palette textures do not ship.
        used=sorted(set(p.material_index for p in obj.data.polygons))
        materials=[obj.data.materials[i] for i in used]
        indices={old:new for new,old in enumerate(used)}
        remap=[indices[p.material_index] for p in obj.data.polygons]
        obj.data.materials.clear()
        for m in materials:obj.data.materials.append(m)
        for p,index in zip(obj.data.polygons,remap):p.material_index=index
        bounds.extend(obj.matrix_world @ __import__('mathutils').Vector(v) for v in obj.bound_box)
        polygons+=len(obj.data.polygons)
        triangles+=sum(max(0,len(p.vertices)-2) for p in obj.data.polygons)
    zlo=min(v.z for v in bounds);zhi=max(v.z for v in bounds)
    factor=height/(zhi-zlo)
    # glTF scene imports use applied conversion axes; bake world transforms.
    for obj in objects:
        obj.data.transform(obj.matrix_world)
        obj.matrix_world.identity()
        for vertex in obj.data.vertices:
            vertex.co.z-=zlo
            vertex.co*=factor
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT/(stem+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_materials='EXPORT')
    report.append({'asset':stem,'source':'Kenney Fantasy Town Kit 2.0','license':'CC0-1.0','triangles':triangles,'height_m':height,'source_palette':sorted(colors),'modifications':'Native low-poly topology retained. Source palette image removed; rebuilt oak/iron/sage cloth material groups, native meter scale, grounded base.'})
(OUTPUT/'manifest.json').write_text(json.dumps(report,indent=2))
print('REBUILT_CC0',len(report),sum(r['triangles'] for r in report))
