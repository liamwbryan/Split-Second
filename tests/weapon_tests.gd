extends Node3D
## Headless weapon tests (M2): slots and switching, the rail sniper's zoom,
## damage and spread, blade melee in and out of range, the lunge, and quick
## melee from a gun. A real Player with scripted input against dummies.
##
## Run: godot --headless --path . --fixed-fps 120 res://tests/weapon_tests.tscn

const A := InputRouter.Action

var player: Player
var router: InputRouter
var b: LevelBuilder
var failures: PackedStringArray = []
var passes: int = 0
var only: String = ""
var dummies: Dictionary = {}


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.substr(7)
	b = LevelBuilder.new(self)
	_build()
	var vp := SubViewport.new()
	add_child(vp)
	router = InputRouter.new(PlayerSettings.new())
	router.scripted = true
	router.use_kbm = false
	player = Player.new()
	add_child(player)
	player.setup(0, router, MovementTuning.new(), vp)
	for t in ["switch_slots", "ammo_kept_per_gun", "sniper_zoom_and_damage", "sniper_long_shot", "sniper_hip_vs_ads",
			"melee_hits_in_range", "melee_misses_out_of_range", "lunge_closes_distance", "no_lunge_without_target",
			"quick_melee_from_gun", "slide_melee_stronger", "combo_chains"]:
		if only == "" or t == only:
			await call("test_" + t)
	print("\n%d passed, %d failed" % [passes, failures.size()])
	for f in failures:
		print("  FAIL ", f)
	get_tree().quit(failures.size())


# Each lane has its own x so tests never share a dummy.
func _build() -> void:
	b.block(Vector3(-50, -1, -200), Vector3(1400, 0, 50))
	dummies["sniper"] = _dummy(Vector3(100, 0, -30))
	dummies["far"] = _dummy(Vector3(150, 0, -75))
	dummies["near"] = _dummy(Vector3(200, 0, -2.2))
	dummies["out"] = _dummy(Vector3(300, 0, -12))
	dummies["lunge"] = _dummy(Vector3(400, 0, -6))
	dummies["quick"] = _dummy(Vector3(600, 0, -2.2))
	dummies["slide"] = _dummy(Vector3(700, 0, -16))
	dummies["combo"] = _dummy(Vector3(800, 0, -2.2), 1000.0)


func _dummy(pos: Vector3, health: float = 100.0) -> TargetDummy:
	var d := TargetDummy.new()
	d.max_health = health
	d.position = pos
	add_child(d)
	return d


# --------------------------------------------------------------------------- helpers

func reset(pos: Vector3, yaw: float = 0.0) -> void:
	for i in InputRouter.ACTION_COUNT:
		router.scripted_held[i] = false
	router.scripted_move = Vector2.ZERO
	player.spawn(pos + Vector3.UP * 0.05, yaw)
	await ticks(6)


func ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func seconds(s: float) -> void:
	await ticks(int(s * 120.0))


func tap(action: int) -> void:
	router.scripted_held[action] = true
	await ticks(2)
	router.scripted_held[action] = false


func aim_at(p: Vector3) -> void:
	var to := p - player.eye_position()
	player.yaw = atan2(-to.x, -to.z)
	player.pitch = atan2(to.y, Vector2(to.x, to.z).length())


func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		passes += 1
		print("  ok   ", name)
	else:
		failures.append("%s  %s" % [name, detail])
		print("  FAIL ", name, "  ", detail)


func lo() -> Loadout:
	return player.loadout


func equip(slot: int) -> void:
	await tap([A.SLOT1, A.SLOT2, A.SLOT3][slot])
	await seconds(0.5)


func hdist(a: Vector3, c: Vector3) -> float:
	return Vector2(a.x - c.x, a.z - c.z).length()


# --------------------------------------------------------------------------- tests

func test_switch_slots() -> void:
	await reset(Vector3(0, 0, 0))
	check("spawn holds the primary", lo().current == 0 and player.weapon.active and player.weapon.data == Loadout.PRIMARY)
	await tap(A.SLOT2)
	await ticks(3)
	check("switching: gun off while lowering", not player.weapon.active and lo().switching())
	await seconds(0.5)
	check("slot 2 = rail sniper, ready", lo().current == 1 and player.weapon.data == Loadout.SECONDARY and player.weapon.active and player.weapon.viewmodel.lower == 0.0)
	await equip(2)
	check("slot 3 = blade (gun off)", lo().holding_blade() and not player.weapon.active and player.weapon.viewmodel.is_blade())
	await tap(A.SWAP)
	await seconds(0.5)
	check("next weapon wraps to slot 1", lo().current == 0 and player.weapon.active)
	await tap(A.SWAP_PREV)
	await seconds(0.5)
	check("previous weapon wraps to slot 3", lo().current == 2)
	await reset(Vector3(0, 0, 0))
	check("respawn resets to the primary", lo().current == 0 and player.weapon.active)


