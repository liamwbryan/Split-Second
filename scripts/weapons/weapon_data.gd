class_name WeaponData
extends Resource
## Data for one weapon. M2 adds projectile weapons on top of this.

@export var display_name: String = "Rifle"

@export_group("Damage")
@export_range(1.0, 200.0, 0.5) var damage: float = 18.0
@export_range(1.0, 4.0, 0.05) var headshot_mult: float = 2.0
@export_range(5.0, 500.0, 1.0) var max_range: float = 220.0
@export_range(0.0, 200.0, 1.0) var falloff_near: float = 25.0
@export_range(0.0, 300.0, 1.0) var falloff_far: float = 70.0
@export_range(0.0, 1.0, 0.01) var falloff_min_mult: float = 0.55

@export_group("Fire")
@export_range(30.0, 1500.0, 5.0) var rpm: float = 640.0
@export var automatic: bool = true
@export_range(1, 200, 1) var magazine: int = 30
@export_range(0.2, 5.0, 0.05) var reload_time: float = 1.6

@export_group("Accuracy")
@export_range(0.0, 10.0, 0.05) var hip_spread: float = 1.1  ## degrees
@export_range(0.0, 5.0, 0.01) var ads_spread: float = 0.12
@export_range(0.0, 10.0, 0.05) var move_spread: float = 1.0  ## added at sprint speed (hip only)
@export_range(0.0, 10.0, 0.05) var air_spread: float = 0.8
@export_range(0.0, 1.0, 0.01) var parkour_spread_mult: float = 0.55  ## slide / wall-run tighten spread
@export_range(0.0, 3.0, 0.01) var bloom_per_shot: float = 0.25
@export_range(0.0, 10.0, 0.05) var bloom_max: float = 2.5
@export_range(0.0, 40.0, 0.5) var bloom_recover: float = 9.0  ## degrees / s

@export_group("Recoil")
## (pitch up, yaw right) degrees per shot; loops over the tail after the first pass.
@export var recoil_pattern: PackedVector2Array = PackedVector2Array([
	Vector2(0.55, 0.02), Vector2(0.6, 0.08), Vector2(0.6, 0.12), Vector2(0.55, 0.05),
	Vector2(0.5, -0.12), Vector2(0.48, -0.22), Vector2(0.45, -0.1), Vector2(0.42, 0.12),
	Vector2(0.4, 0.24), Vector2(0.38, 0.1), Vector2(0.38, -0.1), Vector2(0.38, -0.2),
])
@export_range(0, 20, 1) var recoil_loop_from: int = 4
@export_range(0.0, 1.0, 0.01) var ads_recoil_mult: float = 0.7
@export_range(0.0, 3.0, 0.05) var visual_punch: float = 1.0

@export_group("ADS")
@export_range(0.03, 0.6, 0.01) var ads_time: float = 0.13
@export_range(0.4, 1.0, 0.01) var ads_fov_mult: float = 0.8

@export_group("Handling")
## SMG-style carry: one hand on the gun at the hip, the other free (it swings
## with your stride and reaches for walls/ledges); both hands when aiming.
## Off = rifle carry, both hands on the gun all the time.
@export var one_hand_hip: bool = true
@export_range(0.03, 0.4, 0.01) var support_time: float = 0.1  ## support hand on/off the handguard (s)
