extends "res://scripts/dialogue_scene.gd"

# TODO (webcam): the lines below are a temporary stand-in.
# Real version: the webcam label drives these reactions.
# Until then the detective only pretends to see the player.

const NEXT_SCENE := ""
const SCARY_BG := "res://art/scary_face.png"
const SCARY_FROM_STEP := 1


func _setup() -> void:
	# Same framing as scene 4: narrow box on the plain wall right of the door.
	place_box(Vector2(900, 180), 348.0)
	# The door scenes in the reference go pure green; so does the moment it turns on you.
	set_tint(Color(0.02, 0.16, 0.1), Color(0.75, 1.0, 0.8), 0.75)
	set_queue(lines_for("Detective", [
		"There it is.",
		"That face. You can stop pretending now.",
		"...",
	]))


func _on_line_shown() -> void:
	if step >= SCARY_FROM_STEP and ResourceLoader.exists(SCARY_BG):
		background.texture = load(SCARY_BG)
	if at_end() and NEXT_SCENE == "":
		lock_end()


func _on_queue_finished() -> void:
	if NEXT_SCENE != "":
		go_to(NEXT_SCENE)
