from pathlib import Path
import urllib.request,re,zipfile
p=Path('.local/sfx_revision_20261012');p.mkdir(parents=True,exist_ok=True)
for name in ['impact-sounds','digital-audio','sci-fi-sounds']:
    try:
        page=urllib.request.urlopen('https://kenney.nl/assets/'+name,timeout=25).read()
        (p/(name+'.html')).write_bytes(page)
        url=re.findall(r'https://[^"\s<>]+\.zip',page.decode())[0]
        data=urllib.request.urlopen(url,timeout=40).read();(p/(name+'.zip')).write_bytes(data)
        with zipfile.ZipFile(p/(name+'.zip')) as z:
            print(name,z.read('License.txt').decode(),z.namelist(),flush=True)
    except Exception as e: print(name,str(e),flush=True)
