extends "res://scripts/dialogue_scene.gd"

const SUSPICION_LIMIT := 2
const NEXT_SCENE := "res://scenes/scene4.tscn"
const END_SCENE := "res://scenes/scene1.tscn"

## The face-reading moment comes after this many questions. Two is the latest
## point where nobody can have been caught yet, so every player reaches it.
const MOOD_BEAT_AFTER := 2

# Face rules, from the webcam work. The face counts only if it was tracked for at least
# FACE_MIN_SECONDS, and it counts as "not calm" when that showed for FACE_SHARE of the time.
const FACE_SHARE := 0.5
const FACE_COST := 1
const FACE_MIN_SECONDS := 1.0

## The detective's one line that depends on the player's face.
## The "" entry is used when the game has no face reading it may react to.
const MOOD_LINES := {
	"": "You've gone quiet. Let's return to the question.",
	"calm": "You're keeping remarkably calm. Is that because you have nothing to hide?",
	"tense": "Those clenched features. Something about that question seems to have unsettled you.",
	"smiling": "A smile. In this building? Careful. People might misunderstand.",
	"looked_away": "Look at me when I'm asking you a question. What are you avoiding?",
}

var suspicion := 0
var q_index := 0
var phase := "question"  # question, reaction, lead_in, mood, caught, released
var mood_point := 0      # what the face reading cost, kept so it can be given back

var questions := [
	{
		"lines": [
			"Let's keep this simple.",
			"Tuesday night. A neighbor says your light was on until three. Where were you?"
		],
		"options": [
			{"text": "Home. I don't keep track of my lights.", "cost": 0,
			 "reply": ["Home. Fine.", "I'll write that down."]},
			{"text": "I was asleep by eleven. My light was off.", "cost": 1,
			 "reply": ["Eleven exactly. Off exactly.", "Most people don't remember their evenings that precisely."]},
			{"text": "Which neighbor said that?", "cost": 1,
			 "reply": ["You want a name. Why?", "Innocent people don't audit the witnesses."]},
		]
	},
	{
		"lines": [
			"The body was found in the kitchen.",
			"On the floor, near the stove. Does that sound familiar?"
		],
		"options": [
			{"text": "I wouldn't know where he was found.", "cost": 0,
			 "reply": ["No. You wouldn't."]},
			{"text": "The kitchen? That's not right.", "cost": 1,
			 "reply": ["Not right?", "Only two people know where he really was. Me, and the one who left him there."]},
			{"text": "Was there a lot of blood?", "cost": 1,
			 "reply": ["A lot. You're curious.", "Curiosity is an emotion."]},
		]
	},
	{
		"lines": [
			"A witness saw a man in a grey coat leaving his building at midnight.",
			"You own a grey coat."
		],
		"options": [
			{"text": "A lot of people own a grey coat.", "cost": 0,
			 "reply": ["They do.", "But not many of them were seen there."]},
			{"text": "I own one. I wasn't wearing it that night.", "cost": 1,
			 "reply": ["That night.", "I never asked about that night. You offered it."]},
			{"text": "Check it. You won't find anything.", "cost": 1,
			 "reply": ["We will.", "\"Nothing.\" You've already decided what we'll find."]},
		]
	},
	{
		"lines": [
			"He had a daughter. Eight years old.",
			"She asked me today when her father is coming home. What should I tell her?"
		],
		"options": [
			{"text": "I'm sorry. That's terrible.", "cost": 1,
			 "reply": ["Sorry.", "There's no room for that word here. Everyone in this building is calm. You're not."]},
			{"text": "I have nothing to tell her.", "cost": 0,
			 "reply": ["Nothing. Of course.", "That's the answer I expected."]},
			{"text": "Tell her he isn't coming home.", "cost": 1,
			 "reply": ["Not coming home.", "You sound very sure for someone who knows nothing."]},
		]
	},
	{
		"lines": [
			"One blow. From behind. No struggle.",
			"Is that how you would do it?"
		],
		"options": [
			{"text": "From behind makes sense. He wouldn't see it coming.", "cost": 1,
			 "reply": ["Wouldn't see it coming.", "That's a very precise thought."]},
			{"text": "No struggle? That's hard to believe.", "cost": 1,
			 "reply": ["Hard to believe.", "Why? What would you expect to see?"]},
			{"text": "I wouldn't do it at all.", "cost": 0,
			 "reply": ["Everyone says that.", "Tonight, a few of them even mean it."]},
		]
	},
	{
		"lines": [
			"Someone close to you has already talked.",
			"They say you came to them afterward. Your hands weren't steady."
		],
		"options": [
			{"text": "Bring them in. I'll say it to their face.", "cost": 1,
			 "reply": ["Eager.", "Calm people don't ask for confrontations."]},
			{"text": "Whoever it is, they're lying.", "cost": 1,
			 "reply": ["You haven't heard a name.", "Yet you already know they're lying."]},
			{"text": "I don't know who you mean.", "cost": 0,
			 "reply": ["No. You don't.", "We'll see."]},
		]
	},
]


