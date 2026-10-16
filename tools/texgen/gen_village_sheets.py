# 金穗镇村屋「构件总图 + 家具总图」（给 Tripo3D 一轮生成多个物品用）。
# 依赖 .local/texgen.env（TEX_API_BASE / TEX_API_KEY / TEX_IMAGE_MODEL），与 gen_concepts_v3.py 同一套调用。
#   py tools/texgen/gen_village_sheets.py [components|furniture|all]
# 输出 docs/village_kit/tripo/{village_components_sheet.png, village_furniture_sheet.png}（已存在则跳过，删除后重生成）
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen_concepts_v3 as g
from PIL import Image

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
REF = os.path.join(ROOT, "docs", "city_ref")
OUT = os.path.join(ROOT, "docs", "village_kit", "tripo")
os.makedirs(OUT, exist_ok=True)
TMP = os.path.join(OUT, "_refs")
os.makedirs(TMP, exist_ok=True)


def ref_png(name):
    """webp → 限宽 1280 的 png（接口只认 png / jpeg）"""
    src = [f for f in os.listdir(REF) if f.startswith(name) and f.endswith(".webp")][0]
    dst = os.path.join(TMP, name + ".png")
    if not os.path.exists(dst):
        im = Image.open(os.path.join(REF, src)).convert("RGB")
        im.thumbnail((1280, 1280))
        im.save(dst)
    return dst


STYLE = ("Art style: hand-painted stylised fantasy village in the manner of the attached references (Mabinogi Mobile remake and World of Warcraft Elwynn cottages): "
         "warm salmon / cream plaster, dark brown half-timber framing, grey fieldstone bases, thick carved stone window surrounds, red clay tile or blue slate roofs, "
         "soft painterly colour variation, clean readable broad forms, chunky proportions, matte surfaces, no photorealism.")

LAYOUT = ("LAYOUT RULES (very important): plain flat very light grey-white background, no scenery, no ground plane, no cast shadows on the ground. "
          "{cols} columns x {rows} rows grid, exactly {n} separate objects, every object fully isolated and floating in its own cell with a wide empty margin so nothing touches or overlaps a neighbour. "
          "All objects are drawn at a similar on-screen size, from the SAME three-quarter front-left isometric camera angle with soft consistent studio light, "
          "each object is ONE single connected modular piece with real thickness (as a 3D modelling reference, no people, no text on the objects). "
          "Under each object put a small plain black numeral {first}-{n} (left to right, top to bottom) as its label, no other text.")

COMPONENTS = [
    "red clay-tile gable roof section: a straight 4 m long roof segment with ridge cap and overhanging eave, thick tiles in varied reds",
    "blue-grey slate gable roof section: the same straight roof segment with scalloped slate tiles and a dark ridge cap",
    "gable end wall: triangular plaster gable with dark half-timber post, collar beam and diagonal braces, a round attic window and carved barge boards",
    "roof dormer: small plaster dormer with wooden-framed cross-mullion window, thick stone sill and its own little red-tile gable roof",
    "stone chimney: tall rectangular fieldstone chimney stack with a limestone cap and two clay pots",
    "plaster wall panel with a window: 3 m wide, salmon plaster, dark timber posts and rails, a window with thick stone surround, sill and green wooden shutters, flower box below",
    "plain half-timber wall panel: 3 m wide, cream plaster between dark timber posts and rails with two diagonal braces, no openings",
    "fieldstone foundation wall segment: 3 m long rough grey stone base course with a limestone cap strip, plus one stone corner quoin block stack",
    "white-plaster wall panel with a wooden-framed cross window and a small flower box, dark timber frame (Elwynn cottage style)",
    "arched front door unit: arched stone-and-timber doorway with a heavy plank door standing open, iron hinges, worn stone threshold",
    "entrance porch: two timber posts with curved brackets, a small red-tile gable roof, a hanging heraldic shield sign and two stone steps",
    "bay window oriel: projecting timber bay with small panes, carved corbel brackets underneath and a little tiled shed roof",
    "wall corner post: tall dark timber corner post with stone quoin blocks at the base and a short length of wall on both sides",
    "double barn / stable door: wide double plank door with iron strap hinges and an arched timber frame, one leaf slightly open",
    "stone tower segment with crenellated top: square grey fieldstone tower block with arrow slit, wooden balcony and a lantern bracket",
    "tower pyramid roof: steep four-sided blue slate pyramid roof with a small iron weathervane and wide eaves",
    "ivy and flower clump set: three separate foliage props on one base-less piece group: climbing ivy patch with yellow flowers, round green hedge bush with red berries, small flower bed",
    "wooden fence section with a gate: 3 m of rustic picket fence plus a matching single gate, weathered brown wood",
    "stone well: round fieldstone well with a small wooden roof, rope winch and bucket",
    "market stall: wooden stall with a striped red-and-cream canvas awning, a counter and a few crates of goods",
]

