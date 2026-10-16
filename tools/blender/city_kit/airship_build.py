# 单独导出一艘飞艇（60m）：assets/models/city_lm/airship.glb，供游戏里的 Airship 节点（停泊 / 巡航）使用。
# 沿 +X，船头在 -X，原点在气囊中心，吊舱在下。
# "E:\FF导出\BlenderPortable\blender-4.5.10-windows-x64\blender.exe" -b -P tools/blender/city_kit/airship_build.py
import os, sys, importlib.util as _iu
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "modkit")); sys.path.insert(0, HERE)
import kit, monument as mo
from monument import join
_spec = _iu.spec_from_file_location("city_kit_build", os.path.join(HERE, "build.py"))
ckb = _iu.module_from_spec(_spec); _spec.loader.exec_module(ckb)
ROOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(ROOT, "assets", "models", "city_lm")
DOC = os.path.join(ROOT, "docs", "city_lm")
os.makedirs(OUT, exist_ok=True); os.makedirs(DOC, exist_ok=True)
ckb.clear()
ob = join([mo.airship(60, 1.4, {})], "airship")
objs = ckb.split_nocol(ob)
ckb.export(objs, os.path.join(OUT, "airship.glb"))
ckb.render(os.path.join(DOC, "airship.png"), objs, (900, 600))
print("AIRSHIP", ckb.tris_of(objs), "tris", [round(v, 1) for v in ckb.bounds(objs)[1] - ckb.bounds(objs)[0]])
