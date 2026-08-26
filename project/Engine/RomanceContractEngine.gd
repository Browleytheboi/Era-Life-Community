extends Resource
class_name RomanceContractEngine

const CONTRACT_SCHEMA:= "eralife.romance_contract_engine"
const CONTRACT_VERSION:= 1
const FOREIGN_ROMANCE_SCHEMA:= "eralife.romance_contract.foreign_outreach"

var gs
var pending_romance_contracts: Dictionary = {}
var active_foreign_romance_links: Dictionary = {}
var romance_contract_history: Array = []
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs


func export_state() -> Dictionary:
	return _make_binary_safe({
		"schema": CONTRACT_SCHEMA + "_state",
		"version": CONTRACT_VERSION,
		"pending_romance_contracts": pending_romance_contracts.duplicate(true),
		"active_foreign_romance_links": active_foreign_romance_links.duplicate(true),
		"romance_contract_history": romance_contract_history.duplicate(true),
		"last_report": last_report.duplicate(true)
	})


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "RomanceContractEngine import_state expected a Dictionary."}

	pending_romance_contracts = _safe_dictionary(data.get("pending_romance_contracts", {}))
	active_foreign_romance_links = _safe_dictionary(data.get("active_foreign_romance_links", {}))
	romance_contract_history = _safe_array(data.get("romance_contract_history", []))
	last_report = _safe_dictionary(data.get("last_report", {}))

	return {
		"success": true,
		"pending_count": pending_romance_contracts.size(),
		"active_link_count": active_foreign_romance_links.size()
	}


func yearly_tick() -> void:
	var expired_ids: Array = []
	var current_year: int = _current_year()

	for raw_id in pending_romance_contracts.keys():
		var contract_id: String = str(raw_id)
		var contract: Dictionary = _safe_dictionary(pending_romance_contracts.get(contract_id, {}))
		var created_year: int = int(contract.get("created_year", current_year))
		if current_year - created_year >= 2:
			contract ["state"] = "expired"
			contract ["expired_year"] = current_year
			contract ["updated_at_ms"] = int(Time.get_ticks_msec())
			romance_contract_history.append(contract.duplicate(true))
			expired_ids.append(contract_id)

	for contract_id in expired_ids:
		pending_romance_contracts.erase(contract_id)

	if romance_contract_history.size() > 120:
		romance_contract_history = romance_contract_history.slice(romance_contract_history.size() - 120, romance_contract_history.size())


func route_command_envelope(envelope: Dictionary) -> Dictionary:
	if typeof(envelope) != TYPE_DICTIONARY or envelope.is_empty():
		return { "success": false, "reason": "Romance command envelope is empty."}

	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()
	var payload: Dictionary = _safe_dictionary(envelope.get("payload", {}))

	match command_id:
		"romance.find_foreign_date":
			return begin_foreign_date_search(_actor_from_payload(payload), _safe_dictionary(payload.get("entry", {})), str(payload.get("preference", "woman")), payload)
		"romance.accept_foreign_date":
			return accept_pending_foreign_romance_contract(_actor_from_payload(payload), str(payload.get("contract_id", "")), payload)
		_:
			return { "success": false, "reason": "No RomanceContractEngine route claimed this command.", "command": command_id}


