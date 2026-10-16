import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { TransformControls } from 'three/addons/controls/TransformControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { createGroundReview, highlightGroundParcels } from './ground-review.mjs';
import { applyGroundAppearance, makeGroundCollision, decodeTerrainColors } from './ground.mjs';
import { clone, same, createDraft, district, buildingPose, duplicateBuilding, removeBuilding, transformBuildings, exportDraft, importDraft, makeTerrainSampler } from './state.mjs';

const data = window.CITY_DATA;
const hasGroundPlan = !!data.groundPlan?.faces?.length;
const groundCollisionRoots = new Map();
let groundReview = false, groundReviewGroup = null;
const terrainSurfaceColors = decodeTerrainColors(data.terrain);
const $ = id => document.getElementById(id);
const radians = THREE.MathUtils.degToRad;
const escapeHTML = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', "'":'&#39;' }[c]));
const rounded = n => Math.round(n * 100) / 100;
const friendly = { civic:'市政厅', market:'展览市场', cathedral:'晴岚大圣堂', station:'晴岚港车站', academy:'晴岚学院', palace:'总督官邸', guild:'冒险者公会', exchange:'交易所', court:'法院', bath:'公共浴场', portal:'传送大厅', mage:'法师公会', opera:'歌剧院', hospital:'医院', customs:'海关', terminal:'港口客运站', tavern:'水手酒馆', smith:'铁匠工坊', governor:'官邸台地', station_court:'车站街坊' };
Object.assign(friendly,{artisan:'工匠工坊',inn:'旅人旅馆',archive:'档案馆',tax:'税务所',welfare:'福利所',library:'图书馆',scholar:'学者会馆',institute:'研究院',merchant:'商人会馆',cook:'烹饪工坊',clergy:'教区公馆',canal:'运河管理所',warehouse:'港口仓库',shipyard:'造船工坊',blackmarket:'隐巷商馆',finance_minister:'财政官宅邸',admiral:'海军公馆',ambassador:'使节馆',weapon_shop:'武器铺',armor_shop:'护甲铺',jeweler:'珠宝铺',west_docks:'西码头台地',harbor_offices:'港务台地',east_crown:'王冠大道',north_ring:'北城环路',civic_west:'市政西街',civic_cross:'市政横街',civic_south:'市政南街',market_axis:'商贸中轴街',market_east:'市场东街',bridge_station:'车站大桥道',east_embankment:'东岸滨河路',station_front:'车站前街',station_south:'车站南街',station_west:'车站西街',west_highstreet:'西城高街',palace_approach:'官邸前道',academy_approach:'学院前道',academy_lower:'学院下街',west_cross:'西城横街',cathedral_front:'圣堂前街',harbor_ramp:'港区坡道',western_quay:'西码头路',north_quay:'北码头路',east_quay:'东码头路',station_to_quay:'车站滨岸路',cathedral_garden:'圣堂花园路',terrace_lane:'台地巷',west_residential_lane:'西居住巷',tavern_walk:'酒馆步行道',station_court_w:'车站院落西通道',station_court_e:'车站院落东通道'});
const prefixNames={merchant:'商贸街',east:'东城街',crown:'王冠大道',north:'北城街',westcore:'西城中心',academy_back:'学院后街',academy_south:'学院南街',upperwest:'西部上街',westlane:'西城巷',west_middle:'西城中街',west_sea:'西海街',dockwest:'西码头',eastnorth:'东北街',station_east:'车站东街',station_north:'车站北街',westouter:'西城外街',west_boulevard:'西大道',west_south:'西城南街',merchant_upper:'商贸上街',merchant_lower:'商贸下街',terrace_north:'台地北街',terrace_south:'台地南街',bath_north:'浴场北街',bath_south:'浴场南街',civic_back:'市政后街',market_back:'市场后街',market_eastwall:'市场东侧',market_southwall:'市场南侧',station_northwall:'车站北侧',station_upper:'车站上街',cathedral_lane:'圣堂巷',academy_westwall:'学院西侧',upper_seafront:'高岸街',station_court:'车站街坊',court:'庭院街屋'};
const names = row => {
  if(row.label&&!row.label.includes('�'))return row.label;
  if(friendly[row.id])return friendly[row.id];
  const river=row.id.match(/^river_(west|east)_(.+)$/);
  if(river){const area=river[1]==='west'?'河湾西街坊':'河湾东街坊',suffix=river[2],part=suffix.match(/^([nsew])(\d+)$/);if(part)return `${area} · ${{n:'北排',s:'南排',e:'东排',w:'西排'}[part[1]]}${Number(part[2])+1}号`;const roads={front:'前街',back:'后街',court_path:'院落步道',side_39:'西侧通道',side_128:'东侧通道','side_-117':'西侧通道',side_1:'东侧通道'};return `${area} · ${roads[suffix]||'街屋'}`;}
  const prefix=Object.keys(prefixNames).sort((a,b)=>b.length-a.length).find(p=>row.id.startsWith(p+'_'));
  if(prefix)return `${prefixNames[prefix]} · ${row.id.slice(prefix.length+1).replaceAll('_','·')}`;
  return `${row.pts?'支路':row.size?.length===2?'台地区域':'街坊建筑'} · ${row.id}`;
};
const storageKey = `solenne-city-draft-v1:${data.baselineHash}`;
let draft = createDraft(data), selection = { kind:'building', ids:[] }, tab = 'building';
let past = [], future = [], saving = 0, toastTimer = 0, ready = false, changedCount = 0;
let mode = 'orbit', walkYaw = 0, walkPitch = 0, lastCoordinateUpdate = 0, selectedPoint = -1;
let inspectorRendering = false;
let dragLook=false,dragLookPoint=null,lockUnavailable=false;
const keys = new Set(), objectRoots = new Map(), assetTemplates = new Map(), objectBounds = new Map();
let missingAssets = [], selectableRoots = [], collisionRoots = [], terrainHeights = [...data.terrain.heights];
let getHeight = makeTerrainSampler({ ...data.terrain, heights:terrainHeights });
let draftCamera = null;
try {
  const saved = localStorage.getItem(storageKey);
  if (saved) { const value = JSON.parse(saved); draft = importDraft(data, value); draftCamera = value.editor?.camera; }
} catch (error) { console.warn('草稿恢复失败', error); }

function toast(message, error = false) {
  $('toast').textContent = message; $('toast').classList.toggle('error', error); $('toast').classList.add('visible');
  clearTimeout(toastTimer); toastTimer = setTimeout(() => $('toast').classList.remove('visible'), error ? 7000 : 3800);
}
function cameraState() { return { position:camera.position.toArray(), target:controls.target.toArray() }; }
function saveSoon() {
  $('save-status').textContent = '正在保存草稿'; $('save-dot').className = '';
  clearTimeout(saving); saving = setTimeout(saveNow, 500);
}
function saveNow() {
  try { localStorage.setItem(storageKey, JSON.stringify(exportDraft(data, draft, cameraState()))); $('save-status').textContent = '已自动保存到本机'; $('save-dot').className = 'saved'; }
  catch { $('save-status').textContent = '自动保存不可用，请导出'; $('save-dot').className = 'warn'; }
}
function commit(mutator, message = '') {
  const before = clone(draft);
  try { mutator(draft); } catch (error) { draft = before; toast(error.message, true); return false; }
  if (same(before, draft)) return false;
  past.push(before); if (past.length > 80) past.shift(); future = [];
  refreshAll(); saveSoon(); if (message) toast(message); return true;
}
function undo() {
  if (!past.length) return;
  future.push(clone(draft)); draft = past.pop(); refreshAll(); saveSoon(); toast('已撤销');
}
function redo() {
  if (!future.length) return;
  past.push(clone(draft)); draft = future.pop(); refreshAll(); saveSoon(); toast('已重做');
}

