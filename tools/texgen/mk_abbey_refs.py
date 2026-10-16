# 从晨钟修道院的游戏内截图 / 设定图裁出风格参考，供风语旧圣堂副本设定图使用
import os
from PIL import Image
R = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
S = os.path.join(R, ".shots")
D = os.path.join(R, "docs", "sanctum_v2", "refs")
os.makedirs(D, exist_ok=True)


def crop(src, dst, box):
    Image.open(os.path.join(S, src)).convert("RGB").crop(box).save(os.path.join(D, dst), quality=92)


crop("abbey_fix7/04_tour_a_chapel_se.png", "abbey_chapel_game.jpg", (0, 100, 1360, 640))
crop("abbey_fix7/23_tour_a_altar.png", "abbey_interior_game.jpg", (0, 100, 1360, 640))
crop("current_town_20261011/03_abbey.png", "abbey_gate_game.jpg", (0, 110, 1360, 640))
crop("style_latest/00_tour_s_abbey_court.png", "abbey_hall_game.jpg", (0, 110, 1360, 640))
Image.open(os.path.join(R, "docs", "buildings_v2", "vale_abbey_chapel", "hero.png")).convert("RGB").save(
    os.path.join(D, "abbey_chapel_concept.jpg"), quality=92)
print(sorted(os.listdir(D)))
