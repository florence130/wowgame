# 铁匠铺总装：外部（敞棚锻炉 + 山墙外砖烟囱 + 牌匾）与室内（砖炉膛 + 铁砧 + 武器柜台 / 护甲柜台 + 展示架 + 武器墙 + 工具架 + 磨刀石）。
# 武器商人阿尔戈站在武器柜台后，护甲商人多恩站在护甲柜台后（站位写进 meta["npcs"]，gen_vale 按它放）。
# 坐标沿用房屋生成器：放大前的米（build.py 最后整体 ×1.6），构件按放大后的米建，盖章时乘 1/1.6。
import math
from mathutils import Vector, Matrix
from geo import T, Rz, S3
import stamp
from house import FL, TW, SCL, WT
import furn

SC = stamp.SC


def world(M, p):
    return M @ Vector(p)


def exterior(G, st, sp, info, parts, H, zr):
    """敞棚锻炉（左山墙，开口朝前）、砖烟囱（右山墙，炉口朝前）、门上牌匾。返回外扩范围 (xmin, xmax)。"""
    p0 = parts[0]["rect"]
    W = p0[1] - p0[0]
    e1, e3, e0 = info[1], info[3], info[0]
    k = 0.8                                           # 棚整体缩到 0.8：长 6.0m、深 4.6m
    Lsh, Dsh = 7.5, 5.75
    hi, lo = round((H - 0.4) / k, 2), round(3.2, 2)   # 靠墙一侧檐高到墙檐下 0.4m，外沿 2.56m（人 1.7m 能站进去）
    x0 = e3["L"] - Lsh * k - 0.4
    Ms = e3["Me"] @ T(x0, -TW / 2, 0) @ SCL @ S3(k, k, k)
    stamp.place(G, st, "forge_shed", Ms, None, Lsh=Lsh, Dsh=Dsh, hi=hi, lo=lo)
    fp = world(Ms, (Lsh * 0.5, -1.4, 1.5))
    G.lights.append((fp.x, fp.y, fp.z, 9.0, 1.8))
    # 砖烟囱：贴右山墙（边 1：局部 x 由前向后），炉口朝前（-x 局部），整体 0.75
    kc = 0.75
    top = round((zr + 1.2) / kc, 2)
    xc = 3.6
    Mc = e1["Me"] @ T(xc, -TW / 2, 0) @ SCL @ S3(kc, kc, kc)
    stamp.place(G, st, "forge_chimney", Mc, None, top=top)
    sm = world(Mc, (0.0, -0.8, top + 0.6))
    G.smoke.append((sm.x, sm.y, sm.z))
    cf = world(Mc, (-1.5, -1.25, 0.9))
    G.lights.append((cf.x, cf.y, cf.z, 6.0, 1.2))
    # 牌匾（英文）：门洞正上方
    if e0["door_x"] is not None:
        stamp.place(G, st, "plaque", e0["Me"] @ T(e0["door_x"], -TW / 2, 3.0) @ SCL, None, text="BLACKSMITH", w=2.7, h=0.5)
    return -W / 2 - (Dsh * k + 0.5), W / 2 + (2.7 * kc + 0.3)

