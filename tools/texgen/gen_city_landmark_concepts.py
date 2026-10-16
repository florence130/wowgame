# 晴岚港功能建筑「奇观级」概念图（2026-10-09 用户：风格和建筑规模还是不太对 → 先出概念图定风格与尺度，再做模块）。
# 风格参考：docs/city_ref/ref10…ref14（用户 2026-10-09 给的 5 张）。复用 gen_concepts_v3.py 的出图接口。
# py tools/texgen/gen_city_landmark_concepts.py [id1,id2]   → docs/city_lm_concepts/<id>.png + _sheet.jpg
import os, sys, importlib.util
from concurrent.futures import ThreadPoolExecutor
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
spec = importlib.util.spec_from_file_location("gc3", os.path.join(HERE, "gen_concepts_v3.py"))
gc3 = importlib.util.module_from_spec(spec); spec.loader.exec_module(gc3)
OUT = os.path.join(ROOT, "docs", "city_lm_concepts")
REF = os.path.join(ROOT, "docs", "city_ref")
os.makedirs(OUT, exist_ok=True)

def ref(name):
    """webp 参考转成 jpg（出图接口按扩展名标 MIME）。"""
    src = os.path.join(REF, name)
    if not name.endswith(".webp"):
        return src
    dst = os.path.join(OUT, "_ref_" + name.replace(".webp", ".jpg"))
    if not os.path.exists(dst):
        from PIL import Image
        Image.open(src).convert("RGB").save(dst, quality=92)
    return dst

R_STREET, R_GOTHIC, R_SKY, R_TOWER, R_AERIAL = (ref("ref10_street_tower_scale.jpg"), ref("ref11_gothic_dome_viaduct_airship.jpg"),
                                                ref("ref12_sky_city_dome_terrace.webp"), ref("ref13_airship_tower_overlook.webp"), ref("ref14_cathedral_river_city_aerials.webp"))

STYLE = ("Concept art for a fantasy MMORPG capital city, matching the attached reference images in architecture language and mood: "
         "European Gothic-Baroque fantasy architecture, warm sandstone and cream limestone with weathering, deeply carved facades with strong shadow relief, "
         "clustered pinnacles and needle spires, flying buttresses, very tall lancet and round-arched windows spanning several storeys, "
         "red terracotta and verdigris copper domes on drums with lanterns and corner turrets, arcaded viaducts and stone sky bridges between buildings, "
         "steampunk airships in the sky, golden late-afternoon light, painterly but readable game-asset clarity. "
         "MONUMENTAL MMO SCALE: built for crowds of players, everything oversized relative to people. "
         "Draw small human figures (1.8 m tall) for scale. The attached images are STYLE references only - do not copy them.")

SHOTS = {
    "scale_street": ("Eye-level street view from a player standing on a 40 m wide stone boulevard lined with ornate iron lamp posts 7 m tall. "
                     "Left: the Adventurers' Guild, a 60 m long facade with a 45 m high cornice, its ground-floor entrance portal 9 m wide and 12 m tall with deep carved archivolts; "
                     "each upper window is a single 10 m tall arched opening, only three storeys of windows on the whole 45 m facade. "
                     "Center background: a 110 m Gothic clock tower closing the street vista. Right: a bank with a verdigris dome. "
                     "A few 1.8 m tall adventurers in the foreground show how huge the buildings are.", [R_STREET, R_GOTHIC]),
    "guild": ("Three-quarter aerial view of the Adventurers' Guild hall: footprint 60 x 45 m, 45 m to the cornice, a 95 m corner tower with a needle spire and clock, "
              "a protruding central frontispiece with a 12 m tall entrance portal, giant 10 m tall arched windows, buttresses with pinnacles on every bay, "
              "a steep red-tile roof with ornate dormers, two smaller turrets with conical roofs, banners. Grand stone stairs in front with crowds of 1.8 m adventurers.",
              [R_GOTHIC, R_STREET]),
    "cityhall": ("Three-quarter aerial view of the City Hall: 140 m wide, 50 m deep, 50 m to the cornice, a central 130 m clock tower in Gothic-Baroque style with tiered stages, "
                 "pinnacles and a copper spire, four corner pavilions with tall verdigris pavilion roofs and lanterns, a grand arcaded ground floor with 12 m arches, "
                 "a huge ceremonial staircase and a plaza with a fountain; hundreds of tiny 1.8 m people on the plaza.", [R_STREET, R_AERIAL]),
    "cathedral": ("Three-quarter view of the grand cathedral: 85 m wide, 110 m long, nave 55 m high, twin west towers with 140 m needle spires, "
                  "a red terracotta crossing dome on a drum with corner turrets, rows of flying buttresses with pinnacles, a 12 m rose window, three deep portals 12 m tall. "
                  "Airships in the sky. Tiny 1.8 m people on the parvis for scale.", [R_GOTHIC, R_AERIAL]),
    "airtower": ("The airship-station observation tower: a 150 m stone tower with an octagonal buttressed base, a slender shaft with flying buttresses, "
                 "and near the top an ornate wrought-iron and glass observation cage (12 m tall arched iron ribs with scrollwork) where people stand at the railing; "
                 "two iron mooring arms with a 60 m airship docked; at its foot a long airship platform with a mosaic plaza and crowds of 1.8 m people.",
                 [R_TOWER, R_GOTHIC]),
    "module_sheet": ("A clean modular architecture KIT reference sheet on a plain light grey background, all pieces in the same style, each isolated with space around it, "
                     "a 1.8 m human silhouette next to the pieces for scale, small numbers under each piece, no other text. Pieces: "
                     "1 ground-floor portal bay 9 m wide x 14 m tall with carved archivolts; 2 upper-storey bay with one 10 m tall arched window and carved surround; "
                     "3 Gothic lancet bay 9 m wide x 18 m tall with tracery; 4 buttress pier with a pinnacle, 20 m tall; 5 flying buttress; "
                     "6 square tower stage 12 m with lancet belfry openings and corner pinnacles; 7 octagonal lantern stage; 8 needle spire 30 m with lucarnes; "
                     "9 verdigris dome on a colonnaded drum with lantern, 20 m diameter; 10 red terracotta dome with ribs; 11 conical corner turret; "
                     "12 cornice and balustrade segment with statues; 13 arcaded viaduct / sky-bridge segment 20 m span; 14 wrought-iron and glass observation cage segment.",
                     [R_GOTHIC, R_STREET]),
}

