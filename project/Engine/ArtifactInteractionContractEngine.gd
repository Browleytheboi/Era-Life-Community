

extends RefCounted
class_name ArtifactInteractionContractEngine

const ENGINE_SCHEMA:= "eralife.artifact_interaction_contract_engine"
const ENGINE_VERSION:= 1
const OBSERVABILITY_SCHEMA:= "eralife.artifact_observability_contract"
const ITEM_PROJECTION_SCHEMA:= "eralife.artifact_item_interaction_contract"
const CACHE_KEY:= "artifact_interaction_projection_cache"

var gs
var projection_cache: Dictionary = {}
var last_report: Dictionary = {}


func _init(
	_game_state = null
) -> void:
	gs = _game_state
	_ensure_cache()


func bind_game_state(
	_game_state
) -> void:
	gs = _game_state
	_ensure_cache()


func bootstrap_default_contracts() -> Dictionary:
	_ensure_cache()
	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"artifact_truth_authority": "artifacts_engine",
		"red_bonnet_truth_authority": "red_bonnet_engine",
		"catalog_authority": "artifacts_catalog_contract_engine",
		"ui_is_renderer_only": true
	}
	return last_report.duplicate(true)


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")

	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get("intent_id", "observe")
		)
	).strip_edges().to_lower()

	match action_id:
		"observe", "refresh", "observe_artifacts":
			return {
				"success": true,
				"mode": "artifact_observability_projected",
				"artifact_contract": emit_observability_contract(actor),
				"ui_is_renderer_only": true
			}

		"inspect_item", "project_item":
			var item: Dictionary = _safe_dictionary(
				payload.get("item", payload.get("source_item", {}))
			)
			return {
				"success": true,
				"mode": "artifact_item_projected",
				"item_projection": emit_item_projection(actor, item),
				"ui_is_renderer_only": true
			}

		"perform_artifact_action", "perform_self_action":
			return _perform_artifact_action(actor, actor, payload)

		"perform_artifact_target_action", "perform_target_action":
			var target: Person = _person_by_id(
				int(payload.get("target_id", -1))
			)
			return _perform_artifact_action(actor, target, payload)

		"perform_red_bonnet_wish", "perform_wish":
			return _perform_red_bonnet_wish(actor, payload)

		"wish_requires_target":
			return {
				"success": true,
				"mode": "red_bonnet_wish_requirement_projected",
				"wish_name": str(payload.get("wish_name", "")),
				"requires_target": wish_requires_target(
					str(payload.get("wish_name", ""))
				),
				"ui_is_renderer_only": true
			}

		"summon_dragon_balls":
			return _summon_dragon_balls(actor, payload)

		"build_dragon_ball_summon_transition":
			return _build_dragon_ball_summon_transition(actor, payload)

		"flush_deferred_red_bonnet_effects", "flush_deferred_artifact_effects":
			return _flush_deferred_artifact_effects(
				int(payload.get("max_count", 1))
			)

		"last_red_bonnet_action_result":
			return {
				"success": true,
				"mode": "red_bonnet_last_result_projected",
				"result": last_red_bonnet_action_result(),
				"ui_is_renderer_only": true
			}

		_:
			return _fail(
				"unsupported_artifact_interaction_intent",
				{
					"action_id": action_id
				}
			)


