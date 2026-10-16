"""Build a local, self-contained navigation page from actual build metadata."""
import json,pathlib,sys,html
folder=pathlib.Path(sys.argv[1]);m=json.loads((folder/'manifest.json').read_text(encoding='utf-8'))
esc=html.escape
cards=[]
for key,title in [('farm','农舍'),('barn','谷仓'),('windmill','风车')]:
    thumbs=''.join(f'<a href="renders/{key}_{view}.png"><img loading="lazy" src="renders/{key}_{view}.png" alt="{title} {view}"></a>' for view in ['front','right','back'])
    cards.append(f'<article><h2>{title}</h2><a href="renders/{key}_hero.png"><img class="hero" src="renders/{key}_hero.png" alt="{title}实际Blender渲染"></a><div class="views">{thumbs}</div><p><a href="godot/assemblies/VALE_{key}.scn">Godot原生场景（优先）</a> · <a href="assemblies/VALE_{key}.glb">源GLB</a> · <a href="reimport/renders/reimport_{key}_hero.png">GLB重载渲染</a></p></article>')
rows=[]
for r in m['modules']:
    lo,hi=r['bounds_blender'];size=' × '.join(f'{hi[i]-lo[i]:.2f}' for i in range(3))
    rows.append(f'<tr><td><a href="{esc(r["file"])}">{esc(r["id"])}</a></td><td>{size}</td><td>{esc(", ".join(r["methods"]))}</td></tr>')
page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>晨露谷建筑构件</title><style>
body{margin:0;background:#f4eee2;color:#342412;font:16px/1.65 system-ui,sans-serif}main{max-width:1350px;margin:auto;padding:32px}h1,h2{line-height:1.2}p{max-width:80ch}a{color:#435a79}section{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:24px}article{background:#fffaf1;padding:16px;border-radius:12px}img{display:block;width:100%;height:auto;border-radius:6px}.views{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-top:8px}table{width:100%;border-collapse:collapse;background:#fffaf1}td,th{text-align:left;padding:8px;border-bottom:1px solid #d4c8b1}.table{overflow:auto}small{color:#675749}@media(max-width:800px){section{grid-template-columns:1fr}main{padding:16px}}</style><main>'''
page+=f'<h1>晨露谷 · 农庄建筑构件</h1><p>{esc(folder.name)} · 农舍、谷仓、风车 · {len(m["modules"])} 类独立构件。以下为实际模型渲染；点击图片查看原尺寸。</p>'
page+='<p><a href="vale_kit.blend">可编辑 Blender 源文件</a> · <a href="manifest.json">构件接口与色板</a> · <a href="validation.json">GLB 检查</a> · <a href="godot_native_validation.json">Godot原生场景检查</a></p><p>Godot请优先使用.scn。裸GLB在本机引擎导入后未保留零镜面反射，必须按HANDOFF配置导入脚本；原始失败报告保留为godot_validation.json。</p>'
page+='<p>谷仓采用连续覆草层、厚檐与顺坡纤维。砂石墙保留矿物颗粒，红砖表现孔隙与烧结变化；全材质哑光。主色依据用户色板，贴图包含同色系明暗。</p><section>'+''.join(cards)+'</section>'
page+='<h2>模块目录</h2><p>尺寸按 Blender X / Y / Z，单位米。拼接使用 manifest 中的 sockets，不使用装饰外包。Godot 导入后 Y 朝上、-Z 朝前。</p><div class="table"><table><tr><th>模块 / GLB</th><th>实际外包（米）</th><th>制作手法</th></tr>'+''.join(rows)+'</table></div>'
page+='<p><a href="assemblies/VALE_rotor.glb">独立风车转子</a> · <a href="assemblies/VALE_fence_demo.glb">围栏组合示例</a></p><small>未接入正式地图；未完成碰撞、导航或玩家视角性能验收。审查结论见 docs/vale_kit_v1/REVIEW.md。</small></main></html>'
(folder/'catalog.html').write_text(page,encoding='utf-8')
print(folder/'catalog.html')
