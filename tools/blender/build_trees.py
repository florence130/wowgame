# Stylized (Mabinogi-like) vegetation: fluffy clumped broadleaf trees, layered pines, birches and bushes.
# Run: blender -b --factory-startup --python tools/blender/build_trees.py -- <out_dir>
# Output: <out_dir>/<kind>_<n>.glb, each with two mesh objects:
#   "trunk" (material "trunk") and "leaf" (material "leaf").
# Leaf vertices get *spherical* custom normals (pointing away from the canopy centre) so the crown shades like one
# soft volume instead of many faceted balls, which is the key trick of the painterly tree look.
# Vertex colour R = per-clump shade (0.75..1.15) and G = AO (inner/lower parts darker); the game's foliage shader uses them.
# Origin = trunk base, +Z up (exported as +Y up).
import bpy, bmesh, sys, os, math, random
from mathutils import Vector, noise

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(os.getcwd(), "assets", "models", "veg")
os.makedirs(OUT, exist_ok=True)


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for m in list(bpy.data.meshes):
        bpy.data.meshes.remove(m)


def get_mat(name, rgb):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    if b:
        b.inputs["Base Color"].default_value = (*rgb, 1)
        b.inputs["Roughness"].default_value = 1.0
    return m


class Builder:
    def __init__(self):
        self.bm_leaf = bmesh.new()
        self.bm_trunk = bmesh.new()
        self.leaf_info = []   # per-vertex (shade)

    # ---------------------------------------------------------------- trunk / branches
    def limb(self, p0, p1, r0, r1, seg=7):
        """Tapered cylinder between two points."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        L = d.length
        if L < 1e-4:
            return
        z = d.normalized()
        x = z.orthogonal().normalized()
        y = z.cross(x)
        ring0, ring1 = [], []
        for i in range(seg):
            a = i * math.tau / seg
            c, s = math.cos(a), math.sin(a)
            ring0.append(self.bm_trunk.verts.new(p0 + (x * c + y * s) * r0))
            ring1.append(self.bm_trunk.verts.new(p1 + (x * c + y * s) * r1))
        for i in range(seg):
            j = (i + 1) % seg
            self.bm_trunk.faces.new((ring0[i], ring0[j], ring1[j], ring1[i]))
        if r1 > 0.02:
            self.bm_trunk.faces.new(list(reversed(ring1)))
        # root flare
        return p1

    # ---------------------------------------------------------------- foliage clump
    def clump(self, c, r, sq=(1, 1, 0.85), sub=2, amt=0.22, seed=0, droop=0.0):
        rnd = random.Random(seed)
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=sub, radius=r)
        off = Vector((rnd.random() * 50, rnd.random() * 50, rnd.random() * 50))
        for v in tmp.verts:
            n = v.co.normalized()
            k = noise.noise(n * 1.9 + off) * amt + noise.noise(n * 4.3 + off) * amt * 0.45
            v.co = n * r * (1 + k)
            v.co.x *= sq[0]
            v.co.y *= sq[1]
            v.co.z *= sq[2]
            if droop and v.co.z < 0:
                v.co.z *= 1 + droop
            v.co += Vector(c)
        shade = rnd.uniform(0.85, 1.12)
        vmap = {}
        for v in tmp.verts:
            nv = self.bm_leaf.verts.new(v.co)
            vmap[v] = nv
            self.leaf_info.append(shade)
        for f in tmp.faces:
            self.bm_leaf.faces.new([vmap[v] for v in f.verts])
        tmp.free()

    def cone_tier(self, z, r, h, seed, n=11, jag=0.35):
        """Pine tier: a drooping skirt with jagged rim + a cap, for layered conifers."""
        rnd = random.Random(seed)
        top = self.bm_leaf.verts.new((0, 0, z + h))
        self.leaf_info.append(rnd.uniform(0.9, 1.1))
        rim, mid = [], []
        for i in range(n * 2):
            a = i * math.pi / n + rnd.uniform(-0.08, 0.08)
            rr = r * (1.0 if i % 2 == 0 else 1 - jag) * rnd.uniform(0.92, 1.06)
            dz = -0.35 * r * (1.0 if i % 2 == 0 else 0.6)
            rim.append(self.bm_leaf.verts.new((math.cos(a) * rr, math.sin(a) * rr, z + dz)))
            mid.append(self.bm_leaf.verts.new((math.cos(a) * rr * 0.55, math.sin(a) * rr * 0.55, z + h * 0.45)))
            self.leaf_info += [rnd.uniform(0.85, 1.05), rnd.uniform(0.95, 1.1)]
        under = self.bm_leaf.verts.new((0, 0, z + 0.15 * h))
        self.leaf_info.append(0.6)
        m = len(rim)
        for i in range(m):
            j = (i + 1) % m
            self.bm_leaf.faces.new((rim[i], rim[j], mid[j], mid[i]))
            self.bm_leaf.faces.new((mid[i], mid[j], top))
            self.bm_leaf.faces.new((rim[j], rim[i], under))

    # ---------------------------------------------------------------- output
    def finish(self, name, centre, axes, trunk_rgb, leaf_rgb, normal_mix=0.85):
        col = bpy.context.collection
        # trunk
        me_t = bpy.data.meshes.new("trunk")
        self.bm_trunk.to_mesh(me_t)
        self.bm_trunk.free()
        me_t.materials.append(get_mat("trunk", trunk_rgb))
        ot = bpy.data.objects.new("trunk", me_t)
        col.objects.link(ot)
        for p in me_t.polygons:
            p.use_smooth = True
        # leaves
        me_l = bpy.data.meshes.new("leaf")
        self.bm_leaf.to_mesh(me_l)
        self.bm_leaf.free()
        me_l.materials.append(get_mat("leaf", leaf_rgb))
        ol = bpy.data.objects.new("leaf", me_l)
        col.objects.link(ol)
        for p in me_l.polygons:
            p.use_smooth = True
        C = Vector(centre)
        A = Vector(axes)
        zmin = min(v.co.z for v in me_l.vertices)
        zmax = max(v.co.z for v in me_l.vertices)
        # vertex colours: R shade, G ambient occlusion (depth inside the crown + height)
        ca = me_l.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        nrm = []
        for i, v in enumerate(me_l.vertices):
            d = v.co - C
            e = Vector((d.x / A.x, d.y / A.y, d.z / A.z))
            el = e.length
            sph = Vector((d.x / (A.x * A.x), d.y / (A.y * A.y), d.z / (A.z * A.z))).normalized()
            n = (v.normal * (1 - normal_mix) + sph * normal_mix).normalized()
            nrm.append(n)
            hz = (v.co.z - zmin) / max(zmax - zmin, 0.01)
            ao = max(0.25, min(1.0, 0.35 + el * 0.55)) * (0.75 + 0.25 * hz)
            ca.data[i].color = (self.leaf_info[i] if i < len(self.leaf_info) else 1.0, ao, hz, 1.0)
        me_l.normals_split_custom_set_from_vertices(nrm)
        # trunk vertex colour: white (shader uses R/G too)
        ct = me_t.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for i in range(len(me_t.vertices)):
            ct.data[i].color = (1, 1, 1, 1)
        bpy.ops.object.select_all(action="DESELECT")
        ot.select_set(True)
        ol.select_set(True)
        bpy.context.view_layer.objects.active = ol
        path = os.path.join(OUT, name + ".glb")
        kw = dict(filepath=path, use_selection=True, export_format="GLB", export_yup=True, export_normals=True)
        try:
            bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", export_all_vertex_colors=False, **kw)
        except TypeError:
            try:
                bpy.ops.export_scene.gltf(export_vertex_color="ACTIVE", **kw)
            except TypeError:
                bpy.ops.export_scene.gltf(export_colors=True, **kw)
        print("EXPORTED", name, len(me_l.vertices) + len(me_t.vertices))
        clear()


TRUNK = (0.30, 0.19, 0.11)
LEAF = (0.18, 0.42, 0.12)


def oak(n):
    rnd = random.Random(100 + n)
    b = Builder()
    H = rnd.uniform(3.2, 3.8)
    lean = Vector((rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25), 0))
    top = Vector((0, 0, H)) + lean
    b.limb((0, 0, -0.3), (0, 0, 0.5), 0.5, 0.36, 8)       # root flare
    b.limb((0, 0, 0.5), top, 0.36, 0.22, 8)
    tips = []
    for i in range(4):
        a = i * math.tau / 4 + rnd.uniform(-0.4, 0.4)
        L = rnd.uniform(1.6, 2.3)
        p0 = top - Vector((0, 0, rnd.uniform(0.2, 0.9)))
        p1 = p0 + Vector((math.cos(a) * L, math.sin(a) * L, rnd.uniform(1.0, 1.8)))
        b.limb(p0, p1, 0.16, 0.07, 6)
        tips.append(p1)
    b.limb(top, top + Vector((0, 0, 1.6)), 0.2, 0.08, 6)
    C = top + Vector((0, 0, 1.9))
    R = rnd.uniform(2.6, 3.0)
    k = 0
    # big crown: central mass + clumps over branch tips + upper/side clumps
    b.clump(C, R * 0.72, (1, 1, 0.82), 2, 0.2, 200 + n * 31 + k); k += 1
    for t in tips:
        b.clump(t + Vector((0, 0, 0.35)), rnd.uniform(1.25, 1.6), (1, 1, 0.8), 2, 0.25, 200 + n * 31 + k, 0.2); k += 1
    for i in range(6):
        a = i * math.tau / 6 + rnd.uniform(0, 0.8)
        el = rnd.uniform(0.15, 0.85)
        p = C + Vector((math.cos(a) * R * 0.75 * math.cos(el), math.sin(a) * R * 0.75 * math.cos(el), R * 0.55 * math.sin(el)))
        b.clump(p, rnd.uniform(1.0, 1.45), (1, 1, 0.85), 2, 0.28, 200 + n * 31 + k, 0.15); k += 1
    b.clump(C + Vector((0, 0, R * 0.6)), rnd.uniform(1.1, 1.4), (1, 1, 0.9), 2, 0.25, 200 + n * 31 + k)
    b.finish("oak_%d" % n, C, (R * 1.15, R * 1.15, R * 0.95), TRUNK, LEAF)


def round_tree(n):
    """Smaller round fruit-tree / lollipop broadleaf (village trees)."""
    rnd = random.Random(300 + n)
    b = Builder()
    H = rnd.uniform(2.2, 2.6)
    b.limb((0, 0, -0.2), (0, 0, 0.4), 0.32, 0.22, 7)
    b.limb((0, 0, 0.4), (0.1, 0, H), 0.22, 0.14, 7)
    C = Vector((0.1, 0, H + 1.4))
    R = 1.9
    b.clump(C, R * 0.8, (1, 1, 0.9), 2, 0.18, 400 + n)
    for i in range(5):
        a = i * math.tau / 5 + rnd.uniform(0, 0.5)
        p = C + Vector((math.cos(a) * R * 0.6, math.sin(a) * R * 0.6, rnd.uniform(-0.4, 0.6)))
        b.clump(p, rnd.uniform(0.85, 1.1), (1, 1, 0.9), 2, 0.25, 410 + n * 7 + i)
    b.clump(C + Vector((0, 0, R * 0.65)), 0.95, (1, 1, 0.9), 2, 0.25, 420 + n)
    b.finish("round_%d" % n, C, (R * 1.1, R * 1.1, R), TRUNK, LEAF)


def pine(n):
    rnd = random.Random(500 + n)
    b = Builder()
    H = rnd.uniform(8.5, 10.0)
    b.limb((0, 0, -0.2), (0, 0, H * 0.75), 0.32, 0.1, 7)
    tiers = 5
    for i in range(tiers):
        t = i / (tiers - 1)
        z = 1.4 + t * (H - 3.2)
        r = (2.7 - t * 2.0) * rnd.uniform(0.95, 1.05)
        b.cone_tier(z, r, 1.9 - t * 0.5, 600 + n * 11 + i, 9 + (tiers - i), 0.32)
    b.cone_tier(H - 1.6, 0.75, 1.6, 650 + n, 6, 0.25)
    b.finish("pine_%d" % n, (0, 0, H * 0.5), (2.6, 2.6, H * 0.6), TRUNK, (0.12, 0.30, 0.13), 0.55)


def birch(n):
    rnd = random.Random(700 + n)
    b = Builder()
    H = rnd.uniform(5.0, 5.8)
    b.limb((0, 0, -0.2), (0.15, 0, H), 0.2, 0.09, 7)
    C = Vector((0.15, 0, H + 0.6))
    for i in range(5):
        p = C + Vector((rnd.uniform(-0.8, 0.8), rnd.uniform(-0.8, 0.8), -1.2 + i * 0.75))
        b.clump(p, rnd.uniform(0.9, 1.2), (0.9, 0.9, 1.15), 2, 0.28, 800 + n * 9 + i, 0.3)
    b.finish("birch_%d" % n, C, (1.6, 1.6, 2.6), (0.88, 0.86, 0.80), (0.36, 0.62, 0.20))


def bush(n):
    rnd = random.Random(900 + n)
    b = Builder()
    b.limb((0, 0, -0.1), (0, 0, 0.2), 0.1, 0.08, 5)
    C = Vector((0, 0, 0.55))
    for i in range(5):
        a = i * math.tau / 5 + rnd.uniform(0, 0.6)
        p = C + Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, rnd.uniform(-0.1, 0.25)))
        b.clump(p, rnd.uniform(0.45, 0.62), (1, 1, 0.8), 2, 0.25, 950 + n * 7 + i)
    b.clump(C + Vector((0, 0, 0.3)), 0.6, (1, 1, 0.8), 2, 0.22, 990 + n)
    b.finish("bush_%d" % n, C, (1.1, 1.1, 0.75), TRUNK, LEAF)


clear()
for i in range(3):
    oak(i)
for i in range(2):
    round_tree(i)
for i in range(2):
    pine(i)
for i in range(2):
    birch(i)
for i in range(2):
    bush(i)
print("TREES DONE")
