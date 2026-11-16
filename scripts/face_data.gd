extends Node
## Autoload: holds the latest webcam reading so any scene can use it, e.g. FaceData.label.
## In the browser it reads window.faceReading, which webcam/game_bridge.js keeps updated.
## Anywhere else (e.g. running from the editor) there is no webcam, so the keys Z, X, C, V set the
## label by hand. (1-4 are taken: they pick the answers.)
##
## Study conditions (see the wiki):
##   A = buttons only: the face is ignored.
##   B = hidden sensing: the face changes suspicion and lines, and the player isn't shown the reading.
##   C = open sensing: like B, plus the reading on the scene's monitor panel, with "That's wrong"
##       and "Switch off". The panel itself lives in scenes/dialogue_base.tscn.
## Choose the condition with the page address (index.html?condition=A), or in the editor with
## Project > Project Settings > Run > Main Run Args (enable Advanced Settings): -- --condition=C
## In debug builds the M key also steps through A, B, C, so one run can show all three.

signal label_changed(new_label: String)
## Sent when what the monitor shows has changed: the reading, the condition or the switch.
signal changed

const LABELS = ["calm", "tense", "smiling", "looked_away"]
# webcam/emotion.js still sends the first set of labels. Until it sends the ones above,
# its three stressed labels all count as tense.
const OLD_LABELS = {"nervous": "tense", "afraid": "tense", "angry": "tense"}
const MANUAL_KEYS = {KEY_Z: "calm", KEY_X: "tense", KEY_C: "smiling", KEY_V: "looked_away"}
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
var _discarded_until_ms := 0
var _last_shown := ""  # what the monitor showed last, to announce only real changes

# Measuring window: seconds spent showing each label since start_window() was called.
var _window_active := false
var _window_seconds := {}
var _window_corrected := false  # set by "That's wrong": ignore the face until the window ends


func _ready() -> void:
	_read_condition()
	if not _is_web:
		status = "manual: keys Z X C V"
	if OS.is_debug_build():
		_create_debug_label()
	_refresh_display()


func _process(delta: float) -> void:
	if _window_active and not _window_corrected and uses_face() and is_tracking():
		_window_seconds[label] = _window_seconds.get(label, 0.0) + delta

	# The "discarded" message has had its 1.5 s: put the live reading back on the monitor.
	if _discarded_until_ms != 0 and Time.get_ticks_msec() >= _discarded_until_ms:
		_discarded_until_ms = 0
		_refresh_display()

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


## True when the story may react to the face right now: uses_face(), and the player has not
## pressed "That's wrong" since the current measuring window started.
func may_react() -> bool:
	return uses_face() and not _window_corrected


## The words the monitor shows for the current reading.
func monitor_text() -> String:
	if not sensing_on:
		return "OFF"
	if Time.get_ticks_msec() < _discarded_until_ms:
		return "DISCARDED"
	if calibrating:
		return "CALIBRATING"
	if not face_found:
		return "NO FACE"
	return label.replace("_", " ").to_upper()


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
##   stressed_share  fraction of that time the face showed anything other than calm (0 to 1)
##   stressed_label  the most common of those other labels, or "" if none appeared
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
		var new_label: String = reading["label"]
		_set_label(OLD_LABELS.get(new_label, new_label), reading.get("confidence", 0.0))
	_refresh_display()


## Z, X, C, V choose calm, tense, smiling, looked away when there is no webcam.
## In debug builds M steps to the next condition.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if OS.is_debug_build() and key.keycode == KEY_M:
		condition = CONDITIONS[(CONDITIONS.find(condition) + 1) % CONDITIONS.size()]
		sensing_on = true
		_refresh_display()
	elif not _is_web and MANUAL_KEYS.has(key.keycode):
		face_found = true
		_set_label(MANUAL_KEYS[key.keycode], 1.0)
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
	# Bottom left: the scene's monitor sits top right and the progress marks top left.
	_debug_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_debug_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_debug_label.position += Vector2(12, -8)
	_debug_label.add_theme_font_size_override("font_size", 16)
	_debug_label.add_theme_constant_override("outline_size", 6)
	_debug_label.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_debug_label)


## Updates the debug readout, and announces "changed" when what the monitor shows is different.
func _refresh_display() -> void:
	if _debug_label:
		_debug_label.text = "Face: %s %d%%  [%s]  condition %s%s" % [
			label, roundi(confidence * 100), status, condition,
			"" if sensing_on else " (switched off)"]

	var shown := "%s|%s|%s" % [monitor_text(), condition, sensing_on]
	if shown != _last_shown:
		_last_shown = shown
		changed.emit()
