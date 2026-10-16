# Batch 5: landmarks and large special buildings of Solenne (晴岚港) + city gate, station, airship, ships.
# Run: blender -b --factory-startup --python tools/blender/build_landmarks.py -- <out_dir> [names]
# Size semantics match src/world/landmark.gd so ModelProp can scale them the same way.
# Animated pieces (rune rings, light beam, portal ring, steam, smoke) are added by ModelProp at runtime.
import bpy, os, sys, math, random
_LIB_ONLY = True
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "build_models.py"), encoding="utf-8").read())
COLORS.update({"glow": "9ae8ff", "white": "f4f2ec", "beige": "e8dcc4", "sea": "2f6fa8", "dark": "3a3a48"})


def sphere(r, x, y, z, m, sub=2, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, m)


def half_sphere(r, x, y, z, m, seg=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=max(6, seg // 2), radius=r, location=(x, y, z))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    return _finish(o, m)


def torus(R, r, x, y, z, m, rot=(0, 0, 0), seg=32):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=6, location=(x, y, z), rotation=rot)
    return _finish(bpy.context.active_object, m)


def spire(x, y, z, r, h, m, sides=8):
    cyl(r, h, x, y, z, m, sides, r2=0.0)
    sphere(max(0.25, r * 0.12), x, y, z + h + 0.2, "gold", 1)


def dome(x, y, z, r, m, lantern=True):
    cyl(r * 1.02, r * 0.35, x, y, z, "white", 24)
    half_sphere(r, x, y, z + r * 0.35, m)
    for i in range(4):
        torus(r * 1.0, 0.08, x, y, z + r * 0.35, "gold", rot=(math.pi / 2, 0, i * math.pi / 4))
    if lantern:
        cyl(r * 0.18, r * 0.4, x, y, z + r * 1.32, "white", 12)
        half_sphere(r * 0.2, x, y, z + r * 1.72, m, 12)
        sphere(max(0.25, r * 0.06), x, y, z + r * 1.98, "gold", 1)


def colonnade(cx, y, w, h, n, z0=0.0, r=0.45, m="white"):
    for i in range(n):
        x = cx - w / 2 + (i + 0.5) * w / n
        cyl(r, h, x, y, z0, m, 12, r2=r * 0.92)
        box(r * 2.6, r * 2.6, 0.35, x, y, z0, "stone", 0.02)
        box(r * 2.6, r * 2.6, 0.35, x, y, z0 + h - 0.35, "stone", 0.02)


def pediment(w, y, z, depth=2.0, m="white"):
    v = [(-w / 2, y - depth / 2, z), (w / 2, y - depth / 2, z), (0, y - depth / 2, z + w * 0.22),
         (-w / 2, y + depth / 2, z), (w / 2, y + depth / 2, z), (0, y + depth / 2, z + w * 0.22)]
    mesh_obj(v, [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], m)
    box(w + 0.4, depth + 0.2, 0.5, 0, y, z - 0.5, "stone", 0.02)


def win_row(y, w, z, n, ww=1.1, wh=1.8, facing="+y", arched=False):
    for i in range(n):
        window(-w / 2 + (i + 0.5) * w / n, y, z, ww, wh, facing, arched=arched)


def side_wins(w, d, z, n, ww=1.1, wh=1.8):
    for j in range(n):
        yy = -d / 2 + (j + 0.5) * d / n
        window(w / 2, yy, z, ww, wh, "+x")
        window(-w / 2, yy, z, ww, wh, "-x")


# ---------------------------------------------------------------- goddess (height 40, scaled uniformly by height in game)
def b_goddess():
    s = 1.0
    for i in range(3):
        r = 9.0 - i * 2.2
        cyl(r, 3.0, 0, 0, i * 3.0, "stone", 8, r2=r * 0.94)
    for i in range(8):
        a = i * math.tau / 8 + math.pi / 8
        cyl(0.25, 1.6, math.cos(a) * 8.2, math.sin(a) * 8.2, 9.0, "gold", 8)
    b = 9.0
    cyl(4.0, 12.0, 0, 0, b, "C", 16, r2=2.2)
    cyl(2.2, 6.0, 0, 0, b + 12.0, "C", 16, r2=1.6)
    sphere(1.25, 0, 0, b + 19.4, "C", 2)
    cyl(1.0, 5.0, 0, -0.6, b + 16.0, "C", 12, r2=0.7)
    torus(1.2, 0.13, 0, 0, b + 20.3, "gold", rot=(0.17, 0, 0))
    for sx in (-1, 1):
        for k in range(3):
            v = [(0, 0, 0), (sx * 5.5, 0, 2.0 - k * 0.8), (sx * 4.0, 0, -4.0 + k * 0.6)]
            o = mesh_obj(v, [(0, 1, 2)], "white" if k < 2 else "sea")
            o.modifiers.new("s", "SOLIDIFY").thickness = 0.35
            o.location = (sx * (1.0 + k * 0.5), -1.2, b + 15.5 - k * 0.8)
    cyl(0.45, 6.5, 1.9, 0.3, b + 17.0, "C", 8, rot=(0.14, 0.38, 0))
    cyl(0.9, 2.2, 3.1, 0.5, b + 23.5, "glow", 6, r2=0.0)
    cyl(0.0, 1.4, 3.1, 0.5, b + 22.1, "glow", 6, r2=0.9)
    cyl(0.42, 4.5, -1.9, 0.9, b + 12.0, "C", 8, rot=(-0.7, -0.45, 0))
    torus(1.05, 0.15, -2.6, 2.4, b + 13.6, "gold", rot=(1.2, 0, 0))
    export("goddess_0", [1.0, 40.0, 1.0])


def b_beacon():
    R, H = 3.0, 30.0
    cyl(R * 2.0, 4.0, 0, 0, -2.0, "stone_dark", 10, r2=R * 2.3)
    seg = 5
    for i in range(seg):
        z0 = 2.0 + i * (H - 2.0) / seg
        r0 = R - (R * 0.28) * i / seg
        r1 = R - (R * 0.28) * (i + 1) / seg
        cyl(r0, (H - 2.0) / seg, 0, 0, z0, "white" if i % 2 == 0 else "B", 16, r2=r1)
        window(0, r0 * 0.95, z0 + (H - 2.0) / seg * 0.5, 0.7, 1.2, "+y")
    cyl(R * 1.15, 0.6, 0, 0, H, "dark", 16, r2=R)
    torus(R * 1.1, 0.12, 0, 0, H + 1.2, "dark")
    for i in range(8):
        a = i * math.tau / 8
        box(0.08, 0.08, 1.2, math.cos(a) * R * 1.1, math.sin(a) * R * 1.1, H + 0.6, "dark", 0.0)
    cyl(R * 0.6, 3.0, 0, 0, H + 0.6, "glow", 12)
    dome(0, 0, H + 3.6, R * 0.68, "B", lantern=False)
    door(0, R, 0, 1.4, 2.4)
    export("beacon_0", [6.0, 30.0, 6.0])


def b_clock_spire():
    W, H = 10.0, 34.0
    box(W + 2.0, W + 2.0, 5.5, 0, 0, -2.5, "stone", 0.05)
    box(W, W, H, 0, 0, 0, "beige", 0.04)
    box(W * 0.96, W * 0.96, W * 0.9, 0, 0, H, "beige", 0.03)
    for f in range(1, int(H / 6)):
        box(W + 0.3, W + 0.3, 0.3, 0, 0, 4.0 + f * 6.0, "C", 0.02)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(1.0, 1.0, H + W * 0.9 + 2.0, sx * W / 2, sy * W / 2, 0, "white", 0.03)
            spire(sx * W / 2, sy * W / 2, H + W * 0.9 + 2.0, 0.7, 3.0, "B", 4)
    for (dx, dy, rz) in [(0, 1, 0), (0, -1, math.pi), (1, 0, -math.pi / 2), (-1, 0, math.pi / 2)]:
        c = (dx * (W / 2 + 0.12), dy * (W / 2 + 0.12), H - W * 0.3)
        cyl(W * 0.36, 0.3, 0, 0, 0, "cloth", 32, rot=(math.pi / 2, 0, rz))
        PARTS[-1].location = c
        torus(W * 0.37, 0.25, c[0] + dx * 0.05, c[1] + dy * 0.05, c[2], "gold", rot=(math.pi / 2, 0, rz))
        box(0.18 if dy else 0.12, 0.12 if dy else 0.18, W * 0.26, c[0] + dx * 0.2, c[1] + dy * 0.2, c[2], "dark", 0.0)
        box(W * 0.55 if dy else 0.2, 0.2 if dy else W * 0.55, W * 0.62, dx * (W * 0.48 + 0.02), dy * (W * 0.48 + 0.02), H + 0.15, "dark", 0.0)
    box(W + 0.8, W + 0.8, 0.6, 0, 0, H + W * 0.9, "stone", 0.03)
    spire(0, 0, H + W * 0.9 + 0.6, W * 0.62, H * 0.45, "B", 4)
    door(0, W / 2 + 1.0, 0, 2.0, 3.2)
    export("clock_spire_0", [W, H, W])


def b_cathedral():
    W, H, D = 36.0, 22.0, 64.0
    box(W, D, 3.0, 0, 0, -2.5, "stone", 0.05)
    box(W * 0.5, D, H, 0, 0, 0, "A", 0.03)
    gable(W * 0.5, D, H, W * 0.28, "B", 0.3, "y")
    for sx in (-1, 1):
        box(W * 0.25, D * 0.92, H * 0.55, sx * W * 0.375, 0, 0, "beige", 0.03)
        v = [(0, -D * 0.46, 0), (0, D * 0.46, 0), (sx * W * 0.13, D * 0.46, -H * 0.12), (sx * W * 0.13, -D * 0.46, -H * 0.12)]
        o = mesh_obj(v, [(0, 1, 2, 3)], "B")
        o.modifiers.new("s", "SOLIDIFY").thickness = 0.3
        o.location = (sx * W * 0.25, 0, H * 0.67)
        for i in range(int(D / 7)):
            y = -D / 2 + 4.0 + i * 7.0
            box(1.0, 1.4, H * 0.62, sx * W / 2, y, 0, "stone", 0.03)
            box(W * 0.26, 0.9, 0.7, sx * W * 0.37, y, H * 0.72, "stone", 0.0, rot=(0, sx * 0.49, 0))
            spire(sx * W / 2, y, H * 0.62, 0.6, 2.4, "B", 4)
            window(sx * (W * 0.25), y + 3.5, H * 0.75, 1.4, H * 0.18, "+x" if sx > 0 else "-x", arched=True)
            window(sx * (W * 0.5), y + 3.5, H * 0.2, 1.2, H * 0.2, "+x" if sx > 0 else "-x", arched=True)
    box(W * 1.25, W * 0.35, H * 0.9, 0, -D * 0.12, 0, "A", 0.03)
    gable(W * 1.25, W * 0.35, H * 0.9, W * 0.25, "B", 0.2, "x")
    PARTS[-1].location.y = -D * 0.12
    cyl(W * 0.2, H * 0.35, 0, -D * 0.12, H, "white", 16)
    dome(0, -D * 0.12, H * 1.3, W * 0.21, "B")
    cyl(W * 0.25, H * 0.85, 0, -D / 2, 0, "A", 16)
    half_sphere(W * 0.25, 0, -D / 2, H * 0.85, "B", 16)
    tw, th = W * 0.26, H * 1.75
    fy = D / 2 + tw * 0.4
    for sx in (-1, 1):
        tx = sx * (W / 2 - tw / 2)
        box(tw, tw, th, tx, fy, 0, "A", 0.03)
        for k in range(3):
            window(tx, fy + tw / 2, th * (0.35 + k * 0.22), tw * 0.32, th * 0.1, "+y", arched=True)
        box(tw + 0.6, tw + 0.6, 0.6, tx, fy, th, "stone", 0.03)
        for qx in (-1, 1):
            for qy in (-1, 1):
                spire(tx + qx * tw * 0.42, fy + qy * tw * 0.42, th + 0.6, 0.5, 3.0, "B", 4)
        spire(tx, fy, th + 0.6, tw * 0.5, th * 0.5, "B", 8)
    gw = W - tw * 2.0
    box(gw, tw * 0.6, H * 1.05, 0, fy - tw * 0.2, 0, "A", 0.03)
    v = [(-gw / 2, 0, 0), (gw / 2, 0, 0), (0, 0, H * 0.3)]
    o = mesh_obj(v, [(0, 1, 2)], "A")
    o.modifiers.new("s", "SOLIDIFY").thickness = tw * 0.6
    o.location = (0, fy - tw * 0.2 + tw * 0.3, H * 1.05)
    ry = fy - tw * 0.2 + tw * 0.3 + 0.08
    cyl(W * 0.13, 0.2, 0, 0, 0, "glass", 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, ry, H * 0.72)
    torus(W * 0.14, 0.4, 0, ry + 0.05, H * 0.72, "gold", rot=(math.pi / 2, 0, 0))
    for k in range(4):
        box(0.15, 0.1, W * 0.25, 0, ry + 0.1, H * 0.72 - W * 0.125, "gold", 0.0, rot=(0, k * math.pi / 4, 0))
        PARTS[-1].location = (0, ry + 0.1, H * 0.72)
    for i in range(3):
        x = (i - 1) * gw * 0.32
        dw = 3.2 if i == 1 else 2.2
        door(x, ry - 0.1, 0, dw, dw * 1.7, m="door")
    box(W * 0.9, 6.0, 0.6, 0, fy + tw * 0.5 + 3.0, 0, "stone", 0.03)
    export("cathedral_0", [W, H, D])


def b_civic_hall():
    W, H, D = 64.0, 14.0, 30.0
    box(W, D, 4.1, 0, 0, -2.5, "stone", 0.05)
    cw = W * 0.36
    box(cw, D, H, 0, 0, 1.6, "A", 0.03)
    for sx in (-1, 1):
        wx = sx * (cw / 2 + (W - cw) / 4)
        box((W - cw) / 2, D * 0.86, H * 0.82, wx, 0, 1.6, "beige", 0.03)
        frustum((W - cw) / 2, D * 0.86, (W - cw) / 2 * 0.7, D * 0.5, 1.6 + H * 0.82, 3.2, "B")
        PARTS[-1].location.x = wx
        for f in range(2):
            for i in range(5):
                x = wx - (W - cw) / 4 + (i + 0.5) * (W - cw) / 10
                window(x, D * 0.43, 3.8 + f * H * 0.38, 1.2, 2.0, "+y", arched=True)
        cyl(1.8, 3.0, sx * W / 2, D * 0.43, 1.6 + H * 0.82, "white", 12)
        dome(sx * W / 2, D * 0.43, 1.6 + H * 0.82 + 3.0, 1.9, "B")
    box(W + 0.6, D + 0.6, 0.6, 0, 0, 1.6 + H * 0.82, "stone", 0.02)
    top = 1.6 + H
    box(cw + 0.6, D + 0.6, 0.7, 0, 0, top, "stone", 0.02)
    cyl(cw * 0.36, H * 0.4, 0, 0, top + 0.7, "white", 24, r2=cw * 0.34)
    for i in range(12):
        a = i * math.tau / 12
        cyl(0.3, H * 0.36, math.cos(a) * cw * 0.37, math.sin(a) * cw * 0.37, top + 0.7, "white", 8)
    dome(0, 0, top + 0.7 + H * 0.4, cw * 0.38, "B")
    py = D / 2 + 4.0
    box(cw + 4.0, 8.0, 1.6, 0, py, 0, "stone", 0.03)
    colonnade(0, py + 2.5, cw + 2.0, H * 0.8, 8, 1.6, 0.6)
    box(cw + 3.0, 7.0, 1.2, 0, py - 0.5, 1.6 + H * 0.8, "white", 0.02)
    pediment(cw + 3.0, py - 0.5, 1.6 + H * 0.8 + 1.7, 7.0)
    cyl(1.2, 0.3, 0, 0, 0, "gold", 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, py + 3.1, 1.6 + H * 0.8 + 3.5)
    for k in range(6):
        box(cw + 6.0 - k * 0.3, 0.9, 0.27, 0, py + 4.0 + (5 - k) * 0.9, k * 0.27, "stone", 0.02)
    door(0, D / 2, 1.6, 3.0, 4.6)
    export("civic_hall_0", [W, H, D])


def b_opera():
    W, H, D = 44.0, 18.0, 40.0
    box(W, D, 3.0, 0, 0, -2.5, "stone", 0.05)
    box(W, D, H, 0, 0, 0, "A", 0.03)
    box(W + 0.6, D + 0.6, 0.8, 0, 0, H, "stone", 0.02)
    for i in range(7):
        x = -W * 0.42 + i * W * 0.14
        box(1.2, 2.4, H * 0.38, x, D / 2 + 1.2, 0, "beige", 0.03)
        if i < 6:
            window(x + W * 0.07, D / 2, H * 0.08, W * 0.08, H * 0.2, "+y", arched=True)
    box(W * 0.9, 2.6, 1.0, 0, D / 2 + 1.2, H * 0.38, "stone", 0.02)
    colonnade(0, D / 2 + 0.8, W * 0.84, H * 0.42, 12, H * 0.38 + 1.0, 0.42)
    win_row(D / 2, W * 0.8, H * 0.55, 6, 1.6, H * 0.25, arched=True)
    for sx in (-1, 1):
        cyl(1.0, 2.6, sx * W * 0.42, D * 0.45, H + 0.8, "white", 10, r2=0.6)
        v = [(0, 0, 0), (sx * 2.4, 0, 1.0), (sx * 0.4, 0, 2.2)]
        o = mesh_obj(v, [(0, 1, 2)], "gold")
        o.modifiers.new("s", "SOLIDIFY").thickness = 0.2
        o.location = (sx * W * 0.42, D * 0.45, H + 3.0)
    torus(1.6, 0.2, 0, D / 2, H + 2.2, "gold", rot=(math.pi / 2, 0, 0))
    dome(0, 0, H + 0.8, min(W, D) * 0.32, "B")
    box(W * 0.6, D * 0.25, H * 0.5, 0, -D * 0.33, H, "beige", 0.03)
    gable(W * 0.6, D * 0.25, H * 1.5, W * 0.15, "B", 0.3, "x")
    PARTS[-1].location.y = -D * 0.33
    side_wins(W, D, H * 0.45, int(D / 4.0), 1.1, 2.4)
    door(0, D / 2 + 2.45, 0, 3.0, 4.0, m="red")
    for k in range(4):
        box(W * 0.8, 1.0, 0.3, 0, D / 2 + 3.0 + (3 - k) * 1.0, k * 0.3, "stone", 0.02)
    export("opera_0", [W, H, D])


def b_mage_tower():
    W, H = 12.0, 56.0
    box(W * 2.2, W * 1.8, 2.6, 0, -W * 0.6, -2.0, "stone", 0.05)
    box(W * 2.2, W * 1.8, H * 0.16, 0, -W * 0.6, 0, "beige", 0.03)
    frustum(W * 2.2, W * 1.8, W * 1.4, W * 1.0, H * 0.16, 3.0, "B")
    PARTS[-1].location.y = -W * 0.6
    seg = 4
    for i in range(seg):
        z0 = i * H * 0.8 / seg
        r0 = W * 0.5 - W * 0.2 * i / seg
        r1 = W * 0.5 - W * 0.2 * (i + 1) / seg
        cyl(r0, H * 0.8 / seg, 0, 0, z0, "A", 8, r2=r1, rot=(0, 0, math.pi / 8))
        cyl(r1 * 1.12, 0.5, 0, 0, z0 + H * 0.8 / seg - 0.25, "B", 8, rot=(0, 0, math.pi / 8))
        for (dx, dy, f) in [(0, 1, "+y"), (0, -1, "-y"), (1, 0, "+x"), (-1, 0, "-x")]:
            window(dx * r0 * 0.93, dy * r0 * 0.93, z0 + H * 0.8 / seg * 0.4, 0.9, 1.8, f, arched=True)
    top = H * 0.8
    cyl(W * 0.45, 1.2, 0, 0, top, "stone", 8, r2=W * 0.3, rot=(0, 0, math.pi / 8))
    spire(0, 0, top + 1.2, W * 0.42, H * 0.2, "B", 8)
    cz = top + H * 0.2 + 4.0
    cyl(1.2, 3.0, 0, 0, cz, "glow", 6, r2=0.0)
    cyl(0.0, 2.0, 0, 0, cz - 2.0, "glow", 6, r2=1.2)
    door(0, W * 0.5, 0, 1.8, 3.2)
    export("mage_tower_0", [W, H, W])


def b_rotunda():
    R, H = 15.0, 12.0
    cyl(R + 2.0, 1.6, 0, 0, 0, "stone", 32, r2=R + 2.0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=32, radius=R * 0.82, depth=H, end_fill_type="NOTHING", location=(0, 0, 1.6 + H / 2))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().y > R * 0.7], context="FACES")
    bm.to_mesh(o.data); bm.free()
    o.modifiers.new("s", "SOLIDIFY").thickness = 0.6
    _finish(o, "A")
    for i in range(16):
        a = i * math.tau / 16
        if abs(math.sin(a) - 1.0) < 0.05:
            continue
        cyl(0.5, H, math.cos(a) * R, math.sin(a) * R, 1.6, "white", 10, r2=0.46)
    torus(R * 1.0, 0.7, 0, 0, 1.6 + H, "stone", seg=40)
    half_sphere(R * 0.85, 0, 0, 1.6 + H + 0.4, "glass", 24)
    for i in range(4):
        torus(R * 0.86, 0.12, 0, 0, 1.6 + H + 0.4, "gold", rot=(math.pi / 2, 0, i * math.pi / 4))
    sphere(1.0, 0, 0, 1.6 + H + R * 0.85 + 0.6, "gold", 1)
    cyl(R * 0.4, 0.6, 0, 0, 1.6, "dark", 24, r2=R * 0.45)
    export("rotunda_0", [R * 2, H, R * 2])


