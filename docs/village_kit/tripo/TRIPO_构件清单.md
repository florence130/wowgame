# 金穗镇村屋 · 构件拆分与 Tripo 清单（2026-10-10）

房屋拆成两类：

- **Blender 自做**（简单、规整、要按地块尺寸伸缩的）：外墙板、屋面板、山墙三角、墙基、转角柱、塔身、地板 / 天花 / 梁。已在 `tools/blender/village_kit/` 里程序化生成，**不用拿去 Tripo**。说明图 `village_blender_parts_sheet.png`。
- **Tripo 生成**（造型复杂、有雕刻 / 曲面 / 细碎件，做出来能明显提升质感的）：见下表 T1–T13 + 家具 F1–F24。

| 文件 | 用途 |
|---|---|
| `village_tripo_parts_sheet.png` | **T1–T13 复杂构件总图**（5×3 网格，白底，只有编号） |
| `village_furniture_sheet.png` | **F1–F24 家具总图**（6×4） |
| `single/T01…T13.png`、`single/F01…F24.png` | 单件 1024 白底图（总图拆不开时一件一件喂） |
| `TRIPO_生图提示词.md` | 在 Tripo「图片」面板里生成手绘风总图用的提示词 |
| `village_blender_parts_sheet.png` | Blender 自做件（仅说明） |

> 图里的形体是我在 Blender 里搭的白模级造型，作为**版面与造型参考**。图片 API 当前不可用（密钥未开通计费），所以没有 AI 手绘版；
> 你可以在 Tripo 的「图片」里用 GPT Image 2.5 / Nano Banana Pro 以这张图 + 参考图生成手绘版，再图转 3D。

## 尺度（重要）

MMO 尺度：**门洞 ≈ 2.4m 宽 × 3.8m 高**（约玩家身高 2 倍），室内层高 ≈ 5.4m，窗 ≈ 1.8 × 2.2m。
下表「尺寸」已按这个尺度给出；Tripo 导出的 GLB 我会按此缩放。原点放**底面中心**（门 / 窗类放在**墙面中线的底边中点**），+Z 朝外。

## T · 复杂构件（13）

| # | 名称 | 尺寸 宽×深×高 (m) | 英文提示（件名） |
|---|---|---|---|
| T1 | 老虎窗 | 2.4 × 2.2 × 2.6 | roof dormer: small plaster dormer with wooden cross-mullion window, stone sill and its own little red-tile gable roof |
| T2 | 石烟囱 | 1.6 × 1.6 × 5.0 | tall rectangular fieldstone chimney stack with limestone cap and two clay chimney pots |
| T3 | 拱门单元（门扇半开） | 4.8 × 1.6 × 5.4 | arched stone-and-timber doorway with heavy iron-strapped plank door standing half open, worn stone threshold |
| T4 | 门廊（盾徽） | 4.6 × 3.4 × 6.0 | entrance porch: two carved timber posts with curved brackets, small red-tile gable roof, hanging heraldic shield, two stone steps |
| T5 | 挑阁凸窗 | 4.0 × 2.0 × 4.0 | projecting timber bay window with small panes, carved corbel brackets and little tiled shed roof |
| T6 | 双开谷仓 / 马厩大门 | 5.4 × 0.6 × 5.2 | wide double plank barn door with iron strap hinges in a heavy timber frame |
| T7 | 塔楼锥顶（蓝瓦 + 风向标） | 10 × 10 × 6.5 | steep four-sided blue slate pyramid roof with wide eaves and an iron weathervane |
| T8 | 藤蔓 / 灌木 / 花坛（三件） | 各约 1–3 | climbing ivy with yellow flowers; round hedge bush with red berries; small wooden flower bed |
| T9 | 木栅栏 + 小门 | 3.2 段 × 1.6 高 | rustic wooden picket fence section and matching gate |
| T10 | 石井（带小屋顶） | 3.6 × 3.6 × 4.2 | round fieldstone well with small tiled roof, rope winch and bucket |
| T11 | 集市摊位 | 4.8 × 3.4 × 4.2 | wooden market stall with tiled awning, counter and crates of goods |
| T12 | 窗户单元（石窗框 + 窗板 + 花箱） | 3.0 × 0.8 × 3.2 | window unit: thick carved stone surround, cross-mullion glazing, green wooden shutters, flower box; no wall |
| T13 | 店招挂牌 | 2.4 × 0.3 × 2.6 | wrought-iron sign bracket with chains and a wooden shop sign with a golden shield emblem |

## F · 家具（24）

同前一版（桌、长凳、凳、椅、酒桶、木箱、麻袋、石壁炉、铁吊灯、壁灯、书架、酒瓶架、床、柜台、衣柜、地毯、铁砧、锻炉、武器架、训练木人、裁缝人台 + 布匹、马厩隔栏、挂锅架、画框 + 盾徽 + 盆栽）。
尺寸按真实家具 × 1.2（MMO 略放大）：桌高 1.0m、椅座 0.55m、门内吊灯 Ø1.8m。

## 通用后缀（每件都加）

`hand-painted stylised fantasy (World of Warcraft / Mabinogi remake style), chunky proportions, broad clean forms, matte. One single connected object with real thickness and flat mounting faces. No ground, no scenery, no text, no characters.`

## 回收

生成的 GLB 放进 `assets/models/village_kit/tripo/`，文件名用编号（`T03.glb`、`F08.glb`）。告诉我后，我把它们接进装配器替换对应的 Blender 件（门 / 窗 / 烟囱 / 门廊等按构件位置自动摆）。
