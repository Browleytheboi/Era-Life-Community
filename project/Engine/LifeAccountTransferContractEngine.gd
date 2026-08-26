extends Resource
class_name LifeAccountTransferContractEngine

const ENGINE_SCHEMA:= (
	"eralife.life_account_transfer_contract_engine"
)
const CONTRACT_VERSION:= 1
const TRANSFER_REGISTRY_PATH:= (
	"user://identity/life_account_transfer_registry.json"
)

var gs
var transfer_registry: Dictionary = {}
var last_report: Dictionary = {}


func _init(_gs = null) -> void:
	gs = _gs
	_ensure_state()


func emit_transfer_context(
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = (
		_identity_context()
	)
	var current_identity_id: String = (
		_identity_id(identity_context)
	)
	var is_guest: bool = bool(
		identity_context.get(
			"is_guest",
			true
		)
	)
	var ownership_by_path: Dictionary = (
		_safe_dictionary(
			transfer_registry.get(
				"ownership_by_path",
				{}
			)
		)
	)
	var local_lives: Array = (
		_local_life_summaries()
	)
	var unclaimed_lives: Array = []
	var current_account_lives: Array = []
	var other_account_lives: Array = []

	for raw_summary in local_lives:
		if typeof(raw_summary) != TYPE_DICTIONARY:
			continue

		var summary: Dictionary = (
			raw_summary as Dictionary
		).duplicate(true)
		var path: String = str(
			summary.get(
				"path",
				""
			)
		).strip_edges()
		var ownership: Dictionary = (
			_safe_dictionary(
				ownership_by_path.get(
					path,
					{}
				)
			)
		)
		var owner_identity_id: String = str(
			ownership.get(
				"owner_identity_id",
				""
			)
		).strip_edges()

		summary ["account_attachment"] = (
			ownership.duplicate(true)
		)
		summary ["is_unclaimed"] = (
			owner_identity_id == ""
		)
		summary [
			"is_owned_by_current_account"
		] = (
			current_identity_id != ""
			and owner_identity_id == current_identity_id
		)
		summary [
			"is_owned_by_other_account"
		] = (
			owner_identity_id != ""
			and owner_identity_id != current_identity_id
		)

		if owner_identity_id == "":
			unclaimed_lives.append(summary)
		elif owner_identity_id == current_identity_id:
			current_account_lives.append(summary)
		else:
			other_account_lives.append(summary)

	var report: Dictionary = {
		"schema": (
			"eralife.life_account_transfer.context"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": (
			"guest_local_lives_ready"
			if is_guest
			else "account_transfer_ready"
		),
		"is_guest": is_guest,
		"identity_context": (
			identity_context.duplicate(true)
		),
		"local_lives": local_lives,
		"unclaimed_lives": unclaimed_lives,
		"current_account_lives": (
			current_account_lives
		),
		"other_account_lives": (
			other_account_lives
		),
		"unclaimed_count": (
			unclaimed_lives.size()
		),
		"current_account_life_count": (
			current_account_lives.size()
		),
		"transfer_available": (
			not is_guest
			and not unclaimed_lives.is_empty()
		),
		"context": context.duplicate(true),
		"created_at_ms": _now_ms(),
		"contract_mesh": {
			"source_of_truth": (
				"LifeAccountTransferContractEngine"
			),
			"saved_life_authority": "GameState",
			"account_identity_authority": (
				"IdentityContractEngine"
			),
			"transfer_attaches_ownership_metadata_only": (
				true
			),
			"ui_mutation_allowed": false
		}
	}

	last_report = report.duplicate(true)
	_commit_state()
	return report
func emit_title_card_continue_contract(
	context: Dictionary = {}
) -> Dictionary:
	var transfer_context: Dictionary = (
		emit_transfer_context({
			"source": str(
				context.get(
					"source",
					(
						"life_account_transfer."
						+ "title_card_continue"
					)
				)
			),
		})
	)
	var identity_context: Dictionary = (
		_safe_dictionary(
			transfer_context.get(
				"identity_context",
				{}
			)
		)
	)
	var is_guest: bool = bool(
		identity_context.get(
			"is_guest",
			true
		)
	)
	var eligible_lives: Array = []

	if is_guest:
		eligible_lives = _safe_array(
			transfer_context.get(
				"unclaimed_lives",
				[]
			)
		)
	else:
		eligible_lives = _safe_array(
			transfer_context.get(
				"current_account_lives",
				[]
			)
		)

	var candidate: Dictionary = (
		_title_card_continue_candidate_from_rows(
			eligible_lives
		)
	)
	var checkpoint_path: String = str(
		candidate.get(
			"path",
			candidate.get(
				"checkpoint_path",
				""
			)
		)
	).strip_edges()




	var session_context: Dictionary = {}
	var checkpoint_candidates_report: Dictionary = {}
	var checkpoint_candidate: Dictionary = {}

	if gs != null:
		if (
			gs.session_contract_engine != null
			and gs.session_contract_engine.has_method(
				"emit_session_context"
			)
		):
			session_context = (
				gs.session_contract_engine.emit_session_context({
					"source": (
						"life_account_transfer."
						+ "title_card_continue"
					),
					"identity_context": (
						identity_context.duplicate(false)
					)
				})
			)

		if (
			gs.reality_checkpoint_contract_engine != null
			and gs.reality_checkpoint_contract_engine.has_method(
				"emit_checkpoint_candidates"
			)
		):
			checkpoint_candidates_report = (
				gs.reality_checkpoint_contract_engine
				.emit_checkpoint_candidates(
					identity_context,
					session_context,
					{
						"source": (
							"life_account_transfer."
							+ "title_card_continue"
						),
						"selected_checkpoint_path": checkpoint_path
					}
				)
			)
			checkpoint_candidate = _safe_dictionary(
				checkpoint_candidates_report.get(
					"local_checkpoint",
					{}
				)
			)

	var checkpoint_candidate_path: String = str(
		checkpoint_candidate.get(
			"checkpoint_path",
			checkpoint_candidate.get(
				"path",
				""
			)
		)
	).strip_edges()
	var candidate_matches_checkpoint_pointer: bool = (
		checkpoint_path != ""
		and checkpoint_candidate_path == checkpoint_path
		and bool(
			checkpoint_candidate.get(
				"success",
				false
			)
		)
	)

	if candidate_matches_checkpoint_pointer:
		for key in [
			"residency_signature",
			"checkpoint_resume_contract",
			"current_panel",
			"actor_id",
			"controlled_actor_id",
			"life_id",
			"branch_id",
			"updated_at_ms",
			"timestamp"
		]:
			if checkpoint_candidate.has(key):
				candidate [key] = (
					checkpoint_candidate.get(
						key
					)
				)

		candidate ["checkpoint_candidate"] = (
			checkpoint_candidate.duplicate(false)
		)
		candidate [
			"checkpoint_pointer_authoritative"
		] = true
		candidate [
			"checkpoint_binary_decode_required_before_first_frame"
		] = false

	var resume_raw: Variant = candidate.get(
		"checkpoint_resume_contract",
		{}
	)
	var checkpoint_resume_contract: Dictionary = (
		(resume_raw as Dictionary).duplicate(false)
		if typeof(resume_raw) == TYPE_DICTIONARY
		else {}
	)
	var residency_signature: String = str(
		candidate.get(
			"residency_signature",
			checkpoint_resume_contract.get(
				"residency_signature",
				""
			)
		)
	).strip_edges()
	var controlled_actor_id: int = int(
		candidate.get(
			"controlled_actor_id",
			candidate.get(
				"actor_id",
				checkpoint_resume_contract.get(
					"controlled_actor_id",
					checkpoint_resume_contract.get(
						"actor_id",
						-1
					)
				)
			)
		)
	)
	var current_panel: String = str(
		candidate.get(
			"current_panel",
			checkpoint_resume_contract.get(
				"current_panel",
				"life"
			)
		)
	).strip_edges().to_lower()

	if current_panel == "":
		current_panel = "life"

	var available: bool = (
		not candidate.is_empty()
		and checkpoint_path != ""
		and FileAccess.file_exists(
			checkpoint_path
		)
	)
	var attachment: Dictionary = (
		_safe_dictionary(
			candidate.get(
				"account_attachment",
				{}
			)
		)
	)
	var ownership_scope: String = (
		"guest_device_unclaimed"
		if is_guest
		else "current_eraccount"
	)
	var report: Dictionary = {
		"schema": (
			"eralife.title_card.continue_contract"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"available": available,
		"mode": (
			"guest_local_continue_ready"
			if (
				is_guest
				and available
			)
			else (
				"eraccount_continue_ready"
				if available
				else (
					"guest_has_no_unclaimed_life"
					if is_guest
					else (
						"eraccount_has_no_attached_life"
					)
				)
			)
		),
		"input_key": "C",
		"input_keycode": KEY_C,
		"is_guest": is_guest,
		"ownership_scope": ownership_scope,
		"checkpoint_path": checkpoint_path,
		"residency_signature": residency_signature,
		"checkpoint_resume_contract": (
			checkpoint_resume_contract
		),
		"checkpoint_candidate": (
			checkpoint_candidate.duplicate(false)
		),
		"checkpoint_pointer_authoritative": (
			candidate_matches_checkpoint_pointer
		),
		"checkpoint_binary_decode_required_before_first_frame": (
			not candidate_matches_checkpoint_pointer
			or checkpoint_resume_contract.is_empty()
		),
		"controlled_actor_id": controlled_actor_id,
		"actor_id": controlled_actor_id,
		"current_panel": current_panel,
		"life_summary": (
			candidate.duplicate(true)
		),
		"player_name": str(
			candidate.get(
				"player_name",
				"Current Life"
			)
		),
		"player_age": int(
			candidate.get(
				"age",
				-1
			)
		),
		"era_name": str(
			candidate.get(
				"era_name",
				""
			)
		),
		"saved_at_unix": int(
			candidate.get(
				"saved_at_unix",
				0
			)
		),
		"life_id": str(
			attachment.get(
				"life_id",
				candidate.get(
					"life_id",
					""
				)
			)
		),
		"portable_life_packet_id": str(
			attachment.get(
				"portable_life_packet_id",
				""
			)
		),
		"branch_id": str(
			attachment.get(
				"branch_id",
				candidate.get(
					"branch_id",
					"main"
				)
			)
		),
		"unclaimed_local_life_count": int(
			transfer_context.get(
				"unclaimed_count",
				0
			)
		),
		"current_account_life_count": int(
			transfer_context.get(
				"current_account_life_count",
				0
			)
		),
		"legacy_attachment_available": bool(
			transfer_context.get(
				"transfer_available",
				false
			)
		),
		"checkpoint_hydration_allowed": available,
		"resident_reattach_preferred": (
			residency_signature != ""
		),
		"resume_capsule_available": (
			not checkpoint_resume_contract.is_empty()
		),
		"cloud_replication_state": str(
			attachment.get(
				"cloud_replication_state",
				"not_attached"
			)
		),
		"identity_context": (
			identity_context.duplicate(true)
		),
		"context": context.duplicate(true),
		"created_at_ms": _now_ms(),
		"contract_mesh": {
			"saved_life_authority": "GameState",
			"ownership_authority": (
				"LifeAccountTransferContractEngine"
			),
			"identity_authority": (
				"IdentityContractEngine"
			),
			"hydration_authority": (
				"RealityCheckpointContractEngine"
			),
			"resume_pointer_authority": (
				"SessionContractEngine"
			),
			"ui_is_renderer_only": true
		}
	}

	last_report = report.duplicate(true)
	_commit_state()

	return report
func _title_card_continue_candidate_from_rows(
	rows: Array
) -> Dictionary:
	var best_candidate: Dictionary = {}
	var best_saved_at_unix: int = -1

	for raw_row in rows:
		if typeof(
			raw_row
		) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			raw_row as Dictionary
		).duplicate(true)
		var path: String = str(
			row.get(
				"path",
				row.get(
					"checkpoint_path",
					""
				)
			)
		).strip_edges()

		if (
			path == ""
			or not FileAccess.file_exists(
				path
			)
		):
			continue

		var saved_at_unix: int = int(
			row.get(
				"saved_at_unix",
				FileAccess.get_modified_time(
					path
				)
			)
		)

		if saved_at_unix <= best_saved_at_unix:
			continue

		best_saved_at_unix = saved_at_unix
		best_candidate = row
		best_candidate ["path"] = path
		best_candidate [
			"checkpoint_path"
		] = path
		best_candidate [
			"saved_at_unix"
		] = saved_at_unix

	return best_candidate

func transfer_local_lives_to_current_account(
	life_paths: Array,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = (
		_identity_context()
	)

	if bool(
		identity_context.get(
			"is_guest",
			true
		)
	):
		return _fail(
			"account_required",
			(
				"Sign into an ErAccount before "
				+ "attaching local lives."
			),
			context
		)

	var identity_id: String = (
		_identity_id(
			identity_context
		)
	)
	var username: String = str(
		identity_context.get(
			"account_username",
			""
		)
	).strip_edges()

	if identity_id == "":
		return _fail(
			"identity_missing",
			(
				"The active ErAccount ID "
				+ "could not be resolved."
			),
			context
		)

	var requested_paths: Array = (
		life_paths.duplicate(true)
	)

	if requested_paths.is_empty():
		var transfer_context: Dictionary = (
			emit_transfer_context(
				context
			)
		)
		var unclaimed_lives: Array = (
			_safe_array(
				transfer_context.get(
					"unclaimed_lives",
					[]
				)
			)
		)

		for raw_summary in unclaimed_lives:
			if typeof(
				raw_summary
			) != TYPE_DICTIONARY:
				continue

			requested_paths.append(
				str(
					(
						raw_summary as Dictionary
					).get(
						"path",
						""
					)
				)
			)

	var summaries_by_path: Dictionary = {}

	for raw_summary in _local_life_summaries():
		if typeof(
			raw_summary
		) != TYPE_DICTIONARY:
			continue

		var summary: Dictionary = (
			raw_summary as Dictionary
		).duplicate(true)
		var summary_path: String = str(
			summary.get(
				"path",
				""
			)
		).strip_edges()

		if summary_path != "":
			summaries_by_path [
				summary_path
			] = summary

	var ownership_by_path: Dictionary = (
		_safe_dictionary(
			transfer_registry.get(
				"ownership_by_path",
				{}
			)
		)
	)
	var attached: Array = []
	var skipped: Array = []
	var now_ms: int = _now_ms()

	for raw_path in requested_paths:
		var path: String = str(
			raw_path
		).strip_edges()

		if path == "":
			continue

		if not FileAccess.file_exists(
			path
		):
			skipped.append({
				"path": path,
				"reason": "saved_life_missing"
			})
			continue

		var existing: Dictionary = (
			_safe_dictionary(
				ownership_by_path.get(
					path,
					{}
				)
			)
		)
		var existing_owner_id: String = str(
			existing.get(
				"owner_identity_id",
				""
			)
		).strip_edges()

		if (
			existing_owner_id != ""
			and existing_owner_id != identity_id
		):
			skipped.append({
				"path": path,
				"reason": (
					"owned_by_other_eraccount"
				),
				"owner_identity_id": (
					existing_owner_id
				)
			})
			continue

		var summary: Dictionary = (
			_safe_dictionary(
				summaries_by_path.get(
					path,
					{}
				)
			)
		)
		var portable_life_packet_id: String = str(
			existing.get(
				"portable_life_packet_id",
				""
			)
		).strip_edges()

		if portable_life_packet_id == "":
			portable_life_packet_id = (
				"life_packet:%s:%d:%d"
				% [
					identity_id,
					now_ms,
					attached.size()
				]
			)

		var life_id: String = str(
			context.get(
				"life_id",
				existing.get(
					"life_id",
					""
				)
			)
		).strip_edges()

		if life_id == "":
			life_id = (
				"legacy_%s"
				% portable_life_packet_id.replace(
					":",
					"_"
				)
			)

		var branch_id: String = str(
			context.get(
				"branch_id",
				existing.get(
					"branch_id",
					"main"
				)
			)
		).strip_edges()

		if branch_id == "":
			branch_id = "main"

		var root_life_packet_id: String = str(
			existing.get(
				"root_life_packet_id",
				portable_life_packet_id
			)
		).strip_edges()
		var attachment_revision: int = int(
			existing.get(
				"attachment_revision",
				0
			)
		) + 1
		var attachment: Dictionary = {
			"schema": (
				"eralife.life_account_transfer.attachment"
			),
			"version": CONTRACT_VERSION,
			"path": path,
			"checkpoint_path": path,
			"owner_identity_id": identity_id,
			"owner_username": username,
			"owner_local_identity_id": str(
				identity_context.get(
					"local_identity_id",
					""
				)
			),
			"owner_device_identity_id": str(
				identity_context.get(
					"device_identity_id",
					""
				)
			),
			"portable_life_packet_id": (
				portable_life_packet_id
			),
			"root_life_packet_id": (
				root_life_packet_id
			),
			"life_id": life_id,
			"branch_id": branch_id,
			"parent_branch_id": str(
				existing.get(
					"parent_branch_id",
					""
				)
			),
			"fork_parent_packet_id": str(
				existing.get(
					"fork_parent_packet_id",
					""
				)
			),
			"attachment_revision": (
				attachment_revision
			),
			"player_name": str(
				summary.get(
					"player_name",
					"Current Life"
				)
			),
			"player_age": int(
				summary.get(
					"age",
					-1
				)
			),
			"era_name": str(
				summary.get(
					"era_name",
					""
				)
			),
			"head_saved_at_unix": int(
				summary.get(
					"saved_at_unix",
					FileAccess.get_modified_time(
						path
					)
				)
			),
			"attached_at_ms": int(
				existing.get(
					"attached_at_ms",
					now_ms
				)
			),
			"updated_at_ms": now_ms,
			"cloud_replication_state": (
				"local_attachment_pending_remote_replication"
			),
		}

		ownership_by_path [
			path
		] = attachment
		attached.append(
			attachment
		)

	transfer_registry [
		"ownership_by_path"
	] = ownership_by_path
	transfer_registry [
		"updated_at_ms"
	] = now_ms
	_write_registry()

	last_report = {
		"schema": (
			"eralife.life_account_transfer.report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": (
			"local_lives_attached_to_eraccount"
		),
		"message": (
			"%d local life packet(s) were attached to @%s."
			% [
				attached.size(),
				username
			]
		),
		"attached": attached,
		"skipped": skipped,
		"attached_count": attached.size(),
		"skipped_count": skipped.size(),
		"cloud_replication_pending": (
			not attached.is_empty()
		),
		"transfer_context": (
			emit_transfer_context({
				"source": (
					"transfer_local_lives_to_current_account"
				)
			})
		),
		"created_at_ms": now_ms
	}

	_commit_state()

	return last_report.duplicate(true)


func leave_local_lives_unattached(
	life_paths: Array = [],
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var dismissed_paths: Array = (
		life_paths.duplicate(true)
	)

	if dismissed_paths.is_empty():
		var transfer_context: Dictionary = (
			emit_transfer_context(context)
		)
		var unclaimed_lives: Array = (
			_safe_array(
				transfer_context.get(
					"unclaimed_lives",
					[]
				)
			)
		)

		for raw_summary in unclaimed_lives:
			if typeof(raw_summary) != TYPE_DICTIONARY:
				continue

			dismissed_paths.append(
				str(
					(
						raw_summary as Dictionary
					).get(
						"path",
						""
					)
				)
			)

	transfer_registry [
		"last_left_local_paths"
	] = dismissed_paths
	transfer_registry [
		"last_left_local_at_ms"
	] = _now_ms()
	_write_registry()

	last_report = {
		"schema": (
			"eralife.life_account_transfer.report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": (
			"local_lives_left_unattached"
		),
		"message": (
			"Your local lives remain local and fully playable."
		),
		"life_paths": dismissed_paths,
		"created_at_ms": _now_ms()
	}
	_commit_state()
	return last_report.duplicate(true)


func detach_life_from_current_account(
	life_path: String,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var identity_context: Dictionary = (
		_identity_context()
	)
	if bool(
		identity_context.get(
			"is_guest",
			true
		)
	):
		return _fail(
			"account_required",
			"Sign into the owning ErAccount before detaching a life.",
			context
		)

	var identity_id: String = (
		_identity_id(identity_context)
	)
	var clean_path: String = str(
		life_path
	).strip_edges()
	var ownership_by_path: Dictionary = (
		_safe_dictionary(
			transfer_registry.get(
				"ownership_by_path",
				{}
			)
		)
	)
	var ownership: Dictionary = (
		_safe_dictionary(
			ownership_by_path.get(
				clean_path,
				{}
			)
		)
	)

	if ownership.is_empty():
		return _fail(
			"attachment_missing",
			"That life is not attached to an ErAccount.",
			context
		)

	if str(
		ownership.get(
			"owner_identity_id",
			""
		)
	) != identity_id:
		return _fail(
			"attachment_permission_denied",
			"Only the owning ErAccount may detach this life.",
			context
		)

	ownership_by_path.erase(clean_path)
	transfer_registry ["ownership_by_path"] = (
		ownership_by_path
	)
	transfer_registry ["updated_at_ms"] = (
		_now_ms()
	)
	_write_registry()

	last_report = {
		"schema": (
			"eralife.life_account_transfer.report"
		),
		"version": CONTRACT_VERSION,
		"success": true,
		"mode": (
			"life_detached_from_eraccount"
		),
		"message": (
			"The life remains saved locally but is no longer attached to this ErAccount."
		),
		"path": clean_path,
		"created_at_ms": _now_ms()
	}
	_commit_state()
	return last_report.duplicate(true)


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

	if command_id == "life_account_transfer.emit":
		return emit_transfer_context(
			envelope
		)

	if (
		command_id
		== "life_account_transfer.title_card_continue"
	):
		return emit_title_card_continue_contract(
			envelope
		)

	if command_id == "life_account_transfer.attach":
		return transfer_local_lives_to_current_account(
			_safe_array(
				envelope.get(
					"life_paths",
					[]
				)
			),
			envelope
		)

	if command_id == "life_account_transfer.leave_local":
		return leave_local_lives_unattached(
			_safe_array(
				envelope.get(
					"life_paths",
					[]
				)
			),
			envelope
		)

	if command_id == "life_account_transfer.detach":
		return detach_life_from_current_account(
			str(
				envelope.get(
					"life_path",
					""
				)
			),
			envelope
		)

	return _fail(
		"unknown_life_account_transfer_command",
		(
			"LifeAccountTransferContractEngine "
			+ "did not recognize command."
		),
		envelope
	)

func _local_life_summaries() -> Array:
	if (
		gs != null
		and gs.has_method(
			"list_saved_life_summaries"
		)
	):
		var raw: Variant = (
			gs.list_saved_life_summaries()
		)

		if typeof(raw) == TYPE_ARRAY:
			return (
				raw as Array
			).duplicate(true)

	return []


func _identity_context() -> Dictionary:
	if (
		gs != null
		and "identity_contract_engine" in gs
		and gs.identity_contract_engine != null
		and gs.identity_contract_engine.has_method(
			"emit_identity_context"
		)
	):
		return (
			gs.identity_contract_engine
			.emit_identity_context({
				"source": (
					"life_account_transfer"
				)
			})
		)

	return {
		"is_guest": true
	}


func _identity_id(
	identity_context: Dictionary
) -> String:
	return str(
		identity_context.get(
			"cloud_identity_id",
			identity_context.get(
				"identity_id",
				""
			)
		)
	).strip_edges()


func _ensure_state() -> void:
	transfer_registry = _read_registry()

	if typeof(
		transfer_registry.get(
			"ownership_by_path",
			{}
		)
	) != TYPE_DICTIONARY:
		transfer_registry [
			"ownership_by_path"
		] = {}

	_commit_state()


func _read_registry() -> Dictionary:
	if not FileAccess.file_exists(
		TRANSFER_REGISTRY_PATH
	):
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"ownership_by_path": {}
		}

	var file:= FileAccess.open(
		TRANSFER_REGISTRY_PATH,
		FileAccess.READ
	)

	if file == null:
		return {
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"ownership_by_path": {}
		}

	var parsed: Variant = JSON.parse_string(
		file.get_as_text()
	)
	file.close()

	if typeof(parsed) == TYPE_DICTIONARY:
		return (
			parsed as Dictionary
		).duplicate(true)

	return {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"ownership_by_path": {}
	}


func _write_registry() -> void:
	_ensure_identity_dir()

	var file:= FileAccess.open(
		TRANSFER_REGISTRY_PATH,
		FileAccess.WRITE
	)

	if file == null:
		return

	file.store_string(
		JSON.stringify(
			transfer_registry,
			"\t"
		)
	)
	file.close()


func _ensure_identity_dir() -> void:
	var root:= DirAccess.open(
		"user://"
	)

	if (
		root != null
		and not root.dir_exists(
			"identity"
		)
	):
		root.make_dir(
			"identity"
		)


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"life_account_transfer_registry"
	] = transfer_registry.duplicate(true)
	gs.scenario_state [
		"last_life_account_transfer_report"
	] = last_report.duplicate(true)


func _now_ms() -> int:
	return int(
		Time.get_unix_time_from_system()
		* 1000.0
	)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _fail(
	reason_id: String,
	message: String,
	context: Dictionary = {}
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": (
			"eralife.life_account_transfer.error"
		),
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": message,
		"message": message,
		"context": context.duplicate(true),
		"created_at_ms": _now_ms()
	}
	_commit_state()
	return last_report.duplicate(true)