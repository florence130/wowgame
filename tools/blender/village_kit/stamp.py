# 构件库 → 房屋：把 parts.py 手建的构件（镜像 / 阵列 / 截面挤出 / 实体化 / 曲线倒角 / 旋绕 / 桥接 / 顶点…）烘成「顶点 + 三角 + 材质」缓存，
# 再按每栋房子的风格换材质（灰泥 / 木筋 / 石 / 屋面），用变换矩阵盖章进 Geo 累加器。软材质（玻璃 / 叶 / 花 / 土）进无碰撞组 N。
# 构件按真实米制（MMO 尺度）建，房屋生成器在「放大前」的坐标系里工作，所以盖章时统一乘 1/SC。
import bpy, os, sys, re
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, "..", "modkit"))
import kit, vmat, parts, smith_parts as sp

SC = 1.0          # 构件源头使用真实米制；最终世界比例由 build.py 的 3.0/2.3 统一导出
PANE = "N|4d6a8a"
_cache = {}
_BUILD = dict(
    window=parts.p_window, door=parts.door_set, porch=parts.p_porch, dormer=parts.p_dormer, chimney=parts.p_chimney, tower=parts.p_tower_roof,
    finial=parts.p_finial, ivy=parts.p_ivy, bush=parts.p_bush, flowerbed=parts.p_flowerbed, grass=parts.p_grass, fence=parts.p_fence, sign=parts.p_sign,
    barn=parts.p_barn_door, bay=parts.p_bay, well=parts.p_well, stall=parts.p_stall,
    hearth=sp.p_hearth, forge_chimney=sp.p_forge_chimney, forge_shed=sp.p_forge_shed, plaque=sp.p_plaque, armor_plate=sp.p_armor_plate, armor_mail=sp.p_armor_mail,
    armor_leather=sp.p_armor_leather, weapon_wall=sp.p_weapon_wall, counter=sp.p_counter, tool_rack=sp.p_tool_rack, grindstone=sp.p_grindstone, anvil=sp.p_anvil,
)


def _extract(ob):
    me = ob.data
    me.calc_loop_triangles()
    M = ob.matrix_basis
    verts = [tuple(M @ v.co) for v in me.vertices]
    groups = {}
    for lt in me.loop_triangles:
        mi = me.polygons[lt.polygon_index].material_index
        mat = me.materials[mi] if mi < len(me.materials) else None
        groups.setdefault(mat.name if mat else "?", []).append(tuple(lt.vertices))
    return dict(verts=verts, groups=groups)


def get(kind, t=None, **kw):
    """建（或取缓存的）构件。返回 {子件名: 数据}；builder 返回单个对象时子件名为 ''。t = 墙厚覆盖（米，放大后）。"""
    ck = (kind, t, tuple(sorted(kw.items())))
    if ck in _cache:
        return _cache[ck]
    old = parts.T
    if t is not None:
        parts.set_wall(t)
    kit.COL = None
    kit.mat = lambda key: vmat.get(kit.PAL.get(key, key))
    try:
        res = _BUILD[kind](**kw)
    finally:
        parts.set_wall(old)
    objs = res if isinstance(res, dict) else {"": res}
    out = {}
    for name, ob in objs.items():
        out[name] = _extract(ob)
        me = ob.data
        bpy.data.objects.remove(ob)
        if me.users == 0:
            bpy.data.meshes.remove(me)
    _cache[ck] = out
    return out


def soft_names():
    return {kit.PAL[k] for k in ("glass", "plant", "plant2", "plant3", "flower", "flower2", "flower3", "berry", "soil", "ember", "water")}


def remap_for(st):
    """构件调色板 → 这栋房子的风格材质。"""
    P = kit.PAL
    return {P["plaster"]: st["PLASTER"], P["timber"]: st["TIMBER"], P["ashlar"]: st["STONE"], P["terracotta"]: st["ROOF"], P["slate"]: st["ROOF"],
            P["glass"]: PANE, P["shutter"]: st["SHUT"]}