def b_bathhouse():
    W, H, D = 36.0, 9.0, 20.0
    box(W, D, 3.0, 0, 0, -2.5, "stone", 0.05)
    box(W, D, H, 0, 0, 0, "A", 0.03)
    box(W + 0.5, D + 0.5, 0.6, 0, 0, H, "stone", 0.02)
    for i in range(3):
        rr = min(W * 0.15, D * 0.35) * (1.3 if i == 1 else 1.0)
        dome((i - 1) * W * 0.32, 0, H + 0.3, rr, "B", lantern=(i == 1))
    win_row(D / 2, W * 0.9, H * 0.25, int(W / 3.5), 1.4, H * 0.45, arched=True)
    side_wins(W, D, H * 0.25, int(D / 4.0), 1.4, H * 0.45)
    colonnade(0, D / 2 + 1.6, W * 0.4, H * 0.85, 6, 0.0, 0.45)
    box(W * 0.44, 3.4, 0.8, 0, D / 2 + 1.4, H * 0.85, "white", 0.02)
    door(0, D / 2, 0, 2.6, 3.6)
    export("bathhouse_0", [W, H, D])


def b_hospital():
    W, H, D = 40.0, 12.0, 24.0
    box(W, D, 3.0, 0, 0, -2.5, "stone", 0.05)
    box(W * 0.4, D * 0.5, H, 0, 0, 0, "A", 0.03)
    frustum(W * 0.4 + 0.8, D * 0.5 + 0.8, W * 0.15, D * 0.1, H, H * 0.3, "B")
    for sx in (-1, 1):
        box(W * 0.3, D, H * 0.85, sx * W * 0.35, 0, 0, "beige", 0.03)
        gable(W * 0.3, D, H * 0.85, W * 0.12, "B", 0.4, "y")
        PARTS[-1].location.x = sx * W * 0.35
        for f in range(2):
            for i in range(3):
                window(sx * W * 0.35 + (i - 1) * W * 0.08, D / 2, 2.0 + f * H * 0.38, 1.0, 1.6, "+y")
    for f in range(2):
        win_row(D * 0.25, W * 0.36, 2.0 + f * H * 0.38, 4)
    cyl(1.8, 0.2, 0, 0, 0, "white", 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, D * 0.25 + 0.15, H * 0.8)
    box(0.7, 0.12, 2.4, 0, D * 0.25 + 0.3, H * 0.8 - 1.2, "B", 0.0)
    box(2.4, 0.12, 0.7, 0, D * 0.25 + 0.3, H * 0.8 - 0.35, "B", 0.0)
    box(W * 0.3, 4.0, 0.3, 0, D * 0.25 + 2.0, 3.6, "B", 0.02)
    for sx in (-1, 1):
        cyl(0.18, 3.6, sx * W * 0.13, D * 0.25 + 3.8, 0, "white", 8)
    door(0, D * 0.25, 0, 2.6, 3.0)
    export("hospital_0", [W, H, D])


