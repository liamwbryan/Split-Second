class_name FPPoseModifier
extends SkeletonModifier3D
## First skeleton modifier on the first-person body. Runs after animation,
## before the arm IK:
##  - hides the head and neck (the camera is where the eyes would be)
##  - bends the spine a share of the view pitch (looking down curls the chest)
##  - poses fingers into a grip (right hand always, left hand by `left_grip`)

var pitch: float = 0.0          ## camera pitch (radians, + = up)
var left_grip: float = 1.0      ## 1 = left fingers closed on the gun, 0 = open palm (planting)

## bone index -> gripped rotation (sampled from Pistol_Aim_Neutral at load)
var grip_right: Dictionary = {}
var grip_left: Dictionary = {}

const HIDE := [&"Head", &"neck_01"]
const SPINE_SHARE := {&"spine_01": 0.15, &"spine_02": 0.2, &"spine_03": 0.25}
const SPINE_LIMIT := deg_to_rad(35.0)

var _hide_idx: PackedInt32Array = []
var _spine_idx: Dictionary = {}


func setup(skeleton: Skeleton3D, grip_source: Animation) -> void:
	for b in HIDE:
		_hide_idx.append(skeleton.find_bone(b))
	for b: StringName in SPINE_SHARE:
		_spine_idx[skeleton.find_bone(b)] = SPINE_SHARE[b]
	# Capture finger rotations from the pistol pose: closed, gun-holding fingers.
	for t in grip_source.get_track_count():
		if grip_source.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := String(grip_source.track_get_path(t).get_subname(0))
		var is_finger := bone.begins_with("index") or bone.begins_with("middle") or bone.begins_with("ring") \
			or bone.begins_with("pinky") or bone.begins_with("thumb")
		if not is_finger:
			continue
		var idx := skeleton.find_bone(bone)
		if idx < 0:
			continue
		var rot := grip_source.rotation_track_interpolate(t, 0.0)
		if bone.ends_with("_r"):
			grip_right[idx] = rot
		elif bone.ends_with("_l"):
			grip_left[idx] = rot


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for i in _hide_idx:
		sk.set_bone_pose_scale(i, Vector3.ONE * 0.001)
	# Bone local X is the body's side axis for the spine chain on this rig.
	var bend := clampf(-pitch, -SPINE_LIMIT, SPINE_LIMIT)
	for i: int in _spine_idx:
		var q := sk.get_bone_pose_rotation(i) * Quaternion(Vector3.RIGHT, bend * _spine_idx[i])
		sk.set_bone_pose_rotation(i, q)
	for i: int in grip_right:
		sk.set_bone_pose_rotation(i, grip_right[i])
	if left_grip > 0.001:
		for i: int in grip_left:
			sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(grip_left[i], left_grip))
