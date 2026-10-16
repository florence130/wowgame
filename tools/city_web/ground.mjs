import * as THREE from 'three';

// The scene supplies geometry. These profiles only add metre-scaled stone joints.
export function groundMaterialProfile(row) {
  const key = `${row.groundKind || ''} ${row.groundMaterial || ''}`.toLowerCase();
  if (/park|grass/.test(key)) return { id:'park', color:'#788c60', tile:[1,1], joint:0, joints:false };
  if (/curb|kerb|cap/.test(key)) return { id:'curb', color:'#d9cfb9', tile:[.9,.3], joint:.009, joints:true };
  if (/retaining|wall|riser|edge/.test(key)) return { id:'retaining', color:'#aca591', tile:[1.1,.5], joint:.016, joints:true };
  if (/sidewalk|walkway|promenade|pedestrian|step|stair|ramp/.test(key)) return { id:'sidewalk', color:'#d0c5ae', tile:[.8,.5], joint:.009, joints:true };
  if (/road|carriage|street/.test(key)) return { id:'road', color:'#95958b', tile:[.45,.26], joint:.012, joints:true };
  if (/plaza|square/.test(key)) return { id:'plaza', color:'#cfc3aa', tile:[1.2,.8], joint:.012, joints:true };
  return { id:'paving', color:'#c4baa4', tile:[1,.65], joint:.012, joints:true };
}

const materials = new Map();
export function applyGroundAppearance(root, row) {
  const profile = groundMaterialProfile(row);
  if (!materials.has(profile.id)) {
    const material = new THREE.MeshStandardMaterial({ color:profile.color, roughness:.96, metalness:0, side:THREE.DoubleSide });
    material.name = `city-ground-${profile.id}-metre-joints`;
    if (profile.joints) {
      material.onBeforeCompile = shader => {
        shader.uniforms.cityTile = { value:new THREE.Vector2(...profile.tile) };
        shader.uniforms.cityJoint = { value:profile.joint };
        shader.vertexShader = 'varying vec3 vCityPosition; varying vec3 vCityNormal;\n' + shader.vertexShader;
        shader.vertexShader = shader.vertexShader.replace('#include <project_vertex>', '#include <project_vertex>\nvCityPosition = (modelMatrix * vec4(transformed, 1.0)).xyz;\nvCityNormal = normalize(mat3(modelMatrix) * objectNormal);');
        shader.fragmentShader = 'varying vec3 vCityPosition; varying vec3 vCityNormal; uniform vec2 cityTile; uniform float cityJoint;\n' + shader.fragmentShader;
        shader.fragmentShader = shader.fragmentShader.replace('#include <color_fragment>', `#include <color_fragment>
          vec3 cn = abs(normalize(vCityNormal));
          vec2 cp = cn.y >= max(cn.x, cn.z) ? vCityPosition.xz : (cn.x > cn.z ? vCityPosition.zy : vCityPosition.xy);
          vec2 ct = cp / cityTile;
          ct.x += mod(floor(ct.y), 2.0) * .5;
          vec2 cf = fract(ct), aa = max(fwidth(ct), vec2(.0001));
          vec2 inside = smoothstep(vec2(cityJoint) / cityTile - aa, vec2(cityJoint) / cityTile + aa, min(cf, 1.0 - cf));
          float jointMask = inside.x * inside.y;
          float variation = fract(sin(dot(floor(ct), vec2(12.9898,78.233))) * 43758.5453);
          float grain = fract(sin(dot(cp, vec2(271.73,159.37))) * 43758.5453);
          diffuseColor.rgb *= mix(.67, .945 + variation * .11, jointMask) * (.985 + grain * .025);
        `);
      };
      material.customProgramCacheKey = () => `city-ground-metre-joints-v1-${profile.id}`;
    }
    materials.set(profile.id, material);
  }
  root.traverse(node => { if (node.isMesh && !node.userData.editorCollision) node.material = materials.get(profile.id); });
}

// Exact triangles from the Godot ConcavePolygonShape3D, never inferred from Terrain.
export function makeGroundCollision(row, collisionAsset) {
  if (!collisionAsset?.vertices?.length || !collisionAsset?.triangles?.length) return null;
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.Float32BufferAttribute(collisionAsset.vertices.flat(), 3));
  // Godot collision faces use clockwise front faces; Three.js uses CCW.
  geometry.setIndex(collisionAsset.triangles.flatMap(([a,b,c]) => [a,c,b]));
  geometry.computeVertexNormals();
  const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ side:THREE.DoubleSide }));
  mesh.name = `physical-${row.id}`;
  mesh.userData.cityId = row.id;
  mesh.userData.physicalGround = true;
  mesh.position.fromArray(row.position);
  mesh.rotation.y = THREE.MathUtils.degToRad(row.yaw || 0);
  mesh.scale.fromArray(row.scale || [1,1,1]);
  mesh.updateMatrixWorld(true);
  return mesh; // Not attached to the visible scene; used only for physical queries.
}

export function decodeTerrainColors(terrain) {
  if (!terrain.surfaceColors) return null;
  const raw = atob(terrain.surfaceColors);
  if (raw.length !== terrain.cols * terrain.rows * 3) throw new Error('地表颜色数据与高度网格不一致');
  return Uint8Array.from(raw, c => c.charCodeAt(0));
}
