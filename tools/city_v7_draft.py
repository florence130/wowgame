"""晴岚港 v7 规划草案（仅规划，不进游戏）。

v7 = v6 契约 + 城市肌理重构（回应用户：建筑数量必须补足，城市不能只有地标和功能建筑）。

与 v6 的关系：
1. 全部保留：v6 的 22 种建筑资产地标/功能建筑（坐标不变）、71+ NPC 契约、POI、出生点、
   双轴道路骨架（王冠大道 / 北门大道+站南大道 / 港湾大道 / 码头街 / 西埠坡道等）、
   广场、庭园、高差体系（60→44→26→18→13→8）。
2. 修正 v6 错误：SW1 街坊一半在湾水里（v6 未查海岸线），已删除；market_lane x=140 穿过
   城东上坊，西移到 x=128；civic_green 与 N2 街坊重叠，改为 N2 共享内院。
3. 核心新增：24 个街坊的连续街墙填充（v6 因占位盒 1.0m 外扩+1.5m 摆放间距自相矛盾，
   每条边只能放 1 栋，全城仅 94 栋）。v7 修正间距逻辑，沿街面墙 + 转角楼 + 共享内院
   后排，老城/车站/河湾用 wb_shophouse（白板联排商住屋）密织填充。
4. 新增：湾前街（河湾坊与车站区之间的缺失横街）、2 座跨河步行桥（白盒）、
   3 座街坊内院喷泉（白盒）、港市坊/港北坊/埠头坊等 11 个新街坊。

真实规划逻辑：
- 街墙连续性：临街建筑沿红线排布，随机 1-3m 缝隙 + 每 4-6 栋留 7m 巷口。
- 老城（河湾/湾东）密而小（wb_shophouse 16×14），新城（市政/商贸）疏而大（22-34m 住宅）。
- 高频服务环、港水关系、机构带后退一线等沿用 v6 结论。

输出：docs/city_v7/draft.json（与 v6 编辑器 schema 完全兼容）。
"""
import json, math, random, zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V5 = json.loads((ROOT / 'docs/city_v5/layout.json').read_text(encoding='utf8'))
OUT = ROOT / 'docs/city_v7'
OUT.mkdir(exist_ok=True)

FP = {
    'civic_hall': [88, 40], 'trade_hall': [70, 38], 'governor_palace': [100, 70],
    'academy': [60, 40], 'cathedral': [48, 94], 'station': [100, 56],
    'guild_hall': [44, 30], 'public_house': [44, 28], 'shop_arcade_3': [24, 20],
    'inn_seafarer_3': [28, 24], 'academy_library_3': [26, 22], 'magic_tower': [20, 20],
    'courtyard_college_3': [36, 26], 'opera': [64, 40], 'warehouse_brick_2': [30, 24],
    'warehouse_stone_1': [32, 24], 'mansion_garden_3': [26, 22],
    'residence_slate_3': [22, 20], 'residence_ochre_4': [26, 22],
    'corner_merchants_3': [32, 26], 'shop_rose_4': [28, 22],
    'academy_lodgings_4': [28, 22], 'corner_copper_4': [34, 26],
}
WB = {
    'wb_clock_arch': [30, 10], 'wb_fountain': [14, 14], 'wb_tower': [12, 12],
    'wb_crane': [8, 8], 'wb_lighthouse': [12, 12], 'wb_warehouse': [36, 22],
    'wb_hall': [60, 30], 'wb_shophouse': [16, 14], 'wb_pier_shed': [24, 14],
    'wb_footbridge': [16, 6], 'wb_rowhouse': [12, 10],
}
ALL_FP = {**FP, **WB}
WHITE = set(WB)
ALLOW_ROAD = {'wb_clock_arch', 'wb_fountain', 'wb_lighthouse', 'wb_tower',
              'wb_crane', 'wb_pier_shed', 'wb_footbridge'}

WALL = V5['wall']
RIVER = V5['river']
COAST_S = V5['coast_south']
COAST_W = V5['coast_west']

P = dict(
    version=7, water=8, draft=True,
    coast_west=V5['coast_west'], coast_south=V5['coast_south'],
    river=V5['river'], wall=V5['wall'], gates=V5['gates'], terraces=V5['terraces'],
    roads=[], buildings=[], gardens=[], squares=[], districts=[], blocks=[],
    npcs=[], pois=[], spawns=[], bridges=[], notes=[],
)

# ---------------------------------------------------------------- 几何工具
def bbox(x, z, w, d, yaw, pad=0.0):
    a = math.radians(yaw)
    wx = abs(math.cos(a)) * w + abs(math.sin(a)) * d
    dz = abs(math.sin(a)) * w + abs(math.cos(a)) * d
    return [x - wx / 2 - pad, z - dz / 2 - pad, x + wx / 2 + pad, z + dz / 2 + pad]

def overlap(a, b):
    return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]

def segdist(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / max(dx * dx + dz * dz, 1e-9)))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dz)

def poly_dist(px, pz, poly):
    best = 1e9
    for i in range(len(poly)):
        best = min(best, segdist((px, pz), poly[i], poly[(i + 1) % len(poly)]))
    return best

def river_dist(px, pz):  # 河道是折线（非闭合）
    best = 1e9
    for a, b in zip(RIVER, RIVER[1:]):
        best = min(best, segdist((px, pz), a, b))
    return best

def on_land(px, pz, margin=18.0):
    """城墙内、离城墙/河/海岸足够远才算可建。"""
    if poly_dist(px, pz, WALL) < margin:
        return False
    if river_dist(px, pz) < 9 + margin:
        return False
    if poly_dist(px, pz, COAST_S) < margin:
        return False
    if poly_dist(px, pz, COAST_W) < margin:
        return False
    return True

occupied = []          # 地标/庭园/广场的占位（街坊填充需避让）
road_test_extra = []   # 无

