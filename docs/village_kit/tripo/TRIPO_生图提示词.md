# Tripo 生图提示词（构件总图 / 家具总图）

在 Tripo 左侧「图片」面板里：模型选 **GPT Image 2.5**（或 Nano Banana Pro），比例选 **4:3**（构件）/ **3:2 或 4:3**（家具），数量 1–2，勾 **4K**（若有）。
**上传参考图**（面板里的参考图 / 图生图入口，如果有）：

| 总图 | 参考图（都在 `docs/city_ref/` 与 `docs/village_kit/tripo/`） |
|---|---|
| 构件总图 | `ref24_mm_l_cottage_redroof.webp`、`ref25_wow_night_cottage_bluroof.webp`、`ref27_wow_cottage_autumn.webp`，再加我渲染的版面参考 `village_tripo_parts_sheet.png` |
| 家具总图 | `ref26_wow_tavern_interior.webp`、`ref24_mm_l_cottage_redroof.webp`，再加 `village_furniture_sheet.png` |

> 我渲染的两张总图（Blender）可以当「版面 + 造型」参考：让 AI 保持**编号、数量、排布**不变，只把画风改成手绘。若 Tripo 面板没有参考图入口，就只贴文字提示词。
> 生成后把结果图发给我（或放进 `docs/village_kit/tripo/`），再用于 Tripo 的图转 3D。

---

## 提示词 A：复杂构件总图（T1–T13，参考图用 `village_tripo_parts_sheet.png` + `ref24` / `ref25` / `ref27` / `ref28`）

```
A building-component KIT SHEET for a fantasy village (modular pieces to be turned into 3D models). Hand-painted stylised fantasy village art in the manner of World of Warcraft Elwynn Forest cottages and the Mabinogi Mobile remake: warm salmon / cream plaster, dark brown half-timber, grey fieldstone, thick carved stone surrounds, red clay tile or blue slate, soft painterly colour, chunky proportions, matte.
Plain flat very light grey-white background, no scenery, no ground, no cast shadows. 5 columns x 3 rows grid, exactly 13 separate objects, each fully isolated in its own cell with wide empty margins, same three-quarter front-left isometric camera and soft studio light for all, every object one connected modular piece with real thickness. Under each object a small black numeral 1-13, no other text.
Objects in order:
1. roof dormer: small plaster dormer with wooden cross-mullion window, stone sill and its own little red-tile gable roof
2. tall rectangular fieldstone chimney stack with limestone cap and two clay chimney pots
3. arched stone-and-timber doorway with heavy iron-strapped plank door standing half open, worn stone threshold
4. entrance porch: two carved timber posts with curved brackets, small red-tile gable roof, hanging heraldic shield, two stone steps
5. projecting timber bay window with small panes, carved corbel brackets and little tiled shed roof
6. wide double plank barn door with iron strap hinges in a heavy timber frame
7. steep four-sided blue slate pyramid roof with wide eaves and an iron weathervane
8. climbing ivy with yellow flowers; round hedge bush with red berries; small wooden flower bed
9. rustic wooden picket fence section and matching gate
10. round fieldstone well with small tiled roof, rope winch and bucket
11. wooden market stall with tiled awning, counter and crates of goods
12. window unit: thick carved stone surround, cross-mullion glazing, green wooden shutters, flower box; no wall
13. wrought-iron sign bracket with chains and a wooden shop sign with a golden shield emblem
```

## 提示词 B：家具与室内小物总图（24 件）

```
A furniture and interior-props KIT SHEET for the interiors of those village buildings (cottage, tavern, smithy, shop, tailor, guard post, stable). Each numbered cell is one prop. Art style: hand-painted stylised fantasy village in the manner of the attached references (Mabinogi Mobile remake and World of Warcraft Elwynn cottages): warm salmon / cream plaster, dark brown half-timber framing, grey fieldstone bases, thick carved stone window surrounds, red clay tile or blue slate roofs, soft painterly colour variation, clean readable broad forms, chunky proportions, matte surfaces, no photorealism.
LAYOUT RULES (very important): plain flat very light grey-white background, no scenery, no ground plane, no cast shadows on the ground. 6 columns x 4 rows grid, exactly 24 separate objects, every object fully isolated and floating in its own cell with a wide empty margin so nothing touches or overlaps a neighbour. All objects are drawn at a similar on-screen size, from the SAME three-quarter front-left isometric camera angle with soft consistent studio light, each object is ONE single connected modular piece with real thickness (as a 3D modelling reference, no people, no text on the objects). Under each object put a small plain black numeral 1-24 (left to right, top to bottom) as its label, no other text.
The objects, in order:
1. long wooden tavern table with a red cloth runner, two mugs, a plate and a candle
2. long wooden bench
3. round three-legged wooden stool
4. wooden chair with a tall slatted back
5. iron-hooped oak barrel (upright)
6. wooden storage crate with plank edges
7. burlap sack tied at the top plus a second smaller sack leaning on it
8. big fieldstone fireplace with a timber mantel, a burning fire and stacked logs
9. round iron chandelier ring with eight lit candles
10. iron wall lantern bracket with a glowing candle lantern
11. tall wooden bookshelf with books and trinkets on four shelves
12. wooden shelf rack filled with bottles and jars
13. wooden bed with a blue blanket, white pillow and a carved headboard
14. long shop counter with a thick plank top and panelled front
15. wooden cupboard with two panelled doors and a moulded top
16. oval woven rug with a patterned cream border (flat, thin)
17. blacksmith anvil on an oak stump
18. blacksmith forge: stone hearth with glowing coals, hooded chimney breast and a leather bellows
19. wooden weapon rack with swords, axes and a shield
20. straw training dummy on a wooden post with crossbar and a wooden base
21. tailor mannequin in a red dress plus a stack of colourful cloth bolts
22. horse stall partition with a hay feeder and a small hay pile
23. hanging iron pot rack with three cooking pots and a ladle
24. framed painting and a heraldic shield wall plaque, plus a small potted plant
```

## 若 AI 把物体糊在一起 / 数量不对

- 把比例改 16:9 并去掉「4K」，或把清单拆成两张（前 10 件 / 后 10 件），分别生成再拼。
- 保底：直接用我的 Blender 渲染总图（已是 20 / 24 件、编号正确）喂 Tripo 的图转 3D。
