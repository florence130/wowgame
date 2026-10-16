# 内饰与家具。所有函数把几何加进 Geo：大件有碰撞（S），小件 / 装饰无碰撞（N）。
# 参考 ref26（魔兽酒馆内景）：石砌 + 粗木柱 / 横梁、红桌布长桌、铁箍酒桶、吊灯烛台、壁炉、书架、红地毯。
import math, random
from mathutils import Vector
from geo import T, Rz, Rx, Ry, S3, I
from house import K, TW, FL, WOODL, WOODD, IRON, FIRE, GLOW, RUBBLE, STONEM, LEAF, FLOWERS, PANE

CLOTH_RED = K(0, "a8362e", "", 3)
CLOTH_BLUE = K(0, "3f5f93", "", 3)
CLOTH_CREAM = K(0, "e8dcc0", "", 3)
CLOTH_GREEN = K(0, "4f7a52", "", 3)
GOODS = ["c0453a", "e0b04a", "4f8f7d", "5b73b0", "d97c9a", "e8dcc0", "8a6ad0", "d98a3a"]
HAY = K(0, "d8b24f", "", 3)
SOOT = K(0, "2a2220", "", 3)
STRAW = K(0, "cfae5a", "", 3)


# 2026-10-10：建筑源头审计后，家具也统一走 Blender 程序化构件；Tripo 资产保留在独立道具目录。
import stamp
TPYAW = {"chair": 3.14159265}      # Tripo 椅子靠背在 +Y；原调用点按「靠背朝桌」摆的，整体转 180° 变成背朝外


def _tp(G, name, M, w=None, d=None, h=None, group="S"):
    return False


def mabi(G, M, obj, tex, scale=1.0, group="S", mod=None):
    """直接取用洛奇M 解包模型（带它自己的 UV 图集贴图）。M 与家具函数同一约定：局部 +Y 是床头 / 椅背。"""
    import stamp
    stamp.put_obj(G, stamp.get_obj(obj, tex, scale, mod=mod), M, group)


def bed_m(G, M):
    if _tp(G, "bed", M, 1.45, 2.2, 1.15):
        return
    """洛奇M Housing_Bed_Antique（2.6×3.0 的雕花大床）缩到 1.6×1.9m。"""
    # 底模取自洛奇M，但做成我们自己的衍生款：床身压扁 / 微弯 / 床尾收分、顶点手作抖动，图集换成偏青绿的被面色并向平涂压平
    mabi(G, M, "Housing_Bed_Antique_00", "Housing_Bed_Antique_00_T00", 0.62, "S",
         dict(s=(1.0, 0.9, 0.92), jitter=0.02, bend=0.05, taper=0.04, hue=-35, sat=0.8, val=1.06, flat=0.4, tag="bed"))


def chair_m(G, M):
    if _tp(G, "chair", M, 0.62, 0.62, 1.15, "N"):
        return
    """洛奇M Colhen 医师屋的扶手椅（0.8×0.8×1.25，蓝坐垫）。"""
    mabi(G, M, "Colhen_Interior_HealerHouse_00_Chair", "Colhen_HealerHouse_Inside_00", 1.0, "N",
         dict(s=(1.05, 1.0, 0.94), jitter=0.012, bend=0.06, hue=-55, sat=0.85, val=1.05, flat=0.3, tag="chair"))


def M_(x, y, z=FL, rot=0.0):
    return T(x, y, z) @ Rz(rot)


# ------------------------------------------------------------------ 家具
def table(G, M, w=1.6, d=0.9, h=0.82, cloth=None, items=True, rnd=None):
    if _tp(G, "table", M, w, d, h):
        return
    top = WOODL
    G.box("S", cloth or top, w, d, 0.07, M @ T(0, 0, h - 0.07))
    if cloth:
        for sx in (-1, 1):
            G.box("N", cloth, 0.03, d, 0.32, M @ T(sx * (w / 2), 0, h - 0.34))
        for sy in (-1, 1):
            G.box("N", cloth, w, 0.03, 0.32, M @ T(0, sy * (d / 2), h - 0.34))
    for sx in (-1, 1):
        for sy in (-1, 1):
            G.box("S", WOODD, 0.09, 0.09, h - 0.07, M @ T(sx * (w / 2 - 0.1), sy * (d / 2 - 0.1), 0))
    if items and rnd is not None:
        G.cyl("N", K(0, "d9d2c2", "", 3), 0.13, 0.1, 0.03, M @ T(rnd.uniform(-0.3, 0.3), rnd.uniform(-0.15, 0.15), h), 10)
        G.cyl("N", K(6, "7a5a3a", "pt_wood", 1.0), 0.05, 0.045, 0.1, M @ T(rnd.uniform(-0.5, 0.5), rnd.uniform(-0.2, 0.2), h), 8)
        cx, cy = rnd.uniform(-0.4, 0.4), rnd.uniform(-0.15, 0.15)
        G.cyl("N", K(0, "efe4c8", "", 3), 0.025, 0.025, 0.14, M @ T(cx, cy, h), 6)
        G.ico("N", FIRE, 0.03, M @ T(cx, cy, h + 0.17), 0)


