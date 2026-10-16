"""Authored city parcels and service anchors; no stochastic house sprinkling."""
import json, math
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT/'docs/city_v5'
P = dict(version=5, water=8, roads=[], buildings=[], gardens=[], squares=[], npcs=[], pois=[], spawns=[], terraces=[])
arch = {a['id']:a for a in json.loads((ROOT/'assets/models/city_v5/architecture/manifest.json').read_text(encoding='utf8'))['assets']}
land = {a['id']:a for a in json.loads((OUT/'landmarks/manifest.plan.json').read_text(encoding='utf8'))['assets']}
P['coast_west'] = [[-930,160],[-980,250],[-965,430],[-960,630],[-940,800],[-880,940]]
P['coast_south'] = [[-1040,880],[-880,940],[-720,970],[-640,930],[-620,735],[-550,650],[-270,650],[-180,735],[-180,930],[80,1030],[300,1000],[520,905]]
P['river'] = [[360,580],[160,580],[-40,580],[-185,610],[-310,670]]
P['wall'] = [[-936,220],[-700,190],[-380,195],[-70,205],[225,225],[292,330],[292,450],[292,580],[270,740],[258,890],[230,1000]]
P['gates'] = [['east',292,450,90],['north',-70,205,0],['southeast',270,740,90]]
def terrace(id,x,z,w,d,y): P['terraces'].append(dict(id=id,c=[x,z],size=[w,d],y=y))
terrace('governor',-790,302,244,200,60)
terrace('academy',-510,302,238,196,44)
terrace('civic',-75,379,546,300,26)
terrace('cathedral',-786,754,230,204,38)
terrace('station',50,802,350,236,18)
terrace('west_docks',-659,788,40,222,13)
terrace('harbor_offices',-465,600,350,80,13)
def road(id,pts,width=12,walk=3): P['roads'].append(dict(id=id,pts=pts,width=width,walk=walk))
road('east_crown',[[320,450],[235,450],[-40,450],[-180,450],[-360,450],[-510,450],[-670,450],[-790,450]],18,4)
road('north_ring',[[-900,245],[-670,245],[-670,205],[-360,205],[-70,205],[200,245],[235,450]],10,3)
road('civic_west',[[-360,205],[-360,390],[-360,450],[-360,535]],12,3)
road('civic_cross',[[-360,390],[-300,390],[-60,390],[145,390],[235,390]],10,3)
road('civic_south',[[-360,535],[-300,535],[-180,535],[-40,535],[200,535],[235,450]],10,3)
road('market_axis',[[-40,245],[-40,390],[-40,450],[-40,535]],10,3)
road('market_east',[[145,245],[145,390],[145,450],[145,535]],10,3)
road('bridge_station',[[20,450],[20,535],[20,580],[20,650],[20,705],[60,735]],14,4)
road('east_embankment',[[235,450],[235,515],[219,536],[200,580],[180,628],[175,650],[175,735],[200,875],[258,890]],12,3)
road('station_front',[[-140,735],[20,735],[60,735],[175,735],[270,740]],16,4)
road('station_south',[[-120,885],[60,885],[200,875]],10,3)
road('station_west',[[-140,735],[-120,885]],10,3)
road('west_highstreet',[[-900,245],[-900,450],[-895,580],[-900,650],[-900,850],[-815,885]],12,3)
road('palace_approach',[[-790,355],[-790,420],[-790,450],[-790,530],[-790,540],[-790,580],[-785,600],[-785,655]],12,4)
road('academy_approach',[[-510,330],[-510,405],[-510,450]],12,4)
road('academy_lower',[[-510,450],[-510,535]],10,3)
road('west_cross',[[-895,580],[-790,580],[-690,580],[-570,535],[-510,535],[-360,535]],10,3)
road('cathedral_front',[[-900,650],[-785,650],[-745,650]],10,3)
road('harbor_ramp',[[-690,580],[-735,630],[-735,690],[-720,735],[-700,800],[-660,850]],10,3)
P['road_levels']=[[-510,385,44],[-370,385,34],[-370,450,30],[-895,580,38],[-790,580,38],[-690,580,30],[-735,630,28],[-735,690,24],[-720,735,20],[-700,800,16],[-660,850,13],[-570,535,26],[-360,535,26]]
P['road_levels'] += [[-790,450,57],[-670,450,50],[-510,450,44],[-360,450,32],[-510,405,44],[-510,330,44],[-510,535,36],[-435,575,23],[-435,623,13],[-900,450,52],[-790,420,60],[-790,530,47],[-785,600,38],[-895,540,44],[-790,540,45],[-670,540,38]]
for level in P['road_levels']:
    if level[:2]==[-510,450]:level[2]=42
    if level[:2] in [[-510,535],[-570,535]]:level[2]=34
