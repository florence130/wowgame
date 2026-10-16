# 海神旧圣堂副本 v2 全新设定图（2026-10-12 用户：完全重做，忽略旧方案）。
# 风格：洛奇M / 巴别塔圣歌 的手绘卡通低多边形平涂 + 希腊地中海建筑。
#   py tools/texgen/gen_sanctum_v2_concepts.py <id> [<id>...]   -> docs/sanctum_v2/concept/<id>.png（已存在则跳过）
# 密钥只在 .local/texgen.env。逐张出图、看过再出下一张（省 API）。
# 区域一致性：本副本与晨钟修道院同属晨露谷一带，材质/色板/造型语汇必须与修道院游戏内画面一致（docs/sanctum_v2/refs）。
import os, sys, importlib.util
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
spec = importlib.util.spec_from_file_location("gc3", os.path.join(HERE, "gen_concepts_v3.py"))
gc3 = importlib.util.module_from_spec(spec); spec.loader.exec_module(gc3)
OUT = os.path.join(ROOT, "docs", "sanctum_v2", "concept")
os.makedirs(OUT, exist_ok=True)
RF =os.path.join(ROOT, "docs", "sanctum_v2", "refs")
MM = [os.path.join(RF, n) for n in ("abbey_chapel_game.jpg", "abbey_gate_game.jpg", "abbey_hall_game.jpg", "abbey_interior_game.jpg")]

STYLE = (
    "STYLE LOCK - the image must look like an in-engine screenshot of the SAME game area as the attached images (the Morning Bell Abbey of a Mabinogi-Mobile-style stylized low-poly mobile MMORPG), "
    "same art direction, same materials, same palette. Chunky low-poly 3D geometry with large FLAT matte colour planes, very little texture noise, simple faceted shapes, thick rounded stone edges, "
    "soft warm sunlight with broad cool shadows, moderate saturation, clean readable silhouettes. It is a clean game render, NOT a painterly illustration, no brush strokes, no photographic detail. "
    "REGIONAL MATERIAL PALETTE (copy from the attached abbey): cream / ivory-white limestone BLOCK walls built from big rectangular bricks with rounded edges; "
    "BLUE-GREY SLATE roofs with a thick dark-brown wooden eave board; dark-brown timber beams and half-timbering with white plaster; black wrought-iron gates, lamps and brackets; "
    "round and slightly pointed stone arches with chunky mouldings; conical dark-green cypress trees; bright green grass; muted pale-blue accents. "
    "Add a light Greek-Mediterranean flavour built from those SAME materials: thick short stone columns with simple scroll capitals, colonnades of round arches, wide stone steps, "
    "wave and scallop-shell reliefs, large clay amphorae, ship-anchor and ship-prow motifs, sea-blue cloth banners, an open sea view. Keep it a cousin of the abbey, not a different civilisation. "
    "SETTING: a forgotten sea-goddess sanctuary where sailors and merchants once prayed before voyages, abandoned for over a hundred years: "
    "chipped stone, missing roof tiles, a few broken columns, faded blue banners, dry offering bowls, thick green vines and creeper roots climbing walls and pillars, "
    "plus crude scavenger camps of rat-folk barbarians (rope-lashed wooden palisades, patchwork cloth tents, clay pots, scrap-wood scaffolds) along the edges of the old halls. "
    "Ruined but tidy and readable, friendly to play in, not grim, not horror. "
    "AVOID: photorealism, painterly concept-art rendering, dense fine detail, orange terracotta roofs, heavy black outlines, gloomy darkness, bloom, text, watermark, UI overlay, human characters. "
    "The attached images are STYLE references only - copy their materials, proportions and rendering, not their layouts. ")
SHOTS = {}

SHOTS["00_overview"] = ("Concept art, high three-quarter aerial view of the whole abandoned Greek-Mediterranean sea temple complex seen from the sea side, built on a sunny coastal cliff. "
    "From front to back: a stepped stone pilgrim landing with a ruined cream limestone gate at the bottom; a walled tide forecourt with a dry fountain and a rat-folk scavenger camp; "
    "a long colonnade corridor; an open overgrown cloister garden with a cracked wave-pattern floor swallowed by thick vines; a sunken flooded offering cistern; "
    "the big central nave with a broken half-collapsed barrel-vault roof, blue banners and a giant scallop-shell altar; at the back a tall white lighthouse-like bell tower on the cliff edge with a bronze ship bell and the turquoise sea behind. "
    "Blue-grey slate roofs partly collapsed, vines everywhere, rat-folk wooden palisades and tents on the edges. Clear winding route through all rooms, readable as a dungeon map. Warm afternoon sun.")
