"""Read-only independent coverage check of the ground snapshot embedded in the HTML data."""
from pathlib import Path
import json, sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / '.local/city_v5/audit_deps'))
from shapely.geometry import Polygon
from shapely.ops import unary_union

data = json.loads((ROOT / 'tools/city_web/city-data.json').read_text(encoding='utf-8'))
plan = data.get('groundPlan', {})
if not plan.get('faces'):
    print(json.dumps({'pass': False, 'error': 'No exported ground plan'}))
    raise SystemExit(1)

def polygon(row):
    return Polygon(row['polygon'], row.get('holes', []))

water = unary_union([polygon(p) for p in plan.get('waterExclusions', [])])
land = Polygon(plan['urbanBoundary']).difference(water)
faces, invalid, triangulation_errors = [], [], []
for row in plan['faces']:
    poly = polygon(row)
    if not poly.is_valid:
        invalid.append(row['id'])
        continue
    faces.append(poly)
    vertices = row.get('vertices', [])
    pieces = []
    for tri in row.get('triangles', []):
        points = [(vertices[i][0], vertices[i][2]) for i in tri]
        piece = Polygon(points)
        if piece.area > 1e-9:
            pieces.append(piece)
    projected = unary_union(pieces)
    difference = projected.symmetric_difference(poly).area
    if difference > .02:
        triangulation_errors.append({'id': row['id'], 'differenceArea': difference})

covered = unary_union(faces)
parks = [polygon(p) for p in plan.get('parks', [])]
park_faces = [polygon(f) for f in plan['faces'] if f.get('kind') == 'park']
park_difference = unary_union(parks).symmetric_difference(unary_union(park_faces)).area
walk_faces = unary_union([polygon(f) for f in plan['faces']
                          if f.get('kind') in {'pedestrian', 'sidewalk', 'carriageway', 'promenade'}])
path_gaps = []
for path in plan.get('pedestrianPaths', []):
    missing = polygon(path).difference(walk_faces).area
    if missing > .02:
        path_gaps.append({'id': path['id'], 'missingPhysicalWalkArea': missing})
result = {
    'scope': 'Independent polygon and triangle projection check; does not prove route connectivity or vertical seam correctness.',
    'landArea': land.area,
    'missingArea': land.difference(covered).area,
    'overlapArea': sum(p.area for p in faces) - covered.area,
    'outsideLandArea': covered.difference(land).area,
    'waterIntrusionArea': covered.intersection(water).area,
    'parkCount': len(parks), 'parkFaceCount': len(park_faces),
    'parkPartitionDifferenceArea': park_difference,
    'invalidPolygons': invalid, 'triangulationErrors': triangulation_errors,
    'pedestrianPaths': len(plan.get('pedestrianPaths', [])),
    'pathsMissingPhysicalWalkingFaces': path_gaps,
}
result['pass'] = (not invalid and not triangulation_errors and len(parks) == 2
                  and result['missingArea'] < .05 and result['overlapArea'] < .05
                  and result['outsideLandArea'] < .05 and result['waterIntrusionArea'] < .05
                  and park_difference < .05 and not path_gaps)
print(json.dumps(result, ensure_ascii=False))
raise SystemExit(0 if result['pass'] else 1)
