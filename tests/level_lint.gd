extends SceneTree
## Level lint: loads the gym and checks placement rules that are easy to
## break when editing layouts. Exit code = number of failures.
##   godot --headless --path . -s res://tests/level_lint.gd

var failures := 0


const LEVELS := ["res://scenes/gym.tscn", "res://scenes/rooftops.tscn", "res://scenes/spiral.tscn"]


func _initialize() -> void:
	for path in LEVELS:
		await _lint(path)
	quit(failures)


func _lint(path: String) -> void:
	var gym: Node = load(path).instantiate()
	root.add_child(gym)
	for i in 6:
		await physics_frame
	var space: PhysicsDirectSpaceState3D = gym.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.6
	q.shape = cap
	q.collision_mask = 1
	var count := 0
	for d in gym.get_children():
		if not (d is TargetDummy):
			continue
		count += 1
		var dummy: TargetDummy = d
		var home: Vector3 = dummy._origin
		for k in 21:
			var p: Vector3 = home + dummy.move_axis * (-1.0 + k * 0.1)
			q.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.0)
			if not space.intersect_shape(q, 1).is_empty():
				_fail("%s: dummy at %s overlaps geometry along its path (t=%.1f)" % [path.get_file(), home, -1.0 + k * 0.1])
				break
		var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(home + Vector3.UP * 0.3, home + Vector3.DOWN * 0.5, 1))
		if ground.is_empty():
			_fail("%s: dummy at %s is floating (no ground within 0.5 m)" % [path.get_file(), home])
	if count == 0:
		_fail("no dummies found (placement broken?)")
	for s in gym.stations:
		var pos: Vector3 = s[1]
		q.transform = Transform3D(Basis.IDENTITY, pos + Vector3.UP * 1.0)
		if not space.intersect_shape(q, 1).is_empty():
			_fail("%s: station '%s' spawns inside geometry" % [path.get_file(), s[0]])
	# Arena spawns (M3): not inside geometry, with a floor under them.
	for sp in gym.get("arena_spawns"):
		var sp_pos: Vector3 = sp[0]
		q.transform = Transform3D(Basis.IDENTITY, sp_pos + Vector3.UP * 1.0)
		if not space.intersect_shape(q, 1).is_empty():
			_fail("%s: arena spawn %s is inside geometry" % [path.get_file(), sp_pos])
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(sp_pos + Vector3.UP * 0.3, sp_pos + Vector3.DOWN * 0.5, 1)).is_empty():
			_fail("%s: arena spawn %s has no floor under it" % [path.get_file(), sp_pos])
	# Course gates: the base sits on a walkable surface and a player fits inside.
	var course = gym.get("course")  # untyped: this script compiles before autoloads exist
	if course:
		var all: Array = [course.start]
		all.append_array(course.gates)
		all.append(course.finish)
		for g in all:
			q.transform = Transform3D(Basis.IDENTITY, g.position + Vector3.UP * 1.0)
			if not space.intersect_shape(q, 1).is_empty():
				_fail("%s: course gate '%s' overlaps geometry" % [path.get_file(), g.name])
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(g.position + Vector3.UP * 0.3, g.position + Vector3.DOWN * 0.5, 1))
			if floor_hit.is_empty():
				_fail("%s: course gate '%s' has no floor under it" % [path.get_file(), g.name])
	print("level lint %s: %d dummies, %d stations, %d failures so far" % [path.get_file(), count, gym.stations.size(), failures])
	gym.queue_free()
	await process_frame


func _fail(msg: String) -> void:
	failures += 1
	print("  FAIL ", msg)
