# city_kit 构建：逐件导出 assets/models/city_kit/<id>.glb、渲染缩略图 docs/city_kit/<id>.png、写 manifest.json；
# 再用这些构件拼出 3 栋示范建筑（demo_*），验证“快速搭建重复立面 / 造型 / 屋顶”。
# "E:\FF导出\BlenderPortable\blender-4.5.10-windows-x64\blender.exe" -b -P tools/blender/city_kit/build.py -- [id1,id2|demos|pieces]
import bpy, bmesh, math, os, sys, json, importlib
from mathutils import Matrix, Vector
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, "..", "modkit"))
import kit, city_kit as ck
importlib.reload(kit); importlib.reload(ck)
from city_kit import BAY, GF, FH, T

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "city_kit")
DOC = os.path.join(ROOT, "docs", "city_kit")
os.makedirs(OUT, exist_ok=True); os.makedirs(DOC, exist_ok=True)

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit.COL = None

def split_nocol(ob):
    """玻璃 / 植物 / 发光拆成 *_nocol（游戏端不生成碰撞），与 modkit 相同规则。"""
    me = ob.data
    soft = [i for i, m in enumerate(me.materials) if m and ("glass" in m.name or "|8|" in m.name or "glow" in m.name)]
    if not soft or len(soft) == len(me.materials):
        if soft:
            ob.name = ob.name + "_nocol"
        return [ob]
    bm = bmesh.new(); bm.from_mesh(me); bm2 = bm.copy()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in soft], context="FACES")
    bmesh.ops.delete(bm2, geom=[f for f in bm2.faces if f.material_index not in soft], context="FACES")
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

def bounds(objs):
    bpy.context.view_layer.update()
    mn, mx = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    return mn, mx

_rig = {}
def render(path, objs, res=(720, 540)):
    scn = bpy.context.scene
    eng = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scn.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in eng else "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.render.film_transparent = False
    w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = (0.78, 0.83, 0.9, 1); bg.inputs[1].default_value = 0.85
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(sun)
    sun.data.energy = 3.4; sun.rotation_euler = (math.radians(52), math.radians(-18), math.radians(-38))
    mn, mx = bounds(objs)
    ctr = (mn + mx) / 2
    size = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z, 2.0)
    gm = bpy.data.materials.new("gnd"); gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.55, 0.53, 0.5, 1)
    me = bpy.data.meshes.new("g"); bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size * 3); bm.to_mesh(me); bm.free(); me.materials.append(gm)
    g = bpy.data.objects.new("ground", me); scn.collection.objects.link(g); g.location.z = min(mn.z, 0) - 0.01
    fig = kit.box("human_1_75m", 0.45, 0.3, 1.75, (mn.x - 1.0, mn.y - 1.2, 0), "K|7|c03030||0")   # 1.75m 人形比例尺
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    cam.data.lens = 50
    d = size * 1.75 + 2.5
    cam.location = ctr + Vector((-d * 0.55, -d * 0.85, d * 0.42))
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in (fig, g, cam, sun):
        bpy.data.objects.remove(o)

def methods_of(objs):
    return sorted(set(m for o in objs for m in o.get("methods", "").split(",") if m))

def tris_of(objs):
    t = 0
    for o in objs:
        o.data.calc_loop_triangles(); t += len(o.data.loop_triangles)
    return t

# ------------------------------------------------------------------ 示范建筑：只用构件拼装
def P(fn, xf):
    """构件放置：先建构件，再左乘变换。"""
    o = fn()
    bpy.context.view_layer.update()
    o.matrix_world = xf @ o.matrix_world
    return o

def facade_xf(side, i, W, D, z):
    """与 modkit.side_xf 相同的四面放置：front 沿 +X、外立面 -Y；back / left / right 依次旋转。"""
    if side == "front":
        return Matrix.Translation((i * BAY, 0, z))
    if side == "back":
        return Matrix.Translation(((i + 1) * BAY, D, z)) @ Matrix.Rotation(math.pi, 4, "Z")
    if side == "left":
        return Matrix.Translation((0, (i + 1) * BAY, z)) @ Matrix.Rotation(-math.pi / 2, 4, "Z")
    return Matrix.Translation((W, i * BAY, z)) @ Matrix.Rotation(math.pi / 2, 4, "Z")

