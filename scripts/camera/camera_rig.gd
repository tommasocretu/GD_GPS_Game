class_name CameraRig
extends Node3D

## Follow camera with a collision arm and touch yaw (ticket 08).

const COLLISION_MASK := 1 << 1  # layer 2: building chunks

@export var config: CameraConfig
@onready var camera: Camera3D = $Camera3D

var target_position := Vector3.ZERO
var smoothed_position := Vector3.ZERO
var initialized := false

## Camera yaw in degrees: 0 = north-up, positive looks west (camera east of
## the avatar). The avatar stays horizontally centered at every yaw.
var yaw_deg := 0.0
var yaw_target_deg := 0.0

var _arm_length := 0.0
var _full_arm_length := 0.0
var _chest_offset := Vector3.ZERO

var _touch_index := -1
var _touch_travel_px := 0.0
var _touch_drag_active := false
var _mouse_dragging := false
var _mouse_travel_px := 0.0
var _mouse_drag_active := false
var _last_tap_ms := -1_000_000
var _last_tap_position := Vector2.ZERO


func _ready() -> void:
	process_priority = 100
	if config == null:
		config = CameraConfig.new()
	_configure_internal()


func configure(p_config: CameraConfig) -> void:
	config = p_config
	if is_inside_tree():
		_configure_internal()


func _configure_internal() -> void:
	_apply_config()
	_chest_offset = Vector3(0.0, config.camera_height_at_avatar, 0.0)
	_full_arm_length = (config.offset - _chest_offset).length()
	_arm_length = _full_arm_length
	if camera != null:
		camera.position = _rotated_offset()


func _apply_config() -> void:
	if camera == null:
		return
	camera.fov = config.fov_deg
	camera.near = 0.1
	camera.far = 400.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.rotation_degrees = Vector3(config.pitch_deg, yaw_deg, 0.0)


func set_target(position: Vector3) -> void:
	target_position = position
	if not initialized:
		smoothed_position = position
		initialized = true


func snap_to(position: Vector3) -> void:
	target_position = position
	smoothed_position = position
	initialized = true
	_arm_length = _full_arm_length
	_place_camera(0.0)


func shift_world(offset: Vector3) -> void:
	target_position += offset
	smoothed_position += offset


## Rotates the camera around the avatar. Positive values look west/left from
## the north-up orientation; input maps horizontal dragging to this method.
func add_yaw(delta_deg: float) -> void:
	yaw_deg = wrapf(yaw_deg + delta_deg, -180.0, 180.0)
	yaw_target_deg = yaw_deg
	_last_tap_ms = -1_000_000


## Smoothly returns the camera to north-up (used by the double tap gesture).
func reset_yaw() -> void:
	yaw_target_deg = 0.0
	_last_tap_ms = -1_000_000


func _process(delta: float) -> void:
	if not initialized:
		return
	delta = clampf(delta, 0.0, 0.1)
	var blend := 1.0 - exp(-delta / maxf(config.follow_tau, 0.0001))
	smoothed_position = smoothed_position.lerp(target_position, blend)
	_update_yaw(delta)
	_place_camera(delta)


func _update_yaw(delta: float) -> void:
	if is_equal_approx(yaw_deg, yaw_target_deg):
		yaw_deg = yaw_target_deg
		return
	var blend := 1.0 - exp(-delta / maxf(config.yaw_reset_tau, 0.0001))
	var next_rad := lerp_angle(deg_to_rad(yaw_deg), deg_to_rad(yaw_target_deg), blend)
	yaw_deg = wrapf(rad_to_deg(next_rad), -180.0, 180.0)


func _place_camera(delta: float) -> void:
	if camera == null:
		return
	position = Vector3(smoothed_position.x, 0.0, smoothed_position.z)

	var chest := smoothed_position + _chest_offset
	var desired := smoothed_position + _rotated_offset()
	var direction := (desired - chest).normalized()
	var wanted_length := _full_arm_length

	if is_inside_tree() and get_world_3d() != null:
		var space := get_world_3d().direct_space_state
		if space != null:
			var query := PhysicsRayQueryParameters3D.create(chest, desired, COLLISION_MASK)
			query.collide_with_areas = false
			query.collide_with_bodies = true
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				var hit_distance := chest.distance_to(hit["position"])
				wanted_length = clampf(hit_distance - config.spring_margin, config.spring_min_length, _full_arm_length)

	if wanted_length < _arm_length:
		_arm_length = wanted_length
	else:
		var recovery_step := _full_arm_length * delta / maxf(config.spring_recovery_s, 0.0001)
		_arm_length = move_toward(_arm_length, wanted_length, recovery_step)

	var camera_offset := _chest_offset + direction * _arm_length
	camera.position = camera_offset
	camera.rotation_degrees = Vector3(config.pitch_deg, yaw_deg, 0.0)


func _rotated_offset() -> Vector3:
	return config.offset.rotated(Vector3.UP, deg_to_rad(yaw_deg))


func _unhandled_input(event: InputEvent) -> void:
	if config == null:
		return
	if event is InputEventScreenTouch:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			_on_screen_touch(event)
	elif event is InputEventScreenDrag:
		if event.device != InputEvent.DEVICE_ID_EMULATION and event.index == _touch_index:
			_touch_travel_px += event.relative.length()
			if not _touch_drag_active:
				if _touch_travel_px <= config.drag_start_px:
					return
				_touch_drag_active = true
			apply_drag(event.relative.x)
	elif event is InputEventMouseButton:
		if event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT:
			_on_mouse_button(event)
	elif event is InputEventMouseMotion:
		if event.device != InputEvent.DEVICE_ID_EMULATION and _mouse_dragging:
			_mouse_travel_px += event.relative.length()
			if not _mouse_drag_active:
				if _mouse_travel_px <= config.drag_start_px:
					return
				_mouse_drag_active = true
			apply_drag(event.relative.x)


func _on_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index == -1:
			_touch_index = event.index
			_touch_travel_px = 0.0
			_touch_drag_active = false
	elif event.index == _touch_index:
		if not _touch_drag_active:
			_register_tap(event.position)
		_touch_index = -1
		_touch_drag_active = false


func _on_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed:
		_mouse_dragging = true
		_mouse_travel_px = 0.0
		_mouse_drag_active = false
	elif _mouse_dragging:
		_mouse_dragging = false
		if not _mouse_drag_active:
			_register_tap(event.position)
		_mouse_drag_active = false


## Applies a horizontal drag in viewport pixels: negative goes left.
func apply_drag(relative_x: float) -> void:
	var viewport_width := maxf(1.0, get_viewport().get_visible_rect().size.x)
	add_yaw(-relative_x * config.yaw_degrees_per_screen / viewport_width)


func _register_tap(position_px: Vector2) -> void:
	var now_ms := Time.get_ticks_msec()
	var window_ms := int(round(config.double_tap_window_s * 1000.0))
	var near := position_px.distance_to(_last_tap_position) <= config.double_tap_max_move_px
	if now_ms - _last_tap_ms <= window_ms and near:
		_last_tap_ms = -1_000_000
		reset_yaw()
	else:
		_last_tap_ms = now_ms
		_last_tap_position = position_px
