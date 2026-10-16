# 本次交付：修道院构件拆解与 Tripo 图包

第一阶段已交付：52 个原生 Blender 构件配方族的拆解规格，以及 6 个可选 Tripo 造型候选。不是 58 个已经完成的 3D 模型。

## 直接使用

1. 打开 `output/imagegen/abbey_tripo_20261007/pack_v1/tripo_parts_board.png` 查看六件编号。
2. 生成单件时使用 `pack_v1/parts/TR01.png` 到 `TR06.png`，每件配同名 `_prompt.txt`。无字总图为 `tripo_parts_clean.png`。六图是不同物件，不是同一物件的六个视角。
3. 返回模型按相同 ID 保存，使用 `tools/blender/abbey_tripo/README.md` 中的命令导入到全新候选目录。
4. 其他 agent 从 `docs/abbey_tripo_20261007/HANDOFF.md` 接手；详细工法和结构层级在 `BREAKDOWN.md`。

压缩包保留工程相对目录结构，工具只依赖 Blender（图包重建另需 Python/Pillow 及中文字体）。原项目在 `E:/wowgame`；换电脑后替换文档示例中的绝对路径。导入器依据脚本位置定位项目根，所以应保留 `tools/blender/abbey_tripo/` 与 `output/imagegen/…` 层级。完整旧修道院建模库没有打进此轻量交付包；需要在原项目中继续复用，其入口已在 HANDOFF 中列明。

## 验证与下一阶段

- 本图包经实际看图检查；独立陪审 GPT-6 Astra Low 对 delivery-v1 的 G1–G4 阶段目标通过，详见 `REVIEW.md`。
- 导入器已用包含父子层级、旋转和非均匀原始比例的合成 GLB 做往返验证；报告 `TOOL_VALIDATION.json`。这是脚本验证，不是真实 Tripo 模型验收。
- 真实 Tripo 模型仍待返回。后续按 CSG 灰盒 → 解析 SDF 比较 → 小件分流与所选十法 → CSG/SDF 精修 → 接口校正 → 两种复用装配 → 游戏接入，逐阶段保存实际证据。
- 当前没有替换正式游戏场景，没有更改旧库 LATEST；新工具仅生成 staging 候选。

图像方式：imagegen CLI / gpt-image-2，用户指定 API；完整来源与提示在 `GENERATION.md`、`image_prompt.txt`。包内没有 API 密钥。
