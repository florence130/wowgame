# 晴岚港「奇观级」功能建筑模块库（city_kit / monument v1，2026-10-09）
# 依据：docs/city_ref/ref10…ref14（街道钟塔比例、哥特穹顶与高架拱、云端圆顶露台、飞艇站高塔俯瞰、大教堂河城鸟瞰）+ ref15…ref19。
# MMO 尺度：玩家 1.8m，主要入口 6–12m 宽 / 8–12m 高，功能建筑檐口 25–55m，地标塔 80–150m。
# 全部模块参数化（宽 / 高可变），仍只用 modkit 的十种手法，登记在 methods：
#   bridge 桥接（墙板开洞）· solidify 实体化 · profile_extrude 截面挤出 · curve_bevel 曲线倒角 · screw 旋绕 · array 阵列 ·
#   mirror 镜像 · simple_deform 简单形变 · curve_deform 曲线变形 · vertex 几何顶点
# 立面坐标系：模块沿 +X 展开 0..w，外立面在 y=0、朝 -Y，墙体向 +Y 长厚度 t；z 向上。
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, "..", "modkit"))
import kit
from kit import box as _kbox, profile_extrude as _kpx, array, mirror, curve_bevel as _kcb, jitter, join, apply_mods, bm_obj, new_obj, simple_taper, simple_bend, curve_deform

# ------------------------------------------------------------------ 材质与配色（按分区）
def K(t, c, tex="", m=0):
    return "K|%s|%s|%s|%s" % (t, c, tex, m)

PALETTES = {
    "core":     dict(wall=K(2, "e8e0cf", "st_masonry", 4.0), base=K(2, "d3c9b4", "st_masonry", 3.0), trim=K(9, "f2ebdc"), roof=K(3, "4a5a74", "st_roof_scale", 2.6), accent=K(5, "d6a64a")),
    "academy":  dict(wall=K(2, "e6dccb", "st_masonry", 4.0), base=K(2, "cfc4ad", "st_masonry", 3.0), trim=K(9, "f4eee0"), roof=K(5, "5f9f8f"), accent=K(5, "d6a64a")),
    "nobles":   dict(wall=K(9, "f3efe6"), base=K(2, "ded8cb", "st_masonry", 3.0), trim=K(9, "fbf8f1"), roof=K(5, "5aa392"), accent=K(5, "d9ab4c")),
    "mage":     dict(wall=K(2, "e4dde8", "st_masonry", 4.0), base=K(2, "c9c0cf", "st_masonry", 3.0), trim=K(9, "f1edf5"), roof=K(3, "5d4f86", "st_roof_scale", 2.6), accent=K(5, "62b3b0")),
    "oldtown":  dict(wall=K(0, "dcc193", "st_plaster", 3.0), base=K(2, "b8ab92", "st_masonry", 3.0), trim=K(9, "efe4cc"), roof=K(4, "a5463a", "st_roof_barrel", 2.0), accent=K(5, "b9873f")),
    "military": dict(wall=K(2, "b3b0a8", "st_masonry", 3.2), base=K(2, "8f8c85", "st_masonry", 2.6), trim=K(9, "d7d4cc"), roof=K(3, "3f4654", "st_roof_scale", 2.6), accent=K(5, "a88a4a")),
    "harbor":   dict(wall=K(0, "ead2ad", "st_plaster", 3.0), base=K(2, "cdbf9f", "st_masonry", 3.0), trim=K(9, "f6eddc"), roof=K(4, "b04a37", "st_roof_barrel", 2.0), accent=K(5, "d6a64a")),
    "brick":    dict(wall=K(1, "b25a40", "brick", 2.6), base=K(2, "cdc3ae", "st_masonry", 3.0), trim=K(9, "efe6d4"), roof=K(3, "48566e", "st_roof_scale", 2.6), accent=K(5, "d6a64a")),
    "gothic":   dict(wall=K(2, "e3d9c3", "st_masonry", 4.0), base=K(2, "c7bca4", "st_masonry", 3.0), trim=K(9, "efe6d2"), roof=K(4, "a9503c", "st_roof_barrel", 2.2), accent=K(5, "d6a64a")),
}
GLASS = K("glass", "8fb3c9", "", 0)
GLOW = K("glow", "ffd9a0", "", 0)
IRON = K(7, "262b33")
WOOD = K(6, "5b3a26", "st_boards", 1.6)
ZINC = K(9, "7f8b97")
CLOCK = K(9, "f7f1e2")

def tag(ob, *m):
    s = set(x for x in ob.get("methods", "").split(",") if x) | set(m)
    ob["methods"] = ",".join(sorted(s)); return ob

def bake(ob):
    """把对象变换写进网格（后续再整体放置）。"""
    bpy.context.view_layer.update()
    ob.data.transform(ob.matrix_basis); ob.matrix_basis = Matrix.Identity(4)
    return ob

def place(ob, xf):
    bpy.context.view_layer.update()
    ob.matrix_world = xf @ ob.matrix_world
    return ob

def BX(name, x0, y0, z0, x1, y1, z1, mkey):
    """轴对齐方块（截面挤出）。"""
    ob = _kpx(name, [(y0, z0), (y1, z0), (y1, z1), (y0, z1)], x1 - x0, mkey, "x")
    ob.location.x = x0
    return bake(ob)

def PX(name, prof, length, mkey, x0=0.0):
    ob = _kpx(name, prof, length, mkey, "x"); ob.location.x = x0
    return bake(ob)

def CB(name, pts, r, mkey, square=True):
    return _kcb(name, pts, r, mkey, square=square)

def spin(name, prof, mkey, angle=2 * math.pi, steps=16, center=(0.0, 0.0), dup=False):
    bm = bmesh.new()
    vs = [bm.verts.new((center[0] + r, center[1], z)) for r, z in prof]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, cent=(center[0], center[1], 0), axis=(0, 0, 1), angle=angle, steps=steps, use_duplicate=dup)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm_obj(name, bm, mkey, ("screw",))

