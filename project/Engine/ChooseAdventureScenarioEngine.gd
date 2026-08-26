extends Resource
class_name ChooseAdventureScenarioEngine

const CONTRACT_SCHEMA:= "eralife.choose_adventure_scenario_engine"
const CONTRACT_VERSION:= 1

var gs
var active_contract: Dictionary = {}
var last_result: Dictionary = {}


func _init(_gs = null):
	gs = _gs
	active_contract = _build_default_contract()
	_ensure_catalog_story_pool()
	_ensure_state()


func _ensure_state() -> Dictionary:
	if gs == null:
		return {}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var state_raw: Variant = gs.scenario_state.get("choose_adventure", {})
	var state: Dictionary = state_raw.duplicate(true) if typeof(state_raw) == TYPE_DICTIONARY else {}

	if state.is_empty():
		state = {}

	state ["schema"] = str(state.get("schema", "eralife.choose_adventure_state"))
	state ["version"] = max(1, int(state.get("version", CONTRACT_VERSION)))
	state ["active"] = bool(state.get("active", false))
	state ["catalog_open"] = bool(state.get("catalog_open", false))
	state ["cycle"] = int(state.get("cycle", 0))
	state ["current_story_id"] = str(state.get("current_story_id", ""))
	state ["selected_adventure_id"] = str(state.get("selected_adventure_id", state.get("current_story_id", "")))
	state ["current_node_id"] = str(state.get("current_node_id", ""))

	var pressure_raw: Variant = state.get("pressure", {})
	var pressure: Dictionary = pressure_raw.duplicate(true) if typeof(pressure_raw) == TYPE_DICTIONARY else {}
	for key in ["integrity", "corruption", "trauma", "wealth", "faction_tension", "family_pressure", "public_attention", "spiritual_weight"]:
		if not pressure.has(key):
			pressure [key] = 0.0
	state ["pressure"] = pressure

	if typeof(state.get("pressure_history", [])) != TYPE_ARRAY:
		state ["pressure_history"] = []

	if typeof(state.get("node_registry", {})) != TYPE_DICTIONARY:
		state ["node_registry"] = {}

	if typeof(state.get("visited_nodes", [])) != TYPE_ARRAY:
		state ["visited_nodes"] = []

	if typeof(state.get("adventure_history", [])) != TYPE_ARRAY:
		state ["adventure_history"] = []

	state ["node_injections_this_cycle"] = int(state.get("node_injections_this_cycle", 0))
	state ["saturation"] = float(state.get("saturation", 0.0))
	state ["birth_ready"] = bool(state.get("birth_ready", false))

	if typeof(state.get("last_result", {})) != TYPE_DICTIONARY:
		state ["last_result"] = {}

	gs.scenario_state ["choose_adventure"] = state
	return state


func _write_state(state: Dictionary) -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["choose_adventure"] = state.duplicate(true)


