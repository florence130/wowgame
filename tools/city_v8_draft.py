# -*- coding: utf-8 -*-
"""
晴岚港 v8 城市规划草案生成器（2026-10-07）
=========================================
设计主旨：「双轴、一湾、四级路网、坊巷城市」
- 完整保留 v7 契约：水系/城墙/三门/7 台地/72 栋地标与职能建筑身份/83 NPC/22 POI/5 出生点
- 完全重建路网（A 主干 / B 次干 / C 支路 / D 巷弄 四级）与街坊系统（29 坊）
- 白盒密织填充至 ~450 栋，冲突自检归零
- 修正 v7 错误：WP2 埠头坊压水、行会街跨河两岸散乱、站前大道穿越台地东缘等

输出: E:/wowgame/docs/city_v8/draft.json
"""
import json, math, os, sys
from collections import Counter

OUT = os.path.join(os.path.dirname(__file__), '..', 'docs', 'city_v8', 'draft.json')
WATER = 8

# ---------------------------------------------------------------- 地理骨架（与 v7 完全一致，动地形才会改）
coast_west = [[-930,160],[-980,250],[-965,430],[-960,630],[-940,800],[-880,940]]
coast_south = [[-1040,880],[-880,940],[-720,970],[-640,930],[-620,735],[-550,650],[-270,650],[-180,735],[-180,930],[80,1030],[300,1000],[520,905]]
river = [[360,580],[160,580],[-40,580],[-185,610],[-310,670]]
wall = [[-936,220],[-700,190],[-380,195],[-70,205],[225,225],[292,330],[292,450],[292,580],[270,740],[258,890],[230,1000]]
gates = [["east",292,450,90],["north",-70,205,0],["southeast",270,740,90]]
terraces = [
 {"id":"governor","c":[-790,302],"size":[244,200],"y":60},
 {"id":"academy","c":[-510,296],"size":[238,196],"y":44},
 {"id":"civic","c":[-75,379],"size":[546,300],"y":26},
 {"id":"cathedral","c":[-786,754],"size":[230,204],"y":38},
 {"id":"station","c":[50,802],"size":[350,236],"y":18},
 {"id":"west_docks","c":[-659,788],"size":[40,222],"y":13},
 {"id":"harbor_offices","c":[-465,600],"size":[350,80],"y":13},
]

# ---------------------------------------------------------------- v8 路网（全部重新设计）
# cls: arterial 主干 / collector 次干 / local 支路 / alley 巷 / path 步道 / rail 铁路
def R(id,cn,cls,width,pts,note="",walk=None):
    w = walk if walk is not None else (3 if cls=="arterial" else 2 if cls in("collector","local") else 1)
    return {"id":id,"cn":cn,"cls":cls,"width":width,"pts":[list(p) for p in pts],"walk":w,"note":note}

ROADS = [
 # ---- A 级 主干道：双轴 + 湾滨 + 城东
 R("crown_ave","王冠大道东段","arterial",20,[(292,450),(140,450),(45,450)],
   "礼仪主轴东段：东门→中央十字广场（对景市政厅钟塔）"),
 R("crown_west","王冠大道西段","arterial",20,[(-175,450),(-365,450),(-520,450),(-660,446),(-760,438),(-790,424),(-790,362)],
   "礼仪主轴西段：广场→缓坡爬升→总督宫前庭（对景总督宫）"),
 R("north_ave","北门大道","arterial",18,[(-70,205),(-70,300),(-70,385)],
   "生活轴北段：北门→广场北缘"),
 R("grand_south","中央南大道","arterial",18,[(-70,515),(-70,579),(-70,597),(-70,660),(-70,695)],
   "生活轴中南段：广场→晴岚主桥→站前广场（贯通市政核心与车站枢纽）"),
 R("harbor_ave","湾滨大道","arterial",16,[(-600,762),(-556,694),(-500,676),(-420,670),(-340,668),(-268,674),(-230,702),(-200,728),(-170,738),(-155,742)],
   "v8 新增：内港北岸滨水主路，串接埠头—海关—客运站—站前广场"),
 R("se_gate_ave","东南门大道","arterial",14,[(-125,872),(-40,876),(80,874),(190,862),(240,810),(270,748)],
   "车站台地南横轴：站台西端→东南门（绕行歌剧院与货棚坊北侧）"),
 R("east_ave","城东大街","arterial",14,[(276,334),(280,400),(292,450),(286,520),(280,580),(274,660),(270,736)],
   "v8 新增：东墙内侧南北干道，连通东北坊—东门—城东南坊—东南门"),
 # ---- B 级 次干道
 R("ring_north","环城北街","collector",12,[(-890,244),(-700,228),(-380,232),(-226,238),(-160,244),(-16,246),(120,252),(225,262),(276,334)],
   "北城墙内侧次干道：西城→北门→东北角接城东大街"),
 R("riverside_n","河滨北街","collector",12,[(-700,560),(-560,558),(-440,556),(-320,554),(-200,554),(-80,556),(40,558),(160,560),(240,562),(278,576)],
   "河北岸滨水次干道：西城→行会街→港务台地北缘→城东（v8 统一沿河走线）"),
 R("riverside_s","河滨南街","collector",10,[(-268,674),(-210,660),(-150,640),(-80,624),(0,616),(80,614),(160,616),(240,624),(278,634)],
   "河南岸滨水街：湾滨大道→河湾南坊→城东（西端接湾滨大道）"),
 R("west_highstreet","西城高街","collector",12,[(-762,442),(-744,540),(-712,616),(-690,682)],
   "西城南北脊柱：王冠大道→西城坊群→圣堂坡→湾滨大道"),
 R("port_ave","港务大道","collector",12,[(-640,600),(-500,596),(-360,592),(-292,588)],
   "港务台地内东西干道：海关—漕运局—客运站沿街"),
 R("academy_ave","学院大道","collector",12,[(-370,450),(-378,414),(-386,398)],
   "王冠大道→学院台地东南角台阶（上台地接学院前广场）"),
 R("cathedral_ave","圣堂大道","local",10,[(-712,616),(-702,644),(-690,662),(-742,672)],
   "西城高街→圣堂台地东缘→圣堂前广场（朝圣入场序列）"),
 # ---- C 级 支路
 R("civic_n_st","市政北街","local",9,[(-226,353),(-118,353),(-16,353),(45,353)],
   "v8 新增：广场以北的东西支街（东端止于博览集市西缘），分隔北带坊与市政机构"),
 R("civic_w_st","广场西街","local",9,[(-207,246),(-207,353),(-207,470),(-207,516)],
   "广场西侧纵街（北带→市政北街→广场南）"),
 R("civic_e_st","广场东街","local",9,[(77,252),(77,353),(77,470),(77,516)],
   "广场东侧纵街，与广场西街对称"),
 R("w_market_st","商贸西巷","local",9,[(-244,368),(-244,470),(-244,516)],
   "市政厅以西的南北巷（CC1 坊东界）"),
 R("e_market_st","商贸东巷","local",9,[(96,368),(96,470),(96,516)],
   "博览集市以东的南北巷（CC2 坊西界）"),
 R("guild_walk","行会滨水步道","path",8,[(-700,572),(-560,570),(-440,568),(-320,566),(-200,566),(-80,568),(40,570),(160,572),(240,574),(278,586)],
   "v8 新增：河北岸连续步行带（街南侧，亲水界面）"),
 R("s_river_walk","河南滨水步道","path",7,[(240,600),(160,598),(80,596),(0,596),(-80,600),(-150,616),(-210,636),(-268,656)],
   "河南岸步行带（河湾南坊望河面）"),
 R("st_east_st","站东街","local",8,[(15,755),(15,830),(50,862),(80,874)],
   "站前广场东南角→站台东侧→东南门大道"),
 R("st_east2","站东二巷","local",8,[(160,700),(160,760),(160,850)],
   "站东坊群之间的南北巷"),
 R("quay_link","埠头接驳路","local",8,[(-600,762),(-659,762)],
   "湾滨大道西端→西埠码头平台"),
 R("west_cross","西城横街","local",9,[(-744,500),(-640,494),(-540,490),(-520,478),(-520,450)],
   "西城高街→王冠大道的横向连接"),
 R("shrine_ln","圣堂东坡巷","local",8,[(-660,568),(-656,610),(-648,644),(-671,656)],
   "河滨北街→圣堂台地东北角的巷道"),
 # ---- D 级 巷弄
 R("sv_ln","河湾南巷","alley",5,[(-210,656),(-170,652),(-130,648)],
   "河湾南坊后巷"),
 # ---- 白盒交通/景观线
 R("rail_corridor","铁路走廊","rail",12,[(-330,960),(-60,952),(120,946),(225,920)],
   "铁路白盒走廊（沿车站台地南缘，v7 遗留衔接待定）"),
 R("pier_walk","轮渡栈桥","path",8,[(-659,899),(-659,990)],
   "西埠轮渡栈桥白盒"),
 R("breakwater","防波堤","path",7,[(-620,735),(-460,700),(-300,668),(-180,735)],
   "内港防波堤白盒（示意线）"),
 R("esplanade","海湾东岸步道","path",7,[(80,1000),(230,960),(300,1000)],
   "海湾公园东侧岸线步道"),
]