def radial(ob, n, center=(0.0, 0.0), angle=2 * math.pi):
    """环形阵列（array）。"""
    bake(ob)
    bm = bmesh.new(); bm.from_mesh(ob.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    step = angle / n if angle < 2 * math.pi - 1e-6 else 2 * math.pi / n
    bmesh.ops.spin(bm, geom=geom, cent=(center[0], center[1], 0), axis=(0, 0, 1), angle=step * (n - 1), steps=n - 1, use_duplicate=True)
    bm.to_mesh(ob.data); bm.free()
    return tag(ob, "array")

# ------------------------------------------------------------------ 开洞轮廓
def opening(kind, cx, z0, w, h, seg=10):
    """洞口轮廓（x,z），逆时针：rect 方 / round 半圆拱 / pointed 哥特尖拱（等边）/ circle 圆窗。"""
    if kind == "circle":
        r = min(w, h) / 2; zc = z0 + h / 2
        return [(cx + r * math.cos(a), zc + r * math.sin(a)) for a in (-math.pi / 2 + 2 * math.pi * i / (seg * 2) for i in range(seg * 2))]
    if kind == "round":
        r = w / 2; zs = z0 + h - r
        return [(cx - r, z0), (cx + r, z0)] + [(cx + r * math.cos(a), zs + r * math.sin(a)) for a in (math.pi * i / seg for i in range(seg + 1))]
    if kind == "pointed":
        R = w; zs = z0 + h - w * math.sqrt(3) / 2
        right = [(cx - w / 2 + R * math.cos(a), zs + R * math.sin(a)) for a in (math.pi / 3 * i / seg for i in range(seg + 1))]
        left = [(cx + w / 2 + R * math.cos(a), zs + R * math.sin(a)) for a in (math.pi - math.pi / 3 + math.pi / 3 * i / seg for i in range(1, seg + 1))]
        return [(cx - w / 2, z0), (cx + w / 2, z0)] + right + left
    return [(cx - w / 2, z0), (cx + w / 2, z0), (cx + w / 2, z0 + h), (cx - w / 2, z0 + h)]

def spring_of(kind, z0, w, h):
    return z0 + h - (w / 2 if kind == "round" else w * math.sqrt(3) / 2 if kind == "pointed" else 0)

def _ray(c, ang, poly):
    d = Vector((math.cos(ang), math.sin(ang))); best = None
    for i in range(len(poly)):
        p, q = Vector(poly[i]), Vector(poly[(i + 1) % len(poly)]); e = q - p
        den = d.x * e.y - d.y * e.x
        if abs(den) < 1e-9: continue
        w_ = p - c
        t = (w_.x * e.y - w_.y * e.x) / den; s = (w_.x * d.y - w_.y * d.x) / den
        if t > 0 and -1e-6 <= s <= 1 + 1e-6 and (best is None or t < best): best = t
    return c + d * (best or 0)

def cell(name, w, h, mkey, hole=None, t=0.6, n=None):
    """墙板单元：外框与洞口轮廓按同一角度采样后桥接（bridge），实体化（solidify）向 +Y 长厚度。hole=(kind,cx,z0,w,h)。
    采样数按洞口形状取（方洞 24、拱 / 圆 36），控制面数。"""
    if n is None:
        n = 24 if (hole is None or hole[0] == "rect") else 36
    bm = bmesh.new()
    outer = [(0, 0), (w, 0), (w, h), (0, h)]
    if hole is None:
        bm.faces.new([bm.verts.new((x, 0, z)) for x, z in outer]); methods = ("solidify",)
    else:
        poly = opening(*hole)
        c = Vector((hole[1], hole[2] + hole[4] * 0.42))
        o = [bm.verts.new((p.x, 0, p.y)) for p in (_ray(c, 2 * math.pi * i / n, outer) for i in range(n))]
        ii = [bm.verts.new((p.x, 0, p.y)) for p in (_ray(c, 2 * math.pi * i / n, poly) for i in range(n))]
        e1 = [bm.edges.new((o[i], o[(i + 1) % n])) for i in range(n)]
        e2 = [bm.edges.new((ii[i], ii[(i + 1) % n])) for i in range(n)]
        bmesh.ops.bridge_loops(bm, edges=e1 + e2)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        methods = ("bridge", "solidify")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.y > 0: f.normal_flip()
    ob = bm_obj(name, bm, mkey, methods)
    m = ob.modifiers.new("s", "SOLIDIFY"); m.thickness = t; m.offset = -1; m.use_even_offset = True
    return apply_mods(ob)

def glazing(hole, s=1.0, tracery=False, glow=False, glass=None):
    """窗扇：玻璃（实体化）+ 中梃 / 横档（挤出）+ 窗框（曲线倒角沿洞口）；尖拱窗加双尖券花格 + 圆环（旋绕）。"""
    kind, cx, z0, w, h = hole
    poly = opening(*hole)
    bm = bmesh.new(); bm.faces.new([bm.verts.new((x, 0.25 * s, z)) for x, z in poly])
    g = bm_obj("glass", bm, GLOW if glow else (glass or GLASS), ("solidify",))
    m = g.modifiers.new("s", "SOLIDIFY"); m.thickness = 0.03; apply_mods(g)
    fr = CB("wframe", [(x, 0.12 * s, z) for x, z in poly + poly[:1]], 0.09 * s, IRON)
    sp = spring_of(kind, z0, w, h)
    parts = [g, fr, BX("mull", cx - 0.07 * s, 0.1 * s, z0, cx + 0.07 * s, 0.22 * s, sp if kind != "rect" else z0 + h, IRON)]
    nt = max(1, int((sp - z0) / (2.6 * s)))
    tr = BX("transom", cx - w / 2, 0.1 * s, z0 + (sp - z0) / (nt + 1) - 0.06 * s, cx + w / 2, 0.22 * s, z0 + (sp - z0) / (nt + 1) + 0.06 * s, IRON)
    array(tr, nt, (0, 0, (sp - z0) / (nt + 1)))
    parts.append(tr)
    if tracery and kind == "pointed":
        for sx in (-1, 1):
            sub = opening("pointed", cx + sx * w / 4, sp - w * 0.1, w / 2 - 0.2 * s, w * 0.55)
            parts.append(CB("subarch", [(x, 0.14 * s, z) for x, z in sub[2:]], 0.07 * s, IRON))
        ring = spin("trac_ring", [(w * 0.18, -0.07 * s), (w * 0.18 + 0.12 * s, -0.07 * s), (w * 0.18 + 0.12 * s, 0.07 * s), (w * 0.18, 0.07 * s)], IRON, steps=16)
        ring.rotation_euler = (math.pi / 2, 0, 0); ring.location = (cx, 0.14 * s, sp + w * 0.42)
        parts.append(ring)
    return join(parts, "glazing")

def surround(hole, s=1.0, mkey=None, key=True):
    """洞口线脚：沿洞口（不封底）的方截面曲线倒角 + 拱心石（截面挤出）。"""
    kind, cx, z0, w, h = hole
    poly = opening(kind, cx, z0, w + 0.36 * s, h + 0.18 * s)
    pts = poly[1:] + poly[:1]
    parts = [CB("surr", [(x, -0.12 * s, z) for x, z in pts], 0.2 * s, mkey)]
    if key and kind in ("round", "pointed"):
        top = max(z for _, z in poly)
        parts.append(PX("keystone", [(-0.34 * s, top - 0.55 * s), (0.05, top - 0.55 * s), (0.05, top + 0.25 * s), (-0.34 * s, top + 0.25 * s)], 0.7 * s, mkey, cx - 0.35 * s))
    return join(parts, "surround")

def sill(cx, z, w, s, mkey):
    return PX("sill", [(0.05, z - 0.2 * s), (-0.35 * s, z - 0.2 * s), (-0.35 * s, z), (0.05, z + 0.05 * s)], w + 0.6 * s, mkey, cx - (w + 0.6 * s) / 2)

def pediment(cx, z, w, rise, s, mkey, kind="tri"):
    """窗楣：三角山花（半坡挤出 + 镜像）/ 弧形山花（曲线倒角弧 + 平檐）/ 平檐板。"""
    if kind == "tri":
        ang = math.atan2(rise, w / 2)
        half = _kpx("pedi", [(-0.45 * s, 0), (0.05, 0), (0.05, 0.22 * s), (-0.45 * s, 0.22 * s)], (w / 2) / math.cos(ang), mkey, "x")
        half.matrix_world = Matrix.Translation((cx - w / 2, 0, z)) @ Matrix.Rotation(-ang, 4, "Y")
        bake(half); mirror(half, 0, (cx, 0, 0))
        base = BX("pedi_base", cx - w / 2, -0.45 * s, z - 0.2 * s, cx + w / 2, 0.05, z, mkey)
        return [half, base]
    if kind == "seg":
        sag = rise * 0.6; R = (w * w / 4 + sag * sag) / (2 * sag); a0 = math.asin(min(1, w / 2 / R))
        arc = CB("seg", [(cx + R * math.sin(a), -0.22 * s, z + sag - R * (1 - math.cos(a))) for a in (-a0 + 2 * a0 * i / 12 for i in range(13))], 0.2 * s, mkey)
        return [arc, BX("seg_flat", cx - w / 2 + 0.2, -0.4 * s, z - 0.2 * s, cx + w / 2 - 0.2, 0.05, z, mkey)]
    return [PX("head", [(0.05, z - 0.1 * s), (-0.4 * s, z - 0.1 * s), (-0.5 * s, z + 0.15 * s), (0.05, z + 0.25 * s)], w + 0.5 * s, mkey, cx - (w + 0.5 * s) / 2)]

def _rust_arr(s, n, step):
    """横缝石：一条凸出石带按层距阵列（array）。"""
    return array(s, n, (0, 0, step))

def pilaster(x, z0, z1, s, mkey):
    """巨柱式壁柱：柱身（挤出）+ 凹槽（阵列）+ 柱础 / 柱头（分层挤出）。x 为中心。"""
    pw = 0.9 * s
    parts = [BX("pil", x - pw / 2, -0.35 * s, z0 + 0.5 * s, x + pw / 2, 0.02, z1 - 0.7 * s, mkey)]
    fl = BX("flute", x - pw / 2 + 0.12 * s, -0.38 * s, z0 + 0.9 * s, x - pw / 2 + 0.2 * s, -0.33 * s, z1 - 1.1 * s, K(9, "d8d0bf"))
    parts.append(array(fl, 4, (pw / 5, 0, 0)))
    parts.append(BX("pil_base", x - pw * 0.7, -0.5 * s, z0, x + pw * 0.7, 0.02, z0 + 0.5 * s, mkey))
    parts.append(PX("pil_cap", [(0.02, z1 - 0.7 * s), (-0.38 * s, z1 - 0.7 * s), (-0.6 * s, z1 - 0.2 * s), (-0.6 * s, z1), (0.02, z1)], pw * 1.5, mkey, x - pw * 0.75))
    return join(parts, "pilaster")

def cornice(L, s, mkey):
    """大檐口：多层线脚截面挤出 + 牛腿（阵列）+ 齿饰（阵列）。z=0 为檐口底。"""
    k = s
    prof = [(0.02, 0), (-0.2 * k, 0), (-0.2 * k, 0.25 * k), (-0.5 * k, 0.38 * k), (-0.5 * k, 0.65 * k), (-1.25 * k, 0.78 * k), (-1.4 * k, 0.98 * k), (-1.4 * k, 1.22 * k), (-1.15 * k, 1.35 * k), (0.02, 1.35 * k)]
    c = PX("cornice", prof, L, mkey)
    mod = PX("modillion", [(-0.5 * k, 0.65 * k), (-1.2 * k, 0.75 * k), (-1.2 * k, 0.66 * k), (-0.8 * k, 0.48 * k), (-0.5 * k, 0.42 * k)], 0.3 * k, mkey, 0.35 * k)
    array(mod, max(1, int(L / (0.9 * k))), (0.9 * k, 0, 0))
    den = BX("dentil", 0.1 * k, -0.32 * k, 0.04 * k, 0.26 * k, -0.18 * k, 0.22 * k, mkey)
    array(den, max(1, int(L / (0.32 * k))), (0.32 * k, 0, 0))
    return join([c, mod, den], "cornice")

def balustrade(L, s, mkey):
    """女儿墙栏杆：底座 / 扶手（挤出）+ 车削瓶形栏杆（旋绕）阵列 + 两端墩柱（镜像）。"""
    k = s
    parts = [BX("bal_base", 0, -0.3 * k, 0, L, 0.4 * k, 0.3 * k, mkey), BX("bal_rail", 0, -0.35 * k, 1.2 * k, L, 0.45 * k, 1.45 * k, mkey)]
    prof = [(0.12 * k, 0), (0.16 * k, 0.07 * k), (0.09 * k, 0.18 * k), (0.17 * k, 0.48 * k), (0.13 * k, 0.7 * k), (0.08 * k, 0.8 * k), (0.12 * k, 0.86 * k), (0.12 * k, 0.9 * k), (0, 0.9 * k)]
    b = spin("baluster", prof, mkey, steps=6); b.location = (0.6 * k, 0.05, 0.3 * k); bake(b)
    n = max(2, int((L - 1.2 * k) / (0.6 * k)))
    array(b, n, ((L - 1.2 * k) / (n - 1), 0, 0))
    ped = BX("ped", 0, -0.4 * k, 0, 0.7 * k, 0.5 * k, 1.6 * k, mkey)
    mirror(ped, 0, (L / 2, 0, 0))
    parts += [b, ped]
    return join(parts, "balustrade")

def column(h, r, mkey, seg=12):
    """独立柱：带收分的车削柱身（旋绕）+ 柱础 / 柱头（旋绕）+ 方顶板（挤出）。原点柱底中心。"""
    shaft = spin("shaft", [(r, 0.6 * r), (r * 1.02, h * 0.33), (r * 0.86, h - 0.9 * r)], mkey, steps=seg)
    base = spin("cbase", [(r * 1.5, 0), (r * 1.5, 0.3 * r), (r * 1.2, 0.45 * r), (r * 1.25, 0.55 * r), (r, 0.6 * r)], mkey, steps=seg)
    cap = spin("ccap", [(r * 0.86, h - 0.9 * r), (r * 1.05, h - 0.6 * r), (r * 1.45, h - 0.3 * r), (r * 1.45, h)], mkey, steps=seg)
    ab = BX("abacus", -r * 1.6, -r * 1.6, h, r * 1.6, r * 1.6, h + 0.25 * r, mkey)
    return join([shaft, base, cap, ab], "column")

# ------------------------------------------------------------------ 立面开间（按层）
def bay(w, storeys, kinds, pal, s, t=0.6):
    """一个开间的整列立面：storeys=[(z0,z1)…]，kinds 对应每层的开窗方式：
    'arch'（底层大拱窗 + 横缝石）/'portal:dw:dh:floor'（主入口，洞口与规划门洞一致）/'win_tri'/'win_seg'/'win_flat'/'win_balc'
    /'lancet'（哥特尖窗带花格）/'oculus'（阁楼圆窗）/'blank'/'open'（敞开拱廊）。返回对象列表（立面坐标）。"""
    out = []
    for (z0, z1), kind in zip(storeys, kinds):
        h = z1 - z0
        if kind == "blank":
            out.append(place(cell("wall", w, h, pal["wall"], None, t), Matrix.Translation((0, 0, z0)))); continue
        if kind.startswith("portal"):
            _, dw, dh, fl = kind.split(":"); dw, dh, fl = float(dw), float(dh), float(fl)
            hole = ("round" if dh >= dw * 0.75 else "rect", w / 2, fl, dw, dh)
            out.append(place(cell("portal_wall", w, h, pal["base"], hole, t), Matrix.Translation((0, 0, z0))))
            # 阶梯式拱券（多道曲线倒角，逐层外凸）+ 两侧柱（旋绕）+ 门洞上方铁艺扇窗
            for k in range(3):
                po = opening(hole[0], w / 2, fl, dw + (0.7 + 0.7 * k) * s, dh + (0.35 + 0.35 * k) * s)
                out.append(place(CB("archivolt", [(x, -0.15 * s * (k + 1), z) for x, z in po[1:] + po[:1]], 0.22 * s, pal["trim"]), Matrix.Translation((0, 0, z0))))
            for sx in (-1, 1):
                c = column(min(dh * 0.62, h - 1), 0.32 * s, pal["trim"])
                place(c, Matrix.Translation((w / 2 + sx * (dw / 2 + 1.4 * s), -0.7 * s, z0 + fl)))
                out.append(c)
            continue
        if kind == "open":
            hole = ("round", w / 2, 0.0, w * 0.72, h * 0.86)
            out.append(place(cell("arcade", w, h, pal["base"], hole, t), Matrix.Translation((0, 0, z0))))
            out.append(place(surround(hole, s, pal["trim"]), Matrix.Translation((0, 0, z0)))); continue
        if kind == "arch":
            ww = min(w * 0.56, 7 * s); hh = h * 0.72; zz = h * 0.12
            hole = ("round", w / 2, zz, ww, hh)
            out.append(place(cell("arch_wall", w, h, pal["base"], hole, t), Matrix.Translation((0, 0, z0))))
            out.append(place(glazing(hole, s), Matrix.Translation((0, 0, z0))))
            out.append(place(surround(hole, s, pal["trim"]), Matrix.Translation((0, 0, z0))))
            for x0, x1 in ((0, w / 2 - ww / 2 - 0.5 * s), (w / 2 + ww / 2 + 0.5 * s, w)):
                if x1 - x0 > 0.4:
                    out.append(place(_rust_arr(BX("rust", x0, -0.12 * s, 0, x1, 0.02, 0.62 * s - 0.1, pal["base"]), max(1, int(h / (0.62 * s)) - 1), 0.62 * s), Matrix.Translation((0, 0, z0 + 0.3))))
            continue
        if kind == "lancet":
            ww = min(w * 0.5, 4.6 * s); hh = h * 0.78; zz = h * 0.1
            hole = ("pointed", w / 2, zz, ww, hh)
            out.append(place(cell("lancet_wall", w, h, pal["wall"], hole, t), Matrix.Translation((0, 0, z0))))
            out.append(place(glazing(hole, s, tracery=True), Matrix.Translation((0, 0, z0))))
            out.append(place(surround(hole, s, pal["trim"], key=False), Matrix.Translation((0, 0, z0))))
            continue
        if kind == "oculus":
            d = min(w * 0.42, h * 0.7)
            hole = ("circle", w / 2, (h - d) / 2, d, d)
            out.append(place(cell("attic_wall", w, h, pal["wall"], hole, t), Matrix.Translation((0, 0, z0))))
            out.append(place(glazing(hole, s), Matrix.Translation((0, 0, z0))))
            out.append(place(surround(hole, s * 0.8, pal["trim"], key=False), Matrix.Translation((0, 0, z0))))
            continue
        # 标准层窗：高窗 + 窗套 + 窗台 + 窗楣变体（balc 落地窗 + 弓形铁艺阳台）
        balc = kind == "win_balc"
        ww = min(w * 0.42, 3.4 * s)
        zz = 0.25 * s if balc else h * 0.17
        hh = h * (0.7 if balc else 0.6)
        hole = ("round" if kind == "win_seg" else "rect", w / 2, zz, ww, hh)
        out.append(place(cell("win_wall", w, h, pal["wall"], hole, t), Matrix.Translation((0, 0, z0))))
        out.append(place(glazing(hole, s), Matrix.Translation((0, 0, z0))))
        out.append(place(surround(hole, s, pal["trim"], key=kind == "win_seg"), Matrix.Translation((0, 0, z0))))
        if not balc:
            out.append(place(sill(w / 2, zz, ww, s, pal["trim"]), Matrix.Translation((0, 0, z0))))
        ptype = {"win_tri": "tri", "win_seg": "flat", "win_flat": "flat", "win_balc": "tri"}[kind]
        for o in pediment(w / 2, zz + hh + 0.35 * s, ww + 1.0 * s, 0.9 * s, s, pal["trim"], ptype):
            out.append(place(o, Matrix.Translation((0, 0, z0))))
        if balc:
            L = ww + 2.2 * s
            slab = PX("balc", [(0.02, 0), (-1.2 * s, 0), (-1.2 * s, 0.24 * s), (-1.05 * s, 0.36 * s), (0.02, 0.36 * s)], L, pal["trim"])
            bars = BX("bbar", 0.05, -0.04, 0.36 * s, 0.11, 0.04, 1.5 * s, IRON); array(bars, int(L / (0.22 * s)), (0.22 * s, 0, 0))
            rail = BX("brail", 0, -0.06, 1.45 * s, L, 0.06, 1.58 * s, IRON)
            for o in (slab, bars, rail):
                kit.curve_deform(o, [(L * i / 12, -0.35 * s * math.sin(math.pi * i / 12), 0) for i in range(13)], "POS_X")
                if o is not slab:
                    o.location.y = -1.0 * s
                place(o, Matrix.Translation((w / 2 - L / 2, 0, z0)))
                out.append(o)
    return out

def facade(L, storeys, pattern, pal, s, t=0.6):
    """整面立面：L 长，按开间数 n 等分；pattern(i, n) → 每层 kind 列表。开间之间巨柱式壁柱（upper 层段）。"""
    n = max(1, round(L / (9.0 * s)))
    bw = L / n
    parts = []
    for i in range(n):
        for o in bay(bw, storeys, pattern(i, n), pal, s, t):
            parts.append(place(o, Matrix.Translation((i * bw, 0, 0))))
    return parts, n, bw

# ------------------------------------------------------------------ 屋顶
def mansard_rect(w, d, z0, hr, inset, mkey, dormers=None, s=1.0, pal=None):
    """矩形芒萨尔：底环（外出 0.5）与顶环（内收 inset）两圈轮廓桥接（bridge）成四坡 + 顶面锌皮（挤出）+ 屋脊铁艺花冠（阵列）。
    dormers=[(side, x_local, w)]：老虎窗（墙板开洞 + 三角山花 + 玻璃），side ∈ front/back。原点在建筑中心。"""
    bm = bmesh.new()
    lo = [(-w / 2 - 0.5, -d / 2 - 0.5), (w / 2 + 0.5, -d / 2 - 0.5), (w / 2 + 0.5, d / 2 + 0.5), (-w / 2 - 0.5, d / 2 + 0.5)]
    hi = [(-w / 2 + inset, -d / 2 + inset), (w / 2 - inset, -d / 2 + inset), (w / 2 - inset, d / 2 - inset), (-w / 2 + inset, d / 2 - inset)]
    a = [bm.verts.new((x, y, z0)) for x, y in lo]; b = [bm.verts.new((x, y, z0 + hr)) for x, y in hi]
    e1 = [bm.edges.new((a[i], a[(i + 1) % 4])) for i in range(4)]; e2 = [bm.edges.new((b[i], b[(i + 1) % 4])) for i in range(4)]
    bmesh.ops.bridge_loops(bm, edges=e1 + e2)
    bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    r = bm_obj("mansard", bm, mkey, ("bridge",))
    parts = [r]
    parts.append(CB("eave_roll", [(x, y, z0 + 0.1) for x, y in lo + lo[:1]], 0.22 * s, ZINC))
    parts.append(CB("curb_roll", [(x, y, z0 + hr + 0.05) for x, y in hi + hi[:1]], 0.16 * s, ZINC))
    cw = w - 2 * inset - 1
    if cw > 2:
        cr = BX("crest", -cw / 2, -0.05, z0 + hr, -cw / 2 + 0.08, 0.05, z0 + hr + 1.1 * s, IRON)
        array(cr, int(cw / (0.6 * s)), (0.6 * s, 0, 0))
        place(cr, Matrix.Translation((0, -d / 2 + inset, 0)))
        parts.append(cr)
    ang = math.atan2(hr, inset + 0.5)
    for side, xl, dw in (dormers or []):
        fr_w, fr_h = dw, min(hr * 0.6, dw * 1.5)
        hole = ("round", fr_w / 2, 0.35 * fr_h * 0.4, fr_w * 0.55, fr_h * 0.7)
        dw_ = cell("dormer", fr_w, fr_h, pal["trim"], hole, 0.3)
        gl = glazing(hole, s * 0.6)
        ped = pediment(fr_w / 2, fr_h + 0.2, fr_w + 0.4, fr_h * 0.35, s * 0.7, pal["trim"], "tri")
        cheek = PX("cheek", [(0.0, 0), (inset + 0.5, 0), (0.0, fr_h)], 0.2, ZINC, -0.2); mirror(cheek, 0, (fr_w / 2, 0, 0))
        dj = join([dw_, gl, cheek] + ped, "dormer")
        yoff = (inset + 0.5) * 0.35
        xf = Matrix.Translation((xl - fr_w / 2, -d / 2 - 0.5 + yoff, z0 + hr * 0.18)) if side == "front" else \
            Matrix.Translation((xl + fr_w / 2, d / 2 + 0.5 - yoff, z0 + hr * 0.18)) @ Matrix.Rotation(math.pi, 4, "Z")
        parts.append(place(dj, xf))
    return join(parts, "roof")

def pavilion_roof(size, h, mkey, s=1.0):
    """帝国式钟形亭顶：钟形截面旋绕 4 段（screw）转 45°+ 顶部铁艺花冠（阵列）+ 尖顶（旋绕）。原点亭底中心。"""
    r = size / 2 * math.sqrt(2)
    prof = [(r + 0.4, 0), (r, 0.5), (r * 0.9, h * 0.35), (r * 0.66, h * 0.75), (r * 0.32, h * 0.95), (r * 0.28, h)]
    roof = kit.screw("pav", prof, mkey, steps=4); roof.rotation_euler.z = math.pi / 4; bake(roof)
    top = BX("pav_top", -size * 0.2, -size * 0.2, h, size * 0.2, size * 0.2, h + 0.3, ZINC)
    fin = spin("pav_fin", [(0.3 * s, 0), (0.45 * s, 0.5 * s), (0.12 * s, 1.0 * s), (0.25 * s, 1.5 * s), (0.04 * s, 3.6 * s), (0, 3.7 * s)], IRON, steps=8)
    fin.location.z = h + 0.3; bake(fin)
    cr = BX("pcrest", -size * 0.2, -size * 0.2 - 0.04, h + 0.3, -size * 0.2 + 0.08, -size * 0.2 + 0.04, h + 1.3 * s, IRON)
    array(cr, 8, (size * 0.4 / 7, 0, 0)); mirror(cr, 1, (0, 0, 0))
    return join([roof, top, fin, cr], "pavilion_roof")

def dome(r, mkey, pal, s=1.0, drum_h=None, ribs=12, colonnade=True, lantern=True, seg=24):
    """穹顶组：鼓座（旋绕）+ 环形柱廊（柱子环形阵列）+ 穹面（旋绕）+ 金肋（曲线倒角环形阵列）+ 采光亭（柱环形阵列 + 亭帽旋绕）。原点鼓座底中心。"""
    dh = drum_h or r * 0.55
    parts = [spin("drum", [(r + 0.6, 0), (r + 0.6, dh * 0.15), (r, dh * 0.2), (r, dh), (r + 0.8, dh + 0.3 * s), (r + 0.8, dh + 0.7 * s), (r - 0.2, dh + 0.7 * s)], pal["wall"], steps=seg)]
    if colonnade:
        c = column(dh * 0.75, 0.32 * s * max(1, r / 8), pal["trim"]); c.location = (r + 0.9 * s, 0, dh * 0.2); bake(c)
        parts.append(radial(c, max(8, int(r * 1.6))))
        parts.append(spin("drum_ring", [(r + 1.6 * s, dh * 0.95), (r + 1.6 * s, dh + 0.3 * s), (r, dh + 0.3 * s)], pal["trim"], steps=seg))
    z = dh + 0.7 * s
    prof = [(r, z)] + [(r * math.cos(a), z + r * 0.92 * math.sin(a)) for a in (math.pi / 2 * i / 12 for i in range(1, 12))] + [(r * 0.16, z + r * 0.92)]
    parts.append(spin("dome", prof, mkey, steps=seg))
    rib = CB("rib", [(r * math.cos(a) + 0.04, 0, z + r * 0.92 * math.sin(a)) for a in (math.pi / 2 * i / 12 for i in range(13)) if r * math.cos(a) > r * 0.16], 0.12 * s * max(1, r / 8), pal["accent"])
    parts.append(radial(rib, ribs))
    zt = z + r * 0.92
    if lantern:
        lr = r * 0.16
        lc = spin("lcol", [(0.12 * s, 0), (0.12 * s, lr * 2.2), (0, lr * 2.2)], pal["trim"], steps=6); lc.location = (lr, 0, zt); bake(lc)
        parts.append(radial(lc, 8))
        parts.append(spin("lglass", [(lr * 0.8, zt), (lr * 0.8, zt + lr * 2.2)], GLOW, steps=8))
        parts.append(spin("lcap", [(lr * 1.3, zt + lr * 2.2), (lr * 1.2, zt + lr * 2.5), (lr * 0.5, zt + lr * 3.4), (0.12 * s, zt + lr * 4.2), (0.04 * s, zt + lr * 5.8), (0, zt + lr * 5.9)], mkey, steps=12))
    return join(parts, "dome")

def glass_vault(L, span, rise, s, pal):
    """铁骨玻璃拱顶（市场 / 车站）：拱形截面挤出成玻璃面（实体化）+ 铁拱肋（曲线倒角，阵列）+ 两端半圆山墙铁格（曲线倒角）。原点：沿 +X 长 L，跨度 span 沿 Y 居中，z=0 起拱。"""
    arc = [(span / 2 * math.cos(a), rise * math.sin(a)) for a in (math.pi * i / 16 for i in range(17))]
    bm = bmesh.new()
    rows = [[bm.verts.new((x, y, z)) for y, z in arc] for x in (0, L)]
    for i in range(len(arc) - 1):
        bm.faces.new((rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]))
    g = bm_obj("vault_glass", bm, GLASS, ("profile_extrude", "solidify"))
    m = g.modifiers.new("s", "SOLIDIFY"); m.thickness = 0.04; apply_mods(g)
    rib = CB("vault_rib", [(0, y, z + 0.05) for y, z in arc], 0.14 * s, IRON)
    n = max(2, int(L / (3.2 * s)))
    array(rib, n + 1, (L / n, 0, 0))
    purl = CB("purlin", [(0, 0, rise + 0.08), (L, 0, rise + 0.08)], 0.12 * s, IRON)
    gable = []
    for x in (0, L):
        for k in range(1, 5):
            yk = span / 2 * k / 5
            zk = rise * math.sqrt(max(0, 1 - (yk / (span / 2)) ** 2))
            gable.append(CB("gbar", [(x, yk, 0), (x, yk, zk)], 0.06 * s, IRON)); gable.append(CB("gbar", [(x, -yk, 0), (x, -yk, zk)], 0.06 * s, IRON))
    return join([g, rib, purl] + gable, "glass_vault")