def bench(G, M, w=1.6, d=0.3, h=0.46):
    if _tp(G, "bench_long", M, w, max(d, 0.42), h, "N"):
        return
    G.box("N", WOODL, w, d, 0.05, M @ T(0, 0, h - 0.05))
    for sx in (-1, 1):
        G.box("N", WOODD, 0.07, d - 0.06, h - 0.05, M @ T(sx * (w / 2 - 0.12), 0, 0))


def stool(G, M, r=0.17, h=0.46):
    if _tp(G, "stool", M, r * 2.2, r * 2.2, h, "N"):
        return
    G.cyl("N", WOODL, r, r, 0.05, M @ T(0, 0, h - 0.05), 10)
    for i in range(3):
        a = i * 2 * math.pi / 3
        G.box("N", WOODD, 0.05, 0.05, h - 0.05, M @ T(math.cos(a) * r * 0.6, math.sin(a) * r * 0.6, 0))


def chair(G, M, h=0.46):
    if _tp(G, "chair", M, 0.55, 0.55, h * 2.4, "N"):
        return
    stool(G, M, 0.19, h)
    G.box("N", WOODD, 0.36, 0.05, 0.5, M @ T(0, 0.18, h))


def barrel(G, M, r=0.36, h=0.95):
    if _tp(G, "barrel", M, r * 2.1, r * 2.1, h):
        return
    half = h / 2
    G.cyl("S", WOODL, r * 0.85, r, half, M, 10)
    G.cyl("S", WOODL, r, r * 0.85, half, M @ T(0, 0, half), 10)
    for z, rr in ((0.1, r * 0.88), (half, r * 1.01), (h - 0.1, r * 0.88)):
        G.cyl("N", IRON, rr + 0.012, rr + 0.012, 0.045, M @ T(0, 0, z), 10, False)


def crate(G, M, s=0.6):
    G.box("S", WOODL, s, s, s, M)
    for z in (0.05, s - 0.1):
        G.box("N", WOODD, s + 0.02, s + 0.02, 0.05, M @ T(0, 0, z))


BURLAP = K(0, "c8a878", "", 3)


def sack(G, M, rnd, r=0.3):
    G.ico("N", BURLAP, r, M @ T(0, 0, r * 0.75) @ S3(1, 1, 1.15), 1, 0.08, rnd.randint(0, 99))
    G.cyl("N", BURLAP, r * 0.3, 0.04, 0.16, M @ T(0, 0, r * 1.5), 6)
    G.cyl("N", K(0, "6a4a2a", "", 3), r * 0.32, r * 0.32, 0.03, M @ T(0, 0, r * 1.5 + 0.02), 6)


def rug(G, M, w=2.4, l=1.6, col=CLOTH_RED, border=K(0, "d9b86a", "", 3)):
    G.box("N", border, w, l, 0.02, M @ T(0, 0, 0.0))
    G.box("N", col, w - 0.3, l - 0.3, 0.03, M @ T(0, 0, 0.0))


def shelf(G, M, w=1.4, h=2.1, d=0.38, rnd=None, kind="books", rows=4):
    if _tp(G, "bookshelf", M, w, d + 0.1, h):
        return
    for sx in (-1, 1):
        G.box("S", WOODD, 0.07, d, h, M @ T(sx * (w / 2 - 0.035), 0, 0))
    G.box("S", WOODD, w, 0.04, h, M @ T(0, d / 2 - 0.02, 0))
    for r in range(rows + 1):
        z = 0.1 + r * (h - 0.18) / rows
        G.box("S", WOODL, w - 0.1, d, 0.04, M @ T(0, 0, z))
        if rnd is not None and r < rows:
            x = -w / 2 + 0.12
            while x < w / 2 - 0.15:
                if kind == "books":
                    bw, bh = rnd.uniform(0.04, 0.09), rnd.uniform(0.2, 0.32)
                    G.box("N", K(0, rnd.choice(GOODS), "", 3), bw, d * 0.7, bh, M @ T(x + bw / 2, -0.02, z + 0.04))
                    x += bw + 0.005
                elif kind == "bottles":
                    G.cyl("N", K(0, rnd.choice(["4f8f7d", "7a4a2a", "5b73b0", "b0404a"]), "", 3), 0.045, 0.04, 0.24, M @ T(x + 0.05, -0.02, z + 0.04), 8)
                    x += 0.13
                else:
                    bw = rnd.uniform(0.18, 0.3)
                    G.box("N", K(0, rnd.choice(GOODS), "", 3), bw, d * 0.7, rnd.uniform(0.14, 0.28), M @ T(x + bw / 2, -0.02, z + 0.04))
                    x += bw + 0.05


def bed(G, M, w=1.0, l=2.0, blanket=CLOTH_BLUE):
    if _tp(G, "bed", M, w + 0.4, l + 0.2, 1.1):
        return
    G.box("S", WOODL, w, l, 0.38, M)
    G.box("N", CLOTH_CREAM, w - 0.1, l - 0.12, 0.18, M @ T(0, 0, 0.38))
    G.box("N", blanket, w - 0.08, l * 0.55, 0.1, M @ T(0, -l * 0.18, 0.54))
    G.box("N", CLOTH_CREAM, w * 0.6, 0.32, 0.12, M @ T(0, l * 0.38, 0.56))
    G.box("S", WOODD, w + 0.06, 0.1, 0.95, M @ T(0, l / 2, 0))
    G.box("S", WOODD, w + 0.06, 0.08, 0.55, M @ T(0, -l / 2, 0))


