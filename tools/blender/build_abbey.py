# 晨钟修道院（晨露谷）重制：礼拜堂 / 钟楼 / 军需处 / 训练厅 / 小屋 / 院墙 / 门拱 / 灯柱 / 柏树 / 训练假人 / 武器架 /
# 鸟浴盆 / 十字墓碑 / 花盆，以及全局树木（橡树/松树/灌木）重做。
# 参考：docs/buildings_v2/vale_abbey_chapel/hero.png（概念图）、F:\MabinogiMobile\extracted\Textures\Splash_BG.png（植被风格）
# Run: blender -b --factory-startup --python tools/blender/build_abbey.py -- <out_dir> [names]
# 材质名对应 src/world/model_prop.gd::_mtype → 建筑着色器：stone=石块 sandstone=光面石饰 slate=石板瓦 wood/wood_dark/door=木
#   iron/bronze/gold=金属 leaf/flower_*=植物 plaster(A)=灰泥 thatch=茅草 glass/lamp=游戏内窗户/灯罩
import bpy, os, sys, math, random
_LIB_ONLY = True
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "build_models.py"), encoding="utf-8").read())
COLORS.update({
    "stone": "e2d6bc", "stone_dark": "b8aa8e", "sandstone": "efe5cf", "slate": "4c5a78", "slate_dark": "3a465e",
    "wood": "7a5234", "wood_dark": "4e3220", "door": "6e4528", "iron": "2e2e34", "bronze": "8a6a3a", "gold": "d8b060",
    "leaf": "4f8a3c", "leaf2": "6aa448", "flower_w": "f4f0e6", "flower_p": "e888b0", "flower_y": "f2cc48", "flower_r": "d85050",
    "A": "eee4cc", "B": "4c5a78", "C": "6e4a2e", "thatch": "c9a25a", "cobble": "c8bfae", "plaster": "efe6d0", "soil": "6a4a30",
})


def sphere(r, x, y, z, m, sub=2, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, m)


def blob(r, x, y, z, m, seed, sub=2, squash=0.85, jitter=0.12):
    """有机团块（树冠/灌木/常春藤）：随机扰动的二十面球"""
    random.seed(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    for v in o.data.vertices:
        v.co *= 1.0 + random.uniform(-jitter, jitter)
    o.scale = (1.0, 1.0, squash)
    return _finish(o, m)


def half_torus(R, r, x, y, z, m, rot_z=0.0, seg=16):
    """半圆拱（拱门/拱窗石框），竖直立在 XZ 平面，绕 Z 旋转 rot_z"""
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg * 2, minor_segments=6,
                                     location=(0, 0, 0), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -0.02], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    o.rotation_euler = (math.pi / 2, 0, rot_z)
    o.location = (x, y, z)
    return _finish(o, m)


def arch_window(x, y, z, w, h, facing, frame="sandstone", sill=True):
    """尖拱彩窗：玻璃 + 石框 + 竖棂"""
    s = 1 if facing in ("+y", "+x") else -1
    if facing in ("+y", "-y"):
        box(w, 0.16, h, x, y + s * 0.06, z, "glass", 0.0)
        cyl(w / 2, 0.16, 0, 0, 0, "glass", 12, rot=(math.pi / 2, 0, 0))
        PARTS[-1].location = (x, y + s * 0.06, z + h)
        box(0.08, 0.2, h + w / 2, x, y + s * 0.1, z, "iron", 0.0)
        box(w, 0.2, 0.06, x, y + s * 0.1, z + h * 0.55, "iron", 0.0)
        for sx in (-1, 1):
            box(0.22, 0.3, h, x + sx * (w / 2 + 0.11), y + s * 0.08, z, frame, 0.03)
        half_torus(w / 2 + 0.11, 0.13, x, y + s * 0.1, z + h, frame)
        if sill:
            box(w + 0.6, 0.45, 0.16, x, y + s * 0.2, z - 0.16, frame, 0.03)
    else:
        box(0.16, w, h, x + s * 0.06, y, z, "glass", 0.0)
        cyl(w / 2, 0.16, 0, 0, 0, "glass", 12, rot=(0, math.pi / 2, 0))
        PARTS[-1].location = (x + s * 0.06, y, z + h)
        box(0.2, 0.08, h + w / 2, x + s * 0.1, y, z, "iron", 0.0)
        box(0.2, w, 0.06, x + s * 0.1, y, z + h * 0.55, "iron", 0.0)
        for sy in (-1, 1):
            box(0.3, 0.22, h, x + s * 0.08, y + sy * (w / 2 + 0.11), z, frame, 0.03)
        half_torus(w / 2 + 0.11, 0.13, x + s * 0.1, y, z + h, frame, rot_z=math.pi / 2)
        if sill:
            box(0.45, w + 0.6, 0.16, x + s * 0.2, y, z - 0.16, frame, 0.03)