# v2（2026-10-09 用户选「再收敛一些」+「尺度按概念图」）：以 v1 概念图为底稿保留布局 / 体量 / 尺度 / 机位，
# 装饰密度降一档，向洛奇M 的卡通化体块靠拢（docs/art_direction_v3/refs 的 mm_city_* 作为风格参考）。
MM = [os.path.join(ROOT, "docs", "art_direction_v3", "refs", n) for n in ("mm_city_palace.jpg", "mm_city_sheet.jpg")]
CONVERGE = ("REDESIGN BASE: the FIRST attached image is the approved concept - keep its layout, building massing, proportions, number and placement of towers, "
            "human-to-building scale and camera angle exactly. Change only the level of detail and rendering style: reduce ornament density by one level - "
            "fewer but larger and chunkier details, clean readable silhouettes, pinnacles grouped and simplified, no lace-like filigree, broad flat wall areas between features; "
            "stylized MMORPG game-art look like the 2nd and 3rd attached images (Mabinogi Mobile style): soft hand-painted materials, slightly saturated warm colours, "
            "gently exaggerated chunky proportions, crisp shapes that read from far away. Keep the warm sandstone, red terracotta and verdigris copper palette, the airships "
            "and the tiny 1.8 m people for scale.")

if __name__ == "__main__":
    if not gc3.BASE or not gc3.KEY:
        sys.exit("Set TEX_API_BASE and TEX_API_KEY first (.local/texgen.env).")
    v2 = "--v2" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    only = set(args[0].split(",")) if args else None
    todo = [(k, v) for k, v in SHOTS.items() if not only or k in only]
    if v2:
        OUT2 = os.path.join(OUT, "v2"); os.makedirs(OUT2, exist_ok=True)
        with ThreadPoolExecutor(3) as ex:
            list(ex.map(lambda kv: gc3.gen(CONVERGE + " Subject: " + kv[1][0], os.path.join(OUT2, kv[0] + ".png"),
                                           [os.path.join(OUT, kv[0] + ".png")] + MM, "1536x1024"), todo))
        OUT = OUT2
    else:
        with ThreadPoolExecutor(3) as ex:
            list(ex.map(lambda kv: gc3.gen(STYLE + " " + kv[1][0], os.path.join(OUT, kv[0] + ".png"), kv[1][1], "1536x1024"), todo))
    from PIL import Image, ImageDraw
    ims = [(k, os.path.join(OUT, k + ".png")) for k in SHOTS if os.path.exists(os.path.join(OUT, k + ".png"))]
    W, H = 768, 512
    sheet = Image.new("RGB", (W * 3, (H + 30) * ((len(ims) + 2) // 3)), "white")
    d = ImageDraw.Draw(sheet)
    for i, (k, p) in enumerate(ims):
        x, y = (i % 3) * W, (i // 3) * (H + 30)
        sheet.paste(Image.open(p).convert("RGB").resize((W, H)), (x, y + 30)); d.text((x + 8, y + 8), k, fill=(30, 30, 60), font=gc3._font(20))
    sheet.save(os.path.join(OUT, "_sheet.jpg"), quality=88)
    print("CONCEPTS_DONE", len(ims))
