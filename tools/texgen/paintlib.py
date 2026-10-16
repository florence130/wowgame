# Hand-painted tileable "multiplier" textures (RGB, per-channel mean 0.5 -> shader multiplies by 2, so the material's base colour is kept
# while the painted tile-to-tile hue / value variation, soft edge shading and brush streaks come from the texture).
# Pure numpy + PIL (no scipy). Every pattern wraps seamlessly: noise is FFT-filtered, cell structures are modular.
import numpy as np
from PIL import Image, ImageDraw

F32 = np.float32


# ------------------------------------------------------------------ noise / filters (periodic)
def _freq(S):
    fx = np.fft.fftfreq(S).astype(F32)[None, :]
    fy = np.fft.fftfreq(S).astype(F32)[:, None]
    return fx, fy


def blur(a, sx, sy=None, theta=0.0):
    """Periodic anisotropic gaussian blur (sigma in pixels; theta rotates the sx axis, radians)."""
    S = a.shape[0]
    sy = sx if sy is None else sy
    fx, fy = _freq(S)
    c, s = np.cos(theta), np.sin(theta)
    u = fx * c + fy * s
    v = -fx * s + fy * c
    G = np.exp(-2.0 * np.pi ** 2 * ((sx * u) ** 2 + (sy * v) ** 2)).astype(F32)
    if a.ndim == 2:
        return np.real(np.fft.ifft2(np.fft.fft2(a) * G)).astype(F32)
    return np.stack([blur(a[..., k], sx, sy, theta) for k in range(a.shape[2])], -1)


def gnoise(S, sx, sy=None, theta=0.0, seed=0):
    """Zero-mean, unit-variance periodic noise: white noise blurred by an (anisotropic) gaussian."""
    r = np.random.default_rng(seed)
    w = r.standard_normal((S, S)).astype(F32)
    a = blur(w, sx, sy, theta)
    return (a - a.mean()) / (a.std() + 1e-8)


def fnoise(S, beta=1.0, seed=0):
    """1/f^beta periodic noise (painterly multi-scale)."""
    r = np.random.default_rng(seed)
    w = r.standard_normal((S, S)).astype(F32)
    fx, fy = _freq(S)
    f = np.sqrt(fx ** 2 + fy ** 2)
    f[0, 0] = 1.0
    F = np.fft.fft2(w) / (f ** beta)
    F[0, 0] = 0
    a = np.real(np.fft.ifft2(F)).astype(F32)
    return (a - a.mean()) / (a.std() + 1e-8)


def coords(S):
    y, x = np.mgrid[0:S, 0:S].astype(F32)
    return x / S, y / S


def hsh(*ints, seed=0):
    """Vectorised integer hash -> float in [0,1)."""
    h = np.uint64(seed * 2654435761 + 1013904223)
    h = np.full(np.broadcast(*ints).shape, h, dtype=np.uint64)
    for k, a in enumerate(ints):
        h = (h ^ (np.asarray(a).astype(np.int64).astype(np.uint64) + np.uint64(0x9E3779B97F4A7C15) + (h << np.uint64(6)) + (h >> np.uint64(2)))) * np.uint64(0xBF58476D1CE4E5B9)
        h ^= h >> np.uint64(29)
    h = h * np.uint64(0x94D049BB133111EB)
    h ^= h >> np.uint64(32)
    return ((h >> np.uint64(11)).astype(np.float64) / float(1 << 53)).astype(F32)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0 + 1e-8), 0, 1)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ output
def finish(rgb, path, size=None, strength=1.0):
    """rgb: HxWx3 multiplier (~1 average). Normalise each channel mean to 0.5 and write an 8-bit PNG."""
    a = np.asarray(rgb, F32)
    a = 1.0 + (a - 1.0) * strength
    a = a / a.reshape(-1, 3).mean(0)
    a = np.clip(a * 0.5, 0, 1)
    im = Image.fromarray((a * 255 + 0.5).astype(np.uint8), "RGB")
    if size and size != a.shape[0]:
        im = im.resize((size, size), Image.LANCZOS)
    im.save(path, optimize=True)
    return im


def tile_color(r, g, b):
    return np.stack([r, g, b], -1).astype(F32)


# ------------------------------------------------------------------ coursed masonry (bricks / ashlar)
def wobble(S, amp, sigma, seed):
    """Low-frequency coordinate wobble in tile units (hand-drawn lines are never straight)."""
    return gnoise(S, sigma, seed=seed) * amp, gnoise(S, sigma, seed=seed + 1) * amp


