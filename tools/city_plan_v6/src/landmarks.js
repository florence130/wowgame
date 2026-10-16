// 地标建筑（局部坐标：原点在占地中心地面，+z 为正面，+x 为右手横向）
const C = {
  stone: [0.93, 0.89, 0.8], stoneD: [0.78, 0.72, 0.62], white: [0.97, 0.95, 0.9], trim: [0.9, 0.86, 0.76],
  brick: [1, 1, 1], copper: [1, 1, 1], slate: [1, 1, 1], gold: [0.86, 0.66, 0.28], iron: [0.2, 0.21, 0.23],
  glass: [0.62, 0.78, 0.86], red: [0.62, 0.16, 0.12], wood: [0.42, 0.28, 0.18], blue: [0.22, 0.34, 0.62], cream: [1, 0.96, 0.88],
};
export { C as COL };

// 通用公共建筑：主楼 + 中央凸出亭 + 角亭 + 柱廊 + 台阶 + 孟莎屋顶
export function civic(mb, o) {
  const { w, d, h } = o;
  const fac = o.fac || 'fac_haus', tint = o.tint || C.white, gf = o.gf || 6;
  const roofMat = o.roof || 'roof_slate';
  mb.box('trim', 0, 0, 0, w + 1.2, 1.2, d + 1.2, C.stoneD, 0, { uv: [3, 3] });
  const P = [[-w / 2, -d / 2], [w / 2, -d / 2], [w / 2, d / 2], [-w / 2, d / 2]];
  bodyWalls(mb, P, 1.2, gf, h, fac, o.ground || 'groundres', tint, [9, 9.5]);
  mb.prism('trim', inflate(P, 0.5), h - 0.4, h + 0.4, C.trim);
  mansard(mb, P, h + 0.4, o.roofH || 5, 2.2, roofMat, o.flatTop ?? true);
  // 中央亭
  const pw = o.pw || Math.max(12, w * 0.28), ph = h + (o.ph || 6);
  const pz0 = d / 2, pz1 = d / 2 + 2.6;   // 与主体正面齐平，背墙不画（否则会伸进室内大厅）
  const PP = [[-pw / 2, pz0], [pw / 2, pz0], [pw / 2, pz1], [-pw / 2, pz1]];
  bodyWalls(mb, PP, 1.2, gf, ph, fac, o.ground || 'groundres', tint, [9, 9.5], [0]);
  if (ph > h) mb.wall(fac, PP[0], PP[1], h, ph, tint, [0, -1], [9, 9.5], 0, 1.2 + gf);
  mb.prism('trim', inflate(PP, 0.5), ph - 0.4, ph + 0.4, C.trim);
  if (o.pediment !== false) pediment(mb, -pw / 2 - 0.4, pw / 2 + 0.4, pz1 + 0.5, ph + 0.4, Math.min(5, pw * 0.22));
  if (o.dome) { drum(mb, 0, ph + 0.4, (pz0 + pz1) / 2 - 4, o.dome, o.domeMat || 'roof_copper'); }
  // 柱廊与台阶
  if (o.columns !== false) {
    const n = o.columns || 6, ch = gf * 1.5;
    for (let i = 0; i < n; i++) { const x = -pw / 2 + 1.2 + i * (pw - 2.4) / (n - 1); column(mb, x, 1.2, pz1 + 1.6, 0.7, ch); }
    mb.box('trim', 0, 1.2 + ch, pz1 + 1.4, pw + 0.8, 1.2, 3.6, C.trim);
  }
  steps(mb, 0, 0, pz1 + (o.columns !== false ? 3.4 : 0.2), pw * 0.8, 1.2, 5, 1);
  // 角亭
  if (o.corners) for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const cw = Math.min(10, w * 0.16);
    const cx = sx * (w / 2 - cw / 2 + 0.6), cz = sz * (d / 2 - cw / 2 + 0.6);
    const CP = [[cx - cw / 2, cz - cw / 2], [cx + cw / 2, cz - cw / 2], [cx + cw / 2, cz + cw / 2], [cx - cw / 2, cz + cw / 2]];
    // 朝主楼内侧的两面墙只画屋檐以上（屋檐以下在室内大厅里）
    const inner = [sz > 0 ? 0 : 2, sx > 0 ? 3 : 1];
    bodyWalls(mb, CP, 1.2, gf, h + 3, fac, o.ground || 'groundres', tint, [9, 9.5], inner);
    for (const i of inner) mb.wall(fac, CP[i], CP[(i + 1) % 4], h - 0.4, h + 3, tint, outward(CP, i), [9, 9.5], 0, 1.2 + gf);
    mb.prism('trim', inflate(CP, 0.4), h + 2.7, h + 3.3, C.trim);
    mansard(mb, CP, h + 3.3, 5, 2.4, roofMat, false, 1.5);
  }
}
// 楼体墙面：底层 + 上层立面
export function bodyWalls(mb, P, y0, gf, h, fac, ground, tint, facUV = [7.2, 7.6], skip = null) {
  const n = P.length;
  for (let i = 0; i < n; i++) {
    if (skip && skip.includes(i)) continue;
    const a = P[i], b = P[(i + 1) % n];
    const out = outward(P, i);
    mb.wall(ground, a, b, y0, y0 + gf, tint, out, [ground.startsWith('shop') || ground === 'groundres' ? 3.6 : facUV[0], gf]);
    if (h > y0 + gf + 0.1) mb.wall(fac, a, b, y0 + gf, h, tint, out, facUV, 0, y0 + gf);
  }
}
export function outward(P, i) {
  const a = P[i], b = P[(i + 1) % P.length];
  let s = 0; for (let k = 0; k < P.length; k++) { const p = P[k], q = P[(k + 1) % P.length]; s += p[0] * q[1] - q[0] * p[1]; }
  const dx = b[0] - a[0], dz = b[1] - a[1], l = Math.hypot(dx, dz) || 1;
  const n = [-dz / l, dx / l];
  return s > 0 ? [-n[0], -n[1]] : n;
}
export function inflate(P, o) {
  const n = P.length, lines = [];
  for (let i = 0; i < n; i++) { const a = P[i], b = P[(i + 1) % n], ou = outward(P, i); lines.push([[a[0] + ou[0] * o, a[1] + ou[1] * o], [b[0] - a[0], b[1] - a[1]]]); }
  const res = [];
  for (let i = 0; i < n; i++) {
    const [p, d] = lines[(i - 1 + n) % n], [q, e] = lines[i];
    const den = d[0] * e[1] - d[1] * e[0];
    if (Math.abs(den) < 1e-9) { res.push(q); continue; }
    const t = ((q[0] - p[0]) * e[1] - (q[1] - p[1]) * e[0]) / den;
    res.push([p[0] + d[0] * t, p[1] + d[1] * t]);
  }
  return res;
}
// 孟莎屋顶：外轮廓在 y0，向内收 ins，高 rh；flat=true 时顶面为铅皮平台
export function mansard(mb, P, y0, rh, ins, mat, flat = true, peak = 0) {
  const Q = inflate(P, -ins);
  const n = P.length;
  for (let i = 0; i < n; i++) {
    const a = P[i], b = P[(i + 1) % n], c = Q[(i + 1) % n], d = Q[i];
    const out = outward(P, i);
    const L = Math.hypot(b[0] - a[0], b[1] - a[1]), sl = Math.hypot(ins, rh);
    mb.face(mat, [[a[0], y0, a[1]], [b[0], y0, b[1]], [c[0], y0 + rh, c[1]], [d[0], y0 + rh, d[1]]], C.slate, [out[0], 0.6, out[1]],
      (p) => [((p[0] - a[0]) * (b[0] - a[0]) + (p[2] - a[1]) * (b[1] - a[1])) / (L || 1) / 3, (p[1] - y0) / rh * sl / 3]);
  }
  if (peak > 0) {
    const cx = Q.reduce((s, p) => s + p[0], 0) / n, cz = Q.reduce((s, p) => s + p[1], 0) / n;
    for (let i = 0; i < n; i++) { const a = Q[i], b = Q[(i + 1) % n]; mb.face(mat, [[a[0], y0 + rh, a[1]], [b[0], y0 + rh, b[1]], [cx, y0 + rh + peak, cz]], C.slate, [0, 1, 0], (p) => [p[0] / 3, p[2] / 3]); }
    mb.cyl('metal', cx, y0 + rh + peak, cz, 0.12, 0.05, 2.2, 6, C.iron);
  } else if (flat) mb.cap('roof_lead', Q, y0 + rh, C.slate, 3);
  return Q;
}
export function pediment(mb, x0, x1, z, y, ph) {
  mb.face('trim', [[x0, y, z], [x1, y, z], [(x0 + x1) / 2, y + ph, z]], C.trim, [0, 0, 1]);
  mb.face('trim', [[x0, y, z - 2], [x1, y, z - 2], [(x0 + x1) / 2, y + ph, z - 2]], C.trim, [0, 0, -1]);
  mb.face('roof_slate', [[x0, y, z + 0.3], [(x0 + x1) / 2, y + ph, z + 0.3], [(x0 + x1) / 2, y + ph, z - 2.3], [x0, y, z - 2.3]], C.slate, [-1, 1, 0], (p) => [p[2] / 3, p[1] / 3]);
  mb.face('roof_slate', [[x1, y, z + 0.3], [(x0 + x1) / 2, y + ph, z + 0.3], [(x0 + x1) / 2, y + ph, z - 2.3], [x1, y, z - 2.3]], C.slate, [1, 1, 0], (p) => [p[2] / 3, p[1] / 3]);
}
export function column(mb, x, y, z, r, h) {
  mb.cyl('trim', x, y, z, r * 1.4, r * 1.4, 0.5, 10, C.trim);
  mb.cyl('trim', x, y + 0.5, z, r, r * 0.88, h - 1.1, 12, C.white);
  mb.cyl('trim', x, y + h - 0.6, z, r * 1.25, r * 1.45, 0.6, 10, C.trim);
}
export function steps(mb, x, y, z, w, h, n, dir = 1) {
  const rise = h / n, tread = 0.4;
  for (let i = 0; i < n; i++) mb.box('trim', x, y, z + dir * (n - i - 0.5) * tread, w, rise * (i + 1), tread, C.stoneD);
}
// 鼓座 + 穹顶 + 灯笼亭
export function drum(mb, x, y, z, r, mat = 'roof_copper') {
  mb.cyl('fac_academy', x, y, z, r, r, r * 0.55, 20, C.white, { uRep: 4, vScale: r * 0.55 });
  mb.cyl('trim', x, y + r * 0.55, z, r + 0.4, r + 0.4, 0.5, 20, C.trim);
  mb.dome(mat, x, y + r * 0.55 + 0.5, z, r, r * 0.95, 20, C.copper);
  const top = y + r * 0.55 + 0.5 + r * 0.95;
  mb.cyl('trim', x, top - 0.2, z, r * 0.18, r * 0.16, r * 0.35, 8, C.white);
  mb.cyl(mat, x, top + r * 0.33, z, r * 0.2, 0, r * 0.35, 8, C.copper);
  mb.cyl('gold', x, top + r * 0.68, z, 0.12, 0.05, 2.5, 6, C.gold);
}
function clockFace(mb, x, y, z, r, nrm) {
  // nrm: [nx, nz] 朝向
  const seg = 16;
  for (let i = 0; i < seg; i++) {
    const a0 = (i / seg) * Math.PI * 2, a1 = ((i + 1) / seg) * Math.PI * 2;
    const t = [nrm[1], -nrm[0]];
    const p = (a, rr) => [x + t[0] * Math.cos(a) * rr + nrm[0] * 0.15, y + Math.sin(a) * rr, z + t[1] * Math.cos(a) * rr + nrm[1] * 0.15];
    mb.face('clock', [[x + nrm[0] * 0.15, y, z + nrm[1] * 0.15], p(a0, r), p(a1, r)], C.cream, [nrm[0], 0, nrm[1]]);
    mb.face('gold', [p(a0, r), p(a0, r + 0.35), p(a1, r + 0.35), p(a1, r)], C.gold, [nrm[0], 0, nrm[1]]);
  }
  mb.face('metal', [[x + nrm[0] * 0.2, y, z + nrm[1] * 0.2], [x + nrm[0] * 0.2, y + r * 0.75, z + nrm[1] * 0.2], [x + nrm[0] * 0.2 + nrm[1] * 0.12, y + r * 0.75, z + nrm[1] * 0.2 - nrm[0] * 0.12]], C.iron, [nrm[0], 0, nrm[1]]);
}
// 方塔（钟楼、市政厅塔）
export function tower(mb, x, z, s, y0, h, o = {}) {
  const P = [[x - s / 2, z - s / 2], [x + s / 2, z - s / 2], [x + s / 2, z + s / 2], [x - s / 2, z + s / 2]];
  bodyWalls(mb, P, y0, 6, h, o.fac || 'fac_haus', y0 > 2 ? (o.fac || 'fac_haus') : 'groundres', o.tint || C.white, [7.2, 7.6]);
  mb.prism('trim', inflate(P, 0.5), h - 0.5, h + 0.3, C.trim);
  if (o.clock) for (const [nx, nz] of [[0, 1], [0, -1], [1, 0], [-1, 0]]) clockFace(mb, x + nx * s / 2, h - s * 0.45, z + nz * s / 2, s * 0.3, [nx, nz]);
  // 钟室：开敞拱 + 角柱
  const bh = s * 0.9, y1 = h + 0.3;
  for (const [cx, cz] of [[-1, -1], [1, -1], [1, 1], [-1, 1]]) mb.box('trim', x + cx * (s / 2 - 0.7), y1, z + cz * (s / 2 - 0.7), 1.4, bh, 1.4, C.white);
  mb.box('trim', x, y1 + bh, z, s + 0.8, 0.8, s + 0.8, C.trim);
  mb.box('metal', x, y1, z, s * 0.4, bh * 0.7, s * 0.4, [0.55, 0.42, 0.2]);
  const y2 = y1 + bh + 0.8;
  if (o.cap === 'dome') { drum(mb, x, y2, z, s * 0.42, 'roof_copper'); }
  else if (o.cap === 'spire') { mb.cyl('roof_slate', x, y2, z, s * 0.62, 0, s * 2.2, 8, C.slate); mb.cyl('gold', x, y2 + s * 2.2, z, 0.12, 0.05, 2.5, 6, C.gold); }
  else { mansard(mb, P.map((p) => [p[0], p[1]]), y2, s * 0.7, s * 0.3, 'roof_copper', false, s * 0.6); }
}

