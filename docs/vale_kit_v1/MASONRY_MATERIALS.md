# 砂石与红砖材质修订

用户原话：『材质有些反光，这是不对的。民房的墙壁应该是砂石质感，而茅屋的红砖结构也没有红砖质感，都需要调整』。这一要求替代build006/007纯色光滑墙面的旧通过，build008将按实际材料表现复验。

砂石与红砖的albedo由内置imagegen分别生成，原图直接复制到项目，不使用Python图像编辑。实际输出1254×1254。茅草保留此前纤维底图。三者都是包含绘制明暗的材质图，色板用于主色约束，不宣称纹理每个像素等于离散色号。

纹理目录：`assets/models/vale_kit_v1/textures/`：
- `sandstone_grain_albedo.png`：民房/风车墙面和矿物石件的颗粒底图。
- `brick_porous_albedo.png`：现有独立砖几何表面使用的多孔烧结黏土底图，不含额外砖缝。
- `sandstone_grain_normal.png` / `brick_porous_normal.png`：Blender原生程序材质烘焙的切线法线数据，1024×1024；脚本bake_mineral_normals.py。不是修改albedo；无程序纹理留在仅Blender可见的状态。

所有本批材质Roughness=1，Specular IOR Level=0，导出检查KHR_materials_specular.specularFactor=0。砂石/红砖使用标准BaseColorTexture与NormalTexture，原图与法线均内嵌到GLB。红砖轻微Multiply着色变化避免整面机械同色，不用光泽制造材质差异。

材质粒度按米制UV绘制。需要实际整栋正常尺寸与近景检查，以防小样颗粒过密或远景脏斑。受光明暗和接触阴影保留；关闭镜面反射不等于无光照。

实际跨工具发现：本机Godot 4.7.2的GLTFDocument导入后，部分材质metallic_specular=0.5且specular_mode=0，未保留GLB零specular扩展。故交付额外42个原生.scn，显式SPECULAR_DISABLED；保存后重载验证通过。裸GLB失败报告保留，不覆盖为成功。完整导入/重建步骤见HANDOFF。

## 内置imagegen完整提示词

### 砂石

Use case: stylized-concept. Asset type: seamless tileable base-color albedo bitmap for a stylized fantasy MMO farmhouse wall. Full-frame flat orthographic scan of dry cream-colored rough sandstone render, small tightly packed mineral sand grains, subtle tiny pores, chalky eroded mineral flecks and broad quiet painterly variation. This is granular sandstone masonry surface, not smooth plastic plaster, not polished stone. Warm ivory game palette centered on #EFE6D2 with restrained pale sand #E3CF9E and warm light #F4EEE2, preserve light cream identity. Completely matte appearance. Even diffuse albedo only: NO directional light, NO highlights, NO specular shine, NO ambient occlusion, NO cast shadows, NO vignette. No brick layout, no mortar joints, no large blocks, no large cracks, no moss, no dirt stains. Fine material texture readable close up and calm at a distance. Entire square filled by one continuous surface, tileable on all four edges. No border, no labels, no text, no objects, no background.

### 红砖

Use case: stylized-concept. Asset type: seamless tileable base-color albedo bitmap for the individual red brick surfaces of a stylized fantasy MMO barn. Full-frame flat orthographic close scan of dry fired clay brick material: fine open pores, small clay aggregates, granular sandy inclusions, faint kiln mottling and tiny irregular shallow pits, soft hand-painted broad color grouping. Matte unglazed porous brick, not lacquer, metal, polished ceramic or smooth plastic. Game palette centered on muted warm brick red #8A3A2A, restrained #B8553A terracotta variation and tiny dusty warm mineral flecks. Medium-low contrast texture, no bright orange/yellow wash. NO actual brick silhouettes or mortar grid because 3D geometry supplies the brick boundaries. Even flat diffuse ALBEDO ONLY, no directional light, no highlights, no specular reflections, no shadows, no dark vignette, no large cracks or strong dirt stains. Entire square one continuous close surface, seamlessly tileable on all four edges, no text, no border, no background or objects.
