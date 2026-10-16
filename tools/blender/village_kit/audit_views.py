# 多视角审计图：每件渲 前 / 后 / 左 / 右 / 俯视 / 仰视 6 个正交视角（带背面可见：关闭背面剔除用不同底色看缺面），拼成 docs/village_kit/parts/audit/<id>.png。
# blender -b -P tools/blender/village_kit/audit_views.py -- [id1,id2|all]
import bpy, bmesh, math, os, sys
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, "..", "modkit"))
import kit, vmat, parts, smith_parts
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "docs", "village_kit", "parts", "audit")
os.makedirs(OUT, exist_ok=True)
VIEWS = [("front", (0, -1, 0.15)), ("back", (0, 1, 0.15)), ("left", (-1, 0, 0.15)), ("right", (1, 0, 0.15)), ("top", (0, -0.01, 1)), ("under", (0, -0.01, -1))]


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit.COL = None
    vmat.reset()
    kit.mat = lambda key: vmat.get(kit.PAL.get(key, key))


def render_views(pid, ob):
    scn = bpy.context.scene
    # 背面显示成醒目的洋红：缺面 / 法线反了的面一眼可见（Blender 材质：backface_culling 关，背面用 Backfacing 节点）
    for m in ob.data.materials:
        if not m or not m.use_nodes:
            continue
        nt = m.node_tree
        out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        geo = nt.nodes.new("ShaderNodeNewGeometry")
        mixn = nt.nodes.new("ShaderNodeMixShader")
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (1.0, 0.0, 0.8, 1.0)
        nt.links.new(geo.outputs["Backfacing"], mixn.inputs["Fac"])
        nt.links.new(bsdf.outputs["BSDF"], mixn.inputs[1])
        nt.links.new(em.outputs["Emission"], mixn.inputs[2])
        nt.links.new(mixn.outputs["Shader"], out.inputs["Surface"])
        m.use_backface_culling = False
    eng = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scn.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in eng else "BLENDER_EEVEE"
    scn.render.resolution_x = scn.render.resolution_y = 560
    scn.render.film_transparent = False
    w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = (0.86, 0.88, 0.9, 1); bg.inputs[1].default_value = 1.1
    s = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(s)
    s.data.energy = 2.6; s.rotation_euler = (math.radians(55), math.radians(-10), math.radians(-35))
    bpy.context.view_layer.update()
    mn, mx = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for v in ob.data.vertices:
        mn = Vector(map(min, mn, v.co)); mx = Vector(map(max, mx, v.co))
    ctr = (mn + mx) / 2
    d = (mx - mn).length
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = d * 0.95; cam.data.clip_end = 1000
    imgs = []
    for name, dv in VIEWS:
        dv = Vector(dv).normalized()
        cam.location = ctr + dv * (d * 2 + 10)
        up = "Y"
        cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", up).to_euler()
        p = os.path.join(OUT, "%s__%s.png" % (pid, name))
        scn.render.filepath = p
        bpy.ops.render.render(write_still=True)
        imgs.append((name, p))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sel = args[0] if args else "all"
    todo = [p for p in parts.PARTS if sel == "all" or p[0] in sel.split(",") or p[0].split("_")[0] in sel.split(",")]
    for pid, fn, zh in todo:
        clear()
        ob = fn()
        render_views(pid, ob)
        print("VIEW", pid, flush=True)