FURNITURE = [
    "long wooden tavern table with a red cloth runner, two mugs, a plate and a candle",
    "long wooden bench",
    "round three-legged wooden stool",
    "wooden chair with a tall slatted back",
    "iron-hooped oak barrel (upright)",
    "wooden storage crate with plank edges",
    "burlap sack tied at the top plus a second smaller sack leaning on it",
    "big fieldstone fireplace with a timber mantel, a burning fire and stacked logs",
    "round iron chandelier ring with eight lit candles",
    "iron wall lantern bracket with a glowing candle lantern",
    "tall wooden bookshelf with books and trinkets on four shelves",
    "wooden shelf rack filled with bottles and jars",
    "wooden bed with a blue blanket, white pillow and a carved headboard",
    "long shop counter with a thick plank top and panelled front",
    "wooden cupboard with two panelled doors and a moulded top",
    "oval woven rug with a patterned cream border (flat, thin)",
    "blacksmith anvil on an oak stump",
    "blacksmith forge: stone hearth with glowing coals, hooded chimney breast and a leather bellows",
    "wooden weapon rack with swords, axes and a shield",
    "straw training dummy on a wooden post with crossbar and a wooden base",
    "tailor mannequin in a red dress plus a stack of colourful cloth bolts",
    "horse stall partition with a hay feeder and a small hay pile",
    "hanging iron pot rack with three cooking pots and a ladle",
    "framed painting and a heraldic shield wall plaque, plus a small potted plant",
]


def prompt(kind, items, cols, rows):
    n = len(items)
    head = {"components": "A modular building-component KIT SHEET for a small fantasy village. Each numbered cell is one reusable construction piece that can be assembled into cottages, a tavern, a smithy, a guard tower and stables. ",
            "furniture": "A furniture and interior-props KIT SHEET for the interiors of those village buildings (cottage, tavern, smithy, shop, tailor, guard post, stable). Each numbered cell is one prop. "}[kind]
    lines = "\n".join("%d. %s" % (i + 1, t) for i, t in enumerate(items))
    return head + STYLE + "\n" + LAYOUT.format(cols=cols, rows=rows, n=n, first=1) + "\nThe objects, in order:\n" + lines


if __name__ == "__main__":
    which = sys.argv[1] if len(sys.argv) > 1 else "all"
    size = "3072x2048"
    if which in ("components", "all"):
        refs = [ref_png("ref24_mm_l_cottage_redroof"), ref_png("ref25_wow_night_cottage_bluroof"), ref_png("ref27_wow_cottage_autumn")]
        g.gen(prompt("components", COMPONENTS, 5, 4), os.path.join(OUT, "village_components_sheet.png"), refs, size)
    if which in ("furniture", "all"):
        refs = [ref_png("ref26_wow_tavern_interior"), ref_png("ref24_mm_l_cottage_redroof")]
        g.gen(prompt("furniture", FURNITURE, 6, 4), os.path.join(OUT, "village_furniture_sheet.png"), refs, size)
