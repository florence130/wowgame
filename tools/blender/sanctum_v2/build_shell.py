# 海神旧圣堂 v2 —— 建筑外壳（地面 / 墙 / 天花拱顶 / 屋顶 / 地下山体）。
# 从 tools/sanctum_v2/layout.py + fields.py 的 2D 场直接生成，没有任何手摆坐标。
# Run: blender -b --factory-startup --python tools/blender/sanctum_v2/build_shell.py -- <out_dir>
# 材质名约定见 src/core/util.gd::kit_mat：K|<mtype>|<RRGGBB>|<贴图>|<每张米数>（mtype 0灰泥 2石块 3石板瓦 6木 9石饰）
# 碰撞：网格名含 "colonly" 的只做碰撞不渲染；其它网格由 ModelProp._apply_kit 按网格生成碰撞（glass/ivy/nocol/flower 除外）
import bpy, bmesh, sys, os, math, json
import numpy as np
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.normpath(os.path.join(HERE, "..", "..", "sanctum_v2")))
import layout as L, fields as F, geo2d as G, sanctum_data as D

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "models", "sanctum_v2"))
os.makedirs(OUT, exist_ok=True)

# ---- 材质（与晨钟修道院同一套：奶白石砖墙 / 蓝灰板岩顶 / 深棕木 / 黑铁）
MAT = {
    "wall": "K|2|e2d6bc|pt_ashlar|3.2",       # 奶白方石墙
    "trim": "K|9|efe5cf|pt_limestone|4.0",    # 石饰：柱 / 拱 / 压顶
    "floor": "K|2|c8bfae|pt_ashlar|3.0",      # 地砖
    "floor_dk": "K|2|a89c86|pt_rubble|3.0",   # 地窖 / 洞窟地面
    "roof": "K|3|4c5a78|pt_roof_slate|2.6",   # 蓝灰石板瓦
    "eave": "K|6|4e3220|pt_wood|2.2",         # 深棕檐板
    "vault": "K|2|b8aa8e|pt_ashlar|3.0",      # 拱顶内面
    "rock": "K|2|8a8678|pt_rubble|4.0",       # 岩壁
    "grass": "K|8|6aa448|pt_foliage|3.0",
    "wood": "K|6|7a5234|pt_wood|2.2",
    "iron": "K|7|2e2e34||0",
    "water": "K|glass|5ab0c8||0",
}
_mats = {}


