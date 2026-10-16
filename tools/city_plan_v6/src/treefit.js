// 树木整饬：把规划里生成的树（行道树 / 公园树 / 环湖树 / 台地行树）逐棵对照障碍物检查，
// ① 树干压到建筑、台阶、桥、大厅坡道、传送石、喷泉、水面、城墙、瀑布 → 删树；
// ② 树冠（橡树半径≈6m×0.9×缩放，松树≈6m×0.75，棕榈≈3m）穿进建筑立面 / 桥面 → 先把冠幅沿垂直方向压窄（across ≥ 0.45），仍穿 → 删树；
// ③ 树与树过近（< 5m；棕榈 < 4m）→ 删后者（行道树优先）。
// 结果写回 t.across / t.along / t.yaw（游戏侧 Forest 用它做椭圆冠幅）。
import { pointInPoly } from './geo2d.js';

export const dseg = (p, a, b) => { const dx = b[0] - a[0], dz = b[1] - a[1]; let t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz || 1); t = Math.max(0, Math.min(1, t)); return Math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dz); };
export const dpoly = (p, poly) => { if (pointInPoly(p, poly)) return 0; let m = 1e9; for (let i = 0; i < poly.length; i++) m = Math.min(m, dseg(p, poly[i], poly[(i + 1) % poly.length])); return m; };
export const bbox4 = (poly) => { let x0 = 1e9, z0 = 1e9, x1 = -1e9, z1 = -1e9; for (const p of poly) { x0 = Math.min(x0, p[0]); z0 = Math.min(z0, p[1]); x1 = Math.max(x1, p[0]); z1 = Math.max(z1, p[1]); } return [x0, z0, x1, z1]; };
export const nearBB = (b, p, m) => p[0] > b[0] - m && p[0] < b[2] + m && p[1] > b[1] - m && p[1] < b[3] + m;
export function ribbon(pts, hw) {
  const out = [];
  for (let i = 0; i + 1 < pts.length; i++) {
    const a = pts[i], b = pts[i + 1], dx = b[0] - a[0], dz = b[1] - a[1], L = Math.hypot(dx, dz) || 1, nx = -dz / L * hw, nz = dx / L * hw;
    out.push([[a[0] + nx, a[1] + nz], [b[0] + nx, b[1] + nz], [b[0] - nx, b[1] - nz], [a[0] - nx, a[1] - nz]]);
  }
  return out;
}
const circle = (x, z, r, n = 16) => Array.from({ length: n }, (_, i) => [x + Math.cos(i / n * Math.PI * 2) * r, z + Math.sin(i / n * Math.PI * 2) * r]);

// 冠幅基准半径（米，未乘缩放）
export const CROWN = { round: 5.4, cypress: 4.5, palm: 3.0 };
export const crownR0 = (t) => (CROWN[t.kind] ?? 5.4) * (t.s || 1);

