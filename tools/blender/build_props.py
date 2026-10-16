# Batch 4: common scene props (ruins, fire, decor, farm, harbor, dungeon furniture) + forest vegetation.
# Run: blender -b --factory-startup --python tools/blender/build_props.py -- <out_dir> [names]
# Reuses helpers from build_models.py. Extra fixed materials used here:
#   flame  -> replaced in game by an unshaded glow tinted with the prop's color_b
#   glow   -> same (crystals, obelisk gems, portal surface)
#   water  -> replaced by the game's water shader
import bpy, os, sys, math, random
_LIB_ONLY = True
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "build_models.py"), encoding="utf-8").read())
COLORS.update({"flame": "ffa030", "glow": "80c0ff", "water": "70c8e0", "leaf": "5a9a3a", "leaf_dark": "3f7040",
               "rock": "9a968c", "rock_dark": "7e7a72", "soil": "6a4a30", "wheat": "e0c050", "web": "f0f0f0", "rug": "8a3a4a"})


def sphere(r, x, y, z, m, sub=1, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    o.scale = scale
    return _finish(o, m)


def rock_blob(r, x, y, z, m, seed):
    random.seed(seed)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=(x, y, z))
    o = bpy.context.active_object
    for v in o.data.vertices:
        v.co *= random.uniform(0.75, 1.15)
        if v.co.z < -r * 0.3:
            v.co.z = -r * 0.3
    o.scale = (1.0, random.uniform(0.8, 1.1), random.uniform(0.55, 0.8))
    return _finish(o, m)


# ---------------------------------------------------------------- ruins / stone
def b_ruin_wall(v):
    random.seed(60 + v)
    L, H, T = 6.0, 4.0, 1.5
    n = 5
    for i in range(n):
        hh = H * random.uniform(0.5, 1.0) if 0 < i < n - 1 else H * random.uniform(0.3, 0.55)
        box(L / n + 0.03, T, hh, -L / 2 + (i + 0.5) * L / n, 0, 0, "A" if i % 2 else "stone", 0.06)
    for i in range(6):
        x = random.uniform(-L / 2, L / 2)
        box(random.uniform(0.3, 0.6), random.uniform(0.3, 0.5), random.uniform(0.2, 0.4), x, random.choice([-1, 1]) * (T / 2 + 0.4), 0, "stone_dark", 0.05)
    if v == 1:
        cyl(1.2, T + 0.1, 0, 0, 0, "metal", 12, rot=(math.pi / 2, 0, 0))
        PARTS[-1].location = (0, T / 2 + 0.05, H * 0.55)
    for i in range(3):
        x = random.uniform(-L * 0.4, L * 0.4)
        box(0.25, 0.15, random.uniform(1.2, 2.4), x, T / 2 + 0.05, random.uniform(0.0, 1.0), "leaf", 0.02)
    export("ruin_wall_%d" % v, [L, H, T])


def b_column():
    cyl(0.85, 0.5, 0, 0, 0, "stone_dark", 8, bevel=0.04)
    cyl(0.55, 7.0, 0, 0, 0.5, "A", 12, r2=0.5)
    for i in range(8):
        a = i * math.tau / 8
        box(0.1, 0.1, 6.6, math.cos(a) * 0.52, math.sin(a) * 0.52, 0.7, "stone", 0.0)
    cyl(0.8, 0.5, 0, 0, 7.5, "stone_dark", 8, r2=0.6, bevel=0.03)
    export("column_0", [1.4, 8.0, 1.4])


def b_pillar(v):
    box(1.6, 1.6, 0.5, 0, 0, 0, "stone_dark", 0.05)
    h = 5.0 if v == 0 else 3.2
    cyl(0.6, h, 0, 0, 0.5, "A", 10, r2=0.55)
    if v == 0:
        box(1.6, 1.6, 0.5, 0, 0, 5.5, "stone_dark", 0.05)
    else:
        cyl(0.55, 0.9, 0.3, 0.2, 3.5, "A", 10, rot=(0.3, 0.5, 0))
        box(0.5, 0.4, 0.3, 1.2, 0.6, 0, "A", 0.05)
    box(0.2, 0.12, h * 0.6, 0.55, 0, 0.8, "leaf", 0.02)
    export("pillar_%d" % v, [1.4, 6.0 if v == 0 else 4.4, 1.4])