def counter(G, M, ln=3.0, w=0.75, h=1.05):
    if _tp(G, "counter", M, ln, w + 0.15, h):
        return
    G.box("S", WOODD, ln, w - 0.1, h - 0.08, M @ T(0, 0, 0))
    G.box("S", WOODL, ln + 0.12, w + 0.14, 0.08, M @ T(0, 0, h - 0.08))
    n = max(2, int(ln / 0.9))
    for i in range(n + 1):
        G.box("N", WOODL, 0.07, 0.04, h - 0.2, M @ T(-ln / 2 + i * ln / n, -(w - 0.1) / 2 - 0.02, 0.06))


def cupboard(G, M, w=1.1, h=1.9, d=0.5):
    if _tp(G, "cupboard", M, w, d + 0.1, h):
        return
    G.box("S", WOODL, w, d, h, M)
    for sx in (-1, 1):
        G.box("N", WOODD, w / 2 - 0.06, 0.03, h - 0.3, M @ T(sx * w / 4, -d / 2 - 0.015, 0.12))
        G.box("N", IRON, 0.04, 0.05, 0.1, M @ T(sx * 0.07, -d / 2 - 0.05, h * 0.5))
    G.box("N", WOODD, w + 0.1, d + 0.06, 0.08, M @ T(0, 0, h))


def fireplace(G, ctx, M, w=2.0, h=2.7, depth=0.75, big=False):
    """壁炉：石墩 + 石过梁 + 烟道墩到天花；炉膛里有火（发光）和柴；M 的 -Y 方向朝房内。"""
    Hc = ctx["Hc"]
    ow = w - 1.1
    if _tp(G, "fireplace", M @ T(0, 0, 0), w + 0.4, depth + 0.5, min(Hc - 0.25, 4.0)):
        pass
    else:
        for sx in (-1, 1):
            G.box("S", RUBBLE, 0.55, depth, 1.4, M @ T(sx * (ow / 2 + 0.275), 0, 0))
        G.box("S", RUBBLE, w, depth, 0.3, M @ T(0, 0, 1.4))
        G.box("S", STONEM, w + 0.3, depth + 0.2, 0.1, M @ T(0, -0.1, 1.7))
        G.box("S", RUBBLE, w - 0.3, depth - 0.2, Hc - 1.8, M @ T(0, 0.1, 1.8))
        G.box("N", SOOT, ow, 0.08, 1.4, M @ T(0, depth / 2 - 0.06, 0))
        G.box("S", STONEM, w + 0.4, 0.55, 0.08, M @ T(0, -depth / 2 - 0.2, 0))
        G.box("N", FIRE, ow * 0.55, 0.3, 0.32, M @ T(0, 0.1, 0.1))
        G.ico("N", FIRE, 0.2, M @ T(0, 0.05, 0.45) @ S3(1, 0.7, 1.4), 1)
        for i in range(3):
            G.beam("N", WOODD, M @ Vector((-0.4 + i * 0.35, -0.12, 0.1)), M @ Vector((-0.2 + i * 0.35, 0.25, 0.14)), 0.1, 0.1)
    p = M @ Vector((0, -0.5, 0.9))
    G.lights.append((p.x, p.y, p.z + FL, 9.0 if big else 6.5, 1.6 if big else 1.2))
    # 壁炉上方的小摆件
    G.box("N", K(0, "6b4a2e", "", 3), 0.5, 0.06, 0.4, M @ T(0.4, -depth / 2 - 0.0, 2.05))


def chandelier(G, ctx, x, y, r=0.55, n=6, drop=0.9, light=1.3):
    Hc = ctx["Hc"]
    z = Hc - drop
    if _tp(G, "chandelier", T(x, y, z - 0.35), r * 2.5, r * 2.5, drop + 0.55, "N"):
        G.lights.append((x, y, z - 0.1, 9.0, light))
        return
    G.box("N", IRON, 0.04, 0.04, drop, T(x, y, z))
    seg = 10
    for i in range(seg):
        a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
        G.beam("N", IRON, (x + math.cos(a0) * r, y + math.sin(a0) * r, z), (x + math.cos(a1) * r, y + math.sin(a1) * r, z), 0.05, 0.05)
    for i in range(n):
        a = 2 * math.pi * i / n
        cx, cy = x + math.cos(a) * r, y + math.sin(a) * r
        G.cyl("N", K(0, "efe4c8", "", 3), 0.035, 0.035, 0.17, T(cx, cy, z + 0.05), 6)
        G.ico("N", FIRE, 0.045, T(cx, cy, z + 0.26) @ S3(1, 1, 1.4), 0)
    G.lights.append((x, y, z - 0.1, 9.0, light))


def wall_lamp(G, ctx, x, y, z, rot=0.0):
    M = T(x, y, z) @ Rz(rot)
    G.box("N", IRON, 0.08, 0.2, 0.24, M)
    G.ico("N", FIRE, 0.07, M @ T(0, -0.1, 0.25) @ S3(1, 1, 1.3), 0)
    p = M @ Vector((0, -0.2, 0.3))
    G.lights.append((p.x, p.y, p.z, 5.0, 0.7))


