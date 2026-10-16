import { build } from 'esbuild';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';
import { gzipSync } from 'node:zlib';
import { Script } from 'node:vm';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const args = process.argv.slice(2);
const option = (name, fallback) => { const i = args.indexOf(name); return i < 0 ? fallback : resolve(args[i + 1]); };
const dataPath = option('--data', resolve(here, 'city-data.json'));
const outPath = option('--out', resolve(root, 'docs/city_v5/晴岚港-主城漫游.html'));
const data = JSON.parse(await readFile(dataPath, 'utf8'));
if (!data.layout || !data.terrain || !data.assets || !Array.isArray(data.sceneObjects)) throw new Error('城市数据不完整');
if(data.groundPlan?.faces?.length){const groundRows=data.sceneObjects.filter(r=>r.groundId);if(!data.groundPlanHash||!groundRows.length||groundRows.some(r=>!data.collisionAssets?.[r.asset]?.triangles?.length))throw new Error('新地面缺少同源实体或碰撞出口，不能用旧场景构建新页面');}
const bundled = await build({ entryPoints: [resolve(here, 'main.js')], bundle: true, write: false, format: 'iife', platform: 'browser', target: ['chrome110', 'firefox115', 'safari16'], minify: true, legalComments: 'inline' });
const template = await readFile(resolve(here, 'index.html'), 'utf8');
const css = await readFile(resolve(here, 'style.css'), 'utf8');
const safeJSON = JSON.stringify(data).replaceAll('<', '\\u003c').replaceAll('\u2028', '\\u2028').replaceAll('\u2029', '\\u2029');
const js = bundled.outputFiles[0].text.replaceAll('</script', '<\\/script');
const compressed = gzipSync(Buffer.from(safeJSON), { level: 9 }).toString('base64');
const bootstrap = `window.CITY_DATA_READY=(async()=>{document.getElementById('load-status').textContent='正在解压内置城市…';const raw=atob('${compressed}'),bytes=new Uint8Array(raw.length);for(let i=0;i<raw.length;i++)bytes[i]=raw.charCodeAt(i);if(!window.DecompressionStream)throw new Error('请使用较新版本的 Chrome、Edge 或 Firefox 打开此页面');const stream=new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'));window.CITY_DATA=JSON.parse(await new Response(stream).text());})();`;
const runner = `window.CITY_DATA_READY.then(()=>{${js}}).catch(error=>{document.getElementById('load-status').textContent='加载未完成：'+error.message;console.error(error);});`;
// Callback replacements preserve literal $&, $` and $' inside Three.js shader code.
const html = template.replace('/* CITY_STYLE */', () => css).replace('/* CITY_DATA */', () => bootstrap).replace('/* CITY_BUNDLE */', () => runner);
const inlineScripts = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
if (inlineScripts.length !== 2) throw new Error('构建后的脚本边界无效');
for (const [index, match] of inlineScripts.entries()) new Script(match[1], { filename: `city-inline-${index}.js` });
await mkdir(dirname(outPath), { recursive: true });
await writeFile(outPath, html, 'utf8');
const result = { path: outPath, bytes: Buffer.byteLength(html), sourceDataBytes: Buffer.byteLength(safeJSON), compression: 'embedded gzip / native browser decompression', sha256: createHash('sha256').update(html).digest('hex'), embeddedSnapshotSha256: createHash('sha256').update(safeJSON).digest('hex'), sourceFileSha256: createHash('sha256').update(await readFile(dataPath)).digest('hex'), bundleSha256: createHash('sha256').update(js).digest('hex'), baselineHash: data.baselineHash, sceneHash: data.sceneHash, terrainHash: data.terrainHash, groundPlanHash: data.groundPlanHash || null, groundFaces: data.groundPlan?.faces?.length || 0, groundParcels: data.groundPlan?.parcels?.length || 0, groundPedestrianPaths: data.groundPlan?.pedestrianPaths?.length || 0, layoutVersion: data.layout.version, objects: data.sceneObjects.length, assets: Object.keys(data.assets).length, offline: true, scriptSyntaxVerified: true, externalRuntimeDependencies: [], browserVerification: 'Actual localhost browser load is tracked separately; file:// automation is blocked by browser protocol policy.' };
await writeFile(`${outPath}.build.json`, JSON.stringify(result, null, 2), 'utf8');
console.log(JSON.stringify(result, null, 2));