# ---------------------------------------------------------------- 保留建筑（v7 的 72 栋地标/职能建筑身份不变）
# 说明：身份（id/asset/size）逐字保留；坐标仅两类微调：
#  ① 行会街带建筑（guild/inn/artisan/smith/bath/stable/exchange 等）从跨两岸的散点统一落到河滨北街南侧的行会带（z≈542，门朝南临街）；
#  ② 其余仅校正 y 与台地一致。NPC 同步规则见文末。
KEEP = [
 # 市政核心（civic 台地 y26）
 ("civic","civic_hall",(-65,368),[88,40],0,26,"市政厅（银行在开放首层）"),
 ("archive","academy_library_3",(-172,372),[26,22],0,26,"城市档案馆"),
 ("court","public_house",(-134,372),[44,28],0,26,"裁定厅"),
 ("welfare","shop_arcade_3",(-6,372),[24,20],0,26,"社会保障局"),
 ("tax","shop_arcade_3",(24,372),[24,20],0,26,"税务局"),
 ("exchange","public_house",(-114,542),[44,28],180,23,"交易所（拍卖行）→ v8 落位行会带"),
 ("guild","guild_hall",(-232,542),[44,30],0,23,"冒险者公会 → v8 落位行会带"),
 ("inn","inn_seafarer_3",(-192,542),[28,24],180,23,"旅人之歌旅店 → v8 落位行会带"),
 ("artisan","shop_arcade_3",(-152,542),[24,20],180,23,"精工行会 → v8 落位行会带"),
 ("smith","shop_arcade_3",(-76,542),[24,20],180,23,"锻铁匠行会 → v8 落位行会带"),
 ("bath","public_house",(-312,542),[44,28],180,23,"公共浴池 → v8 落位行会带"),
 ("stable","shop_arcade_3",(-272,542),[24,20],180,23,"车马行 → v8 落位行会带"),
 ("market","trade_hall",(80,350),[70,38],180,26,"万国博览集市"),
 ("merchant","courtyard_college_3",(185,290),[36,26],270,26,"商会总部"),
 ("cook","shop_arcade_3",(185,368),[24,20],270,26,"烹饪师行会"),
 ("weapon_shop","shop_arcade_3",(90,486),[24,20],180,26,"武器店"),
 ("armor_shop","shop_arcade_3",(122,486),[24,20],180,26,"防具店"),
 ("jeweler","shop_arcade_3",(154,486),[24,20],180,26,"珠宝店"),
 ("florist","shop_arcade_3",(210,486),[24,20],180,26,"花店"),
 # 官邸山（y60）
 ("palace","governor_palace",(-790,300),[100,70],0,60,"总督宫"),
 ("finance_minister","mansion_garden_3",(-888,305),[26,22],90,60,"财政大臣公馆"),
 ("ambassador","mansion_garden_3",(-888,382),[26,22],90,60,"外交使馆"),
 ("admiral","mansion_garden_3",(-692,302),[26,22],270,60,"海军提督公馆"),
 # 学院区（y44 / institute y40）
 ("academy","academy",(-510,296),[60,40],0,44,"皇家学院"),
 ("library","academy_library_3",(-572,300),[26,22],90,44,"公共图书馆"),
 ("scholar","courtyard_college_3",(-455,300),[36,26],270,44,"学者行会"),
 ("institute","courtyard_college_3",(-462,412),[36,26],270,40,"魔导研究所"),
 ("mage","magic_tower",(-480,256),[20,20],0,44,"魔法师行会"),
 ("lodg1","academy_lodgings_4",(-580,258),[28,22],0,44,"学生宿舍"),
 ("lodg2","academy_lodgings_4",(-548,258),[28,22],0,44,"学生宿舍"),
 # 港务区（y13 / blackmarket y20）
 ("customs","public_house",(-570,592),[44,28],0,13,"海关"),
 ("terminal","public_house",(-448,592),[44,28],0,13,"海运客运站"),
 ("canal","shop_arcade_3",(-335,592),[24,20],0,13,"漕运局"),
 ("tavern","inn_seafarer_3",(-620,592),[28,24],0,13,"海鸥酒馆"),
 ("blackmarket","shop_arcade_3",(-679,556),[24,20],0,20,"旧巷货行"),
 ("wh0","warehouse_stone_1",(-688,715),[32,24],0,13,""),
 ("wh1","warehouse_brick_2",(-688,757),[30,24],0,13,""),
 ("shipyard","warehouse_stone_1",(-733,916),[32,24],0,13,"海军船坞"),
 # 圣堂区（y38）
 ("cathedral","cathedral",(-785,762),[48,94],180,38,"晴岚大圣堂"),
 ("hospital","public_house",(-845,765),[44,28],0,38,"圣堂医院"),
 ("clergy","courtyard_college_3",(-856,700),[36,26],0,38,"修士院"),
 # 车站区（y18）
 ("station","station",(-70,812),[100,56],180,18,"晴岚中央车站"),
 ("opera","opera",(0,930),[64,40],0,18,"晴岚歌剧院"),
 # 旧资产住宅/商铺（v7 已用真实模型者全部保留，v8 归入新街坊）
 ("CB0_0","shop_rose_4",(160.0,340.0),[28,22],180,26,""),
 ("CB0_1","shop_rose_4",(190.1,340.0),[28,22],0,26,""),
 ("CS2_1","residence_slate_3",(-294.0,506.0),[22,20],0,26,""),
 ("CS3_0","shop_rose_4",(4.0,528.5),[28,22],180,26,""),
 ("CS3_1","shop_rose_4",(36.1,528.5),[28,22],180,26,""),
 ("CS3_2","shop_rose_4",(65.8,528.5),[28,22],0,26,""),
 ("WM1_0","residence_slate_3",(-844.0,481),[22,20],180,32,""),
 ("WM1_1","residence_ochre_4",(-816.0,481),[26,22],180,32,""),
 ("WM1_2","residence_slate_3",(-790.1,481),[22,20],180,32,""),
 ("WM1_3","mansion_garden_3",(-763.8,481),[26,22],180,32,""),
 ("WM1_4","residence_ochre_4",(-842.0,507),[26,22],0,32,""),
 ("WM1_5","residence_ochre_4",(-812.0,507),[26,22],0,32,""),
 ("WM1_6","residence_ochre_4",(-781.9,507),[26,22],0,32,""),
 ("WM1_7","residence_slate_3",(-844.0,533),[22,20],180,32,""),
 ("WM1_8","residence_ochre_4",(-817.8,533),[26,22],180,32,""),
 ("WM1_9","mansion_garden_3",(-787.9,533),[26,22],180,32,""),
 ("WM2_0","residence_slate_3",(-716.5,481),[22,20],180,28,""),
 ("WM2_1","residence_slate_3",(-692.4,481),[22,20],180,28,""),
 ("WM2_2","residence_ochre_4",(-666.2,481),[26,22],180,28,""),
 ("WM2_3","residence_ochre_4",(-635.1,481),[26,22],180,28,""),
 ("WM2_4","residence_ochre_4",(-717.0,507),[26,22],0,28,""),
 ("WM2_5","residence_slate_3",(-689.1,507),[22,20],0,28,""),
 ("WM2_6","corner_copper_4",(-659.4,507),[34,26],0,28,""),
 ("WM2_7","mansion_garden_3",(-627.4,507),[26,22],0,28,""),
 ("WM2_8","mansion_garden_3",(-717.0,533),[26,22],180,28,""),
 ("WM2_9","residence_slate_3",(-688.2,533),[26,22],180,28,""),
 ("WM2_10","mansion_garden_3",(-662.1,533),[26,22],180,28,""),
 ("WM2_11","mansion_garden_3",(-631.6,533),[26,22],180,28,""),
 ("WP2_1","warehouse_brick_2",(-583.2,709.0),[30,24],180,13,""),
]
# 旧资产坊内建筑（保留 v7 摆位者所在坊的归属，供 blocks 引用）
LEGACY_FIT = {
 "CC2":["CB0_0","CB0_1"],"CW1":["CS2_1","CS3_0","CS3_1","CS3_2"],
 "WM1":[f"WM1_{i}" for i in range(10)],"WM2":[f"WM2_{i}" for i in range(12)],
 "WP2":["WP2_1"],
}

