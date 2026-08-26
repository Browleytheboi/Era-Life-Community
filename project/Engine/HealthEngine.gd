extends Resource
class_name HealthEngine

var gs

const HEALTH_CONTRACT_SCHEMA:= "eralife.health_contract_engine"
const HEALTH_CONTRACT_VERSION:= 1
const HEALTH_EVENT_CONTRACT_SCHEMA:= "eralife.runtime_contract.health_event"

var health_contract_event_log: Array = []
var health_contract_index: Dictionary = {}
var last_health_contract_report: Dictionary = {}
var health_contract_emit_runtime_contracts: bool = true
var health_contract_max_event_log: int = 180
var committed_death_fanout_queue: Array = []
var committed_death_fanout_service_armed: bool = false
var committed_death_fanout_sequence: int = 0
var committed_death_fanout_keys: Dictionary = {}
func _init(_gs):
	gs = _gs

	if (
		gs != null
		and gs.event_bus != null
	):
		gs.event_bus.subscribe(
			"career_overwork_pressure",
			self,
			"handle_career_overwork_pressure",
			{
				"lane": "immediate",
				"allow_defer": false,
				"force_immediate": true,
				"subscription_priority": 12,
				"subscription_id": (
					"health_engine.career_overwork_pressure"
				),
				"execution_model": "constant_time",
				"max_quantum_ms": 1
			}
		)
func handle_career_overwork_pressure(
	payload: Dictionary
) -> Dictionary:
	var actor: Person = _actor_from_payload(
		payload
	)

	if actor == null:
		return {
			"success": false,
			"reason": "career_overwork_actor_missing"
		}

	var weekly_hours: int = int(
		payload.get(
			"weekly_hours",
			0
		)
	)

	if weekly_hours <= 50:
		return {
			"success": true,
			"reason": "within_safe_career_hours_contract"
		}

	var overwork_hours: int = (
		weekly_hours - 50
	)

	var pressure_years: int = int(
		actor.get_meta(
			"career_overwork_pressure_years",
			0
		)
	) + 1

	actor.set_meta(
		"career_overwork_pressure_years",
		pressure_years
	)
	actor.set_meta(
		"career_overwork_last_year",
		int(
			payload.get(
				"year",
				gs.year
			)
		)
	)

	var mental_delta: float = - clampf(
		1.5
		+ float(overwork_hours) * 0.35,
		1.5,
		12.0
	)

	var context: Dictionary = {
		"actor_id": int(
			actor.id
		),
		"weekly_hours": weekly_hours,
		"overwork_hours": overwork_hours,
		"pressure_years": pressure_years,
		"career_work_stress": float(
			payload.get(
				"work_stress",
				0.0
			)
		),
		"source": (
			"career_overwork_pressure"
		)
	}

	var mental_report: Dictionary = (
		_apply_mental_health_delta_contract(
			actor,
			mental_delta,
			"career_overwork_pressure",
			context,
			false
		)
	)

	var risk_score: int = clampi(
		overwork_hours * 4
		+ pressure_years * 12
		+ int(
			round(
				float(
					payload.get(
						"work_stress",
						0.0
					)
				) * 0.25
			)
		),
		0,
		95
	)

	var deterministic_roll: int = (
		abs(
			hash([
				int(actor.id),
				int(
					payload.get(
						"year",
						gs.year
					)
				),
				weekly_hours,
				pressure_years,
				"career_hypertension"
			])
		)
		% 100
	)

	var hypertension_triggered: bool = (
		pressure_years >= 2
		and deterministic_roll < risk_score
	)

	var health_report: Dictionary = {}

	if hypertension_triggered:
		actor.set_meta(
			"high_blood_pressure",
			true
		)
		actor.set_meta(
			"high_blood_pressure_diagnosed_year",
			int(
				payload.get(
					"year",
					gs.year
				)
			)
		)

		health_report = (
			_apply_health_delta_contract(
				actor,
				-4.0,
				"career_overwork_hypertension",
				context,
				false
			)
		)

	return {
		"success": true,
		"actor_id": int(
			actor.id
		),
		"weekly_hours": weekly_hours,
		"overwork_hours": overwork_hours,
		"pressure_years": pressure_years,
		"mental_delta": mental_delta,
		"hypertension_risk": risk_score,
		"hypertension_triggered": (
			hypertension_triggered
		),
		"mental_report": mental_report,
		"health_report": health_report,
		"execution_model": "constant_time"
	}




var disease_causes = {
	"heart_attack": "Heart attack",
	"stroke": "Stroke",
	"cancer_lung": "Lung cancer",
	"cancer_breast": "Breast cancer",
	"cancer_colon": "Colon cancer",
	"pneumonia": "Pneumonia",
	"flu_complications": "Flu complications",
	"organ_failure": "Organ failure",
	"alcohol_liver_failure": "Liver failure from alcoholism",
	"diabetes_complication": "Diabetes complications",
	"old_age": "Old age",
	"accident": "Accidental injury",
	"fatal_injury": "Fatal injury"
}





func commit_weapon_self_mortality_core(
	entity,
	cause: String
) -> Dictionary:
	return commit_nonblocking_mortality_core(
		entity,
		cause,
		{
			"source": "weapon_self_mortality",
			"request_action": "try_kill",
			"death_action": "handle_death",
			"self_inflicted": true,
			"mode": "weapon_self_mortality_core_committed"
		}
	)
func commit_nonblocking_mortality_core(
	entity,
	cause: String,
	context: Dictionary = {}
) -> Dictionary:
	if entity == null:
		return {
			"success": false,
			"death_committed": false,
			"reason": "missing_entity"
		}

	var clean_cause: String = str(
		cause
	).strip_edges()

	if clean_cause == "":
		clean_cause = "Unknown causes"

	if (
		not bool(
			entity.alive
		)
		and str(
			entity.cause_of_death
		).strip_edges() != ""
	):
		if (
			"death_year" in entity
			and int(
				entity.death_year
			) <= -999000
			and gs != null
		):
			entity.death_year = int(
				gs.year
			)

		return {
			"success": false,
			"death_committed": false,
			"reason": "duplicate_death_guarded",
			"entity_id": _health_entity_id(
				entity
			),
			"existing_cause": str(
				entity.cause_of_death
			)
		}

	var request_action: String = str(
		context.get(
			"request_action",
			"try_kill"
		)
	).strip_edges()
	var death_action: String = str(
		context.get(
			"death_action",
			"handle_death"
		)
	).strip_edges()
	var self_inflicted: bool = bool(
		context.get(
			"self_inflicted",
			false
		)
	)
	var mode: String = str(
		context.get(
			"mode",
			"nonblocking_mortality_core_committed"
		)
	).strip_edges()
	var source: String = str(
		context.get(
			"source",
			"health_engine"
		)
	).strip_edges()
	var fanout_policy: Dictionary = _safe_dictionary(
		context.get(
			"fanout_policy",
			{}
		)
	)
	var before_snapshot: Dictionary = (
		_health_snapshot_for(
			entity
		)
	)
	var death_requested_contract: Dictionary = (
		_build_health_contract(
			entity,
			"death_requested",
			request_action,
			{
				"cause": clean_cause,
				"self_inflicted": self_inflicted,
				"source": source,
			},
			before_snapshot,
			before_snapshot
		)
	)

	_record_health_contract(
		death_requested_contract,
		false
	)


	entity.alive = false
	entity.health = 0
	entity.cause_of_death = clean_cause

	if (
		"death_year" in entity
		and gs != null
	):
		entity.death_year = int(
			gs.year
		)

	var after_snapshot: Dictionary = (
		_health_snapshot_for(
			entity
		)
	)
	var death_contract: Dictionary = (
		_build_health_contract(
			entity,
			"death",
			death_action,
			{
				"domain": "mortality",
				"severity": "fatal",
				"cause": clean_cause,
				"source": source,
				"self_inflicted": self_inflicted,
				"age": int(
					entity.age
				),
				"death_year": (
					int(
						entity.death_year
					)
					if "death_year" in entity
					else _health_year()
				),
			},
			before_snapshot,
			after_snapshot
		)
	)

	_record_health_contract(
		death_contract,
		false
	)

	return {
		"success": true,
		"death_committed": true,
		"mode": mode,
		"entity_id": _health_entity_id(
			entity
		),
		"cause": clean_cause,
		"source": source,
		"before_snapshot": before_snapshot,
		"after_snapshot": after_snapshot,
		"death_requested_contract": (
			death_requested_contract.duplicate(false)
		),
		"death_contract": (
			death_contract.duplicate(false)
		),
		"fanout_policy": fanout_policy.duplicate(true),
		"player_idle_required": false,
		"ready_gate_member": false
	}


