"""Package this reference-stage delivery using an explicit allow-list; no network."""
from pathlib import Path
import hashlib
import json
import zipfile

ROOT = Path(__file__).resolve().parents[3]
DOC = ROOT/'docs/abbey_tripo_20261007'
TOOLS = Path(__file__).resolve().parent
PACK = ROOT/'output/imagegen/abbey_tripo_20261007/pack_v1'
OUT = ROOT/'output/imagegen/abbey_tripo_20261007/abbey_tripo_stage1_v1.zip'


def main():
    if OUT.exists():
        raise SystemExit('Refusing to replace an existing delivery archive.')
    files = []
    for name in ['START_HERE.md','TASK.md','BREAKDOWN.md','HANDOFF.md','GENERATION.md','REVIEW.md','TOOL_VALIDATION.json','image_prompt.txt','crop_regions.json']:
        files.append(DOC/name)
    files += [DOC/'references/townhall.png', DOC/'references/legacy_breakdown.png']
    for name in ['import_tripo.py','assets.json','README.md','make_image_pack.py','package_delivery.py']:
        files.append(TOOLS/name)
    files += [p for p in PACK.rglob('*') if p.is_file() and p.suffix.lower() in {'.png','.json','.md','.txt'}]
    files.append(PACK.parent/'tripo_parts_clean_v1.png')
    rows = []
    for path in sorted(files):
        data = path.read_bytes()
        rows.append({'path':path.relative_to(ROOT).as_posix(),'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()})
        if path.suffix.lower() in {'.py','.json','.md','.txt'}:
            text = data.decode('utf-8-sig')
            # Reject likely inline API secrets without printing the matching text.
            import re
            if re.search(r'sk-[A-Za-z0-9_-]{24,}',text):
                raise ValueError('Possible credential in delivery text; package aborted.')
    with zipfile.ZipFile(OUT,'x',zipfile.ZIP_DEFLATED) as z:
        z.writestr('START_HERE.md',(DOC/'START_HERE.md').read_bytes())
        for row in rows:
            z.write(ROOT/row['path'],row['path'])
        z.writestr('DELIVERY_MANIFEST.json',json.dumps({'stage':'reference_and_import_prototype','files':rows},ensure_ascii=False,indent=2)+'\n')
    with zipfile.ZipFile(OUT) as z:
        assert z.testzip() is None
        for row in rows:
            assert hashlib.sha256(z.read(row['path'])).hexdigest()==row['sha256']
    report={'zip':str(OUT),'bytes':OUT.stat().st_size,'sha256':hashlib.sha256(OUT.read_bytes()).hexdigest(),'file_count':len(rows)+2,'crc_and_file_hashes_verified':True}
    (DOC/'PACKAGE.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False))


if __name__=='__main__':
    main()
