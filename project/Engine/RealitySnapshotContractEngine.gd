

extends Resource
class_name RealitySnapshotContractEngine

const ENGINE_SCHEMA:= (
	"eralife.reality_snapshot_contract_engine"
)
const SNAPSHOT_SCHEMA:= (
	"eralife.reality_resident_snapshot_contract"
)
const ENGINE_VERSION:= 1
const MAX_LEDGER:= 96

var gs = null
var snapshots_by_signature: Dictionary = {}
var integrity_ledger: Array = []
var last_report: Dictionary = {}


func _init(
	_gs = null
) -> void:
	gs = _gs


func bind_game_state(
	_gs
) -> void:
	gs = _gs


func bootstrap_default_contracts() -> Dictionary:
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"required_graphs": [
			"contract_graph",
			"projection_graph",
			"lens_graph",
			"node_graph",
			"surface_graph"
		],
		"ui_is_renderer_only": true
	}


func capture_resident_snapshot(
	signature: String,
	runtime,
	projection: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()

	if clean_signature == "":
		return _failure(
			"missing_signature",
			context
		)

	if (
		runtime == null
		or runtime.player == null
	):
		return _failure(
			"missing_playable_runtime",
			context
		)

	var scenario: Dictionary = _dict(
		runtime.scenario_state
	)
	var snapshot: Dictionary = {
		"success": true,
		"schema": SNAPSHOT_SCHEMA,
		"version": ENGINE_VERSION,
		"snapshot_id": (
			"resident_snapshot:%s:%d"
			% [
				clean_signature,
				int(
					Time.get_ticks_msec()
				)
			]
		),
		"signature": clean_signature,
		"actor_id": int(
			runtime.player.id
		),
		"player_id": int(
			runtime.player_id
		),
		"year": int(
			runtime.year
		),
		"world_seed": int(
			scenario.get(
				"world_seed",
				-1
			)
		),
		"seed_contract": _dict(
			scenario.get(
				"seed_contract",
				{}
			)
		),
		"settings": _dict(
			runtime.custom_settings
		),
		"contract_graph": _dict(
			projection.get(
				"contract_graph",
				{}
			)
		),
		"projection_graph": _dict(
			projection.get(
				"projection_graph",
				{}
			)
		),
		"lens_graph": _dict(
			projection.get(
				"lens_graph",
				{}
			)
		),
		"node_graph": _dict(
			projection.get(
				"node_graph",
				{}
			)
		),
		"surface_graph": _dict(
			projection.get(
				"surface_graph",
				{}
			)
		),
		"runtime_boot_snapshot": (
			_runtime_boot_snapshot(
				runtime
			)
		),
		"hydrated": true,
		"observable": true,
		"verified": false,
		"legal": false,
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"context": context.duplicate(true),
		"ui_is_renderer_only": true
	}

	var integrity: Dictionary = validate_snapshot(
		snapshot,
		{
			"source": (
				"capture_resident_snapshot"
			)
		}
	)

	snapshot ["integrity_report"] = (
		integrity.duplicate(true)
	)
	snapshot ["verified"] = bool(
		integrity.get(
			"valid",
			false
		)
	)
	snapshot ["legal"] = bool(
		integrity.get(
			"valid",
			false
		)
	)
	snapshot ["success"] = bool(
		integrity.get(
			"valid",
			false
		)
	)

	snapshots_by_signature [clean_signature] = (
		snapshot.duplicate(true)
	)

	last_report = {
		"success": bool(
			snapshot.get(
				"success",
				false
			)
		),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "resident_snapshot_captured",
		"signature": clean_signature,
		"snapshot": snapshot.duplicate(true),
		"integrity_report": integrity.duplicate(true),
		"ui_is_renderer_only": true
	}

	_commit_state()

	return last_report.duplicate(true)


func validate_snapshot(
	snapshot: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var missing: Array = []

	if str(
		snapshot.get(
			"signature",
			""
		)
	).strip_edges() == "":
		missing.append("signature")

	if int(
		snapshot.get(
			"actor_id",
			-1
		)
	) <= 0:
		missing.append("actor_id")

	if not bool(
		snapshot.get(
			"hydrated",
			false
		)
	):
		missing.append(
			"hydrated_runtime"
		)

	for graph_id in [
		"contract_graph",
		"projection_graph",
		"lens_graph",
		"node_graph",
		"surface_graph"
	]:
		if _dict(
			snapshot.get(
				graph_id,
				{}
			)
		).is_empty():
			missing.append(graph_id)

	if not bool(
		_dict(
			snapshot.get(
				"contract_graph",
				{}
			)
		).get(
			"required_engines_hot",
			false
		)
	):
		missing.append(
			"required_engines_hot"
		)

	if not bool(
		_dict(
			snapshot.get(
				"surface_graph",
				{}
			)
		).get(
			"surface_graph_hot",
			false
		)
	):
		missing.append(
			"surface_graph_hot"
		)

	var valid: bool = missing.is_empty()
	var report: Dictionary = {
		"success": valid,
		"valid": valid,
		"schema": (
			"eralife.reality_resident_snapshot_integrity"
		),
		"version": ENGINE_VERSION,
		"signature": str(
			snapshot.get(
				"signature",
				""
			)
		),
		"missing": missing,
		"attach_without_rebuild_allowed": valid,
		"context": context.duplicate(true),
		"validated_at_ms": int(
			Time.get_ticks_msec()
		),
		"ui_is_renderer_only": true
	}

	integrity_ledger.append(
		report.duplicate(true)
	)

	while integrity_ledger.size() > MAX_LEDGER:
		integrity_ledger.pop_front()

	return report


func snapshot_for_signature(
	signature: String
) -> Dictionary:
	return _dict(
		snapshots_by_signature.get(
			str(
				signature
			).strip_edges(),
			{}
		)
	)


func has_valid_snapshot(
	signature: String
) -> bool:
	var snapshot: Dictionary = (
		snapshot_for_signature(
			signature
		)
	)

	return (
		not snapshot.is_empty()
		and bool(
			snapshot.get(
				"verified",
				false
			)
		)
		and bool(
			snapshot.get(
				"legal",
				false
			)
		)
	)

func bind_checkpoint_to_snapshot(
	signature: String,
	checkpoint: Dictionary = {}
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()

	if clean_signature == "":
		return _failure(
			"missing_signature",
			{
				"checkpoint": checkpoint.duplicate(true)
			}
		)

	var snapshot: Dictionary = snapshot_for_signature(
		clean_signature
	)

	if snapshot.is_empty():
		return _failure(
			"snapshot_not_found",
			{
				"signature": clean_signature,
				"checkpoint": checkpoint.duplicate(true)
			}
		)

	var path: String = str(
		checkpoint.get(
			"checkpoint_path",
			checkpoint.get(
				"path",
				""
			)
		)
	).strip_edges()
	var candidate: Dictionary = checkpoint.duplicate(true)

	candidate ["schema"] = "eralife.reality.checkpoint_candidate"
	candidate ["version"] = ENGINE_VERSION
	candidate ["success"] = (
		path != ""
		and FileAccess.file_exists(path)
	)
	candidate ["authority"] = str(
		candidate.get(
			"authority",
			"local"
		)
	)
	candidate ["source"] = str(
		candidate.get(
			"source",
			"reality_snapshot_checkpoint_binding"
		)
	)
	candidate ["checkpoint_path"] = path
	candidate ["path"] = path
	candidate ["residency_signature"] = clean_signature
	candidate ["updated_at_ms"] = int(
		candidate.get(
			"updated_at_ms",
			Time.get_ticks_msec()
		)
	)

	snapshot ["checkpoint_candidate"] = candidate.duplicate(true)
	snapshot ["restart_hydration_ready"] = bool(
		candidate.get(
			"success",
			false
		)
	)
	snapshot ["checkpoint_bound_at_ms"] = int(
		Time.get_ticks_msec()
	)
	snapshots_by_signature [clean_signature] = snapshot

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": "checkpoint_bound_to_resident_snapshot",
		"signature": clean_signature,
		"checkpoint_candidate": candidate.duplicate(true),
		"restart_hydration_ready": bool(
			candidate.get(
				"success",
				false
			)
		),
		"ui_is_renderer_only": true
	}

	_commit_state()

	return last_report.duplicate(true)
func remove_snapshot(
	signature: String,
	reason: String = "explicit_remove"
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var removed: bool = snapshots_by_signature.erase(
		clean_signature
	)

	_commit_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"signature": clean_signature,
		"removed": removed,
		"reason": reason
	}


func export_state() -> Dictionary:
	return {
		"schema": (
			"eralife.reality_snapshot_contract_engine.state"
		),
		"version": ENGINE_VERSION,
		"snapshots_by_signature": (
			snapshots_by_signature.duplicate(true)
		),
		"integrity_ledger": (
			integrity_ledger.duplicate(true)
		),
		"last_report": last_report.duplicate(true)
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	snapshots_by_signature = _dict(
		data.get(
			"snapshots_by_signature",
			{}
		)
	)
	integrity_ledger = _array(
		data.get(
			"integrity_ledger",
			[]
		)
	)
	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)

	_commit_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"snapshot_count": (
			snapshots_by_signature.size()
		)
	}


func _runtime_boot_snapshot(
	runtime
) -> Dictionary:
	if (
		runtime != null
		and runtime.has_method(
			"resident_runtime_bootstrap_snapshot"
		)
	):
		return _dict(
			runtime.resident_runtime_bootstrap_snapshot()
		)

	return {}


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"reality_snapshot_contract_engine_state"
	] = export_state()


func _dict(
	value: Variant
) -> Dictionary:
	return (
		(value as Dictionary).duplicate(true)
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)


func _array(
	value: Variant
) -> Array:
	return (
		(value as Array).duplicate(true)
		if typeof(value) == TYPE_ARRAY
		else []
	)


func _failure(
	reason: String,
	context: Dictionary
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	last_report = {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"context": context.duplicate(true),
		"ui_is_renderer_only": true
	}

	_commit_state()

	return last_report.duplicate(true)