def b_warehouse():
    W, H, D = 18.0, 10.0, 28.0
    box(W, D, 3.0, 0, 0, -2.5, "stone", 0.05)
    box(W, D, H, 0, 0, 0, "A", 0.03)
    gable(W, D, H, W * 0.35, "B", 0.5, "y")
    for i in range(int(D / 5)):
        y = -D / 2 + 2.5 + i * 5.0
        for sx in (-1, 1):
            box(0.6, 0.8, H, sx * (W / 2 + 0.2), y, 0, "C", 0.02)
            window(sx * W / 2, y + 2.5, H * 0.7, 1.4, 1.0, "+x" if sx > 0 else "-x")
    box(W * 0.55, 0.2, H * 0.7, 0, D / 2 + 0.1, 0, "wood_dark", 0.0)
    for k in range(5):
        box(W * 0.55, 0.24, 0.1, 0, D / 2 + 0.12, 0.4 + H * 0.14 * k, "door", 0.0)
    box(W * 0.8, 3.0, 1.0, 0, D / 2 + 1.5, 0, "stone", 0.03)
    export("warehouse_0", [W, H, D])


def b_terminal():
    W, H, D = 30.0, 12.0, 36.0
    box(W, D, 3.0, 0, 0, -2.5, "stone", 0.05)
    box(W, D * 0.35, H, 0, D * 0.325, 0, "A", 0.03)
    box(W + 0.5, D * 0.35 + 0.5, 0.6, 0, D * 0.325, H, "stone", 0.02)
    win_row(D / 2, W * 0.9, H * 0.25, int(W / 3.2), 1.4, H * 0.5, arched=True)
    cyl(2.0, 0.3, 0, 0, 0, "cloth", 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, D / 2 + 0.2, H + 2.2)
    torus(2.0, 0.2, 0, D / 2 + 0.3, H + 2.2, "gold", rot=(math.pi / 2, 0, 0))
    for sx in (-1, 1):
        box(1.0, D * 0.65, H * 0.7, sx * W * 0.48, -D * 0.175, 0, "dark", 0.0)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=W * 0.47, depth=D * 0.65, location=(0, -D * 0.175, H * 0.7), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.01], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    _finish(o, "glass")
    box(W * 0.8, 8.0, 0.25, 0, -D / 2 - 4.0, 4.0, "B", 0.0)
    door(0, D / 2, 0, 3.0, 4.0)
    export("terminal_0", [W, H, D])


