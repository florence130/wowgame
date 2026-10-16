# 晴岚港 · Tripo3D 精细模型需求

> 用途：把白盒地标替换为精细模型。每条包含 **内容名 / 游戏内规格 / Tripo3D 文字描述 / 视图**。
> 视图图片在 `docs/tripo_views/`，由 `tests/gallery.tscn -- mode=views` 从当前白盒自动渲染（正视、侧视、俯视为正交投影，另附一张透视图）。
> 视图只表示**比例、轮廓和部件位置**；材质、细节以文字描述为准。白盒改了以后重跑一次即可更新视图。

> **2026-10-05 更新**：按用户要求，大多数建筑与场景道具改为用 Blender 脚本制作（`tools/blender/build_models.py`）。
> 已由 Blender 完成、**不需要 Tripo** 的：联排住宅（第 13 项）、行会会馆（第 14 项）、港口仓库（第 17 项）的同类建筑 hall、运河石拱桥（第 23 项）、
> 以及木筋农舍、塔楼、城墙、教堂、码头栈桥、街灯、树、木箱木桶推车等道具。
> Tripo 只建议用于造型复杂、程序化难以表现的地标：迎海女神像、大教堂、市政厅、歌剧院、魔法师行会尖塔、飞空艇、船只。
> **2026-10-05 再更新**：以上地标也已有 Blender 版本（`tools/blender/build_landmarks.py`），游戏可完整运行；
> Tripo 版本现在属于"精修替换"，需要更高细节时再做，优先级以迎海女神像（人物造型）最高。

---

## 0. 通用要求（每个模型都适用）

| 项 | 要求 |
|---|---|
| 美术风格 | 风格化低多边形 + 手绘贴图，参考《洛奇 M》的柔和明快色调；不要写实、不要 PBR 金属感过强 |
| 主色调 | 白色（墙体）、海蓝色（屋顶/穹顶）、米色（基座/装饰带）；点缀金色（尖顶、徽记）、以太蓝紫色（魔法发光件） |
| 气质关键词 | 开放、港口、海运、商业、自由、魔法、魔导科学、维多利亚 |
| 输出格式 | GLB（带贴图），单位：米 |
| 原点与朝向 | 原点在模型**底面中心**；**正面（主入口）朝向 -Z**（Godot 前方）。Tripo 生成时正面朝镜头即可，导入时再旋转 |
| 尺寸 | 按下表"游戏内尺寸"缩放；允许 ±10% |
| 面数预算 | 地标 8k–20k 三角面；普通建筑 3k–6k；船 6k–12k；小件 < 2k |
| 碰撞 | 不需要在模型里做；游戏内用简化碰撞盒 |
| 发光件 | 以太水晶、灯塔灯室等单独成一个网格（材质名以 `_emit` 结尾），方便在 Godot 里加自发光 |

**Tripo3D 文字描述通用后缀**（每条描述末尾都加上）：

```
stylized low-poly game asset, hand-painted texture, white walls, sea-blue roofs, beige stone trim, gold accents, Victorian seaside city with magitech details, clean silhouette, single object, no ground, front view facing camera
```

---

## 1. 迎海女神像（城市地标）

- **位置**：内港南防波堤尖端，面朝大海（西）
- **游戏内尺寸**：总高 44 m；三层八角基座直径约 18 m
- **白盒类型**：`Landmark.goddess`

**Tripo3D 文字描述**

```
A colossal guardian goddess statue welcoming ships, 44 meters tall, standing on a three-tier octagonal white stone pedestal with gold rim posts. She wears long flowing robes and a hood, has large feathered wings spread behind her, her right arm raised high holding a glowing diamond-shaped aether crystal, her left hand holding a golden navigator's compass ring. Calm, protective expression, marble white with subtle sea-blue drapery shading.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/goddess_front.png) | ![](tripo_views/goddess_side.png) | ![](tripo_views/goddess_top.png) | ![](tripo_views/goddess_persp.png) |

---

## 2. 晴岚灯塔

- **位置**：内港北防波堤尖端
- **游戏内尺寸**：塔身直径 6 m，塔高 30 m（含灯室与穹顶约 36 m）
- **白盒类型**：`Landmark.beacon`

**Tripo3D 文字描述**

```
A tall tapering seaside lighthouse, white tower with sea-blue horizontal bands, wide stone base, small arched windows spiraling up, a dark iron gallery balcony with railing, a glass lantern room containing a large glowing aether crystal instead of a flame, topped with a small sea-blue dome and gold finial.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/beacon_front.png) | ![](tripo_views/beacon_side.png) | ![](tripo_views/beacon_top.png) | ![](tripo_views/beacon_persp.png) |

