// 过渡带可达性：北苑叠园逐层上山、西海堤上崖阶梯、各离岸岛与栈桥、飞艇天桥（步行碰撞同 HTML / 游戏）
// node test_transition.mjs
import { ISLANDS, SHELF, STAIR_Z, HILL, xOut, LV, CURB, DECKS } from './src/plan.js';
import { step, groundAt } from './src/walk.js';

let fails = 0;
function route(name, start, waypoints, endY, tol = 0.6) {
  let [x, z] = start;
  let y = groundAt(x, z, 99);
  if (y === null) { console.log('FAIL', name, '起点无地面', start); fails++; return; }
  let fail = null;
  for (const p of waypoints) {
    for (let k = 0; k < 6000; k++) {
      const dx = p[0] - x, dz = p[1] - z, L = Math.hypot(dx, dz);
      if (L < 0.3) break;
      const s = Math.min(0.1, L), n = step(x, z, y, dx / L * s, dz / L * s);
      if (Math.hypot(n[0] - x, n[1] - z) < 1e-5) { fail = `卡在 (${x.toFixed(1)}, ${z.toFixed(1)}) y=${y.toFixed(2)} 想去 (${p[0].toFixed(0)}, ${p[1].toFixed(0)})`; break; }
      [x, z, y] = n;
    }
    if (fail) break;
  }
  const ok = !fail && Math.abs(y - endY) <= tol;
  if (!ok) fails++;
  console.log(ok ? 'PASS' : 'FAIL', name, fail || `终点 (${x.toFixed(0)}, ${z.toFixed(0)}) y=${y.toFixed(2)}（期望 ${endY}）`);
}

const hx = HILL.x, zs = HILL.zs, lv = HILL.levels;
// 1) 北苑叠园：王宫台（30）→ 侧阶 → 后平台（34）→ 四道阶梯 → 山顶台（54）
const ap = HILL.apron, zA = (zs[0] + ap.z1) / 2;
const up = (sx) => [[hx + sx * 36, zA], [hx + sx * 36, zs[0] + 3], [hx + sx * 36, zs[1] + 4], [hx + sx * 36, zs[1] - 4], [hx + sx * 36, zs[2] + 4], [hx + sx * 36, zs[2] - 4], [hx + sx * 36, zs[3] + 4], [hx + sx * 36, zs[3] - 4], [hx, -655]];
route('北苑 王宫台 → 西侧侧阶 → 后平台 → 山顶台', [ap.x0 - 16, zA], [[ap.x0 + 4, zA], ...up(-1)], lv[4] + CURB, 0.4);
route('北苑 王宫台 → 东侧侧阶 → 后平台 → 山顶台', [ap.x1 + 16, zA], [[ap.x1 - 4, zA], ...up(1)], lv[4] + CURB, 0.4);
route('北苑 山顶台 → 回到王宫台', [hx, -655], [[hx - 36, -640], [hx - 36, zs[3] + 4], [hx - 36, zs[2] - 4], [hx - 36, zs[2] + 4], [hx - 36, zs[1] - 4], [hx - 36, zs[1] + 4], [hx - 36, zs[0] + 3], [hx - 36, zA], [ap.x0 + 4, zA], [ap.x0 - 16, zA]], LV.TOP, 0.4);// 2) 西海堤：四处上崖阶梯，从崖上街道走到海堤面
for (const z of STAIR_Z) route(`海崖阶梯 z=${Math.round(z)} 崖上 → 海堤`, [SHELF.x + 12, z], [[SHELF.x - 1, z], [SHELF.x - 44, z]], LV.LOW + 0.1, 0.5);
// 3) 海堤 → 各岛：从海堤沿桥走到岛心
for (const s of ISLANDS) {
  const endY = s.level + (s.level === LV.QUAY ? 0 : CURB);
  route(`海堤 → ${s.name}`, [xOut(s.zc) + 8, s.zc], [[xOut(s.zc) - 6, s.zc], [s.xc + s.r - 2, s.zc], [s.xc + s.r * 0.45, s.zc]], endY, 0.5);
}
// 4) 飞艇天桥：从使馆区飞艇广场走上天桥到泊台
const air = ISLANDS.find((s) => s.id === 'isl_air');
route('飞艇天桥 使馆区 → 泊台', [SHELF.x + 25, air.zc], [[SHELF.x - 4, air.zc], [air.xc + air.r - 2, air.zc], [air.xc + 30, air.zc]], LV.TOP + CURB, 0.5);
// 5) 反向：从泊台走回崖上
route('飞艇天桥 泊台 → 使馆区', [air.xc + 30, air.zc], [[air.xc + air.r - 2, air.zc], [SHELF.x + 2, air.zc], [SHELF.x + 25, air.zc]], LV.TOP + CURB, 0.5);
// 6) 水中：海堤外沿以外不是地面
const out = groundAt(xOut(100) - 10, 100, 99);
console.log(out === null ? 'PASS' : 'FAIL', '海堤外沿之外是水面（无地面）', out); if (out !== null) fails++;
console.log(fails ? `FAILED ${fails}` : 'transition ok');
process.exitCode = fails ? 1 : 0;
