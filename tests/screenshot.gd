extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var scene: Node = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	await create_timer(10.0).timeout
	var image := root.get_texture().get_image()
	var error := image.save_png("res://screenshot_walk.png")
	print("screenshot saved: ", error, " size=", image.get_size())
	quit()