/** 障碍物：solids = 树干不许进入的实体（m 为余量）；walls = 树冠不许穿入的立面 / 桥面（proj 为外挑余量） */
export function obstacles(P) {
  const solids = [], walls = [];
  const W = (poly, kind, proj) => walls.push({ poly, kind, proj, bb: bbox4(poly) });
  const S = (poly, kind, m) => solids.push({ poly, kind, m, bb: bbox4(poly) });
  for (const l of P.LOTS) { W(l.poly, 'lot:' + l.id, 0.6); S(l.poly, 'lot:' + l.id, 1.0); }
  for (const l of P.LANDMARKS) {
    W(l.footprint, 'landmark:' + l.id, l.orn ? 0.3 : 0.8);
    S(l.footprint, 'landmark:' + l.id, l.orn ? 2.0 : 1.0);
  }
  // 功能建筑门前台阶 / 台基（局部 +z 为正面）：与 plan.js stripBlocked 同一套进深
  for (const l of P.LANDMARKS) {
    if (l.orn || l.type === 'gate') continue;
    const front = l.type === 'gatebridge' ? 1.5 : l.type === 'grandpalace' ? 19 : l.type === 'cathedral' || l.type === 'magetower' || l.type === 'portal' ? 5 : 10;
    const c = Math.cos(l.yaw), s = Math.sin(l.yaw), loc = (x, z) => [l.x + c * x + s * z, l.z - s * x + c * z];
    S([loc(-l.w / 2, l.d / 2), loc(l.w / 2, l.d / 2), loc(l.w / 2, l.d / 2 + front), loc(-l.w / 2, l.d / 2 + front)], 'landmark_front:' + l.id, 1.0);
  }
  for (const h of P.HALLS) {
    if (h.landing) S(h.landing, 'landing:' + h.id, 1.5);
    if (h.tunnel) S(h.tunnel, 'tunnel:' + h.id, 1.5);
    for (const r of h.ramps || []) {
      const d = r.dir, n = [-d[1], d[0]], w = r.w / 2, e = [r.b[0] + d[0] * 3, r.b[1] + d[1] * 3];
      S([[r.a[0] + n[0] * w, r.a[1] + n[1] * w], [e[0] + n[0] * w, e[1] + n[1] * w], [e[0] - n[0] * w, e[1] - n[1] * w], [r.a[0] - n[0] * w, r.a[1] - n[1] * w]], 'ramp:' + h.id, 1.5);
    }
  }
  for (const st of P.STAIRS) {
    const n = [-st.dir[1], st.dir[0]], w = st.width / 2, b0 = st.bottom, t0 = st.top;
    S([[b0[0] + n[0] * w, b0[1] + n[1] * w], [b0[0] - n[0] * w, b0[1] - n[1] * w], [t0[0] - n[0] * w, t0[1] - n[1] * w], [t0[0] + n[0] * w, t0[1] + n[1] * w]], 'stair:' + st.id, 1.6);
  }
  for (const d of P.DECKS) for (const r of ribbon(d.pts, d.width / 2 + (d.side || 0))) { S(r, 'deck:' + d.id, 1.0); W(r, 'deck:' + d.id, 0.4); }
  if (P.VIADUCT) for (const r of ribbon(P.VIADUCT.pts, 5)) { S(r, 'viaduct', 1.5); W(r, 'viaduct', 0.5); }
  for (const w of P.WAYSTONES) S([[w.x - 3.8, w.z - 3.8], [w.x + 3.8, w.z - 3.8], [w.x + 3.8, w.z + 3.8], [w.x - 3.8, w.z + 3.8]], 'waystone:' + w.id, 1.2);
  for (const c of P.CANALS) S(c.poly, 'canal:' + c.id, 0.6);
  for (const f of P.FOUNTAINS) S(circle(f.x, f.z, f.r + 1.5), 'fountain', 1.2);
  for (const b of P.BASINS) S(circle(b.x, b.z, b.r + 1, 32), 'basin:' + b.id, 0.6);
  for (const r of ribbon(P.WALL.pts.filter(Boolean), P.WALL.thickness / 2)) S(r, 'wall', 1.5);
  for (const f of P.FALLS) S([[f.x - f.w / 2, f.z - f.depth], [f.x + f.w / 2, f.z - f.depth], [f.x + f.w / 2, f.z + 2], [f.x - f.w / 2, f.z + 2]], 'fall', 1.5);
  return { solids, walls };
}

/** 椭圆冠幅（中心 t，半轴 a 沿 yaw 方向、c 垂直）是否穿入立面；返回最大穿入深度（米），0 = 没穿 */
export function crownPenetration(t, a, c, yaw, walls) {
  const cs = Math.cos(yaw), sn = Math.sin(yaw);
  const pts = [];
  // yaw 与 Godot 一致：绕 Y 转 yaw 后局部 +X 指向 (cos, 0, -sin)
  for (let i = 0; i < 16; i++) { const u = Math.cos(i / 16 * Math.PI * 2) * a, v = Math.sin(i / 16 * Math.PI * 2) * c; pts.push([t.x + cs * u + sn * v, t.z - sn * u + cs * v]); }
  const R = Math.max(a, c);
  let worst = 0;
  for (const w of walls) {
    if (!nearBB(w.bb, [t.x, t.z], R + 2)) continue;
    if (pointInPoly([t.x, t.z], w.poly)) return 99;
    for (const q of pts) {
      if (!nearBB(w.bb, q, w.proj + 0.2)) continue;
      // 点在立面里：穿入 = 外挑余量 + 0.5；否则 = 外挑余量 − 点到立面距离
      const pen = pointInPoly(q, w.poly) ? w.proj + 0.5 : w.proj - dpoly(q, w.poly);
      if (pen > worst) worst = pen;
    }
  }
  return worst;
}

