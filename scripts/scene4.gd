extends "res://scripts/dialogue_scene.gd"

const NEXT_SCENE := "res://scenes/scene5.tscn"


func _setup() -> void:
	# The detective leans in at the centre and the door is centre-right; a narrower box
	# sits on the plain wall right of the door, level with his face.
	place_box(Vector2(900, 180), 348.0)
	set_queue([
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
	])


func _on_queue_finished() -> void:
	go_to(NEXT_SCENE)
