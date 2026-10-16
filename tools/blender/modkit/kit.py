# 晨露谷建筑构件库（拆分方式参考 SUNTAIL：2m×3m 栅格 → 本项目放大 1.2 倍为 2.4m × 3.6m）。
# 每个构件只用“十手法”建模，并在对象自定义属性 methods 中登记：
#   mirror 镜像 | array 阵列 | profile_extrude 轮廓/分层挤出 | solidify 实体化 | curve_bevel 曲线倒角
#   screw 旋绕 | curve_deform 曲线变形 | bridge 桥接/放样 | simple_deform 简单形变 | vertex 几何顶点
# 约定：Blender 米制 +Z 向上；墙构件沿 +X 展开 0..U，外立面朝 -Y，墙体中心线 y=0；材质名 K|mtype|RRGGBB|贴图|米（见 src/core/util.gd kit_mat）。
import bpy, bmesh, math, random, os
from mathutils import Vector, Matrix
TEXDIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "textures", "building"))

U = 2.4          # 模数宽
H = 3.6          # 层高
T = 0.30         # 墙厚
BASE = 0.6       # 勒脚 / 室内地坪高

PAL = {
    "plaster": "K|0|efe6d2|st_plaster|3.0",
    "timber": "K|6|5a3d2b|st_wood|2.0",
    "ashlar": "K|2|dcd7ca|st_masonry|4.0",
    "rubble": "K|2|a59d8f|st_cobble|2.6",
    "trim": "K|9|e4ddcc||0",
    "slate": "K|3|4a5f86|st_roof_scale|2.4",
    "terracotta": "K|4|a5463a|st_roof_barrel|2.0",
    "door": "K|6|6b4630|st_boards|1.6",
    "floor": "K|6|8a6440|st_boards|2.0",
    "iron": "K|7|2b2f36||0",
    "glass": "K|glass|a9c8d8||0",
    "plant": "K|8|4f8a3c||0",
    "flower": "K|8|e07a9a||0",
}

def mat(key):
    name = PAL.get(key, key)
    m = bpy.data.materials.get(name)
    if m is None:
        m = bpy.data.materials.new(name)
        f = name.split("|")
        try:
            c = tuple(int(f[2][i:i + 2], 16) / 255 for i in (0, 2, 4))
            m.diffuse_color = (*c, 0.5 if f[1] == "glass" else 1.0)
            m.use_nodes = True
            bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            bsdf.inputs["Base Color"].default_value = (*[x ** 2.2 for x in c], 1)
            if f[1] == "glass":
                bsdf.inputs["Alpha"].default_value = 0.5
            if f[1] == "glow":
                bsdf.inputs["Emission Color"].default_value = (*c, 1); bsdf.inputs["Emission Strength"].default_value = 3.0
            tex = os.path.join(TEXDIR, f[3] + ".png") if len(f) > 4 and f[3] else ""
            if tex and os.path.exists(tex):
                # 仅用于 Blender 预览：与游戏端 building.gdshader 相同的灰度细节贴图 × 底色（盒状投影）
                nt = m.node_tree
                tc = nt.nodes.new("ShaderNodeTexCoord"); mp = nt.nodes.new("ShaderNodeMapping")
                s = 1.0 / max(float(f[4]), 0.1); mp.inputs["Scale"].default_value = (s, s, s)
                im = nt.nodes.new("ShaderNodeTexImage"); im.image = bpy.data.images.load(tex, check_existing=True)
                im.projection = "BOX"; im.projection_blend = 0.25
                mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"; mix.inputs["Factor"].default_value = 1.0
                mix.inputs[6].default_value = (*[x ** 2.2 * 2.0 for x in c], 1)
                nt.links.new(tc.outputs["Object"], mp.inputs["Vector"]); nt.links.new(mp.outputs["Vector"], im.inputs["Vector"])
                nt.links.new(im.outputs["Color"], mix.inputs[7]); nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
        except Exception:
            pass
    return m

COL = None
def _link(ob):
    (COL or bpy.context.scene.collection).objects.link(ob)
    return ob

def new_obj(name, me, methods=()):
    ob = _link(bpy.data.objects.new(name, me))
    ob["methods"] = ",".join(methods)
    return ob

def bm_obj(name, bm, mkey, methods=()):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    me.materials.append(mat(mkey))
    return new_obj(name, me, methods)

def apply_mods(ob):
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    if old.users == 0 and isinstance(old, bpy.types.Mesh):
        bpy.data.meshes.remove(old)
    return ob

def to_mesh_obj(ob, mkey, methods):
    """Curve / evaluated object -> plain mesh object (keeps methods)."""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    me.materials.clear(); me.materials.append(mat(mkey))
    n = new_obj(ob.name + "_m", me, methods)
    n.matrix_world = ob.matrix_world.copy()
    data = ob.data
    bpy.data.objects.remove(ob)
    if isinstance(data, bpy.types.Curve) and data.users == 0:
        bpy.data.curves.remove(data)
    return n

def join(objs, name):
    objs = [o for o in objs if o is not None]
    bpy.context.view_layer.update()
    methods = set()
    for o in objs:
        methods.update(x for x in o.get("methods", "").split(",") if x)
    base = objs[0]
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    mats = []
    for o in objs:
        tmp = o.data.copy()
        tmp.transform(o.matrix_world)
        remap = []
        for m in tmp.materials:
            if m not in mats:
                mats.append(m)
            remap.append(mats.index(m))
        for p in tmp.polygons:
            p.material_index = remap[p.material_index] if remap else 0
        bm.from_mesh(tmp)
        bpy.data.meshes.remove(tmp)
    bm.to_mesh(me); bm.free()
    for m in mats:
        me.materials.append(m)
    for o in objs:
        d = o.data
        bpy.data.objects.remove(o)
        if d.users == 0:
            bpy.data.meshes.remove(d)
    ob = new_obj(name, me, sorted(methods))
    return ob

# ------------------------------------------------------------------ 基础形体（全部由十手法组成）
def profile_extrude(name, prof, length, mkey, axis="x", methods=("profile_extrude",)):
    """2D 截面（u,v）沿轴挤出：axis=x 时截面在 YZ 平面。"""
    bm = bmesh.new()
    def P(u, v, t):
        return {"x": (t, u, v), "y": (u, t, v), "z": (u, v, t)}[axis]
    a = [bm.verts.new(P(u, v, 0)) for u, v in prof]
    b = [bm.verts.new(P(u, v, length)) for u, v in prof]
    n = len(prof)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(a))); bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm_obj(name, bm, mkey, methods)

def box(name, sx, sy, sz, loc, mkey, methods=("profile_extrude",)):
    ob = profile_extrude(name, [(-sy / 2, 0), (sy / 2, 0), (sy / 2, sz), (-sy / 2, sz)], sx, mkey, "x", methods)
    ob.location = (loc[0] - sx / 2, loc[1], loc[2])
    return ob

