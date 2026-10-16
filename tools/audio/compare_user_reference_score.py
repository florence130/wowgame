"""Time alignment is harmonic guidance, not proof of lead melody or orchestration."""
from pathlib import Path
import sys,json,csv,hashlib,zipfile,xml.etree.ElementTree as ET
from fractions import Fraction
ROOT=Path(__file__).resolve().parents[2];WORK=ROOT/'.local/music_reference_20261011'
OUT=ROOT/'output/audio/granblue_reference_20261011/melody';SRC=Path('C:/Users/17408/Music/GBFR')
sys.path[:0]=[str(WORK/'rhythm_deps'),str(WORK/'model_deps')]
import numpy as np,librosa,mido,soundfile as sf
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties
font=FontProperties(fname='C:/Windows/Fonts/msyh.ttc')
mf=mido.MidiFile(SRC/'Main Theme.mid')
tempos=[];sigs=[];keys=[];notes=[]
for ti,tr in enumerate(mf.tracks):
    tick=0;active={}
    for msg in tr:
        tick+=msg.time
        if msg.type=='set_tempo':tempos.append((tick,msg.tempo))
        if msg.type=='time_signature':sigs.append((tick,msg.numerator,msg.denominator))
        if msg.type=='key_signature':keys.append((tick,msg.key))
        if msg.type=='note_on' and msg.velocity>0:active.setdefault(msg.note,[]).append((tick,msg.velocity))
        if msg.type=='note_off' or(msg.type=='note_on' and msg.velocity==0):
            if active.get(msg.note):
                st,v=active[msg.note].pop(0);notes.append({'track':ti,'start_tick':st,'end_tick':tick,'midi':msg.note,'velocity':v})
tempos=sorted(set(tempos));assert len(tempos)==1 and tempos[0][0]==0
beat_s=tempos[0][1]/1e6;tick_s=beat_s/mf.ticks_per_beat
for n in notes:n.update(start_s=n['start_tick']*tick_s,end_s=n['end_tick']*tick_s)
with zipfile.ZipFile(SRC/'Main Theme.mscz')as z:xml=ET.fromstring(z.read('Main Theme.mscx')).find('Score')
duration={'whole':4,'half':2,'quarter':1,'eighth':.5,'16th':.25,'32nd':.125}
rows=[];barrows=[]
for staff in xml.findall('Staff'):
    for mi,me in enumerate(staff.findall('Measure')):
        pos=Fraction(0)
        for vi,voice in enumerate(me.findall('voice')):
            for el in voice:
                if el.tag not in ['Chord','Rest']:continue
                typ=el.findtext('durationType')
                dur=Fraction(el.findtext('duration'))*4 if el.find('duration')is not None else Fraction(duration[typ])
                dots=int(el.findtext('dots','0'));dur*=sum(Fraction(1,2**i)for i in range(dots+1))
                pitches=[int(n.findtext('pitch')) for n in el.findall('Note')]
                if pitches:
                    shift=12 if staff.get('id')=='1' and mi<8 else 0
                    sounding=[p+shift for p in pitches]
                    rows.append({'staff':int(staff.get('id')),'measure':mi+1,'beat_in_measure':float(pos),
                        'start_s':(mi*6+float(pos))*beat_s,'duration_s':float(dur)*beat_s,
                        'midi':sounding,'top_midi':max(sounding),'arpeggio':el.find('Arpeggio')is not None})
                pos+=dur
        assert pos==6,(staff.get('id'),mi+1,pos)
        if staff.get('id')=='1':
            this=[r for r in rows if r['staff']==1 and r['measure']==mi+1]
            barrows.append({'measure':mi+1,'score_start_s':mi*6*beat_s,
                'soprano_pitch_classes':[librosa.midi_to_note(r['top_midi']%12+60,unicode=False)[:-1]for r in this],
                'soprano_midi':[r['top_midi']for r in this],
                'beat_onsets':[r['beat_in_measure']for r in this]})
