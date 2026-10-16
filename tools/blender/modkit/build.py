# 按装配表把构件拼成整栋建筑，导出 assets/models/modkit/<id>.glb，并渲染预览 docs/modkit/<id>.png
# blender -b -P tools/blender/modkit/build.py -- [id1,id2]
import bpy, bmesh, math, os, sys, json, importlib
from mathutils import Matrix, Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit
importlib.reload(kit)
from kit import U, H, T, BASE

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "modkit")
DOC = os.path.join(ROOT, "docs", "modkit")
os.makedirs(OUT, exist_ok=True); os.makedirs(DOC, exist_ok=True)

# 装配表：nx×ny 模数；floors 自下而上 stone / frame；doors=[(side, slot, open)]；side ∈ front/back/left/right
HOUSES = {
    "abbey_quartermaster": dict(nx=5, ny=4, floors=["stone", "frame"], roof="slate", pitch=1.05,
                                doors=[("front", 2, True)], canopy=("front", 2, 5.0), chimney=(0.22, 0.72), lanterns=[("front", 2)]),
    "abbey_training_hall": dict(nx=7, ny=4, floors=["stone"], roof="slate", pitch=0.9, wall_h=4.6,
                                doors=[("front", 3, True)], chimney=None, lanterns=[("front", 3)]),
    "abbey_cottage": dict(nx=3, ny=3, floors=["stone"], roof="slate", pitch=1.1,
                          doors=[("front", 1, True)], chimney=(0.2, 0.7), lanterns=[("front", 1)]),
    "vale_house_timber": dict(nx=5, ny=3, floors=["stone", "frame"], roof="terracotta", pitch=1.15,
                              doors=[("front", 2, True)], chimney=(0.2, 0.7), lanterns=[("front", 2)]),
}

# 单件道具 / 场景构件：id -> (构造函数, 预览尺寸)
PROPS = {
    "abbey_wall_seg": (lambda: kit.wall_segment(4.8, 2.6, 1), (4.8, 1, 3)),
    "abbey_wall_seg_b": (lambda: kit.wall_segment(4.8, 2.6, 2), (4.8, 1, 3)),
    "abbey_wall_seg_c": (lambda: kit.wall_segment(4.8, 2.6, 3), (4.8, 1, 3)),
    "abbey_gatehouse": (lambda: kit.gatehouse(), (8, 3, 8)),
    "lamp_post_iron": (lambda: kit.lamp_post(), (1.5, 1.5, 4)),
    "cypress_kit": (lambda: kit.cypress(7.0, 1), (2, 2, 7)),
    "cypress_kit_b": (lambda: kit.cypress(6.0, 2), (2, 2, 6)),
}

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit.COL = None

def side_xf(side, i, W, D, z, ln=U):
    """把沿 +X、外立面朝 -Y 的构件放到某一面第 i 格。"""
    if side == "front":
        return Matrix.Translation((i * ln, 0, z))
    if side == "back":
        return Matrix.Translation(((i + 1) * ln, D, z)) @ Matrix.Rotation(math.pi, 4, "Z")
    if side == "left":
        return Matrix.Translation((0, (i + 1) * ln, z)) @ Matrix.Rotation(-math.pi / 2, 4, "Z")
    return Matrix.Translation((W, i * ln, z)) @ Matrix.Rotation(math.pi / 2, 4, "Z")

def place(ob, xf):
    bpy.context.view_layer.update()
    ob.matrix_world = xf @ ob.matrix_world
    return ob

def facade_variant(fl, n, i, ground, is_door):
    """立面开窗规则（左右对称）：m = 距最近端头的格数。石层：n<6 全开窗，n≥6 隔一开窗；木筋层：端头起隔一开窗，其余为斜撑实墙。"""
    if is_door:
        return "door"
    m = min(i, n - 1 - i)
    if fl == "stone":
        return "window" if n < 6 or m % 2 == 0 else "solid"
    return "window" if m % 2 == 0 or n <= 3 else "solid"