func queue_committed_death_fanout(
	entity,
	core_report: Dictionary
) -> Dictionary:
	if (
		entity == null
		or not bool(
			core_report.get(
				"death_committed",
				false
			)
		)
	):
		return {
			"success": false,
			"reason": "mortality_core_not_committed"
		}

	var request_raw: Variant = core_report.get(
		"death_requested_contract",
		{}
	)
	var death_raw: Variant = core_report.get(
		"death_contract",
		{}
	)
	var death_requested_contract: Dictionary = (
		(request_raw as Dictionary).duplicate(false)
		if typeof(request_raw) == TYPE_DICTIONARY
		else {}
	)
	var death_contract: Dictionary = (
		(death_raw as Dictionary).duplicate(false)
		if typeof(death_raw) == TYPE_DICTIONARY
		else {}
	)

	if death_contract.is_empty():
		return {
			"success": false,
			"reason": "death_contract_missing"
		}

	var fanout_key: String = str(
		death_contract.get(
			"contract_id",
			""
		)
	).strip_edges()

	if (
		fanout_key != ""
		and committed_death_fanout_keys.has(
			fanout_key
		)
	):
		return {
			"success": true,
			"mode": "committed_death_fanout_already_queued",
			"fanout_key": fanout_key,
		}

	committed_death_fanout_sequence += 1

	var queue_id: String = (
		"committed_death_fanout_%d"
		% committed_death_fanout_sequence
	)
	var was_controlled_player: bool = (
		gs != null
		and gs.player != null
		and entity == gs.player
	)

	committed_death_fanout_queue.append({
		"queue_id": queue_id,
		"fanout_key": fanout_key,
		"entity_ref": entity,
		"entity_id": _health_entity_id(
			entity
		),
		"cause": str(
			core_report.get(
				"cause",
				entity.cause_of_death
			)
		),
		"death_requested_contract": (
			death_requested_contract
		),
		"death_contract": death_contract,
		"was_controlled_player": was_controlled_player,
		"fanout_policy": _safe_dictionary(
			core_report.get(
				"fanout_policy",
				{}
			)
		).duplicate(true),
		"stage": 0,
		"queued_at_ms": int(
			Time.get_ticks_msec()
		),
		"requires_player_idle": false,
		"blocks_ui": false,
		"ready_gate_member": false
	})

	if fanout_key != "":
		committed_death_fanout_keys [
			fanout_key
		] = queue_id

	_arm_committed_death_fanout_service()

	return {
		"success": true,
		"mode": "committed_death_fanout_queued",
		"queue_id": queue_id,
		"fanout_key": fanout_key,
		"entity_id": _health_entity_id(
			entity
		),
		"queued_stage": 0,
		"queue_size": committed_death_fanout_queue.size(),
		"requires_player_idle": false,
		"blocks_ui": false,
		"ready_gate_member": false
	}


func _arm_committed_death_fanout_service() -> void:
	if committed_death_fanout_service_armed:
		return

	if committed_death_fanout_queue.is_empty():
		return

	committed_death_fanout_service_armed = true

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		committed_death_fanout_service_armed = false
		return

	var connection_error: int = (
		tree.process_frame.connect(
			Callable(
				self,
				"_service_committed_death_fanout_quantum"
			),
			CONNECT_ONE_SHOT
		)
	)

	if connection_error != OK:
		committed_death_fanout_service_armed = false
func _service_committed_death_fanout_quantum() -> void:
	committed_death_fanout_service_armed = false

	if committed_death_fanout_queue.is_empty():
		return

	var row_raw: Variant = (
		committed_death_fanout_queue [
			0
		]
	)

	if typeof(row_raw) != TYPE_DICTIONARY:
		committed_death_fanout_queue.pop_front()
		_arm_committed_death_fanout_service()
		return

	var row: Dictionary = (
		(row_raw as Dictionary).duplicate(false)
	)
	var entity = row.get(
		"entity_ref",
		null
	)

	if entity == null:
		committed_death_fanout_queue.pop_front()
		_arm_committed_death_fanout_service()
		return

	var clean_cause: String = str(
		row.get(
			"cause",
			entity.cause_of_death
		)
	).strip_edges()

	if clean_cause == "":
		clean_cause = "Unknown causes"

	var stage: int = int(
		row.get(
			"stage",
			0
		)
	)
	var was_controlled_player: bool = bool(
		row.get(
			"was_controlled_player",
			false
		)
	)

	match stage:
		0:
			var request_raw: Variant = row.get(
				"death_requested_contract",
				{}
			)
			var request_contract: Dictionary = (
				request_raw as Dictionary
				if typeof(request_raw) == TYPE_DICTIONARY
				else {}
			)

			if (
				not request_contract.is_empty()
				and health_contract_emit_runtime_contracts
			):
				_mirror_health_contract_to_runtime(
					request_contract
				)

		1:
			var death_raw: Variant = row.get(
				"death_contract",
				{}
			)
			var death_contract: Dictionary = (
				death_raw as Dictionary
				if typeof(death_raw) == TYPE_DICTIONARY
				else {}
			)

			if (
				not death_contract.is_empty()
				and health_contract_emit_runtime_contracts
			):
				_mirror_health_contract_to_runtime(
					death_contract
				)

		2:
			if (
				gs != null
				and gs.narrative_engine != null
			):
				gs.narrative_engine.log_event(
					entity,
					{
						"type": "death",
						"cause": clean_cause,
						"skip_llm_enhancement": true,
						"background_only": true,
						"blocks_ui": false,
						"ready_gate_member": false,
					}
				)

		3:
			if (
				was_controlled_player
				and gs != null
				and gs.event_bus != null
			):
				gs.event_bus.emit(
					ActionEventTypes.PLAYER_DIED,
					{
						"npc_id": entity.id,
						"cause": clean_cause,
						"source": "health_engine",
						"qos_tier": "important",
						"fanout_hints": {
							"force_defer_bus": true,
							"player_idle_required": false,
							"ready_gate_member": false
						}
					}
				)

		4:
			if (
				gs != null
				and gs.event_bus != null
			):
				gs.event_bus.emit(
					ActionEventTypes.NPC_DIED,
					{
						"npc_id": entity.id,
						"cause": clean_cause,
						"source": "health_engine",
						"qos_tier": "important",
						"fanout_hints": {
							"force_defer_bus": true,
							"player_idle_required": false,
							"ready_gate_member": false
						}
					}
				)

		5:
			var fanout_policy: Dictionary = _safe_dictionary(
				row.get(
					"fanout_policy",
					{}
				)
			)
			var msg: String = _build_death_text(
				entity
			)
			var personally_relevant_death: bool = bool(
				fanout_policy.get(
					"personally_relevant_death",
					msg != ""
				)
			)
			var suppress_known_person_death_message: bool = bool(
				fanout_policy.get(
					"suppress_known_person_death_message",
					false
				)
			)

			row [
				"personally_relevant_death"
			] = personally_relevant_death

			if not suppress_known_person_death_message:
				if (
					gs != null
					and not was_controlled_player
					and gs.has_method(
						"queue_known_person_death_message"
					)
				):
					gs.queue_known_person_death_message(
						entity
					)
				elif (
					gs != null
					and personally_relevant_death
				):
					gs.pending_death_messages.append(
						msg
					)
					gs.queue_year_resolution_popup({
						"popup_title": "Death",
						"popup_text": msg,
						"popup_footer": "Tap anywhere to continue."
					})

		6:
			var personally_relevant_death: bool = bool(
				row.get(
					"personally_relevant_death",
					false
				)
			)
			var full_name: String = (
				"%s %s"
				% [
					str(
						entity.first_name
					),
					str(
						entity.last_name
					)
				]
			).strip_edges()
			var world_text: String = (
				"%s died at age %d. Cause: %s."
				% [
					full_name,
					int(
						entity.age
					),
					str(
						entity.cause_of_death
					)
				]
			)

			if (
				gs != null
				and gs.has_method(
					"build_death_world_feed_text"
				)
			):
				world_text = (
					gs.build_death_world_feed_text(
						full_name,
						int(
							entity.age
						),
						str(
							entity.cause_of_death
						),
						int(
							entity.id
						)
					)
				)

			if (
				gs != null
				and gs.has_method(
					"push_world_feed"
				)
			):
				gs.push_world_feed(
					world_text,
					{
						"npc_id": entity.id,
						"relation_label": (
							"family_death"
							if personally_relevant_death
							else ""
						),
						"personally_relevant": (
							personally_relevant_death
						),
						"category": "death",
						"event_name": (
							"family_death"
							if personally_relevant_death
							else "death"
						),
						"source": "health_engine",
						"contract_source": "health_contract",
						"suppress_diary": (
							personally_relevant_death
						)
					}
				)

		_:
			committed_death_fanout_queue.pop_front()

			_arm_committed_death_fanout_service()
			return

	row [
		"stage"
	] = stage + 1
	row [
		"last_serviced_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	row [
		"publication_quantum_complete"
	] = true
	row [
		"requires_player_idle"
	] = false
	row [
		"blocks_ui"
	] = false

	committed_death_fanout_queue [
		0
	] = row

	_arm_committed_death_fanout_service()
