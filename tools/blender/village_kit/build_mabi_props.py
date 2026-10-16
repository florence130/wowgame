# 金穗镇广场武器摊：以洛奇M Dunbarton_WeaponStore 的摆件（兵器架 / 木桶 / 箱子）为「底模」，做我们自己的衍生版：
#   · 去掉它的帐篷布、旗和四根绑绳原木支柱（丢弃高处 / 外圈的面），只留桌面上的兵器、盾、桶、箱
#   · 摆件整体压扁 / 加顶点手作抖动 / 微弯；图集重新调色并向平涂压平（stamp.recolor_atlas，写到 assets/textures/mabi/*__stall.png）
#   · 篷顶、立柱是我们自己的：红 / 奶油条纹斜篷 + 倒角木柱（K| 材质，和房屋同一套手绘贴图）
# "E:\FF导出\BlenderPortable\blender-4.5.10-windows-x64\blender.exe" -b -P tools/blender/village_kit/build_mabi_props.py
import bpy, bmesh, os, sys, json, math
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import stamp
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "mabi")
os.makedirs(OUT, exist_ok=True)

TEX = "Dunbarton_WeaponStore_All_00"
RED, CREAM, WOOD = "K|0|b4503f||3.0", "K|0|ecdcb8||3.0", "K|6|8a5f3e|pt_wood|4.0"


def drop(c, zr):
    x, y, z = c
    return z > 2.3 or abs(x) > 3.0              # 帐篷绑绳 / 旗 / 立柱 / 篷顶高处的面


def box_obj(name, center, size, mat, rx=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    bm.transform(Matrix.Translation(center) @ Matrix.Rotation(rx, 4, "X"))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    me.materials.append(bpy.data.materials.get(mat) or bpy.data.materials.new(mat))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


bpy.ops.wm.read_factory_settings(use_empty=True)
mods = dict(s=(0.92, 0.9, 1.0), jitter=0.015, bend=0.05, hue=22, sat=0.82, val=1.05, flat=0.35, tag="stall", drop=drop)
objs = []
for part in ("Dunbarton_WeaponStore_Body_00", "Dunbarton_WeaponStore_Box_00"):
    d = stamp.get_obj(part, TEX, 1.0, center=False, mod=mods)
    me = bpy.data.meshes.new(part)
    me.from_pydata(d["verts"], [], d["faces"])
    me.update()
    uv = me.uv_layers.new(name="UVMap")
    for lp in me.loops:
        uv.data[lp.index].uv = d["uvs"][lp.vertex_index]
    m = bpy.data.materials.get(d["mk"]) or bpy.data.materials.new(d["mk"])
    me.materials.append(m)
    ob = bpy.data.objects.new(part, me)
    bpy.context.scene.collection.objects.link(ob)
    objs.append(ob)
# 我们自己的篷顶与立柱
H0, H1, Y0, Y1 = 3.5, 2.7, -2.5, 2.2
ang = math.atan2(H0 - H1, Y1 - Y0)
for i in range(9):
    objs.append(box_obj("stripe%d" % i, Vector((-3.6 + 0.8 * (i + 0.5), (Y0 + Y1) / 2, (H0 + H1) / 2)), (0.78, math.hypot(Y1 - Y0, H0 - H1) + 0.3, 0.07), RED if i % 2 == 0 else CREAM, rx=-ang))
for sx in (-3.2, 3.2):
    objs.append(box_obj("post_f%d" % (sx > 0), Vector((sx, Y0 + 0.1, H0 / 2)), (0.2, 0.2, H0), WOOD))
    objs.append(box_obj("post_b%d" % (sx > 0), Vector((sx, Y1 - 0.1, H1 / 2)), (0.2, 0.2, H1), WOOD))
objs.append(box_obj("valance", Vector((0, Y0 - 0.08, H0 - 0.18)), (7.4, 0.06, 0.34), RED))
# 脚底落地、中心对齐
mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
for o in objs:
    for v in o.data.vertices:
        mn = Vector(map(min, mn, v.co)); mx = Vector(map(max, mx, v.co))
off = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
for o in objs:
    o.data.transform(Matrix.Translation(-off))
bpy.ops.object.select_all(action="DESELECT")
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "weapon_stall.glb"), use_selection=True, export_apply=True, export_yup=True, export_format="GLB", export_image_format="NONE")
meta = dict(size=[round(mx.x - mn.x, 2), round(mx.z - mn.z, 2), round(mx.y - mn.y, 2)])        # [宽, 高, 深]
ALL_META = {"weapon_stall": meta}
print("MABI weapon_stall", meta, flush=True)