def painting(G, M, w=0.7, h=0.9, rnd=None):
    G.box("N", WOODD, w + 0.12, 0.05, h + 0.12, M)
    cols = ["6d8a5a", "b0884a", "5b73b0", "a8504a"]
    G.box("N", K(0, (rnd or random).choice(cols), "", 3), w, 0.06, h, M @ T(0, -0.005, 0.0) @ T(0, 0, 0.0))
    G.box("N", K(0, "d9c892", "", 3), w * 0.6, 0.07, h * 0.4, M @ T(0, -0.01, h * 0.1))


def mannequin(G, M, cloth=CLOTH_RED):
    if _tp(G, "mannequin", M, 0.7, 0.7, 1.85, "N"):
        return
    G.cyl("N", WOODD, 0.22, 0.2, 0.05, M, 10)
    G.box("N", WOODD, 0.05, 0.05, 1.0, M @ T(0, 0, 0.05))
    G.cyl("N", cloth, 0.2, 0.15, 0.55, M @ T(0, 0, 1.0), 10)
    G.cyl("N", cloth, 0.3, 0.2, 0.45, M @ T(0, 0, 0.6), 10)
    G.ico("N", K(0, "d9c7a6", "", 3), 0.11, M @ T(0, 0, 1.68), 1)


def cloth_bolts(G, M, rnd, n=5):
    for i in range(n):
        G.cyl("N", K(0, rnd.choice(GOODS), "", 3), 0.1, 0.1, 0.55, M @ T(i * 0.24 - n * 0.12, 0, 0) @ Ry(math.pi / 2), 8)


def anvil(G, M):
    if _tp(G, "anvil", M, 0.8, 0.5, 0.95):
        return
    G.cyl("S", WOODD, 0.3, 0.26, 0.6, M, 8)
    G.box("S", IRON, 0.7, 0.2, 0.12, M @ T(0, 0, 0.6))
    G.box("S", IRON, 0.3, 0.22, 0.16, M @ T(0, 0, 0.72))
    G.box("S", IRON, 0.22, 0.14, 0.1, M @ T(0.4, 0, 0.62))


def forge(G, ctx, M, w=2.2, h=2.6):
    Hc = ctx["Hc"]
    G.box("S", RUBBLE, w, 1.1, 0.95, M)
    G.box("N", FIRE, w * 0.6, 0.5, 0.12, M @ T(0, 0.05, 0.95))
    G.ico("N", FIRE, 0.28, M @ T(0, 0.05, 1.08) @ S3(1.4, 1, 0.8), 1)
    G.box("S", RUBBLE, 1.2, 0.7, Hc - 0.95, M @ T(0, 0.25, 0.95))
    G.box("N", IRON, 0.5, 0.5, 0.08, M @ T(0.9, -0.8, 0.0))
    G.box("N", IRON, 0.8, 0.3, 0.35, M @ T(-1.0, -0.2, 0.95))                  # 风箱
    G.box("N", WOODL, 0.6, 0.26, 0.28, M @ T(-1.0, -0.2, 1.3))
    p = M @ Vector((0, -0.6, 1.3))
    G.lights.append((p.x, p.y, p.z + FL, 8.5, 1.7))


def weapon_rack(G, M, rnd):
    if _tp(G, "weaponrack", M, 1.6, 0.5, 1.5, "N"):
        return
    G.box("S", WOODD, 1.5, 0.3, 0.1, M)
    for sx in (-1, 1):
        G.box("S", WOODD, 0.08, 0.2, 1.3, M @ T(sx * 0.7, 0, 0))
    G.box("N", WOODD, 1.5, 0.12, 0.08, M @ T(0, 0, 1.0))
    for i in range(5):
        x = -0.55 + i * 0.27
        G.beam("N", IRON, M @ Vector((x, 0, 0.12)), M @ Vector((x + rnd.uniform(-0.04, 0.04), 0, 1.25 - 0.1 * (i % 2))), 0.04, 0.012)
        G.box("N", WOODD, 0.1, 0.04, 0.05, M @ T(x, 0, 0.3))


def dummy(G, M):
    G.box("S", WOODD, 0.12, 0.12, 1.45, M)
    G.box("N", WOODL, 0.7, 0.1, 0.1, M @ T(0, 0, 1.05))
    G.cyl("N", STRAW, 0.2, 0.18, 0.55, M @ T(0, 0, 0.55), 8)
    G.ico("N", STRAW, 0.15, M @ T(0, 0, 1.55), 1)
    G.box("S", WOODD, 0.7, 0.7, 0.08, M)


def stall(G, M, ln=3.0, hay=True):
    for sy in (-1, 1):
        G.box("S", WOODL, ln, 0.1, 1.3, M @ T(0, sy * 1.1, 0))
    G.box("S", WOODL, 0.1, 2.2, 1.0, M @ T(-ln / 2, 0, 0))
    G.box("N", WOODD, ln, 0.12, 0.08, M @ T(0, -1.1, 1.3))
    G.box("N", WOODD, ln, 0.12, 0.08, M @ T(0, 1.1, 1.3))
    if hay:
        G.ico("N", HAY, 0.55, M @ T(ln * 0.1, 0, 0.2) @ S3(1.6, 1.2, 0.5), 1, 0.12, 5)
    G.box("N", WOODL, 0.8, 0.35, 0.3, M @ T(-ln / 2 + 0.4, 0.5, 0.6))


def hay_bale(G, M, rnd=None):
    G.box("N", HAY, 0.9, 0.5, 0.5, M)
    for x in (-0.25, 0.25):
        G.box("N", K(0, "8a6a30", "", 3), 0.04, 0.52, 0.52, M @ T(x, 0, 0))


