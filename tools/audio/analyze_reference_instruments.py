"""Offline AudioSet tags: model scores are clues, not verified instruments."""
from pathlib import Path
import sys, json, csv, hashlib
ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT/'.local/music_reference_20261011'
OUT = ROOT/'output/audio/granblue_reference_20261011/melody'
sys.path[:0] = [str(WORK/'rhythm_deps'),str(WORK/'model_deps')]
import numpy as np
import soundfile as sf
import librosa
import onnxruntime as ort

OUT.mkdir(parents=True,exist_ok=True)
opts = ort.SessionOptions()
opts.intra_op_num_threads = 4
opts.inter_op_num_threads = 1
session = ort.InferenceSession(str(WORK/'models/yamnet.onnx'),sess_options=opts,providers=['CPUExecutionProvider'])
with (WORK/'models/yamnet_class_map.csv').open(encoding='utf-8',newline='') as fp:
    labels = [r['display_name'] for r in csv.DictReader(fp)]
y,sr = sf.read(WORK/'reference.wav',dtype='float32')
y16 = librosa.resample(y,orig_sr=sr,target_sr=16000)
segments=[(0,35),(35,51),(51,67),(67,86),(86,108),(108,134),(134,141),(141,161),
          (161,181),(181,211),(211,241),(241,271),(271,301),(301,331)]
rows=[]
all_scores=[]
selected=['Piano','Electric piano','Harp','Violin, fiddle','String section',
          'Bowed string instrument','Cello','Orchestra','Keyboard (musical)',
          'Synthesizer','Harpsichord','Percussion','Drum','Drum kit','Timpani',
          'Bass drum','Snare drum','Cymbal','Maraca','Tambourine',
          'Glockenspiel','Vibraphone','Mallet percussion','Bell','Chime','Jingle bell',
          'Tubular bells','Wind chime','Flute','French horn']
for start,end in segments:
    clip=y16[int(start*16000):int(end*16000)]
    rms=float(np.sqrt(np.mean(clip**2)))
    gain=min(10**(-22/20)/max(rms,1e-8),.85/max(float(np.abs(clip).max()),1e-8))
    row={'start_s':start,'end_s':end,'gain_normalized_db':float(20*np.log10(gain)),
         'user_timing_approximate':True,'predictions':{}}
    for mode,scale in [('raw',1.),('level_normalized',gain)]:
        scores=session.run(['output_0'],{'waveform':(clip*scale).astype(np.float32)})[0]
        mean=scores.mean(axis=0)
        assert len(mean)==len(labels)
        assert np.all(np.isfinite(mean))
        top=np.argsort(mean)[::-1][:15]
        # Rank the disclosed instrument candidates; exclude broad Music and
        # Musical instrument superclasses from a purported instrument ranking.
        instruments=[labels.index(label) for label in selected]
        top_inst=sorted(instruments,key=lambda i:mean[i],reverse=True)[:10]
        row['predictions'][mode]={'window_count':len(scores),
             'top_all':[{'label':labels[i],'score':round(float(mean[i]),5)}for i in top],
             'top_instruments':[{'label':labels[i],'score':round(float(mean[i]),5)}for i in top_inst],
             'selected_scores':{label:round(float(mean[labels.index(label)]),5)for label in selected}}
        all_scores.append(mean)
    rows.append(row)
    print(json.dumps({'start':start,'end':end,'raw':row['predictions']['raw']['top_instruments'][:5],
                     'normalized':row['predictions']['level_normalized']['top_instruments'][:5]}),flush=True)
report={'model':'Google YAMNet, community ONNX conversion',
        'source':'https://huggingface.co/zeropointnine/yamnet-onnx',
        'upstream':'https://github.com/tensorflow/models/tree/master/research/audioset/yamnet',
        'model_sha256':hashlib.sha256((WORK/'models/yamnet.onnx').read_bytes()).hexdigest(),
        'labelmap_sha256':hashlib.sha256((WORK/'models/yamnet_class_map.csv').read_bytes()).hexdigest(),
        'input_wav_sha256':hashlib.sha256((WORK/'reference.wav').read_bytes()).hexdigest(),
        'labels':labels,'sample_rate':16000,'onnxruntime_version':ort.__version__,
        'limits':['AudioSet model scores are uncalibrated tags, not probabilities that instruments exist.',
                  'Celesta and specific Japanese bells are absent from the label set.',
                  'Mixed orchestral music may confuse instruments; rank is not ground truth.',
                  'Only approximate user segment times; no audio audition by assistant.',
                  'Level-normalised comparisons expose sensitivity to mastering level.'],
        'segments':rows}
(OUT/'instrument_tags.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
with (OUT/'instrument_scores.csv').open('w',encoding='utf-8',newline='') as fp:
    w=csv.writer(fp);w.writerow(['start_s','end_s','processing']+labels)
    for i,(a,b) in enumerate(segments):
        for j,mode in enumerate(['raw','level_normalized']):
            w.writerow([a,b,mode]+all_scores[2*i+j].tolist())
print('YAMNet tagging complete',flush=True)
