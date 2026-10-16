# 村屋复杂构件库（取代 Tripo 对总图的整体转换结果）：全部用 modkit 十手法（镜像 / 阵列 / 截面挤出 / 实体化 / 曲线倒角 / 旋绕 / 曲线变形 / 桥接 / 简单形变 / 顶点）手建，
# 左右对称件只建一半再镜像，重复件用阵列；植被是「叶片 / 草叶」软卡片，不是硬块。
# 坐标沿用 modkit：墙沿 +X，外立面朝 -Y，Z 向上，原点在底面中心（墙类在洞口底边中点）；导出 glTF 后外立面朝 +Z。
# 真实米制（MMO 尺度：门 2.4×3.8m）。
import bpy, bmesh, math, os, sys, random
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "modkit"))
import kit
import vmat
from kit import T, box, profile_extrude, panel, array, mirror, curve_bevel, screw, simple_bend, curve_deform, jitter, join, apply_mods, bm_obj, new_obj, simple_taper

# 材质：沿用村屋库的手绘调色（K|mtype|RRGGBB|贴图|米）
kit.PAL.update({
    "plaster": "K|0|cdbd9a|pt_plaster|4.0", "timber": "K|6|855c3f|pt_wood|2.0", "ashlar": "K|2|b3a88f|pt_ashlar|3.2", "rubble": "K|2|9d937f|pt_rubble|2.4",
    "trim": "K|9|cfc6b2|pt_limestone|4.8", "slate": "K|3|68748a|pt_roof_slate|2.6", "terracotta": "K|4|b46a3e|pt_roof_tile|2.4", "door": "K|6|7a5236|pt_wood|1.8",
    "floor": "K|6|8a6542|pt_wood|1.6", "iron": "K|7|2b2f36|pt_metal|2.0", "glass": "K|glass|4d6a8a||0", "plant": "K|8|4f8a3c|pt_foliage|3.0", "plant2": "K|8|6aa046|pt_foliage|3.0",
    "plant3": "K|8|3f7a38|pt_foliage|3.0", "flower": "K|0|f0c93a||3.0", "flower2": "K|0|e87aa0||3.0", "flower3": "K|0|f4f0e6||3.0", "gold": "K|7|c79a3c|pt_metal|2.0",
    "red": "K|0|a8362e||3.0", "cream": "K|0|efe4c8||3.0", "berry": "K|0|c8403a||3.0", "soil": "K|0|4a3626||3.0", "shutter": "K|6|4f7a63|pt_wood|1.8",
})
kit.mat = lambda key: vmat.get(kit.PAL.get(key, key))


def set_wall(t):
    """墙厚（放大后的米）：构件里的窗 / 门 / 墙板都按它建。MMO 尺度的门洞 2.4×3.8m，30cm 的墙太薄，默认 0.6m。"""
    global T
    T = t
    kit.T = t


set_wall(0.6)


def _fill_open(ob, sides=16):
    """封口（holes_fill）：把细条（曲线倒角）两端的开口补成面。"""
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bd = [e for e in bm.edges if e.is_boundary]
    if bd:
        # 逐环走边建面（holes_fill 对共点的相邻环会漏）
        adj = {}
        for e in bd:
            for v in e.verts:
                adj.setdefault(v, []).append(e)
        seen = set()
        for e0 in bd:
            if e0 in seen:
                continue
            loop, e, v = [], e0, e0.verts[0]
            ok = True
            while True:
                seen.add(e)
                loop.append(v)
                v = e.other_vert(v)
                nxt = [x for x in adj[v] if x is not e and x not in seen]
                if not nxt:
                    ok = v is loop[0] or len(adj[v]) == 2
                    break
                e = nxt[0]
            if ok and 3 <= len(loop) <= sides:
                try:
                    bm.faces.new(loop)
                except ValueError:
                    pass
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(ob.data)
    bm.free()
    return ob


_orig_cb, _orig_screw = kit.curve_bevel, kit.screw


def curve_bevel(*a, **k):
    return _fill_open(_orig_cb(*a, **k))


def screw(name, prof, mkey, steps=16, methods=("screw",)):
    """旋绕（screw）+ 法线校正：旋转体的面必须朝外（径向）/ 平盘朝上，否则背面剔除后看不见。"""
    prof = list(prof)
    if len(prof) > 2 and abs(prof[0][0]) > 1e-4 and abs(prof[-1][0]) > 1e-4 and tuple(prof[0]) != tuple(prof[-1]):
        prof.append(tuple(prof[0]))          # 两端都离轴的开放截面 → 封成闭合环，避免旋转体两端出现开口
    ob = _orig_screw(name, prof, mkey, steps, methods)
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bm.to_mesh(ob.data); bm.free()
    _fill_open(ob, 64)
    bm = bmesh.new(); bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    vote = 0
    for f in bm.faces:
        c = f.calc_center_median()
        rad = Vector((c.x, c.y, 0.0))
        n = f.normal
        if rad.length > 0.04 and abs(n.z) < 0.9:
            vote += 1 if n.dot(rad) > 0 else -1
        elif abs(n.z) > 0.9:
            vote += 1 if n.z > 0 else -1
    if vote < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.to_mesh(ob.data); bm.free()
    return ob


kit.curve_bevel = curve_bevel
kit.screw = screw


def sym_jitter(ob, amt, seed=1, axes=(1, 1, 1)):
    """左右对称的手作抖动（vertex）：位移由 (|x|, y, z) 量化后的哈希决定，镜像顶点得到镜像位移，所以不破坏对称。"""
    # 先把对象的位置 / 旋转烘焙进网格（box() 等建出来的网格局部坐标并不以 x=0 对称），再按世界坐标算对称位移
    ob.data.transform(ob.matrix_basis)
    ob.matrix_basis = Matrix.Identity(4)
    for v in ob.data.vertices:
        key = (round(abs(v.co.x), 3), round(v.co.y, 3), round(v.co.z, 3), seed)
        r = random.Random(hash(key) & 0xFFFFFFFF)
        dx, dy, dz = (r.uniform(-amt, amt) * axes[0], r.uniform(-amt, amt) * axes[1], r.uniform(-amt, amt) * axes[2])
        v.co += Vector((dx if v.co.x >= 0 else -dx, dy, dz))
    ob["methods"] = ",".join(sorted(set(ob.get("methods", "").split(",")) | {"vertex"} - {""}))
    return ob


