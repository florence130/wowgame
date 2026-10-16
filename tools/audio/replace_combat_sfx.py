from pathlib import Path
import sys,zipfile,subprocess,json,hashlib,shutil
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'.local/music_reference_20261011/rhythm_deps'))
import numpy as np,soundfile as sf
work=ROOT/'.local/sfx_revision_20261012';out=ROOT/'assets/audio/free';credits=ROOT/'assets/third_party/free_audio'
ff=ROOT/'.local/menu_music_20261011/deps/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
backup=work/'before';backup.mkdir(exist_ok=True)
mapping={'hit':'impactPunch_medium_000','hit_crit':'impactPunch_heavy_000','block':'impactPlate_medium_000','death':'impactSoft_heavy_000'}
if not (out/'thunder.ogg').exists():
    shutil.copy2(backup/'hit_crit.ogg' if (backup/'hit_crit.ogg').exists() else out/'hit_crit.ogg',out/'thunder.ogg')
rows=json.loads((credits/'manifest.json').read_text(encoding='utf-8'));results=[]
if not any(r['key']=='thunder' for r in rows):
    rows.append({'key':'thunder','file':'assets/audio/free/thunder.ogg','source_pack':'rpg.zip','source_member':'RPG Sound Pack/battle/sword-unsheathe5.wav','license':'CC0','edit':'preserved previous thunder proxy; runtime pitch 0.3','sha256':hashlib.sha256((out/'thunder.ogg').read_bytes()).hexdigest()})
with zipfile.ZipFile(work/'impact-sounds.zip') as z:
    (credits/'Kenney_Impact_LICENSE.txt').write_bytes(z.read('License.txt'))
    for key,member in mapping.items(): (work/(key+'_source.ogg')).write_bytes(z.read('Audio/'+member+'.ogg'))
for key in list(mapping)+['shot']:
    dst=out/(key+'.ogg')
    if not (backup/dst.name).exists():shutil.copy2(dst,backup/dst.name)
    src=work/(key+'_source.ogg') if key!='shot' else work/'guns/shots/pistol.wav'
    pcm=work/(key+'_decoded.wav')
    subprocess.run([str(ff),'-y','-v','error','-i',str(src),'-ar','44100','-ac','2',str(pcm)],check=True)
    y,sr=sf.read(pcm,always_2d=True)
    target=-27 if key=='shot' else -24
    y*=min(10**(target/20)/max(np.sqrt(np.mean(y*y)),1e-9),10**(-6/20)/max(np.abs(y).max(),1e-9))
    sf.write(pcm,y,sr,subtype='PCM_24')
    subprocess.run([str(ff),'-y','-v','error','-i',str(pcm),'-c:a','libvorbis','-q:a','5',str(dst)],check=True)
    decoded,rate=sf.read(dst,always_2d=True);assert np.isfinite(decoded).all() and np.abs(decoded).max()<1
    row={'key':key,'file':str(dst.relative_to(ROOT)),'author':'Kenney' if key!='shot' else 'Michel Baradari','license':'CC0' if key!='shot' else 'CC-BY-3.0','source_member':'Audio/'+mapping[key]+'.ogg' if key!='shot' else 'shots/pistol.wav','source':'https://kenney.nl/assets/impact-sounds' if key!='shot' else 'https://opengameart.org/content/chaingun-pistol-rifle-shotgun-shots','edit':'constant level adjustment; no pitch editing','sha256':hashlib.sha256(dst.read_bytes()).hexdigest(),'actual_duration_s':round(len(decoded)/rate,3),'decoded_peak_dbfs':round(float(20*np.log10(np.abs(decoded).max())),2)}
    rows=[r for r in rows if r['key']!=key];rows.append(row);results.append(row)
for name in ['impact-sounds.html','guns.html']:shutil.copy2(work/name,credits/('revision_'+name))
shutil.copy2(work/'guns/shots/info.txt',credits/'Michel_Baradari_guns_LICENSE.txt')
(credits/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
(credits/'combat_revision_20261012.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
notice=credits/'CREDITS.txt'
notice.write_text(notice.read_text(encoding='utf-8').split('Combat SFX revision 2026-10-12:')[0].rstrip()+'\n',encoding='utf-8')
with (credits/'CREDITS.txt').open('a',encoding='utf-8') as f:f.write('\nCombat SFX revision 2026-10-12: hit/critical hit use Kenney punch impacts; block uses plate impact; death uses soft heavy impact (neutral body fall, no voice). Kenney Impact Sounds: CC0. https://kenney.nl/assets/impact-sounds\nShot: pistol.wav by Michel Baradari (apollo-music.de), submitted by qubodup, CC BY 3.0 https://creativecommons.org/licenses/by/3.0/ ; https://opengameart.org/content/chaingun-pistol-rifle-shotgun-shots . Modified volume and OGG encoding. Preserve author and license on distribution.\n')
preview=ROOT/'output/audio/combat_sfx_revision_20261012';preview.mkdir(parents=True,exist_ok=True)
parts=[]
for key in ['hit','hit_crit','block','death','shot']:
    y,sr=sf.read(out/(key+'.ogg'),always_2d=True);parts.extend([y,np.zeros((int(sr*.8),2))])
sf.write(preview/'combat_preview.wav',np.concatenate(parts),sr,subtype='PCM_24')
print(json.dumps(results))
