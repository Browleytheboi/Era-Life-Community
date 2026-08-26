

extends Resource
class_name RealityProjectionContractEngine

signal resident_surface_contract_ready(
	signature: String,
	surface_id: String,
	surface_contract: Dictionary
)

signal resident_relationship_section_contract_ready(
	signature: String,
	actor_id: int,
	section_id: String,
	section_contract: Dictionary
)

signal resident_projection_ready(
	signature: String,
	projection_contract: Dictionary
)

signal resident_continuous_observation_ready(
	observation_key: String,
	observation_contract: Dictionary
)

const ENGINE_SCHEMA:= (
	"eralife.reality_projection_contract_engine"
)
const PROJECTION_SCHEMA:= (
	"eralife.reality_resident_projection_contract"
)
const ENGINE_VERSION:= 1
const MAX_LEDGER:= 96

var gs = null
var projection_work_by_signature: Dictionary = {}
var last_projection_by_signature: Dictionary = {}
var last_report: Dictionary = {}
var ledger: Array = []










const MAX_RESIDENT_SURFACE_ADMISSION_PACKETS:= 64

var resident_surface_admission_packet_by_key: Dictionary = {}
var resident_surface_admission_packet_by_actor: Dictionary = {}
var resident_surface_admission_key_order: Array = []


var projection_step_threads: Dictionary = {}
var projection_step_thread_context_by_signature: Dictionary = {}
var checkpoint_resume_life_observation_threads: Dictionary = {}
var checkpoint_resume_life_observation_request_by_signature: Dictionary = {}
var checkpoint_resume_life_observation_poll_armed: Dictionary = {}




var checkpoint_resume_life_observation_generation_by_signature: Dictionary = {}
var checkpoint_resume_life_observation_worker_generation_by_signature: Dictionary = {}

func _init(
	_gs = null
) -> void:
	gs = _gs

	var admission_callable: Callable = Callable(
		self,
		"_capture_resident_surface_admission_packet"
	)

	if not resident_surface_contract_ready.is_connected(
		admission_callable
	):
		resident_surface_contract_ready.connect(
			admission_callable
		)

	var persistence_callable: Callable = Callable(
		self,
		"_persist_resident_main_tab_surface_deck_if_complete"
	)

	if not resident_surface_contract_ready.is_connected(
		persistence_callable
	):
		resident_surface_contract_ready.connect(
			persistence_callable
		)
func _capture_resident_surface_admission_packet(
	signature: String,
	surface_id: String,
	surface_contract: Dictionary
) -> void:
	var clean_signature: String = str(
		signature
	).strip_edges()

	var clean_surface_id: String = str(
		surface_id
	).strip_edges().to_lower()

	if (
		clean_signature == ""
		or clean_surface_id == ""
		or surface_contract.is_empty()
	):
		return

	var actor_id: int = int(
		surface_contract.get(
			"actor_id",
			-1
		)
	)

	if actor_id <= 0:
		return

	var packet_key: String = (
		"%s:%d"
		% [
			clean_signature,
			actor_id
		]
	)

	if not resident_surface_admission_packet_by_key.has(
		packet_key
	):
		resident_surface_admission_key_order.append(
			packet_key
		)

	var packet: Dictionary = {
		"signature": clean_signature,
		"surface_id": clean_surface_id,
		"actor_id": actor_id,
		"surface_contract": surface_contract.duplicate(false),
		"published_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	resident_surface_admission_packet_by_key [
		packet_key
	] = packet





	resident_surface_admission_packet_by_actor [
		str(
			actor_id
		)
	] = packet

	while resident_surface_admission_key_order.size() > (
		MAX_RESIDENT_SURFACE_ADMISSION_PACKETS
	):
		var retired_key: String = str(
			resident_surface_admission_key_order.pop_front()
		)

		var retired_raw: Variant = (
			resident_surface_admission_packet_by_key.get(
				retired_key,
				{}
			)
		)

		var retired_packet: Dictionary = (
			retired_raw as Dictionary
			if typeof(retired_raw) == TYPE_DICTIONARY
			else {}
		)

		resident_surface_admission_packet_by_key.erase(
			retired_key
		)

		var retired_actor_id: int = int(
			retired_packet.get(
				"actor_id",
				-1
			)
		)

		if retired_actor_id <= 0:
			continue

		var retired_actor_key: String = str(
			retired_actor_id
		)

		var latest_raw: Variant = (
			resident_surface_admission_packet_by_actor.get(
				retired_actor_key,
				{}
			)
		)

		if typeof(latest_raw) != TYPE_DICTIONARY:
			continue

		var latest_packet: Dictionary = (
			latest_raw as Dictionary
		)

		if (
			str(
				latest_packet.get(
					"signature",
					""
				)
			) == str(
				retired_packet.get(
					"signature",
					""
				)
			)
			and int(
				latest_packet.get(
					"published_at_ms",
					-1
				)
			) == int(
				retired_packet.get(
					"published_at_ms",
					-2
				)
			)
		):
			resident_surface_admission_packet_by_actor.erase(
				retired_actor_key
			)
func latest_resident_surface_admission_packet_for_actor(
	actor_id: int
) -> Dictionary:
	if actor_id <= 0:
		return {}

	var packet_raw: Variant = (
		resident_surface_admission_packet_by_actor.get(
			str(
				actor_id
			),
			{}
		)
	)

	if typeof(packet_raw) != TYPE_DICTIONARY:
		return {}

	var packet: Dictionary = (
		packet_raw as Dictionary
	)

	if int(
		packet.get(
			"actor_id",
			-1
		)
	) != actor_id:
		return {}



	return packet.duplicate(
		false
	)
func resident_surface_admission_packet(
	actor_id: int,
	signature_hint: String
) -> Dictionary:
	var clean_signature: String = str(
		signature_hint
	).strip_edges()

	if (
		actor_id <= 0
		or clean_signature == ""
	):
		return {}

	var packet_key: String = (
		"%s:%d"
		% [
			clean_signature,
			actor_id
		]
	)

	var packet_raw: Variant = (
		resident_surface_admission_packet_by_key.get(
			packet_key,
			{}
		)
	)

	if typeof(packet_raw) != TYPE_DICTIONARY:
		return {}



	return (
		packet_raw as Dictionary
	).duplicate(false)

func bind_game_state(
	_gs
) -> void:
	gs = _gs

func _persist_resident_main_tab_surface_deck_if_complete(
	signature: String,
	surface_id: String,
	surface_contract: Dictionary
) -> void:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var clean_surface_id: String = str(
		surface_id
	).strip_edges().to_lower()

	if (
		clean_signature == ""
		or clean_surface_id not in [
			"relationships",
			"school",
			"activities",
			"career",
			"mods"
		]
		or surface_contract.is_empty()
	):
		return

	var work: Dictionary = _work(
		clean_signature
	)

	if work.is_empty():
		return

	var runtime = work.get(
		"runtime_ref",
		null
	)
	var actor_id: int = int(
		work.get(
			"actor_id",
			surface_contract.get(
				"actor_id",
				-1
			)
		)
	)

	if (
		runtime == null
		or actor_id <= 0
		or int(
			surface_contract.get(
				"actor_id",
				-1
			)
		) != actor_id
	):
		return

	var surface_deck_raw: Variant = work.get(
		"surface_contracts",
		{}
	)
	var surface_deck: Dictionary = (
		(surface_deck_raw as Dictionary).duplicate(false)
		if typeof(surface_deck_raw) == TYPE_DICTIONARY
		else {}
	)

	surface_deck [
		clean_surface_id
	] = surface_contract.duplicate(false)





	work [
		"surface_contracts"
	] = surface_deck
	work [
		"last_resident_surface_successor_id"
	] = clean_surface_id
	work [
		"last_resident_surface_successor_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	projection_work_by_signature [
		clean_signature
	] = work

	var persisted_deck: Dictionary = {}

	for required_surface_id in [
		"relationships",
		"school",
		"activities",
		"career",
		"mods"
	]:
		var contract_raw: Variant = surface_deck.get(
			required_surface_id,
			{}
		)
		var contract: Dictionary = (
			contract_raw as Dictionary
			if typeof(contract_raw) == TYPE_DICTIONARY
			else {}
		)

		if (
			contract.is_empty()
			or int(
				contract.get(
					"actor_id",
					-1
				)
			) != actor_id
		):
			return

		var schema: String = str(
			contract.get(
				"schema",
				""
			)
		).strip_edges().to_lower()
		var truth_state: String = str(
			contract.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower()



		if (
			schema == "eralife.pointer_only.destination_tab_contract"
			or truth_state == "pointer_only_resident_shell"
			or bool(
				contract.get(
					"pointer_only",
					false
				)
			)
			or bool(
				contract.get(
					"projection_pending",
					false
				)
			)
			or truth_state in [
				"warming",
				"streaming",
				"observable_partial",
				"partial",
				"pending"
			]
		):
			return

		if (
			contract.has(
				"projection_complete"
			)
			and not bool(
				contract.get(
					"projection_complete",
					false
				)
			)
		):
			return

		persisted_deck [
			required_surface_id
		] = contract.duplicate(false)

	if typeof(
		runtime.scenario_state
	) != TYPE_DICTIONARY:
		runtime.scenario_state = {}

	var deck_by_actor_raw: Variant = (
		runtime.scenario_state.get(
			"resident_main_tab_surface_contracts_by_actor",
			{}
		)
	)
	var deck_by_actor: Dictionary = (
		(deck_by_actor_raw as Dictionary).duplicate(false)
		if typeof(deck_by_actor_raw) == TYPE_DICTIONARY
		else {}
	)

	deck_by_actor [
		str(actor_id)
	] = persisted_deck.duplicate(false)

	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	runtime.scenario_state [
		"resident_main_tab_surface_contracts_by_actor"
	] = deck_by_actor
	runtime.scenario_state [
		"resident_main_tab_surface_contracts_last_actor_id"
	] = actor_id
	runtime.scenario_state [
		"resident_main_tab_surface_contracts_last_signature"
	] = clean_signature
	runtime.scenario_state [
		"resident_main_tab_surface_contracts_cached_at_ms"
	] = now_ms
	runtime.scenario_state [
		"resident_main_tab_surface_contracts_complete_actor_id"
	] = actor_id
	runtime.scenario_state [
		"resident_main_tab_surface_contracts_complete"
	] = true
	runtime.scenario_state [
		"resident_main_tab_surface_contracts_authority"
	] = "RealityProjectionContractEngine"
	runtime.scenario_state [
		"resident_main_tab_surface_contracts_renderer_persistence_bridge_forbidden"
	] = true

	if (
		runtime.player != null
		and int(
			runtime.player.id
		) == actor_id
	):
		runtime.scenario_state [
			"resident_main_tab_surface_contracts"
		] = persisted_deck.duplicate(false)

	EraLog.truth(
		"ERALIFE_RESIDENT_MAIN_TAB_DECK_AUTHORITY_TRUTH"
		+ "|signature=" + clean_signature
		+ "|actor_id=" + str(actor_id)
		+ "|surface_count=5"
		+ "|authority=RealityProjectionContractEngine"
		+ "|renderer_persistence_bridge=false"
		+ "|all_surfaces_terminal=true"
		+ "|streaming_surface_persisted=false"
		+ "|projection_rebuild_required_on_next_checkpoint=false"
		+ "|ready_gate_member=false"
		+ "|at_ms=" + str(now_ms)
	)
func bootstrap_default_contracts() -> Dictionary:
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"projection_graphs": [
			"contract_graph",
			"projection_graph",
			"lens_graph",
			"node_graph",
			"surface_graph"
		],
		"build_on_click_forbidden": true,
		"ui_is_renderer_only": true
	}
