"""Candidate polyphonic notes and pitch contours; not verified lead transcription."""
from pathlib import Path
import sys,json,csv,hashlib
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'.local/music_reference_20261011'
OUT=ROOT/'output/audio/granblue_reference_20261011/melody'
sys.path[:0]=[str(WORK/'rhythm_deps'),str(WORK/'model_deps')]
import numpy as np
import librosa
import soundfile as sf
import onnxruntime as ort
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
from basic_pitch.inference import predict, Model

opts=ort.SessionOptions();opts.intra_op_num_threads=4;opts.inter_op_num_threads=1
model=Model(WORK/'models/basic_pitch.onnx')
model.model=ort.InferenceSession(str(WORK/'models/basic_pitch.onnx'),sess_options=opts,providers=['CPUExecutionProvider'])
y,sr=sf.read(WORK/'reference.wav',dtype='float32')
segments=[(0,35),(35,67),(67,86),(86,108),(108,134),(141,161),(181,211),(241,271)]
rows=[]
all_events=[]
font=FontProperties(fname='C:/Windows/Fonts/msyh.ttc')
fig,axes=plt.subplots(4,1,figsize=(13,10))
for index,(a,b) in enumerate(segments):
    data=y[int(a*sr):int(b*sr)]
    gain=min(10**(-22/20)/max(float(np.sqrt(np.mean(data**2))),1e-8),
             .8/max(float(np.abs(data).max()),1e-8))
    pcm=WORK/f'notes_{a}_{b}_normalized.wav'
    sf.write(pcm,data*gain,sr,subtype='PCM_16')
    output,midi,events=predict(pcm,model,onset_threshold=.5,frame_threshold=.3,
        minimum_note_length=140,minimum_frequency=librosa.note_to_hz('C3'),
        maximum_frequency=librosa.note_to_hz('C7'),melodia_trick=True)
    np.savez_compressed(OUT/f'notes_activation_{a}_{b}.npz',**output)
    midi.write(str(OUT/f'candidate_notes_{a}_{b}.mid'))
    notes=[{'start_s':round(float(s+a),3),'end_s':round(float(e+a),3),
            'midi':int(p),'name':librosa.midi_to_note(p,unicode=False),
            'model_strength':round(float(v),4)}for s,e,p,v,_ in events]
    all_events.extend(notes)
    # Event list sorted for review: overlapping notes are not collapsed into a melody.
    notes.sort(key=lambda n:(n['start_s'],n['midi']))
    stat={'start_s':a,'end_s':b,'gain_db':round(float(20*np.log10(gain)),2),
          'note_count':len(notes),'notes':notes,
          'pitch_extent_midi':[min(n['midi'] for n in notes),max(n['midi'] for n in notes)] if notes else None}
    rows.append(stat)
    if a in [0,35,67,141]:
        ax=axes[[0,35,67,141].index(a)]
        for n in notes:
            ax.plot([n['start_s'],n['end_s']],[n['midi']]*2,
                    color='#2563eb',alpha=max(.25,n['model_strength']),lw=2)
        ax.set_xlim(a,b);ax.set_ylim(47,90)
        ax.set_title(f'原曲 {a//60}:{a%60:02d}–{b//60}:{b%60:02d}：全部音符候选（非确定主旋律）',fontproperties=font,fontsize=11)
        ax.set_ylabel('MIDI 音高',fontproperties=font)
        ax.grid(alpha=.2)
    if a in [0,35,141]:
        # Neutral sine reconstruction, intentionally not labelled original timbre.
        rebuilt=midi.synthesize(fs=sr)
        if len(rebuilt):
            rebuilt=rebuilt/max(float(np.abs(rebuilt).max()),1e-8)*.22
            sf.write(OUT/f'candidate_notes_{a}_{b}.wav',rebuilt,sr,subtype='PCM_16')
    print(json.dumps({k:v for k,v in stat.items() if k!='notes'}),flush=True)

# Monophonic pYIN is a secondary pitch view for sparse passages only.
pyin_rows=[]
for a,b in [(0,35),(35,51),(67,86),(141,161)]:
    yy=y[int(a*sr):int(b*sr)]
    f0,voiced,prob=librosa.pyin(yy,fmin=librosa.note_to_hz('C3'),fmax=librosa.note_to_hz('C7'),
        sr=sr,frame_length=2048,hop_length=512)
    t=librosa.times_like(f0,sr=sr,hop_length=512)+a
    finite=np.isfinite(f0)
    pp=librosa.hz_to_midi(f0[finite])
    np.savez_compressed(OUT/f'pyin_{a}_{b}.npz',times=t,f0=f0,voiced=voiced,voiced_probability=prob)
    pyin_rows.append({'start_s':a,'end_s':b,'voiced_fraction':round(float(finite.mean()),3),
        'median_midi':round(float(np.median(pp)),2)if len(pp)else None,
        'median_voiced_probability':round(float(np.median(prob[finite])),3)if np.any(finite)else None})
    print('PYIN',pyin_rows[-1],flush=True)

fig.tight_layout()
fig.savefig(OUT/'candidate_note_contours.png',dpi=150);plt.close(fig)
report={'model':'Spotify Basic Pitch ICASSP 2022 ONNX','source':'https://github.com/spotify/basic-pitch',
        'model_sha256':hashlib.sha256((WORK/'models/basic_pitch.onnx').read_bytes()).hexdigest(),
        'input_wav_sha256':hashlib.sha256((WORK/'reference.wav').read_bytes()).hexdigest(),
        'settings':{'onset_threshold':.5,'frame_threshold':.3,'minimum_note_length_ms':140,
                    'frequency_range':'C3-C7','melodia_trick':True},
        'limitations':['Polyphonic notes include accompaniment, bass and harmonic mistakes.',
            'Scores are model activations, not calibrated confidence.',
            'No lead voice or instrument labels are inferred from the MIDI.',
            'pYIN assumes one voice, which these excerpts may violate.',
            'Reconstruction uses neutral sine tones and may expose transcription errors.',
            'No actual listening by assistant; theme identity remains to be checked.'],
        'segments':rows,'pyin_sparse_segments':pyin_rows}
(OUT/'candidate_notes.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
with (OUT/'candidate_notes.csv').open('w',encoding='utf-8',newline='')as fp:
    writer=csv.DictWriter(fp,fieldnames=['start_s','end_s','midi','name','model_strength'])
    writer.writeheader();writer.writerows(sorted(all_events,key=lambda n:n['start_s']))
print('Pitch extraction complete',flush=True)
