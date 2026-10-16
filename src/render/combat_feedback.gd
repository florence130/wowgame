class_name CombatFeedback
extends RefCounted
## Presentation-only combat feedback: directional mesh arcs, streaks and school silhouettes.
##
## emit(parent, origin, target, school, style, strength) -> Node3D (or null)
##   parent    live Node3D that will own the returned root. origin/target are in parent-local space
##             (identical to world space when the parent has an identity transform). Pass the body-center
##             anchors of caster and target; the module never stores node references, only the two vectors.
##   school    physical fire frost water lightning light shadow wind arcane. Unknown names (for example the
##             exported "nature" and "neutral") use a neutral silver palette.
##   style     slash heavy shield thrust shot cast impact heal aoe. Unknown names fall back to "impact".
##   strength  "aoe": ground radius in meters, clamped 0.5..6. Other styles: size multiplier, clamped 0.4..2.0.
##
## Budgets (enforced in code, asserted by tests/test_feedback_lifecycle.gd):
##   * at most MAX_ROOTS (24) live roots across the whole game, emit() returns null beyond that
##   * at most MAX_MESHES (12) MeshInstance3D per root, no lights, particles, shadows or audio
##   * every root frees itself within LIFE_CAP (0.9 s) of entering the tree, measured on both scene time and the
##     wall clock, so slow motion or a paused tree cannot keep it alive; the global time scale is never touched
##   * no Tweens: the root drives its own animation from _process, so nothing can outlive the node
##   * leaving the tree (parent freed, removed or the scene changed) frees the root on the same frame
## No gameplay, damage or audio is produced here.

const MAX_ROOTS := 24
const MAX_MESHES := 12
const MAX_ARC_SEGMENTS := 12
const MAX_RING_SEGMENTS := 24
const LIFE_CAP := 0.9
const STYLES := ["slash", "heavy", "shield", "thrust", "shot", "cast", "impact", "heal", "aoe"]
const SCHOOLS := ["physical", "fire", "frost", "water", "lightning", "light", "shadow", "wind", "arcane"]
const UP := Vector3.UP

static var _live: Array = []
static var _meshes: Dictionary = {}


static func emit(parent: Node3D, origin: Vector3, target: Vector3, school: String, style: String, strength: float = 1.0) -> Node3D:
	if parent == null or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return null
	if not _finite3(origin) or not _finite3(target):
		return null
	_prune()
	if _live.size() >= MAX_ROOTS:
		return null
	var st := style.strip_edges().to_lower()
	if not STYLES.has(st):
		st = "impact"
	var sc := school.strip_edges().to_lower()
	if not SCHOOLS.has(sc):
		sc = "neutral"
	var amount := _clean_strength(strength, st == "aoe")
	var ctx := _compose(st, sc, origin, target, amount)
	var root := _FxRoot.new()
	root.name = "CombatFeedback_%s_%s" % [st, sc]
	root.set_meta("combat_feedback", {"style": st, "school": sc, "strength": amount})
	root.setup(ctx["parts"], float(ctx["life"]))
	parent.add_child(root)
	_live.append(root)
	return root


# ---------------------------------------------------------------- registry (test hooks are underscore-prefixed)
static func _live_count() -> int:
	_prune()
	return _live.size()


static func _prune() -> void:
	for i in range(_live.size() - 1, -1, -1):
		var r = _live[i]
		if not is_instance_valid(r) or r.is_queued_for_deletion():
			_live.remove_at(i)


static func _unregister(root: Object) -> void:
	_live.erase(root)


static func _release_cache() -> void:
	_meshes.clear()


static func _cache_size() -> int:
	return _meshes.size()


static func _finite3(v: Vector3) -> bool:
	return is_finite(v.x) and is_finite(v.y) and is_finite(v.z)


static func _clean_strength(strength: float, is_aoe: bool) -> float:
	var s := strength if is_finite(strength) else 1.0
	return clampf(s, 0.5, 6.0) if is_aoe else clampf(s, 0.4, 2.0)


# ---------------------------------------------------------------- runtime nodes
class _Part extends RefCounted:
	var mi: MeshInstance3D
	var mat: StandardMaterial3D
	var t0 := 0.0
	var t1 := 0.4
	var p0 := Vector3.ZERO
	var p1 := Vector3.ZERO
	var basis := Basis.IDENTITY
	var s0 := Vector3.ONE
	var s1 := Vector3.ONE
	var axis := Vector3.UP
	var a0 := 0.0
	var a1 := 0.0
	var c0 := Color.WHITE
	var c1 := Color.WHITE
	var ease_kind := 1
	var fade_in := 0.1
	var fade_out := 0.5


class _FxRoot extends Node3D:
	var parts: Array = []
	var life := 0.5
	var age := 0.0
	var _wall_start := 0
	var _finished := false

	func setup(p: Array, l: float) -> void:
		parts = p
		life = minf(l, CombatFeedback.LIFE_CAP)
		process_mode = Node.PROCESS_MODE_ALWAYS
		for part in parts:
			add_child(part.mi)
		_apply(0.0)
		tree_exiting.connect(_on_tree_exiting)

	func _enter_tree() -> void:
		_wall_start = Time.get_ticks_msec()

	func _process(delta: float) -> void:
		age += delta
		var wall := float(Time.get_ticks_msec() - _wall_start) / 1000.0
		var t := maxf(age, wall)
		if t >= life:
			_finish()
			return
		_apply(t)

	## Jump to an absolute time (tests and the sample capture use this to sample frames deterministically).
	func _seek(t: float) -> void:
		age = t
		if t >= life:
			_finish()
		else:
			_apply(t)

	func _apply(t: float) -> void:
		for part in parts:
			var span := maxf(part.t1 - part.t0, 0.001)
			if t < part.t0 or t > part.t1:
				part.mi.visible = false
				continue
			var u := clampf((t - part.t0) / span, 0.0, 1.0)
			var e := CombatFeedback._ease(u, part.ease_kind)
			var sc: Vector3 = part.s0.lerp(part.s1, e)
			sc = Vector3(maxf(sc.x, 0.001), maxf(sc.y, 0.001), maxf(sc.z, 0.001))
			var b: Basis = part.basis * Basis(part.axis, lerpf(part.a0, part.a1, e)) * Basis.from_scale(sc)
			part.mi.transform = Transform3D(b, part.p0.lerp(part.p1, e))
			var env := 1.0
			if u < part.fade_in:
				env = u / maxf(part.fade_in, 0.001)
			elif u > 1.0 - part.fade_out:
				env = (1.0 - u) / maxf(part.fade_out, 0.001)
			var col: Color = part.c0.lerp(part.c1, u)
			col.a *= clampf(env, 0.0, 1.0)
			part.mat.albedo_color = col
			part.mi.visible = true

	func _finish() -> void:
		if _finished:
			return
		_finished = true
		CombatFeedback._unregister(self)
		set_process(false)
		queue_free()

	func _on_tree_exiting() -> void:
		CombatFeedback._unregister(self)
		set_process(false)
		if not _finished and not is_queued_for_deletion():
			_finished = true
			queue_free()