road('western_quay',[[-660,710],[-660,790],[-660,885],[-660,930]],12,3)
road('north_quay',[[-660,710],[-570,623],[-520,623],[-435,623],[-340,623]],12,4)
road('east_quay',[[-145,720],[-145,835],[-140,915],[0,980],[160,965]],12,4)
road('station_to_quay',[[-145,735],[-40,705],[60,705],[175,705]],10,3)
road('cathedral_garden',[[-815,885],[-815,830]],6,2)
road('terrace_lane',[[-670,245],[-670,450],[-670,540],[-690,580]],8,3)
road('west_residential_lane',[[-895,540],[-790,540],[-670,540],[-510,535],[-360,535]],8,3)
road('tavern_walk',[[-679,631],[-679,657],[-638,689]],5,1.5)
P['road_levels'] += [[-679,631,22],[-679,657,20],[-638,689,13]]
road('academy_lower_court',[[-620,264],[-620,395],[-570,395],[-570,405],[-510,405]],4,1)
P['road_levels'] += [[-620,264,44],[-620,395,44],[-570,395,44],[-570,405,44]]
P['road_levels'] += [[235,515,22],[219,536,20],[180,628,20]]
def square(id,x,z,w,d,y): P['squares'].append(dict(id=id,c=[x,z],size=[w,d],y=y))
square('civic_forecourt',-180,393,210,72,26)
square('market_forecourt',80,395,110,82,26)
square('service_court',-180,492,188,64,26)
square('station_square',60,721,172,62,18)
square('cathedral_square',-785,662,80,66,38)
square('academy_square',-510,368,155,60,44)
square('palace_court',-790,376,130,66,60)
square('dock_apron',-475,624,190,28,13)
occupied=[]
def rot(v,yaw):
    a=math.radians(yaw); x,z=v
    return [math.cos(a)*x+math.sin(a)*z,-math.sin(a)*x+math.cos(a)*z]
def bbox(x,z,w,d,yaw,pad=0):
    a=math.radians(yaw); wx=abs(math.cos(a))*w+abs(math.sin(a))*d; dz=abs(math.sin(a))*w+abs(math.cos(a))*d
    return [x-wx/2-pad,z-dz/2-pad,x+wx/2+pad,z+dz/2+pad]
def overlap(a,b): return a[0]<b[2] and a[2]>b[0] and a[1]<b[3] and a[3]>b[1]
def add(id,asset,x,z,yaw=0,y=None,label='',reserve=4):
    lib=land if asset in land else arch; a=lib[asset]; w,d=a['footprint']
    item=dict(id=id,asset=asset,family='landmarks' if lib is land else 'architecture',c=[x,z],yaw=yaw,size=[w,a.get('max_height',a.get('visible_height',20)),d],label=label)
    if y is not None:item['y']=y
    P['buildings'].append(item);occupied.append(bbox(x,z,w,d,yaw,reserve));return item
def npc(id,x,z,yaw=0,y=None):
    a=dict(id=id,p=[x,z],yaw=yaw)
    if y is not None:a['y']=y
    P['npcs'].append(a)
def service(id,building,local,yaw=0):
    q=rot([local[0],local[1]],building['yaw']);npc(id,building['c'][0]+q[0],building['c'][1]+q[1],building['yaw']+yaw,building.get('y',26)+.6)
