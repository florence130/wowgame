# 金穗镇村屋生成器：外形（石基座 + 灰泥木筋墙 + 石窗框 + 双坡屋面 + 山墙 + 老虎窗 + 烟囱 + 门廊 + 藤蔓灌木）。
# 参考：docs/city_ref/ref24（洛奇M 重制版红瓦转角屋）、ref25 / ref27（魔兽世界艾尔文森林木筋蓝瓦屋）、ref26（酒馆内景）。
# 一栋房子 = 一个 Geo：S 组（碰撞）+ N 组（无碰撞）。内饰见 furn.py。
import math, random
from mathutils import Vector, Matrix
from geo import Geo, T, Rz, Rx, Ry, S3, M_YZ, M_XZ, I
import stamp
import timber
import colorsys

SC = stamp.SC                  # 构件按真实米制建；build.py 统一以 3.0/2.3 导出世界比例
SCL = S3(1 / SC, 1 / SC, 1 / SC)
TW = 0.45                       # 墙厚
WT = round(TW * SC, 3)          # 放大后的墙厚（构件按这个厚度建，窗 / 门嵌在墙洞里）
FL = 0.14                       # 室内地面高出室外（门口用 1.2m 斜坡过渡）
PITCH = math.radians(40.0)
TN, CS = math.tan(PITCH), math.cos(PITCH)
OV = 0.62                       # 檐口外挑
RT = 0.22                       # 屋面板厚

def K(t, hexc, tex="", m=3.0):
    return "K|%s|%s|%s|%s" % (t, hexc, tex, m)

PANE = "N|4d6a8a"
GLOW = K("glow", "ffcf80")
FIRE = K("glow", "ff8a30")
IRON = K(7, "2b2f36", "pt_metal", 2.0)
WOODL = K(6, "c49a68", "pt_wood_light", 3.0)
WOODD = K(6, "7a5236", "pt_wood", 4.0)
FLOORM = K(6, "d0a574", "pt_wood_light", 3.0)
STONEM = K(2, "b3a88f", "pt_ashlar", 2.8)
RUBBLE = K(2, "9d937f", "pt_rubble", 2.4)
LEAF = [K(8, "4f8a3c", "pt_foliage", 3.0), K(8, "5f9a45", "pt_foliage", 3.0), K(8, "3f7a38", "pt_foliage", 3.0)]
BERRY = K(0, "c8403a")
FLOWERS = [K(0, "f0c93a"), K(0, "f4f0e6"), K(0, "e87aa0"), K(0, "8a6ad0")]

STYLES = {
    # 色板取自洛奇M 解包贴图的整体均值色（docs/mabi_ref/tile_means.json：灰泥 #bfaf8f、深木 #855c3f、方石 #96907a、红砖 #aa6a3c、屋面 #72799d / #9fb2a3），略提亮
    "mm": dict(plaster="cdbd9a", timber="855c3f", stone="a39d86", roof=("tile", "b46a3e"), win="stone", sh="6f8f78"),
    "mm2": dict(plaster="d5c6a2", timber="8b6143", stone="9c9680", roof=("tile", "c27b46"), win="stone", sh="b8714e"),
    "wow": dict(plaster="d3c6a4", timber="7d5538", stone="a8a28c", roof=("slate", "68748a"), win="timber", sh="6a8aa8"),
    "wow2": dict(plaster="cdbf9a", timber="825a3d", stone="9f9984", roof=("slate", "81908c"), win="timber", sh="b8714e"),
}