const scene = new THREE.Scene(); scene.background = new THREE.Color('#cbdcd8'); scene.fog = new THREE.Fog('#cbdcd8', 1800, 4200);
const camera = new THREE.PerspectiveCamera(48, 1, 0.15, 7000);
const renderer = new THREE.WebGLRenderer({ antialias:true, powerPreference:'high-performance' });
renderer.setPixelRatio(Math.min(devicePixelRatio, 1.7)); renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.toneMappingExposure = 1.22;
renderer.shadowMap.enabled = false;
$('scene').appendChild(renderer.domElement);
renderer.domElement.tabIndex=0;renderer.domElement.setAttribute('aria-label','晴岚港三维视图：点击后可使用 WASD 漫游');
const controls = new OrbitControls(camera, renderer.domElement); controls.enableDamping = true; controls.dampingFactor = 0.1; controls.maxPolarAngle = Math.PI * 0.495; controls.minDistance = 3; controls.maxDistance = 2800;
const sun = new THREE.DirectionalLight('#fff3d7', 2.5); sun.position.set(-700, 1100, -300); scene.add(sun);
scene.add(new THREE.HemisphereLight('#e6f5ff', '#849277', 2.0));
const ambient = new THREE.AmbientLight('#ffffff', 0.32); scene.add(ambient);
const cityGroup = new THREE.Group(); scene.add(cityGroup);
const roadGroup = new THREE.Group(), terraceGroup = new THREE.Group(), selectionGroup = new THREE.Group(), hiddenGroup = new THREE.Group();
scene.add(roadGroup, terraceGroup, selectionGroup, hiddenGroup);
const transform = new TransformControls(camera, renderer.domElement); transform.setSize(0.8); scene.add(transform.getHelper());
transform.addEventListener('dragging-changed', e => { controls.enabled = !e.value && mode === 'orbit'; });
transform.addEventListener('mouseUp', () => {
  const id = selection.ids[0], obj = objectRoots.get(id);
  if (!id || !obj || selection.kind !== 'building') return;
  commit(d => {
    const row = d.layout.buildings.find(b => b.id === id); if (!row) return;
    const prior = buildingPose(data, d, id), lift = prior.editorLift;
    row.c = [rounded(obj.position.x), rounded(obj.position.z)]; row.y = rounded(obj.position.y - lift); row.yaw = rounded(THREE.MathUtils.radToDeg(obj.rotation.y));
  });
});

const raycaster = new THREE.Raycaster(), pointer = new THREE.Vector2(), downRay = new THREE.Raycaster();
downRay.ray.direction.set(0, -1, 0);
const terrainGeometry = new THREE.BufferGeometry();
const terrain = data.terrain;
const [terrainSX, terrainSZ] = Array.isArray(terrain.size) ? terrain.size : [terrain.size, terrain.size];
const terrainVertices = new Float32Array(terrain.cols * terrain.rows * 3), terrainColors = new Float32Array(terrainVertices.length), terrainIndices = [];
for (let z = 0; z < terrain.rows; z++) for (let x = 0; x < terrain.cols; x++) {
  const i = z * terrain.cols + x;
  terrainVertices[i*3] = terrain.origin[0] + x / (terrain.cols-1) * terrainSX;
  terrainVertices[i*3+1] = terrainHeights[i]; terrainVertices[i*3+2] = terrain.origin[1] + z / (terrain.rows-1) * terrainSZ;
  if (x < terrain.cols-1 && z < terrain.rows-1) { const b = i+1, c = i+terrain.cols, d = c+1; terrainIndices.push(i,c,b,b,c,d); }
}
terrainGeometry.setAttribute('position', new THREE.BufferAttribute(terrainVertices, 3));
terrainGeometry.setAttribute('color', new THREE.BufferAttribute(terrainColors, 3)); terrainGeometry.setIndex(terrainIndices);
const terrainMesh = new THREE.Mesh(terrainGeometry, new THREE.MeshStandardMaterial({ vertexColors:true, roughness:1 })); scene.add(terrainMesh);
const water = new THREE.Mesh(new THREE.PlaneGeometry(terrainSX * 3, terrainSZ * 3), new THREE.MeshStandardMaterial({ color:'#77acae', metalness:0.05, roughness:0.45, transparent:true, opacity:0.88, side:THREE.DoubleSide }));
water.rotation.x = -Math.PI/2; water.position.set(terrain.origin[0]+terrainSX/2, terrain.waterLevel ?? data.layout.water ?? 8, terrain.origin[1]+terrainSZ/2); scene.add(water);