def poi(id,title,x,z,r=18,priority=14,xp=False):P['pois'].append(dict(id=id,title=title,p=[x,z],radius=r,priority=priority,xp=xp))
def bp(id,title,b,r=20,priority=14,xp=False):poi(id,title,*b['c'],r,priority,xp)
def garden(id,x,z,w,d,y,style='formal'):
    P['gardens'].append(dict(id=id,c=[x,z],size=[w,d],y=y,style=style));occupied.append(bbox(x,z,w,d,0))
# The six major grounds are authored before any ordinary parcel is accepted.
hall=add('civic','civic_hall',-180,323,180,26,'市政厅',8)
for i,(n,pt) in enumerate([('mayor',[0,9]),('banker',[-9,-2]),('banker2',[9,-2])]):service(n,hall,pt)
poi('poi_plaza','市政广场',-180,412,48,10,True)
market=add('market','trade_hall',80,322,180,26,'万国博览集市',8)
for n,pt in [('transmog',[-10,-6]),('rare_shop',[10,-6]),('potion_shop',[-10,8]),('item_shop',[10,8])]:service(n,market,pt)
npc('expo_guide',80,352,180,26)
bp('poi_market','万国博览集市',market,43,10,True)
for i,n in enumerate(['transmog','rare_shop','potion_shop','item_shop']):
    q=next(a for a in P['npcs'] if a['id']==n);poi('poi_shop_'+str(i),['幻化工坊','珍品阁','药剂店','道具店'][i],*q['p'],5,16)
pal=add('palace','governor_palace',-790,293,180,60,'总督宫',12)
for n,pt in [('governor',[-7,23]),('butler',[7,23])]:service(n,pal,pt)
bp('poi_governor','总督宫',pal,45)
poi('poi_residency','海角官邸区',-790,372,125,5,True)
garden('palace_axis',-790,390,126,82,60)
aca=add('academy','academy',-510,289,180,44,'皇家学院',10)
for n,pt in [('lecturer',[-10,-1]),('scholar_master',[5,-1])]:service(n,aca,pt)
bp('poi_academy','皇家学院',aca,32);poi('poi_north_slope','学院台地',-510,360,120,5,True)
cat=add('cathedral','cathedral',-785,751,0,38,'晴岚大圣堂',12)
service('archbishop',cat,[0,26]);service('clergy',cat,[-7,15])
bp('poi_cathedral','晴岚大圣堂',cat,47,10,True)
station=add('station','station',60,805,0,18,'晴岚中央车站',10)
service('station_master',station,[-10,-12]);bp('poi_station','晴岚中央车站',station,52,10,True)
# Compact daily service court: entrances face the same connected square.
guild=add('guild','guild_hall',-266,494,270,26,'冒险者公会',5)
for n,pt in [('guild_master',[-9,4]),('guild_reg',[9,4]),('t_warrior_3',[-9,-5]),('t_rogue_3',[9,-5]),('t_gunner_3',[0,8])]:service(n,guild,pt)
bp('poi_guild','冒险者公会',guild,23,12,True)
exchange=add('exchange','public_house',-85,493,90,26,'交易所',5);service('auctioneer',exchange,[-8,3]);bp('poi_exchange','交易所',exchange,23,12)
smith=add('smith','shop_arcade_3',-180,517,0,26,'锻铁匠行会',3);service('smith_master',smith,[-5,-3]);bp('poi_smith','锻铁匠行会',smith,13)
artisan=add('artisan','shop_arcade_3',-215,517,0,26,'精工行会',3);service('artisan_master',artisan,[5,-3]);bp('poi_artisan','精工行会',artisan,13)
inn=add('inn','inn_seafarer_3',-315,486,270,26,'旅人之歌旅店',4);service('inn_keeper2',inn,[0,-6]);bp('poi_city_inn','旅人之歌旅店',inn,17,20)
# Supporting institutions occupy deliberate edges, not enlarged copies of a civic palace.
for bid,asset,x,z,yaw,h,label,n,pi in [
 ('court','public_house',-292,321,180,26,'裁定厅','judge','poi_court'),
 ('archive','academy_library_3',-285,268,180,26,'城市档案馆','archivist','poi_archive'),
 ('tax','shop_arcade_3',-78,322,180,26,'税务局','tax_officer','poi_tax'),
 ('welfare','shop_arcade_3',-78,269,180,26,'社会保障局','welfare_officer','poi_welfare'),
 ('bath','public_house',-435,493,0,38,'公共浴池','bath_attendant','poi_bath'),
 ('portal','magic_tower',-315,370,270,26,'传送大厅','portal_mage','poi_portal_hall'),
 ('library','academy_library_3',-599,300,180,44,'公共图书馆','librarian','poi_library'),
 ('scholar','courtyard_college_3',-593,366,0,44,'学者行会','scholar','poi_scholar'),
 ('institute','courtyard_college_3',-424,358,0,44,'魔导研究所','researcher','poi_institute'),
 ('mage','magic_tower',-425,285,180,44,'魔法师行会','mage_master','poi_mage_guild'),
 ('merchant','courtyard_college_3',70,256,180,26,'商会总部','merchant_head','poi_merchant_hq'),
 ('cook','shop_arcade_3',186,491,90,26,'烹饪师行会','cook_master','poi_cook'),
 ('opera','opera',-22,920,0,18,'晴岚歌剧院','opera_manager','poi_opera'),
 ('hospital','public_house',-867,772,270,38,'圣堂医院','doctor','poi_hospital'),
 ('clergy','courtyard_college_3',-869,714,270,38,'修士院','clergy','poi_clergy'),
 ('customs','public_house',-570,584,180,13,'海关','customs_officer','poi_customs'),
 ('terminal','public_house',-445,586,180,13,'海运客运站','ferry_clerk','poi_north_port'),
 ('canal','shop_arcade_3',-369,588,180,13,'漕运局','canal_officer','poi_canal_bureau'),
 ('warehouse','warehouse_brick_2',-700,875,270,13,'港区货栈','warehouse_keeper','poi_warehouse'),
 ('shipyard','warehouse_stone_1',-733,916,180,13,'海军船坞','shipwright','poi_shipyard'),
 ('tavern','inn_seafarer_3',-679,614,180,22,'海鸥酒馆','tavern_keeper','poi_tavern'),
 ('blackmarket','shop_arcade_3',-725,560,180,32.8,'旧巷货行','black_marketeer','poi_blackmarket'),
]:
    a=add(bid,asset,x,z,yaw,h,label,4)
    if asset in land or arch[asset].get('enterable'):service(n,a,[0,-5])
    else:
        q=rot([0,-a['size'][2]/2-3],yaw);npc(n,x+q[0],z+q[1],yaw,h)
    bp(pi,label,a,18,12,pi in ['poi_library','poi_mage_guild'])
