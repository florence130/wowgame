# 铁匠铺专用构件（参考 docs/city_ref 之外的用户图：棕色木瓦屋面、砖砌大烟囱 + 炉膛、敞棚锻炉、铁砧、铁匠铺牌匾 + 锤子招牌）。
# 全部在 Blender 里用「十手法」手建：镜像 / 阵列 / 截面挤出 / 实体化 / 曲线倒角 / 旋绕 / 桥接 / 顶点；对称件只建一半再镜像。
# 尺寸一律是放大后的真实米制（MMO 尺度），盖章进房屋时和 parts.py 的构件一样乘 1/1.6。
# 坐标：外墙面 y=0、向 -Y 伸出；Z 向上；原点见各函数说明。
import bpy, bmesh, math, random
from mathutils import Vector, Matrix
import kit
import parts
from parts import (B, PX, at, beam, thin, sym_jitter, join, array, mirror, screw, curve_bevel, profile_extrude, bm_obj, apply_mods, new_obj)

kit.PAL.update({
    "bark": "K|6|6b4a32|pt_bark|0.9", "logtop": "K|0|c8a06e||3.0", "ringdark": "K|0|8a5e3a||3.0", "steel": "K|7|9aa3ad|pt_steel|1.3", "darksteel": "K|7|4a4f58|pt_steel|1.3", "mail": "K|7|7a838d|pt_metal|1.6", "leather": "K|0|7a4a2a|pt_leather|1.4",
    "leather2": "K|0|a8754a|pt_leather|1.4", "brick": "K|2|b9733f|pt_brick|1.8", "brickd": "K|2|8a5636|pt_brick|1.8", "shake": "K|3|8c6a4a|pt_shake|2.4",
    "plankroof": "K|6|8a6a44|pt_wood|1.6", "soot": "K|0|2a2220||3.0", "coal": "K|0|26262c||3.0", "ember": "K|glow|ff8a30||3.0",
    "water": "K|glass|4d6a8a||0", "plaqueblue": "K|6|39455a|pt_wood|1.6", "brass": "K|7|c79a3c|pt_metal|2.0", "cloth": "K|0|a8362e||3.0",
    "log": "K|6|7a5638|pt_wood|1.2", "flag": "K|2|a8a392|pt_ashlar|2.4",
})
EMBER_OK = True


def bk(ob):
    ob.data.transform(ob.matrix_basis)
    ob.matrix_basis = Matrix.Identity(4)
    return ob


# ---------------------------------------------------------------- 小件
def blade(L=1.0, w=0.07, t=0.02, mk="steel"):
    """剑身：截面（x,z）渐尖多边形沿 y 挤出；原点在护手位置（z=0），向上 L。"""
    pts = [(-w / 2, 0), (w / 2, 0), (w / 2 * 0.9, L * 0.8), (0, L), (-w / 2 * 0.9, L * 0.8)]
    ob = PX("blade", pts, t, mk, 0.0, "y")
    ob.data.transform(Matrix.Translation((0, -t / 2, 0)))
    return ob


def sword(L=0.95, mk_blade="steel"):
    b = blade(L, 0.075, 0.022, mk_blade)
    g = B("guard", 0.34, 0.05, 0.05, 0, 0, -0.03, "brass")
    grip = screw("grip", [(0.0, -0.3), (0.022, -0.3), (0.022, -0.03), (0.0, -0.03)], "leather", 8)
    pom = screw("pom", [(0.0, -0.36), (0.045, -0.34), (0.045, -0.31), (0.0, -0.3)], "brass", 8)
    return join([b, g, grip, pom], "sword")


def axe_head_pts():
    return [(0.0, 0.0), (0.16, -0.05), (0.2, -0.16), (0.16, -0.27), (0.0, -0.22)]


def axe():
    haft = B("haft", 0.045, 0.045, 1.0, 0, 0, -0.3, "log")
    head = PX("ahead", axe_head_pts(), 0.03, "steel", 0.0, "y")
    head.data.transform(Matrix.Translation((0.02, -0.015, 0.95)))
    head2 = PX("ahead2", [(-x, z) for x, z in axe_head_pts()], 0.03, "steel", 0.0, "y")
    head2.data.transform(Matrix.Translation((-0.02, -0.015, 0.95)))
    for h in (head, head2):
        pass
    return join([haft, head, head2], "axe")


def mace():
    haft = B("haft", 0.045, 0.045, 0.85, 0, 0, -0.3, "log")
    hd = screw("mhead", [(0.0, 0.0), (0.07, 0.0), (0.1, 0.08), (0.1, 0.16), (0.07, 0.24), (0.0, 0.24)], "darksteel", 10)
    hd.location = (0, 0, 0.55)
    fl = B("fl", 0.24, 0.025, 0.1, 0, 0, 0.62, "darksteel")
    fl2 = B("fl2", 0.025, 0.24, 0.1, 0, 0, 0.62, "darksteel")
    return join([haft, hd, fl, fl2], "mace")


def round_shield(r=0.42, face="cloth"):
    """圆盾：旋绕盾面（碟形）+ 铁盾钉 + 铁边；盾面朝 -Y（竖放：绕 X 转 90°）。原点在盾心。"""
    dish = screw("dish", [(0.0, 0.07), (0.1, 0.06), (r * 0.7, 0.03), (r, 0.0), (r, -0.03), (r * 0.7, 0.0), (0.1, 0.03), (0.0, 0.04)], face, 20)
    rim = curve_bevel("rim", [(r * math.cos(a), r * math.sin(a), 0.0) for a in (2 * math.pi * i / 24 for i in range(24))], 0.02, "darksteel", closed=True)
    boss = screw("boss", [(0.0, 0.14), (0.07, 0.12), (0.1, 0.07), (0.1, 0.04), (0.0, 0.04)], "steel", 12)
    o = join([dish, rim, boss], "shield")
    o.data.transform(Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Scale(1, 4))
    o.data.transform(Matrix.Rotation(math.pi, 4, "X"))
    return o