def ray_poly(c, ang, poly):
    d = Vector((math.cos(ang), math.sin(ang)))
    best = None
    for i in range(len(poly)):
        p, q = Vector(poly[i]), Vector(poly[(i + 1) % len(poly)])
        e = q - p
        den = d.x * e.y - d.y * e.x
        if abs(den) < 1e-9:
            continue
        w = p - c
        t = (w.x * e.y - w.y * e.x) / den
        s = (w.x * d.y - w.y * d.x) / den
        if t > 0 and -1e-6 <= s <= 1 + 1e-6 and (best is None or t < best):
            best = t
    return c + d * (best or 0)

def opening_poly(kind, cx, z0, w, h, seg=12):
    if kind == "arch":
        r = w / 2
        pts = [(cx - r, z0), (cx + r, z0), (cx + r, z0 + h - r)]
        for i in range(1, seg):
            a = math.pi * i / seg
            pts.append((cx + r * math.cos(a), z0 + h - r + r * math.sin(a)))
        pts.append((cx - r, z0 + h - r))
        return pts
    return [(cx - w / 2, z0), (cx + w / 2, z0), (cx + w / 2, z0 + h), (cx - w / 2, z0 + h)]

def panel(name, w, h, mkey, hole=None, thick=T, n=48):
    """墙板：外框与洞口轮廓按同一角度参数采样后桥接（bridge），再实体化（solidify）。hole=(kind,cx,z0,w,h)。"""
    bm = bmesh.new()
    outer = [(0, 0), (w, 0), (w, h), (0, h)]
    if hole is None:
        vs = [bm.verts.new((x, 0, z)) for x, z in outer]
        bm.faces.new(vs)
        methods = ("solidify",)
    else:
        poly = opening_poly(*hole)
        c = Vector((hole[1], hole[2] + hole[4] * 0.45))
        o = [bm.verts.new((p.x, 0, p.y)) for p in (ray_poly(c, 2 * math.pi * i / n, outer) for i in range(n))]
        ii = [bm.verts.new((p.x, 0, p.y)) for p in (ray_poly(c, 2 * math.pi * i / n, poly) for i in range(n))]
        e1 = [bm.edges.new((o[i], o[(i + 1) % n])) for i in range(n)]
        e2 = [bm.edges.new((ii[i], ii[(i + 1) % n])) for i in range(n)]
        bmesh.ops.bridge_loops(bm, edges=e1 + e2)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        methods = ("bridge", "solidify")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.y > 0:
            f.normal_flip()
    ob = bm_obj(name, bm, mkey, methods)
    m = ob.modifiers.new("solid", "SOLIDIFY"); m.thickness = thick; m.offset = 0; m.use_even_offset = True
    return apply_mods(ob)

def jitter(ob, amt, seed=1, axis_mask=(1, 1, 1)):
    """几何顶点（vertex）：手工感的轻微错位。"""
    rnd = random.Random(seed)
    for v in ob.data.vertices:
        v.co += Vector((rnd.uniform(-amt, amt) * axis_mask[0], rnd.uniform(-amt, amt) * axis_mask[1], rnd.uniform(-amt, amt) * axis_mask[2]))
    tags = set(ob["methods"].split(",")) | {"vertex"}
    ob["methods"] = ",".join(sorted(t for t in tags if t))
    return ob

def array(ob, count, offset, methods_add=("array",)):
    m = ob.modifiers.new("arr", "ARRAY"); m.count = count
    m.use_relative_offset = False; m.use_constant_offset = True; m.constant_offset_displace = offset
    apply_mods(ob)
    ob["methods"] = ",".join(sorted(set(ob["methods"].split(",")) | set(methods_add) - {""}))
    return ob

def mirror(ob, axis=0, center=None):
    """镜像：以 center（世界坐标）为镜像面。"""
    if center is not None:
        e = bpy.data.objects.new("mc", None); _link(e); e.location = center
    m = ob.modifiers.new("mir", "MIRROR"); m.use_axis = [axis == 0, axis == 1, axis == 2]
    if center is not None:
        m.mirror_object = e
    apply_mods(ob)
    if center is not None:
        bpy.data.objects.remove(e)
    ob["methods"] = ",".join(sorted(set(ob["methods"].split(",")) | {"mirror"} - {""}))
    return ob

def curve_bevel(name, pts, depth, mkey, closed=False, square=False, methods=("curve_bevel",)):
    cu = bpy.data.curves.new(name, "CURVE"); cu.dimensions = "3D"
    sp = cu.splines.new("POLY"); sp.points.add(len(pts) - 1)
    for p, c in zip(sp.points, pts):
        p.co = (*c, 1)
    sp.use_cyclic_u = closed
    cu.bevel_depth = depth; cu.bevel_resolution = 0 if square else 2; cu.use_fill_caps = True
    ob = _link(bpy.data.objects.new(name, cu))
    return to_mesh_obj(ob, mkey, methods)

def screw(name, prof, mkey, steps=16, methods=("screw",)):
    """旋绕：XZ 平面截面（r,z）绕 Z 轴。"""
    bm = bmesh.new()
    vs = [bm.verts.new((r, 0, z)) for r, z in prof]
    for i in range(len(vs) - 1):
        bm.edges.new((vs[i], vs[i + 1]))
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free(); me.materials.append(mat(mkey))
    ob = new_obj(name, me, methods)
    m = ob.modifiers.new("scr", "SCREW"); m.steps = steps; m.render_steps = steps; m.use_merge_vertices = True; m.use_normal_calculate = True
    return apply_mods(ob)

def simple_bend(ob, angle_deg, axis="Y", origin=None):
    """简单形变（SIMPLE_DEFORM / BEND），origin 为世界坐标的弯曲中心。"""
    e = None
    m = ob.modifiers.new("sd", "SIMPLE_DEFORM"); m.deform_method = "BEND"; m.angle = math.radians(angle_deg); m.deform_axis = axis
    if origin is not None:
        e = _link(bpy.data.objects.new("sdo", None)); e.location = origin; m.origin = e
    apply_mods(ob)
    if e is not None:
        bpy.data.objects.remove(e)
    ob["methods"] = ",".join(sorted(set(ob["methods"].split(",")) | {"simple_deform"} - {""}))
    return ob

def curve_deform(ob, pts, axis="POS_X"):
    cu = bpy.data.curves.new("cd", "CURVE"); cu.dimensions = "3D"
    sp = cu.splines.new("POLY"); sp.points.add(len(pts) - 1)
    for p, c in zip(sp.points, pts):
        p.co = (*c, 1)
    co = _link(bpy.data.objects.new("cd", cu))
    m = ob.modifiers.new("cdm", "CURVE"); m.object = co; m.deform_axis = axis
    apply_mods(ob)
    bpy.data.objects.remove(co); bpy.data.curves.remove(cu)
    ob["methods"] = ",".join(sorted(set(ob["methods"].split(",")) | {"curve_deform"} - {""}))
    return ob

