# 晴岚港沿街楼构件库（street_kit v1）——洛奇M 重制版 / 荒野之息式手绘卡通的「木筋灰泥 + 砖石底层 + 陡坡瓦顶」。
# 拆分方式沿用 modkit（十手法）：镜像 / 阵列 / 截面挤出 / 实体化 / 曲线倒角 / 旋绕 / 桥接 / 顶点…
# 只做几何轮廓，质感由手绘贴图（assets/textures/building/pt_*.png，RGB 乘数）在着色器里出：所以每件都很省面（目标 ≤ 300 三角形）。
# 模数与旧 city_kit 一致：开间 BAY 4.4m（装配时按地块宽度 ±12% 缩放 X），底层 GF 5.6m，标准层 FH 4.4m，墙厚 T 0.3m。
# 坐标（Blender）：+Z 向上；立面构件沿 +X 展开 0..BAY，外立面朝 -Y，墙体中心线 y=0，原点在左下角墙中心线；
#   导出 glTF（Y 向上）后：沿 +X、外立面朝 +Z；进深方向是 glTF -Z（Blender +Y）。
# 材质名：
#   S|槽|类型|贴图|米   实例着色槽（0 墙 / 1 屋顶 / 2 石材线脚 / 3 点缀：窗板、门、雨篷）→ 每栋楼各自调色板色（CityKitLots）
#   K|类型|RRGGBB|贴图|米 固定颜色（木筋、铁艺、招牌…）→ U.kit_mat
#   N|RRGGBB            窗格：白天深蓝灰，夜间发暖光（CityKitLots 登记到 CityMat 夜间系统）
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "modkit"))
import kit
from kit import T, box, profile_extrude, panel, array, mirror, curve_bevel, join, apply_mods, bm_obj, new_obj, jitter

BAY, GF, FH = 4.4, 5.6, 4.4
Y0 = -T / 2
TEXDIR = os.path.normpath(os.path.join(HERE, "..", "..", "..", "assets", "textures", "building"))
PITCH = math.radians(38.0)
DN = 14.0                       # 山墙 / 双坡屋面构件的名义进深（装配时 Y、Z 同比缩放）
RN = DN / 2 * math.tan(PITCH)   # 名义屋脊高

# ------------------------------------------------------------------ 材质
PREV = {0: (0.94, 0.89, 0.8), 1: (0.62, 0.3, 0.22), 2: (0.84, 0.8, 0.72), 3: (0.5, 0.3, 0.2)}
WALL = "S|0|0|pt_plaster|4.0"
BRICK = "S|0|1|pt_brick|2.6"
ROOF = "S|1|4|pt_roof_tile|2.4"
ROOF_S = "S|1|3|pt_roof_slate|2.6"
STONE = "S|2|2|pt_ashlar|3.2"
TRIM = "S|2|9|pt_limestone|4.8"
ACC = "S|3|6|pt_wood|2.0"
AWN = "S|3|0|pt_awning|1.6"
TIMBER = "K|6|5a3d2b|pt_wood|2.0"
IRON = "K|7|2b2f36|pt_metal|2.0"
SIGN = "K|6|2f3b34|pt_wood|2.0"
GOLD = "K|7|c79a3c|pt_metal|2.0"
PANE = "N|45617d"
LEAD = "K|7|59616b|pt_metal|2.0"

def sk_mat(name):
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    m = bpy.data.materials.new(name)
    f = name.split("|")
    c = (0.7, 0.7, 0.7)
    tex, tm = "", 3.0
    if f[0] == "S":
        c = PREV[int(f[1])]; tex = f[3]; tm = float(f[4])
    elif f[0] == "K":
        c = tuple(int(f[2][i:i + 2], 16) / 255 for i in (0, 2, 4)); tex = f[3]; tm = float(f[4]) if len(f) > 4 and f[4] else 3.0
    elif f[0] == "N":
        c = tuple(int(f[1][i:i + 2], 16) / 255 for i in (0, 2, 4))
    m.diffuse_color = (*c, 1.0)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*[x ** 2.2 for x in c], 1)
    bsdf.inputs["Roughness"].default_value = 1.0
    path = os.path.join(TEXDIR, tex + ".png") if tex else ""
    if path and os.path.exists(path):   # 仅 Blender 预览：与游戏端相同的 RGB 乘数贴图 × 底色（盒状投影）
        tc = nt.nodes.new("ShaderNodeTexCoord"); mp = nt.nodes.new("ShaderNodeMapping")
        s = 1.0 / max(tm, 0.1); mp.inputs["Scale"].default_value = (s, s, s)
        im = nt.nodes.new("ShaderNodeTexImage"); im.image = bpy.data.images.load(path, check_existing=True)
        im.image.colorspace_settings.name = "sRGB"
        im.projection = "BOX"; im.projection_blend = 0.2
        mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = "RGBA"; mix.blend_type = "MULTIPLY"; mix.inputs["Factor"].default_value = 1.0
        mix.inputs[6].default_value = (*[x ** 2.2 * 2.0 for x in c], 1)
        nt.links.new(tc.outputs["Object"], mp.inputs["Vector"]); nt.links.new(mp.outputs["Vector"], im.inputs["Vector"])
        nt.links.new(im.outputs["Color"], mix.inputs[7]); nt.links.new(mix.outputs[2], bsdf.inputs["Base Color"])
    return m

