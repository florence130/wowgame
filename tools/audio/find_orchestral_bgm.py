from pathlib import Path
import urllib.request,re,concurrent.futures,html
p=Path('.local/bgm_revision_20261012');p.mkdir(exist_ok=True,parents=True)
def inspect(name):
    try:
        page=urllib.request.urlopen(urllib.request.Request('https://www.scottbuckley.com.au/library/'+name+'/',headers={'User-Agent':'Mozilla/5.0'}),timeout=25).read().decode()
        (p/(name+'.html')).write_text(page,encoding='utf-8')
        desc=re.search(r'property="og:description" content="([^"]+)',page)
        url=re.search(r'mp3:\s*"([^"]+)',page)
        return name,html.unescape(desc[1]) if desc else '',url[1] if url else '', 'licenses/by/4.0' in page
    except Exception as e:return name,str(e)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    for result in pool.map(inspect,['childhood','memories-of-home','solace','horizons','a-kind-of-hope','hiraeth','undertow','the-old-ones','snowfall','moonlight']):print(result,flush=True)