def b_pillar_row():
    L = 16.0
    n = 5
    for i in range(n):
        x = -L / 2 + i * L / (n - 1)
        cyl(0.5, 8.0, x, 0, 0, "A", 12, r2=0.46)
        box(1.2, 1.2, 0.4, x, 0, 0, "stone_dark", 0.03)
    box(L + 1.0, 1.4, 1.0, 0, 0, 8.0, "A", 0.04)
    box(L + 1.2, 1.6, 0.25, 0, 0, 9.0, "stone_dark", 0.02)
    export("pillar_row_0", [L, 8.0, 1.4])


def b_arch():
    W, H, T = 10.0, 9.0, 3.0
    for sx in (-1, 1):
        box(1.6, T, H, sx * (W / 2 + 0.8), 0, 0, "A", 0.05)
        box(2.0, T + 0.3, 0.6, sx * (W / 2 + 0.8), 0, 0, "stone_dark", 0.04)
    bpy.ops.mesh.primitive_torus_add(major_radius=W / 2 + 0.8, minor_radius=0.8, major_segments=24, minor_segments=4, location=(0, 0, H), rotation=(math.pi / 2, 0, 0))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if vv.co.y < -0.05], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    o.scale = (1, 1, T / 1.6)
    _finish(o, "A")
    box(W + 3.2, T + 0.2, 1.2, 0, 0, H + W / 2 + 0.2, "B", 0.04)
    box(1.2, T + 0.4, 1.4, 0, 0, H + W / 2 - 1.0, "stone", 0.04)
    export("arch_0", [W, H, T])


def b_obelisk():
    box(1.6, 1.6, 0.8, 0, 0, 0, "stone_dark", 0.05)
    cyl(0.55, 3.0, 0, 0, 0.8, "A", 4, r2=0.32, rot=(0, 0, math.pi / 4))
    cyl(0.34, 0.6, 0, 0, 3.8, "C", 4, r2=0.0, rot=(0, 0, math.pi / 4))
    sphere(0.22, 0, 0.42, 3.0, "glow", 1, (1, 0.5, 1))
    export("obelisk_0", [0.8, 3.0, 0.8])


def b_grave():
    box(0.9, 0.25, 1.1, 0, 0, 0, "stone", 0.04)
    cyl(0.45, 0.25, 0, 0, 0, "stone", 12, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, 0.125, 1.1)
    box(1.0, 1.8, 0.2, 0, -1.0, 0, "soil", 0.04)
    box(0.12, 0.05, 0.5, 0, 0.14, 0.45, "stone_dark", 0.0)
    box(0.35, 0.05, 0.12, 0, 0.14, 0.72, "stone_dark", 0.0)
    export("grave_0", [1.0, 1.0, 1.0])


def b_block(v):
    box(4.0, 4.0, 4.0, 0, 0, 0, "A", 0.04)
    if v == 1:
        box(4.2, 4.2, 0.3, 0, 0, 3.85, "C", 0.03)
    export("block_%d" % v, [4.0, 4.0, 4.0])


def b_platform():
    box(10.0, 10.0, 5.0, 0, 0, -4.0, "A", 0.06)
    box(10.2, 10.2, 0.25, 0, 0, 0.85, "C", 0.03)
    for i in range(4):
        box(10.0, 0.05, 0.3, 0, -5.02, -3.6 + i * 1.2, "stone_dark", 0.0)
    export("platform_0", [10.0, 1.0, 10.0])