kit.mat = sk_mat       # modkit 的 box / profile_extrude 等按名字取材质：换成本库的命名规则

# ------------------------------------------------------------------ 小工具
def B(name, sx, sy, sz, x, y, z, mk):
    """盒：x、y 为中心，z 为底。"""
    return box(name, sx, sy, sz, (x, y, z), mk)

def PX(name, prof, length, mk, x0=0.0):
    ob = profile_extrude(name, prof, length, mk, "x")
    ob.location.x += x0
    return ob

def quad(name, p0, p1, p2, p3, mk, double=False):
    """单个四边形（4 点按逆时针看向法线一侧）。"""
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in (p0, p1, p2, p3)]
    bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm_obj(name, bm, mk, ("vertex",))

def tilted(ob, origin, angle_y):
    """绕 Y 轴（Blender 的 XZ 面内）旋转一个沿 +X 的杆件：origin = 起点。"""
    ob.matrix_world = Matrix.Translation(origin) @ Matrix.Rotation(angle_y, 4, "Y")
    bpy.context.view_layer.update()
    return ob

def slant_box(name, x0, z0, x1, z1, thick, depth, y, mk):
    """XZ 面内从 (x0,z0) 到 (x1,z1) 的斜杆（斜撑 / 椽子）。"""
    d = math.hypot(x1 - x0, z1 - z0)
    ob = profile_extrude(name, [(y - depth / 2, -thick / 2), (y + depth / 2, -thick / 2), (y + depth / 2, thick / 2), (y - depth / 2, thick / 2)], d, mk, "x")
    ob.matrix_world = Matrix.Translation((x0, 0, z0)) @ Matrix.Rotation(-math.atan2(z1 - z0, x1 - x0), 4, "Y")
    bpy.context.view_layer.update()
    return ob

def window(cx, z0, w, h, shutters=True, arch=False, cross=True, awn_c=None):
    """窗：深色窗格（夜间发光）+ 高光斜条 + 四边窗框 + 十字窗棂 + 窗台 + 窗板（点缀槽）。返回零件列表。"""
    parts = []
    if arch:
        r = w / 2
        pts = [(cx - r, z0), (cx + r, z0), (cx + r, z0 + h - r)] + [(cx + r * math.cos(math.pi * i / 8), z0 + h - r + r * math.sin(math.pi * i / 8)) for i in range(1, 8)] + [(cx - r, z0 + h - r)]
        bm = bmesh.new()
        vs = [bm.verts.new((x, 0.02, z)) for x, z in pts]
        bm.faces.new(vs)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        for f in bm.faces:
            if f.normal.y > 0:
                f.normal_flip()
        parts.append(bm_obj("pane", bm, PANE, ("vertex",)))
        ring = curve_bevel("arch_ring", [(cx + (r + 0.07) * math.cos(math.pi * i / 10), Y0 - 0.05, z0 + h - r + (r + 0.07) * math.sin(math.pi * i / 10)) for i in range(11)], 0.07, TRIM, square=True)
        parts.append(ring)
    else:
        parts.append(quad("pane", (cx - w / 2, 0.02, z0), (cx + w / 2, 0.02, z0), (cx + w / 2, 0.02, z0 + h), (cx - w / 2, 0.02, z0 + h), PANE))
        # 高光斜条：把窗格画成「映着天空的玻璃」
        parts.append(quad("gleam", (cx - w * 0.38, 0.0, z0 + h * 0.52), (cx - w * 0.08, 0.0, z0 + h * 0.86), (cx + w * 0.06, 0.0, z0 + h * 0.86), (cx - w * 0.24, 0.0, z0 + h * 0.52), "K|0|a9c4d8||0"))
        parts[-1].location.y = Y0 + 0.2
    fw = 0.09
    if not arch:
        parts += [B("fr_t", w + 0.2, 0.14, fw, cx, Y0 + 0.02, z0 + h, TRIM), B("fr_l", fw, 0.14, h, cx - w / 2 - fw / 2, Y0 + 0.02, z0, TRIM), B("fr_r", fw, 0.14, h, cx + w / 2 + fw / 2, Y0 + 0.02, z0, TRIM)]
    if cross:
        parts += [B("mul_v", 0.05, 0.1, h, cx, Y0 + 0.09, z0, TIMBER), B("mul_h", w, 0.1, 0.05, cx, Y0 + 0.09, z0 + h * 0.58, TIMBER)]
    s = PX("sill", [(Y0 + 0.02, 0), (Y0 - 0.3, 0), (Y0 - 0.3, 0.07), (Y0 - 0.22, 0.14), (Y0 + 0.02, 0.14)], w + 0.34, TRIM, cx - (w + 0.34) / 2)
    s.location.z = z0 - 0.12
    parts.append(s)
    if shutters:
        sw = w * 0.5 - 0.02
        for sx in (-1, 1):
            parts.append(B("shutter", sw, 0.06, h, cx + sx * (w / 2 + sw / 2 + 0.1), Y0 - 0.04, z0, ACC))
    return parts

