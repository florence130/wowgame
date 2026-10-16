"""Create a searchable local catalogue and precise Markdown inventory from a build."""
import json,sys,html
from pathlib import Path
folder=Path(sys.argv[1]).resolve();root=Path(__file__).resolve().parents[3]
d=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
rows=[];cards=[]
for i,a in enumerate(d['assets'],1):
    dims=[a['bounds_max'][k]-a['bounds_min'][k] for k in range(3)]
    size=' × '.join(f'{v:.2f}' for v in dims)
    rows.append(f"| {i:02d} | `{a['id']}` | {a['label_zh']} | {size} | {a['triangles']} | {', '.join(a['techniques'])} |")
    img=f'renders/thumbnails/{a["id"]}.png'
    views=''.join(f'<a href="renders/thumbnails/{a["id"]}_{v}.png">{label}</a>' for v,label in [('front','正'),('side','侧'),('back','背')] if (folder/'renders/thumbnails'/f'{a["id"]}_{v}.png').exists())
    cards.append(f'<article data-search="{a["id"]} {a["label_zh"]} {a["route"]}"><a href="{img}"><img src="{img}" alt="{a["label_zh"]}" loading="lazy"></a><div class="body"><span class="num">{i:02d}</span><h2>{a["label_zh"]}</h2><code>{a["id"]}</code><p>{size} m · {a["triangles"]:,} 三角面</p><footer><a href="{a["file"]}">GLB</a>{views}</footer></div></article>')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>晨钟修道院 · 模块库</title><style>
*{box-sizing:border-box}body{margin:0;background:#f2eee6;color:#352f27;font:15px/1.6 system-ui,'Microsoft YaHei'}header{padding:44px max(5vw,24px) 28px;background:#e7decb;border-bottom:1px solid #c9bda4}.eyebrow{letter-spacing:.16em;color:#986348;font-size:12px;font-weight:700}h1{font:42px/1.2 Georgia,serif;margin:12px 0}header p{max-width:880px;color:#655b4c}.pills{display:flex;gap:8px;flex-wrap:wrap}.pills span{border:1px solid #baaa8f;border-radius:30px;padding:3px 14px}main{max-width:1600px;margin:auto;padding:28px}input{width:100%;padding:14px 18px;border:1px solid #c3b7a1;border-radius:7px;font:inherit;background:#fffdf7;margin:0 0 25px}.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(245px,1fr));gap:18px}article{background:#fffdf7;border:1px solid #d6ccba;border-radius:9px;overflow:hidden}article img{width:100%;display:block;background:#ece8df;aspect-ratio:1.2;object-fit:contain}.body{padding:14px 17px}h2{font-size:18px;margin:0 0 4px}.num{float:right;color:#a37150;font:24px Georgia}code{font-size:12px;color:#796c59}.body p{font-size:12px;color:#756a59}footer{display:flex;gap:18px}a{color:#8a4d32;text-decoration:none}a:hover{text-decoration:underline}.hero{width:100%;max-height:640px;object-fit:contain;margin-bottom:24px}.hint{font-size:13px;color:#766c5d}article[hidden]{display:none}
</style><header><div class="eyebrow">AETHERLANDS / DAWNBELL ABBEY</div><h1>晨钟修道院 · 可拼装构件库</h1><p>以 4 米开间组织墙、门窗、屋面、柱廊和桥梁。所有缩略图由实际 Blender 模型渲染；点击构件查看原图，带“正／侧／背”的项提供同一模型正交三视图。</p><div class="pills"><span>49 类构件</span><span>米制 / 平涂</span><span>CSG + SDF</span><span>可编辑 Blender 源</span></div></header><main><img class="hero" src="renders/ABY_Demo.png" alt="实际模块组合的修道院"><p class="hint">当前为模块工具首版。玻璃为不透明平涂；门为静态件；地图碰撞、导航与性能尚未接入。尺寸是几何包围盒，拼装请用 manifest 中的逻辑接口。</p><input id="q" placeholder="查找：墙 / 玻璃 / 石桥 / roof / SDF …" aria-label="查找构件"><div class="grid">'''+''.join(cards)+'''</div></main><script>const q=document.querySelector('#q');q.addEventListener('input',()=>document.querySelectorAll('article').forEach(a=>a.hidden=!a.dataset.search.toLowerCase().includes(q.value.toLowerCase().trim())));</script></html>'''
(folder/'catalog.html').write_text(page,encoding='utf-8')
doc='# 修道院构件清单\n\n当前模型以 `'+folder.name+'` 为准，49 类。下表尺寸为 Blender XYZ 包围盒，含窗台、挑檐和托架；不是拼装模数。全部生成可查看，不等于全地图美术最终验收。\n\n| # | 资产ID | 名称 | 包围盒 XYZ / m | 三角面 | 制作方法 |\n|---|---|---|---|---:|---|\n'+'\n'.join(rows)+'\n'
(root/'docs/abbey_kit_v1/INVENTORY.md').write_text(doc,encoding='utf-8')
print(folder/'catalog.html')
