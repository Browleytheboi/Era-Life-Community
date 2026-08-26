

extends Resource
class_name RealityResidencyContractEngine

const ENGINE_SCHEMA:= (
	"eralife.reality_residency_contract_engine"
)
const CONTRACT_SCHEMA:= (
	"eralife.reality_residency_contract"
)
const ENGINE_VERSION:= 1
const MAX_LEDGER:= 128

var gs = null
var manager: RealityResidencyManager = null
var snapshot_engine: RealitySnapshotContractEngine = null
var projection_engine: RealityProjectionContractEngine = null
var lens_state_by_signature: Dictionary = {}
var ledger: Array = []
var last_report: Dictionary = {}


func _init(
	_gs = null,
	_manager: RealityResidencyManager = null,
	_snapshot_engine: RealitySnapshotContractEngine = null,
	_projection_engine: RealityProjectionContractEngine = null
) -> void:
	gs = _gs
	manager = _manager
	snapshot_engine = _snapshot_engine
	projection_engine = _projection_engine


func bind_authorities(
	_gs,
	_manager: RealityResidencyManager,
	_snapshot_engine: RealitySnapshotContractEngine,
	_projection_engine: RealityProjectionContractEngine
) -> void:
	gs = _gs
	manager = _manager
	snapshot_engine = _snapshot_engine
	projection_engine = _projection_engine


func bootstrap_default_contracts() -> Dictionary:
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"law": {
		},
		"ui_is_renderer_only": true
	}


func resolve_intent(
		envelope: Dictionary,
		context: Dictionary = {}
) -> Dictionary:
	if manager == null:
		return _failure(
			"missing_reality_residency_manager",
			context
		)

	var payload: Dictionary = _payload_from_envelope(
		envelope
	)
	var action_id: String = str(
		envelope.get(
			"action_id",
			payload.get(
				"action_id",
				"status"
			)
		)
	).strip_edges().to_lower()
	var signature: String = str(
		payload.get(
			"signature",
			""
		)
	).strip_edges()
	var report: Dictionary = {}

	match action_id:
		"prime_pool":
			report = manager.prime_chassis_pool(
				payload
			)

		"reserve", "reserve_reality":
			report = manager.reserve_reality(
				_dict(
					payload.get(
						"settings",
						{}
					)
				),
				{
					"signature": signature,
					"source": str(
						payload.get(
							"source",
							(
								"reality_residency_contract_engine"
							)
						)
					),
					"prewarm_contract": _dict(
						payload.get(
							"prewarm_contract",
							{}
						)
					),
					"candidate_slot": str(
						payload.get(
							"candidate_slot",
							""
						)
					),
					"replace_uncommitted_slot": bool(
						payload.get(
							"replace_uncommitted_slot",
							false
						)
					),
					"commit_residency": bool(
						payload.get(
							"commit_residency",
							false
						)
					)
				}
			)

		"reserve_checkpoint", "reserve_checkpoint_reality":
			report = manager.reserve_checkpoint_reality(
				signature,
				{
					"checkpoint_path": str(
						payload.get(
							"checkpoint_path",
							payload.get(
								"path",
								""
							)
						)
					),
					"path": str(
						payload.get(
							"path",
							payload.get(
								"checkpoint_path",
								""
							)
						)
					),
					"authority": str(
						payload.get(
							"authority",
							"local"
						)
					),
					"source": str(
						payload.get(
							"source",
							(
								"reality_residency_contract_engine"
							)
						)
					),
					"load_options": _dict(
						payload.get(
							"load_options",
							{}
						)
					)
				}
			)

		"service", "service_residency":
			report = manager.service_residency({
				"signature": signature,
				"max_steps": int(
					payload.get(
						"max_steps",
						1
					)
				),
				"frame_budget_ms": int(
					payload.get(
						"frame_budget_ms",
						2
					)
				),
				"source": str(
					payload.get(
						"source",
						(
							"reality_residency_contract_engine"
						)
					)
				)
			})

		"attach", "attach_runtime":
			report = manager.attach_reality(
				signature,
				payload
			)

			if bool(
				report.get(
					"success",
					false
				)
			):
				lens_state_by_signature [
					signature
				] = {
					"attached": true,
					"attached_at_ms": int(
						Time.get_ticks_msec()
					),
					"source": str(
						payload.get(
							"source",
							"attach_runtime"
						)
					)
				}

		"detach", "detach_lens":
			report = manager.detach_lens(
				signature,
				payload
			)
			lens_state_by_signature [
				signature
			] = {
				"attached": false,
				"detached_at_ms": int(
					Time.get_ticks_msec()
				),
				"source": str(
					payload.get(
						"source",
						"detach_lens"
					)
				)
			}

		"status", "observe":
			report = manager.status_contract(
				signature,
				payload
			)

		"catalog":
			report = {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"version": ENGINE_VERSION,
				"mode": "resident_catalog",
				"catalog": (
					manager.resident_catalog()
				),
				"ui_is_renderer_only": true
			}

		_:
			return _failure(
				"unknown_residency_action",
				{
					"action_id": action_id,
					"payload": payload
				}
			)

	var contract_report: Dictionary = (
		_contract_from_report(
			report,
			signature,
			action_id
		)
	)
	var serializable_report: Dictionary = (
		_serializable_report(
			contract_report
		)
	)




	if action_id not in [
		"status",
		"observe",
		"service",
		"service_residency"
	]:
		_record(
			serializable_report
		)

	last_report = serializable_report


	return contract_report


