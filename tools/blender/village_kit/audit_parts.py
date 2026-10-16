# 构件审计：对 parts.PARTS 逐件统计 ① 左右对称度（x→-x 镜像后顶点匹配率）② 开放边（缺面 / 未封闭）③ 共面重叠面（穿模 / 闪面）；
# join 时逐个子对象报告开放边，定位是哪一块没封。
# blender -b -P tools/blender/village_kit/audit_parts.py -- [id1,id2|all]
import bpy, bmesh, math, os, sys
from mathutils import Vector, kdtree
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, "..", "modkit"))
import kit, vmat, parts, smith_parts

# 设计上不对称 / 随机的件（植被、开着的门、栅栏+门、井口吊桶等）
ASYM_OK = {"T03_door", "T08a_ivy", "T08b_bush", "T08c_flowerbed", "T08d_grass", "T09_fence", "T13_sign", "T07_tower_roof", "S01_anvil", "S02_hearth", "S03_forge_chimney", "S04_forge_shed", "S05_plaque"}


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit.COL = None
    vmat.reset()
    kit.mat = lambda key: vmat.get(kit.PAL.get(key, key))


def stats(ob):
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    kd = kdtree.KDTree(len(bm.verts))
    for i, v in enumerate(bm.verts):
        kd.insert(v.co, i)
    kd.balance()
    miss = 0
    for v in bm.verts:
        _, _, d = kd.find(Vector((-v.co.x, v.co.y, v.co.z)))
        if d > 0.02:
            miss += 1
    sym = 1.0 - miss / max(1, len(bm.verts))
    open_e = sum(1 for e in bm.edges if e.is_boundary)
    nonman = sum(1 for e in bm.edges if not e.is_manifold and not e.is_boundary)
    seen = {}
    zf = 0
    for f in bm.faces:
        c = f.calc_center_median()
        n = f.normal
        k2 = ((round(c.x / 0.004), round(c.y / 0.004), round(c.z / 0.004)), round(n.x, 1), round(n.y, 1), round(n.z, 1))
        if k2 in seen:
            zf += 1
        seen[k2] = 1
    bm.free()
    return sym, open_e, nonman, zf


def islands(ob):
    """物理合理性：按连通块拆开，报告 ① 悬空块（不贴地、不挨着任何其他块）② 大而薄的实体块（任一块最大两维 ≥ 0.9m 而最小维 < 0.1m，植物 / 玻璃 / 布除外）。"""
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bm.verts.ensure_lookup_table()
    seen, comps = set(), []
    for v0 in bm.verts:
        if v0.index in seen:
            continue
        stack, cur = [v0], []
        seen.add(v0.index)
        while stack:
            v = stack.pop(); cur.append(v)
            for e in v.link_edges:
                w = e.other_vert(v)
                if w.index not in seen:
                    seen.add(w.index); stack.append(w)
        comps.append(cur)
    boxes = []
    for c in comps:
        xs = [v.co.x for v in c]; ys = [v.co.y for v in c]; zs = [v.co.z for v in c]
        mat = None
        for f in c[0].link_faces:
            mat = ob.data.materials[f.material_index].name if f.material_index < len(ob.data.materials) else None
            break
        boxes.append(((min(xs), min(ys), min(zs)), (max(xs), max(ys), max(zs)), mat, len(c)))
    float_, thin_ = [], []
    from mathutils.bvhtree import BVHTree
    cid = {}
    for ci, c in enumerate(comps):
        for v in c:
            cid[v.index] = ci
    coords = [tuple(v.co) for v in bm.verts]
    polys = [(tuple(v.index for v in f.verts), cid[f.verts[0].index]) for f in bm.faces]
    for i, (lo, hi, mat, n) in enumerate(boxes):
        if n < 4:
            continue
        soft = mat and any(k in mat for k in ("|8|", "glass", "f0c93a", "e87aa0", "f4f0e6", "c8403a", "4a3626"))
        d = sorted([hi[k] - lo[k] for k in range(3)])
        if lo[2] > 0.03 and not soft and len(comps) < 400:
            others = [p for p, c in polys if c != i]
            mine = [p for p, c in polys if c == i]
            touch = False
            D = Vector((0.5773, 0.5774, 0.5772))

            def inside(tree, p):
                cnt, o = 0, Vector(p)
                for _ in range(40):
                    loc, nrm, fi, dist = tree.ray_cast(o, D)
                    if loc is None:
                        break
                    cnt += 1
                    o = loc + D * 1e-4
                return cnt % 2 == 1
            if others:
                tree = BVHTree.FromPolygons(coords, others)
                for v in comps[i]:
                    loc, nrm, fi, dist = tree.find_nearest(v.co)
                    if (loc is not None and dist < 0.025) or inside(tree, v.co):
                        touch = True
                        break
                mt = BVHTree.FromPolygons(coords, mine)
                if not touch and mt.overlap(tree):              # 三角面相交（穿插在一起，如栅栏条穿过横档）
                    touch = True
                if not touch:                                   # 反向：别的块的顶点在我体内（我包着别人，如腰线石圈套在烟囱上）
                    for j, c2 in enumerate(comps):
                        if j == i:
                            continue
                        l2, h2 = boxes[j][0], boxes[j][1]
                        if not all(lo[k] - 0.03 <= h2[k] and hi[k] + 0.03 >= l2[k] for k in range(3)):
                            continue
                        if any(inside(mt, v.co) for v in c2[:6]):
                            touch = True
                            break
            if not touch:
                float_.append((tuple(round(v, 2) for v in lo), tuple(round(v, 2) for v in hi), mat))
        if not soft and d[2] >= 0.9 and d[1] >= 0.5 and d[0] < 0.1:
            thin_.append((tuple(round(v, 2) for v in lo), tuple(round(v, 2) for v in hi), mat))
    bm.free()
    return float_, thin_