def mats(sp):
    st = dict(STYLES[sp.get("style", "mm")])
    st.update({k: v for k, v in sp.get("pal", {}).items()})
    st["PLASTER"] = K(6, st["plaster"], "pt_wood_light", 3.0) if sp.get("walls") == "planks" else K(0, st["plaster"], "pt_plaster", 4.0)    # walls=planks：谷仓竖板墙
    st["TIMBER"] = K(6, st["timber"], "pt_wood", 4.6)
    st["STONE"] = K(2, st["stone"], "pt_ashlar", 2.8)
    t = st["roof"]
    if t[0] == "thatch":                                  # 厚茅草屋面（thatch_patch：圆润隆起的草束层）
        st["ROOF"] = K(3, t[1], "pt_thatch", 3.0)
        st["ROOFD"] = K(3, t[1], "pt_thatch", 3.0)
    elif t[0] == "shake":                                 # 棕色木瓦（铁匠铺）                                   # 棕色木瓦（铁匠铺）
        st["ROOF"] = K(3, t[1], "pt_shake", 2.4)
        st["ROOFD"] = K(3, t[1], "pt_shake", 2.4)
    else:
        st["ROOF"] = K(4, t[1], "pt_roof_tile", 2.4) if t[0] == "tile" else K(3, t[1], "pt_roof_slate", 2.6)
        st["ROOFD"] = K(4 if t[0] == "tile" else 3, t[1], "pt_roof_tile" if t[0] == "tile" else "pt_roof_slate", 2.4)
    st["SHUT"] = K(6, st["sh"], "pt_wood_light", 3.0)
    # 瓦色变体：洛奇M 屋顶每片瓦的明度 / 色相略有不同（手绘感）。3 档，逐片随机取
    t = st["roof"]
    r, g, b = (int(t[1][i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    var = []
    for dh, dv in ((-0.012, 0.93), (0.0, 1.0), (0.012, 1.07)):
        rr, gg, bb = colorsys.hsv_to_rgb((h + dh) % 1.0, s, min(1.0, v * dv))
        hx = "%02x%02x%02x" % (int(rr * 255), int(gg * 255), int(bb * 255))
        if t[0] == "thatch":
            var.append(K(3, hx, "pt_thatch", 3.0))
        elif t[0] == "shake":
            var.append(K(3, hx, "pt_shake", 2.4))
        elif t[0] == "tile":
            var.append(K(4, hx, "pt_roof_tile", 2.4))
        else:
            var.append(K(3, hx, "pt_roof_slate", 2.6))
    st["ROOFV"] = var
    return st


# ---------------------------------------------------------------- 轮廓
def footprint(sp):
    sh = sp["shape"]
    if sh[0] == "rect":
        W, D = sh[1], sh[2]
        out = [(-W / 2, -D / 2), (W / 2, -D / 2), (W / 2, D / 2), (-W / 2, D / 2)]
        axis = sp.get("axis", "x" if W >= D else "y")
        parts = [dict(rect=(-W / 2, W / 2, -D / 2, D / 2), axis=axis, g0=True, g1=True)]
        return out, parts, W, D
    W, D, d1, w2, side = sh[1], sh[2], sh[3], sh[4], (sh[5] if len(sh) > 5 else "r")
    out = [(-W / 2, -D / 2), (W / 2, -D / 2), (W / 2, D / 2), (W / 2 - w2, D / 2), (W / 2 - w2, -D / 2 + d1), (-W / 2, -D / 2 + d1)]
    ywb = -D / 2 + d1
    parts = [dict(rect=(-W / 2, W / 2, -D / 2, ywb), axis="x", g0=True, g1=True, noeave_back=(W / 2 - w2, W / 2 + 5)),
             dict(rect=(W / 2 - w2, W / 2, ywb, D / 2), axis="y", g0=False, g1=True, a0=-D / 2 + d1 / 2, clip=ywb)]
    if side == "l":
        out = [(-x, y) for x, y in reversed(out)]
        # 反序后起点变了：把最前面的边（y 最小、x 从小到大）放到第 0 条
        i0 = min(range(len(out)), key=lambda i: (out[i][1] + out[(i + 1) % len(out)][1], out[i][0]))
        out = out[i0:] + out[:i0]
        for p in parts:
            x0, x1, y0, y1 = p["rect"]
            p["rect"] = (-x1, -x0, y0, y1)
            if p.get("noeave_back"):
                lo, hi = p["noeave_back"]
                p["noeave_back"] = (-hi, -lo)
    return out, parts, W, D


# ---------------------------------------------------------------- 墙
def notch_poly(bw, base, z1, cx, w, top, arch):
    xl, xr = cx - w / 2, cx + w / 2
    pts = [(0, base), (xl, base)]
    if arch:
        r = w / 2
        zs = top - r
        n = 9
        for i in range(n + 1):
            t = math.pi * (1 - i / n)
            pts.append((cx + r * math.cos(t), zs + r * math.sin(t)))
    else:
        pts += [(xl, top), (xr, top)]
    pts += [(xr, base), (bw, base), (bw, z1), (0, z1)]
    return pts


def wall_bay(G, mk, Me, x0, bw, z0, z1, hole=None):
    base = Me @ T(x0, TW / 2, 0) @ M_XZ
    if hole is None:
        G.prism("S", mk, [(0, z0), (bw, z0), (bw, z1), (0, z1)], TW, base)
        return
    kind, cx, hz0, w, h = hole
    if hz0 > z0 + 1e-3:
        G.prism("S", mk, [(0, z0), (bw, z0), (bw, hz0), (0, hz0)], TW, base)
    G.prism("S", mk, notch_poly(bw, max(hz0, z0), z1, cx, w, hz0 + h, kind == "arch"), TW, base)


def window(G, st, Me, cx, z0, w, h, shutters=False, flowerbox=False, rnd=None):
    """窗：用构件库 T12（窗格 / 窗扇 / 石窗套 / 对称花箱）盖章；室内窗台仍是一块灰泥板。"""
    if _tp(G, "window", Me @ T(cx, -(TW / 2 + 0.06), z0 - 0.3), w + 1.5, 0.42, h + 0.55, "N"):
        G.box("S", st["PLASTER"], w + 0.2, 0.22, 0.05, Me @ T(cx, TW / 2 + 0.07, z0 - 0.02))
        G.box("N", PANE, w, 0.04, h, Me @ T(cx, 0.0, z0))           # 玻璃（夜间发光）
        return
    surround = "trim" if st["win"] == "stone" else "timber"
    stamp.place(G, st, "window", Me @ T(cx, 0, z0) @ SCL, WT, w=round(w * SC, 3), h=round(h * SC, 3), shutters=bool(shutters), flowers=bool(flowerbox and rnd is not None),
                surround=surround, wall=False)
    G.box("S", st["PLASTER"], w + 0.2, 0.22, 0.05, Me @ T(cx, TW / 2 + 0.07, z0 - 0.02))      # 室内窗台


def barn_doors(G, st, Me, cx, w, h):
    """谷仓大型双开门：厚木门框 + 两扇竖板门（Z 形斜撑、铁铰链），一扇半开；门洞 w×h。"""
    tm, wd, ir = st["TIMBER"], K(6, "8a5a3a", "pt_wood_light", 3.0), K(7, "3d4048", "pt_metal", 2.0)
    yo = -TW / 2
    G.box("S", tm, 0.32, 0.5, h + 0.35, Me @ T(cx - w / 2 - 0.16, yo, 0))
    G.box("S", tm, 0.32, 0.5, h + 0.35, Me @ T(cx + w / 2 + 0.16, yo, 0))
    G.box("S", tm, w + 0.96, 0.55, 0.38, Me @ T(cx, yo, h))
    hw = w / 2
    for s, ang in ((-1, 0.0), (1, 0.9)):
        hx = cx + s * hw                                       # 铰链在外侧
        M = Me @ T(hx, yo - 0.12, FL) @ Rz(-s * ang)
        n = 6
        for i in range(n):
            G.box("N", wd, hw / n - 0.02, 0.1, h - 0.1, M @ T(-s * (hw / n * (i + 0.5)), 0, 0))
        for z in (0.35, h * 0.5, h - 0.45):
            G.box("N", tm, hw, 0.08, 0.22, M @ T(-s * hw / 2, -0.07, z))
        G.beam("N", tm, M @ Vector((-s * 0.15, -0.08, 0.45)), M @ Vector((-s * (hw - 0.15), -0.08, h * 0.5 - 0.1)), 0.18, 0.07, up=(0, 1, 0))
        G.beam("N", tm, M @ Vector((-s * 0.15, -0.08, h * 0.5 + 0.1)), M @ Vector((-s * (hw - 0.15), -0.08, h - 0.55)), 0.18, 0.07, up=(0, 1, 0))
        for z in (0.5, h - 0.6):
            G.box("N", ir, 0.7, 0.04, 0.09, M @ T(-s * 0.35, -0.12, z))


def door_unit(G, st, Me, cx, w, h):
    if G.__dict__.get("barn_door"):
        barn_doors(G, st, Me, cx, w, h)
        return
    for s_ in (-1, 1):
        _tp(G, "wall_lantern", Me @ T(cx + s_ * (w / 2 + 0.75), -(TW / 2), h * 0.95), None, None, 0.85, "N")
    """标准 Blender T03 拱门：框、门扇、墙洞使用同一组 w×h 尺寸。

    Tripo 门模型曾以更大的外包围盒盖在门洞前，造成蓝紫色拱框遮住门扇；
    建筑源头统一使用可审计的程序化构件，Tripo 只保留在独立道具管线。
    """
    kw = dict(dw=round(w * SC, 3), dh=round(h * SC, 3), wall=False, steps=False, surround="trim" if st["win"] == "stone" else "timber")
    M = Me @ T(cx, 0, FL) @ SCL
    stamp.place(G, st, "door", M, WT, sub="frame", **kw)
    # 门扇不再烘进整栋无碰撞网格：由 Godot 运行时创建独立节点，靠近时自动打开。


def build_walls(G, st, sp, out, rows, H, rnd):
    n = len(out)
    G.TF = TF = timber.Collector()           # 木筋构件先收集，compose 在屋顶建完后一次布尔求并 + 倒角（timber.py）
    info = []
    for e in range(n):
        a, b = Vector(out[e]), Vector(out[(e + 1) % n])
        d = b - a
        L = d.length
        th = math.atan2(d.y, d.x)
        Me = T(a.x, a.y, 0) @ Rz(th)
        nb = max(1, round(L / sp.get("bay", 3.0)))
        bw = L / nb
        info.append(dict(a=a, b=b, L=L, th=th, Me=Me, nb=nb, bw=bw))
    door_bay = sp.get("door_bay")
    door_w, door_h = (3.4, 3.2) if sp.get("barn_door") else (1.5, 2.4)
    G.barn_door = bool(sp.get("barn_door"))
    oriel = set(sp.get("oriel", []))
    barn = tuple(sp["barn"]) if sp.get("barn") else None
    solid_bays = set(tuple(x) for x in sp.get("solid", []))               # 指定开间做实心墙（被敞棚 / 烟囱 / 武器墙挡住的）

    _, parts_, _, _ = footprint(sp)

    def is_eave(ed):
        if sp.get("roof") == "pyramid":
            return True
        m = (ed["a"] + ed["b"]) / 2
        best = None
        for p in parts_:
            x0, x1, y0, y1 = p["rect"]
            dx, dy = max(x0 - m.x, 0, m.x - x1), max(y0 - m.y, 0, m.y - y1)
            if best is None or dx * dx + dy * dy < best[0]:
                best = (dx * dx + dy * dy, p)
        horiz = abs(ed["b"].x - ed["a"].x) > abs(ed["b"].y - ed["a"].y)
        return horiz == (best[1]["axis"] == "x")

    def special(e, k):
        return (e == 0 and k in oriel) or (barn is not None and (e, k) == barn) or (e, k) in solid_bays
    for e, ed in enumerate(info):
        Me, L, nb, bw = ed["Me"], ed["L"], ed["nb"], ed["bw"]
        db = (door_bay if door_bay is not None else nb // 2) if e == 0 else -1
        ed["door_x"] = db * bw + bw / 2 if db >= 0 else None
        eave_e = is_eave(ed)
        for r, (z0, z1) in enumerate(rows):
            if eave_e and r == len(rows) - 1:
                z1 -= 0.3                      # 檐口侧墙顶让到出檐屋面之下，灰泥不从瓦面穿出
            for k in range(nb):
                x0 = k * bw
                cx = bw / 2
                if L < 1.6:
                    wall_bay(G, st["PLASTER"], Me, x0, bw, z0, z1)
                    continue
                if e == 0 and k == db and r == 0:
                    wall_bay(G, st["PLASTER"], Me, x0, bw, z0, z1, ("arch", cx, FL, door_w, door_h))
                    continue
                if special(e, k) and r == 0:                                  # 凸窗 / 谷仓门所在开间：墙面实心，构件盖在外面
                    wall_bay(G, st["PLASTER"], Me, x0, bw, z0, z1)
                    continue
                is_win = (e == 0) or ((k + e + r) % 2 == 0) or (L > 6 and r == 1)
                ww, wh = (1.12, 1.4) if r == 0 else (1.0, 1.25)
                if sp.get("small_win") and e != 0:
                    ww, wh = 0.9, 0.9
                sill = (z0 + (0.95 if r == 0 else 0.8)) if r == 0 else z0 + 0.85
                if r == 0:
                    sill = FL + 0.95
                if is_win and bw > 1.8:
                    wall_bay(G, st["PLASTER"], Me, x0, bw, z0, z1, ("rect", cx, sill, ww, wh))
                    window(G, st, Me, x0 + cx, sill, ww, wh, shutters=(st["win"] == "stone" or rnd.random() < 0.4) and e == 0 and rnd.random() < 0.7,
                           flowerbox=(e == 0 and r == 0 and rnd.random() < 0.45), rnd=rnd)
                else:
                    wall_bay(G, st["PLASTER"], Me, x0, bw, z0, z1)
        # 木筋：立柱 / 顶梁 / 层间梁 / 斜撑；石基座
        tm = st["TIMBER"]
        yo = -TW / 2
        # 统一截面规则：立柱 0.18×0.16、顶梁 0.18×0.26、层间梁 0.18×0.22、腰梁 0.18×0.16、斜撑 0.14×0.12；外凸量一致（前沿在 yo-0.12），嵌进墙 0.05
        eave = is_eave(ed)                     # 檐口一侧的墙顶要低于出檐屋面（否则立柱 / 顶梁会从瓦面下面戳出来）
        zt = H - 0.32 if eave else H
        for k in range(nb + 1):
            TF.box("S", tm, 0.18, 0.17, (zt if eave else H + 0.1), Me @ T(k * bw, yo - 0.035, 0))
        TF.box("S", tm, L, 0.17, 0.26, Me @ T(L / 2, yo - 0.035, zt - 0.26))
        for (z0, z1) in rows[:-1]:
            TF.box("S", tm, L, 0.17, 0.22, Me @ T(L / 2, yo - 0.035, z1 - 0.11))
        # 腰梁 / 石基座要让开的区间：门洞、凸窗、谷仓门
        gaps = []
        if ed["door_x"] is not None:
            gaps.append((ed["door_x"] - door_w / 2 - 0.2, ed["door_x"] + door_w / 2 + 0.2))
        if barn is not None and barn[0] == e:                  # 谷仓门贴着地面，石基座 / 腰梁在这一开间让开
            gaps.append((barn[1] * bw + 0.1, (barn[1] + 1) * bw - 0.1))
        gaps.sort()
        rail_segs, cur = [], 0.0
        for g0, g1 in gaps:
            if g0 > cur:
                rail_segs.append((cur, g0))
            cur = max(cur, g1)
        if cur < L:
            rail_segs.append((cur, L))
        for (r0, r1) in rail_segs:
            if r1 - r0 > 0.05:
                TF.box("S", tm, r1 - r0, 0.17, 0.16, Me @ T((r0 + r1) / 2, yo - 0.035, FL + 0.9))
        # 斜撑（实墙开间）
        if sp.get("braces", True):
            for r, (z0, z1) in enumerate(rows):
                if eave and r == len(rows) - 1:
                    z1 -= 0.3
                for k in range(nb):
                    if e == 0 and k == db and r == 0:
                        continue
                    if special(e, k) and r == 0:
                        continue
                    sx0 = k * bw
                    solid = not (((e == 0) or ((k + e + r) % 2 == 0) or (L > 6 and r == 1)) and bw > 1.8) or L < 1.6
                    if solid and bw > 1.2:
                        bz0 = (FL + 1.0) if r == 0 else z0 + 0.15
                        wn = Me.to_3x3() @ Vector((0, 1, 0))
                        TF.beam("S", tm, Me @ Vector((sx0 + 0.09, yo - 0.035, bz0)), Me @ Vector((sx0 + bw * 0.5, yo - 0.035, z1 - 0.3)), 0.14, 0.14, up=wn)
                        TF.beam("S", tm, Me @ Vector((sx0 + bw - 0.09, yo - 0.035, bz0)), Me @ Vector((sx0 + bw * 0.5, yo - 0.035, z1 - 0.3)), 0.14, 0.14, up=wn)
        # 石基座（门洞处断开）
        segs = rail_segs                                    # 石基座与腰梁让开同样的区间
        for (s0, s1) in segs:
            if s1 - s0 > 0.1:
                G.box("S", st["STONE"], s1 - s0, 0.2, 1.05 + 1.8, Me @ T((s0 + s1) / 2, yo - 0.1, -1.8))        # 石基座向下接到 1.8m（坡地上不悬空）
        # 凸窗（T05，盖在实心墙面外）/ 谷仓双开门（T06，贴墙面）
        if e == 0:
            for k in sorted(oriel):
                stamp.place(G, st, "bay", Me @ T(k * bw + bw / 2, yo + 0.02, 0) @ SCL @ S3(0.66, 0.66, 0.66) @ T(0, 0, 0.2), WT)
        if barn is not None and barn[0] == e:
            stamp.place(G, st, "barn", Me @ T(barn[1] * bw + bw / 2, yo, 0) @ SCL @ S3(0.66, 0.66, 0.66) @ T(0, -0.1, 0), WT)
    # 转角柱 + 隅石
    for e in range(n):
        v = Vector(out[e])
        TF.box("S", st["TIMBER"], 0.3, 0.3, H - 0.3, T(v.x, v.y, 0))
    return info


# ---------------------------------------------------------------- 屋顶
def shingle(G, mk, xa, xb, yl, yu, lift, M, rr):
    """一片瓦（洛奇M Bangor / Dunbarton 屋顶那种平涂方瓦）：下缘两角圆润、下缘翘起 lift、中间微微拱起、四周有厚度，上缘埋进下一排之下。
    局部坐标：x 沿檐口、y 沿坡向上、z 屋面法向；M 把它放到屋面上。闭合体（含底面），不依赖法线重算。"""
    w = xb - xa
    rc = min(0.1, w * 0.22)
    jt = lambda: rr.uniform(-0.012, 0.012)
    pts = [(xa + rc, yl), (xb - rc, yl)]
    for a in (-45.0, 0.0):                                   # 右下圆角
        pts.append((xb - rc + rc * math.cos(math.radians(a)), yl + rc + rc * math.sin(math.radians(a))))
    pts += [(xb, yu), (xa, yu)]
    for a in (180.0, 225.0):                                 # 左下圆角
        pts.append((xa + rc + rc * math.cos(math.radians(a)), yl + rc + rc * math.sin(math.radians(a))))
    n = len(pts)
    xm = (xa + xb) / 2
    camber = rr.uniform(0.008, 0.02)
    top, bot = [], []
    for (x, y) in pts:
        t = (y - yl) / max(yu - yl, 1e-4)
        z = lift * (1.0 - t) + camber * (1.0 - ((x - xm) / (w / 2)) ** 2)
        x, y = x + jt(), y + jt()
        top.append((x, y, z))
        bot.append((x, y, min(z, 0.0) - 0.05))
    v = top + bot
    f = [tuple(range(n)), tuple(range(2 * n - 1, n - 1, -1))]
    for i in range(n):
        j = (i + 1) % n
        f.append((i, i + n, j + n, j))
    G.raw("S", mk, v, f, M)


def thatch_patch(G, mk, sw, Wd, M, rr, flip, eyebrows=()):
    """一块茅草屋面（局部：x 沿檐口居中 [-sw/2, sw/2]，y 从檐口 0 到屋脊 Wd，z 屋面法向；底板顶面在 z = 0）。
    参考图的厚茅草：整块圆润隆起，檐口 / 山墙边缘像圆角厚垫一样卷下去，表面有大起伏（草束层叠的鼓包），可加「眉毛窗」式的隆起。
    只建上表面（下面有实心底板）；面朝向自己保证（keep），镜像侧 flip 反转绕序。"""
    nx = max(4, int(sw / 0.32))
    ny = max(4, int(Wd / 0.32))
    ph = [rr.uniform(0, 6.28) for _ in range(6)]
    def rnd(d, r):                                    # 圆角剖面：d=0 → 0，d>=1 → 1
        d = max(0.0, min(1.0, d))
        return math.sqrt(max(0.0, 1.0 - (1.0 - d) ** 2))
    def zf(x, y):
        ex = min(x + sw / 2, sw / 2 - x)
        fy = rnd(y / 0.7, 0)
        fx = rnd(ex / 0.6, 0)
        base = 0.46 + 0.07 * math.sin(x * 1.7 + ph[0]) + 0.06 * math.sin(y * 2.3 + x * 0.9 + ph[1]) + 0.04 * math.sin(x * 4.1 + y * 3.3 + ph[2])
        base += 0.18 * smooth((y - Wd * 0.72) / (Wd * 0.28))     # 屋脊处加厚
        for (ex0, ey0, er) in eyebrows:
            d2 = ((x - ex0) / er) ** 2 + ((y - ey0) / (er * 1.15)) ** 2
            base += 0.85 * math.exp(-d2 * 1.6)
        z = -0.05 + base * min(fx, fy)
        # 檐口下垂：圆角卷到底板下面一点
        z -= 0.10 * (1.0 - fy) ** 2
        return z
    def smooth(a):
        a = max(0.0, min(1.0, a))
        return a * a * (3 - 2 * a)
    verts, faces = [], []
    for j in range(ny + 1):
        for i in range(nx + 1):
            x = -sw / 2 + sw * i / nx
            y = Wd * j / ny + 0.04
            verts.append((x + 0.0, y, zf(x, min(y, Wd))))
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            q = (a, a + 1, a + 1 + (nx + 1), a + (nx + 1))
            faces.append(q[::-1] if flip else q)
    G.raw("S", mk, verts, faces, M, keep=True)


def gable_roof(G, st, part, H, rnd, sp):
    """双坡屋面（两块实体屋面板 + 屋脊）+ 山墙三角（含木筋 / 圆窗 / 封檐板）。part: rect / axis / g0 / g1 / a0（可选，覆盖脊线起点）"""
    x0, x1, y0, y1 = part["rect"]
    ax = part["axis"]
    if ax == "x":
        a0, a1, c0, c1 = x0, x1, y0, y1
    else:
        a0, a1, c0, c1 = y0, y1, x0, x1
    a0 = part.get("a0", a0)
    ac, cc = (a0 + a1) / 2, (c0 + c1) / 2
    M0 = T(ac, cc, 0) if ax == "x" else T(cc, ac, 0) @ Rz(math.pi / 2)
    Lr, span = a1 - a0, c1 - c0
    g0, g1 = part["g0"], part["g1"]
    gx = 0.4
    e0, e1 = (gx if g0 else 0.7), (gx if g1 else 0.7)
    Lx = Lr + e0 + e1
    xc = (e1 - e0) / 2
    zr = H + (span / 2) * TN
    xlo, xhi = xc - Lx / 2, xc + Lx / 2
    # 屋面板分段：与另一栋屋面相接处（翼楼与主屋）不出檐，否则檐口会伸进邻室的天花以下
    noeave = {-1: [], 1: []}
    if part.get("clip") is not None:                     # 翼楼：clip 之前（伸进主屋屋顶里的那一段）不出檐
        noeave[-1].append((xlo, part["clip"] - ac)); noeave[1].append((xlo, part["clip"] - ac))
    if part.get("noeave_back") is not None:              # 主屋背坡：翼楼宽度范围内不出檐
        lo, hi = part["noeave_back"]
        noeave[1].append((lo - ac, hi - ac))
    for sd in (-1, 1):
        cuts = sorted(noeave[sd])
        edges = [xlo]
        for (a, b) in cuts:
            a, b = max(a, xlo), min(b, xhi)
            if b > a:
                edges += [a, b]
        edges.append(xhi)
        edges = sorted(set(edges))
        for i in range(len(edges) - 1):
            xa, xb = edges[i], edges[i + 1]
            if xb - xa < 0.02:
                continue
            mid = (xa + xb) / 2
            no = any(a - 1e-6 <= mid <= b + 1e-6 for a, b in cuts)
            ye = -span / 2 - (0.0 if no else OV)
            ze = H + (ye + span / 2) * TN
            Wd = (0 - ye) / CS + 0.1
            Mf = T(mid, ye, ze) @ Rx(PITCH) @ T(0, Wd / 2, -RT)
            M = M0 @ (Mf if sd < 0 else S3(1, -1, 1) @ Mf)
            G.box("S", st["ROOF"], xb - xa + 0.01, Wd, RT, M)                   # 实心底板（室内看天花 / 不漏光）
            # 叠瓦层（参考洛奇M Bangor 工坊屋顶：几百片各自带点歪斜 / 错位的大瓦片，宽 ≈ 0.5–0.6、沿坡长 ≈ 0.85–1.3，一排排压着下一排；
            # 剪影是一圈圈的小台阶，不是一块平板）。每片 = 一个闭合六面体（下缘翘起 3–7cm、上缘埋进底板），逐片抖动尺寸 / 位置 / 翘度。
            Mb = T(mid, ye, ze) @ Rx(PITCH)
            Mbs = M0 @ (Mb if sd < 0 else S3(1, -1, 1) @ Mb)
            rr_ = random.Random(int(mid * 97) * 7 + sd * 3 + int(ye * 13))
            sw = xb - xa
            if st["roof"][0] == "thatch":
                ebs = []
                if sd < 0:
                    for exo in sp.get("eyebrow", []):
                        ebs.append((exo - mid, Wd * 0.46, 1.25))
                thatch_patch(G, rr_.choice(st["ROOFV"]), sw, Wd, Mbs, rr_, sd > 0, ebs)
                continue
            step = 0.48
            nrow = int(Wd / step) + 1
            for r in range(nrow):
                yl = r * step
                yu = min(yl + 0.95, Wd + 0.05)
                if yu - yl < 0.15:
                    continue
                x = -sw / 2 - (r % 2) * 0.3 + rr_.uniform(-0.05, 0.05)
                while x < sw / 2:
                    w = rr_.uniform(0.52, 0.66)
                    xa_, xb_ = max(x, -sw / 2), min(x + w, sw / 2)
                    if xb_ - xa_ > 0.1:
                        shingle(G, rr_.choice(st["ROOFV"]), xa_, xb_, yl, yu, rr_.uniform(0.04, 0.08), Mbs, rr_)
                    x += w + rr_.uniform(0.005, 0.03)
    # 屋脊：半圆截面的圆润脊瓦（沿脊线挤出），不是方条
    rp = [(-0.22, -0.02)] + [(0.22 * math.cos(math.pi * (1 - i / 6.0)), 0.2 * math.sin(math.pi * (1 - i / 6.0)) - 0.02) for i in range(1, 6)] + [(0.22, -0.02)]
    if st["roof"][0] == "thatch":
        rp = [(-0.42, -0.04)] + [(0.42 * math.cos(math.pi * (1 - i / 8.0)), 0.36 * math.sin(math.pi * (1 - i / 8.0)) - 0.04) for i in range(1, 8)] + [(0.42, -0.04)]
    G.prism("S", st["ROOFV"][0], rp[::-1], Lx + 0.06, M0 @ T(xc - (Lx + 0.06) / 2, 0, zr - 0.04) @ M_YZ)
    tm = st["TIMBER"]
    TF = G.TF
    for end, flag in ((-1, g0), (1, g1)):
        if not flag:
            continue
        xe = end * Lr / 2
        pts = [(-span / 2, H - 0.05), (span / 2, H - 0.05), (0, zr - 0.27)]
        G.prism("S", st["PLASTER"], pts, TW, M0 @ T(xe - TW / 2, 0, 0) @ M_YZ)
        xo = xe + end * (TW / 2 + 0.04)
        P = lambda y, z, xo=xo: M0 @ Vector((xo, y, z))
        zt = zr - 0.4
        TF.beam("S", tm, P(0, H - 0.05), P(0, zt), 0.16, 0.1, up=(1, 0, 0))
        TF.beam("S", tm, P(-span / 2 + 0.1, H + 0.02), P(span / 2 - 0.1, H + 0.02), 0.2, 0.1, up=(1, 0, 0))
        zc = H + (zr - H) * 0.45
        TF.beam("S", tm, P(-span * 0.27, zc), P(span * 0.27, zc), 0.12, 0.1, up=(1, 0, 0))
        TF.beam("S", tm, P(-span / 2 + 0.3, H + 0.05), P(-0.05, zc + 0.55), 0.1, 0.08, up=(1, 0, 0))
        TF.beam("S", tm, P(span / 2 - 0.3, H + 0.05), P(0.05, zc + 0.55), 0.1, 0.08, up=(1, 0, 0))
        xr = end * (Lr / 2 + gx)                                   # 封檐板
        for s in (-1, 1):
            TF.beam("S", tm, M0 @ Vector((xr, s * (span / 2 + OV), H - OV * TN - 0.1)), M0 @ Vector((xr, 0, zr + 0.02)), 0.14, 0.22, up=(1, 0, 0))
        wz = zc - 0.5                                              # 圆窗
        R90 = Ry(math.pi / 2)
        G.cyl("N", tm, 0.46, 0.46, 0.06, M0 @ T(xo, 0, wz) @ R90, 16)
        G.cyl("N", PANE, 0.36, 0.36, 0.1, M0 @ T(xo + end * 0.02, 0, wz) @ R90, 16)
    return dict(zr=zr, span=span, M0=M0, ax=ax, ye=ye, cc=cc, ac=ac, Lr=Lr)


def small_gable(G, st, M, hw, L, hh, thick=0.14):
    """小双坡屋顶（脊沿局部 Y）：M 原点在屋脊正下方、檐口高度 hh 处，向 +Y 伸 L。"""
    pr = math.radians(38)
    Wd = hw / math.cos(pr)
    for s in (-1, 1):
        G.box("S", st["ROOF"], Wd, L, thick, M @ T(s * hw / 2, L / 2, hh + hw * math.tan(pr) / 2 - thick / 2) @ Ry(s * pr))
    G.box("S", st["ROOFD"], 0.16, L + 0.04, 0.12, M @ T(0, L / 2, hh + hw * math.tan(pr) - 0.04))


# Tripo 衍生细节件的朝向修正（弧度，预览确认）
TPYAW = {"sign_tavern": 1.5708, "sign_smith": 1.5708, "sign_store": 1.5708, "sign_tailor": 1.5708, "sign_guard": 1.5708, "sign_trainer": 1.5708, "sign_stable": 1.5708}   # 招牌的墙板在模型 +X 端，转到 +Y（靠墙）


def _tp(G, name, M, w=None, d=None, h=None, group="S", roofmk=None):
    # 建筑外立面只使用 Blender 构件库；Tripo 几何不参与墙洞、门廊、窗和屋顶的源头生成。
    return False


def dormer(G, st, M):
    if _tp(G, "dormer", M @ T(0, 0.55, -0.85), 2.1, 2.3, 2.2, roofmk=st["ROOF"]):
        return
    """老虎窗：构件库 T01（窗墙 + 窗 + 木框 + 贴着主屋面的颊墙 + 双坡小屋顶）。M 原点在屋面上、正面朝 -Y；整体下沉 0.3m 埋进屋面。"""
    stamp.place(G, st, "dormer", M @ SCL @ T(0, 0, -0.3), None, w=1.8, h=1.75, tn=round(TN, 4))


def chimney(G, st, x, y, z0, z1, M=I):
    if _tp(G, "chimney", M @ T(x, y, z0), 1.3, 1.3, (z1 - z0) + 1.0):
        p = M @ Vector((x, y, z1 + 0.7))
        G.smoke.append((p.x, p.y, p.z))
        return
    """石烟囱：构件库 T02（石块阵列 + 腰线 + 压顶 + 陶罐烟帽）；高度由石块层数决定，再微调纵向缩放吻合 z0..z1。"""
    h = (z1 - z0) * SC
    n = max(6, round(h / 0.34))
    kz = h / (n * 0.34)
    stamp.place(G, st, "chimney", M @ T(x, y, z0) @ S3(1 / SC, 1 / SC, kz / SC), None, keep=("terracotta",), n=n, s=1.1)
    p = M @ Vector((x, y, z1 + 0.7))
    G.smoke.append((p.x, p.y, p.z))


def porch(G, st, Me, cx, rnd):
    """门廊：构件库 T04（立柱 / 檐托 / 横梁 / 双坡小屋顶 / 前山尖 / 盾徽）+ 石阶斜坡。Me 为正面边的坐标系，cx 为门中心。"""
    dpt = 1.6
    zc = 2.75
    if _tp(G, "porch", Me @ T(cx, -(TW / 2 + dpt / 2 + 0.05), 0), 3.2, dpt + 0.3, 3.3, roofmk=st["ROOF"]):
        doorstep(G, st, Me, cx, dpt)
        return
    stamp.place(G, st, "porch", Me @ T(cx, 0, 0) @ SCL, WT, zc=round(zc * SC, 3), D=round((TW / 2 + dpt) * SC, 3), hw=round(1.15 * SC, 3), ground=False)
    doorstep(G, st, Me, cx, dpt)

def doorstep(G, st, Me, cx, extra=0.0):
    yo = -TW / 2
    G.prism("S", st["STONE"], [(yo - extra - 1.2, 0), (yo - extra, 0), (yo - extra, FL)], 2.0, Me @ T(cx - 1.0, 0, 0) @ M_YZ)
    if extra > 0:
        G.box("S", st["STONE"], 2.0, extra, FL, Me @ T(cx, yo - extra / 2, 0))


def ivy_climb(G, st, rnd, p, o, z0=1.05):
    """常春藤：构件库 T08a（藤 + 叶片卡片阵列）贴在墙上往上爬。p = 墙心线上的点，o = 外法线；z0 起点（石基座顶）。无碰撞。"""
    hgt = rnd.choice((1.8, 2.3, 2.7))
    th = math.atan2(o.x, -o.y)
    stamp.place(G, st, "ivy", T(p.x + o.x * 0.1, p.y + o.y * 0.1, z0) @ Rz(th) @ SCL, WT, force="N", nl=int(hgt * 13), hgt=hgt)


def bush(G, rnd, x, y, r=0.7, berries=True, st=None):
    """灌木：构件库 T08b（叶片卡片螺旋 + 暗色内核 + 红莓），三种叶团变体随机旋转 / 缩放。无碰撞。"""
    seed = rnd.choice((9, 10, 11))
    s = r / 1.05
    stamp.place(G, st, "bush", T(x, y, 0) @ Rz(rnd.uniform(0, 2 * math.pi)) @ S3(s / SC, s / SC, s / SC), None, force="N", n=70, seed=seed)


SIGN_OF = {"tavern": "tavern", "smithy": "smith", "store": "store", "tailor": "tailor", "guard": "guard", "trainer": "trainer", "stable": "stable"}


def build_exterior_dressing(G, st, sp, info, out, H, rnd, roofs, W, D):
    # （2026-10-10：藤蔓 / 草丛的叶片卡片偏硬表面，已删除；灌木改成低多边形圆团）
    # 灌木带 + 花坛 + 草丛：沿墙基外侧（构件 T08b / c / d）
    for e, ed in enumerate(info):
        a, b = ed["a"], ed["b"]
        d = (b - a).normalized()
        o = Vector((d.y, -d.x, 0))
        L = ed["L"]
        th = ed["th"]
        dx = ed["door_x"]
        t = 0.9
        while t < L - 0.5:
            if dx is not None and abs(t - dx) < 2.3:
                t += 1.0
                continue
            u = rnd.random()
            k = TW / 2 + 0.75
            if u < sp.get("bushes", 0.8):
                bush(G, rnd, a.x + d.x * t + o.x * k, a.y + d.y * t + o.y * k, rnd.uniform(0.5, 0.8), st=st)
            t += rnd.uniform(1.3, 2.0)
        # 花坛：门两侧各一个（沿墙，木框 + 土 + 花叶）
        if e == 0 and dx is not None and sp.get("beds", 0.7) > 0:
            for sgn in (-1, 1):
                bx = dx + sgn * (1.5 + 1.0)
                if 1.0 < bx < L - 1.0 and rnd.random() < sp.get("beds", 0.7):
                    if not _tp(G, "planter", ed["Me"] @ T(bx, -(TW / 2 + 0.7), 0), 1.1, None, None, "N"):
                        stamp.place(G, st, "flowerbed", ed["Me"] @ T(bx, -(TW / 2 + 0.62), 0) @ SCL, None)
        # 招牌：门右侧木柱上挂一块（店铺）
        if e == 0 and dx is not None and sp.get("sign") and stamp.tp_has("sign_" + SIGN_OF.get(sp["id"], "tavern")):
            sx_ = dx + (ed["bw"] * 0.5 + 0.35)
            _tp(G, "sign_" + SIGN_OF.get(sp["id"], "tavern"), ed["Me"] @ T(sx_, -(TW / 2 + 0.85), 2.45), 1.7, None, None, "N")
        elif e == 0 and dx is not None and sp.get("sign"):
            smithy = sp.get("sign") == "smith"
            stamp.place(G, st, "sign", ed["Me"] @ T(dx + ed["bw"] / 2, -(TW / 2 + 0.12), 0) @ SCL @ T(0, 0, 0.55), None,
                        emblem="hammers" if smithy else "shield", board_mk="darksteel" if smithy else "door")
        # 栅栏：前院低栅栏（门口留 3.4m 缺口）
        if e == 0 and dx is not None and sp.get("fence"):
            sec = 3.0 / SC
            n = int((L - 0.4) // sec)
            x0 = (L - n * sec) / 2
            yy = -(TW / 2 + sp.get("fence_d", 3.6))
            for i in range(n):
                xm = x0 + i * sec + sec / 2
                if abs(xm - dx) < 1.7 + sec / 2 - 0.3:
                    continue
                if not _tp(G, "fence", ed["Me"] @ T(x0 + i * sec + sec / 2, yy, 0), sec, None, None, "S"):
                    stamp.place(G, st, "fence", ed["Me"] @ T(x0 + i * sec, yy, 0) @ SCL, None, gate=False)


def roof_surface_z(H, span, c):
    return H + (span / 2 - abs(c)) * TN





