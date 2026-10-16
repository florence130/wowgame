// 把规划数据建成三维城市
import * as THREE from 'three';
import { MB } from './mb.js';
import * as T from './tex.js';
import { BUILD, COL, bodyWalls, mansard, inflate, gable, outward, ring, column, steps } from './landmarks.js';
import { inset, inwardNormal, centroid, norm, sub, add, mul, dist, pointInPoly, rng, bbox, area } from './geo2d.js';
import { FOUNTAINS, FALLS, KIT_TYPES, WAYSTONES, HALLS, CUTS, X, Z, STRIPS, LV, CURB, SEABED, TERRACES, BLOCKS, LOTS, LANDMARKS, STAIRS, DECKS, WALL, PLAZA, TRAM, VIADUCT, CABLEWAY, CANALS, BASINS, DISTRICTS, terraceAt } from './plan.js';
import { surfacesAt } from './walk.js';
import { kitEligible } from './kitlots.js';

// ---------------------------------------------------------------- 材质
export function makeMaterials() {
  const std = (o) => new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.88, metalness: 0, ...o });
  const M = {};
  M.cobble = std({ map: T.cobble() });
  M.paving = std({ map: T.paving() });
  M.plaza = std({ map: T.plazaTiles() });
  M.quay = std({ map: T.plazaTiles(), color: 0xc8c2b6 });
  M.grass = std({ map: T.grass(), roughness: 1 });
  M.ashlar = std({ map: T.ashlar() });
  M.curb = std({ color: 0xd9d4ca, roughness: 0.7 });
  M.trim = std({});
  for (const k of ['haus', 'brick', 'plaster', 'warehouse', 'academy', 'timber']) {
    const [map, em] = T.facade(k);
    M['fac_' + k] = std({ map, emissiveMap: em, emissive: 0xffc070, emissiveIntensity: 0 });
    M['fac_' + k].userData.night = 1.25;
  }
  for (let i = 0; i < 4; i++) { const [map, em] = T.shopfront(i); M['shop' + i] = std({ map, emissiveMap: em, emissive: 0xffd08a, emissiveIntensity: 0 }); M['shop' + i].userData.night = 1.6; }
  { const [map, em] = T.groundRes(); M.groundres = std({ map, emissiveMap: em, emissive: 0xffc070, emissiveIntensity: 0 }); M.groundres.userData.night = 1.1; }
  for (const k of ['slate', 'tile', 'copper', 'lead', 'violet', 'royal']) M['roof_' + k] = std({ map: T.roof(k), roughness: k === 'copper' ? 0.6 : 0.8 });
  M.balus = std({ map: T.balustrade(false), alphaTest: 0.5, side: THREE.DoubleSide });
  M.iron = std({ map: T.balustrade(true), alphaTest: 0.5, side: THREE.DoubleSide, color: 0xffffff });
  M.awning = std({ map: T.awning(), side: THREE.DoubleSide, roughness: 0.95 });
  M.glass = new THREE.MeshStandardMaterial({ vertexColors: true, color: 0xbfd8e6, transparent: true, opacity: 0.45, roughness: 0.15, metalness: 0.2, side: THREE.DoubleSide, depthWrite: false });
  M.glass.userData.noShadow = true;
  M.glass_lit = std({ color: 0xdfe8ee, roughness: 0.2, emissive: 0xffc77a, emissiveIntensity: 0.05, side: THREE.DoubleSide });
  M.glass_lit.userData.night = 1.4; M.glass_lit.userData.day = 0.05;
  M.glow_lamp = std({ color: 0xfff1cc, emissive: 0xffd18a, emissiveIntensity: 0.3 }); M.glow_lamp.userData.night = 2.5; M.glow_lamp.userData.day = 0.3;
  M.glow_arcane = std({ color: 0xbfe6ff, emissive: 0x66c8ff, emissiveIntensity: 1.2 }); M.glow_arcane.userData.night = 2.6; M.glow_arcane.userData.day = 1.2;
  M.metal = std({ color: 0x2b2e33, roughness: 0.5, metalness: 0.5 });
  M.steel_red = std({ color: 0xa3342a, roughness: 0.55, metalness: 0.3 });
  M.gold = std({ color: 0xd4a548, roughness: 0.35, metalness: 0.8 });
  M.bronze = std({ color: 0xa57a45, roughness: 0.45, metalness: 0.6 });
  M.wood = std({ color: 0xffffff, roughness: 0.9 });
  M.cloth = std({ side: THREE.DoubleSide, roughness: 1 });
  M.clock = std({ color: 0xfaf3e2, emissive: 0xfff0c8, emissiveIntensity: 0 }); M.clock.userData.night = 0.8;
  M.water = new THREE.MeshStandardMaterial({ color: 0x2b7f95, roughness: 0.18, metalness: 0.15, transparent: true, opacity: 0.88 });
  M.water_s = new THREE.MeshStandardMaterial({ color: 0x5aa7b8, roughness: 0.1, metalness: 0.2, transparent: true, opacity: 0.85 });
  M.seabed = new THREE.MeshStandardMaterial({ color: 0x1d4c58, roughness: 1 });
  return M;
}

// ---------------------------------------------------------------- 地基：台面 + 挡土墙 + 护岸
export function levelOutside(x, z, self) {
  let best = null;
  for (const t of TERRACES) if (t !== self && pointInPoly([x, z], t.poly)) if (best === null || t.level > best) best = t.level;
  return best;
}
export function nearConnector(p, r = 2) {
  for (const s of STAIRS) {
    const half = s.width / 2 + r;
    const rel = sub(p, s.bottom), along = rel[0] * s.dir[0] + rel[1] * s.dir[1], lat = Math.abs(rel[0] * -s.dir[1] + rel[1] * s.dir[0]);
    if (along > -r && along < s.run + 4 && lat < half) return true;
  }
  for (const d of DECKS) for (const q of [d.pts[0], d.pts[d.pts.length - 1]]) if (dist(p, [q[0], q[1]]) < d.width / 2 + r) return true;
  return false;
}
export function nearWall(p) {
  const pts = WALL.pts;
  for (let i = 0; i + 1 < pts.length; i++) {
    const a = pts[i], b = pts[i + 1]; if (!a || !b) continue;
    const ab = sub(b, a), t = Math.max(0, Math.min(1, ((p[0] - a[0]) * ab[0] + (p[1] - a[1]) * ab[1]) / (ab[0] ** 2 + ab[1] ** 2)));
    if (dist(p, add(a, mul(ab, t))) < WALL.thickness / 2 + 10) return true;
  }
  return false;
}
function buildTerraces(mb, opts = {}) {
  for (const t of TERRACES) {
    if ((opts.game || opts.noOuter) && t.outer) continue;
    const c = centroid(t.poly);
    mb.world(c[0], c[1]);
    const mat = t.outer ? 'grass' : t.level === LV.QUAY ? 'quay' : 'cobble';
    const tint = t.outer ? [1, 1, 1] : t.level === LV.TOP ? [1.02, 1, 0.97] : t.level === LV.UP ? [0.98, 0.98, 1] : [1, 1, 1];
    mb.cap(mat, t.poly, t.level, tint, mat === 'cobble' ? 4 : 5);
    // 边缘：按 6m 一段判断外侧标高；外侧更低就砌挡土墙（城外地形除外），高差大于 1.5m 加石栏杆
    const n = t.poly.length;
    for (let i = 0; i < n; i++) {
      const a = t.poly[i], b = t.poly[(i + 1) % n], L = dist(a, b);
      const inN = inwardNormal(t.poly, i), out = [-inN[0], -inN[1]];
      const pieces = Math.max(1, Math.ceil(L / 6));
      for (let k = 0; k < pieces; k++) {
        const p0 = add(a, mul(sub(b, a), k / pieces)), p1 = add(a, mul(sub(b, a), (k + 1) / pieces));
        const mid = mul(add(p0, p1), 0.5);
        const ol = levelOutside(mid[0] + out[0] * 1.2, mid[1] + out[1] * 1.2, t);
        const low = ol === null ? (t.floor ?? SEABED) : ol;
        if (low >= t.level - 0.05) continue;
        mb.world(mid[0], mid[1]);
        mb.wall('ashlar', p0, p1, low, t.level, [1, 1, 1], out, [4, 4], k * L / pieces, 0);
        if (t.outer) continue;
        // 压顶石
        const q0 = add(p0, mul(out, 0.35)), q1 = add(p1, mul(out, 0.35));
        mb.wall('trim', q0, q1, t.level - 0.35, t.level + 0.12, COL.trim, out);
        mb.up('trim', [[q0[0], t.level + 0.12, q0[1]], [q1[0], t.level + 0.12, q1[1]], [p1[0] - out[0] * 0.25, t.level + 0.12, p1[1] - out[1] * 0.25], [p0[0] - out[0] * 0.25, t.level + 0.12, p0[1] - out[1] * 0.25]], COL.trim);
        if (t.level - low > 1.5 && !nearConnector(mid) && !nearWall(mid)) {
          const r0 = add(p0, mul(inN, 0.05)), r1 = add(p1, mul(inN, 0.05));
          mb.strip('balus', r0, r1, t.level + 0.12, t.level + 0.12, 1.05, COL.white, 1.05);
          mb.box('trim', (r0[0] + r1[0]) / 2, t.level + 1.1, (r0[1] + r1[1]) / 2, dist(r0, r1) + 0.05, 0.16, 0.4, COL.trim, Math.atan2(-(r1[1] - r0[1]), r1[0] - r0[0]), { uv: [2, 2] });
        }
      }
    }
  }
}

