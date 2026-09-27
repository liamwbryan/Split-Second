class_name WeaponData
extends Resource
## Data for one weapon: guns (hitscan) and blades (melee). Everything a weapon
## does or looks like comes from here, and every number is in the tuning panel.
## M2 adds projectile weapons on top of this.

enum Kind { HITSCAN, MELEE }
enum Slot { PRIMARY, SECONDARY, MELEE }

@export var display_name: String = "Rifle"
@export var kind: Kind = Kind.HITSCAN
@export var slot: Slot = Slot.PRIMARY
## Blender model (see art/blender/); null = the carbine.
@export var model: PackedScene
@export var model_scale: float = 0.9
@export var model_rot_deg: Vector3 = Vector3.ZERO  ## mount rotation (blades stand up out of the fist)
## Viewmodel grip positions in camera space (two hands / one hand / aiming / sprint).
@export var hip_pos: Vector3 = Vector3(0.16, -0.19, -0.4)
@export var hip1_pos: Vector3 = Vector3(0.17, -0.2, -0.36)
@export var ads_pos: Vector3 = Vector3(0.0, -0.132, -0.19)
@export var sprint_pos: Vector3 = Vector3(0.13, -0.24, -0.34)
@export var sprint1_pos: Vector3 = Vector3(0.2, -0.27, -0.3)
@export_range(0.05, 1.0, 0.01) var draw_time: float = 0.2  ## raise after a switch (s)
@export var shot_sound: StringName = &"shot"
@export_range(-30.0, 6.0, 0.5) var shot_volume_db: float = -4.0

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
@export_range(0.1, 1.0, 0.01) var ads_fov_mult: float = 0.8
@export_range(0.1, 1.0, 0.01) var ads_sens_mult: float = 1.0  ## look sensitivity at full ADS
## Scoped: full-screen scope overlay at full ADS (the gun and arms hide).
@export var scoped: bool = false
@export_range(0.0, 1.0, 0.01) var scope_in_at: float = 0.8  ## ADS amount where the scope view takes over

@export_group("Shot")
## Rail tracer: a thick lingering beam instead of a quick streak.
@export var rail_tracer: bool = false
## Bolt/charge cadence: after each shot the gun cycles (the rpm sets the time).
@export var bolt_action: bool = false
@export_range(0.0, 400.0, 1.0) var long_shot_distance: float = 60.0  ## hits past this get the long-shot reward

@export_group("Handling")
## SMG-style carry: one hand on the gun at the hip, the other free (it swings
## with your stride and reaches for walls/ledges); both hands when aiming.
## Off = rifle carry, both hands on the gun all the time.
@export var one_hand_hip: bool = true
@export_range(0.03, 0.4, 0.01) var support_time: float = 0.1  ## support hand on/off the handguard (s)

@export_group("Melee")
@export_range(1.0, 300.0, 1.0) var melee_damage: float = 50.0
@export_range(0.5, 6.0, 0.05) var melee_range: float = 2.4  ## reach from the eye to the target's chest
@export_range(5.0, 90.0, 1.0) var melee_cone_deg: float = 40.0
@export_range(0.1, 1.2, 0.01) var swing_time: float = 0.34  ## one swing, start to ready
@export_range(0.0, 1.0, 0.01) var strike_at: float = 0.3  ## fraction of the swing where it connects
@export_range(1, 3, 1) var combo_count: int = 3
@export_range(0.0, 1.0, 0.01) var combo_window: float = 0.45  ## press again within this after a swing to chain
@export_range(1.0, 3.0, 0.05) var combo_finisher_mult: float = 1.5  ## last swing of the chain
@export_range(1.0, 3.0, 0.05) var slide_melee_mult: float = 1.5
@export_range(1.0, 3.0, 0.05) var air_melee_mult: float = 1.3
@export_range(0.0, 0.2, 0.005) var hitstop: float = 0.06  ## freeze on a hit (s)
@export_group("Lunge")
@export_range(0.0, 15.0, 0.1) var lunge_range: float = 7.5
@export_range(0.0, 40.0, 0.5) var lunge_speed: float = 20.0
@export_range(0.05, 1.0, 0.01) var lunge_max_time: float = 0.4
@export_range(0.5, 3.0, 0.05) var lunge_stop_distance: float = 1.4  ## stop this far from the target (never pass through)
@export_range(1.0, 45.0, 0.5) var lunge_cone_deg: float = 14.0
@export_range(1.0, 45.0, 0.5) var lunge_cone_pad_deg: float = 22.0  ## gamepad magnetism
@export_range(0.0, 1.0, 0.01) var lunge_exit_keep: float = 0.35  ## share of your entry speed kept after the strike
