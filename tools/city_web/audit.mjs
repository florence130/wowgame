import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { gunzipSync } from 'node:zlib';
import { Script } from 'node:vm';

const here=dirname(fileURLToPath(import.meta.url)),root=resolve(here,'../..');
const path=resolve(root,'docs/city_v5/晴岚港-主城漫游.html');
const html=await readFile(path,'utf8'),build=JSON.parse(await readFile(`${path}.build.json`,'utf8'));
const hash=value=>createHash('sha256').update(value).digest('hex');
const encoded=html.match(/const raw=atob\('([A-Za-z0-9+/=]+)'\)/)?.[1];
if(!encoded)throw new Error('未找到完整内置快照');
const decoded=gunzipSync(Buffer.from(encoded,'base64')).toString('utf8'),data=JSON.parse(decoded);
const scripts=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
for(const [i,script]of scripts.entries())new Script(script[1],{filename:`inline-${i}.js`});
const externalAssets=[],invalidGLBs=[];
for(const [id,raw]of Object.entries(data.assets)){
  const bytes=Buffer.from(typeof raw==='string'?raw:raw.base64,'base64');
  if(bytes.length<20||bytes.readUInt32LE(0)!==0x46546c67){invalidGLBs.push(id);continue;}
  const gltf=JSON.parse(bytes.subarray(20,20+bytes.readUInt32LE(12)).toString('utf8'));
  for(const item of [...(gltf.buffers||[]),...(gltf.images||[])])if(item.uri&&!item.uri.startsWith('data:'))externalAssets.push({id,uri:item.uri});
}
const sourceFile=await readFile(resolve(here,'city-data.json'));
const report={
  generatedAt:new Date().toISOString(),htmlPath:path,htmlSha256:hash(html),embeddedSnapshotSha256:hash(decoded),sourceFileSha256:hash(sourceFile),
  baselineHash:data.baselineHash,sceneHash:data.sceneHash,terrainHash:data.terrainHash,
  counts:{objects:data.sceneObjects.length,assets:Object.keys(data.assets).length,buildings:data.layout.buildings.length,roads:data.layout.roads.length,blocks:data.layout.blocks?.length||0},
  checks:{htmlMatchesBuildHash:hash(html)===build.sha256,snapshotMatchesBuildHash:hash(decoded)===build.embeddedSnapshotSha256,sourceFileMatchesBuildHash:hash(sourceFile)===build.sourceFileSha256,twoValidInlineScripts:scripts.length===2,noRemoteScriptOrStylesheet:!/<(?:script|link)[^>]+(?:src|href)\s*=/i.test(html),allSceneAssetReferencesResolve:data.sceneObjects.every(row=>data.assets[row.asset]),allGLBsSelfContained:externalAssets.length===0&&invalidGLBs.length===0,fullLayoutEqualsSource:JSON.stringify(data.layout)===JSON.stringify(JSON.parse(sourceFile).layout)},
  externalAssets,invalidGLBs,
  evidenceBoundary:'Static package/hash audit. Actual localhost UI behavior was tested separately by the parent agent. Automated file:// opening is prohibited by the browser protocol policy, so double-click opening is not claimed as observed.',
  fileDoubleclickVerified:false,
};
report.pass=Object.values(report.checks).every(Boolean);
const out=resolve(root,'.local/city_v5/web_editor_audit.json');await mkdir(dirname(out),{recursive:true});await writeFile(out,JSON.stringify(report,null,2),'utf8');console.log(JSON.stringify({...report,output:out},null,2));if(!report.pass)process.exitCode=1;
