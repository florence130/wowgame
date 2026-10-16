import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createDraft, buildingPose, duplicateBuilding, removeBuilding, transformBuildings, exportDraft, importDraft, makeTerrainSampler } from './state.mjs';

const fixture = {
  schemaVersion:1, baselineHash:'fixture-base', sceneHash:'scene-1', terrainHash:'terrain-1',
  layout:{version:5,buildings:[{id:'explicit',asset:'house',family:'architecture',c:[10,20],y:26,yaw:90,size:[20,18,22],label:'街屋'},{id:'implicit',asset:'house',family:'architecture',c:[-30,50],yaw:180,size:[20,18,22]}],roads:[{id:'road',pts:[[0,0],[10,0]],width:5,walk:1}],terraces:[{id:'terrace',c:[0,0],size:[80,60],y:26}],blocks:[{id:'block',label:'测试街坊',buildingIds:['explicit','implicit']}],arbitraryField:{retain:true}},
  sceneObjects:[{id:'explicit',asset:'house',position:[10,26.6,20],yaw:90,family:'architecture'},{id:'implicit',asset:'house',position:[-30,34.6,50],yaw:180,family:'architecture'}],assets:{house:'fixture'},
};

test('unchanged explicit and terrain-derived foundations preserve exact scene elevations',()=>{
  const draft=createDraft(fixture);
  assert.deepEqual(buildingPose(fixture,draft,'explicit').position,[10,26.6,20]);
  assert.deepEqual(buildingPose(fixture,draft,'implicit').position,[-30,34.6,50]);
  draft.layout.buildings[1].y=40;
  assert.equal(buildingPose(fixture,draft,'implicit').position[1],40.6);
  assert.equal(fixture.layout.buildings[1].y,undefined);
});

test('duplicate remains at its authored elevation and can be exported, imported, moved and removed',()=>{
  const draft=createDraft(fixture),id=duplicateBuilding(fixture,draft,'implicit');
  assert.equal(buildingPose(fixture,draft,id).position[1],34.6);
  const payload=exportDraft(fixture,draft),restored=importDraft(fixture,payload);
  assert.equal(restored.layout.buildings.length,3);
  assert.equal(buildingPose(fixture,restored,id).position[1],34.6);
  restored.layout.buildings.find(b=>b.id===id).y=19;
  assert.equal(buildingPose(fixture,restored,id).position[1],19.6);
  removeBuilding(fixture,restored,id);
  assert.equal(restored.addedObjects.length,0);
  assert.equal(restored.layout.buildings.length,2);
});

test('complete layout round trip retains unrelated fields, road points, terraces, hidden and removed objects',()=>{
  const draft=createDraft(fixture);
  draft.layout.buildings[0].c=[15,29];draft.layout.buildings[0].yaw=225;
  draft.layout.roads[0].pts.splice(1,0,[3,4]);draft.layout.roads[0].width=8;
  draft.layout.terraces[0].y=28.5;draft.overrides.explicit={hidden:true};
  removeBuilding(fixture,draft,'implicit');
  const payload=exportDraft(fixture,draft),restored=importDraft(fixture,JSON.parse(JSON.stringify(payload)));
  assert.deepEqual(restored,draft);
  assert.equal(payload.changes.buildings.updated.length,1);
  assert.deepEqual(payload.changes.buildings.removed,['implicit']);
  assert.equal(payload.changes.roads.updated.length,1);
  assert.equal(payload.changes.terraces.updated.length,1);
  assert.deepEqual(restored.layout.arbitraryField,{retain:true});
  assert.equal(payload.baselineHash,'fixture-base');assert.equal(payload.source.sceneHash,'scene-1');
});

test('imports reject wrong baselines, duplicate ids and invalid geometry without mutating original',()=>{
  const snapshot=JSON.stringify(fixture),valid=exportDraft(fixture,createDraft(fixture));
  assert.throws(()=>importDraft(fixture,{...valid,baselineHash:'other'}),/另一版/);
  const duplicate=structuredClone(valid);duplicate.layout.buildings.push(structuredClone(duplicate.layout.buildings[0]));assert.throws(()=>importDraft(fixture,duplicate),/重复/);
  const badRoad=structuredClone(valid);badRoad.layout.roads[0].width=-1;assert.throws(()=>importDraft(fixture,badRoad),/宽度/);
  const badTerrace=structuredClone(valid);badTerrace.layout.terraces[0].size=[-1,60];assert.throws(()=>importDraft(fixture,badTerrace),/标高/);
  assert.equal(JSON.stringify(fixture),snapshot);
});

test('terrain sampler uses z-major grid and independent x/z bounds',()=>{
  const sample=makeTerrainSampler({origin:[-20,40],size:[100,60],cols:2,rows:2,heights:[10,20,30,40]});
  assert.equal(sample(-20,40),10);assert.equal(sample(80,100),40);assert.equal(sample(30,70),25);assert.equal(sample(-50,40),10);
});

test('whole-block movement preserves distances and moves courtyard metadata with the group',()=>{
  const draft=createDraft(fixture),block=draft.layout.blocks[0];block.courtyard=[-10,35];block.exits=[[[-10,35],[0,35]]];
  transformBuildings(draft,['explicit','implicit'],7,-3,90);
  assert.deepEqual(draft.layout.buildings[0].c,[-18,12]);
  assert.deepEqual(draft.layout.buildings[1].c,[12,52]);
  assert.deepEqual(block.courtyard,[-3,32]);assert.deepEqual(block.exits,[[[-3,32],[-3,22]]]);
  assert.equal(draft.layout.buildings[0].y,26);assert.equal(draft.layout.buildings[1].y,undefined);
  const copy=duplicateBuilding(fixture,draft,'explicit');assert.ok(block.buildingIds.includes(copy));removeBuilding(fixture,draft,copy);assert.ok(!block.buildingIds.includes(copy));
});

test('real exported city has a lossless draft round trip and preserves every building transform',async()=>{
  const data=JSON.parse(await readFile(new URL('./city-data.json',import.meta.url),'utf8')),draft=createDraft(data);
  const restored=importDraft(data,JSON.parse(JSON.stringify(exportDraft(data,draft))));
  assert.deepEqual(restored,draft);
  for(const b of data.layout.buildings){const source=data.sceneObjects.find(row=>row.id===b.id),pose=buildingPose(data,draft,b.id);assert.ok(source,`${b.id}: scene source`);assert.ok(data.assets[pose.asset],`${b.id}: embedded model`);for(let i=0;i<3;i++)assert.ok(Math.abs(pose.position[i]-source.position[i])<.025,`${b.id}: coordinate ${i}`);assert.ok(Math.abs(((pose.yaw-source.yaw+540)%360)-180)<.025,`${b.id}: rotation`);}
});