def oak_door(x, y, z, w, h, facing="+y"):
    """拱形双开橡木门 + 铁箍 + 门环 + 石拱门框"""
    s = 1 if facing == "+y" else -1
    box(w, 0.22, h, x, y + s * 0.08, z, "door", 0.02)
    cyl(w / 2, 0.22, 0, 0, 0, "door", 14, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (x, y + s * 0.08, z + h)
    box(0.05, 0.26, h + w * 0.45, x, y + s * 0.12, z, "wood_dark", 0.0)
    for k in range(3):
        box(w * 0.9, 0.26, 0.1, x, y + s * 0.13, z + 0.4 + k * h * 0.38, "iron", 0.0)
    for sx in (-1, 1):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.12, minor_radius=0.025, location=(x + sx * 0.22, y + s * 0.25, z + h * 0.5), rotation=(math.pi / 2, 0, 0))
        _finish(bpy.context.active_object, "iron")
    for sx in (-1, 1):
        box(0.45, 0.5, h, x + sx * (w / 2 + 0.22), y + s * 0.1, z, "sandstone", 0.04)
    half_torus(w / 2 + 0.22, 0.24, x, y + s * 0.12, z + h, "sandstone")
    half_torus(w / 2 + 0.55, 0.12, x, y + s * 0.16, z + h, "stone_dark")


def wall_lantern(x, y, z, facing="+y"):
    s = 1 if facing == "+y" else -1
    box(0.08, 0.6, 0.08, x, y + s * 0.3, z + 0.4, "iron", 0.0)
    box(0.36, 0.36, 0.06, x, y + s * 0.6, z + 0.38, "iron", 0.0)
    cyl(0.14, 0.42, x, y + s * 0.6, z - 0.06, "lamp", 6)
    cyl(0.24, 0.22, x, y + s * 0.6, z + 0.36, "iron", 6, r2=0.0)


def ivy(x, y, z, h, seed, facing="+y", spread=0.9):
    """沿墙攀爬的常春藤：一串扁平叶团 + 零星小白花"""
    random.seed(seed)
    s = 1 if facing in ("+y", "+x") else -1
    n = max(2, int(h / 0.7))
    for i in range(n):
        f = i / max(1, n - 1)
        off = random.uniform(-spread, spread) * (0.4 + f)
        px, py = (x + off, y + s * 0.12) if facing in ("+y", "-y") else (x + s * 0.12, y + off)
        r = random.uniform(0.32, 0.55) * (1.1 - f * 0.4)
        sc = (1.0, 0.45, 1.0) if facing in ("+y", "-y") else (0.45, 1.0, 1.0)
        blob(r, px, py, z + f * h, "leaf" if i % 3 else "leaf2", seed + i, 1, 1.0, 0.2)
        PARTS[-1].scale = sc
        if random.random() < 0.3:
            sphere(0.08, px + random.uniform(-0.2, 0.2), py + s * 0.15, z + f * h + 0.15, "flower_w", 1)


def flower_box(x, y, z, w, facing="+y", seed=0):
    random.seed(seed)
    s = 1 if facing == "+y" else -1
    box(w, 0.36, 0.28, x, y + s * 0.22, z, "wood", 0.02)
    for i in range(int(w / 0.22)):
        fx = x - w / 2 + 0.11 + i * 0.22
        blob(0.17, fx, y + s * 0.24, z + 0.36, "leaf", seed + i, 1, 0.9)
        sphere(0.08, fx + 0.04, y + s * 0.34, z + 0.5, random.choice(["flower_p", "flower_w", "flower_y", "flower_r"]), 1)


def curved_gable(w, d, z, h, m, over=0.7, sag=0.35, flare=0.35, axis="y", ends=True, end_m="stone", barge=True):
    """手绘风弯曲双坡屋顶：坡面内凹 + 檐口外翻；可生成山墙三角墙与木质封檐板。
    axis='y' 屋脊沿 Y（进深）方向。返回剖面函数 prof(t, side) -> (横向坐标, 高度)"""
    n = 10
    half = w / 2 + over

    def prof(t, s):
        x = s * half * (1 - t)
        zz = z + h * t - sag * math.sin(math.pi * t) - flare * (1 - t) ** 3 + flare * 0.0
        return x, zz

    verts, faces = [], []
    L = d / 2 + over
    for side in (-1, 1):
        base = len(verts)
        for i in range(n + 1):
            t = i / n
            x, zz = prof(t, side)
            for yy in (-L, L):
                verts.append((x, yy, zz) if axis == "y" else (yy, x, zz))
        for i in range(n):
            a = base + i * 2
            faces.append((a, a + 1, a + 3, a + 2) if side < 0 else (a, a + 2, a + 3, a + 1))
    o = mesh_obj(verts, faces, m)
    o.modifiers.new("s", "SOLIDIFY").thickness = 0.28
    # 屋脊压条
    if axis == "y":
        box(0.42, 2 * L + 0.1, 0.3, 0, 0, z + h - 0.12, "slate_dark", 0.04)
    else:
        box(2 * L + 0.1, 0.42, 0.3, 0, 0, z + h - 0.12, "slate_dark", 0.04)
    if ends:
        for ey in (-d / 2, d / 2):
            pts = [prof(i / n, -1) for i in range(n + 1)] + [prof(i / n, 1) for i in range(n, -1, -1)]
            pts = [(px * (w / 2) / half, pz) for px, pz in pts if abs(px) <= half]
            v2 = [(px, ey, max(pz - 0.25, z)) if axis == "y" else (ey, px, max(pz - 0.25, z)) for px, pz in pts]
            v2 += [(w / 2, ey, z), (-w / 2, ey, z)] if axis == "y" else [(ey, w / 2, z), (ey, -w / 2, z)]
            g = mesh_obj(v2, [tuple(range(len(v2)))], end_m)
            g.modifiers.new("s", "SOLIDIFY").thickness = 0.5
    if barge:
        for ey in (-L, L):
            for side in (-1, 1):
                for i in range(n):
                    x0, z0 = prof(i / n, side)
                    x1, z1 = prof((i + 1) / n, side)
                    ln = math.hypot(x1 - x0, z1 - z0)
                    ang = math.atan2(z1 - z0, x1 - x0)
                    if axis == "y":
                        box(ln + 0.05, 0.22, 0.38, (x0 + x1) / 2, ey + (0.12 if ey > 0 else -0.12), (z0 + z1) / 2 - 0.25, "wood", 0.0, rot=(0, -ang, 0))
                    else:
                        box(0.22, ln + 0.05, 0.38, ey + (0.12 if ey > 0 else -0.12), (x0 + x1) / 2, (z0 + z1) / 2 - 0.25, "wood", 0.0, rot=(ang, 0, 0))
    return prof