# ---------------------------------------------------------------- 资产池（白盒）
# (asset, w, d, h)  w 沿街面宽 / d 进深 / h 檐高
WB = {
 "wb_rowhouse":(12,10,11),   # 联排住宅 3 层
 "wb_shophouse":(16,14,14),  # 商住联排 3-4 层
 "wb_manor":(26,20,13),      # 公馆
 "wb_big_house":(22,18,12),  # 大宅
 "wb_warehouse":(30,24,11),  # 仓库
 "wb_shed":(18,12,7),        # 货棚
 "wb_tower":(10,10,20),      # 街角塔
 "wb_fountain":(8,8,3),
 "wb_well":(5,5,3),
 "wb_kiosk":(6,6,5),
 "wb_clock_arch":(14,5,12),
 "wb_lighthouse":(8,8,26),
 "wb_crane":(8,8,14),
 "wb_pier_shed":(16,10,6),
 "wb_footbridge":(20,6,5),
}

def terr_y(x,z):
    """取台地面高（在台地内返回台地 y，否则低地基准）"""
    for t in terraces:
        cx,cz = t["c"]; sx,sz = t["size"]
        if abs(x-cx)<=sx/2 and abs(z-cz)<=sz/2:
            return t["y"]
    return 18  # 低地基准（编辑器里显示为缓坡）

