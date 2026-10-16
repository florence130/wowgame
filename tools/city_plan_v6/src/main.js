import * as THREE from 'three';
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js';
import { mergeGeometries } from 'three/examples/jsm/utils/BufferGeometryUtils.js';
import { makeMaterials, buildCity } from './build.js';
import { glowSprite } from './tex.js';
import { inset, centroid, dist, rng, pointInPoly, bbox } from './geo2d.js';
import { EXTENT, HALLS, WAYSTONES, CITY_RECT, LV, CURB, ROAD, DISTRICTS, TERRACES, BLOCKS, LOTS, LANDMARKS, STAIRS, DECKS, TREES, PALMS, LAMPS, SHIPS, AIRSHIPS, PLAZA, DISTRICT_LABELS, STREET_LABELS, VIADUCT, CABLEWAY, stats } from './plan.js';
import { groundAt, step, setTerrain } from './walk.js';
import TER from '../../../docs/city_v7/terrain.json';

const $ = (s) => document.querySelector(s);
const status = $('#load-status');
if (innerWidth < 1100) document.getElementById('panel').classList.remove('open');
const say = (t) => { if (status) status.textContent = t; };

// ---------------------------------------------------------------- 渲染器与场景
const canvas = $('#scene');
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.75));
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(55, 1, 0.3, 9000);
camera.position.set(-180 + 700, 820, 200 + 900);

// 天空
const skyU = { top: { value: new THREE.Color('#4f86d8') }, hor: { value: new THREE.Color('#d6e7f1') }, sunDir: { value: new THREE.Vector3(0.4, 0.6, 0.3) }, sunCol: { value: new THREE.Color('#fff2d0') } };
const sky = new THREE.Mesh(new THREE.SphereGeometry(6000, 32, 16), new THREE.ShaderMaterial({
  side: THREE.BackSide, depthWrite: false, uniforms: skyU,
  vertexShader: 'varying vec3 vd; void main(){ vd = normalize((modelMatrix*vec4(position,1.0)).xyz - cameraPosition); gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.0); }',
  fragmentShader: 'uniform vec3 top; uniform vec3 hor; uniform vec3 sunDir; uniform vec3 sunCol; varying vec3 vd; void main(){ float h = clamp(vd.y*1.6+0.05,0.0,1.0); vec3 c = mix(hor, top, pow(h,0.7)); float s = pow(max(dot(normalize(vd), normalize(sunDir)),0.0), 220.0); float g = pow(max(dot(normalize(vd), normalize(sunDir)),0.0), 8.0); c += sunCol*(s*1.2 + g*0.18); gl_FragColor = vec4(c,1.0); }',
}));
sky.frustumCulled = false;
scene.add(sky);
scene.fog = new THREE.Fog(0xd6e7f1, 600, 3800);
const hemi = new THREE.HemisphereLight(0xdbe8ff, 0x6b5f4f, 1.1);
scene.add(hemi);
const sun = new THREE.DirectionalLight(0xfff0d6, 3.0);
sun.castShadow = true;
sun.shadow.mapSize.set(2048, 2048);
sun.shadow.camera.left = -260; sun.shadow.camera.right = 260; sun.shadow.camera.top = 260; sun.shadow.camera.bottom = -260;
sun.shadow.camera.near = 10; sun.shadow.camera.far = 1600;
sun.shadow.bias = -0.0006; sun.shadow.normalBias = 0.6;
scene.add(sun, sun.target);

// ---------------------------------------------------------------- 城市
say('正在生成街坊与建筑…');
const M = makeMaterials();
const city = buildCity(scene, M);

// 城外真实地形（游戏 tidewind 地形导出，docs/city_v7/terrain.json，10m 网格）
function terrainH(x, z) {
  const fx = (x - TER.x0) / TER.step, fz = (z - TER.z0) / TER.step;
  const ix = Math.max(0, Math.min(TER.nx - 2, Math.floor(fx))), iz = Math.max(0, Math.min(TER.nz - 2, Math.floor(fz)));
  const tx = Math.min(1, Math.max(0, fx - ix)), tz = Math.min(1, Math.max(0, fz - iz));
  const H = TER.h, n = TER.nx;
  const a = H[iz * n + ix], b = H[iz * n + ix + 1], c = H[(iz + 1) * n + ix], d = H[(iz + 1) * n + ix + 1];
  return (a * (1 - tx) + b * tx) * (1 - tz) + (c * (1 - tx) + d * tx) * tz;
}
setTerrain(terrainH);
{
  const g = new THREE.PlaneGeometry((TER.nx - 1) * TER.step, (TER.nz - 1) * TER.step, TER.nx - 1, TER.nz - 1);
  g.rotateX(-Math.PI / 2);
  g.translate(TER.x0 + (TER.nx - 1) * TER.step / 2, 0, TER.z0 + (TER.nz - 1) * TER.step / 2);
  const pos = g.attributes.position, raw = atob(TER.c), col = new Float32Array(pos.count * 3);
  for (let i = 0; i < pos.count; i++) {
    const ix = Math.round((pos.getX(i) - TER.x0) / TER.step), iz = Math.round((pos.getZ(i) - TER.z0) / TER.step), k = iz * TER.nx + ix;
    pos.setY(i, TER.h[k]);
    for (let j = 0; j < 3; j++) col[i * 3 + j] = Math.pow(raw.charCodeAt(k * 3 + j) / 255, 2.2);
  }
  g.setAttribute('color', new THREE.BufferAttribute(col, 3));
  g.computeVertexNormals();
  const ground = new THREE.Mesh(g, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 1 }));
  ground.receiveShadow = true;
  scene.add(ground);
}
// 远山与海岛
{
  const mat = new THREE.MeshStandardMaterial({ color: 0x7f9488, roughness: 1, flatShading: true });
  const snow = new THREE.MeshStandardMaterial({ color: 0xeef3f8, roughness: 0.9, flatShading: true });
  const R = rng(42);
  for (let i = 0; i < 26; i++) {
    const a = -Math.PI * 0.15 + (i / 26) * Math.PI * 1.25;   // 北与东侧环山
    const r = 2400 + R() * 1100, h = 220 + R() * 380;
    const x = -200 + Math.cos(a - Math.PI / 2) * r, z = 400 + Math.sin(a - Math.PI / 2) * r;
    if (z > 700 && x < 200) continue;
    const g = new THREE.ConeGeometry(220 + R() * 260, h, 7, 1);
    const m = new THREE.Mesh(g, mat); m.position.set(x, h / 2 - 10, z); m.rotation.y = R() * 3; scene.add(m);
    if (h > 470) { const cap = new THREE.Mesh(new THREE.ConeGeometry(130, h * 0.3, 7, 1), snow); cap.position.set(x, h - h * 0.15 - 10, z); scene.add(cap); }
  }
  for (const [x, z, s] of [[-1500, 1500, 220], [-900, 2100, 160], [600, 1900, 140]]) {
    const m = new THREE.Mesh(new THREE.SphereGeometry(s, 10, 6, 0, Math.PI * 2, 0, Math.PI / 2), mat);
    m.scale.y = 0.35; m.position.set(x, -4, z); scene.add(m);
  }
}

