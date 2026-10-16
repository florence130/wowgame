# 建筑重设计 v2 —— Tripo3D 制作清单

生成日期：2026-10-05。每个建筑一个文件夹：`hero.png`（3/4 透视主图，**建议作为 Tripo 图生模型的输入**）、`front/right/back/left.png`（四向正交视图，用于多视图生成或比对）、`sheet.jpg`（汇总）。总览：`_index.jpg`。

## 统一美术规范

- 风格：洛奇M / 勇者斗恶龙X 式手绘卡通，比例略夸张，厚重的挑檐与略下垂的屋脊、粗木梁和托架、圆润的石砌基座，手绘纹理，带花箱、吊灯、藤蔓与苔藓等小细节。
- 色板：晴岚港以蓝灰石板瓦 + 奶油灰泥 + 深棕木筋 + 砂岩为主，点缀红砖、铜绿和条纹遮阳篷；晨露谷以暖橙/红陶瓦、金色茅草、深棕木构为主。
- 朝向：**正门朝 -Z（Godot 前方，Blender +Y）**，原点在底面中心，单位米。
- 面数建议：住宅/店铺 8k–15k 三角面，地标 20k–40k，道具 1k–3k；导出 GLB，贴图 1024（地标 2048）。
- 放到 `E:/wowgame/assets/models/tripo/<id>.glb`，我会按下表尺寸自动缩放并替换场景中对应 kind 的白盒。

## 清单

| # | id | 名称 | 区域 | 替换的 kind | 尺寸 宽×高×深 (m) |
|---|---|---|---|---|---|
| 1 | `city_townhouse_a` | 城区联排住宅 A（木筋三层） | 晴岚港 | rowhouse | 10×14×11 |
| 2 | `city_townhouse_b` | 城区联排住宅 B（石砌店面） | 晴岚港 | rowhouse | 10×13×11 |
| 3 | `city_townhouse_c` | 城区联排住宅 C（红砖阳台） | 晴岚港 | rowhouse | 10×13×11 |
| 4 | `city_corner_tower` | 转角塔楼公寓 | 晴岚港 | corner | 12×16×12 |
| 5 | `shop_general` | 道具店 / 杂货铺 | 晴岚港 | shop_general | 11×11×10 |
| 6 | `shop_smithy` | 武器铺 / 铁匠铺 | 晴岚港 | shop_smithy | 12×10×11 |
| 7 | `shop_potion` | 药剂店 / 魔法道具店 | 晴岚港 | shop_potion | 10×13×10 |
| 8 | `shop_florist` | 花店 / 面包房 | 晴岚港 | shop_florist | 9×10×9 |
| 9 | `tavern` | 酒馆（塔楼酒馆） | 晴岚港 | tavern | 22×18×18 |
| 10 | `inn` | 旅店 | 晴岚港 | inn | 20×15×16 |
| 11 | `guild_adventurer` | 冒险者公会 | 晴岚港 | guild | 28×20×22 |
| 12 | `bank_exchange` | 银行 / 交易所 | 晴岚港 | bank | 26×18×20 |
| 13 | `city_hall` | 市政厅 | 晴岚港 | civic_hall | 44×22×26 |
| 14 | `cathedral` | 大教堂 | 晴岚港 | cathedral | 32×36×60 |
| 15 | `grand_station` | 中央车站 | 晴岚港 | grand_station | 56×24×34 |
| 16 | `mage_tower` | 魔法师行会塔 | 晴岚港 | mage_tower | 14×50×14 |
| 17 | `warehouse` | 港口仓库 | 晴岚港 | warehouse | 18×12×28 |
| 18 | `lighthouse` | 灯塔 | 晴岚港 | beacon | 8×32×8 |
| 19 | `tholos` | 城市公园圆亭 | 晴岚港 | tholos | 20×10×20 |
| 20 | `vale_cottage_thatch` | 晨露谷茅草农舍 | 晨露谷 | house | 10×7×9 |
| 21 | `vale_cottage_timber` | 金穗镇木筋小屋 | 晨露谷 | house | 12×8×10 |
| 22 | `vale_barn` | 农场谷仓 | 晨露谷 | barn | 14×10×18 |
| 23 | `vale_windmill` | 风车磨坊 | 晨露谷 | windmill | 8×16×8 |
| 24 | `vale_abbey_chapel` | 晨钟修道院礼拜堂 | 晨露谷 | church | 16×18×28 |
| 25 | `vale_inn` | 金穗旅店 | 晨露谷 | inn | 16×11×14 |
| 26 | `prop_market_stall` | 市场摊位 | 通用 | stall | 4×3×3 |
| 27 | `prop_lamppost` | 街灯与旗帜 | 通用 | lamp2 | 2×6×1 |
| 28 | `prop_well_fountain` | 广场喷泉 | 通用 | fountain | 8×5×8 |

## 设计说明（英文描述可直接作为 Tripo 文本提示补充）

### 城区联排住宅 A（木筋三层） `city_townhouse_a`

