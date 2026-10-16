# Build stylized low-poly building/prop models and export GLB for Godot.
# Run: blender -b --factory-startup --python tools/blender/build_models.py -- <out_dir> [name1,name2,...]
#
# Conventions (read by src/world/model_prop.gd):
#  * Origin = base center. FRONT (doors) faces Blender +Y  -> glTF/Godot -Z.
#  * Recolorable materials are named "A" (walls / main), "B" (roof / canopy), "C" (beams / trim / wood accent).
#    Fixed materials: stone, stone_dark, glass (replaced by the game's night-glowing window material),
#    door, metal, gold, plant, cloth, thatch.
#  * Each model's nominal size (x = width, z = wall height, y = depth in Blender) is written to models.json
#    so the game can scale an instance to a requested size.
import bpy, bmesh, sys, os, math, json, random
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(os.getcwd(), "assets", "models")
ONLY = set(argv[1].split(",")) if len(argv) > 1 and argv[1] else None
os.makedirs(OUT, exist_ok=True)

COLORS = {
    "A": "efe6d2", "B": "2f6fa8", "C": "6a4a30", "stone": "b9b1a1", "stone_dark": "8e877a", "glass": "6a8ab0",
    "door": "5a3a24", "metal": "3a3a44", "gold": "d8b060", "plant": "4f8f3a", "cloth": "f2ede0", "thatch": "c8a868",
    "lamp": "fff0c0", "flower_r": "ff7090", "flower_y": "ffd040", "wood_dark": "4a3020", "red": "c04040",
}
_mats = {}


def mat(name):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    h = COLORS.get(name, "ff00ff")
    c = tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4))
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*c, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    m.diffuse_color = (*c, 1.0)
    _mats[name] = m
    return m


PARTS = []


