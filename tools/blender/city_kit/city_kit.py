# 晴岚港城市建筑构件库（city_kit v1）
# 依据：两段参考视频（E:\DOWNLOADS\41418490820-1-192.mp4 / 41403485769-1-192.mp4，抽帧见 docs/city_ref/sheet_*.jpg）
#      + 2026-10-09 用户给的 5 张参考图（车站港区、千泉城商业街青铜屋顶、黄昏圆形广场、第二帝国式市政厅、夜景宫殿园林）。
# 拆分方式沿用 modkit（SUNTAIL 栅格 + 十手法），模数放大到 MMO 尺度：
#   开间 BAY = 4.4m，底层 GF = 5.6m，标准层 FH = 4.4m，墙厚 T = 0.3m（与 kit.T 一致，kit.window / kit.door 直接复用）。
# 坐标约定（Blender）：+Z 向上；立面构件沿 +X 展开 0..BAY，外立面朝 -Y，墙体中心线 y=0；原点在左下角墙中心线上。
#   导出 glTF（Y 向上）后：沿 +X 展开、外立面朝 +Z。
# 十手法登记在对象自定义属性 methods（mirror / array / profile_extrude / solidify / curve_bevel / screw /
#   curve_deform / bridge / simple_deform / vertex）。
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "modkit"))
import kit
from kit import T, box, profile_extrude, panel, array, mirror, curve_bevel, screw, simple_bend, curve_deform, jitter, join, apply_mods, bm_obj, new_obj, simple_taper

BAY = 4.4
GF = 5.6
FH = 4.4
Y0 = -T / 2          # 外墙面

# 材质：K|mtype|RRGGBB|细节贴图|每张米数（游戏端 U.kit_mat → building.gdshader）
M = {
    "rustic": "K|2|d6ccb8|st_masonry|3.0",     # 底层横缝石（米黄石灰岩）
    "ashlar": "K|2|e6dfcf|st_masonry|4.0",     # 标准层方石
    "brick": "K|1|b25a40|brick|2.6",           # 红砖（视频里主力墙面）
    "stucco": "K|0|efe5cf|st_plaster|3.0",     # 灰泥
    "trim": "K|9|efe7d6||0",                   # 线脚 / 窗套 / 檐口（光面石）
    "trim_d": "K|9|cfc5b2||0",
    "slate": "K|3|48566e|st_roof_scale|2.4",   # 石板瓦（芒萨尔屋顶）
    "zinc": "K|9|7f8b97||0",                   # 锌皮屋脊 / 天沟
    "copper": "K|5|5f9f8f||0",                 # 铜绿屋顶（千泉城青铜屋顶）
    "gold": "K|5|d6a64a||0",
    "iron": "K|7|23272e||0",
    "glass": "K|glass|9fc0d4||0",
    "glow": "K|glow|ffd9a0||0",                # 店内暖光（夜景）
    "door": "K|6|5b3a26|st_boards|1.6",
    "wood": "K|6|6e4a30|st_wood|2.0",
    "sign": "K|6|2f3b34||0",                   # 店招底板（墨绿漆）
    "awn_a": "K|0|b33a2f||0",                  # 雨篷条纹（红）
    "awn_b": "K|0|f2e9d6||0",                  # 雨篷条纹（米白）
    "clock": "K|9|f7f1e2||0",
    "plant": "K|8|4f8a3c||0",
    "flower": "K|8|d86a8e||0",
}

def tag(ob, *methods):
    s = set(x for x in ob.get("methods", "").split(",") if x) | set(methods)
    ob["methods"] = ",".join(sorted(s))
    return ob

def spin(name, prof, mkey, angle=2 * math.pi, steps=16, center=(0.0, 0.0), dup=False):
    """旋绕（screw）：XZ 截面 (r,z) 绕 (center) 的竖轴转 angle。"""
    bm = bmesh.new()
    vs = [bm.verts.new((center[0] + r, center[1], z)) for r, z in prof]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(len(vs) - 1)]
    bmesh.ops.spin(bm, geom=vs + es, cent=(center[0], center[1], 0), axis=(0, 0, 1), angle=angle, steps=steps, use_duplicate=dup)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm_obj(name, bm, M.get(mkey, mkey), ("screw",))

def radial(ob, n, center=(0.0, 0.0)):
    """环形阵列（array）：把对象网格绕竖轴复制 n 份。"""
    bm = bmesh.new(); bm.from_mesh(ob.data)
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.spin(bm, geom=geom, cent=(center[0], center[1], 0), axis=(0, 0, 1), angle=2 * math.pi * (n - 1) / n, steps=n - 1, use_duplicate=True)
    bm.to_mesh(ob.data); bm.free()
    return tag(ob, "array")

def B(name, sx, sy, sz, loc, mkey):
    return box(name, sx, sy, sz, loc, M.get(mkey, mkey))

def PX(name, prof, length, mkey, x0=0.0, axis="x"):
    ob = profile_extrude(name, prof, length, M.get(mkey, mkey), axis)
    ob.location.x += x0
    return ob

def wall_panel(name, w, h, mkey, hole=None):
    return panel(name, w, h, M.get(mkey, mkey), hole)

def strips(x0, x1, z0, z1, pitch, depth=0.05, gap=0.06, mkey="rustic"):
    """横缝石（rustication）：一条凸出的石带按层距阵列。"""
    n = max(1, int((z1 - z0) / pitch))
    s = B("rust", x1 - x0, depth, pitch - gap, ((x0 + x1) / 2, Y0 - depth / 2, z0), mkey)
    return array(s, n, (0, 0, pitch))

def arch_trim(cx, z_spring, r, mkey="trim", width=0.28):
    """拱券线脚（curve_bevel）+ 拱心石（profile_extrude）。"""
    pts = [(cx + (r + width / 2) * math.cos(a), Y0 - 0.06, z_spring + (r + width / 2) * math.sin(a)) for a in (math.pi * i / 18 for i in range(19))]
    hood = curve_bevel("archv", pts, width / 2, M[mkey], square=True)
    key = PX("key", [(Y0 - 0.16, 0), (Y0 + 0.02, 0), (Y0 + 0.02, 0.62), (Y0 - 0.16, 0.62)], 0.42, mkey, cx - 0.21)
    key.location.z = z_spring + r - 0.08
    return [hood, key]