# ---------------------------------------------------------------- fire / light
def b_campfire():
    for i in range(7):
        a = i * math.tau / 7
        rock_blob(0.22, math.cos(a) * 0.62, math.sin(a) * 0.62, 0.08, "rock", 70 + i)
    for i in range(3):
        cyl(0.07, 1.0, 0, 0, 0, "wood_dark", 6, rot=(math.pi / 2, 0, i * math.pi / 3))
        PARTS[-1].location = (0, 0, 0.15)
    cyl(0.32, 0.8, 0, 0, 0.12, "flame", 6, r2=0.0)
    cyl(0.18, 0.55, 0.1, 0.05, 0.12, "flame", 6, r2=0.0)
    export("campfire_0", [1.0, 1.0, 1.0])


def b_brazier():
    cyl(0.3, 0.12, 0, 0, 0, "metal", 8)
    cyl(0.08, 1.2, 0, 0, 0.1, "metal", 6)
    for i in range(3):
        a = i * math.tau / 3
        cyl(0.04, 0.9, math.cos(a) * 0.18, math.sin(a) * 0.18, 0.1, "metal", 4, rot=(math.sin(a) * 0.3, -math.cos(a) * 0.3, 0))
    cyl(0.25, 0.4, 0, 0, 1.15, "metal", 10, r2=0.5)
    cyl(0.32, 0.6, 0, 0, 1.45, "flame", 7, r2=0.0)
    export("brazier_0", [1.0, 1.0, 1.0])


def b_signal_lamp():
    cyl(0.12, 4.0, 0, 0, 0, "metal", 6)
    box(0.6, 0.4, 1.4, 0, 0, 3.6, "metal", 0.03)
    sphere(0.18, 0, 0.22, 4.4, "glow")
    box(0.7, 0.2, 0.08, 0, 0.2, 4.65, "metal", 0.0)
    export("signal_lamp_0", [1.0, 1.0, 1.0])


def b_crystal():
    random.seed(80)
    for i in range(5):
        h = 3.0 * (1.0 - i * 0.15)
        cyl(0.45, h, (i - 2) * 0.35, random.uniform(-0.3, 0.3), 0, "glow", 6, r2=0.0,
            rot=(random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), 0))
    rock_blob(0.8, 0, 0, 0.1, "rock_dark", 81)
    export("crystal_0", [2.0, 3.0, 2.0])


# ---------------------------------------------------------------- town decor
def b_flowerbed():
    W, D = 4.0, 2.5
    box(W, D, 0.4, 0, 0, 0, "stone", 0.05)
    box(W - 0.3, D - 0.3, 0.42, 0, 0, 0.01, "soil", 0.0)
    random.seed(90)
    cols = ["flower_r", "flower_y", "cloth", "glow", "red"]
    for i in range(18):
        x = random.uniform(-W / 2 + 0.3, W / 2 - 0.3)
        y = random.uniform(-D / 2 + 0.3, D / 2 - 0.3)
        sphere(0.24, x, y, 0.5, "leaf", 1)
        sphere(0.13, x + 0.05, y, 0.72, cols[i % 5], 1)
    export("flowerbed_0", [W, 1.0, D])


def b_hedge():
    box(4.0, 1.4, 1.6, 0, 0, 0, "leaf_dark", 0.15)
    random.seed(91)
    for i in range(6):
        sphere(0.45, -1.7 + i * 0.68, random.uniform(-0.2, 0.2), 1.5, "leaf", 1, (1.0, 1.0, 0.6))
    export("hedge_0", [4.0, 1.6, 1.4])


def b_sign():
    cyl(0.08, 2.2, 0, 0, 0, "C", 6)
    box(1.7, 0.1, 0.75, 0, 0, 1.55, "cloth", 0.02)
    box(1.84, 0.08, 0.89, 0, -0.02, 1.48, "C", 0.02)
    export("sign_0", [1.0, 1.0, 1.0])