def b_market_hall():
    W, H, D = 24.0, 10.0, 40.0
    box(W, D, 3.0, 0, 0, -2.5, "stone", 0.05)
    for sx in (-1, 1):
        box(1.0, D, H, sx * W / 2, 0, 0, "A", 0.03)
        for i in range(int(D / 4)):
            window(sx * W / 2, -D / 2 + 2.0 + i * 4.0, H * 0.2, 2.0, H * 0.5, "+x" if sx > 0 else "-x", arched=True)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=W * 0.49, depth=D, location=(0, 0, H), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.01], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    _finish(o, "glass")
    for i in range(int(D / 4) + 1):
        torus(W * 0.49, 0.18, 0, -D / 2 + i * 4.0, H, "dark", rot=(math.pi / 2, 0, 0))
    box(W * 0.9, 1.0, H * 1.2, 0, D / 2, 0, "A", 0.03)
    cyl(W * 0.3, 0.3, 0, 0, 0, "glass", 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, D / 2 + 0.55, H * 1.05)
    door(0, D / 2 + 0.5, 0, 3.6, 5.0)
    export("market_hall_0", [W, H, D])


def b_culvert():
    W, H, L = 6.0, 10.0, 18.0
    box(L, 3.0, H, 0, 0, 0, "A", 0.03)
    box(L + 0.4, 3.4, 0.6, 0, 0, H, "stone", 0.02)
    cyl(W * 0.5, 3.2, 0, 0, 0, "dark", 20, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, 1.6, W * 0.5)
    torus(W * 0.5 + 0.4, 0.45, 0, 1.6, W * 0.5, "stone", rot=(math.pi / 2, 0, 0))
    for i in range(6):
        box(0.12, 0.12, W, -W * 0.4 + i * W * 0.16, 1.65, 0, "dark", 0.0)
    box(W * 0.7, 6.0, 0.25, 0, 4.5, 0.2, "water", 0.0, rot=(-0.3, 0, 0))
    export("culvert_0", [W, H, L])