def bracket(x, y, z, facing="+y", size=0.7):
    """屋檐下木托架"""
    s = 1 if facing in ("+y", "+x") else -1
    if facing in ("+y", "-y"):
        box(0.18, size, 0.18, x, y + s * size / 2, z, "wood_dark", 0.02)
        box(0.16, 0.16, size, x, y + s * 0.08, z - size, "wood_dark", 0.02)
        box(0.12, size * 1.1, 0.12, x, y + s * size * 0.4, z - size * 0.45, "wood_dark", 0.0, rot=(s * 0.78, 0, 0))
    else:
        box(size, 0.18, 0.18, x + s * size / 2, y, z, "wood_dark", 0.02)
        box(0.16, 0.16, size, x + s * 0.08, y, z - size, "wood_dark", 0.02)
        box(size * 1.1, 0.12, 0.12, x + s * size * 0.4, y, z - size * 0.45, "wood_dark", 0.0, rot=(0, -s * 0.78, 0))


def stone_cross(x, y, z, h=1.4, m="sandstone"):
    box(0.24, 0.24, h, x, y, z, m, 0.03)
    box(h * 0.6, 0.24, 0.24, x, y, z + h * 0.62, m, 0.03)


def spire(x, y, z, r, h, m="slate", flare=0.5):
    """带外翻裙边的四棱尖顶 + 金色十字"""
    frustum(r * 2 + flare * 2, r * 2 + flare * 2, r * 2, r * 2, z, 0.6, m)
    PARTS[-1].location = (x, y, 0)
    cyl(r * 1.414, h, x, y, z + 0.5, m, 4, r2=0.0, rot=(0, 0, math.pi / 4))
    sphere(0.16, x, y, z + 0.5 + h, "gold", 1)
    box(0.1, 0.1, 1.1, x, y, z + 0.55 + h, "gold", 0.0)
    box(0.6, 0.1, 0.1, x, y, z + 0.55 + h + 0.7, "gold", 0.0)


