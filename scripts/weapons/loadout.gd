class_name Loadout
extends Node
## What a player carries: a primary and a secondary gun plus a blade (slots
## 1/2/3), and a knife for quick melee. Switching lowers the current weapon,
## swaps the model and raises the new one (each weapon's draw_time). The guns
## share one HitscanWeapon (each keeps its own ammo); blades go through Melee.
##
## Input (per-player InputRouter): 1/2/3 pick a slot, the mouse wheel or pad Y
## cycles, V / pad R3 is quick melee (a knife slash from a gun, a swing with
## the blade out), and FIRE swings the blade when it's out.

signal switched(slot: int)

const PRIMARY := preload("res://scripts/weapons/rifle.tres")
const SECONDARY := preload("res://scripts/weapons/sniper.tres")
const BLADE := preload("res://scripts/weapons/blade.tres")
const KNIFE := preload("res://scripts/weapons/knife.tres")
const LOWER_TIME := 0.09  ## putting the current weapon away (s)

var player: Player
var gun: HitscanWeapon
var melee: Melee
var viewmodel: Viewmodel
var weapons: Array[WeaponData] = [PRIMARY, SECONDARY, BLADE]
var knife: WeaponData = KNIFE
var current: int = 0            ## slot index into `weapons`

var _pending: int = -1          ## slot being switched to
var _lower: float = 0.0         ## 0 up .. 1 down
var _raising: bool = false
var _quick: bool = false        ## a quick melee borrowed the viewmodel


func setup(p_player: Player, p_gun: HitscanWeapon, p_melee: Melee) -> void:
	player = p_player
	gun = p_gun
	melee = p_melee
	viewmodel = gun.viewmodel
	melee.finished.connect(_on_melee_finished)
	var trail := SlashTrail.new()
	player.camera_rig.camera.add_child(trail)
	trail.setup(viewmodel, player.camera_rig.viewmodel_layer_bit(), RunnerAvatar.PLAYER_COLORS[player.player_index % RunnerAvatar.PLAYER_COLORS.size()])
	viewmodel.trail = trail
	# Build every model now, so the first switch mid-fight doesn't hitch.
	for w: WeaponData in weapons + [knife]:
		viewmodel.set_weapon(w)
	_apply(current, true)


func current_data() -> WeaponData:
	return weapons[current]


func holding_blade() -> bool:
	return current_data().kind == WeaponData.Kind.MELEE


func switching() -> bool:
	return _pending >= 0 or _raising


## Back to the primary, weapon up, full ammo (respawn).
func reset() -> void:
	melee.cancel()
	_quick = false
	_pending = -1
	_raising = false
	_lower = 0.0
	viewmodel.lower = 0.0
	_apply(0, true)
	gun.refill()


## Switch to a slot (animated). Ignored if already there.
func select(slot: int) -> void:
	slot = clampi(slot, 0, weapons.size() - 1)
	if slot == current and _pending < 0:
		return
	if melee.busy:
		melee.cancel()
		_quick = false
	_pending = slot
	_raising = false
	gun.active = false
	Sfx.play(&"swap", -12.0, 0.05)


func physics_step(delta: float) -> void:
	var r := player.router
	if r.just_pressed(InputRouter.Action.SLOT1):
		select(0)
	elif r.just_pressed(InputRouter.Action.SLOT2):
		select(1)
	elif r.just_pressed(InputRouter.Action.SLOT3):
		select(2)
	elif r.just_pressed(InputRouter.Action.SWAP):
		select(wrapi((_pending if _pending >= 0 else current) + 1, 0, weapons.size()))
	elif r.just_pressed(InputRouter.Action.SWAP_PREV):
		select(wrapi((_pending if _pending >= 0 else current) - 1, 0, weapons.size()))

	# Switch animation: lower, swap the model at the bottom, raise.
	if _pending >= 0:
		_lower = minf(1.0, _lower + delta / LOWER_TIME)
		if _lower >= 1.0:
			_apply(_pending, false)
			_pending = -1
			_raising = true
	elif _raising:
		_lower = maxf(0.0, _lower - delta / current_data().draw_time)
		if _lower <= 0.0:
			_raising = false
			gun.active = not holding_blade() and not _quick
	viewmodel.lower = _lower

	# Melee: V / R3 from anything; FIRE with the blade out.
	var ready := not switching()
	if ready and r.just_pressed(InputRouter.Action.MELEE):
		_start_melee()
	elif ready and holding_blade() and r.just_pressed(InputRouter.Action.FIRE):
		_start_melee()
	melee.preview_data = current_data() if holding_blade() else knife
	gun.physics_step(delta)
	melee.physics_step(delta)


func _start_melee() -> void:
	if holding_blade():
		melee.swing(current_data(), false)
		return
	if melee.busy:
		melee.swing(knife, true)  # queues the next slash of the combo
		return
	# Quick melee from a gun: the knife comes up from below for one slash.
	_quick = true
	gun.active = false
	viewmodel.set_weapon(knife)
	melee.swing(knife, true)


func _on_melee_finished() -> void:
	if not _quick:
		return
	# Back to the gun: it rises in (a bit faster than a full draw).
	_quick = false
	viewmodel.set_weapon(current_data())
	_lower = 0.6
	_raising = true


func _apply(slot: int, instant: bool) -> void:
	current = slot
	var d := current_data()
	if d.kind == WeaponData.Kind.HITSCAN:
		gun.set_data(d)
	viewmodel.set_weapon(d)
	gun.active = instant and d.kind == WeaponData.Kind.HITSCAN
	switched.emit(slot)