# ---------------------------------------------------------------- palette
static func _palette(school: String, style: String) -> Dictionary:
	var main := Color(0.75, 0.8, 0.9)
	var hi := Color(1, 1, 1)
	var dark := Color(0.3, 0.33, 0.4)
	match school:
		"physical":
			main = Color(0.88, 0.9, 0.95); hi = Color(1.0, 0.93, 0.72); dark = Color(0.35, 0.37, 0.42)
		"fire":
			main = Color(1.0, 0.52, 0.12); hi = Color(1.0, 0.9, 0.4); dark = Color(0.5, 0.18, 0.02)
		"frost":
			main = Color(0.45, 0.82, 1.0); hi = Color(0.78, 0.96, 1.0); dark = Color(0.12, 0.35, 0.6)
		"water":
			main = Color(0.18, 0.62, 0.95); hi = Color(0.55, 0.88, 1.0); dark = Color(0.05, 0.2, 0.5)
		"lightning":
			main = Color(1.0, 0.9, 0.25); hi = Color(1.0, 1.0, 0.6); dark = Color(0.4, 0.35, 0.0)
		"light":
			main = Color(1.0, 0.88, 0.45); hi = Color(1.0, 0.97, 0.9); dark = Color(0.7, 0.5, 0.1)
		"shadow":
			main = Color(0.62, 0.3, 0.95); hi = Color(0.85, 0.6, 1.0); dark = Color(0.12, 0.03, 0.2)
		"wind":
			main = Color(0.55, 0.95, 0.75); hi = Color(0.78, 1.0, 0.8); dark = Color(0.2, 0.5, 0.4)
		"arcane":
			main = Color(0.8, 0.4, 1.0); hi = Color(0.45, 0.95, 1.0); dark = Color(0.3, 0.1, 0.55)
	if style == "heal" and not ["light", "water", "wind"].has(school):
		# friendly accents never borrow hostile palettes: pull toward soft green-gold
		main = main.lerp(Color(0.5, 1.0, 0.6), 0.55)
		hi = hi.lerp(Color(1.0, 1.0, 0.85), 0.5)
	return {"main": main, "hi": hi, "dark": dark}


# ---------------------------------------------------------------- geometry (cached, immutable, shared between roots)
static func _mesh(key: String) -> ArrayMesh:
	if _meshes.has(key):
		return _meshes[key]
	var p := key.split(":")
	var m: ArrayMesh
	match p[0]:
		"streak": m = _m_streak(false)
		"streak_x": m = _m_streak(true)
		"shard": m = _m_shard()
		"flame": m = _m_flame()
		"arc": m = _m_arc(float(p[1]), int(p[2]), float(p[3]))
		"ring": m = _m_ring(int(p[1]), float(p[2]))
		"plate": m = _m_plate()
		"bolt": m = _m_bolt(int(p[1]))
		"petal": m = _m_petal()
		"wisp": m = _m_wisp()
		"swirl": m = _m_swirl()
		_: m = _m_streak(false)
	_meshes[key] = m
	return m


static func _to_mesh(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


static func _strip(verts: PackedVector3Array, cols: PackedColorArray, idx: PackedInt32Array, lefts: Array, rights: Array, alphas: Array) -> void:
	var base := verts.size()
	for i in lefts.size():
		verts.append(lefts[i])
		verts.append(rights[i])
		cols.append(Color(1, 1, 1, alphas[i]))
		cols.append(Color(1, 1, 1, alphas[i]))
	for i in range(lefts.size() - 1):
		var a := base + i * 2
		idx.append_array(PackedInt32Array([a, a + 1, a + 2, a + 1, a + 3, a + 2]))


## Tapered diamond along -Z (tail at z=0, tip at z=-1). The cross variant adds a perpendicular copy so it reads from any side.
static func _m_streak(cross: bool) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var planes := 2 if cross else 1
	for k in planes:
		var side := Vector3(0.5, 0, 0) if k == 0 else Vector3(0, 0.5, 0)
		var base := verts.size()
		verts.append(Vector3(0, 0, 0))
		verts.append(-side + Vector3(0, 0, -0.35))
		verts.append(side + Vector3(0, 0, -0.35))
		verts.append(Vector3(0, 0, -1))
		cols.append(Color(1, 1, 1, 0.0))
		cols.append(Color(1, 1, 1, 0.8))
		cols.append(Color(1, 1, 1, 0.8))
		cols.append(Color(1, 1, 1, 1.0))
		idx.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	return _to_mesh(verts, cols, idx)


## Elongated bipyramid (ice shard, arcane diamond): 6 vertices, 8 triangles, visible from every angle.
static func _m_shard() -> ArrayMesh:
	var verts := PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -1)])
	var cols := PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 1.0)])
	var idx := PackedInt32Array()
	for i in 4:
		var a := TAU * float(i) / 4.0
		verts.append(Vector3(cos(a) * 0.5, sin(a) * 0.5, -0.3))
		cols.append(Color(1, 1, 1, 0.9))
	for i in 4:
		var v0 := 2 + i
		var v1 := 2 + (i + 1) % 4
		idx.append_array(PackedInt32Array([0, v0, v1, 1, v1, v0]))
	return _to_mesh(verts, cols, idx)


## Ember / flame tongue: bright base, tip fades out. Three-sided so it keeps a silhouette when rotated.
static func _m_flame() -> ArrayMesh:
	var verts := PackedVector3Array([Vector3(0, 0, 0), Vector3(0.12, 0, -1)])
	var cols := PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0)])
	var idx := PackedInt32Array()
	for i in 3:
		var a := TAU * float(i) / 3.0
		verts.append(Vector3(cos(a) * 0.5, sin(a) * 0.5, -0.28))
		cols.append(Color(1, 1, 1, 1.0))
	for i in 3:
		var v0 := 2 + i
		var v1 := 2 + (i + 1) % 3
		idx.append_array(PackedInt32Array([0, v0, v1, 1, v1, v0]))
	return _to_mesh(verts, cols, idx)