func export_state() -> Dictionary:
	return {
		"schema": HEALTH_CONTRACT_SCHEMA + "_state",
		"version": HEALTH_CONTRACT_VERSION,
		"health_contract_event_log": health_contract_event_log.duplicate(true),
		"health_contract_index": health_contract_index.duplicate(true),
		"last_health_contract_report": last_health_contract_report.duplicate(true)
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return { "success": false, "reason": "HealthEngine import_state expected a Dictionary."}

	health_contract_event_log = _safe_array(data.get("health_contract_event_log", []))
	health_contract_index = _safe_dictionary(data.get("health_contract_index", {}))
	last_health_contract_report = _safe_dictionary(data.get("last_health_contract_report", {}))

	return {
		"success": true,
		"schema": HEALTH_CONTRACT_SCHEMA + "_state",
		"event_count": health_contract_event_log.size(),
		"index_count": health_contract_index.size()
	}


func route_command_envelope(envelope: Dictionary) -> Dictionary:
	if typeof(envelope) != TYPE_DICTIONARY or envelope.is_empty():
		return { "success": false, "reason": "HealthEngine command envelope is empty."}

	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()
	var payload: Dictionary = _safe_dictionary(envelope.get("payload", {}))

	match command_id:
		"health.observe":
			return observe_health_contracts(payload)
		"health.contracts.recent":
			return observe_health_contracts(payload)
		"health.update":
			var actor: Person = _actor_from_payload(payload)
			update_health(actor)
			return {
				"success": actor != null,
				"mode": "health_update_routed",
				"actor_id": _health_entity_id(actor),
				"last_report": last_health_contract_report.duplicate(true)
			}
		_:
			return { "success": false, "reason": "No HealthEngine route claimed this command.", "command": command_id}


func observe_health_contracts(filters: Dictionary = {}) -> Dictionary:
	var entity_id_filter: int = int(filters.get("entity_id", filters.get("actor_id", -1)))
	var event_type_filter: String = str(filters.get("event_type", "")).strip_edges().to_lower()
	var max_count: int = int(clamp(int(filters.get("max_count", 24)), 1, 120))

	var rows: Array = []
	for i in range(health_contract_event_log.size() - 1, -1, -1):
		if rows.size() >= max_count:
			break

		var raw_event: Variant = health_contract_event_log [i]
		if typeof(raw_event) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = raw_event as Dictionary
		if entity_id_filter > 0 and int(contract.get("entity_id", -1)) != entity_id_filter:
			continue

		if event_type_filter != "" and str(contract.get("event_type", "")).strip_edges().to_lower() != event_type_filter:
			continue

		rows.append(contract.duplicate(true))

	return {
		"success": true,
		"mode": "health_contract_observe",
		"count": rows.size(),
		"contracts": rows
	}


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _actor_from_payload(payload: Dictionary) -> Person:
	if gs == null or typeof(payload) != TYPE_DICTIONARY:
		return null

	var actor_id: int = int(payload.get("actor_id", payload.get("npc_id", payload.get("entity_id", -1))))
	if actor_id <= 0:
		return null

	if gs.player != null and int(gs.player.id) == actor_id:
		return gs.player

	if gs.has_method("get_or_reactivate_npc_by_id"):
		return gs.get_or_reactivate_npc_by_id(actor_id)

	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(actor_id)

	return null


func _health_year() -> int:
	if gs != null and "year" in gs:
		return int(gs.year)
	return 0


func _health_entity_id(entity) -> int:
	if entity == null:
		return -1
	if "id" in entity:
		return int(entity.id)
	return -1


func _health_entity_name(entity) -> String:
	if entity == null:
		return "Unknown"

	var first_name: String = str(entity.first_name).strip_edges() if "first_name" in entity else ""
	var last_name: String = str(entity.last_name).strip_edges() if "last_name" in entity else ""
	var full_name: String = ("%s %s" % [first_name, last_name]).strip_edges()

	if full_name != "":
		return full_name

	if "name" in entity:
		var direct_name: String = str(entity.name).strip_edges()
		if direct_name != "":
			return direct_name

	return "Unknown"


func _health_entity_traits(entity) -> Array:
	if entity == null:
		return []
	if "traits" in entity and typeof(entity.traits) == TYPE_ARRAY:
		return entity.traits.duplicate(true)
	return []


func _health_life_stage_for(entity) -> String:
	if entity == null:
		return "unknown"

	var age: int = int(entity.age) if "age" in entity else 0

	if age <= 2:
		return "baby"
	if age <= 12:
		return "child"
	if age <= 17:
		return "teen"
	if age <= 39:
		return "adult"
	if age <= 64:
		return "middle_age"
	if age <= 89:
		return "elder"
	return "ancient"


func _health_snapshot_for(entity) -> Dictionary:
	if entity == null:
		return {}

	return {
		"entity_id": _health_entity_id(entity),
		"entity_name": _health_entity_name(entity),
		"age": int(entity.age) if "age" in entity else 0,
		"life_stage": _health_life_stage_for(entity),
		"alive": bool(entity.alive) if "alive" in entity else false,
		"health": float(entity.health) if "health" in entity else 0.0,
		"mental_health": float(entity.mental_health) if "mental_health" in entity else 0.0,
		"hunger": float(entity.hunger) if "hunger" in entity else 0.0,
		"cause_of_death": str(entity.cause_of_death) if "cause_of_death" in entity else "",
		"death_year": int(entity.death_year) if "death_year" in entity else -999999,
		"traits": _health_entity_traits(entity)
	}


func _health_contract_id(entity, event_type: String, source: String) -> String:
	var clean_type: String = str(event_type).strip_edges().to_lower().replace(" ", "_")
	var clean_source: String = str(source).strip_edges().to_lower().replace(" ", "_")
	if clean_type == "":
		clean_type = "health_event"
	if clean_source == "":
		clean_source = "health_engine"

	return "health_%s_%s_%s_%d_%d" % [
		str(_health_entity_id(entity)),
		clean_type,
		clean_source,
		int(_health_year()),
		int(Time.get_ticks_msec())
	]


func _build_health_contract(entity, event_type: String, source: String, payload: Dictionary, before_snapshot: Dictionary, after_snapshot: Dictionary) -> Dictionary:
	var clean_type: String = str(event_type).strip_edges().to_lower()
	if clean_type == "":
		clean_type = "health_event"

	var clean_source: String = str(source).strip_edges().to_lower()
	if clean_source == "":
		clean_source = "health_engine"

	var contract_id: String = _health_contract_id(entity, clean_type, clean_source)
	var entity_id: int = _health_entity_id(entity)

	return {
		"schema": HEALTH_EVENT_CONTRACT_SCHEMA,
		"version": HEALTH_CONTRACT_VERSION,
		"contract_id": contract_id,
		"contract_type": "health_event",
		"event_type": clean_type,
		"source": clean_source,
		"entity_id": entity_id,
		"entity_name": _health_entity_name(entity),
		"year": _health_year(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"before": before_snapshot.duplicate(true),
		"after": after_snapshot.duplicate(true),
		"payload": payload.duplicate(true),
		"biological_contract": {
			"source_of_truth": "HealthEngine",
			"applies_to": ["health", "mental_health", "alive", "cause_of_death", "death_year"],
		}
	}


func _record_health_contract(contract: Dictionary, mirror_to_runtime: bool = false) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY or contract.is_empty():
		return { "success": false, "reason": "Health contract was empty."}

	var contract_id: String = str(contract.get("contract_id", "")).strip_edges()
	if contract_id == "":
		contract_id = "health_contract_%d" % int(Time.get_ticks_msec())
		contract ["contract_id"] = contract_id

	health_contract_event_log.append(contract.duplicate(true))
	health_contract_index [contract_id] = {
		"entity_id": int(contract.get("entity_id", -1)),
		"event_type": str(contract.get("event_type", "")),
		"source": str(contract.get("source", "")),
		"year": int(contract.get("year", 0)),
		"created_at_ms": int(contract.get("created_at_ms", 0))
	}

	while health_contract_event_log.size() > health_contract_max_event_log:
		var removed: Variant = health_contract_event_log.pop_front()
		if typeof(removed) == TYPE_DICTIONARY:
			var removed_id: String = str((removed as Dictionary).get("contract_id", "")).strip_edges()
			if removed_id != "":
				health_contract_index.erase(removed_id)

	var runtime_report: Dictionary = {}
	if mirror_to_runtime and health_contract_emit_runtime_contracts:
		runtime_report = _mirror_health_contract_to_runtime(contract)

	last_health_contract_report = {
		"success": true,
		"mode": "health_contract_recorded",
		"contract_id": contract_id,
		"entity_id": int(contract.get("entity_id", -1)),
		"event_type": str(contract.get("event_type", "")),
		"source": str(contract.get("source", "")),
		"log_count": health_contract_event_log.size(),
		"mirrored_to_runtime": not runtime_report.is_empty(),
		"runtime_report": runtime_report.duplicate(true)
	}

	return last_health_contract_report.duplicate(true)


func _mirror_health_contract_to_runtime(contract: Dictionary) -> Dictionary:
	if gs == null:
		return {}

	if not ("runtime_contract_engine" in gs):
		return {}

	var runtime_engine = gs.runtime_contract_engine
	if runtime_engine == null or not runtime_engine.has_method("instantiate_contract"):
		return {}

	var contract_id: String = str(contract.get("contract_id", "")).strip_edges()
	if contract_id == "":
		return {}

	var runtime_contract: Dictionary = {
		"schema": HEALTH_EVENT_CONTRACT_SCHEMA,
		"version": HEALTH_CONTRACT_VERSION,
		"contract_id": "rtc_%s" % contract_id,
		"contract_type": "health_event",
		"runtime_key": "health:%s:%s:%s" % [
			str(contract.get("entity_id", -1)),
			str(contract.get("event_type", "health_event")),
			contract_id
		],
		"state": "active",
		"created_year": _health_year(),
		"updated_year": _health_year(),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"health_event": contract.duplicate(true),
		"subject": {
			"entity_id": int(contract.get("entity_id", -1)),
			"entity_name": str(contract.get("entity_name", "Unknown"))
		},
		"contract_mesh": {
			"tags": ["health", "biology", "mortality", "observable_reality"],
			"can_interact_with": ["relationships", "family", "school", "jobs", "world_feed", "memory", "hospitals", "genetics"],
		}
	}

	var report: Variant = runtime_engine.instantiate_contract(runtime_contract, {
		"source": "health_engine",
	})

	if typeof(report) == TYPE_DICTIONARY:
		return report as Dictionary

	return {}


func _emit_health_observation(entity, event_type: String, source: String, payload: Dictionary, before_snapshot: Dictionary, mirror_to_runtime: bool = false) -> Dictionary:
	var after_snapshot: Dictionary = _health_snapshot_for(entity)
	var contract: Dictionary = _build_health_contract(entity, event_type, source, payload, before_snapshot, after_snapshot)
	return _record_health_contract(contract, mirror_to_runtime)


func _apply_health_delta_contract(entity, delta: float, source: String, context: Dictionary = {}, mirror_to_runtime: bool = false) -> Dictionary:
	if entity == null:
		return { "success": false, "reason": "No entity supplied."}

	var amount: float = float(delta)
	if is_zero_approx(amount):
		return { "success": true, "mode": "health_delta_zero", "entity_id": _health_entity_id(entity)}

	var clean_context: Dictionary = _safe_dictionary(context)
	var before_snapshot: Dictionary = _health_snapshot_for(entity)
	var previous_health: float = float(entity.health)

	entity.health = previous_health + amount

	var payload: Dictionary = clean_context.duplicate(true)
	payload ["delta"] = amount
	payload ["previous_health"] = previous_health
	payload ["new_health"] = float(entity.health)
	payload ["stat"] = "health"

	return _emit_health_observation(entity, "health_delta", source, payload, before_snapshot, mirror_to_runtime)


func _set_health_contract(entity, new_value: float, source: String, context: Dictionary = {}, mirror_to_runtime: bool = false) -> Dictionary:
	if entity == null:
		return { "success": false, "reason": "No entity supplied."}

	var clean_context: Dictionary = _safe_dictionary(context)
	var before_snapshot: Dictionary = _health_snapshot_for(entity)
	var previous_health: float = float(entity.health)

	entity.health = float(new_value)

	var payload: Dictionary = clean_context.duplicate(true)
	payload ["previous_health"] = previous_health
	payload ["new_health"] = float(entity.health)
	payload ["delta"] = float(entity.health) - previous_health
	payload ["stat"] = "health"

	return _emit_health_observation(entity, "health_set", source, payload, before_snapshot, mirror_to_runtime)


func _apply_mental_health_delta_contract(entity, delta: float, source: String, context: Dictionary = {}, mirror_to_runtime: bool = false) -> Dictionary:
	if entity == null:
		return { "success": false, "reason": "No entity supplied."}

	var amount: float = float(delta)
	if is_zero_approx(amount):
		return { "success": true, "mode": "mental_delta_zero", "entity_id": _health_entity_id(entity)}

	var clean_context: Dictionary = _safe_dictionary(context)
	var before_snapshot: Dictionary = _health_snapshot_for(entity)
	var previous_mental: float = float(entity.mental_health)

	entity.mental_health = clamp(previous_mental + amount, 0.0, 100.0)

	var payload: Dictionary = clean_context.duplicate(true)
	payload ["delta"] = amount
	payload ["previous_mental_health"] = previous_mental
	payload ["new_mental_health"] = float(entity.mental_health)
	payload ["stat"] = "mental_health"

	return _emit_health_observation(entity, "mental_health_delta", source, payload, before_snapshot, mirror_to_runtime)


func _emit_state_contract(entity, event_type: String, source: String, context: Dictionary = {}, mirror_to_runtime: bool = false) -> Dictionary:
	if entity == null:
		return { "success": false, "reason": "No entity supplied."}

	var before_snapshot: Dictionary = _safe_dictionary(context.get("before_snapshot", {}))
	var payload: Dictionary = _safe_dictionary(context)
	payload.erase("before_snapshot")

	if before_snapshot.is_empty():
		before_snapshot = _health_snapshot_for(entity)

	return _emit_health_observation(entity, event_type, source, payload, before_snapshot, mirror_to_runtime)


func _sync_death_from_health_or_kill(entity, cause: String) -> bool:
	if entity == null:
		return false

	var clean_cause: String = str(cause).strip_edges()
	if clean_cause == "":
		clean_cause = "Health depleted"

	if gs != null and gs.has_method("sync_person_death_state_from_health"):
		return bool(gs.sync_person_death_state_from_health(entity, clean_cause))

	return try_kill(entity, clean_cause)



func update_health(entity):
	if entity == null:
		return




	if typeof(entity) == TYPE_DICTIONARY:
		var payload: Dictionary = entity as Dictionary
		var requested_entity_id: int = int(
			payload.get(
				"npc_id",
				payload.get(
					"actor_id",
					payload.get(
						"entity_id",
						-1
					)
				)
			)
		)

		var resolved_entity = null

		if (
			gs != null
			and gs.player != null
			and int(gs.player.id) == requested_entity_id
		):
			resolved_entity = gs.player
		elif (
			gs != null
			and requested_entity_id > 0
			and gs.has_method(
				"get_npc_by_id"
			)
		):
			resolved_entity = gs.get_npc_by_id(
				requested_entity_id,
				false
			)

		if resolved_entity == null:
			return

		entity = resolved_entity








	if not bool(entity.alive):
		return








	if _is_immortal_protected(entity):
		_stabilize_immortal(entity)
		return

	if float(entity.health) <= 0.0:
		_set_health_contract(
			entity,
			0.0,
			"pre_tick_health_depleted",
			{
				"cause": "Health depleted",
				"severity": "fatal",
				"biological_resolution": "death_sync"
			},
			true
		)
		_sync_death_from_health_or_kill(
			entity,
			"Health depleted"
		)
		return

	_emit_state_contract(
		entity,
		"health_tick_started",
		"update_health",
		{
			"tick_stage": "start",
			"age": int(entity.age),
			"life_stage": _health_life_stage_for(entity)
		},
		false
	)

	apply_genetics(entity)
	if not entity.alive:
		return

	apply_age_deterioration(entity)
	if not entity.alive:
		return

	apply_lifestyle_effects(entity)
	if not entity.alive:
		return

	apply_illness_chance(entity)
	if not entity.alive:
		return

	apply_injury_chance(entity)
	if not entity.alive:
		return

	if _maybe_apply_controlled_era_death_accident(entity):
		return

	apply_mental_health_drift(entity)
	if not entity.alive:
		return

	var health_cap: float = 200.0
	var health_bonus_divisor: float = max(
		health_cap / 10.0,
		1.0
	)
	var clamped_health: float = clamp(
		float(entity.health),
		0.0,
		health_cap
	)

	if not is_equal_approx(
		clamped_health,
		float(entity.health)
	):
		_set_health_contract(
			entity,
			clamped_health,
			"health_cap_clamp",
			{
				"health_cap": health_cap,
				"reason": "post_biology_clamp"
			},
			false
		)

	if enforce_mortal_age_cap(entity):
		return

	var age_chance: int = 0

	if entity.age < 45:
		age_chance = 0
	elif entity.age >= 45 and entity.age < 60:
		age_chance = 1
	elif entity.age >= 60 and entity.age < 70:
		age_chance = 2
	elif entity.age >= 70 and entity.age < 80:
		age_chance = 4
	elif entity.age >= 80 and entity.age < 90:
		age_chance = 8
	elif entity.age >= 90 and entity.age < 100:
		age_chance = 15
	elif entity.age >= 100 and entity.age < 110:
		age_chance = 28
	elif entity.age >= 110 and entity.age < 120:
		age_chance = 45
	elif entity.age >= 120:
		age_chance = 65

	var disease_rate: float = 1.0

	if (
		gs != null
		and gs.era_engine != null
		and gs.era_engine.has_method(
			"get_disease_rate"
		)
	):
		disease_rate = float(
			gs.era_engine.get_disease_rate()
		)

	age_chance = int(
		age_chance * disease_rate
	)

	var health_bonus: int = int(
		float(entity.health) / health_bonus_divisor
	)
	var mental_bonus: int = int(
		entity.mental_health / 20
	)

	age_chance = max(
		age_chance - health_bonus - mental_bonus,
		0
	)

	if (
		age_chance > 0
		and randi() % 100 < age_chance
	):
		var dkey = _random_disease_for(entity)

		_set_health_contract(
			entity,
			0.0,
			"age_disease_roll",
			{
				"disease_key": dkey,
				"cause": disease_causes [dkey],
				"severity": "fatal",
				"age_chance": age_chance,
				"disease_rate": disease_rate
			},
			true
		)

		_sync_death_from_health_or_kill(
			entity,
			disease_causes [dkey]
		)
		return

	if entity.health <= 0:
		var dkey2 = _random_disease_for(entity)

		_set_health_contract(
			entity,
			0.0,
			"post_tick_health_depleted",
			{
				"disease_key": dkey2,
				"cause": disease_causes [dkey2],
				"severity": "fatal"
			},
			true
		)

		_sync_death_from_health_or_kill(
			entity,
			disease_causes [dkey2]
		)
		return

	_emit_state_contract(
		entity,
		"health_tick_completed",
		"update_health",
		{
			"tick_stage": "complete",
			"age": int(entity.age),
			"life_stage": _health_life_stage_for(entity)
		},
		false
	)
func _random_disease_for(entity):

	if "Smoker" in entity.traits and randi() % 100 < 30:
		return "cancer_lung"

	if "Alcoholic" in entity.traits and randi() % 100 < 25:
		return "alcohol_liver_failure"

	if entity.age >= 70:
		var elderly = [
			"heart_attack",
			"stroke",
			"organ_failure",
			"pneumonia"
		]
		return elderly [randi() % elderly.size()]

	var pool = [
		"flu_complications",
		"pneumonia",
		"diabetes_complication"
	]

	return pool [randi() % pool.size()]





func apply_genetics(entity):
	if entity == null:
		return

	var health_cap: float = 200.0
	var health_scale: float = health_cap / 100.0

	if "StrongImmuneSystem" in entity.traits:
		_apply_health_delta_contract(entity, 1.0 * health_scale, "genetics_strong_immune_system", {
			"trait": "StrongImmuneSystem",
			"domain": "genetics",
			"health_scale": health_scale
		}, false)

	if "WeakImmuneSystem" in entity.traits:
		var weak_delta: float = - (randf() * 3.0 * health_scale)
		_apply_health_delta_contract(entity, weak_delta, "genetics_weak_immune_system", {
			"trait": "WeakImmuneSystem",
			"domain": "genetics",
			"health_scale": health_scale
		}, false)
func _health_current_era_name() -> String:
	if gs == null:
		return "Modern Era"

	if gs.era != null:
		if typeof(gs.era) == TYPE_DICTIONARY:
			return str((gs.era as Dictionary).get("name", "Modern Era"))
		if "name" in gs.era:
			return str(gs.era.name)

	return "Modern Era"


func _era_mortal_age_contract(entity) -> Dictionary:
	var era_name: String = _health_current_era_name()
	var min_cap: int = 78
	var max_cap: int = int(gs.MAX_MORTAL_AGE) if gs != null else 130
	var decline_start: int = 55

	match era_name:
		"Ancient Era":
			min_cap = 48
			max_cap = 72
			decline_start = 34
		"Medieval Era":
			min_cap = 52
			max_cap = 78
			decline_start = 38
		"Industrial Era":
			min_cap = 62
			max_cap = 92
			decline_start = 48
		"Modern Era":
			min_cap = 76
			max_cap = 108
			decline_start = 58
		"Future Era":
			min_cap = 92
			max_cap = max(118, int(gs.MAX_MORTAL_AGE) if gs != null else 130)
			decline_start = 72

	if max_cap < min_cap:
		var swap_value: int = min_cap
		min_cap = max_cap
		max_cap = swap_value

	var entity_id: int = int(entity.id) if entity != null else 0
	var span: int = max(1, max_cap - min_cap + 1)
	var stable_offset: int = abs((entity_id * 1103515245) + 12345) % span
	var personal_cap: int = min_cap + stable_offset

	return {
		"era_name": era_name,
		"min_cap": min_cap,
		"max_cap": max_cap,
		"cap": personal_cap,
		"decline_start": min(decline_start, max(1, personal_cap - 8)),
		"source": "era_mortal_age_contract"
	}


func _old_age_pressure_ratio(entity) -> float:
	if entity == null:
		return 0.0

	var contract: Dictionary = _era_mortal_age_contract(entity)
	var cap: int = int(contract.get("cap", 100))
	var decline_start: int = int(contract.get("decline_start", max(45, cap - 25)))
	var age_value: int = int(entity.age)

	if age_value < decline_start:
		return 0.0

	return clamp(float(age_value - decline_start) / max(1.0, float(cap - decline_start)), 0.0, 1.35)


func _era_accident_death_cause_for(_entity) -> String:
	var era_name: String = _health_current_era_name()

	match era_name:
		"Ancient Era":
			return "Trampled during a deeply unserious goat stampede"
		"Medieval Era":
			return "Flattened by a runaway turnip cart"
		"Industrial Era":
			return "Caught by a factory machine that clearly had beef"
		"Modern Era":
			return "Ignored a wet floor sign like the main character"
		"Future Era":
			return "Lost an argument with an experimental hover toaster"
		_:
			return "A bizarre accident"


func _maybe_apply_controlled_era_death_accident(entity) -> bool:
	if entity == null or gs == null or gs.player == null:
		return false

	if int(entity.id) != int(gs.player.id):
		return false

	if not bool(entity.alive):
		return false

	if _is_immortal_protected(entity):
		return false

	if int(entity.age) < 4:
		return false

	var era_name: String = _health_current_era_name()
	var roll_cap: int = 950

	match era_name:
		"Ancient Era":
			roll_cap = 720
		"Medieval Era":
			roll_cap = 780
		"Industrial Era":
			roll_cap = 900
		"Modern Era":
			roll_cap = 1100
		"Future Era":
			roll_cap = 1250

	var old_age_pressure: float = _old_age_pressure_ratio(entity)
	if old_age_pressure > 0.0:
		roll_cap = max(260, int(float(roll_cap) * (1.0 - min(old_age_pressure, 0.75))))

	if randi() % roll_cap != 1:
		return false

	var cause: String = _era_accident_death_cause_for(entity)

	_set_health_contract(entity, 0.0, "controlled_era_death_accident", {
		"domain": "accident",
		"severity": "fatal",
		"cause": cause,
		"era_name": era_name,
		"old_age_pressure": old_age_pressure
	}, true)

	try_kill(entity, cause)
	return true



func apply_age_deterioration(entity):
	if entity == null:
		return

	var disease_rate: float = 1.0
	if gs != null and gs.era_engine != null and gs.era_engine.has_method("get_disease_rate"):
		disease_rate = float(gs.era_engine.get_disease_rate())

	var health_cap: float = 200.0
	var health_scale: float = health_cap / 100.0
	var contract: Dictionary = _era_mortal_age_contract(entity)
	var decline_start: int = int(contract.get("decline_start", 45))
	var personal_cap: int = int(contract.get("cap", int(gs.MAX_MORTAL_AGE) if gs != null else 130))
	var pressure: float = _old_age_pressure_ratio(entity)

	if int(entity.age) < decline_start:
		return

	var base_min: float = 0.08
	var base_max: float = 0.35

	if int(entity.age) >= personal_cap - 20:
		base_min = 0.25
		base_max = 0.9
	if int(entity.age) >= personal_cap - 10:
		base_min = 0.55
		base_max = 1.65
	if int(entity.age) >= personal_cap - 4:
		base_min = 1.15
		base_max = 3.2

	var pressure_multiplier: float = 1.0 + (pressure * 2.35)
	var delta: float = - (randf_range(base_min, base_max) * disease_rate * health_scale * pressure_multiplier)

	_apply_health_delta_contract(entity, delta, "era_old_age_deterioration", {
		"domain": "aging",
		"age": int(entity.age),
		"life_stage": _health_life_stage_for(entity),
		"disease_rate": disease_rate,
		"health_scale": health_scale,
		"era_name": str(contract.get("era_name", _health_current_era_name())),
		"mortal_age_cap": personal_cap,
		"decline_start": decline_start,
		"old_age_pressure": pressure
	}, false)



func apply_lifestyle_effects(entity):
	if entity == null:
		return

	var health_cap: float = 200.0
	var health_scale: float = health_cap / 100.0

	if "Smoker" in entity.traits:
		_apply_health_delta_contract(entity, - (randf() * 4.0 * health_scale), "lifestyle_smoker", {
			"domain": "lifestyle",
			"trait": "Smoker",
			"health_scale": health_scale
		}, false)

	if "Alcoholic" in entity.traits:
		_apply_health_delta_contract(entity, - (randf() * 3.0 * health_scale), "lifestyle_alcoholic", {
			"domain": "lifestyle",
			"trait": "Alcoholic",
			"health_scale": health_scale
		}, false)

	if "Athletic" in entity.traits:
		_apply_health_delta_contract(entity, randf() * 2.0 * health_scale, "lifestyle_athletic", {
			"domain": "lifestyle",
			"trait": "Athletic",
			"health_scale": health_scale
		}, false)

	if "JunkFoodAddict" in entity.traits:
		_apply_health_delta_contract(entity, - (randf() * 1.5 * health_scale), "lifestyle_junk_food_addict", {
			"domain": "lifestyle",
			"trait": "JunkFoodAddict",
			"health_scale": health_scale
		}, false)

func _get_minor_illness_ppm(entity) -> int:
	var age:= int(entity.age)
	var base_ppm:= 0

	if age <= 4:
		base_ppm = 1
	elif age <= 12:
		base_ppm = 2
	elif age <= 17:
		base_ppm = 3
	elif age <= 39:
		base_ppm = 5
	elif age <= 59:
		base_ppm = 7
	elif age <= 74:
		base_ppm = 10
	elif age <= 89:
		base_ppm = 14
	else:
		base_ppm = 18

	if "StrongImmuneSystem" in entity.traits:
		base_ppm = max(0, base_ppm - 2)
	if "WeakImmuneSystem" in entity.traits:
		base_ppm += 3

	var disease_rate: float = max(float(gs.era_engine.get_disease_rate()), 0.1)
	base_ppm = int(round(base_ppm * disease_rate))

	var cooldown_years:= 2
	if age <= 12:
		cooldown_years = 3
	elif age <= 17:
		cooldown_years = 2

	if age - int(entity.last_minor_illness_age) <= cooldown_years:
		base_ppm = 0

	return int(clamp(base_ppm, 0, 1000))


func _get_major_illness_ppm(entity) -> int:
	var age:= int(entity.age)
	var base_ppm:= 0

	if age < 18:
		base_ppm = 0
	elif age <= 39:
		base_ppm = 1
	elif age <= 59:
		base_ppm = 2
	elif age <= 74:
		base_ppm = 4
	elif age <= 89:
		base_ppm = 8
	else:
		base_ppm = 14

	if "StrongImmuneSystem" in entity.traits:
		base_ppm = max(0, base_ppm - 1)
	if "WeakImmuneSystem" in entity.traits:
		base_ppm += 2

	var disease_rate: float = max(float(gs.era_engine.get_disease_rate()), 0.1)
	base_ppm = int(round(base_ppm * disease_rate))

	return int(clamp(base_ppm, 0, 1000))



func apply_illness_chance(entity):
	if entity == null or not entity.alive:
		return

	var health_cap: float = 200.0
	var health_scale: float = health_cap / 100.0
	var major_ppm: int = _get_major_illness_ppm(entity)
	var minor_ppm: int = _get_minor_illness_ppm(entity)
	if major_ppm <= 0 and minor_ppm <= 0:
		return

	var roll: int = randi() % 1000

	if roll < major_ppm:
		var major_context: Dictionary = {
			"domain": "illness",
			"severity": "major",
			"roll": roll,
			"major_ppm": major_ppm,
			"minor_ppm": minor_ppm,
			"health_scale": health_scale
		}

		_apply_health_delta_contract(entity, - (20.0 * health_scale), "illness_major", major_context, true)
		_emit_illness_event_bus_contract(entity, "major", major_context)

		if gs != null and gs.narrative_engine != null and not _life_engine_should_route_illness_to_pending_situations(entity):
			gs.narrative_engine.log_event(entity, {
				"type": "illness_major",
				"source": "life_engine_illness",
			})

		return

	if roll < major_ppm + minor_ppm:
		var minor_delta: float = 0.0
		if entity.age < 18:
			minor_delta = - (randf_range(1.0, 3.0) * health_scale)
		else:
			minor_delta = - (randf_range(3.0, 5.0) * health_scale)

		var minor_context: Dictionary = {
			"domain": "illness",
			"severity": "minor",
			"roll": roll,
			"major_ppm": major_ppm,
			"minor_ppm": minor_ppm,
			"health_scale": health_scale
		}

		_apply_health_delta_contract(entity, minor_delta, "illness_minor", minor_context, true)

		entity.last_minor_illness_age = entity.age
		_emit_state_contract(entity, "minor_illness_cooldown_marked", "illness_minor", {
			"last_minor_illness_age": int(entity.last_minor_illness_age)
		}, false)

		_emit_illness_event_bus_contract(entity, "minor", minor_context)

		if gs != null and gs.narrative_engine != null and not _life_engine_should_route_illness_to_pending_situations(entity):
			gs.narrative_engine.log_event(entity, {
				"type": "illness_minor",
				"source": "life_engine_illness",
			})
func _emit_illness_event_bus_contract(entity: Person, severity: String, context: Dictionary = {}) -> void:
	if gs == null or entity == null:
		return

	var clean_severity: String = str(severity).strip_edges().to_lower()
	if clean_severity == "":
		clean_severity = "minor"

	var event_type: String = "illness_major" if clean_severity == "major" else "illness_minor"

	if gs.event_bus != null and gs.event_bus.has_method("emit"):
		gs.event_bus.emit(event_type, {
			"source": "life_engine_apply_illness_chance",
			"npc_id": int(entity.id),
			"actor_id": int(entity.id),
			"person_id": int(entity.id),
			"severity": clean_severity,
			"illness_severity": clean_severity,
			"age": int(entity.age),
			"health": float(entity.health),
			"health_delta_context": context.duplicate(true),
			"pending_situation_preferred": _life_engine_should_route_illness_to_pending_situations(entity),
			"suppress_world_feed": _life_engine_should_route_illness_to_pending_situations(entity),
			"dispatch_lane": "important",
			"qos_tier": "important"
		})


func _life_engine_should_route_illness_to_pending_situations(entity: Person) -> bool:
	if gs == null or gs.player == null or entity == null:
		return false

	if int(entity.id) == int(gs.player.id):
		return false

	var player: Person = gs.player
	var entity_id: int = int(entity.id)
	var player_id: int = int(player.id)

	if entity_id in player.parents:
		return true

	if entity_id in player.children:
		return true

	if player_id in entity.parents:
		return true

	if player_id in entity.children:
		return true

	if entity.partner != null and int(entity.partner.id) == player_id:
		return true

	if player.partner != null and int(player.partner.id) == entity_id:
		return true

	for raw_parent_id in player.parents:
		var parent_id: int = int(raw_parent_id)
		if parent_id > 0 and parent_id in entity.parents:
			return true

	return false



func apply_injury_chance(entity):
	if entity == null or not entity.alive:
		return

	var health_cap: float = 200.0
	var health_scale: float = health_cap / 100.0

	if "Clumsy" in entity.traits and randi() % 200 < 3:
		_apply_health_delta_contract(entity, - (15.0 * health_scale), "injury_clumsy_trait", {
			"domain": "injury",
			"trait": "Clumsy",
			"severity": "moderate",
			"health_scale": health_scale
		}, true)

		if gs != null and gs.narrative_engine != null:
			gs.narrative_engine.log_event(entity, { "type": "injury"})


	if randi() % 2000 == 1:
		_set_health_contract(entity, 0.0, "fatal_accident_roll", {
			"domain": "injury",
			"severity": "fatal",
			"cause": disease_causes ["fatal_injury"]
		}, true)
		try_kill(entity, disease_causes ["fatal_injury"])
		return





func apply_mental_health_drift(entity):
	if entity == null:
		return

	var delta: float = - (randf() * 0.5)
	var causes: Array = ["baseline_drift"]

	if "Anxious" in entity.traits:
		delta -= randf() * 2
		causes.append("Anxious")

	if "Optimist" in entity.traits:
		delta += randf() * 1.5
		causes.append("Optimist")

	_apply_mental_health_delta_contract(entity, delta, "mental_health_drift", {
		"domain": "mental_health",
		"causes": causes,
		"traits": _health_entity_traits(entity)
	}, false)

func _is_immortal_protected(entity) -> bool:
	if entity == null:
		return false

	return "Immortal" in entity.traits

func enforce_mortal_age_cap(entity) -> bool:
	if entity == null:
		return false

	if not entity.alive:
		return false

	if _is_immortal_protected(entity):
		return false

	var contract: Dictionary = _era_mortal_age_contract(entity)
	var mortal_age_cap: int = int(contract.get("cap", int(gs.MAX_MORTAL_AGE) if gs != null else 130))
	var decline_start: int = int(contract.get("decline_start", max(45, mortal_age_cap - 25)))
	var era_name: String = str(contract.get("era_name", _health_current_era_name()))

	if int(entity.age) >= mortal_age_cap:
		_set_health_contract(entity, 0.0, "era_mortal_age_cap_enforced", {
			"domain": "aging",
			"severity": "fatal",
			"cause": disease_causes ["old_age"],
			"era_name": era_name,
			"mortal_age_cap": mortal_age_cap,
			"decline_start": decline_start
		}, true)

		try_kill(entity, disease_causes ["old_age"])
		return true

	if int(entity.age) >= decline_start:
		var pressure: float = _old_age_pressure_ratio(entity)
		var pressure_delta: float = - (randf_range(0.15, 0.85) * max(0.05, pressure) * 2.0)

		_apply_health_delta_contract(entity, pressure_delta, "era_old_age_cap_pressure", {
			"domain": "aging",
			"severity": "pressure",
			"era_name": era_name,
			"mortal_age_cap": mortal_age_cap,
			"decline_start": decline_start,
			"old_age_pressure": pressure
		}, false)

		if float(entity.health) <= 0.0:
			_set_health_contract(entity, 0.0, "era_old_age_pressure_depleted_health", {
				"domain": "aging",
				"severity": "fatal",
				"cause": disease_causes ["old_age"],
				"era_name": era_name,
				"mortal_age_cap": mortal_age_cap,
				"old_age_pressure": pressure
			}, true)

			try_kill(entity, disease_causes ["old_age"])
			return true

	return false
func _stabilize_immortal(entity) -> void:
	if entity == null:
		return







	if not bool(entity.alive):
		return

	var before_snapshot: Dictionary = _health_snapshot_for(entity)




	entity.cause_of_death = ""

	if "death_year" in entity:
		entity.death_year = -999999

	var health_floor: float = 200.0
	var mental_floor: float = 100.0


	if "RedBonnetBearer" in entity.traits:
		health_floor = 200.0
		mental_floor = 200.0

	entity.health = max(
		float(entity.health),
		health_floor
	)
	entity.mental_health = max(
		float(entity.mental_health),
		mental_floor
	)

	_emit_state_contract(
		entity,
		"immortality_stabilized",
		"immortality_guard",
		{
			"before_snapshot": before_snapshot,
			"domain": "immortality",
			"health_floor": health_floor,
			"mental_floor": mental_floor,
			"traits": _health_entity_traits(entity),
		},
		true
	)

func try_kill(entity, cause: String, self_inflicted: bool = false) -> bool:
	if entity == null:
		return false

	var clean_cause: String = str(cause).strip_edges()
	if clean_cause == "":
		clean_cause = "Unknown causes"


	if _is_immortal_protected(entity) and not self_inflicted:
		_emit_state_contract(entity, "death_prevented_by_immortality", "try_kill", {
			"domain": "immortality",
			"cause": clean_cause,
			"self_inflicted": self_inflicted,
			"prevented": true
		}, true)
		_stabilize_immortal(entity)
		return false

	_emit_state_contract(entity, "death_requested", "try_kill", {
		"cause": clean_cause,
		"self_inflicted": self_inflicted
	}, true)

	handle_death(entity, clean_cause)
	return true



func handle_death(entity, cause: String):
	if entity == null:
		return

	var clean_cause: String = str(cause).strip_edges()
	if clean_cause == "":
		clean_cause = "Unknown causes"


	if not entity.alive and entity.cause_of_death != "":
		if "death_year" in entity and int(entity.death_year) <= -999000 and gs != null:
			entity.death_year = int(gs.year)

		_emit_state_contract(entity, "duplicate_death_guarded", "handle_death", {
			"cause": clean_cause,
			"existing_cause": str(entity.cause_of_death),
		}, false)
		return

	var before_snapshot: Dictionary = _health_snapshot_for(entity)

	entity.alive = false
	entity.health = 0
	entity.cause_of_death = clean_cause

	if "death_year" in entity and gs != null:
		entity.death_year = int(gs.year)

	_emit_state_contract(entity, "death", "handle_death", {
		"before_snapshot": before_snapshot,
		"domain": "mortality",
		"severity": "fatal",
		"cause": clean_cause,
		"age": int(entity.age),
		"death_year": int(entity.death_year) if "death_year" in entity else _health_year(),
	}, true)

	if gs != null and gs.narrative_engine != null:
		gs.narrative_engine.log_event(entity, {
			"type": "death",
			"cause": clean_cause
		})

	if (
		gs != null
		and gs.event_bus != null
		and entity == gs.player
	):
		gs.event_bus.emit(
			ActionEventTypes.PLAYER_DIED,
			{
				"npc_id": entity.id,
				"cause": clean_cause,
				"source": "health_engine",
				"qos_tier": "important",
				"fanout_hints": {
					"force_defer_bus": true,
					"player_idle_required": false,
					"ready_gate_member": false
				}
			}
		)
	if (
		gs != null
		and gs.has_method(
			"mark_surviving_spouse_widowed"
		)
	):
		gs.mark_surviving_spouse_widowed(
			entity
		)
	if (
		gs != null
		and gs.event_bus != null
	):
		gs.event_bus.emit(
			ActionEventTypes.NPC_DIED,
			{
				"npc_id": entity.id,
				"cause": clean_cause,
				"source": "health_engine",
				"qos_tier": "important",
				"fanout_hints": {
					"force_defer_bus": true,
					"player_idle_required": false,
					"ready_gate_member": false
				}
			}
		)

	var msg = _build_death_text(entity)
	var personally_relevant_death: bool = msg != ""

	if gs != null and entity != gs.player and gs.has_method("queue_known_person_death_message"):
		gs.queue_known_person_death_message(entity)
	elif gs != null and personally_relevant_death:
		gs.pending_death_messages.append(msg)
		gs.queue_year_resolution_popup({
			"popup_title": "Death",
			"popup_text": msg,
			"popup_footer": "Tap anywhere to continue."
		})

	var full_name: String = ("%s %s" % [str(entity.first_name), str(entity.last_name)]).strip_edges()
	var world_text:= "%s died at age %d. Cause: %s." % [
		full_name,
		int(entity.age),
		str(entity.cause_of_death)
	]

	if gs != null and gs.has_method("build_death_world_feed_text"):
		world_text = gs.build_death_world_feed_text(
			full_name,
			int(entity.age),
			str(entity.cause_of_death),
			int(entity.id)
		)

	if gs != null and gs.has_method("push_world_feed"):
		gs.push_world_feed(world_text, {
			"npc_id": entity.id,
			"relation_label": "family_death" if personally_relevant_death else "",
			"personally_relevant": personally_relevant_death,
			"category": "death",
			"event_name": "family_death" if personally_relevant_death else "death",
			"source": "health_engine",
			"contract_source": "health_contract",
			"suppress_diary": personally_relevant_death
		})
func _build_ancestor_death_text(entity, _p: Person, dad: Person, mom: Person) -> String:



	var mgf: Person = null
	var mgm: Person = null
	var pgf: Person = null
	var pgm: Person = null

	if mom != null:
		if mom.parents.size() > 0:
			mgf = gs.get_npc_by_id(int(mom.parents [0]))
			if entity.id == int(mom.parents [0]):
				return "️ My maternal grandfather %s %s has died at age %d from %s." % [
					entity.first_name, entity.last_name, entity.age, entity.cause_of_death
				]

		if mom.parents.size() > 1:
			mgm = gs.get_npc_by_id(int(mom.parents [1]))
			if entity.id == int(mom.parents [1]):
				return "️ My maternal grandmother %s %s has died at age %d from %s." % [
					entity.first_name, entity.last_name, entity.age, entity.cause_of_death
				]

	if dad != null:
		if dad.parents.size() > 0:
			pgf = gs.get_npc_by_id(int(dad.parents [0]))
			if entity.id == int(dad.parents [0]):
				return "️ My paternal grandfather %s %s has died at age %d from %s." % [
					entity.first_name, entity.last_name, entity.age, entity.cause_of_death
				]

		if dad.parents.size() > 1:
			pgm = gs.get_npc_by_id(int(dad.parents [1]))
			if entity.id == int(dad.parents [1]):
				return "️ My paternal grandmother %s %s has died at age %d from %s." % [
					entity.first_name, entity.last_name, entity.age, entity.cause_of_death
				]




	if mgf != null:
		if mgf.parents.size() > 0 and entity.id == int(mgf.parents [0]):
			return "️ My Maternal Great-Grandfather %s %s has died at age %d from %s." % [
				entity.first_name, entity.last_name, entity.age, entity.cause_of_death
			]
		if mgf.parents.size() > 1 and entity.id == int(mgf.parents [1]):
			return "️ My Maternal Great-Grandmother %s %s has died at age %d from %s." % [
				entity.first_name, entity.last_name, entity.age, entity.cause_of_death
			]

	if mgm != null:
		if mgm.parents.size() > 0 and entity.id == int(mgm.parents [0]):
			return "️ My Maternal Great-Grandfather %s %s has died at age %d from  %s." % [
				entity.first_name, entity.last_name, entity.age, entity.cause_of_death
			]
		if mgm.parents.size() > 1 and entity.id == int(mgm.parents [1]):
			return "️ My Maternal Great-Grandmother %s %s has died at age %d from  %s." % [
				entity.first_name, entity.last_name, entity.age, entity.cause_of_death
			]

	if pgf != null:
		if pgf.parents.size() > 0 and entity.id == int(pgf.parents [0]):
			return "️ My Paternal Great-grandfather %s %s has died at age %d from %s." % [
				entity.first_name, entity.last_name, entity.age, entity.cause_of_death
			]
		if pgf.parents.size() > 1 and entity.id == int(pgf.parents [1]):
			return "️ My Paternal Great-grandmother %s %s has died at age %d from %s." % [
				entity.first_name, entity.last_name, entity.age, entity.cause_of_death
			]

	if pgm != null:
		if pgm.parents.size() > 0 and entity.id == int(pgm.parents [0]):
			return "️ My Paternal Great-Grandfather %s %s has died at age %d from %s." % [
				entity.first_name, entity.last_name, entity.age, entity.cause_of_death
			]
		if pgm.parents.size() > 1 and entity.id == int(pgm.parents [1]):
			return "️ My Paternal Great-Grandmother %s %s has died at age %d from %s." % [
				entity.first_name, entity.last_name, entity.age, entity.cause_of_death
			]

	return ""





func _build_death_text(entity) -> String:
	var p = gs.player
	var dad = null
	var mom = null
	if p.parents.size() > 0:
		dad = gs.get_npc_by_id(p.parents [0])
	if p.parents.size() > 1:
		mom = gs.get_npc_by_id(p.parents [1])

	if entity == p:
		return "\n💀\n I died at age %d from %s." % [
			p.age, p.cause_of_death
		]

	if p.parents.size() > 0 and entity.id == p.parents [0]:
		return "\n🕊\n My father %s died at age %d from %s." % [
			entity.first_name, entity.age, entity.cause_of_death
		]
	if p.parents.size() > 1 and entity.id == p.parents [1]:
		return "\n🕊\n My mother %s died at age %d from %s." % [
			entity.first_name, entity.age, entity.cause_of_death
		]

	if p.id in entity.parents:
		var label = "son" if entity.gender == "Male" else "daughter"
		return "\n🕊\n My %s %s died at age %d from %s." % [
			label,
			entity.first_name,
			entity.age,
			entity.cause_of_death
		]

	if entity.parents == p.parents:
		var label2 = "brother" if entity.gender == "Male" else "sister"
		return "\n🕊\n My %s %s died at age %d from %s." % [
			label2,
			entity.first_name,
			entity.age,
			entity.cause_of_death
		]

	var ancestor_msg:= _build_ancestor_death_text(entity, p, dad, mom)
	if ancestor_msg != "":
		return ancestor_msg

	return ""