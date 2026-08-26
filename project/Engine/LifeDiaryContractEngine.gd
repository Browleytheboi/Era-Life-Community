extends Resource
class_name LifeDiaryContractEngine

signal diary_entry_committed(
	actor_id: int,
	delta_contract: Dictionary
)

const ENGINE_SCHEMA:= "eralife.life_diary_contract_engine"
const INTENT_SCHEMA:= "eralife.life_diary.intent"
const ENTRY_SCHEMA:= "eralife.life_diary.entry"
const STREAM_SCHEMA:= "eralife.life_diary.stream"
const CONTRACT_SCHEMA:= "eralife.life_diary.contract"
const CONTRACT_VERSION:= 1
const MAX_STREAM_PER_ACTOR:= 900
const MAX_REPAIR_LEDGER:= 96
const MAX_BRIDGE_LEDGER:= 120

var gs: GameState = null
var sequence: int = 0
var actor_streams: Dictionary = {}
var actor_dedupe_index: Dictionary = {}
var actor_signatures: Dictionary = {}
var bridge_ledger: Array = []
var repair_ledger: Array = []
var last_report: Dictionary = {}

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs, false)

func bind_game_state(_gs: GameState, publish_on_bind: bool = true) -> void:
	if gs == _gs:
		if publish_on_bind:
			_ensure_state()
			_publish_state("bind_game_state_same")
		return

	gs = _gs
	_ensure_state()
	_repair_all_streams("bind_game_state")
	if publish_on_bind:
		_publish_state("bind_game_state")

func bind_game_state_quiet(_gs: GameState) -> void:
	bind_game_state(_gs, false)

func contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"engine_id": "life_diary_contract_engine",
		"engine_schema": ENGINE_SCHEMA,
		"authority": "narrative_timeline",
		"save_slice": save_slice_contract(),
		"render_policy": {
			"ui_is_reader_only": true,
		},
		"created_at_ms": int(Time.get_ticks_msec())
	}

func save_slice_contract() -> Dictionary:
	return {
		"id": "life_diary_contract_engine_state",
		"save_key": "life_diary_contract_engine_state",
		"engine_id": "life_diary_contract_engine",
		"import_method": "import_state",
		"export_method": "export_state",
		"hydration_phase": "system_state",
		"required": false,
		"missing_engine_policy": "recover",
		"metadata": {
			"schema": CONTRACT_SCHEMA,
			"version": CONTRACT_VERSION,
			"source_of_truth": true,
			"legacy_bridge": true,
		}
	}