def panel_hole(name, w, h, mk, hole):
    return panel(name, w, h, mk, hole)

# ================================================================== 底层（GF = 5.6m）
def gf_shop():
    """商铺开间：石墙裙 + 大橱窗（木框）+ 招牌 + 条纹遮阳篷 + 两侧壁柱。"""
    ow, oh, oz = 3.5, 3.1, 0.7
    parts = [panel("gf_wall", BAY, GF, STONE, ("rect", BAY / 2, oz, ow, oh))]
    # 店内：暖色后墙（夜间发光）+ 两层搁板 + 彩色货品（固定色小盒）
    parts.append(quad("shop_back", (BAY / 2 - ow / 2, 0.55, oz), (BAY / 2 + ow / 2, 0.55, oz), (BAY / 2 + ow / 2, 0.55, oz + oh), (BAY / 2 - ow / 2, 0.55, oz + oh), "N|4a3526"))
    for sz_, cols in ((oz + 1.05, ("c0453a", "e0b04a", "4f8f7d", "5b73b0", "d97c9a")), (oz + 1.95, ("e0b04a", "7a5aa8", "c0453a", "4f8f7d", "e8dcc0"))):
        parts.append(B("shelf", ow - 0.1, 0.45, 0.07, BAY / 2, 0.32, sz_ - 0.07, "K|6|6b4a2e|pt_wood|2.0"))
        for k, cc in enumerate(cols):
            parts.append(B("goods", 0.3, 0.26, 0.34 + 0.08 * (k % 3), BAY / 2 - ow / 2 + 0.35 + k * (ow - 0.7) / 4, 0.3, sz_, "K|0|" + cc + "||0"))
    parts.append(quad("shop_gleam", (BAY / 2 - 1.4, 0.0, oz + 0.8), (BAY / 2 - 0.5, 0.0, oz + oh - 0.15), (BAY / 2 - 0.15, 0.0, oz + oh - 0.15), (BAY / 2 - 1.05, 0.0, oz + 0.8), "K|0|a9c4d8||0"))
    parts[-1].location.y = Y0 + 0.2
    # 木框：四边 + 竖棂阵列（array）+ 腰窗横梁
    parts += [B("fr_t", ow + 0.2, 0.16, 0.14, BAY / 2, Y0 + 0.02, oz + oh - 0.0, TIMBER), B("fr_b", ow + 0.2, 0.18, 0.5, BAY / 2, Y0 - 0.0, oz - 0.5, TIMBER),
              B("fr_l", 0.14, 0.16, oh, BAY / 2 - ow / 2 - 0.07, Y0 + 0.02, oz, TIMBER), B("fr_r", 0.14, 0.16, oh, BAY / 2 + ow / 2 + 0.07, Y0 + 0.02, oz, TIMBER),
              B("transom", ow, 0.12, 0.08, BAY / 2, Y0 + 0.05, oz + oh - 0.75, TIMBER)]
    mul = B("mul", 0.07, 0.12, oh - 0.75, BAY / 2 - ow / 2 + ow / 3, Y0 + 0.05, oz, TIMBER)
    array(mul, 2, (ow / 3, 0, 0))
    parts.append(mul)
    # 招牌：出挑的深色招牌板 + 金色压条
    sign = PX("fascia", [(Y0 - 0.2, 0), (Y0 + 0.02, 0), (Y0 + 0.02, 0.8), (Y0 - 0.26, 0.8), (Y0 - 0.26, 0.7), (Y0 - 0.2, 0.66)], BAY - 0.7, SIGN, 0.35)
    sign.location.z = oz + oh + 0.22
    parts.append(sign)
    parts.append(B("sign_gold", BAY - 0.9, 0.04, 0.08, BAY / 2, Y0 - 0.27, oz + oh + 0.5, GOLD))
    # 壁柱
    for x in (0.32, BAY - 0.32):
        parts.append(B("pil", 0.44, 0.2, GF - 0.35, x, Y0 - 0.08, 0, TRIM))
        parts.append(B("pil_cap", 0.58, 0.28, 0.2, x, Y0 - 0.12, GF - 0.55, TRIM))
    # 遮阳篷：一块斜帆布 + 前沿垂边
    ax0, ax1 = 0.5, BAY - 0.5
    aw_z = oz + oh + 0.1
    parts.append(quad("awning", (ax1, Y0 - 0.05, aw_z + 0.05), (ax0, Y0 - 0.05, aw_z + 0.05), (ax0, Y0 - 1.55, aw_z - 0.75), (ax1, Y0 - 1.55, aw_z - 0.75), AWN))
    parts.append(quad("valance", (ax1, Y0 - 1.55, aw_z - 0.75), (ax0, Y0 - 1.55, aw_z - 0.75), (ax0, Y0 - 1.57, aw_z - 1.05), (ax1, Y0 - 1.57, aw_z - 1.05), AWN))
    # 双面：背面（从上往下看 / 从店里看）也要有帆布，否则会被背面剔除而「消失」
    parts.append(quad("awning_b", (ax0, Y0 - 0.05, aw_z + 0.05), (ax1, Y0 - 0.05, aw_z + 0.05), (ax1, Y0 - 1.55, aw_z - 0.75), (ax0, Y0 - 1.55, aw_z - 0.75), AWN))
    parts.append(quad("valance_b", (ax0, Y0 - 1.55, aw_z - 0.75), (ax1, Y0 - 1.55, aw_z - 0.75), (ax1, Y0 - 1.57, aw_z - 1.05), (ax0, Y0 - 1.57, aw_z - 1.05), AWN))
    rod = curve_bevel("awn_rod", [(ax0 + 0.05, Y0 - 0.1, aw_z + 0.4), (ax0 + 0.05, Y0 - 1.5, aw_z - 0.7)], 0.025, IRON)
    mirror(rod, 0, (BAY / 2, 0, 0))
    parts.append(rod)
    return join(parts, "sk_gf_shop")