# ------------------------------------------------------------------ 构件（对应 SUNTAIL 分组）
# Stone Modules ----------------------------------------------------
def stone_base(w=U, h=BASE, out=0.12, seed=1):
    """勒脚：带斜压顶的截面挤出 + 顶点错位。"""
    prof = [(-T / 2 - out, 0), (T / 2, 0), (T / 2, h), (-T / 2 - out * 0.3, h), (-T / 2 - out, h - 0.12)]
    ob = profile_extrude("stone_base", prof, w, "rubble")
    return jitter(ob, 0.015, seed, (0.3, 1, 0.4))

def wall_stone(variant="solid", w=U, h=H, opening=None):
    hole = None
    if variant == "door":
        hole = opening or ("arch", w / 2, 0, 1.5, 2.8)
    elif variant == "window":
        hole = opening or ("arch", w / 2, 1.0, 1.0, 1.7)
    parts = [panel("ashlar", w, h, "ashlar", hole)]
    # 隅石/墙缘线脚：块石阵列 + 错位
    return join(parts, "wall_stone_" + variant)

def quoin(h=H, seed=3):
    """转角隅石：长短交替的块石（阵列 + 顶点错位）。"""
    a = box("q1", 0.55, 0.55, 0.42, (0, 0, 0), "ashlar")
    b = box("q2", 0.42, 0.42, 0.42, (0, 0, 0.42), "ashlar")
    q = join([a, b], "quoin")
    n = max(1, int(h / 0.84))
    array(q, n, (0, 0, h / n))
    return jitter(q, 0.012, seed)

# Frame Modules ----------------------------------------------------
TB = 0.20   # 木筋截面
def _beam_x(x0, x1, z, y=-T / 2 - 0.02, s=TB, name="beam"):
    b = box(name, x1 - x0, s * 0.6, s, ((x0 + x1) / 2, y, z - s / 2), "timber")
    return b

def _beam_z(x, z0, z1, y=-T / 2 - 0.02, s=TB, name="post"):
    prof = [(y - s * 0.3, 0), (y + s * 0.3, 0), (y + s * 0.3, z1 - z0), (y - s * 0.3, z1 - z0)]
    ob = profile_extrude(name, [(p[0], p[1]) for p in prof], s, "timber", "x")
    ob.location = (x - s / 2, 0, z0)
    return ob

def _brace(x0, z0, x1, z1, y=-T / 2 - 0.02, s=TB * 0.8):
    d = math.hypot(x1 - x0, z1 - z0)
    ob = profile_extrude("brace", [(y - s * 0.3, -s / 2), (y + s * 0.3, -s / 2), (y + s * 0.3, s / 2), (y - s * 0.3, s / 2)], d, "timber", "x")
    ob.matrix_world = Matrix.Translation((x0, 0, z0)) @ Matrix.Rotation(math.atan2(z1 - z0, x1 - x0), 4, "Y").inverted()
    return ob

def wall_frame(variant="solid", w=U, h=H, skirting=True):
    """木筋墙板（SUNTAIL Frame_Wall_1/_D/_W）：灰泥板（桥接+实体化）+ 木筋（挤出、镜像斜撑）+ 下部护板（阵列）。"""
    hole = None
    if variant == "door":
        hole = ("rect", w / 2, 0, 1.4, 2.7)
    elif variant == "window":
        hole = ("rect", w / 2, 1.0, 1.2, 1.7)
    parts = [panel("plaster", w, h, "plaster", hole, T * 0.8)]
    parts += [_beam_x(0, w, TB, name="sill"), _beam_x(0, w, h, name="head"), _beam_z(TB / 2, 0, h), _beam_z(w - TB / 2, 0, h)]
    if variant == "solid":
        br = _brace(TB, TB, w / 2, h - TB)
        mirror(br, 0, (w / 2, 0, 0))
        parts += [br, _beam_x(TB, w - TB, h * 0.5, name="rail")]
    elif variant == "window":
        parts += [_beam_z(w / 2 - 0.71, TB, h - TB), _beam_z(w / 2 + 0.71, TB, h - TB)]
        br = _brace(TB, TB, w / 2 - 0.82, 0.92)
        mirror(br, 0, (w / 2, 0, 0)); parts.append(br)
    elif variant == "door":
        parts += [_beam_z(w / 2 - 0.8, TB, h - TB), _beam_z(w / 2 + 0.8, TB, h - TB), _beam_x(w / 2 - 0.8, w / 2 + 0.8, 2.85, name="lintel")]
    if skirting and variant != "door":
        bd = box("board", 0.22, 0.04, 0.7, (TB + 0.14, -T / 2 - 0.03, TB), "door")
        n = int((w - 2 * TB) / 0.24)
        array(bd, n, (0.24, 0, 0))
        parts.append(bd)
    return join(parts, "wall_frame_" + variant)

def gable(w, rise, frame=True, t=T * 0.8):
    """山墙三角（Gable）：三角板挤出（solidify）+ 中柱与斜撑（镜像）。原点在左下，宽 w。"""
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in [(0, 0, 0), (w, 0, 0), (w / 2, 0, rise)]]
    bm.faces.new(vs)
    ob = bm_obj("gable", bm, "plaster" if frame else "ashlar", ("solidify",))
    m = ob.modifiers.new("s", "SOLIDIFY"); m.thickness = t; m.offset = 0
    apply_mods(ob)
    parts = [ob]
    if frame:
        parts += [_beam_x(0, w, TB, name="tie"), _beam_z(w / 2, TB, rise - 0.1)]
        br = _brace(w / 2 - 0.15, rise * 0.35, w * 0.18, TB)
        mirror(br, 0, (w / 2, 0, 0)); parts.append(br)
        br2 = _brace(w / 2 - 0.12, rise * 0.75, w * 0.32, rise * 0.3)
        mirror(br2, 0, (w / 2, 0, 0)); parts.append(br2)
    return join(parts, "gable_frame" if frame else "gable_stone")

