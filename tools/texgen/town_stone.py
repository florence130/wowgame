"""Deterministic, seamless broad cobbles for the town material; original art."""
from pathlib import Path
import json,numpy as np
from PIL import Image

root=Path(__file__).resolve().parents[2]
out=root/'assets/textures/mmo';out.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(20261016)
size=512;n=9
yy,xx=np.mgrid[0:size,0:size].astype(np.float32)
seeds=[]
for j in range(n):
    for i in range(n):
        seeds.append(((i+.5+rng.uniform(-.22,.22))*size/n,(j+.5+rng.uniform(-.22,.22))*size/n))
best=np.full((size,size),np.inf,dtype=np.float32)
second=best.copy();index=np.zeros((size,size),dtype=np.int32)
for k,(sx,sy) in enumerate(seeds):
    dx=np.minimum(abs(xx-sx),size-abs(xx-sx));dy=np.minimum(abs(yy-sy),size-abs(yy-sy))
    distance=np.sqrt((dx*.96)**2+(dy*1.04)**2)
    closer=distance<best
    second=np.where(closer,best,np.minimum(second,distance))
    index=np.where(closer,k,index)
    best=np.minimum(best,distance)
palette=np.array([[143,144,130],[154,150,135],[131,139,129],[151,145,129],[142,142,131],[160,153,135]],dtype=np.float32)
colors=palette[rng.integers(0,len(palette),size=n*n)]
color=colors[index]
edge=second-best
joint=np.clip((edge-1.5)/3.5,0,1)
joint=joint*joint*(3-2*joint)
grain=1.3*np.sin(xx*2*np.pi/size*17)*np.sin(yy*2*np.pi/size*13)+1.1*np.cos((xx+yy)*2*np.pi/size*9)
color=color+grain[:,:,None]
# Broad bevel gives a readable stone silhouette without noisy high-frequency normals.
bevel=np.clip(edge/10,0,1)
color*=.88+.12*bevel[:,:,None]
seam=np.array([88,98,77],dtype=np.float32)
result=seam[None,None,:]*(1-joint[:,:,None])+color*joint[:,:,None]
Image.fromarray(np.clip(result,0,255).astype('uint8')).save(out/'town_stone.png')
(out/'SOURCE.json').write_text(json.dumps({'source':'Original deterministic procedural material','generator':'tools/texgen/town_stone.py','seed':20261016,'resolution':[512,512],'usage':'Per-zone cobble override; broad irregular cobbles, muted stone and moss joints; opaque rough terrain material.','license':'Project-authored asset; no third-party source pixels.'},indent=2))
print('Generated',out/'town_stone.png')