def lantern_hang(G, ctx, x, y, drop=0.8, light=0.9):
    Hc = ctx["Hc"]
    G.box("N", IRON, 0.02, 0.02, drop, T(x, y, Hc - drop))
    G.box("N", IRON, 0.2, 0.2, 0.26, T(x, y, Hc - drop - 0.26))
    G.ico("N", FIRE, 0.07, T(x, y, Hc - drop - 0.13), 0)
    G.lights.append((x, y, Hc - drop - 0.2, 7.0, light))


def pots_hang(G, M, rnd=None):
    G.beam("N", IRON, M @ Vector((-0.6, 0, 0)), M @ Vector((0.6, 0, 0)), 0.04, 0.04)
    for i in range(3):
        x = -0.4 + i * 0.4
        G.cyl("N", IRON, 0.1, 0.13, 0.16, M @ T(x, 0, -0.35), 10)
        G.box("N", IRON, 0.015, 0.015, 0.2, M @ T(x, 0, -0.2))


def flower_pot(G, M, rnd):
    G.cyl("N", K(4, "b0603a", "", 3), 0.12, 0.09, 0.18, M, 8)
    G.ico("N", rnd.choice(LEAF), 0.15, M @ T(0, 0, 0.26) @ S3(1, 1, 0.8), 1)
    G.ico("N", rnd.choice(FLOWERS), 0.06, M @ T(0.05, 0, 0.36), 0)


# ------------------------------------------------------------------ 内壳：护墙板 / 立柱 / 天花梁
def shell(G, ctx, wain="wood", beams=True, post_every=2):
    Hc, FLr = ctx["Hc"], FL
    st = ctx["st"]
    for e, ed in enumerate(ctx["info"]):
        Me, L, nb, bw = ed["Me"], ed["L"], ed["nb"], ed["bw"]
        yi = TW / 2
        segs = [(0.1, L - 0.1)]
        if ed["door_x"] is not None:
            segs = [(0.1, ed["door_x"] - 0.9), (ed["door_x"] + 0.9, L - 0.1)]
        # 护墙板（木 / 石）
        for s0, s1 in segs:
            if s1 - s0 > 0.2:
                mk = RUBBLE if wain == "stone" else WOODL
                G.box("S", mk, s1 - s0, 0.07, 1.15 if wain == "stone" else 1.0, Me @ T((s0 + s1) / 2, yi + 0.035, FLr))
                G.box("N", WOODD, s1 - s0, 0.1, 0.06, Me @ T((s0 + s1) / 2, yi + 0.05, FLr + (1.15 if wain == "stone" else 1.0)))
        # 立柱 + 墙顶横梁
        for k in range(0, nb + 1, post_every):
            x = k * bw
            if ed["door_x"] is not None and abs(x - ed["door_x"]) < 1.0:
                continue
            G.box("S", WOODD, 0.2, 0.14, Hc - FLr, Me @ T(min(max(x, 0.1), L - 0.1), yi + 0.07, FLr))
        G.box("S", WOODD, L, 0.18, 0.26, Me @ T(L / 2, yi + 0.09, Hc - 0.36))
    if beams:
        for p in ctx["parts"]:
            x0, x1, y0, y1 = p["rect"]
            across_x = (x1 - x0) < (y1 - y0)       # 沿短边架梁
            n = max(2, int(((y1 - y0) if not across_x else (x1 - x0)) / 1.6))
            for i in range(1, n):
                if not across_x:
                    yy = y0 + i * (y1 - y0) / n
                    G.box("S", WOODD, x1 - x0 - TW, 0.24, 0.3, T((x0 + x1) / 2, yy, Hc - 0.44))
                else:
                    xx = x0 + i * (x1 - x0) / n
                    G.box("S", WOODD, 0.24, y1 - y0 - TW, 0.3, T(xx, (y0 + y1) / 2, Hc - 0.44))


def inner(p, m=0.5):
    x0, x1, y0, y1 = p["rect"]
    return x0 + m, x1 - m, y0 + m, y1 - m


def rooms(ctx):
    """主室与翼室的内部范围；主室背墙可用的 x 上限 xb（L 形时被翼楼挡住）。"""
    parts = ctx["parts"]
    mx0, mx1, my0, my1 = inner(parts[0])
    xb = mx1
    wing = None
    if len(parts) > 1:
        wx0, wx1, wy0, wy1 = inner(parts[1])
        wing = (wx0, wx1, wy0, wy1)
        if parts[1]["rect"][0] > 0:
            xb = parts[1]["rect"][0] - 0.5
        else:
            mx0 = parts[1]["rect"][1] + 0.5
    return (mx0, mx1, my0, my1, xb), wing


# ------------------------------------------------------------------ 预设
def furnish(G, sp, ctx):
    kind = sp.get("interior", "home")
    rnd = ctx["rnd"]
    wain = {"tavern": "stone", "smithy": "stone", "guard": "stone"}.get(kind, "wood")
    shell(G, ctx, wain)
    fn = PRESETS.get(kind)
    if fn:
        fn(G, ctx, rnd, sp)