def helmet(kind="knight"):
    """头盔：旋绕盔体（圆顶 + 颈甲）+ 面甲缝 + 盔缨。原点在盔底中心。"""
    shell = screw("shell", [(0.0, 0.34), (0.1, 0.33), (0.17, 0.27), (0.19, 0.17), (0.2, 0.05), (0.2, 0.0), (0.17, 0.0), (0.17, 0.05), (0.15, 0.17), (0.13, 0.25), (0.0, 0.3)], "steel", 14)
    parts_ = [shell]
    if kind == "knight":
        visor = B("visor", 0.3, 0.03, 0.045, 0, -0.17, 0.18, "soot")
        ridge = B("ridge", 0.025, 0.1, 0.1, 0, -0.04, 0.31, "darksteel")
        plume = PX("plume", [(0, 0), (-0.06, 0.12), (-0.04, 0.24), (0.02, 0.2), (0.04, 0.08)], 0.04, "cloth", 0.0, "y")
        plume.data.transform(Matrix.Translation((0, 0.02, 0.33)))
        parts_ += [visor, ridge, plume]
    return join(parts_, "helmet")


# ---------------------------------------------------------------- 铁砧 + 树墩（原点：墩底中心；砧长轴沿 X，角朝 -X）
def p_anvil():
    stump = screw("stump", [(0.0, 0.0), (0.46, 0.0), (0.5, 0.06), (0.43, 0.3), (0.45, 0.6), (0.43, 0.63), (0.0, 0.63)], "bark", 14)          # 树皮侧面（pt_bark 竖向裂纹）
    sym_jitter(stump, 0.015, 21, (1, 1, 0.1))
    topd = screw("stoptop", [(0.0, 0.63), (0.43, 0.63), (0.43, 0.655), (0.0, 0.655)], "logtop", 14)                        # 锯平的树桩顶面（浅色木芯）
    rings = [screw("sring%d" % i, [(r0, 0.655), (r1, 0.655), (r1, 0.662), (r0, 0.662)], "ringdark", 14) for i, (r0, r1) in enumerate(((0.07, 0.085), (0.17, 0.185), (0.27, 0.285), (0.36, 0.375)))]   # 手建年轮（同心细环，贴在顶面上）
    ring = join([topd] + rings, "stoprings")
    pts = [(-0.32, 0.0), (0.32, 0.0), (0.32, 0.08), (0.15, 0.16), (0.13, 0.28), (0.42, 0.34), (0.42, 0.47), (-0.36, 0.47),
           (-0.82, 0.41), (-0.82, 0.38), (-0.4, 0.33), (-0.13, 0.28), (-0.15, 0.16), (-0.32, 0.08)]
    body = PX("anv", pts, 0.36, "darksteel", 0.0, "y")
    body.data.transform(Matrix.Translation((0, -0.18, 0.662)))
    face = B("face", 0.78, 0.38, 0.03, 0.03, 0.0, 1.13 + 0.002, "steel")
    hole = B("hardy", 0.06, 0.06, 0.035, 0.28, 0.0, 1.127, "soot")
    return join([stump, ring, body, face, hole], "anvil")


# ---------------------------------------------------------------- 内景砖砌炉膛（原点：贴墙地面中心，炉口朝 -Y；总高到 top）
def arch_notch(w, h_side, h_total, half, n=12):
    """正面轮廓（x,z）：宽 2*half、高 h_total 的块，底部中央开一个拱形炉口（宽 w，直壁 h_side）。"""
    r = w / 2
    pts = [(-half, 0), (-r, 0), (-r, h_side)]
    for i in range(1, n):
        a = math.pi - math.pi * i / n
        pts.append((r * math.cos(a), h_side + r * math.sin(a)))
    pts += [(r, h_side), (r, 0), (half, 0), (half, h_total), (-half, h_total)]
    return pts


def firebox_inside(w, depth, z0=0.18):
    """炉膛里的炉栅 / 柴 / 炭 / 火：对称的栅条（阵列）+ 一堆原木 + 发光炭火。炉口在 -Y 面，后壁在 y=-depth 处。"""
    items = []
    grate = B("grate_b", w * 0.82, 0.04, 0.04, 0, -depth * 0.5, z0, "iron")
    array(grate, 5, (0, 0.0, 0.0))
    bars = B("gbar", 0.035, depth * 0.8, 0.035, -w * 0.38, -depth * 0.5, z0, "iron")
    array(bars, 5, (w * 0.19, 0, 0))
    items += [bars]
    bed = B("embers", w * 0.7, depth * 0.55, 0.1, 0, -depth * 0.55, z0 + 0.04, "ember")
    coal = screw("coal", [(0.0, 0.0), (0.3, 0.0), (0.24, 0.1), (0.0, 0.14)], "coal", 8)
    coal.location = (0, -depth * 0.55, z0 + 0.08)
    coal.scale = (1.2, 0.9, 0.7)
    kit.apply_scale(coal)
    items += [bed, coal]
    for i, (dx, dy, rot) in enumerate(((-0.28, -depth * 0.45, 0.1), (0.05, -depth * 0.6, -0.15), (0.3, -depth * 0.5, 0.05))):
        lg = screw("log%d" % i, [(0.0, -0.3), (0.07, -0.3), (0.08, -0.28), (0.08, 0.28), (0.07, 0.3), (0.0, 0.3)], "bark", 8)
        lg.rotation_euler = (0, math.pi / 2, rot)
        lg.location = (dx, dy, z0 + 0.2 + 0.03 * i)
        kit.apply_scale(lg)
        items.append(lg)
    return items


