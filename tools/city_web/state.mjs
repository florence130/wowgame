export const FORMAT = 'solenne-city-draft';
export const clone = value => structuredClone(value);
export const same = (a, b) => JSON.stringify(a) === JSON.stringify(b);
const finite = value => typeof value === 'number' && Number.isFinite(value);

export function createDraft(data) {
  return { layout: clone(data.layout), overrides: {}, addedObjects: [], nextCopy: 1 };
}

export function district(row) {
  if (row.district) return row.district;
  const [x, z] = row.c || [0, 0];
  if (z > 700 && x > -200) return '站区';
  if (x < -720 && z > 630) return '圣堂区';
  if (z > 555 && x < -210) return '港区';
  if (x < -665 && z < 460) return '官邸区';
  if (x < -375 && z < 460) return '学城区';
  if (z > 680) return '南城区';
  return '中央城区';
}

export function buildingPose(data, draft, id) {
  const row = draft.layout.buildings.find(b => b.id === id);
  if (!row) return null;
  const originalRow = data.layout.buildings.find(b => b.id === id);
  const sceneRow = [...data.sceneObjects, ...draft.addedObjects].find(b => b.id === id);
  const lift = originalRow && sceneRow ? sceneRow.position[1] - (originalRow.y ?? sceneRow.position[1] - 0.6) : (sceneRow?.editorLift ?? 0.6);
  const baseY = row.y ?? ((sceneRow?.position?.[1] ?? 0.6) - lift);
  return { ...sceneRow, id, asset: row.asset, family: row.family, position: [row.c[0], baseY + lift, row.c[1]], yaw: row.yaw || 0, hidden: !!draft.overrides[id]?.hidden, deleted: false, editorLift: lift };
}

export function duplicateBuilding(data, draft, id) {
  const source = draft.layout.buildings.find(b => b.id === id);
  if (!source) throw new Error('请先选择一栋建筑');
  const pose = buildingPose(data, draft, id);
  let newId;
  do { newId = `${id}_copy_${draft.nextCopy++}`; } while (draft.layout.buildings.some(b => b.id === newId) || data.sceneObjects.some(b => b.id === newId));
  const row = clone(source);
  row.id = newId;
  row.label = `${source.label || source.id} · 副本`;
  row.c[0] += Math.max(6, (row.size?.[0] || 12) * 0.65);
  draft.layout.buildings.push(row);
  draft.addedObjects.push({ ...clone(pose), id: newId, position: [row.c[0], pose.position[1], row.c[1]], editorLift: pose.editorLift, sourceId: id });
  for (const block of draft.layout.blocks || []) {
    const members = block.buildingIds || block.members || block.buildings;
    if (Array.isArray(members) && members.includes(id)) members.push(newId);
  }
  return newId;
}

export function removeBuilding(data, draft, id) {
  draft.layout.buildings = draft.layout.buildings.filter(b => b.id !== id);
  for (const block of draft.layout.blocks || []) for (const key of ['buildingIds', 'members', 'buildings']) if (Array.isArray(block[key])) block[key] = block[key].filter(value => value !== id);
  const added = draft.addedObjects.find(b => b.id === id);
  if (added) {
    draft.addedObjects = draft.addedObjects.filter(b => b.id !== id);
    delete draft.overrides[id];
  } else draft.overrides[id] = { ...draft.overrides[id], deleted: true };
}

export function collectionChanges(base, next) {
  const original = new Map((base || []).map(row => [row.id, row]));
  const current = new Map((next || []).map(row => [row.id, row]));
  return {
    added: [...current].filter(([id]) => !original.has(id)).map(([, value]) => clone(value)),
    removed: [...original.keys()].filter(id => !current.has(id)),
    updated: [...current].filter(([id, value]) => original.has(id) && !same(value, original.get(id))).map(([id, value]) => ({ id, before: clone(original.get(id)), after: clone(value) })),
  };
}

export function transformBuildings(draft, ids, dx = 0, dz = 0, degrees = 0) {
  const rows = draft.layout.buildings.filter(b => ids.includes(b.id));
  if (!rows.length || ![dx, dz, degrees].every(finite)) return;
  const cx = rows.reduce((n, b) => n + b.c[0], 0) / rows.length, cz = rows.reduce((n, b) => n + b.c[1], 0) / rows.length;
  const a = degrees * Math.PI / 180, c = Math.cos(a), s = Math.sin(a), round = n => Math.round(n * 100) / 100;
  const transformPoint = p => { const x = p[0] - cx, z = p[1] - cz; return [round(cx + c*x + s*z + dx), round(cz - s*x + c*z + dz)]; };
  for (const row of rows) { row.c = transformPoint(row.c); row.yaw = round((row.yaw || 0) + degrees); }
  for (const block of draft.layout.blocks || []) {
    const members = block.buildingIds || block.members || block.buildings || [];
    if (!members.length || !members.every(id => ids.includes(id))) continue;
    if (Array.isArray(block.courtyard) && block.courtyard.length === 2) block.courtyard = transformPoint(block.courtyard);
    if (Array.isArray(block.exits)) block.exits = block.exits.map(path => Array.isArray(path) && path.length === 2 && path.every(finite) ? transformPoint(path) : Array.isArray(path) ? path.map(transformPoint) : path);
  }
}

