# 晴岚港功能建筑 v2 模块（2026-10-09 用户确认的概念图 docs/city_lm_concepts/v2：奇幻哥特，装饰比参考图收敛一档，向洛奇M 卡通化体块靠拢）
# 语汇：暖砂岩方石墙 + 浅奶油线脚；每个开间之间一根阶梯扶壁，冲出檐口成铜绿尖顶小塔（金色顶饰）；
# 少而巨大的尖拱窗（蓝玻璃 + 中梃 + 小圆花格）；底层尖拱券；中央山墙门楼（深尖拱门 + 阶梯拱券 + 门楣尖山花 + 玫瑰窗），两侧红锥顶圆角楼；
# 陡坡红陶瓦屋顶 + 铜绿屋脊 + 成排尖顶老虎窗；方塔分层 + 钟 + 角尖塔 + 铜绿八角尖顶 / 钟形穹顶；红底金纹大旗帜。
# 手法同 modkit 十手法（bridge / solidify / profile_extrude / curve_bevel / screw / array / mirror / simple_deform / curve_deform / vertex）。
# 立面坐标：沿 +X 0..w，外立面 y=0 朝 -Y，墙向 +Y 长厚度；z 向上。
import bpy, bmesh, math
from mathutils import Matrix, Vector
import kit, monument as mo
from monument import BX, PX, CB, spin, radial, place, bake, join, K, IRON, ZINC

def palette(roof="red"):
    roofs = {"red": K(4, "c0573c", "st_roof_barrel", 2.2), "copper": K(5, "4f9583"), "slate": K(3, "4b5670", "st_roof_scale", 2.6),
             "violet": K(3, "6a5a92", "st_roof_scale", 2.6), "dark": K(3, "3e4350", "st_roof_scale", 2.6)}
    # 墙用光面大方石（building.gdshader mtype 9 的大块石缝），暖金砂岩色；概念图 v2 是干净的大块石，不是粗毛石
    return dict(wall=K(9, "e2c48e"), base=K(9, "d1b07a"), trim=K(9, "f4e4c0"),
                roof=roofs.get(roof, roofs["red"]), copper=K(5, "4f9583"), gold=K(5, "d9a83e"), glass=K("glass", "4f78a8", "", 0),
                banner=K(0, "a8232e"), accent=K(5, "d9a83e"), cone=K(4, "c0573c", "st_roof_barrel", 2.0))

def finial(h, s, pal):
    """金色顶饰（旋绕）。原点底。"""
    return spin("finial", [(0.0, 0), (0.18 * s, 0.05), (0.32 * s, 0.35 * s), (0.12 * s, 0.75 * s), (0.2 * s, 0.95 * s), (0.03 * s, h), (0, h + 0.05)], pal["gold"], steps=8)

def pinnacle(r, h, s, pal):
    """尖顶小塔：方墩（挤出）+ 四面小尖券山花（截面挤出 + 环形阵列）+ 铜绿四角锥（旋绕 4 段）+ 金顶饰。原点底中心。"""
    shaft = BX("pin_shaft", -r, -r, 0, r, r, h * 0.42, pal["trim"])
    gab = PX("pin_gablet", [(-r - 0.05, h * 0.42), (r + 0.05, h * 0.42), (0, h * 0.42 + r * 1.3)], 0.15 * s, pal["trim"], -r - 0.12 * s)
    gab.rotation_euler.z = math.pi / 2; bake(gab)
    radial(gab, 4)
    cone = kit.screw("pin_cone", [(r * 1.414 + 0.08, h * 0.42), (r * 0.9, h * 0.5), (0.06, h)], pal["copper"], steps=4)
    cone.rotation_euler.z = math.pi / 4; bake(cone)
    fn = finial(1.2 * s, s, pal); fn.location.z = h; bake(fn)
    return join([shaft, gab, cone, fn], "pinnacle")

