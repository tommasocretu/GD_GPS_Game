class_name DebugHud
extends CanvasLayer

## Debug HUD and safe-area layout (tickets 07/08). Debug-only panels are not
## created in release builds.

signal start_gps_requested
signal marker_toggled(visible: bool)

const FOG_COLOR := Color("#cfd8cc")
const PANEL_COLOR := Color(0.05, 0.08, 0.06, 0.68)
const TEXT_COLOR := Color("#f2f5ef")
const MUTED_COLOR := Color("#b9c4b6")
const STATE_NAMES := ["INIT", "OK", "WEAK", "STALE", "LOST", "DENIED"]

var movement_config: MovementConfig

var _root: Control
var _top_panel: PanelContainer
var _top_label: Label
var _debug_panel: PanelContainer
var _banner: Label
var _bottom_panel: PanelContainer
var _attribution: Label
var _toast: Label
var _overlay: ColorRect
var _overlay_title: Label
var _overlay_text: Label
var _overlay_button: Button
var _fade: ColorRect
var _smooth_slider: HSlider
var _lock_slider: HSlider
var _max_speed_slider: HSlider
var _smooth_value: Label
var _lock_value: Label
var _max_speed_value: Label
var _snap_text := "—"
var _toast_serial := 0
var _marker_visible := false


func _ready() -> void:
	layer = 10
	_build_ui()
	get_viewport().size_changed.connect(_apply_safe_area)
	call_deferred("_apply_safe_area")


func setup(config: MovementConfig) -> void:
	movement_config = config
	if _smooth_slider != null:
		_smooth_slider.set_value_no_signal(config.smooth_time)
		_lock_slider.set_value_no_signal(config.lock_speed)
		_max_speed_slider.set_value_no_signal(config.max_speed)
		_refresh_slider_labels()


func update_hud(model: MovementModel, fix: GpsFix, chunk_text: String = "—") -> void:
	var state := int(model.state)
	var state_text: String = STATE_NAMES[state] if state >= 0 and state < STATE_NAMES.size() else "?"
	var age_text := "—"
	var accuracy_text := "—"
	var mock_text := ""
	var lat_text := "—"
	var lon_text := "—"
	if fix != null:
		age_text = "%.1fs" % model.last_fix_age_s
		accuracy_text = "%.1fm" % fix.accuracy
		mock_text = "  MOCK" if fix.is_mock else ""
		lat_text = "%.6f" % fix.latitude
		lon_text = "%.6f" % fix.longitude

	var status_line := "GPS %s   age %s   acc %s%s" % [state_text, age_text, accuracy_text, mock_text]
	if OS.is_debug_build():
		_top_label.text = "\n".join([
			status_line,
			"lat %s   lon %s" % [lat_text, lon_text],
			"speed %.2f m/s   heading %03d°   anchor %.1f m" % [
				model.speed_mps, int(round(model.heading_degrees())), model.anchor_distance()
			],
			"chunk %s   fps %d   snap %s" % [chunk_text, Engine.get_frames_per_second(), _snap_text],
		])
	else:
		_top_label.text = status_line

	if model.state == MovementModel.State.INIT:
		_show_banner(false)
	elif model.state == MovementModel.State.LOST:
		_banner.text = "GPS perso: in attesa di un fix"
		_show_banner(true)
	elif model.state == MovementModel.State.STALE:
		if model.last_fix_age_s >= 5.0:
			_banner.text = "GPS in attesa di un fix valido"
			_show_banner(true)
		else:
			_show_banner(false)
	else:
		_show_banner(false)


func show_waiting() -> void:
	_overlay_title.text = "GPS in attesa"
	_overlay_text.text = "Ricerca del primo fix preciso…"
	_overlay_button.visible = false
	_overlay.visible = true
	_top_panel.visible = false


func show_permission_prompt() -> void:
	_overlay_title.text = "Serve la posizione"
	_overlay_text.text = "Il gioco usa il GPS per muovere l'avatar.\nConcedi la posizione precisa per iniziare."
	_overlay_button.text = "Attiva GPS"
	_overlay_button.visible = true
	_overlay.visible = true
	_top_panel.visible = false


