extends Control
## Shared behaviour for every story scene: a queue of lines shown in a floating
## black speech box next to the speaker, typewriter reveal, choices as a card
## under the box with 1/2/3 key badges, Space or click to continue, and the
## in-world monitor readout. Scenes extend this script and override the
## virtual methods marked below.

const TYPE_SPEED := 45.0  # characters per second
const CHOICE_KEYS: Array[int] = [KEY_1, KEY_2, KEY_3, KEY_4]

## Top-left corner of the speech box, in a 1280x720 layout. Set per scene.
@export var box_position := Vector2(700, 160)
## Duotone grade for this scene: shadow and highlight colours and how strongly they apply.
@export var shadow_tint := Color(0.05, 0.22, 0.2)
@export var highlight_tint := Color(0.95, 0.83, 0.86)
@export var duotone := 0.55

@onready var background: TextureRect = $World/Background
@onready var postfx: ColorRect = $FX/PostFX
@onready var bubble: VBoxContainer = $UI/Bubble
@onready var text_label: RichTextLabel = $UI/Bubble/Dialogue/Margin/Text
@onready var choices_box: VBoxContainer = $UI/Bubble/Choices
@onready var hint: HBoxContainer = $UI/Hint
@onready var hint_label: Label = $UI/Hint/HintLabel
@onready var monitor: PanelContainer = $UI/Monitor
@onready var monitor_bars: Control = $UI/Monitor/VBox/Row/Bars
@onready var monitor_value: Label = $UI/Monitor/VBox/Row/Value
@onready var suspicion_row: HBoxContainer = $UI/Monitor/VBox/Row
@onready var sense_box: VBoxContainer = $UI/Monitor/VBox/Sense
@onready var sense_line: ColorRect = $UI/Monitor/VBox/Sense/Line
@onready var read_value: Label = $UI/Monitor/VBox/Sense/ReadRow/ReadValue
@onready var wrong_button: Button = $UI/Monitor/VBox/Sense/Buttons/Wrong
@onready var off_button: Button = $UI/Monitor/VBox/Sense/Buttons/Off
@onready var progress: Control = $UI/Progress
@onready var fade: ColorRect = $Fade/Black

const FADE_IN := 0.45
const FADE_OUT := 0.35
const POP_IN := 0.16

var queue: Array = []   # list of {"who": String, "text": String}
var step: int = 0
var locked := false     # true at a dead end: nothing advances
## The plan keeps the suspicion score hidden from players. Debug builds show it for testing.
var show_suspicion := OS.is_debug_build()
var _monitor_wanted := false  # true once the scene has asked for the monitor
var _tween: Tween
var _pop_tween: Tween
var _choice_buttons: Array[Button] = []
var _leaving := false


func _ready() -> void:
	place_box(box_position)
	set_tint(shadow_tint, highlight_tint, duotone)
	monitor.visible = false
	progress.visible = false
	# The monitor's two buttons talk to FaceData; FaceData tells us when to redraw.
	wrong_button.pressed.connect(FaceData.mark_wrong)
	off_button.pressed.connect(_toggle_sensing)
	FaceData.changed.connect(refresh_sensing)
	refresh_sensing()
	_fade_in()
	call_deferred("_start_drift")
	_setup()


# ---- virtual: scenes override these -------------------------------------

## Called once at start. Position the box, then fill the queue with set_queue().
func _setup() -> void:
	pass


## Called after every line is displayed. Show choices here when needed.
func _on_line_shown() -> void:
	pass


## Called when the player continues past the last line of the queue.
func _on_queue_finished() -> void:
	pass


# ---- placement and grade -------------------------------------------------------

## Top-left corner of the speech box and, optionally, its width (default 480).
func place_box(p: Vector2, width: float = 480.0) -> void:
	box_position = p
	if bubble:
		bubble.position = p
		bubble.custom_minimum_size.x = width
		bubble.size.x = width


func set_tint(shadow: Color, highlight: Color, amount: float) -> void:
	var mat := postfx.material as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("shadow_color", Vector3(shadow.r, shadow.g, shadow.b))
	mat.set_shader_parameter("highlight_color", Vector3(highlight.r, highlight.g, highlight.b))
	mat.set_shader_parameter("duotone", amount)


# ---- queue and lines ---------------------------------------------------------

static func lines_for(who: String, texts: Array) -> Array:
	var out: Array = []
	for t in texts:
		out.append({"who": who, "text": str(t)})
	return out


func set_queue(lines: Array) -> void:
	queue = lines
	step = 0
	show_line()


func at_end() -> bool:
	return step >= queue.size() - 1


func show_line() -> void:
	if queue.is_empty():
		return
	var l: Dictionary = queue[step]
	clear_choices()
	_type(str(l.get("text", "")))
	hint.visible = not locked
	_on_line_shown()
	_relayout()
	_pop_in()


## Marks a dead end: hides the continue hint and ignores further input.
func lock_end() -> void:
	locked = true
	hint.visible = false


# ---- typewriter --------------------------------------------------------------

func _type(text: String) -> void:
	if _tween:
		_tween.kill()
	# Lines written as *thought* are inner monologue: show them in italics.
	if text.length() > 2 and text.begins_with("*") and text.ends_with("*"):
		text = "[i]" + text.substr(1, text.length() - 2) + "[/i]"
	text_label.text = "[center]" + text + "[/center]"
	text_label.visible_characters = 0
	var n := text_label.get_total_character_count()
	if n <= 0:
		text_label.visible_characters = -1
		return
	_tween = create_tween()
	_tween.tween_property(text_label, "visible_characters", n, float(n) / TYPE_SPEED)