def gf_arch():
    """拱窗开间：砖石墙 + 拱洞 + 拱券线脚 + 拱心石 + 窗棂。"""
    w, z0, h = 2.4, 1.0, 3.7
    parts = [panel("gf_wall", BAY, GF, STONE, ("arch", BAY / 2, z0, w, h))]
    parts += window(BAY / 2, z0, w, h, shutters=False, arch=True)
    parts.append(B("key", 0.36, 0.2, 0.55, BAY / 2, Y0 - 0.1, z0 + h - 0.02, TRIM))
    parts.append(PX("plinth", [(Y0 - 0.12, 0), (Y0 + 0.02, 0), (Y0 + 0.02, 0.5), (Y0 - 0.06, 0.5), (Y0 - 0.12, 0.42)], BAY, TRIM))
    return join(parts, "sk_gf_arch")

def gf_door():
    """拱门开间：拱洞 + 拱券线脚 + 木门扇（拱形，点缀槽）+ 铁箍 + 门前石阶一级。"""
    w, h = 2.3, 4.0
    parts = [panel("gf_wall", BAY, GF, STONE, ("arch", BAY / 2, 0, w, h))]
    r = w / 2
    pts = [(BAY / 2 - r + 0.06, 0), (BAY / 2 + r - 0.06, 0), (BAY / 2 + r - 0.06, h - r)] + [(BAY / 2 + (r - 0.06) * math.cos(math.pi * i / 10), h - r + (r - 0.06) * math.sin(math.pi * i / 10)) for i in range(1, 10)] + [(BAY / 2 - r + 0.06, h - r)]
    bm = bmesh.new()
    vs = [bm.verts.new((x, 0.0, z)) for x, z in pts]
    bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.y > 0:
            f.normal_flip()
    leaf = bm_obj("door_leaf", bm, ACC, ("solidify",))
    m = leaf.modifiers.new("s", "SOLIDIFY"); m.thickness = 0.1; m.offset = 0
    apply_mods(leaf)
    parts.append(leaf)
    parts.append(curve_bevel("door_ring", [(BAY / 2 + (r + 0.07) * math.cos(math.pi * i / 10), Y0 - 0.05, h - r + (r + 0.07) * math.sin(math.pi * i / 10)) for i in range(11)], 0.08, TRIM, square=True))
    parts.append(B("door_split", 0.05, 0.14, h - 0.3, BAY / 2, Y0 - 0.0, 0.0, IRON))
    for z in (0.7, 1.9, 3.1):
        parts.append(B("strap", w - 0.2, 0.13, 0.09, BAY / 2, Y0 - 0.0, z, IRON))
    parts.append(B("key", 0.34, 0.2, 0.5, BAY / 2, Y0 - 0.1, h - 0.02, TRIM))
    parts.append(B("step", w + 0.7, 0.6, 0.16, BAY / 2, Y0 - 0.35, 0, TRIM))
    parts.append(PX("plinth", [(Y0 - 0.12, 0), (Y0 + 0.02, 0), (Y0 + 0.02, 0.5), (Y0 - 0.06, 0.5), (Y0 - 0.12, 0.42)], BAY, TRIM))
    return join(parts, "sk_gf_door")

def gf_solid():
    parts = [panel("gf_wall", BAY, GF, STONE), PX("plinth", [(Y0 - 0.12, 0), (Y0 + 0.02, 0), (Y0 + 0.02, 0.5), (Y0 - 0.06, 0.5), (Y0 - 0.12, 0.42)], BAY, TRIM)]
    return join(parts, "sk_gf_solid")

