extends Resource
class_name PendingSituationsEngine

const ENGINE_STATE_SCHEMA:= "eralife.pending_situations_engine_state"
const SUMMARY_CONTRACT_SCHEMA:= "eralife.pending_situations_summary_contract"
const ITEM_CONTRACT_SCHEMA:= "eralife.pending_situation_item_contract"
# How many game years a household starter situation stays open before time
# settles it on the parents' behalf. See _fallback_deadline_option_id().
const BIRTH_STARTER_DEFAULT_EXPIRY_YEARS:= 6.0
# Game years before an unattended pending contract settles itself. Applies to the
# illness, relationship-history and family-finance builders, which all hardcoded
# expires_age = -1.0 (never).
const PENDING_CONTRACT_DEFAULT_EXPIRY_YEARS:= 6.0
# NPC decision pacing. An argument should play out across visible beats: the other
# parent does not answer instantly, and does not answer twice for the same stage.
const NPC_DECISION_INITIAL_DELAY_MS:= 20000
const NPC_DECISION_RESTAGE_DELAY_MS:= 15000
const BIRTH_STARTER_CONTRACT_SCHEMA:= "eralife.pending_situation.birth_starter_contract"
const CONTRACT_VERSION:= 1

var gs
var pending_situation_contracts: Dictionary = {}
# source_contract_id -> { "<actor_id>": last_decision_ms, "<actor_id>:stage": stage }
var npc_decision_ledger: Dictionary = {}
var pending_situation_index: Dictionary = {}
var pending_situation_observations: Dictionary = {}
var pending_situation_mutation_log: Array = []
var birth_starter_seeded_actor_ids: Dictionary = {}
var last_summary_contract: Dictionary = {}
var last_report: Dictionary = {}
var last_tick_ms: int = 0



var state_hydrated: bool = false


const PENDING_RUNTIME_QUANTUM_INTERVAL_MS: int = 50





const MAX_RELATIONSHIP_HISTORY_SEED_INTENTS_PER_QUANTUM: int = 1


var pending_baseline_seed_signature_by_actor: Dictionary = {}
var relationship_history_seed_cursor_by_actor: Dictionary = {}
var relationship_history_seed_next_scan_ms_by_actor: Dictionary = {}



var pending_payload_revision_sequence_by_actor: Dictionary = {}






var pending_list_observation_snapshot_by_actor: Dictionary = {}
var pending_list_observation_snapshot_mutex: Mutex = Mutex.new()

func _init(_gs = null):
	gs = _gs
	_ensure_state()


func _ensure_state() -> void:
	if gs == null:
		return

	if state_hydrated:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	pending_situation_contracts = _safe_dictionary(
		gs.scenario_state.get(
			"pending_situation_contracts",
			pending_situation_contracts
		)
	)
	pending_situation_index = _safe_dictionary(
		gs.scenario_state.get(
			"pending_situation_index",
			pending_situation_index
		)
	)
	pending_situation_observations = _safe_dictionary(
		gs.scenario_state.get(
			"pending_situation_observations",
			pending_situation_observations
		)
	)
	pending_situation_mutation_log = _safe_array(
		gs.scenario_state.get(
			"pending_situation_mutation_log",
			pending_situation_mutation_log
		)
	)
	birth_starter_seeded_actor_ids = _safe_dictionary(
		gs.scenario_state.get(
			"pending_situation_birth_starter_seeded_actor_ids",
			birth_starter_seeded_actor_ids
		)
	)
	last_summary_contract = _safe_dictionary(
		gs.scenario_state.get(
			"pending_situations_last_summary_contract",
			last_summary_contract
		)
	)

	_repair_pending_situation_state()



	state_hydrated = true



	_commit_state()

func export_state() -> Dictionary:
	_ensure_state()
	return {
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"pending_situation_contracts": pending_situation_contracts.duplicate(true),
		"pending_situation_index": pending_situation_index.duplicate(true),
		"pending_situation_observations": pending_situation_observations.duplicate(true),
		"pending_situation_mutation_log": pending_situation_mutation_log.duplicate(true),
		"birth_starter_seeded_actor_ids": birth_starter_seeded_actor_ids.duplicate(true),
		"last_summary_contract": last_summary_contract.duplicate(true),
		"last_report": last_report.duplicate(true),
		"last_tick_ms": last_tick_ms,
		"exported_at_ms": int(Time.get_ticks_msec())
	}


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "invalid_data"
		}

	pending_situation_contracts = _safe_dictionary(data.get("pending_situation_contracts", data.get("contracts", {})))
	pending_situation_index = _safe_dictionary(data.get("pending_situation_index", data.get("index", {})))
	pending_situation_observations = _safe_dictionary(data.get("pending_situation_observations", data.get("observations", {})))
	pending_situation_mutation_log = _safe_array(data.get("pending_situation_mutation_log", data.get("mutation_log", [])))
	birth_starter_seeded_actor_ids = _safe_dictionary(data.get("birth_starter_seeded_actor_ids", data.get("pending_situation_birth_starter_seeded_actor_ids", {})))
	last_summary_contract = _safe_dictionary(data.get("last_summary_contract", data.get("summary_contract", {})))
	last_report = _safe_dictionary(data.get("last_report", {}))
	last_tick_ms = int(data.get("last_tick_ms", 0))

	_repair_pending_situation_state()
	_commit_state()

	last_report = {
		"success": true,
		"mode": "pending_situations_engine_imported",
		"schema": ENGINE_STATE_SCHEMA,
		"version": CONTRACT_VERSION,
		"contract_count": pending_situation_contracts.size(),
		"index_count": pending_situation_index.size(),
		"observation_count": pending_situation_observations.size(),
		"mutation_count": pending_situation_mutation_log.size(),
		"birth_seed_count": birth_starter_seeded_actor_ids.size(),
		"repaired": true
	}

	return last_report.duplicate(true)
func on_illness_event(payload: Dictionary) -> void:
	_ensure_state()

	if gs == null or gs.player == null:
		return

	var sick_actor_id: int = int(payload.get("actor_id", payload.get("npc_id", payload.get("person_id", -1))))
	if sick_actor_id <= 0:
		return

	var sick_actor: Person = _actor_by_id(sick_actor_id)
	if sick_actor == null:
		return

	var viewer: Person = gs.player
	if viewer == null or int(viewer.id) == sick_actor_id:
		return

	if not _pending_illness_is_relevant_to_viewer(sick_actor, viewer):
		return

	_ensure_pending_illness_runtime_engines()

	if gs.scenario_popup_contract_engine == null:
		return

	var severity: String = str(payload.get("severity", payload.get("illness_severity", "minor"))).strip_edges().to_lower()
	if severity not in ["minor", "major"]:
		severity = "minor"

	var contract: Dictionary = _build_illness_pending_contract_for_viewer(sick_actor, viewer, severity, payload)
	if contract.is_empty():
		return

	var contract_id: String = str(contract.get("id", contract.get("contract_id", ""))).strip_edges()
	if contract_id == "":
		return

	if _runtime_has_pending_or_resolved_contract(contract_id):
		return

	var emit_report: Dictionary = gs.scenario_popup_contract_engine.emit_popup_contract(contract, {
		"source": "pending_situations_illness_event_bus",
		"target_id": int(viewer.id)
	})

	if bool(emit_report.get("success", false)):
		_record_pending_mutation(contract_id, "illness_event_pending_contract_emitted", {
			"sick_actor_id": sick_actor_id,
			"viewer_actor_id": int(viewer.id),
			"severity": severity,
			"event_payload": payload.duplicate(true)
		})
		_commit_state()
func _ensure_pending_illness_runtime_engines() -> void:
	if gs == null:
		return

	if gs.scenario_runtime_contract_engine == null:
		gs.scenario_runtime_contract_engine = ScenarioRuntimeContractEngine.new(gs)

	if gs.scenario_popup_contract_engine == null:
		gs.scenario_popup_contract_engine = ScenarioPopupContractEngine.new(gs)


func _build_illness_pending_contract_for_viewer(sick_actor: Person, viewer: Person, severity: String, payload: Dictionary = {}) -> Dictionary:
	if sick_actor == null or viewer == null:
		return {}

	var viewer_id: int = int(viewer.id)
	var sick_id: int = int(sick_actor.id)
	if viewer_id <= 0 or sick_id <= 0:
		return {}

	var clean_severity: String = str(severity).strip_edges().to_lower()
	if clean_severity not in ["minor", "major"]:
		clean_severity = "minor"

	var relation_label: String = _pending_relationship_label_for_viewer(sick_actor, viewer)
	var sick_name: String = _first_name_for_actor(sick_actor)
	if sick_name == "":
		sick_name = "Someone"

	var era_name: String = _current_era_name()
	var illness_label: String = _pending_era_illness_label(clean_severity, era_name)
	var contract_id: String = "illness_notice_%d_%d_%s_%d" % [viewer_id, sick_id, clean_severity, int(gs.year) if gs != null else 0]

	var details: String = "Your %s %s has %s. %s What will you do?" % [
		relation_label,
		sick_name,
		illness_label,
		_pending_era_illness_context_sentence(clean_severity, era_name)
	]

	return {
		"schema": "eralife.pending_situation.illness_notice_contract",
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"contract_type": "scenario_popup",
		"target": viewer_id,
		"target_id": viewer_id,
		"issuer": sick_id,
		"issuer_id": sick_id,
		"participant_ids": _unique_positive_int_array([viewer_id, sick_id]),
		"decision_actor_ids": [viewer_id],
		"audience_ids": [viewer_id],
		"category": "health",
		"pending_category": "health",
		"category_group": "health",
		"request": "immediate_family_illness_notice",
		"title": "Someone close to you is sick",
		"overview": "%s is sick." % sick_name,
		"details": details,
		"state": "pending",
		"visibility": "participant_visible",
		"requires_attention": true,
		"response_options": _pending_illness_response_options(relation_label, sick_name, clean_severity, era_name),
		"selected_response": "",
		"resolution": {},
		"urgency": 58.0 if clean_severity == "minor" else 84.0,
		"decay": 0.04 if clean_severity == "minor" else 0.1,
		"escalation_stage": 0,
		"escalation_triggers": [],
		"next_escalation_ms": int(Time.get_ticks_msec()) + (24000 if clean_severity == "minor" else 12000),
		# FIX: was -1.0 (never expires). Nothing resolves a contract on an NPC's
		# behalf, so these accumulated for the whole life. See
		# PENDING_CONTRACT_DEFAULT_EXPIRY_YEARS.
		"expires_age": float(viewer.age) + PENDING_CONTRACT_DEFAULT_EXPIRY_YEARS,
		"created_year": int(gs.year) if gs != null else 0,
		"created_age": float(viewer.age),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"illness_actor_id": sick_id,
		"illness_actor_name": sick_name,
		"illness_relationship_label": relation_label,
		"illness_severity": clean_severity,
		"illness_era_label": illness_label,
		"source": "pending_situations_event_bus_illness",
		"source_event_payload": payload.duplicate(true),
		"contract_mesh": {
			"source_of_truth": "PendingSituationsEngine",
			"popup_contract_owner": "ScenarioPopupContractEngine",
			"runtime_owner": "ScenarioRuntimeContractEngine",
			"pending_index_owner": "PendingSituationsEngine",
			"ui_observer": "PopupViewer",
			"ui_mutation_allowed": false,
			"persistent": true,
			"save_key": "scenario_runtime_contract_engine_state"
		}
	}


func _pending_illness_response_options(relation_label: String, sick_name: String, severity: String, era_name: String) -> Array:
	var clean_relation: String = str(relation_label).strip_edges()
	if clean_relation == "":
		clean_relation = "relative"

	var clean_name: String = str(sick_name).strip_edges()
	if clean_name == "":
		clean_name = "Someone"

	var clean_severity: String = str(severity).strip_edges().to_lower()
	var era_key: String = str(era_name).strip_edges().to_lower()

	var care_label: String = "Visit them"
	var help_label: String = "Send help"
	var hope_label: String = "Hope they recover"

	if era_key.find("ancient") >= 0:
		care_label = "Sit near their bedding"
		help_label = "Ask for herbs"
		hope_label = "Pray to the spirits"
	elif era_key.find("medieval") >= 0:
		care_label = "Visit their chamber"
		help_label = "Send for a healer"
		hope_label = "Pray for them"
	elif era_key.find("future") >= 0:
		care_label = "Visit their recovery pod"
		help_label = "Send medical credits"
		hope_label = "Monitor their recovery feed"

	var severity_phrase: String = "minor illness" if clean_severity == "minor" else "serious illness"

	return [
		{
			"id": "visit_them",
			"label": care_label,
			"source_resolves": true,
			"priority": 62,
			"journal_text": "I checked on my %s %s after they came down with a %s." % [clean_relation, clean_name, severity_phrase],
			"result_text": "You check on your %s %s. They may still be sick, but they know you cared." % [clean_relation, clean_name]
		},
		{
			"id": "send_help",
			"label": help_label,
			"source_resolves": true,
			"priority": 70,
			"journal_text": "I sent help for my %s %s after they came down with a %s." % [clean_relation, clean_name, severity_phrase],
			"result_text": "You send help for your %s %s." % [clean_relation, clean_name]
		},
		{
			"id": "give_space",
			"label": "Give them space",
			"source_resolves": true,
			"priority": 35,
			"journal_text": "I gave my %s %s space while they were dealing with a %s." % [clean_relation, clean_name, severity_phrase],
			"result_text": "You give your %s %s space." % [clean_relation, clean_name]
		},
		{
			"id": "hope_they_recover",
			"label": hope_label,
			"source_resolves": true,
			"priority": 48,
			"journal_text": "I hoped my %s %s would recover from their %s." % [clean_relation, clean_name, severity_phrase],
			"result_text": "You hold onto hope for your %s %s." % [clean_relation, clean_name]
		}
	]


func _pending_era_illness_label(severity: String, era_name: String) -> String:
	var clean_severity: String = str(severity).strip_edges().to_lower()
	var era_key: String = str(era_name).strip_edges().to_lower()

	if clean_severity == "major":
		if era_key.find("ancient") >= 0:
			return "a dangerous sickness"
		if era_key.find("medieval") >= 0:
			return "a grave illness"
		if era_key.find("industrial") >= 0:
			return "a serious illness"
		if era_key.find("future") >= 0:
			return "a severe system-diagnosed illness"
		return "a serious illness"

	if era_key.find("ancient") >= 0:
		return "a passing sickness"
	if era_key.find("medieval") >= 0:
		return "a minor ailment"
	if era_key.find("industrial") >= 0:
		return "a minor illness"
	if era_key.find("future") >= 0:
		return "a mild bio-alert"
	return "a minor illness"


func _pending_era_illness_context_sentence(severity: String, era_name: String) -> String:
	var clean_severity: String = str(severity).strip_edges().to_lower()
	var era_key: String = str(era_name).strip_edges().to_lower()

	if clean_severity == "major":
		if era_key.find("ancient") >= 0:
			return "The household knows sickness can change everything quickly in this era."
		if era_key.find("medieval") >= 0:
			return "Medicine is uncertain, and the household is worried."
		if era_key.find("industrial") >= 0:
			return "Doctors can help, but the fear in the house is real."
		if era_key.find("future") >= 0:
			return "Even advanced care cannot make the fear disappear instantly."
		return "The household is worried."

	if era_key.find("ancient") >= 0:
		return "The adults are watching them closely."
	if era_key.find("medieval") >= 0:
		return "Everyone is hoping it does not become worse."
	if era_key.find("industrial") >= 0:
		return "It may pass, but the household is paying attention."
	if era_key.find("future") >= 0:
		return "The monitors say it is mild, but family still notices."
	return "It may pass, but family still notices."


func _pending_illness_is_relevant_to_viewer(sick_actor: Person, viewer: Person) -> bool:
	if sick_actor == null or viewer == null:
		return false

	var sick_id: int = int(sick_actor.id)
	var viewer_id: int = int(viewer.id)

	if sick_id <= 0 or viewer_id <= 0 or sick_id == viewer_id:
		return false

	if sick_id in viewer.parents:
		return true

	if sick_id in viewer.children:
		return true

	if viewer_id in sick_actor.parents:
		return true

	if viewer_id in sick_actor.children:
		return true

	if viewer.partner != null and int(viewer.partner.id) == sick_id:
		return true

	if sick_actor.partner != null and int(sick_actor.partner.id) == viewer_id:
		return true

	for raw_parent_id in viewer.parents:
		var parent_id: int = int(raw_parent_id)
		if parent_id > 0 and parent_id in sick_actor.parents:
			return true

	return false


func _pending_relationship_label_for_viewer(subject: Person, viewer: Person) -> String:
	if subject == null or viewer == null:
		return "relative"

	var subject_id: int = int(subject.id)
	var viewer_id: int = int(viewer.id)

	if subject_id in viewer.parents:
		return "mother" if str(subject.gender).strip_edges().to_lower() == "female" else "father"

	if subject_id in viewer.children:
		return "daughter" if str(subject.gender).strip_edges().to_lower() == "female" else "son"

	if viewer_id in subject.parents:
		return "sister" if str(subject.gender).strip_edges().to_lower() == "female" else "brother"

	if viewer.partner != null and int(viewer.partner.id) == subject_id:
		return "girlfriend" if str(subject.gender).strip_edges().to_lower() == "female" else "boyfriend"

	if subject.partner != null and int(subject.partner.id) == viewer_id:
		return "girlfriend" if str(subject.gender).strip_edges().to_lower() == "female" else "boyfriend"

	for raw_parent_id in viewer.parents:
		var parent_id: int = int(raw_parent_id)
		if parent_id > 0 and parent_id in subject.parents:
			return "sister" if str(subject.gender).strip_edges().to_lower() == "female" else "brother"

	return "relative"


func _unique_positive_int_array(value: Variant) -> Array:
	var out: Array = []
	var raw_array: Array = _safe_array(value)

	for raw_id in raw_array:
		var clean_id: int = int(raw_id)
		if clean_id > 0 and clean_id not in out:
			out.append(clean_id)

	return out
func run_npc_decision_pass(_context: Dictionary = {}) -> Dictionary:
	# Part 2: nothing in the game ever made an NPC decide. resolve_view_choice() was
	# already fully actor-agnostic, and _latest_parent_decision_for_source() already
	# advances a contract to its follow-up stage when the OTHER decision actor
	# responds -- so the whole two-stage negotiation was wired and waiting for
	# somebody to call it on an NPC's behalf. This is that caller.
	var report: Dictionary = {
		"schema": "eralife.pending_situations.npc_decision_pass",
		"success": true,
		"decisions": [],
		"considered": 0,
		"skipped_no_living_actor": 0,
		"skipped_waiting": 0
	}

	if (
		gs == null
		or gs.scenario_runtime_contract_engine == null
		or gs.contract_view_layer_contract_engine == null
	):
		report ["success"] = false
		report ["reason"] = "engines_unavailable"
		return report

	var runtime = gs.scenario_runtime_contract_engine
	var view_layer = gs.contract_view_layer_contract_engine
	var player_id: int = (
		int(gs.player.id)
		if gs.player != null
		else -1
	)
	var now_ms: int = int(Time.get_ticks_msec())

	for raw_contract_id in runtime.active_popup_contracts.keys():
		var contract: Dictionary = _safe_dictionary(
			runtime.active_popup_contracts.get(raw_contract_id, {})
		)

		if contract.is_empty():
			continue

		var decision_actor_ids: Array = _safe_array(
			contract.get("decision_actor_ids", [])
		)

		if decision_actor_ids.is_empty():
			continue

		var source_id: String = str(raw_contract_id)

		for raw_decision_actor_id in decision_actor_ids:
			var decision_actor_id: int = int(raw_decision_actor_id)

			# The player decides for themselves; never auto-play them.
			if decision_actor_id <= 0 or decision_actor_id == player_id:
				continue

			report ["considered"] = int(report.get("considered", 0)) + 1

			var decision_actor: Person = _actor_by_id(decision_actor_id)
			if decision_actor == null or not bool(decision_actor.alive):
				report ["skipped_no_living_actor"] = int(
					report.get("skipped_no_living_actor", 0)
				) + 1
				continue

			if not _npc_decision_is_due(source_id, decision_actor_id, contract, now_ms):
				report ["skipped_waiting"] = int(
					report.get("skipped_waiting", 0)
				) + 1
				continue

			var view_contract: Dictionary = _safe_dictionary(
				view_layer.build_view_contract(contract, decision_actor, {
					"source": "npc_decision_pass"
				})
			)
			var option_id: String = _weighted_option_id_for_npc(
				view_contract,
				decision_actor
			)

			if option_id == "":
				continue

			var choice_report: Dictionary = _safe_dictionary(
				view_layer.resolve_view_choice(
					contract,
					decision_actor_id,
					option_id,
					{
						"source": "npc_decision_pass",
					}
				)
			)

			_mark_npc_decision_made(source_id, decision_actor_id, now_ms)

			# If the NPC's choice settles the shared situation, run it through the
			# same terminal path a player tap uses so every consequence fires.
			if bool(choice_report.get("source_resolves", false)):
				if gs.scenario_popup_contract_engine != null:
					gs.scenario_popup_contract_engine.resolve_contract_response(
						source_id,
						option_id,
						{
							"target_id": decision_actor_id,
							"viewer_actor_id": decision_actor_id,
						}
					)

			report ["decisions"].append({
				"contract_id": source_id,
				"actor_id": decision_actor_id,
				"actor_name": _first_name_for_actor_id(decision_actor_id),
				"option_id": option_id,
				"source_resolves": bool(choice_report.get("source_resolves", false))
			})

			EraLog.truth(
				"ERALIFE_NPC_DECISION|contract=%s|actor=%d|option=%s|resolves=%s"
				% [
					source_id,
					decision_actor_id,
					option_id,
					str(choice_report.get("source_resolves", false))
				]
			)

	return report


func _npc_decision_is_due(
	source_id: String,
	actor_id: int,
	contract: Dictionary,
	now_ms: int
) -> bool:
	# An NPC responds once per stage, after a delay, so an argument plays out across
	# visible beats instead of resolving itself the instant it appears.
	var ledger: Dictionary = _safe_dictionary(
		npc_decision_ledger.get(source_id, {})
	)
	var actor_key: String = str(actor_id)

	if ledger.has(actor_key):
		var last_ms: int = int(ledger.get(actor_key, 0))
		# Already responded to the current stage; wait for the stage to advance.
		if now_ms - last_ms < NPC_DECISION_RESTAGE_DELAY_MS:
			return false

		var stage_signature: String = str(
			contract.get("escalation_stage", 0)
		)
		if str(ledger.get("%s:stage" % actor_key, "")) == stage_signature:
			return false

	var created_ms: int = int(
		contract.get("created_at_ms", now_ms)
	)
	return now_ms - created_ms >= NPC_DECISION_INITIAL_DELAY_MS


func _mark_npc_decision_made(
	source_id: String,
	actor_id: int,
	now_ms: int
) -> void:
	var ledger: Dictionary = _safe_dictionary(
		npc_decision_ledger.get(source_id, {})
	)
	var contract: Dictionary = {}

	if gs != null and gs.scenario_runtime_contract_engine != null:
		contract = _safe_dictionary(
			gs.scenario_runtime_contract_engine.active_popup_contracts.get(source_id, {})
		)

	ledger [str(actor_id)] = now_ms
	ledger ["%s:stage" % str(actor_id)] = str(
		contract.get("escalation_stage", 0)
	)
	npc_decision_ledger [source_id] = ledger


