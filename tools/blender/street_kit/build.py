# street_kit 构建：逐件导出 assets/models/street_kit/<id>.glb、渲染缩略图 docs/street_kit/<id>.png、写 manifest.json；再拼 3 栋示范楼。
# "E:\FF导出\BlenderPortable\blender-4.5.10-windows-x64\blender.exe" -b -P tools/blender/street_kit/build.py -- [all|pieces|demos|id1,id2]
import bpy, bmesh, math, os, sys, json, importlib
from mathutils import Matrix, Vector
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, "..", "modkit"))
import kit, street_kit as sk
importlib.reload(kit); importlib.reload(sk)
from street_kit import BAY, GF, FH, DN, RN

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "street_kit")
DOC = os.path.join(ROOT, "docs", "street_kit")
os.makedirs(OUT, exist_ok=True); os.makedirs(DOC, exist_ok=True)

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit.COL = None
    kit.mat = sk.sk_mat

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

def render(path, objs, res=(720, 540), view="front"):
    scn = bpy.context.scene
    eng = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scn.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in eng else "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = res
    w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = (0.78, 0.83, 0.9, 1); bg.inputs[1].default_value = 0.85
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(sun)
    sun.data.energy = 3.2; sun.rotation_euler = (math.radians(50), math.radians(-12), math.radians(-30))
    mn, mx = bounds(objs)
    ctr = (mn + mx) / 2
    size = max(mx.x - mn.x, mx.y - mn.y, mx.z - mn.z, 2.0)
    gm = bpy.data.materials.new("gnd"); gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.5, 0.48, 0.44, 1)
    me = bpy.data.meshes.new("g"); bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=size * 3); bm.to_mesh(me); bm.free(); me.materials.append(gm)
    g = bpy.data.objects.new("ground", me); scn.collection.objects.link(g); g.location.z = min(mn.z, 0) - 0.01
    fig = kit.box("human_1_75m", 0.45, 0.3, 1.75, (mn.x - 1.0, mn.y - 1.2, 0), "K|7|c03030||0")
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    cam.data.lens = 50
    d = size * 1.7 + 2.5
    if view == "front":
        cam.location = ctr + Vector((-d * 0.35, -d * 0.95, d * 0.3))
    else:
        cam.location = ctr + Vector((-d * 0.6, -d * 0.8, d * 0.45))
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

# ------------------------------------------------------------------ 示范楼：只用构件拼装（与游戏端 tools/city_plan_v6/src/kitlots.js 同一套摆法）
def P(fn, xf):
    o = fn()
    bpy.context.view_layer.update()
    o.matrix_world = xf @ o.matrix_world
    return o

def T_(x, y, z): return Matrix.Translation((x, y, z))
def Rz(a): return Matrix.Rotation(a, 4, "Z")
def S_(sx, sy, sz): return Matrix.Diagonal((sx, sy, sz, 1))

def demo_house(nx=5, depth=14.0, floors=3, style="half", roof="gable"):
    """沿街楼：前墙 nx 开间（底层商铺 / 拱窗交替，上层木筋 / 灰泥 / 红砖），双坡屋顶 + 山墙 + 老虎窗 + 烟囱；左右后墙用侧墙构件。"""
    W = nx * BAY
    parts = []
    bw = BAY
    uf = {"half": sk.uf_half, "plain": sk.uf_plain, "brick": sk.uf_brick}[style]
    for i in range(nx):
        gf = sk.gf_door if i == nx // 2 else (sk.gf_shop if i % 2 == 0 else sk.gf_arch)
        parts.append(P(gf, T_(i * bw, 0, 0)))
        for f in range(floors - 1):
            z = GF + f * FH
            parts.append(P(sk.band, T_(i * bw, 0, z - 0.1)))
            parts.append(P(sk.uf_balc if (f == 0 and i % 2 == 1 and style != "half") else uf, T_(i * bw, 0, z)))
    top = GF + (floors - 1) * FH
    parts.append(P(sk.eave, T_(0, 0, top - 0.4)))
    for i in range(1, nx):
        parts.append(P(sk.eave, T_(i * bw, 0, top - 0.4)))
    # 右 / 左 / 后墙（简化：侧墙 depth/BAY 开间）
    nz = max(2, round(depth / BAY))
    sbw = depth / nz
    for side, xf in (("L", lambda j: T_(0, (j + 1) * sbw, 0) @ Rz(-math.pi / 2)), ("R", lambda j: T_(W, j * sbw, 0) @ Rz(math.pi / 2)), ("B", lambda j: T_(W - j * bw, depth, 0) @ Rz(math.pi))):
        n = nz if side != "B" else nx
        for j in range(n):
            m = xf(j) @ (S_(sbw / BAY if side != "B" else 1, 1, 1))
            parts.append(P(sk.gf_solid, m))
            for f in range(floors - 1):
                parts.append(P(sk.uf_side if (j + f) % 2 == 0 else sk.uf_blank, xf(j) @ T_(0, 0, GF + f * FH) @ S_(sbw / BAY if side != "B" else 1, 1, 1)))
    # 屋顶：双坡（屋脊沿 X），Y/Z 按进深缩放；山墙两端
    s = depth / DN
    for i in range(nx):
        parts.append(P(sk.roof_gable, T_(i * bw, 0, top) @ S_(1, s, s)))
    parts.append(P(sk.gable_end, T_(0, 0, top) @ S_(1, s, s)))
    parts.append(P(sk.gable_end, T_(W, depth, top) @ Rz(math.pi) @ S_(1, s, s)))
    for i in range(1, nx, 2):
        zz = RN * s * 0.0
        # 前坡：屋面在 y=d 处高度 = (y - yf)/(DN/2 - yf) * RN；老虎窗放在 y=2.4*s 处
        y = 2.6 * s
        z = (y + 0.6 * s) / (DN / 2 + 0.6) * RN * s * 1.0 - 0.55 * s
        parts.append(P(sk.dormer, T_(i * bw + bw / 2, y, top + z - 0.1)))
    parts.append(P(sk.chimney, T_(W * 0.7, depth * 0.5, top + RN * s - 0.9)))
    return parts

