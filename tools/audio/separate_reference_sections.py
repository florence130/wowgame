"""Demucs model groups for comparison, never exact instrument attribution."""
from pathlib import Path
import sys, json, hashlib, time
ROOT=Path(__file__).resolve().parents[2]
WORK=ROOT/'.local/music_reference_20261011'
OUT=ROOT/'output/audio/granblue_reference_20261011/melody/separated'
sys.path[:0]=[str(WORK/'rhythm_deps'),str(WORK/'separation_deps')]
import numpy as np
import soundfile as sf
import torch
from demucs.pretrained import get_model
from demucs.apply import apply_model
torch.set_num_threads(4)
torch.hub.set_dir(str(WORK/'models/torch_cache'))
model=get_model('htdemucs_6s').eval()
y,sr=sf.read(WORK/'reference_stereo.wav',dtype='float32')
assert sr==model.samplerate
OUT.mkdir(parents=True,exist_ok=True)
rows=[]
for a,b in [(35,67),(67,108),(108,141),(141,161)]:
    begin=time.monotonic()
    mix=torch.from_numpy(y[a*sr:b*sr].T.copy())
    ref=mix.mean(0);mean=ref.mean();scale=ref.std()
    normalized=(mix-mean)/scale
    with torch.no_grad():
        stems=apply_model(model,normalized[None],device='cpu',shifts=0,split=True,overlap=.25,progress=False)[0]
    stems=stems*scale+mean
    residual=mix-stems.sum(0)
    row={'start_s':a,'end_s':b,'elapsed_s':round(time.monotonic()-begin,2),
         'relative_sum_residual_rms':float(torch.sqrt((residual**2).mean())/torch.sqrt((mix**2).mean())),
         'groups':{}}
    sf.write(OUT/f'original_{a}_{b}.wav',mix.T.numpy(),sr,subtype='FLOAT')
    for label,stem in zip(model.sources,stems):
        data=stem.T.numpy()
        p=OUT/f'{label}_{a}_{b}.wav';sf.write(p,data,sr,subtype='FLOAT')
        row['groups'][label]={'rms':float(np.sqrt(np.mean(data**2))),
             'peak':float(np.max(np.abs(data))),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()}
    rows.append(row)
    print(json.dumps(row),flush=True)
    (OUT/'separation_report.json').write_text(json.dumps({'model':'htdemucs_6s',
         'sources':model.sources,'settings':{'shifts':0,'split':True,'overlap':.25,'threads':4},
         'input_sha256':hashlib.sha256((WORK/'reference_stereo.wav').read_bytes()).hexdigest(),
         'limits':['Labels are model groups, not identification of actual instruments.',
                   'Piano/harp/celesta/strings may leak across groups.',
                   'Sum residual is measured, not assumed zero.','Assistant did not audition audio.'],
         'segments':rows},indent=2),encoding='utf-8')
