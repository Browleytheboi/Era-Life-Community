extends Resource
class_name AdobeFlashContractEngine

const ENGINE_SCHEMA:= "eralife.adobe_flash_contract_engine"
const ENGINE_VERSION:= 1
const STATE_KEY:= "adobe_flash_contract_state"

var gs: GameState = null
var state: Dictionary = {}
var provider_registry: Dictionary = {}


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()


func bootstrap_default_contracts() -> Dictionary:
	var provider:= StickFighterMiniGameProvider.new()
	return register_flash_reality_provider(
		provider.flash_reality_provider_contract(),
		{ "source": "builtin_stick_fighter", "first_party": true}
	)


func register_flash_reality_provider(
	provider_contract: Dictionary, context: Dictionary = {}
) -> Dictionary:
	var provider_id: String = _id(str(provider_contract.get("provider_id", "")))
	if provider_id == "":
		return _failure(
			"missing_provider_id", "Flash-like reality providers require a stable provider_id."
		)
	var normalized: Dictionary = provider_contract.duplicate(true)
	normalized ["schema"] = "eralife.flash_reality_provider_contract"
	normalized ["version"] = int(normalized.get("version", 1))
	normalized ["provider_id"] = provider_id
	normalized ["registered_at_ms"] = int(Time.get_ticks_msec())
	normalized ["registration_context"] = _serializable_dictionary(context)
	normalized ["runs_adobe_flash_binary"] = false
	normalized ["hosts_flash_like_reality_through_contracts"] = true
	normalized ["ui_is_renderer_only"] = true
	provider_registry [provider_id] = normalized
	var installed: Dictionary = _dict(state.get("installed_providers", {}))
	installed [provider_id] = {
		"provider_id": provider_id,
		"title": str(normalized.get("title", provider_id.capitalize())),
		"revision": str(normalized.get("revision", normalized.get("version", 1))),
		"enabled": true,
		"registered_at_ms": int(Time.get_ticks_msec())
	}
	state ["installed_providers"] = installed
	_publish_state()
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "flash_reality_provider_registered",
		"provider_id": provider_id,
		"provider_contract": normalized.duplicate(true),
		"ui_is_renderer_only": true
	}


func emit_flash_reality_contract(
	provider_id: String, actor: Person, context: Dictionary = {}
) -> Dictionary:
	_ensure_mod_flash_providers(actor, context)
	var provider: Dictionary = _dict(provider_registry.get(_id(provider_id), {}))
	if provider.is_empty():
		return _failure("provider_missing", "That Flash-like reality provider is unavailable.")
	return {
		"success": true,
		"schema": "eralife.flash_reality_contract",
		"version": ENGINE_VERSION,
		"provider_id": _id(provider_id),
		"actor_id": int(actor.id) if actor != null else -1,
		"activity_provider": _dict(provider.get("flash_activity_provider", {})).duplicate(true),
		"minigame_provider": _dict(provider.get("flash_minigame_provider", {})).duplicate(true),
		"npc_provider": _dict(provider.get("flash_npc_provider", {})).duplicate(true),
		"item_provider": _dict(provider.get("flash_item_provider", {})).duplicate(true),
		"sound_provider": _dict(provider.get("flash_sound_provider", {})).duplicate(true),
		"achievement_provider":
		_dict(provider.get("flash_achievement_provider", {})).duplicate(true),
		"animation_provider": _dict(provider.get("flash_animation_provider", {})).duplicate(true),
		"world_adapter": emit_flash_world_adapter(provider_id, context),
		"ui_projection": emit_flash_ui_projection(provider_id, {}, context),
		"context": context.duplicate(true),
		"runs_adobe_flash_binary": false,
		"hosts_flash_like_reality_through_contracts": true,
		"truth_state": "hot",
		"authoritative_projection": true,
		"ui_is_renderer_only": true
	}


func emit_flash_world_adapter(provider_id: String, context: Dictionary = {}) -> Dictionary:
	var provider: Dictionary = _dict(provider_registry.get(_id(provider_id), {}))
	var adapter: Dictionary = _dict(provider.get("world_adapter", {})).duplicate(true)
	adapter ["schema"] = "eralife.flash_world_adapter_contract"
	adapter ["version"] = ENGINE_VERSION
	adapter ["provider_id"] = _id(provider_id)
	adapter ["host_contract"] = _dict(context.get("host_contract", {})).duplicate(true)
	adapter ["reality_runtime_authority"] = "mini_game_runtime_engine"
	adapter ["world_state_is_provider_owned"] = true
	adapter ["ui_is_renderer_only"] = true
	return adapter


