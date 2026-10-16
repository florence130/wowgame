# 木筋构架：把一栋房子外墙 / 山墙上所有木构件（立柱、顶梁、腰梁、斜撑、封檐梁）收集成实体，
# 用 Blender 精确布尔求并成「一整块」构架（相交处没有重叠面 / 闪面，节点是真正的榫接），
# 再对外露的硬边做圆润倒角、加一点手作式的低频起伏，最后一次性写进 Geo（木材质，K|6 三向投影木纹）。
# 2026-10-10 用户：木条框架用长方体拼接、风格不统一 → 统一截面规则 + 布尔求并 + 倒角（洛奇M 的木构件是圆润的）。
import math
import bpy, bmesh
from mathutils import Vector, Matrix


def _cube(sx, sy, sz, M):
    """闭合盒：x、y 居中，z 从 0 到 sz（局部），再乘 M。返回 (verts, faces)。"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * sx, v.co.y * sy, v.co.z * sz + sz / 2))
    bm.transform(M)
    bm.verts.ensure_lookup_table()
    vs = [tuple(v.co) for v in bm.verts]
    fs = [[v.index for v in f.verts] for f in bm.faces]
    bm.free()
    return vs, fs


class Collector:
    """接口和 Geo.box / Geo.beam 一致（g、mk 参数被忽略），先收集，emit 时一次求并。"""

    def __init__(self):
        self.solids = []

    def box(self, g, mk, sx, sy, sz, M=Matrix.Identity(4)):
        self.solids.append(_cube(sx, sy, sz, M))

    def beam(self, g, mk, a, b, w, h, up=(0, 0, 1)):
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
        self.solids.append(_cube(w, h, L, R))

    def emit(self, G, mk, group="S", bevel=0.022, warp=0.007):
        if not self.solids:
            return
        try:
            vs, fs = self._union()
        except Exception as e:                                   # 布尔失败：退回逐件原样输出，不丢构件
            print("TIMBER union failed, fallback:", repr(e)[:120], flush=True)
            for v, f in self.solids:
                G.raw(group, mk, v, f)
            self.solids = []
            return
        bm = bmesh.new()
        mv = [bm.verts.new(v) for v in vs]
        for f in fs:
            try:
                bm.faces.new([mv[i] for i in f])
            except ValueError:
                pass
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        # 不再做共面合并：带孔的共面大面会被合成无法表示的 n 边形，导出三角化后把灰泥格子「填死」（游戏里出现整块深色三角）。先自己三角化，再倒角
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
        bm.edges.ensure_lookup_table()
        sharp = [e for e in bm.edges if len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(35)]
        if bevel > 0 and sharp:
            bmesh.ops.bevel(bm, geom=sharp, offset=bevel, offset_type="OFFSET", segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
        # 手作起伏：低频位移（木料不是绝对笔直）
        for v in bm.verts:
            p = v.co
            v.co = p + Vector((math.sin(2.3 * p.y + 4.1 * p.z), math.sin(1.9 * p.x + 3.3 * p.z), math.sin(2.7 * p.x + 2.1 * p.y))) * warp
        bm.verts.ensure_lookup_table()
        bm.faces.ensure_lookup_table()
        self._orient(bm)
        idx = {v: i for i, v in enumerate(bm.verts)}          # 不用 v.index：布尔 / 倒角 / 三角化后索引可能是过期的
        G.raw(group, mk, [tuple(v.co) for v in bm.verts], [[idx[v] for v in f.verts] for f in bm.faces], keep=True)
        bm.free()
        self.solids = []

    @staticmethod
    def _orient(bm):
        """逐个连通块确认法线朝外：最高顶点处的面法线应朝上，否则整块翻转（Geo.finish 的法线重算对退化三角不可靠，木筋面标记为 keep 不再重算）。"""
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        bm.normal_update()
        bm.faces.ensure_lookup_table()
        seen = set()
        for f0 in bm.faces:
            if f0 in seen:
                continue
            isl, stack = [], [f0]
            seen.add(f0)
            while stack:
                f = stack.pop()
                isl.append(f)
                for e in f.edges:
                    for nf in e.link_faces:
                        if nf not in seen:
                            seen.add(nf)
                            stack.append(nf)
            # 闭合流形：有向体积 Σ(中心·法线·面积)/3 为正 = 朝外；为负则整块翻转（顶点法线判法在带孔 / 环形构架上不可靠）
            vol = sum(f.calc_center_median().dot(f.normal) * f.calc_area() for f in isl) / 3.0
            if vol < 0:
                bmesh.ops.reverse_faces(bm, faces=isl)

    def _union(self):
        coll = bpy.data.collections.new("tf_ops")
        bpy.context.scene.collection.children.link(coll)
        objs = []
        for i, (v, f) in enumerate(self.solids):
            me = bpy.data.meshes.new("tf%d" % i)
            me.from_pydata(v, [], f)
            me.update()
            ob = bpy.data.objects.new("tf%d" % i, me)
            (bpy.context.scene.collection if i == 0 else coll).objects.link(ob)
            objs.append(ob)
        base = objs[0]
        md = base.modifiers.new("u", "BOOLEAN")
        md.operation = "UNION"
        md.operand_type = "COLLECTION"
        md.collection = coll
        md.solver = "EXACT"
        dg = bpy.context.evaluated_depsgraph_get()
        ev = base.evaluated_get(dg)
        me = ev.to_mesh()
        vs = [tuple(v.co) for v in me.vertices]
        fs = [list(p.vertices) for p in me.polygons]
        ev.to_mesh_clear()
        for ob in objs:
            m = ob.data
            bpy.data.objects.remove(ob)
            bpy.data.meshes.remove(m)
        bpy.data.collections.remove(coll)
        return vs, fs