func emit_diary_intent(intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	return enqueue_intent(intent, context)

func enqueue_intent(
	intent: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var clean_intent: Dictionary = _normalize_intent(
		intent,
		context
	)

	if clean_intent.is_empty():
		return _report(
			false,
			"intent_rejected",
			{
				"reason": "empty_intent",
				"context": context.duplicate(true)
			}
		)

	var entry: Dictionary = _compile_intent_to_entry(
		clean_intent,
		context
	)

	if entry.is_empty():
		return _report(
			false,
			"intent_rejected",
			{
				"reason": "entry_compile_failed",
				"intent": clean_intent.duplicate(true)
			}
		)

	var report: Dictionary = _commit_entry(
		entry,
		clean_intent,
		context
	)

	_publish_state(
		str(
			report.get(
				"mode",
				"enqueue_intent"
			)
		)
	)

	if (
		bool(
			report.get(
				"success",
				false
			)
		)
		and bool(
			report.get(
				"committed",
				false
			)
		)
	):
		var actor_id: int = int(
			entry.get(
				"actor_id",
				-1
			)
		)

		if actor_id > 0:
			diary_entry_committed.emit(
				actor_id,
				{
					"schema": (
						"eralife.life_diary."
						+ "entry_delta_contract"
					),
					"version": CONTRACT_VERSION,
					"actor_id": actor_id,
					"entry_id": str(
						entry.get(
							"entry_id",
							""
						)
					),
					"year": int(
						entry.get(
							"year",
							_current_year()
						)
					),
					"age": int(
						entry.get(
							"age",
							0
						)
					),
					"lines": _safe_array(
						entry.get(
							"lines",
							[]
						)
					).duplicate(false),
					"signature": signature_for_actor(
						actor_id
					),
					"journal_continuation": bool(
						report.get(
							"journal_continuation",
							false
						)
					),
					"intent_type": str(
						clean_intent.get(
							"type",
							""
						)
					),
					"source": str(
						entry.get(
							"source",
							"unknown"
						)
					),
					"immutable": true,
					"ui_is_reader_only": true
				}
			)

	return report
func emit_legacy_text(text: String, meta: Dictionary = {}) -> Dictionary:
	var intent: Dictionary = {
		"schema": INTENT_SCHEMA,
		"version": CONTRACT_VERSION,
		"type": "legacy_text",
		"text": str(text),
		"meta": meta.duplicate(true),
		"source": str(meta.get("source", "legacy_diary_bridge"))
	}
	return enqueue_intent(intent, meta)

func emit_birth_intro_lines_for_actor(actor: Person, lines: Array, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return _report(false, "birth_intro_rejected", { "reason": "missing_actor", "context": context.duplicate(true)})

	var intent: Dictionary = {
		"schema": INTENT_SCHEMA,
		"version": CONTRACT_VERSION,
		"type": "birth_intro",
		"actor_id": int(actor.id),
		"actor_name": _person_display_name(actor),
		"lines": _safe_array(lines),
		"year": int(context.get("year", _current_year())),
		"age": int(context.get("age", int(actor.age))),
		"source": str(context.get("source", "birth_intro_bridge")),
		"dedupe_key": "birth_intro:%d" % int(actor.id),
		"preserve_lines_exactly": true,
		"meta": context.duplicate(true)
	}
	return enqueue_intent(intent, context)

func ensure_birth_intro_for_actor(
		actor: Person,
		context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _report(
			false,
			"birth_intro_rejected",
			{
				"reason": "missing_actor",
				"context": context.duplicate(true)
			}
		)

	var actor_id: int = int(
		actor.id
	)
	var canonical_context: Dictionary = (
		context.duplicate(false)
	)

	canonical_context [
		"birth_intro_contract_version"
	] = 2
	canonical_context [
		"birth_intro_family_format_version"
	] = 2
	canonical_context [
		"birth_intro_is_canonical_newborn_truth"
	] = true
	canonical_context [
		"birth_intro_applies_to_every_newborn"
	] = true
	canonical_context [
		"placeholder_birth_intro_forbidden"
	] = true

	var canonical_lines: Array = (
		compile_birth_intro_lines_for_actor(
			actor,
			canonical_context
		)
	)

	if canonical_lines.is_empty():
		return _report(
			false,
			"birth_intro_rejected",
			{
				"reason": (
					"canonical_birth_intro_compiled_empty"
				),
				"actor_id": actor_id,
				"context": (
					canonical_context.duplicate(true)
				)
			}
		)

	if _birth_intro_contract_is_complete_for_actor(
		actor_id
	):
		return _report(
			true,
			"birth_intro_already_present",
			{
				"actor_id": actor_id,
				"context": (
					canonical_context.duplicate(true)
				),
				"committed": false,
				"canonical": true,
				"birth_intro_contract_version": 2,
				"birth_intro_line_count": (
					canonical_lines.size()
				)
			}
		)

	var removed_entry_count: int = (
		_remove_birth_intro_entries_for_actor(
			actor_id
		)
	)

	canonical_context [
		"replaced_incomplete_birth_intro"
	] = removed_entry_count > 0
	canonical_context [
		"removed_incomplete_birth_intro_count"
	] = removed_entry_count

	var report: Dictionary = (
		emit_birth_intro_lines_for_actor(
			actor,
			canonical_lines,
			canonical_context
		)
	)

	report [
		"canonical"
	] = true
	report [
		"birth_intro_contract_version"
	] = 2
	report [
		"birth_intro_family_format_version"
	] = 2
	report [
		"birth_intro_line_count"
	] = canonical_lines.size()
	report [
		"replaced_incomplete_birth_intro"
	] = removed_entry_count > 0
	report [
		"removed_incomplete_birth_intro_count"
	] = removed_entry_count

	return report
func _birth_intro_contract_is_complete_for_actor(
		actor_id: int
) -> bool:
	var clean_actor_id: int = int(
		actor_id
	)

	if clean_actor_id <= 0:
		return false

	for raw_entry in _stream_for_actor(
		clean_actor_id
	):
		var entry: Dictionary = _safe_dictionary(
			raw_entry
		)
		var entry_type: String = str(
			entry.get(
				"type",
				""
			)
		).strip_edges().to_lower()
		var fingerprint: String = str(
			entry.get(
				"fingerprint",
				""
			)
		).strip_edges()

		if (
			entry_type != "birth_intro"
			and fingerprint != (
				"birth_intro:%d"
				% clean_actor_id
			)
		):
			continue

		var lines: Array = _safe_array(
			entry.get(
				"lines",
				[]
			)
		)
		var metadata: Dictionary = _safe_dictionary(
			entry.get(
				"meta",
				{}
			)
		)
		var contract_version: int = int(
			metadata.get(
				"birth_intro_contract_version",
				0
			)
		)
		var family_format_version: int = int(
			metadata.get(
				"birth_intro_family_format_version",
				0
			)
		)
		var contains_placeholder: bool = false

		for raw_line in lines:
			var line_text: String = str(
				raw_line
			).strip_edges().to_lower()

			if line_text in [
				"my life has begun.",
				"my life has begun",
				"life has begun.",
				"life has begun"
			]:
				contains_placeholder = true
				break

		return (
			not contains_placeholder
			and contract_version >= 2
			and family_format_version >= 2
			and lines.size() >= 5
		)

	return false


func _remove_birth_intro_entries_for_actor(
		actor_id: int
) -> int:
	var clean_actor_id: int = int(
		actor_id
	)

	if clean_actor_id <= 0:
		return 0

	var actor_key: String = str(
		clean_actor_id
	)
	var stream: Array = _stream_for_actor(
		clean_actor_id
	)
	var retained: Array = []
	var removed_count: int = 0

	for raw_entry in stream:
		var entry: Dictionary = _safe_dictionary(
			raw_entry
		)
		var entry_type: String = str(
			entry.get(
				"type",
				""
			)
		).strip_edges().to_lower()
		var fingerprint: String = str(
			entry.get(
				"fingerprint",
				""
			)
		).strip_edges()
		var remove_entry: bool = (
			entry_type == "birth_intro"
			or fingerprint == (
				"birth_intro:%d"
				% clean_actor_id
			)
		)

		if remove_entry:
			removed_count += 1
			continue

		retained.append(
			entry
		)

	actor_streams [
		actor_key
	] = retained

	_rebuild_dedupe_for_actor(
		clean_actor_id
	)

	actor_signatures [
		actor_key
	] = signature_for_actor(
		clean_actor_id
	)

	return removed_count
func append_legacy_entries_for_actor(actor_id: int, entries: Array, context: Dictionary = {}) -> Dictionary:
	var clean_actor_id: int = int(actor_id)
	if clean_actor_id <= 0:
		return _report(false, "legacy_entries_rejected", { "reason": "missing_actor_id"})

	var committed: int = 0
	var duplicates: int = 0
	for raw_entry in entries:
		var entry_lines: Array = _safe_array(raw_entry)
		if entry_lines.is_empty():
			continue
		var report: Dictionary = enqueue_intent({
			"schema": INTENT_SCHEMA,
			"version": CONTRACT_VERSION,
			"type": "legacy_entry",
			"actor_id": clean_actor_id,
			"lines": entry_lines.duplicate(true),
			"source": str(context.get("source", "legacy_state_hydration")),
			"preserve_lines_exactly": true,
			"meta": context.duplicate(true)
		}, context)
		if bool(report.get("duplicate", false)):
			duplicates += 1
		elif bool(report.get("committed", false)):
			committed += 1

	return _report(true, "legacy_entries_ingested", {
		"actor_id": clean_actor_id,
		"committed": committed,
		"duplicates": duplicates,
		"entry_count": _stream_for_actor(clean_actor_id).size()
	})

func compile_birth_intro_lines_for_actor(
		actor: Person,
		context: Dictionary = {}
) -> Array:
	if actor == null:
		return []

	var lines: Array = []
	var year_value: int = int(
		context.get(
			"year",
			_current_year()
		)
	)
	var age_value: int = int(
		context.get(
			"age",
			int(
				actor.age
			)
		)
	)
	var gender_text: String = str(
		actor.get(
			"gender"
		)
	).strip_edges().to_lower()

	if gender_text == "":
		gender_text = "person"

	var birth_city: String = str(
		actor.get(
			"birth_city"
		)
	).strip_edges()
	var birth_country: String = str(
		actor.get(
			"birth_country"
		)
	).strip_edges()

	if birth_city == "":
		birth_city = str(
			actor.get(
				"home_city"
			)
		).strip_edges()

	if birth_country == "":
		birth_country = str(
			actor.get(
				"home_country"
			)
		).strip_edges()

	if birth_city == "":
		birth_city = "an unknown city"

	if birth_country == "":
		birth_country = "an unknown nation"

	lines.append(
		"Year: %s"
		% _format_year_value(
			year_value
		)
	)
	lines.append(
		"Age: %d"
		% age_value
	)

	var narrative_contract: Dictionary = {}

	if (
		gs != null
		and gs.era_contract_engine != null
		and gs.era_contract_engine.has_method(
			"birth_narrative_contract"
		)
	):
		narrative_contract = (
			gs.era_contract_engine
			.birth_narrative_contract(
				actor,
				{
					"event_id": "birth_intro",
					"year": year_value,
					"age": age_value,
					"actor_id": int(
						actor.id
					),
					"source": (
						"life_diary_contract_engine."
						+ "compile_birth_intro"
					)
				}
			)
		)

	var replace_birth_body: bool = bool(
		narrative_contract.get(
			"replace_birth_body",
			false
		)
	)

	if replace_birth_body:
		var headline: String = str(
			narrative_contract.get(
				"headline",
				""
			)
		).strip_edges()

		if headline != "":
			lines.append(
				headline
			)

		for raw_line in _safe_array(
			narrative_contract.get(
				"lines",
				[]
			)
		):
			var narrative_line: String = str(
				raw_line
			).strip_edges()

			if narrative_line != "":
				lines.append(
					narrative_line
				)
	else:
		var conception_story: String = ""

		if (
			gs != null
			and gs.era_engine != null
			and gs.era_engine.has_method(
				"get_conception_story"
			)
		):
			conception_story = str(
				gs.era_engine.get_conception_story(
					"",
					year_value,
					int(
						actor.id
					)
				)
			).strip_edges()

		if conception_story != "":
			lines.append(
				conception_story
			)

		lines.append(
			"I was born in %s."
			% _format_year_value(
				year_value
			)
		)
		lines.append(
			"I was born a %s in %s, %s."
			% [
				gender_text,
				birth_city,
				birth_country
			]
		)

	var birthday: Variant = actor.get(
		"birthday"
	)
	var month_value: int = 0
	var day_value: int = 0

	if typeof(
		birthday
	) == TYPE_DICTIONARY:
		month_value = int(
			(
				birthday as Dictionary
			).get(
				"month",
				0
			)
		)
		day_value = int(
			(
				birthday as Dictionary
			).get(
				"day",
				0
			)
		)
	elif birthday != null:
		month_value = int(
			birthday.get(
				"month"
			)
		)
		day_value = int(
			birthday.get(
				"day"
			)
		)

	var zodiac_text: String = str(
		actor.get(
			"zodiac"
		)
	).strip_edges()

	if (
		month_value > 0
		and day_value > 0
	):
		if zodiac_text != "":
			lines.append(
				"My birthday is %s %d. I am a %s."
				% [
					_month_name(
						month_value
					),
					day_value,
					zodiac_text
				]
			)
		else:
			lines.append(
				"My birthday is %s %d."
				% [
					_month_name(
						month_value
					),
					day_value
				]
			)

	lines.append(
		"My name is %s."
		% _person_display_name(
			actor
		)
	)

	_append_parent_intro_lines(
		lines,
		actor
	)

	var bending_type: String = str(
		actor.get(
			"bending_type"
		)
	).strip_edges().to_lower()

	if (
		bending_type != ""
		and bending_type != "none"
	):
		if bending_type == "avatar":
			lines.append(
				(
					"My soul was chosen to become "
					+ "the next Avatar, Master of 4 Elements."
				)
			)
			lines.append(
				"My name is legendary across the world."
			)
			lines.append(
				"People everywhere know my name."
			)
		else:
			lines.append(
				"I was born with %s bending."
				% bending_type
			)

	return lines

func render_packet_for_actor(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	var actor_id: int = int(
		actor.id
	)

	var entries: Array = (
		diary_entries_for_actor(
			actor_id,
			context
		)
	)

	var historical_signature: String = (
		signature_for_actor(
			actor_id
		)
	)

	var current_world_year: int = (
		_current_year()
	)

	var current_actor_age: int = maxi(
		0,
		int(
			actor.age
		)
	)



	var year_line: String = _format_year_value(
		current_world_year
	)

	var age_line: String = (
		"Age: %d"
		% current_actor_age
	)

	var temporal_frontier_already_present: bool = false

	if not entries.is_empty():
		var last_raw: Variant = entries [
			entries.size() - 1
		]

		if typeof(last_raw) == TYPE_ARRAY:
			var last_entry: Array = (
				last_raw as Array
			)

			temporal_frontier_already_present = (
				last_entry.size() >= 2
				and str(
					last_entry [0]
				).strip_edges() == year_line
				and str(
					last_entry [1]
				).strip_edges() == age_line
			)

	var projected_temporal_frontier: bool = (
		not temporal_frontier_already_present
	)

	if projected_temporal_frontier:



		entries.append([
			year_line,
			age_line
		])

	var lines: Array = []

	for raw_entry in entries:
		if typeof(raw_entry) != TYPE_ARRAY:
			continue

		for raw_line in (
			raw_entry as Array
		):
			lines.append(
				str(
					raw_line
				)
			)

		lines.append("")
		lines.append("")

	var temporal_signature: String = (
		"%s|temporal_frontier:%d:%d"
		% [
			historical_signature,
			current_world_year,
			current_actor_age
		]
	)

	return {
		"schema": "eralife.life_diary.render_packet",
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"actor_name": _person_display_name(
			actor
		),
		"entries": entries.duplicate(true),
		"lines": lines.duplicate(true),
		"signature": temporal_signature,
		"historical_signature": historical_signature,
		"temporal_frontier_year": current_world_year,
		"temporal_frontier_age": current_actor_age,
		"temporal_frontier_projected": (
			projected_temporal_frontier
		),
		"source_of_truth": ENGINE_SCHEMA,
		"temporal_truth_source": "GameState.year+Person.age",
		"context": context.duplicate(true)
	}
func diary_entries_for_actor(
	actor_id: int,
	_context: Dictionary = {}
) -> Array:
	var clean_actor_id: int = int(actor_id)
	var stream: Array = _stream_for_actor(clean_actor_id)

	if stream.is_empty():
		return []

	var grouped: Array = []
	var current_entry: Array = []
	var current_key: String = ""
	var seen_in_current: Dictionary = {}
	var missing_year_sentinel: int = -2147483648

	for raw_entry in stream:
		var entry: Dictionary = _safe_dictionary(
			raw_entry
		)
		var lines: Array = _entry_lines(
			entry
		)

		if lines.is_empty():
			continue

		var entry_year: int = int(
			entry.get(
				"year",
				_current_year()
			)
		)
		var entry_age: int = int(
			entry.get(
				"age",
				0
			)
		)





		var year_line: String = _format_year_value(
			entry_year
		)
		var age_line: String = "Age: %d" % entry_age
		var key: String = "%s|%s" % [
			year_line,
			age_line
		]

		if current_key != key:
			if not current_entry.is_empty():
				grouped.append(
					current_entry.duplicate(true)
				)

			current_key = key
			current_entry = [
				year_line,
				age_line
			]
			seen_in_current = {
				year_line: true,
				age_line: true
			}

		var start_index: int = 0

		if lines.size() > 0:
			var stored_year_line: String = str(
				lines [0]
			).strip_edges()

			if (
				stored_year_line.begins_with("Year: ")
				or _year_from_lines(
					[
						stored_year_line
					],
					missing_year_sentinel
				) != missing_year_sentinel
			):
				start_index = 1

		if (
			lines.size() > start_index
			and str(
				lines [start_index]
			).strip_edges().begins_with("Age: ")
		):
			start_index += 1

		for i in range(
			start_index,
			lines.size()
		):
			var line_text: String = str(
				lines [i]
			).strip_edges()

			if line_text == "":
				continue

			if seen_in_current.has(
				line_text
			):
				continue

			seen_in_current [
				line_text
			] = true
			current_entry.append(
				line_text
			)

	if not current_entry.is_empty():
		grouped.append(
			current_entry.duplicate(true)
		)

	return grouped

func diary_lines_for_actor(actor_id: int, context: Dictionary = {}) -> Array:
	var entries: Array = diary_entries_for_actor(actor_id, context)
	var lines: Array = []
	for raw_entry in entries:
		var entry_lines: Array = _safe_array(raw_entry)
		for raw_line in entry_lines:
			lines.append(str(raw_line))
		lines.append("")
		lines.append("")
	return lines

func has_diary_for_actor(actor_id: int) -> bool:
	return not _stream_for_actor(int(actor_id)).is_empty()

func signature_for_actor(actor_id: int) -> String:
	var clean_actor_id: int = int(actor_id)
	var stream: Array = _stream_for_actor(clean_actor_id)
	var last_key: String = "none"
	if not stream.is_empty():
		var last_entry: Dictionary = _safe_dictionary(stream [stream.size() - 1])
		last_key = str(last_entry.get("entry_id", last_entry.get("fingerprint", "none")))
	return "%d:%d:%s" % [clean_actor_id, stream.size(), last_key]

func export_state() -> Dictionary:
	_repair_all_streams("export_state")
	return {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"sequence": sequence,
		"actor_streams": actor_streams.duplicate(true),
		"actor_dedupe_index": actor_dedupe_index.duplicate(true),
		"actor_signatures": actor_signatures.duplicate(true),
		"bridge_ledger": bridge_ledger.duplicate(true),
		"repair_ledger": repair_ledger.duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	}

func import_state(data: Dictionary) -> Dictionary:
	_ensure_state()
	if typeof(data) != TYPE_DICTIONARY:
		return _report(false, "import_state_failed", { "reason": "data_not_dictionary"})

	sequence = max(sequence, int(data.get("sequence", sequence)))
	var streams_raw: Variant = data.get("actor_streams", data.get("streams", {}))
	if typeof(streams_raw) == TYPE_DICTIONARY:
		actor_streams = (streams_raw as Dictionary).duplicate(true)
	else:
		actor_streams = {}

	var dedupe_raw: Variant = data.get("actor_dedupe_index", {})
	actor_dedupe_index = (dedupe_raw as Dictionary).duplicate(true) if typeof(dedupe_raw) == TYPE_DICTIONARY else {}

	var signature_raw: Variant = data.get("actor_signatures", {})
	actor_signatures = (signature_raw as Dictionary).duplicate(true) if typeof(signature_raw) == TYPE_DICTIONARY else {}

	_repair_all_streams("import_state")
	_publish_state("import_state")
	return _report(true, "import_state_complete", {
		"actor_count": actor_streams.size(),
		"entry_count": _total_entry_count()
	})

func hydrate_state(data: Dictionary) -> Dictionary:
	return import_state(data)

func repair_state(context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	var repaired_before: int = repair_ledger.size()
	_repair_all_streams(str(context.get("reason", "manual_repair")))
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var legacy_raw: Variant = gs.scenario_state.get("life_diary_state_by_npc", {})
		if typeof(legacy_raw) == TYPE_DICTIONARY:
			repair_from_legacy_state(legacy_raw as Dictionary, { "source": "repair_state_legacy_bridge"})
	_publish_state("repair_state")
	return _report(true, "repair_state_complete", {
		"repairs_added": repair_ledger.size() - repaired_before,
		"actor_count": actor_streams.size(),
		"entry_count": _total_entry_count(),
		"context": context.duplicate(true)
	})

func repair_from_legacy_state(legacy_store: Dictionary, context: Dictionary = {}) -> Dictionary:
	var actor_count: int = 0
	var entry_count: int = 0
	for raw_key in legacy_store.keys():
		var actor_id: int = int(raw_key)
		if actor_id <= 0:
			continue
		var bucket: Dictionary = _safe_dictionary(legacy_store.get(raw_key, {}))
		var entries: Array = _safe_array(bucket.get("entries", []))
		if entries.is_empty():
			continue
		var report: Dictionary = append_legacy_entries_for_actor(actor_id, entries, context)
		actor_count += 1
		entry_count += int(report.get("committed", 0))

	_publish_state("repair_from_legacy_state")
	return _report(true, "legacy_state_repaired", {
		"actor_count": actor_count,
		"entry_count": entry_count,
		"context": context.duplicate(true)
	})

func current_state(include_streams: bool = false) -> Dictionary:
	var state: Dictionary = {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"sequence": sequence,
		"actor_count": actor_streams.size(),
		"entry_count": _total_entry_count(),
		"last_report": last_report.duplicate(true),
		"repair_count": repair_ledger.size(),
		"bridge_count": bridge_ledger.size()
	}
	if include_streams:
		state ["actor_streams"] = actor_streams.duplicate(true)
		state ["actor_dedupe_index"] = actor_dedupe_index.duplicate(true)
		state ["repair_ledger"] = repair_ledger.duplicate(true)
		state ["bridge_ledger"] = bridge_ledger.duplicate(true)
	return state

func on_npc_born(payload:= {}) -> void:
	var payload_dict: Dictionary = _safe_dictionary(payload)
	var actor: Person = _person_from_birth_payload(payload_dict)
	if actor == null:
		return
	if int(actor.id) <= 0:
		return
	if int(actor.age) > int(payload_dict.get("max_birth_intro_age", 0)):
		return
	ensure_birth_intro_for_actor(actor, {
		"source": "event_bus_npc_born",
		"payload": payload_dict.duplicate(true),
		"year": int(payload_dict.get("year", _current_year())),
		"age": int(actor.age)
	})

func _normalize_intent(intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	if typeof(intent) != TYPE_DICTIONARY:
		return {}
	var out: Dictionary = intent.duplicate(true)
	out ["schema"] = str(out.get("schema", INTENT_SCHEMA))
	out ["version"] = int(out.get("version", CONTRACT_VERSION))
	out ["type"] = str(out.get("type", "legacy_text")).strip_edges()
	if out ["type"] == "":
		out ["type"] = "legacy_text"
	out ["source"] = str(out.get("source", context.get("source", "unknown_diary_intent"))).strip_edges()
	if out ["source"] == "":
		out ["source"] = "unknown_diary_intent"
	out ["actor_id"] = _resolve_actor_id(out, context)
	out ["year"] = int(out.get("year", context.get("year", _current_year())))
	out ["age"] = int(out.get("age", context.get("age", _age_for_actor_id(int(out.get("actor_id", -1))))))
	out ["created_at_ms"] = int(out.get("created_at_ms", Time.get_ticks_msec()))
	out ["context"] = context.duplicate(true)
	return out

func _compile_intent_to_entry(intent: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var actor_id: int = int(intent.get("actor_id", -1))
	if actor_id <= 0:
		return {}

	var intent_type: String = str(intent.get("type", "legacy_text")).strip_edges()
	var lines: Array = []
	var preserve_lines: bool = bool(intent.get("preserve_lines_exactly", false))

	match intent_type:
		"birth_intro":
			lines = _safe_array(intent.get("lines", []))
			preserve_lines = true
		"legacy_entry":
			lines = _safe_array(intent.get("lines", []))
		"legacy_text":
			var clean_text: String = _compact_text(str(intent.get("text", "")))
			if clean_text != "":
				lines = [clean_text]
		"action_event":
			var narrative_text: String = str(intent.get("life_diary_text", intent.get("narrative_text", intent.get("text", "")))).strip_edges()
			if narrative_text == "":
				narrative_text = _default_action_event_line(intent)
			if narrative_text != "":
				lines = [narrative_text]
		_:
			var fallback_text: String = str(intent.get("text", intent.get("life_diary_text", ""))).strip_edges()
			if fallback_text != "":
				lines = [fallback_text]

	lines = _normalize_lines(lines, intent, preserve_lines)
	if lines.is_empty():
		return {}

	sequence += 1
	var fingerprint: String = str(intent.get("dedupe_key", "")).strip_edges()
	if fingerprint == "":
		fingerprint = _fingerprint_for_entry(actor_id, intent, lines)

	return {
		"schema": ENTRY_SCHEMA,
		"version": CONTRACT_VERSION,
		"entry_id": "diary_%d_%d_%d" % [actor_id, int(intent.get("year", _current_year())), sequence],
		"sequence": sequence,
		"actor_id": actor_id,
		"actor_name": str(intent.get("actor_name", _actor_name_for_id(actor_id))).strip_edges(),
		"type": intent_type,
		"source": str(intent.get("source", "unknown")),
		"year": int(intent.get("year", _current_year())),
		"age": int(intent.get("age", 0)),
		"timeline_key": _timeline_key(intent, sequence),
		"perspective": str(intent.get("perspective", "first_person")),
		"narrator": str(intent.get("narrator", "self")),
		"lines": lines.duplicate(true),
		"fingerprint": fingerprint,
		"immutable": true,
		"preserve_lines_exactly": preserve_lines,
		"meta": _safe_dictionary(intent.get("meta", {})),
		"created_at_ms": int(Time.get_ticks_msec()),
		"intent": intent.duplicate(true)
	}

func _commit_entry(entry: Dictionary, intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	var actor_id: int = int(entry.get("actor_id", -1))
	if actor_id <= 0:
		return _report(false, "entry_rejected", { "reason": "missing_actor_id", "entry": entry.duplicate(true)})

	var actor_key: String = str(actor_id)
	var fingerprint: String = str(entry.get("fingerprint", "")).strip_edges()
	var index: Dictionary = _dedupe_for_actor(actor_id)
	if fingerprint != "" and index.has(fingerprint):
		var duplicate_report: Dictionary = _report(true, "entry_duplicate_ignored", {
			"actor_id": actor_id,
			"fingerprint": fingerprint,
			"duplicate": true,
			"committed": false,
			"intent_type": str(intent.get("type", "")),
			"context": context.duplicate(true)
		})
		_record_bridge(duplicate_report)
		return duplicate_report

	var append_report: Dictionary = _append_entry_to_current_journal_block_if_allowed(entry, intent, context)
	if not append_report.is_empty():
		return append_report

	var stream: Array = _stream_for_actor(actor_id)
	stream.append(entry.duplicate(true))
	stream.sort_custom(Callable(self, "_timeline_sort"))
	if stream.size() > MAX_STREAM_PER_ACTOR:
		stream = stream.slice(stream.size() - MAX_STREAM_PER_ACTOR, stream.size())
	actor_streams [actor_key] = stream
	_rebuild_dedupe_for_actor(actor_id)
	actor_signatures [actor_key] = signature_for_actor(actor_id)

	var report: Dictionary = _report(true, "entry_committed", {
		"actor_id": actor_id,
		"entry_id": str(entry.get("entry_id", "")),
		"fingerprint": fingerprint,
		"committed": true,
		"duplicate": false,
		"journal_continuation": false,
		"intent_type": str(intent.get("type", "")),
		"entry_count": stream.size(),
		"context": context.duplicate(true)
	})
	_record_bridge(report)
	return report
func _append_entry_to_current_journal_block_if_allowed(entry: Dictionary, intent: Dictionary, context: Dictionary = {}) -> Dictionary:
	if not _entry_should_append_to_current_journal_block(entry, intent):
		return {}

	var actor_id: int = int(entry.get("actor_id", -1))
	if actor_id <= 0:
		return {}

	var actor_key: String = str(actor_id)
	var target_year: int = int(entry.get("year", _current_year()))
	var target_age: int = int(entry.get("age", 0))
	var stream: Array = _stream_for_actor(actor_id)

	if stream.is_empty():
		return {}

	var incoming_lines: Array = _body_lines_from_diary_entry_lines(_safe_array(entry.get("lines", [])))
	if incoming_lines.is_empty():
		return {}

	for i in range(stream.size() - 1, -1, -1):
		var existing: Dictionary = _safe_dictionary(stream [i])
		if existing.is_empty():
			continue

		if int(existing.get("actor_id", actor_id)) != actor_id:
			continue
		if int(existing.get("year", 0)) != target_year:
			continue
		if int(existing.get("age", 0)) != target_age:
			continue

		var existing_lines: Array = _safe_array(existing.get("lines", []))
		if existing_lines.is_empty():
			existing_lines = [
				"Year: %s" % _format_year_value(target_year),
				"Age: %d" % target_age
			]

		var seen_lines: Dictionary = {}
		for raw_existing_line in existing_lines:
			var existing_text: String = str(raw_existing_line).strip_edges()
			if existing_text != "":
				seen_lines [existing_text] = true

		var appended_count: int = 0
		for raw_incoming_line in incoming_lines:
			var incoming_text: String = str(raw_incoming_line).strip_edges()
			if incoming_text == "":
				continue
			if seen_lines.has(incoming_text):
				continue

			seen_lines [incoming_text] = true
			existing_lines.append(incoming_text)
			appended_count += 1

		if appended_count <= 0:
			var duplicate_report: Dictionary = _report(true, "entry_duplicate_ignored", {
				"actor_id": actor_id,
				"fingerprint": str(entry.get("fingerprint", "")),
				"duplicate": true,
				"committed": false,
				"journal_continuation": true,
				"intent_type": str(intent.get("type", "")),
				"context": context.duplicate(true)
			})
			_record_bridge(duplicate_report)
			return duplicate_report

		var continuation_fingerprints: Array = _safe_array(existing.get("continuation_fingerprints", []))
		var fingerprint: String = str(entry.get("fingerprint", "")).strip_edges()
		if fingerprint != "" and not continuation_fingerprints.has(fingerprint):
			continuation_fingerprints.append(fingerprint)

		existing ["lines"] = existing_lines.duplicate(true)
		existing ["continuation_fingerprints"] = continuation_fingerprints.duplicate(true)
		existing ["continuation_count"] = int(existing.get("continuation_count", 0)) + appended_count
		existing ["last_continuation_entry_id"] = str(entry.get("entry_id", ""))
		existing ["last_continuation_source"] = str(entry.get("source", "unknown"))
		existing ["updated_at_ms"] = int(Time.get_ticks_msec())
		existing ["journal_block_accumulates_actions"] = true
		existing ["year_age_header_repeats_for_continuations"] = false

		stream [i] = existing
		stream.sort_custom(Callable(self, "_timeline_sort"))

		if stream.size() > MAX_STREAM_PER_ACTOR:
			stream = stream.slice(stream.size() - MAX_STREAM_PER_ACTOR, stream.size())

		actor_streams [actor_key] = stream
		_rebuild_dedupe_for_actor(actor_id)
		actor_signatures [actor_key] = signature_for_actor(actor_id)

		var report: Dictionary = _report(true, "entry_appended_to_current_journal_block", {
			"actor_id": actor_id,
			"entry_id": str(existing.get("entry_id", "")),
			"continuation_entry_id": str(entry.get("entry_id", "")),
			"fingerprint": fingerprint,
			"committed": true,
			"duplicate": false,
			"journal_continuation": true,
			"year": target_year,
			"age": target_age,
			"appended_line_count": appended_count,
			"intent_type": str(intent.get("type", "")),
			"entry_count": stream.size(),
			"context": context.duplicate(true)
		})
		_record_bridge(report)
		return report

	return {}


func _entry_should_append_to_current_journal_block(entry: Dictionary, intent: Dictionary) -> bool:
	var intent_type: String = str(intent.get("type", entry.get("type", "legacy_text"))).strip_edges()

	if intent_type not in [
		"legacy_text",
		"action_event",
		"committed_action"
	]:
		return false

	if bool(intent.get("start_new_block", false)):
		return false
	if bool(intent.get("force_new_block", false)):
		return false

	var meta: Dictionary = _safe_dictionary(intent.get("meta", {}))
	if bool(meta.get("start_new_block", false)):
		return false
	if bool(meta.get("force_new_block", false)):
		return false

	if intent.has("append_to_current_year_block") and not bool(intent.get("append_to_current_year_block", true)):
		return false
	if meta.has("append_to_current_year_block") and not bool(meta.get("append_to_current_year_block", true)):
		return false

	if bool(entry.get("preserve_lines_exactly", false)):
		return false

	return true


func _body_lines_from_diary_entry_lines(lines: Array) -> Array:
	var out: Array = []
	for raw_line in lines:
		var line_text: String = str(raw_line).strip_edges()
		if line_text == "":
			continue
		if line_text.begins_with("Year: "):
			continue
		if line_text.begins_with("Age: "):
			continue
		if line_text == "----------------------":
			continue
		out.append(line_text)
	return out
func _normalize_lines(
	lines: Array,
	intent: Dictionary,
	preserve_lines_exactly: bool
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_line in lines:
		var line_text: String = str(raw_line)

		if not preserve_lines_exactly:
			line_text = _compact_text(line_text)
		else:
			line_text = line_text.strip_edges()

		if line_text == "":
			continue

		if not preserve_lines_exactly and seen.has(line_text):
			continue

		seen [line_text] = true
		out.append(line_text)

	if out.is_empty():
		return []

	var year_value: int = int(
		intent.get(
			"year",
			_current_year()
		)
	)
	var age_value: int = int(
		intent.get(
			"age",
			0
		)
	)
	var year_line: String = "Year: %s" % _format_year_value(
		year_value
	)
	var age_line: String = "Age: %d" % age_value
	var missing_year_sentinel: int = -2147483648
	var first_line_is_year_header: bool = false

	if not out.is_empty():
		var first_line: String = str(
			out [0]
		).strip_edges()

		first_line_is_year_header = (
			first_line.begins_with("Year: ")
			or _year_from_lines(
				[
					first_line
				],
				missing_year_sentinel
			) != missing_year_sentinel
		)

	if not first_line_is_year_header:
		out.insert(
			0,
			year_line
		)
	else:




		out [0] = year_line

	if (
		out.size() < 2
		or not str(
			out [1]
		).strip_edges().begins_with("Age: ")
	):
		out.insert(
			1,
			age_line
		)
	else:
		out [1] = age_line

	return out

func _entry_lines(entry: Dictionary) -> Array:
	return _safe_array(entry.get("lines", []))

func _timeline_sort(a, b) -> bool:
	var left: Dictionary = _safe_dictionary(a)
	var right: Dictionary = _safe_dictionary(b)
	var left_year: int = int(left.get("year", 0))
	var right_year: int = int(right.get("year", 0))
	if left_year != right_year:
		return left_year < right_year
	var left_age: int = int(left.get("age", 0))
	var right_age: int = int(right.get("age", 0))
	if left_age != right_age:
		return left_age < right_age
	return int(left.get("sequence", 0)) < int(right.get("sequence", 0))

func _timeline_key(intent: Dictionary, seq: int) -> String:
	return "%012d:%04d:%012d" % [int(intent.get("year", 0)), int(intent.get("age", 0)), seq]

func _fingerprint_for_entry(actor_id: int, intent: Dictionary, lines: Array) -> String:
	var parts: Array = []
	parts.append(str(actor_id))
	parts.append(str(intent.get("type", "legacy_text")))
	parts.append(str(intent.get("year", _current_year())))
	parts.append(str(intent.get("age", 0)))
	for raw_line in lines:
		var line_text: String = str(raw_line).strip_edges().to_lower()
		if line_text == "" or line_text.begins_with("year: ") or line_text.begins_with("age: "):
			continue
		parts.append(line_text)
	return "|".join(parts)

func _has_birth_intro_for_actor(actor_id: int) -> bool:
	for raw_entry in _stream_for_actor(actor_id):
		var entry: Dictionary = _safe_dictionary(raw_entry)
		if str(entry.get("type", "")) == "birth_intro":
			return true
		var fingerprint: String = str(entry.get("fingerprint", ""))
		if fingerprint == "birth_intro:%d" % int(actor_id):
			return true
	return false

func _stream_for_actor(actor_id: int) -> Array:
	var key: String = str(int(actor_id))
	var raw: Variant = actor_streams.get(key, [])
	if typeof(raw) == TYPE_ARRAY:
		return (raw as Array).duplicate(true)
	return []

func _dedupe_for_actor(actor_id: int) -> Dictionary:
	var key: String = str(int(actor_id))
	var raw: Variant = actor_dedupe_index.get(key, {})
	if typeof(raw) == TYPE_DICTIONARY:
		return (raw as Dictionary).duplicate(true)
	return {}

func _rebuild_dedupe_for_actor(actor_id: int) -> void:
	var index: Dictionary = {}
	for raw_entry in _stream_for_actor(actor_id):
		var entry: Dictionary = _safe_dictionary(raw_entry)
		var fingerprint: String = str(entry.get("fingerprint", "")).strip_edges()
		if fingerprint != "":
			index [fingerprint] = true

		var continuation_fingerprints: Array = _safe_array(entry.get("continuation_fingerprints", []))
		for raw_continuation_fingerprint in continuation_fingerprints:
			var continuation_fingerprint: String = str(raw_continuation_fingerprint).strip_edges()
			if continuation_fingerprint != "":
				index [continuation_fingerprint] = true

	actor_dedupe_index [str(int(actor_id))] = index

func _repair_all_streams(reason: String = "repair") -> void:
	var repaired_streams: Dictionary = {}
	var highest_sequence: int = sequence
	for raw_key in actor_streams.keys():
		var actor_id: int = int(raw_key)
		if actor_id <= 0:
			_record_repair("dropped_invalid_actor_key", { "key": raw_key, "reason": reason})
			continue
		var raw_stream: Variant = actor_streams.get(raw_key, [])
		var stream: Array = raw_stream if typeof(raw_stream) == TYPE_ARRAY else []
		var clean_stream: Array = []
		var seen: Dictionary = {}
		for raw_entry in stream:
			var repaired: Dictionary = _repair_entry(raw_entry, actor_id, reason)
			if repaired.is_empty():
				continue
			var fingerprint: String = str(repaired.get("fingerprint", ""))
			if fingerprint != "" and seen.has(fingerprint):
				_record_repair("dropped_duplicate_entry", { "actor_id": actor_id, "fingerprint": fingerprint, "reason": reason})
				continue
			seen [fingerprint] = true
			highest_sequence = max(highest_sequence, int(repaired.get("sequence", 0)))
			clean_stream.append(repaired)
		clean_stream.sort_custom(Callable(self, "_timeline_sort"))
		if clean_stream.size() > MAX_STREAM_PER_ACTOR:
			clean_stream = clean_stream.slice(clean_stream.size() - MAX_STREAM_PER_ACTOR, clean_stream.size())
		repaired_streams [str(actor_id)] = clean_stream
	actor_streams = repaired_streams
	sequence = highest_sequence
	actor_dedupe_index = {}
	actor_signatures = {}
	for raw_key in actor_streams.keys():
		var actor_id: int = int(raw_key)
		_rebuild_dedupe_for_actor(actor_id)
		actor_signatures [str(actor_id)] = signature_for_actor(actor_id)

func _repair_entry(raw_entry: Variant, actor_id: int, reason: String) -> Dictionary:
	var entry: Dictionary = _safe_dictionary(raw_entry)
	if entry.is_empty():
		var raw_lines: Array = _safe_array(raw_entry)
		if raw_lines.is_empty():
			return {}
		entry = { "lines": raw_lines, "type": "legacy_entry"}
	entry ["schema"] = str(entry.get("schema", ENTRY_SCHEMA))
	entry ["version"] = int(entry.get("version", CONTRACT_VERSION))
	entry ["actor_id"] = int(entry.get("actor_id", actor_id))
	entry ["year"] = int(entry.get("year", _year_from_lines(_safe_array(entry.get("lines", [])), _current_year())))
	entry ["age"] = int(entry.get("age", _age_from_lines(_safe_array(entry.get("lines", [])), 0)))
	entry ["type"] = str(entry.get("type", "legacy_entry"))
	entry ["source"] = str(entry.get("source", "repaired_state"))
	entry ["sequence"] = int(entry.get("sequence", 0))
	if int(entry.get("sequence", 0)) <= 0:
		sequence += 1
		entry ["sequence"] = sequence
		_record_repair("assigned_missing_sequence", { "actor_id": actor_id, "reason": reason})
	var lines: Array = _normalize_lines(_safe_array(entry.get("lines", [])), entry, bool(entry.get("preserve_lines_exactly", true)))
	if lines.is_empty():
		return {}
	entry ["lines"] = lines.duplicate(true)
	entry ["entry_id"] = str(entry.get("entry_id", "diary_%d_%d_%d" % [actor_id, int(entry.get("year", 0)), int(entry.get("sequence", 0))]))
	entry ["fingerprint"] = str(entry.get("fingerprint", _fingerprint_for_entry(actor_id, entry, lines)))
	entry ["immutable"] = true
	entry ["timeline_key"] = str(entry.get("timeline_key", _timeline_key(entry, int(entry.get("sequence", 0)))))
	return entry

func _record_repair(mode: String, payload: Dictionary = {}) -> void:
	var row: Dictionary = {
		"mode": mode,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"at_ms": int(Time.get_ticks_msec())
	}
	for key in payload.keys():
		row [key] = payload [key]
	repair_ledger.append(row)
	if repair_ledger.size() > MAX_REPAIR_LEDGER:
		repair_ledger = repair_ledger.slice(repair_ledger.size() - MAX_REPAIR_LEDGER, repair_ledger.size())

func _record_bridge(report: Dictionary) -> void:
	bridge_ledger.append(report.duplicate(true))
	if bridge_ledger.size() > MAX_BRIDGE_LEDGER:
		bridge_ledger = bridge_ledger.slice(bridge_ledger.size() - MAX_BRIDGE_LEDGER, bridge_ledger.size())

func _report(success: bool, mode: String, payload: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": success,
		"mode": mode,
		"created_at_ms": int(Time.get_ticks_msec())
	}
	for key in payload.keys():
		row [key] = payload [key]
	last_report = row.duplicate(true)
	return row

func _publish_state(reason: String = "life_diary_contract_engine") -> void:
	_ensure_state()
	if gs == null:
		return
	gs.scenario_state ["life_diary_contract_engine_state"] = export_state()
	gs.scenario_state ["life_diary_contract_engine_contract"] = contract()
	gs.scenario_state ["life_diary_contract_engine_reason"] = reason
	gs.scenario_state ["life_diary_contract_engine_updated_at_ms"] = int(Time.get_ticks_msec())
	gs.scenario_state ["life_diary_authority_layer_active"] = true
	gs.scenario_state ["life_diary_ui_write_forbidden"] = true

func _ensure_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

func _resolve_actor_id(intent: Dictionary, context: Dictionary = {}) -> int:
	for key in ["actor_id", "owner_id", "subject_id", "person_id", "target_id"]:
		if intent.has(key) and int(intent.get(key, -1)) > 0:
			return int(intent.get(key, -1))
		if context.has(key) and int(context.get(key, -1)) > 0:
			return int(context.get(key, -1))
	if gs != null and gs.player != null:
		return int(gs.player.id)
	return -1

func _age_for_actor_id(actor_id: int) -> int:
	var actor: Person = _actor_for_id(actor_id)
	if actor != null:
		return int(actor.age)
	return 0

func _actor_name_for_id(actor_id: int) -> String:
	var actor: Person = _actor_for_id(actor_id)
	if actor != null:
		return _person_display_name(actor)
	return "Unknown Life"

func _actor_for_id(actor_id: int) -> Person:
	if gs == null or int(actor_id) <= 0:
		return null
	if gs.player != null and int(gs.player.id) == int(actor_id):
		return gs.player
	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(int(actor_id))
	return null

func _person_from_birth_payload(payload: Dictionary) -> Person:
	for key in ["person", "npc", "baby", "child", "actor", "subject"]:
		var raw: Variant = payload.get(key, null)
		if raw is Person:
			return raw as Person
	var id_value: int = int(payload.get("person_id", payload.get("npc_id", payload.get("baby_id", payload.get("child_id", payload.get("actor_id", -1))))))
	return _actor_for_id(id_value)

func _append_parent_intro_lines(
		lines: Array,
		actor: Person
) -> void:
	if actor == null:
		return

	var seen_lines: Dictionary = {}

	for raw_line in lines:
		var existing_line: String = str(
			raw_line
		).strip_edges()

		if existing_line != "":
			seen_lines [
				existing_line
			] = true

	_append_birth_family_intro_lines(
		lines,
		seen_lines,
		actor
	)
func _birth_intro_resolve_relative_pair(
		relative_ids: Array
) -> Array:
	var father_or_male: Person = null
	var mother_or_female: Person = null
	var extras: Array = []

	for raw_relative in relative_ids:
		var relative: Person = null

		if raw_relative is Person:
			relative = raw_relative as Person
		else:
			relative = _actor_for_id(
				int(
					raw_relative
				)
			)

		if relative == null:
			continue

		var gender_text: String = str(
			relative.get(
				"gender"
			)
		).strip_edges().to_lower()

		if (
			gender_text == "male"
			and father_or_male == null
		):
			father_or_male = relative
		elif (
			gender_text == "female"
			and mother_or_female == null
		):
			mother_or_female = relative
		else:
			extras.append(
				relative
			)

	if (
		father_or_male == null
		and not extras.is_empty()
	):
		father_or_male = extras [0]

	if mother_or_female == null:
		for raw_extra in extras:
			var extra: Person = raw_extra as Person

			if extra != father_or_male:
				mother_or_female = extra
				break

	return [
		father_or_male,
		mother_or_female
	]


func _birth_intro_current_occupation(
		actor: Person
) -> String:
	if actor == null:
		return ""

	var civic_title: String = str(
		actor.get(
			"civic_title"
		)
	).strip_edges()

	if civic_title != "":
		return civic_title

	var is_royal: bool = bool(
		actor.get(
			"is_royal"
		)
	)
	var royal_title: String = str(
		actor.get(
			"royal_title"
		)
	).strip_edges()

	if (
		is_royal
		and royal_title != ""
	):
		return royal_title

	var job_text: String = str(
		actor.get(
			"job"
		)
	).strip_edges()
	var lower_job: String = (
		job_text.to_lower()
	)

	if lower_job in [
		"",
		"none",
		"unemployed",
		"retired"
	]:
		return ""

	return job_text


func _birth_intro_retired_from_occupation(
		actor: Person
) -> String:
	if actor == null:
		return ""

	var profile_raw: Variant = actor.get(
		"career_profile"
	)
	var profile: Dictionary = (
		(
			profile_raw as Dictionary
		).duplicate(false)
		if typeof(
			profile_raw
		) == TYPE_DICTIONARY
		else {}
	)

	for candidate_key in [
		"retired_from_job",
		"retired_from_title",
		"former_job",
		"last_job",
		"previous_job"
	]:
		var candidate: String = str(
			profile.get(
				candidate_key,
				""
			)
		).strip_edges()

		if (
			candidate != ""
			and candidate.to_lower() != "retired"
		):
			return candidate

	var history: Array = _safe_array(
		profile.get(
			"career_history",
			[]
		)
	)

	for i in range(
		history.size() - 1,
		-1,
		-1
	):
		var history_row: Dictionary = _safe_dictionary(
			history [i]
		)

		for title_key in [
			"rank_title",
			"position_title",
			"job_title",
			"role_title"
		]:
			var title_text: String = str(
				history_row.get(
					title_key,
					""
				)
			).strip_edges()

			if (
				title_text != ""
				and title_text.to_lower() != "retired"
			):
				return title_text

	return ""


func _birth_intro_occupation_phrase(
		occupation: String
) -> String:
	var clean_occupation: String = str(
		occupation
	).strip_edges()

	if clean_occupation == "":
		return ""

	var lower_occupation: String = (
		clean_occupation.to_lower()
	)

	if lower_occupation in [
		"president",
		"president of the united states"
	]:
		return (
			"the President of the United States"
		)

	if lower_occupation in [
		"first lady",
		"first gentleman"
	]:
		return (
			"the %s"
			% clean_occupation
		)

	if (
		lower_occupation.begins_with(
			"a "
		)
		or lower_occupation.begins_with(
			"an "
		)
		or lower_occupation.begins_with(
			"the "
		)
	):
		return lower_occupation

	var first_character: String = (
		lower_occupation.substr(
			0,
			1
		)
	)
	var article: String = (
		"an"
		if first_character in [
			"a",
			"e",
			"i",
			"o",
			"u"
		]
		else "a"
	)

	return "%s %s" % [
		article,
		lower_occupation
	]


func _format_birth_relative_intro_line(
		relationship: String,
		relative: Person
) -> String:
	if relative == null:
		return ""

	var clean_relationship: String = str(
		relationship
	).strip_edges()
	var full_name: String = _person_display_name(
		relative
	)

	if clean_relationship == "":
		clean_relationship = "relative"

	if not bool(
		relative.alive
	):
		return (
			"My %s, %s, (dead)."
			% [
				clean_relationship,
				full_name
			]
		)

	var age_value: int = int(
		relative.age
	)
	var job_text: String = str(
		relative.get(
			"job"
		)
	).strip_edges()

	if job_text.to_lower() == "retired":
		var retired_occupation: String = (
			_birth_intro_retired_from_occupation(
				relative
			)
		)
		var retired_phrase: String = (
			_birth_intro_occupation_phrase(
				retired_occupation
			)
		)

		if retired_phrase != "":
			return (
				(
					"My %s is %s, (%d), retired "
					+ "from a career as %s."
				)
				% [
					clean_relationship,
					full_name,
					age_value,
					retired_phrase
				]
			)

		return (
			"My %s is %s, (%d), retired."
			% [
				clean_relationship,
				full_name,
				age_value
			]
		)

	var current_occupation: String = (
		_birth_intro_current_occupation(
			relative
		)
	)
	var occupation_phrase: String = (
		_birth_intro_occupation_phrase(
			current_occupation
		)
	)

	if occupation_phrase == "":
		return (
			"My %s is %s, (%d)."
			% [
				clean_relationship,
				full_name,
				age_value
			]
		)

	return (
		"My %s is %s, (%d), %s."
		% [
			clean_relationship,
			full_name,
			age_value,
			occupation_phrase
		]
	)


func _append_birth_relative_intro_line(
		lines: Array,
		seen_lines: Dictionary,
		relationship: String,
		relative: Person
) -> void:
	var line_text: String = (
		_format_birth_relative_intro_line(
			relationship,
			relative
		)
	)

	if (
		line_text == ""
		or seen_lines.has(
			line_text
		)
	):
		return

	seen_lines [
		line_text
	] = true
	lines.append(
		line_text
	)


func _append_birth_family_intro_lines(
		lines: Array,
		seen_lines: Dictionary,
		actor: Person
) -> void:
	if (
		actor == null
		or gs == null
	):
		return

	var player_parents: Array = (
		_birth_intro_resolve_relative_pair(
			_safe_array(
				actor.get(
					"parents"
				)
			)
		)
	)
	var father: Person = (
		player_parents [0] as Person
	)
	var mother: Person = (
		player_parents [1] as Person
	)

	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"father",
		father
	)
	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"mother",
		mother
	)

	var maternal_parents: Array = (
		_birth_intro_resolve_relative_pair(
			_safe_array(
				mother.get(
					"parents"
				)
			)
			if mother != null
			else []
		)
	)
	var paternal_parents: Array = (
		_birth_intro_resolve_relative_pair(
			_safe_array(
				father.get(
					"parents"
				)
			)
			if father != null
			else []
		)
	)

	var maternal_grandfather: Person = (
		maternal_parents [0] as Person
	)
	var maternal_grandmother: Person = (
		maternal_parents [1] as Person
	)
	var paternal_grandfather: Person = (
		paternal_parents [0] as Person
	)
	var paternal_grandmother: Person = (
		paternal_parents [1] as Person
	)

	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"maternal grandfather",
		maternal_grandfather
	)
	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"maternal grandmother",
		maternal_grandmother
	)
	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"paternal grandfather",
		paternal_grandfather
	)
	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"paternal grandmother",
		paternal_grandmother
	)

	var maternal_gf_parents: Array = (
		_birth_intro_resolve_relative_pair(
			_safe_array(
				maternal_grandfather.get(
					"parents"
				)
			)
			if maternal_grandfather != null
			else []
		)
	)
	var maternal_gm_parents: Array = (
		_birth_intro_resolve_relative_pair(
			_safe_array(
				maternal_grandmother.get(
					"parents"
				)
			)
			if maternal_grandmother != null
			else []
		)
	)
	var paternal_gf_parents: Array = (
		_birth_intro_resolve_relative_pair(
			_safe_array(
				paternal_grandfather.get(
					"parents"
				)
			)
			if paternal_grandfather != null
			else []
		)
	)
	var paternal_gm_parents: Array = (
		_birth_intro_resolve_relative_pair(
			_safe_array(
				paternal_grandmother.get(
					"parents"
				)
			)
			if paternal_grandmother != null
			else []
		)
	)

	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"maternal great-grandfather",
		maternal_gf_parents [0] as Person
	)
	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"maternal great-grandmother",
		maternal_gf_parents [1] as Person
	)
	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"maternal great-grandfather",
		maternal_gm_parents [0] as Person
	)
	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"maternal great-grandmother",
		maternal_gm_parents [1] as Person
	)
	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"paternal great-grandfather",
		paternal_gf_parents [0] as Person
	)
	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"paternal great-grandmother",
		paternal_gf_parents [1] as Person
	)
	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"paternal great-grandfather",
		paternal_gm_parents [0] as Person
	)
	_append_birth_relative_intro_line(
		lines,
		seen_lines,
		"paternal great-grandmother",
		paternal_gm_parents [1] as Person
	)

	var sibling_ids: Dictionary = {}

	for parent in [
		father,
		mother
	]:
		if parent == null:
			continue

		for raw_child_id in _safe_array(
			parent.get(
				"children"
			)
		):
			var child_id: int = int(
				raw_child_id
			)

			if (
				child_id <= 0
				or child_id == int(
					actor.id
				)
			):
				continue

			sibling_ids [
				child_id
			] = true

	for raw_sibling_id in sibling_ids.keys():
		var sibling: Person = _actor_for_id(
			int(
				raw_sibling_id
			)
		)

		if sibling == null:
			continue

		var sibling_gender: String = str(
			sibling.get(
				"gender"
			)
		).strip_edges().to_lower()
		var sibling_relationship: String = "sibling"

		if sibling_gender == "male":
			sibling_relationship = "brother"
		elif sibling_gender == "female":
			sibling_relationship = "sister"

		_append_birth_relative_intro_line(
			lines,
			seen_lines,
			sibling_relationship,
			sibling
		)