def b_gazebo():
    R, H = 3.0, 4.0
    cyl(R, 0.4, 0, 0, 0, "stone", 8, bevel=0.03)
    for i in range(8):
        a = i * math.tau / 8
        cyl(0.13, H, math.cos(a) * R * 0.88, math.sin(a) * R * 0.88, 0.4, "cloth", 8)
    cyl(R * 1.05, 0.25, 0, 0, H + 0.4, "C", 8)
    cyl(R * 1.18, H * 0.45, 0, 0, H + 0.65, "B", 8, r2=0.0)
    sphere(0.2, 0, 0, H + 0.65 + H * 0.45, "gold")
    for i in range(8):
        a = (i + 0.5) * math.tau / 8
        box(R * 0.75, 0.08, 0.08, math.cos(a) * R * 0.86, math.sin(a) * R * 0.86, 1.2, "cloth", 0.0, rot=(0, 0, a + math.pi / 2))
    export("gazebo_0", [6.0, 4.0, 6.0])


def b_fountain():
    R = 3.5
    cyl(R, 0.25, 0, 0, 0, "stone_dark", 24)
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=R, depth=0.9, end_fill_type="NOTHING", location=(0, 0, 0.45))
    o = bpy.context.active_object
    o.modifiers.new("s", "SOLIDIFY").thickness = 0.4
    _finish(o, "A")
    cyl(R - 0.3, 0.6, 0, 0, 0.05, "water", 24)
    bpy.ops.mesh.primitive_torus_add(major_radius=R - 0.2, minor_radius=0.25, major_segments=24, minor_segments=6, location=(0, 0, 0.92))
    _finish(bpy.context.active_object, "stone_dark")
    cyl(0.7, 2.0, 0, 0, 0.9, "A", 12, r2=0.5)
    cyl(R * 0.42, 0.4, 0, 0, 2.8, "A", 16, r2=R * 0.32)
    cyl(R * 0.36, 0.3, 0, 0, 2.95, "water", 16)
    cyl(0.3, 1.2, 0, 0, 3.2, "A", 8, r2=0.2)
    sphere(0.45, 0, 0, 4.6, "C")
    export("fountain_0", [7.0, 4.0, 7.0])


def b_rug():
    box(4.0, 6.0, 0.04, 0, 0, 0, "B", 0.0)
    box(3.2, 5.2, 0.05, 0, 0, 0.0, "C", 0.0)
    box(2.0, 4.0, 0.055, 0, 0, 0.0, "B", 0.0)
    export("rug_0", [4.0, 1.0, 6.0])


def b_altar():
    box(6.0, 2.5, 1.0, 0, 0, 0, "A", 0.05)
    box(6.3, 2.8, 0.2, 0, 0, 1.0, "C", 0.03)
    for sx in (-1, 1):
        cyl(0.1, 0.4, sx * 2.1, 0, 1.2, "cloth", 8)
        sphere(0.09, sx * 2.1, 0, 1.68, "flame", 1, (1, 1, 1.5))
    box(1.2, 0.8, 0.3, 0, 0, 1.2, "gold", 0.02)
    export("altar_0", [6.0, 1.0, 2.5])


def b_throne():
    box(1.6, 1.4, 0.8, 0, 0, 0, "C", 0.05)
    box(1.6, 0.3, 3.0, 0, -0.6, 0, "C", 0.05)
    box(1.3, 1.1, 0.12, 0, 0.05, 0.8, "B", 0.02)
    for sx in (-1, 1):
        box(0.25, 1.4, 0.5, sx * 0.8, 0, 0.8, "C", 0.03)
    sphere(0.3, 0, -0.6, 3.1, "gold")
    export("throne_0", [1.0, 1.0, 1.0])


def b_bell():
    cyl(1.25, 4.5, 0, 0, 0.2, "C", 16, r2=2.5)
    PARTS[-1].location.z = 0.0
    cyl(2.6, 0.3, 0, 0, 0, "C", 16)
    sphere(1.25, 0, 0, 4.5, "C", 2, (1, 1, 0.6))
    cyl(0.25, 0.8, 0, 0, 4.9, "metal", 8)
    export("bell_0", [5.0, 4.5, 5.0])