func emit_observability_contract(
	actor: Person
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")

	var owned_stones: Array = []
	for stone_name in ["Mind", "Reality", "Space", "Time", "Soul", "Power"]:
		if _person_has_stone(actor, stone_name):
			owned_stones.append(stone_name)

	var contract: Dictionary = {
		"success": true,
		"schema": OBSERVABILITY_SCHEMA,
		"version": 1,
		"actor_id": int(actor.id),
		"owned_stones": owned_stones,
		"owned_stone_count": clampi(owned_stones.size(), 0, 6),
		"owns_all_stones": owned_stones.size() >= 6,
		"artifact_signature": "stones_%s" % "_".join(owned_stones),
		"feature_enabled": _artifacts_feature_enabled(),
		"truth_state": "hot",
		"projection_composed": true,
		"hydrated": true,
		"ui_is_renderer_only": true,
		"generated_at_ms": int(Time.get_ticks_msec())
	}
	projection_cache ["actor:%d" % int(actor.id)] = contract.duplicate(true)
	_sync_cache()
	return contract


func emit_item_projection(
	actor: Person,
	item: Dictionary
) -> Dictionary:
	var action_specs: Array = artifact_action_specs(item)
	var wishes: Array = red_bonnet_wishes(actor)
	var wish_rows: Array = []

	for raw_wish in wishes:
		var wish_name: String = str(raw_wish).strip_edges()
		if wish_name == "":
			continue
		wish_rows.append({
			"wish_name": wish_name,
			"requires_target": wish_requires_target(wish_name)
		})

	return {
		"success": true,
		"schema": ITEM_PROJECTION_SCHEMA,
		"version": 1,
		"actor_id": int(actor.id) if actor != null else -1,
		"item": item.duplicate(true),
		"action_specs": action_specs,
		"market_profile": artifact_market_profile(actor, item),
		"available_wishes": wishes,
		"wish_rows": wish_rows,
		"ui_is_renderer_only": true
	}


func artifact_action_specs(
	item: Dictionary
) -> Array:
	if gs == null or gs.artifacts_engine == null:
		return []
	if gs.artifacts_engine.has_method("get_artifact_action_specs"):
		return _safe_array(
			gs.artifacts_engine.get_artifact_action_specs(item)
		)
	if gs.artifacts_engine.has_method("get_artifact_action_definitions"):
		return _safe_array(
			gs.artifacts_engine.get_artifact_action_definitions(item)
		)
	return []


func artifact_market_profile(
	actor: Person,
	item: Dictionary
) -> Dictionary:
	if (
		gs != null
		and gs.artifacts_engine != null
		and gs.artifacts_engine.has_method("get_item_market_profile")
	):
		var profile: Variant = gs.artifacts_engine.get_item_market_profile(item)
		if typeof(profile) == TYPE_DICTIONARY:
			return (profile as Dictionary).duplicate(true)

	if gs != null and gs.global_object_catalog_system != null:
		var object_id: String = str(
			item.get(
				"instance_object_id",
				item.get(
					"catalog_object_id",
					item.get("object_id", "")
				)
			)
		).strip_edges()
		if object_id != "":
			var object_contract: Dictionary = _safe_dictionary(
				gs.global_object_catalog_system.resolve_object(
					object_id,
					{
						"actor_id": int(actor.id) if actor != null else -1,
						"include_owned_instances": true,
						"include_catalog_definitions": true
					}
				)
			)
			return _safe_dictionary(
				object_contract.get("value_contract", {})
			)
	return {}


func red_bonnet_wishes(
	actor: Person
) -> Array:
	if (
		actor == null
		or gs == null
		or gs.red_bonnet_engine == null
		or not gs.red_bonnet_engine.has_method("get_available_wishes")
	):
		return []
	return _safe_array(
		gs.red_bonnet_engine.get_available_wishes(actor)
	)


func wish_requires_target(
	wish_name: String
) -> bool:
	if (
		gs == null
		or gs.red_bonnet_engine == null
		or not gs.red_bonnet_engine.has_method("wish_requires_target")
	):
		return false
	return bool(
		gs.red_bonnet_engine.wish_requires_target(wish_name)
	)


func last_red_bonnet_action_result() -> Dictionary:
	if gs == null or gs.red_bonnet_engine == null:
		return {}
	if "last_rewrite_report" in gs.red_bonnet_engine:
		return _safe_dictionary(
			gs.red_bonnet_engine.last_rewrite_report
		)
	return {}


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"projection_cache": projection_cache.duplicate(true),
	}


