# 潮汐圣所白盒模型 v1.0

> 创建日期：2026-10-12  
> 工具：Blender 5.2.2 LTS  
> 风格：地中海 + 希腊古典

---

## 📦 文件清单

| 文件名 | 说明 | 尺寸 | 用途 |
|--------|------|------|------|
| `sanctum_whitebox_v1.glb` | 完整白盒场景 | 5根完整柱+1断裂柱+台阶+平台 | Godot 预览/测试 |
| `doric_column_complete.glb` | 单根多立克柱（完整） | 高5.6m, 底径0.8m | 可复用构件 |
| `doric_column_broken.glb` | 单根多立克柱（断裂） | 高3m, 断面不规则 | 废墟装饰 |
| `sanctum_whitebox_v1.blend` | Blender 源文件 | - | 可编辑源 |

---

## 🏛️ 模型规格

### 多立克柱（Doric Column）

**完整版**：
- **柱身**：高 5.0m，底径 0.8m，顶部略细（锥度 0.95）
- **凹槽**：20 条垂直凹槽（Flutes）
- **柱头 Echinus**：曲面过渡，直径 0.92m，高 0.3m
- **柱头 Abacus**：方形顶板，边长 1.84m，厚 0.2m
- **总高度**：5.6m（从地面到顶板）
- **材质**：白色大理石，Roughness 0.3

**断裂版**：
- **高度**：3.0m
- **断面**：顶部不规则（模拟崩塌）
- **用途**：废墟场景装饰

---

## 🎨 材质系统

### 1. 白色大理石（White_Marble）
```
Base Color: RGB(0.96, 0.95, 0.94) — 纯白/奶白
Roughness: 0.3
Specular IOR Level: 0.5
用途：柱子、柱头、三角山墙
```

### 2. 地面大理石（Ground_Marble）
```
Base Color: RGB(0.93, 0.92, 0.90) — 略暗的白色
Roughness: 0.4
用途：地面平台、台阶
```

### 3. 蓝色织物（Blue_Banner）
```
Base Color: RGB(0.12, 0.37, 0.56) — 爱琴海蓝
Roughness: 0.7
用途：装饰旗帜（需要布料 Shader + 风力动画）
```

---

## 📐 场景布局

```
        [三角山墙占位]
         ___________
        /           \
       /             \
      |  [Abacus]    |
      |  [Echinus]   |
      |    柱身      | × 5根（间距3.5m）
      |    柱身      |
      |_____________|
            |
         台阶 × 5级
            |
    ════════════════════
       地面平台 20m×20m
```

**柱子排列**：
- 中央 1 根（位置 0,0）
- 左侧 2 根（位置 -7, -3.5）
- 右侧 2 根（位置 3.5, 7）
- 断裂柱 1 根（位置 3,0，高 3m）

**台阶**：
- 数量：5 级
- 每级：宽 6m × 深 0.4m × 高 0.2m
- 位置：Y = -6 到 -8

---

## 🔧 导入到 Godot

### 1. 导入设置
```gdscript
# 在 Godot 4.x 中导入 GLB
# Project Settings → Import → Scene
Scale: 1.0 (已按米单位建模)
Generate LODs: true
Create Collisions: true
```

### 2. 材质映射
```gdscript
# 替换为 StandardMaterial3D
var marble = StandardMaterial3D.new()
marble.albedo_color = Color(0.96, 0.95, 0.94)
marble.roughness = 0.3
marble.metallic = 0.0

# 应用到导入的模型
$Column.mesh.surface_set_material(0, marble)
```

### 3. 批量复用
```gdscript
# 使用 doric_column_complete.glb 批量生成柱廊
const COLUMN = preload("res://models/sanctum/whitebox/doric_column_complete.glb")

for i in range(10):
    var col = COLUMN.instantiate()
    col.position = Vector3(i * 3.5, 0, 0)
    add_child(col)
```

---

## 📸 参考视角

**相机位置**：(15, -12, 7)  
**相机旋转**：(65°, 0°, 55°)  
**光照**：太阳光，方向 (50°, 0°, 120°)，强度 4.0

**建议渲染设置**：
- 引擎：Cycles
- 采样：128-256
- 天空背景：RGB(0.53, 0.81, 0.98) — 地中海蓝天

---

## 🚧 待完善（Phase 2）

### 优先级 P1（构件细化）
- [ ] 柱头 Echinus 曲面细化（当前为简单圆柱）
- [ ] 三角山墙细节（当前仅占位方块）
- [ ] 横梁（Architrave）连接柱顶
- [ ] 地面石板纹理（当前纯色）

### 优先级 P2（装饰元素）
- [ ] 蓝白织物旗帜（添加布料模拟）
- [ ] 圆形祭坛
- [ ] 青铜火盆
- [ ] 破损细节（裂纹、青苔、风化）

### 优先级 P3（环境）
- [ ] 橄榄树/月桂树
- [ ] 野草/灌木（干燥气候植被）
- [ ] 散落的石块
- [ ] 海滨背景（可选）

---

## 📚 相关文档

- [美术方向 v2.0](../../../docs/art/sanctum_art_direction_v2.md) — 地中海+希腊风格规范
- [Tripo 工作流](../../../docs/art/sanctum_art_direction_v2.md#4-tripo-手动上传工作流) — 手动上传图片生成
- [gen_sanctum.gd](../../../tools/gen_sanctum.gd) — Godot 地图生成器

---

## 🔄 版本历史

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-10-12 | 初版白盒：5根完整多立克柱+1断裂柱+台阶+平台 |

---

**下一步**：将 `doric_column_complete.glb` 导入 Godot，测试碰撞和材质效果。