# Doors And Windows ------------------------------------------------
def window(kind="rect", w=1.2, h=1.7, shutters=True, box_flowers=True):
    """窗：窗框（曲线倒角，沿洞口一圈）、通高竖棂 + 横棂（挤出 / 阵列）、玻璃（实体化）、窗台（挤出）、
    窗楣：方窗为挑檐线脚（挤出），拱窗为拱形滴水线（曲线倒角）+ 拱心石；百叶（阵列 + 镜像）、花箱（阵列 + 旋绕 + 顶点）。
    原点：窗洞底边中点，外墙面 y=-T/2。"""
    y = -T / 2
    poly = opening_poly(kind, 0, 0, w, h)
    frame = curve_bevel("wframe", [(x, y + 0.04, z) for x, z in poly], 0.075, "timber", closed=True, square=True)
    glass_bm = bmesh.new()
    vs = [glass_bm.verts.new((x, y + 0.1, z)) for x, z in poly]
    glass_bm.faces.new(vs)
    glass = bm_obj("glass", glass_bm, "glass", ("solidify",))
    m = glass.modifiers.new("s", "SOLIDIFY"); m.thickness = 0.02; apply_mods(glass)
    bar = 0.055
    spring = h - w / 2 if kind == "arch" else h
    mul_v = box("mullion", bar, bar, h - 0.02, (0, y + 0.07, 0), "timber")
    parts = [frame, glass, mul_v]
    if kind == "arch":
        parts.append(box("transom", w, bar, bar, (0, y + 0.07, spring - bar / 2), "timber"))
        parts.append(box("transom2", w, bar, bar, (0, y + 0.07, spring * 0.5 - bar / 2), "timber"))
        r = w / 2 + 0.16
        hood = curve_bevel("hood", [(r * math.cos(a), y - 0.06, spring + r * math.sin(a)) for a in (math.pi * i / 14 for i in range(15))], 0.07, "trim", square=True)
        key = profile_extrude("keystone", [(y - 0.1, 0), (y + 0.02, 0), (y + 0.02, 0.36), (y - 0.1, 0.36)], 0.26, "trim")
        key.location = (-0.13, 0, spring + w / 2 + 0.02)
        parts += [hood, key]
    else:
        tr = box("transom", w, bar, bar, (0, y + 0.07, h * 0.62), "timber")
        parts.append(tr)
        head = profile_extrude("head", [(y + 0.02, h), (y - 0.14, h), (y - 0.18, h + 0.12), (y + 0.02, h + 0.16)], w + 0.36, "trim")
        head.location.x = -(w + 0.36) / 2
        parts.append(head)
    sill = profile_extrude("sill", [(y + 0.06, -0.08), (y - 0.18, -0.08), (y - 0.18, 0.02), (y + 0.06, 0.05)], w + 0.34, "trim")
    sill.location.x = -(w + 0.34) / 2
    parts.append(sill)
    if shutters:
        sh_w = w * 0.45
        sl = box("slat", sh_w, 0.04, 0.09, (-w / 2 - sh_w / 2 - 0.08, y - 0.06, 0.05), "door")
        array(sl, int((h - 0.1) / 0.12), (0, 0, 0.12))
        mirror(sl, 0, (0, 0, 0))
        parts.append(sl)
    if box_flowers:
        fb = box("fbox", w + 0.2, 0.26, 0.24, (0, y - 0.22, -0.32), "door")
        bl = screw("bloom", [(0, 0), (0.09, 0.05), (0.1, 0.12), (0.04, 0.18), (0, 0.19)], "plant", 6)
        bl.location = (-w / 2 + 0.05, y - 0.22, -0.1)
        array(bl, max(2, int(w / 0.18)), (0.18, 0, 0))
        jitter(bl, 0.03, 7)
        fl = screw("blossom", [(0, 0), (0.05, 0.02), (0.05, 0.05), (0, 0.07)], "flower", 5)
        fl.location = (-w / 2 + 0.12, y - 0.26, 0.04)
        array(fl, max(2, int(w / 0.25)), (0.25, 0, 0))
        jitter(fl, 0.03, 9)
        parts += [fb, bl, fl]
    return join(parts, "window_" + kind)

DOOR_Y = T / 2 - 0.045   # 门扇贴内墙面：开门时绕内侧墙角旋转，不扫进墙体

def door(kind="rect", w=1.4, h=2.7, t=0.07, gap=0.01):
    """门：竖板（阵列）、拱顶板（实体化）、铁铰带（曲线倒角）、门环（旋绕）、门框（曲线倒角，外墙面）。
    原点：门洞底边中点；门扇在内墙面 y=DOOR_Y，铰链在 (-w/2, T/2)。t = 门扇厚，gap = 板缝。返回 (门扇, 门框)。"""
    y = T / 2 - 0.045
    pl = box("plank", w / 6 - gap, t, h - (w / 2 if kind == "arch" else 0) - 0.02, (-w / 2 + w / 12, y, 0), "door")
    array(pl, 6, (w / 6, 0, 0))
    parts = [pl]
    if kind == "arch":
        r = w / 2 - 0.01
        bm = bmesh.new()
        seg = 12
        base_z = h - w / 2
        vs = [bm.verts.new((0, y, base_z - 0.02))]
        for i in range(seg + 1):
            a = math.pi * i / seg
            vs.append(bm.verts.new((r * math.cos(a), y, base_z - 0.02 + r * math.sin(a))))
        for i in range(1, seg + 1):
            bm.faces.new((vs[0], vs[i], vs[i + 1]))
        tp = bm_obj("door_top", bm, "door", ("solidify",))
        m = tp.modifiers.new("s", "SOLIDIFY"); m.thickness = t; m.offset = 0; apply_mods(tp)
        parts.append(tp)
    ys = y - t / 2 - 0.015
    for z in (0.45, h - 1.0):
        st = curve_bevel("strap", [(-w / 2 + 0.05, ys, z), (w * 0.25, ys, z), (w * 0.32, ys, z + 0.06)], 0.035, "iron", square=True)
        parts.append(st)
    ring = screw("ring", [(0.07, -0.01), (0.09, 0.0), (0.07, 0.01)], "iron", 12)
    ring.rotation_euler = (math.pi / 2, 0, 0); ring.location = (w * 0.28, y - t / 2 - 0.035, 1.2)
    parts.append(ring)
    leaf = join(parts, "door_leaf_" + kind)
    poly = opening_poly(kind, 0, 0, w + 0.16, h + 0.08)
    poly = poly[1:] + poly[:1]   # 门框不封底：从右下沿洞口走到左下
    fr = curve_bevel("dframe", [(x, -T / 2 - 0.02, z) for x, z in poly], 0.08, "trim" if kind == "arch" else "timber", square=True)
    return leaf, fr

