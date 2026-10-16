"""Convert purchased Cartoon Grass FBX plants into small, normalized Godot meshes."""
import bpy
from pathlib import Path
from mathutils import Vector
import json

ROOT = Path('E:/wowgame')
SOURCE = ROOT / '.local/environment_20261011/source/plants/Assets/CartoonGrass/Models'
OUTPUT = ROOT / 'assets/models/cartoon_plants'
OUTPUT.mkdir(parents=True, exist_ok=True)
ITEMS = {
    'grass_near': ('Grass_04-1', 0.56),
    'grass_far': ('Grass_04-1', 0.56),
    'grass_wide': ('Grass_04-1', 0.55),
    'flower_white': ('Flower_01', 0.56),
    'flower_yellow': ('Flower_02', 0.54),
    'flower_blue': ('Flower_03', 0.60),
    'flower_pink': ('Flower_04', 0.56),
    'plant_broad': ('Plant_01', 0.64),
    'plant_fern': ('Plant_07', 0.72),
    'plant_leaf': ('Plant_10', 0.65),
}
report = {}
for key, (name, height) in ITEMS.items():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.fbx(filepath=str(SOURCE / (name + '.fbx')))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for o in objects:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    lo = Vector(tuple(min(v.co[i] for v in obj.data.vertices) for i in range(3)))
    hi = Vector(tuple(max(v.co[i] for v in obj.data.vertices) for i in range(3)))
    factor = height / max(hi.z - lo.z, 0.001)
    center = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    for v in obj.data.vertices:
        v.co = (v.co - center) * factor
    width = max(max(v.co.x for v in obj.data.vertices) - min(v.co.x for v in obj.data.vertices), max(v.co.y for v in obj.data.vertices) - min(v.co.y for v in obj.data.vertices))
    if width > 1.2:
        for v in obj.data.vertices:
            v.co.x *= 1.2 / width
            v.co.y *= 1.2 / width
    if key == 'grass_far':
        modifier = obj.modifiers.new('Distant silhouette', 'DECIMATE')
        modifier.ratio = 0.45
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.location = (0, 0, 0)
    obj.name = key
    obj.data.materials.clear()
    # Vertex colors separate original green leaves from petals in the Godot shader.
    # Sample the source palette through its original UVs, so flower identities survive.
    atlas = bpy.data.images.load(str(ROOT / '.local/environment_20261011/source/plants/Assets/CartoonGrass/Textures/CartoonGrass_Texture_01.png'), check_existing=True)
    w, h = atlas.size
    pixels = list(atlas.pixels)
    colors = obj.data.color_attributes.new(name='SourcePalette', type='FLOAT_COLOR', domain='CORNER')
    uv = obj.data.uv_layers.active
    for face in obj.data.polygons:
        for li in face.loop_indices:
            u, v = uv.data[li].uv if uv else (0.25, 0.25)
            ix = min(w - 1, max(0, int(u * w)))
            iy = min(h - 1, max(0, int(v * h)))
            color = pixels[(iy * w + ix) * 4:(iy * w + ix) * 4 + 4]
            colors.data[li].color = color
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / (key + '.glb')), export_format='GLB', use_selection=True, export_materials='NONE', export_vertex_color='ACTIVE', export_active_vertex_color_when_no_material=True, export_normals=True, export_texcoords=True)
    report[key] = {'source': name + '.fbx', 'height_m': height, 'original_size': list(hi - lo), 'vertices': len(obj.data.vertices), 'polygons': len(obj.data.polygons)}
    print('PLANT', key, report[key])
(OUTPUT / 'conversion.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
