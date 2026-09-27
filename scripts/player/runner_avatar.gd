class_name RunnerAvatar
extends Node3D
## A player's third-person body: a stealth agent. The Quaternius UAL mannequin
## in a matte black suit, with Blender-made tri-lens goggles, belt, holster,
## grapple bracer and spine unit (art/blender/runner_gear.py). Player color
## only shows on the lenses and small status lights. It's
## animated from the movement state. Other players see it; its owner doesn't
## (per-player render layer). It stops animating when nobody can see it.

const BODY := preload("res://assets/characters/UAL1_Standard.glb")
const MORE_ANIMS := preload("res://assets/characters/UAL2_Standard.glb")
## [scene, bone] pairs; each gear piece is authored in rest-pose model space.
const GEAR := [
	[preload("res://assets/models/agent_goggles.glb"), &"Head"],
	[preload("res://assets/models/agent_belt.glb"), &"pelvis"],
	[preload("res://assets/models/agent_holster.glb"), &"thigh_r"],
	[preload("res://assets/models/agent_bracer.glb"), &"lowerarm_l"],
	[preload("res://assets/models/agent_spine.glb"), &"spine_02"],
]

const PLAYER_COLORS: Array[Color] = [
	Color(1.0, 0.45, 0.15), Color(0.2, 0.85, 1.0), Color(0.55, 1.0, 0.25), Color(1.0, 0.3, 0.8),
]
const BLEND := 0.14
## Natural ground speed (m/s) of each locomotion clip, for matching foot speed.
const CLIP_SPEED := {"Walk": 1.6, "Jog_Fwd": 3.6, "Sprint": 6.2, "Crouch_Fwd": 1.3}

## Shared across all bodies: animation libraries are loaded once.
static var _extra_library: AnimationLibrary
static var _base_library: AnimationLibrary

var player: Player
var anim: AnimationPlayer
var skeleton: Skeleton3D
var needed: bool = true  ## false when no camera can see this body

var _model: Node3D
var _current: StringName = &""
var _lean: float = 0.0
var _land_time: float = 0.0
var _face_yaw: float = 0.0


func setup(p_player: Player, layer_bits: int) -> void:
	player = p_player
	name = "Avatar%d" % (player.player_index + 1)
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_model = BODY.instantiate()
	add_child(_model)
	_model.rotation.y = PI  # the model faces +Z; Godot forward is -Z
	skeleton = _model.find_child("Skeleton3D") as Skeleton3D
	anim = _model.find_child("AnimationPlayer") as AnimationPlayer
	anim.add_animation_library(&"x", extra_library())

	var color := PLAYER_COLORS[player.player_index % PLAYER_COLORS.size()]
	# Matte stealth suit with a faint sheen so the silhouette reads against dark walls.
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color(0.035, 0.038, 0.042)
	suit.roughness = 0.58
	suit.metallic = 0.15
	suit.rim_enabled = true
	suit.rim = 0.35
	suit.rim_tint = 0.2
	var joints := StandardMaterial3D.new()
	joints.albedo_color = Color(0.13, 0.14, 0.15)
	joints.roughness = 0.35
	joints.metallic = 0.7
	var accent := StandardMaterial3D.new()
	accent.albedo_color = color
	accent.emission_enabled = true
	accent.emission = color
	accent.emission_energy_multiplier = 2.5
	var body := _model.find_child("Mannequin") as MeshInstance3D
	body.set_surface_override_material(0, suit)
	body.set_surface_override_material(1, joints)
	for g in GEAR:
		_attach(g[0], g[1], accent)
	for vi in find_children("*", "VisualInstance3D", true, false):
		(vi as VisualInstance3D).layers = layer_bits
	player.motor.landed.connect(func(impact: float) -> void:
		if impact > 7.0:
			_land_time = 0.22)


