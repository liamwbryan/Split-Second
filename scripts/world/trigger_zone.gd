class_name TriggerZone
extends Area3D
## Box trigger for level features: checkpoints, hazards, and jump pads.

enum Kind { CHECKPOINT, HAZARD, JUMP_PAD }

var kind: Kind = Kind.CHECKPOINT
var spawn_position: Vector3
var spawn_yaw: float = 0.0
var launch_velocity: Vector3 = Vector3.ZERO


static func create(parent: Node, p_kind: Kind, center: Vector3, size: Vector3) -> TriggerZone:
	var z := TriggerZone.new()
	z.kind = p_kind
	z.collision_layer = 1 << 3
	z.collision_mask = 1 << 1  # players
	z.monitorable = false
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	z.add_child(cs)
	parent.add_child(z)
	z.global_position = center
	z.body_entered.connect(z._on_body_entered)
	return z


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	match kind:
		Kind.CHECKPOINT:
			player.spawn_position = spawn_position
			player.spawn_yaw = spawn_yaw
		Kind.HAZARD:
			player.respawn.call_deferred()
		Kind.JUMP_PAD:
			player.motor.launch(launch_velocity)
			Sfx.play(&"double_jump", -2.0, 0.0, 0.8)