func show_denied(message: String) -> void:
	_overlay_title.text = "Posizione non disponibile"
	_overlay_text.text = message
	_overlay_button.text = "Riprova"
	_overlay_button.visible = true
	_overlay.visible = true
	_top_panel.visible = false


func hide_overlay() -> void:
	_overlay.visible = false
	_top_panel.visible = true


func fade_in_world(duration: float = 0.3) -> void:
	hide_overlay()
	_fade.color = Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, 1.0)
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, duration)
	tween.tween_callback(func() -> void: _fade.visible = false)


func flash_snap() -> void:
	_fade.color = Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, 1.0)
	_fade.visible = true
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 0.0, 0.15)
	tween.tween_callback(func() -> void: _fade.visible = false)


func show_snap(distance_m: float, reason: String) -> void:
	_snap_text = "%.1fm %s" % [distance_m, reason]
	_toast.text = "SNAP  %.1f m  (%s)" % [distance_m, reason]
	_toast.visible = true
	_toast_serial += 1
	var serial := _toast_serial
	await get_tree().create_timer(3.0).timeout
	if serial == _toast_serial:
		_toast.visible = false


func set_marker_visible(visible: bool) -> void:
	_marker_visible = visible


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_overlay = ColorRect.new()
	_overlay.color = FOG_COLOR
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)
	var overlay_box := VBoxContainer.new()
	overlay_box.custom_minimum_size = Vector2(300, 0)
	overlay_box.add_theme_constant_override("separation", 14)
	center.add_child(overlay_box)
	_overlay_title = _make_label("GPS in attesa", 22, TEXT_COLOR)
	_overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_box.add_child(_overlay_title)
	_overlay_text = _make_label("", 15, MUTED_COLOR)
	_overlay_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_box.add_child(_overlay_text)
	_overlay_button = Button.new()
	_overlay_button.text = "Attiva GPS"
	_overlay_button.custom_minimum_size = Vector2(180, 48)
	_overlay_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_overlay_button.add_theme_font_size_override("font_size", 17)
	_overlay_button.pressed.connect(func() -> void: start_gps_requested.emit())
	overlay_box.add_child(_overlay_button)

	_fade = ColorRect.new()
	_fade.color = Color(FOG_COLOR.r, FOG_COLOR.g, FOG_COLOR.b, 0.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.visible = false
	_root.add_child(_fade)

	_top_panel = PanelContainer.new()
	_top_panel.add_theme_stylebox_override("panel", _panel_style())
	_top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_top_panel)
	_top_label = _make_label("GPS INIT", 13, TEXT_COLOR)
	_top_panel.add_child(_top_label)

	if OS.is_debug_build():
		_debug_panel = PanelContainer.new()
		_debug_panel.add_theme_stylebox_override("panel", _panel_style())
		_debug_panel.visible = false
		_root.add_child(_debug_panel)
		var debug_box := VBoxContainer.new()
		debug_box.add_theme_constant_override("separation", 4)
		_debug_panel.add_child(debug_box)
		var debug_title := _make_label("Debug (F2)", 12, MUTED_COLOR)
		debug_box.add_child(debug_title)
		var smooth_pair := _add_slider(debug_box, "smooth", 0.1, 1.5, 0.05)
		_smooth_slider = smooth_pair[0]
		_smooth_value = smooth_pair[1]
		var lock_pair := _add_slider(debug_box, "lock", 0.1, 1.0, 0.05)
		_lock_slider = lock_pair[0]
		_lock_value = lock_pair[1]
		var max_speed_pair := _add_slider(debug_box, "max speed", 0.5, 5.0, 0.1)
		_max_speed_slider = max_speed_pair[0]
		_max_speed_value = max_speed_pair[1]
		_smooth_slider.value_changed.connect(_on_smooth_changed)
		_lock_slider.value_changed.connect(_on_lock_changed)
		_max_speed_slider.value_changed.connect(_on_max_speed_changed)

	_banner = _make_label("", 15, TEXT_COLOR)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_stylebox_override("normal", _panel_style())
	_banner.visible = false
	_root.add_child(_banner)

	_bottom_panel = PanelContainer.new()
	_bottom_panel.add_theme_stylebox_override("panel", _panel_style())
	_bottom_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_bottom_panel)
	_attribution = _make_label("© MapTiler  © OpenStreetMap contributors", 12, MUTED_COLOR)
	_attribution.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom_panel.add_child(_attribution)

	_toast = _make_label("", 15, TEXT_COLOR)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_stylebox_override("normal", _panel_style())
	_toast.visible = false
	_root.add_child(_toast)