def demo_mansard(nx=5, depth=14.0, floors=3):
    W = nx * BAY
    parts = []
    for i in range(nx):
        parts.append(P(sk.gf_shop if i % 2 == 0 else sk.gf_arch, T_(i * BAY, 0, 0)))
        for f in range(floors - 1):
            z = GF + f * FH
            parts.append(P(sk.band, T_(i * BAY, 0, z - 0.1)))
            parts.append(P(sk.uf_balc if f == 0 else sk.uf_brick, T_(i * BAY, 0, z)))
    top = GF + (floors - 1) * FH
    for i in range(nx):
        parts.append(P(sk.eave, T_(i * BAY, 0, top - 0.4)))
        fn = (lambda: sk.skirt_end('mansard', 'L', 90)) if i == 0 else (lambda: sk.skirt_end('mansard', 'R', 90)) if i == nx - 1 else sk.mansard_bay
        parts.append(P(fn, T_(i * BAY, 0, top)))
        if i % 2 == 1:
            parts.append(P(sk.mansard_dormer, T_(i * BAY + BAY / 2, 0.15, top + 1.0)))
    return parts

DEMOS = {"demo_half_timber": lambda: demo_house(5, 14, 3, "half"), "demo_plaster_row": lambda: demo_house(4, 12, 3, "plain"), "demo_mansard_front": lambda: demo_mansard(5, 14, 3)}

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    cat = sk.catalog()
    sel = args[0] if args else "all"
    ids = list(cat) if sel in ("all", "pieces") else [] if sel == "demos" else sel.split(",")
    if sel in ("all", "demos"):
        ids += list(DEMOS)
    mp = os.path.join(OUT, "manifest.json")
    man = json.load(open(mp, encoding="utf-8")) if os.path.exists(mp) else {"version": 1, "grid": {}, "pieces": {}}
    man["grid"] = {"bay_m": BAY, "ground_floor_m": GF, "floor_m": FH, "gable_depth_m": DN, "gable_rise_m": round(RN, 3),
                   "axes": "glTF/Godot：沿 +X 展开 0..bay，外立面朝 +Z，Y 向上，进深为 -Z；原点在左下角墙中心线（屋面 / 山墙原点在墙顶）",
                   "materials": "S|槽|类型|贴图|米 = 实例着色槽；K|… 固定色；N|RRGGBB 窗格（夜间发光）"}
    for cid in ids:
        clear()
        if cid in DEMOS:
            parts = DEMOS[cid]()
            ob = kit.join(parts, cid)
            note = DEMOS[cid].__doc__.strip().split("\n")[0] if DEMOS[cid].__doc__ else "示范楼"
            cat_name = "示范建筑"
        else:
            fn, cat_name, note = cat[cid]
            ob = fn()
        ob.name = cid
        mn, mx = bounds([ob])
        export([ob], os.path.join(OUT, cid + ".glb"))
        render(os.path.join(DOC, cid + ".png"), [ob], (960, 720) if cid in DEMOS else (720, 540), "iso" if cid in DEMOS else "front")
        man["pieces"][cid] = {"category": cat_name, "note": note, "size_m": [round(mx.x - mn.x, 2), round(mx.y - mn.y, 2), round(mx.z - mn.z, 2)],
                              "min_m": [round(v, 2) for v in mn], "tris": tris_of([ob]), "methods": methods_of([ob])}
        print("BUILT", cid, man["pieces"][cid]["size_m"], man["pieces"][cid]["tris"], flush=True)
    json.dump(man, open(mp, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print("STREET_KIT_DONE", len(ids))
