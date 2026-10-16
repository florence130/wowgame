# 海神旧圣堂 v2 —— 由 layout.py 派生的标量场：并集 SDF、各处地面高度、风格、地形高度。
# 纯 numpy。Blender 建模 (tools/blender/sanctum_v2/build.py) 与 Godot 数据导出 (export_data.py) 共用。
import math
import numpy as np
import layout as L
import geo2d as G

STYLES = ["quay", "court", "arcade", "hall", "cellar", "cave", "cliff", "tower", "tunnel"]
# 风格参数：wall 墙高（含低矮护栏）、base 屋顶起拱高度（None = 无顶）、rise 拱顶矢高、ug 位于地下（上方盖山体）
STYLE_P = {
    "quay": dict(wall=1.1, base=None, rise=0.0, ug=False),
    "court": dict(wall=1.2, base=None, rise=0.0, ug=False),
    "arcade": dict(wall=1.1, base=4.6, rise=1.4, ug=False),
    "hall": dict(wall=6.0, base=6.0, rise=3.0, ug=False),
    "cellar": dict(wall=4.5, base=4.5, rise=2.5, ug=True),
    "cave": dict(wall=4.0, base=4.0, rise=3.5, ug=True),
    "tunnel": dict(wall=4.0, base=4.0, rise=1.5, ug=True),
    "cliff": dict(wall=1.1, base=None, rise=0.0, ug=False),
    "tower": dict(wall=1.2, base=None, rise=0.0, ug=False),
}
# 个别房间的覆盖（大型厅堂更高）
ROOM_P = {
    "nave": dict(wall=9.5, base=9.5, rise=6.5),
    "transept": dict(wall=7.0, base=7.0, rise=4.0),
    "granary": dict(wall=6.0, base=6.0, rise=3.5),
    "cistern": dict(wall=5.5, base=5.5, rise=3.0),
    "dock": dict(wall=5.0, base=5.0, rise=4.5),
}
ENCLOSED = {s for s, p in STYLE_P.items() if p["base"] is not None}
UNDERGROUND = {s for s, p in STYLE_P.items() if p["ug"]}

def _elements():
    els = []
    for s in L.MAIN:
        style = s["style"]
        if s["id"] in ("s4", "s8"):
            style = "tunnel"
        els.append(dict(id=s["id"], kind="poly", pts=s["pts"], half=L.CORR / 2, y0=s["y0"], y1=s["y1"], style=style, main=True))
    for s in L.SIDE:
        y = L.LEVEL_Y[s["level"]]
        els.append(dict(id=s["id"] + "_c", kind="poly", pts=s["pts"], half=L.SIDE_CORR / 2, y0=y, y1=y, style=s["style"], main=False))
        els.append(dict(id=s["id"], kind="rect", c=s["c"], size=s["size"], y0=y, y1=y, style=s["style"], main=False))
    for r in L.ROOMS:
        y = L.LEVEL_Y[r["level"]]
        e = dict(id=r["id"], y0=y, y1=y, style=r["style"], main=True)
        if "r" in r:
            e.update(kind="circle", c=r["c"], r=r["r"])
        else:
            e.update(kind="rect", c=r["c"], size=r["size"])
        els.append(e)
    for e in els:
        p = dict(STYLE_P[e["style"]])
        p.update(ROOM_P.get(e["id"], {}))
        e["wall"], e["base"], e["rise"], e["ug"] = p["wall"], p["base"], p["rise"], p["ug"]
        e["enc"] = 1.0 if p["base"] is not None else 0.0
        e["ceil"] = (p["base"] or 0.0) + p["rise"]
        if e["kind"] == "poly":
            e["dv"] = e["half"]
        elif e["kind"] == "circle":
            e["dv"] = min(e["r"] * 0.7, 14.0)
        else:
            e["dv"] = min(min(e["size"]) / 2 * 0.8, 14.0)
        if e["kind"] == "poly":
            seg = [math.dist(a, b) for a, b in zip(e["pts"], e["pts"][1:])]
            e["seglen"] = seg
            e["total"] = max(sum(seg), 1e-6)
            e["cum"] = [0.0] + list(np.cumsum(seg))
    return els