func _weighted_option_id_for_npc(
	view_contract: Dictionary,
	decision_actor: Person
) -> String:
	# Weight by the option's authored priority, then nudge by the actor's own state:
	# a broke household leans away from expensive-sounding cooperation, a kind actor
	# leans toward it, a hot-tempered one leans toward conflict. Priority stays the
	# dominant term so authored intent still drives the outcome.
	var options: Array = _safe_array(
		view_contract.get("response_options", [])
	)

	if options.is_empty():
		return ""

	var weights: Array = []
	var total_weight: float = 0.0

	for raw_option in options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue

		var option: Dictionary = raw_option as Dictionary
		var option_id: String = str(option.get("id", "")).strip_edges()

		if option_id == "":
			continue

		var weight: float = maxf(
			1.0,
			float(option.get("priority", 50))
		)
		weight *= _npc_option_bias(option_id, decision_actor)

		weights.append({
			"id": option_id,
			"weight": weight
		})
		total_weight += weight

	if weights.is_empty() or total_weight <= 0.0:
		return ""

	var roll: float = randf() * total_weight
	var running: float = 0.0

	for entry in weights:
		running += float(entry.get("weight", 0.0))
		if roll <= running:
			return str(entry.get("id", ""))

	return str(weights[weights.size() - 1].get("id", ""))


func _npc_option_bias(option_id: String, decision_actor: Person) -> float:
	var bias: float = 1.0
	var clean_option: String = option_id.strip_edges().to_lower()

	var cooperative: bool = clean_option in [
		"accept_plan",
		"apologize",
		"make_budget_plan",
		"try_to_help"
	]
	var conflict: bool = clean_option in [
		"argue_back",
		"snap_back",
		"walk_away",
		"argue"
	]

	var happiness: float = float(decision_actor.happiness) if "happiness" in decision_actor else 50.0
	var money: float = float(decision_actor.money) if "money" in decision_actor else 0.0

	if cooperative:
		bias *= lerpf(0.6, 1.5, clampf(happiness / 100.0, 0.0, 1.0))
		if money <= 0.0:
			bias *= 0.7
	elif conflict:
		bias *= lerpf(1.5, 0.6, clampf(happiness / 100.0, 0.0, 1.0))
		if money <= 0.0:
			bias *= 1.3

	return maxf(0.05, bias)


func runtime_tick(
	delta: float = 0.0,
	_context: Dictionary = {}
) -> Dictionary:
	var now_ms: int = int(
		Time.get_ticks_msec()
	)




	if (
		now_ms - last_tick_ms
		< PENDING_RUNTIME_QUANTUM_INTERVAL_MS
	):
		return last_report.duplicate(false)

	last_tick_ms = now_ms

	_ensure_state()

	var actor: Person = (
		gs.player
		if (
			gs != null
			and gs.player != null
		)
		else null
	)
	var actor_id: int = (
		int(actor.id)
		if actor != null
		else -1
	)
	var actor_key: String = str(
		actor_id
	)

	var birth_seed_report: Dictionary = {}
	var age_seed_report: Dictionary = {}

	# Stall watchdog sweep. This lives here rather than in the residency manager on
	# purpose: the failure being watched for is the residency service pump dying, and
	# a watchdog driven by the pump would die with it. runtime_tick() is driven from
	# MainScene independently, so it keeps ticking either way.
	EraLog.watch_sweep()

	# Let non-player decision actors respond to their own situations.
	# Result intentionally unused: the pass reports through EraLog.
	var _npc_decision_report: Dictionary = run_npc_decision_pass({
		"source": "pending_situations_runtime_tick"
	})



	if actor != null and actor_id > 0:
		var baseline_signature: String = (
			"%d:%d:%d"
			% [
				actor_id,
				int(
					gs.year
					if gs != null
					else 0
				),
				int(
					floor(
						float(actor.age)
					)
				)
			]
		)

		if str(
			pending_baseline_seed_signature_by_actor.get(
				actor_key,
				""
			)
		) != baseline_signature:
			birth_seed_report = (
				seed_birth_starter_contracts_for_actor(
					actor,
					{
						"source": (
							"pending_situations_runtime"
						),
						"controlled_actor_id": actor_id,
					}
				)
			)

			age_seed_report = (
				seed_age_window_contracts_for_actor(
					actor,
					{
						"source": (
							"pending_situations_runtime"
						),
						"controlled_actor_id": actor_id,
					}
				)
			)

			pending_baseline_seed_signature_by_actor [
				actor_key
			] = baseline_signature

	var relationship_seed_report: Dictionary = {}

	if actor != null and actor_id > 0:
		relationship_seed_report = (
			seed_relationship_history_contracts_for_actor(
				actor,
				{
					"source": (
						"pending_situations_runtime"
					),
					"controlled_actor_id": actor_id,
					"max_intents_per_quantum": (
						MAX_RELATIONSHIP_HISTORY_SEED_INTENTS_PER_QUANTUM
					)
				}
			)
		)

	var runtime_report: Dictionary = {}

	if (
		gs != null
		and gs.scenario_runtime_contract_engine != null
	):
		runtime_report = (
			gs.scenario_runtime_contract_engine
			.runtime_tick(
				delta
			)
		)
	else:
		runtime_report = {
			"success": false,
			"reason": (
				"missing_scenario_runtime_contract_engine"
			),
			"cycle_completed_now": false
		}

	var resident_payload: Dictionary = {}

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
		and actor_id > 0
	):
		var payload_registry_raw: Variant = (
			gs.scenario_state.get(
				"resident_pending_situations_payload_by_actor",
				{}
			)
		)

		if typeof(payload_registry_raw) == TYPE_DICTIONARY:
			var payload_raw: Variant = (
				(payload_registry_raw as Dictionary).get(
					actor_key,
					{}
				)
			)

			if typeof(payload_raw) == TYPE_DICTIONARY:
				resident_payload = (
					(payload_raw as Dictionary)
					.duplicate(false)
				)

	var baseline_authored_truth: bool = (
		bool(
			birth_seed_report.get(
				"success",
				false
			)
		)
		and not bool(
			birth_seed_report.get(
				"already_seeded",
				false
			)
		)
		and not bool(
			birth_seed_report.get(
				"skipped",
				false
			)
		)
	) or (
		bool(
			age_seed_report.get(
				"success",
				false
			)
		)
		and not bool(
			age_seed_report.get(
				"already_seeded",
				false
			)
		)
		and not bool(
			age_seed_report.get(
				"skipped",
				false
			)
		)
	)

	var relationship_authored_truth: bool = (
		int(
			relationship_seed_report.get(
				"seeded",
				0
			)
		) > 0
	)




	var runtime_structural_truth_changed: bool = (
		bool(
			runtime_report.get(
				"cycle_completed_now",
				false
			)
		)
		and (
			int(
				runtime_report.get(
					"changed",
					0
				)
			) > 0
			or int(
				runtime_report.get(
					"automatic_resolution_count",
					0
				)
			) > 0
		)
	)

	var should_publish_payload: bool = (
		actor_id > 0
		and (
			resident_payload.is_empty()
			or baseline_authored_truth
			or relationship_authored_truth
			or runtime_structural_truth_changed
		)
	)

	var list_payload: Dictionary = (
		resident_payload
	)

	if should_publish_payload:
		list_payload = build_pending_list_payload(
			actor_id
		)

		if not list_payload.is_empty():
			var next_revision_sequence: int = (
				int(
					pending_payload_revision_sequence_by_actor.get(
						actor_key,
						0
					)
				) + 1
			)

			pending_payload_revision_sequence_by_actor [
				actor_key
			] = next_revision_sequence



			list_payload = list_payload.duplicate(false)

			list_payload [
				"payload_revision_sequence"
			] = next_revision_sequence

			list_payload [
				"payload_revision"
			] = (
				"%d:%d"
				% [
					actor_id,
					next_revision_sequence
				]
			)

			list_payload [
				"payload_revision_authority"
			] = "pending_situations_engine"

			list_payload [
				"clock_cycle_completion_is_not_revision_authority"
			] = true

			list_payload [
				"player_idle_required"
			] = false

			if (
				gs != null
				and typeof(
					gs.scenario_state
				) != TYPE_DICTIONARY
			):
				gs.scenario_state = {}

			if gs != null:
				var payload_registry_raw: Variant = (
					gs.scenario_state.get(
						"resident_pending_situations_payload_by_actor",
						{}
					)
				)
				var payload_registry: Dictionary = (
					payload_registry_raw as Dictionary
					if typeof(payload_registry_raw) == TYPE_DICTIONARY
					else {}
				)

				payload_registry [
					actor_key
				] = list_payload

				gs.scenario_state [
					"resident_pending_situations_payload_by_actor"
				] = payload_registry

			_publish_pending_list_payload_observation_snapshot(
				actor_id,
				list_payload
			)

	var summary_contract: Dictionary = {}

	if typeof(
		list_payload.get(
			"summary_contract",
			{}
		)
	) == TYPE_DICTIONARY:
		summary_contract = (
			list_payload.get(
				"summary_contract",
				{}
			) as Dictionary
		).duplicate(false)

	if (
		summary_contract.is_empty()
		and actor_id > 0
		and should_publish_payload
	):
		summary_contract = (
			emit_pending_situations_summary_contract(
				{
					"source": (
						"pending_situations_runtime_tick"
					),
					"target_id": actor_id,
					"runtime_report": (
						runtime_report.duplicate(false)
					)
				}
			)
		)

	var changed_count: int = int(
		runtime_report.get(
			"changed",
			0
		)
	)
	changed_count += int(
		relationship_seed_report.get(
			"seeded",
			0
		)
	)

	if baseline_authored_truth:
		changed_count += 1

	last_report = {
		"success": true,
		"mode": (
			"pending_situations_engine_truth_driven_runtime_quantum"
		),
		"actor_id": actor_id,
		"changed": changed_count,
		"runtime_report": runtime_report.duplicate(false),
		"birth_seed_report": birth_seed_report.duplicate(false),
		"age_seed_report": age_seed_report.duplicate(false),
		"relationship_seed_report": (
			relationship_seed_report.duplicate(false)
		),
		"summary_contract": summary_contract.duplicate(false),
		"list_payload": list_payload.duplicate(false),
		"active_count": int(
			list_payload.get(
				"count",
				summary_contract.get(
					"count",
					0
				)
			)
		),
		"payload_publication_performed": (
			should_publish_payload
		),
		"payload_revision": str(
			list_payload.get(
				"payload_revision",
				""
			)
		),
		"resident_actor_scoped_payload_published": (
			not list_payload.is_empty()
		),
		"runtime_structural_truth_changed": (
			runtime_structural_truth_changed
		),
		"relationship_seed_quantum_limit": (
			MAX_RELATIONSHIP_HISTORY_SEED_INTENTS_PER_QUANTUM
		),
		"visible_click_work_required": false,
		"ready_gate_member": false,
		"player_idle_required": false,
		"ui_is_renderer_only": true,
		"updated_at_ms": now_ms
	}

	return last_report.duplicate(false)
func get_pending_count(target_id: int = -1) -> int:
	if gs == null or gs.scenario_runtime_contract_engine == null:
		return 0

	if target_id <= 0 and gs.player != null:
		target_id = int(gs.player.id)

	return gs.scenario_runtime_contract_engine.get_pending_count(target_id)

func _publish_pending_list_payload_observation_snapshot(
	target_id: int,
	payload: Dictionary
) -> void:
	if (
		target_id <= 0
		or payload.is_empty()
	):
		return







	var frozen_payload: Dictionary = (
		payload.duplicate(false)
	)

	frozen_payload [
		"immutable_observation_snapshot"
	] = true
	frozen_payload [
		"worker_safe_observation"
	] = true
	frozen_payload [
		"owner_thread_reconciled"
	] = true
	frozen_payload [
		"worker_may_not_mutate"
	] = true
	frozen_payload [
		"snapshot_actor_id"
	] = target_id
	frozen_payload [
		"snapshot_published_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	frozen_payload [
		"recursive_snapshot_copy_performed"
	] = false

	pending_list_observation_snapshot_mutex.lock()

	var next_registry: Dictionary = (
		pending_list_observation_snapshot_by_actor.duplicate(
			false
		)
	)

	next_registry [
		str(
			target_id
		)
	] = frozen_payload

	pending_list_observation_snapshot_by_actor = (
		next_registry
	)

	pending_list_observation_snapshot_mutex.unlock()


func _pending_list_payload_observation_snapshot(
	target_id: int
) -> Dictionary:


	if target_id <= 0:
		return {}

	pending_list_observation_snapshot_mutex.lock()

	var snapshot_raw: Variant = (
		pending_list_observation_snapshot_by_actor.get(
			str(
				target_id
			),
			{}
		)
	)
	var snapshot: Dictionary = (
		(snapshot_raw as Dictionary).duplicate(false)
		if typeof(snapshot_raw) == TYPE_DICTIONARY
		else {}
	)

	pending_list_observation_snapshot_mutex.unlock()

	if snapshot.is_empty():
		return {}



	snapshot [
		"worker_snapshot_read"
	] = true
	snapshot [
		"worker_snapshot_read_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	snapshot [
		"mutable_reconciliation_performed"
	] = false
	snapshot [
		"scenario_state_write_performed"
	] = false
	snapshot [
		"engine_commit_performed"
	] = false

	return snapshot
func build_pending_list_payload(
	target_id: int = -1
) -> Dictionary:










	var caller_thread_id: int = int(
		OS.get_thread_caller_id()
	)
	var main_thread_id: int = int(
		OS.get_main_thread_id()
	)

	if caller_thread_id != main_thread_id:
		return _pending_list_payload_observation_snapshot(
			target_id
		)

	_ensure_state()

	if (
		gs == null
		or gs.scenario_runtime_contract_engine == null
	):
		return {
			"success": false,
			"title": "Pending Situations",
			"actor_id": target_id,
			"count": 0,
			"summaries": [],
			"contracts": [],
			"category_groups": [],
			"summary_contract": {}
		}

	if (
		target_id <= 0
		and gs.player != null
	):
		target_id = int(
			gs.player.id
		)

	var actor: Person = _actor_by_id(
		target_id
	)

	if actor != null:
		seed_birth_starter_contracts_for_actor(
			actor,
			{
				"source": "build_pending_list_payload",
				"target_id": target_id
			}
		)

		if has_method(
			"seed_age_window_contracts_for_actor"
		):
			call(
				"seed_age_window_contracts_for_actor",
				actor,
				{
					"source": "build_pending_list_payload",
					"target_id": target_id
				}
			)

		if has_method(
			"seed_relationship_history_contracts_for_actor"
		):
			call(
				"seed_relationship_history_contracts_for_actor",
				actor,
				{
					"source": "build_pending_list_payload",
					"target_id": target_id
				}
			)

	var source_contracts: Array = (
		gs.scenario_runtime_contract_engine
		.get_pending_popup_contracts(
			target_id
		)
	)
	var visible_contracts: Array = []
	var summaries: Array = []

	for raw_contract in source_contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var source_contract: Dictionary = (
			raw_contract as Dictionary
		)
		var view_contract: Dictionary = (
			source_contract
		)

		if (
			gs.contract_view_layer_contract_engine != null
		):
			view_contract = (
				gs.contract_view_layer_contract_engine
				.build_view_contract(
					source_contract,
					actor,
					{
						"source": "pending_situations_payload",
						"viewer_actor_id": target_id
					}
				)
			)

		var item_contract: Dictionary = (
			_pending_item_contract_from_popup_contract(
				view_contract,
				target_id
			)
		)
		var item_id: String = str(
			item_contract.get(
				"id",
				""
			)
		).strip_edges()

		if item_id == "":
			continue

		var canonical_category: String = (
			_pending_category_key_for_contract(
				item_contract
			)
		)

		item_contract [
			"category"
		] = canonical_category
		view_contract [
			"category"
		] = canonical_category
		view_contract [
			"actor_id"
		] = target_id
		view_contract [
			"target_id"
		] = int(
			view_contract.get(
				"target_id",
				view_contract.get(
					"target",
					target_id
				)
			)
		)

		pending_situation_contracts [
			item_id
		] = item_contract

		visible_contracts.append(
			view_contract
		)

		summaries.append({
			"id": str(
				source_contract.get(
					"id",
					source_contract.get(
						"contract_id",
						""
					)
				)
			),
			"view_contract_id": str(
				view_contract.get(
					"view_contract_id",
					view_contract.get(
						"id",
						""
					)
				)
			),
			"source_contract_id": str(
				source_contract.get(
					"id",
					source_contract.get(
						"contract_id",
						""
					)
				)
			),
			"title": str(
				item_contract.get(
					"title",
					"Pending Situation"
				)
			),
			"overview": str(
				item_contract.get(
					"overview",
					""
				)
			),
			"category": canonical_category,
			"category_label": _pending_category_label(
				canonical_category
			),
			"urgency": float(
				item_contract.get(
					"urgency",
					0.0
				)
			),
			"state": str(
				item_contract.get(
					"state",
					"pending"
				)
			),
			"perspective": str(
				view_contract.get(
					"perspective",
					"self"
				)
			)
		})

	var category_groups: Array = (
		_pending_category_groups_for_summaries(
			summaries
		)
	)
	var summary_contract: Dictionary = (
		emit_pending_situations_summary_contract({
			"source": "build_pending_list_payload",
			"target_id": target_id,
			"summaries": summaries.duplicate(true),
			"contracts": visible_contracts.duplicate(true),
			"category_groups": category_groups.duplicate(true)
		})
	)

	_observe_summary_contract(
		summary_contract,
		"pending_list_payload"
	)

	var actor_name: String = "Unknown"

	if actor != null:
		actor_name = (
			"%s %s"
			% [
				str(
					actor.first_name
				),
				str(
					actor.last_name
				)
			]
		).strip_edges()

		if actor_name == "":
			actor_name = "Unknown"

	var payload: Dictionary = {
		"success": true,
		"title": "Pending Situations",
		"actor_id": target_id,
		"actor_name": actor_name,
		"count": summaries.size(),
		"summaries": summaries,
		"contracts": visible_contracts,
		"category_groups": category_groups,
		"summary_contract": summary_contract.duplicate(true),
		"era_name": _current_era_name(),
		"dominant_category": (
			_dominant_category_for_summaries(
				summaries
			)
		),
		"visible_click_work_required": false,
		"ready_gate_member": false,
		"built_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var payload_by_actor: Dictionary = (
		_safe_dictionary(
			gs.scenario_state.get(
				"resident_pending_situations_payload_by_actor",
				{}
			)
		)
	)

	payload_by_actor [
		str(
			target_id
		)
	] = payload.duplicate(false)

	gs.scenario_state [
		"resident_pending_situations_payload_by_actor"
	] = payload_by_actor
	gs.scenario_state [
		"pending_situations_zero_frame_actor_id"
	] = target_id
	gs.scenario_state [
		"pending_situations_zero_frame_count"
	] = summaries.size()
	gs.scenario_state [
		"pending_situations_zero_frame_ready"
	] = true




	_publish_pending_list_payload_observation_snapshot(
		target_id,
		payload
	)

	return payload
func _pending_category_groups_for_summaries(summaries: Array) -> Array:
	var groups: Dictionary = {}

	for raw_summary in summaries:
		if typeof(raw_summary) != TYPE_DICTIONARY:
			continue

		var summary: Dictionary = raw_summary as Dictionary
		var category_key: String = _pending_category_key_for_contract(summary)
		if category_key == "":
			category_key = "general"

		if not groups.has(category_key):
			groups [category_key] = {
				"key": category_key,
				"label": _pending_category_label(category_key),
				"count": 0,
				"max_urgency": 0.0,
				"summary_ids": [],
				"summaries": []
			}

		var group: Dictionary = groups [category_key]
		var summary_id: String = str(summary.get("id", summary.get("source_contract_id", ""))).strip_edges()
		if summary_id != "" and summary_id in group ["summary_ids"]:
			continue

		group ["count"] = int(group.get("count", 0)) + 1
		group ["max_urgency"] = max(float(group.get("max_urgency", 0.0)), float(summary.get("urgency", 0.0)))
		if summary_id != "":
			group ["summary_ids"].append(summary_id)
		group ["summaries"].append(summary.duplicate(true))
		groups [category_key] = group

	var out: Array = []
	for raw_key in groups.keys():
		out.append((groups [raw_key] as Dictionary).duplicate(true))

	out.sort_custom(Callable(self, "_sort_pending_category_group_rows"))
	return out


func _sort_pending_category_group_rows(a: Dictionary, b: Dictionary) -> bool:
	var priority_a: int = _pending_category_sort_priority(str(a.get("key", "general")))
	var priority_b: int = _pending_category_sort_priority(str(b.get("key", "general")))

	if priority_a == priority_b:
		var urgency_a: float = float(a.get("max_urgency", 0.0))
		var urgency_b: float = float(b.get("max_urgency", 0.0))
		if urgency_a == urgency_b:
			return str(a.get("label", "")) < str(b.get("label", ""))
		return urgency_a > urgency_b

	return priority_a < priority_b


func _pending_category_sort_priority(category_key: String) -> int:
	match str(category_key).strip_edges().to_lower():
		"deaths":
			return 0
		"danger":
			return 1
		"health":
			return 2
		"money":
			return 3
		"family":
			return 4
		"relationships":
			return 5
		"children":
			return 6
		"school":
			return 7
		"career":
			return 8
		"housing":
			return 9
		"belongings":
			return 10
		"legal":
			return 11
		"crime":
			return 12
		"romance":
			return 13
		"sports":
			return 14
		"royalty":
			return 15
		"supernatural":
			return 16
		"travel":
			return 17
		"world":
			return 18
		"social":
			return 19
		_:
			return 99


func _pending_category_key_for_contract(contract: Dictionary) -> String:
	var explicit_key: String = _pending_explicit_category_key(contract)
	if explicit_key != "":
		return explicit_key

	var category: String = str(contract.get("category", "")).strip_edges().to_lower()
	var request: String = str(contract.get("request", "")).strip_edges().to_lower()
	var title: String = str(contract.get("title", "")).strip_edges().to_lower()
	var overview: String = str(contract.get("overview", "")).strip_edges().to_lower()
	var details: String = str(contract.get("details", "")).strip_edges().to_lower()

	var joined: String = "%s %s %s %s %s" % [category, request, title, overview, details]

	if joined.find("somebody has died") >= 0 or _pending_text_has_any(joined, ["death", "funeral", "burial", "died", "dead", "grave"]):
		return "deaths"

	if joined.find("inheritance received") >= 0 \
or joined.find("left you") >= 0 \
or joined.find("in their will") >= 0 \
or joined.find("in the will") >= 0 \
or _pending_text_has_any(joined, ["inheritance", "finance", "finances", "bank", "loan", "debt", "cash", "payroll"]):
		return "money"

	if _pending_text_has_any(joined, ["medical", "health", "illness", "injury", "disease", "sick", "doctor", "hospital"]):
		return "health"

	if _pending_text_has_any(joined, ["danger", "threat", "safety", "war", "attack", "raid", "violence"]):
		return "danger"

	if _pending_text_has_any(joined, ["family", "parent", "parents", "sibling", "newborn", "guardian", "crib", "mother", "father"]):
		return "family"

	if _pending_text_has_any(joined, ["relationship", "friend", "neighbor", "bond"]):
		return "relationships"

	if _pending_text_has_any(joined, ["child", "baby", "pregnancy", "toddler"]):
		return "children"

	if _pending_text_has_any(joined, ["school", "teacher", "student", "classroom", "academy"]):
		return "school"

	if _pending_text_has_any(joined, ["career", "job", "work", "promotion", "boss"]):
		return "career"

	if _pending_text_has_any(joined, ["house", "home", "rent", "property", "housing", "shelter"]):
		return "housing"

	if _pending_text_has_any(joined, ["belonging", "belongings", "item", "inventory"]):
		return "belongings"

	if _pending_text_has_any(joined, ["legal", "court", "law", "trial"]):
		return "legal"

	if _pending_text_has_any(joined, ["crime", "police", "jail", "prison"]):
		return "crime"

	if _pending_text_has_any(joined, ["romance", "partner", "date", "marriage", "spouse"]):
		return "romance"

	if _pending_text_has_any(joined, ["boxing", "sport", "fight", "gym"]):
		return "sports"

	if _pending_text_has_any(joined, ["crown", "royal", "realm", "king", "queen", "throne"]):
		return "royalty"

	if _pending_text_has_any(joined, ["avatar", "bending", "power", "super", "magic", "stone"]):
		return "supernatural"

	if _pending_text_has_any(joined, ["travel", "trip", "journey"]):
		return "travel"

	if _pending_text_has_any(joined, ["world", "country", "nation", "village", "city"]):
		return "world"

	if _pending_text_has_any(joined, ["social", "party", "public", "crowd"]):
		return "social"

	return "general"
