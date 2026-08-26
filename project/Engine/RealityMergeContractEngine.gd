extends Resource
class_name RealityMergeContractEngine

const MERGE_REPORT_SCHEMA:= "eralife.reality.merge_report"
const CONTRACT_VERSION:= 1

var gs
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func resolve_truth_authority(checkpoint_candidates: Dictionary = {}, identity_context: Dictionary = {}, session_context: Dictionary = {}) -> Dictionary:
	var candidates: Array = checkpoint_candidates.get("candidates", []) if typeof(checkpoint_candidates.get("candidates", [])) == TYPE_ARRAY else []
	var local_valid: Array = []
	var cloud_valid: Array = []

	for raw_candidate in candidates:
		if typeof(raw_candidate) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = raw_candidate
		if not bool(candidate.get("success", false)):
			continue
		if str(candidate.get("authority", "")).to_lower() == "cloud":
			cloud_valid.append(candidate.duplicate(true))
		else:
			local_valid.append(candidate.duplicate(true))

	local_valid.sort_custom(Callable(self, "_sort_candidates_newest_first"))
	cloud_valid.sort_custom(Callable(self, "_sort_candidates_newest_first"))

	var resolved: Dictionary = {}
	var resolution_mode: String = "missing_checkpoint"

	if not local_valid.is_empty():
		resolved = local_valid [0].duplicate(true)
		resolution_mode = "valid_local_checkpoint"
	elif not cloud_valid.is_empty():
		resolved = cloud_valid [0].duplicate(true)
		resolution_mode = "valid_cloud_checkpoint"
	else:
		resolved = {}

	last_report = {
		"schema": MERGE_REPORT_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": not resolved.is_empty(),
		"mode": resolution_mode,
		"resolved_checkpoint": resolved.duplicate(true),
		"identity_context": identity_context.duplicate(true),
		"session_context": session_context.duplicate(true),
		"local_candidate_count": local_valid.size(),
		"cloud_candidate_count": cloud_valid.size(),
		"merge_strategy": "event_stream_preferred_field_timestamp_fallback",
		"overwrite_policy": "never_naive_overwrite",
		"created_at_ms": int(Time.get_ticks_msec()),
		"contract_mesh": {
			"source_of_truth": "RealityMergeContractEngine",
			"ui_mutation_allowed": false,
		}
	}
	_commit_state()
	return last_report.duplicate(true)

func _sort_candidates_newest_first(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("updated_at_ms", 0)) > int(b.get("updated_at_ms", 0))

func _commit_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["last_reality_merge_report"] = last_report.duplicate(true)