// ---------------------------------------------------------------- 街坊路基：路缘石（行道砖）+ 人行道铺面
function buildBlocks(mb) {
  for (const b of BLOCKS) {
    const c = centroid(b.poly);
    mb.world(c[0], c[1]);
    const y = b.level, top = y + CURB;
    // 路缘石立面
    const n = b.poly.length;
    for (let i = 0; i < n; i++) {
      const inN = inwardNormal(b.poly, i);
      mb.wall('curb', b.poly[i], b.poly[(i + 1) % n], y - 0.05, top, [1, 1, 1], [-inN[0], -inN[1]]);
    }
    // 路缘石顶带 0.3m + 人行道铺面
    const inner = inset(b.poly, 0.3);
    for (let i = 0; i < n; i++) {
      const a = b.poly[i], bb = b.poly[(i + 1) % n], c2 = inner[(i + 1) % n], d2 = inner[i];
      mb.up('curb', [[a[0], top, a[1]], [d2[0], top, d2[1]], [c2[0], top, c2[1]], [bb[0], top, bb[1]]], [0.95, 0.94, 0.92]);
    }
    const surf = b.use === 'square' ? 'plaza' : b.use === 'park' ? 'paving' : 'paving';
    if (b.use === 'park') {
      mb.cap('paving', inner, top, [1, 1, 1], 3);
      const lawn = inset(b.poly, 5);
      if (Math.abs(area(lawn)) > 60) { mb.cap('grass', lawn, top + 0.02, [1, 1, 1], 4); for (let i = 0; i < lawn.length; i++) { const inN = inwardNormal(lawn, i); mb.wall('curb', lawn[i], lawn[(i + 1) % lawn.length], top, top + 0.25, [0.9, 0.9, 0.86], [-inN[0], -inN[1]]); } }
    } else mb.cap(surf, inner, top, DISTRICTS[b.district].pave || [1, 1, 1], surf === 'plaza' ? 6 : 3);
    // 合院内庭（无地标的建筑街坊）：中间一块草坪 + 树
    if (b.use === 'build' && !b.landmarks.length) {
      const yard = inset(b.poly, 24);
      if (yard.length && Math.abs(area(yard)) > 220 && pointInPoly(centroid(yard), b.poly)) mb.cap('grass', yard, top + 0.03, [0.95, 1, 0.92], 4);
    }
  }
}

// 行道树绿化带：草带 + 两侧 0.15m 高花岗岩镶边
function buildStrips(mb) {
  for (const st of STRIPS) {
    const d = norm(sub(st.b, st.a)), n = [-d[1], d[0]], hw = st.w / 2, y = st.level;
    const c = mul(add(st.a, st.b), 0.5);
    mb.world(c[0], c[1]);
    const P = [add(st.a, mul(n, -hw)), add(st.b, mul(n, -hw)), add(st.b, mul(n, hw)), add(st.a, mul(n, hw))];
    mb.up('grass', P.map((p) => [p[0], y + 0.04, p[1]]), [0.95, 1, 0.9], 3);
    for (const sg of [-1, 1]) {
      const e0 = add(st.a, mul(n, sg * hw)), e1 = add(st.b, mul(n, sg * hw));
      const o0 = add(e0, mul(n, sg * 0.12)), o1 = add(e1, mul(n, sg * 0.12));
      mb.up('curb', [[e0[0], y + 0.15, e0[1]], [e1[0], y + 0.15, e1[1]], [o1[0], y + 0.15, o1[1]], [o0[0], y + 0.15, o0[1]]], [0.92, 0.91, 0.88]);
      mb.wall('curb', e0, e1, y, y + 0.15, [0.92, 0.91, 0.88], mul(n, -sg));
      mb.wall('curb', o0, o1, y, y + 0.15, [0.92, 0.91, 0.88], mul(n, sg));
    }
    for (const e of [st.a, st.b]) mb.box('curb', e[0], y, e[1], st.w + 0.24, 0.15, 0.12, [0.92, 0.91, 0.88], Math.atan2(-d[1], d[0]) + Math.PI / 2);
  }
}

// 传送石：三级八角台基 + 四棱石框 + 发光水晶柱 + 悬浮符文环（游戏内由 Waystone 节点自建同款）
const NG = (x, z, r, n = 8, rot = Math.PI / 8) => Array.from({ length: n }, (_, i) => [x + Math.cos(rot + i / n * Math.PI * 2) * r, z + Math.sin(rot + i / n * Math.PI * 2) * r]);
export function buildWaystones(mb) {
  for (const w of WAYSTONES) {
    const { x, z, y } = w;
    mb.world(x, z);
    mb.prism('trim', NG(x, z, 2.6), y - 0.4, y + 0.2, COL.stoneD, { topMat: 'plaza', topScale: 3 });
    mb.prism('trim', NG(x, z, 2.0), y + 0.2, y + 0.45, COL.stone);
    mb.prism('trim', NG(x, z, 1.25), y + 0.45, y + 0.75, COL.trim);
    for (const [sx, sz] of [[1, 1], [-1, 1], [1, -1], [-1, -1]]) mb.box('trim', x + sx * 0.72, y + 0.75, z + sz * 0.72, 0.32, 3.1, 0.32, COL.stone);
    mb.cyl('glow_arcane', x, y + 0.75, z, 0.5, 0.36, 3.0, 6, [1, 1, 1]);
    mb.cyl('glow_arcane', x, y + 3.75, z, 0.36, 0.02, 0.9, 6, [1, 1, 1]);
    mb.box('trim', x, y + 3.85, z, 1.9, 0.22, 1.9, COL.trim);
    ring(mb, x, y + 2.4, z, 1.55, 0.06, 'gold', [1, 1, 1]);
  }
}

