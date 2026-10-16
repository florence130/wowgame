# 金穗镇设定图（2026-10-10 用户：自行处理金穗村全流程，遵循洛奇M 画面风格，PBR 高清化重置）。
# 提示词与 docs/金穗镇_设定图提示词.md 一致；风格参考：洛奇M 重制版截图（docs/city_ref ref20-22、docs/art_direction_v3/refs mm_*）。
#   py tools/texgen/gen_goldenear_concepts.py [id1,id2]   → docs/goldenear_concept/<id>.png（已存在则跳过，删除后可重出）
import os, sys, json, importlib.util
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
spec = importlib.util.spec_from_file_location("gc3", os.path.join(HERE, "gen_concepts_v3.py"))
gc3 = importlib.util.module_from_spec(spec); spec.loader.exec_module(gc3)
OUT = os.path.join(ROOT, "docs", "goldenear_concept")
CR = os.path.join(ROOT, "docs", "city_ref")
AR = os.path.join(ROOT, "docs", "art_direction_v3", "refs")
os.makedirs(OUT, exist_ok=True)


def ref(name):
    src = os.path.join(CR, name)
    if not name.endswith(".webp"):
        return src
    dst = os.path.join(OUT, "_ref_" + name.replace(".webp", ".jpg"))
    if not os.path.exists(dst):
        from PIL import Image
        Image.open(src).convert("RGB").save(dst, quality=92)
    return dst


MM = [ref("ref20_mm_remake_halftimber_shop.webp"), ref("ref21_mm_remake_lshape_house.webp"), ref("ref22_mm_old_town_and_gothic_night.webp")]
MM2 = [os.path.join(AR, "mm_rural_dof.jpg"), os.path.join(AR, "village_aerial.jpg"), os.path.join(AR, "mm_timber_square_dusk.jpg")]

# 风格段由 GPT（gpt-6.1-sol）看过 ref29 / ref30 两张洛奇M 实机图后写成（docs/goldenear_concept/mabi_style_gpt.json）；负面项并入同一段
_g = json.load(open(os.path.join(OUT, "mabi_style_gpt.json"), encoding="utf-8"))
STYLE = ("STYLE LOCK - the result must look like an in-engine screenshot of Mabinogi Mobile (洛奇M), exactly like the FIRST TWO attached images. " + _g["style"] +
         " AVOID: " + "; ".join(_g["negative"]) + ". No text, no watermark, no people. The attached images are STYLE references only - do not copy their layouts. ")
SHEET = ("Plain flat very light grey-white background, no ground, no cast shadows, wide empty margin around every object, same three-quarter front-left camera and soft studio light, "
         "each object one connected modular piece with real thickness, small black numerals under each object, no other text. ")

