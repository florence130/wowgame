// 游戏碰撞几何（与视觉网格分开、尽量简单）：可走面朝上；栏杆、护墙双面；台阶做成斜坡；路缘石做成 0.6m 缓坡。
import { inset, inwardNormal, dist, add, sub, mul, norm, centroid, pointInPoly } from './geo2d.js';
import { HALLS, CUTS, LV, CURB, SEABED, TERRACES, BLOCKS, LOTS, LANDMARKS, STAIRS, DECKS, WALL, PLAZA, BASINS, VIADUCT, terraceAt } from './plan.js';
import { nearConnector, nearWall, levelOutside } from './build.js';

const M = 'col';
function barrier(mb, a, b, y0a, y0b, h) { mb.strip(M, a, b, y0a, y0b, h, [1, 1, 1], 1, true); }
function prismWalls(mb, P, y0, y1, top = true) {
  for (let i = 0; i < P.length; i++) {
    const inN = inwardNormal(P, i);
    mb.wall(M, P[i], P[(i + 1) % P.length], y0, y1, [1, 1, 1], [-inN[0], -inN[1]]);
  }
  if (top) mb.cap(M, P, y1, [1, 1, 1]);
}
const circle = (x, z, r, n = 20) => Array.from({ length: n }, (_, i) => [x + Math.cos(i / n * Math.PI * 2) * r, z + Math.sin(i / n * Math.PI * 2) * r]);

// 双面墙（两侧都挡；门洞切割照常生效）
function twoWay(mb, a, b, y0, y1) { const d = norm(sub(b, a)); mb.wall(M, a, b, y0, y1, [1, 1, 1], [-d[1], d[0]]); mb.wall(M, a, b, y0, y1, [1, 1, 1], [d[1], -d[0]]); }
// 可进入建筑：外墙（门洞切开）+ 大厅内墙 + 大厅 / 门洞 / 门外平台地面 + 门前坡道（代替台阶）
function enterable(mb, h, outer, hTop) {
  const y0 = h.level - 0.2;
  if (h.podium) mb.cap(M, h.podium.poly, h.podium.y, [1, 1, 1]);
  for (const P of outer) prismWalls(mb, P, y0, hTop);
  for (const P of h.inner) prismWalls(mb, P, h.floor - 0.1, h.ceil);
  for (let i = 0; i < h.hall.length; i++) twoWay(mb, h.hall[i], h.hall[(i + 1) % h.hall.length], h.floor - 0.1, h.ceil);
  mb.cap(M, h.hall, h.floor, [1, 1, 1]);
  mb.up(M, h.tunnel.map((p) => [p[0], h.floor, p[1]]), [1, 1, 1]);
  const T = h.tunnel;
  twoWay(mb, T[0], T[3], h.floor, h.floor + h.sp.dh); twoWay(mb, T[1], T[2], h.floor, h.floor + h.sp.dh);
  if (h.landing) mb.up(M, h.landing.map((p) => [p[0], h.floor, p[1]]), [1, 1, 1]);
  for (const r of h.ramps) { const perp = [-r.dir[1], r.dir[0]];
  if (Math.abs(r.y0 - r.y1) > 0.05) mb.up(M, [[...add(r.a, mul(perp, -r.w / 2)), r.y0], [...add(r.a, mul(perp, r.w / 2)), r.y0], [...add(r.b, mul(perp, r.w / 2)), r.y1], [...add(r.b, mul(perp, -r.w / 2)), r.y1]].map((q) => [q[0], q[2], q[1]]), [1, 1, 1]); }
}

