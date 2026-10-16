# -*- coding: utf-8 -*-
"""Sea-goddess ruined temple (风语旧圣堂) room preview generator.

Style is locked to the flat big-colour-block mobile MMO look the user approved in
output/imagegen/sanctum_ocean_ruin_20261012/07_sea_nave_flat.png.

Env: TEX_API_BASE / TEX_API_KEY / TEX_IMAGE_MODEL  (read from .local/texgen.env)
Usage:
  py tools/sanctum/gen_ocean_preview.py                 # generate every missing preview
  py tools/sanctum/gen_ocean_preview.py 03,07           # only these ids
  py tools/sanctum/gen_ocean_preview.py --list
Output: output/imagegen/sanctum_preview_20261012/<id>_<slug>.png + <id>_<slug>_prompt.txt
Resumable: an existing PNG is skipped, so delete a file to regenerate it.
"""
import os, sys, json, time, base64, uuid, urllib.request, threading
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "output", "imagegen", "sanctum_preview_20261012")
ENVF = os.path.join(ROOT, ".local", "texgen.env")

if os.path.exists(ENVF):
    for line in open(ENVF, encoding="utf-8"):
        if "=" in line and not line.startswith("#"):
            k, v = line.strip().split("=", 1)
            os.environ.setdefault(k, v)
BASE = os.environ.get("TEX_API_BASE", "").rstrip("/")
KEY = os.environ.get("TEX_API_KEY", "")
MODEL = os.environ.get("TEX_IMAGE_MODEL", "gpt-image-2")
LOCK = threading.Lock()


def log(*a):
    with LOCK:
        print(time.strftime("%H:%M:%S"), *a, flush=True)


# ---------------------------------------------------------------- style blocks
# The approved flat look. Kept byte-identical in every request so all rooms read
# as one game.
STYLE = (
    "Use case: stylized-concept. A PRODUCTION GAME ENVIRONMENT PREVIEW for a mobile MMORPG, "
    "Mabinogi Mobile and Canticum Turris inspired VERY SIMPLE hand-painted cartoon LOW-POLY "
    "FLAT-COLORED 3D environment. Strong chunky polygonal geometry, visibly planar surfaces, "
    "flat big colour blocks with only 2-3 shading steps, minimal broad painted texture, crisp "
    "readable shapes, soft ambient light. NOT a detailed painterly illustration, NOT photorealism, "
    "NOT watercolor, NOT realistic PBR, no heavy black outlines, no tiny leaf or stone detail, "
    "no brush grain, no surface noise, no bloom, no dramatic sunbeams, no HUD, no text, no watermark. "
    "Keep detail limited to big readable architectural shapes. "
)

WORLD = (
    "The whole dungeon is ONE abandoned temple of the SEA GODDESS of the ancient kingdom, once where "
    "sailors and merchant fleets prayed before voyages, deserted for over 100 years after new magical "
    "technology replaced the old faith, now overgrown and occupied by living vine monsters and primitive "
    "ratfolk. Shared kit in every room: worn grey-beige simple limestone ashlar arches, muted slate-blue "
    "polygon roof tiles, desaturated moss-green chunky polygon leaves, dark brown rotten timber, dull old "
    "bronze lamp fixtures. Worn wave, scallop-shell and tide-disc carvings as the only ornament. Wooden "
    "ship-shaped votive offerings and faded slate-blue banners along the edges. Roots lift the paving and "
    "crawl along ruins; ratfolk traces are crude rope-tied scavenged planks, clay pots and nesting sacks. "
    "No modern magic machines, no Christian crosses, no Gothic cathedral, no different art style per room."
)

GAMEPLAY = (
    "This is a gameplay space: the central floor stays wide and unobstructed for a 28 m battle area, "
    "the architecture is tall enough for a distant third-person MMO camera, and props plus vegetation are "
    "grouped only along functional edges and column bases instead of scattered randomly. Show plausible "
    "structural support and standing walls, no floating geometry. Show a handful of tiny simple player and "
    "companion silhouettes for scale only, with no portrait detail."
)

