class_name SanctumFollow
extends RefCounted
## Follow the owner's actual traversed floor path through the layered monastery.
## This is a noncombat follow path; enemy pursuit remains the existing logic.
var trail: Array[Vector3] = []
var last_owner := Vector3.INF

static func walk_supported(ally: Unit, destination: Vector3) -> bool:
	if not ally.is_on_floor():
		return false
	var distance := ally.global_position.distance_to(destination)
	var end := ally.global_position.lerp(destination, minf(1.0, 7.0 / maxf(distance, 0.01)))
	var space := ally.get_world_3d().direct_space_state
	for i in range(1, 7):
		var sample := ally.global_position.lerp(end, i / 6.0)
		var query := PhysicsRayQueryParameters3D.create(sample + Vector3.UP * 0.75, sample - Vector3.UP * 1.0, 1)
		if space.intersect_ray(query).is_empty():
			return false
	return true

func reset() -> void:
	trail.clear()
	last_owner=Vector3.INF

func record(owner: Unit) -> void:
	var current := owner.global_position
	# An actual owner relocation starts a new path. Ordinary walking never
	# snaps the follower to the owner, even if it has fallen far behind.
	if not last_owner.is_finite() or last_owner.distance_to(current)>12:
		trail.clear()
		trail.append(current)
		last_owner=current
	elif current.distance_to(last_owner)>=.75:
		trail.append(current)
		last_owner=current

func target(ally: Unit, owner: Unit) -> Vector3:
	record(owner)
	var current := owner.global_position
	# A companion can advance beside the trail during a fight. Consume the
	# nearest visited sample on the same floor instead of walking backwards
	# to a stale pre-fight point. Keep corners that have not been reached.
	var nearest := -1
	var nearest_distance := 3.0
	for i in trail.size():
		var distance := ally.global_position.distance_to(trail[i])
		if distance < nearest_distance:
			nearest = i
			nearest_distance = distance
	if nearest > 0 and walk_supported(ally, trail[nearest]):
		var sight := PhysicsRayQueryParameters3D.create(ally.chest_pos(), trail[nearest] + Vector3.UP, 1)
		if ally.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
			trail = trail.slice(nearest)
	while trail.size()>1:
		var delta := trail[0]-ally.global_position
		if Vector2(delta.x,delta.z).length()>.35 or absf(delta.y)>.7:break
		trail.pop_front()
	if trail.is_empty():return ally.global_position
	var point := trail[0]
	# Keep a small gap when the owner stops, without trying a diagonal
	# formation position through a wall, across a cut or onto another floor.
	var gap := 2.8 if ally.get("role")=="tank" else 4.3 if ally.get("role")=="healer" else 5.2
	if trail.size()<8 and ally.global_position.distance_to(current)<gap:
		return ally.global_position
	return point
