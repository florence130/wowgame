# 晨露谷建筑构件库（modkit）

源码：`tools/blender/modkit/kit.py`（构件）、`build.py`（装配表 + 导出 + 预览）。
运行：`blender -b -P tools/blender/modkit/build.py -- [id,...]`，输出 `assets/models/modkit/<id>.glb`、`docs/modkit/<id>.png` / `_back.png`、`report.json`。

## 拆分方式（参照 SUNTAIL，`docs/suntail_reference/`）

SUNTAIL 栅格为 2m × 3m/层；本项目按尺度标准放大 1.2 倍：**模数 2.4m、层高 3.6m、勒脚 0.6m、墙厚 0.3m**。

| SUNTAIL 分组 | 本库构件 | 十手法 |
|---|---|---|
| Stone Modules | `stone_base` 勒脚、`wall_stone(solid/door/window)`、`quoin` 隅石 | 轮廓挤出、桥接 + 实体化（墙板开洞）、阵列、几何顶点 |
| Frame Modules | `wall_frame(solid/door/window)`、`gable` 山墙 | 桥接 + 实体化、轮廓挤出（木筋）、镜像（斜撑）、阵列（护板） |
| Doors And Windows | `window(rect/arch)`、`door(rect/arch)`、`oculus` 圆窗 | 曲线倒角（窗框 / 门框 / 铰带）、阵列（窗棂 / 门板 / 百叶）、镜像、实体化（玻璃）、旋绕（门环 / 玻璃圆片 / 花） |
| Roofs | `roof_side`、`ridge`、`barge_board` | 实体化、简单形变（屋面下垂 BEND）、几何顶点（檐口外翻）、阵列（脊瓦）、曲线倒角 + 镜像（封檐板） |
| Decor | `bracket` 檐托、`finial` 尖饰、`ivy` 常春藤、`chimney` 烟囱、`lantern` 壁灯、`canopy` 雨棚 | 轮廓挤出、旋绕、阵列 + 几何顶点、曲线倒角 |
| Stairs | `stone_steps`、`railing` | 阵列、旋绕（栏杆柱）、轮廓挤出 |
| Indoor Modules | `floor_planks`、`ceiling_beams` | 阵列 |

每个构件把所用手法写进对象属性 `methods`，`report.json` 汇总每栋实际用到的手法。

## 材质

材质名 `K|<mtype>|<RRGGBB>|<贴图>|<每张米数>`，游戏端 `ModelProp._apply_kit` → `U.kit_mat` 换成 `building.gdshader`。
贴图是 SUNTAIL 的灰度细节图经 `tools/texgen/prep_suntail.py` 处理后的 `assets/textures/building/st_*.png`。GLB 不嵌图。

## 装配表（build.py HOUSES）

`nx/ny` 模数、`floors`（stone/frame 自下而上）、`doors`、`blank`、`canopy`、`chimney`（屋宽/屋深比例）、`lanterns`、`pitch`、`wall_h`。
门默认向内开 100°，可进入；室内有木地板、顶梁、楼板。玻璃 / 植物 / 发光拆成 `*_nocol`，不生成碰撞。

| id | 尺寸 (m) | 用途 |
|---|---|---|
| abbey_quartermaster | 12 × 9.6 × 12.8 | 修道院军需处（石 + 木筋两层，门廊雨棚） |
| abbey_training_hall | 14.4 × 9.6 × 9.5 | 修道院训练馆（高石墙单层，双门） |
| abbey_cottage | 7.2 × 7.2 × 8.2 | 修道院小屋 ×3 |
| vale_house_timber | 9.6 × 7.2 × 11.9 | 金穗镇民居（红陶瓦，尚未接入） |
