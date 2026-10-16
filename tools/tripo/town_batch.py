# 金穗镇难做物件的 Tripo 文生批次：先全部提交（记录 id 到 .local/tripo_out/town_batch1.json），再逐个轮询下载到 .local/tripo_out/town/<name>/。
#   py tools/tripo/town_batch.py            提交 + 等待 + 下载（可中断；已提交的 id 会复用）
import os, sys, json, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo

STY = ("Mabinogi Mobile remake style hand-painted stylised fantasy village prop, soft flat painted colours, chunky rounded bevelled forms, warm saturated palette, "
       "clean silhouette, single object, no ground, no base plate, white background. ")
ITEMS = {
    "fountain": "Round three-tier stone fountain for a village plaza, warm grey fieldstone, wide octagonal lower basin with water, carved wheat-sheaf finial on top, water spouting into the basins.",
    "waystone": "Teleport waystone: waist-high rune-carved standing stone slab with softly glowing blue runes, a small floating blue crystal above it, on a round stepped stone base with a little moss.",
    "well": "Round fieldstone village well with a small red clay tile roof on two wooden posts, rope winch with wooden crank and a wooden bucket.",
    "stall": "Wooden village market stall with a red-and-cream striped fabric awning, plank counter with crates of apples and loaves of bread, wooden posts, hanging scale.",
    "haycart": "Two-wheeled wooden farm hand cart with spoked wheels and shafts, loaded with golden hay and a pitchfork.",
    "scarecrow": "Friendly scarecrow on a wooden cross post wearing a patched shirt and a straw hat, stuffed straw hands, burlap face with stitched smile.",
    "noticeboard": "Wooden village notice board with two posts, a tiny pitched shingle roof, pinned parchment papers and a wanted poster, no readable text.",
}
IDS = os.path.join(tripo.ROOT, ".local", "tripo_out", "town_batch1.json")
os.makedirs(os.path.dirname(IDS), exist_ok=True)
ids = json.load(open(IDS)) if os.path.exists(IDS) else {}
only = set(sys.argv[1].split(",")) if len(sys.argv) > 1 else None
# 一件一件来：提交 → 等它做完并下载 → 间隔 → 下一件。429（今天操作频繁）时每 20 分钟重试一次，最多等 12 小时。
GAP = 120
for k, p in ITEMS.items():
    if only and k not in only:
        continue
    out = os.path.join(tripo.ROOT, ".local", "tripo_out", "town", k)
    if os.path.exists(os.path.join(out, "model_0_0.glb")):
        continue
    t0 = time.time()
    while k not in ids:
        try:
            r = tripo.call("POST", "/tripo3d/generate", {"prompt": STY + p, "count": 4, "faceCount": 50000}, tries=3)
            ids[k] = r["creationsId"]
            json.dump(ids, open(IDS, "w"), indent=1)
            print("submitted", k, ids[k], flush=True)
        except SystemExit as e:
            print(time.strftime("%H:%M:%S"), k, "submit failed:", str(e)[:90].replace("\n", " "), flush=True)
            if time.time() - t0 > 12 * 3600:
                sys.exit("gave up on " + k)
            time.sleep(1200)
    print("waiting", k, flush=True)
    tripo.wait(ids[k], out)
    time.sleep(GAP)