func import_state(
	data: Dictionary
) -> Dictionary:
	projection_cache = _safe_dictionary(
		data.get("projection_cache", {})
	)
	_sync_cache()
	return {
		"success": true,
		"mode": "artifact_interaction_projection_cache_imported",
		"cache_count": projection_cache.size()
	}


func _perform_artifact_action(
	actor: Person,
	target: Person,
	payload: Dictionary
) -> Dictionary:
	if actor == null or target == null:
		return _fail("artifact_action_target_unavailable")

	var item: Dictionary = _safe_dictionary(
		payload.get("item", payload.get("source_item", {}))
	)
	var action_label: String = str(
		payload.get(
			"action_label",
			payload.get("action_name", "")
		)
	).strip_edges()
	var resolver_method: String = str(
		payload.get("resolver_method", "perform_artifact_action")
	).strip_edges()
	var result: Dictionary = {}

	if gs != null and gs.artifacts_engine != null:
		if (
			resolver_method == "perform_artifact_action"
			and gs.artifacts_engine.has_method("perform_artifact_action")
		):
			result = _safe_dictionary(
				gs.artifacts_engine.perform_artifact_action(
					item,
					action_label,
					target
				)
			)
		elif gs.artifacts_engine.has_method(resolver_method):
			result = _safe_dictionary(
				gs.artifacts_engine.call(
					resolver_method,
					item,
					payload,
					target
				)
			)

	if (
		not bool(result.get("success", false))
		and gs != null
		and gs.red_bonnet_engine != null
	):
		if (
			resolver_method == "perform_red_bonnet_action"
			and gs.red_bonnet_engine.has_method("perform_red_bonnet_action")
		):
			result = _safe_dictionary(
				gs.red_bonnet_engine.perform_red_bonnet_action(
					item,
					action_label,
					target
				)
			)
		elif gs.red_bonnet_engine.has_method(resolver_method):
			result = _safe_dictionary(
				gs.red_bonnet_engine.call(
					resolver_method,
					item,
					action_label,
					target
				)
			)

	if result.is_empty():
		return _fail("artifact_action_unresolved")
	return result


