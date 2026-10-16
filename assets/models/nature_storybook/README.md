# Storybook vegetation

Oak, pine and bush meshes derived from **Quaternius — Stylized Nature MegaKit, Standard edition (CC0-1.0)**.
Original selected files, license and SHA-256 provenance:
`assets/third_party/quaternius/nature/`.

| Runtime scene | Original mesh | Normalized height |
| --- | --- | --- |
| oak_0.scn | CommonTree_1, spreading mature crown | 13.0 m |
| oak_1.scn | CommonTree_2, wider forked crown | 12.5 m |
| oak_2.scn | CommonTree_5, asymmetric crown | 14.0 m |
| pine_0.scn | Pine_1, tall layered crown | 16.0 m |
| pine_1.scn | Pine_2, full lower crown | 14.5 m |
| pine_2.scn | Pine_3, extended lower foliage | 17.0 m |
| birch_0.scn / birch_1.scn | Original branched geometry + CC0 leaf mask | about 12.6–12.9 m |
| bush_0.scn | Bush_Common | 1.2 m |

Rebuild after importing the source textures:

```powershell
python tools/texgen/paint_canopy_masks.py
# Import the derived textures before rebuilding scenes. Keep mipmaps/generate=true
# in the three checked-in masks/*.png.import files.
& 'F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path E:\wowgame --editor --import
& 'F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path E:\wowgame --script res://tools/prepare_storybook_nature.gd
```

The build splits bark and foliage, normalizes height, generates canopy normals and vertex gradients, and builds native mesh LODs. The 2026-10-07 pass uses derived linear-data masks: R holds soft leaf volume, G holds broad painted light, and A preserves the original alpha exactly. Mipmaps filter distant leaves; the original CC0 source files remain untouched. Runtime colors still come from the region palette. Trunks use the opaque foliage shader, leaf cards use the separate cutout canopy shader. Forest MultiMeshes switch to matching mature-tree proxies under `proxy/` beyond 120 m, using bounds fitted to both representations and 12 m hysteresis. Broadleaf proxies follow fitted crown clusters; pine proxies reshape the established serrated skirt geometry to each new crown; birch proxies follow the new branch clusters. Proxy stems preserve visible height. Legacy assets remain a missing-resource fallback. Near tree shadows use opaque canopy proxies to avoid expensive alpha tests in every shadow cascade. Outer landscape trees always retain their cheap opaque representation. Selected model resources are warmed through WorldStream's existing bounded background loader.

Tree placement, per-tree scale and streamed ownership are inherited from map descriptors. Trunk collisions use baked stem radii with caps that exclude long low branches (oak 0.78 m, pine 0.55 m maximum before placement scale; birch 0.36 m). Native detail scenes and opaque proxies are accompanied by approximately 1.1 MB of procedurally derived masks; original third-party files total approximately 10 MB. No paid pack files, AI-generated images, or extracted commercial game assets are included.

The final density pass responds to the sparse mature-tree silhouettes. Oak foliage is widened another 30% and extended down to 34% of total height; fitted inner cores and 756 additional card triangles fill its interior. Added oak cards are merged into the original leaf surface/material and generate native LODs. Pine foliage is widened 16% and extended down to 22% of height, with small opaque inner skirts; clean tapered stems replace the bare lower dead branches. These ratios describe geometry bounds; the cutout silhouette begins slightly higher.

The two birches are original procedural geometry: bent tapered stems, visible side branches, eleven overlapping leaf clusters, small solid inner cores and 1,320 alpha-card triangles each. Cards sit around the core perimeter so the solid support does not replace the textured silhouette. Birch bark marks are generated in the foliage shader. Trunks and crowns share the same restrained wind bend. `tests/tree_art.tscn` checks dimensions, real trunk raycasts, referenced far-stem vertices, bounds and queued assets, and captures near/far comparison images with a 1.8 m scale reference.
