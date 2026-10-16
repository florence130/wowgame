# Solenne v5 — native landmark asset handoff

Ten new metre-scale assets are authored by `tools/blender/city_v5/landmarks.py`. No old GLB is loaded, scaled, or reused. Each asset has a preserved `.blend`, an exported `.glb`, a material-batched visual mesh set, and one independent `*-colonly` coarse collision shell.

## Placement contract

- Godot XYZ in metres; front faces **-Z**; use scale **(1,1,1)**.
- Main interior floor is local **y=0**, street **y=-0.6**, foundation bottom **y=-1.2**. Lift each asset **+0.6m above its local terrain/deck**.
- `footprint` is the main body footprint. Cornices, entrance platforms and ramps extend beyond it; use `aabb_min`, `aabb_max` from the exported manifest for placement clearance.
- `entries` and `service_positions` use local metres and are preserved for direct layout integration. Rotate these anchors with the asset.
- The station and trade hall include front and rear ramps. The governor palace includes its courtyard-facing central entry and two front wing entries.
- Governor palace wing entries are **4.6667m** wide; its central entry is **10m**. The courtyard structural footprint is 60×48m, with a conservative interior rectangle of 59×47.5m before landscaping.
- Cathedral `gross_nave_floor` records the large nave floor; `usable_hall` records the flat clear rectangle before the raised altar. Its two service anchors remain at y=0.

Authoritative exported data: `assets/models/city_v5/landmarks/manifest.json`. Each matching JSON here records actual AABB, visual/collision counts and author-time doorway checks. `manifest.plan.json` remains the builder input.

## Assets

| ID | Purpose | Body footprint | Top above floor |
|---|---|---:|---:|
| station | Rail arrival hall, offices, twin clock towers | 100×56m | 46m |
| civic_hall | City administration and central service hall | 88×40m | 44m |
| governor_palace | U-shaped palace and courtyard | 100×70m | 38m |
| cathedral | Nave, aisles and twin spires | 48×94m | 62m |
| trade_hall | Covered trade/exhibition hall with barrel glass roof | 70×38m | ~24m |
| academy | Academic building and observatory | 60×40m | 48m |
| opera | Public performance building | 64×40m | ~28m |
| public_house | Library/hospital public building | 44×28m | 28m |
| magic_tower | Magical institution | 20×20m | 66m |
| guild_hall | Guild services and meeting hall | 44×30m | ~28m |

The station's central 30×48m hall has columns moved to its boundary and benches moved into side wings. The central entrance is 14m wide; the large hall is intended for arriving player crowds.

## References personally inspected

The two contact sheets in `docs/city_v5/references/` and five reference images in `docs/city_review_20261006/references/` were opened and inspected. They informed the stone arcades, thick piers, layered cornices, blue roofs, copper domes, U courtyard, and station barrel roof with twin towers. Contact sheets are sampled video frames; this review does not claim continuous playback of the source videos.

## Verification and evidence

- Blender authoring BVH checks every declared entry at chest height and confirms y=0 floor inside.
- `godot_check.gd` loads the exported GLBs in an isolated Godot 4.7.2 project. It checks exactly one static body and one collision shape per asset, absence of visible `colonly` geometry, and K-material preservation.
- A 1.8m high, radius 0.35m CharacterBody walks from 7m before each entry to at least 3m inside, starting on a street plane at y=-0.6. The test includes all 14 declared entries, including rear ramps and courtyard entry.
- Each of the 24 service positions is checked for y=0 support and a clear standing capsule.
- `godot_import_report.json` records the engine results; `asset_checksums.json` identifies the exported files checked.
- `*_preview.png` and `contact_sheet.jpg` are Blender asset previews with a 1.8m scale witness. They are **not in-game screenshots**.

Rebuild with Blender 5.2: `blender -b --python tools/blender/city_v5/landmarks.py`; optionally pass `-- --only station` or `-- --no-render`.

For the isolated check, copy the GLBs, exported manifest and `godot_check.gd` into a scratch Godot project. Import using `--headless --editor --import --quit`, then run `--headless --fixed-fps 60 --script godot_check.gd`.

## Limits still owned by city integration

The isolated tests establish asset entry/standing support, not navigation through the integrated city. Terrain, plazas, roads, NPC placement, rail/bridge connections, streaming transitions and camera behaviour still require the full-city run. Small facade details and freestanding decorative columns intentionally omit individual collision; the coarse shell blocks walls and supports floors. Interior furnishing is deliberately limited so service placement can follow the city design.
