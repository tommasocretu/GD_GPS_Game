class_name MovementConfig
extends Resource

## All tunables for the GPS movement model (ticket 07).

@export_range(0.1, 10.0, 0.1) var max_fix_age_s := 2.0
@export_range(1.0, 60.0, 0.5) var lost_after_s := 10.0
@export_range(5.0, 50.0, 1.0) var accuracy_ok_m := 30.0
@export_range(10.0, 200.0, 1.0) var accuracy_reject_m := 50.0
@export_range(0.05, 3.0, 0.05) var smooth_time := 0.45
@export_range(0.05, 3.0, 0.05) var weak_smooth_time := 1.0
@export_range(0.2, 10.0, 0.1) var max_speed := 2.5
@export_range(0.1, 5.0, 0.1) var weak_max_speed := 0.8
@export_range(0.5, 15.0, 0.5) var correction_min_m := 3.0
@export_range(5.0, 100.0, 1.0) var snap_distance_m := 15.0
@export_range(0.1, 3.0, 0.05) var correction_time_s := 0.8
@export_range(0.05, 2.0, 0.05) var lock_speed := 0.35
@export_range(0.5, 10.0, 0.1) var lock_time_s := 2.0
@export_range(0.1, 3.0, 0.05) var unlock_speed := 0.6
@export_range(1.0, 20.0, 0.5) var unlock_distance_m := 3.0
@export_range(0.05, 2.0, 0.05) var idle_speed := 0.3
@export_range(0.5, 10.0, 0.1) var run_speed := 2.5
@export_range(0.5, 10.0, 0.5) var heading_window_m := 2.0
@export_range(30.0, 720.0, 10.0) var max_turn_rate_deg := 180.0
@export_range(0.1, 5.0, 0.1) var speed_smoothing_s := 0.25