def _finish(obj, m, bevel=0.0):
    obj.data.materials.append(mat(m))
    if bevel > 0.0:
        mod = obj.modifiers.new("bv", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
    PARTS.append(obj)
    return obj


def box(sx, sy, sz, x, y, z, m, bevel=0.03, rot=(0, 0, 0)):
    """Box with min-z at z (sits on z)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(x, y, z + sz * 0.5), rotation=rot)
    o = bpy.context.active_object
    o.scale = (sx, sy, sz)
    return _finish(o, m, bevel)


def cyl(r, h, x, y, z, m, verts=12, r2=None, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r2 is None else r2, depth=h,
                                    location=(x, y, z + h * 0.5), rotation=rot)
    return _finish(bpy.context.active_object, m, bevel)


def mesh_obj(verts, faces, m):
    me = bpy.data.meshes.new("m")
    me.from_pydata(verts, [], faces)
    me.update()
    o = bpy.data.objects.new("o", me)
    bpy.context.collection.objects.link(o)
    return _finish(o, m)


def gable(w, d, z, h, m, over=0.4, axis="x"):
    """Gable roof prism; ridge along X (axis='x') or Y."""
    if axis == "x":
        x0, x1, y0, y1 = -w / 2 - over, w / 2 + over, -d / 2 - over, d / 2 + over
        v = [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z), (x0, 0, z + h), (x1, 0, z + h)]
        f = [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (0, 3, 2, 1)]
    else:
        x0, x1, y0, y1 = -w / 2 - over, w / 2 + over, -d / 2 - over, d / 2 + over
        v = [(x0, y0, z), (x1, y0, z), (x1, y1, z), (x0, y1, z), (0, y0, z + h), (0, y1, z + h)]
        f = [(1, 2, 5, 4), (3, 0, 4, 5), (0, 1, 4), (2, 3, 5), (0, 3, 2, 1)]
    o = mesh_obj(v, f, m)
    sol = o.modifiers.new("s", "SOLIDIFY")
    sol.thickness = 0.18
    return o


def frustum(w0, d0, w1, d1, z, h, m):
    """Truncated pyramid (mansard / hip)."""
    v = [(-w0 / 2, -d0 / 2, z), (w0 / 2, -d0 / 2, z), (w0 / 2, d0 / 2, z), (-w0 / 2, d0 / 2, z),
         (-w1 / 2, -d1 / 2, z + h), (w1 / 2, -d1 / 2, z + h), (w1 / 2, d1 / 2, z + h), (-w1 / 2, d1 / 2, z + h)]
    f = [(0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7), (4, 5, 6, 7), (0, 3, 2, 1)]
    return mesh_obj(v, f, m)


def window(x, y, z, w, h, facing, frame="C", arched=False):
    """Window on a wall face. facing: '+y','-y','+x','-x' (outward normal)."""
    t = 0.12
    if facing in ("+y", "-y"):
        s = 1 if facing == "+y" else -1
        box(w + 0.18, t, h + 0.18, x, y + s * 0.02, z - 0.09, frame, 0.02)
        box(w, t, h, x, y + s * 0.07, z, "glass", 0.0)
        box(0.07, t, h, x, y + s * 0.1, z, frame, 0.0)
        box(w + 0.3, 0.28, 0.1, x, y + s * 0.12, z - 0.16, frame, 0.02)
        if arched:
            cyl(w * 0.5, t, x, y + s * 0.07, z + h, "glass", 12, rot=(math.pi / 2, 0, 0))
    else:
        s = 1 if facing == "+x" else -1
        box(t, w + 0.18, h + 0.18, x + s * 0.02, y, z - 0.09, frame, 0.02)
        box(t, w, h, x + s * 0.07, y, z, "glass", 0.0)
        box(t, 0.07, h, x + s * 0.1, y, z, frame, 0.0)
        box(0.28, w + 0.3, 0.1, x + s * 0.12, y, z - 0.16, frame, 0.02)


def door(x, y, z, w, h, facing="+y", m="door"):
    s = 1 if facing == "+y" else -1
    box(w + 0.3, 0.14, h + 0.15, x, y + s * 0.02, z, "C", 0.02)
    box(w, 0.16, h, x, y + s * 0.06, z, m, 0.02)
    cyl(w * 0.5, 0.16, x, y + s * 0.06 - 0.08, z + h, m, 12, rot=(math.pi / 2, 0, 0))
    box(0.08, 0.08, 0.08, x + w * 0.3, y + s * 0.16, z + h * 0.45, "gold", 0.0)


def export(name, nominal):
    """Join parts, export GLB, record nominal size [width, wall_height, depth]."""
    global PARTS
    bpy.ops.object.select_all(action="DESELECT")
    for p in PARTS:
        p.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    # 统一法线朝外（随机扰动的团块、负缩放的部件会产生翻面，游戏里背面剔除后显示成"透明三角"）
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(o.data)
    bm.free()
    for poly in o.data.polygons:
        poly.use_smooth = False
    path = os.path.join(OUT, name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_apply=True, export_yup=True)
    NOMINAL[name] = nominal
    bpy.data.objects.remove(o, do_unlink=True)
    PARTS = []
    print("EXPORTED", name)


NOMINAL = {}

# ======================================================================== buildings


def build_rowhouse(variant):
    W, D, H = 10.0, 11.0, 13.5
    random.seed(10 + variant)
    box(W + 0.3, D + 0.3, 2.6, 0, 0, -2.3, "stone_dark", 0.04)
    box(W, D, 3.4, 0, 0, 0, "stone", 0.04)
    box(W - 0.1, D - 0.1, H - 3.4, 0, 0, 3.4, "A", 0.03)
    floors = int(H / 3.4)
    for f in range(1, floors):
        box(W + 0.2, D + 0.2, 0.22, 0, 0, f * 3.4 - 0.11, "C", 0.02)
    box(W + 0.4, D + 0.4, 0.4, 0, 0, H - 0.2, "C", 0.03)
    # 曼萨德屋顶 + 平顶 + 老虎窗 + 烟囱
    frustum(W + 0.2, D + 0.2, W * 0.72, D * 0.72, H + 0.2, 2.8, "B")
    box(W * 0.72, D * 0.72, 0.15, 0, 0, H + 3.0, "B", 0.0)
    ncol = 3
    for i in range(ncol):
        x = (i - (ncol - 1) * 0.5) * (W / ncol)
        if variant != 3:
            box(1.2, 1.0, 1.4, x, D / 2 - 0.6, H + 0.4, "A", 0.03)
            gable(1.2, 1.0, H + 1.8, 0.6, "B", 0.1, "y")
            window(x, D / 2 - 0.08, H + 0.7, 0.7, 0.8, "+y")
    for sx in (-1, 1):
        box(0.9, 0.9, 2.8, sx * (W / 2 - 0.7), -D * 0.2, H + 1.2, "stone_dark", 0.03)
    # 窗：前后各 3 列 × 每层
    for f in range(1, floors):
        z = f * 3.4 + 0.8
        if z > H - 1.2:
            break
        for i in range(ncol):
            x = (i - (ncol - 1) * 0.5) * (W / ncol)
            window(x, D / 2, z, 1.0, 1.7, "+y", arched=(variant % 2 == 0))
            window(x, -D / 2, z, 1.0, 1.6, "-y")
        for j in range(3):
            yy = (j - 1) * (D / 3)
            window(W / 2, yy, z, 1.0, 1.6, "+x")
            window(-W / 2, yy, z, 1.0, 1.6, "-x")
    # 底层：店面窗 + 门 + 台阶
    door(0, D / 2, 0, 1.4, 2.5)
    box(2.6, 1.2, 0.3, 0, D / 2 + 0.6, 0, "stone", 0.03)
    for sx in (-1, 1):
        window(sx * W * 0.3, D / 2, 0.8, 1.7, 1.6, "+y")
    if variant == 1:
        r = 2.3
        cyl(r, H + 1.0, W / 2 - r * 0.6, D / 2 - r * 0.6, 0, "A", 14)
        cyl(r * 1.15, 4.2, W / 2 - r * 0.6, D / 2 - r * 0.6, H + 1.0, "B", 14, r2=0.0)
        cyl(0.12, 0.6, W / 2 - r * 0.6, D / 2 - r * 0.6, H + 5.2, "gold", 6)
        for k in range(3):
            window(W / 2 - r * 0.6 + r * 0.92 * math.sin(0.5), D / 2 - r * 0.6 + r * 0.92 * math.cos(0.5), 4.4 + k * 3.4, 0.7, 1.3, "+y")
    elif variant == 2:
        for sx in (-1, 1):
            box(2.6, 1.0, H - 4.0, sx * W * 0.27, D / 2 + 0.45, 3.4, "A", 0.03)
            box(2.8, 1.2, 0.25, sx * W * 0.27, D / 2 + 0.5, H - 0.6, "C", 0.02)
            for f in range(1, floors):
                z = f * 3.4 + 0.8
                if z < H - 1.4:
                    window(sx * W * 0.27, D / 2 + 0.96, z, 1.7, 1.6, "+y")
    elif variant == 3:
        for sx in (-1, 1):
            gable(W * 0.45, 1.2, H + 0.2, 2.4, "A", 0.0, "y")
            PARTS[-1].location.x = sx * W * 0.25
            PARTS[-1].location.y = D / 2 - 0.4
            window(sx * W * 0.25, D / 2 + 0.25, H + 0.6, 0.8, 1.0, "+y", arched=True)
    export("rowhouse_%d" % variant, [W, H, D])


def build_house(variant):
    W, D, H = 8.5, 8.0, 5.5
    box(W + 0.4, D + 0.4, 2.8, 0, 0, -2.5, "stone", 0.05)
    box(W, D, H, 0, 0, 0, "A", 0.03)
    # 木筋
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(0.3, 0.3, H, sx * (W / 2 - 0.1), sy * (D / 2 - 0.1), 0, "C", 0.02)
    for zz in (H * 0.5, H - 0.15):
        box(W + 0.12, D + 0.12, 0.26, 0, 0, zz, "C", 0.02)
    if variant != 1:
        for sy in (-1, 1):
            for k in (-1, 1):
                box(0.2, 0.12, H * 0.55, k * W * 0.27, sy * (D / 2 + 0.03), H * 0.5, "C", 0.0, rot=(0, k * 0.6, 0))
    if variant == 2:
        box(W + 0.8, D + 0.8, 0.3, 0, 0, H * 0.5, "C", 0.02)
    rh = min(W, D) * 0.6
    if variant == 1:
        gable(W, D, H - 0.1, rh + 0.3, "thatch", 0.8, "x")
        cyl(0.5, W + 1.8, 0, 0, 0, "thatch", 10, rot=(0, math.pi / 2, 0))
        PARTS[-1].location = (0, 0, H + rh + 0.05)
    else:
        gable(W, D, H, rh, "B", 0.55, "x")
    box(0.9, 0.9, rh + 1.4, W * 0.28, -D * 0.2, H, "stone_dark", 0.04)
    door(0, D / 2, 0, 1.3, 2.2)
    box(2.0, 1.0, 0.3, 0, D / 2 + 0.6, 0, "stone", 0.03)
    for sx in (-1, 1):
        window(sx * W * 0.3, D / 2, 1.2, 0.9, 1.0, "+y")
        window(sx * W * 0.3, D / 2, H * 0.62, 0.8, 0.8, "+y")
        window(sx * W * 0.3, -D / 2, 1.3, 0.9, 1.0, "-y")
        window(sx * (W / 2), 0, 1.3, 0.9, 1.0, "+x" if sx > 0 else "-x")
        box(1.1, 0.35, 0.25, sx * W * 0.3, D / 2 + 0.25, 1.0, "wood_dark", 0.02)
        for k in range(3):
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.15, location=(sx * W * 0.3 + (k - 1) * 0.3, D / 2 + 0.25, 1.32))
            _finish(bpy.context.active_object, ["flower_r", "flower_y", "cloth"][k])
    export("house_%d" % variant, [W, H, D])


def build_tower():
    R, H = 4.5, 16.0
    cyl(R * 1.08, 4.0, 0, 0, -3.0, "stone_dark", 16)
    cyl(R, H, 0, 0, 0, "A", 16, r2=R * 0.95)
    cyl(R * 1.15, 0.6, 0, 0, H, "C", 16)
    for i in range(12):
        a = i * math.tau / 12
        if i % 2 == 0:
            box(1.0, 0.7, 0.9, math.cos(a) * R * 1.05, math.sin(a) * R * 1.05, H + 0.6, "A", 0.03, rot=(0, 0, a))
    cyl(R * 1.25, R * 2.0, 0, 0, H + 0.6, "B", 16, r2=0.0)
    cyl(0.12, 1.2, 0, 0, H + 0.6 + R * 2.0, "gold", 6)
    for i in range(4):
        a = i * math.tau / 4 + 0.4
        for zz in (H * 0.45, H * 0.75):
            bpy.ops.mesh.primitive_cube_add(size=1.0, location=(math.cos(a) * (R - 0.02), math.sin(a) * (R - 0.02), zz), rotation=(0, 0, a))
            o = bpy.context.active_object
            o.scale = (0.2, 0.7, 1.3)
            _finish(o, "glass")
    door(0, R - 0.1, 0, 1.4, 2.4)
    export("tower_0", [R * 2, H, R * 2])


def build_wall():
    L, H, T = 4.0, 9.0, 3.0
    box(L, T, H + 3.0, 0, 0, -3.0, "A", 0.02)
    box(L, T + 0.6, 0.4, 0, 0, H - 0.4, "C", 0.02)
    for sy in (-1, 1):
        for k in (-1, 1):
            box(1.0, 0.6, 1.0, k * L * 0.25, sy * (T / 2 - 0.3), H, "A", 0.03)
    box(L, 0.1, 0.5, 0, T / 2 + 0.02, 1.0, "stone_dark", 0.0)
    export("wall_0", [L, H, T])


# ======================================================================== props


def build_crate():
    box(1.0, 1.0, 1.0, 0, 0, 0, "C", 0.04)
    for z in (0.04, 0.88):
        box(1.04, 1.04, 0.1, 0, 0, z, "wood_dark", 0.01)
    box(0.1, 1.04, 1.25, 0, 0, -0.12, "wood_dark", 0.0, rot=(0, math.radians(45), 0))
    PARTS[-1].location.z = 0.5
    export("crate_0", [1.0, 1.0, 1.0])


def build_barrel():
    cyl(0.46, 1.3, 0, 0, 0, "C", 14)
    cyl(0.5, 0.8, 0, 0, 0.25, "C", 14)
    for z in (0.12, 0.6, 1.08):
        cyl(0.52, 0.08, 0, 0, z, "metal", 14)
    cyl(0.4, 0.02, 0, 0, 1.3, "wood_dark", 14)
    export("barrel_0", [1.0, 1.3, 1.0])


def build_cart():
    box(1.8, 2.8, 0.15, 0, 0, 0.75, "C", 0.03)
    for sx in (-1, 1):
        box(0.12, 2.8, 0.5, sx * 0.85, 0, 0.9, "C", 0.02)
    for sy in (-1, 1):
        box(1.8, 0.12, 0.5, 0, sy * 1.35, 0.9, "C", 0.02)
    for sx in (-1, 1):
        cyl(0.6, 0.12, sx * 1.0, 0.4, 0.0, "wood_dark", 14, rot=(0, math.pi / 2, 0))
        PARTS[-1].location = (sx * 1.0 - sx * 0.06, 0.4, 0.6)
        cyl(0.12, 0.16, sx * 1.0, 0.4, 0.0, "metal", 8, rot=(0, math.pi / 2, 0))
        PARTS[-1].location = (sx * 1.0 - sx * 0.08, 0.4, 0.6)
        box(0.1, 2.2, 0.1, sx * 0.4, -2.3, 0.75, "C", 0.01)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=10, ring_count=6, radius=0.75, location=(0, 0.1, 1.2))
    o = bpy.context.active_object
    o.scale = (1.0, 1.5, 0.5)
    _finish(o, "thatch")
    export("cart_0", [1.8, 1.0, 2.8])


def build_bench():
    for k in range(3):
        box(2.4, 0.14, 0.06, 0, -0.18 + k * 0.17, 0.48, "C", 0.01)
    for k in range(2):
        box(2.4, 0.06, 0.12, 0, 0.26, 0.65 + k * 0.18, "C", 0.01)
    for sx in (-1, 1):
        box(0.08, 0.5, 0.48, sx * 1.05, 0, 0, "metal", 0.0)
        box(0.08, 0.06, 0.45, sx * 1.05, 0.26, 0.48, "metal", 0.0)
    export("bench_0", [2.4, 1.0, 0.6])


def build_well():
    cyl(1.15, 0.9, 0, 0, 0, "stone", 14, bevel=0.03)
    cyl(0.9, 0.92, 0, 0, 0.01, "glass", 14)
    cyl(1.22, 0.12, 0, 0, 0.9, "stone_dark", 14)
    for sx in (-1, 1):
        box(0.16, 0.16, 2.4, sx * 0.95, 0, 0.9, "C", 0.02)
    cyl(0.07, 2.0, -1.0, 0, 2.6, "C", 8, rot=(0, math.pi / 2, 0))
    PARTS[-1].location = (0, 0, 2.6)
    gable(2.4, 1.6, 3.0, 0.8, "B", 0.15, "x")
    cyl(0.18, 0.3, 0, 0, 1.6, "C", 8)
    export("well_0", [2.0, 2.0, 2.0])


def build_stall():
    W, D = 4.0, 3.0
    box(W, D * 0.5, 1.0, 0, D * 0.2, 0, "C", 0.03)
    box(W + 0.1, D * 0.5 + 0.1, 0.08, 0, D * 0.2, 1.0, "wood_dark", 0.01)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(0.12, 0.12, 2.7, sx * W * 0.47, sy * D * 0.45, 0, "C", 0.01)
    n = 6
    for i in range(n):
        box(W / n, D * 1.15, 0.07, -W / 2 + (i + 0.5) * W / n, 0, 2.62, "B" if i % 2 == 0 else "cloth", 0.0, rot=(math.radians(12), 0, 0))
    goods = ["flower_r", "flower_y", "plant", "red"]
    for i in range(5):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.17, location=(-W * 0.36 + i * W * 0.18, D * 0.3, 1.2))
        _finish(bpy.context.active_object, goods[i % 4])
        box(0.5, 0.4, 0.2, -W * 0.36 + i * W * 0.18, D * 0.05, 1.0, "wood_dark", 0.01)
    export("stall_0", [W, 3.0, D])


def build_tent():
    W, H, D = 4.0, 2.6, 4.0
    v = [(-W / 2, -D / 2, 0), (W / 2, -D / 2, 0), (W / 2, D / 2, 0), (-W / 2, D / 2, 0), (0, -D / 2, H), (0, D / 2, H)]
    f = [(1, 2, 5, 4), (3, 0, 4, 5), (0, 1, 4), (2, 3, 5)]
    o = mesh_obj(v, f, "B")
    o.modifiers.new("s", "SOLIDIFY").thickness = 0.05
    box(W * 0.36, 0.06, H * 0.6, 0, D / 2 + 0.02, 0, "wood_dark", 0.0)
    for sy in (-1, 1):
        cyl(0.05, H + 0.3, 0, sy * (D / 2 + 0.05), 0, "C", 6)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(0.04, 0.4, sx * (W / 2 + 0.3), sy * (D / 2 + 0.3), 0, "C", 6)
    export("tent_0", [W, H, D])


def build_fence():
    L = 2.0
    for sx in (-1, 1):
        box(0.15, 0.15, 1.1, sx * L / 2, 0, 0, "C", 0.02)
        cyl(0.1, 0.15, sx * L / 2, 0, 1.1, "C", 4, r2=0.0)
    for z in (0.42, 0.78):
        box(L, 0.08, 0.12, 0, 0, z, "C", 0.01)
    export("fence_0", [L, 1.1, 0.2])


def build_lamp():
    # 维多利亚式铸铁街灯：材质 "lamp" 在游戏里换成夜间发光的灯罩材质，并附带点光源
    cyl(0.22, 0.35, 0, 0, 0, "metal", 8)
    cyl(0.08, 4.0, 0, 0, 0.35, "metal", 8, r2=0.06)
    box(0.7, 0.06, 0.06, 0.25, 0, 4.25, "metal", 0.0)
    cyl(0.1, 0.12, 0.55, 0, 4.18, "metal", 6)
    cyl(0.16, 0.5, 0.55, 0, 3.6, "lamp", 6, r2=0.24)
    cyl(0.3, 0.25, 0.55, 0, 4.1, "metal", 6, r2=0.0)
    export("lamp_0", [1.0, 4.5, 1.0])


def build_tree(v):
    random.seed(40 + v)
    if v == 0:
        cyl(0.22, 3.4, 0, 0, 0, "C", 7, r2=0.14)
        for (x, y, z, r) in [(0, 0, 4.6, 1.9), (0.9, 0.3, 4.0, 1.3), (-0.8, -0.4, 3.9, 1.2), (0.1, -0.6, 5.6, 1.1)]:
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=r, location=(x, y, z))
            o = bpy.context.active_object
            o.scale = (1.0, 1.0, 0.85)
            _finish(o, "B")
    elif v == 1:
        cyl(0.18, 2.0, 0, 0, 0, "C", 6)
        for i in range(4):
            cyl(1.9 - i * 0.4, 2.0, 0, 0, 1.4 + i * 1.15, "B", 9, r2=0.0)
    elif v == 2:
        for i in range(6):
            cyl(0.16 - i * 0.012, 1.1, 0.12 * i, 0, i * 1.0, "C", 6, rot=(0, math.radians(6 + i * 2), 0))
        for i in range(7):
            a = i * math.tau / 7
            box(0.5, 2.4, 0.05, 0.75 + math.cos(a) * 0.9, math.sin(a) * 0.9, 5.7, "B", 0.0, rot=(math.radians(25), 0, a + math.pi / 2))
    elif v == 3:
        cyl(0.13, 4.5, 0, 0, 0, "cloth", 6, r2=0.09)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=1.5, location=(0, 0, 4.8))
        o = bpy.context.active_object
        o.scale = (0.85, 0.85, 1.3)
        _finish(o, "B")
    else:
        cyl(0.22, 4.2, 0, 0, 0, "wood_dark", 6, r2=0.08)
        for i in range(4):
            a = i * math.tau / 4 + 0.3
            cyl(0.06, 1.6, math.cos(a) * 0.3, math.sin(a) * 0.3, 2.6 + i * 0.3, "wood_dark", 5, r2=0.02,
                rot=(math.sin(a) * 0.8, -math.cos(a) * 0.8, 0))
    export("tree_%d" % v, [4.0, 6.0, 4.0])


def build_haystack():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=7, radius=1.0, location=(0, 0, 0.55))
    o = bpy.context.active_object
    o.scale = (1.0, 1.0, 0.75)
    _finish(o, "thatch")
    cyl(1.02, 0.12, 0, 0, 0.55, "wood_dark", 12)
    export("haystack_0", [2.0, 1.6, 2.0])


def build_banner():
    cyl(0.06, 6.0, 0, 0, 0, "wood_dark", 6)
    box(1.0, 0.05, 0.05, 0, 0, 5.85, "wood_dark", 0.0)
    box(0.9, 0.04, 2.4, 0, 0.02, 3.4, "B", 0.0)
    v = [(-0.45, 0.04, 3.4), (0.45, 0.04, 3.4), (0, 0.04, 2.9)]
    mesh_obj(v, [(0, 1, 2)], "B")
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.2, location=(0, 0.06, 4.7))
    _finish(bpy.context.active_object, "C")
    export("banner_0", [1.0, 6.0, 1.0])


def build_guildhouse():
    W, D, H = 22.0, 18.0, 13.0
    box(W + 0.4, D + 0.4, 2.6, 0, 0, -2.3, "stone_dark", 0.05)
    box(W, D, H * 0.35, 0, 0, 0, "stone", 0.04)
    box(W - 0.2, D - 0.2, H * 0.65, 0, 0, H * 0.35, "A", 0.03)
    box(W + 0.3, D + 0.3, 0.3, 0, 0, H * 0.35, "C", 0.02)
    gable(W, D, H, W * 0.28, "B", 0.5, "x")
    # 中央山墙立面（前 +Y）
    box(W * 0.4, 1.2, H * 1.15, 0, D / 2 + 0.6, 0, "A", 0.03)
    v0 = [(-W * 0.22, D / 2, H * 1.15), (W * 0.22, D / 2, H * 1.15), (0, D / 2, H * 1.15 + W * 0.18),
          (-W * 0.22, D / 2 + 1.3, H * 1.15), (W * 0.22, D / 2 + 1.3, H * 1.15), (0, D / 2 + 1.3, H * 1.15 + W * 0.18)]
    mesh_obj(v0, [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], "B")
    cyl(1.9, 0.3, 0, D / 2 + 1.25, 0, "C", 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, D / 2 + 1.35, H * 0.9)
    cyl(2.15, 0.25, 0, 0, 0, "gold", 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, D / 2 + 1.3, H * 0.9)
    door(0, D / 2 + 1.2, 0, 2.4, 3.6)
    for i in range(6):
        x = -W / 2 + 1.8 + i * (W - 3.6) / 5
        if abs(x) > W * 0.21:
            window(x, D / 2, H * 0.12, 1.2, 1.4, "+y")
            window(x, D / 2, H * 0.5, 1.1, 1.9, "+y", arched=True)
        window(x, -D / 2, H * 0.5, 1.1, 1.9, "-y", arched=True)
    for j in range(4):
        yy = -D / 2 + 2.2 + j * (D - 4.4) / 3
        window(W / 2, yy, H * 0.5, 1.1, 1.9, "+x")
        window(-W / 2, yy, H * 0.5, 1.1, 1.9, "-x")
    for sx in (-1, 1):
        box(1.4, 0.06, H * 0.5, sx * W * 0.28, D / 2 + 0.05, H * 0.35, "C", 0.0)
    cyl(2.2, H * 1.3, -W / 2, D / 2, 0, "A", 12)
    cyl(2.8, W * 0.3, -W / 2, D / 2, H * 1.3, "B", 12, r2=0.0)
    cyl(0.12, 1.0, -W / 2, D / 2, H * 1.3 + W * 0.3, "gold", 6)
    export("guildhouse_0", [W, H, D])


def build_hall(v):
    # 大型公共建筑：v0 山墙顶 / v1 穹顶 / v2 四坡顶；前有四柱门廊
    W, D, H = 16.0, 14.0, 8.0
    box(W + 0.5, D + 0.5, 2.8, 0, 0, -2.5, "stone_dark", 0.05)
    box(W, D, H, 0, 0, 0, "A", 0.03)
    box(W + 0.5, D + 0.5, 0.6, 0, 0, H, "C", 0.03)
    if v == 0:
        gable(W, D, H + 0.6, W * 0.3, "B", 0.4, "x")
    elif v == 1:
        r = min(W, D) * 0.4
        cyl(r * 1.02, 1.2, 0, 0, H + 0.6, "A", 20)
        bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=r, location=(0, 0, H + 1.8))
        o = bpy.context.active_object
        bm = bmesh.new(); bm.from_mesh(o.data)
        bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if vv.co.z < -0.01], context="VERTS")
        bm.to_mesh(o.data); bm.free()
        _finish(o, "B")
        cyl(0.35, 1.6, 0, 0, H + 1.8 + r, "gold", 8, r2=0.1)
    else:
        frustum(W + 1.2, D + 1.2, W * 0.35, D * 0.2, H + 0.6, H * 0.45, "B")
    for i in range(4):
        x = (i - 1.5) * W * 0.2
        cyl(0.42, H * 0.85, x, D / 2 + 0.7, 0, "C" if v == 2 else "A", 12)
        box(0.9, 0.9, 0.3, x, D / 2 + 0.7, 0, "stone", 0.02)
    box(W * 0.75, 1.8, 0.5, 0, D / 2 + 0.7, H * 0.85, "A", 0.03)
    box(W * 0.8, 2.4, 0.4, 0, D / 2 + 0.6, -0.2, "stone", 0.03)
    door(0, D / 2, 0, 2.4, 3.4)
    for i in range(5):
        x = -W / 2 + 1.6 + i * (W - 3.2) / 4
        if abs(x) > 2.4:
            window(x, D / 2, H * 0.32, 1.1, 2.2, "+y", arched=True)
        window(x, -D / 2, H * 0.32, 1.1, 2.2, "-y", arched=True)
    for j in range(4):
        yy = -D / 2 + 1.8 + j * (D - 3.6) / 3
        window(W / 2, yy, H * 0.32, 1.1, 2.2, "+x", arched=True)
        window(-W / 2, yy, H * 0.32, 1.1, 2.2, "-x", arched=True)
    export("hall_%d" % v, [W, H, D])


def build_church():
    W, D, H = 16.0, 30.0, 12.0
    box(W + 0.5, D + 0.5, 2.8, 0, 0, -2.5, "stone_dark", 0.05)
    box(W, D, H, 0, 0, 0, "A", 0.03)
    gable(W, D, H, W * 0.6, "B", 0.5, "y")
    for i in range(int(D / 4)):
        yy = -D / 2 + 2.5 + i * 4.0
        for sx in (-1, 1):
            box(1.0, 1.0, H * 0.8, sx * (W / 2 + 0.4), yy + 1.5, 0, "A", 0.03)
            window(sx * W / 2, yy, H * 0.3, 1.2, H * 0.45, "+x" if sx > 0 else "-x", arched=True)
    tw = W * 0.42
    th = H * 2.1
    ty = D / 2 + tw * 0.3
    box(tw, tw, th, 0, ty, 0, "A", 0.03)
    cyl(tw * 0.8, tw * 1.6, 0, ty, th, "B", 4, r2=0.0, rot=(0, 0, math.pi / 4))
    cyl(0.08, 2.0, 0, ty, th + tw * 1.6, "gold", 6)
    box(1.2, 0.15, 0.15, 0, ty, th + tw * 1.6 + 1.2, "gold", 0.0)
    cyl(tw * 0.32, 0.2, 0, 0, 0, "glass", 16, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, ty + tw / 2 + 0.06, th * 0.6)
    cyl(tw * 0.36, 0.2, 0, 0, 0, "C", 16, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, ty + tw / 2 + 0.02, th * 0.6)
    box(tw * 0.6, 0.2, tw * 0.7, 0, ty + tw / 2 + 0.05, th - tw * 0.95, "metal", 0.0)
    door(0, ty + tw / 2, 0, 2.2, 3.6)
    export("church_0", [W, H, D])


def build_pier():
    W, L, Hd = 3.0, 12.0, 1.4
    box(W, L, 0.35, 0, 0, Hd - 0.35, "C", 0.02)
    for i in range(int(L / 0.8)):
        box(W, 0.05, 0.04, 0, -L / 2 + 0.4 + i * 0.8, Hd, "wood_dark", 0.0)
    for i in range(int(L / 3) + 1):
        for sx in (-1, 1):
            cyl(0.18, Hd + 4.0, sx * (W / 2 - 0.2), -L / 2 + i * L / int(L / 3), -4.0, "wood_dark", 8)
    for sx in (-1, 1):
        cyl(0.12, 0.9, sx * (W / 2 - 0.2), L / 2 - 0.3, Hd, "wood_dark", 8)
    export("pier_0", [W, Hd, L])


def build_bridge():
    W, L, Hd = 10.0, 22.0, 8.0
    box(W, L, 0.6, 0, 0, Hd, "A", 0.03)
    for sx in (-1, 1):
        box(0.5, L, 1.0, sx * (W / 2 - 0.25), 0, Hd + 0.6, "C", 0.03)
        for k in range(int(L / 2.2)):
            box(0.3, 0.3, 0.9, sx * (W / 2 - 0.25), -L / 2 + 1.1 + k * 2.2, Hd + 0.6, "C", 0.02)
    # 拱：两侧拱墙 + 拱顶
    for sy in (-1, 1):
        box(W, 2.0, Hd + 4.0, 0, sy * (L / 2 - 1.0), -4.0, "A", 0.03)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=Hd * 0.85, depth=W, location=(0, 0, 0), rotation=(0, math.pi / 2, 0))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if vv.co.x > 0.01], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    o.scale = (1.0, (L / 2 - 2.0) / (Hd * 0.85), 1.0)
    sol = o.modifiers.new("s", "SOLIDIFY")
    sol.thickness = -0.8
    _finish(o, "stone")
    box(W, L - 4.0, 0.6, 0, 0, Hd - 0.6, "A", 0.0)
    export("bridge_0", [W, Hd, L])


BUILDERS = {
    "rowhouse_0": lambda: build_rowhouse(0), "rowhouse_1": lambda: build_rowhouse(1), "rowhouse_2": lambda: build_rowhouse(2),
    "rowhouse_3": lambda: build_rowhouse(3), "house_0": lambda: build_house(0), "house_1": lambda: build_house(1),
    "house_2": lambda: build_house(2), "tower_0": build_tower, "wall_0": build_wall, "crate_0": build_crate,
    "barrel_0": build_barrel, "cart_0": build_cart, "bench_0": build_bench, "well_0": build_well, "stall_0": build_stall,
    "tent_0": build_tent, "fence_0": build_fence, "lamp_0": build_lamp, "haystack_0": build_haystack, "banner_0": build_banner,
    "guildhouse_0": build_guildhouse,
    "tree_0": lambda: build_tree(0), "tree_1": lambda: build_tree(1), "tree_2": lambda: build_tree(2),
    "tree_3": lambda: build_tree(3), "tree_4": lambda: build_tree(4),
    "hall_0": lambda: build_hall(0), "hall_1": lambda: build_hall(1), "hall_2": lambda: build_hall(2),
    "church_0": build_church, "pier_0": build_pier, "bridge_0": build_bridge,
}

def run_builders(builders):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    meta_path = os.path.join(OUT, "models.json")
    if os.path.exists(meta_path):
        with open(meta_path, "r", encoding="utf-8") as fh:
            NOMINAL.update(json.load(fh))
    for name, fn in builders.items():
        if ONLY and name not in ONLY:
            continue
        fn()
    with open(meta_path, "w", encoding="utf-8") as fh:
        json.dump(NOMINAL, fh, indent=1, sort_keys=True)
    print("MODELS DONE", len(NOMINAL))


# 其它批次脚本（build_props.py 等）先设置 _LIB_ONLY = True 再 exec 本文件，只取用上面的工具函数
if not globals().get("_LIB_ONLY", False):
    run_builders(BUILDERS)
