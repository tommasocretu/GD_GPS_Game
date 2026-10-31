class_name AvatarController
extends Node3D

## Applies the movement model output to the visual avatar.

const MODEL_PATH := "res://assets/avatar/casual_male.glb"
const CROSSFADE_S := 0.2
const MAX_TURN_RATE_DEG := 180.0

var model: Node3D = null
var anim_player: AnimationPlayer = null

var _clips: Dictionary = {}
var _current_motion := -1


func _ready() -> void:
	_instantiate_model()
	_collect_animations()
	_play_motion(MovementModel.Motion.IDLE, true)


func apply_state(world_position: Vector3, heading: Vector3, motion: int, delta: float) -> void:
	position = world_position
	if heading.length_squared() > 0.0001:
		var target_yaw := atan2(heading.x, heading.z)
		rotation.y = rotate_toward(rotation.y, target_yaw, deg_to_rad(MAX_TURN_RATE_DEG) * delta)
	_play_motion(motion, false)


func _instantiate_model() -> void:
	if ResourceLoader.exists(MODEL_PATH):
		var packed: PackedScene = load(MODEL_PATH)
		var instance := packed.instantiate() if packed != null else null
		if instance is Node3D:
			model = instance
			add_child(model)
			return
	model = Node3D.new()
	model.name = "PlaceholderAvatar"
	var capsule := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.8
	capsule.mesh = mesh
	capsule.position.y = 0.9
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#e07a3f")
	material.roughness = 1.0
	capsule.material_override = material
	model.add_child(capsule)
	add_child(model)


func _collect_animations() -> void:
	anim_player = _find_animation_player(model)
	if anim_player == null:
		return
	for clip_name in anim_player.get_animation_list():
		var animation := anim_player.get_animation(clip_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
		_clips[_match_clip(clip_name)] = clip_name


func _match_clip(clip_name: String) -> String:
	var short_name := clip_name
	var separator := clip_name.rfind("|")
	if separator >= 0:
		short_name = clip_name.substr(separator + 1)
	match short_name:
		"Idle", "Idle_Neutral":
			return "Idle"
		"Walk":
			return "Walk"
		"Run":
			return "Run"
		_:
			return short_name


func _play_motion(motion: int, force: bool) -> void:
	if not force and motion == _current_motion:
		return
	_current_motion = motion
	if anim_player == null:
		return
	var wanted := "Idle"
	match motion:
		MovementModel.Motion.WALK:
			wanted = "Walk"
		MovementModel.Motion.RUN:
			wanted = "Run"
	if not _clips.has(wanted):
		wanted = "Idle"
	if not _clips.has(wanted):
		return
	anim_player.play(_clips[wanted], CROSSFADE_S)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
