# village_kit 鏋勫缓锛氶€愭爧瀵煎嚭 assets/models/village_kit/<id>.glb锛屾覆鏌撳瑙?/ 鍐呮櫙缂╃暐鍥?docs/village_kit/<id>_*.png锛屽啓 buildings.json銆?# "E:\FF瀵煎嚭\BlenderPortable\blender-4.5.10-windows-x64\blender.exe" -b -P tools/blender/village_kit/build.py -- [all|id1,id2]
import bpy, bmesh, math, os, sys, json, importlib
from mathutils import Vector, Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import vmat, geo, stamp, house, furn, compose, specs
for m in (vmat, geo, house, furn, compose, specs):
    importlib.reload(m)

ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "village_kit")
DOC = os.path.join(ROOT, "docs", "village_kit")
os.makedirs(OUT, exist_ok=True); os.makedirs(DOC, exist_ok=True)
SCALE = 3.0 / 2.3   # 唯一世界比例：门洞 2.3m → 3.0m（玩家 1.7m）；Godot ZoneBuilder 使用同一常量


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    vmat.reset()


def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_apply=True, export_yup=True, export_format="GLB", export_image_format="NONE")


def setup_render(res):
    scn = bpy.context.scene
    eng = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scn.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in eng else "BLENDER_EEVEE"
    scn.render.resolution_x, scn.render.resolution_y = res
    w = bpy.data.worlds.new("w"); scn.world = w; w.use_nodes = True
    bg = next(n for n in w.node_tree.nodes if n.type == "BACKGROUND"); bg.inputs[0].default_value = (0.78, 0.84, 0.92, 1); bg.inputs[1].default_value = 0.9
    return scn


def cam_shot(path, pos, target, lens=35, res=(1100, 760), sun=True, point=None):
    scn = setup_render(res)
    objs = []
    if sun:
        s = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); scn.collection.objects.link(s)
        s.data.energy = 3.4; s.rotation_euler = (math.radians(52), math.radians(-14), math.radians(-35)); objs.append(s)
    for p in (point or []):
        l = bpy.data.objects.new("pl", bpy.data.lights.new("pl", "POINT")); scn.collection.objects.link(l)
        l.data.energy = p[3]; l.location = p[:3]; l.data.color = (1.0, 0.8, 0.55); l.data.shadow_soft_size = 0.4; objs.append(l)
    gm = bpy.data.materials.new("gnd"); gm.use_nodes = True
    next(n for n in gm.node_tree.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"].default_value = (0.32, 0.42, 0.2, 1)
    me = bpy.data.meshes.new("g"); bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=60); bm.to_mesh(me); bm.free(); me.materials.append(gm)
    g = bpy.data.objects.new("ground", me); scn.collection.objects.link(g); g.location.z = -0.02; objs.append(g)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    cam.data.lens = lens; cam.data.clip_start = 0.05
    cam.location = pos
    cam.rotation_euler = (Vector(target) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)
    for o in objs + [cam]:
        bpy.data.objects.remove(o)


def tri_count(objs):
    t = 0
    for o in objs:
        o.data.calc_loop_triangles(); t += len(o.data.loop_triangles)
    return t


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sel = args[0] if args else "all"
    ids = list(specs.SPECS) if sel == "all" else sel.split(",")
    mp = os.path.join(OUT, "buildings.json")
    meta_all = json.load(open(mp, encoding="utf-8")) if os.path.exists(mp) else {}
    for cid in ids:
        clear()
        sp = specs.SPECS[cid]
        G, meta = compose.build_house(sp, sp.get("seed", 1))
        obs = G.finish(cid)
        objs = list(obs.values())
        # MMO 灏哄害锛氭暣浣撴斁澶?S 鍊嶏紙闂?鈮?m 瀹?脳 3.4m 楂橈紝灞傞珮 鈮?.8m锛屾埧闂村鏁烇級锛岀綉鏍奸噷鐩存帴鐑樼剻锛涘厓鏁版嵁鍚屾鏀惧ぇ
        S = SCALE
        for o in objs:
            o.data.transform(Matrix.Scale(S, 4))
        for k in ("w", "d", "h"):
            meta[k] = round(meta[k] * S, 2)
        meta["door"] = [round(v * S, 2) for v in meta["door"]]
        meta["bbox"] = [round(v * S, 2) for v in meta["bbox"]]
        meta["fp"] = [round(v * S, 2) for v in meta["fp"]]
        if "ext" in meta:
            meta["ext"] = [round(v * S, 2) for v in meta["ext"]]
        meta["inner"] = [round(v * S, 2) for v in meta["inner"]]
        meta["lights"] = [[round(l[0] * S, 2), round(l[1] * S, 2), round(l[2] * S, 2), round(l[3] * S, 1), l[4]] for l in meta["lights"]]
        meta["smoke"] = [[round(v * S, 2) for v in s] for s in meta["smoke"]]
        if "npcs" in meta:
            meta["npcs"] = {k: [round(v[0] * S, 2), round(v[1] * S, 2)] for k, v in meta["npcs"].items()}
        meta["scale"] = S
        meta["tris"] = tri_count(objs)
        export(objs, os.path.join(OUT, cid + ".glb"))
        W, D, h = meta["w"], meta["d"], meta["h"]
        r = max(W, D, h)
        c = Vector(((meta["bbox"][0] + meta["bbox"][2]) / 2, (meta["bbox"][1] + meta["bbox"][3]) / 2, h * 0.38))
        cam_shot(os.path.join(DOC, cid + "_ext.png"), c + Vector((r * 0.95, -r * 1.55, r * 0.42)), c + Vector((0, 0, -h * 0.05)), 34)
        # 鍐呮櫙锛氱浉鏈烘斁鍦ㄩ棬鍐呭乏鍓嶈锛屾湞瀵硅
        bx0, by0, bx1, by1 = meta["fp"]
        ctr = Vector(((bx0 + bx1) / 2, (by0 + by1) / 2, 1.2 * SCALE))
        hc = sp.get("Hc", sp["H"] if sp.get("rows", 1) == 1 else 3.3) * SCALE
        cam_shot(os.path.join(DOC, cid + "_int.png"), Vector((bx0 + 1.4, by0 + 1.2, 1.85 * SCALE * 0.8)), Vector((bx1 - 2.0, by1 - 1.4, 1.2 * SCALE)), 22,
                 point=[(ctr.x, ctr.y, hc - 0.8, 900), (ctr.x - 2, ctr.y + 1, 1.5, 300)])
        meta_all[cid] = meta
        print("BUILT", cid, meta["w"], meta["d"], meta["h"], meta["tris"], flush=True)
    json.dump(meta_all, open(mp, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
    print("VILLAGE_KIT_DONE", len(ids))


