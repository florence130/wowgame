# 购买资源来源与运行状态

当前保留来源为 `F:\资源\服装\stylized-medieval-market-fatpack--stylarts-5.0+.rar`。工程副本在 `archives/`，大小与来源哈希见 `archive_manifest.json`。该目录使用 `.gdignore` 排除 Godot 扫描和常规导出，游戏启动时不解压。

## Stylarts

RAR 内有 926 个 UE 原生 `.uasset` 和一个 `.uproject`，没有可直接使用的 FBX、GLB、glTF、OBJ 或 Blender 模型。目前仍未转换、未接入游戏，`stylarts_runtime_catalog.json` 仅记录待转换来源。转换需导出实际网格及其引用贴图，按项目色板、UV、压缩和可进入碰撞要求逐项验证。

## 当前美术基准

继续使用 `src/render/art_style.gd` 的统一色板和现有模块化房屋流程。地表使用 `assets/textures/terrain/t0_grass.png` 到 `t8_moss.png`，农田网格土面使用项目已有材质；草的密度、间距、高度和生成逻辑不因本次删除改变。其他来源的天空、光照和资产独立保留。

## 撤销记录

用户于 2026-10-11 明确要求删除 0.4.6。工程内该包的原始 ZIP 副本、提取库、插件、转换资源、专属制作工具和展示场景均撤销，金穗镇中的八个相关实例已移除，也不再作为后续房屋制作基准。F 盘原件没有进行写入或删除。

为保留未通过接入的事实，历史地图截图和失败报告仍在 `.shots/hd2d_046/`，仅作历史证据，不能作为当前运行资源或验收结果。删除清单和当轮加载检查在 `.local/remove_046/`。既有道路、区域边界、农田和房屋入口问题须另外处理。
