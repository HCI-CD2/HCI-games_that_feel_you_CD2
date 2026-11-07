extends Control

# TODO (webcam): the lines below are a TEMPORARY stand-in.
# Real version: webcam face/expression tracking drives these reactions.
# Until the webcam feature is implemented, the detective only pretends to see the player.

const NEXT_SCENE = ""
const SCARY_BG = "res://art/scary_face.png"
const SCARY_FROM_STEP = 1

@onready var label = $Label
@onready var name_label = $Name
@onready var back_button = $HBoxContainer/BackButton
@onready var next_button = $HBoxContainer/NextButton
@onready var bg = get_node_or_null("TextureRect")

var step = 0

var lines = [
	{"who": "Detective", "text": "There it is."},
	{"who": "Detective", "text": "That face. You can stop pretending now."},
	{"who": "Detective", "text": "..."},
	# --- (replace when the webcam is implemented) ---
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
	var last = (step == lines.size() - 1)
	next_button.disabled = (last and NEXT_SCENE == "")
	update_bg()

func update_bg():
	if bg == null:
		return
	if step >= SCARY_FROM_STEP and ResourceLoader.exists(SCARY_BG):
		bg.texture = load(SCARY_BG)

func _on_next_pressed():
	if step < lines.size() - 1:
		step += 1
		show_line()
	elif NEXT_SCENE != "":
		get_tree().change_scene_to_file(NEXT_SCENE)

func _on_back_pressed():
	if step > 0:
		step -= 1
		show_line()