def home(G, ctx, rnd, sp):
    (x0, x1, y0, y1, xb), wing = rooms(ctx)
    cxm = (x0 + xb) / 2
    fireplace(G, ctx, M_(x0 + (xb - x0) * 0.28, y1 + 0.38, FL, 0.0), w=2.0)
    tx, ty = cxm + 0.6, (y0 + y1) / 2 - 0.2
    rug(G, M_(tx, ty, FL + 0.0), 2.6, 1.8, CLOTH_RED if sp.get("style", "mm").startswith("mm") else CLOTH_GREEN)
    table(G, M_(tx, ty), 1.5, 0.85, cloth=None, rnd=rnd)
    for sx in (-1, 1):
        stool(G, M_(tx + sx * 0.55, ty + 0.7))
    chair_m(G, M_(tx - 1.15, ty, FL, -math.pi / 2))
    bed_m(G, M_(x1 - 1.1 if xb >= x1 - 0.1 else xb - 1.1, y1 - 1.3))
    shelf(G, M_(x0 + 0.3, (y0 + y1) / 2 - 0.4, FL, math.pi / 2), 1.5, 2.0, rnd=rnd)
    barrel(G, M_(x0 + 0.5, y0 + 0.5))
    crate(G, M_(x0 + 1.1, y0 + 0.4), 0.5)
    sack(G, M_(x0 + 0.45, y0 + 1.15), rnd)
    chandelier(G, ctx, tx, ty, 0.45, 5, 0.8, 1.1)
    pots_hang(G, M_(x0 + (xb - x0) * 0.28, y1 - 0.15, ctx["Hc"] - 0.8))
    painting(G, M_(x0 + (xb - x0) * 0.62, y1 + 0.15 - 0.0, FL + 1.55, math.pi), 0.8, 0.6, rnd) if False else None
    painting(G, M_(x0 - 0.0, y0 + 1.3, FL + 1.55, math.pi / 2), 0.7, 0.9, rnd) if False else None
    flower_pot(G, M_(x1 - 0.5, y0 + 0.5), rnd)
    if wing:
        wx0, wx1, wy0, wy1 = wing
        bed_m(G, M_((wx0 + wx1) / 2, wy1 - 1.3))
        cupboard(G, M_(wx1 - 0.35, (wy0 + wy1) / 2, FL, -math.pi / 2), 1.2)
        table(G, M_(wx0 + 0.9, wy0 + 0.9), 0.9, 0.6, rnd=rnd)
        chair(G, M_(wx0 + 0.9, wy0 + 1.4, FL, math.pi))
        lantern_hang(G, ctx, (wx0 + wx1) / 2, (wy0 + wy1) / 2, 0.7, 0.8)
    wall_lamp(G, ctx, x0 - 0.0 + 0.1, y0 + 0.8, FL + 1.8, math.pi / 2)


def tavern(G, ctx, rnd, sp):
    (x0, x1, y0, y1, xb), wing = rooms(ctx)
    Hc = ctx["Hc"]
    # 后墙：吧台 + 酒架；右墙：大壁炉
    counter(G, M_((x0 + xb) / 2 - 1.5, y1 - 1.7), 4.6, 0.8)
    for i in range(3):
        shelf(G, M_(x0 + 1.5 + i * 1.7, y1 - 0.25), 1.5, 2.3, 0.35, rnd, "bottles", 5)
    for i in range(3):
        barrel(G, M_(xb - 0.6 - i * 0.8, y1 - 0.6))
    fireplace(G, ctx, M_(xb + 0.0 - 0.25, (y0 + y1) / 2 + 0.6, FL, -math.pi / 2), w=2.6, big=True)
    cx = (x0 + xb) / 2 - 1.0
    for j, ty in enumerate((y0 + 2.0, y0 + 4.4)):
        for i, tx in enumerate((cx - 2.2, cx + 1.6)):
            table(G, M_(tx, ty), 2.4, 0.95, cloth=CLOTH_RED, rnd=rnd)
            bench(G, M_(tx, ty - 0.85), 2.2)
            bench(G, M_(tx, ty + 0.85), 2.2)
    rug(G, M_(cx - 0.3, (y0 + y1) / 2 + 0.5), 5.0, 3.0, K(0, "6a2f3a", "", 3))
    chandelier(G, ctx, cx - 2.2, y0 + 3.2, 0.75, 8, 1.2, 1.6)
    chandelier(G, ctx, cx + 1.6, y0 + 3.2, 0.75, 8, 1.2, 1.6)
    chandelier(G, ctx, cx - 0.3, y1 - 2.2, 0.6, 6, 1.1, 1.3)
    for i in range(2):
        wall_lamp(G, ctx, x0 + 0.1, y0 + 2.0 + i * 4.0, FL + 2.1, math.pi / 2)
    # 二层回廊（装饰，无碰撞）：沿左墙一圈挑台 + 栏杆
    gz = 3.3
    G.box("N", WOODL, 1.4, y1 - y0 - 0.4, 0.2, T(x0 + 0.7, (y0 + y1) / 2, gz))
    n = 14
    for i in range(n + 1):
        G.box("N", WOODD, 0.05, 0.05, 0.9, T(x0 + 1.4, y0 + 0.2 + i * (y1 - y0 - 0.4) / n, gz + 0.2))
    G.box("N", WOODD, 0.1, y1 - y0 - 0.4, 0.08, T(x0 + 1.4, (y0 + y1) / 2, gz + 1.1))
    painting(G, M_(x0 + 0.02, (y0 + y1) / 2 - 1.0, FL + 1.6, math.pi / 2), 1.0, 1.2, rnd) if False else None
    G.box("N", K(0, "7a5a3a", "", 3), 0.06, 1.1, 0.8, T(x0 + 0.03, y0 + 1.4, FL + 1.7))


