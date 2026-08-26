extends Resource
class_name LivePersonEditorEngine

const ENGINE_STATE_SCHEMA:= "eralife.live_person_editor_engine_state"
const EDIT_CONTRACT_SCHEMA:= "eralife.live_person_editor.edit_contract"
const OPEN_CONTRACT_SCHEMA:= "eralife.live_person_editor.open_contract"
const CONTRACT_VERSION:= 1
const MAX_EDIT_CONTRACTS:= 240
const MAX_EDIT_LEDGER:= 400

var gs

var editor_contracts: Dictionary = {}
var open_contracts: Dictionary = {}
var edit_ledger: Array = []
var editor_sequence: int = 0
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
	_ensure_state()


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	editor_contracts = _safe_dictionary(gs.scenario_state.get("live_person_editor_contracts", editor_contracts))
	open_contracts = _safe_dictionary(gs.scenario_state.get("live_person_editor_open_contracts", open_contracts))
	edit_ledger = _safe_array(gs.scenario_state.get("live_person_editor_ledger", edit_ledger))
	editor_sequence = int(gs.scenario_state.get("live_person_editor_sequence", editor_sequence))
	last_report = _safe_dictionary(gs.scenario_state.get("live_person_editor_last_report", last_report))

	_repair_state()
	_commit_state()


func export_state() -> Dictionary:
	_ensure_state()

	return _make_binary_safe({
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"editor_contracts": editor_contracts.duplicate(true),
		"open_contracts": open_contracts.duplicate(true),
		"edit_ledger": edit_ledger.duplicate(true),
		"editor_sequence": editor_sequence,
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	})


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		last_report = {
			"success": false,
			"reason": "invalid_data",
			"schema": ENGINE_STATE_SCHEMA,
			"version": CONTRACT_VERSION
		}
		return last_report.duplicate(true)

	editor_contracts = _safe_dictionary(data.get("editor_contracts", data.get("live_person_editor_contracts", {})))
	open_contracts = _safe_dictionary(data.get("open_contracts", data.get("live_person_editor_open_contracts", {})))
	edit_ledger = _safe_array(data.get("edit_ledger", data.get("live_person_editor_ledger", [])))
	editor_sequence = int(data.get("editor_sequence", data.get("live_person_editor_sequence", 0)))
	last_report = _safe_dictionary(data.get("last_report", {}))

	_repair_state()
	_commit_state()

	last_report = {
		"success": true,
		"mode": "live_person_editor_engine_imported",
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"contract_count": editor_contracts.size(),
		"open_contract_count": open_contracts.size(),
		"ledger_count": edit_ledger.size(),
		"repaired": true,
		"imported_at_ms": int(Time.get_ticks_msec())
	}

	_commit_state()
	return last_report.duplicate(true)


