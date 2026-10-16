// 可进入建筑回归：每个大厅从门前台阶下 2m 走到服务位（步行碰撞同 HTML；>0.07m 的竖向坎视为真实物理迈不上，0.18m 路缘石除外——游戏碰撞里是 0.6m 缓坡）
// node test_enter.mjs
import { HALLS } from './src/plan.js';
import { step, groundAt } from './src/walk.js';
let ok=0; const bad=[];
for (const h of HALLS) {
  const sp=h.sp, W=h.toWorld, zs=h.hallL.map(p=>p[1]); const zin=sp.doorZ-sp.din, zmin=Math.min(...zs);
  const start=h.ramp.b.map((v,i)=>v+h.ramp.dir[i]*2.0);
  const target=W([0, zin-Math.min((zin-zmin)*0.55,10)+3]);
  let x=start[0], z=start[1], y=groundAt(x,z,h.level+1.5);
  if (y===null) { bad.push(h.id+' no ground at start'); continue; }
  const pts=[ W([0, sp.doorZ + 1.5]), W([0, sp.doorZ - sp.din - 1]), target ];
  let fail=null;
  for (const p of pts) { for (let k=0;k<4000;k++){ const dx=p[0]-x, dz=p[1]-z, L=Math.hypot(dx,dz); if (L<0.25) break; const s=Math.min(0.05,L); const n=step(x,z,y,dx/L*s,dz/L*s); if (Math.hypot(n[0]-x,n[1]-z)<1e-4){ fail=[x,z,y].map(v=>v.toFixed(1)).join(','); break;} if (n[2]-y>0.07 && Math.abs(n[2]-y-0.18)>0.01) { fail='lip '+(n[2]-y).toFixed(2)+' at '+[x,z,y].map(v=>v.toFixed(1)).join(','); break; } [x,z,y]=n; } if (fail) break; }
  if (fail || Math.abs(y-h.floor)>0.05) bad.push(h.id+' stuck at '+(fail||[x,z,y].map(v=>v.toFixed(1)).join(','))+' floor '+h.floor.toFixed(2)); else ok++;
}
console.log('walk-in ok', ok, '/', HALLS.length); console.log(bad.join('\n'));



process.exitCode = bad.length ? 1 : 0;

// 入口坡道坡度不超过角色 floor_max_angle（52°），留 4° 余量
for (const h of HALLS) for (const r of h.ramps) { const a = Math.atan2(Math.abs(r.y0 - r.y1), dist2d(r.a, r.b)) * 180 / Math.PI; if (a > 48) { console.log('STEEP', h.id, a.toFixed(1)); process.exitCode = 1; } }
function dist2d(a, b) { return Math.hypot(b[0] - a[0], b[1] - a[1]); }