def smithy(G, ctx, rnd, sp):
    if sp.get("smith"):
        import smith
        return smith.interior(G, ctx, rnd, sp)
    (x0, x1, y0, y1, xb), wing = rooms(ctx)
    forge(G, ctx, M_((x0 + x1) / 2, y1 - 0.8, FL), 2.4)
    anvil(G, M_((x0 + x1) / 2 + 0.3, (y0 + y1) / 2 + 0.3))
    barrel(G, M_(x1 - 0.5, y1 - 0.6))
    G.box("N", K(0, "3a6a8a", "", 3), 0.55, 0.55, 0.12, M_(x1 - 0.5, y1 - 0.6, FL + 0.9))       # 淬火水
    weapon_rack(G, M_(x0 + 0.7, y1 - 0.45), rnd)
    weapon_rack(G, M_(x0 + 0.5, (y0 + y1) / 2, FL, math.pi / 2), rnd)
    table(G, M_(x1 - 1.0, (y0 + y1) / 2 + 0.2, FL, math.pi / 2), 1.8, 0.8, rnd=rnd)
    shelf(G, M_(x1 - 0.3, y0 + 1.4, FL, -math.pi / 2), 1.4, 1.9, rnd=rnd, kind="goods", rows=3)
    for i in range(3):
        crate(G, M_(x0 + 0.5 + i * 0.7, y0 + 0.5), 0.55)
    G.ico("N", K(0, "2a2a2e", "", 3), 0.5, M_(x1 - 1.2, y1 - 0.9, FL + 0.1) @ S3(1.3, 1, 0.55), 1, 0.15, 3)   # 煤堆
    lantern_hang(G, ctx, (x0 + x1) / 2, (y0 + y1) / 2, 0.9, 1.0)
    rug(G, M_((x0 + x1) / 2, (y0 + y1) / 2 - 0.4), 2.0, 1.4, K(0, "5a4a3a", "", 3))


