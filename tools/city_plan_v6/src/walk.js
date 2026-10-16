// 步行用的地面与碰撞：解析式（不依赖网格射线），与规划数据一一对应。
import { pointInPoly, bbox, segDist, dot, sub, norm, dist } from './geo2d.js';
import { HALLS, WAYSTONES, CITY_RECT, TERRACES, BLOCKS, LOTS, LANDMARKS, STAIRS, DECKS, WALL, CURB, PLAZA, LV, BASINS } from './plan.js';

const CELL = 40;
const grid = new Map();
const key = (i, j) => i * 10007 + j;
function addToGrid(item, bb) {
  for (let i = Math.floor(bb[0] / CELL); i <= Math.floor(bb[2] / CELL); i++)
    for (let j = Math.floor(bb[1] / CELL); j <= Math.floor(bb[3] / CELL); j++) {
      const k = key(i, j); if (!grid.has(k)) grid.set(k, []); grid.get(k).push(item);
    }
}
for (const b of BLOCKS) addToGrid({ t: 'block', poly: b.poly, h: b.level + CURB, ref: b }, bbox(b.poly));
const SOLID_LM = new Set(['gatebridge', 'airship', 'gate']);
// 可进入建筑：实体多边形挖去「大厅 + 门洞隧道 + 门外平台」
const holesOf = (h) => [h.hall, h.tunnel, ...(h.landing ? [h.landing] : [])];
for (const l of LOTS) addToGrid({ t: 'solid', poly: l.poly, base: l.level, holes: l.enter ? holesOf(l.enter) : null }, bbox(l.poly));
for (const h of HALLS) {
  addToGrid({ t: 'floor', h }, bbox([...h.hall, ...h.tunnel, ...(h.landing || []), ...h.ramps.flatMap((r) => [r.a, r.b]), ...(h.podium ? h.podium.poly : [])]));
  for (const P of h.inner) addToGrid({ t: 'solid', poly: P, base: h.floor }, bbox(P));
}
for (const w of WAYSTONES || []) { const poly = [[w.x - 1.6, w.z - 1.6], [w.x + 1.6, w.z - 1.6], [w.x + 1.6, w.z + 1.6], [w.x - 1.6, w.z + 1.6]]; addToGrid({ t: 'solid', poly, base: w.y }, bbox(poly)); }
for (const lm of LANDMARKS) {
  if (lm.type === 'triumph') {
    for (const sgn of [-1, 1]) { const cx = lm.x + sgn * (8 + (lm.w - 16) / 4); const poly = [[cx - 6, lm.z - 7], [cx + 6, lm.z - 7], [cx + 6, lm.z + 7], [cx - 6, lm.z + 7]]; addToGrid({ t: 'solid', poly, base: LV.MID }, bbox(poly)); }
    continue;
  }
  if (lm.type === 'gatebridge') {
    // 只有两座桥塔是实体，桥洞可通行
    const c = Math.cos(lm.yaw), s = Math.sin(lm.yaw);
    for (const sgn of [-1, 1]) {
      const cx = lm.x + c * sgn * (lm.w / 2 - 6), cz = lm.z - s * sgn * (lm.w / 2 - 6);
      const poly = [[cx - 6, cz - 7], [cx + 6, cz - 7], [cx + 6, cz + 7], [cx - 6, cz + 7]];
      addToGrid({ t: 'solid', poly, base: LV.MID }, bbox(poly));
    }
    continue;
  }
  if (lm.type === 'gate' || lm.type === 'airship') continue;
  if (lm.enter) {
    const h = lm.enter;
    for (const P of (h.solids.length ? h.solids : [lm.footprint])) addToGrid({ t: 'solid', poly: P, base: lm.level ?? 0, holes: holesOf(h) }, bbox(P));
    continue;
  }
  const poly = lm.footprint;
  addToGrid({ t: 'solid', poly, base: lm.level ?? 0, lm: lm.id }, bbox(poly));
}
// 城墙
{
  const pts = WALL.pts;
  for (let i = 0; i + 1 < pts.length; i++) {
    const a = pts[i], b = pts[i + 1];
    if (!a || !b) continue;
    const d = norm(sub(b, a)), n = [-d[1], d[0]], t = WALL.thickness / 2;
    const poly = [[a[0] + n[0] * t, a[1] + n[1] * t], [b[0] + n[0] * t, b[1] + n[1] * t], [b[0] - n[0] * t, b[1] - n[1] * t], [a[0] - n[0] * t, a[1] - n[1] * t]];
    addToGrid({ t: 'solid', poly, base: -99 }, bbox(poly));
  }
}
function near(x, z) { return grid.get(key(Math.floor(x / CELL), Math.floor(z / CELL))) || []; }