def p_hearth(top=4.4, w=3.4, depth=1.9):
    """内景炉膛：砖砌炉座（拱形炉口）+ 逐级内收的砖烟罩 + 砖烟道到 top；炉里有栅 / 柴 / 炭火；左侧挂皮风箱，右侧一堆煤。原点贴墙。"""
    half = w / 2
    base_h = 1.45
    front = PX("hfront", arch_notch(1.5, 0.55, base_h, half), 0.4, "brick", 0.0, "y")
    front.data.transform(Matrix.Translation((0, -depth, 0)))
    # 炉口两侧 / 顶 / 后壁：与正面同轮廓的块沿深度往后接（只镂空炉口到 0.4 深度，其余为实心砖 + 烟熏后壁）
    mid = PX("hmid", arch_notch(1.5, 0.55, base_h, half), depth - 0.4 - 0.5, "brick", 0.0, "y")
    mid.data.transform(Matrix.Translation((0, -depth + 0.4, 0)))
    back = B("hback", w, 0.5, base_h, 0, -0.25, 0, "brickd")
    soot = B("soot", 1.5, 0.04, 0.95, 0, -depth + 0.4 + (depth - 0.4 - 0.5) + 0.02, 0.0, "soot")
    items = [front, mid, back, soot] + firebox_inside(1.5, depth - 0.5, 0.2)
    mantel = B("mantel", w + 0.3, depth + 0.2, 0.12, 0, -depth / 2, base_h, "flag")
    items.append(mantel)
    # 烟罩：四级内收的砖
    z = base_h + 0.12
    steps = [(w * 0.86, depth * 0.88, 0.4), (w * 0.62, depth * 0.72, 0.4), (w * 0.44, depth * 0.58, 0.4), (1.3, 0.95, 0.4)]
    for i, (sx, sy, h) in enumerate(steps):
        items.append(B("hood%d" % i, sx, sy, h, 0, -sy / 2, z, "brick"))
        z += h
    shaft = B("shaft", 1.3, 0.95, max(0.2, top - z), 0, -0.475, z, "brick")
    items.append(shaft)
    # 风箱：两块木板夹一圈皮褶（阵列）+ 铁嘴指向炉口
    bx = -half - 0.75
    bl = B("bel_b", 0.9, 0.8, 0.07, bx, -0.65, 0.62, "log")
    bt = B("bel_t", 0.9, 0.8, 0.07, bx, -0.65, 1.02, "log")
    fold = B("fold", 0.84, 0.74, 0.05, bx, -0.65, 0.7, "leather")
    array(fold, 6, (0, 0, 0.05))
    stand = B("bel_s", 0.12, 0.6, 0.62, bx, -0.65, 0.0, "timber")
    nozzle = screw("nozzle", [(0.0, 0.0), (0.07, 0.0), (0.035, 0.7), (0.0, 0.7)], "iron", 8)
    nozzle.rotation_euler = (0, math.pi / 2, 0)
    nozzle.location = (bx + 0.45, -0.65, 0.85)
    kit.apply_scale(nozzle)
    handle = beam("bel_h", (bx - 0.45, -0.65, 1.02), (bx - 1.0, -0.65, 1.5), 0.05, 0.05, "log")
    items += [bl, bt, fold, stand, nozzle, handle]
    # 煤堆（旋绕 + 顶点）
    heap = screw("heap", [(0.0, 0.0), (0.6, 0.0), (0.5, 0.18), (0.25, 0.34), (0.0, 0.4)], "coal", 8)
    sym_jitter(heap, 0.03, 31)
    heap.location = (half + 0.7, -0.65, 0.0)
    kit.apply_scale(heap)
    items.append(heap)
    return join(items, "hearth")