func _person_display_name(actor: Person) -> String:
	if actor == null:
		return "Someone"
	var first_name: String = str(actor.get("first_name")).strip_edges()
	var last_name: String = str(actor.get("last_name")).strip_edges()
	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()
	if full_name == "":
		return "Someone"
	return full_name

func _default_action_event_line(intent: Dictionary) -> String:
	var action_type: String = str(intent.get("action", intent.get("event", intent.get("type", "something")))).replace("_", " ")
	return "I experienced %s." % action_type

func _compact_text(text: String) -> String:
	var parts: Array = []
	for raw_line in str(text).split("\n", false):
		var line: String = str(raw_line).strip_edges()
		if line != "":
			parts.append(line)
	return " ".join(parts).strip_edges()
func _year_from_lines(lines: Array, fallback: int) -> int:
	for raw_line in lines:
		var line: String = str(raw_line).strip_edges()

		if line == "":
			continue

		if line.begins_with("Year: "):
			line = line.substr(6).strip_edges()

		if line.ends_with(" BCE"):
			var bce_value: String = line.substr(
				0,
				line.length() - 4
			).strip_edges()

			if bce_value.is_valid_int():
				return - abs(int(bce_value))

			continue

		if line.ends_with(" BC"):
			var bc_value: String = line.substr(
				0,
				line.length() - 3
			).strip_edges()

			if bc_value.is_valid_int():
				return - abs(int(bc_value))

			continue

		if line.ends_with(" AD"):
			var ad_value: String = line.substr(
				0,
				line.length() - 3
			).strip_edges()

			if ad_value.is_valid_int():
				return abs(int(ad_value))

			continue

		if line.ends_with(" CE"):
			var ce_value: String = line.substr(
				0,
				line.length() - 3
			).strip_edges()

			if ce_value.is_valid_int():
				return abs(int(ce_value))

			continue

		if line.is_valid_int():
			return int(line)

	return fallback

func _age_from_lines(lines: Array, fallback: int) -> int:
	for raw_line in lines:
		var line: String = str(raw_line).strip_edges()
		if line.begins_with("Age: "):
			var value: String = line.replace("Age: ", "").strip_edges()
			if value.is_valid_int():
				return int(value)
	return fallback

func _current_year() -> int:
	if gs != null:
		return int(gs.year)
	return 0

func _format_year_value(value: int) -> String:
	if value < 0:
		return "%d BCE" % abs(value)

	if value <= 1000:
		return "%d AD" % value

	return str(value)

func _month_name(month: int) -> String:
	var names: Array = ["", "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var index: int = clampi(int(month), 1, 12)
	return str(names [index])

func _total_entry_count() -> int:
	var count: int = 0
	for raw_key in actor_streams.keys():
		count += _stream_for_actor(int(raw_key)).size()
	return count

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []