// 晴岚港 v7 主城规划（v6 向北扩建一倍：王宫高地 / 魔法区 / 旧城区 / 军营区 / 城市公园 + 运河）（纯数据 + 推导，不依赖 three.js；node 可直接导出 JSON 给 Godot 生成器）
// 坐标沿用游戏区域坐标：+x 东，+z 南，单位米；高度 y 为海平面以上米数。
import { area, centroid, pointInPoly, inset, inwardNormal, norm, sub, add, mul, dist, len, lineIntersect, overlap, rectPoly, rng, bbox } from './geo2d.js';
import { fitTrees } from './treefit.js';

// ---------------------------------------------------------------- 标高（人工地基，全部铺平）
export const LV = { SEA: 0, QUAY: 3, LOW: 9, MID: 16, UP: 22, TOP: 30 };
export const CURB = 0.18;            // 人行道路基比车行道高 18cm
// v7.1 整城缩小：设计坐标（下文所有字面坐标）以东门 (300,430) 为原点缩放 KS，道路宽度与建筑模数不缩放
export const KS = 0.8;
export const X = (x) => 300 + (x - 300) * KS;
export const Z = (z) => 430 + (z - 430) * KS;
export const MP = (p) => [X(p[0]), Z(p[1])];
export const CITY_RECT = { x0: X(-1040), x1: 300, z0: Z(-600), z1: Z(1090) };
export const SEABED = -7;

// 道路等级：c = 车行道宽，sw = 单侧人行道宽
export const ROAD = {
  B: { c: 20, sw: 9, name: '大道' },     // boulevard：电车 + 双排行道树
  A: { c: 14, sw: 6, name: '主干道' },
  S: { c: 10, sw: 4, name: '街道' },
  L: { c: 6, sw: 2.5, name: '巷道' },
  P: { c: 12, sw: 5, name: '步行街' },
  E: { c: 3, sw: 0, name: '地基边' },    // 台地边缘：留 1.5m 栏杆带，不临街
  W: { c: 18, sw: 0, name: '城墙' },     // 城墙：墙体 8m + 内侧马道
};
const isStreet = (code) => 'BASLP'.includes(code);

// ---------------------------------------------------------------- 分区
export const DISTRICTS = {
  royal:    { name: '王宫高地', color: '#e9e2ff', style: 'royal', floors: [2, 3], pave: [1.04, 1.03, 1.06] },
  mage:     { name: '魔法区', color: '#9b86d6', style: 'mage', floors: [2, 3], pave: [0.92, 0.88, 1.04] },
  oldtown:  { name: '旧城区', color: '#b07a4f', style: 'oldtown', floors: [2, 3], pave: [0.95, 0.88, 0.8] },
  military: { name: '军营区', color: '#8a929c', style: 'military', floors: [2, 2], pave: [0.82, 0.84, 0.88] },
  cpark:    { name: '城市公园', color: '#5f9f55', style: 'park', floors: [2, 2], pave: [0.95, 1, 0.92] },
  nobles:   { name: '使馆区', color: '#c9b37a', style: 'palace', floors: [2, 3], pave: [1.03, 1.0, 0.95] },
  academy:  { name: '学院台地', color: '#8fb0c9', style: 'academy', floors: [2, 3], pave: [0.95, 0.98, 1.03] },
  cape:     { name: '圣堂海岬', color: '#b9c4d6', style: 'cape', floors: [2, 3], pave: [1.0, 1.0, 1.04] },
  core:     { name: '市政核心', color: '#d9a35b', style: 'core', floors: [3, 4], pave: [1.04, 1.0, 0.94] },
  trade:    { name: '商贸区', color: '#e0c06a', style: 'trade', floors: [3, 4], pave: [1.02, 0.98, 0.9] },
  artisan:  { name: '工匠区', color: '#c4734f', style: 'artisan', floors: [2, 3], pave: [0.98, 0.86, 0.8] },
  hero:     { name: '冒险者区', color: '#a7c27a', style: 'hero', floors: [3, 3], pave: [0.98, 1.0, 0.9] },
  harbor:   { name: '旧港区', color: '#6fa3a8', style: 'harbor', floors: [2, 3], pave: [0.9, 0.95, 0.96] },
  station:  { name: '车站区', color: '#b8866b', style: 'station', floors: [3, 3], pave: [0.98, 0.9, 0.86] },
  park:     { name: '海湾公园', color: '#7fb069', style: 'park', floors: [2, 3], pave: [0.95, 1, 0.92] },
};

// ---------------------------------------------------------------- 地基（人工台地）
const R = (x0, z0, x1, z1) => [[x0, z0], [x1, z0], [x1, z1], [x0, z1]];
export const TERRACES = [
  // ---- 北城（v7 扩建）
  { id: 'royal', name: '王宫高地台', level: LV.TOP, poly: R(-520, -600, 160, -380) },
  { id: 'mage', name: '魔法区台', level: LV.UP, poly: R(-960, -600, -520, 200) },
  { id: 'oldtown', name: '旧城台', level: LV.MID, poly: R(-500, -380, -120, 172) },
  { id: 'military', name: '军营台', level: LV.MID, poly: R(-120, -380, 160, 172) },
  { id: 'cpark', name: '公园台', level: LV.MID, poly: R(160, -600, 300, 172) },
  // ---- 南城（v6）
  { id: 'nobles', name: '使馆高地台', level: LV.TOP, poly: [[-960, 200], [-660, 200], [-660, 470], [-960, 470]] },
  { id: 'academy', name: '学院台', level: LV.UP, poly: R(-660, 198, -380, 540) },
  { id: 'cape', name: '圣堂海岬台', level: LV.UP, poly: [[-960, 470], [-660, 470], [-660, 820], [-720, 850], [-900, 850], [-960, 810]] },
  { id: 'central', name: '中心台', level: LV.MID, poly: R(-380, 198, 300, 552) },
  { id: 'harbortown', name: '港街台', level: LV.LOW, poly: [[-660, 540], [-380, 540], [-380, 552], [300, 552], [300, 600], [-200, 600], [-232, 625], [-660, 625]] },
  { id: 'northquay', name: '北码头', level: LV.QUAY, poly: R(-600, 625, -240, 650) },
  { id: 'westquay', name: '西码头', level: LV.QUAY, poly: [[-660, 625], [-580, 625], [-580, 990], [-660, 990]] },
  { id: 'breakwater', name: '防波堤', level: LV.QUAY, poly: [[-660, 990], [-580, 990], [-560, 1040], [-410, 1040], [-400, 1072], [-600, 1072], [-660, 1030]] },
  { id: 'eastquay', name: '东码头', level: LV.QUAY, poly: R(-240, 652, -196, 1000) },
  { id: 'station', name: '车站台', level: LV.LOW, poly: [[-196, 652], [300, 652], [300, 1000], [120, 1030], [-196, 1000]] },
  // 城外（只作网页地表；游戏里是自然地形）
  { id: 'out_n', name: '北岭', level: LV.TOP, outer: true, poly: R(-1000, -1000, 900, -600) },
  { id: 'out_e0', name: '东北高原', level: LV.MID, outer: true, poly: R(300, -600, 900, 200) },
  { id: 'out_e1', name: '东郊', level: LV.MID, outer: true, poly: R(300, 200, 900, 560) },
  { id: 'out_e2', name: '东郊河北', level: LV.LOW, outer: true, poly: R(300, 560, 900, 600) },
  { id: 'out_e3', name: '东郊河南', level: LV.LOW, outer: true, poly: [[300, 652], [900, 652], [900, 1000], [300, 1000]] },
];
// 运河：台地之间的水道（水面比两岸低 5m，石砌驳岸 + 栏杆）；湖：台面上的石砌水池
export const CANALS = [
  { id: 'canal_s', name: '晴岚运河', poly: R(-500, 172, 300, 198), water: LV.MID - 5 },
  { id: 'canal_w', name: '法师渠', poly: R(-520, -380, -500, 198), water: LV.MID - 5 },
];
export const BASINS = [
  { id: 'mage_lake', name: '星辉湖', x: -740, z: -300, r: 85, island: 26, level: LV.UP, bridges: [0, Math.PI / 2, Math.PI, -Math.PI / 2] },
  { id: 'park_pond', name: '公园湖', x: 230, z: -250, r: 42, island: 0, level: LV.MID, bridges: [] },
];
for (const t of TERRACES) t.poly = t.poly.map(MP);
for (const c of CANALS) c.poly = c.poly.map(MP);
for (const b of BASINS) { b.x = X(b.x); b.z = Z(b.z); b.r *= KS; b.island *= KS; }
export const WATER_NOTE = '台地以外即水面（海、港池、晴岚河）。河宽 52m（z 600–652），港池 x -580..-240。';

// ---------------------------------------------------------------- 街坊生成工具
let _bid = 0;
const blocks = [];
function halfOf(code) { return ROAD[code].c / 2; }
// 由道路中线围成的格子生成一个街坊（路基）多边形。sides 依次 N E S W 的道路代码。
function cellBlock(x0, z0, x1, z1, sides, opt) {
  x0 = X(x0); x1 = X(x1); z0 = Z(z0); z1 = Z(z1);
  const [N, E, S, W] = sides;
  const bx0 = x0 + halfOf(W), bx1 = x1 - halfOf(E), bz0 = z0 + halfOf(N), bz1 = z1 - halfOf(S);
  let poly = [[bx0, bz0], [bx1, bz0], [bx1, bz1], [bx0, bz1]];
  let codes = [N, E, S, W];
  // 两条临街边相交的角做切角（巴塞罗那式街角），大道切得更大
  if (opt.chamfer !== false) {
    const P = [], C = [];
    for (let i = 0; i < 4; i++) {
      const prev = codes[(i + 3) % 4], cur = codes[i];
      const v = poly[i];
      if (isStreet(prev) && isStreet(cur)) {
        const c = Math.max(ROAD[prev].c, ROAD[cur].c) >= 14 ? 9 : 6;
        const a = poly[(i + 3) % 4], b = poly[(i + 1) % 4];
        P.push(add(v, mul(norm(sub(a, v)), c)), add(v, mul(norm(sub(b, v)), c)));
        C.push(prev, ROAD[prev].c >= ROAD[cur].c ? prev : cur);
      } else { P.push(v); C.push(prev); }
    }
    // C[k] 是进入 P[k] 的边的代码；改成以 P[k] 为起点的边代码
    poly = P; codes = P.map((_, k) => C[(k + 1) % P.length]);
  }
  const b = { id: opt.id || `blk${++_bid}`, district: opt.district, level: opt.level, poly, codes,
    use: opt.use || 'build', floors: opt.floors, landmarks: [], labels: opt.labels || [], seed: _bid * 7919 };
  blocks.push(b);
  return b;
}
// 网格：xs/zs 为 [坐标, 道路代码]；cell(i,j,i2,j2) 取线 i..i2+1、j..j2+1 围成的街坊
function grid(xs, zs, base) {
  return (i, j, i2 = i, j2 = j, opt = {}) => cellBlock(xs[i][0], zs[j][0], xs[i2 + 1][0], zs[j2 + 1][0],
    [zs[j][1], xs[i2 + 1][1], zs[j2 + 1][1], xs[i][1]], { ...base, ...opt });
}

// ---------------------------------------------------------------- 中心台（16m）：市政核心 / 商贸 / 工匠 / 英雄区
export const PLAZA = { x: X(-120), z: Z(430), r: 62 * KS, monument: 30 * KS, name: '市政广场' };
const CX = [[-380, 'E'], [-300, 'S'], [-220, 'A'], [-120, 'A'], [-20, 'A'], [70, 'S'], [160, 'A'], [230, 'S'], [300, 'W']];
const CZ = [[198, 'E'], [260, 'S'], [345, 'A'], [430, 'B'], [515, 'S'], [552, 'E']];
const C = grid(CX, CZ, { level: LV.MID });
// 北排（城墙内侧）
C(0, 0, 0, 0, { district: 'hero' });
C(1, 0, 1, 0, { district: 'hero', id: 'archive_blk' });
C(2, 0, 2, 0, { district: 'core', id: 'court_blk' });
C(3, 0, 3, 0, { district: 'core', id: 'tax_blk', labels: ['税务局', '社会保障局'] });
C(4, 0, 4, 0, { district: 'trade' }); C(5, 0, 5, 0, { district: 'trade' }); C(6, 0, 6, 0, { district: 'trade' }); C(7, 0, 7, 0, { district: 'trade' });
// 第二排
C(0, 1, 0, 1, { district: 'hero' });
C(1, 1, 1, 1, { district: 'hero', id: 'bath_blk' });
C(2, 1, 3, 1, { district: 'core', id: 'cityhall_blk', chamfer: false });          // 市政厅占两格，北门大道在此收头
C(4, 1, 5, 1, { district: 'trade', id: 'market_blk' });                          // 万国博览集市（拍卖行）
C(6, 1, 6, 1, { district: 'trade', id: 'merchant_blk' });
C(7, 1, 7, 1, { district: 'trade', labels: ['珍品阁'] });
// 大道北侧商店排
C(0, 2, 0, 2, { district: 'hero' });
C(1, 2, 1, 2, { district: 'hero', id: 'trainer_blk' });
C(4, 2, 4, 2, { district: 'trade', labels: ['武器店', '防具店'] });
C(5, 2, 5, 2, { district: 'trade', labels: ['珠宝店'] });
C(6, 2, 6, 2, { district: 'trade', labels: ['药剂店', '道具店'] });
C(7, 2, 7, 2, { district: 'trade', labels: ['幻化工坊'] });
// 大道南侧：工匠区
C(0, 3, 0, 3, { district: 'hero' });
C(1, 3, 1, 3, { district: 'hero', id: 'post_blk' });
C(4, 3, 4, 3, { district: 'artisan', id: 'smith_blk' });
C(5, 3, 5, 3, { district: 'artisan', id: 'artisan_blk' });
C(6, 3, 6, 3, { district: 'artisan', id: 'cook_blk' });
C(7, 3, 7, 3, { district: 'artisan' });
// 河景排
for (let i = 0; i < 8; i++) C(i, 4, i, 4, { district: i < 2 ? 'hero' : i < 4 ? 'core' : 'artisan' });

