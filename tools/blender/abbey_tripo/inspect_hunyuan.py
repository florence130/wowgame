"""Offline Hunyuan GLB inspection, staging normalization and neutral renders.

Blender:
  blender --background --factory-startup --python-exit-code 1 --python
  inspect_hunyuan.py -- --source raw/TR01.glb --asset TR01 --out review/TR01_r001
  [--rotate-deg X Y Z] [--budget 3000] [--resolution 640] [--no-render]

Host Python (Pillow):
  py -3 inspect_hunyuan.py --contact-sheet --reports review/TR*/inspection.json
  --out review/contact_sheet.png
Pass explicit report paths: shell wildcard expansion is not required/supported.

Existing output paths are always refused. Raw inputs are read only. No network,
decimation, automatic repair, production manifest updates or visual approval.
"""
import argparse
import contextlib
import hashlib
import io
import json
import math
import runpy
import struct
import sys
from array import array
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
ASSETS = [f"TR{i:02d}" for i in range(1, 7)]


def sha256(path):
    with Path(path).open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256")
    return digest.hexdigest()


def write_json(path, value):
    with Path(path).open("x", encoding="utf-8") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2, allow_nan=False)
        handle.write("\n")


def read_glb(path):
    """Parse JSON directly before any neutral material override can hide inputs."""
    blob = Path(path).read_bytes()
    if len(blob) < 20:
        raise ValueError("Incomplete GLB header")
    magic, version, size = struct.unpack_from("<4sII", blob)
    if magic != b"glTF" or version != 2 or size != len(blob):
        raise ValueError("Expected complete glTF 2 binary")
    cursor = 12
    while cursor + 8 <= len(blob):
        length, kind = struct.unpack_from("<II", blob, cursor)
        cursor += 8
        if cursor + length > len(blob):
            raise ValueError("GLB chunk extends beyond file")
        if kind == 0x4E4F534A:
            return json.loads(blob[cursor:cursor + length])
        cursor += length
    raise ValueError("GLB has no JSON chunk")


def texture_audit(document):
    refs = []

    def visit(value, trail):
        if isinstance(value, dict):
            for key, nested in value.items():
                path = trail + "." + key
                if key.lower().endswith("texture") and isinstance(nested, dict) and "index" in nested:
                    refs.append({"path": path, "texture_index": nested["index"]})
                visit(nested, path)
        elif isinstance(value, list):
            for index, nested in enumerate(value):
                visit(nested, trail + f"[{index}]")

    visit(document.get("materials", []), "materials")
    result = {"images": len(document.get("images", [])),
              "textures": len(document.get("textures", [])),
              "materials": len(document.get("materials", [])),
              "material_texture_references": refs,
              "material_texture_reference_count": len(refs)}
    result["no_textures_passed"] = result["images"] == 0 and result["textures"] == 0 and not refs
    result["vertex_color_attribute_count"] = sum(
        sum(key.startswith("COLOR_") for key in primitive.get("attributes", {}))
        for mesh in document.get("meshes", []) for primitive in mesh.get("primitives", []))
    return result


def collect_geometry(objects):
    import bpy
    vertices, faces, per_object = [], [], []
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for ob in objects:
        if ob.type != "MESH":
            continue
        evaluated = ob.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        try:
            offset = len(vertices)
            vertices.extend(tuple(evaluated.matrix_world @ vertex.co) for vertex in mesh.vertices)
            faces.extend(tuple(offset + vertex for vertex in poly.vertices) for poly in mesh.polygons)
            mesh.calc_loop_triangles()
            per_object.append({"object": ob.name, "vertices": len(mesh.vertices),
                               "polygons": len(mesh.polygons), "triangles": len(mesh.loop_triangles)})
        finally:
            evaluated.to_mesh_clear()
    if not faces:
        raise ValueError("No mesh faces in candidate")
    return vertices, faces, per_object