# ---------------------------------------------------------------- 外墙砖烟囱 + 炉口（原点：墙外面 y=0、地面；炉口朝 -X；烟囱高到 top）
def p_forge_chimney(top=10.4, wx=2.7, d=2.5):
    """贴在山墙外的大砖烟囱：矮炉座（侧面拱形炉口，里面有火 / 柴）+ 阶梯收分的肩 + 细长烟道 + 石压顶。炉口朝 -X。"""
    half = wx / 2
    base_h = 2.5
    # 正面（炉口所在的 -X 面）：用 YZ 平面轮廓沿 x 挤出一个薄饰面，炉口拱洞在其中
    pts = arch_notch(1.3, 0.7, base_h, d / 2)
    face = PX("cface", pts, 0.35, "brick", 0.0, "x")                 # 截面 (u=y, v=z) 沿 x 挤出
    face.data.transform(Matrix.Translation((-half, -d / 2, 0)))
    body = B("cbody", wx - 0.35, d, base_h, 0.175, -d / 2, 0, "brick")
    # 炉口里的炉栅 / 火（沿 -X 方向看进去：深度沿 +X，所以把 firebox_inside 的深度轴转到 X）
    fb = join(firebox_inside(1.1, 0.9, 0.18), "fb")
    fb.data.transform(Matrix.Rotation(-math.pi / 2, 4, "Z"))
    fb.data.transform(Matrix.Translation((-half + 0.35 + 0.45, -d / 2, 0)))
    soot = B("csoot", 0.04, 1.35, 1.2, -half + 0.35 + 0.95, -d / 2, 0.0, "soot")
    items = [face, body, fb, soot]
    # 柴堆：炉口旁几根圆木（阵列）
    lg = screw("clog", [(0.0, -0.45), (0.11, -0.45), (0.12, -0.42), (0.12, 0.42), (0.11, 0.45), (0.0, 0.45)], "bark", 8)
    lg.rotation_euler = (math.pi / 2, 0, 0)
    lg.location = (-half - 0.35, -d / 2 - 0.9, 0.12)
    kit.apply_scale(lg)
    array(lg, 3, (0.0, 0.28, 0.0))
    items.append(lg)
    # 肩：逐级收分
    z = base_h
    for i, (sx, sy, h) in enumerate(((wx - 0.1, d - 0.1, 0.35), (wx * 0.8, d * 0.8, 0.45), (wx * 0.6, d * 0.62, 0.55), (1.45, 1.45, 0.5))):
        items.append(B("shd%d" % i, sx, sy, h, 0.0 + (wx - sx) * 0.12, -sy / 2 - (d - sy) * 0.0, z, "brick"))
        z += h
    n = max(1, int((top - z - 0.3) / 0.35))
    shaft = B("shaft", 1.45, 1.45, 0.35, 0.0, -0.8, z, "brick")
    array(shaft, n, (0, 0, 0.35))
    sym_jitter(shaft, 0.012, 7, (1, 1, 0))
    zt = z + n * 0.35
    cap = B("ccap", 1.85, 1.85, 0.28, 0.0, -0.8, zt, "flag")
    cap2 = B("ccap2", 1.5, 1.5, 0.16, 0.0, -0.8, zt + 0.28, "flag")
    hole = B("chole", 0.9, 0.9, 0.02, 0.0, -0.8, zt + 0.44, "soot")
    items += [shaft, cap, cap2, hole]
    return join(items, "forge_chimney")


