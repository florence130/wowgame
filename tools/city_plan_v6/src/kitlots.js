// 沿街楼模块化装配：把规划里的地块（LOTS）按 street_kit 构件（assets/models/street_kit/sk_*.glb）摆成一栋栋楼，
// 输出给游戏端 CityKitLots（MultiMesh 合批）。构件按墙边摆：x 沿墙、外立面朝外、屋面 / 山墙原点在墙顶。
// 两条路径：
//   · 规则四边形（临街边 = 第 0 条边）：整数开间立面 + 双坡屋面 / 芒萨尔；
//   · 街角楼（6 / 7 边形切角楼、直角街角）：逐边装配——临街边（含切角斜边）是商铺 / 拱窗 / 拱门底层 + 上层立面，
//     其余边是侧 / 背墙；屋顶沿每条边铺斜接屋面裙边（转角 90° / 135° 各有斜接构件），中间封顶（芒萨尔平顶 / 四坡锥顶）。
import { norm, sub, add, mul, dist, rng, inset, centroid } from './geo2d.js';
import { outward } from './landmarks.js';
import { BLOCKS, ROAD } from './plan.js';

export const BAY = 4.4, GF = 5.6, FH = 4.4, DN = 14.0, T = 0.3;
const RN = DN / 2 * Math.tan(38 * Math.PI / 180);
export const PIECES = ['sk_gf_shop', 'sk_gf_arch', 'sk_gf_door', 'sk_gf_solid', 'sk_uf_half', 'sk_uf_plain', 'sk_uf_brick', 'sk_uf_balc', 'sk_uf_blank', 'sk_uf_side',
  'sk_band', 'sk_eave', 'sk_roof_gable', 'sk_gable_end', 'sk_dormer', 'sk_chimney', 'sk_mansard_bay', 'sk_mansard_L90', 'sk_mansard_R90', 'sk_mansard_L135', 'sk_mansard_R135',
  'sk_mansard_dormer', 'sk_roof_flat', 'sk_hip_bay', 'sk_hip_L90', 'sk_hip_R90', 'sk_hip_L135', 'sk_hip_R135'];
const PI = Object.fromEntries(PIECES.map((p, i) => [p, i]));

// ---- 调色板（着色器 inst_pal 下标）：墙 / 红砖 / 屋顶 / 石材线脚 / 点缀
const SEG = {
  plaster: ['f2e9d4', 'ecd9b4', 'efd5c3', 'd7e3d2', 'd2dde9', 'f1e2ac', 'f6f1e6', 'e6c9b8', 'e9dfc9'],
  brick: ['c4694d', 'b85d44', 'cf7a58', 'a9503b', 'c27355'],
  tile: ['b8553f', 'c4693f', 'a8463a', 'c0603f', 'b04c3b'],
  slate: ['566b92', '4a5f86', '5d6f8a', '6b7a90', '50648a'],
  copper: ['5a9886', '4f8f7d', '67a08c'],
  violet: ['6e5aa6', '7c64ad', '5f4f98'],
  trim: ['ece6d6', 'e0d8c4', 'f1ece0', 'd6cdb8'],
  stone: ['d9cfba', 'cdc3ac', 'e0d7c2', 'c4b9a2'],
  acc: ['4f7a63', '4c6b8a', 'a34a3a', 'c79a3c', '6b4630', '3f7f86', '8a4f6d', '5b7f3f'],
};
export const PALETTE = [];
const OFF = {};
for (const [k, arr] of Object.entries(SEG)) { OFF[k] = [PALETTE.length, arr.length]; PALETTE.push(...arr); }
const pick = (R, seg) => OFF[seg][0] + Math.floor(R() * OFF[seg][1]);

// ---- 各区风格
const RECIPE = {
  core: { roof: 'mansard', up: ['plain', 'balc'], wall: 'plaster', rf: 'slate' },
  trade: { roof: 'mansard', up: ['balc', 'plain'], wall: 'plaster', rf: 'slate' },
  artisan: { roof: 'gable', up: ['brick'], wall: 'brick', rf: 'tile' },
  hero: { roof: 'mansard', up: ['plain', 'balc'], wall: 'plaster', rf: 'slate' },
  academy: { roof: 'mansard', up: ['plain', 'plain'], wall: 'plaster', rf: 'copper' },
  palace: { roof: 'mansard', up: ['plain', 'balc'], wall: 'plaster', rf: 'copper' },
  cape: { roof: 'gable', up: ['plain', 'half'], wall: 'plaster', rf: 'slate' },
  harbor: { roof: 'gable', up: ['half', 'plain'], wall: 'plaster', rf: 'tile' },
  station: { roof: 'mansard', up: ['brick', 'plain'], wall: 'brick', rf: 'slate' },
  park: { roof: 'gable', up: ['half'], wall: 'plaster', rf: 'tile' },
  royal: { roof: 'mansard', up: ['plain', 'balc'], wall: 'plaster', rf: 'copper' },
  mage: { roof: 'mansard', up: ['plain', 'balc'], wall: 'plaster', rf: 'violet' },
  oldtown: { roof: 'gable', up: ['half'], wall: 'plaster', rf: 'tile' },
  military: { roof: 'gable', up: ['plain'], wall: 'plaster', rf: 'slate' },
};

// ---------------------------------------------------------------- 地块几何：临街边判定、转角
const BLK = Object.fromEntries(BLOCKS.map((b) => [b.id, b]));
const dseg = (p, a, b) => { const dx = b[0] - a[0], dz = b[1] - a[1]; let t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz || 1); t = Math.max(0, Math.min(1, t)); return Math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dz); };
/** 每条边是否临街：与街区的某条街道边平行且相距≈人行道宽；斜边（切角）若两侧都临街也算（cut=true） */
export function frontInfo(lot) {
  const n = lot.poly.length, b = BLK[lot.block];
  const front = new Array(n).fill(false), cut = new Array(n).fill(false);
  if (!b) return { front, cut };
  for (let i = 0; i < n; i++) {
    const a = lot.poly[i], c = lot.poly[(i + 1) % n], m = [(a[0] + c[0]) / 2, (a[1] + c[1]) / 2];
    for (let j = 0; j < b.poly.length; j++) {
      const code = b.codes[j], sw = ROAD[code]?.sw;
      if (!sw || 'BASLP'.indexOf(code) < 0) continue;
      const e0 = b.poly[j], e1 = b.poly[(j + 1) % b.poly.length];
      const ex = e1[0] - e0[0], ez = e1[1] - e0[1], lx = c[0] - a[0], lz = c[1] - a[1];
      const cs = Math.abs(ex * lx + ez * lz) / Math.hypot(ex, ez) / Math.hypot(lx, lz);
      if (Math.abs(dseg(m, e0, e1) - sw) < 0.8 && cs > 0.97) { front[i] = true; break; }
    }
  }
  // 切角边 = 连续三条临街边的中间一条（块的短街边被两侧街夹住）；两侧都临街的非平行斜边也算临街
  for (let i = 0; i < n; i++) if (!front[i] && front[(i + n - 1) % n] && front[(i + 1) % n]) front[i] = true;
  for (let i = 0; i < n; i++) if (front[i] && front[(i + n - 1) % n] && front[(i + 1) % n]) cut[i] = true;
  return { front, cut };
}
const isRect = (lot) => lot.poly.length === 4 && !lot.corner;
/** 可替换为构件的地块：规则四边形，或有临街边的街角楼（4–7 边，内缩后边数不变） */
export function kitEligible(lot) {
  if (lot.enter) return false;
  const n = lot.poly.length;
  if (n < 4 || n > 7) return false;
  if (isRect(lot)) return true;
  if (inset(lot.poly, T / 2).length !== n) return false;
  return frontInfo(lot).front.some(Boolean);
}

const r3 = (v) => Math.round(v * 1000) / 1000;
const mitreOf = (phi) => (phi >= 160 ? 0 : phi >= 112 ? 135 : 90);       // 0 = 不斜接（近直线）
const area2 = (p) => { let s = 0; for (let i = 0; i < p.length; i++) { const q = p[(i + 1) % p.length]; s += p[i][0] * q[1] - q[0] * p[i][1]; } return s; };