def house(hid, s):
    nx, ny = s["nx"], s["ny"]
    W, D = nx * U, ny * U
    parts, soft, colonly = [], [], []
    doors = {(d[0], d[1]): d[2] for d in s.get("doors", [])}
    counts = {"front": nx, "back": nx, "left": ny, "right": ny}
    z = BASE
    wall_h = s.get("wall_h", H)
    cx = Matrix.Translation((U / 2, 0, 0))
    for fi, fl in enumerate(s["floors"]):
        h = wall_h if fi == 0 else H
        wh = round(h * 0.6, 2)                     # 石墙拱窗高（3.6m 墙 → 2.16m）
        for side, n in counts.items():
            for i in range(n):
                key = (side, i)
                var = facade_variant(fl, n, i, fi == 0, fi == 0 and key in doors)
                if fl == "stone":
                    op = ("arch", U / 2, 0.8, 1.2, wh) if var == "window" else ("arch", U / 2, 0, 1.5, 2.9)
                    w = kit.wall_stone(var, U, h, op)
                else:
                    w = kit.wall_frame(var, U, h, skirting=fi == 0)
                place(w, side_xf(side, i, W, D, z))
                parts.append(w)
                if var == "window":
                    if fl == "stone":
                        win = kit.window("arch", 1.2, wh, shutters=False, box_flowers=side == "front")
                        place(win, side_xf(side, i, W, D, z + 0.8) @ cx)
                    else:
                        win = kit.window("rect", 1.2, 1.7, shutters=True, box_flowers=True)
                        place(win, side_xf(side, i, W, D, z + 1.0) @ cx)
                    parts.append(win)
                elif var == "door":
                    kind = "arch" if fl == "stone" else "rect"
                    dw, dh = (1.5, 2.9) if kind == "arch" else (1.4, 2.7)
                    leaf, fr = kit.door(kind, dw, dh)
                    if doors[key]:
                        # 开门：绕内墙面门洞左侧的铰链向室内转 90°，门扇贴在门洞边、伸进室内
                        piv = Vector((-dw / 2, T / 2, 0))
                        leaf.data.transform(Matrix.Translation(piv) @ Matrix.Rotation(math.radians(90), 4, "Z") @ Matrix.Translation(-piv))
                    for o in (leaf, fr):
                        place(o, side_xf(side, i, W, D, z) @ cx)
                        parts.append(o)
                    if fi == 0:
                        sw = dw + 0.9
                        st = kit.stone_steps(sw)
                        place(st, side_xf(side, i, W, D, 0) @ cx)
                        soft.append(st)
                        rp = kit.step_ramp(sw)
                        place(rp, side_xf(side, i, W, D, 0) @ cx)
                        colonly.append(rp)
        for (x, y) in ((0, 0), (W, 0), (0, D), (W, D)):
            if fl == "stone":
                q = kit.quoin(h)
                q.location = (x, y, z)
            else:
                q = kit.box("corner_post", 0.32, 0.32, h, (x, y, z), "timber")
            parts.append(q)
        z += h
        if fi < len(s["floors"]) - 1:
            for side, n in (("front", nx), ("back", nx)):
                band = kit.box("floor_band", n * U, 0.36, 0.28, (n * U / 2, -0.04, -0.14), "timber")
                ends = kit.box("joist_end", 0.2, 0.3, 0.22, (0.4, -0.2, -0.36), "timber")
                kit.array(ends, int(n * U / 0.8), (0.8, 0, 0))
                for o in (band, ends):
                    place(o, side_xf(side, 0, W, D, z, n * U))
                    parts.append(o)
    ztop = z
    for side, n in counts.items():
        for i in range(n):
            b = kit.stone_base(U, BASE, seed=i * 7 + len(side))
            place(b, side_xf(side, i, W, D, 0))
            parts.append(b)
    # 山墙 + 屋面。屋面顶面在外墙线处高出墙顶 0.27（瓦面板厚 0.22），墙头不会穿出屋面
    run = D / 2 + T / 2
    rise = s["pitch"] * D / 2
    k = rise / (D / 2)
    zr = ztop + k * run + 0.27
    top_frame = s["floors"][-1] == "frame"
    for side, xf in (("left", Matrix.Translation((0, D, ztop)) @ Matrix.Rotation(-math.pi / 2, 4, "Z")),
                     ("right", Matrix.Translation((W, 0, ztop)) @ Matrix.Rotation(math.pi / 2, 4, "Z"))):
        g = kit.gable(D, zr - ztop - 0.3, frame=top_frame)
        place(g, xf)
        parts.append(g)
        if not top_frame:
            ow = kit.oculus(0.5)
            place(ow, xf @ Matrix.Translation((D / 2, 0, (zr - ztop) * 0.42)))
            parts.append(ow)
    over_x, over = 0.45, 0.55
    rmat = s["roof"]
    for rot, org in ((0, (-over_x, D / 2, zr)), (math.pi, (W + over_x, D / 2, zr))):
        r = kit.roof_side(W + 2 * over_x, run, k * run, rmat, over)   # 瓦面 + 檐口板 + 山墙封檐板一体
        place(r, Matrix.Translation(org) @ Matrix.Rotation(rot, 4, "Z"))
        parts.append(r)
    rd = kit.ridge(W + 2 * over_x + 0.14, rmat)
    place(rd, Matrix.Translation((-over_x - 0.07, D / 2, zr)))
    parts.append(rd)
    for x in (-over_x - 0.035, W + over_x + 0.035):
        fn = kit.finial()
        place(fn, Matrix.Translation((x, D / 2, zr + 0.1)))
        parts.append(fn)
    for x in (0.0, W):
        for y in (0.6, D - 0.6):
            bk = kit.bracket(0.45, 0.8)
            place(bk, Matrix.Translation((x, y, ztop - 0.6)) @ Matrix.Rotation(-math.pi / 2 if x == 0 else math.pi / 2, 4, "Z"))
            parts.append(bk)
    if s.get("chimney"):
        fx, fy = s["chimney"]
        ch = kit.chimney(zr - ztop - k * abs(D * fy - D / 2) + 1.3)
        place(ch, Matrix.Translation((W * fx, D * fy, ztop)))
        parts.append(ch)
    if s["floors"][0] == "stone":
        for i, (x, y, rz) in enumerate(((0, 0, 0), (W, D, math.pi))):
            iv = kit.ivy(1.6, min(wall_h, H) * 0.9, seed=i + 3)
            place(iv, Matrix.Translation((x, y, BASE)) @ Matrix.Rotation(rz, 4, "Z"))
            parts.append(iv)
    if s.get("canopy"):
        side, i, cw = s["canopy"]
        c = kit.canopy(cw, 2.2, 3.4, rmat)
        place(c, side_xf(side, i, W, D, BASE) @ Matrix.Translation((U / 2, -T / 2, 0)))
        parts.append(c)
    for side, i in s.get("lanterns", []):
        for dx in (-1.05, 1.05) if (side, i) in doors else (0,):
            l = kit.lantern()
            place(l, side_xf(side, i, W, D, BASE + 2.4) @ Matrix.Translation((U / 2 + dx, 0, 0)))
            parts.append(l)
    # 室内：抬高的木地板（顶面 = BASE，与门槛平齐）；每层顶部：次梁 + 主梁 + 石托 + 天花板；长房间加中柱斜撑
    iw, idp = W - T, D - T
    parts.append(kit.floor_planks(T / 2, T / 2, iw, idp, BASE))
    zz = BASE
    for fi, fl in enumerate(s["floors"]):
        zf = zz
        zz += wall_h if fi == 0 else H
        parts.append(kit.ceiling(T / 2, T / 2, iw, idp, zz, boards=True))
        po = kit.posts(T / 2, T / 2, iw, idp, zf, zz - 0.24 - 0.38)
        if po:
            parts.append(po)
        if fi < len(s["floors"]) - 1:
            parts.append(kit.floor_planks(T / 2, T / 2, iw, idp, zz + 0.09))
    bpy.context.view_layer.update()
    allm = kit.join(parts, hid)
    objs = split_nocol(allm)
    if soft:
        objs.append(kit.join(soft, hid + "_steps_nocol"))
    if colonly:
        objs.append(kit.join(colonly, hid + "_ramp_colonly"))
    for o in objs:
        o.data.transform(Matrix.Translation((-W / 2, -D / 2, 0)))
    return objs, (W, D, ztop + rise)

