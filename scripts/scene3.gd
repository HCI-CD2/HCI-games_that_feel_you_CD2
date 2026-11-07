extends Control

const SUSPICION_LIMIT = 2
const NEXT_SCENE = "res://scenes/scene4.tscn"
const END_SCENE = "res://scenes/scene1.tscn"

@onready var label = $Label
@onready var name_label = $Name
@onready var choices_box = $Choices
@onready var back_button = $HBoxContainer/BackButton
@onready var next_button = $HBoxContainer/NextButton
@onready var hud = get_node_or_null("Suspicion")

var suspicion = 0
var q_index = 0
var step = 0
var phase = "question"
var queue = []

var questions = [
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

func _ready():
	back_button.hide()
	next_button.pressed.connect(_on_next_pressed)
	update_hud()
	start_question()

func make_queue(lines, who):
	var result = []
	for t in lines:
		result.append({"who": who, "text": t})
	return result

func update_hud():
	if hud:
		hud.text = "Suspicion: " + str(suspicion)

func start_question():
	phase = "question"
	queue = make_queue(questions[q_index]["lines"], "Detective")
	step = 0
	show_line()

func show_line():
	var l = queue[step]
	name_label.text = l["who"] + ":"
	label.text = l["text"]
	clear_choices()
	var at_end = (step == queue.size() - 1)
	var ask = (phase == "question" and at_end)
	next_button.visible = not ask
	if ask:
		build_choices()

func build_choices():
	var opts = questions[q_index]["options"].duplicate()
	opts.shuffle()
	for o in opts:
		var b = Button.new()
		b.text = o["text"]
		b.custom_minimum_size = Vector2(560, 44)
		b.pressed.connect(_on_choice.bind(o))
		choices_box.add_child(b)
	choices_box.show()

func clear_choices():
	for child in choices_box.get_children():
		child.queue_free()
	choices_box.hide()

func _on_choice(o):
	suspicion += o["cost"]
	update_hud()
	phase = "reaction"
	queue = make_queue([o["text"]], "You") + make_queue(o["reply"], "Detective")
	step = 0
	show_line()

func _on_next_pressed():
	if step < queue.size() - 1:
		step += 1
		show_line()
		return
	if phase == "reaction":
		if suspicion > SUSPICION_LIMIT:
			start_caught()
		else:
			q_index += 1
			if q_index >= questions.size():
				start_released()
			else:
				start_question()
	elif phase == "caught":
		get_tree().change_scene_to_file(NEXT_SCENE)
	elif phase == "released":
		get_tree().change_scene_to_file(END_SCENE)

func start_caught():
	phase = "caught"
	queue = make_queue([
		"Mm. Interesting.",
		"We watch your face. It's all there."
	], "Detective")
	step = 0
	show_line()

func start_released():
	phase = "released"
	queue = make_queue([
		"That will be all.",
		"Thank you for your cooperation.",
		"You may go."
	], "Detective")
	step = 0
	show_line()