def gothic_roof(L, span, rise, mkey, s, pal):
    """哥特陡坡屋顶：三角截面挤出（沿 X）+ 屋脊铁艺花冠（阵列）。原点：沿 +X、跨度沿 Y 居中、z=0 檐口。"""
    r = PX("groof", [(-span / 2 - 0.6, 0), (span / 2 + 0.6, 0), (0, rise)], L, mkey)
    cr = BX("gcrest", 0, -0.05, rise, 0.1, 0.05, rise + 1.4 * s, IRON); array(cr, max(2, int(L / (0.7 * s))), (0.7 * s, 0, 0))
    return join([r, cr], "gothic_roof")

def spire(r, h, mkey, s=1.0, lucarnes=True):
    """八角尖塔：八角锥截面旋绕 8 段（screw）+ 小老虎窗（环形阵列）+ 顶饰（旋绕）。原点塔底中心。"""
    sp = kit.screw("spire", [(r + 0.3, 0), (r, 0.6 * s), (r * 0.12, h * 0.96), (0.05, h)], mkey, steps=8)
    sp.rotation_euler.z = math.pi / 8; bake(sp)
    parts = [sp]
    if lucarnes:
        lu = BX("lucarne", r * 0.55 - 0.6 * s, -0.7 * s, h * 0.18, r * 0.55 + 0.4 * s, 0.7 * s, h * 0.18 + 2.4 * s, K(9, "eee6d4"))
        lr = PX("lroof", [(-0.9 * s, 0), (0.9 * s, 0), (0, 1.2 * s)], 1.4 * s, mkey); lr.rotation_euler.z = math.pi / 2; lr.location = (r * 0.55 + 0.4 * s, -0.0, h * 0.18 + 2.4 * s); bake(lr)
        parts.append(radial(join([lu, lr], "luc"), 4))
    parts.append(spin("sfin", [(0.25 * s, h), (0.4 * s, h + 0.6 * s), (0.1 * s, h + 1.4 * s), (0.2 * s, h + 2.0 * s), (0.03 * s, h + 4.5 * s), (0, h + 4.6 * s)], pal_gold(), steps=8))
    return join(parts, "spire")

