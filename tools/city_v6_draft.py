"""晴岚港 v6 规划草案（仅规划，不进游戏）。

原则（真实城市规划 + MMO 主城逻辑）：
1. 路网分级：主干道(18-20m) / 次干道(12-14m) / 支路(9m) / 后巷(5m)，先定贯通路网再填街坊。
2. 双轴结构：王冠大道（东门→中央广场→官邸，东西轴）；北门大道（北门→市政厅立面，视线终点）
   + 站南大道（广场→晴岚主桥→站前广场→车站）。轴在广场内为石铺广场段，不画车行道。
3. 高频服务环：银行(市政厅)/拍卖(交易所)/锻铁/精工/旅店/公会/浴池/车马行 全在中央广场 250m 内。
4. 港水关系：北岸机构带后退一线临北岸码头街；货栈/船坞沿西埠坡道下到埠头；湾内不架低桥；
   东岸设滨水步道与轮渡栈桥（白盒）。
5. 街坊：13 个周边式街坊——建筑面街、共享内院、转角让位形成出入口。
6. 地标独立场地与前庭：总督宫(U庭+轴花园)、学院(前广场)、圣堂(前广场+南园)、车站(站前广场)。
7. 现有 22 种建筑资产全部复用；新增构筑物一律白盒（wb_*）。

输出：docs/city_v6/draft.json（含编辑器所需全部数据）。
"""
import json, math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
V5 = json.loads((ROOT / 'docs/city_v5/layout.json').read_text(encoding='utf8'))
OUT = ROOT / 'docs/city_v6'
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
}
ALL_FP = {**FP, **WB}
WHITE = set(WB)
# 白盒/城门塔允许骑跨道路（拱门、塔楼、堤端灯塔）
ALLOW_ROAD = {'wb_clock_arch', 'wb_fountain', 'wb_lighthouse', 'wb_tower',
              'wb_crane', 'wb_pier_shed'}

P = dict(
    version=6, water=8, draft=True,
    coast_west=V5['coast_west'], coast_south=V5['coast_south'],
    river=V5['river'], wall=V5['wall'], gates=V5['gates'], terraces=V5['terraces'],
    roads=[], buildings=[], gardens=[], squares=[], districts=[], blocks=[],
    npcs=[], pois=[], spawns=[], bridges=[], notes=[],
)

def bbox(x, z, w, d, yaw, pad=0.0):
    a = math.radians(yaw)
    wx = abs(math.cos(a)) * w + abs(math.sin(a)) * d
    dz = abs(math.sin(a)) * w + abs(math.cos(a)) * d
    return [x - wx / 2 - pad, z - dz / 2 - pad, x + wx / 2 + pad, z + dz / 2 + pad]

def overlap(a, b):
    return a[0] < b[2] and a[2] > b[0] and a[1] < b[3] and a[3] > b[1]

occupied = []

def segdist(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / max(dx * dx + dz * dz, 1e-9)))
    return math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dz)

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

# ---------------------------------------------------------------- 1. 路网
road('crown_ave', '王冠大道', 'arterial', 20,
     [[292, 450], [140, 450], [45, 450]], elev=[26, 26],
     note='东西主轴东段：东门→中央广场（广场内为石铺段，不设车行道）')
road('crown_west', '王冠大道西段', 'arterial', 20,
     [[-175, 450], [-365, 450], [-520, 450], [-660, 446], [-760, 438], [-790, 424], [-790, 362]],
     elev=[26, 60], note='广场→爬坡（430m 升 34m≈8%）→官邸前庭；西端视线终点=总督宫')
road('north_ave', '北门大道', 'arterial', 18,
     [[-70, 205], [-70, 330]], elev=[30, 26], note='北门→中央广场；视线终点=市政厅立面',
     walk=4)
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
road('station_east_h1', '站东一巷', 'local', 9, [[55, 800], [225, 800]], elev=[18, 18])
road('station_east_h2', '站东二巷', 'local', 9, [[55, 868], [230, 868]], elev=[18, 18])
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
road('market_lane', '商贸支巷', 'local', 9, [[140, 232], [140, 450]], elev=[26, 26])
road('east_rd', '城东支街', 'local', 9, [[250, 232], [250, 450]], elev=[26, 26])
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
]

# ---------------------------------------------------------------- 2. 广场/庭园
square('civic_square', '中央十字广场', -65, 450, 220, 130, 26)
square('station_square', '站前广场', -70, 725, 170, 60, 18)
square('academy_square', '学院前广场', -510, 368, 150, 56, 44)
square('cathedral_square', '圣堂前广场', -787, 672, 90, 56, 38)
square('dock_apron', '港口装卸广场', -470, 640, 190, 22, 13)
garden('palace_court', '总督宫 U 形前庭', -790, 322, 170, 76, 60, 'court')
garden('palace_axis', '官邸轴线花园', -790, 408, 120, 80, 60)
garden('academy_garden', '学院阅读园', -510, 330, 96, 30, 44)
garden('cathedral_south', '圣堂南园', -785, 845, 110, 48, 38)
garden('seaside_park', '海湾公园', 113, 929, 98, 48, 18, 'park')
garden('axis_lawn_w', '北轴西草坪', -125, 285, 26, 110, 26, 'lawn')
garden('axis_lawn_e', '北轴东草坪', -8, 285, 26, 110, 26, 'lawn')
garden('civic_green', '市政北园', -180, 262, 80, 24, 26, 'park')
garden('m1_gdn', '财政大臣园', -888, 352, 30, 24, 60)
garden('m2_gdn', '提督园', -692, 350, 30, 24, 60)

# ---------------------------------------------------------------- 3. 地标
Y = dict(gov=60, aca=44, civ=26, cat=38, sta=18, port=13, west=32)

# 市政核心：中央十字广场（北门大道视线终点=市政厅立面）
add('civic', 'civic_hall', -65, 368, 0, Y['civ'], '市政厅（银行在开放首层）')
add('wb_fountain', 'wb_fountain', -65, 450, 0, Y['civ'], '广场喷泉（白盒）')
add('archive', 'academy_library_3', -172, 372, 0, Y['civ'], '城市档案馆')
add('court', 'public_house', -134, 372, 0, Y['civ'], '裁定厅')
add('welfare', 'shop_arcade_3', -6, 372, 0, Y['civ'], '社会保障局')
add('tax', 'shop_arcade_3', 24, 372, 0, Y['civ'], '税务局')
add('exchange', 'public_house', -120, 527, 180, Y['civ'], '交易所（拍卖行）')
add('guild', 'guild_hall', -215, 519, 90, Y['civ'], '冒险者公会')
# 日常服务巷（拍卖/广场南侧，沿河滨北街一字排开，面北朝街）
add('inn', 'inn_seafarer_3', -205, 578, 180, 23, '旅人之歌旅店')
add('artisan', 'shop_arcade_3', -163, 578, 180, 23, '精工行会')
add('smith', 'shop_arcade_3', -121, 578, 180, 23, '锻铁匠行会')
add('bath', 'public_house', -300, 578, 180, 23, '公共浴池')
add('stable', 'shop_arcade_3', 15, 578, 180, 23, '车马行')
# 商贸：博览集市 + 商会 + 临街商铺（东门来向）
add('market', 'trade_hall', 80, 350, 180, Y['civ'], '万国博览集市')
add('merchant', 'courtyard_college_3', 185, 290, 270, Y['civ'], '商会总部')
add('cook', 'shop_arcade_3', 185, 368, 270, Y['civ'], '烹饪师行会')
add('weapon_shop', 'shop_arcade_3', 90, 486, 180, Y['civ'], '武器店')
add('armor_shop', 'shop_arcade_3', 122, 486, 180, Y['civ'], '防具店')
add('jeweler', 'shop_arcade_3', 154, 486, 180, Y['civ'], '珠宝店')
add('florist', 'shop_arcade_3', 210, 486, 180, Y['civ'], '花店')
# 官邸高地
add('palace', 'governor_palace', -790, 300, 0, Y['gov'], '总督宫')
add('finance_minister', 'mansion_garden_3', -888, 305, 90, Y['gov'], '财政大臣公馆')
add('ambassador', 'mansion_garden_3', -888, 382, 90, Y['gov'], '外交使馆')
add('admiral', 'mansion_garden_3', -692, 302, 270, Y['gov'], '海军提督公馆')
add('airship_pad', 'wb_tower', -894, 228, 0, Y['gov'], '飞艇坪塔（白盒）', cat='infra')
# 学院台地
add('academy', 'academy', -510, 296, 0, Y['aca'], '皇家学院')
add('library', 'academy_library_3', -572, 300, 90, Y['aca'], '公共图书馆')
add('scholar', 'courtyard_college_3', -455, 300, 270, Y['aca'], '学者行会')
add('institute', 'courtyard_college_3', -462, 412, 270, 40, '魔导研究所')
add('mage', 'magic_tower', -480, 256, 0, Y['aca'], '魔法师行会')
add('lodg1', 'academy_lodgings_4', -580, 258, 0, Y['aca'], '学生宿舍')
add('lodg2', 'academy_lodgings_4', -548, 258, 0, Y['aca'], '学生宿舍')
# 港务带（机构后退一线，面南朝北岸码头街）
add('customs', 'public_house', -570, 592, 0, Y['port'], '海关')
add('terminal', 'public_house', -448, 592, 0, Y['port'], '海运客运站')
add('canal', 'shop_arcade_3', -335, 592, 0, Y['port'], '漕运局')
add('tavern', 'inn_seafarer_3', -620, 592, 0, Y['port'], '海鸥酒馆')
add('blackmarket', 'shop_arcade_3', -679, 556, 0, 20, '旧巷货行')
# 西岸货栈列 + 船坞
for i, (aid, wz) in enumerate([('warehouse_stone_1', 715), ('warehouse_brick_2', 757),
                                ('wb_warehouse', 800), ('wb_warehouse', 843)]):
    add('wh%d' % i, aid, -688 if i < 3 else -682, wz, 0, Y['port'], '货栈' if aid in WHITE else '')
