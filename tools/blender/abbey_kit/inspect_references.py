"""Read-only source inspection; write labelled contact sheets and video frames."""
from pathlib import Path
import sys, subprocess, re, json
from PIL import Image, ImageDraw, ImageFont
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'docs/abbey_kit_v1/references'
OUT.mkdir(parents=True, exist_ok=True)
SOURCE = Path('E:/DOWNLOADS/新建文件夹')
font = ImageFont.truetype('C:/Windows/Fonts/msyh.ttc', 17)
def sheet(paths, output, cols=4, cell=(400,280)):
    im = Image.new('RGB',(cols*cell[0], ((len(paths)+cols-1)//cols)*cell[1]),'#ece8df')
    d = ImageDraw.Draw(im)
    for i,p in enumerate(paths):
        tile=Image.open(p).convert('RGB'); tile.thumbnail((cell[0]-16,cell[1]-42))
        x,y=(i%cols)*cell[0],(i//cols)*cell[1]
        im.paste(tile,(x+(cell[0]-tile.width)//2,y+8))
        d.text((x+10,y+cell[1]-29),p.name,font=font,fill='#24313a')
    im.save(output)
paths=sorted(p for p in SOURCE.iterdir() if p.suffix.lower() in ('.png','.jpg','.jpeg'))
sheet(paths,OUT/'images_contact.jpg')
sys.path.insert(0,str(ROOT/'.local/abbey-media-deps'))
import imageio_ffmpeg
ff=imageio_ffmpeg.get_ffmpeg_exe()
video=SOURCE/'32627100298-1-192.mp4'
r=subprocess.run([ff,'-hide_banner','-i',str(video)],capture_output=True,text=True,encoding='utf-8',errors='replace')
m=re.search(r'Duration: (\d+):(\d+):(\d+(?:\.\d+)?)',r.stderr)
duration=int(m[1])*3600+int(m[2])*60+float(m[3])
frames=[]; stamps=[]
for i in range(16):
    t=duration*(i+.4)/16; p=OUT/f'video_{int(t)//60:02d}m{int(t)%60:02d}s.jpg'
    subprocess.run([ff,'-hide_banner','-loglevel','error','-ss',str(t),'-i',str(video),'-frames:v','1','-vf','scale=960:-1','-y',str(p)],check=True)
    frames.append(p); stamps.append({'file':p.name,'time_seconds':round(t,3)})
sheet(frames,OUT/'video_contact.jpg')
(OUT/'source_index.json').write_text(json.dumps({'video':str(video),'duration_seconds':duration,'samples':stamps,'images':[str(p) for p in paths]},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'images':len(paths),'duration':duration,'output':str(OUT)},ensure_ascii=False))