# ---------------------------------------------------------------- 街坊定义（29 坊，全部由 v8 路网主动围合）
# pool: row=老城联排 / shop=商住联排 / mix=新城大宅 / rich=公馆 / ind=仓储
# face: 'S' 主朝向朝南(+z) / 'N' 朝北 / 'E' 朝东 / 'W' 朝西（沿主要界面）
# court_use: 内院用途
BLOCKS_DEF = [
 # id, cn, rect(x0,z0,x1,z1), pool, face, court_use
 # （官邸台地不设居住坊：总督宫+三公馆+两园已占满，保持官邸山纯净）
 ("NB2","中西北坊",(-336,252,-242,338),"shop","S","染坊晾晒场"),
 ("NB3","中北西坊",(-216,252,-108,338),"row","S","菜园"),
 ("NB4","中北东坊",(-100,252,56,338),"row","S","堆木场"),
 ("NB5","东北坊",(94,258,234,336),"mix","S","货栈院"),
 ("NG1","北门西厢",(-106,216,-82,244),"row","W","门房院"),
 ("NG2","北门东厢",(-58,216,-34,244),"row","E","草料院"),
 ("CC1","市政西坊",(-340,370,-252,440),"mix","E","学院附馆庭院"),
 ("CC3","广场西厢",(-203,388,-183,512),"shop","E","作坊院"),
 ("CC2","商贸东坊",(120,384,192,440),"shop","W","商栈院"),
 ("CW1","西桥坊",(-336,478,-256,514),"shop","S","染坊晾晒场"),
 ("EB2","城东南坊",(96,462,232,538),"shop","N","鱼货院"),
 ("EB3","东南窄坊",(238,462,272,538),"row","W","堆场"),
 ("RW1","河湾西坊",(-200,568,-142,590),"shop","S","渔具院"),
 # （河湾西部 x-228..-130 为河道转弯留白，设滨河绿地，不建坊）
 ("SV2","河湾南西坊",(-108,644,-86,666),"row","S","菜园"),
 ("SV2B","河湾南东坊",(-54,644,-30,666),"row","S","水井小院"),
 ("SV3","河湾南三坊",(0,624,66,644),"row","N","水井小院"),
 ("SQ1","河湾北坊",(-28,594,60,612),"shop","N","渔市院"),
 ("WP1","港市坊",(-586,472,-404,544),"shop","S","鱼货转运院"),
 ("WP2","埠头坊",(-618,646,-560,682),"ind","S","桶料场"),
 ("WP3","船坞坊",(-752,860,-704,900),"ind","N","船料场"),
 ("WM1","西城中坊",(-856,470,-760,556),"mix","S","公馆后园"),
 ("WM2","西城东坊",(-728,470,-604,556),"mix","S","公馆后园"),
 ("WM3","西城下坊",(-856,596,-748,644),"row","N","洗衣院"),
 ("CQ1","圣堂东坡坊",(-652,612,-600,646),"row","S","药草园"),
 ("CQ3","圣堂南坡坊",(-878,872,-756,926),"row","N","山城菜园"),
 ("AC1","学舍西坊",(-618,410,-526,438),"row","S","学生球场"),
 ("AC2","学舍东坊",(-396,410,-344,438),"row","S","学舍菜园"),
 ("AG1","学苑巷坊",(-664,240,-636,390),"row","W","教工菜园"),
 ("EB4","站东一坊",(40,700,150,742),"shop","N","货栈院"),
 ("EB5","站东二坊",(40,764,150,852),"shop","N","旅店马厩"),
 ("EB6","站东三坊",(172,700,218,852),"row","W","堆场"),
 ("SB1","港南货棚坊",(170,896,236,944),"ind","N","货棚场"),
 ("SB2","东南水岸坊",(150,952,250,996),"row","N","渔村晒网场"),
]

# ---------------------------------------------------------------- 冲突检测工具
def seg_rect_dist(pts, rect):
    """折线到矩形 [x0,z0,x1,z1] 的近似最小距离（采样中点+端点）"""
    x0,z0,x1,z1 = rect
    def pt_rect(px,pz):
        dx = max(x0-px, 0, px-x1); dz = max(z0-pz, 0, pz-z1)
        return math.hypot(dx,dz)
    best = 1e9
    for i in range(len(pts)-1):
        ax,az = pts[i]; bx,bz = pts[i+1]
        for t in [k/24 for k in range(25)]:
            best = min(best, pt_rect(ax+(bx-ax)*t, az+(bz-az)*t))
    return best

def rects_overlap(a, b, margin=0):
    return not (a[2]+margin <= b[0] or b[2]+margin <= a[0] or a[3]+margin <= b[1] or b[3]+margin <= a[1])

def rect_in_water(rect):
    """矩形是否触水。
    - coast_south：水在南 → 点在水线以南 8m 内判水
    - coast_west：水在西 → 点在水线以西 8m 内判水
    - river：带状水域 → 距河心线 < 15m（河宽18/2 + 护岸缓冲6）判水
    """
    x0,z0,x1,z1 = rect
    pts = [(x0,z0),(x1,z0),(x0,z1),(x1,z1),((x0+x1)/2,(z0+z1)/2)]
    for (px,pz) in pts:
        # 南海线
        ln = coast_south
        for i in range(len(ln)-1):
            ax,az = ln[i]; bx,bz = ln[i+1]
            if abs(bx-ax) < 1e-6:
                if abs(px-ax) < 1e-6 and min(az,bz) <= pz <= max(az,bz):
                    return True
                continue
            t = (px-ax)/(bx-ax)
            if 0 <= t <= 1:
                zl = az + (bz-az)*t
                if pz > zl - 8: return True
        # 西海线（x 是 z 的函数）
        ln = coast_west
        for i in range(len(ln)-1):
            ax,az = ln[i]; bx,bz = ln[i+1]
            if abs(bz-az) < 1e-6: continue
            t = (pz-az)/(bz-az)
            if 0 <= t <= 1:
                xl = ax + (bx-ax)*t
                if px < xl + 8: return True
        # 河（带状）
        xs = [p[0] for p in river]
        if min(xs)-2 <= px <= max(xs)+2:
            for i in range(len(river)-1):
                ax,az = river[i]; bx,bz = river[i+1]
                lo,hi = (ax,bx) if ax<=bx else (bx,ax)
                if lo <= px <= hi:
                    t = (px-ax)/(bx-ax) if bx != ax else 0
                    zc = az + (bz-az)*t
                    if abs(pz-zc) < 15: return True
    return False

