class_name MovementModel
extends RefCounted

## GPS fix -> filtered target -> visual avatar position (ticket 07).
##
## The model is pure logic: it never touches nodes. The main scene feeds fixes
## in the current world frame and reads visual_position / heading / motion.

signal state_changed(new_state: int)
signal first_anchor(position: Vector3)
signal snap_occurred(distance_m: float, reason: String)
signal locked_changed(is_locked: bool)

enum State { INIT, OK, WEAK, STALE, LOST, DENIED }
enum Motion { IDLE, WALK, RUN }

var config: MovementConfig
var state: State = State.INIT
var motion: Motion = Motion.IDLE
var visual_position := Vector3.ZERO
var target_position := Vector3.ZERO
var anchor_position := Vector3.ZERO
var has_anchor := false
var locked := false
var lock_position := Vector3.ZERO
var heading := Vector3.ZERO
var speed_mps := 0.0
var last_fix: GpsFix = null
var last_fix_age_s := 0.0
var last_snap: Dictionary = {}

var _velocity := Vector3.ZERO
var _recent_fixes: Array[GpsFix] = []
var _candidate: GpsFix = null
var _candidate_hits := 0
var _last_valid_received_ns := 0
var _still_since_ns := 0
var _still_window: Array[Dictionary] = []
var _heading_anchor := Vector3.ZERO
var _correction_active := false
var _correction_start := Vector3.ZERO
var _correction_elapsed := 0.0
var _previous_visual := Vector3.ZERO
var _speed_filtered := 0.0
var _frozen_by_accuracy := false


func _init(p_config: MovementConfig = null) -> void:
	config = p_config if p_config != null else MovementConfig.new()


func set_denied() -> void:
	_set_state(State.DENIED)
	speed_mps = 0.0
	motion = Motion.IDLE


func push_fix(fix: GpsFix, now_ns: int) -> void:
	last_fix = fix
	last_fix_age_s = fix.age_ns(now_ns) / 1_000_000_000.0

	if state == State.DENIED:
		return

	if not has_anchor:
		_update_state_from_age(now_ns)
		if last_fix_age_s > config.max_fix_age_s:
			return
		if fix.accuracy <= 20.0:
			_create_anchor(fix)
		return

	_update_state_from_age(now_ns)
	if last_fix_age_s > config.max_fix_age_s:
		return

	if fix.accuracy > config.accuracy_reject_m:
		_frozen_by_accuracy = true
		_candidate = null
		_candidate_hits = 0
		return
	_frozen_by_accuracy = false

	# Outliers need confirmation from the next fix before they move the avatar.
	# Doppler speed above the unlock threshold is a reliable movement hint, so
	# a walking user is not blocked by the confirmation step.
	var moving_hint := fix.has_speed() and fix.speed > config.unlock_speed
	var distance := fix.world.distance_to(target_position)
	var threshold := maxf(3.0, 2.0 * fix.accuracy)
	var large_jump := distance > config.snap_distance_m
	if distance > threshold and (not moving_hint or large_jump):
		if _candidate == null:
			_candidate = fix
			_candidate_hits = 0
			return
		var candidate_distance := fix.world.distance_to(_candidate.world)
		var target_distance := fix.world.distance_to(target_position)
		# A real jump is much closer to the candidate than to the old target.
		# Two independent noise samples can also be mutually close, so require
		# the candidate to be the clear nearest explanation.
		var coherent := candidate_distance <= maxf(3.0, 2.0 * fix.accuracy) \
			and candidate_distance < target_distance * 0.5
		if coherent:
			_candidate_hits += 1
			# Medium jumps (15-30 m) need two confirming fixes: a single pair
			# of 3-sigma noise samples must not teleport the avatar. Larger
			# jumps are unambiguous and snap after one confirmation.
			var required_hits := 2 if distance <= config.snap_distance_m * 2.0 else 1
			if _candidate_hits < required_hits:
				_candidate = fix
				return
			# Keep the candidate in the filter window, but only the newest fix
			# may trigger a correction or a snap: one jump = one event.
			var confirmed := _candidate
			_candidate = null
			_candidate_hits = 0
			_recent_fixes.append(confirmed)
			if _recent_fixes.size() > 2:
				_recent_fixes.pop_front()
			_last_valid_received_ns = confirmed.received_ns
			_apply_valid_fix(fix, now_ns)
		else:
			_candidate = fix
			_candidate_hits = 0
		return

	_candidate = null
	_candidate_hits = 0
	_apply_valid_fix(fix, now_ns)


