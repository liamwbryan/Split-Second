class_name PlayerSettings
extends Resource
## Per-player comfort and control settings. Separate from MovementTuning,
## which is game-wide feel.

@export_group("Mouse")
@export_range(0.0002, 0.01, 0.0001) var mouse_sensitivity: float = 0.0022  ## radians per pixel
@export var invert_y: bool = false

@export_group("Gamepad Look")
@export_range(60.0, 600.0, 5.0) var pad_yaw_speed: float = 280.0  ## deg/s at full deflection
@export_range(60.0, 600.0, 5.0) var pad_pitch_speed: float = 190.0
@export_range(1.0, 3.5, 0.05) var pad_response_curve: float = 1.9
@export_range(0.0, 0.4, 0.01) var pad_inner_deadzone: float = 0.12
@export_range(0.6, 1.0, 0.01) var pad_outer_deadzone: float = 0.95
@export_range(1.0, 3.0, 0.05) var pad_edge_yaw_boost: float = 1.7  ## extra yaw after holding full deflection
@export_range(0.0, 1.0, 0.01) var pad_edge_boost_delay: float = 0.22
@export_range(0.0, 1.0, 0.01) var pad_edge_boost_ramp: float = 0.35
@export_range(0.0, 0.4, 0.01) var pad_move_deadzone: float = 0.15

@export_group("Comfort")
@export_range(60.0, 110.0, 1.0) var fov: float = 80.0  ## vertical degrees (~111 horizontal at 16:9)
@export_range(0.0, 1.5, 0.05) var camera_tilt_scale: float = 1.0
@export_range(0.0, 1.5, 0.05) var head_bob_scale: float = 0.6
@export_range(0.0, 1.5, 0.05) var speed_fov_scale: float = 1.0
@export var auto_sprint: bool = false  ## always sprint when moving forward