## Crescent / comet ribbon in the XZ plane, centered on -Z; the thick leading end is at the positive angle side.
static func _m_arc(span_deg: float, segs: int, width: float) -> ArrayMesh:
	segs = clampi(segs, 2, MAX_ARC_SEGMENTS)
	var span := deg_to_rad(span_deg)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var lefts := []
	var rights := []
	var alphas := []
	for i in segs + 1:
		var t := float(i) / float(segs)
		var a := (t - 0.5) * span
		var dir := Vector3(-sin(a), 0.0, -cos(a))
		var w := width * sin(PI * pow(t, 1.8))
		lefts.append(dir * (1.0 + w * 0.15))
		rights.append(dir * (1.0 - w * 0.85))
		alphas.append(pow(t, 1.2))
	_strip(verts, cols, idx, lefts, rights, alphas)
	return _to_mesh(verts, cols, idx)


## Flat annulus (or triangle/hexagon outline for few segments) in the XZ plane, outer radius 1.
static func _m_ring(segs: int, inner: float) -> ArrayMesh:
	segs = clampi(segs, 3, MAX_RING_SEGMENTS)
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for i in segs:
		var a := TAU * float(i) / float(segs) - PI * 0.5
		var o := Vector3(cos(a), 0, sin(a))
		verts.append(o)
		cols.append(Color(1, 1, 1, 1.0))
		verts.append(o * inner)
		cols.append(Color(1, 1, 1, 0.3))
	for i in segs:
		var a := i * 2
		var b := ((i + 1) % segs) * 2
		idx.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	return _to_mesh(verts, cols, idx)


## Heater-shield outline (hollow so the target stays visible) plus a thin spine, facing +Z/-Z in the XY plane.
static func _m_plate() -> ArrayMesh:
	var outline := [Vector2(-0.5, 0.55), Vector2(0.5, 0.55), Vector2(0.55, 0.1), Vector2(0.35, -0.3), Vector2(0.0, -0.65), Vector2(-0.35, -0.3), Vector2(-0.55, 0.1)]
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var n := outline.size()
	for p in outline:
		verts.append(Vector3(p.x, p.y, 0.0))
		cols.append(Color(1, 1, 1, 1.0))
		verts.append(Vector3(p.x * 0.74, p.y * 0.74 - 0.02, 0.05))
		cols.append(Color(1, 1, 1, 0.55))
	for i in n:
		var a := i * 2
		var b := ((i + 1) % n) * 2
		idx.append_array(PackedInt32Array([a, a + 1, b, a + 1, b + 1, b]))
	var s := verts.size()
	verts.append_array(PackedVector3Array([Vector3(-0.035, 0.48, 0.05), Vector3(0.035, 0.48, 0.05), Vector3(0.035, -0.5, 0.05), Vector3(-0.035, -0.5, 0.05)]))
	for i in 4:
		cols.append(Color(1, 1, 1, 0.85))
	idx.append_array(PackedInt32Array([s, s + 1, s + 2, s, s + 2, s + 3]))
	return _to_mesh(verts, cols, idx)


## Lightning fork along -Z: a jagged main strand with a side branch, built as two crossed ribbons so it reads from any side.
static func _m_bolt(variant: int) -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var pts := 8
	for plane in 2:
		var lefts := []
		var rights := []
		var alphas := []
		for i in pts:
			var t := float(i) / float(pts - 1)
			var j := 0.0 if (i == 0 or i == pts - 1) else (_hash01(variant * 7 + plane, i) - 0.5) * 0.26
			var hw := 0.05 * (1.0 - 0.5 * t)
			var c := Vector3(j, 0, -t) if plane == 0 else Vector3(0, j, -t)
			var side := Vector3(hw, 0, 0) if plane == 0 else Vector3(0, hw, 0)
			lefts.append(c - side)
			rights.append(c + side)
			alphas.append(1.0 - 0.35 * t)
		_strip(verts, cols, idx, lefts, rights, alphas)
	# short side branch from the middle of the strand
	var bl := []
	var br := []
	var ba := []
	var start := Vector3((_hash01(variant, 3) - 0.5) * 0.26, 0, -0.43)
	for i in 3:
		var t := float(i) / 2.0
		var c := start + Vector3(0.22 * t * (1.0 if variant % 2 == 0 else -1.0), 0.0, -0.28 * t)
		var hw := 0.035 * (1.0 - 0.7 * t)
		bl.append(c - Vector3(0, hw, 0))
		br.append(c + Vector3(0, hw, 0))
		ba.append(0.9 - 0.5 * t)
	_strip(verts, cols, idx, bl, br, ba)
	return _to_mesh(verts, cols, idx)


## Curled petal / leaf along -Z with an upward bend.
static func _m_petal() -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var lefts := []
	var rights := []
	var alphas := []
	for i in 7:
		var t := float(i) / 6.0
		var c := Vector3(0, 0.25 * t * t, -t)
		var hw := 0.5 * pow(sin(PI * clampf(t, 0.0, 1.0)), 0.8)
		lefts.append(c - Vector3(hw, 0, 0))
		rights.append(c + Vector3(hw, 0, 0))
		alphas.append(1.0 - 0.3 * t)
	_strip(verts, cols, idx, lefts, rights, alphas)
	return _to_mesh(verts, cols, idx)


## Wavy tapered tail with the belly near the head (dark wisp).
static func _m_wisp() -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var lefts := []
	var rights := []
	var alphas := []
	var segs := 8
	for i in segs + 1:
		var t := float(i) / float(segs)
		var c := Vector3(0.22 * sin(3.8 * t) * (1.0 - 0.35 * t), 0, -t)
		var hw := 0.2 * sin(PI * pow(t, 1.5))
		lefts.append(c - Vector3(hw, 0, 0))
		rights.append(c + Vector3(hw, 0, 0))
		alphas.append(pow(t, 0.8))
	_strip(verts, cols, idx, lefts, rights, alphas)
	return _to_mesh(verts, cols, idx)


