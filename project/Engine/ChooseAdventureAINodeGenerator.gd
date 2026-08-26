extends Resource
class_name ChooseAdventureAINodeGenerator

const CONTRACT_SCHEMA:= "eralife.choose_adventure_ai_node_generator"
const CONTRACT_VERSION:= 2

var gs
var active_contract: Dictionary = {}
var last_generated_node: Dictionary = {}


func _init(_gs = null):
	gs = _gs
	active_contract = _build_default_contract()


func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_choose_adventure_ai_node_generator",
		"mode": "deterministic_contract_seeded",
		"limits": {
			"max_choices": 4,
			"max_text_chars": 2200,
		},
		"compatibility": {
		}
	}


func generate_node(context: Dictionary = {}) -> Dictionary:
	var state_raw: Variant = context.get("state", {})
	var state: Dictionary = state_raw.duplicate(true) if typeof(state_raw) == TYPE_DICTIONARY else {}

	var choice_raw: Variant = context.get("choice", {})
	var choice: Dictionary = choice_raw.duplicate(true) if typeof(choice_raw) == TYPE_DICTIONARY else {}

	var previous_node_raw: Variant = context.get("node", {})
	var previous_node: Dictionary = previous_node_raw.duplicate(true) if typeof(previous_node_raw) == TYPE_DICTIONARY else {}

	var pressure_raw: Variant = state.get("pressure", {})
	var pressure: Dictionary = pressure_raw.duplicate(true) if typeof(pressure_raw) == TYPE_DICTIONARY else {}

	var cycle: int = int(state.get("cycle", 0))
	var story_id: String = str(state.get("current_story_id", state.get("selected_adventure_id", ""))).strip_edges()
	var dominant_pressure: String = _dominant_pressure_key(pressure)
	var scene: Dictionary = _pick_scene(story_id, cycle, dominant_pressure, pressure, choice)

	var node_id: String = "dynamic_%s_%d_%s" % [
		story_id if story_id != "" else dominant_pressure,
		cycle,
		_short_id("%s.%d.%s.%s" % [story_id, cycle, dominant_pressure, str(choice.get("id", ""))])
	]

	var node:= {
		"id": node_id,
		"schema": "eralife.choose_adventure_node",
		"version": CONTRACT_VERSION,
		"dynamic": true,
		"panel_title": str(scene.get("panel_title", _title_from_story_id(story_id))),
		"subtitle": str(scene.get("subtitle", "The next choice has consequences.")),
		"text": str(scene.get("text", "")),
		"choices": scene.get("choices", []).duplicate(true) if typeof(scene.get("choices", [])) == TYPE_ARRAY else [],
		"accent": str(scene.get("accent", "#B56BFF")),
		"emoji": str(scene.get("emoji", "✦")),
		"footer_text": str(scene.get("footer_text", "The action changes because the world changed.")),
		"metadata": {
			"dominant_pressure": dominant_pressure,
			"cycle": cycle,
			"story_id": story_id,
			"generator": CONTRACT_SCHEMA,
			"previous_node_id": str(previous_node.get("id", "")),
			"previous_choice_id": str(choice.get("id", choice.get("choice_id", "")))
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}

	last_generated_node = node.duplicate(true)
	return node


func _pick_scene(story_id: String, cycle: int, dominant_pressure: String, pressure: Dictionary, choice: Dictionary) -> Dictionary:
	var pool: Array = _scene_pool_for_story(story_id)
	if pool.is_empty():
		pool = _fallback_pressure_scene_pool(dominant_pressure)

	var index_seed: int = abs(hash("%s.%d.%s.%s" % [
		story_id,
		cycle,
		dominant_pressure,
		str(choice.get("id", choice.get("choice_id", "")))
	]))

	var idx: int = index_seed % pool.size()
	var scene_raw: Variant = pool [idx]
	var scene: Dictionary = scene_raw.duplicate(true) if typeof(scene_raw) == TYPE_DICTIONARY else {}

	var pressure_total: float = _pressure_total(pressure)
	if pressure_total >= 72.0:
		var choices_raw: Variant = scene.get("choices", [])
		var choices: Array = choices_raw.duplicate(true) if typeof(choices_raw) == TYPE_ARRAY else []
		choices.append({
			"id": "birth_threshold_%d" % cycle,
			"label": "Let this become their life",
			"text": "Stop shaping from outside the world and be born into the consequences.",
			"overview": "The narrative pressure is high enough now. This choice ends the adventure phase and creates a real life using the pressure you built.",
			"emoji": "🌍",
			"accent": "#FFFFFF",
			"pressure": {
				"integrity": 4,
				"trauma": 4,
				"wealth": 4,
				"faction_tension": 4
			},
			"birth_candidate": true
		})
		scene ["choices"] = choices

	return scene


func _scene_pool_for_story(story_id: String) -> Array:
	match story_id:
		"runaway_heir":
			return [
				{
					"panel_title": "The Runaway Heir",
					"subtitle": "A crown can become a target before it becomes a title.",
					"accent": "#D9A441",
					"emoji": "👑",
					"text": "By dawn, the palace has split into two truths.\n\nIn the throne room, officials announce that the royal nursery is secure. In the servants’ district, a woman with shaking hands hides a child in a flour cart while soldiers search every alley.\n\nA retired knight recognizes the royal birthmark. He kneels, not because he is loyal — but because he is terrified.",
					"choices": [
						{
							"id": "heir_trust_retired_knight",
							"label": "Trust the retired knight",
							"text": "Let old loyalty become the child’s first shield.",
							"overview": "The knight can protect the heir, but his name is tied to old wars and older enemies.",
							"emoji": "🛡️",
							"accent": "#D9A441",
							"pressure": {
								"integrity": 10,
								"faction_tension": 8,
								"family_pressure": 8
							},
							"dynamic_node": true
						},
						{
							"id": "heir_sell_the_ring",
							"label": "Sell the royal ring for passage",
							"text": "Trade proof of identity for a chance to disappear.",
							"overview": "The child may survive, but the strongest proof of their claim enters the black market.",
							"emoji": "💍",
							"accent": "#FFB000",
							"pressure": {
								"wealth": 10,
								"corruption": 8,
								"faction_tension": 12
							},
							"dynamic_node": true
						},
						{
							"id": "heir_send_word_to_queen",
							"label": "Send secret word to the queen",
							"text": "Risk the messenger’s life to keep the family bond alive.",
							"overview": "If the queen receives the message, the child has protection. If enemies intercept it, the hunt sharpens.",
							"emoji": "✉️",
							"accent": "#FFE08A",
							"pressure": {
								"integrity": 12,
								"trauma": 6,
								"faction_tension": 10
							},
							"dynamic_node": true
						}
					]
				},
				{
					"panel_title": "The Runaway Heir",
					"subtitle": "The kingdom has started choosing sides.",
					"accent": "#D9A441",
					"emoji": "👑",
					"text": "A market singer performs a song about a missing child with royal eyes.\n\nBy afternoon, half the capital is humming it. By evening, guards are arresting anyone who knows the second verse. The child is still hidden, but the idea of the child has escaped.\n\nIdeas are harder to kill than heirs.",
					"choices": [
						{
							"id": "heir_feed_the_song",
							"label": "Spread the song wider",
							"text": "Turn the child into a public symbol.",
							"overview": "The people may protect a myth even when they cannot find the child.",
							"emoji": "🎶",
							"accent": "#FFD36A",
							"pressure": {
								"public_attention": 18,
								"faction_tension": 12,
								"integrity": 6
							},
							"dynamic_node": true
						},
						{
							"id": "heir_silence_the_singer",
							"label": "Silence the singer",
							"text": "Keep the child safe by killing the rumor.",
							"overview": "Safety may come at the cost of the one thing that could make people care.",
							"emoji": "🤫",
							"accent": "#A8732A",
							"pressure": {
								"corruption": 8,
								"public_attention": -10,
								"trauma": 8
							},
							"dynamic_node": true
						},
						{
							"id": "heir_change_the_lyrics",
							"label": "Change the lyrics into a false trail",
							"text": "Use the rumor as bait.",
							"overview": "The kingdom will chase a story, but stories sometimes turn around and chase back.",
							"emoji": "🗺️",
							"accent": "#F5C15F",
							"pressure": {
								"corruption": 6,
								"faction_tension": 10,
								"integrity": -2
							},
							"dynamic_node": true
						}
					]
				}
			]
		"corner_store_prophet":
			return [
				{
					"panel_title": "The Corner Store Prophet",
					"subtitle": "The block wants a miracle, but nobody wants the bill.",
					"accent": "#7CFF9B",
					"emoji": "🕯️",
					"text": "The woman from the freezer warning survives the night.\n\nBy morning, half the neighborhood believes the corner store is holy. The other half says the cashier staged it for attention. A local news van parks outside. Somebody tapes a handwritten sign to the door: IF GOD TALKING, BUY SOMETHING FIRST.",
					"choices": [
						{
							"id": "prophet_hold_prayer",
							"label": "Hold a prayer circle outside",
							"text": "Let the block gather around the sign.",
							"overview": "This can heal people, expose pain, or turn the store into a spectacle.",
							"emoji": "🙏",
							"accent": "#A4FFB8",
							"pressure": {
								"spiritual_weight": 18,
								"public_attention": 10,
								"integrity": 8
							},
							"dynamic_node": true
						},
						{
							"id": "prophet_refuse_camera",
							"label": "Refuse the news interview",
							"text": "Protect the miracle from becoming content.",
							"overview": "The story stays cleaner, but suspicion grows when nobody explains anything.",
							"emoji": "📵",
							"accent": "#7CFF9B",
							"pressure": {
								"integrity": 12,
								"public_attention": -8,
								"spiritual_weight": 8
							},
							"dynamic_node": true
						},
						{
							"id": "prophet_sell_blessed_water",
							"label": "Sell blessed water by the register",
							"text": "Let somebody monetize the miracle.",
							"overview": "Money enters the room. That always changes who claims ownership.",
							"emoji": "💧",
							"accent": "#4EFFC4",
							"pressure": {
								"wealth": 12,
								"corruption": 12,
								"spiritual_weight": -4,
								"public_attention": 10
							},
							"dynamic_node": true
						}
					]
				},
				{
					"panel_title": "The Corner Store Prophet",
					"subtitle": "The next warning names a child.",
					"accent": "#7CFF9B",
					"emoji": "🕯️",
					"text": "The receipt printer starts printing without paper loaded.\n\nOne line appears over and over: DO NOT LET MALIK WALK HOME ALONE.\n\nNobody knows which Malik. There are six on the block, three in the school, one in the barbershop, and one who has not been born yet.",
					"choices": [
						{
							"id": "prophet_warn_all_maliks",
							"label": "Warn every Malik you can find",
							"text": "Look ridiculous in every direction at once.",
							"overview": "Wide obedience may save someone, but it will also make the whole block stare.",
							"emoji": "🚲",
							"accent": "#90FFAE",
							"pressure": {
								"integrity": 16,
								"public_attention": 12,
								"spiritual_weight": 10
							},
							"dynamic_node": true
						},
						{
							"id": "prophet_check_unborn_records",
							"label": "Ask around about unborn babies",
							"text": "Search for the Malik who does not exist yet.",
							"overview": "This pulls family secrets, pregnancies, and fear into the miracle.",
							"emoji": "👶",
							"accent": "#C7FFD2",
							"pressure": {
								"family_pressure": 14,
								"spiritual_weight": 12,
								"trauma": 6
							},
							"dynamic_node": true
						},
						{
							"id": "prophet_blame_machine",
							"label": "Blame the machine and unplug it",
							"text": "Try to end the calling by cutting the power.",
							"overview": "The warning may stop. The danger may not.",
							"emoji": "🔌",
							"accent": "#54D97A",
							"pressure": {
								"spiritual_weight": -8,
								"trauma": 10,
								"integrity": -2
							},
							"dynamic_node": true
						}
					]
				}
			]
		"debt_baby":
			return [
				{
					"panel_title": "Born Owing Everybody",
					"subtitle": "The baby shower has become a budget hearing.",
					"accent": "#FF6B6B",
					"emoji": "💸",
					"text": "The landlord leaves, but not before everyone at the baby shower hears the balance.\n\nAn auntie says she can help if she gets paid back by Friday. A cousin says nobody should bring a child into this kind of instability. Someone else says the baby is the blessing that will force everybody to grow up.\n\nThe cake is melting. The family is not.",
					"choices": [
						{
							"id": "debt_accept_auntie_loan",
							"label": "Accept the auntie loan",
							"text": "Survive today and owe family tomorrow.",
							"overview": "The child enters a family where help and control are tied together.",
							"emoji": "🧾",
							"accent": "#FF8A8A",
							"pressure": {
								"wealth": 8,
								"family_pressure": 16,
								"trauma": 4
							},
							"dynamic_node": true
						},
						{
							"id": "debt_refuse_help",
							"label": "Refuse help out of pride",
							"text": "Keep dignity clean and the lights uncertain.",
							"overview": "This protects independence, but the future life may inherit survival stress.",
							"emoji": "🚪",
							"accent": "#FF5252",
							"pressure": {
								"integrity": 8,
								"wealth": -12,
								"trauma": 10,
								"family_pressure": -4
							},
							"dynamic_node": true
						},
						{
							"id": "debt_make_joke",
							"label": "Make everybody laugh",
							"text": "Break the shame before it breaks the room.",
							"overview": "Humor becomes a family defense mechanism. Powerful. Dangerous. Familiar.",
							"emoji": "😂",
							"accent": "#FFA06B",
							"pressure": {
								"integrity": 6,
								"trauma": -4,
								"public_attention": 4,
								"family_pressure": 8
							},
							"dynamic_node": true
						}
					]
				}
			]
		"schoolyard_legend":
			return [
				{
					"panel_title": "The Schoolyard Legend",
					"subtitle": "Everybody saw. Now everybody has a version.",
					"accent": "#5DA8FF",
					"emoji": "🎒",
					"text": "By lunch, the playground moment has become three different stories.\n\nOne version says the child is brave. One says they are a snitch. One says they only acted tough because the teacher was nearby.\n\nAt a cafeteria table, the smaller student quietly slides over half a cookie as thanks.",
					"choices": [
						{
							"id": "schoolyard_accept_cookie",
							"label": "Accept the cookie and sit with them",
							"text": "Let kindness become visible.",
							"overview": "This may cost social status, but it builds a loyalty that can outlast popularity.",
							"emoji": "🍪",
							"accent": "#7BBCFF",
							"pressure": {
								"integrity": 12,
								"public_attention": 6,
								"family_pressure": 2
							},
							"dynamic_node": true
						},
						{
							"id": "schoolyard_reject_cookie",
							"label": "Reject it so nobody jokes on you",
							"text": "Protect reputation by hurting someone gently.",
							"overview": "The future life learns that image can cost more than honesty.",
							"emoji": "🧊",
							"accent": "#5DA8FF",
							"pressure": {
								"corruption": 6,
								"trauma": 6,
								"public_attention": 8
							},
							"dynamic_node": true
						},
						{
							"id": "schoolyard_call_out_rumors",
							"label": "Call out the rumors at lunch",
							"text": "Challenge the whole cafeteria story machine.",
							"overview": "This creates courage and heat at the same time.",
							"emoji": "📣",
							"accent": "#95D0FF",
							"pressure": {
								"integrity": 14,
								"public_attention": 14,
								"trauma": 4
							},
							"dynamic_node": true
						}
					]
				}
			]
		"cult_of_fame":
			return [
				{
					"panel_title": "The Cult of Fame",
					"subtitle": "The internet has started naming what belongs to the family.",
					"accent": "#FF4FD8",
					"emoji": "📸",
					"text": "A brand sends a contract with more money than anyone in the kitchen has ever seen at once.\n\nThe comments are already calling the child a star. A stranger makes fan art. Another stranger says the parents are exploiting them. A relative asks why the family would turn down a blessing.\n\nThe child is asleep in the next room, unaware that their laugh has become an industry.",
					"choices": [
						{
							"id": "fame_hire_lawyer",
							"label": "Hire a real lawyer first",
							"text": "Slow the money down before it enters the family.",
							"overview": "This protects the child but may anger relatives who already started spending imaginary checks.",
							"emoji": "⚖️",
							"accent": "#FF8BE8",
							"pressure": {
								"integrity": 12,
								"wealth": 8,
								"family_pressure": 10,
								"public_attention": 4
							},
							"dynamic_node": true
						},
						{
							"id": "fame_post_more",
							"label": "Post another video immediately",
							"text": "Feed the algorithm while it is hungry.",
							"overview": "Attention compounds quickly, but so does dependency.",
							"emoji": "📱",
							"accent": "#FF4FD8",
							"pressure": {
								"wealth": 14,
								"public_attention": 20,
								"corruption": 6,
								"family_pressure": 8
							},
							"dynamic_node": true
						},
						{
							"id": "fame_make_account_private",
							"label": "Make the account private",
							"text": "Try to put the lightning back in the bottle.",
							"overview": "This may protect the child, but the internet does not like losing access.",
							"emoji": "🔒",
							"accent": "#D645B9",
							"pressure": {
								"integrity": 14,
								"public_attention": -14,
								"trauma": 6
							},
							"dynamic_node": true
						}
					]
				}
			]
		_:
			return []


func _fallback_pressure_scene_pool(dominant_pressure: String) -> Array:
	return [
		{
			"panel_title": "The Story Pushes Back",
			"subtitle": "The simulation needs a sharper shape.",
			"accent": "#B56BFF",
			"emoji": "✦",
			"text": "The adventure does not collapse. It adapts.\n\nA new scene forms from the pressure you created, not from a prewritten ending. The world is asking what kind of person could survive the weight you keep adding.",
			"choices": [
				{
					"id": "fallback_protect_someone",
					"label": "Protect someone vulnerable",
					"text": "Turn the pressure toward mercy.",
					"overview": "This adds integrity and family gravity.",
					"emoji": "🛡️",
					"accent": "#B56BFF",
					"pressure": {
						"integrity": 12,
						"family_pressure": 6
					},
					"dynamic_node": true
				},
				{
					"id": "fallback_take_power",
					"label": "Take control of the situation",
					"text": "Turn uncertainty into authority.",
					"overview": "This may create wealth, attention, or corruption depending on the life that follows.",
					"emoji": "🔥",
					"accent": "#FF8A3D",
					"pressure": {
						dominant_pressure: 12,
						"public_attention": 8
					},
					"dynamic_node": true
				},
				{
					"id": "fallback_walk_away",
					"label": "Walk away and let consequences breathe",
					"text": "Refuse to force the story.",
					"overview": "The world keeps moving, but not always in your favor.",
					"emoji": "🌫️",
					"accent": "#8A8AFF",
					"pressure": {
						"trauma": 4,
						"integrity": 4
					},
					"dynamic_node": true
				}
			]
		}
	]


func _title_from_story_id(story_id: String) -> String:
	match story_id:
		"runaway_heir":
			return "The Runaway Heir"
		"corner_store_prophet":
			return "The Corner Store Prophet"
		"debt_baby":
			return "Born Owing Everybody"
		"schoolyard_legend":
			return "The Schoolyard Legend"
		"cult_of_fame":
			return "The Cult of Fame"
		_:
			return "Choose Your Own Adventure"


func _dominant_pressure_key(pressure: Dictionary) -> String:
	var best_key: String = "integrity"
	var best_value: float = -1.0

	for raw_key in pressure.keys():
		var key: String = str(raw_key)
		var value: float = abs(float(pressure.get(raw_key, 0.0)))
		if value > best_value:
			best_value = value
			best_key = key

	return best_key


func _pressure_total(pressure: Dictionary) -> float:
	var total: float = 0.0
	for raw_key in pressure.keys():
		total += abs(float(pressure.get(raw_key, 0.0)))
	return total


func _short_id(source: String) -> String:
	var value: int = abs(hash(source))
	return String.num_int64(value, 36)