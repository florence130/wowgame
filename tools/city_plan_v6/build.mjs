// 打包：three.js + 源码 → 单文件 HTML（离线可用）；另导出 plan.json 给 Godot 生成器
// node build.mjs
import { build } from '../city_web/node_modules/esbuild/lib/main.js';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const outDir = resolve(root, 'docs/city_v6');
await mkdir(outDir, { recursive: true });
const res = await build({
  entryPoints: [resolve(here, 'src/main.js')], bundle: true, write: false, format: 'iife', minify: true, target: ['chrome110', 'firefox115', 'safari16'],
  nodePaths: [resolve(here, '../city_web/node_modules')], legalComments: 'none',
});
const js = res.outputFiles[0].text.replaceAll('</script', '<\\/script');
const tpl = await readFile(resolve(here, 'index.html'), 'utf8');
const css = await readFile(resolve(here, 'style.css'), 'utf8');
const body = tpl.replace('/* STYLE */', () => css).replace('/* BUNDLE */', () => js);
// 片段（发布为 Artifact 时外层骨架由平台提供）
await writeFile(resolve(outDir, 'artifact.html'), body, 'utf8');
// 完整文档（本地双击打开）
const full = `<!doctype html>\n<html lang="zh-CN">\n<head>\n<meta charset="utf-8">\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n${body.replace(/<canvas id="scene"[\s\S]*$/, '')}</head>\n<body>\n${body.slice(body.indexOf('<canvas id="scene"'))}\n</body>\n</html>\n`;
await writeFile(resolve(outDir, '晴岚港v6-主城漫游.html'), full, 'utf8');
// 规划数据
const plan = await import(pathToFileURL(resolve(here, 'src/plan.js')).href);
await writeFile(resolve(outDir, 'plan.json'), JSON.stringify(plan.PLAN, null, 1), 'utf8');
console.log('OK', (Buffer.byteLength(full) / 1024).toFixed(0) + ' KB', plan.stats());