func tick(delta: float, now_ns: int) -> void:
	delta = clampf(delta, 0.0, 0.1)
	_update_state_from_age(now_ns)

	if not has_anchor:
		return

	if state == State.STALE or state == State.LOST or state == State.DENIED or _frozen_by_accuracy:
		speed_mps = 0.0
		motion = Motion.IDLE
		return

	if state == State.WEAK and _correction_active:
		_correction_active = false
		_velocity = Vector3.ZERO

	if _correction_active:
		_correction_elapsed += delta
		var t := clampf(_correction_elapsed / config.correction_time_s, 0.0, 1.0)
		visual_position = _correction_start.lerp(target_position, smoothstep(0.0, 1.0, t))
		if t >= 1.0:
			_correction_active = false
			_velocity = Vector3.ZERO
	else:
		var smooth := config.weak_smooth_time if state == State.WEAK else config.smooth_time
		var max_speed := config.weak_max_speed if state == State.WEAK else config.max_speed
		var result := _smooth_damp(visual_position, target_position, _velocity, smooth, max_speed, delta)
		visual_position = result[0]
		_velocity = result[1]

	var displacement := visual_position - _previous_visual
	_previous_visual = visual_position
	var instant_speed := displacement.length() / maxf(delta, 0.0001)
	var blend := 1.0 - exp(-delta / config.speed_smoothing_s)
	_speed_filtered = lerpf(_speed_filtered, instant_speed, blend)

	if locked:
		speed_mps = 0.0
		motion = Motion.IDLE
	else:
		speed_mps = _speed_filtered
		motion = _motion_from_speed(speed_mps)


func shift_world(offset: Vector3) -> void:
	visual_position += offset
	target_position += offset
	anchor_position += offset
	lock_position += offset
	_heading_anchor += offset
	_correction_start += offset
	_previous_visual += offset
	for fix in _recent_fixes:
		fix.world += offset
	for entry in _still_window:
		entry["pos"] += offset
	if _candidate != null:
		_candidate.world += offset
	# last_fix is usually the same object as the newest recent fix (and may be
	# the candidate); shift each fix exactly once.
	if last_fix != null and not _recent_fixes.has(last_fix) and last_fix != _candidate:
		last_fix.world += offset


func anchor_distance() -> float:
	if not has_anchor:
		return 0.0
	return visual_position.distance_to(anchor_position)


func heading_degrees() -> float:
	if heading.length_squared() < 0.0001:
		return 0.0
	var deg := rad_to_deg(atan2(heading.x, -heading.z))
	return fposmod(deg, 360.0)


func _create_anchor(fix: GpsFix) -> void:
	has_anchor = true
	anchor_position = fix.world
	visual_position = fix.world
	target_position = fix.world
	_previous_visual = fix.world
	_heading_anchor = fix.world
	_recent_fixes.clear()
	_recent_fixes.append(fix)
	_last_valid_received_ns = fix.received_ns
	_velocity = Vector3.ZERO
	_frozen_by_accuracy = fix.accuracy > config.accuracy_reject_m
	_set_state(State.OK if fix.accuracy <= config.accuracy_ok_m else State.WEAK)
	first_anchor.emit(fix.world)


func _apply_valid_fix(fix: GpsFix, now_ns: int) -> void:
	var gap_s := 0.0
	if _last_valid_received_ns > 0:
		gap_s = maxf(0.0, (fix.received_ns - _last_valid_received_ns) / 1_000_000_000.0)
	_last_valid_received_ns = fix.received_ns

	_recent_fixes.append(fix)
	if _recent_fixes.size() > 2:
		_recent_fixes.pop_front()
	var filtered_target := _weighted_target()

	_update_stillness(fix, now_ns)
	if locked:
		# Doppler speed is authoritative when available; distance from the lock
		# point is only the fallback for sources without speed. Using the raw
		# noisy fix here would unlock on every 5 m GPS wobble.
		var release := false
		if fix.has_speed():
			release = fix.speed > config.unlock_speed
		else:
			release = filtered_target.distance_to(lock_position) > config.unlock_distance_m
		if release:
			_release_lock()
			target_position = filtered_target
			_heading_anchor = target_position
			_velocity = Vector3.ZERO
		else:
			target_position = lock_position
			return
	else:
		target_position = filtered_target

	_update_heading(fix)

	var distance := visual_position.distance_to(target_position)
	if gap_s > 10.0 or distance > config.snap_distance_m:
		var reason := "gap" if gap_s > 10.0 else "distance"
		_snap(distance, reason)
	elif distance > config.correction_min_m and state != State.WEAK:
		_correction_active = true
		_correction_start = visual_position
		_correction_elapsed = 0.0
		_velocity = Vector3.ZERO


