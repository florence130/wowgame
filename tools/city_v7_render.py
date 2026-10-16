"""晴岚港 v7 草案总览渲染：docs/city_v7/draft.json -> v7草案总览.png"""
import json, math
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Polygon as MPoly, Rectangle, FancyArrow
from matplotlib.collections import PatchCollection, LineCollection

matplotlib.rcParams['font.family'] = ['Microsoft YaHei', 'SimHei', 'sans-serif']
matplotlib.rcParams['axes.unicode_minus'] = False

ROOT = Path(__file__).resolve().parents[1]
D = json.loads((ROOT / 'docs/city_v7/draft.json').read_text(encoding='utf8'))

WATER = '#a8d4e6'
LAND = '#e8e0c8'
WALL_C = '#8a8f96'
ROAD_C = {0.0: '#b98a4e'}
CLS_C = {'arterial': '#c9915a', 'collector': '#d8ae74', 'local': '#e0c193',
         'alley': '#e8d8b4', 'rail': '#9a9a9a', 'path': '#b9c4a8'}
BLD_FACE = '#d9c9a8'
BLD_EDGE = '#7a6a50'
WB_FACE = '#c2c8ce'
CAT_C = {'infra': '#8fa3b8'}

ASSET_C = {
    'civic_hall': '#c98a3a', 'governor_palace': '#7fae7f', 'academy': '#9a7fc9',
    'cathedral': '#b8b8c9', 'station': '#c97f7f', 'trade_hall': '#e09a50',
    'opera': '#c97fa8', 'guild_hall': '#5a8ac9', 'public_house': '#d8b060',
    'courtyard_college_3': '#a8b878', 'warehouse_brick_2': '#8f9aa8',
    'warehouse_stone_1': '#8f9aa8', 'wb_warehouse': '#9aa4ae',
}

fig, ax = plt.subplots(figsize=(19, 12.4), dpi=150)
ax.set_facecolor(WATER)

# 陆地多边形 = 城墙线 + 南岸海岸（反向）+ 西岸海岸（反向）
ax.add_patch(Rectangle((-1120, 40), 1680, 1080, facecolor=WATER, edgecolor='none', zorder=0.3))
land = list(D['wall'])
cs = D['coast_south']
land += [cs[10]] + cs[9::-1]          # (300,1000) -> (-1040,880)
cw = D['coast_west']
land += cw[5::-1]                      # (-880,940) -> (-930,160)
ax.add_patch(MPoly(land, closed=True, facecolor=LAND, edgecolor='none', zorder=0.5))

# 地块底色（分区）
for dist in D['districts']:
    poly = MPoly(dist['poly'], closed=True, facecolor=[c / 255 for c in dist['color']],
                 edgecolor='none', alpha=0.35, zorder=1)
    ax.add_patch(poly)
    cx = sum(p[0] for p in dist['poly']) / len(dist['poly'])
    cz = sum(p[1] for p in dist['poly']) / len(dist['poly'])
    ax.text(cx, cz, dist['cn'], fontsize=13, color='#555', alpha=0.75,
            ha='center', va='center', zorder=2)

# 海岸线
for coast, c in [(D['coast_south'], '#5a92b0'), (D['coast_west'], '#5a92b0')]:
    xs = [p[0] for p in coast]
    zs = [p[1] for p in coast]
    ax.plot(xs, zs, color=c, lw=2.2, zorder=3)

# 河道
rx = [p[0] for p in D['river']]
rz = [p[1] for p in D['river']]
ax.plot(rx, rz, color=WATER, lw=16, solid_capstyle='round', zorder=1.5)
ax.plot(rx, rz, color='#7ab8d0', lw=18, solid_capstyle='round', zorder=1.4, alpha=0.5)

# 城墙
wx = [p[0] for p in D['wall']]
wz = [p[1] for p in D['wall']]
ax.plot(wx, wz, color=WALL_C, lw=5, zorder=6, solid_capstyle='round')

# 广场/庭园
for s in D['squares']:
    ax.add_patch(Rectangle((s['c'][0] - s['size'][0] / 2, s['c'][1] - s['size'][1] / 2),
                           s['size'][0], s['size'][1], facecolor='#e8dcc0',
                           edgecolor='#c0b090', lw=1, zorder=3))
for g in D['gardens']:
    ax.add_patch(Rectangle((g['c'][0] - g['size'][0] / 2, g['c'][1] - g['size'][1] / 2),
                           g['size'][0], g['size'][1], facecolor='#b5d0a0',
                           edgecolor='#8aa878', lw=1, alpha=0.9, zorder=3))