ROOMS = [
    dict(id="01", slug="overall", title="整体总览",
         size="1536x1024",
         desc="Wide elevated three-quarter overall view of the entire hillside temple ruin read as ONE "
              "connected playable space. South gate and paved forecourt at the near low end; western "
              "colonnaded cloister wrapping a vine-choked former prayer courtyard; the big high-roofed "
              "nave in the centre; ONE small restrained cutaway showing the buried offering stores "
              "genuinely UNDER the nave floor with soil above them; the eastern former offering delivery "
              "court with its service ramp; the northwestern old departure bell tower with folded stairs "
              "and a stone bridge. Consistent roof silhouettes and the bell tower are the landmarks. "
              "Weathered but standing walls, some missing roof tiles, chunky roots. Clear readable main "
              "route from the gate up through the complex. Strictly landlocked hillside, no sea cliff, "
              "no island, no ocean panorama."),
    dict(id="02", slug="gate_forecourt", title="山门与前庭",
         size="1536x1024",
         desc="Distant third-person MMO view of the ruined SOUTH GATE and forecourt, the dungeon entrance "
              "and first approach space. A broad worn stone stair rises to a broken gateway arch with one "
              "collapsed roof section; wave-carved paving in the open forecourt, two chunky faceted vine "
              "creatures rooted at the wall bases as the first light encounter, one ratfolk lookout "
              "silhouette on the stair. Faded blue voyage banners hanging limp from the gate piers, dry "
              "stone basin at one side, coarse moss in the joints. Wide open floor for fighting. "
              "The nave roof and the bell tower are visible above and beyond the gate, establishing where "
              "the player is heading."),
    dict(id="03", slug="cloister_court", title="回廊与祈航庭院",
         size="1536x1024",
         desc="Distant third-person MMO view standing in the western colonnaded CLOISTER, looking into the "
              "former prayer COURTYARD that is now the first major boss arena. One tall airy perimeter "
              "colonnade runs along the left with its high roof and columns pushed to the outer margins "
              "so the central 28 m arena stays completely clear. Worn large wave-pattern pavers, a broken "
              "scallop-shell votive pedestal at the arena edge, one big chunky faceted vine monster rooted "
              "beside it, broad curled roots displacing the coping stones along the edges. Over a century "
              "of neglect: dry basin, torn faded blue cloth, coarse moss, a few fallen column drums. "
              "A broad stone arch at the far end descends toward the buried offering stores and the nave."),
    dict(id="04", slug="rat_cellar", title="地下供物储藏层",
         size="1536x1024",
         desc="Distant-camera view INSIDE the spacious buried offering store under the nave, roughly 40 m "
              "wide with a high stone vault and real soil above it, so no sky and no daylight. The same "
              "simplified grey-beige arches and dark timber as outside, just in lower values. Ancient "
              "votive cargo and damaged ship-shaped wooden offerings pushed against the walls; ratfolk now "
              "live here with crude rope-tied plank partitions along the edges, nesting sacks, big clay "
              "pots and scavenged chests; patchy green roots push in through the cracks. A clear wide "
              "central transport path is read from the surviving broad paving and sparse old amber lamps. "
              "One short doorway leads to the chest niche. Two small stylized ratfolk silhouettes, not "
              "humans. Not a mine, not a tidy wine cellar, not packed with barrels."),
    dict(id="05", slug="nave", title="海洋女神正殿",
         size="1536x1024",
         desc="Distant third-person MMO view down the main axis of the ruined SEA GODDESS temple NAVE, the "
              "largest interior. Very tall high vault with solid exterior side walls and only small HIGH "
              "windows, well over 20 m of clear height and a 28 m uncluttered central fight floor. At the "
              "far apse a giant simple worn faceted scallop-shell shaped stone goddess relief with a wave "
              "motif, explicitly NOT a cross and NOT Gothic. Faded slate-blue voyage banners, sparse old "
              "ship-shaped votive offerings and broken prayer benches kept along the perimeter. Chunky "
              "living vines pierce the cracked joints and encircle the altar edge, with one faceted vine "
              "creature as the encounter focus; foliage never covers the floor. A few restrained dull "
              "bronze lamps and thin high-window light. This is a roofed above-ground hall, so no open sky, "
              "no ocean view through ground-level openings, no exposed underground layer."),
    dict(id="06", slug="nave_apse", title="正殿后殿与祭坛",
         size="1536x1024",
         desc="Closer distant third-person MMO view of the semicircular APSE and altar at the far end of the "
              "nave, framed by the crossing. The huge simple faceted shell-and-wave goddess relief fills "
              "the apse wall as a flat-coloured silhouette; a plain worn stone altar stands in front of it "
              "with a few old ship-shaped votive carvings and dull bronze bowls. Thick vine roots crack the "
              "apse joints and wrap the altar perimeter while the floor in front stays a clear wide battle "
              "space. Tall blind arches and simple ribbing, faded blue banner fragments high on the walls, "
              "missing roof tiles letting in a few narrow shafts of light. Quiet abandoned mood, no "
              "worshippers, no horror."),
    dict(id="07", slug="rat_delivery_court", title="鼠人转运院",
         size="1536x1024",
         desc="Wide distant MMO view of the eastern former offering TRANSFER COURT on a flat stone platform, "
              "now a ratfolk scavenger camp inside the SAME ruined temple. A clear central 28 m battle "
              "space. Crude lean-to nesting shelters and rope-tied wood scraps are attached only to the "
              "perimeter old walls; two primitive cartoon ratfolk silhouettes at the edge; an old handcart, "
              "broken cargo rope and large votive pots follow the original delivery use. A worn "
              "wave-carved stone doorway frames the uphill path to the nave, and the service ramp comes "
              "down beside it. Overgrown roots run along the walls and the old drain. Identical low-poly "
              "limestone, slate-blue roof fragments, muted green leaf shapes and bronze fittings. "
              "No military bandit camp, no red faction banners, no tidy new courtyard."),
    dict(id="08", slug="bell_tower", title="旧出航钟台",
         size="1536x1024",
         desc="Distant third-person MMO view of the final encounter space: the old DEPARTURE BELL TOWER "
              "platform at the top of the ruin, reached by folded stone stairs and a short stone bridge. "
              "An octagonal open-air stone platform with part of its colonnade and roof missing, an old "
              "bronze departure bell hanging from a worn beam in the centre, thick roots splitting the "
              "paving and one massive faceted vine creature coiled at the broken edge. Faded blue banners "
              "on the surviving columns, votive stone sockets along the parapet, the whole temple ruin "
              "spread out below and behind. Clear circular fighting floor of about 28 m. Overcast soft "
              "light, quiet and melancholic, no dramatic god-rays."),
    dict(id="09", slug="passage_down", title="地下过道（下坡）",
         size="1536x1024",
         desc="Distant MMO view down the main connecting corridor that descends from the upper temple into "
              "the buried offering stores: an 8 m wide, 12 m high sloping stone passage. Thick stone walls "
              "and a genuine cut soil section over the portal where the floor enters the ground, so the "
              "player can read that the stores are actually underground. One big faceted root crosses at "
              "the wall only, leaving the floor clear; ratfolk scavenging traces and a dropped clay pot "
              "along the side; worn wave carving on the arch above the descent. Broad flat paving, simple "
              "amber lamp at the corner, no clutter on the walkable path."),
    dict(id="10", slug="passage_up", title="上行过道与装卸坡道",
         size="1536x1024",
         desc="Distant MMO view of the eastern connecting corridor: a service RAMP climbing from the "
              "delivery court up toward the temple's upper floor, about 24 m long and 8 m wide with a low "
              "retaining wall on the outer side and the old drain running beside it. Cart ruts are worn "
              "into the paving, broken votive cargo and a abandoned handcart sit on the shoulder out of the "
              "walking line, roots push through the retaining wall, and part of the canopy over the ramp "
              "has collapsed leaving fallen tile polygons on the edge. Ahead a worn wave-carved doorway "
              "opens into the upper temple. Clear straight walkable ramp, no obstruction in the middle."),
    dict(id="11", slug="side_rooms", title="侧室一组",
         size="1536x1024",
         desc="Four-panel environment preview sheet in one image, no written labels, same flat-colour "
              "low-poly art in all four panels. Panel 1: an entirely EMPTY small stone side room, bare "
              "flagged floor, worn wall joints, one narrow window slot, nothing inside but dust and a "
              "little moss. Panel 2: a small room with an old chest on a stone plinth in the middle, "
              "ratfolk nesting sacks and a rope-tied crate pushed against the wall. Panel 3: a former "
              "brewery store with big clay fermentation pots and rotten timber racks along one wall, green "
              "roots entering through a crack. Panel 4: a small chapel with a worn shell niche, a plain "
              "stone bench and faded blue cloth. All four are low, simple, roughly 12 by 12 metres, "
              "clearly side rooms of the same temple."),
    dict(id="12", slug="scale_check", title="尺度与镜头参照",
         size="1536x1024",
         desc="Two-panel scale reference sheet in one image, no written labels, same flat-colour low-poly "
              "art in both panels. Left panel: a wide third-person MMO gameplay shot of the temple nave "
              "with the camera pulled far back and high, a small party of one player and three companions "
              "standing in the middle of the empty floor, the surrounding architecture clearly much "
              "taller than the characters. Right panel: a close third-person gameplay shot inside one of "
              "the narrow 8 m connecting corridors, again with one player and three companions, showing "
              "how much headroom and side clearance the passage gives. Characters are tiny simple "
              "silhouettes with no face detail; they exist only to communicate real world scale."),
]