---

## 3. 钟塔

- **位置**：市政广场东北角
- **游戏内尺寸**：塔身 10×10 m，钟面以下 34 m，总高约 53 m
- **白盒类型**：`Landmark.clock_spire`

**Tripo3D 文字描述**

```
A Victorian Gothic clock tower like a smaller Big Ben, square beige stone shaft with corner buttresses and decorative bands, four large ornate white clock faces with gold rims and black Roman numerals, an open belfry level with tall arched openings, a steep sea-blue pyramidal spire with four corner pinnacles and a gold finial, arched wooden door at the base.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/clock_spire_front.png) | ![](tripo_views/clock_spire_side.png) | ![](tripo_views/clock_spire_top.png) | ![](tripo_views/clock_spire_persp.png) |

---

## 4. 晴岚港大教堂

- **位置**：城南教堂区，正面朝北
- **游戏内尺寸**：宽 36 m × 中殿高 22 m × 长 64 m；双塔高约 58 m
- **白盒类型**：`Landmark.cathedral`

**Tripo3D 文字描述**

```
A grand white Gothic-Renaissance cathedral, twin west-front bell towers with tall sea-blue conical spires and gold crosses, a large round rose window with gold tracery between the towers, three arched portals, a long nave with side aisles and flying buttresses topped by small pinnacles, a transept crossing crowned by a sea-blue ribbed dome with lantern, a rounded apse at the back, tall pointed stained-glass windows.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/cathedral_front.png) | ![](tripo_views/cathedral_side.png) | ![](tripo_views/cathedral_top.png) | ![](tripo_views/cathedral_persp.png) |

---

## 5. 市政厅

- **位置**：市政广场北侧，正面朝南
- **游戏内尺寸**：宽 64 m × 主体高 14 m × 深 30 m；中央穹顶顶高约 38 m
- **白盒类型**：`Landmark.civic_hall`

**Tripo3D 文字描述**

```
A neoclassical city hall, wide symmetrical white building, central block with a tall drum and large sea-blue ribbed dome with lantern, two long side wings with mansard roofs and rows of arched windows, small domed corner turrets, a grand front portico of eight white columns under a triangular pediment with a gold city emblem, broad stone stairs leading up to the entrance.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/civic_hall_front.png) | ![](tripo_views/civic_hall_side.png) | ![](tripo_views/civic_hall_top.png) | ![](tripo_views/civic_hall_persp.png) |

---

## 6. 晴岚歌剧院

- **位置**：主大道南侧、运河以北
- **游戏内尺寸**：宽 44 m × 高 18 m × 深 40 m；穹顶顶高约 40 m
- **白盒类型**：`Landmark.opera`

**Tripo3D 文字描述**

```
An ornate Victorian opera house, white facade with a ground-floor arcade of round arches, an upper loggia of paired columns with tall arched windows, rooftop statues and a golden lyre emblem above the entrance, a large sea-blue copper dome with gold ribs behind the facade, a tall stage fly-tower at the rear, wide front steps.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/opera_front.png) | ![](tripo_views/opera_side.png) | ![](tripo_views/opera_top.png) | ![](tripo_views/opera_persp.png) |

---

## 7. 魔法师行会尖塔

- **位置**：魔法区（城西北，飞空艇高地下方）
- **游戏内尺寸**：塔基 12 m，塔高 56 m（含水晶约 72 m）；附属学院 26×7×22 m
- **白盒类型**：`Landmark.mage_tower`

**Tripo3D 文字描述**