// 市政广场四象限：格子减去广场圆，正面朝圆心
function sectorBlock(id, qx, qz, district) {
  // qx/qz = ±1，象限方向；x 线 -220/-20、z 线 345/515；广场中心 (-120,430)
  const P = PLAZA, hA = halfOf('A'), hB = halfOf('B'), hAv = halfOf('A');
  const xo = qx < 0 ? X(-220) + hA : X(-20) - hA;        // 外侧 x 边
  const zo = qz < 0 ? Z(345) + hAv : Z(515) - halfOf('S'); // 外侧 z 边
  const xi = P.x + qx * hA;                                // 北门/南桥大道半宽
  const zi = P.z + qz * hB;                                // 王冠大道半宽
  const arcR = P.r;
  const a0 = Math.atan2(zi - P.z, qx * Math.sqrt(Math.max(0, arcR * arcR - (zi - P.z) ** 2)));
  const pts = [];
  // 外角 → 沿外 z 边 → 沿内 x 边到圆弧 → 圆弧 → 沿内 z 边回到外 x 边
  pts.push([xo, zo]);
  pts.push([xi, zo]);
  const zc = P.z + qz * Math.sqrt(arcR * arcR - (xi - P.x) ** 2);
  pts.push([xi, zc]);
  const angA = Math.atan2(zc - P.z, xi - P.x);
  const xc = P.x + qx * Math.sqrt(arcR * arcR - (zi - P.z) ** 2);
  const angB = Math.atan2(zi - P.z, xc - P.x);
  let da = angB - angA; while (da > Math.PI) da -= 2 * Math.PI; while (da < -Math.PI) da += 2 * Math.PI;
  for (let k = 1; k < 8; k++) { const a = angA + da * k / 8; pts.push([P.x + arcR * Math.cos(a), P.z + arcR * Math.sin(a)]); }
  pts.push([xc, zi]);
  pts.push([xo, zi]);
  const codes = pts.map((_, k) => (k === 0 ? 'S' : k === 1 ? 'A' : k >= 2 && k <= 9 ? 'P' : k === 10 ? 'B' : 'A'));
  codes[0] = qz < 0 ? 'A' : 'S';
  const b = { id, district, level: LV.MID, poly: pts, codes, use: 'build', landmarks: [], labels: [], seed: ++_bid * 7919 };
  void a0;
  blocks.push(b);
  return b;
}
sectorBlock('plaza_nw', -1, -1, 'core');
sectorBlock('plaza_ne', 1, -1, 'core');
sectorBlock('plaza_sw', -1, 1, 'core');
sectorBlock('plaza_se', 1, 1, 'core');

// ---------------------------------------------------------------- 学院台（22m）
const AX = [[-660, 'E'], [-520, 'S'], [-380, 'E']];
const AZ = [[198, 'E'], [300, 'S'], [430, 'A'], [520, 'S'], [540, 'E']];
const A = grid(AX, AZ, { level: LV.UP, district: 'academy' });
A(0, 0, 0, 0, { id: 'library_blk' });
A(1, 0, 1, 0, { id: 'lecture_blk' });
A(0, 1, 0, 1, { id: 'academy_blk', chamfer: false });
A(1, 1, 1, 1, { id: 'garden_blk', use: 'park' });
A(0, 2, 0, 2, {});
A(1, 2, 1, 2, {});

// ---------------------------------------------------------------- 使馆区（30m，原总督高地）
const PX = [[-960, 'E'], [-900, 'S'], [-660, 'E']];
const PZ = [[200, 'E'], [290, 'S'], [470, 'E']];
const PG = grid(PX, PZ, { level: LV.TOP, district: 'nobles' });
PG(0, 0, 0, 0, { id: 'airship_blk', use: 'square' });
PG(1, 0, 1, 0, { id: 'residence_blk', labels: ['财政大臣官邸', '海军上将官邸', '外国使节馆'] });
cellBlock(-960, 290, -790, 470, ['S', 'S', 'E', 'E'], { id: 'embassy_blk', level: LV.TOP, district: 'nobles', chamfer: false });
cellBlock(-790, 290, -660, 470, ['S', 'E', 'E', 'S'], { id: 'embassy_garden', level: LV.TOP, district: 'nobles', use: 'park', chamfer: false });

// ---------------------------------------------------------------- 圣堂海岬（22m）
const KX = [[-960, 'E'], [-880, 'S'], [-740, 'S'], [-660, 'E']];
const KZ = [[470, 'E'], [520, 'S'], [700, 'S'], [820, 'E']];
const K = grid(KX, KZ, { level: LV.UP, district: 'cape' });
K(0, 0); K(1, 0); K(2, 0);
K(0, 1, 0, 1, { id: 'hospital_blk' });
K(1, 1, 1, 1, { id: 'cathedral_blk', use: 'square', chamfer: false });
K(2, 1, 2, 1, { id: 'clergy_blk' });
K(0, 2, 2, 2, { id: 'cemetery_blk', use: 'park' });

// ---------------------------------------------------------------- 王宫高地（30m）
const RX = [[-520, 'E'], [-280, 'A'], [40, 'A'], [160, 'E']];
const RZ = [[-600, 'W'], [-380, 'E']];
const RG = grid(RX, RZ, { level: LV.TOP, district: 'royal' });
RG(0, 0, 0, 0, { id: 'royal_garden', use: 'park', chamfer: false });
RG(1, 0, 1, 0, { id: 'palace_blk', use: 'square', chamfer: false });
RG(2, 0, 2, 0, { id: 'royal_chapel_blk', chamfer: false });

// ---------------------------------------------------------------- 魔法区（22m）：星辉湖 + 湖心法师塔
const MGX = [[-960, 'E'], [-870, 'S'], [-790, 'A'], [-690, 'A'], [-610, 'S'], [-520, 'E']];
const MGZ = [[-600, 'W'], [-500, 'S'], [-400, 'A'], [-200, 'A'], [-100, 'S'], [0, 'S'], [100, 'S'], [200, 'E']];
const MG = grid(MGX, MGZ, { level: LV.UP, district: 'mage' });
for (let i = 0; i < 5; i++) for (let j = 0; j < 7; j++) {
  if (j === 2 && i >= 1 && i <= 3) continue;           // 湖区
  const id = i === 0 && j === 0 ? 'observatory_blk' : i === 3 && j === 1 ? 'institute_blk' : i === 2 && j === 3 ? 'arcane_blk' : `mage_${i}_${j}`;
  const labels = i === 1 && j === 3 ? ['附魔工坊', '卷轴店'] : i === 3 && j === 3 ? ['法杖铺', '星象书店'] : [];
  MG(i, j, i, j, { id, labels });
}

// ---------------------------------------------------------------- 旧城区（16m）：窄巷木筋老街
const OX = [[-500, 'E'], [-430, 'L'], [-360, 'S'], [-300, 'L'], [-220, 'S'], [-170, 'L'], [-120, 'B']];
const OZ = [[-380, 'E'], [-300, 'L'], [-200, 'S'], [-150, 'L'], [-100, 'S'], [-50, 'L'], [0, 'S'], [50, 'L'], [100, 'S'], [172, 'E']];
const OG = grid(OX, OZ, { level: LV.MID, district: 'oldtown' });
for (let i = 0; i < 6; i++) for (let j = 0; j < 9; j++) {
  const id = i === 2 && j === 3 ? 'rogue_blk' : i === 4 && j === 5 ? 'blackmarket2_blk' : i === 1 && j === 6 ? 'oldchurch_blk' : i === 3 && j === 1 ? 'oldsquare' : `old_${i}_${j}`;
  const labels = i === 4 && j === 1 ? ['老橡木酒馆'] : i === 0 && j === 4 ? ['铁匠老铺', '皮革作坊'] : i === 5 && j === 7 ? ['旧城面包房'] : [];
  OG(i, j, i, j, { id, labels, use: id === 'oldsquare' ? 'square' : 'build' });
}

// ---------------------------------------------------------------- 军营区（16m）：练兵场、骑士团、兵营、马厩
const MX = [[-120, 'B'], [-20, 'S'], [70, 'S'], [160, 'S']];
const MZ = [[-380, 'E'], [-300, 'S'], [-160, 'A'], [-60, 'S'], [60, 'S'], [172, 'E']];
const MI = grid(MX, MZ, { level: LV.MID, district: 'military' });
MI(0, 0, 0, 0, { id: 'barracks_n' }); MI(1, 0, 1, 0, { id: 'barracks_c' }); MI(2, 0, 2, 0, { id: 'barracks_e' });
MI(0, 1, 0, 1, { id: 'knights_blk', chamfer: false });
MI(1, 1, 1, 1, { id: 'drillyard', use: 'square', chamfer: false });
MI(2, 1, 2, 1, { id: 'armory_blk' });
MI(0, 2, 0, 2, {}); MI(1, 2, 1, 2, { id: 'gunnery_blk' }); MI(2, 2, 2, 2, { id: 'stables_blk' });
for (let i = 0; i < 3; i++) for (let j = 3; j < 5; j++) MI(i, j, i, j, { labels: i === 1 && j === 3 ? ['军需铺'] : [] });

// ---------------------------------------------------------------- 城市公园（16m）
const KPX = [[160, 'S'], [300, 'W']];
const KPZ = [[-600, 'W'], [-380, 'S'], [-160, 'S'], [60, 'S'], [172, 'E']];
const KP = grid(KPX, KPZ, { level: LV.MID, district: 'cpark' });
KP(0, 0, 0, 0, { id: 'park_n', use: 'park', chamfer: false });
KP(0, 1, 0, 1, { id: 'park_lake', use: 'park', chamfer: false });
KP(0, 2, 0, 2, { id: 'park_greenhouse', use: 'park', chamfer: false });
KP(0, 3, 0, 3, { id: 'park_s', use: 'park', chamfer: false });

// ---------------------------------------------------------------- 港街台（9m）与码头（3m）
const HX = [[-660, 'E'], [-560, 'S'], [-460, 'S'], [-380, 'S'], [-300, 'S'], [-232, 'E']];
const HZ = [[540, 'E'], [585, 'A'], [625, 'E']];
const H = grid(HX, HZ, { level: LV.LOW, district: 'harbor' });
H(0, 0, 0, 0, { id: 'blackmarket_blk' });
H(1, 0); H(2, 0);
cellBlock(-380, 552, -300, 585, ['E', 'S', 'A', 'S'], { level: LV.LOW, district: 'harbor' });
H(0, 1, 0, 1, { id: 'fishmarket_blk', labels: ['鱼市'] });
H(1, 1, 1, 1, { id: 'customs_blk' });
H(2, 1, 2, 1, { id: 'terminal_blk' });
H(3, 1, 3, 1, { id: 'tavern_blk' });
cellBlock(-300, 552, -232, 625, ['E', 'E', 'E', 'S'], { id: 'canal_blk', level: LV.LOW, district: 'harbor', chamfer: false });
// 西码头仓库（面向港池）
cellBlock(-660, 640, -598, 760, ['E', 'L', 'S', 'E'], { id: 'wq1', level: LV.QUAY, district: 'harbor', labels: ['港区货栈'] });
cellBlock(-660, 760, -598, 890, ['S', 'L', 'S', 'E'], { id: 'wq2', level: LV.QUAY, district: 'harbor' });
cellBlock(-660, 890, -580, 985, ['S', 'E', 'E', 'E'], { id: 'shipyard_blk', level: LV.QUAY, district: 'harbor', use: 'square', chamfer: false });

// ---------------------------------------------------------------- 车站台（9m）
const SX = [[-196, 'E'], [-120, 'B'], [-20, 'S'], [70, 'S'], [160, 'A'], [230, 'S'], [300, 'W']];
const SZ = [[652, 'E'], [700, 'B'], [790, 'S'], [900, 'S'], [1000, 'E']];
const S = grid(SX, SZ, { level: LV.LOW, district: 'station' });
for (let i = 0; i < 6; i++) S(i, 0, i, 0, {});
S(0, 1, 0, 1, {}); S(0, 2, 0, 2, {}); S(0, 3, 0, 3, { district: 'park' });
S(1, 1, 2, 1, { id: 'station_square', use: 'square', chamfer: false });
S(1, 2, 2, 2, { id: 'station_blk', chamfer: false });
S(3, 1, 3, 1, { id: 'opera_blk' });
S(4, 1); S(5, 1);
S(3, 2); S(4, 2); S(5, 2);
S(1, 3, 5, 3, { id: 'baypark', district: 'park', use: 'park', chamfer: false });

export const BLOCKS = blocks;