SHOTS = {
    "01_aerial": ("Concept art, high three-quarter aerial view of a small harvest fantasy village called Goldenear on a gentle green hill. In the middle a large circular cobblestone plaza "
                  "with a round three-tier stone fountain in the centre, eight iron street lamps around the rim, wooden benches, a stone well, two small striped market stalls and a glowing blue rune standing stone at the south edge. "
                  "Fourteen two-storey cottages and shops stand around the plaza radially, every front door facing the centre, each with its own curved dirt path to the plaza. "
                  "Largest: a half-timbered tavern with two wings and a hanging sign; an open vertical-plank blacksmith shed with a tall brick chimney and glowing forge; a general store; a tailor shop with red-white awning; "
                  "a small guard house with a stubby watch turret; a wide trainers' hall; a long stable with a hay loft; seven different homes. Roofs alternate red clay tile, blue-grey slate and golden thatch. Chimney smoke. "
                  "Around: golden wheat fields, vegetable plot, orchard trees, a small river on the east, forest edge, dirt roads leaving to hills. Warm late-afternoon light, long soft shadows.", MM2, "1536x1024"),
    "02_plaza": ("Concept art, eye-level view at the edge of a circular village plaza looking to the centre: round three-tier stone fountain with a plain carved stone ball finial (no wheat, no gold, no emblem, a generic reusable fountain), warm beige cobblestone with darker radial bands, "
                 "eight slender black wrought-iron street lamps with glass lanterns, a stone well with a little red-tile roof, wooden benches, a red-and-cream striped weapon stall with racks of swords and shields, "
                 "and a waist-high rune-carved standing stone with soft blue glow (teleport waystone) on a round stepped stone base. Behind: a half-timbered two-storey tavern with hanging sign and warm lit windows, "
                 "an open plank blacksmith shed with a brick chimney, a salmon-plaster house with red tile roof. Dirt paths join the plaza. Golden late-afternoon light, light chimney smoke, a few autumn leaves.", MM, "1536x1024"),
    "03_plan": ("Top-down orthographic map of a small fantasy village in hand-painted style: central circular cobblestone plaza with a round fountain, fourteen buildings arranged radially with front doors facing the plaza, each with a short curved dirt path to the plaza; "
                "larger tavern upper right, open blacksmith shed with chimney upper left, general store lower left, tailor shop with striped awning lower right, small guard house at the top, long stable far right, trainers' hall far left, seven smaller homes on the outer ring. "
                "Surrounding golden wheat fields, vegetable plots, orchard, trees, river on the east side, dirt roads leaving north and south. Roof colours alternate red tile, blue slate, golden thatch. Clean flat colours, soft shadows, no labels.", MM2[:2], "1024x1024"),
    "04_tavern": ("Building design sheet: front elevation, side elevation and three-quarter perspective of the same large fantasy village tavern, plain light grey-white background, no ground, no shadows. "
                  "Two-storey half-timbered inn, salmon plaster with dark brown timber frame and grey fieldstone base, big steep red clay tile roof with two gabled wings and two dormer windows, tall stone chimney with two clay pots, "
                  "covered entrance porch with carved posts and hanging heraldic shield, wrought-iron bracket with a wooden sign showing a golden wheat-sheaf emblem (no text), bay window with small panes, green shutters with flower boxes, warm lit windows.", MM, "1536x1024"),
    "04_smithy": ("Building design sheet: front, side and three-quarter views, plain light grey-white background, no ground. Fantasy village blacksmith: a small stone-and-plaster workshop attached to a large OPEN forge shed whose walls and roof are vertical wooden planks, "
                  "a tall square red-brick chimney, glowing forge hearth visible from outside, anvil on an oak stump, weapon and armour racks under the shed, a counter, a hammer-and-anvil emblem sign on an iron bracket and a plaque reading only the English word BLACKSMITH.", MM, "1536x1024"),
    "04_store": ("Building design sheet: front, side and three-quarter views, plain light grey-white background, no ground. Compact two-storey general store: cream plaster with dark half-timber, blue-grey slate roof, wide shop window with small panes and a wooden display ledge "
                 "with crates of apples, jars and sacks, green striped fabric awning, swinging sign shaped like a barrel, side lean-to with stacked barrels, stone chimney.", MM, "1536x1024"),
    "04_tailor": ("Building design sheet: front, side and three-quarter views, plain light grey-white background, no ground. Cozy fantasy tailor shop: salmon plaster, dark timber frame, red tile roof, red-and-white striped awning over a big bow window "
                  "with a mannequin in a red dress among colourful cloth bolts, hanging sign shaped like a golden needle and spool, small balcony with flower boxes, round chimney.", MM, "1536x1024"),
    "04_guard": ("Building design sheet: front, side and three-quarter views, plain light grey-white background, no ground. Small fantasy village guard house: grey fieldstone lower walls, cream plaster upper floor, blue-slate pyramid roof with iron weathervane, "
                 "stubby square watch turret at one corner with arrow-slit windows and a small lantern, heavy iron-strapped plank door under a stone arch, hanging shield emblem with a golden wheat ear, notice board on the side wall.", MM, "1536x1024"),
    "04_trainer": ("Building design sheet: front, side and three-quarter views, plain light grey-white background, no ground. Wide one-and-a-half-storey training hall: long salmon plaster hall with dark timber frame, steep red tile roof with a central gable over a double doorway, "
                   "five arched windows along the front, covered stone-pillar porch, weapon rack and straw training dummies by the wall, class banners with sword, staff, bow, dagger and gun symbols hanging from iron brackets.", MM, "1536x1024"),
    "04_stable": ("Building design sheet: front, side and three-quarter views, plain light grey-white background, no ground. Long fantasy village stable: grey fieldstone base, vertical plank walls, tall hayloft with hoist beam and open loft door, "
                  "steep golden thatch roof with wide eaves, split Dutch doors with two horse heads looking out, water trough, hay bales, wooden fence corner, small tack room at one end.", MM, "1536x1024"),
    "04_homes": ("Building variety sheet: exactly seven different small fantasy village homes in a grid on a plain light grey-white background, same three-quarter front-left camera, each isolated with wide margins, small black numeral 1-7 under each, no other text. "
                 "1 L-shaped cottage with red tile roof; 2 tiny single-room cottage with golden thatch and round chimney; 3 long narrow house with covered side porch; 4 tall narrow loft house with upper balcony; "
                 "5 house with an extra side wing and a dormer; 6 broad low house with wide gable and barn-style door; 7 mini house with blue slate roof and flower window.", MM, "1536x1024"),
    "05_props": (SHEET + "GENERIC REUSABLE PROP KIT (not specific to any village: no wheat, no gold, no heraldry, no emblems, no banners, no text, no engraved symbols). Every prop must have chunky simplified forms, large simple shapes, thick rounded edges, smooth flat hand-painted colour areas and very few tiny details, because it will be turned into a low-poly 3D model. "
                 "A PROP KIT SHEET: exactly 16 separate objects in a 4 columns x 4 rows grid, numbered 1-16: "
                 "1 round three-tier stone fountain, plain grey stone, plain round stone ball finial on top, water in the basins, no figures, no wheat, no gold; "
                 "2 teleport waystone: waist-high standing stone with a few simple glowing blue rune grooves, one small floating blue crystal above, on a round stepped stone base; "
                 "3 plain black wrought-iron street lamp with a glass lantern; 4 round fieldstone well with a small red-tile roof on two wooden posts, rope winch and bucket; "
                 "5 wooden market stall with a red-and-cream striped awning, crates of apples and bread; 6 wooden market stall with a green-and-cream striped awning, jars and hanging herbs; "
                 "7 weapon stall with swords and plain round shields (no emblems) under a red-and-cream striped canopy; 8 wooden notice board with pinned blank papers and a small tiled roof; "
                 "9 wooden signpost with two blank arrow boards; 10 hay-laden wooden hand cart with spoked wheels; 11 round hay stack on a pole with a small conical cap; 12 plain wooden park bench; "
                 "13 stacked firewood under a small lean-to tiled roof; 14 wooden water trough with a hand pump; 15 stone fire brazier on a wooden tripod with glowing coals; 16 scarecrow in a straw hat on a wooden cross.", MM, "1536x1024"),
    "08_interior": (SHEET + "GENERIC REUSABLE PROP KIT (no village names, no wheat, no gold, no heraldry, no readable text). Every prop has chunky simplified forms, thick rounded edges, smooth flat hand-painted colour areas and few tiny details, because it will be turned into a low-poly 3D model. INTERIOR FURNITURE KIT SHEET: exactly 16 separate objects in a 4 columns x 4 rows grid, numbered 1-16: "
                    "1 long heavy wooden tavern table with two mugs and a plate; 2 long wooden bench; 3 wooden chair with a tall slatted back; 4 round three-legged stool; "
                    "5 wooden bed with a blue blanket, white pillow and plain carved headboard; 6 tall wooden bookshelf with books on four shelves; 7 wooden cupboard with two panelled doors; 8 shop counter with a thick plank top; "
                    "9 big fieldstone fireplace with a timber mantel and burning logs; 10 round iron chandelier ring with eight lit candles; 11 blacksmith anvil on an oak stump; 12 blacksmith forge: stone hearth with glowing coals and a leather bellows; "
                    "13 wooden weapon rack with swords, axes and plain round shields; 14 iron-hooped oak barrel; 15 wooden storage chest with iron bands; 16 tailor dress-form mannequin in a plain red dress.", MM, "1536x1024"),
    "09_details": (SHEET + "GENERIC REUSABLE PROP KIT (no village names, no wheat, no gold, no heraldry, no readable text). Every prop has chunky simplified forms, thick rounded edges, smooth flat hand-painted colour areas and few tiny details, because it will be turned into a low-poly 3D model. BUILDING DETAIL KIT SHEET for a fantasy village: exactly 16 separate objects in a 4 columns x 4 rows grid, numbered 1-16: "
                   "1 hanging tavern sign: iron bracket with a wooden board showing a simple tankard icon; 2 hanging blacksmith sign: iron bracket with a board showing hammer and anvil icon; "
                   "3 hanging general-store sign: bracket with a barrel-shaped board; 4 hanging tailor sign: bracket with a needle-and-spool shaped board; 5 sheriff sign: bracket with a plain shield-shaped board with a simple star; "
                   "6 trainer sign: bracket with a board showing two crossed swords; 7 stable sign: bracket with a horseshoe-shaped board; 8 roof dormer window with its own small gable roof of large chunky shingles; "
                   "9 tall fieldstone chimney stack with two clay pots; 10 window unit with chunky wooden frame, diamond lattice glass, open shutters and a flower box; 11 arched plank door with iron straps in a stone arch frame; "
                   "12 wall-mounted iron lantern bracket with a lit candle lantern; 13 round wooden planter barrel with flowers; 14 entrance porch: two carved posts with curved brackets and a small shingled gable roof; "
                   "15 wooden picket fence section with a gate; 16 stone entrance steps with a wooden handrail.", MM, "1536x1024"),
    "06_materials": ("Flat material swatch sheet, 12 square seamless hand-painted tiles in a 4x3 grid on a plain background, only small numerals: 1 golden thatch roof, 2 red clay roof tiles, 3 blue-grey slate shingles, "
                     "4 salmon plaster wall, 5 cream plaster wall, 6 dark half-timber oak, 7 grey fieldstone, 8 worn cobblestone paving, 9 packed dirt road with wheel ruts, 10 wooden plank wall, 11 golden wheat field ground, 12 mossy grass with small flowers. "
                     "No lighting, no perspective, no text, Mabinogi Mobile flat painted look.", MM, "1536x1024"),
    "07_night": ("Concept art, the same circular village plaza at dusk: windows glowing warm orange, street lamps lit, the blue waystone glowing softly, fireflies, chimney smoke, a warm fire in a stone brazier, long soft blue shadows, cosy harvest-festival mood. "
                 "Half-timbered tavern, plank blacksmith shed with brick chimney, red-tile cottages around the round plaza with fountain.", MM2, "1536x1024"),
}

if __name__ == "__main__":
    if not gc3.BASE or not gc3.KEY:
        sys.exit("Set TEX_API_BASE and TEX_API_KEY first (.local/texgen.env).")
    only = set(sys.argv[1].split(",")) if len(sys.argv) > 1 else None
    todo = [(k, v) for k, v in SHOTS.items() if not only or k in only]
    with ThreadPoolExecutor(3) as ex:
        list(ex.map(lambda kv: gc3.gen(STYLE + kv[1][0], os.path.join(OUT, kv[0] + ".png"), kv[1][1], kv[1][2]), todo))




