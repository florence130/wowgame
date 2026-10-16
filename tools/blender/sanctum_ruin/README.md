# 海洋女神旧圣堂 · Blender 制作源

本制作源继续使用既有副本的平面白盒、地面高差、门与战斗路线。正殿/后殿地面仍在 y24，实体屋顶由 y40 提高到 y54.4；分面拱顶内表面最高约 y53.2。提高的是建筑实体与碰撞，游戏 FOV 仍为 60。

## 源文件与导出

- 可编辑源：`E:/wowgame/assets/models/sanctum_blender_ruin/sea_temple_ruin.blend`。保留逐块石材、断面、窗洞工具、原白盒参考、修改后结构与命名分区。
- 完整结构：同目录 `sea_temple_structure.glb`。Godot 替代原结构加载，按真实网格创建墙、地面、屋顶碰撞。
- 美术层：同目录 `sea_temple_ruin.glb`。35 个分区网格，约 10.3 万三角形。新增柱子的实体碰撞与视觉柱脚一致；碎石、藤蔓、薄地砖仅用于美术层。
- 原始白盒：`assets/models/sanctum_unity_v2/sanctum_architecture.glb` 原文件保留，manifest 记录哈希。

Blender 制作了厚柱分段、石块尖拱、交叉肋、穹顶、八处真实高窗墙洞、阶梯式祭坛、贝壳背板与完整女神像。局部缺块、切角断口、灰泥剥落、接缝裂纹、断椅与落石由网格表达。根系侵入点位与破损位置相连。其他房间目前补充同配色的边角破损和植物，地下、回廊、钟台尚没有达到同等细化程度。原白盒包含相交墙体，窗洞布尔后另用切平面清理内部残面，并验证实际碰撞孔洞。

Blender 预览灯不导出。Godot 使用独立高窗灯光预算（最多 6 灯、3 阴影），叠加原来 8 个局部灯预算；全局设置关闭阴影时高窗同步关闭。正殿与地下环境光局部降低，其他地图不改变。窗玻璃仍保留，并非玩家出口；地下覆土与屋顶不开天窗。

## 重建

```powershell
& 'E:/SteamLibrary/steamapps/common/Blender/blender.exe' --background --factory-startup --python-exit-code 1 --python 'E:/wowgame/tools/blender/sanctum_ruin/build.py'
& 'F:/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe' --headless --editor --path E:/wowgame --import --quit
& 'F:/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path E:/wowgame res://tools/gen.tscn -- sanctum
```

`build.py` 从原白盒重建；手工编辑 `.blend` 后，应直接导出对应集合，不能再运行重建脚本覆盖手工修改。修改高窗/柱脚后必须检查实际碰撞与远镜头。

## 证据边界

固定截图使用保存后的 Godot 场景，三名静止原生角色只作未缩放的尺寸参照。固定构图、四处 SpringArm、原生自动战斗是三类独立证据；都不能证明整个地图的美术或人工玩法已经验收。原白盒跨厅跨度比单一直线概念图更大，不能把概念图视为精确路线图。
