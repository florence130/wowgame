"""Genuine signed-distance fields -> welded marching-tetrahedra mesh.

No remesh modifier and no mesh input. Only sampled analytic scalar fields.
Socket-bearing architecture deliberately does not use this route.
"""
import numpy as np
import math

def rounded_box(p,half,r):
    q=np.abs(p)-np.array(half)+r
    return np.linalg.norm(np.maximum(q,0),axis=-1)+np.minimum(np.max(q,axis=-1),0)-r

def sphere(p,r):return np.linalg.norm(p,axis=-1)-r

def smooth_union(a,b,k):
    h=np.clip(.5+.5*(b-a)/k,0,1)
    return b*(1-h)+a*h-k*h*(1-h)

def field(p,kind,refined=True):
    if kind=='stone':
        d=rounded_box(p,(.5,.3,.28),.1 if refined else .035)
        if refined:d+=.014*np.sin(p[...,0]*13+1)*np.sin(p[...,1]*17)*np.cos(p[...,2]*11)
        return d
    if kind=='plinth':
        a=rounded_box(p-np.array([0,0,-.2]),(.65,.65,.12),.07)
        b=rounded_box(p-np.array([0,0,.02]),(.48,.48,.23),.07)
        return smooth_union(a,b,.12 if refined else .01)
    if kind=='rock':
        a=sphere((p-np.array([-.15,0,0]))/np.array([1.1,.9,.65]),.65)*.65
        b=sphere((p-np.array([.38,.1,.1]))/np.array([1,.85,1]),.42)*.85
        return smooth_union(a,b,.22 if refined else .01)
    raise ValueError(kind)

def polygonize(kind='stone',step=.075,refined=True):
    if not .025<=step<=.2:raise ValueError('SDF step must be 0.025–0.2 metres')
    axis=np.arange(-1.,1.00001,step);p=np.stack(np.meshgrid(axis,axis,axis,indexing='ij'),-1)
    val=field(p,kind,refined);verts=[];faces=[];cache={}
    # Six tetrahedra sharing the 0-6 cube diagonal. Corner ordering is fixed.
    off=[(0,0,0),(1,0,0),(1,1,0),(0,1,0),(0,0,1),(1,0,1),(1,1,1),(0,1,1)]
    tets=[(0,1,2,6),(0,2,3,6),(0,3,7,6),(0,7,4,6),(0,4,5,6),(0,5,1,6)]
    edges=[(0,1),(0,2),(0,3),(1,2),(1,3),(2,3)]
    vals=[val[a:val.shape[0]-1+a,b:val.shape[1]-1+b,c:val.shape[2]-1+c] for a,b,c in off]
    crossing=(np.min(vals,axis=0)<0)&(np.max(vals,axis=0)>=0)
    for base in np.argwhere(crossing):
        ids=[tuple(base+o) for o in off]; ps=[p[i] for i in ids];ds=[val[i] for i in ids]
        for tet in tets:
            points=[];indices=[]
            for ea,eb in edges:
                a,b=tet[ea],tet[eb]
                if (ds[a]<0)==(ds[b]<0):continue
                key=tuple(sorted((ids[a],ids[b])))
                pt=ps[a]+ds[a]/(ds[a]-ds[b])*(ps[b]-ps[a])
                if key not in cache:cache[key]=len(verts);verts.append(tuple(pt))
                indices.append(cache[key]);points.append(pt)
            if len(indices)<3:continue
            center=np.mean(points,axis=0); eps=.001
            normal=np.array([(field(center+np.eye(3)[k]*eps,kind,refined)-field(center-np.eye(3)[k]*eps,kind,refined)) for k in range(3)])
            normal/=max(np.linalg.norm(normal),1e-10)
            u=points[0]-center;u/=max(np.linalg.norm(u),1e-10);v=np.cross(normal,u)
            order=sorted(range(len(points)),key=lambda i:math.atan2(np.dot(points[i]-center,v),np.dot(points[i]-center,u)))
            ids2=[indices[i] for i in order]
            for i in range(1,len(ids2)-1):faces.append((ids2[0],ids2[i],ids2[i+1]))
    return verts,faces
