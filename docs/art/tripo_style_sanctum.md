# Tripo API 美术规范 — 潮汐圣所 Sanctum 建筑

> 建立于 2026-10-12  
> 用途：为潮汐圣所地区的建筑与道具生成 3D 模型  
> 基于：`output/imagegen/sanctum_preview_20261012/` 预览图

---

## 1. 整体美术方向

### 1.1 核心风格定位

**废墟化的海洋宗教建筑**，融合：
- 哥特式垂直感（尖拱、肋拱、玫瑰窗）
- 巴洛克装饰元素（贝壳纹样、波浪旗帜、繁复雕刻）
- 地中海石造质感（米白色石材、风化裂纹）
- 自然侵蚀破败感（藤蔓缠绕、石块崩塌、青苔覆盖）

**重要**：洛奇 M 风格的"降一档华丽度" —— 保留造型特征，但避免过度繁复的细节雕刻。

### 1.2 色彩规范

| 材质类型 | 主色 | 辅色 | 细节色 |
|---------|------|------|--------|
| **石材主体** | 米白色 `#E8DCC8` | 暖灰色 `#C4B5A0` | 风化黄褐 `#A89274` |
| **旗帜/装饰** | 深海蓝 `#2C5F7D` | 浅海蓝 `#5A8BA8` | 白色波浪纹 |
| **植被侵蚀** | 深绿藤蔓 `#3A5A3F` | 浅绿青苔 `#6B8E6F` | 黄褐枯叶 `#8B7355` |
| **金属配件** | 古铜色 `#6B5742` | 锈迹褐 `#8B6F47` | 青铜绿锈 `#4A7C7E` |

---

## 2. 建筑类型与 Prompt 模板

### 2.1 核心地标建筑（Landmarks）

#### 【大门与前庭】Gate Forecourt
```
A grand ruined sea temple entrance gate, Gothic pointed arches overgrown with vines, 
stone pillars with shell motifs and wave patterns, blue ceremonial banners hanging from weathered wooden beams, 
crumbling stone pavement with moss and cracks, abandoned stone fountain with shell basin in foreground,
Mediterranean cream-colored limestone with brown weathering stains, 
scattered ceramic pots and broken pillars, warm afternoon lighting, fantasy MMO style inspired by Mabinogi Mobile
```

**关键元素**：
- 尖拱门洞（Gothic pointed arch）
- 贝壳纹样石柱（shell motif pillars）
- 蓝色仪式旗帜（blue ceremonial banners）
- 风化石材地面（crumbling stone pavement）
- 前景石质贝壳喷泉（stone shell fountain）

#### 【回廊庭院】Cloister Court
```
A ruined monastery cloister courtyard, colonnaded arcade with pointed arches on left, 
overgrown central garden with ancient trees breaking through stonework, 
grand vaulted archway entrance in background with fan-shaped sunburst carving, 
octagonal bell tower with Gothic windows visible beyond, 
scattered stone debris and moss-covered steps, blue banners with white wave symbols,
warm stone textures with green ivy overgrowth, dramatic perspective with vanishing point at central arch,
fantasy MMO architectural concept art in Mabinogi Mobile style
```

**关键元素**：
- 侧廊拱廊（colonnaded arcade）
- 中央庭院古树（ancient trees breaking through stonework）
- 扇形日辉雕刻拱门（fan-shaped sunburst arch）
- 八角钟楼背景（octagonal bell tower）
- 透视感强烈的纵深构图

---

### 2.2 建筑构件（Props）

#### 【尖拱门】Pointed Arch Gate
```
A single Gothic pointed arch gateway, weathered cream limestone with visible stone blocks, 
ornate shell-shaped keystone carving at apex, flanking decorative columns with wave motifs,
green ivy growing along edges, blue ceremonial banner hanging from wooden crossbeam,
modular game asset, clean geometry for tiling, fantasy MMO style
```

**尺寸参考**：宽 4m × 高 6m × 深 0.8m  
**用途**：可平铺组成长廊

#### 【贝壳纹样柱】Shell Motif Column
```
A decorative stone pillar with scallop shell relief carving, 
square base with wave pattern border, cylindrical shaft with vertical fluting,
cream-colored limestone with brown weathering stains and green moss patches,
ruined capital with broken edges, modular architectural element for fantasy MMO
```

**尺寸参考**：底边 0.6m × 高 3.5m  
**变体**：完好版 / 半毁版 / 断裂版

#### 【波浪旗帜】Wave Banner
```
A vertical ceremonial banner, deep ocean blue fabric with white wave symbol emblem,
hanging from weathered wooden pole with rope, fabric shows wind movement and slight tattering,
fantasy medieval style, game-ready prop
```

**尺寸参考**：宽 1.2m × 高 3m  
**材质**：布料 Shader，需要风力顶点动画

#### 【石质喷泉】Shell Fountain
```
A small stone fountain basin shaped like an open scallop shell, 
weathered limestone with moss and water stains, 
octagonal pedestal base with wave pattern carvings, 
fantasy medieval garden prop
```

