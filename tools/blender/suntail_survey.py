# Survey the SUNTAIL building modules (reference only, never shipped):
# imports each FBX, records bounds / tri count / material slots, renders a labelled contact sheet.
# blender -b -P tools/blender/suntail_survey.py
import bpy, os, json, math
from mathutils import Vector

SRC = r"E:\wowgame\.local\suntail\Assets\Raygeas\Suntail Village\Assets\Models\Building Modules"
OUT = r"E:\wowgame\docs\suntail_reference"
os.makedirs(os.path.join(OUT, "tiles"), exist_ok=True)

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

rows = []
files = []
for root, _, fs in os.walk(SRC):
    for f in sorted(fs):
        if f.lower().endswith(".fbx"):
            files.append(os.path.join(root, f))

for path in files:
    clear()
    bpy.ops.import_scene.fbx(filepath=path)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    if not meshes:
        continue
    lo = Vector((1e9, 1e9, 1e9)); hi = -lo
    tris = 0; mats = set()
    for o in meshes:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
        o.data.calc_loop_triangles(); tris += len(o.data.loop_triangles)
        for m in o.data.materials:
            if m: mats.add(m.name)
    size = hi - lo
    rel = os.path.relpath(path, SRC)
    rows.append({"file": rel.replace("\\", "/"), "group": rel.split(os.sep)[0], "size_m": [round(v, 3) for v in size],
                 "min": [round(v, 3) for v in lo], "max": [round(v, 3) for v in hi], "tris": tris, "materials": sorted(mats), "objects": len(meshes)})
    # render tile
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"; scn.display.shading.color_type = "MATERIAL"
    scn.display.shading.show_cavity = True
    scn.render.resolution_x = scn.render.resolution_y = 360
    scn.render.film_transparent = False
    world = bpy.data.worlds.new("w"); scn.world = world; world.color = (0.86, 0.86, 0.88)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    cam.data.type = "ORTHO"; cam.data.ortho_scale = max(size) * 1.25 + 0.1
    ctr = (lo + hi) / 2
    d = max(size) * 3 + 2
    cam.location = ctr + Vector((d * 0.7, -d * 0.8, d * 0.55))
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = os.path.join(OUT, "tiles", rel.replace(os.sep, "__").replace(".fbx", ".png").replace(".FBX", ".png"))
    bpy.ops.render.render(write_still=True)

json.dump(rows, open(os.path.join(OUT, "modules.json"), "w", encoding="utf-8"), indent=1)
print("SURVEY_DONE", len(rows))