# ---------------------------------------------------------------- 敞棚锻炉（原点：棚贴墙一侧的前端地面，墙面 y=0；沿 +X 展开 Lsh、向 -Y 伸出 Dsh）
def p_forge_shed(Lsh=8.6, Dsh=6.8, hi=5.6, lo=3.9):
    items = []
    floor = B("sfloor", Lsh, Dsh, 0.14, Lsh / 2, -Dsh / 2, 0, "flag")
    items.append(floor)
    # 立柱：外缘一排（含两端），阵列 + 柱脚石墩；顶梁沿 X
    yp = -Dsh + 0.45
    post = B("spost", 0.3, 0.3, lo, 0.35, yp, 0.14, "timber")
    array(post, 3, ((Lsh - 0.7) / 2, 0, 0))
    base = B("sbase", 0.5, 0.5, 0.22, 0.35, yp, 0.14, "ashlar")
    array(base, 3, ((Lsh - 0.7) / 2, 0, 0))
    plate = B("splate", Lsh + 0.3, 0.36, 0.3, Lsh / 2, yp, lo - 0.02, "timber")
    items += [post, base, plate]
    # 墙侧挑梁座：贴墙一根水平梁，屋面斜梁（阵列）从墙梁搭到顶梁
    wbeam = B("wbeam", Lsh, 0.3, 0.3, Lsh / 2, -0.15, hi - 0.35, "timber")
    items.append(wbeam)
    raf = beam("raf", (0.2, -0.15, hi - 0.25), (0.2, yp, lo + 0.15), 0.22, 0.2, "timber")
    array(bk(raf), 9, ((Lsh - 0.4) / 8, 0, 0))
    items.append(raf)
    # 屋面：木板屋面（截面 YZ 平行四边形沿 X 挤出）+ 板缝压条（阵列）+ 前沿封檐板
    over = 0.55
    ye = -Dsh - over + 0.35
    # 屋面：垫层（深色薄板，板缝里露出来的暗线）+ 一条条顺坡向下的木板（截面平行四边形沿 X 挤出，阵列，间距留缝；奇偶板微差高低）
    under = PX("sunder", [(0.0, hi + 0.02), (ye, lo + 0.02), (ye, lo + 0.07), (0.0, hi + 0.07)], Lsh + 0.5, "timber", 0.0, "x")
    under.location.x = -0.1
    items.append(under)
    pw, gap = 0.3, 0.045
    npl = int((Lsh + 0.5) / (pw + gap))
    plank = PX("splank", [(0.0, hi + 0.07), (ye, lo + 0.07), (ye, lo + 0.15), (0.0, hi + 0.15)], pw, "plankroof", 0.0, "x")
    plank.location.x = -0.1
    array(plank, npl, (pw + gap, 0, 0))
    plank2 = PX("splank2", [(0.0, hi + 0.15), (ye, lo + 0.15), (ye, lo + 0.17), (0.0, hi + 0.17)], pw * 0.55, "plankroof", 0.0, "x")
    plank2.location.x = -0.1 + pw * 0.22
    array(plank2, (npl + 1) // 2, (2 * (pw + gap), 0, 0))
    items += [plank, plank2]
    # 前沿封檐板 + 两侧挡板
    fas = B("sfascia", Lsh + 0.5, 0.08, 0.26, Lsh / 2 + 0.15, ye, lo - 0.1, "timber")
    items.append(fas)    # 斜撑：每根立柱两面各一根（沿 X 的往梁里斜撑，镜像两端）
    br = beam("brx", (0.35, yp, lo - 1.3), (1.55, yp, lo - 0.05), 0.14, 0.14, "timber")
    mid = Lsh / 2
    br2 = beam("brx2", (Lsh - 0.35, yp, lo - 1.3), (Lsh - 1.55, yp, lo - 0.05), 0.14, 0.14, "timber")
    bry = beam("bry", (0.35, yp, lo - 1.4), (0.35, yp + 1.4, lo - 0.1), 0.14, 0.14, "timber")
    bry2 = beam("bry2", (Lsh - 0.35, yp, lo - 1.4), (Lsh - 0.35, yp + 1.4, lo - 0.1), 0.14, 0.14, "timber")
    items += [br, br2, bry, bry2]
    # 锻炉：砖炉座（拱形炉口朝 -Y）+ 砖烟罩逐级收到屋面下
    fh = 1.3
    fw = 3.4
    cx = Lsh * 0.5
    fg = PX("fg", arch_notch(1.5, 0.6, fh, fw / 2), 0.45, "brick", 0.0, "y")
    fg.data.transform(Matrix.Translation((cx, -1.9, 0.14)))
    fm = PX("fm", arch_notch(1.5, 0.6, fh, fw / 2), 1.0, "brick", 0.0, "y")
    fm.data.transform(Matrix.Translation((cx, -1.45, 0.14)))
    fb = B("fback", fw, 0.45, fh, cx, -0.225, 0.14, "brickd")
    fsoot = B("fsoot", 1.5, 0.04, 0.95, cx, -0.45, 0.14, "soot")
    items += [fg, fm, fb, fsoot]
    fire = join(firebox_inside(1.5, 1.4, 0.2), "fire")
    fire.data.transform(Matrix.Translation((cx, -0.5, 0.14)))
    items.append(fire)
    z = fh + 0.14
    for i, (sx, sy, h) in enumerate(((fw * 0.88, 1.7, 0.42), (fw * 0.64, 1.45, 0.42), (fw * 0.46, 1.2, 0.42), (1.3, 1.0, 0.42))):
        items.append(B("fh%d" % i, sx, sy, h, cx, -sy / 2, z, "brick"))
        z += h
    items.append(B("fshaft", 1.3, 1.0, hi - z + 0.3, cx, -0.5, z, "brick"))
    items.append(B("fmantel", fw + 0.3, 2.1, 0.12, cx, -1.0, fh + 0.14, "flag"))
    # 炉前：铁砧（树墩）+ 水桶 + 煤堆 + 工具台
    an = p_anvil()
    at(an, cx - 0.2, -4.0, 0.14, math.pi / 2)
    items.append(an)
    ben = B("bench", 2.6, 0.8, 0.1, 1.5, yp + 0.2, 1.05, "log")
    ben_l = B("bleg", 0.14, 0.7, 1.05, 0.4, yp + 0.2, 0.0, "timber")
    mirror(ben_l, 0, (1.5, 0, 0))
    shelf = B("bshelf", 2.5, 0.7, 0.07, 1.5, yp + 0.2, 0.45, "log")
    items += [ben, ben_l, shelf]
    for i, (hx, rot) in enumerate(((0.8, 0.3), (1.45, -0.6))):          # 台面上平放的两把锤（截面在 XY，沿 Z 挤出）
        hm = PX("hm%d" % i, [(-0.5, -0.025), (0.0, -0.025), (0.0, -0.1), (0.13, -0.1), (0.13, 0.1), (0.0, 0.1), (0.0, 0.025), (-0.5, 0.025)], 0.05, "darksteel", 0.0, "z")
        at(hm, hx + 0.3, yp + 0.2, 1.15, rot)
        items.append(hm)
    pliers = curve_bevel("tong", [(0.0, 0.0, 0.0), (0.18, 0.0, 0.0), (0.5, 0.05, 0.0), (0.62, 0.0, 0.0)], 0.014, "darksteel")
    at(pliers, 2.0, yp + 0.1, 1.17, 0.4)
    items.append(pliers)
    bucket = screw("bucket", [(0.0, 0.0), (0.24, 0.0), (0.29, 0.38), (0.0, 0.38)], "log", 12)
    at(bucket, Lsh - 1.0, -1.1, 0.14)
    bw = screw("bwater", [(0.0, 0.34), (0.26, 0.34), (0.26, 0.31), (0.0, 0.31)], "water", 12)
    at(bw, Lsh - 1.0, -1.1, 0.14)
    bh = curve_bevel("bhandle", [(0.29 * math.cos(a), 0.0, 0.38 + 0.2 * math.sin(a)) for a in (math.pi * i / 10 for i in range(11))], 0.012, "iron")
    at(bh, Lsh - 1.0, -1.1, 0.14)
    quench = screw("quench", [(0.0, 0.0), (0.42, 0.0), (0.46, 0.5), (0.5, 0.8), (0.0, 0.8)], "log", 14)
    hoop = screw("qhoop", [(0.505, 0.15), (0.505, 0.2), (0.455, 0.2), (0.455, 0.15)], "iron", 14)
    at(quench, Lsh - 2.2, -1.1, 0.14)
    at(hoop, Lsh - 2.2, -1.1, 0.14)
    qw = screw("qwater", [(0.0, 0.76), (0.46, 0.76), (0.46, 0.72), (0.0, 0.72)], "water", 14)
    at(qw, Lsh - 2.2, -1.1, 0.14)
    heap = screw("sheap", [(0.0, 0.0), (0.75, 0.0), (0.6, 0.22), (0.3, 0.4), (0.0, 0.46)], "coal", 8)
    sym_jitter(heap, 0.03, 33)
    at(heap, 1.1, -1.0, 0.14)
    items += [bucket, bw, bh, quench, hoop, qw, heap]
    return join(items, "forge_shed")


# ---------------------------------------------------------------- 牌匾 / 招牌
def p_plaque(text="BLACKSMITH", w=3.4, h=1.0):
    """门上方的牌匾：深蓝木板 + 木框 + 浮雕立体字（Blender 文字曲线挤出 → 网格，系统微软雅黑粗体）。原点在牌匾背面中心，朝 -Y。"""
    board = B("pq_board", w, 0.14, h, 0, -0.07, -h / 2, "plaqueblue")
    fr = B("pq_fr", w + 0.16, 0.2, 0.1, 0, -0.1, h / 2 - 0.02, "timber")
    array(fr, 2, (0, 0, -(h - 0.08)))
    sd = B("pq_sd", 0.1, 0.2, h + 0.16, w / 2 + 0.03, -0.1, -h / 2 - 0.08, "timber")
    mirror(sd, 0, (0, 0, 0))
    cu = bpy.data.curves.new("pq_txt", "FONT")
    cu.body = text
    try:
        cu.font = bpy.data.fonts.load(r"C:\Windows\Fonts\msyhbd.ttc")
    except Exception:
        pass
    cu.size = min(h * 0.62, w * 0.8 / (0.64 * max(len(text), 1)))
    cu.extrude = 0.05
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    ob = bpy.data.objects.new("pq_txt", cu)
    kit._link(ob)
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    me.materials.clear(); me.materials.append(kit.mat("cream"))
    me.transform(Matrix.Translation((0, 0, 0)) @ Matrix.Rotation(math.pi / 2, 4, "X"))          # 字面朝 -Y
    me.transform(Matrix.Translation((0, -0.18, 0)))
    _bm = bmesh.new(); _bm.from_mesh(me); bmesh.ops.remove_doubles(_bm, verts=_bm.verts, dist=1e-4); _bm.to_mesh(me); _bm.free()
    txt = new_obj("pq_txt_m", me, ("profile_extrude",))
    return join([board, fr, sd, txt], "plaque")


# ---------------------------------------------------------------- 内景：盔甲架 / 武器墙 / 柜台 / 工具架
def stand_base(h=1.0):
    base = screw("stb", [(0.0, 0.0), (0.34, 0.0), (0.34, 0.07), (0.1, 0.1), (0.0, 0.1)], "log", 10)
    post = B("stp", 0.07, 0.07, h, 0, 0, 0.08, "timber")
    return [base, post]


def p_armor_plate():
    """板甲展示架：钢胸甲（旋绕，压扁）+ 肩甲（镜像）+ 腿裙 + 腰带 + 头盔；原点在底座中心。"""
    its = stand_base(0.8)
    chest = screw("chest", [(0.0, 0.7), (0.2, 0.7), (0.26, 0.84), (0.29, 1.08), (0.25, 1.28), (0.16, 1.38), (0.0, 1.4)], "steel", 16)
    chest.scale = (1.0, 0.68, 1.0)
    kit.apply_scale(chest)
    skirt = screw("skirt", [(0.2, 0.7), (0.34, 0.42), (0.32, 0.36), (0.18, 0.62)], "steel", 16)
    skirt.scale = (1.0, 0.7, 1.0)
    kit.apply_scale(skirt)
    belt = screw("belt", [(0.215, 0.72), (0.215, 0.78), (0.2, 0.78), (0.2, 0.72)], "leather", 16)
    belt.scale = (1.0, 0.7, 1.0)
    kit.apply_scale(belt)
    pad = screw("pad", [(0.0, 0.0), (0.15, 0.0), (0.17, 0.08), (0.12, 0.17), (0.0, 0.2)], "steel", 10)
    pad.scale = (1.0, 0.9, 0.9)
    kit.apply_scale(pad)
    pad.location = (0.31, 0.0, 1.22)
    pad.rotation_euler = (0, math.radians(-30), 0)
    kit.apply_scale(pad)
    mirror(pad, 0, (0, 0, 0))
    arm = screw("arm", [(0.0, 0.0), (0.075, 0.0), (0.07, 0.5), (0.0, 0.5)], "steel", 8)
    arm.rotation_euler = (0, math.radians(-14), 0)
    arm.location = (0.34, 0.0, 0.78)
    kit.apply_scale(arm)
    mirror(arm, 0, (0, 0, 0))
    hm = helmet("knight")
    at(hm, 0, 0, 1.38)
    return join(its + [chest, skirt, belt, pad, arm, hm], "armor_plate")


def p_armor_mail():
    """锁甲展示架：横木撑开锁子甲（旋绕躯干 + 袖筒镜像）+ 锁帽 + 皮腰带；锁子环由 pt_metal 手绘贴图表现。"""
    its = stand_base(1.0)
    torso = screw("torso", [(0.0, 0.55), (0.26, 0.55), (0.29, 0.75), (0.26, 1.15), (0.2, 1.36), (0.0, 1.38)], "mail", 14)
    torso.scale = (1.0, 0.7, 1.0)
    kit.apply_scale(torso)
    skirt = screw("mskirt", [(0.26, 0.55), (0.33, 0.28), (0.3, 0.2), (0.25, 0.4)], "mail", 14)
    skirt.scale = (1.0, 0.7, 1.0)
    kit.apply_scale(skirt)
    bar = B("sbar", 1.1, 0.05, 0.05, 0, 0, 1.28, "timber")
    sleeve = screw("slv", [(0.0, 0.0), (0.095, 0.0), (0.085, 0.55), (0.0, 0.55)], "mail", 10)
    sleeve.rotation_euler = (0, math.radians(-78), 0)
    sleeve.location = (0.27, 0.0, 1.27)
    kit.apply_scale(sleeve)
    mirror(sleeve, 0, (0, 0, 0))
    coif = screw("coif", [(0.0, 1.35), (0.14, 1.36), (0.18, 1.5), (0.14, 1.66), (0.0, 1.72)], "mail", 12)
    belt = screw("mbelt", [(0.29, 0.62), (0.29, 0.7), (0.275, 0.7), (0.275, 0.62)], "leather", 14)
    belt.scale = (1.0, 0.7, 1.0)
    kit.apply_scale(belt)
    return join(its + [torso, skirt, bar, sleeve, coif, belt], "armor_mail")


def p_armor_leather():
    """皮甲展示架：皮胸甲 + 皮肩甲（镜像）+ 皮帽 + 交叉背带。"""
    its = stand_base(0.9)
    torso = screw("ltor", [(0.0, 0.62), (0.2, 0.62), (0.25, 0.8), (0.26, 1.1), (0.22, 1.3), (0.0, 1.34)], "leather", 14)
    torso.scale = (1.0, 0.66, 1.0)
    kit.apply_scale(torso)
    flaps = screw("flaps", [(0.2, 0.62), (0.3, 0.38), (0.27, 0.34), (0.19, 0.55)], "leather2", 14)
    flaps.scale = (1.0, 0.7, 1.0)
    kit.apply_scale(flaps)
    sh = screw("lsh", [(0.0, 0.0), (0.13, 0.0), (0.14, 0.06), (0.1, 0.13), (0.0, 0.15)], "leather2", 10)
    sh.location = (0.29, 0.0, 1.22)
    sh.rotation_euler = (0, math.radians(-25), 0)
    kit.apply_scale(sh)
    mirror(sh, 0, (0, 0, 0))
    cap = screw("lcap", [(0.0, 1.55), (0.1, 1.54), (0.15, 1.42), (0.16, 1.34), (0.0, 1.36)], "leather2", 12)
    strap = curve_bevel("strap", [(-0.2, -0.18, 1.28), (0.0, -0.2, 1.05), (0.22, -0.17, 0.8)], 0.025, "leather2", square=True)
    buckle = B("buckle", 0.07, 0.03, 0.07, 0.0, -0.2, 1.03, "brass")
    return join(its + [torso, flaps, sh, cap, strap, buckle], "armor_leather")


def p_weapon_wall(w=4.2, h=2.2):
    """武器墙：木板墙 + 三道横梁，上面左右对称挂剑 / 斧 / 锤（建左半镜像），正中是圆盾 + 两把交叉长剑。原点在板底中心，朝 -Y。"""
    back = B("wback", w, 0.1, h, 0, 0.05, 0, "timber")
    rail = B("wrail", w - 0.2, 0.12, 0.1, 0, -0.04, 0.55, "log")
    array(rail, 3, (0, 0, 0.62))
    items = [back, rail]
    half = []
    for i, x in enumerate((-1.75, -1.3)):
        s = sword(0.95 + 0.1 * i)
        at(s, x, -0.11, 0.8 + 0.15 * i)
        half.append(s)
    ax = axe()
    at(ax, -0.88, -0.11, 0.98)
    half.append(ax)
    mc = mace()
    at(mc, -0.5, -0.11, 1.0)
    half.append(mc)
    sd = round_shield(0.34, "cloth")
    at(sd, -1.5, -0.12, 1.8)
    half.append(sd)
    hj = join(half, "whalf")
    mirror(hj, 0, (0, 0, 0))
    items.append(hj)
    ctr_s = round_shield(0.5, "steel")
    at(ctr_s, 0.0, -0.13, 1.3)
    items.append(ctr_s)
    for sg in (-1, 1):
        sw = sword(1.15)
        sw.rotation_euler = (0, math.radians(sg * 38), 0)
        sw.location = (-sg * 0.38, -0.11, 0.68)
        kit.apply_scale(sw)
        items.append(sw)
    return join(items, "weapon_wall")


def p_counter(variant="weapons", ln=3.4):
    """柜台：木柜身（前板阵列）+ 厚台面 + 台面陈列（武器柜台：红布上横放长剑 + 匕首；护甲柜台：红布上两顶头盔 + 一副护手）。原点在柜台中心地面，前面朝 -Y。"""
    h = 1.2
    body = B("cbody", ln, 0.8, h - 0.1, 0, 0, 0, "log")
    plank = B("cpl", 0.34, 0.04, h - 0.3, -ln / 2 + 0.3, -0.42, 0.1, "door")
    array(plank, int((ln - 0.4) / 0.4), (0.4, 0, 0))
    top = B("ctop", ln + 0.24, 1.05, 0.14, 0, -0.02, h - 0.1, "door")
    kick = B("ckick", ln + 0.02, 0.84, 0.1, 0, 0, 0, "timber")
    items = [body, plank, top, kick]
    runner = B("runner", ln - 0.6, 0.55, 0.012, 0, -0.1, h + 0.04, "cloth")
    items.append(runner)
    z = h + 0.05
    if variant == "weapons":
        s = sword(0.9)
        s.rotation_euler = (math.pi / 2, 0, math.pi / 2)
        s.location = (-0.9, -0.1, z + 0.02)
        kit.apply_scale(s)
        items.append(s)
        for x in (0.5, 1.05):
            d = sword(0.42)
            d.rotation_euler = (math.pi / 2, 0, math.pi / 2)
            d.location = (x - 0.4, -0.15 + 0.06 * (x > 0.7), z + 0.02)
            kit.apply_scale(d)
            items.append(d)
    else:
        for x in (-0.9, 0.0):
            hm = helmet("knight")
            at(hm, x, -0.12, z)
            items.append(hm)
        for sg in (-1, 1):
            gl = B("glove", 0.12, 0.3, 0.1, 0.95 + sg * 0.12, -0.12, z, "darksteel")
            items.append(gl)
        pl = B("plate", 0.4, 0.3, 0.05, 1.5, -0.12, z, "steel")
        items.append(pl)
    return join(items, "counter_" + variant)


def p_tool_rack(w=1.8):
    """墙挂工具架：横板 + 铁钩（阵列），挂大锤 / 小锤 / 长钳 / 钢锯。原点板底中心，朝 -Y。"""
    bd = B("tbd", w, 0.08, 0.5, 0, 0.04, 0.0, "timber")
    hooks = B("hook", 0.03, 0.12, 0.03, -w / 2 + 0.25, -0.04, 0.38, "iron")
    array(hooks, 4, ((w - 0.5) / 3, 0, 0))
    items = [bd, hooks]
    hm = PX("hm1", [(-0.03, -0.6), (0.03, -0.6), (0.03, 0.0), (0.16, 0.0), (0.16, 0.2), (-0.16, 0.2), (-0.16, 0.0), (-0.03, 0.0)], 0.07, "darksteel", 0.0, "y")
    hm.data.transform(Matrix.Translation((-w / 2 + 0.25, -0.11, 0.3)))
    hm2 = PX("hm2", [(-0.025, -0.42), (0.025, -0.42), (0.025, 0.0), (0.1, 0.0), (0.1, 0.12), (-0.1, 0.12), (-0.1, 0.0), (-0.025, 0.0)], 0.05, "steel", 0.0, "y")
    hm2.data.transform(Matrix.Translation((-w / 2 + 0.25 + (w - 0.5) / 3, -0.1, 0.3)))
    tg = curve_bevel("tg", [(0.0, 0.0, 0.0), (0.0, 0.0, -0.3), (0.05, 0.0, -0.55), (0.0, 0.0, -0.7)], 0.014, "darksteel")
    tg2 = curve_bevel("tg2", [(0.0, 0.0, 0.0), (0.0, 0.0, -0.3), (-0.05, 0.0, -0.55), (0.0, 0.0, -0.7)], 0.014, "darksteel")
    at(tg, -w / 2 + 0.25 + 2 * (w - 0.5) / 3, -0.11, 0.34)
    at(tg2, -w / 2 + 0.25 + 2 * (w - 0.5) / 3 + 0.06, -0.12, 0.34)
    saw = PX("saw", [(-0.28, 0.0), (0.28, 0.0), (0.28, 0.07), (-0.28, 0.07)], 0.015, "steel", 0.0, "y")
    saw.data.transform(Matrix.Translation((w / 2 - 0.25, -0.11, -0.05)))
    items += [hm, hm2, tg, tg2]
    return join(items, "tool_rack")


def p_grindstone():
    """磨刀石：木架（镜像一侧）+ 石磨盘（旋绕，横轴）+ 踏板曲柄。原点地面中心；磨盘轴沿 X。"""
    leg = B("gleg", 0.1, 0.6, 0.85, -0.38, 0.0, 0.0, "timber")
    mirror(leg, 0, (0, 0, 0))
    axle = screw("gaxle", [(0.0, -0.45), (0.04, -0.45), (0.04, 0.45), (0.0, 0.45)], "iron", 8)
    axle.rotation_euler = (0, math.pi / 2, 0)
    axle.location = (0, 0, 0.78)
    kit.apply_scale(axle)
    wheel = screw("gwheel", [(0.0, -0.1), (0.36, -0.1), (0.38, -0.08), (0.38, 0.08), (0.36, 0.1), (0.0, 0.1)], "flag", 20)
    wheel.rotation_euler = (0, math.pi / 2, 0)
    wheel.location = (0, 0, 0.78)
    kit.apply_scale(wheel)
    tr = B("gtread", 0.5, 0.18, 0.04, 0, 0.3, 0.14, "timber")
    rod = beam("grod", (0.0, 0.3, 0.16), (0.0, 0.0, 0.75), 0.035, 0.035, "iron")
    trough = B("gtrough", 0.7, 0.16, 0.14, 0, -0.3, 0.48, "log")
    return join([leg, axle, wheel, tr, rod, trough], "grindstone")


PARTS_SMITH = [
    ("S01_anvil", p_anvil, "铁砧 + 树墩"), ("S02_hearth", p_hearth, "内景砖炉膛"), ("S03_forge_chimney", p_forge_chimney, "外墙砖烟囱"),
    ("S04_forge_shed", p_forge_shed, "敞棚锻炉"), ("S05_plaque", p_plaque, "铁匠铺牌匾"), ("S06_armor_plate", p_armor_plate, "板甲架"),
    ("S07_armor_mail", p_armor_mail, "锁甲架"), ("S08_armor_leather", p_armor_leather, "皮甲架"), ("S09_weapon_wall", p_weapon_wall, "武器墙"),
    ("S10_counter_weapons", lambda: p_counter("weapons"), "武器柜台"), ("S11_counter_armor", lambda: p_counter("armor"), "护甲柜台"),
    ("S12_tool_rack", p_tool_rack, "工具架"), ("S13_grindstone", p_grindstone, "磨刀石"),
]
parts.PARTS.extend(PARTS_SMITH)