// ---------------------------------------------------------------- 地标（功能建筑）
// facing：正面朝向（'N','S','E','W' 或 'plaza' 朝广场中心）；poi 为旧版 POI ID（兼容）
const FACE = { S: 0, N: Math.PI, E: Math.PI / 2, W: -Math.PI / 2 };
export const LANDMARKS = [];
const KEEP_SIZE = new Set(['gate', 'obelisk', 'equestrian', 'triumph', 'gatebridge', 'airship', 'magetower', 'lighthouse', 'waystone', 'airtower']);
function LM(id, name, func, type, block, x, z, w, d, h, facing, extra = {}) {
  x = X(x); z = Z(z);
  if (!KEEP_SIZE.has(type)) { w = Math.round(w * KS); d = Math.round(d * KS); }
  const yaw = facing === 'plaza' ? Math.atan2(PLAZA.x - x, PLAZA.z - z) : FACE[facing];
  const lm = { id, name, func, type, block, x, z, w, d, h, yaw, ...extra };
  LANDMARKS.push(lm);
  return lm;
}
// 市政核心
LM('cityhall', '市政厅', '城市行政、银行柜台、主线任务起点', 'cityhall', 'cityhall_blk', -120, 304, 150, 52, 26, 'S', { poi: 'poi_plaza', tower: 88 });
LM('exchange', '交易所 · 晴岚银行', '银行、仓库、货币兑换；广场钟楼', 'exchange', 'plaza_ne', -52, 381, 54, 42, 22, 'plaza', { poi: 'poi_exchange', clock: 'poi_clock' });
LM('guild', '冒险者公会', '任务板、队伍招募、副本登记', 'guild', 'plaza_nw', -188, 381, 52, 40, 22, 'plaza', { poi: 'poi_guild' });
LM('portal', '传送大厅', '各城传送门、法师传送服务', 'portal', 'plaza_sw', -186, 478, 38, 38, 24, 'plaza', { poi: 'poi_portal_hall' });
LM('inn', '旅人之歌旅店', '炉石绑定、休息经验、酒馆', 'inn', 'plaza_se', -54, 478, 46, 34, 20, 'plaza', { poi: 'poi_city_inn' });
LM('court', '裁定厅', 'PvP 荣誉、悬赏、城市治安', 'civic', 'court_blk', -170, 232, 64, 30, 18, 'S', { poi: 'poi_court' });
LM('archive', '城市档案馆', '剧情档案、成就展陈', 'civic', 'archive_blk', -260, 232, 44, 30, 16, 'S', { poi: 'poi_archive' });
// 商贸区
LM('market', '万国博览集市', '拍卖行、交易大厅（铁与玻璃大展馆）', 'market', 'market_blk', 70, 302, 150, 56, 26, 'S', { poi: 'poi_market' });
LM('merchant', '商会总部', '商会声望、商队任务', 'civic', 'merchant_blk', 195, 302, 46, 40, 20, 'S', { poi: 'poi_merchant_hq' });
LM('gatebridge', '钟门桥', '跨大道的钟楼桥门，商贸区入口地标', 'gatebridge', null, 115, 430, 52, 14, 26, 'E');   // 52m：两座桥塔落在人行道外缘，不挡两侧建筑正门
// 工匠区
LM('smith', '锻铁匠行会', '锻造、采矿训练', 'workshop', 'smith_blk', 25, 470, 56, 34, 16, 'N', { poi: 'poi_smith' });
LM('artisan', '精工行会', '珠宝、工程、裁缝训练', 'workshop', 'artisan_blk', 115, 486, 56, 30, 16, 'N', { poi: 'poi_artisan' });
LM('cook', '烹饪师行会', '烹饪、钓鱼训练', 'workshop', 'cook_blk', 195, 470, 44, 32, 14, 'N', { poi: 'poi_cook' });
// 英雄区
LM('bath', '公共浴池', '休息区、社交动作', 'bath', 'bath_blk', -260, 302, 54, 46, 14, 'E', { poi: 'poi_bath' });
LM('trainer', '英雄殿', '各职业训练师、天赋重置', 'civic', 'trainer_blk', -260, 387, 54, 44, 22, 'E');
LM('post', '邮政驿站', '邮箱、坐骑管理、马车夫', 'civic', 'post_blk', -260, 472, 50, 36, 16, 'E');
// 学院台
LM('library', '公共图书馆', '书籍收集、知识任务', 'civic', 'library_blk', -590, 252, 90, 50, 20, 'S', { poi: 'poi_library', dome: true });
LM('lecture', '学院讲堂', '公开课、学院声望', 'civic', 'lecture_blk', -450, 252, 80, 46, 18, 'S', { poi: 'poi_north_slope' });
LM('academy', '皇家学院', '学院声望、学者行会', 'academy', 'academy_blk', -590, 366, 110, 100, 22, 'S', { poi: 'poi_academy', tower: 58 });
LM('scholar', '学者行会', '考古、铭文', 'pavilion', 'garden_blk', -450, 330, 30, 22, 12, 'S', { poi: 'poi_scholar' });
// 使馆区（原总督高地）
LM('embassy', '外交宫', '各国使节、外交任务', 'civic', 'embassy_blk', -870, 380, 110, 80, 22, 'E', { poi: 'poi_residency', dome: true });
LM('airship', '海角飞艇坪', '飞艇航线（城际飞行点）', 'airship', 'airship_blk', -930, 245, 40, 40, 6, 'S', { poi: 'poi_airport' });
// 王宫高地（v7）
LM('palace', '晴岚王宫', '城主、阵营声望、宫廷任务', 'grandpalace', 'palace_blk', -120, -505, 260, 150, 32, 'S', { poi: 'poi_governor' });
LM('royal_chapel', '王室礼拜堂', '王室典礼、祝福', 'cathedral', 'royal_chapel_blk', 100, -490, 40, 70, 22, 'S', { spire: 48 });
// 魔法区（v7）
LM('mage', '魔法师行会', '法师训练、附魔（湖心塔）', 'magetower', null, -740, -300, 28, 28, 120, 'S', { poi: 'poi_mage_guild', level: LV.UP + 1.4 });
LM('institute', '魔导研究所', '魔导科技、工程任务', 'civic', 'institute_blk', -650, -450, 60, 56, 20, 'S', { poi: 'poi_institute', tint: [0.88, 0.84, 1] });
LM('observatory', '星象台', '天文观测、星象任务', 'observatory', 'observatory_blk', -915, -550, 56, 56, 22, 'S', { poi: 'poi_observatory' });
LM('arcane', '奥术议会', '魔法区议事厅', 'civic', 'arcane_blk', -740, -50, 66, 50, 20, 'N', { poi: 'poi_mage_quarter', dome: true, tint: [0.86, 0.82, 1] });
// 旧城区（v7）
LM('rogue', '影刃会馆', '盗贼训练、潜行任务', 'workshop', 'rogue_blk', -330, -125, 40, 26, 12, 'N', { poi: 'poi_oldtown' });
LM('blackmarket', '旧巷货行', '黑市商人、稀有材料', 'workshop', 'blackmarket2_blk', -195, -25, 30, 24, 12, 'W', { poi: 'poi_blackmarket' });
LM('oldchurch', '旧城礼拜堂', '旧城居民的小教堂', 'cathedral', 'oldchurch_blk', -395, 25, 26, 44, 16, 'N', { spire: 34 });
// 军营区（v7）
LM('knights', '晨曦骑士团', '战士训练、骑士团任务', 'civic', 'knights_blk', -70, -230, 70, 80, 22, 'E', { poi: 'poi_barracks', fac: 'fac_haus', tint: [0.8, 0.8, 0.84] });
LM('armory', '军械库', '军需、武器保养', 'workshop', 'armory_blk', 115, -230, 60, 34, 14, 'W');
LM('gunnery', '魔导枪械所', '魔导枪手训练', 'workshop', 'gunnery_blk', 25, -110, 60, 34, 14, 'N');
LM('stables', '皇家马厩', '骑术训练、坐骑', 'workshop', 'stables_blk', 115, -110, 70, 34, 10, 'N');
// 城市公园（v7）
LM('greenhouse', '城市温室', '花卉、草药', 'market', 'park_greenhouse', 230, -50, 60, 40, 14, 'W', { poi: 'poi_citypark' });
LM('triumph', '凯旋门', '王宫大道北端的凯旋门', 'triumph', null, -120, 140, 44, 14, 44, 'S');
// 礼仪轴线装饰（王宫大道）：方尖碑、骑马像
const ORN = (id, type, x, z, h, yaw = 'S') => LM(id, '', '', type, null, x, z, type === 'obelisk' ? 6 : 12, type === 'obelisk' ? 6 : 8, h, yaw, { orn: true });
ORN('ob_palace_w', 'obelisk', -185, -405, 30); ORN('ob_palace_e', 'obelisk', -55, -405, 30);
ORN('statue_king', 'equestrian', -120, -391, 14);   // 王宫大台阶落脚点外 14m
ORN('ob_stair_w', 'obelisk', -143, -318, 24); ORN('ob_stair_e', 'obelisk', -97, -318, 24);
ORN('ob_arch_w', 'obelisk', -146, 112, 22); ORN('ob_arch_e', 'obelisk', -94, 112, 22);
// 圣堂海岬
LM('cathedral', '晴岚大圣堂', '牧师训练、复活点、婚礼', 'cathedral', 'cathedral_blk', -810, 628, 64, 118, 36, 'N', { poi: 'poi_cathedral', spire: 96 });
LM('hospital', '圣堂医院', '急救、草药训练', 'civic', 'hospital_blk', -920, 610, 50, 80, 16, 'E', { poi: 'poi_hospital' });
LM('clergy', '修士院', '修士、圣职任务', 'civic', 'clergy_blk', -700, 610, 50, 70, 16, 'W', { poi: 'poi_clergy' });
// 旧港区
LM('fishmarket', '鱼市', '渔获、钓鱼补给', 'workshop', 'blackmarket_blk', -610, 562, 50, 26, 10, 'S', { poi: 'poi_drain' });
LM('customs', '海关', '航运许可、走私任务', 'civic', 'customs_blk', -510, 606, 62, 26, 16, 'N', { poi: 'poi_customs' });
LM('terminal', '海运客运站', '客船航线（城际船运）', 'terminal', 'terminal_blk', -420, 606, 52, 26, 16, 'N', { poi: 'poi_north_port' });
LM('tavern', '海鸥酒馆', '水手、钓鱼、酒馆游戏', 'tavern', 'tavern_blk', -340, 606, 44, 26, 14, 'N', { poi: 'poi_tavern' });
LM('canal', '漕运局', '运河航运、渡船', 'civic', 'canal_blk', -266, 590, 44, 50, 14, 'E', { poi: 'poi_canal_bureau' });
LM('shipyard', '海军船坞', '船只、海战任务', 'shipyard', 'shipyard_blk', -620, 938, 70, 80, 22, 'E', { poi: 'poi_shipyard' });
LM('lighthouse', '港口灯塔', '港口地标', 'lighthouse', null, -418, 1056, 14, 14, 42, 'S', { poi: 'poi_lighthouse' });
// 车站区
LM('station', '晴岚中央车站', '魔导列车（往晨露谷）、电车总站', 'station', 'station_blk', -70, 830, 170, 64, 30, 'N', { poi: 'poi_station' });
LM('opera', '晴岚歌剧院', '演出、节日活动', 'opera', 'opera_blk', 115, 745, 72, 56, 24, 'N', { poi: 'poi_opera' });
// 城门
LM('gate_e', '东门', '通往潮风高地野外', 'gate', null, 300, 430, 30, 24, 22, 'E', { poi: 'poi_citygate' });
LM('gate_n', '北门', '通往北岭', 'gate', null, 230, -600, 30, 24, 22, 'N', { poi: 'poi_citygate_n' });
LM('gate_se', '东南门', '通往晨露谷大路', 'gate', null, 300, 700, 30, 24, 22, 'E', { poi: 'poi_citygate_se' });

// 飞艇站瞭望塔（参考图 4）：飞艇坪东侧的观景高塔，顶部铁艺玻璃观景笼 + 系泊臂伸向飞艇坪
LM('airtower', '飞艇站瞭望塔', '俯瞰全城的观景台、飞艇登船口', 'airtower', 'residence_blk', -875, 244, 26, 26, 118, 'W', { poi: 'poi_airtower' });

// ================================================================ v7.2 过渡带：北苑叠园（接山）+ 西海堤 / 离岸岛 / 栈桥（接海）
// 2026-10-09 用户：北侧与山地高原没有过渡，西侧没有向海的过渡；不要整城一个死板矩形，西侧大海可以利用（人工岛、栈桥）。
// 以下坐标直接是游戏区域坐标（已缩放），不再经过 X() / Z()；写给 LM() 的坐标用 DXi / DZi 反算回设计坐标。
const DXi = (x) => (x - 60) / KS;
const DZi = (z) => (z - 86) / KS;
const sstep = (a, b, v) => { const t = Math.max(0, Math.min(1, (v - a) / (b - a))); return t * t * (3 - 2 * t); };
const gauss = (v, c, s) => Math.exp(-(((v - c) / s) ** 2));
function addTerrace(id, name, level, poly, extra = {}) { const t = { id, name, level, poly, ...extra }; TERRACES.push(t); return t; }
function addBlock(id, district, level, terracePoly, use = 'park', off = 1.5) {
  const poly = inset(terracePoly, off);
  const b = { id, district, level, poly, codes: poly.map(() => 'E'), use, floors: undefined, landmarks: [], labels: [], seed: ++_bid * 7919 };
  blocks.push(b);
  return b;
}
function blobPoly(cx, cz, r, n, seed, wob = 0.1) {
  const R = rng(seed), ph = R() * Math.PI * 2, pts = [];
  for (let i = 0; i < n; i++) { const a = Math.PI * 2 * i / n, rr = r * (1 + wob * Math.sin(a * 3 + ph) + wob * 0.5 * Math.sin(a * 5 + ph * 2)); pts.push([cx + Math.cos(a) * rr, cz + Math.sin(a) * rr]); }
  return pts;
}

// ---- 北苑叠园：王宫背后沿山坡升起的四层园台，阶梯 + 叠水，尽头是山顶眺望台
// levels[0] 是王宫背后的「后平台」（与王宫 4m 台基同高 34），之后是四层山台 36 / 42 / 48 / 54
export const HILL = { x: X(-120), levels: [34, 36, 42, 48, 54], zs: [Z(-600), -484, -564, -634, -706], widths: [230, 200, 160, 120], apron: { x0: X(-120) - 122, x1: X(-120) + 122, z1: Z(-600) + 9.5 } };
{
  const hx = HILL.x, zs = HILL.zs, ws = HILL.widths, lv = HILL.levels, ap = HILL.apron;
  addTerrace('hill0', '宫后平台', lv[0], [[ap.x0, zs[0]], [ap.x1, zs[0]], [ap.x1, ap.z1], [ap.x0, ap.z1]], { floor: lv[0] - 8 });
  for (let k = 0; k < 3; k++) {
    const poly = [[hx - ws[k + 1] / 2, zs[k + 1]], [hx + ws[k + 1] / 2, zs[k + 1]], [hx + ws[k] / 2, zs[k]], [hx - ws[k] / 2, zs[k]]];
    addTerrace(`hill${k + 1}`, `北苑${'一二三'[k]}层台`, lv[k + 1], poly, { floor: lv[k + 1] - 7 });
    addBlock(`hill${k + 1}_blk`, 'royal', lv[k + 1], poly);
  }
  const apex = [[hx - ws[3] / 2, zs[3]]];
  for (let i = 0; i <= 18; i++) { const a = Math.PI * i / 18; apex.push([hx + Math.cos(a) * ws[3] / 2, zs[3] - Math.sin(a) * (zs[3] - zs[4])]); }
  apex.pop();
  addTerrace('hill4', '北苑山顶台', lv[4], apex, { floor: lv[4] - 7 });
  addBlock('hill4_blk', 'royal', lv[4], apex);
}
LM('belvedere', '北苑眺望台', '山顶观景台、全城俯瞰、北苑叠园尽头', 'pavilion', 'hill4_blk', DXi(HILL.x), DZi(-682), 44, 30, 24, 'S', { poi: 'poi_belvedere' });

