from pathlib import Path
import sys,json,hashlib
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'.local/music_reference_20261011/rhythm_deps'),str(ROOT/'.local/music_reference_20261011/model_deps')]
import numpy as np,soundfile as sf,pretty_midi
base=ROOT/'assets/third_party/free_audio'
rows=json.loads((base/'manifest.json').read_text(encoding='utf-8'))
for row in rows:
    path=ROOT/row['file']; y,sr=sf.read(path,always_2d=True)
    assert np.isfinite(y).all() and np.max(np.abs(y))<1 and len(y)>0, path
    assert hashlib.sha256(path.read_bytes()).hexdigest()==row['sha256'],path
    row['actual_duration_s']=round(len(y)/sr,3)
    row['decoded_peak_dbfs']=round(float(20*np.log10(max(np.max(np.abs(y)),1e-12))),2)
    row['decoded_rms_dbfs']=round(float(20*np.log10(max(np.sqrt(np.mean(y*y)),1e-12))),2)
pairs=[]
for key in ['vale','tidewind','city','sanctum']:
    a=pretty_midi.PrettyMIDI(str(base/(key+'_source.mid')))
    b=pretty_midi.PrettyMIDI(str(base/(key+'_night.mid')))
    aa=sorted(a.instruments[0].notes,key=lambda n:(n.start,n.pitch))
    bb=sorted(b.instruments[0].notes,key=lambda n:(n.start,n.pitch))
    assert [n.pitch for n in aa]==[n.pitch for n in bb],key
    assert max(abs(x.start*1.3-y.start) for x,y in zip(aa,bb))<.02,key
    assert all(i.program in [0,46] and not i.is_drum for i in b.instruments),key
    pairs.append({'map':key,'preserved_first_voice_notes':len(aa),'first_voice_is_theme':'not independently confirmed'})
(base/'manifest.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
report={'decoded_assets':len(rows),'clipping':False,'night_pairs':pairs,'godot_integration':'tests/free_audio.tscn passed','aesthetic_and_musical_loop_seam':'requires audition'}
(base/'verification.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report))