def interior(G, ctx, rnd, sp):
    """室内：右墙大砖炉（对着山墙外的烟囱）、炉前铁砧、后墙武器墙 + 武器柜台（阿尔戈）、护甲柜台（多恩）+ 三具盔甲架、工具架、磨刀石、红地毯、吊灯。"""
    st = ctx["st"]
    Hc = ctx["Hc"]
    r = ctx["parts"][0]["rect"]
    x0, x1, y0, y1 = r
    xr = x1 - TW / 2                      # 右墙内面
    yb = y1 - TW / 2                      # 后墙内面
    xl = x0 + TW / 2
    yf = y0 + TW / 2
    yh = y0 + 3.2                         # 炉子位置（对着外面的烟囱）
    ceil_top = round((Hc - FL) * SC, 2)
    # --- 炉 + 铁砧 + 工具
    stamp.place(G, st, "hearth", T(xr, yh, FL) @ Rz(-math.pi / 2) @ SCL, None, top=ceil_top)
    G.lights.append((xr - 1.1, yh, FL + 1.1, 9.5, 1.9))
    stamp.place(G, st, "anvil", T(xr - 3.4, yh - 0.1, FL) @ Rz(math.pi / 2) @ SCL, None)
    stamp.place(G, st, "tool_rack", T(xr, yh + 2.1, FL + 1.0) @ Rz(-math.pi / 2) @ SCL, None)
    stamp.place(G, st, "tool_rack", T(xr, yh - 2.0, FL + 1.0) @ Rz(-math.pi / 2) @ SCL, None, w=1.2)
    stamp.place(G, st, "grindstone", T(xr - 0.8, y0 + 1.1, FL) @ SCL, None)
    # 洛奇M Tool_ForgeStick_00（拨火钩，1.1m）斜靠在炉边
    furn.mabi(G, T(xr - 1.15, yh + 1.4, FL + 0.53) @ Rz(1.2) @ Matrix.Rotation(-1.25, 4, "Y"), "Tool_ForgeStick_00", "Tool_ForgeStick_00", 1.0, "N",
              dict(s=(1.0, 2.2, 2.2), jitter=0.004, bend=0.2, hue=15, sat=0.9, val=0.95, tag="stick"))
    furn.barrel(G, furn.M_(xr - 0.55, yh - 2.35))
    furn.barrel(G, furn.M_(xr - 1.35, yh - 2.45))
    # --- 后墙：武器墙（左半）+ 盔甲架（右半）
    wx, ax = x0 + 2.6, 2.3                # 武器柜台 / 护甲柜台中心 x
    stamp.place(G, st, "weapon_wall", T(wx, yb, FL + 0.5) @ SCL, None)
    for xx, kind in ((0.35, "armor_plate"), (3.95, "armor_mail"), (4.75, "armor_leather")):
        stamp.place(G, st, kind, T(xx, yb - 0.4, FL) @ Rz(0.0) @ SCL, None, force="N" if kind != "armor_plate" else None)
    cy = yb - 1.85
    stamp.place(G, st, "counter", T(wx, cy, FL) @ SCL, None, variant="weapons", ln=3.4)
    stamp.place(G, st, "counter", T(ax, cy, FL) @ SCL, None, variant="armor", ln=3.4)
    # 左墙：长凳 + 煤袋、木箱
    # 左墙：第二面武器墙（朝室内）+ 两具板甲架 + 煤袋、木箱
    stamp.place(G, st, "weapon_wall", T(xl, 0.4, FL + 0.5) @ Rz(math.pi / 2) @ SCL, None)
    for yy in (y0 + 2.1, y0 + 3.0):
        stamp.place(G, st, "armor_plate", T(xl + 0.4, yy, FL) @ Rz(math.pi / 2) @ SCL, None)
    for i in range(2):
        furn.crate(G, furn.M_(xl + 0.5, y1 - 1.0 - i * 0.7), 0.55)
    furn.sack(G, furn.M_(xl + 1.2, y1 - 0.7), rnd)
    furn.rug(G, furn.M_(0.4, y0 + 2.6), 2.4, 4.0, furn.CLOTH_RED)
    furn.chandelier(G, ctx, 0.2, 0.4, 0.7, 6, 1.0, 1.5)
    furn.lantern_hang(G, ctx, wx, cy - 0.2, 0.9, 1.0)
    furn.lantern_hang(G, ctx, ax, cy - 0.2, 0.9, 1.0)
    # --- 商人站位（面朝门，站在柜台后）
    ny = yb - 0.95
    G.marks["npcs"] = {"argo": (wx, ny), "dorn": (ax, ny)}
