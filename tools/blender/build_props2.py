# Batch 7: hand-crafted village props in the Mabinogi-style reference look (chunky, soft-bevelled, slightly irregular
# planks, dark wood frames, iron hoops, rope, fruit / flowers). Replaces the old crate / barrel / bench / cart / fence /
# haystack / flower_pot models and adds chairs, tables, stools, buckets, sacks, baskets, wood piles, wheelbarrows, troughs.
# Run: blender -b --factory-startup --python tools/blender/build_props2.py -- <out_dir> [names]
# Materials: "C" = main wood (recoloured by the prop's color_c), wood_dark = frames / legs, metal = iron, cloth = sacks /
# table cloth, rope, wheat = hay, leaf / flower_* = plants, red / fruit_g = apples, water = game water shader.
import bpy, os, sys, math, random
_LIB_ONLY = True
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "build_models.py"), encoding="utf-8").read())
COLORS.update({"wood_dark": "5a3a24", "metal": "3c3a40", "cloth": "e8dcc0", "rope": "b89a68", "wheat": "e2c460",
               "leaf": "5a9a3a", "flower_r": "f06a7a", "flower_y": "ffd040", "flower_w": "fff6e8", "flower_p": "b090f0",
               "red": "d0382c", "fruit_g": "9cc040", "water": "70c8e0", "soil": "5a3e28", "wood": "a87a48",
               "bread": "c8883c"})


def soft(o, w=0.025, seg=2):
    """Rounded edges (chunky hand-made look)."""
    for m in list(o.modifiers):
        if m.type == "BEVEL":
            o.modifiers.remove(m)
    mod = o.modifiers.new("bv", "BEVEL")
    mod.width = w
    mod.segments = seg
    mod.limit_method = "ANGLE"
    return o


def jit(a):
    return random.uniform(-a, a)


def plank(sx, sy, sz, x, y, z, m="C", rough=0.02, w=0.018, rot=(0, 0, 0)):
    """Plank with a tiny random wobble so rows don't look machine-cut."""
    o = box(sx * (1 + jit(0.03)), sy, sz, x, y, z + jit(rough * 0.3), m, 0.0,
            rot=(rot[0] + jit(rough), rot[1] + jit(rough), rot[2] + jit(rough)))
    return soft(o, w)


def ball(r, x, y, z, m, sub=2, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, m)


