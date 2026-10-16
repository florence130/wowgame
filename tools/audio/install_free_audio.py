"""Build licensed audio assets and deterministic day/night arrangements."""
from pathlib import Path
import sys,json,zipfile,shutil,subprocess,hashlib,re,copy
ROOT=Path(__file__).resolve().parents[2];WORK=ROOT/'.local/free_audio_20261011'
OUT=ROOT/'assets/audio/free';CREDITS=ROOT/'assets/third_party/free_audio'
sys.path[:0]=[str(ROOT/'.local/music_reference_20261011/rhythm_deps'),str(ROOT/'.local/music_reference_20261011/model_deps')]
import numpy as np,soundfile as sf,pretty_midi
FF=ROOT/'.local/menu_music_20261011/deps/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
FL=WORK/'fluidsynth/fluidsynth-v2.6.1-win10-x64-cpp11/bin/fluidsynth.exe'
SF=WORK/'GeneralUser-GS.sf2'
OUT.mkdir(parents=True,exist_ok=True);CREDITS.mkdir(parents=True,exist_ok=True)
rows=[]
def convert(src,dst,kind='sfx',loop=False):
    pcm=WORK/(dst.stem+'_pcm.wav')
    subprocess.run([str(FF),'-y','-v','error','-i',str(src),'-ar','44100','-ac','2',str(pcm)],check=True)
    y,sr=sf.read(pcm,dtype='float32',always_2d=True)
    if loop:
        n=min(int(.5*sr),len(y)//10)
        a=np.linspace(0,1,n,dtype='float32')[:,None]
        y=np.concatenate([y[n:-n],y[-n:]*(1-a)+y[:n]*a])
    target={'sfx':-24,'bgm':-25,'amb':-32}[kind]
    gain=min(10**(target/20)/max(float(np.sqrt(np.mean(y*y))),1e-9),10**(-4/20)/max(float(np.abs(y).max()),1e-9))
    y*=gain;sf.write(pcm,y,sr,subtype='PCM_16')
    subprocess.run([str(FF),'-y','-v','error','-i',str(pcm),'-c:a','libvorbis','-q:a','5',str(dst)],check=True)
    return {'duration_s':round(len(y)/sr,3),'rms_dbfs':round(float(20*np.log10(max(np.sqrt(np.mean(y*y)),1e-9))),2),
            'peak_dbfs':round(float(20*np.log10(max(np.abs(y).max(),1e-9))),2),'crossfade_s':.5 if loop else 0}
def add(key,pack,member):
    with zipfile.ZipFile(WORK/pack)as z:
        src=WORK/('source_'+key+Path(member).suffix);src.write_bytes(z.read(member))
    dst=OUT/(key+'.ogg');info=convert(src,dst)
    rows.append({'key':key,'file':str(dst.relative_to(ROOT)),'source_pack':pack,'source_member':member,'license':'CC0',**info})
ui={'click':'click_001','open':'open_001','close':'close_001','error':'error_003','loot':'confirmation_001',
    'levelup':'confirmation_004','quest_accept':'confirmation_002','quest_progress':'confirmation_001',
    'quest_done':'confirmation_004','learn':'confirmation_003','train':'confirmation_002'}
for key,member in ui.items():add(key,'kenney_ui.zip','Audio/'+member+'.ogg')
rpg={'hit':'battle/sword-unsheathe2.wav','hit_crit':'battle/sword-unsheathe5.wav','swing':'battle/swing.wav',
    'block':'battle/sword-unsheathe4.wav','cast':'battle/spell.wav','fire':'battle/magic1.wav',
    'frost':'inventory/bubble2.wav','holy':'battle/spell.wav','heal':'inventory/bubble.wav',
    'shadow':'battle/magic1.wav','arcane':'battle/spell.wav','shot':'battle/swing3.wav',
    'coin':'inventory/coin.wav','equip':'inventory/chainmail1.wav','death':'NPC/shade/shade1.wav',
    'aggro':'NPC/gutteral beast/mnstr1.wav','portal':'battle/magic1.wav','bell':'inventory/metal-ringing.wav'}
# Names must resolve to actual source members; never silently substitute a pack.
with zipfile.ZipFile(WORK/'rpg.zip')as z:
    names=z.namelist()
    if 'RPG Sound Pack/NPC/shade/shade1.wav'not in names:
        shade=[n for n in names if '/shade/'in n and n.endswith('.wav')and not n.startswith('__MACOSX')]
        rpg['death']=shade[0].removeprefix('RPG Sound Pack/')
for key,member in rpg.items():add(key,'rpg.zip','RPG Sound Pack/'+member)
add('jump','kenney_rpg.zip','Audio/cloth1.ogg')
# Different edits of shared magic sources keep concise cues and distinct timbres.
for key,semitones,limit in [('fire',-3,.65),('frost',7,.6),('holy',5,1.1),('heal',3,.8),('shadow',-7,.85),('arcane',2,.8),('shot',5,.22),('portal',-2,1.5)]:
    src=OUT/(key+'.ogg');tmp=WORK/(key+'_effect.ogg')
    rate=2**(semitones/12)
    subprocess.run([str(FF),'-y','-v','error','-i',str(src),'-af',f'asetrate=44100*{rate},aresample=44100,afade=t=out:st={max(0,limit-.08)}:d=0.08','-t',str(limit),'-c:a','libvorbis','-q:a','5',str(tmp)],check=True)
    shutil.copy2(tmp,src)
    for r in rows:
        if r['key']==key:r['edit']={'pitch_semitones':semitones,'max_duration_s':limit}
music={'vale':'plains-01','tidewind':'plains-02','city':'castle-03','sanctum':'cave-01','combat':'battle-01'}
for key,source in music.items():
    dst=OUT/(key+'_day.ogg');info=convert(WORK/(source+'_day.ogg'),dst,'bgm',True)
    rows.append({'key':key+'_day','file':str(dst.relative_to(ROOT)),'source':source,'author':'Beau Buckley','license':'CC-BY-SA-4.0','edit':'level and loop crossfade',**info})
    if key=='combat':continue
    original=pretty_midi.PrettyMIDI(str(WORK/(source+'_midi.mid')))
    # Keep composed note pitches and order; replace all harmonic instruments
    # except obvious percussion programs with piano/harp and reduce density.
    night=pretty_midi.PrettyMIDI(initial_tempo=120);factor=1.3;kept=0;omitted=[]
    for ix,inst in enumerate(original.instruments):
        if inst.is_drum or inst.program in [47,116,117,118,119]:omitted.append(ix);continue
        replacement=pretty_midi.Instrument(program=0 if ix==0 else 46,name='Piano melody'if ix==0 else 'Harp harmony')
        # Sustain melodic source, thin only accompaniment; retain first voice.
        last=-100.
        for n in sorted(inst.notes,key=lambda n:(n.start,n.pitch)):
            if ix>0 and n.start-last<.4 and n.start>last+.03:continue
            vel=min(62,max(30,int(n.velocity*.65)))
            replacement.notes.append(pretty_midi.Note(velocity=vel,pitch=n.pitch,start=n.start*factor,end=n.end*factor))
            last=n.start;kept+=1
        night.instruments.append(replacement)
    mid=CREDITS/(key+'_night.mid');night.write(str(mid))
    shutil.copy2(WORK/(source+'_midi.mid'),CREDITS/(key+'_source.mid'))
    wav=WORK/(key+'_night_render.wav')
    subprocess.run([str(FL),'-ni','-r','44100','-g','.65','-F',str(wav),str(SF),str(mid)],check=True,stdout=subprocess.DEVNULL)
    dst=OUT/(key+'_night.ogg');info=convert(wav,dst,'bgm',True)
    rows.append({'key':key+'_night','file':str(dst.relative_to(ROOT)),'source':source,'author':'Beau Buckley','license':'CC-BY-SA-4.0',
        'arrangement':{'speed_factor':factor,'melody_pitches_preserved':True,'first_voice_note_count':len(night.instruments[0].notes),
            'source_first_voice_note_count':len(original.instruments[0].notes),'programs':[int(i.program)for i in night.instruments],
            'omitted_percussion_tracks':omitted,'kept_notes':kept,'soundfont':'GeneralUser GS 2.0.3'},**info})
# Menu candidate: rearranged sustained theme, not the rejected generated music.
original=pretty_midi.PrettyMIDI(str(WORK/'opening-03_midi.mid'))
menu=pretty_midi.PrettyMIDI();
for ix in [0,6]:
    inst=original.instruments[ix];dest=pretty_midi.Instrument(program=0 if ix==0 else 46)
    for n in inst.notes:dest.notes.append(pretty_midi.Note(velocity=min(58,max(30,int(n.velocity*.6))),pitch=n.pitch,start=n.start*1.25,end=n.end*1.25))
    menu.instruments.append(dest)
menu.write(str(CREDITS/'menu_arrangement.mid'));shutil.copy2(WORK/'opening-03_midi.mid',CREDITS/'menu_source.mid')
wav=WORK/'menu_render.wav';subprocess.run([str(FL),'-ni','-r','44100','-g','.65','-F',str(wav),str(SF),str(CREDITS/'menu_arrangement.mid')],check=True,stdout=subprocess.DEVNULL)
info=convert(wav,OUT/'menu.ogg','bgm',True)
rows.append({'key':'menu','file':'assets/audio/free/menu.ogg','source':'opening-03','author':'Beau Buckley','license':'CC-BY-SA-4.0','edit':'sustained first source voice on piano and harp source on harp; 1.25x time; no choir',**info})
for key,src in [('forest_day','forest.mp3'),('forest_night','crickets.mp3'),('village_day','forest.mp3'),('village_night','crickets.mp3')]:
    info=convert(WORK/src,OUT/(key+'.ogg'),'amb',True)
    rows.append({'key':key,'file':f'assets/audio/free/{key}.ogg','source':src,'license':'CC0',**info})
for r in rows:
    r['sha256']=hashlib.sha256((ROOT/r['file']).read_bytes()).hexdigest()
    r['actual_duration_s']=round(sf.info(ROOT/r['file']).duration,3)
(CREDITS/'manifest.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
for name in ['rpg','kenney','kenney_fantasy','ambient','crickets-ambient-noise-loopable']+list(music.values())+['opening-03']:
    f=WORK/(name+'.html')
    if f.exists():shutil.copy2(f,CREDITS/(name+'_source_page.html'))
shutil.copy2(WORK/'LICENSE.txt',CREDITS/'GeneralUser_GS_LICENSE.txt')
for pack,label in [('kenney_ui.zip','Kenney_UI_LICENSE.txt'),('kenney_rpg.zip','Kenney_RPG_LICENSE.txt')]:
    with zipfile.ZipFile(WORK/pack)as z:(CREDITS/label).write_bytes(z.read('License.txt'))
print(json.dumps({'assets':len(rows),'night_pairs':4,'menu':'candidate arrangement, aesthetic match not auditioned'}),flush=True)
subprocess.run([sys.executable, str(ROOT/'tools/audio/replace_combat_sfx.py')], check=True)
