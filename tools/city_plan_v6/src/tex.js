// 程序化贴图（canvas），全部内嵌，不需要外部文件。
import * as THREE from 'three';
import { rng } from './geo2d.js';

function canvas(w, h = w) { const c = document.createElement('canvas'); c.width = w; c.height = h; return [c, c.getContext('2d')]; }
function toTex(c, srgb = true) {
  const t = new THREE.CanvasTexture(c);
  t.wrapS = t.wrapT = THREE.RepeatWrapping;
  t.anisotropy = 8;
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
const hsl = (h, s, l) => `hsl(${h},${s}%,${l}%)`;
function noise(g, w, h, R, amt, n = 4000) {
  for (let i = 0; i < n; i++) { g.fillStyle = `rgba(${R() < 0.5 ? '0,0,0' : '255,255,255'},${R() * amt})`; g.fillRect(R() * w, R() * h, 1 + R() * 2, 1 + R() * 2); }
}

// 车行道：不规则弹石（4m 一张）
export function cobble() {
  const S = 512, [c, g] = canvas(S), R = rng(3);
  g.fillStyle = '#6d665d'; g.fillRect(0, 0, S, S);
  const rows = 28, rh = S / rows;
  for (let r = 0; r < rows; r++) {
    let x = -R() * 20;
    while (x < S) {
      const w = rh * (0.9 + R() * 0.7);
      const l = 46 + R() * 16;
      g.fillStyle = hsl(30 + R() * 14, 8 + R() * 8, l);
      const pad = 1.6;
      g.beginPath(); g.roundRect(x + pad, r * rh + pad, w - pad * 2, rh - pad * 2, 4); g.fill();
      g.fillStyle = 'rgba(255,255,255,0.08)'; g.fillRect(x + pad + 2, r * rh + pad + 1, w - pad * 2 - 4, 2);
      x += w;
    }
  }
  noise(g, S, S, R, 0.08);
  return toTex(c);
}
// 人行道：错缝石板（3m 一张）
export function paving() {
  const S = 512, [c, g] = canvas(S), R = rng(5);
  g.fillStyle = '#9a9286'; g.fillRect(0, 0, S, S);
  const rows = 8, rh = S / rows;
  for (let r = 0; r < rows; r++) {
    const off = (r % 2) * rh;
    for (let x = -off; x < S; x += rh * 2) {
      g.fillStyle = hsl(36, 10 + R() * 6, 66 + R() * 9);
      g.fillRect(x + 2, r * rh + 2, rh * 2 - 4, rh - 4);
    }
  }
  noise(g, S, S, R, 0.06);
  return toTex(c);
}
// 广场：大石板 + 浅色勾边（6m 一张）
export function plazaTiles() {
  const S = 512, [c, g] = canvas(S), R = rng(9);
  g.fillStyle = '#8c8479'; g.fillRect(0, 0, S, S);
  const n = 6, s = S / n;
  for (let i = 0; i < n; i++) for (let j = 0; j < n; j++) {
    g.fillStyle = ((i + j) % 2) ? hsl(38, 14, 72 + R() * 6) : hsl(30, 10, 62 + R() * 6);
    g.fillRect(i * s + 3, j * s + 3, s - 6, s - 6);
  }
  noise(g, S, S, R, 0.05);
  return toTex(c);
}
export function grass() {
  const S = 256, [c, g] = canvas(S), R = rng(7);
  g.fillStyle = '#5f8a3e'; g.fillRect(0, 0, S, S);
  for (let i = 0; i < 6000; i++) { g.fillStyle = hsl(85 + R() * 30, 40 + R() * 20, 28 + R() * 22); g.fillRect(R() * S, R() * S, 1, 2 + R() * 3); }
  return toTex(c);
}
// 挡土墙 / 城墙：大块琢石（4m 一张）
export function ashlar() {
  const S = 512, [c, g] = canvas(S), R = rng(11);
  g.fillStyle = '#7d7468'; g.fillRect(0, 0, S, S);
  const rows = 8, rh = S / rows;
  for (let r = 0; r < rows; r++) {
    let x = -R() * rh;
    while (x < S) {
      const w = rh * (1.4 + R() * 1.4);
      g.fillStyle = hsl(34 + R() * 8, 10 + R() * 8, 60 + R() * 12);
      g.fillRect(x + 2, r * rh + 2, w - 4, rh - 4);
      g.fillStyle = 'rgba(0,0,0,0.12)'; g.fillRect(x + 2, r * rh + rh - 6, w - 4, 4);
      x += w;
    }
  }
  noise(g, S, S, R, 0.07);
  return toTex(c);
}
// 立面贴图：一张 = 2 开间 × 2 层（7.2m × 7.6m）。返回 [颜色贴图, 夜景亮窗贴图]
export function facade(kind) {
  const S = 512, [c, g] = canvas(S), [ce, ge] = canvas(S), R = rng(kind.length * 31);
  const wall = { haus: '#e4d7bd', brick: '#a5543d', plaster: '#f2ece2', warehouse: '#8f4632', academy: '#e9e3d6', timber: '#efe4cc' }[kind];
  g.fillStyle = wall; g.fillRect(0, 0, S, S);
  ge.fillStyle = '#000'; ge.fillRect(0, 0, S, S);
  if (kind === 'brick' || kind === 'warehouse') {
    for (let y = 0; y < S; y += 8) for (let x = -((y / 8) % 2) * 8; x < S; x += 16) {
      g.fillStyle = hsl(10 + R() * 10, 45 + R() * 15, 34 + R() * 12); g.fillRect(x + 1, y + 1, 14, 6);
    }
  } else if (kind === 'timber') {
    noise(g, S, S, R, 0.05, 3000);
    g.fillStyle = '#5a3a26';
    for (const x of [0, S / 2 - 6, S - 12]) g.fillRect(x, 0, 12, S);
    for (const y of [0, S / 2 - 8]) g.fillRect(0, y, S, 14);
    g.lineWidth = 10; g.strokeStyle = '#5a3a26';
    for (let k = 0; k < 2; k++) { const x0 = k * S / 2; g.beginPath(); g.moveTo(x0 + 12, S / 2 - 8); g.lineTo(x0 + S / 2 - 6, 14); g.stroke(); g.beginPath(); g.moveTo(x0 + 12, S - 4); g.lineTo(x0 + S / 2 - 6, S / 2 + 6); g.stroke(); }
  } else {
    for (let y = 0; y < S; y += 32) { g.fillStyle = 'rgba(80,60,40,0.10)'; g.fillRect(0, y, S, 2); }
    noise(g, S, S, R, 0.05, 3000);
  }
  const bw = S / 2, fh = S / 2;
  for (let fy = 0; fy < 2; fy++) for (let bx = 0; bx < 2; bx++) {
    const x0 = bx * bw, y0 = fy * fh;
    const ww = bw * (kind === 'warehouse' ? 0.5 : 0.38), wh = fh * (kind === 'warehouse' ? 0.5 : 0.6);
    const wx = x0 + (bw - ww) / 2, wy = y0 + fh * 0.22;
    // 窗套
    g.fillStyle = kind === 'brick' || kind === 'warehouse' ? '#e8dfcc' : kind === 'plaster' ? '#d9cfbf' : '#d2c3a2';
    g.fillRect(wx - 10, wy - 12, ww + 20, wh + 24);
    if (kind === 'brick' || kind === 'warehouse') { g.beginPath(); g.ellipse(wx + ww / 2, wy, ww / 2 + 10, 22, 0, Math.PI, 0); g.fill(); }
    // 玻璃
    const lit = R() < 0.55;
    g.fillStyle = '#2e3d4a'; g.fillRect(wx, wy, ww, wh);
    if (kind === 'brick' || kind === 'warehouse') { g.beginPath(); g.ellipse(wx + ww / 2, wy, ww / 2, 16, 0, Math.PI, 0); g.fill(); }
    g.fillStyle = 'rgba(160,190,210,0.35)'; g.fillRect(wx + 4, wy + 4, ww * 0.4, wh * 0.5);
    ge.fillStyle = lit ? `hsl(${36 + R() * 10},90%,${55 + R() * 20}%)` : '#000';
    ge.fillRect(wx, wy, ww, wh);
    // 窗棂
    g.fillStyle = '#efe9dc'; g.fillRect(wx + ww / 2 - 2, wy, 4, wh); g.fillRect(wx, wy + wh * 0.4, ww, 4);
    ge.fillStyle = '#000'; ge.fillRect(wx + ww / 2 - 2, wy, 4, wh); ge.fillRect(wx, wy + wh * 0.4, ww, 4);
    // 窗台与窗楣
    g.fillStyle = 'rgba(0,0,0,0.18)'; g.fillRect(wx - 14, wy + wh + 10, ww + 28, 5);
    g.fillStyle = kind === 'brick' ? '#efe6d4' : '#cdbd9d'; g.fillRect(wx - 14, wy + wh + 4, ww + 28, 8);
    if (kind === 'haus' || kind === 'academy') { g.fillStyle = '#c8b791'; g.fillRect(wx - 16, wy - 26, ww + 32, 12); }
    // 百叶
    if (kind === 'plaster') { g.fillStyle = R() < 0.5 ? '#4f7a63' : '#4c6b8a'; g.fillRect(wx - 34, wy, 22, wh); g.fillRect(wx + ww + 12, wy, 22, wh); }
    // 法式小阳台栏杆
    if (kind === 'haus' || kind === 'academy') { g.strokeStyle = '#2b2b2b'; g.lineWidth = 2; for (let k = 0; k < 9; k++) { const xx = wx - 6 + k * (ww + 12) / 8; g.beginPath(); g.moveTo(xx, wy + wh * 0.68); g.lineTo(xx, wy + wh); g.stroke(); } g.fillStyle = '#2b2b2b'; g.fillRect(wx - 8, wy + wh * 0.66, ww + 16, 4); }
  }
  return [toTex(c), toTex(ce)];
}
// 底层商铺：一张 = 1 开间 × 1 层（3.6m × 5m）
export function shopfront(variant) {
  const S = 256, [c, g] = canvas(S), [ce, ge] = canvas(S), R = rng(91 + variant);
  const frame = ['#1f3a4d', '#4a2a22', '#24402f', '#2a2a2a'][variant % 4];
  g.fillStyle = '#d8ccb4'; g.fillRect(0, 0, S, S);
  ge.fillStyle = '#000'; ge.fillRect(0, 0, S, S);
  g.fillStyle = frame; g.fillRect(14, 30, S - 28, S - 30);
  g.fillStyle = '#c9a65a'; g.fillRect(20, 36, S - 40, 26);           // 招牌带
  g.fillStyle = '#26333d'; g.fillRect(26, 74, S - 52, S - 84);       // 橱窗
  g.fillStyle = 'rgba(200,220,235,0.25)'; g.fillRect(32, 80, 60, 110);
  ge.fillStyle = 'hsl(40,85%,62%)'; ge.fillRect(26, 74, S - 52, S - 84);
  g.fillStyle = frame; g.fillRect(S / 2 - 3, 74, 6, S - 84); g.fillRect(26, 150, S - 52, 5);
  ge.fillStyle = '#000'; ge.fillRect(S / 2 - 3, 74, 6, S - 84);
  noise(g, S, S, R, 0.05, 800);
  return [toTex(c), toTex(ce)];
}
// 住宅底层：粗面石 + 拱窗（1 开间 × 1 层）
export function groundRes() {
  const S = 256, [c, g] = canvas(S), [ce, ge] = canvas(S), R = rng(77);
  g.fillStyle = '#cbbd9f'; g.fillRect(0, 0, S, S); ge.fillStyle = '#000'; ge.fillRect(0, 0, S, S);
  for (let y = 0; y < S; y += 26) { g.fillStyle = 'rgba(60,45,30,0.25)'; g.fillRect(0, y, S, 3); }
  g.fillStyle = '#2b3640'; g.fillRect(70, 80, 116, 150); g.beginPath(); g.ellipse(128, 80, 58, 40, 0, Math.PI, 0); g.fill();
  ge.fillStyle = R() < 0.5 ? 'hsl(38,80%,58%)' : '#000'; ge.fillRect(70, 80, 116, 150);
  g.fillStyle = '#e7dcc4'; g.fillRect(124, 60, 8, 170);
  return [toTex(c), toTex(ce)];
}
// 屋面：石板鱼鳞瓦 / 红陶筒瓦 / 铜皮（3m 一张）
export function roof(kind) {
  const S = 256, [c, g] = canvas(S), R = rng(kind.length * 13);
  const base = { slate: [215, 18, 34], tile: [12, 52, 42], copper: [165, 28, 46], lead: [210, 6, 52], violet: [262, 32, 38], royal: [222, 46, 34] }[kind];
  g.fillStyle = hsl(base[0], base[1], base[2] - 6); g.fillRect(0, 0, S, S);
  const rows = kind === 'copper' || kind === 'lead' ? 8 : 16, rh = S / rows;
  for (let r = 0; r < rows; r++) {
    const off = (r % 2) * rh * 0.5;
    for (let x = -off; x < S; x += rh) {
      g.fillStyle = hsl(base[0] + R() * 8 - 4, base[1] + R() * 8, base[2] + R() * 10 - 3);
      if (kind === 'slate' || kind === 'violet' || kind === 'royal') { g.beginPath(); g.ellipse(x + rh / 2, r * rh + rh * 0.5, rh * 0.48, rh * 0.62, 0, 0, Math.PI); g.fill(); g.fillRect(x + 1, r * rh, rh - 2, rh * 0.5); }
      else if (kind === 'tile') { g.fillRect(x + 2, r * rh, rh - 4, rh); g.fillStyle = 'rgba(255,255,255,0.12)'; g.fillRect(x + rh * 0.3, r * rh, 3, rh); }
      else { g.fillRect(x, r * rh, rh * 2 - 2, rh - 2); }
    }
  }
  if (kind === 'copper') for (let i = 0; i < 40; i++) { g.fillStyle = 'rgba(90,160,140,0.25)'; g.fillRect(R() * S, 0, 3, S); }
  return toTex(c);
}
// 栏杆（透明）：石瓶栏杆 / 铁栏杆
export function balustrade(iron = false) {
  const W = 256, H = 64, [c, g] = canvas(W, H);
  g.clearRect(0, 0, W, H);
  if (iron) {
    g.fillStyle = '#26292c'; g.fillRect(0, 0, W, 5); g.fillRect(0, H - 6, W, 6);
    for (let x = 4; x < W; x += 16) { g.fillRect(x, 0, 3, H); g.beginPath(); g.arc(x + 1.5, H * 0.45, 5, 0, Math.PI * 2); g.lineWidth = 2; g.strokeStyle = '#26292c'; g.stroke(); }
  } else {
    g.fillStyle = '#e2d8c4'; g.fillRect(0, 0, W, 10); g.fillRect(0, H - 8, W, 8);
    for (let x = 8; x < W; x += 21) { g.beginPath(); g.ellipse(x + 6, H * 0.52, 6.5, 16, 0, 0, Math.PI * 2); g.fill(); g.fillRect(x + 3, 8, 6, H - 14); }
  }
  const t = toTex(c);
  return t;
}
export function awning() {
  const S = 128, [c, g] = canvas(S);
  g.fillStyle = '#fff'; g.fillRect(0, 0, S, S);
  g.fillStyle = '#c9c9c9'; for (let x = 0; x < S; x += 32) g.fillRect(x, 0, 16, S);
  return toTex(c);
}
export function glowSprite() {
  const S = 64, [c, g] = canvas(S);
  const gr = g.createRadialGradient(S / 2, S / 2, 0, S / 2, S / 2, S / 2);
  gr.addColorStop(0, 'rgba(255,220,150,1)'); gr.addColorStop(0.3, 'rgba(255,190,110,0.5)'); gr.addColorStop(1, 'rgba(255,170,90,0)');
  g.fillStyle = gr; g.fillRect(0, 0, S, S);
  const t = new THREE.CanvasTexture(c); t.colorSpace = THREE.SRGBColorSpace; return t;
}
