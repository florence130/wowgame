"""Deterministic original piano sketch; no source melody samples or notes copied."""
from pathlib import Path
import sys,json,subprocess,hashlib
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'.local/music_reference_20261011/model_deps'),str(ROOT/'.local/music_reference_20261011/rhythm_deps')]
import pretty_midi,numpy as np,soundfile as sf
OUT=ROOT/'output/audio/menu_piano_sketch_20261012';OUT.mkdir(parents=True,exist_ok=True)
beat=60/72
# Four twelve-beat phrases: A, identical A, B, returning A with quiet closure.
A=[(0,'D5',1.6),(2,'F5',2.6),(5,'E5',1.7),(8,'A4',3.2)]
B=[(0,'C5',2.7),(4,'Bb4',1.7),(7,'G4',1.7),(10,'A4',1.5)]
Ac=[(0,'D5',1.6),(2,'F5',2.6),(5,'E5',1.7),(8,'D5',3.2)]
phrases=[A,A,B,Ac]
mid=pretty_midi.PrettyMIDI(initial_tempo=72)
mid.time_signature_changes.append(pretty_midi.TimeSignature(6,4,0))
mel=pretty_midi.Instrument(0,name='Original theme')
harm=pretty_midi.Instrument(0,name='Sparse piano harmony')
for ix,phrase in enumerate(phrases):
    for j,(at,name,length) in enumerate(phrase):
        start=(ix*12+at)*beat
        mel.notes.append(pretty_midi.Note([47,50,45,42][j],pretty_midi.note_name_to_number(name),start,start+length*beat))
chords=[['D3','A3','F4'],['Bb2','F3','D4'],['D3','A3','F4'],['Bb2','F3','D4'],['G2','D3','Bb3'],['A2','E3','C4'],['Bb2','F3','D4'],['D3','A3','F4']]
for bar,chord in enumerate(chords):
    for j,name in enumerate(chord):
        start=bar*6*beat+.035*j
        harm.notes.append(pretty_midi.Note(29+j*2,pretty_midi.note_name_to_number(name),start,start+4.4*beat))
mid.instruments=[mel,harm]
for bar in range(8):
    harm.control_changes.extend([pretty_midi.ControlChange(64,90,bar*6*beat+.1),pretty_midi.ControlChange(64,0,(bar*6+5.5)*beat)])
mp=OUT/'After_the_Last_Light_piano.mid';mid.write(str(mp))
work=ROOT/'.local/free_audio_20261011'
fl=work/'fluidsynth/fluidsynth-v2.6.1-win10-x64-cpp11/bin/fluidsynth.exe'
wav=OUT/'After_the_Last_Light_piano.wav'
subprocess.run([str(fl),'-ni','-r','44100','-g','.65','-o','synth.chorus.active=0','-o','synth.reverb.room-size=0.55','-o','synth.reverb.level=0.18','-F',str(wav),str(work/'GeneralUser-GS.sf2'),str(mp)],check=True,stdout=subprocess.DEVNULL)
y,sr=sf.read(wav,always_2d=True)
assert np.isfinite(y).all()
# Retain performance dynamics; a single constant gain only.
gain=min(10**(-25/20)/max(np.sqrt(np.mean(y*y)),1e-12),10**(-4/20)/max(np.max(np.abs(y)),1e-12))
y*=gain;sf.write(wav,y,sr,subtype='PCM_24')
ff=ROOT/'.local/menu_music_20261011/deps/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe'
mp3=OUT/'After_the_Last_Light_piano.mp3'
subprocess.run([str(ff),'-y','-v','error','-i',str(wav),'-c:a','libmp3lame','-q:a','2',str(mp3)],check=True)
report={'title':'After the Last Light / 余光之后','scope':'original piano theme sketch; not installed in game; not auditioned by assistant','bpm':72,'meter':'6/4','composed_duration_s':40,'render_duration_s':round(len(y)/sr,3),'melody_notes':len(mel.notes),'harmony_attacks':8,'structure':['A','A identical','B response','A modified closure'],'peak_dbfs':round(float(20*np.log10(np.max(np.abs(y)))),2),'no_drums_or_harp_or_strings':True,'source_reference':'User score informs phrase repetition and rests only; no original note sequence reused','soundfont':'GeneralUser GS 2.0.3; historical sample-source caveat retained in assets/third_party/free_audio/GeneralUser_GS_LICENSE.txt','sha256_mp3':hashlib.sha256(mp3.read_bytes()).hexdigest()}
(OUT/'sketch_notes.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,ensure_ascii=False))
