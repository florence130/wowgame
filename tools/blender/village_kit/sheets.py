# 单件渲染：把 kitpieces 里的 20 个构件 + 24 件家具各渲成统一 3/4 正前左等距视角的透明底 PNG，
# 输出 docs/village_kit/tripo/items/{c01..c20,f01..f24}.png；总图拼合见 tools/texgen/make_village_sheets.py。
# "E:\FF导出\BlenderPortable\blender-4.5.10-windows-x64\blender.exe" -b -P tools/blender/village_kit/sheets.py -- [components|furniture|all]
import bpy, math, os, sys, random, importlib
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import vmat, geo, house, furn, kitpieces
for m in (vmat, geo, house, furn, kitpieces):
    importlib.reload(m)

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "docs", "village_kit", "tripo", "items")
os.makedirs(OUT, exist_ok=True)
RES = 900


def render_item(G, path):
    obs = G.finish("item")
    objs = list(obs.values())
    bpy.context.view_layer.update()
    mn, mx = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    ctr = (mn + mx) / 2
    scn = bpy.context.scene
    eng = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scn.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in eng else "BLENDER_EEVEE"
    scn.render.resolution_x = scn.render.resolution_y = RES
    scn.render.film_transparent = True
    scn.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = (0.82, 0.86, 0.92, 1); bg.inputs[1].default_value = 1.0
    s = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(s)
    s.data.energy = 3.0; s.rotation_euler = (math.radians(50), math.radians(-12), math.radians(-40))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    cam.data.type = "ORTHO"
    d = (mx - mn).length
    cam.data.ortho_scale = d * 0.98
    cam.data.clip_start = 0.1; cam.data.clip_end = 400
    dirv = Vector((-0.62, -0.72, 0.62)).normalized()
    cam.location = ctr + dirv * (d * 2 + 20)
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


def run(kind, n, builder, start=1):
    for i in range(start, n + 1):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        vmat.reset()
        rnd = random.Random(100 + i)
        G = builder(i, rnd)
        render_item(G, os.path.join(OUT, "%s%02d.png" % (kind, i)))
        print("ITEM", kind, i, flush=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sel = args[0] if args else "all"
    if sel in ("components", "all"):
        run("c", 22, kitpieces.build_component, int(args[1]) if len(args) > 1 else 1)
    if sel in ("furniture", "all"):
        run("f", 24, kitpieces.build_furniture, int(args[1]) if len(args) > 1 else 1)
    print("SHEETS_DONE")
