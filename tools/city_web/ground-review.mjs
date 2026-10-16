import * as THREE from 'three';

// Review overlays describe the shared plan; they never stand in for physical paving.
export function createGroundReview(plan, surfaceHeight) {
  const group=new THREE.Group();group.name='ground-plan-review';
  const style={block:'#856e56',parcel:'#9b8060',footprint:'#755c46',court:'#b9a58a',path:'#267e8a',entrance:'#ce9738'};
  const ringOf=value=>Array.isArray(value)?value:value?.polygon||[];
  function outline(ring,color,y,id='',offset=.22,dashed=false){
    if(ring.length<3)return;
    const points=[...ring,ring[0]].map(([x,z])=>new THREE.Vector3(x,typeof y==='function'?y(x,z):y??surfaceHeight(x,z),z).add(new THREE.Vector3(0,offset,0)));
    const material=dashed?new THREE.LineDashedMaterial({color,dashSize:2.5,gapSize:1.5,transparent:true,opacity:.85}):new THREE.LineBasicMaterial({color,transparent:true,opacity:.94});
    const line=new THREE.Line(new THREE.BufferGeometry().setFromPoints(points),material);line.computeLineDistances();line.renderOrder=6;line.userData={kind:'building',id,baseColor:color,review:true};group.add(line);
  }
  function fill(ring,holes,color,y,id='',opacity=.12){
    if(ring.length<3)return;
    const shape=new THREE.Shape(ring.map(p=>new THREE.Vector2(...p)));
    for(const hole of holes||[])if(hole.length>=3)shape.holes.push(new THREE.Path(hole.map(p=>new THREE.Vector2(...p))));
    const geometry=new THREE.ShapeGeometry(shape),points=geometry.attributes.position;
    for(let i=0;i<points.count;i++){const x=points.getX(i),z=points.getY(i);points.setXYZ(i,x,(y??surfaceHeight(x,z))+.19,z);}
    geometry.computeVertexNormals();
    const mesh=new THREE.Mesh(geometry,new THREE.MeshBasicMaterial({color,transparent:true,opacity,depthWrite:false,side:THREE.DoubleSide,polygonOffset:true,polygonOffsetFactor:-3}));
    mesh.renderOrder=4;mesh.userData={kind:'building',id,baseColor:color,review:true};group.add(mesh);
  }
  for(const block of plan.blocks||[])outline(ringOf(block.polygon),style.block,block.level,'',.16,true);
  for(const parcel of plan.parcels||[]){
    const id=parcel.buildingId||'',ring=ringOf(parcel.polygon),footprint=ringOf(parcel.buildingFootprint);
    outline(ring,style.parcel,parcel.level,id,.24,true);
    fill(footprint,parcel.buildingFootprint?.holes||[],style.footprint,parcel.level,id,.2);
    outline(footprint,style.footprint,parcel.level,id,.27);
    for(const court of [parcel.frontCourt,parcel.backCourt])outline(ringOf(court),style.court,parcel.level,id,.22,true);
    if(parcel.entrance?.length===3){const marker=new THREE.Mesh(new THREE.CircleGeometry(.9,12),new THREE.MeshBasicMaterial({color:style.entrance,side:THREE.DoubleSide}));marker.rotation.x=-Math.PI/2;marker.position.fromArray(parcel.entrance);marker.position.y+=.34;marker.userData={kind:'building',id,baseColor:style.entrance,review:true};marker.renderOrder=7;group.add(marker);}
  }
  for(const path of plan.pedestrianPaths||[]){
    const pathHeight=(x,z)=>{let best=Infinity,y=null;for(let i=1;i<(path.centerline?.length||0);i++){const a=path.centerline[i-1],b=path.centerline[i],dx=b[0]-a[0],dz=b[2]-a[2],t=THREE.MathUtils.clamp(((x-a[0])*dx+(z-a[2])*dz)/(dx*dx+dz*dz||1),0,1),distance=Math.hypot(x-a[0]-t*dx,z-a[2]-t*dz);if(distance<best){best=distance;y=a[1]+t*(b[1]-a[1]);}}return y??surfaceHeight(x,z);};
    outline(ringOf(path.polygon),style.path,pathHeight,'',.3);
    if(path.centerline?.length>1){const points=path.centerline.map(p=>new THREE.Vector3(p[0],p[1]+.32,p[2]));const line=new THREE.Line(new THREE.BufferGeometry().setFromPoints(points),new THREE.LineDashedMaterial({color:style.path,dashSize:2,gapSize:1.5,opacity:.6,transparent:true}));line.computeLineDistances();line.renderOrder=6;line.userData={review:true,baseColor:style.path};group.add(line);}
  }
  return group;
}

export function highlightGroundParcels(group, ids) {
  group?.traverse(node=>{if(node.material?.color&&node.userData.baseColor)node.material.color.set(ids.includes(node.userData.id)?'#d39b39':node.userData.baseColor);});
}
