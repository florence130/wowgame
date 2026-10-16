# Bake seamless stylized terrain textures (hand-painted look) with Blender procedural nodes.
# Run: blender -b --factory-startup --python tools/blender/bake_terrain.py -- <out_dir> [size]
# Tileable: every noise/voronoi is sampled in 4D on a torus (cos/sin of U and V), so edges wrap.
import bpy, sys, math, os

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(os.getcwd(), "assets", "textures", "terrain")
SIZE = int(argv[1]) if len(argv) > 1 else 512
os.makedirs(OUT, exist_ok=True)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 4
scene.cycles.device = "CPU"
for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
bpy.ops.mesh.primitive_plane_add(size=2.0)
plane = bpy.context.active_object


class G:
    """Tiny node-graph helper."""
    def __init__(self, name):
        self.mat = bpy.data.materials.new(name)
        self.mat.use_nodes = True
        self.nt = self.mat.node_tree
        self.nt.nodes.clear()
        self.out = self.nt.nodes.new("ShaderNodeOutputMaterial")
        uv = self.nt.nodes.new("ShaderNodeTexCoord")
        sep = self.nt.nodes.new("ShaderNodeSeparateXYZ")
        self.link(uv.outputs["UV"], sep.inputs[0])
        self.u = sep.outputs[0]
        self.v = sep.outputs[1]

    def link(self, a, b):
        self.nt.links.new(a, b)

    def math(self, op, a, b=None, val=None):
        n = self.nt.nodes.new("ShaderNodeMath")
        n.operation = op
        self._in(n.inputs[0], a)
        if b is not None:
            self._in(n.inputs[1], b)
        return n.outputs[0]

    def _in(self, sock, v):
        if isinstance(v, (int, float)):
            sock.default_value = v
        elif isinstance(v, tuple):
            sock.default_value = v if len(v) == 4 else (*v, 1.0)
        else:
            self.link(v, sock)

    def torus(self, freq):
        """Return (vec3 socket, w socket) mapping UV onto a 4D torus scaled by freq (integer = seamless)."""
        r = freq / (2.0 * math.pi)
        au = self.math("MULTIPLY", self.u, 2.0 * math.pi)
        av = self.math("MULTIPLY", self.v, 2.0 * math.pi)
        cu = self.math("MULTIPLY", self.math("COSINE", au), r)
        su = self.math("MULTIPLY", self.math("SINE", au), r)
        cv = self.math("MULTIPLY", self.math("COSINE", av), r)
        sv = self.math("MULTIPLY", self.math("SINE", av), r)
        comb = self.nt.nodes.new("ShaderNodeCombineXYZ")
        self.link(cu, comb.inputs[0]); self.link(su, comb.inputs[1]); self.link(cv, comb.inputs[2])
        return comb.outputs[0], sv

    def noise(self, freq, detail=4.0, rough=0.55, distort=0.0, seed=0.0):
        vec, w = self.torus(freq)
        n = self.nt.nodes.new("ShaderNodeTexNoise")
        n.noise_dimensions = "4D"
        n.inputs["Scale"].default_value = 1.0
        n.inputs["Detail"].default_value = detail
        n.inputs["Roughness"].default_value = rough
        n.inputs["Distortion"].default_value = distort
        self.link(vec, n.inputs["Vector"])
        self.link(self.math("ADD", w, seed * 17.31), n.inputs["W"])
        return n.outputs["Fac"]

    def voronoi(self, freq, feature="F1", out="Distance", rand=1.0, seed=0.0):
        vec, w = self.torus(freq)
        n = self.nt.nodes.new("ShaderNodeTexVoronoi")
        n.voronoi_dimensions = "4D"
        n.feature = feature
        n.inputs["Scale"].default_value = 1.0
        n.inputs["Randomness"].default_value = rand
        self.link(vec, n.inputs["Vector"])
        self.link(self.math("ADD", w, seed * 23.7), n.inputs["W"])
        return n.outputs[out]

    def ramp(self, fac, stops, interp="LINEAR"):
        n = self.nt.nodes.new("ShaderNodeValToRGB")
        n.color_ramp.interpolation = interp
        els = n.color_ramp.elements
        while len(els) > 1:
            els.remove(els[-1])
        els[0].position = stops[0][0]
        els[0].color = (*stops[0][1], 1.0)
        for p, c in stops[1:]:
            e = els.new(p)
            e.color = (*c, 1.0)
        self._in(n.inputs[0], fac)
        return n.outputs[0]

    def mix(self, a, b, fac, blend="MIX"):
        n = self.nt.nodes.new("ShaderNodeMix")
        n.data_type = "RGBA"
        n.blend_type = blend
        self._in(n.inputs[0], fac)
        self._in(n.inputs[6], a)
        self._in(n.inputs[7], b)
        return n.outputs[2]

    def smooth(self, x, e0, e1):
        n = self.nt.nodes.new("ShaderNodeMapRange")
        n.interpolation_type = "SMOOTHSTEP"
        n.inputs[1].default_value = e0
        n.inputs[2].default_value = e1
        self._in(n.inputs[0], x)
        return n.outputs[0]

    def emit(self, color):
        e = self.nt.nodes.new("ShaderNodeEmission")
        self.link(color, e.inputs[0])
        self.link(e.outputs[0], self.out.inputs["Surface"])