func _setup() -> void:
	# The detective sits centre-left; the box sits to his right, below the monitor
	# at its tallest (condition C), so the layout is the same in all three conditions.
	place_box(Vector2(700, 168))
	set_monitor(suspicion, true)
	FaceData.changed.connect(_on_face_changed)
	start_question()


func start_question() -> void:
	phase = "question"
	set_progress(q_index, questions.size())
	# The face is watched from the question before the face-reading moment until that moment.
	if q_index == MOOD_BEAT_AFTER - 1:
		FaceData.start_window()
	set_queue(lines_for("Detective", questions[q_index]["lines"]))


func _on_line_shown() -> void:
	if phase == "question" and at_end():
		var opts: Array = questions[q_index]["options"].duplicate()
		opts.shuffle()
		show_choices(opts, _on_choice)


func _on_choice(o: Dictionary) -> void:
	suspicion += int(o["cost"])
	set_monitor(suspicion, true)
	set_progress(q_index + 1, questions.size())
	phase = "reaction"
	set_queue(lines_for("You", [o["text"]]) + lines_for("Detective", o["reply"]))


func _on_queue_finished() -> void:
	match phase:
		"reaction":
			if suspicion > SUSPICION_LIMIT:
				start_caught()
			else:
				q_index += 1
				if q_index == MOOD_BEAT_AFTER:
					start_lead_in()
				else:
					next_question()
		"lead_in":
			start_mood_line()
		"mood":
			if suspicion > SUSPICION_LIMIT:
				start_caught()
			else:
				next_question()
		"caught":
			go_to(NEXT_SCENE)
		"released":
			go_to(END_SCENE)


## Asks the next question, or lets the player go when none are left.
func next_question() -> void:
	if q_index >= questions.size():
		start_released()
	else:
		start_question()


## Two lines that set up the face-reading moment. The face is still being watched.
func start_lead_in() -> void:
	phase = "lead_in"
	set_queue(lines_for("Detective", [
		"People in this city learn to control their faces.",
		"But under pressure, people show more than they intend.",
	]))


## The face-reading moment: one line, picked by what the player's face showed since the
## last question was asked. Anything other than calm costs FACE_COST suspicion.
func start_mood_line() -> void:
	phase = "mood"
	var seen := face_verdict(FaceData.end_window())
	if seen != "" and seen != "calm":
		mood_point = FACE_COST
		suspicion += mood_point
		set_monitor(suspicion, true)
	set_queue(lines_for("Detective", [MOOD_LINES.get(seen, MOOD_LINES[""])]))


## Turns FaceData's summary of the measuring window into one label, or "" when the face
## must not be used (buttons only, switched off, rejected) or was not seen for long enough.
func face_verdict(window: Dictionary) -> String:
	if not FaceData.may_react():
		return ""
	if window["seconds"] < FACE_MIN_SECONDS:
		return ""
	if window["stressed_share"] < FACE_SHARE:
		return "calm"
	return window["stressed_label"]


## Runs whenever FaceData announces a change. If the player rejects the reading or switches
## it off while the detective is still reacting to it, the point is given back.
func _on_face_changed() -> void:
	if phase == "mood" and mood_point > 0 and not FaceData.may_react():
		suspicion -= mood_point
		mood_point = 0
		set_monitor(suspicion, true)


func start_caught() -> void:
	phase = "caught"
	set_queue(lines_for("Detective", [
		"Mm. Interesting.",
		"We watch your face. It's all there."
	]))


func start_released() -> void:
	phase = "released"
	set_queue(lines_for("Detective", [
		"That will be all.",
		"Thank you for your cooperation.",
		"You may go."
	]))
