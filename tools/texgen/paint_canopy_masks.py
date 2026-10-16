"""Derive soft leaf-volume masks from the selected CC0 alpha atlases.

RGB is linear scalar data (R: volume, G: broad painted light); alpha is
copied exactly. No original source texture is modified. Requires Pillow/numpy.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "assets/third_party/quaternius/nature"
OUTPUT = ROOT / "assets/models/nature_storybook/masks"


def build():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name in ("Leaves_NormalTree_C", "Leaf_Pine_C", "Leaves_TwistedTree_C"):
        src = Image.open(SOURCE / (name + ".png")).convert("RGBA")
        alpha = src.getchannel("A")
        # Broad soft interior, restrained brush-like edges, no high frequency noise.
        blur = np.asarray(alpha.filter(ImageFilter.GaussianBlur(src.width * 0.017)), dtype=float) / 255.0
        dy, dx = np.gradient(blur)
        light = np.clip(0.5 - (dx + dy) * src.width * 0.12, 0.0, 1.0)
        volume = np.clip(blur, 0.0, 1.0)
        rgba = np.stack((volume * 255, light * 255, np.full_like(blur, 255), np.asarray(alpha)), axis=-1).astype(np.uint8)
        Image.fromarray(rgba, "RGBA").save(OUTPUT / (name + ".png"), optimize=True)
        print(name, "alpha preserved", src.size)


if __name__ == "__main__":
    build()