func _build_default_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "default_choose_adventure_contract",
		"entry_story_id": "adventure_catalog",
		"rules": {
			"choice_resolution": "choice_to_pressure_to_world_reaction",
			"birth_trigger": "saturation_threshold",
			"every_choice_advances_node": true,
		},
		"catalog": {
			"title": "Choose Your Own Adventure",
			"subtitle": "Pick the kind of life-pressure you want to step into.",
			"text": "These are not endings. They are living story contracts.\n\nEach adventure lets you make choices before birth. Those choices push on the world — family, money, danger, faith, factions, love, survival, reputation — until the simulation becomes saturated enough to create a real life from what you shaped."
		},
		"stories": {
			"runaway_heir": {
				"id": "runaway_heir",
				"title": "The Runaway Heir",
				"genre": "Royal Drama",
				"accent": "#D9A441",
				"emoji": "👑",
				"overview": "You are born near a throne before you are born into a body.\n\nA royal child has disappeared from a palace where every smile has a witness and every witness has a price. Servants whisper that the heir was hidden to prevent a succession war. Ministers insist the bloodline is stable. The queen has not slept in three nights.\n\nYour choices decide whether this future life enters the world protected, hunted, entitled, exiled, or carrying a claim nobody can safely say out loud.",
				"root_node": "runaway_heir_root",
				"nodes": {
					"runaway_heir_root": {
						"id": "runaway_heir_root",
						"panel_title": "The Runaway Heir",
						"subtitle": "A throne is not inherited. It is survived.",
						"text": "Rain crawls down the palace windows while a nurse carries a wrapped infant through a servants’ corridor.\n\nBehind her, bells ring for a royal banquet. Ahead of her, a side gate waits in the dark. The child does not know they are important yet. The kingdom does.\n\nA captain stops the nurse and asks what is under the blanket.",
						"choices": [
							{
								"id": "heir_lie_to_captain",
								"label": "Tell the captain it is laundry",
								"text": "Protect the child through deception.",
								"pressure": {
									"integrity": -3,
									"corruption": 8,
									"faction_tension": 14,
									"family_pressure": 10
								},
								"dynamic_node": true
							},
							{
								"id": "heir_reveal_the_child",
								"label": "Reveal the child and demand loyalty",
								"text": "Put the royal claim in the open before anyone is ready.",
								"pressure": {
									"integrity": 10,
									"public_attention": 12,
									"faction_tension": 16
								},
								"dynamic_node": true
							},
							{
								"id": "heir_escape_through_gate",
								"label": "Run before the captain can look",
								"text": "Turn the royal bloodline into a fugitive secret.",
								"pressure": {
									"trauma": 10,
									"faction_tension": 12,
									"family_pressure": 8
								},
								"dynamic_node": true
							}
						]
					}
				}
			},
			"corner_store_prophet": {
				"id": "corner_store_prophet",
				"title": "The Corner Store Prophet",
				"genre": "Street Myth",
				"accent": "#7CFF9B",
				"emoji": "🕯️",
				"overview": "A broke neighborhood keeps seeing impossible signs around a corner store that should have closed years ago.\n\nA cashier dreams tomorrow’s tragedies. A child hears names from a broken freezer. A local pastor says God is warning the block. A landlord says everybody is hallucinating because rent is due.\n\nYour choices decide whether this future life is born into spiritual calling, public skepticism, miracle pressure, or a community that expects one person to save everybody.",
				"root_node": "corner_store_root",
				"nodes": {
					"corner_store_root": {
						"id": "corner_store_root",
						"panel_title": "The Corner Store Prophet",
						"subtitle": "Some miracles arrive with a receipt printer jam.",
						"text": "At 2:13 AM, every light in the corner store flickers except the freezer by the back wall.\n\nInside the glass, frost writes a name that belongs to a woman across the street. She is asleep. She is also in danger.\n\nThe cashier sees the name, the security camera sees nothing, and outside, a boy on a bike swears he heard angels arguing near the lottery machine.",
						"choices": [
							{
								"id": "prophet_warn_woman",
								"label": "Warn the woman immediately",
								"text": "Risk looking crazy to protect a stranger.",
								"pressure": {
									"integrity": 14,
									"spiritual_weight": 16,
									"public_attention": 8
								},
								"dynamic_node": true
							},
							{
								"id": "prophet_record_evidence",
								"label": "Record the freezer before acting",
								"text": "Choose proof before obedience.",
								"pressure": {
									"integrity": 4,
									"public_attention": 16,
									"spiritual_weight": 8
								},
								"dynamic_node": true
							},
							{
								"id": "prophet_ignore_sign",
								"label": "Ignore it and finish the shift",
								"text": "Refuse the burden before it names you.",
								"pressure": {
									"trauma": 12,
									"spiritual_weight": -4,
									"corruption": 4
								},
								"dynamic_node": true
							}
						]
					}
				}
			},
			"debt_baby": {
				"id": "debt_baby",
				"title": "Born Owing Everybody",
				"genre": "Survival Comedy Drama",
				"accent": "#FF6B6B",
				"emoji": "💸",
				"overview": "Before a child even has a name, the adults around them are already arguing over bills, favors, rent, custody, pride, and who bought diapers last time.\n\nThis is not poverty as a stat. This is pressure as atmosphere. Every choice shapes whether the future life is born hustling, ashamed, hilarious, angry, generous, manipulative, or spiritually unbreakable.\n\nThe world can make them broke. Your choices decide whether it also makes them small.",
				"root_node": "debt_baby_root",
				"nodes": {
					"debt_baby_root": {
						"id": "debt_baby_root",
						"panel_title": "Born Owing Everybody",
						"subtitle": "Some families pass down heirlooms. Some pass down payment arrangements.",
						"text": "A baby shower is happening in a cramped apartment with folding chairs, loud aunties, and a cake that says ‘WELCOME LITTLE MIRACLE’ even though nobody knows who paid for it.\n\nIn the kitchen, two relatives are whisper-fighting over rent money. In the living room, someone announces they started a college fund with seven dollars and a coupon.\n\nThen the landlord knocks.",
						"choices": [
							{
								"id": "debt_hide_from_landlord",
								"label": "Tell everyone to get quiet",
								"text": "Survive through avoidance and family teamwork.",
								"pressure": {
									"wealth": -10,
									"family_pressure": 14,
									"trauma": 6,
									"integrity": -2
								},
								"dynamic_node": true
							},
							{
								"id": "debt_answer_with_pride",
								"label": "Answer the door with pride",
								"text": "Refuse shame even when the money is missing.",
								"pressure": {
									"integrity": 10,
									"public_attention": 6,
									"family_pressure": 8
								},
								"dynamic_node": true
							},
							{
								"id": "debt_start_collection",
								"label": "Make everybody donate on the spot",
								"text": "Turn panic into a family fundraiser.",
								"pressure": {
									"wealth": 12,
									"family_pressure": 10,
									"corruption": 3
								},
								"dynamic_node": true
							}
						]
					}
				}
			},
			"schoolyard_legend": {
				"id": "schoolyard_legend",
				"title": "The Schoolyard Legend",
				"genre": "Coming-of-Age",
				"accent": "#5DA8FF",
				"emoji": "🎒",
				"overview": "Before this future life reaches adulthood, the myth starts early.\n\nA playground fight, a stolen lunch card, a teacher who sees too much, a friend who lies to protect them, and a school that turns one rumor into a whole identity.\n\nYour choices decide whether the future person is born with social courage, fear of humiliation, protector energy, bully energy, or the kind of charisma that starts before they understand it.",
				"root_node": "schoolyard_root",
				"nodes": {
					"schoolyard_root": {
						"id": "schoolyard_root",
						"panel_title": "The Schoolyard Legend",
						"subtitle": "The first rumor becomes the first mask.",
						"text": "A child stands near the monkey bars while three older kids surround a smaller student by the fence.\n\nA teacher is close enough to help but distracted by a phone call. Everyone else is watching with that dangerous playground silence where nobody wants to be next.\n\nThe child has one clean moment before the story of who they are begins.",
						"choices": [
							{
								"id": "schoolyard_step_in",
								"label": "Step between them",
								"text": "Become brave before becoming safe.",
								"pressure": {
									"integrity": 16,
									"trauma": 5,
									"public_attention": 10
								},
								"dynamic_node": true
							},
							{
								"id": "schoolyard_get_teacher",
								"label": "Get the teacher",
								"text": "Choose help over glory.",
								"pressure": {
									"integrity": 10,
									"public_attention": -2,
									"family_pressure": 3
								},
								"dynamic_node": true
							},
							{
								"id": "schoolyard_laugh_along",
								"label": "Laugh along so they leave you alone",
								"text": "Trade someone else’s safety for your own belonging.",
								"pressure": {
									"corruption": 10,
									"trauma": 8,
									"public_attention": 6
								},
								"dynamic_node": true
							}
						]
					}
				}
			},
			"cult_of_fame": {
				"id": "cult_of_fame",
				"title": "The Cult of Fame",
				"genre": "Celebrity Horror Satire",
				"accent": "#FF4FD8",
				"emoji": "📸",
				"overview": "A family uploads one video of a child doing something funny. By morning, millions of strangers have opinions about the child’s face, future, talent, parents, voice, and value.\n\nManagers call. Relatives change their tone. The internet starts acting like ownership.\n\nYour choices decide whether this future life is born into performance pressure, public love, exploitation, wealth, paranoia, or a destiny where attention feels like oxygen and poison at the same time.",
				"root_node": "cult_fame_root",
				"nodes": {
					"cult_fame_root": {
						"id": "cult_fame_root",
						"panel_title": "The Cult of Fame",
						"subtitle": "The algorithm noticed the baby before the baby noticed itself.",
						"text": "A toddler’s laugh goes viral because someone clipped it with dramatic music and a caption about destiny.\n\nBy sunrise, strangers are stitching the video, brands are emailing, and one uncle has already put ‘manager’ in his bio.\n\nThe parents sit at the kitchen table staring at numbers that look too large to be real.",
						"choices": [
							{
								"id": "fame_delete_video",
								"label": "Delete the video",
								"text": "Protect the child from becoming content.",
								"pressure": {
									"integrity": 16,
									"wealth": -8,
									"public_attention": -14
								},
								"dynamic_node": true
							},
							{
								"id": "fame_sign_brand_deal",
								"label": "Take the brand deal",
								"text": "Turn attention into money before it disappears.",
								"pressure": {
									"wealth": 18,
									"public_attention": 18,
									"corruption": 6,
									"family_pressure": 8
								},
								"dynamic_node": true
							},
							{
								"id": "fame_set_boundaries",
								"label": "Accept fame with strict boundaries",
								"text": "Try to build a wall around a wildfire.",
								"pressure": {
									"integrity": 10,
									"wealth": 8,
									"public_attention": 10,
									"family_pressure": 6
								},
								"dynamic_node": true
							}
						]
					}
				}
			}
		}
	}