// ---------------------------------------------------------------- 室内（白盒）：大厅内墙、地面、天花、门洞隧道、门外平台、柜台、地毯、柱列
export function buildInteriors(mb) {
  for (const h of HALLS) {
    const c = centroid(h.hall);
    mb.world(c[0], c[1]);
    // 内墙三段：深色木护墙板 1.1m + 暖色灰泥墙面 + 顶部 0.45m 檐口色带（室内色调要暖，避免在蓝色环境光下读成天空）
    const n = h.hall.length, wall = [1, 0.9, 0.76], wains = [0.46, 0.31, 0.2], cornice = [0.82, 0.7, 0.54];
    const wy = Math.min(h.floor + 1.1, h.ceil - 1), cy = h.ceil - 0.45;
    for (let i = 0; i < n; i++) {
      const a = h.hall[i], b = h.hall[(i + 1) % n], inN = inwardNormal(h.hall, i);
      mb.wall('wood', a, b, h.floor, wy, wains, inN, [3, 3]);
      mb.wall('trim', a, b, wy, cy, wall, inN, [3, 3]);
      mb.wall('trim', a, b, cy, h.ceil, cornice, inN, [3, 3]);
    }
    mb.cap('plaza', h.hall, h.floor + 0.03, [1, 0.98, 0.94], 4);
    mb.cap('trim', h.hall, h.ceil, [0.93, 0.86, 0.74], 4, true);
    // 矩形大厅：沿短边方向每 3.5m 一根木梁
    const xs0 = h.hallL.map((p) => p[0]), zs0 = h.hallL.map((p) => p[1]);
    const x0 = Math.min(...xs0), x1 = Math.max(...xs0), z0 = Math.min(...zs0), z1 = Math.max(...zs0);
    const isRect = h.hallL.length === 4 && h.hallL.every((p) => (Math.abs(p[0] - x0) < 0.05 || Math.abs(p[0] - x1) < 0.05) && (Math.abs(p[1] - z0) < 0.05 || Math.abs(p[1] - z1) < 0.05));
    if (isRect) {
      const alongX = x1 - x0 < z1 - z0;   // 梁沿短边铺
      const [s0, s1] = alongX ? [z0, z1] : [x0, x1], cnt = Math.floor((s1 - s0) / 3.5);
      for (let k = 1; k < cnt; k++) {
        const s = s0 + (s1 - s0) * k / cnt;
        const L = alongX ? [[x0, s - 0.18], [x1, s - 0.18], [x1, s + 0.18], [x0, s + 0.18]] : [[s - 0.18, z0], [s + 0.18, z0], [s + 0.18, z1], [s - 0.18, z1]];
        mb.prism('wood', L.map(h.toWorld), h.ceil - 0.45, h.ceil - 0.01, [0.42, 0.28, 0.18]);
      }
    }
    // 门洞隧道：两侧墙、顶、地
    const T = h.tunnel, sp = h.sp;
    mb.wall('trim', T[3], T[0], h.floor, h.floor + sp.dh, COL.trim, norm(sub(T[1], T[0])));
    mb.wall('trim', T[1], T[2], h.floor, h.floor + sp.dh, COL.trim, norm(sub(T[0], T[1])));
    mb.up('trim', T.map((p) => [p[0], h.floor + sp.dh, p[1]]), COL.trim, 3, true);
    mb.up('plaza', T.map((p) => [p[0], h.floor + 0.03, p[1]]), [1, 0.98, 0.94], 4);
    if (h.landing) { const L = h.landing; const lc = centroid(L); mb.prism('trim', L, h.level - 0.05, h.floor, COL.stoneD, { topMat: 'plaza', topScale: 4 }); void lc; }
    for (const st of h.ramps) {
      if (!(st.addSteps || (st === h.ramp && sp.addSteps))) continue;
      const dir = st.dir, perp = [-dir[1], dir[0]], cnt = Math.max(2, Math.round((st.y0 - st.y1) / 0.16)), run = Math.hypot(st.b[0] - st.a[0], st.b[1] - st.a[1]) / cnt;
      for (let k = 0; k < cnt; k++) {
        const p0 = add(st.a, mul(dir, k * run)), p1 = add(p0, mul(dir, run)), hy = st.y0 - (st.y0 - st.y1) * k / cnt;
        const P = [add(p0, mul(perp, -st.w / 2)), add(p0, mul(perp, st.w / 2)), add(p1, mul(perp, st.w / 2)), add(p1, mul(perp, -st.w / 2))];
        mb.prism('trim', P, st.y1 - 0.05, hy, COL.stoneD);
      }
    }
    // 柜台、地毯、柱列（局部坐标经 toWorld 换算）
    const W = h.toWorld, zs = h.hallL.map((p) => p[1]), xs = h.hallL.map((p) => p[0]);
    const zin = sp.doorZ - sp.din, zmin = Math.min(...zs), depth = zin - zmin, hwid = (Math.max(...xs) - Math.min(...xs)) / 2;
    const zN = zin - Math.min(depth * 0.55, 10), cz = zN + 1.8, cw = Math.min(hwid * 1.4, 10);
    const C4 = (x0, z0, x1, z1) => [[x0, z0], [x1, z0], [x1, z1], [x0, z1]].map(W);
    mb.prism('wood', C4(-cw / 2, cz - 0.5, cw / 2, cz + 0.5), h.floor, h.floor + 1.1, [0.55, 0.38, 0.24], { topMat: 'wood' });
    mb.up('cloth', C4(-1.6, zN + 3, 1.6, zin - 0.3).map((p) => [p[0], h.floor + 0.05, p[1]]), [0.55, 0.16, 0.18], 3);
    if (hwid > 13 && depth > 16) for (const sx of [-1, 1]) for (let z = zin - 5; z > zmin + 3; z -= 7) { const q = W([sx * (hwid - 4), z]); column(mb, q[0], h.floor, q[1], 0.6, h.ceil - h.floor); }
  }
}

