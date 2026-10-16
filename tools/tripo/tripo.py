# Tripo3D 生成 API 客户端（文档：E:\DOWNLOADS\tripo3D生成API文档V2.pdf）。令牌在 .local/tripo.env（TRIPO_API_BASE / TRIPO_TOKEN），不入库、不回显。
#   上传图片到公网（30 分钟后自动删除）：  py tools/tripo/tripo.py upload a.png
#   文生模型：   py tools/tripo/tripo.py text "prompt" [--count 4] [--faces 50000] [--out dir]
#   单图生模型： py tools/tripo/tripo.py image a.png [--faces 50000] [--out dir]      （本地文件会先上传；也可直接给 http 地址）
#   多视角：     py tools/tripo/tripo.py multi front.png:frontView back.png:rearView left.png:leftView [--out dir]
#   只查询：     py tools/tripo/tripo.py query <creationsId> [--out dir]
# 生成会轮询到完成并把所有 GLB 下载到 --out（默认 .local/tripo_out/<creationsId>/），同时存下 query.json。
import os, sys, json, time, argparse, mimetypes, uuid, urllib.request, urllib.error

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))


def env():
    d = {}
    for ln in open(os.path.join(ROOT, ".local", "tripo.env"), encoding="utf-8"):
        if "=" in ln:
            k, v = ln.strip().split("=", 1)
            d[k] = v
    return d["TRIPO_API_BASE"].rstrip("/"), d["TRIPO_TOKEN"]


BASE, TOKEN = env()


def call(method, path, body=None, raw=None, ctype="application/json", timeout=60, tries=3):
    req = urllib.request.Request(BASE + path, data=raw if raw is not None else (json.dumps(body).encode() if body is not None else None), method=method)
    req.add_header("Authorization", TOKEN)
    if raw is not None or body is not None:
        req.add_header("Content-Type", ctype)
    for attempt in range(tries):
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code >= 500 and attempt < tries - 1:        # 网关偶发 502：退避重试
                time.sleep(min(60, 10 * (attempt + 1)))
                continue
            raise SystemExit("HTTP %d %s: %s" % (e.code, path, e.read().decode("utf-8", "replace")[:400]))
        except (urllib.error.URLError, TimeoutError):
            if attempt < tries - 1:
                time.sleep(10)
                continue
            raise SystemExit("network error " + path)


def upload(fp):
    if fp.startswith("http"):
        return fp
    bd = uuid.uuid4().hex
    mt = mimetypes.guess_type(fp)[0] or "application/octet-stream"
    head = ('--%s\r\nContent-Disposition: form-data; name="file"; filename="%s"\r\nContent-Type: %s\r\n\r\n' % (bd, os.path.basename(fp), mt)).encode()
    raw = head + open(fp, "rb").read() + ("\r\n--%s--\r\n" % bd).encode()
    r = call("POST", "/upload", raw=raw, ctype="multipart/form-data; boundary=" + bd)
    if not r.get("success"):
        raise SystemExit("upload failed: %s" % r)
    return r["url"]


def find_urls(o, out):
    """递归找出所有 .glb 链接（成品 / 中间产物字段名随版本变，不写死）。"""
    if isinstance(o, dict):
        for k, v in o.items():
            find_urls(v, out)
    elif isinstance(o, list):
        for v in o:
            find_urls(v, out)
    elif isinstance(o, str) and o.startswith("http") and ".glb" in o.split("?")[0].lower():
        out.append(o)
    return out


def wait(cid, out_dir, poll=10, timeout=1500):
    t0 = time.time()
    last = None
    while True:
        try:
            q = call("GET", "/tripo3d/query/" + cid)
        except SystemExit as e:
            print("query error (retrying):", str(e)[:120], flush=True)
            time.sleep(poll)
            continue
        res = q.get("result") or []
        st = [(x.get("status"), x.get("progress")) for x in res]
        if st != last:
            print("status", q.get("status"), st, flush=True)
            last = st
        if str(q.get("status")).lower() in ("success", "succeeded", "done", "finish", "finished", "completed", "complete", "fail", "failed", "error", "cancelled", "canceled"):
            break
        if time.time() - t0 > timeout:
            print("timeout; re-run `query %s` later" % cid)
            break
        time.sleep(poll)
    os.makedirs(out_dir, exist_ok=True)
    json.dump(q, open(os.path.join(out_dir, "query.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    for i, x in enumerate(res):
        for j, u in enumerate(dict.fromkeys(find_urls(x, []))):
            fn = os.path.join(out_dir, "model_%d_%d.glb" % (i, j))
            try:
                urllib.request.urlretrieve(u, fn)
                print("saved", fn, os.path.getsize(fn))
            except Exception as e:
                print("download failed", u[:80], e)
    return q


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("cmd", choices=["upload", "text", "image", "multi", "query"])
    ap.add_argument("args", nargs="+")
    ap.add_argument("--count", type=int, default=None)
    ap.add_argument("--faces", type=int, default=None, help="1500000 / 1000000 / 500000 / 50000")
    ap.add_argument("--out", default=None)
    ap.add_argument("--no-wait", action="store_true")
    a = ap.parse_args()
    if a.cmd == "upload":
        for f in a.args:
            print(upload(f))
        return
    if a.cmd == "query":
        cid = a.args[0]
    else:
        body = {}
        if a.cmd == "text":
            body["prompt"] = a.args[0]
            body["count"] = a.count or 4
        elif a.cmd == "image":
            body["imageUrl"] = upload(a.args[0])
            if a.count:
                body["count"] = a.count
        else:
            fl, tl = [], []
            for s in a.args:
                p, tag = s.rsplit(":", 1)
                fl.append(upload(p)); tl.append(tag)
            body["imageList"], body["imageTagList"] = fl, tl
        if a.faces:
            body["faceCount"] = a.faces
        r = call("POST", "/tripo3d/generate", body, tries=12)
        print("generate ->", r, flush=True)
        cid = r.get("creationsId")
        if not cid or a.no_wait:
            return
    wait(cid, a.out or os.path.join(ROOT, ".local", "tripo_out", cid))


if __name__ == "__main__":
    main()