def hexc(h):
    h = h.lstrip("#")
    return tuple((int(h[i:i + 2], 16) / 255.0) ** 2.2 for i in (0, 2, 4))  # sRGB -> linear


def grass_base(g, c0, c1, c2, seed=0.0):
    big = g.noise(3, 3.0, 0.5, seed=seed)
    mid = g.noise(9, 5.0, 0.6, 0.3, seed=seed + 1)
    fine = g.noise(40, 2.0, 0.5, seed=seed + 2)
    col = g.ramp(big, [(0.3, c0), (0.55, c1), (0.75, c2)])
    col = g.mix(col, g.ramp(mid, [(0.35, c0), (0.65, c2)]), 0.35)
    # 细小笔触：亮/暗点
    dots = g.smooth(fine, 0.62, 0.72)
    col = g.mix(col, g.ramp(fine, [(0.0, c2), (1.0, tuple(min(1.0, x * 1.25) for x in c2))]), g.math("MULTIPLY", dots, 0.45))
    return col


def tex_grass(g):
    g.emit(grass_base(g, hexc("6f9a3e"), hexc("82ad48"), hexc("9cc45a")))


def tex_grass_dark(g):
    col = grass_base(g, hexc("3f6630"), hexc("4d7836"), hexc("5f8a3e"), seed=3)
    leaf = g.smooth(g.noise(14, 4.0, 0.6, seed=4), 0.6, 0.7)
    g.emit(g.mix(col, g.ramp(leaf, [(0.0, hexc("5a4a30")), (1.0, hexc("6e5a38"))]), g.math("MULTIPLY", leaf, 0.5)))


def tex_dirt(g):
    base = g.ramp(g.noise(5, 4.0, 0.55, seed=5), [(0.25, hexc("8a6a46")), (0.55, hexc("a3805a")), (0.8, hexc("b8966a"))])
    peb = g.voronoi(28, "F1", "Distance", 1.0, seed=6)
    pm = g.math("SUBTRACT", 1.0, g.smooth(peb, 0.05, 0.12))
    sel = g.smooth(g.voronoi(28, "F1", "Color", 1.0, seed=6), 0.0, 1.0)
    pebc = g.ramp(g.noise(28, 1.0, 0.5, seed=7), [(0.3, hexc("9a8a78")), (0.7, hexc("c8b8a0"))])
    g.emit(g.mix(base, pebc, g.math("MULTIPLY", pm, 0.7)))


def tex_rock(g):
    strata = g.noise(4, 6.0, 0.65, 1.2, seed=8)
    base = g.ramp(strata, [(0.25, hexc("7d7a72")), (0.5, hexc("96928a")), (0.75, hexc("b0aca2"))])
    cr = g.voronoi(10, "DISTANCE_TO_EDGE", "Distance", 1.0, seed=9)
    crack = g.math("SUBTRACT", 1.0, g.smooth(cr, 0.0, 0.035))
    g.emit(g.mix(base, (0.18, 0.17, 0.16, 1.0), g.math("MULTIPLY", crack, 0.6)))


def tex_sand(g):
    base = g.ramp(g.noise(6, 3.0, 0.5, seed=10), [(0.3, hexc("d9c79a")), (0.7, hexc("ecdcb0"))])
    rip = g.math("SINE", g.math("ADD", g.math("MULTIPLY", g.v, 2 * math.pi * 14), g.math("MULTIPLY", g.noise(4, 2.0, 0.5, seed=11), 4.0)))
    rip = g.smooth(rip, 0.4, 1.0)
    grain = g.smooth(g.noise(60, 1.0, 0.5, seed=12), 0.6, 0.75)
    col = g.mix(base, (0.95, 0.9, 0.78, 1.0), g.math("MULTIPLY", rip, 0.25))
    g.emit(g.mix(col, (0.62, 0.55, 0.42, 1.0), g.math("MULTIPLY", grain, 0.3)))


