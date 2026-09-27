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

## Gamepad aim assist strength (scales slowdown and rotational below).
enum AimAssistPreset { OFF, LOW, STANDARD, STRONG }
const AIM_ASSIST_SCALE: Array[float] = [0.0, 0.55, 1.0, 1.4]

@export_group("Aim Assist (gamepad only)")
@export var aim_assist: AimAssistPreset = AimAssistPreset.STANDARD
@export_range(0.0, 0.9, 0.01) var aim_assist_slowdown: float = 0.4  ## stick look slows by this much on target
@export_range(0.0, 1.0, 0.01) var aim_assist_rotational: float = 0.5  ## share of the target's motion (relative to you) the view follows
@export_range(0.5, 15.0, 0.1) var aim_assist_cone: float = 5.0  ## degrees around the target's chest
@export_range(0.0, 2.0, 0.05) var aim_assist_target_radius: float = 0.7  ## m: widens the cone for close targets
@export_range(5.0, 150.0, 1.0) var aim_assist_range: float = 60.0  ## m
@export_range(5.0, 200.0, 1.0) var aim_assist_max_rate: float = 60.0  ## deg/s cap on the rotational pull
@export_range(0.0, 1.0, 0.01) var aim_assist_hip_mult: float = 0.7  ## hip-fire strength (ADS gets the full amount)
@export_range(0.05, 1.0, 0.01) var aim_assist_stick_full: float = 0.3  ## curved look-stick deflection for full rotational

@export_group("Comfort")
@export_range(60.0, 110.0, 1.0) var fov: float = 80.0  ## vertical degrees (~111 horizontal at 16:9)
@export_range(0.0, 1.5, 0.05) var camera_tilt_scale: float = 1.0
@export_range(0.0, 1.5, 0.05) var head_bob_scale: float = 0.6
@export_range(0.0, 1.5, 0.05) var speed_fov_scale: float = 1.0
@export var auto_sprint: bool = false  ## always sprint when moving forward