func emit_flash_ui_projection(
	provider_id: String, session_contract: Dictionary = {}, context: Dictionary = {}
) -> Dictionary:
	var provider: Dictionary = _dict(provider_registry.get(_id(provider_id), {}))
	var projection: Dictionary = _dict(provider.get("ui_projection", {})).duplicate(true)
	projection ["schema"] = "eralife.flash_ui_projection_contract"
	projection ["version"] = ENGINE_VERSION
	projection ["provider_id"] = _id(provider_id)
	projection ["session_id"] = str(session_contract.get("session_id", ""))
	projection ["provider_state"] = _dict(session_contract.get("provider_state", {})).duplicate(true)
	projection ["context"] = context.duplicate(true)
	projection ["projection_only"] = true
	projection ["launch_authority"] = "mini_game_contract_engine"
	projection ["ui_is_renderer_only"] = true
	return projection


func provider_rows(facet: String, actor: Person, context: Dictionary = {}) -> Array:
	_ensure_mod_flash_providers(actor, context)
	var clean_facet: String = _id(facet)
	var key: String = "flash_%s_provider" % clean_facet
	var out: Array = []
	for raw_provider in provider_registry.values():
		var provider: Dictionary = _dict(raw_provider)
		var facet_contract: Dictionary = _dict(provider.get(key, {}))
		for raw_row in _array(facet_contract.get("rows", [])):
			var row: Dictionary = _dict(raw_row).duplicate(true)
			row ["provider_id"] = str(provider.get("provider_id", ""))
			row ["flash_facet"] = clean_facet
			row ["ui_is_renderer_only"] = true
			out.append(row)
	return out


func export_state() -> Dictionary:
	_ensure_state()
	return state.duplicate(true)


func import_state(data: Dictionary) -> Dictionary:
	state = data.duplicate(true)
	_ensure_state()
	_publish_state()
	bootstrap_default_contracts()
	return { "success": true, "schema": ENGINE_SCHEMA, "version": ENGINE_VERSION}


func _ensure_mod_flash_providers(actor: Person, context: Dictionary) -> void:
	if gs == null or gs.mod_contract_engine == null:
		return
	var mappings: Dictionary = {
		"flash_realities": "flash_reality_provider",
		"flash_activities": "flash_activity_provider",
		"flash_minigames": "flash_minigame_provider",
		"flash_npcs": "flash_npc_provider",
		"flash_items": "flash_item_provider",
		"flash_sounds": "flash_sound_provider",
		"flash_achievements": "flash_achievement_provider",
		"flash_animations": "flash_animation_provider"
	}
	for provider_type in mappings.keys():
		var rows: Array = gs.mod_contract_engine.emit_provider_rows(
			str(provider_type), actor, context
		)
		for raw_row in rows:
			var row: Dictionary = _dict(raw_row)
			var provider_id: String = _id(
				str(row.get("flash_provider_id", row.get("provider_id", "")))
			)
			if provider_id == "":
				continue
			var provider: Dictionary = _dict(
				provider_registry.get(
					provider_id,
					{
						"provider_id": provider_id,
						"title": str(row.get("title", provider_id.capitalize()))
					}
				)
			)
			provider [str(mappings.get(provider_type, ""))] = row.duplicate(true)
			provider_registry [provider_id] = provider


func _ensure_state() -> void:
	if state.is_empty() and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		state = _dict(gs.scenario_state.get(STATE_KEY, {})).duplicate(true)
	if state.is_empty():
		state = {
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"installed_providers": {},
			"updated_at_ms": int(Time.get_ticks_msec())
		}
	if typeof(state.get("installed_providers", {})) != TYPE_DICTIONARY:
		state ["installed_providers"] = {}


func _publish_state() -> void:
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = state.duplicate(true)


func _serializable_dictionary(value: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for raw_key in value.keys():
		var raw_value: Variant = value.get(raw_key)
		if raw_value is Object or typeof(raw_value) == TYPE_CALLABLE:
			continue
		out [str(raw_key)] = raw_value
	return out


func _failure(reason: String, text: String) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"text": text,
		"ui_is_renderer_only": true
	}


func _id(value: String) -> String:
	return str(value).strip_edges().to_lower()


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []