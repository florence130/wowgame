// 导出给 Godot：assets/models/city_v7/chunk_I_J.glb（视觉网格 + "col-colonly" 碰撞）+ docs/city_v7/game.json
// node export_game.mjs
import { writeFile, mkdir, readdir, unlink } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { MB } from './src/mb.js';
import { pointInPoly } from './src/geo2d.js';
import { buildGeometry } from './src/build.js';
import { buildCollision } from './src/collide.js';
import * as P from './src/plan.js';
import { groundAt, blocked } from './src/walk.js';
import { buildKitLots, PIECES, PALETTE } from './src/kitlots.js';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const OUT = resolve(root, 'assets/models/city_v7');
const DOC = resolve(root, 'docs/city_v7');
await mkdir(OUT, { recursive: true }); await mkdir(DOC, { recursive: true });
for (const f of await readdir(OUT)) if (f.startsWith('chunk_') && f.endsWith('.glb')) await unlink(resolve(OUT, f));

const vis = new MB(); buildGeometry(vis, { game: true, kitLandmarks: true, kitLots: true });
const col = new MB(); buildCollision(col);
const CH = 200;
const chunks = new Map();
for (const [mbName, mb] of [['vis', vis], ['col', col]]) {
  for (const [k, o] of mb.b) {
    const ck = k.split('|')[1];
    if (!chunks.has(ck)) chunks.set(ck, { vis: [], col: [] });
    chunks.get(ck)[mbName].push(o);
  }
}

function glb(nodes) {
  // nodes: [{ name, prims: [{ mat, p, n, u, c }] }]
  const bins = [], json = { asset: { version: '2.0', generator: 'city_plan_v6/export_game' }, scene: 0, scenes: [{ nodes: [] }], nodes: [], meshes: [], materials: [], accessors: [], bufferViews: [], buffers: [] };
  let off = 0;
  const matIdx = new Map();
  const view = (arr, target) => {
    const buf = Buffer.from(new Float32Array(arr).buffer);
    json.bufferViews.push({ buffer: 0, byteOffset: off, byteLength: buf.length, target });
    bins.push(buf); off += buf.length;
    const pad = (4 - (off % 4)) % 4; if (pad) { bins.push(Buffer.alloc(pad)); off += pad; }
    return json.bufferViews.length - 1;
  };
  const acc = (arr, type, comps, minmax) => {
    const bv = view(arr, 34962);
    const a = { bufferView: bv, componentType: 5126, count: arr.length / comps, type };
    if (minmax) {
      const mn = [Infinity, Infinity, Infinity], mx = [-Infinity, -Infinity, -Infinity];
      for (let i = 0; i < arr.length; i += 3) for (let k = 0; k < 3; k++) { mn[k] = Math.min(mn[k], arr[i + k]); mx[k] = Math.max(mx[k], arr[i + k]); }
      a.min = mn; a.max = mx;
    }
    json.accessors.push(a); return json.accessors.length - 1;
  };
  for (const nd of nodes) {
    if (!nd.prims.length) continue;
    const prims = [];
    for (const pr of nd.prims) {
      const attrs = { POSITION: acc(pr.p, 'VEC3', 3, true), NORMAL: acc(pr.n, 'VEC3', 3) };
      if (pr.u) attrs.TEXCOORD_0 = acc(pr.u, 'VEC2', 2);
      if (pr.c) attrs.COLOR_0 = acc(pr.c, 'VEC3', 3);
      const prim = { attributes: attrs, mode: 4 };
      if (pr.mat) {
        if (!matIdx.has(pr.mat)) { json.materials.push({ name: 'C7_' + pr.mat, pbrMetallicRoughness: { baseColorFactor: [1, 1, 1, 1], metallicFactor: 0, roughnessFactor: 0.9 } }); matIdx.set(pr.mat, json.materials.length - 1); }
        prim.material = matIdx.get(pr.mat);
      }
      prims.push(prim);
    }
    json.meshes.push({ name: nd.name, primitives: prims });
    json.nodes.push({ name: nd.name, mesh: json.meshes.length - 1 });
    json.scenes[0].nodes.push(json.nodes.length - 1);
  }
  const bin = Buffer.concat(bins);
  json.buffers.push({ byteLength: bin.length });
  let js = Buffer.from(JSON.stringify(json));
  const jpad = (4 - (js.length % 4)) % 4; js = Buffer.concat([js, Buffer.alloc(jpad, 0x20)]);
  const header = Buffer.alloc(12); header.writeUInt32LE(0x46546c67, 0); header.writeUInt32LE(2, 4); header.writeUInt32LE(12 + 8 + js.length + 8 + bin.length, 8);
  const jh = Buffer.alloc(8); jh.writeUInt32LE(js.length, 0); jh.writeUInt32LE(0x4e4f534a, 4);
  const bh = Buffer.alloc(8); bh.writeUInt32LE(bin.length, 0); bh.writeUInt32LE(0x004e4942, 4);
  return Buffer.concat([header, jh, js, bh, bin]);
}
// 细节层：不投影、远处不画（游戏端 CityMat.apply 按节点名处理）
const DETAIL = new Set(['balus', 'iron', 'awning', 'glow_lamp', 'metal', 'gold', 'bronze', 'cloth', 'wood', 'clock', 'glass', 'glass_lit', 'steel_red']);
const rel = (arr, cx, cz) => { const o = new Array(arr.length); for (let i = 0; i < arr.length; i += 3) { o[i] = arr[i] - cx; o[i + 1] = arr[i + 1]; o[i + 2] = arr[i + 2] - cz; } return o; };

