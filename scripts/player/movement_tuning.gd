class_name MovementTuning
extends Resource
## Every movement number lives here. It can be edited live in the tuning panel
## (F1 / Tab), and "Save as default" writes res://tuning/movement_default.tres.
## Units: meters, seconds, m/s, m/s^2, degrees.

@export_group("Ground")
@export_range(1.0, 20.0, 0.1) var walk_speed: float = 6.0  ## default movement; sprint is Shift / L3
@export_range(1.0, 25.0, 0.1) var sprint_speed: float = 10.0
@export_range(0.5, 10.0, 0.1) var crouch_speed: float = 3.5
@export_range(5.0, 200.0, 1.0) var ground_accel: float = 75.0
@export_range(5.0, 200.0, 1.0) var ground_decel: float = 55.0  ## stopping with no input
@export_range(0.0, 60.0, 0.5) var overspeed_decel: float = 14.0  ## bleed above sprint speed on foot
@export_range(0.0, 30.0, 0.5) var overspeed_turn_rate: float = 10.0  ## rad/s steering while overspeed

@export_group("Air")
@export_range(5.0, 60.0, 0.5) var gravity: float = 24.0
@export_range(1.0, 2.0, 0.01) var fall_gravity_mult: float = 1.1
@export_range(10.0, 80.0, 1.0) var max_fall_speed: float = 45.0
@export_range(0.0, 20.0, 0.1) var air_speed: float = 7.5  ## wish speed for air acceleration
@export_range(0.0, 20.0, 0.1) var air_accel: float = 2.6  ## Quake-style; higher = more air control

@export_group("Jump")
@export_range(0.3, 4.0, 0.05) var jump_height: float = 1.25
@export_range(0.3, 4.0, 0.05) var double_jump_height: float = 1.1
@export_range(0.0, 1.0, 0.01) var double_jump_redirect: float = 0.8  ## 0 keep direction, 1 full redirect to input
@export_range(0.0, 0.3, 0.01) var coyote_time: float = 0.12
@export_range(0.0, 0.3, 0.01) var jump_buffer: float = 0.14
@export_range(0.3, 1.0, 0.01) var jump_cut_mult: float = 1.0  ## <1 = releasing jump early cuts height

@export_group("Slide")
@export_range(0.0, 15.0, 0.1) var slide_min_start_speed: float = 7.0  ## above walk speed: slides come from a sprint
@export_range(0.0, 10.0, 0.1) var slide_boost: float = 3.0
@export_range(5.0, 30.0, 0.5) var slide_boost_max_speed: float = 14.0  ## boost never pushes past this
@export_range(0.0, 5.0, 0.05) var slide_boost_chain_window: float = 1.6  ## boosts within this window diminish
@export_range(0.0, 1.0, 0.01) var slide_boost_chain_mult: float = 0.5
@export_range(0.0, 20.0, 0.1) var slide_decel: float = 4.5
@export_range(0.0, 2.0, 0.05) var slide_slope_mult: float = 1.0  ## fraction of gravity applied along slopes
@export_range(0.0, 10.0, 0.1) var slide_steer: float = 1.6  ## rad/s
@export_range(0.0, 10.0, 0.1) var slide_exit_speed: float = 4.0
@export_range(0.0, 1.0, 0.01) var slide_min_time: float = 0.15  ## shortest slide, so a quick tap isn't a stutter

@export_group("Speed Limits")
@export_range(5.0, 50.0, 0.5) var soft_speed_cap: float = 18.0  ## horizontal speed above this bleeds off
@export_range(0.0, 60.0, 0.5) var soft_cap_decay: float = 7.0
@export_range(10.0, 80.0, 1.0) var hard_speed_cap: float = 40.0