// ---------------------------------------------------------------- 沿街楼房
const STYLE = {
  core: { fac: 'fac_haus', roof: 'mansard', rm: 'roof_slate', gf: 5.2, bal: true, turret: true, tints: [[1, 1, 1], [1, 0.97, 0.92], [0.97, 0.95, 0.92], [1, 0.95, 0.88]] },
  trade: { fac: 'fac_haus', roof: 'mansard', rm: 'roof_slate', gf: 5.2, bal: true, turret: true, tints: [[1, 1, 1], [1, 0.97, 0.9], [0.96, 0.96, 0.98], [1, 0.94, 0.86]] },
  artisan: { fac: 'fac_brick', roof: 'gable', rm: 'roof_slate', gf: 4.4, bal: false, turret: false, tints: [[1, 1, 1], [0.92, 0.88, 0.86], [1, 0.95, 0.9]], chimney: true },
  hero: { fac: 'fac_plaster', roof: 'mansard', rm: 'roof_slate', gf: 4.6, bal: false, turret: true, tints: [[1, 0.88, 0.8], [0.9, 0.95, 0.86], [0.86, 0.92, 1], [1, 0.94, 0.78], [1, 1, 0.97]] },
  academy: { fac: 'fac_academy', roof: 'mansard', rm: 'roof_copper', gf: 4.8, bal: true, turret: false, tints: [[1, 1, 1], [0.96, 0.97, 1]] },
  palace: { fac: 'fac_haus', roof: 'mansard', rm: 'roof_copper', gf: 5.2, bal: true, turret: true, tints: [[1, 1, 1], [1, 0.98, 0.95]] },
  cape: { fac: 'fac_plaster', roof: 'gable', rm: 'roof_slate', gf: 4.2, bal: false, turret: false, tints: [[1, 1, 1], [0.92, 0.96, 1], [1, 0.97, 0.9]] },
  harbor: { fac: 'fac_plaster', roof: 'gable', rm: 'roof_tile', gf: 4.4, bal: false, turret: false, tints: [[1, 0.86, 0.74], [0.82, 0.92, 0.95], [1, 0.95, 0.75], [0.95, 0.85, 0.85], [1, 1, 0.96]], chimney: true },
  royal: { fac: 'fac_academy', roof: 'mansard', rm: 'roof_royal', gf: 5.4, bal: true, turret: true, tints: [[1, 1, 1], [1, 0.99, 0.96]] },
  mage: { fac: 'fac_plaster', roof: 'mansard', rm: 'roof_violet', gf: 4.8, bal: false, turret: true, tints: [[0.88, 0.84, 1], [0.92, 0.88, 1], [0.84, 0.86, 1], [1, 0.95, 1]] },
  oldtown: { fac: 'fac_timber', roof: 'gable', rm: 'roof_tile', gf: 4.2, bal: false, turret: false, tints: [[1, 1, 1], [1, 0.94, 0.86], [0.96, 0.92, 0.9]], chimney: true },
  military: { fac: 'fac_haus', roof: 'gable', rm: 'roof_slate', gf: 4.6, bal: false, turret: false, tints: [[0.78, 0.78, 0.8], [0.72, 0.72, 0.75], [0.8, 0.78, 0.76]] },
  station: { fac: 'fac_brick', roof: 'mansard', rm: 'roof_slate', gf: 5.0, bal: true, turret: true, tints: [[1, 1, 1], [0.95, 0.9, 0.88], [1, 0.97, 0.94]] },
  park: { fac: 'fac_plaster', roof: 'gable', rm: 'roof_tile', gf: 4.4, bal: false, turret: false, tints: [[1, 0.95, 0.85]] },
};
const AWN = [[0.72, 0.18, 0.16], [0.16, 0.36, 0.6], [0.2, 0.46, 0.32], [0.82, 0.6, 0.2], [0.5, 0.24, 0.42]];
function buildLot(mb, lot, blockC) {
  const st = STYLE[lot.style] || STYLE.core;
  const R = rng(lot.seed);
  const P = lot.fe ? [...lot.poly.slice(lot.fe), ...lot.poly.slice(0, lot.fe)] : lot.poly;
  const c = centroid(P);
  mb.world(c[0], c[1]);
  const y0 = lot.level;
  const warehouse = lot.block.startsWith('wq');
  const fac = warehouse ? 'fac_warehouse' : st.fac;
  const tint = st.tints[Math.floor(R() * st.tints.length)];
  const fh = 4.4, gf = Math.max(st.gf, 5.6);
  const mans = st.roof === 'mansard' || P.length !== 4;
  const fl = warehouse ? 3 : lot.floors;
  const wallTop = y0 + gf + Math.max(0, (mans ? fl - 2 : fl - 1)) * fh;
  const ground = lot.shop ? 'shop' + (lot.seed % 4) : st.fac === 'fac_brick' ? 'fac_brick' : 'groundres';
  bodyWalls(mb, P, y0, gf, wallTop, fac, warehouse ? 'fac_warehouse' : ground, tint, [7.2, 8.8]);
  // 腰线、檐口
  mb.prism('trim', inflate(P, 0.22), y0 + gf - 0.12, y0 + gf + 0.22, COL.trim);
  mb.prism('trim', inflate(P, 0.45), wallTop - 0.45, wallTop + 0.15, COL.trim);
  const f0 = P[0], f1 = P[1], fout = outward(P, 0), flen = dist(f0, f1), fdir = norm(sub(f1, f0));
  // 连续阳台（奥斯曼式：三层与顶层）
  if (st.bal && !warehouse && flen > 6) {
    for (const yb of [y0 + gf + fh, wallTop - fh].filter((v, i, a) => v > y0 + gf && a.indexOf(v) === i)) {
      const a = add(f0, mul(fout, 0.9)), b = add(f1, mul(fout, 0.9));
      mb.up('trim', [[f0[0], yb, f0[1]], [f1[0], yb, f1[1]], [b[0], yb, b[1]], [a[0], yb, a[1]]], COL.trim);
      mb.up('trim', [[f0[0], yb - 0.25, f0[1]], [f1[0], yb - 0.25, f1[1]], [b[0], yb - 0.25, b[1]], [a[0], yb - 0.25, a[1]]], COL.trim, 3, true);
      mb.wall('trim', a, b, yb - 0.25, yb, COL.trim, fout);
      mb.strip('iron', a, b, yb, yb, 1.0, [1, 1, 1], 1.0);
    }
  }
  // 屋顶
  let roofTop = wallTop;
  if (mans) {
    const Q = mansard(mb, P, wallTop + 0.15, 4.6, 1.8, st.rm, true);
    roofTop = wallTop + 4.75;
    // 老虎窗
    if (flen > 6) {
      const nd = Math.max(1, Math.floor(flen / 4.2));
      for (let k = 0; k < nd; k++) {
        const t = (k + 0.5) / nd;
        const base = add(f0, mul(fdir, flen * t));
        const p = add(base, mul(fout, -0.55));
        const yaw = Math.atan2(fout[0], fout[1]);
        mb.box('trim', p[0], wallTop + 0.9, p[1], 1.4, 1.9, 1.2, COL.white, yaw);
        const fp = add(p, mul(fout, 0.61));
        const side = mul([fdir[0], fdir[1]], 0.45);
        mb.face('glass_lit', [[fp[0] - side[0], wallTop + 1.1, fp[1] - side[1]], [fp[0] + side[0], wallTop + 1.1, fp[1] + side[1]], [fp[0] + side[0], wallTop + 2.4, fp[1] + side[1]], [fp[0] - side[0], wallTop + 2.4, fp[1] - side[1]]], [0.5, 0.6, 0.7], [fout[0], 0, fout[1]]);
        const s2 = mul([fdir[0], fdir[1]], 0.85);
        mb.face(st.rm, [[p[0] - s2[0] + fout[0] * 0.7, wallTop + 2.8, p[1] - s2[1] + fout[1] * 0.7], [p[0] + fout[0] * 0.7, wallTop + 3.5, p[1] + fout[1] * 0.7], [p[0] - fout[0] * 0.6, wallTop + 3.5, p[1] - fout[1] * 0.6], [p[0] - s2[0] - fout[0] * 0.6, wallTop + 2.8, p[1] - s2[1] - fout[1] * 0.6]], COL.slate, [-fdir[0], 1, -fdir[1]], (q) => [q[0] / 3, q[2] / 3]);
        mb.face(st.rm, [[p[0] + s2[0] + fout[0] * 0.7, wallTop + 2.8, p[1] + s2[1] + fout[1] * 0.7], [p[0] + fout[0] * 0.7, wallTop + 3.5, p[1] + fout[1] * 0.7], [p[0] - fout[0] * 0.6, wallTop + 3.5, p[1] - fout[1] * 0.6], [p[0] + s2[0] - fout[0] * 0.6, wallTop + 2.8, p[1] + s2[1] - fout[1] * 0.6]], COL.slate, [fdir[0], 1, fdir[1]], (q) => [q[0] / 3, q[2] / 3]);
      }
    }
    // 烟囱
    const qc = centroid(Q);
    for (let k = 0; k < 2; k++) { const q = Q[(k * 2) % Q.length]; const p = add(mul(q, 0.7), mul(qc, 0.3)); mb.box('fac_brick', p[0], wallTop + 3.6, p[1], 1, 1.8, 0.7, [0.9, 0.85, 0.8], 0, { uv: [7.2, 7.6] }); }
    // 街角圆塔
    if (lot.corner && st.turret && P.length > 4) {
      let far = P[0], fd = -1;
      for (const q of P) { const d = dist(q, blockC); if (d > fd) { fd = d; far = q; } }
      const tc = add(far, mul(norm(sub(c, far)), 2.4));
      const ty0 = lot.enter ? Math.max(wallTop - fh, lot.enter.ceil) : wallTop - fh;   // 可进入店铺：圆塔从大厅天花以上起
      mb.cyl(fac, tc[0], ty0, tc[1], 3.2, 3.2, wallTop + 3.8 - ty0, 14, tint, { uRep: 3, vScale: 7.6 });
      mb.cyl('trim', tc[0], wallTop + 3.6, tc[1], 3.6, 3.6, 0.5, 14, COL.trim);
      if (R() < 0.5) mb.dome(st.rm === 'roof_copper' ? 'roof_copper' : 'roof_slate', tc[0], wallTop + 4.1, tc[1], 3.6, 4.2, 14, COL.slate);
      else mb.cyl(st.rm, tc[0], wallTop + 4.1, tc[1], 3.7, 0, 6.5, 14, COL.slate);
      mb.cyl('gold', tc[0], wallTop + 10.4, tc[1], 0.1, 0.04, 1.6, 6, COL.gold);
    }
  } else {
    gable(mb, P, wallTop + 0.15, Math.min(7, dist(P[1], P[2]) * 0.42), st.rm, COL.slate, true);
    roofTop = wallTop + 4;
    if (st.chimney) { const p = add(mul(P[2], 0.75), mul(P[1], 0.25)); mb.box('fac_brick', p[0], wallTop, p[1], 1.1, 6, 0.8, [0.9, 0.85, 0.8], 0, { uv: [7.2, 7.6] }); }
  }
  // 商铺遮阳篷
  if (lot.shop && flen > 5) {
    const nb = Math.max(1, Math.floor(flen / 3.6)), col = AWN[lot.seed % AWN.length];
    for (let k = 0; k < nb; k++) {
      const t0 = (k + 0.1) / nb, t1 = (k + 0.9) / nb;
      const a = add(f0, mul(fdir, flen * t0)), b = add(f0, mul(fdir, flen * t1));
      const ao = add(a, mul(fout, 1.7)), bo = add(b, mul(fout, 1.7));
      mb.quad('awning', [a[0], y0 + 4.1, a[1]], [b[0], y0 + 4.1, b[1]], [bo[0], y0 + 3.35, bo[1]], [ao[0], y0 + 3.35, ao[1]], [[0, 0], [flen / nb / 1.2, 0], [flen / nb / 1.2, 1], [0, 1]], col);
      mb.quad('awning', [ao[0], y0 + 3.35, ao[1]], [bo[0], y0 + 3.35, bo[1]], [bo[0], y0 + 3.0, bo[1]], [ao[0], y0 + 3.0, ao[1]], [[0, 0], [flen / nb / 1.2, 0], [flen / nb / 1.2, 0.3], [0, 0.3]], col);
    }
  }
  if (lot.label) {
    const p = add(add(f0, mul(fdir, Math.min(2.5, flen / 2))), mul(fout, 0.2));
    mb.box('metal', p[0] + fout[0] * 0.6, y0 + 4.6, p[1] + fout[1] * 0.6, 0.1, 0.1, 1.4, COL.iron, Math.atan2(fout[0], fout[1]));
    mb.box('wood', p[0] + fout[0] * 1.2, y0 + 3.4, p[1] + fout[1] * 1.2, 0.1, 1.1, 1.0, [0.62, 0.42, 0.22], Math.atan2(fout[0], fout[1]));
    lot.signPos = [p[0] + fout[0] * 1.2, y0 + 5.4, p[1] + fout[1] * 1.2];
  }
  lot.top = roofTop;
}