```
A slender octagonal wizard tower for a mages' guild, pale lavender-white stone tapering upward in four tiers separated by sea-blue rings, arched windows on every tier, a tall pointed sea-blue spire, a large floating violet aether crystal hovering above the spire tip, three glowing rune rings orbiting the tower at different heights, a low two-story academy annex with a sea-blue hip roof at its base.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/mage_tower_front.png) | ![](tripo_views/mage_tower_side.png) | ![](tripo_views/mage_tower_top.png) | ![](tripo_views/mage_tower_persp.png) |

---

## 8. 传送大厅（圆厅）

- **位置**：市政广场西侧
- **游戏内尺寸**：直径 30 m，柱廊高 12 m；玻璃穹顶顶高约 28 m
- **白盒类型**：`Landmark.rotunda`

**Tripo3D 文字描述**

```
A circular magitech teleportation hall, white rotunda ringed by a colonnade of slender columns, tall arched windows, a large transparent glass dome with gold ribs and a gold finial, inside under the dome a giant upright golden portal ring with a swirling cyan magic surface on a raised round dais, a wide open entrance on the front.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/rotunda_front.png) | ![](tripo_views/rotunda_side.png) | ![](tripo_views/rotunda_top.png) | ![](tripo_views/rotunda_persp.png) |

---

## 9. 公共浴池

- **位置**：主大道西段北侧（近北港）
- **游戏内尺寸**：36 × 9 × 20 m；中央穹顶顶高约 22 m
- **白盒类型**：`Landmark.bathhouse`

**Tripo3D 文字描述**

```
A public bathhouse in Roman-Victorian style, long low beige building with three sea-blue domes (the middle one larger with a lantern), rows of tall arched windows, a small columned entrance portico, gentle steam rising from roof vents.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/bathhouse_front.png) | ![](tripo_views/bathhouse_side.png) | ![](tripo_views/bathhouse_top.png) | ![](tripo_views/bathhouse_persp.png) |

---

## 10. 公共医院

- **位置**：教堂区东侧
- **游戏内尺寸**：40 × 12 × 24 m（H 形平面）
- **白盒类型**：`Landmark.hospital`

**Tripo3D 文字描述**

```
A Victorian public hospital, H-shaped white building with two long gabled wings and a central entrance block with sea-blue hip roof, a large round emblem with a sea-blue cross above the door, a covered entrance canopy on thin columns, rows of tall sash windows.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/hospital_front.png) | ![](tripo_views/hospital_side.png) | ![](tripo_views/hospital_top.png) | ![](tripo_views/hospital_persp.png) |

---

## 11. 海运客运站

- **位置**：北港区岸边
- **游戏内尺寸**：30 × 12 × 34 m
- **白盒类型**：`Landmark.terminal`

**Tripo3D 文字描述**

```
A Victorian ferry terminal, white stone front building with arched windows and a large round clock under a small gable, behind it a long arched cast-iron and glass train-shed style waiting hall, and a waterside canopy on slender dark iron posts for boarding passengers.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/terminal_front.png) | ![](tripo_views/terminal_side.png) | ![](tripo_views/terminal_top.png) | ![](tripo_views/terminal_persp.png) |

---

## 12. 东北区市场大厅

- **位置**：东北区市场北侧
- **游戏内尺寸**：24 × 10 × 40 m
- **白盒类型**：`Landmark.market_hall`

**Tripo3D 文字描述**

```
A Victorian covered market hall, long beige brick side walls with large arched windows, a barrel-vaulted glass roof on dark cast-iron arches, a decorative front gable with a big round fan window and a wide entrance, market sign above the door.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/market_hall_front.png) | ![](tripo_views/market_hall_side.png) | ![](tripo_views/market_hall_top.png) | ![](tripo_views/market_hall_persp.png) |

---

## 13. 维多利亚联排住宅（城市住宅主体，需 4 个变体）

- **位置**：全城街道两侧（约 245 栋，复用 4 个变体 × 换色）
- **游戏内尺寸**：宽 9.5 / 11.5 m × 高 10.5 / 13.5 / 16.5 m × 深 10 / 11.5 m（可做一个基础尺寸，游戏内缩放）
- **白盒类型**：`Landmark.rowhouse`（variant 0 平顶山墙 / 1 角楼 / 2 凸窗 / 3 双山墙）
- **贴图要求**：墙面与窗框颜色分开（窗框色在游戏内换色：蓝 / 红 / 青 / 金 / 紫）

**Tripo3D 文字描述（变体 1：角楼）**

```
A narrow three-story Victorian seaside townhouse, white stucco upper floors over a beige stone ground floor, horizontal white cornice bands between floors, tall arched sash windows with colored frames, a sea-blue mansard roof with small dormer windows and two chimneys, a round corner turret with a pointed sea-blue cone roof, a front door with stone steps.
```

