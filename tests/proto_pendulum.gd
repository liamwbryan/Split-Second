extends Node3D
## Throwaway prototype (MAP_BRIEFS §5.2): ride a 90 m pendulum, jump off at the
## bottom, and check you stay on the tilting bob at the ends of the swing.

const A := InputRouter.Action
var player: Player
var router: InputRouter
var b: LevelBuilder
var pend: Mover


func _ready() -> void:
	b = LevelBuilder.new(self)
	b.block(Vector3(-200, -1, -200), Vector3(200, 0, 200))
	pend = b.mover(Vector3(0, 100, 0), Mover.Mode.SWING)
	pend.axis = Vector3.RIGHT  # swings along z
	pend.swing_amplitude_deg = 30.0
	pend.period = 10.0
	b.attach_box(pend, Vector3(0, -90.0, 0), Vector3(7, 0.6, 7), LevelBuilder.Tag.BOOST)
	b.finalize()
	var vp := SubViewport.new()
	add_child(vp)
	router = InputRouter.new(PlayerSettings.new())
	router.scripted = true
	router.use_kbm = false
	player = Player.new()
	add_child(player)
	player.setup(0, router, MovementTuning.new(), vp)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# t=0: the bob is at the bottom moving at peak speed. Put the player on it
	# at an extreme instead: wait until the swing's end (t = 2.5 s).
	await get_tree().create_timer(2.45).timeout
	var top := pend.global_transform * Vector3(0, -89.7, 0)
	player.spawn(top + Vector3.UP * 0.1, 0.0)
	var off := false
	var max_tilt := 0.0
	var peak := 0.0
	for i in 600:  # ride a full period
		await get_tree().physics_frame
		var bob := pend.global_transform * Vector3(0, -89.7, 0)
		var local := player.global_position - bob
		if Vector2(local.x, local.z).length() > 4.5 or local.y < -1.0:
			off = true
		max_tilt = maxf(max_tilt, rad_to_deg(pend.global_transform.basis.y.angle_to(Vector3.UP)))
		peak = maxf(peak, (pend.velocity_at(bob)).length())
		if i % 150 == 0:
			print("  i=%d ang_vel=%s lin=%s pos=%s bob=%s" % [i, pend.angular_velocity, pend.linear_velocity, pend.global_position, bob.snappedf(0.1)])
	print("RIDE full period: stayed on=%s  max tilt %.1f°  bob peak %.1f m/s  state %s" % [not off, max_tilt, peak, player.motor.state_name()])
	# Now at the same phase as the start (an extreme). Wait a quarter period
	# (bottom), then jump.
	await get_tree().create_timer(2.5).timeout
	router.scripted_held[A.JUMP] = true
	await get_tree().create_timer(0.05).timeout
	router.scripted_held[A.JUMP] = false
	var launch := 0.0
	var start := player.global_position
	var land := Vector3.ZERO
	for i in 900:
		await get_tree().physics_frame
		launch = maxf(launch, player.horizontal_speed())
		if player.is_on_floor() and i > 30:
			land = player.global_position
			break
	print("JUMP at bottom: top horizontal %.1f m/s, flew %.1f m, landed %s after %.2f s" % [launch, Vector2(land.x - start.x, land.z - start.z).length(), land.snappedf(0.1), 0.0])
	get_tree().quit()