function updateTerrain() {
  terrainHeights = [...terrain.heights];
  const changed = []; // Terrace edits require the shared ground plan; legacy draft parameters remain exportable.
  for (const row of changed) {
    const base = data.layout.terraces.find(b => b.id === row.id); if (!base) continue;
    const falloff = Math.max(3, row.falloff || 8), delta = row.y - base.y;
    for (let i = 0; i < terrainHeights.length; i++) {
      const x = terrainVertices[i*3], z = terrainVertices[i*3+2];
      const dx = Math.max(0, Math.abs(x-row.c[0]) - row.size[0]/2), dz = Math.max(0, Math.abs(z-row.c[1]) - row.size[1]/2);
      const weight = Math.max(0, 1 - Math.hypot(dx,dz)/falloff);
      if (weight) terrainHeights[i] = base.c[0] === row.c[0] && base.c[1] === row.c[1] && same(base.size,row.size) ? terrainHeights[i] + delta*weight : THREE.MathUtils.lerp(terrainHeights[i],row.y,weight);
    }
  }
  const color = new THREE.Color(), stone = new THREE.Color('#bfc4a8'), grass = new THREE.Color('#8fa47c'), shore = new THREE.Color('#c1ba9c');
  for (let i = 0; i < terrainHeights.length; i++) {
    const h = terrainHeights[i]; terrainVertices[i*3+1] = h;
    if(terrainSurfaceColors) color.setRGB(terrainSurfaceColors[i*3]/255,terrainSurfaceColors[i*3+1]/255,terrainSurfaceColors[i*3+2]/255,THREE.SRGBColorSpace);
    else color.copy(h < (terrain.waterLevel??8)+4 ? shore : grass).lerp(stone, Math.min(0.48,Math.max(0,h/150)));
    terrainColors[i*3] = color.r; terrainColors[i*3+1] = color.g; terrainColors[i*3+2] = color.b;
  }
  terrainGeometry.attributes.position.needsUpdate = true; terrainGeometry.attributes.color.needsUpdate = true; terrainGeometry.computeVertexNormals(); terrainGeometry.computeBoundingSphere();
  getHeight = makeTerrainSampler({ ...terrain, heights:terrainHeights });
}
function clearGroup(group) {
  for (const child of [...group.children]) { group.remove(child); child.traverse(node => { node.geometry?.dispose(); if (node.material) (Array.isArray(node.material) ? node.material : [node.material]).forEach(m => m.dispose()); }); }
}
function physicalGroundY(x,z) {
  if(!groundCollisionRoots.size)return null;
  const candidates=[...groundCollisionRoots].filter(([id])=>{const b=objectBounds.get(id);return objectRoots.get(id)?.visible&&b&&x>=b.min.x-.01&&x<=b.max.x+.01&&z>=b.min.z-.01&&z<=b.max.z+.01;}).map(([,mesh])=>mesh);
  downRay.ray.origin.set(x,2000,z);downRay.near=0;downRay.far=4000;
  for(const hit of downRay.intersectObjects(candidates,false)){const normal=hit.face?.normal.clone().transformDirection(hit.object.matrixWorld);if(normal&&normal.y>.55)return hit.point.y;}
  return null;
}
function surfaceY(x,z) { return physicalGroundY(x,z) ?? getHeight(x,z); }
function roadRibbon(road) {
  const positions = [], indices = [], width = road.width / 2;
  for (let segment = 1; segment < road.pts.length; segment++) {
    const a = road.pts[segment-1], b = road.pts[segment], dx = b[0]-a[0], dz = b[1]-a[1], length = Math.hypot(dx,dz);
    if (length < 0.01) continue;
    const nx = -dz/length*width, nz = dx/length*width, steps = Math.max(1,Math.ceil(length/5));
    for (let j = 0; j < steps; j++) {
      const u = j/steps, v = (j+1)/steps, x1 = a[0]+dx*u, z1 = a[1]+dz*u, x2 = a[0]+dx*v, z2 = a[1]+dz*v, start = positions.length/3;
      for (const [x,z] of [[x1+nx,z1+nz],[x1-nx,z1-nz],[x2+nx,z2+nz],[x2-nx,z2-nz]]) positions.push(x,surfaceY(x,z)+0.22,z);
      indices.push(start,start+2,start+1,start+1,start+2,start+3);
    }
  }
  const geometry = new THREE.BufferGeometry(); geometry.setAttribute('position',new THREE.Float32BufferAttribute(positions,3)); geometry.setIndex(indices); geometry.computeVertexNormals(); return geometry;
}
function updateRoads() {
  clearGroup(roadGroup);
  for (const road of draft.layout.roads) {
    const edited = !same(road, data.layout.roads.find(r => r.id===road.id)), selected = selection.kind==='road' && selection.ids.includes(road.id);
    if(hasGroundPlan&&!selected&&!edited)continue;
    const mesh = new THREE.Mesh(roadRibbon(road), new THREE.MeshBasicMaterial({ color:selected ? '#efbc58' : edited ? '#db9754' : '#dcd5b2', transparent:true, opacity:selected ? .8 : edited ? .7 : .27, side:THREE.DoubleSide, depthWrite:false, polygonOffset:true, polygonOffsetFactor:-2 }));
    if((selected||edited)&&road.walk>0){const shoulder=new THREE.Mesh(roadRibbon({...road,width:road.width+road.walk*2}),new THREE.MeshBasicMaterial({color:'#ddd8bd',transparent:true,opacity:.55,side:THREE.DoubleSide,depthWrite:false,polygonOffset:true,polygonOffsetFactor:-1}));shoulder.userData={kind:'road',id:road.id};shoulder.renderOrder=1;roadGroup.add(shoulder);}
    mesh.userData = { kind:'road', id:road.id }; mesh.renderOrder=2; roadGroup.add(mesh);
    if (selected) road.pts.forEach((p,index) => {
      const sphere = new THREE.Mesh(new THREE.SphereGeometry(2.2,12,8),new THREE.MeshBasicMaterial({ color:index===selectedPoint ? '#f16f3c' : '#fff4bd',depthTest:false }));
      sphere.position.set(p[0],surfaceY(...p)+1.1,p[1]); sphere.userData={ kind:'road',id:road.id,index }; sphere.renderOrder=10; roadGroup.add(sphere);
    });
  }
  roadGroup.visible = $('show-roads').checked || selection.kind==='road';
  for (const row of data.sceneObjects) if (row.layoutRoadId) {
    const current = draft.layout.roads.find(r=>r.id===row.layoutRoadId), original = data.layout.roads.find(r=>r.id===row.layoutRoadId);
    const obj = objectRoots.get(row.id); if (obj) obj.visible = !!current && same(current,original);
  }
}
function updateTerraces() {
  clearGroup(terraceGroup);
  for (const row of draft.layout.terraces) {
    const selected = selection.kind==='terrace' && selection.ids.includes(row.id), edited = !same(row,data.layout.terraces.find(r=>r.id===row.id));
    if (!$('show-terraces').checked && !selected && !edited) continue;
    const plane = new THREE.Mesh(new THREE.PlaneGeometry(row.size[0],row.size[1]),new THREE.MeshBasicMaterial({ color:selected ? '#efb64b' : '#53a6b1', transparent:true,opacity:selected?.3:.13,side:THREE.DoubleSide,depthWrite:false }));
    plane.rotation.x=-Math.PI/2; plane.position.set(row.c[0],row.y+.28,row.c[1]); plane.userData={kind:'terrace',id:row.id}; terraceGroup.add(plane);
    const points=[[-1,-1],[1,-1],[1,1],[-1,1],[-1,-1]].map(([x,z])=>new THREE.Vector3(row.c[0]+x*row.size[0]/2,row.y+.35,row.c[1]+z*row.size[1]/2));
    const line=new THREE.Line(new THREE.BufferGeometry().setFromPoints(points),new THREE.LineBasicMaterial({color:selected?'#dc9835':'#54a1a9',depthTest:false,transparent:true,opacity:.8})); line.renderOrder=5; terraceGroup.add(line);
  }
}

