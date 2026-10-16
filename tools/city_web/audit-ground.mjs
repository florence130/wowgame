import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import * as THREE from 'three';
import { groundMaterialProfile, makeGroundCollision } from './ground.mjs';

const here=dirname(fileURLToPath(import.meta.url)),root=resolve(here,'../..');
const data=JSON.parse(await readFile(resolve(here,'city-data.json'),'utf8'));
const hash=v=>createHash('sha256').update(v).digest('hex');
const plan=data.groundPlan,errors=[],checks={};
if(!plan?.faces?.length)throw new Error('地面总图尚未导出');
const source=await readFile(resolve(root,'docs/city_v5/ground_plan.json'));
checks.snapshotUsesCurrentGroundPlan=hash(source)===data.groundPlanHash;
checks.groundPlanUsesCurrentLayout=plan.sourceLayoutHash===data.baselineHash;
checks.terrainPaintColorsExported=Buffer.from(data.terrain.surfaceColors||'','base64').length===data.terrain.cols*data.terrain.rows*3;
checks.noOldGroundOverlays=!data.sceneObjects.some(r=>/^(road_|square_|apron_|retaining_\d)/.test(r.id));
const planned=[...plan.faces,...(plan.edges||[]),...(plan.links||[])].filter(r=>(r.vertices||r.mesh?.vertices)?.length);
const rows=data.sceneObjects.filter(r=>r.groundId),byScene=new Map(rows.map(r=>[r.id,r]));
checks.allPlannedMeshesExported=planned.every(p=>byScene.has(p.sceneId||`ground_${p.id}`));
checks.allGroundMeshesTraceable=rows.every(r=>planned.some(p=>(p.sceneId||`ground_${p.id}`)===r.id));
checks.allGroundHasCollision=rows.every(r=>data.collisionAssets?.[r.asset]?.triangles?.length>0);
checks.onlyTwoParkRegions=plan.parks?.length===2&&plan.faces.filter(f=>f.kind==='park').length===2;
checks.allBuildingsHaveReservedParcels=data.layout.buildings.every(b=>(plan.parcels||[]).some(p=>p.buildingId===b.id&&p.polygon?.length>=3&&(Array.isArray(p.buildingFootprint)?p.buildingFootprint:p.buildingFootprint?.polygon)?.length>=3));
checks.blocksAndPedestrianNetworkPresent=!!plan.blocks?.length&&!!plan.pedestrianPaths?.length&&plan.pedestrianPaths.every(p=>p.polygon?.length>=3&&p.centerline?.length>=2&&p.centerline.every(v=>v.length===3&&v.every(Number.isFinite)));

