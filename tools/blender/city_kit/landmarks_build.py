# 地标拼装器 v2：读 docs/city_v7/game.json 的 landmarks（kit=true），用 gothic_kit.py（v2 概念图语汇）+ monument.py 的参数化模块，
# 按规划占地 / 门洞 / 大厅逐栋拼装，导出 assets/models/city_lm/<id>.glb（原点 = 地标中心、地面 = 地标标高；正面朝 glTF +Z），
# 缩略图 docs/city_lm/<id>.png，清单 assets/models/city_lm/manifest.json。
# 风格与尺度依据：docs/city_lm_concepts/v2（2026-10-09 用户确认）。
# 游戏端：GenCityV7 摆放这些 GLB；城市分块里这些地标只保留室内 / 门外平台 / 碰撞（export_game.mjs kitLandmarks）。
# "E:\FF导出\BlenderPortable\blender-4.5.10-windows-x64\blender.exe" -b -P tools/blender/city_kit/landmarks_build.py -- [all|id1,id2]
import bpy, bmesh, math, os, sys, json, importlib
from mathutils import Matrix, Vector
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "modkit")); sys.path.insert(0, HERE)
import kit, monument as mo, gothic_kit as gk
importlib.reload(kit); importlib.reload(mo); importlib.reload(gk)
from monument import BX, PX, CB, spin, radial, place, bake, join, K, IRON
import importlib.util as _iu   # 复用 city_kit/build.py 的 export / render / split_nocol / bounds（按路径加载，避免与 modkit/build.py 重名）
_spec = _iu.spec_from_file_location("city_kit_build", os.path.join(HERE, "build.py"))
ckb = _iu.module_from_spec(_spec); _spec.loader.exec_module(ckb)
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
DATA = os.path.join(ROOT, "docs", "city_v7", "game.json")
OUT = os.path.join(ROOT, "assets", "models", "city_lm")
DOC = os.path.join(ROOT, "docs", "city_lm")
os.makedirs(OUT, exist_ok=True); os.makedirs(DOC, exist_ok=True)

def clamp(v, a, b):
    return max(a, min(b, v))

def P2B(p):
    """规划局部 (x, z 朝正面) → Blender (x, -z)。"""
    return (p[0], -p[1])

side_xf = gk.side_xf
ROOF_OF_DISTRICT = {"mage": "violet", "military": "dark", "academy": "copper"}

def palette(lm):
    return gk.palette(ROOF_OF_DISTRICT.get(lm.get("district") or "", "red"))

# ------------------------------------------------------------------ 台基 / 台阶
def stairs(ramp, mkey):
    """台阶：沿坡道逐级方块（截面挤出 + 阵列 + 逐级抬高的几何顶点）+ 两侧斜顶栏墙。坡道 a（顶）→ b（底）。"""
    a, b = Vector(P2B(ramp["a"])), Vector(P2B(ramp["b"]))
    rise = ramp["y0"] - ramp["y1"]
    if rise <= 0.05:
        return None
    L = (b - a).length
    n = max(2, round(rise / 0.17))
    run = L / n
    ang = math.atan2((b - a).y, (b - a).x)
    st = BX("step", 0, -ramp["w"] / 2, ramp["y1"] - 0.05, run, ramp["w"] / 2, ramp["y1"] + rise / n, mkey)
    kit.array(st, n, (0, 0, 0))
    bm = bmesh.new(); bm.from_mesh(st.data); bm.verts.ensure_lookup_table()
    per = len(bm.verts) // n
    for k in range(n):          # 局部 x=0 在坡脚 b，第 k 级（自下而上）在 x = k·run
        for v in bm.verts[k * per:(k + 1) * per]:
            v.co.x += k * run
            if v.co.z > ramp["y1"]:
                v.co.z = ramp["y1"] + rise * (k + 1) / n
    bm.to_mesh(st.data); bm.free()
    mo.tag(st, "vertex")
    side = [BX("cheek", 0, sx * ramp["w"] / 2 - 0.35, ramp["y1"] - 0.05, L, sx * ramp["w"] / 2 + 0.35, ramp["y0"] + 0.9, mkey) for sx in (-1, 1)]
    for c in side:
        for v in c.data.vertices:
            if v.co.z > ramp["y1"]:
                v.co.z = ramp["y1"] + rise * (v.co.x / L) + 0.9
        mo.tag(c, "vertex")
    ob = join([st] + side, "stairs")
    place(ob, Matrix.Translation((b.x, b.y, 0)) @ Matrix.Rotation(ang + math.pi, 4, "Z"))
    return ob