def lump(r, x, y, z, m, seed, flat=0.7, sub=2, amt=0.12):
    random.seed(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    for v in o.data.vertices:
        v.co *= 1.0 + random.uniform(-amt, amt)
    o.scale = (1, 1, flat)
    return _finish(o, m)


def torus(R, r, x, y, z, m, seg=16, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=seg, minor_segments=6,
                                     location=(x, y, z), rotation=rot)
    return _finish(bpy.context.active_object, m)


def apples(n, cx, cy, z, rad, seed, r=0.075):
    random.seed(seed)
    for i in range(n):
        a = random.random() * math.tau
        d = math.sqrt(random.random()) * rad
        ball(r * random.uniform(0.85, 1.1), cx + math.cos(a) * d, cy + math.sin(a) * d, z + random.uniform(0, r * 0.8),
             "red" if random.random() < 0.75 else "fruit_g", 1)


def flowers(n, cx, cy, z, rx, ry, seed, h=0.25):
    random.seed(seed)
    cols = ["flower_r", "flower_y", "flower_w", "flower_p"]
    for i in range(n):
        x = cx + jit(rx)
        y = cy + jit(ry)
        lump(0.09, x, y, z + 0.05, "leaf", seed + i, 0.8, 1, 0.2)
        cyl(0.012, h, x, y, z, "leaf", 4)
        ball(0.055, x + jit(0.02), y + jit(0.02), z + h, cols[i % 4] if random.random() < 0.8 else random.choice(cols), 1,
             (1, 1, 0.7))


# ------------------------------------------------------------------------------------------------ crates
def crate_body(S, seed):
    """Planked crate: 3 horizontal planks per side inside a dark corner frame."""
    random.seed(seed)
    h = S
    n = 3
    ph = h / n
    for k in range(n):
        z = k * ph + 0.015
        for sy in (-1, 1):
            plank(S - 0.1, 0.06, ph - 0.03, 0, sy * (S / 2 - 0.03), z)
        for sx in (-1, 1):
            plank(0.06, S - 0.1, ph - 0.03, sx * (S / 2 - 0.03), 0, z)
    box(S - 0.1, S - 0.1, 0.05, 0, 0, 0.0, "C", 0.0)
    # corner posts + top/bottom rims
    for sx in (-1, 1):
        for sy in (-1, 1):
            soft(box(0.11, 0.11, h + 0.02, sx * (S / 2 - 0.035), sy * (S / 2 - 0.035), 0, "wood_dark", 0.0), 0.02)
    for z in (0.0, h - 0.08):
        for sy in (-1, 1):
            soft(box(S, 0.08, 0.09, 0, sy * (S / 2 - 0.0), z, "wood_dark", 0.0), 0.015)
        for sx in (-1, 1):
            soft(box(0.08, S, 0.09, sx * (S / 2 - 0.0), 0, z, "wood_dark", 0.0), 0.015)
    # diagonal brace on the front / back
    L = math.hypot(S - 0.2, h - 0.2)
    ang = math.atan2(h - 0.2, S - 0.2)
    for sy in (-1, 1):
        o = soft(box(L, 0.05, 0.08, 0, sy * (S / 2 + 0.02), h / 2 - 0.04, "wood_dark", 0.0, rot=(0, -ang * sy, 0)), 0.012)


def b_crate0():
    crate_body(1.0, 701)
    random.seed(702)
    for i in range(4):   # lid planks
        plank(0.23, 0.98, 0.05, -0.36 + i * 0.24, 0, 1.0)
    export("crate_0", [1.0, 1.0, 1.0])


def b_crate1():
    # open produce crate full of apples
    crate_body(1.0, 711)
    box(0.86, 0.86, 0.05, 0, 0, 0.72, "soil", 0.0)
    apples(26, 0, 0, 0.76, 0.36, 712, 0.085)
    export("crate_1", [1.0, 1.0, 1.0])


def b_crate2():
    # low long crate with rope handles + a small crate stacked on top
    random.seed(721)
    W, D, H = 1.0, 1.0, 0.62
    for k in range(2):
        z = k * 0.31 + 0.01
        for sy in (-1, 1):
            plank(W - 0.08, 0.06, 0.28, 0, sy * (D / 2 - 0.03), z)
        for sx in (-1, 1):
            plank(0.06, D - 0.08, 0.28, sx * (W / 2 - 0.03), 0, z)
    for sx in (-1, 1):
        for sy in (-1, 1):
            soft(box(0.1, 0.1, H, sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), 0, "wood_dark", 0.0), 0.02)
        torus(0.08, 0.018, sx * (W / 2 + 0.02), 0, H * 0.62, "rope", 10, rot=(0, math.pi / 2, 0))
    for i in range(4):
        plank(0.235, D, 0.05, -0.36 + i * 0.24, 0, H)
    # small crate on top, rotated
    random.seed(722)
    s = 0.5
    z0 = H + 0.05
    for sy in (-1, 1):
        plank(s - 0.06, 0.05, s, 0.1, sy * (s / 2 - 0.02) + 0.05, z0, rot=(0, 0, 0.3))
    for sx in (-1, 1):
        plank(0.05, s - 0.06, s, sx * (s / 2 - 0.02) + 0.1, 0.05, z0, rot=(0, 0, 0.3))
    box(s, s, 0.05, 0.1, 0.05, z0 + s, "wood_dark", 0.02, rot=(0, 0, 0.3))
    export("crate_2", [1.0, 1.0, 1.0])


# ------------------------------------------------------------------------------------------------ barrels
def barrel_body(R, H, seed, staves=14, bulge=0.12):
    random.seed(seed)
    for i in range(staves):
        a = i * math.tau / staves
        # stave = slightly bent box approximated by 3 segments
        segs = 4
        for s in range(segs):
            z0 = H * s / segs
            z1 = H * (s + 1) / segs
            zm = (z0 + z1) * 0.5
            t = (zm / H) * 2 - 1
            r = R * (1 + bulge * (1 - t * t))
            w = 2 * r * math.sin(math.pi / staves) * 1.04
            o = box(w, 0.07, (z1 - z0) + 0.01, math.cos(a) * r, math.sin(a) * r, z0 - 0.005,
                    "C" if i % 5 else "wood_dark", 0.0, rot=(0, 0, a + math.pi / 2))
            # tilt each segment to follow the bulge
            dr = R * bulge * (-4 * t / H) * 1.0
            o.rotation_euler = (0, 0, a + math.pi / 2)
            o.rotation_mode = "XYZ"
            o.rotation_euler.rotate_axis("X", -math.atan(dr * 0.5))
    for z, rr in ((0.12, 0.0), (0.3, 0.0), (H - 0.3, 0.0), (H - 0.12, 0.0)):
        t = (z / H) * 2 - 1
        r = R * (1 + bulge * (1 - t * t)) + 0.035
        torus(r, 0.03, 0, 0, z, "metal", 24)