// ---------------------------------------------------------------- 市政广场：参考图2 的阶梯圆台 + 雕像
function buildPlaza(mb) {
  const { x, z } = PLAZA, y = LV.MID;
  mb.world(x, z);
  mb.cyl('curb', x, y, z, PLAZA.r + 1.5, PLAZA.r + 1.5, 0.05, 48, [1, 1, 1]);
  // 外圈花岗岩环带
  for (let i = 0; i < 48; i++) {
    const a0 = i / 48 * Math.PI * 2, a1 = (i + 1) / 48 * Math.PI * 2;
    const p = (a, r) => [x + Math.cos(a) * r, y + 0.03, z + Math.sin(a) * r];
    mb.up('plaza', [p(a0, PLAZA.r - 6), p(a0, PLAZA.r + 1.5), p(a1, PLAZA.r + 1.5), p(a1, PLAZA.r - 6)], [0.92, 0.9, 0.86], 6);
  }
  const R0 = PLAZA.monument;
  for (let k = 0; k < 6; k++) mb.cyl('trim', x, y, z, R0 - k * 0.45, R0 - k * 0.45, CURB + (k + 1) * 0.16, 64, k % 2 ? [0.92, 0.89, 0.84] : [0.86, 0.83, 0.78], { top: k === 5, topMat: 'plaza' });
  const top = y + CURB + 6 * 0.16;
  // 花坛环 + 柏树（在 build 中由实例树处理）+ 中央台座与雕像
  for (let i = 0; i < 8; i++) {
    const a = i / 8 * Math.PI * 2 + Math.PI / 8;
    const cx = x + Math.cos(a) * 19, cz = z + Math.sin(a) * 19;
    mb.box('trim', cx, top, cz, 6, 0.7, 2.4, COL.trim, -a + Math.PI / 2);
    mb.box('grass', cx, top + 0.7, cz, 5.4, 0.08, 1.8, [0.8, 1, 0.7], -a + Math.PI / 2);
  }
  mb.cyl('trim', x, top, z, 7, 6.6, 1.2, 24, COL.stoneD, { top: true });
  mb.cyl('trim', x, top + 1.2, z, 5, 4.6, 3.5, 24, COL.white, { top: true });
  mb.cyl('trim', x, top + 4.7, z, 5.4, 5.4, 0.5, 24, COL.trim, { top: true });
  // 航海者雕像（青铜）：举望远镜
  const sy = top + 5.2;
  mb.cyl('bronze', x, sy, z, 1.6, 1.1, 5, 10, [1, 1, 1]);
  mb.cyl('bronze', x, sy + 5, z, 1.2, 1.4, 1.6, 10, [1, 1, 1]);
  mb.cyl('bronze', x + 0.9, sy, z + 0.4, 2.3, 0.4, 5.8, 10, [0.9, 0.9, 0.9]);
  mb.dome('bronze', x, sy + 6.6, z, 0.9, 1.2, 10, [1, 1, 1]);
  mb.cyl('bronze', x + 0.6, sy + 6.2, z - 0.4, 0.28, 0.28, 2.4, 8, [1, 1, 1]);
  mb.cyl('gold', x + 0.6, sy + 8.4, z - 0.6, 0.35, 0.25, 1.4, 8, [1, 1, 1]);
  // 四向台阶标识（铜环）
  ring(mb, x, top + 0.05, z, 12, 0.18, 'gold', COL.gold);
}

// 运河水面（驳岸墙由台地边缘自动生成）
function buildCanals(mb) {
  for (const c of CANALS) {
    const ct = c.poly.reduce((s, p) => [s[0] + p[0] / c.poly.length, s[1] + p[1] / c.poly.length], [0, 0]);
    mb.world(ct[0], ct[1]);
    mb.cap('water_s', c.poly, c.water, [0.75, 0.9, 0.95], 6);
  }
}
// 台面上的石砌水池（星辉湖 / 公园湖）：外沿矮墙 + 水面 + 湖心岛
function buildBasin(mb, b) {
  const y = b.level;
  mb.world(b.x, b.z);
  mb.cyl('trim', b.x, y, b.z, b.r + 1.2, b.r + 1.2, 0.9, 64, COL.trim, { top: true });
  mb.cyl('water_s', b.x, y, b.z, b.r, b.r, 0.92, 64, [0.8, 0.9, 1], { top: true });
  if (b.island > 0) {
    mb.cyl('trim', b.x, y, b.z, b.island + 0.6, b.island, 1.4, 40, COL.stoneD, { top: true, topMat: 'plaza' });
    for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; mb.cyl('glow_arcane', b.x + Math.cos(a) * (b.island - 1), y + 1.4, b.z + Math.sin(a) * (b.island - 1), 0.25, 0.25, 1.6, 6, [0.7, 0.85, 1]); }
  }
}
function buildFountain(mb, x, y, z, r) {
  mb.world(x, z);
  mb.cyl('trim', x, y, z, r, r, 0.8, 32, COL.stoneD, { top: false });
  mb.cyl('trim', x, y + 0.8, z, r + 0.3, r + 0.3, 0.25, 32, COL.trim);
  mb.cyl('water_s', x, y, z, r - 0.2, r - 0.2, 0.6, 32, [1, 1, 1], { top: true });
  mb.lathe('trim', x, y, z, [[1.4, 0], [1.0, 1.2], [0.6, 2.4], [2.6, 2.8], [2.6, 3.1], [0.5, 3.3], [0.4, 4.6], [1.2, 5.0], [1.2, 5.2], [0.2, 5.6], [0, 6.2]], 16, COL.white);
  mb.cyl('water_s', x, y + 2.8, z, 2.4, 2.4, 0.3, 16, [1, 1, 1], { top: true });
}

