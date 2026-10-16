# 道具总图（4×4）→ 逐件裁图 → Tripo 图生3D（最多 3 件并行）。
#   py tools/tripo/sheet_batch.py interior|details [name1,name2]     输出 .local/tripo_out/props/<name>/model_0_0.glb（已有的跳过）
import os, sys, json, time, threading
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tripo

SHEETS = {
    "interior": ("08_interior.png", ["table", "bench_long", "chair", "stool", "bed", "bookshelf", "cupboard", "counter", "fireplace", "chandelier", "anvil", "forge", "weaponrack", "barrel", "chest", "mannequin"]),
    "details": ("09_details.png", ["sign_tavern", "sign_smith", "sign_store", "sign_tailor", "sign_guard", "sign_trainer", "sign_stable", "dormer", "chimney", "window", "door", "wall_lantern", "planter", "porch", "fence", "steps"]),
}
CROP = os.path.join(tripo.ROOT, "docs", "goldenear_concept", "props")
IDS = os.path.join(tripo.ROOT, ".local", "tripo_out", "props_ids.json")
lock = threading.Lock()


def crops(fn, names):
    im = Image.open(os.path.join(tripo.ROOT, "docs", "goldenear_concept", fn)).convert("RGB")
    cw, ch = im.width / 4, im.height / 4
    for i, n in enumerate(names):
        fp = os.path.join(CROP, n + ".png")
        if os.path.exists(fp):
            continue
        c, r = i % 4, i // 4
        cell = im.crop((int(c * cw) + 4, int(r * ch) + 4, int((c + 1) * cw) - 4, int((r + 1) * ch) - 30))
        s = max(cell.size) + 40
        bg = Image.new("RGB", (s, s), cell.getpixel((6, 6)))
        bg.paste(cell, ((s - cell.width) // 2, (s - cell.height) // 2))
        bg.resize((768, 768), Image.LANCZOS).save(fp)


def work(n, ids):
    out = os.path.join(tripo.ROOT, ".local", "tripo_out", "props", n)
    if os.path.exists(os.path.join(out, "model_0_0.glb")):
        return
    t0 = time.time()
    while n not in ids:
        try:
            url = tripo.upload(os.path.join(CROP, n + ".png"))
            r = tripo.call("POST", "/tripo3d/generate", {"imageUrl": url, "faceCount": 50000}, tries=3)
            with lock:
                ids[n] = r["creationsId"]
                json.dump(ids, open(IDS, "w"), indent=1)
            print("submitted", n, flush=True)
        except SystemExit as e:
            print(time.strftime("%H:%M:%S"), n, "submit failed:", str(e)[:80].replace("\n", " "), flush=True)
            if time.time() - t0 > 6 * 3600:
                return
            time.sleep(600)
    tripo.wait(ids[n], out)


if __name__ == "__main__":
    fn, names = SHEETS[sys.argv[1]]
    if len(sys.argv) > 2:
        names = [x for x in names if x in sys.argv[2].split(",")]
    crops(fn, SHEETS[sys.argv[1]][1])
    ids = json.load(open(IDS)) if os.path.exists(IDS) else {}
    q = list(names)
    def runner():
        while True:
            with lock:
                if not q:
                    return
                n = q.pop(0)
            work(n, ids)
            time.sleep(20)
    th = [threading.Thread(target=runner) for _ in range(3)]
    for t in th:
        t.start(); time.sleep(3)
    for t in th:
        t.join()
    print("ALL DONE")
