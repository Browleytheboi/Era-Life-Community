extends Resource
class_name NarrativeEngine

var gs

const NARRATIVE_CONTRACT_VERSION:= 1
const NARRATIVE_CONTRACT_SCHEMA:= "eralife.narrative_contract"
const NARRATIVE_MEMORY_SCHEMA:= "eralife.narrative_memory_packet"
const MAX_NARRATIVE_REPORTS:= 120

var last_narrative_contract: Dictionary = {}
var narrative_reports: Array = []

func _init(_gs):
	gs = _gs





func _name(person: Person) -> String:
	return "%s %s" % [person.first_name, person.last_name]

func _pronoun(person: Person) -> String:
	return "he" if person.gender == "Male" else "she"

func _obj_pronoun(person: Person) -> String:
	return "him" if person.gender == "Male" else "her"

func _poss_pronoun(person: Person) -> String:
	return "his" if person.gender == "Male" else "her"





func log_event(person_or_payload, raw_event: Dictionary = {}):
	var resolved: Dictionary = _resolve_narrative_event_person(person_or_payload, raw_event)
	var person: Person = resolved.get("person", null)
	var event_payload: Dictionary = resolved.get("payload", {})

	if person == null:
		return {}

	if gs == null:
		return {}

	if not event_payload.has("type"):
		event_payload ["type"] = str(event_payload.get("event_name", "text"))

	if not event_payload.has("event_name") and event_payload.has("type"):
		event_payload ["event_name"] = event_payload ["type"]
	if not event_payload.has("year"):
		event_payload ["year"] = int(gs.year)
	if not event_payload.has("era"):
		event_payload ["era"] = gs.era.name if gs.era != null else ""
	if not event_payload.has("source"):
		event_payload ["source"] = "narrative_engine"
	if not event_payload.has("npc_id"):
		event_payload ["npc_id"] = int(person.id)

	var is_player: bool = gs.player != null and int(person.id) == int(gs.player.id)
	var narrative_contract: Dictionary = _build_narrative_contract(person, event_payload, is_player)
	narrative_contract = _resolve_narrative_contract_through_consciousness(person, narrative_contract)

	var text: String = _render_contract_text(person, narrative_contract, is_player)

	if gs.llm_bridge != null and text.length() > 3 and not bool(event_payload.get("skip_llm_enhancement", false)):
		text = gs.llm_bridge.enhance(text, person, event_payload)

	narrative_contract ["rendered_text"] = text
	narrative_contract ["memory_packet"] = _build_narrative_memory_packet(person, narrative_contract, text)

	_commit_narrative_memory(person, narrative_contract, text)
	_apply_narrative_relationship_delta(person, narrative_contract)
	_emit_world_feed_from_narrative_contract(person, narrative_contract, text)

	if not bool(event_payload.get("skip_relationship_hooks", false)):
		_apply_relationship_memory_hooks(person, narrative_contract, text)

	_commit_narrative_report(narrative_contract)

	return {
		"success": true,
		"schema": "eralife.narrative_log_report",
		"version": NARRATIVE_CONTRACT_VERSION,
		"person_id": int(person.id),
		"text": text,
		"contract": narrative_contract.duplicate(true)
	}






func _render_event_text(person: Person, raw_event: Dictionary, is_player: bool) -> String:
	var forced_first_person: bool = bool(raw_event.get("force_first_person_memory", false))
	var life_diary_text: String = str(raw_event.get("life_diary_text", "")).strip_edges()
	if forced_first_person and life_diary_text != "":
		return life_diary_text

	var event_type:= str(raw_event.get("type", "text"))

	match event_type:
		"age":
			if is_player or forced_first_person:
				return "I turned %d." % person.age
			return "%s turned %d." % [_name(person), person.age]

		"illness_minor":
			if is_player or forced_first_person:
				return "At %d, I caught a minor illness." % person.age
			return "At %d, %s caught a minor illness." % [person.age, _name(person)]

		"illness_major":
			if is_player or forced_first_person:
				return "At %d, I was diagnosed with a serious illness." % person.age
			return "At %d, %s was diagnosed with a serious illness." % [person.age, _name(person)]

		"injury":
			if is_player or forced_first_person:
				return "At %d, I suffered an injury." % person.age
			return "At %d, %s suffered an injury." % [person.age, _name(person)]

		"job_start":
			var job_name: String = str(raw_event.get("job", person.job)).strip_edges()
			if job_name == "":
				job_name = "worker"
			if is_player or forced_first_person:
				return "At %d, I started working as a %s." % [person.age, job_name]
			return "At %d, %s started working as a %s." % [person.age, _name(person), job_name]

		"job_raise":
			if is_player or forced_first_person:
				return "At %d, I received a raise." % person.age
			return "At %d, %s received a raise." % [person.age, _name(person)]

		"job_demotion":
			if is_player or forced_first_person:
				return "At %d, I was demoted at work." % person.age
			return "At %d, %s was demoted at work." % [person.age, _name(person)]

		"job_quit":
			var job_name = raw_event.get("job", person.job)
			if is_player or forced_first_person:
				return "At %d, I quit my job as a %s." % [person.age, job_name]
			return "At %d, %s quit %s job as a %s." % [
				person.age,
				_name(person),
				_poss_pronoun(person),
				job_name
			]

		"job_switch":
			if is_player or forced_first_person:
				return "At %d, I switched careers." % person.age
			return "At %d, %s switched careers." % [person.age, _name(person)]

		"death":
			var cause: String = str(raw_event.get("cause", person.cause_of_death)).strip_edges()
			if cause == "":
				cause = "unknown causes"
			if is_player or forced_first_person:
				return "I died from %s at age %d." % [cause, int(person.age)]
			return "%s died from %s at age %d." % [_name(person), cause, int(person.age)]

		_:
			return _render_text_event(person, raw_event, is_player)









