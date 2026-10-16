"""Official Hunyuan3D API-key client: untextured 3000-face geometry only.

No submit retries: uncertain submission is retained for manual reconciliation.
Key is read from HUNYUAN3D_API_KEY and is never persisted or printed.
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.request
import urllib.error
import urllib.parse

BASE = 'https://api.ai3d.cloud.tencent.com/v1/ai3d/'
ROOT = Path(__file__).resolve().parents[3]
IMAGES = ROOT/'output/imagegen/abbey_tripo_20261007/pack_v1/parts'
JOBS = ROOT/'.local/abbey_hunyuan_20261007/jobs'
OUT = ROOT/'assets/models/abbey_hunyuan_v1/build001/raw'


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')


def api(operation, payload):
    key = os.environ.get('HUNYUAN3D_API_KEY', '').strip()
    if not key:
        raise ValueError('Set HUNYUAN3D_API_KEY in this process environment.')
    req = urllib.request.Request(BASE+operation, data=json.dumps(payload).encode(),
        headers={'Authorization': key, 'Content-Type':'application/json'}, method='POST')
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    try:
        with opener.open(req, timeout=90) as res:
            return json.load(res)
    except urllib.error.HTTPError as e:
        body = e.read(16000).decode('utf-8','replace').replace(key,'[REDACTED]')
        return {'http_error':e.code, 'body':body}


def unwrap(response):
    return response.get('Response',response)


def submit(aid):
    folder = JOBS/aid
    if folder.exists():
        # A received HTTP 400 with explicit parameter rejection has no JobId.
        # Permit one documented-schema correction; preserve its exact receipt.
        old_path=folder/'submit_response.json'
        old=json.loads(old_path.read_text(encoding='utf-8')) if old_path.exists() else {}
        try:
            rejected=json.loads(old.get('body','{}'))
        except (TypeError,ValueError):
            rejected={}
        parameter_rejected=(old.get('http_error')==400 and rejected.get('Code')==1001
                            and rejected.get('Msg')=='Invalid param')
        if (folder/'job.json').exists() or not parameter_rejected or (folder/'submit_response_attempt1.json').exists():
            raise ValueError('Existing/uncertain submission; do not submit another billable request.')
        old_path.rename(folder/'submit_response_attempt1.json')
        (folder/'request.json').rename(folder/'request_attempt1.json')
    else:
        folder.mkdir(parents=True)
    image = IMAGES/(aid+'.png')
    data = image.read_bytes()
    payload = {'Model':'3.0', 'GenerateType':'Geometry', 'FaceCount':3000,
               'EnablePBR':False, 'ImageBase64':base64.b64encode(data).decode()}
    public = {k:v for k,v in payload.items() if k!='ImageBase64'}
    public.update(image=str(image), image_sha256=hashlib.sha256(data).hexdigest(),
                  input_schema='ImageBase64 raw base64, per official professional-task schema', endpoint=BASE+'submit', status='submitting')
    save(folder/'request.json',public)
    response = api('submit',payload)
    save(folder/'submit_response.json',response)
    result = unwrap(response)
    job = result.get('JobId') or result.get('job_id')
    if job:
        save(folder/'job.json',{'asset':aid,'JobId':job,'provider':'Tencent Hunyuan3D','request':public})
        print(json.dumps({'asset':aid,'submitted':True,'JobId':job},ensure_ascii=False))
    else:
        print(json.dumps({'asset':aid,'submitted':False,'response':response},ensure_ascii=False))
        raise SystemExit(2)


def query(aid):
    folder=JOBS/aid
    job=json.loads((folder/'job.json').read_text(encoding='utf-8'))
    response=api('query',{'JobId':job['JobId']})
    save(folder/'query_latest.json',response)
    r=unwrap(response)
    print(json.dumps({'asset':aid,'status':r.get('Status'),
        'error':r.get('Error') or r.get('ErrorMessage') or response.get('body'),
        'result_types':[x.get('Type') for x in r.get('ResultFile3Ds',[])],
        'credits':r.get('ResultCreditConsumed')},ensure_ascii=False))


def download(aid):
    folder=JOBS/aid
    r=unwrap(json.loads((folder/'query_latest.json').read_text(encoding='utf-8')))
    if r.get('Status')!='DONE':
        raise ValueError('Only a confirmed DONE result can be downloaded.')
    files=r.get('ResultFile3Ds',[])
    item=next((x for x in files if x.get('Type','').upper()=='GLB'),None)
    if item is None:
        raise ValueError('No GLB returned; inspect available result types.')
    url=item['Url']
    if urllib.parse.urlparse(url).scheme!='https':
        raise ValueError('Refusing a non-HTTPS result URL.')
    OUT.mkdir(parents=True,exist_ok=True)
    dest=OUT/(aid+'.glb')
    if dest.exists():
        raise ValueError('Refusing to overwrite a downloaded model.')
    # Result download intentionally has NO API authorization header.
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
    with opener.open(url,timeout=90) as res:
        data=res.read(128*1024*1024+1)
    if len(data)>128*1024*1024 or data[:4]!=b'glTF':
        raise ValueError('Unexpected model payload; original result receipt retained.')
    with dest.open('xb') as f: f.write(data)
    receipt={'asset':aid,'provider':'Tencent Hunyuan3D','JobId':json.loads((folder/'job.json').read_text())['JobId'],
             'file':str(dest),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),
             'requested_generate_type':'Geometry','requested_faces':3000,'requested_pbr':False,
             'credits':r.get('ResultCreditConsumed'),'credit_details':r.get('ResultCreditDetails'),
             'geometry_and_texture_status':'not_yet_inspected'}
    save(OUT/(aid+'_receipt.json'),receipt)
    print(json.dumps(receipt,ensure_ascii=False))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation',choices=['submit','query','download'])
    parser.add_argument('asset',choices=['TR01','TR02','TR03','TR04','TR05','TR06'])
    args=parser.parse_args()
    {'submit':submit,'query':query,'download':download}[args.operation](args.asset)


if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    main()