/** 绿化带 / 树池避让：沿中线每 0.5m 采样，压到台阶 / 桥 / 坡道 / 传送石 / 水面等实体（不含沿街建筑）的段落剪掉，剩余各段（≥3m）保留 */
function cutStrips(P, solids) {
  const hard = solids.filter((s) => !s.kind.startsWith('lot') && !s.kind.startsWith('landmark'));
  const out = [], map = [];   // map[oldIdx] = [[newIdx, u0, u1, a, dir], ...]
  let removed = 0, cutCount = 0;
  P.STRIPS.forEach((st, i) => {
    const dx = st.b[0] - st.a[0], dz = st.b[1] - st.a[1], L = Math.hypot(dx, dz), d = [dx / (L || 1), dz / (L || 1)];
    const runs = []; let r0 = null;
    const m = 0.4 + st.w / 2;
    const steps = Math.max(1, Math.round(L / 0.5));
    for (let k = 0; k <= steps; k++) {
      const u = L * k / steps, p = [st.a[0] + d[0] * u, st.a[1] + d[1] * u];
      let free = true;
      for (const s of hard) { if (!nearBB(s.bb, p, m + 0.3)) continue; if (dpoly(p, s.poly) < m) { free = false; break; } }
      if (free) { if (r0 === null) r0 = u; } else if (r0 !== null) { runs.push([r0, u - 0.5]); r0 = null; }
    }
    if (r0 !== null) runs.push([r0, L]);
    const good = runs.filter((r) => r[1] - r[0] >= 3);
    if (good.length !== 1 || good[0][0] > 0.01 || good[0][1] < L - 0.01) cutCount++;
    if (!good.length) removed++;
    map[i] = good.map(([u0, u1]) => {
      const ns = { ...st, a: [st.a[0] + d[0] * u0, st.a[1] + d[1] * u0], b: [st.a[0] + d[0] * u1, st.a[1] + d[1] * u1] };
      out.push(ns);
      return [out.length - 1, u0, u1];
    });
  });
  return { out, map, removed, cutCount };
}

