# Batch 6 (2026-10-05): Solenne v3 hero assets, designed from the user's reference images.
#   grand_station_0  中央车站：双塔亭顶 + 巨型拱窗 + 铜绿穹顶 + 两翼 + 玻璃雨棚 + 后部拱形站棚（参考图 1/4/7）
#   cathedral2_0     大教堂：双钟楼（开放拱廊 + 肋状穹顶 + 尖顶）+ 长中殿 + 十字翼 + 半圆后殿（参考图 3/5）
#   tholos_0         圆亭：三级台阶 + 10 根凹槽柱 + 环形檐 + 花藤 + 中央水池（参考图 6）
#   manor_0..3       蓝色曼萨德屋顶联排（底层拱廊店面 + 铁艺阳台 + 老虎窗 + 烟囱）（参考图 8/9）
#   corner_0         转角公寓：圆柱角楼 + 尖帽 + 绿色铁窗凸窗（参考图 7 上）
#   viaduct_0        红色钢梁高架轨道段（白色 Y 形墩柱）（参考图 10）
#   hero_statue_0    广场英雄铜像 + 圆形台座（参考图 9）
#   lamp2_0          双头铸铁华灯
#   palm_0           棕榈树（参考图 10）
# Run inside Blender (MCP):  sys.argv = ["b", "--", "E:/wowgame/assets/models", "names"]; exec(open(this).read())
import bpy, bmesh, os, sys, math, random
from mathutils import Vector
_LIB_ONLY = True
_HERE = os.path.dirname(os.path.abspath(__file__)) if "__file__" in globals() else "E:/wowgame/tools/blender"
exec(open(os.path.join(_HERE, "build_models.py"), encoding="utf-8").read())
def mat(name):
    """Robust material maker (Blender 4/5: default node may be missing or renamed)."""
    if name in _mats and _mats[name].name in bpy.data.materials:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    h = COLORS.get(name, "ff00ff")
    c = tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4))
    nt = m.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        for n in list(nt.nodes):
            nt.nodes.remove(n)
        bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        nt.links.new(bsdf.outputs[0], out.inputs[0])
    bsdf.inputs["Base Color"].default_value = (*c, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.9
    m.diffuse_color = (*c, 1.0)
    _mats[name] = m
    return m


COLORS.update({
    "white": "f4f0e6", "beige": "e8dcc4", "sandstone": "e9d3a2", "brick": "b0563e", "copper": "5a9a88",
    "slate": "3d5f8e", "terracotta": "c86a40", "iron": "2f3a40", "red_steel": "b8382e", "bronze": "a07a40",
    "water": "60b8d0", "leaf": "4f9a3e", "leaf2": "6db04a", "trunk": "8a6a48", "flower_w": "efe6f4",
    "flower_p": "c9a0e0", "awning_r": "c84a3a", "awning_b": "3f6fb0", "awning_g": "3f8a6a", "concrete": "e6e1d6",
})


# ---------------------------------------------------------------- extra primitives
def sphere(r, x, y, z, m, sub=2, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, m)


def half_sphere(r, x, y, z, m, seg=20, sz=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(6, seg // 2), radius=r, location=(x, y, z))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    o.scale = (1, 1, sz)
    return _finish(o, m)


def torus(R, r, x, y, z, m, rot=(0, 0, 0), seg=32, mseg=6):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=mseg, location=(x, y, z), rotation=rot)
    return _finish(bpy.context.active_object, m)


def ribbed_dome(x, y, z, r, m, ribs=8, sz=1.0, rib_m="white"):
    half_sphere(r, x, y, z, m, 24, sz)
    for i in range(ribs):
        a = i * math.pi / ribs
        torus(r * 1.01, r * 0.035, x, y, z, rib_m, rot=(math.pi / 2, 0, a), seg=32, mseg=4)
        PARTS[-1].scale = (1, 1, 1)
    # 去掉地平线以下的半环：用一个扁盖子盖住
    cyl(r * 1.06, r * 0.08, x, y, z - r * 0.04, rib_m, 24)


def onion_cap(x, y, z, r, h, m):
    """Pavilion / bell cap: bulging lower part then pointed."""
    prof = [(r * 1.0, 0.0), (r * 1.08, h * 0.18), (r * 0.95, h * 0.42), (r * 0.6, h * 0.66), (r * 0.25, h * 0.86), (0.0, h)]
    verts, faces = [], []
    seg = 16
    for i, (rr, zz) in enumerate(prof):
        for k in range(seg):
            a = k * math.tau / seg
            verts.append((x + math.cos(a) * rr, y + math.sin(a) * rr, z + zz))
    for i in range(len(prof) - 1):
        for k in range(seg):
            a0 = i * seg + k; a1 = i * seg + (k + 1) % seg
            faces.append((a0, a1, a1 + seg, a0 + seg))
    return mesh_obj(verts, faces, m)


def arch_frame(x, y, z, w, h, depth, m, facing="+y", seg=12, thick=0.5):
    """Semicircular arch ring + jambs standing on a facade (opening is left to glass)."""
    r = w / 2
    for sx in (-1, 1):
        box(thick, depth, h, x + sx * (r + thick / 2), y, z, m, 0.03)
    for i in range(seg):
        a0 = math.pi * i / seg; a1 = math.pi * (i + 1) / seg
        am = (a0 + a1) / 2
        cx = x + math.cos(am) * (r + thick / 2)
        cz = z + h + math.sin(am) * (r + thick / 2)
        L = (r + thick / 2) * (a1 - a0) + 0.06
        box(L, depth, thick, cx, y, cz - thick / 2, m, 0.0, rot=(0, -(am - math.pi / 2), 0))
        PARTS[-1].location = (cx, y, cz)


def glass_arch(x, y, z, w, h, facing_s=1, m="glass", mull="iron", spokes=6):
    """Big arched window (rect part h, semicircle on top) with radial mullions."""
    r = w / 2
    box(w, 0.12, h, x, y + facing_s * 0.05, z, m, 0.0)
    cyl(r, 0.12, x, y + facing_s * 0.05, z + h, m, 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (x, y + facing_s * 0.05 - 0.06 * facing_s, z + h)
    for i in range(1, spokes):
        a = math.pi * i / spokes
        box(r, 0.1, 0.12, x + math.cos(a) * r * 0.5, y + facing_s * 0.14, z + h + math.sin(a) * r * 0.5 - 0.06, mull, 0.0, rot=(0, -a, 0))
        PARTS[-1].location = (x + math.cos(a) * r * 0.5, y + facing_s * 0.14, z + h + math.sin(a) * r * 0.5)
    torus(r * 0.45, 0.07, x, y + facing_s * 0.14, z + h, mull, rot=(math.pi / 2, 0, 0), seg=24, mseg=4)
    torus(r * 0.98, 0.09, x, y + facing_s * 0.14, z + h, mull, rot=(math.pi / 2, 0, 0), seg=32, mseg=4)
    for k in range(1, 4):
        box(0.1, 0.1, h, x - r + k * w / 4, y + facing_s * 0.14, z, mull, 0.0)
    box(w, 0.1, 0.12, x, y + facing_s * 0.14, z + h * 0.5, mull, 0.0)


def balustrade(x0, x1, y, z, m="white", h=0.9, axis="x"):
    L = abs(x1 - x0)
    n = max(2, int(L / 0.45))
    if axis == "x":
        box(L, 0.35, 0.15, (x0 + x1) / 2, y, z + h - 0.15, m, 0.02)
        box(L, 0.4, 0.12, (x0 + x1) / 2, y, z, m, 0.02)
        for i in range(n):
            cyl(0.09, h - 0.27, x0 + (i + 0.5) * L / n, y, z + 0.12, m, 6)
    else:
        box(0.35, L, 0.15, y, (x0 + x1) / 2, z + h - 0.15, m, 0.02)
        box(0.4, L, 0.12, y, (x0 + x1) / 2, z, m, 0.02)
        for i in range(n):
            cyl(0.09, h - 0.27, y, x0 + (i + 0.5) * L / n, z + 0.12, m, 6)


def cornice(w, d, z, m="C", over=0.35, h=0.45):
    box(w + over * 2, d + over * 2, h, 0, 0, z, m, 0.04)
    box(w + over, d + over, h * 0.5, 0, 0, z - h * 0.5, m, 0.03)


def wins_face(w, y, z, n, ww, wh, facing="+y", arched=False, x0=0.0):
    for i in range(n):
        window(x0 - w / 2 + (i + 0.5) * w / n, y, z, ww, wh, facing, frame="C", arched=arched)


def wins_side(xside, d, z, n, ww, wh, y0=0.0):
    for j in range(n):
        yy = y0 - d / 2 + (j + 0.5) * d / n
        window(xside, yy, z, ww, wh, "+x" if xside > 0 else "-x", frame="C")


def oculus(x, y, z, r, facing_s=1):
    torus(r, 0.12, x, y + facing_s * 0.08, z, "C", rot=(math.pi / 2, 0, 0), seg=20, mseg=4)
    cyl(r * 0.85, 0.1, x, y + facing_s * 0.03, z, "glass", 16, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (x, y + facing_s * 0.03, z)


# ======================================================================== grand station
def b_grand_station():
    W, D = 56.0, 34.0         # facade width, main block depth
    HC, HW = 19.0, 12.5       # center / wing cornice heights
    fy = D / 2                # facade plane (+Y)
    # plinth
    box(W + 1.2, D + 1.2, 1.0, 0, 0, -0.6, "stone_dark", 0.05)
    box(W + 0.4, D + 0.4, 1.2, 0, 0, 0.0, "stone", 0.04)
    # --- wings (sandstone, two storeys of arched windows, red-brown cornice)
    for sx in (-1, 1):
        cx = sx * (W / 2 - 9.0)
        box(18.0, D - 4.0, HW, cx, -1.0, 0.8, "A", 0.05)
        # pilasters + string course
        for k in range(5):
            box(0.7, 0.5, HW - 0.5, cx - 9.0 + 0.35 + k * 4.32, fy - 2.6, 0.8, "C", 0.03)
        box(18.4, 0.6, 0.45, cx, fy - 2.7, 6.4, "C", 0.03)
        for k in range(4):
            wx = cx - 9.0 + 2.5 + k * 4.32
            window(wx, fy - 3.0, 1.6, 1.8, 3.2, "+y", frame="C", arched=True)
            window(wx, fy - 3.0, 7.4, 1.6, 2.6, "+y", frame="C", arched=True)
        # red bracketed eave (参考图 1 的橙红挑檐)
        box(19.2, D - 2.6, 0.55, cx, -1.0, HW + 0.8, "terracotta", 0.04)
        for k in range(10):
            box(0.25, 0.9, 0.5, cx - 8.5 + k * 1.9, fy - 1.9, HW + 0.35, "terracotta", 0.0)
        frustum(18.6, D - 3.0, 14.0, D - 9.0, HW + 1.35, 2.6, "B")
        PARTS[-1].location = (cx, -1.0, 0)
        # balustrade on wing front
        balustrade(cx - 8.6, cx + 8.6, fy - 2.4, HW + 1.35, "white")
        # corner pavilion with small copper dome at outer end
        ox = sx * (W / 2 - 2.2)
        box(5.2, 6.0, HW + 2.6, ox, fy - 4.2, 0.8, "A", 0.05)
        box(5.8, 6.6, 0.5, ox, fy - 4.2, HW + 3.4, "C", 0.04)
        cyl(2.2, 1.2, ox, fy - 4.2, HW + 3.9, "white", 16)
        ribbed_dome(ox, fy - 4.2, HW + 5.1, 2.3, "copper", 6, 1.15)
        cyl(0.18, 2.2, ox, fy - 4.2, HW + 7.6, "gold", 6, r2=0.0)
        window(ox, fy - 1.15, 3.0, 2.0, 4.2, "+y", frame="C", arched=True)
        window(ox, fy - 1.15, 9.0, 1.4, 2.4, "+y", frame="C")
        door(ox, fy - 1.1, 0.8, 1.8, 2.8)
    # --- central hall block
    box(24.0, D, HC, 0, 0, 0.8, "A", 0.05)
    # great arch: deep recessed frame + glass
    arch_frame(0, fy + 0.25, 1.0, 14.0, 8.5, 1.4, "C", seg=14, thick=1.1)
    glass_arch(0, fy - 0.05, 1.0, 14.0, 8.5, 1)
    # keystone sculpture + round medallions (oculi)
    box(1.4, 0.8, 2.0, 0, fy + 0.4, 16.2, "C", 0.05)
    for sx in (-1, 1):
        oculus(sx * 9.0, fy, 16.0, 1.0)
        oculus(sx * 5.0, fy, 17.4, 0.6)
    # entrance canopy (dark iron frame + glass roof) projecting forward
    box(18.0, 6.0, 0.35, 0, fy + 3.0, 5.2, "iron", 0.03)
    box(17.4, 5.6, 0.15, 0, fy + 3.0, 5.55, "glass", 0.0)
    box(18.2, 0.4, 0.8, 0, fy + 5.9, 4.8, "iron", 0.02)
    for sx in (-1, -0.33, 0.33, 1):
        cyl(0.16, 5.2, sx * 8.6, fy + 5.6, 0.0, "iron", 8)
    for k in range(5):
        door(-6.0 + k * 3.0, fy + 0.05, 1.2, 2.0, 2.9, "+y", "glass")
    # cornice + attic
    box(25.0, D + 0.8, 0.6, 0, 0, HC + 0.8, "terracotta", 0.04)
    for k in range(13):
        box(0.25, 1.0, 0.55, -11.6 + k * 1.93, fy + 0.3, HC + 0.3, "terracotta", 0.0)
    box(23.0, D - 2.0, 1.6, 0, 0, HC + 1.4, "C", 0.04)
    # big copper dome behind the facade (on a drum)
    dy = -3.0
    cyl(9.4, 3.2, 0, dy, HC + 2.0, "white", 28)
    torus(9.45, 0.18, 0, dy, HC + 2.6, "C", seg=32, mseg=4)
    torus(9.45, 0.18, 0, dy, HC + 4.6, "C", seg=32, mseg=4)
    ribbed_dome(0, dy, HC + 5.2, 9.2, "copper", 12, 0.82)
    cyl(1.6, 2.4, 0, dy, HC + 12.6, "white", 12)
    onion_cap(0, dy, HC + 15.0, 1.9, 3.4, "copper")
    cyl(0.14, 2.6, 0, dy, HC + 18.3, "gold", 6, r2=0.0)
    # --- twin towers flanking the arch
    for sx in (-1, 1):
        tx = sx * 10.5
        ty = fy - 2.0
        box(6.4, 6.4, HC + 6.0, tx, ty, 0.8, "A", 0.05)
        for k in range(3):
            box(6.8, 6.8, 0.4, tx, ty, 6.6 + k * 6.4, "C", 0.03)
        window(tx, ty + 3.2, 2.4, 1.6, 3.0, "+y", frame="C", arched=True)
        window(tx, ty + 3.2, 9.2, 1.4, 3.4, "+y", frame="C")
        window(tx, ty + 3.2, 15.0, 1.4, 3.0, "+y", frame="C")
        oculus(tx, ty + 3.2, 20.8, 1.1)
        # wide flared eave (orange-red), the hallmark of reference 1
        frustum(10.4, 10.4, 7.2, 7.2, HC + 6.4, 0.9, "terracotta")
        box(7.2, 7.2, 0.3, tx, ty, HC + 7.3, "terracotta", 0.0)
        PARTS[-2].location = (tx, ty, 0)
        for sxx in (-1, 1):
            for syy in (-1, 1):
                box(0.3, 0.3, 0.7, tx + sxx * 4.6, ty + syy * 4.6, HC + 5.9, "terracotta", 0.0)
        # open belfry: four corner piers + arches + cap
        bz = HC + 7.6
        for sxx in (-1, 1):
            for syy in (-1, 1):
                box(1.1, 1.1, 4.2, tx + sxx * 2.2, ty + syy * 2.2, bz, "A", 0.04)
        for face in range(4):
            a = face * math.pi / 2
            cx = tx + math.sin(a) * 2.2
            cy = ty + math.cos(a) * 2.2
            torus(1.4, 0.32, cx, cy, bz + 3.0, "C", rot=(math.pi / 2, 0, a), seg=16, mseg=4)
        box(5.8, 5.8, 0.6, tx, ty, bz + 4.2, "C", 0.04)
        frustum(5.4, 5.4, 2.6, 2.6, bz + 4.8, 1.6, "iron")
        PARTS[-1].location = (tx, ty, 0)
        onion_cap(tx, ty, bz + 6.4, 1.3, 2.8, "iron")
        cyl(0.12, 2.2, tx, ty, bz + 9.2, "gold", 6, r2=0.0)
        for sxx in (-1, 1):
            for syy in (-1, 1):
                cyl(0.12, 1.4, tx + sxx * 2.6, ty + syy * 2.6, bz + 4.8, "gold", 6, r2=0.0)
        # clock on tower face
        torus(1.15, 0.12, tx, ty + 3.35, HC + 2.8, "gold", rot=(math.pi / 2, 0, 0), seg=24, mseg=4)
        cyl(1.05, 0.08, tx, ty + 3.3, HC + 2.8, "white", 20, rot=(math.pi / 2, 0, 0))
        PARTS[-1].location = (tx, ty + 3.3, HC + 2.8)
    # --- train shed behind (barrel vault of glass on iron ribs)
    sd = 30.0
    sy0 = -D / 2 - sd / 2 + 1.0
    box(30.0, sd, 0.4, 0, sy0, 0.0, "stone", 0.02)
    for sx in (-1, 1):
        box(1.4, sd, 7.0, sx * 15.0, sy0, 0.0, "brick", 0.04)
        for k in range(6):
            window(sx * 15.7, sy0 - sd / 2 + 2.5 + k * 5.0, 1.8, 2.4, 3.6, "+x" if sx > 0 else "-x", frame="C")
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=15.0, depth=sd, location=(0, sy0, 7.0), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y < -0.01], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    o.scale = (1, 0.55, 1)
    _finish(o, "glass")
    for k in range(7):
        torus(15.0, 0.22, 0, sy0 - sd / 2 + k * sd / 6, 7.0, "iron", rot=(math.pi / 2, 0, 0), seg=32, mseg=4)
        PARTS[-1].scale = (1, 0.55, 1)
    # back gable of the shed: iron fan
    export("grand_station_0", [W, HC, D])


# ======================================================================== cathedral (reference 3 + blue roofs)
def b_cathedral2():
    W, L = 26.0, 62.0
    fy = L / 2
    nave_h, aisle_h = 17.0, 9.0
    box(W + 2.0, L + 2.0, 1.2, 0, -1.0, -0.8, "stone_dark", 0.05)
    # aisles and nave
    for sx in (-1, 1):
        box(6.0, L - 14.0, aisle_h, sx * 8.0, -3.0, 0.4, "A", 0.05)
        frustum(6.4, L - 13.6, 1.0, L - 14.6, aisle_h + 0.4, 2.2, "B")
        PARTS[-1].location = (sx * 8.0, -3.0, 0)
        for k in range(8):
            yy = -3.0 - (L - 14.0) / 2 + 3.0 + k * (L - 20.0) / 7
            window(sx * 11.0, yy, 2.0, 1.4, 4.6, "+x" if sx > 0 else "-x", frame="C")
            box(0.9, 0.9, aisle_h, sx * 11.2, yy - 2.6, 0.4, "C", 0.03)
    box(10.0, L - 14.0, nave_h, 0, -3.0, 0.4, "A", 0.05)
    gable(10.0, L - 14.0, nave_h + 0.4, 5.0, "B", 0.5, "y")
    PARTS[-1].location = (0, -3.0, 0)
    for k in range(8):
        yy = -3.0 - (L - 14.0) / 2 + 3.0 + k * (L - 20.0) / 7
        for sx in (-1, 1):
            window(sx * 5.0, yy, 11.0, 1.2, 3.6, "+x" if sx > 0 else "-x", frame="C")
    # transept
    ty = -14.0
    box(30.0, 9.0, nave_h - 1.0, 0, ty, 0.4, "A", 0.05)
    gable(30.0, 9.0, nave_h - 0.6, 4.6, "B", 0.4, "x")
    PARTS[-1].location = (0, ty, 0)
    for sx in (-1, 1):
        oculus(sx * 15.0, ty, 12.0, 1.6)
        PARTS[-2].rotation_euler = (math.pi / 2, 0, math.pi / 2)
        PARTS[-1].rotation_euler = (math.pi / 2, 0, math.pi / 2)
        PARTS[-2].location = (sx * 15.08, ty, 12.0)
        PARTS[-1].location = (sx * 15.03, ty, 12.0)
        window(sx * 15.0, ty, 2.0, 2.2, 6.0, "+x" if sx > 0 else "-x", frame="C", arched=True)
    # crossing dome (small, ribbed)
    cyl(4.0, 3.0, 0, ty, nave_h + 2.0, "A", 16)
    ribbed_dome(0, ty, nave_h + 5.0, 4.0, "B", 8, 1.1)
    cyl(0.2, 3.0, 0, ty, nave_h + 9.4, "gold", 6, r2=0.0)
    # apse
    ay = -L / 2 + 4.0
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=6.5, depth=nave_h - 3.0, location=(0, ay, 0.4 + (nave_h - 3.0) / 2))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.01], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    _finish(o, "A")
    half_sphere(6.8, 0, ay, nave_h - 2.6, "B", 20, 0.55)
    # front: two bell towers + porch between them
    th = 30.0
    for sx in (-1, 1):
        tx = sx * 9.0
        tyy = fy - 4.5
        box(8.0, 9.0, th, tx, tyy, 0.4, "A", 0.05)
        for k in range(4):
            box(8.5, 9.5, 0.45, tx, tyy, 6.0 + k * 6.2, "C", 0.03)
        window(tx, tyy + 4.5, 7.5, 1.4, 5.0, "+y", frame="C", arched=True)
        window(tx, tyy + 4.5, 15.0, 1.2, 4.0, "+y", frame="C", arched=True)
        window(tx + sx * 4.0, tyy, 15.0, 1.2, 4.0, "+x" if sx > 0 else "-x", frame="C")
        # open belfry
        bz = th + 0.4
        for sxx in (-1, 1):
            for syy in (-1, 1):
                box(1.2, 1.2, 5.2, tx + sxx * 2.9, tyy + syy * 2.9, bz, "A", 0.04)
        for face in range(4):
            ang = face * math.pi / 2
            torus(1.6, 0.3, tx + math.sin(ang) * 2.9, tyy + math.cos(ang) * 2.9, bz + 3.8, "C", rot=(math.pi / 2, 0, ang), seg=16, mseg=4)
        box(8.4, 8.4, 0.5, tx, tyy, bz + 5.2, "C", 0.04)
        # balustrade ring
        balustrade(tx - 3.9, tx + 3.9, tyy + 3.9, bz + 5.7, "white", 0.8)
        balustrade(tx - 3.9, tx + 3.9, tyy - 3.9, bz + 5.7, "white", 0.8)
        # octagonal lantern + ribbed dome + spire
        cyl(2.6, 3.0, tx, tyy, bz + 5.7, "A", 8)
        for k in range(8):
            a = k * math.tau / 8 + math.pi / 8
            box(0.4, 0.4, 3.0, tx + math.cos(a) * 2.6, tyy + math.sin(a) * 2.6, bz + 5.7, "C", 0.0)
        ribbed_dome(tx, tyy, bz + 8.7, 2.8, "B", 8, 1.25)
        cyl(0.22, 4.4, tx, tyy, bz + 12.1, "C", 6, r2=0.0)
        sphere(0.3, tx, tyy, bz + 16.6, "gold", 1)
    # central front between towers: gabled screen, big arched relief + portico columns
    box(10.0, 3.0, 22.0, 0, fy - 1.5, 0.4, "A", 0.05)
    arch_frame(0, fy + 0.2, 8.0, 7.0, 5.0, 1.0, "C", seg=12, thick=0.9)
    box(7.0, 0.3, 5.0, 0, fy + 0.05, 8.0, "C", 0.0)
    half_sphere(3.5, 0, fy - 0.1, 13.0, "C", 16, 1.0)
    PARTS[-1].scale = (1, 0.1, 1)
    oculus(0, fy, 14.0, 2.0)
    # porch: two columns with capitals carrying an entablature
    for sx in (-1, 1):
        cyl(0.55, 6.0, sx * 3.0, fy + 2.0, 0.4, "white", 12, r2=0.5)
        box(1.5, 1.5, 0.4, sx * 3.0, fy + 2.0, 6.4, "C", 0.03)
    box(10.0, 3.2, 1.0, 0, fy + 1.2, 6.8, "C", 0.04)
    door(0, fy + 0.05, 0.4, 3.0, 4.2)
    for sx in (-1, 1):
        door(sx * 9.0, fy + 0.05, 0.4, 1.8, 3.0)
    box(14.0, 4.0, 0.4, 0, fy + 2.4, 0.0, "stone", 0.03)
    box(16.0, 6.0, 0.2, 0, fy + 3.0, -0.2, "stone", 0.03)
    export("cathedral2_0", [W, nave_h, L])


# ======================================================================== tholos (reference 6)
def b_tholos():
    R = 7.0
    for k in range(3):
        cyl(R + 2.4 - k * 0.8, 0.35, 0, 0, k * 0.35, "white", 32)
    z0 = 1.05
    cyl(R + 0.2, 0.3, 0, 0, z0, "stone", 32)
    n = 10
    H = 6.2
    for i in range(n):
        a = i * math.tau / n
        x, y = math.cos(a) * R, math.sin(a) * R
        box(1.3, 1.3, 0.5, x, y, z0 + 0.3, "white", 0.03)
        cyl(0.42, H, x, y, z0 + 0.8, "white", 12, r2=0.37)
        box(1.2, 1.2, 0.4, x, y, z0 + 0.8 + H, "C", 0.03)
    ez = z0 + 1.2 + H
    torus(R, 0.75, 0, 0, ez + 0.4, "white", seg=40, mseg=6)
    PARTS[-1].scale = (1, 1, 0.7)
    torus(R + 0.1, 0.45, 0, 0, ez + 1.15, "C", seg=40, mseg=4)
    # flowering vines on the ring and up some columns
    random.seed(6)
    for i in range(46):
        a = random.random() * math.tau
        rr = R + random.uniform(-0.6, 0.8)
        m = random.choice(["flower_w", "flower_p", "leaf", "leaf2", "flower_w"])
        sphere(random.uniform(0.35, 0.75), math.cos(a) * rr, math.sin(a) * rr, ez + 1.0 + random.uniform(-0.2, 0.7), m, 1)
    for i in range(0, n, 2):
        a = i * math.tau / n
        for k in range(6):
            sphere(random.uniform(0.25, 0.45), math.cos(a) * (R + 0.4), math.sin(a) * (R + 0.4), z0 + 1.0 + k * 1.0, random.choice(["leaf", "flower_p", "leaf2"]), 1)
    # central fountain
    cyl(2.6, 0.7, 0, 0, z0 + 0.3, "white", 24)
    cyl(2.3, 0.1, 0, 0, z0 + 0.85, "water", 24)
    cyl(0.45, 1.4, 0, 0, z0 + 0.3, "white", 12)
    cyl(0.9, 0.3, 0, 0, z0 + 1.7, "white", 16, r2=1.1)
    cyl(0.75, 0.06, 0, 0, z0 + 1.95, "water", 16)
    # inner planting ring
    for i in range(24):
        a = i * math.tau / 24 + 0.1
        sphere(random.uniform(0.35, 0.6), math.cos(a) * 4.4, math.sin(a) * 4.4, z0 + 0.6, random.choice(["leaf", "leaf2", "flower_w", "flower_y", "flower_p"]), 1)
    export("tholos_0", [(R + 2.4) * 2, ez + 1.6, (R + 2.4) * 2])


# ======================================================================== mansard townhouses (references 8/9)
def b_manor(v):
    W, D, H = 10.0, 11.0, 13.5
    random.seed(40 + v)
    fy = D / 2
    box(W + 0.3, D + 0.3, 1.0, 0, 0, -0.9, "stone_dark", 0.04)
    # ground floor: rusticated stone arcade with shop windows
    box(W, D, 3.8, 0, 0, 0, "stone", 0.04)
    for i in range(3):
        x = (i - 1) * 3.2
        if i == 1 and v % 2 == 0:
            door(x, fy, 0.1, 1.5, 2.7)
        else:
            box(2.3, 0.12, 2.6, x, fy + 0.04, 0.4, "glass", 0.0)
            box(2.5, 0.16, 0.2, x, fy + 0.08, 3.0, "C", 0.02)
        cyl(1.25, 0.15, x, fy + 0.06, 3.0, "stone", 12, rot=(math.pi / 2, 0, 0))
        PARTS[-1].location = (x, fy + 0.06, 3.0)
    # awnings (striped colour per variant)
    aw = ["awning_r", "awning_b", "awning_g", "awning_r"][v]
    for i in range(3):
        x = (i - 1) * 3.2
        if i == 1 and v % 2 == 0:
            continue
        v0 = [(x - 1.25, fy + 0.1, 3.35), (x + 1.25, fy + 0.1, 3.35), (x + 1.25, fy + 1.5, 2.6), (x - 1.25, fy + 1.5, 2.6)]
        o = mesh_obj(v0, [(0, 1, 2, 3)], aw)
        o.modifiers.new("s", "SOLIDIFY").thickness = 0.06
    box(W + 0.25, D + 0.25, 0.35, 0, 0, 3.8, "C", 0.03)
    # upper floors: plaster, pilasters at corners, tall windows with iron balconies
    box(W - 0.05, D - 0.05, H - 4.15, 0, 0, 4.15, "A", 0.03)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(0.6, 0.6, H - 4.15, sx * (W / 2 - 0.25), sy * (D / 2 - 0.25), 4.15, "C", 0.02)
    if v == 2:
        # projecting central bay with a small pediment
        box(3.6, 0.6, H - 4.15, 0, fy + 0.25, 4.15, "A", 0.03)
        v1 = [(-2.0, fy + 0.6, H), (2.0, fy + 0.6, H), (0, fy + 0.6, H + 1.4)]
        o = mesh_obj(v1, [(0, 1, 2)], "C")
        o.modifiers.new("s", "SOLIDIFY").thickness = 0.5
    floors = [4.7, 7.9]
    if H > 12.0:
        floors.append(10.9)
    for fi, z in enumerate(floors):
        for i in range(3):
            x = (i - 1) * 3.1
            fy2 = fy + (0.55 if v == 2 and i == 1 else 0.0)
            window(x, fy2, z + 0.2, 1.15, 2.1 if fi < 2 else 1.6, "+y", frame="C", arched=(v == 1 and fi == 0))
            window(x, -fy, z + 0.2, 1.0, 1.8, "-y")
            if fi == 0 or (v == 2 and fi == 1):
                box(1.8, 0.7, 0.12, x, fy2 + 0.35, z, "stone", 0.02)
                box(1.8, 0.05, 0.75, x, fy2 + 0.68, z + 0.1, "iron", 0.0)
        for j in range(3):
            yy = (j - 1) * 3.4
            window(W / 2, yy, z + 0.2, 1.0, 1.8, "+x")
            window(-W / 2, yy, z + 0.2, 1.0, 1.8, "-x")
        box(W + 0.15, D + 0.15, 0.18, 0, 0, z - 0.25, "C", 0.02)
    # cornice
    box(W + 0.6, D + 0.6, 0.35, 0, 0, H - 0.3, "C", 0.04)
    box(W + 0.3, D + 0.3, 0.2, 0, 0, H - 0.5, "C", 0.03)
    # blue slate mansard: steep lower slope + shallow top, dormers with round tops
    frustum(W + 0.4, D + 0.4, W - 1.6, D - 1.6, H + 0.05, 3.0, "B")
    frustum(W - 1.6, D - 1.6, W - 4.4, D - 4.4, H + 3.05, 1.2, "B")
    box(W - 1.5, D - 1.5, 0.12, 0, 0, H + 3.0, "C", 0.0)
    for i in range(3):
        x = (i - 1) * 3.1
        box(1.3, 1.3, 1.6, x, fy - 0.85, H + 0.5, "A", 0.03)
        if v in (0, 3):
            half_sphere(0.72, x, fy - 0.85, H + 2.1, "B", 12, 0.9)
        else:
            gable(1.3, 1.3, H + 2.1, 0.7, "B", 0.12, "y")
            PARTS[-1].location = (x, fy - 0.85, 0)
        window(x, fy - 0.18, H + 0.75, 0.75, 1.05, "+y", arched=(v in (0, 3)))
    # chimneys + roof crest
    for sx in (-1, 1):
        box(0.9, 1.4, 2.6, sx * (W / 2 - 1.6), -1.5, H + 2.4, "brick", 0.03)
        box(1.1, 1.6, 0.2, sx * (W / 2 - 1.6), -1.5, H + 5.0, "stone", 0.02)
        for k in range(2):
            cyl(0.16, 0.45, sx * (W / 2 - 1.6) + (k - 0.5) * 0.45, -1.5, H + 5.2, "terracotta", 8)
    box(W - 4.4, 0.08, 0.35, 0, 0, H + 4.25, "iron", 0.0)
    export("manor_%d" % v, [W, H, D])


def b_corner():
    W, D, H = 12.0, 12.0, 15.0
    fy = D / 2
    box(W + 0.3, D + 0.3, 1.0, 0, 0, -0.9, "stone_dark", 0.04)
    box(W, D, 4.0, 0, 0, 0, "stone", 0.04)
    for i in range(3):
        x = -3.5 + i * 3.0
        box(2.2, 0.12, 2.8, x, fy + 0.04, 0.4, "glass", 0.0)
        v0 = [(x - 1.2, fy + 0.1, 3.5), (x + 1.2, fy + 0.1, 3.5), (x + 1.2, fy + 1.4, 2.8), (x - 1.2, fy + 1.4, 2.8)]
        o = mesh_obj(v0, [(0, 1, 2, 3)], "awning_r")
        o.modifiers.new("s", "SOLIDIFY").thickness = 0.06
    box(W - 0.05, D - 0.05, H - 4.0, 0, 0, 4.0, "A", 0.03)
    for z in (4.6, 8.0, 11.4):
        for i in range(2):
            window(-3.5 + i * 3.0, fy, z + 0.2, 1.1, 2.1, "+y", frame="C")
            window(-W / 2, -2.0 + i * 3.4, z + 0.2, 1.1, 2.0, "-x", frame="C")
            window(W / 2, -2.0 + i * 3.4, z + 0.2, 1.1, 2.0, "+x", frame="C")
        box(W + 0.15, D + 0.15, 0.18, 0, 0, z - 0.25, "C", 0.02)
    box(W + 0.6, D + 0.6, 0.35, 0, 0, H - 0.3, "C", 0.04)
    frustum(W + 0.4, D + 0.4, W - 2.0, D - 2.0, H + 0.05, 3.2, "B")
    # corner turret (front-right)
    tx, ty, r = W / 2 - 1.0, fy - 1.0, 2.6
    cyl(r, H + 2.0, tx, ty, 0.0, "A", 16)
    for z in (5.0, 8.4, 11.8):
        for k in range(3):
            a = -0.4 + k * 0.75
            box(1.0, 0.12, 2.0, tx + math.cos(a) * (r + 0.02), ty + math.sin(a) * (r + 0.02), z, "glass", 0.0, rot=(0, 0, a + math.pi / 2))
            PARTS[-1].location = (tx + math.cos(a) * (r + 0.02), ty + math.sin(a) * (r + 0.02), z + 1.0)
    # green bay window (reference 7)
    box(3.2, 1.2, 7.0, -1.5, fy + 0.6, 5.0, "awning_g", 0.04)
    box(2.6, 0.1, 6.0, -1.5, fy + 1.22, 5.4, "glass", 0.0)
    for k in range(3):
        box(0.12, 0.12, 6.0, -2.7 + k * 1.2, fy + 1.28, 5.4, "awning_g", 0.0)
    gable(3.4, 1.4, 12.0, 1.0, "B", 0.1, "x")
    PARTS[-1].location = (-1.5, fy + 0.6, 0)
    torus(r + 0.1, 0.18, tx, ty, H + 2.0, "C", seg=24, mseg=4)
    onion_cap(tx, ty, H + 2.0, r + 0.25, 4.6, "B")
    cyl(0.12, 2.0, tx, ty, H + 6.5, "gold", 6, r2=0.0)
    for sx in (-1, 1):
        box(0.9, 1.2, 2.4, sx * 3.5, -3.0, H + 2.2, "brick", 0.03)
    door(-4.6, fy, 0.1, 1.4, 2.6)
    export("corner_0", [W, H, D])


# ======================================================================== elevated rail (reference 10)
def b_viaduct():
    L = 12.0
    hgt = 9.0
    # Y-shaped white pier at the segment centre
    box(1.6, 1.6, hgt - 2.2, 0, 0, 0, "concrete", 0.08)
    for sx in (-1, 1):
        box(1.0, 1.4, 3.4, sx * 1.2, 0, hgt - 3.0, "concrete", 0.06, rot=(0, sx * 0.5, 0))
        PARTS[-1].location = (sx * 1.3, 0, hgt - 2.2)
    box(5.4, 2.0, 0.9, 0, 0, hgt - 0.4, "concrete", 0.06)
    for k in range(3):
        box(0.15, 2.05, 0.6, -1.5 + k * 1.5, 0, hgt - 0.3, "concrete", 0.0)
    # two red box girders running along Y
    for sx in (-1, 1):
        box(0.7, L, 1.1, sx * 1.6, 0, hgt + 0.4, "red_steel", 0.04)
        box(0.9, L, 0.12, sx * 1.6, 0, hgt + 1.5, "red_steel", 0.0)
        for k in range(4):
            box(0.06, 0.06, 1.0, sx * 1.6 + sx * 0.36, -L / 2 + 1.5 + k * 3.0, hgt + 0.45, "iron", 0.0)
    # cross ties
    for k in range(6):
        box(3.6, 0.35, 0.3, 0, -L / 2 + 1.0 + k * 2.0, hgt + 1.0, "red_steel", 0.0)
    export("viaduct_0", [5.4, hgt + 1.6, L])


def b_hero_statue():
    for k in range(3):
        cyl(4.2 - k * 0.9, 0.45, 0, 0, k * 0.45, "white", 28)
    cyl(1.5, 3.2, 0, 0, 1.35, "stone", 16)
    cyl(1.8, 0.4, 0, 0, 4.5, "C", 16)
    cyl(1.7, 0.35, 0, 0, 1.35, "C", 16)
    # stylised cloaked figure with raised sword
    z = 4.9
    cyl(0.9, 2.6, 0, 0, z, "bronze", 10, r2=0.55)       # cloak / legs
    cyl(0.55, 1.6, 0, 0, z + 2.6, "bronze", 10, r2=0.5)  # torso
    sphere(0.42, 0, 0, z + 4.6, "bronze", 2)            # head
    box(0.32, 0.32, 1.6, 0.65, 0, z + 3.1, "bronze", 0.03, rot=(0, -0.5, 0))
    PARTS[-1].location = (0.95, 0, z + 3.4)
    box(0.12, 0.12, 2.6, 1.5, 0, z + 4.6, "bronze", 0.0, rot=(0, -0.2, 0))
    box(0.32, 0.32, 1.3, -0.6, 0.2, z + 2.6, "bronze", 0.03, rot=(0.3, 0.4, 0))
    v0 = [(-0.9, -0.3, z + 4.1), (0.9, -0.3, z + 4.1), (1.3, -1.4, z + 0.2), (-1.3, -1.4, z + 0.2)]
    o = mesh_obj(v0, [(0, 1, 2, 3)], "bronze")
    o.modifiers.new("s", "SOLIDIFY").thickness = 0.12
    export("hero_statue_0", [8.4, 12.0, 8.4])


def b_lamp2():
    cyl(0.32, 0.5, 0, 0, 0, "iron", 8)
    cyl(0.13, 4.6, 0, 0, 0.5, "iron", 8, r2=0.09)
    torus(0.22, 0.05, 0, 0, 1.2, "gold", seg=12, mseg=4)
    for sx in (-1, 1):
        box(1.3, 0.08, 0.08, sx * 0.6, 0, 4.4, "iron", 0.0)
        cyl(0.05, 0.4, sx * 1.15, 0, 4.05, "iron", 6)
        cyl(0.26, 0.6, sx * 1.15, 0, 3.55, "lamp", 6, r2=0.18)
        cyl(0.3, 0.25, sx * 1.15, 0, 4.15, "iron", 6, r2=0.05)
    sphere(0.14, 0, 0, 5.15, "gold", 1)
    export("lamp2_0", [2.6, 5.2, 0.6])


def b_palm():
    random.seed(9)
    segs = 7
    x = y = 0.0
    z = 0.0
    lean = 0.12
    for i in range(segs):
        r = 0.32 - i * 0.025
        cyl(r, 1.15, x, y, z, "trunk", 8, r2=r - 0.03)
        torus(r, 0.06, x, y, z + 1.1, "trunk", seg=10, mseg=4)
        x += lean * (i * 0.25)
        z += 1.1
    sphere(0.45, x, y, z, "trunk", 1)
    for k in range(9):
        a = k * math.tau / 9 + random.uniform(-0.1, 0.1)
        L = random.uniform(3.2, 4.0)
        dx, dy = math.cos(a), math.sin(a)
        verts = [(x, y, z + 0.1), (x + dx * L * 0.5 - dy * 0.55, y + dy * L * 0.5 + dx * 0.55, z + 0.5),
                 (x + dx * L, y + dy * L, z - 1.1), (x + dx * L * 0.5 + dy * 0.55, y + dy * L * 0.5 - dx * 0.55, z + 0.5)]
        o = mesh_obj(verts, [(0, 1, 2, 3)], random.choice(["leaf", "leaf2"]))
        o.modifiers.new("s", "SOLIDIFY").thickness = 0.05
    for k in range(3):
        sphere(0.2, x + 0.25 * math.cos(k * 2.1), y + 0.25 * math.sin(k * 2.1), z - 0.3, "trunk", 1)
    export("palm_0", [4.0, 8.0, 4.0])


def b_gable(v):
    """manor_4: 窄高山墙住宅（荷兰阶梯山墙 + 顶部钟形窗，参考图 7 Corner Apartment）
       manor_5: 红砖立面 + 白色石饰 + 铜绿屋顶的公寓"""
    W, D, H = 10.0, 11.0, 13.5
    fy = D / 2
    box(W + 0.3, D + 0.3, 1.0, 0, 0, -0.9, "stone_dark", 0.04)
    box(W, D, 3.6, 0, 0, 0, "stone", 0.04)
    for i in range(2):
        x = -2.3 + i * 4.6
        box(2.8, 0.12, 2.6, x, fy + 0.04, 0.4, "glass", 0.0)
        cyl(1.4, 0.15, x, fy + 0.06, 3.0, "stone", 12, rot=(math.pi / 2, 0, 0))
        PARTS[-1].location = (x, fy + 0.06, 3.0)
        v0 = [(x - 1.5, fy + 0.1, 3.3), (x + 1.5, fy + 0.1, 3.3), (x + 1.5, fy + 1.5, 2.6), (x - 1.5, fy + 1.5, 2.6)]
        o = mesh_obj(v0, [(0, 1, 2, 3)], "awning_b" if v == 4 else "awning_g")
        o.modifiers.new("s", "SOLIDIFY").thickness = 0.06
    door(0, fy, 0.1, 1.2, 2.6)
    wall = "A" if v == 4 else "brick"
    box(W - 0.05, D - 0.05, H - 3.6, 0, 0, 3.6, wall, 0.03)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(0.7, 0.7, H - 3.6, sx * (W / 2 - 0.3), sy * (D / 2 - 0.3), 3.6, "C", 0.02)
    for z in (4.3, 7.4, 10.5):
        box(W + 0.2, D + 0.2, 0.2, 0, 0, z - 0.3, "C", 0.02)
        for i in range(3):
            x = (i - 1) * 3.0
            window(x, fy, z, 1.1, 2.1, "+y", frame="C", arched=(v == 5))
            window(x, -fy, z, 1.0, 1.8, "-y")
        for j in range(3):
            window(W / 2, (j - 1) * 3.4, z, 1.0, 1.8, "+x")
            window(-W / 2, (j - 1) * 3.4, z, 1.0, 1.8, "-x")
    if v == 4:
        # 阶梯山墙（立面朝 +Y）+ 坡屋顶沿 Y
        gable(W, D, H, 5.0, "B", 0.3, "y")
        steps = [(W, 0.0), (W * 0.78, 1.2), (W * 0.56, 2.4), (W * 0.34, 3.6), (W * 0.14, 4.8)]
        for (w, z) in steps:
            box(w, 0.6, 1.25, 0, fy - 0.25, H + z, "A", 0.03)
            box(w + 0.3, 0.75, 0.18, 0, fy - 0.25, H + z + 1.2, "C", 0.02)
        window(0, fy + 0.05, H + 1.5, 1.2, 1.6, "+y", frame="C", arched=True)
        oculus(0, fy + 0.05, H + 4.0, 0.45)
        sphere(0.3, 0, fy - 0.25, H + 6.4, "gold", 1)
    else:
        box(W + 0.6, D + 0.6, 0.4, 0, 0, H - 0.3, "white", 0.04)
        frustum(W + 0.3, D + 0.3, W - 3.0, D - 3.0, H + 0.1, 3.6, "copper")
        for i in range(3):
            x = (i - 1) * 3.0
            box(1.2, 1.2, 1.4, x, fy - 0.9, H + 0.4, "white", 0.03)
            half_sphere(0.66, x, fy - 0.9, H + 1.8, "copper", 12, 0.9)
            window(x, fy - 0.28, H + 0.6, 0.7, 1.0, "+y", arched=True)
        cyl(0.12, 1.8, 0, 0, H + 3.7, "gold", 6, r2=0.0)
    for sx in (-1, 1):
        box(0.9, 1.3, 2.4, sx * (W / 2 - 1.4), -2.0, H + 2.0, "brick", 0.03)
    export("manor_%d" % v, [W, H, D])


CITY2_BUILDERS = {
    "grand_station_0": b_grand_station, "cathedral2_0": b_cathedral2, "tholos_0": b_tholos,
    "manor_0": lambda: b_manor(0), "manor_1": lambda: b_manor(1), "manor_2": lambda: b_manor(2), "manor_3": lambda: b_manor(3), "manor_4": lambda: b_gable(4), "manor_5": lambda: b_gable(5),
    "corner_0": b_corner, "viaduct_0": b_viaduct, "hero_statue_0": b_hero_statue, "lamp2_0": b_lamp2, "palm_0": b_palm,
}
for _o in list(bpy.data.objects):
    bpy.data.objects.remove(_o, do_unlink=True)
for _m in list(bpy.data.materials):
    bpy.data.materials.remove(_m)
_mats.clear()
run_builders(CITY2_BUILDERS)
