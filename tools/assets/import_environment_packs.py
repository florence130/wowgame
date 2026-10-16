"""Extract source assets from the user's Unity packs without requiring Unity.

Only asset bytes are read; documentation and scripts are treated as source data.
The original archives are never modified. Run --inventory first, then --extract.
"""
from pathlib import Path
import argparse
import hashlib
import gzip
import json
import tarfile

ROOT = Path(__file__).resolve().parents[2]
STAGING = ROOT / '.local/environment_20261011/source'
PACKS = {
    'sky': Path('F:/资源/服装/Super Simple Skybox 5.0.0.unitypackage'),
    'plants': Path('F:/资源/服装/53.Cartoon Grass and Plants 1.01 卡通草地植物/Cartoon Grass and Plants v1.01.unitypackage'),
    'water': Path('F:/资源/服装/Stylized Water For URP 1.1.2.unitypackage'),
    'ethereal': Path('F:/资源/服装/Ethereal URP - Volumetric Lighting Fog v1.6.5.unitypackage'),
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--extract', action='store_true')
    args = parser.parse_args()
    report = {}
    for name, path in PACKS.items():
        paths = {}
        with gzip.open(path, 'rb') as compressed, tarfile.open(fileobj=compressed, mode='r|') as archive:
            for member in archive:
                if member.isfile() and member.name.endswith('/pathname'):
                    paths[member.name.split('/')[0]] = archive.extractfile(member).read().decode('utf-8').splitlines()[0].rstrip('\x00')
        with gzip.open(path, 'rb') as compressed, tarfile.open(fileobj=compressed, mode='r|') as archive:
            records = []
            for asset in archive:
                key = asset.name
                if not asset.isfile() or not key.endswith('/asset') or key.split('/')[0] not in paths:
                    continue
                pathname = paths[key.split('/')[0]]
                record = {'guid': key.split('/')[0], 'path': pathname, 'bytes': asset.size}
                if args.extract:
                    relative = Path(pathname)
                    if relative.is_absolute() or '..' in relative.parts:
                        raise ValueError(f'Unsafe archive path: {pathname}')
                    target = STAGING / name / relative
                    target.parent.mkdir(parents=True, exist_ok=True)
                    data = archive.extractfile(asset).read()
                    target.write_bytes(data)
                    record['sha256'] = hashlib.sha256(data).hexdigest()
                records.append(record)
            report[name] = {'source': str(path), 'bytes': path.stat().st_size, 'assets': records}
            print(name, len(records), 'assets')
            for item in records:
                if Path(item['path']).suffix.lower() in {'.fbx', '.shader', '.shadergraph', '.png', '.tga', '.hlsl', '.compute'}:
                    print(' ', item['path'], item['bytes'])
    STAGING.parent.mkdir(parents=True, exist_ok=True)
    (STAGING.parent / 'inventory.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
