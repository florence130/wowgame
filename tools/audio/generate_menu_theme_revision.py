"""One authorized MXAPI submission; secrets accepted only through runtime stdin."""
from pathlib import Path
import sys,json,urllib.request,urllib.parse,urllib.error,datetime,hashlib
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'output/audio/menu_theme_revision_20261011'
WORK=ROOT/'.local/menu_theme_revision_20261011'
if len(sys.argv)>2:
    attempt=sys.argv[2]
    if attempt not in ['retry1']:raise SystemExit('Unknown explicit attempt identifier')
    WORK=WORK/attempt
WORK.mkdir(parents=True,exist_ok=True)
action=sys.argv[1]
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')
key=sys.stdin.readline().strip() if action in ['submit','poll'] else ''
def write(name,data):
    s=json.dumps(data,indent=2,ensure_ascii=False)
    if key:s=s.replace(key,'[REDACTED]')
    (WORK/name).write_text(s,encoding='utf-8')
def api(path,body=None):
    assert key,'Missing runtime API credential'
    headers={'Authorization':'Bearer '+key,'Accept':'application/json'}
    data=None
    if body is not None:
        headers['Content-Type']='application/json';data=json.dumps(body,ensure_ascii=False).encode()
    req=urllib.request.Request('https://open.mxapi.org'+path,data=data,headers=headers)
    try:
        with urllib.request.urlopen(req,timeout=90)as r:result=json.load(r)
    except urllib.error.HTTPError as e:
        try:result=json.loads(e.read())
        except Exception:result={}
        message=str(result.get('message',''))[:350].replace(key,'[REDACTED]')
        write('last_api_error.json',{'http_status':e.code,'api_path':path.split('?')[0],
             'message':message,'observed_utc':datetime.datetime.now(datetime.timezone.utc).isoformat()})
        raise RuntimeError(f'API HTTP {e.code}: {message}') from None
    if result.get('code')not in [200,0]:
        raise RuntimeError('API rejected: '+str(result.get('message',''))[:350].replace(key,'[REDACTED]'))
    return result
if action=='submit':
    marker=WORK/'submission_attempt.json'
    if marker.exists():raise SystemExit('Submission attempt already recorded; inspect it before any further request.')
    request=json.loads((OUT/'suno_request.json').read_text(encoding='utf-8'))
    write('submission_attempt.json',{'started_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
        'request_sha256':hashlib.sha256((OUT/'suno_request.json').read_bytes()).hexdigest(),
        'endpoint':'https://open.mxapi.org/api/v2/music/generate','retry_policy':'No automatic retry of submission.'})
    result=api('/api/v2/music/generate',request)
    write('submission.json',result)
    ids=result.get('data',{}).get('task_ids',[])
    if len(ids)!=2:raise RuntimeError('Unexpected task count; response retained for inspection.')
    print(json.dumps({'accepted':True,'task_ids':ids,'request_sha256':hashlib.sha256((OUT/'suno_request.json').read_bytes()).hexdigest()}),flush=True)
elif action=='poll':
    ids=json.loads((WORK/'submission.json').read_text())['data']['task_ids']
    for task in ids:
        result=api('/api/v2/music/task?id='+urllib.parse.quote(str(task)))
        write(f'task_{task}.json',result)
        data=result.get('data',{});r=data.get('result')or{}
        print(json.dumps({'task_id':task,'status':data.get('status'),'progress':r.get('progress'),
            'duration_s':r.get('fileInfo',{}).get('duration'),'points_cost':data.get('points_cost'),
            'error':data.get('error')},ensure_ascii=False),flush=True)
elif action=='download':
    ids=json.loads((WORK/'submission.json').read_text())['data']['task_ids'];manifest=[]
    for label,task in zip(['A','B'],ids):
        j=json.loads((WORK/f'task_{task}.json').read_text())['data']
        if j.get('status')!='completed':raise RuntimeError('Task not complete; downloading withheld.')
        result=j['result'];url=result.get('proxy_url')or result.get('fileInfo',{}).get('mp3Url')
        if not url:raise RuntimeError('Completed response has no audio URL.')
        dst=WORK/f'candidate_{label}.source';req=urllib.request.Request(url,headers={'User-Agent':'Codex music asset retrieval'})
        with urllib.request.urlopen(req,timeout=90)as r,dst.open('wb')as f:
            total=0
            while True:
                b=r.read(1024*1024)
                if not b:break
                total+=len(b)
                if total>80*1024*1024:raise RuntimeError('Unexpectedly large audio asset.')
                f.write(b)
        row={'candidate':label,'task_id':task,'custom_id':result.get('custom_id'),
            'declared_duration_s':result.get('fileInfo',{}).get('duration'),
            'bytes':total,'sha256':hashlib.sha256(dst.read_bytes()).hexdigest()}
        manifest.append(row);print(json.dumps(row),flush=True)
    (OUT/'generation_provenance.json').write_text(json.dumps({'request_sha256':hashlib.sha256((OUT/'suno_request.json').read_bytes()).hexdigest(),
        'candidates':manifest,'original_reference_uploaded':False,
        'limits':'Download/metadata do not establish musical similarity or actual instrumentation.'},indent=2),encoding='utf-8')
else:raise SystemExit('Unknown action')