def common_base(lm, e, pal):
    parts = []
    if not e:
        return parts
    if e.get("podium"):
        pts = [P2B(p) for p in e["podium"]["poly"]]
        bm = bmesh.new()
        lo = [bm.verts.new((x, y, -0.6)) for x, y in pts]; hi = [bm.verts.new((x, y, e["podium"]["y"])) for x, y in pts]
        for i in range(len(pts)):
            j = (i + 1) % len(pts); bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
        bm.faces.new(hi)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        parts.append(kit.bm_obj("podium", bm, pal["base"], ("profile_extrude",)))
        parts.append(CB("podium_lip", [(x, y, e["podium"]["y"] - 0.1) for x, y in pts + pts[:1]], 0.22, pal["trim"]))
    for r in e.get("ramps", []):
        if not r.get("jsSteps"):
            st = stairs(r, pal["trim"])
            if st:
                parts.append(st)
    return parts

# ================================================================== 公共建筑（概念图 v2：冒险者公会 / 市政厅 / 银行）
DOME_TYPES = {"opera", "observatory", "bath", "pavilion", "exchange"}
VAULT_TYPES = {"market"}

def civic(lm, e, pal):
    w, d, h, t = lm["w"], lm["d"], lm["h"], lm["type"]
    s = clamp(h / 34, 1.0, 1.6)
    fl = e["floor"] if e else 1.2
    dw, dh = (e["dw"], e["dh"]) if e else (7, 9)
    G = clamp(h * 0.32, dh + fl + 3.0, 17)
    T = clamp(h * 0.17, 5, 8)
    M = h - G - T
    tiers = [(0, G), (G, G + M), (G + M, h)]
    proj = (e["doorZ"] - d / 2) if e else 0.0
    portal = "portal:%.2f:%.2f:%.2f" % (dw, dh, fl)
    parts = common_base(lm, e, pal)
    for side, L in (("front", w), ("right", d), ("back", w), ("left", d)):
        def kinds(i, n, side=side):
            g = portal if (side == "front" and i == n // 2 and proj < 0.5) else "arcade"
            return [g, "lancet", "small"]
        fp, n, bw = gk.facade(L, tiers, kinds, pal, s, H=h)
        xf = side_xf(side, w, d)
        parts += [place(o, xf) for o in fp]
        parts.append(place(gk.eave(L, s, pal), xf @ Matrix.Translation((0, 0, h - 1.1 * s))))
        if side == "front":
            nb, bwf = n, bw
    # 正面山墙门楼（门洞前移量 proj）+ 门侧红锥圆角楼 + 旗帜
    fw = 0.0
    if proj > 0.5:
        fw = clamp(dw + 10 * s, 16, w * 0.5)
        fp, n, bw = gk.facade(fw, tiers, lambda i, n: [portal, "lancet", "small"], pal, s, bay_w=fw, H=h)
        xf = Matrix.Translation((-fw / 2, -d / 2 - proj, 0))
        parts += [place(o, xf) for o in fp]
        for sx in (-1, 1):
            sxf = (Matrix.Translation((fw / 2, -d / 2 - proj, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z")) if sx > 0 else \
                  (Matrix.Translation((-fw / 2, -d / 2, 0)) @ Matrix.Rotation(-math.pi / 2, 4, "Z"))
            parts.append(place(mo.cell("proj_side", proj, h, pal["wall"], None, 0.7), sxf))
        gr = fw * 0.62
        parts.append(place(gk.gable_wall(fw, gr, s, pal), Matrix.Translation((-fw / 2, -d / 2 - proj, h))))
        if not (t in DOME_TYPES or lm.get("dome") or t in VAULT_TYPES):   # 穹顶 / 玻璃拱建筑是平台屋面，山墙后不接坡屋顶
            groof = PX("gable_roof", [(-fw / 2 - 0.6, 0), (fw / 2 + 0.6, 0), (0, gr)], proj + d * 0.35, pal["roof"], 0)
            groof.rotation_euler.z = math.pi / 2; groof.location = (0, -d / 2 - proj + 0.9, h); bake(groof); parts.append(groof)
        else:
            back = PX("gable_back", [(-fw / 2, 0), (fw / 2, 0), (0, gr)], 0.6, pal["wall"], 0)
            back.rotation_euler.z = math.pi / 2; back.location = (0, -d / 2 - proj + 0.9, h); bake(back); parts.append(back)
        for sx in (-1, 1):
            parts.append(place(gk.banner(2.6 * s, M * 0.62, s, pal), xf @ Matrix.Translation((fw / 2 + sx * (dw / 2 + 2.6 * s), -0.4, G + M * 0.92))))
            tr = gk.round_turret(2.6 * s, G + M * 0.45, s, pal)
            parts.append(place(tr, Matrix.Translation((sx * (fw / 2 + 2.4 * s), -d / 2 - proj - 0.6, 0))))
    # 屋顶
    if t in VAULT_TYPES:
        v = mo.glass_vault(w - 3, d - 3, d * 0.34, s, dict(pal, trim=pal["trim"]))
        parts.append(place(v, Matrix.Translation((-(w - 3) / 2, 0, h + 1.2 * s))))
        for sx in (-1, 1):
            for sy in (-1, 1):
                parts.append(place(gk.round_turret(3.0 * s, h + 6 * s, s, pal, start=h - 2), Matrix.Translation((sx * (w / 2 - 2), sy * (d / 2 - 2), 0))))
    elif t in DOME_TYPES or lm.get("dome"):
        parts.append(BX("terrace", -w / 2 + 0.3, -d / 2 + 0.3, h + 0.3 * s, w / 2 - 0.3, d / 2 - 0.3, h + 0.8 * s, pal["trim"]))
        r = clamp(min(w, d) * 0.32, 6, 18)
        dmat = {"opera": pal["cone"], "bath": pal["copper"]}.get(t, pal["copper"])
        parts.append(place(mo.dome(r, dmat, dict(pal, accent=pal["gold"]), s, drum_h=r * 0.75, ribs=12), Matrix.Translation((0, d * 0.05, h + 0.8 * s))))
        for sx in ((-1, 1) if t != "exchange" and not lm.get("clock") else ()):   # 银行有钟楼，不再加四角楼（避免拥挤）
            for sy in (-1, 1):
                parts.append(place(gk.round_turret(2.4 * s, h + 5 * s, s, pal, start=h - 1), Matrix.Translation((sx * (w / 2 - 1.5), sy * (d / 2 - 1.5), 0))))
    else:
        rise = clamp(min(w, d) * 0.55, 9, 24)
        ndx = max(1, round(w / (8.6 * s)))
        xs = [-w / 2 + w * (i + 0.5) / ndx for i in range(ndx)]
        xs = [x for x in xs if abs(x) > fw / 2 + 1.5 and abs(x) < w / 2 - 3]
        parts.append(gk.hip_roof(w, d, h + 0.3 * s, rise, s, pal, xs))
    # 塔
    if t == "cityhall":
        parts += gk.tower(0, -d / 2 + 9.5, h - 1, lm.get("tower") or h + 80, 19, s, pal, top="spire", clock=True)
        sz = 13
        for sx in (-1, 1):
            for sy in (-1, 1):
                sides = ("front" if sy < 0 else "back", "left" if sx < 0 else "right")
                parts += gk.tower(sx * (w / 2 - sz / 2 + 1), sy * (d / 2 - sz / 2 + 1), h - 1, h + 28, sz, s, pal, top="bell", clock=False, skirt_from=0, skirt_sides=sides, banners=sy < 0)
    elif t == "guild" or (lm.get("tower") and t in ("civic", "academy")):
        sz = clamp(min(w, d) * 0.32, 11, 15)
        top_z = lm.get("tower") or h + 50
        if t == "academy":
            parts += gk.tower(w / 2 - 12, d / 2 - 10, h - 1, top_z, sz, s, pal, top="spire", clock=True, skirt_from=0, skirt_sides=("back", "right"))
        else:
            parts += gk.tower(-w / 2 + sz / 2 - 1, -d / 2 + sz / 2 - 1, h - 1, top_z, sz, s, pal, top="spire", clock=True, skirt_from=0, skirt_sides=("front", "left"))
    elif t == "exchange" or lm.get("clock"):
        parts += gk.tower(w / 2 - 6, -d / 2 + 6, h - 1, h + 34, 10, s, pal, top="bell", clock=True, skirt_from=0, skirt_sides=("front", "right"))
    elif lm.get("tier") == 1 and t not in VAULT_TYPES:
        parts += gk.tower(0, d / 2 - 10, h - 1, h + 40, 14, s, pal, top="bell", clock=True)
    if t == "knights":
        for sx in (-1, 1):
            for sy in (-1, 1):
                parts.append(place(gk.round_turret(3.4 * s, h + 8 * s, s, pal, start=h - 2), Matrix.Translation((sx * (w / 2 - 1), sy * (d / 2 - 1), 0))))
    return parts

# ================================================================== 工坊 / 酒馆（T3）
def workshop(lm, e, pal):
    w, d, h = lm["w"], lm["d"], lm["h"]
    s = clamp(h / 26, 0.9, 1.2)
    fl = e["floor"] if e else 0.8
    dw, dh = (e["dw"], e["dh"]) if e else (6, 7)
    G = clamp(h * 0.45, dh + fl + 2.5, 12)
    tiers = [(0, G), (G, h)]
    portal = "portal:%.2f:%.2f:%.2f" % (dw, dh, fl)
    upper = "lancet" if h - G > 8 else "small"
    parts = common_base(lm, e, pal)
    for side, L in (("front", w), ("right", d), ("back", w), ("left", d)):
        fp, n, bw = gk.facade(L, tiers, lambda i, n, side=side: [portal if (side == "front" and i == n // 2) else "arcade", upper], pal, s, bay_w=8.0, H=h)
        xf = side_xf(side, w, d)
        parts += [place(o, xf) for o in fp]
        parts.append(place(gk.eave(L, s, pal), xf @ Matrix.Translation((0, 0, h - 1.1 * s))))
    rise = clamp(min(w, d) * 0.6, 7, 18)
    ndx = max(1, round(w / (8 * s)))
    parts.append(gk.hip_roof(w, d, h + 0.3 * s, rise, s, pal, [-w / 2 + w * (i + 0.5) / ndx for i in range(ndx) if abs(-w / 2 + w * (i + 0.5) / ndx) > 4]))
    parts.append(place(gk.round_turret(2.6 * s, h + 5 * s, s, pal, start=0), Matrix.Translation((w / 2 - 1.5, -d / 2 + 1.5, 0))))
    parts.append(place(gk.banner(2.4 * s, (h - G) * 0.6, s, pal), Matrix.Translation((0, -d / 2 - 0.2, G + (h - G) * 0.9))))
    ch = kit.chimney(rise * 0.6 + 3)
    parts.append(place(ch, Matrix.Translation((-w * 0.28, d * 0.15, h)) @ Matrix.Scale(1.5, 4)))
    return parts

# ================================================================== 哥特大圣堂（cathedral / royal_chapel / oldchurch）
def _flyer(sx, y, x_out, x_in, z_out, z_in, s, pal):
    pts = []
    for i in range(13):
        tt = i / 12
        pts.append((sx * (x_out + (x_in - x_out) * tt), y, z_out + (z_in - z_out) * tt - math.sin(math.pi * tt) * 1.4 * s))
    arm = CB("flyer", pts, 0.45 * s, pal["base"])
    cap = CB("flyer_cap", [(px, py, pz + 1.0 * s + 0.5 * math.sin(math.pi * i / 12)) for i, (px, py, pz) in enumerate(pts)], 0.25 * s, pal["trim"])
    return join([arm, cap], "flyer")

def gothic(lm, e, pal):
    w, d, h = lm["w"], lm["d"], lm["h"]
    s = clamp(h / 34, 1.0, 1.7)
    nw = w * 0.22
    ts = min(7, (w / 2 - nw) / 2) * 2
    fl = e["floor"]
    pod = e["podium"]["y"] if e.get("podium") else fl
    ah = h * 0.55
    parts = common_base(lm, e, pal)
    y_front, y_back = -(d / 2 - 12), d / 2 - 10
    nave_len = y_back - y_front
    a_front, a_back = -(d / 2 - 14), d / 2 - 14
    for sx in (-1, 1):
        L = a_back - a_front
        rot = Matrix.Rotation(math.pi / 2 if sx > 0 else -math.pi / 2, 4, "Z")
        org = Matrix.Translation((sx * w / 2, a_front if sx > 0 else a_back, 0)) @ rot
        fp, n, bw = gk.facade(L, [(0, pod), (pod, ah)], lambda i, n: ["blank", "lancet"], pal, s, bay_w=8.5, H=ah)
        parts += [place(o, org) for o in fp]
        parts.append(place(gk.eave(L, s, pal), org @ Matrix.Translation((0, 0, ah - 1.1 * s))))
        for i in range(n + 1):
            y = a_front + i * bw
            parts.append(_flyer(sx, y, w / 2 + 0.6 * s, nw, ah + 2.4 * s, h * 0.84, s, pal))
        lean = PX("aisle_roof", [(0, 0), (w / 2 - nw + 1.0, 0), (0, h * 0.18)], L, pal["roof"])
        lean.rotation_euler.z = -math.pi / 2 if sx > 0 else math.pi / 2
        lean.location = (sx * nw, a_back if sx > 0 else a_front, ah)
        bake(lean); parts.append(lean)
        org2 = Matrix.Translation((sx * nw, y_front if sx > 0 else y_back, 0)) @ rot
        fp, n2, bw2 = gk.facade(nave_len, [(ah, h)], lambda i, n: ["lancet"], pal, s, bay_w=8.5, buttresses=False)
        parts += [place(o, org2) for o in fp]
        parts.append(place(mo.cell("nave_low", nave_len, ah - pod, pal["wall"], None, 0.6), org2 @ Matrix.Translation((0, 0, pod))))
        parts.append(place(gk.eave(nave_len, s, pal), org2 @ Matrix.Translation((0, 0, h - 1.1 * s))))
    # 西立面：门 + 玫瑰窗山墙
    portal = "portal:%.2f:%.2f:%.2f" % (e["dw"], e["dh"], fl)
    zt = fl + e["dh"] + 5 * s
    for o in gk.lancet_cell(2 * nw, zt, portal, pal, s * 1.2):
        parts.append(place(o, Matrix.Translation((-nw, y_front, 0))))
    for o in gk.lancet_cell(2 * nw, h - zt, "lancet", pal, s * 1.4):
        parts.append(place(o, Matrix.Translation((-nw, y_front, zt))))
    parts.append(place(gk.gable_wall(2 * nw, nw * 1.3, s, pal), Matrix.Translation((-nw, y_front, h))))
    parts.append(place(gk.banner(3.0 * s, h * 0.35, s, pal), Matrix.Translation((-nw * 0.55, y_front - 0.4, zt + (h - zt) * 0.9))))
    parts.append(place(gk.banner(3.0 * s, h * 0.35, s, pal), Matrix.Translation((nw * 0.55, y_front - 0.4, zt + (h - zt) * 0.9))))
    # 中殿屋顶 + 十字交叉红穹顶 + 四角尖塔
    rr = PX("nave_roof", [(-nw - 0.8, 0), (nw + 0.8, 0), (0, nw * 1.3)], nave_len + 1, pal["roof"], 0)
    rr.rotation_euler.z = math.pi / 2; rr.location = (0, y_front - 0.5, h); bake(rr); parts.append(rr)
    cross_y = y_front + nave_len * 0.62
    parts.append(place(mo.dome(nw * 0.95, pal["cone"], dict(pal, accent=pal["gold"]), s, drum_h=nw * 0.8, ribs=8), Matrix.Translation((0, cross_y, h + nw * 0.4))))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(place(gk.pinnacle(1.1 * s, 8 * s, s, pal), Matrix.Translation((sx * nw * 1.05, cross_y + sy * nw * 1.05, h + nw * 0.4))))
    # 西立面双塔（铜绿尖顶）
    for sx in (-1, 1):
        cx = sx * (w / 2 - ts / 2)
        parts += gk.tower(cx, -(d / 2 - ts / 2), pod, max(lm.get("spire") or h + 40, h + 30), ts, s * 0.9, pal, top="spire", clock=sx < 0)
    # 后殿：半八角尖窗墙 + 半锥屋顶
    ay = y_back
    for i in range(4):
        a0, a1 = math.pi * i / 4, math.pi * (i + 1) / 4
        p0 = Vector((nw * math.cos(a0), ay + nw * math.sin(a0))); p1 = Vector((nw * math.cos(a1), ay + nw * math.sin(a1)))
        L = (p1 - p0).length; ang = math.atan2((p1 - p0).y, (p1 - p0).x)
        for o in gk.lancet_cell(L, h * 0.8 - pod, "lancet", pal, s * 0.8):
            parts.append(place(o, Matrix.Translation((p0.x, p0.y, pod)) @ Matrix.Rotation(ang, 4, "Z")))
    parts.append(place(spin("apse_roof", [(nw + 0.8, 0), (0.0, nw * 1.1)], pal["roof"], angle=math.pi, steps=4), Matrix.Translation((0, ay, h * 0.8))))
    return parts

# ================================================================== 中央车站
def station(lm, e, pal):
    w, d, h = lm["w"], lm["d"], lm["h"]
    s = clamp(h / 34, 1.0, 1.6)
    fl = e["floor"]
    parts = common_base(lm, e, pal)
    cw = 42.6 + 1.2
    G = 13.0
    tiers = [(0, G), (G, h - 7), (h - 7, h)]
    ww = (w - cw) / 2
    for sx in (-1, 1):
        x0 = -w / 2 if sx < 0 else cw / 2
        for side, xf in (("front", Matrix.Translation((x0, -d / 2, 0))), ("back", Matrix.Translation((x0 + ww, d / 2, 0)) @ Matrix.Rotation(math.pi, 4, "Z"))):
            fp, n, bw = gk.facade(ww, tiers, lambda i, n: ["arcade", "lancet", "small"], pal, s, H=h)
            parts += [place(o, xf) for o in fp]
            parts.append(place(gk.eave(ww, s, pal), xf @ Matrix.Translation((0, 0, h - 1.1 * s))))
        fp, n, bw = gk.facade(d, tiers, lambda i, n: ["arcade", "lancet", "small"], pal, s, H=h)
        xf = side_xf("left" if sx < 0 else "right", w, d)
        parts += [place(o, xf) for o in fp]
        parts.append(place(gk.eave(d, s, pal), xf @ Matrix.Translation((0, 0, h - 1.1 * s))))
        xs = [x0 + ww * (i + 0.5) / 3 - (x0 + ww / 2) for i in range(3)]
        parts.append(place(gk.hip_roof(ww, d, h + 0.3, clamp(d * 0.4, 9, 18), s, pal, xs), Matrix.Translation((x0 + ww / 2, 0, 0))))
    # 中央：门墙 + 整面尖拱大窗
    zsplit = fl + e["dh"] + 2.5
    org = Matrix.Translation((-cw / 2, -d / 2, 0))
    for o in gk.lancet_cell(cw, zsplit, "portal:%.2f:%.2f:%.2f" % (e["dw"], e["dh"], fl), pal, s * 1.3):
        parts.append(place(o, org))
    big = ("pointed", cw / 2, 0.5, cw * 0.6, h + 10 - zsplit - 2)
    up = Matrix.Translation((-cw / 2, -d / 2, zsplit))
    parts.append(place(mo.cell("great_wall", cw, h + 10 - zsplit, pal["wall"], big, 0.8), up))
    parts.append(place(mo.glazing(big, s * 1.5, tracery=True, glass=pal["glass"]), up))
    parts.append(place(mo.surround(big, s * 1.8, pal["trim"], key=False), up))
    parts.append(place(gk.gable_wall(cw, cw * 0.35, s, pal, rose=False), Matrix.Translation((-cw / 2, -d / 2, h + 10))))
    v = mo.glass_vault(d - 2, cw - 1, cw * 0.4, s, pal)
    parts.append(place(v, Matrix.Translation((0, -d / 2 + 1, h + 2)) @ Matrix.Rotation(math.pi / 2, 4, "Z")))
    for sx in (-1, 1):
        parts += gk.tower(sx * (cw / 2 + 6), -d / 2 + 6, h - 1, h + 36, 12, s, pal, top="bell", clock=True, skirt_from=0, skirt_sides=("front",))
    return parts

# ================================================================== 飞艇站瞭望塔（概念图 v2 airtower）
def airtower(lm, e, pal):
    H = lm["h"]
    r = lm["w"] / 2 - 1.5
    s = 1.4
    fl = e["floor"]
    parts = common_base(lm, e, pal)
    portal = "portal:%.2f:%.2f:%.2f" % (e["dw"], e["dh"], fl)
    def faces(rr, z0, tiers, kinds_front, kinds_other, sc):
        out = []
        ap = rr * math.cos(math.pi / 8); fw = 2 * rr * math.sin(math.pi / 8)
        for i in range(8):
            phi = -math.pi / 2 + i * math.pi / 4
            ks = kinds_front if i == 0 else kinds_other
            for (a, b), k in zip(tiers, ks):
                for o in gk.lancet_cell(fw, b - a, k, pal, sc):
                    out.append(place(o, Matrix.Rotation(phi + math.pi / 2, 4, "Z") @ Matrix.Translation((-fw / 2, -ap, a))))
            out.append(place(gk.eave(fw, sc, pal), Matrix.Rotation(phi + math.pi / 2, 4, "Z") @ Matrix.Translation((-fw / 2, -ap, tiers[-1][1] - 1.1 * sc))))
        return out
    parts += faces(r, 0, [(0, 16), (16, 30)], [portal, "lancet"], ["arcade", "lancet"], 1.2)
    for i in range(8):
        a = -math.pi / 2 + math.pi / 8 + i * math.pi / 4
        b = gk.buttress(30, 1.2, pal, depth=2.6, wid=1.8)
        parts.append(place(b, Matrix.Translation((r * math.cos(a), r * math.sin(a), 0)) @ Matrix.Rotation(a + math.pi / 2, 4, "Z")))
    r2 = r * 0.72
    shaft = [(30 + 58 * k / 4, 30 + 58 * (k + 1) / 4) for k in range(4)]
    parts += [place(o, Matrix.Translation((0, 0, 30))) for o in faces(r2, 0, [(a - 30, b - 30) for a, b in shaft], ["lancet"] * 4, ["lancet", "small", "lancet", "small"], 1.1)]
    for i in range(8):
        a = -math.pi / 2 + math.pi / 8 + i * math.pi / 4
        pts = [(((r + 1.2) + (r2 - (r + 1.2)) * tt) * math.cos(a), ((r + 1.2) + (r2 - (r + 1.2)) * tt) * math.sin(a), 36 + 14 * tt - math.sin(math.pi * tt) * 2.0) for tt in (k / 12 for k in range(13))]
        parts.append(CB("tower_flyer", pts, 0.6, pal["base"]))
    parts.append(place(gk.banner(3.0, 18, s, pal), Matrix.Translation((0, -r2 * math.cos(math.pi / 8) - 0.4, 82))))
    parts.append(place(mo.iron_cage(r * 0.95, 13, 1.4, dict(pal)), Matrix.Translation((0, 0, 88))))
    parts.append(spin("cage_floor", [(0, 87.2), (r * 1.2, 87.2), (r * 1.2, 88.0), (0, 88.0)], pal["trim"], steps=16))
    z = 88 + 13 * 1.06
    parts.append(spin("crown", [(r * 0.55, z - 0.5), (r * 0.5, z + 2), (r * 0.3, z + 6), (0.25, H - 3), (0.06, H), (0, H + 0.1)], pal["copper"], steps=16))
    fn = gk.finial(3.0, 1.6, pal); fn.location.z = H; bake(fn); parts.append(fn)
    L = 22
    y0 = -r2 * math.cos(math.pi / 8)
    top = CB("arm_top", [(0, y0, 72), (0, y0 - L, 71)], 0.35, IRON)
    bot = CB("arm_bot", [(0, y0, 66), (0, y0 - L, 69.5)], 0.35, IRON)
    br = CB("arm_brace", [(0, y0 - 0.5, 66.2), (0, y0 - 2.3, 71.8)], 0.15, IRON)
    kit.array(br, 10, (0, -2.1, 0))
    ring = spin("moor_ring", [(1.8, -0.2), (2.2, -0.2), (2.2, 0.2), (1.8, 0.2)], pal["gold"], steps=16)
    ring.rotation_euler = (math.pi / 2, 0, 0); ring.location = (0, y0 - L, 70.4); bake(ring)
    parts += [top, bot, br, ring]
    parts.append(place(mo.airship(60, 1.4, pal), Matrix.Translation((0, y0 - L - 60 * 0.17 - 2.5, 72.4))))
    return parts

# ================================================================== 晴岚王宫（grandpalace）：规划里的 U 形占地 = 一座主楼 + 若干侧翼实体块（e["solids"]）
def palace(lm, e, pal):
    w, d, h = lm["w"], lm["d"], lm["h"]
    s = 1.5
    pod = e["podium"]["y"] if e.get("podium") else 0.0
    parts = common_base(lm, e, pal)
    portal = "portal:%.2f:%.2f:%.2f" % (e["dw"], e["dh"], e["floor"] - pod)
    rects = e["solids"]
    for idx, P in enumerate(rects):
        xs = [p[0] for p in P]; zs = [p[1] for p in P]
        x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
        bw, bd = x1 - x0, z1 - z0
        keep = idx == 0
        hh = h if keep else h * (0.74 if bd > 30 else 0.62)
        G = clamp(hh * 0.3, 12, 18); T = 7.0; M = hh - G - T
        tiers = [(0, G), (G, G + M), (G + M, hh)]
        cx, cy = (x0 + x1) / 2, -(z0 + z1) / 2
        base = Matrix.Translation((cx, cy, pod))
        for side, L in (("front", bw), ("right", bd), ("back", bw), ("left", bd)):
            def kinds(i, n, side=side, keep=keep):
                return [portal if (keep and side == "front" and i == n // 2) else "arcade", "lancet", "small"]
            fp, n, bw_ = gk.facade(L, tiers, kinds, pal, s, bay_w=10.5, H=hh)
            xf = base @ side_xf(side, bw, bd)
            parts += [place(o, xf) for o in fp]
            parts.append(place(gk.eave(L, s, pal), xf @ Matrix.Translation((0, 0, hh - 1.1 * s))))
        if keep:
            fw = clamp(e["dw"] + 12, 20, bw * 0.5)
            proj = e["doorZ"] - z1
            if proj > 0.5:
                fp, n, bw_ = gk.facade(fw, tiers, lambda i, n: [portal, "lancet", "small"], pal, s, bay_w=fw, H=hh)
                xf = base @ Matrix.Translation((-fw / 2, -bd / 2 - proj, 0))
                parts += [place(o, xf) for o in fp]
                parts.append(place(gk.gable_wall(fw, fw * 0.6, s, pal), xf @ Matrix.Translation((0, 0, hh))))
            parts.append(place(BX("keep_terrace", -bw / 2 + 0.3, -bd / 2 + 0.3, hh + 0.3, bw / 2 - 0.3, bd / 2 - 0.3, hh + 1.0, pal["trim"]), base))
            r = clamp(min(bw, bd) * 0.32, 12, 20)
            parts.append(place(mo.dome(r, pal["copper"], dict(pal, accent=pal["gold"]), s, drum_h=r * 0.8, ribs=16), base @ Matrix.Translation((0, 0, hh + 1.0))))
            for sx in (-1, 1):
                parts += gk.tower(cx + sx * (bw / 2 - 7), cy - bd / 2 + 8, pod + hh - 1, pod + hh + 52, 13, s, pal, top="spire", clock=sx < 0, skirt_from=pod, skirt_sides=("front", "left" if sx < 0 else "right"))
        else:
            rise = clamp(min(bw, bd) * 0.5, 9, 18)
            parts.append(place(gk.hip_roof(bw, bd, hh + 0.3, rise, s, pal, [-bw / 2 + bw * (i + 0.5) / max(1, round(bw / 10)) for i in range(max(1, round(bw / 10)))]), base))
            for sx in (-1, 1):
                for sy in (-1, 1):
                    parts.append(place(gk.round_turret(2.8, hh + 6, s, pal, start=hh - 2), base @ Matrix.Translation((sx * (bw / 2 - 1.2), sy * (bd / 2 - 1.2), 0))))
    return parts

ARCH = {"cathedral": gothic, "workshop": workshop, "tavern": workshop, "station": station, "airtower": airtower, "grandpalace": palace}

def assemble(lm):
    pal = palette(lm)
    e = lm.get("enter")
    fn = ARCH.get(lm["type"], civic)
    parts = [p for p in fn(lm, e, pal) if p is not None]
    return join(parts, lm["id"])

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    data = json.load(open(DATA, encoding="utf-8"))
    lms = [l for l in data["landmarks"] if l.get("kit")]
    sel = args[0] if args else "all"
    if sel != "all":
        want = set(sel.split(",")); lms = [l for l in lms if l["id"] in want]
    mp = os.path.join(OUT, "manifest.json")
    man = json.load(open(mp, encoding="utf-8")) if os.path.exists(mp) else {"version": 2, "landmarks": {}}
    man["version"] = 2
    for lm in lms:
        ckb.clear()
        ob = assemble(lm)
        objs = ckb.split_nocol(ob)
        mn, mx = ckb.bounds(objs)
        ckb.export(objs, os.path.join(OUT, lm["id"] + ".glb"))
        ckb.render(os.path.join(DOC, lm["id"] + ".png"), objs, (900, 680))
        man["landmarks"][lm["id"]] = {"name": lm["name"], "type": lm["type"], "tier": lm.get("tier", 0), "plan_wdh": [lm["w"], lm["d"], lm["h"]],
                                      "size_m": [round(mx.x - mn.x, 1), round(mx.y - mn.y, 1), round(mx.z - mn.z, 1)], "tris": ckb.tris_of(objs), "methods": ckb.methods_of(objs)}
        print("LM", lm["id"], man["landmarks"][lm["id"]]["size_m"], man["landmarks"][lm["id"]]["tris"], flush=True)
    json.dump(man, open(mp, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print("LANDMARKS_DONE", len(lms))