const chunkList = [];
let tris = 0, colTris = 0;
const mats = new Set();
for (const [ck, g] of chunks) {
  const [i, j] = ck.split('_').map(Number);
  const cx = (i + 0.5) * CH, cz = (j + 0.5) * CH;
  let ymin = Infinity, ymax = -Infinity, xmin = Infinity, xmax = -Infinity, zmin = Infinity, zmax = -Infinity;
  const prims = g.vis.map((o) => { mats.add(o.mat.replace(/^LF:/, '')); tris += o.p.length / 9; for (let k = 0; k < o.p.length; k += 3) { xmin = Math.min(xmin, o.p[k]); xmax = Math.max(xmax, o.p[k]); ymin = Math.min(ymin, o.p[k + 1]); ymax = Math.max(ymax, o.p[k + 1]); zmin = Math.min(zmin, o.p[k + 2]); zmax = Math.max(zmax, o.p[k + 2]); } return { mat: o.mat.replace(/^LF:/, ''), far: o.mat.startsWith('LF:'), p: rel(o.p, cx, cz), n: o.n, u: o.u, c: o.c }; });
  const colP = [], colN = [];
  for (const o of g.col) { colTris += o.p.length / 9; colP.push(...rel(o.p, cx, cz)); colN.push(...o.n); }
  const file = `chunk_${i}_${j}.glb`;
  await writeFile(resolve(OUT, file), glb([{ name: 'vis', prims: prims.filter((p) => !p.far && !DETAIL.has(p.mat)) }, { name: 'detail', prims: prims.filter((p) => !p.far && DETAIL.has(p.mat)) }, { name: 'lotfar', prims: prims.filter((p) => p.far) }, { name: 'col-colonly', prims: colP.length ? [{ mat: null, p: colP, n: colN }] : [] }]));
  chunkList.push({ file, x: cx, z: cz, size: [Math.max(1, xmax - xmin), Math.max(1, ymax - ymin), Math.max(1, zmax - zmin)] });
}

// 模块化沿街楼：street_kit 构件摆放表（游戏端 CityKitLots 读取，MultiMesh 合批）
{
  const kdir = resolve(root, 'assets/models/street_kit');
  await mkdir(kdir, { recursive: true });
  const { data, caps, stats } = buildKitLots(P.LOTS);
  await writeFile(resolve(kdir, 'kit_lots.bin'), Buffer.from(data.buffer, data.byteOffset, data.byteLength));
  await writeFile(resolve(kdir, 'kit_caps.bin'), Buffer.from(caps.buffer, caps.byteOffset, caps.byteLength));
  await writeFile(resolve(kdir, 'kit_lots.json'), JSON.stringify({ stride: 12, count: data.length / 12, pieces: PIECES, palette: PALETTE.map((h) => '#' + h), lots: stats.lots, caps: caps.length / 10 }, null, 1));
  console.log('KIT LOTS', stats.lots, 'lots', stats.inst, 'instances');
}

const r2 = (v) => Math.round(v * 100) / 100;
// 地标局部坐标（x 横向，z 朝正面）：门洞、大厅、台基、台阶坡道，供 Blender 地标拼装器对齐（tools/blender/city_kit/landmarks_build.py）
function toLocal(l, p) { const c = Math.cos(l.yaw), s = Math.sin(l.yaw), dx = p[0] - l.x, dz = p[1] - l.z; return [r2(c * dx - s * dz), r2(s * dx + c * dz)]; }
function enterLocal(l) {
  const h = l.enter, sp = h.sp, base = l.level;
  return { floor: r2(h.floor - base), ceil: r2(h.ceil - base), doorZ: r2(sp.doorZ), dw: r2(sp.dw), dh: r2(sp.dh), din: r2(sp.din),
    hall: h.hall.map((p) => toLocal(l, p)), solids: (h.solids || []).map((P) => P.map((p) => toLocal(l, p))),
    podium: h.podium ? { y: r2(h.podium.y - base), poly: h.podium.poly.map((p) => toLocal(l, p)) } : null,
    landing: h.landing ? h.landing.map((p) => toLocal(l, p)) : null,
    // jsSteps：这段台阶已由 build.js 的 buildInteriors 画出（拼装器不重复画）
    ramps: h.ramps.map((r) => ({ a: toLocal(l, r.a), b: toLocal(l, r.b), w: r2(r.w), y0: r2(r.y0 - base), y1: r2(r.y1 - base), jsSteps: !!(r.addSteps || (r === h.ramp && sp.addSteps)) })) };
}
const game = {
  version: 7, sea_offset: 8, water_level: 8,
  bounds: { x0: P.EXTENT.x0 - 4, x1: P.CITY_RECT.x1 + 2, z0: P.EXTENT.z0 - 4, z1: P.CITY_RECT.z1 + 150 },
  // 北苑叠园（山坡剖面用）与西侧船只（v7.2 新增的在 index ≥ 8）
  hill: { x: P.HILL.x, zs: P.HILL.zs, levels: P.HILL.levels },
  airships: P.AIRSHIPS.map((a) => ({ x: r2(a.x), z: r2(a.z), y: a.y, len: a.len, moored: !!a.moored, r: a.r || 0, speed: a.speed || 0 })),
  ships: P.SHIPS.map((s) => ({ x: r2(s.x), z: r2(s.z), yaw: r2(s.yaw), len: s.len, kind: s.kind })),
  ks: P.KS,
  levels: P.LV,
  terraces: P.TERRACES.filter((t) => !t.outer).map((t) => ({ id: t.id, level: t.level, poly: t.poly })),
  canals: P.CANALS, basins: P.BASINS.map(({ id, x, z, r, island, level }) => ({ id, x, z, r, island, level })),
  chunks: chunkList, materials: [...mats].sort(),
  npcs: P.NPCS.map((n) => ({ id: n.id, x: r2(n.x), z: r2(n.z), yaw: r2(n.yaw * 180 / Math.PI), y: r2(groundAt(n.x, n.z, 999) ?? P.LV.MID) })),
  pois: P.POIS.map((p) => ({ ...p, x: r2(p.x), z: r2(p.z) })),
  spawns: P.SPAWNS.map((s) => ({ id: s.id, x: r2(s.x), z: r2(s.z), yaw: r2(s.yaw * 180 / Math.PI), y: r2(groundAt(s.x, s.z, 999) ?? P.LV.MID) })),
  gates: P.LANDMARKS.filter((l) => l.type === 'gate').map((l) => ({ id: l.id, x: l.x, z: l.z, yaw: r2(l.yaw * 180 / Math.PI), w: l.w })),
  // [x, z, y, 缩放, 种类, 朝向 yaw, 沿街冠幅系数, 垂街冠幅系数]：树冠避让建筑立面时压成椭圆（见 src/treefit.js）
  trees: [...P.TREES.map((t) => [r2(t.x), r2(t.z), r2(t.y), r2(t.s), t.kind, r2(t.yaw ?? 0), t.along ?? 1, t.across ?? 1]), ...P.PALMS.map((t) => [r2(t.x), r2(t.z), r2(t.y), r2(t.s), 'palm', r2(t.yaw ?? 0), t.along ?? 1, t.across ?? 1])],
  lamps: P.LAMPS.map((l) => [r2(l.x), r2(l.z), r2(l.y), r2(l.yaw)]),
  // 传送石落点：石头四周 3.4m 处第一个可站立、无阻挡、与石基同高的点，面朝石头
  waystones: P.WAYSTONES.map((w) => {
    let land = [w.x, w.z + 4, 180];
    for (const a of [Math.PI / 2, 0, Math.PI, -Math.PI / 2]) {
      const x = w.x + Math.cos(a) * 3.4, z = w.z + Math.sin(a) * 3.4, g = groundAt(x, z, w.y + 0.7);
      if (g !== null && Math.abs(g - w.y) < 0.7 && !blocked(x, z, g, 0.5)) { land = [x, z, Math.atan2(w.x - x, w.z - z) * 180 / Math.PI]; break; }
    }
    return { id: w.id, name: w.name, x: r2(w.x), z: r2(w.z), y: r2(w.y), land: land.map(r2) };
  }),
  // 室内大厅：游戏端在天花下挂补光（白盒室内没有窗光）
  halls: P.HALLS.map((h) => {
    const n = h.hall.length, c = h.hall.reduce((a, p) => [a[0] + p[0] / n, a[1] + p[1] / n], [0, 0]);
    const xs = h.hall.map((p) => p[0]), zs = h.hall.map((p) => p[1]);
    // 补光网格：约 14m 一盏、落在大厅多边形内、最多 6 盏（按离中心远近取），至少一盏在中心
    const lights = [];
    const bx0 = Math.min(...xs), bx1 = Math.max(...xs), bz0 = Math.min(...zs), bz1 = Math.max(...zs);
    const nx = Math.max(1, Math.round((bx1 - bx0) / 14)), nz = Math.max(1, Math.round((bz1 - bz0) / 14));
    for (let i = 0; i < nx; i++) for (let j = 0; j < nz; j++) {
      const q = [bx0 + (bx1 - bx0) * (i + 0.5) / nx, bz0 + (bz1 - bz0) * (j + 0.5) / nz];
      if (pointInPoly(q, h.hall)) lights.push(q);
    }
    lights.sort((a, b) => Math.hypot(a[0] - c[0], a[1] - c[1]) - Math.hypot(b[0] - c[0], b[1] - c[1]));
    if (!lights.length) lights.push(c);
    return { id: h.id, x: r2(c[0]), z: r2(c[1]), floor: r2(h.floor), ceil: r2(h.ceil), span: r2(Math.max(bx1 - bx0, bz1 - bz0)), door: h.cut.o.map(r2),
      lights: lights.slice(0, 6).map((q) => q.map(r2)) };
  }),
  map: {
    districts: Object.fromEntries(Object.entries(P.DISTRICTS).map(([k, d]) => [k, d.color])),
    blocks: P.BLOCKS.map((b) => ({ d: b.district, use: b.use, poly: b.poly.map(([x, z]) => [r2(x), r2(z)]) })),
    lots: P.LOTS.map((l) => l.poly.map(([x, z]) => [r2(x), r2(z)])),
    landmarks: P.LANDMARKS.filter((l) => !l.orn).map((l) => ({ id: l.id, name: l.name, poly: l.footprint.map(([x, z]) => [r2(x), r2(z)]) })),
  },
  landmarks: P.LANDMARKS.map((l) => ({ id: l.id, name: l.name, func: l.func, type: l.type, x: r2(l.x), z: r2(l.z), w: l.w, d: l.d, h: l.h, yaw: r2(l.yaw * 180 / Math.PI), level: l.level, poi: l.poi || null,
    tier: l.tier || 0, tower: l.tower || 0, spire: l.spire || 0, dome: !!l.dome, clock: !!l.clock, block: l.block, district: (P.BLOCKS.find((b) => b.id === l.block) || {}).district || null,
    kit: P.KIT_TYPES.has(l.type) && !l.orn, enter: l.enter ? enterLocal(l) : null })),
};
await writeFile(resolve(DOC, 'game.json'), JSON.stringify(game), 'utf8');
console.log('EXPORTED', chunkList.length, 'chunks', Math.round(tris), 'tris', Math.round(colTris), 'collision tris', 'materials:', [...mats].join(','));