def b_galleon():
    W, L = 7.0, 32.0
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.0, location=(0, 0, 1.6 - W * 0.3))
    o = bpy.context.active_object
    o.scale = (W * 0.5, L * 0.5, W * 0.35)
    _finish(o, "C")
    box(W * 0.92, L * 0.86, 0.25, 0, 0, 1.6, "wood_dark", 0.02)
    box(W * 0.96, L * 0.86, 0.5, 0, 0, 1.2, "B", 0.02)
    box(W * 0.85, L * 0.2, 3.0, 0, -L * 0.36, 1.7, "C", 0.03)
    window(0, -L * 0.46, 3.4, W * 0.6, 1.0, "-y")
    box(W * 0.7, L * 0.12, 1.6, 0, L * 0.38, 1.7, "C", 0.03)
    cyl(0.12, L * 0.3, 0, L * 0.42, 2.0, "C", 6, rot=(-1.2, 0, 0))
    for i in range(3):
        y = -L * 0.25 + i * L * 0.25
        mh = L * (0.75 if i == 1 else 0.6)
        cyl(0.25, mh, 0, y, 1.8, "wood_dark", 8, r2=0.18)
        for k in range(3):
            sw = W * (1.7 - k * 0.35)
            box(sw, 0.1, mh * 0.18, 0, y + 0.3, 1.8 + mh * (0.3 + k * 0.22), "cloth", 0.0)
            box(sw + 0.4, 0.14, 0.14, 0, y + 0.3, 1.8 + mh * (0.48 + k * 0.22), "wood_dark", 0.0)
        box(0.06, 1.6, 0.9, 0, y, 1.8 + mh + 0.2, "B", 0.0)
    export("galleon_0", [W, 3.0, L])