function prepareTemplate(gltf) {
  const root = gltf.scene;
  root.traverse(node => {
    if (/colonly|collision|collider|collision_shape/i.test(node.name)) { node.visible=false; node.userData.editorCollision=true; }
    if (node.isMesh) { node.castShadow=false; node.receiveShadow=false; }
  });
  return root;
}
async function loadAssets() {
  const entries=Object.entries(data.assets), loader=new GLTFLoader(); let complete=0, next=0;
  async function worker() {
    while (next<entries.length) {
      const [id,raw]=entries[next++];
      try {
        const binary=atob(typeof raw==='string'?raw:raw.base64), bytes=new Uint8Array(binary.length);
        for(let i=0;i<binary.length;i++) bytes[i]=binary.charCodeAt(i);
        const gltf=await loader.parseAsync(bytes.buffer,''); assetTemplates.set(id,prepareTemplate(gltf));
      } catch(error) { missingAssets.push(id); console.error('模型加载失败',id,error); }
      complete++; $('load-progress').value=complete/entries.length; $('load-status').textContent=`原生模型 ${complete} / ${entries.length}`;
      if (complete%5===0) await new Promise(resolve=>setTimeout(resolve,0));
    }
  }
  await Promise.all([worker(),worker(),worker()]);
}
function makeObject(row) {
  const template=assetTemplates.get(row.asset); let obj;
  if(template) obj=template.clone(true);
  else { const spec=draft.layout.buildings.find(b=>b.id===row.id), size=spec?.size||[6,6,6]; obj=new THREE.Group(); const mesh=new THREE.Mesh(new THREE.BoxGeometry(...size),new THREE.MeshStandardMaterial({color:'#b16958',wireframe:true})); mesh.position.y=size[1]/2; obj.add(mesh); }
  obj.name=row.id; obj.userData.cityId=row.id;
  obj.traverse(node=>{node.userData.cityId=row.id;});
  if(row.groundId){applyGroundAppearance(obj,row);const physical=makeGroundCollision(row,data.collisionAssets?.[row.asset]);if(physical)groundCollisionRoots.set(row.id,physical);}
  cityGroup.add(obj); objectRoots.set(row.id,obj); return obj;
}
function syncObjects() {
  const sceneRows=[...data.sceneObjects,...draft.addedObjects], buildingIds=new Set(draft.layout.buildings.map(b=>b.id));
  const originalBuildingIds=new Set(data.layout.buildings.map(b=>b.id));
  for(const row of sceneRows) {
    let obj=objectRoots.get(row.id); if(!obj) obj=makeObject(row);
    const pose=buildingIds.has(row.id)?buildingPose(data,draft,row.id):row;
    const removed=(originalBuildingIds.has(row.id)&&!buildingIds.has(row.id))||draft.overrides[row.id]?.deleted;
    obj.position.fromArray(pose.position); obj.rotation.set(0,radians(pose.yaw||0),0);
    if(pose.scale) obj.scale.fromArray(Array.isArray(pose.scale)?pose.scale:[pose.scale,pose.scale,pose.scale]);
    obj.visible=!removed&&!draft.overrides[row.id]?.hidden&&!(groundReview&&(originalBuildingIds.has(row.id)||buildingIds.has(row.id)||row.family==='scenery')); obj.updateMatrixWorld(true); objectBounds.set(row.id,new THREE.Box3().setFromObject(obj));
  }
  const currentIds=new Set(sceneRows.map(r=>r.id));
  for(const [id,obj] of objectRoots) if(!currentIds.has(id)){cityGroup.remove(obj);objectRoots.delete(id);objectBounds.delete(id);}
  selectableRoots=[...objectRoots].filter(([id,obj])=>buildingIds.has(id)&&obj.visible).map(([,obj])=>obj);
  collisionRoots=[...objectRoots].filter(([id,obj])=>obj.visible&&!groundCollisionRoots.has(id)).map(([,obj])=>obj);
  for(const [id,physical] of groundCollisionRoots)if(objectRoots.get(id)?.visible)collisionRoots.push(physical);
  updateHidden();
}
function updateHidden() {
  clearGroup(hiddenGroup); if(!$('show-hidden').checked)return;
  for(const row of draft.layout.buildings) if(draft.overrides[row.id]?.hidden) {
    const box=objectBounds.get(row.id); if(!box)continue;
    const helper=new THREE.Box3Helper(box,'#8199a4'); helper.material.transparent=true;helper.material.opacity=.5;hiddenGroup.add(helper);
  }
}
function updateSelectionVisuals() {
  clearGroup(selectionGroup); transform.detach();
  if(groundReview){highlightGroundParcels(groundReviewGroup,selection.ids);return;}
  if(selection.kind!=='building')return;
  for(const id of selection.ids) {
    const obj=objectRoots.get(id), box=objectBounds.get(id); if(!obj||!box)continue;
    const helper=new THREE.Box3Helper(box.clone().expandByScalar(.18),'#efb653'); helper.material.depthTest=false;helper.material.transparent=true;helper.material.opacity=.9;helper.renderOrder=10;selectionGroup.add(helper);
  }
  if(selection.ids.length===1 && mode==='orbit'){
    const obj=objectRoots.get(selection.ids[0]); if(obj?.visible && (document.querySelector('#move-tool.active')||document.querySelector('#rotate-tool.active'))) transform.attach(obj);
  }
}