// ---------------------------------------------------------------- 实例化：树、棕榈、路灯、行人
const dummy = new THREE.Object3D();
function instanced(geo, mat, list, place, castShadow = true) {
  const im = new THREE.InstancedMesh(geo, mat, list.length);
  list.forEach((it, i) => { place(it, dummy, i); dummy.updateMatrix(); im.setMatrixAt(i, dummy.matrix); });
  im.castShadow = castShadow; im.receiveShadow = true;
  scene.add(im);
  return im;
}
const leaf = new THREE.MeshStandardMaterial({ color: 0xffffff, roughness: 0.95, flatShading: true });
const bark = new THREE.MeshStandardMaterial({ color: 0x6b4a32, roughness: 1 });
// 广场花坛柏树
for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2 + Math.PI / 8; for (const off of [-1.8, 1.8]) TREES.push({ x: PLAZA.x + Math.cos(a) * 19 - Math.sin(a) * off, z: PLAZA.z + Math.sin(a) * 19 + Math.cos(a) * off, y: LV.MID + CURB + 1.7, s: 0.55, kind: 'cypress' }); }
const round = TREES.filter((t) => t.kind === 'round'), cyp = TREES.filter((t) => t.kind === 'cypress');
{
  const crownG = new THREE.IcosahedronGeometry(3.2, 1);
  const pos = crownG.attributes.position, R = rng(5);
  for (let i = 0; i < pos.count; i++) pos.setXYZ(i, pos.getX(i) * (0.9 + R() * 0.2), pos.getY(i) * (0.8 + R() * 0.15), pos.getZ(i) * (0.9 + R() * 0.2));
  crownG.computeVertexNormals();
  instanced(new THREE.CylinderGeometry(0.22, 0.3, 4, 6).translate(0, 2, 0), bark, round, (t, d) => { d.position.set(t.x, t.y, t.z); d.scale.setScalar(t.s); d.rotation.set(0, 0, 0); });
  const im = instanced(crownG.translate(0, 5.6, 0), leaf, round, (t, d) => { d.position.set(t.x, t.y, t.z); d.scale.setScalar(t.s); d.rotation.y = t.x; });
  const R2 = rng(9);
  round.forEach((t, i) => im.setColorAt(i, new THREE.Color().setHSL(0.24 + R2() * 0.08, 0.45, 0.32 + R2() * 0.1)));
  const ic = instanced(new THREE.CylinderGeometry(0.15, 1.3, 8.5, 7).translate(0, 5, 0), leaf, cyp, (t, d) => { d.position.set(t.x, t.y, t.z); d.scale.setScalar(t.s); });
  cyp.forEach((t, i) => ic.setColorAt(i, new THREE.Color().setHSL(0.33, 0.35, 0.22 + R2() * 0.06)));
  instanced(new THREE.CylinderGeometry(0.12, 0.2, 2, 5).translate(0, 1, 0), bark, cyp, (t, d) => { d.position.set(t.x, t.y, t.z); d.scale.setScalar(t.s); });
  // 棕榈
  const fronds = [];
  for (let k = 0; k < 8; k++) { const g = new THREE.BoxGeometry(0.5, 0.06, 3.4).translate(0, 0, 1.7).rotateX(0.5).rotateY(k / 8 * Math.PI * 2); fronds.push(g); }
  const palmCrown = mergeGeometries(fronds).translate(0, 7.4, 0);
  instanced(new THREE.CylinderGeometry(0.18, 0.3, 7.5, 6).translate(0, 3.75, 0), bark, PALMS, (t, d) => { d.position.set(t.x, t.y, t.z); d.scale.setScalar(t.s); });
  const ip = instanced(palmCrown, leaf, PALMS, (t, d) => { d.position.set(t.x, t.y, t.z); d.scale.setScalar(t.s); d.rotation.y = t.z; });
  PALMS.forEach((t, i) => ip.setColorAt(i, new THREE.Color().setHSL(0.27, 0.5, 0.3)));
}
// 路灯（参考视频：黑色铸铁灯柱 + 灯笼）
const lampPost = mergeGeometries([
  new THREE.CylinderGeometry(0.28, 0.34, 0.6, 8).translate(0, 0.3, 0),
  new THREE.CylinderGeometry(0.08, 0.11, 4.2, 6).translate(0, 2.7, 0),
  new THREE.BoxGeometry(0.08, 0.08, 1.1).translate(0, 4.6, 0.45),
  new THREE.ConeGeometry(0.32, 0.35, 6).translate(0, 4.45, 0.95),
]);
instanced(lampPost, M.metal, LAMPS, (l, d) => { d.position.set(l.x, l.y, l.z); d.rotation.set(0, l.yaw, 0); d.scale.setScalar(1); });
const lanternIM = instanced(new THREE.CylinderGeometry(0.2, 0.15, 0.5, 6).translate(0, 4.0, 0.95), M.glow_lamp, LAMPS, (l, d) => { d.position.set(l.x, l.y, l.z); d.rotation.set(0, l.yaw, 0); }, false);
// 灯光晕（夜间）
const glowPts = new THREE.Points(new THREE.BufferGeometry().setAttribute('position', new THREE.Float32BufferAttribute(LAMPS.flatMap((l) => [l.x + Math.sin(l.yaw) * 0.95, l.y + 4.0, l.z + Math.cos(l.yaw) * 0.95]), 3)),
  new THREE.PointsMaterial({ map: glowSprite(), size: 7, sizeAttenuation: true, transparent: true, depthWrite: false, blending: THREE.AdditiveBlending, opacity: 0 }));
scene.add(glowPts);
const lampLights = [];
for (let i = 0; i < 10; i++) { const L = new THREE.PointLight(0xffc979, 0, 26, 1.6); scene.add(L); lampLights.push(L); }