def b_steamship():
    W, L = 9.0, 40.0
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1.0, location=(0, 0, 1.4 - W * 0.275))
    o = bpy.context.active_object
    o.scale = (W * 0.5, L * 0.5, W * 0.3)
    _finish(o, "dark")
    box(W * 0.95, L * 0.88, 0.6, 0, 0, 1.3, "A", 0.02)
    box(W * 0.8, L * 0.55, 2.6, 0, -L * 0.05, 1.9, "A", 0.03)
    box(W * 0.65, L * 0.32, 2.2, 0, 0, 4.5, "A", 0.03)
    box(W * 0.85, L * 0.58, 0.2, 0, -L * 0.05, 4.5, "B", 0.0)
    box(W * 0.7, L * 0.35, 0.2, 0, 0, 6.7, "B", 0.0)
    for i in range(int(L * 0.5 / 1.6)):
        for sx in (-1, 1):
            window(sx * W * 0.4, L * 0.22 - i * 1.6, 2.8, 0.8, 0.8, "+x" if sx > 0 else "-x")
    for i in range(2):
        y = L * 0.08 - i * L * 0.16
        cyl(W * 0.14, 4.0, 0, y, 6.9, "B", 12)
        cyl(W * 0.155, 0.5, 0, y, 10.4, "gold", 12)
    for sx in (-1, 1):
        cyl(2.2, 1.2, 0, 0, 0, "B", 16, rot=(0, math.pi / 2, 0))
        PARTS[-1].location = (sx * (W / 2 + 0.6), 0, 1.6)
        half_sphere(2.3, 0, 0, 0, "A", 16)
        PARTS[-1].rotation_euler = (0, sx * -math.pi / 2, 0)
        PARTS[-1].location = (sx * (W / 2 + 0.6), 0, 1.6)
    cyl(0.08, 6.0, 0, L * 0.3, 6.9, "dark", 6)
    export("steamship_0", [W, 3.0, L])


