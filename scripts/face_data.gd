extends Node
## Autoload: holds the latest webcam reading so any scene can use it, e.g. FaceData.label.
## In the browser it reads window.faceReading, which webcam/game_bridge.js keeps updated.
## Anywhere else (e.g. running from the editor) there is no webcam, so keys 1-4 set the label by hand.
##
## Study conditions (see the wiki):
##   A = buttons only: the face is ignored.
##   B = hidden sensing: the face changes suspicion and lines, and the player isn't shown the reading.
##   C = open sensing: like B, plus a monitor panel with "That's wrong" and "Switch off".
## Choose the condition with the page address (index.html?condition=A), or in the editor with
## Project > Project Settings > Run > Main Run Args (enable Advanced Settings): -- --condition=C

signal label_changed(new_label: String)

const LABELS = ["calm", "nervous", "afraid", "angry"]
const CONDITIONS = ["A", "B", "C"]
const POLL_SECONDS = 0.1  # read from the browser 10 times a second; the label changes slower than that

var condition := "B"
var sensing_on := true  # condition C's "Switch off" sets this to false

var label := "calm"
var confidence := 0.0
var face_found := false
var calibrating := false
var status := "starting"

# Counted for the study logs (M2): how often players corrected or switched off the monitor.
var corrections := 0
var switch_offs := 0

var _is_web := OS.has_feature("web")
var _poll_timer := 0.0
var _debug_label: Label
var _monitor_reading: Label
var _switch_button: Button
var _discarded_until_ms := 0

# Measuring window: seconds spent showing each label since start_window() was called.
var _window_active := false
var _window_seconds := {}
var _window_corrected := false  # set by "That's wrong": ignore the face until the window ends


func _ready() -> void:
	_read_condition()
	if not _is_web:
		status = "manual: keys 1-4"
	if OS.is_debug_build():
		_create_debug_label()
	if condition == "C":
		_create_monitor_panel()
	_refresh_display()


func _process(delta: float) -> void:
	if _window_active and not _window_corrected and is_tracking():
		_window_seconds[label] = _window_seconds.get(label, 0.0) + delta

	if not _is_web:
		return
	_poll_timer += delta
	if _poll_timer < POLL_SECONDS:
		return
	_poll_timer = 0.0
	_read_from_browser()


## True when the game should react to the face: not condition A, and not switched off.
func uses_face() -> bool:
	return condition != "A" and sensing_on


## True when there is a face and a finished calibration, so the label means something.
func is_tracking() -> bool:
	return face_found and not calibrating


## Starts measuring which labels the player shows, e.g. when a question is asked.
func start_window() -> void:
	_window_active = true
	_window_seconds = {}
	_window_corrected = false


## Stops measuring and summarises the window:
##   seconds         how long a face was tracked in total
##   stressed_share  fraction of that time spent nervous, afraid or angry (0 to 1)
##   stressed_label  the most common of those three, or "" if none appeared
func end_window() -> Dictionary:
	_window_active = false
	var total := 0.0
	var stressed := 0.0
	var stressed_label := ""
	var most := 0.0
	for each_label in _window_seconds:
		var seconds: float = _window_seconds[each_label]
		total += seconds
		if each_label != "calm":
			stressed += seconds
			if seconds > most:
				most = seconds
				stressed_label = each_label
	return {
		"seconds": total,
		"stressed_share": stressed / total if total > 0.0 else 0.0,
		"stressed_label": stressed_label,
	}


## "That's wrong": throws away this question's reading and ignores the face until the question
## ends, so a reading the player rejected can't count against them.
func mark_wrong() -> void:
	corrections += 1
	_window_seconds = {}
	_window_corrected = true
	_discarded_until_ms = Time.get_ticks_msec() + 1500  # keep the message visible for 1.5 s
	_refresh_display()


## "Switch off" / "Switch on": while off, the game behaves like condition A.
func set_sensing(on: bool) -> void:
	if not on and sensing_on:
		switch_offs += 1
	sensing_on = on
	if not on:
		_window_seconds = {}
	_refresh_display()


## Records the player's relaxed face again (browser only).
func recalibrate() -> void:
	if _is_web:
		JavaScriptBridge.eval("window.faceTracker?.recalibrate()", true)