// ---- 西海堤：贴着西侧崖壁脚的一条波浪形海滨台地（9m），有海湾、阶梯上崖；崖外是离岸人工岛与栈桥
export const SHELF = { x: X(-960), level: LV.LOW, z0: -320, z1: 734 };
export const STAIR_Z = [Z(-200), Z(100), Z(520), Z(700)];      // 法师区 ×2、圣堂海岬 ×2 的东西向街道尽头
const shelfW = (z) => {
  const taper = sstep(SHELF.z0, SHELF.z0 + 60, z) * sstep(SHELF.z1, SHELF.z1 - 60, z);
  const w = 40 + 11 * Math.sin(z / 78 + 0.5) + 6 * Math.sin(z / 29) + 40 * STAIR_Z.reduce((s, c) => s + gauss(z, c, 38), 0);
  return Math.max(10, 10 + (w - 10) * taper);
};
export const xOut = (z) => SHELF.x - shelfW(z);
{
  const pts = [];
  for (let z = SHELF.z0; z <= SHELF.z1 + 0.1; z += 12) pts.push([xOut(z), z]);
  pts.push([SHELF.x, SHELF.z1], [SHELF.x, SHELF.z0]);
  addTerrace('seashelf', '西海堤', SHELF.level, pts, { floor: SHELF.level - 8 });
  addBlock('seashelf_blk', 'park', SHELF.level, pts, 'park');          // 海滨花园：铺装边 + 草坪 + 树
}
// 海滨凉亭（可进入的穹顶亭，面朝大海）：三座，错开在三段海堤上
for (const [id, name, z] of [['seaside_a', '观潮亭', -110], ['seaside_b', '听涛亭', 400], ['seaside_c', '望帆亭', 575]]) {
  // 朝西（面海）：门前台阶落在海堤面上，后墙离崖脚 ≥ 3m
  const cx = Math.min(xOut(z) + 26, SHELF.x - 14);
  LM(id, name, '海滨凉亭，可休憩观海', 'pavilion', 'seashelf_blk', DXi(cx), DZi(z), 34, 26, 16, 'W');
}
export const ISLANDS = [];
{
  const spec = [
    { id: 'isl_light', name: '灯塔岛', zc: -205, r: 30, level: LV.LOW, n: 18, district: 'cape', use: 'park' },
    { id: 'isl_plaza', name: '海神广场岛', zc: 30, r: 42, level: LV.LOW, n: 22, district: 'harbor', use: 'square' },
    { id: 'isl_air', name: '飞艇泊台', zc: 282, r: 46, level: LV.TOP, n: 24, district: 'nobles', use: 'square', xc: SHELF.x - 185 - 46 },
    { id: 'isl_dock', name: '商船码头岛', zc: 430, r: 38, level: LV.QUAY, n: 22, district: 'harbor', use: 'square' },
    { id: 'pier_pad1', name: '观海亭台', zc: -262, r: 12, level: LV.LOW, n: 14, district: 'cape', use: 'square', xc: xOut(-262) - 78, wob: 0.03 },
    { id: 'pier_pad2', name: '渡轮栈桥头', zc: 696, r: 14, level: LV.LOW, n: 14, district: 'harbor', use: 'square', xc: xOut(696) - 84, wob: 0.03 },
  ];
  spec.forEach((s, i) => {
    const xc = s.xc ?? xOut(s.zc) - 38 - s.r;
    const poly = blobPoly(xc, s.zc, s.r, s.n, 600 + i, s.wob ?? 0.1);
    addTerrace(s.id, s.name, s.level, poly, { floor: s.level - 8 });
    addBlock(`${s.id}_blk`, s.district, s.level, poly, s.use);
    ISLANDS.push({ ...s, xc });
  });
}
const ISL = Object.fromEntries(ISLANDS.map((s) => [s.id, s]));
// 飞艇泊台上的候船厅（门朝东，对着天桥）
LM('airship_terminal', '飞艇候船厅', '飞艇登船、空中航线与观光', 'terminal', 'isl_air_blk', DXi(ISL.isl_air.xc - 9), DZi(ISL.isl_air.zc), 44, 28, 18, 'E', { poi: 'poi_airship_dock' });
LM('lighthouse_w', '西港灯塔', '西侧海岛上的灯塔，夜间为进港船只指路', 'lighthouse', 'isl_light_blk', DXi(ISL.isl_light.xc), DZi(ISL.isl_light.zc), 14, 14, 62, 'E', { poi: 'poi_lighthouse_w' });

// ---------------------------------------------------------------- MMO 尺度：功能建筑分三档放大（2026-10-09 用户：功能建筑要更庞大、有奇观感）
// T1 城市地标（80–150m 级），T2 主要功能建筑（30–50m，塔 / 穹顶到 60–80m），T3 工坊类（18–26m）。
// 占地：正面线不动，在所属街坊内向后 / 两侧长（后边与侧边离街坊边 ≥3m）；高度一律按档放大。
const TIER = {
  // 高度按 2026-10-09 用户确认的概念图 v2（docs/city_lm_concepts/v2）：公会檐口 ≈42m、市政厅 ≈46m、钟塔 110–150m、工坊 22–26m
  1: { ids: ['cityhall', 'palace', 'cathedral', 'station', 'opera', 'market', 'academy'], grow: 1.6, h: 1.75, tower: 1.5 },
  2: { ids: ['exchange', 'guild', 'portal', 'inn', 'court', 'archive', 'merchant', 'bath', 'trainer', 'post', 'library', 'lecture', 'embassy', 'institute', 'observatory',
    'arcane', 'knights', 'hospital', 'clergy', 'customs', 'terminal', 'canal', 'royal_chapel', 'oldchurch', 'shipyard', 'greenhouse', 'scholar'], grow: 1.4, h: 1.9, tower: 1.5 },
  3: { ids: ['smith', 'artisan', 'cook', 'rogue', 'blackmarket', 'armory', 'gunnery', 'stables', 'fishmarket', 'tavern'], grow: 1.25, h: 1.6, tower: 1.3 },
};
// 个别覆盖：大圣堂中殿不再加高（概念图中殿 ≈55m），尖塔 140m
const TIER_H = { cathedral: { h: 1.55, spire: 140 } };
// 游戏端外观由 Blender 地标拼装器（tools/blender/city_kit/landmarks_build.py）按模块生成的类型；网页仍用 landmarks.js 的体块
export const KIT_TYPES = new Set(['civic', 'cityhall', 'exchange', 'guild', 'inn', 'bath', 'opera', 'terminal', 'market', 'pavilion', 'observatory',
  'academy', 'workshop', 'tavern', 'cathedral', 'station', 'airtower', 'grandpalace']);
const TIER_OF = {};
for (const [t, s] of Object.entries(TIER)) for (const id of s.ids) TIER_OF[id] = { t: +t, ...s };
function toWorldL(lm, p) { const c = Math.cos(lm.yaw), s = Math.sin(lm.yaw); return [lm.x + c * p[0] + s * p[1], lm.z - s * p[0] + c * p[1]]; }
function growLandmark(lm, b) {
  const ti = TIER_OF[lm.id];
  lm.tier = ti.t;
  const ov = TIER_H[lm.id] || {};
  lm.h = Math.round(lm.h * (ov.h || ti.h));
  if (lm.tower) lm.tower = Math.round(lm.tower * ti.tower);
  if (lm.spire) lm.spire = ov.spire || Math.round(lm.spire * ti.tower);
  const shared = LANDMARKS.filter((q) => q.block === lm.block && !q.orn).length > 1;
  const grow = shared ? Math.min(ti.grow, 1.15) : ti.grow;
  const back = inset(b.poly, 3), edge = inset(b.poly, 0.3);
  const others = LANDMARKS.filter((o) => o !== lm && !o.orn && o.block === lm.block).map((o) => inset(o.footprint, -4));
  const clear = (pts) => pts.every((q) => pointInPoly(toWorldL(lm, q), back)) && !others.some((P) => pts.some((q) => pointInPoly(toWorldL(lm, q), P)));
  // 加深只看新的后边线（两侧各收 2m 采样，原本贴街坊边的宽建筑也能加深）；加宽看新的两条侧边 + 前角在街坊内
  const deeper = (w, d, fz) => clear([-w / 2 + 2, -w / 4, 0, w / 4, w / 2 - 2].map((x) => [x, fz - d]));
  const wider = (w, d, fz) => clear([[-w / 2, fz - d + 1], [w / 2, fz - d + 1], [-w / 2, fz - d / 2], [w / 2, fz - d / 2]])
    && [[w / 2, fz], [-w / 2, fz]].every((q) => pointInPoly(toWorldL(lm, q), edge));
  // 先向后加深（宽度不变），再向两侧加宽（深度取上一步结果）
  const fz = lm.d / 2;
  let d = lm.d, w = lm.w;
  for (let k = 0; k <= 24; k++) { const g = grow - (grow - 1) * k / 24; if (deeper(w, lm.d * g, fz)) { d = lm.d * g; break; } }
  for (let k = 0; k <= 24; k++) { const g = grow - (grow - 1) * k / 24; if (wider(lm.w * g, d, fz)) { w = lm.w * g; break; } }
  const c = toWorldL(lm, [0, fz - d / 2]);
  lm.grown = +Math.max(w / lm.w, d / lm.d).toFixed(2);
  lm.x = c[0]; lm.z = c[1]; lm.w = Math.round(w); lm.d = Math.round(d);
}
for (const lm of LANDMARKS) {
  lm.footprint = rectPoly(lm.x, lm.z, lm.w, lm.d, lm.yaw);
  const b = blocks.find((q) => q.id === lm.block);
  if (b) { b.landmarks.push(lm.id); lm.level = b.level + CURB; } else if (lm.orn) { const q = blocks.find((k) => pointInPoly([lm.x, lm.z], k.poly)); lm.level = q ? q.level + CURB : null; } else if (lm.level === undefined) lm.level = null;
}
for (const lm of LANDMARKS) {
  if (!TIER_OF[lm.id]) continue;
  const b = blocks.find((q) => q.id === lm.block);
  if (b) growLandmark(lm, b); else { lm.tier = TIER_OF[lm.id].t; lm.h = Math.round(lm.h * TIER_OF[lm.id].h); }
  lm.footprint = rectPoly(lm.x, lm.z, lm.w, lm.d, lm.yaw);
}

// ---------------------------------------------------------------- 楼梯 / 坡道 / 桥（人工地基之间的连接）
// stair: top 为上沿中点，dir 为向上的方向（单位向量），从下台地一侧起步
export const STAIRS = [];
function stair(id, name, top, dir, width, h0, h1) {
  top = MP(top);
  const n = Math.ceil((h1 - h0) / 0.16), rise = (h1 - h0) / n, tread = 0.36;
  const landings = Math.floor((n - 1) / 14);
  const run = n * tread + landings * 2.4;
  const d = norm(dir);
  const bottom = sub(top, mul(d, run));
  STAIRS.push({ id, name, top, bottom, dir: d, width, h0, h1, n, rise, tread, landings, run });
}
stair('st_crown', '王冠阶梯', [-380, 430], [-1, 0], 18, LV.MID, LV.UP);
stair('st_palace', '宫廷阶梯', [-660, 430], [-1, 0], 12, LV.UP, LV.TOP);
stair('st_cape', '海岬阶梯', [-740, 470], [0, -1], 8, LV.UP, LV.TOP);
for (const x of [-300, -20, 70, 230]) stair(`st_river_${x}`, '河景阶梯', [x, 552], [0, -1], 8, LV.LOW, LV.MID);
for (const x of [-560, -460]) stair(`st_cliff_${x}`, '学院海崖阶梯', [x, 540], [0, -1], 8, LV.LOW, LV.UP);
for (const x of [-560, -460, -380, -300]) stair(`st_quay_${x}`, '码头阶梯', [x, 625], [0, -1], 8, LV.QUAY, LV.LOW);
stair('st_wquay', '西码头阶梯', [-628, 625], [0, -1], 8, LV.QUAY, LV.LOW);
for (const z of [740, 850, 950]) stair(`st_equay_${z}`, '东码头阶梯', [-196, z], [1, 0], 6, LV.QUAY, LV.LOW);
stair('st_royal', '王宫天阶', [-120, -380], [0, -1], 34, LV.MID, LV.TOP);
stair('st_royal_w', '旧城登宫阶', [-360, -380], [0, -1], 8, LV.MID, LV.TOP);
stair('st_royal_e', '军营登宫阶', [70, -380], [0, -1], 8, LV.MID, LV.TOP);
stair('st_royal_park', '公园登宫阶', [160, -480], [-1, 0], 8, LV.MID, LV.TOP);
stair('st_mage_royal', '星辉阶梯', [-520, -500], [1, 0], 8, LV.UP, LV.TOP);
for (const z of [-200, -100, 0, 100]) stair(`st_magebr_${z}`, '法师渠阶梯', [-497, z], [-1, 0], 8, LV.MID, LV.UP);

// deck: 架空/坡道路面，pts 为 [x, z, y]；width 总宽（含两侧人行道 side）
export const DECKS = [
  { id: 'bridge_s', name: '南桥', pts: [[-120, 552, LV.MID], [-120, 704, LV.LOW]], width: 20, side: 4, kind: 'bridge' },
  { id: 'bridge_e', name: '东桥', pts: [[160, 552, LV.MID], [160, 704, LV.LOW]], width: 18, side: 3.5, kind: 'bridge' },
  ...[-300, -220, -120, -20, 70, 160, 230].map((x) => ({ id: `canalbr_${x}`, name: x === -120 ? '凯旋桥' : '运河桥', pts: [[x, 166, LV.MID], [x, 185, LV.MID + 1.2], [x, 204, LV.MID]], width: x === -120 ? 24 : 12, side: x === -120 ? 5 : 2.5, kind: 'bridge' })),
  ...[-200, -100, 0, 100].map((z) => ({ id: `magebr_${z}`, name: '法师渠桥', pts: [[-530, z, LV.UP], [-497, z, LV.UP]], width: 8, side: 1.5, kind: 'bridge' })),
].filter((d) => d.kind !== 'none');
for (const d of DECKS) d.pts = d.pts.map((p) => [X(p[0]), Z(p[1]), p[2]]);
{ const L = BASINS[0]; [0, Math.PI / 2, Math.PI, -Math.PI / 2].forEach((a, i) => DECKS.push({ id: `lakebr_${i}`, name: '星辉湖桥', pts: [[L.x + Math.cos(a) * (L.r + 13), L.z + Math.sin(a) * (L.r + 13), LV.UP], [L.x + Math.cos(a) * (L.r + 1), L.z + Math.sin(a) * (L.r + 1), LV.UP + 1.4], [L.x + Math.cos(a) * (L.island - 4), L.z + Math.sin(a) * (L.island - 4), LV.UP + 1.4]], width: 7, side: 1.4, kind: 'bridge' })); }