def buttress(H, s, pal, depth=None, wid=None, over=None):
    """阶梯扶壁（分段截面挤出、向上两次收进）+ 冲出檐口的尖顶小塔。立面坐标：x 居中 0，向 -Y 外凸。H = 檐口高。"""
    depth = depth or 1.7 * s; wid = wid or 1.5 * s; over = over if over is not None else 2.4 * s
    prof = [(0.05, 0), (-depth, 0), (-depth, H * 0.38), (-depth * 0.72, H * 0.44), (-depth * 0.72, H * 0.78), (-depth * 0.45, H * 0.84), (-depth * 0.45, H + over), (0.05, H + over)]
    b = PX("buttress", prof, wid, pal["base"], -wid / 2)
    p = pinnacle(wid * 0.42, 6.5 * s, s, pal); p.location = (0, -depth * 0.45 + wid * 0.2, H + over); bake(p)
    return join([b, p], "buttress")

def eave(L, s, pal):
    """檐口：方截面阶梯线脚（挤出）+ 铜绿天沟（挤出）+ 下方小尖券饰带（截面挤出 + 阵列）。z=0 为檐口底。"""
    prof = [(0.05, 0), (-0.35 * s, 0), (-0.35 * s, 0.45 * s), (-0.8 * s, 0.6 * s), (-0.8 * s, 1.1 * s), (0.05, 1.1 * s)]
    c = PX("eave", prof, L, pal["trim"])
    gut = PX("gutter", [(-0.8 * s, 1.1 * s), (-1.1 * s, 1.1 * s), (-1.1 * s, 1.45 * s), (0.05, 1.45 * s), (0.05, 1.1 * s)], L, pal["copper"])
    arc = PX("corbel", [(0.02, -0.7 * s), (-0.3 * s, -0.7 * s), (-0.3 * s, 0.0), (0.02, 0.0)], 0.35 * s, pal["trim"], 0.3 * s)
    kit.array(arc, max(1, int(L / (1.1 * s))), (1.1 * s, 0, 0))
    return join([c, gut, arc], "eave")

def lancet_cell(w, h, kind, pal, s, t=0.7):
    """一层一格：'arcade' 底层尖拱窗 / 'lancet' 巨型尖窗 / 'small' 檐下小尖窗 / 'blank' / 'portal:dw:dh:fl'（门洞与规划一致）。
    返回立面坐标对象列表（z 从 0 起）。"""
    out = []
    if kind == "blank":
        return [mo.cell("wall", w, h, pal["wall"], None, t)]
    if kind.startswith("portal"):
        _, dw, dh, fl = kind.split(":"); dw, dh, fl = float(dw), float(dh), float(fl)
        hole = ("pointed" if dh >= dw * 0.9 else "round", w / 2, fl, dw, dh)
        out.append(mo.cell("portal_wall", w, h, pal["base"], hole, t))
        # 深门洞：三道逐层外凸的尖拱券（曲线倒角）+ 门侧细柱（旋绕）+ 门楣尖山花（三角截面挤出）+ 门内暖光
        for k in range(3):
            po = mo.opening(hole[0], w / 2, fl, dw + (1.0 + 1.0 * k) * s, dh + (0.5 + 0.6 * k) * s)
            out.append(CB("archivolt", [(x, -0.25 * s * (k + 1), z) for x, z in po[1:] + po[:1]], 0.3 * s, pal["trim"]))
        for sx in (-1, 1):
            c = spin("jamb", [(0.35 * s, fl), (0.35 * s, fl + dh * 0.62), (0.0, fl + dh * 0.62)], pal["trim"], steps=8)
            c.location = (w / 2 + sx * (dw / 2 + 1.2 * s), -0.6 * s, 0); bake(c); out.append(c)
        top = fl + dh + 2.2 * s
        gw = dw + 4.4 * s
        tri = PX("wimperg_tri", [(-gw / 2, top - 0.8 * s), (gw / 2, top - 0.8 * s), (0, top + gw * 0.55)], 0.5 * s, pal["trim"], 0)
        tri.rotation_euler.z = math.pi / 2; tri.location = (w / 2, -0.95 * s, 0); bake(tri); out.append(tri)
        for sx in (-1, 1):
            p = pinnacle(0.45 * s, 4.0 * s, s, pal); p.location = (w / 2 + sx * gw / 2, -0.75 * s, top - 0.8 * s); bake(p); out.append(p)
        glow = BX("portal_glow", w / 2 - dw / 2 + 0.3, t * 0.9, fl, w / 2 + dw / 2 - 0.3, t * 0.95, fl + dh * 0.8, K("glow", "ffcf8a", "", 0))
        out.append(glow)
        return out
    if kind == "arcade":
        ww, hh, zz = min(w * 0.6, 5.6 * s), h * 0.8, h * 0.1
    elif kind == "lancet":
        ww, hh, zz = min(w * 0.52, 5.0 * s), h * 0.84, h * 0.08
    else:   # small
        ww, hh, zz = min(w * 0.34, 2.6 * s), h * 0.62, h * 0.2
    hole = ("pointed", w / 2, zz, ww, hh)
    out.append(mo.cell(kind + "_wall", w, h, pal["wall"] if kind != "arcade" else pal["base"], hole, t))
    out.append(mo.glazing(hole, s, tracery=kind != "small", glass=pal["glass"]))
    out.append(mo.surround(hole, s * 1.3, pal["trim"], key=False))
    out.append(mo.sill(w / 2, zz, ww, s * 1.2, pal["trim"]))
    return out

