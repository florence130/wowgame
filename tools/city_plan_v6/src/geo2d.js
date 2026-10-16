// 2D helpers on the city ground plane. Points are [x, z]; +x east, +z south.
export const add = (a, b) => [a[0] + b[0], a[1] + b[1]];
export const sub = (a, b) => [a[0] - b[0], a[1] - b[1]];
export const mul = (a, s) => [a[0] * s, a[1] * s];
export const dot = (a, b) => a[0] * b[0] + a[1] * b[1];
export const cross = (a, b) => a[0] * b[1] - a[1] * b[0];
export const len = (a) => Math.hypot(a[0], a[1]);
export const norm = (a) => { const l = len(a) || 1; return [a[0] / l, a[1] / l]; };
export const dist = (a, b) => Math.hypot(a[0] - b[0], a[1] - b[1]);
export const lerp2 = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t];

export function area(poly) {
  let s = 0;
  for (let i = 0; i < poly.length; i++) { const a = poly[i], b = poly[(i + 1) % poly.length]; s += a[0] * b[1] - b[0] * a[1]; }
  return s / 2;
}
export function centroid(poly) {
  let x = 0, z = 0;
  for (const p of poly) { x += p[0]; z += p[1]; }
  return [x / poly.length, z / poly.length];
}
export function pointInPoly(p, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const a = poly[i], b = poly[j];
    if ((a[1] > p[1]) !== (b[1] > p[1]) && p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
  }
  return inside;
}
export function bbox(poly) {
  let x0 = Infinity, z0 = Infinity, x1 = -Infinity, z1 = -Infinity;
  for (const p of poly) { x0 = Math.min(x0, p[0]); z0 = Math.min(z0, p[1]); x1 = Math.max(x1, p[0]); z1 = Math.max(z1, p[1]); }
  return [x0, z0, x1, z1];
}
// Inward unit normal of edge i (works for either winding).
export function inwardNormal(poly, i) {
  const a = poly[i], b = poly[(i + 1) % poly.length];
  const d = norm(sub(b, a));
  const n = [-d[1], d[0]];
  return area(poly) > 0 ? n : [-n[0], -n[1]];
}
export function lineIntersect(p, d, q, e) {
  const den = cross(d, e);
  if (Math.abs(den) < 1e-9) return null;
  const t = cross(sub(q, p), e) / den;
  return add(p, mul(d, t));
}
// Move every edge i inward by off[i] (number or array) and rebuild the vertices.
export function inset(poly, off) {
  const n = poly.length, lines = [];
  for (let i = 0; i < n; i++) {
    const a = poly[i], b = poly[(i + 1) % n];
    const o = Array.isArray(off) ? off[i] : off;
    const nn = inwardNormal(poly, i);
    lines.push([add(a, mul(nn, o)), norm(sub(b, a))]);
  }
  const out = [];
  for (let i = 0; i < n; i++) {
    const L0 = lines[(i - 1 + n) % n], L1 = lines[i];
    out.push(lineIntersect(L0[0], L0[1], L1[0], L1[1]) || L1[0]);
  }
  return out;
}
// Separating-axis overlap test for convex polygons (shrink lets touching shapes pass).
export function overlap(A, B, shrink = 0.05) {
  for (const P of [A, B]) {
    for (let i = 0; i < P.length; i++) {
      const a = P[i], b = P[(i + 1) % P.length];
      const ax = norm([-(b[1] - a[1]), b[0] - a[0]]);
      let a0 = Infinity, a1 = -Infinity, b0 = Infinity, b1 = -Infinity;
      for (const p of A) { const v = dot(p, ax); a0 = Math.min(a0, v); a1 = Math.max(a1, v); }
      for (const p of B) { const v = dot(p, ax); b0 = Math.min(b0, v); b1 = Math.max(b1, v); }
      if (a1 - shrink <= b0 || b1 - shrink <= a0) return false;
    }
  }
  return true;
}
export function rectPoly(cx, cz, w, d, yaw) {
  // local +z faces (sin yaw, cos yaw); local +x is (cos yaw, -sin yaw)
  const c = Math.cos(yaw), s = Math.sin(yaw);
  const ax = [c, -s], az = [s, c];
  const pts = [[-w / 2, -d / 2], [w / 2, -d / 2], [w / 2, d / 2], [-w / 2, d / 2]];
  return pts.map(([u, v]) => [cx + ax[0] * u + az[0] * v, cz + ax[1] * u + az[1] * v]);
}
export function segDist(p, a, b) {
  const ab = sub(b, a), t = Math.max(0, Math.min(1, dot(sub(p, a), ab) / (dot(ab, ab) || 1)));
  return [dist(p, add(a, mul(ab, t))), t];
}
export function polylineLength(pts) {
  let s = 0;
  for (let i = 1; i < pts.length; i++) s += dist(pts[i - 1], pts[i]);
  return s;
}
export function rng(seed) {
  let s = seed >>> 0;
  return () => { s = (s + 0x6D2B79F5) >>> 0; let t = s; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