// ---------------------------------------------------------------- 城墙与城门
// 北墙在王宫背后让开北苑叠园的入口（HILL 宽 230m，两侧各留 15m），墙端各立一座角楼
const WALL_GAP = [HILL.x - HILL.widths[0] / 2 - 16, HILL.x + HILL.widths[0] / 2 + 16];
export const WALL = { thickness: 8, height: 14, towers: [[WALL_GAP[0], Z(-600)], [WALL_GAP[1], Z(-600)]],
  pts: [[X(-960), Z(-600)], [WALL_GAP[0], Z(-600)], null, [WALL_GAP[1], Z(-600)], [X(230) - 16, Z(-600)], null, [X(230) + 16, Z(-600)], [300, Z(-600)], [300, 430 - 16], null, [300, 430 + 16], [300, Z(700) - 16], null, [300, Z(700) + 16], [300, Z(1000)]] };

// ---------------------------------------------------------------- v7.2 过渡带的连接：阶梯 / 栈桥 / 天桥 / 叠水 / 喷泉
// 阶梯（游戏坐标版）：top 为上沿中点，dir 为向上方向
function stairM(id, name, top, dir, width, h0, h1) {
  const n = Math.ceil((h1 - h0) / 0.16), rise = (h1 - h0) / n, tread = 0.36;
  const landings = Math.floor((n - 1) / 14), run = n * tread + landings * 2.4, d = norm(dir);
  STAIRS.push({ id, name, top, bottom: sub(top, mul(d, run)), dir: d, width, h0, h1, n, rise, tread, landings, run });
}
// 北苑：每道墙两侧各一座阶梯（宽 12），中间留叠水；王宫背后 30 → 33 → 39 → 45 → 51
for (let k = 0; k < 4; k++) {
  const zTop = HILL.zs[k], h0 = HILL.levels[k], h1 = HILL.levels[k + 1];
  for (const sx of [-1, 1]) stairM(`st_hill${k}_${sx < 0 ? 'w' : 'e'}`, k === 0 ? '宫后登园阶' : '北苑登台阶', [HILL.x + sx * 36, zTop], [0, -1], 12, h0, h1);
}
// 叠水：墙脚水池 + 墙面水帘（building 里画）。y0 = 低台标高，y1 = 高台标高，z 为高台南缘
export const FALLS = [1, 2, 3].map((k) => ({ x: HILL.x, z: HILL.zs[k], w: 16, y0: HILL.levels[k], y1: HILL.levels[k + 1], depth: 9 }));
// 王宫背后的后平台两端各一座阶梯：王宫台（30）→ 后平台（34），绕过王宫台基
stairM('st_hill_apron_w', '宫后侧阶', [HILL.apron.x0, (HILL.zs[0] + HILL.apron.z1) / 2], [1, 0], 8, LV.TOP, HILL.levels[0]);
stairM('st_hill_apron_e', '宫后侧阶', [HILL.apron.x1, (HILL.zs[0] + HILL.apron.z1) / 2], [-1, 0], 8, LV.TOP, HILL.levels[0]);
// 西海堤上崖阶梯：9 → 22（法师区 / 圣堂海岬），每段 41.5m
for (const z of STAIR_Z) stairM(`st_shelf_${Math.round(z)}`, '海崖阶梯', [SHELF.x, z], [1, 0], 8, LV.LOW, LV.UP);
// 栈桥与岛桥
{
  const deck = (id, name, a, b, width, side) => DECKS.push({ id, name, pts: [a, b], width, side, kind: 'bridge' });
  const e = (s) => s.xc + s.r - 3;                                   // 岛东缘（桥落脚）
  deck('br_light', '灯塔岛桥', [xOut(ISL.isl_light.zc) + 3, ISL.isl_light.zc, LV.LOW], [e(ISL.isl_light), ISL.isl_light.zc, LV.LOW], 12, 2.5);
  deck('br_plaza', '海神桥', [xOut(ISL.isl_plaza.zc) + 3, ISL.isl_plaza.zc, LV.LOW], [e(ISL.isl_plaza), ISL.isl_plaza.zc, LV.LOW], 16, 3);
  deck('br_dock', '商船码头桥', [xOut(ISL.isl_dock.zc) + 3, ISL.isl_dock.zc, LV.LOW], [e(ISL.isl_dock), ISL.isl_dock.zc, LV.QUAY], 14, 2.5);
  deck('via_air', '飞艇天桥', [SHELF.x + 2, ISL.isl_air.zc, LV.TOP], [e(ISL.isl_air), ISL.isl_air.zc, LV.TOP], 18, 3.5);
  deck('pier_1', '观海栈桥', [xOut(ISL.pier_pad1.zc) + 3, ISL.pier_pad1.zc, LV.LOW], [e(ISL.pier_pad1), ISL.pier_pad1.zc, LV.LOW], 9, 2);
  deck('pier_2', '渡轮栈桥', [xOut(ISL.pier_pad2.zc) + 3, ISL.pier_pad2.zc, LV.LOW], [e(ISL.pier_pad2), ISL.pier_pad2.zc, LV.LOW], 10, 2);
}
// 喷泉（原先写死在 build.js 里的两座 + 海神广场岛 + 北苑山顶泉池）
export const FOUNTAINS = [
  { x: X(-25), z: Z(750), y: LV.LOW + CURB, r: 9 }, { x: X(-470), z: Z(360), y: LV.UP + CURB, r: 6 },
  { x: ISL.isl_plaza.xc, z: ISL.isl_plaza.zc, y: LV.LOW + CURB, r: 14 }, { x: HILL.x, z: -648, y: HILL.levels[4] + CURB, r: 6 },
];

// ---------------------------------------------------------------- 电车、高架铁路、缆车
export const TRAM = { name: '1 号电车', pts: [[290, 430], [PLAZA.x + 40, 430], 'loop', [PLAZA.x, 470], [-120, 552], [-120, 704], [-120, 745], [60, 745], [60, 700], [290, 700]] };
export const VIADUCT = { name: '魔导列车高架', h: 17, pts: [[60, 870], [120, 892], [180, 900], [300, 900], [420, 900]].map(MP) };
export const CABLEWAY = { name: '学院缆车', pts: [[-108, 712, LV.LOW + 14], [-450, 470, LV.UP + 16]].map((p) => [X(p[0]), Z(p[1]), p[2]]) };

// ---------------------------------------------------------------- 地块生成：沿临街边排房
// MMO 尺度：开间更宽、楼层更少更高（首层 6m，上层 4.4m），屋顶更厚重
const STYLE_W = { core: [18, 28], trade: [16, 26], artisan: [16, 26], hero: [16, 24], academy: [20, 30], palace: [22, 32], cape: [14, 20], harbor: [14, 22], station: [18, 26], park: [14, 20], royal: [22, 32], mage: [16, 24], oldtown: [12, 18], military: [18, 28] };
export const LOTS = [];
function genLots(b) {
  if (b.use === 'square' || b.use === 'park' || b.use === 'empty') return;
  const R = rng(b.seed);
  const n = b.poly.length;
  const sw = b.codes.map((c) => ROAD[c].sw || 0);
  const BL = inset(b.poly, sw.map((s, i) => (isStreet(b.codes[i]) ? s : 1)));
  const front = b.codes.map(isStreet);
  const ex = bbox(b.poly);
  const inr = Math.min(ex[2] - ex[0], ex[3] - ex[1]) / 2;
  const d = Math.max(12, Math.min(18 + R() * 4, inr - 4));
  const bb0 = bbox(b.poly);
  const lmGrow = LANDMARKS.filter((l) => { const q = bbox(l.footprint); return q[0] < bb0[2] + 4 && q[2] > bb0[0] - 4 && q[1] < bb0[3] + 4 && q[3] > bb0[1] - 4; }).flatMap((l) => {
    // 占地外扩 3m + 正门前 18m 进场通道（门前不许再插沿街楼，否则堵门）
    const c = Math.cos(l.yaw), s = Math.sin(l.yaw), hw = Math.max(8, l.w * 0.3);
    const apron = [[-hw, l.d / 2], [hw, l.d / 2], [hw, l.d / 2 + 18], [-hw, l.d / 2 + 18]].map(([px, pz]) => [l.x + c * px + s * pz, l.z - s * px + c * pz]);
    return l.orn || l.type === 'gate' || l.type === 'gatebridge' ? [inset(l.footprint, -3)] : [inset(l.footprint, -3), apron];
  });
  const dist = DISTRICTS[b.district];
  const placed = [];
  const tryAdd = (poly, info) => {
    if (Math.abs(area(poly)) < 40) return false;
    for (const f of lmGrow) if (overlap(poly, f)) return false;
    for (const p of placed) if (overlap(poly, p.poly, 0.3)) return false;
    const floors = info.floors || Math.round(dist.floors[0] + R() * (dist.floors[1] - dist.floors[0]));
    const lot = { id: `${b.id}_${placed.length}`, block: b.id, district: b.district, level: b.level + CURB, poly, front: info.front || 0,
      floors, style: dist.style, corner: !!info.corner, shop: !!info.shop, seed: Math.floor(R() * 1e9), label: null };
    placed.push(lot);
    return true;
  };
  const dirOf = (i) => norm(sub(BL[(i + 1) % n], BL[i]));
  const inN = (i) => inwardNormal(BL, i);
  const elen = (i) => dist2(BL[i], BL[(i + 1) % n]);
  const trimS = new Array(n).fill(0), trimE = new Array(n).fill(0);
  const shopOf = (code) => code === 'B' || code === 'A' || code === 'P' || b.district === 'trade' || b.district === 'core';
  // 1) 街角楼：切角边（短临街边，两侧也临街）或直角
  for (let i = 0; i < n; i++) {
    const ip = (i - 1 + n) % n, inx = (i + 1) % n;
    if (front[i] && b.codes[i] !== 'P' && elen(i) < 15 && front[ip] && front[inx] && b.codes[ip] !== 'P' && b.codes[inx] !== 'P') {
      const A0 = BL[i], B0 = BL[inx];
      const P1 = sub(A0, mul(dirOf(ip), d * 0.7)), P2 = add(B0, mul(dirOf(inx), d * 0.7));
      const Iq = lineIntersect(add(A0, mul(inN(ip), d)), dirOf(ip), add(B0, mul(inN(inx), d)), dirOf(inx));
      if (Iq) {
        const poly = [P1, A0, B0, P2, add(P2, mul(inN(inx), d)), Iq, add(P1, mul(inN(ip), d))];
        if (tryAdd(convexHull(poly), { corner: true, shop: shopOf(b.codes[i]), front: 0 })) { trimE[ip] = d * 0.7; trimS[inx] = d * 0.7; }
      }
    } else if (front[ip] && front[i] && b.codes[i] !== 'P' && b.codes[ip] !== 'P' && elen(ip) >= 15 && elen(i) >= 15) {
      const Cn = BL[i];
      const Q1 = sub(Cn, mul(dirOf(ip), d)), Q2 = add(Cn, mul(dirOf(i), d));
      const Iq = lineIntersect(add(Cn, mul(inN(ip), d)), dirOf(ip), add(Cn, mul(inN(i), d)), dirOf(i));
      if (Iq && tryAdd(convexHull([Q1, Cn, Q2, Iq]), { corner: true, shop: shopOf(b.codes[i]) })) { trimE[ip] = d; trimS[i] = d; }
    }
  }
  // 2) 沿边排房
  const [w0, w1] = STYLE_W[b.district] || [14, 22];
  for (let i = 0; i < n; i++) {
    if (!front[i] || elen(i) < 12) continue;
    const a = BL[i], dir = dirOf(i), nn = inN(i), L = elen(i);
    let t = trimS[i];
    const tEnd = L - trimE[i];
    while (tEnd - t > 8) {
      let w = w0 + R() * (w1 - w0);
      if (tEnd - t - w < w0 * 0.7) w = tEnd - t;
      const p0 = add(a, mul(dir, t)), p1 = add(a, mul(dir, t + w));
      const dd = d * (0.85 + R() * 0.2);
      const poly = [p0, p1, add(p1, mul(nn, dd)), add(p0, mul(nn, dd))];
      tryAdd(poly, { shop: shopOf(b.codes[i]), front: 0 });
      t += w;
    }
  }
  // 3) 标签：按道路等级优先分配给沿街楼
  const rank = { B: 0, P: 1, A: 2, S: 3, L: 4 };
  if (b.labels.length) {
    const cand = [...placed].sort((p, q) => (edgeRank(p) + (p.corner ? 0.5 : 0)) - (edgeRank(q) + (q.corner ? 0.5 : 0)));
    b.labels.forEach((lab, k) => { if (cand[k]) { cand[k].label = lab; cand[k].shop = true; } });
  }
  function edgeRank(p) {
    const c = centroid(p.poly);
    let best = 9;
    for (let i = 0; i < n; i++) if (front[i]) {
      const dd = segDistLocal(c, BL[i], BL[(i + 1) % n]);
      if (dd < d * 0.9) best = Math.min(best, rank[b.codes[i]] ?? 5);
    }
    return best;
  }
  LOTS.push(...placed);
}
function dist2(a, b) { return Math.hypot(a[0] - b[0], a[1] - b[1]); }
function segDistLocal(p, a, b) {
  const ab = sub(b, a), t = Math.max(0, Math.min(1, ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / (ab[0] ** 2 + ab[1] ** 2 || 1)));
  return dist2(p, add(a, mul(ab, t)));
}
export function convexHull(pts) {
  const P = pts.map((p) => [p[0], p[1]]).sort((a, b) => a[0] - b[0] || a[1] - b[1]);
  const cr = (o, a, b) => (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0]);
  const lo = [], up = [];
  for (const p of P) { while (lo.length >= 2 && cr(lo[lo.length - 2], lo[lo.length - 1], p) <= 1e-9) lo.pop(); lo.push(p); }
  for (let i = P.length - 1; i >= 0; i--) { const p = P[i]; while (up.length >= 2 && cr(up[up.length - 2], up[up.length - 1], p) <= 1e-9) up.pop(); up.push(p); }
  up.pop(); lo.pop();
  return lo.concat(up);
}
for (const b of blocks) genLots(b);