SHOTS["01_landing"] = ("Concept art, eye-level game view of the dungeon entrance: a wide worn cream-limestone stair climbing from a small rocky sea harbour up to a ruined temple gate with two thick fluted columns, a broken pediment carved with a faded wave and shell relief, "
    "a stone anchor monument, faded blue banners, moss and vines on the steps, a few rat-folk lookout shacks of lashed wood on the cliff side, turquoise sea and sailing-ship wreck in the distance.")
SHOTS["02_forecourt"] = ("Concept art, eye-level game view of the first room, a tide forecourt: a wide square courtyard of cream limestone paving with a wave-pattern inlay, a dry round fountain with a headless sea-goddess statue, arcades of round arches along both sides, "
    "a crude rat-folk scavenger camp of patchwork tents, rope-lashed wooden barricades, clay pots, sacks and a smoking campfire in the middle; a doorway on the far side leading into a colonnade.")
SHOTS["03_colonnade"] = ("Concept art, eye-level game view of a long corridor: a roofed Greek colonnade walkway with a row of thick limestone columns on one side open to the sea light, cracked floor, fallen column drums, "
    "thick green vines hanging from the roof beams, faded blue pennants, small rat-folk rope barricade half blocking the way and a lit doorway at the end. Clear straight path for the player.")
SHOTS["04_cloister"] = ("Concept art, eye-level game view of boss arena one, an overgrown cloister garden: a large round open courtyard ringed by a roofed arcade of round arches, centre floor a circular wave-pattern mosaic cracked open by giant thick vine roots and big leafy plants, "
    "a dry shell-shaped basin in the middle, vines climbing every arch, glowing pale green blossom pods, sunlight falling into the open roof, plenty of free space for a boss fight.")
SHOTS["05_cistern"] = ("Concept art, eye-level game view of boss arena two, a sunken votive cistern under the temple: a wide vaulted stone hall half-filled with shallow turquoise water, stone walkways and round arches on short thick columns, "
    "huge stacks of old offering amphorae, rotted ship models and wooden votive boats, a large rat-folk nest of scrap cloth, ropes, barrels and clay pots built on a raised platform, hanging lanterns with warm light, root tendrils through the ceiling.")
SHOTS["06_nave"] = ("Concept art, eye-level game view of boss arena three, the main sea-goddess nave: a very tall hall with two rows of thick fluted limestone columns, a half-collapsed barrel-vault ceiling letting in beams of sunlight, "
    "long faded blue banners with wave patterns, a stepped apse with a giant scallop-shell altar and a weathered limestone sea-goddess statue holding a ship, vines covering the columns and spilling across the wave-patterned nave floor, rat-folk scrap banners hung on the side aisles.")
SHOTS["07_belltower"] = ("Concept art, eye-level game view of the final boss arena, an open cliff-top bell terrace: a wide round cream-limestone platform ringed by low balustrade and eight short columns, a tall open bell tower with a huge bronze ship bell, "
    "a white lighthouse lamp room above, thick vine roots wrapped around the tower, rat-folk chief's scrap-metal throne and banners at the edge, brilliant turquoise sea, sky and distant islands behind, golden sunlight.")
SHOTS["08_sidehall"] = ("Concept art, eye-level game view of an optional side chamber: a small old priest quarters or votive chapel in the temple, cream stone walls, an arched window with sea view, a rotting wooden bed, an old prayer niche with an empty shell bowl and a faded blue cloth, "
    "a treasure chest in the corner, a few vines through the cracked floor.")

if __name__ == "__main__":
    if not gc3.BASE or not gc3.KEY:
        sys.exit("Set TEX_API_BASE and TEX_API_KEY first (.local/texgen.env).")
    ids = sys.argv[1:] or list(SHOTS)
    for k in ids:
        p, = [SHOTS[k]]
        gc3.gen(STYLE + p, os.path.join(OUT, k + ".png"), MM, "1536x1024")
