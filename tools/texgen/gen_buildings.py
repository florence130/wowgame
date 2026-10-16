# Generate building concept views for Tripo3D (hero 3/4 view + front/right/back/left orthographic views).
# Env: TEX_API_BASE, TEX_API_KEY.  Usage: py tools/texgen/gen_buildings.py [id1,id2,...] [--workers 5]
# Output: docs/buildings_v2/<id>/{hero,front,right,back,left}.png + sheet.jpg ; docs/buildings_v2/_index.jpg
# Resumable: existing images are skipped.
import os, sys, json, base64, urllib.request, time, threading
from concurrent.futures import ThreadPoolExecutor

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "buildings_v2")
CFG = json.load(open(os.path.join(ROOT, "buildings.json"), encoding="utf-8"))
BASE = os.environ.get("TEX_API_BASE", "").rstrip("/")
KEY = os.environ.get("TEX_API_KEY", "")
MODEL = os.environ.get("TEX_MODEL", "gpt-5.5")
VIEWS = ["front", "right", "back", "left"]
lock = threading.Lock()


def log(*a):
    with lock:
        print(time.strftime("%H:%M:%S"), *a, flush=True)


def find_image(obj):
    if isinstance(obj, dict):
        if obj.get("type") == "image_generation_call" and obj.get("result"):
            return obj["result"]
        for v in obj.values():
            r = find_image(v)
            if r:
                return r
    elif isinstance(obj, list):
        for v in obj:
            r = find_image(v)
            if r:
                return r
    return None


def gen(prompt, out_path, ref=None, tries=3):
    if os.path.exists(out_path):
        return True
    content = [{"type": "input_text", "text": "Generate an image: " + prompt}]
    if ref:
        b64 = base64.b64encode(open(ref, "rb").read()).decode()
        content.append({"type": "input_image", "image_url": "data:image/png;base64," + b64})
    body = {"model": MODEL, "store": False, "stream": True, "input": [{"role": "user", "content": content}],
            "tools": [{"type": "image_generation", "size": "1024x1024", "quality": "high"}]}
    for t in range(tries):
        try:
            req = urllib.request.Request(BASE + "/responses", data=json.dumps(body).encode("utf-8"),
                                         headers={"Authorization": "Bearer " + KEY, "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=900) as r:
                txt = r.read().decode("utf-8")
            img = None
            for line in txt.splitlines():
                if line.startswith("data:"):
                    try:
                        img = find_image(json.loads(line[5:].strip())) or img
                    except ValueError:
                        pass
            if img:
                with open(out_path, "wb") as f:
                    f.write(base64.b64decode(img))
                log("OK", os.path.relpath(out_path, ROOT))
                return True
            log("NO_IMAGE", out_path, txt[-300:].replace("\n", " "))
        except Exception as e:
            log("ERR", out_path, e, getattr(e, "read", lambda: b"")()[:200])
        time.sleep(5 + t * 10)
    return False


def sheet(b):
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return
    d = os.path.join(ROOT, b["id"])
    names = ["hero"] + VIEWS
    ims = [Image.open(os.path.join(d, n + ".png")).convert("RGB") if os.path.exists(os.path.join(d, n + ".png")) else Image.new("RGB", (1024, 1024), "white") for n in names]
    W = 512
    out = Image.new("RGB", (W * 4, W * 2 + 60), "white")
    out.paste(ims[0].resize((W * 2, W * 2)), (0, 60))
    for i, im in enumerate(ims[1:]):
        out.paste(im.resize((W, W)), (W * 2 + (i % 2) * W, 60 + (i // 2) * W))
    dr = ImageDraw.Draw(out)
    try:
        font = ImageFont.truetype("msyh.ttc", 30)
        small = ImageFont.truetype("msyh.ttc", 22)
    except Exception:
        font = small = ImageFont.load_default()
    dr.text((14, 12), "%s  %s   [%s]  %gx%gx%g m" % (b["id"], b["cn"], b["kind"], *b["size"]), fill=(40, 40, 60), font=font)
    for i, n in enumerate(VIEWS):
        dr.text((W * 2 + (i % 2) * W + 8, 60 + (i // 2) * W + 6), n, fill=(200, 60, 60), font=small)
    out.save(os.path.join(d, "sheet.jpg"), quality=88)


def do_building(b):
    d = os.path.join(ROOT, b["id"])
    os.makedirs(d, exist_ok=True)
    w, h, dep = b["size"]
    scale = " The building footprint is about %g m wide, %g m deep and %g m tall (a human is 1.7 m)." % (w, dep, h)
    hero = os.path.join(d, "hero.png")
    if not gen(CFG["style"] + ". " + b["desc"] + "." + scale + " " + CFG["iso"], hero):
        return
    with ThreadPoolExecutor(4) as ex:
        list(ex.map(lambda v: gen(CFG["views"][v] + ". " + CFG["style"] + ". Building: " + b["desc"] + ".", os.path.join(d, v + ".png"), ref=hero), VIEWS))
    sheet(b)


def index():
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        return
    bs = CFG["buildings"]
    cols = 6
    T = 300
    rows = (len(bs) + cols - 1) // cols
    out = Image.new("RGB", (cols * T, rows * (T + 34)), "white")
    dr = ImageDraw.Draw(out)
    try:
        font = ImageFont.truetype("msyh.ttc", 18)
    except Exception:
        font = ImageFont.load_default()
    for i, b in enumerate(bs):
        p = os.path.join(ROOT, b["id"], "hero.png")
        x, y = (i % cols) * T, (i // cols) * (T + 34)
        if os.path.exists(p):
            out.paste(Image.open(p).convert("RGB").resize((T, T)), (x, y))
        dr.text((x + 6, y + T + 6), b["cn"], fill=(30, 30, 50), font=font)
    out.save(os.path.join(ROOT, "_index.jpg"), quality=88)


if __name__ == "__main__":
    only = set(sys.argv[1].split(",")) if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else None
    workers = int(sys.argv[sys.argv.index("--workers") + 1]) if "--workers" in sys.argv else 3
    todo = [b for b in CFG["buildings"] if not only or b["id"] in only]
    with ThreadPoolExecutor(workers) as ex:
        list(ex.map(do_building, todo))
    index()
    log("ALL_DONE", len(todo))