func emit_residency_contract(
	signature: String,
	context: Dictionary = {}
) -> Dictionary:
	if manager == null:
		return _failure(
			"missing_reality_residency_manager",
			context
		)

	return _contract_from_report(
		manager.status_contract(
			signature,
			context
		),
		signature,
		"observe"
	)


func _contract_from_report(
		report: Dictionary,
		signature: String,
		action_id: String
) -> Dictionary:
	var ready: bool = bool(
		report.get(
			"ready",
			false
		)
	)
	var residency_contract: Dictionary = {
		"schema": CONTRACT_SCHEMA,
		"version": ENGINE_VERSION,
		"signature": signature,
		"action_id": action_id,
		"state": str(
			report.get(
				"state",
				report.get(
					"mode",
					"unknown"
				)
			)
		),
		"ready": ready,
		"resident": bool(
			report.get(
				"resident",
				ready
			)
		),
		"progress": float(
			report.get(
				"progress",
				1.0 if ready else 0.0
			)
		),
		"stage_id": str(
			report.get(
				"stage_id",
				"resident_runtime"
			)
		),
		"attach_without_rebuild": ready,
		"worker_thread_used": false,
		"ui_is_renderer_only": true,
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}



	var out: Dictionary = report.duplicate(false)

	out ["residency_contract"] = (
		residency_contract
	)
	out [
		"residency_contract_report_deep_copy_performed"
	] = false

	return out

func _payload_from_envelope(
	envelope: Dictionary
) -> Dictionary:
	var payload: Dictionary = _dict(
		envelope.get(
			"payload",
			{}
		)
	)

	if payload.is_empty():
		payload = envelope.duplicate(true)

	return payload


func export_state() -> Dictionary:
	return {
		"schema": (
			"eralife.reality_residency_contract_engine.state"
		),
		"version": ENGINE_VERSION,
		"state": {
			"lens_state_by_signature": (
				lens_state_by_signature.duplicate(true)
			),
			"ledger": ledger.duplicate(true),
			"last_report": (
				_serializable_report(
					last_report
				)
			)
		},
		"ui_is_renderer_only": true
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	var imported: Dictionary = _dict(
		data.get(
			"state",
			data
		)
	)

	lens_state_by_signature = _dict(
		imported.get(
			"lens_state_by_signature",
			{}
		)
	)
	ledger = _array(
		imported.get(
			"ledger",
			[]
		)
	)
	last_report = _dict(
		imported.get(
			"last_report",
			{}
		)
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"mode": (
			"residency_contract_state_imported"
		),
		"ui_is_renderer_only": true
	}


func _serializable_report(
		report: Dictionary
) -> Dictionary:

	var out: Dictionary = report.duplicate(false)

	out.erase(
		"game_state"
	)
	out.erase(
		"runtime_ref"
	)

	for nested_key in [
		"route_report",
		"result"
	]:
		var nested_raw: Variant = out.get(
			nested_key,
			{}
		)

		if typeof(
			nested_raw
		) != TYPE_DICTIONARY:
			continue

		var nested: Dictionary = (
			(nested_raw as Dictionary).duplicate(false)
		)

		nested.erase(
			"game_state"
		)
		nested.erase(
			"runtime_ref"
		)
		out [nested_key] = nested

	out [
		"live_runtime_reference_serialized"
	] = false

	return out.duplicate(true)


func _record(
	report: Dictionary
) -> void:
	ledger.append(
		_serializable_report(
			report
		)
	)

	while ledger.size() > MAX_LEDGER:
		ledger.pop_front()


func _failure(
	reason: String,
	context: Dictionary = {}
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	var report: Dictionary = {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"context": context.duplicate(true),
		"ui_is_renderer_only": true
	}

	_record(report)

	return report


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