# Roofs ------------------------------------------------------------
def roof_side(length, run, rise, mkey="slate", over=0.5, flare=True, thick=0.22):
    """一侧坡屋面：瓦面板（实体化，顶面过屋脊线）+ 檐口封檐板 + 两端山墙封檐板（截面挤出，按瓦面实际坡线计算），
    合并后整体做檐口外翻（几何顶点），三者始终对齐。原点：屋脊线起点（x=0），坡面朝 -Y 下降。"""
    k = rise / run
    ang = math.atan2(rise, run)
    L = (run + over) / math.cos(ang)
    bm = bmesh.new()
    nx, ns = max(2, int(length / 0.6)), 10
    grid = [[bm.verts.new((i * length / nx, -L * j / ns, 0)) for i in range(nx + 1)] for j in range(ns + 1)]
    for j in range(ns):
        for i in range(nx):
            bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
    bmesh.ops.reverse_faces(bm, faces=bm.faces)     # 法线朝上
    slab = bm_obj("roof", bm, mkey, ("solidify",))
    m = slab.modifiers.new("s", "SOLIDIFY"); m.thickness = thick; m.offset = -1   # 向下长厚度，顶面即瓦面
    apply_mods(slab)
    slab.data.transform(Matrix.Rotation(ang, 4, "X"))
    ye, ze = -(run + over), -k * (run + over)       # 檐口顶边
    hv = thick / math.cos(ang) + 0.08                # 竖向厚度 + 盖缝
    fascia = profile_extrude("fascia", [(ye - 0.07, ze + 0.03), (ye + 0.02, ze + 0.03), (ye + 0.02, ze - hv), (ye - 0.07, ze - hv)], length + 0.14, "timber")
    fascia.location.x = -0.07
    parts = [slab, fascia]
    for x0 in (-0.07, length):
        bb = profile_extrude("barge", [(0.02, 0.05), (ye, ze + 0.05), (ye, ze - hv), (0.02, -hv)], 0.07, "timber")
        bb.location.x = x0
        parts.append(bb)
    ob = join(parts, "roof_side")
    if flare:
        for v in ob.data.vertices:
            t = max(0.0, (-v.co.y - (run - 0.3)) / (over + 0.3))
            v.co.z += 0.15 * t * t
        ob["methods"] += ",vertex"
    return ob

def ridge(length, mkey="slate"):
    """屋脊盖瓦：A 形截面挤出 + 分段阵列。"""
    seg = profile_extrude("ridge", [(-0.22, -0.08), (0, 0.12), (0.22, -0.08), (0.15, -0.12), (0, 0.03), (-0.15, -0.12)], 0.6, mkey)
    n = max(1, int(round(length / 0.6)))
    seg.scale.x = length / n / 0.6
    apply_scale(seg)
    array(seg, n, (length / n, 0, 0))
    return seg

def simple_taper(ob, factor, origin):
    """简单形变（SIMPLE_DEFORM / TAPER）：沿 Z 收分。"""
    m = ob.modifiers.new("tp", "SIMPLE_DEFORM"); m.deform_method = "TAPER"; m.factor = factor; m.deform_axis = "Z"
    e = _link(bpy.data.objects.new("tpo", None)); e.location = origin; m.origin = e
    apply_mods(ob)
    bpy.data.objects.remove(e)
    ob["methods"] = ",".join(sorted(set(ob["methods"].split(",")) | {"simple_deform"} - {""}))
    return ob

def chimney(h=2.4, seed=5):
    """烟囱：块石阵列 + 顶点错位 + 收分（简单形变 TAPER）+ 顶部压檐 + 陶土烟囱帽（旋绕）。"""
    blk = box("cblk", 0.9, 0.9, 0.3, (0, 0, 0), "rubble")
    n = int(h / 0.3)
    array(blk, n, (0, 0, 0.3))
    jitter(blk, 0.02, seed, (1, 1, 0.2))
    simple_taper(blk, -0.06, (0, 0, 0))
    cap = profile_extrude("ccap", [(-0.55, 0), (0.55, 0), (0.55, 0.12), (0.4, 0.2), (-0.4, 0.2), (-0.55, 0.12)], 1.1, "trim")
    cap.location = (-0.55, 0, n * 0.3)
    pot = screw("pot", [(0.0, 0), (0.16, 0), (0.14, 0.3), (0.18, 0.36), (0.0, 0.36)], "terracotta", 10)
    pot.location = (0.15, 0, n * 0.3 + 0.2)
    return join([blk, cap, pot], "chimney")

def bracket(depth=0.9, h=1.0):
    """檐托（Support_2）：L 形截面挤出 + 斜撑。"""
    a = box("bk_arm", 0.18, depth, 0.22, (0, -depth / 2, h - 0.22), "timber")
    br = profile_extrude("bk_brace", [(-0.08, 0), (0.08, 0), (0.08, math.hypot(depth * 0.8, h * 0.8)), (-0.08, math.hypot(depth * 0.8, h * 0.8))], 0.16, "timber", "x")
    br.location = (-0.08, 0, 0)
    br.rotation_euler = (math.atan2(depth * 0.8, h * 0.8), 0, 0)
    return join([a, br], "bracket")

def oculus(r=0.5):
    """山墙圆窗：窗框圆环（曲线倒角，闭合）、玻璃圆片（旋绕）、十字窗棂（挤出）。原点在圆心，外墙面 y=-T/2。"""
    y = -T / 2 - 0.03
    ring = curve_bevel("oc_ring", [(r * math.cos(a), y, r * math.sin(a)) for a in (2 * math.pi * i / 20 for i in range(20))], 0.07, "trim", closed=True)
    g = screw("oc_glass", [(r, 0), (0, 0)], "glass", 20)
    g.rotation_euler = (math.pi / 2, 0, 0); g.location = (0, y + 0.08, 0)
    a = box("oc_mv", 0.05, 0.05, 2 * r, (0, y + 0.02, -r), "timber")
    b = box("oc_mh", 2 * r, 0.05, 0.05, (0, y + 0.02, -0.025), "timber")
    return join([ring, g, a, b], "oculus")

def finial(h=0.9):
    """山尖尖饰（Decor_Peaks）：铁质旋绕。"""
    return screw("finial", [(0, 0), (0.06, 0), (0.05, 0.15), (0.09, 0.3), (0.03, 0.42), (0.03, h - 0.25), (0.07, h - 0.2), (0, h)], "iron", 8)

def ivy(w=1.6, h=3.0, seed=1):
    """常春藤（Ivy）：叶片卡阵列 + 顶点扰动，越往上越稀。原点在墙角，贴外墙面 -Y 沿 +X 展开。"""
    rnd = random.Random(seed)
    bm = bmesh.new()
    n = int(w * h * 26)
    for _ in range(n):
        x = rnd.uniform(0, w) * rnd.uniform(0.3, 1.0)
        z = h * (1 - math.sqrt(rnd.random()))
        if rnd.random() < z / h * 0.6:
            continue
        cx, cz = x, z
        s = rnd.uniform(0.09, 0.15)
        y = -T / 2 - 0.03 - rnd.uniform(0, 0.06)
        a = rnd.uniform(0, math.pi)
        vs = [bm.verts.new((cx + s * math.cos(a + k * math.pi / 2) * (1 if k % 2 == 0 else 0.6), y, cz + s * math.sin(a + k * math.pi / 2) * (1 if k % 2 == 0 else 0.6))) for k in range(4)]
        bm.faces.new(vs)
    ob = bm_obj("ivy", bm, "plant", ("array", "vertex"))
    m = ob.modifiers.new("s", "SOLIDIFY"); m.thickness = 0.01; apply_mods(ob)
    return ob

# Walls & gate (院墙 / 门楼) ------------------------------------------
def coping(length, w=0.62, mkey="trim"):
    """墙顶压顶石：斜面截面挤出，分块阵列。"""
    seg = profile_extrude("coping", [(-w / 2, 0), (w / 2, 0), (w / 2, 0.1), (0, 0.24), (-w / 2, 0.1)], 1.2, mkey)
    n = max(1, int(round(length / 1.2)))
    seg.scale.x = length / n / 1.2
    apply_scale(seg)
    array(seg, n, (length / n, 0, 0))
    return jitter(seg, 0.008, 2, (0, 1, 1))

