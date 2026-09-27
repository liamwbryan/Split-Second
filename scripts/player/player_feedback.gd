class_name PlayerFeedback
extends Node
## Audio feedback for movement and shooting. Kept out of the motor so the
## motor stays pure simulation (and testable headless).

const WIND_MAX_DB := -17.0
const WIND_MIN_SPEED := 9.0    ## m/s where air starts to be audible
const WIND_FULL_SPEED := 26.0  ## m/s for full volume
const WIND_ATTACK := 1.6       ## level per second rising
const WIND_RELEASE := 1.0      ## level per second falling

var player: Player
var _wind: AudioStreamPlayer
var _wind_level: float = 0.0
var _wind_t: float = 0.0
var _step_dist: float = 0.0


func attach(p_player: Player) -> void:
	player = p_player
	name = "Feedback"
	player.add_child(self)
	var m := player.motor
	m.jumped.connect(_on_jumped)
	m.landed.connect(func(impact: float) -> void:
		if impact > 4.0:
			Sfx.play(&"land", linear_to_db(clampf(impact / 18.0, 0.25, 1.0)), 0.08))
	m.slide_started.connect(func() -> void: Sfx.play(&"slide", -4.0, 0.1))
	m.mantled.connect(func(vault: bool) -> void: Sfx.play(&"mantle", -6.0 if vault else -3.0, 0.1))
	m.grapple_attached.connect(func(_p: Vector3) -> void:
		Sfx.play(&"grapple_fire", -4.0, 0.05)
		Sfx.play(&"grapple_attach", -6.0, 0.05))
	m.grapple_released.connect(func() -> void: Sfx.play(&"grapple_release", -10.0, 0.05))
	m.grapple_missed.connect(func() -> void: Sfx.play(&"denied", -8.0))
	# Momentum (prototype): each chained move chimes a little higher, and a
	# boost gets a whoosh on top of the move's own sound.
	m.momentum_linked.connect(func(flow: float) -> void:
		if player.tuning.momentum_link_sound_db > -39.0:
			Sfx.play(&"grapple_release", player.tuning.momentum_link_sound_db, 0.0, 0.85 + flow * 0.6))
	m.momentum_boosted.connect(func(amount: float) -> void:
		Sfx.play(&"double_jump", linear_to_db(clampf(amount / 4.0, 0.35, 1.0)) - 4.0, 0.05, 1.3))
	m.state_changed.connect(func(_from: int, to: int) -> void:
		if to == PlayerMotor.State.WALLRUN or to == PlayerMotor.State.WALLCLIMB:
			Sfx.play(&"step", -4.0, 0.15))
	player.weapon.hit_confirmed.connect(func(is_head: bool, killed: bool) -> void:
		if killed:
			Sfx.play(&"kill", -2.0)
		elif is_head:
			Sfx.play(&"head", -4.0, 0.03)
		else:
			Sfx.play(&"hit", -6.0, 0.05))
	player.weapon.hit_detail.connect(func(is_head: bool, killed: bool, _distance: float, long_shot: bool) -> void:
		if (long_shot and (is_head or killed)) or (player.weapon.data.scoped and is_head):
			Sfx.play(&"long_shot", -6.0, 0.0, 1.0 if is_head else 0.85))
	_wind = Sfx.make_loop(&"wind", self, Sfx.WIND_BUS)


func _on_jumped(kind: int) -> void:
	match kind:
		PlayerMotor.JumpKind.DOUBLE:
			Sfx.play(&"double_jump", -5.0, 0.08)
		PlayerMotor.JumpKind.WALL_KICK, PlayerMotor.JumpKind.CLIMB_KICK:
			Sfx.play(&"kick", -4.0, 0.08)
		_:
			Sfx.play(&"jump", -8.0, 0.1)


func _physics_process(delta: float) -> void:
	var speed := player.horizontal_speed()
	var state := player.motor.state
	# Footsteps on the ground and on walls, spaced by distance travelled.
	if state == PlayerMotor.State.GROUND or state == PlayerMotor.State.WALLRUN:
		_step_dist += speed * delta
		var stride := 2.1 if state == PlayerMotor.State.GROUND else 1.7
		if _step_dist > stride:
			_step_dist = 0.0
			Sfx.play(&"step", -14.0 + minf(speed, 12.0) * 0.4, 0.2)
	else:
		_step_dist = 0.0
	_update_wind(delta, state)


## Air rush only where it's natural: flying, grappling, wall-running, sliding.
## Never while running on the ground. Eased in/out, with slow gusts.
func _update_wind(delta: float, state: int) -> void:
	var weight := 0.0
	match state:
		PlayerMotor.State.AIR, PlayerMotor.State.GRAPPLE:
			weight = 1.0
		PlayerMotor.State.WALLRUN:
			weight = 0.8
		PlayerMotor.State.SLIDE:
			weight = 0.55
	var speed := player.velocity.length()
	var target := weight * smoothstep(WIND_MIN_SPEED, WIND_FULL_SPEED, speed)
	target = minf(1.0, target + weight * player.motor.flow * 0.2)  # a full momentum meter roars a bit more
	var rate := WIND_ATTACK if target > _wind_level else WIND_RELEASE
	_wind_level = move_toward(_wind_level, target, rate * delta)
	_wind_t += delta
	var gust := 0.82 + 0.18 * sin(_wind_t * 0.63) * sin(_wind_t * 1.71 + 1.3)
	var level := _wind_level * gust
	_wind.volume_db = linear_to_db(maxf(level, 0.0001)) + WIND_MAX_DB
	_wind.pitch_scale = 0.92 + _wind_level * 0.18
	Sfx.set_wind_cutoff(lerpf(350.0, 2400.0, _wind_level))