summary={'sources':{p.name:hashlib.sha256(p.read_bytes()).hexdigest()for p in SRC.iterdir()if p.is_file()},
    'scope':'User piano arrangement, potentially inaccurate; original orchestration is not encoded.',
    'score_measure_count':39,'score_meter':'6/4','score_quarter_bpm':60/beat_s,
    'midi_duration_s':max(n['end_s']for n in notes),'midi_notes':len(notes),
    'midi_tempo_events_unique':tempos,'midi_key_events_unique':sorted(set(keys)),
    'key_signature_limit':'Key signature alone does not distinguish relative major/minor or establish tonal center.',
    'score_topline_limit':'Highest note per right-hand chord is the score soprano, not automatically the original lead.',
    'first_eight_measures_octave_mark':'8va, reflected in exported MIDI',
    'measures':barrows,'score_chords':rows}
(OUT/'user_score_summary.json').write_text(json.dumps(summary,indent=2,ensure_ascii=False),encoding='utf-8')
print('Parsed score',summary['midi_duration_s'],flush=True)
# Harmonic DTW guides approximate phrase times. Score and audio octave identity checked separately.
y,sr=sf.read(WORK/'reference.wav',dtype='float32');hop=2048
cqt=np.abs(librosa.cqt(y[:180*sr],sr=sr,hop_length=hop,fmin=librosa.midi_to_hz(36),n_bins=72))
audio=np.zeros((12,cqt.shape[1]))
for p in range(72):audio[(p+36)%12]+=cqt[p]
audio=np.sqrt(audio);audio/=np.linalg.norm(audio,axis=0,keepdims=True)+1e-9
step=hop/sr;times=np.arange(audio.shape[1])*step
scoretimes=np.arange(0,39*6*beat_s,step);score=np.zeros((12,len(scoretimes)))
for n in notes:
    mask=(scoretimes>=n['start_s'])&(scoretimes<n['end_s']);score[n['midi']%12,mask]+=1
score=np.sqrt(score);score/=np.linalg.norm(score,axis=0,keepdims=True)+1e-9
cost=1-score.T@audio
# Broad chronology restriction avoids alignment to unrelated later reprises; not data-derived proof.
band=np.abs(times[None,:]-(scoretimes[:,None]*1.025+.4))<10
cost[~band]=5
# The recording and score both begin with the opening phrase. Repetition made an
# unconstrained subsequence jump to 10 s; restrict the first frame to the opening.
cost[0,times>.6]=np.inf
D,path=librosa.sequence.dtw(C=cost,subseq=True,step_sizes_sigma=np.array([[1,1],[1,2],[2,1]]),weights_add=np.array([0,.12,.12]))
path=path[::-1];aligned=np.full(len(scoretimes),np.nan)
for i in range(len(scoretimes)):
    ix=path[path[:,0]==i,1]
    if len(ix):aligned[i]=np.median(times[ix])
aligned=np.interp(scoretimes,scoretimes[np.isfinite(aligned)],aligned[np.isfinite(aligned)])
def align(t):return float(np.interp(t,scoretimes,aligned))
candidates=json.loads((OUT/'candidate_notes.json').read_text())['segments']
events=[n for s in candidates for n in s['notes']]
comparisons=[]
for r in rows:
    at=align(r['start_s']);p=r['top_midi']
    covered=any(s['start_s']<=at<s['end_s']for s in candidates)
    found=[n for n in events if abs(n['start_s']-at)<.6 and n['midi'] in [p-12,p,p+12]]
    found.sort(key=lambda n:(n['midi']!=p,abs(n['start_s']-at)))
    controls={str(shift):sum(abs(n['start_s']-at)<.6 and (n['midi']-p-shift)%12==0 for n in events)for shift in [1,6]}
    comparisons.append({**r,'audio_time_approx_s':round(at,3),'covered_by_pitch_extract':covered,
        'candidates':found[:3],'transpose_control_matches':controls,
        'limit':'DTW guides timing using harmony; matches are model candidates, absent matches do not establish score errors.'})