# ================================================================ 礼拜堂
def b_abbey_chapel():
    W, D, H = 14.0, 26.0, 9.0          # 墙体；含屋顶总高约 20
    box(W + 1.6, D + 1.6, 3.0, 0, 0, -2.6, "stone_dark", 0.06)
    box(W + 1.0, D + 1.0, 0.5, 0, 0, 0, "stone_dark", 0.05)
    box(W, D, H, 0, 0, 0.4, "stone", 0.05)
    box(W + 0.3, D + 0.3, 0.35, 0, 0, H + 0.2, "sandstone", 0.03)
    curved_gable(W, D, H + 0.55, 7.5, "slate", over=0.9, sag=0.45, flare=0.4, axis="y", end_m="stone")
    # 侧墙：扶壁 + 尖拱彩窗 + 屋檐托架 + 花箱
    nb = 5
    for sx in (-1, 1):
        f = "+x" if sx > 0 else "-x"
        for i in range(nb + 1):
            yy = -D / 2 + 1.2 + i * (D - 2.4) / nb
            box(1.0, 1.3, H * 0.85, sx * (W / 2 + 0.45), yy, 0.4, "stone", 0.05)
            box(0.8, 1.1, 1.2, sx * (W / 2 + 0.35), yy, H * 0.85 + 0.4, "stone", 0.05, rot=(0, -sx * 0.5, 0))
            bracket(sx * (W / 2 + 0.05), yy, H + 0.4, f, 0.6)
        for i in range(nb):
            yy = -D / 2 + 1.2 + (i + 0.5) * (D - 2.4) / nb
            arch_window(sx * W / 2, yy, 3.0, 1.3, 3.6, f)
            if i % 2 == 0:
                flower_box(sx * (W / 2 + 0.2), yy, 2.55, 1.6, "+y", 30 + i)
                PARTS[-6:] and None
        # 屋顶老虎窗
        for k in (-1, 1):
            yy = k * D * 0.18
            box(1.6, 1.4, 1.6, sx * W * 0.28, yy, H + 2.4, "stone", 0.03, rot=(0, 0, 0))
            gable_tri = curved_gable(1.6, 1.4, H + 4.0, 1.1, "slate", over=0.25, sag=0.05, flare=0.05, axis="x", ends=False, barge=False)
            for p in PARTS[-2:]:
                p.location.x += sx * W * 0.28
                p.location.y += yy
            window(sx * W * 0.28, yy, H + 2.7, 0.6, 0.8, "+x" if sx > 0 else "-x")
    # 正立面（+Y）：玫瑰窗 + 拱门 + 壁灯 + 台阶 + 常春藤
    fy = D / 2
    oak_door(0, fy, 0.5, 2.4, 3.2)
    for k in range(3):
        box(4.6 + k * 1.0, 1.0, 0.25, 0, fy + 0.9 + (2 - k) * 0.75, 0.25 + k * 0.25 - 0.5, "sandstone", 0.03)
    rz = H + 2.4
    cyl(2.1, 0.3, 0, 0, 0, "sandstone", 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, fy + 0.15, rz)
    cyl(1.75, 0.34, 0, 0, 0, "glass", 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, fy + 0.2, rz)
    for k in range(8):
        a = k * math.tau / 8
        bpy.ops.mesh.primitive_torus_add(major_radius=0.5, minor_radius=0.07, major_segments=12, minor_segments=4,
                                         location=(math.cos(a) * 1.0, fy + 0.4, rz + math.sin(a) * 1.0), rotation=(math.pi / 2, 0, 0))
        _finish(bpy.context.active_object, "sandstone")
    bpy.ops.mesh.primitive_torus_add(major_radius=0.42, minor_radius=0.08, major_segments=12, minor_segments=4,
                                     location=(0, fy + 0.4, rz), rotation=(math.pi / 2, 0, 0))
    _finish(bpy.context.active_object, "sandstone")
    for sx in (-1, 1):
        wall_lantern(sx * 2.4, fy, 3.2)
        box(1.3, 1.5, H * 0.95, sx * (W / 2 - 0.2), fy + 0.4, 0.4, "stone", 0.05)
        ivy(sx * (W / 2 - 0.9), fy + 0.4, 0.6, H * 0.85, 40 + sx, "+y", 0.6)
        flower_box(sx * 2.4, fy, 0.5, 1.0, "+y", 50 + sx)
    stone_cross(0, fy - 0.1, H + 0.55 + 7.6, 1.6)
    # 侧面常春藤
    ivy(W / 2 + 0.2, D * 0.3, 0.5, H * 0.7, 61, "+x", 1.0)
    ivy(-W / 2 - 0.2, -D * 0.2, 0.5, H * 0.8, 62, "-x", 1.0)
    # 后殿（半圆）
    cyl(W * 0.38, H * 0.85, 0, -D / 2, 0.4, "stone", 16)
    cyl(W * 0.42, 2.8, 0, -D / 2, H * 0.85 + 0.4, "slate", 16, r2=W * 0.1)
    for k in range(3):
        a = math.pi + (k - 1) * 0.6
        arch_window(math.sin(a) * W * 0.38 * 0.0, -D / 2 - W * 0.36, 2.8, 0.9, 2.6, "-y")
        PARTS[-1].location.x += (k - 1) * 2.6
    export("abbey_chapel_0", [W, H, D])


# ================================================================ 钟楼
def b_abbey_campanile():
    S, H = 6.0, 15.0
    box(S + 1.4, S + 1.4, 3.0, 0, 0, -2.6, "stone_dark", 0.06)
    box(S + 0.8, S + 0.8, 1.2, 0, 0, 0, "stone_dark", 0.05)
    box(S, S, H, 0, 0, 1.0, "stone", 0.05)
    for k in range(1, 4):
        box(S + 0.25, S + 0.25, 0.3, 0, 0, 1.0 + k * H / 4, "sandstone", 0.03)
    for f, (dx, dy) in (("+y", (0, 1)), ("-y", (0, -1)), ("+x", (1, 0)), ("-x", (-1, 0))):
        window(dx * S / 2, dy * S / 2, H * 0.45, 0.5, 1.1, f)
    oak_door(0, S / 2, 1.0, 1.6, 2.4)
    # 钟室：四角柱 + 拱 + 铜钟
    bz = H + 1.0
    box(S + 0.5, S + 0.5, 0.4, 0, 0, bz, "sandstone", 0.03)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(1.3, 1.3, 3.6, sx * (S / 2 - 0.65), sy * (S / 2 - 0.65), bz + 0.4, "stone", 0.04)
    for rz, f in ((0, "y"), (math.pi / 2, "x")):
        for s in (-1, 1):
            off = (0, s * (S / 2 - 0.35)) if f == "y" else (s * (S / 2 - 0.35), 0)
            half_torus(1.7, 0.32, off[0], off[1], bz + 2.5, "stone", rot_z=rz)
            box(S if f == "y" else 0.7, 0.7 if f == "y" else S, 1.6, off[0], off[1], bz + 2.6, "stone", 0.03)
    box(S + 0.6, S + 0.6, 0.45, 0, 0, bz + 4.0, "sandstone", 0.03)
    cyl(0.9, 1.5, 0, 0, bz + 1.4, "bronze", 14, r2=0.45)
    sphere(0.45, 0, 0, bz + 2.9, "bronze", 2, (1, 1, 0.6))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.92, minor_radius=0.08, location=(0, 0, bz + 1.45))
    _finish(bpy.context.active_object, "bronze")
    box(S - 1.0, 0.25, 0.25, 0, 0, bz + 3.3, "wood_dark", 0.0)
    spire(0, 0, bz + 4.45, S / 2 - 0.1, 6.0, "slate", 0.45)
    ivy(S / 2 + 0.1, -1.0, 1.0, H * 0.7, 71, "+x", 0.7)
    ivy(-1.2, S / 2 + 0.1, 1.0, H * 0.45, 72, "+y", 0.6)
    export("abbey_campanile_0", [S, H, S])


