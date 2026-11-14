extends "res://scripts/dialogue_scene.gd"

const NEXT_SCENE := "res://scenes/scene3.tscn"

var intro := [
	{"who": "You", "text": "*That guy looks dangerous.*"},
	{"who": "Detective", "text": "So. You're the one they brought in."},
]

var greet_branch := [
	{"who": "You", "text": "Good evening."},
	{"who": "Detective", "text": "A greeting. Warm tone, steady eyes. Rehearsed."},
	{"who": "Detective", "text": "People who are calm don't need to prove it."},
	{"who": "Detective", "text": "Noted: attempt to control the conversation."},
]

var silent_branch := [
	{"who": "You", "text": "..."},
	{"who": "Detective", "text": "No greeting. No expression. Good."},
	{"who": "Detective", "text": "But silence is also a choice. We'll see what it hides."},
]

var choices := [
	{"text": "Greet him", "branch": "greet"},
	{"text": "Stay silent", "branch": "silent"},
]

var in_intro := true


func _setup() -> void:
	# The detective stands in the doorway, centre-left; the box sits to his right.
	place_box(Vector2(768, 150))
	in_intro = true
	set_queue(intro)


func _on_line_shown() -> void:
	if in_intro and at_end():
		show_choices(choices, _on_choice)


func _on_choice(c: Dictionary) -> void:
	in_intro = false
	set_queue(greet_branch if c["branch"] == "greet" else silent_branch)


func _on_queue_finished() -> void:
	if not in_intro:
		go_to(NEXT_SCENE)
