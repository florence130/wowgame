# Concept images for the v3 building rework (style locked to docs/art_direction_v3/refs).
# Env: TEX_API_BASE, TEX_API_KEY (optional TEX_MODEL).
# Usage:
#   py tools/texgen/gen_concepts_v3.py [id1,id2,...] [--workers 3]   hero + 4 orthographic views + interior
#   py tools/texgen/gen_concepts_v3.py --relief                       one sheet of all complex relief parts (relief_parts.json)
# Output: docs/buildings_v3/<id>/{hero,front,right,back,left,interior}.png + sheet.jpg ; docs/buildings_v3/_index.jpg
# Resumable: existing images are skipped. Delete an image to regenerate it.
import os, sys, json, base64, urllib.request, time, threading
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "buildings_v3"))
REFS = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "art_direction_v3", "refs"))
CFG = json.load(open(os.path.join(ROOT, "buildings.json"), encoding="utf-8"))
# Fallback: .local/texgen.env with lines KEY=VALUE (kept out of docs/tools)
_envf = os.path.normpath(os.path.join(HERE, "..", "..", ".local", "texgen.env"))
if os.path.exists(_envf):
    for _l in open(_envf, encoding="utf-8"):
        if "=" in _l and not _l.startswith("#"):
            _k, _v = _l.strip().split("=", 1)
            os.environ.setdefault(_k, _v)
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


def _img_part(path):
    mime = "image/png" if path.lower().endswith(".png") else "image/jpeg"
    b64 = base64.b64encode(open(path, "rb").read()).decode()
    return {"type": "input_image", "image_url": "data:%s;base64,%s" % (mime, b64)}


IMAGE_MODEL = os.environ.get("TEX_IMAGE_MODEL", "")


def _post_images(prompt, refs, size):
    """OpenAI Images API: /images/generations, or /images/edits (multipart) when reference images are given."""
    import uuid
    refs = [r for r in refs if os.path.exists(r)]
    hdr = {"Authorization": "Bearer " + KEY, "User-Agent": "Mozilla/5.0"}
    if not refs:
        data = json.dumps({"model": IMAGE_MODEL, "prompt": prompt, "size": size, "n": 1}).encode("utf-8")
        hdr["Content-Type"] = "application/json"
        url = BASE + "/images/generations"
    else:
        bd = uuid.uuid4().hex
        parts = []
        for k, v in (("model", IMAGE_MODEL), ("prompt", prompt), ("size", size)):
            parts.append(('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n' % (bd, k, v)).encode("utf-8"))
        for r in refs:
            mime = "image/png" if r.lower().endswith(".png") else "image/jpeg"
            parts.append(('--%s\r\nContent-Disposition: form-data; name="image[]"; filename="%s"\r\nContent-Type: %s\r\n\r\n'
                          % (bd, os.path.basename(r), mime)).encode("utf-8") + open(r, "rb").read() + b"\r\n")
        parts.append(("--%s--\r\n" % bd).encode())
        data = b"".join(parts)
        hdr["Content-Type"] = "multipart/form-data; boundary=" + bd
        url = BASE + "/images/edits"
    with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=hdr), timeout=900) as r:
        d = json.loads(r.read().decode("utf-8"))
    it = d["data"][0]
    if it.get("b64_json"):
        return base64.b64decode(it["b64_json"])
    if it.get("url"):
        return urllib.request.urlopen(it["url"], timeout=300).read()
    return None


def gen(prompt, out_path, refs=(), size="1536x1024", tries=3):
    if os.path.exists(out_path):
        return True
    if IMAGE_MODEL:
        for t in range(tries):
            try:
                img = _post_images(prompt, refs, size)
                if img:
                    with open(out_path, "wb") as f:
                        f.write(img)
                    log("OK", os.path.relpath(out_path, ROOT))
                    return True
                log("NO_IMAGE", out_path)
            except Exception as e:
                log("ERR", out_path, e, getattr(e, "read", lambda: b"")()[:200])
            time.sleep(5 + t * 10)
        return False
    content = [{"type": "input_text", "text": "Generate an image: " + prompt}]
    content += [_img_part(r) for r in refs if os.path.exists(r)]
    body = {"model": MODEL, "store": False, "stream": True, "input": [{"role": "user", "content": content}],
            "tools": [{"type": "image_generation", "size": size, "quality": "high"}]}
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


def style_refs(b):
    return [os.path.join(REFS, r) for r in b.get("refs", [])]