## Outward spiral ribbon in the XZ plane (wind gust).
static func _m_swirl() -> ArrayMesh:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	var lefts := []
	var rights := []
	var alphas := []
	var segs := 12
	for i in segs + 1:
		var t := float(i) / float(segs)
		var a := 1.75 * PI * t
		var r := 0.25 + 0.75 * t
		var radial := Vector3(cos(a), 0, sin(a))
		var hw := 0.1 * sin(PI * pow(t, 0.8))
		lefts.append(radial * (r - hw))
		rights.append(radial * (r + hw))
		alphas.append(t)
	_strip(verts, cols, idx, lefts, rights, alphas)
	return _to_mesh(verts, cols, idx)


static func _hash01(a: int, b: int) -> float:
	var v := sin(float(a) * 12.9898 + float(b) * 78.233) * 43758.5453
	return v - floorf(v)


# ---------------------------------------------------------------- composition helpers
static func _ease(u: float, kind: int) -> float:
	match kind:
		0: return u
		1: return 1.0 - (1.0 - u) * (1.0 - u)
		2: return u * u
		_: return u * u * (3.0 - 2.0 * u)


static func _look(dir: Vector3) -> Basis:
	var d := dir.normalized() if dir.length() > 0.0001 else Vector3(0, 0, -1)
	var up := UP if absf(d.dot(UP)) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(d, up)


## Basis whose local +Y (ring normal) points along n.
static func _normal_basis(n: Vector3) -> Basis:
	return _look(n) * Basis(Vector3.RIGHT, PI * 0.5)


static func _new_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.disable_receive_shadows = true
	return m


static func _add(ctx: Dictionary, key: String, p0: Vector3, basis: Basis, s0: Vector3, s1: Vector3, c0: Color, c1: Color, t0: float, t1: float, o: Dictionary = {}) -> bool:
	var parts: Array = ctx["parts"]
	if parts.size() >= MAX_MESHES:
		return false
	var part := _Part.new()
	part.mat = _new_material()
	part.mi = MeshInstance3D.new()
	part.mi.mesh = _mesh(key)
	part.mi.material_override = part.mat
	part.mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	part.mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	part.mi.visible = false
	part.p0 = p0
	part.p1 = o.get("p1", p0)
	part.basis = basis
	part.s0 = s0
	part.s1 = s1
	part.c0 = c0
	part.c1 = c1
	part.t0 = t0
	part.t1 = minf(t1, CombatFeedback.LIFE_CAP)
	part.axis = o.get("axis", UP)
	part.a0 = o.get("a0", 0.0)
	part.a1 = o.get("a1", 0.0)
	part.ease_kind = o.get("ease", 1)
	part.fade_in = o.get("fi", 0.1)
	part.fade_out = o.get("fo", 0.5)
	parts.append(part)
	return true


static func _room(ctx: Dictionary) -> int:
	return MAX_MESHES - (ctx["parts"] as Array).size()


## Radiating spark streak starting at p, pointing along d.
static func _spark(ctx: Dictionary, p: Vector3, d: Vector3, length: float, width: float, t0: float, t1: float, pal: Dictionary, reach := 0.5) -> void:
	_add(ctx, "streak_x", p, _look(d), Vector3(width, width, length * 0.35), Vector3(width * 0.6, width * 0.6, length), pal["hi"], pal["main"], t0, t1,
		{"p1": p + d.normalized() * reach, "ease": 1, "fi": 0.05, "fo": 0.6})