def b_guildhouse(v):
    # v1 锻铁匠：两根烟囱；v2 精工：正面金色齿轮；v3 学者：书卷浮雕。基础造型与 guildhouse_0 一致
    build_guildhouse()
    os.replace(os.path.join(OUT, "guildhouse_0.glb"), os.path.join(OUT, "guildhouse_tmp.glb"))
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(OUT, "guildhouse_tmp.glb"))
    base = [o for o in bpy.data.objects if o.type == "MESH"]
    PARTS.extend(base)
    W, D, H = 22.0, 18.0, 13.0
    if v == 1:
        for i in range(2):
            box(1.6, 1.6, H * 0.7, W * 0.3, -D * 0.1 - i * D * 0.2, H, "stone_dark", 0.04)
    elif v == 2:
        torus(1.3, 0.35, 0, D / 2 + 1.5, H * 0.9, "gold", rot=(math.pi / 2, 0, 0), seg=16)
        for t in range(8):
            box(0.4, 0.2, 3.4, 0, D / 2 + 1.5, H * 0.9 - 1.7, "gold", 0.0, rot=(0, t * math.pi / 8, 0))
            PARTS[-1].location = (0, D / 2 + 1.5, H * 0.9)
    elif v == 3:
        cyl(0.6, W * 0.3, 0, 0, 0, "cloth", 12, rot=(0, math.pi / 2, 0))
        PARTS[-1].location = (0, D / 2 + 0.9, H * 1.18)
    os.remove(os.path.join(OUT, "guildhouse_tmp.glb"))
    export("guildhouse_%d" % v, [W, H, D])
    build_guildhouse()  # 重新生成 guildhouse_0


def b_gate():
    W, H, T = 14.0, 10.0, 3.2
    tw = 5.0
    for sx in (-1, 1):
        x = sx * (W / 2 + tw / 2)
        box(tw, tw, H + 6.0, x, 0, -2.0, "A", 0.04)
        cyl(tw * 0.8, 4.0, x, 0, H + 4.0, "B", 4, r2=0.0, rot=(0, 0, math.pi / 4))
        for k in range(2):
            window(x, tw / 2, H * 0.5 + k * 3.0, 0.6, 1.2, "+y")
        box(tw + 0.4, tw + 0.4, 0.5, x, 0, H + 3.8, "C", 0.02)
        for i in range(3):
            for sy in (-1, 1):
                box(0.9, 0.6, 0.9, x - tw * 0.33 + i * tw * 0.33, sy * (tw / 2 - 0.3), H + 4.3, "A", 0.03)
    box(W + 0.2, T, 4.0, 0, 0, H, "A", 0.04)
    box(W + 0.4, T + 0.4, 0.5, 0, 0, H - 0.1, "C", 0.02)
    bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=W / 2, depth=T + 0.1, location=(0, 0, H), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.01], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    o.scale = (1, 0.5, 1)
    _finish(o, "A")
    for sx in (-1, 1):
        box(1.4, 0.08, 3.2, sx * (W / 2 - 1.0), T / 2 + 0.1, H - 2.6, "B", 0.0)
        sphere(0.3, sx * (W / 2 - 1.0), T / 2 + 0.16, H - 0.6, "gold", 1, (1, 0.3, 1))
    for i in range(int(W / 1.2)):
        box(0.12, 0.12, 2.0, -W / 2 + 0.6 + i * 1.2, 0, H - 2.0, "dark", 0.0)
    box(W, 0.12, 0.12, 0, 0, H - 1.0, "dark", 0.0)
    export("gate_0", [W, H, T])