# ================================================================== 标准层（FH = 4.4m）
def uf_half():
    """木筋灰泥墙：灰泥板（带窗洞）+ 木柱 / 横梁 / 斜撑 + 窗框窗板。"""
    ww, wh, wz = 1.25, 1.95, 1.05
    parts = [panel("uf_wall", BAY, FH, WALL, ("rect", BAY / 2, wz, ww, wh))]
    parts += window(BAY / 2, wz, ww, wh, shutters=True)
    ty = Y0 - 0.03
    parts += [B("post_l", 0.2, 0.12, FH, 0.1, ty, 0, TIMBER), B("post_r", 0.2, 0.12, FH, BAY - 0.1, ty, 0, TIMBER),
              B("rail_t", BAY, 0.12, 0.22, BAY / 2, ty, FH - 0.22, TIMBER), B("rail_b", BAY, 0.12, 0.2, BAY / 2, ty, 0, TIMBER),
              B("rail_m", BAY - 0.3, 0.1, 0.16, BAY / 2, ty, 0.62, TIMBER)]
    br = slant_box("brace", 0.2, 0.2, 0.95, FH - 0.25, 0.16, 0.1, ty, TIMBER)
    mirror(br, 0, (BAY / 2, 0, 0))
    parts.append(br)
    return join(parts, "sk_uf_half")

def uf_plain():
    """灰泥墙 + 石窗套 + 窗板 + 窗上小檐。"""
    ww, wh, wz = 1.3, 2.1, 1.0
    parts = [panel("uf_wall", BAY, FH, WALL, ("rect", BAY / 2, wz, ww, wh))]
    parts += window(BAY / 2, wz, ww, wh, shutters=True)
    parts.append(PX("hood", [(Y0 + 0.02, 0), (Y0 - 0.3, 0), (Y0 - 0.3, 0.08), (Y0 - 0.16, 0.2), (Y0 + 0.02, 0.2)], ww + 0.7, TRIM, BAY / 2 - (ww + 0.7) / 2))
    parts[-1].location.z = wz + wh + 0.12
    parts.append(B("corner_l", 0.34, 0.08, FH, 0.17, Y0 - 0.01, 0, TRIM))
    parts.append(B("corner_r", 0.34, 0.08, FH, BAY - 0.17, Y0 - 0.01, 0, TRIM))
    return join(parts, "sk_uf_plain")

def uf_brick():
    """红砖墙 + 石过梁 + 拱窗洞（用矩形窗 + 弧形过梁）。"""
    ww, wh, wz = 1.4, 2.2, 0.95
    parts = [panel("uf_wall", BAY, FH, BRICK, ("rect", BAY / 2, wz, ww, wh))]
    parts += window(BAY / 2, wz, ww, wh, shutters=False)
    parts.append(B("lintel", ww + 0.6, 0.2, 0.26, BAY / 2, Y0 - 0.05, wz + wh + 0.02, TRIM))
    parts.append(B("keystone", 0.3, 0.24, 0.4, BAY / 2, Y0 - 0.06, wz + wh + 0.0, TRIM))
    parts.append(B("quoin_l", 0.36, 0.1, FH, 0.18, Y0 - 0.02, 0, TRIM))
    parts.append(B("quoin_r", 0.36, 0.1, FH, BAY - 0.18, Y0 - 0.02, 0, TRIM))
    return join(parts, "sk_uf_brick")

def uf_balc():
    """落地窗 + 小阳台：挑台板 + 铁栏杆阵列 + 扶手 + 两个托架。"""
    ww, wh, wz = 1.5, 3.0, 0.1
    parts = [panel("uf_wall", BAY, FH, WALL, ("rect", BAY / 2, wz, ww, wh))]
    parts += window(BAY / 2, wz, ww, wh, shutters=True, cross=True)
    L = ww + 1.0
    slab = PX("balc_slab", [(Y0 + 0.02, 0), (Y0 - 0.85, 0), (Y0 - 0.85, 0.14), (Y0 - 0.7, 0.2), (Y0 + 0.02, 0.2)], L, TRIM, BAY / 2 - L / 2)
    slab.location.z = -0.2
    parts.append(slab)
    bal = B("rail_bar", 0.035, 0.035, 0.92, BAY / 2 - L / 2 + 0.06, Y0 - 0.8, 0.0, IRON)
    array(bal, int(L / 0.16), (L / int(L / 0.16), 0, 0))
    parts.append(bal)
    parts.append(B("handrail", L, 0.08, 0.07, BAY / 2, Y0 - 0.8, 0.92, IRON))
    for sx in (-1, 1):
        parts.append(B("rail_end", 0.035, 0.7, 0.92, BAY / 2 + sx * (L / 2 - 0.04), Y0 - 0.5, 0.0, IRON))
    parts.append(B("console", 0.22, 0.5, 0.5, BAY / 2 - L / 2 + 0.2, Y0 - 0.3, -0.7, TRIM))
    c2 = B("console", 0.22, 0.5, 0.5, BAY / 2 + L / 2 - 0.2, Y0 - 0.3, -0.7, TRIM)
    parts.append(c2)
    return join(parts, "sk_uf_balc")

def uf_blank():
    """无窗灰泥墙（山墙 / 侧墙 / 背墙）。"""
    parts = [panel("uf_wall", BAY, FH, WALL)]
    return join(parts, "sk_uf_blank")

