# 以太纪元 Aetherlands 色板 v1

从参考视频（E:/DOWNLOADS/新建文件夹，洛奇M/洛奇永恒风格）逐帧 k-means 取色，再按材质整理与微调

## 使用规则

- 不用纯黑 #000 与纯白 #fff：最暗用 #1e2522 / #2a1d12，最亮用 #f7f4ec
- 暗部偏冷（蓝灰 #394550 叠乘），亮部偏暖（日光 #fff4e0）；同一材质 3~4 阶：暗 / 中 / 亮 / 高光
- 饱和度适中：大面积颜色 S≤0.55，点缀色（花、布料、旗帜、果实）可到 0.75
- 木制道具：浅色木板 + 深色木框/包角形成明暗对比；铁件用偏暖的深灰 #3c3a40，不用纯黑
- 石材偏暖米灰，不偏冷蓝；屋顶以石板蓝、赤陶红、铜绿三类为主
- 贴图手绘风：低频大色块 + 少量笔触，不要写实噪点和高频细节
- 道具模型材质命名（游戏会识别）：A=主墙/主体，B=屋顶/布篷/树冠，C=木饰/主木色（这三个会被游戏按场景重新着色）；固定材质名：wood, wood_dark, metal, gold, stone, stone_dark, cloth, rope, sack, wheat, soil, leaf, flower_r/y/w/p, red, glass, lamp, water, flame

## 天空与远景 (sky)

| 键 | 名称 | HEX |
|---|---|---|
| sky_zenith | 天顶蓝 | `#4f86d8` |
| sky_upper | 上空蓝 | `#7fb0ea` |
| sky_horizon | 地平线 | `#c4dfef` |
| cloud | 云白 | `#f7f9fc` |
| cloud_shade | 云影 | `#b9c8dc` |
| haze_far | 最远山（雾蓝） | `#9fb4cf` |
| haze_mid | 远山 | `#7f9cbf` |
| hill_near | 近处林山 | `#5f8a6a` |
| snow | 雪顶 | `#f2f5f8` |
| snow_shade | 雪影 | `#c8d4e6` |

## 草地 (grass)

| 键 | 名称 | HEX |
|---|---|---|
| grass_root | 草根暗部 | `#27532a` |
| grass_base | 草基色 | `#3a7643` |
| grass_mid | 草中段 | `#5f8433` |
| grass_lit | 受光草 | `#8ead48` |
| grass_tip | 草尖高光 | `#b6cf62` |
| grass_warm | 暖黄草斑 | `#c7c56a` |
| grass_cool | 冷绿草斑 | `#68945c` |
| grass_dry | 干草地 | `#a9a35a` |

## 树木植被 (foliage)

| 键 | 名称 | HEX |
|---|---|---|
| leaf_dark | 阔叶暗部 | `#24502c` |
| leaf_mid | 阔叶中 | `#3f7a3a` |
| leaf_light | 阔叶亮 | `#6fa04a` |
| leaf_hi | 阔叶高光 | `#a6c95c` |
| pine_dark | 针叶暗 | `#1f4430` |
| pine_mid | 针叶中 | `#2f5e3e` |
| pine_light | 针叶亮 | `#4f7f4c` |
| birch_leaf | 桦叶 | `#8fbf4a` |
| bark | 树皮 | `#5a3f2a` |
| bark_light | 树皮亮 | `#7a5a3c` |
| birch_bark | 桦树皮 | `#e6e1d6` |
| moss | 苔藓 | `#6f8a4a` |

## 土地·岩石·水 (ground)

| 键 | 名称 | HEX |
|---|---|---|
| dirt_dark | 土路暗 | `#6f5236` |
| dirt | 土路 | `#96714c` |
| dirt_light | 土路亮 | `#b79469` |
| pebble | 碎石 | `#cdb894` |
| sand | 沙地 | `#c3b07a` |
| sand_light | 亮沙 | `#e2d3a2` |
| rock_shadow | 岩石暗 | `#8a8072` |
| rock | 岩石（米灰） | `#b3a894` |
| rock_light | 岩石亮 | `#d4cbb6` |
| water_deep | 深水 | `#2f6f9a` |
| water | 水 | `#4f9cc0` |
| water_shallow | 浅水 | `#7cc7d6` |
| foam | 浪花 | `#e8f6f8` |

## 野花 (flower)

| 键 | 名称 | HEX |
|---|---|---|
| flower_w | 白花 | `#fff6e8` |
| flower_y | 黄花 | `#ffd23f` |
| flower_pink | 粉花 | `#f28fb0` |
| flower_p | 紫花 | `#a98be8` |
| flower_r | 红花 | `#e8504a` |
| flower_b | 蓝花 | `#6f9be8` |

## 建筑：墙面与石材 (masonry)

