# Actual city snapshot

`export_scene.tscn` is a read-only Godot tool. Run it after the city generator finishes:

```powershell
& 'F:/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path 'E:/wowgame' 'res://tools/city_web/export_scene.tscn'
```

It writes `city-data.json` and `export-summary.json`. The HTML bundler reads the JSON directly. Failed validation preserves the previous successful JSON.

- Coordinates are city-local metres; do not apply the world's zone offset.
- `sceneObjects.position` and `yaw` come from the saved scene, including actual building floor lift. They do not come from guessed layout elevations.
- Layout building asset keys match `layout.buildings[].asset`. Generated road objects carry `layoutRoadId`.
- Native GLB bytes retain authored geometry. The browser must hide nodes whose names contain `colonly` or `collision`.
- Generated civil assemblies and legacy scenery are exported as static meshes only. Child transforms retain the generator's pivot offsets. Legacy props use ModelProp's actual asset selection and scale, including the airship and train.
- The terrain grid samples the final saved terrain at native cell spacing. Heights use row-major order, rows increasing Z and columns increasing X. Geometry is rounded to 1mm.
- Godot procedural materials become base-color materials. NPCs, gameplay logic, particles, animation and user interface are omitted. This is a geometry/editing preview, not real-player collision validation.

The exporter verifies all authored building IDs, scene/layout poses and explicit street elevations, unique object IDs, and stable source hashes during export. Elevation validation uses the v5 architectural manifests' 0.6m placement lift; exported elevations still come directly from the saved scene. `baselineHash` is SHA-256 of the exact raw layout file; `sceneHash` and `terrainHash` identify the saved geometry snapshot.