**尺寸参考**：直径 1.5m × 高 0.8m  
**用途**：庭院装饰

#### 【藤蔓覆盖立柱】Ivy-Covered Pillar
```
A ruined stone pillar heavily overgrown with green vines and ivy, 
broken capital with exposed internal stones, thick twisted vines wrapping around shaft,
moss-covered base with scattered rubble, cream limestone base material,
environmental storytelling prop for abandoned ruins
```

**尺寸参考**：底边 0.8m × 高 4m（断裂高度随机）

---

### 2.3 地面与铺装（Ground Elements）

#### 【石板地面】Stone Pavement
```
Octagonal and rectangular stone tile pavement, cream-colored limestone blocks,
irregular cracks with moss and grass growing through, weathered edges and uneven surfaces,
circular pattern inlay in center, modular tileable ground texture for fantasy MMO
```

**尺寸参考**：4m × 4m 模块  
**变体**：圆形镶嵌纹样版 / 纯铺装版

#### 【台阶组】Ruined Steps
```
A set of weathered stone steps, cream limestone with moss covering, 
broken edges and missing corner pieces, green plants growing in cracks,
modular staircase element, 5 steps ascending
```

**尺寸参考**：宽 3m × 进深 2.5m × 高 1m

---

## 3. 通用 Prompt 要素清单

每个 Prompt 必须包含以下要素（按优先级排序）：

### 3.1 强制要素（P0）
1. **材质基调**：`weathered cream limestone` / `Mediterranean stone`
2. **风化效果**：`moss-covered` / `crumbling` / `cracked` / `overgrown with vines`
3. **装饰主题**：`shell motifs` / `wave patterns` / `ocean religious symbols`
4. **色彩锚点**：`blue ceremonial banners` / `green ivy` / `brown weathering stains`
5. **风格声明**：`fantasy MMO style inspired by Mabinogi Mobile`

### 3.2 推荐要素（P1）
- **光照描述**：`warm afternoon lighting` / `soft sunlight through arches`
- **几何特征**：`Gothic pointed arches` / `colonnaded arcade` / `octagonal tower`
- **破败细节**：`scattered debris` / `broken pillars` / `exposed stonework`

### 3.3 可选要素（P2）
- **构图指导**：`dramatic perspective` / `vanishing point at center`
- **概念艺术暗示**：`architectural concept art` / `game environment design`

---

## 4. 反面案例（避免的表述）

❌ **过度具象的破坏**  
`collapsed roof with exposed wooden beams and hanging cables`  
→ 太现代，且细节过碎，Tripo 难以还原

❌ **复杂光照要求**  
`god rays shining through stained glass with rainbow caustics`  
→ Tripo 不处理光照，这些是引擎的事

❌ **多物体场景**  
`a courtyard with fountain, benches, NPCs, and background buildings`  
→ 一次生成一个独立物体，场景由 Godot 组装

❌ **风格混杂**  
`steampunk gears mixed with Gothic arches`  
→ 保持海洋宗教主题统一

---

## 5. Tripo API 调用规范

### 5.1 文生 3D 参数
```python
{
    "type": "text_to_model",
    "prompt": "<上述 Prompt 模板>",
    "model_version": "v2.0-20240919",  # 最新版本
    "texture_quality": "high",          # 必须高质量纹理
    "face_limit": 30000,                # 建筑类建议 2-3 万面
    "pbr_texture": True                 # 启用 PBR 材质
}
```

### 5.2 图生 3D 参数（当有概念图时）
```python
{
    "type": "image_to_model",
    "file": "<概念图路径>",
    "model_version": "v2.0-20240919",
    "remove_background": False,         # 建筑保留背景上下文
    "texture_quality": "high",
    "face_limit": 30000
}
```

---

## 6. 后处理检查清单

生成完成后在 Blender 中检查：

- [ ] **材质一致性**：石材是否为米白色系（非纯白/灰黑）
- [ ] **破败合理性**：裂纹/藤蔓是否自然分布（非对称暴力破坏）
- [ ] **装饰完整性**：贝壳纹样是否可识别（非抽象噪点）
- [ ] **比例正确性**：门洞高度 > 人物 2 倍（约 4-6m）
- [ ] **法线方向**：面朝向正确，无内翻
- [ ] **UV 完整性**：纹理无拉伸/重叠（特别是柱子顶部）

---

## 7. 版本记录

| 日期 | 版本 | 变更说明 |
|------|------|----------|
| 2026-10-12 | v1.0 | 初版，基于 gate_forecourt / cloister_court 预览图建立 |

---

## 附录：参考图像

- `output/imagegen/sanctum_preview_20261012/02_gate_forecourt.png` — 大门前庭全景
- `output/imagegen/sanctum_preview_20261012/03_cloister_court.png` — 回廊庭院纵深
- `output/imagegen/sanctum_preview_20261012/*.png` — 其他视角（待补充）