def facade(L, tiers, kinds_of, pal, s, bay_w=8.6, H=None, buttresses=True, t=0.7):
    """整面立面：L 按开间数等分（目标开间宽 bay_w·s），tiers=[(z0,z1)…]；kinds_of(i,n) → 每层 kind。
    开间分界（含两端）立阶梯扶壁，扶壁顶冲出檐口成尖顶小塔。返回 (对象列表, n, bw)。"""
    n = max(1, round(L / (bay_w * s)))
    bw = L / n
    parts = []
    for i in range(n):
        for (z0, z1), kind in zip(tiers, kinds_of(i, n)):
            for o in lancet_cell(bw, z1 - z0, kind, pal, s, t):
                parts.append(place(o, Matrix.Translation((i * bw, 0, z0))))
    if buttresses:
        Ht = H if H is not None else tiers[-1][1]
        for i in range(n + 1):
            parts.append(place(buttress(Ht, s, pal), Matrix.Translation((i * bw, 0, 0))))
    return parts, n, bw

def dormer(w_, h_, s, pal):
    """尖顶老虎窗：墙板开尖窗洞（桥接 + 实体化）+ 蓝玻璃 + 两侧颊板（挤出 + 镜像）+ 铜绿尖坡顶（三角截面挤出）+ 金顶饰。原点底面前沿中点。"""
    hole = ("pointed", w_ / 2, h_ * 0.18, w_ * 0.5, h_ * 0.7)
    wall = mo.cell("dormer_wall", w_, h_, pal["trim"], hole, 0.35)
    gl = mo.glazing(hole, s * 0.6, glass=pal["glass"])
    cheek = PX("cheek", [(0.0, 0.0), (2.2 * s, 0.0), (0.0, h_)], 0.22, pal["wall"], -0.22)
    mirror(cheek, 0, (w_ / 2, 0, 0))
    ridge = PX("dormer_gable", [(-w_ / 2 - 0.3, h_ - 0.1), (w_ / 2 + 0.3, h_ - 0.1), (0, h_ + w_ * 0.8)], 2.8 * s, pal["copper"], 0)
    ridge.rotation_euler.z = math.pi / 2; ridge.location = (w_ / 2, -0.4, 0); bake(ridge)
    fn = finial(0.9 * s, s * 0.7, pal); fn.location = (w_ / 2, -0.3, h_ + w_ * 0.8); bake(fn)
    dj = join([wall, gl, cheek, ridge, fn], "dormer")
    dj.data.transform(Matrix.Translation((-w_ / 2, 0, 0)))
    return dj

def mirror(ob, axis, center):
    return kit.mirror(ob, axis, center)

