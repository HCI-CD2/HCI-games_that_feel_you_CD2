extends Control

@onready var label = $Label
@onready var back_button = $HBoxContainer/BackButton
@onready var next_button = $HBoxContainer/NextButton

var step = 0

var lines = [
	"The room is quiet.",
	"I should have refused. What if they find out?",
	"No, no. Everything will be fine. I need to calm down.",
	"I've already thought it all through."
]

func _ready():
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	show_line()

func show_line():
	label.text = lines[step]
	back_button.disabled = (step == 0)

func _on_next_pressed():
	if step < lines.size() - 1:
		step += 1
		show_line()
	else:
		get_tree().change_scene_to_file("res://scenes/scene2.tscn")

func _on_back_pressed():
	if step > 0:
		step -= 1
		show_line()