func set_contract(contract: Dictionary) -> Dictionary:
	if contract.is_empty():
		active_contract = _build_default_contract()
	else:
		active_contract = contract.duplicate(true)

	_ensure_catalog_story_pool()

	return {
		"schema": "eralife.choose_adventure_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}


func start_story(story_id: String = "") -> Dictionary:
	var state: Dictionary = _ensure_state()
	var clean_story_id: String = str(story_id).strip_edges()

	if clean_story_id == "" or clean_story_id == "adventure_catalog":
		return build_adventure_catalog_result()

	var story: Dictionary = _get_story(clean_story_id)
	if story.is_empty():
		return _error_result("Story '%s' was not found." % clean_story_id)

	var root_node_id: String = str(story.get("root_node", "")).strip_edges()
	var root_node: Dictionary = _get_node(clean_story_id, root_node_id)
	if root_node.is_empty():
		return _error_result("Root node '%s' was not found." % root_node_id)

	var pressure: Dictionary = {}
	for key in [
		"integrity",
		"corruption",
		"trauma",
		"wealth",
		"faction_tension",
		"family_pressure",
		"public_attention",
		"spiritual_weight",
		"supernatural_affinity",
		"relationship_gravity",
		"survival_pressure"
	]:
		pressure [key] = 0.0

	state ["active"] = true
	state ["catalog_open"] = false
	state ["cycle"] = 0
	state ["birth_ready"] = false
	state ["birth_mode"] = ""
	state ["current_story_id"] = clean_story_id
	state ["selected_adventure_id"] = clean_story_id
	state ["current_node_id"] = root_node_id
	state ["node_injections_this_cycle"] = 0
	state ["pressure"] = pressure
	state ["pressure_history"] = []
	state ["visited_nodes"] = []
	state.erase("pending_birth_choice")
	state.erase("pending_birth_node")

	if gs != null and gs.lineage_engine != null and gs.lineage_engine.has_method("begin_narrative_lineage"):
		var lineage: Dictionary = gs.lineage_engine.begin_narrative_lineage(story, state)
		state ["lineage_id"] = str(lineage.get("lineage_id", ""))
		state ["lineage_contract"] = lineage.duplicate(true)

	var registry_raw: Variant = state.get("node_registry", {})
	var registry: Dictionary = registry_raw.duplicate(true) if typeof(registry_raw) == TYPE_DICTIONARY else {}
	registry [root_node_id] = root_node.duplicate(true)
	state ["node_registry"] = registry

	var visited_raw: Variant = state.get("visited_nodes", [])
	var visited: Array = visited_raw.duplicate(true) if typeof(visited_raw) == TYPE_ARRAY else []
	if root_node_id not in visited:
		visited.append(root_node_id)
	state ["visited_nodes"] = visited

	var adventure_history_raw: Variant = state.get("adventure_history", [])
	var adventure_history: Array = adventure_history_raw.duplicate(true) if typeof(adventure_history_raw) == TYPE_ARRAY else []
	adventure_history.append({
		"story_id": clean_story_id,
		"title": str(story.get("title", clean_story_id)),
		"lineage_id": str(state.get("lineage_id", "")),
		"started_at_cycle": int(state.get("cycle", 0)),
		"started_at_ms": int(Time.get_ticks_msec())
	})
	state ["adventure_history"] = adventure_history
	state ["last_result"] = {}

	_write_state(state)

	_emit_event(ActionEventTypes.NARRATIVE_NODE_SURFACED, {
		"story_id": clean_story_id,
		"node_id": root_node_id,
		"lineage_id": str(state.get("lineage_id", "")),
		"dynamic": false
	})

	var result: Dictionary = build_current_panel_result()
	last_result = result.duplicate(true)
	return result

func choose(choice_id: String) -> Dictionary:
	var state: Dictionary = _ensure_state()
	var clean_choice_id: String = str(choice_id).strip_edges()

	if clean_choice_id == "":
		if bool(state.get("catalog_open", false)):
			return build_adventure_catalog_result()
		return build_current_panel_result()

	if clean_choice_id.begins_with("adventure:"):
		var catalog_story_id: String = clean_choice_id.replace("adventure:", "").strip_edges()
		return build_story_overview_result(catalog_story_id)

	if clean_choice_id.begins_with("start_story:"):
		var start_story_id: String = clean_choice_id.replace("start_story:", "").strip_edges()
		return start_story(start_story_id)

	if clean_choice_id == "open_adventure_catalog":
		return build_adventure_catalog_result()

	if clean_choice_id.begins_with("choose_birth_path:"):
		var birth_path_id: String = clean_choice_id.replace("choose_birth_path:", "").strip_edges().to_lower()
		var birth_mode: String = "lineage_birth"
		if birth_path_id in ["continue", "continue_as_anchor", "continue_as_them"]:
			birth_mode = "continue_as_anchor"

		var pending_choice_raw: Variant = state.get("pending_birth_choice", {})
		var pending_choice: Dictionary = pending_choice_raw.duplicate(true) if typeof(pending_choice_raw) == TYPE_DICTIONARY else {}
		var pending_node_raw: Variant = state.get("pending_birth_node", {})
		var pending_node: Dictionary = pending_node_raw.duplicate(true) if typeof(pending_node_raw) == TYPE_DICTIONARY else {}

		if pending_node.is_empty():
			pending_node = _current_node(state)
		if pending_choice.is_empty():
			pending_choice = {
				"id": clean_choice_id,
				"label": "Choose birth path",
				"text": "You decide how the story becomes playable."
			}

		state ["birth_ready"] = true
		state ["birth_mode"] = birth_mode
		_write_state(state)

		return _build_birth_trigger_result(state, pending_choice, pending_node, birth_mode)

	if not bool(state.get("active", false)):
		return build_adventure_catalog_result()

	var node: Dictionary = _current_node(state)
	if node.is_empty():
		return _error_result("The current narrative node is missing.")

	var choice: Dictionary = _find_choice(node, clean_choice_id)
	if choice.is_empty():
		return _error_result("Choice '%s' was not found." % clean_choice_id)

	var governor_report: Dictionary = _govern_choice(choice, node, state)
	var pressure_patch: Dictionary = governor_report.get("pressure", {}) if typeof(governor_report.get("pressure", {})) == TYPE_DICTIONARY else {}

	_apply_pressure(state, pressure_patch)

	state ["saturation"] = float(governor_report.get("saturation_after", state.get("saturation", 0.0)))
	state ["cycle"] = int(state.get("cycle", 0)) + 1

	var pressure_packet: Dictionary = _build_pressure_packet(choice, node, pressure_patch, state, governor_report)
	_inject_pressure_packet(pressure_packet)

	if gs != null and gs.lineage_engine != null and gs.lineage_engine.has_method("absorb_narrative_choice"):
		gs.lineage_engine.absorb_narrative_choice({
			"state": state.duplicate(true),
			"choice": choice.duplicate(true),
			"node": node.duplicate(true),
			"pressure": pressure_patch.duplicate(true),
			"story_id": str(state.get("current_story_id", "")),
			"generation": int(state.get("cycle", 0))
		})

	_emit_event(ActionEventTypes.NARRATIVE_CHOICE_MADE, {
		"choice_id": clean_choice_id,
		"node_id": str(node.get("id", "")),
		"story_id": str(state.get("current_story_id", "")),
		"pressure": pressure_patch.duplicate(true)
	})

	if bool(governor_report.get("birth_ready", false)):
		state ["birth_ready"] = true
		state ["pending_birth_choice"] = choice.duplicate(true)
		state ["pending_birth_node"] = node.duplicate(true)
		_write_state(state)

		return _build_birth_trigger_result(state, choice, node, "select_path")

	var generated_node: Dictionary = {}
	if bool(governor_report.get("allow_dynamic_node", false)) or bool(active_contract.get("rules", {}).get("every_choice_advances_node", true)):
		generated_node = _generate_dynamic_node(state, choice, node)

	if not generated_node.is_empty():
		var registry_raw: Variant = state.get("node_registry", {})
		var registry: Dictionary = registry_raw.duplicate(true) if typeof(registry_raw) == TYPE_DICTIONARY else {}
		var generated_node_id: String = str(generated_node.get("id", "")).strip_edges()

		if generated_node_id != "":
			registry [generated_node_id] = generated_node.duplicate(true)
			state ["node_registry"] = registry
			state ["current_node_id"] = generated_node_id
			state ["node_injections_this_cycle"] = int(state.get("node_injections_this_cycle", 0)) + 1

			var visited_raw: Variant = state.get("visited_nodes", [])
			var visited: Array = visited_raw.duplicate(true) if typeof(visited_raw) == TYPE_ARRAY else []
			visited.append(generated_node_id)
			state ["visited_nodes"] = visited

			_emit_event(ActionEventTypes.NARRATIVE_DYNAMIC_NODE_GENERATED, {
				"node_id": generated_node_id,
				"story_id": str(state.get("current_story_id", "")),
				"cycle": int(state.get("cycle", 0))
			})

	_write_state(state)

	var result: Dictionary = build_current_panel_result()
	last_result = result.duplicate(true)
	return result
func build_story_overview_result(story_id: String) -> Dictionary:
	_ensure_catalog_story_pool()

	var state: Dictionary = _ensure_state()
	var clean_story_id: String = str(story_id).strip_edges()
	var story: Dictionary = _get_story(clean_story_id)

	if story.is_empty():
		return _error_result("Story '%s' was not found." % clean_story_id)

	state ["active"] = false
	state ["catalog_open"] = false
	state ["birth_ready"] = false
	state ["birth_mode"] = ""
	state ["current_story_id"] = clean_story_id
	state ["selected_adventure_id"] = clean_story_id
	state ["current_node_id"] = ""
	state.erase("pending_birth_choice")
	state.erase("pending_birth_node")

	var overview_text: String = str(story.get("overview", "")).strip_edges()
	if overview_text == "":
		overview_text = "You feel a life waiting behind this doorway, but the story contract has not supplied its overview yet."

	var panel_text: String = "You pause at the edge of this story before it becomes a life.\n\nRead the pulse below. When you start, every choice you make becomes pressure the birth system can remember."

	var result:= {
		"type": "choose_adventure_story_overview",
		"display_kind": "story_overview",
		"panel_title": str(story.get("title", clean_story_id)),
		"subtitle": str(story.get("genre", "Lineage Adventure")),
		"text": panel_text,
		"overview": "",
		"opps": [
			{
				"choice_id": "start_story:%s" % clean_story_id,
				"label": "Start this story",
				"text": "Step inside and begin making choices.",
				"overview": overview_text,
				"display_kind": "story_start_card",
				"accent": str(story.get("accent", "#B56BFF")),
				"emoji": str(story.get("emoji", "✦"))
			},
			{
				"choice_id": "open_adventure_catalog",
				"label": "Return to the library",
				"text": "Back out and choose a different story contract.",
				"overview": "Nothing locks in until you begin the story.",
				"display_kind": "action_card",
				"accent": "#B56BFF",
				"emoji": "↩"
			}
		],
		"pressure": state.get("pressure", {}).duplicate(true) if typeof(state.get("pressure", {})) == TYPE_DICTIONARY else {},
		"saturation": float(state.get("saturation", 0.0)),
		"cycle": int(state.get("cycle", 0)),
		"footer_text": "Start Story → make choices → build pressure → choose birth path.",
		"node_id": "story_overview",
		"story_id": clean_story_id,
		"accent": str(story.get("accent", "#B56BFF")),
		"emoji": str(story.get("emoji", "✦")),
		"top_actions": [
			{
				"choice_id": "open_adventure_catalog",
				"label": "Library",
				"slot": "left",
				"role": "secondary"
			},
			{
				"choice_id": "start_story:%s" % clean_story_id,
				"label": "Start Story",
				"slot": "right",
				"role": "primary"
			}
		]
	}

	state ["last_result"] = result.duplicate(true)
	_write_state(state)
	return result
func build_current_panel_result() -> Dictionary:
	var state: Dictionary = _ensure_state()

	if bool(state.get("catalog_open", false)):
		return build_adventure_catalog_result()

	var node: Dictionary = _current_node(state)
	if node.is_empty():
		return _error_result("No active Choose Your Own Adventure node exists.")

	var pressure_raw: Variant = state.get("pressure", {})
	var pressure: Dictionary = pressure_raw.duplicate(true) if typeof(pressure_raw) == TYPE_DICTIONARY else {}

	var story_id: String = str(state.get("current_story_id", "")).strip_edges()
	var story: Dictionary = _get_story(story_id)
	var accent: String = str(story.get("accent", node.get("accent", "#B56BFF")))

	var choices_raw: Variant = node.get("choices", [])
	var choices: Array = choices_raw.duplicate(true) if typeof(choices_raw) == TYPE_ARRAY else []

	var opps: Array = []
	for raw_choice in choices:
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue

		var choice: Dictionary = raw_choice
		opps.append({
			"choice_id": str(choice.get("id", choice.get("choice_id", ""))),
			"label": str(choice.get("label", "Choose")),
			"text": str(choice.get("text", "")),
			"overview": str(choice.get("overview", choice.get("text", ""))),
			"display_kind": "action_card",
			"accent": str(choice.get("accent", accent)),
			"emoji": str(choice.get("emoji", story.get("emoji", "✦"))),
			"pressure_preview": choice.get("pressure", {}).duplicate(true) if typeof(choice.get("pressure", {})) == TYPE_DICTIONARY else {},
			"birth_candidate": bool(choice.get("birth_candidate", false))
		})

	if opps.is_empty():
		opps.append({
			"choice_id": "open_adventure_catalog",
			"label": "Return to the library",
			"text": "This story node has no available action contracts.",
			"overview": "The panel stays recoverable instead of trapping you in a dead node.",
			"display_kind": "action_card",
			"accent": accent,
			"emoji": "↩"
		})

	var node_text: String = str(node.get("text", "")).strip_edges()
	if node_text == "":
		node_text = "You feel the story waiting for a sharper choice."

	var result:= {
		"type": "choose_adventure_prompt",
		"display_kind": "story_node",
		"panel_title": str(node.get("panel_title", story.get("title", "Choose Your Own Adventure"))),
		"subtitle": str(node.get("subtitle", story.get("genre", "Narrative as Pressure Injection"))),
		"text": node_text,
		"overview": "",
		"opps": opps,
		"pressure": pressure,
		"saturation": float(state.get("saturation", 0.0)),
		"cycle": int(state.get("cycle", 0)),
		"footer_text": str(node.get("footer_text", "Your choice changes the pressure. The pressure changes the life.")),
		"node_id": str(node.get("id", "")),
		"story_id": story_id,
		"accent": accent,
		"emoji": str(story.get("emoji", "✦"))
	}

	state ["last_result"] = result.duplicate(true)
	_write_state(state)
	return result
func build_adventure_catalog_result() -> Dictionary:
	_ensure_catalog_story_pool()
	var state: Dictionary = _ensure_state()
	state ["active"] = false
	state ["catalog_open"] = true
	state ["current_story_id"] = ""
	state ["current_node_id"] = ""
	var catalog_raw: Variant = active_contract.get("catalog", {})
	var catalog: Dictionary = catalog_raw.duplicate(true) if typeof(catalog_raw) == TYPE_DICTIONARY else {}
	var opps: Array = []
	var stories_raw: Variant = active_contract.get("stories", {})
	var stories: Dictionary = stories_raw if typeof(stories_raw) == TYPE_DICTIONARY else {}
	var ordered_story_ids: Array = []
	var catalog_order_raw: Variant = active_contract.get("catalog_order", [])
	if typeof(catalog_order_raw) == TYPE_ARRAY:
		for raw_order_id in catalog_order_raw:
			var ordered_id: String = str(raw_order_id).strip_edges()
			if ordered_id != "" and ordered_id not in ordered_story_ids:
				ordered_story_ids.append(ordered_id)
	for raw_story_id in stories.keys():
		var story_id_from_key: String = str(raw_story_id).strip_edges()
		if story_id_from_key != "" and story_id_from_key not in ordered_story_ids:
			ordered_story_ids.append(story_id_from_key)
	for raw_story_id in ordered_story_ids:
		var story_id: String = str(raw_story_id).strip_edges()
		if story_id == "" or story_id == "adventure_catalog":
			continue
		var story_raw: Variant = stories.get(story_id, {})
		if typeof(story_raw) != TYPE_DICTIONARY:
			continue
		var story: Dictionary = story_raw
		var genre_text: String = str(story.get("genre", "Adventure")).strip_edges()
		var tagline: String = str(story.get("tagline", "")).strip_edges()
		var card_text: String = genre_text
		if tagline != "":
			card_text = "%s • %s" % [genre_text, tagline]
		opps.append({
			"choice_id": "adventure:%s" % story_id,
			"label": str(story.get("title", story_id)),
			"text": card_text,
			"overview": str(story.get("overview", "")),
			"display_kind": "adventure_card",
			"accent": str(story.get("accent", "#B56BFF")),
			"emoji": str(story.get("emoji", "✦")),
			"pressure_preview": {},
			"birth_candidate": false
		})
	var result:= {
		"type": "choose_adventure_catalog",
		"display_kind": "adventure_catalog",
		"panel_title": str(catalog.get("title", "Choose Your Own Adventure")),
		"subtitle": str(catalog.get("subtitle", "Pick the kind of life-pressure you want to step into.")),
		"text": str(catalog.get("text", "")),
		"opps": opps,
		"pressure": state.get("pressure", {}).duplicate(true) if typeof(state.get("pressure", {})) == TYPE_DICTIONARY else {},
		"saturation": float(state.get("saturation", 0.0)),
		"cycle": int(state.get("cycle", 0)),
		"footer_text": "Select an adventure. Every choice inside it becomes pressure the simulation can remember.",
		"node_id": "adventure_catalog",
		"story_id": "",
		"accent": "#B56BFF",
		"emoji": "📚",
		"top_actions": [
			{
				"choice_id": "__back_to_entry__",
				"label": "Back",
				"slot": "left",
				"role": "secondary"
			},
			{
				"choice_id": "__open_god_mode__",
				"label": "Nevermind, go to God mode",
				"slot": "right",
				"role": "god_mode"
			}
		]
	}
	state ["last_result"] = result.duplicate(true)
	_write_state(state)
	return result
func _ensure_catalog_story_pool() -> void:
	if active_contract.is_empty():
		active_contract = _build_default_contract()

	var stories_raw: Variant = active_contract.get("stories", {})
	var stories: Dictionary = stories_raw.duplicate(true) if typeof(stories_raw) == TYPE_DICTIONARY else {}

	var extensions: Dictionary = _build_catalog_story_extensions()
	var lineage_extensions: Dictionary = _build_lineage_adventure_story_extensions()
	for raw_lineage_story_id in lineage_extensions.keys():
		extensions [raw_lineage_story_id] = lineage_extensions [raw_lineage_story_id]
	for raw_story_id in extensions.keys():
		var story_id: String = str(raw_story_id).strip_edges()
		if story_id == "":
			continue
		if stories.has(story_id):
			continue
		var story_raw: Variant = extensions.get(raw_story_id, {})
		if typeof(story_raw) == TYPE_DICTIONARY:
			stories [story_id] = (story_raw as Dictionary).duplicate(true)

	active_contract ["stories"] = stories

	var catalog_order_raw: Variant = active_contract.get("catalog_order", [])
	var catalog_order: Array = catalog_order_raw.duplicate(true) if typeof(catalog_order_raw) == TYPE_ARRAY else []
	for raw_story_id in stories.keys():
		var story_id: String = str(raw_story_id).strip_edges()
		if story_id != "" and story_id not in catalog_order:
			catalog_order.append(story_id)
	active_contract ["catalog_order"] = catalog_order

	var catalog_raw: Variant = active_contract.get("catalog", {})
	var catalog: Dictionary = catalog_raw.duplicate(true) if typeof(catalog_raw) == TYPE_DICTIONARY else {}
	if str(catalog.get("title", "")).strip_edges() == "":
		catalog ["title"] = "Choose Your Own Adventure"
	if str(catalog.get("subtitle", "")).strip_edges() == "":
		catalog ["subtitle"] = "Pick the kind of life- YOU want to step into."
	if str(catalog.get("text", "")).strip_edges() == "":
		catalog ["text"] = "These are not endings. They are living story contracts.\n\nEach adventure lets you make choices before birth. Those choices push on the world — family, money, danger, faith, factions, love, survival, reputation — until the simulation becomes saturated enough to create a real life from what you shaped."
	active_contract ["catalog"] = catalog
func _build_lineage_adventure_story_extensions() -> Dictionary:
	return {
		"avatar_lineage_cycle": {
			"id": "avatar_lineage_cycle",
			"title": "The Avatar Before You",
			"genre": "Elemental Lineage",
			"accent": "#9FFFFF",
			"emoji": "🌪️",
			"tagline": "A past life bends the bloodline before birth.",
			"ancestor_name": "The Forgotten Avatar",
			"ancestor_role": "ancestor_avatar",
			"overview": "You do not begin as the baby.\n\nYou begin as someone before them — a figure carrying the Avatar cycle through fear, duty, family pressure, and spiritual expectation.\n\nEvery choice stores supernatural affinity, family memory, public attention, and faction tension. When the story saturates, you are born into the family that inherited the consequences.",
			"root_node": "avatar_cycle_root",
			"nodes": {
				"avatar_cycle_root": {
					"id": "avatar_cycle_root",
					"panel_title": "The Avatar Before You",
					"subtitle": "The four elements are already arguing over the bloodline.",
					"text": "A child in your family shows signs no one can explain.\n\nThe wind answers when they cry. Fire bends away from their hands. Water settles when they enter the room. The earth feels awake under their feet.\n\nThe family can hide it, exploit it, or prepare them.",
					"choices": [
						{
							"id": "avatar_hide_child",
							"label": "Hide the child from the world",
							"text": "Protect the bloodline through secrecy.",
							"pressure": {
								"integrity": 8,
								"trauma": 8,
								"supernatural_affinity": 18,
								"faction_tension": -4
							},
							"dynamic_node": true
						},
						{
							"id": "avatar_train_child",
							"label": "Train them before the world finds out",
							"text": "Turn fear into discipline.",
							"pressure": {
								"integrity": 14,
								"family_pressure": 8,
								"supernatural_affinity": 26,
								"public_attention": 4
							},
							"dynamic_node": true
						},
						{
							"id": "avatar_sell_secret",
							"label": "Let powerful people know",
							"text": "Trade destiny for protection and wealth.",
							"pressure": {
								"corruption": 14,
								"wealth": 18,
								"supernatural_affinity": 22,
								"faction_tension": 16
							},
							"dynamic_node": true
						}
					]
				}
			}
		},
		"fire_bending_heir": {
			"id": "fire_bending_heir",
			"title": "The Firebender in the Family",
			"genre": "Elemental Family Drama",
			"accent": "#FF6A3D",
			"emoji": "🔥",
			"tagline": "A family flame becomes inheritance.",
			"ancestor_name": "The First Flame",
			"ancestor_role": "firebending_ancestor",
			"overview": "Before you are born, someone in your family is the first person to firebend openly.\n\nTheir choice can make the family respected, feared, hunted, wealthy, exiled, or spiritually marked.\n\nWhen the story saturates, you are born into the family carrying that flame.",
			"root_node": "fire_heir_root",
			"nodes": {
				"fire_heir_root": {
					"id": "fire_heir_root",
					"panel_title": "The Firebender in the Family",
					"subtitle": "The first flame decides what kind of family survives it.",
					"text": "The kitchen catches fire without burning.\n\nA teenager in your family stares at their hands while orange light curls around their fingers. Their parent sees it. Their sibling sees it. The neighbors might have seen it too.\n\nOne family decision can change generations.",
					"choices": [
						{
							"id": "fire_teach_control",
							"label": "Teach control before pride",
							"text": "The flame becomes discipline.",
							"pressure": {
								"integrity": 12,
								"supernatural_affinity": 20,
								"family_pressure": 8
							},
							"dynamic_node": true
						},
						{
							"id": "fire_use_for_status",
							"label": "Use the gift to gain status",
							"text": "The flame becomes reputation.",
							"pressure": {
								"wealth": 12,
								"public_attention": 14,
								"corruption": 5,
								"supernatural_affinity": 20
							},
							"dynamic_node": true
						},
						{
							"id": "fire_answer_fear_with_fire",
							"label": "Answer fear with fire",
							"text": "The flame becomes a warning.",
							"pressure": {
								"trauma": 12,
								"corruption": 10,
								"faction_tension": 12,
								"supernatural_affinity": 22
							},
							"dynamic_node": true
						}
					]
				}
			}
		}
	}
func _build_catalog_story_extensions() -> Dictionary:
	return {
		"bluford_first_day": _build_story_contract(
			"bluford_first_day",
			"First Day at Bluford",
			"School Drama",
			"#5DA8FF",
			"🏫",
			"Reputation starts before the bell rings.",
			"You arrive at Bluford High with new shoes, old rumors, and a schedule that already feels like a warning.\n\nSomebody knows your cousin. Somebody heard about a fight you never had. Somebody at lunch is saving you a seat, but you do not know yet whether it is kindness or a setup.\n\nYour choices decide whether this future life is born quiet, popular, feared, protected, underestimated, or already carrying hallway pressure.",
			"First Day at Bluford",
			"The hallway decides who it thinks you are.",
			"The front doors open into noise: lockers slamming, sneakers squeaking, somebody laughing too loud near the trophy case.\n\nA group by the stairs watches you like they already voted on your future. At the same time, a lonely student drops their books and nobody moves to help.\n\nThe bell has not rung yet, but your story has.",
			[
				{
					"id": "bluford_help_student",
					"label": "Help the student with their books",
					"text": "Choose kindness before status.",
					"pressure": { "integrity": 14, "public_attention": 5, "family_pressure": 2},
					"dynamic_node": true
				},
				{
					"id": "bluford_join_loud_group",
					"label": "Walk toward the loud group",
					"text": "Step directly into the social storm.",
					"pressure": { "public_attention": 14, "faction_tension": 8, "corruption": 2},
					"dynamic_node": true
				},
				{
					"id": "bluford_keep_head_down",
					"label": "Keep your head down and find class",
					"text": "Survive the first day by staying invisible.",
					"pressure": { "trauma": 4, "public_attention": -6, "integrity": 2},
					"dynamic_node": true
				}
			]
		),
		"boxing_after_school": _build_story_contract(
			"boxing_after_school",
			"After-School Hands",
			"Boxing Coming-of-Age",
			"#FF8A3D",
			"🥊",
			"Discipline and anger share the same gloves.",
			"The gym behind the community center smells like old mats, sweat, and second chances.\n\nA trainer says you have fast hands but heavy eyes. A rival from school says boxing will not save you from what waits outside. Your family says fighting is dangerous, but bills, pride, and fear already know where you live.\n\nYour choices decide whether this future life is born disciplined, violent, famous, humble, reckless, or impossible to intimidate.",
			"After-School Hands",
			"Every punch asks what you are really fighting.",
			"The speed bag snaps back and forth while rain taps the gym windows.\n\nYour trainer tells you to go home. Then someone from school walks in with two friends and a grin that does not belong in a boxing gym.\n\nThey say they just came to watch. Nobody believes them.",
			[
				{
					"id": "boxing_ignore_rival",
					"label": "Ignore them and keep training",
					"text": "Let discipline speak louder than pride.",
					"pressure": { "integrity": 12, "trauma": 3, "public_attention": -2},
					"dynamic_node": true
				},
				{
					"id": "boxing_call_them_out",
					"label": "Call them out in front of everyone",
					"text": "Turn the gym into a stage.",
					"pressure": { "public_attention": 16, "faction_tension": 10, "corruption": 3},
					"dynamic_node": true
				},
				{
					"id": "boxing_ask_trainer",
					"label": "Ask the trainer to handle it",
					"text": "Choose structure over ego.",
					"pressure": { "integrity": 9, "family_pressure": 4, "public_attention": -4},
					"dynamic_node": true
				}
			]
		),
		"cafeteria_trial": _build_story_contract(
			"cafeteria_trial",
			"The Cafeteria Trial",
			"Social Pressure Mystery",
			"#FFD166",
			"🍽",
			"The lunch table can become a courtroom.",
			"One spilled tray turns into a rumor. One rumor turns into a crowd. One crowd turns into a verdict before any adult knows what happened.\n\nSomebody is lying. Somebody is scared. Somebody is about to lose every friend they thought they had.\n\nYour choices decide whether this future life is born loyal, suspicious, socially brilliant, publicly humiliated, or dangerously good at reading people.",
			"The Cafeteria Trial",
			"Everybody saw something. Nobody saw the same thing.",
			"A tray crashes near the vending machines. Milk spreads across the floor. A phone is already recording.\n\nA student points at someone who looks too shocked to defend themselves. The cafeteria gets quiet in the way it only gets quiet before cruelty becomes entertainment.",
			[
				{
					"id": "cafeteria_defend_accused",
					"label": "Defend the accused student",
					"text": "Stand up before the crowd finishes deciding.",
					"pressure": { "integrity": 15, "public_attention": 12, "faction_tension": 5},
					"dynamic_node": true
				},
				{
					"id": "cafeteria_find_video",
					"label": "Find the person with the video",
					"text": "Search for proof before choosing a side.",
					"pressure": { "integrity": 7, "public_attention": 8, "spiritual_weight": 2},
					"dynamic_node": true
				},
				{
					"id": "cafeteria_walk_away",
					"label": "Walk away before it becomes your problem",
					"text": "Protect your peace by abandoning the moment.",
					"pressure": { "corruption": 5, "trauma": 6, "public_attention": -5},
					"dynamic_node": true
				}
			]
		),
		"choir_room_secret": _build_story_contract(
			"choir_room_secret",
			"The Choir Room Secret",
			"Faith and Family Drama",
			"#B56BFF",
			"🎹",
			"Some prayers echo through locked doors.",
			"After school, the choir room is supposed to be empty. Instead, someone is crying behind the piano with a secret that could split a family, expose a teacher, or save a life.\n\nThe school wants order. The church wants appearances. The truth wants a witness.\n\nYour choices decide whether this future life is born spiritually sensitive, burdened, brave, distrustful, merciful, or known as the person people confess to.",
			"The Choir Room Secret",
			"The truth is hiding behind a hymn.",
			"You hear someone crying behind the piano bench.\n\nWhen you step closer, they whisper your name even though you have never spoken to them before. In their hand is a folded note with a phone number, a Bible verse, and a warning: DO NOT TELL THE OFFICE.",
			[
				{
					"id": "choir_listen_quietly",
					"label": "Sit down and listen quietly",
					"text": "Become safe before becoming useful.",
					"pressure": { "integrity": 12, "spiritual_weight": 14, "trauma": 4},
					"dynamic_node": true
				},
				{
					"id": "choir_take_note_office",
					"label": "Take the note to the office",
					"text": "Trust the institution with the secret.",
					"pressure": { "integrity": 8, "public_attention": 7, "faction_tension": 6},
					"dynamic_node": true
				},
				{
					"id": "choir_call_number",
					"label": "Call the number yourself",
					"text": "Step outside the rules to chase the truth.",
					"pressure": { "faction_tension": 10, "spiritual_weight": 10, "corruption": 2},
					"dynamic_node": true
				}
			]
		)
	}
func _build_story_contract(
	story_id: String,
	title: String,
	genre: String,
	accent: String,
	emoji: String,
	tagline: String,
	overview: String,
	panel_title: String,
	subtitle: String,
	text: String,
	choices: Array
) -> Dictionary:
	var clean_story_id: String = str(story_id).strip_edges()
	var root_node_id: String = "%s_root" % clean_story_id

	return {
		"id": clean_story_id,
		"title": title,
		"genre": genre,
		"accent": accent,
		"emoji": emoji,
		"tagline": tagline,
		"overview": overview,
		"root_node": root_node_id,
		"nodes": {
			root_node_id: {
				"id": root_node_id,
				"panel_title": panel_title,
				"subtitle": subtitle,
				"text": text,
				"choices": choices
			}
		}
	}


func export_state() -> Dictionary:
	var state: Dictionary = _ensure_state()
	return {
		"schema": "eralife.choose_adventure_state",
		"version": CONTRACT_VERSION,
		"data": state.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	var row_raw: Variant = data.get("data", data)
	var row: Dictionary = row_raw.duplicate(true) if typeof(row_raw) == TYPE_DICTIONARY else {}
	if row.is_empty():
		return {
			"success": false,
			"reason": "Choose Adventure state import was empty."
		}

	_write_state(row)
	return {
		"success": true,
		"schema": "eralife.choose_adventure_state_import_report",
		"version": CONTRACT_VERSION,
		"imported_at_ms": int(Time.get_ticks_msec())
	}


func _get_story(story_id: String) -> Dictionary:
	var stories_raw: Variant = active_contract.get("stories", {})
	var stories: Dictionary = stories_raw if typeof(stories_raw) == TYPE_DICTIONARY else {}
	var story_raw: Variant = stories.get(story_id, {})
	return story_raw.duplicate(true) if typeof(story_raw) == TYPE_DICTIONARY else {}


func _get_node(story_id: String, node_id: String) -> Dictionary:
	var story: Dictionary = _get_story(story_id)
	var nodes_raw: Variant = story.get("nodes", {})
	var nodes: Dictionary = nodes_raw if typeof(nodes_raw) == TYPE_DICTIONARY else {}
	var node_raw: Variant = nodes.get(node_id, {})
	return node_raw.duplicate(true) if typeof(node_raw) == TYPE_DICTIONARY else {}


func _current_node(state: Dictionary) -> Dictionary:
	var registry_raw: Variant = state.get("node_registry", {})
	var registry: Dictionary = registry_raw if typeof(registry_raw) == TYPE_DICTIONARY else {}
	var node_id: String = str(state.get("current_node_id", "")).strip_edges()

	if registry.has(node_id):
		var node_raw: Variant = registry.get(node_id, {})
		return node_raw.duplicate(true) if typeof(node_raw) == TYPE_DICTIONARY else {}

	var story_id: String = str(state.get("current_story_id", "")).strip_edges()
	return _get_node(story_id, node_id)


func _find_choice(node: Dictionary, choice_id: String) -> Dictionary:
	var choices_raw: Variant = node.get("choices", [])
	var choices: Array = choices_raw if typeof(choices_raw) == TYPE_ARRAY else []

	for raw_choice in choices:
		if typeof(raw_choice) != TYPE_DICTIONARY:
			continue

		var choice: Dictionary = raw_choice
		var id: String = str(choice.get("id", choice.get("choice_id", ""))).strip_edges()
		if id == choice_id:
			return choice.duplicate(true)

	return {}


func _govern_choice(choice: Dictionary, node: Dictionary, state: Dictionary) -> Dictionary:
	if gs != null and gs.narrative_governor != null and gs.narrative_governor.has_method("govern_choice"):
		return gs.narrative_governor.govern_choice(choice, node, state)

	var fallback_governor:= NarrativeGovernor.new(gs)
	return fallback_governor.govern_choice(choice, node, state)


func _apply_pressure(state: Dictionary, pressure_patch: Dictionary) -> void:
	var pressure_raw: Variant = state.get("pressure", {})
	var pressure: Dictionary = pressure_raw.duplicate(true) if typeof(pressure_raw) == TYPE_DICTIONARY else {}

	for raw_key in pressure_patch.keys():
		var key: String = str(raw_key).strip_edges()
		if key == "":
			continue

		var current: float = float(pressure.get(key, 0.0))
		pressure [key] = current + float(pressure_patch.get(raw_key, 0.0))

	state ["pressure"] = pressure

	var history_raw: Variant = state.get("pressure_history", [])
	var history: Array = history_raw.duplicate(true) if typeof(history_raw) == TYPE_ARRAY else []
	history.append({
		"cycle": int(state.get("cycle", 0)),
		"pressure": pressure_patch.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	})
	state ["pressure_history"] = history


func _build_pressure_packet(choice: Dictionary, node: Dictionary, pressure_patch: Dictionary, state: Dictionary, governor_report: Dictionary) -> Dictionary:
	return {
		"schema": "eralife.narrative_pressure_packet",
		"version": CONTRACT_VERSION,
		"packet_id": "np_%s_%d" % [str(choice.get("id", "choice")), int(Time.get_ticks_msec())],
		"source": "choose_adventure_scenario_engine",
		"intent": "narrative_pressure_injection",
		"choice_id": str(choice.get("id", "")),
		"node_id": str(node.get("id", "")),
		"story_id": str(state.get("current_story_id", "")),
		"cycle": int(state.get("cycle", 0)),
		"pressure": pressure_patch.duplicate(true),
		"saturation": float(state.get("saturation", 0.0)),
		"governor_report": governor_report.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _inject_pressure_packet(packet: Dictionary) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var packets_raw: Variant = gs.scenario_state.get("narrative_pressure_packets", [])
		var packets: Array = packets_raw.duplicate(true) if typeof(packets_raw) == TYPE_ARRAY else []
		packets.append(packet.duplicate(true))
		gs.scenario_state ["narrative_pressure_packets"] = packets

	_emit_event(ActionEventTypes.NARRATIVE_PRESSURE_INJECTED, packet)

	var sinks: Array = [
		gs.universal_faction_engine,
		gs.realm_engine,
		gs.royalty_engine,
		gs.politics_engine,
		gs.simulation_director,
		gs.simulation_contract_engine
	]

	var methods: Array = [
		"inject_narrative_pressure",
		"receive_intent_packet",
		"apply_pressure_packet",
		"apply_narrative_pressure"
	]

	for sink in sinks:
		if sink == null:
			continue

		for method_name in methods:
			if sink.has_method(method_name):
				sink.call(method_name, packet)
				break


func _generate_dynamic_node(state: Dictionary, choice: Dictionary, node: Dictionary) -> Dictionary:
	if gs != null and gs.choose_adventure_ai_node_generator != null and gs.choose_adventure_ai_node_generator.has_method("generate_node"):
		return gs.choose_adventure_ai_node_generator.generate_node({
			"state": state.duplicate(true),
			"choice": choice.duplicate(true),
			"node": node.duplicate(true),
			"contract": active_contract.duplicate(true)
		})

	var generator:= ChooseAdventureAINodeGenerator.new(gs)
	return generator.generate_node({
		"state": state.duplicate(true),
		"choice": choice.duplicate(true),
		"node": node.duplicate(true),
		"contract": active_contract.duplicate(true)
	})


func _build_birth_trigger_result(state: Dictionary, choice: Dictionary, node: Dictionary, birth_mode: String = "select_path") -> Dictionary:
	var clean_birth_mode: String = str(birth_mode).strip_edges().to_lower()
	if clean_birth_mode == "":
		clean_birth_mode = "select_path"

	var pressure_raw: Variant = state.get("pressure", {})
	var pressure: Dictionary = pressure_raw.duplicate(true) if typeof(pressure_raw) == TYPE_DICTIONARY else {}

	if clean_birth_mode == "select_path":
		var path_bias: Dictionary = _build_birth_bias(state, "select_path")
		var path_result:= {
			"type": "choose_adventure_birth_path_selection",
			"display_kind": "story_node",
			"birth_now": false,
			"birth_ready": true,
			"panel_title": "The Story Is Ready To Become A Life",
			"subtitle": "You decide how the pressure enters reality.",
			"text": "The story has enough weight now.\n\nYou can let it become family history and be born into the bloodline shaped by your choices.\n\nOr you can stop standing outside the moment and continue as the person whose life you have been steering.",
			"overview": "",
			"opps": [
				{
					"choice_id": "choose_birth_path:family",
					"label": "Be born into their family",
					"text": "Let this become ancestry, household memory, birth class, family pressure, and inherited consequence.",
					"overview": "Your accumulated pressure becomes a lineage birth contract. The family you enter is shaped by the choices you made before birth.",
					"display_kind": "birth_path_card",
					"accent": "#B56BFF",
					"emoji": "🩸"
				},
				{
					"choice_id": "choose_birth_path:continue",
					"label": "Continue as them",
					"text": "Keep the hands already on the door and begin life at their age.",
					"overview": "Your accumulated pressure becomes an adult-start contract. You begin with family generated around you and a relationship-potential seed instead of a newborn shell.",
					"display_kind": "birth_path_card",
					"accent": "#7CFF9B",
					"emoji": "🫀"
				}
			],
			"pressure": pressure,
			"saturation": float(state.get("saturation", 0.0)),
			"birth_bias": path_bias,
			"choice_id": str(choice.get("id", "")),
			"node_id": str(node.get("id", "")),
			"story_id": str(state.get("current_story_id", "")),
			"lineage_id": str(state.get("lineage_id", "")),
			"footer_text": "No forced ending. Your accumulated pressure decides the birth contract."
		}

		state ["last_result"] = path_result.duplicate(true)
		_write_state(state)
		last_result = path_result.duplicate(true)
		return path_result

	var birth_bias: Dictionary = _build_birth_bias(state, clean_birth_mode)

	var lineage_contract_raw: Variant = birth_bias.get("lineage_birth_contract", {})
	var lineage_contract: Dictionary = lineage_contract_raw.duplicate(true) if typeof(lineage_contract_raw) == TYPE_DICTIONARY else {}

	var continuation_raw: Variant = birth_bias.get("continuation_contract", {})
	var continuation_contract: Dictionary = continuation_raw.duplicate(true) if typeof(continuation_raw) == TYPE_DICTIONARY else {}

	var final_text: String = "You choose the bloodline route.\n\nThe pressure folds into ancestry. Your choices stop being options and become household memory, class tension, reputation, risk, and inheritance.\n\nYou are being born into the family your story shaped."
	if clean_birth_mode == "continue_as_anchor":
		final_text = "You choose to continue as them.\n\nThe story does not collapse into infancy. It becomes an already-moving life with family around you, an age already lived into, and relationship potential waiting to resolve inside the world.\n\nYou are not being born from the story.\n\nYou are stepping into the person the story created."

	var result:= {
		"type": "choose_adventure_birth_trigger",
		"display_kind": "birth_trigger",
		"birth_now": true,
		"birth_mode": clean_birth_mode,
		"panel_title": "Narrative Saturation",
		"subtitle": "The story becomes playable reality.",
		"text": final_text,
		"overview": "",
		"opps": [],
		"pressure": pressure,
		"saturation": float(state.get("saturation", 0.0)),
		"birth_bias": birth_bias,
		"lineage_birth_contract": lineage_contract.duplicate(true),
		"continuation_contract": continuation_contract.duplicate(true),
		"choice_id": str(choice.get("id", "")),
		"node_id": str(node.get("id", "")),
		"story_id": str(state.get("current_story_id", "")),
		"lineage_id": str(state.get("lineage_id", "")),
		"footer_text": "Narrative pressure → birth mode → playable life contract."
	}

	_emit_event(ActionEventTypes.NARRATIVE_BIRTH_TRIGGERED, result)

	last_result = result.duplicate(true)
	return result


func _build_birth_bias(state: Dictionary, birth_mode: String = "lineage_birth") -> Dictionary:
	var clean_birth_mode: String = str(birth_mode).strip_edges().to_lower()
	if clean_birth_mode == "" or clean_birth_mode == "select_path":
		clean_birth_mode = "lineage_birth"

	var pressure_raw: Variant = state.get("pressure", {})
	var pressure: Dictionary = pressure_raw.duplicate(true) if typeof(pressure_raw) == TYPE_DICTIONARY else {}

	var pressure_history_raw: Variant = state.get("pressure_history", [])
	var pressure_history: Array = pressure_history_raw.duplicate(true) if typeof(pressure_history_raw) == TYPE_ARRAY else []

	var adventure_history_raw: Variant = state.get("adventure_history", [])
	var adventure_history: Array = adventure_history_raw.duplicate(true) if typeof(adventure_history_raw) == TYPE_ARRAY else []

	var integrity: float = float(pressure.get("integrity", 0.0))
	var corruption: float = float(pressure.get("corruption", 0.0))
	var trauma: float = float(pressure.get("trauma", 0.0))
	var wealth: float = float(pressure.get("wealth", 0.0))
	var faction_tension: float = float(pressure.get("faction_tension", 0.0))
	var family_pressure: float = float(pressure.get("family_pressure", 0.0))
	var public_attention: float = float(pressure.get("public_attention", 0.0))
	var spiritual_weight: float = float(pressure.get("spiritual_weight", 0.0))
	var supernatural_affinity: float = float(pressure.get("supernatural_affinity", 0.0))
	var relationship_gravity: float = float(pressure.get("relationship_gravity", 0.0))
	var survival_pressure: float = float(pressure.get("survival_pressure", 0.0))

	var social_class: String = "Random / Era Default"
	if wealth >= 40.0 and corruption < 40.0:
		social_class = "Upper"
	elif wealth >= 40.0 and corruption >= 40.0:
		social_class = "Noble"
	elif trauma >= 45.0 and wealth < 25.0:
		social_class = "Poor"

	var cycle: int = int(state.get("cycle", 0))
	var continuation_age: int = int(clamp(
		16 + cycle + int(max(0.0, public_attention) / 18.0) + int(max(0.0, wealth) / 24.0) + int(max(0.0, survival_pressure) / 20.0),
		16,
		72
	))

	var partnership_chance: float = clamp(
		0.2 + (max(0.0, integrity) / 260.0) + (max(0.0, relationship_gravity) / 180.0) + (max(0.0, public_attention) / 320.0) - (max(0.0, trauma) / 360.0),
		0.05,
		0.85
	)

	var family_birth_contract:= {
		"schema": "eralife.choose_adventure_family_birth_contract",
		"version": CONTRACT_VERSION,
		"birth_mode": "lineage_birth",
		"story_id": str(state.get("current_story_id", "")),
		"lineage_id": str(state.get("lineage_id", "")),
		"birth_conditions": {
			"social_class": social_class,
			"starting_money": int(max(0.0, wealth) * 125.0),
			"family_pressure_seed": family_pressure,
			"trauma_seed": trauma,
			"spiritual_weight_seed": spiritual_weight,
			"supernatural_affinity_seed": supernatural_affinity,
			"public_attention_seed": public_attention
		}
	}

	var continuation_contract:= {
		"schema": "eralife.choose_adventure_continuation_contract",
		"version": CONTRACT_VERSION,
		"birth_mode": "continue_as_anchor",
		"story_id": str(state.get("current_story_id", "")),
		"lineage_id": str(state.get("lineage_id", "")),
		"starting_age": continuation_age,
		"generate_family": true,
		"relationship_potential": {
			"chance": partnership_chance,
			"relationship_gravity": relationship_gravity,
			"public_attention": public_attention,
			"trauma": trauma,
			"integrity": integrity
		},
		"adult_start_memory": {
			"pressure_history_size": pressure_history.size(),
			"dominant_moral_seed": integrity - corruption,
			"dominant_risk_seed": trauma + faction_tension + survival_pressure
		}
	}

	var base_bias:= {
		"source": "choose_adventure_birth_trigger",
		"birth_mode": clean_birth_mode,
		"social_class": social_class,
		"starting_money": int(max(0.0, wealth) * 125.0),
		"starting_age": 0 if clean_birth_mode == "lineage_birth" else continuation_age,
		"world_pressure": {
			"integrity": integrity,
			"corruption": corruption,
			"trauma": trauma,
			"wealth": wealth,
			"faction_tension": faction_tension,
			"family_pressure": family_pressure,
			"public_attention": public_attention,
			"spiritual_weight": spiritual_weight,
			"supernatural_affinity": supernatural_affinity,
			"relationship_gravity": relationship_gravity,
			"survival_pressure": survival_pressure
		},
		"choice_pressure_count": pressure_history.size(),
		"pressure_history": pressure_history.duplicate(true),
		"adventure_history": adventure_history.duplicate(true),
		"faction_pressure_seed": faction_tension,
		"family_trauma_seed": trauma,
		"moral_alignment_seed": integrity - corruption,
		"family_birth_contract": family_birth_contract.duplicate(true),
		"continuation_contract": continuation_contract.duplicate(true),
		"lineage_birth_contract": family_birth_contract.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	if gs != null and gs.lineage_engine != null and gs.lineage_engine.has_method("build_birth_bias_from_reservoir"):
		var resolved_bias: Dictionary = gs.lineage_engine.build_birth_bias_from_reservoir(state, base_bias)
		if not resolved_bias.has("birth_mode"):
			resolved_bias ["birth_mode"] = clean_birth_mode
		if not resolved_bias.has("family_birth_contract"):
			resolved_bias ["family_birth_contract"] = family_birth_contract.duplicate(true)
		if not resolved_bias.has("continuation_contract"):
			resolved_bias ["continuation_contract"] = continuation_contract.duplicate(true)
		if not resolved_bias.has("pressure_history"):
			resolved_bias ["pressure_history"] = pressure_history.duplicate(true)
		if not resolved_bias.has("choice_pressure_count"):
			resolved_bias ["choice_pressure_count"] = pressure_history.size()
		if not resolved_bias.has("starting_age"):
			resolved_bias ["starting_age"] = 0 if clean_birth_mode == "lineage_birth" else continuation_age
		return resolved_bias

	return base_bias
func _emit_event(event_type: String, payload: Dictionary) -> void:
	if gs == null:
		return

	if gs.event_bus != null and gs.event_bus.has_method("emit"):
		gs.event_bus.emit(event_type, payload)
	elif gs.event_bus != null and gs.event_bus.has_method("publish"):
		gs.event_bus.publish(event_type, payload)


func _error_result(message: String) -> Dictionary:
	return {
		"type": "choose_adventure_error",
		"panel_title": "Choose Your Own Adventure",
		"subtitle": "Narrative route unavailable",
		"text": message,
		"opps": [],
		"footer_text": "The engine could not resolve the requested narrative node."
	}