def wall_hole(name, w, h, mk, hole=None, t=T):
    """开洞墙板（桥接思路，精确轮廓）：hole = (kind, cx, z0, hw, hh)；z0>0 时是内洞（外框 + 洞环，耳切三角化），z0==0 时是门洞缺口（单个带缺口的多边形）。
    墙面在 y∈[-t/2, t/2]，沿 +X 展开 0..w，Z 向上；四角不切角。"""
    from mathutils import geometry
    outer = [(0.0, 0.0), (w, 0.0), (w, h), (0.0, h)]
    loops = []
    if hole is None:
        loops = [outer]
    else:
        kind, cx, z0, hw, hh = hole
        op = kit.opening_poly(kind, cx, z0, hw, hh)
        if z0 <= 1e-6:
            # 门洞缺口：opening_poly 点序 = [左下, 右下, 右弹线(, 弧点 右→左 ...), 左弹线]；缺口路径取 左下 → 左弹线 → 弧(左→右) → 右弹线 → 右下
            if kind == "arch":
                path = [op[0], op[-1]] + op[3:-1][::-1] + [op[2], op[1]]
            else:
                path = [op[0], op[3], op[2], op[1]]
            loops = [[(0.0, 0.0)] + path + [(w, 0.0), (w, h), (0.0, h)]]
        else:
            loops = [outer, op]
    bm = bmesh.new()
    vf, vb = [], []
    for lp in loops:
        vf.append([bm.verts.new((x, -t / 2, z)) for x, z in lp])
        vb.append([bm.verts.new((x, t / 2, z)) for x, z in lp])
    flat = [[Vector((x, z, 0.0)) for x, z in lp] for lp in loops]
    tris = geometry.tessellate_polygon(flat)
    # tessellate_polygon 返回的下标是各环连续拼接后的下标
    allf = [v for ring in vf for v in ring]
    allb = [v for ring in vb for v in ring]
    for tri in tris:
        try:
            bm.faces.new([allf[i] for i in tri])
            bm.faces.new([allb[i] for i in reversed(tri)])
        except ValueError:
            pass
    for ring_f, ring_b in zip(vf, vb):
        n = len(ring_f)
        for i in range(n):
            j = (i + 1) % n
            try:
                bm.faces.new((ring_f[i], ring_f[j], ring_b[j], ring_b[i]))
            except ValueError:
                pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm_obj(name, bm, mk, ("bridge", "profile_extrude"))


def B(name, sx, sy, sz, x, y, z, mk):
    return box(name, sx, sy, sz, (x, y, z), mk)


def PX(name, prof, length, mk, x0=0.0, axis="x"):
    ob = profile_extrude(name, prof, length, mk, axis)
    ob.location.x += x0
    return ob


def beam(name, a, b, w, h, mk):
    """两点间的方梁（沿 a→b；截面 w 沿 X 近似，h 沿 Y/Z 垂直方向）。"""
    a, b = Vector(a), Vector(b)
    d = b - a
    L = d.length
    ob = profile_extrude(name, [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)], L, mk, "z")
    z = d.normalized()
    x = Vector((1, 0, 0)) if abs(z.x) < 0.9 else Vector((0, 1, 0))
    y = z.cross(x).normalized()
    x = y.cross(z).normalized()
    R = Matrix(((x.x, y.x, z.x, a.x), (x.y, y.y, z.y, a.y), (x.z, y.z, z.z, a.z), (0, 0, 0, 1)))
    ob.matrix_world = R
    bpy.context.view_layer.update()
    return ob