func queue_checkpoint_resume_life_observation(
	runtime,
	signature: String,
	resume_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()

	if (
		runtime == null
		or runtime.player == null
		or clean_signature == ""
	):
		return {
			"success": false,
			"reason": "checkpoint_life_observation_runtime_unavailable"
		}

	var request_generation: int = int(
		checkpoint_resume_life_observation_generation_by_signature.get(
			clean_signature,
			0
		)
	) + 1

	checkpoint_resume_life_observation_generation_by_signature [
		clean_signature
	] = request_generation

	checkpoint_resume_life_observation_request_by_signature [
		clean_signature
	] = {
		"runtime_ref": runtime,
		"actor_id": int(
			runtime.player.id
		),
		"resume_contract": (
			resume_contract.duplicate(false)
		),
		"context": context.duplicate(false),
		"generation": request_generation,
		"queued_at_ms": int(
			Time.get_ticks_msec()
		),
		"background_only": true,
		"blocks_ui": false,
		"requires_ui_idle": false,
		"ready_gate_member": false
	}

	_arm_checkpoint_resume_life_observation_poll(
		clean_signature
	)

	return {
		"success": true,
		"queued": true,
		"signature": clean_signature,
		"actor_id": int(
			runtime.player.id
		),
		"generation": request_generation,
		"background_only": true,
		"blocks_ui": false,
		"requires_ui_idle": false,
		"ready_gate_member": false
	}
func checkpoint_resume_life_observation_pending(
	signature: String
) -> bool:
	var clean_signature: String = str(
		signature
	).strip_edges()

	if clean_signature == "":
		return false

	return (
		checkpoint_resume_life_observation_request_by_signature.has(
			clean_signature
		)
		or checkpoint_resume_life_observation_threads.has(
			clean_signature
		)
	)


func _arm_checkpoint_resume_life_observation_poll(
	signature: String
) -> void:
	var clean_signature: String = str(
		signature
	).strip_edges()

	if clean_signature == "":
		return

	if bool(
		checkpoint_resume_life_observation_poll_armed.get(
			clean_signature,
			false
		)
	):
		return

	checkpoint_resume_life_observation_poll_armed [
		clean_signature
	] = true

	call_deferred(
		"_service_checkpoint_resume_life_observation",
		clean_signature
	)


func _service_checkpoint_resume_life_observation(
	signature: String
) -> void:
	var clean_signature: String = str(
		signature
	).strip_edges()

	checkpoint_resume_life_observation_poll_armed.erase(
		clean_signature
	)

	var request: Dictionary = _dict(
		checkpoint_resume_life_observation_request_by_signature.get(
			clean_signature,
			{}
		)
	)

	if request.is_empty():
		return

	var worker_raw: Variant = (
		checkpoint_resume_life_observation_threads.get(
			clean_signature,
			null
		)
	)

	if worker_raw is Thread:
		var active_life_observation_worker: Thread = (
			worker_raw as Thread
		)

		if active_life_observation_worker.is_alive():
			_arm_checkpoint_resume_life_observation_poll(
				clean_signature
			)
			return

		var worker_generation: int = int(
			checkpoint_resume_life_observation_worker_generation_by_signature.get(
				clean_signature,
				0
			)
		)
		var result_raw: Variant = (
			active_life_observation_worker.wait_to_finish()
		)

		checkpoint_resume_life_observation_threads.erase(
			clean_signature
		)
		checkpoint_resume_life_observation_worker_generation_by_signature.erase(
			clean_signature
		)



		var latest_request: Dictionary = _dict(
			checkpoint_resume_life_observation_request_by_signature.get(
				clean_signature,
				{}
			)
		)
		var latest_generation: int = int(
			latest_request.get(
				"generation",
				0
			)
		)

		if (
			latest_request.is_empty()
			or latest_generation <= worker_generation
		):
			checkpoint_resume_life_observation_request_by_signature.erase(
				clean_signature
			)

		var newer_request_pending: bool = (
			checkpoint_resume_life_observation_request_by_signature.has(
				clean_signature
			)
		)

		if typeof(result_raw) != TYPE_DICTIONARY:
			if newer_request_pending:
				_arm_checkpoint_resume_life_observation_poll(
					clean_signature
				)

			return

		var observation: Dictionary = (
			(result_raw as Dictionary).duplicate(false)
		)

		if bool(
			observation.get(
				"success",
				false
			)
		):
			publish_resident_continuous_observation(
				"checkpoint_resume_life_shell:%s"
				% clean_signature,
				observation
			)

		if newer_request_pending:
			_arm_checkpoint_resume_life_observation_poll(
				clean_signature
			)

		return



	var projection_worker_raw: Variant = (
		projection_step_threads.get(
			clean_signature,
			null
		)
	)

	if (
		projection_worker_raw is Thread
		and (
			projection_worker_raw as Thread
		).is_alive()
	):
		_arm_checkpoint_resume_life_observation_poll(
			clean_signature
		)
		return

	var runtime = request.get(
		"runtime_ref",
		null
	)
	var resume_contract: Dictionary = _dict(
		request.get(
			"resume_contract",
			{}
		)
	)
	var context: Dictionary = _dict(
		request.get(
			"context",
			{}
		)
	)
	var request_generation: int = int(
		request.get(
			"generation",
			0
		)
	)

	var new_life_observation_worker: Thread = Thread.new()
	var new_worker_error: int = (
		new_life_observation_worker.start(
			Callable(
				self,
				"_build_checkpoint_resume_life_observation_on_worker"
			).bind(
				runtime,
				clean_signature,
				resume_contract,
				context
			),
			Thread.PRIORITY_LOW
		)
	)

	if new_worker_error != OK:
		var current_request: Dictionary = _dict(
			checkpoint_resume_life_observation_request_by_signature.get(
				clean_signature,
				{}
			)
		)

		if int(
			current_request.get(
				"generation",
				-1
			)
		) == request_generation:
			checkpoint_resume_life_observation_request_by_signature.erase(
				clean_signature
			)

		return

	checkpoint_resume_life_observation_threads [
		clean_signature
	] = new_life_observation_worker
	checkpoint_resume_life_observation_worker_generation_by_signature [
		clean_signature
	] = request_generation

	_arm_checkpoint_resume_life_observation_poll(
		clean_signature
	)
func _build_checkpoint_resume_life_observation_on_worker(
	runtime,
	signature: String,
	resume_contract: Dictionary,
	context: Dictionary
) -> Dictionary:
	if (
		runtime == null
		or runtime.player == null
	):
		return {
			"success": false,
			"reason": "checkpoint_life_observation_actor_missing"
		}

	var actor_id: int = int(
		runtime.player.id
	)
	var diary_entries: Array = []
	var diary_lines: Array = []

	if (
		runtime.life_diary_contract_engine != null
		and runtime.life_diary_contract_engine.has_method(
			"diary_entries_for_actor"
		)
	):
		diary_entries = (
			runtime.life_diary_contract_engine
			.diary_entries_for_actor(
				actor_id,
				{
					"source": (
						"reality_projection_contract_engine."
						+ "checkpoint_resume_life_observation"
					),
					"read_only": true
				}
			)
		)

	if (
		runtime.life_diary_contract_engine != null
		and runtime.life_diary_contract_engine.has_method(
			"diary_lines_for_actor"
		)
	):
		diary_lines = (
			runtime.life_diary_contract_engine
			.diary_lines_for_actor(
				actor_id,
				{
					"source": (
						"reality_projection_contract_engine."
						+ "checkpoint_resume_life_observation"
					),
					"read_only": true
				}
			)
		)

	if diary_entries.is_empty():
		var saved_entries_raw: Variant = (
			resume_contract.get(
				"life_diary_entries",
				[]
			)
		)

		if typeof(saved_entries_raw) == TYPE_ARRAY:
			diary_entries = (
				(saved_entries_raw as Array).duplicate(false)
			)

	if diary_lines.is_empty():
		var saved_lines_raw: Variant = (
			resume_contract.get(
				"latest_life_diary_lines",
				[]
			)
		)

		if typeof(saved_lines_raw) == TYPE_ARRAY:
			diary_lines = (
				(saved_lines_raw as Array).duplicate(false)
			)

	var first_frame_raw: Variant = (
		resume_contract.get(
			"first_frame_ui_snapshot",
			{}
		)
	)
	var first_frame_base: Dictionary = (
		(first_frame_raw as Dictionary).duplicate(false)
		if typeof(first_frame_raw) == TYPE_DICTIONARY
		else {}
	)

	var first_frame_snapshot: Dictionary = (
		runtime
		._checkpoint_resume_first_frame_snapshot_for_current_actor(
			first_frame_base,
			diary_lines,
			str(
				resume_contract.get(
					"current_panel",
					"life"
				)
			)
		)
	)

	var hud_raw: Variant = resume_contract.get(
		"runtime_hud_visibility_snapshot",
		{}
	)
	var hud_base: Dictionary = (
		(hud_raw as Dictionary).duplicate(false)
		if typeof(hud_raw) == TYPE_DICTIONARY
		else {}
	)
	var hud_snapshot: Dictionary = (
		runtime
		._checkpoint_resume_hud_visibility_snapshot_for_current_actor(
			hud_base
		)
	)

	return {
		"success": true,
		"schema": (
			"eralife.checkpoint_resume."
			+ "life_shell_observation"
		),
		"version": 1,
		"observation_channel": (
			"checkpoint_resume_life_shell"
		),
		"signature": signature,
		"actor_id": actor_id,
		"first_frame_ui_snapshot": (
			first_frame_snapshot
		),
		"runtime_hud_visibility_snapshot": (
			hud_snapshot
		),
		"life_diary_entries": (
			diary_entries
		),
		"latest_life_diary_lines": (
			diary_lines
		),
		"truth_state": "hot",
		"authority_phase": str(
			context.get(
				"authority_phase",
				"hydrated_runtime"
			)
		),
		"simulation_mutation_performed": false,
		"requires_ui_idle": false,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
func publish_resident_continuous_observation(
	observation_key: String,
	observation_contract: Dictionary
) -> void:
	var clean_key: String = str(
		observation_key
	).strip_edges()

	if (
		clean_key == ""
		or observation_contract.is_empty()
		or not bool(
			observation_contract.get(
				"ui_is_renderer_only",
				false
			)
		)
	):
		return

	resident_continuous_observation_ready.emit(
		clean_key,
		observation_contract
	)
func _interactive_surface_contract_terminal_for_actor(
	surface_id: String,
	contract: Dictionary,
	actor_id: int
) -> bool:
	var clean_surface_id: String = str(
		surface_id
	).strip_edges().to_lower()

	if (
		clean_surface_id == ""
		or contract.is_empty()
		or actor_id <= 0
		or int(
			contract.get(
				"actor_id",
				-1
			)
		) != actor_id
	):
		return false

	var schema: String = str(
		contract.get(
			"schema",
			""
		)
	).strip_edges().to_lower()
	var truth_state: String = str(
		contract.get(
			"truth_state",
			""
		)
	).strip_edges().to_lower()

	if (
		schema
		== "eralife.pointer_only.destination_tab_contract"
		or truth_state
		== "pointer_only_resident_shell"
		or bool(
			contract.get(
				"pointer_only",
				false
			)
		)
		or bool(
			contract.get(
				"projection_pending",
				false
			)
		)
		or truth_state in [
			"warming",
			"streaming",
			"observable_partial",
			"partial",
			"pending"
		]
	):
		return false

	if (
		contract.has(
			"projection_complete"
		)
		and not bool(
			contract.get(
				"projection_complete",
				false
			)
		)
	):
		return false

	return true
func begin_resident_projection(
	runtime,
	context: Dictionary = {}
) -> Dictionary:
	if runtime == null:
		return _failure(
			"missing_runtime",
			context
		)

	var actor = context.get(
		"actor_override",
		runtime.player
	)

	if actor == null:
		return _failure(
			"missing_projection_actor",
			context
		)

	var signature: String = str(
		context.get(
			"signature",
			_runtime_signature(
				runtime
			)
		)
	).strip_edges()

	if signature == "":
		return _failure(
			"missing_signature",
			context
		)

	var actor_id: int = int(
		actor.id
	)

	if actor_id <= 0:
		return _failure(
			"invalid_projection_actor_id",
			context
		)

	var interactive_surfaces_only: bool = bool(
		context.get(
			"interactive_surfaces_only",
			false
		)
	)

	# FIX: this reuse branch returns the EXISTING projection whenever the actor has
	# not changed, and only erases + rebuilds for a different actor. That is correct
	# for the caller it was written for (character switching, where the actor always
	# differs), but it makes the engine structurally incapable of rebuilding surfaces
	# for the actor you are already playing. Anything acquired mid-life -- a pet, a
	# vehicle, a property -- commits to the data model and then never reaches the UI,
	# because the surface packets from world start are handed back as already
	# complete. "force_rebuild" lets a caller ask for a genuine rebuild; without it
	# the original reuse behaviour is untouched.
	var force_rebuild: bool = bool(
		context.get(
			"force_rebuild",
			false
		)
	)

	if projection_work_by_signature.has(
		signature
	):
		var existing_work: Dictionary = _work(
			signature
		)
		var existing_actor_id: int = int(
			existing_work.get(
				"actor_id",
				-1
			)
		)
		var existing_interactive_only: bool = bool(
			existing_work.get(
				"interactive_surfaces_only",
				false
			)
		)

		if (
			not force_rebuild
			and existing_actor_id == actor_id
			and existing_interactive_only == interactive_surfaces_only
		):
			return projection_status(
				signature
			)

		projection_work_by_signature.erase(
			signature
		)

	var interactive_surface_order: Array = [
		"mods",
		"school",
		"activities",
		"career",
		"relationships"
	]

	var persisted_surface_deck: Dictionary = {}
	var checkpoint_resume_runtime: bool = false

	if typeof(runtime.scenario_state) == TYPE_DICTIONARY:
		checkpoint_resume_runtime = (
			bool(
				runtime.scenario_state.get(
					"checkpoint_resume_not_birth",
					false
				)
			)
			or bool(
				runtime.scenario_state.get(
					"resident_runtime_restored_from_checkpoint",
					false
				)
			)
		)

		var deck_by_actor: Dictionary = _dict(
			runtime.scenario_state.get(
				"resident_main_tab_surface_contracts_by_actor",
				{}
			)
		)

		persisted_surface_deck = _dict(
			deck_by_actor.get(
				str(actor_id),
				{}
			)
		)

		if persisted_surface_deck.is_empty():
			persisted_surface_deck = _dict(
				runtime.scenario_state.get(
					"resident_main_tab_surface_contracts",
					{}
				)
			)

	var projection_source: String = str(
		context.get(
			"source",
			""
		)
	).strip_edges().to_lower()
	var continuation_relationship_priority: bool = (
		checkpoint_resume_runtime
		or bool(
			context.get(
				"continuation_actor_projection",
				false
			)
		)
		or projection_source.find(
			"continue_lineage_destination_prewarm"
		) >= 0
	)








	if continuation_relationship_priority:
		interactive_surface_order = [
			"relationships",
			"mods",
			"school",
			"activities",
			"career"
		]









	var validated_persisted_surface_deck: Dictionary = {}
	var projection_steps: Array = []

	for raw_surface_id in interactive_surface_order:
		var surface_id: String = str(
			raw_surface_id
		).strip_edges().to_lower()
		var persisted_contract: Dictionary = _dict(
			persisted_surface_deck.get(
				surface_id,
				{}
			)
		)
		var relationship_runtime_rebind_required: bool = (
			checkpoint_resume_runtime
			and surface_id == "relationships"
		)
		var persisted_contract_terminal: bool = (
			checkpoint_resume_runtime
			and not relationship_runtime_rebind_required
			and _interactive_surface_contract_terminal_for_actor(
				surface_id,
				persisted_contract,
				actor_id
			)
		)

		if persisted_contract_terminal:
			validated_persisted_surface_deck [
				surface_id
			] = persisted_contract.duplicate(false)
		else:
			projection_steps.append(
				surface_id
			)

	if not interactive_surfaces_only:
		projection_steps.append_array([
			"life",
			"world",
			"graphs"
		])

	var persisted_interactive_surface_packets_hot: bool = (
		checkpoint_resume_runtime
		and projection_steps.is_empty()
		and validated_persisted_surface_deck.size()
		== interactive_surface_order.size()
	)

	if persisted_interactive_surface_packets_hot:
		projection_work_by_signature [signature] = {
			"signature": signature,
			"runtime_ref": runtime,
			"actor_ref": actor,
			"actor_id": actor_id,
			"actor_override": actor != runtime.player,
			"interactive_surfaces_only": interactive_surfaces_only,
			"cursor": 0,
			"steps": [],
			"interactive_surface_order": (
				interactive_surface_order.duplicate(false)
			),
			"continuation_relationship_priority": (
				continuation_relationship_priority
			),
			"surface_contracts": (
				validated_persisted_surface_deck.duplicate(false)
			),
			"result": {
				"surface_contracts": (
					validated_persisted_surface_deck.duplicate(false)
				),
				"projection_rebuild_performed": false
			},
			"complete": true,
			"failed": false,
			"failure": {},
			"ready_signal_emitted": false,
			"projection_rebuild_performed": false,
			"started_at_ms": int(
				Time.get_ticks_msec()
			),
			"last_step_at_ms": int(
				Time.get_ticks_msec()
			),
			"context": context.duplicate(false)
		}

		_commit_state()

		return projection_status(
			signature
		)

	projection_work_by_signature [signature] = {
		"signature": signature,
		"runtime_ref": runtime,
		"actor_ref": actor,
		"actor_id": actor_id,
		"actor_override": actor != runtime.player,
		"interactive_surfaces_only": interactive_surfaces_only,
		"cursor": 0,
		"steps": projection_steps,
		"interactive_surface_order": (
			interactive_surface_order.duplicate(false)
		),
		"continuation_relationship_priority": (
			continuation_relationship_priority
		),
		"surface_contracts": (
			validated_persisted_surface_deck.duplicate(false)
		),
		"result": {
			"persisted_checkpoint_surface_packets_reused": (
				validated_persisted_surface_deck.keys()
			),
			"relationship_checkpoint_runtime_rebind_required": (
				checkpoint_resume_runtime
			),
			"relationship_saved_packet_is_presentation_seed_only": (
				checkpoint_resume_runtime
			),
			"continuation_relationship_priority": (
				continuation_relationship_priority
			),
		},
		"complete": false,
		"failed": false,
		"failure": {},
		"ready_signal_emitted": false,
		"started_at_ms": int(
			Time.get_ticks_msec()
		),
		"last_step_at_ms": 0,
		"context": context.duplicate(false)
	}

	return projection_status(
		signature
	)
func _run_projection_step_on_worker(
	step_id: String,
	runtime,
	work: Dictionary
) -> Dictionary:
	return _run_projection_step(
		step_id,
		runtime,
		work
	)
func _interactive_projection_stage_authority_descriptor(
	runtime,
	stage_id: String
) -> Dictionary:
	var clean_stage_id: String = str(
		stage_id
	).strip_edges().to_lower()

	if runtime == null:
		return {
			"stage_id": clean_stage_id,
			"authority": "",
			"authority_hot": false
		}

	match clean_stage_id:
		"mods":
			return {
				"stage_id": clean_stage_id,
				"authority": "ModMenuContractEngine",
				"authority_hot": (
					runtime.mod_menu_contract_engine != null
				)
			}

		"school":
			return {
				"stage_id": clean_stage_id,
				"authority": "SchoolHubContractEngine",
				"authority_hot": (
					runtime.school_hub_contract_engine != null
				)
			}

		"activities":
			return {
				"stage_id": clean_stage_id,
				"authority": "ActivitiesHubContractEngine",
				"authority_hot": (
					runtime.activities_hub_contract_engine != null
				)
			}

		"career":
			return {
				"stage_id": clean_stage_id,
				"authority": "CareerHubContractEngine",
				"authority_hot": (
					runtime.career_hub_contract_engine != null
				)
			}

		"relationships":
			return {
				"stage_id": clean_stage_id,
				"authority": "RelationshipsHubContractEngine",
				"authority_hot": (
					runtime.relationships_hub_contract_engine != null
				)
			}

		_:
			return {
				"stage_id": clean_stage_id,
				"authority": "RealityProjectionContractEngine",
				"authority_hot": true
			}


func promote_next_hot_interactive_stage(
	signature: String
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var work: Dictionary = _work(
		clean_signature
	)

	if work.is_empty():
		return {
			"success": false,
			"signature": clean_signature,
			"promoted": false,
			"reason": "projection_work_not_found"
		}

	if not bool(
		work.get(
			"interactive_surfaces_only",
			false
		)
	):
		return {
			"success": true,
			"signature": clean_signature,
			"promoted": false,
			"reason": "non_interactive_projection_order_preserved"
		}

	if bool(
		work.get(
			"complete",
			false
		)
	):
		return {
			"success": true,
			"signature": clean_signature,
			"promoted": false,
			"reason": "projection_complete"
		}



	var active_thread_raw: Variant = (
		projection_step_threads.get(
			clean_signature,
			null
		)
	)

	if active_thread_raw is Thread:
		return {
			"success": true,
			"signature": clean_signature,
			"promoted": false,
			"reason": "active_projection_worker_owns_cursor"
		}

	var runtime = work.get(
		"runtime_ref",
		null
	)
	var steps: Array = _array(
		work.get(
			"steps",
			[]
		)
	)
	var cursor: int = int(
		work.get(
			"cursor",
			0
		)
	)

	if (
		runtime == null
		or cursor < 0
		or cursor >= steps.size()
	):
		return {
			"success": true,
			"signature": clean_signature,
			"promoted": false,
			"reason": "no_pending_interactive_stage"
		}

	var emitted_registry: Dictionary = _dict(
		work.get(
			"surface_signal_emitted",
			{}
		)
	)
	var progressive_registry: Dictionary = _dict(
		work.get(
			"progressive_surface_signal_emitted",
			{}
		)
	)

	var current_stage_id: String = str(
		steps [
			cursor
		]
	).strip_edges().to_lower()
	var current_authority: Dictionary = (
		_interactive_projection_stage_authority_descriptor(
			runtime,
			current_stage_id
		)
	)
	var current_authority_hot: bool = bool(
		current_authority.get(
			"authority_hot",
			false
		)
	)
	var current_baseline_published: bool = (
		bool(
			emitted_registry.get(
				current_stage_id,
				false
			)
		)
		or bool(
			progressive_registry.get(
				current_stage_id,
				false
			)
		)
	)




	if (
		current_authority_hot
		and not current_baseline_published
	):
		return {
			"success": true,
			"signature": clean_signature,
			"promoted": false,
			"stage_id": current_stage_id,
			"authority": str(
				current_authority.get(
					"authority",
					""
				)
			),
			"authority_hot": true,
			"reason": "current_hot_stage_owns_first_packet"
		}

	var promoted_index: int = -1
	var promoted_stage_id: String = ""
	var promoted_authority: Dictionary = {}

	for candidate_index in range(
		cursor + 1,
		steps.size()
	):
		var candidate_stage_id: String = str(
			steps [
				candidate_index
			]
		).strip_edges().to_lower()

		if candidate_stage_id not in [
			"mods",
			"school",
			"activities",
			"career",
			"relationships"
		]:
			continue

		var candidate_baseline_published: bool = (
			bool(
				emitted_registry.get(
					candidate_stage_id,
					false
				)
			)
			or bool(
				progressive_registry.get(
					candidate_stage_id,
					false
				)
			)
		)

		if candidate_baseline_published:
			continue

		var candidate_authority: Dictionary = (
			_interactive_projection_stage_authority_descriptor(
				runtime,
				candidate_stage_id
			)
		)

		if not bool(
			candidate_authority.get(
				"authority_hot",
				false
			)
		):
			continue

		promoted_index = candidate_index
		promoted_stage_id = candidate_stage_id
		promoted_authority = candidate_authority
		break

	if promoted_index < 0:
		return {
			"success": true,
			"signature": clean_signature,
			"promoted": false,
			"stage_id": current_stage_id,
			"authority": str(
				current_authority.get(
					"authority",
					""
				)
			),
			"authority_hot": current_authority_hot,
			"reason": (
				"no_later_unpublished_hot_authority"
			)
		}

	var promoted_step: Variant = steps [
		promoted_index
	]
	steps.remove_at(
		promoted_index
	)
	steps.insert(
		cursor,
		promoted_step
	)

	work [
		"steps"
	] = steps
	work [
		"interactive_authority_promotion_count"
	] = int(
		work.get(
			"interactive_authority_promotion_count",
			0
		)
	) + 1
	work [
		"interactive_authority_last_promoted_stage"
	] = promoted_stage_id
	work [
		"interactive_authority_last_displaced_stage"
	] = current_stage_id
	work [
		"interactive_authority_last_promotion_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	work [
		"interactive_authority_promotion_waited_for_ui_idle"
	] = false
	work [
		"interactive_authority_promotion_required_full_engine_graph"
	] = false

	projection_work_by_signature [
		clean_signature
	] = work

	return {
		"success": true,
		"signature": clean_signature,
		"promoted": true,
		"stage_id": promoted_stage_id,
		"displaced_stage_id": current_stage_id,
		"authority": str(
			promoted_authority.get(
				"authority",
				""
			)
		),
		"authority_hot": true,
		"ready_gate_member": false
	}
func interactive_projection_stage_authority_status(
	signature: String
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var work: Dictionary = _work(
		clean_signature
	)

	if work.is_empty():
		return {
			"success": false,
			"signature": clean_signature,
			"stage_id": "",
			"authority_hot": false,
			"reason": "projection_work_not_found",
			"ready_gate_member": false
		}

	var runtime = work.get(
		"runtime_ref",
		null
	)
	var steps: Array = _array(
		work.get(
			"steps",
			[]
		)
	)
	var cursor: int = int(
		work.get(
			"cursor",
			0
		)
	)

	if (
		runtime == null
		or cursor < 0
		or cursor >= steps.size()
	):
		return {
			"success": true,
			"signature": clean_signature,
			"stage_id": "complete",
			"authority_hot": bool(
				work.get(
					"complete",
					false
				)
			),
			"projection_complete": bool(
				work.get(
					"complete",
					false
				)
			),
			"ready_gate_member": false
		}

	var stage_id: String = str(
		steps [
			cursor
		]
	).strip_edges().to_lower()
	var authority_descriptor: Dictionary = (
		_interactive_projection_stage_authority_descriptor(
			runtime,
			stage_id
		)
	)
	var authority_hot: bool = bool(
		authority_descriptor.get(
			"authority_hot",
			false
		)
	)
	var authority_name: String = str(
		authority_descriptor.get(
			"authority",
			""
		)
	)

	return {
		"success": true,
		"schema": (
			"eralife.interactive_projection_stage_authority_status"
		),
		"version": 1,
		"signature": clean_signature,
		"actor_id": int(
			work.get(
				"actor_id",
				-1
			)
		),
		"stage_id": stage_id,
		"authority": authority_name,
		"authority_hot": authority_hot,
		"projection_complete": bool(
			work.get(
				"complete",
				false
			)
		),
		"surface_authority_order_is_dynamic": true,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
func step_resident_projection(
	signature: String,
	max_steps: int = 1,
	frame_budget_ms: int = 2
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var work: Dictionary = _work(
		clean_signature
	)

	if work.is_empty():
		return _failure(
			"projection_work_not_found",
			{
				"signature": clean_signature
			}
		)

	if (
		bool(
			work.get(
				"complete",
				false
			)
		)
		or bool(
			work.get(
				"failed",
				false
			)
		)
	):
		return projection_status(
			clean_signature
		)

	var runtime = work.get(
		"runtime_ref",
		null
	)

	if (
		runtime == null
		or runtime.player == null
	):
		work ["failed"] = true
		work ["failure"] = {
			"reason": (
				"resident_projection_runtime_lost"
			)
		}
		projection_work_by_signature [
			clean_signature
		] = work
		_commit_state()

		return projection_status(
			clean_signature
		)

	var steps: Array = _array(
		work.get(
			"steps",
			[]
		)
	)
	var cursor: int = int(
		work.get(
			"cursor",
			0
		)
	)
	var started_ms: int = int(
		Time.get_ticks_msec()
	)
	var executed: int = 0
	var safe_max_steps: int = maxi(
		1,
		max_steps
	)
	var safe_budget_ms: int = maxi(
		1,
		frame_budget_ms
	)

	while (
		cursor < steps.size()
		and executed < safe_max_steps
	):
		if (
			executed > 0
			and (
				int(
					Time.get_ticks_msec()
				) - started_ms
			) >= safe_budget_ms
		):
			break

		var step_id: String = str(
			steps [cursor]
		).strip_edges().to_lower()
		var step_report: Dictionary = {}




		var detached_step_required: bool = true

		var active_thread_raw: Variant = (
			projection_step_threads.get(
				clean_signature,
				null
			)
		)

		if active_thread_raw is Thread:
			var active_thread: Thread = (
				active_thread_raw as Thread
			)
			var worker_context: Dictionary = _dict(
				projection_step_thread_context_by_signature.get(
					clean_signature,
					{}
				)
			)

			if active_thread.is_alive():
				work [
					"active_projection_step_id"
				] = str(
					worker_context.get(
						"step_id",
						step_id
					)
				)
				work [
					"active_projection_step_pending"
				] = true
				work [
					"active_projection_step_detached"
				] = true
				work [
					"projection_worker_renderer_thread_poll_only"
				] = true
				projection_work_by_signature [
					clean_signature
				] = work

				return projection_status(
					clean_signature
				)

			var worker_result_raw: Variant = (
				active_thread.wait_to_finish()
			)

			projection_step_threads.erase(
				clean_signature
			)
			projection_step_thread_context_by_signature.erase(
				clean_signature
			)

			var worker_step_id: String = str(
				worker_context.get(
					"step_id",
					""
				)
			)
			var worker_cursor: int = int(
				worker_context.get(
					"cursor",
					-1
				)
			)
			var worker_actor_id: int = int(
				worker_context.get(
					"actor_id",
					-1
				)
			)
			var current_actor_id: int = int(
				work.get(
					"actor_id",
					-1
				)
			)

			if (
				worker_step_id != step_id
				or worker_cursor != cursor
				or worker_actor_id != current_actor_id
			):
				work [
					"stale_projection_worker_result_discarded"
				] = true
				work [
					"stale_projection_worker_result_discarded_at_ms"
				] = int(
					Time.get_ticks_msec()
				)
				work [
					"active_projection_step_detached"
				] = false
				projection_work_by_signature [
					clean_signature
				] = work

				return projection_status(
					clean_signature
				)

			step_report = (
				worker_result_raw as Dictionary
				if typeof(
					worker_result_raw
				) == TYPE_DICTIONARY
				else {
					"success": false,
					"complete": false,
					"reason": (
						"projection_worker_return_invalid"
					),
					"step_id": step_id,
					"work": work
				}
			)

			work [
				"active_projection_step_detached"
			] = false
			work [
				"projection_worker_last_completed_at_ms"
			] = int(
				Time.get_ticks_msec()
			)

		elif detached_step_required:
			var worker:= Thread.new()
			var worker_error: int = worker.start(
				Callable(
					self,
					"_run_projection_step_on_worker"
				).bind(
					step_id,
					runtime,
					work.duplicate(false)
				),
				Thread.PRIORITY_LOW
			)

			if worker_error != OK:
				step_report = {
					"success": false,
					"complete": false,
					"reason": (
						"projection_worker_start_failed"
					),
					"worker_error": worker_error,
					"step_id": step_id,
					"work": work
				}
			else:
				projection_step_threads [
					clean_signature
				] = worker
				projection_step_thread_context_by_signature [
					clean_signature
				] = {
					"signature": clean_signature,
					"step_id": step_id,
					"cursor": cursor,
					"actor_id": int(
						work.get(
							"actor_id",
							-1
						)
					),
					"started_at_ms": int(
						Time.get_ticks_msec()
					),
					"worker_thread_used": true,
				}
				work [
					"active_projection_step_id"
				] = step_id
				work [
					"active_projection_step_pending"
				] = true
				work [
					"active_projection_step_detached"
				] = true
				work [
					"projection_worker_renderer_thread_poll_only"
				] = true
				projection_work_by_signature [
					clean_signature
				] = work

				return projection_status(
					clean_signature
				)

		else:
			step_report = (
				_run_projection_step(
					step_id,
					runtime,
					work
				)
			)

		if not bool(
			step_report.get(
				"success",
				false
			)
		):
			work ["failed"] = true
			work ["failure"] = (
				step_report.duplicate(false)
			)
			projection_work_by_signature [
				clean_signature
			] = work
			_commit_state()

			return projection_status(
				clean_signature
			)

		work = _dict(
			step_report.get(
				"work",
				work
			)
		)
		work ["last_step_at_ms"] = int(
			Time.get_ticks_msec()
		)

		executed += 1

		var step_complete: bool = bool(
			step_report.get(
				"complete",
				true
			)
		)

		if not step_complete:
			work ["cursor"] = cursor
			work [
				"active_projection_step_id"
			] = step_id
			work [
				"active_projection_step_pending"
			] = true
			work [
				"active_projection_step_progress"
			] = clampf(
				float(
					step_report.get(
						"progress",
						work.get(
							"active_surface_progress",
							0.0
						)
					)
				),
				0.0,
				0.999
			)
			work [
				"cooperative_projection_yield_count"
			] = int(
				work.get(
					"cooperative_projection_yield_count",
					0
				)
			) + 1
			work [
				"cooperative_projection_last_yield_at_ms"
			] = int(
				Time.get_ticks_msec()
			)
			projection_work_by_signature [
				clean_signature
			] = work

			break

		cursor += 1
		work ["cursor"] = cursor
		work [
			"active_projection_step_id"
		] = ""
		work [
			"active_projection_step_pending"
		] = false
		work [
			"active_projection_step_progress"
		] = 1.0

		if step_id in [
			"relationships",
			"school",
			"activities",
			"career",
			"mods"
		]:
			var surfaces: Dictionary = _dict(
				work.get(
					"surface_contracts",
					{}
				)
			)
			var surface_contract: Dictionary = _dict(
				surfaces.get(
					step_id,
					{}
				)
			)
			var emitted_registry: Dictionary = _dict(
				work.get(
					"surface_signal_emitted",
					{}
				)
			)

			if (
				not surface_contract.is_empty()
				and not bool(
					emitted_registry.get(
						step_id,
						false
					)
				)
			):
				emitted_registry [
					step_id
				] = true
				work [
					"surface_signal_emitted"
				] = emitted_registry

				var interactive_packets_complete: bool = true

				for required_surface_id in [
					"relationships",
					"school",
					"activities",
					"career",
					"mods"
				]:
					if not bool(
						emitted_registry.get(
							required_surface_id,
							false
						)
					):
						interactive_packets_complete = false
						break

				work [
					"interactive_surface_packets_complete"
				] = interactive_packets_complete
				work [
					"interactive_surface_packets_completed_at_ms"
				] = (
					int(
						Time.get_ticks_msec()
					)
					if interactive_packets_complete
					else 0
				)
				work [
					"surface_packets_are_immutable"
				] = true
				work [
					"surface_packet_recursive_copy_forbidden"
				] = true
				projection_work_by_signature [
					clean_signature
				] = work

				resident_surface_contract_ready.emit(
					clean_signature,
					step_id,
					surface_contract.duplicate(false)
				)

	var projection_became_ready: bool = false
	var completed_projection: Dictionary = {}

	if (
		cursor >= steps.size()
		and not bool(
			work.get(
				"failed",
				false
			)
		)
	):
		work ["complete"] = true
		completed_projection = _dict(
			work.get(
				"result",
				{}
			)
		)
		last_projection_by_signature [
			clean_signature
		] = completed_projection.duplicate(false)
		last_report = completed_projection.duplicate(false)

		_record(
			completed_projection
		)

		if not bool(
			work.get(
				"ready_signal_emitted",
				false
			)
		):
			work ["ready_signal_emitted"] = true
			projection_became_ready = true

	projection_work_by_signature [
		clean_signature
	] = work

	if (
		bool(
			work.get(
				"complete",
				false
			)
		)
		or bool(
			work.get(
				"failed",
				false
			)
		)
	):
		_commit_state()

	if (
		projection_became_ready
		and not completed_projection.is_empty()
	):
		resident_projection_ready.emit(
			clean_signature,
			completed_projection.duplicate(false)
		)

	return projection_status(
		clean_signature
	)
func interactive_surface_packets_ready(
	signature: String
) -> bool:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var work: Dictionary = _work(
		clean_signature
	)

	if work.is_empty():
		return false

	var actor_id: int = int(
		work.get(
			"actor_id",
			-1
		)
	)

	if actor_id <= 0:
		return false

	var surfaces_raw: Variant = work.get(
		"surface_contracts",
		{}
	)
	var surfaces: Dictionary = (
		surfaces_raw as Dictionary
		if typeof(surfaces_raw) == TYPE_DICTIONARY
		else {}
	)

	for raw_surface_id in [
		"relationships",
		"school",
		"activities",
		"career",
		"mods"
	]:
		var surface_id: String = str(
			raw_surface_id
		)
		var contract_raw: Variant = surfaces.get(
			surface_id,
			{}
		)
		var contract: Dictionary = (
			contract_raw as Dictionary
			if typeof(contract_raw) == TYPE_DICTIONARY
			else {}
		)

		if (
			contract.is_empty()
			or int(
				contract.get(
					"actor_id",
					-1
				)
			) != actor_id
		):
			return false

		var schema: String = str(
			contract.get(
				"schema",
				""
			)
		).strip_edges().to_lower()
		var truth_state: String = str(
			contract.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower()
		var projection_pending: bool = bool(
			contract.get(
				"projection_pending",
				false
			)
		)

		if (
			schema ==
				"eralife.pointer_only.destination_tab_contract"
			or truth_state ==
				"pointer_only_resident_shell"
			or bool(
				contract.get(
					"pointer_only",
					false
				)
			)
			or projection_pending
			or truth_state in [
				"warming",
				"streaming",
				"observable_partial",
				"partial",
				"pending"
			]
		):
			return false

		if (
			contract.has(
				"projection_complete"
			)
			and not bool(
				contract.get(
					"projection_complete",
					false
				)
			)
		):
			return false

	return true
func projection_status(
	signature: String
) -> Dictionary:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var work: Dictionary = _work(
		clean_signature
	)

	if work.is_empty():
		var cached: Dictionary = (
			projection_for_signature(
				clean_signature
			)
		)

		if not cached.is_empty():
			return {
				"success": bool(
					cached.get(
						"success",
						false
					)
				),
				"schema": ENGINE_SCHEMA,
				"version": ENGINE_VERSION,
				"signature": clean_signature,
				"actor_id": int(
					cached.get(
						"actor_id",
						-1
					)
				),
				"complete": true,
				"failed": not bool(
					cached.get(
						"success",
						false
					)
				),
				"progress": 1.0,
				"stage_id": "complete",
				"surface_contracts": _dict(
					cached.get(
						"surface_contracts",
						{}
					)
				),
				"projection_contract": (
					cached.duplicate(false)
				),
				"ui_is_renderer_only": true
			}

		return {
			"success": false,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"signature": clean_signature,
			"actor_id": -1,
			"complete": false,
			"failed": false,
			"progress": 0.0,
			"stage_id": "not_started",
			"surface_contracts": {},
			"interactive_surface_packets_complete": false,
			"ui_is_renderer_only": true
		}

	var steps: Array = _array(
		work.get(
			"steps",
			[]
		)
	)
	var cursor: int = int(
		work.get(
			"cursor",
			0
		)
	)
	var complete: bool = bool(
		work.get(
			"complete",
			false
		)
	)
	var failed: bool = bool(
		work.get(
			"failed",
			false
		)
	)
	var actor_id: int = int(
		work.get(
			"actor_id",
			-1
		)
	)
	var surface_contracts: Dictionary = _dict(
		work.get(
			"surface_contracts",
			{}
		)
	)
	var interactive_surface_packets_complete: bool = true

	for raw_surface_id in [
		"relationships",
		"school",
		"activities",
		"career",
		"mods"
	]:
		var surface_id: String = str(
			raw_surface_id
		)
		var surface_contract: Dictionary = _dict(
			surface_contracts.get(
				surface_id,
				{}
			)
		)
		var surface_schema: String = str(
			surface_contract.get(
				"schema",
				""
			)
		).strip_edges().to_lower()
		var truth_state: String = str(
			surface_contract.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower()

		if (
			surface_contract.is_empty()
			or int(
				surface_contract.get(
					"actor_id",
					-1
				)
			) != actor_id
			or surface_schema ==
				"eralife.pointer_only.destination_tab_contract"
			or truth_state == "pointer_only_resident_shell"
			or bool(
				surface_contract.get(
					"pointer_only",
					false
				)
			)
		):
			interactive_surface_packets_complete = false
			break

	var status_surface_contracts: Dictionary = (
		surface_contracts.duplicate(false)
		if complete
		else {}
	)

	var stage_id: String = "complete"

	if (
		not complete
		and cursor < steps.size()
	):
		stage_id = str(
			steps [cursor]
		)

	return {
		"success": not failed,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"signature": clean_signature,
		"actor_id": actor_id,
		"actor_override": bool(
			work.get(
				"actor_override",
				false
			)
		),
		"interactive_surfaces_only": bool(
			work.get(
				"interactive_surfaces_only",
				false
			)
		),
		"interactive_surface_packets_complete": (
			interactive_surface_packets_complete
		),
		"surface_contracts": status_surface_contracts,
		"surface_contracts_omitted_while_incomplete": not complete,
		"complete": complete,
		"failed": failed,
		"failure": _dict(
			work.get(
				"failure",
				{}
			)
		),
		"progress": (
			1.0
			if complete
			else (
				float(cursor)
				/ float(
					maxi(
						1,
						steps.size()
					)
				)
			)
		),
		"stage_id": stage_id,
		"projection_contract": _dict(
			work.get(
				"result",
				{}
			)
		),
		"started_at_ms": int(
			work.get(
				"started_at_ms",
				0
			)
		),
		"last_step_at_ms": int(
			work.get(
				"last_step_at_ms",
				0
			)
		),
		"ui_is_renderer_only": true
	}

func emit_resident_projection(
	runtime,
	context: Dictionary = {}
) -> Dictionary:
	var begin_report: Dictionary = (
		begin_resident_projection(
			runtime,
			context
		)
	)

	if not bool(
		begin_report.get(
			"success",
			false
		)
	):
		return begin_report

	var signature: String = str(
		begin_report.get(
			"signature",
			""
		)
	)

	for _step_index in range(16):
		var report: Dictionary = (
			step_resident_projection(
				signature,
				1,
				8
			)
		)

		if bool(
			report.get(
				"failed",
				false
			)
		):
			return report

		if bool(
			report.get(
				"complete",
				false
			)
		):
			return _dict(
				report.get(
					"projection_contract",
					{}
				)
			)

	return _failure(
		"projection_step_limit_reached",
		{
			"signature": signature,
			"maximum_steps": 16
		}
	)


func projection_for_signature(
	signature: String
) -> Dictionary:
	return _dict(
		last_projection_by_signature.get(
			str(
				signature
			).strip_edges(),
			{}
		)
	)


func _run_projection_step(
	step_id: String,
	runtime,
	work: Dictionary
) -> Dictionary:
	var actor = work.get(
		"actor_ref",
		runtime.player
	)

	if actor == null:
		return {
			"success": false,
			"complete": false,
			"reason": "projection_actor_reference_lost",
			"step_id": step_id,
			"work": work
		}

	var _actor_id: int = int(
		actor.id
	)
	var surfaces: Dictionary = _dict(
		work.get(
			"surface_contracts",
			{}
		)
	)
	var surface_contract: Dictionary = {}
	var progressive_registry: Dictionary = _dict(
		work.get(
			"progressive_surface_signal_emitted",
			{}
		)
	)
	var runtime_scenario: Dictionary = {}

	if (
		runtime != null
		and typeof(
			runtime.scenario_state
		) == TYPE_DICTIONARY
	):
		runtime_scenario = (
			runtime.scenario_state as Dictionary
		)

	var interactive_lens_has_absolute_priority: bool = (
		bool(
			runtime_scenario.get(
				"playable_life_shell_has_visible_sovereignty",
				false
			)
		)
		or bool(
			runtime_scenario.get(
				"playable_life_surface_has_visual_authority",
				false
			)
		)
		or bool(
			runtime_scenario.get(
				"birth_shell_player_control_released",
				false
			)
		)
		or bool(
			runtime_scenario.get(
				"spawn_ready_live_ui_shell_released",
				false
			)
		)
		or bool(
			runtime_scenario.get(
				"god_mode_ready_revealed_staged_surface",
				false
			)
		)
	)





	if (
		step_id == "relationships"
		and bool(
			progressive_registry.get(
				"relationships",
				false
			)
		)
		and interactive_lens_has_absolute_priority
	):
		work [
			"relationship_optional_projection_pending"
		] = true
		work [
			"relationship_optional_projection_continues_after_ready"
		] = true
		work [
			"relationship_optional_projection_one_group_per_service_quantum"
		] = true
		work [
			"relationship_optional_projection_ui_construction_forbidden"
		] = true
		work [
			"relationship_optional_projection_ready_gate_member"
		] = false
		work [
			"relationship_progressive_surface_remains_sovereign"
		] = true
		work [
			"relationship_final_enrichment_packet_may_merge_sections"
		] = true
		work [
			"interactive_input_has_absolute_priority"
		] = true

	match step_id:
		"career":
			surface_contract = _career_surface(
				runtime,
				actor
			)
		"activities":
			surface_contract = _activities_surface(
				runtime,
				actor
			)
		"mods":
			surface_contract = _mods_surface(
				runtime,
				actor
			)
		"school":
			surface_contract = _school_surface(
				runtime,
				actor
			)
		"relationships":
			surface_contract = _relationships_surface(
				runtime,
				actor
			)
		"life":
			surface_contract = _life_surface(
				runtime
			)
		"world":
			surface_contract = _world_surface(
				runtime
			)
		"graphs":
			work ["surface_contracts"] = surfaces
			work ["result"] = _seal_graphs(
				runtime,
				work
			)

			return {
				"success": bool(
					_dict(
						work.get(
							"result",
							{}
						)
					).get(
						"success",
						false
					)
				),
				"complete": true,
				"progress": 1.0,
				"work": work
			}
		_:
			return {
				"success": false,
				"complete": false,
				"reason": "unknown_projection_step",
				"step_id": step_id,
				"work": work
			}

	if bool(
		surface_contract.get(
			"projection_pending",
			false
		)
	):



		surfaces [
			step_id
		] = surface_contract
		work [
			"surface_contracts"
		] = surfaces
		work [
			"active_surface_step_id"
		] = step_id
		work [
			"active_surface_progress"
		] = clampf(
			float(
				surface_contract.get(
					"projection_progress",
					0.0
				)
			),
			0.0,
			0.999
		)
		work [
			"active_surface_status"
		] = surface_contract.duplicate(false)
		work [
			"surface_projection_is_cooperative"
		] = true
		work [
			"surface_projection_main_thread_monolith_forbidden"
		] = true
		work [
			"progressive_surface_packet_preserves_existing_cards"
		] = true
		work [
			"optional_projection_may_pause_for_interactive_lens"
		] = false
		work [
			"optional_projection_continues_without_ready_membership"
		] = true

		var groups: Array = _array(
			surface_contract.get(
				"groups",
				[]
			)
		)
		var section_contracts: Dictionary = _dict(
			surface_contract.get(
				"section_contracts",
				{}
			)
		)
		var renderable_partial: bool = (
			not groups.is_empty()
			or not section_contracts.is_empty()
		)

		if (
			renderable_partial
			and not bool(
				progressive_registry.get(
					step_id,
					false
				)
			)
		):
			progressive_registry [
				step_id
			] = true
			work [
				"progressive_surface_signal_emitted"
			] = progressive_registry
			work [
				"progressive_surface_first_packet_at_ms"
			] = int(
				Time.get_ticks_msec()
			)
			work [
				"progressive_surface_first_packet_id"
			] = step_id
			work [
				"progressive_surface_packet_is_interactive_baseline"
			] = true
			work [
				"progressive_surface_packet_may_not_be_erased"
			] = true
			work [
				"progressive_surface_packet_ready_gate_member"
			] = false

			call_deferred(
				"_emit_resident_surface_contract_packet",
				str(
					work.get(
						"signature",
						""
					)
				),
				step_id,
				surface_contract.duplicate(false)
			)

		return {
			"success": true,
			"complete": false,
			"progress": float(
				work.get(
					"active_surface_progress",
					0.0
				)
			),
			"work": work
		}

	surfaces [
		step_id
	] = surface_contract
	work [
		"surface_contracts"
	] = surfaces
	work [
		"active_surface_step_id"
	] = ""
	work [
		"active_surface_progress"
	] = 1.0
	work [
		"active_surface_status"
	] = {}

	if step_id == "relationships":
		work [
			"relationship_optional_projection_pending"
		] = false
		work [
			"relationship_optional_projection_complete"
		] = true
		work [
			"relationship_complete_section_deck_ready"
		] = true
		work [
			"relationship_complete_section_deck_ready_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

	return {
		"success": true,
		"complete": true,
		"progress": 1.0,
		"work": work
	}
func _emit_resident_surface_contract_packet(
	signature: String,
	surface_id: String,
	surface_contract: Dictionary
) -> void:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var clean_surface_id: String = str(
		surface_id
	).strip_edges().to_lower()

	if (
		clean_signature == ""
		or clean_surface_id == ""
		or surface_contract.is_empty()
	):
		return

	resident_surface_contract_ready.emit(
		clean_signature,
		clean_surface_id,
		surface_contract.duplicate(false)
	)
func _career_surface(
		runtime,
		actor
) -> Dictionary:
	var incarceration_surface: Dictionary = (
		_resident_incarceration_surface(
			runtime,
			actor,
			"career"
		)
	)

	if not incarceration_surface.is_empty():
		return incarceration_surface

	if (
		runtime != null
		and runtime.career_hub_contract_engine != null
		and runtime.career_hub_contract_engine.has_method(
			"resolve_career_hub"
		)
	):
		var contract: Dictionary = _dict(
			runtime.career_hub_contract_engine.resolve_career_hub(
				actor,
				{
					"active_section": "overview",
					"career_lane": "full_time",
					"force_refresh": false,
					"source": (
						"reality_projection_contract_engine"
					),
					"resident_projection": true,
					"build_on_click_forbidden": true,
					"ui_is_expression_only": true
				}
			)
		)

		if (
			not contract.is_empty()
			and bool(
				contract.get(
					"authoritative_projection",
					false
				)
			)
		):
			return contract

	return _surface_fallback(
		"career",
		int(
			actor.id
		)
	)
func _resident_incarceration_surface(
		runtime,
		actor,
		surface_id: String
) -> Dictionary:
	if (
		runtime == null
		or actor == null
	):
		return {}

	var actor_id: int = int(
		actor.id
	)
	var custody_contract: Dictionary = {}

	if (
		runtime.prison_engine != null
		and runtime.prison_engine.has_method(
			"resident_prison_reality_contract"
		)
	):
		custody_contract = _dict(
			runtime.prison_engine.call(
				"resident_prison_reality_contract",
				actor_id
			)
		)

	if (
		custody_contract.is_empty()
		and runtime.jail_engine != null
		and runtime.jail_engine.has_method(
			"resident_jail_reality_contract"
		)
	):
		custody_contract = _dict(
			runtime.jail_engine.call(
				"resident_jail_reality_contract",
				actor_id
			)
		)

	if custody_contract.is_empty():
		return {}

	var surface_contracts: Dictionary = _dict(
		custody_contract.get(
			"surface_contracts",
			{}
		)
	)
	var contract: Dictionary = _dict(
		surface_contracts.get(
			str(
				surface_id
			).strip_edges().to_lower(),
			{}
		)
	)

	if contract.is_empty():
		return {}




	contract ["incarceration_lens"] = {
		"schema": "eralife.incarceration_lens_contract",
		"version": 2,
		"actor_id": actor_id,
		"active": true,
		"incarceration_kind": str(
			custody_contract.get(
				"incarceration_kind",
				""
			)
		),
		"navigation_labels": _dict(
			custody_contract.get(
				"navigation_labels",
				{}
			)
		),
		"facility_surface_contract": _dict(
			custody_contract.get(
				"facility_surface_contract",
				{}
			)
		),
		"sentence_surface_contract": _dict(
			custody_contract.get(
				"sentence_surface_contract",
				{}
			)
		),
		"nearby_prisoner_cards": _array(
			custody_contract.get(
				"nearby_prisoner_cards",
				[]
			)
		),
		"other_facility_cards": _array(
			custody_contract.get(
				"other_facility_cards",
				[]
			)
		),
		"truth_state": "hot",
		"projection_complete": true,
		"ui_is_renderer_only": true
	}
	contract ["incarceration_mode"] = true
	contract ["free_world_surface_suppressed"] = true

	return contract.duplicate(false)
func _activities_surface(
		runtime,
		actor
) -> Dictionary:
	var incarceration_surface: Dictionary = (
		_resident_incarceration_surface(
			runtime,
			actor,
			"activities"
		)
	)

	if not incarceration_surface.is_empty():
		return incarceration_surface

	if (
		runtime != null
		and runtime.activities_hub_contract_engine != null
		and runtime.activities_hub_contract_engine.has_method(
			"emit_hub_contract"
		)
	):
		var contract: Dictionary = _dict(
			runtime.activities_hub_contract_engine.emit_hub_contract(
				actor,
				{
					"active_section": "all",
					"force_refresh": false,
					"source": (
						"reality_projection_contract_engine"
					),
					"resident_projection": true,
					"build_on_click_forbidden": true,
					"ui_is_expression_only": true
				}
			)
		)

		if (
			not contract.is_empty()
			and bool(
				contract.get(
					"authoritative_projection",
					contract.get(
						"projection_complete",
						false
					)
				)
			)
		):
			return contract

	return _surface_fallback(
		"activities",
		int(
			actor.id
		)
	)


func _mods_surface(
	runtime,
	actor
) -> Dictionary:
	if (
		runtime != null
		and runtime.mod_menu_contract_engine != null
		and runtime.mod_menu_contract_engine.has_method(
			"emit_menu_contract"
		)
	):
		var contract: Dictionary = _dict(
			runtime.mod_menu_contract_engine.emit_menu_contract(
				actor,
				{
					"active_section": "bundles",
					"force_refresh": false,
					"surface_mode": "global_hub",
					"source": (
						"reality_projection_contract_engine"
					),
					"resident_projection": true,
					"default_reality_bundle_id": (
						"caveman_reality_pack"
					),
					"section_press_reveal_only": true,
					"build_on_click_forbidden": true,
					"ui_is_expression_only": true
				}
			)
		)

		if (
			not contract.is_empty()
			and bool(
				contract.get(
					"authoritative_projection",
					true
				)
			)
		):
			contract [
				"active_section"
			] = "bundles"
			contract [
				"default_section"
			] = "bundles"
			contract [
				"section_press_reveal_only"
			] = true
			contract [
				"immutable_surface_contract"
			] = true

			return contract

	return _surface_fallback(
		"mods",
		int(
			actor.id
		)
	)

func _school_surface(
	runtime,
	actor
) -> Dictionary:
	var incarceration_surface: Dictionary = (
		_resident_incarceration_surface(
			runtime,
			actor,
			"school"
		)
	)

	if not incarceration_surface.is_empty():
		return incarceration_surface

	if (
		runtime != null
		and runtime.school_hub_contract_engine != null
		and runtime.school_hub_contract_engine.has_method(
			"emit_hub_contract"
		)
	):
		var contract: Dictionary = _dict(
			runtime.school_hub_contract_engine.emit_hub_contract(
				actor,
				{
					"active_section_id": "overview",
					"force_refresh": false,
					"source": (
						"reality_projection_contract_engine"
					),
					"resident_projection": true,
					"projection_read_only": true,
					"build_on_click_forbidden": true,
					"ready_gate_member": false,
					"ui_is_expression_only": true
				}
			)
		)




		if (
			not contract.is_empty()
			and bool(
				contract.get(
					"authoritative_projection",
					false
				)
			)
		):
			return contract

	return _surface_fallback(
		"school",
		int(
			actor.id
		)
	)
func _resident_relationship_temporal_age_truth_pending(runtime) -> bool:
	if runtime == null:
		return false

	if typeof(runtime.scenario_state) != TYPE_DICTIONARY:
		return false

	var scenario_state: Dictionary = (
		runtime.scenario_state as Dictionary
	)
	var current_year: int = int(
		runtime.year
	)
	var refresh_year: int = int(
		scenario_state.get(
			"age_up_relationship_lenses_refresh_year",
			-999999
		)
	)



	if refresh_year != current_year:
		return false

	var report: Dictionary = _dict(
		scenario_state.get(
			"last_world_engine_age_npcs_report",
			{}
		)
	)
	var age_truth_complete: bool = (
		str(
			report.get(
				"schema",
				""
			)
		).strip_edges()
		== "eralife.world_engine_age_npcs_report"
		and str(
			report.get(
				"authority",
				""
			)
		).strip_edges()
		== "world_engine"
		and str(
			report.get(
				"task",
				""
			)
		).strip_edges()
		== "age_npcs"
		and int(
			report.get(
				"year",
				-999999
			)
		) == current_year
		and bool(
			report.get(
				"is_complete",
				false
			)
		)
		and bool(
			report.get(
				"completion_receipt",
				false
			)
		)
	)

	return not age_truth_complete
func _relationships_surface(
	runtime,
	actor,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _surface_fallback(
			"relationships",
			-1
		)

	var incarceration_surface: Dictionary = (
		_resident_incarceration_surface(
			runtime,
			actor,
			"relationships"
		)
	)

	if not incarceration_surface.is_empty():
		return incarceration_surface

	if (
		runtime != null
		and runtime.relationships_hub_contract_engine != null
		and runtime.relationships_hub_contract_engine.has_method(
			"emit_hub_contract"
		)
	):
		var active_section_id: String = str(
			context.get(
				"active_section_id",
				context.get(
					"preferred_section_id",
					"family"
				)
			)
		).strip_edges().to_lower()

		if active_section_id == "":
			active_section_id = "family"

		var runtime_scenario: Dictionary = {}

		if typeof(
			runtime.scenario_state
		) == TYPE_DICTIONARY:
			runtime_scenario = (
				runtime.scenario_state as Dictionary
			)

		var checkpoint_resume_relationship_priority: bool = (
			bool(
				runtime_scenario.get(
					"checkpoint_resume_not_birth",
					false
				)
			)
			or bool(
				runtime_scenario.get(
					"resident_runtime_restored_from_checkpoint",
					false
				)
			)
		)
		var afterlife_continuation_relationship_priority: bool = (
			bool(
				runtime.afterlife_active
			)
			and runtime.player != null
			and int(
				actor.id
			) != int(
				runtime.player.id
			)
		)
		var continuation_relationship_priority: bool = (
			checkpoint_resume_relationship_priority
			or afterlife_continuation_relationship_priority
			or bool(
				context.get(
					"continuation_relationship_priority",
					false
				)
			)
		)
		var projection_context: Dictionary = {
			"active_section_id": active_section_id,
			"force_refresh": bool(
				context.get(
					"force_refresh",
					false
				)
			),
			"source": str(
				context.get(
					"source",
					"reality_projection_contract_engine"
				)
			),
			"relationship_priority": (
				continuation_relationship_priority
			),
			"top_priority": (
				continuation_relationship_priority
			),
			"checkpoint_resume_relationship_priority": (
				checkpoint_resume_relationship_priority
			),
			"afterlife_continuation_relationship_priority": (
				afterlife_continuation_relationship_priority
			),
			"resident_projection": true,
			"cooperative_projection": true,
			"projection_read_only": true,
			"publish_card_shell_to_scenario": false,
			"build_on_click_forbidden": true,
			"ready_gate_member": false,
			"ui_is_expression_only": true,
			"background_only": bool(
				context.get(
					"background_only",
					false
				)
			),
			"ui_interaction_grace_ignored": bool(
				context.get(
					"ui_interaction_grace_ignored",
					false
				)
			)
		}

		var contract: Dictionary = _dict(
			runtime.relationships_hub_contract_engine.emit_hub_contract(
				actor,
				projection_context
			)
		)

		if contract.is_empty():
			return _surface_fallback(
				"relationships",
				int(
					actor.id
				)
			)

		var stream_section_id: String = str(
			contract.get(
				"stream_section_id",
				""
			)
		).strip_edges().to_lower()
		var stream_section_contract: Dictionary = _dict(
			contract.get(
				"stream_section_contract",
				{}
			)
		)

		if (
			stream_section_id != ""
			and not stream_section_contract.is_empty()





			and not bool(
				context.get(
					"process_frame_serviced",
					false
				)
			)





			and not _resident_relationship_temporal_age_truth_pending(
				runtime
			)
		):
			var residency_signature: String = (
				_runtime_signature(
					runtime
				)
			)
			var stream_revision: String = str(
				stream_section_contract.get(
					"surface_revision",
					""
				)
			)
			var stream_packet_key: String = (
				"%s:%d:%s:%s"
				% [
					residency_signature,
					int(
						actor.id
					),
					stream_section_id,
					stream_revision
				]
			)

			if str(
				get_meta(
					"resident_relationship_section_packet_last_key",
					""
				)
			) != stream_packet_key:
				set_meta(
					"resident_relationship_section_packet_last_key",
					stream_packet_key
				)






				call_deferred(
					"_emit_resident_relationship_section_contract_packet",
					residency_signature,
					int(
						actor.id
					),
					stream_section_id,
					stream_section_contract.duplicate(false)
				)

		if bool(
			contract.get(
				"projection_pending",
				false
			)
		):
			return contract

		if bool(
			contract.get(
				"projection_complete",
				contract.get(
					"authoritative_projection",
					false
				)
			)
		):
			return contract

	return _surface_fallback(
		"relationships",
		int(
			actor.id
		)
	)
func _emit_resident_relationship_section_contract_packet(
	signature: String,
	actor_id: int,
	section_id: String,
	section_contract: Dictionary
) -> void:
	var clean_signature: String = str(
		signature
	).strip_edges()
	var clean_section_id: String = str(
		section_id
	).strip_edges().to_lower()

	if (
		clean_signature == ""
		or actor_id <= 0
		or clean_section_id == ""
		or section_contract.is_empty()
	):
		return

	resident_relationship_section_contract_ready.emit(
		clean_signature,
		actor_id,
		clean_section_id,
		section_contract.duplicate(false)
	)
func queue_resident_relationship_section_refresh(
	actor_id: int,
	section_ids: Array,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor_id <= 0
	):
		return {
			"success": false,
			"reason": "missing_game_state_or_actor",
			"actor_id": actor_id
		}

	var order_raw: Variant = get_meta(
		"resident_relationship_section_refresh_order",
		[]
	)

	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)

	var jobs_raw: Variant = get_meta(
		"resident_relationship_section_refresh_jobs",
		{}
	)

	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(jobs_raw) == TYPE_DICTIONARY
		else {}
	)




	var refresh_sequence: int = int(
		get_meta(
			"resident_relationship_projection_refresh_sequence",
			0
		)
	) + 1

	set_meta(
		"resident_relationship_projection_refresh_sequence",
		refresh_sequence
	)

	var request_reality_revision: String = str(
		context.get(
			"reality_revision",
			""
		)
	).strip_edges()

	if request_reality_revision == "":
		request_reality_revision = (
			"relationship_refresh:%d:%d:%d"
			% [
				actor_id,
				int(
					gs.year
				),
				refresh_sequence
			]
		)

	var queued_sections: Array = []

	for raw_section_id in section_ids:
		var section_id: String = str(
			raw_section_id
		).strip_edges().to_lower()

		if section_id == "":
			continue

		var request_key: String = (
			"%d:%s"
			% [
				actor_id,
				section_id
			]
		)

		var refresh_context: Dictionary = (
			context.duplicate(false)
		)

		refresh_context [
			"active_section_id"
		] = section_id

		refresh_context [
			"preferred_section_id"
		] = section_id

		refresh_context [
			"force_refresh"
		] = true

		refresh_context [
			"reality_revision"
		] = request_reality_revision

		refresh_context [
			"relationship_projection_refresh_sequence"
		] = refresh_sequence

		refresh_context [
			"background_only"
		] = true

		refresh_context [
			"blocks_ui"
		] = false

		refresh_context [
			"ui_interaction_grace_ignored"
		] = true

		refresh_context [
			"build_on_click_forbidden"
		] = true

		refresh_context [
			"ready_gate_member"
		] = false

		jobs [
			request_key
		] = {
			"request_key": request_key,
			"actor_id": actor_id,
			"section_id": section_id,
			"context": refresh_context,
			"reality_revision": request_reality_revision,
			"relationship_projection_refresh_sequence": refresh_sequence,
			"requested_at_ms": int(
				Time.get_ticks_msec()
			)
		}

		if not order.has(
			request_key
		):
			order.append(
				request_key
			)

		if not queued_sections.has(
			section_id
		):
			queued_sections.append(
				section_id
			)

	set_meta(
		"resident_relationship_section_refresh_order",
		order
	)

	set_meta(
		"resident_relationship_section_refresh_jobs",
		jobs
	)

	set_meta(
		"resident_relationship_section_refresh_requires_input_idle",
		false
	)

	set_meta(
		"resident_relationship_section_refresh_last_reality_revision",
		request_reality_revision
	)

	_arm_resident_relationship_section_refresh_service()

	return {
		"success": true,
		"queued": not queued_sections.is_empty(),
		"actor_id": actor_id,
		"section_ids": queued_sections,
		"queue_size": order.size(),
		"reality_revision": request_reality_revision,
		"relationship_projection_refresh_sequence": refresh_sequence,
		"background_only": true,
		"blocks_ui": false,
		"requires_input_idle": false,
		"render_boundary_required": false,
		"process_frame_serviced": true,
		"ready_gate_member": false
	}
func _arm_resident_relationship_section_refresh_service() -> void:
	var order_raw: Variant = get_meta(
		"resident_relationship_section_refresh_order",
		[]
	)

	var order: Array = (
		order_raw as Array
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)

	if order.is_empty():
		set_meta(
			"resident_relationship_section_refresh_service_active",
			false
		)
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		set_meta(
			"resident_relationship_section_refresh_service_active",
			false
		)
		return

	var callback:= Callable(
		self,
		"_drive_resident_relationship_section_refresh_process_frame"
	)

	if tree.process_frame.is_connected(
		callback
	):
		set_meta(
			"resident_relationship_section_refresh_service_active",
			true
		)
		return

	tree.process_frame.connect(
		callback
	)

	set_meta(
		"resident_relationship_section_refresh_service_active",
		true
	)


func _drive_resident_relationship_section_refresh_process_frame() -> void:
	var tree:= Engine.get_main_loop() as SceneTree

	var callback:= Callable(
		self,
		"_drive_resident_relationship_section_refresh_process_frame"
	)

	if (
		tree != null
		and tree.process_frame.is_connected(
			callback
		)
	):
		tree.process_frame.disconnect(
			callback
		)

	set_meta(
		"resident_relationship_section_refresh_service_active",
		false
	)

	_service_resident_relationship_section_refresh_queue()
func _service_resident_relationship_section_refresh_queue() -> void:
	var order_raw: Variant = get_meta(
		"resident_relationship_section_refresh_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)

	if order.is_empty():
		set_meta(
			"resident_relationship_section_refresh_service_active",
			false
		)
		return

	var request_key: String = str(
		order.pop_front()
	)
	var jobs_raw: Variant = get_meta(
		"resident_relationship_section_refresh_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(jobs_raw) == TYPE_DICTIONARY
		else {}
	)
	var job_raw: Variant = jobs.get(
		request_key,
		{}
	)

	jobs.erase(
		request_key
	)

	set_meta(
		"resident_relationship_section_refresh_order",
		order
	)
	set_meta(
		"resident_relationship_section_refresh_jobs",
		jobs
	)

	if typeof(job_raw) != TYPE_DICTIONARY:
		_arm_resident_relationship_section_refresh_service()
		return

	var job: Dictionary = (
		job_raw as Dictionary
	)
	var actor_id: int = int(
		job.get(
			"actor_id",
			-1
		)
	)
	var section_id: String = str(
		job.get(
			"section_id",
			""
		)
	).strip_edges().to_lower()
	var actor: Person = (
		_resident_relationship_projection_actor_by_id(
			actor_id
		)
	)

	if (
		actor == null
		or section_id == ""
	):
		_arm_resident_relationship_section_refresh_service()
		return

	var refresh_context: Dictionary = _dict(
		job.get(
			"context",
			{}
		)
	)
	var force_refresh_this_quantum: bool = bool(
		refresh_context.get(
			"force_refresh",
			true
		)
	)

	refresh_context [
		"active_section_id"
	] = section_id
	refresh_context [
		"preferred_section_id"
	] = section_id
	refresh_context [
		"force_refresh"
	] = force_refresh_this_quantum
	refresh_context [
		"resident_projection"
	] = true
	refresh_context [
		"cooperative_projection"
	] = true
	refresh_context [
		"projection_read_only"
	] = true
	refresh_context [
		"background_only"
	] = true
	refresh_context [
		"ui_interaction_grace_ignored"
	] = true
	refresh_context [
		"build_on_click_forbidden"
	] = true
	refresh_context [
		"ready_gate_member"
	] = false
	refresh_context [
		"render_boundary_required"
	] = false
	refresh_context [
		"process_frame_serviced"
	] = true

	var surface_contract: Dictionary = (
		_relationships_surface(
			gs,
			actor,
			refresh_context
		)
	)
	var section_contracts: Dictionary = _dict(
		surface_contract.get(
			"section_contracts",
			{}
		)
	)
	var section_contract: Dictionary = _dict(
		section_contracts.get(
			section_id,
			{}
		)
	)

	if (
		section_contract.is_empty()
		and str(
			surface_contract.get(
				"active_section_id",
				""
			)
		).strip_edges().to_lower()
		== section_id
		and bool(
			surface_contract.get(
				"section_projection_complete",
				false
			)
		)
	):
		section_contract = (
			surface_contract.duplicate(false)
		)

	var section_projection_complete: bool = false
	if not section_contract.is_empty():
		section_projection_complete = bool(
			section_contract.get(
				"section_projection_complete",
				section_contract.get(
					"projection_complete",
					false
				)
			)
		)
		resident_relationship_section_contract_ready.emit(
			_runtime_signature(
				gs
			),
			actor_id,
			section_id,
			section_contract.duplicate(false)
		)






	if (
		not section_contract.is_empty()
		and not section_projection_complete
	):
		var continuation_context: Dictionary = (
			refresh_context.duplicate(false)
		)
		continuation_context [
			"force_refresh"
		] = false
		continuation_context [
			"resident_refresh_continuation"
		] = true
		continuation_context [
			"resident_refresh_initial_generation_invalidated"
		] = true

		var continuation_job: Dictionary = (
			job.duplicate(false)
		)
		continuation_job [
			"context"
		] = continuation_context
		continuation_job [
			"continued_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		jobs [
			request_key
		] = continuation_job
		if not order.has(
			request_key
		):
			order.append(
				request_key
			)

		set_meta(
			"resident_relationship_section_refresh_order",
			order
		)
		set_meta(
			"resident_relationship_section_refresh_jobs",
			jobs
		)

	set_meta(
		"resident_relationship_section_refresh_last_actor_id",
		actor_id
	)
	set_meta(
		"resident_relationship_section_refresh_last_section_id",
		section_id
	)
	set_meta(
		"resident_relationship_section_refresh_last_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"resident_relationship_section_refresh_last_blocks_ui",
		false
	)
	set_meta(
		"resident_relationship_section_refresh_last_render_boundary_used",
		false
	)
	set_meta(
		"resident_relationship_section_refresh_last_section_complete",
		section_projection_complete
	)
	set_meta(
		"resident_relationship_section_refresh_last_force_refresh",
		force_refresh_this_quantum
	)




	_arm_resident_relationship_section_refresh_service()
func yearly_school_surface_refresh(
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or gs.player == null
	):
		return {
			"success": false,
			"queued": false,
			"reason": "controlled_actor_unavailable",
			"is_complete": true,
			"progress": 1.0,
			"blocks_ui": false,
			"requires_input_idle": false
		}

	var actor_id: int = int(
		gs.player.id
	)
	var target_year: int = int(
		payload.get(
			"year",
			gs.year
		)
	)

	if actor_id <= 0:
		return {
			"success": false,
			"queued": false,
			"reason": "controlled_actor_id_unavailable",
			"is_complete": true,
			"progress": 1.0,
			"blocks_ui": false,
			"requires_input_idle": false
		}

	if not gs.player.alive:
		return {
			"success": true,
			"queued": false,
			"reason": "controlled_actor_not_alive",
			"actor_id": actor_id,
			"target_year": target_year,
			"is_complete": true,
			"progress": 1.0,
			"blocks_ui": false,
			"requires_input_idle": false
		}

	var queue_report: Dictionary = (
		queue_resident_temporal_surface_refresh(
			actor_id,
			[
				"school"
			],
			{
				"source": (
					"reality_projection_contract_engine."
					+ "yearly_school_surface_refresh"
				),
				"reason": (
					"school_engine_yearly_truth_committed"
				),
				"target_year": target_year,
				"school_truth_dependency_committed": true,
				"background_only": true,
				"blocks_ui": false,
				"requires_input_idle": false,
				"ui_interaction_grace_ignored": true,
				"build_on_click_forbidden": true,
				"render_boundary_required": false,
				"ready_gate_member": false,
				"projection_read_only": true
			}
		)
	)

	queue_report [
		"is_complete"
	] = true
	queue_report [
		"progress"
	] = 1.0
	queue_report [
		"yearly_listener_constant_time"
	] = true
	queue_report [
		"school_truth_dependency_committed"
	] = true
	queue_report [
		"school_projection_authored_off_click_path"
	] = true
	queue_report [
		"school_projection_requires_observation"
	] = false
	queue_report [
		"school_projection_requires_entity_switch"
	] = false

	return queue_report
func queue_resident_temporal_surface_refresh(
	actor_id: int,
	surface_ids: Array,
	context: Dictionary = {}
) -> Dictionary:
	if (
		gs == null
		or actor_id <= 0
	):
		return {
			"success": false,
			"queued": false,
			"reason": "missing_game_state_or_actor",
			"actor_id": actor_id,
			"blocks_ui": false
		}

	var signature: String = str(
		context.get(
			"signature",
			_runtime_signature(gs)
		)
	).strip_edges()

	if signature == "":
		return {
			"success": false,
			"queued": false,
			"reason": "missing_resident_reality_signature",
			"actor_id": actor_id,
			"blocks_ui": false
		}

	var order_raw: Variant = get_meta(
		"resident_temporal_surface_refresh_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)
	var jobs_raw: Variant = get_meta(
		"resident_temporal_surface_refresh_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(jobs_raw) == TYPE_DICTIONARY
		else {}
	)
	var refresh_sequence: int = int(
		get_meta(
			"resident_temporal_surface_refresh_sequence",
			0
		)
	) + 1

	set_meta(
		"resident_temporal_surface_refresh_sequence",
		refresh_sequence
	)

	var queued_surfaces: Array = []
	var rejected_surfaces: Array = []
	var allowed_surface_ids: Array = [
		"activities",
		"career",
		"school",
		"mods"
	]

	for raw_surface_id in surface_ids:
		var surface_id: String = str(
			raw_surface_id
		).strip_edges().to_lower()

		if surface_id == "":
			continue



		if not allowed_surface_ids.has(surface_id):
			if not rejected_surfaces.has(surface_id):
				rejected_surfaces.append(surface_id)
			continue

		var request_key: String = (
			"%s:%d:%s:%d"
			% [
				signature,
				actor_id,
				surface_id,
				refresh_sequence
			]
		)
		var refresh_context: Dictionary = context.duplicate(false)
		refresh_context ["background_only"] = true
		refresh_context ["blocks_ui"] = false
		refresh_context ["requires_input_idle"] = false
		refresh_context ["ui_interaction_grace_ignored"] = true
		refresh_context ["build_on_click_forbidden"] = true
		refresh_context ["render_boundary_required"] = false
		refresh_context ["ready_gate_member"] = false
		refresh_context ["projection_read_only"] = true
		refresh_context ["temporal_successor_refresh"] = true

		jobs [request_key] = {
			"request_key": request_key,
			"signature": signature,
			"actor_id": actor_id,
			"surface_id": surface_id,
			"context": refresh_context,
			"refresh_sequence": refresh_sequence,
			"requested_world_year": int(
				context.get(
					"target_year",
					gs.year
				)
			),
			"retry_count": 0,
			"requested_at_ms": int(Time.get_ticks_msec()),
			"background_only": true,
			"blocks_ui": false,
		}
		order.append(request_key)

		if not queued_surfaces.has(surface_id):
			queued_surfaces.append(surface_id)

	set_meta(
		"resident_temporal_surface_refresh_order",
		order
	)
	set_meta(
		"resident_temporal_surface_refresh_jobs",
		jobs
	)
	set_meta(
		"resident_temporal_surface_refresh_requires_input_idle",
		false
	)
	set_meta(
		"resident_temporal_surface_refresh_renderer_thread_authoring_forbidden",
		true
	)

	_arm_resident_temporal_surface_refresh_service()

	return {
		"success": not queued_surfaces.is_empty(),
		"queued": not queued_surfaces.is_empty(),
		"actor_id": actor_id,
		"surface_ids": queued_surfaces,
		"rejected_surface_ids": rejected_surfaces,
		"queue_size": order.size(),
		"signature": signature,
		"refresh_sequence": refresh_sequence,
		"background_only": true,
		"blocks_ui": false,
		"requires_input_idle": false,
		"render_boundary_required": false,
		"ready_gate_member": false,
		"renderer_thread_poll_only": true
	}


func _arm_resident_temporal_surface_refresh_service() -> void:
	var order_raw: Variant = get_meta(
		"resident_temporal_surface_refresh_order",
		[]
	)
	var order: Array = (
		order_raw as Array
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)
	var active_thread_raw: Variant = get_meta(
		"resident_temporal_surface_refresh_thread",
		null
	)

	if (
		order.is_empty()
		and not (active_thread_raw is Thread)
	):
		set_meta(
			"resident_temporal_surface_refresh_service_active",
			false
		)
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		set_meta(
			"resident_temporal_surface_refresh_service_active",
			false
		)
		return

	var callback:= Callable(
		self,
		"_drive_resident_temporal_surface_refresh_process_frame"
	)

	if tree.process_frame.is_connected(callback):
		set_meta(
			"resident_temporal_surface_refresh_service_active",
			true
		)
		return

	tree.process_frame.connect(callback)
	set_meta(
		"resident_temporal_surface_refresh_service_active",
		true
	)


func _drive_resident_temporal_surface_refresh_process_frame() -> void:
	var tree:= Engine.get_main_loop() as SceneTree
	var callback:= Callable(
		self,
		"_drive_resident_temporal_surface_refresh_process_frame"
	)

	if (
		tree != null
		and tree.process_frame.is_connected(callback)
	):
		tree.process_frame.disconnect(callback)

	set_meta(
		"resident_temporal_surface_refresh_service_active",
		false
	)

	_service_resident_temporal_surface_refresh_queue()


func _build_resident_temporal_surface_successor_on_worker(
	surface_id: String,
	runtime,
	actor
) -> Dictionary:
	var clean_surface_id: String = str(
		surface_id
	).strip_edges().to_lower()
	var surface_contract: Dictionary = {}

	match clean_surface_id:
		"activities":
			surface_contract = _activities_surface(
				runtime,
				actor
			)
		"career":
			surface_contract = _career_surface(
				runtime,
				actor
			)
		"school":
			surface_contract = _school_surface(
				runtime,
				actor
			)
		"mods":
			surface_contract = _mods_surface(
				runtime,
				actor
			)
		_:
			return {
				"success": false,
				"complete": true,
				"reason": "unsupported_temporal_surface",
				"surface_id": clean_surface_id,
				"surface_contract": {},
				"blocks_ui": false
			}

	var projection_pending: bool = bool(
		surface_contract.get(
			"projection_pending",
			false
		)
	)

	return {
		"success": not surface_contract.is_empty(),
		"complete": (
			not surface_contract.is_empty()
			and not projection_pending
		),
		"surface_id": clean_surface_id,
		"surface_contract": surface_contract,
		"projection_pending": projection_pending,
		"blocks_ui": false
	}


func _service_resident_temporal_surface_refresh_queue() -> void:
	var active_thread_raw: Variant = get_meta(
		"resident_temporal_surface_refresh_thread",
		null
	)
	var worker_context_raw: Variant = get_meta(
		"resident_temporal_surface_refresh_thread_context",
		{}
	)
	var worker_context: Dictionary = (
		(worker_context_raw as Dictionary).duplicate(false)
		if typeof(worker_context_raw) == TYPE_DICTIONARY
		else {}
	)

	if active_thread_raw is Thread:
		var active_thread: Thread = active_thread_raw as Thread

		if active_thread.is_alive():
			set_meta(
				"resident_temporal_surface_refresh_renderer_thread_poll_only",
				true
			)
			_arm_resident_temporal_surface_refresh_service()
			return



		var worker_result_raw: Variant = active_thread.wait_to_finish()
		var completed_request_key: String = str(
			worker_context.get(
				"request_key",
				""
			)
		)
		var completed_signature: String = str(
			worker_context.get(
				"signature",
				""
			)
		).strip_edges()
		var completed_surface_id: String = str(
			worker_context.get(
				"surface_id",
				""
			)
		).strip_edges().to_lower()
		var completed_actor_id: int = int(
			worker_context.get(
				"actor_id",
				-1
			)
		)

		set_meta(
			"resident_temporal_surface_refresh_thread",
			null
		)
		set_meta(
			"resident_temporal_surface_refresh_thread_context",
			{}
		)

		var completed_jobs_raw: Variant = get_meta(
			"resident_temporal_surface_refresh_jobs",
			{}
		)
		var completed_jobs: Dictionary = (
			(completed_jobs_raw as Dictionary).duplicate(false)
			if typeof(completed_jobs_raw) == TYPE_DICTIONARY
			else {}
		)
		var worker_result: Dictionary = (
			(worker_result_raw as Dictionary).duplicate(false)
			if typeof(worker_result_raw) == TYPE_DICTIONARY
			else {}
		)
		var surface_contract: Dictionary = _dict(
			worker_result.get(
				"surface_contract",
				{}
			)
		)
		var worker_success: bool = bool(
			worker_result.get(
				"success",
				false
			)
		)
		var worker_complete: bool = bool(
			worker_result.get(
				"complete",
				false
			)
		)
		var packet_valid: bool = (
			worker_success
			and worker_complete
			and completed_signature != ""
			and completed_surface_id != ""
			and not surface_contract.is_empty()
			and int(
				surface_contract.get(
					"actor_id",
					-1
				)
			) == completed_actor_id
		)

		if packet_valid:
			completed_jobs.erase(
				completed_request_key
			)
			set_meta(
				"resident_temporal_surface_refresh_jobs",
				completed_jobs
			)
			_emit_resident_surface_contract_packet(
				completed_signature,
				completed_surface_id,
				surface_contract
			)
			set_meta(
				"resident_temporal_surface_refresh_last_success",
				true
			)
			set_meta(
				"resident_temporal_surface_refresh_last_actor_id",
				completed_actor_id
			)
			set_meta(
				"resident_temporal_surface_refresh_last_surface_id",
				completed_surface_id
			)
			set_meta(
				"resident_temporal_surface_refresh_last_surface_revision",
				str(
					surface_contract.get(
						"surface_revision",
						""
					)
				)
			)
		elif worker_success and not worker_complete:
			var pending_job: Dictionary = _dict(
				completed_jobs.get(
					completed_request_key,
					{}
				)
			)
			var retry_count: int = int(
				pending_job.get(
					"retry_count",
					0
				)
			) + 1

			pending_job ["retry_count"] = retry_count
			pending_job ["last_pending_at_ms"] = int(
				Time.get_ticks_msec()
			)

			if retry_count <= 8:
				completed_jobs [
					completed_request_key
				] = pending_job

				var pending_order_raw: Variant = get_meta(
					"resident_temporal_surface_refresh_order",
					[]
				)
				var pending_order: Array = (
					(pending_order_raw as Array).duplicate(false)
					if typeof(pending_order_raw) == TYPE_ARRAY
					else []
				)

				if not pending_order.has(
					completed_request_key
				):
					pending_order.append(
						completed_request_key
					)

				set_meta(
					"resident_temporal_surface_refresh_order",
					pending_order
				)
				set_meta(
					"resident_temporal_surface_refresh_jobs",
					completed_jobs
				)
			else:
				completed_jobs.erase(
					completed_request_key
				)
				set_meta(
					"resident_temporal_surface_refresh_jobs",
					completed_jobs
				)
				set_meta(
					"resident_temporal_surface_refresh_last_success",
					false
				)
				set_meta(
					"resident_temporal_surface_refresh_last_failure_reason",
					"projection_remained_pending"
				)
		else:
			completed_jobs.erase(
				completed_request_key
			)
			set_meta(
				"resident_temporal_surface_refresh_jobs",
				completed_jobs
			)
			set_meta(
				"resident_temporal_surface_refresh_last_success",
				false
			)
			set_meta(
				"resident_temporal_surface_refresh_last_failure",
				worker_result.duplicate(false)
			)

		set_meta(
			"resident_temporal_surface_refresh_last_at_ms",
			int(Time.get_ticks_msec())
		)
		set_meta(
			"resident_temporal_surface_refresh_last_blocks_ui",
			false
		)
		set_meta(
			"resident_temporal_surface_refresh_blocking_wait_performed",
			false
		)

		_arm_resident_temporal_surface_refresh_service()
		return

	var order_raw: Variant = get_meta(
		"resident_temporal_surface_refresh_order",
		[]
	)
	var order: Array = (
		(order_raw as Array).duplicate(false)
		if typeof(order_raw) == TYPE_ARRAY
		else []
	)

	if order.is_empty():
		set_meta(
			"resident_temporal_surface_refresh_service_active",
			false
		)
		return

	var request_key: String = str(
		order.pop_front()
	)
	var jobs_raw: Variant = get_meta(
		"resident_temporal_surface_refresh_jobs",
		{}
	)
	var jobs: Dictionary = (
		(jobs_raw as Dictionary).duplicate(false)
		if typeof(jobs_raw) == TYPE_DICTIONARY
		else {}
	)
	var job_raw: Variant = jobs.get(
		request_key,
		{}
	)

	set_meta(
		"resident_temporal_surface_refresh_order",
		order
	)

	if typeof(job_raw) != TYPE_DICTIONARY:
		jobs.erase(
			request_key
		)
		set_meta(
			"resident_temporal_surface_refresh_jobs",
			jobs
		)
		_arm_resident_temporal_surface_refresh_service()
		return

	var job: Dictionary = job_raw as Dictionary
	var signature: String = str(
		job.get(
			"signature",
			""
		)
	).strip_edges()
	var actor_id: int = int(
		job.get(
			"actor_id",
			-1
		)
	)
	var surface_id: String = str(
		job.get(
			"surface_id",
			""
		)
	).strip_edges().to_lower()
	var actor: Person = (
		_resident_relationship_projection_actor_by_id(
			actor_id
		)
	)

	if (
		actor == null
		or signature == ""
		or surface_id == ""
	):
		jobs.erase(
			request_key
		)
		set_meta(
			"resident_temporal_surface_refresh_jobs",
			jobs
		)
		set_meta(
			"resident_temporal_surface_refresh_last_success",
			false
		)
		set_meta(
			"resident_temporal_surface_refresh_last_failure_reason",
			"actor_signature_or_surface_unavailable"
		)
		_arm_resident_temporal_surface_refresh_service()
		return




	var projection_worker_raw: Variant = projection_step_threads.get(
		signature,
		null
	)
	var checkpoint_worker_raw: Variant = (
		checkpoint_resume_life_observation_threads.get(
			signature,
			null
		)
	)
	var another_projection_worker_alive: bool = (
		(
			projection_worker_raw is Thread
			and (projection_worker_raw as Thread).is_alive()
		)
		or (
			checkpoint_worker_raw is Thread
			and (checkpoint_worker_raw as Thread).is_alive()
		)
	)

	if another_projection_worker_alive:
		order = (
			get_meta(
				"resident_temporal_surface_refresh_order",
				[]
			) as Array
		).duplicate(false)
		order.push_front(
			request_key
		)
		set_meta(
			"resident_temporal_surface_refresh_order",
			order
		)
		set_meta(
			"resident_temporal_surface_refresh_waiting_for_projection_worker",
			true
		)
		_arm_resident_temporal_surface_refresh_service()
		return

	set_meta(
		"resident_temporal_surface_refresh_waiting_for_projection_worker",
		false
	)

	var worker:= Thread.new()
	var worker_error: int = worker.start(
		Callable(
			self,
			"_build_resident_temporal_surface_successor_on_worker"
		).bind(
			surface_id,
			gs,
			actor
		),
		Thread.PRIORITY_LOW
	)

	if worker_error != OK:
		order = (
			get_meta(
				"resident_temporal_surface_refresh_order",
				[]
			) as Array
		).duplicate(false)
		order.push_front(
			request_key
		)
		set_meta(
			"resident_temporal_surface_refresh_order",
			order
		)
		set_meta(
			"resident_temporal_surface_refresh_last_success",
			false
		)
		set_meta(
			"resident_temporal_surface_refresh_last_failure_reason",
			"worker_start_failed"
		)
		set_meta(
			"resident_temporal_surface_refresh_last_worker_error",
			worker_error
		)
		_arm_resident_temporal_surface_refresh_service()
		return

	set_meta(
		"resident_temporal_surface_refresh_thread",
		worker
	)
	set_meta(
		"resident_temporal_surface_refresh_thread_context",
		{
			"request_key": request_key,
			"signature": signature,
			"actor_id": actor_id,
			"surface_id": surface_id,
			"started_at_ms": int(
				Time.get_ticks_msec()
			),
			"worker_thread_used": true,
		}
	)
	set_meta(
		"resident_temporal_surface_refresh_renderer_thread_authoring_forbidden",
		true
	)
	set_meta(
		"resident_temporal_surface_refresh_renderer_thread_poll_only",
		true
	)

	_arm_resident_temporal_surface_refresh_service()
func _resident_relationship_projection_actor_by_id(
	actor_id: int
) -> Person:
	if (
		gs == null
		or actor_id <= 0
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		return gs.player

	if gs.has_method(
		"get_npc_by_id"
	):
		return gs.get_npc_by_id(
			actor_id
		)

	return null
func _life_surface(
	runtime
) -> Dictionary:
	if (
		runtime == null
		or runtime.player == null
	):
		return _surface_fallback(
			"life",
			-1
		)

	var actor = runtime.player

	return {
		"schema": (
			"eralife.resident_life_surface_contract"
		),
		"version": 1,
		"actor_id": int(
			actor.id
		),
		"actor_name": _actor_name(
			actor
		),
		"age": int(
			actor.age
		),
		"year": int(
			runtime.year
		),
		"money": _actor_bank_balance(
			actor
		),
		"bank_balance": _actor_bank_balance(
			actor
		),
		"truth_state": "hot",
		"ui_is_renderer_only": true
	}

func _world_surface(
	runtime
) -> Dictionary:
	return {
		"schema": (
			"eralife.resident_world_surface_contract"
		),
		"version": 1,
		"actor_id": int(
			runtime.player.id
		),
		"year": int(
			runtime.year
		),
		"era_name": _era_name(
			runtime
		),
		"world_seed": int(
			runtime.scenario_state.get(
				"world_seed",
				-1
			)
		),
		"truth_state": "hot",
		"ui_is_renderer_only": true
	}


func _seal_graphs(
	runtime,
	work: Dictionary
) -> Dictionary:
	var signature: String = str(
		work.get(
			"signature",
			""
		)
	)
	var actor = runtime.player
	var actor_id: int = int(
		actor.id
	)
	var surfaces: Dictionary = _dict(
		work.get(
			"surface_contracts",
			{}
		)
	)
	var required_engine_ids: Array = [
		"global_intent_contract_engine",
		"career_hub_contract_engine",
		"activities_hub_contract_engine",
		"mod_menu_contract_engine",
		"school_engine",
		"relationship_engine",
		"life_engine",
		"world_engine"
	]
	var engine_rows: Array = []
	var required_engines_hot: bool = true

	for raw_engine_id in required_engine_ids:
		var engine_id: String = str(
			raw_engine_id
		)
		var engine_hot: bool = (
			runtime.get(
				engine_id
			) != null
		)

		engine_rows.append({
			"engine_id": engine_id,
			"hot": engine_hot
		})

		if not engine_hot:
			required_engines_hot = false

	var available_lenses: Array = [
		"life",
		"world",
		"activities",
		"career",
		"school",
		"relationships",
		"mods"
	]
	var surface_rows: Array = []
	var surface_graph_hot: bool = true

	for raw_surface_id in available_lenses:
		var surface_id: String = str(
			raw_surface_id
		)
		var surface_hot: bool = not _dict(
			surfaces.get(
				surface_id,
				{}
			)
		).is_empty()

		surface_rows.append({
			"surface_id": surface_id,
			"contract_hot": surface_hot,
			"build_on_click_forbidden": true
		})

		if not surface_hot:
			surface_graph_hot = false

	var contract_graph: Dictionary = {
		"schema": (
			"eralife.resident_contract_graph"
		),
		"version": 1,
		"signature": signature,
		"required_engines_hot": required_engines_hot,
		"engine_rows": engine_rows,
		"ui_is_renderer_only": true
	}
	var projection_graph: Dictionary = {
		"schema": (
			"eralife.resident_projection_graph"
		),
		"version": 1,
		"signature": signature,
		"actor_id": actor_id,
		"first_frame_snapshot": (
			_minimal_first_frame_snapshot(
				runtime
			)
		),
		"surface_contracts": surfaces.duplicate(true),
		"authoritative_projection": true,
		"ui_is_renderer_only": true
	}
	var lens_graph: Dictionary = {
		"schema": (
			"eralife.resident_lens_graph"
		),
		"version": 1,
		"signature": signature,
		"active_lens": "life",
		"available_lenses": available_lenses,
		"lens_state": {
			"career": "overview",
			"activities": "all",
			"school": "overview",
			"relationships": "family",
			"mods": "bundles"
		},
		"ui_is_renderer_only": true
	}
	var node_graph: Dictionary = {
		"schema": (
			"eralife.resident_node_graph"
		),
		"version": 1,
		"signature": signature,
		"actor_id": actor_id,
		"player_id": int(
			runtime.player_id
		),
		"year": int(
			runtime.year
		),
		"world_seed": int(
			runtime.scenario_state.get(
				"world_seed",
				-1
			)
		),
		"npc_count": runtime.npcs.size(),
		"world_node_hot": (
			runtime.world_engine != null
		),
		"ui_is_renderer_only": true
	}
	var surface_graph: Dictionary = {
		"schema": (
			"eralife.resident_surface_graph"
		),
		"version": 1,
		"signature": signature,
		"surface_rows": surface_rows,
		"surface_contracts": surfaces.duplicate(true),
		"surface_graph_hot": surface_graph_hot,
		"build_on_click_forbidden": true,
		"ui_is_renderer_only": true
	}

	return {
		"success": (
			required_engines_hot
			and surface_graph_hot
		),
		"schema": PROJECTION_SCHEMA,
		"version": ENGINE_VERSION,
		"signature": signature,
		"actor_id": actor_id,
		"contract_graph": contract_graph,
		"projection_graph": projection_graph,
		"lens_graph": lens_graph,
		"node_graph": node_graph,
		"surface_graph": surface_graph,
		"ui_is_renderer_only": true,
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func _minimal_first_frame_snapshot(
	runtime
) -> Dictionary:
	if (
		runtime == null
		or runtime.player == null
	):
		return {
			"schema": (
				"eralife.resident_first_frame_snapshot"
			),
			"version": 1,
			"actor_id": -1,
			"actor_name": "Unknown Life",
			"age": 0,
			"year": 0,
			"era_name": "Unknown Era",
			"money": 0.0,
			"bank_balance": 0.0,
			"current_panel": "life",
			"truth_state": "unavailable",
			"ui_is_renderer_only": true
		}

	var actor = runtime.player
	var bank_balance: float = (
		_actor_bank_balance(
			actor
		)
	)

	return {
		"schema": (
			"eralife.resident_first_frame_snapshot"
		),
		"version": 1,
		"actor_id": int(
			actor.id
		),
		"actor_name": _actor_name(
			actor
		),
		"age": int(
			actor.age
		),
		"year": int(
			runtime.year
		),
		"era_name": _era_name(
			runtime
		),
		"money": bank_balance,
		"bank_balance": bank_balance,
		"current_panel": "life",
		"truth_state": "hot",
		"ui_is_renderer_only": true
	}
func _actor_bank_balance(
	actor
) -> float:
	if actor == null:
		return 0.0

	return float(
		actor.bank_balance
	)

func _surface_fallback(
	surface_id: String,
	actor_id: int
) -> Dictionary:
	return {
		"success": true,
		"schema": (
			"eralife.resident_observable_surface_contract"
		),
		"version": 1,
		"surface_id": surface_id,
		"actor_id": actor_id,
		"truth_state": "observable_partial",
		"projection_pending": true,
		"projection_complete": false,
		"authoritative_projection": false,
		"ready_gate_member": false,
		"build_on_click_forbidden": true,
		"ui_is_renderer_only": true
	}


func export_state() -> Dictionary:
	return {
		"schema": (
			"eralife.reality_projection_contract_engine.state"
		),
		"version": ENGINE_VERSION,
		"last_projection_by_signature": (
			last_projection_by_signature.duplicate(true)
		),
		"last_report": last_report.duplicate(true),
		"ledger": ledger.duplicate(true),
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	last_projection_by_signature = _dict(
		data.get(
			"last_projection_by_signature",
			{}
		)
	)
	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)
	ledger = _array(
		data.get(
			"ledger",
			[]
		)
	)
	projection_work_by_signature = {}

	_commit_state()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION
	}


func _runtime_signature(
	runtime
) -> String:
	if (
		runtime != null
		and typeof(
			runtime.scenario_state
		) == TYPE_DICTIONARY
	):
		return str(
			runtime.scenario_state.get(
				"reality_residency_signature",
				runtime.scenario_state.get(
					"god_mode_life_prewarm_signature",
					""
				)
			)
		).strip_edges()

	return ""


func _relationship_count(
	runtime,
	actor
) -> int:
	if actor == null:
		return 0

	var relationship_keys: Dictionary = {}
	var actor_id: int = int(
		actor.id
	)
	var actor_entity_id: String = (
		"human:%d"
		% actor_id
	)

	if (
		runtime != null
		and runtime.relationship_graph_contract_engine != null
		and runtime.relationship_graph_contract_engine.has_method(
			"relationships_for_entity"
		)
	):
		var graph_edges: Array = _array(
			runtime.relationship_graph_contract_engine.relationships_for_entity(
				actor_entity_id
			)
		)

		for raw_edge in graph_edges:
			if typeof(
				raw_edge
			) != TYPE_DICTIONARY:
				continue

			var edge: Dictionary = (
				raw_edge as Dictionary
			)
			var entity_a: String = str(
				edge.get(
					"entity_a",
					""
				)
			).strip_edges()
			var entity_b: String = str(
				edge.get(
					"entity_b",
					""
				)
			).strip_edges()

			if (
				entity_a == actor_entity_id
				and entity_b != ""
			):
				relationship_keys [
					entity_b
				] = true
			elif (
				entity_b == actor_entity_id
				and entity_a != ""
			):
				relationship_keys [
					entity_a
				] = true

	_append_relationship_identity(
		relationship_keys,
		actor.partner,
		actor_id
	)
	_append_relationship_identities(
		relationship_keys,
		actor.parents,
		actor_id
	)
	_append_relationship_identities(
		relationship_keys,
		actor.children,
		actor_id
	)
	_append_relationship_identities(
		relationship_keys,
		actor.friends,
		actor_id
	)
	_append_relationship_identities(
		relationship_keys,
		actor.ex_partners,
		actor_id
	)
	_append_relationship_identities(
		relationship_keys,
		actor.schoolmates,
		actor_id
	)
	_append_relationship_identities(
		relationship_keys,
		actor.coworkers,
		actor_id
	)

	if typeof(
		actor.affection
	) == TYPE_DICTIONARY:
		_append_relationship_identities(
			relationship_keys,
			actor.affection.keys(),
			actor_id
		)

	return relationship_keys.size()
func _append_relationship_identities(
	out: Dictionary,
	values: Array,
	actor_id: int
) -> void:
	for raw_value in values:
		_append_relationship_identity(
			out,
			raw_value,
			actor_id
		)


func _append_relationship_identity(
	out: Dictionary,
	raw_value: Variant,
	actor_id: int
) -> void:
	var identity_key: String = (
		_relationship_identity_key(
			raw_value
		)
	)
	var actor_identity_key: String = (
		"human:%d"
		% actor_id
	)

	if (
		identity_key == ""
		or identity_key == actor_identity_key
	):
		return

	out [
		identity_key
	] = true


func _relationship_identity_key(
	raw_value: Variant
) -> String:
	if raw_value == null:
		return ""

	if raw_value is Person:
		var person_value: Person = (
			raw_value as Person
		)
		var person_id: int = int(
			person_value.id
		)

		if person_id <= 0:
			return ""

		return (
			"human:%d"
			% person_id
		)

	if typeof(
		raw_value
	) == TYPE_DICTIONARY:
		var row: Dictionary = (
			raw_value as Dictionary
		)
		var entity_id: String = str(
			row.get(
				"entity_id",
				""
			)
		).strip_edges()

		if entity_id != "":
			return entity_id

		var row_person_id: int = int(
			row.get(
				"person_id",
				row.get(
					"id",
					-1
				)
			)
		)

		if row_person_id <= 0:
			return ""

		return (
			"human:%d"
			% row_person_id
		)

	var value_type: int = typeof(
		raw_value
	)

	if (
		value_type == TYPE_INT
		or value_type == TYPE_FLOAT
	):
		var numeric_person_id: int = int(
			raw_value
		)

		if numeric_person_id <= 0:
			return ""

		return (
			"human:%d"
			% numeric_person_id
		)

	var text_value: String = str(
		raw_value
	).strip_edges()

	if text_value == "":
		return ""

	if text_value.is_valid_int():
		var text_person_id: int = int(
			text_value
		)

		if text_person_id <= 0:
			return ""

		return (
			"human:%d"
			% text_person_id
		)

	return text_value


func _actor_name(
	actor
) -> String:
	if actor == null:
		return "Unknown Life"

	var display_name: String = "%s %s" % [
		str(
			actor.first_name
		).strip_edges(),
		str(
			actor.last_name
		).strip_edges()
	]
	display_name = display_name.strip_edges()

	return (
		display_name
		if display_name != ""
		else "Unnamed Life"
	)


func _era_name(
	runtime
) -> String:
	if runtime == null:
		return "Unknown Era"

	if typeof(
		runtime.era
	) == TYPE_DICTIONARY:
		return str(
			runtime.era.get(
				"name",
				runtime.era.get(
					"key",
					"Unknown Era"
				)
			)
		)

	return "Unknown Era"


func _work(
	signature: String
) -> Dictionary:
	return _dict(
		projection_work_by_signature.get(
			signature,
			{}
		)
	)


func _record(
	report: Dictionary
) -> void:
	ledger.append(
		report.duplicate(true)
	)

	while ledger.size() > MAX_LEDGER:
		ledger.pop_front()


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [
		"reality_projection_contract_engine_state"
	] = export_state()

func _dict(
	value: Variant
) -> Dictionary:
	return (
		(value as Dictionary).duplicate(false)
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)


func _array(
	value: Variant
) -> Array:
	return (
		(value as Array).duplicate(false)
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
		"schema": PROJECTION_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"context": context.duplicate(true),
		"ui_is_renderer_only": true,
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_record(last_report)
	_commit_state()

	return last_report.duplicate(true)