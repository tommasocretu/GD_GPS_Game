extends SceneTree

## Headless deterministic tests for the coordinate frame and movement model.
## Run with:
##   flatpak run org.godotengine.Godot --headless --path . --script res://tests/run_tests.gd

const GeoFrameScript := preload("res://scripts/core/geo_frame.gd")
const MovementConfigScript := preload("res://scripts/movement/movement_config.gd")
const MovementModelScript := preload("res://scripts/movement/movement_model.gd")
const GpsFixScript := preload("res://scripts/gps/gps_fix.gd")

var _failures := 0
var _checks := 0


func _initialize() -> void:
	print("== GeoFrame ==")
	_test_geo_frame()
	print("== Movement model ==")
	_test_anchor_gate()
	_test_stationary_lock()
	_test_straight_line()
	_test_jump_10m()
	_test_jump_40m()
	_test_stale_and_lost()
	_test_weak_accuracy()
	_test_outlier_confirmation()
	_test_heading()
	_test_rebase_shift()

	print("")
	print("%d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		printerr("FAIL: ", message)


func _approx(actual: float, expected: float, epsilon: float, message: String) -> void:
	_expect(absf(actual - expected) <= epsilon, "%s (actual %.9f, expected %.9f)" % [message, actual, expected])


func _test_geo_frame() -> void:
	var frame := GeoFrameScript.new(45.0, 12.0)
	var origin := frame.to_world(45.0, 12.0, 0.0, 0.0, 0.0)
	_expect(origin.length() < 0.000001, "anchor projects to zero")

	var north_lat: float = 45.0 + rad_to_deg(1000.0 / frame.m0)
	var north := frame.to_world(north_lat, 12.0, 0.0, 0.0, 0.0)
	_approx(north.z, -1000.0, 0.001, "1 km north is -Z")
	_approx(north.x, 0.0, 0.001, "1 km north has no east component")

	var east_lon: float = 12.0 + rad_to_deg(1000.0 / frame.east_scale)
	var east := frame.to_world(45.0, east_lon, 0.0, 0.0, 0.0)
	_approx(east.x, 1000.0, 0.001, "1 km east is +X")
	_approx(east.z, 0.0, 0.001, "1 km east has no north component")

	var roundtrip := frame.from_world(Vector3(123.4, 0.0, -567.8), 0.0, 0.0)
	_approx(roundtrip[0], 45.0 + rad_to_deg(567.8 / frame.m0), 1e-9, "round-trip latitude")
	_approx(roundtrip[1], 12.0 + rad_to_deg(123.4 / frame.east_scale), 1e-9, "round-trip longitude")

	var tile := GeoFrameScript.lonlat_to_tile(35.6590699, 139.7006793, 18)
	_expect(tile == Vector2i(232798, 103246), "Hachiko tile index")
	_approx(GeoFrameScript.tile_lat_n(103246, 18), 35.6595278649, 1e-9, "tile north edge")
	_approx(GeoFrameScript.tile_lon_w(232798, 18), 139.6994018555, 1e-9, "tile west edge")
	_approx(GeoFrameScript.tile_lat_n(103247, 18), 35.6584120643, 1e-9, "tile south edge")
	_approx(GeoFrameScript.tile_lon_w(232799, 18), 139.7007751465, 1e-9, "tile east edge")

	var tile45 := GeoFrameScript.lonlat_to_tile(45.0, 12.0, 18)
	var rect := frame.tile_world_rect(18, tile45.x, tile45.y, 0.0, 0.0)
	_approx(rect.size.x, 108.2797, 0.01, "z18 tile width at 45N")
	_approx(rect.size.y, 107.9160, 0.01, "z18 tile height at 45N")


func _test_anchor_gate() -> void:
	var model := _new_model()
	var t := 1_000_000_000
	model.push_fix(_fix(Vector3.ZERO, 30.0, 0.0, t), t)
	_expect(not model.has_anchor, "accuracy 30 m does not create the anchor")
	_expect(model.state == MovementModel.State.INIT, "state is INIT before the anchor")
	t += 1_000_000_000
	model.push_fix(_fix(Vector3.ZERO, 10.0, 0.0, t), t)
	_expect(model.has_anchor, "accuracy 10 m creates the anchor")


func _test_stationary_lock() -> void:
	var model := _new_model()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var t := 1_000_000_000
	var visual_before := Vector3.ZERO
	for i in 120:
		var offset := Vector3(rng.randfn(0.0, 5.0), 0.0, rng.randfn(0.0, 5.0))
		model.push_fix(_fix(offset, 5.0, 0.1, t), t)
		t = _tick_seconds(model, 1.0, t)
		if i == 110:
			visual_before = model.visual_position
	_expect(model.locked, "stationary fixes lock the avatar")
	_expect(model.motion == MovementModel.Motion.IDLE, "locked avatar is idle")
	_expect(visual_before.distance_to(model.visual_position) < 0.5, "locked avatar drifts less than 0.5 m over 10 s")


func _test_straight_line() -> void:
	# No-noise run: the visual must track the true path with less than 1 m RMS.
	var clean := _new_model()
	var clean_t := 1_000_000_000
	var clean_sum_sq := 0.0
	var clean_max := 0.0
	var clean_samples := 0
	for i in 120:
		var truth := Vector3(0.0, 0.0, -1.4 * i)
		clean.push_fix(_fix(truth, 5.0, 1.4, clean_t), clean_t)
		clean_t = _tick_seconds(clean, 1.0, clean_t)
		if i > 10:
			var error := clean.visual_position.distance_to(truth)
			clean_sum_sq += error * error
			clean_max = maxf(clean_max, error)
			clean_samples += 1
	var clean_rms := sqrt(clean_sum_sq / maxf(1.0, float(clean_samples)))
	_expect(clean_rms < 1.0, "clean straight line RMS < 1 m (actual %.2f)" % clean_rms)
	_expect(clean_max < 2.0, "clean straight line max error < 2 m (actual %.2f)" % clean_max)
	_expect(clean.heading.z < -0.9, "heading points north while walking north")

	# Noisy run: the filter cannot remove 5 m measurement noise, but the
	# visual must follow the filtered target and never snap.
	var model := _new_model()
	var snaps := []
	model.snap_occurred.connect(func(distance: float, reason: String) -> void: snaps.append([distance, reason]))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var t := 1_000_000_000
	var sum_sq := 0.0
	var max_error := 0.0
	var samples := 0
	for i in 120:
		var truth := Vector3(0.0, 0.0, -1.4 * i)
		var offset := Vector3(rng.randfn(0.0, 5.0), 0.0, rng.randfn(0.0, 5.0))
		model.push_fix(_fix(truth + offset, 5.0, 1.4, t), t)
		t = _tick_seconds(model, 1.0, t)
		if i > 10:
			var error := model.visual_position.distance_to(model.target_position)
			sum_sq += error * error
			max_error = maxf(max_error, error)
			samples += 1
	var rms := sqrt(sum_sq / maxf(1.0, float(samples)))
	_expect(rms < 0.5, "noisy line: visual follows target, RMS < 0.5 m (actual %.2f)" % rms)
	_expect(max_error < 1.0, "noisy line: visual follows target, max < 1 m (actual %.2f)" % max_error)
	_expect(snaps.is_empty(), "noisy straight line produces no snap")


func _test_jump_10m() -> void:
	var model := _new_model()
	var snaps := []
	model.snap_occurred.connect(func(distance: float, reason: String) -> void: snaps.append([distance, reason]))
	var t := 1_000_000_000
	for i in 5:
		model.push_fix(_fix(Vector3.ZERO, 5.0, 0.1, t), t)
		t = _tick_seconds(model, 1.0, t)
	var jump := Vector3(10.0, 0.0, 0.0)
	model.push_fix(_fix(jump, 5.0, 1.4, t), t)
	t = _tick_seconds(model, 1.0, t)
	model.push_fix(_fix(jump, 5.0, 1.4, t), t)
	t = _tick_seconds(model, 0.9, t)
	_expect(snaps.is_empty(), "10 m jump is corrected, not snapped")
	_expect(model.visual_position.distance_to(jump) < 0.6, "10 m jump recovered within 0.9 s")


func _test_jump_40m() -> void:
	var model := _new_model()
	var snaps := []
	model.snap_occurred.connect(func(distance: float, reason: String) -> void: snaps.append([distance, reason]))
	var t := 1_000_000_000
	for i in 5:
		model.push_fix(_fix(Vector3.ZERO, 5.0, 0.1, t), t)
		t = _tick_seconds(model, 1.0, t)
	var jump := Vector3(40.0, 0.0, 0.0)
	model.push_fix(_fix(jump, 5.0, 1.4, t), t)
	t = _tick_seconds(model, 1.0, t)
	model.push_fix(_fix(jump, 5.0, 1.4, t), t)
	t = _tick_seconds(model, 0.1, t)
	_expect(snaps.size() == 1, "40 m jump produces exactly one snap (actual %d)" % snaps.size())
	_expect(model.last_snap.get("reason", "") == "distance", "snap reason is distance")
	_expect(model.visual_position.distance_to(jump) < 0.01, "snap lands on the target")


func _test_stale_and_lost() -> void:
	var model := _new_model()
	var t := 1_000_000_000
	model.push_fix(_fix(Vector3.ZERO, 5.0, 0.1, t), t)
	model.tick(0.1, t + 3_000_000_000)
	_expect(model.state == MovementModel.State.STALE, "fix older than 2 s is STALE")
	var frozen := model.visual_position
	model.tick(0.1, t + 3_500_000_000)
	_expect(model.visual_position == frozen, "avatar does not move while STALE")
	model.tick(0.1, t + 11_000_000_000)
	_expect(model.state == MovementModel.State.LOST, "fix older than 10 s is LOST")


func _test_weak_accuracy() -> void:
	var model := _new_model()
	var t := 1_000_000_000
	model.push_fix(_fix(Vector3.ZERO, 5.0, 0.1, t), t)
	t = _tick_seconds(model, 1.0, t)
	for i in 30:
		var truth := Vector3(0.0, 0.0, -2.0 * i)
		model.push_fix(_fix(truth, 40.0, 1.4, t), t)
		t = _tick_seconds(model, 1.0, t)
	_expect(model.state == MovementModel.State.WEAK, "accuracy 40 m is WEAK")
	_expect(model.speed_mps <= 0.85, "WEAK speed is capped at 0.8 m/s (actual %.2f)" % model.speed_mps)


func _test_outlier_confirmation() -> void:
	var model := _new_model()
	var t := 1_000_000_000
	for i in 5:
		model.push_fix(_fix(Vector3.ZERO, 5.0, -1.0, t), t)
		t = _tick_seconds(model, 1.0, t)
	var outlier := Vector3(20.0, 0.0, 0.0)
	model.push_fix(_fix(outlier, 5.0, -1.0, t), t)
	t = _tick_seconds(model, 1.0, t)
	model.push_fix(_fix(Vector3.ZERO, 5.0, -1.0, t), t)
	t = _tick_seconds(model, 1.0, t)
	_expect(model.visual_position.distance_to(Vector3.ZERO) < 0.6, "isolated outlier is discarded")

	model.push_fix(_fix(outlier, 5.0, -1.0, t), t)
	t = _tick_seconds(model, 1.0, t)
	model.push_fix(_fix(outlier, 5.0, -1.0, t), t)
	t = _tick_seconds(model, 1.0, t)
	model.push_fix(_fix(outlier, 5.0, -1.0, t), t)
	t = _tick_seconds(model, 0.1, t)
	_expect(model.visual_position.distance_to(outlier) < 0.01, "confirmed outlier becomes movement")
	_expect(not model.last_snap.is_empty(), "confirmed 20 m outlier produces a snap")


func _test_heading() -> void:
	var model := _new_model()
	var t := 1_000_000_000
	for i in 10:
		model.push_fix(_fix(Vector3(2.0 * i, 0.0, 0.0), 5.0, 1.4, t), t)
		t = _tick_seconds(model, 1.0, t)
	_expect(model.heading.x > 0.9, "heading points east while walking east")
	_approx(model.heading_degrees(), 90.0, 5.0, "heading degrees is ~90 east")


func _test_rebase_shift() -> void:
	var model := _new_model()
	var t := 1_000_000_000
	model.push_fix(_fix(Vector3(10.0, 0.0, -10.0), 5.0, 1.4, t), t)
	t = _tick_seconds(model, 1.0, t)
	var before := model.visual_position
	var target_before := model.target_position
	model.shift_world(Vector3(-2000.0, 0.0, 0.0))
	_expect(model.visual_position.is_equal_approx(before + Vector3(-2000.0, 0.0, 0.0)), "rebase shifts the visual position")
	_expect(model.target_position.is_equal_approx(target_before + Vector3(-2000.0, 0.0, 0.0)), "rebase shifts the target")

	var snaps := []
	model.snap_occurred.connect(func(distance: float, reason: String) -> void: snaps.append([distance, reason]))
	var shifted := model.visual_position
	model.push_fix(_fix(shifted, 5.0, 1.4, t), t)
	t = _tick_seconds(model, 1.0, t)
	_expect(snaps.is_empty(), "rebase does not snap on the next fix")
	_expect(model.visual_position.distance_to(shifted) < 0.5, "rebase keeps the next fix continuous")


func _new_model() -> MovementModel:
	return MovementModelScript.new(MovementConfigScript.new())


func _fix(position: Vector3, accuracy: float, speed: float, received_ns: int) -> GpsFix:
	var fix: GpsFix = GpsFixScript.new()
	fix.world = position
	fix.accuracy = accuracy
	fix.speed = speed
	fix.received_ns = received_ns
	fix.age_ms = 0.0
	fix.latitude = 45.0
	fix.longitude = 9.0
	fix.is_mock = true
	return fix


func _tick_seconds(model: MovementModel, seconds: float, start_ns: int) -> int:
	var steps := int(round(seconds * 10.0))
	for i in steps:
		model.tick(0.1, start_ns + int((i + 1) * 100_000_000))
	return start_ns + int(seconds * 1_000_000_000.0)
