"""Acquire CC0 Freesound preview sources and prepare short gameplay transients."""
from pathlib import Path
import concurrent.futures, hashlib, html, json, re, subprocess, sys, urllib.request, wave

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/third_party/combat_freesound'
OUT = ROOT / 'assets/audio/combat'
FF = ROOT / '.local/menu_music_20261011/deps/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
import numpy as np

SOUNDS = [
    ('swing','yutface',257015,0.32),
    ('blade','CogFireStudios',547040,0.24),
    ('metal','spycrah',471095,0.46),
    ('fire','qubodup',159725,0.65),
    ('frost','Nox_Sound',625740,0.45),
    ('water','qubodup',442773,0.45),
    ('lightning','BigKahuna360',160421,0.30),
    ('shadow','LucasDuff',516081,0.55),
    ('light','MattLeschuck',511485,0.58),
    ('step_stone_a','sgossner',197778,0.30),
    ('step_stone_b','sgossner',197780,0.30),
    ('step_dirt','d00121058',390757,0.27),
]

def get(url):
    req = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=40) as response:
        return response.read()

def acquire(row):
    key, author, sid, length = row
    page_url = f'https://freesound.org/people/{author}/sounds/{sid}/'
    page_path = SOURCE / f'{sid}.html'
    page = page_path.read_text(encoding='utf-8') if page_path.exists() else get(page_url).decode('utf-8')
    page_path.write_text(page, encoding='utf-8')
    if not re.search(r'creativecommons.org/publicdomain/zero/1.0/', page):
        raise RuntimeError(f'CC0 license not verified: {sid}')
    urls = sorted(set(re.findall(r'https://cdn\.freesound\.org/previews/[^\s"<>]+-hq\.mp3', page)))
    if len(urls) != 1:
        raise RuntimeError(f'Unambiguous preview missing: {sid}')
    source = SOURCE / f'{sid}_hq.mp3'
    if not source.exists():
        source.write_bytes(get(urls[0]))
    pcm = SOURCE / f'{sid}_decoded.wav'
    subprocess.run([str(FF),'-y','-v','error','-i',str(source),'-ar','44100','-ac','1','-c:a','pcm_s16le',str(pcm)],check=True)
    with wave.open(str(pcm),'rb') as stream:
        sr=stream.getframerate()
        y=np.frombuffer(stream.readframes(stream.getnframes()),dtype='<i2').astype('float32')/32768
    # Use a local transient, not the entire source sequence/ambience.
    window = max(1, int(sr * .016))
    energy = np.convolve(y*y, np.ones(window,dtype='float32')/window, mode='same')
    peak = int(np.argmax(energy))
    threshold = max(float(energy[peak]) * .06, 1e-8)
    start = peak
    while start > 0 and energy[start] > threshold and peak-start < sr*.16:
        start -= 1
    start = max(0, start - int(sr * .008))
    clip = y[start : min(len(y), start + int(sr*length))].copy()
    clip -= np.mean(clip)
    fade_in = min(len(clip)//4,int(sr*.003))
    fade_out = min(len(clip)//3,int(sr*.065))
    clip[:fade_in] *= np.linspace(0,1,fade_in)
    clip[-fade_out:] *= np.linspace(1,0,fade_out)
    clip *= (10**(-6/20)) / max(float(np.max(np.abs(clip))),1e-6)
    output = OUT / f'{key}.wav'
    with wave.open(str(output),'wb') as stream:
        stream.setnchannels(1);stream.setsampwidth(2);stream.setframerate(sr)
        stream.writeframes((clip*32767).astype('<i2').tobytes())
    title_match = re.search(r'<title>(.*?)</title>',page,re.S)
    title = html.unescape(re.sub(r'\s+',' ',title_match.group(1))).strip() if title_match else key
    result = {'key':key,'author':author,'sound_id':sid,'title':title,'source_page':page_url,'download_url':urls[0], 'source_kind':'public high-quality MP3 preview; original file requires login','license':'CC0-1.0','license_url':'https://creativecommons.org/publicdomain/zero/1.0/','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'output':str(output.relative_to(ROOT)),'start_s':round(start/sr,4),'duration_s':round(len(clip)/sr,4),'peak_dbfs':round(20*np.log10(max(float(np.max(np.abs(clip))),1e-9)),2),'rms_dbfs':round(20*np.log10(max(float(np.sqrt(np.mean(clip*clip))),1e-9)),2),'sha256':hashlib.sha256(output.read_bytes()).hexdigest(),'edits':'Mono 44.1k PCM16, selected transient, DC removal, 3ms attack / 65ms release fade, -6dBFS peak.'}
    print(key,sid,result['duration_s'],flush=True)
    return result

if __name__ == '__main__':
    SOURCE.mkdir(parents=True,exist_ok=True)
    (SOURCE/'.gdignore').touch()
    OUT.mkdir(parents=True,exist_ok=True)
    rows=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for future in concurrent.futures.as_completed([pool.submit(acquire,row) for row in SOUNDS]):
            rows.append(future.result())
    rows.sort(key=lambda r:r['key'])
    (SOURCE/'manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
    credits=['COMBAT AUDIO SOURCES - 2026-10-16','All sources: CC0 1.0 Universal.','Source pages and downloaded previews are archived here. Runtime files are in assets/audio/combat.','Edits: selected transient, mono conversion, fades, DC and level adjustment.','Public HQ preview MP3 was used; no claim of original uncompressed source quality.','']
    for row in rows:
        credits += [f"{row['key']}: {row['title']} by {row['author']}",row['source_page'],row['license_url'],'']
    (SOURCE/'CREDITS.txt').write_text('\n'.join(credits),encoding='utf-8')
    print('BUILT',len(rows),'licensed clips')
