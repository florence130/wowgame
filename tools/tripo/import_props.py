# Tripo 成品 GLB → 游戏资产（2026-10-10 用户：不用 Tripo 的纹理，重绘材质和贴图，可让 GPT 协助）。
# 流程：
#   1. 取 Tripo 模型的几何（丢弃它的 4096 贴图）；合并、底面中心为原点、按目标尺寸等比缩放、减面到 ~15k 三角（碰撞也用它）
#   2. 按「Tripo 贴图颜色」给每个三角面聚类（k-means，k=7），再用邻面多数投票去噪点
#   3. 让 GPT（gpt-6.1-sol，看概念图 + 各簇颜色 / 面积 / 高度）把每个簇判成一种材质：木 / 浅木 / 石 / 碎石 / 灰泥 / 茅草 / 红瓦 / 石板 / 金属 / 布 / 皮革 / 植物 / 水 / 发光 / 纸；
#      没有网络或解析失败时退回颜色规则
#   4. 材质换成本项目的 K| 材质（洛奇M 方砖裁出的手绘平涂 + PBR 法线 / 粗糙度贴图，三向投影，底色 = 簇均色），导出 GLB（不含任何图片）
# 输出 assets/models/tripo_town/<name>.glb + props.json（[宽, 高, 深]）+ docs/goldenear_concept/props_labels.json（GPT 的判定，便于复查）
# "E:\FF导出\BlenderPortable\blender-4.5.10-windows-x64\blender.exe" -b -P tools/tripo/import_props.py -- [name1,name2] [--no-gpt]
import bpy, os, sys, json, base64, colorsys, urllib.request
import numpy as np
from mathutils import Vector

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SRC = os.path.join(ROOT, ".local", "tripo_out", "props")
OUT = os.path.join(ROOT, "assets", "models", "tripo_town")
CONCEPT = os.path.join(ROOT, "docs", "goldenear_concept", "props")
LABELS = os.path.join(ROOT, "docs", "goldenear_concept", "props_labels.json")
os.makedirs(OUT, exist_ok=True)
TARGET = {
    "fountain": ("w", 9.0), "waystone": ("h", 3.4), "lamp": ("h", 5.2), "well": ("h", 3.6), "stall_fruit": ("w", 4.6), "stall_herb": ("w", 4.6),
    "stall_weapon": ("w", 5.2), "noticeboard": ("w", 3.4), "signpost": ("h", 3.4), "haycart": ("w", 4.6), "haystack": ("h", 3.6), "bench": ("w", 2.9),
    "woodshed": ("w", 3.6), "trough": ("w", 3.0), "brazier": ("h", 2.4), "scarecrow": ("h", 3.0),
    # 室内家具（Blender 里按各房间需要的尺寸再缩放；这里只定名义大小）
    "table": ("w", 2.6), "bench_long": ("w", 2.4), "chair": ("h", 1.5), "stool": ("h", 0.7), "bed": ("w", 2.6), "bookshelf": ("h", 2.9), "cupboard": ("h", 2.6),
    "counter": ("w", 3.4), "fireplace": ("h", 3.6), "chandelier": ("w", 1.6), "anvil": ("h", 1.4), "forge": ("w", 3.0), "weaponrack": ("w", 2.0), "barrel": ("h", 1.4),
    "chest": ("w", 1.4), "mannequin": ("h", 2.1),
    # 建筑细节件
    "sign_tavern": ("w", 1.6), "sign_smith": ("w", 1.6), "sign_store": ("w", 1.6), "sign_tailor": ("w", 1.6), "sign_guard": ("w", 1.6), "sign_trainer": ("w", 1.6),
    "sign_stable": ("w", 1.6), "dormer": ("w", 2.4), "chimney": ("h", 3.2), "window": ("w", 1.8), "door": ("h", 3.3), "wall_lantern": ("h", 1.0), "planter": ("w", 1.2),
    "porch": ("w", 3.6), "fence": ("w", 3.0), "steps": ("w", 2.4),
}
# 面数：室内 / 细节件会在每栋房子里出现很多次，压到更低（props 默认 15000）
TRIS_BY = {"table": 2200, "bench_long": 1500, "chair": 1600, "stool": 900, "bed": 2800, "bookshelf": 2800, "cupboard": 1800, "counter": 2200, "fireplace": 3500,
           "chandelier": 1800, "anvil": 1500, "forge": 3500, "weaponrack": 2500, "barrel": 1400, "chest": 1600, "mannequin": 1800, "sign_tavern": 1800, "sign_smith": 1800,
           "sign_store": 1800, "sign_tailor": 1800, "sign_guard": 1800, "sign_trainer": 1800, "sign_stable": 1800, "dormer": 3500, "chimney": 3000, "window": 2800, "door": 3000,
           "wall_lantern": 1500, "planter": 1500, "porch": 4500, "fence": 2500, "steps": 2500}