ELEMS = _elements()


def elem_sdf_h(e, px, py):
    """返回 (sdf, height)。poly 的高度沿路线线性插值（含端点外 clamp）。"""
    if e["kind"] == "circle":
        return G.circle_sdf(px, py, e["c"], e["r"]), np.full_like(px, e["y0"], dtype=float)
    if e["kind"] == "rect":
        return G.rect_sdf(px, py, e["c"], e["size"]), np.full_like(px, e["y0"], dtype=float)
    pts = e["pts"]
    best = None
    bs = None
    for k, (a, b) in enumerate(zip(pts, pts[1:])):
        abx, aby = b[0] - a[0], b[1] - a[1]
        l2 = max(abx * abx + aby * aby, 1e-9)
        t = np.clip(((px - a[0]) * abx + (py - a[1]) * aby) / l2, 0.0, 1.0)
        d = np.hypot(px - (a[0] + t * abx), py - (a[1] + t * aby))
        s = (e["cum"][k] + t * e["seglen"][k]) / e["total"]
        if best is None:
            best, bs = d, s
        else:
            m = d < best
            best = np.where(m, d, best)
            bs = np.where(m, s, bs)
    # 坡道在两端各留出一个半宽的平段（与相邻房间的圆角帽重叠区高度保持一致）
    a = min(max(e["half"], 14.0) / e["total"], 0.45)
    u = np.clip((bs - a) / (1.0 - 2 * a), 0.0, 1.0)
    return best - e["half"], e["y0"] + (e["y1"] - e["y0"]) * u


def build(cs=1.0, margin=0.0):
    xmax = max(max(p[0] for e in ELEMS if e["kind"] == "poly" for p in e["pts"]), L.EXTENT[0]) + 12
    ymax = max(max(p[1] for e in ELEMS if e["kind"] == "poly" for p in e["pts"]), L.EXTENT[1]) + 12
    xs, ys, px, py = G.make_grid(-12, -12, math.ceil(xmax), math.ceil(ymax), cs)
    f = np.full(px.shape, 1e9)
    idx = np.zeros(px.shape, dtype=np.int32)
    H = np.zeros(px.shape)
    for i, e in enumerate(ELEMS):
        d, h = elem_sdf_h(e, px, py)
        m = d < f
        f = np.where(m, d, f)
        idx = np.where(m, i, idx)
        H = np.where(m, h, H)
    return dict(xs=xs, ys=ys, px=px, py=py, f=f, idx=idx, H=H, cs=cs)


def sample(F, x, y):
    """在网格上最近邻取 (sdf, 元素下标, 高度)"""
    i = int(round((x - F["xs"][0]) / F["cs"]))
    j = int(round((y - F["ys"][0]) / F["cs"]))
    i = min(max(i, 0), len(F["xs"]) - 1)
    j = min(max(j, 0), len(F["ys"]) - 1)
    return F["f"][j, i], F["idx"][j, i], F["H"][j, i]


def height_at(x, y):
    """精确地面高度（逐元素求值，取 sdf 最小者）；不在任何空间内也返回最近元素的高度"""
    px, py = np.array([[x]], dtype=float), np.array([[y]], dtype=float)
    best, bh = 1e9, 0.0
    for e in ELEMS:
        d, h = elem_sdf_h(e, px, py)
        if d[0, 0] < best:
            best, bh = float(d[0, 0]), float(h[0, 0])
    return bh


def inside(x, y, margin=0.0):
    px, py = np.array([[x]], dtype=float), np.array([[y]], dtype=float)
    return min(float(elem_sdf_h(e, px, py)[0][0, 0]) for e in ELEMS) < -margin


def ceil_of(e_index):
    return ELEMS[int(e_index)]["ceil"]


def style_of(e_index):
    return ELEMS[int(e_index)]["style"]


