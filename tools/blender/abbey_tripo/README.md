# 修道院异形石构件：Tripo 候选接收工具

本目录接收 **6 个单件静态 GLB**，建立尺寸、轴向和接口可检查的候选件，供后续 agent 接手。当前没有真实 Tripo 模型验收结果；本工具不调用网络，不提交 Tripo 任务，也不把导入视为完整建模流程完成。

`assets.json` 是本批统一定义：TR01 石柱头、TR02 檐下牛腿、TR03 老虎窗山花上冠、TR04 中央山花单侧肩石、TR05 钟楼半圆拱头石、TR06 主窗宽缓尖拱顶框。TR03/05/06 **只包含顶部异形部分**，直墙、立柱、竖框、屋顶等规则件继续通过 Blender 制作。树木、旗帜、旗杆、灯具、园艺不在本批。

六件默认采用 H 原生 Blender 手法路线，Tripo/T 仅作可选形状探索，尤其 TR01/05/06 应优先原生参数化制作。本目录的 `route=tripo_optional` 标识的是可选导入分流，`default_route=blender_native_H` 才是默认制作路径。TR06 保留参考图的宽缓尖顶，不改成过尖狭长的教堂窗。

每件尺寸是首轮设计提案，不能当作参考照片测量值。已生成部件图位于 `output/imagegen/abbey_tripo_20261007/pack_v1/parts/TR0N.png`；实际导入时记录图片是否存在和 SHA-256。建筑与旧拆解参考已采用持久路径 `docs/abbey_tripo_20261007/references/townhall.png` / `legacy_breakdown.png`。图像生成来源以交付包中的生成记录为准；本导入工具只记录文件存在性和 hash，不验证图片 API 的生成来源。TR01 采用承压顶板、分层过渡、短方颈；TR02 为弧面/S 形正面，不添加参考图没有的花叶雕刻。

## 使用

在项目目录 `E:/wowgame` 启动**新后台进程**，`--out` 必须是此前不存在的目录。先把 Tripo 下载的 GLB 存到明确的新输入目录，再执行：

```powershell
& 'E:/SteamLibrary/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python 'E:/wowgame/tools/blender/abbey_tripo/import_tripo.py' -- --source 'E:/wowgame/.local/tripo_incoming/TR01.glb' --asset TR01 --out 'E:/wowgame/.local/tripo_candidates/TR01_r001'
```

若观察到导入轴向错误，依据 Blender 导入后的坐标显式补充旋转，并输出到另一个新目录：

```powershell
& 'E:/SteamLibrary/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python 'E:/wowgame/tools/blender/abbey_tripo/import_tripo.py' -- --source 'E:/wowgame/.local/tripo_incoming/TR02.glb' --asset TR02 --rotate-deg 0 0 180 --out 'E:/wowgame/.local/tripo_candidates/TR02_r002'
```

旋转参数为 Blender 坐标系内 Euler XYZ 角度，先经过 glTF 导入器的坐标转换，再应用该旋转。默认 `[0,0,0]` 不代表工具已识别正确正面；需要回看确认。工程单位米、X 宽度、Y 深度、+Z 向上、+Y 从建筑朝外。GLB 文件内部遵循 glTF 的坐标转换，重新导回 Blender 后恢复本合同。

只接受静态 MESH/EMPTY 层级；发现相机、灯光、骨骼、动画或形态键时拒绝，需要先另存干净静态单件。一次输入一个构件，不能把包含 6 件的整张图生成的大模型直接当一个构件导入。一次性总览图可用于提交清单，是否能自动分出 6 个独立模型取决于 Tripo 的实际批量入口；按编号独立图逐件/批量提交后，每个返回 GLB 对应一个编号。

## 归一化与接口

工具根据显式旋转后的**实际网格顶点**测量包围盒，按该件提案高度做**统一比例缩放**。原模型宽高比、深宽比及父子层级中的非均匀比例都会保留，不会独立拉伸 X/Y/Z 来凑提案尺寸。原始矩阵写入交接 JSON。最终宽深与提案的差值同时记录。

- TR01 原点为包围盒底面中心：X/Y 居中，最低 Z=0。
- TR02–TR06 原点为包围盒背面底部中点：X 居中，最低 Y=0，最低 Z=0；件体朝 +Y 延伸。
- 这是包围盒定位，**不意味着背面已切平、承压面可用、净开口正确**。生成的凹凸表面需要后续检查与修整。
- 接口位置来自 `assets.json` 的设计提案。候选中生成同名 Empty，并标记 `design_proposal_unverified`；它们是待核对的目标，不能当作已经测量的实际接点。
- TR04 约定为正面看的左肩石，内侧 +X 较高；另一侧在修正后镜像制作。工具不自动猜手性或镜像。

集合名是 `ABY_TR01` 等，内有带 `asset_id=TR01` 的恒等变换根对象，所有输入对象都挂在根下的 `TR01_NORMALIZE` 对齐节点下，保持原始后代层级。这与 v3 面板的 `ABY_<id>` / 根 `asset_id` / `children_recursive` 加载合同一致。

输出到新目录：

- `abbey_kit.blend`：仅候选新场景及其资源，原启动场景不混入。
- `glb/TR01.glb`：仅该构件层级及接口 Empty，保留自定义属性。
- `candidate.json`：来源 hash、图片 hash/可用性、原始矩阵、旋转/缩放、真实包围盒、尺寸差、接口提案、后续检查项和输出 hash。

默认 `status=staging`、`production_ready=false`。**不写 `manifest.json`，不更新生产 catalog、地图、旧工具或 `LATEST.json`**。因此已有面板不会把候选自动当作生产资源；可先通过 Blender 的 Append 加载候选中的 `ABY_TR01` 集合。通过检查后，另开明确的审核/推广步骤，将验证过的接口和元数据纳入正式 manifest。现有 v3 的简单镜像/重复接口也需匹配实际 kind 与承压位置，不能仅因名称相同就视为兼容。

程序拒绝在交互现场运行；不会清空已有场景。输出目录即使为空，只要已存在也拒绝覆盖。`INCOMPLETE.json` 表示尚未成功完成，失败另写 `FAILED.json`；成功才产生 `candidate.json` 并移除未完成标记。失败目录留作诊断，下次请用新目录名。指定 `--python-exit-code 1` 才能保证 Blender 将脚本异常反映为进程失败退出码。

## 接手检查

1. 核对编号、图像与模型只含对应单件；检查正反面、TR04 左右、TR05/06 孔洞。
2. 打开候选 blend，并在独立进程重新导入导出的 GLB，比对尺寸、原点、层级及贴图。
3. 复核真实宽深、开口、接触面与周围规则件。背面/底面需要时切平；按实际接触面修正接口提案。
4. 清理悬浮碎片、法线、非流形边、过密面；设置实际需要的材质、UV、碰撞和 LOD。
5. `assets.json` 中十法组合是**后续重建/修整建议**，不代表导入网格已有可编辑修改器。该批属于 `tripo_optional` 路线；不合格可回退 `blockout`，再从选用的十法完成。
6. 回到结构拼装验证，记录通过证据后再另行推广。导入测试不能替代真实 Tripo 视觉和结构验收。

本轮合成验证证据放在 `E:/wowgame/.local/abbey_tripo_20261007/`。该证据只覆盖本地工具的层级变换、显式旋转、等比校准、非均匀原始比例保留、候选集合/GLB 再读取以及拒绝覆盖等行为；不证明未收到的真实 Tripo 模型质量。