![](city_townhouse_a/sheet.jpg)

narrow three-storey townhouse, stone ground floor with an arched wooden door and a small shop window, two upper floors of cream plaster with dark brown half-timber framing that projects slightly over the street, steep blue slate fish-scale tiled gable roof facing the street with one pointed dormer, tall stone chimney, window boxes with red and pink flowers, an iron lantern beside the door

### 城区联排住宅 B（石砌店面） `city_townhouse_b`

![](city_townhouse_b/sheet.jpg)

two-and-a-half storey stone townhouse with light sandstone block walls, ground floor shopfront with a large wooden-framed display window and a blue-and-white striped fabric awning, wooden shutters on the upper windows, blue slate mansard roof with two small round-topped dormers, carved wooden hanging shop sign, potted plants by the door

### 城区联排住宅 C（红砖阳台） `city_townhouse_c`

![](city_townhouse_c/sheet.jpg)

warm red-brown brick townhouse, white stone window frames and a white carved stone string course, a small wrought-iron balcony with potted flowers on the second floor, pink and white striped awning over a ground floor cafe window with a little table and chairs outside, dark green front door with an arched fanlight, blue slate roof with a white chimney

### 转角塔楼公寓 `city_corner_tower`

![](city_corner_tower/sheet.jpg)

corner apartment building with a round turret on its corner topped by a tall pointed blue slate cone roof with a golden finial, cream plaster walls, three floors of tall windows with green painted shutters, a green-painted wooden bay window, ground floor bakery with red awning and bread display, small balconies

### 道具店 / 杂货铺 `shop_general`

![](shop_general/sheet.jpg)

charming general goods shop, whitewashed rough stone walls, a big open shop counter under a red-and-cream striped awning piled with baskets of fruit, potions, rope and lanterns, steep green-grey moss-covered slate roof with a small pointed dormer, round attic window, wooden hanging sign on an iron bracket, barrels, crates and clay pots outside

### 武器铺 / 铁匠铺 `shop_smithy`

![](shop_smithy/sheet.jpg)

blacksmith and weapon shop, heavy dark stone walls with a big brick forge chimney glowing orange at its base, an open-sided timber workshop lean-to with an anvil, grindstone and weapon racks of swords and shields, dark brown timber upper floor, dark blue slate roof, hanging sign shaped like a crossed sword and hammer, coal sacks and barrels

### 药剂店 / 魔法道具店 `shop_potion`

![](shop_potion/sheet.jpg)

quirky alchemist potion shop, slightly crooked tall narrow building, lavender-tinted plaster and timber frame, round porthole window with colourful glowing bottles, drying herbs hanging from a beam, bulging bay window full of potion bottles, steep twisted purple-blue tiled roof with a small brass telescope and a crooked chimney puffing coloured smoke, hanging cauldron sign

### 花店 / 面包房 `shop_florist`

![](shop_florist/sheet.jpg)

small cosy flower shop, cream plaster walls covered in climbing ivy and flowering vines, ground floor with wooden flower stands and buckets of colourful flowers spilling onto the pavement, pink striped awning, small wooden balcony with a hanging basket, warm terracotta tiled roof, little bench beside the door

### 酒馆（塔楼酒馆） `tavern`

![](tavern/sheet.jpg)

lively fantasy tavern compound, a big round whitewashed stone tower with a wooden top storey and a tall conical brown shingle roof covered in ivy, attached to a two-storey half-timbered main hall with cream walls and brown timber framing, a smaller second round tower at the other end, a long red banner with a beer mug emblem hanging on the tower, outdoor bar counter with stools under a little shingled roof, stacked barrels, orange cloth awning, flower boxes

### 旅店 `inn`

![](inn/sheet.jpg)

large welcoming three-storey inn, stone ground floor with a wide arched entrance and lanterns, two half-timbered upper floors with long wooden balconies covered in flower boxes, many windows glowing warm, large blue slate roof with three gabled dormers, two tall chimneys, carved wooden sign with a bed and moon emblem, a small stable shelter on the side

### 冒险者公会 `guild_adventurer`

![](guild_adventurer/sheet.jpg)

grand adventurers guild hall, solid light stone ground floor with a big double wooden door under a heavy stone arch, carved shield crest above the door, two upper floors of timber framing with large windows, a tall central clock gable, a small square watchtower with a blue pennant flag on one corner, blue slate roofs, quest notice board covered in papers beside the entrance, banners with a sword and compass emblem

### 银行 / 交易所 `bank_exchange`

![](bank_exchange/sheet.jpg)

stately neoclassical bank and trade exchange, cream sandstone walls, wide front steps up to a portico of four fluted columns with a triangular pediment carved with a coin and scales emblem, tall arched windows, a small green copper dome with a gold finial on top, balustrade along the roof edge, gold lettered plaque, two iron lamp posts at the steps

### 市政厅 `city_hall`

![](city_hall/sheet.jpg)

grand city hall, long symmetrical facade of white stone and pale blue accents, central clock tower with a blue slate spire and gold clock face, arched arcade on the ground floor, two wings with tall windows and blue slate mansard roofs with dormers, flags flying, wide stairs and flower beds in front