def uf_side():
    """侧 / 背墙带小窗：灰泥板 + 小窗 + 窗框。"""
    ww, wh, wz = 0.9, 1.4, 1.5
    parts = [panel("uf_wall", BAY, FH, WALL, ("rect", BAY / 2, wz, ww, wh))]
    parts += window(BAY / 2, wz, ww, wh, shutters=False, cross=True)
    return join(parts, "sk_uf_side")

# ================================================================== 线脚（腰线 / 檐口）
def band():
    """层间腰线（出挑 0.2m 的窄线脚；也是木筋房的「悬挑」）。"""
    return join([PX("band", [(Y0 + 0.02, 0), (Y0 - 0.16, 0), (Y0 - 0.22, 0.06), (Y0 - 0.22, 0.16), (Y0 + 0.02, 0.2)], BAY, TRIM)], "sk_band")

def eave():
    """檐口：出挑托檐板 + 牛腿托（阵列）。"""
    prof = [(Y0 + 0.02, 0), (Y0 - 0.1, 0), (Y0 - 0.1, 0.1), (Y0 - 0.32, 0.18), (Y0 - 0.32, 0.4), (Y0 + 0.02, 0.4)]
    c = PX("cornice", prof, BAY, TRIM)
    cb = B("corbel", 0.2, 0.34, 0.34, 0.5, Y0 - 0.12, -0.3, TIMBER)
    array(cb, 4, (1.0, 0, 0))
    return join([c, cb], "sk_eave")

# ================================================================== 屋顶
def roof_gable():
    """双坡屋面一个开间（屋脊沿 X）：前后两坡（实体化的瓦面）+ 屋脊压条。原点在墙顶、前墙中心线；进深 DN，装配时 Y、Z 同比缩放。"""
    ov = 0.75      # 檐口外挑
    yf, yb = Y0 - ov + 0.15, DN - Y0 + ov - 0.15
    ym = DN / 2
    zf = -0.55
    rid = RN
    parts = []
    for side in (0, 1):
        ys, ye = (yf, ym) if side == 0 else (yb, ym)
        zs = zf
        bm = bmesh.new()
        vs = [bm.verts.new(p) for p in ((0.0, ys, zs), (BAY, ys, zs), (BAY, ye, rid), (0.0, ye, rid))]
        bm.faces.new(vs if side == 0 else list(reversed(vs)))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = bm_obj("slope", bm, ROOF, ("solidify",))
        for f in ob.data.polygons:
            if f.normal.z < 0:
                break
        m = ob.modifiers.new("s", "SOLIDIFY"); m.thickness = 0.22; m.offset = -1
        apply_mods(ob)
        parts.append(ob)
    parts.append(B("ridge", BAY + 0.02, 0.34, 0.22, BAY / 2, ym, rid - 0.02, TRIM))
    # 檐口封檐板（前后）
    parts.append(B("fascia_f", BAY, 0.1, 0.3, BAY / 2, yf - 0.02, zf - 0.28, TRIM))
    parts.append(B("fascia_b", BAY, 0.1, 0.3, BAY / 2, yb + 0.02, zf - 0.28, TRIM))
    return join(parts, "sk_roof_gable")

def gable_end():
    """山墙（朝 -X）：三角墙（灰泥）+ 木筋（立柱 / 横梁 / 人字撑）+ 封檐斜板 + 圆窗。原点在墙顶、前墙中心线、山墙中心线。"""
    tri = [(Y0 - 0.05, 0), (DN - Y0 + 0.05, 0), (DN / 2, RN)]
    wall = profile_extrude("gable_wall", tri, T, WALL, "x")
    wall.location.x = -T / 2
    ty = -T / 2 - 0.03
    parts = [wall]
    prof = lambda y0, z0, y1, z1, w: None
    # 木筋：立柱 + 横梁（x = 外墙面）
    def vbar(y, z0, z1, w=0.2):
        return B("g_post", 0.12, w, z1 - z0, ty, y, z0, TIMBER)
    for y in (0.15, DN - 0.15):
        parts.append(vbar(y, 0, 0.2))
    parts.append(B("g_tie", 0.12, DN - 0.1, 0.22, ty, DN / 2, 0, TIMBER))
    parts.append(vbar(DN / 2, 0, RN - 0.4, 0.22))
    parts.append(B("g_collar", 0.12, DN * 0.5, 0.18, ty, DN / 2, RN * 0.5, TIMBER))
    # 人字边梁（沿屋面斜边的封檐板，包出墙外）
    for s in (0, 1):
        y0, y1 = (Y0 - 0.05, DN / 2) if s == 0 else (DN - Y0 + 0.05, DN / 2)
        run = abs(y1 - y0)
        d = math.hypot(run, RN)
        ang = math.atan2(RN, run)
        rb = profile_extrude("rake", [(-0.17, -0.12), (0.17, -0.12), (0.17, 0.12), (-0.17, 0.12)], d, TRIM, "x")
        # 沿 Y（进深）方向的斜杆：先沿 X 挤出，再旋到 YZ 面；前坡朝 +Y、后坡朝 -Y；以山墙外面（x=-0.15）为中线，向外探出 0.17
        rb.matrix_world = Matrix.Translation((-0.15, y0, 0)) @ Matrix.Rotation(math.pi / 2 if s == 0 else -math.pi / 2, 4, "Z") @ Matrix.Rotation(-ang, 4, "Y")
        bpy.context.view_layer.update()
        parts.append(rb)
    # 圆形通风窗（旋绕 / 圆环）
    ring = curve_bevel("vent_ring", [(ty - 0.02, DN / 2 + 0.45 * math.cos(a), RN * 0.33 + 0.45 * math.sin(a)) for a in [i * math.pi / 6 for i in range(13)]], 0.06, TRIM)
    parts.append(ring)
    parts.append(quad("vent", (ty - 0.0, DN / 2 - 0.4, RN * 0.33 - 0.4), (ty - 0.0, DN / 2 + 0.4, RN * 0.33 - 0.4), (ty - 0.0, DN / 2 + 0.4, RN * 0.33 + 0.4), (ty - 0.0, DN / 2 - 0.4, RN * 0.33 + 0.4), PANE))
    ob = join(parts, "sk_gable_end")
    return ob

