# village_kit 几何累加器：按（分组 × 材质）累积 bmesh，最后每组导出一个网格对象（多材质槽）。
# 分组 'S' = 有碰撞（墙、屋顶、大件家具）；'N' = 无碰撞（玻璃、藤蔓、灌木、小摆件；对象名含 nocol，游戏端不生成碰撞）。
# 坐标：Blender Z 向上、X 向右、Y 向后（外立面朝 -Y）；导出 glTF 后 外立面朝 +Z。
import bpy, bmesh, math, random
from mathutils import Vector, Matrix
import vmat

I = Matrix.Identity(4)

def T(x=0.0, y=0.0, z=0.0):
    return Matrix.Translation((x, y, z))

def Rz(a):
    return Matrix.Rotation(a, 4, "Z")

def Rx(a):
    return Matrix.Rotation(a, 4, "X")

def Ry(a):
    return Matrix.Rotation(a, 4, "Y")

def S3(sx, sy, sz):
    return Matrix.Diagonal((sx, sy, sz, 1.0))

# 局部 (x, y) 多边形、沿局部 +z 挤出 → 世界 Y-Z 平面（山墙三角形用，沿世界 +X 挤出）
M_YZ = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
# 局部 (x, y) → 世界 (x, z)，挤出沿世界 -Y（墙板用）
M_XZ = Rx(math.pi / 2)


