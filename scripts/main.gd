extends Node3D

## Vertical-slice entry point: GPS source -> movement model -> avatar/camera/HUD.

@onready var world_root: WorldRoot = $WorldRoot
@onready var avatar: AvatarController = $WorldRoot/Avatar
@onready var camera_rig: CameraRig = $WorldRoot/CameraRig
@onready var hud: DebugHud = $HUD
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $DirectionalLight3D
@onready var ground: MeshInstance3D = $Ground

var movement_config: MovementConfig
var camera_config: CameraConfig
var model: MovementModel
var gps: GpsSource

var _last_fix: GpsFix = null
var _raw_marker: MeshInstance3D
var _marker_visible := false


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.screen_set_keep_on(true)

	movement_config = MovementConfig.new()
	camera_config = CameraConfig.new()
	camera_rig.configure(camera_config)
	hud.setup(movement_config)
	_apply_environment()
	_build_ground()
	_build_landmarks()
	_build_raw_marker()

	model = MovementModel.new(movement_config)
	model.first_anchor.connect(_on_first_anchor)
	model.snap_occurred.connect(_on_snap)
	model.state_changed.connect(_on_state_changed)

	hud.start_gps_requested.connect(_on_start_gps_requested)
	hud.marker_toggled.connect(_on_marker_toggled)

	camera_rig.snap_to(Vector3.ZERO)
	_create_gps_source()


func _process(delta: float) -> void:
	var now_ns := Time.get_ticks_usec() * 1000
	model.tick(delta, now_ns)

	if model.has_anchor:
		avatar.apply_state(model.visual_position, model.heading, model.motion, delta)
		camera_rig.set_target(model.visual_position)

	if _last_fix != null and _raw_marker != null:
		_raw_marker.position = _last_fix.world + Vector3(0.0, 0.2, 0.0)

	hud.update_hud(model, _last_fix)


func _create_gps_source() -> void:
	var is_android := OS.has_feature("android")
	if is_android and Engine.has_singleton(AndroidGpsSource.PLUGIN_NAME):
		gps = AndroidGpsSource.new()
	else:
		gps = FakeGpsSource.new()
		if is_android:
			push_warning("GpsPlugin non trovato: fallback al fake GPS desktop.")

	gps.name = "GpsSource"
	add_child(gps)
	gps.fix_received.connect(_on_fix)
	gps.error_occurred.connect(_on_gps_error)
	gps.permission_result.connect(_on_permission_result)

	if gps.requires_permission():
		hud.show_permission_prompt()
	else:
		hud.show_waiting()
		gps.start()


func _on_start_gps_requested() -> void:
	hud.show_waiting()
	gps.start()


func _on_fix(fix: GpsFix) -> void:
	var now_ns := Time.get_ticks_usec() * 1000
	if fix.age_ns(now_ns) > int(movement_config.max_fix_age_s * 1_000_000_000.0):
		return

	if not world_root.has_anchor():
		if fix.accuracy > movement_config.accuracy_reject_m:
			return
		world_root.set_anchor(fix.latitude, fix.longitude)

	fix.world = world_root.to_world(fix.latitude, fix.longitude, 0.0)
	_last_fix = fix
	model.push_fix(fix, now_ns)

	var shift := world_root.rebase_if_needed(fix.latitude, fix.longitude)
	if shift != Vector3.ZERO:
		model.shift_world(-shift)
		camera_rig.shift_world(-shift)


func _on_first_anchor(position: Vector3) -> void:
	avatar.position = position
	camera_rig.snap_to(position)
	hud.fade_in_world(0.3)


func _on_snap(distance_m: float, reason: String) -> void:
	avatar.position = model.visual_position
	camera_rig.snap_to(model.visual_position)
	hud.flash_snap()
	hud.show_snap(distance_m, reason)


func _on_state_changed(state: int) -> void:
	if state == MovementModel.State.DENIED:
		hud.show_denied("Il GPS non è disponibile. Controlla il permesso di posizione e riprova.")
	elif state == MovementModel.State.INIT:
		hud.show_waiting()


func _on_permission_result(granted: bool) -> void:
	if granted:
		hud.show_waiting()
	else:
		model.set_denied()
		hud.show_denied("Permesso di posizione negato.\nServe la posizione precisa per giocare.")


func _on_gps_error(message: String) -> void:
	if message.begins_with("provider_disabled"):
		model.set_denied()
		hud.show_denied("Il provider GPS è stato disattivato.\nControlla la localizzazione e riprova.")
		return
	match message:
		"permission_denied", "missing_permission":
			model.set_denied()
			hud.show_denied("Permesso di posizione negato.\nServe la posizione precisa per giocare.")
		"coarse_only":
			model.set_denied()
			hud.show_denied("Hai concesso solo la posizione approssimativa.\nServe la posizione precisa: riapri il permesso e scegli “Precisa”.")
		"location_disabled":
			model.set_denied()
			hud.show_denied("La localizzazione del telefono è spenta.\nAttivala dalle impostazioni di Android e riprova.")
		"no_provider", "gps_start_failed", "start_failed":
			model.set_denied()
			hud.show_denied("Nessun provider GPS disponibile.\nControlla la localizzazione e riprova.")
		"gps_plugin_missing":
			model.set_denied()
			hud.show_denied("Plugin GPS non installato nell'APK.\nRicompila con il plugin Android.")
		_:
			push_warning("GPS error: %s" % message)


func _on_marker_toggled(visible: bool) -> void:
	_marker_visible = visible
	if _raw_marker != null:
		_raw_marker.visible = visible


func _apply_environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = camera_config.background_color
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(1.0, 1.0, 1.0)
	environment.ambient_light_energy = 0.7
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = camera_config.background_color
	environment.fog_light_energy = 1.0
	environment.fog_density = 1.0
	environment.fog_depth_begin = camera_config.fog_begin_m
	environment.fog_depth_end = camera_config.fog_end_m
	world_environment.environment = environment

	sun.rotation_degrees = Vector3(-45.0, -45.0, 0.0)
	sun.light_energy = 1.0
	sun.shadow_enabled = false


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(12000.0, 12000.0)
	ground.mesh = plane
	ground.position = Vector3.ZERO
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/world/grid.gdshader")
	ground.material_override = material


func _build_landmarks() -> void:
	var specs := [
		{"offset": Vector3(18.0, 0.0, -30.0), "size": Vector3(9.0, 12.0, 9.0), "color": Color("#c98b6b")},
		{"offset": Vector3(-26.0, 0.0, -44.0), "size": Vector3(12.0, 7.0, 10.0), "color": Color("#9fb0a5")},
		{"offset": Vector3(34.0, 0.0, 26.0), "size": Vector3(7.0, 18.0, 7.0), "color": Color("#b7a27c")},
		{"offset": Vector3(-38.0, 0.0, 32.0), "size": Vector3(14.0, 5.0, 9.0), "color": Color("#8fa3b5")},
		{"offset": Vector3(6.0, 0.0, -20.0), "size": Vector3(5.0, 8.0, 5.0), "color": Color("#b58f6a")},
	]
	for spec in specs:
		var body := StaticBody3D.new()
		body.collision_layer = 1 << 1
		body.collision_mask = 0
		body.position = spec["offset"]

		var size: Vector3 = spec["size"]
		var mesh_instance := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh_instance.mesh = box
		mesh_instance.position.y = size.y * 0.5
		var material := StandardMaterial3D.new()
		material.albedo_color = spec["color"]
		material.roughness = 1.0
		mesh_instance.material_override = material
		body.add_child(mesh_instance)

		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		collision.position.y = size.y * 0.5
		body.add_child(collision)
		world_root.add_child(body)


func _build_raw_marker() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	sphere.radial_segments = 12
	sphere.rings = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.MAGENTA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_raw_marker = MeshInstance3D.new()
	_raw_marker.mesh = sphere
	_raw_marker.material_override = material
	_raw_marker.visible = false
	world_root.add_child(_raw_marker)