def b_barrel0():
    H = 1.3
    barrel_body(0.45, H, 731)
    cyl(0.44, 0.04, 0, 0, H - 0.08, "wood_dark", 18)
    # lid planks
    random.seed(732)
    for i in range(4):
        plank(0.2, 0.82 - abs(i - 1.5) * 0.22, 0.03, -0.3 + i * 0.2, 0, H - 0.05, "C", 0.0, 0.008)
    soft(box(0.1, 0.1, 0.07, 0.0, 0.0, H - 0.02, "wood_dark", 0.0), 0.01)
    export("barrel_0", [1.0, 1.3, 1.0])


def b_barrel1():
    # open rain barrel with water + ladle
    H = 1.0
    barrel_body(0.42, H, 741, 12, 0.08)
    cyl(0.4, 0.04, 0, 0, 0.02, "wood_dark", 16)
    cyl(0.4, 0.02, 0, 0, H - 0.14, "water", 16)
    cyl(0.025, 0.6, 0.15, 0.0, H - 0.25, "wood_dark", 6, rot=(0.0, 0.55, 0.0))
    export("barrel_1", [1.0, 1.0, 1.0])


# ------------------------------------------------------------------------------------------------ seating / tables
def b_bench():
    random.seed(751)
    L = 2.4
    # thick split-log seat (two planks) on chunky trestle legs
    for k in range(2):
        plank(L, 0.2, 0.08, 0, -0.11 + k * 0.22, 0.44, "C", 0.01, 0.025)
    for sx in (-1, 1):
        for sy in (-1, 1):
            o = soft(box(0.1, 0.1, 0.5, sx * (L / 2 - 0.3) + sx * 0.06, sy * 0.15, -0.02, "wood_dark", 0.0,
                         rot=(sy * 0.18, 0, 0)), 0.02)
        soft(box(0.08, 0.5, 0.08, sx * (L / 2 - 0.24), 0, 0.2, "wood_dark", 0.0), 0.015)
    soft(box(L - 0.5, 0.06, 0.08, 0, 0, 0.2, "wood_dark", 0.0), 0.015)
    export("bench_0", [2.4, 1.0, 0.6])


def b_chair():
    random.seed(761)
    S = 0.5
    for i in range(3):
        plank(S, 0.16, 0.05, 0, -0.17 + i * 0.17, 0.44, "C", 0.0, 0.015)
    for sx in (-1, 1):
        for sy in (-1, 1):
            h = 0.46 if sy < 0 else 1.0
            soft(cyl(0.035, h, sx * 0.21, sy * 0.21, 0, "wood_dark", 8), 0.0)
        soft(box(0.04, 0.42, 0.04, sx * 0.21, 0, 0.18, "wood_dark", 0.0), 0.01)
    # back: two curved slats + top rail
    for z in (0.62, 0.8):
        plank(0.42, 0.04, 0.09, 0, 0.22, z, "C", 0.0, 0.012)
    soft(box(0.52, 0.06, 0.08, 0, 0.22, 0.96, "wood_dark", 0.0), 0.02)
    # little heart cut-out ornament
    ball(0.035, 0, 0.245, 0.89, "wood_dark", 1, (1, 0.4, 1))
    export("chair_0", [0.5, 1.0, 0.5])


def b_stool():
    random.seed(771)
    cyl(0.22, 0.07, 0, 0, 0.45, "C", 14, bevel=0.0)
    soft(PARTS[-1], 0.02)
    for i in range(3):
        a = i * math.tau / 3
        soft(cyl(0.03, 0.5, math.cos(a) * 0.14, math.sin(a) * 0.14, -0.03, "wood_dark", 6,
                 rot=(math.sin(a) * -0.15, math.cos(a) * 0.15, 0)), 0.0)
    torus(0.14, 0.015, 0, 0, 0.18, "wood_dark", 12)
    export("stool_0", [0.5, 0.5, 0.5])


