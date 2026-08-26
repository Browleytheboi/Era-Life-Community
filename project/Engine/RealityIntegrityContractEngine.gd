extends Resource
class_name RealityIntegrityContractEngine

const INTEGRITY_REPORT_SCHEMA:= "eralife.reality.integrity_report"
const CONTRACT_VERSION:= 1

var gs
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func validate_snapshot(checkpoint: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var path: String = str(checkpoint.get("checkpoint_path", checkpoint.get("path", ""))).strip_edges()
	var exists: bool = path != "" and FileAccess.file_exists(path)

	last_report = {
		"schema": INTEGRITY_REPORT_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": exists,
		"valid": exists,
		"mode": "fast_local_checkpoint_validation",
		"checkpoint": checkpoint.duplicate(true),
		"path": path,
		"repair_required": not exists,
		"reason": "" if exists else "checkpoint_file_missing",
		"context": context.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "RealityIntegrityContractEngine",
			"ui_mutation_allowed": false
		}
	}
	_commit_state()
	return last_report.duplicate(true)

func repair_if_needed(integrity_report: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	if bool(integrity_report.get("valid", false)):
		return integrity_report.duplicate(true)
	var repaired: Dictionary = integrity_report.duplicate(true)
	repaired ["success"] = false
	repaired ["valid"] = false
	repaired ["mode"] = "repair_deferred_to_cinematic_fallback"
	repaired ["fallback"] = "cinematic_path"
	repaired ["context"] = context.duplicate(true)
	last_report = repaired.duplicate(true)
	_commit_state()
	return repaired

func _commit_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["last_reality_integrity_report"] = last_report.duplicate(true)