def dormer():
    """屋面老虎窗（朝 -Y）：小山墙（灰泥）+ 窗 + 两坡小屋顶（瓦）。原点在底部中心（贴屋面处）。"""
    w, h = 1.7, 1.5
    parts = [B("dw", w, 0.4, h, 0, 0.1, 0, WALL)]
    parts += window(0.0, 0.35, 0.8, 0.95, shutters=False, cross=True)
    # 把窗搬到老虎窗前面（窗构件以墙中心线 y=0 为基准，这里墙面在 y=-0.1）
    for p in parts[1:]:
        p.location.y += 0.1
    # 小屋顶：两坡
    for sx in (-1, 1):
        bm = bmesh.new()
        vs = [bm.verts.new(p) for p in ((sx * (w / 2 + 0.2), -0.3, h - 0.1), (sx * 0.0, -0.3, h + 0.75), (sx * 0.0, 1.2, h + 0.75), (sx * (w / 2 + 0.2), 1.2, h - 0.1))]
        bm.faces.new(vs if sx > 0 else list(reversed(vs)))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        ob = bm_obj("dslope", bm, ROOF, ("solidify",))
        m = ob.modifiers.new("s", "SOLIDIFY"); m.thickness = 0.14; m.offset = -1
        apply_mods(ob)
        parts.append(ob)
    # 山尖三角
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((-w / 2, -0.1, h - 0.12), (w / 2, -0.1, h - 0.12), (0, -0.1, h + 0.7))]
    bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.y > 0:
            f.normal_flip()
    parts.append(bm_obj("dtri", bm, WALL, ("vertex",)))
    parts.append(B("dridge", 0.14, 1.4, 0.1, 0, 0.5, h + 0.72, TRIM))
    return join(parts, "sk_dormer")

def chimney():
    """烟囱：砖身（收分）+ 石压顶 + 两个烟道口。"""
    shaft = B("ch_shaft", 0.9, 0.9, 2.6, 0, 0, 0, BRICK)
    cap = B("ch_cap", 1.2, 1.2, 0.2, 0, 0, 2.6, TRIM)
    pot = B("pot", 0.3, 0.3, 0.35, -0.22, 0, 2.8, IRON)
    mirror(pot, 0, (0, 0, 0))
    return join([shaft, cap, pot], "sk_chimney")

def roof_skirt(kind="mansard"):
    """屋面裙边一个开间（沿 X）。mansard = 陡坡芒萨尔（高 3.9、顶部内收 1.55，石板瓦槽）；hip = 四坡屋面裙边（高 3.0、内收 3.0，陶瓦槽）。
    原点在墙顶、墙中心线。"""
    if kind == "hip":
        h, yi, mat = 3.0, 3.0, ROOF
    else:
        h, yi, mat = 3.9, 1.55, ROOF_S
    yo = Y0 - 0.5
    prof = [(yo, -0.3), (yi, h), (yi - 0.3, h), (Y0 + 0.02, 0.0)]
    slope = PX("skirt", prof, BAY, mat)
    roll = curve_bevel("roll", [(0, yo - 0.02, -0.28), (BAY, yo - 0.02, -0.28)], 0.1, TRIM)
    parts = [slope, roll]
    if kind != "hip":
        parts.append(curve_bevel("top_roll", [(0, yi + 0.02, h + 0.04), (BAY, yi + 0.02, h + 0.04)], 0.09, LEAD))
    return join(parts, "sk_" + kind + "_bay")

def mansard_bay():
    return roof_skirt("mansard")