def pal_gold():
    return K(5, "d6a64a")

def pinnacle(r, h, mkey, s=1.0):
    """尖塔小顶（哥特扶壁顶）：方墩（挤出）+ 四角锥（旋绕 4 段）+ 球饰。原点底中心。"""
    b = BX("pin_base", -r, -r, 0, r, r, h * 0.4, mkey)
    c = kit.screw("pin_cone", [(r * 1.414 + 0.05, h * 0.4), (0.05, h)], mkey, steps=4); c.rotation_euler.z = math.pi / 4; bake(c)
    k = spin("pin_knob", [(0, h - 0.05), (0.18 * s, h + 0.1 * s), (0, h + 0.35 * s)], mkey, steps=6)
    return join([b, c, k], "pinnacle")

def buttress(h, depth, wid, mkey, s=1.0):
    """阶梯式扶壁（分段截面挤出，向上收进）+ 顶部尖塔小顶。立面坐标：贴在外墙面 y=0 外侧（-Y），x 居中 0。"""
    prof = [(0.05, 0), (-depth, 0), (-depth, h * 0.45), (-depth * 0.7, h * 0.52), (-depth * 0.7, h * 0.8), (-depth * 0.4, h * 0.86), (-depth * 0.4, h), (0.05, h)]
    b = PX("buttress", prof, wid, mkey, -wid / 2)
    p = pinnacle(wid * 0.45, 3.2 * s, mkey, s); p.location = (0, -depth * 0.4, h); bake(p)
    return join([b, p], "buttress")