function blocks() {
  if(Array.isArray(draft.layout.blocks)&&draft.layout.blocks.length) return draft.layout.blocks.map(b=>({id:b.id,label:b.label||b.name||b.id,ids:b.buildingIds||b.members||b.buildings||[]}));
  const groups=new Map();
  for(const b of draft.layout.buildings){const id=b.id.replace(/_(?:\d+|[nsew]\d*)$/,'');if(!groups.has(id))groups.set(id,[]);groups.get(id).push(b.id);}
  return [...groups].filter(([,ids])=>ids.length>1).map(([id,ids])=>({id,label:friendly[id]||prefixNames[id]||`街坊 · ${id}`,ids}));
}
function refreshFilters() {
  const chosenDistrict=$('district').value, chosenGroup=$('group').value;
  $('district').innerHTML='<option value="">全部城区</option>'+[...new Set(draft.layout.buildings.map(district))].sort().map(d=>`<option value="${escapeHTML(d)}">${escapeHTML(d)}</option>`).join('');
  $('group').innerHTML='<option value="">全部街坊</option>'+blocks().map(b=>`<option value="${escapeHTML(b.id)}">${escapeHTML(b.label)} (${b.ids.length})</option>`).join('');
  $('district').value=chosenDistrict;$('group').value=chosenGroup;
  $('district').disabled=tab!=='building';$('group').disabled=tab!=='building';$('select-group').hidden=tab!=='building'||!$('group').value;
}
function renderList() {
  const key={building:'buildings',road:'roads',terrace:'terraces'}[tab], rows=draft.layout[key]||[], search=$('search').value.toLowerCase().trim(), area=$('district').value, group=blocks().find(b=>b.id===$('group').value);
  const filtered=rows.filter(row=>(!search||`${names(row)} ${row.id}`.toLowerCase().includes(search))&&(tab!=='building'||!area||district(row)===area)&&(tab!=='building'||!group||group.ids.includes(row.id)));
  $('object-count').textContent=`${rows.length} 项`;$('visible-count').textContent=`显示 ${filtered.length} / ${rows.length}`;
  $('object-list').innerHTML=filtered.map(row=>`<button class="object-row${selection.kind===tab&&selection.ids.includes(row.id)?' selected':''}${draft.overrides[row.id]?.hidden?' hidden-object':''}" data-id="${escapeHTML(row.id)}" role="option" aria-selected="${selection.kind===tab&&selection.ids.includes(row.id)}"><span class="object-icon">${tab==='road'?'⌁':tab==='terrace'?'▱':row.family==='landmarks'?'♜':'⌂'}</span><span class="object-text"><span class="name">${escapeHTML(names(row))}</span><span class="meta">${escapeHTML(tab==='building'?district(row)+' · '+(row.family==='landmarks'?'地标建筑':'街坊建筑'):tab==='road'?`${row.width} m · ${row.pts.length} 个控制点`:`标高 ${row.y} m`)}${draft.overrides[row.id]?.hidden?' · 已隐藏':''}</span></span></button>`).join('');
  for(const el of $('object-list').querySelectorAll('[data-id]')){
    el.onclick=e=>select(tab,el.dataset.id,e.ctrlKey||e.metaKey);
    el.ondblclick=()=>focusSelection();
  }
}
function select(kind,id,multi=false) {
  if(kind==='building'&&multi&&selection.kind==='building') selection.ids=selection.ids.includes(id)?selection.ids.filter(v=>v!==id):[...selection.ids,id];
  else selection={kind,ids:[id]};
  selectedPoint=-1; if(tab!==kind){tab=kind;for(const b of document.querySelectorAll('[data-tab]'))b.classList.toggle('active',b.dataset.tab===tab);refreshFilters();}
  if(matchMedia('(max-width:720px)').matches){$('explorer').classList.remove('mobile-open');$('inspector').classList.remove('mobile-collapsed');}
  renderList();renderInspector();updateRoads();updateTerraces();updateSelectionVisuals();
}
function field(label,id,value,step=1,attrs='') { return `<label class="field">${label}<input id="${id}" type="number" value="${rounded(value)}" step="${step}" ${attrs}></label>`; }
function bindNumberElement(element,handler) {
  let timer=0,last=Number(element.value);
  const submit=()=>{
    clearTimeout(timer);
    if(inspectorRendering||!element.isConnected)return;
    const raw=element.value.trim(),n=Number(raw);
    if(raw===''||!Number.isFinite(n)){element.value=String(last);return;}
    if(n===last)return;
    last=n;const focused=document.activeElement===element,id=element.id;
    handler(n);
    if(focused&&id)$(id)?.focus({preventScroll:true});
  };
  element.addEventListener('input',()=>{clearTimeout(timer);timer=setTimeout(submit,450);});
  element.addEventListener('change',submit);element.addEventListener('blur',submit);
  element.addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();submit();}});
}
function bindNumber(id,handler) { bindNumberElement($(id),handler); }
function groupCenter(ids) { const rows=draft.layout.buildings.filter(b=>ids.includes(b.id));return rows.length?[rows.reduce((n,b)=>n+b.c[0],0)/rows.length,rows.reduce((n,b)=>n+b.c[1],0)/rows.length]:[0,0]; }
function renderInspector() {inspectorRendering=true;try{renderInspectorContent();}finally{inspectorRendering=false;}}
function renderInspectorContent() {
  const key={building:'buildings',road:'roads',terrace:'terraces'}[selection.kind]; selection.ids=selection.ids.filter(id=>draft.layout[key]?.some(row=>row.id===id));
  const ids=selection.ids, row=draft.layout[key]?.find(b=>b.id===ids[0]), multiple=ids.length>1;
  $('selection-empty').hidden=!!row;$('selection-panel').hidden=!row;$('selection-kind').textContent=row?({building:'建筑',road:'道路',terrace:'台地'}[selection.kind]):'';
  $('mobile-inspector').hidden=!row;
  if(!row)return;
  $('selection-title').textContent=multiple?`${ids.length} 栋建筑`:names(row);$('selection-id').textContent=multiple?'整体编辑 · 以所选建筑中心旋转':row.id;
  $('move-tool').hidden=$('rotate-tool').hidden=selection.kind!=='building'||multiple;$('building-actions').hidden=selection.kind!=='building';$('duplicate').hidden=multiple;
  if(selection.kind==='building'&&multiple) {
    const center=groupCenter(ids);
    $('inspector-fields').innerHTML=`<div class="field-heading">街坊整体位移</div><div class="field-row">${field('东西位移 · m','group-x',0)}${field('南北位移 · m','group-z',0)}</div><button id="apply-group-move" class="wide">平移所选建筑</button><div class="field-heading" style="margin-top:18px">绕中心旋转</div><div class="field-row one">${field('旋转角度 · °','group-yaw',0,5)}</div><button id="apply-group-rotate" class="wide">旋转所选建筑</button><p class="field-note">中心 ${rounded(center[0])}, ${rounded(center[1])}。保留建筑彼此间距与各自地基标高；道路和台地可另行调整。</p>`;
    $('apply-group-move').onclick=()=>{const x=Number($('group-x').value),z=Number($('group-z').value);if(!Number.isFinite(x)||!Number.isFinite(z))return;commit(d=>transformBuildings(d,ids,x,z,0),'已整体平移街坊');};
    $('apply-group-rotate').onclick=()=>{const degrees=Number($('group-yaw').value);if(!Number.isFinite(degrees))return;commit(d=>transformBuildings(d,ids,0,0,degrees),'已绕街坊中心旋转');};
  } else if(selection.kind==='building') {
    const pose=buildingPose(data,draft,row.id),baseY=pose.position[1]-pose.editorLift;
    $('inspector-fields').innerHTML=`<div class="field-heading">平面位置</div><div class="field-row">${field('东西 X · m','edit-x',row.c[0],.5)}${field('南北 Z · m','edit-z',row.c[1],.5)}</div><div class="field-row">${field('朝向 · °','edit-yaw',row.yaw||0,5)}${field('地基标高 · m','edit-y',baseY,.1)}</div><div class="field-row one"><label class="field">显示名称<input id="edit-label" type="text" value="${escapeHTML(row.label||'')}"></label></div><div class="dimension-note">${(row.size||[]).map(n=>rounded(n)).join(' × ')} m · 原生比例</div><p class="field-note">位置使用城市局部坐标。地基标高保留模型自身的楼面抬升；调整后请留意建筑与道路的衔接。</p>`;
    for(const [id,mut] of [['edit-x',(r,v)=>r.c[0]=v],['edit-z',(r,v)=>r.c[1]=v],['edit-yaw',(r,v)=>r.yaw=v],['edit-y',(r,v)=>r.y=v]]) bindNumber(id,v=>commit(d=>mut(d.layout.buildings.find(b=>b.id===row.id),v)));
    $('edit-label').onchange=()=>{const label=$('edit-label').value;commit(d=>d.layout.buildings.find(b=>b.id===row.id).label=label);};
  } else if(selection.kind==='road') {
    $('inspector-fields').innerHTML=`<div class="field-heading">道路断面</div><div class="field-row">${field('车行/主路宽 · m','edit-width',row.width,.5,'min="0.5" max="300"')}${field('单侧步行带 · m','edit-walk',row.walk||0,.5,'min="0" max="80"')}</div><div class="field-heading">道路控制点 · X / Z</div><div id="road-points">${row.pts.map((p,i)=>`<div class="point-row"><span class="point-index">${i+1}</span><input aria-label="第${i+1}点X" data-index="${i}" data-axis="0" type="number" step=".5" value="${rounded(p[0])}"><input aria-label="第${i+1}点Z" data-index="${i}" data-axis="1" type="number" step=".5" value="${rounded(p[1])}"><button data-remove="${i}" title="删除此点" ${row.pts.length<=2?'disabled':''}>×</button></div>`).join('')}</div><button id="add-road-point" class="wide subtle">在末端增加控制点</button><p class="field-note">金色为选中道路，橙色仅为草稿位置与宽度。正式铺装、地基和人行道保持总图状态，回导后统一重建。</p>`;
    bindNumber('edit-width',v=>commit(d=>d.layout.roads.find(r=>r.id===row.id).width=Math.max(.5,Math.min(300,v))));bindNumber('edit-walk',v=>commit(d=>d.layout.roads.find(r=>r.id===row.id).walk=Math.max(0,Math.min(80,v))));
    for(const input of $('road-points').querySelectorAll('input')){const i=Number(input.dataset.index),a=Number(input.dataset.axis);bindNumberElement(input,v=>commit(d=>d.layout.roads.find(r=>r.id===row.id).pts[i][a]=v));}
    for(const button of $('road-points').querySelectorAll('[data-remove]'))button.onclick=()=>commit(d=>d.layout.roads.find(r=>r.id===row.id).pts.splice(Number(button.dataset.remove),1));
    $('add-road-point').onclick=()=>commit(d=>{const r=d.layout.roads.find(r=>r.id===row.id),a=r.pts.at(-2),b=r.pts.at(-1);r.pts.push([rounded(b[0]+(b[0]-a[0])*.25),rounded(b[1]+(b[1]-a[1])*.25)]);});
  } else {
    $('inspector-fields').innerHTML=`<div class="field-heading">台地区域 · 只读</div><div class="field-row">${field('中心 X · m','edit-x',row.c[0],1,'disabled')}${field('中心 Z · m','edit-z',row.c[1],1,'disabled')}</div><div class="field-row">${field('东西宽度 · m','edit-sx',row.size[0],1,'disabled')}${field('南北深度 · m','edit-sz',row.size[1],1,'disabled')}</div><div class="field-row one">${field('台地标高 · m','edit-y',row.y,.5,'disabled')}</div><p class="field-note">台地由统一地面总图调整，需同时处理街道、入口、挡墙和台阶。本页只审阅现有地面；旧草稿台地参数仍保留并可导出，不改变当前地面。</p>`;
  }
  $('hide-object').textContent=ids.every(id=>draft.overrides[id]?.hidden)?'显示':'隐藏';
  if(groundReview)for(const input of $('inspector-fields').querySelectorAll('input,button,select'))input.disabled=true;
  for(const id of ['move-tool','rotate-tool','duplicate','hide-object','delete-object'])$(id).disabled=groundReview;
}