func is_typing() -> bool:
	return _tween != null and _tween.is_running()


func finish_typing() -> void:
	if _tween:
		_tween.kill()
	text_label.visible_characters = -1


# ---- choices -----------------------------------------------------------------

## options: list of dictionaries with at least "text". on_pick receives the dictionary.
func show_choices(options: Array, on_pick: Callable) -> void:
	clear_choices()
	for i in options.size():
		var o: Dictionary = options[i]
		var b := Button.new()
		b.theme_type_variation = &"ChoiceRow"
		b.text = str(o.get("text", ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(on_pick.bind(o))
		choices_box.add_child(b)
		_add_badge(b, str(i + 1))
		_choice_buttons.append(b)
	choices_box.visible = true
	hint.visible = false
	# No answer gets keyboard focus by itself: with focus on the first row, a player
	# pressing Space to hurry the text would pick that answer by accident.
	_relayout()


func _add_badge(button: Button, key: String) -> void:
	var badge := PanelContainer.new()
	badge.theme_type_variation = &"KeyBadge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := Label.new()
	lab.theme_type_variation = &"KeyText"
	lab.text = key
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(lab)
	button.add_child(badge)
	# Anchor to the left edge, vertically centred, once the badge knows its size.
	badge.call_deferred("set_anchors_and_offsets_preset", Control.PRESET_CENTER_LEFT, Control.PRESET_MODE_MINSIZE, 14)


func clear_choices() -> void:
	for c in choices_box.get_children():
		choices_box.remove_child(c)
		c.queue_free()
	_choice_buttons.clear()
	choices_box.visible = false


# ---- monitor, layout, navigation ---------------------------------------------

## Suspicion as signal bars plus the number. Bars go hot when the level is reached.
func set_monitor(value: int, show: bool = true) -> void:
	_monitor_wanted = show
	monitor_bars.value = value
	monitor_value.text = str(value)
	refresh_sensing()


## Redraws the monitor from FaceData. Runs every time FaceData announces a change.
## The suspicion row shows in debug builds only; the face-reading part in condition C only.
func refresh_sensing() -> void:
	var reading_on: bool = FaceData.condition == "C"
	suspicion_row.visible = show_suspicion
	sense_line.visible = show_suspicion
	sense_box.visible = reading_on
	monitor.visible = _monitor_wanted and (show_suspicion or reading_on)
	read_value.text = FaceData.monitor_text()
	wrong_button.disabled = not FaceData.sensing_on
	off_button.text = "SWITCH OFF" if FaceData.sensing_on else "SWITCH ON"
	# Let the panel grow or shrink to fit what is showing.
	monitor.set_deferred("size", Vector2(monitor.size.x, 0))


## "Switch off" and "Switch on": the player's own switch for the face reading.
func _toggle_sensing() -> void:
	FaceData.set_sensing(not FaceData.sensing_on)


## Question progress as the row of diamonds top-left.
func set_progress(done: int, total: int, show: bool = true) -> void:
	progress.visible = show
	progress.total = total
	progress.done = done


## Fade to black, then switch scene. Ignores repeated calls while leaving.
func go_to(scene_path: String) -> void:
	if _leaving:
		return
	_leaving = true
	locked = true
	hint.visible = false
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 1.0, FADE_OUT)
	await t.finished
	get_tree().change_scene_to_file(scene_path)


func _fade_in() -> void:
	fade.modulate.a = 1.0
	var t := create_tween()
	t.tween_property(fade, "modulate:a", 0.0, FADE_IN)


## New line: the box drops in from a few pixels above while fading up.
func _pop_in() -> void:
	if _pop_tween:
		_pop_tween.kill()
	bubble.modulate.a = 0.0
	bubble.position = box_position + Vector2(0, -6)
	_pop_tween = create_tween().set_parallel(true)
	_pop_tween.tween_property(bubble, "modulate:a", 1.0, POP_IN)
	_pop_tween.tween_property(bubble, "position", box_position, POP_IN).set_ease(Tween.EASE_OUT)


## Slow drift of the background, as if the camera breathes. Runs for the life of the scene.
func _start_drift() -> void:
	background.pivot_offset = background.size / 2.0
	background.scale = Vector2(1.03, 1.03)
	var t := create_tween().set_loops()
	t.tween_property(background, "position", Vector2(8, 4), 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(background, "position", Vector2(-8, -4), 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Space, Enter or a click: finish the typewriter, otherwise go to the next line.
func advance() -> void:
	if locked:
		return
	if is_typing():
		finish_typing()
		return
	_next()


func _next() -> void:
	if step < queue.size() - 1:
		step += 1
		show_line()
	else:
		_on_queue_finished()


func _relayout() -> void:
	call_deferred("_do_relayout")


func _do_relayout() -> void:
	bubble.reset_size()


func _unhandled_input(event: InputEvent) -> void:
	if choices_box.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			var idx := CHOICE_KEYS.find(event.keycode)
			if idx >= 0 and idx < _choice_buttons.size():
				_choice_buttons[idx].pressed.emit()
				get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
