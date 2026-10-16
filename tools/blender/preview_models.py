# Render a 3/4 preview of every GLB in a folder (Workbench, flat colors) into <dir>/_preview/<name>.png
# Run: blender -b --factory-startup --python tools/blender/preview_models.py -- <models_dir> [name1,name2]
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = argv[0]
ONLY = set(argv[1].split(",")) if len(argv) > 1 and argv[1] else None
OUT = os.path.join(SRC, "_preview")
os.makedirs(OUT, exist_ok=True)
open(os.path.join(OUT, ".gdignore"), "a").close()

sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_shadows = True
sc.display.shading.show_cavity = True
sc.render.resolution_x = 640
sc.render.resolution_y = 640
sc.render.film_transparent = False
sc.world = bpy.data.worlds.new("w") if sc.world is None else sc.world

for f in sorted(os.listdir(SRC)):
    if not f.endswith(".glb"):
        continue
    name = f[:-4]
    if ONLY and name not in ONLY:
        continue
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, f))
    objs = [o for o in bpy.data.objects if o.type == "MESH"]
    mn = Vector((1e9, 1e9, 1e9)); mx = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    ctr = (mn + mx) * 0.5
    size = max((mx - mn).length, 0.5)
    cam_data = bpy.data.cameras.new("c")
    cam = bpy.data.objects.new("cam", cam_data)
    bpy.context.collection.objects.link(cam)
    # 正面朝 +Y：相机放在前方偏右上方
    cam.location = ctr + Vector((size * 0.75, size * 1.15, size * 0.6))
    d = ctr - cam.location
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = 50
    sc.camera = cam
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("PREVIEW", name)
