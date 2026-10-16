"""Offline rhythm evidence: signal estimates, not instrument identification.

Dependencies: librosa 0.11, scipy, numpy, soundfile, matplotlib.
Run with --deps pointing to a task-local package folder when needed.
"""
from pathlib import Path
import argparse
import hashlib
import json
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--deps', type=Path)
parser.add_argument('--input', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
if args.deps:
    sys.path.insert(0, str(args.deps.resolve()))
import numpy as np
import scipy
from scipy import signal
import soundfile as sf
import librosa
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

args.output.mkdir(parents=True, exist_ok=True)
y, sr = sf.read(args.input, dtype='float32', always_2d=True)
y = y.mean(axis=1)
hop = 512
print(f'Loaded {len(y)/sr:.2f}s at {sr}Hz', flush=True)
D = librosa.stft(y, n_fft=2048, hop_length=hop)
H, P = librosa.decompose.hpss(D)
print('Harmonic/percussive separation complete', flush=True)
onsets = {}
for name, spec in [('mix', D), ('percussive', P)]:
    db = librosa.amplitude_to_db(np.abs(spec), ref=np.max)
    onsets[name] = librosa.onset.onset_strength(S=db, sr=sr, hop_length=hop)
    if name == 'mix':
        freqs = librosa.fft_frequencies(sr=sr, n_fft=2048)
        onsets['low_band'] = librosa.onset.onset_strength(
            S=db[(freqs >= 30) & (freqs <= 500)], sr=sr, hop_length=hop)
times = librosa.frames_to_time(np.arange(D.shape[1]), sr=sr, hop_length=hop)
rms = librosa.feature.rms(y=y, frame_length=2048, hop_length=hop)[0]
centroid = librosa.feature.spectral_centroid(S=np.abs(D), sr=sr)[0]
percussion_ratio = np.sum(np.abs(P)**2, axis=0) / np.maximum(np.sum(np.abs(D)**2, axis=0), 1e-12)

def candidates(env, start, end):
    z = env[(times >= start) & (times < end)].astype(float)
    if len(z) < 100 or float(np.std(z)) < 1e-8:
        return []
    z -= z.mean()
    ac = signal.correlate(z, z, mode='full', method='fft')[len(z)-1:]
    # Normalise at each lag, so long-lag candidates aren't penalised only by length.
    energy = np.cumsum(np.r_[0., z*z])
    lag = np.arange(len(z))
    denom = np.sqrt((energy[len(z)]-energy[lag])*energy[len(z)-lag])
    ac = ac / np.maximum(denom, 1e-12)
    minlag = int(np.ceil(60*sr/(hop*200)))
    maxlag = min(len(z)-2, int(np.floor(60*sr/(hop*45))))
    peaks, _ = signal.find_peaks(ac[minlag:maxlag+1], prominence=0.015)
    peaks += minlag
    selected = sorted(peaks, key=lambda p: ac[p], reverse=True)[:5]
    result = []
    for p in selected:
        a, b, c = ac[p-1:p+2]
        offset = float(np.clip(0.5*(a-c)/(a-2*b+c), -0.5, 0.5)) if abs(a-2*b+c) > 1e-9 else 0.
        period = (p+offset)*hop/sr
        result.append({'bpm': round(60/period, 2), 'period_s': round(period, 4),
                       'correlation': round(float(ac[p]), 4)})
    return result

# Times from user descriptions of the two excerpts; not algorithmic boundaries.
segments = [(0,35), (35,51), (51,67), (67,86), (86,108),
            (108,134), (134,141), (141,161), (161,181),
            (181,211), (211,241), (241,271), (271,301), (301,331)]
rows = []
for start, end in segments:
    mask = (times >= start) & (times < end)
    row = {'start_s': start, 'end_s': end,
           'rms_dbfs': round(float(20*np.log10(max(np.sqrt(np.mean(rms[mask]**2)), 1e-10))), 2),
           'percussive_ratio': round(float(np.mean(percussion_ratio[mask])), 3),
           'spectral_centroid_hz': round(float(np.mean(centroid[mask])), 1),
           'pulse_candidates': {name:candidates(env,start,end) for name,env in onsets.items()}}
    rows.append(row)
    print(json.dumps(row), flush=True)

print('Beat tracker corroboration', flush=True)
beat_rows = []
for start, end in [(35,108),(86,134),(108,134),(141,211),(181,331),(0,len(y)/sr)]:
    for name in ['mix', 'percussive']:
        z = onsets[name][(times >= start) & (times < end)]
        for prior in [60,90,120,160]:
            tempo, beats = librosa.beat.beat_track(onset_envelope=z, sr=sr,
                hop_length=hop, start_bpm=prior, trim=True)
            bt = librosa.frames_to_time(beats, sr=sr, hop_length=hop) + start
            interval = np.diff(bt)
            beat_rows.append({'start_s':start, 'end_s':round(end,2), 'method':name,
                'start_bpm_prior':prior, 'tempo_bpm':round(float(np.asarray(tempo).ravel()[0]),2),
                'beat_count':len(bt), 'median_beat_interval_s':round(float(np.median(interval)),4) if len(interval) else None})
print(json.dumps(beat_rows), flush=True)

windows = []
for center in np.arange(16, len(y)/sr-16, 4):
    windows.append({'center_s':float(center), 'start_s':float(center-16), 'end_s':float(center+16),
                    'candidates':candidates(onsets['percussive'],center-16,center+16)})
report = {'source_decoded_wav_sha256':hashlib.sha256(args.input.read_bytes()).hexdigest(),
          'duration_s':len(y)/sr, 'sr':sr, 'hop_length':hop,
          'versions':{m.__name__:m.__version__ for m in [librosa,scipy,np,matplotlib,sf]},
          'method':'spectral onset autocorrelation, mixed/HPSS-percussive/low-band; independent normalisation by lag; librosa dynamic-programming beat tracker with four priors',
          'limitations':['BPM estimates have half/double and 3:2 subdivision ambiguity.',
                         'Short/quiet/sustained windows can be unreliable.',
                         'HPSS separates texture, not instrument identities.',
                         'Input user timestamps are approximate.',
                         'No audio audition by assistant; estimates need click-track checking.'],
          'segments':rows, 'beat_tracker':beat_rows, 'rolling_32s_windows':windows}
(args.output/'rhythm_analysis.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
np.savez_compressed(args.output/'rhythm_features.npz', times=times, rms=rms,
                    percussion_ratio=percussion_ratio, centroid=centroid, **onsets)

# A standard standalone figure, retaining estimated and user-supplied times separately.
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10})
fig, ax = plt.subplots(3,1,figsize=(14,10),sharex=True)
ax[0].plot(times,20*np.log10(np.maximum(rms,1e-8)),color='#2563eb',linewidth=.7)
ax[0].set_ylabel('Level (dBFS)'); ax[0].set_ylim(-65,-15)
ax[0].set_title('Reference audio: loudness, transient texture, and pulse candidates')
smoothed = np.convolve(percussion_ratio,np.ones(43)/43,mode='same')
ax[1].plot(times,smoothed,color='#d97706',linewidth=.8)
ax[1].set_ylabel('HPSS percussive\nenergy fraction'); ax[1].set_ylim(0,1)
for w in windows:
    for rank,c in enumerate(w['candidates'][:3]):
        if c['correlation'] > 0.05:
            ax[2].scatter(w['center_s'],c['bpm'],s=12+100*max(0,c['correlation']),
                c=['#15803d','#64748b','#cbd5e1'][rank],alpha=.8)
ax[2].set_ylabel('Pulse candidate (BPM)'); ax[2].set_ylim(40,205)
ax[2].set_xlabel('Original recording time (seconds)')
for a in ax:
    a.grid(alpha=.2)
    for t in [35,51,67,86,108,134,141]:
        a.axvline(t,color='#be123c',linewidth=.7,alpha=.4,linestyle='--')
fig.text(.08,.025,'Dashed lines: approximate user-described changes. Green: highest autocorrelation peak; grey: alternatives. Pulse rate is not confirmed musical tempo.',fontsize=9)
fig.tight_layout(rect=(0,.05,1,1))
fig.savefig(args.output/'rhythm_overview.png',dpi=150)
plt.close(fig)
print('Analysis artifacts saved', flush=True)