# ---------------------------------------------------------------- school silhouettes
## Short school-specific silhouettes. mode: "burst" (outward from a hit), "rise" (up and out), "inward" (converge on the anchor).
static func _accent(ctx: Dictionary, f: Dictionary, anchor: Vector3, mode: String, want: int, size: float, t0: float) -> void:
	var school: String = ctx["school"]
	var pal: Dictionary = ctx["pal"]
	var per := 2 if school == "shadow" else 1
	var n := mini(want, _room(ctx) / per)
	if n <= 0:
		return
	var fb: Basis = f["fb"]
	var fwd: Vector3 = f["fwd"]
	var phase: float = float(f["seed"]) * TAU
	for k in n:
		var phi := TAU * float(k) / float(n) + phase
		var radial: Vector3 = fb.x * cos(phi) + fb.y * sin(phi)
		var flat_radial := Vector3(cos(phi), 0.0, sin(phi))
		var d: Vector3
		var p_start := anchor
		var p_end: Vector3
		match mode:
			"rise":
				d = (UP * 0.9 + flat_radial * 0.45).normalized()
				p_start = anchor + flat_radial * 0.15 * size
				p_end = p_start + d * 0.95 * size
			"inward":
				d = -radial
				p_start = anchor + radial * 1.15 * size
				p_end = anchor + radial * 0.15 * size
			_:
				d = (fwd * 0.55 + radial * 0.85).normalized()
				p_start = anchor
				p_end = anchor + d * 0.9 * size
		var tt := t0 + 0.03 * float(k)
		var life_end := tt + 0.34
		match school:
			"frost":
				_add(ctx, "shard", p_start, _look(d), Vector3(0.13, 0.13, 0.2) * size, Vector3(0.16, 0.16, 0.62) * size, pal["hi"], pal["main"], tt, life_end, {"p1": p_end, "fi": 0.05, "fo": 0.5})
			"fire":
				var up_d := (d + UP * 0.9).normalized()
				_add(ctx, "flame", p_start, _look(up_d), Vector3(0.17, 0.17, 0.3) * size, Vector3(0.12, 0.12, 0.58) * size, pal["hi"], pal["main"], tt, life_end + 0.12, {"p1": p_start + up_d * 0.95 * size, "fi": 0.05, "fo": 0.7})
			"lightning":
				var len := 1.05 * size
				var base := _look(d)
				_add(ctx, "bolt:%d" % (k % 4), p_start, base, Vector3.ONE * len * 0.55, Vector3.ONE * len, pal["hi"], pal["main"], tt, tt + 0.16, {"p1": p_start + (d * 0.15 * size if mode != "inward" else d * 0.5 * size), "ease": 1, "fi": 0.04, "fo": 0.55})
			"water":
				if k % 2 == 0:
					var crest := _look(d) * Basis(Vector3(0, 0, 1), deg_to_rad(80.0))
					_add(ctx, "arc:130:9:0.5", p_start, crest, Vector3(0.28, 1.0, 0.28) * size, Vector3(0.62, 1.0, 0.62) * size, pal["hi"], pal["main"], tt, life_end + 0.1, {"p1": p_start + d * 0.2 * size, "fi": 0.08, "fo": 0.6})
				else:
					_add(ctx, "flame", p_start, _look(UP * 0.8 + d * 0.5), Vector3(0.13, 0.13, 0.26) * size, Vector3(0.10, 0.10, 0.34) * size, pal["hi"], pal["main"], tt, life_end + 0.1, {"p1": p_end + UP * 0.2 * size, "fi": 0.08, "fo": 0.55})
			"shadow":
				var wb := _look(d)
				_add(ctx, "wisp", p_start, wb, Vector3(0.62, 1.0, 1.1) * size, Vector3(0.78, 1.0, 1.35) * size, pal["dark"], pal["dark"], tt, life_end + 0.14,
					{"p1": p_end, "axis": Vector3(0, 0, 1), "a0": 0.0, "a1": 1.4 * PI, "fi": 0.1, "fo": 0.5})
				_add(ctx, "wisp", p_start, wb, Vector3(0.3, 1.0, 1.0) * size, Vector3(0.38, 1.0, 1.35) * size, pal["hi"], pal["main"], tt, life_end + 0.14,
					{"p1": p_end, "axis": Vector3(0, 0, 1), "a0": 0.0, "a1": 1.4 * PI, "fi": 0.1, "fo": 0.5})
			"light":
				var pb := _look(d) * Basis(Vector3(0, 0, 1), phi)
				_add(ctx, "petal", p_start, pb, Vector3(0.34, 1.0, 0.3) * size, Vector3(0.38, 1.0, 0.7) * size, pal["hi"], pal["main"], tt, life_end + 0.2, {"p1": p_end, "axis": Vector3(0, 0, 1), "a0": 0.0, "a1": 0.8 * PI, "fi": 0.12, "fo": 0.55})
			"wind":
				_add(ctx, "swirl", p_start, Basis.IDENTITY, Vector3(0.35, 1, 0.35) * size, Vector3(0.8, 1, 0.8) * size * (1.0 + 0.2 * float(k)), pal["hi"], pal["main"], tt, life_end + 0.2, {"p1": p_end * 0.5 + p_start * 0.5 + UP * 0.2 * size, "axis": UP, "a0": 0.0, "a1": TAU * (1.0 if k % 2 == 0 else -1.0), "fi": 0.12, "fo": 0.55})
			"arcane":
				var sig := 6 if k % 2 == 0 else 3
				var fbn := _normal_basis(d if mode != "inward" else fwd)
				_add(ctx, "ring:%d:0.84" % sig, p_start, fbn, Vector3(0.2, 1, 0.2) * size, Vector3(0.55, 1, 0.55) * size, pal["hi"], pal["main"], tt, life_end + 0.12, {"p1": p_end, "axis": UP, "a0": 0.0, "a1": PI * (1.0 if k % 2 == 0 else -1.0), "fi": 0.1, "fo": 0.55})
			_:
				_spark(ctx, p_start, d, 0.5 * size, 0.07 * size, tt, life_end, pal, 0.6 * size)


# ---------------------------------------------------------------- composition per style
static func _compose(style: String, school: String, o: Vector3, t: Vector3, s: float) -> Dictionary:
	var d := t - o
	var dist := d.length()
	var fwd := d / dist if dist > 0.001 else Vector3(0, 0, -1)
	var flat := Vector3(fwd.x, 0.0, fwd.z)
	flat = flat.normalized() if flat.length() > 0.001 else Vector3(0, 0, -1)
	var f := {
		"o": o, "t": t, "s": s, "dist": dist, "fwd": fwd, "flat": flat, "fb": _look(flat),
		"seed": _hash01(int(floorf(o.x * 7.0 + t.x * 3.0)) + school.length(), int(floorf(o.z * 5.0 + t.z * 11.0)) + style.length()),
	}
	var ctx := {"parts": [], "pal": _palette(school, style), "school": school, "life": 0.5}
	match style:
		"slash": _style_slash(ctx, f)
		"heavy": _style_heavy(ctx, f)
		"shield": _style_shield(ctx, f)
		"thrust": _style_thrust(ctx, f)
		"shot": _style_shot(ctx, f)
		"cast": _style_cast(ctx, f)
		"heal": _style_heal(ctx, f)
		"aoe": _style_aoe(ctx, f)
		_: _style_impact(ctx, f)
	return ctx


static func _style_slash(ctx: Dictionary, f: Dictionary) -> void:
	var s: float = f["s"]
	var pal: Dictionary = ctx["pal"]
	var t: Vector3 = f["t"]
	var flat: Vector3 = f["flat"]
	var r := 1.5 * s
	var pivot := t - flat * r * 0.85
	var tilt: Basis = (f["fb"] as Basis) * Basis(Vector3(0, 0, 1), deg_to_rad(-14.0))
	ctx["life"] = 0.4
	_add(ctx, "arc:110:10:0.5", pivot, tilt, Vector3(r, 1, r), Vector3(r, 1, r), pal["hi"], pal["main"], 0.0, 0.3,
		{"axis": UP, "a0": deg_to_rad(-60.0), "a1": deg_to_rad(15.0), "ease": 1, "fi": 0.06, "fo": 0.5})
	_add(ctx, "arc:80:8:0.2", pivot, tilt, Vector3(r * 1.08, 1, r * 1.08), Vector3(r * 1.08, 1, r * 1.08), pal["hi"], pal["hi"], 0.03, 0.3,
		{"axis": UP, "a0": deg_to_rad(-50.0), "a1": deg_to_rad(25.0), "ease": 1, "fi": 0.06, "fo": 0.5})
	var dirs := [Vector3(-0.9, 0.45, -0.25), Vector3(-0.8, -0.35, -0.4), Vector3(-0.5, 0.85, 0.1)]
	for v in dirs:
		_spark(ctx, t, tilt * (v as Vector3).normalized(), 0.6 * s, 0.07 * s, 0.1, 0.32, pal, 0.5 * s)
	_accent(ctx, f, t, "burst", 2, 0.8 * s, 0.1)