func build_open_contract(actor: Person, context: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var actor_id: int = int(actor.id)
	if actor_id <= 0:
		return {
			"success": false,
			"reason": "invalid_actor_id"
		}

	editor_sequence += 1

	var contract_id: String = "live_person_editor_open_%d_%d_%d" % [
		editor_sequence,
		actor_id,
		int(Time.get_ticks_msec())
	]

	var contract: Dictionary = {
		"schema": OPEN_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"actor_id": actor_id,
		"actor_name": _actor_display_name(actor),
		"mode": "open_live_person_editor",
		"surface_policy": {
			"ui_is_pure_renderer": true,
		},
		"snapshot": _snapshot_actor(actor),
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	open_contracts [contract_id] = contract.duplicate(true)
	_trim_state()
	_commit_state()

	last_report = {
		"success": true,
		"mode": "live_person_editor_open_contract_created",
		"contract_id": contract_id,
		"actor_id": actor_id,
		"actor_name": _actor_display_name(actor),
		"open_contract": contract.duplicate(true)
	}

	_commit_state()
	return last_report.duplicate(true)


func apply_editor_values(
	actor_id: int,
	values: Dictionary = {},
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor_id <= 0:
		return {
			"success": false,
			"reason": "invalid_actor_id"
		}

	var actor: Person = _actor_by_id(
		actor_id
	)

	if actor == null:
		return {
			"success": false,
			"reason": "actor_not_found",
			"actor_id": actor_id
		}

	if typeof(values) != TYPE_DICTIONARY:
		values = {}

	var before_snapshot: Dictionary = (
		_snapshot_actor(
			actor
		)
	)
	var applied_fields: Dictionary = {}

	_apply_string_field(
		actor,
		values,
		applied_fields,
		"first_name",
		"first_name",
		40
	)
	_apply_string_field(
		actor,
		values,
		applied_fields,
		"last_name",
		"last_name",
		40
	)

	_apply_int_field(
		actor,
		values,
		applied_fields,
		"happiness",
		"satisfaction",
		0,
		100
	)
	_apply_int_field(
		actor,
		values,
		applied_fields,
		"health",
		"health",
		0,
		200
	)
	_apply_int_field(
		actor,
		values,
		applied_fields,
		"hunger",
		"hunger",
		0,
		100
	)
	_apply_int_field(
		actor,
		values,
		applied_fields,
		"smarts",
		"smarts",
		0,
		100
	)
	_apply_int_field(
		actor,
		values,
		applied_fields,
		"looks",
		"looks",
		0,
		100
	)
	_apply_int_field(
		actor,
		values,
		applied_fields,
		"mental_health",
		"mental_health",
		0,
		100
	)
	_apply_int_field(
		actor,
		values,
		applied_fields,
		"willpower",
		"willpower",
		0,
		150
	)
	_apply_int_field(
		actor,
		values,
		applied_fields,
		"imagination",
		"imagination",
		0,
		100
	)
	_apply_int_field(
		actor,
		values,
		applied_fields,
		"fame",
		"fame",
		0,
		100
	)
	_apply_float_field(
		actor,
		values,
		applied_fields,
		"fertility",
		"fertility",
		0.0,
		100.0
	)
	_apply_int_field(
		actor,
		values,
		applied_fields,
		"bank_balance",
		"bank_balance",
		0,
		5000000
	)

	if (
		applied_fields.has(
			"first_name"
		)
		or applied_fields.has(
			"last_name"
		)
	):
		var full_name: String = (
			"%s %s"
			% [
				str(actor.first_name),
				str(actor.last_name)
			]
		).strip_edges()

		if (
			full_name != ""
			and _actor_has_property(
				actor,
				"name"
			)
		):
			actor.set(
				"name",
				full_name
			)

	if (
		gs != null
		and gs.fame_engine != null
		and applied_fields.has(
			"fame"
		)
		and gs.fame_engine.has_method(
			"give_fame"
		)
	):
		gs.fame_engine.give_fame(
			actor,
			0
		)

	if (
		gs != null
		and gs.has_method(
			"apply_reality_rules_to_person"
		)
	):
		gs.apply_reality_rules_to_person(
			actor
		)

	if (
		gs != null
		and gs.has_method(
			"sync_person_death_state_from_health"
		)
	):
		gs.sync_person_death_state_from_health(
			actor,
			"Health depleted"
		)

	var after_snapshot: Dictionary = (
		_snapshot_actor(
			actor
		)
	)

	editor_sequence += 1

	var contract_id: String = (
		"live_person_editor_edit_%d_%d_%d"
		% [
			editor_sequence,
			actor_id,
			int(
				Time.get_ticks_msec()
			)
		]
	)
	var edit_contract: Dictionary = {
		"schema": EDIT_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"actor_id": actor_id,
		"actor_name": (
			_actor_display_name(
				actor
			)
		),
		"mode": (
			"apply_live_person_editor_values"
		),
		"applied_fields": (
			applied_fields.duplicate(true)
		),
		"before": (
			before_snapshot.duplicate(true)
		),
		"after": (
			after_snapshot.duplicate(true)
		),
		"context": context.duplicate(true),
		"persistent": true,
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	editor_contracts [contract_id] = (
		edit_contract.duplicate(true)
	)
	edit_ledger.append(
		{
			"contract_id": contract_id,
			"actor_id": actor_id,
			"actor_name": (
				_actor_display_name(
					actor
				)
			),
			"applied_fields": (
				applied_fields.duplicate(true)
			),
			"created_at_ms": int(
				Time.get_ticks_msec()
			)
		}
	)

	_trim_state()
	_commit_state()

	last_report = {
		"success": true,
		"mode": (
			"live_person_editor_values_applied"
		),
		"schema": EDIT_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"contract_id": contract_id,
		"actor_id": actor_id,
		"actor_name": (
			_actor_display_name(
				actor
			)
		),
		"applied_fields": (
			applied_fields.duplicate(true)
		),
		"before": (
			before_snapshot.duplicate(true)
		),
		"after": (
			after_snapshot.duplicate(true)
		),
		"edit_contract": (
			edit_contract.duplicate(true)
		)
	}

	_commit_state()

	return last_report.duplicate(true)
func _apply_string_field(
	actor: Person,
	values: Dictionary,
	applied_fields: Dictionary,
	value_key: String,
	actor_property: String,
	max_length: int
) -> void:
	if actor == null:
		return

	if not values.has(value_key):
		return

	if not _actor_has_property(
		actor,
		actor_property
	):
		return

	var previous_value: String = str(
		actor.get(
			actor_property
		)
	)
	var next_value: String = str(
		values.get(
			value_key,
			previous_value
		)
	)
	next_value = next_value.replace(
		"\n",
		" "
	)
	next_value = next_value.replace(
		"
",
		" "
	)
	next_value = next_value.replace(
		"\t",
		" "
	)
	next_value = next_value.strip_edges()

	if next_value.length() > max_length:
		next_value = next_value.substr(
			0,
			max_length
		)

	if next_value == "":
		return

	actor.set(
		actor_property,
		next_value
	)

	applied_fields [value_key] = {
		"actor_property": actor_property,
		"previous": previous_value,
		"value": next_value
	}

func _apply_int_field(actor: Person, values: Dictionary, applied_fields: Dictionary, value_key: String, actor_property: String, min_value: int, max_value: int) -> void:
	if actor == null:
		return

	if not values.has(value_key):
		return

	if not _actor_has_property(actor, actor_property):
		return

	var previous_value: int = int(actor.get(actor_property))
	var next_value: int = int(clamp(int(values.get(value_key, previous_value)), min_value, max_value))

	actor.set(actor_property, next_value)

	applied_fields [value_key] = {
		"actor_property": actor_property,
		"previous": previous_value,
		"value": next_value
	}


func _apply_float_field(actor: Person, values: Dictionary, applied_fields: Dictionary, value_key: String, actor_property: String, min_value: float, max_value: float) -> void:
	if actor == null:
		return

	if not values.has(value_key):
		return

	if not _actor_has_property(actor, actor_property):
		return

	var previous_value: float = float(actor.get(actor_property))
	var next_value: float = clamp(float(values.get(value_key, previous_value)), min_value, max_value)

	actor.set(actor_property, next_value)

	applied_fields [value_key] = {
		"actor_property": actor_property,
		"previous": previous_value,
		"value": next_value
	}


func _actor_by_id(actor_id: int) -> Person:
	if gs == null or actor_id <= 0:
		return null

	if gs.player != null and int(gs.player.id) == actor_id:
		return gs.player

	if gs.has_method("get_npc_by_id"):
		var found = gs.get_npc_by_id(actor_id)
		if found != null:
			return found

	if gs.has_method("get_or_reactivate_npc_by_id"):
		var restored = gs.get_or_reactivate_npc_by_id(actor_id)
		if restored != null:
			return restored

	return null

func _snapshot_actor(
	actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	return {
		"actor_id": int(actor.id),
		"actor_name": (
			_actor_display_name(
				actor
			)
		),
		"first_name": str(
			actor.first_name
		),
		"last_name": str(
			actor.last_name
		),
		"age": int(actor.age),
		"alive": bool(actor.alive),
		"health": int(
			round(
				float(actor.health)
			)
		),
		"hunger": int(
			round(
				float(
					_actor_numeric_value(
						actor,
						"hunger",
						100.0
					)
				)
			)
		),
		"happiness": int(
			round(
				float(
					actor.satisfaction
				)
			)
		),
		"smarts": int(
			round(
				float(actor.smarts)
			)
		),
		"looks": int(
			round(
				float(actor.looks)
			)
		),
		"mental_health": int(
			round(
				float(
					actor.mental_health
				)
			)
		),
		"willpower": int(
			round(
				_actor_numeric_value(
					actor,
					"willpower",
					0.0
				)
			)
		),
		"imagination": int(
			round(
				_actor_numeric_value(
					actor,
					"imagination",
					0.0
				)
			)
		),
		"fame": int(
			round(
				float(actor.fame)
			)
		),
		"fertility": float(
			actor.fertility
		),
		"bank_balance": int(
			actor.bank_balance
		),
		"snapshot_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _actor_numeric_value(
	actor: Person,
	property_name: String,
	fallback: float
) -> float:
	if actor == null:
		return fallback

	if not _actor_has_property(
		actor,
		property_name
	):
		return fallback

	return float(
		actor.get(
			property_name
		)
	)
func emit_modification_surface_contract(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	var report: Dictionary = (
		build_open_contract(
			actor,
			payload
		)
	)

	if not bool(
		report.get(
			"success",
			false
		)
	):
		return report

	var open_contract: Dictionary = (
		_safe_dictionary(
			report.get(
				"open_contract",
				{}
			)
		)
	)

	return {
		"success": true,
		"mode": (
			"modification_surface_contract_emitted"
		),
		"actor_id": int(actor.id),
		"actor_name": (
			_actor_display_name(
				actor
			)
		),
		"surface_contract": (
			open_contract.duplicate(true)
		),
		"open_contract": (
			open_contract.duplicate(true)
		),
		"ui_is_renderer_only": true
	}


func commit_modification_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var values: Dictionary = _safe_dictionary(
		payload.get(
			"values",
			{}
		)
	)
	var edit_report: Dictionary = (
		apply_editor_values(
			int(actor.id),
			values,
			payload
		)
	)

	if not bool(
		edit_report.get(
			"success",
			false
		)
	):
		return edit_report

	var actor_id: int = int(
		actor.id
	)
	var actor_name: String = (
		_actor_display_name(
			actor
		)
	)

	if gs != null:
		if typeof(gs.scenario_state) != TYPE_DICTIONARY:
			gs.scenario_state = {}

		gs.scenario_state [
			"live_person_editor_last_modified_actor_id"
		] = actor_id
		gs.scenario_state [
			"live_person_editor_last_modified_actor_name"
		] = actor_name
		gs.scenario_state [
			"live_person_editor_last_modified_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		gs.scenario_state [
			"live_person_editor_relationship_projection_dirty_actor_id"
		] = actor_id
		gs.scenario_state [
			"live_person_editor_actor_lens_residency_dirty_actor_id"
		] = actor_id
		gs.scenario_state [
			"live_person_editor_post_commit_open_contract_rebuild_deferred"
		] = true
		gs.scenario_state [
			"live_person_editor_post_commit_relationship_rebuild_forbidden"
		] = true

	edit_report [
		"actor_id"
	] = actor_id
	edit_report [
		"actor_name"
	] = actor_name
	edit_report [
		"surface_contract"
	] = {}
	edit_report [
		"open_contract"
	] = {}
	edit_report [
		"modification_panel_refresh_ready"
	] = false
	edit_report [
		"modification_panel_refresh_deferred"
	] = true
	edit_report [
		"relationship_projection_rebuild_deferred"
	] = true
	edit_report [
		"relationship_projection_rebuild_on_commit_forbidden"
	] = true
	edit_report [
		"actor_lens_residency_dirty"
	] = true
	edit_report [
		"ui_is_renderer_only"
	] = true

	return edit_report.duplicate(false)

func _actor_display_name(actor: Person) -> String:
	if actor == null:
		return "Unknown Life"

	var first: String = str(actor.first_name).strip_edges()
	var last: String = str(actor.last_name).strip_edges()
	var full_name: String = ("%s %s" % [first, last]).strip_edges()

	if full_name == "":
		full_name = str(actor.name).strip_edges()

	if full_name == "":
		full_name = "Unknown Life"

	return full_name


func _actor_has_property(actor: Person, property_name: String) -> bool:
	if actor == null:
		return false

	var clean_property: String = str(property_name).strip_edges()
	if clean_property == "":
		return false

	for raw_property in actor.get_property_list():
		if typeof(raw_property) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_property as Dictionary
		if str(row.get("name", "")).strip_edges() == clean_property:
			return true

	return false


func _repair_state() -> void:
	var repaired_editor_contracts: Dictionary = {}

	for raw_key in editor_contracts.keys():
		var contract: Dictionary = _safe_dictionary(editor_contracts.get(raw_key, {}))
		if contract.is_empty():
			continue

		var contract_id: String = str(contract.get("contract_id", contract.get("id", raw_key))).strip_edges()
		if contract_id == "":
			continue

		contract ["schema"] = str(contract.get("schema", EDIT_CONTRACT_SCHEMA))
		contract ["version"] = int(contract.get("version", CONTRACT_VERSION))
		contract ["contract_id"] = contract_id
		contract ["id"] = contract_id

		repaired_editor_contracts [contract_id] = contract

	editor_contracts = repaired_editor_contracts

	var repaired_open_contracts: Dictionary = {}

	for raw_open_key in open_contracts.keys():
		var open_contract: Dictionary = _safe_dictionary(open_contracts.get(raw_open_key, {}))
		if open_contract.is_empty():
			continue

		var open_contract_id: String = str(open_contract.get("contract_id", open_contract.get("id", raw_open_key))).strip_edges()
		if open_contract_id == "":
			continue

		open_contract ["schema"] = str(open_contract.get("schema", OPEN_CONTRACT_SCHEMA))
		open_contract ["version"] = int(open_contract.get("version", CONTRACT_VERSION))
		open_contract ["contract_id"] = open_contract_id
		open_contract ["id"] = open_contract_id

		repaired_open_contracts [open_contract_id] = open_contract

	open_contracts = repaired_open_contracts

	var repaired_ledger: Array = []
	for raw_row in edit_ledger:
		var row: Dictionary = _safe_dictionary(raw_row)
		if row.is_empty():
			continue

		if str(row.get("contract_id", "")).strip_edges() == "":
			continue

		repaired_ledger.append(row)

	edit_ledger = repaired_ledger

	_trim_state()


func _trim_state() -> void:
	while editor_contracts.size() > MAX_EDIT_CONTRACTS:
		var oldest_key: String = str(editor_contracts.keys() [0])
		editor_contracts.erase(oldest_key)

	while edit_ledger.size() > MAX_EDIT_LEDGER:
		edit_ledger.remove_at(0)


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["live_person_editor_contracts"] = editor_contracts.duplicate(true)
	gs.scenario_state ["live_person_editor_open_contracts"] = open_contracts.duplicate(true)
	gs.scenario_state ["live_person_editor_ledger"] = edit_ledger.duplicate(true)
	gs.scenario_state ["live_person_editor_sequence"] = editor_sequence
	gs.scenario_state ["live_person_editor_last_report"] = last_report.duplicate(true)


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