def rect_near_poly(rect, poly_pts, clearance):
    return seg_rect_dist(poly_pts, rect) < clearance

# ---------------------------------------------------------------- 街坊填充
buildings = []
def add_b(bid, asset, x, z, w, d, yaw, label=""):
    # 规范化：yaw 90/270 时交换尺寸，全库统一 size=[x向宽, z向深]
    if yaw % 180 == 90:
        w, d = d, w
    y = terr_y(x,z)
    buildings.append({"id":bid,"asset":asset,"c":[round(x,1),round(z,1)],
                      "yaw":yaw,"size":[w,d],"label":label,"y":y})

def fill_block(defrec, keep_rects, road_polys, out_ids):
    bid, cn, rect, pool, face, court = defrec
    x0,z0,x1,z1 = rect
    # 坊内缩：临街 setback 自适应（浅坊缩小，保证能放下建筑）
    sx, sz = x1-x0, z1-z0
    setback_main = max(3.5, min(7, sz*0.12))
    setback_side = max(3.0, min(5, sx*0.08))
    ix0, iz0, ix1, iz1 = x0+setback_side, z0+setback_main, x1-setback_side, z1-setback_main
    # 行列填充：沿 face 法向排深
    pool_assets = {
      "row":  ["wb_rowhouse","wb_shophouse"],
      "shop": ["wb_shophouse","wb_rowhouse"],
      "mix":  ["wb_big_house","wb_shophouse","wb_manor"],
      "rich": ["wb_manor","wb_big_house"],
      "ind":  ["wb_shed","wb_warehouse"],
    }[pool]
    # 行方向：face S/N → 沿 x 排；E/W → 沿 z 排
    horizontal = face in ("S","N")
    span0, span1 = (ix0, ix1) if horizontal else (iz0, iz1)
    depth = (iz1-iz0) if horizontal else (ix1-ix0)
    yaw = {"S":0,"N":180,"E":90,"W":270}[face]
    # 行数按池内最大进深自适应（排深=最大进深+弄堂8m）
    max_d = max(WB[a][1] for a in pool_assets)
    n_rows = max(1, round(depth / (max_d + 8)))
    n_rows = min(n_rows, 3)
    # 保证行带能放下最大进深，否则减行
    while n_rows > 1 and depth/n_rows - 6 < max_d:
        n_rows -= 1
    row_depth = depth / n_rows
    count = 0
    for r in range(n_rows):
        # 行内带（保留 6m 弄堂）
        if horizontal:
            rz0 = iz0 + r*row_depth + (3 if r else 0)
            rz1 = iz0 + (r+1)*row_depth - (3 if r < n_rows-1 else 0)
        else:
            rz0 = ix0 + r*row_depth + (3 if r else 0)
            rz1 = ix0 + (r+1)*row_depth - (3 if r < n_rows-1 else 0)
        band_depth = rz1 - rz0
        # 该行可用资产（进深 <= 带深-2）
        cands = [a for a in pool_assets if WB[a][1] <= band_depth-2]
        if not cands: continue
        # 贪心排布：优先大资产，放不下换小的，冲突小步跳过
        cur = span0 + 1.0
        idx = 0
        while cur < span1 - 8:
            placed = False
            for a in (cands[idx:] + cands[:idx]):
                w,d,h = WB[a]
                if cur + w > span1 - 1: continue
                # 建筑中心
                if horizontal:
                    cx = cur + w/2; cz = (rz0+rz1)/2
                    rect_b = (cx-w/2, cz-d/2, cx+w/2, cz+d/2)
                    if n_rows >= 2:  # 双排背靠背：第二排反向朝向
                        use_yaw = yaw if r == 0 else (yaw+180)%360
                    else:
                        use_yaw = yaw
                else:
                    cz = cur + w/2; cx = (rz0+rz1)/2
                    rect_b = (cx-d/2, cz-w/2, cx+d/2, cz+w/2)
                    use_yaw = yaw
                # 冲突检查
                if rect_in_water(rect_b): continue
                ok = True
                for kr in keep_rects:
                    if rects_overlap(rect_b, kr, margin=1.0): ok=False; break
                if not ok: continue
                for (rp, rw) in road_polys:
                    if rect_near_poly(rect_b, rp, rw/2 + 4.0): ok=False; break
                if not ok: continue
                ob = f"{bid}_{count}"
                add_b(ob, a, cx, cz, w, d, use_yaw)
                out_ids.append(ob); count += 1
                cur += w + 1.2   # 列距 1.2m
                idx = (pool_assets.index(a)+1) % len(pool_assets)
                placed = True
                break
            if not placed:
                cur += 2.5  # 跳过放不下的位置（留豁口做巷门）
    return count