# 道路（宽度按等级）
for r in D['roads']:
    pts = r['pts']
    lw = max(1.0, r['width'] / 7.0)
    if r['cls'] == 'rail':
        ax.plot([p[0] for p in pts], [p[1] for p in pts], color=CLS_C['rail'],
                lw=2.4, ls=(0, (6, 3)), zorder=4)
        continue
    ax.plot([p[0] for p in pts], [p[1] for p in pts], color=CLS_C.get(r['cls'], '#e0c193'),
            lw=lw, solid_capstyle='round', zorder=4)

# 桥
for b in D.get('bridges', []):
    ax.plot([b['at'][0]], [b['at'][1]], marker='o', ms=7, mfc='white',
            mec='#5a92b0', mew=1.6, zorder=5)

# 街坊边界（虚线）+ 编号
for blk in D['blocks']:
    x0, z0, x1, z1 = blk['rect']
    ax.add_patch(Rectangle((x0, z0), x1 - x0, z1 - z0, facecolor='none',
                           edgecolor='#a08a60', lw=0.9, ls=(0, (4, 3)), zorder=5.5))
    ax.text((x0 + x1) / 2, (z0 + z1) / 2 - 2, '%s %s' % (blk['id'], blk['cn']),
            fontsize=6.2, color='#8a7048', ha='center', va='center', zorder=7)

# 建筑
for b in D['buildings']:
    w, d = b['size']
    a = math.radians(b['yaw'])
    wx_, dz = abs(math.cos(a)) * w + abs(math.sin(a)) * d, abs(math.sin(a)) * w + abs(math.cos(a)) * d
    face = ASSET_C.get(b['asset'], BLD_FACE)
    if b.get('whitebox'):
        face = WB_FACE if b['asset'] not in ('wb_rowhouse', 'wb_shophouse') else '#e2ddd0'
    if b['asset'] in ('wb_rowhouse', 'wb_shophouse'):
        face = '#e2d5b8'
    ax.add_patch(Rectangle((b['c'][0] - wx_ / 2, b['c'][1] - dz / 2), wx_, dz,
                           facecolor=face, edgecolor=BLD_EDGE, lw=0.45, zorder=6))

# 地标标注（只标主要建筑，避免文字糊版）
MAJOR = {'civic', 'market', 'exchange', 'guild', 'palace', 'academy', 'cathedral',
         'station', 'opera', 'customs', 'terminal', 'shipyard', 'wb_lighthouse',
         'airship_pad', 'mage', 'hospital', 'bath', 'inn'}
for b in D['buildings']:
    if b['id'] in MAJOR:
        ax.text(b['c'][0], b['c'][1] + 3, b['label'].split('（')[0], fontsize=6.8,
                color='#3a3020', ha='center', va='bottom', zorder=8, fontweight='bold',
                bbox=dict(boxstyle='round,pad=0.15', fc='white', ec='none', alpha=0.7))

# 城门/指北/比例尺
for gid, x, z, ang in D['gates']:
    ax.annotate('', xy=(x + math.cos(math.radians(ang)) * 40, z + math.sin(math.radians(ang)) * 40),
                xytext=(x, z), arrowprops=dict(arrowstyle='-|>', color='#c05050', lw=2), zorder=9)
    ax.text(x, z - 14, {'east': '东门', 'north': '北门', 'southeast': '东南门'}[gid],
            fontsize=8, color='#c05050', ha='center', zorder=9)

ax.plot([-1010, -940], [1070, 1070], color='#444', lw=2)
ax.text(-975, 1082, '100m', fontsize=8, ha='center', color='#444')
ax.text(-1010, 1040,
        '晴岚港 v7 主城规划草案（%d 栋 / %d 街坊 / 白盒 %d）\n白盒=待 Tripo 建模；虚线框=街坊；红箭头=城门'
        % (len(D['buildings']), len(D['blocks']),
           sum(1 for b in D['buildings'] if b.get('whitebox'))),
        fontsize=9, color='#333', va='top')

ax.set_xlim(-1120, 560)
ax.set_ylim(1120, 40)   # 翻转 z 轴：北门朝上（游戏坐标 z 向南增加）
ax.set_aspect('equal')
ax.axis('off')
ax.set_title('晴岚港 v7 主城规划（保留 v6 地标与契约 / 重建街坊肌理）', fontsize=15, pad=12)

out = ROOT / 'docs/city_v7/v7草案总览.png'
fig.savefig(out, bbox_inches='tight', facecolor='white')
print('saved', out)