def b_station():
    W, H, D = 34.0, 12.0, 34.0
    box(W, D, 3.0, 0, 0, -2.5, "stone", 0.05)
    box(W, D * 0.3, H, 0, D * 0.35, 0, "A", 0.03)
    for sx in (-1, 1):
        box(W * 0.12, D * 0.32, H * 1.3, sx * W * 0.45, D * 0.35, 0, "C", 0.03)
        half_sphere(W * 0.07, sx * W * 0.45, D * 0.35, H * 1.3, "B", 12)
    cyl(W * 0.22, D * 0.32, 0, 0, 0, "glass", 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, D * 0.35, H * 0.85)
    torus(W * 0.235, 0.5, 0, D / 2 + 0.05, H * 0.85, "C", rot=(math.pi / 2, 0, 0))
    door(0, D / 2 + 0.3, 0, 3.6, 4.5, m="dark")
    for i in range(6):
        x = (i - 2.5) * W * 0.14
        if abs(x) > W * 0.2:
            cyl(0.45, H * 0.8, x, D / 2 + 0.6, 0, "C", 10, r2=0.4)
    cx = W * 0.3
    box(5.0, 5.0, H * 2.0, cx, D * 0.52, 0, "C", 0.03)
    cyl(1.6, 0.3, 0, 0, 0, "cloth", 24, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (cx, D * 0.52 + 2.6, H * 1.6)
    cyl(3.8, 4.0, cx, D * 0.52, H * 2.0, "B", 4, r2=0.0, rot=(0, 0, math.pi / 4))
    for sx in (-1, 1):
        box(1.0, D * 0.65, H * 0.6, sx * W * 0.45, -D * 0.15, 0, "A", 0.03)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=W * 0.44, depth=D * 0.65, location=(0, -D * 0.15, H * 0.6), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.01], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    _finish(o, "glass")
    for i in range(int(D * 0.65 / 4)):
        torus(W * 0.44, 0.25, 0, D * 0.18 - i * 4.0, H * 0.6, "dark", rot=(math.pi / 2, 0, 0))
    export("station_0", [W, H, D])


def b_airship():
    L = 20.0
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=1.0, location=(0, 0, L * 0.3))
    o = bpy.context.active_object
    o.scale = (L * 0.18, L * 0.5, L * 0.153)
    _finish(o, "A")
    for i in range(5):
        torus(L * 0.18, 0.12, 0, -L * 0.3 + i * L * 0.15, L * 0.3, "C", rot=(math.pi / 2, 0, 0), seg=24)
        PARTS[-1].scale = (1, 1, 0.85)
    for sx in (-1, 1):
        v = [(0, 0, 0), (0, -L * 0.25, 0), (0, -L * 0.1, L * 0.15)]
        o2 = mesh_obj(v, [(0, 1, 2)], "B")
        o2.modifiers.new("s", "SOLIDIFY").thickness = 0.12
        o2.location = (sx * L * 0.12, -L * 0.33, L * 0.3)
        o2.rotation_euler = (0, sx * 0.5, 0)
    box(L * 0.16, L * 0.4, L * 0.08, 0, 0, L * 0.02, "C", 0.03)
    for k in range(4):
        for sx in (-1, 1):
            window(sx * L * 0.08, -L * 0.12 + k * L * 0.08, L * 0.04, 0.6, 0.5, "+x" if sx > 0 else "-x")
    for sx in (-1, 1):
        cyl(0.2, L * 0.15, 0, 0, 0, "gold", 8, rot=(0, math.pi / 2, 0))
        PARTS[-1].location = (sx * L * 0.08, -L * 0.22, L * 0.1)
        for b in range(3):
            box(0.25, 0.05, L * 0.1, sx * L * 0.15, -L * 0.24, L * 0.1, "wood_dark", 0.0, rot=(0, b * math.tau / 3, 0))
            PARTS[-1].location = (sx * L * 0.15, -L * 0.24, L * 0.1)
    export("airship_0", [7.0, 7.0, L])


LANDMARK_BUILDERS = {
    "goddess_0": b_goddess, "beacon_0": b_beacon, "clock_spire_0": b_clock_spire, "cathedral_0": b_cathedral,
    "civic_hall_0": b_civic_hall, "opera_0": b_opera, "mage_tower_0": b_mage_tower, "rotunda_0": b_rotunda,
    "bathhouse_0": b_bathhouse, "hospital_0": b_hospital, "warehouse_0": b_warehouse, "terminal_0": b_terminal,
    "market_hall_0": b_market_hall, "culvert_0": b_culvert, "galleon_0": b_galleon, "steamship_0": b_steamship,
    "guildhouse_1": lambda: b_guildhouse(1), "guildhouse_2": lambda: b_guildhouse(2), "guildhouse_3": lambda: b_guildhouse(3),
    "gate_0": b_gate, "station_0": b_station, "airship_0": b_airship,
}
run_builders(LANDMARK_BUILDERS)
