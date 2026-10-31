class_name CameraRig
extends Node3D

## Fixed north-up follow camera with a collision arm (ticket 08).

const COLLISION_MASK := 1 << 1  # layer 2: building chunks

@export var config: CameraConfig
@onready var camera: Camera3D = $Camera3D

var target_position := Vector3.ZERO
var smoothed_position := Vector3.ZERO
var initialized := false

var _arm_length := 0.0
var _full_arm_length := 0.0
var _chest_offset := Vector3.ZERO


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
		camera.position = config.offset


func _apply_config() -> void:
	if camera == null:
		return
	camera.fov = config.fov_deg
	camera.near = 0.1
	camera.far = 400.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.rotation_degrees = Vector3(config.pitch_deg, 0.0, 0.0)


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


func _process(delta: float) -> void:
	if not initialized:
		return
	delta = clampf(delta, 0.0, 0.1)
	var blend := 1.0 - exp(-delta / maxf(config.follow_tau, 0.0001))
	smoothed_position = smoothed_position.lerp(target_position, blend)
	_place_camera(delta)


func _place_camera(delta: float) -> void:
	if camera == null:
		return
	position = Vector3(smoothed_position.x, 0.0, smoothed_position.z)

	var chest := smoothed_position + _chest_offset
	var desired := smoothed_position + config.offset
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
	camera.rotation_degrees = Vector3(config.pitch_deg, 0.0, 0.0)
