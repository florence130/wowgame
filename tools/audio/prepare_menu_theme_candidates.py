"""Preserve complete generated music; prepare playback and basic integrity checks."""
from pathlib import Path
import sys,json,subprocess,hashlib
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/audio/menu_theme_revision_20261011'
WORK=ROOT/'.local/menu_theme_revision_20261011/retry1'
sys.path[:0]=[str(ROOT/'.local/music_reference_20261011/rhythm_deps')]
import numpy as np
import soundfile as sf
ffmpeg=ROOT/'.local/menu_music_20261011/deps/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
rows=[]
for label in ['A','B']:
    source=WORK/f'candidate_{label}.source'
    wav=WORK/f'candidate_{label}.wav'
    preview=OUT/f'Echoes_of_a_Distant_Story_{label}.mp3'
    subprocess.run([str(ffmpeg),'-y','-loglevel','error','-i',str(source),'-ar','44100','-ac','2',str(wav)],check=True)
    subprocess.run([str(ffmpeg),'-y','-loglevel','error','-i',str(source),'-codec:a','libmp3lame','-q:a','2',str(preview)],check=True)
    y,sr=sf.read(wav,dtype='float32',always_2d=True)
    assert np.all(np.isfinite(y)) and len(y)>30*sr
    blocks=np.array([np.sqrt(np.mean(y[i:i+sr]**2)) for i in range(0,len(y),sr)])
    active=np.flatnonzero(blocks>10**(-55/20))
    row={'candidate':label,'decoded_duration_s':round(len(y)/sr,3),'sample_rate':sr,'channels':y.shape[1],
         'rms_dbfs':round(float(20*np.log10(max(np.sqrt(np.mean(y**2)),1e-9))),3),
         'peak_dbfs':round(float(20*np.log10(max(np.max(np.abs(y)),1e-9))),3),
         'samples_at_or_above_full_scale':int(np.sum(np.abs(y)>=1)),
         'first_active_second':int(active[0]) if len(active)else None,
         'last_active_second':int(active[-1])if len(active)else None,
         'mp3_sha256':hashlib.sha256(preview.read_bytes()).hexdigest(),
         'file':str(preview),'one_second_rms_dbfs':[round(float(20*np.log10(max(v,1e-9))),2)for v in blocks]}
    rows.append(row)
    print(json.dumps({k:v for k,v in row.items()if k!='one_second_rms_dbfs'}),flush=True)
provenance=json.loads((OUT/'generation_provenance.json').read_text())
status={'stage':'completed_candidates_saved','attempt':'retry1','task_ids':[x['task_id']for x in provenance['candidates']],
        'request_sha256':provenance['request_sha256'],'candidates':rows,
        'music_auditioned_by_assistant':False,'game_binding_changed':False,
        'limits':['Audio integrity and metadata do not verify style, melody, instruments or absence of maracas.',
                  'Complete generated arrangement preserved; no loop, trim, normalization or composition edits.']}
(OUT/'generation_status.json').write_text(json.dumps(status,indent=2),encoding='utf-8')
(OUT/'candidate_audio_checks.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