# ================================================================ 石木住宅（军需处 / 训练厅 / 修士小屋）
def stone_timber_house(W, D, H1, H2, variant, name):
    box(W + 0.8, D + 0.8, 3.0, 0, 0, -2.6, "stone_dark", 0.05)
    box(W, D, H1, 0, 0, 0.2, "stone", 0.05)
    # 二层略挑出的木筋灰泥墙
    box(W + 0.5, D + 0.5, 0.35, 0, 0, H1 + 0.2, "wood_dark", 0.02)
    box(W + 0.4, D + 0.4, H2, 0, 0, H1 + 0.55, "plaster", 0.03)
    zt = H1 + 0.55
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(0.3, 0.3, H2, sx * (W / 2 + 0.1), sy * (D / 2 + 0.1), zt, "wood_dark", 0.02)
    box(W + 0.6, D + 0.6, 0.28, 0, 0, zt + H2 - 0.1, "wood_dark", 0.02)
    for side in (1, -1):
        for i in range(int(W / 1.8) + 1):
            x = -W / 2 + i * W / int(W / 1.8)
            box(0.2, 0.14, H2, x, side * (D / 2 + 0.22), zt, "wood_dark", 0.0)
        for i in range(int(W / 3.6)):
            x = -W / 2 + 1.8 + i * 3.6
            box(0.16, 0.12, H2 * 1.1, x, side * (D / 2 + 0.24), zt + 0.05, "wood_dark", 0.0, rot=(0, 0.7, 0))
    prof = curved_gable(W + 0.4, D + 0.4, zt + H2 + 0.05, min(W, D) * 0.55, "slate", over=0.8, sag=0.3, flare=0.3, axis="x", end_m="plaster")
    for i in range(int(W / 2.4) + 1):
        x = -W / 2 + i * W / int(W / 2.4)
        for s in (-1, 1):
            bracket(x, s * (D / 2 + 0.25), zt + H2, "+y" if s > 0 else "-y", 0.5)
    box(0.9, 0.9, 4.0, W * 0.3, -D * 0.15, zt + H2, "stone", 0.04)
    box(1.1, 1.1, 0.3, W * 0.3, -D * 0.15, zt + H2 + 4.0, "stone_dark", 0.03)
    # 门窗
    oak_door(0, D / 2, 0.2, 1.5, 2.3)
    for sx in (-1, 1):
        window(sx * W * 0.3, D / 2, 1.1, 1.0, 1.2, "+y")
        window(sx * W * 0.3, D / 2 + 0.2, zt + 0.7, 0.9, 1.1, "+y")
        flower_box(sx * W * 0.3, D / 2 + 0.2, zt + 0.35, 1.2, "+y", 80 + sx + variant * 5)
        window(sx * W * 0.3, -D / 2, 1.1, 1.0, 1.2, "-y")
        window(sx * W / 2, 0, 1.1, 1.0, 1.2, "+x" if sx > 0 else "-x")
        window(sx * (W / 2 + 0.2), 0, zt + 0.7, 0.9, 1.1, "+x" if sx > 0 else "-x")
    wall_lantern(1.3, D / 2, 2.4)
    if variant == 0:
        # 军需处：条纹遮阳篷 + 货箱木桶
        for i in range(6):
            box(W * 0.8 / 6, 1.8, 0.08, -W * 0.4 + (i + 0.5) * W * 0.8 / 6, D / 2 + 0.9, 2.95, "slate" if i % 2 == 0 else "flower_w", 0.0, rot=(-0.3, 0, 0))
        for k in range(3):
            box(0.9, 0.9, 0.9, W / 2 + 0.8, D * 0.2 - k * 1.1, 0.2, "wood", 0.04)
        cyl(0.42, 1.0, -W / 2 - 0.7, D * 0.25, 0.2, "wood", 12)
        cyl(0.42, 1.0, -W / 2 - 0.7, D * 0.25 - 1.0, 0.2, "wood", 12)
    elif variant == 1:
        # 训练厅：侧面开敞木构披檐（练习场）
        for k in range(4):
            box(0.35, 0.35, 3.2, -W * 0.4 + k * W * 0.27, -D / 2 - 3.4, 0.2, "wood_dark", 0.02)
        box(W, 4.2, 0.2, 0, -D / 2 - 1.8, 3.3, "slate", 0.0, rot=(0.25, 0, 0))
        box(W * 1.02, 0.3, 0.3, 0, -D / 2 - 3.4, 3.35, "wood_dark", 0.02)
    ivy(-W / 2 - 0.1, D * 0.2, 0.3, H1 + H2 * 0.6, 90 + variant, "-x", 0.8)
    export(name, [W, H1 + H2, D])