let lastTerrainState='',lastRoadState='';
function refreshAll() {
  if(ready)syncObjects();
  const t=JSON.stringify(draft.layout.terraces);if(t!==lastTerrainState){updateTerrain();lastTerrainState=t;}
  updateRoads();updateTerraces();refreshFilters();renderList();renderInspector();updateSelectionVisuals();
  const exported=exportDraft(data,draft);changedCount=Object.values(exported.changes).reduce((n,v)=>n+v.added.length+v.removed.length+v.updated.length,0)+Object.keys(draft.overrides).length;
  $('draft-count').textContent=changedCount?`${changedCount} 项改动`:'原始布局';$('undo').disabled=!past.length;$('redo').disabled=!future.length;
}
function focusSelection() {
  if(!selection.ids.length)return;
  let center=new THREE.Vector3(),radius=40;
  if(selection.kind==='building') {const box=new THREE.Box3();selection.ids.forEach(id=>{const b=objectBounds.get(id);if(b)box.union(b);});if(box.isEmpty())return;box.getCenter(center);radius=Math.max(22,box.getSize(new THREE.Vector3()).length()*.6);}
  else if(selection.kind==='road'){const row=draft.layout.roads.find(r=>r.id===selection.ids[0]),box=new THREE.Box3();row.pts.forEach(([x,z])=>box.expandByPoint(new THREE.Vector3(x,surfaceY(x,z),z)));box.getCenter(center);radius=Math.max(35,box.getSize(new THREE.Vector3()).length()*.6);}
  else{const row=draft.layout.terraces.find(r=>r.id===selection.ids[0]);center.set(row.c[0],row.y,row.c[1]);radius=Math.max(...row.size)*.65;}
  setMode('orbit');controls.target.copy(center);camera.position.copy(center).add(new THREE.Vector3(radius*.65,radius*.95,radius*1.1));controls.update();
}
function overview() {
  setMode('orbit');const box=new THREE.Box3();draft.layout.buildings.forEach(b=>box.expandByPoint(new THREE.Vector3(b.c[0],b.y,b.c[1])));const c=box.getCenter(new THREE.Vector3()),s=box.getSize(new THREE.Vector3()),r=Math.max(s.x,s.z)*.8;
  controls.target.copy(c);camera.position.copy(c).add(new THREE.Vector3(r*.44,r*.93,r*.83));controls.update();
}
function nearbyRoots(x,z,radius=8) {return collisionRoots.filter(obj=>{const b=objectBounds.get(obj.userData.cityId);return obj.visible&&b&&x>=b.min.x-radius&&x<=b.max.x+radius&&z>=b.min.z-radius&&z<=b.max.z+radius;});}
function supportAt(x,z,currentFeet,maxRise=1) {
  let floor=surfaceY(x,z);downRay.ray.origin.set(x,Math.max(currentFeet+maxRise,floor+.05),z);downRay.near=0;downRay.far=100;
  const hits=downRay.intersectObjects(nearbyRoots(x,z,1),true);
  for(const hit of hits){if(!isActuallyVisible(hit.object)||hit.object.userData.editorCollision)continue;const normal=hit.face?.normal.clone().transformDirection(hit.object.matrixWorld);if(normal&&normal.y>.55&&hit.point.y<=currentFeet+maxRise&&hit.point.y>floor){floor=hit.point.y;break;}}
  return floor;
}
function isActuallyVisible(obj){let n=obj;while(n){if(!n.visible)return false;n=n.parent;}return true;}
function setMode(next) {
  if(next==='walk'&&groundReview)setGroundReview(false);
  mode=next;keys.clear();dragLook=false;transform.detach();controls.enabled=next==='orbit';$('orbit-mode').classList.toggle('active',next==='orbit');$('walk-mode').classList.toggle('active',next==='walk');$('walk-reticle').hidden=next!=='walk';$('walk-pad').hidden=next!=='walk';
  if(next==='walk') {
    $('explorer').classList.remove('mobile-open');$('inspector').classList.add('mobile-collapsed');
    const p=controls.target.clone();const dir=new THREE.Vector3();camera.getWorldDirection(dir);walkYaw=Math.atan2(-dir.x,-dir.z);walkPitch=-.03;
    let x=p.x,z=p.z;if(selection.kind==='building'&&selection.ids.length===1){const b=draft.layout.buildings.find(r=>r.id===selection.ids[0]);if(b){const a=radians(b.yaw||0),d=(b.size?.[2]||20)/2+8;x=b.c[0]-Math.sin(a)*d;z=b.c[1]-Math.cos(a)*d;walkYaw=Math.atan2(-(b.c[0]-x),-(b.c[1]-z));}}
    const floor=supportAt(x,z,surfaceY(x,z)+1,2);camera.position.set(x,floor+1.75,z);camera.rotation.set(walkPitch,walkYaw,0,'YXZ');
    $('nav-hint').textContent='点击画面后 WASD / 方向键行走 · 按住左键拖动转向';toast('点击画面开始漫游；也可使用右下方向按钮');renderer.domElement.focus({preventScroll:true});
  }else{
    if(document.pointerLockElement)document.exitPointerLock();$('nav-hint').textContent='左键环绕 · 右键平移 · 滚轮缩放 · 单击选择';
    if(camera.position.distanceTo(controls.target)<4)controls.target.copy(camera.position).add(new THREE.Vector3(0,0,-15).applyEuler(camera.rotation));controls.update();updateSelectionVisuals();
  }
}
function moveWalk(dt) {
  if(mode!=='walk'||(document.pointerLockElement!==renderer.domElement&&document.activeElement!==renderer.domElement))return;
  const turn=(keys.has('TurnLeft')?1:0)-(keys.has('TurnRight')?1:0);if(turn){walkYaw+=turn*Math.min(dt,.04)*1.25;camera.rotation.set(walkPitch,walkYaw,0,'YXZ');}
  let dx=(keys.has('KeyD')||keys.has('ArrowRight')?1:0)-(keys.has('KeyA')||keys.has('ArrowLeft')?1:0),dz=(keys.has('KeyS')||keys.has('ArrowDown')?1:0)-(keys.has('KeyW')||keys.has('ArrowUp')?1:0);if(!dx&&!dz)return;
  const norm=Math.hypot(dx,dz),speed=(keys.has('ShiftLeft')||keys.has('ShiftRight')?19:6)*Math.min(dt,.04);dx/=norm;dz/=norm;
  const vx=(dx*Math.cos(walkYaw)+dz*Math.sin(walkYaw))*speed,vz=(-dx*Math.sin(walkYaw)+dz*Math.cos(walkYaw))*speed;
  tryWalk(vx,vz)||tryWalk(vx,0)||tryWalk(0,vz);
}
function tryWalk(dx,dz) {
  if(Math.abs(dx)+Math.abs(dz)<1e-6)return false;
  const x=camera.position.x+dx,z=camera.position.z+dz,feet=camera.position.y-1.75;
  if(x<terrain.origin[0]||x>terrain.origin[0]+terrainSX||z<terrain.origin[1]||z>terrain.origin[1]+terrainSZ)return false;
  const floor=supportAt(x,z,feet,.8),rise=floor-feet;
  if(floor<(terrain.waterLevel??8)-.1||rise>Math.max(.45,Math.hypot(dx,dz)*1.05)||rise< -6)return false;
  const dir=new THREE.Vector3(dx,0,dz).normalize(),nearby=nearbyRoots(x,z,1);
  for(const height of [.72,1.4]){raycaster.set(new THREE.Vector3(camera.position.x,Math.max(feet,floor)+height,camera.position.z),dir);raycaster.near=0;raycaster.far=Math.hypot(dx,dz)+.32;const wall=raycaster.intersectObjects(nearby,true).find(h=>isActuallyVisible(h.object)&&!h.object.userData.editorCollision&&Math.abs(h.face?.normal.clone().transformDirection(h.object.matrixWorld).y||0)<.6);if(wall)return false;}
  camera.position.set(x,floor+1.75,z);return true;
}