// ---------------------------------------------------------------- 各类地标
export const BUILD = {
  cityhall(mb, lm) {
    civic(mb, { w: lm.w, d: lm.d, h: lm.h, gf: 7, corners: true, pw: 26, ph: 4, pediment: false, columns: 8 });
    tower(mb, 0, -2, 13, lm.h + 4, lm.tower, { clock: true, cap: 'spire' });
    // 侧翼小穹顶
    for (const sx of [-1, 1]) drum(mb, sx * lm.w * 0.28, lm.h + 5.4, 0, 4.2, 'roof_copper');
  },
  exchange(mb, lm) {
    civic(mb, { w: lm.w, d: lm.d, h: lm.h, gf: 7, pw: 22, ph: 6, columns: 6, dome: 7 });
    // 参考图2：广场边高耸绿色穹顶钟楼（立在离广场最近的前角）
    tower(mb, -lm.w / 2 + 6, lm.d / 2 - 6, 12, lm.h - 0.4, 58, { clock: true, cap: 'dome' });   // 从屋檐起，免得塔身伸进室内大厅
  },
  guild(mb, lm) {
    civic(mb, { w: lm.w, d: lm.d, h: lm.h, gf: 6, pw: 18, ph: 5, columns: 4, fac: 'fac_brick', tint: C.brick, corners: false });
    tower(mb, lm.w / 2 - 6, -lm.d / 2 + 6, 11, lm.h - 0.4, 36, { cap: 'spire', fac: 'fac_brick', tint: C.brick });
    for (const sx of [-1, 1]) banner(mb, sx * 6, lm.h - 1, lm.d / 2 + 3.2, 2.2, 8, C.blue);
  },
  portal(mb, lm) {
    const r = lm.w / 2 - 2;
    mb.cyl('trim', 0, 0, 0, r + 3, r + 3, 1.2, 28, C.stoneD, { top: true });
    bodyWalls(mb, Array.from({ length: 28 }, (_, i) => [Math.cos((i + 0.5) / 28 * Math.PI * 2) * r, Math.sin((i + 0.5) / 28 * Math.PI * 2) * r]), 1.2, 6, 15.2, 'fac_academy', 'fac_academy', C.white, [7.2, 7.6]);
    // 柱廊 12 根、细柱、离墙 2.8m：窗洞不被柱身正挡（原 16 根粗柱正好挡在窗前）
    for (let i = 0; i < 12; i++) { const a = ((i + 0.5) / 12) * Math.PI * 2; column(mb, Math.cos(a) * (r + 2.8), 1.2, Math.sin(a) * (r + 2.8), 0.42, 11); }
    mb.cyl('trim', 0, 12.2, 0, r + 3.4, r + 3.4, 1.3, 28, C.trim);
    mb.cyl('trim', 0, 15.2, 0, r + 0.6, r + 0.6, 0.6, 28, C.trim);
    mb.dome('roof_copper', 0, 15.8, 0, r, r * 0.9, 28, C.copper);
    mb.cyl('glow_arcane', 0, 15.8 + r * 0.9, 0, 2.2, 1.6, 4, 10, [0.6, 0.85, 1]);
    // 漂浮的传送环
    ring(mb, 0, 15.8 + r * 0.9 + 9, 0, 6, 0.45, 'glow_arcane', [0.55, 0.85, 1]);
    steps(mb, 0, 0, r + 4.2, 12, 1.2, 5, 1);
  },
  inn(mb, lm) {
    civic(mb, { w: lm.w, d: lm.d, h: lm.h, gf: 5.2, fac: 'fac_plaster', tint: [1, 0.9, 0.78], pw: 14, ph: 3, columns: false, ground: 'shop1', roof: 'roof_tile' });
    for (let k = 1; k < 3; k++) mb.box('wood', 0, 5.2 + k * 3.8 - 0.2, lm.d / 2 + 0.8, lm.w - 4, 0.25, 1.8, C.wood);
    hangingSign(mb, -8, 5.6, lm.d / 2 + 0.3);
  },
  civic(mb, lm) {
    const fac = lm.fac || 'fac_haus';
    civic(mb, { w: lm.w, d: lm.d, h: lm.h, gf: 5.5, pw: Math.min(20, lm.w * 0.35), ph: 4, columns: lm.w > 44 ? 6 : 4, fac, tint: lm.tint || C.white, dome: lm.dome ? 7 : 0 });
  },
  observatory(mb, lm) {
    // 白盒：前部 civic 大厅占满占地，观星塔鼓座落在屋顶后部
    civic(mb, { w: lm.w, d: lm.d, h: 12, gf: 5, pw: 14, ph: 3, columns: 4, fac: 'fac_plaster', tint: [0.88, 0.84, 1], roof: 'roof_violet' });
    const r = Math.min(11, lm.w * 0.25), cz = -lm.d * 0.2;
    mb.cyl('fac_plaster', 0, 12, cz, r, r, 10, 24, [0.88, 0.84, 1], { uRep: 6, vScale: 7.6 });
    mb.cyl('trim', 0, 22, cz, r + 0.6, r + 0.6, 0.8, 24, C.trim);
    mb.dome('roof_copper', 0, 22.8, cz, r, r, 24, [0.8, 0.9, 1]);
    mb.box('metal', 0, 24, cz + r * 0.55, 2.4, r * 0.8, 1, C.iron, 0);
    mb.cyl('gold', 0, 22.8 + r, cz, 0.4, 0.1, 3, 6, C.gold);
  },
  pavilion(mb, lm) {
    // 学者行会：小型 civic 大厅 + 屋顶穹顶亭
    civic(mb, { w: lm.w, d: lm.d, h: 12, gf: 5, pw: 10, ph: 3, columns: false });
    for (let i = 0; i < 8; i++) { const a = ((i + 0.5) / 8) * Math.PI * 2; column(mb, Math.cos(a) * 4.5, 12.4, Math.sin(a) * 4.5 - 2, 0.35, 5); }
    mb.cyl('trim', 0, 17.4, -2, 5.2, 5.2, 0.8, 20, C.trim);
    mb.dome('roof_copper', 0, 18.2, -2, 5, 3.6, 20, C.copper);
  },
  workshop(mb, lm) {
    const { w, d, h } = lm;
    mb.box('trim', 0, 0, 0, w + 1, 0.8, d + 1, C.stoneD);
    const P = [[-w / 2, -d / 2], [w / 2, -d / 2], [w / 2, d / 2], [-w / 2, d / 2]];
    bodyWalls(mb, P, 0.8, 5, h, 'fac_warehouse', 'fac_warehouse', C.brick, [7.2, 7.6]);
    mb.prism('trim', inflate(P, 0.3), h - 0.3, h + 0.3, C.trim);
    // 锯齿屋顶（采光）
    const n = Math.max(3, Math.round(w / 9)), sw = w / n;
    for (let i = 0; i < n; i++) {
      const x0 = -w / 2 + i * sw, x1 = x0 + sw;
      mb.face('roof_slate', [[x0, h + 0.3, -d / 2], [x0, h + 0.3, d / 2], [x1, h + 4.5, d / 2], [x1, h + 4.5, -d / 2]], C.slate, [-1, 1, 0], (p) => [p[2] / 3, p[0] / 3]);
      mb.face('glass', [[x1, h + 0.3, -d / 2], [x1, h + 4.5, -d / 2], [x1, h + 4.5, d / 2], [x1, h + 0.3, d / 2]], C.glass, [1, 0, 0]);
      mb.face('fac_warehouse', [[x0, h + 0.3, d / 2], [x1, h + 0.3, d / 2], [x1, h + 4.5, d / 2]], C.brick, [0, 0, 1], (p) => [p[0] / 7.2, p[1] / 7.6]);
      mb.face('fac_warehouse', [[x0, h + 0.3, -d / 2], [x1, h + 0.3, -d / 2], [x1, h + 4.5, -d / 2]], C.brick, [0, 0, -1], (p) => [p[0] / 7.2, p[1] / 7.6]);
    }
    for (const cx of [-w / 2 + 4, w / 2 - 6]) { mb.cyl('fac_brick', cx, h, -d / 2 + 4, 1.4, 1.1, 14, 10, C.brick, { vScale: 7.6 }); mb.cyl('trim', cx, h + 14, -d / 2 + 4, 1.4, 1.4, 0.6, 10, C.trim); }
    hangingSign(mb, 0, 5.2, d / 2 + 0.3);
    mb.box('wood', 0, 0.8, d / 2 + 1.6, w * 0.6, 0.15, 3, C.wood);
  },
  bath(mb, lm) {
    civic(mb, { w: lm.w, d: lm.d, h: lm.h, gf: 6, pw: 20, ph: 3, columns: 6, dome: 10, tint: [1, 0.95, 0.88] });
  },
  magetower(mb, lm) {
    // 湖心法师塔：高 lm.h（默认 120m），基座 + 五段收分塔身 + 飞扶垛 + 悬浮符环 + 尖顶水晶
    const k = lm.h / 74;
    mb.cyl('trim', 0, 0, 0, 14, 13, 3, 24, C.stoneD, { top: true });
    const segs = [[11, 0, 18], [9.4, 18, 38], [8, 38, 60], [6.8, 60, 80], [5.6, 80, 96]].map(([r, a, b]) => [r, 3 + a * k * 0.8, 3 + b * k * 0.8]);
    for (const [r, y0, y1] of segs) {
      if (y0 <= 3.01) { const P = Array.from({ length: 24 }, (_, i) => [Math.cos((i + 0.5) / 24 * Math.PI * 2) * r, Math.sin((i + 0.5) / 24 * Math.PI * 2) * r]); bodyWalls(mb, P, y0, 6, y1, 'fac_academy', 'fac_academy', [0.84, 0.86, 1], [7.2, 7.6]); }
      else mb.cyl('fac_academy', 0, y0, 0, r, r * 0.95, y1 - y0, 24, [0.84, 0.86, 1], { uRep: 8, vScale: 7.6 });
      mb.cyl('trim', 0, y1 - 0.3, 0, r + 1.4, r + 1.4, 0.8, 24, C.trim, { top: true });
      for (let i = 0; i < 4; i++) { const a = i / 4 * Math.PI * 2 + Math.PI / 4; mb.cyl('roof_violet', Math.cos(a) * (r + 1.2), y1 + 0.5, Math.sin(a) * (r + 1.2), 1.1, 0, 5, 6, [0.8, 0.75, 1]); }
    }
    for (let i = 0; i < 6; i++) {           // 飞扶垛
      const a = i / 6 * Math.PI * 2;
      mb.push(Math.cos(a) * 16, 0, Math.sin(a) * 16, -a + Math.PI / 2);
      mb.box('fac_academy', 0, 0, 0, 2.4, 22 * k * 0.8, 4, [0.84, 0.86, 1], 0, { uv: [7.2, 7.6] });
      mb.cyl('roof_violet', 0, 22 * k * 0.8, 0, 2.2, 0, 7, 4, [0.8, 0.75, 1]);
      mb.pop();
    }
    const top = segs[segs.length - 1][2];
    mb.cyl('roof_violet', 0, top + 0.5, 0, 7, 0, 22 * k * 0.8, 16, [0.8, 0.75, 1]);
    mb.cyl('glow_arcane', 0, top + 22 * k * 0.8, 0, 1.4, 0.05, 9, 6, [0.7, 0.85, 1]);
    for (const [f, r] of [[0.42, 19], [0.62, 15], [0.8, 12]]) ring(mb, 0, 3 + top * f, 0, r, 0.45, 'glow_arcane', [0.6, 0.8, 1]);
    steps(mb, 0, 0, 14.5, 8, 3, 8, 1);
  },
  grandpalace(mb, lm) {
    // 晴岚王宫（白模）：三级基座 + 主楼与中央穹顶 + 前伸两翼与角亭 + 后部双钟楼 + 前廊柱列；正面 +z
    const { w, d } = lm, H = lm.h, base = 4;
    mb.box('trim', 0, 0, 0, w + 18, 2, d + 18, C.stoneD);
    mb.box('trim', 0, 2, 0, w + 8, 2, d + 8, C.stone);
    steps(mb, 0, 0, d / 2 + 9 + 3.6, 70, base, 12, 1);
    const cw = w * 0.46, cd = 50, cz = -d / 2 + cd / 2;
    mb.push(0, base, cz);
    civic(mb, { w: cw, d: cd, h: H, gf: 8, corners: false, pw: 46, ph: 12, columns: 12, pediment: true, roof: 'roof_royal', tint: [1, 1, 1] });
    mb.pop();
    // 中央鼓座穹顶（穹顶顶点约 lm.dome 米）
    drum(mb, 0, base + H + 12.4, cz + 4, 19, 'roof_royal');
    for (const sx of [-1, 1]) {
      // 连廊
      mb.push(sx * (cw / 2 + 17), base, -d / 2 + 18);
      civic(mb, { w: 34, d: 30, h: H - 6, gf: 7, corners: false, pw: 14, ph: 2, columns: false, pediment: false, roof: 'roof_royal' });
      mb.pop();
      // 前伸翼楼
      const wx = sx * (w / 2 - 18);
      mb.push(wx, base, 6, sx * Math.PI / 2 * -1 * 0);
      civic(mb, { w: 36, d: d - 30, h: H - 4, gf: 7, corners: false, pw: 18, ph: 3, columns: false, pediment: false, roof: 'roof_royal' });
      mb.pop();
      // 翼楼前端角亭（带高孟莎尖顶）
      mb.push(wx, base, d / 2 - 22);
      civic(mb, { w: 40, d: 40, h: H + 6, gf: 7, corners: false, pw: 20, ph: 4, columns: 6, pediment: true, roof: 'roof_royal' });
      mb.pop();
      mansard(mb, [[wx - 20, d / 2 - 42], [wx + 20, d / 2 - 42], [wx + 20, d / 2 - 2], [wx - 20, d / 2 - 2]], base + H + 6.4, 9, 6, 'roof_royal', false, 14);
      // 后部双钟楼
      tower(mb, sx * (cw / 2 - 8), -d / 2 + 8, 15, base, H + 26, { clock: sx < 0, cap: 'spire', fac: 'fac_academy' });
      // 旗杆
      for (const fz of [d / 2 - 2]) { mb.cyl('metal', wx, base + H + 30, fz - 20, 0.25, 0.15, 14, 6, C.iron); banner(mb, wx + 2.4, base + H + 43, fz - 20, 4, 7, C.blue); }
    }
  },
  triumph(mb, lm) {
    // 凯旋门：两座厚墩 + 16m 宽中拱 + 墩内侧拱 + 檐部 + 女儿墙 + 四驾马车青铜像；正面 +z
    const W = lm.w, D = lm.d, span = 16, pw = (W - span) / 2, hA = 24, R = span / 2;
    for (const sx of [-1, 1]) {
      const x = sx * (span / 2 + pw / 2);
      mb.box('fac_academy', x, 0, 0, pw, hA, D, [1, 0.98, 0.94], 0, { uv: [7.2, 7.6] });
      for (const fz of [D / 2 + 0.6, -D / 2 - 0.6]) for (const cx of [x - pw / 2 + 1.4, x + pw / 2 - 1.4]) column(mb, cx, 1.2, fz, 0.8, hA - 2);
      mb.box('trim', x, 0, 0, pw + 1.6, 1.2, D + 2.4, C.stoneD);
    }
    const yS = hA - R;
    for (let i = 0; i < 18; i++) {
      const a0 = Math.PI * i / 18, a1 = Math.PI * (i + 1) / 18;
      const p = (a, zz) => [Math.cos(a) * R, yS + Math.sin(a) * R, zz];
      for (const zz of [D / 2, -D / 2]) mb.face('fac_academy', [p(a0, zz), p(a1, zz), [Math.cos(a1) * R, hA, zz], [Math.cos(a0) * R, hA, zz]], [1, 0.98, 0.94], [0, 0, Math.sign(zz)], (q) => [q[0] / 7.2, q[1] / 7.6]);
      mb.face('trim', [p(a0, D / 2), p(a1, D / 2), p(a1, -D / 2), p(a0, -D / 2)], C.stoneD, [-Math.cos((a0 + a1) / 2), -Math.sin((a0 + a1) / 2), 0]);
      mb.face('trim', [[Math.cos(a0) * (R + 1.2), yS + Math.sin(a0) * (R + 1.2), D / 2 + 0.3], [Math.cos(a1) * (R + 1.2), yS + Math.sin(a1) * (R + 1.2), D / 2 + 0.3], p(a1, D / 2 + 0.3), p(a0, D / 2 + 0.3)], C.trim, [0, 0, 1]);
    }
    for (const sx of [-1, 1]) mb.box('trim', sx * (R + 0.6), 0, 0, 1.2, yS, D + 0.2, C.stoneD);
    mb.box('trim', 0, hA, 0, W + 2, 1.6, D + 2, C.trim);
    mb.box('fac_academy', 0, hA + 1.6, 0, W - 2, 9, D - 1, [1, 0.98, 0.94], 0, { uv: [7.2, 7.6] });
    mb.box('gold', 0, hA + 4, D / 2 - 0.4, W * 0.5, 2.4, 0.3, C.gold);
    mb.box('trim', 0, hA + 10.6, 0, W, 1.2, D + 0.6, C.trim);
    // 四驾马车
    mb.box('trim', 0, hA + 11.8, 0, 12, 1.6, 7, C.stoneD);
    for (let i = 0; i < 4; i++) { const x = -4.5 + i * 3; mb.box('bronze', x, hA + 13.4, 1.4, 1.2, 2.2, 4, [1, 1, 1]); mb.box('bronze', x, hA + 15.6, 3.1, 1, 1.8, 1.2, [1, 1, 1]); }
    mb.box('bronze', 0, hA + 13.4, -2.4, 6, 2.4, 3, [1, 1, 1]);
    mb.cyl('bronze', 0, hA + 15.8, -2.4, 0.7, 0.6, 3.6, 8, [1, 1, 1]);
    mb.cyl('gold', 0, hA + 19.4, -2.4, 0.5, 0.2, 1.4, 8, C.gold);
  },
  obelisk(mb, lm) {
    mb.box('trim', 0, 0, 0, 6, 1.2, 6, C.stoneD);
    mb.box('trim', 0, 1.2, 0, 4.4, 3, 4.4, C.trim);
    mb.cyl('fac_academy', 0, 4.2, 0, 1.8, 1.1, lm.h - 7, 4, [0.97, 0.95, 0.9], { uRep: 1, vScale: 7.6 });
    mb.cyl('gold', 0, lm.h - 2.8, 0, 1.1, 0, 2.8, 4, C.gold);
  },
  equestrian(mb, lm) {
    mb.box('trim', 0, 0, 0, 12, 1.2, 8, C.stoneD);
    mb.box('trim', 0, 1.2, 0, 9, 4.5, 5, C.trim);
    mb.box('trim', 0, 5.7, 0, 9.6, 0.6, 5.6, C.stoneD);
    const y = 6.3;
    mb.box('bronze', 0, y + 2.2, 0, 1.6, 2.2, 5.4, [1, 1, 1]);
    for (const [x, z] of [[-0.5, 2], [0.5, 2], [-0.5, -2], [0.5, -2]]) mb.box('bronze', x, y, z, 0.4, 2.4, 0.4, [1, 1, 1]);
    mb.box('bronze', 0, y + 4, 2.9, 1, 2.4, 1.2, [1, 1, 1]);
    mb.cyl('bronze', 0, y + 4.4, 0.4, 0.55, 0.45, 2.6, 8, [1, 1, 1]);
    mb.dome('bronze', 0, y + 7, 0.4, 0.45, 0.55, 8, [1, 1, 1]);
    mb.box('bronze', 0.7, y + 6, 1.4, 0.2, 0.2, 2.6, [1, 1, 1]);
  },
  academy(mb, lm) {
    const { w, d, h } = lm, t = 18;
    // 四翼围合庭院
    const wings = [[0, d / 2 - t / 2, w, t], [0, -d / 2 + t / 2, w, t], [-w / 2 + t / 2, 0, t, d - 2 * t], [w / 2 - t / 2, 0, t, d - 2 * t]];
    for (const [x, z, ww, dd] of wings) {
      const P = [[x - ww / 2, z - dd / 2], [x + ww / 2, z - dd / 2], [x + ww / 2, z + dd / 2], [x - ww / 2, z + dd / 2]];
      mb.box('trim', x, 0, z, ww + 0.8, 1, dd + 0.8, C.stoneD);
      bodyWalls(mb, P, 1, 5.5, h, 'fac_academy', 'groundres', C.white, [7.2, 7.6]);
      mb.prism('trim', inflate(P, 0.4), h - 0.3, h + 0.4, C.trim);
      mansard(mb, P, h + 0.4, 4.5, 2, 'roof_copper');
    }
    tower(mb, w / 2 - 12, d / 2 - 9, 14, h - 0.3, lm.tower, { clock: true, cap: 'spire', fac: 'fac_academy' });
    steps(mb, 0, 0, d / 2 + 1.6, 16, 1, 5, 1);
    // 庭院回廊柱
    for (let i = 0; i < 8; i++) { column(mb, -w / 2 + t + 4 + i * (w - 2 * t - 8) / 7, 1, -d / 2 + t + 3, 0.45, 5); column(mb, -w / 2 + t + 4 + i * (w - 2 * t - 8) / 7, 1, d / 2 - t - 3, 0.45, 5); }
  },
  palace(mb, lm) {
    const { w, d, h } = lm;
    // U 形：主楼在后（-z），两翼向前伸，正面朝 +z
    const t = 26;
    const parts = [[0, -d / 2 + t / 2, w, t, true], [-w / 2 + t / 2, t / 2, t, d - t, false], [w / 2 - t / 2, t / 2, t, d - t, false]];
    for (const [x, z, ww, dd, main] of parts) {
      const P = [[x - ww / 2, z - dd / 2], [x + ww / 2, z - dd / 2], [x + ww / 2, z + dd / 2], [x - ww / 2, z + dd / 2]];
      mb.box('trim', x, 0, z, ww + 1, 1.5, dd + 1, C.stoneD);
      bodyWalls(mb, P, 1.5, 7, h, 'fac_haus', 'groundres', [1, 0.98, 0.94], [8.4, 8.8]);
      mb.prism('trim', inflate(P, 0.6), h - 0.4, h + 0.6, C.trim);
      mansard(mb, P, h + 0.6, 6, 2.6, 'roof_copper');
      if (main) { for (let i = 0; i < 10; i++) column(mb, -20 + i * 40 / 9, 1.5, z + dd / 2 + 1.5, 0.8, 12); mb.box('trim', 0, 13.5, z + dd / 2 + 1.4, 44, 1.4, 4, C.trim); }
    }
    drum(mb, 0, h + 6.6, -d / 2 + t / 2, 11, 'roof_copper');
    for (const sx of [-1, 1]) drum(mb, sx * (w / 2 - t / 2), h + 6.6, d / 2 - 10, 5.5, 'roof_copper');
    steps(mb, 0, 0, -d / 2 + t + 5, 40, 1.5, 6, 1);
  },
  airtower(mb, lm) {
    // 飞艇站瞭望塔（参考图 4）：八角塔基 → 收分塔身 → 约 92m 处铁艺玻璃观景笼 → 尖顶；系泊臂伸向正面（飞艇坪）
    const r = lm.w / 2 - 1.5, H = lm.h;
    const oct = (rr, rot = 0) => Array.from({ length: 8 }, (_, i) => [Math.cos(rot + (i + 0.5) / 8 * Math.PI * 2) * rr, Math.sin(rot + (i + 0.5) / 8 * Math.PI * 2) * rr]);
    mb.prism('trim', oct(r + 4), 0, 1.2, C.stoneD, { topMat: 'plaza', topScale: 4 });
    bodyWalls(mb, oct(r), 1.2, 9, 30, 'fac_academy', 'fac_academy', C.white, [7.2, 9]);
    mb.prism('trim', oct(r + 0.8), 29.6, 30.6, C.trim);
    bodyWalls(mb, oct(r * 0.72), 30.6, 6, 88, 'fac_academy', 'fac_academy', C.white, [7.2, 9]);
    for (const z of [50, 70]) mb.prism('trim', oct(r * 0.72 + 0.5), z, z + 0.8, C.trim);
    mb.cyl('trim', 0, 88, 0, r * 1.05, r * 1.05, 1.2, 16, C.trim, { top: true });          // 观景平台
    mb.cyl('glass', 0, 89.2, 0, r * 0.98, r * 0.92, 11, 16, C.glass);                         // 玻璃笼
    for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; mb.cyl('metal', Math.cos(a) * r, 89.2, Math.sin(a) * r, 0.25, 0.25, 11, 6, C.iron); }
    ring(mb, 0, 100.2, 0, r * 0.95, 0.35, 'bronze', [1, 1, 1]);
    mb.cyl('roof_copper', 0, 100.2, 0, r * 1.02, 1.2, H - 100.2 - 6, 16, C.copper);
    mb.cyl('gold', 0, H - 6, 0, 0.6, 0.05, 8, 8, C.gold);
    // 系泊臂：从 70m 处伸向正面 16m，端头系泊环
    mb.box('metal', 0, 70, r * 0.72 + 8, 1.4, 1.2, 16, C.iron);
    ring(mb, 0, 69.4, r * 0.72 + 16, 1.6, 0.25, 'bronze', [1, 1, 1]);
  },
  airship(mb, lm) {
    mb.cyl('trim', 0, 0, 0, 20, 20, 2.2, 32, C.stoneD, { top: true });
    mb.cyl('metal', 0, 2.2, 0, 0.8, 0.6, 24, 8, C.iron);
    mb.cyl('gold', 0, 26, 0, 1.6, 0.4, 2, 8, C.gold);
    for (let i = 0; i < 12; i++) { const a = i / 12 * Math.PI * 2; mb.cyl('metal', Math.cos(a) * 19.5, 2.2, Math.sin(a) * 19.5, 0.12, 0.12, 1.1, 6, C.iron); }
  },
  cathedral(mb, lm) {
    const { w, d, h } = lm;
    // 正面 +z（朝北的大圣堂由 yaw 决定）
    const nave = [[-w * 0.22, -d / 2 + 10], [w * 0.22, -d / 2 + 10], [w * 0.22, d / 2 - 12], [-w * 0.22, d / 2 - 12]];
    mb.box('trim', 0, 0, 0, w + 2, 1.4, d + 2, C.stoneD);
    bodyWalls(mb, nave, 1.4, 8, h, 'fac_academy', 'fac_academy', C.white, [7.2, 9]);
    gable(mb, nave, h, 14, 'roof_slate', C.slate);
    for (const sx of [-1, 1]) {
      const aisle = [[sx * w * 0.22, -d / 2 + 14], [sx * w / 2, -d / 2 + 14], [sx * w / 2, d / 2 - 14], [sx * w * 0.22, d / 2 - 14]];
      bodyWalls(mb, aisle, 1.4, 6, h * 0.55, 'fac_academy', 'fac_academy', C.white, [7.2, 9]);
      mb.cap('roof_slate', aisle, h * 0.55, C.slate, 3);
      for (let z = -d / 2 + 18; z < d / 2 - 16; z += 10) { mb.box('trim', sx * (w / 2 + 0.8), 1.4, z, 2.2, h * 0.5, 2.6, C.stone); mb.cyl('roof_slate', sx * (w / 2 + 0.8), 1.4 + h * 0.5, z, 1.4, 0, 4, 4, C.slate); }
    }
    // 西立面双塔 + 玫瑰窗
    for (const sx of [-1, 1]) {
      const ts = Math.min(7, (w / 2 - w * 0.22) / 2), tx = sx * (w / 2 - ts);   // 小教堂的塔收窄，不压中殿
      const P = [[tx - ts, d / 2 - 14], [tx + ts, d / 2 - 14], [tx + ts, d / 2], [tx - ts, d / 2]];
      bodyWalls(mb, P, 1.4, 8, h + 16, 'fac_academy', 'fac_academy', C.white, [7, 9]);
      mb.prism('trim', inflate(P, 0.6), h + 15.6, h + 16.6, C.trim);
      mb.cyl('roof_slate', tx, h + 16.6, d / 2 - 7, ts + 0.5, 0, lm.spire - h - 16, 8, C.slate);
      mb.cyl('gold', tx, lm.spire + 0.6, d / 2 - 7, 0.15, 0.05, 3, 6, C.gold);
    }
    const fz = d / 2 - 12;
    mb.face('trim', [[-w * 0.22, h, fz], [w * 0.22, h, fz], [0, h + 14, fz]], C.white, [0, 0, 1]);
    rose(mb, 0, h * 0.72, fz + 0.2, 5.5);
    // 大门
    // 后殿半圆
    // 只画向后突出的半圆墙（整圆会有一半伸进中殿大厅）
    const ar = w * 0.22, az = -d / 2 + 10, apse = Array.from({ length: 9 }, (_, i) => [Math.cos(i / 8 * Math.PI) * ar, az - Math.sin(i / 8 * Math.PI) * ar]);
    bodyWalls(mb, apse, 1.4, 8, h, 'fac_academy', 'fac_academy', C.white, [7.2, 9], [8]);
    mb.dome('roof_slate', 0, h, -d / 2 + 10, w * 0.22, 9, 16, C.slate);
    steps(mb, 0, 0, d / 2 + 0.6, w * 0.5, 1.4, 6, 1);
  },
  lighthouse(mb, lm) {
    mb.cyl('trim', 0, 0, 0, 8, 8, 2, 16, C.stoneD, { top: true });
    const bands = 6;
    for (let i = 0; i < bands; i++) mb.cyl('trim', 0, 2 + i * 5.5, 0, 5.2 - i * 0.35, 5.2 - (i + 1) * 0.35, 5.5, 16, i % 2 ? [0.75, 0.2, 0.16] : C.white);
    mb.cyl('trim', 0, 35, 0, 4.4, 4.4, 0.6, 16, C.iron, { top: true });
    mb.cyl('glow_lamp', 0, 35.6, 0, 2.6, 2.6, 3.2, 12, [1, 0.9, 0.6]);
    mb.cyl('roof_copper', 0, 38.8, 0, 3.2, 0, 3.4, 12, C.copper);
  },
  station(mb, lm) {
    const { w, d, h } = lm;
    // 参考图1：红砖 + 石带，中央大拱窗（放射窗棂），两侧穹顶塔，背后铁玻璃列车棚
    mb.box('trim', 0, 0, 0, w + 2, 1.2, d + 2, C.stoneD);
    const cw = 44;
    for (const sx of [-1, 1]) {
      const x0 = sx > 0 ? cw / 2 : -w / 2, x1 = sx > 0 ? w / 2 : -cw / 2;
      const P = [[x0, -d / 2], [x1, -d / 2], [x1, d / 2], [x0, d / 2]];
      bodyWalls(mb, P, 1.2, 6, h - 6, 'fac_brick', 'groundres', C.brick, [7.2, 7.6]);
      mb.prism('trim', inflate(P, 0.5), h - 6.4, h - 5.6, C.trim);
      mansard(mb, P, h - 5.6, 5, 2.2, 'roof_slate');
    }
    const P = [[-cw / 2, -d / 2], [cw / 2, -d / 2], [cw / 2, d / 2], [-cw / 2, d / 2]];
    bodyWalls(mb, P, 1.2, 6, h + 6, 'fac_brick', 'groundres', C.brick, [7.2, 7.6]);
    // 大拱窗
    const R = cw * 0.36, cy = h - 4, fz = d / 2 + 0.06;
    for (let i = 0; i < 18; i++) {
      const a0 = Math.PI * i / 18, a1 = Math.PI * (i + 1) / 18;
      mb.face('glass_lit', [[0, cy, fz], [Math.cos(a0) * R, cy + Math.sin(a0) * R, fz], [Math.cos(a1) * R, cy + Math.sin(a1) * R, fz]], C.glass, [0, 0, 1]);
      mb.face('trim', [[Math.cos(a0) * R, cy + Math.sin(a0) * R, fz + 0.1], [Math.cos(a0) * (R + 1.6), cy + Math.sin(a0) * (R + 1.6), fz + 0.1], [Math.cos(a1) * (R + 1.6), cy + Math.sin(a1) * (R + 1.6), fz + 0.1], [Math.cos(a1) * R, cy + Math.sin(a1) * R, fz + 0.1]], C.trim, [0, 0, 1]);
      if (i % 3 === 0) mb.face('metal', [[0, cy, fz + 0.15], [Math.cos(a0) * R, cy + Math.sin(a0) * R, fz + 0.15], [Math.cos(a0 + 0.02) * R, cy + Math.sin(a0 + 0.02) * R, fz + 0.15]], C.iron, [0, 0, 1]);
    }
    mb.face('glass_lit', [[-R, 7, fz], [R, 7, fz], [R, cy, fz], [-R, cy, fz]], C.glass, [0, 0, 1]);
    for (let i = -3; i <= 3; i++) mb.box('metal', i * R / 3.5, 7, fz + 0.1, 0.25, cy - 7, 0.2, C.iron);
    mb.face('trim', [[-cw / 2 - 0.5, h + 6, fz], [cw / 2 + 0.5, h + 6, fz], [0, h + 16, fz]], C.trim, [0, 0, 1]);
    clockFace(mb, 0, h + 9.5, fz + 0.2, 3, [0, 1]);
    mb.face('roof_slate', [[-cw / 2 - 0.6, h + 6, fz + 0.5], [0, h + 16, fz + 0.5], [0, h + 16, -d / 2 - 0.5], [-cw / 2 - 0.6, h + 6, -d / 2 - 0.5]], C.slate, [-1, 1, 0], (p) => [p[2] / 3, p[1] / 3]);
    mb.face('roof_slate', [[cw / 2 + 0.6, h + 6, fz + 0.5], [0, h + 16, fz + 0.5], [0, h + 16, -d / 2 - 0.5], [cw / 2 + 0.6, h + 6, -d / 2 - 0.5]], C.slate, [1, 1, 0], (p) => [p[2] / 3, p[1] / 3]);
    for (const sx of [-1, 1]) tower(mb, sx * (cw / 2 + 5), d / 2 - 5, 10, 1.2, h + 10, { cap: 'dome', fac: 'fac_brick', tint: C.brick });
    // 入口雨棚
    mb.box('metal', 0, 6.2, d / 2 + 5, cw * 0.8, 0.4, 10, C.iron);
    mb.face('glass', [[-cw * 0.4, 6.8, d / 2], [cw * 0.4, 6.8, d / 2], [cw * 0.4, 6.0, d / 2 + 10], [-cw * 0.4, 6.0, d / 2 + 10]], C.glass, [0, 1, 0]);
    for (const x of [-cw * 0.38, cw * 0.38]) mb.cyl('metal', x, 1.2, d / 2 + 9.5, 0.25, 0.25, 5, 8, C.iron);
    // 列车棚（铁拱 + 玻璃），向后延伸
    const sz0 = -d / 2, sz1 = -d / 2 - 66, sw = w * 0.8, sr = sw / 2;
    for (let i = 0; i < 16; i++) {
      const a0 = Math.PI * i / 16, a1 = Math.PI * (i + 1) / 16;
      const p = (a, z) => [Math.cos(a) * sr, 8 + Math.sin(a) * sr * 0.55, z];
      mb.face(i % 4 === 1 || i % 4 === 2 ? 'glass_lit' : 'roof_lead', [p(a0, sz0), p(a1, sz0), p(a1, sz1), p(a0, sz1)], i % 4 === 1 || i % 4 === 2 ? C.glass : C.slate, [Math.cos((a0 + a1) / 2), 1, 0], (q) => [q[2] / 3, q[0] / 3]);
    }
    for (let z = sz0; z >= sz1; z -= 11) for (let i = 0; i < 16; i++) {
      const a0 = Math.PI * i / 16, a1 = Math.PI * (i + 1) / 16;
      mb.strip('steel_red', [Math.cos(a0) * sr, z], [Math.cos(a1) * sr, z], 8 + Math.sin(a0) * sr * 0.55, 8 + Math.sin(a1) * sr * 0.55, 0.7, [1, 1, 1]);
    }
    for (const sx of [-1, 1]) mb.box('fac_brick', sx * sr, 1.2, (sz0 + sz1) / 2, 2, 7, 66, C.brick, 0, { uv: [7.2, 7.6] });
  },
  opera(mb, lm) {
    civic(mb, { w: lm.w, d: lm.d, h: lm.h, gf: 7, pw: 34, ph: 5, columns: 8, dome: 0, corners: true, tint: [1, 0.96, 0.9] });
    drum(mb, 0, lm.h + 0.4, -6, 14, 'roof_copper');
    for (const sx of [-1, 1]) statue(mb, sx * 12, lm.h + 5.6, lm.d / 2 + 2.2, 0.9);
  },
  terminal(mb, lm) {
    civic(mb, { w: lm.w, d: lm.d, h: lm.h, gf: 6, pw: 16, ph: 8, columns: false, pediment: true, fac: 'fac_plaster', tint: [0.9, 0.95, 1] });
    clockFace(mb, 0, lm.h + 4, lm.d / 2 + 2.7, 2.2, [0, 1]);
    mb.box('metal', 0, 5.6, lm.d / 2 + 5, lm.w * 0.8, 0.3, 8, C.iron);
    mb.face('glass', [[-lm.w * 0.4, 6, lm.d / 2], [lm.w * 0.4, 6, lm.d / 2], [lm.w * 0.4, 5.4, lm.d / 2 + 8.5], [-lm.w * 0.4, 5.4, lm.d / 2 + 8.5]], C.glass, [0, 1, 0]);
  },
  tavern(mb, lm) {
    const { w, d, h } = lm;
    const P = [[-w / 2, -d / 2], [w / 2, -d / 2], [w / 2, d / 2], [-w / 2, d / 2]];
    mb.box('trim', 0, 0, 0, w + 1, 0.6, d + 1, C.stoneD);
    bodyWalls(mb, P, 0.6, 4.6, h, 'fac_plaster', 'shop1', [1, 0.86, 0.72], [7.2, 7.6]);
    gable(mb, P, h, 7, 'roof_tile', C.slate, true);
    hangingSign(mb, -w / 2 + 6, 5, d / 2 + 0.3);
    for (let i = 0; i < 4; i++) mb.cyl('wood', -w / 2 + 8 + i * 8, 0.6, d / 2 + 3, 0.6, 0.6, 1, 8, C.wood, { top: true });
  },
  shipyard(mb, lm) {
    const { w, d } = lm;
    // 船台斜坡 + 开敞大棚 + 在建船骨
    mb.face('quay', [[-14, 0.05, -d / 2], [14, 0.05, -d / 2], [14, -4, d / 2 + 30], [-14, -4, d / 2 + 30]], [0.8, 0.78, 0.72], [0, 1, 0], (p) => [p[0] / 5, p[2] / 5]);
    for (const sx of [-1, 1]) for (let z = -d / 2; z < d / 2; z += 10) mb.box('wood', sx * 15, 0, z, 1, 18, 1, C.wood);
    mb.face('roof_tile', [[-17, 18, -d / 2], [0, 25, -d / 2], [0, 25, d / 2], [-17, 18, d / 2]], C.slate, [-1, 1, 0], (p) => [p[2] / 3, p[1] / 3]);
    mb.face('roof_tile', [[17, 18, -d / 2], [0, 25, -d / 2], [0, 25, d / 2], [17, 18, d / 2]], C.slate, [1, 1, 0], (p) => [p[2] / 3, p[1] / 3]);
    for (let z = -d / 2 + 8; z < d / 2 - 6; z += 3) { const t = Math.sin(Math.PI * (z + d / 2) / d); arcRib(mb, 0, 2, z, 5 * t + 1, 6 * t + 1); }
    mb.box('wood', 0, 1, 0, 1.2, 1.4, d - 12, C.wood);
    // 起重机
    mb.box('steel_red', -w / 2 + 6, 0, -10, 1.4, 26, 1.4, [1, 1, 1]);
    mb.box('steel_red', -w / 2 + 14, 25, -10, 18, 1.2, 1.2, [1, 1, 1]);
  },
  gatebridge(mb, lm) {
    // 参考图3：跨街拱桥门楼 + 顶部钟
    const span = lm.w - 12;
    for (const sx of [-1, 1]) {
      const x = sx * (lm.w / 2 - 6);
      tower(mb, x, 0, 12, 0, 30, { cap: 'dome', fac: 'fac_haus' });
    }
    const y0 = 13, th = 6, dz = lm.d;
    // 拱
    const seg = 20, r = span / 2;
    for (let i = 0; i < seg; i++) {
      const a0 = Math.PI * i / seg, a1 = Math.PI * (i + 1) / seg;
      const p = (a, zz, off = 0) => [Math.cos(a) * (r + off), 2 + Math.sin(a) * (y0 - 2) / 1 * 0.95 + 0, zz];
      for (const zz of [dz / 2, -dz / 2]) {
        const s = zz > 0 ? 1 : -1;
        mb.face('fac_haus', [p(a0, zz), p(a1, zz), [Math.cos(a1) * r, y0 + th, zz], [Math.cos(a0) * r, y0 + th, zz]], C.white, [0, 0, s], (q) => [q[0] / 7.2, q[1] / 7.6]);
      }
      mb.face('trim', [p(a0, dz / 2), p(a1, dz / 2), p(a1, -dz / 2), p(a0, -dz / 2)], C.stoneD, [-Math.cos((a0 + a1) / 2), -1, 0]);
      mb.face('trim', [p(a0, dz / 2 + 0.3, 1.2), p(a1, dz / 2 + 0.3, 1.2), p(a1, dz / 2 + 0.3), p(a0, dz / 2 + 0.3)], C.trim, [0, 0, 1]);
    }
    mb.box('trim', 0, y0 + th, 0, span + 2, 0.8, dz + 1.2, C.trim);
    // 顶部回廊栏杆 + 中央钟亭
    for (const zz of [dz / 2 + 0.4, -dz / 2 - 0.4]) mb.strip('balus', [-span / 2, zz], [span / 2, zz], y0 + th + 0.8, y0 + th + 0.8, 1.2, C.white, 1.2);
    const cy = y0 + th + 0.8;
    mb.box('trim', 0, cy, 0, 12, 8, 6, C.white);
    pedimentCurve(mb, 0, cy + 8, 3.05, 6.5);
    clockFace(mb, 0, cy + 5, 3.05, 2.6, [0, 1]);
    clockFace(mb, 0, cy + 5, -3.05, 2.6, [0, -1]);
    for (const sx of [-1, 1]) mb.cyl('gold', sx * 5.6, cy + 8, 0, 0.6, 0.1, 2.5, 8, C.gold);
  },
  gate(mb, lm) {
    // 城门：双圆塔 + 门洞，正面朝城外
    for (const sx of [-1, 1]) {
      mb.cyl('ashlar', sx * 15, -6, 0, 7, 6.4, 34, 16, [1, 1, 1], { uRep: 8, vScale: 4 });
      mb.cyl('trim', sx * 15, 28, 0, 7.4, 7.4, 1.2, 16, C.trim, { top: true });
      mb.cyl('roof_slate', sx * 15, 29.2, 0, 7.6, 0, 11, 16, C.slate);
      mb.cyl('gold', sx * 15, 40, 0, 0.15, 0.05, 3, 6, C.gold);
    }
    mb.box('ashlar', 0, 12, 0, 24, 10, lm.d, [1, 1, 1], 0, { uv: [4, 4] });
    for (let x = -8; x <= 8; x += 2.4) mb.box('ashlar', x, 22, lm.d / 2 - 0.6, 1.4, 1.6, 1.2, [1, 1, 1]);
    banner(mb, 0, 20, lm.d / 2 + 0.3, 3.4, 7, C.blue);
  },
};