// 行人：沿各街坊人行道环行
const walkers = [];
{
  const R = rng(77);
  for (const b of BLOCKS) {
    if (b.use === 'empty') continue;
    const loop = inset(b.poly, 1.6);
    let L = 0; for (let i = 0; i < loop.length; i++) L += dist(loop[i], loop[(i + 1) % loop.length]);
    const n = Math.min(14, Math.floor(L / (b.district === 'core' || b.district === 'trade' ? 22 : 38)));
    for (let k = 0; k < n; k++) walkers.push({ loop, L, s: R() * L, v: (0.9 + R() * 0.7) * (R() < 0.5 ? 1 : -1), y: b.level + CURB, col: new THREE.Color().setHSL(R(), 0.35 + R() * 0.3, 0.28 + R() * 0.3) });
  }
}
const bodyG = new THREE.CapsuleGeometry(0.24, 1.0, 3, 8).translate(0, 0.75, 0);
const headG = new THREE.SphereGeometry(0.17, 8, 6).translate(0, 1.6, 0);
const people = new THREE.InstancedMesh(mergeGeometries([bodyG, headG]), new THREE.MeshStandardMaterial({ roughness: 0.9 }), walkers.length);
people.castShadow = true;
walkers.forEach((w, i) => people.setColorAt(i, w.col));
scene.add(people);
function posOnLoop(w) {
  let s = ((w.s % w.L) + w.L) % w.L;
  for (let i = 0; i < w.loop.length; i++) {
    const a = w.loop[i], b = w.loop[(i + 1) % w.loop.length], l = dist(a, b);
    if (s <= l) { const t = s / l; return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, Math.atan2(b[0] - a[0], b[1] - a[1])]; }
    s -= l;
  }
  return [w.loop[0][0], w.loop[0][1], 0];
}

// 电车（参考图2：红白双色有轨电车）
function tramMesh(col) {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.BoxGeometry(2.5, 2.6, 14), new THREE.MeshStandardMaterial({ color: col, roughness: 0.5 }));
  body.position.y = 1.8; g.add(body);
  const band = new THREE.Mesh(new THREE.BoxGeometry(2.55, 0.9, 13.6), new THREE.MeshStandardMaterial({ color: 0xf2ead8, emissive: 0xffd590, emissiveIntensity: 0 }));
  band.position.y = 2.5; band.userData.win = true; g.add(band);
  const roofM = new THREE.Mesh(new THREE.BoxGeometry(2.3, 0.35, 13), new THREE.MeshStandardMaterial({ color: 0x3a3a3a }));
  roofM.position.y = 3.25; g.add(roofM);
  const pole = new THREE.Mesh(new THREE.BoxGeometry(0.1, 2.6, 0.1), M.metal); pole.position.set(0, 4.5, -2); pole.rotation.x = 0.5; g.add(pole);
  g.traverse((o) => { o.castShadow = true; });
  scene.add(g);
  return g;
}
const tramPathPts = city.tram;
const tramLen = []; { let s = 0; tramLen.push(0); for (let i = 1; i < tramPathPts.length; i++) { s += Math.hypot(tramPathPts[i][0] - tramPathPts[i - 1][0], tramPathPts[i][2] - tramPathPts[i - 1][2]); tramLen.push(s); } }
const trams = [{ m: tramMesh(0xa3302a), s: 0, v: 7 }, { m: tramMesh(0x2f5f86), s: tramLen[tramLen.length - 1] * 0.55, v: -7 }];
function tramAt(s) {
  const total = tramLen[tramLen.length - 1];
  s = Math.max(0, Math.min(total, s));
  let i = 1; while (i < tramLen.length - 1 && tramLen[i] < s) i++;
  const a = tramPathPts[i - 1], b = tramPathPts[i], t = (s - tramLen[i - 1]) / Math.max(0.001, tramLen[i] - tramLen[i - 1]);
  return [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t, Math.atan2(b[0] - a[0], b[2] - a[2])];
}
// 魔导列车（高架）
const train = new THREE.Group();
for (let k = 0; k < 4; k++) {
  const car = new THREE.Mesh(new THREE.BoxGeometry(3, 3.2, 15), new THREE.MeshStandardMaterial({ color: k === 0 ? 0x2c3e55 : 0x6e2f2a, roughness: 0.5, metalness: 0.2 }));
  car.position.set(0, 1.9, -k * 16); car.castShadow = true; train.add(car);
}
scene.add(train);
const vPts = VIADUCT.pts, vLen = []; { let s = 0; vLen.push(0); for (let i = 1; i < vPts.length; i++) { s += dist(vPts[i - 1], vPts[i]); vLen.push(s); } }
// 缆车
const gondolas = [0, 0.33, 0.66].map((p) => { const g = new THREE.Mesh(new THREE.BoxGeometry(3, 2.6, 3.6), new THREE.MeshStandardMaterial({ color: 0xb23a2e })); g.userData.p = p; g.castShadow = true; scene.add(g); return g; });
// 船
for (const s of SHIPS) {
  const g = new THREE.Group();
  const L = s.len, W = L * 0.24;
  const shape = new THREE.Shape(); shape.moveTo(-W / 2, -L / 2); shape.lineTo(W / 2, -L / 2); shape.lineTo(W / 2, L * 0.25); shape.quadraticCurveTo(W / 2, L / 2, 0, L / 2 + 2); shape.quadraticCurveTo(-W / 2, L / 2, -W / 2, L * 0.25); shape.closePath();
  const hull = new THREE.Mesh(new THREE.ExtrudeGeometry(shape, { depth: 4, bevelEnabled: false }).rotateX(Math.PI / 2).translate(0, 2.5, 0), new THREE.MeshStandardMaterial({ color: s.kind === 'steamer' ? 0x2c3440 : 0x5b3a26, roughness: 0.8 }));
  g.add(hull);
  const deck = new THREE.Mesh(new THREE.BoxGeometry(W * 0.9, 0.3, L * 0.8), new THREE.MeshStandardMaterial({ color: 0xc8a776 })); deck.position.y = 2.6; g.add(deck);
  if (s.kind === 'clipper') for (const z of [-L * 0.25, L * 0.05, L * 0.3]) {
    const mast = new THREE.Mesh(new THREE.CylinderGeometry(0.2, 0.28, L * 0.7, 6), M.metal); mast.position.set(0, 2.6 + L * 0.35, z); g.add(mast);
    for (const k of [0.3, 0.55]) { const sail = new THREE.Mesh(new THREE.PlaneGeometry(W * 1.4, L * 0.18), new THREE.MeshStandardMaterial({ color: 0xf3ede0, side: THREE.DoubleSide })); sail.position.set(0, 2.6 + L * 0.7 * k + L * 0.08, z + 0.4); g.add(sail); }
  } else if (s.kind === 'steamer') {
    const house = new THREE.Mesh(new THREE.BoxGeometry(W * 0.7, 3, L * 0.35), new THREE.MeshStandardMaterial({ color: 0xece4d2 })); house.position.y = 4.2; g.add(house);
    const fun = new THREE.Mesh(new THREE.CylinderGeometry(1, 1.1, 6, 10), new THREE.MeshStandardMaterial({ color: 0xa3302a })); fun.position.set(0, 8, 0); g.add(fun);
  }
  g.position.set(s.x, 0, s.z); g.rotation.y = s.yaw; g.traverse((o) => { o.castShadow = true; });
  scene.add(g);
}
// 飞艇与热气球
const airships = AIRSHIPS.map((a, i) => {
  const g = new THREE.Group();
  const env = new THREE.Mesh(new THREE.SphereGeometry(1, 24, 12), new THREE.MeshStandardMaterial({ color: i === 0 ? 0xd9cfb8 : 0xbac6cf, roughness: 0.7 }));
  env.scale.set(a.len * 0.16, a.len * 0.16, a.len / 2); g.add(env);
  const gon = new THREE.Mesh(new THREE.BoxGeometry(a.len * 0.08, a.len * 0.05, a.len * 0.3), new THREE.MeshStandardMaterial({ color: 0x5b3a26 })); gon.position.y = -a.len * 0.18; g.add(gon);
  for (const sx of [-1, 1]) { const fin = new THREE.Mesh(new THREE.BoxGeometry(0.3, a.len * 0.12, a.len * 0.1), new THREE.MeshStandardMaterial({ color: 0x8a2c26 })); fin.position.set(sx * a.len * 0.08, 0, -a.len * 0.45); g.add(fin); }
  g.position.set(a.x, a.y, a.z); g.userData = a; scene.add(g); return g;
});
const balloons = [[-300, 160, 900], [260, 140, 380], [-700, 180, 600]].map(([x, y, z], i) => {
  const g = new THREE.Group();
  const b = new THREE.Mesh(new THREE.SphereGeometry(7, 16, 12), new THREE.MeshStandardMaterial({ color: [0xd2523f, 0xe8c25a, 0x5a86c6][i], roughness: 0.6 }));
  b.scale.y = 1.2; g.add(b);
  const bk = new THREE.Mesh(new THREE.BoxGeometry(2, 1.4, 2), new THREE.MeshStandardMaterial({ color: 0x6b4a32 })); bk.position.y = -11; g.add(bk);
  g.position.set(x, y, z); g.userData.base = [x, y, z, i]; scene.add(g); return g;
});