// 某点所有可站立面的高度
let terrainFn = null;
export function setTerrain(fn) { terrainFn = fn; }
export function surfacesAt(x, z) {
  const out = [];
  let wet = false;
  for (const b of BASINS) { const r = Math.hypot(x - b.x, z - b.z); if (r < b.r + 1.2) { if (r < b.island) out.push(b.level + 1.4); else wet = true; } }
  if (!wet) for (const t of TERRACES) if (!(terrainFn && t.outer) && pointInPoly([x, z], t.poly)) out.push(t.level);
  if (terrainFn && (x > CITY_RECT.x1 || z < CITY_RECT.z0 || x < CITY_RECT.x0 || z > CITY_RECT.z1 + 60)) { const h = terrainFn(x, z); if (h > 0.3) out.push(h); }
  if (!wet) for (const it of near(x, z)) {
    if (it.t === 'block' && pointInPoly([x, z], it.poly)) out.push(it.h);
    else if (it.t === 'floor') {
      const h = it.h;
      if (pointInPoly([x, z], h.hall) || pointInPoly([x, z], h.tunnel) || (h.landing && pointInPoly([x, z], h.landing))) out.push(h.floor);
      if (h.podium && pointInPoly([x, z], h.podium.poly)) out.push(h.podium.y);
      for (const r of h.ramps) {
        const rel = sub([x, z], r.a), along = dot(rel, r.dir), lat = Math.abs(rel[0] * -r.dir[1] + rel[1] * r.dir[0]), L = dist(r.a, r.b);
        if (along >= -0.3 && along <= L + 0.3 && lat <= r.w / 2) out.push(r.y0 + (r.y1 - r.y0) * Math.max(0, Math.min(1, along / L)));
      }
    }
  }
  // 广场中央纪念台：阶梯式圆台
  const r = Math.hypot(x - PLAZA.x, z - PLAZA.z);
  if (r < PLAZA.monument) out.push(LV.MID + CURB + Math.min(1.1, (PLAZA.monument - r) * 0.45));
  for (const s of STAIRS) {
    const rel = sub([x, z], s.bottom), along = dot(rel, s.dir), lat = Math.abs(rel[0] * -s.dir[1] + rel[1] * s.dir[0]);
    if (along >= -0.2 && along <= s.run + 0.2 && lat <= s.width / 2) out.push(s.h0 + (s.h1 - s.h0) * Math.max(0, Math.min(1, along / s.run)));
  }
  for (const d of DECKS) {
    for (let i = 0; i + 1 < d.pts.length; i++) {
      const a = d.pts[i], b = d.pts[i + 1];
      const [dd, t] = segDist([x, z], [a[0], a[1]], [b[0], b[1]]);
      if (dd <= d.width / 2) out.push(a[2] + (b[2] - a[2]) * t + (dd > d.width / 2 - d.side ? CURB : 0));
    }
  }
  return out;
}
// 当前高度 y 附近可走上去的地面（允许 0.6m 台阶，脚下更高的桥面不算）
export function groundAt(x, z, y = Infinity) {
  let best = null;
  for (const h of surfacesAt(x, z)) if (h <= y + 0.6 && (best === null || h > best)) best = h;
  return best;
}
export function blocked(x, z, y, r = 0.35) {
  for (const it of near(x, z)) {
    if (it.t !== 'solid') continue;
    if (y < it.base - 2) continue;
    for (const [ox, oz] of [[0, 0], [r, 0], [-r, 0], [0, r], [0, -r]]) {
      const q = [x + ox, z + oz];
      if (pointInPoly(q, it.poly) && !(it.holes && it.holes.some((H) => pointInPoly(q, H)))) return true;
    }
  }
  if (Math.hypot(x - PLAZA.x, z - PLAZA.z) < 6.5) return true;   // 雕像基座
  return false;
}
// 调试：列出某点的阻挡来源
export function blockers(x, z, y) {
  return near(x, z).filter((it) => it.t === 'solid' && y >= it.base - 2 && pointInPoly([x, z], it.poly) && !(it.holes && it.holes.some((H) => pointInPoly([x, z], H))));
}
// 尝试移动：返回新的 [x, z, y]，不能走（水面、落差、墙体）则沿轴滑动
export function step(x, z, y, dx, dz) {
  const tryMove = (nx, nz) => {
    const g = groundAt(nx, nz, y);
    if (g === null || g < y - 0.75) return null;
    if (blocked(nx, nz, g)) return null;
    return [nx, nz, g];
  };
  return tryMove(x + dx, z + dz) || tryMove(x + dx, z) || tryMove(x, z + dz) || [x, z, y];
}
export function nearestDistrict(x, z) {
  let best = null, bd = Infinity;
  for (const b of BLOCKS) {
    const c = b.poly[0];
    const d = dist([x, z], c);
    if (d < bd) { bd = d; best = b; }
  }
  return best;
}