def courses(S, rows, per_row, seed, shift=0.5, wob=0.0035, wob_sigma=40, width_jitter=0.0, row_jitter=0.0):
    """Courses of blocks. Returns dict with block id arrays and local coords:
       u, v in [0,1] inside the block, w, h block size (tile units), rid/cid integer row/col, idr/idc hashes inputs."""
    x, y = coords(S)
    wx, wy = wobble(S, wob, wob_sigma, seed * 7 + 3)
    X, Y = x + wx, y + wy
    # row boundaries: equal rows with optional jitter (partition of [0,1))
    if row_jitter > 0:
        r = np.random.default_rng(seed)
        hs = 1 + (r.random(rows) - 0.5) * 2 * row_jitter
        edges = np.concatenate([[0], np.cumsum(hs / hs.sum())])
    else:
        edges = np.linspace(0, 1, rows + 1)
    Ym = np.mod(Y, 1.0)
    rid = np.clip(np.searchsorted(edges, Ym, side="right") - 1, 0, rows - 1)
    h = (edges[rid + 1] - edges[rid]).astype(F32)
    v = ((Ym - edges[rid]) / h).astype(F32)
    u = np.zeros_like(v)
    cid = np.zeros(v.shape, np.int64)
    wblk = np.zeros_like(v)
    rr = np.random.default_rng(seed + 17)
    for k in range(rows):
        m = rid == k
        n = per_row[k] if isinstance(per_row, (list, tuple)) else per_row
        if width_jitter > 0:
            ws = 1 + (rr.random(n) - 0.5) * 2 * width_jitter
            b = np.concatenate([[0], np.cumsum(ws / ws.sum())])
        else:
            b = np.linspace(0, 1, n + 1)
        off = ((k % 2) * shift + rr.random() * 0.0) / n if shift else 0.0
        Xr = np.mod(X[m] - off, 1.0)
        ci = np.clip(np.searchsorted(b, Xr, side="right") - 1, 0, n - 1)
        wid = b[ci + 1] - b[ci]
        u[m] = (Xr - b[ci]) / wid
        wblk[m] = wid
        cid[m] = ci
    return dict(u=u, v=v, w=wblk, h=h, rid=rid, cid=cid, x=X, y=Y)


def edge_masks(u, v, w, h, S, gap_px):
    """Distance (pixels) to the block border, from block-local u/v and block size (tile units)."""
    du = np.minimum(u, 1 - u) * w * S
    dv = np.minimum(v, 1 - v) * h * S
    return du, dv, np.minimum(du, dv)


# ------------------------------------------------------------------ voronoi stones
def voronoi(S, n, seed, jitter=0.85):
    """Periodic worley. Returns id, d1, d2 (in tile units), local offset (dx,dy from the nearest site)."""
    r = np.random.default_rng(seed)
    px = (np.arange(n)[None, :] + 0.5 + (r.random((n, n)) - 0.5) * jitter)  # site x in cell units
    py = (np.arange(n)[:, None] + 0.5 + (r.random((n, n)) - 0.5) * jitter)
    x, y = coords(S)
    X, Y = x * n, y * n
    ci, cj = np.floor(X).astype(int), np.floor(Y).astype(int)
    best1 = np.full((S, S), 1e9, F32)
    best2 = np.full((S, S), 1e9, F32)
    bid = np.zeros((S, S), np.int64)
    bdx = np.zeros((S, S), F32)
    bdy = np.zeros((S, S), F32)
    for dj in (-1, 0, 1):
        for di in (-1, 0, 1):
            ii, jj = (ci + di), (cj + dj)
            sx = px[jj % n, ii % n] + (ii - ii % n)
            sy = py[jj % n, ii % n] + (jj - jj % n)
            dx, dy = X - sx, Y - sy
            d = np.sqrt(dx * dx + dy * dy)
            m1 = d < best1
            m2 = (~m1) & (d < best2)
            best2 = np.where(m1, best1, np.where(m2, d, best2))
            bid = np.where(m1, (jj % n) * n + (ii % n), bid)
            bdx = np.where(m1, dx, bdx)
            bdy = np.where(m1, dy, bdy)
            best1 = np.where(m1, d, best1)
    return bid, best1 / n, best2 / n, bdx, bdy


def leaf_dabs(S, count, seed, size=(0.05, 0.11)):
    """Painted leaf dabs: returns (coverage-id image as float value 0..1 per leaf, mask)."""
    r = np.random.default_rng(seed)
    img = Image.new("F", (S, S), 0.0)
    d = ImageDraw.Draw(img)
    for _ in range(count):
        cx, cy = r.random() * S, r.random() * S
        L = (size[0] + r.random() * (size[1] - size[0])) * S
        Wd = L * (0.45 + r.random() * 0.2)
        a = r.random() * np.pi
        val = r.random()
        pts = []
        for t in np.linspace(0, 2 * np.pi, 14, endpoint=False):
            px = np.cos(t) * L * 0.5 * (1 - 0.15 * np.cos(t)) ; py = np.sin(t) * Wd * 0.5 * (1 - 0.6 * np.abs(np.cos(t)) ** 3)
            pts.append((cx + px * np.cos(a) - py * np.sin(a), cy + px * np.sin(a) + py * np.cos(a)))
        for ox in (-S, 0, S):
            for oy in (-S, 0, S):
                d.polygon([(p[0] + ox, p[1] + oy) for p in pts], fill=0.15 + 0.85 * val)
    return np.asarray(img, F32)
