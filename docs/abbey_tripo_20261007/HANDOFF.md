# 晨露谷修道院 Tripo 参考包：agent 接手入口

本轮日期：2026-10-07。当前范围是**阶段 1：市政厅参考形制拆解、六件 Tripo 造型参考、工具接入原型**。还没有获得并验收用户在 Tripo 生成的六件模型，不能把图片或示例导入当成最终可用资产。

## 先读这些

1. `E:/wowgame/docs/abbey_tripo_20261007/BREAKDOWN.md`：L0/L1/L2、58 个设计条目、工法选择、CSG/SDF 分流、六件规格与阶段状态。
2. `E:/wowgame/tools/blender/abbey_tripo/assets.json`：新六件的机器可读资产表；尺寸是设计建议，不是照片实测。
3. `E:/wowgame/tools/blender/abbey_tripo/import_tripo.py`：新的接入原型；具体命令与输出见下文。
4. `E:/wowgame/output/imagegen/abbey_tripo_20261007/pack_v1/`：已生成带编号总图 `tripo_parts_board.png`、无字总图 `tripo_parts_clean.png`、`parts/TR01.png` 到 `parts/TR06.png`、`TRIPO_PROMPTS.md` 与 `image_manifest.json`。主AI与独立陪审已实际看图，静态图包用途通过；具体范围见 REVIEW.md；上级目录的 `tripo_parts_clean_v1.png` 保留原 API 输出。
5. `E:/wowgame/docs/abbey_kit_v3/HANDOFF.md`：原有模块库与拼装工具入口；底层 v1/v2 仍被 v3 引用，不能删除。

本轮用用户图片的对称市政厅作为形制参考，用工程已有晨钟修道院作为复用与接入对象。这两个对象应分开记录来源；旧教堂模型不能作为新市政厅参考的完成证明。

## 范围约束

- 去树木、旗帜、徽章、十字、花园、路灯等附属装饰，保留建筑必要檐口、牛腿、山花和窗框。
- 六件默认采用 H 原生 Blender 路线；TR01、TR05、TR06 属于规则几何，应优先精确控制截面。Tripo 仅为可选造型探索，并非硬性依赖；另外三件同样保留原生默认路线。
- 每件从镜像、阵列、轮廓/分层挤出、实体化、曲线倒角、旋绕、曲线变形、桥接/放样、简单形变、几何顶点中选需要的组合，不强制一件使用全部十种。
- 背面、内结构、建筑进深没有直接参考证据，须标记为设计补全。不要把自动生成的背面当成已经核验的建筑设计。
- 1 Blender 单位 = 1 米，+Z 向上、正面 +Y。glTF 导出转为 +Y 向上；所有轴与尺寸须明确记录，避免二次转轴或按整件外包盒强行匹配逻辑开间。

## 六件固定对应

| ID | 名称 | 设计包围尺寸：宽 × 深 × 高 / m | 生成边界 |
|---|---|---|---|
| TR01 | 方形承托柱头 | 1.00 × 0.80 × 0.55 | 不含柱身或梁 |
| TR02 | 檐下曲面牛腿 | 0.45 × 0.60 × 0.80 | 不含墙片与长檐口 |
| TR03 | 老虎窗弧形山花冠 | 1.60 × 0.35 × 0.80 | 不含窗、窗台、屋顶 |
| TR04 | 中央山花单侧曲线肩石 | 0.80 × 0.35 × 1.40 | 另一侧镜像；不含整片山花 |
| TR05 | 钟楼拱龛弧形头石 | 1.30 × 0.40 × 0.65 | 不含立柱、窗、塔 |
| TR06 | 主窗宽缓尖拱顶石框 | 1.50 × 0.28 × 0.90 | 仅上部宽缓拱框，不含直框与玻璃；避免旧教堂的过尖窄窗形 |

这六个 ID 不随中文名称调整而变化。下载文件应保留原始版本，另做规范化副本；同 ID 的重做版本用版本目录区分，不覆盖原始生成结果。

## 图片与 Tripo 使用

总图用于核对六件风格、边界和编号。用于单件生成时采用对应 `parts/TRxx.png`；支持批量创建的 Tripo 界面可一次选六单图。各图是六个不同构件，不能作为一个构件的六视角。仅有拼图输入时不能保证平台自动拆为六件；若生成了一个组合网格，应先评估能否分离，不能直接注册为六个合格资产。

保持浅色石材和图示轮廓，避免生成树旗、徽章、十字、文字、展示底座、场景地面及背景墙。保存 Tripo 的源任务/下载来源信息与原始文件。收到模型后按 ID 对照几何内容，不按下载顺序猜 ID。

## 接收模型后的操作顺序

1. 先检查文件内容与 ID：一件对应一个规格，完整且没有多余墙片、窗玻璃或整塔。把“未收到”“已收到未导入”“已导入待检查”“通过当前检查”分开记录。
2. 查看导入器实际参数，再用新输出目录运行。第一件建议先试 TR01，核对尺度与上下面；确认导入流程后处理其余五件。
3. 检查导入坐标、底部原点、宽深高以及是否误含背景网格。规范化可以辅助匹配建议包围尺寸，但不能证明承托面、洞口或插槽已经精确。
4. 保留生成网格作造型源，另做可复用成品。顶底、背面贴墙面、左右拱脚必须校正；实际接口要依修正后的几何记录。
5. TR04 只需一侧源件。镜像副本应用变换后复查法线、材质和接口，不另向 Tripo 生成不一致的对侧。
6. 转入 Blender 精修时按 BREAKDOWN 的工法和 H/S 路线处理。薄拱框与窗棂不做粗 SDF；需要 SDF 对照时重新建立解析场源，不能将 Tripo 网格或 Remesh 冒充解析 SDF。
7. 输出渲染、源 `.blend`、规范化 `.glb`、尺寸与来源记录。先验证单件，再接到墙、柱、檐口或山花灰盒，核对前/侧/背/俯视接缝。
8. 至少用同一柱头/牛腿/拱框搭出两个不同结构组合，证明复用后，再推进全建筑拼装和游戏接入。

