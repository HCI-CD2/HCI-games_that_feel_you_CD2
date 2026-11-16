extends "res://scripts/dialogue_scene.gd"

const NEXT_SCENE := "res://scenes/scene2.tscn"


func _setup() -> void:
	# The player's own thoughts: box on the plain right wall, clear of the door and the lamp.
	place_box(Vector2(768, 120))
	set_queue(lines_for("You", [
		"*The room is quiet.*",
		"*A small monitoring device is fixed high on the wall.*",
		"*I have seen devices like it throughout the city.*",
		"*I should have refused. What if they find out?*",
		"*No, no. Everything will be fine. I need to calm down.*",
		"*I've already thought it all through.*",
	]))


func _on_queue_finished() -> void:
	go_to(NEXT_SCENE)
