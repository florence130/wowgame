# 茅草修复记录

用户指出 build_002 屋顶没有茅草质感，作为必要失败保留。build_003仅改色板，不能关闭此失败。

修复原因：规则硬片、平整表面、齐缝和薄檐不能表达覆草构造。初次厚草束方案仍呈现瓦片分格，已被用户否决。当前thatch.py每坡使用连续有厚度曲面、整体缓慢起伏、圆厚纤维包边和少量草梢，定向UV沿坡面，粗糙度0.97；不把改名、加草纹或换黄色当成构造修复。

贴图由内置 imagegen 生成，保存为 assets/models/vale_kit_v1/textures/thatch_fibre_albedo.png，原图不做程序化编辑。生成提示：

Use case: stylized-concept. Asset type: seamless diffuse/albedo texture for a 3D game's thatched roof, square 1024x1024. Full-frame flat orthographic close surface of tightly laid dry wheat straw, all slender fibres running VERTICALLY from top edge to bottom edge. Hand-painted fantasy MMO material, clean broad painterly color groups at a distance, distinct fine longitudinal straw streaks close up, occasional split stalks, subtle uneven packing and broken ends, natural organic variations in fibre width, not regular planks, no tiled/scalloped shingle outlines, no braid or woven cross-hatching. Restrained game palette: medium dry straw #C8A868, subdued ochre shadow #9C7E48, softly warm light dry straw #DCC18A; no orange cast, no green, no pure white/black. Evenly flat lit diffuse only, no cast shadows, no highlights, no ambient occlusion, no lighting gradient. Tileable seamlessly on all four edges. Absolutely no border, labels, diagram, objects or background; entire image is straw fibres.

色板边界：非贴图材质逐色验证用户色板固有色；茅草贴图以色板茅草中/暗为基色，包含绘制的明暗变化，不能宣称每个像素等于离散色卡。图像生成器实际输出1254×1254；UV按连续材质使用，不把提示中的1024当成文件实测尺寸。

迭代证据：

- probe001 / build004：曾获陪审局部“纤维可辨认”意见，但用户随后原话“你见过茅草瓦片这种东西吗？”否决其片格构造。该局部意见不能作为当前通过依据。
- probe002：取消片格和横缝；陪审仍指出外露山墙边UV拉伸、檐口厚板感，未通过。
- probe003：独立UV的圆厚边条消除了拉伸切面；陪审发现檐角及屋脊端部开口，仍未整体通过。
- probe004：恢复连续草层完整内封边、关闭边条端面、添加实体草脊端部填料，同时校正两坡朝外法线；保留独立边缘UV。需以实际小样与整栋复验结果裁定。

build005在整栋输出过程中因probe003收口问题主动终止，不能作为完整交付包。