K = 7
# 全镇统一色板（与 village_kit/house.py 的 STYLES 同源）：同一种材质在所有物件上颜色一致；布 / 水 / 发光 / 植物保留原色
PAL = {"wood": "7a5236", "wood_light": "b08a5e", "stone": "b3a88f", "rubble": "9d937f", "plaster": "e4d6b8", "thatch": "d2b46a",
       "roof_tile": "b46a3e", "slate": "6f7a9a", "metal": "3d4048", "leather": "7a4a2e", "paper": "e8dcc0"}
TRIS = 15000
# 材质标签 → (K| mtype, 贴图, 每张米数)；颜色取簇均色（glow / glass 同）
MATS = {
    "wood": (6, "pt_wood", 4.0), "wood_light": (6, "pt_wood_light", 3.0), "stone": (2, "pt_ashlar", 2.8), "rubble": (2, "pt_rubble", 2.4),
    "plaster": (0, "pt_plaster", 4.0), "thatch": (3, "pt_shake", 1.8), "roof_tile": (4, "pt_roof_tile", 2.4), "slate": (3, "pt_roof_slate", 2.6),
    "metal": (7, "pt_metal", 2.0), "cloth": (0, "pt_awning", 2.0), "leather": (6, "pt_leather", 2.0), "foliage": (8, "pt_foliage", 3.0),
    "paper": (0, "", 3.0), "water": ("glass", "", 0), "glow": ("glow", "", 0),
}


def hexs(c):
    return "%02x%02x%02x" % tuple(int(max(0, min(1, v)) * 255 + 0.5) for v in c)


def rule_label(rgb, h):
    """没有 GPT 时的颜色规则。"""
    r, g, b = rgb
    hh, ss, vv = colorsys.rgb_to_hsv(r, g, b)
    if vv < 0.28:
        return "metal"
    if ss < 0.18:
        return "stone" if vv > 0.45 else "metal"
    if 0.52 < hh < 0.72 and ss > 0.45 and vv > 0.7:
        return "glow"
    if 0.45 < hh < 0.62:
        return "water"
    if 0.2 < hh < 0.45:
        return "foliage"
    if 0.1 <= hh <= 0.2 and ss > 0.45 and vv > 0.7:
        return "thatch"
    if hh < 0.04 or hh > 0.93:
        return "cloth"
    return "wood" if vv < 0.55 else "wood_light"


def kmeans(x, k, it=18, seed=3):
    rng = np.random.default_rng(seed)
    c = x[rng.choice(len(x), k, replace=False)]
    for _ in range(it):
        d = ((x[:, None, :] - c[None]) ** 2).sum(2)
        lab = d.argmin(1)
        for j in range(k):
            m = lab == j
            if m.any():
                c[j] = x[m].mean(0)
    return lab, c