def put(G, data, M, remap=None, force=None):
    """把一份构件数据盖章进 Geo：M = 世界（放大前坐标）变换；force = 'S' / 'N' 强制分组，否则软材质 → N，其余 → S。"""
    soft = soft_names()
    remap = remap or {}
    for name, tris in data["groups"].items():
        used = sorted({i for t in tris for i in t})
        idx = {v: i for i, v in enumerate(used)}
        verts = [data["verts"][v] for v in used]
        faces = [tuple(idx[i] for i in t) for t in tris]
        g = force or ("N" if name in soft else "S")
        G.raw(g, remap.get(name, name), verts, faces, M)


def place(G, st, kind, M, t=None, force=None, sub=None, keep=(), **kw):
    """一步到位：取构件 → 换材质 → 盖章。sub = 只盖某个子件（door 的 frame / leaf）；keep = 不随风格换色的调色板键（如烟囱陶罐）。"""
    d = get(kind, t, **kw)
    rm = remap_for(st) if st else {}
    for k in keep:
        rm.pop(kit.PAL[k], None)
    for name, data in d.items():
        if sub is not None and name != sub:
            continue
        put(G, data, M, rm, force)


# ---------------------------------------------------------------- 洛奇M 解包模型（直接取用，个人项目可做衍生）
MABI = r"E:\MabinogiMobile_TW_extract"
_obj_cache = {}


def recolor_atlas(tex, tag, hue=0.0, sat=1.0, val=1.0, flat=0.0):
    """洛奇M 图集 → 我们自己的衍生图集：色相旋转 / 饱和度 / 明度调整，flat > 0 时再向 3×3 局部均值压平（更接近我们的平涂风格）。
    写到 assets/textures/mabi/<tex>__<tag>.png，返回新贴图名。（Blender 自带 Python 没有 PIL，所以用 numpy + bpy.data.images）"""
    import numpy as np
    out = tex + "__" + tag
    dst = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "textures", "mabi", out + ".png"))
    if os.path.exists(dst):
        return out
    img = bpy.data.images.load(os.path.join(MABI, "Textures", tex + ".png"), check_existing=False)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    r, g, b, a = px[..., 0], px[..., 1], px[..., 2], px[..., 3]
    mx, mn = np.maximum(np.maximum(r, g), b), np.minimum(np.minimum(r, g), b)
    d = mx - mn
    hh = np.zeros_like(mx)
    m = d > 1e-6
    rc = np.where(m, (mx - r) / np.where(m, d, 1), 0); gc = np.where(m, (mx - g) / np.where(m, d, 1), 0); bc = np.where(m, (mx - b) / np.where(m, d, 1), 0)
    hh = np.where(mx == r, bc - gc, np.where(mx == g, 2.0 + rc - bc, 4.0 + gc - rc))
    hh = (hh / 6.0) % 1.0
    ss = np.where(mx > 1e-6, d / np.where(mx > 1e-6, mx, 1), 0)
    vv = mx
    hh = (hh + hue / 360.0) % 1.0
    ss = np.clip(ss * sat, 0, 1)
    vv = np.clip(vv * val, 0, 1)
    i = np.floor(hh * 6.0).astype(np.int32) % 6
    f = hh * 6.0 - np.floor(hh * 6.0)
    p, q, t = vv * (1 - ss), vv * (1 - f * ss), vv * (1 - (1 - f) * ss)
    R = np.choose(i, [vv, q, p, p, t, vv]); G = np.choose(i, [t, vv, vv, q, p, p]); B = np.choose(i, [p, p, t, vv, vv, q])
    res = np.stack([R, G, B], -1)
    if flat > 0:
        k = np.zeros_like(res)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                k += np.roll(np.roll(res, dy, axis=0), dx, axis=1)
        res = res * (1 - flat) + (k / 9.0) * flat
    outp = np.concatenate([res, a[..., None]], -1).astype(np.float32)
    ni = bpy.data.images.new(out, w, h, alpha=True)
    ni.pixels = outp.reshape(-1).tolist()
    ni.filepath_raw = dst
    ni.file_format = "PNG"
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    ni.save()
    bpy.data.images.remove(ni)
    bpy.data.images.remove(img)
    return out

