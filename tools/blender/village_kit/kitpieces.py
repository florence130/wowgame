# Tripo3D 构件总图用：把「建筑构件」与「家具」逐件单独建出来（与装配用的是同一批函数），再由 sheets.py 渲成统一视角的单件图。
import math, random
from mathutils import Vector
from geo import Geo, T, Rz, Rx, Ry, S3, I, M_XZ, M_YZ
import house as hs
from house import TW, FL, K, mats, WOODL, WOODD, IRON, RUBBLE, STONEM, LEAF, FLOWERS, PANE, FIRE
import furn

HP = 0.14


def _ctx(Hc=3.0):
    return dict(Hc=Hc, st=mats({"style": "mm"}), parts=[], info=[], rnd=random.Random(3))


def wall_unit(G, st, rnd, bw=3.0, H=3.4, win=True, braces=False, shut=True, fbox=True, base=True):
    Me = I
    hole = ("rect", bw / 2, FL + 0.95, 1.12, 1.4) if win else None
    hs.wall_bay(G, st["PLASTER"], Me, 0, bw, 0, H, hole)
    if win:
        hs.window(G, st, Me, bw / 2, FL + 0.95, 1.12, 1.4, shutters=shut, flowerbox=fbox, rnd=rnd)
    tm, yo = st["TIMBER"], -TW / 2
    for x in (0, bw):
        G.box("S", tm, 0.16, 0.14, H + 0.1, T(x, yo - 0.04, 0))
    G.box("S", tm, bw, 0.17, 0.26, T(bw / 2, yo - 0.05, H - 0.26))
    G.box("S", tm, bw, 0.15, 0.14, T(bw / 2, yo - 0.04, FL + 0.9))
    if braces:
        G.beam("N", tm, Vector((0.15, yo - 0.07, FL + 1.0)), Vector((bw * 0.5, yo - 0.07, H - 0.35)), 0.1, 0.08)
        G.beam("N", tm, Vector((bw - 0.15, yo - 0.07, FL + 1.0)), Vector((bw * 0.5, yo - 0.07, H - 0.35)), 0.1, 0.08)
    if base:
        G.box("S", st["STONE"], bw, 0.2, 1.55, T(bw / 2, yo - 0.1, -0.5))


def gable_roof_piece(G, st, rnd, sp, g0=False, g1=False, length=4.0):
    part = dict(rect=(-length / 2, length / 2, -2.8, 2.8), axis="x", g0=g0, g1=g1)
    hs.gable_roof(G, st, part, 0.0, rnd, sp)