# ---------------------------------------------------------------- api


def post(prompt, size):
    hdr = {"Authorization": "Bearer " + KEY, "User-Agent": "Mozilla/5.0"}
    if MODEL.startswith("gpt-image") or "dall" in MODEL:
        hdr["Content-Type"] = "application/json"
        data = json.dumps({"model": MODEL, "prompt": prompt, "size": size, "n": 1}).encode("utf-8")
        url = BASE + "/images/generations"
    else:
        bd = uuid.uuid4().hex
        parts = [('--%s\r\nContent-Disposition: form-data; name="%s"\r\n\r\n%s\r\n' % (bd, k, v)).encode("utf-8")
                 for k, v in (("model", MODEL), ("prompt", prompt), ("size", size))]
        parts.append(("--%s--\r\n" % bd).encode())
        data = b"".join(parts)
        hdr["Content-Type"] = "multipart/form-data; boundary=" + bd
        url = BASE + "/images/edits"
    with urllib.request.urlopen(urllib.request.Request(url, data=data, headers=hdr), timeout=900) as r:
        d = json.loads(r.read().decode("utf-8"))
    it = d["data"][0]
    if it.get("b64_json"):
        return base64.b64decode(it["b64_json"])
    if it.get("url"):
        return urllib.request.urlopen(it["url"], timeout=300).read()
    return None