add('shipyard', 'warehouse_stone_1', -733, 916, 0, Y['port'], '海军船坞')
add('wb_crane1', 'wb_crane', -530, 638, 0, Y['port'], '港吊（白盒）')
add('wb_crane2', 'wb_crane', -358, 640, 0, Y['port'], '港吊（白盒）')
add('wb_pier_shed', 'wb_pier_shed', -660, 930, 0, Y['port'], '埠头棚（白盒）')
# 圣堂海岬
add('cathedral', 'cathedral', -785, 762, 180, Y['cat'], '晴岚大圣堂')
add('hospital', 'public_house', -845, 765, 0, Y['cat'], '圣堂医院')
add('clergy', 'courtyard_college_3', -856, 700, 0, Y['cat'], '修士院')
# 车站区
add('station', 'station', -70, 812, 180, Y['sta'], '晴岚中央车站')
add('opera', 'opera', 0, 930, 0, Y['sta'], '晴岚歌剧院')
# 城门白盒塔楼
for gid, gx, gz in [('n1', -88, 210), ('n2', -52, 210), ('e1', 284, 425),
                    ('e2', 284, 475), ('s1', 252, 722), ('s2', 252, 758)]:
    add('gate_' + gid, 'wb_tower', gx, gz, 0, 30, '城门塔（白盒）', cat='infra')
add('wb_arch', 'wb_clock_arch', -70, 330, 0, Y['civ'], '北门钟拱（白盒，跨北门大道）')
add('wb_lighthouse', 'wb_lighthouse', -425, 1048, 0, 13, '外港灯塔（白盒）')

# ---------------------------------------------------------------- 4. 街坊自动填充（周边式）
RES = ['residence_slate_3', 'residence_ochre_4', 'shop_rose_4',
       'corner_merchants_3', 'residence_slate_3', 'corner_copper_4']
BLOCKS = [
    ('N1', '市政北坊', -330, 240, -245, 312, 26, RES),
    ('N2', '学院东坊', -235, 240, -150, 312, 26, RES),
    ('W3', '西桥坊', -330, 328, -245, 435, 26, RES),
    ('W4', '西坊南', -235, 328, -185, 435, 26, RES),
    ('E1', '城东上坊', 135, 240, 245, 312, 26, RES),
    ('E2', '城东下坊', 135, 328, 245, 435, 26, RES),
    ('RW1', '河湾西坊', -160, 618, -30, 688, 18, RES),
    ('RW2', '河湾东坊', 15, 618, 160, 688, 18, RES),
    ('WM1', '西城中坊', -860, 470, -745, 555, 32, RES),
    ('WM2', '西城东坊', -735, 470, -600, 555, 28, RES),
    ('EB1', '站东上坊', 62, 690, 165, 792, 18, RES),
    ('EB2', '站东下坊', 62, 808, 165, 862, 18, RES),
    ('SW1', '站西坊', -225, 760, -130, 862, 18, RES),
]

def fill_block(bid, x0, z0, x1, z1, y, types):
    placed = 0
    lanes = 6.0
    def try_place(x, z, yaw, i):
        aid = types[i % len(types)]
        w, d = ALL_FP[aid]
        bb = bbox(x, z, w, d, yaw, 0.6)
        if any(overlap(bb, o) for o in occupied):
            return False
        if not road_clear(bb, 0.6):
            return False
        add('%s_%d' % (bid, placed), aid, x, z, yaw, y, '')
        return True
    zN = z0 + 11
    xs, i = x0 + lanes, 0
    while xs < x1 - lanes:
        w, _ = ALL_FP[types[i % len(types)]]
        if try_place(xs + w / 2, zN, 180, i):
            placed += 1; i += 1
        xs += w + 1.5
    zS = z1 - 11
    xs, i = x0 + lanes, 1
    while xs < x1 - lanes:
        w, _ = ALL_FP[types[i % len(types)]]
        if try_place(xs + w / 2, zS, 0, i):
            placed += 1; i += 1
        xs += w + 1.5
    zW, i = z0 + 22, 2
    while zW < z1 - 22:
        _, d = ALL_FP[types[i % len(types)]]
        if try_place(x0 + 10.5, zW + d / 2, 270, i):
            placed += 1; i += 1
        zW += d + 1.5
    zE, i = z1 - 22, 3
    while zE > z0 + 22:
        _, d = ALL_FP[types[i % len(types)]]
        if try_place(x1 - 10.5, zE - d / 2, 90, i):
            placed += 1; i += 1
        zE -= d + 1.5
    members = [b['id'] for b in P['buildings'] if b['id'].startswith(bid + '_')]
    P['blocks'].append(dict(id=bid, cn='', buildingIds=members,
                            rect=[x0, z0, x1, z1],
                            court=[round((x0 + x1) / 2), round((z0 + z1) / 2)]))

BLOCK_CN = {'N1': '市政北坊', 'N2': '学院东坊', 'W3': '西桥坊', 'W4': '西坊南',
            'E1': '城东上坊', 'E2': '城东下坊', 'RW1': '河湾西坊', 'RW2': '河湾东坊',
            'WM1': '西城中坊', 'WM2': '西城东坊', 'EB1': '站东上坊', 'EB2': '站东下坊',
            'SW1': '站西坊'}
for bid, cn, x0, z0, x1, z1, y, types in BLOCKS:
    fill_block(bid, x0, z0, x1, z1, y, types)
for b in P['blocks']:
    b['cn'] = BLOCK_CN[b['id']]

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
         poly=[[-180, 660], [-115, 660], [-115, 684], [235, 684], [268, 740], [262, 880],
               [242, 965], [150, 1000], [0, 990], [-120, 940], [-180, 860]]),
    dict(id='riverward', cn='河湾坊', color=[190, 200, 170],
         poly=[[-185, 596], [45, 596], [45, 684], [-150, 684], [-185, 655]]),
]

# ---------------------------------------------------------------- 6. NPC（契约ID复用）
npc('mayor', -65, 394, 180, 26.6); npc('banker', -85, 394, 180, 26.6); npc('banker2', -45, 394, 180, 26.6)
npc('auctioneer', -120, 512, 180, 26.6)
npc('guild_master', -199, 512, 90, 26.6); npc('guild_reg', -199, 532, 90, 26.6)
npc('t_warrior_3', -231, 512, 90, 26.6); npc('t_rogue_3', -231, 532, 90, 26.6)
npc('judge', -134, 386, 0, 26.6); npc('archivist', -172, 386, 0, 26.6)
npc('welfare_officer', -6, 386, 0, 26.6); npc('tax_officer', 24, 386, 0, 26.6)
npc('clock_keeper', -70, 342, 0, 26.6)
npc('inn_keeper2', -205, 562, 180, 23.6); npc('artisan_master', -163, 562, 180, 23.6)
npc('smith_master', -121, 562, 180, 23.6); npc('bath_attendant', -300, 562, 180, 23.6)
npc('stable_city', 15, 562, 180, 23.6)
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
for x, z, y in [(-160, 430, 26), (20, 430, 26), (-100, 340, 26), (160, 340, 26),
                (-505, 634, 13), (-688, 730, 13), (-70, 700, 18), (100, 750, 18),
                (-850, 500, 32), (-190, 660, 18), (100, 660, 18), (-785, 640, 38)]:
    npc('citizen', x, z, 180, y)

# ---------------------------------------------------------------- 7. POI / 出发点
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

P['spawns'] = [
    dict(id='fp_solenne', p=[-889, 235], yaw=180),
    dict(id='st_solenne', p=[-70, 748], yaw=0),
    dict(id='gy_gate', p=[300, 470], yaw=270),
    dict(id='gy_cathedral', p=[-820, 800], yaw=0),
    dict(id='city_inn_safe', p=[-205, 552], yaw=180),
]

# ---------------------------------------------------------------- 8. 设计说明
P['notes'] = [
    ['结构', '双轴十字：王冠大道（东西）与北站轴系（北门大道+站南大道）交汇于中央十字广场；东望东门、西望总督宫、北望市政厅立面、南望车站，四向都有视线终点。北门大道在广场北缘结束，市政厅正立面成为轴线对景（经典做法：广场尽端主立面）。'],
    ['路网分级', '主干道 20/18m（王冠大道、北门大道、站南大道）→ 次干道 12-14m（环城北街、港湾大道、码头街、西城高街、城东南街、东河沿街、站前横街）→ 支路 9m（坊间街）→ 后巷 5m。先网后坊，次街全部贯通接入主路，不再出现被剪断的断头路。'],
    ['日常服务环', '银行（市政厅首层）、拍卖（交易所）、锻铁、精工、旅店、冒险者公会、浴池、车马行全部在中央广场 250m 半径内；从东门进城沿主轴约 360m 即达服务核。商店行（武器/防具/珠宝）沿王冠大道南缘排布，迎东门来向客流。'],
    ['港水关系', '湾内不架低桥保通航；港务机构（海关/客运/漕运/酒馆）在 13m 北岸台地后退一线，面朝北岸码头街与装卸广场；货栈列+船坞经西埠坡道（西侧走货）下到埠头；东岸设滨水步道与轮渡栈桥（白盒）；外港灯塔由防波堤（白盒）接入。'],
    ['街坊制', '13 个周边式街坊：建筑面朝四边街道、共享内院、转角让位 6m 形成自然出入口，替代 v5 的折线随机排房。街坊尺寸约 85-110 × 55-107m。'],
    ['地标场地', '总督宫（U形前庭+轴线花园）、学院（前广场+阅读园）、圣堂（前广场+南园）、车站（站前广场）、博览集市（面向广场东北角）各有独立场地；中央广场四边：北=市政厅+机构排（档案/裁定/税务/保障），南=交易所+服务巷，东=商贸支巷口，西=公会+市政西街。'],
    ['高差', '官邸 60m → 学院 44m → 市政 26m → 车站 18m → 埠头 13m → 水面 8m；王冠大道西段 430m 爬 34m≈8% 缓坡；港湾大道/西埠坡道承担 26→13m 降落。各地块整平+挡墙，不用房屋四角埋地。'],
    ['白盒清单', '北门钟拱、广场喷泉、6 座城门塔、飞艇坪塔、2 台港吊、外港灯塔+防波堤、轮渡栈桥、埠头棚、2 栋货栈、铁路走廊——占位待建模。'],
    ['与 v5 契约', '71 个 NPC ID、主要 POI ID、5 个出生点 ID 语义不变；车站西移 130m 移到南北轴上（原 60,805 → -70,812），铁路走廊随之平移，需与 goldenear 线核对；三座城门位置不动；东门公路边界 (430,420)→(288,450) 不受影响。'],
    ['待定问题', '① 车站西移与 goldenear 铁路线的衔接；② 湾东岸街南端轮渡的开度；③ 圣堂大道 24→38m 接坡的坡道位置；④ 外城（下城区/篱田/河源）本轮未动；⑤ 街坊内院用途（市场/晾晒/花园）待逐坊指派。'],
]

# ---------------------------------------------------------------- 9. 冲突自检
issues = []
for a in P['buildings']:
    bb = bbox(a['c'][0], a['c'][1], a['size'][0], a['size'][1], a['yaw'], 0)
    if a['asset'] not in ALLOW_ROAD and not road_clear(bb, -0.5):
        issues.append('road-hit: ' + a['id'])
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
            # 临街建筑贴广场边属正常关系；白盒广场家具除外；深入广场 >6m 才算冲突
            depth = min(bb[2], sb[2]) - max(bb[0], sb[0])
            depth_z = min(bb[3], sb[3]) - max(bb[1], sb[1])
            if min(depth, depth_z) > 6:
                issues.append('square-hit: %s x %s' % (a['id'], s['id']))

out = OUT / 'draft.json'
out.write_text(json.dumps(P, ensure_ascii=False, indent=1), encoding='utf8')
print('buildings:', len(P['buildings']), '(whitebox:',
      sum(1 for b in P['buildings'] if b.get('whitebox')), ')')
print('roads:', len(P['roads']), 'blocks:', len(P['blocks']),
      'npcs:', len(P['npcs']), 'pois:', len(P['pois']))
print('conflicts:', len(issues))
for i in issues[:40]:
    print(' -', i)
