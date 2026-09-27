class_name FPPoseModifier
extends SkeletonModifier3D
## First skeleton modifier on the first-person body. Runs after animation,
## before the arm IK:
##  - hides the head and neck (the camera is where the eyes would be)
##  - locks the chest into a rifle stance that follows the view: upright, a
##    share of the view pitch, bladed (left shoulder forward). Clips still
##    drive the hips and legs; the lock keeps the shoulders where the arms can
##    reach the gun no matter how far a clip leans or twists the torso.
##  - poses fingers into a grip (right hand always, left hand by `left_grip`)

var pitch: float = 0.0          ## camera pitch (radians, + = up)
var left_grip: float = 1.0      ## 1 = left fingers closed on the gun, 0 = open palm (planting)
var stance: float = 1.0         ## 1 = chest locked to the stance, 0 = chest from the clip
var body: Node3D                ## the FP body root: its -Z is "forward"

const PITCH_SHARE := 0.6        ## share of the view pitch the chest follows
const PITCH_LIMIT := deg_to_rad(21.0)
const HUNCH := deg_to_rad(8.0)  ## chest leans forward over the gun
const BLADE := deg_to_rad(-18.0)  ## chest turned right: left shoulder forward
const PROTRACT := deg_to_rad(22.0)  ## shoulders rolled forward around the chest (clavicles)
## First-person arms are a little longer than the body's, the usual FP cheat so
## the hands reach a gun held where it reads well on screen.
const ARM_STRETCH := 1.12

const LEFT_CURL := [62.0, 78.0, 48.0]  ## left finger flexion around the handguard, knuckle -> tip (deg)
const THUMB_CURL := 35.0

var support: float = 1.0        ## 1 = both hands on the gun (bladed stance); 0 = one hand (square)
## Neck anchor (skeleton space): the pelvis is shifted so the posed neck lands
## here, this frame, so the upper body is rigid to the camera whatever the clip
## bounce (reading the neck back a frame late made it shake).
var neck_target: Vector3 = Vector3.INF
var max_lift: float = INF       ## cap on raising the pelvis (slide: keeps the legs on the floor)
var lift_cap_weight: float = 0.0
var extra_hunch: float = 0.0    ## radians of extra forward lean (mantle/vault reach)

## bone index -> gripped rotation (sampled from Pistol_Aim_Neutral at load)
var grip_right: Dictionary = {}
var grip_left: Dictionary = {}
var open_left: Dictionary = {}  ## flat hand, fingers slightly relaxed

const HIDE := [&"Head", &"neck_01"]
const SPINE := [&"spine_01", &"spine_02", &"spine_03"]

var _hide_idx: PackedInt32Array = []
var _spine_idx: PackedInt32Array = []
var _chest_rest: Quaternion      ## spine_03 global rest rotation (upright, facing forward)
var _clavicles: PackedInt32Array = []  ## [left, right]
var _neck: int = -1
var _pelvis: int = -1
var _stretch: Dictionary = {}    ## bone -> stretched local position (forearm, hand)