def gen(room, tries=3):
    name = "%s_%s" % (room["id"], room["slug"])
    png = os.path.join(OUT, name + ".png")
    txt = os.path.join(OUT, name + "_prompt.txt")
    if os.path.exists(png):
        log("SKIP already exists", name)
        return True
    prompt = (STYLE + " " + WORLD + " " + GAMEPLAY + " Scene: " + room["desc"] + " "
              "Render it as one coherent game environment preview in the shared flat-colour style.")
    os.makedirs(OUT, exist_ok=True)
    with open(txt, "w", encoding="utf-8") as f:
        f.write(prompt + "\n")
    for t in range(tries):
        try:
            img = post(prompt, room.get("size", "1536x1024"))
            if img:
                with open(png, "wb") as f:
                    f.write(img)
                log("OK", name, len(img) // 1024, "KiB")
                return True
            log("NO_IMAGE", name)
        except Exception as e:
            body = ""
            try:
                body = e.read()[:200].decode("utf-8", "replace")
            except Exception:
                pass
            log("ERR", name, type(e).__name__, e, body)
        time.sleep(6 + t * 12)
    return False


if __name__ == "__main__":
    if "--list" in sys.argv:
        for r in ROOMS:
            print("%s  %s  %s" % (r["id"], r["slug"], r["title"]))
        sys.exit(0)
    if not BASE or not KEY:
        sys.exit("Set TEX_API_BASE and TEX_API_KEY (or fill .local/texgen.env).")
    only = set()
    argv = sys.argv[1:]
    value_flags = ("--workers", "--only")
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in value_flags:
            i += 2
            continue
        if not a.startswith("--"):
            only |= set(x.strip() for x in a.split(",") if x.strip())
        i += 1
    todo = [r for r in ROOMS if not only or r["id"] in only or r["slug"] in only]
    workers = 2
    if "--workers" in argv:
        workers = int(argv[argv.index("--workers") + 1])
    log("MODEL", MODEL, BASE, "| rooms", len(todo), "| workers", workers)
    fails = []
    with ThreadPoolExecutor(workers) as ex:
        for r, ok in zip(todo, ex.map(gen, todo)):
            if not ok:
                fails.append("%s_%s" % (r["id"], r["slug"]))
    log("DONE", len(todo) - len(fails), "/", len(todo), ("failed: " + ",".join(fails)) if fails else "")