def b_abbey_house():
    stone_timber_house(11.0, 8.5, 3.2, 3.0, 0, "abbey_house_0")


def b_abbey_hall():
    stone_timber_house(12.0, 10.0, 3.4, 3.0, 1, "abbey_house_1")


def b_abbey_cottage():
    W, D, H = 8.0, 7.0, 4.2
    box(W + 0.8, D + 0.8, 3.0, 0, 0, -2.6, "stone_dark", 0.05)
    box(W, D, H, 0, 0, 0.2, "stone", 0.05)
    curved_gable(W, D, H + 0.2, 4.0, "thatch", over=1.0, sag=-0.25, flare=0.5, axis="x", end_m="plaster")
    oak_door(0, D / 2, 0.2, 1.3, 2.1)
    for sx in (-1, 1):
        window(sx * W * 0.3, D / 2, 1.1, 0.9, 1.0, "+y")
        flower_box(sx * W * 0.3, D / 2, 0.85, 1.1, "+y", 95 + sx)
    box(0.8, 0.8, 3.6, -W * 0.3, -D * 0.2, H, "stone", 0.04)
    ivy(W / 2 + 0.1, 0, 0.3, H * 0.9, 97, "+x", 0.8)
    export("abbey_cottage_0", [W, H, D])


# ================================================================ 院墙 / 门拱 / 小品
def b_abbey_wall():
    L, H, T = 4.0, 2.6, 0.9
    box(L, T, H, 0, 0, -1.5, "stone", 0.05)
    PARTS[-1].scale.z = (H + 1.5)
    PARTS[-1].location.z = -1.5 + 0.0
    box(L + 0.05, T + 0.25, 0.25, 0, 0, H, "sandstone", 0.03)
    box(1.1, 1.1, H + 0.6, L / 2, 0, -1.5, "stone", 0.05)
    PARTS[-1].scale.z = H + 2.1
    box(1.3, 1.3, 0.3, L / 2, 0, H + 0.6, "sandstone", 0.03)
    sphere(0.3, L / 2, 0, H + 1.1, "sandstone", 1)
    random.seed(110)
    for i in range(3):
        ivy(random.uniform(-L / 2 + 0.5, L / 2 - 0.8), T / 2, 0.0, random.uniform(1.2, 2.4), 111 + i, "+y", 0.5)
        if random.random() < 0.6:
            ivy(random.uniform(-L / 2 + 0.5, L / 2 - 0.8), -T / 2, 0.0, random.uniform(1.0, 2.2), 121 + i, "-y", 0.5)
    export("abbey_wall_0", [L, H, T])


def b_abbey_gate():
    W, H, T = 4.4, 3.0, 1.2
    for sx in (-1, 1):
        box(1.4, T + 0.4, H, sx * (W / 2 + 0.7), 0, -1.0, "stone", 0.05)
        PARTS[-1].scale.z = H + 1.0
        box(1.6, T + 0.6, 0.3, sx * (W / 2 + 0.7), 0, H, "sandstone", 0.03)
        sphere(0.32, sx * (W / 2 + 0.7), 0, H + 0.6, "sandstone", 1)
    half_torus(W / 2 + 0.35, 0.4, 0, 0, H - 0.4, "stone")
    PARTS[-1].scale = (1, 1, 1)
    top = H - 0.4 + W / 2 + 0.75
    v = [(-W / 2 - 1.4, 0, H), (W / 2 + 1.4, 0, H), (W / 2 + 1.4, 0, top), (-W / 2 - 1.4, 0, top)]
    for i in range(9):
        a = math.pi * i / 8
        v.append((math.cos(a) * (W / 2 + 0.1) * -1 if False else (W / 2 + 0.1) * math.cos(math.pi - a), 0, H - 0.4 + (W / 2 + 0.1) * math.sin(math.pi - a)))
    box(W + 2.8, T, 0.8, 0, 0, top - 0.8, "stone", 0.04)
    box(W + 3.0, T + 0.3, 0.3, 0, 0, top, "sandstone", 0.03)
    stone_cross(0, 0, top + 0.3, 1.2)
    # 敞开的铁门
    for sx in (-1, 1):
        for i in range(5):
            box(0.06, 0.06, 2.6, sx * (W / 2 - 0.1) - sx * 0.0, sx * 0.0 + 0.1 + i * 0.22 * 0, 0, "iron", 0.0)
            PARTS[-1].location = (sx * (W / 2 - 0.15), T / 2 + 0.25 + i * 0.25, 0)
        box(0.06, 1.2, 0.08, sx * (W / 2 - 0.15), T / 2 + 0.75, 2.4, "iron", 0.0)
        box(0.06, 1.2, 0.08, sx * (W / 2 - 0.15), T / 2 + 0.75, 0.5, "iron", 0.0)
    ivy(-W / 2 - 1.2, T / 2 + 0.2, 0.0, H, 131, "+y", 0.4)
    ivy(W / 2 + 1.2, -T / 2 - 0.2, 0.0, H * 0.8, 132, "-y", 0.4)
    export("abbey_gate_0", [W, H, T])