export function exportDraft(data, draft, camera = null) {
  const changes = Object.fromEntries(['buildings', 'roads', 'terraces', 'blocks'].map(key => [key, collectionChanges(data.layout[key], draft.layout[key])]));
  return {
    format: FORMAT, schemaVersion: 1, baselineHash: data.baselineHash,
    source: { layoutVersion: data.layout.version, sceneHash: data.sceneHash || null, terrainHash: data.terrainHash || null, groundPlanHash: data.groundPlanHash || null },
    exportedAt: new Date().toISOString(),
    layout: clone(draft.layout), changes,
    sceneChanges: Object.entries(draft.overrides).map(([id, override]) => ({ id, ...clone(override) })),
    addedObjects: clone(draft.addedObjects),
    editor: { nextCopy: draft.nextCopy, camera },
  };
}

export function importDraft(data, value) {
  if (!value || value.format !== FORMAT || value.schemaVersion !== 1) throw new Error('请选择由此编辑器导出的草稿 JSON');
  if (value.baselineHash !== data.baselineHash) throw new Error('草稿来自另一版主城。请使用对应版本的 HTML 打开，避免坐标错配。');
  if(value.source?.groundPlanHash && value.source.groundPlanHash !== data.groundPlanHash) throw new Error('草稿来自另一版地面总图，请使用对应版本的页面。');
  const layout = clone(value.layout);
  for (const name of ['buildings', 'roads', 'terraces']) {
    if (!Array.isArray(layout?.[name])) throw new Error(`草稿缺少 ${name} 数据`);
    const ids = new Set();
    for (const row of layout[name]) {
      if (typeof row.id !== 'string' || !row.id || ids.has(row.id)) throw new Error('草稿包含缺失或重复的对象标识');
      ids.add(row.id);
      if (name === 'roads') {
        if (!finite(row.width) || row.width < 0.5 || row.width > 300 || !Array.isArray(row.pts) || row.pts.length < 2 || row.pts.some(p => !Array.isArray(p) || p.length !== 2 || !p.every(finite))) throw new Error(`道路 ${row.id} 的坐标或宽度无效`);
      } else if (!Array.isArray(row.c) || row.c.length !== 2 || !row.c.every(finite) || (row.y !== undefined && !finite(row.y)) || (name === 'terraces' && (!finite(row.y) || !Array.isArray(row.size) || row.size.length !== 2 || row.size.some(v => !finite(v) || v < 2))) || (name === 'buildings' && !finite(row.yaw))) throw new Error(`对象 ${row.id} 的位置或标高无效`);
    }
  }
  const overrides = {};
  for (const row of value.sceneChanges || []) {
    if (typeof row.id !== 'string' || ['__proto__', 'constructor', 'prototype'].includes(row.id)) throw new Error('草稿对象标识无效');
    overrides[row.id] = { ...(row.hidden === undefined ? {} : { hidden: !!row.hidden }), ...(row.deleted === undefined ? {} : { deleted: !!row.deleted }) };
  }
  const addedObjects = clone(value.addedObjects || []);
  if (!Array.isArray(addedObjects) || addedObjects.some(row => !row.id || !data.assets[row.asset] || !Array.isArray(row.position) || row.position.length !== 3 || !row.position.every(finite))) throw new Error('副本模型数据不完整');
  for (const row of layout.buildings) {
    if (!data.assets[row.asset]) throw new Error(`模型 ${row.asset} 不在本页面中`);
    if (!data.sceneObjects.some(b => b.id === row.id) && !addedObjects.some(b => b.id === row.id)) throw new Error(`新增建筑 ${row.id} 缺少场景记录`);
  }
  const nextCopy = Number(value.editor?.nextCopy);
  return { layout, overrides, addedObjects, nextCopy: Number.isSafeInteger(nextCopy) && nextCopy > 0 && nextCopy < 1e8 ? nextCopy : 1 };
}

export function makeTerrainSampler(terrain) {
  const [ox, oz] = terrain.origin;
  const [sx, sz] = Array.isArray(terrain.size) ? terrain.size : [terrain.size, terrain.size];
  const sample = (x, z) => {
    const gx = Math.max(0, Math.min(terrain.cols - 1, (x - ox) / sx * (terrain.cols - 1)));
    const gz = Math.max(0, Math.min(terrain.rows - 1, (z - oz) / sz * (terrain.rows - 1)));
    const x0 = Math.floor(gx), z0 = Math.floor(gz), x1 = Math.min(x0 + 1, terrain.cols - 1), z1 = Math.min(z0 + 1, terrain.rows - 1);
    const fx = gx - x0, fz = gz - z0;
    const h = (ix, iz) => terrain.heights[iz * terrain.cols + ix];
    return (h(x0, z0) * (1 - fx) + h(x1, z0) * fx) * (1 - fz) + (h(x0, z1) * (1 - fx) + h(x1, z1) * fx) * fz;
  };
  return sample;
}
