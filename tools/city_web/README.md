# 晴岚港网页布局编辑器

独立单 HTML，包含原生 GLB、城市静态场景与真实地形。所有编辑仅保存到网页草稿，不会写游戏存档或自动覆盖布局源。

## 构建

数据导出由 `export_scene.gd` / `export_scene.tscn` 完成，输出此目录的 `city-data.json`。导出时场景必须与布局及 `ground_plan.json` 一致。新地面必须先生成真实 `ground_*` 实体；出口不会将待生成总图伪装成正式场景。

安装依赖后运行：

```text
node build.mjs
node --test state.test.mjs
node audit.mjs
node audit-ground.mjs
```

默认产物位于 `docs/city_v5/晴岚港-主城漫游.html`，可直接双击离线打开。支持 `--data <JSON路径> --out <HTML路径>`。构建器嵌入压缩数据和全部 JavaScript；最终两段内联脚本经过语法验证。现代 Chrome、Edge、Firefox、Safari 需要 WebGL 2 和原生 gzip 解压支持。无需本地服务器或 CDN。

## 编辑与回导

- 建筑：点选、Ctrl/⌘ 多选、坐标、朝向、基高、名称、拖动、旋转、隐藏、复制、删除与撤销重做。
- 街坊：优先读取 `layout.blocks[{id,label,buildingIds}]`，也兼容 `members` / `buildings`；无分组时由建筑编号前缀生成。整组平移与绕中心旋转保持相对间距。
- 道路：控制点、主路宽与单侧步行带宽草稿；彩色带只表示修改意图，实际地面保持总图。台地改为只读，须在统一总图里联动处理街道、入口、挡墙和台阶；旧草稿台地参数保留导出，但不再制造局部高度预览。
- 地面审查：隐藏建筑和装饰，显示同源地块边界、建筑预留占地、前后院、入口和街坊步道。底面保持实际ground网格，两处park以外不添加绿色区域。审查模式只读，退出后恢复建筑草稿编辑。
- 草稿以基线 SHA256 为键写入浏览器本地存储；离线 file 页面若不允许存储，会明确提示改用导出。
- JSON 的 `layout` 是完整可回导布局；`changes` 包含建筑、道路、台地的增删改；`sceneChanges` 表达隐藏/删除；`addedObjects` 记录复制建筑的资产及模型楼面抬升。
- `baselineHash` 必须与页面相同，`source` 另记录布局版本、场景、地形和地面总图哈希。导入不会静默跨版本套用坐标。
- 建筑使用城市本地坐标和原生比例 1；Three.js 与 Godot 的 Y 轴朝向一致。显式/隐式地基都保留场景中实际模型抬升（通常 +0.6m）。

步行支持 WASD / 方向键、鼠标转向、地形与模型表面支撑、简单墙面阻挡。鼠标锁定受限时，画面聚焦即可行走，按住左键拖动转向；屏幕按钮也可移动和转向。它用于审阅尺度、街区与连通关系，不是游戏角色碰撞系统的替代品。

`window.CITY_EDITOR` 在加载完成后提供只读快照、选择入口与加载/绘制诊断，方便浏览器验收。模型加载错误会明确列入 `missingAssets` 并显示线框替代，不把替代物当成模型加载成功。


## 新地面出口和审计

`groundPlan`保留总图语义，`groundPlanHash`绑定版本。每个faces/edges/links实体通过sceneId对应真实ground_*GLB；`collisionAssets`另存同一Godot资产中的真实ConcavePolygonShape3D三角面。网页显示GLB并用物理三角面查询地面支撑，绝不从旧Terrain推演新台面。石砖缝按米制世界坐标显示；Terrain颜色来自实际地表绘制权重。

`audit-ground.mjs`核对总图/布局哈希、实体覆盖、GLB与物理顶点、支撑法线和高度，以及材质类别；`audit-ground-coverage.py`独立核对陆域覆盖、三角剖分、两块公园与水域排除。它们不替代实际Player通行，也不证明浏览器着色器视觉效果已亲验。