def hip_roof(w, d, z0, rise, s, pal, dormer_x=(), ridge_mat=None):
    """陡坡四坡红瓦屋顶：底环（外出 0.8）与屋脊线两圈轮廓桥接（bridge）+ 铜绿屋脊（挤出）+ 屋脊花冠（阵列）；
    dormer_x：正 / 背坡上的老虎窗 x 位置（建筑坐标）。原点建筑中心。"""
    o = 0.8
    ins = min(w, d) / 2 - 0.6                         # 屋脊收进量（接近人字）
    bm = bmesh.new()
    lo = [(-w / 2 - o, -d / 2 - o), (w / 2 + o, -d / 2 - o), (w / 2 + o, d / 2 + o), (-w / 2 - o, d / 2 + o)]
    hi = [(-w / 2 + ins, -d / 2 + ins), (w / 2 - ins, -d / 2 + ins), (w / 2 - ins, d / 2 - ins), (-w / 2 + ins, d / 2 - ins)]
    a = [bm.verts.new((x, y, z0)) for x, y in lo]; b = [bm.verts.new((x, y, z0 + rise)) for x, y in hi]
    e1 = [bm.edges.new((a[i], a[(i + 1) % 4])) for i in range(4)]; e2 = [bm.edges.new((b[i], b[(i + 1) % 4])) for i in range(4)]
    bmesh.ops.bridge_loops(bm, edges=e1 + e2)
    bm.faces.new(b)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    roof = kit.bm_obj("hip_roof", bm, pal["roof"], ("bridge",))
    rl = max(0.6, w - 2 * ins) if w >= d else max(0.6, d - 2 * ins)
    ridge = BX("ridge", -rl / 2 - 0.4, -0.45 * s, z0 + rise - 0.2, rl / 2 + 0.4, 0.45 * s, z0 + rise + 0.45 * s, pal["copper"])
    if d > w:
        ridge.rotation_euler.z = math.pi / 2; bake(ridge)
    cr = BX("crest", -rl / 2, -0.05, z0 + rise + 0.45 * s, -rl / 2 + 0.12, 0.05, z0 + rise + 1.4 * s, pal["gold"])
    kit.array(cr, max(2, int(rl / (0.9 * s))), (0.9 * s, 0, 0))
    if d > w:
        cr.rotation_euler.z = math.pi / 2; bake(cr)
    parts = [roof, ridge, cr]
    run = ins + o
    for x in dormer_x:
        for side in (-1, 1):
            dm = dormer(2.4 * s, 3.4 * s, s, pal)
            f = 0.22                                   # 老虎窗坐在坡面下部 22% 处
            yy = -d / 2 - o + run * f
            xf = Matrix.Translation((x, yy, z0 + rise * f)) if side < 0 else Matrix.Translation((x, -yy, z0 + rise * f)) @ Matrix.Rotation(math.pi, 4, "Z")
            parts.append(place(dm, xf))
    return join(parts, "hip_roof")

def gable_wall(fw, rise, s, pal, rose=True):
    """山墙门楼的三角山墙：三角截面挤出（厚 0.9）+ 玫瑰窗（旋绕环 + 玻璃盘 + 十字花格）+ 顶 / 两肩尖顶小塔。原点：底边左端、外立面 y=0。"""
    tri = PX("gable", [(-fw / 2, 0), (fw / 2, 0), (0, rise)], 0.9, pal["wall"], 0)
    # 截面在 YZ 平面沿 X 挤出，绕 Z 转 90° 后挤出方向变为 +Y（墙厚向内），截面横轴变为 X
    tri.rotation_euler.z = math.pi / 2; tri.location = (fw / 2, 0.0, 0); bake(tri)
    parts = [tri]
    cop = PX("gable_coping", [(-fw / 2 - 0.4, -0.2), (fw / 2 + 0.4, -0.2), (0, rise + 0.5)], 1.3, pal["trim"], 0)
    cop.rotation_euler.z = math.pi / 2; cop.location = (fw / 2, -0.2, 0); bake(cop)
    parts.append(cop)
    if rose:
        r = min(fw * 0.2, rise * 0.3)
        ring = spin("rose_ring", [(r, -0.35), (r + 0.55 * s, -0.35), (r + 0.55 * s, 0.25), (r, 0.25)], pal["trim"], steps=20)
        ring.rotation_euler = (math.pi / 2, 0, 0); ring.location = (fw / 2, -0.15, rise * 0.4); bake(ring)
        disc = spin("rose_glass", [(0, 0), (r + 0.05, 0)], pal["glass"], steps=20)
        disc.rotation_euler = (math.pi / 2, 0, 0); disc.location = (fw / 2, 0.05, rise * 0.4); bake(disc)
        bars = [CB("rose_bar", [(fw / 2 + r * math.cos(a), -0.2, rise * 0.4 + r * math.sin(a)), (fw / 2 - r * math.cos(a), -0.2, rise * 0.4 - r * math.sin(a))], 0.09 * s, pal["trim"]) for a in (0, math.pi / 4, math.pi / 2, 3 * math.pi / 4)]
        hub = spin("rose_hub", [(0, -0.3), (r * 0.25, -0.3), (r * 0.25, 0.1), (0, 0.1)], pal["trim"], steps=12)
        hub.rotation_euler = (math.pi / 2, 0, 0); hub.location = (fw / 2, -0.1, rise * 0.4); bake(hub)
        parts += [ring, disc, hub] + bars
    for x, z, k in ((0, 0, 0.9), (fw, 0, 0.9), (fw / 2, rise, 1.2)):
        p = pinnacle(0.55 * s * k, 5.0 * s * k, s, pal); p.location = (x, -0.3, z); bake(p); parts.append(p)
    return join(parts, "gable_wall")

