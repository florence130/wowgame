import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { makeGroundCollision, decodeTerrainColors } from './ground.mjs';
import { createGroundReview } from './ground-review.mjs';
import { createDraft, exportDraft, importDraft } from './state.mjs';

test('Godot collision winding and saved transforms produce an upward physical support surface',()=>{
  const row={id:'ground_test',position:[10,20,30],yaw:90,scale:[2,1,2]};
  const physical=makeGroundCollision(row,{vertices:[[0,0,0],[1,0,1],[0,0,1]],triangles:[[0,1,2]]});
  const expected=new THREE.Vector3(1/3,0,2/3).applyMatrix4(physical.matrixWorld);
  const ray=new THREE.Raycaster(expected.clone().add(new THREE.Vector3(0,5,0)),new THREE.Vector3(0,-1,0));
  const hit=ray.intersectObject(physical,false)[0];
  assert.ok(hit);assert.ok(Math.abs(hit.point.y-20)<1e-8);
  assert.ok(hit.face.normal.clone().transformDirection(physical.matrixWorld).y>.99);
  assert.equal(physical.parent,null,'collision helper must not be rendered as duplicate paving');
});

test('parcel review preserves footprint holes and X/Z coordinates without adding physical ground',()=>{
  const ring=[[10,30],[20,30],[20,40],[10,40]],hole=[[13,33],[17,33],[17,37],[13,37]];
  const review=createGroundReview({parcels:[{id:'p',buildingId:'b',polygon:ring,buildingFootprint:{polygon:ring,holes:[hole]},level:18}],pedestrianPaths:[]},()=>18);
  const fill=review.children.find(n=>n.isMesh);assert.ok(fill);
  const ray=new THREE.Raycaster(new THREE.Vector3(11,30,31),new THREE.Vector3(0,-1,0));
  assert.ok(ray.intersectObject(fill,false).length>0);
  ray.ray.origin.set(15,30,35);assert.equal(ray.intersectObject(fill,false).length,0);
  assert.equal(fill.userData.id,'b');assert.equal(fill.userData.physicalGround,undefined);
});

test('terrain paint data and ground draft provenance reject mismatched snapshots',()=>{
  assert.throws(()=>decodeTerrainColors({cols:2,rows:2,surfaceColors:btoa('short')}),/地表颜色/);
  const data={baselineHash:'layout',groundPlanHash:'ground-a',layout:{buildings:[],roads:[],terraces:[]},assets:{},sceneObjects:[]};
  const exported=exportDraft(data,createDraft(data));
  assert.equal(exported.source.groundPlanHash,'ground-a');
  assert.throws(()=>importDraft({...data,groundPlanHash:'ground-b'},exported),/地面总图/);
  delete exported.source.groundPlanHash;
  assert.deepEqual(importDraft(data,exported).layout,data.layout,'older same-layout drafts remain readable');
});
