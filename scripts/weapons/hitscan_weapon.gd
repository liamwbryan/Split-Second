class_name HitscanWeapon
extends Node
## Hitscan gun logic: fire rate, magazine, ADS, patterned recoil,
## movement-aware spread, damage falloff, hit confirmation.

signal fired
signal hit_confirmed(is_head: bool, killed: bool)
signal ammo_changed(ammo: int, magazine: int)

const HITBOX_MASK := 1 | (1 << 2)  # world + hitbox

var data: WeaponData
var player: Player
var rig: CameraRig
var viewmodel: Viewmodel

var ammo: int = 0
var reloading: bool = false
var reload_left: float = 0.0
var ads_t: float = 0.0
var bloom: float = 0.0

var _cooldown: float = 0.0
var _shot_index: int = 0
var _since_shot: float = 10.0
var _rng := RandomNumberGenerator.new()
var _ray := PhysicsRayQueryParameters3D.new()


func setup(p_player: Player, p_rig: CameraRig, p_data: WeaponData) -> void:
	player = p_player
	rig = p_rig
	data = p_data
	ammo = data.magazine
	_ray.collision_mask = HITBOX_MASK
	_ray.exclude = [player.get_rid()]
	_ray.collide_with_areas = false
	viewmodel = Viewmodel.new()
	rig.camera.add_child(viewmodel)
	viewmodel.setup(player, rig.viewmodel_layer_bit())


func physics_step(delta: float) -> void:
	var router := player.router
	_cooldown = maxf(-1.0 / 120.0, _cooldown - delta)
	_since_shot += delta
	bloom = maxf(0.0, bloom - data.bloom_recover * delta)
	if _since_shot > 0.3:
		_shot_index = 0

	var want_ads := router.is_held(InputRouter.Action.ADS) and not reloading
	ads_t = move_toward(ads_t, 1.0 if want_ads else 0.0, delta / data.ads_time)
	var e := ads_t * ads_t * (3.0 - 2.0 * ads_t)
	rig.ads_fov_mult = lerpf(1.0, data.ads_fov_mult, e)
	viewmodel.ads_amount = ads_t

	if reloading:
		reload_left -= delta
		if reload_left <= 0.0:
			reloading = false
			ammo = data.magazine
			ammo_changed.emit(ammo, data.magazine)
	elif router.just_pressed(InputRouter.Action.RELOAD) and ammo < data.magazine:
		_start_reload()

	var trigger := router.is_held(InputRouter.Action.FIRE) if data.automatic else router.just_pressed(InputRouter.Action.FIRE)
	if trigger and _cooldown <= 0.0 and not reloading:
		if ammo > 0:
			_fire()
		else:
			_start_reload()


func current_spread() -> float:
	var motor := player.motor
	var hip := data.hip_spread
	var speed_f := clampf(player.horizontal_speed() / player.tuning.sprint_speed, 0.0, 1.0)
	hip += data.move_spread * speed_f
	if motor.state == PlayerMotor.State.AIR or motor.state == PlayerMotor.State.GRAPPLE:
		hip += data.air_spread
	if motor.state == PlayerMotor.State.SLIDE or motor.state == PlayerMotor.State.WALLRUN:
		hip *= data.parkour_spread_mult
	var base := lerpf(hip, data.ads_spread, ads_t)
	return base + bloom


func _start_reload() -> void:
	if reloading:
		return
	reloading = true
	reload_left = data.reload_time
	Sfx.play(&"reload", -6.0)


func _fire() -> void:
	ammo -= 1
	_cooldown += 60.0 / data.rpm
	_since_shot = 0.0
	ammo_changed.emit(ammo, data.magazine)

	var cam := rig.camera
	var origin := cam.global_position
	var spread := deg_to_rad(current_spread())
	# Uniform in a cone (sqrt keeps it from clumping in the center).
	var r := spread * sqrt(_rng.randf())
	var a := _rng.randf() * TAU
	var local_dir := Vector3(sin(r) * cos(a), sin(r) * sin(a), -cos(r))
	var dir := (cam.global_basis * local_dir).normalized()

	_ray.from = origin
	_ray.to = origin + dir * data.max_range
	var hit := player.get_world_3d().direct_space_state.intersect_ray(_ray)
	var end := _ray.to
	if not hit.is_empty():
		end = hit.position
		var dist := origin.distance_to(end)
		var collider: Object = hit.collider
		if collider and collider.has_meta(&"hit_owner"):
			var target: Node = collider.get_meta(&"hit_owner")
			var is_head: bool = collider.get_meta(&"is_head", false)
			var dmg := data.damage * _falloff(dist) * (data.headshot_mult if is_head else 1.0)
			var killed: bool = target.take_hit(dmg, end, dir, player)
			hit_confirmed.emit(is_head, killed)
			Fx.impact(end, hit.normal, true)
		else:
			Fx.impact(end, hit.normal, false)
	Fx.tracer(viewmodel.muzzle.global_position, end)

	# Patterned recoil moves your aim (learnable); the punch is visual only.
	var pattern := data.recoil_pattern
	if pattern.size() > 0:
		var idx := _shot_index
		if idx >= pattern.size():
			var loop_len := maxi(1, pattern.size() - data.recoil_loop_from)
			idx = data.recoil_loop_from + (idx - data.recoil_loop_from) % loop_len
		var kick := pattern[idx] * lerpf(1.0, data.ads_recoil_mult, ads_t)
		player.pitch = clampf(player.pitch + deg_to_rad(kick.x), deg_to_rad(-88.0), deg_to_rad(88.0))
		player.yaw -= deg_to_rad(kick.y)
	_shot_index += 1
	bloom = minf(data.bloom_max, bloom + data.bloom_per_shot)
	rig.punch(deg_to_rad(0.35) * data.visual_punch, deg_to_rad(_rng.randf_range(-0.12, 0.12)) * data.visual_punch)
	rig.add_trauma(0.12)
	viewmodel.kick(1.0 - ads_t * 0.5)
	Sfx.play(&"shot", -4.0, 0.06)
	fired.emit()


func _falloff(dist: float) -> float:
	if dist <= data.falloff_near:
		return 1.0
	if dist >= data.falloff_far:
		return data.falloff_min_mult
	return lerpf(1.0, data.falloff_min_mult, (dist - data.falloff_near) / (data.falloff_far - data.falloff_near))
