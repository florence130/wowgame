# 营地资产库

- `fallen_log.tscn`：横原木，5 米长，包含树皮、切面年轮、断枝及横向圆柱碰撞。
- `campfire.tscn`：石圈篝火，包含柴木、火焰、暖色闪烁光源及炉圈碰撞。`lit` 可关闭火焰和光源。

两者以地面中心为原点、使用米制尺寸，可以直接实例化到任意游戏场景。选角营地直接引用相同资产。也可以使用现有 `ModelProp.asset_scene` 指定这些路径；无需复制 UI 脚本或依赖 `Game.hud`。

材质沿用工程树皮贴图与 `ArtStyle` 石材色板。构建源为 `tools/gen_camp_assets.gd`，资产尺寸与来源见 `manifest.json`。
