// 树木审计：每棵树必须 ① 立在绿地上（行道树草带 / 树池 / 公园草坪 / 合院草坪）；② 树干不压建筑、台阶、桥、大厅坡道、传送石、喷泉、水面、城墙、路灯、别的树；
// ③ 标高与所在地面一致；④ 树冠椭圆（橡树半径 ≈5.4m×缩放×across，松树 4.5m，棕榈 3m）不穿进建筑立面 / 桥面；⑤ 草带 / 树池本身不压台阶、桥、坡道。
// node test_trees.mjs [--verbose]
import * as P from './src/plan.js';
import { inset, pointInPoly } from './src/geo2d.js';
import { obstacles, crownPenetration, crownR0, CROWN, dpoly, bbox4, nearBB } from './src/treefit.js';

const verbose = process.argv.includes('--verbose');
const { solids, walls } = obstacles(P);
const hard = solids.filter((s) => !s.kind.startsWith('lot') && !s.kind.startsWith('landmark'));

// ---- 绿地
const greens = [];
for (const st of P.STRIPS) {
  const d = [st.b[0] - st.a[0], st.b[1] - st.a[1]], L = Math.hypot(d[0], d[1]) || 1, hw = st.w / 2 + 0.05;
  const n = [-d[1] / L * hw, d[0] / L * hw], e = [d[0] / L * 0.2, d[1] / L * 0.2];
  const poly = [[st.a[0] - e[0] + n[0], st.a[1] - e[1] + n[1]], [st.b[0] + e[0] + n[0], st.b[1] + e[1] + n[1]], [st.b[0] + e[0] - n[0], st.b[1] + e[1] - n[1]], [st.a[0] - e[0] - n[0], st.a[1] - e[1] - n[1]]];
  greens.push({ poly, kind: 'strip', bb: bbox4(poly) });
}
for (const b of P.BLOCKS) {
  if (b.use === 'park') { const lawn = inset(b.poly, 5); if (lawn.length) greens.push({ poly: lawn, kind: 'lawn', bb: bbox4(lawn) }); }
  else if (b.use === 'build' && !b.landmarks.length) { const yard = inset(b.poly, 24); if (yard.length) greens.push({ poly: yard, kind: 'yard', bb: bbox4(yard) }); }
}
const groundAt = (x, z) => { const b = P.BLOCKS.find((q) => pointInPoly([x, z], q.poly)); if (b) return b.level + P.CURB; const t = P.terraceAt(x, z); return t ? t.level : null; };

const fails = {};
const note = (cat, t, extra) => { (fails[cat] = fails[cat] || []).push(`(${t.x.toFixed(1)}, ${t.z.toFixed(1)}) ${extra || ''}`); };
const all = [...P.TREES.map((t) => ({ ...t, ptype: 'tree' })), ...P.PALMS.map((t) => ({ ...t, ptype: 'palm', kind: 'palm' }))];
for (const t of all) {
  const p = [t.x, t.z];
  if (!greens.find((q) => nearBB(q.bb, p, 0.1) && pointInPoly(p, q.poly))) note('不在绿地', t, `${t.kind} y=${t.y}`);
  for (const s of solids) { if (!nearBB(s.bb, p, s.m + 0.5)) continue; if (dpoly(p, s.poly) < s.m - 1e-6) { note('树干压实体', t, s.kind); break; } }
  const gy = groundAt(t.x, t.z);
  if (gy === null || Math.abs(gy - t.y) > 0.45) note('标高不符', t, `tree y=${t.y} ground=${gy}`);
  const R0 = t.ptype === 'palm' ? CROWN.palm * (t.s || 1) : crownR0(t);
  const pen = crownPenetration(t, R0 * (t.along ?? 1), R0 * (t.across ?? 1), t.yaw ?? 0, walls);
  if (pen > 0.35) note('树冠穿立面', t, `穿入 ${pen.toFixed(2)}m across=${t.across ?? 1}`);
  // 台地边缘：树池 / 台地树离台地边至少 2m（不压挡土墙压顶石）
  if (!P.BLOCKS.some((q) => pointInPoly(p, q.poly))) {
    const tr = P.terraceAt(t.x, t.z);
    if (tr && !tr.outer && dpoly(p, tr.poly) === 0) {
      let m = 1e9; for (let i = 0; i < tr.poly.length; i++) { const a = tr.poly[i], b = tr.poly[(i + 1) % tr.poly.length]; const dx = b[0] - a[0], dz = b[1] - a[1]; let u = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz || 1); u = Math.max(0, Math.min(1, u)); m = Math.min(m, Math.hypot(p[0] - a[0] - u * dx, p[1] - a[1] - u * dz)); }
      if (m < 2.0) note('近台地边', t, `${m.toFixed(1)}m 台地 ${tr.id}`);
    }
  }
}
// 树间距 / 树与路灯
{
  const cell = new Map(), key = (x, z) => Math.floor(x / 8) + ',' + Math.floor(z / 8);
  all.forEach((t, i) => { const k = key(t.x, t.z); if (!cell.has(k)) cell.set(k, []); cell.get(k).push(i); });
  all.forEach((t, i) => { const cx = Math.floor(t.x / 8), cz = Math.floor(t.z / 8); for (let a = -1; a <= 1; a++) for (let b = -1; b <= 1; b++) for (const j of cell.get((cx + a) + ',' + (cz + b)) || []) { if (j <= i) continue; const d = Math.hypot(all[j].x - t.x, all[j].z - t.z); if (d < (t.ptype === 'palm' || all[j].ptype === 'palm' ? 4.0 : 5.0) - 1e-6) note('树与树过近', t, `${d.toFixed(1)}m`); } });
  for (const t of all) for (const l of P.LAMPS) { if (Math.abs(t.x - l.x) > 1.6 || Math.abs(t.z - l.z) > 1.6) continue; if (Math.hypot(t.x - l.x, t.z - l.z) < 1.4) note('树压路灯', t, `灯 (${l.x.toFixed(1)}, ${l.z.toFixed(1)})`); }
}
// 草带 / 树池本身不许压台阶、桥、坡道、传送石、水面……
for (const st of P.STRIPS) {
  const dx = st.b[0] - st.a[0], dz = st.b[1] - st.a[1], L = Math.hypot(dx, dz), m = 0.4 + st.w / 2 - 0.15;
  for (let u = 0; u <= L; u += 0.5) {
    const p = [st.a[0] + dx / L * u, st.a[1] + dz / L * u];
    const hit = hard.find((s) => nearBB(s.bb, p, m + 0.2) && dpoly(p, s.poly) < m);
    if (hit) { note('草带压实体', { x: p[0], z: p[1] }, hit.kind); break; }
  }
}

let bad = 0;
console.log(`树 ${P.TREES.length} + 棕榈 ${P.PALMS.length}，草带/树池 ${P.STRIPS.length}，绿地 ${greens.length}，实体 ${solids.length}，立面 ${walls.length}`);
console.log('整饬统计', JSON.stringify(P.TREE_FIT));
for (const [k, v] of Object.entries(fails)) { bad += v.length; console.log(`FAIL ${k}: ${v.length}`); for (const s of v.slice(0, verbose ? 400 : 8)) console.log('   ', s); }
console.log(bad ? `TREES RESULT: ${bad} 项问题` : 'TREES RESULT: ALL PASS');
process.exit(bad ? 1 : 0);