def pier(h=3.0, w=0.8, seed=4):
    """墙墩：块石阵列 + 墩帽（挤出）+ 球饰（旋绕）。原点在墩底中心。"""
    blk = box("pblk", w, w, 0.5, (0, 0, 0), "ashlar")
    n = int(h / 0.5)
    array(blk, n, (0, 0, h / n))
    jitter(blk, 0.012, seed, (1, 1, 0.2))
    cap = profile_extrude("pcap", [(-w / 2 - 0.1, 0), (w / 2 + 0.1, 0), (w / 2 + 0.1, 0.12), (w / 2 - 0.05, 0.22), (-w / 2 + 0.05, 0.22), (-w / 2 - 0.1, 0.12)], w + 0.2, "trim")
    cap.location = (-(w + 0.2) / 2, 0, h)
    ball = screw("pball", [(0, 0), (0.18, 0), (0.12, 0.08), (0.2, 0.25), (0.14, 0.4), (0, 0.45)], "trim", 12)
    ball.location = (0, 0, h + 0.22)
    return join([blk, cap, ball], "pier")

def wall_segment(length=4.8, h=2.6, seed=1, ivy_on=True):
    """院墙一段：勒脚 + 石墙板（实体化）+ 压顶 + 一端墙墩 + 随机常春藤。沿 +X，中心线 y=0，原点在左端。"""
    base = profile_extrude("wbase", [(-0.38, 0), (0.38, 0), (0.38, 0.45), (0.3, 0.55), (-0.3, 0.55), (-0.38, 0.45)], length, "rubble")
    jitter(base, 0.012, seed, (0.2, 1, 0.5))
    wall = panel("wall", length, h - 0.55, "ashlar", None, 0.5)
    wall.location = (0, 0, 0.55)
    cp = coping(length)
    cp.location = (0, 0, h)
    pr = pier(h + 0.3, 0.85, seed + 3)
    parts = [base, wall, cp, pr]
    if ivy_on and seed % 3 != 0:
        iv = ivy(random.Random(seed).uniform(1.2, 2.4), h * random.Random(seed + 1).uniform(0.6, 0.95), seed)
        iv.location = (random.Random(seed + 2).uniform(0.8, length - 2.6), -0.1, 0.3)
        parts.append(iv)
    return join(parts, "wall_segment")

def gatehouse(passage=4.2, h_arch=5.4, depth=2.4):
    """修道院门楼：两侧厚墩（块石阵列）、半圆券门洞（桥接 + 实体化）、券石（曲线倒角）、
    小坡屋顶（实体化 + 简单形变）、山尖十字（挤出 + 镜像）、敞开的铁花门（阵列 + 镜像 + 曲线倒角）、壁灯。
    原点：门洞地面中心；门洞沿 Y 穿过，外侧朝 -Y。"""
    W = passage + 2 * 1.8
    Hh = h_arch + 1.6
    parts = []
    # 门楼前后两片墙板（带券洞），用桥接 + 实体化
    for y in (-depth / 2, depth / 2):
        p = panel("gface", W, Hh, "ashlar", ("arch", W / 2, 0, passage, h_arch), 0.4)
        p.location = (-W / 2, y, 0)
        parts.append(p)
    # 两侧实墙（门洞内壁）
    for sx in (-1, 1):
        side = box("gside", 0.4, depth, h_arch - passage / 2, (sx * (passage / 2 + 0.2), 0, 0), "ashlar")
        parts.append(side)
    # 券顶内壁：半圆筒（旋绕 180°）
    vault = screw("gvault", [(passage / 2 + 0.01, -depth / 2), (passage / 2 + 0.01, depth / 2)], "ashlar", 12)
    vault.rotation_euler = (math.pi / 2, 0, 0)
    vault.location = (0, 0, h_arch - passage / 2)
    # 只保留上半
    bm = bmesh.new(); bm.from_mesh(vault.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -0.01], context="VERTS")
    bm.to_mesh(vault.data); bm.free()
    parts.append(vault)
    # 券石：沿券线的曲线倒角
    for y in (-depth / 2 - 0.22, depth / 2 + 0.22):
        r = passage / 2 + 0.15
        pts = [(r * math.cos(a), y, h_arch - passage / 2 + r * math.sin(a)) for a in (math.pi * i / 16 for i in range(17))]
        parts.append(curve_bevel("voussoir", pts, 0.18, "trim", square=True))
    # 墙角隅石 + 墙脚
    for sx in (-1, 1):
        q = quoin(Hh, 7 + sx)
        q.location = (sx * W / 2, -depth / 2, 0)
        parts.append(q)
        q2 = quoin(Hh, 9 + sx)
        q2.location = (sx * W / 2, depth / 2, 0)
        parts.append(q2)
    base = profile_extrude("gbase", [(-depth / 2 - 0.28, 0), (depth / 2 + 0.28, 0), (depth / 2 + 0.28, 0.5), (-depth / 2 - 0.28, 0.5)], W + 0.5, "rubble")
    base.location.x = -(W + 0.5) / 2
    # 墙板裁掉门洞处勒脚：做成左右两段
    bl = box("gbase_l", (W - passage) / 2 + 0.25, depth + 0.56, 0.5, (-(passage / 2 + ((W - passage) / 2 + 0.25) / 2), 0, 0), "rubble")
    br = box("gbase_r", (W - passage) / 2 + 0.25, depth + 0.56, 0.5, ((passage / 2 + ((W - passage) / 2 + 0.25) / 2), 0, 0), "rubble")
    bpy.data.objects.remove(base)
    parts += [jitter(bl, 0.01, 3), jitter(br, 0.01, 4)]
    # 檐口线脚 + 小坡屋顶 + 屋脊
    cor = profile_extrude("gcornice", [(-depth / 2 - 0.3, 0), (depth / 2 + 0.3, 0), (depth / 2 + 0.38, 0.14), (depth / 2 + 0.2, 0.26), (-depth / 2 - 0.2, 0.26), (-depth / 2 - 0.38, 0.14)], W + 0.6, "trim")
    cor.location = (-(W + 0.6) / 2, 0, Hh)
    parts.append(cor)
    zr = Hh + 0.26
    for rot in (0, math.pi):
        rs = roof_side(W + 0.8, depth / 2 + 0.3, 1.3, "slate", 0.35)
        rs.matrix_world = Matrix.Rotation(rot, 4, "Z") @ Matrix.Translation((-(W + 0.8) / 2, 0, zr + 1.3))
        parts.append(rs)
    for sx in (-1, 1):
        g = gable(depth + 0.6, 1.2, frame=False, t=0.3)
        g.matrix_world = Matrix.Translation((sx * W / 2, -sx * (depth + 0.6) / 2, zr)) @ Matrix.Rotation(sx * math.pi / 2, 4, "Z")
        parts.append(g)
    rd = ridge(W + 0.8, "slate"); rd.location = (-(W + 0.8) / 2, 0, zr + 1.3)
    parts.append(rd)
    # 山尖石十字（外立面上方）
    cr = box("cross_v", 0.16, 0.16, 1.1, (0, -depth / 2 - 0.1, Hh - 1.25), "trim")
    ch = box("cross_h", 0.6, 0.16, 0.16, (0, -depth / 2 - 0.1, Hh - 0.85), "trim")
    parts += [cr, ch]
    # 敞开的铁花门：竖杆阵列 + 横档 + 顶部曲线，左右镜像
    leaf_w = passage / 2 - 0.16
    bar = screw("gbar", [(0, 0), (0.025, 0), (0.025, 2.9), (0.05, 2.95), (0, 3.1)], "iron", 6)
    nb = int(leaf_w / 0.16)
    array(bar, nb, (0.16, 0, 0))
    rails = []
    for z in (0.15, 1.4, 2.6):
        rails.append(box("grail", leaf_w, 0.05, 0.07, (leaf_w / 2, 0, z), "iron"))
    leaf = join([bar] + rails, "gleaf")
    # 打开 84°，铰链离门洞侧壁 0.14m，门扇贴着侧壁停在门洞内（门高 3.1m < 券脚 3.3m，不碰券顶）
    leaf.data.transform(Matrix.Rotation(math.radians(84), 4, "Z"))
    leaf.location = (-passage / 2 + 0.14, -depth / 2 + 0.3, 0)
    mirror(leaf, 0, (0, 0, 0))
    parts.append(leaf)
    for sx in (-1, 1):
        l = lantern()
        l.matrix_world = Matrix.Translation((sx * (passage / 2 + 0.9), -depth / 2 - 0.05, 3.0))
        parts.append(l)
    return join(parts, "gatehouse")