def get_obj(objname, tex, scale=1.0, center=True, mod=None):
    """导入 E:\MabinogiMobile_TW_extract\Meshes\<objname>.obj 当作「底模」，再做我们自己的修改（衍生品，不直接沿用）：
    mod = dict(s=(sx, sy, sz) 非等比缩放, jitter=顶点抖动米数, bend=沿高度的扭转角（弧度）, taper=顶部收分比例,
               hue / sat / val / flat = 图集重新调色, tag = 衍生图集后缀, drop = 函数 (bbox 中心, 尺寸) → True 则丢弃该连通块)。
    逐三角拆成独立顶点并带 UV；返回 dict(verts, faces, uvs, mk)。"""
    mod = mod or {}
    ck = (objname, tex, scale, repr(sorted(mod.items(), key=lambda kv: kv[0])) if mod else "")
    if ck in _obj_cache:
        return _obj_cache[ck]
    import shutil, math
    dst = os.path.join(HERE, "..", "..", "..", "assets", "textures", "mabi")
    os.makedirs(dst, exist_ok=True)
    use_tex = tex
    if mod.get("mk"):
        pass                                              # 改用我们自己的 K| 材质（三向投影，不需要 UV / 图集）
    elif any(k in mod for k in ("hue", "sat", "val", "flat")):
        use_tex = recolor_atlas(tex, mod.get("tag", "mod"), mod.get("hue", 0.0), mod.get("sat", 1.0), mod.get("val", 1.0), mod.get("flat", 0.0))
    elif False:
        pass
    before = set(bpy.data.objects)
    bpy.ops.wm.obj_import(filepath=os.path.join(MABI, "Meshes", objname + ".obj"))
    new = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    sx, sy, sz = mod.get("s", (1.0, 1.0, 1.0))
    jit, bend, taper = mod.get("jitter", 0.0), mod.get("bend", 0.0), mod.get("taper", 0.0)
    drop = mod.get("drop")
    allp = []
    for o in new:
        for v in o.data.vertices:
            allp.append(o.matrix_world @ v.co)
    if allp:
        zmin = min(p.z for p in allp); zmax = max(p.z for p in allp)
    else:
        zmin, zmax = 0.0, 1.0
    verts, faces, uvs = [], [], []
    for o in new:
        me = o.data
        me.calc_loop_triangles()
        uvl = me.uv_layers.active
        for lt in me.loop_triangles:
            if drop is not None:
                ps = [o.matrix_world @ me.vertices[vi].co for vi in lt.vertices]
                c = (ps[0] + ps[1] + ps[2]) / 3.0
                if drop((c.x, c.y, c.z), (zmin, zmax)):
                    continue
            base = len(verts)
            for li, vi in zip(lt.loops, lt.vertices):
                p = o.matrix_world @ me.vertices[vi].co
                x, y, z = p.x * sx, p.y * sy, p.z * sz
                if jit > 0:                                    # 位置哈希抖动：同一位置的顶点位移相同，缝不会裂开
                    k = (round(x * 40), round(y * 40), round(z * 40))
                    hh = hash(k) & 0xFFFFFF
                    x += ((hh & 0xFF) / 255.0 - 0.5) * 2 * jit
                    y += (((hh >> 8) & 0xFF) / 255.0 - 0.5) * 2 * jit
                    z += (((hh >> 16) & 0xFF) / 255.0 - 0.5) * 2 * jit
                t = (p.z - zmin) / max(zmax - zmin, 1e-6)
                if bend:
                    a = bend * t
                    x, y = x * math.cos(a) - y * math.sin(a), x * math.sin(a) + y * math.cos(a)
                if taper:
                    k2 = 1.0 - taper * t
                    x, y = x * k2, y * k2
                verts.append((x * scale, y * scale, z * scale))
                uvs.append(tuple(uvl.data[li].uv) if uvl else (0.0, 0.0))
            faces.append((base, base + 1, base + 2))
    for o in new:
        me = o.data
        bpy.data.objects.remove(o)
        bpy.data.meshes.remove(me)
    if center and verts:                                   # 平面中心对齐、底面落到 z=0（家具 / 摆件用）
        xs = [v[0] for v in verts]; ys = [v[1] for v in verts]; zs = [v[2] for v in verts]
        cx, cy, cz = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)
        verts = [(v[0] - cx, v[1] - cy, v[2] - cz) for v in verts]
    if mod.get("mk"):
        out = dict(verts=verts, faces=faces, uvs=None, mk=mod["mk"])
    else:
        out = dict(verts=verts, faces=faces, uvs=uvs, mk="M|" + use_tex)
    _obj_cache[ck] = out
    return out

