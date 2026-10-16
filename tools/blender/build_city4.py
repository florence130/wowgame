# Batch 8 (2026-10-05): 晴岚港 v4 新增设施建筑（docs/world_v4/city_plan.json）
#   crystal_palace_0  博览集市馆（"水晶宫"）：铁骨玻璃长廊 —— 低矮两侧廊 + 高中殿筒形玻璃拱 + 更高的十字翼 + 正面扇形巨窗与入口雨棚
#   mansion_0/1       公馆 / 官邸：三层对称洋馆，中央凸出门厅 + 四柱门廊 + 山花 + 曼萨德屋顶 + 老虎窗 + 烟囱（参考图五 / 图六的城市建筑）
# 材质：A 墙 / 铁骨（游戏按 color_a 换色）、B 屋顶、C 饰边；glass 用游戏的窗户材质（夜里发光）。正面 = Blender +Y（游戏里朝 -Z）。
# blender -b -P tools/blender/build_city4.py -- E:/wowgame/assets/models [names]
import bpy, bmesh, os, sys, math, random
from mathutils import Vector
_LIB_ONLY = True
_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else "E:/wowgame/tools/blender"
exec(open(os.path.join(_HERE, "build_models.py"), encoding="utf-8").read())
_src = open(os.path.join(_HERE, "build_city2.py"), encoding="utf-8").read()
exec(_src.split("CITY2_BUILDERS = {")[0])   # build_city2 的工具函数（含 build_models 与 mat/COLORS 扩展）


def _arc_mesh(a0, a1, cross, z, r, axis, seg, thick, m):
    """半圆筒面：沿 axis 从 a0 到 a1，截面圆心 (cross, z)，半径 r。"""
    verts, faces = [], []
    for end in (a0, a1):
        for i in range(seg + 1):
            t = math.pi * i / seg
            u, h = math.cos(t) * r, z + math.sin(t) * r
            verts.append((end, cross + u, h) if axis == "x" else (cross + u, end, h))
    n = seg + 1
    for i in range(seg):
        faces.append((i, i + 1, n + i + 1, n + i))
    o = mesh_obj(verts, faces, m)
    o.modifiers.new("s", "SOLIDIFY").thickness = thick
    return o


def barrel_vault(a0, a1, cross, z, r, m, rib_m, rib_every=6.0, axis="x", seg=16):
    """筒形玻璃拱 + 每隔 rib_every 米一道铁骨拱肋。"""
    _arc_mesh(a0, a1, cross, z, r, axis, seg, 0.08, m)
    L = abs(a1 - a0)
    n = max(2, int(L / rib_every))
    lo = min(a0, a1)
    for k in range(n + 1):
        t = lo + L * k / n
        _arc_mesh(t - 0.15, t + 0.15, cross, z, r + 0.12, axis, seg, 0.25, rib_m)

def glass_wall(x0, x1, y, z, h, facing, mull="A", step=3.0, rows=(0.33, 0.66)):
    """Glass curtain wall along X at y, with mullion grid."""
    L = x1 - x0
    s = 1 if facing == "+y" else -1
    box(L, 0.12, h, (x0 + x1) / 2, y, z, "glass", 0.0)
    n = int(L / step)
    for k in range(n + 1):
        box(0.22, 0.3, h, x0 + L * k / n, y + s * 0.08, z, mull, 0.0)
    for f in rows:
        box(L, 0.3, 0.2, (x0 + x1) / 2, y + s * 0.08, z + h * f, mull, 0.0)
    box(L + 0.3, 0.45, 0.35, (x0 + x1) / 2, y + s * 0.1, z + h - 0.35, mull, 0.0)


def glass_wall_y(y0, y1, x, z, h, facing, mull="A", step=3.0):
    L = y1 - y0
    s = 1 if facing == "+x" else -1
    box(0.12, L, h, x, (y0 + y1) / 2, z, "glass", 0.0)
    n = int(L / step)
    for k in range(n + 1):
        box(0.3, 0.22, h, x + s * 0.08, y0 + L * k / n, z, mull, 0.0)
    for f in (0.33, 0.66):
        box(0.3, L, 0.2, x + s * 0.08, (y0 + y1) / 2, z + h * f, mull, 0.0)


