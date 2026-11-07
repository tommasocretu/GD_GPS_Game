extends SceneTree

## Headless camera yaw check: one-finger drag orbit, composition and double tap
## reset. Run with:
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/camera_yaw.gd

const FULL_OFFSET := Vector3(0.0, 11.375, 16.1875)

var _failures := 0
var _checks := 0
var _rig: CameraRig


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(0.6).timeout

	var rig: CameraRig = scene.get_node("WorldRoot/CameraRig")
	var camera: Camera3D = scene.get_node("WorldRoot/CameraRig/Camera3D")
	var avatar: Node3D = scene.get_node("WorldRoot/Avatar")
	var screen := root.get_visible_rect().size
	var start := Vector2(screen.x * 0.5, screen.y * 0.5)
	_rig = rig

	_approx(rig.yaw_deg, 0.0, 0.01, "camera starts north-up")
	var offset := camera.global_position - avatar.global_position
	_expect(offset.z > 10.0 and absf(offset.x) < 0.01, "camera starts south of the avatar")

	# Half-screen drag to the left: +90° yaw, the camera orbits east.
	_send_touch(start, true)
	_send_drag(start, Vector2(-screen.x * 0.5, 0.0))
	_send_touch(start + Vector2(-screen.x * 0.5, 0.0), false)
	await create_timer(0.1).timeout
	_approx(rig.yaw_deg, 90.0, 0.5, "drag left half screen turns the view 90° left")
	offset = camera.global_position - avatar.global_position
	_approx(offset.x, FULL_OFFSET.z, 0.1, "camera orbits east at yaw 90")
	_approx(offset.z, 0.0, 0.1, "camera has no south offset at yaw 90")
	_approx(offset.length(), FULL_OFFSET.length(), 0.1, "orbit preserves the arm length")
	_expect(_looks_at_avatar(camera, avatar), "camera looks at the avatar at yaw 90")
	_check_composition(camera, avatar, screen, "yaw 90")

	# Full-screen mouse drag to the right: 90° -> -90°, the camera orbits west.
	_send_mouse_press(start)
	_send_mouse_motion(start, Vector2(screen.x, 0.0))
	_send_mouse_release(start + Vector2(screen.x, 0.0))
	await create_timer(0.1).timeout
	_approx(rig.yaw_deg, -90.0, 0.5, "mouse drag right full screen turns the view 180° right")
	offset = camera.global_position - avatar.global_position
	_approx(offset.x, -FULL_OFFSET.z, 0.1, "camera orbits west at yaw -90")
	_approx(offset.z, 0.0, 0.1, "camera has no south offset at yaw -90")
	_expect(_looks_at_avatar(camera, avatar), "camera looks at the avatar at yaw -90")
	_check_composition(camera, avatar, screen, "yaw -90")

	# Double tap anywhere in the world returns smoothly to north-up.
	rig.add_yaw(90.0 - rig.yaw_deg)
	await create_timer(0.1).timeout
	_approx(rig.yaw_deg, 90.0, 0.01, "test starts from yaw 90")
	_send_touch(start, true)
	_send_drag(start, Vector2(2.0, 0.0))
	_send_drag(start, Vector2(2.0, 0.0))
	_send_touch(start + Vector2(4.0, 0.0), false)
	await create_timer(0.1).timeout
	_approx(rig.yaw_deg, 90.0, 0.01, "sub-slop jitter does not rotate or cancel a tap")
	_send_tap(start + Vector2(2.0, 0.0))
	await create_timer(1.2).timeout
	_approx(rig.yaw_deg, 0.0, 1.0, "double tap returns to north")
	offset = camera.global_position - avatar.global_position
	_expect(offset.z > 10.0 and absf(offset.x) < 0.1, "reset puts the camera back south")

	print("camera yaw: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check_composition(camera: Camera3D, avatar: Node3D, screen: Vector2, label: String) -> void:
	var feet := camera.unproject_position(avatar.global_position)
	var head := camera.unproject_position(avatar.global_position + Vector3(0.0, 1.858, 0.0))
	var feet_pct := feet.y / screen.y
	var height_pct := (feet.y - head.y) / screen.y
	var x_pct := feet.x / screen.x
	_approx(feet_pct, 0.65, 0.02, "feet stay at 65%% (%s)" % label)
	_expect(height_pct >= 0.085 and height_pct <= 0.095, "avatar stays 8.5-9.5%% tall (%s)" % label)
	_approx(x_pct, 0.5, 0.02, "avatar stays horizontally centered (%s)" % label)


func _looks_at_avatar(camera: Camera3D, avatar: Node3D) -> bool:
	var forward := -camera.global_transform.basis.z
	forward.y = 0.0
	var to_avatar := avatar.global_position - camera.global_position
	to_avatar.y = 0.0
	return forward.normalized().dot(to_avatar.normalized()) > 0.99


## Feed events to the rig directly: the headless window transform would
## otherwise rescale Input.parse_input_event drag distances.
func _send_touch(position_px: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = position_px
	event.pressed = pressed
	_rig._unhandled_input(event)


func _send_drag(position_px: Vector2, relative_px: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = position_px
	event.relative = relative_px
	_rig._unhandled_input(event)


func _send_tap(position_px: Vector2) -> void:
	_send_touch(position_px, true)
	_send_touch(position_px, false)


func _send_mouse_press(position_px: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_MOUSE
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position_px
	event.pressed = true
	_rig._unhandled_input(event)


func _send_mouse_motion(position_px: Vector2, relative_px: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.device = InputEvent.DEVICE_ID_MOUSE
	event.position = position_px
	event.relative = relative_px
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_rig._unhandled_input(event)


func _send_mouse_release(position_px: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_MOUSE
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position_px
	event.pressed = false
	_rig._unhandled_input(event)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _approx(actual: float, expected: float, epsilon: float, message: String) -> void:
	_expect(absf(actual - expected) <= epsilon, "%s (actual %.6f, expected %.6f)" % [message, actual, expected])
