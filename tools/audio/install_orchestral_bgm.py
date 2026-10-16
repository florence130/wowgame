from pathlib import Path
import sys,subprocess,json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.local/music_reference_20261011/rhythm_deps'))
import numpy as np,soundfile as sf
work=ROOT/'.local/bgm_revision_20261012';out=ROOT/'assets/audio/orchestral';out.mkdir(parents=True,exist_ok=True)
credits=ROOT/'assets/third_party/orchestral_bgm';credits.mkdir(parents=True,exist_ok=True)
ff=ROOT/'.local/menu_music_20261011/deps/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
mapping={'menu':'moonlight','vale':'childhood','city':'midsommar','tidewind':'snowfall','sanctum':'undertow'}
rows=[]
for key,track in mapping.items():
    pcm=work/(track+'.wav')
    subprocess.run([str(ff),'-y','-v','error','-i',str(work/(track+'.mp3')),'-ar','44100','-ac','2',str(pcm)],check=True)
    y,sr=sf.read(pcm,always_2d=True)
    assert np.isfinite(y).all()
    gain=min(10**(-25/20)/max(np.sqrt(np.mean(y*y)),1e-9),10**(-5/20)/max(np.abs(y).max(),1e-9))
    y*=gain
    # Keep complete composition and its ending; do not crop or crossfade phrases.
    sf.write(pcm,y,sr,subtype='PCM_24');dst=out/(key+'.ogg')
    subprocess.run([str(ff),'-y','-v','error','-i',str(pcm),'-c:a','libvorbis','-q:a','6',str(dst)],check=True)
    decoded,rate=sf.read(dst,always_2d=True);assert np.abs(decoded).max()<1
    rows.append({'role':key,'title':track.title(),'author':'Scott Buckley','license':'CC-BY-4.0','source':'https://www.scottbuckley.com.au/library/'+track+'/','file':str(dst.relative_to(ROOT)),'modifications':'constant gain and OGG encoding; complete composition preserved','duration_s':round(len(decoded)/rate,3),'peak_dbfs':round(float(20*np.log10(np.abs(decoded).max())),2),'sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'aesthetic_acceptance':'not auditioned'})
    shutil.copy2(work/(track+'.html'),credits/(track+'_source.html'))
(credits/'manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
(credits/'CREDITS.txt').write_text('\n'.join("'"+r['title']+"' by Scott Buckley - released under CC-BY 4.0. www.scottbuckley.com.au\n"+r['source'] for r in rows)+'\nLicense: https://creativecommons.org/licenses/by/4.0/\nModifications: constant level adjustment and OGG encoding. Full compositions retained.\nNight piano/harp adaptations not yet made; any shared original is temporary and not an arrangement.\n',encoding='utf-8')
print(json.dumps(rows))