alignment={'method':'CQT pitch-class harmonic DTW, 92.9 ms frames; chronology ±10 s, known opening start <=0.6 s',
    'limits':['Harmonic agreement is not proof of melodic identity.','Subsequence/repeats may yield ambiguous local timing.',
              'Highest-score-note comparison can select chord tones.','±0.6 s onset tolerance; octave alternatives kept explicit.',
              'No metric establishes exact note duration or instrument identity.'],
    'measure_times':[{'measure':m['measure'],'score_s':m['score_start_s'],
        'audio_approx_s':round(align(m['score_start_s']),3)}for m in barrows],
    'score_note_comparisons':comparisons}
(OUT/'score_audio_alignment.json').write_text(json.dumps(alignment,indent=2,ensure_ascii=False),encoding='utf-8')
np.savez_compressed(OUT/'score_alignment_features.npz',scoretimes=scoretimes,audio_times=times,
    aligned_audio_times=aligned,score_chroma=score,audio_chroma=audio,cqt=cqt,path=path)
print('Aligned measure times',alignment['measure_times'],flush=True)
fig,axes=plt.subplots(2,1,figsize=(13,7))
axes[0].plot(scoretimes,aligned);axes[0].set_title('钢琴改编谱与录音的近似乐句对应（和声对齐，不是旋律鉴定）',fontproperties=font)
axes[0].set_xlabel('谱面时间 / 秒',fontproperties=font);axes[0].set_ylabel('原录音时间 / 秒',fontproperties=font);axes[0].grid(alpha=.2)
for r in comparisons:
    if r['staff']==1 and r['measure']<=8:
        at=r['audio_time_approx_s'];axes[1].plot([at,align(r['start_s']+r['duration_s'])],[r['top_midi']]*2,color='orange',lw=2)
for n in events:
    if n['start_s']<35 and n['midi']>=77:
        axes[1].plot([n['start_s'],n['end_s']],[n['midi']]*2,color='#2563eb',alpha=.65,lw=2)
axes[1].set_title('开头：橙线＝谱面右手最高音；蓝线＝录音音符候选（含泛音）',fontproperties=font)
axes[1].set_xlabel('原录音时间 / 秒',fontproperties=font);axes[1].set_ylabel('MIDI 音高',fontproperties=font);axes[1].set_xlim(0,35);axes[1].grid(alpha=.2)
fig.tight_layout();fig.savefig(OUT/'score_audio_comparison.png',dpi=150)
# Neutral reconstruction follows the supplied MIDI, not a claimed original melody/timbre.
out=np.zeros(int((32.36+1)*sr));topout=np.zeros_like(out)
for n in notes:
    if n['start_s']>=32.36:continue
    a=int(n['start_s']*sr);b=min(len(out),int(n['end_s']*sr));t=np.arange(b-a)/sr
    env=np.minimum(t/.015,1)*np.exp(-2.5*t)*np.minimum(np.maximum((b-a)/sr-t,0)/.12,1)
    wave=.1*np.sin(2*np.pi*librosa.midi_to_hz(n['midi'])*t)*env;out[a:b]+=wave
for r in rows:
    if r['staff']!=1 or r['measure']>8:continue
    a=int(r['start_s']*sr);b=min(len(out),int((r['start_s']+r['duration_s'])*sr));t=np.arange(b-a)/sr
    env=np.minimum(t/.015,1)*np.exp(-2.5*t)*np.minimum(np.maximum((b-a)/sr-t,0)/.12,1)
    topout[a:b]+=.15*np.sin(2*np.pi*librosa.midi_to_hz(r['top_midi'])*t)*env
for name,data in [('user_score_opening_neutral',out),('user_score_soprano_neutral',topout)]:
    sf.write(OUT/f'{name}.wav',data/max(np.max(np.abs(data)),1e-9)*.3,sr,subtype='PCM_16')
# Inspect low accompaniment independently: energy peaks are still not exact polyphonic notes.
for a,b in [(0.1,1.2),(4.7,5.7),(9.1,10),(13.6,14.7)]:
    peaks=cqt[:,(times>=a)&(times<=b)].mean(1);ix=np.argsort(peaks)[::-1][:12]
    print('CQT',a,b,[(librosa.midi_to_note(int(i)+36,unicode=False),round(float(peaks[i]),4))for i in ix],flush=True)
print('Finished',flush=True)
