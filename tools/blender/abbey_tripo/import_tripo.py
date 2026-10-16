"""Offline static GLB -> isolated, metre-scale Abbey candidate. Never publishes.

Run only in a new Blender --background --factory-startup process, with
--python-exit-code 1 before --python. See README.md for the complete command.
"""
import argparse
import hashlib
import json
import math
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

import bpy
from mathutils import Euler, Matrix, Vector


HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[2]


def sha256(path):
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path, data):
    # 'x' also prevents accidental replacement inside a freshly claimed folder.
    with path.open("x", encoding="utf-8") as handle:
        json.dump(data, handle, ensure_ascii=False, indent=2, allow_nan=False)
        handle.write("\n")


def matrix_rows(matrix):
    return [[float(value) for value in row] for row in matrix]


def mesh_bounds(objects, transform=None):
    """Actual evaluated vertices, not rotated object bounding boxes."""
    transform = transform if transform is not None else Matrix.Identity(4)
    depsgraph = bpy.context.evaluated_depsgraph_get()
    low = [float("inf")] * 3
    high = [float("-inf")] * 3
    vertex_count = triangle_count = mesh_count = 0
    for ob in objects:
        if ob.type != "MESH":
            continue
        evaluated = ob.evaluated_get(depsgraph)
        mesh = evaluated.to_mesh()
        try:
            matrix = transform @ evaluated.matrix_world
            for vertex in mesh.vertices:
                point = matrix @ vertex.co
                if not all(math.isfinite(value) for value in point):
                    raise ValueError("Mesh contains non-finite coordinates: " + ob.name)
                for axis in range(3):
                    low[axis] = min(low[axis], point[axis])
                    high[axis] = max(high[axis], point[axis])
                vertex_count += 1
            mesh.calc_loop_triangles()
            triangle_count += len(mesh.loop_triangles)
            mesh_count += 1
        finally:
            evaluated.to_mesh_clear()
    if not vertex_count or not triangle_count:
        raise ValueError("Source must contain visible polygon meshes.")
    dimensions = [high[i] - low[i] for i in range(3)]
    if any(d <= 1e-8 or not math.isfinite(d) for d in dimensions):
        raise ValueError("Source needs nonzero extent on all three axes: " + repr(dimensions))
    return {"min": low, "max": high, "dimensions_xyz": dimensions,
            "mesh_count": mesh_count, "evaluated_vertices": vertex_count,
            "triangles": triangle_count}


def validate_source(path):
    if not path.is_file() or path.suffix.lower() != ".glb":
        raise ValueError("--source must be an existing .glb file.")
    with path.open("rb") as handle:
        header = handle.read(12)
    if len(header) != 12:
        raise ValueError("Source has no complete GLB header.")
    magic, version, length = struct.unpack("<4sII", header)
    if magic != b"glTF" or version != 2 or length != path.stat().st_size:
        raise ValueError("Source must be a complete glTF 2.0 binary GLB.")