def block(nx, ny, floors, gf_pattern, uf_pattern, roof="slate", dormers="pedi", turret=False, wall="brick", balc_floor=1):
    """通用街区楼：nx×ny 开间，floors 个标准层。gf_pattern(side,i,n) / uf_pattern(side,i,n,floor) 返回构件构造函数。"""
    W, D = nx * BAY, ny * BAY
    parts = []
    sides = {"front": nx, "right": ny, "back": nx, "left": ny}
    for side, n in sides.items():
        for i in range(n):
            parts.append(P(gf_pattern(side, i, n), facade_xf(side, i, W, D, 0)))
            for f in range(floors):
                z = GF + f * FH
                parts.append(P(uf_pattern(side, i, n, f), facade_xf(side, i, W, D, z)))
                parts.append(P(lambda: ck.band(BAY), facade_xf(side, i, W, D, z - 0.16)))
            zt = GF + floors * FH
            parts.append(P(lambda: ck.cornice(BAY), facade_xf(side, i, W, D, zt - 0.86)))
            m = ck.mansard if roof != "flat" else None
            if m:
                dm = dormers if (i % 2 == (n % 2 == 0 and 1 or 0) or n <= 2) else None
                parts.append(P(lambda dm=dm: ck.mansard(BAY, dm, roof), facade_xf(side, i, W, D, zt)))
    # 转角：隅石（每层）+ 可选圆角楼
    zt = GF + floors * FH
    for (x, y) in ((0, 0), (W, 0), (0, D), (W, D)):
        for f in range(floors):
            parts.append(P(lambda: ck.quoins(FH), Matrix.Translation((x, y, GF + f * FH))))
    if turret:
        for f in range(floors):
            parts.append(P(lambda: ck.turret_body(), Matrix.Translation((0, 0, GF + f * FH))))
        parts.append(P(lambda: ck.turret_cone(), Matrix.Translation((0, 0, zt))))
    # 屋顶平顶（锌皮）+ 烟囱
    parts.append(kit.box("roof_top", W - 2.2, D - 2.2, 0.2, (W / 2, D / 2, zt + 4.3), ck.M["zinc"]))
    for k, (fx, fy) in enumerate(((0.3, 0.5), (0.72, 0.5))):
        parts.append(P(lambda: ck.chimney_stack(), Matrix.Translation((W * fx, D * fy, zt + 4.4))))
    return parts, (W, D)

def demo_haussmann():
    """视频里最常见的转角公寓：底层拱券 + 商铺交替，三层红砖（二层阳台、三层三角山花、四层弧形山花），
    檐口 + 芒萨尔老虎窗，转角圆角楼尖顶。"""
    def gf(side, i, n):
        if side == "front" and i == n // 2:
            return lambda: ck.gf_arch("door")
        return (lambda: ck.gf_shop(True)) if (i % 2 == 0 and side in ("front", "left")) else (lambda: ck.gf_arch("window"))
    def uf(side, i, n, f):
        st = ("balc", "pedi", "seg")[f % 3]
        return lambda: ck.uf_window(st, "brick")
    parts, (W, D) = block(5, 3, 3, gf, uf, "slate", "pedi", turret=True)
    for i in range(5):
        parts.append(P(lambda: ck.wall_lamp(), facade_xf("front", i, W, D, 3.2) @ Matrix.Translation((0.25, 0, 0))))
    return parts

def demo_cityhall():
    """第二帝国式市政厅（参考图 4）：中央亭（3 开间方石 + 双柱门廊 + 大山花 + 钟形亭顶 + 钟层），两翼 3 开间芒萨尔。"""
    parts = []
    # 两翼
    for wx in (0.0, 6 * BAY):
        def gf(side, i, n):
            return lambda: ck.gf_arch("window")
        def uf(side, i, n, f):
            return lambda: ck.uf_window("pedi" if f == 0 else "seg", "ashlar")
        ps, (W, D) = block(3, 3, 2, gf, uf, "slate", "oculus")
        for o in ps:
            o.matrix_world = Matrix.Translation((wx, 0, 0)) @ o.matrix_world
        parts += ps
    # 中央亭：前凸 2m，高一层
    cx0, ny = 3 * BAY, 3
    W, D = 3 * BAY, ny * BAY
    off = Matrix.Translation((cx0, -2.0, 0))
    for i in range(3):
        parts.append(P(lambda i=i: ck.gf_arch("door" if i == 1 else "open"), off @ facade_xf("front", i, W, D, 0)))
        for f in range(3):
            parts.append(P(lambda: ck.uf_window("balc" if f == 0 else "pedi", "ashlar"), off @ facade_xf("front", i, W, D, GF + f * FH)))
        parts.append(P(lambda: ck.portico(BAY, GF + FH), off @ facade_xf("front", i, W, D, 0)))
    zt = GF + 3 * FH
    for side in ("left", "right", "back"):
        for i in range(ny):
            for f in range(3):
                parts.append(P(lambda: ck.uf_solid("ashlar"), off @ facade_xf(side, i, W, D, GF + f * FH)))
            parts.append(P(lambda: ck.gf_solid(), off @ facade_xf(side, i, W, D, 0)))
    for i in range(3):
        parts.append(P(lambda: ck.cornice(BAY), off @ facade_xf("front", i, W, D, zt - 0.86)))
        parts.append(P(lambda: ck.balustrade(BAY), off @ facade_xf("front", i, W, D, zt)))
    parts.append(P(lambda: ck.temple_pediment(3 * BAY), off @ Matrix.Translation((0, -1.4, GF + FH + 0.0))))
    parts.append(P(lambda: ck.pavilion_roof(W - 0.4, 8.0), off @ Matrix.Translation((W / 2, D / 2, zt))))
    parts.append(P(lambda: ck.clock_stage(5.0, 5.0), off @ Matrix.Translation((W / 2, D / 2, zt + 8.2))))
    parts.append(P(lambda: ck.turret_cone(2.4, 6.0, "copper"), off @ Matrix.Translation((W / 2, D / 2, zt + 13.2))))
    return parts

