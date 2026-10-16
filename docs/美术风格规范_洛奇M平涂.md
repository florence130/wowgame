# 美术风格规范 · 洛奇M 式手绘卡通「平涂色块多边形」

> 建立于 2026-10-05。**本项目所有建筑、道具、载具、角色的美术与参考图的唯一风格依据。**
> 上游依据：`CLAUDE.md` §2「美术与 UI 方向参考《洛奇 M》」、`docs/buildings_v2/README.md` 的统一美术规范。
> 适用：Tripo3D 图生模型参考图、Blender 程序化生成、Godot 着色器与后期。

---

## 0. 一句话定义

> **低多边形的面片，每一片填一个纯固有色；不含任何光照、渐变、投影与高光；靠面与面之间的色块差读出体块。**

洛奇M 的观感不是"低配写实"，而是**手绘插画被切成多边形**：颜色饱和明快、笔触随意、形体略夸张。任何让画面显得"被太阳照过"的东西都算跑偏。

---

## 1. 三条铁律（违反即返工）

| # | 铁律 | 禁止出现 |
|---|---|---|
| **一** | **无光照** | 方向光明暗、渐变过渡、投影（脚下影/自阴影）、高光、边缘光、环境光遮蔽变暗 |
| **二** | **平涂色块** | 任何"由明到暗"的平滑过渡；明暗只能以**硬边色块**出现，且最多一档 |
| **三** | **低多边形** | 高密度曲面、圆滑细分表面、写实布线与褶皱；保留可见的**多边形面片转折** |

> 判定口诀：**把图缩到拇指大小，如果还能看出一束光从某个方向打过来 —— 就是错的。**

---

## 2. 色板

### 2.1 晴岚港（城区 / 港口 / 车站）

| 用途 | 名称 | hex | 备注 |
|---|---|---|---|
| 屋顶主色 | 蓝灰石板瓦 | `#6E7C93` | 城镇占比最大，鳞状/鱼鳞瓦 |
| 屋顶深/浅 | 板岩深浅 | `#5A6879` / `#8593A8` | 仅作硬边分块，不做渐变 |
| 墙体主色 | 奶油灰泥 | `#EFE7D6` | 大面积留白墙 |
| 墙体暗 | 灰泥阴面块 | `#DCD0BA` | 唯一允许的一档硬边暗色块 |
| 结构木构 | 深棕木筋 | `#5A4331` | 半木构（Fachwerk）主梁、托架 |
| 木构亮面 | 暖棕木 | `#765B42` | 梁的受光面片 |
| 基座 | 砂岩 | `#C8B79B` | 粗砌块，圆润倒角 |
| 基座深 | 砂岩阴 | `#AE9C80` | 砌缝与底面块 |
| 点缀 1 | 红砖 | `#A85C46` | 烟囱、局部墙面 |
| 点缀 2 | 铜绿 | `#5E9B8B` | 穹顶、雨水管、灯柱 |
| 点缀 3 | 苔痕/藤蔓 | `#6E8A4A` | 屋脊、墙根小面积 |
| 点缀 4 | 遮阳篷条纹 | `#B8443C` + `#F0E4D2` | 红/奶油竖条纹 |
| 魔法光 | 以太水晶 | `#5FD3E0` | **全项目唯一允许自发光的材质** |

### 2.2 晨露谷（乡村）

| 用途 | 名称 | hex |
|---|---|---|
| 屋顶 | 暖橙陶瓦 | `#C4694A` |
| 屋顶 | 金色茅草 | `#D8A94E` |
| 墙体 | 桃橙灰泥 | `#E8C9A8` |
| 木构 | 深棕木构 | `#4E3A2C` |

### 2.3 昼夜全局色调（渲染阶段用，见 §7）

| 时段 | 色调乘数 | 说明 |
|---|---|---|
| 白天 | `#FFFFFF` | 原色 |
| 清晨/黄昏 | `#FFC89B` | 整体转暖橙 |
| 夜晚 | `#7A8CC8` | 整体转冷蓝 |

> 昼夜**不改物体固有色，只做一次全局染色**（multiply）。这样才保住"平涂"。

---

## 3. 形制语汇（洛奇M 式，来自 `buildings_v2/README.md`）

**要有**
- 比例**略夸张**：门偏大、窗偏大、层高偏矮
- **厚重的挑檐**，屋檐明显外挑并投下一条深色檐下色块
- **略下垂的屋脊**（屋脊中部微微下凹），不做笔直犀利的几何
- **粗木梁与托架**外露，转角处有斜撑
- **圆润的石砌基座**，砌块倒大圆角
- 生活化小细节：花箱、吊灯、藤蔓、苔藓、木桶、招牌

**不要有**
- 写实化的锐利棱线与大量重复细小构件
- 精密机械感（齿轮、螺栓、铆钉阵列）
- 哥特式密集尖塔、繁复肋拱

> **对车站的直接影响**：v2 的科林斯凹槽柱 + 齿饰 + 三角山花属于"新古典精密语汇"，需**简化并加粗**——
> 保留柱式与山花作为地标标识，但柱子改粗短、去掉密齿饰、檐口加大加厚。

---

## 4. 材质与资产规范