func _pending_explicit_category_key(contract: Dictionary) -> String:
	var field_order: Array = [
		"pending_category",
		"category_group",
		"category_key",
		"category"
	]

	for raw_field in field_order:
		var field: String = str(raw_field)
		var raw_value: String = str(contract.get(field, "")).strip_edges().to_lower()
		var normalized: String = _pending_normalized_category_key(raw_value)
		if normalized != "":
			return normalized

	return ""


func _pending_normalized_category_key(raw_category: String) -> String:
	var key: String = str(raw_category).strip_edges().to_lower()
	if key == "":
		return ""

	match key:
		"death", "deaths", "family_death", "family_death_notice", "family_death_pending", "funeral", "burial":
			return "deaths"
		"money", "finance", "finances", "family_finance", "family_finance_argument", "inheritance", "bank", "loan", "debt":
			return "money"
		"family", "family_newborn", "newborn", "newborn_attention", "newborn_sibling_attention", "family_pressure", "household":
			return "family"
		"relationship", "relationships", "friendship", "friends", "neighbors":
			return "relationships"
		"health", "medical", "illness", "injury":
			return "health"
		"danger", "safety", "threat":
			return "danger"
		"children", "child", "baby", "pregnancy":
			return "children"
		"school", "education":
			return "school"
		"career", "job", "work":
			return "career"
		"housing", "property", "home":
			return "housing"
		"belongings", "inventory", "items":
			return "belongings"
		"legal", "law", "court":
			return "legal"
		"crime", "criminal":
			return "crime"
		"romance", "dating", "marriage":
			return "romance"
		"sports", "boxing", "gym":
			return "sports"
		"royalty", "crown", "realm":
			return "royalty"
		"supernatural", "powers", "power", "bending", "avatar":
			return "supernatural"
		"travel":
			return "travel"
		"world":
			return "world"
		"social":
			return "social"
		"general":
			return "general"
		_:
			return ""


func _pending_text_has_any(text: String, needles: Array) -> bool:
	var normalized: String = (" %s " % str(text).strip_edges().to_lower())
	normalized = normalized.replace("_", " ")
	normalized = normalized.replace("-", " ")
	normalized = normalized.replace(".", " ")
	normalized = normalized.replace(",", " ")
	normalized = normalized.replace("!", " ")
	normalized = normalized.replace("?", " ")
	normalized = normalized.replace(":", " ")
	normalized = normalized.replace(";", " ")
	normalized = normalized.replace("\"", " ")
	normalized = normalized.replace("'", " ")

	while normalized.find("  ") >= 0:
		normalized = normalized.replace("  ", " ")

	for raw_needle in needles:
		var needle: String = str(raw_needle).strip_edges().to_lower()
		if needle == "":
			continue

		var padded_needle: String = " %s " % needle
		if normalized.find(padded_needle) >= 0:
			return true

	return false

func _pending_category_label(category_key: String) -> String:
	match str(category_key).strip_edges().to_lower():
		"deaths":
			return "Deaths"
		"money":
			return "Money"
		"health":
			return "Health"
		"danger":
			return "Danger"
		"family":
			return "Family"
		"relationships":
			return "Relationships"
		"children":
			return "Children"
		"school":
			return "School"
		"career":
			return "Career"
		"housing":
			return "Housing"
		"belongings":
			return "Belongings"
		"legal":
			return "Legal"
		"crime":
			return "Crime"
		"romance":
			return "Romance"
		"sports":
			return "Sports"
		"royalty":
			return "Royalty"
		"supernatural":
			return "Powers & Supernatural"
		"travel":
			return "Travel"
		"world":
			return "World"
		"social":
			return "Social"
		_:
			return "General"
func resolve_pending_contract(contract_id: String, option_id: String, payload: Dictionary = {}) -> Dictionary:
	_ensure_state()

	if gs == null or gs.scenario_popup_contract_engine == null:
		return {
			"success": false,
			"reason": "missing_scenario_popup_contract_engine"
		}

	# FIX: the UI may hand us a view id ("view_<source>_<viewer>") or an item id
	# ("pending_item:<source>") instead of the runtime source id. Normalize before
	# any lookup, otherwise resolution silently fails with contract_not_active.
	# Watch the resolution chain end to end. The original bug in this function was a
	# silent no-op: the click was swallowed and nothing anywhere reported it. If a
	# resolution starts and never reaches its report, the watchdog now says so.
	var requested_id: String = str(contract_id).strip_edges()

	EraLog.watch_begin(
		"pending_resolve:%s" % requested_id,
		"pending_situation_resolution"
	)
	var clean_id: String = _resolve_source_contract_id(requested_id)
	var clean_option: String = str(option_id).strip_edges()
	var actor_id: int = int(payload.get("viewer_actor_id", payload.get("perspective_actor_id", payload.get("target_id", -1))))

	var source_contract: Dictionary = {}
	if gs.scenario_runtime_contract_engine != null:
		source_contract = gs.scenario_runtime_contract_engine.get_contract(clean_id)

	var selected_option: Dictionary = _pending_selected_option_from_source_contract(source_contract, clean_option)

	var view_report: Dictionary = {}
	if gs.contract_view_layer_contract_engine != null and not source_contract.is_empty():
		view_report = gs.contract_view_layer_contract_engine.resolve_view_choice(source_contract, actor_id, clean_option, payload)

	var source_resolves: bool = true
	if not view_report.is_empty():
		source_resolves = bool(view_report.get("source_resolves", true))

	var report: Dictionary = {}
	if source_resolves:
		report = gs.scenario_popup_contract_engine.resolve_contract_response(clean_id, clean_option, payload)

		if not view_report.is_empty():
			report ["text"] = str(view_report.get("text", report.get("text", "")))
			report ["popup_title"] = str(view_report.get("popup_title", report.get("popup_title", "Situation Resolved")))
			report ["popup_text"] = str(view_report.get("popup_text", report.get("popup_text", "")))
			report ["popup_footer"] = str(view_report.get("popup_footer", report.get("popup_footer", "Tap anywhere to continue.")))
			report ["view_report"] = view_report.duplicate(true)
	else:
		report = {
			"success": true,
			"mode": "perspective_choice_recorded",
			"contract_id": clean_id,
			"option_id": clean_option,
			"text": str(view_report.get("text", "I made a choice from my perspective.")),
			"popup_title": str(view_report.get("popup_title", "Perspective Recorded")),
			"popup_text": str(view_report.get("popup_text", "This choice affected your perspective, but the shared situation still exists.")),
			"popup_footer": str(view_report.get("popup_footer", "Tap anywhere to continue.")),
			"view_report": view_report.duplicate(true)
		}

	var diary_records: Array = []
	if typeof(view_report.get("diary_records", [])) == TYPE_ARRAY:
		diary_records = (view_report.get("diary_records", []) as Array).duplicate(true)

	var bank_report: Dictionary = _bank_report_from_pending_resolution_report(report)

	report ["diary_records"] = diary_records
	EraLog.watch_end(
		"pending_resolve:%s" % requested_id
	)

	report ["requested_contract_id"] = requested_id
	report ["resolved_contract_id"] = clean_id
	report ["source_contract"] = source_contract.duplicate(true)
	report ["source_resolves"] = source_resolves
	report ["emotional_impact_contract"] = _safe_dictionary(view_report.get("emotional_impact_contract", {}))
	report ["emotional_application_report"] = _safe_dictionary(view_report.get("emotional_application_report", {}))
	report ["relationship_dna_updates"] = _safe_array(view_report.get("relationship_dna_updates", []))
	report ["future_behavior_intents"] = _safe_array(view_report.get("future_behavior_intents", []))
	report ["trait_growth_report"] = _safe_dictionary(view_report.get("trait_growth_report", {}))
	report ["identity_report"] = _safe_dictionary(view_report.get("identity_report", {}))
	if not bank_report.is_empty():
		report ["bank_report"] = bank_report.duplicate(true)
		report ["money_delta_report"] = bank_report.duplicate(true)

	var followup_report: Dictionary = {}
	if bool(report.get("success", false)) and source_resolves:
		followup_report = _emit_followup_pending_contract_from_option(selected_option, source_contract, actor_id, payload)
		if not followup_report.is_empty():
			report ["followup_pending_contract_report"] = followup_report.duplicate(true)

	_record_pending_mutation(clean_id, "resolved" if source_resolves else "perspective_choice_recorded", {
		"option_id": clean_option,
		"actor_id": actor_id,
		"source_resolves": source_resolves,
		"success": bool(report.get("success", false)),
		"diary_record_count": diary_records.size(),
		"emotional_impact_count": int(report.get("relationship_dna_updates", []).size()) if typeof(report.get("relationship_dna_updates", [])) == TYPE_ARRAY else 0,
		"future_behavior_intent_count": int(report.get("future_behavior_intents", []).size()) if typeof(report.get("future_behavior_intents", [])) == TYPE_ARRAY else 0,
		"trait_changed_count": _safe_array(_safe_dictionary(report.get("trait_growth_report", {})).get("changed_traits", [])).size(),
		"identity_refreshed": bool(_safe_dictionary(report.get("identity_report", {})).get("success", false)),
		"bank_delta": int(bank_report.get("bank_delta", 0)),
		"bank_balance": int(bank_report.get("balance", bank_report.get("new_balance", 0))),
		"followup_emitted": bool(followup_report.get("success", false)),
		"source": str(payload.get("source", "resolve_pending_contract"))
	})

	if bool(report.get("success", false)) and source_resolves:
		pending_situation_contracts.erase(clean_id)
		pending_situation_contracts.erase(requested_id)
		pending_situation_contracts.erase("pending_item:%s" % clean_id)
		for raw_key in pending_situation_contracts.keys():
			var item: Dictionary = _safe_dictionary(pending_situation_contracts.get(raw_key, {}))
			if str(item.get("source_contract_id", "")) == clean_id:
				pending_situation_contracts.erase(raw_key)
				break

	emit_pending_situations_summary_contract({
		"source": "resolve_pending_contract",
		"resolved_contract_id": clean_id,
		"source_resolves": source_resolves
	})

	# FIX: the pending viewer is repainted from the CACHED resident payload in
	# gs.scenario_state["resident_pending_situations_payload_by_actor"], and that cache
	# is only rebuilt by runtime_tick(). Without refreshing it here, a situation that
	# genuinely resolved stays on screen until the next tick — which looks exactly like
	# "I picked an option, it narrated, and nothing resolved".
	if bool(report.get("success", false)) and source_resolves and actor_id > 0:
		build_pending_list_payload(actor_id)

	_commit_state()
	return report
func _resolve_source_contract_id(raw_id: String) -> String:
	var clean_id: String = str(raw_id).strip_edges()
	if clean_id == "":
		return ""

	# 1. Already a live runtime contract.
	if gs != null and gs.scenario_runtime_contract_engine != null:
		if not _safe_dictionary(
			gs.scenario_runtime_contract_engine.get_contract(clean_id)
		).is_empty():
			return clean_id

	# 2. Pending item wrapper: "pending_item:<source_id>"
	if clean_id.begins_with("pending_item:"):
		var unwrapped: String = clean_id.substr("pending_item:".length())
		if unwrapped != "" and unwrapped != clean_id:
			return _resolve_source_contract_id(unwrapped)

	# 3. Per-viewer view contract: "view_<source_id>_<viewer_id>"
	if clean_id.begins_with("view_"):
		var body: String = clean_id.substr(5)
		var cut: int = body.rfind("_")
		if cut > 0 and body.substr(cut + 1).is_valid_int():
			var candidate: String = body.substr(0, cut)
			if candidate != "" and candidate != clean_id:
				return _resolve_source_contract_id(candidate)

	# 4. Alias lookup against the pending registry.
	for raw_key in pending_situation_contracts.keys():
		var item: Dictionary = _safe_dictionary(
			pending_situation_contracts.get(raw_key, {})
		)
		if item.is_empty():
			continue
		for alias_key in ["id", "contract_id", "view_contract_id", "source_contract_id"]:
			if str(item.get(alias_key, "")).strip_edges() == clean_id:
				var source_id: String = str(
					item.get("source_contract_id", item.get("contract_id", ""))
				).strip_edges()
				if source_id != "" and source_id != clean_id:
					return source_id

	return clean_id


func _bank_report_from_pending_resolution_report(report: Dictionary) -> Dictionary:
	if typeof(report) != TYPE_DICTIONARY:
		return {}

	var direct_report: Dictionary = _safe_dictionary(report.get("bank_report", {}))
	if not direct_report.is_empty():
		return direct_report

	var money_report: Dictionary = _safe_dictionary(report.get("money_delta_report", {}))
	if not money_report.is_empty():
		return money_report

	var resolution_report: Dictionary = _safe_dictionary(report.get("resolution_report", {}))
	var nested_bank_report: Dictionary = _safe_dictionary(resolution_report.get("bank_report", {}))
	if not nested_bank_report.is_empty():
		return nested_bank_report

	var nested_money_report: Dictionary = _safe_dictionary(resolution_report.get("money_delta_report", {}))
	if not nested_money_report.is_empty():
		return nested_money_report

	return {}
func _pending_selected_option_from_source_contract(source_contract: Dictionary, option_id: String) -> Dictionary:
	if typeof(source_contract) != TYPE_DICTIONARY:
		return {}

	var clean_option: String = str(option_id).strip_edges()
	var options: Array = _safe_array(source_contract.get("response_options", []))
	for raw_option in options:
		if typeof(raw_option) != TYPE_DICTIONARY:
			continue

		var option: Dictionary = raw_option as Dictionary
		if str(option.get("id", "")).strip_edges() == clean_option:
			return option.duplicate(true)

	return {}


func _emit_followup_pending_contract_from_option(option: Dictionary, source_contract: Dictionary, actor_id: int, payload: Dictionary = {}) -> Dictionary:
	if typeof(option) != TYPE_DICTIONARY or option.is_empty():
		return {}

	var followup_raw: Variant = option.get("followup_pending_contract", {})
	if typeof(followup_raw) != TYPE_DICTIONARY:
		return {}

	var followup: Dictionary = (followup_raw as Dictionary).duplicate(true)
	if followup.is_empty():
		return {}

	var followup_id: String = str(followup.get("id", followup.get("contract_id", ""))).strip_edges()
	if followup_id == "":
		followup_id = "followup_%s_%d" % [
			str(source_contract.get("id", source_contract.get("contract_id", "pending"))),
			int(Time.get_ticks_msec())
		]
		followup ["id"] = followup_id
		followup ["contract_id"] = followup_id

	if _runtime_has_pending_or_resolved_contract(followup_id):
		return {
			"success": true,
			"contract_id": followup_id
		}

	if actor_id > 0:
		followup ["target"] = int(followup.get("target", actor_id))
		followup ["target_id"] = int(followup.get("target_id", actor_id))

	if not followup.has("created_at_ms"):
		followup ["created_at_ms"] = int(Time.get_ticks_msec())
	followup ["updated_at_ms"] = int(Time.get_ticks_msec())
	followup ["source_parent_contract_id"] = str(source_contract.get("id", source_contract.get("contract_id", "")))
	followup ["source_parent_option_id"] = str(option.get("id", ""))

	return gs.scenario_popup_contract_engine.emit_popup_contract(followup, {
		"source": str(payload.get("source", "pending_followup_contract")),
		"target_id": actor_id
	})


func _runtime_has_pending_or_resolved_contract(contract_id: String) -> bool:
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "" or gs == null or gs.scenario_runtime_contract_engine == null:
		return false

	var existing: Dictionary = gs.scenario_runtime_contract_engine.get_contract(clean_id)
	return not existing.is_empty()