def miter(ob, side, phi_deg=90.0):
    """屋面裙边端部斜接：phi = 该转角的室内夹角（90 直角、135 切角）。side='L' 在 x=0 端、'R' 在 x=BAY 端。
    先把直件向外延伸 1.6m，再沿转角平分面切掉（保留靠近本件的一侧）。"""
    half = math.radians(phi_deg) / 2
    bm = bmesh.new(); bm.from_mesh(ob.data)
    for v in bm.verts:
        if side == "L" and v.co.x < 0.01:
            v.co.x -= 1.6
        if side == "R" and v.co.x > BAY - 0.01:
            v.co.x += 1.6
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    no = (math.sin(half), -math.cos(half), 0) if side == "L" else (-math.sin(half), -math.cos(half), 0)
    co = (0, 0, 0) if side == "L" else (BAY, 0, 0)
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=co, plane_no=no, clear_inner=True)
    bd = [e for e in bm.edges if e.is_boundary]
    if bd:
        bmesh.ops.holes_fill(bm, edges=bd, sides=12)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(ob.data); bm.free()
    ob["methods"] = ",".join(sorted(set(ob.get("methods", "").split(",")) | {"vertex"} - {""}))
    return ob

def skirt_end(kind, side, phi):
    ob = roof_skirt(kind)
    miter(ob, side, phi)
    ob.name = "sk_%s_%s%d" % (kind, side, phi)
    return ob
def mansard_dormer():
    """芒萨尔老虎窗（朝 -Y，原点在斜面中点附近）：竖窗墙 + 窗 + 三角小屋顶。"""
    w, h = 1.55, 1.7
    parts = [B("dw", w, 0.5, h, 0, 0.1, 0, WALL)]
    parts += window(0.0, 0.3, 0.75, 1.0, shutters=False, cross=True)
    for p in parts[1:]:
        p.location.y += 0.1
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in ((-w / 2 - 0.15, -0.25, h), (w / 2 + 0.15, -0.25, h), (w / 2 + 0.15, -0.25, h + 0.1), (0, -0.25, h + 0.75), (-w / 2 - 0.15, -0.25, h + 0.1))]
    bm.faces.new(vs)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:
        if f.normal.y > 0:
            f.normal_flip()
    ped = bm_obj("ped", bm, TRIM, ("solidify",))
    m = ped.modifiers.new("s", "SOLIDIFY"); m.thickness = 0.25; m.offset = 0
    apply_mods(ped)
    parts.append(ped)
    return join(parts, "sk_mansard_dormer")

def roof_flat():
    """芒萨尔顶面：4.4×4.4 的薄锌皮板（装配时按顶面大小缩放）。原点在板中心 / 底面。"""
    return join([B("flat", BAY, BAY, 0.16, BAY / 2, BAY / 2, 0, LEAD)], "sk_roof_flat")

def catalog():
    return {
        "sk_gf_shop": (gf_shop, "底层", "商铺开间：石墙裙 + 大橱窗 + 招牌 + 遮阳篷 + 壁柱"),
        "sk_gf_arch": (gf_arch, "底层", "拱窗开间：砖石墙 + 拱洞 + 拱券线脚 + 拱心石"),
        "sk_gf_door": (gf_door, "底层", "拱门开间：拱形木门 + 铁箍 + 拱券线脚 + 门前石阶"),
        "sk_gf_solid": (gf_solid, "底层", "实墙开间（侧 / 背墙）"),
        "sk_uf_half": (uf_half, "标准层", "木筋灰泥墙 + 窗板窗"),
        "sk_uf_plain": (uf_plain, "标准层", "灰泥墙 + 石窗套 + 窗板 + 小檐"),
        "sk_uf_brick": (uf_brick, "标准层", "红砖墙 + 石过梁窗"),
        "sk_uf_balc": (uf_balc, "标准层", "落地窗 + 铁艺小阳台"),
        "sk_uf_blank": (uf_blank, "标准层", "无窗灰泥墙"),
        "sk_uf_side": (uf_side, "标准层", "侧 / 背墙带小窗"),
        "sk_band": (band, "线脚", "层间腰线"),
        "sk_eave": (eave, "线脚", "檐口 + 牛腿"),
        "sk_roof_gable": (roof_gable, "屋顶", "双坡屋面一个开间（进深 14m 名义，Y/Z 同比缩放）"),
        "sk_gable_end": (gable_end, "屋顶", "木筋山墙（朝 -X）"),
        "sk_dormer": (dormer, "屋顶", "双坡老虎窗"),
        "sk_chimney": (chimney, "屋顶", "砖烟囱"),
        "sk_mansard_bay": (mansard_bay, "屋顶", "芒萨尔屋面一个开间"),
        **{"sk_mansard_%s%d" % (s, p): ((lambda s=s, p=p: skirt_end("mansard", s, p)), "屋顶", "芒萨尔屋面端部开间（%s 端，转角室内夹角 %d° 斜接）" % (s, p)) for s in "LR" for p in (90, 135)},
        "sk_hip_bay": ((lambda: roof_skirt("hip")), "屋顶", "四坡屋面裙边一个开间（陶瓦，顶部另封锥顶）"),
        **{"sk_hip_%s%d" % (s, p): ((lambda s=s, p=p: skirt_end("hip", s, p)), "屋顶", "四坡屋面裙边端部开间（%s 端，%d° 斜接）" % (s, p)) for s in "LR" for p in (90, 135)},
        "sk_mansard_dormer": (mansard_dormer, "屋顶", "芒萨尔老虎窗"),
        "sk_roof_flat": (roof_flat, "屋顶", "芒萨尔顶面薄板"),
    }