# ------------------------------------------------------------------ 地形（岛）高度
def terrain_heights(res=256, cs=2.5, origin=(-90.0, -90.0)):
    """岛屿式地形：空间周围是岩壁入海。露天空间下方地面 -1.5；地下 / 有顶空间上方盖山体。"""
    n = res + 1
    xs = origin[0] + np.arange(n) * cs
    ys = origin[1] + np.arange(n) * cs
    px, py = np.meshgrid(xs, ys)
    T = np.full(px.shape, -22.0)
    for e in ELEMS:
        d, h = elem_sdf_h(e, px, py)
        if e["style"] in UNDERGROUND:
            top = h + e["ceil"] + 2.2          # 山体盖过天花
        elif e["style"] in ENCLOSED:
            top = h - 1.6
        else:
            top = h - 1.6
        reach = 5.0 if e["style"] in UNDERGROUND else 7.0     # 平台外缘
        dd = np.maximum(d - (L.WALL_T + reach), 0.0)
        val = top - 1.7 * dd
        T = np.maximum(T, val)
    # 开放 / 地上空间的占地范围内，把地形压到地面以下 2.6m（含墙厚），保证草皮和岩石不会穿出地板；
    # 地下空间脚下的区域不压（上方要保留山体盖住天花）。
    ug_d = np.full(px.shape, 1e9)
    for e in ELEMS:
        if e["ug"]:
            ug_d = np.minimum(ug_d, elem_sdf_h(e, px, py)[0])
    for e in ELEMS:
        if e["ug"]:
            continue
        d, h = elem_sdf_h(e, px, py)
        m = (d < L.WALL_T + 0.8) & (ug_d > 1.0)
        T = np.where(m, np.minimum(T, h - 2.6), T)
    # 轻微起伏
    rng = np.random.RandomState(7)
    noise = np.zeros_like(T)
    for k, (fr, amp) in enumerate([(0.045, 1.6), (0.11, 0.7)]):
        ph = rng.rand(4) * 6.28
        noise += amp * (np.sin(px * fr + ph[0]) * np.cos(py * fr * 1.3 + ph[1]) + 0.5 * np.sin((px + py) * fr * 0.7 + ph[2]))
    far = np.clip((min_sdf(px, py) - (L.WALL_T + 3.0)) / 10.0, 0.0, 1.0)
    land = T > 0.5
    T = np.where(land, T + noise * np.clip((T - 0.5) / 6.0, 0, 1) * far, T)
    return T.astype(np.float32), dict(origin=list(origin), resolution=res, cell_size=cs)


def path_point(main_id, t):
    """主路线某段 t∈[0,1] 处的 (x, y, 高度, 朝向弧度)"""
    e = next(e for e in ELEMS if e["id"] == main_id)
    tot = e["total"]
    goal = t * tot
    for k, l in enumerate(e["seglen"]):
        if e["cum"][k] + l >= goal - 1e-9:
            a, b = e["pts"][k], e["pts"][k + 1]
            u = (goal - e["cum"][k]) / l if l > 0 else 0
            x, y = a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u
            return x, y, e["y0"] + (e["y1"] - e["y0"]) * t, math.atan2(b[1] - a[1], b[0] - a[0])
    a, b = e["pts"][-2], e["pts"][-1]
    return b[0], b[1], e["y1"], math.atan2(b[1] - a[1], b[0] - a[0])


def min_sdf(px, py):
    """所有空间的并集 SDF（向量化）"""
    best = np.full(px.shape, 1e9)
    for e in ELEMS:
        best = np.minimum(best, elem_sdf_h(e, px, py)[0])
    return best


def enclosed_mask(cs=4.0):
    """4m 粗网格：0 室外 1 有顶地上 2 地下。供游戏侧调环境光。"""
    S = build(1.0)
    xs = np.arange(-12, int(S["xs"][-1]) + 1, cs)
    ys = np.arange(-12, int(S["ys"][-1]) + 1, cs)
    px, py = np.meshgrid(xs, ys)
    f = np.full(px.shape, 1e9)
    kind = np.zeros(px.shape, dtype=np.int32)
    for e in ELEMS:
        d, h = elem_sdf_h(e, px, py)
        m = d < f
        f = np.where(m, d, f)
        k = 2 if e["ug"] else (1 if e["enc"] > 0 else 0)
        kind = np.where(m, k, kind)
    kind = np.where(f < 0.5, kind, 0)
    return dict(origin=[-12.0, -12.0], cs=cs, rows=["".join(str(int(v)) for v in row) for row in kind])