def b_statue():
    s = 0.1
    cyl(2.5, 2.5, 0, 0, 0, "stone_dark", 8)
    cyl(1.9, 1.0, 0, 0, 2.5, "stone", 8)
    cyl(1.4, 4.0, 0, 0, 3.5, "C", 12, r2=0.75)
    cyl(0.7, 1.8, 0, 0, 7.5, "C", 12, r2=0.55)
    sphere(0.5, 0, 0, 9.7, "C", 2)
    cyl(0.18, 2.0, 0.6, 0, 8.6, "C", 6, rot=(0, -0.3, 0))
    sphere(0.3, 1.0, 0, 10.6, "lamp")
    export("statue_0", [1.0, 10.0, 1.0])


def b_web():
    for i in range(6):
        box(4.0, 0.03, 0.03, 0, 0, 2.0, "web", 0.0, rot=(0, i * math.pi / 6, 0))
    for k in range(3):
        bpy.ops.mesh.primitive_torus_add(major_radius=0.4 * (k + 1), minor_radius=0.02, major_segments=6, minor_segments=3, location=(0, 0, 2.0), rotation=(math.pi / 2, 0, 0))
        _finish(bpy.context.active_object, "web")
    export("web_0", [4.0, 4.0, 1.0])


# ---------------------------------------------------------------- farm / industry
def b_field(v):
    S = 6.0
    box(S, S, 0.25, 0, 0, -0.1, "soil", 0.0)
    rows = 5
    for i in range(rows):
        y = -S / 2 + (i + 0.5) * S / rows
        box(S, 0.45, 0.2, 0, y, 0.0, "soil", 0.05)
        n = 7
        for j in range(n):
            x = -S / 2 + (j + 0.5) * S / n
            if v == 0:
                cyl(0.18, 0.9, x, y, 0.15, "wheat", 5, r2=0.0)
            elif v == 1:
                sphere(0.28, x, y, 0.35, "B", 1)
            else:
                sphere(0.22, x, y, 0.32, "red" if j % 3 == 0 else "leaf", 1)
    export("field_%d" % v, [S, 1.0, S])


def b_anvil():
    box(0.5, 0.5, 0.6, 0, 0, 0, "wood_dark", 0.03)
    box(0.9, 0.4, 0.3, 0, 0, 0.6, "metal", 0.03)
    cyl(0.2, 0.4, 0.55, 0, 0.75, "metal", 6, r2=0.0, rot=(0, math.pi / 2, 0))
    PARTS[-1].location = (0.6, 0, 0.75)
    export("anvil_0", [1.0, 1.0, 1.0])


def b_rail():
    L = 4.0
    box(L, 3.2, 0.3, 0, 0, -0.2, "stone_dark", 0.02)
    for i in range(4):
        box(0.35, 2.4, 0.15, -L / 2 + 0.5 + i, 0, 0.1, "wood_dark", 0.01)
    for sy in (-0.75, 0.75):
        box(L, 0.12, 0.15, 0, sy, 0.25, "metal", 0.0)
    export("rail_0", [L, 1.0, 3.2])


def b_mine_entrance():
    random.seed(95)
    for i in range(6):
        rock_blob(1.4, random.uniform(-3, 3), 0.6, random.uniform(0.2, 3.5), "rock", 96 + i)
    for sx in (-1, 1):
        box(0.6, 0.6, 4.0, sx * 2.2, 0, 0, "C", 0.04)
    box(5.6, 0.7, 0.6, 0, 0, 4.0, "C", 0.04)
    box(4.0, 0.2, 4.0, 0, -0.5, 0, "metal", 0.0)
    cyl(0.12, 0.3, 2.2, 0.4, 3.0, "lamp", 8)
    export("mine_entrance_0", [1.0, 1.0, 1.0])