npc('t_mage_3',-432,298,180,44);npc('nurse',-853,764,270,38)
for x,z,n in [(-868,305,'finance_minister'),(-692,302,'admiral'),(-868,382,'ambassador')]:
    a=add(n,'mansion_garden_3',x,z,180,60,'',6);npc(n,x,z+16,180,60)
    garden(n+'_garden',x,z+32,36,20,60)
# Seven store IDs remain in their original semantic ordering.
for i,(n,label,x,z) in enumerate([('weapon_shop','武器店',44,484),('armor_shop','防具店',84,484),('jeweler','珠宝店',120,484)],4):
    a=add(n,'shop_arcade_3',x,z,0,26,label,3);service(n,a,[0,-3]);bp('poi_shop_'+str(i),label,a,12,16)
garden('cathedral_south',-785,840,110,48,38)
garden('academy_reading',-510,377,88,42,44)
garden('seaside_park',113,929,98,48,18,'park')
garden('civic_green',-180,258,113,26,26)
# Parcel edge rows: setbacks are shared and buildings have fixed native sizes.
def segdist(p,a,b):
    dx=b[0]-a[0];dz=b[1]-a[1];t=max(0,min(1,((p[0]-a[0])*dx+(p[1]-a[1])*dz)/(dx*dx+dz*dz)))
    return math.hypot(p[0]-a[0]-t*dx,p[1]-a[1]-t*dz)
def road_conflict(bb):
    for r in P['roads']:
        for a,b in zip(r['pts'],r['pts'][1:]):
            for q in [(bb[0],bb[1]),(bb[2],bb[1]),(bb[0],bb[3]),(bb[2],bb[3]),((bb[0]+bb[2])/2,(bb[1]+bb[3])/2)]:
                if segdist(q,a,b)<r['width']/2+r['walk']+.8:return True
    return False
