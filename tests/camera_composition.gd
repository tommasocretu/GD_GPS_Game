extends SceneTree

## Headless camera composition check (ticket 08): feet at 65% +/- 2%,
## projected height 8.5-9.5%, avatar horizontally centered.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(1.0).timeout
	var cam: Camera3D = scene.get_node("WorldRoot/CameraRig/Camera3D")
	var avatar: Node3D = scene.get_node("WorldRoot/Avatar")
	var screen := root.get_visible_rect().size
	var feet := cam.unproject_position(avatar.global_position)
	var head := cam.unproject_position(avatar.global_position + Vector3(0.0, 1.858, 0.0))
	var feet_pct := feet.y / screen.y
	var height_pct := (feet.y - head.y) / screen.y
	var x_pct := feet.x / screen.x
	print("camera composition: feet=%.3f height=%.3f x=%.3f" % [feet_pct, height_pct, x_pct])
	var ok := absf(feet_pct - 0.65) <= 0.02 and height_pct >= 0.085 and height_pct <= 0.095 and absf(x_pct - 0.5) <= 0.02
	quit(0 if ok else 1)