def round_turret(r, H, s, pal, cone_h=None, start=0.0):
    """圆角楼：圆柱塔身（旋绕）+ 两圈线脚环（旋绕）+ 小尖窗（玻璃片沿圆周环形阵列）+ 挑檐托（阵列）+ 红锥顶（旋绕）+ 铜绿环 + 金顶饰。原点塔底中心。"""
    cone_h = cone_h or r * 2.6
    parts = [spin("turret_body", [(r, start), (r, H)], pal["wall"], steps=16)]
    for z in (start + (H - start) * 0.45, H - 0.6 * s):
        parts.append(spin("turret_ring", [(r - 0.05, z), (r + 0.35 * s, z), (r + 0.35 * s, z + 0.45 * s), (r - 0.05, z + 0.45 * s)], pal["trim"], steps=16))
    win = BX("turret_win", -0.55 * s, -r - 0.04, start + (H - start) * 0.58, 0.55 * s, -r + 0.2, start + (H - start) * 0.58 + 2.4 * s, pal["glass"])
    parts.append(radial(win, 4))
    cor = BX("turret_corbel", -0.25 * s, -r - 0.5 * s, H - 1.4 * s, 0.25 * s, -r + 0.1, H - 0.6 * s, pal["trim"])
    parts.append(radial(cor, 12))
    parts.append(spin("turret_cone", [(r + 0.6 * s, H), (r + 0.45 * s, H + 0.4 * s), (r * 0.4, H + cone_h * 0.62), (0.08, H + cone_h)], pal["cone"], steps=16))
    parts.append(spin("turret_cone_ring", [(r + 0.65 * s, H - 0.1), (r + 0.75 * s, H + 0.25 * s), (r + 0.35 * s, H + 0.35 * s)], pal["copper"], steps=16))
    fn = finial(1.4 * s, s, pal); fn.location.z = H + cone_h; bake(fn); parts.append(fn)
    return join(parts, "round_turret")

def side_xf(side, w, d):
    if side == "front":
        return Matrix.Translation((-w / 2, -d / 2, 0))
    if side == "right":
        return Matrix.Translation((w / 2, -d / 2, 0)) @ Matrix.Rotation(math.pi / 2, 4, "Z")
    if side == "back":
        return Matrix.Translation((w / 2, d / 2, 0)) @ Matrix.Rotation(math.pi, 4, "Z")
    return Matrix.Translation((-w / 2, d / 2, 0)) @ Matrix.Rotation(-math.pi / 2, 4, "Z")