rows=[
 ('merchant',[-8,260],[28,260],180,26),('east', [182,286],[182,366],90,26),
 ('crown',[2,424],[208,424],180,26),('north',[-310,231],[-60,231],180,26),
 ('westcore',[-395,265],[-395,413],270,None),
 ('academy_back',[-610,235],[-410,235],180,44),
 ('academy_south',[-625,418],[-405,418],180,None),
 ('upperwest',[-862,478],[-820,478],0,None),('westlane',[-862,513],[-815,513],180,None),
 ('west_middle',[-765,489],[-582,489],0,None),('west_middle_s',[ -765,548],[-600,548],180,None),
 ('west_sea',[-927,480],[-927,590],270,None),
 ('dockwest',[-695,723],[-695,863],270,13),
 ('eastnorth',[236,270],[236,356],90,26),
 ('station_east',[235,785],[235,851],90,18),
 ('station_north',[-105,670],[137,670],180,18),
 ('station_south',[-88,865],[140,865],0,18),
 ('westouter',[-875,880],[-735,880],0,None),
]
types=['residence_slate_3','residence_ochre_4','shop_rose_4','corner_merchants_3','residence_slate_3','corner_copper_4']
for ri,(district,a,b,yaw,h) in enumerate(rows):
    dx,dz=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dz);dx/=max(length,1);dz/=max(length,1);t=0;j=0
    while t<=length:
        asset=types[(ri+j)%len(types)]
        if district.startswith('academy'):asset=['academy_lodgings_4','academy_library_3','courtyard_college_3'][j%3]
        if district=='dockwest':asset=['warehouse_stone_1','warehouse_brick_2'][j%2]
        spec=arch[asset];w,d=spec['footprint'];x,z=a[0]+dx*t,a[1]+dz*t;bb=bbox(x,z,w,d,yaw,1.2)
        if not any(overlap(bb,q) for q in occupied) and not road_conflict(bb):add(district+'_'+str(j),asset,x,z,yaw,h,'',1.0)
        t+=w+2.6;j+=1
# Coherent street walls fill the sides of the already reserved civic compounds.
# Each complete parcel has buildings facing each bounding street and an open shared rear court.
extra_rows=[
 ('west_boulevard',[-867,476],[-815,476],0,None),
 ('west_south',[-867,516],[-815,516],180,None),
 ('merchant_upper',[-757,476],[-706,476],0,None),
 ('merchant_lower',[-757,516],[-706,516],180,None),
 ('terrace_north',[-631,476],[-547,476],0,None),
 ('terrace_south',[-631,510],[-547,510],180,None),
 ('bath_north',[-474,476],[-398,476],0,None),
 ('bath_south',[-474,510],[-398,510],180,None),
 ('civic_back',[-247,282],[-118,282],180,26),
 ('market_back',[3,283],[118,283],180,26),
 ('market_eastwall',[263,483],[263,510],90,26),
 ('market_southwall',[28,514],[125,514],180,20),
 ('station_northwall',[-105,695],[ -60,695],180,18),
 ('station_upper',[55,625],[128,625],0,18),
 ('station_lower',[55,678],[128,678],180,18),
 ('cathedral_lane',[-876,616],[-724,616],0,38),
 ('academy_westwall',[-642,288],[-642,362],90,44),
 ('academy_eastwall',[-383,287],[-383,355],270,44),
 ('upper_seafront',[-928,321],[-928,407],270,60),
]
for ri,(district,a,b,yaw,h) in enumerate(extra_rows):
    dx,dz=b[0]-a[0],b[1]-a[1];length=math.hypot(dx,dz);dx/=max(length,1);dz/=max(length,1);t=0;j=0
    while t<=length:
        asset=['residence_slate_3','residence_ochre_4','shop_rose_4'][j%3]
        w,d=arch[asset]['footprint'];x,z=a[0]+dx*t,a[1]+dz*t;bb=bbox(x,z,w,d,yaw,.3)
        if not any(overlap(bb,q) for q in occupied) and not road_conflict(bb):add(district+'_'+str(j),asset,x,z,yaw,h,'',.3)
        t+=w+.8;j+=1