def b_lantern_post():
    box(0.6, 0.6, 0.5, 0, 0, 0, "stone", 0.05)
    cyl(0.12, 3.4, 0, 0, 0.5, "wood_dark", 8)
    box(0.1, 0.9, 0.1, 0, 0.35, 3.75, "iron", 0.0)
    cyl(0.04, 0.3, 0, 0.75, 3.45, "iron", 6)
    cyl(0.17, 0.5, 0, 0.75, 2.95, "lamp", 6, r2=0.22)
    cyl(0.28, 0.25, 0, 0.75, 3.45, "iron", 6, r2=0.0)
    blob(0.3, 0.1, -0.1, 0.55, "leaf", 141, 1, 0.8)
    export("lantern_post_0", [1.0, 4.0, 1.0])


def b_cypress():
    cyl(0.18, 1.2, 0, 0, 0, "wood_dark", 6)
    random.seed(150)
    for i in range(6):
        r = 1.0 - i * 0.12
        blob(r, random.uniform(-0.1, 0.1), random.uniform(-0.1, 0.1), 1.6 + i * 0.95, "B", 151 + i, 2, 1.25, 0.1)
    blob(0.35, 0, 0, 7.0, "B", 160, 1, 1.4)
    export("cypress_0", [2.0, 7.0, 2.0])


def b_training_dummy():
    cyl(0.12, 2.0, 0, 0, 0, "wood_dark", 8)
    box(1.6, 0.14, 0.14, 0, 0, 1.45, "wood_dark", 0.02)
    cyl(0.38, 0.9, 0, 0, 0.9, "thatch", 10, r2=0.32)
    sphere(0.3, 0, 0, 2.05, "thatch", 2)
    box(0.4, 0.42, 0.5, 0, 0.05, 1.05, "wood", 0.03)
    for sx in (-1, 1):
        cyl(0.13, 0.5, sx * 0.85, 0, 1.25, "thatch", 8)
    box(0.9, 0.9, 0.12, 0, 0, 0, "wood", 0.02)
    export("training_dummy_0", [1.0, 1.0, 1.0])


def b_weapon_rack():
    for sx in (-1, 1):
        box(0.12, 0.5, 1.6, sx * 1.1, 0, 0, "wood_dark", 0.02)
    for z in (0.45, 1.35):
        box(2.4, 0.12, 0.1, 0, 0, z, "wood", 0.02)
    for i in range(5):
        x = -0.8 + i * 0.4
        box(0.07, 0.04, 1.5, x, 0.08, 0.1, "iron", 0.0, rot=(0.12, 0, 0))
        box(0.3, 0.06, 0.06, x, 0.12, 1.25, "bronze", 0.0)
    cyl(0.45, 0.08, 0, 0, 0, "wood", 14, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0.9, -0.2, 0.9)
    export("weapon_rack_0", [1.0, 1.0, 1.0])


def b_birdbath():
    cyl(0.45, 0.2, 0, 0, 0, "sandstone", 10)
    cyl(0.18, 0.9, 0, 0, 0.2, "sandstone", 10, r2=0.14)
    cyl(0.62, 0.22, 0, 0, 1.05, "sandstone", 14, r2=0.5)
    cyl(0.5, 0.05, 0, 0, 1.22, "water", 14)
    export("birdbath_0", [1.0, 1.0, 1.0])


def b_grave_cross():
    box(0.9, 0.4, 0.3, 0, 0, 0, "stone_dark", 0.04)
    stone_cross(0, 0, 0.3, 1.3, "stone")
    box(1.0, 1.9, 0.18, 0, -1.1, 0, "soil", 0.04)
    blob(0.25, 0.3, -0.7, 0.2, "leaf", 171, 1, 0.6)
    sphere(0.07, 0.3, -0.7, 0.38, "flower_w", 1)
    export("grave_cross_0", [1.0, 1.0, 1.0])


def b_flower_pot():
    cyl(0.32, 0.5, 0, 0, 0, "thatch", 12, r2=0.42)
    PARTS[-1].data.materials.clear()
    PARTS[-1].data.materials.append(mat("terracotta"))
    random.seed(180)
    blob(0.42, 0, 0, 0.75, "leaf", 181, 1, 0.8)
    for i in range(7):
        a = i * math.tau / 7
        sphere(0.09, math.cos(a) * 0.3, math.sin(a) * 0.3, 0.95 + random.uniform(-0.05, 0.1), random.choice(["flower_p", "flower_w", "flower_y"]), 1)
    export("flower_pot_0", [1.0, 1.0, 1.0])