def radial(ob, n, center=(0.0, 0.0)):
    """环形阵列（array）：把网格绕竖轴复制 n 份（先把对象的位置 / 旋转烘进网格，绕世界 Z 轴转）。"""
    ob.data.transform(ob.matrix_basis)
    ob.matrix_basis = Matrix.Identity(4)
    bm = bmesh.new(); bm.from_mesh(ob.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.spin(bm, geom=geom, cent=(center[0], center[1], 0), axis=(0, 0, 1), angle=2 * math.pi * (n - 1) / n, steps=n - 1, use_duplicate=True)
    bm.to_mesh(ob.data); bm.free()
    ob["methods"] = ",".join(sorted(set(ob.get("methods", "").split(",")) | {"array"} - {""}))
    return ob


def thin(ob, t=0.012):
    """实体化（solidify）：把单面卡片做成薄板（叶片 / 草叶 / 布）。"""
    m = ob.modifiers.new("s", "SOLIDIFY"); m.thickness = t; m.offset = 0
    apply_mods(ob)
    return ob


def at(ob, x=0.0, y=0.0, z=0.0, rz=0.0):
    """把对象整体移到 (x,y,z) 并绕 Z 转 rz（烘焙进网格，保持 methods 登记）。"""
    ob.data.transform(Matrix.Translation((x, y, z)) @ Matrix.Rotation(rz, 4, "Z") @ ob.matrix_basis)
    ob.matrix_basis = Matrix.Identity(4)
    return ob


# ---------------------------------------------------------------- 山墙式小屋顶（脊沿 Y）：两侧屋面 + 脊瓦；mirror 做另一侧
def gable_cap(w, depth, rise_ratio=0.8, mk="terracotta", over=0.35):
    """脊沿 Y 的双坡屋顶：一侧屋面（roof_side，沿 X 展开）旋 90° 后镜像；原点在檐口平面中心。w=屋面跨度，depth=沿脊长度。"""
    run = w / 2
    rs = kit.roof_side(depth, run, run * rise_ratio, mk, over, True, 0.16)
    # roof_side：沿 +X 展开 depth，坡面朝 -Y 下降。绕 Z 转 +90°，坡面朝 +X 下降；平移到脊线 x=0, y=-depth/2
    rs.data.transform(Matrix.Rotation(math.pi / 2, 4, "Z"))
    rs.data.transform(Matrix.Translation((0, -depth / 2, run * rise_ratio)))
    mirror(rs, 0, (0, 0, 0))
    rg = kit.ridge(depth, mk)
    rg.data.transform(Matrix.Rotation(math.pi / 2, 4, "Z")); rg.data.transform(Matrix.Translation((0, -depth / 2, run * rise_ratio)))
    return [rs, rg]


# ================================================================ T1 老虎窗
def p_dormer(w=2.2, h=2.0, tn=0.839):
    """老虎窗：原点在主屋面上的窗墙正面脚点，tn = 主屋面坡度 tan（颊墙下沿贴着主屋面往后升）。"""
    parts = []
    y1 = h / tn                                         # 主屋面升到檐线高度时的进深
    wall = wall_hole("dw", w, h, "plaster", ("rect", w / 2, 0.45, 0.9, 1.1))
    wall.data.transform(Matrix.Translation((-w / 2, 0, 0)))
    win = kit.window("rect", 0.9, 1.1, False, False)
    win.location = (0, 0, 0.45)
    # 两颊墙：三角板（solidify）+ 木框，镜像一份；下沿沿主屋面（0,0)→(y1,h)，上沿贴檐线 z=h；下沿再往下探 0.15 埋进屋面
    cheek = bmesh.new()
    vs = [cheek.verts.new(p) for p in ((w / 2, 0.0, -0.15), (w / 2, y1 + 0.12, h), (w / 2, 0.0, h))]
    cheek.faces.new(vs)
    ck = bm_obj("cheek", cheek, "plaster", ("solidify",))
    m = ck.modifiers.new("s", "SOLIDIFY"); m.thickness = 0.14; m.offset = 0; apply_mods(ck)
    ck.data.transform(Matrix.Translation((-0.07, 0, 0)))
    mirror(ck, 0, (0, 0, 0))
    post = B("post", 0.14, 0.14, h + 0.1, w / 2 - 0.07, -T / 2 - 0.05, 0, "timber")
    mirror(post, 0, (0, 0, 0))
    lintel = B("lintel", w + 0.1, 0.16, 0.18, 0, -T / 2 - 0.05, h - 0.05, "timber")
    sill = PX("sill", [(-T / 2 + 0.05, 0), (-T / 2 - 0.3, 0), (-T / 2 - 0.3, 0.1), (-T / 2 + 0.05, 0.16)], 1.5, "trim", -0.75)
    sill.location.z = 0.34
    droof = y1 + 0.55                                   # 老虎窗屋顶：从檐口前缘伸到屋面交线之后
    roof = gable_cap(w + 0.6, droof, 0.8, "terracotta", 0.25)
    for r in roof:
        r.data.transform(Matrix.Translation((0, droof / 2 - 0.35, h - 0.02)))
    # 前山尖：灰泥三角（截面挤出）+ 中柱，补上檐下缺的那一块墙
    gab = PX("gab", [(-w / 2 + 0.05, 0), (w / 2 - 0.05, 0), (0, 0.9)], 0.16, "plaster", 0.0, "y")
    gab.data.transform(Matrix.Translation((0, -0.08, h - 0.02)))
    kp = B("kingpost", 0.12, 0.2, 0.85, 0, -0.1, h - 0.02, "timber")
    return join([wall, win, ck, post, lintel, sill, gab, kp] + roof, "dormer")


# ================================================================ T2 石烟囱
def p_chimney(n=15, s=1.3):
    """石烟囱：n 层石块（阵列）× 边长 s；带两道腰线 + 压顶 + 一对陶罐烟帽。"""
    f = s / 1.3
    blk = B("cblk", s, s, 0.34, 0, 0, 0, "rubble")
    array(blk, n, (0, 0, 0.34))
    sym_jitter(blk, 0.025, 5, (1, 1, 0.15))
    simple_taper(blk, -0.07, (0, 0, 0))
    # 腰线石带（阵列的凸出石圈）
    z = n * 0.34
    band = B("band", s + 0.16, s + 0.16, 0.12, 0, 0, z * 0.3, "trim")
    array(band, 2, (0, 0, z * 0.45))
    cap = PX("ccap", [(-0.85 * f, 0), (0.85 * f, 0), (0.85 * f, 0.16), (0.7 * f, 0.28), (-0.7 * f, 0.28), (-0.85 * f, 0.16)], 1.7 * f, "trim", -0.85 * f, "x")
    cap.data.transform(Matrix.Translation((0, 0, z)))
    # 压顶 profile 在 YZ 平面（u=y），沿 x 挤出；y 方向已居中，不需要平移
    pot = screw("pot", [(0.0, 0), (0.22, 0), (0.2, 0.42), (0.26, 0.5), (0.0, 0.5)], "terracotta", 12)
    pot.location = (0.32 * f, 0, z + 0.26)
    mirror(pot, 0, (0, 0, 0))
    return join([blk, band, cap, pot], "chimney")


# ================================================================ T3 拱门单元（门扇半开）
def door_set(dw=1.5, dh=2.4, wall=True, steps=True, surround="trim"):
    """拱门单元，分成两组返回：frame（石拱圈 / 拱心石 / 石柱 [/ 墙板 / 台阶]，带碰撞）和 leaf（半开门扇 + 门框，无碰撞）。
    原点在门洞底边中点；门扇向屋内开，外侧台阶不会被门扇穿到。"""
    r = dw / 2
    objs = []
    if wall:
        W, H = 4.0, dh + 0.6
        w_ = wall_hole("dw", W, H, "plaster", ("arch", W / 2, 0, dw, dh))
        w_.data.transform(Matrix.Translation((-W / 2, 0, 0)))
        objs.append(w_)
    leaf, fr = kit.door("arch", dw - 0.2, dh - 0.1, t=0.14, gap=0.004)       # 14cm 厚实木门扇（MMO 尺度），板缝 4mm
    leaf.rotation_euler = (0, 0, 0)                         # 默认闭合；游戏运行时由 Godot 按玩家距离自动开合
    leaf.data.transform(Matrix.Translation((dw / 2 - 0.1, 0, 0)))
    leaf.location = (-(dw / 2 - 0.1), T / 2, 0)
    # 石拱圈（曲线倒角）+ 拱心石 + 两侧石柱（阵列石块）
    ring = curve_bevel("ring", [(r * math.cos(math.pi * i / 16) * 1.0, -T / 2 - 0.1, dh - r + (r + 0.12) * math.sin(math.pi * i / 16)) for i in range(17)], 0.14, surround, square=True)
    key = PX("key", [(-T / 2 - 0.2, 0), (-T / 2 + 0.02, 0), (-T / 2 + 0.02, 0.6), (-T / 2 - 0.2, 0.6)], 0.5, surround, -0.25)
    key.location.z = dh - 0.02
    nj = max(2, int((dh - r) / 0.45))
    jb = B("jamb", 0.38, 0.36, 0.42, -dw / 2 - 0.22, -T / 2 - 0.1, 0, surround)
    array(jb, nj, (0, 0, 0.45))
    mirror(jb, 0, (0, 0, 0))
    objs += [fr, ring, key, jb]
    if steps:
        st_ = kit.stone_steps(dw + 1.0, 3, 0.18, 0.45)
        st_.data.transform(Matrix.Translation((0, -T / 2 - 0.02, 0)))
        objs.append(st_)
    return dict(leaf=leaf, frame=join(objs, "door_frame"))


def p_door():
    d = door_set()
    return join([d["frame"], d["leaf"]], "door_unit")


# ================================================================ T4 门廊（盾徽）
def p_porch(zc=3.9, D=2.5, hw=1.55, ground=True):
    """门廊：两根立柱 + 檐托 + 横梁 + 双坡小屋顶（脊垂直于墙）+ 前山尖 + 盾徽牌 [+ 石阶 / 铺地]。
    原点在门洞底边中点（墙外面 y=-T/2 处）；D = 立柱到墙心的距离，zc = 横梁高，hw = 立柱半间距。"""
    run = hw + 0.4
    post = B("post", 0.3, 0.3, zc, hw, -D, 0, "timber")
    mirror(post, 0, (0, 0, 0))
    base = B("pbase", 0.5, 0.5, 0.2, hw, -D, 0, "trim")
    mirror(base, 0, (0, 0, 0))
    bk = kit.bracket(0.75, 0.9)                             # 檐托（L 形 + 斜撑）：两根立柱各一对
    bk.rotation_euler = (0, 0, math.radians(90))
    bk.location = (hw - 0.15, -D, zc - 0.9)
    mirror(bk, 0, (0, 0, 0))
    girder = B("girder", 2 * hw + 0.3, 0.3, 0.3, 0, -D, zc, "timber")
    sidebeam = B("sidebeam", 0.26, D, 0.26, hw, -D / 2, zc, "timber")
    mirror(sidebeam, 0, (0, 0, 0))
    rd = D + 0.7
    roof = gable_cap(2 * run, rd, 0.78, "terracotta", 0.3)
    for r in roof:
        r.data.transform(Matrix.Translation((0, -(D + 0.3) / 2, zc + 0.3)))
    # 盾徽牌：半个盾轮廓挤出后镜像（镜像）
    half = PX("shield", [(0, -0.35), (0.28, -0.12), (0.3, 0.2), (0.18, 0.3), (0, 0.34)], 0.08, "red", 0.0, "y")
    half.data.transform(Matrix.Translation((0, -(D + 0.05), zc - 0.3)))      # 盾牌贴着横梁挂：下沿 ≈ 2.1m（人 1.7m 走过门廊不会撞头）
    mirror(half, 0, (0, 0, 0))
    frame = curve_bevel("sframe", [(0.0, -(D + 0.12), zc + 0.03), (0.32, -(D + 0.12), zc - 0.13), (0.34, -(D + 0.12), zc - 0.45), (0.0, -(D + 0.12), zc - 0.67)], 0.025, "gold")
    mirror(frame, 0, (0, 0, 0))
    chain = B("chain", 0.04, 0.04, 0.12, 0, -(D + 0.08), zc - 0.06, "iron")      # 从横梁底面一直吊到盾牌顶（原来短了 15cm，盾牌悬空）
    # 前山尖：灰泥三角 + 中柱 + 横梁，补上檐下缺的山墙
    rise = run * 0.78 - 0.27
    gab = PX("gab", [(-hw - 0.05, 0), (hw + 0.05, 0), (0, rise)], 0.14, "plaster", 0.0, "y")
    gab.data.transform(Matrix.Translation((0, -(D + 0.12), zc + 0.3)))
    kp = B("kingpost", 0.16, 0.2, rise - 0.05, 0, -(D + 0.12), zc + 0.3, "timber")
    tie = B("tie", 2 * hw + 0.4, 0.2, 0.16, 0, -(D + 0.12), zc + 0.3, "timber")
    items = [post, base, bk, girder, sidebeam, gab, kp, tie] + roof + [half, frame, chain]
    if ground:
        steps = kit.stone_steps(2.4, 3, 0.17, 0.5)
        steps.data.transform(Matrix.Translation((0, -(D + 0.5), 0)))
        paving = B("pave", 2 * hw + 0.3, D + 0.1, 0.12, 0, -(D + 0.1) / 2, 0, "ashlar")
        items += [steps, paving]
    return join(items, "porch")


# ================================================================ T5 凸窗（挑阁）
def p_bay():
    d, w0, w1 = 1.6, 3.6, 2.4
    plan = [(-w0 / 2, 0), (w0 / 2, 0), (w1 / 2, -d), (-w1 / 2, -d)]
    sill = profile_extrude("sill", plan, 0.26, "timber", "z"); sill.location.z = 0.9
    body = profile_extrude("body", [(x * 0.96, y * 0.96) for x, y in plan], 2.7, "plaster", "z"); body.location.z = 1.16
    # 玻璃窗格：中间一扇 + 两斜扇（右斜扇建好后镜像）
    gl_c = B("gc", w1 - 0.5, 0.05, 1.7, 0, -d - 0.02, 1.5, "glass")
    mullion_c = B("mc", 0.06, 0.07, 1.8, 0, -d - 0.04, 1.45, "timber")
    # 斜面玻璃：贴在两个斜面上的四边形（沿斜面方向内缩，外移 0.04），右斜面建好后镜像成左斜面
    ax, ay = (w0 / 2 * 0.96), 0.0
    bx, by = (w1 / 2 * 0.96), -d * 0.96
    ex, ey = bx - ax, by - ay
    el = math.hypot(ex, ey)
    ux, uy = ex / el, ey / el
    nx, ny = uy, -ux                                   # 斜面外法线（朝 +x, -y）
    if nx < 0:
        nx, ny = -nx, -ny
    qa = (ax + ux * 0.25 + nx * 0.04, ay + uy * 0.25 + ny * 0.04)
    qb = (bx - ux * 0.25 + nx * 0.04, by - uy * 0.25 + ny * 0.04)
    gbm = bmesh.new()
    gv = [gbm.verts.new(p) for p in ((qa[0], qa[1], 1.5), (qb[0], qb[1], 1.5), (qb[0], qb[1], 3.4), (qa[0], qa[1], 3.4))]
    gbm.faces.new(gv)
    gl_s = bm_obj("gs", gbm, "glass", ("solidify",))
    ms = gl_s.modifiers.new("s", "SOLIDIFY"); ms.thickness = 0.03; ms.offset = 0; apply_mods(gl_s)
    mirror(gl_s, 0, (0, 0, 0))
    head = profile_extrude("head", [(x * 1.06, y * 1.06 - 0.04) for x, y in plan], 0.3, "timber", "z"); head.location.z = 3.86
    post = B("cpost", 0.16, 0.16, 2.9, w1 / 2 + 0.02, -d - 0.02, 1.1, "timber")
    mirror(post, 0, (0, 0, 0))
    steps_ = []
    for k, (sc, z0, hh) in enumerate(((0.9, 0.62, 0.28), (0.78, 0.36, 0.26), (0.66, 0.12, 0.24))):
        st_ = profile_extrude("corb%d" % k, [(x * sc, y * sc - d * (1 - sc) * 0.5) for x, y in plan], hh, "trim", "z"); st_.location.z = z0
        steps_.append(st_)
    corb = join(steps_, "corbel")
    roof = profile_extrude("shed", [(0.1, 0), (-d - 0.35, 0), (0.1, 0.9)], w0 + 0.5, "terracotta", "x")
    roof.location = (-(w0 + 0.5) / 2, 0, 4.16)
    return join([sill, body, gl_c, mullion_c, gl_s, head, post, corb, roof], "bay")


# ================================================================ T6 双开谷仓门
def p_barn_door():
    h, lw = 4.2, 1.6
    pl = B("pl", lw / 6 - 0.012, 0.1, h, lw / 12, 0, 0.1, "door")
    array(pl, 6, (lw / 6, 0, 0))
    rail = B("rail", lw, 0.12, 0.18, lw / 2, -0.04, 0.5, "timber")
    array(rail, 3, (0, 0, 1.6))
    brace = beam("brace", (0.05, -0.1, 0.55), (lw - 0.05, -0.1, 3.65), 0.14, 0.09, "timber")
    strap = curve_bevel("strap", [(0.0, -0.12, 1.1), (lw * 0.75, -0.12, 1.1), (lw * 0.85, -0.12, 1.16)], 0.04, "iron", square=True)
    array(strap, 2, (0, 0, 1.6))
    handle = screw("ring", [(0.08, -0.012), (0.1, 0.0), (0.08, 0.012)], "iron", 12)
    handle.rotation_euler = (math.pi / 2, 0, 0); handle.location = (lw - 0.22, -0.16, 1.9)
    leaf = join([pl, rail, brace, strap, handle], "leafR")
    leaf.data.transform(Matrix.Translation((0.0, 0, 0)))
    mirror(leaf, 0, (0, 0, 0))                                                  # 左扇 = 右扇镜像
    frame = B("jamb", 0.34, 0.34, h + 0.5, lw + 0.2, -0.05, 0, "timber")
    mirror(frame, 0, (0, 0, 0))
    head = B("head", 2 * lw + 0.74, 0.34, 0.34, 0, -0.05, h + 0.2, "timber")
    sill = B("sill", 2 * lw + 0.5, 0.5, 0.14, 0, -0.15, 0, "ashlar")
    back = B("backing", 2 * lw + 0.1, 0.12, h + 0.1, 0, 0.11, 0.1, "timber")   # 门板后的衬板：木板拼缝 / 门扇与门框之间不再透空
    return join([leaf, frame, head, sill, back], "barn_door")


# ================================================================ T7 塔楼四坡锥顶 + 风向标
def p_tower_roof(finial=True):
    prof = [(3.7, 0.0)]
    r, z = 3.4, 0.0
    for k in range(7):                                # 7 层瓦：每层一个小台阶外翻（砖瓦层叠）
        z1 = 0.62 + k * 0.5
        prof += [(r - k * 0.42 + 0.0, z1 - 0.22), (r - k * 0.42 - 0.08, z1), (r - (k + 1) * 0.42 + 0.1, z1)]
    prof += [(0.18, 4.1), (0.0, 4.2)]
    roof = screw("pyr", [(3.9, 0.0)] + [(p[0], p[1]) for p in prof[1:]], "slate", 4)
    roof.rotation_euler = (0, 0, math.pi / 4)
    kit.apply_scale(roof)
    if not finial:
        return roof
    fin = kit.finial(1.5)
    fin.location = (0, 0, 4.15)
    arm = B("arm", 0.8, 0.03, 0.03, 0.3, 0, 5.2, "iron")
    flag = PX("flag", [(0, 0), (0.55, 0.12), (0.55, 0.3), (0, 0.4)], 0.02, "red", 0.1, "y")
    flag.location = (0.4, 0, 5.1)
    return join([roof, fin, arm, flag], "tower_roof")


def p_finial():
    """塔尖：尖顶饰（旋绕）+ 横臂 + 红旗；原点在塔尖根部。"""
    fin = kit.finial(1.5)
    arm = B("arm", 0.8, 0.03, 0.03, 0.3, 0, 1.05, "iron")
    flag = PX("flag", [(0, 0), (0.55, 0.12), (0.55, 0.3), (0, 0.4)], 0.02, "red", 0.1, "y")
    flag.location = (0.4, 0, 0.95)
    return join([fin, arm, flag], "finial")


# ================================================================ T8 植被（软）：常春藤 / 灌木 / 花坛 / 草丛
def leaf_card(L=0.2, Wd=0.1, fold=0.015):
    """叶片：6 顶点折叶（中脉微折），之后 thin() 做薄板；返回 (verts, faces) 局部坐标，叶尖朝 +Y。"""
    v = [(0, 0, 0), (-Wd * 0.42, L * 0.22, fold), (-Wd * 0.5, L * 0.52, fold), (0, L, 0), (Wd * 0.5, L * 0.52, fold), (Wd * 0.42, L * 0.22, fold), (0, L * 0.45, -fold * 0.8)]
    f = [(0, 1, 6), (1, 2, 6), (2, 3, 6), (3, 4, 6), (4, 5, 6), (5, 0, 6)]
    return v, f


def cards(name, mk, placements, L=0.2, Wd=0.1):
    """叶片阵列（array）：placements=[(位置 Vector, 朝向 Vector(叶尖方向), 缩放)]；一个对象，薄板。"""
    bm = bmesh.new()
    lv, lf = leaf_card(L, Wd)
    for p, d, s in placements:
        d = Vector(d).normalized()
        y = d
        x = y.cross(Vector((0, 0, 1)))
        if x.length < 1e-3:
            x = Vector((1, 0, 0))
        x.normalize()
        z = x.cross(y).normalized()
        R = Matrix(((x.x, y.x, z.x, p.x), (x.y, y.y, z.y, p.y), (x.z, y.z, z.z, p.z), (0, 0, 0, 1))) @ Matrix.Scale(s, 4)
        vs = [bm.verts.new(R @ Vector(q)) for q in lv]
        for ff in lf:
            try:
                bm.faces.new([vs[i] for i in ff])
            except ValueError:
                pass
    ob = bm_obj(name, bm, mk, ("array", "vertex"))
    return thin(ob, 0.01)


def p_ivy(nl=70, hgt=3.4):
    """常春藤：一条上攀的藤（曲线倒角）+ 沿藤螺旋排布的叶片阵列 + 黄花。贴墙面 y=-T/2。nl = 叶数，hgt = 高度。"""
    k = hgt / 3.4
    pts = [(0.0, -T / 2 - 0.05, 0.0), (0.12, -T / 2 - 0.05, 0.8 * k), (-0.1, -T / 2 - 0.06, 1.7 * k), (0.15, -T / 2 - 0.05, 2.6 * k), (0.0, -T / 2 - 0.05, 3.4 * k)]
    vine = curve_bevel("vine", pts, 0.03, "timber")
    rnd = random.Random(4)
    pl = []
    for i in range(nl):
        t = i / (nl - 1)
        z = t * hgt
        x = 0.12 * math.sin(z * 2.2) + 0.12 * math.sin(i * 2.4)
        a = i * 2.39996
        d = Vector((math.sin(a) * 0.8, -0.35, 0.5 + math.cos(a) * 0.7)).normalized()
        pl.append((Vector((x, -T / 2 - 0.07 - 0.05 * abs(math.sin(a)), z)), d, 0.9 + 0.5 * (1 - t)))
    lv = cards("leaves", "plant", pl, 0.2, 0.12)
    lv2 = cards("leaves2", "plant2", [(Vector((p.x + 0.05, p.y - 0.03, p.z + 0.06)), Vector((d.x, d.y, d.z + 0.3)), s * 0.8) for p, d, s in pl[::2]], 0.18, 0.11)
    bl = []
    for i in range(0, 70, 8):
        t = i / 69
        bl.append(i)
    return join([vine, lv, lv2], "ivy")


def p_bush(n=0, seed=9):
    """灌木（洛奇M 式）：6 团低多边形圆团（二级 icosphere 压扁 + 顶点抖动，面状着色），叶色三种深浅交替，上面几颗红莓；不是叶片卡片，没有硬边。
    n 保留旧签名（已不用）。原点在地面中心，约 1.9 × 1.7 × 1.0 m。"""
    rnd = random.Random(seed)
    blobs = [(0.0, 0.0, 0.52, 0.66), (-0.62, 0.1, 0.4, 0.5), (0.6, -0.08, 0.42, 0.52), (0.12, 0.52, 0.36, 0.44), (-0.22, -0.5, 0.34, 0.42), (0.36, 0.38, 0.62, 0.34)]
    mks = ["plant", "plant2", "plant3", "plant", "plant2", "plant2"]
    objs = []
    for i, (x, y, z0, r) in enumerate(blobs):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
        for v in bm.verts:
            v.co.z *= 0.8
            v.co += Vector((rnd.uniform(-0.1, 0.1) * r, rnd.uniform(-0.1, 0.1) * r, rnd.uniform(-0.08, 0.08) * r))
            v.co += Vector((x, y, z0))
            v.co.z = max(v.co.z, 0.03)
        objs.append(bm_obj("blob%d" % i, bm, mks[i], ("vertex", "array")))
    bm = bmesh.new()
    for i in range(6):
        a = rnd.uniform(0, 2 * math.pi)
        rr = rnd.uniform(0.35, 0.8)
        bmesh.ops.create_icosphere(bm, subdivisions=0, radius=0.06, matrix=Matrix.Translation((math.cos(a) * rr, math.sin(a) * rr * 0.8, rnd.uniform(0.62, 0.95))))
    objs.append(bm_obj("berries", bm, "berry", ("vertex",)))
    return join(objs, "bush")

def p_flowerbed():
    """花坛：木框箱（板条阵列）+ 土 + 一排花（茎 + 五瓣花阵列旋绕）和叶丛。"""
    L, Wd, H = 2.6, 0.9, 0.5
    plank = B("pl", L, 0.05, 0.14, 0, -Wd / 2, 0, "timber")
    array(plank, 4, (0, 0, 0.125))
    mirror(plank, 1, (0, 0, 0))
    endp = B("ep", 0.05, Wd, H, L / 2, 0, 0, "timber")
    mirror(endp, 0, (0, 0, 0))
    soil = B("soil", L - 0.1, Wd - 0.1, 0.05, 0, 0, H - 0.1, "soil")
    pts = []
    rnd = random.Random(11)
    fl = []
    for i in range(7):
        for j in range(2):
            x = -L / 2 + 0.25 + i * (L - 0.5) / 6 + (0.1 if j else 0)
            y = -0.18 + j * 0.32
            fl.append((x, y, H + 0.0))
    bm = bmesh.new()
    for k, (x, y, z) in enumerate(fl):
        h = rnd.uniform(0.35, 0.6)
        # 茎
        v = [bm.verts.new((x + dx, y + dy, z + zz)) for dx, dy, zz in ((-0.012, 0, 0), (0.012, 0, 0), (0.008, 0, h), (-0.008, 0, h))]
        bm.faces.new(v)
        v = [bm.verts.new((x, y + dy, z + zz)) for dy, zz in ((-0.012, 0), (0.012, 0), (0.008, h), (-0.008, h))]
        bm.faces.new(v)
    stems = bm_obj("stems", bm, "plant3", ("vertex",))
    thin(stems, 0.006)
    cols = ["flower", "flower2", "flower3"]
    blooms = []
    for c in range(3):
        pl = []
        for k, (x, y, z) in enumerate(fl):
            if k % 3 != c:
                continue
            h = 0.4 + 0.05 * (k % 5)
            for q in range(5):
                a = q * 2 * math.pi / 5
                pl.append((Vector((x, y, z + h)), Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, 0.35)), 1.0))
        blooms.append(cards("bl%d" % c, cols[c], pl, 0.1, 0.075))
    leaves = cards("lv", "plant", [(Vector((x, y, z)), Vector((math.cos(k * 2.4), math.sin(k * 2.4), 0.9)), 1.0) for k, (x, y, z) in enumerate(fl) for _ in (0, 1)], 0.26, 0.12)
    return join([plank, endp, soil, stems] + blooms + [leaves], "flowerbed")


