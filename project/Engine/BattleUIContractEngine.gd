extends Resource
class_name BattleUIContractEngine

const ENGINE_SCHEMA:= "eralife.battle_ui_contract_engine"
const CONTRACT_VERSION:= 1

var gs
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs


func route_command_envelope(envelope: Dictionary) -> Dictionary:
	var command_id: String = str(envelope.get("command", envelope.get("action_id", ""))).strip_edges().to_lower()

	if command_id == "battle_ui.emit_surface":
		return emit_battle_ui_surface(str(envelope.get("battle_id", "")), envelope)

	return _fail("unknown_battle_ui_command", "BattleUIContractEngine did not recognize command.", envelope)


func emit_battle_ui_surface(battle_id: String, context: Dictionary = {}) -> Dictionary:
	var snapshot_report: Dictionary = _snapshot_report(battle_id, context)
	if not bool(snapshot_report.get("success", false)):
		return snapshot_report

	var snapshot: Dictionary = snapshot_report.get("snapshot", {}) if typeof(snapshot_report.get("snapshot", {})) == TYPE_DICTIONARY else {}
	var units: Array = snapshot.get("units", []) if typeof(snapshot.get("units", [])) == TYPE_ARRAY else []
	var engagement_edges: Array = snapshot.get("engagement_edges", []) if typeof(snapshot.get("engagement_edges", [])) == TYPE_ARRAY else []
	var pressure_edges: Array = snapshot.get("pressure_edges", []) if typeof(snapshot.get("pressure_edges", [])) == TYPE_ARRAY else []

	last_report = {
		"schema": "eralife.battle_ui.surface_contract",
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": "battle_ui_surface_ready",
		"battle_id": battle_id,
		"terrain": str(snapshot.get("terrain", "plains")),
		"weather": str(snapshot.get("weather", "clear")),
		"tick_index": int(snapshot.get("tick_index", 0)),
		"unit_nodes": _unit_nodes_from_snapshot(units),
		"engagement_edges": _ui_edges(engagement_edges),
		"pressure_edges": _ui_edges(pressure_edges),
		"legend": {
			"red": "enemy engagement",
			"yellow": "commander influence",
			"purple": "nearby allied pressure",
			"green": "supply/support"
		},
		"visual_rules": {
		},
		"contract_mesh": {
			"source_of_truth": "BattleUIContractEngine",
			"simulation_authority": "BattleSimContractEngine",
			"ui_is_lens": true
		},
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	return last_report.duplicate(true)


func _snapshot_report(battle_id: String, context: Dictionary = {}) -> Dictionary:
	if gs != null and "battle_sim_contract_engine" in gs:
		if gs.battle_sim_contract_engine == null:
			gs.battle_sim_contract_engine = BattleSimContractEngine.new(gs)
		if gs.battle_sim_contract_engine != null and gs.battle_sim_contract_engine.has_method("emit_battle_snapshot"):
			return gs.battle_sim_contract_engine.emit_battle_snapshot(battle_id, {
				"source": "BattleUIContractEngine.emit_battle_ui_surface",
				"context": context.duplicate(true)
			})

	return _fail("battle_sim_unavailable", "BattleSimContractEngine unavailable.", context)


func _unit_nodes_from_snapshot(units: Array) -> Array:
	var out: Array = []

	for raw_unit in units:
		if typeof(raw_unit) != TYPE_DICTIONARY:
			continue

		var unit: Dictionary = raw_unit as Dictionary
		var morale: float = clamp(float(unit.get("morale", 0.7)), 0.0, 1.0)
		var fear: float = clamp(float(unit.get("fear", 0.18)), 0.0, 1.0)
		var position: Dictionary = unit.get("position", {}) if typeof(unit.get("position", {})) == TYPE_DICTIONARY else {}

		out.append({
			"unit_id": str(unit.get("unit_id", "")),
			"army_id": str(unit.get("army_id", "")),
			"display_name": str(unit.get("display_name", unit.get("unit_type", "Unit"))),
			"unit_type": str(unit.get("unit_type", "infantry")),
			"count": int(unit.get("count", 0)),
			"state": str(unit.get("state", "holding")),
			"position": {
				"x": float(position.get("x", 0.0)),
				"y": float(position.get("y", 0.0))
			},
			"morale": morale,
			"fear": fear,
			"glow_alpha": 0.18 + morale * 0.44,
			"shake_alpha": fear * 0.32,
			"movement_explanation": unit.get("movement_explanation", {}) if typeof(unit.get("movement_explanation", {})) == TYPE_DICTIONARY else {}
		})

	return out


func _ui_edges(edges: Array) -> Array:
	var out: Array = []

	for raw_edge in edges:
		if typeof(raw_edge) != TYPE_DICTIONARY:
			continue

		var edge: Dictionary = raw_edge as Dictionary
		out.append({
			"from": str(edge.get("from", "")),
			"to": str(edge.get("to", "")),
			"type": str(edge.get("type", "")),
			"intensity": clamp(float(edge.get("intensity", 0.0)), 0.0, 1.0),
			"pulse": bool(edge.get("pulse", true)),
			"thickness": 1.0 + clamp(float(edge.get("intensity", 0.0)), 0.0, 1.0) * 5.0,
			"color": edge.get("color", {}) if typeof(edge.get("color", {})) == TYPE_DICTIONARY else {}
		})

	return out


func _fail(reason_id: String, message: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": "eralife.battle_ui.error",
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	return last_report.duplicate(true)