export function fitTrees(P, opts = {}) {
  const { solids, walls } = obstacles(P);
  P.BLOCKS = P.BLOCKS || [];
  const stats = { solid: {}, crownDeleted: 0, squashed: 0, close: 0, lampDeleted: 0, stripsCut: 0, stripsRemoved: 0, offStrip: 0, bedsDropped: 0 };
  const AMIN = 0.45, TOL = 0.3;
  // 0) 草带 / 树池先剪掉压到实体的段，树按新位置重新挂回（挂不上的删）
  {
    const { out, map, removed, cutCount } = cutStrips(P, solids);
    stats.stripsCut = cutCount; stats.stripsRemoved = removed;
    const old = P.STRIPS;
    const remap = (t) => {
      if (t.strip === undefined) return true;
      const st = old[t.strip], dx = st.b[0] - st.a[0], dz = st.b[1] - st.a[1], L = Math.hypot(dx, dz) || 1;
      const u = ((t.x - st.a[0]) * dx + (t.z - st.a[1]) * dz) / L;
      for (const [ni, u0, u1] of map[t.strip]) if (u >= u0 + 0.8 - 1e-6 && u <= u1 - 0.8 + 1e-6) { t.strip = ni; return true; }
      stats.offStrip++; return false;
    };
    const tk = P.TREES.filter(remap), pk = P.PALMS.filter(remap);
    P.TREES.length = 0; P.TREES.push(...tk); P.PALMS.length = 0; P.PALMS.push(...pk);
    P.STRIPS.length = 0; P.STRIPS.push(...out);
  }
  // 行道树（有 strip）优先，其次其它；棕榈同样处理
  const all = [...P.TREES.map((t) => [t, 'T']), ...P.PALMS.map((t) => [t, 'P'])].sort((a, b) => (a[0].strip !== undefined ? 0 : 1) - (b[0].strip !== undefined ? 0 : 1));
  const kept = [];
  const grid = new Map(), key = (x, z) => Math.floor(x / 8) + ',' + Math.floor(z / 8);
  const nearKept = (t, r) => { const cx = Math.floor(t.x / 8), cz = Math.floor(t.z / 8); for (let i = -1; i <= 1; i++) for (let j = -1; j <= 1; j++) for (const k of grid.get((cx + i) + ',' + (cz + j)) || []) if (Math.hypot(k.x - t.x, k.z - t.z) < r) return true; return false; };
  for (const [t, ty] of all) {
    const p = [t.x, t.z];
    let hit = null;
    for (const s of solids) { if (!nearBB(s.bb, p, s.m + 0.5)) continue; if (dpoly(p, s.poly) < s.m) { hit = s.kind.split(':')[0]; break; } }
    if (hit) { stats.solid[hit] = (stats.solid[hit] || 0) + 1; continue; }
    // 功能建筑立面：树干离占地至少 6m（行道树 4m 人行道正好把树挡在大窗 / 尖拱窗前面）；门前通道由 landmark_front 管
    {
      let hitLm = false;
      for (const l of P.LANDMARKS) {
        if (l.orn || l.type === 'gate') continue;
        if (Math.abs(p[0] - l.x) > l.w / 2 + 12 && Math.abs(p[1] - l.z) > l.d / 2 + 12 && Math.hypot(p[0] - l.x, p[1] - l.z) > Math.hypot(l.w, l.d) / 2 + 8) continue;
        if (dpoly(p, l.footprint) < 6.0) { hitLm = true; break; }
      }
      if (hitLm) { stats.nearFacade = (stats.nearFacade || 0) + 1; continue; }
    }
    // 台地树：离台地边（挡土墙压顶 / 栏杆）至少 2m
    if (P.terraceAt && !P.BLOCKS.some((q) => pointInPoly(p, q.poly))) {
      const tr = P.terraceAt(t.x, t.z);
      if (tr && !tr.outer) {
        let m = 1e9; for (let i = 0; i < tr.poly.length; i++) m = Math.min(m, dseg(p, tr.poly[i], tr.poly[(i + 1) % tr.poly.length]));
        if (m < 2.0) { stats.edge = (stats.edge || 0) + 1; continue; }
      }
    }
    if (nearKept(t, ty === 'P' ? 4.0 : 5.0)) { stats.close++; continue; }
    // 树冠：先按街向压窄（沿街 along = min(1, 1.5·across)，垂直街向 across）
    t.yaw = t.yaw ?? 0;
    const R0 = ty === 'P' ? CROWN.palm * (t.s || 1) : crownR0(t);
    let ok = false, across = 1;
    for (across = 1; across >= AMIN - 1e-6; across -= 0.05) {
      const along = Math.min(1, across * 1.5);
      if (crownPenetration(t, R0 * along, R0 * across, t.yaw, walls) <= TOL) { ok = true; t.across = +across.toFixed(2); t.along = +along.toFixed(2); break; }
    }
    if (!ok) { // 再试：四向均匀压窄
      for (across = AMIN; across >= 0.4 - 1e-6; across -= 0.05) {
        if (crownPenetration(t, R0 * across, R0 * across, t.yaw, walls) <= TOL) { ok = true; t.across = +across.toFixed(2); t.along = t.across; break; }
      }
    }
    if (!ok) { stats.crownDeleted++; continue; }
    if (t.across < 0.999) stats.squashed++; else { delete t.across; delete t.along; }
    kept.push([t, ty]);
    const kk = key(t.x, t.z); if (!grid.has(kk)) grid.set(kk, []); grid.get(kk).push(t);
  }
  P.TREES.length = 0; P.PALMS.length = 0;
  for (const [t, ty] of kept) (ty === 'P' ? P.PALMS : P.TREES).push(t);
  // 树池：树被删了的池子一并拆掉（街道草带保留）
  {
    const used = new Set(kept.map(([t]) => t.strip));
    const idx = new Map(), ns = [];
    P.STRIPS.forEach((st, i) => { if (st.block === 'bed' && !used.has(i)) { stats.bedsDropped++; return; } idx.set(i, ns.length); ns.push(st); });
    for (const [t] of kept) if (t.strip !== undefined) t.strip = idx.get(t.strip);
    P.STRIPS.length = 0; P.STRIPS.push(...ns);
  }
  // 路灯：压到树干 / 实体里的删掉
  const lampKeep = P.LAMPS.filter((l) => {
    if (nearKept({ x: l.x, z: l.z }, 1.4)) { stats.lampDeleted++; return false; }
    for (const s of solids) { if (s.kind.startsWith('lot') || s.kind.startsWith('landmark')) continue; if (!nearBB(s.bb, [l.x, l.z], s.m)) continue; if (dpoly([l.x, l.z], s.poly) < 0.4) { stats.lampDeleted++; return false; } }
    return true;
  });
  P.LAMPS.length = 0; P.LAMPS.push(...lampKeep);
  void opts;
  return stats;
}