def put_obj(G, data, M, group="S"):
    G.raw(group, data["mk"], data["verts"], data["faces"], M, data.get("uvs"))

# ---------------------------------------------------------------- Tripo 衍生件（assets/models/tripo_town/*.glb，import_props.py 导出：几何来自 Tripo、材质是我们的 K| 手绘 PBR 材质）
_TP = {}
TP_DIR = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "assets", "models", "tripo_town"))


def tp_has(name):
    return os.path.exists(os.path.join(TP_DIR, name + ".glb"))


def _tp_load(name):
    """读 GLB → {材质名: (verts, faces)} + 包围盒（Blender 坐标：x 宽 / y 深 / z 高，原点在底面中心）。"""
    if name in _TP:
        return _TP[name]
    import bpy
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(TP_DIR, name + ".glb"))
    new = [o for o in bpy.data.objects if o not in before]
    out = {}
    mn = [1e9] * 3
    mx = [-1e9] * 3
    for o in new:
        if o.type != "MESH":
            continue
        me = o.data
        mw = o.matrix_world
        vs = [tuple(mw @ v.co) for v in me.vertices]
        for v in vs:
            for i in range(3):
                mn[i] = min(mn[i], v[i]); mx[i] = max(mx[i], v[i])
        for p in me.polygons:
            mk = me.materials[p.material_index].name if p.material_index < len(me.materials) and me.materials[p.material_index] else "K|6|8a5f3e|pt_wood|4.0"
            mk = re.sub(r"\.\d{3}$", "", mk)
            d = out.setdefault(mk, ({}, []))
            idx = []
            for vi in p.vertices:
                if vi not in d[0]:
                    d[0][vi] = len(d[0])
                idx.append(d[0][vi])
            d[1].append((idx, [vs[vi] for vi in p.vertices]))
    for o in new:
        me = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o)
        if me is not None and me.users == 0:
            bpy.data.meshes.remove(me)
    res = {}
    for mk, (vm, fl) in out.items():
        verts = [None] * len(vm)
        faces = []
        for idx, pts in fl:
            faces.append(idx)
            for i, k in enumerate(idx):
                verts[k] = pts[i]
        res[mk] = (verts, faces)
    _TP[name] = (res, tuple(mn), tuple(mx))
    return _TP[name]


def tp(G, name, M, w=None, d=None, h=None, group="S", yaw=0.0, flip=False, roofmk=None):
    """放一件 Tripo 衍生件。w / d / h：目标尺寸（基础米，缺省的轴按已给的轴等比）；原点 = 底面中心；模型正面默认朝 -Y（本地 +Y 是靠墙 / 背面）。
    返回 False 表示没有这件资产（调用方退回程序化版本）。"""
    if not tp_has(name):
        return False
    from mathutils import Matrix
    res, mn, mx = _tp_load(name)
    sx0, sy0, sz0 = mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]
    ks = [t / s if t else None for t, s in ((w, sx0), (d, sy0), (h, sz0))]
    given = [k for k in ks if k]
    base = given[0] if given else 1.0
    if sx0 > 0 and ks[0] is None and ks[2] is None and ks[1] is not None:
        base = ks[1]
    ks = [k if k else base for k in ks]
    cx, cy = (mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2
    R = Matrix.Rotation(yaw + (3.141592653589793 if flip else 0.0), 4, "Z")
    X = M @ R @ Matrix.Diagonal((ks[0], ks[1], ks[2], 1.0)) @ Matrix.Translation((-cx, -cy, -mn[2]))
    for mk, (verts, faces) in res.items():
        grp = group
        if roofmk and ("pt_roof_tile" in mk or "pt_roof_slate" in mk or "pt_shake" in mk):
            mk = roofmk
        if mk.startswith("K|glow") or mk.startswith("K|glass"):
            grp = "N"
        G.raw(grp, mk, verts, faces, X)
    return True