export function buildCollision(mb) {
  mb.cuts = CUTS;
  // 台地面 + 边墙（落差 > 1.5m 且不是阶梯 / 桥头处加 1.1m 护栏）
  for (const t of TERRACES) {
    if (t.outer) continue;
    const c = centroid(t.poly);
    mb.world(c[0], c[1]);
    mb.cap(M, t.poly, t.level, [1, 1, 1]);
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
        mb.wall(M, p0, p1, low, t.level, [1, 1, 1], out);
        if (t.level - low > 1.5 && !nearConnector(mid) && !nearWall(mid)) barrier(mb, p0, p1, t.level, t.level, 1.15);
      }
    }
  }
  // 街坊路基：顶面 + 0.6m 缓坡路缘
  for (const b of BLOCKS) {
    const c = centroid(b.poly);
    mb.world(c[0], c[1]);
    const inner = inset(b.poly, 0.6), y = b.level, top = y + CURB;
    for (let i = 0; i < b.poly.length; i++) {
      const j = (i + 1) % b.poly.length;
      mb.up(M, [[b.poly[i][0], y + 0.01, b.poly[i][1]], [b.poly[j][0], y + 0.01, b.poly[j][1]], [inner[j][0], top, inner[j][1]], [inner[i][0], top, inner[i][1]]], [1, 1, 1]);
    }
    mb.cap(M, inner, top, [1, 1, 1]);
  }
  // 沿街楼：外墙 + 屋面
  for (const l of LOTS) {
    const c = centroid(l.poly);
    mb.world(c[0], c[1]);
    prismWalls(mb, l.poly, l.level - 0.2, (l.top || l.level + 16) - 1.5);
    if (l.enter) { for (let i = 0; i < l.enter.hall.length; i++) twoWay(mb, l.enter.hall[i], l.enter.hall[(i + 1) % l.enter.hall.length], l.level - 0.1, l.enter.ceil); mb.cap(M, l.enter.hall, l.level + 0.02, [1, 1, 1]); }
  }
  // 地标：占地外墙（少数类型特殊处理）
  for (const lm of LANDMARKS) {
    mb.world(lm.x, lm.z);
    const y0 = (lm.level ?? LV.MID) - 0.2;
    const c = Math.cos(lm.yaw), s = Math.sin(lm.yaw);
    const local = (u, v) => [lm.x + c * u + s * v, lm.z - s * u + c * v];
    if (lm.enter) { enterable(mb, lm.enter, lm.enter.solids.length ? lm.enter.solids : [lm.footprint], y0 + Math.min(lm.h, 40)); if (lm.type === 'station') prismWalls(mb, [local(-lm.w * 0.42, -lm.d / 2), local(lm.w * 0.42, -lm.d / 2), local(lm.w * 0.42, -lm.d / 2 - 66), local(-lm.w * 0.42, -lm.d / 2 - 66)], y0, y0 + 14); continue; }
    if (lm.type === 'obelisk') { prismWalls(mb, circle(lm.x, lm.z, 3, 8), y0, y0 + lm.h); continue; }
    if (lm.type === 'gatebridge' || lm.type === 'gate' || lm.type === 'triumph') {
      const off = lm.type === 'gate' ? 15 : lm.type === 'triumph' ? 8 + (lm.w - 16) / 4 : lm.w / 2 - 6, r = lm.type === 'gate' ? 7 : lm.type === 'triumph' ? 6.5 : 6;
      for (const sg of [-1, 1]) { const p = local(sg * off, 0); prismWalls(mb, circle(p[0], p[1], r, 12), y0 - 6, y0 + 30); }
      continue;
    }
    if (lm.type === 'airship') { prismWalls(mb, circle(lm.x, lm.z, 20, 24), y0, y0 + 2.4); continue; }
    if (lm.type === 'magetower') { prismWalls(mb, circle(lm.x, lm.z, 9.5, 16), y0, y0 + 60); continue; }
    if (lm.type === 'lighthouse') { prismWalls(mb, circle(lm.x, lm.z, 8, 16), y0, y0 + 36); continue; }
    if (lm.type === 'portal') { prismWalls(mb, circle(lm.x, lm.z, lm.w / 2 + 1, 20), y0, y0 + 16); continue; }
    if (lm.type === 'shipyard') { for (const sg of [-1, 1]) prismWalls(mb, [local(sg * 15 - 0.6, -lm.d / 2), local(sg * 15 + 0.6, -lm.d / 2), local(sg * 15 + 0.6, lm.d / 2), local(sg * 15 - 0.6, lm.d / 2)], y0, y0 + 18); continue; }
    prismWalls(mb, lm.footprint, y0, y0 + Math.min(lm.h, 40));
    if (lm.type === 'station') prismWalls(mb, [local(-lm.w * 0.42, -lm.d / 2), local(lm.w * 0.42, -lm.d / 2), local(lm.w * 0.42, -lm.d / 2 - 66), local(-lm.w * 0.42, -lm.d / 2 - 66)], y0, y0 + 14);
  }
  // 市政广场纪念台：圆台斜坡 + 雕像基座
  {
    const y = LV.MID + CURB, R0 = PLAZA.monument, R1 = R0 - 2.6, top = y + 0.96;
    mb.world(PLAZA.x, PLAZA.z);
    const n = 40;
    for (let i = 0; i < n; i++) {
      const a0 = i / n * Math.PI * 2, a1 = (i + 1) / n * Math.PI * 2;
      const p = (a, r, h) => [PLAZA.x + Math.cos(a) * r, h, PLAZA.z + Math.sin(a) * r];
      mb.up(M, [p(a0, R0, y - 0.18), p(a1, R0, y - 0.18), p(a1, R1, top), p(a0, R1, top)], [1, 1, 1]);
    }
    mb.cap(M, circle(PLAZA.x, PLAZA.z, R1, n), top, [1, 1, 1]);
    prismWalls(mb, circle(PLAZA.x, PLAZA.z, 7, 16), top, top + 12);
  }
  // 楼梯：斜坡 + 两侧颊墙
  for (const s of STAIRS) {
    const perp = [-s.dir[1], s.dir[0]], hw = s.width / 2;
    const c = add(s.bottom, mul(s.dir, s.run / 2));
    mb.world(c[0], c[1]);
    const top = add(s.bottom, mul(s.dir, s.run));
    const b0 = add(s.bottom, mul(perp, -hw)), b1 = add(s.bottom, mul(perp, hw)), t1 = add(top, mul(perp, hw)), t0 = add(top, mul(perp, -hw));
    mb.up(M, [[b0[0], s.h0, b0[1]], [b1[0], s.h0, b1[1]], [t1[0], s.h1, t1[1]], [t0[0], s.h1, t0[1]]], [1, 1, 1]);
    for (const sg of [-1, 1]) {
      const a = add(s.bottom, mul(perp, sg * (hw + 0.2))), b = add(top, mul(perp, sg * (hw + 0.2)));
      barrier(mb, a, b, s.h0 - 0.5, s.h1 - 0.5, 1.6);
    }
  }
  // 桥：桥面 + 两侧栏杆
  for (const d of DECKS) {
    for (let i = 0; i + 1 < d.pts.length; i++) {
      const A = d.pts[i], B = d.pts[i + 1];
      const a = [A[0], A[1]], b = [B[0], B[1]], dir = norm(sub(b, a)), perp = [-dir[1], dir[0]], hw = d.width / 2;
      mb.world((A[0] + B[0]) / 2, (A[1] + B[1]) / 2);
      const q = [add(a, mul(perp, -hw)), add(a, mul(perp, hw)), add(b, mul(perp, hw)), add(b, mul(perp, -hw))];
      mb.up(M, [[q[0][0], A[2], q[0][1]], [q[1][0], A[2], q[1][1]], [q[2][0], B[2], q[2][1]], [q[3][0], B[2], q[3][1]]], [1, 1, 1]);
      for (const sg of [-1, 1]) barrier(mb, add(a, mul(perp, sg * hw)), add(b, mul(perp, sg * hw)), A[2] - 0.3, B[2] - 0.3, 1.45);
    }
  }
  // 水池：外沿矮墙 + 湖心岛
  for (const b of BASINS) {
    mb.world(b.x, b.z);
    const ring = circle(b.x, b.z, b.r + 1.2, 48);
    for (let i = 0; i < ring.length; i++) barrier(mb, ring[i], ring[(i + 1) % ring.length], b.level, b.level, 1.0);
    if (b.island > 0) prismWalls(mb, circle(b.x, b.z, b.island, 24), b.level - 1, b.level + 1.4);
  }
  // 城墙
  const pts = WALL.pts;
  for (let i = 0; i + 1 < pts.length; i++) {
    const a = pts[i], b = pts[i + 1];
    if (!a || !b) continue;
    const dir = norm(sub(b, a)), n = [-dir[1], dir[0]], t = WALL.thickness / 2;
    const mid = mul(add(a, b), 0.5);
    mb.world(mid[0], mid[1]);
    const L = dist(a, b), steps = Math.ceil(L / 40);
    for (let k = 0; k < steps; k++) {
      const p0 = add(a, mul(sub(b, a), k / steps)), p1 = add(a, mul(sub(b, a), (k + 1) / steps));
      mb.world((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2);
      prismWalls(mb, [add(p0, mul(n, t)), add(p1, mul(n, t)), add(p1, mul(n, -t)), add(p0, mul(n, -t))], SEABED, 50);
    }
  }
  // 高架桥墩
  const V = VIADUCT.pts, vh = LV.LOW + VIADUCT.h;
  for (let i = 0; i + 1 < V.length; i++) {
    const a = V[i], b = V[i + 1], L = dist(a, b), dir = norm(sub(b, a));
    for (let t = 8; t < L; t += 22) {
      const p = add(a, mul(dir, t));
      const g = terraceAt(p[0], p[1]);
      mb.world(p[0], p[1]);
      prismWalls(mb, circle(p[0], p[1], 2.2, 8), g ? g.level : SEABED, vh - 1.2);
    }
  }
  void pointInPoly;
}