function glbVertices(raw){
  const bytes=Buffer.from(typeof raw==='string'?raw:raw.base64,'base64');
  const jsonLength=bytes.readUInt32LE(12),gltf=JSON.parse(bytes.subarray(20,20+jsonLength).toString('utf8'));
  const binary=bytes.subarray(28+jsonLength),out=[];
  const position=index=>{const a=gltf.accessors[index],view=gltf.bufferViews[a.bufferView];if(a.componentType!==5126||a.type!=='VEC3')throw new Error('Unsupported ground position accessor');const step=view.byteStride||12,start=(view.byteOffset||0)+(a.byteOffset||0);return Array.from({length:a.count},(_,i)=>new THREE.Vector3(binary.readFloatLE(start+i*step),binary.readFloatLE(start+i*step+4),binary.readFloatLE(start+i*step+8)));};
  const visit=(index,parent)=>{const n=gltf.nodes[index],local=new THREE.Matrix4();if(n.matrix)local.fromArray(n.matrix);else local.compose(new THREE.Vector3(...(n.translation||[0,0,0])),new THREE.Quaternion(...(n.rotation||[0,0,0,1])),new THREE.Vector3(...(n.scale||[1,1,1])));const matrix=parent.clone().multiply(local);if(n.mesh!==undefined)for(const p of gltf.meshes[n.mesh].primitives)out.push(...position(p.attributes.POSITION).map(v=>v.applyMatrix4(matrix)));for(const child of n.children||[])visit(child,matrix);};
  for(const n of gltf.scenes[gltf.scene||0].nodes)visit(n,new THREE.Matrix4());return out;
}
function pointMatcher(points,tolerance=.003){
  const buckets=new Map(),cell=p=>p.map(v=>Math.floor(v/tolerance)),key=p=>p.join(',');
  for(const p of points){const k=key(cell(p));if(!buckets.has(k))buckets.set(k,[]);buckets.get(k).push(p);}
  return point=>{const c=cell(point);for(let x=-1;x<=1;x++)for(let y=-1;y<=1;y++)for(let z=-1;z<=1;z++)for(const p of buckets.get(key([c[0]+x,c[1]+y,c[2]+z]))||[])if(p.every((v,i)=>Math.abs(v-point[i])<=tolerance))return true;return false;};
}
const perObject=[];
for(const row of rows){
  const collision=data.collisionAssets?.[row.asset];if(!collision)continue;
  const visual=glbVertices(data.assets[row.asset]).map(v=>v.toArray()),matchVisual=pointMatcher(visual),matchCollision=pointMatcher(collision.vertices);
  const visualOnly=visual.filter(p=>!matchCollision(p)).length,collisionOnly=collision.vertices.filter(p=>!matchVisual(p)).length;
  const physical=makeGroundCollision(row,collision),matrix=physical.matrixWorld;
  const matchWorld=pointMatcher(collision.vertices.map(p=>new THREE.Vector3(...p).applyMatrix4(matrix).toArray()));
  const spec=planned.find(p=>(p.sceneId||`ground_${p.id}`)===row.id),vertices=spec?.vertices||spec?.mesh?.vertices||[];
  const missingPlanVertices=vertices.filter(p=>!matchWorld(p)).length;
  let supportProbe=null;
  for(const tri of spec?.triangles||spec?.mesh?.triangles||[]){
    const [a,b,c]=tri.map(i=>new THREE.Vector3(...vertices[i]));
    const normal=b.clone().sub(a).cross(c.clone().sub(a)).normalize();
    if(Math.abs(normal.y)<.6)continue;
    const center=a.clone().add(b).add(c).multiplyScalar(1/3),ray=new THREE.Raycaster(center.clone().add(new THREE.Vector3(0,100,0)),new THREE.Vector3(0,-1,0),0,200);
    const hit=ray.intersectObject(physical,false).find(h=>h.face.normal.clone().transformDirection(matrix).y>.55);
    supportProbe={expected:center.toArray(),actual:hit?.point.toArray()||null,heightError:hit?Math.abs(hit.point.y-center.y):null,pass:!!hit&&Math.abs(hit.point.y-center.y)<.02};break;
  }
  const profile=groundMaterialProfile(row);
  const item={id:row.id,groundId:row.groundId,kind:row.groundKind,profile:profile.id,tileMetres:profile.tile,jointMetres:profile.joint,visualOnlyVertices:visualOnly,collisionOnlyVertices:collisionOnly,missingPlanVertices,collisionTriangles:collision.triangles.length,supportProbe};
  if(visualOnly||collisionOnly||missingPlanVertices)errors.push(item);
  perObject.push(item);
}
checks.visibleAndPhysicalVerticesAgree=errors.length===0;
checks.physicalSupportNormalsAndHeight=perObject.every(r=>!r.supportProbe||r.supportProbe.pass);
checks.onlyParksUseGreenProfile=perObject.every(r=>r.profile!=='park'||r.kind==='park');
checks.stoneJointsUseMetricScale=perObject.filter(r=>r.profile!=='park').every(r=>r.jointMetres>0&&r.tileMetres.every(n=>n>0));
const coverageProcess=spawnSync('py',['-3.11',resolve(here,'audit-ground-coverage.py')],{cwd:root,encoding:'utf8',windowsHide:true,maxBuffer:1024*1024});
let coverage;try{coverage=JSON.parse(coverageProcess.stdout);}catch{coverage={pass:false,error:coverageProcess.stderr||coverageProcess.error?.message||'coverage check did not return JSON'};}
checks.independentProjectedCoverage=coverage.pass===true;
const report={generatedAt:new Date().toISOString(),groundPlanHash:data.groundPlanHash,counts:{planned:planned.length,objects:rows.length,collisions:Object.keys(data.collisionAssets||{}).length},checks,coverage,geometryMismatches:errors,perObject,pass:Object.values(checks).every(Boolean),scope:'Read-only export/coverage/geometry/material audit. Browser shader appearance and real Player route acceptance remain separate.'};
const out=resolve(root,'.local/city_v5/web_ground_audit.json');await mkdir(dirname(out),{recursive:true});await writeFile(out,JSON.stringify(report,null,2),'utf8');
console.log(JSON.stringify({output:out,counts:report.counts,checks,coverage,geometryMismatchCount:errors.length,pass:report.pass},null,2));if(!report.pass)process.exitCode=1;