func emit_pending_situations_summary_contract(
	context: Dictionary = {}
) -> Dictionary:
	var target_id: int = int(
		context.get(
			"target_id",
			-1
		)
	)

	if (
		target_id <= 0
		and gs != null
		and gs.player != null
	):
		target_id = int(
			gs.player.id
		)

	var contracts: Array = []

	if typeof(
		context.get(
			"contracts",
			[]
		)
	) == TYPE_ARRAY:
		contracts = context.get(
			"contracts",
			[]
		)
	elif (
		gs != null
		and gs.scenario_runtime_contract_engine != null
	):
		contracts = (
			gs.scenario_runtime_contract_engine
			.get_pending_popup_contracts(
				target_id
			)
		)

	var summaries: Array = []

	if typeof(
		context.get(
			"summaries",
			[]
		)
	) == TYPE_ARRAY:
		summaries = context.get(
			"summaries",
			[]
		)
	else:
		for raw_contract in contracts:
			if typeof(raw_contract) != TYPE_DICTIONARY:
				continue

			var popup_contract: Dictionary = (
				raw_contract as Dictionary
			)
			var item_contract: Dictionary = (
				_pending_item_contract_from_popup_contract(
					popup_contract,
					target_id
				)
			)

			if item_contract.is_empty():
				continue

			var item_id: String = str(
				item_contract.get(
					"id",
					""
				)
			).strip_edges()

			pending_situation_contracts [
				item_id
			] = item_contract

			summaries.append({
				"id": item_id,
				"source_contract_id": str(
					item_contract.get(
						"source_contract_id",
						""
					)
				),
				"title": str(
					item_contract.get(
						"title",
						"Pending Situation"
					)
				),
				"overview": str(
					item_contract.get(
						"overview",
						""
					)
				),
				"category": str(
					item_contract.get(
						"category",
						"general"
					)
				),
				"urgency": float(
					item_contract.get(
						"urgency",
						0.0
					)
				),
				"state": str(
					item_contract.get(
						"state",
						"pending"
					)
				)
			})

	var max_urgency: float = 0.0

	for raw_summary in summaries:
		if typeof(raw_summary) != TYPE_DICTIONARY:
			continue

		max_urgency = max(
			max_urgency,
			float(
				(raw_summary as Dictionary).get(
					"urgency",
					0.0
				)
			)
		)

	var summary_id: String = (
		"pending_situations:%d"
		% target_id
	)
	var semantic_revision: String = str(
		hash(
			[
				target_id,
				summaries
			]
		)
	)

	if (
		not last_summary_contract.is_empty()
		and int(
			last_summary_contract.get(
				"target_id",
				-1
			)
		) == target_id
		and str(
			last_summary_contract.get(
				"semantic_revision",
				""
			)
		) == semantic_revision
	):
		var resident_summary: Dictionary = (
			last_summary_contract.duplicate(true)
		)
		resident_summary [
			"resident_summary_cache_hit"
		] = true
		resident_summary [
			"summary_rebuilt"
		] = false
		resident_summary [
			"state_commit_performed"
		] = false
		return resident_summary

	var summary_contract: Dictionary = {
		"schema": SUMMARY_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": summary_id,
		"contract_id": summary_id,
		"contract_type": "pending_situations_summary",
		"target_id": target_id,
		"title": "Pending Situations",
		"count": summaries.size(),
		"max_urgency": max_urgency,
		"state": "active",
		"summaries": summaries.duplicate(true),
		"source_contract_count": contracts.size(),
		"semantic_revision": semantic_revision,
		"resident_summary_cache_hit": false,
		"summary_rebuilt": true,
		"state_commit_performed": true,
		"created_at_ms": int(
			last_summary_contract.get(
				"created_at_ms",
				Time.get_ticks_msec()
			)
		),
		"updated_at_ms": int(
			Time.get_ticks_msec()
		),
		"source": str(
			context.get(
				"source",
				"pending_situations_engine"
			)
		),
		"contract_mesh": {
			"source_of_truth": (
				"PendingSituationsEngine"
			),
			"runtime_owner": (
				"ScenarioRuntimeContractEngine"
			),
			"popup_contract_owner": (
				"ScenarioPopupContractEngine"
			),
			"ui_observer": "PopupViewer",
			"persistent": true,
			"save_key": (
				"pending_situations_engine_state"
			)
		}
	}

	last_summary_contract = summary_contract

	pending_situation_index [
		summary_id
	] = {
		"target_id": target_id,
		"count": summaries.size(),
		"max_urgency": max_urgency,
		"semantic_revision": semantic_revision,
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_record_pending_mutation(
		summary_id,
		"summary_emitted",
		{
			"count": summaries.size(),
			"max_urgency": max_urgency,
			"semantic_revision": semantic_revision,
			"source": str(
				context.get(
					"source",
					"pending_situations_engine"
				)
			)
		}
	)


	_commit_state()

	return summary_contract.duplicate(true)
func seed_relationship_history_contracts_for_actor(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var source: String = str(
		context.get(
			"source",
			""
		)
	).strip_edges().to_lower()

	if (
		source == "build_pending_list_payload"
		or bool(
			context.get(
				"read_only_projection",
				false
			)
		)
		or bool(
			context.get(
				"simulation_mutation_forbidden",
				false
			)
		)
	):
		return {
			"success": true,
			"skipped": true,
			"reason": "projection_cannot_seed_simulation",
			"seeded": 0,
		}

	_ensure_state()

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor",
			"seeded": 0
		}

	if (
		gs == null
		or gs.scenario_popup_contract_engine == null
	):
		return {
			"success": false,
			"reason": "missing_scenario_popup_contract_engine",
			"seeded": 0
		}

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var intents_raw: Variant = (
		gs.scenario_state.get(
			"relationship_future_behavior_intents",
			{}
		)
	)

	if typeof(intents_raw) != TYPE_DICTIONARY:
		return {
			"success": true,
			"skipped": true,
			"reason": "no_future_behavior_intents",
			"seeded": 0
		}

	var intents: Dictionary = (
		intents_raw as Dictionary
	)

	if intents.is_empty():
		return {
			"success": true,
			"skipped": true,
			"reason": "no_future_behavior_intents",
			"seeded": 0
		}

	var actor_id: int = int(actor.id)
	var actor_key: String = str(actor_id)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var next_scan_ms: int = int(
		relationship_history_seed_next_scan_ms_by_actor.get(
			actor_key,
			0
		)
	)

	if now_ms < next_scan_ms:
		return {
			"success": true,
			"mode": "relationship_history_seed_quantum_throttled",
			"actor_id": actor_id,
			"seeded": 0,
			"skipped": 0,
			"next_scan_ms": next_scan_ms
		}

	var intent_ids: Array = intents.keys()
	var intent_count: int = intent_ids.size()

	if intent_count <= 0:
		relationship_history_seed_next_scan_ms_by_actor [
			actor_key
		] = now_ms + 1000

		return {
			"success": true,
			"mode": "relationship_history_seed_quantum_empty",
			"actor_id": actor_id,
			"seeded": 0,
			"skipped": 0,
		}

	var cursor: int = clampi(
		int(
			relationship_history_seed_cursor_by_actor.get(
				actor_key,
				0
			)
		),
		0,
		intent_count
	)
	var limit: int = clampi(
		int(
			context.get(
				"max_intents_per_quantum",
				MAX_RELATIONSHIP_HISTORY_SEED_INTENTS_PER_QUANTUM
			)
		),
		1,
		MAX_RELATIONSHIP_HISTORY_SEED_INTENTS_PER_QUANTUM
	)

	var current_year: int = int(gs.year)
	var seeded: int = 0
	var skipped: int = 0
	var processed: int = 0
	var reports: Array = []

	while (
		cursor < intent_count
		and processed < limit
	):
		var raw_intent_id: Variant = intent_ids [
			cursor
		]
		cursor += 1
		processed += 1

		var intent_id: String = str(
			raw_intent_id
		)
		var intent_raw: Variant = intents.get(
			raw_intent_id,
			{}
		)

		if typeof(intent_raw) != TYPE_DICTIONARY:
			skipped += 1
			continue


		var intent: Dictionary = (
			(intent_raw as Dictionary).duplicate(true)
		)

		if intent.is_empty():
			skipped += 1
			continue

		if str(
			intent.get(
				"state",
				"watching"
			)
		).strip_edges().to_lower() in [
			"consumed",
			"retired",
			"disabled"
		]:
			skipped += 1
			continue

		if int(
			intent.get(
				"owner_actor_id",
				-1
			)
		) != actor_id:
			skipped += 1
			continue

		if int(actor.age) < int(
			intent.get(
				"eligible_age_min",
				0
			)
		):
			skipped += 1
			continue

		var cooldown_years: int = max(
			1,
			int(
				intent.get(
					"cooldown_years",
					2
				)
			)
		)
		var last_emitted_year: int = int(
			intent.get(
				"last_emitted_year",
				-999999
			)
		)

		if (
			current_year - last_emitted_year
			< cooldown_years
		):
			skipped += 1
			continue

		var contract: Dictionary = (
			_relationship_history_pending_contract_from_intent(
				actor,
				intent,
				context
			)
		)

		if contract.is_empty():
			skipped += 1
			continue

		var contract_id: String = str(
			contract.get(
				"id",
				contract.get(
					"contract_id",
					""
				)
			)
		).strip_edges()

		if (
			contract_id == ""
			or _runtime_has_pending_or_resolved_contract(
				contract_id
			)
		):
			skipped += 1
			continue

		var emit_report: Dictionary = (
			gs.scenario_popup_contract_engine
			.emit_popup_contract(
				contract,
				{
					"source": str(
						context.get(
							"source",
							"relationship_future_behavior_seed"
						)
					),
					"target_id": actor_id
				}
			)
		)

		if bool(
			emit_report.get(
				"success",
				false
			)
		):
			seeded += 1
			intent ["last_emitted_year"] = current_year
			intent ["times_emitted"] = int(
				intent.get(
					"times_emitted",
					0
				)
			) + 1
			intent ["updated_at_ms"] = int(
				Time.get_ticks_msec()
			)


			intents [intent_id] = intent
			reports.append(
				emit_report.duplicate(false)
			)
		else:
			skipped += 1

	var scan_complete: bool = (
		cursor >= intent_count
	)

	if scan_complete:
		relationship_history_seed_cursor_by_actor [
			actor_key
		] = 0
		relationship_history_seed_next_scan_ms_by_actor [
			actor_key
		] = now_ms + 1000
	else:
		relationship_history_seed_cursor_by_actor [
			actor_key
		] = cursor


	gs.scenario_state [
		"relationship_future_behavior_intents"
	] = intents

	if seeded > 0:
		_record_pending_mutation(
			"relationship_future_behavior:%d"
			% actor_id,
			"relationship_history_seeded",
			{
				"actor_id": actor_id,
				"seeded": seeded,
				"skipped": skipped,
				"processed": processed,
				"scan_complete": scan_complete,
				"source": str(
					context.get(
						"source",
						"relationship_future_behavior_seed"
					)
				)
			}
		)


		_commit_state()

	return {
		"success": true,
		"mode": "relationship_history_contracts_seed_quantum",
		"actor_id": actor_id,
		"seeded": seeded,
		"skipped": skipped,
		"processed": processed,
		"cursor": (
			0
			if scan_complete
			else cursor
		),
		"intent_count": intent_count,
		"scan_complete": scan_complete,
		"reports": reports.duplicate(false),
		"max_intents_per_quantum": limit
	}

func _relationship_history_pending_contract_from_intent(actor: Person, intent: Dictionary, _context: Dictionary = {}) -> Dictionary:
	if actor == null or typeof(intent) != TYPE_DICTIONARY or intent.is_empty():
		return {}

	var actor_id: int = int(actor.id)
	var target_id: int = int(intent.get("target_actor_id", -1))
	if actor_id <= 0 or target_id <= 0 or actor_id == target_id:
		return {}

	var target: Person = _actor_by_id(target_id)
	if target == null:
		return {}

	var arc_type: String = str(intent.get("arc_type", "relationship_history")).strip_edges().to_lower()
	var era_name: String = _current_era_name()
	var era_context: String = _relationship_history_era_context_sentence(arc_type, era_name)
	var contract_id: String = "relationship_history_%s_%d_%d_%d" % [arc_type, actor_id, target_id, int(gs.year) if gs != null else 0]

	var title: String = _relationship_history_title_for_intent(actor, target, intent, era_name)
	var overview: String = _relationship_history_overview_for_intent(actor, target, intent, era_name)
	var details: String = "%s %s" % [overview, era_context]
	details = details.strip_edges()

	return {
		"schema": "eralife.pending_situation.relationship_history_contract",
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"contract_type": "scenario_popup",
		"target": actor_id,
		"target_id": actor_id,
		"issuer": target_id,
		"issuer_id": target_id,
		"participant_ids": _unique_positive_int_array([actor_id, target_id]),
		"decision_actor_ids": [actor_id],
		"audience_ids": [actor_id],
		"category": _relationship_history_category_for_arc(arc_type),
		"pending_category": _relationship_history_category_for_arc(arc_type),
		"category_group": _relationship_history_category_for_arc(arc_type),
		"request": "relationship_future_behavior:%s" % arc_type,
		"title": title,
		"overview": overview,
		"details": details,
		"state": "pending",
		"visibility": "participant_visible",
		"requires_attention": true,
		"response_options": _relationship_history_response_options(actor, target, intent, era_name),
		"selected_response": "",
		"resolution": {},
		"urgency": clamp(30.0 + float(intent.get("intensity", 0.0)) * 0.65, 35.0, 92.0),
		"decay": 0.08,
		"escalation_stage": 0,
		"escalation_triggers": [],
		"next_escalation_ms": int(Time.get_ticks_msec()) + 22000,
		# FIX: was -1.0 (never expires). Nothing resolves a contract on an NPC's
		# behalf, so these accumulated for the whole life. See
		# PENDING_CONTRACT_DEFAULT_EXPIRY_YEARS.
		"expires_age": float(actor.age) + PENDING_CONTRACT_DEFAULT_EXPIRY_YEARS,
		"created_year": int(gs.year) if gs != null else 0,
		"created_age": float(actor.age),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"source": "relationship_future_behavior_intent",
		"source_future_behavior_intent": intent.duplicate(true),
		"relationship_arc_type": arc_type,
		"relationship_target_id": target_id,
		"relationship_target_name": _first_name_for_actor(target),
		"era_emotional_context": _era_emotional_context_profile(era_name),
		"contract_mesh": {
			"source_of_truth": "PendingSituationsEngine",
			"future_behavior_intent_owner": "ContractViewLayerContractEngine",
			"popup_contract_owner": "ScenarioPopupContractEngine",
			"runtime_owner": "ScenarioRuntimeContractEngine",
			"view_layer_owner": "ContractViewLayerContractEngine",
			"ui_mutation_allowed": false,
			"persistent": true,
			"save_key": "scenario_runtime_contract_engine_state"
		}
	}


func _relationship_history_title_for_intent(_actor: Person, target: Person, intent: Dictionary, _era_name: String) -> String:
	var target_name: String = _first_name_for_actor(target)
	match str(intent.get("arc_type", "")).strip_edges().to_lower():
		"long_term_grudge":
			return "Old tension with %s resurfaces" % target_name
		"sibling_rivalry":
			return "%s is celebrating again..." % target_name
		"favoritism_wound":
			return "It feels like %s gets treated differently" % target_name
		"protective_bond":
			return "%s may need you" % target_name
		"neglect_memory":
			return "An old lonely feeling returns"
		"uneasy_history":
			return "%s makes you uneasy" % target_name
		_:
			return "Something old between you and %s returns" % target_name


func _relationship_history_overview_for_intent(_actor: Person, target: Person, intent: Dictionary, _era_name: String) -> String:
	var target_name: String = _first_name_for_actor(target)
	match str(intent.get("arc_type", "")).strip_edges().to_lower():
		"long_term_grudge":
			return "Something about %s brings back an old hurt. What will you do?" % target_name
		"sibling_rivalry":
			return "%s is being praised, and the old comparison is hard to ignore. What will you do?" % target_name
		"favoritism_wound":
			return "You feel like someone keeps choosing %s first. What will you do?" % target_name
		"protective_bond":
			return "%s is caught in a difficult moment, and part of you wants to step in. What will you do?" % target_name
		"neglect_memory":
			return "A familiar feeling of being overlooked comes back. What will you do?"
		"uneasy_history":
			return "%s is nearby, and your body remembers the tension. What will you do?" % target_name
		_:
			return "A shared history with %s is affecting this moment. What will you do?" % target_name


func _relationship_history_response_options(_actor: Person, target: Person, intent: Dictionary, era_name: String) -> Array:
	var target_name: String = _first_name_for_actor(target)
	var arc_type: String = str(intent.get("arc_type", "")).strip_edges().to_lower()

	match arc_type:
		"long_term_grudge":
			return [
				{
					"id": "defend_them_anyway",
					"label": _era_action_label("Defend them anyway", era_name),
					"source_resolves": true,
					"priority": 72,
					"journal_text": "I defended %s even though old tension still lived between us." % target_name,
					"result_text": "You defend %s anyway. The old hurt does not vanish, but something shifts." % target_name,
					"emotional_impact": { "trust": 7, "comfort": 4, "resentment": -8, "respect": 4}
				},
				{
					"id": "stay_silent",
					"label": "Stay silent",
					"source_resolves": true,
					"priority": 35,
					"journal_text": "I stayed silent when %s might have needed me." % target_name,
					"result_text": "You stay silent. The silence becomes part of the history.",
					"emotional_impact": { "resentment": 5, "trust": -5, "perceived_unfairness": 4}
				},
				{
					"id": "bring_up_old_hurt",
					"label": "Bring up old hurt",
					"source_resolves": true,
					"priority": 40,
					"journal_text": "I brought up an old hurt with %s." % target_name,
					"result_text": "You bring up the old hurt. The moment gets heavier.",
					"emotional_impact": { "resentment": 9, "stress": 6, "trust": -4, "humiliation": 3}
				}
			]
		"sibling_rivalry":
			return [
				{
					"id": "congratulate_them",
					"label": "Congratulate them",
					"source_resolves": true,
					"priority": 70,
					"journal_text": "I congratulated %s even though part of me felt compared to them." % target_name,
					"result_text": "You congratulate %s. The rivalry cools for now." % target_name,
					"emotional_impact": { "envy": -8, "respect": 5, "comfort": 3, "trust": 2}
				},
				{
					"id": "make_sarcastic_comment",
					"label": "Make a sarcastic comment",
					"source_resolves": true,
					"priority": 38,
					"journal_text": "I made a sarcastic comment while %s was being celebrated." % target_name,
					"result_text": "You make a sarcastic comment. It lands exactly where the rivalry lives.",
					"emotional_impact": { "envy": 7, "resentment": 6, "trust": -4, "humiliation": 4}
				},
				{
					"id": "try_to_outdo_them",
					"label": "Try to outdo them",
					"source_resolves": true,
					"priority": 45,
					"journal_text": "I decided I needed to outdo %s." % target_name,
					"result_text": "You turn the moment into fuel.",
					"emotional_impact": { "envy": 5, "pride": 4, "stress": 3}
				}
			]
		"favoritism_wound":
			return [
				{
					"id": "say_it_out_loud",
					"label": "Say it out loud",
					"source_resolves": true,
					"priority": 54,
					"journal_text": "I said it felt like %s was treated better than me." % target_name,
					"result_text": "You say it out loud. Nobody can pretend the feeling is not there anymore.",
					"emotional_impact": { "perceived_unfairness": 4, "stress": 3, "trust": -2}
				},
				{
					"id": "swallow_the_feeling",
					"label": "Swallow the feeling",
					"source_resolves": true,
					"priority": 30,
					"journal_text": "I swallowed the feeling that %s was treated better than me." % target_name,
					"result_text": "You swallow it. The feeling does not disappear; it stores itself.",
					"emotional_impact": { "perceived_neglect": 6, "resentment": 5, "comfort": -4}
				},
				{
					"id": "ask_for_reassurance",
					"label": "Ask for reassurance",
					"source_resolves": true,
					"priority": 68,
					"journal_text": "I asked for reassurance instead of letting the feeling rot inside me.",
					"result_text": "You ask for reassurance. The answer matters.",
					"emotional_impact": { "trust": 4, "comfort": 5, "perceived_neglect": -5}
				}
			]
		"protective_bond":
			return [
				{
					"id": "step_in",
					"label": _era_action_label("Step in", era_name),
					"source_resolves": true,
					"priority": 75,
					"journal_text": "I stepped in for %s because something in me wanted to protect them." % target_name,
					"result_text": "You step in for %s. The bond gets another quiet layer." % target_name,
					"emotional_impact": { "trust": 6, "protectiveness": 7, "comfort": 4}
				},
				{
					"id": "watch_first",
					"label": "Watch first",
					"source_resolves": true,
					"priority": 45,
					"journal_text": "I watched before deciding whether %s needed me." % target_name,
					"result_text": "You watch first. The bond stays careful.",
					"emotional_impact": { "curiosity": 3, "protectiveness": 2}
				}
			]
		_:
			return [
				{
					"id": "respond_gently",
					"label": "Respond gently",
					"source_resolves": true,
					"priority": 60,
					"journal_text": "I responded gently to %s." % target_name,
					"result_text": "You respond gently.",
					"emotional_impact": { "trust": 3, "comfort": 3}
				},
				{
					"id": "pull_back",
					"label": "Pull back",
					"source_resolves": true,
					"priority": 35,
					"journal_text": "I pulled back from %s." % target_name,
					"result_text": "You pull back.",
					"emotional_impact": { "comfort": -3, "perceived_neglect": 3}
				}
			]


func _relationship_history_category_for_arc(arc_type: String) -> String:
	match str(arc_type).strip_edges().to_lower():
		"sibling_rivalry", "favoritism_wound", "protective_bond", "neglect_memory":
			return "family"
		_:
			return "relationships"


func _relationship_history_era_context_sentence(arc_type: String, era_name: String) -> String:
	var era_key: String = str(era_name).strip_edges().to_lower()
	var arc_key: String = str(arc_type).strip_edges().to_lower()

	if era_key.find("ancient") >= 0:
		return "In this era, family memory travels through fireside stories, clan duty, and who stands beside whom when the tribe watches."
	if era_key.find("medieval") >= 0:
		return "In this era, household loyalty, honor, inheritance, and public shame can turn small feelings into lasting family politics."
	if era_key.find("industrial") >= 0:
		return "In this era, money pressure, factory schedules, crowded homes, and survival stress make old emotions harder to hide."
	if era_key.find("future") >= 0:
		return "In this era, feeds, records, implants, and household monitors can preserve emotional patterns long after everyone pretends they moved on."

	match arc_key:
		"long_term_grudge":
			return "The present moment is carrying an old emotional receipt."
		"sibling_rivalry":
			return "The comparison is not new. It has just found a new outfit."
		"favoritism_wound":
			return "The facts may be debatable, but the feeling is not."
		"protective_bond":
			return "Something older than the moment is telling you to care."
		_:
			return "The moment feels bigger because history is standing inside it."


func _era_action_label(label: String, era_name: String) -> String:
	var era_key: String = str(era_name).strip_edges().to_lower()
	var clean_label: String = str(label).strip_edges()

	if era_key.find("ancient") >= 0:
		if clean_label == "Defend them anyway":
			return "Stand beside them"
		if clean_label == "Step in":
			return "Step between them"
	elif era_key.find("medieval") >= 0:
		if clean_label == "Defend them anyway":
			return "Speak for their honor"
		if clean_label == "Step in":
			return "Intervene"
	elif era_key.find("industrial") >= 0:
		if clean_label == "Defend them anyway":
			return "Back them up"
		if clean_label == "Step in":
			return "Get involved"
	elif era_key.find("future") >= 0:
		if clean_label == "Defend them anyway":
			return "Override the silence"
		if clean_label == "Step in":
			return "Intervene directly"

	return clean_label


func _era_emotional_context_profile(era_name: String) -> Dictionary:
	var era_key: String = str(era_name).strip_edges().to_lower()

	if era_key.find("ancient") >= 0:
		return {
			"era": era_name,
			"dominant_pressure": "survival_and_clan_loyalty",
			"amplifies": ["protectiveness", "fear", "trust"],
			"flavor": "Small family moments can become tribe memory."
		}
	if era_key.find("medieval") >= 0:
		return {
			"era": era_name,
			"dominant_pressure": "honor_household_rank_and_public_shame",
			"amplifies": ["respect", "resentment", "perceived_unfairness"],
			"flavor": "Family emotion is tangled with duty, name, and reputation."
		}
	if era_key.find("industrial") >= 0:
		return {
			"era": era_name,
			"dominant_pressure": "money_labor_and_crowded_home_stress",
			"amplifies": ["stress", "resentment", "perceived_neglect"],
			"flavor": "Pressure makes every small slight feel louder."
		}
	if era_key.find("future") >= 0:
		return {
			"era": era_name,
			"dominant_pressure": "surveillance_records_and_identity_systems",
			"amplifies": ["suspicion", "curiosity", "perceived_neglect"],
			"flavor": "The future remembers too much and explains too little."
		}

	return {
		"era": era_name,
		"dominant_pressure": "modern_family_psychology",
		"amplifies": ["trust", "comfort", "identity"],
		"flavor": "People may move on out loud while carrying the feeling privately."
	}
func seed_birth_starter_contracts_for_actor(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var source: String = str(
		context.get(
			"source",
			""
		)
	).strip_edges().to_lower()

	if (
		source == "build_pending_list_payload"
		or bool(
			context.get(
				"read_only_projection",
				false
			)
		)
		or bool(
			context.get(
				"simulation_mutation_forbidden",
				false
			)
		)
	):
		return {
			"success": true,
			"skipped": true,
			"reason": "projection_cannot_seed_simulation",
		}

	_ensure_state()

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	if (
		gs == null
		or gs.scenario_popup_contract_engine == null
	):
		return {
			"success": false,
			"reason": "missing_scenario_popup_contract_engine"
		}

	var actor_id: int = int(actor.id)

	if actor_id <= 0:
		return {
			"success": false,
			"reason": "invalid_actor_id"
		}

	var actor_key: String = str(actor_id)

	if bool(
		birth_starter_seeded_actor_ids.get(
			actor_key,
			false
		)
	):
		return {
			"success": true,
			"already_seeded": true,
			"actor_id": actor_id
		}

	if (
		float(actor.age) > 0.01
		and not bool(
			context.get(
				"force_seed",
				false
			)
		)
	):
		return {
			"success": true,
			"skipped": true,
			"reason": "actor_not_newborn",
			"actor_id": actor_id
		}

	var contract: Dictionary = (
		_build_birth_starter_contract_for_actor(
			actor,
			context
		)
	)

	if contract.is_empty():
		return {
			"success": false,
			"reason": "starter_contract_empty",
			"actor_id": actor_id
		}

	var emit_report: Dictionary = (
		gs.scenario_popup_contract_engine
		.emit_popup_contract(
			contract,
			{
				"source": str(
					context.get(
						"source",
						"birth_starter_seed"
					)
				),
				"target_id": actor_id
			}
		)
	)

	if bool(
		emit_report.get(
			"success",
			false
		)
	):
		birth_starter_seeded_actor_ids [
			actor_key
		] = true

		_record_pending_mutation(
			str(
				contract.get(
					"id",
					""
				)
			),
			"birth_starter_seeded",
			{
				"actor_id": actor_id,
				"era": _current_era_name(),
				"social_class": str(
					actor.social_class
				),
				"source": str(
					context.get(
						"source",
						"birth_starter_seed"
					)
				)
			}
		)
		_commit_state()

	return emit_report
func seed_age_window_contracts_for_actor(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var source: String = str(
		context.get(
			"source",
			""
		)
	).strip_edges().to_lower()

	if (
		source == "build_pending_list_payload"
		or bool(
			context.get(
				"read_only_projection",
				false
			)
		)
		or bool(
			context.get(
				"simulation_mutation_forbidden",
				false
			)
		)
	):
		return {
			"success": true,
			"skipped": true,
			"reason": "projection_cannot_seed_simulation",
		}

	_ensure_state()

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	if (
		gs == null
		or gs.scenario_popup_contract_engine == null
	):
		return {
			"success": false,
			"reason": "missing_scenario_popup_contract_engine"
		}

	var actor_id: int = int(actor.id)

	if actor_id <= 0:
		return {
			"success": false,
			"reason": "invalid_actor_id"
		}

	var window_id: String = (
		_pending_age_window_id_for_actor(
			actor
		)
	)

	if window_id == "":
		return {
			"success": true,
			"skipped": true,
			"reason": "no_age_window_pending_situation",
			"actor_id": actor_id
		}

	var seed_key: String = (
		"age_window:%d:%s"
		% [
			actor_id,
			window_id
		]
	)

	if bool(
		birth_starter_seeded_actor_ids.get(
			seed_key,
			false
		)
	):
		return {
			"success": true,
			"already_seeded": true,
			"actor_id": actor_id,
			"window_id": window_id
		}

	var contract: Dictionary = (
		_build_age_window_contract_for_actor(
			actor,
			window_id,
			context
		)
	)

	if contract.is_empty():
		return {
			"success": false,
			"reason": "age_window_contract_empty",
			"actor_id": actor_id,
			"window_id": window_id
		}

	var emit_report: Dictionary = (
		gs.scenario_popup_contract_engine
		.emit_popup_contract(
			contract,
			{
				"source": str(
					context.get(
						"source",
						"age_window_seed"
					)
				),
				"target_id": actor_id
			}
		)
	)

	if bool(
		emit_report.get(
			"success",
			false
		)
	):
		birth_starter_seeded_actor_ids [
			seed_key
		] = true

		_record_pending_mutation(
			str(
				contract.get(
					"id",
					""
				)
			),
			"age_window_seeded",
			{
				"actor_id": actor_id,
				"window_id": window_id,
				"era": _current_era_name(),
				"source": str(
					context.get(
						"source",
						"age_window_seed"
					)
				)
			}
		)
		_commit_state()

	return emit_report
func _pending_age_window_id_for_actor(actor: Person) -> String:
	if actor == null:
		return ""

	var age_value: int = int(actor.age)
	if age_value >= 2 and age_value <= 5:
		return "toddler_finance_argument"

	return ""


func _build_age_window_contract_for_actor(actor: Person, window_id: String, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	match str(window_id):
		"toddler_finance_argument":
			return _build_family_finance_argument_contract(actor, context)
		_:
			return {}


func _build_family_finance_argument_contract(actor: Person, context: Dictionary = {}) -> Dictionary:
	var actor_id: int = int(actor.id)
	var parent_ids: Array = _parent_ids_for_actor(actor)
	var participant_ids: Array = _starter_participant_ids_for_actor(actor)
	var role_map: Dictionary = _starter_actor_roles_for_actor(actor, parent_ids)
	var selected: Dictionary = _family_finance_argument_seed(actor)
	var contract_id: String = "age_window_finance_argument_%d_%d" % [actor_id, int(gs.year) if gs != null else 0]

	return {
		"schema": BIRTH_STARTER_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"contract_type": "scenario_popup",
		"target": actor_id,
		"target_id": actor_id,
		"issuer": -1,
		"issuer_id": -1,
		"participant_ids": participant_ids,
		"decision_actor_ids": participant_ids,
		"parent_ids": parent_ids,
		"perspective_actor_roles": role_map,
		"category": "family_finance",
		"request": "multi_perspective_family_argument",
		"title": "Parents arguing about finances",
		"overview": "Your parents are yelling at each other over something called \"Finances\" again. What will you do?",
		"details": "Your parents are yelling at each other over something called \"Finances\" again. What will you do?",
		"state": "pending",
		"visibility": "participant_visible",
		"requires_attention": true,
		"response_options": _finance_child_options_for_actor(actor),
		"selected_response": "",
		"resolution": {},
		"urgency": 46.0,
		"decay": 0.12,
		"escalation_stage": 0,
		"escalation_triggers": [],
		"next_escalation_ms": int(Time.get_ticks_msec()) + 30000,
		# FIX: was -1.0 (never expires). Nothing resolves a contract on an NPC's
		# behalf, so these accumulated for the whole life. See
		# PENDING_CONTRACT_DEFAULT_EXPIRY_YEARS.
		"expires_age": float(actor.age) + PENDING_CONTRACT_DEFAULT_EXPIRY_YEARS,
		"visible_age_min": 2.0,
		"visible_age_max": -1.0,
		"created_year": int(gs.year) if gs != null else 0,
		"created_age": float(actor.age),
		"created_at_ms": int(Time.get_ticks_msec()),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"source": str(context.get("source", "age_window_family_finance_argument")),
		"perspective_views": _starter_parent_views_for_actor(actor, selected),
		"follow_up_views": _starter_follow_up_views_for_actor(actor, selected),
		"shared_decision_model": {
			"mode": "asynchronous_decision_collision",
		},
		"contract_mesh": {
			"source_of_truth": "PendingSituationsEngine",
			"popup_contract_owner": "ScenarioPopupContractEngine",
			"runtime_owner": "ScenarioRuntimeContractEngine",
			"view_layer_owner": "ContractViewLayerContractEngine",
			"ui_observer": "PopupViewer",
			"one_contract_multiple_views": true,
			"ui_mutation_allowed": false,
			"persistent": true,
			"save_key": "scenario_runtime_contract_engine_state"
		}
	}


func _family_finance_argument_seed(actor: Person) -> Dictionary:
	return {
		"id": "modern_finance_argument_age_window",
		"category": "family_finance",
		"request": "multi_perspective_family_argument",
		"title": "Parents arguing about finances",
		"child_title": "Your parents are yelling about \"Finances\"",
		"child_overview": "Your parents are yelling at each other over something called \"Finances\" again. What will you do?",
		"child_details": "Your parents are yelling at each other over something called \"Finances\" again. What will you do?",
		"child_options": _finance_child_options_for_actor(actor),
		"mother_options": _finance_parent_opening_options("mother"),
		"father_options": _finance_parent_opening_options("father"),
		"guardian_options": _finance_parent_opening_options("guardian"),
		"urgency": 46.0,
		"decay": 0.12,
		"tags": ["modern", "finance", "family", "age_window"]
	}


func _finance_child_options_for_actor(actor: Person) -> Array:
	var options: Array = [
		{
			"id": "stay_quiet",
			"label": "Stay Quiet",
			"source_resolves": false,
			"priority": 20,
			"journal_text": "I stayed quiet while my parents argued about finances.",
			"result_text": "You stay quiet. The argument keeps living in the room."
		},
		{
			"id": "ask_what_finances_mean",
			"label": "Ask what \"Finances\" mean",
			"source_resolves": false,
			"priority": 22,
			"journal_text": "I asked what finances mean.",
			"result_text": "You ask what \"Finances\" mean. The room gets awkward for a second."
		},
		{
			"id": "start_crying",
			"label": "Start Crying",
			"source_resolves": false,
			"priority": 24,
			"journal_text": "I started crying while my parents argued.",
			"result_text": "You start crying. The argument pauses, but the problem does not disappear."
		}
	]

	if actor != null and int(actor.age) >= 18:
		options.append({
			"id": "offer_own_money",
			"label": "Offer your own money",
			"source_resolves": true,
			"priority": 70,
			"journal_text": "I offered my own money to help with the household finances.",
			"result_text": "You offer your own money. The household pressure drops for now."
		})

	return options


func _finance_parent_opening_options(_parent_role: String) -> Array:
	return [
		{
			"id": "make_budget_plan",
			"label": "Try to make a plan",
			"source_resolves": false,
			"priority": 78,
			"journal_text": "I tried to turn the money argument into a plan.",
			"result_text": "You try to make a plan. The other parent still has to respond."
		},
		{
			"id": "snap_back",
			"label": "Snap back",
			"source_resolves": false,
			"priority": 45,
			"journal_text": "I snapped back during the money argument.",
			"result_text": "You snap back. The argument gets sharper."
		},
		{
			"id": "walk_away",
			"label": "Walk away",
			"source_resolves": false,
			"priority": 25,
			"journal_text": "I walked away from the money argument.",
			"result_text": "You walk away. The argument is not solved."
		}
	]


func _finance_parent_follow_up_options() -> Array:
	return [
		{
			"id": "accept_plan",
			"label": "Accept the plan",
			"source_resolves": true,
			"priority": 86,
			"journal_text": "We cooled the argument down and made a money plan.",
			"popup_title": "Argument Cooled Down",
			"result_text": "The argument cools down. The household still has pressure, but nobody is yelling now."
		},
		{
			"id": "apologize",
			"label": "Apologize",
			"source_resolves": true,
			"priority": 80,
			"journal_text": "I apologized and helped calm the money argument.",
			"popup_title": "Argument Softened",
			"result_text": "You apologize. The argument softens, and the house feels less tense."
		},
		{
			"id": "argue_back",
			"label": "Argue back",
			"source_resolves": false,
			"priority": 30,
			"journal_text": "I argued back and made the money fight worse.",
			"popup_title": "Argument Escalated",
			"result_text": "You argue back. The situation is still unresolved."
		}
	]
func _build_birth_starter_contract_for_actor(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	var era_name: String = (
		_current_era_name()
	)
	var social_class: String = str(
		actor.social_class
	).strip_edges()
	var starter_pool: Array = (
		_birth_starter_pool_for_context(
			actor,
			era_name,
			social_class
		)
	)

	if starter_pool.is_empty():
		return {}

	var selected: Dictionary = (
		_weighted_birth_starter_pick(
			actor,
			starter_pool,
			context
		)
	)

	if selected.is_empty():
		return {}

	var actor_id: int = int(
		actor.id
	)
	var parent_ids: Array = (
		_parent_ids_for_actor(
			actor
		)
	)
	var participant_ids: Array = (
		_birth_starter_participant_ids_for_actor(
			actor,
			selected
		)
	)
	var audience_ids: Array = (
		_birth_starter_audience_ids_for_actor(
			actor,
			selected,
			participant_ids
		)
	)
	var parent_views: Dictionary = (
		_starter_parent_views_for_actor(
			actor,
			selected
		)
	)
	var role_map: Dictionary = (
		_starter_actor_roles_for_actor(
			actor,
			parent_ids,
			selected
		)
	)
	var decision_actor_ids: Array = (
		_birth_starter_decision_actor_ids_for_actor(
			actor,
			selected,
			participant_ids
		)
	)
	var shared_decision_contract: bool = (
		decision_actor_ids.size() > 1
	)
	var contract_id: String = (
		"birth_starter_%d_%d"
		% [
			actor_id,
			int(
				gs.year
				if gs != null
				else 0
			)
		]
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	return {
		"schema": BIRTH_STARTER_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"contract_id": contract_id,
		"contract_type": "scenario_popup",
		"target": actor_id,
		"target_id": actor_id,
		"issuer": -1,
		"issuer_id": -1,
		"participant_ids": participant_ids,
		"audience_ids": audience_ids,
		"decision_actor_ids": decision_actor_ids,
		"perspective_action_actor_ids": (
			decision_actor_ids.duplicate(true)
		),
		"pending_visibility_policy": (
			"decision_actor_only"
		),
		"parent_ids": parent_ids,
		"perspective_actor_roles": role_map,
		"category": str(
			selected.get(
				"category",
				"family_pressure"
			)
		),
		"request": str(
			selected.get(
				"request",
				"birth_starter_pressure"
			)
		),
		"title": str(
			selected.get(
				"title",
				"A new pressure enters your life"
			)
		),
		"overview": str(
			selected.get(
				"child_overview",
				selected.get(
					"overview",
					""
				)
			)
		),
		"details": str(
			selected.get(
				"child_details",
				selected.get(
					"details",
					selected.get(
						"overview",
						""
					)
				)
			)
		),
		"amount": int(
			selected.get(
				"amount",
				0
			)
		),
		"currency": str(
			selected.get(
				"currency",
				"USD"
			)
		),
		"state": "pending",
		"visibility": "participant_visible",
		"requires_attention": true,
		"response_options": _safe_array(
			selected.get(
				"child_options",
				[
					{
						"id": "stay_quiet",
						"label": "Stay quiet",
						"source_resolves": false
					},
					{
						"id": "ask_whats_wrong",
						"label": "Ask what is wrong",
						"source_resolves": false
					}
				]
			)
		),
		"selected_response": "",
		"resolution": {},
		"urgency": float(
			selected.get(
				"urgency",
				36.0
			)
		),
		"decay": float(
			selected.get(
				"decay",
				0.12
			)
		),
		"escalation_stage": 0,
		"escalation_triggers": _safe_array(
			selected.get(
				"escalation_triggers",
				[]
			)
		),
		"next_escalation_ms": (
			now_ms
			+ int(
				selected.get(
					"escalates_after_ms",
					30000
				)
			)
		),
		# FIX: pool entries never set expires_age, so it defaulted to -1.0 (never
		# expires) and household situations owned by the parents piled up for the
		# whole life. Default to a window of game years from the actor's current age;
		# a pool entry can still override it explicitly.
		"expires_age": float(
			selected.get(
				"expires_age",
				float(actor.age) + BIRTH_STARTER_DEFAULT_EXPIRY_YEARS
			)
		),
		"deadline_default_option_id": str(
			selected.get(
				"deadline_default_option_id",
				""
			)
		),
		"visible_age_min": float(
			selected.get(
				"visible_age_min",
				-1.0
			)
		),
		"visible_age_max": float(
			selected.get(
				"visible_age_max",
				-1.0
			)
		),
		"created_year": int(
			gs.year
			if gs != null
			else 0
		),
		"created_age": float(
			actor.age
		),
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"source": "birth_starter_contract",
		"starter_weighting": {
			"era": era_name,
			"social_class": social_class,
			"fame": _actor_fame_value(
				actor
			),
			"household_size": participant_ids.size(),
			"family_money": int(
				actor.bank_balance
			),
			"country_stability": (
				_country_stability_score()
			)
		},
		"shared_decision_model": {
			"enabled": shared_decision_contract,
			"mode": (
				"asynchronous_decision_collision"
				if shared_decision_contract
				else "single_actor_unresolved_decision"
			),
			"child_choices_record_perspective_only": (
				shared_decision_contract
			),
			"parent_choices_can_chain_to_partner": (
				shared_decision_contract
			),
			"parent_follow_up_can_resolve_source": (
				shared_decision_contract
			),
			"conflict_policy": (
				"highest_priority_then_latest"
				if shared_decision_contract
				else "target_actor_owns_decision"
			),
			"resolution_priority": (
				[
					"guardian",
					"mother",
					"father",
					"self",
					"child"
				]
				if shared_decision_contract
				else [
					"child",
					"self"
				]
			)
		},
		"perspective_views": parent_views,
		"follow_up_views": (
			_starter_follow_up_views_for_actor(
				actor,
				selected
			)
		),
		"emotional_impact_rules": (
			_starter_emotional_impact_rules_for_actor(
				actor,
				selected
			)
		),
		"future_behavior_seed": {
			"enabled": true,
			"source": "birth_starter_contract",
		},
		"era_emotional_context": (
			_era_emotional_context_profile(
				era_name
			)
		),
		"contract_mesh": {
			"source_of_truth": (
				"PendingSituationsEngine"
			),
			"popup_contract_owner": (
				"ScenarioPopupContractEngine"
			),
			"runtime_owner": (
				"ScenarioRuntimeContractEngine"
			),
			"view_layer_owner": (
				"ContractViewLayerContractEngine"
			),
			"ui_observer": "PopupViewer",
			"one_contract_multiple_views": (
				shared_decision_contract
			),
			"ui_mutation_allowed": false,
			"persistent": true,
			"save_key": (
				"scenario_runtime_contract_engine_state"
			),
		}
	}
func _starter_emotional_impact_rules_for_actor(_actor: Person, selected: Dictionary) -> Dictionary:
	var request_key: String = str(selected.get("request", "")).strip_edges().to_lower()
	var era_name: String = _current_era_name()

	if request_key == "newborn_sibling_attention":
		return {
			"schema": "eralife.pending_situation.emotional_impact_rules",
			"version": CONTRACT_VERSION,
			"era": era_name,
			"default": {
				"curiosity": 2
			},
			"by_option": {
				"smile": {
					"trust": 3,
					"comfort": 5,
					"affection": 4,
					"suspicion": -10,
					"curiosity": 6
				},
				"blink_slowly": {
					"comfort": 2,
					"curiosity": 8,
					"suspicion": -4
				},
				"stare_back": {
					"curiosity": 10,
					"suspicion": 4,
					"envy": 2
				},
				"start_crying": {
					"stress": 7,
					"fear": 3,
					"protectiveness": 4
				}
			},
			"by_owner_role": {
				"mother": {
					"protectiveness": 3
				},
				"father": {
					"protectiveness": 3
				},
				"guardian": {
					"protectiveness": 3
				},
				"brother": {
					"curiosity": 2
				},
				"sister": {
					"curiosity": 2
				},
				"sibling": {
					"curiosity": 2
				}
			}
		}

	return {
		"schema": "eralife.pending_situation.emotional_impact_rules",
		"version": CONTRACT_VERSION,
		"era": era_name,
		"default": {
			"curiosity": 1
		},
		"by_option": {},
		"by_owner_role": {}
	}
func _birth_starter_pool_for_context(actor: Person, era_name: String, social_class: String) -> Array:
	var era_key: String = str(era_name).strip_edges().to_lower()
	var class_key: String = str(social_class).strip_edges().to_lower()
	var pool: Array = []

	for newborn_entry in _newborn_family_entries_for_actor(actor):
		if typeof(newborn_entry) == TYPE_DICTIONARY:
			pool.append(newborn_entry)

	if era_key.find("ancient") >= 0:
		pool.append({
			"id": "ancient_food_shortage",
			"title": "Your tribe is low on food",
			"overview": "The adults are speaking quietly about food running low.",
			"child_overview": "The home feels tense. Food is not guaranteed.",
			"mother_overview": "The household needs food and the child depends on you.",
			"father_overview": "The tribe is low on food and your family expects you to provide.",
			"urgency": 48.0,
			"decay": 0.14,
			"tags": ["ancient", "food", "survival", "family"]
		})
		pool.append({
			"id": "ancient_war_expectation",
			"title": "Your father is expected to go to war",
			"overview": "War talk moves through the family like smoke.",
			"child_overview": "You hear adults mention war and your family name.",
			"father_overview": "The tribe expects you to fight.",
			"urgency": 58.0,
			"decay": 0.1,
			"tags": ["ancient", "war", "father", "duty"]
		})
		pool.append({
			"id": "ancient_rival_clan",
			"title": "A rival clan is watching your family",
			"overview": "A rival clan has started watching your household.",
			"child_overview": "Strangers keep looking toward your home.",
			"urgency": 42.0,
			"decay": 0.12,
			"tags": ["ancient", "rival", "danger"]
		})
	elif era_key.find("medieval") >= 0:
		pool.append({
			"id": "medieval_crown_taxes",
			"title": "Your family owes taxes to the crown",
			"overview": "The crown expects payment from your household.",
			"child_overview": "Your family seems afraid of a tax collector.",
			"mother_overview": "Taxes are due and the household has limited options.",
			"father_overview": "The crown expects payment and your family is watching you.",
			"urgency": 52.0,
			"decay": 0.13,
			"tags": ["medieval", "tax", "crown"]
		})
		pool.append({
			"id": "medieval_mother_ill",
			"title": "Your mother is ill with no healer nearby",
			"overview": "Illness has entered the household.",
			"child_overview": "Your mother looks weaker than usual.",
			"mother_overview": "You are ill and still expected to hold the household together.",
			"urgency": 62.0,
			"decay": 0.16,
			"tags": ["medieval", "illness", "mother"]
		})
		pool.append({
			"id": "medieval_village_threat",
			"title": "Your village is under threat",
			"overview": "People whisper that danger is close to the village.",
			"child_overview": "The village feels afraid.",
			"urgency": 54.0,
			"decay": 0.11,
			"tags": ["medieval", "village", "threat"]
		})
	elif era_key.find("industrial") >= 0:
		pool.append({
			"id": "industrial_factory_danger",
			"title": "Your parents work dangerous factory jobs",
			"overview": "Factory work keeps the household alive, but it is dangerous.",
			"child_overview": "Your parents come home tired from dangerous work.",
			"mother_overview": "The factory pays, but every shift costs your body.",
			"father_overview": "Factory work is dangerous, but the family needs money.",
			"urgency": 50.0,
			"decay": 0.15,
			"tags": ["industrial", "factory", "danger"]
		})
		pool.append({
			"id": "industrial_child_labor",
			"title": "Child labor opportunity available",
			"overview": "A small job could bring money into the household.",
			"child_overview": "Adults mention you may be old enough to help earn.",
			"urgency": 45.0,
			"decay": 0.12,
			"tags": ["industrial", "labor", "poverty"]
		})
		pool.append({
			"id": "industrial_family_debt",
			"title": "Family debt increasing weekly",
			"overview": "Debt is rising faster than money comes in.",
			"child_overview": "Money talk keeps making the house quiet.",
			"urgency": 56.0,
			"decay": 0.18,
			"tags": ["industrial", "debt", "family"]
		})
	elif era_key.find("future") >= 0:
		pool.append({
			"id": "future_genetic_enhancement",
			"title": "Genetic enhancement decision pending",
			"overview": "Your household has been offered a genetic enhancement decision.",
			"child_overview": "Adults are deciding something about your future body.",
			"mother_overview": "The enhancement offer could change your child's future.",
			"father_overview": "The household must decide whether enhancement is worth the cost.",
			"urgency": 46.0,
			"decay": 0.08,
			"tags": ["future", "genetics", "choice"]
		})
		pool.append({
			"id": "future_ai_guardian",
			"title": "AI guardian assigned to your household",
			"overview": "An AI guardian has been assigned to monitor household welfare.",
			"child_overview": "A voice in the home keeps checking on you.",
			"urgency": 34.0,
			"decay": 0.05,
			"tags": ["future", "ai", "household"]
		})
		pool.append({
			"id": "future_social_score_risk",
			"title": "Social score risk detected",
			"overview": "Your household has triggered a social score risk warning.",
			"child_overview": "Adults are worried about how the world sees your family.",
			"urgency": 52.0,
			"decay": 0.14,
			"tags": ["future", "social_score", "risk"]
		})
	else:
		pool.append({
			"id": "modern_medical_bills",
			"title": "Medical bills unpaid",
			"overview": "Medical bills are sitting unpaid.",
			"child_overview": "Your family seems worried about something medical.",
			"mother_overview": "Medical bills are unpaid and your child depends on you.",
			"father_overview": "Medical bills are unpaid and the household expects action.",
			"urgency": 54.0,
			"decay": 0.16,
			"tags": ["modern", "medical", "debt"]
		})
		pool.append({
			"id": "modern_neighborhood_safety",
			"title": "Neighborhood safety concerns",
			"overview": "The neighborhood feels less safe lately.",
			"child_overview": "People are telling you to be careful outside.",
			"urgency": 38.0,
			"decay": 0.1,
			"tags": ["modern", "safety", "neighborhood"]
		})

	if class_key in ["wealthy", "upper", "upper class", "rich", "elite"]:
		pool.append({
			"id": "wealth_public_image_risk",
			"title": "Public image risk",
			"overview": "Your family reputation is already under pressure.",
			"child_overview": "Adults keep saying your family must look perfect.",
			"mother_overview": "One wrong move could damage the family image.",
			"father_overview": "Your family name carries expectations.",
			"urgency": 40.0,
			"decay": 0.08,
			"tags": ["wealth", "image", "reputation"]
		})
	else:
		pool.append({
			"id": "poor_eviction_risk",
			"title": "Eviction risk",
			"overview": "Housing pressure is sitting over the household.",
			"child_overview": "The adults seem scared about where everyone will live.",
			"mother_overview": "Rent is behind and your child needs a home.",
			"father_overview": "The household may lose housing if something does not change.",
			"urgency": 60.0,
			"decay": 0.18,
			"tags": ["poverty", "housing", "family"]
		})

	return pool
func _newborn_family_entries_for_actor(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	var siblings: Array = _siblings_for_actor(actor)
	for sibling in siblings:
		if not (sibling is Person):
			continue

		var sibling_person: Person = sibling
		var sibling_relation: String = _sibling_relation_label(sibling_person)
		var sibling_first_name: String = _first_name_for_actor(sibling_person)
		var sibling_label: String = ("%s %s" % [sibling_relation, sibling_first_name]).strip_edges()
		var mood: String = _newborn_sibling_mood(actor, sibling_person)
		var sibling_id: int = int(sibling_person.id)

		out.append({
			"id": "newborn_sibling_staring_%d" % sibling_id,
			"category": "family_newborn",
			"pending_category": "family",
			"category_group": "family",
			"request": "newborn_sibling_attention",
			"title": "%s is staring at you in your crib..." % sibling_label.capitalize(),
			"overview": "%s keeps staring into your crib." % sibling_label.capitalize(),
			"child_overview": "Ever since your parents brought you home from the hospital, your %s has been staring at you with %s. What will you do?" % [sibling_label, mood],
			"child_details": "Ever since your parents brought you home from the hospital, your %s has been staring at you with %s. What will you do?" % [sibling_label, mood],
			"featured_relative_id": sibling_id,
			"featured_relative_name": sibling_first_name,
			"featured_relative_relation": sibling_relation,
			"child_options": _newborn_sibling_child_options(sibling_relation, sibling_first_name),
			"urgency": 28.0,
			"decay": 0.02,
			"tags": ["newborn", "sibling", "family"]
		})

	out.append({
		"id": "newborn_room_full_of_faces",
		"category": "family_newborn",
		"pending_category": "family",
		"category_group": "family",
		"request": "newborn_attention",
		"title": "Everyone keeps making faces at you...",
		"overview": "People keep leaning over you and making strange noises.",
		"child_overview": "Everyone keeps leaning over you, smiling, gasping, and making noises that do not sound like language yet. What will you do?",
		"child_details": "Everyone keeps leaning over you, smiling, gasping, and making noises that do not sound like language yet. What will you do?",
		"child_options": [
			{ "id": "look_confused", "label": "Look confused", "source_resolves": true, "priority": 15, "journal_text": "I looked confused at everyone making faces at me.", "result_text": "You look confused. The adults somehow think this is adorable."},
			{ "id": "fall_asleep", "label": "Fall asleep", "source_resolves": true, "priority": 18, "journal_text": "I fell asleep while everyone stared at me.", "result_text": "You fall asleep. Excellent newborn boundary setting."},
			{ "id": "tiny_sneeze", "label": "Tiny sneeze", "source_resolves": true, "priority": 20, "journal_text": "I sneezed while everyone stared at me.", "result_text": "You sneeze. The room reacts like you performed a miracle."}
		],
		"urgency": 20.0,
		"decay": 0.01,
		"tags": ["newborn", "family", "funny"]
	})

	return out
func _newborn_sibling_child_options(sibling_relation: String, sibling_first_name: String) -> Array:
	var relation: String = str(sibling_relation).strip_edges().to_lower()
	if relation == "":
		relation = "sibling"

	var first_name: String = str(sibling_first_name).strip_edges()
	if first_name == "":
		first_name = "Someone"

	var sibling_label: String = ("%s %s" % [relation, first_name]).strip_edges()
	var _sibling_label_title: String = sibling_label.capitalize()

	return [
		{
			"id": "blink_slowly",
			"label": "Blink slowly",
			"source_resolves": true,
			"priority": 22,
			"journal_text": "I blinked slowly at my %s from the crib." % sibling_label,
			"result_text": "You blink slowly. Your %s seems confused, but less suspicious." % sibling_label
		},
		{
			"id": "start_crying",
			"label": "Start crying",
			"source_resolves": true,
			"priority": 18,
			"journal_text": "I started crying when my %s stared at me." % sibling_label,
			"result_text": "You start crying. Your %s immediately becomes part of the room-wide emergency." % sibling_label
		},
		{
			"id": "stare_back",
			"label": "Stare back",
			"source_resolves": true,
			"priority": 26,
			"journal_text": "I stared back at my %s from the crib." % sibling_label,
			"result_text": "You stare back. The crib rivalry between you and your %s has officially begun." % sibling_label
		},
		{
			"id": "smile",
			"label": "Smile",
			"source_resolves": true,
			"priority": 30,
			"journal_text": "I smiled at my %s from the crib." % sibling_label,
			"result_text": "You smile. Your %s seems confused, but less suspicious." % sibling_label
		}
	]
func _weighted_birth_starter_pick(actor: Person, pool: Array, _context: Dictionary = {}) -> Dictionary:
	if pool.is_empty():
		return {}

	var rng:= RandomNumberGenerator.new()
	rng.seed = abs(int(hash("%d|%d|%s|birth_starter" % [
		int(actor.id),
		int(gs.year) if gs != null else 0,
		str(actor.social_class)
	])))

	var total_weight: float = 0.0
	var weighted: Array = []

	for raw_entry in pool:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = raw_entry as Dictionary
		var weight: float = _starter_weight_for_actor(actor, entry)
		if weight <= 0.0:
			continue

		total_weight += weight
		weighted.append({
			"entry": entry.duplicate(true),
			"weight": weight
		})

	if weighted.is_empty():
		return {}

	var roll: float = rng.randf_range(0.0, total_weight)
	var cursor: float = 0.0

	for raw_weighted in weighted:
		var row: Dictionary = raw_weighted as Dictionary
		cursor += float(row.get("weight", 0.0))
		if roll <= cursor:
			return _safe_dictionary(row.get("entry", {}))

	return _safe_dictionary((weighted [weighted.size() - 1] as Dictionary).get("entry", {}))


func _starter_weight_for_actor(actor: Person, entry: Dictionary) -> float:
	var weight: float = 10.0
	var tags: Array = _safe_array(entry.get("tags", []))
	var class_key: String = str(actor.social_class).strip_edges().to_lower()
	var fame_value: int = _actor_fame_value(actor)
	var family_money: int = int(actor.bank_balance)
	var household_size: int = _starter_participant_ids_for_actor(actor).size()

	if "newborn" in tags and int(actor.age) <= 0:
		weight += 42.0

	if "poverty" in tags or "debt" in tags or "housing" in tags or "food" in tags:
		if class_key in ["poor", "lower", "lower class", "commoner", "working class"] or family_money < 10000:
			weight += 18.0
		else:
			weight -= 5.0

	if "wealth" in tags or "image" in tags or "reputation" in tags:
		if class_key in ["wealthy", "upper", "upper class", "rich", "elite"] or fame_value >= 45:
			weight += 16.0
		else:
			weight -= 7.0

	if "family" in tags and household_size >= 3:
		weight += 6.0

	if "medical" in tags and _country_stability_score() < 45:
		weight += 8.0

	return max(1.0, weight)


func _starter_participant_ids_for_actor(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	var actor_id: int = int(actor.id)
	if actor_id > 0:
		out.append(actor_id)

	for raw_parent_id in actor.parents:
		var parent_id: int = int(raw_parent_id)
		if parent_id > 0 and parent_id not in out:
			out.append(parent_id)

	return out

func _starter_role_view_is_explicit(
	selected: Dictionary,
	role: String
) -> bool:
	var clean_role: String = str(
		role
	).strip_edges().to_lower()

	if clean_role == "":
		return false

	for suffix in [
		"title",
		"overview",
		"details",
		"options"
	]:
		if selected.has(
			"%s_%s" % [
				clean_role,
				str(suffix)
			]
		):
			return true

	var explicit_views: Dictionary = _safe_dictionary(
		selected.get(
			"perspective_views",
			{}
		)
	)

	return explicit_views.has(
		clean_role
	)


func _birth_starter_is_shared_decision_contract(
	selected: Dictionary
) -> bool:
	var request: String = str(
		selected.get(
			"request",
			""
		)
	).strip_edges().to_lower()
	var tags: Array = _safe_array(
		selected.get(
			"tags",
			[]
		)
	)

	return (
		request == "multi_perspective_family_argument"
		or bool(
			selected.get(
				"shared_decision_contract",
				false
			)
		)
		or "finance" in tags
	)
func _starter_parent_views_for_actor(
	actor: Person,
	selected: Dictionary
) -> Dictionary:
	var parent_ids: Array = (
		_parent_ids_for_actor(
			actor
		)
	)
	var mother_id: int = (
		_parent_id_for_gender(
			parent_ids,
			"female"
		)
	)
	var father_id: int = (
		_parent_id_for_gender(
			parent_ids,
			"male"
		)
	)
	var mother_partner_name: String = (
		_first_name_for_actor_id(
			father_id
		)
	)
	var father_partner_name: String = (
		_first_name_for_actor_id(
			mother_id
		)
	)

	if mother_partner_name == "":
		mother_partner_name = "Your partner"

	if father_partner_name == "":
		father_partner_name = "Your partner"

	var child_options: Array = _safe_array(
		selected.get(
			"child_options",
			[
				{
					"id": "stay_quiet",
					"label": "Stay quiet",
					"source_resolves": false
				},
				{
					"id": "ask_whats_wrong",
					"label": "Ask what is wrong",
					"source_resolves": false
				},
				{
					"id": "try_to_help",
					"label": "Try to help",
					"source_resolves": false
				}
			]
		)
	)
	var is_shared_finance_argument: bool = (
		_birth_starter_is_shared_decision_contract(
			selected
		)
	)
	var views: Dictionary = {
		"child": {
			"title": str(
				selected.get(
					"child_title",
					selected.get(
						"title",
						"A pressure surrounds your family"
					)
				)
			),
			"overview": str(
				selected.get(
					"child_overview",
					selected.get(
						"overview",
						""
					)
				)
			),
			"details": str(
				selected.get(
					"child_details",
					selected.get(
						"child_overview",
						selected.get(
							"overview",
							""
						)
					)
				)
			),
			"response_options": child_options,
			"information_control": {
				"truth_level": (
					"limited_child_perspective"
				),
			}
		},
		"self": {
			"title": str(
				selected.get(
					"title",
					"Pending Situation"
				)
			),
			"overview": str(
				selected.get(
					"overview",
					""
				)
			),
			"details": str(
				selected.get(
					"details",
					selected.get(
						"overview",
						""
					)
				)
			),
			"response_options": _safe_array(
				selected.get(
					"response_options",
					child_options
				)
			)
		}
	}

	if is_shared_finance_argument:
		views [
			"mother"
		] = {
			"title": (
				"%s is arguing with you..."
				% mother_partner_name
			),
			"overview": (
				"Your partner %s is arguing with you "
				+ "that the household does not have enough "
				+ "money. How will you respond?"
			) % mother_partner_name,
			"details": (
				"Your partner %s is arguing with you "
				+ "that the household does not have enough "
				+ "money. How will you respond?"
			) % mother_partner_name,
			"response_options": _safe_array(
				selected.get(
					"mother_options",
					_finance_parent_opening_options(
						"mother"
					)
				)
			),
			"information_control": {
				"truth_level": (
					"guardian_operational_truth"
				),
			}
		}
		views [
			"father"
		] = {
			"title": (
				"%s is arguing with you..."
				% father_partner_name
			),
			"overview": (
				"Your partner %s is arguing with you "
				+ "that the household does not have enough "
				+ "money. How will you respond?"
			) % father_partner_name,
			"details": (
				"Your partner %s is arguing with you "
				+ "that the household does not have enough "
				+ "money. How will you respond?"
			) % father_partner_name,
			"response_options": _safe_array(
				selected.get(
					"father_options",
					_finance_parent_opening_options(
						"father"
					)
				)
			),
			"information_control": {
				"truth_level": (
					"guardian_operational_truth"
				),
			}
		}
		views [
			"guardian"
		] = {
			"title": str(
				selected.get(
					"guardian_title",
					"Household financial pressure"
				)
			),
			"overview": str(
				selected.get(
					"guardian_overview",
					(
						"The household is under financial "
						+ "pressure. How will you respond?"
					)
				)
			),
			"details": str(
				selected.get(
					"guardian_details",
					selected.get(
						"guardian_overview",
						(
							"The household is under financial "
							+ "pressure. How will you respond?"
						)
					)
				)
			),
			"response_options": _safe_array(
				selected.get(
					"guardian_options",
					_finance_parent_opening_options(
						"guardian"
					)
				)
			),
			"information_control": {
				"truth_level": (
					"guardian_operational_truth"
				),
			}
		}

		return views



	for raw_role in [
		"mother",
		"father",
		"guardian"
	]:
		var role: String = str(
			raw_role
		)

		if not _starter_role_view_is_explicit(
			selected,
			role
		):
			continue

		views [
			role
		] = {
			"title": str(
				selected.get(
					"%s_title" % role,
					"Pending Situation"
				)
			),
			"overview": str(
				selected.get(
					"%s_overview" % role,
					""
				)
			),
			"details": str(
				selected.get(
					"%s_details" % role,
					selected.get(
						"%s_overview" % role,
						""
					)
				)
			),
			"response_options": _safe_array(
				selected.get(
					"%s_options" % role,
					[]
				)
			),
			"information_control": {
				"truth_level": (
					"explicit_actor_perspective"
				),
			}
		}

	return views
func _birth_starter_decision_actor_ids_for_actor(
	actor: Person,
	selected: Dictionary,
	participant_ids: Array
) -> Array:
	var out: Array = []

	if actor == null:
		return out

	var target_id: int = int(
		actor.id
	)

	if target_id > 0:
		out.append(
			target_id
		)

	var parent_ids: Array = (
		_parent_ids_for_actor(
			actor
		)
	)
	var shared_decision_contract: bool = (
		_birth_starter_is_shared_decision_contract(
			selected
		)
	)

	for raw_parent_id in parent_ids:
		var parent_id: int = int(
			raw_parent_id
		)

		if (
			parent_id <= 0
			or parent_id not in participant_ids
		):
			continue

		var parent: Person = _actor_by_id(
			parent_id
		)
		var role: String = "guardian"

		if parent != null:
			var gender_key: String = str(
				parent.gender
			).strip_edges().to_lower()

			if gender_key == "female":
				role = "mother"
			elif gender_key == "male":
				role = "father"

		if (
			shared_decision_contract
			or _starter_role_view_is_explicit(
				selected,
				role
			)
		):
			if parent_id not in out:
				out.append(
					parent_id
				)

	var explicit_decision_actor_ids: Array = _safe_array(
		selected.get(
			"decision_actor_ids",
			[]
		)
	)

	for raw_explicit_id in explicit_decision_actor_ids:
		var explicit_id: int = int(
			raw_explicit_id
		)

		if (
			explicit_id > 0
			and explicit_id in participant_ids
			and explicit_id not in out
		):
			out.append(
				explicit_id
			)

	return out
func _starter_follow_up_views_for_actor(_actor: Person, _selected: Dictionary) -> Dictionary:
	return {
		"mother": {
			"title": "{other_first_name} responded: {option_label}",
			"overview": "Your {other_relation} {other_first_name} chose \"{option_label}\". What will you do?",
			"details": "Your {other_relation} {other_first_name} chose \"{option_label}\" during the money argument. What will you do?",
			"response_options": _finance_parent_follow_up_options()
		},
		"father": {
			"title": "{other_first_name} responded: {option_label}",
			"overview": "Your {other_relation} {other_first_name} chose \"{option_label}\". What will you do?",
			"details": "Your {other_relation} {other_first_name} chose \"{option_label}\" during the money argument. What will you do?",
			"response_options": _finance_parent_follow_up_options()
		},
		"guardian": {
			"title": "{other_first_name} responded: {option_label}",
			"overview": "{other_first_name} chose \"{option_label}\". What will you do?",
			"details": "{other_first_name} chose \"{option_label}\". The situation is still unresolved.",
			"response_options": _finance_parent_follow_up_options()
		},
		"default": {
			"title": "{other_first_name} responded...",
			"overview": "{other_first_name} chose \"{option_label}\".",
			"details": "{other_first_name} chose \"{option_label}\".",
			"response_options": _finance_parent_follow_up_options()
		}
	}


func _parent_ids_for_actor(actor: Person) -> Array:
	var out: Array = []
	if actor == null:
		return out

	for raw_parent_id in actor.parents:
		var parent_id: int = int(raw_parent_id)
		if parent_id > 0 and parent_id not in out:
			out.append(parent_id)

	return out


func _starter_actor_roles_for_actor(actor: Person, parent_ids: Array, selected: Dictionary = {}) -> Dictionary:
	var roles: Dictionary = {}
	if actor == null:
		return roles

	roles [str(int(actor.id))] = "child"

	for raw_parent_id in parent_ids:
		var parent_id: int = int(raw_parent_id)
		if parent_id <= 0:
			continue

		var parent: Person = _actor_by_id(parent_id)
		var gender_key: String = str(parent.gender).strip_edges().to_lower() if parent != null else ""
		if gender_key == "female":
			roles [str(parent_id)] = "mother"
		elif gender_key == "male":
			roles [str(parent_id)] = "father"
		else:
			roles [str(parent_id)] = "guardian"

	if typeof(selected) == TYPE_DICTIONARY and not selected.is_empty():
		var featured_relative_id: int = int(selected.get("featured_relative_id", -1))
		if featured_relative_id > 0:
			var featured_role: String = str(selected.get("featured_relative_relation", "participant")).strip_edges().to_lower()
			if featured_role == "":
				featured_role = "participant"
			roles [str(featured_relative_id)] = featured_role

		var involved_actor_ids: Array = _safe_array(selected.get("involved_actor_ids", []))
		for raw_involved_id in involved_actor_ids:
			var involved_id: int = int(raw_involved_id)
			if involved_id <= 0:
				continue
			if not roles.has(str(involved_id)):
				roles [str(involved_id)] = "participant"

		var subject_actor_id: int = int(selected.get("subject_actor_id", -1))
		if subject_actor_id > 0 and not roles.has(str(subject_actor_id)):
			roles [str(subject_actor_id)] = "subject"

		var recipient_actor_id: int = int(selected.get("recipient_actor_id", -1))
		if recipient_actor_id > 0 and not roles.has(str(recipient_actor_id)):
			roles [str(recipient_actor_id)] = "recipient"

	return roles
func _birth_starter_participant_ids_for_actor(actor: Person, selected: Dictionary) -> Array:
	var out: Array = _starter_participant_ids_for_actor(actor)

	if typeof(selected) != TYPE_DICTIONARY:
		return out

	var direct_keys: Array = [
		"featured_relative_id",
		"subject_actor_id",
		"recipient_actor_id",
		"responder_actor_id",
		"other_actor_id"
	]

	for raw_key in direct_keys:
		var key: String = str(raw_key)
		var actor_id: int = int(selected.get(key, -1))
		if actor_id > 0 and actor_id not in out:
			out.append(actor_id)

	var array_keys: Array = [
		"involved_actor_ids",
		"participant_ids",
		"subject_actor_ids",
		"recipient_actor_ids"
	]

	for raw_array_key in array_keys:
		var array_key: String = str(raw_array_key)
		var ids: Array = _safe_array(selected.get(array_key, []))
		for raw_id in ids:
			var actor_id: int = int(raw_id)
			if actor_id > 0 and actor_id not in out:
				out.append(actor_id)

	return out


func _birth_starter_audience_ids_for_actor(actor: Person, selected: Dictionary, participant_ids: Array) -> Array:
	var out: Array = []
	if actor == null:
		return out

	if typeof(selected) == TYPE_DICTIONARY:
		var audience_ids: Array = _safe_array(selected.get("audience_ids", []))
		for raw_audience_id in audience_ids:
			var audience_id: int = int(raw_audience_id)
			if audience_id > 0 and audience_id not in out and audience_id not in participant_ids:
				out.append(audience_id)

		var observer_ids: Array = _safe_array(selected.get("observer_ids", []))
		for raw_observer_id in observer_ids:
			var observer_id: int = int(raw_observer_id)
			if observer_id > 0 and observer_id not in out and observer_id not in participant_ids:
				out.append(observer_id)

	return out


func _parent_id_for_gender(parent_ids: Array, gender_key: String) -> int:
	var clean_gender: String = str(gender_key).strip_edges().to_lower()
	for raw_parent_id in parent_ids:
		var parent_id: int = int(raw_parent_id)
		var parent: Person = _actor_by_id(parent_id)
		if parent == null:
			continue
		if str(parent.gender).strip_edges().to_lower() == clean_gender:
			return parent_id
	return -1


func _first_name_for_actor_id(actor_id: int) -> String:
	var actor: Person = _actor_by_id(actor_id)
	return _first_name_for_actor(actor)


func _first_name_for_actor(actor: Person) -> String:
	if actor == null:
		return ""

	var first_name: String = str(actor.first_name).strip_edges()
	if first_name != "":
		return first_name

	var full_name: String = str(actor.name).strip_edges()
	if full_name != "":
		return full_name.split(" ") [0]

	return ""


func _siblings_for_actor(actor: Person) -> Array:
	var out: Array = []
	if actor == null or gs == null:
		return out

	var actor_id: int = int(actor.id)
	var actor_parent_ids: Array = _parent_ids_for_actor(actor)
	if actor_parent_ids.is_empty():
		return out

	var candidates: Array = []
	if gs.player != null:
		candidates.append(gs.player)

	for raw_npc in gs.npcs:
		if raw_npc is Person:
			candidates.append(raw_npc)

	for raw_person in candidates:
		if not (raw_person is Person):
			continue

		var person: Person = raw_person
		if person == null:
			continue
		if int(person.id) == actor_id:
			continue
		if int(person.age) < 1:
			continue

		for raw_parent_id in person.parents:
			if int(raw_parent_id) in actor_parent_ids:
				out.append(person)
				break

	return out


func _sibling_relation_label(sibling: Person) -> String:
	if sibling == null:
		return "sibling"

	var gender_key: String = str(sibling.gender).strip_edges().to_lower()
	if gender_key == "female":
		return "sister"
	if gender_key == "male":
		return "brother"
	return "sibling"


func _newborn_sibling_mood(actor: Person, sibling: Person) -> String:
	if actor == null or sibling == null:
		return "bewilderment"

	var bond: int = int(sibling.affection.get(int(actor.id), 50)) if typeof(sibling.affection) == TYPE_DICTIONARY else 50
	if bond >= 70:
		return "love and a tiny smile"
	if bond <= 35:
		return "jealousy and a frown"

	var seed_value: int = abs(int(hash("%d|%d|newborn_sibling_mood" % [int(actor.id), int(sibling.id)])))
	match seed_value % 3:
		0:
			return "bewilderment"
		1:
			return "suspicion"
		_:
			return "confusion"


func _dominant_category_for_summaries(summaries: Array) -> String:
	var best_category: String = "general"
	var best_urgency: float = -1.0

	for raw_summary in summaries:
		if typeof(raw_summary) != TYPE_DICTIONARY:
			continue

		var summary: Dictionary = raw_summary as Dictionary
		var urgency: float = float(summary.get("urgency", 0.0))
		if urgency > best_urgency:
			best_urgency = urgency
			best_category = str(summary.get("category", "general"))

	return best_category
func _actor_by_id(actor_id: int) -> Person:
	if gs == null or actor_id <= 0:
		return null

	if gs.player != null and int(gs.player.id) == actor_id:
		return gs.player

	if gs.has_method("get_npc_by_id"):
		var found = gs.get_npc_by_id(actor_id)
		if found != null:
			return found

	if gs.has_method("get_or_reactivate_npc_by_id"):
		var restored = gs.get_or_reactivate_npc_by_id(actor_id)
		if restored != null:
			return restored

	return null


func _actor_fame_value(actor: Person) -> int:
	if actor == null:
		return 0

	if "fame" in actor:
		return int(actor.fame)

	if "fame_score" in actor:
		return int(actor.fame_score)

	return 0


func _country_stability_score() -> int:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return 55

	var geo_truth: Dictionary = _safe_dictionary(gs.scenario_state.get("geo_contract_truth", {}))
	if geo_truth.has("country_stability"):
		return clamp(int(geo_truth.get("country_stability", 55)), 0, 100)

	return 55


func _current_era_name() -> String:
	if gs == null:
		return "Modern Era"

	if gs.era_engine != null and gs.era_engine.has_method("get_current_era_name"):
		return str(gs.era_engine.get_current_era_name())

	if "current_era" in gs:
		return str(gs.current_era)

	return "Modern Era"
func _pending_item_contract_from_popup_contract(contract: Dictionary, target_id: int = -1) -> Dictionary:
	if typeof(contract) != TYPE_DICTIONARY:
		return {}

	var source_id: String = str(contract.get("id", contract.get("contract_id", ""))).strip_edges()
	if source_id == "":
		return {}

	var clean_target_id: int = int(contract.get("target_id", contract.get("target", target_id)))
	var item_id: String = "pending_item:%s" % source_id

	return {
		"schema": ITEM_CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": item_id,
		"contract_id": item_id,
		"source_contract_id": source_id,
		"contract_type": "pending_situation_item",
		"target_id": clean_target_id,
		"title": str(contract.get("title", "Pending Situation")),
		"overview": str(contract.get("overview", "")),
		"category": str(contract.get("category", "general")),
		"urgency": float(contract.get("urgency", 0.0)),
		"state": str(contract.get("state", "pending")),
		"created_at_ms": int(contract.get("created_at_ms", Time.get_ticks_msec())),
		"updated_at_ms": int(Time.get_ticks_msec()),
		"source_contract": contract.duplicate(true),
		"contract_mesh": {
			"source_of_truth": "PendingSituationsEngine",
			"source_contract_owner": "ScenarioRuntimeContractEngine",
			"ui_observer": "PopupViewer",
			"ui_mutation_allowed": false,
			"persistent": true
		}
	}


func _observe_summary_contract(summary_contract: Dictionary, observer_id: String = "unknown") -> void:
	var summary_id: String = str(summary_contract.get("id", "")).strip_edges()
	if summary_id == "":
		return

	var observer: String = str(observer_id).strip_edges()
	if observer == "":
		observer = "unknown"

	var row: Dictionary = _safe_dictionary(pending_situation_observations.get(summary_id, {}))
	row ["contract_id"] = summary_id
	row ["observer"] = observer
	row ["observation_count"] = int(row.get("observation_count", 0)) + 1
	row ["last_observed_at_ms"] = int(Time.get_ticks_msec())
	pending_situation_observations [summary_id] = row

	_record_pending_mutation(summary_id, "observed", {
		"observer": observer
	})


func _repair_pending_situation_state() -> void:
	var repaired_contracts: Dictionary = {}

	for raw_id in pending_situation_contracts.keys():
		var contract: Dictionary = _safe_dictionary(pending_situation_contracts.get(raw_id, {}))
		if contract.is_empty():
			continue

		var source_id: String = str(contract.get("source_contract_id", contract.get("id", raw_id))).strip_edges()
		if source_id == "":
			continue

		if str(contract.get("schema", "")) != ITEM_CONTRACT_SCHEMA:
			contract ["schema"] = ITEM_CONTRACT_SCHEMA
		contract ["version"] = int(contract.get("version", CONTRACT_VERSION))
		contract ["id"] = str(contract.get("id", "pending_item:%s" % source_id))
		contract ["contract_id"] = str(contract.get("contract_id", contract.get("id", "")))
		contract ["contract_type"] = "pending_situation_item"
		contract ["updated_at_ms"] = int(contract.get("updated_at_ms", Time.get_ticks_msec()))

		repaired_contracts [str(contract.get("id", ""))] = contract

	pending_situation_contracts = repaired_contracts

	var repaired_index: Dictionary = {}
	for raw_key in pending_situation_index.keys():
		var key: String = str(raw_key).strip_edges()
		if key == "":
			continue
		repaired_index [key] = _safe_dictionary(pending_situation_index.get(raw_key, {}))
	pending_situation_index = repaired_index

	var repaired_observations: Dictionary = {}
	for raw_key in pending_situation_observations.keys():
		var key: String = str(raw_key).strip_edges()
		if key == "":
			continue
		repaired_observations [key] = _safe_dictionary(pending_situation_observations.get(raw_key, {}))
	pending_situation_observations = repaired_observations

	if pending_situation_mutation_log.size() > 240:
		pending_situation_mutation_log = pending_situation_mutation_log.slice(pending_situation_mutation_log.size() - 240, pending_situation_mutation_log.size())

	if not last_summary_contract.is_empty():
		last_summary_contract ["schema"] = str(last_summary_contract.get("schema", SUMMARY_CONTRACT_SCHEMA))
		last_summary_contract ["version"] = int(last_summary_contract.get("version", CONTRACT_VERSION))


func _record_pending_mutation(contract_id: String, mutation_type: String, payload: Dictionary = {}) -> void:
	var clean_id: String = str(contract_id).strip_edges()
	if clean_id == "":
		return

	pending_situation_mutation_log.append({
		"contract_id": clean_id,
		"mutation_type": str(mutation_type).strip_edges(),
		"payload": payload.duplicate(true),
		"created_at_ms": int(Time.get_ticks_msec())
	})

	if pending_situation_mutation_log.size() > 240:
		pending_situation_mutation_log = pending_situation_mutation_log.slice(pending_situation_mutation_log.size() - 240, pending_situation_mutation_log.size())


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}





	gs.scenario_state [
		"pending_situation_contracts"
	] = pending_situation_contracts

	gs.scenario_state [
		"pending_situation_index"
	] = pending_situation_index

	gs.scenario_state [
		"pending_situation_observations"
	] = pending_situation_observations

	gs.scenario_state [
		"pending_situation_mutation_log"
	] = pending_situation_mutation_log

	gs.scenario_state [
		"pending_situation_birth_starter_seeded_actor_ids"
	] = birth_starter_seeded_actor_ids

	gs.scenario_state [
		"pending_situations_last_summary_contract"
	] = last_summary_contract
func _crime_interrogation_target_name(
	crime_event: Dictionary
) -> String:
	var participants: Dictionary = _safe_dictionary(
		crime_event.get(
			"participants",
			{}
		)
	)
	var target_id: int = int(
		participants.get(
			"victim",
			crime_event.get(
				"victim_id",
				-1
			)
		)
	)
	var target: Person = _actor_by_id(
		target_id
	)

	if target == null:
		return "the recorded target"

	var full_name: String = (
		"%s %s"
		% [
			str(target.first_name),
			str(target.last_name)
		]
	).strip_edges()

	return (
		full_name
		if full_name != ""
		else "Person %d" % target_id
	)
func _crime_interrogation_location_label(
	actor: Person,
	crime_event: Dictionary
) -> String:
	var context: Dictionary = _safe_dictionary(
		crime_event.get(
			"context",
			{}
		)
	)
	var source_item: Dictionary = _safe_dictionary(
		context.get(
			"source_item",
			{}
		)
	)
	var location: String = str(
		context.get(
			"location_name",
			context.get(
				"location",
				source_item.get(
					"location_name",
					""
				)
			)
		)
	).strip_edges()

	if location != "":
		return location

	if actor != null:
		var city: String = str(
			actor.home_city
		).strip_edges()
		var country: String = str(
			actor.home_country
		).strip_edges()
		var home_label: String = (
			"%s, %s"
			% [
				city,
				country
			]
		).strip_edges().trim_prefix(",").trim_suffix(",")

		if home_label != "":
			return home_label

	return "the recorded scene"
func _crime_interrogation_counsel_options(
	case_id: String,
	stage: int,
	era_name: String = "Modern Era"
) -> Array:
	var era_key: String = str(
		era_name
	).strip_edges().to_lower()
	var tiers: Array = []

	match era_key:
		"industrial era":
			tiers = [
				{
					"id": "court_assigned_solicitor",
					"label": "Use a Court-Assigned Solicitor — Free",
					"cost": 0,
					"quality": 18,
					"text": (
						"Accept an overworked court solicitor with minimal "
						+ "investigative resources."
					)
				},
				{
					"id": "junior_solicitor",
					"label": "Hire a Junior Solicitor — $1,200",
					"cost": 1200,
					"quality": 36,
					"text": (
						"Hire an early-career solicitor familiar with "
						+ "industrial criminal procedure."
					)
				},
				{
					"id": "seasoned_barrister",
					"label": "Hire a Seasoned Barrister — $7,000",
					"cost": 7000,
					"quality": 63,
					"text": (
						"Retain a courtroom barrister with substantial "
						+ "criminal-case experience."
					)
				},
				{
					"id": "royal_trial_counsel",
					"label": "Hire Royal Trial Counsel — $25,000",
					"cost": 25000,
					"quality": 87,
					"text": (
						"Retain an elite advocate accustomed to the era's "
						+ "highest courts and political cases."
					)
				}
			]

		"future era":
			tiers = [
				{
					"id": "public_defense_ai",
					"label": "Use Public Defense AI — Free",
					"cost": 0,
					"quality": 25,
					"text": (
						"Accept a free civic defense model with restricted "
						+ "compute, memory access, and appeal authority."
					)
				},
				{
					"id": "licensed_synth_counsel",
					"label": "Hire Licensed Synth-Counsel — $5,000",
					"cost": 5000,
					"quality": 47,
					"text": (
						"Hire a licensed synthetic advocate with verified "
						+ "criminal-procedure modules."
					)
				},
				{
					"id": "quantum_trial_specialist",
					"label": "Hire a Quantum Trial Specialist — $25,000",
					"cost": 25000,
					"quality": 74,
					"text": (
						"Retain counsel trained to challenge predictive "
						+ "evidence and reconstructed memory."
					)
				},
				{
					"id": "sovereign_legal_architect",
					"label": "Hire a Sovereign Legal Architect — $100,000",
					"cost": 100000,
					"quality": 96,
					"text": (
						"Retain an elite legal architect capable of attacking "
						+ "the full evidence model and tribunal protocol."
					)
				}
			]

		"modern era":
			tiers = [
				{
					"id": "public_defender",
					"label": "Use a Public Defender — Free",
					"cost": 0,
					"quality": 20,
					"text": (
						"Accept free court-appointed representation with the "
						+ "lowest experience and resource tier."
					)
				},
				{
					"id": "junior_defense_lawyer",
					"label": "Hire a Junior Defense Lawyer — $2,500",
					"cost": 2500,
					"quality": 40,
					"text": (
						"Hire an early-career criminal defense lawyer."
					)
				},
				{
					"id": "experienced_criminal_lawyer",
					"label": "Hire an Experienced Lawyer — $12,000",
					"cost": 12000,
					"quality": 65,
					"text": (
						"Hire an experienced criminal defense lawyer."
					)
				},
				{
					"id": "elite_trial_counsel",
					"label": "Hire Elite Trial Counsel — $50,000",
					"cost": 50000,
					"quality": 90,
					"text": (
						"Retain elite counsel for the interrogation, trial, "
						+ "and public fallout."
					)
				}
			]

		_:
			return []

	var out: Array = []
	var clean_stage: int = clampi(
		stage,
		1,
		3
	)

	for raw_tier in tiers:
		var tier: Dictionary = _safe_dictionary(
			raw_tier
		)
		var tier_id: String = str(
			tier.get(
				"id",
				"public_defender"
			)
		)
		var cost: int = maxi(
			0,
			int(
				tier.get(
					"cost",
					0
				)
			)
		)
		var quality: int = clampi(
			int(
				tier.get(
					"quality",
					20
				)
			),
			0,
			100
		)

		out.append({
			"id": "retain_%s" % tier_id,
			"label": str(
				tier.get(
					"label",
					"Request Counsel"
				)
			),
			"text": str(
				tier.get(
					"text",
					"Request legal representation."
				)
			),
			"result_text": (
				"You selected legal representation."
			),
			"resolution_payload": {
				"case_id": case_id,
				"response_id": "retain_counsel",
				"interrogation_stage": clean_stage,
				"lawyer_tier": tier_id,
				"lawyer_cost": cost,
				"lawyer_quality": quality,
				"lawyer_era": era_name
			}
		})

	return out
func _crime_interrogation_response_options(
	actor: Person,
	case_id: String,
	stage: int,
	era_name: String,
	severity: float,
	intent: String,
	witness_count: int
) -> Array:
	var out: Array = []

	if (
		actor == null
		or str(case_id).strip_edges() == ""
	):
		return out

	var clean_stage: int = clampi(
		stage,
		1,
		3
	)
	var era_key: String = str(
		era_name
	).strip_edges().to_lower()
	var clean_severity: float = clampf(
		severity,
		0.0,
		1.0
	)
	var intent_key: String = str(
		intent
	).strip_edges().to_lower()
	var clean_witness_count: int = maxi(
		0,
		witness_count
	)
	var accidental_intent: bool = (
		intent_key.contains("accident")
		or intent_key.contains("negligent")
		or intent_key.contains("unintentional")
		or intent_key.contains("misfire")
		or intent_key.contains("reckless")
	)
	var deliberate_intent: bool = (
		intent_key.contains("intentional")
		or intent_key.contains("deliberate")
		or intent_key.contains("premeditated")
		or intent_key.contains("malicious")
		or intent_key.contains("execution")
		or intent_key.contains("revenge")
	)
	var modern_legal_system: bool = era_key in [
		"industrial era",
		"modern era",
		"future era"
	]
	var substantial_exposure: bool = (
		clean_severity >= 0.45
		or clean_witness_count >= 2
		or deliberate_intent
	)
	var social_class_key: String = str(
		actor.social_class
	).strip_edges().to_lower()
	var civic_title: String = str(
		actor.civic_title
	).strip_edges()
	var royal_title: String = str(
		actor.royal_title
	).strip_edges()
	var job_key: String = str(
		actor.job
	).strip_edges().to_lower()
	var official_job: bool = (
		job_key.contains("president")
		or job_key.contains("governor")
		or job_key.contains("senator")
		or job_key.contains("minister")
		or job_key.contains("magistrate")
		or job_key.contains("mayor")
		or job_key.contains("chancellor")
		or job_key.contains("consul")
		or job_key.contains("emperor")
		or job_key.contains("empress")
		or job_key.contains("king")
		or job_key.contains("queen")
		or job_key.contains("pharaoh")
		or job_key.contains("fire lord")
	)
	var civic_contract_exists: bool = (
		typeof(actor.civic_office_contract) == TYPE_DICTIONARY
		and not actor.civic_office_contract.is_empty()
	)
	var noble_status: bool = social_class_key in [
		"noble",
		"royal"
	]
	var institutional_power_available: bool = (
		bool(actor.is_ruler)
		or bool(actor.is_royal)
		or royal_title != ""
		or civic_title != ""
		or civic_contract_exists
		or noble_status
		or official_job
	)
	var institutional_power_kind: String = "institutional_office"

	if bool(actor.is_ruler):
		institutional_power_kind = "sovereign"
	elif bool(actor.is_royal) or royal_title != "":
		institutional_power_kind = "royal"
	elif noble_status:
		institutional_power_kind = "noble"
	elif civic_title != "" or civic_contract_exists or official_job:
		institutional_power_kind = "government_office"

	var institutional_power_strength: int = 0

	if bool(actor.is_ruler):
		institutional_power_strength += 48

	if bool(actor.is_royal):
		institutional_power_strength += 28

	if royal_title != "":
		institutional_power_strength += 12

	if social_class_key == "royal":
		institutional_power_strength += 14
	elif social_class_key == "noble":
		institutional_power_strength += 9

	if civic_title != "":
		institutional_power_strength += 22

	if civic_contract_exists:
		institutional_power_strength += 16

	if official_job:
		institutional_power_strength += 12

	institutional_power_strength += int(
		round(
			float(actor.approval) * 0.16
		)
	)
	institutional_power_strength += int(
		round(
			float(actor.fame) * 0.08
		)
	)
	institutional_power_strength = clampi(
		institutional_power_strength,
		0,
		100
	)

	var base_payload: Dictionary = {
		"case_id": case_id,
		"interrogation_stage": clean_stage,
		"era_name": era_name,
		"crime_severity": clean_severity,
		"crime_intent": intent_key,
		"witness_count": clean_witness_count,
		"policy_authority": (
			"PendingSituationsEngine."
			+ "_crime_interrogation_response_options"
		)
	}

	match clean_stage:
		1:
			var silence_label: String = "Remain Silent"
			var silence_text: String = (
				"Refuse to answer the opening questions."
			)
			var account_label: String = "Give an Initial Account"
			var account_text: String = (
				"Give investigators your first account of the event."
			)
			var deny_label: String = "Deny Involvement"
			var deny_text: String = (
				"Deny committing the alleged weapon crime."
			)
			var flee_label: String = "Flee"
			var flee_text: String = (
				"Attempt to escape before the interrogation continues."
			)
			var power_label: String = (
				"Invoke Institutional Power"
			)

			match era_key:
				"ancient era":
					silence_label = (
						"Seal My Tongue Before the Magistrate"
					)
					silence_text = (
						"Refuse to speak before the imperial record."
					)
					account_label = "Give a Sworn Account"
					account_text = (
						"Swear before the gods and give the magistrate "
						+ "your account."
					)
					deny_label = (
						"Deny the Accusation Before the Scribe"
					)
					deny_text = (
						"Order the court scribe to record your denial."
					)
					flee_label = "Escape Imperial Custody"
					flee_text = (
						"Attempt to escape before the magistrate seals "
						+ "the accusation."
					)
					power_label = (
						"Command the Magistrate to Stand Down"
						if bool(actor.is_ruler)
						else "Invoke Sacred Rank and Privilege"
					)

				"medieval era":
					silence_label = (
						"Refuse the Constable's Questions"
					)
					silence_text = (
						"Refuse to answer without submitting to the "
						+ "Crown's account."
					)
					account_label = (
						"Give My Account Before the Crown"
					)
					account_text = (
						"Give the constable your version of the event."
					)
					deny_label = "Deny the Charge"
					deny_text = (
						"Deny the accusation before the Crown's officer."
					)
					flee_label = "Flee the Crown's Custody"
					flee_text = (
						"Attempt to escape before formal judgment."
					)
					power_label = (
						"Invoke Crown Privilege"
					)

				"industrial era":
					silence_label = "Exercise My Right to Silence"
					silence_text = (
						"Refuse the inspector's opening questions."
					)
					account_label = "Give a Recorded Statement"
					account_text = (
						"Give a formal statement for the city record."
					)
					deny_label = "Deny the Allegation"
					deny_text = (
						"Deny the allegation before the inspector."
					)
					flee_label = "Escape the Investigation"
					flee_text = (
						"Attempt to disappear before a warrant is issued."
					)
					power_label = (
						"Invoke Rank, Office, and Influence"
					)

				"future era":
					silence_label = "Lock My Testimony"
					silence_text = (
						"Refuse neural, biometric, and verbal testimony."
					)
					account_label = (
						"Submit a Verified Memory Statement"
					)
					account_text = (
						"Submit a cryptographically signed account of "
						+ "the event."
					)
					deny_label = (
						"Reject the Predictive Allegation"
					)
					deny_text = (
						"Reject the tribunal's predictive accusation."
					)
					flee_label = "Evade Tribunal Tracking"
					flee_text = (
						"Attempt to disappear from the tribunal's "
						+ "identity network."
					)
					power_label = (
						"Invoke Sovereign Clearance"
					)

				_:
					power_label = (
						"Invoke Executive or Official Privilege"
						if (
							civic_title != ""
							or civic_contract_exists
							or official_job
						)
						else "Invoke Royal or Noble Privilege"
					)

			var silence_payload: Dictionary = (
				base_payload.duplicate(true)
			)
			silence_payload ["response_id"] = "remain_silent"

			out.append({
				"id": "remain_silent",
				"label": silence_label,
				"text": silence_text,
				"result_text": (
					"You refused to answer the opening questions."
				),
				"resolution_payload": silence_payload
			})

			if institutional_power_available:
				var power_payload: Dictionary = (
					base_payload.duplicate(true)
				)

				power_payload ["response_id"] = (
					"exert_institutional_power"
				)
				power_payload ["institutional_power_kind"] = (
					institutional_power_kind
				)
				power_payload ["institutional_power_label"] = (
					power_label
				)
				power_payload ["institutional_power_strength"] = (
					institutional_power_strength
				)
				power_payload [
					"institutional_power_catastrophic_failure"
				] = true
				power_payload [
					"institutional_power_failure_evidence_bonus"
				] = 0.25
				power_payload [
					"institutional_power_failure_defense_penalty"
				] = 0.12
				power_payload [
					"institutional_power_failure_scandal"
				] = 25

				out.append({
					"id": "exert_institutional_power",
					"label": power_label,
					"text": (
						"Attempt to terminate the interrogation through "
						+ "royal, noble, or governmental authority. This "
						+ "usually succeeds when your standing exceeds the "
						+ "case's public evidence. Failure can add "
						+ "obstruction, abuse-of-office, scandal, and "
						+ "stronger evidence."
					),
					"result_text": (
						"You attempted to exert institutional power over "
						+ "the investigation."
					),
					"resolution_payload": power_payload
				})

			var account_payload: Dictionary = (
				base_payload.duplicate(true)
			)
			account_payload ["response_id"] = "cooperate"

			out.append({
				"id": "cooperate",
				"label": account_label,
				"text": account_text,
				"result_text": (
					"You gave an opening account."
				),
				"resolution_payload": account_payload
			})

			var deny_payload: Dictionary = (
				base_payload.duplicate(true)
			)
			deny_payload ["response_id"] = "deny"

			out.append({
				"id": "deny",
				"label": deny_label,
				"text": deny_text,
				"result_text": (
					"You denied involvement."
				),
				"resolution_payload": deny_payload
			})

			var flee_threshold: float = 0.55

			match era_key:
				"ancient era":
					flee_threshold = 0.35
				"medieval era":
					flee_threshold = 0.4
				"industrial era":
					flee_threshold = 0.48
				"future era":
					flee_threshold = 0.62

			if (
				clean_severity >= flee_threshold
				or clean_witness_count >= 4
			):
				var flee_payload: Dictionary = (
					base_payload.duplicate(true)
				)
				flee_payload ["response_id"] = "flee"

				out.append({
					"id": "flee",
					"label": flee_label,
					"text": flee_text,
					"result_text": (
						"You attempted to flee the legal process."
					),
					"resolution_payload": flee_payload
				})

			if modern_legal_system:
				out.append_array(
					_crime_interrogation_counsel_options(
						case_id,
						clean_stage,
						era_name
					)
				)

		2:
			var evidence_label: String = "Challenge Evidence"
			var evidence_text: String = (
				"Challenge the physical and circumstantial evidence."
			)
			var witness_label: String = "Challenge Witnesses"
			var witness_text: String = (
				"Challenge the reliability of the witness accounts."
			)
			var accident_label: String = "Claim Accident"
			var accident_text: String = (
				"Claim that the weapon use was accidental."
			)
			var intent_label: String = "Justify Intent"
			var intent_text: String = (
				"Attempt to justify why the weapon was used."
			)
			var stop_label: String = "Stop Answering"
			var stop_text: String = (
				"End your participation in the interrogation."
			)

			match era_key:
				"ancient era":
					evidence_label = (
						"Challenge the Magistrate's Proof"
					)
					evidence_text = (
						"Challenge the objects, wounds, omens, and written "
						+ "claims entered before the magistrate."
					)
					witness_label = "Confront the Accusers"
					witness_text = (
						"Demand that the witnesses repeat their claims "
						+ "before the court."
					)
					accident_label = "Claim Accident or Divine Misfortune"
					accident_text = (
						"Claim that chance, equipment failure, or divine "
						+ "misfortune caused the harm."
					)
					intent_label = "Invoke Blood-Law Justification"
					intent_text = (
						"Argue that custom, honor, duty, or vengeance "
						+ "justified the act."
					)
					stop_label = "Seal My Testimony"
					stop_text = (
						"Refuse to give the magistrate another word."
					)

				"medieval era":
					evidence_label = "Challenge the Crown's Evidence"
					evidence_text = (
						"Challenge the weapon, wounds, and constable's "
						+ "account."
					)
					witness_label = (
						"Demand Witness Confrontation"
					)
					witness_text = (
						"Demand that each accuser face you before the Crown."
					)
					accident_label = "Claim Misadventure"
					accident_text = (
						"Claim that the injury arose through misadventure."
					)
					intent_label = "Invoke Feudal Right or Duty"
					intent_text = (
						"Argue that rank, service, defense, or feudal duty "
						+ "justified the act."
					)
					stop_label = "Refuse Further Questions"
					stop_text = (
						"Refuse to answer the constable again."
					)

				"industrial era":
					evidence_label = (
						"Challenge the Physical Evidence"
					)
					evidence_text = (
						"Challenge the weapon examination, medical report, "
						+ "and inspector's reconstruction."
					)
					witness_label = (
						"Challenge Witness Credibility"
					)
					witness_text = (
						"Attack inconsistencies in the witness statements."
					)
					accident_label = "Claim Mechanical Accident"
					accident_text = (
						"Claim that machinery, ammunition, or weapon failure "
						+ "caused the event."
					)
					intent_label = "Justify the Use of Force"
					intent_text = (
						"Argue that the era's law justified your use of force."
					)

				"future era":
					evidence_label = (
						"Challenge Forensic Reconstruction"
					)
					evidence_text = (
						"Challenge the tribunal's physical, biometric, and "
						+ "predictive reconstruction."
					)
					witness_label = (
						"Challenge Witness-Memory Integrity"
					)
					witness_text = (
						"Attack corruption, editing, bias, or drift in the "
						+ "recorded witness memories."
					)
					accident_label = (
						"Claim System or Equipment Failure"
					)
					accident_text = (
						"Claim that autonomous systems or weapon hardware "
						+ "caused the event."
					)
					intent_label = (
						"Justify Authorized Use"
					)
					intent_text = (
						"Argue that your authorization, defense protocol, or "
						+ "emergency mandate justified the act."
					)
					stop_label = "Terminate the Neural Interview"
					stop_text = (
						"Revoke consent for further cognitive questioning."
					)

			var evidence_payload: Dictionary = (
				base_payload.duplicate(true)
			)
			evidence_payload ["response_id"] = (
				"challenge_evidence"
			)

			out.append({
				"id": "challenge_evidence",
				"label": evidence_label,
				"text": evidence_text,
				"result_text": (
					"You challenged the evidence."
				),
				"resolution_payload": evidence_payload
			})

			if clean_witness_count > 0:
				var witness_payload: Dictionary = (
					base_payload.duplicate(true)
				)
				witness_payload ["response_id"] = (
					"challenge_witnesses"
				)

				out.append({
					"id": "challenge_witnesses",
					"label": witness_label,
					"text": witness_text,
					"result_text": (
						"You challenged the witness accounts."
					),
					"resolution_payload": witness_payload
				})

			if accidental_intent:
				var accident_payload: Dictionary = (
					base_payload.duplicate(true)
				)
				accident_payload ["response_id"] = (
					"claim_accident"
				)

				out.append({
					"id": "claim_accident",
					"label": accident_label,
					"text": accident_text,
					"result_text": (
						"You claimed the event was accidental."
					),
					"resolution_payload": accident_payload
				})
			elif deliberate_intent:
				var intent_payload: Dictionary = (
					base_payload.duplicate(true)
				)
				intent_payload ["response_id"] = (
					"justify_intent"
				)

				out.append({
					"id": "justify_intent",
					"label": intent_label,
					"text": intent_text,
					"result_text": (
						"You attempted to justify your intent."
					),
					"resolution_payload": intent_payload
				})

			var stop_payload: Dictionary = (
				base_payload.duplicate(true)
			)
			stop_payload ["response_id"] = "remain_silent"

			out.append({
				"id": "stop_answering",
				"label": stop_label,
				"text": stop_text,
				"result_text": (
					"You stopped answering questions."
				),
				"resolution_payload": stop_payload
			})

			if modern_legal_system:
				out.append_array(
					_crime_interrogation_counsel_options(
						case_id,
						clean_stage,
						era_name
					)
				)

		3:
			var denial_label: String = "Maintain Denial"
			var confession_label: String = "Confess"
			var final_silence_label: String = (
				"Make No Final Statement"
			)
			var plea_label: String = "Seek a Plea Deal"

			match era_key:
				"ancient era":
					denial_label = (
						"Maintain My Denial Before Judgment"
					)
					confession_label = (
						"Confess Before the Magistrate"
					)
					final_silence_label = "Offer No Final Word"

				"medieval era":
					denial_label = (
						"Maintain My Denial Before the Crown"
					)
					confession_label = "Confess Before Judgment"
					final_silence_label = "Make No Final Plea"

				"industrial era":
					confession_label = (
						"Confess to the City Inspector"
					)
					plea_label = (
						"Seek a Negotiated Charge"
					)

				"future era":
					denial_label = (
						"Maintain My Verified Denial"
					)
					confession_label = (
						"Submit a Full Recorded Confession"
					)
					final_silence_label = (
						"Seal the Final Record"
					)
					plea_label = (
						"Request Algorithmic Plea Review"
					)

			var denial_payload: Dictionary = (
				base_payload.duplicate(true)
			)
			denial_payload ["response_id"] = (
				"maintain_denial"
			)

			out.append({
				"id": "maintain_denial",
				"label": denial_label,
				"text": (
					"Maintain your denial through the final interrogation "
					+ "stage."
				),
				"result_text": (
					"You maintained your denial."
				),
				"resolution_payload": denial_payload
			})

			var confession_payload: Dictionary = (
				base_payload.duplicate(true)
			)
			confession_payload ["response_id"] = "confess"

			out.append({
				"id": "confess",
				"label": confession_label,
				"text": (
					"Admit committing the recorded weapon crime."
				),
				"result_text": (
					"You confessed."
				),
				"resolution_payload": confession_payload
			})

			var final_silence_payload: Dictionary = (
				base_payload.duplicate(true)
			)
			final_silence_payload ["response_id"] = (
				"remain_silent"
			)

			out.append({
				"id": "make_no_final_statement",
				"label": final_silence_label,
				"text": (
					"End the interrogation without a final statement."
				),
				"result_text": (
					"You made no final statement."
				),
				"resolution_payload": final_silence_payload
			})

			if (
				modern_legal_system
				and substantial_exposure
			):
				var plea_payload: Dictionary = (
					base_payload.duplicate(true)
				)
				plea_payload ["response_id"] = "seek_plea"

				out.append({
					"id": "seek_plea",
					"label": plea_label,
					"text": (
						"Attempt to negotiate reduced exposure before "
						+ "formal trial."
					),
					"result_text": (
						"You requested plea negotiations."
					),
					"resolution_payload": plea_payload
				})

			if modern_legal_system:
				out.append_array(
					_crime_interrogation_counsel_options(
						case_id,
						clean_stage,
						era_name
					)
				)

	return out
func emit_crime_interrogation_stage_contract(
	actor: Person,
	crime_event: Dictionary,
	case_report: Dictionary,
	stage: int,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if (
		actor == null
		or gs == null
		or gs.scenario_runtime_contract_engine == null
	):
		return {
			"success": false,
			"reason": "crime_pending_dependencies_unavailable"
		}

	var clean_stage: int = clampi(
		stage,
		1,
		3
	)
	var case_data: Dictionary = _safe_dictionary(
		case_report.get(
			"case",
			case_report
		)
	)
	var case_id: String = str(
		case_report.get(
			"case_id",
			case_data.get(
				"case_id",
				""
			)
		)
	).strip_edges()

	if case_id == "":
		return {
			"success": false,
			"reason": "crime_case_id_missing"
		}

	var crime: Dictionary = _safe_dictionary(
		crime_event.get(
			"crime",
			case_data.get(
				"crime",
				{}
			)
		)
	)
	var participants: Dictionary = _safe_dictionary(
		crime_event.get(
			"participants",
			case_data.get(
				"participants",
				{}
			)
		)
	)
	var response_window_ms: int = maxi(
		30000,
		int(
			context.get(
				"response_window_ms",
				75000
			)
		)
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var deadline_at_ms: int = (
		now_ms
		+ response_window_ms
	)
	var era_name: String = str(
		crime_event.get(
			"era",
			case_data.get(
				"era",
				"Modern Era"
			)
		)
	)
	var authority_label: String = (
		_crime_authority_label_for_era(
			era_name
		)
	)
	var weapon_name: String = str(
		crime.get(
			"weapon_name",
			"unknown weapon"
		)
	)
	var action_label: String = str(
		crime.get(
			"weapon_action_label",
			"weapon action"
		)
	)
	var body_part: String = str(
		crime.get(
			"body_part",
			"unknown area"
		)
	).replace(
		"_",
		" "
	)
	var witness_count: int = int(
		crime.get(
			"witness_count",
			_safe_array(
				participants.get(
					"witnesses",
					[]
				)
			).size()
		)
	)
	var severity: float = clampf(
		float(
			crime.get(
				"severity",
				0.35
			)
		),
		0.0,
		1.0
	)
	var intent: String = str(
		crime.get(
			"intent",
			"unknown"
		)
	)
	var target_name: String = (
		_crime_interrogation_target_name(
			crime_event
		)
	)
	var location_label: String = (
		_crime_interrogation_location_label(
			actor,
			crime_event
		)
	)
	var victim_outcome: String = (
		"The target died."
		if bool(
			crime.get(
				"target_died",
				false
			)
		)
		else "The target survived."
	)
	var stage_focus: String = "Opening account"

	match clean_stage:
		2:
			stage_focus = (
				"Evidence and witness confrontation"
			)
		3:
			stage_focus = (
				"Final statement before charging"
			)

	var overview: String = (
		"%s is questioning you about the use of %s to %s %s at %s.\n\n"
		+ "Target: %s.\n"
		+ "Recorded target area: %s.\n"
		+ "%s\n"
		+ "Known witnesses: %d.\n"
		+ "Intent on record: %s."
	) % [
		authority_label,
		weapon_name,
		action_label.to_lower(),
		target_name,
		location_label,
		target_name,
		body_part,
		victim_outcome,
		witness_count,
		intent.replace("_", " ")
	]
	var response_options: Array = (
		_crime_interrogation_response_options(
			actor,
			case_id,
			clean_stage,
			era_name,
			severity,
			intent,
			witness_count
		)
	)
	var contract_id: String = (
		"crime_response:%s:%d"
		% [
			case_id,
			clean_stage
		]
	)
	var contract: Dictionary = {
		"schema": "eralife.crime_response_pending_contract",
		"version": 2,
		"id": contract_id,
		"contract_id": contract_id,
		"contract_type": "scenario_popup",
		"state": "pending",
		"category": "crime",
		"pending_category": "crime",
		"target": int(actor.id),
		"target_id": int(actor.id),
		"actor_id": int(actor.id),
		"title": (
			"Interrogation %d/3 — %s"
			% [
				clean_stage,
				authority_label
			]
		),
		"overview": overview,
		"details": (
			"%s. Your response becomes part of case %s. "
			+ "Available actions reflect the era, severity, recorded intent, "
			+ "witness count, institutional standing, and retained counsel."
		) % [
			stage_focus,
			case_id
		],
		"urgency": 96.0,
		"decay": 0.8,
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"deadline_at_ms": deadline_at_ms,
		"remaining_response_ms": response_window_ms,
		"deadline_default_option_id": "remain_silent",
		"case_id": case_id,
		"interrogation_stage": clean_stage,
		"interrogation_stage_count": 3,
		"weapon_name": weapon_name,
		"weapon_action_label": action_label,
		"location_label": location_label,
		"target_name": target_name,
		"body_part": body_part,
		"witness_count": witness_count,
		"severity": severity,
		"intent": intent,
		"crime_event": crime_event.duplicate(true),


		"response_options": response_options,


		"options": response_options.duplicate(true),

		"resolution_route": {
			"engine_property": "case_orchestrator",
			"method": "resolve_pending_crime_response",
			"pass_actor_payload": true
		},
		"response_policy_contract": {
			"authority": (
				"PendingSituationsEngine."
				+ "_crime_interrogation_response_options"
			),
			"actor_id": int(actor.id),
			"era_name": era_name,
			"stage": clean_stage,
			"severity": severity,
			"intent": intent,
			"witness_count": witness_count,
		},
		"escalation_triggers": [
			{
				"title_suffix": "— FINAL NOTICE",
				"overview": (
					"The response window is nearly closed. "
					+ "The authorities are proceeding without your answer."
				)
			}
		],
		"source": str(
			context.get(
				"source",
				"pending_situations_engine.crime"
			)
		),
		"contract_mesh": {
			"source_of_truth": "PendingSituationsEngine",
			"case_owner": "CaseOrchestrator",
			"action_policy_owner": (
				"PendingSituationsEngine."
				+ "_crime_interrogation_response_options"
			),
			"view_owner": "ContractViewLayerContractEngine",
			"ui_observer": "PopupViewer",
			"ui_mutation_allowed": false,
			"persistent": true,
			"ready_gate_member": false
		}
	}
	var activation_report: Dictionary = (
		gs.scenario_runtime_contract_engine.activate_popup_contract(
			contract
		)
	)

	emit_pending_situations_summary_contract({
		"target_id": int(actor.id),
		"source": "crime_interrogation_stage_activated"
	})

	return {
		"success": bool(
			activation_report.get(
				"success",
				false
			)
		),
		"mode": "crime_interrogation_stage_activated",
		"contract_id": str(
			activation_report.get(
				"contract_id",
				contract_id
			)
		),
		"interrogation_stage": clean_stage,
		"interrogation_stage_count": 3,
		"deadline_at_ms": deadline_at_ms,
		"response_window_ms": response_window_ms,
		"contract": contract.duplicate(true),
		"activation_report": activation_report.duplicate(true)
	}
func emit_crime_response_contract(
	actor: Person,
	crime_event: Dictionary,
	case_report: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	return emit_crime_interrogation_stage_contract(
		actor,
		crime_event,
		case_report,
		1,
		context
	)
func emit_crime_aftermath_contract(
	actor: Person,
	crime_event: Dictionary,
	case_report: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if (
		actor == null
		or gs == null
	):
		return {
			"success": false,
			"reason": "crime_aftermath_dependencies_unavailable"
		}

	if gs.scenario_runtime_contract_engine == null:
		gs.scenario_runtime_contract_engine = (
			ScenarioRuntimeContractEngine.new(
				gs
			)
		)

	var case_raw: Variant = case_report.get(
		"case",
		{}
	)
	var case_data: Dictionary = (
		case_raw as Dictionary
		if typeof(
			case_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var case_id: String = str(
		case_report.get(
			"case_id",
			case_data.get(
				"case_id",
				""
			)
		)
	).strip_edges()

	if case_id == "":
		return {
			"success": false,
			"reason": "crime_aftermath_case_id_missing"
		}

	var crime_raw: Variant = crime_event.get(
		"crime",
		{}
	)
	var crime: Dictionary = (
		crime_raw as Dictionary
		if typeof(
			crime_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var weapon_name: String = str(
		crime.get(
			"weapon_name",
			"the weapon"
		)
	)
	var action_label: String = str(
		crime.get(
			"weapon_action_label",
			"the action"
		)
	)
	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var contract_id: String = (
		"crime_aftermath:%s"
		% case_id
	)
	var contract: Dictionary = {
		"schema": (
			"eralife.crime_aftermath_pending_contract"
		),
		"version": 1,
		"id": contract_id,
		"contract_id": contract_id,
		"state": "pending",
		"category": "crime",
		"pending_category": "crime",
		"target_id": int(
			actor.id
		),
		"actor_id": int(
			actor.id
		),
		"title": "Crime Aftermath",
		"overview": (
			"You used %s to perform %s. "
			+ "No authority has identified you yet, but "
			+ "the event, evidence, victim, and witnesses "
			+ "continue existing in world truth."
		) % [
			weapon_name,
			action_label
		],
		"details": (
			"The crime is not erased because it was not "
			+ "immediately discovered. Decide how you respond "
			+ "to the scene and the possibility of later discovery."
		),
		"urgency": 82.0,
		"decay": 0.45,
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"deadline_at_ms": now_ms + 60000,
		"remaining_response_ms": 60000,
		"deadline_default_option_id": "leave_scene",
		"case_id": case_id,
		"crime_event": crime_event,
		"options": [
			{
				"id": "leave_scene",
				"label": "Leave the Scene",
				"text": "You leave before anyone connects you to it.",
				"result_text": (
					"You left the scene. The case remains "
					+ "capable of resurfacing."
				)
			},
			{
				"id": "help_target",
				"label": "Help the Target",
				"text": "You remain and attempt to help.",
				"result_text": (
					"You helped the target, increasing the "
					+ "chance that your involvement becomes known."
				)
			},
			{
				"id": "conceal_evidence",
				"label": "Conceal Evidence",
				"text": "You attempt to obscure what happened.",
				"result_text": (
					"You attempted to conceal evidence. "
					+ "The attempt itself now exists in case history."
				)
			},
			{
				"id": "confess",
				"label": "Confess",
				"text": "You report your own involvement.",
				"result_text": (
					"You confessed and brought the case "
					+ "into active investigation."
				)
			}
		],
		"source": str(
			context.get(
				"source",
				"pending_situations_engine.crime_aftermath"
			)
		),
		"ui_is_renderer_only": true
	}
	var activation_report: Dictionary = (
		gs.scenario_runtime_contract_engine
		.activate_popup_contract(
			contract
		)
	)

	emit_pending_situations_summary_contract({
		"target_id": int(
			actor.id
		),
		"source": (
			"crime_aftermath_contract_activated"
		)
	})

	return {
		"success": bool(
			activation_report.get(
				"success",
				false
			)
		),
		"mode": (
			"crime_aftermath_pending_contract_activated"
		),
		"contract_id": str(
			activation_report.get(
				"contract_id",
				contract_id
			)
		),
		"contract": contract,
		"activation_report": activation_report
	}
func emit_crime_pretrial_disposition_contract(
	actor: Person,
	case_data: Dictionary,
	arrested: bool,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if (
		actor == null
		or case_data.is_empty()
		or gs == null
		or gs.scenario_runtime_contract_engine == null
	):
		return {
			"success": false,
			"reason": (
				"crime_pretrial_disposition_dependencies_unavailable"
			)
		}

	var case_id: String = str(
		case_data.get(
			"case_id",
			""
		)
	).strip_edges()

	if case_id == "":
		return {
			"success": false,
			"reason": (
				"crime_pretrial_disposition_case_missing"
			)
		}

	var pretrial: Dictionary = _safe_dictionary(
		case_data.get(
			"pretrial_disposition",
			{}
		)
	)
	var booking: Dictionary = _safe_dictionary(
		case_data.get(
			"pretrial_booking",
			{}
		)
	)

	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	var response_options: Array = []
	var title: String = ""
	var overview: String = ""

	if arrested:
		title = "ARRESTED • CHARGED"
		overview = (
			"The interrogation is over. Probable cause was established, "
			+ "you have been formally charged, and you were booked into %s."
		) % str(
			booking.get(
				"facility_label",
				booking.get(
					"facility_type",
					"jail"
				)
			)
		)

		if bool(
			pretrial.get(
				"bail_allowed",
				false
			)
		):
			overview += (
				"\n\nBail has been set at %d."
				% int(
					pretrial.get(
						"bail_amount",
						0
					)
				)
			)

		response_options = [
			{
				"id": "review_charges",
				"label": "Review the Charges",
				"journal_text": (
					"I reviewed the charges filed against me."
				),
				"resolution_payload": {
					"action": "review_charges"
				}
			},
			{
				"id": "prepare_for_trial",
				"label": "Prepare for Trial",
				"journal_text": (
					"I prepared for the criminal trial ahead."
				),
				"resolution_payload": {
					"action": "prepare_for_trial"
				}
			}
		]

		if bool(
			pretrial.get(
				"bail_allowed",
				false
			)
		):
			response_options.insert(
				1,
				{
					"id": "ask_about_bail",
					"label": "Ask About Bail",
					"journal_text": (
						"I asked about the conditions of my bail."
					),
					"resolution_payload": {
						"action": "ask_about_bail"
					}
				}
			)

	else:
		title = (
			"INTERROGATION COMPLETE • RELEASED"
		)
		overview = (
			"The interrogation is over. The authorities did not establish "
			+ "enough probable cause to continue holding or charging you."
		)

		response_options = [
			{
				"id": "leave_custody",
				"label": "Leave Custody",
				"journal_text": (
					"I left custody after being released without charge."
				),
				"resolution_payload": {
					"action": "leave_custody"
				}
			},
			{
				"id": "call_someone",
				"label": "Call Someone I Trust",
				"journal_text": (
					"I called someone I trusted after being released."
				),
				"resolution_payload": {
					"action": "call_someone"
				}
			},
			{
				"id": "leave_silently",
				"label": "Say Nothing and Leave",
				"journal_text": (
					"I said nothing else and left custody."
				),
				"resolution_payload": {
					"action": "leave_silently"
				}
			}
		]

	var contract_id: String = (
		"crime_pretrial_disposition:%s"
		% case_id
	)

	var contract: Dictionary = {
		"schema": (
			"eralife.crime_pretrial_disposition_pending_contract"
		),
		"version": 1,
		"id": contract_id,
		"contract_id": contract_id,
		"contract_type": "scenario_popup",
		"state": "pending",
		"category": "crime",
		"pending_category": "crime",
		"target": int(
			actor.id
		),
		"target_id": int(
			actor.id
		),
		"actor_id": int(
			actor.id
		),
		"title": title,
		"overview": overview,
		"details": (
			"Your interrogation has ended. "
			+ "This is the live pretrial disposition of the case."
		),
		"urgency": 100.0,
		"decay": 0.0,
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"case_id": case_id,
		"arrested": arrested,
		"pretrial_disposition": pretrial,
		"booking_report": booking,
		"response_options": response_options,
		"options": response_options.duplicate(false),
		"resolution_route": {
			"engine_property": "case_orchestrator",
			"method": (
				"resolve_pretrial_disposition_choice"
			),
			"pass_actor_payload": true
		},
		"source": str(
			context.get(
				"source",
				"pending_situations_engine.pretrial_disposition"
			)
		),
		"contract_mesh": {
			"source_of_truth": (
				"PendingSituationsEngine"
			),
			"case_owner": "CaseOrchestrator",
			"ui_observer": "PopupViewer",
			"ui_mutation_allowed": false,
			"ready_gate_member": false
		}
	}

	var activation_report: Dictionary = (
		gs.scenario_runtime_contract_engine
		.activate_popup_contract(
			contract
		)
	)

	emit_pending_situations_summary_contract({
		"target_id": int(
			actor.id
		),
		"source": (
			"crime_pretrial_disposition_activated"
		)
	})

	return {
		"success": bool(
			activation_report.get(
				"success",
				false
			)
		),
		"mode": (
			"crime_pretrial_disposition_activated"
		),
		"contract_id": contract_id,
		"contract": contract,
		"activation_report": activation_report
	}
func emit_live_crime_trial_contract(
	actor: Person,
	scenario: Dictionary,
	case_data: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if (
		actor == null
		or scenario.is_empty()
		or case_data.is_empty()
		or gs == null
		or gs.scenario_runtime_contract_engine == null
	):
		return {
			"success": false,
			"reason": (
				"live_crime_trial_pending_dependencies_unavailable"
			)
		}

	var case_id: String = str(
		case_data.get(
			"case_id",
			""
		)
	)
	var stage: int = int(
		scenario.get(
			"trial_stage",
			-1
		)
	)

	var response_options: Array = []

	for raw_choice in _safe_array(
		scenario.get(
			"choices",
			[]
		)
	):
		var choice: Dictionary = _safe_dictionary(
			raw_choice
		)

		if choice.is_empty():
			continue

		var option: Dictionary = (
			choice.duplicate(false)
		)

		option [
			"resolution_payload"
		] = {
			"case_id": case_id,
			"trial_stage": stage,
			"trial_choice_id": str(
				choice.get(
					"id",
					""
				)
			)
		}

		response_options.append(
			option
		)

	var contract_id: String = str(
		scenario.get(
			"id",
			"live_crime_trial_%s_stage_%d"
			% [
				case_id,
				stage
			]
		)
	)

	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	var contract: Dictionary = {
		"schema": (
			"eralife.live_crime_trial_pending_contract"
		),
		"version": 1,
		"id": contract_id,
		"contract_id": contract_id,
		"contract_type": "scenario_popup",
		"state": "pending",
		"category": "crime_trial",
		"pending_category": "crime",
		"target": int(
			actor.id
		),
		"target_id": int(
			actor.id
		),
		"actor_id": int(
			actor.id
		),
		"title": str(
			scenario.get(
				"panel_title",
				"TRIAL"
			)
		),
		"overview": str(
			scenario.get(
				"prompt",
				""
			)
		),
		"details": str(
			scenario.get(
				"footer_text",
				"The court record changes with every answer."
			)
		),
		"urgency": 100.0,
		"decay": 0.0,
		"created_at_ms": now_ms,
		"updated_at_ms": now_ms,
		"case_id": case_id,
		"trial_stage": stage,
		"response_options": response_options,
		"options": response_options.duplicate(false),
		"resolution_route": {
			"engine_property": "case_orchestrator",
			"method": (
				"resolve_pending_live_crime_trial_choice"
			),
			"pass_actor_payload": true
		},
		"source": str(
			context.get(
				"source",
				"pending_situations_engine.live_crime_trial"
			)
		),
		"contract_mesh": {
			"source_of_truth": (
				"PendingSituationsEngine"
			),
			"case_owner": "CaseOrchestrator",
			"scenario_owner": "CaseOrchestrator",
			"view_owner": (
				"ContractViewLayerContractEngine"
			),
			"ui_observer": "PopupViewer",
			"ui_mutation_allowed": false,
			"ready_gate_member": false
		}
	}

	var activation_report: Dictionary = (
		gs.scenario_runtime_contract_engine
		.activate_popup_contract(
			contract
		)
	)

	emit_pending_situations_summary_contract({
		"target_id": int(
			actor.id
		),
		"source": "live_crime_trial_activated"
	})

	return {
		"success": bool(
			activation_report.get(
				"success",
				false
			)
		),
		"mode": "live_crime_trial_activated",
		"contract_id": contract_id,
		"live_trial_case_id": case_id,
		"live_trial_stage": stage,
		"contract": contract,
		"activation_report": activation_report,
		"queue_as_pending_situation": true,
		"popup_choices_are_contracts": true
	}
func _crime_authority_label_for_era(
	era_name: String
) -> String:
	match str(
		era_name
	).strip_edges():
		"Ancient Era":
			return "The Imperial Magistrate"
		"Medieval Era":
			return "The Crown's Constable"
		"Industrial Era":
			return "The City Inspector"
		"Future Era":
			return "The Tribunal Intelligence"
		_:
			return "Detectives"


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (value as Array).duplicate(true)
	return []