## Reads the condition from ?condition=X in the browser, or --condition=X when run from the editor.
func _read_condition() -> void:
	var value = null
	if _is_web:
		value = JavaScriptBridge.eval(
			"new URLSearchParams(location.search).get('condition')", true)
	else:
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--condition="):
				value = arg.get_slice("=", 1)
	if typeof(value) == TYPE_STRING and value.to_upper() in CONDITIONS:
		condition = value.to_upper()


## Asks the page for window.faceReading as JSON text and copies it into our variables.
func _read_from_browser() -> void:
	var text = JavaScriptBridge.eval("JSON.stringify(window.faceReading ?? null)", true)
	if typeof(text) != TYPE_STRING:
		return
	var reading = JSON.parse_string(text)
	if typeof(reading) != TYPE_DICTIONARY:
		return

	status = reading.get("status", "unknown")
	face_found = reading.get("faceFound", false)
	calibrating = reading.get("calibrating", false)
	if reading.get("label") != null:
		_set_label(reading["label"], reading.get("confidence", 0.0))
	_refresh_display()


## Keys 1-4 choose calm, nervous, afraid, angry when there is no webcam.
func _unhandled_input(event: InputEvent) -> void:
	if _is_web:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.keycode - KEY_1
		if index >= 0 and index < LABELS.size():
			face_found = true
			_set_label(LABELS[index], 1.0)
			_refresh_display()


## Stores a new reading and announces it only when the label actually changes.
func _set_label(new_label: String, new_confidence: float) -> void:
	confidence = new_confidence
	if new_label != label:
		label = new_label
		label_changed.emit(label)


## A small corner readout, only in debug builds, so we can see what the game receives.
func _create_debug_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100  # draw above every scene
	add_child(layer)

	_debug_label = Label.new()
	_debug_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_debug_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_debug_label.position += Vector2(-12, 8)
	_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug_label.add_theme_font_size_override("font_size", 16)
	_debug_label.add_theme_constant_override("outline_size", 6)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_debug_label)


## Condition C's monitor: shows the current reading with "That's wrong" and "Switch off".
func _create_monitor_panel() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90  # above every scene, below the debug readout
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.1, 0.08, 0.85)
	style.border_color = Color(0.5, 1.0, 0.85)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var column := VBoxContainer.new()
	panel.add_child(column)

	var title := Label.new()
	title.text = "EMOTION COMPLIANCE MONITOR"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.5, 1.0, 0.85))
	column.add_child(title)

	_monitor_reading = Label.new()
	_monitor_reading.add_theme_font_size_override("font_size", 20)
	column.add_child(_monitor_reading)

	var buttons := HBoxContainer.new()
	column.add_child(buttons)

	var wrong_button := Button.new()
	wrong_button.text = "That's wrong"
	wrong_button.focus_mode = Control.FOCUS_NONE  # don't steal keys from the dialogue buttons
	wrong_button.pressed.connect(mark_wrong)
	buttons.add_child(wrong_button)

	_switch_button = Button.new()
	_switch_button.focus_mode = Control.FOCUS_NONE
	_switch_button.pressed.connect(func(): set_sensing(not sensing_on))
	buttons.add_child(_switch_button)


## Updates the debug readout and the monitor panel to match the current reading.
func _refresh_display() -> void:
	if _debug_label:
		_debug_label.text = "Face: %s %d%%  [%s]  condition %s%s" % [
			label, roundi(confidence * 100), status, condition,
			"" if sensing_on else " (switched off)"]

	if _monitor_reading == null:
		return
	_switch_button.text = "Switch off" if sensing_on else "Switch on"
	if not sensing_on:
		_monitor_reading.text = "Sensing off"
	elif Time.get_ticks_msec() < _discarded_until_ms:
		_monitor_reading.text = "Reading discarded"
	elif calibrating:
		_monitor_reading.text = "Calibrating..."
	elif not face_found:
		_monitor_reading.text = "No face detected"
	else:
		_monitor_reading.text = "%s  %d%%" % [label.to_upper(), roundi(confidence * 100)]