def diag_join(orig):
    def j(objs, name):
        for o in [o for o in objs if o is not None]:
            try:
                bm = bmesh.new(); bm.from_mesh(o.data)
                oe = sum(1 for e in bm.edges if e.is_boundary)
                nm = sum(1 for e in bm.edges if not e.is_manifold and not e.is_boundary)
                bm.free()
                ws = [o.matrix_world @ v.co if False else o.matrix_basis @ v.co for v in o.data.vertices]
                if ws:
                    kd = kdtree.KDTree(len(ws))
                    for i, p in enumerate(ws):
                        kd.insert(p, i)
                    kd.balance()
                    ms = sum(1 for p in ws if kd.find(Vector((-p.x, p.y, p.z)))[2] > 0.02)
                    if ms / len(ws) > 0.03 and name in ("well", "stall", "window", "tower_roof"):
                        print("   ASYMSUB %-14s -> %-12s miss=%d/%d" % (o.name, name, ms, len(ws)), flush=True)
                if oe or nm:
                    mats = [m.name.split("|")[2] if m.name.count("|") >= 2 else m.name for m in o.data.materials][:2]
                    print("   SUB %-14s -> %-12s open=%d nonman=%d verts=%d mat=%s" % (o.name, name, oe, nm, len(o.data.vertices), mats), flush=True)
            except Exception:
                pass
        return orig(objs, name)
    return j


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sel = args[0] if args else "all"
    todo = [p for p in parts.PARTS if sel == "all" or p[0] in sel.split(",") or p[0].split("_")[0] in sel.split(",")]
    for pid, fn, zh in todo:
        clear()
        orig_join = kit.join
        kit.join = diag_join(orig_join)
        parts.join = kit.join
        ob = fn()
        kit.join = orig_join
        parts.join = orig_join
        s, oe, nm, zf = stats(ob)
        flag = []
        if s < 0.97 and pid not in ASYM_OK:
            flag.append("ASYM")
        if oe > 0:
            flag.append("OPEN")
        if zf > 3:
            flag.append("COPLANAR")
        print("AUDIT %-16s sym=%.3f open=%d nonman=%d coplanar=%d %s" % (pid, s, oe, nm, zf, " ".join(flag)), flush=True)
        fl, th = islands(ob)
        for f in fl:
            print("   FLOAT", f, flush=True)
        for f in th:
            print("   THIN ", f, flush=True)