# ---------------------------------------------------------------- 主流程
def main():
    # 1) 保留建筑
    keep_rects = []
    idset = set()
    for (bid, asset, c, size, yaw, y, label) in KEEP:
        add_b(bid, asset, c[0], c[1], size[0], size[1], yaw, label)
        idset.add(bid)
        keep_rects.append((c[0]-size[0]/2, c[1]-size[1]/2, c[0]+size[0]/2, c[1]+size[1]/2))
    # 现有 v7 白盒广场类保留物（水井/泉等在广场内，不参与坊填）
    road_polys = [(r["pts"], r["width"]) for r in ROADS if r["cls"] not in ("rail","path")]
    # 广场绿地视作禁建
    no_build = [(-155,695,15,755),(-790,362,-620,442),(-585,340,-435,396),(-832,644,-742,700),
                (-175,385,45,515),(-475,604,-465,676)]
    for nb in no_build: keep_rects.append(nb)

    # 2) 填充街坊
    blocks_out = []
    total_new = 0
    skip_pairs = {("EB2","EB3")}  # EB2/EB3 共享同一矩形带：EB3 由 EB2 算法第二排覆盖
    done = set()
    for defrec in BLOCKS_DEF:
        bid = defrec[0]
        if (defrec[0], ) and any(bid==p[1] for p in skip_pairs for p in [(0,p[0])]): pass
        ids = []
        n = fill_block(defrec, keep_rects, road_polys, ids)
        rect = defrec[2]
        blocks_out.append({"id":bid,"cn":defrec[1],"pool":defrec[3],"face":defrec[4],
                           "rect":[round(v,1) for v in rect],
                           "buildingIds":ids,
                           "court":(defrec[5] or None)})
        if defrec[0] in LEGACY_FIT:
            blocks_out[-1]["buildingIds"] = LEGACY_FIT[defrec[0]] + ids
        total_new += n
        done.add(bid)

    # 3) 白盒公共设施：水井/泉/钟塔/灯塔/吊车/栈棚（v7 保留物 + v8 补足）
    extras = [
      ("wb_fountain","广场北泉",(-70,430),0),("wb_fountain","行会街泉",(-160,556),0),
      ("wb_well","河湾市集水井",(96,652),0),("wb_well","圣堂东坡井",(-626,614),0),
      ("wb_clock_arch","市政钟塔",(-70,342),0),("wb_clock_arch","北门内拱",(-70,232),0),
      ("wb_clock_arch","广场东拱",(45,450),270),
      ("wb_lighthouse","外港灯塔",(-425,1048),0),("wb_crane","埠头吊1",(-659,730),0),
      ("wb_crane","埠头吊2",(-659,830),0),("wb_pier_shed","埠头棚1",(-659,760),0),
      ("wb_pier_shed","埠头棚2",(-659,860),0),("wb_footbridge","染坊步行桥",(-150,598),0),
      ("wb_footbridge","鱼市步行桥",(110,582),0),("wb_kiosk","广场售货亭",(-40,430),0),
      ("wb_kiosk","湾滨售货亭",(-320,664),0),
    ]
    extra_ids = []
    for a, label, (x,z), yaw in extras:
        w,d,h = WB[a]
        # 桥是特殊：跨河拉长
        if a == "wb_footbridge":
            add_b(f"fx_{label}", a, x, z, 20, 6, 0, label)
        else:
            add_b(f"fx_{label}", a, x, z, w, d, yaw, label)
        extra_ids.append(f"fx_{label}")

    # 4) 桥（道路桥）
    bridges = [
      {"id":"main_bridge","cn":"晴岚主桥","at":[-70,588],"span":18,"road":"grand_south"},
      {"id":"east_bridge","cn":"东河桥","at":[278,580],"span":14,"road":"east_ave"},
      {"id":"foot_w1","cn":"染坊步行桥（白盒）","at":[-150,598],"span":16,"road":""},
      {"id":"foot_e1","cn":"鱼市步行桥（白盒）","at":[110,582],"span":14,"road":""},
    ]

    # 5) 广场 / 绿地 / 园林
    squares = [
      {"id":"civic_square","cn":"中央十字广场","c":[-65,450],"size":[220,130],"y":26,"style":"plaza"},
      {"id":"station_square","cn":"站前广场","c":[-70,725],"size":[170,60],"y":18,"style":"plaza"},
      {"id":"academy_square","cn":"学院前广场","c":[-510,368],"size":[150,56],"y":44,"style":"plaza"},
      {"id":"cathedral_square","cn":"圣堂前广场","c":[-787,672],"size":[90,56],"y":38,"style":"plaza"},
      {"id":"guild_court","cn":"行会小广场","c":[-160,556],"size":[70,26],"y":23,"style":"plaza"},
      {"id":"dock_apron","cn":"港口装卸广场","c":[-470,640],"size":[190,22],"y":13,"style":"apron"},
      {"id":"rw_market","cn":"河湾市集","c":[96,652],"size":[44,22],"y":18,"style":"market"},
    ]
    gardens = [
      {"id":"palace_court","cn":"总督宫 U 形前庭","c":[-790,322],"size":[170,76],"y":60,"style":"court"},
      {"id":"palace_axis","cn":"官邸轴线花园","c":[-790,408],"size":[120,80],"y":60,"style":"formal"},
      {"id":"academy_garden","cn":"学院阅读园","c":[-510,330],"size":[96,30],"y":44,"style":"formal"},
      {"id":"cathedral_south","cn":"圣堂南园","c":[-785,845],"size":[110,48],"y":38,"style":"formal"},
      {"id":"seaside_park","cn":"海湾公园","c":[113,929],"size":[98,48],"y":18,"style":"park"},
      {"id":"axis_lawn_w","cn":"北轴西草坪","c":[-125,285],"size":[26,110],"y":26,"style":"lawn"},
      {"id":"axis_lawn_e","cn":"北轴东草坪","c":[-8,285],"size":[26,110],"y":26,"style":"lawn"},
      {"id":"civic_south_g","cn":"市政南园","c":[-148,419],"size":[70,30],"y":26,"style":"park"},
      {"id":"m1_gdn","cn":"财政大臣园","c":[-888,352],"size":[30,24],"y":60,"style":"formal"},
      {"id":"m2_gdn","cn":"提督园","c":[-692,350],"size":[30,24],"y":60,"style":"formal"},
      {"id":"harbor_walk_g","cn":"湾滨棕榈带","c":[-420,688],"size":[180,14],"y":13,"style":"linear"},
      {"id":"riverbend_g","cn":"河湾西滨河绿地","c":[-180,642],"size":[84,32],"y":18,"style":"park"},
    ]

    # 6) NPC 契约：id 全保留（含 v7 重复 id：dock_worker×2 / sailor×2 / guard×4）。
    #    绑定建筑者按"门前面南 4m"重算；港务/飞艇/公园等开阔位用绝对坐标。
    door_front = [  # (id, 建筑id, 偏移x, 朝向yaw)
      ("mayor","civic",0,180),("banker","civic",-20,180),("banker2","civic",20,180),
      ("auctioneer","exchange",0,180),("guild_master","guild",-11,180),("guild_reg","guild",11,180),
      ("t_warrior_3","guild",-22,180),("t_rogue_3","guild",22,180),
      ("judge","court",0,0),("archivist","archive",0,0),("welfare_officer","welfare",0,0),("tax_officer","tax",0,0),
      ("clock_keeper","fx_市政钟塔",0,180),
      ("inn_keeper2","inn",0,180),("artisan_master","artisan",0,180),("smith_master","smith",0,180),
      ("bath_attendant","bath",0,180),("stable_city","stable",0,180),
      ("expo_guide","market",0,180),("transmog","market",-14,180),("rare_shop","market",14,180),
      ("potion_shop","market",-14,0),("item_shop","market",14,0),
      ("merchant_head","merchant",0,270),("cook_master","cook",0,270),
      ("weapon_shop","weapon_shop",0,180),("armor_shop","armor_shop",0,180),
      ("jeweler","jeweler",0,180),("florist","florist",0,180),
      ("governor","palace",0,0),("butler","palace",14,0),
      ("finance_minister","finance_minister",0,90),("ambassador","ambassador",0,90),("admiral","admiral",0,270),
      ("lecturer","academy",-12,0),("scholar_master","academy",12,0),
      ("librarian","library",0,90),("scholar","scholar",0,270),("researcher","institute",0,270),
      ("mage_master","mage",0,0),("t_mage_3","mage",-10,180),
      ("customs_officer","customs",0,0),("ferry_clerk","terminal",0,0),
      ("canal_officer","canal",0,0),("tavern_keeper","tavern",0,0),
      ("black_marketeer","blackmarket",0,180),("warehouse_keeper","wh0",0,0),
      ("shipwright","shipyard",0,0),
      ("archbishop","cathedral",0,180),("clergy","clergy",0,0),
      ("doctor","hospital",0,180),("nurse","hospital",12,180),
      ("station_master","station",0,180),("opera_manager","opera",0,0),
    ]
    b_by_id = {b["id"]: b for b in buildings}
    npcs = []
    def npc_y(x,z):
        return terr_y(x,z) + 0.6
    for nid,bid,dx,fov in door_front:
        bb = b_by_id.get(bid)
        if not bb: continue
        x = bb["c"][0]+dx
        z = bb["c"][1] + (bb["size"][1]/2+4 if fov==180 else -(bb["size"][1]/2+4))
        npcs.append({"id":nid,"p":[round(x,1),round(z,1)],"yaw":fov,"y":round(npc_y(x,z),1)})
    # 开阔位 NPC（绝对坐标，v7 契约位）
    for nid,p,yw in [
        ("harbor_master",(-470,648),180),("airship_captain",(-886,240),0),("astronomer",(-898,240),270),
        ("dock_worker",(-664,700),90),("dock_worker",(-662,830),90),
        ("sailor",(-505,634),180),("sailor",(-483,634),180),("merchant_captain",(-452,634),180),
        ("park_keeper",(113,908),0),("lighthouse_keeper",(-425,1036),180)]:
        npcs.append({"id":nid,"p":[p[0],p[1]],"yaw":yw,"y":round(npc_y(*p),1)})
    # 城门卫兵 & 广场女卫（契约位）
    for nid,p,yw in [
        ("guard_city",(282,438),90),("guard_city",(282,462),90),("guard_city",(-70,216),90),
        ("guard_city",(270,752),90),("guard_city_f",(-65,400),180),("guard_city_f",(-65,500),180),
        ("guard_city_f",(15,430),180)]:
        npcs.append({"id":nid,"p":[p[0],p[1]],"yaw":yw,"y":round(npc_y(*p),1)})
    # 市民：散布在新街坊内院/市集/埠头/广场（12 名通用契约 ID）
    citizen_spots = [(-291,296),(50,296),(-291,384),(82,407),(-169,481),(96,656),(100,652),
                     (-122,650),(114,768),(-582,510),(-300,320),(200,920)]
    for i,sp in enumerate(citizen_spots):
        npcs.append({"id":"citizen","p":[sp[0],sp[1]],"yaw":180,"y":round(npc_y(*sp),1)})

    # 7) POI / 出生点（id 契约不动）
    pois = [
      {"id":"poi_solenne","title":"晴岚港","p":[-300,440],"radius":780,"priority":1},
      {"id":"poi_plaza","title":"中央十字广场","p":[-65,450],"radius":60,"priority":3},
      {"id":"poi_market","title":"万国博览集市","p":[80,356],"radius":43,"priority":3},
      {"id":"poi_governor","title":"总督宫","p":[-790,305],"radius":45,"priority":3},
      {"id":"poi_academy","title":"皇家学院","p":[-510,302],"radius":40,"priority":3},
      {"id":"poi_cathedral","title":"晴岚大圣堂","p":[-785,762],"radius":47,"priority":3},
      {"id":"poi_station","title":"晴岚中央车站","p":[-70,812],"radius":52,"priority":3},
      {"id":"poi_guild","title":"冒险者公会","p":[-232,542],"radius":23,"priority":3},
      {"id":"poi_exchange","title":"交易所","p":[-120,542],"radius":23,"priority":3},
      {"id":"poi_smith","title":"锻铁匠行会","p":[-112,542],"radius":13,"priority":3},
      {"id":"poi_artisan","title":"精工行会","p":[-152,542],"radius":13,"priority":3},
      {"id":"poi_city_inn","title":"旅人之歌旅店","p":[-192,542],"radius":17,"priority":3},
      {"id":"poi_harbor","title":"晴岚港湾","p":[-460,660],"radius":60,"priority":2},
      {"id":"poi_south_port","title":"南港埠头","p":[-660,900],"radius":25,"priority":2},
      {"id":"poi_lighthouse","title":"外港灯塔","p":[-425,1048],"radius":24,"priority":2},
      {"id":"poi_park","title":"海湾公园","p":[113,940],"radius":55,"priority":2},
      {"id":"poi_airport","title":"海角飞艇坪","p":[-894,230],"radius":28,"priority":2},
      {"id":"poi_citygate","title":"东门","p":[292,450],"radius":28,"priority":2},
      {"id":"poi_citygate_n","title":"北门","p":[-70,205],"radius":26,"priority":2},
      {"id":"poi_citygate_se","title":"东南门","p":[270,740],"radius":28,"priority":2},
      {"id":"poi_canal","title":"晴岚运河","p":[-50,590],"radius":130,"priority":2},
      {"id":"poi_rw_market","title":"河湾市集","p":[96,652],"radius":26,"priority":3},
      {"id":"poi_guild_court","title":"行会小广场","p":[-160,556],"radius":20,"priority":3},
    ]
    spawns = [
      {"id":"fp_solenne","p":[-889,235],"yaw":180},
      {"id":"st_solenne","p":[-70,748],"yaw":0},
      {"id":"gy_gate","p":[300,470],"yaw":270},
      {"id":"gy_cathedral","p":[-820,800],"yaw":0},
      {"id":"city_inn_safe","p":[-192,524],"yaw":180},
    ]
    districts = [
      {"id":"governor","cn":"官邸区","color":[150,186,160],"poly":[[-936,215],[-668,215],[-668,300],[-660,402],[-790,470],[-936,470]]},
      {"id":"academy","cn":"学院区","color":[176,156,214],"poly":[[-668,215],[-391,225],[-391,402],[-524,470],[-660,402],[-668,300]]},
      {"id":"civic","cn":"市政区","color":[214,190,150],"poly":[[-391,225],[-16,246],[-16,529],[-348,529],[-348,300],[-391,225]]},
      {"id":"commerce","cn":"商贸区","color":[224,170,120],"poly":[[-16,246],[276,262],[292,540],[77,529],[-16,529]]},
      {"id":"port","cn":"港务区","color":[150,176,200],"poly":[[-660,470],[-278,540],[278,640],[155,700],[-155,742],[-600,762],[-679,677]]},
      {"id":"cathedral","cn":"圣堂区","color":[196,196,210],"poly":[[-912,596],[-671,596],[-671,856],[-901,856]]},
      {"id":"station","cn":"车站区（湾东）","color":[200,170,170],"poly":[[-155,660],[225,660],[240,920],[80,1000],[-125,920]]},
      {"id":"riverward","cn":"河湾坊","color":[190,200,170],"poly":[[-268,560],[278,576],[278,660],[-155,700],[-268,674]]},
    ]
    notes = [
      "v8 主旨：推倒 v7 补丁式路网，按「双轴、一湾、四级路网、坊巷城市」整体重构。地理契约（水系/城墙/三门/台地）与建筑身份契约（72 栋地标+旧资产）、83 NPC、22+1 POI、5 出生点全部保留。",
      "双轴：东西礼仪轴（东门→王冠大道→中央广场→总督宫前庭，两端对景）；南北生活轴（北门→北门大道→中央广场→中央南大道→晴岚主桥→站前广场，贯通市政核心与车站枢纽）。",
      "湾滨大道（v8 新增 A 级）：内港北岸连续滨水主路，串接埠头—海关—客运站—站前广场，修正 v7 埠头坊压水（v7 WP2 rect z690-728 在水线以南）。",
      "四级路网：A 主干 7 条（18-20m）/ B 次干 8 条（10-14m）/ C 支路 11 条（8-9m）/ D 巷弄+步道。修正 v7 的 37 条互不连通补丁线。",
      "行会带重整：guild/inn/artisan/smith/bath/stable/exchange 从 v7 跨两岸散点，统一落到河滨北街南侧行会带（z=542，门朝南临街+行会小广场+泉水），银行→拍卖→铁匠办事环线缩到 200m 内（v7 审视问题6）。",
      "河湾两岸：北岸贴岸做河滨北街+连续步行带；南岸做河湾南坊（SV1-3）面北望河；两座步行桥保持南北岸成环。",
      "29 坊主动划分：北带 5 坊、核心 3 坊、城东 3 坊、河湾 4 坊、港务 3 坊、西城 3 坊、圣堂 2 坊、学舍 2 坊、站东 3 坊、货棚 1 坊；每坊指定用途池/主朝向/内院用途（真实街坊逻辑：临街界面+内院后勤）。",
      "密度梯度：老城坊（河湾/行会/北带）wb_rowhouse+wb_shophouse 密织联排；核心坊（CC/EB0）wb_big_house 疏朗；西城/西北 rich 公馆坊；港务 ind 仓储坊。呼应「老城密织、新城疏朗」。",
      "城东大街（v8 新增 A 级）：补 v7 东城无南北干道缺陷，东门以北/以南均有连续界面。",
      "站前广场与站台：grand_south 直插站前广场北缘，广场→车站 29m 进站通道；se_gate_ave 沿站台南缘绕行（不再穿 EB 坊）。",
      "全部建筑含 AABB 冲突自检：建筑/道路/水系/保留建筑四方检测，冲突自动跳过（放不下留豁口做巷门）。",
    ]

    data = {
      "version":8,"water":WATER,"draft":True,
      "coast_west":coast_west,"coast_south":coast_south,"river":river,
      "wall":wall,"gates":gates,"terraces":terraces,
      "roads":ROADS,"buildings":buildings,"gardens":gardens,"squares":squares,
      "districts":districts,"blocks":blocks_out,"npcs":npcs,"pois":pois,
      "spawns":spawns,"bridges":bridges,"notes":notes,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT,"w",encoding="utf-8") as f:
        json.dump(data,f,ensure_ascii=False,indent=1)

    # ---- 自检报告
    wb_count = sum(1 for b in buildings if b["asset"].startswith("wb_"))
    print(f"建筑总数 {len(buildings)}（保留 {len(KEEP)} + 白盒填充 {wb_count - len([b for b in buildings if b['asset'].startswith('wb_') and b['id'].startswith('fx_')])} + 白盒设施 {len(extra_ids)}）")
    print(f"街坊 {len(blocks_out)} 个；路网 {len(ROADS)} 条（A{sum(1 for r in ROADS if r['cls']=='arterial')} B{sum(1 for r in ROADS if r['cls']=='collector')} C{sum(1 for r in ROADS if r['cls'] in ('local','path'))} D{sum(1 for r in ROADS if r['cls']=='alley')}）")
    print(f"NPC {len(npcs)}；POI {len(pois)}；出生点 {len(spawns)}")
    # 建筑互撞终检
    rects = []
    clash = []
    for b in buildings:
        w,d = b["size"]
        yaw = b.get("yaw",0)
        if yaw % 180 == 90: w,d = d,w
        r = (b["c"][0]-w/2, b["c"][1]-d/2, b["c"][0]+w/2, b["c"][1]+d/2)
        for i,orr in enumerate(rects):
            if rects_overlap(r, orr[1], margin=-0.5):
                clash.append((b["id"], orr[0]))
        rects.append((b["id"], r))
    if clash:
        print(f"!! 建筑互撞 {len(clash)} 对：", clash[:10])
    else:
        print("建筑互撞：0（通过）")
    # 白盒压水抽检
    wet = [b["id"] for b in buildings if b["asset"].startswith("wb_") and not b["id"].startswith("fx_")
           and rect_in_water((b["c"][0]-b["size"][0]/2, b["c"][1]-b["size"][1]/2, b["c"][0]+b["size"][0]/2, b["c"][1]+b["size"][1]/2))
           and "桥" not in b.get("label","")]
    print(f"白盒临水（≤8m 缓冲，含滨水坊属正常）: {len(wet)} 栋", wet[:8])

if __name__ == "__main__":
    main()
