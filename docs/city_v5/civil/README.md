# City v5 — civil engineering and harbor assets

Seven original native-metre assets, each delivered as a GLB and editable Blender source. Their construction is defined in `tools/blender/city_v5/civil.py`; none uses nonuniformly stretched legacy models.

## Placement contract

Keep scale `(1, 1, 1)`. Translate and rotate the complete asset. Blender +Y becomes Godot -Z.

| Asset | Authored size / role | Root datum |
|---|---|---|
| `city_gate_grand` | 18 m clear street passage between substantial gate towers; 14 m central arch clearance, 11 m springing height | Street grade, y = 0 |
| `city_wall_32` | 32 m repeat length along X; 7 m structural depth; wall-walk y = 16.2 m | Grade, y = 0 |
| `city_corner_tower` | 22 m body diameter, 24 m nominal footprint, 28 m high | Grade, y = 0 |
| `city_bridge_74` | 74 m along Z, 22 m deck, three 20 m clear arch spans; cutwaters extend to 28 m total width | Road deck, y = 0 |
| `harbor_passenger_65` | 65 m hull, 13 m beam; finished main deck y = 2.76 m | Waterline, y = 0 |
| `harbor_sailing_52` | 52 m hull, 12 m beam, about 55.2 m including bowsprit; finished main deck y = 3.16 m | Waterline, y = 0 |
| `harbor_crane` | 8 m base; supported lattice boom and counterweight; hook toward -Z | Quay surface, y = 0 |

The bridge must span a real opening in terrain and embankment; it does not remove terrain beneath itself. Its piers extend to y = -8 m. Ship keels extend to y = -3.2 m. Use the manifest's `actual_bounds_godot` when checking clearance from neighbors.

Architecture assets use a separate convention: `assets/models/city_v5/architecture/manifest.json` requires root placement at street grade + 0.6 m. That lift does not apply to these civil assets.

## Verification

- All 21 architecture/civil GLBs import into Godot with one authored collision shape each and unit-scale transforms.
- `godot_asset_verification.json`: 139 checks, zero failures, using isolated imported scenes and Godot physics rays. Includes open/closed building entrances, finished interior floors, gate opening and arch, bridge road/footways/piers/waterway, wall-walk and both ship decks.
- `save_hashes.json`: three existing character saves still match the hashes recorded before the work. Verification did not launch the game world.
- Seven PNG previews were individually inspected; `catalog.png` provides a contact sheet. These are Blender previews, not evidence of final in-game route continuity, lighting or frame rate.
- Gate and bridge have complete solid spandrels and continuous arch collision. Structural faces were separated where overlapping coplanar surfaces caused dark bands.

## Rebuild

```text
blender -b --python tools/blender/city_v5/civil.py -- --all
blender -b --python tools/blender/city_v5/civil.py -- --all --preview-only
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://docs/city_v5/civil/verify_assets.gd
```

Preview-only mode leaves GLBs and Blender source files unchanged.