def image_provenance(spec, definitions):
    path = PROJECT / spec["source_image"]
    return {"path_project_relative": spec["source_image"],
            "exists_at_import": path.is_file(),
            "sha256_at_import": sha256(path) if path.is_file() else None,
            "reference_provenance": definitions["source_provenance"],
            "image_is_design_interpretation": True}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--asset", required=True, choices=["TR01", "TR02", "TR03", "TR04", "TR05", "TR06"])
    parser.add_argument("--out", required=True, type=Path,
                        help="New, nonexistent staging directory; existing paths are rejected.")
    parser.add_argument("--rotate-deg", type=float, nargs=3, metavar=("X", "Y", "Z"),
                        default=[0.0, 0.0, 0.0],
                        help="Euler XYZ degrees in Blender axes after glTF coordinate conversion.")
    args = parser.parse_args(argv if argv is not None else sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
    if not bpy.app.background or "--factory-startup" not in sys.argv or bpy.data.filepath:
        raise RuntimeError("Use a NEW background Blender process with --factory-startup; never run in an open scene.")
    if not all(math.isfinite(value) for value in args.rotate_deg):
        raise ValueError("Rotation values must be finite.")
    source, out = args.source.resolve(), args.out.resolve()
    validate_source(source)
    if out.exists():
        raise FileExistsError("Refusing existing output path: " + str(out))
    definitions = json.loads((HERE / "assets.json").read_text(encoding="utf-8"))
    spec = next(row for row in definitions["assets"] if row["id"] == args.asset)
    source_hash = sha256(source)
    collection_name = "ABY_" + args.asset
    if bpy.data.collections.get(collection_name):
        raise RuntimeError("Candidate collection already exists in this process: " + collection_name)

    # Atomically claim a new directory BEFORE any output; never overwrite/reuse.
    out.mkdir(parents=True, exist_ok=False)
    write_json(out / "INCOMPLETE.json", {"status": "incomplete", "asset_id": args.asset,
               "source_sha256": source_hash, "notice": "Only candidate.json marks a completed staging export."})
    previous_scene = bpy.context.window.scene
    scene = bpy.data.scenes.new("STAGING_" + args.asset)
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["candidate_status"] = "staging"
    bpy.context.window.scene = scene
    try:
        before = set(bpy.data.objects)
        images_before = set(bpy.data.images)
        result = bpy.ops.import_scene.gltf(filepath=str(source))
        if "FINISHED" not in result:
            raise RuntimeError("GLB importer did not finish.")
        imported = sorted(set(bpy.data.objects) - before, key=lambda ob: ob.name)
        if not imported:
            raise ValueError("GLB imported no objects.")
        unsupported = [ob.name + ":" + ob.type for ob in imported if ob.type not in {"MESH", "EMPTY"}]
        animated = [ob.name for ob in imported if ob.animation_data or
                    (ob.type == "MESH" and ob.data.shape_keys)]
        if unsupported or animated:
            raise ValueError("Static stone pieces only; unsupported objects=" + repr(unsupported) +
                             "; animation/shape keys=" + repr(animated))
        if any(ob.parent and ob.parent not in imported for ob in imported):
            raise ValueError("Imported hierarchy unexpectedly references a preexisting object.")
        bpy.context.view_layer.update()
        source_bounds = mesh_bounds(imported)
        rotation = Euler(tuple(math.radians(v) for v in args.rotate_deg), "XYZ").to_matrix().to_4x4()
        rotated_bounds = mesh_bounds(imported, rotation)
        lo, hi = rotated_bounds["min"], rotated_bounds["max"]
        factor = spec["dimensions_xyz_m"][2] / rotated_bounds["dimensions_xyz"][2]
        anchor = Vector(((lo[0] + hi[0]) / 2,
                         (lo[1] + hi[1]) / 2 if spec["origin"] == "bottom_center" else lo[1],
                         lo[2]))
        normalization = Matrix.Translation(-anchor * factor) @ Matrix.Scale(factor, 4) @ rotation
        source_hierarchy = [dict(name=ob.name, type=ob.type,
                                 parent=ob.parent.name if ob.parent else None,
                                 matrix_local=matrix_rows(ob.matrix_local),
                                 matrix_world=matrix_rows(ob.matrix_world)) for ob in imported]

        collection = bpy.data.collections.new(collection_name)
        scene.collection.children.link(collection)
        collection["candidate_status"] = "staging"
        collection["aby_asset_id"] = args.asset
        for ob in imported:
            for old_collection in list(ob.users_collection):
                old_collection.objects.unlink(ob)
            collection.objects.link(ob)
        root = bpy.data.objects.new(args.asset + "_ROOT", None)
        collection.objects.link(root)
        root["asset_id"] = args.asset
        root["candidate_status"] = "staging"
        root["source_sha256"] = source_hash
        root["origin_convention"] = spec["origin"]
        root["socket_status"] = "design_proposal_unverified"
        root["units"] = "metres"
        align = bpy.data.objects.new(args.asset + "_NORMALIZE", None)
        collection.objects.link(align)
        align.parent = root
        align.matrix_basis = normalization
        align["uniform_scale"] = factor
        align["rotation_xyz_degrees_json"] = json.dumps(args.rotate_deg)
        for ob in imported:
            if ob.parent is None:
                # Imported world transforms become local to the normalization
                # node. Original descendants, including nonuniform transforms,
                # remain unchanged; the only added size change is UNIFORM.
                original_world = ob.matrix_world.copy()
                ob.parent = align
                ob.matrix_parent_inverse = Matrix.Identity(4)
                ob.matrix_basis = original_world
        for socket in spec["target_socket_specification"]["sockets"]:
            ob = bpy.data.objects.new(args.asset + "_SOCKET_" + socket["name"], None)
            collection.objects.link(ob)
            ob.parent = root
            ob.location = socket["position_blender"]
            ob.empty_display_type = "ARROWS"
            ob.empty_display_size = 0.08
            ob.rotation_euler = Vector(socket["normal_blender"]).to_track_quat("Z", "Y").to_euler()
            ob["socket_kind"] = socket["kind"]
            ob["socket_name"] = socket["name"]
            ob["socket_status"] = "design_proposal_unverified"
            ob["normal_blender_json"] = json.dumps(socket["normal_blender"])
        bpy.context.view_layer.update()
        final_bounds = mesh_bounds(imported)
        tolerance = max(spec["dimensions_xyz_m"]) * 1e-5
        if abs(final_bounds["dimensions_xyz"][2] - spec["dimensions_xyz_m"][2]) > tolerance:
            raise RuntimeError("Height normalization failed.")
        if abs(final_bounds["min"][2]) > tolerance:
            raise RuntimeError("Bottom-origin normalization failed.")

        # Save an isolated scene as a library. Startup Cube/Camera/Light and any
        # unrelated scene objects are not dependencies and are never exported.
        blend_path = out / "abbey_kit.blend"
        glb_directory = out / "glb"
        glb_directory.mkdir()
        glb_path = glb_directory / (args.asset + ".glb")
        for ob in scene.objects:
            ob.select_set(ob in collection.objects.values())
        bpy.context.view_layer.objects.active = root
        for image in set(bpy.data.images) - images_before:
            if image.source == "FILE" and image.has_data and not image.packed_file:
                image.pack()
        bpy.data.libraries.write(str(blend_path), {scene}, path_remap="RELATIVE_ALL", fake_user=True, compress=True)
        result = bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format="GLB",
                         use_selection=True, use_active_scene=True, export_apply=False, export_animations=False,
                         export_extras=True, export_cameras=False, export_lights=False)
        if "FINISHED" not in result or not glb_path.is_file():
            raise RuntimeError("Candidate GLB export did not finish.")
        review = [
            "Inspect front/back and requested part-only scope against the individual source image.",
            "Review unknown rear/hidden geometry; generated image is a design interpretation.",
            "Check silhouette, watertightness, normals, disconnected scraps, density and UV/material quality.",
            "Cut/repair actual planar bearing and back interfaces; bounding-box alignment does not flatten surfaces.",
            "Replace proposal sockets with measured contact positions and check matched pieces in assembly.",
            "Review actual width/depth deviations; regenerate or rebuild geometry instead of anisotropic stretching.",
            "Confirm polycount, collision, LOD, textures and game-engine import budget before promotion.",
            "Reopen candidate blend and reimport GLB; approve only after visual and dimensional checks."
        ]
        target = spec["dimensions_xyz_m"]
        report = {
            "schema_version": 1, "status": "staging", "production_ready": False,
            "asset_id": args.asset, "label_zh": spec["label_zh"],
            "created_utc": datetime.now(timezone.utc).isoformat(),
            "blender_version": bpy.app.version_string,
            "source": {"path": str(source), "sha256": source_hash, "bytes": source.stat().st_size},
            "source_image": image_provenance(spec, definitions),
            "asset_definition": spec,
            "axes": definitions["axes"], "units": "metres",
            "orientation": {"gltf_to_blender_conversion": "Blender importer applied first",
                            "additional_euler_xyz_degrees": args.rotate_deg,
                            "front_is_verified": False},
            "normalization": {"method": "uniform_by_rotated_height", "uniform_scale": factor,
                              "anisotropic_stretch_applied": False,
                              "source_hierarchy_and_proportions_preserved": True,
                              "anchor_before_scale_in_rotated_space": list(anchor),
                              "matrix_blender": matrix_rows(normalization),
                              "origin": spec["origin"],
                              "origin_is_bounding_box_anchor_not_surface_repair": True},
            "bounds": {"source_blender": source_bounds, "source_after_rotation": rotated_bounds,
                       "candidate_metres": final_bounds},
            "proposed_dimensions_xyz_m": target,
            "dimension_difference_xyz_m": [final_bounds["dimensions_xyz"][i] - target[i] for i in range(3)],
            "source_hierarchy": source_hierarchy,
            "collection": collection_name, "root": root.name,
            "sockets": spec["target_socket_specification"]["sockets"],
            "socket_status": "design_proposal_unverified",
            "review_required": review,
            "outputs": {"blend": "abbey_kit.blend", "glb": "glb/" + args.asset + ".glb",
                        "blend_sha256": sha256(blend_path), "glb_sha256": sha256(glb_path)},
            "catalog_updated": False,
            "pipeline_stage_completed": "optional_tripo_candidate_normalization_only"
        }
        write_json(out / "candidate.json", report)
        # Remove only the marker created by this invocation, inside claimed out.
        (out / "INCOMPLETE.json").unlink()
        print("ABBEY_TRIPO_CANDIDATE " + json.dumps({"status": "staging", "asset": args.asset,
                                                     "out": str(out), "bounds_m": final_bounds["dimensions_xyz"]}))
    except Exception as error:
        write_json(out / "FAILED.json", {"status": "failed", "error_type": type(error).__name__,
                                         "message": str(error), "production_ready": False})
        raise
    finally:
        bpy.context.window.scene = previous_scene


if __name__ == "__main__":
    main()