// ---------------------------------------------------------------- 街道家具：行道树、路灯（沿路缘内侧）
export const TREES = [], LAMPS = [], PALMS = [];
// 行道树绿化带：大道 / 主干道 / 街道两侧，紧贴路缘石的一条草带，树按统一 12m 间距居中排布，路灯放在隔一个树距的空档里
export const TREE_SPACING = 12;
export const STRIPS = [];
// 树池：台地 / 岸线 / 环湖这些不挨着人行道的树，每棵配一块 3.8×2.8m 的草池（带花岗岩镶边），树干永远立在绿地上
function bed(x, z, level, dx, dz) {
  const L = Math.hypot(dx, dz) || 1, d = [dx / L, dz / L];
  STRIPS.push({ a: [x - d[0] * 1.9, z - d[1] * 1.9], b: [x + d[0] * 1.9, z + d[1] * 1.9], w: 2.8, level, block: 'bed', code: 'E', district: '', nn: [-d[1], d[0]] });
  return { strip: STRIPS.length - 1, yaw: Math.atan2(-d[1], d[0]) };
}
const STRIP_W = { B: 1.8, A: 1.6, S: 1.2 };
// 功能建筑占地（局部 +z 为正面）：两侧 / 背面外扩 1.5m，正面外扩到门前台阶末端
function stripBlocked(p, w) {
  for (const l of LANDMARKS) {
    if (l.orn || l.type === 'gate') continue;
    const dx = p[0] - l.x, dz = p[1] - l.z, c = Math.cos(l.yaw), s = Math.sin(l.yaw);
    const lx = c * dx - s * dz, lz = s * dx + c * dz;
    const front = l.type === 'gatebridge' ? 1.5 : l.type === 'grandpalace' ? 19 : l.type === 'cathedral' || l.type === 'magetower' || l.type === 'portal' ? 5 : 10;
    const m = 1.5 + w / 2;
    if (Math.abs(lx) < l.w / 2 + m && lz > -l.d / 2 - m && lz < l.d / 2 + front) return true;
  }
  return false;
}
for (const b of blocks) {
  const n = b.poly.length;
  for (let i = 0; i < n; i++) {
    const code = b.codes[i];
    if (!STRIP_W[code]) continue;
    const a = b.poly[i], c = b.poly[(i + 1) % n], L = dist2(a, c);
    if (L < 16) continue;
    const dir = norm(sub(c, a)), nn = inwardNormal(b.poly, i), w = STRIP_W[code], off = 0.3 + w / 2;
    // 两端让出街角 4m
    const s0 = add(add(a, mul(dir, 4)), mul(nn, off)), s1 = add(add(c, mul(dir, -4)), mul(nn, off));
    // 被功能建筑（含门前台阶 / 台基）占住的区段不种：按 1m 采样切成若干段绿化带，树仍落在同一条 12m 网格上
    const len = L - 8, k = Math.floor(len / TREE_SPACING), t0 = (len - k * TREE_SPACING) / 2;
    const free = (t) => !stripBlocked(add(s0, mul(dir, t)), w);
    const runs = []; let r0 = null;
    for (let t = 0; t <= len + 0.01; t += 1) { if (free(t)) { if (r0 === null) r0 = t; } else if (r0 !== null) { runs.push([r0, t - 1]); r0 = null; } }
    if (r0 !== null) runs.push([r0, len]);
    const warm = b.district === 'harbor' || b.district === 'station' || b.district === 'park';
    const kind = b.district === 'cape' || b.district === 'academy' || b.district === 'mage' ? 'cypress' : 'round';
    for (const [u0, u1] of runs) {
      if (u1 - u0 < 3) continue;
      STRIPS.push({ a: add(s0, mul(dir, u0)), b: add(s0, mul(dir, u1)), w, level: b.level + CURB, block: b.id, code, district: b.district, nn });
      for (let j = 0; j <= k; j++) {
        const t = t0 + j * TREE_SPACING;
        if (t < u0 + 1.2 || t > u1 - 1.2) continue;
        const p = add(s0, mul(dir, t));
        (warm && code === 'B' ? PALMS : TREES).push({ x: p[0], z: p[1], y: b.level + CURB, s: code === 'B' ? 0.85 : 0.66, kind, strip: STRIPS.length - 1, yaw: Math.atan2(-dir[1], dir[0]) });
        const tq = t + TREE_SPACING / 2;
        if (j < k && j % 2 === 0 && tq < u1 - 0.5) { const q = add(s0, mul(dir, tq)); LAMPS.push({ x: q[0], z: q[1], y: b.level + CURB, yaw: Math.atan2(-nn[0], -nn[1]) }); }
      }
    }
  }
}
for (const b of blocks) {
  const R = rng(b.seed + 11);
  if (b.use === 'park') {
    const [x0, z0, x1, z1] = bbox(b.poly);
    const cnt = Math.floor(Math.abs(area(b.poly)) / 180);
    // 只种在草坪内（街区内缩 5m 即草坪边，再退 1.5m 给树干），树间距 ≥ 8m（树冠互不穿插）
    const lawn = inset(b.poly, 6.5), lawn5 = inset(b.poly, 5), mine = [];
    for (let k = 0, placed = 0; k < cnt * 12 && placed < cnt; k++) {
      const p = [x0 + 6 + R() * (x1 - x0 - 12), z0 + 6 + R() * (z1 - z0 - 12)];
      if (!lawn.length || !lawn5.length || !pointInPoly(p, lawn) || !pointInPoly(p, lawn5)) continue;
      if (LANDMARKS.some((l) => l.block === b.id && pointInPoly(p, inset(l.footprint, -6)))) continue;
      if (BASINS.some((q) => Math.hypot(p[0] - q.x, p[1] - q.z) < q.r + 6)) continue;
      if (mine.some((q) => Math.hypot(p[0] - q[0], p[1] - q[1]) < 8)) continue;
      mine.push(p); placed++;
      (b.district === 'park' && R() < 0.4 ? PALMS : TREES).push({ x: p[0], z: p[1], y: b.level + CURB, s: 0.8 + R() * 0.6, kind: b.district === 'cape' ? 'cypress' : R() < 0.25 ? 'cypress' : 'round' });
    }
  }
}
// 星辉湖与公园湖环湖树、灯
for (const bs of BASINS) for (let i = 0; i < (bs.island ? 28 : 16); i++) {
  const ang = (i + 0.5) / (bs.island ? 28 : 16) * Math.PI * 2;
  if (bs.bridges.some((q) => Math.abs(Math.atan2(Math.sin(ang - q), Math.cos(ang - q))) < 0.12)) continue;
  const tx = bs.x + Math.cos(ang) * (bs.r + 7), tz = bs.z + Math.sin(ang) * (bs.r + 7);
  TREES.push({ x: tx, z: tz, y: bs.level, s: 0.9, kind: bs.island ? 'cypress' : 'round', ...bed(tx, tz, bs.level, -Math.sin(ang), Math.cos(ang)) });
  if (i % 2) LAMPS.push({ x: bs.x + Math.cos(ang) * (bs.r + 3), z: bs.z + Math.sin(ang) * (bs.r + 3), y: bs.level, yaw: Math.atan2(-Math.cos(ang), -Math.sin(ang)) });
}
// 礼仪视线：大阶梯前 40m、方尖碑 / 雕像 10m 内不种树
{
  const clear = (t) => {
    for (const st of STAIRS) {
      if (st.width < 18) continue;
      const rel = [t.x - st.bottom[0], t.z - st.bottom[1]];
      const along = rel[0] * st.dir[0] + rel[1] * st.dir[1], lat = Math.abs(rel[0] * -st.dir[1] + rel[1] * st.dir[0]);
      if (along > -40 && along < st.run + 2 && lat < st.width / 2 + 8) return false;
    }
    for (const l of LANDMARKS) if (l.orn && Math.hypot(t.x - l.x, t.z - l.z) < 10) return false;
    // 北苑叠园的阶梯 + 叠水走廊、岛上广场喷泉周围不种树
    if (t.z < HILL.zs[0] + 1 && t.z > HILL.zs[4] && Math.abs(t.x - HILL.x) < 50) return false;
    for (const f of FOUNTAINS) if (Math.hypot(t.x - f.x, t.z - f.z) < f.r + 5) return false;
    return true;
  };
  for (const arr of [TREES, PALMS]) { const keep = arr.filter(clear); arr.length = 0; arr.push(...keep); }
}
// 码头棕榈与灯
for (let z = Z(670); z < Z(990); z += 12) { PALMS.push({ x: X(-226), z, y: LV.QUAY, s: 1, ...bed(X(-226), z, LV.QUAY, 0, 1) }); LAMPS.push({ x: X(-238), z: z + 6, y: LV.QUAY, yaw: Math.PI / 2 }); }
for (let x = X(-580); x < X(-250); x += 24) LAMPS.push({ x, z: Z(646), y: LV.QUAY, yaw: Math.PI });
for (let x = X(-190); x < 290; x += 12) { TREES.push({ x, z: Z(568), y: LV.LOW, s: 1, kind: 'round', ...bed(x, Z(568), LV.LOW, 1, 0) }); if (Math.round((x - X(-190)) / 12) % 2) LAMPS.push({ x, z: Z(596), y: LV.LOW, yaw: Math.PI }); }

// ---------------------------------------------------------------- 船只与飞艇（装饰）
export const SHIPS = [
  { x: -480, z: 690, yaw: 0.1, len: 46, kind: 'clipper' }, { x: -350, z: 680, yaw: -0.05, len: 30, kind: 'steamer' },
  { x: -540, z: 800, yaw: 1.5, len: 38, kind: 'clipper' }, { x: -300, z: 820, yaw: 1.6, len: 24, kind: 'boat' },
  { x: -270, z: 740, yaw: 1.55, len: 18, kind: 'boat' }, { x: -420, z: 930, yaw: 0.4, len: 52, kind: 'steamer' },
  { x: -700, z: 1120, yaw: 2.4, len: 34, kind: 'clipper' }, { x: 80, z: 1090, yaw: 0.9, len: 26, kind: 'boat' },
];
for (const sh of SHIPS) { sh.x = X(sh.x); sh.z = Z(sh.z); }
export const AIRSHIPS = [{ x: -930, z: 245, y: LV.TOP + 26, len: 58, moored: true }, { x: -200, z: 300, y: 120, len: 70 }, { x: 200, z: 820, y: 95, len: 46 }];
for (const a of AIRSHIPS) { a.x = X(a.x); a.z = Z(a.z); }
// 泊在飞艇泊台（离岸岛）上的飞艇；其余在城市 / 海面 / 山前上空绕圈巡航（游戏里 Airship 节点按 r / speed 飞）
AIRSHIPS[0].x = ISL.isl_air.xc + 12; AIRSHIPS[0].z = ISL.isl_air.zc + 20; AIRSHIPS[0].y = LV.TOP + 17; AIRSHIPS[0].len = 60;
AIRSHIPS[1].r = 150; AIRSHIPS[1].speed = 5; AIRSHIPS[2].r = 130; AIRSHIPS[2].speed = 4.5;
AIRSHIPS.push({ x: SHELF.x - 260, z: 180, y: 70, len: 60, r: 140, speed: 5.5 }, { x: HILL.x, z: -470, y: 120, len: 60, r: 150, speed: 4 }, { x: X(-120), z: Z(430), y: 100, len: 60, r: 170, speed: 3.5 });
// 西海堤 / 栈桥的船只（游戏坐标）
SHIPS.push({ x: xOut(696) - 84 - 16, z: 696 + 26, yaw: 0.0, len: 38, kind: 'clipper' }, { x: ISL.isl_dock.xc + 44, z: ISL.isl_dock.zc + 4, yaw: Math.PI / 2, len: 46, kind: 'clipper' },
  { x: xOut(-262) - 100, z: -262 + 40, yaw: 0.3, len: 22, kind: 'boat' }, { x: ISL.isl_plaza.xc - 52, z: ISL.isl_plaza.zc + 30, yaw: 1.2, len: 26, kind: 'steamer' });

// ---- 西海堤沿线：棕榈（12m 等距）+ 路灯（让开上崖阶梯），海神广场岛喷泉环路灯，北苑叠园行列柏
for (let z = SHELF.z0 + 24; z < SHELF.z1 - 10; z += TREE_SPACING) {
  if (STAIR_Z.some((c) => Math.abs(z - c) < 12)) continue;
  PALMS.push({ x: SHELF.x - 17, z, y: SHELF.level + CURB, s: 1, ...bed(SHELF.x - 17, z, SHELF.level, 0, 1) });
  if (Math.round((z - SHELF.z0) / TREE_SPACING) % 2) LAMPS.push({ x: SHELF.x - 22, z: z + 6, y: SHELF.level + CURB, yaw: Math.PI / 2 });
}
for (const s of ISLANDS) {
  const lamps = s.r > 20 ? 8 : 4;
  for (let i = 0; i < lamps; i++) { const a = (i + 0.5) / lamps * Math.PI * 2; LAMPS.push({ x: s.xc + Math.cos(a) * (s.r - 5), z: s.zc + Math.sin(a) * (s.r - 5), y: s.level + CURB, yaw: a + Math.PI }); }
  if (s.id === 'isl_light') for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2 + 0.3; TREES.push({ x: s.xc + Math.cos(a) * 19, z: s.zc + Math.sin(a) * 19, y: s.level + CURB, s: 0.9, kind: 'cypress', ...bed(s.xc + Math.cos(a) * 19, s.zc + Math.sin(a) * 19, s.level, -Math.sin(a), Math.cos(a)) }); }
  if (s.id === 'isl_plaza') for (let i = 0; i < 10; i++) { const a = i / 10 * Math.PI * 2 + 0.15; if (Math.abs(a - Math.PI * 2) < 0.4 || a < 0.4) continue; PALMS.push({ x: s.xc + Math.cos(a) * 31, z: s.zc + Math.sin(a) * 31, y: s.level + CURB, s: 1, ...bed(s.xc + Math.cos(a) * 31, s.zc + Math.sin(a) * 31, s.level, -Math.sin(a), Math.cos(a)) }); }
}
for (let k = 1; k <= 3; k++) {
  const zS = HILL.zs[k - 1], zN = HILL.zs[k], w = (HILL.widths[k - 1] + HILL.widths[k]) / 4;     // 该台南缘 / 北缘，半宽
  for (let z = zS - 14; z > zN + 10; z -= TREE_SPACING) for (const sx of [-1, 1]) TREES.push({ x: HILL.x + sx * (w - 20), z, y: HILL.levels[k] + CURB, s: 1, kind: 'cypress', ...bed(HILL.x + sx * (w - 20), z, HILL.levels[k], 0, 1) });
  for (let z = zS - 20; z > zN + 14; z -= 24) for (const sx of [-1, 1]) LAMPS.push({ x: HILL.x + sx * 56, z, y: HILL.levels[k] + CURB, yaw: sx > 0 ? Math.PI / 2 : -Math.PI / 2 });
}

