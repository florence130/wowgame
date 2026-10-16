"""Secondary stem tags and previews; separation labels are not ground truth."""
from pathlib import Path
import sys,json,csv
ROOT=Path(__file__).resolve().parents[2];WORK=ROOT/'.local/music_reference_20261011'
OUT=ROOT/'output/audio/granblue_reference_20261011/melody';SEP=OUT/'separated'
sys.path[:0]=[str(WORK/'rhythm_deps'),str(WORK/'model_deps')]
import numpy as np,librosa,soundfile as sf,onnxruntime as ort
opts=ort.SessionOptions();opts.intra_op_num_threads=4;opts.inter_op_num_threads=1
session=ort.InferenceSession(str(WORK/'models/yamnet.onnx'),sess_options=opts,providers=['CPUExecutionProvider'])
labels=[r['display_name']for r in csv.DictReader((WORK/'models/yamnet_class_map.csv').open(encoding='utf-8'))]
selected=['Piano','Harp','Violin, fiddle','String section','Bowed string instrument','Cello','Orchestra',
    'Keyboard (musical)','Synthesizer','Harpsichord','Percussion','Drum','Timpani','Glockenspiel',
    'Vibraphone','Bell','Chime','Tubular bells','Jingle bell','Wind chime','Flute','French horn']
results=[]
for filename,a,b in [('piano_35_67.wav',0,16),('piano_35_67.wav',16,32),
    ('other_67_108.wav',0,19),('piano_67_108.wav',0,19),('piano_67_108.wav',19,41),
    ('piano_108_141.wav',0,26),('other_108_141.wav',0,26),('other_141_161.wav',0,20)]:
    y,sr=sf.read(SEP/filename,dtype='float32');y=y[int(a*sr):int(b*sr)].mean(1)
    rms=float(np.sqrt(np.mean(y**2)));gain=min(.1/max(rms,1e-9),.8/max(np.max(np.abs(y)),1e-9))
    norm=librosa.resample(y*gain,orig_sr=sr,target_sr=16000)
    scores=session.run(['output_0'],{'waveform':norm.astype('float32')})[0].mean(0)
    ix=sorted([labels.index(label)for label in selected],key=lambda i:scores[i],reverse=True)
    results.append({'file':filename,'relative_start_s':a,'relative_end_s':b,'source_rms':rms,
        'normalized_gain_db':float(20*np.log10(gain)),
        'top_selected_tags':[{'label':labels[i],'uncalibrated_score':float(scores[i])}for i in ix[:8]]})
    print(json.dumps(results[-1]),flush=True)
for source,name,a,b in [('piano_108_141.wav','keyboard_group_108_134_preview.wav',0,26),
                       ('other_141_161.wav','other_group_141_156_preview.wav',0,15)]:
    y,sr=sf.read(SEP/source,dtype='float32');y=y[int(a*sr):int(b*sr)]
    rms=float(np.sqrt(np.mean(y**2)));gain=min(.07/max(rms,1e-9),.8/max(np.max(np.abs(y)),1e-9))
    sf.write(OUT/name,y*gain,sr,subtype='PCM_16')
(OUT/'stem_tags_supplement.json').write_text(json.dumps({'method':'YAMNet on level-normalized Demucs model groups',
    'limits':['Two fallible model stages; neither labels nor scores confirm actual instrumentation.',
              'Specific celesta and Japanese bell classes absent.','Residual sum RMS 17-18%; stems include artifacts/leakage.',
              'Assistant did not audition these previews.'],'results':results},indent=2),encoding='utf-8')