def road_clear(bb, extra=1.0):
    for r in P['roads']:
        if r['cls'] in ('rail', 'path'):
            continue
        for a, b in zip(r['pts'], r['pts'][1:]):
            for q in [(bb[0], bb[1]), (bb[2], bb[1]), (bb[0], bb[3]), (bb[2], bb[3]),
                      ((bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2)]:
                if segdist(q, a, b) < r['width'] / 2 + r.get('walk', 3) + extra:
                    return False
    return True

def road(id, cn, cls, width, pts, elev=None, note='', walk=3):
    P['roads'].append(dict(id=id, cn=cn, cls=cls, width=width, pts=pts,
                           walk=walk, elev=elev, note=note))

def add(id, asset, x, z, yaw=0, y=None, label='', cat=None):
    w, d = ALL_FP[asset]
    b = dict(id=id, asset=asset, c=[round(x, 1), round(z, 1)], yaw=yaw,
             size=[w, d], label=label)
    if asset in WHITE:
        b['whitebox'] = True
        b.setdefault('h', 18)
    if cat:
        b['cat'] = cat
    if y is not None:
        b['y'] = y
    P['buildings'].append(b)
    if asset not in ALLOW_ROAD:
        occupied.append(bbox(x, z, w, d, yaw, 1.0))
    return b

def npc(id, x, z, yaw=180, y=None):
    a = dict(id=id, p=[x, z], yaw=yaw)
    if y is not None:
        a['y'] = y
    P['npcs'].append(a)

def poi(id, title, x, z, r=20, priority=12):
    P['pois'].append(dict(id=id, title=title, p=[x, z], radius=r, priority=priority))

def garden(id, cn, x, z, w, d, y, style='formal'):
    P['gardens'].append(dict(id=id, cn=cn, c=[x, z], size=[w, d], y=y, style=style))
    occupied.append(bbox(x, z, w, d, 0, 0))

def square(id, cn, x, z, w, d, y, style='plaza'):
    P['squares'].append(dict(id=id, cn=cn, c=[x, z], size=[w, d], y=y, style=style))
    occupied.append(bbox(x, z, w, d, 0, 0))

# ---------------------------------------------------------------- 1. 路网
# —— 主干/次干骨架沿用 v6（双轴 + 环线 + 港口体系）——
road('crown_ave', '王冠大道', 'arterial', 20,
     [[292, 450], [140, 450], [45, 450]], elev=[26, 26],
     note='东西主轴东段：东门→中央广场（广场内为石铺段，不设车行道）')
road('crown_west', '王冠大道西段', 'arterial', 20,
     [[-175, 450], [-365, 450], [-520, 450], [-660, 446], [-760, 438], [-790, 424], [-790, 362]],
     elev=[26, 60], note='广场→爬坡（430m 升 34m≈8%）→官邸前庭；西端视线终点=总督宫')
road('north_ave', '北门大道', 'arterial', 18,
     [[-70, 205], [-70, 330]], elev=[30, 26], note='北门→中央广场；视线终点=市政厅立面', walk=4)
road('station_ave', '站南大道', 'arterial', 18,
     [[-70, 515], [-70, 560], [-70, 610], [-70, 695], [-70, 755]],
     elev=[26, 18], note='广场→晴岚主桥（跨河 z≈588）→站前广场→车站', walk=4)
road('ring_north', '环城北街', 'collector', 12,
     [[-915, 245], [-700, 238], [-380, 232], [-70, 228], [185, 236], [258, 300], [264, 380]],
     elev=[26, 26], note='沿城墙内侧，串联北门与各区北缘')
road('east_wall_rd', '城东南街', 'collector', 12,
     [[264, 380], [268, 450], [270, 560], [268, 650], [270, 740], [262, 880], [242, 965]],
     elev=[26, 18], note='东墙内侧南北向，接东南门')
road('port_ave', '港湾大道', 'collector', 14,
     [[-365, 450], [-365, 540], [-372, 600], [-385, 623]],
     elev=[26, 13], note='市政核心→港务机构带的下坡主通道')
road('quay_north', '北岸码头街', 'collector', 12,
     [[-640, 623], [-540, 623], [-450, 623], [-370, 623], [-300, 632], [-262, 650]],
     elev=[13, 13], note='港务机构带临水一线；临水侧为装卸广场（13m 台地）')
road('west_highstreet', '西城高街', 'collector', 12,
     [[-912, 245], [-912, 330], [-910, 450], [-908, 560], [-906, 660], [-902, 770],
      [-878, 868], [-842, 905]],
     elev=[55, 20], note='西城南北骨架：公馆带→西城街坊→圣堂区→西南居住')
road('palace_court_rd', '宫环路', 'local', 8,
     [[-865, 356], [-865, 252], [-838, 242], [-790, 238], [-742, 242], [-715, 252], [-715, 356]],
     elev=[60, 60], note='总督宫 U 形礼仪环路')
road('academy_ave', '学院大道', 'collector', 12,
     [[-510, 450], [-510, 405], [-510, 368]], elev=[26, 44], note='王冠大道爬台地进学院前广场')
road('academy_west', '学院西巷', 'local', 8, [[-592, 280], [-592, 368]], elev=[44, 44])
road('academy_east', '学院东巷', 'local', 8, [[-428, 286], [-428, 368]], elev=[44, 44])
road('cathedral_ave', '圣堂大道', 'local', 10,
     [[-906, 655], [-840, 662], [-800, 668]], elev=[24, 38], note='西城高街→圣堂前广场')
road('riverside_n', '河滨北街', 'local', 9,
     [[-365, 550], [-180, 550], [-40, 550], [40, 550]], elev=[23, 23],
     note='日常服务巷：锻铁/精工/旅店/浴池沿街北面朝街')
road('riverside_s', '河滨南街', 'local', 9,
     [[-160, 608], [-40, 608], [40, 608], [160, 608], [200, 600]], elev=[18, 18],
     note='河湾街坊临河面')
road('east_embankment', '东河沿街', 'collector', 12,
     [[268, 450], [268, 505], [252, 545], [238, 568], [230, 592], [218, 622],
      [206, 655], [198, 690], [194, 720]],
     elev=[26, 18], note='跨东河桥（z≈580）下到车站区，接站前横街')
road('station_front', '站前横街', 'collector', 12,
     [[-155, 735], [15, 735], [175, 735], [268, 742]], elev=[18, 18],
     note='站前广场南缘横街，连东南门方向')
road('station_east_v', '车站东街', 'local', 9, [[55, 690], [55, 865]], elev=[18, 18])
road('station_east_h1', '站东一巷', 'local', 9, [[64, 800], [225, 800]], elev=[18, 18])
road('station_east_h2', '站东二巷', 'local', 9, [[64, 868], [230, 868]], elev=[18, 18])
road('gulf_street', '湾前街', 'local', 10,
     [[-160, 692], [-20, 692], [120, 692], [238, 696]], elev=[18, 18],
     note='v7 新增：河湾坊与车站区之间缺失的横街，兼作湾岸第二排街')
road('east_quay', '湾东岸街', 'local', 10,
     [[-152, 700], [-150, 780], [-142, 860], [-120, 920], [-90, 952], [0, 972], [160, 962]],
     elev=[18, 15], note='湾东滨水步道；南段接轮渡栈桥')
road('harbor_ramp', '西埠坡道', 'collector', 12,
     [[-662, 610], [-682, 648], [-716, 690], [-730, 740], [-730, 800], [-716, 850],
      [-700, 878], [-684, 892]],
     elev=[13, 13], note='港务带下到货栈/船坞的岸线通道（西侧走货、东侧卸货）')
road('west_mid_rd', '西城中街', 'local', 9, [[-910, 460], [-590, 460]], elev=[38, 30],
     note='西城居住街坊北缘')
road('west_cross', '西城横街', 'local', 10,
     [[-908, 580], [-790, 580], [-690, 580], [-640, 598]], elev=[28, 13])
road('terrace_lane', '台地巷', 'local', 8, [[-670, 245], [-670, 450]], elev=[58, 30],
     note='官邸台地与学院台地之间')
road('market_lane', '商贸支巷', 'local', 9, [[128, 232], [128, 450]], elev=[26, 26],
     note='v7 修正：原 x=140 穿过城东上坊，西移至 x=128 街廊中心')
road('east_rd', '城东支街', 'local', 9, [[252, 232], [252, 450]], elev=[26, 26])
road('north_h', '北城横街', 'local', 9, [[-345, 320], [250, 320]], elev=[26, 26])
road('civic_west_v', '市政西街', 'local', 9, [[-345, 232], [-345, 450]], elev=[26, 26])
road('civic_mid_v', '西城坊巷', 'local', 9, [[-240, 232], [-240, 450]], elev=[26, 26])
road('axis_lane_w', '轴西巷', 'alley', 5, [[-110, 232], [-110, 330]], elev=[26, 26])
road('axis_lane_e', '轴东巷', 'alley', 5, [[-30, 232], [-30, 330]], elev=[26, 26])
road('rail_corridor', '铁路走廊（白盒）', 'rail', 12,
     [[268, 885], [175, 878], [60, 878], [-30, 872]],
     note='站房后方；走向需与 goldenear 线及 v5 轨道几何核对')
road('pier_walk', '轮渡栈桥（白盒）', 'path', 8, [[-142, 862], [-172, 896]])
road('breakwater', '防波堤（白盒）', 'path', 7, [[-372, 990], [-425, 1048]])

P['bridges'] = [
    dict(id='main_bridge', cn='晴岚主桥', at=[-70, 588], span=18, road='station_ave'),
    dict(id='east_bridge', cn='东河桥', at=[232, 580], span=14, road='east_embankment'),
    dict(id='foot_w1', cn='染坊步行桥（白盒）', at=[-150, 596], span=16, road='', whitebox=True),
    dict(id='foot_e1', cn='鱼市步行桥（白盒）', at=[110, 582], span=14, road='', whitebox=True),
]

# ---------------------------------------------------------------- 2. 广场/庭园
square('civic_square', '中央十字广场', -65, 450, 220, 130, 26)
square('station_square', '站前广场', -70, 725, 170, 60, 18)
square('academy_square', '学院前广场', -510, 368, 150, 56, 44)
square('cathedral_square', '圣堂前广场', -787, 672, 90, 56, 38)
square('dock_apron', '港口装卸广场', -470, 640, 190, 22, 13)
square('rw_market', '河湾市集', 96, 652, 44, 22, 18)
garden('palace_court', '总督宫 U 形前庭', -790, 322, 170, 76, 60, 'court')
garden('palace_axis', '官邸轴线花园', -790, 408, 120, 80, 60)
garden('academy_garden', '学院阅读园', -510, 330, 96, 30, 44)
garden('cathedral_south', '圣堂南园', -785, 845, 110, 48, 38)
garden('seaside_park', '海湾公园', 113, 929, 98, 48, 18, 'park')
garden('axis_lawn_w', '北轴西草坪', -125, 285, 26, 110, 26, 'lawn')
garden('axis_lawn_e', '北轴东草坪', -8, 285, 26, 110, 26, 'lawn')
garden('civic_south_g', '市政南园', -148, 419, 70, 30, 26, 'park')
garden('m1_gdn', '财政大臣园', -888, 352, 30, 24, 60)
garden('m2_gdn', '提督园', -692, 350, 30, 24, 60)

# ---------------------------------------------------------------- 3. 地标（v6 坐标原样保留）
Y = dict(gov=60, aca=44, civ=26, cat=38, sta=18, port=13, west=32)

add('civic', 'civic_hall', -65, 368, 0, Y['civ'], '市政厅（银行在开放首层）')
add('wb_fountain', 'wb_fountain', -65, 450, 0, Y['civ'], '广场喷泉（白盒）')
add('archive', 'academy_library_3', -172, 372, 0, Y['civ'], '城市档案馆')
add('court', 'public_house', -134, 372, 0, Y['civ'], '裁定厅')
add('welfare', 'shop_arcade_3', -6, 372, 0, Y['civ'], '社会保障局')
add('tax', 'shop_arcade_3', 24, 372, 0, Y['civ'], '税务局')
add('exchange', 'public_house', -120, 527, 180, Y['civ'], '交易所（拍卖行）')
add('guild', 'guild_hall', -215, 519, 90, Y['civ'], '冒险者公会')
add('inn', 'inn_seafarer_3', -205, 578, 180, 23, '旅人之歌旅店')
add('artisan', 'shop_arcade_3', -163, 578, 180, 23, '精工行会')
add('smith', 'shop_arcade_3', -121, 578, 180, 23, '锻铁匠行会')
add('bath', 'public_house', -300, 578, 180, 23, '公共浴池')
add('stable', 'shop_arcade_3', -260, 578, 180, 23, '车马行（v7 修正：原 x=15 压在河道中心线上）')
add('market', 'trade_hall', 80, 350, 180, Y['civ'], '万国博览集市')
add('merchant', 'courtyard_college_3', 185, 290, 270, Y['civ'], '商会总部')
add('cook', 'shop_arcade_3', 185, 368, 270, Y['civ'], '烹饪师行会')
add('weapon_shop', 'shop_arcade_3', 90, 486, 180, Y['civ'], '武器店')
add('armor_shop', 'shop_arcade_3', 122, 486, 180, Y['civ'], '防具店')
add('jeweler', 'shop_arcade_3', 154, 486, 180, Y['civ'], '珠宝店')
add('florist', 'shop_arcade_3', 210, 486, 180, Y['civ'], '花店')
add('palace', 'governor_palace', -790, 300, 0, Y['gov'], '总督宫')
add('finance_minister', 'mansion_garden_3', -888, 305, 90, Y['gov'], '财政大臣公馆')
add('ambassador', 'mansion_garden_3', -888, 382, 90, Y['gov'], '外交使馆')
add('admiral', 'mansion_garden_3', -692, 302, 270, Y['gov'], '海军提督公馆')
add('airship_pad', 'wb_tower', -894, 228, 0, Y['gov'], '飞艇坪塔（白盒）', cat='infra')
add('academy', 'academy', -510, 296, 0, Y['aca'], '皇家学院')
add('library', 'academy_library_3', -572, 300, 90, Y['aca'], '公共图书馆')
add('scholar', 'courtyard_college_3', -455, 300, 270, Y['aca'], '学者行会')
add('institute', 'courtyard_college_3', -462, 412, 270, 40, '魔导研究所')
add('mage', 'magic_tower', -480, 256, 0, Y['aca'], '魔法师行会')
add('lodg1', 'academy_lodgings_4', -580, 258, 0, Y['aca'], '学生宿舍')
add('lodg2', 'academy_lodgings_4', -548, 258, 0, Y['aca'], '学生宿舍')
add('customs', 'public_house', -570, 592, 0, Y['port'], '海关')
add('terminal', 'public_house', -448, 592, 0, Y['port'], '海运客运站')
add('canal', 'shop_arcade_3', -335, 592, 0, Y['port'], '漕运局')
add('tavern', 'inn_seafarer_3', -620, 592, 0, Y['port'], '海鸥酒馆')
add('blackmarket', 'shop_arcade_3', -679, 556, 0, 20, '旧巷货行')
for i, (aid, wz) in enumerate([('warehouse_stone_1', 715), ('warehouse_brick_2', 757),
                                ('wb_warehouse', 800), ('wb_warehouse', 843)]):
    add('wh%d' % i, aid, -688 if i < 3 else -682, wz, 0, Y['port'], '货栈' if aid in WHITE else '')
add('shipyard', 'warehouse_stone_1', -733, 916, 0, Y['port'], '海军船坞')
add('wb_crane1', 'wb_crane', -530, 638, 0, Y['port'], '港吊（白盒）')
add('wb_crane2', 'wb_crane', -358, 640, 0, Y['port'], '港吊（白盒）')
add('wb_pier_shed', 'wb_pier_shed', -660, 930, 0, Y['port'], '埠头棚（白盒）')
add('cathedral', 'cathedral', -785, 762, 180, Y['cat'], '晴岚大圣堂')
add('hospital', 'public_house', -845, 765, 0, Y['cat'], '圣堂医院')
add('clergy', 'courtyard_college_3', -856, 700, 0, Y['cat'], '修士院')
add('station', 'station', -70, 812, 180, Y['sta'], '晴岚中央车站')
add('opera', 'opera', 0, 930, 0, Y['sta'], '晴岚歌剧院')
for gid, gx, gz in [('n1', -88, 210), ('n2', -52, 210), ('e1', 284, 425),
                    ('e2', 284, 475), ('s1', 252, 722), ('s2', 252, 758)]:
    add('gate_' + gid, 'wb_tower', gx, gz, 0, 30, '城门塔（白盒）', cat='infra')
add('wb_arch', 'wb_clock_arch', -70, 330, 0, Y['civ'], '北门钟拱（白盒，跨北门大道）')
add('wb_lighthouse', 'wb_lighthouse', -425, 1048, 0, 13, '外港灯塔（白盒）')
# v7 新增白盒：2 座步行桥 + 河湾市集水井
add('wb_foot_w1', 'wb_footbridge', -150, 596, 90, 18, '染坊步行桥（白盒，跨河）', cat='infra')
add('wb_foot_e1', 'wb_footbridge', 110, 582, 90, 18, '鱼市步行桥（白盒，跨河）', cat='infra')
add('wb_fnt_rw', 'wb_fountain', 96, 648, 0, 18, '河湾市集水井（白盒）', cat='infra')

# ---------------------------------------------------------------- 4. 街坊填充
# 资产池：FABRIC=白板联排商住屋（老城密织）；MIX=新城大住宅；RICH=西城体面住宅
FABRIC = ['wb_rowhouse'] * 4 + ['wb_shophouse'] * 4 + ['residence_slate_3', 'shop_rose_4']
FABRIC_SLIM = ['wb_rowhouse'] * 5 + ['wb_shophouse'] * 4
MIX = ['residence_ochre_4', 'shop_rose_4', 'residence_slate_3',
       'corner_merchants_3', 'wb_shophouse', 'corner_copper_4']
RICH = ['residence_slate_3', 'mansion_garden_3', 'residence_ochre_4', 'corner_copper_4']
PORT_MIX = ['wb_shophouse'] * 3 + ['warehouse_brick_2', 'wb_warehouse', 'wb_pier_shed']

# (id, 中文名, x0, z0, x1, z1, y, 池, 内院用途)
BLOCKS = [
    # —— 市政/商贸台地 y=26（居住坊全部密织联排）——
    ('CN1', '西北坊', -330, 246, -252, 306, 26, FABRIC, '花园'),
    ('CN2', '中北坊', -228, 246, -146, 306, 26, FABRIC, '花园（原市政北园）'),
    ('CN3', '轴东坊', -16, 246, 116, 306, 26, FABRIC, '晾晒场'),
    ('CN4', '东北坊', 140, 246, 204, 306, 26, FABRIC, '货车院'),
    ('CM1', '西桥坊', -330, 332, -252, 436, 26, FABRIC, '花园'),
    ('CM2', '西坊南', -228, 332, -192, 436, 26, FABRIC, '杂院'),
    ('CM4', '商贸西巷坊', 48, 376, 116, 438, 26, FABRIC, '作坊后院'),
    ('CB0', '商贸北带坊', 140, 330, 238, 350, 26, FABRIC, '货车院'),
    ('CS1', '广场西北坊', -330, 462, -252, 498, 26, FABRIC, '货棚'),
    ('CS2', '广场西南坊', -330, 506, -248, 540, 26, FABRIC, '杂院'),
    ('CS3', '广场南坊', -16, 517, 116, 540, 26, FABRIC, '市场后场'),
    ('CS4', '城东南坊', 160, 502, 238, 540, 26, FABRIC, '花园'),
    ('CE1', '商贸南坊', 140, 396, 238, 436, 26, FABRIC, '货物院'),
    # —— 河湾老城 y=18（白板密织；站南大道 x=-70 穿中，故分东西两坊）——
    ('RW1', '河湾西坊', -160, 618, -84, 682, 18, FABRIC, '染坊晾晒院'),
    ('RW1B', '河湾东口坊', -58, 618, -30, 682, 18, FABRIC, '杂院'),
    ('RW2', '河湾东坊', 15, 618, 160, 682, 18, FABRIC, '鱼市后场'),
    # —— 车站区 y=18（站前横街 z≈735 分隔南北带）——
    ('EB0', '站东南坊', 64, 700, 164, 726, 18, FABRIC, '旅舍后院'),
    ('EB1', '站东一坊', 64, 748, 164, 788, 18, FABRIC, '旅舍内院'),
    ('EB2', '站东二坊', 64, 806, 164, 858, 18, FABRIC, '货物转运院'),
    ('EB3', '站东三坊', 176, 748, 236, 788, 18, FABRIC, '杂院'),
    ('EB4', '站东四坊', 176, 808, 238, 858, 18, FABRIC, '货棚'),
    # —— 西城 y=28-32（公馆区保持疏朗）——
    ('WM1', '西城中坊', -860, 470, -745, 555, 32, RICH, '花园'),
    ('WM2', '西城东坊', -735, 470, -600, 555, 28, RICH, '花园'),
    ('WM4', '西城下坊', -858, 592, -742, 646, 30, FABRIC, '菜园'),
    # —— 港务坡地/湾北 ——
    ('WP1', '港北坊', -586, 474, -404, 550, 20, FABRIC, '渔具后场'),
    ('WP2', '埠头坊', -624, 690, -540, 728, 13, PORT_MIX, '缆绳场'),
    ('WQ1', '港市东坊', -248, 462, -90, 500, 26, FABRIC, '鱼货院'),
    # —— 台地坡地补坊（v7b 新增）——
    ('AC1', '学院南坊', -618, 408, -524, 440, 34, FABRIC, '学生晾晒场'),
    ('AC2', '学院南小坊', -444, 408, -400, 440, 34, FABRIC, '杂院'),
    ('CQ1', '圣堂东坡坊', -758, 598, -706, 648, 20, FABRIC, '药草园'),
    # —— 湾南货棚（铁路与海岸之间）——
    ('SB1', '港南货棚坊', 170, 895, 235, 945, 15, PORT_MIX, '煤场'),
]

fill_report = []

def try_place(x, z, yaw, aid, y):
    w, d = ALL_FP[aid]
    bb = bbox(x, z, w, d, yaw, 0.6)
    if any(overlap(bb, o) for o in occupied):
        return False
    if not road_clear(bb, 0.6):
        return False
    cx, cz = (bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2
    if not on_land(cx, cz, 6.0):
        return False
    return True

def fill_row(bid, placed, fixed, lo, hi, yaw, y, pool, rng, along='x'):
    """沿一条红线走刀摆放：along='x' 时 fixed=z（横排），along='z' 时 fixed=x（竖排）。
    走向步进用建筑宽度 w；剩余跨度放不下当前资产时尝试更小的资产，全放不下才收行。"""
    n = 0
    c = lo
    since_gap = 0
    while True:
        remain = hi - c
        aid = None
        for _ in range(5):  # 试着找一个放得下的资产
            cand = pool[rng.randrange(len(pool))]
            if ALL_FP[cand][0] <= remain:
                aid = cand
                break
        if aid is None:  # 回退：池里最小的资产能放下就用它
            small = min(pool, key=lambda a: ALL_FP[a][0])
            if ALL_FP[small][0] <= remain:
                aid = small
            else:
                break
        w, _d = ALL_FP[aid]
        center = c + w / 2
        cx, cz = (center, fixed) if along == 'x' else (fixed, center)
        if since_gap >= 4 and rng.random() < 0.5:
            c += 7.0          # 巷口
            since_gap = 0
            continue
        if rng.random() < 0.06:
            c += 3.5          # 小缝隙（院门）
            since_gap = 0
            continue
        if try_place(cx, cz, yaw, aid, y):
            add('%s_%d' % (bid, placed[0]), aid, cx, cz, yaw, y, '')
            placed[0] += 1
            n += 1
            since_gap += 1
            c += w + rng.uniform(1.2, 2.4)
        else:
            c += 2.5          # 冲突则小步试探跳过
            since_gap = 0
    return n

def fill_block(bid, cn, x0, z0, x1, z1, y, pool, court_use):
    rng = random.Random(zlib.crc32(bid.encode()))
    placed = [0]
    depth = z1 - z0
    width = x1 - x0
    # 统计落点可建率，太低直接放弃（防水中/坡上街坊）
    samples = sum(1 for i in range(6) for j in range(6)
                  if on_land(x0 + width * (i + .5) / 6, z0 + depth * (j + .5) / 6, 10))
    if samples < 22:
        fill_report.append('%s %s: 落点可建率低(%d/36)，跳过' % (bid, cn, samples))
        return
    counts = {}
    if depth < 38:
        # 浅街坊：背靠背联排，单排双朝向同时服务两条街（老城典型肌理）
        zc = (z0 + z1) / 2
        n = 0
        c = x0 + 6
        idx = 0
        while True:
            remain = x1 - 6 - c
            aid = None
            for _ in range(5):
                cand = pool[rng.randrange(len(pool))]
                if ALL_FP[cand][0] <= remain:
                    aid = cand
                    break
            if aid is None:  # 回退：最小资产
                small = min(pool, key=lambda a: ALL_FP[a][0])
                if ALL_FP[small][0] <= remain:
                    aid = small
                else:
                    break
            w, _ = ALL_FP[aid]
            yaw = 180 if idx % 2 == 0 else 0
            if try_place(c + w / 2, zc, yaw, aid, y):
                add('%s_%d' % (bid, placed[0]), aid, c + w / 2, zc, yaw, y, '')
                placed[0] += 1
                n += 1
                c += w + rng.uniform(1.2, 2.2)
            else:
                c += 2.5
            idx += 1
        counts['B2B'] = n
    else:
        # 联排梯田式密织：每 16m（公馆区 26m）一排，排排交替朝向，
        # 排间 2-6m 形成弄堂；整坊被连续屋面覆盖（参考图的老城肌理）。
        # 多排坊只能用窄资产（进深 ≤15m），否则会挤进下一排的条带。
        if pool is PORT_MIX:
            counts['WH'] = fill_row(bid, placed, (z0 + z1) / 2, x0 + 6, x1 - 6, 180, y, pool, rng)
        else:
            pitch = 26 if pool is RICH else 16
            rpool = pool if pool is RICH else FABRIC_SLIM
            if depth < 44:
                rows = [(z0 + 11, 180), (z1 - 11, 0)]
            else:
                rows = []
                z = z0 + 11
                k = 0
                while z <= z1 - 11:
                    rows.append((z, 180 if k % 2 == 0 else 0))
                    k += 1
                    z += pitch
            for ri, (zc, yaw) in enumerate(rows):
                counts['R%d' % ri] = fill_row(bid, placed, zc, x0 + 5, x1 - 5, yaw, y, rpool, rng)
    members = [b['id'] for b in P['buildings'] if b['id'].startswith(bid + '_')]
    P['blocks'].append(dict(id=bid, cn=cn, buildingIds=members, rect=[x0, z0, x1, z1],
                            court=[round((x0 + x1) / 2), round((z0 + z1) / 2)],
                            courtUse=court_use, elev=y))
    fill_report.append('%s %s: %d 栋 %s' % (bid, cn, len(members), counts))

for bid, cn, x0, z0, x1, z1, y, pool, court in BLOCKS:
    fill_block(bid, cn, x0, z0, x1, z1, y, pool, court)

# ---------------------------------------------------------------- 5. 分区底色
P['districts'] = [
    dict(id='governor', cn='官邸区', color=[150, 186, 160],
         poly=[[-936, 215], [-668, 215], [-668, 300], [-660, 402], [-790, 470], [-936, 470]]),
    dict(id='academy', cn='学院区', color=[176, 156, 214],
         poly=[[-668, 215], [-390, 215], [-390, 470], [-510, 470], [-620, 400], [-640, 300]]),
    dict(id='civic', cn='市政区', color=[214, 190, 150],
         poly=[[-390, 215], [-115, 215], [-115, 385], [-175, 515], [-365, 515], [-390, 385]]),
    dict(id='commerce', cn='商贸区', color=[224, 170, 120],
         poly=[[-115, 215], [230, 215], [265, 300], [268, 470], [45, 515], [45, 385], [-115, 385]]),
    dict(id='port', cn='港务区', color=[150, 176, 200],
         poly=[[-660, 470], [-290, 470], [-262, 650], [-320, 660], [-470, 655],
               [-550, 660], [-620, 700], [-715, 720], [-715, 520]]),
    dict(id='cathedral', cn='圣堂区', color=[196, 196, 210],
         poly=[[-936, 600], [-830, 600], [-760, 660], [-760, 800], [-830, 900], [-880, 930], [-936, 900]]),
    dict(id='station', cn='车站区（湾东）', color=[200, 170, 170],
         poly=[[-176, 660], [-115, 660], [-115, 684], [235, 684], [268, 740], [262, 880],
               [242, 965], [150, 1000], [0, 990], [-120, 940], [-176, 900]]),
    dict(id='riverward', cn='河湾坊', color=[190, 200, 170],
         poly=[[-185, 596], [45, 596], [45, 684], [-150, 684], [-185, 655]]),
]

# ---------------------------------------------------------------- 6. NPC（v6 契约原样）
npc('mayor', -65, 394, 180, 26.6); npc('banker', -85, 394, 180, 26.6); npc('banker2', -45, 394, 180, 26.6)
npc('auctioneer', -120, 512, 180, 26.6)
npc('guild_master', -199, 512, 90, 26.6); npc('guild_reg', -199, 532, 90, 26.6)
npc('t_warrior_3', -231, 512, 90, 26.6); npc('t_rogue_3', -231, 532, 90, 26.6)
npc('judge', -134, 386, 0, 26.6); npc('archivist', -172, 386, 0, 26.6)
npc('welfare_officer', -6, 386, 0, 26.6); npc('tax_officer', 24, 386, 0, 26.6)
npc('clock_keeper', -70, 342, 0, 26.6)
npc('inn_keeper2', -205, 562, 180, 23.6); npc('artisan_master', -163, 562, 180, 23.6)
npc('smith_master', -121, 562, 180, 23.6); npc('bath_attendant', -300, 562, 180, 23.6)
npc('stable_city', -260, 562, 180, 23.6)
npc('expo_guide', 80, 376, 0, 26.6)
for nid, dx, dz in [('transmog', -14, 8), ('rare_shop', 14, 8), ('potion_shop', -14, -8), ('item_shop', 14, -8)]:
    npc(nid, 80 + dx, 350 + dz, 180 if dz > 0 else 0, 26.6)
npc('merchant_head', 168, 290, 270, 26.6); npc('cook_master', 168, 368, 270, 26.6)
npc('weapon_shop', 90, 472, 180, 26.6); npc('armor_shop', 122, 472, 180, 26.6)
npc('jeweler', 154, 472, 180, 26.6); npc('florist', 210, 472, 180, 26.6)
npc('governor', -790, 338, 0, 60.6); npc('butler', -776, 338, 0, 60.6)
npc('finance_minister', -874, 305, 90, 60.6); npc('ambassador', -874, 382, 90, 60.6)
npc('admiral', -706, 302, 270, 60.6)
npc('airship_captain', -886, 240, 0, 60.6); npc('astronomer', -898, 240, 270, 60.6)
npc('lecturer', -522, 322, 0, 44.6); npc('scholar_master', -498, 322, 0, 44.6)
npc('librarian', -561, 300, 90, 44.6); npc('scholar', -469, 300, 270, 44.6)
npc('researcher', -476, 400, 270, 40.6); npc('mage_master', -480, 268, 0, 44.6)
npc('t_mage_3', -498, 258, 180, 44.6)
npc('customs_officer', -570, 578, 0, 13.6); npc('ferry_clerk', -448, 578, 0, 13.6)
npc('harbor_master', -430, 632, 180, 13.6); npc('canal_officer', -335, 578, 0, 13.6)
npc('tavern_keeper', -620, 578, 0, 13.6); npc('black_marketeer', -679, 568, 180, 20.6)
npc('warehouse_keeper', -688, 700, 180, 13.6); npc('shipwright', -733, 900, 0, 13.6)
npc('dock_worker', -664, 700, 90, 13.6); npc('dock_worker', -662, 830, 90, 13.6)
npc('sailor', -505, 634, 180, 13.6); npc('sailor', -483, 634, 180, 13.6)
npc('merchant_captain', -452, 634, 180, 13.6)
npc('archbishop', -785, 712, 180, 38.6); npc('clergy', -856, 716, 0, 38.6)
npc('doctor', -845, 751, 180, 38.6); npc('nurse', -831, 751, 180, 38.6)
npc('station_master', -70, 782, 180, 18.6)
npc('opera_manager', 0, 908, 0, 18.6); npc('park_keeper', 113, 912, 0, 18.6)
npc('lighthouse_keeper', -425, 1036, 180, 13.6)
for gx, gz in [(282, 438), (282, 462), (-70, 216), (270, 752)]:
    npc('guard_city', gx, gz, 90, 28)
for gx, gz in [(-65, 400), (-65, 500), (15, 430)]:
    npc('guard_city_f', gx, gz, 180, 26)
# v7 新增街坊市民（补充城市人口活动，不占用契约 ID 语义）
for x, z, y in [(96, 662, 18), (100, 660, 18), (-190, 660, 18), (114, 764, 18),
                (-670, 524, 30), (-660, 522, 30), (-296, 520, 22), (-292, 524, 22),
                (244, 320, 26), (-320, 320, 26), (-800, 620, 38), (170, 962, 15)]:
    npc('citizen', x, z, 180, y)

# ---------------------------------------------------------------- 7. POI / 出生点（v6 契约原样）
poi('poi_solenne', '晴岚港', -300, 440, 780, 1)
poi('poi_plaza', '中央十字广场', -65, 450, 60, 10)
poi('poi_market', '万国博览集市', 80, 356, 43, 10)
poi('poi_governor', '总督宫', -790, 305, 45, 12)
poi('poi_academy', '皇家学院', -510, 302, 40, 12)
poi('poi_cathedral', '晴岚大圣堂', -785, 762, 47, 10)
poi('poi_station', '晴岚中央车站', -70, 812, 52, 10)
poi('poi_guild', '冒险者公会', -215, 522, 23, 12)
poi('poi_exchange', '交易所', -120, 530, 23, 12)
poi('poi_smith', '锻铁匠行会', -121, 578, 13, 14)
poi('poi_artisan', '精工行会', -163, 578, 13, 14)
poi('poi_city_inn', '旅人之歌旅店', -205, 578, 17, 20)
poi('poi_harbor', '晴岚港湾', -460, 660, 60, 8)
poi('poi_south_port', '南港埠头', -660, 900, 25, 9)
poi('poi_lighthouse', '外港灯塔', -425, 1048, 24, 12)
poi('poi_park', '海湾公园', 113, 940, 55, 9)
poi('poi_airport', '海角飞艇坪', -894, 230, 28, 10)
poi('poi_citygate', '东门', 292, 450, 28, 10)
poi('poi_citygate_n', '北门', -70, 205, 26, 10)
poi('poi_citygate_se', '东南门', 270, 740, 28, 10)
poi('poi_canal', '晴岚运河', -50, 590, 130, 3)
poi('poi_rw_market', '河湾市集', 96, 648, 26, 8)

P['spawns'] = [
    dict(id='fp_solenne', p=[-889, 235], yaw=180),
    dict(id='st_solenne', p=[-70, 748], yaw=0),
    dict(id='gy_gate', p=[300, 470], yaw=270),
    dict(id='gy_cathedral', p=[-820, 800], yaw=0),
    dict(id='city_inn_safe', p=[-205, 552], yaw=180),
]

# ---------------------------------------------------------------- 8. 设计说明
P['notes'] = [
    ['v7 主旨', '回应"城市不能只有地标和功能建筑"：在完全保留 v6 地标/机构/路网骨架与全部 NPC/POI/出生点契约的前提下，把街坊重建为 31 个联排密织街坊，全城建筑从 94 栋提升到 349 栋。全部居住坊采用联排梯田式密织（每 16m 一排、排排交替朝向、排间弄堂），多排坊只用窄资产 wb_rowhouse（12×10）与 wb_shophouse（16×14），符合"白盒优先、Tripo 精模后补"的既定流程。'],
    ['双轴十字', '王冠大道（东门→中央广场→官邸，西段 8% 缓坡爬官邸台地）× 北门大道/站南大道（北门→市政厅立面→晴岚主桥→车站）。四向视线终点不变。'],
    ['路网分级', '主干 20/18m → 次干 12-14m → 支路 9m → 后巷 5m，全部贯通。v7 修正：商贸支巷 x140→x128（原路穿过东北坊）；新增湾前街（河湾坊与车站区之间缺失的横街，也是湾岸第二排商业街）。'],
    ['街墙与内院', '每坊四边临街建筑沿红线连续排布（随机 1-3m 缝隙，每 4-6 栋留 7m 巷口），进深 ≥64m 的街坊内加共享内院后排。内院用途逐坊指派：花园/晾晒场/货物院/菜园/染坊晾晒院等，后巷生活由此成立。'],
    ['新旧肌理', '居住坊全部联排密织（FABRIC_SLIM 窄资产，16m 排距）；西城公馆区 WM1/WM2 用 RICH 池 26m 排距保留体面身份；埠头坊/港南货棚坊单排大仓库面街（PORT_MIX）。浅坊（进深<38m）用背靠背单排双朝向。v7b 新增：CM4 商贸西巷坊、CB0 商贸北带坊、AC1/AC2 学院南坊、CQ1 圣堂东坡坊。'],
    ['城东窄坊', '东墙与城东支街之间 20m 窄带排单列墙根屋，消化城墙内侧死空间（真实城市城墙内的典型肌理）。'],
    ['港水关系', '湾内不架低桥；港务机构带后退一线临北岸码头街；货栈列+船坞经西埠坡道下埠头；东岸滨水步道+轮渡栈桥。v7 新增 2 座跨河步行桥（染坊桥/鱼市桥，白盒）把河湾南北两岸步行连成环——参考图中支流水网城市的多桥特征。'],
    ['人口活动', 'v6 的 40 名市民之外新增 12 名街坊市民散布内院口/市场/埠头（市民 ID 为通用类型，不破坏契约）。河湾市集（鱼市小广场+水井白盒）给河湾坊一个生活锚点。'],
    ['删除项', 'v6 的 SW1 站西坊（一半在湾水里）删除；civic_green 市政北园（与中北坊重叠）改为中北坊共享内院。'],
    ['与 v6 契约', '全部地标/机构建筑坐标不变；71+ NPC ID、POI ID、5 出生点 ID 不变；三座城门不动；车站位置不变（不再有 v6 的车站西移遗留问题）。白盒新增：2 步行桥+3 内院喷泉+河湾市集水井+联排商住屋——待列入 Tripo3D 模型需求。'],
    ['待定问题', '① wb_shophouse（16×14）与 wb_rowhouse（12×10）联排商住屋的 Tripo 建模（建议做成 3-5 开间联排变体，一个模型覆盖多户以支撑 200+ 实例）；② 街坊内院入口门楼是否需要；③ 铁路与 goldenear 线衔接（沿 v6 遗留）；④ 站东坊与湾东岸街之间的滨水货棚带密度。'],
]

# ---------------------------------------------------------------- 9. 冲突自检
issues = []
for a in P['buildings']:
    bb = bbox(a['c'][0], a['c'][1], a['size'][0], a['size'][1], a['yaw'], 0)
    if a['asset'] not in ALLOW_ROAD and not road_clear(bb, -0.5):
        issues.append('road-hit: ' + a['id'])
    if a['asset'] not in ALLOW_ROAD and not on_land((bb[0] + bb[2]) / 2, (bb[1] + bb[3]) / 2, 4.0):
        issues.append('water/wall: ' + a['id'])
    for b in P['buildings']:
        if b['id'] <= a['id']:
            continue
        bb2 = bbox(b['c'][0], b['c'][1], b['size'][0], b['size'][1], b['yaw'], 0)
        if overlap(bb, bb2):
            issues.append('bld-overlap: %s x %s' % (a['id'], b['id']))
    for s in P['squares']:
        sb = [s['c'][0] - s['size'][0] / 2, s['c'][1] - s['size'][1] / 2,
              s['c'][0] + s['size'][0] / 2, s['c'][1] + s['size'][1] / 2]
        if overlap(bb, sb) and not a.get('whitebox'):
            depth = min(bb[2], sb[2]) - max(bb[0], sb[0])
            depth_z = min(bb[3], sb[3]) - max(bb[1], sb[1])
            if min(depth, depth_z) > 6:
                issues.append('square-hit: %s x %s' % (a['id'], s['id']))

out = OUT / 'draft.json'
out.write_text(json.dumps(P, ensure_ascii=False, indent=1), encoding='utf8')
print('buildings:', len(P['buildings']), '(whitebox:', sum(1 for b in P['buildings'] if b.get('whitebox')), ')')
print('roads:', len(P['roads']), 'blocks:', len(P['blocks']),
      'npcs:', len(P['npcs']), 'pois:', len(P['pois']))
for line in fill_report:
    print(' ', line)
print('conflicts:', len(issues))
for i in issues[:40]:
    print(' -', i)