func begin_foreign_date_search(actor: Person, entry: Dictionary, preference: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return _failure_report("Romance Contract Failed", "No actor was supplied to the romance contract.")
	if entry.is_empty():
		return _failure_report("Romance Contract Failed", "The target country or realm could not be resolved.")

	var clean_entry: Dictionary = _normalize_romance_target_entry(entry)
	var preference_gender: String = _preference_to_gender(preference)
	if preference_gender == "":
		return _failure_report("Romance Preference Missing", "Choose whether you are looking for a man or a woman first.")

	var target_name: String = _entry_display_name(clean_entry)
	var target_sentence_name: String = _romance_target_sentence_name(clean_entry)
	var _realm: Dictionary = _safe_dictionary(clean_entry.get("realm", {}))
	var era_name: String = _current_era_name()
	var channel: String = _romance_channel_for_era(era_name)
	var importance: int = _actor_importance_score(actor)
	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed("foreign_romance|%s|%s|%s|%s|%s" % [
		str(actor.id),
		target_name,
		preference_gender,
		era_name,
		str(_current_year())
	])

	if not _message_reaches_candidate(actor, importance, channel, rng):
		var failed_text: String = _failed_outreach_text(actor, target_name, preference_gender, channel, importance, rng)
		var failed_journal_text: String = _foreign_romance_outcome_diary_text(actor, null, clean_entry, channel, false, rng)
		var failed_world_text: String = _foreign_romance_outcome_world_text(actor, null, clean_entry, channel, false, rng)

		last_report = {
			"success": false,
			"mode": "foreign_romance_outreach_failed",
			"popup_title": _channel_title(channel),
			"popup_text": failed_text,
			"text": failed_text,
			"journal_text": failed_journal_text,
			"player_text": failed_journal_text,
			"world_feed_text": failed_world_text,
			"status_text": "Nobody answered from %s." % target_sentence_name,
			"can_accept": false,
			"channel": channel,
			"importance_score": importance
		}
		return last_report.duplicate(true)

	var candidate: Person = _find_or_create_foreign_romance_candidate(actor, clean_entry, preference_gender, rng)
	if candidate == null:
		return _failure_report("Romance Contract Failed", "The contract reached the realm, but no valid person could be instantiated.")

	_repair_foreign_romance_candidate_location(candidate, clean_entry, rng)

	var target_location: Dictionary = _romance_target_location(clean_entry, rng)
	var contract_id: String = "romance_%s_%s_%s" % [
		str(actor.id),
		_target_country_key(clean_entry),
		str(_stable_seed("%s|%s|%s" % [str(actor.id), str(candidate.id), str(Time.get_ticks_msec())]))
	]

	var person_card: Dictionary = _build_person_card(actor, candidate, clean_entry, rng)
	var narrative: String = _successful_outreach_text(actor, candidate, clean_entry, channel, rng)
	var journal_text: String = _foreign_romance_outcome_diary_text(actor, candidate, clean_entry, channel, true, rng)
	var world_text: String = _foreign_romance_outcome_world_text(actor, candidate, clean_entry, channel, true, rng)

	var contract: Dictionary = {
		"schema": FOREIGN_ROMANCE_SCHEMA,
		"version": CONTRACT_VERSION,
		"contract_id": contract_id,
		"state": "pending_response",
		"actor_id": int(actor.id),
		"candidate_id": int(candidate.id),
		"target_name": target_name,
		"target_country": str(target_location.get("country", _entry_country(clean_entry))),
		"target_city": str(target_location.get("city", _entry_city(clean_entry))),
		"era": era_name,
		"channel": channel,
		"preference_gender": preference_gender,
		"importance_score": importance,
		"created_year": _current_year(),
		"updated_year": _current_year(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"person_card": person_card.duplicate(true),
		"context": _make_binary_safe(context)
	}

	pending_romance_contracts [contract_id] = contract

	last_report = {
		"success": true,
		"mode": "foreign_romance_candidate_found",
		"popup_title": _channel_title(channel),
		"popup_text": narrative,
		"text": narrative,
		"journal_text": journal_text,
		"player_text": journal_text,
		"world_feed_text": world_text,
		"status_text": "Someone from %s answered." % target_sentence_name,
		"contract_id": contract_id,
		"candidate_id": int(candidate.id),
		"person_card": person_card,
		"can_accept": true,
		"channel": channel,
		"importance_score": importance
	}

	return last_report.duplicate(true)

func accept_pending_foreign_romance_contract(actor: Person, contract_id: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return _failure_report("Romance Contract Failed", "No actor was supplied.")

	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "" or not pending_romance_contracts.has(clean_id):
		return _failure_report("Letter Already Cold", "That romance contract is no longer pending.")

	var contract: Dictionary = _safe_dictionary(pending_romance_contracts.get(clean_id, {}))
	var candidate_id: int = int(contract.get("candidate_id", -1))
	var candidate: Person = _get_person_by_id(candidate_id)

	if candidate == null:
		return _failure_report("Person Missing", "The person who answered could not be found in the world anymore.")

	actor.affection [int(candidate.id)] = max(int(actor.affection.get(int(candidate.id), 50)), 66)
	candidate.affection [int(actor.id)] = max(int(candidate.affection.get(int(actor.id), 50)), 70)

	var relationship_label: String = _foreign_romance_relationship_label(candidate)
	var popup_text: String = _foreign_romance_accept_popup_text(actor, candidate, relationship_label)
	var journal_text: String = _foreign_romance_accept_diary_text(actor, candidate, relationship_label)
	var world_text: String = _foreign_romance_accept_world_text(actor, candidate, relationship_label)

	actor.memories.append(journal_text)
	candidate.memories.append("I became long-distance writing flings with %s." % _person_name(actor))

	contract ["state"] = "accepted"
	contract ["relationship_type"] = "foreign_writing_fling"
	contract ["relationship_label"] = "Writing Fling"
	contract ["long_distance"] = true
	contract ["accepted_year"] = _current_year()
	contract ["updated_year"] = _current_year()
	contract ["updated_at_ms"] = int(Time.get_ticks_msec())
	contract ["accept_context"] = _make_binary_safe(context)

	active_foreign_romance_links [clean_id] = contract.duplicate(true)
	_register_foreign_romance_fling(actor, candidate, clean_id, contract)

	pending_romance_contracts.erase(clean_id)
	romance_contract_history.append(contract.duplicate(true))

	if gs != null and gs.has_method("push_world_feed"):
		gs.push_world_feed(world_text, {
			"world_text": world_text,
			"player_text": journal_text,
			"npc_id": int(candidate.id),
			"personally_relevant": true,
			"category": "relationship",
			"event_name": "foreign_romance_writing_fling_started",
			"source": "romance_contract_engine",
			"contract_id": clean_id,
			"relationship_type": "foreign_writing_fling"
		})

	last_report = {
		"success": true,
		"mode": "foreign_romance_writing_fling_accepted",
		"popup_title": "Long-Distance Writing Fling Started",
		"popup_text": popup_text,
		"text": popup_text,
		"journal_text": journal_text,
		"player_text": journal_text,
		"world_feed_text": world_text,
		"status_text": "Long-distance writing fling started.",
		"contract_id": clean_id,
		"candidate_id": int(candidate.id),
		"person_card": _safe_dictionary(contract.get("person_card", {})),
		"can_accept": false,
		"relationship_type": "foreign_writing_fling",
		"relationship_label": "Writing Fling"
	}

	return last_report.duplicate(true)

func _find_or_create_foreign_romance_candidate(actor: Person, entry: Dictionary, preference_gender: String, rng: RandomNumberGenerator) -> Person:
	var existing: Person = _find_existing_candidate(actor, entry, preference_gender, rng)
	if existing != null:
		return existing
	return _create_foreign_candidate(actor, entry, preference_gender, rng)


func _find_existing_candidate(actor: Person, entry: Dictionary, preference_gender: String, rng: RandomNumberGenerator) -> Person:
	if gs == null or not ("npcs" in gs):
		return null

	var target_country: String = _entry_country(entry)
	var candidates: Array = []

	for raw_npc in gs.npcs:
		if raw_npc == null or not (raw_npc is Person):
			continue
		var npc: Person = raw_npc as Person
		if npc == actor:
			continue
		if not bool(npc.alive):
			continue
		if str(npc.gender) != preference_gender:
			continue
		if int(npc.age) < 16:
			continue
		if abs(int(npc.age) - int(actor.age)) > 12:
			continue
		if _person_country(npc) != target_country:
			continue
		if npc.partner != null:
			continue
		candidates.append(npc)

	if candidates.is_empty():
		return null

	return candidates [int(rng.randi_range(0, candidates.size() - 1))] as Person


func _create_foreign_candidate(actor: Person, entry: Dictionary, preference_gender: String, rng: RandomNumberGenerator) -> Person:
	if gs == null:
		return null

	var npc:= Person.new()
	npc.id = int(gs.next_id)
	gs.next_id += 1

	var era_name: String = _current_era_name()
	var target_country: String = _entry_country(entry)
	var target_city: String = _entry_city(entry)

	npc.gender = preference_gender
	npc.first_name = _random_first_name(preference_gender, era_name, rng)
	npc.last_name = _random_last_name(target_city, target_country, era_name, rng)
	npc.name = "%s %s" % [npc.first_name, npc.last_name]
	npc.age = _similar_age(actor, rng)
	npc.birth_city = target_city
	npc.birth_country = target_country
	npc.home_city = target_city
	npc.home_country = target_country
	npc.social_class = _target_social_class(actor, rng)
	npc.traits = _candidate_traits(rng)
	npc.smarts = int(rng.randi_range(35, 96))
	npc.looks = int(rng.randi_range(35, 98))
	npc.health = float(rng.randi_range(40, 100))
	npc.mental_health = float(rng.randi_range(35, 100))
	npc.fame = _candidate_fame_from_class(npc.social_class, rng)
	npc.fame_tier = _fame_tier_for_value(int(npc.fame))
	npc.job = _candidate_job_for_era_and_class(era_name, npc.social_class, rng)
	npc.bank_balance = float(rng.randi_range(50, 8000))
	npc.parents = []
	npc.children = []
	npc.friends = []
	npc.memories = []
	npc.affection = {}
	npc.alive = true

	if npc.social_class == "Royal":
		npc.is_royal = true
		npc.royal_title = "Princess" if npc.gender == "Female" else "Prince"
	elif npc.social_class == "Noble":
		npc.royal_title = "Lady" if npc.gender == "Female" else "Lord"

	if gs.capability_graph_engine != null and gs.capability_graph_engine.has_method("initialize_npc"):
		gs.capability_graph_engine.initialize_npc(npc)

	if gs.has_method("register_npc"):
		gs.register_npc(npc)
	elif "npcs" in gs:
		gs.npcs.append(npc)

	return npc


func _message_reaches_candidate(actor: Person, importance: int, channel: String, rng: RandomNumberGenerator) -> bool:
	var roll: int = int(rng.randi_range(1, 100))
	match channel:
		"letter":
			if importance < 25:
				return false
			return roll <= clamp(importance + int(float(actor.looks) / 4.0), 1, 95)
		"public_statement":
			return roll <= clamp(importance + int(float(actor.looks) / 5.0) + 12, 1, 92)
		"future_signal":
			return roll <= clamp(importance + int(float(actor.smarts) / 6.0) + 20, 8, 97)
		_:
			return roll <= clamp(importance + 10, 1, 90)


func _successful_outreach_text(_actor: Person, candidate: Person, entry: Dictionary, channel: String, rng: RandomNumberGenerator) -> String:
	var target_name: String = _romance_target_sentence_name(entry)
	var candidate_name: String = _person_name(candidate)
	var class_text: String = str(candidate.social_class).to_lower()
	var display_location: Dictionary = _candidate_romance_display_location(candidate, entry, rng)
	var city_text: String = str(display_location.get("city", _entry_city(entry)))
	var country_text: String = str(display_location.get("country", _entry_country(entry)))
	var from_text: String = city_text
	if country_text != "":
		from_text = "%s, %s" % [city_text, country_text]

	match channel:
		"letter":
			var messengers: Array = [
				"a pigeon with the confidence of a tax collector",
				"a dusty courier who absolutely read the envelope first",
				"a monk who said he was only delivering it but was clearly invested",
				"a market scribe who yelled, 'OOOOH, somebody likes somebody!'"
			]
			return "You wrote a letter to %s. After passing through %s, it reached %s, a %s from %s. They read it twice, pretended they did not smile, then started writing back in hopes to connect." % [
				target_name,
				str(messengers [int(rng.randi_range(0, messengers.size() - 1))]),
				candidate_name,
				class_text,
				from_text
			]
		"public_statement":
			var channels: Array = [
				"the local papers",
				"a radio mention that somehow became gossip",
				"a public notice board full of nosy citizens",
				"a social feed post that escaped containment"
			]
			return "You made a public statement in %s. It traveled through %s and reached %s, a %s from %s. They made a public statement back, trying to sound casual while clearly being curious about you." % [
				target_name,
				str(channels [int(rng.randi_range(0, channels.size() - 1))]),
				candidate_name,
				class_text,
				from_text
			]
		"future_signal":
			var systems: Array = [
				"a civic romance lattice",
				"a reputation-matching satellite",
				"a privacy-violating but weirdly accurate affection algorithm",
				"a neon social relay that blinked like it knew too much"
			]
			return "You released a future-era romance signal toward %s. It moved through %s and matched with %s, a %s from %s. Their response packet came back warm, curious, and just suspiciously poetic enough to be dangerous." % [
				target_name,
				str(systems [int(rng.randi_range(0, systems.size() - 1))]),
				candidate_name,
				class_text,
				from_text
			]

	return "%s from %s answered your romance contract." % [candidate_name, target_name]


func _failed_outreach_text(_actor: Person, target_name: String, _preference_gender: String, channel: String, _importance: int, rng: RandomNumberGenerator) -> String:
	var target_text: String = _romance_target_sentence_name_from_text(target_name)

	match channel:
		"letter":
			var failures: Array = [
				"You wrote a letter to %s. Nobody returned it. Somewhere, a courier shrugged so hard history forgot him.",
				"You wrote a letter to %s. It reached somebody, but they ripped it up because they thought it was a tax notice with feelings.",
				"You wrote a letter to %s. A palace guard read your name, squinted, and filed it under 'mysterious commoner behavior.'",
				"You wrote a letter to %s. A goose stole it. Not metaphorically. A real goose chose violence."
			]
			return str(failures [int(rng.randi_range(0, failures.size() - 1))]) % target_text
		"public_statement":
			var public_failures: Array = [
				"You made a public statement in %s, but it went unheard. The crowd moved on like you had announced a weather update.",
				"You made a public statement in %s. A few people noticed, then immediately argued about bread prices instead.",
				"You made a public statement in %s. It reached the public, technically, but not the romantic public. Tragic paperwork energy.",
				"You made a public statement in %s. Somebody reposted it with the caption 'who is this?' and that was spiritually devastating."
			]
			return str(public_failures [int(rng.randi_range(0, public_failures.size() - 1))]) % target_text
		"future_signal":
			var future_failures: Array = [
				"You sent a future-era romance signal toward %s. The algorithm marked it as low-priority yearning.",
				"You sent a future-era romance signal toward %s. It bounced through three satellites and came back with a polite error code.",
				"You sent a future-era romance signal toward %s. Somebody's dating firewall blocked it with unnecessary disrespect."
			]
			return str(future_failures [int(rng.randi_range(0, future_failures.size() - 1))]) % target_text

	return "Your message toward %s did not reach anyone." % target_text
func _foreign_romance_outcome_diary_text(_actor: Person, candidate: Person, entry: Dictionary, channel: String, success: bool, rng: RandomNumberGenerator) -> String:
	var target_text: String = _romance_target_sentence_name(entry)

	if not success:
		match channel:
			"letter":
				return "Nobody answered my letter from %s." % target_text
			"public_statement":
				return "My public statement in %s did not reach anyone romantically." % target_text
			"future_signal":
				return "My romance signal toward %s did not find a match." % target_text
			_:
				return "Nobody answered me from %s." % target_text

	if candidate == null:
		return "Someone from %s answered me, but the romance contract could not resolve who they were." % target_text

	var display_location: Dictionary = _candidate_romance_display_location(candidate, entry, rng)
	var city_text: String = str(display_location.get("city", _entry_city(entry)))
	var country_text: String = str(display_location.get("country", _entry_country(entry)))
	var from_text: String = city_text
	if country_text != "":
		from_text = "%s, %s" % [city_text, country_text]

	match channel:
		"letter":
			return "%s answered my letter from %s. They are a %s from %s, and they started writing back in hopes to connect." % [
				_person_name(candidate),
				target_text,
				str(candidate.social_class).to_lower(),
				from_text
			]
		"public_statement":
			return "%s answered my public statement from %s. They are a %s from %s, and they seemed curious about me." % [
				_person_name(candidate),
				target_text,
				str(candidate.social_class).to_lower(),
				from_text
			]
		"future_signal":
			return "%s matched with my romance signal from %s. They are a %s from %s, and their response felt warm and curious." % [
				_person_name(candidate),
				target_text,
				str(candidate.social_class).to_lower(),
				from_text
			]

	return "%s from %s answered me." % [_person_name(candidate), target_text]


func _foreign_romance_outcome_world_text(actor: Person, candidate: Person, entry: Dictionary, channel: String, success: bool, rng: RandomNumberGenerator) -> String:
	var actor_name: String = _person_name(actor)
	var target_text: String = _romance_target_sentence_name(entry)

	if not success:
		match channel:
			"letter":
				return "%s sent a letter to %s hoping to find romance, but nobody answered." % [actor_name, target_text]
			"public_statement":
				return "%s made a public romantic statement in %s, but nobody answered." % [actor_name, target_text]
			"future_signal":
				return "%s sent a future-era romance signal toward %s, but it did not find a match." % [actor_name, target_text]
			_:
				return "%s tried to find a date in %s, but nobody answered." % [actor_name, target_text]

	if candidate == null:
		return "%s received a romance response from %s." % [actor_name, target_text]

	var display_location: Dictionary = _candidate_romance_display_location(candidate, entry, rng)
	var city_text: String = str(display_location.get("city", _entry_city(entry)))
	var country_text: String = str(display_location.get("country", _entry_country(entry)))
	var from_text: String = city_text
	if country_text != "":
		from_text = "%s, %s" % [city_text, country_text]

	return "%s received a romance response from %s, a %s from %s." % [
		actor_name,
		_person_name(candidate),
		str(candidate.social_class).to_lower(),
		from_text
	]


func _foreign_romance_relationship_label(_candidate: Person) -> String:
	return "writing fling"


func _foreign_romance_accept_popup_text(_actor: Person, candidate: Person, relationship_label: String) -> String:
	return "%s wrote back. You and %s are now long-distance %ss, and %s is still living in %s, %s." % [
		_person_name(candidate),
		str(candidate.first_name),
		relationship_label,
		str(candidate.first_name),
		str(candidate.home_city),
		str(candidate.home_country)
	]


func _foreign_romance_accept_diary_text(_actor: Person, candidate: Person, relationship_label: String) -> String:
	return "%s wrote back. We are now long-distance %ss, and %s is still living in %s, %s." % [
		_person_name(candidate),
		relationship_label,
		str(candidate.first_name),
		str(candidate.home_city),
		str(candidate.home_country)
	]


func _foreign_romance_accept_world_text(actor: Person, candidate: Person, relationship_label: String) -> String:
	return "%s and %s became long-distance %ss while living in different countries." % [
		_person_name(actor),
		_person_name(candidate),
		relationship_label
	]
func _register_foreign_romance_fling(actor: Person, candidate: Person, contract_id: String, contract: Dictionary) -> void:
	if gs == null or actor == null or candidate == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var ids: Array = gs.scenario_state.get("foreign_romance_fling_ids", []) if typeof(gs.scenario_state.get("foreign_romance_fling_ids", [])) == TYPE_ARRAY else []
	if not ids.has(int(candidate.id)):
		ids.append(int(candidate.id))

	var contract_rows: Dictionary = _safe_dictionary(gs.scenario_state.get("foreign_romance_fling_contracts", {}))
	contract_rows [str(candidate.id)] = {
		"contract_id": contract_id,
		"actor_id": int(actor.id),
		"candidate_id": int(candidate.id),
		"candidate_name": _person_name(candidate),
		"city": str(candidate.home_city),
		"country": str(candidate.home_country),
		"year": _current_year(),
		"relationship_type": "foreign_writing_fling",
		"relationship_label": "Writing Fling",
		"long_distance": true,
		"contract": _make_binary_safe(contract)
	}

	gs.scenario_state ["foreign_romance_fling_ids"] = ids
	gs.scenario_state ["foreign_romance_fling_contracts"] = contract_rows


func get_foreign_romance_fling_rows(_context: Dictionary = {}) -> Array:
	if gs == null or gs.player == null:
		return []

	var ids: Array = []
	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		ids = gs.scenario_state.get("foreign_romance_fling_ids", []) if typeof(gs.scenario_state.get("foreign_romance_fling_ids", [])) == TYPE_ARRAY else []

	var out: Array = []
	var seen: Dictionary = {}

	for raw_id in ids:
		var person_id: int = int(raw_id)
		if person_id <= 0 or seen.has(person_id):
			continue
		seen [person_id] = true

		var person: Person = _get_person_by_id(person_id)
		if person == null:
			continue

		out.append({
			"label": "%s %s" % [str(person.first_name), str(person.last_name)],
			"description": "Long-distance writing fling from %s, %s. Affection: %d/100." % [
				str(person.home_city),
				str(person.home_country),
				int(person.affection.get(int(gs.player.id), 50))
			],
			"kind": "relationship_fling",
			"relationship_type": "foreign_writing_fling",
			"person_id": int(person.id)
		})

	return out
func _build_person_card(actor: Person, candidate: Person, entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var affection_value: int = int(clamp(52 + int(rng.randi_range(0, 32)) + int(float(_actor_importance_score(actor)) / 8.0), 0, 100))
	var distance_pull: int = int(clamp(35 + int(float(candidate.looks) / 4.0) + int(float(actor.fame) / 6.0) + int(rng.randi_range(0, 22)), 0, 100))
	var display_location: Dictionary = _candidate_romance_display_location(candidate, entry, rng)
	var personality_type: String = _candidate_personality_type_for_entry(candidate, entry)
	var personality_description: String = _candidate_personality_description_for_entry(candidate, entry)

	candidate.affection [int(actor.id)] = max(int(candidate.affection.get(int(actor.id), 50)), affection_value)

	return {
		"npc_id": int(candidate.id),
		"name": _person_name(candidate),
		"first_name": str(candidate.first_name),
		"last_name": str(candidate.last_name),
		"gender": str(candidate.gender),
		"age": int(candidate.age),
		"city": str(display_location.get("city", _entry_city(entry))),
		"country": str(display_location.get("country", _entry_country(entry))),
		"social_class": str(candidate.social_class),
		"job": str(candidate.job),
		"personality_type": personality_type,
		"personality_description": personality_description,
		"background": _candidate_background(candidate, entry),
		"stats": {
			"Looks": int(clamp(int(candidate.looks), 0, 100)),
			"Health": int(clamp(int(candidate.health), 0, 100)),
			"Mental Health": int(clamp(int(candidate.mental_health), 0, 100)),
			"Fame": int(clamp(int(candidate.fame), 0, 100)),
			"Affection": affection_value,
			"Distance Pull": distance_pull
		}
	}
func _candidate_background(candidate: Person, entry: Dictionary) -> String:
	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed("romance_background_location|%s|%s|%s" % [
		str(candidate.id if candidate != null else 0),
		_entry_country(entry),
		str(_current_year())
	])

	var display_location: Dictionary = _candidate_romance_display_location(candidate, entry, rng)
	var city_text: String = str(display_location.get("city", _entry_city(entry)))
	var country_text: String = str(display_location.get("country", _entry_country(entry)))
	var job_text: String = str(candidate.job).strip_edges()

	var work_sentence: String = "Their work is currently unknown."
	if job_text != "":
		work_sentence = "They work as %s %s." % [_romance_indefinite_article(job_text), job_text.to_lower()]

	return "%s lives in %s, %s and belongs to the %s class. %s" % [
		str(candidate.first_name),
		city_text,
		country_text,
		str(candidate.social_class),
		work_sentence
	]
func _romance_indefinite_article(text: String) -> String:
	var clean: String = str(text).strip_edges().to_lower()
	if clean == "":
		return "a"
	var first_letter: String = clean.substr(0, 1)
	if first_letter in ["a", "e", "i", "o", "u"]:
		return "an"
	return "a"


func _romance_is_generic_realm_location_text(text: String) -> bool:
	var clean: String = str(text).strip_edges()
	var lower: String = clean.to_lower()

	if clean == "":
		return true
	if lower in ["unknown city", "unknown country", "that place", "frontier realm", "frontier realm capital", "realm capital", "frontier capital"]:
		return true
	if lower.begins_with("frontier realm"):
		return true
	if lower.find("frontier realm") >= 0:
		return true
	if lower.find("frontier") >= 0 and lower.find("realm") >= 0:
		return true
	if lower.find("realm capital") >= 0 and lower.find("frontier") >= 0:
		return true

	return false
func _romance_target_sentence_name(entry: Dictionary) -> String:
	return _romance_target_sentence_name_from_text(_entry_display_name(entry))


func _romance_target_sentence_name_from_text(target_name: String) -> String:
	var clean: String = str(target_name).strip_edges()
	if clean == "":
		return "that place"

	var lower: String = clean.to_lower()
	if lower.begins_with("the "):
		return "the %s" % clean.substr(4).strip_edges()

	if _romance_target_needs_definite_article(clean):
		return "the %s" % clean

	return clean


func _romance_target_needs_definite_article(target_name: String) -> bool:
	var clean: String = str(target_name).strip_edges()
	if clean == "":
		return false

	var lower: String = clean.to_lower()
	if lower.begins_with("the "):
		return true

	var exact_targets: Array = [
		"earth kingdom",
		"fire nation",
		"water tribe",
		"water nation",
		"northern water tribe",
		"southern water tribe",
		"northern air temple",
		"southern air temple",
		"eastern air temple",
		"western air temple",
		"air temples",
		"air nomads",
		"maurya empire",
		"kingdom of aksum",
		"kingdom of askum",
		"united states",
		"united kingdom",
		"netherlands",
		"philippines",
		"maldives"
	]

	if lower in exact_targets:
		return true

	var article_markers: Array = [
		" kingdom",
		" empire",
		" nation",
		" republic",
		" dynasty",
		" temple",
		" temples",
		" tribe",
		" tribes",
		" confederation",
		" federation",
		" state",
		" states",
		" realm",
		" caliphate",
		" sultanate",
		" duchy"
	]

	for marker in article_markers:
		if lower.find(str(marker)) >= 0:
			return true

	var starting_markers: Array = [
		"kingdom of ",
		"empire of ",
		"republic of ",
		"state of ",
		"states of ",
		"realm of ",
		"duchy of ",
		"sultanate of ",
		"caliphate of "
	]

	for marker in starting_markers:
		if lower.begins_with(str(marker)):
			return true

	return false


func _candidate_personality_type_for_entry(_candidate: Person, entry: Dictionary) -> String:
	var elemental_identity: Dictionary = _romance_element_identity_for_entry(entry)
	return str(elemental_identity.get("personality_type", "")).strip_edges()


func _candidate_personality_description_for_entry(_candidate: Person, entry: Dictionary) -> String:
	var elemental_identity: Dictionary = _romance_element_identity_for_entry(entry)
	return str(elemental_identity.get("personality_description", "")).strip_edges()


func _romance_element_identity_for_entry(entry: Dictionary) -> Dictionary:
	var target_country: String = _entry_country(entry)
	var target_name: String = _entry_display_name(entry)
	var combined: String = ("%s %s" % [target_country, target_name]).strip_edges().to_lower()
	var element: String = ""

	if combined.find("air temple") >= 0 or combined.find("air nomad") >= 0 or combined.find("air nation") >= 0:
		element = "air"
	elif combined.find("earth kingdom") >= 0 or combined.find("earth nation") >= 0:
		element = "earth"
	elif combined.find("fire nation") >= 0:
		element = "fire"
	elif combined.find("water tribe") >= 0 or combined.find("water nation") >= 0:
		element = "water"

	if element == "":
		return {}

	var profile: Dictionary = _romance_element_personality_profile(element)
	return {
		"is_elemental": true,
		"element": element,
		"nation": target_country,
		"personality_type": str(profile.get("name", "")),
		"personality_description": str(profile.get("description", ""))
	}


func _romance_element_personality_profile(element: String) -> Dictionary:
	var clean_element: String = str(element).strip_edges().to_lower()

	match clean_element:
		"fire":
			return {
				"id": "fire",
				"name": "Aggressive Growth",
				"description": "Fire personalities build fast, react hard under pressure, and can become intense when their emotions are not disciplined."
			}
		"water":
			return {
				"id": "water",
				"name": "Adaptive Flow",
				"description": "Water personalities adjust through emotion, recovery, guidance, and social rhythm."
			}
		"earth":
			return {
				"id": "earth",
				"name": "Slow Power",
				"description": "Earth personalities are grounded, stubborn, slower to open up, and frighteningly steady once trust is built."
			}
		"air":
			return {
				"id": "air",
				"name": "Technical Evasion",
				"description": "Air personalities are rhythmic, evasive, thoughtful, and difficult to emotionally corner."
			}

	return {
		"id": clean_element,
		"name": "",
		"description": ""
	}
func _preference_to_gender(preference: String) -> String:
	var clean: String = str(preference).strip_edges().to_lower()
	if clean in ["man", "men", "male", "boyfriend"]:
		return "Male"
	if clean in ["woman", "women", "female", "girlfriend"]:
		return "Female"
	return ""


func _romance_channel_for_era(era_name: String) -> String:
	var lower: String = str(era_name).strip_edges().to_lower()
	if lower.find("ancient") >= 0 or lower.find("medieval") >= 0:
		return "letter"
	if lower.find("future") >= 0:
		return "future_signal"
	return "public_statement"


func _channel_title(channel: String) -> String:
	match channel:
		"letter":
			return "A Letter Across the Realm"
		"public_statement":
			return "A Public Statement Was Heard"
		"future_signal":
			return "Future Romance Signal"
		_:
			return "Romance Contract"
func _romance_safe_int(value: Variant, fallback: int = 0) -> int:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			var float_value: float = float(value)
			if is_nan(float_value) or is_inf(float_value):
				return fallback
			return int(float_value)
		TYPE_BOOL:
			return 1 if bool(value) else 0
		TYPE_STRING:
			var clean: String = str(value).strip_edges()
			if clean == "":
				return fallback
			if clean.is_valid_int():
				return int(clean)
			if clean.is_valid_float():
				return int(float(clean))
			return fallback
		_:
			return fallback


func _person_int_field(person: Person, field_name: String, fallback: int = 0) -> int:
	if person == null:
		return fallback

	var clean_field: String = str(field_name).strip_edges()
	if clean_field == "":
		return fallback

	var raw_value: Variant = person.get(clean_field)
	return _romance_safe_int(raw_value, fallback)

func _actor_importance_score(actor: Person) -> int:
	if actor == null:
		return 0

	var score: int = int(clamp(_person_int_field(actor, "fame", 0), 0, 100))

	if bool(actor.is_ruler):
		score += 45
	elif bool(actor.is_royal):
		score += 34

	match str(actor.social_class):
		"Royal":
			score += 30
		"Noble":
			score += 22
		"Merchant":
			score += 10
		"Commoner":
			score += 4
		"Peasant":
			score -= 6
		"Slave":
			score -= 14

	var infamy_value: int = _person_int_field(actor, "infamy", 0)
	score += int(float(clamp(infamy_value, 0, 100)) / 2.0)

	return int(clamp(score, 0, 100))

func _target_social_class(actor: Person, rng: RandomNumberGenerator) -> String:
	var actor_class: String = str(actor.social_class if actor != null else "Commoner")
	var roll: int = int(rng.randi_range(1, 100))

	match actor_class:
		"Royal":
			if roll <= 55:
				return "Royal"
			if roll <= 82:
				return "Noble"
			return "Merchant"
		"Noble":
			if roll <= 35:
				return "Noble"
			if roll <= 75:
				return "Merchant"
			return "Commoner"
		"Merchant":
			if roll <= 25:
				return "Noble"
			if roll <= 70:
				return "Merchant"
			return "Commoner"
		"Peasant":
			if roll <= 65:
				return "Peasant"
			if roll <= 92:
				return "Commoner"
			return "Merchant"
		"Slave":
			if roll <= 72:
				return "Slave"
			if roll <= 92:
				return "Peasant"
			return "Commoner"
		_:
			if roll <= 70:
				return "Commoner"
			if roll <= 88:
				return "Merchant"
			if roll <= 97:
				return "Noble"
			return "Royal"


func _similar_age(actor: Person, rng: RandomNumberGenerator) -> int:
	var base_age: int = int(actor.age if actor != null else 22)
	var min_age: int = max(16, base_age - 5)
	var max_age: int = max(min_age, base_age + 7)
	return int(rng.randi_range(min_age, max_age))


func _candidate_fame_from_class(social_class: String, rng: RandomNumberGenerator) -> int:
	match str(social_class):
		"Royal":
			return int(rng.randi_range(35, 82))
		"Noble":
			return int(rng.randi_range(18, 58))
		"Merchant":
			return int(rng.randi_range(4, 38))
		_:
			return int(rng.randi_range(0, 24))


func _fame_tier_for_value(value: int) -> String:
	if value >= 85:
		return "Legend"
	if value >= 65:
		return "Global"
	if value >= 45:
		return "National"
	if value >= 20:
		return "Local"
	return "None"


func _candidate_job_for_era_and_class(era_name: String, social_class: String, rng: RandomNumberGenerator) -> String:
	var lower: String = str(era_name).strip_edges().to_lower()
	var pool: Array = []

	if lower.find("ancient") >= 0:
		pool = ["Scribe", "Temple Attendant", "Merchant", "Guard", "Weaver", "Noble Courtier"]
	elif lower.find("medieval") >= 0:
		pool = ["Apprentice", "Court Servant", "Knight's Attendant", "Scribe", "Baker", "Noble Courtier"]
	elif lower.find("industrial") >= 0:
		pool = ["Factory Worker", "Rail Clerk", "Seamstress", "Shopkeeper", "Newspaper Assistant", "Heiress"]
	elif lower.find("future") >= 0:
		pool = ["Signal Curator", "Arcology Medic", "Drone Mechanic", "Algorithm Auditor", "Memory Designer", "Civic Diplomat"]
	else:
		pool = ["Student", "Barista", "Teacher", "Retail Worker", "Artist", "Office Assistant"]

	if social_class == "Royal":
		return "Royal Household Member"
	if social_class == "Noble" and rng.randi_range(1, 100) <= 55:
		return "Court Noble"

	return str(pool [int(rng.randi_range(0, pool.size() - 1))])


func _candidate_traits(rng: RandomNumberGenerator) -> Array:
	var pool: Array = ["Kind", "Charming", "Curious", "Loyal", "Funny", "Ambitious", "Reserved", "Romantic"]
	var out: Array = []
	while out.size() < 3 and not pool.is_empty():
		var index: int = int(rng.randi_range(0, pool.size() - 1))
		out.append(pool [index])
		pool.remove_at(index)
	return out


func _random_first_name(gender: String, era_name: String, rng: RandomNumberGenerator) -> String:
	if gs != null and gs.names_db != null and gs.names_db.has_method("random_first_for_era"):
		return str(gs.names_db.random_first_for_era(gender, era_name))
	var male_names: Array = ["Alden", "Cassian", "Darian", "Theo", "Marcus", "Rowan"]
	var female_names: Array = ["Mira", "Elena", "Nadia", "Seraphine", "Amara", "Lyra"]
	var pool: Array = male_names if gender == "Male" else female_names
	return str(pool [int(rng.randi_range(0, pool.size() - 1))])


func _random_last_name(city: String, country: String, era_name: String, rng: RandomNumberGenerator) -> String:
	if gs != null and gs.names_db != null and gs.names_db.has_method("last_name_for_birthplace"):
		return str(gs.names_db.last_name_for_birthplace(era_name, city, country))
	var fallback: Array = ["Vale", "Ashford", "Stone", "Rivera", "Moon", "Dawn"]
	return str(fallback [int(rng.randi_range(0, fallback.size() - 1))])


func _entry_display_name(entry: Dictionary) -> String:
	return str(entry.get("name", entry.get("entry_id", "that place"))).strip_edges()


func _entry_country(entry: Dictionary) -> String:
	for key in ["romance_target_country", "selected_country", "target_country", "country", "realm_country", "nation", "label", "display_name", "name"]:
		var entry_value: String = str(entry.get(key, "")).strip_edges()
		if entry_value != "" and not _romance_is_generic_realm_location_text(entry_value):
			return entry_value

	var entry_name: String = _entry_display_name(entry)
	if entry_name != "" and not _romance_is_generic_realm_location_text(entry_name):
		return entry_name

	var realm: Dictionary = _safe_dictionary(entry.get("realm", {}))
	for key in ["country", "realm_country", "nation", "label", "display_name", "name"]:
		var realm_value: String = str(realm.get(key, "")).strip_edges()
		if realm_value != "" and not _romance_is_generic_realm_location_text(realm_value):
			return realm_value

	return "Unknown Country"


func _entry_city(entry: Dictionary) -> String:
	for key in ["romance_target_city", "selected_city", "target_city", "city", "capital", "home_city", "primary_city"]:
		var entry_value: String = str(entry.get(key, "")).strip_edges()
		if entry_value != "" and not _romance_is_generic_realm_location_text(entry_value):
			return entry_value

	var target_country: String = _entry_country(entry)
	var realm: Dictionary = _safe_dictionary(entry.get("realm", {}))

	for key in ["capital", "capital_city", "city", "home_city", "primary_city"]:
		var realm_value: String = str(realm.get(key, "")).strip_edges()
		if realm_value != "" and not _romance_is_generic_realm_location_text(realm_value):
			return realm_value

	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed("romance_city|%s|%s|%s" % [
		target_country,
		_current_era_name(),
		str(_current_year())
	])
	return _fallback_romance_city_for_country(target_country, rng)
func _normalize_romance_target_entry(entry: Dictionary) -> Dictionary:
	var out: Dictionary = entry.duplicate(true)
	var rng:= RandomNumberGenerator.new()
	rng.seed = _stable_seed("normalize_romance_target_entry|%s|%s|%s" % [
		str(out.get("entry_id", "")),
		str(out.get("name", "")),
		str(_current_year())
	])

	var location: Dictionary = _romance_target_location(out, rng)
	var target_country: String = str(location.get("country", "")).strip_edges()
	var target_city: String = str(location.get("city", "")).strip_edges()

	if target_country != "":
		out ["romance_target_country"] = target_country
		out ["target_country"] = target_country
		out ["country"] = target_country

	if target_city != "":
		out ["romance_target_city"] = target_city
		out ["target_city"] = target_city
		out ["city"] = target_city

	var realm: Dictionary = _safe_dictionary(out.get("realm", {}))
	if not realm.is_empty():
		if target_country != "":
			realm ["country"] = target_country
			realm ["realm_country"] = target_country
			realm ["nation"] = target_country
		if target_city != "":
			realm ["capital"] = target_city
			realm ["capital_city"] = target_city
			realm ["primary_city"] = target_city
		out ["realm"] = realm

	return out


func _romance_target_location(entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var target_country: String = _entry_country(entry)
	var target_city: String = _entry_city_without_country_fallback(entry)

	if target_city == "" or _romance_is_generic_realm_location_text(target_city):
		target_city = _fallback_romance_city_for_country(target_country, rng)

	if target_country == "" or _romance_is_generic_realm_location_text(target_country):
		target_country = "Unknown Country"

	if target_city == "" or _romance_is_generic_realm_location_text(target_city):
		target_city = "Unknown City"

	return {
		"city": target_city,
		"country": target_country
	}


func _entry_city_without_country_fallback(entry: Dictionary) -> String:
	for key in ["romance_target_city", "selected_city", "target_city", "city", "capital", "home_city", "primary_city"]:
		var entry_value: String = str(entry.get(key, "")).strip_edges()
		if entry_value != "" and not _romance_is_generic_realm_location_text(entry_value):
			return entry_value

	var realm: Dictionary = _safe_dictionary(entry.get("realm", {}))
	for key in ["capital", "capital_city", "city", "home_city", "primary_city"]:
		var realm_value: String = str(realm.get(key, "")).strip_edges()
		if realm_value != "" and not _romance_is_generic_realm_location_text(realm_value):
			return realm_value

	return ""


func _candidate_romance_display_location(candidate: Person, entry: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var target_location: Dictionary = _romance_target_location(entry, rng)
	var target_city: String = str(target_location.get("city", _entry_city(entry))).strip_edges()
	var target_country: String = str(target_location.get("country", _entry_country(entry))).strip_edges()
	var candidate_city: String = str(candidate.home_city if candidate != null else "").strip_edges()
	var candidate_country: String = str(candidate.home_country if candidate != null else "").strip_edges()

	if candidate_country == "" or _romance_is_generic_realm_location_text(candidate_country) or candidate_country != target_country:
		candidate_country = target_country

	if candidate_city == "" or _romance_is_generic_realm_location_text(candidate_city):
		candidate_city = target_city

	if candidate_city == "" or _romance_is_generic_realm_location_text(candidate_city):
		candidate_city = target_city

	return {
		"city": candidate_city,
		"country": candidate_country
	}


func _repair_foreign_romance_candidate_location(candidate: Person, entry: Dictionary, rng: RandomNumberGenerator) -> void:
	if candidate == null:
		return

	var display_location: Dictionary = _candidate_romance_display_location(candidate, entry, rng)
	var target_city: String = str(display_location.get("city", _entry_city(entry))).strip_edges()
	var target_country: String = str(display_location.get("country", _entry_country(entry))).strip_edges()

	if target_city != "":
		candidate.home_city = target_city
		candidate.birth_city = target_city

	if target_country != "":
		candidate.home_country = target_country
		candidate.birth_country = target_country
func _fallback_romance_city_for_country(country: String, rng: RandomNumberGenerator) -> String:
	var clean_country: String = str(country).strip_edges()
	var lower: String = clean_country.to_lower()
	var pool: Array = []

	if lower.find("earth kingdom") >= 0:
		pool = ["Ba Sing Se", "Omashu", "Zaofu", "Gaoling", "Makapu", "Taku"]
	elif lower.find("fire nation") >= 0:
		pool = ["Capital City", "Caldera City", "Ember Island", "Yu Dao", "Shu Jing", "Hari Bulkan"]
	elif lower.find("northern water tribe") >= 0:
		pool = ["Agna Qel'a", "Taku", "Ice Dock"]
	elif lower.find("southern water tribe") >= 0:
		pool = ["Wolf Cove", "Whaletail Harbor", "Glacier Camp"]
	elif lower.find("eastern air temple") >= 0:
		pool = ["Eastern Spires", "Eastern Sanctuary"]
	elif lower.find("western air temple") >= 0:
		pool = ["Western Cloisters", "Western Sanctuary"]
	elif lower.find("northern air temple") >= 0:
		pool = ["Northern Monastery", "Northern Sanctuary"]
	elif lower.find("southern air temple") >= 0:
		pool = ["Southern Monastery", "Southern Sanctuary"]
	elif lower.find("united states") >= 0 or lower == "usa":
		pool = ["New York", "Chicago", "Los Angeles", "Houston", "Atlanta", "Seattle"]
	elif lower.find("canada") >= 0:
		pool = ["Toronto", "Vancouver", "Montreal", "Calgary", "Ottawa"]
	elif lower.find("japan") >= 0:
		pool = ["Tokyo", "Kyoto", "Osaka", "Yokohama", "Sapporo"]
	elif lower.find("south korea") >= 0:
		pool = ["Seoul", "Busan", "Incheon", "Daegu"]
	elif lower.find("united kingdom") >= 0 or lower.find("england") >= 0:
		pool = ["London", "Manchester", "York", "Birmingham"]
	elif lower.find("egypt") >= 0:
		pool = ["Thebes", "Memphis", "Heliopolis", "Alexandria", "Abydos"]
	elif lower.find("france") >= 0:
		pool = ["Paris", "Lyon", "Marseille", "Bordeaux"]
	elif lower.find("germany") >= 0:
		pool = ["Berlin", "Munich", "Hamburg", "Cologne"]
	elif lower.find("china") >= 0:
		pool = ["Beijing", "Shanghai", "Xi'an", "Guangzhou"]
	elif lower.find("india") >= 0:
		pool = ["Delhi", "Mumbai", "Kolkata", "Jaipur"]

	if not pool.is_empty():
		return str(pool [int(rng.randi_range(0, pool.size() - 1))])

	if clean_country == "" or clean_country == "Unknown Country":
		return "Unknown City"

	return "%s Capital" % clean_country


func _target_country_key(entry: Dictionary) -> String:
	return _entry_country(entry).to_lower().replace(" ", "_").replace(",", "").replace(".", "")


func _person_country(person: Person) -> String:
	if person == null:
		return ""
	var home_country: String = str(person.home_country).strip_edges()
	if home_country != "":
		return home_country
	return str(person.birth_country).strip_edges()


func _person_name(person: Person) -> String:
	if person == null:
		return "Unknown Person"
	return ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()


func _get_person_by_id(person_id: int) -> Person:
	if person_id <= 0 or gs == null:
		return null
	if gs.has_method("get_or_reactivate_npc_by_id"):
		return gs.get_or_reactivate_npc_by_id(person_id)
	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)
	return null


func _actor_from_payload(payload: Dictionary) -> Person:
	if gs == null:
		return null
	var actor_id: int = int(payload.get("actor_id", payload.get("player_id", -1)))
	if actor_id > 0:
		return _get_person_by_id(actor_id)
	return gs.player


func _current_year() -> int:
	if gs == null:
		return 0
	if "year" in gs:
		return int(gs.year)
	if "scenario_state" in gs and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		return int(gs.scenario_state.get("year", 0))
	return 0


func _current_era_name() -> String:
	if gs == null:
		return "Modern Era"
	if gs.era != null:
		if typeof(gs.era) == TYPE_DICTIONARY:
			return str(gs.era.get("name", "Modern Era"))
		if "name" in gs.era:
			return str(gs.era.name)
	return "Modern Era"


func _failure_report(title: String, text: String) -> Dictionary:
	last_report = {
		"success": false,
		"popup_title": title,
		"popup_text": text,
		"text": text,
		"status_text": text,
		"can_accept": false
	}
	return last_report.duplicate(true)


func _stable_seed(material: String) -> int:
	var value: int = int(hash(str(material)))
	if value < 0:
		value = - value
	if value <= 0:
		value = 1
	return value


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for raw_key in (value as Dictionary).keys():
				out [raw_key] = _make_binary_safe((value as Dictionary).get(raw_key))
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for raw_item in (value as Array):
				arr.append(_make_binary_safe(raw_item))
			return arr
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL, TYPE_NIL:
			return value
		_:
			return str(value)