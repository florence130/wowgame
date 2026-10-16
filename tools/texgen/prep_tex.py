# Turn a generated texture into a seamless grayscale detail map (mean luminance 0.5) for building.gdshader.
# Usage: python prep_tex.py <in.png> <out.png> [size=512] [contrast=1.0]
import sys
from PIL import Image, ImageOps
import numpy as np

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 512
contrast = float(sys.argv[4]) if len(sys.argv) > 4 else 1.0
periodic = len(sys.argv) > 5 and sys.argv[5] == "periodic"
im = Image.open(src).convert("RGB")
w, h = im.size
s = min(w, h)
im = im.crop(((w - s) // 2, (h - s) // 2, (w - s) // 2 + s, (h - s) // 2 + s))


def period(l, axis):
    """Dominant repeat length along an axis (autocorrelation of the mean profile spectrum)."""
    x = l - l.mean()
    f = np.fft.rfft(x, axis=axis)
    p = (np.abs(f) ** 2).mean(axis=1 - axis)
    ac = np.fft.irfft(p)
    n = len(ac)
    lo, hi = max(20, n // 40), n // 3
    k = lo + int(np.argmax(ac[lo:hi]))
    return k


if periodic:
    l0 = np.asarray(im.convert("L")).astype(np.float32)
    px, py = period(l0, 1), period(l0, 0)
    # 选 2 行（交错瓦片周期）的整倍数
    py2 = py * 2 if py * 2 < s // 2 else py
    cw = (s // px) * px
    ch = (s // py2) * py2
    c = min(cw, ch)
    cw, ch = (c // px) * px, (c // py2) * py2
    im = im.crop((0, 0, cw, ch))
    print("PERIOD", px, py, "crop", cw, ch)
im = im.resize((size, size), Image.LANCZOS)
a = np.asarray(im).astype(np.float32) / 255.0
lum = a @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
# seamless: blend with the half-offset copy, feathered only near the borders (keeps the centre crisp)
sh = np.roll(np.roll(lum, size // 2, 0), size // 2, 1)
t = np.linspace(0, 1, size, dtype=np.float32)
edge = np.minimum(t, 1 - t) * 2.0           # 0 at border, 1 at centre
wv = np.clip(edge / (0.08 if periodic else 0.3), 0, 1)
wv = wv * wv * (3 - 2 * wv)
wmask = np.outer(wv, wv)
out = lum * wmask + sh * (1 - wmask)
# remove low-frequency lighting gradients, normalise mean 0.5
blur = np.asarray(Image.fromarray((out * 255).astype(np.uint8)).resize((8, 8), Image.BILINEAR).resize((size, size), Image.BICUBIC)).astype(np.float32) / 255.0
out = out - blur + blur.mean()
out = (out - out.mean()) * contrast + 0.5
out = np.clip(out, 0, 1)
Image.fromarray((out * 255).astype(np.uint8), "L").convert("RGB").save(dst)
print("PREP", dst, round(float(out.mean()), 3), round(float(out.std()), 3))