| 键 | 名称 | HEX |
|---|---|---|
| plaster | 奶油灰泥 | `#efe6d2` |
| plaster_white | 暖白墙 | `#f4eee2` |
| plaster_ochre | 赭黄墙 | `#e3cf9e` |
| plaster_rose | 浅玫墙 | `#ead2c4` |
| stone_light | 浅石 | `#cdc7c1` |
| stone | 石材 | `#b3aca2` |
| stone_dark | 深石 | `#8e877a` |
| foundation | 墙基 | `#6f6a62` |
| cobble | 石板路 | `#9e9a95` |
| cobble_joint | 石缝 | `#6f6a62` |

## 建筑：屋顶与饰件 (roof)

| 键 | 名称 | HEX |
|---|---|---|
| slate_dark | 石板瓦暗 | `#2f4462` |
| slate | 石板瓦蓝 | `#435a79` |
| slate_light | 石板瓦亮 | `#536e96` |
| terracotta_dark | 赤陶暗 | `#8a3a26` |
| terracotta | 赤陶瓦 | `#b8553a` |
| terracotta_light | 赤陶亮 | `#d0764a` |
| copper | 铜绿 | `#5a9886` |
| copper_light | 铜绿亮 | `#7fb7a4` |
| thatch | 茅草 | `#c8a868` |
| thatch_dark | 茅草暗 | `#9c7e48` |
| timber | 木构架 | `#4a3020` |
| glass | 窗玻璃 | `#3f5f86` |
| window_glow | 夜窗光 | `#ffd98a` |

## 道具：木材 (wood)

| 键 | 名称 | HEX |
|---|---|---|
| wood_pale | 浅木 | `#c49a68` |
| wood_honey | 蜂蜜木 | `#a5805f` |
| wood | 中木 | `#856043` |
| wood_dark | 深木框 | `#5a3a24` |
| wood_darkest | 最深木 | `#3a2616` |
| wood_weathered | 风化木 | `#8f8476` |
| wood_red | 红漆木 | `#8a3a2a` |
| wood_green | 绿漆木 | `#3f6a4a` |
| wood_blue | 蓝漆木 | `#3f5a7a` |

## 道具：金属·绳·布 (metal)

| 键 | 名称 | HEX |
|---|---|---|
| iron | 铁件 | `#3c3a40` |
| iron_light | 铁高光 | `#6c6a72` |
| rust | 锈 | `#8a4a2a` |
| bronze | 青铜/黄铜 | `#b8873a` |
| gold | 金饰 | `#d8b060` |
| rope | 麻绳 | `#b89a68` |
| burlap | 麻袋 | `#c4a676` |
| burlap_dark | 麻袋暗 | `#9a7f52` |
| linen | 亚麻布 | `#efe4cc` |
| royal_blue | 皇家蓝布 | `#2a4f9a` |
| crimson | 绯红布 | `#a8342c` |
| wine | 酒红 | `#6a2c22` |
| forest_cloth | 森绿布 | `#3f6a3a` |
| mustard | 芥黄布 | `#d6a83a` |
| lavender | 淡紫布 | `#9a86c8` |

## 道具：食物·陶器 (produce)

| 键 | 名称 | HEX |
|---|---|---|
| apple | 红苹果 | `#d0382c` |
| apple_green | 青苹果 | `#9cc040` |
| pumpkin | 南瓜 | `#e0802c` |
| wheat | 麦穗/干草 | `#e2c460` |
| bread | 面包 | `#c8883c` |
| grape | 葡萄 | `#6a3f7a` |
| cheese | 奶酪 | `#f0c858` |
| pot_terracotta | 陶罐 | `#c06a42` |
| pot_glazed | 釉陶蓝 | `#5b7fb0` |
| soil | 泥土 | `#5a3e28` |

## 光照与氛围 (light)

| 键 | 名称 | HEX |
|---|---|---|
| sun | 日光 | `#fff4e0` |
| ambient | 天光环境 | `#a9c6ea` |
| shadow | 阴影色调 | `#394550` |
| bounce | 草地反光 | `#7da050` |
| fog | 雾 | `#c4dfef` |
| dusk | 黄昏 | `#ffb070` |
| night | 夜空 | `#1c2a4a` |
| lantern | 灯火 | `#ffc870` |
| magic | 魔法蓝 | `#80c0ff` |
| darkest | 最暗 | `#1e2522` |

## UI (ui)

| 键 | 名称 | HEX |
|---|---|---|
| ui_parchment | 羊皮纸 | `#f0e8d8` |
| ui_panel | 深色面板 | `#2a2418` |
| ui_gold | 金色描边 | `#e8c27a` |
| ui_accent | 高亮金 | `#ffd76a` |
| ui_text_dark | 深字 | `#3a2412` |
| hp | 生命 | `#e04848` |
| mana | 法力 | `#4f8de8` |
| xp | 经验 | `#9a6ae0` |
| q_common | 普通 | `#e0e0e0` |
| q_uncommon | 优秀 | `#5ad15a` |
| q_rare | 精良 | `#4f8de8` |
| q_epic | 史诗 | `#a86ae8` |
| q_legend | 传说 | `#ff9030` |