let downPoint=null;
renderer.domElement.addEventListener('pointerdown',event=>{renderer.domElement.focus({preventScroll:true});downPoint=[event.clientX,event.clientY];if(mode==='walk'&&event.button===0){dragLook=true;dragLookPoint=[event.clientX,event.clientY];}});
window.addEventListener('pointerup',()=>{dragLook=false;dragLookPoint=null;});
function pointerLockFallback(){if(!lockUnavailable)toast('已使用拖动转向：按住左键移动鼠标，WASD 或方向按钮行走');lockUnavailable=true;$('nav-hint').textContent='WASD / 方向键行走 · 按住左键拖动转向 · 右下按钮也可操作';}
document.addEventListener('pointerlockerror',pointerLockFallback);
renderer.domElement.addEventListener('click',event=>{
  if(!ready)return;
  if(mode==='walk'){renderer.domElement.focus({preventScroll:true});if(!lockUnavailable&&document.pointerLockElement!==renderer.domElement){try{const promise=renderer.domElement.requestPointerLock?.();promise?.catch(pointerLockFallback);}catch{pointerLockFallback();}}return;}
  if(event.button!==0||transform.dragging||!downPoint||Math.hypot(event.clientX-downPoint[0],event.clientY-downPoint[1])>5||transform.axis)return;
  const rect=renderer.domElement.getBoundingClientRect();pointer.set((event.clientX-rect.left)/rect.width*2-1,-(event.clientY-rect.top)/rect.height*2+1);raycaster.setFromCamera(pointer,camera);raycaster.near=0;raycaster.far=7000;
  const candidates=groundReview?(groundReviewGroup?.children.filter(o=>o.userData.id)||[]):tab==='road'?roadGroup.children:tab==='terrace'?terraceGroup.children:selectableRoots;
  const hit=raycaster.intersectObjects(candidates,true).find(h=>isActuallyVisible(h.object)&&!h.object.userData.editorCollision);
  if(hit){const meta=hit.object.userData;select(meta.kind||'building',meta.id||meta.cityId,event.ctrlKey||event.metaKey);if(meta.index!==undefined){selectedPoint=meta.index;updateRoads();}}
});
renderer.domElement.addEventListener('dblclick',()=>{if(mode==='orbit')focusSelection();});
document.addEventListener('mousemove',e=>{if(mode!=='walk')return;let dx=0,dy=0;if(document.pointerLockElement===renderer.domElement){dx=e.movementX;dy=e.movementY;}else if(dragLook&&dragLookPoint&&(e.buttons&1)){dx=e.clientX-dragLookPoint[0];dy=e.clientY-dragLookPoint[1];dragLookPoint=[e.clientX,e.clientY];}else return;walkYaw-=dx*.0023;walkPitch=THREE.MathUtils.clamp(walkPitch-dy*.0023,-1.4,1.4);camera.rotation.set(walkPitch,walkYaw,0,'YXZ');});
window.addEventListener('keydown',e=>{
  if(/INPUT|TEXTAREA|SELECT/.test(document.activeElement?.tagName)||$('help-dialog').open||$('export-dialog').open)return;
  if((e.ctrlKey||e.metaKey)&&e.code==='KeyZ'){e.preventDefault();e.shiftKey?redo():undo();return;}
  if((e.ctrlKey||e.metaKey)&&e.code==='KeyY'){e.preventDefault();redo();return;}
  if(e.code==='KeyF'){e.preventDefault();focusSelection();return;}
  if(e.code==='Delete'&&selection.kind==='building'){$('delete-object').click();return;}
  if(['KeyW','KeyA','KeyS','KeyD','ArrowUp','ArrowDown','ArrowLeft','ArrowRight','ShiftLeft','ShiftRight'].includes(e.code)){keys.add(e.code);e.preventDefault();if(!e.repeat)moveWalk(.035);}
});window.addEventListener('keyup',e=>keys.delete(e.code));window.addEventListener('blur',()=>keys.clear());
window.addEventListener('beforeunload',()=>{if(ready)saveNow();});

