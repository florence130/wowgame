# 晨露谷农庄建筑 · Claude / Codex 交接

当前候选为 `assets/models/vale_kit_v1/build_008/`。具体独立审查状态见 REVIEW.md。37类模块、农舍/谷仓/风车三栋、独立转子和围栏示例，保留可编辑源Blend、真实GLB和42个Godot原生.scn。**Godot接手优先使用原生.scn；裸GLB在本机Godot导入后会恢复默认镜面反射，不能直接代替原生版本。** 研发根目录有 `.gdignore`，尚未接入正式地图。

## 从哪里看

- `build_008/catalog.html`：三栋实际渲染、正/侧/背面、模块GLB和尺寸表。
- `build_008/vale_kit.blend`：可编辑修饰器、所有模块与装配集合。打开默认显示农舍，切换集合查看其它建筑。
- `build_008/manifest.json`：模块、原点、接口、色板映射、源码哈希。
- `build_008/reimport/renders/`：全新Blender场景重新导入交付GLB后的实际渲染。
- `build_008/godot/assemblies/VALE_farm.scn`、`VALE_barn.scn`、`VALE_windmill.scn`：优先接入的整栋；`godot/modules/`为37类构件，其余装配为转子和围栏。
- `build_008/validation.json`：45个GLB、349项几何/材质/内嵌纹理等检查通过。
- `build_008/godot_validation.json`：裸GLB材质检查**失败记录**，导入成功但部分specular恢复0.5且specular_mode=0；不得将此文件称为Godot材质通过。
- `build_008/godot_native_validation.json`：42个原生.scn保存后无缓存重载并实例化，roughness1、specular0、SPECULAR_DISABLED通过。只证明材质状态和加载，不证明Godot最终像素/帧率。
- `build_008/source_inspection.json`：从实际最终保存Blend检查到可编辑修饰器。

## 用户要求与保留边界

用户允许农舍和谷仓重设计，要求风格统一；农舍为奶油色砂石墙面、深木筋、陶红瓦和紧凑门廊，谷仓为红墙浅筋、宽货门、草料口和装卸梁；风车保留原版收分八角塔、红棕尖帽与四帆。

用户提供的权威色板原图在 `references/aetherlands_palette_v1.png`，机器数据使用 `docs/palette/palette.json`，映射在 `tools/blender/vale_kit_v1/palette_map.json`。非贴图材质逐色匹配；砂石、红砖、茅草为粗糙颗粒/纤维贴图，包含同色系绘制明暗；全材质roughness1、specular0，矿物材质带内嵌法线，不能称每像素都等于离散色卡。

用户已否决早期茅草瓦片。build001–004均不能作为最终谷仓，build005中途终止，build006/007因装配或后续材质要求替代。当前为每坡连续厚覆草层、定向纤维和圆厚端缘。初期概念图只作演变记录，不能推翻用户后续要求。详情见THATCH_MATERIAL.md。

## 重建与验证

在 `E:\wowgame` 的PowerShell执行，构建输出必须用新的目录，避免覆盖已有候选：

```powershell
& 'E:\SteamLibrary\steamapps\common\Blender\blender.exe' -b -t 6 --factory-startup --python-exit-code 1 --python 'E:\wowgame\tools\blender\vale_kit_v1\build.py' -- 'E:\wowgame\assets\models\vale_kit_v1\build_NEW'
py 'E:\wowgame\tools\blender\vale_kit_v1\verify.py' 'E:\wowgame\assets\models\vale_kit_v1\build_NEW'
& 'E:\SteamLibrary\steamapps\common\Blender\blender.exe' -b -t 6 --factory-startup --python-exit-code 1 --python 'E:\wowgame\tools\blender\vale_kit_v1\reimport.py' -- 'E:\wowgame\assets\models\vale_kit_v1\build_NEW'
py 'E:\wowgame\tools\blender\vale_kit_v1\catalog.py' 'E:\wowgame\assets\models\vale_kit_v1\build_NEW'
```

Godot检查使用隔离工程 `.local/vale_godot`。`godot_check.gd`保留裸GLB的真实失败；`godot_pack.gd`读取GLB、关闭原生材质的specular、保存.scn后重新加载验证。重建原生包：

```powershell
Copy-Item -LiteralPath 'E:\wowgame\tools\blender\vale_kit_v1\godot_pack.gd' -Destination 'E:\wowgame\.local\vale_godot\pack.gd'
& 'F:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' --headless --path 'E:\wowgame\.local\vale_godot' --script 'res://pack.gd' -- 'E:\wowgame\assets\models\vale_kit_v1\build_NEW'
```

## 装配与接入

十手法、CSG/SDF阶段、各楼层尺寸见BREAKDOWN.md。农舍墙体12×9×6m，谷仓16×11×8m；默认横向模块4m，农舍层高3m、谷仓4m，不能统一拉伸。几何外包含装饰，实际拼接必须按socket。

Blender X右/Y前/Z上，Godot X右/Y上/-Z前。整栋底心为原点；独立转子以轴心为原点，安装Godot `(0,11.9,-3.65)` 并绕Z旋转。完整风车已含转子，动态接入应移除/替换对应节点，不能重复摆放。

`ModelProp` 会改材质并自动缩放，直接走旧替换路径可能丢失受光材质和正确尺寸。正式接入优先复制选定的 `build_008/godot/assemblies/*.scn` 或 `godot/modules/*.scn` 到正式资源目录，以1米单位直接实例化；保留纹理、法线及受光材质，关闭该对象重复改色/缩放。不要把研发目录整体变为自动导入。

如必须使用源GLB：将 `tools/blender/vale_kit_v1/godot_matte_post_import.gd` 复制到正式项目可导入目录，在该GLB的Advanced Import中设置Import Script为此脚本，然后Reimport。脚本会保留纹理并设置roughness=1、metallic_specular=0、SPECULAR_DISABLED；重新检查实际材质。**不能只设置粗糙度，不能依赖本机Godot自动保留KHR_materials_specular。** GLB仍可供Blender/其它支持扩展的工具编辑，实际Blender重载效果已检查。

仍需实际地图中的碰撞、门洞通行、导航、LOD与合批。GLB保留大量模块/装饰节点，材质正确不代表可大面积铺设；具体三角数与primitive数见validation.json。当前工作没有改动正式地图、原有模型或另一会话的abbey目录。