def flying_buttress(x, y_out, y_in, z_out, z_in, s, mkey):
    """飞扶壁：从扶壁顶到中殿墙的弧形撑臂（曲线倒角，方截面）+ 上沿压顶（曲线倒角）。"""
    pts = []
    for i in range(13):
        t = i / 12
        y = y_out + (y_in - y_out) * t
        z = z_out + (z_in - z_out) * t + math.sin(math.pi * t) * -1.2 * s
        pts.append((x, y, z))
    arm = CB("flyer", pts, 0.42 * s, mkey)
    top = CB("flyer_top", [(px, py, pz + 1.0 * s + 0.4 * math.sin(math.pi * i / 12)) for i, (px, py, pz) in enumerate(pts)], 0.25 * s, mkey)
    return join([arm, top], "flying_buttress")

def iron_cage(r, h, s, pal):
    """铁艺玻璃观景笼（参考图 4）：12 道尖拱铁肋（曲线倒角）环形阵列 + 卷草纹拱心（曲线倒角）+ 上下铁环（旋绕）+ 玻璃圆筒（旋绕）+ 平台楼板（旋绕）。原点笼底中心。"""
    n = 12
    half = math.pi / n
    ribs = []
    for sx in (-1, 1):
        a = sx * half
        pts = [((r) * math.cos(a), (r) * math.sin(a), z) for z in (0, h * 0.62)]
        ribs.append(CB("cage_post", pts, 0.16 * s, IRON))
    # 每格顶部尖券（在两根柱间的竖直平面内）
    arch = []
    for i in range(9):
        t = i / 8
        a = -half + 2 * half * t
        z = h * 0.62 + h * 0.3 * math.sin(math.pi * t) ** 0.7
        arch.append((r * math.cos(a), r * math.sin(a), z))
    ribs.append(CB("cage_arch", arch, 0.12 * s, IRON))
    swirl = [(r * math.cos(0.18 * math.cos(u) * (1 - u / 14)) + 0.05, r * math.sin(0.18 * math.cos(u) * (1 - u / 14)), h * 0.72 + 0.9 * s * math.sin(u) * (1 - u / 14)) for u in (k * 0.45 for k in range(30))]
    ribs.append(CB("cage_swirl", swirl, 0.05 * s, IRON))
    mullion = CB("cage_mull", [(r * math.cos(0.0), 0, 0), (r, 0, h * 0.62 + h * 0.3 - 0.4)], 0.06 * s, IRON)
    ribs.append(mullion)
    unit = join(ribs, "cage_unit")
    radial(unit, n)
    glass = spin("cage_glass", [(r - 0.08, 0), (r - 0.08, h * 0.62), (r * 0.9, h * 0.92)], GLASS, steps=n * 2)
    rings = [spin("cage_ring%d" % k, [(r - 0.2, z), (r + 0.25, z), (r + 0.25, z + 0.3 * s), (r - 0.2, z + 0.3 * s)], IRON, steps=n * 2) for k, z in enumerate((0, h * 0.3, h * 0.62))]
    roof = spin("cage_roof", [(r * 0.9, h * 0.92), (r * 0.55, h * 1.02), (0, h * 1.06)], IRON, steps=n * 2)
    deck = spin("cage_deck", [(0, -0.4), (r + 1.6 * s, -0.4), (r + 1.6 * s, 0.0), (0, 0.0)], pal["trim"], steps=n * 2)
    rail = BX("deck_rail", r + 1.3 * s, -0.04, 0, r + 1.38 * s, 0.04, 1.2 * s, IRON); radial(rail, n * 6)
    return join([unit, glass, roof, deck, rail] + rings, "iron_cage")

