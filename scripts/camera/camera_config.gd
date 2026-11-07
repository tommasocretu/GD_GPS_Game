class_name CameraConfig
extends Resource

## North-up oblique camera with touch yaw (ticket 08).

## Scaled from the ticket's (0, 13, 18.5) by 0.875: at pitch -27° the
## projected avatar height would otherwise be ~7.6%, not the 8.5-9.5% target.
## The feet stay at 65% of the screen because the offset direction is unchanged.
@export var offset := Vector3(0.0, 11.375, 16.1875)
@export_range(-80.0, -5.0, 1.0) var pitch_deg := -27.0
@export_range(30.0, 90.0, 1.0) var fov_deg := 50.0
@export_range(0.01, 1.0, 0.01) var follow_tau := 0.15
@export_range(1.0, 20.0, 0.5) var spring_min_length := 8.0
@export_range(0.0, 2.0, 0.05) var spring_margin := 0.3
@export_range(0.05, 1.0, 0.05) var spring_sphere_radius := 0.3
@export_range(0.05, 1.0, 0.05) var spring_recovery_s := 0.2
@export_range(20.0, 100.0, 1.0) var fog_begin_m := 180.0
@export_range(50.0, 400.0, 1.0) var fog_end_m := 320.0
@export var background_color := Color("#cfd8cc")
@export_range(0.5, 3.0, 0.1) var camera_height_at_avatar := 1.2

## Horizontal drag sensitivity: degrees of camera yaw per screen width.
@export_range(30.0, 720.0, 10.0) var yaw_degrees_per_screen := 180.0
## Exponential smoothing used when a double tap returns the camera to north.
@export_range(0.05, 2.0, 0.05) var yaw_reset_tau := 0.2
@export_range(0.1, 0.6, 0.05) var double_tap_window_s := 0.3
@export_range(1.0, 40.0, 1.0) var double_tap_max_move_px := 12.0
## Touch slop before a horizontal drag starts rotating the camera.
@export_range(1.0, 30.0, 1.0) var drag_start_px := 6.0
