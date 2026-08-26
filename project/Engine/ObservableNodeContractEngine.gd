extends Resource
class_name ObservableNodeContractEngine

const ENGINE_SCHEMA:= "eralife.observable_node_contract_engine"
const SURFACE_SCHEMA:= "eralife.observable_surface_contract"
const CONTRACT_VERSION:= 1

var gs = null
var surfaces_by_scope: Dictionary = {}
var last_report: Dictionary = {}


func _init(_gs = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs) -> void:
	gs = _gs
	_commit_registry()


func ensure_surface_scope(scope_id: String, surface_contract: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var clean_scope: String = str(scope_id).strip_edges()
	if clean_scope == "":
		return {
			"success": false,
			"reason": "empty_scope_id",
			"schema": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	var packet: Dictionary = surface_contract.duplicate(true)
	packet ["schema"] = SURFACE_SCHEMA
	packet ["version"] = CONTRACT_VERSION
	packet ["scope_id"] = clean_scope
	packet ["exists"] = true
	packet ["surface_exists"] = true
	packet ["hydration_optional"] = true
	packet ["hydrated"] = bool(packet.get("hydrated", false))
	packet ["context"] = context.duplicate(true)
	packet ["updated_at_ms"] = int(Time.get_ticks_msec())
	packet ["ui_is_renderer_only"] = true
	packet ["engine_creates_no_controls"] = true

	surfaces_by_scope [clean_scope] = packet

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"scope_id": clean_scope,
		"surface_exists": true,
		"hydration_optional": true,
		"ui_is_renderer_only": true,
		"at_ms": int(Time.get_ticks_msec())
	}

	_commit_registry()
	return last_report.duplicate(true)


func has_surface_scope(scope_id: String) -> bool:
	var clean_scope: String = str(scope_id).strip_edges()
	if clean_scope == "":
		return false
	return surfaces_by_scope.has(clean_scope)


func surface_for_scope(scope_id: String) -> Dictionary:
	var clean_scope: String = str(scope_id).strip_edges()
	if clean_scope == "":
		return {}

	var raw: Variant = surfaces_by_scope.get(clean_scope, {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}

	return (raw as Dictionary).duplicate(true)


func export_registry() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"surface_count": surfaces_by_scope.size(),
		"surfaces_by_scope": surfaces_by_scope.duplicate(true),
		"last_report": last_report.duplicate(true),
		"ui_is_renderer_only": true
	}


func _commit_registry() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["observable_node_contract_engine_registry"] = export_registry()
	gs.scenario_state ["observable_node_contract_engine_surface_count"] = surfaces_by_scope.size()