$('undo').onclick=undo;$('redo').onclick=redo;$('focus').onclick=focusSelection;$('overview').onclick=overview;
function setGroundReview(active) {
  if(active&&!ready){toast('地面与建筑仍在载入，请稍候');return;}
  if(active&&(!data.groundPlan?.parcels?.length||!data.groundPlan?.pedestrianPaths?.length)){toast('这份快照尚未包含新的街坊地面总图',true);return;}
  groundReview=active;
  if(active)setMode('orbit');
  if(active&&!groundReviewGroup){groundReviewGroup=createGroundReview(data.groundPlan,surfaceY);scene.add(groundReviewGroup);}
  if(groundReviewGroup)groundReviewGroup.visible=active;
  $('ground-review').classList.toggle('active',active);$('ground-review').setAttribute('aria-pressed',String(active));$('ground-review-legend').hidden=!active;
  refreshAll();
  $('nav-hint').textContent=active?'地面审查 · 建筑预留地与步行网来自同一总图 · 点击占地查看建筑':'左键环绕 · 右键平移 · 滚轮缩放 · 单击选择';
}
$('ground-review').disabled=!data.groundPlan?.parcels?.length||!data.groundPlan?.pedestrianPaths?.length;
$('ground-review').onclick=()=>setGroundReview(!groundReview);
$('orbit-mode').onclick=()=>{if(groundReview)setGroundReview(false);setMode('orbit');};$('walk-mode').onclick=()=>setMode('walk');
$('move-tool').onclick=()=>{$('move-tool').classList.toggle('active');$('rotate-tool').classList.remove('active');transform.setMode('translate');transform.showX=true;transform.showY=false;transform.showZ=true;updateSelectionVisuals();};
$('rotate-tool').onclick=()=>{$('rotate-tool').classList.toggle('active');$('move-tool').classList.remove('active');transform.setMode('rotate');transform.showX=false;transform.showY=true;transform.showZ=false;updateSelectionVisuals();};
$('duplicate').onclick=()=>{if(selection.kind==='building'&&selection.ids.length===1){let id;commit(d=>id=duplicateBuilding(data,d,selection.ids[0]),'已复制建筑，可拖动至新位置');select('building',id);}};
$('hide-object').onclick=()=>{const hide=!selection.ids.every(id=>draft.overrides[id]?.hidden);commit(d=>selection.ids.forEach(id=>{if(hide)d.overrides[id]={...d.overrides[id],hidden:true};else{delete d.overrides[id]?.hidden;if(!Object.keys(d.overrides[id]||{}).length)delete d.overrides[id];}}),hide?'已隐藏所选建筑':'已显示所选建筑');};
$('delete-object').onclick=()=>{if(selection.kind!=='building'||!selection.ids.length)return;const ids=[...selection.ids];commit(d=>ids.forEach(id=>removeBuilding(data,d,id)),`已删除 ${ids.length} 栋建筑，可撤销`);};
$('show-roads').onchange=updateRoads;$('show-terraces').onchange=updateTerraces;$('show-hidden').onchange=updateHidden;
$('search').oninput=renderList;$('district').onchange=renderList;$('group').onchange=()=>{$('select-group').hidden=!$('group').value;renderList();};
$('select-group').onclick=()=>{const b=blocks().find(b=>b.id===$('group').value);if(!b)return;selection={kind:'building',ids:b.ids.filter(id=>draft.layout.buildings.some(r=>r.id===id))};renderList();renderInspector();updateSelectionVisuals();focusSelection();};
for(const button of document.querySelectorAll('[data-tab]'))button.onclick=()=>{tab=button.dataset.tab;for(const b of document.querySelectorAll('[data-tab]'))b.classList.toggle('active',b===button);refreshFilters();renderList();if(tab==='terrace'){$('show-terraces').checked=true;updateTerraces();}};
$('landmarks').innerHTML='<option value="">前往地标…</option>'+data.layout.buildings.filter(b=>b.family==='landmarks').map(b=>`<option value="${escapeHTML(b.id)}">${escapeHTML(names(b))}</option>`).join('');
$('landmarks').onchange=()=>{if(!$('landmarks').value)return;select('building',$('landmarks').value);focusSelection();$('landmarks').value='';};
let exportURL=null,exportJSON='';
$('export').onclick=()=>{saveNow();const payload=exportDraft(data,draft,cameraState());exportJSON=JSON.stringify(payload,null,2);if(exportURL)URL.revokeObjectURL(exportURL);exportURL=URL.createObjectURL(new Blob([exportJSON],{type:'application/json;charset=utf-8'}));$('download-json').href=exportURL;$('download-json').download=`晴岚港-布局草稿-${new Date().toISOString().replace(/[:.]/g,'-').slice(0,19)}.json`;$('export-summary').textContent=`${draft.layout.buildings.length} 栋建筑 · ${draft.layout.roads.length} 条道路 · ${draft.layout.blocks?.length||0} 个街坊 · ${changedCount} 项改动`;$('export-text').value=exportJSON;$('export-dialog').showModal();};
$('close-export').onclick=()=>$('export-dialog').close();
$('copy-json').onclick=async()=>{try{await navigator.clipboard.writeText(exportJSON);$('copy-json').textContent='已复制';}catch{$('export-text').parentElement.open=true;$('export-text').focus();$('export-text').select();const ok=document.execCommand('copy');$('copy-json').textContent=ok?'已复制':'已选中，请按 Ctrl+C';}};
$('import').onclick=()=>$('import-file').click();$('import-file').onchange=async()=>{const file=$('import-file').files[0];if(!file)return;try{const next=importDraft(data,JSON.parse(await file.text()));past.push(clone(draft));future=[];draft=next;selection.ids=[];refreshAll();saveSoon();toast('已载入草稿，可撤销此次导入');}catch(error){toast(error.message,true);}finally{$('import-file').value='';}};
$('reset').onclick=()=>{if(!changedCount){toast('当前已经是原始布局');return;}commit(()=>{draft=createDraft(data);selection.ids=[];},'已还原原始布局；可撤销');};
$('help').onclick=()=>$('help-dialog').showModal();$('close-help').onclick=()=>$('help-dialog').close();
$('mobile-directory').onclick=()=>{$('explorer').classList.toggle('mobile-open');$('inspector').classList.add('mobile-collapsed');};
$('mobile-inspector').onclick=()=>{$('inspector').classList.remove('mobile-collapsed');$('explorer').classList.remove('mobile-open');};
$('collapse-inspector').onclick=()=>$('inspector').classList.add('mobile-collapsed');
for(const button of document.querySelectorAll('[data-walk]')){button.onpointerdown=event=>{event.preventDefault();renderer.domElement.focus({preventScroll:true});keys.add(button.dataset.walk);moveWalk(.04);button.setPointerCapture(event.pointerId);};button.onpointerup=button.onpointercancel=()=>keys.delete(button.dataset.walk);button.onlostpointercapture=()=>keys.delete(button.dataset.walk);}
$('baseline-label').textContent=`城市版本 ${data.layout.version} · 基线 ${data.baselineHash.slice(0,12)}`;

new ResizeObserver(()=>{const rect=$('viewport').getBoundingClientRect();camera.aspect=rect.width/rect.height;camera.updateProjectionMatrix();renderer.setSize(rect.width,rect.height);}).observe($('viewport'));
const clock=new THREE.Clock();
function animate(){requestAnimationFrame(animate);const dt=clock.getDelta();if(mode==='orbit')controls.update();else moveWalk(dt);renderer.render(scene,camera);if(performance.now()-lastCoordinateUpdate>300){$('coordinates').textContent=`X ${camera.position.x.toFixed(0)}  Z ${camera.position.z.toFixed(0)}  高 ${camera.position.y.toFixed(1)}m`;lastCoordinateUpdate=performance.now();}}

async function init(){
  updateTerrain();overview();animate();
  await loadAssets();$('load-status').textContent='安置建筑、城防与港口…';await new Promise(r=>setTimeout(r,30));
  ready=true;refreshAll();
  if(draftCamera?.position?.length===3&&draftCamera?.target?.length===3&&[...draftCamera.position,...draftCamera.target].every(Number.isFinite)){camera.position.fromArray(draftCamera.position);controls.target.fromArray(draftCamera.target);controls.update();}
  $('loading').hidden=true;saveNow();
  if(missingAssets.length)toast(`${missingAssets.length} 个模型未能加载，已以线框标记；其余可继续编辑。`,true);
  else if(changedCount)toast('已恢复本机保存的布局草稿');
  window.CITY_EDITOR={getState:()=>clone(draft),getSelection:()=>clone(selection),exportDraft:()=>exportDraft(data,draft,cameraState()),select:(kind,id)=>select(kind,id),getDiagnostics:()=>({ready,objects:objectRoots.size,assets:assetTemplates.size,missingAssets:[...missingAssets],triangles:renderer.info.render.triangles,calls:renderer.info.render.calls,baselineHash:data.baselineHash,groundPlanHash:data.groundPlanHash||null,groundObjects:groundCollisionRoots.size,groundReview,parcels:data.groundPlan?.parcels?.length||0,pedestrianPaths:data.groundPlan?.pedestrianPaths?.length||0})};
}
init().catch(error=>{console.error(error);$('load-status').textContent=`加载未完成：${error.message}`;$('save-status').textContent='加载失败';$('save-dot').className='warn';});