def airship(L, s, pal):
    """飞艇：气囊（旋绕椭球）+ 纵向箍带（曲线倒角，环形阵列）+ 吊舱（截面挤出）+ 尾翼（挤出 + 镜像）+ 螺旋桨（旋绕）。沿 +X，原点气囊中心。"""
    R = L * 0.17
    prof = [(0.0, -L / 2)] + [(R * math.sin(math.pi * i / 16) ** 0.8, -L / 2 + L * i / 16) for i in range(1, 16)] + [(0.0, L / 2)]
    env = spin("envelope", prof, K(0, "efe6d2", "st_plaster", 4.0), steps=20)
    env.rotation_euler = (0, math.pi / 2, 0); bake(env)
    band = CB("band", [(-L / 2 + L * i / 16, 0, R * math.sin(math.pi * i / 16) ** 0.8 + 0.05) for i in range(17)], 0.1 * s, K(5, "b9873f"))
    band.rotation_euler.x = 0; radial_x(band, 8)
    # 吊舱：船形截面（YZ）沿 X 挤出，顶贴气囊下缘；吊索（曲线倒角）
    gon2 = PX("gondola", [(-R * 0.3, -R - 3.2 * s), (R * 0.3, -R - 3.2 * s), (R * 0.42, -R - 0.6 * s), (-R * 0.42, -R - 0.6 * s)], L * 0.42, WOOD, -L * 0.21)
    cables = [CB("cable", [(x, 0, -R * 0.75), (x, 0, -R - 0.6 * s)], 0.06 * s, IRON) for x in (-L * 0.18, 0.0, L * 0.18)]
    # 尾翼：竖直三角翼（截面在 XZ 平面 → 用 YZ 截面挤出后绕 Z 转 90°）上下镜像 + 水平翼
    fin = _kpx("fin", [(0.0, 0.0), (L * 0.16, 0.0), (0.0, R * 0.8)], 0.3, K(4, "a9503c", "st_roof_barrel", 2.0), "x")
    fin.rotation_euler.z = -math.pi / 2; fin.location = (L * 0.5 - L * 0.16 - 0.5, 0.15, R * 0.45); bake(fin)
    mirror(fin, 2, (0, 0, 0))
    hfin = _kpx("hfin", [(0.0, 0.0), (L * 0.16, 0.0), (0.0, R * 0.8)], 0.3, K(4, "a9503c", "st_roof_barrel", 2.0), "x")
    hfin.rotation_euler = (math.pi / 2, 0, -math.pi / 2); hfin.location = (L * 0.5 - L * 0.16 - 0.5, R * 0.45, 0.15); bake(hfin)
    mirror(hfin, 1, (0, 0, 0))
    fin = join([fin, hfin] + cables, "fins")
    prop = spin("prop", [(0.0, -0.1), (2.2 * s, 0.0), (0.0, 0.1)], K(5, "b9873f"), steps=3)
    prop.rotation_euler = (0, math.pi / 2, 0); prop.location = (-L * 0.25, 0, -R - 3.6 * s); bake(prop)
    return join([env, band, gon2, fin, prop], "airship")

def radial_x(ob, n):
    """绕 X 轴的环形阵列（飞艇箍带）。"""
    bake(ob)
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], cent=(0, 0, 0), axis=(1, 0, 0), angle=2 * math.pi * (n - 1) / n, steps=n - 1, use_duplicate=True)
    bm.to_mesh(ob.data); bm.free()
    return tag(ob, "array")

def _rot_yz(ob):
    # 吊舱截面在 YZ 平面，沿 X 挤出：已经是正确朝向（y 为横向，z 为竖向）
    return ob

def _fin_place(fin, L, R):
    fin.location = (L * 0.3, 0, R * 0.55); bake(fin)
    return fin