def lamp_post(h=3.6):
    """铁艺路灯：旋绕灯柱（底座线脚）、曲线倒角挂臂与卷草、旋绕灯笼 + 发光玻璃、底座石台（挤出）。原点在地面。"""
    post = screw("lpost", [(0, 0), (0.22, 0), (0.22, 0.12), (0.14, 0.2), (0.12, 0.6), (0.08, 0.7), (0.06, h - 0.3), (0.09, h - 0.2), (0.05, h - 0.1), (0, h)], "iron", 10)
    arm = curve_bevel("larm", [(0, 0, h - 0.35), (0, -0.35, h - 0.25), (0, -0.62, h - 0.32), (0, -0.7, h - 0.45)], 0.03, "iron")
    scroll = curve_bevel("lscroll", [(0, 0, h - 0.7)] + [(0, -0.12 - 0.12 * math.sin(a), h - 0.55 - 0.12 * math.cos(a)) for a in (i * math.pi / 6 for i in range(1, 9))], 0.018, "iron")
    cage = screw("lcage", [(0, 0), (0.13, 0.02), (0.16, 0.12), (0.12, 0.42), (0.2, 0.47), (0.04, 0.6), (0, 0.66)], "iron", 6)
    glow = screw("lglow", [(0, 0.05), (0.13, 0.08), (0.1, 0.4), (0, 0.41)], "K|glow|ffcf80||0", 6)
    for o in (cage, glow):
        o.location = (0, -0.7, h - 1.15)
    plinth = box("lplinth", 0.6, 0.6, 0.3, (0, 0, 0), "trim")
    post.location.z = 0.3
    arm.location.z = 0.3; scroll.location.z = 0.3; cage.location.z += 0.3; glow.location.z += 0.3
    return join([post, arm, scroll, cage, glow, plinth], "lamp_post")

def cypress(h=7.0, seed=1):
    """柏树：多层旋绕树冠叠放 + 顶点扰动，树干旋绕。原点在地面。"""
    rnd = random.Random(seed)
    trunk = screw("ctrunk", [(0, 0), (0.16, 0), (0.12, 1.0), (0, 1.1)], "timber", 6)
    lobes = []
    n = 6
    for i in range(n):
        t = i / (n - 1)
        r = 0.95 * (1 - t * 0.75) * rnd.uniform(0.9, 1.1)
        z0 = 0.7 + t * (h - 1.9)
        lb = screw("clobe", [(0, 0), (r * 0.7, 0.15), (r, 0.6), (r * 0.8, 1.1), (r * 0.35, 1.45), (0, 1.55)], "K|8|335f35||0", 9)
        lb.location = (rnd.uniform(-0.06, 0.06), rnd.uniform(-0.06, 0.06), z0)
        jitter(lb, 0.09 * r + 0.03, seed * 10 + i)
        lobes.append(lb)
    tip = screw("ctip", [(0, 0), (0.3, 0.2), (0.16, 0.7), (0, 1.0)], "K|8|3d6b3b||0", 7)
    tip.location.z = h - 1.0
    return join([trunk] + lobes + [tip], "cypress")

# Stairs -----------------------------------------------------------
def stone_steps(w=2.4, n=4, rise=BASE / 4, run=0.36):
    """台阶：踏步（轮廓挤出）逐级阵列 + 顶点错位；两侧挡墙（挤出）。外立面朝 -Y，顶面与室内地坪平齐。
    碰撞不用踏步，另由 step_ramp() 提供斜坡（*_colonly）。"""
    parts = []
    for i in range(n):
        h = rise * (n - i)
        s = box("step", w, run + 0.02, h, (0, -run * (i + 0.5), 0), "rubble")
        parts.append(s)
    for sx in (-1, 1):
        prof = [(0.0, 0.0), (-run * n, 0.0), (-run * n, rise * 0.8), (0.0, BASE + 0.12)]
        ch = profile_extrude("cheek", prof, 0.24, "ashlar")
        ch.location.x = sx * (w / 2 + 0.12) - 0.12
        parts.append(ch)
    ob = join(parts, "steps")
    ob["methods"] = "array,profile_extrude,vertex"
    return jitter(ob, 0.008, 11)

def step_ramp(w, n=4, run=0.36, landing=0.6):
    """台阶碰撞斜坡（不渲染）：从台阶前沿地面到门槛高度，再接一段平台进门。"""
    bm = bmesh.new()
    L = run * n
    pts = [(-w / 2, -L, 0.0), (w / 2, -L, 0.0), (w / 2, 0.0, BASE), (-w / 2, 0.0, BASE),
           (w / 2, landing, BASE), (-w / 2, landing, BASE)]
    v = [bm.verts.new(p) for p in pts]
    bm.faces.new((v[0], v[1], v[2], v[3])); bm.faces.new((v[3], v[2], v[4], v[5]))
    return bm_obj("ramp_colonly", bm, "trim", ("bridge",))