def p_grass(nc=6, nb=11, seed=17):
    """草丛：1 + nc 簇小草束（中心 1 + 外圈 nc），每簇 nb 片草叶；草叶是渐尖弯曲的薄带（顶点弯曲），高低、朝向、弯度各异；软、不是硬块。"""
    rnd = random.Random(seed)
    bm = bmesh.new()
    centers = [(0.0, 0.0)] + [(0.34 * math.cos(k * 2 * math.pi / nc + 0.3), 0.34 * math.sin(k * 2 * math.pi / nc + 0.3)) for k in range(nc)]
    for ci, (cx0, cy0) in enumerate(centers):
        for i in range(nb):
            a = i * 2 * math.pi / nb + rnd.uniform(-0.3, 0.3)
            h = rnd.uniform(0.38, 0.62) * (1.15 if ci == 0 else 1.0)
            bend = rnd.uniform(0.15, 0.5)
            w0 = rnd.uniform(0.022, 0.034)
            segs = 4
            vs = []
            for s in range(segs + 1):
                t = s / segs
                w = w0 * (1 - t ** 1.6)
                out = 0.02 + bend * h * t * t
                z = h * (1 - 0.12 * t * t) * t / max(t, 1e-6)
                z = h * t
                ca, sa = math.cos(a), math.sin(a)
                cx, cy = cx0 + out * ca, cy0 + out * sa
                vs.append((bm.verts.new((cx - sa * w, cy + ca * w, z)), bm.verts.new((cx + sa * w, cy - ca * w, z))))
            for s in range(segs):
                try:
                    bm.faces.new((vs[s][0], vs[s][1], vs[s + 1][1], vs[s + 1][0]))
                except ValueError:
                    pass
    g = bm_obj("blades", bm, "plant2", ("vertex", "array"))
    thin(g, 0.008)
    return join([g], "grass")