def b_table():
    random.seed(781)
    W, D = 1.6, 0.9
    for i in range(4):
        plank(W, D / 4 - 0.01, 0.06, 0, -D / 2 + (i + 0.5) * D / 4, 0.74, "C", 0.0, 0.015)
    for sx in (-1, 1):
        soft(box(0.08, D - 0.1, 0.08, sx * (W / 2 - 0.15), 0, 0.66, "wood_dark", 0.0), 0.015)
        for sy in (-1, 1):
            soft(box(0.09, 0.09, 0.68, sx * (W / 2 - 0.15), sy * (D / 2 - 0.12), 0, "wood_dark", 0.0), 0.02)
        soft(box(0.07, D - 0.2, 0.07, sx * (W / 2 - 0.15), 0, 0.14, "wood_dark", 0.0), 0.015)
    soft(box(W - 0.3, 0.07, 0.07, 0, 0, 0.14, "wood_dark", 0.0), 0.015)
    # runner cloth + bread, mug and a jug
    box(0.45, D + 0.06, 0.012, 0, 0, 0.8, "cloth", 0.0)
    lump(0.13, -0.45, 0.1, 0.83, "bread", 782, 0.55, 2, 0.06)
    lump(0.09, -0.3, -0.18, 0.82, "bread", 783, 0.55, 2, 0.06)
    cyl(0.05, 0.12, 0.35, -0.15, 0.8, "wood", 10)
    cyl(0.08, 0.22, 0.55, 0.15, 0.8, "wood_dark", 10, r2=0.06)
    torus(0.04, 0.012, 0.63, 0.15, 0.92, "wood_dark", 8, rot=(math.pi / 2, 0, 0))
    export("table_0", [1.6, 0.9, 0.9])