# ================================================================== 底层（GF = 5.6m）
def gf_arch(kind="window", wall="rustic"):
    """底层拱券开间：横缝石墙 + 拱洞（window 拱窗 / door 拱门 / open 过街拱）。"""
    w = 2.8
    z0 = 0.9 if kind == "window" else 0.0
    h = 4.0 if kind == "window" else 4.5
    parts = [wall_panel("gf_wall", BAY, GF, wall, ("arch", BAY / 2, z0, w, h))]
    spring = z0 + h - w / 2
    # 横缝石只铺在拱洞两侧与拱顶以上
    parts += [strips(0, BAY / 2 - w / 2 - 0.3, 0.45, GF - 0.6, 0.55), strips(BAY / 2 + w / 2 + 0.3, BAY, 0.45, GF - 0.6, 0.55)]
    parts += arch_trim(BAY / 2, spring, w / 2)
    parts.append(PX("plinth", [(Y0 - 0.14, 0), (Y0 + 0.02, 0), (Y0 + 0.02, 0.45), (Y0 - 0.08, 0.45), (Y0 - 0.14, 0.38)], BAY, "trim_d"))
    if kind == "window":
        win = kit.window("arch", w - 0.2, h - 0.1, shutters=False, box_flowers=False)
        win.location = (BAY / 2, 0, z0)
        parts.append(win)
    elif kind == "door":
        leaf, fr = kit.door("arch", w - 0.2, h - 0.1)
        for o in (leaf, fr):
            o.location = (BAY / 2, 0, 0)
        parts += [leaf, fr]
        fan = curve_bevel("fanlight", [((BAY / 2) + (w / 2 - 0.3) * math.cos(a), Y0 + 0.05, spring + (w / 2 - 0.3) * math.sin(a)) for a in (math.pi * i / 12 for i in range(13))], 0.04, M["iron"], square=True)
        parts.append(fan)
    return join(parts, "ck_gf_arch_" + kind)

def gf_shop(awning=True, wall="rustic"):
    """底层商铺开间：方洞 + 墙裙 + 大玻璃（竖棂阵列）+ 墨绿店招 + 条纹雨篷 + 两侧壁柱。"""
    ow, oh, oz = 3.4, 3.7, 0.0
    parts = [wall_panel("shop_wall", BAY, GF, wall, ("rect", BAY / 2, oz, ow, oh))]
    x0 = BAY / 2 - ow / 2
    parts.append(B("riser", ow, 0.12, 0.6, (BAY / 2, Y0 + 0.1, 0), "sign"))
    g = B("shop_glass", ow - 0.1, 0.03, oh - 0.75, (BAY / 2, Y0 + 0.14, 0.62), "glass")
    parts.append(g)
    mul = B("shop_mullion", 0.08, 0.1, oh - 0.75, (x0 + 0.04, Y0 + 0.1, 0.62), "sign")
    parts.append(array(mul, 4, ((ow - 0.08) / 3, 0, 0)))
    parts.append(B("transom", ow, 0.1, 0.08, (BAY / 2, Y0 + 0.1, oh - 0.9), "sign"))
    parts.append(B("shop_glow", ow - 0.3, 0.02, oh - 1.4, (BAY / 2, Y0 + 0.5, 0.7), "glow"))       # 店内暖光板（夜景）
    sign = PX("fascia", [(Y0 - 0.22, 0), (Y0 + 0.02, 0), (Y0 + 0.02, 0.95), (Y0 - 0.3, 0.95), (Y0 - 0.3, 0.85), (Y0 - 0.22, 0.8)], BAY - 0.6, "sign", 0.3)
    sign.location.z = oh + 0.05
    parts.append(sign)
    for x in (0.3, BAY - 0.3):        # 壁柱：柱身 + 柱础 / 柱头（分层挤出）
        parts.append(B("pil", 0.46, 0.22, GF - 0.3, (x, Y0 - 0.1, 0), "trim"))
        parts.append(B("pil_cap", 0.62, 0.32, 0.22, (x, Y0 - 0.14, GF - 0.52), "trim"))
    if awning:
        parts.append(awning_piece(BAY - 0.7, 1.6, oh + 0.02, BAY / 2))
    return join(parts, "ck_gf_shop")