func _render_text_event(person: Person, raw_event: Dictionary, is_player: bool) -> String:
	var player_text:= str(raw_event.get("text", "Something happened."))
	var life_diary_text: String = str(raw_event.get("life_diary_text", "")).strip_edges()
	var npc_text:= str(raw_event.get("third_person_text", ""))
	var forced_first_person: bool = bool(raw_event.get("force_first_person_memory", false))

	if life_diary_text != "":
		return life_diary_text

	if is_player or forced_first_person:
		return player_text

	if npc_text != "":
		return npc_text

	return _safe_first_to_third(person, player_text)
func _resolve_narrative_event_person(person_or_payload, raw_event: Dictionary = {}) -> Dictionary:
	var person: Person = null
	var event_payload: Dictionary = {}

	if person_or_payload is Person:
		person = person_or_payload
		event_payload = raw_event.duplicate(true)
	elif typeof(person_or_payload) == TYPE_DICTIONARY:
		event_payload = person_or_payload.duplicate(true)
		var npc_id: int = int(event_payload.get("npc_id", event_payload.get("actor_id", -1)))
		if gs != null and npc_id > 0:
			person = gs.get_npc_by_id(npc_id)
			if person == null and gs.has_method("get_or_reactivate_npc_by_id"):
				person = gs.get_or_reactivate_npc_by_id(npc_id)
		if person == null and gs != null and gs.player != null and npc_id == int(gs.player.id):
			person = gs.player

	return {
		"person": person,
		"payload": event_payload
	}


func _build_narrative_contract(person: Person, event_payload: Dictionary, is_player: bool) -> Dictionary:
	var event_name: String = str(event_payload.get("event_name", event_payload.get("type", "text"))).strip_edges()
	if event_name == "":
		event_name = "text"

	var category: String = str(event_payload.get("category", _infer_narrative_category(event_name, event_payload))).strip_edges()
	if category == "":
		category = "life"

	var perspective: String = str(event_payload.get("perspective", "")).strip_edges()
	if perspective == "":
		perspective = "first_person" if is_player or bool(event_payload.get("force_first_person_memory", false)) else "third_person"

	var participant_ids: Array = _narrative_participant_ids(person, event_payload)
	var emotional_tags: Array = _narrative_emotion_tags(event_name, category, event_payload)
	var memory_impact: Dictionary = _build_narrative_memory_impact(event_name, category, event_payload, emotional_tags)

	var narrative_id: String = str(event_payload.get("narrative_id", "")).strip_edges()
	if narrative_id == "":
		narrative_id = "narrative_%d_%d_%s" % [
			int(person.id),
			int(Time.get_ticks_msec()),
			event_name
		]

	return {
		"schema": NARRATIVE_CONTRACT_SCHEMA,
		"version": NARRATIVE_CONTRACT_VERSION,
		"narrative_id": narrative_id,
		"year": int(event_payload.get("year", gs.year if gs != null else 0)),
		"era": str(event_payload.get("era", gs.era.name if gs != null and gs.era != null else "")),
		"source": str(event_payload.get("source", "narrative_engine")),
		"event": {
			"name": event_name,
			"type": str(event_payload.get("type", event_name)),
			"category": category,
			"raw": event_payload.duplicate(true)
		},
		"subject": {
			"person_id": int(person.id),
			"person_name": _name(person),
			"is_player": is_player,
			"age": int(person.age)
		},
		"participants": {
			"actor_id": int(event_payload.get("actor_id", int(person.id))),
			"npc_id": int(event_payload.get("npc_id", int(person.id))),
			"target_id": int(event_payload.get("target_id", -1)),
			"victim_id": int(event_payload.get("victim_id", -1)),
			"perpetrator_id": int(event_payload.get("perpetrator_id", event_payload.get("accused_id", -1))),
			"opponent_id": int(event_payload.get("opponent_id", -1)),
			"participant_ids": participant_ids
		},
		"rendering": {
			"perspective": perspective,
			"tone": str(event_payload.get("tone", "")),
			"allow_reinterpretation": bool(event_payload.get("allow_reinterpretation", true)),
			"supports_conflicting_narratives": bool(event_payload.get("supports_conflicting_narratives", true)),
			"explicit_text": str(event_payload.get("text", "")),
			"life_diary_text": str(event_payload.get("life_diary_text", "")),
			"third_person_text": str(event_payload.get("third_person_text", ""))
		},
		"memory": {
			"schema": NARRATIVE_MEMORY_SCHEMA,
			"type": str(event_payload.get("memory_type", "episodic")),
			"salience": float(event_payload.get("salience", -1.0)),
			"emotion_tags": emotional_tags,
			"impact": memory_impact,
			"shared_event_id": str(event_payload.get("shared_event_id", narrative_id)),
			"conflicting_narrative_group": str(event_payload.get("conflicting_narrative_group", "")),
			"relationship_delta": int(event_payload.get("relationship_delta", _default_relationship_delta_for_event(event_name, category, event_payload)))
		},
		"consciousness": {
			"enabled": true,
			"contract_source": "narrative_engine",
			"memory_evolution": bool(event_payload.get("memory_evolution", true)),
		}
	}