// ---------------------------------------------------------------- 标签：区名与街名
export const DISTRICT_LABELS = [
  ['royal', -120, -470], ['mage', -740, -160], ['oldtown', -310, -60], ['military', 20, -40], ['cpark', 230, -300],
  ['nobles', -820, 260], ['academy', -520, 400], ['cape', -810, 760], ['core', -120, 390], ['trade', 120, 260],
  ['artisan', 120, 520], ['hero', -300, 300], ['harbor', -440, 720], ['station', 120, 840], ['park', 150, 955],
].map(([d, x, z]) => ({ district: d, name: DISTRICTS[d].name, x: X(x), z: Z(z) }));
export const STREET_LABELS = [
  ['王冠大道', 140, 430], ['北门大道', -120, 225], ['钟楼街', 30, 345], ['北环街', 30, 260], ['工坊街', 120, 515],
  ['英雄街', -220, 300], ['银行街', -20, 300], ['东城街', 230, 300], ['河景步道', 60, 552], ['港湾街', -470, 585],
  ['车站大街', 120, 700], ['南桥', -120, 625], ['东桥', 160, 625], ['学院大道', -520, 430], ['圣堂大街', -810, 520],
  ['王宫大道', -120, 20], ['晴岚运河', 0, 185], ['法师渠', -510, -150], ['旧城巷', -330, -50], ['骑士街', 20, -160],
].map(([name, x, z]) => ({ name, x: X(x), z: Z(z) }));
STREET_LABELS.push({ name: '西海堤', x: SHELF.x - 24, z: 190 }, { name: '飞艇天桥', x: SHELF.x - 90, z: ISL.isl_air.zc }, { name: '海神广场岛', x: ISL.isl_plaza.xc, z: ISL.isl_plaza.zc },
  { name: '西港灯塔', x: ISL.isl_light.xc, z: ISL.isl_light.zc }, { name: '北苑叠园', x: HILL.x, z: (HILL.zs[1] + HILL.zs[2]) / 2 }, { name: '商船码头岛', x: ISL.isl_dock.xc, z: ISL.isl_dock.zc });
// 全城（含西侧岛 / 北苑叠园）的外包框，供小地图和导出范围用；CITY_RECT 仍是城墙围出的主城矩形
export const EXTENT = (() => {
  const e = { x0: Infinity, z0: Infinity, x1: -Infinity, z1: -Infinity };
  for (const t of TERRACES) if (!t.outer) for (const [x, z] of t.poly) { e.x0 = Math.min(e.x0, x); e.z0 = Math.min(e.z0, z); e.x1 = Math.max(e.x1, x); e.z1 = Math.max(e.z1, z); }
  return e;
})();


// ---------------------------------------------------------------- 可进入的功能建筑（白盒）
// 每栋功能建筑 / 有招牌的店铺：一个室内大厅 + 一个门洞。局部坐标：x 横向，z 朝正面（+z 为外）。
// hall 局部多边形；floor / ceil 为相对地面标高；door：外立面 z、宽、高、向内深度；landing 门外平台长；steps 台阶长（addSteps 时补画）
const rectL = (x0, z0, x1, z1) => [[x0, z0], [x1, z0], [x1, z1], [x0, z1]];
const ngon = (r, n, cz = 0) => Array.from({ length: n }, (_, i) => [Math.cos((i + 0.5) / n * Math.PI * 2) * r, cz + Math.sin((i + 0.5) / n * Math.PI * 2) * r]);
const CIVIC_T = new Set(['civic', 'cityhall', 'exchange', 'guild', 'inn', 'bath', 'opera', 'terminal', 'market', 'pavilion', 'observatory']);
function enterSpec(lm) {
  const { w, d, h } = lm;
  if (CIVIC_T.has(lm.type)) return { hall: rectL(-w / 2 + 0.7, -d / 2 + 0.7, w / 2 - 0.7, d / 2 - 0.7), floor: 1.2, ceil: 1.2 + Math.min(18, h * 0.55),
    doorZ: d / 2 + 2.6, dw: Math.max(7, Math.min(10, w * 0.18)), dh: Math.max(8, Math.min(12, h * 0.3)), din: 3.9, landing: 3.4, steps: 2.0 };
  if (lm.type === 'workshop') return { hall: rectL(-w / 2 + 0.7, -d / 2 + 0.7, w / 2 - 0.7, d / 2 - 0.7), floor: 0.8, ceil: 0.8 + Math.min(12, h * 0.6),
    doorZ: d / 2, dw: 6, dh: 7, din: 1.4, landing: 0.5, steps: 1.8, addSteps: true };
  if (lm.type === 'tavern') return { hall: rectL(-w / 2 + 0.7, -d / 2 + 0.7, w / 2 - 0.7, d / 2 - 0.7), floor: 0.6, ceil: lm.h - 1,
    doorZ: d / 2, dw: 4.5, dh: 5.5, din: 1.4, landing: 0.5, steps: 1.4, addSteps: true };
  if (lm.type === 'academy') return { hall: rectL(-w / 2 + 0.7, d / 2 - 22.3, w / 2 - 0.7, d / 2 - 0.7), floor: 1, ceil: 1 + Math.min(14, h * 0.5),
    doorZ: d / 2, dw: 7, dh: 9, din: 1.4, landing: 1.4, steps: 2.0 };
  if (lm.type === 'station') return { hall: rectL(-21.3, -d / 2 + 0.7, 21.3, d / 2 - 0.7), floor: 1.2, ceil: 1.2 + Math.min(20, h * 0.5),
    doorZ: d / 2, dw: 12, dh: 10, din: 1.4, landing: 1.0, steps: 2.0, addSteps: true };
  if (lm.type === 'grandpalace') { const cw = w * 0.46, cd = 50, z0 = -d / 2;
    return { hall: rectL(-cw / 2 + 0.7, z0 + 0.7, cw / 2 - 0.7, z0 + cd - 0.7), floor: 5.2, ceil: 5.2 + 18, doorZ: z0 + cd + 2.6, dw: 10, dh: 12, din: 3.9, landing: 3.4, steps: 2.0,
      podium: { poly: rectL(-w / 2 - 4, -d / 2 - 4, w / 2 + 4, d / 2 + 4), y: 4 }, front: { z: d / 2 + 4, len: 13.4, w: 70 },
      solids: [rectL(-cw / 2, z0, cw / 2, z0 + cd), ...[-1, 1].flatMap((sx) => [rectL(sx * (cw / 2 + 17) - 17, z0 + 3, sx * (cw / 2 + 17) + 17, z0 + 33),
        rectL(sx * (w / 2 - 18) - 18, 6 - (d - 30) / 2, sx * (w / 2 - 18) + 18, 6 + (d - 30) / 2), rectL(sx * (w / 2 - 18) - 20, d / 2 - 42, sx * (w / 2 - 18) + 20, d / 2 - 2)])],
      inner: [-1, 1].map((sx) => rectL(sx * (cw / 2 - 8) - 7.5, z0 + 0.5, sx * (cw / 2 - 8) + 7.5, z0 + 15.5)) }; }
  if (lm.type === 'cathedral') { const nw = w * 0.22, tw2 = 2 * Math.min(7, (w / 2 - nw) / 2);
    return { hall: rectL(-nw + 0.7, -d / 2 + 10.7, nw - 0.7, d / 2 - 12.7), floor: 1.4, ceil: 1.4 + Math.min(26, h - 6), doorZ: d / 2 - 12, dw: 7, dh: 12, din: 1.3, landing: 0, steps: 2.4,
      podium: { poly: rectL(-w / 2 - 1, -d / 2 - 1, w / 2 + 1, d / 2 + 1), y: 1.4 }, front: { z: d / 2 + 1, len: 2.4, w: w * 0.5 },
      solids: [rectL(-nw, -d / 2 + 10, nw, d / 2 - 12), rectL(-w / 2, -d / 2 + 14, -nw, d / 2 - 14), rectL(nw, -d / 2 + 14, w / 2, d / 2 - 14),
        rectL(-w / 2, d / 2 - 14, -w / 2 + tw2, d / 2), rectL(w / 2 - tw2, d / 2 - 14, w / 2, d / 2), rectL(-nw, -d / 2 + 10 - nw, nw, -d / 2 + 10)] }; }
  if (lm.type === 'magetower') return { hall: ngon(10.3, 24), floor: 3, ceil: 18, doorZ: 11, dw: 5, dh: 7, din: 1.5, landing: 3, steps: 3.2,
    podium: { poly: ngon(14, 24), y: 3 }, front: { z: 14, len: 3.2, w: 8 }, solids: [ngon(11, 24)] };
  if (lm.type === 'portal') { const r = lm.w / 2 - 2;
    return { hall: ngon(r - 0.7, 28), floor: 1.2, ceil: Math.min(20, lm.h * 0.55), doorZ: r, dw: 7, dh: 9, din: 1.5, landing: 3, steps: 2.0,
      podium: { poly: ngon(r + 3, 28), y: 1.2 }, front: { z: r + 3, len: 2.0, w: 14 }, solids: [ngon(r, 28)] }; }
  if (lm.type === 'airtower') { const r = lm.w / 2 - 1.5;   // 瞭望塔底层：八角售票 / 候梯大厅
    return { hall: ngon(r - 1.2, 8, 0), floor: 1.2, ceil: 16, doorZ: r * Math.cos(Math.PI / 8), dw: 6, dh: 9, din: 1.5, landing: 3, steps: 2.0,
      podium: { poly: ngon(r + 4, 8), y: 1.2 }, front: { z: (r + 4) * Math.cos(Math.PI / 8) - 0.05, len: 2.0, w: 12 }, solids: [ngon(r, 8)] }; }
  return null;
}
const lw = (lm, p) => { const c = Math.cos(lm.yaw), s = Math.sin(lm.yaw); return [lm.x + c * p[0] + s * p[1], lm.z - s * p[0] + c * p[1]]; };
export const CUTS = [], HALLS = [];
// 坡脚处地面：在街区内取人行道标高，否则取台地（车行道 / 广场）标高；都没有就用建筑标高
function rampFootLevel(p, fallback) {
  for (const q of BASINS) if (q.island > 0 && Math.hypot(p[0] - q.x, p[1] - q.z) < q.island) return q.level + 1.4;   // 湖心岛面
  const b = blocks.find((q) => pointInPoly(p, q.poly));
  if (b) return b.level + CURB;
  const t = terraceAt(p[0], p[1]);
  return t ? t.level : fallback;
}
function addEnter(owner, toWorld, level, sp, yawOut) {
  const ax0 = toWorld([1, 0]), o0 = toWorld([0, 0]);
  const ax = norm(sub(ax0, o0)), an = [ax[1] * -1 * -1, 0]; void an;
  const out = norm(sub(toWorld([0, 1]), o0));
  const door = toWorld([0, sp.doorZ]);
  const cut = { o: door, ax, an: out, hw: sp.dw / 2, y0: level + sp.floor, y1: level + sp.floor + sp.dh, din: sp.din, dout: 0.5 };
  CUTS.push(cut);
  const hall = { id: owner.id, hall: sp.hall.map(toWorld), hallL: sp.hall, floor: level + sp.floor, ceil: level + sp.ceil, level, cut, sp, toWorld, yaw: yawOut,
    podium: sp.podium ? { poly: sp.podium.poly.map(toWorld), y: level + sp.podium.y } : null,
    solids: (sp.solids || []).map((q) => q.map(toWorld)), inner: (sp.inner || []).map((q) => q.map(toWorld)) };
  // 门外平台与台阶 / 坡道（世界坐标：沿外法线）
  const dz = sp.doorZ;
  hall.landing = sp.landing > 0 ? [[-sp.dw / 2 - 1, dz], [sp.dw / 2 + 1, dz], [sp.dw / 2 + 1, dz + sp.landing], [-sp.dw / 2 - 1, dz + sp.landing]].map(toWorld) : null;
  const fr = sp.front || { z: dz + sp.landing, len: sp.steps, w: sp.dw + 2 };
  // 坡脚落在实际地面上（门前若是广场 / 车行道，比街区人行道低 0.18m，否则会留一道真实物理迈不上的坎）
  const foot = toWorld([0, fr.z + fr.len + 0.3]), gl = rampFootLevel(foot, level);
  hall.ramp = { a: toWorld([0, fr.z]), b: toWorld([0, fr.z + fr.len]), w: fr.w, y0: level + (sp.podium ? sp.podium.y : sp.floor), y1: gl, dir: out };
  hall.ramps = [hall.ramp];
  // 台基建筑：门外平台比台基高时，平台前再补一段台阶下到台基面
  if (sp.podium && sp.floor - sp.podium.y > 0.3) {
    const z0 = dz + sp.landing, rise = sp.floor - sp.podium.y;
    hall.ramps.push({ a: toWorld([0, z0]), b: toWorld([0, z0 + rise / 0.16 * 0.32]), w: sp.dw + 2, y0: level + sp.floor, y1: level + sp.podium.y, dir: out, addSteps: true });
  }
  hall.tunnel = [[-sp.dw / 2, dz - sp.din], [sp.dw / 2, dz - sp.din], [sp.dw / 2, dz], [-sp.dw / 2, dz]].map(toWorld);
  HALLS.push(hall);
  owner.enter = hall;
  return hall;
}
for (const lm of LANDMARKS) {
  if (lm.orn || !lm.func) continue;
  const sp = enterSpec(lm);
  if (!sp) continue;
  addEnter(lm, (p) => lw(lm, p), lm.level ?? LV.MID, sp, lm.yaw);
}
// 有招牌的沿街楼：底层店铺（门在临街面中央）
function lotFront(l) {
  const b = BLOCKS.find((q) => q.id === l.block);
  let best = 0, bl = -1;
  for (let i = 0; i < l.poly.length; i++) {
    const a = l.poly[i], c = l.poly[(i + 1) % l.poly.length], m = mul(add(a, c), 0.5), L = dist2(a, c);
    let dmin = Infinity;
    for (let k = 0; k < b.poly.length; k++) dmin = Math.min(dmin, segDistLocal(m, b.poly[k], b.poly[(k + 1) % b.poly.length]));
    const score = L - dmin * 4;
    if (dmin < (ROAD.B.sw + 1.5) && score > bl) { bl = score; best = i; }
  }
  return best;
}
for (const l of LOTS) {
  if (!l.label) continue;
  const fe = lotFront(l);
  l.fe = fe;
  const a = l.poly[fe], c = l.poly[(fe + 1) % l.poly.length];
  const ax = norm(sub(c, a)), inn = inwardNormal(l.poly, fe), out = [-inn[0], -inn[1]];
  const m = mul(add(a, c), 0.5);
  const toW = (p) => [m[0] + ax[0] * p[0] + out[0] * p[1], m[1] + ax[1] * p[0] + out[1] * p[1]];
  const toL = (q) => { const r = sub(q, m); return [r[0] * ax[0] + r[1] * ax[1], r[0] * out[0] + r[1] * out[1]]; };
  const hallL = inset(l.poly, 0.5).map(toL);
  addEnter(l, toW, l.level, { hall: hallL, floor: 0, ceil: 5.2, doorZ: 0, dw: 2.8, dh: 3.8, din: 1.0, landing: 0, steps: 0 }, Math.atan2(out[0], out[1]));
}
// 室内服务位：门轴线向内 0.55 进深处，横向 3.2m 一位，面朝门
function hallSpot(h, slot, n) {
  const zs = h.hallL.map((p) => p[1]), zmin = Math.min(...zs);
  const zin = h.sp.doorZ - h.sp.din, depth = zin - zmin;
  const z = zin - Math.min(depth * 0.55, 10), x = (slot - (n - 1) / 2) * 3.2;
  const p = h.toWorld([x, z]);
  return [p[0], p[1], h.yaw];
}

