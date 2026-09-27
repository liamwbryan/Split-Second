class_name GrappleRope
extends MeshInstance3D
## Visual grapple line from the player's left hand to the anchor. Shoots out
## quickly on attach and snaps back on release. Purely cosmetic.

const SHOOT_TIME := 0.07
const HAND_OFFSET := Vector3(-0.22, -0.2, -0.35)  # camera-local

var player: Player
var _extend: float = 0.0
var _anchor: Vector3


func setup(p_player: Player) -> void:
	player = p_player
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh_res := CylinderMesh.new()
	mesh_res.top_radius = 0.018
	mesh_res.bottom_radius = 0.018
	mesh_res.height = 1.0
	mesh_res.radial_segments = 6
	mesh_res.rings = 1
	mesh = mesh_res
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = LevelBuilder.COLORS[LevelBuilder.Tag.GRAPPLE]
	material_override = mat
	visible = false
	player.motor.grapple_attached.connect(func(point: Vector3) -> void:
		_anchor = point
		_extend = 0.0)


func _process(delta: float) -> void:
	var motor := player.motor
	var active := motor.state == PlayerMotor.State.GRAPPLE
	if not active:
		visible = false
		return
	_anchor = motor.grapple_point
	_extend = minf(1.0, _extend + delta / SHOOT_TIME)
	var cam := player.camera_rig.camera
	var hand := cam.global_transform * HAND_OFFSET
	var to := _anchor - hand
	var length := to.length() * _extend
	if length < 0.05:
		visible = false
		return
	visible = true
	var dir := to.normalized()
	# Cylinder's axis is local Y: build a basis whose Y points along the rope.
	var x := dir.cross(Vector3.UP)
	if x.length() < 0.01:
		x = dir.cross(Vector3.RIGHT)
	x = x.normalized()
	var z := x.cross(dir).normalized()
	global_transform = Transform3D(Basis(x, dir * length, z), hand + dir * length * 0.5)