func test_ammo_kept_per_gun() -> void:
	await reset(Vector3(0, 0, 0))
	await tap(A.FIRE)
	await ticks(4)
	var rifle_ammo := player.weapon.ammo
	await equip(1)
	var sniper_ammo := player.weapon.ammo
	await equip(0)
	check("each gun keeps its own ammo", rifle_ammo == Loadout.PRIMARY.magazine - 1 and sniper_ammo == Loadout.SECONDARY.magazine and player.weapon.ammo == rifle_ammo,
		"rifle %d sniper %d back %d" % [rifle_ammo, sniper_ammo, player.weapon.ammo])


func test_sniper_zoom_and_damage() -> void:
	var d: TargetDummy = dummies["sniper"]
	await reset(Vector3(100, 0, 0))
	await equip(1)
	aim_at(d.aim_point())
	router.scripted_held[A.ADS] = true
	await seconds(0.5)
	var rig := player.camera_rig
	check("scope zooms the view", absf(rig.ads_fov_mult - Loadout.SECONDARY.ads_fov_mult) < 0.01, "fov mult %.2f" % rig.ads_fov_mult)
	check("scoped in: gun and arms hidden", player.weapon.viewmodel.scoped_in and not rig.fp_body.visible)
	check("scope slows the look", absf(player.weapon.look_scale() - Loadout.SECONDARY.ads_sens_mult) < 0.01, "scale %.2f" % player.weapon.look_scale())
	var before := d.health
	aim_at(d.aim_point())
	await tap(A.FIRE)
	await ticks(3)
	check("one body shot does heavy damage", before - d.health >= 90.0, "damage %.1f" % (before - d.health))
	router.scripted_held[A.ADS] = false
	await tap(A.FIRE)
	await ticks(3)
	check("bolt cadence: no second shot right away", player.weapon.ammo == Loadout.SECONDARY.magazine - 1, "ammo %d" % player.weapon.ammo)


func test_sniper_long_shot() -> void:
	var d: TargetDummy = dummies["far"]
	await reset(Vector3(150, 0, 0))
	await equip(1)
	var got := []
	var on_detail := func(is_head: bool, killed: bool, dist: float, long_shot: bool) -> void:
		got.append([is_head, killed, dist, long_shot])
	player.weapon.hit_detail.connect(on_detail)
	router.scripted_held[A.ADS] = true
	await seconds(0.5)
	aim_at(d.global_position + Vector3.UP * 1.72)  # head
	await tap(A.FIRE)
	await ticks(3)
	router.scripted_held[A.ADS] = false
	player.weapon.hit_detail.disconnect(on_detail)
	check("scoped headshot at 75 m kills and counts as a long shot", got.size() == 1 and got[0][0] and got[0][1] and got[0][3], str(got))


func test_sniper_hip_vs_ads() -> void:
	await reset(Vector3(100, 0, 20))
	await equip(1)
	var hip := player.weapon.current_spread()
	router.scripted_held[A.ADS] = true
	await seconds(0.5)
	var ads := player.weapon.current_spread()
	router.scripted_held[A.ADS] = false
	await seconds(0.3)
	await tap(A.JUMP)
	await ticks(10)
	var air := player.weapon.current_spread()
	check("sniper: sharp scoped, wild from the hip, wilder in the air", ads < 0.05 and hip > 3.0 and air > hip + 3.0,
		"ads %.2f hip %.2f air %.2f" % [ads, hip, air])


func test_melee_hits_in_range() -> void:
	var d: TargetDummy = dummies["near"]
	await reset(Vector3(200, 0, 0))
	await equip(2)
	aim_at(d.aim_point())
	var before := d.health
	await tap(A.FIRE)
	var stop := 0.0
	for i in 54:
		await ticks(1)
		stop = maxf(stop, player.melee.hitstop_left)
	check("blade hits a dummy in reach", before - d.health >= Loadout.BLADE.melee_damage - 0.1, "damage %.1f" % (before - d.health))
	check("a hit triggers hit-stop", stop > 0.0, "max hitstop %.3f" % stop)