# Designed small perimeter blocks with a shared open rear court and two end alleys.
for bi,(cx,cz,w,d,h,theme) in enumerate([
 (-530,498,90,55,31,'terrace'),(-840,555,74,54,40,'old'),
 (91,630,92,52,18,'station'),(-36,650,60,53,18,'station'),
 (-820,605,80,48,38,'old'),(-695,448,60,48,44,'upper'),
 (-455,237,62,42,44,'academy'),(-320,565,48,40,20,'port')]):
    for side in [-1,1]:
        for j in range(max(1,int(w/29))):
            x=cx-w/2+15+j*29;z=cz+side*d/2;asset=['residence_slate_3','residence_ochre_4','shop_rose_4'][(bi+j)%3]
            yaw=0 if side<0 else 180;aw,ad=arch[asset]['footprint'];bb=bbox(x,z,aw,ad,yaw,1)
            if not any(overlap(bb,q) for q in occupied) and not road_conflict(bb):add('court_%d_%d_%d'%(bi,side,j),asset,x,z,yaw,h,'',1)
# A complete station artisans' block is committed as one group with lateral exits.
for bid,asset,x,z,yaw in [
 ('station_court_n','shop_arcade_3',-60,769,0),
 ('station_court_s','inn_seafarer_3',-60,853,180),
 ('station_court_w1','residence_slate_3',-99,798,90),
 ('station_court_w2','residence_slate_3',-99,822,90),
 ('station_court_e1','residence_slate_3',-20,798,270),
 ('station_court_e2','residence_slate_3',-20,822,270)]:
    add(bid,asset,x,z,yaw,18,'',.2)
garden('station_court_garden',-60,810,40,40,18)
road('station_court_w',[[-60,810],[-118,810],[-130,810]],1.5,0)
road('station_court_e',[[-60,810],[0,810],[0,765],[0,735]],1.5,0)
# Jointly audited parcel corrections are applied before NPC/POI export.
for building in P['buildings']:
    if building['id']=='dockwest_3':building['c']=[-705,840.8]
    if building['id']=='merchant_lower_0':building['y']=43
    if building['id'].startswith('academy_westwall_'):building['yaw']=270
    street_grades={'west_sea_0':49,'west_sea_1':44.8,'west_sea_3':39.1,'upper_seafront_0':57,'upper_seafront_2':55.1,'upper_seafront_3':54}
    if building['id'] in street_grades:building['y']=street_grades[building['id']]
# Replace the fragmentary riverside rows with two whole residential blocks.
retired_prefixes=('station_north_','station_upper_','station_northwall_','court_3_','court_5_')
P['buildings']=[b for b in P['buildings'] if not b['id'].startswith(retired_prefixes)]
P['blocks']=[]
for bid,label,xs in [('river_west','河湾西街坊',[-101,-73,-44,-15]),('river_east','河湾东街坊',[55,83,112])]:
    members=[]
    north_z,front_z,court_z,court_depth=(642,628,659,8) if bid=='river_west' else (626,610,651,20)
    for side,z,yaw in [('n',north_z,0),('s',676,180)]:
        for i,x in enumerate(xs):
            aid=['residence_slate_3','residence_ochre_4','shop_rose_4'][i%3]
            ident=f'{bid}_{side}{i}'
            add(ident,aid,x,z,yaw,18,'',.2);members.append(ident)
    cx=(xs[0]+xs[-1])/2
    garden(bid+'_court',cx,court_z,xs[-1]-xs[0]+18,court_depth,18,'court')
    P['blocks'].append(dict(id=bid,label=label,buildingIds=members,courtyard=[cx,court_z],exits=[[xs[0]-16,court_z],[xs[-1]+16,court_z]]))
    left,right=xs[0]-16,xs[-1]+16
    road(bid+'_front',[[left,front_z],[right,front_z]],3,0)
    road(bid+'_back',[[left,693],[right,693]],3,0)
    road(bid+'_court_path',[[left,court_z],[right,court_z]],2,0)
    for x in [left,right]:
        road(bid+'_side_'+str(int(x)),[[x,front_z],[x,court_z],[x,693],[x,705]],2,0)
        P['road_levels'] += [[x,front_z,18],[x,court_z,18],[x,693,18],[x,705,18]]