def awning_piece(w, depth, z, cx):
    """条纹雨篷：斜帆布条（挤出 + 阵列，两色交错）+ 前沿垂边（阵列）+ 铁拉杆（曲线倒角 + 镜像）。"""
    sw = 0.45
    n = int(w / sw)
    sw = w / n
    drop = 0.9
    prof = [(Y0 - 0.02, 0), (Y0 - depth, -drop), (Y0 - depth, -drop - 0.04), (Y0 - 0.02, -0.04)]
    a = PX("awn_a", prof, sw, "awn_a", cx - w / 2); a.location.z = z
    array(a, (n + 1) // 2, (2 * sw, 0, 0))
    b = PX("awn_b", prof, sw, "awn_b", cx - w / 2 + sw); b.location.z = z
    array(b, n // 2, (2 * sw, 0, 0))
    val = B("valance", sw, 0.03, 0.32, (cx - w / 2 + sw / 2, Y0 - depth - 0.01, z - drop - 0.32), "awn_a")
    array(val, n, (sw, 0, 0))
    rod = curve_bevel("awn_rod", [(cx - w / 2 + 0.1, Y0 - 0.02, z + 0.7), (cx - w / 2 + 0.1, Y0 - depth + 0.05, z - drop + 0.02)], 0.025, M["iron"])
    mirror(rod, 0, (cx, 0, 0))
    return join([a, b, val, rod], "awning")

def gf_solid(wall="rustic"):
    parts = [wall_panel("gf_wall", BAY, GF, wall), strips(0, BAY, 0.45, GF - 0.6, 0.55)]
    parts.append(PX("plinth", [(Y0 - 0.14, 0), (Y0 + 0.02, 0), (Y0 + 0.02, 0.45), (Y0 - 0.08, 0.45), (Y0 - 0.14, 0.38)], BAY, "trim_d"))
    return join(parts, "ck_gf_solid")

# ================================================================== 标准层（FH = 4.4m）
def surround(cx, z0, w, h, mkey="trim"):
    """窗套（curve_bevel 沿洞口三边）+ 耳角（mirror）。"""
    pts = [(cx - w / 2 - 0.12, Y0 - 0.05, z0), (cx - w / 2 - 0.12, Y0 - 0.05, z0 + h + 0.12), (cx + w / 2 + 0.12, Y0 - 0.05, z0 + h + 0.12), (cx + w / 2 + 0.12, Y0 - 0.05, z0)]
    fr = curve_bevel("surround", pts, 0.12, M[mkey], square=True)
    ear = B("ear", 0.22, 0.14, 0.22, (cx - w / 2 - 0.18, Y0 - 0.08, z0 + h - 0.05), mkey)
    mirror(ear, 0, (cx, 0, 0))
    return [fr, ear]

def pediment_tri(cx, z, w, rise, mkey="trim", depth=0.34):
    """三角山花：半个三角截面挤出后镜像（mirror）。"""
    half = PX("pedi", [(Y0 - depth, 0), (Y0 + 0.02, 0), (Y0 + 0.02, 0.16), (Y0 - depth, 0.16)], w / 2 / math.cos(math.atan2(rise, w / 2)), mkey)
    half.matrix_world = Matrix.Translation((cx - w / 2, 0, z)) @ Matrix.Rotation(math.atan2(rise, w / 2), 4, "Y").inverted()
    bpy.context.view_layer.update()
    mirror(half, 0, (cx, 0, 0))
    base = B("pedi_base", w, depth + 0.02, 0.14, (cx, Y0 - depth / 2 + 0.01, z - 0.14), mkey)
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((cx - w / 2 + 0.25, Y0 - 0.02, z), (cx + w / 2 - 0.25, Y0 - 0.02, z), (cx, Y0 - 0.02, z + rise - 0.2))]
    bm.faces.new(vs)
    tym = bm_obj("tympanum", bm, M["trim_d"], ("solidify",))
    m = tym.modifiers.new("s", "SOLIDIFY"); m.thickness = 0.06; apply_mods(tym)
    return [half, base, tym]

def pediment_seg(cx, z, w, mkey="trim"):
    """弧形山花：弧线檐板（曲线倒角，方截面）+ 拱心石（挤出）+ 下方平檐（挤出）。"""
    sag = 0.42
    R = (w * w / 4 + sag * sag) / (2 * sag)
    a0 = math.asin(w / 2 / R)
    pts = [(cx + R * math.sin(a), Y0 - 0.17, z + 0.12 + sag - R * (1 - math.cos(a))) for a in (-a0 + 2 * a0 * i / 12 for i in range(13))]
    hood = curve_bevel("seghood", pts, 0.13, M[mkey], square=True)
    flat = PX("seg_flat", [(Y0 + 0.02, 0), (Y0 - 0.26, 0), (Y0 - 0.3, 0.12), (Y0 + 0.02, 0.14)], w - 0.2, mkey, cx - (w - 0.2) / 2)
    flat.location.z = z - 0.1
    key = PX("seg_key", [(Y0 - 0.3, 0), (Y0 + 0.02, 0), (Y0 + 0.02, 0.5), (Y0 - 0.3, 0.5)], 0.34, mkey, cx - 0.17)
    key.location.z = z - 0.05
    return [hood, flat, key]

def bow(ob, length, bulge):
    """弓形阳台（curve_deform）：把沿 +X、从原点起长 length 的直件沿一条外凸 bulge 的弧线曲线变形。"""
    bpy.context.view_layer.update()
    ob.data.transform(ob.matrix_basis); ob.matrix_basis = Matrix.Identity(4)
    pts = [(length * i / 12, -bulge * math.sin(math.pi * i / 12), 0) for i in range(13)]
    return curve_deform(ob, pts, "POS_X")

def uf_window(style="plain", wall="brick"):
    """标准层开间：墙板 + 高窗（kit.window）+ 窗套 + 窗楣变体（plain 檐板 / pedi 三角山花 / seg 弧形山花）
    或 balc：落地法式窗 + 铁艺阳台（挑台挤出 + 栏杆阵列 + 扶手曲线倒角）。"""
    if style == "balc":
        ww, wh, wz = 1.7, 3.3, 0.05
    else:
        ww, wh, wz = 1.6, 2.7, 0.8
    parts = [wall_panel("uf_wall", BAY, FH, wall, ("rect", BAY / 2, wz, ww, wh))]
    win = kit.window("rect", ww, wh, shutters=False, box_flowers=(style == "plain"))
    win.location = (BAY / 2, 0, wz)
    parts.append(win)
    parts += surround(BAY / 2, wz, ww, wh)
    top = wz + wh + 0.25
    if style == "pedi":
        parts += pediment_tri(BAY / 2, top, ww + 0.9, 0.62)
    elif style == "seg":
        parts += pediment_seg(BAY / 2, top, ww + 0.8)
    elif style == "balc":
        slab = PX("balc_slab", [(0.17, 0), (-0.7, 0), (-0.7, 0.16), (-0.6, 0.24), (0.17, 0.24)], ww + 1.2, "trim")
        bow(slab, ww + 1.2, 0.22)                     # 挑台与栏杆同一条弓形线
        slab.location = (BAY / 2 - (ww + 1.2) / 2, Y0 - 0.15, -0.2)
        con = PX("console", [(Y0, 0), (Y0 - 0.6, 0), (Y0 - 0.6, 0.12), (Y0 - 0.1, -0.5), (Y0, -0.5)], 0.22, "trim", BAY / 2 - ww / 2 - 0.4)
        con.location.z = -0.2
        mirror(con, 0, (BAY / 2, 0, 0))
        L = ww + 1.1
        bal = B("rail_bar", 0.035, 0.035, 1.0, (0.05, 0, 0.04), "iron")
        array(bal, int(L / 0.14) + 1, (0.14, 0, 0))
        hand = B("handrail", L, 0.07, 0.07, (L / 2, 0, 1.03), "iron")
        for o in (bal, hand):            # 弓形外凸 0.22m 的铁栏杆（curve_deform）
            bow(o, L, 0.22)
            o.location = (BAY / 2 - L / 2, Y0 - 0.74, 0)
        swirl = curve_bevel("swirl", [(BAY / 2 - 0.5 + 0.5 * math.cos(a) * (1 - a / 12), Y0 - 0.8, 0.5 + 0.3 * math.sin(a) * (1 - a / 12)) for a in (i * 0.5 for i in range(24))], 0.02, M["iron"])
        mirror(swirl, 0, (BAY / 2, 0, 0))
        parts += [slab, con, bal, hand, swirl]
        parts.append(PX("cornice_head", [(Y0 + 0.02, 0), (Y0 - 0.24, 0), (Y0 - 0.3, 0.14), (Y0 + 0.02, 0.2)], ww + 0.7, "trim", BAY / 2 - (ww + 0.7) / 2))
        parts[-1].location.z = top - 0.05
    return join(parts, "ck_uf_" + style + "_" + wall)

def uf_solid(wall="brick"):
    return join([wall_panel("uf_wall", BAY, FH, wall)], "ck_uf_solid_" + wall)

# ================================================================== 线脚 / 转角 / 女儿墙
def band(length=BAY, mkey="trim"):
    """层间腰线：线脚截面挤出。"""
    return tag(PX("ck_band", [(Y0 + 0.02, 0), (Y0 - 0.16, 0), (Y0 - 0.22, 0.08), (Y0 - 0.22, 0.2), (Y0 - 0.12, 0.3), (Y0 + 0.02, 0.32)], length, mkey))

def cornice(length=BAY, mkey="trim"):
    """主檐口：多层线脚截面挤出 + 牛腿托（挤出 + 阵列）+ 齿饰（阵列）。"""
    prof = [(Y0 + 0.02, 0), (Y0 - 0.12, 0), (Y0 - 0.12, 0.16), (Y0 - 0.3, 0.24), (Y0 - 0.3, 0.42), (Y0 - 0.78, 0.5), (Y0 - 0.86, 0.62),
            (Y0 - 0.86, 0.78), (Y0 - 0.7, 0.86), (Y0 + 0.02, 0.86)]
    c = PX("cornice", prof, length, mkey)
    mod = PX("modillion", [(Y0 - 0.3, 0.42), (Y0 - 0.76, 0.48), (Y0 - 0.76, 0.42), (Y0 - 0.5, 0.3), (Y0 - 0.3, 0.26)], 0.18, mkey, 0.21)
    array(mod, max(1, int(length / 0.55)), (0.55, 0, 0))
    den = B("dentil", 0.1, 0.1, 0.12, (0.1, Y0 - 0.17, 0.02), mkey)
    array(den, max(1, int(length / 0.2)), (0.2, 0, 0))
    return join([c, mod, den], "ck_cornice")

def balustrade(length=BAY, mkey="trim"):
    """女儿墙栏杆：底座 / 扶手挤出 + 车削瓶形栏杆（旋绕）阵列 + 两端墩柱。"""
    base = B("bal_base", length, 0.5, 0.22, (length / 2, Y0 + 0.1, 0), mkey)
    rail = B("bal_rail", length, 0.56, 0.18, (length / 2, Y0 + 0.1, 0.95), mkey)
    prof = [(0.09, 0), (0.12, 0.05), (0.07, 0.14), (0.13, 0.36), (0.1, 0.52), (0.06, 0.6), (0.09, 0.66), (0.09, 0.73), (0.0, 0.73)]
    b = spin("baluster", prof, "trim", steps=8)
    b.location = (0.45, Y0 + 0.1, 0.22)
    n = max(1, int((length - 0.7) / 0.3))
    array(b, n, ((length - 0.9) / max(1, n - 1), 0, 0))
    ped = B("ped", 0.5, 0.6, 1.2, (0.25, Y0 + 0.1, 0), mkey)
    mirror(ped, 0, (length / 2, 0, 0))
    return join([base, rail, b, ped], "ck_balustrade")

def quoins(h=FH, mkey="ashlar"):
    """转角隅石：长短交替块石阵列 + 轻微错位（vertex）。"""
    a = B("q1", 0.7, 0.7, 0.5, (0, 0, 0), mkey)
    b = B("q2", 0.5, 0.5, 0.5, (0, 0, 0.5), mkey)
    q = join([a, b], "ck_quoins")
    n = max(1, int(h / 1.0))
    array(q, n, (0, 0, h / n))
    return jitter(q, 0.01, 3)

def pilaster(h=FH, mkey="trim"):
    """壁柱：柱身 + 凹槽（阵列）+ 柱础 / 柱头分层挤出。"""
    shaft = B("pil_shaft", 0.6, 0.24, h - 0.6, (0, Y0 - 0.1, 0.3), mkey)
    fl = B("flute", 0.06, 0.03, h - 1.0, (-0.18, Y0 - 0.23, 0.5), "trim_d")
    array(fl, 4, (0.12, 0, 0))
    bse = B("pil_base", 0.8, 0.36, 0.3, (0, Y0 - 0.14, 0), mkey)
    cap = PX("pil_cap", [(Y0 + 0.02, 0), (Y0 - 0.24, 0), (Y0 - 0.34, 0.12), (Y0 - 0.34, 0.3), (Y0 + 0.02, 0.3)], 0.8, mkey, -0.4)
    cap.location.z = h - 0.3
    return join([shaft, fl, bse, cap], "ck_pilaster")

def oriel(mkey="stucco"):
    """凸窗（一层高）：三面玻璃凸窗：平面截面沿 Z 挤出 + 托架（旋绕）+ 铜皮小屋顶（旋绕 4 段）。"""
    d, w0, w1 = 1.1, 3.0, 2.2
    plan = [(-w0 / 2, Y0), (w0 / 2, Y0), (w1 / 2, Y0 - d), (-w1 / 2, Y0 - d)]
    sill = profile_extrude("oriel_sill", plan, 0.9, M[mkey], "z"); sill.location = (BAY / 2, 0, 0.3)
    glass = profile_extrude("oriel_glass", [(x * 0.97, (y - Y0) * 0.97 + Y0) for x, y in plan], 2.6, M["glass"], "z"); glass.location = (BAY / 2, 0, 1.2)
    head = profile_extrude("oriel_head", [(x * 1.06, (y - Y0) * 1.1 + Y0) for x, y in plan], 0.35, M["trim"], "z"); head.location = (BAY / 2, 0, 3.8)
    posts = []
    for (x, y) in plan[1:3]:
        p = B("opost", 0.14, 0.14, 2.6, (BAY / 2 + x * 0.97, y * 0.97 + Y0 * 0.03, 1.2), "trim")
        posts.append(p)
    mirror(posts[0], 0, (BAY / 2, 0, 0)); mirror(posts[1], 0, (BAY / 2, 0, 0))
    corb = spin("corbel", [(0.0, -1.2), (0.25, -1.1), (0.55, -0.6), (0.9, 0.0), (0.0, 0.0)], "trim", steps=10)
    corb.scale = (1.6, 1.0, 1.0); corb.location = (BAY / 2, Y0 - 0.5, 0.3)
    roof = PX("oriel_roof", [(Y0 + 0.05, 0), (Y0 - d - 0.25, 0), (Y0 + 0.05, 0.75)], w0 + 0.3, "copper", BAY / 2 - (w0 + 0.3) / 2)
    roof.location.z = 4.15
    return join([sill, glass, head] + posts + [corb, roof], "ck_oriel")

# ================================================================== 屋顶
MANS_H, MANS_IN = 4.4, 1.6
def mans_off(t):
    """芒萨尔外坡在高度比例 t 处离墙中心线向外的距离（底部 0.5m，顶部收进 1.1m，中段外凸 0.2m）。"""
    return 0.35 + T / 2 - MANS_IN * t + 0.2 * math.sin(math.pi * t)

def mansard(length=BAY, dormer=None, mkey="slate"):
    """芒萨尔屋顶段：陡坡瓦面（截面挤出，顶点做微弧）+ 檐口卷边 / 顶部锌皮压顶（曲线倒角）+ 平顶段；
    dormer=None / "pedi"（三角山花老虎窗）/ "oculus"（圆窗老虎窗）。底边贴在墙顶，外坡从 y=-T/2-0.35 升到 y=+1.25（高 4.4m）。"""
    h, inset = MANS_H, MANS_IN
    outer = [(-mans_off(i / 8), h * i / 8) for i in range(9)]           # 外坡：微外凸的弧线（与转角件同一曲线）
    prof = outer + [(-mans_off(1.0) + 0.35, h), (Y0 + 0.1, 0)]
    slope = PX("mansard", prof, length, mkey)
    top = B("roof_flat", length, 3.0, 0.12, (length / 2, Y0 + inset + 1.3, h - 0.02), "zinc")
    roll = curve_bevel("eave_roll", [(0, Y0 - 0.4, 0.05), (length, Y0 - 0.4, 0.05)], 0.12, M["zinc"])
    crest_line = curve_bevel("curb_roll", [(0, Y0 - 0.32 + inset, h + 0.05), (length, Y0 - 0.32 + inset, h + 0.05)], 0.09, M["zinc"])
    parts = [slope, top, roll, crest_line]
    if dormer:
        parts += dormer_piece(length / 2, dormer, inset, h)
    return join(parts, "ck_mansard" + ("_" + dormer if dormer else ""))

def dormer_piece(cx, kind, inset, h):
    """老虎窗：窗墙板（桥接洞口 + 实体化）+ 玻璃 + 两侧颊板（挤出 + 镜像）+ 窗顶（三角山花 / 圆窗旋绕环）。"""
    dw, dz, dy = 1.5, 0.6, Y0 - 0.25 + inset * 0.15
    fr_w, fr_h = 2.1, 2.6
    if kind == "oculus":
        wallp = panel("dormer_wall", fr_w, fr_h, M["trim"], ("arch", fr_w / 2, 0.7, 1.2, 1.6))
    else:
        wallp = panel("dormer_wall", fr_w, fr_h, M["trim"], ("rect", fr_w / 2, 0.55, 1.1, 1.5))
    wallp.location = (cx - fr_w / 2, dy, dz)
    gl = B("dormer_glass", 1.2, 0.03, 1.6, (cx, dy + 0.05, dz + 0.6), "glass")
    cheek = PX("cheek", [(dy, 0), (dy + 1.6, 0), (dy, fr_h)], 0.12, "zinc", cx - fr_w / 2 - 0.12)
    cheek.location.z = dz
    mirror(cheek, 0, (cx, 0, 0))
    parts = [wallp, gl, cheek]
    if kind == "pedi":
        tri = pediment_tri(cx, dz + fr_h, fr_w + 0.4, 0.8)
        for o in tri:
            o.location.y += dy - Y0
        parts += tri
        rf = PX("dormer_roof", [(dy - 0.2, 0), (dy + 1.8, 0), (dy + 1.8, 0.1), (dy - 0.2, 0.1)], fr_w + 0.4, "slate", cx - (fr_w + 0.4) / 2)
        rf.location.z = dz + fr_h
        parts.append(rf)
    else:
        ring = spin("oculus_ring", [(0.72, -0.1), (0.9, -0.1), (0.9, 0.1), (0.72, 0.1)], "trim", steps=20)
        ring.rotation_euler = (math.pi / 2, 0, 0); ring.location = (cx, dy - 0.05, dz + fr_h + 0.3)
        cap = spin("dormer_cap", [(1.25, 0), (0.9, 0.5), (0.0, 0.75)], "zinc", angle=math.pi, steps=8)
        cap.rotation_euler = (math.pi / 2, 0, -math.pi / 2); cap.location = (cx, dy + 0.2, dz + fr_h)
        parts += [ring, cap]
    return parts

def mansard_corner(mkey="slate"):
    """芒萨尔外转角：同一截面绕转角竖轴旋绕 90°（screw），与两侧 mansard 段无缝衔接。原点在建筑外角（墙中心线）。"""
    h, c = MANS_H, MANS_IN - (0.35 + T / 2)        # 旋绕轴：坡顶收进后的内角 (c, c)
    bm = bmesh.new()
    vs = [bm.verts.new((c - (c + mans_off(i / 8)), c, h * i / 8)) for i in range(9)]
    es = [bm.edges.new((vs[i], vs[i + 1])) for i in range(8)]
    bmesh.ops.spin(bm, geom=vs + es, cent=(c, c, 0), axis=(0, 0, 1), angle=math.pi / 2, steps=8)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    slope = bm_obj("mcorner", bm, M[mkey], ("screw",))
    roll = curve_bevel("corner_roll", [(c - (c + 0.55) * math.cos(a), c - (c + 0.55) * math.sin(a), 0.05) for a in (math.pi / 2 * i / 8 for i in range(9))], 0.12, M["zinc"])
    return join([slope, roll], "ck_mansard_corner")

def pavilion_roof(size=8.8, h=7.0, mkey="slate"):
    """帝国式亭顶（钟形四坡）：钟形截面旋绕 4 段（screw）再转 45°，顶部铁艺花冠（阵列）+ 尖顶（旋绕）。原点在亭底中心。"""
    s = size / 2 * math.sqrt(2)
    prof = [(s + 0.3, 0), (s, 0.4), (s * 0.92, h * 0.35), (s * 0.7, h * 0.75), (s * 0.35, h * 0.95), (s * 0.3, h)]
    r = kit.screw("pavilion", prof, M[mkey], steps=4)
    r.rotation_euler.z = math.pi / 4
    top = B("pav_top", size * 0.42, size * 0.42, 0.25, (0, 0, h), "zinc")
    crest = B("crest", 0.06, 0.06, 0.8, (-size * 0.2, -size * 0.21, h + 0.25), "iron")
    array(crest, 10, (size * 0.4 / 9, 0, 0))
    mirror(crest, 1, (0, 0, 0))
    fin = spin("finial", [(0.18, 0), (0.25, 0.3), (0.08, 0.6), (0.14, 0.9), (0.02, 2.2), (0, 2.3)], "iron", steps=8)
    fin.location.z = h + 0.25
    return join([r, top, crest, fin], "ck_pavilion_roof")

def dome(r=4.4, mkey="copper"):
    """穹顶 + 采光亭：鼓座（旋绕）+ 半球（旋绕）+ 肋（曲线倒角 + 环形阵列）+ 小亭柱（环形阵列）+ 亭帽 / 尖顶（旋绕）。原点在鼓座底中心。"""
    drum = spin("drum", [(r + 0.3, 0), (r + 0.3, 1.6), (r + 0.5, 1.8), (r + 0.5, 2.1), (r, 2.1)], "trim", steps=24)
    prof = [(r, 2.1)] + [(r * math.cos(a), 2.1 + r * 0.95 * math.sin(a)) for a in (math.pi / 2 * i / 10 for i in range(1, 10))] + [(1.0, 2.1 + r * 0.95)]
    d = spin("dome", prof, mkey, steps=24)
    rib = curve_bevel("rib", [(r * math.cos(a) + 0.02, 0, 2.1 + r * 0.95 * math.sin(a)) for a in (math.pi / 2 * i / 10 for i in range(11)) if r * math.cos(a) > 1.0], 0.09, M["gold"])
    radial(rib, 12)
    zt = 2.1 + r * 0.95
    col = spin("lcol", [(0.12, 0), (0.12, 1.8), (0, 1.8)], "trim", steps=6)
    col.location = (0.85, 0, zt)
    bpy.context.view_layer.update(); col.data.transform(col.matrix_basis); col.matrix_basis = Matrix.Identity(4)
    radial(col, 8)
    lcap = spin("lcap", [(1.2, zt + 1.8), (1.1, zt + 2.1), (0.5, zt + 2.8), (0.12, zt + 3.4), (0.04, zt + 4.6), (0, zt + 4.7)], "copper", steps=12)
    return join([drum, d, rib, col, lcap], "ck_dome")

def turret_body(r=2.6, h=FH, mkey="stucco"):
    """角楼塔身（一层）：圆柱墙（旋绕）+ 层间线脚环（旋绕）+ 三扇窗（窗框板做 BEND 简单形变贴合弧面）。原点在圆心。"""
    wall = spin("tbody", [(r, 0), (r, h)], mkey, steps=20)
    ring = spin("tring", [(r - 0.02, h - 0.3), (r + 0.18, h - 0.25), (r + 0.18, h), (r - 0.02, h)], "trim", steps=20)
    parts = [wall, ring]
    span = 1.1 / r                                    # 窗宽 1.1m 对应的圆心角
    for ang in (-math.pi / 2 - 0.75, -math.pi / 2, -math.pi / 2 + 0.75):
        # 弧面窗：玻璃 / 窗楣 / 窗台都用同一圆心旋绕出弧形片，再转到窗位
        g = spin("twin", [(r + 0.03, 0.9), (r + 0.03, 3.1)], "glass", angle=span, steps=4)
        hd = spin("twin_hd", [(r - 0.02, 3.1), (r + 0.16, 3.15), (r + 0.16, 3.35), (r - 0.02, 3.35)], "trim", angle=span + 0.12, steps=5)
        sl = spin("twin_sl", [(r - 0.02, 0.78), (r + 0.14, 0.78), (r + 0.14, 0.9), (r - 0.02, 0.9)], "trim", angle=span + 0.08, steps=5)
        for o, a0 in ((g, span / 2), (hd, (span + 0.12) / 2), (sl, (span + 0.08) / 2)):
            o.rotation_euler.z = ang - a0
        parts += [g, hd, sl]
    return join(parts, "ck_turret_body")

def turret_cone(r=2.6, h=7.5, mkey="slate"):
    """角楼尖顶：圆锥截面旋绕（带檐口外撇）+ 檐口环 + 铁艺尖顶（旋绕）。原点在圆心、塔身顶。"""
    cone = spin("tcone", [(r + 0.45, 0.0), (r + 0.2, 0.35), (r * 0.6, h * 0.45), (0.15, h), (0, h)], mkey, steps=20)
    eave = spin("teave", [(r - 0.05, -0.2), (r + 0.5, -0.05), (r + 0.5, 0.05), (r - 0.05, 0.05)], "zinc", steps=20)
    fin = spin("tfin", [(0.14, h - 0.1), (0.22, h + 0.3), (0.06, h + 0.8), (0.12, h + 1.1), (0.02, h + 2.6), (0, h + 2.7)], "iron", steps=8)
    return join([cone, eave, fin], "ck_turret_cone")

def clock_stage(size=6.0, h=6.0, mkey="ashlar"):
    """钟楼钟层：方体（挤出）+ 四角壁柱（镜像 X/Y）+ 四面钟盘（旋绕盘 + 指针，镜像）+ 顶檐。原点在底中心。"""
    body = B("cstage", size, size, h, (0, 0, 0), mkey)
    body.location.y = 0
    pil = B("cpil", 0.7, 0.7, h, (size / 2 - 0.2, -size / 2 + 0.2, 0), "trim")
    mirror(pil, 0, (0, 0, 0)); mirror(pil, 1, (0, 0, 0))
    face = spin("cface", [(0.0, 0.0), (1.7, 0.0), (1.7, 0.12), (1.9, 0.12), (1.9, -0.05)], "clock", steps=24)
    face.rotation_euler = (math.pi / 2, 0, 0); face.location = (0, -size / 2 - 0.02, h * 0.55)
    hand = B("hand", 0.12, 0.05, 1.3, (0, -size / 2 - 0.16, h * 0.55), "iron")
    hand2 = B("hand2", 0.9, 0.05, 0.12, (0.4, -size / 2 - 0.16, h * 0.55), "iron")
    bpy.context.view_layer.update()
    clk = join([face, hand, hand2], "clock")
    radial(clk, 4)                                   # 四面钟（环形阵列）
    cr = cornice(size + 0.8, "trim"); cr.location = (-(size + 0.8) / 2, -size / 2 + T / 2, h)
    bpy.context.view_layer.update(); cr.data.transform(cr.matrix_basis); cr.matrix_basis = Matrix.Identity(4)
    radial(cr, 4)
    return join([body, pil, clk, cr], "ck_clock_stage")

def cresting(length=BAY):
    """铁艺屋脊花饰：卷草纹（曲线倒角）沿长度阵列。"""
    pts = [(0.15 * math.cos(a) + 0.2, 0, 0.25 + 0.15 * math.sin(a)) for a in (i * 0.6 for i in range(12))] + [(0.2, 0, 0.6)]
    s = curve_bevel("cresting", pts, 0.02, M["iron"])
    bar = curve_bevel("crest_bar", [(0, 0, 0.05), (length, 0, 0.05)], 0.025, M["iron"])
    array(s, max(1, int(length / 0.4)), (0.4, 0, 0))
    return join([s, bar], "ck_cresting")

def chimney_stack(mkey="brick"):
    """烟囱：砖块阵列 + 收分 + 压顶 + 陶土烟囱管（旋绕，阵列 3 根）。"""
    blk = B("cblk", 1.6, 0.8, 0.3, (0, 0, 0), mkey)
    array(blk, 8, (0, 0, 0.3))
    jitter(blk, 0.01, 5, (1, 1, 0.1))
    simple_taper(blk, -0.04, (0, 0, 0))
    cap = PX("ccap", [(-0.5, 0), (0.5, 0), (0.5, 0.15), (0.42, 0.25), (-0.42, 0.25), (-0.5, 0.15)], 1.8, "trim", -0.9)
    cap.location.z = 2.4
    pot = spin("pot", [(0.14, 0), (0.17, 0.2), (0.13, 0.55), (0.16, 0.6), (0.0, 0.6)], "awn_a", steps=8)
    pot.location = (-0.5, 0, 2.65)
    array(pot, 3, (0.5, 0, 0))
    return join([blk, cap, pot], "ck_chimney")

# ================================================================== 门廊 / 山花 / 拱门 / 街具
def column(h, r=0.42, mkey="trim"):
    """柱：带收分（entasis）的车削柱身（旋绕 + 简单形变 TAPER）+ 柱础 / 柱头（旋绕）。原点在柱底中心。"""
    shaft = spin("shaft", [(r, 0.5), (r * 1.02, h * 0.3), (r * 0.88, h - 0.7)], mkey, steps=16)
    base = spin("cbase", [(r + 0.25, 0), (r + 0.25, 0.25), (r + 0.1, 0.35), (r + 0.12, 0.45), (r, 0.5)], mkey, steps=16)
    cap = spin("ccap", [(r * 0.88, h - 0.7), (r * 1.05, h - 0.5), (r * 1.4, h - 0.25), (r * 1.4, h)], mkey, steps=16)
    abacus = B("abacus", r * 3.0, r * 3.0, 0.18, (0, 0, h - 0.18), mkey)
    return join([shaft, base, cap, abacus], "column")

def portico(span=BAY, h=GF + FH, mkey="trim"):
    """门廊开间：两根柱（column，镜像）+ 额枋 / 檐部（分层挤出）。原点左下墙中心线，柱立在墙外 1.6m。"""
    c = column(h - 1.1)
    c.location = (0.5, Y0 - 1.6, 0)
    mirror(c, 0, (span / 2, 0, 0))
    ent = PX("entablature", [(Y0 + 0.02, 0), (Y0 - 2.3, 0), (Y0 - 2.3, 0.6), (Y0 - 2.5, 0.75), (Y0 - 2.5, 1.1), (Y0 + 0.02, 1.1)], span, mkey)
    ent.location.z = h - 1.1
    stl = B("stylobate", span, 2.4, 0.3, (span / 2, Y0 - 1.15, -0.3), "trim_d")
    return tag(join([c, ent, stl], "ck_portico"), "mirror")

def temple_pediment(w=3 * BAY, rise=3.2, mkey="trim"):
    """大山花：三角山花（mirror）+ 山花中央圆窗（旋绕）。原点左下，挂在门廊檐部之上。"""
    parts = pediment_tri(w / 2, 0.0, w, rise, mkey, depth=2.5)
    for o in parts:
        o.location.y -= 0.0
    ring = spin("tp_ring", [(0.9, -0.1), (1.15, -0.1), (1.15, 0.1), (0.9, 0.1)], "trim", steps=20)
    ring.rotation_euler = (math.pi / 2, 0, 0); ring.location = (w / 2, Y0 - 0.1, rise * 0.42)
    disc = spin("tp_glass", [(0, 0), (0.9, 0)], "glass", steps=20)
    disc.rotation_euler = (math.pi / 2, 0, 0); disc.location = (w / 2, Y0 - 0.05, rise * 0.42)
    return join(parts + [ring, disc], "ck_temple_pediment")

def arch_gate(w=8.8, h=11.0, mkey="rustic"):
    """凯旋式拱门段：横缝石墙板挖大拱（桥接 + 实体化）+ 拱券线脚 / 拱心石 + 两侧壁柱（镜像）+ 顶部女儿墙栏杆。"""
    aw, ah = 4.6, 7.4
    parts = [wall_panel("gate", w, h, mkey, ("arch", w / 2, 0, aw, ah))]
    parts += [strips(0, w / 2 - aw / 2 - 0.4, 0.5, ah - 0.4, 0.6), strips(w / 2 + aw / 2 + 0.4, w, 0.5, ah - 0.4, 0.6)]
    parts += arch_trim(w / 2, ah - aw / 2, aw / 2, width=0.4)
    p = pilaster(h - 2.2); p.location = (0.8, 0, 0)
    mirror(p, 0, (w / 2, 0, 0))
    cr = cornice(w); cr.location.z = h - 2.2
    bl = balustrade(w); bl.location.z = h - 1.3
    # 墙板厚度加厚：门洞进深 1.2m（双层墙板）
    back = wall_panel("gate_back", w, h - 2.2, mkey, ("arch", w / 2, 0, aw, ah)); back.location.y = 0.9
    soffit = spin("soffit", [(aw / 2, -0.15), (aw / 2, 1.05)], "trim_d", angle=math.pi, steps=16)
    soffit.rotation_euler = (math.pi / 2, 0, 0); soffit.location = (w / 2, 0, ah - aw / 2)
    return join(parts + [p, cr, bl, back, soffit], "ck_arch_gate")

def wall_lamp():
    """壁灯：铁艺卷草支架（曲线倒角）+ 灯笼（旋绕）+ 发光玻璃。原点贴墙面，安装高 0（外部决定）。"""
    arm = curve_bevel("larm", [(0, Y0, 0), (0, Y0 - 0.4, 0.15), (0, Y0 - 0.7, 0.1), (0, Y0 - 0.75, -0.1)], 0.03, M["iron"])
    lan = spin("lantern", [(0.0, -0.75), (0.12, -0.72), (0.2, -0.4), (0.16, -0.15), (0.24, -0.1), (0.05, 0.05), (0.0, 0.08)], "iron", steps=6)
    lan.location = (0, Y0 - 0.75, 0)
    gl = spin("lglow", [(0.0, -0.68), (0.15, -0.62), (0.15, -0.2), (0.0, -0.18)], "glow", steps=6)
    gl.location = (0, Y0 - 0.75, 0)
    return join([arm, lan, gl], "ck_wall_lamp")

def flower_box(length=1.8):
    """窗前花箱：木箱（挤出）+ 草团 / 花朵（旋绕 + 阵列 + 顶点错位）。"""
    fb = B("fbox", length, 0.32, 0.3, (length / 2, Y0 - 0.2, 0), "wood")
    bl = spin("bloom", [(0, 0), (0.1, 0.06), (0.11, 0.14), (0.04, 0.2), (0, 0.21)], "plant", steps=6)
    bl.location = (0.12, Y0 - 0.2, 0.28); array(bl, int(length / 0.2), (0.2, 0, 0)); jitter(bl, 0.03, 7)
    fl = spin("blossom", [(0, 0), (0.06, 0.02), (0.06, 0.06), (0, 0.08)], "flower", steps=5)
    fl.location = (0.18, Y0 - 0.28, 0.42); array(fl, int(length / 0.28), (0.28, 0, 0)); jitter(fl, 0.03, 9)
    return join([fb, bl, fl], "ck_flower_box")

# ================================================================== 目录：id → (构造, 类别, 模数尺寸说明)
def catalog():
    C = {}
    def add(cid, fn, cat, note):
        C[cid] = (fn, cat, note)
    add("ck_gf_arch_window", lambda: gf_arch("window"), "底层立面", "开间 4.4 × 高 5.6；横缝石 + 拱窗")
    add("ck_gf_arch_door", lambda: gf_arch("door"), "底层立面", "开间 4.4 × 高 5.6；拱门（门扇 + 铁艺扇形窗）")
    add("ck_gf_arch_open", lambda: gf_arch("open"), "底层立面", "开间 4.4 × 高 5.6；过街拱 / 拱廊")
    add("ck_gf_shop", lambda: gf_shop(True), "底层立面", "开间 4.4 × 高 5.6；商铺橱窗 + 店招 + 条纹雨篷")
    add("ck_gf_shop_plain", lambda: gf_shop(False), "底层立面", "开间 4.4 × 高 5.6；商铺（无雨篷）")
    add("ck_gf_solid", lambda: gf_solid(), "底层立面", "开间 4.4 × 高 5.6；实墙横缝石")
    for wall in ("brick", "stucco", "ashlar"):
        for st in ("plain", "pedi", "seg", "balc"):
            add("ck_uf_%s_%s" % (st, wall), (lambda st=st, wall=wall: uf_window(st, wall)), "标准层立面", "开间 4.4 × 层高 4.4；%s 墙 · %s" % (wall, {"plain": "檐板窗 + 花箱", "pedi": "三角山花窗", "seg": "弧形山花窗", "balc": "法式落地窗 + 铁艺阳台"}[st]))
        add("ck_uf_solid_" + wall, (lambda wall=wall: uf_solid(wall)), "标准层立面", "开间 4.4 × 层高 4.4；%s 实墙" % wall)
    add("ck_oriel", lambda: oriel(), "标准层立面", "开间 4.4 × 层高 4.4；三面凸窗（贴在实墙段外）")
    add("ck_band", lambda: band(), "线脚与转角", "长 4.4；层间腰线（放在每层楼板线）")
    add("ck_cornice", lambda: cornice(), "线脚与转角", "长 4.4；主檐口（牛腿 + 齿饰），放在墙顶")
    add("ck_balustrade", lambda: balustrade(), "线脚与转角", "长 4.4；女儿墙 / 平台栏杆")
    add("ck_quoins", lambda: quoins(), "线脚与转角", "高 4.4；转角隅石（放在外角）")
    add("ck_pilaster", lambda: pilaster(), "线脚与转角", "高 4.4；壁柱（放在开间分界）")
    add("ck_mansard", lambda: mansard(), "屋顶", "长 4.4 × 高 4.4；芒萨尔陡坡 + 平顶段")
    add("ck_mansard_pedi", lambda: mansard(dormer="pedi"), "屋顶", "长 4.4；芒萨尔 + 三角山花老虎窗")
    add("ck_mansard_oculus", lambda: mansard(dormer="oculus"), "屋顶", "长 4.4；芒萨尔 + 圆窗老虎窗")
    add("ck_mansard_copper", lambda: mansard(dormer="oculus", mkey="copper"), "屋顶", "长 4.4；青铜屋面芒萨尔（千泉城风格）")
    add("ck_mansard_corner", lambda: mansard_corner(), "屋顶", "外转角（旋绕 90°），接两侧芒萨尔段")
    add("ck_pavilion_roof", lambda: pavilion_roof(), "屋顶", "8.8 × 8.8 底；帝国式钟形亭顶 + 铁艺花冠")
    add("ck_pavilion_roof_copper", lambda: pavilion_roof(mkey="copper"), "屋顶", "8.8 × 8.8 底；青铜亭顶")
    add("ck_dome", lambda: dome(), "屋顶", "直径 9.4；鼓座 + 穹顶 + 金肋 + 采光亭")
    add("ck_cresting", lambda: cresting(), "屋顶", "长 4.4；铁艺屋脊花饰")
    add("ck_chimney", lambda: chimney_stack(), "屋顶", "1.6 × 0.8；砖烟囱 + 陶土烟囱管")
    add("ck_turret_body", lambda: turret_body(), "塔楼与地标", "直径 5.2 × 层高 4.4；圆角楼塔身（可叠层）")
    add("ck_turret_cone", lambda: turret_cone(), "塔楼与地标", "直径 5.2；角楼尖顶")
    add("ck_clock_stage", lambda: clock_stage(), "塔楼与地标", "6 × 6 × 6；钟楼钟层（四面钟）")
    add("ck_portico", lambda: portico(), "塔楼与地标", "开间 4.4 × 高 10；双柱门廊段（可横向拼接）")
    add("ck_temple_pediment", lambda: temple_pediment(), "塔楼与地标", "宽 13.2；门廊大山花 + 圆窗")
    add("ck_arch_gate", lambda: arch_gate(), "塔楼与地标", "宽 8.8 × 高 11；凯旋式拱门段")
    add("ck_wall_lamp", lambda: wall_lamp(), "街具", "壁灯（离地 3.2 安装）")
    add("ck_flower_box", lambda: flower_box(), "街具", "长 1.8；窗前花箱")
    return C