其他变体把描述中 "a round corner turret …" 替换为：
- 变体 0：`a flat parapet front with simple rectangular windows`
- 变体 2：`two full-height white bay windows on the front facade`
- 变体 3：`two small decorative front gables on the roofline`

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/rowhouse_front.png) | ![](tripo_views/rowhouse_side.png) | ![](tripo_views/rowhouse_top.png) | ![](tripo_views/rowhouse_persp.png) |

---

## 14. 行会会馆（母版，6 处复用）

- **使用处**：冒险者公会（30×16×24）、锻铁匠行会、精工行会、学者行会、烹饪师行会、社会保障局（约 22×13×18）
- **白盒类型**：`Landmark.guildhouse`
- **差异化**：正门山墙上的圆形徽记 + 两侧竖旗颜色不同；锻铁匠多两根冒烟的烟囱，精工有旋转金齿轮，学者有书卷雕饰

**Tripo3D 文字描述（母版）**

```
A Victorian guild hall, two-story building with a beige stone ground floor and white upper floor, steep sea-blue gable roof, a tall white central gabled entrance facade with a large round guild emblem medallion framed in gold, two long vertical guild banners on the facade, rows of arched windows, a round corner tower with a pointed sea-blue roof, a big arched wooden double door.
```

徽记分别建议：冒险者公会＝交叉剑与罗盘（蓝）；锻铁匠＝铁锤与铁砧（红）；精工＝齿轮与以太回路（金）；学者＝翻开的书与羽毛笔（紫）；烹饪师＝厨师帽与汤勺（橙）；社会保障局＝相握的双手（浅蓝）。

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/guildhouse_front.png) | ![](tripo_views/guildhouse_side.png) | ![](tripo_views/guildhouse_top.png) | ![](tripo_views/guildhouse_persp.png) |

---

## 15. 三桅商船

- **位置**：北港（商船）、南港（货船，换帆色）、港外锚地、船厂船台
- **游戏内尺寸**：宽 7–8 m × 长 32–36 m；主桅高约 26 m
- **白盒类型**：`Landmark.galleon`

**Tripo3D 文字描述**

```
A three-masted merchant sailing ship, wooden hull painted dark brown with a sea-blue stripe along the side, raised stern castle with a row of cabin windows, bowsprit at the front, three masts with stacked square white sails, small blue pennants on the mast tops, ropes and rigging simplified.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/galleon_front.png) | ![](tripo_views/galleon_side.png) | ![](tripo_views/galleon_top.png) | ![](tripo_views/galleon_persp.png) |

---

## 16. 魔导蒸汽客轮

- **位置**：北港客运码头、港外锚地
- **游戏内尺寸**：宽 9–10 m × 长 38–44 m
- **白盒类型**：`Landmark.steamship`

**Tripo3D 文字描述**

```
A magitech paddle steamer passenger ship, dark navy hull, two white passenger decks with rows of round portholes, sea-blue deck trim, two tall sea-blue funnels with gold bands and faint cyan aether glow at their base, large side paddle wheels in white housings, a small flagpole with a blue flag.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/steamship_front.png) | ![](tripo_views/steamship_side.png) | ![](tripo_views/steamship_top.png) | ![](tripo_views/steamship_persp.png) |

---

## 17. 港口仓库

- **位置**：南港区（3 栋）、港口船舶区造船厂
- **游戏内尺寸**：18 × 10 × 28 m
- **白盒类型**：`Landmark.warehouse`

**Tripo3D 文字描述**

```
A large Victorian dockside warehouse, beige brick walls with darker brick pilasters, a steep dark sea-blue gable roof, a huge wooden plank cargo door on the front with a small gable above it, a raised stone loading platform, small high windows along the sides, painted number sign.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/warehouse_front.png) | ![](tripo_views/warehouse_side.png) | ![](tripo_views/warehouse_top.png) | ![](tripo_views/warehouse_persp.png) |

---

## 18. 城市排水出口

- **位置**：西侧海堤（南防波堤以南）
- **游戏内尺寸**：拱宽 6 m × 墙高 10 m × 墙长 18 m
- **白盒类型**：`Landmark.culvert`

**Tripo3D 文字描述**

```
A stone sea-wall section with a large arched drainage culvert outlet, heavy beige stone blocks, a dark round tunnel opening with a rusty iron grate, water flowing out of the opening, moss and algae near the bottom, a stone cornice on top.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/culvert_front.png) | ![](tripo_views/culvert_side.png) | ![](tripo_views/culvert_top.png) | ![](tripo_views/culvert_persp.png) |

