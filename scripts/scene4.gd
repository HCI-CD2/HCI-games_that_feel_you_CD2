extends Control

const NEXT_SCENE = "res://scenes/scene5.tscn"

@onready var label = $Label
@onready var name_label = $Name
@onready var back_button = $HBoxContainer/BackButton
@onready var next_button = $HBoxContainer/NextButton

var step = 0

var lines = [
	{"who": "You", "text": "*Don't move. Don't blink.*"},
	{"who": "Detective", "text": "Good. Very still."},
	{"who": "Detective", "text": "He controls his face well. Better than most."},
	{"who": "Detective", "text": "But he isn't the one I'm worried about."},
	{"who": "Detective", "text": "..."},
	{"who": "Detective", "text": "You."},
	{"who": "Detective", "text": "Yes, you. On the other side."},
	{"who": "Detective", "text": "You've been very quiet. Your face is the only thing that talks."},
	{"who": "Detective", "text": "Don't look away now."},
	{"who": "Detective", "text": "Let's see how well you hide it."},
]

func _ready():
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	show_line()

func show_line():
	var l = lines[step]
	name_label.text = l["who"] + ":"
	label.text = l["text"]
	back_button.disabled = (step == 0)

func _on_next_pressed():
	if step < lines.size() - 1:
		step += 1
		show_line()
	else:
		get_tree().change_scene_to_file(NEXT_SCENE)

func _on_back_pressed():
	if step > 0:
		step -= 1
		show_line()
