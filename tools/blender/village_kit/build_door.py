"""Match the saved T03 frame. Root is the room-side left hinge.
Blender +Z / Godot +Y rotation swings inward to Blender +Y / Godot -Z.
"""
import bpy, bmesh, math, os, json

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'models', 'village_kit')
SCALE = 3.0 / 2.3
# parts.door_set uses kit.door(dw-.2,dh-.1); these are its inner frame edges.
W, H = 1.3 * SCALE, 2.3 * SCALE
R, SPRING = W / 2, H - W / 2
EDGE_GAP, BOTTOM_GAP, T = 0.018, 0.026, 0.14
Y0 = -T / 2  # Leaf inside face is at hinge Y=0, in the wall reveal.
BLEND = os.path.join(OUT, 'door_leaf_hinged.blend')
GLB = os.path.join(OUT, 'door_leaf_hinged.glb')
bpy.ops.wm.read_factory_settings(use_empty=True)
root = bpy.data.objects.new('DoorLeaf_Hinged_Root', None)
bpy.context.scene.collection.objects.link(root)
root['asset_role'] = 'goldshire_village_runtime_door_leaf'
root['asset_revision'] = 'frame_fit_v2_20261011'
root['unit'] = 'metre'
root['door_width_m'] = W - 2 * EDGE_GAP
root['door_height_m'] = H - EDGE_GAP - BOTTOM_GAP
root['frame_opening_width_m'] = W
root['frame_opening_height_m'] = H
root['hinge_axis'], root['hinge_side'] = 'Z', 'left'
root['closed_plane'] = 'Blender Y=-0.07, inner wall corner hinge Y=0'
root['swing_direction'] = 'positive Godot Y rotation, inward Godot -Z'
root['open_angle_degrees'] = math.degrees(1.36)

def mat(name, color, rough=0.82, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color, m.use_nodes = (*color, 1), True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = rough
    bs.inputs['Metallic'].default_value = metallic
    return m

wood = mat('K|6|7a5236|pt_wood|1.8', (0.48, 0.32, 0.21))
wood2 = mat('K|6|8d6141|pt_wood_light|2.2', (0.55, 0.38, 0.25))
dark = mat('K|6|59412d|pt_wood|1.8', (0.35, 0.25, 0.17))
iron = mat('K|7|2b2f36|pt_metal|2.0', (0.06, 0.07, 0.08), 0.52, 0.12)

def soften(o, amount):
    if amount > 0:
        mod = o.modifiers.new('Soft timber edges', 'BEVEL')
        mod.width, mod.segments = amount, 2
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o

def add_box(name, dims, loc, material, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o = bpy.context.object
    o.name, o.dimensions, o.parent = name, dims, root
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    return soften(o, bevel)

def crown(x):
    return SPRING + math.sqrt(max(0.0, (R - EDGE_GAP)**2 - (x - R)**2))

def arch_strip(name, x0, x1, y0, y1, material, bevel=0.0):
    # Clip each plank itself, including overlay surfaces, against the arch.
    prof = [(x0, BOTTOM_GAP), (x1, BOTTOM_GAP)]
    prof += [(x1+(x0-x1)*i/12, crown(x1+(x0-x1)*i/12)) for i in range(13)]
    vs = [(x,y,z) for y in (y0,y1) for x,z in prof]
    n = len(prof)
    faces = [tuple(range(n)), tuple(range(n,2*n))[::-1]]
    faces += [(i,(i+1)%n,n+(i+1)%n,n+i) for i in range(n)]
    me = bpy.data.meshes.new(name + '_Mesh')
    me.from_pydata(vs,[],faces)
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(material)
    o = bpy.data.objects.new(name,me)
    bpy.context.scene.collection.objects.link(o)
    o.parent = root
    return soften(o,bevel)

# A recessed backing closes shallow seams without erasing the plank relief.
arch_strip('DoorLeaf_ArchBacking',EDGE_GAP,W-EDGE_GAP,-0.112,-0.028,dark)
pitch = (W-2*EDGE_GAP)/6
for i in range(6):
    x0 = EDGE_GAP+i*pitch+(0.003 if i else 0)
    x1 = EDGE_GAP+(i+1)*pitch-(0.003 if i<5 else 0)
    arch_strip('DoorBoard_%02d'%i,x0,x1,-T,0.0,wood2 if i%3==1 else wood,0.006)

# Construction battens are indoors and stay below the arch spring.
for z in (0.46,1.82):
    add_box('DoorRail_Inside',(W-0.12,0.055,0.14),(R,0.026,z),dark,0.012)
brace = add_box('DoorDiagonalBrace_Inside',(1.84,0.055,0.12),(R,0.027,1.14),dark,0.01)
brace.rotation_euler[1] = math.radians(-42)

# Pintles are vertical; straps and bolts stay inside the leaf silhouette.
front = -T-0.014
for i,z in enumerate((0.46,1.82)):
    add_box('HingeStrap_%d'%i,(0.69,0.038,0.092),(0.39,front,z),iron,0.009)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=0.029,depth=0.22,location=(0.032,0.0,z))
    pin = bpy.context.object
    pin.name,pin.parent = 'HingePin_Vertical_%d'%i,root
    pin.data.materials.append(iron)
    add_box('HingeKnuckle_%d'%i,(0.068,0.17,0.08),(0.04,-0.075,z),iron,0.007)
    for x in (0.14,0.40,0.65):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8,ring_count=4,radius=0.016,location=(x,front-0.021,z))
        bolt = bpy.context.object
        bolt.name,bolt.parent = 'HingeBolt',root
        bolt.data.materials.append(iron)