P['blocks'].append(dict(id='station_artisans',label='车站工匠街坊',buildingIds=[b['id'] for b in P['buildings'] if b['id'].startswith('station_court_')],courtyard=[-60,810],exits=[[-130,810],[0,735]]))
for bid,label,prefixes in [('academy','学院街坊',('academy_','library','scholar','institute','mage')),('upper_market','高街商住街坊',('west_middle_','merchant_upper_','merchant_lower_','terrace_north_','terrace_south_')),('west_street','西城居住街坊',('upperwest_','westlane_','west_boulevard_','west_south_')),('civic','市政街坊',('civic','court','archive','tax','welfare','portal','north_')),('harbor','港务街坊',('customs','terminal','canal','warehouse','shipyard','tavern','dockwest_'))]:
    P['blocks'].append(dict(id=bid,label=label,buildingIds=[b['id'] for b in P['buildings'] if b['id'].startswith(prefixes)]))
# Small-scale life grouped by purpose, stable NPC/POI contract retained.
for args in [('florist',-140,414,180,26),('harbor_master',-485,622,180,13),('merchant_captain',-445,623,180,13),('dock_worker',-652,770,270,13),('dock_worker',-650,838,270,13),('sailor',-460,625,0,13),('sailor',-480,625,0,13),('park_keeper',113,920,0,18),('stable_city',210,512,90,None),('clock_keeper',-45,412,90,26),('canal_keeper',-344,620,180,13),('airship_captain',-896,232,180,60),('astronomer',-882,245,90,60),('lighthouse_keeper',-425,1048,270,13),('outer_farmer',348,510,270,None),('refugee',332,486,270,None),('gate_captain',270,440,270,26)]:npc(*args)
for x,z,y in [(-210,420,26),(-175,480,26),(-45,417,26),(115,399,26),(-501,351,44),(-782,629,38),(56,732,18),(-652,806,13),(-790,423,60),(-389,465,None)]:npc('citizen',x,z,180,y)
for x,z,y in [(282,438,26),(282,462,26),(-60,224,26),(-80,224,26),(248,732,18),(248,748,18)]:npc('guard_city',x,z,270,y)
npc('guard_city_f',265,460,270,26)
for args in [('poi_clock','钟楼',-45,413,12,14,False),('poi_airport','海角飞艇坪',-905,234,28,10,True),('poi_south_port','南港',-654,843,25,9,False),('poi_harbor','晴岚港湾',-475,625,60,8,True),('poi_lighthouse','港口灯塔',-430,1048,24,12,True),('poi_drain','城市排水口',-337,638,15,12,False),('poi_park','海湾公园',113,940,55,9,True),('poi_canal','晴岚运河',-50,548,130,3,True),('poi_spring','城北河源',343,547,23,9,True),('poi_citygate','东门',292,450,28,10,True),('poi_citygate_n','北门',-70,205,26,10,True),('poi_citygate_se','东南门',270,740,28,10,True),('poi_outer','城外驿街',338,484,40,5,True),('poi_farmland','城郊篱田',370,535,30,5,True),('poi_solenne','晴岚港',-300,440,780,1,False)]:poi(*args)
P['spawns']=[dict(id=i,p=[x,z],yaw=yaw) for i,x,z,yaw in [('fp_solenne',-889,235,180),('st_solenne',60,742,0),('gy_gate',324,480,270),('gy_cathedral',-826,814,0),('city_inn_safe',-300,470,270)]]
# Preserve baseline uniqueness, flag omitted service IDs before touching the scene.
base=json.loads((ROOT/'.local/city_v5/baseline.json').read_text(encoding='utf8'))
from city_v5_road_network import solve_network
solve_network(P)
(OUT/'layout.json').write_text(json.dumps(P,ensure_ascii=False,indent=2),encoding='utf8')
print('city layout:',len(P['buildings']),'new native buildings;',len(P['roads']),'streets;',len(P['npcs']),'NPC markers')