func setup(skeleton: Skeleton3D, grip_source: Animation) -> void:
	for b in HIDE:
		_hide_idx.append(skeleton.find_bone(b))
	for b: StringName in SPINE:
		_spine_idx.append(skeleton.find_bone(b))
	_chest_rest = skeleton.get_bone_global_rest(_spine_idx[-1]).basis.get_rotation_quaternion()
	_clavicles = [skeleton.find_bone("clavicle_l"), skeleton.find_bone("clavicle_r")]
	_neck = skeleton.find_bone("neck_01")
	_pelvis = skeleton.find_bone("pelvis")
	for b in ["lowerarm_l", "hand_l", "lowerarm_r", "hand_r"]:
		var i := skeleton.find_bone(b)
		_stretch[i] = skeleton.get_bone_rest(i).origin * ARM_STRETCH
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
			# The pistol clip's support hand cups the other hand with nearly straight
			# fingers; around a handguard the fingers wrap, so curl them (+X flexes
			# toward the palm on this rig). The thumb keeps the clip's pose.
			var seg := int(bone.get_slice("_", 1))  # 1 = knuckle .. 3 = tip
			if not bone.begins_with("thumb"):
				rot = skeleton.get_bone_rest(idx).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, deg_to_rad(LEFT_CURL[clampi(seg, 1, 3) - 1]))
			elif seg >= 2:  # thumb tip folds over the fingers instead of pointing up
				rot = rot * Quaternion(Vector3.RIGHT, deg_to_rad(THUMB_CURL))
			grip_left[idx] = rot
			open_left[idx] = skeleton.get_bone_rest(idx).basis.get_rotation_quaternion().slerp(rot, 0.12)


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for i in _hide_idx:
		sk.set_bone_pose_scale(i, Vector3.ONE * 0.001)
	if stance > 0.001 and body:
		_lock_chest(sk)
	if neck_target.is_finite():
		_anchor_neck(sk)
	for i: int in _stretch:
		sk.set_bone_pose_position(i, _stretch[i])
	for i: int in grip_right:
		sk.set_bone_pose_rotation(i, grip_right[i])
	for i: int in grip_left:
		sk.set_bone_pose_rotation(i, (open_left[i] as Quaternion).slerp(grip_left[i], left_grip))


## Turns spine_01..03 so the chest ends up in the stance orientation, each bone
## taking an equal share of the remaining correction (a smooth curve, not a kink).
func _lock_chest(sk: Skeleton3D) -> void:
	# Body axes in skeleton space (the imported armature may be rotated/scaled).
	var to_skel := sk.global_transform.basis.orthonormalized().inverse() * body.global_basis.orthonormalized()
	var up := (to_skel * Vector3.UP).normalized()
	var right := (to_skel * Vector3.RIGHT).normalized()
	var lean := clampf(pitch * PITCH_SHARE, -PITCH_LIMIT, PITCH_LIMIT) - HUNCH - extra_hunch
	var want := Quaternion(right, lean) * Quaternion(up, BLADE * support) * _chest_rest
	var chest := _spine_idx[-1]
	var n := _spine_idx.size()
	for k in n:
		var bone := _spine_idx[k]
		var have := sk.get_bone_global_pose(chest).basis.get_rotation_quaternion()
		var fix := Quaternion.IDENTITY.slerp(want * have.inverse(), stance / float(n - k))
		var parent := sk.get_bone_parent(bone)
		var parent_rot := sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
		var global_rot := fix * sk.get_bone_global_pose(bone).basis.get_rotation_quaternion()
		sk.set_bone_pose_rotation(bone, (parent_rot.inverse() * global_rot).normalized())
	# Clavicles: rest pose relative to the chest, rolled forward.
	var chest_rot := sk.get_bone_global_pose(chest).basis.get_rotation_quaternion()
	for k in 2:
		var bone := _clavicles[k]
		var rest := sk.get_bone_rest(bone).basis.get_rotation_quaternion()
		var roll := Quaternion(up, PROTRACT * lerpf(0.5, 1.0, support) * (1.0 if k == 1 else -1.0) * stance)
		sk.set_bone_pose_rotation(bone, (chest_rot.inverse() * roll * chest_rot * rest).normalized())


func _anchor_neck(sk: Skeleton3D) -> void:
	var delta := neck_target - sk.get_bone_global_pose(_neck).origin
	if lift_cap_weight > 0.0 and max_lift < INF:
		var up := (sk.global_transform.basis.orthonormalized().inverse() * Vector3.UP).normalized()
		var lift := delta.dot(up)
		var capped := minf(lift, max_lift)
		delta -= up * (lift - capped) * lift_cap_weight
	var parent := sk.get_bone_parent(_pelvis)
	var to_parent := sk.get_bone_global_pose(parent).basis.inverse() if parent >= 0 else Basis.IDENTITY
	sk.set_bone_pose_position(_pelvis, sk.get_bone_pose_position(_pelvis) + to_parent * delta)