# ================================================================ T9 木栅栏 + 小门
def p_fence(gate=True):
    post = PX("post", [(-0.09, 0), (0.09, 0), (0.09, 1.3), (0, 1.42), (-0.09, 1.3)], 0.18, "timber", 0.0, "y")
    post.data.transform(Matrix.Translation((0, -0.09, 0)))
    pk = PX("picket", [(-0.07, 0), (0.07, 0), (0.07, 1.0), (0, 1.16), (-0.07, 1.0)], 0.05, "timber", 0.0, "y")
    pk.data.transform(Matrix.Translation((0.32, -0.025, 0.1)))
    array(pk, 7, (0.4, 0, 0))
    rail = B("rail", 3.1, 0.06, 0.12, 1.5, 0.045, 0.3, "timber")
    array(rail, 2, (0, 0, 0.55))
    p2 = post.copy(); p2.data = post.data.copy(); kit._link(p2); p2.data.transform(Matrix.Translation((3.0, 0, 0)))
    sec = join([post, p2, pk, rail], "fence_sec")
    if not gate:
        return sec
    # 门：框 + 板条 + 斜撑（同一套手法）；放在栅栏段右侧 0.4m 处
    gl = 1.2
    gf = B("gframe", gl, 0.07, 0.12, gl / 2, 0, 0.25, "timber")
    array(gf, 2, (0, 0, 0.7))
    gp = PX("gpk", [(-0.06, 0), (0.06, 0), (0.06, 1.0), (0, 1.12), (-0.06, 1.0)], 0.05, "door", 0.0, "y")
    gp.data.transform(Matrix.Translation((0.09, -0.03, 0.12)))
    array(gp, 6, (0.2, 0, 0))
    gb = beam("gbrace", (0.04, 0.05, 0.28), (gl - 0.04, 0.05, 1.0), 0.1, 0.08, "timber")
    hinge = curve_bevel("hinge", [(0.0, 0.05, 0.4), (0.35, 0.05, 0.4)], 0.025, "iron", square=True)
    array(hinge, 2, (0, 0, 0.7))
    gate = join([gf, gp, gb, hinge], "gate")
    gate.data.transform(Matrix.Translation((3.5, 0, 0)))
    gpost = post.copy() if False else None
    return join([sec, gate], "fence")