def split_nocol(ob):
    """玻璃 / 植物 / 发光材质拆成 *_nocol 对象（游戏端不生成碰撞）。"""
    me = ob.data
    soft = [i for i, m in enumerate(me.materials) if m and ("glass" in m.name or "|8|" in m.name or "glow" in m.name)]
    if not soft:
        return [ob]
    bm = bmesh.new(); bm.from_mesh(me)
    bm2 = bm.copy()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in soft], context="FACES")
    bmesh.ops.delete(bm2, geom=[f for f in bm2.faces if f.material_index not in soft], context="FACES")
    for b in (bm, bm2):
        bmesh.ops.recalc_face_normals(b, faces=b.faces)
    me2 = me.copy()
    bm.to_mesh(me); bm2.to_mesh(me2); bm.free(); bm2.free()
    o2 = kit.new_obj(ob.name + "_detail_nocol", me2, [])
    o2["methods"] = ob["methods"]
    return [ob, o2]

def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=True, export_yup=True, export_format="GLB", export_image_format="NONE")

def render(path, size):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
    scn.render.resolution_x, scn.render.resolution_y = 1400, 1000
    w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = (0.75, 0.8, 0.88, 1); bg.inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(sun)
    sun.data.energy = 3.2; sun.rotation_euler = (math.radians(50), math.radians(-20), math.radians(-35))
    gnd = bpy.data.meshes.new("g"); bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=40); bm.to_mesh(gnd); bm.free()
    g = bpy.data.objects.new("ground", gnd); scn.collection.objects.link(g)
    gm = bpy.data.materials.new("gm"); gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.32, 0.45, 0.22, 1)
    gnd.materials.append(gm)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    W, D, Ht = size
    r = max(W, D, Ht) * 1.9 + 6
    cam.location = (-r * 0.62, -r * 0.85, r * 0.55)
    cam.rotation_euler = (Vector((0, 0, Ht * 0.4)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 50
    fig = kit.box("human_1_75m", 0.45, 0.3, 1.75, (W / 2 * 0.0 - 1.6, -D / 2 - 2.2, 0), "K|7|c03030||0")
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    # 背面视角（检查穿插）
    cam.location = (r * 0.62, r * 0.85, r * 0.5)
    cam.rotation_euler = (Vector((0, 0, Ht * 0.4)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = path.replace(".png", "_back.png")
    bpy.ops.render.render(write_still=True)

def method_report(objs):
    return sorted(set(m for o in objs for m in o.get("methods", "").split(",") if m))

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    only = set(args[0].split(",")) if args else set(HOUSES) | set(PROPS)
    report = {}
    for hid in list(HOUSES) + list(PROPS):
        if hid not in only:
            continue
        clear()
        if hid in HOUSES:
            objs, size = house(hid, HOUSES[hid])
        else:
            fn, size = PROPS[hid]
            ob = fn()
            ob.name = hid
            objs = split_nocol(ob)
            for o in objs:
                o.name = o.name  # keep
        tris = 0
        for o in objs:
            o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
        export(objs, os.path.join(OUT, hid + ".glb"))
        report[hid] = {"size_m": [round(v, 2) for v in size], "tris": tris, "methods": method_report(objs)}
        render(os.path.join(DOC, hid + ".png"), size)
        print("BUILT", hid, report[hid], flush=True)
    old = {}
    rp = os.path.join(DOC, "report.json")
    if os.path.exists(rp):
        old = json.load(open(rp, encoding="utf-8"))
    old.update(report)
    json.dump(old, open(rp, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print("MODKIT_DONE", len(report))