@export_group("Wall Run")
@export_range(0.0, 15.0, 0.1) var wallrun_min_speed: float = 4.5  ## along-wall speed needed to attach
@export_range(0.0, 25.0, 0.1) var wallrun_target_speed: float = 11.0
@export_range(0.0, 30.0, 0.5) var wallrun_accel: float = 7.0
@export_range(0.0, 10.0, 0.1) var wallrun_overspeed_decel: float = 1.5
@export_range(0.3, 5.0, 0.05) var wallrun_max_time: float = 2.2
@export_range(0.0, 30.0, 0.1) var wallrun_gravity_start: float = 0.5
@export_range(0.0, 40.0, 0.1) var wallrun_gravity_end: float = 14.0
@export_range(0.1, 5.0, 0.05) var wallrun_gravity_ramp: float = 2.2
@export_range(0.0, 10.0, 0.1) var wallrun_entry_max_up: float = 3.0
@export_range(-10.0, 0.0, 0.1) var wallrun_entry_min_vy: float = -0.5  ## falls are arrested to this on attach
@export_range(0.0, 20.0, 0.1) var wallrun_max_fall: float = 7.0
@export_range(0.0, 3.0, 0.05) var wallrun_min_height: float = 0.7  ## above ground to attach
@export_range(0.05, 1.5, 0.05) var wall_attach_distance: float = 0.45  ## attach assist reach from capsule
@export_range(0.0, 1.0, 0.05) var wallrun_detach_input: float = 0.6  ## push away this hard to let go
@export_range(0.0, 1.0, 0.05) var wall_reattach_delay: float = 0.25

@export_group("Wall Kick")
@export_range(0.0, 15.0, 0.1) var wallkick_up: float = 7.0
@export_range(0.0, 15.0, 0.1) var wallkick_out: float = 5.5
@export_range(0.0, 1.0, 0.01) var wallkick_look_blend: float = 0.55  ## steer the kick toward where you look
@export_range(0.0, 1.0, 0.01) var wallkick_min_out_dot: float = 0.25  ## kick always leaves the wall at least this much
@export_range(0.0, 20.0, 0.1) var wallkick_min_speed: float = 8.0

@export_group("Wall Climb")
@export_range(0.0, 80.0, 1.0) var climb_angle: float = 35.0  ## within this of head-on = climb, else wall-run
@export_range(0.0, 15.0, 0.1) var climb_speed: float = 7.0
@export_range(0.1, 2.0, 0.05) var climb_time: float = 0.6
@export_range(0.0, 30.0, 0.5) var climb_max_fall: float = 9.0  ## falling faster than this can't start a climb
@export_range(0.0, 15.0, 0.1) var climb_kick_up: float = 6.0
@export_range(0.0, 15.0, 0.1) var climb_kick_out: float = 6.5
@export_range(0.0, 15.0, 0.1) var climb_hop_up: float = 6.5  ## jump while pushing into the wall: hop up it (no kick, no turn)
@export_range(1.0, 10.0, 0.1) var climb_chimney_reach: float = 5.0  ## ...unless a wall is this close behind: then kick across (chimney)
@export var climb_kick_auto_turn: bool = true  ## jump without pushing into the wall: kick off and turn to face away
@export_range(0.05, 0.6, 0.01) var climb_turn_time: float = 0.2

@export_group("Mantle & Vault")
@export_range(0.1, 1.0, 0.05) var mantle_min_height: float = 0.3
@export_range(0.5, 3.5, 0.05) var mantle_max_height: float = 1.9  ## ledge above feet, in air
@export_range(0.3, 2.5, 0.05) var ground_mantle_max_height: float = 1.4  ## jump-to-mantle from ground
@export_range(0.1, 1.5, 0.05) var mantle_reach: float = 0.55
@export_range(0.05, 1.0, 0.01) var mantle_time_base: float = 0.24
@export_range(0.0, 0.5, 0.01) var mantle_time_per_meter: float = 0.08
@export_range(0.0, 15.0, 0.1) var mantle_exit_speed: float = 5.5
@export_range(0.0, 1.0, 0.01) var mantle_speed_keep: float = 0.6
@export_range(0.0, 1.0, 0.05) var mantle_lift_ease: float = 1.0  ## 0 = snappy ease-out lift, 1 = ease-in-out (the ledge and hands stay on screen longer)
@export_range(0.3, 2.0, 0.05) var vault_max_height: float = 1.25
@export_range(0.0, 15.0, 0.1) var vault_min_speed: float = 6.5
@export_range(0.05, 1.0, 0.01) var vault_time: float = 0.22