# ================================================================ T10 石井
def p_well():
    seg = B("blk", 0.62, 0.42, 0.34, 1.08, 0, 0, "rubble")
    seg2 = B("blk2", 0.62, 0.42, 0.34, 1.08, 0, 0.34, "rubble")
    radial(seg, 14); radial(seg2, 14)
    seg2.data.transform(Matrix.Rotation(math.pi / 14, 4, "Z"))
    sym_jitter(seg, 0.02, 3); sym_jitter(seg2, 0.02, 4)
    cap = screw("coping", [(1.5, 0.58), (1.5, 0.8), (0.8, 0.8), (0.8, 0.58), (1.5, 0.58)], "trim", 28)     # 22cm 厚压顶石，嵌进石块顶
    water = screw("water", [(0.0, 0.3), (0.82, 0.3), (0.82, 0.27), (0.0, 0.27)], "glass", 16)
    post = B("post", 0.2, 0.2, 2.6, 1.0, 0, 0.7, "timber")
    mirror(post, 0, (0, 0, 0))
    crossb = B("cross", 2.4, 0.18, 0.2, 0, 0, 2.5, "timber")
    roof = gable_cap(3.4, 2.9, 0.82, "terracotta", 0.3)
    for r in roof:
        r.data.transform(Matrix.Rotation(math.pi / 2, 4, "Z"))
        r.data.transform(Matrix.Translation((0, 0, 3.0)))
    # 两端山尖：木板三角（截面挤出，沿 x），镜像
    gt = PX("gt", [(-1.45, 0), (1.45, 0), (0, 1.25)], 0.1, "door", 0.0, "x")
    gt.data.transform(Matrix.Translation((1.3, 0, 3.0)))
    mirror(gt, 0, (0, 0, 0))
    roof.append(gt)
    axle = screw("axle", [(0.0, -1.0), (0.09, -1.0), (0.09, 1.0), (0.0, 1.0)], "timber", 8)
    axle.rotation_euler = (0, math.pi / 2, 0); axle.location = (0, 0, 2.2)
    kit.apply_scale(axle)
    rope = curve_bevel("rope", [(0.0, 0.0, 2.1), (0.0, 0.0, 1.5)], 0.015, "cream")
    bucket = screw("bucket", [(0.0, 0.0), (0.17, 0.0), (0.2, 0.28), (0.0, 0.28)], "door", 10)
    bucket.location = (0, 0, 1.2)
    handle = curve_bevel("hdl", [(-0.2, 0, 1.5), (0, 0, 1.58), (0.2, 0, 1.5)], 0.012, "iron")
    return join([seg, seg2, cap, water, post, crossb, axle, rope, bucket, handle] + roof, "well")


