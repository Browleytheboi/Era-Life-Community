extends Resource
class_name WarContractEngine

const ENGINE_SCHEMA:= "eralife.war_contract_engine"
const CONTRACT_VERSION:= 1
const WAR_REGISTRY_PATH:= "user://war/war_registry.json"



const ERA_KINGDOM_WAR_REALM_ID: int = -900001



const TERABITHIA_WAR_REALM_ID: int = -900002

const WAR_STALEMATE_YEAR_LIMIT: int = 10

var gs
var war_registry: Dictionary = {}
var last_report: Dictionary = {}



var war_persistence_tail_armed: bool = false
var queued_war_declaration_jobs: Array = []
var queued_war_declaration_service_armed: bool = false
func _init(_gs = null):
	gs = _gs
	_ensure_state()

func bind_game_state(
		_gs = null
) -> void:
		if gs == _gs:
			_ensure_state()
			return

		gs = _gs





		war_registry = {}
		last_report = {}
		war_persistence_tail_armed = false
		queued_war_declaration_jobs.clear()
		queued_war_declaration_service_armed = false

		_ensure_state()
func route_command_envelope(
	envelope: Dictionary
) -> Dictionary:
	var command_id: String = str(
		envelope.get(
			"command",
			envelope.get(
				"action_id",
				""
			)
		)
	).strip_edges().to_lower()

	match command_id:
		"war.emit_registry", "emit_war_registry":
			return emit_war_registry_contract(
				envelope
			)

		"war.emit_preview", "preview_war":
			return emit_war_preview_contract(
				envelope
			)

		"war.declare", "declare_war":
			return declare_war_contract(
				envelope
			)

		"war.set_strategy", "set_war_strategy":
			return set_war_strategy(
				envelope
			)

		"war.request_join", "request_join_war":
			return request_join_war(
				envelope
			)

		"war.advance_year", "advance_wars":
			return advance_wars_to_year(
				envelope
			)

		"war.yearly_tick", "yearly_tick":
			return yearly_tick(
				envelope
			)

		"war.resolve_outcome", "resolve_war_outcome":
			return resolve_war_outcome(
				envelope
			)

		_:
			return _fail(
				"unknown_war_command",
				"WarContractEngine did not recognize command.",
				envelope
			)