## Gear is modeled in the mannequin's rest-pose model space, so attaching it
## with the inverse bone rest makes it line up exactly and follow the bone.
func _attach(scene: PackedScene, bone: StringName, accent: Material) -> void:
	var idx := skeleton.find_bone(bone)
	var attach := BoneAttachment3D.new()
	attach.bone_name = bone
	skeleton.add_child(attach)
	var gear: Node3D = scene.instantiate()
	attach.add_child(gear)
	gear.transform = skeleton.get_bone_global_rest(idx).affine_inverse()
	for mi in gear.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(s)
			if mat and mat.resource_name == "Accent":
				m.set_surface_override_material(s, accent)


func _process(delta: float) -> void:
	var motor := player.motor
	var t := player.get_global_transform_interpolated()
	var h := Vector3(player.velocity.x, 0, player.velocity.z)
	var speed := h.length()
	var state := motor.state

	# Face where you look; on walls and in slides, face where you're going.
	var target_yaw := player.yaw
	if (state == PlayerMotor.State.WALLRUN or state == PlayerMotor.State.SLIDE) and speed > 1.0:
		target_yaw = atan2(-h.x, -h.z)
	_face_yaw = lerp_angle(_face_yaw, target_yaw, 1.0 - exp(-14.0 * delta))
	var lean_target := deg_to_rad(-24.0) * motor.wall_side if state == PlayerMotor.State.WALLRUN else 0.0
	_lean = lerpf(_lean, lean_target, 1.0 - exp(-10.0 * delta))
	global_transform = Transform3D(Basis(Vector3.UP, _face_yaw) * Basis(Vector3.BACK, _lean), t.origin)

	anim.active = needed
	if not needed:
		return
	_land_time = maxf(0.0, _land_time - delta)
	var pick := pick_clip(player, _land_time > 0.0)
	if pick[0] != _current:
		anim.play(pick[0], BLEND)
		_current = pick[0]
	anim.speed_scale = pick[1]


## Locomotion clip + playback rate for a player's movement state. Shared by
## the third-person avatar and the first-person body so they always agree.
static func pick_clip(p: Player, landing: bool) -> Array:
	var motor := p.motor
	var speed := p.horizontal_speed()
	var clip: StringName
	var rate := 1.0
	match motor.state:
		PlayerMotor.State.GROUND:
			if landing:
				clip = &"Jump_Land"
			elif motor.crouched:
				clip = &"Crouch_Idle" if speed < 0.4 else &"Crouch_Fwd"
			elif speed < 0.3:
				clip = &"Idle"
			elif speed < p.tuning.walk_speed * 0.6:
				clip = &"Walk"
			elif speed < p.tuning.walk_speed + 0.8:
				clip = &"Jog_Fwd"
			else:
				clip = &"Sprint"
			if CLIP_SPEED.has(String(clip)):
				rate = clampf(speed / CLIP_SPEED[String(clip)], 0.6, 1.8)
		PlayerMotor.State.SLIDE:
			clip = &"x/Slide"
		PlayerMotor.State.WALLRUN:
			clip = &"Sprint"
			rate = clampf(speed / CLIP_SPEED["Sprint"], 0.9, 1.8)
		PlayerMotor.State.WALLCLIMB:
			clip = &"x/ClimbUp_1m"
			rate = 1.6
		PlayerMotor.State.MANTLE:
			clip = &"x/ClimbUp_1m"
			rate = 2.6
		_:  # AIR, GRAPPLE
			clip = &"Jump" if p.velocity.y > -6.0 else &"x/NinjaJump_Idle"
	return [clip, rate]


## The main animation library (UAL1), loaded once (for bodies built without one).
static func base_library() -> AnimationLibrary:
	if _base_library == null:
		var src: Node = BODY.instantiate()
		_base_library = (src.find_child("AnimationPlayer") as AnimationPlayer).get_animation_library(&"")
		src.free()
	return _base_library


## The second animation library (UAL2), loaded once and shared by every body.
static func extra_library() -> AnimationLibrary:
	if _extra_library == null:
		var src: Node = MORE_ANIMS.instantiate()
		_extra_library = (src.find_child("AnimationPlayer") as AnimationPlayer).get_animation_library(&"")
		src.free()
	return _extra_library
