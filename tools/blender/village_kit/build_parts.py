# 构建村屋复杂构件：逐件导出 assets/models/village_kit/parts/<id>.glb、渲染等距缩略图 docs/village_kit/parts/<id>.png，并拼接 contact sheet。
# "E:\FF导出\BlenderPortable\blender-4.5.10-windows-x64\blender.exe" -b -P tools/blender/village_kit/build_parts.py -- [all|id1,id2]
import bpy, bmesh, math, os, sys, json, importlib
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, "..", "modkit"))
import kit, vmat, parts, smith_parts
importlib.reload(vmat); importlib.reload(kit); importlib.reload(parts)
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "village_kit", "parts")
DOC = os.path.join(ROOT, "docs", "village_kit", "parts")
os.makedirs(OUT, exist_ok=True); os.makedirs(DOC, exist_ok=True)


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    kit.COL = None
    vmat.reset()
    kit.mat = lambda key: vmat.get(kit.PAL.get(key, key))


def split_nocol(ob):
    me = ob.data
    soft = [i for i, m in enumerate(me.materials) if m and ("glass" in m.name or "|8|" in m.name)]
    if not soft or len(soft) == len(me.materials):
        if soft:
            ob.name += "_nocol"
        return [ob]
    bm = bmesh.new(); bm.from_mesh(me); bm2 = bm.copy()
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index in soft], context="FACES")
    bmesh.ops.delete(bm2, geom=[f for f in bm2.faces if f.material_index not in soft], context="FACES")
    me2 = me.copy(); bm.to_mesh(me); bm2.to_mesh(me2); bm.free(); bm2.free()
    o2 = kit.new_obj(ob.name + "_soft_nocol", me2, [])
    return [ob, o2]


def bounds(objs):
    bpy.context.view_layer.update()
    mn, mx = Vector((1e9,) * 3), Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    return mn, mx


def render(path, objs):
    scn = bpy.context.scene
    eng = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scn.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in eng else "BLENDER_EEVEE"
    scn.render.resolution_x = scn.render.resolution_y = 800
    scn.render.film_transparent = True
    scn.render.image_settings.color_mode = "RGBA"
    w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = (0.82, 0.86, 0.92, 1); bg.inputs[1].default_value = 1.0
    s = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(s)
    s.data.energy = 3.0; s.rotation_euler = (math.radians(50), math.radians(-12), math.radians(-40))
    mn, mx = bounds(objs)
    ctr = (mn + mx) / 2
    d = (mx - mn).length
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = d * 0.98; cam.data.clip_end = 500
    # 外立面朝 -Y：从前左上方看
    dirv = Vector((-0.62, -0.72, 0.62)).normalized()
    cam.location = ctr + dirv * (d * 2 + 20)
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sel = args[0] if args else "all"
    todo = [p for p in parts.PARTS if sel == "all" or p[0] in sel.split(",") or p[0].split("_")[0] in sel.split(",")]
    meta = {}
    for pid, fn, zh in todo:
        clear()
        ob = fn()
        ob.name = pid
        objs = split_nocol(ob)
        mn, mx = bounds(objs)
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.select_set(True)
        bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, pid + ".glb"), use_selection=True, export_apply=True, export_yup=True, export_format="GLB", export_image_format="NONE")
        render(os.path.join(DOC, pid + ".png"), objs)
        tris = 0
        for o in objs:
            o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
        methods = sorted(set(m for o in objs for m in o.get("methods", "").split(",") if m))
        meta[pid] = dict(zh=zh, size=[round(mx.x - mn.x, 2), round(mx.y - mn.y, 2), round(mx.z - mn.z, 2)], min=[round(v, 2) for v in mn], tris=tris, methods=methods)
        print("PART", pid, meta[pid]["size"], tris, ",".join(methods), flush=True)
    mp = os.path.join(OUT, "parts.json")
    old = json.load(open(mp, encoding="utf-8")) if os.path.exists(mp) else {}
    old.update(meta)
    json.dump(old, open(mp, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print("PARTS_DONE", len(todo))