def apply_scale(ob):
    ob.data.transform(Matrix.Diagonal((*ob.scale, 1)))
    ob.scale = (1, 1, 1)

def railing(length, h=1.0, mkey="timber"):
    """栏杆（Wooden_Railings）：旋绕栏杆柱阵列 + 扶手挤出。"""
    bal = screw("baluster", [(0, 0), (0.05, 0), (0.05, 0.1), (0.035, 0.2), (0.05, h * 0.5), (0.03, h * 0.8), (0.04, h - 0.05), (0, h - 0.05)], mkey, 8)
    n = max(2, int(length / 0.22))
    bal.location = (0.11, 0, 0)
    array(bal, n, (length / n, 0, 0))
    rail = profile_extrude("handrail", [(-0.06, h - 0.06), (0.06, h - 0.06), (0.05, h + 0.04), (-0.05, h + 0.04)], length, mkey)
    bot = profile_extrude("botrail", [(-0.04, 0.05), (0.04, 0.05), (0.04, 0.12), (-0.04, 0.12)], length, mkey)
    return join([bal, rail, bot], "railing")

def canopy(w=4.0, d=2.2, h=3.2, mkey="terracotta"):
    """门廊雨棚（Wooden_Canopy）：立柱、檐梁（挤出），屋面板（阵列+曲线变形）。原点：贴墙边中点，向 -Y 伸出。"""
    parts = []
    for sx in (-1, 1):
        p = box("cpost", 0.18, 0.18, h - 0.3, (sx * (w / 2 - 0.2), -d + 0.2, 0), "timber")
        parts.append(p)
    parts.append(box("cbeam", w, 0.2, 0.22, (0, -d + 0.2, h - 0.4), "timber"))
    sl = box("cplank", w + 0.4, 0.3, 0.05, (0, -0.15, 0), mkey)
    n = int(d / 0.28) + 1
    array(sl, n, (0, -0.28, 0))
    for v in sl.data.vertices:
        v.co.z += h + 0.2 - 0.45 * (-v.co.y / d) - 0.12 * (-v.co.y / d) ** 2
    sl["methods"] += ",vertex"
    parts.append(sl)
    for sx in (-1, 1):
        br = profile_extrude("cbr", [(-0.06, 0), (0.06, 0), (0.06, 0.9), (-0.06, 0.9)], 0.12, "timber", "x")
        br.location = (sx * (w / 2 - 0.2) - 0.06, -d + 0.25, h - 1.2)
        br.rotation_euler = (math.radians(45), 0, 0)
        parts.append(br)
    return join(parts, "canopy")

def lantern():
    """壁灯：旋绕灯罩 + 曲线倒角挂臂。原点在墙面。"""
    body = screw("lamp", [(0, 0), (0.12, 0.02), (0.14, 0.12), (0.1, 0.36), (0.16, 0.4), (0.0, 0.52)], "iron", 6)
    glow = screw("lglow", [(0, 0.04), (0.11, 0.06), (0.09, 0.34), (0, 0.35)], "K|glow|ffcf80||0", 6)
    for o in (body, glow):
        o.location = (0, -0.42, -0.25)
    arm = curve_bevel("larm", [(0, -T / 2, 0.2), (0, -0.3, 0.32), (0, -0.42, 0.3), (0, -0.42, 0.27)], 0.02, "iron")
    return join([body, glow, arm], "lantern")

# Indoor -----------------------------------------------------------
def floor_planks(x0, y0, w, d, z=BASE):
    """木地板：三种错缝排布的板条行（阵列）、行间留缝露出深色衬板（挤出），轻微高低差（几何顶点）。顶面在 z。"""
    rows = []
    pw, gap, seg = 0.24, 0.012, 1.8
    nr = max(1, int(d / pw))
    for k in range(3):
        off = (k * 0.6) % seg
        x = -off
        pieces = []
        while x < w:
            a0, a1 = max(x, 0.0), min(x + seg - gap, w)
            if a1 - a0 > 0.05:
                pieces.append(box("fp", a1 - a0, pw - gap, 0.05, ((a0 + a1) / 2, (pw - gap) / 2, z - 0.05), "floor"))
            x += seg
        row = join(pieces, "frow")
        row.location.y = k * pw
        array(row, (nr - k + 2) // 3, (0, pw * 3, 0))
        rows.append(row)
    sub = box("subfloor", w, d, 0.04, (w / 2, d / 2, z - 0.09), "timber")
    ob = join(rows + [sub], "floor")
    jitter(ob, 0.004, 5, (0, 0, 1))
    ob.data.transform(Matrix.Translation((x0, y0, 0)))
    return ob

def ceiling(x0, y0, w, d, z, boards=True):
    """楼盖 / 天花：次梁（沿进深，阵列）+ 主梁（沿开间，在次梁下）+ 主梁端头石托（挤出）+ 长房间中部立柱与斜撑（镜像）
    + 天花板（木板阵列，从下面看是吊顶）。z 为次梁顶面。"""
    parts = []
    j = box("joist", 0.2, d, 0.24, (0.6, d / 2, z - 0.24), "timber")
    nj = max(1, int((w - 0.6) / 1.2) + 1)
    array(j, nj, (1.2, 0, 0))
    parts.append(j)
    gz = z - 0.24
    parts.append(box("girder", w, 0.34, 0.38, (w / 2, d / 2, gz - 0.38), "timber"))
    for x in (0.0, w):
        c = profile_extrude("corbel", [(-0.25, 0), (0.25, 0), (0.25, -0.15), (0.0, -0.45), (-0.25, -0.15)], 0.36, "ashlar", "x")
        c.location = (x if x == 0 else x - 0.36, d / 2, gz - 0.38)
        parts.append(c)
    if boards:
        bd = box("ceilboard", w, 0.3 - 0.01, 0.03, (w / 2, 0.15, z), "floor")
        array(bd, max(1, int(d / 0.3)), (0, 0.3, 0))
        parts.append(bd)
    ob = join(parts, "ceiling")
    ob.data.transform(Matrix.Translation((x0, y0, 0)))
    return ob

def posts(x0, y0, w, d, z_floor, z_girder):
    """长房间的主梁中柱 + 双向斜撑（镜像）。"""
    parts = []
    if w <= 10.0:
        return None
    for fx in (1 / 3, 2 / 3):
        x = w * fx
        parts.append(box("post", 0.3, 0.3, z_girder - z_floor, (x, d / 2, z_floor), "timber"))
        br = profile_extrude("kbrace", [(-0.08, 0), (0.08, 0), (0.08, 1.1), (-0.08, 1.1)], 0.14, "timber", "x")
        br.data.transform(Matrix.Rotation(math.radians(-45), 4, "Y"))
        br.location = (x + 0.12, d / 2 - 0.07, z_girder - 0.85)
        mirror(br, 0, (x, 0, 0))
        parts.append(br)
    ob = join(parts, "posts")
    ob.data.transform(Matrix.Translation((x0, y0, 0)))
    return ob