def build_component(i, rnd):
    """返回 Geo。i = 1..20，顺序与 gen_village_sheets.py / TRIPO_构件清单.md 一致。"""
    mm, wow = mats({"style": "mm"}), mats({"style": "wow"})
    G = Geo()
    if i == 1:
        gable_roof_piece(G, mm, rnd, {})
    elif i == 2:
        gable_roof_piece(G, wow, rnd, {})
    elif i == 3:
        # 山墙：短屋脊 + 山墙三角（含木筋、圆窗、封檐板）
        part = dict(rect=(-0.3, 0.3, -2.8, 2.8), axis="x", g0=True, g1=False)
        hs.gable_roof(G, mm, part, 0.0, rnd, {})
        G.box("S", mm["PLASTER"], 0.6, 5.6, 0.5, T(0, 0, -0.5))
    elif i == 4:
        G.box("S", mm["ROOF"], 3.4, 3.2, 0.25, T(0, 0.5, -0.12))
        hs.dormer(G, mm, T(0, 0, 0.05))
    elif i == 5:
        hs.chimney(G, mm, 0, 0, 0, 3.4)
    elif i == 6:
        wall_unit(G, mm, rnd, 3.0, 3.4, True, False, True, True)
    elif i == 7:
        wall_unit(G, mm, rnd, 3.0, 3.4, False, True, False, False)
    elif i == 8:
        G.box("S", mm["STONE"], 3.0, 0.5, 1.05, T(0, 0, 0))
        G.box("S", K(9, "cfc6b2", "pt_limestone", 4.8), 3.1, 0.58, 0.1, T(0, 0, 1.05))
        for k in range(4):
            G.box("S", mm["STONE"], 0.5, 0.5, 0.3, T(2.1, 0.5 if False else 0, 1.05 + 0.05)) if False else None
        for k in range(5):
            G.box("S", mm["STONE"], 0.62 if k % 2 == 0 else 0.46, 0.62 if k % 2 == 0 else 0.46, 0.42, T(2.0 + (0.08 if k % 2 else 0), 0, k * 0.42))
    elif i == 9:
        wall_unit(G, wow, rnd, 3.0, 3.4, True, False, False, True)
    elif i == 10:
        hs.wall_bay(G, mm["PLASTER"], I, 0, 3.0, 0, 3.4, ("arch", 1.5, FL, 1.5, 2.4))
        hs.door_unit(G, mm, I.copy(), 1.5, 1.5, 2.4) if False else None
        import house
        house.door_unit(G, mm, I, 1.5, 1.5, 2.4)
        G.box("S", mm["TIMBER"], 0.16, 0.14, 3.5, T(0, -TW / 2 - 0.04, 0))
        G.box("S", mm["TIMBER"], 0.16, 0.14, 3.5, T(3.0, -TW / 2 - 0.04, 0))
        G.box("S", mm["TIMBER"], 3.0, 0.17, 0.26, T(1.5, -TW / 2 - 0.05, 3.14))
        hs.doorstep(G, mm, I, 1.5)
    elif i == 11:
        G.box("S", mm["PLASTER"], 3.4, TW, 3.4, T(0, 0, 0))
        hs.porch(G, mm, I, 0.0, rnd)
    elif i == 12:
        tm = mm["TIMBER"]
        G.box("S", mm["PLASTER"], 2.4, 1.0, 2.0, T(0, -0.5, 0.7))
        G.box("N", PANE, 0.5, 0.05, 0.7, T(-0.55, -1.03, 1.3)); G.box("N", PANE, 0.5, 0.05, 0.7, T(0.55, -1.03, 1.3)); G.box("N", PANE, 0.5, 0.05, 0.7, T(0, -1.03, 1.3))
        G.box("S", tm, 2.5, 1.1, 0.14, T(0, -0.5, 0.62))
        G.box("S", tm, 2.5, 1.1, 0.14, T(0, -0.5, 2.7))
        for sx in (-1, 1):
            G.box("S", tm, 0.12, 0.12, 2.1, T(sx * 1.2, -1.03, 0.65))
            G.beam("S", IRON, Vector((sx * 0.85, -1.15, 0.7)), Vector((sx * 1.15, -1.15, 1.9)), 0.06, 0.04)
        for k in range(3):
            G.box("N", tm, 0.2 + 0.15 * k, 0.2 + 0.15 * k, 0.2, T(sx * 0 + 0.0 if False else (k - 1) * 0.8, -1.2, 0.15 + 0.0)) if False else None
        G.box("S", mm["ROOF"], 3.0, 1.5, 0.15, T(0, -0.95, 2.78) @ Rx(-0.5))
        G.box("S", mm["STONE"], 2.6, 0.7, 0.5, T(0, 0.1, 0))
    elif i == 13:
        tm = mm["TIMBER"]
        G.box("S", tm, 0.3, 0.3, 3.6, T(0, 0, 0))
        for k in range(5):
            G.box("S", mm["STONE"], 0.55 if k % 2 == 0 else 0.42, 0.55 if k % 2 == 0 else 0.42, 0.4, T(0, 0, k * 0.4) if False else T(0.12 if k % 2 else 0, 0.12 if k % 2 else 0, k * 0.4))
        G.box("S", mm["PLASTER"], 1.5, TW, 3.4, T(0.9, 0.2, 0.0))
        G.box("S", mm["PLASTER"], TW, 1.5, 3.4, T(-0.1, 0.9, 0.0))
    elif i == 14:
        tm = mm["TIMBER"]
        G.box("S", tm, 3.2, 0.2, 3.0, T(0, 0, 0.12))
        for sx in (-1, 1):
            G.box("S", WOODL, 1.5, 0.12, 2.7, T(sx * 0.76, -0.12, 0.2))
            for k in range(4):
                G.box("N", tm, 0.04, 0.03, 2.7, T(sx * (0.15 + k * 0.38), -0.2, 0.2))
        G.box("S", tm, 3.4, 0.24, 0.3, T(0, -0.1, 3.1))
        for k in range(3):
            G.beam("N", IRON, Vector((-1.4, -0.22, 0.5 + k * 0.9)), Vector((-0.2, -0.22, 0.5 + k * 0.9)), 0.1, 0.03)
        G.box("S", tm, 0.3, 0.3, 3.5, T(-1.7, 0, 0)); G.box("S", tm, 0.3, 0.3, 3.5, T(1.7, 0, 0))
    elif i == 15:
        st = mm["STONE"]
        G.box("S", st, 3.2, 3.2, 4.2, T(0, 0, 0))
        for sx in (-1, 1):
            for sy in (-1, 1):
                G.box("S", st, 0.7, 0.7, 0.5, T(sx * 1.45, sy * 1.45, 4.2))
        G.box("S", st, 2.4, 2.4, 0.35, T(0, 0, 4.2))
        G.box("N", K(0, "1e1a18", "", 3), 0.22, 0.08, 1.0, T(0, -1.62, 2.0))
        G.box("S", WOODL, 3.6, 0.9, 0.12, T(0, -2.0, 3.0))
        G.beam("S", mm["TIMBER"], Vector((-1.7, -1.9, 2.4)), Vector((-1.7, -1.62, 3.0)), 0.1, 0.1)
        G.beam("S", mm["TIMBER"], Vector((1.7, -1.9, 2.4)), Vector((1.7, -1.62, 3.0)), 0.1, 0.1)
        G.box("N", IRON, 0.06, 0.06, 0.6, T(0, -1.9, 3.12)); G.ico("N", FIRE, 0.12, T(0, -1.9, 3.8), 0)
    elif i == 16:
        G.cyl("S", wow["ROOF"], 3.3, 0.01, 3.2, T(0, 0, 0) @ Rz(math.pi / 4), 4)
        G.box("S", IRON, 0.05, 0.05, 1.3, T(0, 0, 3.1)); G.box("N", IRON, 0.5, 0.02, 0.3, T(0.22, 0, 4.2))
    elif i == 17:
        for k in range(8):
            a = rnd.uniform(0, 2 * math.pi)
            G.ico("N", rnd.choice(LEAF), rnd.uniform(0.18, 0.28), T(-1.6 + rnd.uniform(-0.1, 0.1), 0.0, 0.5 + k * 0.28) @ S3(0.5, 1.2, 0.8), 1, 0.25, k)
        for k in range(4):
            G.ico("N", FLOWERS[0], 0.07, T(-1.7 + rnd.uniform(-0.1, 0.1), -0.3, rnd.uniform(0.6, 2.0)), 0)
        hs.bush(G, rnd, 0.2, 0.0, 0.75)
        G.box("S", WOODL, 1.4, 0.5, 0.25, T(1.9, 0, 0))
        for k in range(8):
            hs.bush(G, rnd, 0, 0, 0.0001, False) if False else None
            G.ico("N", rnd.choice(LEAF), 0.15, T(1.5 + k * 0.16, rnd.uniform(-0.1, 0.1), 0.3), 1)
            G.ico("N", rnd.choice(FLOWERS), 0.07, T(1.5 + k * 0.16, rnd.uniform(-0.1, 0.1), 0.45), 0)
    elif i == 18:
        for k in range(7):
            G.box("S", WOODL, 0.12, 0.08, 1.05, T(-1.5 + k * 0.5, 0, 0))
            G.beam("N", WOODL, Vector((-1.5 + k * 0.5, 0, 1.05)), Vector((-1.5 + k * 0.5 + 0.06, 0, 1.15)), 0.12, 0.08)
        for z in (0.35, 0.75):
            G.box("S", WOODD, 3.1, 0.08, 0.1, T(0, 0.08, z))
        G.box("S", WOODD, 0.2, 0.2, 1.3, T(-1.65, 0, 0)); G.box("S", WOODD, 0.2, 0.2, 1.3, T(1.65, 0, 0))
        G.box("S", WOODL, 1.3, 0.08, 0.9, T(2.7, 0, 0.15))
        G.box("S", WOODD, 0.2, 0.2, 1.3, T(3.4, 0, 0))
    elif i == 19:
        for k in range(14):
            a = 2 * math.pi * k / 14
            G.box("S", RUBBLE, 0.5, 0.42, 0.4 + 0.1 * (k % 2), T(math.cos(a) * 0.95, math.sin(a) * 0.95, 0) @ Rz(a))
            G.box("S", RUBBLE, 0.5, 0.42, 0.3, T(math.cos(a + 0.2) * 0.95, math.sin(a + 0.2) * 0.95, 0.45) @ Rz(a + 0.2))
        for sx in (-1, 1):
            G.box("S", WOODD, 0.14, 0.14, 2.0, T(sx * 1.0, 0, 0.7))
        G.cyl("S", WOODL, 0.07, 0.07, 2.2, T(0, 0, 1.8) @ Ry(math.pi / 2) @ T(0, 0, -1.1), 8)
        for s in (-1, 1):
            G.box("S", mm["ROOF"], 1.7, 2.6, 0.12, T(s * 0.75, 0, 2.55) @ Ry(s * 0.55))
        G.cyl("N", WOODL, 0.17, 0.15, 0.25, T(0.3, 0, 1.35), 8)
    elif i == 20:
        for sx in (-1.3, 1.3):
            G.box("S", WOODD, 0.12, 0.12, 2.3, T(sx, 0.0, 0.0)); G.box("S", WOODD, 0.12, 0.12, 2.3, T(sx, 1.4 * 0 + 0.0, 0.0)) if False else None
        G.box("S", WOODD, 0.12, 2.0, 0.12, T(-1.3, -1.0, 2.2)); G.box("S", WOODD, 0.12, 2.0, 0.12, T(1.3, -1.0, 2.2))
        G.box("S", mm["ROOF"], 3.2, 1.4, 0.14, T(0, -1.0, 2.4) @ Rx(0.45)); G.box("S", mm["ROOF"], 3.2, 1.4, 0.14, T(0, -1.0, 2.4) @ Rx(-0.45))
        G.box("S", WOODL, 2.6, 0.9, 0.9, T(0, -0.4, 0)); G.box("S", WOODD, 2.8, 1.1, 0.08, T(0, -0.4, 0.9))
        for k in range(5):
            G.box("N", K(0, ["c0453a", "e0b04a", "4f8f7d", "5b73b0", "d97c9a"][k], "", 3), 0.3, 0.3, 0.3, T(-1.0 + k * 0.5, -0.4, 1.0))
        for k in range(8):
            c = "c0453a" if k % 2 == 0 else "efe4c8"
            G.box("N", K(0, c, "", 3), 0.42, 1.5, 0.05, T(-1.47 + k * 0.42, -1.0, 2.45 - 0.0) @ Rx(0.0)) if False else None
        G.box("S", WOODL, 0.3, 1.2, 0.2, T(1.3, -0.4, 0.1))
    elif i == 21:
        # 窗户单元：石窗框 + 十字窗棂 + 双开窗板 + 花箱（嵌进墙洞用，不含墙）
        hs.window(G, mm, I, 0.0, 0.0, 1.12, 1.4, shutters=True, flowerbox=True, rnd=rnd)
    elif i == 22:
        # 店招挂牌：铁艺挑臂 + 两根链条 + 木牌 + 盾徽
        G.box("S", IRON, 0.12, 0.12, 0.5, T(0, 0, 1.8))
        G.box("S", IRON, 1.5, 0.08, 0.08, T(-0.75, 0, 2.2))
        G.beam("N", IRON, Vector((0, 0, 1.85)), Vector((-0.9, 0, 2.2)), 0.05, 0.05)
        for x in (-0.35, -1.15):
            G.box("N", IRON, 0.03, 0.03, 0.35, T(x, 0, 1.85))
        G.box("N", WOODL, 1.1, 0.08, 0.75, T(-0.75, 0, 1.1))
        G.box("N", WOODD, 1.2, 0.1, 0.08, T(-0.75, 0, 1.82))
        G.box("N", K(7, "c79a3c", "pt_metal", 2.0), 0.42, 0.1, 0.5, T(-0.75, -0.02, 1.22))
        G.box("N", K(0, "a8362e"), 0.3, 0.11, 0.36, T(-0.75, -0.03, 1.29))
    return G