导入器是单件接收与规范化的原型；尚未获得真实 Tripo 结果时，其示例检查仅能证明脚本行为，不能证明六个外部生成模型适用。

## 新导入器的实际命令与合同

在新后台 Blender 进程中运行，源文件替换为实际下载的单件 GLB，输出目录必须尚不存在：

```powershell
& 'E:/SteamLibrary/steamapps/common/Blender/blender.exe' `
  --background --factory-startup --python-exit-code 1 `
  --python 'E:/wowgame/tools/blender/abbey_tripo/import_tripo.py' -- `
  --source 'E:/wowgame/.local/tripo_incoming/TR01.glb' `
  --asset TR01 `
  --out 'E:/wowgame/.local/tripo_candidates/TR01_r001'
```

朝向需要调整时，追加 `--rotate-deg X Y Z`，例如 `--rotate-deg 0 0 90`；单位为度，先看源模型朝向再决定。ID 从 TR01 到 TR06 对应资产表定义，不能仅换 ID 却沿用错误文件。

导入器按目标高度**等比缩放**，保留原宽深比例；不会分轴拉伸强行匹配建议包围尺寸。TR01 原点放在底面中心，其余五件放在背面底部中点；工程 +Y 朝外、+Z 向上。建议宽深与实际结果存在偏差时仍需检查，不能据高度正确宣布全部尺寸通过。

输出目录包含：

- `abbey_kit.blend`：`ABY_TR01` 等 ID 对应集合与带 `asset_id` 的根对象。
- `glb/TR01.glb`：单件规范化候选导出。
- `candidate.json`：本次导入来源与候选信息，字段以实际文件为准。

新候选采用现有 v3 的集合/根层级命名合同，但原型**不写 manifest，也不注册到生产目录或修改 LATEST**。先在 Blender 中 Append 候选集合并检查。只有补全真实几何接口、工法来源、测量和正式目录条目后，才进入旧面板完整的目录/吸附流程。脚本测试结果以实际验证报告为准；合成样例的成功不能替代真实 Tripo 模型验收。

## 复用现有 59 件工具

当前历史指针：`E:/wowgame/assets/models/abbey_kit_v3/LATEST.json`，指向 `build005`。该版本实际有 59 类已生成资产，覆盖地基、墙/门窗、柱梁、屋架、屋顶、天花、后殿、内饰与门层级。源目录为 `E:/wowgame/tools/blender/abbey_kit_v3/`，并依赖 `abbey_kit_v2/` 与 `abbey_kit/`。

在 Blender 文本编辑器执行：

```text
E:/wowgame/tools/blender/abbey_kit_v3/install_panel.py
```

使用 **Abbey Kit** 面板：Read Catalog → Add at Cursor；接口吸附时先选移动件、再选目标件使其为活动对象；Repeat Along Socket Pitch 按节距重复；门使用 Add Editable Component 与 Set Door Opening。

现有面板从构建目录的 `abbey_kit.blend` 追加带资产 ID 的集合；它不是任意 GLB 的通用导入器。新 Tripo 原型生成结果要在来源、尺寸和接口检查后才能加入目录，不能因为 GLB 可打开或集合命名符合合同，就声称已被旧面板完整支持。

原库重建命令（输出目录必须尚不存在）：

```powershell
& 'E:/wowgame/tools/blender/abbey_kit_v3/build.ps1' `
  -Out 'E:/wowgame/assets/models/abbey_kit_v3/new_candidate' `
  -Resolution 1400
```

此命令重建旧修道院配方，不会自动生成本轮市政厅形制。若拓展新结构，使用新配方、新构建目录和新 manifest，不覆盖既有候选。

## 真实状态与证据

- 本轮拆解、六件图像与提示已完成。静态图包已实际看图检查，范围以 REVIEW.md 为准；这不证明真实 Tripo 模型的拓扑、背面、尺寸或拼装接口正确。生成来源见 GENERATION.md。
- 旧 v1 代码真实覆盖十种手法；v3 包含解析 SDF 柱头精修与厚石/薄构件分流。新六件尚不能继承“已执行 SDF”状态。
- 旧 `build005` 内工具、导出、支承、材质、层级、玻璃与 Godot 检查 JSON 的通过标志为真，但 `LATEST.status` 仍是 `final_visual_review_in_progress`，其 build 根目录未发现交接文档提到的 `REVIEW.md`。保留这一历史状态，本轮不修改 `LATEST.json`。
- 旧真实渲染位于 `E:/wowgame/assets/models/abbey_kit_v3/build005/renders/`。`exterior_open.png` 是旧教堂外观，不能替代本轮新造型的视觉检查。
- 现有开发模型目录受 `.gdignore` 隔离。正式地图、碰撞、导航、LOD、材质合批和性能尚未由本轮验证。

后续 agent 应逐阶段保存实际结果：CSG 灰盒 → 解析 SDF 比较 → 拆件分流 → 所选十法精修 → CSG/SDF 改良 → 接口纠正 → 成品构件 → 建筑结构拼装。阶段没有产物或检查未执行时写“待完成/未验证”，不要因文件存在而标记整条流程完成。
