extends Node
## Autoload: holds the latest webcam reading so any scene can use it, e.g. FaceData.label.
## In the browser it reads window.faceReading, which webcam/game_bridge.js keeps updated.
## Anywhere else (e.g. running from the editor) there is no webcam, so keys 1-4 set the label by hand.

signal label_changed(new_label: String)

const LABELS = ["calm", "nervous", "afraid", "angry"]
const POLL_SECONDS = 0.1  # read from the browser 10 times a second; the label changes slower than that

var label := "calm"
var confidence := 0.0
var face_found := false
var calibrating := false
var status := "starting"

var _is_web := OS.has_feature("web")
var _poll_timer := 0.0
var _debug_label: Label


func _ready() -> void:
	if not _is_web:
		status = "manual: keys 1-4"
	if OS.is_debug_build():
		_create_debug_label()
	_update_debug_label()


func _process(delta: float) -> void:
	if not _is_web:
		return
	_poll_timer += delta
	if _poll_timer < POLL_SECONDS:
		return
	_poll_timer = 0.0
	_read_from_browser()


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
	_update_debug_label()


## Keys 1-4 choose calm, nervous, afraid, angry when there is no webcam.
func _unhandled_input(event: InputEvent) -> void:
	if _is_web:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var index: int = event.keycode - KEY_1
		if index >= 0 and index < LABELS.size():
			face_found = true
			_set_label(LABELS[index], 1.0)
			_update_debug_label()


## Stores a new reading and announces it only when the label actually changes.
func _set_label(new_label: String, new_confidence: float) -> void:
	confidence = new_confidence
	if new_label != label:
		label = new_label
		label_changed.emit(label)


## Records the player's relaxed face again (browser only).
func recalibrate() -> void:
	if _is_web:
		JavaScriptBridge.eval("window.faceTracker?.recalibrate()", true)


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


func _update_debug_label() -> void:
	if _debug_label == null:
		return
	_debug_label.text = "Face: %s %d%%  [%s]" % [label, roundi(confidence * 100), status]