add_box('DoorPull_Backplate',(0.11,0.022,0.17),(W-0.25,-T-0.012,1.36),iron,0.008)
bpy.ops.mesh.primitive_torus_add(major_segments=20,minor_segments=6,
    location=(W-0.25,-T-0.046,1.31),major_radius=0.088,minor_radius=0.014,rotation=(math.pi/2,0,0))
ring = bpy.context.object
ring.name,ring.parent = 'DoorRingPull',root
ring.data.materials.append(iron)

# The existing wall cutout is 1.5x2.4, while its front trim narrows the
# opening to 1.3x2.3. A fixed timber reveal bridges that depth; without it
# the room is visible beside a closed room-side leaf. It must never rotate.
frame = bpy.data.objects.new('DoorFrame_Fixed_Root', None)
bpy.context.scene.collection.objects.link(frame)
frame['asset_role'] = 'fixed_door_reveal_reparent_to_building'
wall_t = 0.45*SCALE
outer_r = 1.5*SCALE/2
depth_front, depth_back = -wall_t+0.025, 0.006
frame_parts = []
for side in (-1,1):
    x = -0.0652173913 if side<0 else W+0.0652173913
    p = add_box('DoorReveal_Jamb', (outer_r-R, depth_back-depth_front, SPRING),
                (x, (depth_front+depth_back)/2, SPRING/2), dark, 0.003)
    p.parent = frame
    frame_parts.append(p)
vs, fs = [], []
for i in range(25):
    a = math.pi*i/24
    for y in (depth_front,depth_back):
        for radius in (R,outer_r):
            vs.append((R+radius*math.cos(a),y,SPRING+radius*math.sin(a)))
for i in range(24):
    j,k = i*4,(i+1)*4
    fs += [(j,k,k+1,j+1),(j+2,j+3,k+3,k+2),
           (j,j+2,k+2,k),(j+1,k+1,k+3,j+3)]
fs += [(0,1,3,2),(96,98,99,97)]
me = bpy.data.meshes.new('DoorReveal_Arch_Mesh')
me.from_pydata(vs,[],fs)
bm = bmesh.new()
bm.from_mesh(me)
bmesh.ops.recalc_face_normals(bm,faces=bm.faces)
bm.to_mesh(me)
bm.free()
me.materials.append(dark)
arch = bpy.data.objects.new('DoorReveal_Arch',me)
bpy.context.scene.collection.objects.link(arch)
arch.parent = frame
frame_parts.append(arch)
root['fixed_reveal_root'] = frame.name
bpy.ops.object.select_all(action='DESELECT')
for o in [root]+list(root.children)+[frame]+frame_parts: o.select_set(True)
bpy.context.view_layer.objects.active = root
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,
    use_active_scene=True,export_yup=True,export_apply=False,export_extras=True,export_animations=False)
meta = {
    'asset':'door_leaf_hinged.glb','source_blend':'door_leaf_hinged.blend',
    'revision':'frame_fit_v2_20261011','unit':'metres',
    'frame_opening':{'width':W,'height':H,'spring_height':SPRING,
        'source':'actual village frame inner edge: kit.door(dw-.2,dh-.1)'},
    'fixed_reveal':{'root':'DoorFrame_Fixed_Root','depth':depth_back-depth_front,
        'runtime_parent':'building _gen (detached from moving pivot)','material':'existing K wood'},
    'door_leaf':{'width':W-2*EDGE_GAP,'height':H-EDGE_GAP-BOTTOM_GAP,'thickness':T,
        'hinge_origin':[0,0,0],'hinge_side':'left','outline_gap':EDGE_GAP,'bottom_gap':BOTTOM_GAP,
        'closed_panel_blender_y':Y0,'closed_panel_godot_z':-Y0,
        'front_axis':'Blender -Y / Godot +Z','room_axis':'Blender +Y / Godot -Z',
        'runtime_open_angle_radians':1.36,'runtime_open_angle_degrees':math.degrees(1.36),
        'runtime_pivot':'opening left edge at inner wall face; door metadata is an approach point'},
    'collision':{'owner':'src/world/model_prop.gd','shape':'BoxShape3D',
        'closed_size':[W-2*EDGE_GAP,H-EDGE_GAP-BOTTOM_GAP,T],
        'closed_center':[R,(BOTTOM_GAP+H-EDGE_GAP)/2,-Y0],'disabled_when_abs_angle_gt':0.12}
}
json.dump(meta,open(os.path.join(OUT,'door_leaf_hinged.json'),'w',encoding='utf8'),indent=2)
print('DOOR_EXPORT',json.dumps(meta))