def build_furniture(i, rnd):
    """家具 1..24；顺序与 gen_village_sheets.py 一致。"""
    G = Geo()
    ctx = _ctx(1.9)
    M = I
    if i == 1:
        furn.table(G, M, 2.2, 0.95, cloth=furn.CLOTH_RED, rnd=rnd)
    elif i == 2:
        furn.bench(G, M, 2.0)
    elif i == 3:
        furn.stool(G, M)
    elif i == 4:
        furn.chair(G, M)
    elif i == 5:
        furn.barrel(G, M)
    elif i == 6:
        furn.crate(G, M, 0.7)
    elif i == 7:
        furn.sack(G, T(0, 0, 0), rnd, 0.34); furn.sack(G, T(0.55, 0.15, 0), rnd, 0.24)
    elif i == 8:
        ctx["Hc"] = 3.3
        furn.fireplace(G, ctx, T(0, 0.5, 0), 2.2)
    elif i == 9:
        ctx["Hc"] = 1.5
        furn.chandelier(G, ctx, 0, 0, 0.7, 8, 1.1)
    elif i == 10:
        # 壁灯：铁托臂 + 提灯（贴在一段墙板上）
        G.box("N", mats({"style": "mm"})["PLASTER"], 1.2, 0.2, 1.4, T(0, 0.1, 0))
        G.box("N", IRON, 0.08, 0.5, 0.08, T(0, -0.2, 1.0)); G.beam("N", IRON, Vector((0, 0.0, 0.6)), Vector((0, -0.45, 1.0)), 0.06, 0.06)
        G.box("N", IRON, 0.26, 0.26, 0.34, T(0, -0.55, 0.62)); G.box("N", IRON, 0.34, 0.34, 0.06, T(0, -0.55, 0.96))
        G.ico("N", FIRE, 0.1, T(0, -0.55, 0.78), 0)
    elif i == 11:
        furn.shelf(G, M, 1.4, 2.1, 0.38, rnd, "books", 4)
    elif i == 12:
        furn.shelf(G, M, 1.5, 2.2, 0.38, rnd, "bottles", 5)
    elif i == 13:
        furn.bed(G, M)
    elif i == 14:
        furn.counter(G, M, 3.2, 0.8)
    elif i == 15:
        furn.cupboard(G, M)
    elif i == 16:
        furn.rug(G, M, 2.6, 1.6)
        G.box("N", K(0, "6a2f3a", "", 3), 0.9, 0.5, 0.04, T(0, 0, 0.0))
    elif i == 17:
        furn.anvil(G, M)
    elif i == 18:
        ctx["Hc"] = 3.0
        furn.forge(G, ctx, T(0, 0, 0), 2.4)
    elif i == 19:
        furn.weapon_rack(G, M, rnd)
    elif i == 20:
        furn.dummy(G, M)
    elif i == 21:
        furn.mannequin(G, T(-0.5, 0, 0))
        furn.cloth_bolts(G, T(0.7, 0, 0), rnd, 5)
        for k in range(4):
            G.cyl("N", K(0, rnd.choice(furn.GOODS), "", 3), 0.1, 0.1, 0.55, T(0.5 + k * 0.0, 0, 0.0) @ T(0.5, 0, 0.1 + k * 0.2) @ Ry(math.pi / 2), 8) if False else None
    elif i == 22:
        furn.stall(G, M, 3.0)
    elif i == 23:
        furn.pots_hang(G, T(0, 0, 1.6))
        G.box("N", WOODD, 0.1, 0.1, 1.9, T(-0.7, 0, 0)); G.box("N", WOODD, 0.1, 0.1, 1.9, T(0.7, 0, 0)); G.box("N", WOODD, 1.5, 0.1, 0.1, T(0, 0, 1.9))
    elif i == 24:
        furn.painting(G, T(-0.7, 0, 1.0), 0.7, 0.9, rnd)
        G.box("N", furn.CLOTH_RED, 0.5, 0.06, 0.65, T(0.2, 0, 1.1)); G.box("N", K(7, "c79a3c", "pt_metal", 2.0), 0.58, 0.05, 0.72, T(0.2, 0.02, 1.07))
        furn.flower_pot(G, T(1.0, 0, 0), rnd)
    return G