func _resolve_narrative_contract_through_consciousness(person: Person, narrative_contract: Dictionary) -> Dictionary:
	if gs == null or person == null:
		return narrative_contract

	if gs.consciousness_engine == null:
		return narrative_contract

	if not gs.consciousness_engine.has_method("ensure_consciousness"):
		return narrative_contract

	var consciousness_contract: Dictionary = gs.consciousness_engine.ensure_consciousness(person, {
		"source": "narrative_engine.pre_render",
		"narrative_contract": narrative_contract.duplicate(true)
	})

	var rendering: Dictionary = narrative_contract.get("rendering", {}).duplicate(true)
	var tone: String = str(rendering.get("tone", "")).strip_edges()
	if tone == "":
		tone = _narrative_tone_from_consciousness(person, consciousness_contract, narrative_contract)
	rendering ["tone"] = tone

	narrative_contract ["rendering"] = rendering
	narrative_contract ["resolved_consciousness"] = {
		"contract": consciousness_contract.duplicate(true),
		"state": person.consciousness_state.duplicate(true) if typeof(person.consciousness_state) == TYPE_DICTIONARY else {}
	}

	return narrative_contract


func _render_contract_text(person: Person, narrative_contract: Dictionary, is_player: bool) -> String:
	var event_raw: Dictionary = narrative_contract.get("event", {}).get("raw", {}).duplicate(true)
	var rendering: Dictionary = narrative_contract.get("rendering", {}).duplicate(true)

	var perspective: String = str(rendering.get("perspective", "")).strip_edges()
	var forced_first_person: bool = perspective == "first_person"
	if forced_first_person:
		event_raw ["force_first_person_memory"] = true

	var text: String = _render_event_text(person, event_raw, is_player or forced_first_person)
	var tone: String = str(rendering.get("tone", "")).strip_edges().to_lower()

	return _apply_narrative_tone_filter(text, tone, narrative_contract)


func _apply_narrative_tone_filter(text: String, tone: String, narrative_contract: Dictionary) -> String:
	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		return clean_text

	if not _narrative_contract_uses_first_person_tone(narrative_contract):
		return clean_text

	var event: Dictionary = narrative_contract.get("event", {}) if typeof(narrative_contract.get("event", {})) == TYPE_DICTIONARY else {}
	var category: String = str(event.get("category", "")).strip_edges().to_lower()
	var event_name: String = str(event.get("name", "")).strip_edges().to_lower()

	match tone:
		"hopeful":
			if category in ["death", "grief", "trauma"] or event_name.find("lost") >= 0:
				return clean_text + " Somehow, I still felt like this would not be the end of my story."
			return clean_text

		"bitter":
			if clean_text.ends_with("."):
				return clean_text + " I hated how much it still mattered."
			return clean_text + ". I hated how much it still mattered."

		"numb":
			if clean_text.ends_with("."):
				return clean_text + " I barely knew what to feel."
			return clean_text + ". I barely knew what to feel."

		"spiritual":
			if category in ["death", "grief", "trauma"] or event_name.find("death") >= 0:
				return clean_text + " I tried to understand it through faith."
			return clean_text

		_:
			return clean_text
func _narrative_contract_uses_first_person_tone(narrative_contract: Dictionary) -> bool:
	if typeof(narrative_contract) != TYPE_DICTIONARY:
		return false

	var rendering: Dictionary = narrative_contract.get("rendering", {}) if typeof(narrative_contract.get("rendering", {})) == TYPE_DICTIONARY else {}
	var perspective: String = str(rendering.get("perspective", "")).strip_edges().to_lower()
	if perspective == "first_person":
		return true

	var event: Dictionary = narrative_contract.get("event", {}) if typeof(narrative_contract.get("event", {})) == TYPE_DICTIONARY else {}
	var raw: Dictionary = event.get("raw", {}) if typeof(event.get("raw", {})) == TYPE_DICTIONARY else {}

	return bool(raw.get("force_first_person_memory", false))


