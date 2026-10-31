class_name AndroidGpsSource
extends GpsSource

## Wrapper around the internal Android v2 plugin (ticket 01).

const PLUGIN_NAME := "GpsPlugin"
const FINE := "android.permission.ACCESS_FINE_LOCATION"
const COARSE := "android.permission.ACCESS_COARSE_LOCATION"

var _gps: Object = null
var _want_running := false
var _denied_reported := false


func _ready() -> void:
	if not Engine.has_singleton(PLUGIN_NAME):
		return
	_gps = Engine.get_singleton(PLUGIN_NAME)
	_gps.location_fix.connect(_on_location_fix)
	_gps.location_error.connect(_on_location_error)
	var tree := get_tree()
	if not tree.on_request_permissions_result.is_connected(_on_permission_result):
		tree.on_request_permissions_result.connect(_on_permission_result)


func start() -> void:
	_want_running = true
	_denied_reported = false
	if _gps == null:
		error_occurred.emit("gps_plugin_missing")
		return
	if _has_fine():
		_start_native()
		return
	var all_granted := OS.request_permissions()
	if all_granted:
		_start_native()


func stop() -> void:
	_want_running = false
	if _gps != null:
		_gps.stop_updates()


func requires_permission() -> bool:
	return _gps != null and not _has_fine()


func is_fake() -> bool:
	return false


func _has_fine() -> bool:
	return OS.get_granted_permissions().has(FINE)


func _start_native() -> void:
	if _gps == null:
		return
	var ok: bool = _gps.start_updates(1000, 500, 1.0)
	if ok:
		permission_result.emit(true)
	else:
		error_occurred.emit("gps_start_failed")


func _on_location_fix(data: Dictionary) -> void:
	var now_ns := Time.get_ticks_usec() * 1000
	var fix := GpsFix.from_dictionary(data, now_ns)
	fix_received.emit(fix)


func _on_location_error(message: String) -> void:
	error_occurred.emit(message)


func _on_permission_result(permission: String, granted: bool) -> void:
	if permission == FINE:
		if granted:
			_start_native()
		elif not _denied_reported:
			_denied_reported = true
			permission_result.emit(false)
			if OS.get_granted_permissions().has(COARSE):
				error_occurred.emit("coarse_only")
			else:
				error_occurred.emit("permission_denied")
	elif permission == COARSE and not granted and not _denied_reported:
		_denied_reported = true
		permission_result.emit(false)
		error_occurred.emit("permission_denied")


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_APPLICATION_PAUSED:
		if _gps != null:
			_gps.stop_updates()
	elif what == MainLoop.NOTIFICATION_APPLICATION_RESUMED:
		if _want_running and _gps != null and _has_fine():
			_start_native()