func _perform_red_bonnet_wish(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if gs == null or gs.red_bonnet_engine == null:
		return _fail("red_bonnet_engine_unavailable")

	var wish_name: String = str(payload.get("wish_name", "")).strip_edges()
	var target_id: int = int(payload.get("target_id", -1))
	var target: Person = _person_by_id(target_id)
	var result_text: String = ""

	if (
		target != null
		and gs.red_bonnet_engine.has_method("reality_wish_on_target")
	):
		result_text = str(
			gs.red_bonnet_engine.reality_wish_on_target(
				actor,
				wish_name,
				target
			)
		)
	elif gs.red_bonnet_engine.has_method("reality_wish"):
		result_text = str(
			gs.red_bonnet_engine.reality_wish(
				actor,
				wish_name
			)
		)
	else:
		return _fail("red_bonnet_wish_method_unavailable")

	return {
		"success": true,
		"mode": "red_bonnet_wish_committed",
		"wish_name": wish_name,
		"target_id": int(target.id) if target != null else -1,
		"text": result_text,
		"popup_title": "Red Bonnet Wish",
		"popup_text": result_text,
		"popup_footer": "Tap anywhere to continue."
	}


func _summon_dragon_balls(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.red_bonnet_engine == null
		or not gs.red_bonnet_engine.has_method("summon_dragon_balls_to_inventory")
	):
		return _fail("red_bonnet_summon_method_unavailable")

	var summon_payload: Dictionary = payload.duplicate(true)
	summon_payload ["actor"] = actor
	summon_payload ["actor_id"] = int(actor.id)
	return _safe_dictionary(
		gs.red_bonnet_engine.summon_dragon_balls_to_inventory(
			summon_payload
		)
	)


func _build_dragon_ball_summon_transition(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.red_bonnet_engine == null
		or not gs.red_bonnet_engine.has_method(
			"build_dragon_ball_summon_transition_packet"
		)
	):
		return _fail("red_bonnet_transition_method_unavailable")
	return _safe_dictionary(
		gs.red_bonnet_engine.build_dragon_ball_summon_transition_packet(
			actor,
			payload
		)
	)


func _flush_deferred_artifact_effects(
	max_count: int
) -> Dictionary:
	if gs == null:
		return _fail(
			"missing_game_state"
		)

	var budget: int = maxi(
		1,
		max_count
	)
	var dragon_report: Dictionary = {}
	var red_bonnet_report: Dictionary = {}

	if (
		gs.dragonballs_engine != null
		and gs.dragonballs_engine.has_method(
			"_flush_deferred_dragonball_grant_echoes"
		)
	):
		dragon_report = _safe_dictionary(
			gs.dragonballs_engine._flush_deferred_dragonball_grant_echoes(
				budget
			)
		)

	if (
		gs.red_bonnet_engine != null
		and gs.red_bonnet_engine.has_method(
			"_flush_deferred_red_bonnet_dragonball_effects"
		)
	):
		red_bonnet_report = _safe_dictionary(
			gs.red_bonnet_engine._flush_deferred_red_bonnet_dragonball_effects(
				budget
			)
		)

	var remaining_red_queue_size: int = 0
	var remaining_dragon_queue_size: int = 0

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		remaining_red_queue_size = maxi(
			0,
			int(
				gs.scenario_state.get(
					"red_bonnet_deferred_effect_queue_size",
					0
				)
			)
		)
		remaining_dragon_queue_size = maxi(
			0,
			int(
				gs.scenario_state.get(
					"dragonball_grant_echo_queue_size",
					0
				)
			)
		)

	return {
		"success": true,
		"mode": "deferred_artifact_effects_flushed",
		"dragonballs_report": dragon_report,
		"red_bonnet_report": red_bonnet_report,
		"remaining_red_queue_size": (
			remaining_red_queue_size
		),
		"remaining_dragon_queue_size": (
			remaining_dragon_queue_size
		),
		"remaining_queue_size": (
			remaining_red_queue_size
			+ remaining_dragon_queue_size
		),
		"flush_budget": budget,
		"ui_is_renderer_only": true
	}


func _person_has_stone(
	actor: Person,
	stone_name: String
) -> bool:
	if actor == null:
		return false
	if (
		gs != null
		and gs.artifacts_engine != null
		and gs.artifacts_engine.has_method("person_has_stone")
	):
		return bool(
			gs.artifacts_engine.person_has_stone(actor, stone_name)
		)
	if gs != null and gs.belongings_engine != null:
		return gs.belongings_engine.has_item_named(
			actor,
			"Artifacts",
			"%s Infinity Stone" % stone_name
		)
	return false


func _artifacts_feature_enabled() -> bool:
	if gs == null:
		return false
	if gs.has_method("is_feature_enabled"):
		return bool(gs.is_feature_enabled("artifacts"))
	return true


func _person_by_id(
	person_id: int
) -> Person:
	if gs == null or person_id <= 0:
		return null
	if gs.player != null and int(gs.player.id) == person_id:
		return gs.player
	if gs.has_method("get_or_reactivate_npc_by_id"):
		var active: Variant = gs.get_or_reactivate_npc_by_id(person_id)
		if active is Person:
			return active as Person
	if gs.has_method("get_npc_by_id"):
		var found: Variant = gs.get_npc_by_id(person_id)
		if found is Person:
			return found as Person
	return null


func _ensure_cache() -> void:
	if (
		projection_cache.is_empty()
		and gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		projection_cache = _safe_dictionary(
			gs.scenario_state.get(CACHE_KEY, {})
		)
	_sync_cache()


func _sync_cache() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [CACHE_KEY] = projection_cache.duplicate(true)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _fail(
	reason: String,
	extra: Dictionary = {}
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	var report: Dictionary = {
		"success": false,
		"reason": reason,
		"mode": "artifact_interaction_contract_rejected",
		"ui_is_renderer_only": true
	}
	for key in extra.keys():
		report [key] = extra [key]
	return report