---

## 19. 飞空艇

- **位置**：西北高地飞空艇站
- **游戏内尺寸**：气囊长 26 m
- **白盒类型**：`Prop.airship`

**Tripo3D 文字描述**

```
A whimsical magitech airship, large white elongated balloon envelope with sea-blue fabric bands and fins, a wooden gondola cabin with round windows hanging underneath, two side propellers on brass arms, small aether crystal engines glowing cyan.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/airship_front.png) | ![](tripo_views/airship_side.png) | ![](tripo_views/airship_top.png) | ![](tripo_views/airship_persp.png) |

---

## 20. 东城门（含门楼）与城墙塔楼

- **位置**：东城门；城墙转角共 16 座塔楼
- **游戏内尺寸**：城门开口宽 14 m、高 10 m；塔楼直径 11 m、高 18–22 m
- **白盒类型**：`Prop.gate`、`Prop.tower`

**Tripo3D 文字描述（城门）**

```
A grand white stone city gatehouse, a wide round-arched gateway flanked by two square towers with sea-blue pyramid roofs, crenellated top, sea-blue banners with a gold sun emblem hanging beside the arch, a raised iron portcullis, city name plaque above the arch.
```

**Tripo3D 文字描述（塔楼）**

```
A round white stone city wall tower, slightly tapered, crenellated gallery ring near the top, a pointed sea-blue conical roof with gold finial, small arrow-slit windows, a wooden door at the base.
```

| 城门正视 | 城门透视 | 塔楼正视 | 塔楼透视 |
|---|---|---|---|
| ![](tripo_views/gate_front.png) | ![](tripo_views/gate_persp.png) | ![](tripo_views/tower_front.png) | ![](tripo_views/tower_persp.png) |

---

## 21. 中央车站

- **位置**：城中南部
- **游戏内尺寸**：34 × 12 × 34 m；钟楼高约 24 m
- **白盒类型**：`Prop.station`

**Tripo3D 文字描述**

```
A Victorian central railway station, beige stone front facade with a huge semicircular glass arch window, flanking towers with small domes, a tall side clock tower with a sea-blue pyramid roof, a long arched glass-and-iron train shed behind the facade, a row of columns at the entrance.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/station_front.png) | ![](tripo_views/station_side.png) | ![](tripo_views/station_top.png) | ![](tripo_views/station_persp.png) |

---

## 22. 公共图书馆 / 交易所（大型公共建筑母版）

- **位置**：公共图书馆（魔法区，34×12×22）、交易所（东北区市场，24×10×16）
- **白盒类型**：`Prop.hall`（variant 1 穹顶）

**Tripo3D 文字描述**

```
A neoclassical public building, white stone block with a front row of four tall columns, tall arched windows along the facade, a central sea-blue dome with a gold lantern on top, wide entrance doors, engraved name panel above the entrance.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/hall_front.png) | ![](tripo_views/hall_side.png) | ![](tripo_views/hall_top.png) | ![](tripo_views/hall_persp.png) |

---

## 23. 运河石拱桥

- **位置**：运河与街道交叉处（自动生成，约 5 座）
- **游戏内尺寸**：宽 10–13 m × 长 22 m，桥面高出河床约 8 m
- **白盒类型**：`Prop.bridge`

**Tripo3D 文字描述**

```
A small arched stone canal bridge, pale beige stone, one wide round arch underneath, low white stone balustrade railings on both sides, two decorative lamp posts at the ends.
```

| 正视 | 侧视 | 俯视 | 透视 |
|---|---|---|---|
| ![](tripo_views/bridge_front.png) | ![](tripo_views/bridge_side.png) | ![](tripo_views/bridge_top.png) | ![](tripo_views/bridge_persp.png) |

---

## 优先级建议

| 优先级 | 模型 | 理由 |
|---|---|---|
| P0 | 迎海女神像、钟塔、大教堂、市政厅、魔法师行会尖塔 | 城市天际线与宣传图的核心识别点 |
| P1 | 维多利亚联排住宅 ×4、行会会馆母版、三桅商船 | 出现次数最多，替换后观感提升最大 |
| P2 | 歌剧院、传送大厅、灯塔、客运站、蒸汽客轮、城门塔楼 | 区域地标 |
| P3 | 其余 | 白盒已可用 |