def tower(cx, cy, z0, z1, size, s, pal, top="spire", clock=True, skirt_from=None, banners=True, skirt_sides=("front", "left")):
    """方塔：分层（每层四面尖窗墙板）+ 四角扶壁条 + 层间线脚 + 钟层（四面钟）+ 钟楼尖窗层 + 顶（铜绿八角尖顶 + 四角尖塔 / 铜绿钟形穹顶 + 采光亭）。
    skirt_from：塔身从 z0 起；若给出则 skirt_from..z0 只做外侧两面（贴建筑转角的塔「落地」外皮，不进大厅）。原点 (cx,cy)。"""
    parts = []
    topH = size * (2.6 if top == "spire" else 1.4)
    body_top = max(z0 + size * 1.6, z1 - topH)
    H = body_top - z0
    nst = max(2, round(H / (size * 0.95)))
    tiers = [(H * i / nst, H * (i + 1) / nst) for i in range(nst)]
    kinds = ["lancet" if j < nst - 1 else "small" for j in range(nst)]
    for side in ("front", "right", "back", "left"):
        xf = Matrix.Translation((cx, cy, z0)) @ side_xf(side, size, size)
        for i, (a, b) in enumerate(tiers):
            for o in lancet_cell(size, b - a, kinds[i], pal, s * 0.85):
                parts.append(place(o, xf @ Matrix.Translation((0, 0, a))))
            parts.append(place(BX("tband", -0.3, -0.45 * s, b - 0.35 * s, size + 0.3, 0.05, b + 0.25 * s, pal["trim"]), xf))
        if clock:
            zc = tiers[-1][0] - size * 0.08
            cf = spin("clock", [(0.0, 0.0), (size * 0.27, 0.0), (size * 0.27, 0.2), (size * 0.32, 0.2), (size * 0.32, -0.1)], K(9, "f6ecd2"), steps=24)
            cf.rotation_euler = (math.pi / 2, 0, 0); cf.location = (size / 2, -0.3, zc); bake(cf)
            rim = spin("clock_rim", [(size * 0.32, -0.15), (size * 0.36, -0.15), (size * 0.36, 0.25), (size * 0.32, 0.25)], pal["gold"], steps=24)
            rim.rotation_euler = (math.pi / 2, 0, 0); rim.location = (size / 2, -0.35, zc); bake(rim)
            h1 = BX("hand", size / 2 - 0.15, -0.6, zc, size / 2 + 0.15, -0.45, zc + size * 0.22, IRON)
            h2 = BX("hand2", size / 2, -0.6, zc - 0.12, size / 2 + size * 0.16, -0.45, zc + 0.12, IRON)
            for o in (cf, rim, h1, h2):
                parts.append(place(o, xf))
        if banners and side in ("front", "left"):
            parts.append(place(banner(size * 0.28, H * 0.42, s, pal), xf @ Matrix.Translation((size * 0.25, -0.35, H * 0.35))))
    if skirt_from is not None and skirt_from < z0:
        for side in skirt_sides:
            xf = Matrix.Translation((cx, cy, skirt_from)) @ side_xf(side, size, size)
            hs = z0 - skirt_from
            parts.append(place(mo.cell("tower_skirt", size, hs, pal["wall"], ("pointed", size / 2, hs * 0.3, size * 0.4, hs * 0.55), 0.7), xf))
            parts.append(place(mo.glazing(("pointed", size / 2, hs * 0.3, size * 0.4, hs * 0.55), s, tracery=True, glass=pal["glass"]), xf))
    for sx in (-1, 1):
        for sy in (-1, 1):
            q = BX("tcorner", -0.75 * s, -0.75 * s, (skirt_from if skirt_from is not None else z0), 0.75 * s, 0.75 * s, z0 + H + 0.6 * s, pal["trim"])
            parts.append(place(q, Matrix.Translation((cx + sx * size / 2, cy + sy * size / 2, 0))))
            p = pinnacle(0.85 * s, 7.0 * s, s, pal)
            parts.append(place(p, Matrix.Translation((cx + sx * size / 2, cy + sy * size / 2, z0 + H + 0.6 * s))))
    zt = z0 + H
    parts.append(place(BX("tcap", -size / 2 - 0.6, -size / 2 - 0.6, zt, size / 2 + 0.6, size / 2 + 0.6, zt + 0.8 * s, pal["trim"]), Matrix.Translation((cx, cy, 0))))
    if top == "spire":
        sp = kit.screw("spire", [(size * 0.42, 0), (size * 0.4, 1.0 * s), (size * 0.06, (z1 - zt) * 0.95), (0.05, z1 - zt)], pal["copper"], steps=8)
        sp.rotation_euler.z = math.pi / 8; sp.location = (cx, cy, zt + 0.8 * s); bake(sp); parts.append(sp)
        lu = BX("lucarne", -0.9 * s, -size * 0.42 - 0.3, 0, 0.9 * s, -size * 0.25, 3.2 * s, pal["trim"])
        lr = PX("lucarne_roof", [(-1.2 * s, 3.2 * s), (1.2 * s, 3.2 * s), (0, 5.2 * s)], size * 0.2, pal["copper"], 0)
        lr.rotation_euler.z = math.pi / 2; lr.location = (0, -size * 0.42 - 0.4, 0); bake(lr)
        luc = join([lu, lr], "lucarnes"); radial(luc, 4); place(luc, Matrix.Translation((cx, cy, zt + (z1 - zt) * 0.12)))
        parts.append(luc)
        fn = finial(2.5 * s, s * 1.4, pal); fn.location = (cx, cy, z1 + 0.8 * s); bake(fn); parts.append(fn)
    else:
        bell = [(size * 0.5 + 0.4, 0), (size * 0.5, 0.6 * s), (size * 0.47, size * 0.35), (size * 0.33, size * 0.62), (size * 0.14, size * 0.78), (size * 0.12, size * 0.82)]
        bd = kit.screw("bell", bell, pal["copper"], steps=8); bd.rotation_euler.z = math.pi / 8; bd.location = (cx, cy, zt + 0.8 * s); bake(bd); parts.append(bd)
        zl = zt + 0.8 * s + size * 0.82
        lc = spin("lantern_col", [(0.15 * s, 0), (0.15 * s, size * 0.3), (0, size * 0.3)], pal["trim"], steps=6); lc.location = (size * 0.12, 0, 0); bake(lc); radial(lc, 6)
        place(lc, Matrix.Translation((cx, cy, zl))); parts.append(lc)
        cap = spin("lantern_cap", [(size * 0.17, size * 0.3), (size * 0.15, size * 0.36), (0.06, size * 0.58)], pal["copper"], steps=8)
        place(cap, Matrix.Translation((cx, cy, zl))); parts.append(cap)
        fn = finial(2.0 * s, s * 1.2, pal); fn.location = (cx, cy, zl + size * 0.58); bake(fn); parts.append(fn)
    return parts