def do_building(b):
    d = os.path.join(ROOT, b["id"])
    os.makedirs(d, exist_ok=True)
    w, h, dep = b["size"]
    scale = (" Overall size about %g m wide, %g m deep, %g m to the roof ridge or spire tip; a human is 1.75 m tall,"
             " doors are 2.8-3.2 m tall (public portals larger), storeys are 4.2 m (ground) and 3.6 m (upper)." % (w, dep, h))
    pal = " Colour palette: " + CFG["palette"][b["palette"]] + "."
    style = CFG["style"] + " (the attached screenshots are STYLE references only - do not copy their buildings)."
    hero = os.path.join(d, "hero.png")
    refs = style_refs(b)
    if b.get("base"):
        # Refine an existing design (e.g. GPT's kit render) instead of inventing a new one.
        refs = [os.path.join(d, b["base"])] + refs[:2]
        style = (CFG["style"] + ". REDESIGN BASE: the FIRST attached image is the approved design - keep its layout, massing, building parts, "
                 "proportions and camera angle, and upgrade only materials, detail and the additions listed below. The other attached screenshots are STYLE references only.")
    if not gen(style + " Building: " + b["desc"] + "." + scale + pal + " " + CFG["iso"], hero, refs):
        return
    # Separate per-view requests just copy the hero's 3/4 camera; one 2x2 elevation sheet comes out flat.
    jobs = [(CFG["elevations"] + " Building: " + b["desc"] + ".", os.path.join(d, "elevations.png"), [hero], "1536x1024")]
    if b.get("interior_desc"):
        jobs.append((CFG["interior"] + ". " + CFG["style"] + ". " + b["interior_desc"] + "." + pal,
                     os.path.join(d, "interior.png"), [hero] + style_refs(b)[:1], "1536x1024"))
    with ThreadPoolExecutor(len(jobs)) as ex:
        list(ex.map(lambda j: gen(j[0], j[1], j[2], j[3]), jobs))
    sheet(b)


def _font(n):
    from PIL import ImageFont
    try:
        return ImageFont.truetype("msyh.ttc", n)
    except Exception:
        return ImageFont.load_default()


def sheet(b):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return
    d = os.path.join(ROOT, b["id"])
    names = ["hero", "interior", "elevations"]

    def load(n):
        p = os.path.join(d, n + ".png")
        return Image.open(p).convert("RGB") if os.path.exists(p) else Image.new("RGB", (1536, 1024), (235, 235, 235))
    ims = {n: load(n) for n in names}
    W, H = 768, 512
    out = Image.new("RGB", (W * 3, H * 2 + 60), "white")
    out.paste(ims["hero"].resize((W * 2, H * 2)), (0, 60))
    out.paste(ims["interior"].resize((W, H)), (W * 2, 60))
    out.paste(ims["elevations"].resize((W, H)), (W * 2, 60 + H))
    dr = ImageDraw.Draw(out)
    dr.text((14, 12), "%s  %s   %gx%gx%g m (W x H x D)" % (b["id"], b["cn"], b["size"][0], b["size"][1], b["size"][2]), fill=(40, 40, 60), font=_font(30))
    out.save(os.path.join(d, "sheet.jpg"), quality=88)


def index():
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return
    bs = CFG["buildings"]
    cols, T, TH = 4, 420, 280
    rows = (len(bs) + cols - 1) // cols
    out = Image.new("RGB", (cols * T, rows * (TH + 34)), "white")
    dr = ImageDraw.Draw(out)
    for i, b in enumerate(bs):
        p = os.path.join(ROOT, b["id"], "hero.png")
        x, y = (i % cols) * T, (i // cols) * (TH + 34)
        if os.path.exists(p):
            out.paste(Image.open(p).convert("RGB").resize((T, TH)), (x, y))
        ok = os.path.exists(os.path.join(ROOT, b["id"], "APPROVED"))
        dr.text((x + 6, y + TH + 6), ("✔ " if ok else "") + b["cn"], fill=(30, 120, 30) if ok else (30, 30, 50), font=_font(18))
    out.save(os.path.join(ROOT, "_index.jpg"), quality=88)


def relief():
    """All complex sculpted parts of approved buildings on ONE sheet, for a single Tripo3D batch."""
    parts = json.load(open(os.path.join(ROOT, "relief_parts.json"), encoding="utf-8"))["parts"]
    n = len(parts)
    lines = ["%d. %s (about %s m)" % (i + 1, p["desc"], p["size"]) for i, p in enumerate(parts)]
    prompt = (CFG["style"] + ". A clean asset reference sheet on a plain light grey background showing %d separate sculpted architectural ornament "
              "pieces arranged in a neat grid, each piece isolated with generous empty space around it, three-quarter front view, consistent lighting, "
              "a small black number under each piece, no other text. Pieces: " % n) + "; ".join(lines)
    refs = [os.path.join(ROOT, p["from"], "hero.png") for p in parts if p.get("from")]
    refs = list(dict.fromkeys(refs))[:3]
    gen(prompt, os.path.join(ROOT, "relief_sheet.png"), refs, size="1536x1024")


if __name__ == "__main__":
    if not BASE or not KEY:
        sys.exit("Set TEX_API_BASE and TEX_API_KEY first.")
    if "--relief" in sys.argv:
        relief()
        sys.exit(0)
    only = set(sys.argv[1].split(",")) if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else None
    workers = int(sys.argv[sys.argv.index("--workers") + 1]) if "--workers" in sys.argv else 3
    todo = [b for b in CFG["buildings"] if not only or b["id"] in only]
    with ThreadPoolExecutor(workers) as ex:
        list(ex.map(do_building, todo))
    index()
    log("ALL_DONE", len(todo))
