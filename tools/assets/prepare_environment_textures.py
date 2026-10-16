from pathlib import Path
from PIL import Image
import hashlib, json, shutil

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / '.local/environment_20261011/source'
TARGET = ROOT / 'assets/textures/environment_packs'
TARGET.mkdir(parents=True, exist_ok=True)
FILES = {
    'sky_clouds': ('sky', 'Packages/com.occasoftware.super-simple-skybox/Textures/Clouds/T_Clouds_Default.png', 1024),
    'sky_cloud_detail': ('sky', 'Packages/com.occasoftware.super-simple-skybox/Textures/Clouds/T_Clouds-1.png', 512),
    'sky_stars': ('sky', 'Packages/com.occasoftware.super-simple-skybox/Textures/Stars/T_Stars_01.png', 2048),
    'plant_atlas': ('plants', 'Assets/CartoonGrass/Textures/CartoonGrass_Texture_01.png', 1024),
    'water_normal': ('water', 'Assets/Stylized Water For URP/Textures/Normals/Normals 1.png', 512),
    'water_foam': ('water', 'Assets/Stylized Water For URP/Textures/Foam/Foam 1.png', 512),
    'water_caustics': ('water', 'Assets/Stylized Water For URP/Textures/Caustics/Caustics 1.png', 512),
    'fog_noise': ('ethereal', 'Assets/ARTnGAME/VolumeFogSRP/Materials/FogNoise 3 SMALLER.png', 512),
}
records = {}
for key, (pack, relative, size) in FILES.items():
    source = STAGE / pack / relative
    img = Image.open(source)
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    target = TARGET / (key + '.png')
    img.save(target)
    records[key] = {'pack': pack, 'source_asset': relative, 'source_sha256': hashlib.sha256(source.read_bytes()).hexdigest(), 'runtime': str(target.relative_to(ROOT)), 'runtime_sha256': hashlib.sha256(target.read_bytes()).hexdigest(), 'size': img.size}
manifest = ROOT / 'assets/source_packs/environment_20261011.json'
manifest.write_text(json.dumps({'textures': records, 'source_inventory': '.local/environment_20261011/inventory.json', 'plant_conversion': 'assets/models/cartoon_plants/conversion.json'}, ensure_ascii=False, indent=2), encoding='utf-8')
# Keep the pre-change source available for exact same-camera comparisons.
backup = ROOT / '.local/environment_20261011/before'
for relative in ['src/world/world.gd', 'src/render/sky.gdshader', 'src/terrain/grass.gdshader', 'src/terrain/grass_field.gd', 'src/terrain/water.gdshader', 'project.godot']:
    destination = backup / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not destination.exists():
        shutil.copy2(ROOT / relative, destination)
print('Environment textures and original source backup prepared')