def banner(w, h, s, pal):
    """大旗帜：铁横杆（挤出）+ 红布（截面挤出，下摆燕尾）+ 金色徽章（旋绕菱形）+ 金色镶边（曲线倒角）。立面坐标：上沿中点为原点。"""
    rod = BX("banner_rod", -w / 2 - 0.4, -0.5, -0.12, w / 2 + 0.4, -0.25, 0.12, IRON)
    cloth = PX("banner_cloth", [(-0.55, 0), (-0.45, 0), (-0.45, -h), (-0.55, -h)], w, pal["banner"], -w / 2)
    for v in cloth.data.vertices:                        # 燕尾：下沿中点上提（几何顶点）
        if v.co.z < -h + 0.01:
            v.co.z += (h * 0.12) * (1 - abs(v.co.x) / (w / 2)) if abs(v.co.x) < w / 2 else 0
    mo.tag(cloth, "vertex")
    emb = spin("emblem", [(0, -0.1), (w * 0.28, -0.1), (w * 0.28, 0.1), (0, 0.1)], pal["gold"], steps=4)
    emb.rotation_euler = (math.pi / 2, 0, math.pi / 4); emb.location = (0, -0.62, -h * 0.38); bake(emb)
    edge = CB("banner_edge", [(-w / 2, -0.6, -0.2), (-w / 2, -0.6, -h), (0, -0.6, -h * 0.88), (w / 2, -0.6, -h), (w / 2, -0.6, -0.2)], 0.06 * s, pal["gold"])
    return join([rod, cloth, emb, edge], "banner")