// ---------------------------------------------------------------- 北苑叠水：墙面水帘 + 墙脚水池
function buildFalls(mb) {
  for (const f of FALLS) {
    const hw = f.w / 2, z = f.z;
    mb.world(f.x, z);
    // 墙面水帘：从高台缘压顶外 0.45m 垂到池面，略向外鼓（上窄下宽的两段）
    const top = f.y1 - 0.25, bot = f.y0 + 0.55;
    const sheet = (zz0, y0, zz1, y1) => mb.quad('water_s', [f.x - hw, y0, z + zz0], [f.x + hw, y0, z + zz0], [f.x + hw, y1, z + zz1], [f.x - hw, y1, z + zz1], [[0, 0], [1, 0], [1, 1], [0, 1]], [1, 1, 1]);
    sheet(0.5, top, 0.5, (top + bot) / 2 + 0.6);
    sheet(0.5, (top + bot) / 2 + 0.6, 1.4, bot);
    for (const sg of [-1, 1]) mb.box('trim', f.x + sg * (hw + 0.5), f.y0, z + 0.9, 1.0, f.y1 - f.y0 + 0.5, 1.6, COL.trim);       // 水帘两侧石柱
    // 水池：石沿 + 水面 + 落水处泡沫（白色小方块点缀）
    const z0 = z + 1.0, z1 = z + f.depth;
    const rim = [[f.x - hw - 1.2, z0], [f.x + hw + 1.2, z0], [f.x + hw + 1.2, z1], [f.x - hw - 1.2, z1]];
    mb.prism('trim', rim, f.y0, f.y0 + 0.7, COL.trim);
    const wat = [[f.x - hw, z0 + 0.5], [f.x + hw, z0 + 0.5], [f.x + hw, z1 - 0.9], [f.x - hw, z1 - 0.9]];
    mb.cap('water_s', wat, f.y0 + 0.52, [1, 1, 1], 4);
    for (let i = 0; i < 5; i++) mb.box('trim', f.x - hw + (i + 0.5) * f.w / 5, f.y0 + 0.5, z + 1.9, 2.2, 0.12, 1.1, [1, 1, 1]);
  }
}

// ---------------------------------------------------------------- 楼梯
function buildStairs(mb) {
  for (const s of STAIRS) {
    const d = s.dir, perp = [-d[1], d[0]], hw = s.width / 2;
    const c = add(s.bottom, mul(d, s.run / 2));
    mb.world(c[0], c[1]);
    let along = 0, h = s.h0;
    for (let i = 0; i < s.n; i++) {
      if (i > 0 && i % 14 === 0) along += 2.4;
      const a0 = along, a1 = along + s.tread, ht = s.h0 + s.rise * (i + 1);
      const p = (a, l) => add(add(s.bottom, mul(d, a)), mul(perp, l));
      const q = [p(a0, -hw), p(a0, hw), p(a1, hw), p(a1, -hw)];
      // 踏面 + 踢面
      mb.up('trim', [[q[0][0], ht, q[0][1]], [q[3][0], ht, q[3][1]], [q[2][0], ht, q[2][1]], [q[1][0], ht, q[1][1]]], [0.88, 0.85, 0.79]);
      mb.wall('trim', q[0], q[1], h, ht, [0.8, 0.77, 0.71], [-d[0], -d[1]]);
      h = ht; along = a1;
      if (i % 14 === 13 && i < s.n - 1) {
        const l0 = p(along, -hw), l1 = p(along, hw), l2 = p(along + 2.4, hw), l3 = p(along + 2.4, -hw);
        mb.up('paving', [[l0[0], ht, l0[1]], [l3[0], ht, l3[1]], [l2[0], ht, l2[1]], [l1[0], ht, l1[1]]], [1, 1, 1]);
      }
    }
    // 两侧挡墙（颊墙）+ 栏杆
    for (const sg of [-1, 1]) {
      const b0 = add(s.bottom, mul(perp, sg * (hw + 0.25))), b1 = add(b0, mul(d, s.run));
      const out = mul(perp, sg);
      mb.quad('ashlar', [b0[0], s.h0 - 0.2, b0[1]], [b1[0], s.h0 - 0.2, b1[1]], [b1[0], s.h1 + 0.3, b1[1]], [b0[0], s.h0 + 0.6, b0[1]], [[0, 0], [s.run / 4, 0], [s.run / 4, (s.h1 - s.h0) / 4], [0, 0.2]], [1, 1, 1]);
      mb.quad('ashlar', [b1[0], s.h0 - 0.2, b1[1]], [b0[0], s.h0 - 0.2, b0[1]], [b0[0], s.h0 + 0.6, b0[1]], [b1[0], s.h1 + 0.3, b1[1]], [[0, 0], [s.run / 4, 0], [s.run / 4, 0.2], [0, (s.h1 - s.h0) / 4]], [1, 1, 1]);
      const r0 = add(b0, mul(out, 0.0)), r1 = add(b1, mul(out, 0.0));
      mb.strip('balus', r0, r1, s.h0 + 0.6, s.h1 + 0.3, 1.0, COL.white, 1.0);
      mb.cyl('trim', b0[0], s.h0, b0[1], 0.5, 0.45, 1.8, 8, COL.trim, { top: true });
      mb.cyl('glow_lamp', b0[0], s.h0 + 1.8, b0[1], 0.32, 0.32, 0.6, 8, [1, 0.95, 0.8]);
    }
  }
}