def demo_trade_row():
    """千泉城商业街（参考图 2）：5 栋窄面宽商铺连排，青铜芒萨尔与青铜亭顶交替，灰泥 / 方石墙。"""
    parts = []
    for k in range(5):
        wall = "stucco" if k % 2 == 0 else "ashlar"
        def gf(side, i, n):
            return (lambda: ck.gf_shop(True)) if side == "front" else (lambda: ck.gf_solid())
        def uf(side, i, n, f, wall=wall, k=k):
            if side != "front":
                return lambda: ck.uf_solid(wall)
            return lambda: ck.uf_window(("balc", "plain")[f % 2] if k % 2 else ("pedi", "balc")[f % 2], wall)
        ps, (W, D) = block(2, 3, 2 + (k % 2), gf, uf, "copper", "oculus")
        for o in ps:
            o.matrix_world = Matrix.Translation((k * 2 * BAY, 0, 0)) @ o.matrix_world
        parts += ps
        if k % 2 == 0:
            zt = GF + (2 + k % 2) * FH
            parts.append(P(lambda: ck.pavilion_roof(2 * BAY - 0.6, 6.0, "copper"), Matrix.Translation((k * 2 * BAY + BAY, D / 2, zt + 4.3))))
    return parts

DEMOS = {"demo_haussmann_corner": demo_haussmann, "demo_cityhall": demo_cityhall, "demo_trade_row": demo_trade_row}

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    cat = ck.catalog()
    sel = args[0] if args else "all"
    ids = list(cat) if sel in ("all", "pieces") else [] if sel == "demos" else sel.split(",")
    if sel in ("all", "demos"):
        ids += list(DEMOS)
    mp = os.path.join(OUT, "manifest.json")
    man = json.load(open(mp, encoding="utf-8")) if os.path.exists(mp) else {"version": 1, "grid": {}, "pieces": {}}
    man["grid"] = {"bay_m": BAY, "ground_floor_m": GF, "floor_m": FH, "wall_m": T,
                   "axes": "glTF/Godot：沿 +X 展开 0..bay，外立面朝 +Z，Y 向上；原点在左下角墙中心线（塔 / 穹顶 / 亭顶 / 钟层原点在底面中心）",
                   "materials": "K|mtype|RRGGBB|细节贴图|米 → U.kit_mat（ModelProp 自动替换）；*_nocol 子网格不生成碰撞"}
    for cid in ids:
        clear()
        if cid in DEMOS:
            parts = DEMOS[cid]()
            ob = kit.join(parts, cid)
            cat_name, note = "示范建筑", DEMOS[cid].__doc__.strip().split("\n")[0]
        else:
            fn, cat_name, note = cat[cid]
            ob = fn()
        ob.name = cid
        objs = split_nocol(ob)
        mn, mx = bounds(objs)
        export(objs, os.path.join(OUT, cid + ".glb"))
        render(os.path.join(DOC, cid + ".png"), objs, (960, 720) if cid in DEMOS else (720, 540))
        man["pieces"][cid] = {"category": cat_name, "note": note, "size_m": [round(mx.x - mn.x, 2), round(mx.y - mn.y, 2), round(mx.z - mn.z, 2)],
                              "min_m": [round(v, 2) for v in mn], "tris": tris_of(objs), "methods": methods_of(objs)}
        print("BUILT", cid, man["pieces"][cid]["size_m"], man["pieces"][cid]["tris"], ",".join(man["pieces"][cid]["methods"]), flush=True)
    json.dump(man, open(mp, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print("CITY_KIT_DONE", len(ids))