def gpt_label(name, clusters):
    cfg = {}
    for ln in open(os.path.join(ROOT, ".local", "texgen.env"), encoding="utf-8"):
        if "=" in ln:
            a, b = ln.strip().split("=", 1)
            cfg[a] = b
    img = os.path.join(CONCEPT, name + ".png")
    content = [{"type": "text", "text":
                "You are a game artist doing material assignment for a Mabinogi-Mobile-style (hand-painted, chunky) 3D prop called '%s'. "
                "The image is the concept. The mesh was split into colour clusters (RGB hex, share of surface area, mean height 0=bottom..1=top, mean distance from vertical axis 0..1). "
                "Assign EACH cluster exactly one material label from: %s. "
                "Use 'glow' only for emissive crystals / flames / lantern light, 'water' for water surfaces, 'metal' for iron/steel/gold, 'cloth' for awnings/banners/clothes, 'thatch' for straw / hay, "
                "'foliage' for leaves/moss/grass. Reply with ONLY a JSON object mapping cluster id (string) to label." % (name, ", ".join(MATS), )}]
    content[0]["text"] += "\nClusters:\n" + "\n".join("%d: #%s share=%.2f height=%.2f radial=%.2f" % (c["id"], c["hex"], c["share"], c["h"], c["r"]) for c in clusters)
    if os.path.exists(img):
        content.append({"type": "image_url", "image_url": {"url": "data:image/png;base64," + base64.b64encode(open(img, "rb").read()).decode()}})
    body = json.dumps({"model": "gpt-6.1-sol", "messages": [{"role": "user", "content": content}], "max_tokens": 600}).encode()
    req = urllib.request.Request(cfg["TEX_API_BASE"].rstrip("/") + "/chat/completions", data=body,
                                 headers={"Authorization": "Bearer " + cfg["TEX_API_KEY"], "Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=180) as r:
        txt = json.loads(r.read().decode())["choices"][0]["message"]["content"]
    s, e = txt.find("{"), txt.rfind("}")
    d = json.loads(txt[s:e + 1])
    return {int(k): v for k, v in d.items() if v in MATS}


def process(name, use_gpt=True):
    glb = os.path.join(SRC, name, "model_0_0.glb")
    if not os.path.exists(glb):
        print("SKIP (no glb)", name)
        return None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb)
    ms = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in ms:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ms[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(ms) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    me = ob.data
    # ---- 1. 面颜色（采样 Tripo 的基础色贴图）
    img = None
    for m in me.materials:
        if m and m.node_tree:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and "metallic" not in n.image.name and "roughness" not in n.image.name and "normal" not in n.image.name:
                    img = n.image
                    break
        if img:
            break
    if img is None:
        print("NO TEXTURE", name)
        return None
    img.scale(1024, 1024)
    px = np.array(img.pixels[:], dtype=np.float32).reshape(1024, 1024, 4)[..., :3]
    uv = me.uv_layers.active.data
    fc = np.zeros((len(me.polygons), 3), np.float32)
    for p in me.polygons:
        u = sum(uv[l].uv.x for l in p.loop_indices) / p.loop_total
        v = sum(uv[l].uv.y for l in p.loop_indices) / p.loop_total
        fc[p.index] = px[min(1023, max(0, int(v * 1023))), min(1023, max(0, int(u * 1023)))]
    # ---- 2. 聚类 + 邻面多数投票
    lab, cent = kmeans(fc, K)
    adj = [[] for _ in me.polygons]
    ek = {}
    for p in me.polygons:
        for e in p.edge_keys:
            ek.setdefault(e, []).append(p.index)
    for fl in ek.values():
        if len(fl) == 2:
            adj[fl[0]].append(fl[1]); adj[fl[1]].append(fl[0])
    for _ in range(2):
        nl = lab.copy()
        for i, a in enumerate(adj):
            if a:
                cnt = np.bincount(lab[a + [i]], minlength=K)
                nl[i] = cnt.argmax()
        lab = nl
    # ---- 缩放 / 原点（先量再缩，簇统计用归一化高度）
    co = np.array([v.co[:] for v in me.vertices], np.float32)
    mn, mx = co.min(0), co.max(0)
    size = mx - mn
    mode, val = TARGET.get(name, ("h", 2.0))
    kscale = val / (size[2] if mode == "h" else max(size[0], size[1]))
    clusters = []
    for j in range(K):
        idx = [p.index for p in me.polygons if lab[p.index] == j]
        if not idx:
            continue
        cc = np.array([me.polygons[i].center[:] for i in idx])
        area = sum(me.polygons[i].area for i in idx)
        col = fc[idx].mean(0)
        clusters.append(dict(id=j, hex=hexs(col), col=col.tolist(), share=0.0, area=area,
                             h=float(((cc[:, 2] - mn[2]) / size[2]).mean()),
                             r=float((np.hypot(cc[:, 0] - (mn[0] + mx[0]) / 2, cc[:, 1] - (mn[1] + mx[1]) / 2) / (max(size[0], size[1]) / 2)).mean())))
    tot = sum(c["area"] for c in clusters)
    for c in clusters:
        c["share"] = c["area"] / tot
    # ---- 3. GPT 判材质
    labels = {}
    if use_gpt:
        try:
            labels = gpt_label(name, clusters)
        except Exception as ex:
            print("GPT failed, using rules:", repr(ex)[:200], flush=True)
    for c in clusters:
        if c["id"] not in labels:
            labels[c["id"]] = rule_label(c["col"], c["h"])
    # ---- 4. 材质：K| 名称，不带任何图片
    # 同一种「结构材质」的多个簇（Tripo 贴图里的明暗阴影差）合并成一个底色：明暗变化交给方砖手绘贴图，不再保留 Tripo 烘焙的阴影
    MERGE = ("wood", "wood_light", "stone", "rubble", "plaster", "thatch", "leather", "metal", "roof_tile", "slate")
    for lb in MERGE:
        grp = [c for c in clusters if labels[c["id"]] == lb]
        if len(grp) > 1:
            w = sum(c["area"] for c in grp)
            avg = [sum(c["col"][i] * c["area"] for c in grp) / w for i in range(3)]
            for c in grp:
                c["col"] = avg
    me.materials.clear()
    mi = {}
    for c in clusters:
        lb = labels[c["id"]]
        t, tex, m = MATS[lb]
        r, g, b = c["col"]
        h_, s_, v_ = colorsys.rgb_to_hsv(r, g, b)
        if lb in ("wood", "wood_light", "stone", "rubble", "plaster", "thatch", "roof_tile", "slate", "leather"):
            s_ = min(s_, 0.62)                        # 方砖贴图自带色差；底色略压饱和，更接近洛奇M 的平涂
        vmin = {"stone": 0.68, "rubble": 0.6, "plaster": 0.8, "wood_light": 0.62, "wood": 0.38, "thatch": 0.72}.get(lb, 0.0)   # Tripo 烘焙阴影把底色压得太暗；洛奇M 是明亮的平涂底色
        r, g, b = colorsys.hsv_to_rgb(h_, s_, min(1.0, max(v_ * 1.04, vmin)))
        if lb in PAL:
            r, g, b = (int(PAL[lb][i:i + 2], 16) / 255.0 for i in (0, 2, 4))
        mname = "K|%s|%s|%s|%s" % (t, hexs((r, g, b)), tex, m)
        if mname not in mi:
            mat = bpy.data.materials.new(mname)
            mat.diffuse_color = (r, g, b, 1)
            mi[mname] = len(me.materials)
            me.materials.append(mat)
        c["mat"] = mname
        c["label"] = lb
    cl_mat = {c["id"]: mi[c["mat"]] for c in clusters}
    for p in me.polygons:
        p.material_index = cl_mat[int(lab[p.index])]
    # ---- 缩放、原点、减面
    ctr = Vector(((mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, mn[2]))
    for v in me.vertices:
        v.co = (v.co - ctr) * kscale
    me.update()
    n0 = len(me.polygons)
    tgt = TRIS_BY.get(name, TRIS)
    if n0 > tgt // 2:
        md = ob.modifiers.new("dec", "DECIMATE")
        md.ratio = min(1.0, tgt / (n0 * (1.0 if name in TRIS_BY else 2.0)))
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier="dec")
    for im in list(bpy.data.images):
        bpy.data.images.remove(im)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), use_selection=True, export_apply=True, export_yup=True, export_format="GLB",
                              export_image_format="NONE", export_materials="EXPORT")
    me = ob.data
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    meta = [round(size[0] * kscale, 2), round(size[2] * kscale, 2), round(size[1] * kscale, 2)]
    print("PROP", name, meta, "tris", tris, os.path.getsize(os.path.join(OUT, name + ".glb")) // 1024, "KB", {c["hex"]: c["label"] for c in clusters}, flush=True)
    return meta, {c["hex"]: dict(label=c["label"], share=round(c["share"], 3)) for c in clusters}


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    use_gpt = "--no-gpt" not in args
    args = [a for a in args if not a.startswith("--")]
    names = args[0].split(",") if args else list(TARGET)
    mp = os.path.join(OUT, "props.json")
    allm = json.load(open(mp)) if os.path.exists(mp) else {}
    lab_all = json.load(open(LABELS, encoding="utf-8")) if os.path.exists(LABELS) else {}
    for n in names:
        r = process(n, use_gpt)
        if r:
            allm[n], lab_all[n] = r
    json.dump(allm, open(mp, "w"), indent=1)
    json.dump(lab_all, open(LABELS, "w", encoding="utf-8"), indent=1, ensure_ascii=False)





