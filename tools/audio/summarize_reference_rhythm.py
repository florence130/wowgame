"""Cross-check pulse evidence and render a readable local analysis artifact."""
from pathlib import Path
import sys
import json
import hashlib
ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT/'.local/music_reference_20261011'
OUT = ROOT/'output/audio/granblue_reference_20261011/rhythm'
sys.path.insert(0,str(WORK/'rhythm_deps'))
import numpy as np
import scipy.signal as sig
from scipy.ndimage import uniform_filter1d
import soundfile as sf
import librosa
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties

r = json.loads((OUT/'rhythm_analysis.json').read_text())
f = np.load(OUT/'rhythm_features.npz')
y,sr = sf.read(WORK/'reference.wav')
fps=sr/512
times=f['times']
# Correctly use waveform RMS, not the RMS of the Hann-windowed STFT.
rms=librosa.feature.rms(y=y,frame_length=2048,hop_length=512)[0]
for row in r['segments']:
    m=(times>=row['start_s'])&(times<row['end_s'])
    row['rms_dbfs']=round(float(20*np.log10(max(np.sqrt(np.mean(rms[m]**2)),1e-10))),2)
r['limitations'][0]='Half/double and 3:2 subdivision ambiguities: pulse rate is not confirmed musical tempo.'
r['source_original_mp3_sha256']=hashlib.sha256(Path('D:/CloudMusic/GRANBLUE FANTASY - Main Theme (Full Version).mp3').read_bytes()).hexdigest()

# Another signal input + estimator: filtered waveform amplitude changes / Welch PSD.
# This is a cross-check, not an independent human beat annotation.
sos=sig.butter(4,[80,1000],btype='bandpass',fs=sr,output='sos')
band=sig.sosfiltfilt(sos,y)
amp=np.sqrt(np.maximum(uniform_filter1d(band*band,size=int(sr*.025)),0))[::512]
attacks=np.maximum(np.diff(amp,prepend=amp[0]),0)

def modulation_candidates(z):
    if len(z)<80 or np.std(z)<1e-10:
        return []
    freq,power=sig.welch(z-z.mean(),fs=fps,nperseg=len(z),nfft=8192)
    peaks,_=sig.find_peaks(power)
    peaks=[p for p in peaks if .75<=freq[p]<=200/60]
    peaks=sorted(peaks,key=lambda p:power[p],reverse=True)[:4]
    total=float(np.sum(power[(freq>=.75)&(freq<=200/60)]))
    return [{'bpm':round(float(freq[p]*60),2),
             'peak_power_fraction':round(float(power[p]/max(total,1e-20)),4)} for p in peaks]

cross=[]
tt=np.arange(len(attacks))/fps
for a,b in [(0,35),(35,51),(51,67),(67,86),(86,108),(108,134),(134,141),(141,161),(181,211),(241,271)]:
    cross.append({'start_s':a,'end_s':b,
                  'waveform_modulation_candidates':modulation_candidates(attacks[(tt>=a)&(tt<b)])})
r['waveform_modulation_crosscheck']={'method':'80-1000 Hz waveform band-pass, 25 ms amplitude envelope, positive differences, Welch spectrum', 'segments':cross}
# Check a known 90 pulses/min signal and an amplitude-scaled version.
t=np.arange(int(30*fps))/fps
test=np.maximum(np.cos(2*np.pi*1.5*t),0)**12
c1=modulation_candidates(test);c2=modulation_candidates(test*8)
r['estimator_sanity_check']={'known_bpm':90,'estimate':c1[0]['bpm'],
    'estimate_after_8x_amplitude':c2[0]['bpm'],
    'pass':abs(c1[0]['bpm']-90)<1 and abs(c1[0]['bpm']-c2[0]['bpm'])<.01}
(OUT/'rhythm_analysis.json').write_text(json.dumps(r,indent=2),encoding='utf-8')

font=FontProperties(fname='C:/Windows/Fonts/msyh.ttc')
fig,ax=plt.subplots(2,1,figsize=(12,7),sharex=True)
sec=np.arange(0,len(y)/sr,.5)
level=np.array([20*np.log10(max(np.sqrt(np.mean(y[int(s*sr):min(int((s+.5)*sr),len(y))]**2)),1e-9)) for s in sec])
ax[0].plot(sec,level,color='#2563eb',lw=1)
ax[0].set_ylim(-65,-20)
ax[0].set_ylabel('音频电平（RMS dBFS）',fontproperties=font)
ax[0].set_title('碧蓝幻想 Relink 主题曲：前 2 分 40 秒的强弱与速度候选',fontproperties=font,fontsize=15)
for w in r['rolling_32s_windows']:
    for rank,c in enumerate(w['candidates'][:3]):
        if c['correlation']>.1:
            ax[1].scatter(w['center_s'],c['bpm'],s=15+60*c['correlation'],
                          color=['#15803d','#64748b','#cbd5e1'][rank])
ax[1].set_ylim(40,205)
ax[1].set_ylabel('脉冲候选（次/分钟）',fontproperties=font)
ax[1].set_xlabel('原曲时间（分:秒）',fontproperties=font)
ax[1].set_xticks(np.arange(0,161,20),[f'{s//60}:{s%60:02d}'for s in range(0,161,20)])
for a in ax:
    a.set_xlim(0,160)
    a.grid(alpha=.2)
    for s in [108,134,141]:
        a.axvline(s,color='#be123c',ls='--',lw=.8,alpha=.5)
ax[0].annotate('1:48 配器增强\n（用户听辨）',xy=(108,-26),xytext=(75,-43),
    fontproperties=font,fontsize=9,arrowprops={'arrowstyle':'->','color':'#be123c'})
fig.text(.08,.02,'绿色：最强相关峰；灰色：其它候选。强峰会在拍与细分拍之间切换，不代表已确定速度与拍号。',fontproperties=font,fontsize=9)
fig.tight_layout(rect=(0,.04,1,1))
fig.savefig(OUT/'rhythm_summary.png',dpi=160)
plt.close(fig)

# A beat-check excerpt with algorithmic clicks. Original dynamics are preserved.
a,b=108,134
env=f['percussive'][(times>=a)&(times<b)]
tempo,beat_frames=librosa.beat.beat_track(onset_envelope=env,sr=sr,hop_length=512,start_bpm=90,trim=True)
beat_t=librosa.frames_to_time(beat_frames,sr=sr,hop_length=512)
audio=y[int(a*sr):int(b*sr)].copy()
click=librosa.clicks(times=beat_t,sr=sr,length=len(audio),click_freq=1500,click_duration=.025)
mix=audio+.018*click
assert np.abs(mix).max()<1
sf.write(OUT/'pulse_check_108_134.wav',mix,sr,subtype='PCM_16')
(OUT/'pulse_check.json').write_text(json.dumps({'original_start_s':a,'original_end_s':b,
    'estimated_tempo_bpm':float(np.asarray(tempo).ravel()[0]),'beat_times_in_excerpt_s':beat_t.tolist(),
    'warning':'Algorithm-generated check clicks; not human-confirmed beats.'},indent=2))
print(json.dumps({'crosscheck':cross,'sanity_check':r['estimator_sanity_check']},indent=2))
