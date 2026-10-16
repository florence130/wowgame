// MeshBuilder：把所有几何按 材质 × 200m 分块 合并成少量网格。
import * as THREE from 'three';
import { inwardNormal } from './geo2d.js';

const CH = 200;
export const chunkKey = (x, z) => `${Math.floor(x / CH)}_${Math.floor(z / CH)}`;
const v = new THREE.Vector3(), w = new THREE.Vector3(), u = new THREE.Vector3(), nn = new THREE.Vector3();

export class MB {
  constructor() { this.b = new Map(); this.M = new THREE.Matrix4(); this.N = new THREE.Matrix3(); this.ck = '0_0'; this.tf = false; }
  at(x, y, z, yaw = 0, s = 1) {
    this.M.makeRotationY(yaw); if (s !== 1) this.M.scale(new THREE.Vector3(s, s, s)); this.M.setPosition(x, y, z);
    this.N.getNormalMatrix(this.M); this.ck = chunkKey(x, z); this.tf = true; return this;
  }
  // 在当前变换下再叠一个局部平移 / 旋转（大型组合建筑的子体块用）
  push(dx, dy, dz, yaw = 0) {
    (this._st ||= []).push([this.M.clone(), this.N.clone(), this.tf]);
    this.M.multiply(new THREE.Matrix4().makeRotationY(yaw).setPosition(dx, dy, dz));
    this.N.getNormalMatrix(this.M); this.tf = true; return this;
  }
  pop() { const [M, N, tf] = this._st.pop(); this.M.copy(M); this.N.copy(N); this.tf = tf; return this; }
  world(x = 0, z = 0) { this.M.identity(); this.N.identity(); this.tf = false; this.ck = chunkKey(x, z); return this; }
  bk(mat) {
    if (this.pfx) mat = this.pfx + mat;      // 前缀 'LF:' = 远景代理（模块化沿街楼的远处白模），导出时单独成节点
    const k = mat + '|' + this.ck;
    let o = this.b.get(k);
    if (!o) { o = { mat, p: [], n: [], u: [], c: [] }; this.b.set(k, o); }
    return o;
  }
  // a,b,c: [x,y,z] 局部坐标；uvs: [[u,v]x3]；col: [r,g,b]；ns: 可选平滑法线
  tri(mat, a, b, c, uvs, col, ns) {
    const o = this.bk(mat);
    const P = [a, b, c].map((p) => { v.set(p[0], p[1], p[2]); if (this.tf) v.applyMatrix4(this.M); return [v.x, v.y, v.z]; });
    let N3;
    if (ns) N3 = ns.map((q) => { nn.set(q[0], q[1], q[2]); if (this.tf) nn.applyMatrix3(this.N); nn.normalize(); return [nn.x, nn.y, nn.z]; });
    else {
      v.set(...P[0]); w.set(...P[1]).sub(v); u.set(...P[2]).sub(v); w.cross(u).normalize();
      N3 = [[w.x, w.y, w.z], [w.x, w.y, w.z], [w.x, w.y, w.z]];
    }
    for (let i = 0; i < 3; i++) {
      o.p.push(P[i][0], P[i][1], P[i][2]); o.n.push(N3[i][0], N3[i][1], N3[i][2]);
      const uv = uvs ? uvs[i] : [0, 0]; o.u.push(uv[0], uv[1]);
      o.c.push(col[0], col[1], col[2]);
    }
  }
  quad(mat, a, b, c, d, uvs, col, ns) {
    const U = uvs || [[0, 0], [1, 0], [1, 1], [0, 1]];
    this.tri(mat, a, b, c, [U[0], U[1], U[2]], col, ns && [ns[0], ns[1], ns[2]]);
    this.tri(mat, a, c, d, [U[0], U[2], U[3]], col, ns && [ns[0], ns[2], ns[3]]);
  }
  // 平面多边形（凸），按 hint 方向定朝向
  face(mat, pts, col, hint, uvf) {
    const a = pts[0], b = pts[1], c = pts[2];
    const e1 = [b[0] - a[0], b[1] - a[1], b[2] - a[2]], e2 = [c[0] - a[0], c[1] - a[1], c[2] - a[2]];
    const n = [e1[1] * e2[2] - e1[2] * e2[1], e1[2] * e2[0] - e1[0] * e2[2], e1[0] * e2[1] - e1[1] * e2[0]];
    const P = n[0] * hint[0] + n[1] * hint[1] + n[2] * hint[2] < 0 ? [...pts].reverse() : pts;
    const uv = (p) => (uvf ? uvf(p) : [0, 0]);
    for (let i = 1; i + 1 < P.length; i++) this.tri(mat, P[0], P[i], P[i + 1], [uv(P[0]), uv(P[i]), uv(P[i + 1])], col);
  }
  // 朝上（或朝下）的平面四边形，平面 UV
  up(mat, pts, col, s = 3, down = false) { this.face(mat, pts, col, [0, down ? -1 : 1, 0], (p) => [p[0] / s, p[2] / s]); }
  // 竖墙：二维边 a→b，向外（out 为外法线）
  // 门洞：cuts 为世界坐标的门洞体 {o:[x,z] 门洞外立面中点, ax 沿立面单位向量, an 外法线, hw 半宽, y0, y1, din 向内深, dout 向外深}
  // 与门洞平行、位于门洞深度范围内的竖墙被拆成「左段 + 右段 + 门楣上段 + 门槛下段」
  _cut(a, b, y0, y1) {
    if (!this.cuts || !this.cuts.length) return null;
    const M = this.M.elements, ty = this.tf ? M[13] : 0;
    const W = (p) => (this.tf ? [M[0] * p[0] + M[8] * p[1] + M[12], M[2] * p[0] + M[10] * p[1] + M[14]] : p);
    const A = W(a), B = W(b), wy0 = y0 + ty, wy1 = y1 + ty;
    for (const c of this.cuts) {
      if (wy1 <= c.y0 + 0.01 || wy0 >= c.y1 - 0.01) continue;
      const dA = [A[0] - c.o[0], A[1] - c.o[1]], dB = [B[0] - c.o[0], B[1] - c.o[1]];
      const vA = dA[0] * c.an[0] + dA[1] * c.an[1], vB = dB[0] * c.an[0] + dB[1] * c.an[1];
      if (Math.abs(vA - vB) > 0.3 || vA < -c.din || vA > c.dout) continue;
      const uA = dA[0] * c.ax[0] + dA[1] * c.ax[1], uB = dB[0] * c.ax[0] + dB[1] * c.ax[1];
      if (Math.abs(uB - uA) < 0.01) continue;
      let t1 = (-c.hw - uA) / (uB - uA), t2 = (c.hw - uA) / (uB - uA);
      if (t1 > t2) [t1, t2] = [t2, t1];
      if (t2 <= 0.001 || t1 >= 0.999) continue;
      return { t1: Math.max(0, t1), t2: Math.min(1, t2), y0: c.y0 - ty, y1: c.y1 - ty };
    }
    return null;
  }
  wall(mat, a, b, y0, y1, col, out, uvw = [4, 4], u0 = 0, v0 = null) {
    const cut = this._cut(a, b, y0, y1);
    if (cut) {
      const L = Math.hypot(b[0] - a[0], b[1] - a[1]);
      const P = (t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];
      const vb = v0 === null ? y0 : v0, saved = this.cuts;
      this.cuts = null;
      if (cut.t1 > 0.001) this.wall(mat, a, P(cut.t1), y0, y1, col, out, uvw, u0, vb);
      if (cut.t2 < 0.999) this.wall(mat, P(cut.t2), b, y0, y1, col, out, uvw, u0 + L * cut.t2, vb);
      if (y1 > cut.y1) this.wall(mat, P(cut.t1), P(cut.t2), Math.max(y0, cut.y1), y1, col, out, uvw, u0 + L * cut.t1, vb);
      if (y0 < cut.y0) this.wall(mat, P(cut.t1), P(cut.t2), y0, Math.min(y1, cut.y0), col, out, uvw, u0 + L * cut.t1, vb);
      this.cuts = saved;
      return;
    }
    this._wall(mat, a, b, y0, y1, col, out, uvw, u0, v0);
  }
  _wall(mat, a, b, y0, y1, col, out, uvw = [4, 4], u0 = 0, v0 = null) {
    const dx = b[0] - a[0], dz = b[1] - a[1], L = Math.hypot(dx, dz);
    const vb = v0 === null ? y0 : v0;
    let A = a, B = b, uA = u0, uB = u0 + L;
    if ((-dz) * out[0] + dx * out[1] < 0) { A = b; B = a; uA = u0 + L; uB = u0; }
    const V0 = (y0 - vb) / uvw[1], V1 = (y1 - vb) / uvw[1];
    this.quad(mat, [A[0], y0, A[1]], [B[0], y0, B[1]], [B[0], y1, B[1]], [A[0], y1, A[1]],
      [[uA / uvw[0], V0], [uB / uvw[0], V0], [uB / uvw[0], V1], [uA / uvw[0], V1]], col);
  }
  // 水平面（任意简单多边形）
  cap(mat, poly, y, col, scale = 4, down = false) {
    const tris = THREE.ShapeUtils.triangulateShape(poly.map((p) => new THREE.Vector2(p[0], p[1])), []);
    for (const [i, j, k] of tris) {
      const A = [poly[i][0], y, poly[i][1]], B = [poly[j][0], y, poly[j][1]], C = [poly[k][0], y, poly[k][1]];
      const ny = (B[2] - A[2]) * (C[0] - A[0]) - (B[0] - A[0]) * (C[2] - A[2]);
      const up = ny > 0;
      const T = up !== down ? [A, B, C] : [A, C, B];
      this.tri(mat, T[0], T[1], T[2], T.map((p) => [p[0] / scale, p[2] / scale]), col);
    }
  }
  // 挤出多边形
  prism(mat, poly, y0, y1, col, o = {}) {
    const n = poly.length;
    let run = 0;
    for (let i = 0; i < n; i++) {
      const a = poly[i], b = poly[(i + 1) % n];
      const inn = inwardNormal(poly, i);
      this.wall(o.wallMat || mat, a, b, y0, y1, col, [-inn[0], -inn[1]], o.uv || [4, 4], o.cont ? run : 0, o.v0 ?? null);
      run += Math.hypot(b[0] - a[0], b[1] - a[1]);
    }
    if (o.top !== false) this.cap(o.topMat || mat, poly, y1, o.topCol || col, o.topScale || 4);
    if (o.bottom) this.cap(mat, poly, y0, col, 4, true);
  }
  box(mat, cx, y0, cz, w, h, d, col, yaw = 0, o = {}) {
    const c = Math.cos(yaw), s = Math.sin(yaw);
    const P = [[-w / 2, -d / 2], [w / 2, -d / 2], [w / 2, d / 2], [-w / 2, d / 2]].map(([x, z]) => [cx + c * x + s * z, cz - s * x + c * z]);
    this.prism(mat, P, y0, y0 + h, col, { uv: o.uv || [2, 2], ...o });
  }
  // 圆柱 / 圆台（r1=0 为圆锥），平滑法线
  cyl(mat, cx, y0, cz, r0, r1, h, seg, col, o = {}) {
    const slope = (r0 - r1) / h;
    for (let i = 0; i < seg; i++) {
      const a0 = (i / seg) * Math.PI * 2, a1 = ((i + 1) / seg) * Math.PI * 2;
      const p = (a, r, y) => [cx + Math.cos(a) * r, y, cz + Math.sin(a) * r];
      const nr = (a) => { const l = Math.hypot(1, slope); return [Math.cos(a) / l, slope / l, Math.sin(a) / l]; };
      const uvs = [[i / seg * (o.uRep || 1), 0], [(i + 1) / seg * (o.uRep || 1), 0], [(i + 1) / seg * (o.uRep || 1), h / (o.vScale || 4)], [i / seg * (o.uRep || 1), h / (o.vScale || 4)]];
      if (r1 > 0.001) this.quad(mat, p(a0, r0, y0), p(a0, r1, y0 + h), p(a1, r1, y0 + h), p(a1, r0, y0), [uvs[0], uvs[3], uvs[2], uvs[1]], col, [nr(a0), nr(a0), nr(a1), nr(a1)]);
      else this.tri(mat, p(a0, r0, y0), p(a0, 0, y0 + h), p(a1, r0, y0), [uvs[0], uvs[3], uvs[1]], col, [nr(a0), [0, 1, 0], nr(a1)]);
      if (o.top && r1 > 0.001) this.tri(o.topMat || mat, [cx, y0 + h, cz], p(a1, r1, y0 + h), p(a0, r1, y0 + h), null, o.topCol || col);
      if (o.bottom) this.tri(mat, [cx, y0, cz], p(a0, r0, y0), p(a1, r0, y0), null, col);
    }
  }
  // 旋转体：profile = [[r, y], ...]（自下而上）
  lathe(mat, cx, y0, cz, prof, seg, col, uScale = 1) {
    for (let k = 0; k + 1 < prof.length; k++) {
      const [ra, ya] = prof[k], [rb, yb] = prof[k + 1];
      const dr = rb - ra, dy = yb - ya, l = Math.hypot(dr, dy) || 1;
      for (let i = 0; i < seg; i++) {
        const a0 = (i / seg) * Math.PI * 2, a1 = ((i + 1) / seg) * Math.PI * 2;
        const p = (a, r, y) => [cx + Math.cos(a) * r, y0 + y, cz + Math.sin(a) * r];
        const nr = (a) => [Math.cos(a) * dy / l, -dr / l, Math.sin(a) * dy / l];
        const uv = [[i / seg * uScale, ya / 3], [(i + 1) / seg * uScale, ya / 3], [(i + 1) / seg * uScale, yb / 3], [i / seg * uScale, yb / 3]];
        if (rb < 0.001) this.tri(mat, p(a0, ra, ya), p(a0, 0, yb), p(a1, ra, ya), [uv[0], uv[3], uv[1]], col, [nr(a0), [0, 1, 0], nr(a1)]);
        else if (ra < 0.001) this.tri(mat, p(a0, 0, ya), p(a0, rb, yb), p(a1, rb, yb), [uv[0], uv[3], uv[2]], col, [[0, -1, 0], nr(a0), nr(a1)]);
        else this.quad(mat, p(a0, ra, ya), p(a0, rb, yb), p(a1, rb, yb), p(a1, ra, ya), [uv[0], uv[3], uv[2], uv[1]], col, [nr(a0), nr(a0), nr(a1), nr(a1)]);
      }
    }
  }
  dome(mat, cx, y0, cz, r, h, seg, col) {
    const prof = [];
    for (let k = 0; k <= 8; k++) { const t = (k / 8) * Math.PI / 2; prof.push([Math.cos(t) * r, Math.sin(t) * h]); }
    prof[prof.length - 1][0] = 0;
    this.lathe(mat, cx, y0, cz, prof, seg, col);
  }
  // 两点间的条带（栏杆、电车轨、绳索）
  strip(mat, a, b, y0a, y0b, h, col, uvw = 2, both = true) {
    const L = Math.hypot(b[0] - a[0], b[1] - a[1]);
    const uv = [[0, 0], [L / uvw, 0], [L / uvw, 1], [0, 1]];
    const A = [a[0], y0a, a[1]], B = [b[0], y0b, b[1]], C = [b[0], y0b + h, b[1]], D = [a[0], y0a + h, a[1]];
    this.quad(mat, A, B, C, D, uv, col);
    if (both) this.quad(mat, B, A, D, C, [uv[1], uv[0], uv[3], uv[2]], col);
  }
  build(mats, parent) {
    const meshes = [];
    for (const o of this.b.values()) {
      if (!o.p.length) continue;
      const g = new THREE.BufferGeometry();
      g.setAttribute('position', new THREE.Float32BufferAttribute(o.p, 3));
      g.setAttribute('normal', new THREE.Float32BufferAttribute(o.n, 3));
      g.setAttribute('uv', new THREE.Float32BufferAttribute(o.u, 2));
      g.setAttribute('color', new THREE.Float32BufferAttribute(o.c, 3));
      g.computeBoundingSphere();
      const m = new THREE.Mesh(g, mats[o.mat] || mats.trim);
      m.castShadow = !mats[o.mat]?.userData?.noShadow; m.receiveShadow = true;
      parent.add(m); meshes.push(m);
    }
    this.b.clear();
    return meshes;
  }
}