// ---------------------------------------------------------------- 桥与坡道：路面 + 人行道 + 栏杆 + 拱
function buildDecks(mb) {
  for (const d of DECKS) {
    for (let i = 0; i + 1 < d.pts.length; i++) {
      const A = d.pts[i], B = d.pts[i + 1];
      const a = [A[0], A[1]], b = [B[0], B[1]], dir = norm(sub(b, a)), perp = [-dir[1], dir[0]], L = dist(a, b);
      const n = Math.ceil(L / 4), hw = d.width / 2, sw = d.side;
      mb.world((A[0] + B[0]) / 2, (A[1] + B[1]) / 2);
      const pierAt = [];
      for (let k = 0; k < n; k++) {
        const t0 = k / n, t1 = (k + 1) / n;
        const p0 = add(a, mul(sub(b, a), t0)), p1 = add(a, mul(sub(b, a), t1));
        const y0 = A[2] + (B[2] - A[2]) * t0, y1 = A[2] + (B[2] - A[2]) * t1;
        const P = (p, l) => add(p, mul(perp, l));
        // 车行道
        let q = [P(p0, -hw + sw), P(p0, hw - sw), P(p1, hw - sw), P(p1, -hw + sw)];
        mb.up('cobble', [[q[0][0], y0, q[0][1]], [q[3][0], y1, q[3][1]], [q[2][0], y1, q[2][1]], [q[1][0], y0, q[1][1]]], [1, 1, 1], 4);
        for (const sg of [-1, 1]) {
          const i0 = P(p0, sg * (hw - sw)), o0 = P(p0, sg * hw), i1 = P(p1, sg * (hw - sw)), o1 = P(p1, sg * hw);
          const pts = sg > 0 ? [i0, i1, o1, o0] : [o0, o1, i1, i0];
          mb.up('paving', pts.map((p, j) => [p[0], (j === 0 || j === 3 ? y0 : y1) + CURB, p[1]]), [1, 1, 1]);
          mb.quad('curb', [i0[0], y0, i0[1]], [i1[0], y1, i1[1]], [i1[0], y1 + CURB, i1[1]], [i0[0], y0 + CURB, i0[1]], null, [1, 1, 1]);
          mb.quad('curb', [i1[0], y1, i1[1]], [i0[0], y0, i0[1]], [i0[0], y0 + CURB, i0[1]], [i1[0], y1 + CURB, i1[1]], null, [1, 1, 1]);
          // 栏杆
          mb.strip('balus', o0, o1, y0 + CURB, y1 + CURB, 1.05, COL.white, 1.05);
          // 侧墙：离地 < 4.5m 做实心挡墙，否则做拱肩（拱桥）
          const mid = mul(add(o0, o1), 0.5);
          const g = Math.max(...surfacesAt(mid[0] + perp[0] * sg * -1.5, mid[1] + perp[1] * sg * -1.5).filter((h) => h < Math.min(y0, y1) - 0.3), SEABED);
          const yb = Math.min(y0, y1);
          const gap = yb - g;
          let bot0 = y0 - 1.1, bot1 = y1 - 1.1;
          if (gap < 4.5) { bot0 = g; bot1 = g; }
          mb.quad('ashlar', [o0[0], bot0, o0[1]], [o1[0], bot1, o1[1]], [o1[0], y1 + CURB, o1[1]], [o0[0], y0 + CURB, o0[1]], null, [1, 1, 1]);
          mb.quad('ashlar', [o1[0], bot1, o1[1]], [o0[0], bot0, o0[1]], [o0[0], y0 + CURB, o0[1]], [o1[0], y1 + CURB, o1[1]], null, [1, 1, 1]);
          if (sg === 1 && gap >= 4.5) pierAt.push([mid, yb, g, k]);
        }
        // 桥底
        const u = [P(p0, -hw), P(p0, hw), P(p1, hw), P(p1, -hw)];
        mb.up('ashlar', [[u[0][0], y0 - 1.1, u[0][1]], [u[1][0], y0 - 1.1, u[1][1]], [u[2][0], y1 - 1.1, u[2][1]], [u[3][0], y1 - 1.1, u[3][1]]], [0.8, 0.8, 0.8], 4, true);
      }
      // 桥墩：每 4 段一个，只在水中
      for (const [mid, yb, g, k] of pierAt) {
        if (k % 4 !== 2 || g > SEABED + 0.1) continue;
        const pc = add(mid, mul(perp, -hw));
        mb.box('ashlar', pc[0], SEABED, pc[1], 3, yb - SEABED - 1.1, d.width + 1, [1, 1, 1], Math.atan2(-dir[1], dir[0]) + Math.PI / 2, { uv: [4, 4] });
      }
    }
  }
}

// ---------------------------------------------------------------- 城墙与塔
function buildWalls(mb) {
  const pts = WALL.pts, t = WALL.thickness;
  // 墙端角楼（北墙为北苑叠园让开的缺口两端）
  for (const [x, z] of WALL.towers || []) {
    const ins = terraceAt(x, z + 12), li = ins ? ins.level : LV.TOP;
    mb.world(x, z);
    mb.cyl('ashlar', x, li - 2, z, 8.5, 8, WALL.height + 14, 18, [1, 1, 1], { uRep: 9, vScale: 4 });
    mb.cyl('trim', x, li + WALL.height + 11, z, 9.2, 9.2, 1.0, 18, COL.trim, { top: true });
    mb.cyl('roof_slate', x, li + WALL.height + 12, z, 9.4, 0, 11, 18, COL.slate);
    mb.cyl('gold', x, li + WALL.height + 22.6, z, 0.22, 0.05, 2.4, 6, COL.gold);
  }
  for (let i = 0; i + 1 < pts.length; i++) {
    const a = pts[i], b = pts[i + 1];
    if (!a || !b) continue;
    const L = dist(a, b), dir = norm(sub(b, a)), nrm = [-dir[1], dir[0]];
    const n = Math.ceil(L / 12);
    for (let k = 0; k < n; k++) {
      const p0 = add(a, mul(sub(b, a), k / n)), p1 = add(a, mul(sub(b, a), (k + 1) / n)), mid = mul(add(p0, p1), 0.5);
      const ins = terraceAt(mid[0] + nrm[0] * 12, mid[1] + nrm[1] * 12), outs = terraceAt(mid[0] - nrm[0] * 12, mid[1] - nrm[1] * 12);
      const li = ins ? ins.level : LV.MID, lo = outs ? outs.level : SEABED;
      const base = Math.min(li, lo) - 1, top = Math.max(li, lo) + WALL.height;
      mb.world(mid[0], mid[1]);
      const yaw = Math.atan2(-dir[1], dir[0]);
      mb.box('ashlar', mid[0], base, mid[1], dist(p0, p1) + 0.05, top - base, t, [1, 1, 1], yaw, { uv: [4, 4] });
      for (let m = 0; m < 4; m++) {
        const q = add(p0, mul(sub(p1, p0), (m + 0.5) / 4));
        for (const sg of [-1, 1]) mb.box('ashlar', q[0] + nrm[0] * sg * (t / 2 - 0.4), top, q[1] + nrm[1] * sg * (t / 2 - 0.4), 1.6, 1.4, 0.8, [1, 1, 1], yaw);
      }
    }
    // 塔
    const nt = Math.floor(L / 120);
    for (let k = 1; k <= nt; k++) {
      const p = add(a, mul(sub(b, a), k / (nt + 1)));
      const ins = terraceAt(p[0] + nrm[0] * 12, p[1] + nrm[1] * 12), li = ins ? ins.level : LV.MID;
      mb.world(p[0], p[1]);
      mb.cyl('ashlar', p[0], li - 2, p[1], 7, 6.5, WALL.height + 8, 16, [1, 1, 1], { uRep: 8, vScale: 4 });
      mb.cyl('trim', p[0], li + WALL.height + 6, p[1], 7.3, 7.3, 0.8, 16, COL.trim, { top: true });
      mb.cyl('roof_slate', p[0], li + WALL.height + 6.8, p[1], 7.4, 0, 8, 16, COL.slate);
    }
  }
}