func _strip_first_person_tone_tail_for_public_text(text: String) -> String:
	var out: String = str(text).strip_edges()
	if out == "":
		return ""

	var forbidden_tails: Array = [
		" I hated how much it still mattered.",
		". I hated how much it still mattered.",
		" I barely knew what to feel.",
		". I barely knew what to feel.",
		" Somehow, I still felt like this would not be the end of my story.",
		". Somehow, I still felt like this would not be the end of my story.",
		" I tried to understand it through faith.",
		". I tried to understand it through faith."
	]

	for raw_tail in forbidden_tails:
		var tail: String = str(raw_tail)
		if out.ends_with(tail):
			out = out.substr(0, out.length() - tail.length()).strip_edges()

	if out != "" and not out.ends_with(".") and not out.ends_with("!") and not out.ends_with("?"):
		out += "."

	return out


func _build_narrative_memory_packet(person: Person, narrative_contract: Dictionary, text: String) -> Dictionary:
	var memory: Dictionary = narrative_contract.get("memory", {}) if typeof(narrative_contract.get("memory", {})) == TYPE_DICTIONARY else {}
	var rendering: Dictionary = narrative_contract.get("rendering", {}) if typeof(narrative_contract.get("rendering", {})) == TYPE_DICTIONARY else {}
	var event: Dictionary = narrative_contract.get("event", {}) if typeof(narrative_contract.get("event", {})) == TYPE_DICTIONARY else {}

	return {
		"schema": NARRATIVE_MEMORY_SCHEMA,
		"version": NARRATIVE_CONTRACT_VERSION,
		"person_id": int(person.id),
		"person_name": _name(person),
		"text": text,
		"original_text": text,
		"current_text": text,
		"year": int(narrative_contract.get("year", gs.year if gs != null else 0)),
		"age": int(person.age),
		"source": str(narrative_contract.get("source", "narrative_engine")),
		"event_name": str(event.get("name", "text")),
		"category": str(event.get("category", "life")),
		"perspective": str(rendering.get("perspective", "first_person")),
		"tone": str(rendering.get("tone", "neutral")),
		"emotion_tags": memory.get("emotion_tags", []).duplicate(true) if typeof(memory.get("emotion_tags", [])) == TYPE_ARRAY else [],
		"impact": memory.get("impact", {}).duplicate(true) if typeof(memory.get("impact", {})) == TYPE_DICTIONARY else {},
		"relationship_delta": int(memory.get("relationship_delta", 0)),
		"shared_event_id": str(memory.get("shared_event_id", narrative_contract.get("narrative_id", ""))),
		"conflicting_narrative_group": str(memory.get("conflicting_narrative_group", "")),
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _commit_narrative_memory(person: Person, narrative_contract: Dictionary, text: String) -> void:
	if gs == null or person == null:
		return

	if gs.memory_engine != null and gs.memory_engine.has_method("remember"):
		gs.memory_engine.remember(int(person.id), text)

	if gs.legacy_memory_engine != null and gs.legacy_memory_engine.has_method("record_dynasty_event"):
		gs.legacy_memory_engine.record_dynasty_event(person, text)

	if gs.consciousness_engine != null and gs.consciousness_engine.has_method("remember"):
		var memory_packet: Dictionary = narrative_contract.get("memory_packet", {}).duplicate(true)
		gs.consciousness_engine.remember(person, text, {
			"source": str(narrative_contract.get("source", "narrative_engine")),
			"memory_type": str(memory_packet.get("memory_type", memory_packet.get("type", "episodic"))),
			"perspective": str(memory_packet.get("perspective", "first_person")),
			"narrative_contract": narrative_contract.duplicate(true),
			"narrative_tone": str(memory_packet.get("tone", "neutral")),
			"emotion_tags": memory_packet.get("emotion_tags", []).duplicate(true) if typeof(memory_packet.get("emotion_tags", [])) == TYPE_ARRAY else [],
			"memory_impact": memory_packet.get("impact", {}).duplicate(true) if typeof(memory_packet.get("impact", {})) == TYPE_DICTIONARY else {},
			"relationship_delta": int(memory_packet.get("relationship_delta", 0)),
			"shared_event_id": str(memory_packet.get("shared_event_id", "")),
			"conflicting_narrative_group": str(memory_packet.get("conflicting_narrative_group", "")),
			"event_name": str(memory_packet.get("event_name", "")),
			"category": str(memory_packet.get("category", "life"))
		})


func _emit_world_feed_from_narrative_contract(person: Person, narrative_contract: Dictionary, text: String) -> void:
	if gs == null or person == null:
		return

	var event_raw: Dictionary = narrative_contract.get("event", {}).get("raw", {}) if typeof(narrative_contract.get("event", {}).get("raw", {})) == TYPE_DICTIONARY else {}
	var is_player: bool = gs.player != null and int(person.id) == int(gs.player.id)

	if is_player:
		return

	if bool(event_raw.get("suppress_world_feed", false)):
		return

	var diary_scope: String = str(event_raw.get("diary_scope", "")).strip_edges().to_lower()
	if diary_scope in ["actor", "other_person", "private", "memory_only", "life_diary"]:
		return

	var world_text: String = _world_feed_text_from_narrative_contract(person, narrative_contract, text)
	if world_text == "":
		return

	if gs.world_feed_engine != null and gs.world_feed_engine.has_method("handle_event"):
		gs.world_feed_engine.handle_event(person, world_text)
func _world_feed_text_from_narrative_contract(person: Person, narrative_contract: Dictionary, fallback_text: String = "") -> String:
	if person == null:
		return ""

	var event_container: Dictionary = narrative_contract.get("event", {}) if typeof(narrative_contract.get("event", {})) == TYPE_DICTIONARY else {}
	var event_raw: Dictionary = event_container.get("raw", {}) if typeof(event_container.get("raw", {})) == TYPE_DICTIONARY else {}

	var public_event: Dictionary = event_raw.duplicate(true)
	public_event.erase("life_diary_text")
	public_event.erase("force_first_person_memory")
	public_event.erase("player_text")
	public_event ["force_first_person_memory"] = false

	if str(public_event.get("third_person_text", "")).strip_edges() == "" and str(public_event.get("world_text", "")).strip_edges() != "":
		public_event ["third_person_text"] = str(public_event.get("world_text", ""))

	var world_text: String = _render_event_text(person, public_event, false).strip_edges()
	if world_text == "":
		world_text = str(fallback_text).strip_edges()

	return _strip_first_person_tone_tail_for_public_text(world_text)
func _apply_relationship_memory_hooks(person: Person, narrative_contract: Dictionary, rendered_text: String) -> void:
	if gs == null or person == null:
		return

	var participants: Dictionary = narrative_contract.get("participants", {}) if typeof(narrative_contract.get("participants", {})) == TYPE_DICTIONARY else {}
	var participant_ids: Array = participants.get("participant_ids", []) if typeof(participants.get("participant_ids", [])) == TYPE_ARRAY else []

	for raw_id in participant_ids:
		var other_id: int = int(raw_id)
		if other_id <= 0 or other_id == int(person.id):
			continue

		var other: Person = gs.get_npc_by_id(other_id)
		if other == null and gs.has_method("get_or_reactivate_npc_by_id"):
			other = gs.get_or_reactivate_npc_by_id(other_id)
		if other == null:
			continue

		var counter_text: String = _build_counterparty_memory_text(person, other, narrative_contract, rendered_text)
		if counter_text == "":
			continue

		var counter_delta: int = _counterparty_relationship_delta(person, other, narrative_contract)

		log_event(other, {
			"type": "text",
			"text": counter_text,
			"life_diary_text": counter_text,
			"force_first_person_memory": true,
			"source": "narrative_engine.relationship_memory_hook",
			"category": str(narrative_contract.get("event", {}).get("category", "relationship")),
			"event_name": str(narrative_contract.get("event", {}).get("name", "relationship_memory")),
			"actor_id": int(person.id),
			"target_id": other_id,
			"shared_event_id": str(narrative_contract.get("narrative_id", "")),
			"conflicting_narrative_group": str(narrative_contract.get("memory", {}).get("shared_event_id", narrative_contract.get("narrative_id", ""))),
			"supports_conflicting_narratives": true,
			"relationship_delta": counter_delta,
			"memory_type": "relationship",
			"skip_relationship_hooks": true,
			"suppress_world_feed": true
		})

		_record_conflicting_narrative_pair(person, other, narrative_contract, rendered_text, counter_text)


func _apply_narrative_relationship_delta(person: Person, narrative_contract: Dictionary) -> void:
	if gs == null or person == null:
		return

	var participants: Dictionary = narrative_contract.get("participants", {}) if typeof(narrative_contract.get("participants", {})) == TYPE_DICTIONARY else {}
	var other_id: int = int(participants.get("target_id", participants.get("opponent_id", participants.get("victim_id", -1))))
	if other_id <= 0 or other_id == int(person.id):
		return

	var other: Person = gs.get_npc_by_id(other_id)
	if other == null and gs.has_method("get_or_reactivate_npc_by_id"):
		other = gs.get_or_reactivate_npc_by_id(other_id)
	if other == null:
		return

	var memory: Dictionary = narrative_contract.get("memory", {}) if typeof(narrative_contract.get("memory", {})) == TYPE_DICTIONARY else {}
	var relationship_delta: int = int(memory.get("relationship_delta", 0))
	if relationship_delta == 0:
		return

	_adjust_affection(person, other, relationship_delta)


func _adjust_affection(owner: Person, other: Person, delta: int) -> void:
	if owner == null or other == null or delta == 0:
		return

	if typeof(owner.affection) != TYPE_DICTIONARY:
		owner.affection = {}

	var other_id: int = int(other.id)
	var key: Variant = other_id
	if not owner.affection.has(key) and owner.affection.has(str(other_id)):
		key = str(other_id)

	var current_value: int = int(owner.affection.get(key, 50))
	owner.affection [key] = clamp(current_value + delta, 0, 100)


func _record_conflicting_narrative_pair(person: Person, other: Person, narrative_contract: Dictionary, person_text: String, other_text: String) -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var rows: Array = gs.scenario_state.get("conflicting_narratives", []) if typeof(gs.scenario_state.get("conflicting_narratives", [])) == TYPE_ARRAY else []
	rows.append({
		"schema": "eralife.conflicting_narrative_pair",
		"version": NARRATIVE_CONTRACT_VERSION,
		"shared_event_id": str(narrative_contract.get("narrative_id", "")),
		"year": int(narrative_contract.get("year", gs.year if gs != null else 0)),
		"person_a_id": int(person.id),
		"person_a_name": _name(person),
		"person_a_text": person_text,
		"person_b_id": int(other.id),
		"person_b_name": _name(other),
		"person_b_text": other_text,
		"event_name": str(narrative_contract.get("event", {}).get("name", "")),
		"category": str(narrative_contract.get("event", {}).get("category", "")),
		"created_at_ms": int(Time.get_ticks_msec())
	})

	while rows.size() > 200:
		rows.pop_front()

	gs.scenario_state ["conflicting_narratives"] = rows


func _build_counterparty_memory_text(actor: Person, other: Person, narrative_contract: Dictionary, _rendered_text: String) -> String:
	if actor == null or other == null:
		return ""

	var event: Dictionary = narrative_contract.get("event", {}) if typeof(narrative_contract.get("event", {})) == TYPE_DICTIONARY else {}
	var event_name: String = str(event.get("name", "")).strip_edges().to_lower()
	var category: String = str(event.get("category", "")).strip_edges().to_lower()
	var raw: Dictionary = event.get("raw", {}) if typeof(event.get("raw", {})) == TYPE_DICTIONARY else {}

	var actor_name: String = _name(actor)
	var other_is_target: bool = int(raw.get("target_id", raw.get("opponent_id", -1))) == int(other.id)
	var other_is_victim: bool = int(raw.get("victim_id", -1)) == int(other.id)
	var crime_name: String = str(raw.get("crime_name", raw.get("crime_type", "crime"))).strip_edges()
	if crime_name == "":
		crime_name = "crime"

	if category == "crime" or event_name.find("crime") >= 0:
		if other_is_victim:
			return "%s committed %s against me." % [actor_name, crime_name]
		return "I remember being connected to %s's %s case." % [actor_name, crime_name]

	if category == "bending" or event_name.find("bending_duel") >= 0:
		if event_name.find("victory") >= 0 or str(raw.get("outcome", "")).to_lower() == "victory":
			if other_is_target:
				return "I lost a bending duel against %s." % actor_name
			return "I remember %s winning a bending duel." % actor_name
		if event_name.find("loss") >= 0 or str(raw.get("outcome", "")).to_lower() == "loss":
			if other_is_target:
				return "I defeated %s in a bending duel." % actor_name
			return "I remember %s losing a bending duel." % actor_name

	if category in ["relationship", "social"]:
		return "I remembered what happened between me and %s." % actor_name

	return "I remembered what happened with %s." % actor_name


func _counterparty_relationship_delta(_person: Person, other: Person, narrative_contract: Dictionary) -> int:
	var event: Dictionary = narrative_contract.get("event", {}) if typeof(narrative_contract.get("event", {})) == TYPE_DICTIONARY else {}
	var raw: Dictionary = event.get("raw", {}) if typeof(event.get("raw", {})) == TYPE_DICTIONARY else {}
	var category: String = str(event.get("category", "")).strip_edges().to_lower()
	var event_name: String = str(event.get("name", "")).strip_edges().to_lower()

	if category == "crime":
		if int(raw.get("victim_id", -1)) == int(other.id):
			return -18
		return -6

	if event_name.find("betray") >= 0:
		return -16
	if event_name.find("insult") >= 0:
		return -8
	if event_name.find("fight") >= 0:
		return -10
	if event_name.find("bending_duel") >= 0:
		return -3
	if event_name.find("gift") >= 0 or event_name.find("compliment") >= 0:
		return 5

	return int(narrative_contract.get("memory", {}).get("relationship_delta", 0))


func _commit_narrative_report(narrative_contract: Dictionary) -> void:
	last_narrative_contract = narrative_contract.duplicate(true)
	narrative_reports.append(last_narrative_contract.duplicate(true))
	while narrative_reports.size() > MAX_NARRATIVE_REPORTS:
		narrative_reports.pop_front()


func _narrative_participant_ids(person: Person, event_payload: Dictionary) -> Array:
	var out: Array = []
	if person != null:
		out.append(int(person.id))

	for key in ["actor_id", "npc_id", "target_id", "victim_id", "perpetrator_id", "accused_id", "opponent_id"]:
		var id_value: int = int(event_payload.get(key, -1))
		if id_value > 0 and id_value not in out:
			out.append(id_value)

	var raw_participant_ids: Variant = event_payload.get("participant_ids", [])
	if typeof(raw_participant_ids) == TYPE_ARRAY:
		for raw_id in raw_participant_ids:
			var participant_id: int = int(raw_id)
			if participant_id > 0 and participant_id not in out:
				out.append(participant_id)

	return out


func _infer_narrative_category(event_name: String, event_payload: Dictionary) -> String:
	var clean_event: String = str(event_name).strip_edges().to_lower()
	var explicit_category: String = str(event_payload.get("category", "")).strip_edges()
	if explicit_category != "":
		return explicit_category

	if clean_event.find("death") >= 0 or clean_event == "death":
		return "death"
	if clean_event.find("crime") >= 0 or clean_event.find("arrest") >= 0 or clean_event.find("case") >= 0:
		return "crime"
	if clean_event.find("bending") >= 0 or clean_event.find("duel") >= 0 or clean_event.find("tournament") >= 0 or clean_event.find("spar") >= 0:
		return "bending"
	if clean_event.find("relationship") >= 0 or clean_event.find("romance") >= 0 or clean_event.find("betray") >= 0:
		return "relationship"
	if clean_event.find("job") >= 0 or clean_event.find("career") >= 0:
		return "career"

	return "life"


func _narrative_emotion_tags(event_name: String, category: String, event_payload: Dictionary) -> Array:
	var out: Array = []
	var raw_tags: Variant = event_payload.get("emotion_tags", [])
	if typeof(raw_tags) == TYPE_ARRAY:
		for raw_tag in raw_tags:
			var tag: String = str(raw_tag).strip_edges()
			if tag != "" and tag not in out:
				out.append(tag)

	var clean_event: String = str(event_name).strip_edges().to_lower()
	var clean_category: String = str(category).strip_edges().to_lower()

	if clean_category in ["death", "trauma"] or clean_event.find("death") >= 0 or clean_event.find("died") >= 0:
		out.append("grief")
	if clean_category == "crime":
		out.append("violation")
	if clean_category == "bending" or clean_event.find("duel") >= 0:
		out.append("competition")
	if clean_event.find("won") >= 0 or clean_event.find("victory") >= 0:
		out.append("achievement")
	if clean_event.find("lost") >= 0 or clean_event.find("loss") >= 0:
		out.append("humiliation")
	if clean_event.find("betray") >= 0:
		out.append("betrayal")

	return out


func _build_narrative_memory_impact(event_name: String, category: String, event_payload: Dictionary, emotional_tags: Array) -> Dictionary:
	var trauma: float = 0.0
	var healing: float = 0.0
	var resentment: float = 0.0
	var pride: float = 0.0

	var clean_event: String = str(event_name).strip_edges().to_lower()
	var clean_category: String = str(category).strip_edges().to_lower()

	if clean_category == "death":
		trauma += 0.45
	if clean_category == "crime":
		trauma += 0.35
		resentment += 0.45
	if clean_category == "bending":
		pride += 0.15
		if clean_event.find("loss") >= 0:
			resentment += 0.12
			trauma += 0.08
	if "betrayal" in emotional_tags:
		resentment += 0.35
		trauma += 0.25
	if "achievement" in emotional_tags:
		pride += 0.25
		healing += 0.08

	trauma = max(trauma, float(event_payload.get("trauma_score", 0.0)))
	healing = max(healing, float(event_payload.get("healing_score", 0.0)))
	resentment = max(resentment, float(event_payload.get("resentment_score", 0.0)))
	pride = max(pride, float(event_payload.get("pride_score", 0.0)))

	return {
		"trauma": clamp(trauma, 0.0, 1.0),
		"healing": clamp(healing, 0.0, 1.0),
		"resentment": clamp(resentment, 0.0, 1.0),
		"pride": clamp(pride, 0.0, 1.0),
		"memory_pressure": clamp(trauma + resentment - healing, 0.0, 1.0)
	}


func _default_relationship_delta_for_event(event_name: String, category: String, event_payload: Dictionary) -> int:
	if event_payload.has("relationship_delta"):
		return int(event_payload.get("relationship_delta", 0))

	var clean_event: String = str(event_name).strip_edges().to_lower()
	var clean_category: String = str(category).strip_edges().to_lower()

	if clean_category == "crime":
		return -15
	if clean_event.find("betray") >= 0:
		return -18
	if clean_event.find("insult") >= 0:
		return -8
	if clean_event.find("fight") >= 0:
		return -10
	if clean_event.find("bending_duel") >= 0:
		return -2
	if clean_event.find("gift") >= 0:
		return 6
	if clean_event.find("compliment") >= 0:
		return 4

	return 0


func _narrative_tone_from_consciousness(person: Person, consciousness_contract: Dictionary, narrative_contract: Dictionary) -> String:
	if person == null:
		return "neutral"

	var state: Dictionary = person.consciousness_state if typeof(person.consciousness_state) == TYPE_DICTIONARY else {}
	var belief: Dictionary = consciousness_contract.get("belief_system", {}) if typeof(consciousness_contract.get("belief_system", {})) == TYPE_DICTIONARY else {}
	var event: Dictionary = narrative_contract.get("event", {}) if typeof(narrative_contract.get("event", {})) == TYPE_DICTIONARY else {}
	var memory: Dictionary = narrative_contract.get("memory", {}) if typeof(narrative_contract.get("memory", {})) == TYPE_DICTIONARY else {}
	var impact: Dictionary = memory.get("impact", {}) if typeof(memory.get("impact", {})) == TYPE_DICTIONARY else {}

	var category: String = str(event.get("category", "")).strip_edges().to_lower()
	var trauma: float = float(impact.get("trauma", 0.0))
	var resentment: float = float(impact.get("resentment", 0.0))
	var healing: float = float(impact.get("healing", 0.0))
	var faith_level: float = float(belief.get("faith_level", state.get("faith_level", 0.0)))
	var emotional_load: float = float(state.get("emotional_load", 0.0))
	var pressure_load: float = float(state.get("pressure_load", 0.0))

	if faith_level >= 0.72 and (category in ["death", "trauma"] or trauma >= 0.35):
		return "spiritual"
	if resentment >= 0.4 or pressure_load >= 0.68:
		return "bitter"
	if emotional_load >= 0.72 and trauma >= 0.3:
		return "numb"
	if healing >= 0.25 or int(person.satisfaction) >= 72:
		return "hopeful"

	return "neutral"


func get_relationship_memory_summary(viewer: Person, target: Person, limit: int = 6) -> Array:
	var out: Array = []
	if viewer == null or target == null:
		return out

	var viewer_id: int = int(viewer.id)
	var target_id: int = int(target.id)

	for raw_memory in viewer.consciousness_memory_index:
		if typeof(raw_memory) != TYPE_DICTIONARY:
			continue
		var memory: Dictionary = raw_memory
		var contract: Dictionary = memory.get("narrative_contract", {}) if typeof(memory.get("narrative_contract", {})) == TYPE_DICTIONARY else {}
		var participants: Dictionary = contract.get("participants", {}) if typeof(contract.get("participants", {})) == TYPE_DICTIONARY else {}
		var participant_ids: Array = participants.get("participant_ids", []) if typeof(participants.get("participant_ids", [])) == TYPE_ARRAY else []

		if target_id not in participant_ids:
			continue

		out.append({
			"year": int(memory.get("year", 0)),
			"text": str(memory.get("current_text", memory.get("text", ""))),
			"tone": str(memory.get("tone", "neutral")),
			"event_name": str(memory.get("event_name", "")),
			"viewer_id": viewer_id,
			"target_id": target_id
		})

	while out.size() > limit:
		out.pop_front()

	return out


func build_conflicting_narrative_rows(person_a: Person, person_b: Person, limit: int = 6) -> Array:
	var out: Array = []
	if gs == null or person_a == null or person_b == null:
		return out
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return out

	var rows: Array = gs.scenario_state.get("conflicting_narratives", []) if typeof(gs.scenario_state.get("conflicting_narratives", [])) == TYPE_ARRAY else []
	var a_id: int = int(person_a.id)
	var b_id: int = int(person_b.id)

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = raw_row
		var pair_matches: bool = (
			(int(row.get("person_a_id", -1)) == a_id and int(row.get("person_b_id", -1)) == b_id)
			or (int(row.get("person_a_id", -1)) == b_id and int(row.get("person_b_id", -1)) == a_id)
		)
		if not pair_matches:
			continue
		out.append(row.duplicate(true))

	while out.size() > limit:
		out.pop_front()

	return out






func _safe_first_to_third(person: Person, text: String) -> String:

	if text == "":
		return text

	var nm = _name(person)
	var obj = _obj_pronoun(person)
	var poss = _poss_pronoun(person)


	if text.begins_with("I "):
		text = nm + text.substr(1)
	elif text.begins_with("I'm "):
		text = nm + " is " + text.substr(4)
	elif text.begins_with("I’ve "):
		text = nm + " has " + text.substr(5)
	elif text.begins_with("I've "):
		text = nm + " has " + text.substr(5)
	elif text.begins_with("I’d "):
		text = nm + " would " + text.substr(4)
	elif text.begins_with("I'd "):
		text = nm + " would " + text.substr(4)
	elif text.begins_with("I was "):
		text = nm + " was " + text.substr(6)
	elif text.begins_with("I am "):
		text = nm + " is " + text.substr(5)


	text = text.replace(", I ", ", " + nm + " ")
	text = text.replace("; I ", "; " + nm + " ")
	text = text.replace(". I ", ". " + nm + " ")


	var swaps = {
		" my ": " %s " % poss,
		" my.": " %s." % poss,
		" my,": " %s," % poss,
		" my!": " %s!" % poss,
		" my?": " %s?" % poss,

		" me ": " %s " % obj,
		" me.": " %s." % obj,
		" me,": " %s," % obj,
		" me!": " %s!" % obj,
		" me?": " %s?" % obj
	}

	for k in swaps.keys():
		text = text.replace(k, swaps [k])


	if text.begins_with("At "):
		var parts = text.split(", ", false, 1)
		if parts.size() == 2:
			var second = parts [1]
			if second.begins_with("I "):
				second = nm + second.substr(1)
			elif second.begins_with("I'm "):
				second = nm + " is " + second.substr(4)
			elif second.begins_with("I was "):
				second = nm + " was " + second.substr(6)
			parts [1] = second
			text = parts [0] + ", " + parts [1]

	return text