def fan_window(x, y, z, r, facing_s=1, mull="A", spokes=10):
    """Semicircular glass fan (end of a barrel vault) with radial mullions."""
    cyl(r, 0.12, x, y, z, "glass", 32, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (x, y, z)
    for i in range(spokes + 1):
        a = math.pi * i / spokes
        box(r, 0.25, 0.18, x + math.cos(a) * r * 0.5, y + facing_s * 0.1, z + math.sin(a) * r * 0.5 - 0.09, mull, 0.0, rot=(0, -a, 0))
        PARTS[-1].location = (x + math.cos(a) * r * 0.5, y + facing_s * 0.1, z + math.sin(a) * r * 0.5)
    for rr in (r * 0.35, r * 0.7, r):
        torus(rr, 0.12, x, y + facing_s * 0.1, z, mull, rot=(math.pi / 2, 0, 0), seg=32, mseg=4)
    # 下半圆遮住：一条横梁
    box(r * 2 + 0.6, 0.5, 0.6, x, y + facing_s * 0.1, z - 0.6, mull, 0.0)


def b_crystal_palace():
    W, D, H = 124.0, 46.0, 26.0
    hw, hd = W / 2, D / 2
    random.seed(81)
    # 台基 + 台阶
    box(W + 2, D + 2, 1.0, 0, 0, -0.4, "stone", 0.05)
    box(30, 4, 0.5, 0, hd + 2.5, -0.4, "stone", 0.03)
    box(26, 2.5, 0.3, 0, hd + 3.6, -0.4, "stone", 0.02)
    # 两侧低廊（y ±8..±23，高 10）：外墙玻璃幕墙 + 坡顶玻璃
    for s in (-1, 1):
        y_out = s * hd
        glass_wall(-hw, -12, y_out, 0.6, 9.4, "+y" if s > 0 else "-y")
        glass_wall(12, hw, y_out, 0.6, 9.4, "+y" if s > 0 else "-y")
        # 坡屋顶（玻璃）+ 铁骨
        v = [(-hw, s * hd, 10.0), (hw, s * hd, 10.0), (hw, s * 8.0, 12.5), (-hw, s * 8.0, 12.5)]
        mesh_obj(v, [(0, 1, 2, 3)], "glass")
        for k in range(0, 21):
            x = -hw + W * k / 20
            box(0.25, hd - 8.0, 0.25, x, s * (8.0 + (hd - 8.0) / 2), 11.1, "A", 0.0, rot=(s * math.atan2(2.5, hd - 8.0), 0, 0))
    for sx in (-1, 1):
        glass_wall_y(-hd, hd, sx * hw, 0.6, 9.4, "+x" if sx > 0 else "-x")
    # 中殿：高侧窗（y ±8，高 10–15）+ 筒形玻璃拱（半径 8，起拱 15）
    for s in (-1, 1):
        glass_wall(-hw, hw, s * 8.0, 10.0, 5.0, "+y" if s > 0 else "-y", step=4.0, rows=(0.5,))
    barrel_vault(-hw, hw, 0, 15.0, 8.0, "glass", "A", 6.2, "x")
    for sx in (-1, 1):
        arc = [(sx * hw, math.cos(math.pi * i / 16) * 8.0, 15.0 + math.sin(math.pi * i / 16) * 8.0) for i in range(17)]
        mesh_obj([(sx * hw, 0, 15.0)] + arc, [(0, i + 1, i + 2) for i in range(16)], "glass")
        for i in range(1, 8):
            a = math.pi * i / 8
            box(0.3, 8.0, 0.2, sx * (hw + 0.1), math.cos(a) * 4.0, 15.0 + math.sin(a) * 4.0 - 0.1, "A", 0.0, rot=(a - math.pi / 2, 0, 0))
            PARTS[-1].location = (sx * (hw + 0.1), math.cos(a) * 4.0, 15.0 + math.sin(a) * 4.0)
    # 十字翼（x ±10，沿 Y 贯穿，起拱 16，半径 10）——比中殿更高
    for sx in (-1, 1):
        box(0.5, D, 16.0, sx * 10.0, 0, 0.6, "A", 0.0)
    barrel_vault(-hd - 1.0, hd + 1.0, 0, 16.0, 10.0, "glass", "A", 4.0, "y")
    for sy in (-1, 1):
        fan_window(0, sy * (hd + 1.0), 16.0, 10.0, sy)
        glass_wall(-10, 10, sy * (hd + 1.0), 0.6, 15.4, "+y" if sy > 0 else "-y", step=2.5)
    # 正面入口：石框拱门 + 雨棚 + 两侧灯柱
    for sx in (-1, 1):
        box(1.2, 1.2, 16.0, sx * 10.6, hd + 1.1, 0.6, "C", 0.04)
        cyl(0.7, 1.4, sx * 10.6, hd + 1.1, 16.6, "C", 12, r2=0.2)
    box(12, 5, 0.4, 0, hd + 3.6, 5.2, "A", 0.03)
    for sx in (-1, 1):
        cyl(0.18, 4.6, sx * 5.6, hd + 5.8, 0.6, "iron", 8)
    for k in range(3):
        door((k - 1) * 3.4, hd + 1.15, 0.6, 2.2, 3.6, "+y", "glass")
    # 屋脊旗杆与尖饰
    for (x, y, z) in [(0, 0, 26.0), (-hw, 0, 23.0), (hw, 0, 23.0)]:
        cyl(0.12, 4.0, x, y, z, "gold", 6)
        box(2.0, 0.05, 1.2, x + 1.0, y, z + 2.6, "awning_r", 0.0)
    for x in (-hw + 6, -hw + 30, hw - 30, hw - 6):
        for s in (-1, 1):
            cyl(0.25, 1.6, x, s * hd, 10.0, "A", 8, r2=0.05)
    export("crystal_palace_0", [W, H, D])


def b_mansion(v):
    W, D, H = 26.0, 20.0, 12.5
    random.seed(90 + v)
    hw, hd = W / 2, D / 2
    fy = hd
    box(W + 0.6, D + 0.6, 1.4, 0, 0, -0.6, "stone", 0.05)
    # 主体与两翼（两翼略低、略后退）
    box(14.0, D, H, 0, 0, 0.8, "A", 0.03)
    for sx in (-1, 1):
        box((W - 14.0) / 2, D - 2.0, H - 2.4, sx * (7.0 + (W - 14.0) / 4), -1.0, 0.8, "A", 0.03)
    # 中央凸出门厅 + 山花
    box(7.0, 1.6, H + 0.6, 0, fy + 0.6, 0.8, "A", 0.03)
    tri = [(-4.2, fy + 1.5, H + 1.4), (4.2, fy + 1.5, H + 1.4), (0, fy + 1.5, H + 3.8)]
    o = mesh_obj(tri, [(0, 1, 2)], "C")
    o.modifiers.new("s", "SOLIDIFY").thickness = 0.9
    box(8.6, 2.2, 0.5, 0, fy + 0.6, H + 0.9, "C", 0.03)
    # 四柱门廊 + 阳台
    for k in range(4):
        x = -3.3 + k * 2.2
        cyl(0.35, 4.6, x, fy + 3.2, 0.8, "white", 14)
        box(0.9, 0.9, 0.35, x, fy + 3.2, 5.3, "C", 0.02)
    box(8.4, 3.4, 0.45, 0, fy + 2.6, 5.6, "C", 0.03)
    for k in range(9):
        cyl(0.1, 0.9, -3.8 + k * 0.95, fy + 4.15, 6.05, "white", 6)
    box(8.4, 0.18, 0.15, 0, fy + 4.15, 6.95, "C", 0.0)
    for k in range(4):
        box(6.0 - k * 0.6, 1.0, 0.25, 0, fy + 5.4 + k * 0.5, 0.8 - (k + 1) * 0.25, "stone", 0.02)
    door(0, fy + 1.45, 0.8, 1.8, 3.2)
    # 窗：三层，主体 3 开间 + 两翼各 2 开间
    for fi, z in enumerate([1.6, 5.4, 9.0]):
        for x in (-5.4, 5.4):
            window(x, fy, z, 1.3, 2.3 if fi < 2 else 1.8, "+y", frame="C", arched=(fi == 1))
        if fi > 0:
            window(0, fy + 1.4, z + 0.2, 1.4, 2.2, "+y", frame="C", arched=(fi == 2))
        for sx in (-1, 1):
            for j in range(2):
                x = sx * (8.6 + j * 2.6)
                if z + 2.3 < H - 2.4:
                    window(x, fy - 2.0, z, 1.1, 2.1, "+y", frame="C")
        for j in range(3):
            window((j - 1) * 3.6, -hd, z, 1.1, 2.0, "-y")
        box(14.3, D + 0.3, 0.22, 0, 0, z - 0.4, "C", 0.02)
    # 檐口 + 曼萨德屋顶 + 老虎窗
    box(14.6, D + 0.6, 0.4, 0, 0, H + 0.4, "C", 0.04)
    frustum(14.4, D + 0.4, 11.0, D - 3.4, H + 0.8, 3.4, "B")
    frustum(11.0, D - 3.4, 7.0, D - 7.4, H + 4.2, 1.2, "B")
    for sx in (-1, 1):
        cx = sx * (7.0 + (W - 14.0) / 4)
        box((W - 14.0) / 2 + 0.4, D - 1.6, 0.35, cx, -1.0, H - 1.6 + 0.8, "C", 0.03)
        frustum((W - 14.0) / 2 + 0.2, D - 1.8, (W - 14.0) / 2 - 2.6, D - 4.6, H - 0.8 + 0.8, 2.6, "B")
        PARTS[-1].location = (cx, -1.0, 0)
    for x in (-3.6, 3.6):
        box(1.4, 1.2, 1.8, x, fy - 1.2, H + 1.2, "A", 0.03)
        if v == 0:
            half_sphere(0.75, x, fy - 1.2, H + 3.0, "B", 12, 0.9)
        else:
            gable(1.4, 1.2, H + 3.0, 0.8, "B", 0.12, "y")
            PARTS[-1].location = (x, fy - 1.2, 0)
        window(x, fy - 0.55, H + 1.4, 0.8, 1.1, "+y", arched=(v == 0))
    for sx in (-1, 1):
        box(1.1, 1.6, 3.4, sx * 4.8, -2.5, H + 2.6, "brick", 0.03)
        box(1.3, 1.8, 0.25, sx * 4.8, -2.5, H + 6.0, "stone", 0.02)
    box(7.0, 0.1, 0.4, 0, 0, H + 5.4, "iron", 0.0)
    if v == 1:
        # 塔楼角亭（图五城市立面里的钟塔屋顶）
        box(4.2, 4.2, 4.0, hw - 2.6, fy - 3.0, H + 0.6, "A", 0.03)
        onion_cap(hw - 2.6, fy - 3.0, H + 4.6, 2.5, 4.2, "B")
        cyl(0.1, 1.6, hw - 2.6, fy - 3.0, H + 8.8, "gold", 6, r2=0.0)
    export("mansion_%d" % v, [W, H, D])


CITY4_BUILDERS = {"crystal_palace_0": b_crystal_palace, "mansion_0": lambda: b_mansion(0), "mansion_1": lambda: b_mansion(1)}
for _o in list(bpy.data.objects):
    bpy.data.objects.remove(_o, do_unlink=True)
for _m in list(bpy.data.materials):
    bpy.data.materials.remove(_m)
_mats.clear()
run_builders(CITY4_BUILDERS)