func _weighted_target() -> Vector3:
	if _recent_fixes.is_empty():
		return target_position
	var weight_sum := 0.0
	var weighted := Vector3.ZERO
	for fix in _recent_fixes:
		var weight := 1.0 / maxf(fix.accuracy * fix.accuracy, 0.01)
		weighted += fix.world * weight
		weight_sum += weight
	if weight_sum <= 0.0:
		return target_position
	return weighted / weight_sum


func _update_stillness(fix: GpsFix, now_ns: int) -> void:
	if locked:
		return

	if fix.has_speed():
		_still_window.clear()
		if fix.speed < config.lock_speed:
			if _still_since_ns == 0:
				_still_since_ns = now_ns
			elif now_ns - _still_since_ns >= int(config.lock_time_s * 1_000_000_000.0):
				_lock()
		else:
			_still_since_ns = 0
		return

	_still_since_ns = 0
	_still_window.append({"pos": fix.world, "ns": now_ns})
	while _still_window.size() > 0 and now_ns - int(_still_window[0]["ns"]) > 4_000_000_000:
		_still_window.pop_front()
	if _still_window.size() < 2:
		return
	if now_ns - int(_still_window[0]["ns"]) < 4_000_000_000:
		return
	var max_distance := 0.0
	var first_pos: Vector3 = _still_window[0]["pos"]
	for entry in _still_window:
		max_distance = maxf(max_distance, first_pos.distance_to(entry["pos"]))
	if max_distance < 2.0:
		_lock()


func _lock() -> void:
	locked = true
	lock_position = target_position
	target_position = lock_position
	_still_since_ns = 0
	_still_window.clear()
	locked_changed.emit(true)


func _release_lock() -> void:
	locked = false
	_still_since_ns = 0
	_still_window.clear()
	locked_changed.emit(false)


func _update_heading(fix: GpsFix) -> void:
	var fix_speed := fix.speed if fix.has_speed() else _speed_filtered
	if fix_speed <= 0.5:
		return
	# A 2 m window is shorter than the GPS noise at 5 m accuracy. Scale the
	# window with accuracy and low-pass the direction so it does not flip.
	var window := maxf(config.heading_window_m, fix.accuracy)
	var moved := target_position - _heading_anchor
	if moved.length() >= window:
		var new_heading := moved.normalized()
		if heading.length_squared() < 0.01:
			heading = new_heading
		else:
			heading = heading.lerp(new_heading, 0.55).normalized()
		_heading_anchor = target_position


func _snap(distance: float, reason: String) -> void:
	visual_position = target_position
	_previous_visual = visual_position
	_velocity = Vector3.ZERO
	_correction_active = false
	_heading_anchor = target_position
	last_snap = {
		"distance": distance,
		"reason": reason,
		"time_ms": Time.get_ticks_msec(),
	}
	snap_occurred.emit(distance, reason)


func _update_state_from_age(now_ns: int) -> void:
	if state == State.DENIED:
		return
	if not has_anchor or last_fix == null:
		_set_state(State.INIT)
		return
	last_fix_age_s = last_fix.age_ns(now_ns) / 1_000_000_000.0
	if last_fix_age_s > config.lost_after_s:
		_set_state(State.LOST)
	elif last_fix_age_s > config.max_fix_age_s:
		_set_state(State.STALE)
	elif last_fix.accuracy > config.accuracy_ok_m:
		_set_state(State.WEAK)
	else:
		_set_state(State.OK)


func _set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func _motion_from_speed(speed: float) -> Motion:
	if speed < config.idle_speed:
		return Motion.IDLE
	if speed < config.run_speed:
		return Motion.WALK
	return Motion.RUN


## Unity-style critically damped SmoothDamp, vector version.
func _smooth_damp(current: Vector3, target: Vector3, velocity: Vector3, smooth_time: float, max_speed: float, delta: float) -> Array:
	var omega := 2.0 / maxf(smooth_time, 0.0001)
	var x := omega * delta
	var exp_factor := 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)
	var change := current - target
	var max_change := max_speed * smooth_time
	change = change.limit_length(max_change)
	var temp := (velocity + change * omega) * delta
	velocity = (velocity - temp * omega) * exp_factor
	var output := (current - change) + (temp + change) * exp_factor
	if (target - current).dot(output - target) > 0.0:
		output = target
		velocity = Vector3.ZERO
	return [output, velocity]
