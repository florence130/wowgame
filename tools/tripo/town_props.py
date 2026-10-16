# 金穗镇广场道具：把 docs/goldenear_concept/05_props.png（4×4 道具总图）裁成单件白底方图，逐件 图生3D（Tripo），一件做完再提交下一件。
#   py tools/tripo/town_props.py [name1,name2]      输出 .local/tripo_out/props/<name>/model_*.glb；已有的跳过；失败（429 等）每 20 分钟重试
import os, sys, json, time
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo

NAMES = ["fountain", "waystone", "lamp", "well", "stall_fruit", "stall_herb", "stall_weapon", "noticeboard", "signpost", "haycart", "haystack", "bench",
         "woodshed", "trough", "brazier", "scarecrow"]
SRC = os.path.join(tripo.ROOT, "docs", "goldenear_concept", "05_props.png")
CROP = os.path.join(tripo.ROOT, "docs", "goldenear_concept", "props")
os.makedirs(CROP, exist_ok=True)


def crops():
    im = Image.open(SRC).convert("RGB")
    cw, ch = im.width / 4, im.height / 4
    for i, n in enumerate(NAMES):
        fp = os.path.join(CROP, n + ".png")
        if os.path.exists(fp):
            continue
        c, r = i % 4, i // 4
        cell = im.crop((int(c * cw) + 4, int(r * ch) + 4, int((c + 1) * cw) - 4, int((r + 1) * ch) - 30))     # 去掉底部编号
        s = max(cell.size) + 40
        bg = Image.new("RGB", (s, s), cell.getpixel((6, 6)))
        bg.paste(cell, ((s - cell.width) // 2, (s - cell.height) // 2))
        bg = bg.resize((768, 768), Image.LANCZOS)
        bg.save(fp)


if __name__ == "__main__":
    crops()
    only = set(sys.argv[1].split(",")) if len(sys.argv) > 1 else None
    IDS = os.path.join(tripo.ROOT, ".local", "tripo_out", "props_ids.json")
    ids = json.load(open(IDS)) if os.path.exists(IDS) else {}
    for n in NAMES:
        if only and n not in only:
            continue
        out = os.path.join(tripo.ROOT, ".local", "tripo_out", "props", n)
        if os.path.exists(os.path.join(out, "model_0_0.glb")):
            continue
        t0 = time.time()
        while n not in ids:
            try:
                url = tripo.upload(os.path.join(CROP, n + ".png"))
                r = tripo.call("POST", "/tripo3d/generate", {"imageUrl": url, "faceCount": 50000}, tries=3)
                ids[n] = r["creationsId"]
                json.dump(ids, open(IDS, "w"), indent=1)
                print("submitted", n, ids[n], flush=True)
            except SystemExit as e:
                print(time.strftime("%H:%M:%S"), n, "submit failed:", str(e)[:90].replace("\n", " "), flush=True)
                if time.time() - t0 > 12 * 3600:
                    sys.exit("gave up on " + n)
                time.sleep(1200)
        print("waiting", n, flush=True)
        tripo.wait(ids[n], out)
        time.sleep(60)