static func _style_heavy(ctx: Dictionary, f: Dictionary) -> void:
	var s: float = f["s"]
	var pal: Dictionary = ctx["pal"]
	var t: Vector3 = f["t"]
	var flat: Vector3 = f["flat"]
	var fb: Basis = f["fb"]
	var r := 1.45 * s
	var pivot := t - flat * r * 0.55
	ctx["life"] = 0.62
	for k in 2:
		var tilt := fb * Basis(Vector3(0, 0, 1), deg_to_rad(-62.0 if k == 0 else 62.0))
		_add(ctx, "arc:120:12:0.42", pivot, tilt, Vector3(r, 1, r), Vector3(r, 1, r), pal["hi"], pal["main"], 0.06 * k, 0.46 + 0.06 * k,
			{"axis": UP, "a0": deg_to_rad(-80.0), "a1": deg_to_rad(80.0), "ease": 1, "fi": 0.08, "fo": 0.6})
	_add(ctx, "ring:20:0.8", t, Basis.IDENTITY, Vector3(0.3, 1, 0.3) * s, Vector3(1.7, 1, 1.7) * s, pal["hi"], pal["main"], 0.12, 0.58, {"ease": 1, "fi": 0.05, "fo": 0.7})
	for k in 5:
		var a := TAU * float(k) / 5.0 + 0.4
		var dd: Vector3 = (fb.x * cos(a) + fb.y * sin(a) * 0.5 + (f["fwd"] as Vector3) * 0.3).normalized()
		_spark(ctx, t, dd, 0.7 * s, 0.09 * s, 0.14, 0.45, pal, 0.8 * s)
	_accent(ctx, f, t, "burst", 3, 1.0 * s, 0.14)


static func _style_shield(ctx: Dictionary, f: Dictionary) -> void:
	var s: float = f["s"]
	var pal: Dictionary = ctx["pal"]
	var o: Vector3 = f["o"]
	var t: Vector3 = f["t"]
	var flat: Vector3 = f["flat"]
	var fb: Basis = f["fb"]
	ctx["life"] = 0.5
	var start := o + flat * 0.55
	var stop := t - flat * 0.6
	if (stop - o).dot(flat) < 0.7:
		stop = o + flat * 0.7
	var plate := fb * Basis(UP, deg_to_rad(62.0))
	_add(ctx, "plate", start, plate, Vector3(0.8, 0.9, 1.0) * s, Vector3(1.3, 1.45, 1.0) * s, pal["hi"], pal["main"], 0.0, 0.36,
		{"p1": stop, "ease": 1, "fi": 0.08, "fo": 0.5})
	_add(ctx, "arc:140:10:0.22", stop - flat * 0.1, fb, Vector3(0.5, 1, 0.5) * s, Vector3(1.5, 1, 1.5) * s, pal["hi"], pal["main"], 0.12, 0.48,
		{"ease": 1, "fi": 0.05, "fo": 0.7})
	var dirs := [Vector3(-0.8, 0.5, -0.5), Vector3(0.8, 0.5, -0.5), Vector3(0.0, 0.9, -0.4)]
	for v in dirs:
		_spark(ctx, stop + flat * 0.45, fb * (v as Vector3).normalized(), 0.5 * s, 0.07 * s, 0.14, 0.4, pal, 0.5 * s)
	_accent(ctx, f, t, "burst", 3, 0.8 * s, 0.14)


static func _style_thrust(ctx: Dictionary, f: Dictionary) -> void:
	var s: float = f["s"]
	var pal: Dictionary = ctx["pal"]
	var o: Vector3 = f["o"]
	var t: Vector3 = f["t"]
	var fwd: Vector3 = f["fwd"]
	var fb: Basis = f["fb"]
	var dist: float = f["dist"]
	ctx["life"] = 0.4
	var length := clampf(dist * 0.8 + 0.8, 1.2, 3.5)
	var tail0 := o - fwd * 0.3
	var tail1 := t + fwd * 0.15 - fwd * length
	_add(ctx, "streak_x", tail0, _look(fwd), Vector3(0.11, 0.11, length) * s, Vector3(0.09, 0.09, length) * s, pal["hi"], pal["main"], 0.0, 0.26,
		{"p1": tail1, "ease": 1, "fi": 0.05, "fo": 0.6})
	for side in [-1.0, 1.0]:
		var off: Vector3 = fb.x * side * 0.26 * s
		_add(ctx, "streak_x", tail0 + off, _look(fwd), Vector3(0.05, 0.05, length * 0.6) * s, Vector3(0.04, 0.04, length * 0.6) * s, pal["main"], pal["main"], 0.02, 0.26,
			{"p1": tail1 + off, "ease": 1, "fi": 0.05, "fo": 0.6})
	_add(ctx, "ring:16:0.86", t, _normal_basis(fwd), Vector3(0.15, 1, 0.15) * s, Vector3(0.7, 1, 0.7) * s, pal["hi"], pal["main"], 0.1, 0.38, {"fi": 0.05, "fo": 0.7})
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.8
		var dd: Vector3 = (fb.x * cos(a) + fb.y * sin(a) + fwd * 0.25).normalized()
		_spark(ctx, t, dd, 0.7 * s, 0.09 * s, 0.12, 0.34, pal, 0.7 * s)
	_accent(ctx, f, t, "burst", 2, 0.7 * s, 0.12)


static func _style_shot(ctx: Dictionary, f: Dictionary) -> void:
	var s: float = f["s"]
	var pal: Dictionary = ctx["pal"]
	var o: Vector3 = f["o"]
	var t: Vector3 = f["t"]
	var fwd: Vector3 = f["fwd"]
	var fb: Basis = f["fb"]
	var dist: float = f["dist"]
	ctx["life"] = 0.4
	var travel := clampf(dist / 70.0, 0.05, 0.22)
	var tracer := minf(2.2 * s, maxf(dist, 0.3))
	_add(ctx, "streak_x", o, _look(fwd), Vector3(0.16, 0.16, tracer), Vector3(0.14, 0.14, tracer), pal["hi"], pal["main"], 0.0, travel + 0.08,
		{"p1": t - fwd * tracer, "ease": 0, "fi": 0.04, "fo": 0.3})
	_add(ctx, "streak", o, _look(fwd), Vector3(0.07, 0.07, dist), Vector3(0.07, 0.07, dist), pal["main"], pal["main"], 0.0, travel + 0.2,
		{"ease": 0, "fi": 0.05, "fo": 0.85})
	var muzzle := [[Vector3(0, 0, -1), 1.1], [Vector3(-0.45, 0.0, -1), 0.75], [Vector3(0.45, 0.25, -1), 0.75]]
	var lb := _look(fwd)
	for m in muzzle:
		var md: Vector3 = lb * (m[0] as Vector3).normalized()
		_add(ctx, "streak_x", o + fwd * 0.2, _look(md), Vector3(0.2, 0.2, 0.3), Vector3(0.12, 0.12, float(m[1]) * s), pal["hi"], pal["main"], 0.0, 0.12,
			{"p1": o + fwd * 0.5, "ease": 1, "fi": 0.05, "fo": 0.6})
	_add(ctx, "ring:16:0.84", t, _normal_basis(fwd), Vector3(0.15, 1, 0.15) * s, Vector3(0.75, 1, 0.75) * s, pal["hi"], pal["main"], travel, travel + 0.24, {"fi": 0.05, "fo": 0.7})
	for k in 3:
		var a := TAU * float(k) / 3.0 + 0.5
		var dd: Vector3 = (fb.x * cos(a) + fb.y * sin(a) - fwd * 0.2).normalized()
		_spark(ctx, t, dd, 0.8 * s, 0.1 * s, travel, travel + 0.24, pal, 0.8 * s)
	_accent(ctx, f, t, "burst", 2, 0.7 * s, travel)


