

extends RefCounted
class_name ObjectHubContractEngine

const ENGINE_SCHEMA:= "eralife.object_hub_contract_engine"
const ENGINE_VERSION:= 1
const HUB_SCHEMA:= "eralife.object_hub_contract"
const HUB_VERSION:= 1
const LENS_KEY:= "object_hub_lenses"

var gs
var lens_state: Dictionary = {}
var last_report: Dictionary = {}


func _init(
	_game_state = null
) -> void:
	gs = _game_state
	_ensure_lens_state()


func bind_game_state(
	_game_state
) -> void:
	gs = _game_state
	_ensure_lens_state()


func bootstrap_default_contracts() -> Dictionary:
	_ensure_lens_state()
	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"catalog_authority": "global_object_catalog_system",
		"sections": ["all", "owned", "weapons", "heirlooms", "artifacts", "history"],
		"ui_is_renderer_only": true
	}
	return last_report.duplicate(true)


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")
	var action_id: String = str(payload.get("action_id", "refresh")).strip_edges().to_lower()
	var section_id: String = _section(str(payload.get("section_id", "all")))
	var selected_object_id: String = str(payload.get("object_id", "")).strip_edges()

	if action_id not in ["open", "refresh", "change_section", "select_object", "observe_partial"]:
		return _fail("unsupported_object_hub_intent")

	_commit_lens(actor, section_id, selected_object_id)
	return {
		"success": true,
		"mode": "object_hub_intent_resolved",
		"hub_contract": emit_object_hub_contract(
			actor,
			payload.merged({
				"section_id": section_id,
				"object_id": selected_object_id
			}, true)
		),
		"ui_is_renderer_only": true
	}


func emit_observable_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	return emit_object_hub_contract(actor, context)


func emit_object_hub_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail("missing_actor")
	if gs == null or gs.global_object_catalog_system == null:
		return _fail("global_object_catalog_system_unavailable")

	var lens: Dictionary = _lens_for(int(actor.id))
	var section_id: String = _section(str(context.get("section_id", lens.get("active_section", "all"))))
	var selected_object_id: String = str(context.get("object_id", lens.get("selected_object_id", ""))).strip_edges()
	var query: Dictionary = {
		"actor_id": int(actor.id),
		"include_owned_instances": true,
		"include_catalog_definitions": section_id not in ["owned", "history"],
		"include_modded": true,
		"ownership_scope": "owned" if section_id in ["owned", "history"] else "available"
	}

	match section_id:
		"weapons":
			query ["domain"] = "weapon"
		"heirlooms":
			query ["domain"] = "heirloom"
		"artifacts":
			query ["domain"] = "artifact"

	var lens_contract: Dictionary = gs.global_object_catalog_system.emit_object_lens_contract(query)
	var objects: Array = _safe_array(lens_contract.get("objects", []))
	var selected_object: Dictionary = {}
	if selected_object_id != "":
		selected_object = gs.global_object_catalog_system.resolve_object(
			selected_object_id,
			query
		)

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": int(actor.id),
		"active_section": section_id,
		"selected_object_id": selected_object_id,
		"selected_object": selected_object,
		"tabs": _tabs(),
		"objects": objects,
		"object_count": objects.size(),
		"domain_counts": _safe_dictionary(lens_contract.get("domain_counts", {})),
		"provider_contracts": _safe_array(lens_contract.get("provider_contracts", [])),
		"registry_revision": int(lens_contract.get("registry_revision", 0)),
		"truth_state": "hot",
		"projection_composed": true,
		"hydrated": true,
		"ui_is_renderer_only": true,
		"generated_at_ms": int(Time.get_ticks_msec())
	}


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"lenses": lens_state.duplicate(true),
	}


func import_state(
	data: Dictionary
) -> Dictionary:
	lens_state = _safe_dictionary(data.get("lenses", {}))
	_sync_lens_state()
	return {
		"success": true,
		"mode": "object_hub_lenses_imported",
		"lens_count": lens_state.size()
	}


func _tabs() -> Array:
	return [
		{ "id": "all", "label": "All Objects"},
		{ "id": "owned", "label": "Owned"},
		{ "id": "weapons", "label": "Weapons"},
		{ "id": "heirlooms", "label": "Heirlooms"},
		{ "id": "artifacts", "label": "Artifacts"},
		{ "id": "history", "label": "History"}
	]


func _section(
	value: String
) -> String:
	var clean: String = str(value).strip_edges().to_lower()
	if clean not in ["all", "owned", "weapons", "heirlooms", "artifacts", "history"]:
		return "all"
	return clean


func _commit_lens(
	actor: Person,
	section_id: String,
	selected_object_id: String
) -> void:
	lens_state [str(int(actor.id))] = {
		"active_section": _section(section_id),
		"selected_object_id": selected_object_id,
		"updated_at_ms": int(Time.get_ticks_msec())
	}
	_sync_lens_state()


func _lens_for(
	actor_id: int
) -> Dictionary:
	return _safe_dictionary(
		lens_state.get(
			str(actor_id),
			{
				"active_section": "all",
				"selected_object_id": ""
			}
		)
	)


func _ensure_lens_state() -> void:
	if lens_state.is_empty() and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		lens_state = _safe_dictionary(gs.scenario_state.get(LENS_KEY, {}))
	_sync_lens_state()


func _sync_lens_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [LENS_KEY] = lens_state.duplicate(true)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _fail(
	reason: String
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"reason": reason,
		"mode": "object_hub_contract_rejected",
		"ui_is_renderer_only": true
	}