| 项 | 取值 |
|---|---|
| 导出格式 | GLB（Godot 直接可用） |
| 贴图尺寸 | 常规 1024²；地标 2048² |
| 贴图内容 | **固有色 + 硬边色块**，不烘光照；可含极轻的手绘笔触噪点 |
| 面数（住宅/店铺） | 8k–15k 三角面 |
| 面数（地标） | 20k–40k |
| 面数（道具） | 1k–3k |
| 面数（车站整站） | 12k–18k |
| 朝向 | **正门朝 −Z**（Godot 前方，Blender +Y） |
| 原点 | 底面中心 |
| 单位 | 米 |
| 发光材质 | 仅以太水晶，命名 `_emit`，青蓝 `#5FD3E0` |
| 命名 | 材质后缀区分：`_plaster` / `_timber` / `_slate` / `_sandstone` / `_brick` / `_verdigris` / `_moss` / `_emit` |

---

## 5. 参考图生成：统一提示词模板

### 5.1 拼版前缀（三视图，照抄不改）

```
Turnaround reference sheet for 3D modeling: the SAME single object shown three times side by side
on a pure flat white background — LEFT panel: front view; MIDDLE panel: side view rotated exactly
90 degrees (profile); RIGHT panel: back view. Orthographic projection, identical scale and vertical
alignment, evenly flat lighting, no cast shadows, no ground plane, no floor, no text, no labels,
no watermark, no frame, generous white space between panels.
```

### 5.2 风格后缀（**新增，替换旧的 `stylized low-poly game asset, hand-painted texture` 写法**）

```
Mabinogi-style hand-painted cartoon low-poly game asset, flat shaded, every polygon facet filled
with one solid flat colour, visible polygonal facets, completely unlit, no directional lighting,
no gradients, no soft shading, no ambient occlusion, no cast shadows, no specular highlights,
no rim light, hard clean edges between flat colour regions, chunky slightly exaggerated
proportions, thick overhanging eaves casting one flat dark eave-band colour, slightly sagging
roof ridge, round chunky stone block base with soft corners, clean readable silhouette,
single object, no ground, no surrounding landscape, no text, no watermark
```

### 5.3 色板后缀（按区域二选一）

晴岚港：
```
colour palette: blue-grey slate roof tiles #6E7C93, cream lime plaster walls #EFE7D6,
dark brown half-timber framing #5A4331, sandstone block base #C8B79B, accents of red brick
#A85C46, verdigris copper #5E9B8B and moss green #6E8A4A, only flat solid fills
```

晨露谷：
```
colour palette: warm orange clay roof tiles #C4694A, golden thatch #D8A94E, peach plaster
#E8C9A8, dark brown timber #4E3A2C, only flat solid fills
```

### 5.4 穿透洞（建筑构件必加，否则 AI 会把洞口封死）

```
hollow penetrating openings, no glass filling
```

---

## 6. 验收清单

**通过**
- [ ] 缩到拇指大小看：**看不出任何来光方向**
- [ ] 每一个色区边界都是**硬边**，放大看不到渐变带
- [ ] 地面/背后**没有投影**
- [ ] 表面**没有白色高光斑**
- [ ] 能数出**多边形面片的转折**（不是圆滑曲面）
- [ ] 屋顶、墙体、木构、基座的**色相符合上表**，没有出现象牙白/大量金饰
- [ ] 三张视图是**同一造型**（层数、塔尖、开间一致）
- [ ] 侧视真的是 90° 侧面
- [ ] 裁切后主体完整，水印已去净

**返工信号**
- 出现"油画感"的柔和明暗 → 提示词里的 `no gradients / no soft shading` 没生效，重写
- 出现金灿灿的金属反光 → 色板后缀被忽略，把 `gold` 相关词全部删掉
- 洞口被封死 → 漏了 §5.4
- 面数感过于圆滑 → 加强 `visible polygonal facets`、`low-poly`

---

## 7. 与渲染管线的衔接（**本轮不改，记录待办**）

资产图改完之后，Godot 侧要同步，否则图是平涂、游戏里还是被太阳照：

| 文件 | 现状 | 目标 |
|---|---|---|
| `src/render/building.gdshader` | 自定义 `light()`：两段卡通明暗 + 边缘光 + 卡通高光 + 接地 AO | 改为 `render_mode unshaded`；把 `light()` 整段删除；保留程序化/贴图色块细节，去掉一切 `lit` 相关项 |
| `src/terrain/terrain.gdshader` | `render_mode diffuse_toon` | 改 `unshaded` |
| `src/terrain/grass.gdshader` | `render_mode ..., diffuse_toon, ...` | 改 `unshaded` |
| `src/terrain/water.gdshader` | `render_mode diffuse_toon, specular_toon, ...` | 改 `unshaded`，菲涅尔天空反射改为固定色块 |
| `src/world/world.gd` | 太阳/月亮 `DirectionalLight3D` + 阴影 + SSAO + Glow + ACES | 关闭 SSAO / 阴影 / Glow；`unshaded` 下光照不影响物体，昼夜改为**全局色调 uniform**（§2.3）传入各着色器相乘 |

> 注意：`unshaded` 模式下 `LIGHT` / `AMBIENT_LIGHT` 都不参与计算，昼夜必须靠自定义 uniform 实现。
> 这一步会动到 pipeline，**等资产定稿后再单独开一轮**。