# ================================================================ 树木重做（参考 Splash_BG：多团块圆润树冠 + 分层松树）
def b_oak():
    random.seed(200)
    cyl(0.35, 2.6, 0, 0, 0, "wood_dark", 8, r2=0.22)
    for a, l in ((0.5, 1.6), (2.6, 1.4), (4.4, 1.5)):
        cyl(0.13, l, math.cos(a) * 0.2, math.sin(a) * 0.2, 2.0, "wood_dark", 6, r2=0.07, rot=(math.sin(a) * 0.9, -math.cos(a) * 0.9, 0))
    for (x, y, z, r) in [(0, 0, 4.4, 2.0), (1.3, 0.4, 3.9, 1.45), (-1.2, -0.5, 3.8, 1.4), (0.3, -1.2, 4.0, 1.3),
                         (-0.4, 1.1, 4.1, 1.3), (0.2, 0.1, 5.6, 1.35), (1.0, -0.6, 5.0, 1.0), (-0.9, 0.6, 5.1, 1.0)]:
        blob(r, x, y, z, "B", int(200 + x * 10 + y * 7 + z), 2, 0.82, 0.14)
    export("tree_0", [4.0, 6.0, 4.0])


def b_pine():
    random.seed(210)
    cyl(0.22, 2.0, 0, 0, 0, "wood_dark", 6, r2=0.16)
    tiers = 6
    for i in range(tiers):
        r = 2.4 - i * 0.36
        z = 1.3 + i * 0.95
        bpy.ops.mesh.primitive_cone_add(vertices=9, radius1=r, radius2=r * 0.18, depth=1.5, location=(0, 0, z + 0.75))
        o = bpy.context.active_object
        for v in o.data.vertices:
            if v.co.z < 0:
                v.co.z += random.uniform(-0.25, 0.05)       # 下垂的不规则边缘
                v.co.x *= random.uniform(0.9, 1.1)
                v.co.y *= random.uniform(0.9, 1.1)
        o.rotation_euler = (0, 0, random.uniform(0, 1))
        _finish(o, "B")
    cyl(0.3, 1.0, 0, 0, 1.3 + tiers * 0.95, "B", 7, r2=0.0)
    export("tree_1", [4.0, 6.0, 4.0])


def b_bush():
    random.seed(220)
    for (x, y, z, r) in [(0, 0, 0.5, 0.85), (0.6, 0.15, 0.42, 0.6), (-0.55, -0.1, 0.4, 0.58), (0.1, -0.5, 0.45, 0.55), (0, 0.45, 0.7, 0.5)]:
        blob(r, x, y, z, "B", int(220 + x * 10 + y * 10), 2, 0.78, 0.15)
    export("bush_0", [1.8, 1.2, 1.8])


def b_birch():
    random.seed(230)
    cyl(0.16, 4.6, 0, 0, 0, "flower_w", 7, r2=0.1)
    for k in range(5):
        box(0.17, 0.17, 0.08, 0, 0, 0.6 + k * 0.85, "iron", 0.0)
    for a, l in ((0.8, 1.3), (3.0, 1.2), (5.0, 1.1)):
        cyl(0.06, l, 0, 0, 0, "flower_w", 5, r2=0.03, rot=(math.sin(a) * 0.8, -math.cos(a) * 0.8, 0))
        PARTS[-1].location = (0, 0, 3.0)
    for (x, y, z, r) in [(0, 0, 4.8, 1.25), (0.7, 0.3, 4.2, 0.9), (-0.6, -0.4, 4.3, 0.85), (0.2, -0.6, 5.5, 0.8), (-0.3, 0.6, 5.4, 0.8), (0, 0, 6.1, 0.6)]:
        blob(r, x, y, z, "B", int(230 + x * 10 + y * 7 + z), 2, 1.05, 0.14)
    export("tree_3", [4.0, 6.0, 4.0])


ABBEY_BUILDERS = {
    "abbey_chapel_0": b_abbey_chapel, "abbey_campanile_0": b_abbey_campanile, "abbey_house_0": b_abbey_house,
    "abbey_house_1": b_abbey_hall, "abbey_cottage_0": b_abbey_cottage, "abbey_wall_0": b_abbey_wall, "abbey_gate_0": b_abbey_gate,
    "lantern_post_0": b_lantern_post, "cypress_0": b_cypress, "training_dummy_0": b_training_dummy, "weapon_rack_0": b_weapon_rack,
    "birdbath_0": b_birdbath, "grave_cross_0": b_grave_cross, "flower_pot_0": b_flower_pot,
    "tree_0": b_oak, "tree_1": b_pine, "bush_0": b_bush, "tree_3": b_birch,
}
COLORS["terracotta"] = "c06a3a"
COLORS["water"] = "70c8e0"
run_builders(ABBEY_BUILDERS)