def store(G, ctx, rnd, sp):
    (x0, x1, y0, y1, xb), wing = rooms(ctx)
    counter(G, M_((x0 + x1) / 2 + 0.6, (y0 + y1) / 2 + 0.6), 3.2, 0.8)
    for i in range(3):
        shelf(G, M_(x0 + 1.1 + i * 1.6, y1 - 0.25), 1.5, 2.2, 0.38, rnd, "goods", 5)
    shelf(G, M_(x0 + 0.25, (y0 + y1) / 2 - 0.5, FL, math.pi / 2), 1.6, 2.0, 0.38, rnd, "goods", 4)
    for i in range(4):
        barrel(G, M_(x1 - 0.5 - (i % 2) * 0.8, y0 + 0.6 + (i // 2) * 0.8))
    for i in range(3):
        crate(G, M_(x1 - 0.5, y1 - 0.6 - i * 0.7), 0.55)
    for i in range(4):
        sack(G, M_(x0 + 0.6 + i * 0.5, y0 + 0.5), rnd)
    G.box("N", K(0, "c0453a", "", 3), 0.3, 0.2, 0.35, M_((x0 + x1) / 2 + 0.6, (y0 + y1) / 2 + 0.6, FL + 1.05))
    chandelier(G, ctx, (x0 + x1) / 2, (y0 + y1) / 2, 0.5, 5, 0.9, 1.2)
    rug(G, M_((x0 + x1) / 2 - 0.5, y0 + 1.2), 2.4, 1.2, CLOTH_BLUE)
    for i in range(3):
        G.cyl("N", K(0, "e0c8a0", "", 3), 0.07, 0.06, 0.4, T((x0 + x1) / 2 - 0.5 + i * 0.4, y1 - 0.9, ctx["Hc"] - 0.6) @ Rx(0.0), 6)


def tailor(G, ctx, rnd, sp):
    (x0, x1, y0, y1, xb), wing = rooms(ctx)
    table(G, M_((x0 + x1) / 2, (y0 + y1) / 2 + 0.3), 2.4, 1.1, cloth=CLOTH_CREAM, items=False)
    cloth_bolts(G, M_((x0 + x1) / 2, (y0 + y1) / 2 + 0.3, FL + 0.9), rnd, 6)
    for i, sx in enumerate((-1, 1)):
        mannequin(G, M_(x0 + 1.0 + i * 1.3, y1 - 0.8), CLOTH_RED if i == 0 else CLOTH_BLUE)
    for i in range(2):
        shelf(G, M_(x1 - 0.3, y0 + 1.5 + i * 1.7, FL, -math.pi / 2), 1.5, 2.2, 0.4, rnd, "goods", 5)
    shelf(G, M_(x0 + 3.0, y1 - 0.25), 1.6, 2.2, 0.4, rnd, "goods", 5)
    chair(G, M_((x0 + x1) / 2 - 0.9, (y0 + y1) / 2 + 1.3, FL, math.pi))
    rug(G, M_((x0 + x1) / 2, y0 + 1.6), 2.6, 1.4, CLOTH_GREEN)
    chandelier(G, ctx, (x0 + x1) / 2, (y0 + y1) / 2, 0.55, 6, 0.9, 1.3)
    G.box("N", K(0, "a8c0d0", "", 3), 0.9, 0.05, 1.5, M_(x0 + 0.1, (y0 + y1) / 2 - 1.2, FL + 0.4, math.pi / 2))   # 试衣镜
    for i in range(4):
        G.box("N", K(0, GOODS[(i * 3) % 8], "", 3), 0.45, 0.04, 0.9, T(x0 + 2.0 + i * 0.5, y1 - 0.12, ctx["Hc"] - 1.3))


def guard(G, ctx, rnd, sp):
    (x0, x1, y0, y1, xb), wing = rooms(ctx)
    table(G, M_((x0 + x1) / 2, (y0 + y1) / 2 + 0.4), 2.0, 1.0, cloth=CLOTH_GREEN, rnd=rnd)
    G.box("N", K(0, "d9c892", "", 3), 1.0, 0.7, 0.02, M_((x0 + x1) / 2, (y0 + y1) / 2 + 0.4, FL + 0.82))
    chair(G, M_((x0 + x1) / 2, (y0 + y1) / 2 + 1.1, FL, math.pi))
    weapon_rack(G, M_(x0 + 0.8, y1 - 0.45), rnd)
    weapon_rack(G, M_(x1 - 0.8, y1 - 0.45), rnd)
    bench(G, M_(x0 + 0.6, (y0 + y1) / 2, FL, math.pi / 2), 2.0)
    barrel(G, M_(x1 - 0.5, y0 + 0.6))
    crate(G, M_(x1 - 0.5, y0 + 1.3), 0.55)
    for i in range(3):
        G.box("N", IRON, 0.04, 0.04, 1.9, T(x1 - 0.1, y0 + 2.2 + i * 0.3, FL))
    G.box("N", CLOTH_RED, 0.05, 0.9, 1.5, T(x0 + 0.04, y0 + 2.6, FL + 1.1))
    fireplace(G, ctx, M_((x0 + x1) / 2 - 1.0, y1 + 0.38, FL, 0.0), w=1.8)
    lantern_hang(G, ctx, (x0 + x1) / 2, (y0 + y1) / 2, 0.8, 1.2)


def trainer(G, ctx, rnd, sp):
    (x0, x1, y0, y1, xb), wing = rooms(ctx)
    for i in range(3):
        dummy(G, M_(x0 + 1.5 + i * 2.0, y1 - 1.5))
    weapon_rack(G, M_(x1 - 0.8, y0 + 0.5), rnd)
    weapon_rack(G, M_(x0 + 0.8, y0 + 0.5), rnd)
    for i in range(2):
        bench(G, M_(x1 - 0.5, (y0 + y1) / 2 - 0.8 + i * 1.8, FL, math.pi / 2), 1.6)
    table(G, M_((x0 + x1) / 2, y0 + 1.2), 2.0, 0.9, cloth=CLOTH_BLUE, rnd=rnd)
    shelf(G, M_(x0 + 0.3, (y0 + y1) / 2, FL, math.pi / 2), 1.6, 2.0, rnd=rnd)
    fireplace(G, ctx, M_(x1 - 1.5, y1 + 0.38, FL, 0.0), w=1.8)
    rug(G, M_((x0 + x1) / 2, (y0 + y1) / 2 + 0.6), 4.0, 2.6, K(0, "5a4a3a", "", 3))
    chandelier(G, ctx, (x0 + x1) / 2, (y0 + y1) / 2, 0.6, 6, 1.0, 1.3)
    barrel(G, M_(x0 + 0.5, y1 - 0.5))


def stable(G, ctx, rnd, sp):
    (x0, x1, y0, y1, xb), wing = rooms(ctx)
    for i in range(3):
        stall(G, M_(x0 + 1.6, y0 + 1.3 + i * 2.4 + 0.6, FL, 0.0), 3.0)
        G.box("N", K(0, "8a6a40", "", 3), 0.9, 0.5, 0.4, M_(x0 + 0.45, y0 + 0.5 + i * 2.4 + 0.6, FL + 0.55))
    for i in range(4):
        hay_bale(G, M_(x1 - 1.0, y1 - 0.5 - i * 0.55, FL + 0.0, math.pi / 2))
    hay_bale(G, M_(x1 - 1.0, y1 - 0.8, FL + 0.5, math.pi / 2))
    for i in range(2):
        G.box("N", WOODD, 0.06, 0.5, 0.6, T(x1 - 0.1, y0 + 1.5 + i * 1.2, FL + 1.3))
        G.ico("N", K(7, "6a4a2a", "pt_metal", 2.0), 0.28, T(x1 - 0.4, y0 + 1.5 + i * 1.2, FL + 1.5) @ S3(1.3, 0.8, 0.5), 1)
    barrel(G, M_(x1 - 0.5, y0 + 0.5))
    barrel(G, M_(x1 - 1.3, y0 + 0.5))
    lantern_hang(G, ctx, (x0 + x1) / 2, y0 + 3.0, 0.9, 1.0)
    lantern_hang(G, ctx, (x0 + x1) / 2, y1 - 2.0, 0.9, 1.0)


PRESETS = dict(home=home, tavern=tavern, smithy=smithy, store=store, tailor=tailor, guard=guard, trainer=trainer, stable=stable)