def tex_cobble(g):
    d = g.voronoi(10, "F1", "Distance", 0.8, seed=13)
    edge = g.voronoi(10, "DISTANCE_TO_EDGE", "Distance", 0.8, seed=13)
    cellc = g.voronoi(10, "F1", "Color", 0.8, seed=13)
    tone = g.ramp(g.math("MULTIPLY", g.math("ADD", g.math("ADD", g.math("POWER", cellc, 1.0), 0.0), 0.0), 1.0),
                  [(0.0, hexc("cfc6b4")), (0.5, hexc("e2dccd")), (1.0, hexc("bdb4a0"))])
    tone = g.mix(tone, g.ramp(g.noise(24, 3.0, 0.5, seed=14), [(0.3, hexc("b8ae98")), (0.7, hexc("ece6d8"))]), 0.35)
    grout = g.math("SUBTRACT", 1.0, g.smooth(edge, 0.02, 0.07))
    bevel = g.smooth(edge, 0.0, 0.18)
    tone = g.mix((0.55, 0.52, 0.47, 1.0), tone, g.math("ADD", g.math("MULTIPLY", bevel, 0.35), 0.65))
    g.emit(g.mix(tone, (0.32, 0.31, 0.28, 1.0), g.math("MULTIPLY", grout, 0.85)))


def tex_farm(g):
    base = g.ramp(g.noise(6, 4.0, 0.55, seed=15), [(0.3, hexc("6e4e30")), (0.7, hexc("8a6440"))])
    fur = g.math("SINE", g.math("MULTIPLY", g.u, 2 * math.pi * 16))
    ridge = g.smooth(fur, 0.2, 0.9)
    col = g.mix(base, g.ramp(g.noise(30, 2.0, 0.5, seed=16), [(0.3, hexc("9a7650")), (0.7, hexc("ae8a5e"))]), g.math("MULTIPLY", ridge, 0.6))
    g.emit(col)


def tex_flowers(g):
    col = grass_base(g, hexc("7aa848"), hexc("8cba52"), hexc("a8d066"), seed=17)
    pts = g.voronoi(36, "F1", "Distance", 1.0, seed=18)
    pick = g.voronoi(36, "F1", "Color", 1.0, seed=18)
    dot = g.math("SUBTRACT", 1.0, g.smooth(pts, 0.06, 0.11))
    show = g.smooth(g.noise(5, 2.0, 0.5, seed=19), 0.45, 0.6)
    fcol = g.ramp(pick, [(0.0, hexc("ffffff")), (0.33, hexc("ffb0c8")), (0.66, hexc("ffe070")), (1.0, hexc("c8a8ff"))], "CONSTANT")
    g.emit(g.mix(col, fcol, g.math("MULTIPLY", dot, show)))


def tex_moss(g):
    col = g.ramp(g.noise(7, 6.0, 0.65, 0.4, seed=20), [(0.25, hexc("3c4a2c")), (0.55, hexc("4e5e36")), (0.8, hexc("62703e"))])
    sp = g.smooth(g.noise(32, 2.0, 0.5, seed=21), 0.6, 0.72)
    g.emit(g.mix(col, (0.12, 0.13, 0.09, 1.0), g.math("MULTIPLY", sp, 0.4)))


TEXTURES = [("t0_grass", tex_grass), ("t1_grass_dark", tex_grass_dark), ("t2_dirt", tex_dirt), ("t3_rock", tex_rock),
            ("t4_sand", tex_sand), ("t5_cobble", tex_cobble), ("t6_farm", tex_farm), ("t7_flowers", tex_flowers), ("t8_moss", tex_moss)]

only = set(argv[2].split(",")) if len(argv) > 2 else None
for name, fn in TEXTURES:
    if only and name not in only:
        continue
    g = G(name)
    fn(g)
    img = bpy.data.images.new(name, SIZE, SIZE, alpha=False)
    node = g.nt.nodes.new("ShaderNodeTexImage")
    node.image = img
    g.nt.nodes.active = node
    plane.data.materials.clear()
    plane.data.materials.append(g.mat)
    bpy.context.view_layer.objects.active = plane
    plane.select_set(True)
    bpy.ops.object.bake(type="EMIT", margin=0)
    img.filepath_raw = os.path.join(OUT, name + ".png")
    img.file_format = "PNG"
    img.save()
    print("BAKED", name)
print("BAKE DONE", OUT)