def topology(vertices, faces, tolerance, weld=False):
    """Inspect a throwaway bmesh; welding never touches source/candidate meshes."""
    import bmesh
    bm = bmesh.new()
    duplicate_or_invalid_faces = 0
    try:
        bverts = [bm.verts.new(vertex) for vertex in vertices]
        for face in faces:
            try:
                bm.faces.new([bverts[index] for index in face])
            except ValueError:
                duplicate_or_invalid_faces += 1
        if weld:
            bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=tolerance)
        bm.verts.ensure_lookup_table()
        bm.verts.index_update()
        components = []
        unseen = set(bm.verts)
        while unseen:
            start = unseen.pop()
            stack, group, group_faces = [start], [start], set()
            while stack:
                vertex = stack.pop()
                group_faces.update(vertex.link_faces)
                for edge in vertex.link_edges:
                    other = edge.other_vert(vertex)
                    if other in unseen:
                        unseen.remove(other)
                        stack.append(other)
                        group.append(other)
            low = [min(v.co[i] for v in group) for i in range(3)]
            high = [max(v.co[i] for v in group) for i in range(3)]
            components.append({"vertices": len(group), "faces": len(group_faces),
                               "bounds_min_m": low, "bounds_max_m": high})
        components.sort(key=lambda row: row["faces"], reverse=True)
        tiny_threshold = max(8, len(bm.faces) * 0.002)
        return {"vertices": len(bm.verts), "edges": len(bm.edges), "polygons": len(bm.faces),
                "triangles": sum(max(0, len(face.verts) - 2) for face in bm.faces),
                "connected_components": len(components),
                "components_largest_first": components[:64],
                "components_list_truncated": len(components) > 64,
                "tiny_component_threshold_faces": tiny_threshold,
                "tiny_components": sum(row["faces"] <= tiny_threshold for row in components),
                "boundary_edges": sum(edge.is_boundary for edge in bm.edges),
                "non_manifold_edges_including_boundary": sum(not edge.is_manifold for edge in bm.edges),
                "edges_with_more_than_two_faces": sum(len(edge.link_faces) > 2 for edge in bm.edges),
                "inconsistent_winding_edges": sum(edge.is_manifold and not edge.is_contiguous for edge in bm.edges),
                "wire_edges": sum(edge.is_wire for edge in bm.edges),
                "isolated_vertices": sum(not vertex.link_edges for vertex in bm.verts),
                "near_zero_length_edges": sum(edge.calc_length() <= tolerance for edge in bm.edges),
                "degenerate_faces": sum(face.calc_area() <= tolerance * tolerance for face in bm.faces),
                "duplicate_or_invalid_faces_before_weld": duplicate_or_invalid_faces,
                "analysis_only_position_weld": weld, "weld_tolerance_m": tolerance if weld else None}
    finally:
        bm.free()


def opening_samples(vertices, faces, asset):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    low = [min(vertex[i] for vertex in vertices) for i in range(3)]
    high = [max(vertex[i] for vertex in vertices) for i in range(3)]
    span = max(high[i] - low[i] for i in range(3))
    tree = BVHTree.FromPolygons(vertices, faces, all_triangles=False)
    samples = []
    for fraction in [0.05, 0.15, 0.25, 0.35, 0.45, 0.6, 0.8]:
        origin = Vector(((low[0] + high[0]) / 2, high[1] + span,
                         low[2] + (high[2] - low[2]) * fraction))
        hit, normal, index, distance = tree.ray_cast(origin, Vector((0, -1, 0)), 3 * span)
        samples.append({"height_fraction": fraction, "front_ray_blocked": hit is not None,
                        "hit_position_m": list(hit) if hit is not None else None})
    return {"front_assumption": "+Y looking toward -Y; additional rotation chosen by caller",
            "orientation_verified": False, "hole_verified": False,
            "centerline_ray_samples": samples,
            "manual_review_required": True,
            "interpretation": "For TR05/TR06 inspect an open underside and preserved arch void. Samples are advisory; they cannot certify topology, intended openings or correct front orientation."
                              if asset in {"TR05", "TR06"} else
                              "Compare silhouette and front/back against the source image. Samples do not certify shape or direction."}


def render_views(collection, out, resolution):
    import bpy
    from mathutils import Vector
    scene = bpy.data.scenes.new("HUNYUAN_INSPECTION_RENDER")
    bpy.context.window.scene = scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = scene.render.resolution_y = resolution
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("HUNYUAN_NEUTRAL_WORLD")
    scene.world.color = (0.11, 0.12, 0.14)
    shading = scene.display.shading
    shading.light = "STUDIO"
    shading.studiolight_rotate_z = math.radians(25)
    shading.color_type = "MATERIAL"
    shading.show_shadows = True
    shading.show_cavity = True
    shading.cavity_type = "BOTH"
    shading.curvature_ridge_factor = 1.3
    shading.curvature_valley_factor = 1.05
    shading.show_specular_highlight = False
    shading.background_type = "WORLD"
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    material = bpy.data.materials.new("HUNYUAN_REVIEW_NEUTRAL_GREY")
    material.diffuse_color = (0.68, 0.70, 0.73, 1)
    # Independent evaluated copies: visualization does not modify the normalized
    # export, source materials, polygon smoothing or input data.
    depsgraph = bpy.context.evaluated_depsgraph_get()
    for source in collection.objects:
        if source.type != "MESH":
            continue
        mesh = bpy.data.meshes.new_from_object(source.evaluated_get(depsgraph), depsgraph=depsgraph)
        mesh.materials.clear()
        mesh.materials.append(material)
        for polygon in mesh.polygons:
            polygon.material_index = 0
        ob = bpy.data.objects.new("REVIEW_" + source.name, mesh)
        scene.collection.objects.link(ob)
        ob.matrix_world = source.matrix_world.copy()
    bpy.context.view_layer.update()
    vertices, _, _ = collect_geometry(scene.objects)
    low = Vector(tuple(min(vertex[i] for vertex in vertices) for i in range(3)))
    high = Vector(tuple(max(vertex[i] for vertex in vertices) for i in range(3)))
    center = (low + high) / 2
    span = max(high - low)
    camera_data = bpy.data.cameras.new("HUNYUAN_REVIEW_CAMERA")
    camera = bpy.data.objects.new("HUNYUAN_REVIEW_CAMERA", camera_data)
    scene.collection.objects.link(camera)
    camera_data.type = "ORTHO"
    camera_data.clip_start = max(span * 0.001, 0.0001)
    camera_data.clip_end = span * 100
    scene.camera = camera
    directions = {"front": Vector((0, 1, 0)), "back": Vector((0, -1, 0)),
                  "three_quarter": Vector((1, 1.5, 0.8)).normalized()}
    paths = {}
    # Same orthographic scale in all three views preserves within-piece size.
    projected_extents = []
    for direction in directions.values():
        camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
        inverse = camera.rotation_euler.to_matrix().transposed()
        projected = [inverse @ (Vector(vertex) - center) for vertex in vertices]
        projected_extents.extend(max(point[i] for point in projected) - min(point[i] for point in projected) for i in (0, 1))
    camera_data.ortho_scale = max(projected_extents) * 1.22
    out.mkdir()
    for name, direction in directions.items():
        camera.location = center + direction * span * 4
        camera.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
        path = out / (name + ".png")
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        paths[name] = str(path)
    return {"paths": paths, "engine": "Blender Workbench", "material": "neutral grey; visualization override only",
            "resolution": resolution, "orthographic_scale_m": camera_data.ortho_scale,
            "same_scale_across_views_of_this_piece": True,
            "scale_varies_between_pieces_to_fit_frame": True}


def inspect(args):
    import bpy
    if not bpy.app.background or "--factory-startup" not in sys.argv or bpy.data.filepath:
        raise RuntimeError("Use a new Blender --background --factory-startup process")
    source, out = args.source.resolve(), args.out.resolve()
    if out.exists():
        raise FileExistsError("Refusing existing output path: " + str(out))
    document = read_glb(source)
    source_hash = sha256(source)
    texture_check = texture_audit(document)
    out.mkdir(parents=True, exist_ok=False)
    write_json(out / "source_audit.json", {"provider": "Tencent Hunyuan3D", "source": str(source),
                                         "sha256": source_hash, "texture_audit": texture_check})
    previous_scene = bpy.context.window.scene
    try:
        normalize = runpy.run_path(str(HERE / "import_tripo.py"))["main"]
        normalization_log = io.StringIO()
        with contextlib.redirect_stdout(normalization_log):
            normalize(["--source", str(source), "--asset", args.asset, "--out", str(out / "normalized"),
                       "--rotate-deg", *map(str, args.rotate_deg)])
        candidate_path = out / "normalized" / "candidate.json"
        candidate = json.loads(candidate_path.read_text(encoding="utf-8"))
        candidate["provider"] = "Tencent Hunyuan3D"
        candidate["normalization_engine"] = "abbey_tripo/import_tripo.py (shared offline implementation)"
        candidate["pipeline_stage_completed"] = "optional_hunyuan_candidate_normalization_only"
        candidate["asset_definition"]["route"] = "hunyuan_optional"
        candidate["asset_definition"].pop("tripo_route_status", None)
        candidate["generation_request_expectation"] = {"model": "3.0", "generate_type": "Geometry",
                                                      "face_count": args.budget, "enable_pbr": False,
                                                      "request_execution_verified_by_this_tool": False}
        # Updating newly created metadata owned by this invocation; never raw.
        candidate_path.write_text(json.dumps(candidate, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        collection = bpy.data.collections["ABY_" + args.asset]
        scene = next(scene for scene in bpy.data.scenes if collection.name in scene.collection.children)
        bpy.context.window.scene = scene
        bpy.context.view_layer.update()
        vertices, faces, per_object = collect_geometry(collection.objects)
        extent = max(max(vertex[i] for vertex in vertices) - min(vertex[i] for vertex in vertices) for i in range(3))
        tolerance = max(1e-8, extent * 1e-6)
        raw_topology = topology(vertices, faces, tolerance)
        welded_topology = topology(vertices, faces, tolerance, weld=True)
        normalized_texture_check = texture_audit(read_glb(out / "normalized" / "glb" / (args.asset + ".glb")))
        warnings = []
        if not texture_check["no_textures_passed"]:
            warnings.append("SOURCE_CONTAINS_TEXTURES: raw GLB fails the requested no-texture requirement; neutral renders do not cure this.")
        if not normalized_texture_check["no_textures_passed"]:
            warnings.append("NORMALIZED_CONTAINS_TEXTURES: normalized GLB is not texture-free.")
        if raw_topology["triangles"] > args.budget:
            warnings.append("TRIANGLE_BUDGET_EXCEEDED: no decimation performed; report/review before any reduction.")
        if welded_topology["connected_components"] > 1:
            warnings.append("MULTIPLE_COMPONENTS: inspect whether disconnected pieces are intentional or floating debris.")
        if welded_topology["non_manifold_edges_including_boundary"]:
            warnings.append("NON_MANIFOLD_OR_OPEN_BOUNDARY: inspect mating surfaces and unintended holes.")
        if welded_topology["degenerate_faces"] or welded_topology["near_zero_length_edges"] or raw_topology["duplicate_or_invalid_faces_before_weld"]:
            warnings.append("DEGENERATE_OR_DUPLICATE_GEOMETRY: review before approval.")
        report = {"schema_version": 1, "provider": "Tencent Hunyuan3D", "status": "staging_requires_visual_review",
                  "asset_id": args.asset, "source": str(source), "source_sha256": source_hash,
                  "created_utc": datetime.now(timezone.utc).isoformat(), "blender_version": bpy.app.version_string,
                  "synthetic_fixture": args.synthetic_fixture, "production_ready": False,
                  "requested_budget": args.budget, "budget_unit": "triangles (conservative for game rendering)",
                  "actual_polygons": len(faces), "actual_triangles": raw_topology["triangles"],
                  "within_triangle_budget": raw_topology["triangles"] <= args.budget,
                  "texture_audit_source": texture_check, "texture_audit_normalized": normalized_texture_check,
                  "topology_imported": raw_topology, "topology_position_welded_diagnostic_only": welded_topology,
                  "topology_note": "glTF may split vertices for normals/UVs. Raw and position-welded statistics are both reported. Welding is performed only on a disposable analysis copy; it may join touching but separate shells.",
                  "mesh_objects": per_object, "orientation_and_openings": opening_samples(vertices, faces, args.asset),
                  "candidate": str(candidate_path), "candidate_dimensions_xyz_m": candidate["bounds"]["candidate_metres"]["dimensions_xyz"],
                  "automatic_repairs": [], "decimation_applied": False, "raw_overwritten": False,
                  "not_tested": ["self-intersections", "minimum wall thickness", "correct architectural profile", "true back mounting plane", "engine import/collision/LOD"],
                  "warnings": warnings, "renders": None}
        if not args.no_render:
            report["renders"] = render_views(collection, out / "views", args.resolution)
        if sha256(source) != source_hash:
            raise RuntimeError("Source hash changed during inspection")
        write_json(out / "inspection.json", report)
        print("HUNYUAN_INSPECTION " + json.dumps({"asset": args.asset, "triangles": raw_topology["triangles"],
                "no_textures": texture_check["no_textures_passed"], "within_budget": report["within_triangle_budget"],
                "warnings": warnings, "report": str(out / "inspection.json")}, ensure_ascii=False))
    except Exception as error:
        write_json(out / "FAILED.json", {"provider": "Tencent Hunyuan3D", "type": type(error).__name__, "error": str(error)})
        raise
    finally:
        bpy.context.window.scene = previous_scene


def contact_sheet(args):
    from PIL import Image, ImageDraw, ImageFont
    out = args.out.resolve()
    if out.exists():
        raise FileExistsError("Refusing existing output path: " + str(out))
    reports = [json.loads(path.read_text(encoding="utf-8")) for path in args.reports]
    reports.sort(key=lambda report: report["asset_id"])
    if not reports or any(not report.get("renders") for report in reports):
        raise ValueError("Every report needs rendered views")
    cell_width, image_height, caption_height = 420, 420, 58
    header_height = 100
    sheet = Image.new("RGB", (3 * cell_width, header_height + len(reports) * (image_height + caption_height)), (235, 238, 241))
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/arial.ttf")
    title_font = ImageFont.truetype(str(font_path), 27) if font_path.exists() else ImageFont.load_default(size=27)
    font = ImageFont.truetype(str(font_path), 20) if font_path.exists() else ImageFont.load_default(size=20)
    draw.text((22, 16), "Hunyuan geometry inspection | front / back / 3/4", fill=(25, 36, 52), font=title_font)
    draw.text((22, 53), "Neutral material; per-piece framing; staging / visual review required", fill=(62, 75, 92), font=font)
    views = [("front", "FRONT (+Y)"), ("back", "BACK (-Y)"), ("three_quarter", "3/4")]
    for row, report in enumerate(reports):
        for column, (key, label) in enumerate(views):
            image = Image.open(report["renders"]["paths"][key]).convert("RGB")
            image.thumbnail((cell_width - 10, image_height - 10))
            x, y = column * cell_width, header_height + row * (image_height + caption_height)
            sheet.paste(image, (x + (cell_width - image.width) // 2, y + (image_height - image.height) // 2))
            draw.text((x + 12, y + image_height + 3), f'{report["asset_id"]}  {label}  |  {report["actual_triangles"]:,} tris', fill=(25, 36, 52), font=font)
            tags = "TEXTURES: 0" if report["texture_audit_source"]["no_textures_passed"] else "TEXTURES: FAIL"
            tags += " | BUDGET: OK" if report["within_triangle_budget"] else " | OVER BUDGET"
            if report.get("synthetic_fixture"):
                tags += " | FIXTURE"
            draw.text((x + 12, y + image_height + 29), tags, fill=(83, 89, 100), font=font)
    out.parent.mkdir(parents=True, exist_ok=True)
    with out.open("xb") as handle:
        sheet.save(handle, format="PNG")
    print("HUNYUAN_CONTACT_SHEET " + str(out))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--asset", choices=ASSETS)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--rotate-deg", type=float, nargs=3, default=[0, 0, 0])
    parser.add_argument("--budget", type=int, default=3000)
    parser.add_argument("--resolution", type=int, default=640)
    parser.add_argument("--no-render", action="store_true")
    parser.add_argument("--synthetic-fixture", action="store_true")
    parser.add_argument("--contact-sheet", action="store_true")
    parser.add_argument("--reports", nargs="+", type=Path)
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    args = parser.parse_args(argv)
    if args.contact_sheet:
        if not args.reports:
            parser.error("--contact-sheet requires --reports")
        contact_sheet(args)
    else:
        if not args.source or not args.asset:
            parser.error("Inspection requires --source and --asset")
        if args.budget < 1 or not 128 <= args.resolution <= 2048 or not all(math.isfinite(v) for v in args.rotate_deg):
            parser.error("Require positive budget, resolution 128..2048 and finite rotation")
        inspect(args)


if __name__ == "__main__":
    main()