@export_group("Grapple")
@export_range(5.0, 100.0, 1.0) var grapple_range: float = 45.0
@export_range(0.0, 150.0, 1.0) var grapple_pull_accel: float = 48.0
@export_range(5.0, 50.0, 0.5) var grapple_max_speed: float = 24.0
@export_range(0.0, 1.0, 0.01) var grapple_gravity_mult: float = 0.35
@export_range(0.0, 2.0, 0.05) var grapple_air_control: float = 1.4
@export_range(0.2, 5.0, 0.05) var grapple_max_time: float = 1.8
@export_range(0.0, 0.5, 0.01) var grapple_min_time: float = 0.12  ## a tap still pulls this long
@export_range(0.0, 20.0, 0.1) var grapple_cooldown: float = 4.0
@export_range(0.0, 5.0, 0.05) var grapple_miss_cooldown: float = 0.4
@export_range(0.5, 6.0, 0.1) var grapple_release_distance: float = 2.2
@export_range(0.0, 15.0, 0.1) var grapple_ground_lift: float = 5.0
@export_range(0.0, 15.0, 0.1) var grapple_magnet_angle: float = 6.0  ## aim assist toward grapple points

@export_group("Momentum")
## Prototype (docs/MOMENTUM.md): chaining moves fills a flow meter that raises
## the soft speed cap, makes kicks push you faster and lets wall-runs keep their
## entry speed. Landing hard into a slide turns fall speed into slide speed.
@export var momentum_enabled: bool = false
@export_range(0.0, 1.0, 0.05) var momentum_link_gain: float = 0.2  ## meter per chained move (wall-run, kick, slide-hop, slide landing, grapple release)
@export_range(0.0, 2.0, 0.05) var momentum_air_decay: float = 0.15  ## meter lost per second in the air
@export_range(0.0, 10.0, 0.1) var momentum_ground_decay: float = 2.0  ## meter lost per second on foot (not sliding)
@export_range(0.0, 1.0, 0.05) var momentum_ground_grace: float = 0.2  ## seconds on foot before the meter drains
@export_range(0.0, 20.0, 0.5) var momentum_cap_bonus: float = 7.0  ## soft speed cap raise at a full meter
@export_range(0.0, 5.0, 0.1) var momentum_kick_speed: float = 1.5  ## speed a wall/climb kick or grapple release adds at a full meter
@export_range(0.0, 1.0, 0.05) var momentum_wallrun_keep: float = 0.8  ## at a full meter, this much less wall-run overspeed bleed
@export_range(0.0, 30.0, 0.5) var momentum_land_min_impact: float = 9.0  ## fall speed a slide landing must beat (a slide-hop lands at ~8)
@export_range(0.0, 1.0, 0.05) var momentum_land_convert: float = 0.6  ## fraction of fall speed above that turned into slide speed
@export_range(0.0, 15.0, 0.5) var momentum_land_max: float = 6.0  ## most speed one slide landing can add
@export_range(0.0, 15.0, 0.5) var momentum_fov_add: float = 4.0  ## extra FOV (degrees) at a full meter
@export_range(0.0, 15.0, 0.5) var momentum_boost_fov_kick: float = 4.0  ## FOV punch (degrees) on a slide-landing or kick boost
@export_range(-40.0, 0.0, 1.0) var momentum_link_sound_db: float = -15.0  ## rising chime per chained move (-40 = off)

@export_group("Camera")
@export_range(0.0, 30.0, 0.5) var wallrun_camera_tilt: float = 9.0
@export_range(0.0, 10.0, 0.1) var strafe_camera_tilt: float = 1.2
@export_range(0.0, 10.0, 0.1) var slide_camera_tilt: float = 2.5
@export_range(0.0, 25.0, 0.5) var mantle_camera_nod: float = 15.0  ## degrees the view dips mid-mantle (shows the hand plants)
@export_range(0.0, 30.0, 0.5) var speed_fov_add: float = 12.0
@export_range(0.0, 30.0, 0.5) var speed_fov_min: float = 9.0  ## speed where FOV starts widening
@export_range(0.0, 50.0, 0.5) var speed_fov_max: float = 22.0
@export_range(1.0, 2.2, 0.01) var eye_height: float = 1.62
@export_range(0.5, 1.5, 0.01) var crouch_eye_height: float = 0.95
@export_range(0.0, 0.1, 0.001) var landing_dip_scale: float = 0.012
@export_range(0.0, 0.2, 0.005) var head_bob_amount: float = 0.035