// ---------------------------------------------------------------- 电车轨道 / 高架 / 缆车塔
export function tramPath() {
  const out = [];
  const push = (x, z) => { const s = surfacesAt(x, z).filter((h) => h < 40); out.push([x, (s.length ? Math.max(...s.filter((h) => h <= (out.length ? out[out.length - 1][1] + 1 : 99))) : LV.MID), z]); };
  const seg = (a, b, step = 4) => { const L = dist(a, b), n = Math.ceil(L / step); for (let i = 0; i < n; i++) { const p = add(a, mul(sub(b, a), i / n)); push(p[0], p[1]); } };
  const R = PLAZA.r - 12;
  seg([290, 430], [PLAZA.x + R, PLAZA.z]);
  for (let i = 0; i <= 36; i++) { const a = -(i / 36) * Math.PI * 1.5; push(PLAZA.x + Math.cos(a) * R, PLAZA.z + Math.sin(a) * R); }
  seg([PLAZA.x, PLAZA.z + R], [PLAZA.x, Z(552)]);
  seg([PLAZA.x, Z(552)], [PLAZA.x, Z(704)], 3);
  seg([PLAZA.x, Z(704)], [PLAZA.x, Z(745)]);
  seg([PLAZA.x, Z(745)], [X(60), Z(745)]);
  seg([X(60), Z(745)], [X(60), Z(700)]);
  seg([X(60), Z(700)], [290, Z(700)]);
  push(290, Z(700));
  // 修正高度：桥上取桥面
  for (const p of out) { const s = surfacesAt(p[0], p[2]); const deck = s.filter((h) => Math.abs(h - p[1]) < 1.2); if (deck.length) p[1] = Math.max(...deck); }
  return out;
}
function buildRails(mb, path) {
  for (let i = 0; i + 1 < path.length; i++) {
    const A = path[i], B = path[i + 1];
    const dir = norm([B[0] - A[0], B[2] - A[2]]), perp = [-dir[1], dir[0]];
    mb.world(A[0], A[2]);
    for (const off of [-0.72, 0.72]) {
      const a = [A[0] + perp[0] * off, A[2] + perp[1] * off], b = [B[0] + perp[0] * off, B[2] + perp[1] * off];
      const w = mul(perp, 0.07);
      mb.up('metal', [[a[0] - w[0], A[1] + 0.025, a[1] - w[1]], [a[0] + w[0], A[1] + 0.025, a[1] + w[1]], [b[0] + w[0], B[1] + 0.025, b[1] + w[1]], [b[0] - w[0], B[1] + 0.025, b[1] - w[1]]], [0.6, 0.6, 0.62]);
    }
    // 架空接触线
    if (i % 8 === 0) {
      const p = [A[0] + perp[0] * 4, A[2] + perp[1] * 4];
      mb.cyl('metal', p[0], A[1], p[1], 0.12, 0.1, 6.4, 6, COL.iron);
    }
  }
}
function buildViaduct(mb) {
  const P = VIADUCT.pts, h = LV.LOW + VIADUCT.h;
  for (let i = 0; i + 1 < P.length; i++) {
    const a = P[i], b = P[i + 1], L = dist(a, b), dir = norm(sub(b, a)), perp = [-dir[1], dir[0]], yaw = Math.atan2(-dir[1], dir[0]);
    const mid = mul(add(a, b), 0.5);
    mb.world(mid[0], mid[1]);
    mb.box('trim', mid[0], h - 1.2, mid[1], L + 0.2, 1.2, 9, [0.75, 0.72, 0.68], yaw);
    for (const sg of [-1, 1]) {
      const o = mul(perp, sg * 4.2);
      // 参考图1：红色钢桁拱梁
      const n = Math.ceil(L / 3);
      for (let k = 0; k < n; k++) {
        const t0 = k / n, t1 = (k + 1) / n;
        const yy = (t) => h + 0.2 + Math.sin(Math.PI * ((t * L) % 24) / 24) * 0.0 + 1.6;
        const p0 = add(add(a, mul(sub(b, a), t0)), o), p1 = add(add(a, mul(sub(b, a), t1)), o);
        mb.strip('steel_red', p0, p1, h, h, 1.4, [1, 1, 1], 2);
        void yy;
      }
    }
    for (let t = 8; t < L; t += 22) {
      const p = add(a, mul(dir, t));
      const g = terraceAt(p[0], p[1]);
      const base = g ? g.level : SEABED;
      mb.box('ashlar', p[0], base, p[1], 3, h - 1.2 - base, 7, [1, 1, 1], yaw, { uv: [4, 4] });
    }
  }
}
function buildCableway(mb) {
  const [A, B] = CABLEWAY.pts;
  for (const P of [A, B]) {
    const g = terraceAt(P[0], P[1]);
    const base = g ? g.level : LV.LOW;
    mb.world(P[0], P[1]);
    mb.box('steel_red', P[0], base, P[1], 1.6, P[2] - base, 1.6, [1, 1, 1]);
    mb.box('steel_red', P[0], P[2], P[1], 7, 1, 2, [1, 1, 1]);
    mb.box('trim', P[0], base, P[1], 8, 4, 8, COL.white);
    mb.box('roof_slate', P[0], base + 4, P[1], 9, 0.5, 9, COL.slate);
  }
  for (const off of [-2.6, 2.6]) {
    const dir = norm(sub([B[0], B[1]], [A[0], A[1]])), perp = [-dir[1], dir[0]];
    const a = [A[0] + perp[0] * off, A[1] + perp[1] * off], b = [B[0] + perp[0] * off, B[1] + perp[1] * off];
    const n = 40;
    for (let i = 0; i < n; i++) {
      const t0 = i / n, t1 = (i + 1) / n;
      const sag = (t) => -Math.sin(Math.PI * t) * 6;
      const p0 = add(a, mul(sub(b, a), t0)), p1 = add(a, mul(sub(b, a), t1));
      mb.world(p0[0], p0[1]);
      mb.strip('metal', p0, p1, A[2] + (B[2] - A[2]) * t0 + sag(t0), A[2] + (B[2] - A[2]) * t1 + sag(t1), 0.08, [1, 1, 1], 1);
    }
  }
}

// ---------------------------------------------------------------- 总装
// 只生成几何（node 导出游戏资源时也用这一份），opts.game=true 时不画海面/海床与电车轨
export function buildGeometry(mb, opts = {}) {
  mb.cuts = CUTS;
  buildTerraces(mb, opts);
  buildBlocks(mb);
  buildStrips(mb);
  const blockC = Object.fromEntries(BLOCKS.map((b) => [b.id, centroid(b.poly)]));
  for (const lot of LOTS) {
    // 游戏导出：模块化沿街楼（street_kit，CityKitLots 合批）近处替代这些白模；白模只作远景代理（内缩 0.45m，避免与构件共面）
    if (opts.game && opts.kitLots && kitEligible(lot)) {
      mb.pfx = 'LF:';
      buildLot(mb, { ...lot, poly: inset(lot.poly, 0.45) }, blockC[lot.block]);
      mb.pfx = '';
    } else buildLot(mb, lot, blockC[lot.block]);
  }
  for (const lm of LANDMARKS) {
    if (lm.level == null) {
      const inside = add([lm.x, lm.z], mul([Math.sin(lm.yaw), Math.cos(lm.yaw)], -(lm.d / 2 + 6)));
      const t = terraceAt(inside[0], inside[1]) || terraceAt(lm.x, lm.z);
      lm.level = t ? t.level : LV.MID;
      if (lm.type === 'gatebridge') lm.level = LV.MID;
    }
    // 游戏导出：模块化拼装的地标外观由 Blender 生成（assets/models/city_lm），这里只留室内（buildInteriors）与碰撞
    if (opts.game && opts.kitLandmarks && KIT_TYPES.has(lm.type) && !lm.orn) continue;
    const fn = BUILD[lm.type] || BUILD.civic;
    mb.at(lm.x, lm.level, lm.z, lm.yaw);
    fn(mb, lm);
  }
  mb.world();
  buildCanals(mb);
  for (const bs of BASINS) buildBasin(mb, bs);
  buildPlaza(mb);
  for (const f of FOUNTAINS) buildFountain(mb, f.x, f.y, f.z, f.r);
  buildFalls(mb);
  buildInteriors(mb);
  if (!opts.game) buildWaystones(mb);
  buildStairs(mb);
  buildDecks(mb);
  buildWalls(mb);
  const tram = tramPath();
  if (!opts.game) buildRails(mb, tram);
  buildViaduct(mb);
  if (!opts.game) buildCableway(mb);
  return tram;
}
export function buildCity(scene, M) {
  const mb = new MB();
  const root = new THREE.Group();
  scene.add(root);
  const water = new THREE.Mesh(new THREE.PlaneGeometry(9000, 9000), M.water);
  water.rotation.x = -Math.PI / 2; water.position.y = 0; water.receiveShadow = true; root.add(water);
  const bed = new THREE.Mesh(new THREE.PlaneGeometry(9000, 9000), M.seabed);
  bed.rotation.x = -Math.PI / 2; bed.position.y = SEABED + 0.5; root.add(bed);
  const tram = buildGeometry(mb, { noOuter: true });
  const meshes = mb.build(M, root);
  return { root, meshes, tram };
}
void bbox; void rng;