static func _style_cast(ctx: Dictionary, f: Dictionary) -> void:
	var s: float = f["s"]
	var pal: Dictionary = ctx["pal"]
	var o: Vector3 = f["o"]
	var flat: Vector3 = f["flat"]
	var fb: Basis = f["fb"]
	ctx["life"] = 0.7
	var center := o + flat * 0.9 * s
	var n := (flat * 0.55 + UP * 0.85).normalized()
	var nb := _normal_basis(n)
	_add(ctx, "ring:6:0.88", center, nb, Vector3(0.3, 1, 0.3) * s, Vector3(0.85, 1, 0.85) * s, pal["hi"], pal["main"], 0.0, 0.62,
		{"axis": UP, "a0": 0.0, "a1": PI * 0.8, "ease": 1, "fi": 0.15, "fo": 0.4})
	_add(ctx, "ring:3:0.86", center, nb, Vector3(0.2, 1, 0.2) * s, Vector3(0.55, 1, 0.55) * s, pal["main"], pal["hi"], 0.05, 0.62,
		{"axis": UP, "a0": 0.0, "a1": -PI * 1.1, "ease": 1, "fi": 0.15, "fo": 0.4})
	var right := nb.x
	var fwd_in := nb.z
	for k in 4:
		var a := TAU * float(k) / 4.0 + 0.4
		var radial := right * cos(a) + fwd_in * sin(a)
		var start := center + radial * 1.15 * s
		_add(ctx, "streak_x", start, _look(-radial), Vector3(0.08, 0.08, 0.5) * s, Vector3(0.05, 0.05, 0.2) * s, pal["main"], pal["hi"], 0.03 * k, 0.5,
			{"p1": center + radial * 0.15 * s, "ease": 2, "fi": 0.15, "fo": 0.3})
	var tip := center + flat * 0.95 * s
	for side in [-1.0, 1.0]:
		var arm: Vector3 = (flat + fb.x * side * 0.55).normalized()
		_add(ctx, "streak_x", tip - arm * 0.45 * s, _look(arm), Vector3(0.07, 0.07, 0.45) * s, Vector3(0.06, 0.06, 0.45) * s, pal["hi"], pal["hi"], 0.2, 0.6,
			{"p1": tip - arm * 0.35 * s + flat * 0.25 * s, "ease": 1, "fi": 0.2, "fo": 0.45})
	_accent(ctx, f, center, "inward", 3, 0.8 * s, 0.05)


static func _style_impact(ctx: Dictionary, f: Dictionary) -> void:
	var s: float = f["s"]
	var pal: Dictionary = ctx["pal"]
	var t: Vector3 = f["t"]
	var fwd: Vector3 = f["fwd"]
	var fb: Basis = f["fb"]
	ctx["life"] = 0.5
	_add(ctx, "ring:18:0.84", t, _normal_basis(fwd), Vector3(0.2, 1, 0.2) * s, Vector3(1.05, 1, 1.05) * s, pal["hi"], pal["main"], 0.0, 0.34, {"fi": 0.04, "fo": 0.7})
	for k in 6:
		var a := TAU * float(k) / 6.0 + 0.3
		var dd: Vector3 = (fb.x * cos(a) + fb.y * sin(a) + fwd * 0.3).normalized()
		var long := 0.8 if k % 2 == 0 else 0.5
		_spark(ctx, t, dd, long * s, 0.08 * s, 0.0, 0.36, pal, 0.85 * s * long)
	_accent(ctx, f, t, "burst", 4, 0.9 * s, 0.04)


static func _style_heal(ctx: Dictionary, f: Dictionary) -> void:
	var s: float = f["s"]
	var pal: Dictionary = ctx["pal"]
	var o: Vector3 = f["o"]
	var t: Vector3 = f["t"]
	var fwd: Vector3 = f["fwd"]
	var dist: float = f["dist"]
	ctx["life"] = 0.8
	_add(ctx, "ring:20:0.9", t + UP * -0.8 * s, Basis.IDENTITY, Vector3(0.55, 1, 0.55) * s, Vector3(0.55, 1, 0.55) * s, pal["main"], pal["hi"], 0.18, 0.78,
		{"p1": t + UP * 0.9 * s, "ease": 3, "fi": 0.2, "fo": 0.5})
	var perp := fwd.cross(UP)
	perp = perp.normalized() if perp.length() > 0.001 else Vector3.RIGHT
	if dist > 0.4:
		for k in 3:
			var off := perp * (float(k) - 1.0) * 0.22 * s
			_add(ctx, "streak_x", o + off, _look(fwd), Vector3(0.07, 0.07, 0.4) * s, Vector3(0.06, 0.06, 0.4) * s, pal["hi"], pal["main"], 0.04 * float(k), 0.3 + 0.04 * float(k),
				{"p1": t + off - fwd * 0.4 * s, "ease": 3, "fi": 0.15, "fo": 0.3})
	_accent(ctx, f, t, "rise", 4, 0.9 * s, 0.22)
	var spark_up := t + UP * 1.0 * s
	_add(ctx, "streak_x", spark_up - UP * 0.1, _look(UP), Vector3(0.05, 0.05, 0.15) * s, Vector3(0.05, 0.05, 0.5) * s, pal["hi"], pal["main"], 0.3, 0.75,
		{"p1": spark_up + UP * 0.3 * s, "fi": 0.2, "fo": 0.5})