### 大教堂 `cathedral`

![](cathedral/sheet.jpg)

majestic stylized cathedral, white and pale pink stone walls, sweeping dark blue roofs with soft curved flowing shapes and many pointed pinnacles, a tall ornate front portal with a glowing blue round crystal emblem trimmed in gold, tall narrow arched stained glass windows, rounded apse with layered roofs, grand double staircases leading to the entrance, small cypress trees

### 中央车站 `grand_station`

![](grand_station/sheet.jpg)

magnificent belle epoque railway station, cream sandstone facade, a huge central arched window with radiating iron mullions, two square towers with wide orange-red bracketed eaves and open belfry tops with dark domed caps, a large green-glass dome behind the centre, small green copper domes on the end pavilions, rows of arched windows with colourful doors, an iron and glass entrance canopy, a long glass barrel-vault train shed behind

### 魔法师行会塔 `mage_tower`

![](mage_tower/sheet.jpg)

tall slender wizard guild tower, pale lavender-white stone, spiralling upward with slight twist, several balconies, floating rune rings of glowing violet light around it, a pointed deep-blue roof with stars and a crescent finial, arched windows glowing purple, a small observatory dome halfway up, a stone base with a wide arched door and glowing crystals

### 港口仓库 `warehouse`

![](warehouse/sheet.jpg)

harbour warehouse, large barn-like building with tan stone base and weathered wooden plank upper walls, big double cargo doors, a wooden pulley hoist beam sticking out under the gable, orange terracotta tiled roof, stacked crates, barrels, rope coils and fishing nets outside

### 灯塔 `lighthouse`

![](lighthouse/sheet.jpg)

tall round seaside lighthouse with red and white horizontal stripes, a stone base with a small keeper's cottage with a blue roof attached, a glass lantern room with a glowing light, a black iron gallery railing, a red domed cap with a weather vane, sitting on rocks

### 城市公园圆亭 `tholos`

![](tholos/sheet.jpg)

round classical park pavilion, ring of ten white fluted ionic columns on circular stone steps, an open circular entablature ring on top overgrown with flowering wisteria and white blossoms, a small round fountain in the centre, flower beds between the columns

### 晨露谷茅草农舍 `vale_cottage_thatch`

![](vale_cottage_thatch/sheet.jpg)

cosy rural cottage, dark brown log and plank walls with cream plaster panels, a thick puffy golden-orange thatched roof with soft rounded edges hanging low over the walls, small square windows with wooden shutters, a wooden porch deck with barrels and a crate, a bench, a stone chimney

### 金穗镇木筋小屋 `vale_cottage_timber`

![](vale_cottage_timber/sheet.jpg)

charming village house, warm peach-orange plaster walls with dark brown timber framing, sandstone window surrounds, steep red clay tiled roof with a cross gable and small dormers, a stone chimney, climbing yellow flowering vines, round green bushes along the front, a small porch with a shield emblem above the door

### 农场谷仓 `vale_barn`

![](vale_barn/sheet.jpg)

big red-brown wooden farm barn with white trim, large double sliding doors, a hay loft door with a hay bale sticking out, a weathervane rooster on the ridge, weathered dark brown shingle roof, stone foundation, hay bales and a wooden cart beside it

### 风车磨坊 `vale_windmill`

![](vale_windmill/sheet.jpg)

chubby round stone windmill tower with cream plaster, a rounded conical thatched cap, four large wooden lattice sails with cream canvas, a small wooden door and window, sacks of flour and a wooden fence at the base

### 晨钟修道院礼拜堂 `vale_abbey_chapel`

![](vale_abbey_chapel/sheet.jpg)

small peaceful abbey chapel, cream stone walls, a square bell tower with an open belfry and a pointed blue slate spire, a round rose window over the arched wooden door, tall arched windows, buttresses, ivy on the walls, a small walled garden with flower beds

### 金穗旅店 `vale_inn`

![](vale_inn/sheet.jpg)

rustic village inn, stone ground floor and half-timbered upper floor with cream panels, wide overhanging red clay tiled roof, a covered wooden front porch with tables and a hanging lantern, a big carved wooden sign with a bowl of soup, flower boxes, stacked firewood, a horse trough

### 市场摊位 `prop_market_stall`

![](prop_market_stall/sheet.jpg)

wooden market stall with a striped red and cream fabric canopy, a counter covered with crates of fruit and vegetables, baskets, a small chalk price board, hanging garlic and herbs

### 街灯与旗帜 `prop_lamppost`

![](prop_lamppost/sheet.jpg)

tall ornate wooden and iron street lamp post with a hanging glass lantern on a curved bracket, and a long vertical dark green banner with a gold emblem hanging from it

### 广场喷泉 `prop_well_fountain`

![](prop_well_fountain/sheet.jpg)

round stone town square fountain with two tiers, carved fish spouting water, flowers planted around the rim, worn light stone with a little moss