# ------------------------------------------------------------------------------------------------ small things
def b_bucket():
    random.seed(791)
    n = 10
    for i in range(n):
        a = i * math.tau / n
        o = box(0.085, 0.035, 0.36, math.cos(a) * 0.17, math.sin(a) * 0.17, 0, "C", 0.0, rot=(0, 0, a + math.pi / 2))
        o.rotation_euler.rotate_axis("X", -0.1)
    cyl(0.16, 0.03, 0, 0, 0.01, "wood_dark", 12)
    for z in (0.06, 0.28):
        torus(0.185 + z * 0.08, 0.016, 0, 0, z, "metal", 16)
    cyl(0.17, 0.02, 0, 0, 0.26, "water", 12)
    # handle
    bpy.ops.mesh.primitive_torus_add(major_radius=0.2, minor_radius=0.01, major_segments=16, minor_segments=4,
                                     location=(0, 0, 0.36), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object
    _finish(o, "metal")
    export("bucket_0", [0.5, 0.5, 0.5])


def sack(x, y, z, s, seed, lay=False):
    o = lump(0.28 * s, x, y, z + 0.22 * s, "cloth", seed, 1.0, 2, 0.06)
    o.scale = (1.0, 0.8, 1.25) if not lay else (1.35, 0.85, 0.7)
    if not lay:
        cyl(0.07 * s, 0.1 * s, x, y, z + 0.5 * s, "rope", 8)
        lump(0.1 * s, x, y, z + 0.62 * s, "cloth", seed + 1, 0.8, 1, 0.15)
    return o


def b_sacks():
    sack(-0.25, 0.0, 0, 1.0, 801)
    sack(0.28, 0.1, 0, 0.95, 803)
    sack(0.0, -0.05, 0.5, 0.9, 805, True)
    lump(0.12, 0.45, -0.25, 0.04, "wheat", 806, 0.4, 1, 0.3)
    export("sack_0", [1.2, 1.0, 0.8])


def b_basket():
    # wicker basket of apples
    random.seed(811)
    cyl(0.3, 0.3, 0, 0, 0, "rope", 14, r2=0.36)
    for z in (0.04, 0.12, 0.2, 0.28):
        torus(0.31 + z * 0.2, 0.025, 0, 0, z, "wood", 16)
    cyl(0.3, 0.02, 0, 0, 0.24, "soil", 12)
    apples(12, 0, 0, 0.27, 0.22, 812, 0.07)
    bpy.ops.mesh.primitive_torus_add(major_radius=0.3, minor_radius=0.02, major_segments=16, minor_segments=4,
                                     location=(0, 0, 0.3), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object
    o.scale = (1.0, 1.0, 1.0)
    _finish(o, "wood")
    export("basket_0", [0.8, 0.6, 0.8])


def b_woodpile():
    random.seed(821)
    L = 1.6
    rows = [5, 4, 3]
    r = 0.11
    for k, n in enumerate(rows):
        for i in range(n):
            x = (i - (n - 1) / 2) * r * 2.05 + (k % 2) * 0.0
            z = k * r * 1.75 + r
            ll = L * random.uniform(0.9, 1.0)
            o = cyl(r * random.uniform(0.85, 1.05), ll, 0, 0, 0, "C", 8, rot=(math.pi / 2, 0, 0))
            o.location = (x, random.uniform(-0.04, 0.04), z)
            # bright cut ends
            for sy in (-1, 1):
                e = cyl(r * 0.82, 0.02, 0, 0, 0, "wheat", 8, rot=(math.pi / 2, 0, 0))
                e.location = (x, o.location.y + sy * ll / 2, z)
    for sx in (-1, 1):
        soft(box(0.08, 0.08, 0.75, sx * 0.62, 0, 0, "wood_dark", 0.0), 0.015)
    export("wood_pile_0", [1.4, 0.8, 1.6])


def b_trough():
    random.seed(831)
    L, W = 1.8, 0.6
    for sy in (-1, 1):
        plank(L, 0.07, 0.42, 0, sy * (W / 2 - 0.035), 0.12, "C", 0.01)
    for sx in (-1, 1):
        plank(0.07, W, 0.42, sx * (L / 2 - 0.035), 0, 0.12, "C", 0.01)
        soft(box(0.12, W + 0.16, 0.14, sx * (L / 2 - 0.25), 0, 0, "wood_dark", 0.0), 0.02)
    box(L - 0.1, W - 0.1, 0.05, 0, 0, 0.12, "C", 0.0)
    box(L - 0.14, W - 0.14, 0.02, 0, 0, 0.44, "water", 0.0)
    export("trough_0", [1.8, 0.6, 0.6])


def b_wheelbarrow():
    random.seed(841)
    # tub
    for sx in (-1, 1):
        plank(0.06, 0.9, 0.32, sx * 0.3, 0.05, 0.42, "C", 0.0, rot=(0, sx * 0.25, 0))
    plank(0.62, 0.06, 0.32, 0, 0.5, 0.42, "C", 0.0, rot=(-0.3, 0, 0))
    plank(0.62, 0.06, 0.32, 0, -0.4, 0.42, "C", 0.0, rot=(0.2, 0, 0))
    box(0.56, 0.9, 0.05, 0, 0.05, 0.4, "C", 0.0)
    # handles + legs
    for sx in (-1, 1):
        soft(box(0.06, 1.6, 0.06, sx * 0.24, -0.2, 0.42, "wood_dark", 0.0, rot=(0.12, 0, 0)), 0.012)
        soft(box(0.06, 0.06, 0.42, sx * 0.24, -0.45, 0.0, "wood_dark", 0.0), 0.012)
    # wheel
    cyl(0.25, 0.08, 0, 0.72, 0, "wood_dark", 14, rot=(0, math.pi / 2, 0)).location = (-0.04, 0.72, 0.25)
    torus(0.25, 0.025, 0, 0.72, 0.25, "metal", 16, rot=(0, math.pi / 2, 0))
    # load of hay
    lump(0.3, 0, 0.05, 0.62, "wheat", 842, 0.5, 2, 0.2)
    export("wheelbarrow_0", [0.8, 0.8, 1.8])


def b_cart():
    random.seed(851)
    W, L = 1.8, 2.8
    for i in range(6):
        plank(W, L / 6 - 0.02, 0.07, 0, -L / 2 + (i + 0.5) * L / 6, 0.78, "C", 0.0)
    for sx in (-1, 1):
        for k in range(2):
            plank(0.07, L, 0.2, sx * (W / 2 - 0.035), 0, 0.88 + k * 0.23, "C", 0.01)
        for y in (-L / 2 + 0.1, 0, L / 2 - 0.1):
            soft(box(0.1, 0.1, 0.6, sx * (W / 2 - 0.02), y, 0.78, "wood_dark", 0.0), 0.02)
    for sy in (-1, 1):
        for k in range(2):
            plank(W, 0.07, 0.2, 0, sy * (L / 2 - 0.035), 0.88 + k * 0.23, "C", 0.01)
    soft(box(0.12, L, 0.12, 0, 0, 0.66, "wood_dark", 0.0), 0.02)
    # wheels with spokes
    for sx in (-1, 1):
        x = sx * (W / 2 + 0.1)
        torus(0.6, 0.06, x, 0.3, 0.62, "wood_dark", 20, rot=(0, math.pi / 2, 0))
        torus(0.62, 0.025, x, 0.3, 0.62, "metal", 20, rot=(0, math.pi / 2, 0))
        cyl(0.12, 0.2, x, 0.3, 0.62, "wood_dark", 10, rot=(0, math.pi / 2, 0)).location = (x - 0.1, 0.3, 0.62)
        for k in range(8):
            a = k * math.pi / 8
            soft(box(0.04, 0.04, 1.14, x, 0.3, 0.62 - 0.57, "C", 0.0), 0.0)
            o = PARTS[-1]
            o.location = (x, 0.3, 0.62)
            o.rotation_euler = (a, 0, 0)
    # shafts
    for sx in (-1, 1):
        soft(box(0.08, 2.0, 0.08, sx * 0.45, -L / 2 - 0.9, 0.62, "wood_dark", 0.0, rot=(0.1, 0, 0)), 0.012)
    # load: hay + sacks + a barrel
    lump(0.75, 0.1, 0.5, 1.15, "wheat", 852, 0.55, 2, 0.15)
    sack(-0.45, -0.7, 0.85, 0.9, 853)
    sack(0.4, -0.85, 0.85, 0.85, 855, True)
    export("cart_0", [1.8, 1.0, 2.8])


def b_fence():
    random.seed(861)
    L = 2.0
    # rustic split-rail fence: round posts with pointed tops, two slightly sagging rails
    for sx in (-1, 1):
        cyl(0.075, 1.0, sx * L / 2, 0, 0, "wood_dark", 7)
        cyl(0.075, 0.14, sx * L / 2, 0, 1.0, "wood_dark", 7, r2=0.02)
    for z in (0.4, 0.78):
        o = soft(box(L + 0.12, 0.07, 0.12, 0, 0.0, z + jit(0.03), "C", 0.0, rot=(jit(0.02), jit(0.03), 0)), 0.02)
    export("fence_0", [L, 1.1, 0.2])


def b_haystack():
    random.seed(871)
    # two round bales + loose hay mound
    for x, y, rz in ((-0.45, 0.1, 0.2), (0.55, -0.2, -0.4)):
        o = cyl(0.55, 0.9, 0, 0, 0, "wheat", 16, rot=(math.pi / 2, 0, rz))
        o.location = (x, y, 0.55)
        soft(o, 0.12, 2)
        for dz in (-0.25, 0.25):
            t = torus(0.56, 0.018, x, y, 0.55, "rope", 18, rot=(math.pi / 2, 0, rz))
            t.location = (x - math.sin(rz) * dz, y + math.cos(rz) * dz, 0.55)
    lump(0.6, 0.0, 0.6, 0.0, "wheat", 872, 0.6, 2, 0.2)
    export("haystack_0", [2.0, 1.6, 2.0])


def b_flower_pot():
    # wooden planter box overflowing with flowers
    random.seed(881)
    W, D, H = 1.0, 0.45, 0.4
    for sy in (-1, 1):
        plank(W, 0.05, H, 0, sy * (D / 2 - 0.025), 0, "C", 0.01)
    for sx in (-1, 1):
        plank(0.05, D, H, sx * (W / 2 - 0.025), 0, 0, "C", 0.01)
        soft(box(0.07, D + 0.04, H + 0.04, sx * (W / 2 - 0.03), 0, 0, "wood_dark", 0.0), 0.015)
    box(W - 0.08, D - 0.08, 0.04, 0, 0, H - 0.08, "soil", 0.0)
    for i in range(6):
        lump(0.14, -0.38 + i * 0.15, jit(0.06), H, "leaf", 882 + i, 0.75, 1, 0.2)
    flowers(14, 0, 0, H - 0.04, 0.42, 0.14, 890, 0.22)
    export("flower_pot_0", [1.0, 1.0, 1.0])


PROPS2 = {
    "crate_0": b_crate0, "crate_1": b_crate1, "crate_2": b_crate2, "barrel_0": b_barrel0, "barrel_1": b_barrel1,
    "bench_0": b_bench, "chair_0": b_chair, "stool_0": b_stool, "table_0": b_table, "bucket_0": b_bucket,
    "sack_0": b_sacks, "basket_0": b_basket, "wood_pile_0": b_woodpile, "trough_0": b_trough,
    "wheelbarrow_0": b_wheelbarrow, "cart_0": b_cart, "fence_0": b_fence, "haystack_0": b_haystack,
    "flower_pot_0": b_flower_pot,
}
run_builders(PROPS2)