// ---------------------------------------------------------------- 人物、探索点、出生点（与 v5 契约 ID 一致，见 docs/city_v5/COMPATIBILITY.md）
const LMI = Object.fromEntries(LANDMARKS.map((l) => [l.id, l]));
function front(lmId, slot = 0, n = 1, out = 3) {
  const l = LMI[lmId];
  const fx = Math.sin(l.yaw), fz = Math.cos(l.yaw), rx = Math.cos(l.yaw), rz = -Math.sin(l.yaw);
  const lat = (slot - (n - 1) / 2) * 3.2;
  return [l.x + fx * (l.d / 2 + out) + rx * lat, l.z + fz * (l.d / 2 + out) + rz * lat, l.yaw];
}
function shopFront(label) {
  const lot = LOTS.find((q) => q.label === label);
  if (!lot) return null;
  const [a, b] = [lot.poly[0], lot.poly[1]];
  const out = inwardNormal(lot.poly, 0);
  const m = [(a[0] + b[0]) / 2 - out[0] * 2.4, (a[1] + b[1]) / 2 - out[1] * 2.4];
  return [m[0], m[1], Math.atan2(-out[0], -out[1])];
}
const SVC = [
  ['mayor', 'cityhall', 0, 3], ['banker', 'exchange', 0, 3], ['banker2', 'exchange', 1, 3], ['clock_keeper', 'exchange', 2, 3],
  ['expo_guide', 'market', 0, 2], ['auctioneer', 'market', 1, 2], ['governor', 'palace', 0, 2], ['butler', 'palace', 1, 2],
  ['lecturer', 'lecture', 0, 1], ['scholar_master', 'scholar', 0, 1], ['archbishop', 'cathedral', 0, 2], ['clergy', 'cathedral', 1, 2],
  ['clergy', 'clergy', 0, 1], ['station_master', 'station', 0, 1], ['guild_master', 'guild', 0, 2], ['guild_reg', 'guild', 1, 2],
  ['t_warrior_3', 'knights', 0, 1], ['t_rogue_3', 'rogue', 0, 1], ['t_gunner_3', 'gunnery', 0, 1], ['t_mage_3', 'mage', 1, 2],
  ['mage_master', 'mage', 0, 2], ['smith_master', 'smith', 0, 1], ['artisan_master', 'artisan', 0, 1], ['cook_master', 'cook', 0, 1],
  ['inn_keeper2', 'inn', 0, 1], ['judge', 'court', 0, 1], ['archivist', 'archive', 0, 1], ['bath_attendant', 'bath', 0, 1],
  ['portal_mage', 'portal', 0, 1], ['librarian', 'library', 0, 2], ['scholar', 'library', 1, 2], ['researcher', 'institute', 0, 1],
  ['merchant_head', 'merchant', 0, 1], ['opera_manager', 'opera', 0, 1], ['doctor', 'hospital', 0, 2], ['nurse', 'hospital', 1, 2],
  ['customs_officer', 'customs', 0, 1], ['ferry_clerk', 'terminal', 0, 1], ['canal_officer', 'canal', 0, 1],
  ['tavern_keeper', 'tavern', 0, 1], ['black_marketeer', 'blackmarket', 0, 1], ['florist', 'greenhouse', 0, 2], ['park_keeper', 'greenhouse', 1, 2],
  ['stable_city', 'stables', 0, 1], ['airship_captain', 'airship', 0, 1], ['astronomer', 'observatory', 0, 1], ['lighthouse_keeper', 'lighthouse', 0, 1],
  ['ambassador', 'embassy', 0, 1], ['guard_city', 'gate_e', 0, 2], ['guard_city', 'gate_e', 1, 2], ['guard_city', 'gate_se', 0, 1],
  ['guard_city', 'gate_n', 0, 1], ['guard_city', 'palace', 0, 1, 44], ['guard_city', 'knights', 0, 1, 8],
];
const SHOPS = [['transmog', '幻化工坊'], ['rare_shop', '珍品阁'], ['potion_shop', '药剂店'], ['item_shop', '道具店'], ['weapon_shop', '武器店'],
  ['armor_shop', '防具店'], ['jeweler', '珠宝店'], ['tax_officer', '税务局'], ['welfare_officer', '社会保障局'], ['warehouse_keeper', '港区货栈'],
  ['finance_minister', '财政大臣官邸'], ['admiral', '海军上将官邸']];
export const NPCS = [];
for (const [id, lm, slot, n, out] of SVC) { const l = LMI[lm]; const inside = l.enter && out === undefined; const p = inside ? hallSpot(l.enter, slot, n) : front(lm, slot, n, out ?? 3); NPCS.push({ id, x: p[0], z: p[1], yaw: p[2], y: null, anchor: lm, inside, slot, n }); }
for (const [id, label] of SHOPS) { const l = LOTS.find((q) => q.label === label); const p = l && l.enter ? hallSpot(l.enter, 0, 1) : shopFront(label); if (p) NPCS.push({ id, x: p[0], z: p[1], yaw: p[2], y: null, anchor: label, inside: !!(l && l.enter), slot: 0, n: 1 }); }
for (const [id, x, z, yaw] of [
  ['harbor_master', -420, 640, Math.PI], ['shipwright', -620, 978, 0], ['merchant_captain', -470, 642, Math.PI], ['dock_worker', -520, 640, 0], ['dock_worker', -630, 760, Math.PI / 2],
  ['sailor', -350, 641, Math.PI], ['sailor', -218, 800, -Math.PI / 2], ['canal_keeper', -110, 205, Math.PI], ['outer_farmer', 345, 500, -Math.PI / 2],
  ['refugee', 330, 462, -Math.PI / 2], ['gate_captain', 284, 446, -Math.PI / 2], ['guard_city_f', -60, 432, -Math.PI / 2],
  ['citizen', -150, 470, 0.5], ['citizen', -90, 395, 2.4], ['citizen', -20, 745, 1], ['citizen', 40, 760, -2], ['citizen', -328, -250, 0],
  ['citizen', -740, -205, Math.PI], ['citizen', 0, -230, 1.5], ['citizen', 230, -320, 0], ['citizen', -480, 360, 0], ['citizen', -810, 560, 0],
]) NPCS.push({ id, x: X(x), z: Z(z), yaw, y: null, anchor: 'street' });

const POI_SPEC = [
  ['poi_solenne', '晴岚港', -330, 200, 900, 1], ['poi_plaza', '市政广场', -120, 430, 60, 10], ['poi_clock', '晴岚钟楼', -70, 390, 22, 9],
  ['poi_spring', '城北河源', 350, 626, 40, 4], ['poi_outer', '城外驿街', 338, 484, 40, 4], ['poi_farmland', '城郊篱田', 380, 540, 50, 3],
  ['poi_canal', '晴岚运河', 0, 185, 80, 6], ['poi_harbor', '晴岚港湾', -410, 660, 90, 7], ['poi_south_port', '南港', -620, 860, 80, 6],
  ['poi_warehouse', '港区货栈', -630, 700, 50, 7], ['poi_park', '海湾公园', 100, 950, 80, 6], ['poi_citygate', '东门', 300, 430, 30, 8],
  ['poi_shop_0', '幻化工坊', null, null, 18, 9], ['poi_shop_1', '珍品阁', null, null, 18, 9], ['poi_shop_2', '药剂店', null, null, 18, 9], ['poi_shop_3', '道具店', null, null, 18, 9],
  ['poi_shop_4', '武器店', null, null, 18, 9], ['poi_shop_5', '防具店', null, null, 18, 9], ['poi_shop_6', '珠宝店', null, null, 18, 9],
  ['poi_tax', '税务局', null, null, 18, 9], ['poi_welfare', '社会保障局', null, null, 18, 9],
  ['poi_royal', '王宫高地', -120, -480, 200, 6], ['poi_lake', '星辉湖', -740, -300, 100, 7],
];
export const POIS = [];
for (const [id, title, x, z, r, pr] of POI_SPEC) {
  let px = x === null ? null : X(x), pz = z === null ? null : Z(z);
  if (px === null) { const f = shopFront(title); if (!f) continue; px = f[0]; pz = f[1]; }
  POIS.push({ id, title, x: px, z: pz, radius: r, priority: pr, xp: true });
}
for (const l of LANDMARKS) if (l.poi && !POIS.some((q) => q.id === l.poi)) POIS.push({ id: l.poi, title: l.name, x: l.x, z: l.z, radius: Math.max(24, Math.max(l.w, l.d) * 0.7), priority: 8, xp: true });
if (LMI.exchange.clock && !POIS.some((q) => q.id === 'poi_clock')) POIS.push({ id: 'poi_clock', title: '晴岚钟楼', x: X(-70), z: Z(390), radius: 22, priority: 9, xp: true });
const sp = (id, lm, out, extra = 0) => { const f = front(lm, 0, 1, out); return { id, x: f[0], z: f[1], yaw: f[2] + extra }; };
export const SPAWNS = [
  sp('fp_solenne', 'airship', 4), { id: 'st_solenne', x: X(-70), z: Z(772), yaw: 0 }, { id: 'gy_gate', x: 324, z: 480, yaw: -Math.PI / 2 },
  sp('gy_cathedral', 'cathedral', 10), sp('city_inn_safe', 'inn', 6),
];

// ---------------------------------------------------------------- 传送石（城内快速移动）
// 每块石头立在地标门前街面偏一侧；y 取所在街区人行道（或台地）高度。
function groundLevel(x, z) {
  const b = blocks.find((q) => pointInPoly([x, z], q.poly));
  if (b) return b.level + CURB;
  const t = terraceAt(x, z);
  return t ? t.level : LV.MID;
}
const WS_SPEC = [
  ['ws_plaza', '市政广场', () => [PLAZA.x + PLAZA.r * 0.72, PLAZA.z + 6]],
  ['ws_market', '万国博览集市', () => front('market', 0, 5, 9)],
  ['ws_palace', '王宫前庭', () => front('palace', 0, 11, 26)],
  ['ws_knights', '骑士团校场', () => front('knights', 0, 5, 10)],
  ['ws_park', '城市公园', () => front('greenhouse', 0, 5, 10)],
  ['ws_oldtown', '旧城广场', () => front('rogue', 0, 5, 9)],
  ['ws_mage', '魔法区 · 星辉湖', () => front('arcane', 0, 5, 10)],
  ['ws_academy', '学院台', () => front('academy', 0, 5, 9)],
  ['ws_airship', '海角飞艇坪', () => front('airship', 0, 5, 6)],
  ['ws_cathedral', '大圣堂广场', () => front('cathedral', 0, 5, 14)],
  ['ws_harbor', '晴岚港湾', () => front('terminal', 0, 5, 8)],
  ['ws_station', '中央车站', () => front('station', 0, 5, 14)],
  ['ws_gate_e', '东门', () => [X(262), Z(452)]],
  ['ws_isle', '海神广场岛', () => [ISL.isl_plaza.xc + 20, ISL.isl_plaza.zc + 12]],
  ['ws_hill', '北苑眺望台', () => front('belvedere', 0, 5, 10)],
];
export const WAYSTONES = WS_SPEC.map(([id, name, f]) => { const p = f(); return { id, name, x: p[0], z: p[1], y: groundLevel(p[0], p[1]) }; });

// ---------------------------------------------------------------- 树木整饬（必须在所有障碍物都生成之后）：删压到实体的树、把穿进立面的树冠压窄、拆掉空树池
export const TREE_FIT = fitTrees({ LOTS, LANDMARKS, HALLS, STAIRS, DECKS, VIADUCT, WAYSTONES, CANALS, FOUNTAINS, BASINS, WALL, FALLS, STRIPS, TREES, PALMS, LAMPS, BLOCKS, terraceAt: (x, z) => terraceAt(x, z) });

// ---------------------------------------------------------------- 查询：某点的人工地基高度
export function terraceAt(x, z) {
  let best = null;
  for (const t of TERRACES) if (pointInPoly([x, z], t.poly)) if (!best || t.level > best.level) best = t;
  return best;
}
export function stats() {
  return { terraces: TERRACES.length, blocks: blocks.length, lots: LOTS.length, landmarks: LANDMARKS.filter((l) => !l.orn).length, stairs: STAIRS.length, decks: DECKS.length,
    trees: TREES.length + PALMS.length, lamps: LAMPS.length, roadClasses: Object.keys(ROAD).length };
}
export const PLAN = { version: 7.1, WAYSTONES, HALLS, CUTS, LV, CURB, ROAD, DISTRICTS, TERRACES, CANALS, BASINS, NPCS, POIS, SPAWNS, TREES, PALMS, LAMPS, BLOCKS, LOTS, LANDMARKS, STAIRS, DECKS, WALL, TRAM, VIADUCT, CABLEWAY, PLAZA, DISTRICT_LABELS, STREET_LABELS };
void len; void dist;
