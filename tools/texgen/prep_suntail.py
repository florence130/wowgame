# SUNTAIL greyscale albedo maps -> building.gdshader detail maps (mean 0.5, 1024px, already seamless).
# Source: F:\资源\服装\SUNTAIL - Stylized Fantasy Village Unity2022.unitypackage (user-licensed), extracted to .local/suntail.
# Usage: py tools/texgen/prep_suntail.py
import os
import numpy as np
from PIL import Image

SRC = r"E:\wowgame\.local\suntail\Assets\Raygeas\Suntail Village\Assets\Textures\Building Modules"
DST = r"E:\wowgame\assets\textures\building"
MAP = {  # out name: (source file, contrast)
    "st_plaster": ("Wall_AlbedoSmoothness.png", 0.7),
    "st_masonry": ("Masonry_1_AlbedoSmoothness.png", 1.1),
    "st_cobble": ("Masonry_2_AlbedoSmoothness.png", 1.0),
    "st_stone": ("Stone_AlbedoSmoothness.png", 1.3),
    "st_roof_scale": ("Roof_2_AlbedoSmoothness.png", 1.0),
    "st_roof_barrel": ("Roof_AlbedoSmoothness.png", 1.0),
    "st_boards": ("Boards_AlbedoSmoothness.png", 1.4),
    "st_planks": ("Planks_AlbedoSmoothness.png", 1.0),
    "st_wood": ("Wood_1_AlbedoSmoothness.png", 1.4),
}
for out, (src, k) in MAP.items():
    im = Image.open(os.path.join(SRC, src)).convert("RGB").resize((1024, 1024), Image.LANCZOS)
    l = np.asarray(im).astype(np.float32) @ np.array([0.299, 0.587, 0.114], dtype=np.float32) / 255.0
    l = (l - l.mean()) / max(l.std(), 1e-3) * 0.16 * k + 0.5
    Image.fromarray((np.clip(l, 0, 1) * 255).astype(np.uint8), "L").convert("RGB").save(os.path.join(DST, out + ".png"))
    print("OK", out, round(float(l.mean()), 3))