def material(key):
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(MAT[key])
    m.use_nodes = True
    hexv = MAT[key].split("|")[2] if MAT[key].count("|") >= 2 and MAT[key].split("|")[2] else "888888"
    c = tuple((int(hexv[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4))
    b = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*c, 1.0)
    m.diffuse_color = (*c, 1.0)
    _mats[key] = m
    return m


class Mesh:
    """按材质分桶累积顶点 / 面，最后建 Blender 对象。坐标系：x 东、y 南(=Godot +z)、z 上；导出 glTF 时 Y-up 自动转换。"""

    def __init__(self, name):
        self.name = name
        self.buckets = {}

    def bucket(self, mat):
        return self.buckets.setdefault(mat, ([], []))

    def tri(self, mat, a, b, c):
        v, f = self.bucket(mat)
        i = len(v)
        v.extend([a, b, c])
        f.append((i, i + 1, i + 2))

    def quad(self, mat, a, b, c, d):
        v, f = self.bucket(mat)
        i = len(v)
        v.extend([a, b, c, d])
        f.append((i, i + 1, i + 2, i + 3))

    def build(self, parent=None):
        objs = []
        for mat, (v, f) in self.buckets.items():
            if not f:
                continue
            me = bpy.data.meshes.new(self.name)
            # glTF Y-up 导出：Godot z = -Blender y。布局的 y（南）要对应 Godot +z，所以这里写入 -y。
            # 镜像会翻转"数值叉积"的法线方向；各 quad 的顶点顺序已按镜像后的结果写好（地面 / 屋面朝上，天花朝下，
            # 墙内立面朝向空间内部），因此这里不能再反转绕序。
            v = [(p[0], -p[1], p[2]) for p in v]
            me.from_pydata(v, [], f)
            me.update()
            me.validate()
            ob = bpy.data.objects.new(self.name if len(self.buckets) == 1 else "%s_%s" % (self.name, mat), me)
            bpy.context.collection.objects.link(ob)
            me.materials.append(material(mat))
            for p in me.polygons:
                p.use_smooth = False
            objs.append(ob)
        return objs


def to_xyz(x, y, z):
    return (float(x), float(y), float(z))


# ---------------------------------------------------------------- 场 / 轮廓
S = F.build(1.0)
print("grid", S["f"].shape)
loops = G.march(S["f"], S["xs"], S["ys"])
groups = G.classify(loops)
print("outlines", len(groups), "holes", sum(len(h) for o, h in groups))


def ground_height(x, y):
    return F.height_at(x, y)


def elem_at(x, y):
    sd, idx, h = F.sample(S, x, y)
    return F.ELEMS[int(idx)]


# ---------------------------------------------------------------- 地面
def build_floor():
    """地面 = 全部 SDF 内部的三角化。用 1m 网格直接取内部格子，再按元素给材质（保证与高度函数完全一致）。"""
    cs = 1.0
    xs, ys, f, idx = S["xs"], S["ys"], S["f"], S["idx"]
    m = Mesh("floor")
    col = Mesh("floor_colonly")
    ny, nx = f.shape

    def hv(i, j):
        return float(S["H"][j, i])

    for j in range(ny - 1):
        for i in range(nx - 1):
            if not (f[j, i] < 0.2 and f[j, i + 1] < 0.2 and f[j + 1, i + 1] < 0.2 and f[j + 1, i] < 0.2):
                continue
            e = F.ELEMS[int(idx[j, i])]
            mat = "floor_dk" if e["style"] in F.UNDERGROUND else "floor"
            a = to_xyz(xs[i], ys[j], hv(i, j))
            b = to_xyz(xs[i + 1], ys[j], hv(i + 1, j))
            c = to_xyz(xs[i + 1], ys[j + 1], hv(i + 1, j + 1))
            d = to_xyz(xs[i], ys[j + 1], hv(i, j + 1))
            m.quad(mat, a, d, c, b)       # 顶面朝上（Blender z 向上，逆时针）
    return m


# ---------------------------------------------------------------- 墙
def wall_height(e):
    return e["wall"]


def build_walls():
    """沿每条轮廓挤出墙：墙高 = 该点所属空间的 wall；墙底 = 地面高度 - 0.4（埋进地里）；
    封闭空间的墙顶 = 起拱高度，上方再接拱顶 / 屋顶。"""
    walls = Mesh("walls")
    caps = Mesh("wall_caps")
    guard = Mesh("walls_colonly")
    for outer, holes in groups:
        for loop, is_hole in [(outer, False)] + [(h, True) for h in holes]:
            pts = G.simplify_loop(loop, 0.30)
            n = len(pts)
            for k in range(n):
                a, b = pts[k], pts[(k + 1) % n]
                mid = (a + b) / 2
                # 取墙内侧一点以确定所属空间 / 高度（内部在左侧）
                dx, dy = b[0] - a[0], b[1] - a[1]
                ln = math.hypot(dx, dy)
                if ln < 1e-6:
                    continue
                nx_, ny_ = -dy / ln, dx / ln
                inx, iny = mid[0] + nx_ * 0.8, mid[1] + ny_ * 0.8
                e = elem_at(inx, iny)
                ya = F.height_at(a[0], a[1])
                yb = F.height_at(b[0], b[1])
                top = e["wall"]
                if "cliff" == e["style"] or e["style"] == "quay":
                    mat_w = "trim"
                else:
                    mat_w = "wall"
                # 向外挤出厚度
                t = L.WALL_T
                ox, oy = -nx_ * t, -ny_ * t
                za, zb = ya - 3.0, yb - 3.0
                A0, B0 = (a[0], a[1], za), (b[0], b[1], zb)
                A1, B1 = (a[0], a[1], ya + top), (b[0], b[1], yb + top)
                A2, B2 = (a[0] + ox, a[1] + oy, ya + top), (b[0] + ox, b[1] + oy, yb + top)
                A3, B3 = (a[0] + ox, a[1] + oy, za), (b[0] + ox, b[1] + oy, zb)
                # 内立面（朝空间内部，法线 = 左侧）
                walls.quad(mat_w, A0, B0, B1, A1)
                # 外立面
                walls.quad("rock" if e["style"] in F.UNDERGROUND or e["style"] in ("cave",) else "wall", B3, A3, A2, B2)
                # 墙顶
                caps.quad("trim", A1, B1, B2, A2)
                if e["base"] is None:      # 露天空间：低护栏之上再立一道隐形高墙，防止跳出去
                    G1, H1 = (a[0], a[1], ya + 9.0), (b[0], b[1], yb + 9.0)
                    guard.quad("wall", A0, B0, H1, G1)
    return walls, caps, guard


# ---------------------------------------------------------------- 拱顶与屋顶
def build_roofs():
    """封闭空间的天花 / 屋顶：对每个 1m 网格内部格子，若所属元素 enc，就在 base + 拱曲面 处放一块顶（单面向下的天花 + 向上的屋面）。
    拱曲面：沿垂直于「到墙的最近距离」的方向抬高 → 简单用到边界的距离 d 做：z = base + rise * (1 - (clamp(d/dv,0,1)-1)^2)。
    屋面材质：地上 = 蓝灰板岩（盖在天花上方 0.5m），地下 = 不出屋面（山体盖住）。"""
    xs, ys, f, idx = S["xs"], S["ys"], S["f"], S["idx"]
    ceil = Mesh("ceiling")
    roof = Mesh("roof")
    ny, nx = f.shape
    # 先算每个格点的天花高度
    Z = np.full(f.shape, np.nan)
    for j in range(ny):
        for i in range(nx):
            if f[j, i] < 0.2:
                e = F.ELEMS[int(idx[j, i])]
                if e["enc"] > 0:
                    d = max(-f[j, i], 0.0)
                    u = min(d / max(e["dv"], 1e-6), 1.0)
                    arch = e["rise"] * (1.0 - (1.0 - u) ** 2)
                    Z[j, i] = S["H"][j, i] + e["base"] + arch
    for j in range(ny - 1):
        for i in range(nx - 1):
            z4 = [Z[j, i], Z[j, i + 1], Z[j + 1, i + 1], Z[j + 1, i]]
            if any(np.isnan(z) for z in z4):
                continue
            e = F.ELEMS[int(idx[j, i])]
            a = to_xyz(xs[i], ys[j], z4[0]); b = to_xyz(xs[i + 1], ys[j], z4[1])
            c = to_xyz(xs[i + 1], ys[j + 1], z4[2]); d = to_xyz(xs[i], ys[j + 1], z4[3])
            ceil.quad("vault", a, b, c, d)      # 朝下
            if not e["ug"]:
                up = 0.55
                a2, b2, c2, d2 = [(p[0], p[1], p[2] + up) for p in (a, b, c, d)]
                roof.quad("roof", a2, d2, c2, b2)  # 朝上
    return ceil, roof


def build_rock():
    """地下空间上方的山体顶面：地形网格负责外部，这里只在地下元素之上补一层厚盖（防止天空透出）。"""
    xs, ys, f, idx = S["xs"], S["ys"], S["f"], S["idx"]
    m = Mesh("rock_cover")
    ny, nx = f.shape
    for j in range(ny - 1):
        for i in range(nx - 1):
            cells = [(i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1)]
            ok = True
            zs = []
            for (ci, cj) in cells:
                if f[cj, ci] >= 0.2:
                    ok = False
                    break
                e = F.ELEMS[int(idx[cj, ci])]
                if not e["ug"]:
                    ok = False
                    break
                d = max(-f[cj, ci], 0.0)
                u = min(d / max(e["dv"], 1e-6), 1.0)
                zs.append(S["H"][cj, ci] + e["base"] + e["rise"] * (1.0 - (1.0 - u) ** 2) + 1.2)
            if not ok:
                continue
            a = to_xyz(xs[i], ys[j], zs[0]); b = to_xyz(xs[i + 1], ys[j], zs[1])
            c = to_xyz(xs[i + 1], ys[j + 1], zs[2]); d = to_xyz(xs[i], ys[j + 1], zs[3])
            m.quad("rock", a, d, c, b)
    return m


# ---------------------------------------------------------------- 输出
def check_normals(objs):
    """自检法线朝向（Blender 坐标：z 向上）。floor/roof 应朝上，ceiling 应朝下，墙内立面应朝向空间内部。"""
    import mathutils
    out = {}
    for ob in objs:
        base = ob.name.split(".")[0]
        up = down = inward = outward = 0
        for p in ob.data.polygons:
            n = p.normal
            c = p.center
            if base.startswith("floor") or base.startswith("roof"):
                up += n.z > 0.5
                down += n.z < -0.5
            elif base.startswith("ceiling"):
                up += n.z > 0.5
                down += n.z < -0.5
            elif base.startswith("walls") and "colonly" not in base:
                # 内立面：沿法线走 0.6m 应落在空间内部；外立面则相反
                x, y = c.x, -c.y     # 回到布局坐标
                sd_in = F.min_sdf(np.array([[x + n.x * 0.6]]), np.array([[y - n.y * 0.6]]))[0, 0]
                if abs(n.z) < 0.3:
                    inward += sd_in < 0
                    outward += sd_in >= 0
        out[ob.name] = dict(up=up, down=down, inward=inward, outward=outward)
    for k, v in out.items():
        print("NORMALS", k, v)


def export_all():
    parts = []
    floor = build_floor()
    parts += floor.build()
    walls, caps, guard = build_walls()
    parts += walls.build() + caps.build() + guard.build()
    ceil, roof = build_roofs()
    parts += ceil.build() + roof.build()
    parts += build_rock().build()
    check_normals(parts)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    path = os.path.join(OUT, "sanctum_shell.glb")
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_apply=True, export_yup=True)
    print("EXPORTED", path, os.path.getsize(path) // 1024, "KB;", sum(len(o.data.polygons) for o in parts), "faces")


if __name__ == "__main__":
    export_all()
    data = D.build()
    T, meta = F.terrain_heights()
    T.astype("<f4").tofile(os.path.join(OUT, "terrain.f32"))
    data["terrain"] = meta
    data["enclosed"] = F.enclosed_mask()
    data["trees"] = D.scatter_trees(T, meta)
    with open(os.path.join(OUT, "sanctum_data.json"), "w", encoding="utf-8") as fh:
        json.dump(data, fh, ensure_ascii=False, indent=1)
    print("DATA", D.stats(data))
