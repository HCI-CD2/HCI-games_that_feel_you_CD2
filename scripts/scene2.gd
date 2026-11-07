extends Control

const NEXT_SCENE = "res://scenes/scene3.tscn"

@onready var label = $Label
@onready var name_label = $Name
@onready var choices_box = $Choices
@onready var back_button = $HBoxContainer/BackButton
@onready var next_button = $HBoxContainer/NextButton

var step = 0
var in_intro = true

var intro = [
	{"who": "You", "text": "That guy looks dangerous*"},
	{"who": "Detective", "text": "So. You're the one they brought in."},
]

var greet_branch = [
	{"who": "You", "text": "Good evening."},
	{"who": "Detective", "text": "A greeting. Warm tone, steady eyes. Rehearsed."},
	{"who": "Detective", "text": "People who are calm don't need to prove it."},
	{"who": "Detective", "text": "Noted: attempt to control the conversation."},
]

var silent_branch = [
	{"who": "You", "text": "..."},
	{"who": "Detective", "text": "No greeting. No expression. Good."},
	{"who": "Detective", "text": "But silence is also a choice. We'll see what it hides."},
]

var choices = [
	{"text": "Greet him", "branch": greet_branch},
	{"text": "Stay silent", "branch": silent_branch},
]

var current = intro

func _ready():
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	show_line()

func show_line():
	var l = current[step]
	name_label.text = l["who"] + ":"
	label.text = l["text"]
	clear_choices()

	var at_end = (step == current.size() - 1)
	var show_choices = in_intro and at_end

	back_button.disabled = (in_intro and step == 0)
	next_button.visible = not show_choices
	next_button.disabled = false

	if show_choices:
		for c in choices:
			var b = Button.new()
			b.text = c["text"]
			b.custom_minimum_size = Vector2(360, 44)
			b.pressed.connect(_on_choice.bind(c["branch"]))
			choices_box.add_child(b)
		choices_box.show()

func clear_choices():
	for child in choices_box.get_children():
		child.queue_free()
	choices_box.hide()

func _on_choice(branch):
	in_intro = false
	current = branch
	step = 0
	show_line()

func _on_next_pressed():
	if step < current.size() - 1:
		step += 1
		show_line()
	elif not in_intro:
		get_tree().change_scene_to_file(NEXT_SCENE)

func _on_back_pressed():
	if step > 0:
		step -= 1
	elif not in_intro:
		in_intro = true
		current = intro
		step = intro.size() - 1
	show_line()