# ---------------------------------------------------------------- 深石矿坑摆件：洛奇M Barri 矿洞 / 宝石的网格当「底模」，做我们自己的衍生版
# 全部换成我们自己的 K| 材质（三向投影手绘贴图，和房屋同一套），不带它的图集；再做非等比缩放 / 手作抖动 / 微弯 / 收分。
ROCK, CRYST = "K|2|968678|pt_rubble|3.0", "K|0|86bfe0||3.0"
MINE_SETS = {
    # name: (OBJ, 材质, mod)
    "mine_crystal_a": ("Gem_Mineral_01", CRYST, dict(s=(0.7, 0.7, 0.8), jitter=0.02, bend=0.1, taper=0.12)),
    "mine_crystal_b": ("Gem_Mineral_03", CRYST, dict(s=(0.85, 0.8, 0.75), jitter=0.025, bend=-0.12, taper=0.08)),
    "mine_crystal_c": ("Gem_Mineral_06", CRYST, dict(s=(1.0, 1.0, 1.1), jitter=0.015, bend=0.15)),
    "mine_rock": ("Barri_SmallBoss_02_Rock_00", ROCK, dict(s=(1.6, 1.3, 1.3), jitter=0.06, bend=0.1)),
    "mine_scaffold": ("Barri_SmallBoss_01_Elevator_00", WOOD, dict(s=(0.4, 0.4, 0.42), jitter=0.03, bend=0.03)),
    "mine_trestle": ("Barri2_Vista_00_WoodFrame_05", WOOD, dict(s=(0.7, 0.7, 0.8), jitter=0.025, bend=-0.03)),
    "mine_gate": ("Barri_SmallBoss_02_CenterGate_00", WOOD, dict(s=(0.42, 0.42, 0.4), jitter=0.03, bend=0.04)),
    "mine_fence": ("Barri_SmallBoss_02_WoodFence_00", WOOD, dict(s=(0.5, 0.5, 0.55), jitter=0.02)),
    "mine_tower": ("Barri_Entrance_00_WoodFrame_03", WOOD, dict(s=(0.55, 0.55, 0.6), jitter=0.03, bend=0.05)),
}
for name, (objname, mk, mod) in MINE_SETS.items():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    m2 = dict(mod); m2["mk"] = mk
    d = stamp.get_obj(objname, "", 1.0, center=True, mod=m2)
    # 以脚底中心为原点已由 get_obj 处理
    me = bpy.data.meshes.new(name)
    me.from_pydata(d["verts"], [], d["faces"])
    me.update()
    me.materials.append(bpy.data.materials.get(mk) or bpy.data.materials.new(mk))
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True, export_apply=True, export_yup=True, export_format="GLB", export_image_format="NONE")
    xs = [v[0] for v in d["verts"]]; ys = [v[1] for v in d["verts"]]; zs = [v[2] for v in d["verts"]]
    ALL_META[name] = dict(size=[round(max(xs) - min(xs), 2), round(max(zs) - min(zs), 2), round(max(ys) - min(ys), 2)], faces=len(d["faces"]))
    print("MABI", name, ALL_META[name], flush=True)
json.dump(ALL_META, open(os.path.join(OUT, "mabi_props.json"), "w", encoding="utf-8"), indent=1)