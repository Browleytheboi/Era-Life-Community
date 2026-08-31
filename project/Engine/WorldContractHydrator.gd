extends Resource
class_name WorldContractHydrator

const HYDRATOR_REPORT_SCHEMA:= "eralife.world_contract_hydrator_report"
const CONTRACT_VERSION:= 1

var gs
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func hydrate_resolved_checkpoint(
	resolved_checkpoint: Dictionary = {},
	options: Dictionary = {}
) -> Dictionary:
	if gs == null:
		return _fail(
			"game_state_missing",
			"GameState unavailable.",
			resolved_checkpoint,
			options
		)

	var path: String = str(
		resolved_checkpoint.get(
			"checkpoint_path",
			resolved_checkpoint.get(
				"path",
				""
			)
		)
	).strip_edges()

	if path == "":
		return _fail(
			"checkpoint_path_missing",
			"Resolved checkpoint has no path.",
			resolved_checkpoint,
			options
		)

	if not FileAccess.file_exists(
		path
	):
		return _fail(
			"checkpoint_file_missing",
			"Resolved checkpoint file is missing.",
			resolved_checkpoint,
			options
		)

	var resume_raw: Variant = (
		resolved_checkpoint.get(
			"checkpoint_resume_contract",
			{}
		)
	)
	var resume_contract: Dictionary = (
		resume_raw as Dictionary
		if typeof(
			resume_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var load_options: Dictionary = {
		"source": str(
			options.get(
				"source",
				"world_contract_hydrator"
			)
		),
		"load_mode": "playable_first",
		"profile": str(
			options.get(
				"profile",
				"silent_auto_enter"
			)
		),
		"background_enabled": true,
		"playable_npc_limit": int(
			options.get(
				"playable_npc_limit",
				24
			)
		),
		"resolved_checkpoint": (
			resolved_checkpoint.duplicate(false)
		),
		"checkpoint_resume_contract": resume_contract,
		"contract_driven_existence": true,
		"deferred_reality": true,
		"buffered_intention": true,
		"live_system_emergence": true,
		"complete_checkpoint_copy_performed": false
	}

	for key in options.keys():
		load_options [key] = options [key]

	var report: Dictionary = (
		gs.load_game(
			path,
			load_options
		)
	)

	if (
		bool(
			report.get(
				"success",
				false
			)
		)
		and not resume_contract.is_empty()
	):
		var controlled_actor_id: int = int(
			resume_contract.get(
				"controlled_actor_id",
				resume_contract.get(
					"actor_id",
					-1
				)
			)
		)
		var controlled_actor: Person = null

		if controlled_actor_id > 0:
			controlled_actor = gs.get_npc_by_id(
				controlled_actor_id
			)

		if (
			controlled_actor == null
			and controlled_actor_id > 0
		):
			var actor_snapshot_raw: Variant = (
				resume_contract.get(
					"actor_snapshot",
					{}
				)
			)

			if typeof(
				actor_snapshot_raw
			) == TYPE_DICTIONARY:
				controlled_actor = gs._deserialize_npc(
					actor_snapshot_raw as Dictionary
				)

				if controlled_actor != null:
					controlled_actor.id = (
						controlled_actor_id
					)

					var actor_already_present: bool = false

					for existing_actor in gs.npcs:
						if (
							existing_actor != null
							and int(
								existing_actor.id
							) == controlled_actor_id
						):
							actor_already_present = true
							break

					if not actor_already_present:
						gs.npcs.append(
							controlled_actor
						)

					gs._rebuild_npc_index()

		if controlled_actor != null:
			gs.player = controlled_actor
			gs.player_id = int(
				controlled_actor.id
			)

			# DIAGNOSTIC: money, year and era restore but age does not. Report what
			# actually landed on the restored actor.
			EraLog.truth(
				"ERALIFE_RESUME_ACTOR|actor_id=%d|age=%s|year=%s|money=%s"
				% [
					int(controlled_actor.id),
					str(controlled_actor.age),
					str(gs.year),
					str(controlled_actor.money)
				]
			)

		if typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY:
			gs.scenario_state = {}

		var first_frame_raw: Variant = (
			resume_contract.get(
				"first_frame_ui_snapshot",
				{}
			)
		)

		if typeof(
			first_frame_raw
		) == TYPE_DICTIONARY:
			var first_frame_snapshot: Dictionary = (
				first_frame_raw as Dictionary
			)

			gs.scenario_state [
				"prebuilt_first_frame_ui_snapshot"
			] = first_frame_snapshot
			gs.scenario_state [
				"zero_frame_consciousness_switch_surface"
			] = first_frame_snapshot

		gs.scenario_state [
			"checkpoint_resume_contract"
		] = resume_contract
		gs.scenario_state [
			"checkpoint_resume_current_panel"
		] = str(
			resume_contract.get(
				"current_panel",
				"life"
			)
		)
		gs.scenario_state [
			"checkpoint_resume_controlled_actor_id"
		] = controlled_actor_id
		gs.scenario_state [
			"checkpoint_resume_blank_shell_forbidden"
		] = true
		gs.scenario_state [
			"checkpoint_resume_first_frame_truth_hot"
		] = (
			typeof(
				first_frame_raw
			) == TYPE_DICTIONARY
		)

		report [
			"checkpoint_resume_contract_applied"
		] = true
		report [
			"checkpoint_controlled_actor_id"
		] = controlled_actor_id
		report [
			"checkpoint_current_panel"
		] = str(
			resume_contract.get(
				"current_panel",
				"life"
			)
		)
		report [
			"checkpoint_first_frame_snapshot"
		] = first_frame_raw
		report [
			"blank_life_shell_forbidden"
		] = true

	last_report = report.duplicate(false)
	last_report ["schema"] = HYDRATOR_REPORT_SCHEMA
	last_report ["version"] = CONTRACT_VERSION
	last_report ["checkpoint_path"] = path
	last_report ["hydrator"] = "WorldContractHydrator"
	last_report ["continuous_reality"] = bool(
		report.get(
			"success",
			false
		)
	)
	last_report [
		"worker_thread_used"
	] = bool(
		options.get(
			"worker_thread_used",
			false
		)
	)
	last_report [
		"complete_checkpoint_copy_performed"
	] = false

	_commit_state()

	return last_report.duplicate(false)

func _fail(reason_id: String, reason: String, checkpoint: Dictionary, options: Dictionary) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason_id)
	)
	last_report = {
		"schema": HYDRATOR_REPORT_SCHEMA,
		"version": CONTRACT_VERSION,
		"success": false,
		"reason_id": reason_id,
		"reason": reason,
		"checkpoint": checkpoint.duplicate(true),
		"options": options.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_commit_state()
	return last_report.duplicate(true)

func _commit_state() -> void:
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state ["last_world_contract_hydrator_report"] = last_report.duplicate(true)