class Geo:
    def __init__(self):
        self.bm = {"S": bmesh.new(), "N": bmesh.new()}
        self.mats = {"S": [], "N": []}
        self.lights = []        # [(x, y, z, range, energy)] Blender 坐标
        self.smoke = []         # 烟囱口 [(x, y, z)]
        self.marks = {}
        self.keep = set()       # 朝向已自行确认的面（木筋构架）：finish() 不再重算法线

    def _mi(self, g, mk):
        if mk not in self.mats[g]:
            self.mats[g].append(mk)
        return self.mats[g].index(mk)

    def raw(self, g, mk, verts, faces, M=I, uvs=None, keep=False):
        """uvs（可选）：每个顶点一个 (u, v)，给洛奇M 图集贴图的 M| 材质用；K| 材质是三向投影，不需要 UV。"""
        bm = self.bm[g]
        mi = self._mi(g, mk)
        vs = [bm.verts.new(M @ Vector(v)) for v in verts]
        uvl = bm.loops.layers.uv.verify() if uvs is not None else None
        for f in faces:
            try:
                fc = bm.faces.new([vs[i] for i in f])
                fc.material_index = mi
                if keep:
                    self.keep.add(fc)
                if uvl is not None:
                    for lp, i in zip(fc.loops, f):
                        lp[uvl].uv = uvs[i]
            except ValueError:
                pass
    def box(self, g, mk, sx, sy, sz, M=I):
        """盒：x、y 居中，z 从 0 到 sz（局部）。木梁 / 木柱（K|6 木材质、截面 ≥ 7cm、长宽比 ≥ 2.2）自动做成「倒角方梁」：
        截面是切角八边形（洛奇M 的木构件都是圆润倒角的，不是锐利方块），三角面数只比方盒多一倍多。"""
        if mk.startswith("K|6|") and sx * sy * sz > 0.002:
            dims = sorted([sx, sy, sz])
            if dims[0] >= 0.07 and dims[2] / max(dims[1], 1e-6) >= 1.0 and dims[2] / dims[0] >= 2.2:
                if self._chamfer_box(g, mk, sx, sy, sz, M):
                    return
        hx, hy = sx / 2, sy / 2
        v = [(-hx, -hy, 0), (hx, -hy, 0), (hx, hy, 0), (-hx, hy, 0), (-hx, -hy, sz), (hx, -hy, sz), (hx, hy, sz), (-hx, hy, sz)]
        f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        self.raw(g, mk, v, f, M)

    def _chamfer_box(self, g, mk, sx, sy, sz, M):
        """八边形截面（倒角 c = 截面短边的 22%，最大 4cm）沿最长轴挤出；局部坐标同 box（x、y 居中，z 0..sz）。"""
        dims = {"x": sx, "y": sy, "z": sz}
        ax = max(dims, key=dims.get)
        if ax == "z":
            u, w, L, o = sx, sy, sz, (0.0, 0.0, 0.0)
        elif ax == "x":
            u, w, L = sy, sz, sx
        else:
            u, w, L = sx, sz, sy
        c = min(0.04, 0.22 * min(u, w))
        hu, hw = u / 2, w / 2
        ring = [(-hu + c, -hw), (hu - c, -hw), (hu, -hw + c), (hu, hw - c), (hu - c, hw), (-hu + c, hw), (-hu, hw - c), (-hu, -hw + c)]
        v = []
        for a in (0.0, L):
            for (p, q) in ring:
                if ax == "z":
                    v.append((p, q, a))
                elif ax == "x":
                    v.append((a - sx / 2, p, q + 0.0))      # 截面 (y, z)；z 本来是 0..sz，所以 q 要平移到 0..sz
                else:
                    v.append((p, a - sy / 2, q + 0.0))
        if ax != "z":
            v = [(x, y, z + sz / 2) for x, y, z in v]
        n = 8
        f = []
        for i in range(n):
            j = (i + 1) % n
            f.append((i, j, j + n, i + n))
        f.append(tuple(reversed(range(n))))
        f.append(tuple(range(n, 2 * n)))
        self.raw(g, mk, v, f, M)
        return True

    def hexa(self, g, mk, top, depth, M=I):
        """闭合六面体：top = 上表面四个点（局部坐标，按逆时针），向 -Z 挤出 depth 得到下表面。屋面瓦片用。"""
        v = [tuple(p) for p in top] + [(p[0], p[1], p[2] - depth) for p in top]
        f = [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
        self.raw(g, mk, v, f, M)
    def prism(self, g, mk, pts, depth, M=I, cap=True):
        """局部 XY 多边形（可凹），沿 +Z 挤出 depth。"""
        n = len(pts)
        v = [(p[0], p[1], 0.0) for p in pts] + [(p[0], p[1], depth) for p in pts]
        bm = self.bm[g]
        mi = self._mi(g, mk)
        vs = [bm.verts.new(M @ Vector(p)) for p in v]
        for i in range(n):
            j = (i + 1) % n
            try:
                f = bm.faces.new((vs[i], vs[j], vs[j + n], vs[i + n]))
                f.material_index = mi
            except ValueError:
                pass
        if cap:
            # 帽面用 tessellate_polygon（耳切法，支持凹多边形）自己三角化：bmesh 的 ngon 三角化会把门 / 窗洞「封死」
            from mathutils import geometry
            flat = [Vector((p[0], p[1], 0.0)) for p in pts]
            tris = geometry.tessellate_polygon([flat])
            for ring_off, flip in ((0, False), (n, True)):
                for tri in tris:
                    ids = [ring_off + i for i in tri]
                    if flip:
                        ids = ids[::-1]
                    try:
                        f = bm.faces.new([vs[i] for i in ids])
                        f.material_index = mi
                    except ValueError:
                        pass
    def cyl(self, g, mk, r1, r2, h, M=I, seg=12, cap=True):
        v, f = [], []
        if r2 <= 1e-4:      # 尖锥
            v = [(r1 * math.cos(2 * math.pi * i / seg), r1 * math.sin(2 * math.pi * i / seg), 0.0) for i in range(seg)] + [(0.0, 0.0, h)]
            f = [(i, (i + 1) % seg, seg) for i in range(seg)]
            if cap:
                f.append(tuple(reversed(range(seg))))
        else:
            for i in range(seg):
                a = 2 * math.pi * i / seg
                v.append((r1 * math.cos(a), r1 * math.sin(a), 0.0))
            for i in range(seg):
                a = 2 * math.pi * i / seg
                v.append((r2 * math.cos(a), r2 * math.sin(a), h))
            for i in range(seg):
                j = (i + 1) % seg
                f.append((i, j, j + seg, i + seg))
            if cap:
                f.append(tuple(reversed(range(seg))))
                f.append(tuple(range(seg, 2 * seg)))
        self.raw(g, mk, v, f, M)

    def ico(self, g, mk, r, M=I, sub=1, jitter=0.0, seed=1):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=sub, radius=r)
        rnd = random.Random(seed)
        if jitter:
            for vv in tmp.verts:
                vv.co *= 1.0 + rnd.uniform(-jitter, jitter)
        tmp.verts.ensure_lookup_table()
        v = [tuple(vv.co) for vv in tmp.verts]
        f = [[vv.index for vv in fc.verts] for fc in tmp.faces]
        tmp.free()
        self.raw(g, mk, v, f, M)

    def beam(self, g, mk, a, b, w, h, up=(0, 0, 1)):
        """两点之间的方梁（截面 w×h）。"""
        a, b = Vector(a), Vector(b)
        d = b - a
        L = d.length
        if L < 1e-4:
            return
        z = d.normalized()
        x = Vector(up).cross(z)
        if x.length < 1e-4:
            x = Vector((1, 0, 0)).cross(z)
        x.normalize()
        y = z.cross(x)
        R = Matrix(((x.x, y.x, z.x, a.x), (x.y, y.y, z.y, a.y), (x.z, y.z, z.z, a.z), (0, 0, 0, 1)))
        self.box(g, mk, w, h, L, R)

    def finish(self, name):
        """返回 {group: object}（空组跳过）。"""
        out = {}
        for g in ("S", "N"):
            bm = self.bm[g]
            if not bm.faces:
                continue
            bmesh.ops.recalc_face_normals(bm, faces=[f for f in bm.faces if f not in self.keep])
            me = bpy.data.meshes.new(name + g)
            bm.to_mesh(me)
            for mk in self.mats[g]:
                me.materials.append(vmat.get(mk))
            ob = bpy.data.objects.new(name if g == "S" else name + "_nocol", me)
            bpy.context.scene.collection.objects.link(ob)
            out[g] = ob
        return out