# ================================================================ T11 摊位（条纹篷）
def p_stall():
    post = B("post", 0.16, 0.16, 3.2, 1.7, -0.1, 0, "timber")
    post2 = B("post2", 0.16, 0.16, 2.55, 1.7, -2.3, 0, "timber")
    mirror(post, 0, (0, 0, 0)); mirror(post2, 0, (0, 0, 0))
    post = join([post, post2], "posts")
    counter = B("counter", 3.4, 0.9, 0.12, 0, -0.45, 1.0, "timber")
    plank = B("pf", 3.3, 0.04, 0.2, 0, -0.9, 0.08, "door")
    array(plank, 5, (0, 0, 0.2))
    side = B("side", 0.12, 0.9, 1.0, 1.65, -0.45, 0, "door")
    mirror(side, 0, (0, 0, 0))
    # 条纹篷：一条斜帆布条（挤出）阵列，红 / 米白交替；前沿垂边阵列
    sw = 0.4
    n = 9
    prof = [(0.0, 3.2), (-2.4, 2.5), (-2.4, 2.46), (0.0, 3.16)]
    a = PX("sa", [(p[0], p[1]) for p in prof], sw - 0.01, "red", -n * sw / 2, "x")
    a.rotation_euler = (0, 0, 0)
    array(a, (n + 1) // 2, (2 * sw, 0, 0))
    b = PX("sb", [(p[0], p[1]) for p in prof], sw - 0.01, "cream", -n * sw / 2 + sw, "x")
    array(b, n // 2, (2 * sw, 0, 0))
    val = B("val", sw - 0.01, 0.03, 0.32, -n * sw / 2 + sw / 2, -2.4, 2.18, "red")
    array(val, n, (sw, 0, 0))
    ridge = B("rb", n * sw + 0.2, 0.12, 0.14, 0, 0.0, 3.2, "timber")
    # 货物全部左右对称：一半建好，镜像到另一半
    crate = B("crate", 0.7, 0.55, 0.5, 1.1, -0.4, 1.12, "timber")
    goods = [B("g%d" % i, 0.3, 0.3, 0.3, x, -0.4, 1.12, c) for i, (x, c) in enumerate(((0.2, "red"), (0.55, "flower"), (0.2, "plant")))]
    goods[2].location.z += 0.3; goods[2].scale = (0.8, 0.8, 0.8)       # 叠在第一格上
    sack = screw("sack", [(0.0, 0), (0.28, 0), (0.3, 0.3), (0.15, 0.55), (0.0, 0.55)], "cream", 10)
    sack.location = (1.25, -1.3, 0.0)
    for o in [crate, sack] + goods:
        mirror(o, 0, (0, 0, 0))
    return join([post, counter, plank, side, a, b, val, ridge, crate, sack] + goods, "stall")


# ================================================================ T12 窗户单元（石窗框 + 窗板 + 花箱）
def p_window(w=1.6, h=2.2, shutters=True, flowers=True, surround="trim", wall=True):
    """窗户单元：石 / 木窗套（左半条阵列石块镜像）+ 过梁 + 拱心 + kit.window（窗格 / 窗扇）+ 对称花箱。
    wall=True 时带一块开洞墙板（展示用，窗台高 0.8）；wall=False 时原点在窗台高度的窗洞底边中点（给房屋用）。"""
    z0 = 0.8 if wall else 0.0
    objs = []
    if wall:
        W, H = 4.0, 3.6
        wl = wall_hole("ww", W, H, "plaster", ("rect", W / 2, z0, w, h))
        wl.data.transform(Matrix.Translation((-W / 2, 0, 0)))
        objs.append(wl)
    win = kit.window("rect", w, h, shutters, False)
    win.location = (0, 0, z0)
    objs.append(win)
    # 木纹方框：窗格本身已经有一圈细木线，这里再做一圈连续、贴墙的外框，
    # 让远景能读成“木窗套”，而不是石块阵列。四条边统一截面，转角严丝合缝，
    # 不再添加会漂在墙面上的分段石块和拱心石。
    fy = -T / 2 - 0.07
    fw = 0.16
    fd = 0.14
    side_x = w / 2 + fw / 2 + 0.035
    objs += [
        B("frame_l", fw, fd, h + 0.22, -side_x, fy, z0 - 0.11, "timber"),
        B("frame_r", fw, fd, h + 0.22, side_x, fy, z0 - 0.11, "timber"),
        B("frame_b", w + fw * 2 + 0.07, fd, fw, 0, fy, z0 - 0.11, "timber"),
        B("frame_t", w + fw * 2 + 0.07, fd, fw, 0, fy, z0 + h + 0.05, "timber"),
    ]
    if flowers:
        # 自己的对称花箱：木箱 + 一半的土丘 / 花丛（旋绕穹顶阵列）镜像
        # 花箱紧贴墙面、顶面压在窗台下沿，由两根铁托（从墙里伸出、托在箱底）撑着，不再悬空
        yb = -T / 2 - 0.15
        objs.append(B("fbox", w + 0.1, 0.3, 0.26, 0, yb, z0 - 0.31, "timber"))
        objs.append(B("fsoil", w, 0.24, 0.06, 0, yb, z0 - 0.07, "soil"))
        bk = B("fbk", 0.05, 0.36, 0.05, w / 2 - 0.12, -T / 2 - 0.13, z0 - 0.36, "iron")
        mirror(bk, 0, (0, 0, 0))
        objs.append(bk)
        nm = max(2, round(w / 2 / 0.3))
        step = (w / 2 - 0.1) / max(1, nm - 0.5) if nm > 1 else 0.3
        step = min(0.3, step)
        for i, (mk, r, z) in enumerate((("plant", 0.17, 0.0), ("flower", 0.09, 0.2))):
            d = screw("mound%d" % i, [(0.0, 0.0), (r, 0.0), (r * 1.1, r * 0.7), (r * 0.6, r * 1.3), (0.0, r * 1.45)], mk, 8)
            d.location = (step / 2, yb, z0 - 0.07 + z)
            array(d, nm, (step, 0, 0))
            mirror(d, 0, (0, 0, 0))
            objs.append(d)
    return join(objs, "window_unit")


# ================================================================ T13 店招挂牌
def p_sign(emblem="shield", board_mk="door"):
    arm = B("arm", 0.16, 0.16, 0.16, 0, 0, 0, "iron")
    arm.data.transform(Matrix.Translation((0, 0, 0)))
    bar = B("bar", 0.1, 1.9, 0.1, 0, -0.95, 2.6, "iron")
    wall = B("wallplate", 0.1, 0.5, 0.5, 0, 0.0, 2.35, "iron")
    # 涡卷撑杆：螺旋曲线倒角（一侧），再斜拉杆
    scroll = curve_bevel("scroll", [(0, -0.2 - 0.34 * math.cos(a) * (1 - a / 8), 2.55 - 0.34 * math.sin(a) * (1 - a / 8)) for a in [i * 0.4 for i in range(20)]], 0.03, "iron")
    brace = beam("brace", (0, -0.05, 2.2), (0, -1.35, 2.62), 0.07, 0.07, "iron")
    # 牌：木板 + 边框（阵列四条）+ 半盾徽镜像
    board = B("board", 0.12, 1.3, 0.95, 0, -1.1, 1.35, board_mk)
    frame = B("fr", 0.16, 1.38, 0.07, 0, -1.1, 1.31, "timber")
    array(frame, 2, (0, 0, 0.95))
    fr2 = B("fr2", 0.16, 0.07, 1.0, 0, -0.44, 1.31, "timber")
    array(fr2, 2, (0, -1.32, 0))
    chain = B("ch", 0.03, 0.03, 0.5, 0.0, -0.55, 2.3, "iron")
    array(chain, 2, (0, -1.1, 0))
    # 徽记贴在牌面（x=±0.06）外侧：先建正面一份，再沿 x 镜像到背面
    if emblem == "hammers":
        def rot(pts, ang):
            c, s = math.cos(ang), math.sin(ang)
            return [(-1.1 + (u * c - v * s), 1.82 + (u * s + v * c)) for u, v in pts]
        em = []
        for k, ang in enumerate((math.radians(38), math.radians(-38))):
            hd = PX("hm_h%d" % k, rot([(-0.04, -0.42), (0.04, -0.42), (0.04, 0.34), (-0.04, 0.34)], ang), 0.05, "log", 0.0, "x")
            hh = PX("hm_t%d" % k, rot([(-0.19, 0.22), (0.19, 0.22), (0.19, 0.42), (-0.19, 0.42)], ang), 0.07, "steel", 0.0, "x")
            hd.location.x = 0.06
            hh.location.x = 0.06
            em += [hd, hh]
        em = join(em, "emblem")
        mirror(em, 0, (0, 0, 0))
        return join([bar, wall, scroll, brace, board, frame, fr2, chain, em], "sign")
    half = PX("shield", [(0.0, -0.3), (0.26, -0.1), (0.28, 0.18), (0.16, 0.28), (0.0, 0.31)], 0.07, "gold", 0.0, "x")     # 半盾轮廓 (u=y, v=z)，沿 x 挤出
    half.data.transform(Matrix.Translation((0.06, -1.1, 1.82)))
    mirror(half, 1, (0, -1.1, 0))
    inner = PX("shield_in", [(0.0, -0.22), (0.19, -0.07), (0.2, 0.15), (0.11, 0.22), (0.0, 0.24)], 0.04, "red", 0.0, "x")
    inner.data.transform(Matrix.Translation((0.12, -1.1, 1.82)))
    mirror(inner, 1, (0, -1.1, 0))
    em = join([half, inner], "emblem")
    mirror(em, 0, (0, 0, 0))
    return join([bar, wall, scroll, brace, board, frame, fr2, chain, em], "sign")

PARTS = [
    ("T01_dormer", p_dormer, "老虎窗"), ("T02_chimney", p_chimney, "石烟囱"), ("T03_door", p_door, "拱门单元"), ("T04_porch", p_porch, "门廊"),
    ("T05_bay", p_bay, "凸窗"), ("T06_barn_door", p_barn_door, "双开谷仓门"), ("T07_tower_roof", p_tower_roof, "塔楼锥顶"),
    ("T08a_ivy", p_ivy, "常春藤"), ("T08b_bush", p_bush, "灌木"), ("T08c_flowerbed", p_flowerbed, "花坛"), ("T08d_grass", p_grass, "草丛"),
    ("T09_fence", p_fence, "栅栏+小门"), ("T10_well", p_well, "石井"), ("T11_stall", p_stall, "摊位"), ("T12_window", p_window, "窗户单元"), ("T13_sign", p_sign, "店招"),
]