def b_crane():
    box(2.5, 2.5, 1.0, 0, 0, 0, "metal", 0.04)
    box(0.8, 0.8, 9.0, 0, 0, 1.0, "C", 0.02)
    for i in range(6):
        box(0.9, 0.08, 0.08, 0, 0, 1.6 + i * 1.4, "metal", 0.0, rot=(0, 0.7, 0))
    box(0.6, 10.0, 0.6, 0, 3.5, 9.6, "C", 0.02)
    box(1.6, 1.6, 1.4, 0, -1.0, 9.2, "metal", 0.03)
    cyl(0.03, 4.0, 0, 8.0, 5.6, "metal", 4)
    box(1.4, 1.4, 1.0, 0, 8.0, 4.6, "C", 0.03)
    export("crane_0", [1.0, 9.0, 10.0])


def b_pipe():
    L = 12.0
    cyl(0.5, L, 0, 0, 0, "C", 10, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, L / 2, 2.5)
    for i in range(5):
        y = -L / 2 + i * L / 4
        cyl(0.6, 0.2, 0, 0, 0, "gold", 10, rot=(math.pi / 2, 0, 0))
        PARTS[-1].location = (0, y + 0.1, 2.5)
        box(0.2, 0.2, 2.5, 0, y, 0, "metal", 0.0)
    export("pipe_0", [1.0, 2.5, L])


def b_train(v):
    cars = 2 + v
    for i in range(cars):
        y = -i * 13.0
        if i == 0:
            box(3.0, 6.0, 2.6, 0, y + 3.0, 0.8, "B", 0.05)
            cyl(1.3, 7.0, 0, 0, 0, "B", 16, rot=(math.pi / 2, 0, 0))
            PARTS[-1].location = (0, y - 1.0, 2.4)
            cyl(0.45, 1.6, 0, y - 3.5, 3.3, "metal", 10)
            sphere(0.4, 0, y - 4.6, 2.6, "lamp")
            box(3.2, 6.4, 0.3, 0, y + 3.0, 3.4, "C", 0.02)
        else:
            box(3.0, 12.0, 2.8, 0, y, 0.9, "A", 0.05)
            box(3.2, 12.2, 0.3, 0, y, 3.7, "C", 0.02)
            for k in range(5):
                for sx in (-1, 1):
                    window(sx * 1.5, y - 4.4 + k * 2.2, 1.9, 1.0, 1.0, "+x" if sx > 0 else "-x")
        for k in range(3):
            for sx in (-1, 1):
                cyl(0.55, 0.2, 0, 0, 0, "metal", 12, rot=(0, math.pi / 2, 0))
                PARTS[-1].location = (sx * 1.4, y - 4.0 + k * 3.5, 0.7)
    export("train_%d" % v, [1.0, 1.0, 1.0])


# ---------------------------------------------------------------- harbor
def b_boat():
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=1.0, location=(0, 0, 0.4))
    o = bpy.context.active_object
    bm_cut = [v for v in o.data.vertices]
    o.scale = (0.8, 2.0, 0.5)
    _finish(o, "C")
    box(1.5, 3.4, 0.12, 0, 0, 0.55, "wood_dark", 0.02)
    box(1.3, 0.25, 0.1, 0, 0.6, 0.65, "C", 0.0)
    box(1.3, 0.25, 0.1, 0, -0.8, 0.65, "C", 0.0)
    export("boat_0", [1.6, 1.0, 4.0])


def b_buoy():
    cyl(0.5, 1.2, 0, 0, -0.3, "red", 10, r2=0.3)
    cyl(0.52, 0.2, 0, 0, 0.2, "cloth", 10)
    sphere(0.15, 0, 0, 1.0, "lamp")
    export("buoy_0", [1.0, 1.0, 1.0])


def b_ramp():
    W, H, D = 6.0, 3.0, 12.0
    v = [(-W / 2, -D / 2, 0), (W / 2, -D / 2, 0), (W / 2, D / 2, 0), (-W / 2, D / 2, 0), (-W / 2, D / 2, H), (W / 2, D / 2, H)]
    mesh_obj(v, [(0, 1, 5, 4), (1, 2, 5), (0, 4, 3), (2, 3, 4, 5), (0, 3, 2, 1)], "A")
    export("ramp_0", [W, H, D])