export function gable(mb, P, y0, rise, mat, col, overhang = false) {
  // P 为矩形（4 点），屋脊沿较长边
  const [a, b, c, d] = P;
  const L1 = Math.hypot(b[0] - a[0], b[1] - a[1]), L2 = Math.hypot(c[0] - b[0], c[1] - b[1]);
  const [p0, p1, p2, p3] = L1 >= L2 ? [a, b, c, d] : [b, c, d, a];
  const m0 = [(p0[0] + p3[0]) / 2, (p0[1] + p3[1]) / 2], m1 = [(p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2];
  const o = overhang ? 0.6 : 0.3;
  const ext = (p, m) => [p[0] + (p[0] - m[0]) / Math.hypot(p[0] - m[0], p[1] - m[1]) * o, p[1] + (p[1] - m[1]) / Math.hypot(p[0] - m[0], p[1] - m[1]) * o];
  const q0 = ext(p0, m0), q1 = ext(p1, m1), q2 = ext(p2, m1), q3 = ext(p3, m0);
  const yE = y0 - o * rise / (Math.hypot(p0[0] - m0[0], p0[1] - m0[1]));
  const sl = (p) => [p[0] / 3, p[2] / 3 + p[1] / 3];
  mb.face(mat, [[q0[0], yE, q0[1]], [q1[0], yE, q1[1]], [m1[0], y0 + rise, m1[1]], [m0[0], y0 + rise, m0[1]]], col, [q0[0] - m0[0], 1, q0[1] - m0[1]], sl);
  mb.face(mat, [[q3[0], yE, q3[1]], [q2[0], yE, q2[1]], [m1[0], y0 + rise, m1[1]], [m0[0], y0 + rise, m0[1]]], col, [q3[0] - m0[0], 1, q3[1] - m0[1]], sl);
  mb.face('trim', [[p0[0], y0, p0[1]], [p3[0], y0, p3[1]], [m0[0], y0 + rise, m0[1]]], C.white, [m0[0] - m1[0], 0, m0[1] - m1[1]]);
  mb.face('trim', [[p1[0], y0, p1[1]], [p2[0], y0, p2[1]], [m1[0], y0 + rise, m1[1]]], C.white, [m1[0] - m0[0], 0, m1[1] - m0[1]]);
}
function rose(mb, x, y, z, r) {
  for (let i = 0; i < 24; i++) {
    const a0 = (i / 24) * Math.PI * 2, a1 = ((i + 1) / 24) * Math.PI * 2;
    mb.face('glass_lit', [[x, y, z], [x + Math.cos(a0) * r, y + Math.sin(a0) * r, z], [x + Math.cos(a1) * r, y + Math.sin(a1) * r, z]], i % 2 ? [0.5, 0.6, 1] : [1, 0.6, 0.5], [0, 0, 1]);
    mb.face('trim', [[x + Math.cos(a0) * r, y + Math.sin(a0) * r, z + 0.1], [x + Math.cos(a0) * (r + 0.8), y + Math.sin(a0) * (r + 0.8), z + 0.1], [x + Math.cos(a1) * (r + 0.8), y + Math.sin(a1) * (r + 0.8), z + 0.1], [x + Math.cos(a1) * r, y + Math.sin(a1) * r, z + 0.1]], C.trim, [0, 0, 1]);
  }
}
function pedimentCurve(mb, x, y, z, w) {
  for (let i = 0; i < 10; i++) {
    const a0 = Math.PI * i / 10, a1 = Math.PI * (i + 1) / 10;
    mb.face('trim', [[x, y, z], [x + Math.cos(a0) * w / 2, y + Math.sin(a0) * 2.2, z], [x + Math.cos(a1) * w / 2, y + Math.sin(a1) * 2.2, z]], C.trim, [0, 0, 1]);
  }
}
export function ring(mb, x, y, z, R, r, mat, col) {
  const seg = 32, sides = 6;
  for (let i = 0; i < seg; i++) for (let j = 0; j < sides; j++) {
    const a0 = i / seg * Math.PI * 2, a1 = (i + 1) / seg * Math.PI * 2, b0 = j / sides * Math.PI * 2, b1 = (j + 1) / sides * Math.PI * 2;
    const p = (a, b) => [x + Math.cos(a) * (R + Math.cos(b) * r), y + Math.sin(b) * r, z + Math.sin(a) * (R + Math.cos(b) * r)];
    const nrm = (a, b) => [Math.cos(a) * Math.cos(b), Math.sin(b), Math.sin(a) * Math.cos(b)];
    mb.quad(mat, p(a0, b0), p(a1, b0), p(a1, b1), p(a0, b1), null, col, [nrm(a0, b0), nrm(a1, b0), nrm(a1, b1), nrm(a0, b1)]);
  }
}
function arcRib(mb, x, y, z, w, h) {
  for (let i = 0; i < 8; i++) {
    const a0 = Math.PI * i / 8, a1 = Math.PI * (i + 1) / 8;
    mb.strip('wood', [x + Math.cos(a0) * w, z], [x + Math.cos(a1) * w, z], y + h - Math.sin(a0) * h, y + h - Math.sin(a1) * h, 0.4, C.wood, 1);
  }
}
export function banner(mb, x, y, z, w, h, col) {
  mb.face('cloth', [[x - w / 2, y, z], [x + w / 2, y, z], [x + w / 2, y - h, z], [x, y - h - 1, z], [x - w / 2, y - h, z]], col, [0, 0, 1]);
  mb.face('cloth', [[x - w / 2, y, z - 0.02], [x + w / 2, y, z - 0.02], [x + w / 2, y - h, z - 0.02], [x, y - h - 1, z - 0.02], [x - w / 2, y - h, z - 0.02]], col, [0, 0, -1]);
  mb.box('gold', x, y, z, w + 0.6, 0.2, 0.2, C.gold);
}
export function hangingSign(mb, x, y, z) {
  mb.box('metal', x, y, z + 0.6, 0.12, 0.12, 1.4, C.iron);
  mb.box('wood', x, y - 1.3, z + 1.2, 0.12, 1.2, 1.0, [0.55, 0.36, 0.2]);
}
export function statue(mb, x, y, z, s) {
  mb.box('trim', x, y, z, 2.4 * s, 2.2 * s, 2.4 * s, C.trim);
  const b = y + 2.2 * s;
  mb.cyl('bronze', x, b, z, 0.7 * s, 0.5 * s, 2.8 * s, 8, [1, 1, 1]);
  mb.cyl('bronze', x, b + 2.8 * s, z, 0.32 * s, 0.32 * s, 0.6 * s, 8, [1, 1, 1], { top: true });
}
