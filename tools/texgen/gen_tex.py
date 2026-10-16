# Generate hand-painted seamless textures through an OpenAI-compatible endpoint (Responses API + image_generation tool).
# Usage:  set TEX_API_BASE / TEX_API_KEY env vars, then  py tools/texgen/gen_tex.py <name> "<prompt>" [model]
# Output: tools/texgen/raw/<name>.png   (the key is never written to the project)
import os, sys, json, base64, urllib.request

base = os.environ.get("TEX_API_BASE", "").rstrip("/")
key = os.environ.get("TEX_API_KEY", "")
name, prompt = sys.argv[1], sys.argv[2]
model = sys.argv[3] if len(sys.argv) > 3 else "gpt-5.5"
out_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "raw")   # 原图；用 prep_tex.py 处理后放到 assets/textures/building/
os.makedirs(out_dir, exist_ok=True)


def post(path, body):
    req = urllib.request.Request(base + path, data=json.dumps(body).encode("utf-8"),
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        return r.read().decode("utf-8")


def save_b64(b64):
    path = os.path.join(out_dir, name + ".png")
    with open(path, "wb") as f:
        f.write(base64.b64decode(b64))
    print("SAVED", path)


def find_image(obj):
    """Walk any JSON structure and return the first image_generation_call result (base64)."""
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


full = ("Generate an image: " + prompt + ". Seamless tileable square texture, filling the whole frame edge to edge, "
        "no perspective, no borders, no text, hand-painted stylized game texture like a bright cartoon MMORPG (Mabinogi Mobile), "
        "soft painterly brush strokes, gentle color variation, even lighting.")
body = {"model": model, "store": False, "stream": True, "input": [{"role": "user", "content": full}],
        "tools": [{"type": "image_generation", "size": "1024x1024", "quality": "high"}]}
try:
    txt = post("/responses", body)
except Exception as e:
    print("RESPONSES_FAILED", e, getattr(e, "read", lambda: b"")()[:600])
    sys.exit(1)
img = None
try:
    img = find_image(json.loads(txt))
except ValueError:
    # server-sent events stream: parse each data: line
    for line in txt.splitlines():
        if line.startswith("data:"):
            try:
                img = find_image(json.loads(line[5:].strip())) or img
            except ValueError:
                pass
if img:
    save_b64(img)
else:
    print("NO_IMAGE", txt[:1500])