export function buildKitLots(lots) {
  const out = [];       // 每个构件实例 12 个数：piece, x, y, z, yaw, sx, sy, sz, c0..c3
  const caps = [];      // 封顶三角形：每个 10 个数：x,y,z ×3 + 调色板下标（-1 = 锌板）
  const stats = { lots: 0, inst: 0, corner: 0, caps: 0 };
  for (const lot of lots) {
    if (!kitEligible(lot)) continue;
    const st = RECIPE[lot.style] || RECIPE.core;
    const R = rng(lot.seed + 77);
    const y0 = lot.level;
    const brick = st.wall === 'brick';
    const c0 = pick(R, brick ? 'brick' : 'plaster'), c1 = pick(R, st.rf), c2 = pick(R, brick ? 'trim' : 'stone'), c3 = pick(R, 'acc');
    let n = 0;
    const cols = [c0, c1, c2, c3];
    const ufKind = (f) => st.up[f % st.up.length];
    const ufId = (kind) => ({ half: 'sk_uf_half', plain: 'sk_uf_plain', brick: 'sk_uf_brick', balc: 'sk_uf_balc' }[kind]);
    // world 实例：origin = 世界 xz；d = 沿墙单位向量；psi = 偏航
    const emit = (id, wx, wz, bz, psi, ssx, ssy, ssz) => { out.push(PI[id], r3(wx), r3(y0 + bz), r3(wz), r3(psi), r3(ssx), r3(ssz), r3(ssy), ...cols); n++; };

    if (isRect(lot)) {
      // ================= 规则四边形（临街边 = 第 0 条边）
      const mans = st.roof === 'mansard';
      const Pq = lot.fe ? [...lot.poly.slice(lot.fe), ...lot.poly.slice(0, lot.fe)] : lot.poly;
      const outv = outward(Pq, 0);
      let p0 = Pq[0], p1 = Pq[1];
      let d0 = norm(sub(p1, p0));
      if (-d0[1] * outv[0] + d0[0] * outv[1] < 0) { const t = p0; p0 = p1; p1 = t; d0 = [-d0[0], -d0[1]]; }
      const nn = [-outv[0], -outv[1]];
      const psi = Math.atan2(-d0[1], d0[0]);
      const W = dist(p0, p1), D = dist(Pq[1], Pq[2]);
      const Wc = W - T, Dc = D - T;
      const org = add(add(p0, mul(d0, T / 2)), mul(nn, T / 2));
      const nx = Math.max(2, Math.round(Wc / BAY)), bw = Wc / nx, sx = bw / BAY;
      const nz = Math.max(2, Math.round(Dc / BAY)), dbw = Dc / nz, sd = dbw / BAY;
      const nUp = Math.max(0, mans ? lot.floors - 2 : lot.floors - 1);
      const top = GF + nUp * FH;
      const put = (id, bx, by, bz, rot, ssx, ssy, ssz) => emit(id, org[0] + d0[0] * bx + nn[0] * by, org[1] + d0[1] * bx + nn[1] * by, bz, psi + rot, ssx, ssy, ssz);
      const doorI = Math.floor(nx / 2);
      for (let i = 0; i < nx; i++) {
        const gid = lot.shop ? (i === doorI && nx > 3 ? 'sk_gf_door' : 'sk_gf_shop') : (i === doorI ? 'sk_gf_door' : 'sk_gf_arch');
        put(gid, i * bw, 0, 0, 0, sx, 1, 1);
        for (let f = 0; f < nUp; f++) {
          const z = GF + f * FH;
          put('sk_band', i * bw, 0, z - 0.1, 0, sx, 1, 1);
          let kind = ufKind(f);
          if (kind === 'balc' && i % 2 === 0) kind = brick ? 'brick' : 'plain';
          put(ufId(kind), i * bw, 0, z, 0, sx, 1, 1);
        }
        put('sk_eave', i * bw, 0, top - 0.4, 0, sx, 1, 1);
      }
      const side = (xf, count, sc) => {
        for (let j = 0; j < count; j++) {
          const [bx, by, rot] = xf(j);
          put('sk_gf_solid', bx, by, 0, rot, sc, 1, 1);
          for (let f = 0; f < nUp; f++) put((j + f) % 2 === 0 ? 'sk_uf_side' : 'sk_uf_blank', bx, by, GF + f * FH, rot, sc, 1, 1);
          if (mans) put('sk_eave', bx, by, top - 0.4, rot, sc, 1, 1);
        }
      };
      side((j) => [0, (j + 1) * dbw, -Math.PI / 2], nz, sd);
      side((j) => [Wc, j * dbw, Math.PI / 2], nz, sd);
      side((j) => [Wc - j * bw, Dc, Math.PI], nx, sx);
      if (!mans) {
        const s = Dc / DN;
        for (let i = 0; i < nx; i++) put('sk_roof_gable', i * bw, 0, top, 0, sx, s, s);
        put('sk_gable_end', 0, 0, top, 0, 1, s, s);
        put('sk_gable_end', Wc, Dc, top, Math.PI, 1, s, s);
        const yn = 2.6, zn = -0.55 + (yn - (-0.75)) / (DN / 2 + 0.75) * (RN + 0.55);
        if (lot.floors >= 3) for (let i = 1; i < nx; i += 2) put('sk_dormer', i * bw + bw / 2, yn * s, top + zn * s - 0.2, 0, 1, 1, 1);
        put('sk_chimney', Wc * (0.3 + R() * 0.4), Dc * 0.5, top + RN * s - 1.1, 0, 1, 1, 1);
      } else {
        for (let j = 0; j < nx; j++) {
          put(j === 0 ? 'sk_mansard_L90' : j === nx - 1 ? 'sk_mansard_R90' : 'sk_mansard_bay', j * bw, 0, top, 0, sx, 1, 1);
          if (j % 2 === 1) put('sk_mansard_dormer', j * bw + bw / 2, 0.15, top + 1.0, 0, 1, 1, 1);
        }
        for (let j = 0; j < nz; j++) {
          put(j === nz - 1 ? 'sk_mansard_L90' : j === 0 ? 'sk_mansard_R90' : 'sk_mansard_bay', 0, (j + 1) * dbw, top, -Math.PI / 2, sd, 1, 1);
          put(j === 0 ? 'sk_mansard_L90' : j === nz - 1 ? 'sk_mansard_R90' : 'sk_mansard_bay', Wc, j * dbw, top, Math.PI / 2, sd, 1, 1);
        }
        for (let j = 0; j < nx; j++) put(j === 0 ? 'sk_mansard_L90' : j === nx - 1 ? 'sk_mansard_R90' : 'sk_mansard_bay', Wc - j * bw, Dc, top, Math.PI, sx, 1, 1);
        // 顶面：内缩 1.55m 的矩形，扇形拆成两个三角（锌板）
        const q = [[1.55, 1.55], [Wc - 1.55, 1.55], [Wc - 1.55, Dc - 1.55], [1.55, Dc - 1.55]].map(([bx, by]) => [org[0] + d0[0] * bx + nn[0] * by, org[1] + d0[1] * bx + nn[1] * by]);
        const yy = y0 + top + 3.9 - 0.02;
        for (const [a, b, c] of [[0, 1, 2], [0, 2, 3]]) { caps.push(q[a][0], yy, q[a][1], q[b][0], yy, q[b][1], q[c][0], yy, q[c][1], -1); stats.caps++; }
      }
    } else {
      // ================= 街角楼：逐边装配
      stats.corner++;
      const pn = lot.poly.length;
      const Pi = inset(lot.poly, T / 2);
      const { front, cut } = frontInfo(lot);
      const ccw = area2(Pi) > 0;
      void ccw;
      // 室内夹角（凸多边形）
      const phi = Pi.map((v, i) => {
        const u = Pi[(i + pn - 1) % pn], w = Pi[(i + 1) % pn];
        const a1 = Math.atan2(u[1] - v[1], u[0] - v[0]), a2 = Math.atan2(w[1] - v[1], w[0] - v[0]);
        let d = Math.abs(a1 - a2) * 180 / Math.PI; if (d > 180) d = 360 - d;
        return d;
      });
      const hip = st.roof === 'gable';                               // 山墙区的街角楼用四坡屋面
      const mans = !hip;
      const nUp = Math.max(0, mans ? lot.floors - 2 : lot.floors - 1);
      const top = GF + nUp * FH;
      const rh = hip ? 3.0 : 3.9, ri = hip ? 3.0 : 1.55;             // 屋面裙边高 / 顶部内收
      const rk = hip ? 'sk_hip' : 'sk_mansard';
      // 最长的临街边放大门（街角楼的正门在切角斜边）
      const cutI = cut.findIndex(Boolean);
      let doorEdge = cutI;
      if (doorEdge < 0) { let best = -1; for (let i = 0; i < pn; i++) if (front[i]) { const L = dist(Pi[i], Pi[(i + 1) % pn]); if (L > best) { best = L; doorEdge = i; } } }
      for (let i = 0; i < pn; i++) {
        const j = (i + 1) % pn;
        let a = Pi[i], b = Pi[j], va = i, vb = j;
        const o = outward(lot.poly, i);
        let d = norm(sub(b, a));
        if (-d[1] * o[0] + d[0] * o[1] < 0) { const t = a; a = b; b = t; d = [-d[0], -d[1]]; va = j; vb = i; }
        const L = dist(a, b);
        const psi = Math.atan2(-d[1], d[0]);
        const place = (id, bx, bz, ssx = 1, rot = 0) => emit(id, a[0] + d[0] * bx, a[1] + d[1] * bx, bz, psi + rot, ssx, 1, 1);
        const isFront = front[i];
        const nb = L < 2.6 ? 0 : Math.max(1, Math.round(L / BAY)), bw = nb ? L / nb : 0, sx = bw / BAY;
        for (let k = 0; k < nb; k++) {
          const isDoor = i === doorEdge && k === Math.floor(nb / 2) && (nb > 1 || cut[i]);
          if (isFront) {
            const gid = isDoor ? 'sk_gf_door' : lot.shop ? 'sk_gf_shop' : 'sk_gf_arch';
            place(gid, k * bw, 0, sx);
          } else place('sk_gf_solid', k * bw, 0, sx);
          for (let f = 0; f < nUp; f++) {
            const z = GF + f * FH;
            if (isFront) {
              place('sk_band', k * bw, z - 0.1, sx);
              let kind = cut[i] && f === 0 ? 'balc' : ufKind(f);
              if (kind === 'balc' && !cut[i] && k % 2 === 0) kind = brick ? 'brick' : 'plain';
              place(ufId(kind), k * bw, z, sx);
            } else place((k + f) % 2 === 0 ? 'sk_uf_side' : 'sk_uf_blank', k * bw, z, sx);
          }
          place('sk_eave', k * bw, top - 0.4, sx);
        }
        // 屋面裙边：自己的开间数（≥2，两端各一件斜接件），不依赖墙的开间
        if (L >= 1.2) {
          const nr = Math.max(2, Math.round(L / BAY)), rw = L / nr, rsx = rw / BAY;
          const ma = mitreOf(phi[va]), mb2 = mitreOf(phi[vb]);
          for (let k = 0; k < nr; k++) {
            let id = rk + '_bay';
            if (k === 0 && ma) id = `${rk}_L${ma}`;
            else if (k === nr - 1 && mb2) id = `${rk}_R${mb2}`;
            place(id, k * rw, top, rsx);
            if (mans && isFront && k % 2 === 1 && rw > 2.8) place('sk_mansard_dormer', k * rw + rw / 2, top + 1.0, 1, 0);
          }
        }
      }
      // 封顶：屋面裙边顶沿内缩 ri，芒萨尔 = 平顶锌板；四坡 = 向中心升起的锥顶（陶瓦，调色板色同屋面）
      const cap = inset(Pi, ri);
      if (cap.length >= 3) {
        const cc = centroid(cap);
        let rad = 1e9;
        for (let i = 0; i < cap.length; i++) rad = Math.min(rad, dseg(cc, cap[i], cap[(i + 1) % cap.length]));
        const yb = y0 + top + rh - 0.02;
        const apex = hip ? yb + Math.max(0.6, rad * Math.tan(34 * Math.PI / 180)) : yb;
        for (let i = 0; i < cap.length; i++) {
          const q0 = cap[i], q1 = cap[(i + 1) % cap.length];
          caps.push(q0[0], yb, q0[1], q1[0], yb, q1[1], cc[0], apex, cc[1], hip ? c1 : -1); stats.caps++;
        }
        if (hip) {
          // 烟囱：落在锥顶一侧
          const q = cap[0];
          emit('sk_chimney', (q[0] * 0.55 + cc[0] * 0.45), (q[1] * 0.55 + cc[1] * 0.45), top + rh + 0.2, 0, 1, 1, 1);
        }
      }
    }
    stats.lots++; stats.inst += n;
  }
  return { data: Float32Array.from(out), caps: Float32Array.from(caps), stats };
}