// ---------------------------------------------------------------- 玩家（步行模式的人形，1.75m）
const player = new THREE.Group();
{
  const cloak = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.42, 1.25, 10).translate(0, 0.65, 0), new THREE.MeshStandardMaterial({ color: 0x2f4a7a, roughness: 0.8 }));
  const torso = new THREE.Mesh(new THREE.CapsuleGeometry(0.21, 0.4, 3, 8).translate(0, 1.22, 0), new THREE.MeshStandardMaterial({ color: 0xe9e2d2 }));
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.15, 12, 10).translate(0, 1.62, 0), new THREE.MeshStandardMaterial({ color: 0xf0d6c0 }));
  const hair = new THREE.Mesh(new THREE.SphereGeometry(0.165, 12, 10, 0, Math.PI * 2, 0, Math.PI * 0.6).translate(0, 1.65, -0.01), new THREE.MeshStandardMaterial({ color: 0xd88fa0 }));
  for (const m of [cloak, torso, head, hair]) { m.castShadow = true; player.add(m); }
}
player.visible = false;
scene.add(player);

// ---------------------------------------------------------------- 时间
const TIMES = {
  day: { top: '#4f86d8', hor: '#d6e7f1', fog: 0xd6e7f1, sun: [0.45, 0.62, 0.35], sunC: 0xfff0d6, sunI: 3.0, hemi: 1.1, hs: 0xdbe8ff, hg: 0x6b5f4f, night: 0, exp: 1.0 },
  dusk: { top: '#2e2d66', hor: '#f0a37c', fog: 0xb98f9a, sun: [-0.7, 0.12, 0.45], sunC: 0xffa36b, sunI: 1.4, hemi: 0.55, hs: 0x8f8fd6, hg: 0x4a3a4f, night: 0.8, exp: 1.1 },
  night: { top: '#081230', hor: '#24345e', fog: 0x1d2a4a, sun: [0.3, 0.5, -0.4], sunC: 0x9fb4ff, sunI: 0.35, hemi: 0.28, hs: 0x5a6fae, hg: 0x1c1c2a, night: 1, exp: 1.25 },
};
let nightF = 0;
function setTime(k) {
  const t = TIMES[k];
  skyU.top.value.set(t.top); skyU.hor.value.set(t.hor); skyU.sunDir.value.set(...t.sun).normalize(); skyU.sunCol.value.set(t.sunC);
  scene.fog.color.set(t.fog);
  sun.color.set(t.sunC); sun.intensity = t.sunI; hemi.intensity = t.hemi; hemi.color.set(t.hs); hemi.groundColor.set(t.hg);
  renderer.toneMappingExposure = t.exp;
  nightF = t.night;
  for (const m of Object.values(M)) if (m.userData && m.userData.night !== undefined) m.emissiveIntensity = nightF * m.userData.night + (1 - nightF) * (m.userData.day || 0);
  glowPts.material.opacity = Math.max(0, nightF - 0.2);
  for (const tr of trams) tr.m.traverse((o) => { if (o.userData.win) o.material.emissiveIntensity = nightF * 1.2; });
  document.querySelectorAll('[data-time]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.time === k)));
  try { localStorage.setItem('v6.time', k); } catch (e) { /* 私密窗口 */ }
}

// ---------------------------------------------------------------- 控制：鸟瞰 / 步行
const orbit = new OrbitControls(camera, canvas);
orbit.target.set(-160, 16, 230);
orbit.maxPolarAngle = Math.PI * 0.47; orbit.minDistance = 20; orbit.maxDistance = 2600; orbit.enableDamping = true;
orbit.update();
let mode = 'orbit';
const P = { x: 280, z: 430, y: LV.MID, yaw: -Math.PI / 2, pitch: -0.18, dist: 7 };
const keys = new Set();
function setMode(m) {
  mode = m;
  orbit.enabled = m === 'orbit';
  player.visible = m === 'walk';
  document.body.dataset.mode = m;
  document.querySelectorAll('[data-mode]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.mode === m)));
  if (m === 'walk') { camera.near = 0.2; } else { camera.near = 0.5; if (document.pointerLockElement) document.exitPointerLock(); }
  camera.updateProjectionMatrix();
}
function placePlayer(x, z, yaw) {
  const g = groundAt(x, z, 999);
  if (g === null) return false;
  P.x = x; P.z = z; P.y = g; if (yaw !== undefined) P.yaw = yaw;
  return true;
}
addEventListener('keydown', (e) => { if (e.target.closest('input,select,textarea')) return; keys.add(e.code); if (e.code === 'KeyM') toggleMap(); });
addEventListener('keyup', (e) => keys.delete(e.code));
let drag = null;
canvas.addEventListener('pointerdown', (e) => {
  if (mode !== 'walk') return;
  drag = { x: e.clientX, y: e.clientY };
  if (e.pointerType === 'mouse' && e.button === 0 && canvas.requestPointerLock) canvas.requestPointerLock()?.catch?.(() => {});
});
addEventListener('pointerup', () => { drag = null; });
addEventListener('pointermove', (e) => {
  if (mode !== 'walk') return;
  if (document.pointerLockElement === canvas) { P.yaw -= e.movementX * 0.0028; P.pitch = Math.max(-1.1, Math.min(0.5, P.pitch - e.movementY * 0.0022)); return; }
  if (!drag) return;
  P.yaw -= (e.clientX - drag.x) * 0.005; P.pitch = Math.max(-1.1, Math.min(0.5, P.pitch - (e.clientY - drag.y) * 0.004));
  drag = { x: e.clientX, y: e.clientY };
});
canvas.addEventListener('wheel', (e) => { if (mode === 'walk') { P.dist = Math.max(2.2, Math.min(28, P.dist * (e.deltaY > 0 ? 1.12 : 0.89))); e.preventDefault(); } }, { passive: false });
// 触屏方向键
const touchDir = { f: 0, r: 0 };
document.querySelectorAll('[data-pad]').forEach((b) => {
  const [f, r] = b.dataset.pad.split(',').map(Number);
  const on = (e) => { e.preventDefault(); touchDir.f = f; touchDir.r = r; };
  const off = () => { touchDir.f = 0; touchDir.r = 0; };
  b.addEventListener('pointerdown', on); b.addEventListener('pointerup', off); b.addEventListener('pointerleave', off); b.addEventListener('pointercancel', off);
});

function updateWalk(dt) {
  let f = (keys.has('KeyW') || keys.has('ArrowUp') ? 1 : 0) - (keys.has('KeyS') || keys.has('ArrowDown') ? 1 : 0) + touchDir.f;
  let r = (keys.has('KeyD') || keys.has('ArrowRight') ? 1 : 0) - (keys.has('KeyA') || keys.has('ArrowLeft') ? 1 : 0) + touchDir.r;
  if (keys.has('KeyQ')) P.yaw += dt * 1.8;
  if (keys.has('KeyE')) P.yaw -= dt * 1.8;
  const run = keys.has('ShiftLeft') || keys.has('ShiftRight');
  const sp = (run ? 9 : 4.2) * dt;
  if (f || r) {
    const l = Math.hypot(f, r); f /= l; r /= l;
    const fx = Math.sin(P.yaw), fz = Math.cos(P.yaw);
    const dx = (fx * f - fz * r) * sp, dz = (fz * f + fx * r) * sp;
    const subs = Math.ceil(Math.hypot(dx, dz) / 0.4);
    for (let i = 0; i < subs; i++) { const n = step(P.x, P.z, P.y, dx / subs, dz / subs); P.x = n[0]; P.z = n[1]; P.y = n[2]; }
    player.rotation.y = Math.atan2(dx, dz);
  }
  player.position.set(P.x, P.y, P.z);
  // 第三人称相机：躲开地基与建筑太近时拉近
  const cd = P.dist, cp = Math.cos(P.pitch);
  const tx = P.x, ty = P.y + 1.55, tz = P.z;
  camera.position.set(tx - Math.sin(P.yaw) * cd * cp, ty - Math.sin(P.pitch) * cd + 0.4, tz - Math.cos(P.yaw) * cd * cp);
  const gnd = groundAt(camera.position.x, camera.position.z, camera.position.y);
  if (gnd !== null && camera.position.y < gnd + 0.6) camera.position.y = gnd + 0.6;
  camera.lookAt(tx, ty, tz);
}

// ---------------------------------------------------------------- 标签
const labelLayer = $('#labels');
const labels = [];
function addLabel(text, sub, x, y, z, kind, extra = {}) {
  const el = document.createElement('div');
  el.className = 'lbl lbl-' + kind;
  el.innerHTML = `<b>${text}</b>${sub ? `<span>${sub}</span>` : ''}`;
  labelLayer.appendChild(el);
  labels.push({ el, p: new THREE.Vector3(x, y, z), kind, ...extra });
}
for (const lm of LANDMARKS) if (!lm.orn) addLabel(lm.name, lm.func, lm.x, (lm.level || 16) + Math.min(lm.h + 10, 60), lm.z, 'lm');
for (const d of DISTRICT_LABELS) addLabel(d.name, null, d.x, 70, d.z, 'district', { color: DISTRICTS[d.district].color });
for (const s of STREET_LABELS) { const g = groundAt(s.x, s.z, 999) ?? 16; addLabel(s.name, null, s.x, g + 2, s.z, 'street'); }
for (const l of LOTS) if (l.label && l.signPos) addLabel(l.label, null, l.signPos[0], l.signPos[1] + 0.6, l.signPos[2], 'shop');
for (const s of STAIRS) if (s.name !== '码头阶梯' && s.name !== '东码头阶梯') addLabel(s.name, `${s.h0}m → ${s.h1}m`, s.top[0], s.h1 + 3, s.top[1], 'street');
labels.forEach((l) => { if (l.color) l.el.style.setProperty('--dc', l.color); });
const showLabels = { on: true };
const v3 = new THREE.Vector3();
function updateLabels() {
  const W = innerWidth, H = innerHeight;
  const cd = camera.position.distanceTo(orbit.target);
  for (const l of labels) {
    let vis = showLabels.on;
    const d = camera.position.distanceTo(l.p);
    if (mode === 'orbit') {
      if (l.kind === 'district') vis &&= cd > 650;
      else if (l.kind === 'lm') { vis &&= cd <= 650 && d < 900; l.el.classList.toggle('brief', cd > 260); }
      else if (l.kind === 'street') vis &&= cd < 260 && d < 500;
      else vis &&= d < 160;
    } else {
      if (l.kind === 'district') vis = false;
      else if (l.kind === 'lm') vis &&= d < 220;
      else if (l.kind === 'street') vis &&= d < 120;
      else vis &&= d < 60;
    }
    if (vis) {
      v3.copy(l.p).project(camera);
      if (v3.z > 1 || Math.abs(v3.x) > 1.1 || Math.abs(v3.y) > 1.1) vis = false;
      else l.el.style.transform = `translate(${((v3.x + 1) / 2) * W}px, ${((1 - v3.y) / 2) * H}px) translate(-50%, -100%)`;
    }
    l.el.hidden = !vis;
  }
}

// ---------------------------------------------------------------- 小地图
const mm = $('#minimap'), mg = mm.getContext('2d');
const MAPB = [EXTENT.x0 - 30, EXTENT.z0 - 30, EXTENT.x1 + 30, EXTENT.z1 + 90];
const mapBase = document.createElement('canvas');
function mapXY(x, z) { const w = mm.width, h = mm.height; return [((x - MAPB[0]) / (MAPB[2] - MAPB[0])) * w, ((z - MAPB[1]) / (MAPB[3] - MAPB[1])) * h]; }
function drawMapBase() {
  mm.width = mm.clientWidth * devicePixelRatio; mm.height = mm.clientHeight * devicePixelRatio;
  mapBase.width = mm.width; mapBase.height = mm.height;
  const g = mapBase.getContext('2d');
  g.fillStyle = '#2d6f82'; g.fillRect(0, 0, mm.width, mm.height);
  const lvCol = { [LV.QUAY]: '#9c9381', [LV.LOW]: '#b3a88f', [LV.MID]: '#c9bea2', [LV.UP]: '#ddd2b5', [LV.TOP]: '#efe5c8' };
  const poly = (pts, fill, stroke) => { g.beginPath(); pts.forEach((p, i) => { const [x, y] = mapXY(p[0], p[1]); i ? g.lineTo(x, y) : g.moveTo(x, y); }); g.closePath(); if (fill) { g.fillStyle = fill; g.fill(); } if (stroke) { g.strokeStyle = stroke; g.lineWidth = devicePixelRatio; g.stroke(); } };
  for (const t of TERRACES) poly(t.poly, t.outer ? '#6f8f5a' : lvCol[t.level], 'rgba(60,45,30,0.5)');
  for (const b of BLOCKS) poly(b.poly, b.use === 'park' ? '#7fa565' : b.use === 'square' ? '#e9e1cf' : DISTRICTS[b.district].color, null);
  for (const l of LOTS) poly(l.poly, 'rgba(40,30,25,0.28)', null);
  for (const l of LANDMARKS) poly(l.footprint, '#4b2f22', null);
  for (const d of DECKS) { g.strokeStyle = '#e8dcc0'; g.lineWidth = d.width / (MAPB[2] - MAPB[0]) * mm.width; g.beginPath(); d.pts.forEach((p, i) => { const [x, y] = mapXY(p[0], p[1]); i ? g.lineTo(x, y) : g.moveTo(x, y); }); g.stroke(); }
  for (const w of WAYSTONES) { const [x, y] = mapXY(w.x, w.z), r = 4 * devicePixelRatio; g.fillStyle = '#7fe0ff'; g.strokeStyle = '#123'; g.lineWidth = devicePixelRatio; g.beginPath(); g.moveTo(x, y - r); g.lineTo(x + r, y); g.lineTo(x, y + r); g.lineTo(x - r, y); g.closePath(); g.fill(); g.stroke(); }
  g.fillStyle = '#e8dcc0'; { const [x, y] = mapXY(PLAZA.x, PLAZA.z); g.beginPath(); g.arc(x, y, PLAZA.monument / (MAPB[2] - MAPB[0]) * mm.width, 0, 7); g.fill(); }
}
function drawMap() {
  mg.drawImage(mapBase, 0, 0);
  const tx = mode === 'walk' ? P.x : orbit.target.x, tz = mode === 'walk' ? P.z : orbit.target.z;
  const [x, y] = mapXY(tx, tz), dpr = devicePixelRatio;
  const yaw = mode === 'walk' ? P.yaw : Math.atan2(orbit.target.x - camera.position.x, orbit.target.z - camera.position.z);
  mg.save(); mg.translate(x, y); mg.rotate(-yaw + Math.PI);
  mg.fillStyle = '#f3c860'; mg.strokeStyle = '#1b2233'; mg.lineWidth = 1.5 * dpr;
  mg.beginPath(); mg.moveTo(0, -8 * dpr); mg.lineTo(5 * dpr, 6 * dpr); mg.lineTo(0, 3 * dpr); mg.lineTo(-5 * dpr, 6 * dpr); mg.closePath(); mg.fill(); mg.stroke();
  mg.restore();
}
mm.addEventListener('click', (e) => {
  const r = mm.getBoundingClientRect();
  const x = MAPB[0] + ((e.clientX - r.left) / r.width) * (MAPB[2] - MAPB[0]);
  const z = MAPB[1] + ((e.clientY - r.top) / r.height) * (MAPB[3] - MAPB[1]);
  goTo(x, z);
});
function toggleMap() { $('#mapwrap').classList.toggle('big'); requestAnimationFrame(() => { drawMapBase(); }); }
$('#mapsize').addEventListener('click', toggleMap);

// ---------------------------------------------------------------- 跳转
function goTo(x, z, yaw) {
  if (mode === 'walk') {
    // 找最近可站立点
    for (let r = 0; r < 40; r += 2) for (let a = 0; a < 8; a++) {
      const px = x + Math.cos(a) * r, pz = z + Math.sin(a) * r;
      if (placePlayer(px, pz, yaw)) return;
    }
  } else {
    const g = groundAt(x, z, 999) ?? 16;
    const off = camera.position.clone().sub(orbit.target);
    orbit.target.set(x, g, z);
    if (off.length() > 600) off.setLength(360);
    camera.position.copy(orbit.target).add(off);
  }
}
function goLandmark(lm) {
  const fx = Math.sin(lm.yaw), fz = Math.cos(lm.yaw);
  const x = lm.x + fx * (lm.d / 2 + 14), z = lm.z + fz * (lm.d / 2 + 14);
  if (mode === 'walk') goTo(x, z, Math.atan2(-fx, -fz));
  else {
    const g = lm.level || 16;
    orbit.target.set(lm.x, g + lm.h * 0.4, lm.z);
    camera.position.set(lm.x + fx * (lm.d + 70) + fz * 30, g + lm.h + 45, lm.z + fz * (lm.d + 70) - fx * 30);
  }
}

// ---------------------------------------------------------------- 规划面板
function buildPanel() {
  const st = stats();
  $('#st-blocks').textContent = st.blocks; $('#st-lots').textContent = st.lots; $('#st-lm').textContent = st.landmarks; $('#st-stairs').textContent = st.stairs + st.decks;
  const lv = [['王宫高地 · 使馆区', LV.TOP], ['魔法区 · 学院 · 圣堂海岬', LV.UP], ['中心台 · 旧城 · 军营 · 公园', LV.MID], ['港街台 · 车站台', LV.LOW], ['码头 · 防波堤', LV.QUAY]];
  $('#levels').innerHTML = lv.map(([n, h]) => `<li><span class="lvbar" style="--h:${h / 30}"></span><b>${h} m</b><span>${n}</span></li>`).join('');
  $('#roads').innerHTML = ['B', 'A', 'S', 'L'].map((k) => `<li><b>${ROAD[k].name}</b><span>车行道 ${ROAD[k].c} m · 人行道 2 × ${ROAD[k].sw} m</span></li>`).join('');
  const groups = {};
  for (const lm of LANDMARKS) { if (lm.orn) continue; const b = BLOCKS.find((q) => q.id === lm.block); const d = b ? b.district : lm.type === 'gate' ? 'gate' : lm.type === 'lighthouse' ? 'harbor' : 'trade'; (groups[d] ||= []).push(lm); }
  const order = ['royal', 'mage', 'oldtown', 'military', 'cpark', 'core', 'trade', 'artisan', 'hero', 'academy', 'nobles', 'cape', 'harbor', 'station', 'park', 'gate'];
  $('#lmlist').innerHTML = order.filter((d) => groups[d]).map((d) => `<li class="grp"><h4><i style="background:${DISTRICTS[d]?.color || '#888'}"></i>${DISTRICTS[d]?.name || '城门'}</h4><ul>${groups[d].map((l) => `<li><button type="button" data-lm="${l.id}"><b>${l.name}</b><span>${l.func}</span></button></li>`).join('')}</ul></li>`).join('');
  $('#lmlist').addEventListener('click', (e) => { const b = e.target.closest('[data-lm]'); if (b) { goLandmark(LANDMARKS.find((l) => l.id === b.dataset.lm)); if (innerWidth < 760) $('#panel').classList.remove('open'); } });
}
buildPanel();

// ---------------------------------------------------------------- 传送石：面板列表 + 靠近按 F 打开目的地菜单
for (const w of WAYSTONES) addLabel('◆ ' + w.name, '传送石', w.x, w.y + 5.2, w.z, 'street');
const wsHint = document.createElement('div'); wsHint.id = 'ws-hint'; wsHint.hidden = true; wsHint.textContent = '按 F 使用传送石'; document.body.appendChild(wsHint);
const wsMenu = document.createElement('div'); wsMenu.id = 'ws-menu'; wsMenu.hidden = true; document.body.appendChild(wsMenu);
function wsLand(w) { // 落点：石头南侧 3.2m 处，找不到就就近
  for (const a of [Math.PI / 2, 0, Math.PI, -Math.PI / 2]) { const x = w.x + Math.cos(a) * 3.4, z = w.z + Math.sin(a) * 3.4; const g = groundAt(x, z, w.y + 0.7); if (g !== null && Math.abs(g - w.y) < 0.7) return [x, z, Math.atan2(w.x - x, w.z - z)]; }
  return [w.x, w.z + 4, Math.PI];
}
function wsTravel(w) {
  wsMenu.hidden = true;
  const [x, z, yaw] = wsLand(w);
  if (mode === 'walk') { placePlayer(x, z, yaw) || goTo(x, z, yaw); } else goTo(w.x, w.z);
}
function wsNear() { if (mode !== 'walk') return null; let best = null; for (const w of WAYSTONES) { const d = Math.hypot(P.x - w.x, P.z - w.z); if (d < 4.5 && Math.abs(P.y - w.y) < 2 && (!best || d < best.d)) best = { w, d }; } return best && best.w; }
function wsOpen(from) {
  wsMenu.innerHTML = `<h4>传送石 · ${from ? from.name : '城内快速移动'}</h4><ul>${WAYSTONES.filter((w) => w !== from).map((w) => `<li><button type="button" data-ws="${w.id}">${w.name}</button></li>`).join('')}</ul><button type="button" class="ws-close">关闭 (Esc)</button>`;
  wsMenu.hidden = false;
  if (document.pointerLockElement) document.exitPointerLock();
}
wsMenu.addEventListener('click', (e) => { const b = e.target.closest('[data-ws]'); if (b) wsTravel(WAYSTONES.find((w) => w.id === b.dataset.ws)); else if (e.target.closest('.ws-close')) wsMenu.hidden = true; });
addEventListener('keydown', (e) => {
  if (e.code === 'Escape') wsMenu.hidden = true;
  if (e.code === 'KeyF' && !e.repeat) { const w = wsNear(); if (w) { if (wsMenu.hidden) wsOpen(w); else wsMenu.hidden = true; } }
});
{
  const sec = document.createElement('section'); sec.className = 'ws-sec';
  sec.innerHTML = `<h3>传送石 <small>${WAYSTONES.length} 座 · 步行模式靠近按 F</small></h3><ul class="ws-list">${WAYSTONES.map((w) => `<li><button type="button" data-ws="${w.id}">◆ ${w.name}</button></li>`).join('')}</ul>`;
  const anchor = $('#lmlist').closest('section') || $('#lmlist').parentElement;
  anchor.parentElement.insertBefore(sec, anchor);
  sec.addEventListener('click', (e) => { const b = e.target.closest('[data-ws]'); if (b) { wsTravel(WAYSTONES.find((w) => w.id === b.dataset.ws)); if (innerWidth < 760) $('#panel').classList.remove('open'); } });
}
window.__ws = { list: WAYSTONES, travel: (id) => wsTravel(WAYSTONES.find((w) => w.id === id)), near: () => wsNear() };

document.querySelectorAll('[data-mode]').forEach((b) => b.addEventListener('click', () => {
  if (b.dataset.mode === 'walk' && mode !== 'walk') {
    const t = orbit.target;
    let ok = false;
    for (let r = 0; r < 60 && !ok; r += 3) for (let a = 0; a < 12 && !ok; a++) ok = placePlayer(t.x + Math.cos(a / 2) * r, t.z + Math.sin(a / 2) * r);
    if (!ok) placePlayer(260, 430, -Math.PI / 2);
    P.yaw = Math.atan2(t.x - camera.position.x, t.z - camera.position.z);
  }
  if (b.dataset.mode === 'orbit' && mode === 'walk') { orbit.target.set(P.x, P.y, P.z); camera.position.set(P.x - Math.sin(P.yaw) * 90, P.y + 70, P.z - Math.cos(P.yaw) * 90); }
  setMode(b.dataset.mode);
}));
document.querySelectorAll('[data-time]').forEach((b) => b.addEventListener('click', () => setTime(b.dataset.time)));
$('#tg-labels').addEventListener('change', (e) => { showLabels.on = e.target.checked; });
$('#tg-people').addEventListener('change', (e) => { people.visible = e.target.checked; });
$('#tg-shadow').addEventListener('change', (e) => { sun.castShadow = e.target.checked; });
// 白模：城市网格换成统一的灰白黏土材质，用来审体量与天际线
const clay = new THREE.MeshStandardMaterial({ color: 0xf1eee8, roughness: 0.95 });
const clayGlass = new THREE.MeshStandardMaterial({ color: 0xc9d6dc, roughness: 0.6 });
function setWhitebox(on) {
  city.root.traverse((o) => {
    if (!o.isMesh || !o.geometry.attributes.color) return;
    if (on) { o.userData.mat ||= o.material; o.material = o.userData.mat.transparent ? clayGlass : clay; }
    else if (o.userData.mat) o.material = o.userData.mat;
  });
  document.body.classList.toggle('whitebox', on);
  try { localStorage.setItem('v7.white', on ? '1' : '0'); } catch (e) { /* 无存储 */ }
}
$('#tg-white').addEventListener('change', (e) => setWhitebox(e.target.checked));
try { if (localStorage.getItem('v7.white') === '1') { $('#tg-white').checked = true; setWhitebox(true); } } catch (e) { /* 无存储 */ }
$('#panel-toggle').addEventListener('click', () => $('#panel').classList.toggle('open'));
$('#panel-close').addEventListener('click', () => $('#panel').classList.remove('open'));

// ---------------------------------------------------------------- HUD
const hud = $('#hud-pos'), hudArea = $('#hud-area');
function areaAt(x, z) {
  for (const b of BLOCKS) if (pointInPoly([x, z], inset(b.poly, -12))) return DISTRICTS[b.district].name;
  for (const t of TERRACES) if (pointInPoly([x, z], t.poly)) return t.name;
  return '港湾水域';
}
let hudT = 0;

// ---------------------------------------------------------------- 主循环
function resize() { const w = innerWidth, h = innerHeight; renderer.setSize(w, h, false); camera.aspect = w / h; camera.updateProjectionMatrix(); drawMapBase(); }
addEventListener('resize', resize);
resize();
let time0 = performance.now(), simT = 0;
const tmpM = new THREE.Matrix4(), tmpQ = new THREE.Quaternion(), tmpS = new THREE.Vector3(1, 1, 1), tmpP = new THREE.Vector3(), up = new THREE.Vector3(0, 1, 0);
function frame(now) {
  const dt = Math.min(0.05, (now - time0) / 1000); time0 = now; simT += dt;
  if (mode === 'walk') updateWalk(dt); else orbit.update();
  // 阴影相机跟随视点
  const focus = mode === 'walk' ? new THREE.Vector3(P.x, P.y, P.z) : orbit.target;
  sun.position.copy(focus).add(skyU.sunDir.value.clone().multiplyScalar(700));
  sun.target.position.copy(focus);
  // 行人
  if (people.visible) {
    walkers.forEach((w, i) => {
      w.s += w.v * dt;
      const [x, z, yaw] = posOnLoop(w);
      tmpP.set(x, w.y, z); tmpQ.setFromAxisAngle(up, yaw + (w.v < 0 ? Math.PI : 0));
      tmpM.compose(tmpP, tmpQ, tmpS); people.setMatrixAt(i, tmpM);
    });
    people.instanceMatrix.needsUpdate = true;
  }
  // 电车往返
  const total = tramLen[tramLen.length - 1];
  for (const tr of trams) {
    tr.s += tr.v * dt;
    if (tr.s > total) { tr.s = total; tr.v = -Math.abs(tr.v); } else if (tr.s < 0) { tr.s = 0; tr.v = Math.abs(tr.v); }
    const [x, y, z, yaw] = tramAt(tr.s);
    tr.m.position.set(x, y, z); tr.m.rotation.y = yaw;
  }
  // 高架列车
  {
    const tot = vLen[vLen.length - 1], s = (simT * 16) % (tot * 2), ss = s > tot ? tot * 2 - s : s;
    let i = 1; while (i < vLen.length - 1 && vLen[i] < ss) i++;
    const a = vPts[i - 1], b = vPts[i], t = (ss - vLen[i - 1]) / (vLen[i] - vLen[i - 1]);
    train.position.set(a[0] + (b[0] - a[0]) * t, LV.LOW + VIADUCT.h, a[1] + (b[1] - a[1]) * t);
    train.rotation.y = Math.atan2(b[0] - a[0], b[1] - a[1]) + (s > tot ? Math.PI : 0);
  }
  // 缆车
  const [CA, CB] = CABLEWAY.pts;
  for (const g of gondolas) {
    const t = (g.userData.p + simT * 0.012) % 1;
    g.position.set(CA[0] + (CB[0] - CA[0]) * t, CA[2] + (CB[2] - CA[2]) * t - Math.sin(Math.PI * t) * 6 - 2.6, CA[1] + (CB[1] - CA[1]) * t);
    g.rotation.y = Math.atan2(CB[0] - CA[0], CB[1] - CA[1]);
  }
  airships.forEach((g, i) => { const a = g.userData; if (a.moored) { g.position.y = a.y + Math.sin(simT * 0.5) * 0.4; return; } const r = 160 + i * 40, w = 0.012; g.position.set(a.x + Math.cos(simT * w + i) * r, a.y + Math.sin(simT * 0.3) * 3, a.z + Math.sin(simT * w + i) * r); g.rotation.y = -simT * w - i + Math.PI; });
  balloons.forEach((g) => { const [x, y, z, i] = g.userData.base; g.position.set(x + Math.sin(simT * 0.05 + i) * 40, y + Math.sin(simT * 0.4 + i) * 4, z + Math.cos(simT * 0.04 + i) * 30); });
  // 夜间：最近的路灯点亮真实光源
  if (nightF > 0.3) {
    const c = focus;
    const near = LAMPS.map((l, i) => [Math.hypot(l.x - c.x, l.z - c.z), i]).sort((a, b) => a[0] - b[0]).slice(0, lampLights.length);
    near.forEach(([d, i], k) => { const l = LAMPS[i]; lampLights[k].position.set(l.x + Math.sin(l.yaw) * 0.95, l.y + 3.8, l.z + Math.cos(l.yaw) * 0.95); lampLights[k].intensity = 18 * nightF; });
  } else lampLights.forEach((l) => { l.intensity = 0; });
  renderer.render(scene, camera);
  updateLabels();
  drawMap();
  wsHint.hidden = !wsNear() || !wsMenu.hidden;
  hudT -= dt;
  if (hudT < 0) {
    hudT = 0.2;
    const x = mode === 'walk' ? P.x : orbit.target.x, z = mode === 'walk' ? P.z : orbit.target.z, y = mode === 'walk' ? P.y : orbit.target.y;
    hud.textContent = `X ${x.toFixed(0)}  Z ${z.toFixed(0)}  标高 ${y.toFixed(1)} m`;
    hudArea.textContent = areaAt(x, z);
  }
  requestAnimationFrame(frame);
}
let t0 = 'day'; try { t0 = localStorage.getItem('v6.time') || 'day'; } catch (e) { /* 无存储 */ }
setTime(TIMES[t0] ? t0 : 'day');
setMode('orbit');
document.body.classList.add('ready');
say('');
window.__city = { HALLS, THREE, scene, city, setWhitebox, M, camera, orbit, setMode, goTo, goLandmark, P, setTime, LANDMARKS, placePlayer, keys };
requestAnimationFrame(frame);
void centroid; void bbox; void STAIRS;