# ---------------------------------------------------------------- tall structures
def b_windmill():
    H = 14.0
    cyl(3.0, H, 0, 0, 0, "A", 8, r2=2.1)
    cyl(3.3, H * 0.3, 0, 0, H, "B", 8, r2=0.0)
    door(0, 2.85, 0, 1.2, 2.2)
    for k in range(2):
        window(0, 2.5 - k * 0.2, 5.0 + k * 3.5, 0.8, 1.1, "+y")
    box(0.8, 1.2, 0.8, 0, 2.6, H * 0.85 - 0.4, "C", 0.03)
    export("windmill_0", [6.0, H, 6.0])
    # 风车叶片（单独导出，游戏里绕 Z 轴旋转；轴心在原点）
    cyl(0.3, 0.6, 0, 0, 0, "C", 8, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, 0.3, 0)
    for i in range(4):
        a = i * math.pi / 2
        arm = 7.5
        box(0.18, 0.1, arm, 0, 0, 0, "C", 0.0, rot=(0, a, 0))
        PARTS[-1].location = (math.sin(a) * arm / 2, 0, math.cos(a) * arm / 2)
        box(1.4, 0.05, arm * 0.78, 0, 0, 0, "cloth", 0.0, rot=(0, a, 0))
        PARTS[-1].location = (math.sin(a) * arm * 0.55 + math.cos(a) * 0.75, 0.06, math.cos(a) * arm * 0.55 - math.sin(a) * 0.75)
    export("windmill_blades_0", [1.0, 1.0, 1.0])


def b_clocktower():
    W, H = 8.0, 18.0
    box(W + 0.6, W + 0.6, 2.8, 0, 0, -2.5, "stone_dark", 0.05)
    box(W, W, H, 0, 0, 0, "A", 0.04)
    for f in range(1, int(H / 5)):
        box(W + 0.25, W + 0.25, 0.25, 0, 0, f * 5.0, "C", 0.02)
    for i, (dx, dy, rz) in enumerate([(0, 1, 0), (0, -1, math.pi), (1, 0, -math.pi / 2), (-1, 0, math.pi / 2)]):
        cyl(W * 0.35, 0.3, 0, 0, 0, "cloth", 24, rot=(math.pi / 2, 0, rz))
        PARTS[-1].location = (dx * (W / 2 + 0.12), dy * (W / 2 + 0.12), H * 0.82)
        bpy.ops.mesh.primitive_torus_add(major_radius=W * 0.36, minor_radius=0.15, major_segments=24, minor_segments=4,
                                         location=(dx * (W / 2 + 0.2), dy * (W / 2 + 0.2), H * 0.82), rotation=(math.pi / 2, 0, rz))
        _finish(bpy.context.active_object, "gold")
        box(0.15 if dy else 0.1, 0.1 if dy else 0.15, W * 0.28, dx * (W / 2 + 0.3), dy * (W / 2 + 0.3), H * 0.82, "metal", 0.0)
    box(W + 0.6, W + 0.6, 0.6, 0, 0, H, "C", 0.03)
    cyl(W * 0.75, W * 1.2, 0, 0, H + 0.6, "B", 4, r2=0.0, rot=(0, 0, math.pi / 4))
    door(0, W / 2, 0, 1.6, 2.6)
    export("clocktower_0", [W, H, W])


def b_dome():
    R, H = 4.5, 6.0
    cyl(R, H, 0, 0, 0, "A", 20)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=R * 1.02, location=(0, 0, H))
    o = bpy.context.active_object
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[vv for vv in bm.verts if vv.co.z < -0.01], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    _finish(o, "B")
    box(R * 0.35, R * 2.1, R * 1.1, 0, 0, H + 0.1, "metal", 0.0)
    cyl(R * 0.15, R * 1.4, 0, -R * 0.4, H + R * 0.5, "gold", 10, rot=(-0.9, 0, 0))
    door(0, R - 0.05, 0, 1.4, 2.5)
    for i in range(6):
        a = i * math.tau / 6 + 0.5
        window(math.sin(a) * R, math.cos(a) * R, H * 0.45, 0.8, 1.4, "+y" if math.cos(a) > 0.7 else ("-y" if math.cos(a) < -0.7 else ("+x" if math.sin(a) > 0 else "-x")))
    export("dome_0", [R * 2, H, R * 2])