func yearly_tick(
	payload: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var year: int = int(
		payload.get(
			"year",
			int(
				gs.year
				if gs != null
				else 0
			)
		)
	)

	if year <= 0:
		return _fail(
			"invalid_yearly_war_tick",
			"War yearly simulation requires a valid world year.",
			payload
		)



	_materialize_realm_relation_matrix()

	var advanced_count: int = (
		_advance_registry_to_year(
			year
		)
	)
	var auto_outcome_count: int = (
		_auto_resolve_awaiting_wars(
			year
		)
	)
	var autonomous_declarations: Array = (
		_service_autonomous_war_declarations(
			year
		)
	)

	war_registry [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	war_registry [
		"last_world_year_serviced"
	] = year

	last_report = {
		"schema": (
			"eralife.war.yearly_world_report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"committed": true,
		"year": year,
		"advanced_war_count": advanced_count,
		"auto_outcome_count": auto_outcome_count,
		"autonomous_declaration_count": (
			autonomous_declarations.size()
		),
		"autonomous_declarations": (
			autonomous_declarations
		),
		"simulation_trigger": (
			"world_year"
		),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_queue_war_persistence_tail()

	return last_report.duplicate(false)
func _service_autonomous_war_declarations(
	year: int
) -> Array:
	var reports: Array = []

	if (
		gs == null
		or gs.realm_engine == null
	):
		return reports

	var realm_ids: Array = []

	for raw_realm_id in gs.realm_engine.realms.keys():
		var realm_id: int = int(
			raw_realm_id
		)

		if (
			realm_id > 0
			and realm_id not in realm_ids
		):
			realm_ids.append(
				realm_id
			)

	realm_ids.sort()

	for left_index in range(
		realm_ids.size()
	):
		for right_index in range(
			left_index + 1,
			realm_ids.size()
		):
			var left_id: int = int(
				realm_ids [
					left_index
				]
			)
			var right_id: int = int(
				realm_ids [
					right_index
				]
			)
			var relation_score: int = _relation_score(
				left_id,
				right_id
			)
			var relation_tier: String = (
				_relation_tier_for_score(
					relation_score
				)
			)

			if relation_tier not in [
				"hostile",
				"enemy"
			]:
				continue

			if not _active_war_between(
				left_id,
				right_id
			).is_empty():
				continue

			var probability: float = (
				0.0
			)

			if relation_score <= -80:
				probability = 0.22
			elif relation_score <= -70:
				probability = 0.15
			elif relation_score <= -55:
				probability = 0.08
			elif relation_score <= -45:
				probability = 0.04

			if probability <= 0.0:
				continue

			var roll_hash: int = abs(
				hash(
					"%d:%d:%d:%d:auto_war"
					% [
						_war_world_seed(),
						year,
						left_id,
						right_id
					]
				)
			)
			var roll: float = (
				float(
					roll_hash % 10000
				) / 10000.0
			)

			if roll > probability:
				continue

			var direction_hash: int = abs(
				hash(
					"%d:%d:%d:auto_war_direction"
					% [
						year,
						left_id,
						right_id
					]
				)
			)
			var attacker_realm_id: int = (
				left_id
				if direction_hash % 2 == 0
				else right_id
			)
			var defender_realm_id: int = (
				right_id
				if attacker_realm_id == left_id
				else left_id
			)
			var declaration: Dictionary = (
				declare_war_contract(
					{
						"attacker_realm_id": (
							attacker_realm_id
						),
						"defender_realm_id": (
							defender_realm_id
						),
						"year": year,
						"declaration_source": (
							"autonomous_world_year"
						),
						"casus_belli": (
							"hostile_realm_relations"
						),
						"ui_is_renderer_only": false
					}
				)
			)

			if bool(
				declaration.get(
					"success",
					false
				)
			):
				reports.append(
					declaration
				)

	return reports

func emit_war_registry_contract(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var observed_realm_id: int = int(
		context.get(
			"realm_id",
			context.get(
				"actor_realm_id",
				-1
			)
		)
	)
	var include_global_active_wars: bool = bool(
		context.get(
			"include_global_active_wars",
			false
		)
	)
	var wars: Dictionary = _safe_dictionary(
		war_registry.get(
			"wars",
			{}
		)
	)
	var observer_active_wars: Array = []
	var global_active_wars: Array = []
	var observer_history: Array = []
	var observer_wars: Array = []

	for raw_key in wars.keys():
		var war_contract: Dictionary = _safe_dictionary(
			wars.get(
				raw_key,
				{}
			)
		)

		if war_contract.is_empty():
			continue

		var participants: Array = (
			_war_participant_realm_ids(
				war_contract
			)
		)
		var observed_participant: bool = (
			observed_realm_id != 0
			and observed_realm_id in participants
		)
		var state: String = str(
			war_contract.get(
				"state",
				""
			)
		).strip_edges().to_lower()
		var active: bool = state in [
			"active",
			"awaiting_outcome"
		]

		if active:
			global_active_wars.append(
				war_contract
			)

		if not observed_participant:
			continue

		observer_wars.append(
			war_contract
		)

		if active:
			observer_active_wars.append(
				war_contract
			)
		else:
			observer_history.append(
				war_contract
			)

	observer_active_wars.sort_custom(
		Callable(
			self,
			"_sort_wars_by_updated"
		)
	)
	global_active_wars.sort_custom(
		Callable(
			self,
			"_sort_wars_by_updated"
		)
	)
	observer_history.sort_custom(
		Callable(
			self,
			"_sort_wars_by_updated"
		)
	)
	observer_wars.sort_custom(
		Callable(
			self,
			"_sort_wars_by_updated"
		)
	)

	var visible_active_wars: Array = (
		global_active_wars
		if include_global_active_wars
		else observer_active_wars
	)

	last_report = {
		"schema": "eralife.war.registry_contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "war_registry_ready",
		"realm_id": observed_realm_id,
		"wars": observer_wars,
		"active_wars": visible_active_wars,
		"observer_active_wars": observer_active_wars,
		"global_active_wars": global_active_wars,
		"war_history": observer_history,
		"war_count": observer_wars.size(),
		"active_war_count": observer_active_wars.size(),
		"global_active_war_count": global_active_wars.size(),
		"history_count": observer_history.size(),
		"has_active_war": (
			not observer_active_wars.is_empty()
		),
		"has_global_active_war": (
			not global_active_wars.is_empty()
		),
		"dynamic_war_tab_required": (
			not visible_active_wars.is_empty()
			or not observer_history.is_empty()
		),
		"include_global_active_wars": (
			include_global_active_wars
		),
		"context": context.duplicate(false),
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"contract_mesh": {
			"source_of_truth": "WarContractEngine",
			"battle_authority": "BattleContractEngine",
			"battle_simulation_authority": "BattleSimContractEngine",
			"battle_projection_authority": "BattleUIContractEngine",
			"ui_mutation_allowed": false,
		}
	}

	return last_report.duplicate(false)
func queue_war_declaration_contract(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var attacker_realm_id: int = int(
		context.get(
			"attacker_realm_id",
			-1
		)
	)
	var defender_realm_id: int = int(
		context.get(
			"defender_realm_id",
			-1
		)
	)

	if (
		attacker_realm_id == 0
		or defender_realm_id == 0
		or attacker_realm_id == defender_realm_id
	):
		return {
			"success": false,
			"queued": false,
			"reason": "invalid_war_realms",
			"authority": ENGINE_SCHEMA
		}

	var job_id: String = (
		"queued_war:%d:%d:%d"
		% [
			attacker_realm_id,
			defender_realm_id,
			int(
				Time.get_ticks_msec()
			)
		]
	)
	var job: Dictionary = {
		"job_id": job_id,
		"stage": "preview",
		"context": context.duplicate(false),
		"preview": {},
		"queued_at_ms": int(
			Time.get_ticks_msec()
		),
		"authority": ENGINE_SCHEMA
	}

	queued_war_declaration_jobs.append(
		job
	)

	_arm_queued_war_declaration_service()

	return {
		"success": true,
		"queued": true,
		"committed": false,
		"job_id": job_id,
		"attacker_realm_id": attacker_realm_id,
		"defender_realm_id": defender_realm_id,
		"authority": ENGINE_SCHEMA
	}
func _arm_queued_war_declaration_service() -> void:
	if queued_war_declaration_service_armed:
		return

	if queued_war_declaration_jobs.is_empty():
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		call_deferred(
			"_service_queued_war_declaration_quantum"
		)
		return

	queued_war_declaration_service_armed = true

	tree.process_frame.connect(
		Callable(
			self,
			"_service_queued_war_declaration_quantum"
		),
		CONNECT_ONE_SHOT
	)
func _service_queued_war_declaration_quantum() -> void:
	queued_war_declaration_service_armed = false

	if queued_war_declaration_jobs.is_empty():
		return

	var job: Dictionary = _safe_dictionary(
		queued_war_declaration_jobs [
			0
		]
	)
	var context: Dictionary = _safe_dictionary(
		job.get(
			"context",
			{}
		)
	)
	var stage: String = str(
		job.get(
			"stage",
			"preview"
		)
	).strip_edges().to_lower()

	if stage == "preview":
		var supplied_preview: Dictionary = _safe_dictionary(
			context.get(
				"war_preview_contract",
				{}
			)
		)

		if supplied_preview.is_empty():
			supplied_preview = (
				emit_war_preview_contract(
					context
				)
			)

		if not bool(
			supplied_preview.get(
				"success",
				false
			)
		):
			queued_war_declaration_jobs.pop_front()

			set_meta(
				"queued_war_declaration_last_failure",
				supplied_preview
			)

			_arm_queued_war_declaration_service()
			return

		context [
			"war_preview_contract"
		] = supplied_preview.duplicate(false)
		job [
			"context"
		] = context
		job [
			"preview"
		] = supplied_preview.duplicate(false)
		job [
			"stage"
		] = "commit"

		queued_war_declaration_jobs [
			0
		] = job

		_arm_queued_war_declaration_service()
		return

	var report: Dictionary = (
		declare_war_contract(
			context
		)
	)

	queued_war_declaration_jobs.pop_front()

	set_meta(
		"queued_war_declaration_last_report",
		report.duplicate(false)
	)
	set_meta(
		"queued_war_declaration_last_completed_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)

	_arm_queued_war_declaration_service()
func _war_side_realm_ids(
	war_contract: Dictionary,
	side: String
) -> Array:
	var clean_side: String = str(
		side
	).strip_edges().to_lower()
	var key: String = (
		"attacker_side_realm_ids"
		if clean_side == "attacker"
		else "defender_side_realm_ids"
	)
	var realm_ids: Array = _safe_array(
		war_contract.get(
			key,
			[]
		)
	)

	if realm_ids.is_empty():
		var fallback_realm_id: int = int(
			war_contract.get(
				(
					"attacker_realm_id"
					if clean_side == "attacker"
					else "defender_realm_id"
				),
				-1
			)
		)

		if fallback_realm_id != 0:
			realm_ids.append(
				fallback_realm_id
			)

	var cleaned: Array = []

	for raw_realm_id in realm_ids:
		var realm_id: int = int(
			raw_realm_id
		)

		if (
			realm_id != 0
			and realm_id not in cleaned
		):
			cleaned.append(
				realm_id
			)

	return cleaned
func _war_participant_realm_ids(
	war_contract: Dictionary
) -> Array:
	var participants: Array = []

	for side in [
		"attacker",
		"defender"
	]:
		for raw_realm_id in _war_side_realm_ids(
			war_contract,
			side
		):
			var realm_id: int = int(
				raw_realm_id
			)

			if realm_id not in participants:
				participants.append(
					realm_id
				)

	return participants
func _war_side_for_realm(
	war_contract: Dictionary,
	realm_id: int
) -> String:
	if realm_id in _war_side_realm_ids(
		war_contract,
		"attacker"
	):
		return "attacker"

	if realm_id in _war_side_realm_ids(
		war_contract,
		"defender"
	):
		return "defender"

	return ""
func _opposite_war_side(
	side: String
) -> String:
	return (
		"defender"
		if str(
			side
		).strip_edges().to_lower() == "attacker"
		else "attacker"
	)
func _add_realm_to_war_side(
	war_contract: Dictionary,
	realm_id: int,
	side: String
) -> Dictionary:
	if realm_id == 0:
		return war_contract

	var clean_side: String = str(
		side
	).strip_edges().to_lower()

	if clean_side not in [
		"attacker",
		"defender"
	]:
		return war_contract

	var out: Dictionary = (
		war_contract.duplicate(false)
	)
	var side_key: String = (
		"attacker_side_realm_ids"
		if clean_side == "attacker"
		else "defender_side_realm_ids"
	)
	var side_ids: Array = _war_side_realm_ids(
		out,
		clean_side
	)

	if realm_id not in side_ids:
		side_ids.append(
			realm_id
		)

	out [
		side_key
	] = side_ids

	var participant_snapshots: Dictionary = _safe_dictionary(
		out.get(
			"participant_snapshots",
			{}
		)
	)
	var snapshot: Dictionary = _realm_snapshot(
		realm_id
	)

	if not snapshot.is_empty():
		participant_snapshots [
			str(
				realm_id
			)
		] = snapshot

	out [
		"participant_snapshots"
	] = participant_snapshots


	var allied_realm_ids: Array = _safe_array(
		out.get(
			"allied_realm_ids",
			[]
		)
	)
	var primary_attacker: int = int(
		out.get(
			"attacker_realm_id",
			-1
		)
	)
	var primary_defender: int = int(
		out.get(
			"defender_realm_id",
			-1
		)
	)

	if (
		realm_id not in [
			primary_attacker,
			primary_defender
		]
		and realm_id not in allied_realm_ids
	):
		allied_realm_ids.append(
			realm_id
		)

	out [
		"allied_realm_ids"
	] = allied_realm_ids

	_mark_realm_active_war(
		realm_id,
		str(
			out.get(
				"war_id",
				""
			)
		),
		true
	)

	return out
func emit_war_preview_contract(
		context: Dictionary = {}
) -> Dictionary:
		_ensure_state()

		var attacker_realm_id: int = int(
			context.get(
				"attacker_realm_id",
				context.get(
					"side_a_realm_id",
					-1
				)
			)
		)
		var defender_realm_id: int = int(
			context.get(
				"defender_realm_id",
				context.get(
					"side_b_realm_id",
					-1
				)
			)
		)

		if (
			attacker_realm_id == 0
			or defender_realm_id == 0
			or attacker_realm_id == defender_realm_id
		):
			return _fail(
				"invalid_war_realms",
				"War preview requires two distinct realms.",
				context
			)



		var attacker: Dictionary = _realm_snapshot(
			attacker_realm_id
		)
		var defender: Dictionary = _realm_snapshot(
			defender_realm_id
		)

		if (
			attacker.is_empty()
			or defender.is_empty()
		):
			return _fail(
				"realm_power_snapshot_missing",
				"One or both resident realm power snapshots are unavailable.",
				context
			)

		var protection_context: Dictionary = (
			context.duplicate(false)
		)



		protection_context [
			"resident_target_snapshot"
		] = defender.duplicate(false)

		var protection: Dictionary = (
			_war_declaration_protection_contract(
				defender_realm_id,
				protection_context
			)
		)
		var metrics: Array = [
			_war_metric_contract(
				"population",
				"Population",
				float(
					attacker.get(
						"population",
						0
					)
				),
				float(
					defender.get(
						"population",
						0
					)
				)
			),
			_war_metric_contract(
				"land",
				"Land",
				float(
					attacker.get(
						"land",
						0
					)
				),
				float(
					defender.get(
						"land",
						0
					)
				)
			),
			_war_metric_contract(
				"treasury",
				"Treasury",
				float(
					attacker.get(
						"treasury",
						0
					)
				),
				float(
					defender.get(
						"treasury",
						0
					)
				)
			),
			_war_metric_contract(
				"military",
				"Military",
				float(
					attacker.get(
						"military_strength_score",
						0.0
					)
				),
				float(
					defender.get(
						"military_strength_score",
						0.0
					)
				)
			),
			_war_metric_contract(
				"goods",
				"Resources",
				float(
					attacker.get(
						"goods_stockpile",
						0
					)
				),
				float(
					defender.get(
						"goods_stockpile",
						0
					)
				)
			)
		]

		var attacker_power: float = _war_total_power(
			attacker
		)
		var defender_power: float = _war_total_power(
			defender
		)
		var projected_winner_realm_id: int = (
			attacker_realm_id
			if attacker_power >= defender_power
			else defender_realm_id
		)
		var power_ratio: float = (
			maxf(
				attacker_power,
				defender_power
			)
			/ maxf(
				1.0,
				minf(
					attacker_power,
					defender_power
				)
			)
		)
		var projected_duration_years: int = clampi(
			int(
				round(
					8.0 / maxf(
						1.0,
						power_ratio
					)
				)
			),
			1,
			8
		)
		var current_year: int = int(
			context.get(
				"year",
				int(
					gs.year
				)
			)
		)
		var existing_pair_war: Dictionary = (
			_active_war_between(
				attacker_realm_id,
				defender_realm_id
			)
		)
		var target_active_war: Dictionary = (
			_first_active_war_for_realm(
				defender_realm_id
			)
		)
		var attacker_already_in_target_war: bool = (
			not target_active_war.is_empty()
			and _war_side_for_realm(
				target_active_war,
				attacker_realm_id
			) != ""
		)
		var declaration_mode: String = "new_war"

		if (
			not target_active_war.is_empty()
			and existing_pair_war.is_empty()
			and not attacker_already_in_target_war
		):
			declaration_mode = "join_existing_war"

		var declaration_allowed: bool = (
			not bool(
				protection.get(
					"protected",
					false
				)
			)
			and existing_pair_war.is_empty()
			and not attacker_already_in_target_war
		)

		var era_key: String = str(
			context.get(
				"era_key",
				(
					str(
						gs.era.name
					)
					if (
						gs != null
						and gs.era != null
					)
					else ""
				)
			)
		).strip_edges().to_lower()
		var nuclear_allowed: bool = (
			era_key.contains(
				"industrial"
			)
			or era_key.contains(
				"modern"
			)
			or era_key.contains(
				"future"
			)
		)
		var relation_contract: Dictionary = (
			emit_realm_relation_contract(
				attacker_realm_id,
				defender_realm_id
			)
		)

		return {
			"schema": "eralife.war.preview_contract",
			"version": CONTRACT_VERSION,
			"success": true,
			"attacker_realm_id": attacker_realm_id,
			"defender_realm_id": defender_realm_id,
			"attacker": attacker,
			"defender": defender,
			"metrics": metrics,
			"attacker_power": attacker_power,
			"defender_power": defender_power,
			"projected_winner_realm_id": (
				projected_winner_realm_id
			),
			"projected_winner_name": str(
				(
					attacker
					if projected_winner_realm_id
					== attacker_realm_id
					else defender
				).get(
					"name",
					"Unknown Realm"
				)
			),
			"projected_duration_years": (
				projected_duration_years
			),
			"projected_end_year": (
				current_year
				+ projected_duration_years
			),
			"existing_active_war": (
				not existing_pair_war.is_empty()
			),
			"existing_war_id": str(
				existing_pair_war.get(
					"war_id",
					""
				)
			),
			"target_is_already_in_war": (
				not target_active_war.is_empty()
			),
			"target_active_war_id": str(
				target_active_war.get(
					"war_id",
					""
				)
			),
			"declaration_mode": declaration_mode,
			"declaration_allowed": (
				declaration_allowed
			),
			"declaration_protection": protection,
			"relation_contract": relation_contract,
			"nuclear_actions_allowed": (
				nuclear_allowed
			),



			"population_scan_performed": false,

			"ui_is_renderer_only": true,
			"created_at_ms": int(
				Time.get_ticks_msec()
			)
		}
func declare_war_contract(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var attacker_realm_id: int = int(
		context.get(
			"attacker_realm_id",
			context.get(
				"side_a_realm_id",
				-1
			)
		)
	)
	var defender_realm_id: int = int(
		context.get(
			"defender_realm_id",
			context.get(
				"side_b_realm_id",
				-1
			)
		)
	)

	if (
		attacker_realm_id == 0
		or defender_realm_id == 0
		or attacker_realm_id == defender_realm_id
	):
		return _fail(
			"invalid_war_realms",
			"War declaration requires two distinct realms.",
			context
		)

	var protection: Dictionary = (
		_war_declaration_protection_contract(
			defender_realm_id,
			context
		)
	)

	if bool(
		protection.get(
			"protected",
			false
		)
	):
		return _fail(
			"war_target_constitutionally_protected",
			str(
				protection.get(
					"reason",
					"That realm cannot be targeted by war."
				)
			),
			context
		)

	var preview: Dictionary = {}
	var supplied_preview_raw: Variant = context.get(
		"war_preview_contract",
		{}
	)

	if typeof(supplied_preview_raw) == TYPE_DICTIONARY:
		var supplied_preview: Dictionary = (
			supplied_preview_raw as Dictionary
		)

		if (
			bool(
				supplied_preview.get(
					"success",
					false
				)
			)
			and int(
				supplied_preview.get(
					"attacker_realm_id",
					0
				)
			) == attacker_realm_id
			and int(
				supplied_preview.get(
					"defender_realm_id",
					0
				)
			) == defender_realm_id
		):
			preview = (
				supplied_preview.duplicate(false)
			)

	if preview.is_empty():
		preview = emit_war_preview_contract(
			context
		)

	if not bool(
		preview.get(
			"success",
			false
		)
	):
		return preview

	var existing_pair_war: Dictionary = (
		_active_war_between(
			attacker_realm_id,
			defender_realm_id
		)
	)

	if not existing_pair_war.is_empty():
		return _fail(
			"war_already_active",
			"These realms are already fighting on opposite sides of an active war.",
			context
		)



	var target_active_war: Dictionary = (
		_first_active_war_for_realm(
			defender_realm_id
		)
	)

	if not target_active_war.is_empty():
		var attacker_existing_side: String = (
			_war_side_for_realm(
				target_active_war,
				attacker_realm_id
			)
		)

		if attacker_existing_side != "":
			return _fail(
				"declarer_already_participates_in_target_war",
				"Your realm already participates in that war.",
				context
			)

		var defender_side: String = (
			_war_side_for_realm(
				target_active_war,
				defender_realm_id
			)
		)
		var declaration_side: String = (
			_opposite_war_side(
				defender_side
			)
		)

		target_active_war = (
			_add_realm_to_war_side(
				target_active_war,
				attacker_realm_id,
				declaration_side
			)
		)

		var existing_events: Array = _safe_array(
			target_active_war.get(
				"events",
				[]
			)
		)
		var declarer_snapshot: Dictionary = (
			_realm_snapshot(
				attacker_realm_id
			)
		)
		var defender_snapshot: Dictionary = (
			_realm_snapshot(
				defender_realm_id
			)
		)

		existing_events.append({
			"year": int(
				gs.year
				if gs != null
				else 0
			),
			"type": (
				"war_declaration_joined_existing_conflict"
			),
			"declaring_realm_id": attacker_realm_id,
			"target_realm_id": defender_realm_id,
			"joined_side": declaration_side,
			"text": (
				"%s declared war on %s and entered the existing conflict."
				% [
					str(
						declarer_snapshot.get(
							"name",
							"Realm"
						)
					),
					str(
						defender_snapshot.get(
							"name",
							"Realm"
						)
					)
				]
			)
		})

		target_active_war [
			"events"
		] = existing_events
		target_active_war [
			"updated_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		var joined_war_id: String = str(
			target_active_war.get(
				"war_id",
				""
			)
		)
		var joined_wars: Dictionary = _safe_dictionary(
			war_registry.get(
				"wars",
				{}
			)
		)

		joined_wars [
			joined_war_id
		] = target_active_war.duplicate(false)
		war_registry [
			"wars"
		] = joined_wars
		war_registry [
			"updated_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		_set_relation_score(
			attacker_realm_id,
			defender_realm_id,
			-100
		)
		_mark_realm_active_war(
			attacker_realm_id,
			joined_war_id,
			true
		)

		last_report = {
			"schema": (
				"eralife.war.declare_report"
			),
			"version": CONTRACT_VERSION,
			"success": true,
			"mode": (
				"war_joined_by_declaration"
			),
			"committed": true,
			"war": target_active_war,
			"declaring_realm_id": (
				attacker_realm_id
			),
			"target_realm_id": (
				defender_realm_id
			),
			"joined_side": declaration_side,
			"relation_score": -100,
			"dynamic_war_tab_required": true,
			"country_card_banner": "AT WAR",
			"popup_title": "WAR DECLARED",
			"popup_text": (
				"%s declared WAR on %s and entered the existing conflict."
				% [
					str(
						declarer_snapshot.get(
							"name",
							"Your Realm"
						)
					),
					str(
						defender_snapshot.get(
							"name",
							"the target realm"
						)
					)
				]
			),
			"context": context.duplicate(false),
			"created_at_ms": int(
				Time.get_ticks_msec()
			)
		}

		_queue_war_persistence_tail()

		return last_report.duplicate(false)

	if not bool(
		preview.get(
			"declaration_allowed",
			false
		)
	):
		return _fail(
			"war_declaration_not_allowed",
			"That declaration cannot currently be committed.",
			context
		)

	var attacker: Dictionary = _safe_dictionary(
		preview.get(
			"attacker",
			{}
		)
	)
	var defender: Dictionary = _safe_dictionary(
		preview.get(
			"defender",
			{}
		)
	)
	var current_year: int = int(
		context.get(
			"year",
			int(
				gs.year
			)
		)
	)
	var war_id: String = str(
		context.get(
			"war_id",
			""
		)
	).strip_edges()

	if war_id == "":
		war_id = "war_%d_vs_%d_%d" % [
			attacker_realm_id,
			defender_realm_id,
			int(
				Time.get_ticks_msec()
			)
		]

	var participant_snapshots: Dictionary = {
		str(
			attacker_realm_id
		): attacker.duplicate(false),
		str(
			defender_realm_id
		): defender.duplicate(false)
	}

	var war_contract: Dictionary = {
		"schema": "eralife.war.contract",
		"version": CONTRACT_VERSION,
		"war_id": war_id,
		"attacker_realm_id": attacker_realm_id,
		"defender_realm_id": defender_realm_id,
		"attacker_side_realm_ids": [
			attacker_realm_id
		],
		"defender_side_realm_ids": [
			defender_realm_id
		],
		"participant_snapshots": participant_snapshots,
		"side_a": str(
			attacker.get(
				"name",
				"Attacking Realm"
			)
		),
		"side_b": str(
			defender.get(
				"name",
				"Defending Realm"
			)
		),
		"attacker_name": str(
			attacker.get(
				"name",
				"Attacking Realm"
			)
		),
		"defender_name": str(
			defender.get(
				"name",
				"Defending Realm"
			)
		),
		"casus_belli": str(
			context.get(
				"casus_belli",
				"declaration_of_war"
			)
		),
		"state": "active",
		"banner_text": "AT WAR",
		"start_year": current_year,
		"last_resolved_year": current_year,
		"years_active": 0,
		"projected_end_year": int(
			preview.get(
				"projected_end_year",
				current_year + 3
			)
		),
		"projected_winner_realm_id": int(
			preview.get(
				"projected_winner_realm_id",
				attacker_realm_id
			)
		),
		"projected_winner_name": str(
			preview.get(
				"projected_winner_name",
				""
			)
		),
		"war_score": 0.0,
		"war_pressure": 0.44,
		"attacker_snapshot": attacker,
		"defender_snapshot": defender,
		"active_battles": [],
		"battle_history": [],
		"city_invasions": [],
		"allied_realm_ids": [],
		"aid_requests": [],
		"strategic_intent": {
			"attacker": "advance",
			"defender": "hold"
		},
		"nuclear_actions_allowed": bool(
			preview.get(
				"nuclear_actions_allowed",
				false
			)
		),
		"nuclear_strike_requested": false,
		"winner_realm_id": -1,
		"loser_realm_id": -1,
		"conclusion_reason": "",
		"outcome_resolution": "",
		"outcome_choices": [],
		"annual_casualty_reports": [],
		"casualty_totals": {
			"attacker_military": 0,
			"attacker_civilian": 0,
			"defender_military": 0,
			"defender_civilian": 0,
			"displaced": 0
		},
		"resource_loss_totals": {
			"attacker_treasury": 0,
			"attacker_goods": 0,
			"attacker_military_stockpile": 0,
			"defender_treasury": 0,
			"defender_goods": 0,
			"defender_military_stockpile": 0
		},
		"war_report": {},
		"events": [
			{
				"year": current_year,
				"type": "war_declared",
				"text": (
					"%s declared WAR on %s."
					% [
						str(
							attacker.get(
								"name",
								"Attacker"
							)
						),
						str(
							defender.get(
								"name",
								"Defender"
							)
						)
					]
				)
			}
		],
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"updated_at_ms": int(
			Time.get_ticks_msec()
		),
		"contract_mesh": {
			"source_of_truth": "WarContractEngine",
			"ui_mutation_allowed": false
		}
	}

	var wars: Dictionary = _safe_dictionary(
		war_registry.get(
			"wars",
			{}
		)
	)

	wars [
		war_id
	] = war_contract.duplicate(false)
	war_registry [
		"wars"
	] = wars
	war_registry [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	_set_relation_score(
		attacker_realm_id,
		defender_realm_id,
		-100
	)
	_mark_realm_active_war(
		attacker_realm_id,
		war_id,
		true
	)
	_mark_realm_active_war(
		defender_realm_id,
		war_id,
		true
	)

	last_report = {
		"schema": "eralife.war.declare_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"committed": true,
		"mode": "war_declared",
		"war": war_contract,
		"relation_score": -100,
		"dynamic_war_tab_required": true,
		"country_card_banner": "AT WAR",
		"popup_title": "WAR DECLARED",
		"popup_text": (
			"%s has declared WAR on %s."
			% [
				str(
					attacker.get(
						"name",
						"Your Realm"
					)
				),
				str(
					defender.get(
						"name",
						"the target realm"
					)
				)
			]
		),
		"context": context.duplicate(false),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_queue_war_persistence_tail()

	return last_report.duplicate(false)

func set_war_strategy(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var war_id: String = str(
		context.get(
			"war_id",
			""
		)
	).strip_edges()
	var actor_realm_id: int = int(
		context.get(
			"actor_realm_id",
			context.get(
				"realm_id",
				-1
			)
		)
	)
	var intent: String = str(
		context.get(
			"intent",
			"hold"
		)
	).strip_edges().to_lower()
	var valid_intents: Array = [
		"hold",
		"advance",
		"defend",
		"mobilize",
		"invade_city",
		"call_for_aid",
		"seek_treaty",
		"elemental_strike",
		"nuclear_strike"
	]

	if intent not in valid_intents:
		return _fail(
			"invalid_war_strategy",
			"That war strategy is unsupported.",
			context
		)

	var wars: Dictionary = _safe_dictionary(
		war_registry.get(
			"wars",
			{}
		)
	)
	var war_contract: Dictionary = _safe_dictionary(
		wars.get(
			war_id,
			{}
		)
	)

	if war_contract.is_empty():
		return _fail(
			"war_missing",
			"War was not found.",
			context
		)

	if str(
		war_contract.get(
			"state",
			""
		)
	).strip_edges().to_lower() != "active":
		return _fail(
			"war_not_active",
			"That war is no longer active.",
			context
		)

	var side_key: String = _war_side_for_realm(
		war_contract,
		actor_realm_id
	)

	if side_key == "":
		return _fail(
			"realm_not_war_participant",
			"That realm is not a participant in this war.",
			context
		)

	var strategic_intent: Dictionary = _safe_dictionary(
		war_contract.get(
			"strategic_intent",
			{}
		)
	)

	if intent != "call_for_aid":
		strategic_intent [
			side_key
		] = intent

	war_contract [
		"strategic_intent"
	] = strategic_intent

	var events: Array = _safe_array(
		war_contract.get(
			"events",
			[]
		)
	)
	var event: Dictionary = {
		"year": int(
			gs.year
			if gs != null
			else 0
		),
		"type": intent,
		"realm_id": actor_realm_id,
		"side": side_key,
		"text": (
			"Realm %d selected strategy: %s."
			% [
				actor_realm_id,
				intent.replace(
					"_",
					" "
				).capitalize()
			]
		)
	}
	var aid_report: Dictionary = {}

	match intent:
		"invade_city":
			var target_city: String = str(
				context.get(
					"target_city",
					""
				)
			).strip_edges()
			var city_invasions: Array = _safe_array(
				war_contract.get(
					"city_invasions",
					[]
				)
			)

			city_invasions.append({
				"realm_id": actor_realm_id,
				"side": side_key,
				"target_city": target_city,
				"state": "planned",
				"year": int(
					gs.year
				)
			})

			war_contract [
				"city_invasions"
			] = city_invasions
			event [
				"target_city"
			] = target_city

		"call_for_aid":
			var ally_realm_id: int = int(
				context.get(
					"ally_realm_id",
					-1
				)
			)

			if (
				ally_realm_id <= 0
				or ally_realm_id in _war_participant_realm_ids(
					war_contract
				)
			):
				return _fail(
					"invalid_war_ally",
					"That realm cannot be called into this war.",
					context
				)

			var relation_score: int = _relation_score(
				actor_realm_id,
				ally_realm_id
			)
			var relation_tier: String = (
				_relation_tier_for_score(
					relation_score
				)
			)
			var acceptance_roll: float = (
				float(
					abs(
						hash(
							"%d:%s:%d:%d:war_aid"
							% [
								_war_world_seed(),
								war_id,
								actor_realm_id,
								ally_realm_id
							]
						)
					) % 10000
				) / 10000.0
			)
			var acceptance_chance: float = (
				clampf(
					0.58
					+ (
						float(
							relation_score - 50
						) / 100.0
					),
					0.58,
					0.98
				)
				if relation_score >= 50
				else 0.0
			)
			var accepted: bool = (
				relation_tier == "allied"
				and acceptance_roll
				<= acceptance_chance
			)
			var aid_requests: Array = _safe_array(
				war_contract.get(
					"aid_requests",
					[]
				)
			)

			aid_report = {
				"requesting_realm_id": actor_realm_id,
				"ally_realm_id": ally_realm_id,
				"requesting_side": side_key,
				"relation_score": relation_score,
				"relation_tier": relation_tier,
				"accepted": accepted,
				"year": int(
					gs.year
				)
			}

			aid_requests.append(
				aid_report
			)
			war_contract [
				"aid_requests"
			] = aid_requests

			if accepted:
				war_contract = _add_realm_to_war_side(
					war_contract,
					ally_realm_id,
					side_key
				)

			event [
				"ally_realm_id"
			] = ally_realm_id
			event [
				"accepted"
			] = accepted
		"elemental_strike":
			var actor_snapshot: Dictionary = (
				_realm_snapshot(
					actor_realm_id
				)
			)
			var elemental_capability: Dictionary = (
				_safe_dictionary(
					actor_snapshot.get(
						"elemental_war_capability",
						{}
					)
				)
			)

			if not bool(
				elemental_capability.get(
					"enabled",
					false
				)
			):
				return _fail(
					"elemental_war_capability_missing",
					"That realm has no elemental war capability.",
					context
				)

			var elemental_target: String = str(
				context.get(
					"elemental_target",
					"military"
				)
			).strip_edges().to_lower()

			if elemental_target not in [
				"military",
				"population",
				"infrastructure"
			]:
				return _fail(
					"invalid_elemental_war_target",
					"Choose military, population, or infrastructure.",
					context
				)

			war_contract [
				"elemental_strike_request"
			] = {
				"realm_id": actor_realm_id,
				"side": side_key,
				"element": str(
					elemental_capability.get(
						"element",
						""
					)
				),
				"mastery": int(
					elemental_capability.get(
						"effective_mastery",
						0
					)
				),
				"target": elemental_target,
				"requested_year": int(
					gs.year
				),
				"consumed": false,
				"capability_contract": (
					elemental_capability.duplicate(false)
				),
				"ui_is_renderer_only": true
			}

			event [
				"element"
			] = str(
				elemental_capability.get(
					"element",
					""
				)
			)
			event [
				"elemental_target"
			] = elemental_target
			event [
				"mastery"
			] = int(
				elemental_capability.get(
					"effective_mastery",
					0
				)
			)
		"nuclear_strike":
			if not bool(
				war_contract.get(
					"nuclear_actions_allowed",
					false
				)
			):
				return _fail(
					"nuclear_strategy_era_locked",
					"Nuclear strategy is unavailable in this era.",
					context
				)

			war_contract [
				"nuclear_strike_requested"
			] = true
			war_contract [
				"nuclear_strike_requesting_realm_id"
			] = actor_realm_id

	events.append(
		event
	)

	war_contract [
		"events"
	] = events
	war_contract [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	wars [
		war_id
	] = war_contract.duplicate(false)
	war_registry [
		"wars"
	] = wars
	war_registry [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	var popup_text: String = (
		"War strategy updated."
	)

	if intent == "call_for_aid":
		popup_text = (
			"%s accepted your call and entered the war."
			% str(
				_realm_snapshot(
					int(
						aid_report.get(
							"ally_realm_id",
							-1
						)
					)
				).get(
					"name",
					"Your ally"
				)
			)
			if bool(
				aid_report.get(
					"accepted",
					false
				)
			)
			else (
				"Your ally declined the request to enter this war."
			)
		)

	last_report = {
		"schema": "eralife.war.strategy_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"committed": true,
		"mode": "war_strategy_updated",
		"intent": intent,
		"war": war_contract,
		"aid_report": aid_report,
		"popup_title": (
			"ALLY REQUEST"
			if intent == "call_for_aid"
			else "WAR STRATEGY"
		),
		"popup_text": popup_text,
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_queue_war_persistence_tail()

	return last_report.duplicate(false)
func request_join_war(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var war_id: String = str(
		context.get(
			"war_id",
			""
		)
	).strip_edges()
	var joining_realm_id: int = int(
		context.get(
			"actor_realm_id",
			context.get(
				"joining_realm_id",
				-1
			)
		)
	)
	var requested_side: String = str(
		context.get(
			"join_side",
			""
		)
	).strip_edges().to_lower()

	if requested_side not in [
		"attacker",
		"defender"
	]:
		return _fail(
			"invalid_war_join_side",
			"Choose which side of the war you want to join.",
			context
		)

	var wars: Dictionary = _safe_dictionary(
		war_registry.get(
			"wars",
			{}
		)
	)
	var war_contract: Dictionary = _safe_dictionary(
		wars.get(
			war_id,
			{}
		)
	)

	if (
		war_contract.is_empty()
		or str(
			war_contract.get(
				"state",
				""
			)
		).strip_edges().to_lower()
		!= "active"
	):
		return _fail(
			"war_not_joinable",
			"That war is not currently joinable.",
			context
		)

	if _war_side_for_realm(
		war_contract,
		joining_realm_id
	) != "":
		return _fail(
			"realm_already_in_war",
			"Your realm already participates in this war.",
			context
		)

	var side_ids: Array = _war_side_realm_ids(
		war_contract,
		requested_side
	)

	if side_ids.is_empty():
		return _fail(
			"war_side_missing",
			"That side of the war has no recognized anchor realm.",
			context
		)

	var anchor_realm_id: int = int(
		side_ids [
			0
		]
	)
	var relation_score: int = _relation_score(
		joining_realm_id,
		anchor_realm_id
	)
	var acceptance_roll: float = (
		float(
			abs(
				hash(
					"%d:%s:%d:%s:join_war"
					% [
						_war_world_seed(),
						war_id,
						joining_realm_id,
						requested_side
					]
				)
			) % 10000
		) / 10000.0
	)
	var acceptance_chance: float = clampf(
		0.48
		+ (
			float(
				relation_score
			) / 170.0
		),
		0.08,
		0.94
	)
	var accepted: bool = (
		relation_score >= -10
		and acceptance_roll
		<= acceptance_chance
	)
	var events: Array = _safe_array(
		war_contract.get(
			"events",
			[]
		)
	)

	events.append({
		"year": int(
			gs.year
			if gs != null
			else 0
		),
		"type": "war_join_request",
		"realm_id": joining_realm_id,
		"requested_side": requested_side,
		"anchor_realm_id": anchor_realm_id,
		"relation_score": relation_score,
		"accepted": accepted
	})

	if accepted:
		war_contract = _add_realm_to_war_side(
			war_contract,
			joining_realm_id,
			requested_side
		)

	war_contract [
		"events"
	] = events
	war_contract [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	wars [
		war_id
	] = war_contract.duplicate(false)
	war_registry [
		"wars"
	] = wars
	war_registry [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	last_report = {
		"schema": (
			"eralife.war.join_request_report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"committed": accepted,
		"mode": (
			"war_join_request_accepted"
			if accepted
			else "war_join_request_declined"
		),
		"accepted": accepted,
		"war": war_contract,
		"joining_realm_id": joining_realm_id,
		"join_side": requested_side,
		"relation_score": relation_score,
		"popup_title": (
			"WAR ENTRY ACCEPTED"
			if accepted
			else "WAR ENTRY DECLINED"
		),
		"popup_text": (
			"Your realm has entered the war on the %s side."
			% requested_side.capitalize()
			if accepted
			else (
				"That side declined your request to enter the war."
			)
		),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_queue_war_persistence_tail()

	return last_report.duplicate(false)
func advance_wars_to_year(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var target_year: int = int(
		context.get(
			"year",
			int(gs.year)
			if gs != null
			else 0
		)
	)

	if target_year <= 0:
		return _fail(
			"invalid_war_year",
			"War advancement requires a valid year.",
			context
		)

	var advanced_count: int = _advance_registry_to_year(
		target_year
	)

	last_report = {
		"schema": "eralife.war.year_advance_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"year": target_year,
		"advanced_war_count": advanced_count,
		"registry": war_registry.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	_commit_state()

	return last_report.duplicate(true)


func resolve_war_outcome(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var war_id: String = str(
		context.get(
			"war_id",
			""
		)
	).strip_edges()
	var resolution: String = str(
		context.get(
			"resolution",
			"spare"
		)
	).strip_edges().to_lower()
	var valid_resolutions: Array = [
		"spare",
		"treaty",
		"annex"
	]

	if resolution not in valid_resolutions:
		return _fail(
			"invalid_war_resolution",
			"That war outcome is unsupported.",
			context
		)

	var wars: Dictionary = _safe_dictionary(
		war_registry.get(
			"wars",
			{}
		)
	)
	var war_contract: Dictionary = _safe_dictionary(
		wars.get(
			war_id,
			{}
		)
	)

	if war_contract.is_empty():
		return _fail(
			"war_missing",
			"War was not found.",
			context
		)

	if str(
		war_contract.get(
			"state",
			""
		)
	).strip_edges().to_lower() != "awaiting_outcome":
		return _fail(
			"war_outcome_not_ready",
			"That war has not reached an outcome decision.",
			context
		)

	var winner_realm_id: int = int(
		war_contract.get(
			"winner_realm_id",
			-1
		)
	)
	var loser_realm_id: int = int(
		war_contract.get(
			"loser_realm_id",
			-1
		)
	)
	var actor_realm_id: int = int(
		context.get(
			"actor_realm_id",
			-1
		)
	)
	var automatic_resolution: bool = bool(
		context.get(
			"automatic_resolution",
			false
		)
	)

	if (
		not automatic_resolution
		and actor_realm_id > 0
		and actor_realm_id
		!= winner_realm_id
	):
		return _fail(
			"war_outcome_requires_winner_authority",
			"Only the victorious realm may choose this war outcome.",
			context
		)



	_apply_war_realm_outcome(
		winner_realm_id,
		loser_realm_id
	)

	match resolution:
		"spare":
			_apply_relation_delta(
				winner_realm_id,
				loser_realm_id,
				8
			)

		"treaty":
			_apply_treaty_transfer(
				winner_realm_id,
				loser_realm_id
			)
			_apply_relation_delta(
				winner_realm_id,
				loser_realm_id,
				-5
			)

		"annex":
			_apply_annexation(
				winner_realm_id,
				loser_realm_id
			)
			war_contract [
				"global_relation_shock"
			] = -20

	war_contract [
		"state"
	] = "concluded"
	war_contract [
		"outcome_resolution"
	] = resolution
	war_contract [
		"concluded_year"
	] = int(
		gs.year
		if gs != null
		else 0
	)
	war_contract [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	var events: Array = _safe_array(
		war_contract.get(
			"events",
			[]
		)
	)

	events.append({
		"year": int(
			gs.year
			if gs != null
			else 0
		),
		"type": "war_outcome_resolved",
		"resolution": resolution,
		"winner_realm_id": winner_realm_id,
		"loser_realm_id": loser_realm_id
	})

	war_contract [
		"events"
	] = events

	for raw_realm_id in _war_participant_realm_ids(
		war_contract
	):
		_mark_realm_active_war(
			int(
				raw_realm_id
			),
			war_id,
			false
		)

	war_contract [
		"war_report"
	] = _build_war_report_contract(
		war_contract
	)

	wars [
		war_id
	] = war_contract.duplicate(false)
	war_registry [
		"wars"
	] = wars
	war_registry [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	last_report = {
		"schema": "eralife.war.outcome_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"committed": true,
		"mode": "war_outcome_resolved",
		"resolution": resolution,
		"war": war_contract,
		"war_report": _safe_dictionary(
			war_contract.get(
				"war_report",
				{}
			)
		),
		"popup_title": "WAR ENDED",
		"popup_text": (
			"%s defeated %s. The war has concluded by %s."
			% [
				str(
					_realm_snapshot(
						winner_realm_id
					).get(
						"name",
						"The victorious realm"
					)
				),
				str(
					_realm_snapshot(
						loser_realm_id
					).get(
						"name",
						"the defeated realm"
					)
				),
				resolution.replace(
					"_",
					" "
				)
			]
		),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_queue_war_persistence_tail()

	return last_report.duplicate(false)
func _auto_resolve_awaiting_wars(
	year: int
) -> int:
	var wars: Dictionary = _safe_dictionary(
		war_registry.get(
			"wars",
			{}
		)
	)
	var resolved_count: int = 0
	var pending_ids: Array = []

	for raw_war_id in wars.keys():
		var war_contract: Dictionary = _safe_dictionary(
			wars.get(
				raw_war_id,
				{}
			)
		)

		if str(
			war_contract.get(
				"state",
				""
			)
		).strip_edges().to_lower() != "awaiting_outcome":
			continue

		var winner_realm_id: int = int(
			war_contract.get(
				"winner_realm_id",
				-1
			)
		)
		var decision_year: int = int(
			war_contract.get(
				"outcome_decision_year",
				year
			)
		)
		var player_controls_winner: bool = (
			gs != null
			and gs.player != null
			and bool(
				gs.player.is_ruler
			)
			and int(
				gs.player.realm_id
			) == winner_realm_id
		)


		if (
			player_controls_winner
			and year <= decision_year
		):
			continue

		pending_ids.append(
			str(
				raw_war_id
			)
		)

	for war_id in pending_ids:
		var resolution_roll: int = abs(
			hash(
				"%d:%s:auto_outcome"
				% [
					year,
					war_id
				]
			)
		) % 100
		var resolution: String = (
			"spare"
			if resolution_roll < 35
			else "treaty"
		)
		var war_contract: Dictionary = _safe_dictionary(
			_safe_dictionary(
				war_registry.get(
					"wars",
					{}
				)
			).get(
				war_id,
				{}
			)
		)

		var report: Dictionary = resolve_war_outcome({
			"war_id": war_id,
			"resolution": resolution,
			"actor_realm_id": int(
				war_contract.get(
					"winner_realm_id",
					-1
				)
			),
			"automatic_resolution": true,
			"source": "war_contract_engine.yearly_tick"
		})

		if bool(
			report.get(
				"success",
				false
			)
		):
			resolved_count += 1

	return resolved_count
func _war_realm_card_contract(
	realm_id: int,
	observer_realm_id: int
) -> Dictionary:
	var snapshot: Dictionary = _realm_snapshot(
		realm_id
	)
	var relation: Dictionary = (
		emit_realm_relation_contract(
			observer_realm_id,
			realm_id
		)
	)

	return {
		"realm_id": realm_id,
		"name": str(
			snapshot.get(
				"name",
				"Unknown Realm"
			)
		),
		"population": int(
			snapshot.get(
				"population",
				0
			)
		),
		"military": int(
			snapshot.get(
				"military_stockpile",
				0
			)
		),
		"military_strength_score": float(
			snapshot.get(
				"military_strength_score",
				0.0
			)
		),
		"treasury": int(
			snapshot.get(
				"treasury",
				0
			)
		),
		"goods": int(
			snapshot.get(
				"goods_stockpile",
				0
			)
		),
		"land": int(
			snapshot.get(
				"land",
				0
			)
		),
		"native_element": str(
			snapshot.get(
				"native_element",
				""
			)
		),
		"is_elemental_realm": bool(
			snapshot.get(
				"is_elemental_realm",
				false
			)
		),
		"elemental_war_capability": _safe_dictionary(
			snapshot.get(
				"elemental_war_capability",
				{}
			)
		),
		"relation_contract": relation,
		"at_war": true,
		"war_banner": "AT WAR",
		"ui_is_renderer_only": true
	}
func emit_war_surface_contract(
	war_id: String,
	observer_realm_id: int
) -> Dictionary:
	_ensure_state()

	var wars: Dictionary = _safe_dictionary(
		war_registry.get(
			"wars",
			{}
		)
	)
	var war_contract: Dictionary = _safe_dictionary(
		wars.get(
			war_id,
			{}
		)
	)

	if war_contract.is_empty():
		return {}

	var attacker_cards: Array = []
	var defender_cards: Array = []

	for raw_realm_id in _war_side_realm_ids(
		war_contract,
		"attacker"
	):
		attacker_cards.append(
			_war_realm_card_contract(
				int(
					raw_realm_id
				),
				observer_realm_id
			)
		)

	for raw_realm_id in _war_side_realm_ids(
		war_contract,
		"defender"
	):
		defender_cards.append(
			_war_realm_card_contract(
				int(
					raw_realm_id
				),
				observer_realm_id
			)
		)

	var observer_side: String = _war_side_for_realm(
		war_contract,
		observer_realm_id
	)
	var ally_candidates: Array = []
	var participants: Array = _war_participant_realm_ids(
		war_contract
	)

	if (
		observer_side != ""
		and gs != null
		and gs.realm_engine != null
	):
		for raw_realm_id in gs.realm_engine.realms.keys():
			var candidate_realm_id: int = int(
				raw_realm_id
			)

			if (
				candidate_realm_id <= 0
				or candidate_realm_id
				in participants
			):
				continue

			var relation: Dictionary = (
				emit_realm_relation_contract(
					observer_realm_id,
					candidate_realm_id
				)
			)

			if str(
				relation.get(
					"tier",
					""
				)
			) != "allied":
				continue

			var snapshot: Dictionary = (
				_realm_snapshot(
					candidate_realm_id
				)
			)

			ally_candidates.append({
				"realm_id": candidate_realm_id,
				"name": str(
					snapshot.get(
						"name",
						"Allied Realm"
					)
				),
				"relation_contract": relation
			})

	return {
		"schema": "eralife.war.surface_contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"war_id": war_id,
		"state": str(
			war_contract.get(
				"state",
				""
			)
		),
		"attacker_side": {
			"side_id": "attacker",
			"realm_cards": attacker_cards
		},
		"defender_side": {
			"side_id": "defender",
			"realm_cards": defender_cards
		},
		"observer_realm_id": observer_realm_id,
		"observer_side": observer_side,
		"observer_is_participant": (
			observer_side != ""
		),
		"war_score": float(
			war_contract.get(
				"war_score",
				0.0
			)
		),
		"start_year": int(
			war_contract.get(
				"start_year",
				0
			)
		),
		"years_active": int(
			war_contract.get(
				"years_active",
				0
			)
		),
		"projected_end_year": int(
			war_contract.get(
				"projected_end_year",
				0
			)
		),
		"projected_winner_name": str(
			war_contract.get(
				"projected_winner_name",
				"Unknown"
			)
		),
		"winner_realm_id": int(
			war_contract.get(
				"winner_realm_id",
				-1
			)
		),
		"outcome_choices": _safe_array(
			war_contract.get(
				"outcome_choices",
				[]
			)
		),
		"ally_candidates": ally_candidates,
		"casualty_totals": _safe_dictionary(
			war_contract.get(
				"casualty_totals",
				{}
			)
		),
		"war_report": _safe_dictionary(
			war_contract.get(
				"war_report",
				{}
			)
		),
		"banner_text": "AT WAR",
		"ui_is_renderer_only": true
	}
func register_active_battle(war_id: String, battle_id: String) -> void:
	_ensure_state()

	var wars: Dictionary = _safe_dictionary(war_registry.get("wars", {}))
	var war_contract: Dictionary = _safe_dictionary(wars.get(war_id, {}))
	if war_contract.is_empty():
		return

	var active_battles: Array = _safe_array(war_contract.get("active_battles", []))
	if battle_id not in active_battles:
		active_battles.append(battle_id)

	war_contract ["active_battles"] = active_battles
	war_contract ["updated_at_ms"] = int(Time.get_ticks_msec())
	wars [war_id] = war_contract.duplicate(true)
	war_registry ["wars"] = wars
	_write_registry()
	_commit_state()


func get_war(war_id: String) -> Dictionary:
	_ensure_state()
	var wars: Dictionary = _safe_dictionary(war_registry.get("wars", {}))
	return _safe_dictionary(wars.get(war_id, {}))
func _advance_registry_to_year(
	target_year: int
) -> int:
	var wars: Dictionary = _safe_dictionary(
		war_registry.get(
			"wars",
			{}
		)
	)
	var advanced_count: int = 0

	for raw_war_id in wars.keys():
		var war_id: String = str(
			raw_war_id
		)
		var war_contract: Dictionary = _safe_dictionary(
			wars.get(
				raw_war_id,
				{}
			)
		)

		if str(
			war_contract.get(
				"state",
				""
			)
		) != "active":
			continue

		var last_resolved_year: int = int(
			war_contract.get(
				"last_resolved_year",
				war_contract.get(
					"start_year",
					target_year
				)
			)
		)

		while last_resolved_year < target_year:
			last_resolved_year += 1
			war_contract = _advance_single_war_year(
				war_contract,
				last_resolved_year
			)
			advanced_count += 1

			if str(
				war_contract.get(
					"state",
					""
				)
			) != "active":
				break

		wars [
			war_id
		] = war_contract.duplicate(true)

	war_registry ["wars"] = wars
	war_registry ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	_write_registry()

	return advanced_count

func _war_side_total_power(
	war_contract: Dictionary,
	side: String
) -> float:
	var total: float = 0.0
	var ids: Array = _war_side_realm_ids(
		war_contract,
		side
	)

	for index in range(
		ids.size()
	):
		var realm_id: int = int(
			ids [
				index
			]
		)
		var power: float = _war_total_power(
			_realm_snapshot(
				realm_id
			)
		)




		total += (
			power
			if index == 0
			else power * 0.72
		)

	return total
func _war_side_metric_total(
	war_contract: Dictionary,
	side: String,
	metric_id: String
) -> int:
	var total: int = 0

	for raw_realm_id in _war_side_realm_ids(
		war_contract,
		side
	):
		var snapshot: Dictionary = _realm_snapshot(
			int(
				raw_realm_id
			)
		)

		total += int(
			snapshot.get(
				metric_id,
				0
			)
		)

	return total
func _war_side_exhausted(
	war_contract: Dictionary,
	side: String
) -> bool:
	var ids: Array = _war_side_realm_ids(
		war_contract,
		side
	)

	if ids.is_empty():
		return true

	for raw_realm_id in ids:
		var realm_id: int = int(
			raw_realm_id
		)

		if realm_id == ERA_KINGDOM_WAR_REALM_ID:
			return false

		if not _realm_war_exhausted(
			realm_id
		):
			return false

	return true
func _war_year_casualty_report(
	war_contract: Dictionary,
	resolved_year: int,
	score_delta: float
) -> Dictionary:
	var attacker_population: int = (
		_war_side_metric_total(
			war_contract,
			"attacker",
			"population"
		)
	)
	var defender_population: int = (
		_war_side_metric_total(
			war_contract,
			"defender",
			"population"
		)
	)
	var attacker_military: int = (
		_war_side_metric_total(
			war_contract,
			"attacker",
			"military_stockpile"
		)
	)
	var defender_military: int = (
		_war_side_metric_total(
			war_contract,
			"defender",
			"military_stockpile"
		)
	)
	var intensity: float = clampf(
		0.018
		+ (
			absf(
				score_delta
			) / 650.0
		),
		0.018,
		0.065
	)

	var attacker_military_casualties: int = int(
		round(
			float(
				attacker_military
			) * intensity
		)
	)
	var defender_military_casualties: int = int(
		round(
			float(
				defender_military
			) * intensity * 1.08
		)
	)
	var attacker_civilian_casualties: int = int(
		round(
			float(
				attacker_population
			) * intensity * 0.0015
		)
	)
	var defender_civilian_casualties: int = int(
		round(
			float(
				defender_population
			) * intensity * 0.0018
		)
	)
	var displaced: int = int(
		round(
			float(
				attacker_civilian_casualties
				+ defender_civilian_casualties
			) * 3.8
		)
	)

	return {
		"year": resolved_year,
		"attacker_military": (
			attacker_military_casualties
		),
		"attacker_civilian": (
			attacker_civilian_casualties
		),
		"defender_military": (
			defender_military_casualties
		),
		"defender_civilian": (
			defender_civilian_casualties
		),
		"displaced": displaced,
		"score_delta": score_delta
	}
func _append_war_casualty_report(
	war_contract: Dictionary,
	report: Dictionary
) -> Dictionary:
	var out: Dictionary = (
		war_contract.duplicate(false)
	)
	var annual_reports: Array = _safe_array(
		out.get(
			"annual_casualty_reports",
			[]
		)
	)
	var totals: Dictionary = _safe_dictionary(
		out.get(
			"casualty_totals",
			{}
		)
	)

	annual_reports.append(
		report
	)

	for metric_id in [
		"attacker_military",
		"attacker_civilian",
		"defender_military",
		"defender_civilian",
		"displaced"
	]:
		totals [
			metric_id
		] = int(
			totals.get(
				metric_id,
				0
			)
		) + int(
			report.get(
				metric_id,
				0
			)
		)

	out [
		"annual_casualty_reports"
	] = annual_reports
	out [
		"casualty_totals"
	] = totals

	return out
func _advance_single_war_year(
	war_contract: Dictionary,
	resolved_year: int
) -> Dictionary:
	var attacker_realm_id: int = int(
		war_contract.get(
			"attacker_realm_id",
			-1
		)
	)
	var defender_realm_id: int = int(
		war_contract.get(
			"defender_realm_id",
			-1
		)
	)
	var strategic_intent: Dictionary = _safe_dictionary(
		war_contract.get(
			"strategic_intent",
			{}
		)
	)
	var attacker_modifier: float = _strategy_modifier(
		str(
			strategic_intent.get(
				"attacker",
				"advance"
			)
		)
	)
	var defender_modifier: float = _strategy_modifier(
		str(
			strategic_intent.get(
				"defender",
				"hold"
			)
		)
	)
	var attacker_power: float = (
		_war_side_total_power(
			war_contract,
			"attacker"
		) * attacker_modifier
	)
	var defender_power: float = (
		_war_side_total_power(
			war_contract,
			"defender"
		) * defender_modifier
	)
	var deterministic_variance: float = (
		float(
			abs(
				hash(
					"%s:%d"
					% [
						str(
							war_contract.get(
								"war_id",
								"war"
							)
						),
						resolved_year
					]
				)
			) % 1701
		) / 100.0
	) - 8.5
	var score_delta: float = clampf(
		(
			(
				attacker_power
				- defender_power
			)
			/ maxf(
				1.0,
				attacker_power
				+ defender_power
			)
		) * 48.0
		+ deterministic_variance,
		-24.0,
		24.0
	)
	var attacker_elemental_capability: Dictionary = {}
	var defender_elemental_capability: Dictionary = {}

	for raw_realm_id in _war_side_realm_ids(
		war_contract,
		"attacker"
	):
		var snapshot: Dictionary = _realm_snapshot(
			int(
				raw_realm_id
			)
		)
		var capability: Dictionary = _safe_dictionary(
			snapshot.get(
				"elemental_war_capability",
				{}
			)
		)

		if not bool(
			capability.get(
				"enabled",
				false
			)
		):
			continue

		if (
			attacker_elemental_capability.is_empty()
			or int(
				capability.get(
					"effective_mastery",
					0
				)
			) > int(
				attacker_elemental_capability.get(
					"effective_mastery",
					0
				)
			)
		):
			attacker_elemental_capability = (
				capability.duplicate(false)
			)

	for raw_realm_id in _war_side_realm_ids(
		war_contract,
		"defender"
	):
		var snapshot: Dictionary = _realm_snapshot(
			int(
				raw_realm_id
			)
		)
		var capability: Dictionary = _safe_dictionary(
			snapshot.get(
				"elemental_war_capability",
				{}
			)
		)

		if not bool(
			capability.get(
				"enabled",
				false
			)
		):
			continue

		if (
			defender_elemental_capability.is_empty()
			or int(
				capability.get(
					"effective_mastery",
					0
				)
			) > int(
				defender_elemental_capability.get(
					"effective_mastery",
					0
				)
			)
		):
			defender_elemental_capability = (
				capability.duplicate(false)
			)

	var attacker_elemental: bool = (
		not attacker_elemental_capability.is_empty()
	)
	var defender_elemental: bool = (
		not defender_elemental_capability.is_empty()
	)
	var elemental_overmatch_side: String = ""

	if (
		attacker_elemental
		and not defender_elemental
	):
		var mastery: float = float(
			attacker_elemental_capability.get(
				"effective_mastery",
				85
			)
		)
		score_delta += clampf(
			36.0 + (mastery * 0.38),
			50.0,
			74.0
		)
		elemental_overmatch_side = "attacker"
	elif (
		defender_elemental
		and not attacker_elemental
	):
		var mastery: float = float(
			defender_elemental_capability.get(
				"effective_mastery",
				85
			)
		)
		score_delta -= clampf(
			36.0 + (mastery * 0.38),
			50.0,
			74.0
		)
		elemental_overmatch_side = "defender"
	if bool(
		war_contract.get(
			"nuclear_strike_requested",
			false
		)
	):
		var nuclear_realm_id: int = int(
			war_contract.get(
				"nuclear_strike_requesting_realm_id",
				-1
			)
		)
		var nuclear_side: String = _war_side_for_realm(
			war_contract,
			nuclear_realm_id
		)

		if nuclear_side == "attacker":
			score_delta = 100.0
		elif nuclear_side == "defender":
			score_delta = -100.0

		war_contract [
			"conclusion_reason"
		] = "nuclear_strike"
	var elemental_strike_request: Dictionary = _safe_dictionary(
		war_contract.get(
			"elemental_strike_request",
			{}
		)
	)
	var elemental_strike_side: String = ""
	var elemental_strike_target: String = ""
	var elemental_strike_mastery: int = 0

	if (
		not elemental_strike_request.is_empty()
		and not bool(
			elemental_strike_request.get(
				"consumed",
				false
			)
		)
	):
		elemental_strike_side = str(
			elemental_strike_request.get(
				"side",
				""
			)
		).strip_edges().to_lower()
		elemental_strike_target = str(
			elemental_strike_request.get(
				"target",
				"military"
			)
		).strip_edges().to_lower()
		elemental_strike_mastery = clampi(
			int(
				elemental_strike_request.get(
					"mastery",
					0
				)
			),
			0,
			100
		)

		var strike_force: float = clampf(
			30.0
			+ (
				float(
					elemental_strike_mastery
				) * 0.42
			),
			38.0,
			72.0
		)

		if elemental_strike_side == "attacker":
			score_delta += strike_force
		elif elemental_strike_side == "defender":
			score_delta -= strike_force

		elemental_strike_request [
			"consumed"
		] = true
		elemental_strike_request [
			"consumed_year"
		] = resolved_year
		war_contract [
			"elemental_strike_request"
		] = elemental_strike_request
	var war_score: float = clampf(
		float(
			war_contract.get(
				"war_score",
				0.0
			)
		) + score_delta,
		-100.0,
		100.0
	)

	war_contract [
		"war_score"
	] = war_score
	war_contract [
		"last_resolved_year"
	] = resolved_year
	war_contract [
		"years_active"
	] = maxi(
		0,
		resolved_year - int(
			war_contract.get(
				"start_year",
				resolved_year
			)
		)
	)

	var projected_winner_realm_id: int = (
		attacker_realm_id
		if war_score >= 0.0
		else defender_realm_id
	)
	var projected_winner_snapshot: Dictionary = (
		_realm_snapshot(
			projected_winner_realm_id
		)
	)

	war_contract [
		"projected_winner_realm_id"
	] = projected_winner_realm_id
	war_contract [
		"projected_winner_name"
	] = str(
		projected_winner_snapshot.get(
			"name",
			"Unknown Realm"
		)
	)
	war_contract [
		"projected_end_year"
	] = (
		resolved_year
		+ clampi(
			int(
				ceil(
					(
						100.0
						- absf(
							war_score
						)
					) / maxf(
						8.0,
						absf(
							score_delta
						)
					)
				)
			),
			1,
			8
		)
	)

	var casualty_report: Dictionary = (
		_war_year_casualty_report(
			war_contract,
			resolved_year,
			score_delta
		)
	)
	if elemental_overmatch_side != "":
		if elemental_overmatch_side == "attacker":
			casualty_report [
				"defender_military"
			] = maxi(
				int(
					casualty_report.get(
						"defender_military",
						0
					)
				),
				int(
					round(
						float(
							_war_side_metric_total(
								war_contract,
								"defender",
								"military_stockpile"
							)
						) * 0.28
					)
				)
			)
		else:
			casualty_report [
				"attacker_military"
			] = maxi(
				int(
					casualty_report.get(
						"attacker_military",
						0
					)
				),
				int(
					round(
						float(
							_war_side_metric_total(
								war_contract,
								"attacker",
								"military_stockpile"
							)
						) * 0.28
					)
				)
			)

	if elemental_strike_side != "":
		var target_side: String = (
			"defender"
			if elemental_strike_side == "attacker"
			else "attacker"
		)
		var target_realm_ids: Array = (
			_war_side_realm_ids(
				war_contract,
				target_side
			)
		)
		var target_realm_id: int = (
			int(
				target_realm_ids [
					0
				]
			)
			if not target_realm_ids.is_empty()
			else -1
		)

		if elemental_strike_target == "military":
			var military_metric: String = (
				"defender_military"
				if target_side == "defender"
				else "attacker_military"
			)
			var target_military: int = (
				_war_side_metric_total(
					war_contract,
					target_side,
					"military_stockpile"
				)
			)
			var destruction_rate: float = (
				0.22
				+ (
					float(
						elemental_strike_mastery
					) / 100.0
				) * 0.38
			)

			casualty_report [
				military_metric
			] = maxi(
				int(
					casualty_report.get(
						military_metric,
						0
					)
				),
				int(
					round(
						float(
							target_military
						) * destruction_rate
					)
				)
			)

			if target_realm_id > 0:
				_drain_realm_war_resources(
					target_realm_id,
					0.1,
					destruction_rate,
					0.12
				)

		elif elemental_strike_target == "population":
			var civilian_metric: String = (
				"defender_civilian"
				if target_side == "defender"
				else "attacker_civilian"
			)
			var target_population: int = (
				_war_side_metric_total(
					war_contract,
					target_side,
					"population"
				)
			)
			var civilian_rate: float = (
				0.008
				+ (
					float(
						elemental_strike_mastery
					) / 100.0
				) * 0.022
			)
			var elemental_civilian_losses: int = int(
				round(
					float(
						target_population
					) * civilian_rate
				)
			)

			casualty_report [
				civilian_metric
			] = maxi(
				int(
					casualty_report.get(
						civilian_metric,
						0
					)
				),
				elemental_civilian_losses
			)

			if (
				target_realm_id > 0
				and gs != null
				and gs.realm_engine != null
				and gs.realm_engine.realms.has(
					target_realm_id
				)
			):
				var target_realm: Dictionary = (
					_safe_dictionary(
						gs.realm_engine.realms.get(
							target_realm_id,
							{}
						)
					)
				)
				target_realm [
					"population"
				] = maxi(
					0,
					int(
						target_realm.get(
							"population",
							0
						)
					) - elemental_civilian_losses
				)
				target_realm [
					"population_deaths_last_year"
				] = int(
					target_realm.get(
						"population_deaths_last_year",
						0
					)
				) + elemental_civilian_losses

				gs.realm_engine.realms [
					target_realm_id
				] = target_realm

		elif elemental_strike_target == "infrastructure":
			if target_realm_id > 0:
				_drain_realm_war_resources(
					target_realm_id,
					0.38,
					0.18,
					0.46
				)
	if (
		elemental_overmatch_side == "attacker"
		and war_score >= 100.0
	):
		war_contract [
			"conclusion_reason"
		] = "elemental_overmatch"
	elif (
		elemental_overmatch_side == "defender"
		and war_score <= -100.0
	):
		war_contract [
			"conclusion_reason"
		] = "elemental_overmatch"
	elif (
		elemental_strike_side != ""
		and absf(
			war_score
		) >= 100.0
	):
		war_contract [
			"conclusion_reason"
		] = "elemental_strike_total_victory"
	war_contract = _append_war_casualty_report(
		war_contract,
		casualty_report
	)

	for raw_realm_id in _war_side_realm_ids(
		war_contract,
		"attacker"
	):
		_drain_realm_war_resources(
			int(
				raw_realm_id
			),
			0.06,
			0.08,
			0.05
		)

	for raw_realm_id in _war_side_realm_ids(
		war_contract,
		"defender"
	):
		_drain_realm_war_resources(
			int(
				raw_realm_id
			),
			0.07,
			0.09,
			0.06
		)

	var events: Array = _safe_array(
		war_contract.get(
			"events",
			[]
		)
	)

	events.append({
		"year": resolved_year,
		"type": "war_year_resolved",
		"score_delta": score_delta,
		"war_score": war_score,
		"projected_winner_realm_id": (
			projected_winner_realm_id
		),
		"casualties": casualty_report
	})

	war_contract [
		"events"
	] = events


	if (
		str(
			strategic_intent.get(
				"attacker",
				""
			)
		).strip_edges().to_lower()
		== "seek_treaty"
		and str(
			strategic_intent.get(
				"defender",
				""
			)
		).strip_edges().to_lower()
		== "seek_treaty"
	):
		return _conclude_war_without_winner(
			war_contract,
			"peace_treaty",
			resolved_year
		)

	if (
		int(
			war_contract.get(
				"years_active",
				0
			)
		) >= WAR_STALEMATE_YEAR_LIMIT
		and absf(
			war_score
		) < 100.0
	):
		return _conclude_war_without_winner(
			war_contract,
			"stalemate",
			resolved_year
		)

	var attacker_exhausted: bool = (
		_war_side_exhausted(
			war_contract,
			"attacker"
		)
	)
	var defender_exhausted: bool = (
		_war_side_exhausted(
			war_contract,
			"defender"
		)
	)
	var winner_realm_id: int = -1
	var loser_realm_id: int = -1
	var conclusion_reason: String = str(
		war_contract.get(
			"conclusion_reason",
			""
		)
	)

	if (
		war_score >= 100.0
		or defender_exhausted
	):
		winner_realm_id = attacker_realm_id
		loser_realm_id = defender_realm_id

		if conclusion_reason == "":
			conclusion_reason = (
				"defender_resource_exhaustion"
				if defender_exhausted
				else "attacker_total_victory"
			)

	elif (
		war_score <= -100.0
		or attacker_exhausted
	):
		winner_realm_id = defender_realm_id
		loser_realm_id = attacker_realm_id

		if conclusion_reason == "":
			conclusion_reason = (
				"attacker_resource_exhaustion"
				if attacker_exhausted
				else "defender_total_victory"
			)

	if winner_realm_id != -1:
		war_contract [
			"state"
		] = "awaiting_outcome"
		war_contract [
			"winner_realm_id"
		] = winner_realm_id
		war_contract [
			"loser_realm_id"
		] = loser_realm_id
		war_contract [
			"conclusion_reason"
		] = conclusion_reason
		war_contract [
			"outcome_choices"
		] = [
			"spare",
			"treaty",
			"annex"
		]
		war_contract [
			"outcome_decision_year"
		] = resolved_year

	war_contract [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	return war_contract
func _conclude_war_without_winner(
	war_contract: Dictionary,
	resolution: String,
	year: int
) -> Dictionary:
	var out: Dictionary = (
		war_contract.duplicate(false)
	)
	var attacker_realm_id: int = int(
		out.get(
			"attacker_realm_id",
			-1
		)
	)
	var defender_realm_id: int = int(
		out.get(
			"defender_realm_id",
			-1
		)
	)

	out [
		"state"
	] = "concluded"
	out [
		"winner_realm_id"
	] = -1
	out [
		"loser_realm_id"
	] = -1
	out [
		"conclusion_reason"
	] = resolution
	out [
		"outcome_resolution"
	] = resolution
	out [
		"concluded_year"
	] = year

	if resolution == "peace_treaty":
		_apply_relation_delta(
			attacker_realm_id,
			defender_realm_id,
			12
		)
	else:
		_apply_relation_delta(
			attacker_realm_id,
			defender_realm_id,
			4
		)

	for raw_realm_id in _war_participant_realm_ids(
		out
	):
		_mark_realm_active_war(
			int(
				raw_realm_id
			),
			str(
				out.get(
					"war_id",
					""
				)
			),
			false
		)

	out [
		"war_report"
	] = _build_war_report_contract(
		out
	)
	out [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	return out
func _build_war_report_contract(
	war_contract: Dictionary
) -> Dictionary:
	var start_year: int = int(
		war_contract.get(
			"start_year",
			0
		)
	)
	var end_year: int = int(
		war_contract.get(
			"concluded_year",
			war_contract.get(
				"last_resolved_year",
				start_year
			)
		)
	)
	var duration_years: int = maxi(
		0,
		end_year - start_year
	)
	var casualties: Dictionary = _safe_dictionary(
		war_contract.get(
			"casualty_totals",
			{}
		)
	)
	var military_total: int = (
		int(
			casualties.get(
				"attacker_military",
				0
			)
		)
		+ int(
			casualties.get(
				"defender_military",
				0
			)
		)
	)
	var civilian_total: int = (
		int(
			casualties.get(
				"attacker_civilian",
				0
			)
		)
		+ int(
			casualties.get(
				"defender_civilian",
				0
			)
		)
	)

	return {
		"schema": (
			"eralife.war.history_report_contract"
		),
		"version": CONTRACT_VERSION,
		"war_id": str(
			war_contract.get(
				"war_id",
				""
			)
		),
		"attacker_name": str(
			war_contract.get(
				"attacker_name",
				"Realm"
			)
		),
		"defender_name": str(
			war_contract.get(
				"defender_name",
				"Realm"
			)
		),
		"attacker_side_realm_ids": (
			_war_side_realm_ids(
				war_contract,
				"attacker"
			)
		),
		"defender_side_realm_ids": (
			_war_side_realm_ids(
				war_contract,
				"defender"
			)
		),
		"start_year": start_year,
		"end_year": end_year,
		"duration_years": duration_years,
		"winner_realm_id": int(
			war_contract.get(
				"winner_realm_id",
				-1
			)
		),
		"loser_realm_id": int(
			war_contract.get(
				"loser_realm_id",
				-1
			)
		),
		"winner_name": str(
			_realm_snapshot(
				int(
					war_contract.get(
						"winner_realm_id",
						-1
					)
				)
			).get(
				"name",
				"No Decisive Winner"
			)
		),
		"conclusion_reason": str(
			war_contract.get(
				"conclusion_reason",
				""
			)
		),
		"outcome_resolution": str(
			war_contract.get(
				"outcome_resolution",
				""
			)
		),
		"casualty_totals": casualties,
		"casualty_types": [
			{
				"type": "military",
				"label": "Military Casualties",
				"total": military_total
			},
			{
				"type": "civilian",
				"label": "Civilian Casualties",
				"total": civilian_total
			},
			{
				"type": "displaced",
				"label": "Displaced",
				"total": int(
					casualties.get(
						"displaced",
						0
					)
				)
			}
		],
		"annual_casualty_reports": _safe_array(
			war_contract.get(
				"annual_casualty_reports",
				[]
			)
		),
		"resource_loss_totals": _safe_dictionary(
			war_contract.get(
				"resource_loss_totals",
				{}
			)
		),
		"battle_history": _safe_array(
			war_contract.get(
				"battle_history",
				[]
			)
		),
		"city_invasions": _safe_array(
			war_contract.get(
				"city_invasions",
				[]
			)
		),
		"events": _safe_array(
			war_contract.get(
				"events",
				[]
			)
		),
		"ui_is_renderer_only": true
	}
func _realm_leader_person(
	realm_id: int
) -> Person:
	if (
		gs == null
		or realm_id <= 0
		or gs.realm_engine == null
		or not gs.realm_engine.realms.has(
			realm_id
		)
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.realm_id
		) == realm_id
		and bool(
			gs.player.is_ruler
		)
	):
		return gs.player

	var realm: Dictionary = _safe_dictionary(
		gs.realm_engine.realms.get(
			realm_id,
			{}
		)
	)
	var ruler_id: int = int(
		realm.get(
			"ruler_id",
			realm.get(
				"leader_id",
				-1
			)
		)
	)

	if ruler_id <= 0:
		return null

	return gs.get_npc_by_id(
		ruler_id
	)
func _apply_war_leader_outcome(
	realm_id: int,
	victory: bool
) -> void:
	var leader: Person = _realm_leader_person(
		realm_id
	)

	if leader == null:
		return

	if victory:
		leader.approval = clampi(
			int(
				leader.approval
			) + 18,
			0,
			100
		)
		leader.fame = clampi(
			int(
				leader.fame
			) + 15,
			0,
			100
		)
		leader.satisfaction = clampf(
			float(
				leader.satisfaction
			) + 10.0,
			0.0,
			100.0
		)
		leader.mental_health = clampf(
			float(
				leader.mental_health
			) + 7.0,
			0.0,
			100.0
		)
	else:
		leader.approval = clampi(
			int(
				leader.approval
			) - 24,
			0,
			100
		)
		leader.fame = clampi(
			int(
				leader.fame
			) - 8,
			0,
			100
		)
		leader.satisfaction = clampf(
			float(
				leader.satisfaction
			) - 16.0,
			0.0,
			100.0
		)
		leader.mental_health = clampf(
			float(
				leader.mental_health
			) - 14.0,
			0.0,
			100.0
		)
func _apply_war_realm_outcome(
	winner_realm_id: int,
	loser_realm_id: int
) -> void:
	if (
		gs == null
		or gs.realm_engine == null
	):
		return

	var winner_exists: bool = (
		winner_realm_id > 0
		and gs.realm_engine.realms.has(
			winner_realm_id
		)
	)
	var loser_exists: bool = (
		loser_realm_id > 0
		and gs.realm_engine.realms.has(
			loser_realm_id
		)
	)

	var winner: Dictionary = (
		_safe_dictionary(
			gs.realm_engine.realms.get(
				winner_realm_id,
				{}
			)
		)
		if winner_exists
		else {}
	)
	var loser: Dictionary = (
		_safe_dictionary(
			gs.realm_engine.realms.get(
				loser_realm_id,
				{}
			)
		)
		if loser_exists
		else {}
	)

	var treasury_spoils: int = (
		int(
			round(
				float(
					loser.get(
						"treasury",
						0
					)
				) * 0.15
			)
		)
		if loser_exists
		else 0
	)
	var goods_spoils: int = (
		int(
			round(
				float(
					loser.get(
						"goods_stockpile",
						0
					)
				) * 0.18
			)
		)
		if loser_exists
		else 0
	)

	if loser_exists:
		loser [
			"treasury"
		] = maxi(
			0,
			int(
				loser.get(
					"treasury",
					0
				)
			) - treasury_spoils
		)
		loser [
			"goods_stockpile"
		] = maxi(
			0,
			int(
				loser.get(
					"goods_stockpile",
					0
				)
			) - goods_spoils
		)
		loser [
			"stability"
		] = clampi(
			int(
				loser.get(
					"stability",
					50
				)
			) - 22,
			0,
			100
		)
		loser [
			"prosperity"
		] = clampi(
			int(
				loser.get(
					"prosperity",
					50
				)
			) - 18,
			0,
			100
		)
		loser [
			"happiness"
		] = clampi(
			int(
				loser.get(
					"happiness",
					50
				)
			) - 20,
			0,
			100
		)

		gs.realm_engine.realms [
			loser_realm_id
		] = loser

	if winner_exists:
		winner [
			"treasury"
		] = int(
			winner.get(
				"treasury",
				0
			)
		) + treasury_spoils
		winner [
			"goods_stockpile"
		] = int(
			winner.get(
				"goods_stockpile",
				0
			)
		) + goods_spoils
		winner [
			"stability"
		] = clampi(
			int(
				winner.get(
					"stability",
					50
				)
			) + 12,
			0,
			100
		)
		winner [
			"prosperity"
		] = clampi(
			int(
				winner.get(
					"prosperity",
					50
				)
			) + 14,
			0,
			100
		)
		winner [
			"happiness"
		] = clampi(
			int(
				winner.get(
					"happiness",
					50
				)
			) + 10,
			0,
			100
		)

		gs.realm_engine.realms [
			winner_realm_id
		] = winner

	_apply_war_leader_outcome(
		winner_realm_id,
		true
	)
	_apply_war_leader_outcome(
		loser_realm_id,
		false
	)
func _war_metric_contract(
	metric_id: String,
	label: String,
	attacker_value: float,
	defender_value: float
) -> Dictionary:
	var attacker_state: String = "equal"
	var defender_state: String = "equal"

	if attacker_value > defender_value:
		attacker_state = "advantage"
		defender_state = "inferior"
	elif defender_value > attacker_value:
		attacker_state = "inferior"
		defender_state = "advantage"

	return {
		"metric_id": metric_id,
		"label": label,
		"attacker_value": attacker_value,
		"defender_value": defender_value,
		"attacker_state": attacker_state,
		"defender_state": defender_state,
		"advantage_color": "green",
		"inferior_color": "red",
		"equal_color": "neutral"
	}


func _realm_snapshot(
		realm_id: int
) -> Dictionary:
		if gs == null:
			return {}

		if realm_id == ERA_KINGDOM_WAR_REALM_ID:
			if (
				gs.many_realms_engine == null
				or not gs.many_realms_engine.has_method(
					"emit_world_browser_hidden_surface_registry"
				)
			):
				return {}

			var registry_raw: Variant = (
				gs.many_realms_engine
				.emit_world_browser_hidden_surface_registry(
					{
						"include_era_kingdom_preview": true,
						"source": (
							"war_contract_engine.realm_snapshot"
						),
						"ui_is_renderer_only": true
					}
				)
			)

			if typeof(registry_raw) != TYPE_DICTIONARY:
				return {}

			var era_raw: Variant = (
				(registry_raw as Dictionary).get(
					"era_kingdom",
					{}
				)
			)

			if typeof(era_raw) != TYPE_DICTIONARY:
				return {}

			return _war_snapshot_from_realm_dictionary(
				realm_id,
				era_raw as Dictionary,
				"era_kingdom"
			)

		if realm_id == TERABITHIA_WAR_REALM_ID:
			if (
				gs.bridge_to_terabithia_engine == null
				or not gs.bridge_to_terabithia_engine.has_method(
					"get_surface_entry_for_player"
				)
			):
				return {}

			var entry: Dictionary = (
				gs.bridge_to_terabithia_engine
				.get_surface_entry_for_player()
			)
			var realm_raw: Variant = entry.get(
				"realm",
				{}
			)

			if typeof(realm_raw) != TYPE_DICTIONARY:
				return {}

			return _war_snapshot_from_realm_dictionary(
				realm_id,
				realm_raw as Dictionary,
				"terabithia"
			)

		if (
			gs.realm_engine == null
			or realm_id <= 0
			or not gs.realm_engine.has_method(
				"get_resident_realm_war_snapshot"
			)
		):
			return {}





		var snapshot: Dictionary = (
			gs.realm_engine
			.get_resident_realm_war_snapshot(
				realm_id
			)
		)

		if snapshot.is_empty():
			return {}

		return snapshot
func _war_snapshot_from_realm_dictionary(
	realm_id: int,
	realm: Dictionary,
	realm_key: String = ""
) -> Dictionary:
	if realm.is_empty():
		return {}

	var population: int = int(
		realm.get(
			"population",
			0
		)
	)
	var land: int = int(
		realm.get(
			"land",
			realm.get(
				"land_size",
				0
			)
		)
	)
	var treasury: int = int(
		realm.get(
			"treasury",
			0
		)
	)
	var military: int = int(
		realm.get(
			"military_stockpile",
			realm.get(
				"military",
				0
			)
		)
	)
	var goods: int = int(
		realm.get(
			"goods_stockpile",
			0
		)
	)

	return {
		"realm_id": realm_id,
		"realm_key": realm_key,
		"name": str(
			realm.get(
				"name",
				"Unknown Realm"
			)
		),
		"population": population,
		"land": land,
		"treasury": treasury,
		"military_stockpile": military,
		"goods_stockpile": goods,
		"military_strength_score": (
			float(military) * 1.4
			+ float(population) * 0.08
			+ float(land) * 0.12
		),
		"economic_strength_score": (
			float(treasury) / 10000.0
			+ float(goods) * 9.0
			+ float(population) * 0.03
		),
		"government_style": str(
			realm.get(
				"government_style",
				"Realm"
			)
		),
		"external_realm_projection": (
			realm_id < 0
		)
	}
func _war_total_power(
	snapshot: Dictionary
) -> float:
	if snapshot.is_empty():
		return 0.0

	var conventional_power: float = (
		float(
			snapshot.get(
				"military_strength_score",
				0.0
			)
		) * 0.48
		+ float(
			snapshot.get(
				"economic_strength_score",
				0.0
			)
		) * 0.3
		+ float(
			snapshot.get(
				"population",
				0
			)
		) * 0.12
		+ float(
			snapshot.get(
				"land",
				0
			)
		) * 0.1
	)

	var capability: Dictionary = _safe_dictionary(
		snapshot.get(
			"elemental_war_capability",
			{}
		)
	)

	if not bool(
		capability.get(
			"enabled",
			false
		)
	):
		return conventional_power

	var mastery: float = clampf(
		float(
			capability.get(
				"effective_mastery",
				0
			)
		),
		0.0,
		100.0
	)
	var elemental_multiplier: float = (
		1.0
		+ (
			mastery / 100.0
		) * 1.35
	)

	return (
		conventional_power
		* elemental_multiplier
	)

func _strategy_modifier(
	intent: String
) -> float:
	match str(intent).strip_edges().to_lower():
		"advance":
			return 1.12
		"mobilize":
			return 1.16
		"invade_city":
			return 1.2
		"defend":
			return 1.1
		"hold":
			return 1.0
		"seek_treaty":
			return 0.84
		_:
			return 1.0


func _active_war_between(
	realm_a: int,
	realm_b: int
) -> Dictionary:
	var wars: Dictionary = _safe_dictionary(
		war_registry.get(
			"wars",
			{}
		)
	)

	for raw_war in wars.values():
		var war_contract: Dictionary = _safe_dictionary(
			raw_war
		)

		if str(
			war_contract.get(
				"state",
				""
			)
		).strip_edges().to_lower() not in [
			"active",
			"awaiting_outcome"
		]:
			continue

		var side_a: String = _war_side_for_realm(
			war_contract,
			realm_a
		)
		var side_b: String = _war_side_for_realm(
			war_contract,
			realm_b
		)

		if (
			side_a != ""
			and side_b != ""
			and side_a != side_b
		):
			return war_contract

	return {}
func _first_active_war_for_realm(
	realm_id: int
) -> Dictionary:
	var wars: Dictionary = _safe_dictionary(
		war_registry.get(
			"wars",
			{}
		)
	)

	for raw_war in wars.values():
		var war_contract: Dictionary = _safe_dictionary(
			raw_war
		)

		if str(
			war_contract.get(
				"state",
				""
			)
		).strip_edges().to_lower() not in [
			"active",
			"awaiting_outcome"
		]:
			continue

		if _war_side_for_realm(
			war_contract,
			realm_id
		) != "":
			return war_contract

	return {}
func _war_declaration_protection_contract(
		target_realm_id: int,
		context: Dictionary = {}
) -> Dictionary:
		var markers: Array = [
			str(
				context.get(
					"defender_realm_key",
					""
				)
			),
			str(
				context.get(
					"target_realm_key",
					""
				)
			),
			str(
				context.get(
					"defender_name",
					""
				)
			),
			str(
				context.get(
					"target_name",
					""
				)
			)
		]
		var supplied_snapshot_raw: Variant = (
			context.get(
				"resident_target_snapshot",
				{}
			)
		)
		var snapshot: Dictionary = (
			(supplied_snapshot_raw as Dictionary).duplicate(false)
			if typeof(
				supplied_snapshot_raw
			) == TYPE_DICTIONARY
			else {}
		)




		if snapshot.is_empty():
			snapshot = _realm_snapshot(
				target_realm_id
			)

		if not snapshot.is_empty():
			markers.append(
				str(
					snapshot.get(
						"name",
						""
					)
				)
			)
			markers.append(
				str(
					snapshot.get(
						"realm_key",
						""
					)
				)
			)

		if target_realm_id == ERA_KINGDOM_WAR_REALM_ID:
			markers.append(
				"era_kingdom"
			)

		if target_realm_id == TERABITHIA_WAR_REALM_ID:
			markers.append(
				"terabithia"
			)

		for raw_marker in markers:
			var marker: String = str(
				raw_marker
			).strip_edges().to_lower()

			if marker in [
				"era_kingdom",
				"era kingdom",
				"the era kingdom"
			]:
				return {
					"protected": true,
					"identity": "era_kingdom",
					"reason": (
						"The Era Kingdom cannot be targeted by a declaration of war."
					)
				}

			if (
				marker == "terabithia"
				or marker.contains(
					"terabithia"
				)
			):
				return {
					"protected": true,
					"identity": "terabithia",
					"reason": (
						"Terabithia cannot be targeted by a declaration of war."
					)
				}

		return {
			"protected": false,
			"identity": "",
			"reason": ""
		}
func _relation_score(
	source_realm_id: int,
	target_realm_id: int
) -> int:
	if source_realm_id == target_realm_id:
		return 100

	if (
		source_realm_id == 0
		or target_realm_id == 0
	):
		return 0

	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return _deterministic_base_relation_score(
			source_realm_id,
			target_realm_id
		)

	var relations: Dictionary = _safe_dictionary(
		gs.scenario_state.get(
			"crown_realm_relations",
			{}
		)
	)
	var key: String = "%d:%d" % [
		source_realm_id,
		target_realm_id
	]

	if relations.has(
		key
	):
		return clampi(
			int(
				relations.get(
					key,
					0
				)
			),
			-100,
			100
		)



	return _deterministic_base_relation_score(
		source_realm_id,
		target_realm_id
	)
func _deterministic_base_relation_score(
	realm_a: int,
	realm_b: int
) -> int:
	if realm_a == realm_b:
		return 100

	if (
		realm_a == 0
		or realm_b == 0
	):
		return 0

	var low_id: int = mini(
		realm_a,
		realm_b
	)
	var high_id: int = maxi(
		realm_a,
		realm_b
	)
	var world_seed: int = _war_world_seed()
	var relation_hash: int = abs(
		hash(
			"%d:%d:%d:eralife_realm_relation"
			% [
				world_seed,
				low_id,
				high_id
			]
		)
	)




	return int(
		relation_hash % 171
	) - 85
func _relation_tier_for_score(
	score: int
) -> String:
	if score >= 60:
		return "allied"

	if score >= 25:
		return "friendly"

	if score >= 0:
		return "neutral"

	if score >= -24:
		return "unfriendly"

	if score >= -49:
		return "strained"

	if score >= -69:
		return "hostile"

	if score >= -84:
		return "enemies"

	if score >= -99:
		return "sworn_enemies"

	return "pure_enemies"
func _relation_tier_label(
	tier: String
) -> String:
	match str(
		tier
	).strip_edges().to_lower():
		"allied":
			return "Allied"

		"friendly":
			return "Friendly"

		"neutral":
			return "Neutral"

		"unfriendly":
			return "Unfriendly"

		"strained":
			return "Strained"

		"hostile":
			return "Hostile"

		"enemies":
			return "Enemies"

		"sworn_enemies":
			return "Sworn enemies"

		"pure_enemies":
			return "Pure enemies"

		_:
			return "Neutral"
func emit_realm_relation_contract(
	source_realm_id: int,
	target_realm_id: int
) -> Dictionary:
	var score: int = _relation_score(
		source_realm_id,
		target_realm_id
	)

	var tier: String = _relation_tier_for_score(
		score
	)

	return {
		"schema": (
			"eralife.war.realm_relation_contract"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"source_realm_id": source_realm_id,
		"target_realm_id": target_realm_id,
		"score": score,
		"tier": tier,
		"tier_label": _relation_tier_label(
			tier
		),
		"allied": tier == "allied",
		"friendly": tier == "friendly",
		"negative_relation": score < 0,
		"hostile": tier in [
			"hostile",
			"enemies",
			"sworn_enemies",
			"pure_enemies"
		],
		"autonomous_war_eligible": tier in [
			"hostile",
			"enemies",
			"sworn_enemies",
			"pure_enemies"
		],
		"ui_is_renderer_only": true
	}
func _materialize_realm_relation_matrix() -> void:
	if (
		gs == null
		or gs.realm_engine == null
	):
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var relations: Dictionary = _safe_dictionary(
		gs.scenario_state.get(
			"crown_realm_relations",
			{}
		)
	)
	var realm_ids: Array = []

	for raw_realm_id in gs.realm_engine.realms.keys():
		var realm_id: int = int(
			raw_realm_id
		)

		if (
			realm_id > 0
			and not realm_ids.has(
				realm_id
			)
		):
			realm_ids.append(
				realm_id
			)

	realm_ids.sort()

	for left_index in range(
		realm_ids.size()
	):
		var left_id: int = int(
			realm_ids [
				left_index
			]
		)

		relations [
			"%d:%d" % [
				left_id,
				left_id
			]
		] = 100

		for right_index in range(
			left_index + 1,
			realm_ids.size()
		):
			var right_id: int = int(
				realm_ids [
					right_index
				]
			)
			var forward_key: String = "%d:%d" % [
				left_id,
				right_id
			]
			var reverse_key: String = "%d:%d" % [
				right_id,
				left_id
			]

			if (
				not relations.has(
					forward_key
				)
				and not relations.has(
					reverse_key
				)
			):
				var base_score: int = (
					_deterministic_base_relation_score(
						left_id,
						right_id
					)
				)

				relations [
					forward_key
				] = base_score
				relations [
					reverse_key
				] = base_score
			elif relations.has(
				forward_key
			):
				relations [
					reverse_key
				] = int(
					relations.get(
						forward_key,
						0
					)
				)
			else:
				relations [
					forward_key
				] = int(
					relations.get(
						reverse_key,
						0
					)
				)

	gs.scenario_state [
		"crown_realm_relations"
	] = relations
	gs.scenario_state [
		"crown_realm_relations_world_seed"
	] = _war_world_seed()


func _apply_relation_delta(
	source_realm_id: int,
	target_realm_id: int,
	delta: int
) -> void:
	if (
		gs == null
		or source_realm_id == 0
		or target_realm_id == 0
	):
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var relations: Dictionary = _safe_dictionary(
		gs.scenario_state.get(
			"crown_realm_relations",
			{}
		)
	)
	var forward_key: String = "%d:%d" % [
		source_realm_id,
		target_realm_id
	]
	var reverse_key: String = "%d:%d" % [
		target_realm_id,
		source_realm_id
	]
	var current_score: int = _relation_score(
		source_realm_id,
		target_realm_id
	)
	var next_score: int = clampi(
		current_score + delta,
		-100,
		100
	)

	relations [
		forward_key
	] = next_score
	relations [
		reverse_key
	] = next_score

	gs.scenario_state [
		"crown_realm_relations"
	] = relations
func _set_relation_score(
	source_realm_id: int,
	target_realm_id: int,
	score: int
) -> void:
	if (
		gs == null
		or source_realm_id == 0
		or target_realm_id == 0
	):
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var relations: Dictionary = _safe_dictionary(
		gs.scenario_state.get(
			"crown_realm_relations",
			{}
		)
	)
	var clean_score: int = clampi(
		score,
		-100,
		100
	)

	relations [
		"%d:%d" % [
			source_realm_id,
			target_realm_id
		]
	] = clean_score
	relations [
		"%d:%d" % [
			target_realm_id,
			source_realm_id
		]
	] = clean_score

	gs.scenario_state [
		"crown_realm_relations"
	] = relations


func _mark_realm_active_war(
	realm_id: int,
	war_id: String,
	active: bool
) -> void:


	if realm_id < 0:
		return

	if (
		gs == null
		or gs.realm_engine == null
		or realm_id <= 0
		or not gs.realm_engine.realms.has(
			realm_id
		)
	):
		return

	var realm: Dictionary = _safe_dictionary(
		gs.realm_engine.realms.get(
			realm_id,
			{}
		)
	)
	var active_war_ids: Array = _safe_array(
		realm.get(
			"active_war_ids",
			[]
		)
	)

	if active:
		if war_id not in active_war_ids:
			active_war_ids.append(
				war_id
			)
	else:
		active_war_ids.erase(
			war_id
		)

	realm [
		"active_war_ids"
	] = active_war_ids
	realm [
		"in_active_war"
	] = not active_war_ids.is_empty()
	realm [
		"active_war_id"
	] = (
		str(
			active_war_ids [
				0
			]
		)
		if not active_war_ids.is_empty()
		else ""
	)
	realm [
		"war_banner"
	] = (
		"AT WAR"
		if not active_war_ids.is_empty()
		else ""
	)
	realm [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	gs.realm_engine.realms [
		realm_id
	] = realm


func _drain_realm_war_resources(
	realm_id: int,
	treasury_rate: float,
	military_rate: float,
	goods_rate: float
) -> void:
	if (
		gs == null
		or gs.realm_engine == null
		or realm_id <= 0
		or not gs.realm_engine.realms.has(
			realm_id
		)
	):
		return

	var realm: Dictionary = _safe_dictionary(
		gs.realm_engine.realms.get(
			realm_id,
			{}
		)
	)
	realm ["treasury"] = maxi(
		0,
		int(
			round(
				float(
					realm.get(
						"treasury",
						0
					)
				) * (
					1.0 - treasury_rate
				)
			)
		)
	)
	realm ["military_stockpile"] = maxi(
		0,
		int(
			round(
				float(
					realm.get(
						"military_stockpile",
						0
					)
				) * (
					1.0 - military_rate
				)
			)
		)
	)
	realm ["goods_stockpile"] = maxi(
		0,
		int(
			round(
				float(
					realm.get(
						"goods_stockpile",
						0
					)
				) * (
					1.0 - goods_rate
				)
			)
		)
	)
	gs.realm_engine.realms [
		realm_id
	] = realm


func _realm_war_exhausted(
	realm_id: int
) -> bool:
	if (
		gs == null
		or gs.realm_engine == null
		or realm_id <= 0
		or not gs.realm_engine.realms.has(
			realm_id
		)
	):
		return true

	var realm: Dictionary = _safe_dictionary(
		gs.realm_engine.realms.get(
			realm_id,
			{}
		)
	)

	return (
		int(
			realm.get(
				"military_stockpile",
				0
			)
		) <= int(
			realm.get(
				"military_floor",
				0
			)
		)
		or int(
			realm.get(
				"treasury",
				0
			)
		) <= 0
		or int(
			realm.get(
				"goods_stockpile",
				0
			)
		) <= int(
			realm.get(
				"goods_floor",
				0
			)
		)
	)


func _apply_treaty_transfer(
	winner_realm_id: int,
	loser_realm_id: int
) -> void:
	if (
		gs == null
		or gs.realm_engine == null
		or not gs.realm_engine.realms.has(
			winner_realm_id
		)
		or not gs.realm_engine.realms.has(
			loser_realm_id
		)
	):
		return

	var winner: Dictionary = _safe_dictionary(
		gs.realm_engine.realms.get(
			winner_realm_id,
			{}
		)
	)
	var loser: Dictionary = _safe_dictionary(
		gs.realm_engine.realms.get(
			loser_realm_id,
			{}
		)
	)
	var treasury_transfer: int = int(
		round(
			float(
				loser.get(
					"treasury",
					0
				)
			) * 0.1
		)
	)
	var goods_transfer: int = int(
		round(
			float(
				loser.get(
					"goods_stockpile",
					0
				)
			) * 0.1
		)
	)

	loser ["treasury"] = maxi(
		0,
		int(
			loser.get(
				"treasury",
				0
			)
		) - treasury_transfer
	)
	loser ["goods_stockpile"] = maxi(
		0,
		int(
			loser.get(
				"goods_stockpile",
				0
			)
		) - goods_transfer
	)
	winner ["treasury"] = int(
		winner.get(
			"treasury",
			0
		)
	) + treasury_transfer
	winner ["goods_stockpile"] = int(
		winner.get(
			"goods_stockpile",
			0
		)
	) + goods_transfer

	gs.realm_engine.realms [
		winner_realm_id
	] = winner
	gs.realm_engine.realms [
		loser_realm_id
	] = loser


func _apply_annexation(
	winner_realm_id: int,
	loser_realm_id: int
) -> void:
	if (
		gs == null
		or gs.realm_engine == null
		or not gs.realm_engine.realms.has(
			winner_realm_id
		)
		or not gs.realm_engine.realms.has(
			loser_realm_id
		)
	):
		return

	var winner: Dictionary = _safe_dictionary(
		gs.realm_engine.realms.get(
			winner_realm_id,
			{}
		)
	)
	var loser: Dictionary = _safe_dictionary(
		gs.realm_engine.realms.get(
			loser_realm_id,
			{}
		)
	)

	for metric_id in [
		"population",
		"land",
		"treasury",
		"military_stockpile",
		"goods_stockpile"
	]:
		winner [metric_id] = int(
			winner.get(
				metric_id,
				0
			)
		) + int(
			loser.get(
				metric_id,
				0
			)
		)

	loser ["population"] = 0
	loser ["land"] = 0
	loser ["treasury"] = 0
	loser ["military_stockpile"] = 0
	loser ["goods_stockpile"] = 0
	loser ["state"] = "annexed"
	loser ["authority_realm_id"] = winner_realm_id
	loser ["government_style"] = str(
		winner.get(
			"government_style",
			loser.get(
				"government_style",
				"State"
			)
		)
	)

	gs.realm_engine.realms [
		winner_realm_id
	] = winner
	gs.realm_engine.realms [
		loser_realm_id
	] = loser

func _ensure_state() -> void:
	var world_seed: int = _war_world_seed()

	if (
		not war_registry.is_empty()
		and int(
			war_registry.get(
				"world_seed",
				-1
			)
		) == world_seed
	):
		return

	var resident_registry: Dictionary = {}

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		var resident_raw: Variant = (
			gs.scenario_state.get(
				"war_registry",
				{}
			)
		)

		if typeof(resident_raw) == TYPE_DICTIONARY:
			var candidate: Dictionary = (
				resident_raw as Dictionary
			)

			if int(
				candidate.get(
					"world_seed",
					-1
				)
			) == world_seed:
				resident_registry = (
					candidate.duplicate(false)
				)

	if resident_registry.is_empty():
		var disk_registry: Dictionary = (
			_read_registry()
		)

		if int(
			disk_registry.get(
				"world_seed",
				-1
			)
		) == world_seed:
			resident_registry = (
				disk_registry.duplicate(false)
			)

	if resident_registry.is_empty():
		resident_registry = {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"world_seed": world_seed,
			"wars": {},
			"created_at_ms": int(
				Time.get_ticks_msec()
			),
			"updated_at_ms": int(
				Time.get_ticks_msec()
			)
		}

	if typeof(
		resident_registry.get(
			"wars",
			{}
		)
	) != TYPE_DICTIONARY:
		resident_registry [
			"wars"
		] = {}

	resident_registry [
		"world_seed"
	] = world_seed

	war_registry = resident_registry
func _war_world_seed() -> int:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return -1

	return int(
		gs.scenario_state.get(
			"world_seed",
			-1
		)
	)
func _queue_war_persistence_tail() -> void:
		_publish_war_world_feed_from_last_report()

		if war_persistence_tail_armed:
			return

		war_persistence_tail_armed = true

		call_deferred(
			"_flush_war_persistence_tail"
		)
func _publish_war_world_feed_from_last_report() -> void:
		if (
			gs == null
			or not gs.has_method(
				"push_world_feed"
			)
			or last_report.is_empty()
		):
			return

		if (
			not bool(
				last_report.get(
					"success",
					false
				)
			)
			or not bool(
				last_report.get(
					"committed",
					false
				)
			)
			or bool(
				last_report.get(
					"world_feed_published",
					false
				)
			)
		):
			return

		var mode: String = str(
			last_report.get(
				"mode",
				""
			)
		).strip_edges().to_lower()

		if mode not in [
			"war_declared",
			"war_joined_by_declaration"
		]:
			return

		var war: Dictionary = _safe_dictionary(
			last_report.get(
				"war",
				{}
			)
		)
		var war_id: String = str(
			war.get(
				"war_id",
				last_report.get(
					"war_id",
					""
				)
			)
		).strip_edges()
		var attacker_realm_id: int = int(
			war.get(
				"attacker_realm_id",
				last_report.get(
					"declaring_realm_id",
					-1
				)
			)
		)
		var defender_realm_id: int = int(
			war.get(
				"defender_realm_id",
				last_report.get(
					"target_realm_id",
					-1
				)
			)
		)
		var feed_text: String = str(
			last_report.get(
				"popup_text",
				"A new war has begun."
			)
		).strip_edges()

		if feed_text == "":
			feed_text = "A new war has begun."

		gs.push_world_feed(
			feed_text,
			{
				"category": "war",
				"event_name": mode,
				"war_id": war_id,
				"attacker_realm_id": attacker_realm_id,
				"defender_realm_id": defender_realm_id,
				"personally_relevant": true,
				"source": "war_contract_engine",
			}
		)

		last_report [
			"world_feed_published"
		] = true
		last_report [
			"world_feed_published_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
func _flush_war_persistence_tail() -> void:
	war_persistence_tail_armed = false

	_write_registry()
	_commit_state()


func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(WAR_REGISTRY_PATH):
		return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "wars": {}}

	var file:= FileAccess.open(WAR_REGISTRY_PATH, FileAccess.READ)
	if file == null:
		return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "wars": {}}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		var data: Dictionary = (parsed as Dictionary).duplicate(true)
		if typeof(data.get("wars", {})) != TYPE_DICTIONARY:
			data ["wars"] = {}
		return data

	return { "schema": ENGINE_SCHEMA, "version": CONTRACT_VERSION, "wars": {}}


func _write_registry() -> void:
	_ensure_war_dir()
	var file:= FileAccess.open(WAR_REGISTRY_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(war_registry, "\t"))
	file.close()


func _ensure_war_dir() -> void:
	var root_dir:= DirAccess.open("user://")
	if root_dir != null and not root_dir.dir_exists("war"):
		root_dir.make_dir("war")


func _commit_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["war_registry"] = war_registry.duplicate(true)
	gs.scenario_state ["last_war_report"] = last_report.duplicate(true)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _sort_wars_by_updated(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("updated_at_ms", 0)) > int(b.get("updated_at_ms", 0))


func _fail(reason_id: String, message: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.war.error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_commit_state()
	return last_report.duplicate(true)