func _apply_safe_area() -> void:
	if _top_panel == null:
		return
	var window_size := DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		window_size = Vector2i(get_viewport().get_visible_rect().size)
	var safe := DisplayServer.get_display_safe_area()
	var viewport_size := get_viewport().get_visible_rect().size
	var scale := Vector2(
		viewport_size.x / maxf(1.0, float(window_size.x)),
		viewport_size.y / maxf(1.0, float(window_size.y))
	)
	var left := maxf(0.0, float(safe.position.x)) * scale.x
	var top := maxf(0.0, float(safe.position.y)) * scale.y
	var right := maxf(0.0, float(window_size.x - safe.end.x)) * scale.x
	var bottom := maxf(0.0, float(window_size.y - safe.end.y)) * scale.y

	var margin := 12.0
	_top_panel.position = Vector2(left + margin, top + margin)
	if _debug_panel != null:
		_debug_panel.position = Vector2(left + margin, top + margin + 104.0)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_left = left + 48.0
	_banner.offset_right = -(right + 48.0)
	_banner.offset_top = top + 12.0
	_banner.offset_bottom = top + 46.0

	var bar_height := 40.0
	_bottom_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_panel.offset_left = left + margin
	_bottom_panel.offset_right = -(right + margin)
	_bottom_panel.offset_top = -(bottom + bar_height + margin)
	_bottom_panel.offset_bottom = -(bottom + margin)

	_toast.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_toast.offset_left = left + 40.0
	_toast.offset_right = -(right + 40.0)
	_toast.offset_bottom = -(bottom + bar_height + margin + 8.0)
	_toast.offset_top = _toast.offset_bottom - 36.0


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _add_slider(parent: VBoxContainer, title: String, min_value: float, max_value: float, step: float) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var name_label := _make_label(title, 11, MUTED_COLOR)
	name_label.custom_minimum_size = Vector2(64, 0)
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.custom_minimum_size = Vector2(150, 20)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	var value_label := _make_label("", 11, TEXT_COLOR)
	value_label.custom_minimum_size = Vector2(44, 0)
	row.add_child(value_label)
	return [slider, value_label]


func _refresh_slider_labels() -> void:
	if movement_config == null:
		return
	_smooth_value.text = "%.2f" % movement_config.smooth_time
	_lock_value.text = "%.2f" % movement_config.lock_speed
	_max_speed_value.text = "%.1f" % movement_config.max_speed


func _on_smooth_changed(value: float) -> void:
	if movement_config != null:
		movement_config.smooth_time = value
	_refresh_slider_labels()


func _on_lock_changed(value: float) -> void:
	if movement_config != null:
		movement_config.lock_speed = value
	_refresh_slider_labels()


func _on_max_speed_changed(value: float) -> void:
	if movement_config != null:
		movement_config.max_speed = value
	_refresh_slider_labels()


func _show_banner(visible: bool) -> void:
	if _banner.visible != visible:
		_banner.visible = visible


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F2:
			_debug_panel.visible = not _debug_panel.visible
			_apply_safe_area()
		elif event.keycode == KEY_F3:
			_marker_visible = not _marker_visible
			marker_toggled.emit(_marker_visible)