def b_portal_ring():
    R = 2.5
    cyl(R * 1.35, 0.6, 0, 0, 0, "stone_dark", 24)
    bpy.ops.mesh.primitive_torus_add(major_radius=R * 0.92, minor_radius=R * 0.1, major_segments=32, minor_segments=8, location=(0, 0, R + 0.8), rotation=(math.pi / 2, 0, 0))
    _finish(bpy.context.active_object, "gold")
    cyl(R * 0.85, 0.05, 0, 0, 0, "glow", 32, rot=(math.pi / 2, 0, 0))
    PARTS[-1].location = (0, 0.025, R + 0.8)
    for i in range(6):
        a = i * math.tau / 6
        sphere(0.2, math.cos(a) * R, 0, R + 0.8 + math.sin(a) * R, "glow")
    export("portal_ring_0", [5.0, 1.0, 5.0])


# ---------------------------------------------------------------- forest vegetation (used by Forest MultiMesh: material "B" = leaf tint)
def b_bush():
    for (x, y, z, r) in [(0, 0, 0.55, 0.9), (0.55, 0.1, 0.45, 0.6), (-0.5, -0.15, 0.4, 0.55), (0.1, -0.4, 0.75, 0.5)]:
        sphere(r, x, y, z, "B", 2, (1, 1, 0.75))
    export("bush_0", [1.8, 1.2, 1.8])


def b_rock():
    rock_blob(1.0, 0, 0, 0.3, "rock", 120)
    rock_blob(0.6, 0.75, 0.3, 0.2, "rock_dark", 121)
    export("rock_0", [2.0, 1.0, 2.0])


def b_flower():
    cyl(0.02, 0.4, 0, 0, 0, "leaf", 4)
    sphere(0.12, 0, 0, 0.42, "B", 1)
    export("flower_0", [0.3, 0.5, 0.3])


PROP_BUILDERS = {
    "ruin_wall_0": lambda: b_ruin_wall(0), "ruin_wall_1": lambda: b_ruin_wall(1), "column_0": b_column,
    "pillar_0": lambda: b_pillar(0), "pillar_1": lambda: b_pillar(1), "pillar_row_0": b_pillar_row, "arch_0": b_arch,
    "obelisk_0": b_obelisk, "grave_0": b_grave, "block_0": lambda: b_block(0), "block_1": lambda: b_block(1), "platform_0": b_platform,
    "campfire_0": b_campfire, "brazier_0": b_brazier, "signal_lamp_0": b_signal_lamp, "crystal_0": b_crystal,
    "flowerbed_0": b_flowerbed, "hedge_0": b_hedge, "sign_0": b_sign, "gazebo_0": b_gazebo, "fountain_0": b_fountain,
    "rug_0": b_rug, "altar_0": b_altar, "throne_0": b_throne, "bell_0": b_bell, "statue_0": b_statue, "web_0": b_web,
    "field_0": lambda: b_field(0), "field_1": lambda: b_field(1), "field_2": lambda: b_field(2), "anvil_0": b_anvil,
    "rail_0": b_rail, "mine_entrance_0": b_mine_entrance, "crane_0": b_crane, "pipe_0": b_pipe,
    "train_0": lambda: b_train(0), "train_1": lambda: b_train(1), "boat_0": b_boat, "buoy_0": b_buoy, "ramp_0": b_ramp,
    "windmill_0": b_windmill, "clocktower_0": b_clocktower, "dome_0": b_dome, "portal_ring_0": b_portal_ring,
    "bush_0": b_bush, "rock_0": b_rock, "flower_0": b_flower,
}
run_builders(PROP_BUILDERS)
