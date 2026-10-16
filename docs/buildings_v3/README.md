# 建筑 v3：晨露谷重制（概念图 → 审核 → 拆结构 → 建模）

风格与尺度标准见 `docs/art_direction_v3/STYLE.md`。本批共 13 栋，清单在 `buildings.json`。

## 流程与关卡

| 步 | 产物 | 谁做 | 关卡 |
|---|---|---|---|
| 1 概念图 | `<id>/hero.png`、四视图、`interior.png`、`sheet.jpg`；总览 `_index.jpg` | `py tools/texgen/gen_concepts_v3.py` | **用户审核**：通过则在 `<id>/` 下放一个空文件 `APPROVED`；不通过则删除对应 png 并改 `desc` 后重跑 |
| 2 结构拆分 | `<id>/STRUCTURE.md` | Claude | 每个构件标注：十手法路线，或进浮雕表 |
| 3 简单构件 | Blender 构件库（沿用 GPT abbey_kit_v3 的 socket / manifest 规范） | Claude（Blender MCP / 脚本） | 渲染对照概念图 |
| 4 复杂浮雕件 | `relief_parts.json` → `relief_sheet.png`（`--relief`） | 汇总图由 Claude 生成，**用户在 Tripo3D 批量生成** | 用户确认 Tripo 产出 |
| 5 组装接入 | `.scn` 运行时包 → `gen_vale.gd` → 截图回归 | Claude | autotest tour=vale |

## 拆分原则（与 GPT 十手法对应）

| 构件类别 | 路线 |
|---|---|
| 墙段、檐口线脚、腰线、台阶、石栏杆 | 轮廓 / 分层挤出 + 阵列 + 镜像 |
| 扶壁、尖塔小尖顶、角塔 | CSG + 旋绕（圆锥 / 八角锥）+ 阵列 |
| 尖拱窗、门拱、券 | 曲线倒角 + 实体化 + 镜像 |
| 屋瓦（鱼鳞 / 方瓦 / 红陶筒瓦） | 阵列 + 曲线变形（屋面弧）+ 简单形变（下垂） |
| 茅草屋顶 | 解析 SDF 体量 → SDF 精修 |
| 木筋、檐托、楼梯、长椅、栏杆 | CSG + 阵列 + 镜像（精确尺寸，不过 SDF） |
| 玫瑰窗花格、彩窗铅条 | 旋绕 + 阵列（径向）+ 实体化 |
| 桥、拱廊 | 放样 / 桥接 + 曲线变形（可延长、可弯） |
| **雕像、天使像、门楣浮雕、柱头叶饰、祭坛背屏雕花、徽章、滴水兽** | **进浮雕表 → Tripo3D** |

## 当前状态

- [x] 风格规范、尺度标准、参考帧
- [x] 13 栋的概念图提示词与生成脚本
- [ ] 概念图生成（需要 `TEX_API_BASE` / `TEX_API_KEY` 环境变量）
- [ ] 用户审核
- [ ] 结构拆分 / 建模 / Tripo 浮雕 / 接入
