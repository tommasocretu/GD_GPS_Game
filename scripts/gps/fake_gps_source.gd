class_name FakeGpsSource
extends GpsSource

## Desktop development source: WASD moves a virtual GPS position.
## Shift = run. Fixes are emitted at 1 Hz, like the real Android source.

const WALK_SPEED := 1.4
const RUN_SPEED := 5.0
const INTERVAL_S := 1.0

var start_lat: float
var start_lon: float
var accuracy := 5.0

var _frame: GeoFrame
var _east := 0.0
var _north := 0.0
var _speed := 0.0
var _bearing := 0.0
var _running := false
var _accum := 0.0
var _auto_walk := false


func _init() -> void:
	start_lat = float(ProjectSettings.get_setting("gps/fake_start_lat", 45.4642))
	start_lon = float(ProjectSettings.get_setting("gps/fake_start_lon", 9.1900))
	_frame = GeoFrame.new(start_lat, start_lon)
	_auto_walk = OS.get_cmdline_user_args().has("--auto-walk")


func _ready() -> void:
	set_process(false)


func start() -> void:
	_running = true
	set_process(true)
	_emit_fix()


func stop() -> void:
	_running = false
	set_process(false)


func is_fake() -> bool:
	return true


func teleport(lat: float, lon: float) -> void:
	start_lat = lat
	start_lon = lon
	_frame = GeoFrame.new(lat, lon)
	_east = 0.0
	_north = 0.0
	_emit_fix()


func _process(delta: float) -> void:
	if not _running:
		return

	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		direction.y += 1.0
	if Input.is_key_pressed(KEY_S):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_D):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_A):
		direction.x -= 1.0
	if direction == Vector2.ZERO and _auto_walk:
		direction = Vector2(0.0, 1.0)
	direction = direction.normalized()

	var target_speed := 0.0
	if direction != Vector2.ZERO:
		target_speed = RUN_SPEED if Input.is_key_pressed(KEY_SHIFT) else WALK_SPEED
		_bearing = rad_to_deg(atan2(direction.x, direction.y))
	_speed = target_speed
	_east += direction.x * _speed * delta
	_north += direction.y * _speed * delta

	_accum += delta
	if _accum >= INTERVAL_S:
		_accum = fmod(_accum, INTERVAL_S)
		_emit_fix()


func _emit_fix() -> void:
	var lat := _frame.lat0 + rad_to_deg(_north / _frame.m0)
	var lon := _frame.lon0 + rad_to_deg(_east / _frame.east_scale)
	var now_ns := Time.get_ticks_usec() * 1000
	var data := {
		"latitude": lat,
		"longitude": lon,
		"accuracy": accuracy,
		"altitude": 0.0,
		"speed": _speed,
		"bearing": _bearing,
		"time_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"elapsed_ns": now_ns,
		"age_ms": 0.0,
		"is_mock": true,
	}
	fix_received.emit(GpsFix.from_dictionary(data, now_ns))