func test_melee_misses_out_of_range() -> void:
	var d: TargetDummy = dummies["out"]
	await reset(Vector3(300, 0, 0))
	await equip(2)
	aim_at(d.aim_point())
	var start := player.global_position
	var lunged := false
	await tap(A.FIRE)
	for i in 60:
		await ticks(1)
		lunged = lunged or player.motor.state == PlayerMotor.State.LUNGE
	check("blade out of reach (12 m): no damage, no lunge", d.health == d.max_health and not lunged and hdist(player.global_position, start) < 0.5,
		"health %.1f lunged %s moved %.2f" % [d.health, lunged, hdist(player.global_position, start)])


func test_lunge_closes_distance() -> void:
	var d: TargetDummy = dummies["lunge"]
	await reset(Vector3(400, 0, 0))
	await equip(2)
	aim_at(d.aim_point())
	await tap(A.FIRE)
	var lunged := false
	var closest := INF
	for i in 90:
		await ticks(1)
		lunged = lunged or player.motor.state == PlayerMotor.State.LUNGE
		closest = minf(closest, hdist(player.global_position, d.global_position))
	check("lunge dashes to a target 6 m away", lunged)
	check("lunge stops short (never passes through)", closest > 0.9 and closest < Loadout.BLADE.lunge_stop_distance + 0.5, "closest %.2f" % closest)
	check("lunge strike lands", d.health < d.max_health, "health %.1f" % d.health)


func test_no_lunge_without_target() -> void:
	await reset(Vector3(400, 0, 0), PI)  # facing away from the dummy
	await equip(2)
	var lunged := false
	await tap(A.FIRE)
	for i in 60:
		await ticks(1)
		lunged = lunged or player.motor.state == PlayerMotor.State.LUNGE
	check("no lunge with nothing in front", not lunged)


func test_quick_melee_from_gun() -> void:
	var d: TargetDummy = dummies["quick"]
	await reset(Vector3(600, 0, 0))
	aim_at(d.aim_point())
	var before := d.health
	await tap(A.MELEE)
	await ticks(4)
	check("quick melee: knife out, gun off", player.weapon.viewmodel.data == Loadout.KNIFE and not player.weapon.active)
	await seconds(0.8)
	check("quick melee hits", before - d.health >= Loadout.KNIFE.melee_damage - 0.1, "damage %.1f" % (before - d.health))
	check("gun back up after quick melee", player.weapon.viewmodel.data == Loadout.PRIMARY and player.weapon.active and lo().current == 0)


func test_slide_melee_stronger() -> void:
	var d: TargetDummy = dummies["slide"]
	await reset(Vector3(700, 0, 0))
	await equip(2)
	aim_at(d.aim_point())
	router.scripted_held[A.SPRINT] = true
	router.scripted_move = Vector2(0, 1)
	await seconds(0.7)
	router.scripted_held[A.CROUCH] = true
	await ticks(6)
	var sliding := player.motor.state == PlayerMotor.State.SLIDE
	aim_at(d.aim_point())
	var got := []
	var on_hit := func(killed: bool, dmg: float, style: StringName) -> void:
		got.append([killed, dmg, style])
	player.melee.hit_landed.connect(on_hit)
	await tap(A.FIRE)
	await seconds(0.6)
	player.melee.hit_landed.disconnect(on_hit)
	router.scripted_held[A.CROUCH] = false
	router.scripted_held[A.SPRINT] = false
	router.scripted_move = Vector2.ZERO
	check("slide melee hits harder (one-shots a dummy)", sliding and got.size() == 1 and got[0][2] == &"slide" and got[0][0],
		"sliding %s hits %s" % [sliding, str(got)])


func test_combo_chains() -> void:
	var d: TargetDummy = dummies["combo"]
	await reset(Vector3(800, 0, 0))
	await equip(2)
	aim_at(d.aim_point())
	var dmg := []
	var on_hit := func(_killed: bool, amount: float, _style: StringName) -> void:
		dmg.append(amount)
	player.melee.hit_landed.connect(on_hit)
	for i in 3:
		await tap(A.FIRE)
		await seconds(Loadout.BLADE.swing_time + 0.08)
	player.melee.hit_landed.disconnect(on_hit)
	var ok: bool = dmg.size() == 3 and dmg[2] > dmg[0] * 1.4
	check("three presses chain a combo with a finisher", ok, str(dmg))