static func _style_aoe(ctx: Dictionary, f: Dictionary) -> void:
	var r: float = f["s"]
	var pal: Dictionary = ctx["pal"]
	var o: Vector3 = f["o"]
	var t: Vector3 = f["t"]
	var fwd: Vector3 = f["fwd"]
	var dist: float = f["dist"]
	ctx["life"] = 0.75
	var lob := minf(dist, 14.0)
	if lob > 0.5:
		_add(ctx, "streak_x", o, _look(fwd), Vector3(0.09, 0.09, 0.9), Vector3(0.07, 0.07, 0.9), pal["hi"], pal["main"], 0.0, 0.16,
			{"p1": t - fwd * 0.9, "ease": 0, "fi": 0.05, "fo": 0.4})
	_add(ctx, "ring:24:0.93", t, Basis.IDENTITY, Vector3(0.2, 1, 0.2) * r, Vector3(1.0, 1, 1.0) * r, pal["hi"], pal["main"], 0.12, 0.72, {"ease": 1, "fi": 0.05, "fo": 0.55})
	_add(ctx, "ring:24:0.84", t, Basis.IDENTITY, Vector3(0.15, 1, 0.15) * r, Vector3(0.6, 1, 0.6) * r, pal["main"], pal["hi"], 0.2, 0.66, {"ease": 1, "fi": 0.1, "fo": 0.6})
	# perimeter silhouettes: rise from the ring edge
	var school: String = ctx["school"]
	var per := 2 if school == "shadow" else 1
	var count := mini(6, _room(ctx) / per)
	var size := clampf(0.5 + 0.25 * r, 0.6, 1.4)
	var phase: float = float(f["seed"]) * TAU
	for k in count:
		var phi := TAU * float(k) / float(count) + phase
		var pos := t + Vector3(cos(phi), 0.0, sin(phi)) * r * 0.92
		_accent_at(ctx, float(f["seed"]) + float(k) * 0.137, pos, size, 0.2 + 0.03 * float(k), phi)


## Single rising silhouette at a fixed position (used around the aoe ring).
static func _accent_at(ctx: Dictionary, seed: float, pos: Vector3, size: float, t0: float, phi: float) -> void:
	var school: String = ctx["school"]
	var pal: Dictionary = ctx["pal"]
	var out := Vector3(cos(phi), 0.0, sin(phi))
	var d := (UP * 0.9 + out * 0.35).normalized()
	var end := pos + d * 0.9 * size
	var t1 := t0 + 0.4
	match school:
		"frost":
			_add(ctx, "shard", pos, _look(d), Vector3(0.14, 0.14, 0.25) * size, Vector3(0.17, 0.17, 0.75) * size, pal["hi"], pal["main"], t0, t1, {"p1": pos + d * 0.3 * size, "fi": 0.05, "fo": 0.5})
		"fire":
			_add(ctx, "flame", pos, _look(d), Vector3(0.2, 0.2, 0.3) * size, Vector3(0.14, 0.14, 0.75) * size, pal["hi"], pal["main"], t0, t1 + 0.1, {"p1": pos + d * 0.5 * size, "fi": 0.05, "fo": 0.7})
		"lightning":
			_add(ctx, "bolt:%d" % (int(floorf(seed * 4.0)) % 4), pos, _look(UP), Vector3.ONE * 0.7 * size, Vector3.ONE * 1.25 * size, pal["hi"], pal["main"], t0, t0 + 0.2, {"fi": 0.04, "fo": 0.5})
		"water":
			_add(ctx, "arc:130:9:0.5", pos, _look(out) * Basis(Vector3(0, 0, 1), deg_to_rad(80.0)), Vector3(0.25, 1.0, 0.25) * size, Vector3(0.6, 1.0, 0.6) * size, pal["hi"], pal["main"], t0, t1, {"p1": pos + UP * 0.3 * size, "fi": 0.08, "fo": 0.6})
		"shadow":
			var wb := _look(d)
			_add(ctx, "wisp", pos, wb, Vector3(0.62, 1.0, 1.1) * size, Vector3(0.78, 1.0, 1.35) * size, pal["dark"], pal["dark"], t0, t1 + 0.1, {"p1": end, "axis": Vector3(0, 0, 1), "a0": 0.0, "a1": 1.4 * PI, "fi": 0.1, "fo": 0.5})
			_add(ctx, "wisp", pos, wb, Vector3(0.3, 1.0, 1.0) * size, Vector3(0.38, 1.0, 1.35) * size, pal["hi"], pal["main"], t0, t1 + 0.1, {"p1": end, "axis": Vector3(0, 0, 1), "a0": 0.0, "a1": 1.4 * PI, "fi": 0.1, "fo": 0.5})
		"light":
			_add(ctx, "petal", pos, _look(d) * Basis(Vector3(0, 0, 1), phi), Vector3(0.34, 1.0, 0.3) * size, Vector3(0.4, 1.0, 0.75) * size, pal["hi"], pal["main"], t0, t1 + 0.2, {"p1": end, "axis": Vector3(0, 0, 1), "a0": 0.0, "a1": 0.8 * PI, "fi": 0.12, "fo": 0.55})
		"wind":
			_add(ctx, "swirl", pos, Basis.IDENTITY, Vector3(0.3, 1, 0.3) * size, Vector3(0.75, 1, 0.75) * size, pal["hi"], pal["main"], t0, t1 + 0.1, {"p1": pos + UP * 0.45 * size, "axis": UP, "a0": 0.0, "a1": TAU, "fi": 0.12, "fo": 0.55})
		"arcane":
			_add(ctx, "ring:%d:0.84" % (6 if int(floorf(seed * 10.0)) % 2 == 0 else 3), pos + UP * 0.1, _normal_basis(out), Vector3(0.2, 1, 0.2) * size, Vector3(0.55, 1, 0.55) * size, pal["hi"], pal["main"], t0, t1, {"p1": end, "axis": UP, "a0": 0.0, "a1": PI, "fi": 0.1, "fo": 0.55})
		_:
			_spark(ctx, pos, d, 0.6 * size, 0.08 * size, t0, t1, pal, 0.7 * size)
