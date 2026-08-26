


extends RefCounted
class_name ActivitiesHubContractEngine

const ENGINE_SCHEMA:= "eralife.activities_hub_contract_engine"
const ENGINE_VERSION:= 1
const HUB_SCHEMA:= "eralife.activities_hub_contract"
const HUB_VERSION:= 1

var gs
var last_report: Dictionary = {}


func _init(_gs = null) -> void:
	gs = _gs


func bootstrap_default_contracts() -> Dictionary:
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"activity_law_authority": "activities_contract_engine",
		"ui_is_renderer_only": true
	}


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA + ".state",
		"version": ENGINE_VERSION,
		"last_report": last_report.duplicate(true)
	}


func import_state(
	data: Dictionary
) -> Dictionary:
	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION
	}


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(
			"missing_actor",
			"No Activities Hub observer could be resolved."
		)

	if (
		_law() == null
		or not _law().has_method(
			"resolve_intent"
		)
	):
		return _failure(
			"activities_law_unavailable",
			"Activities law is unavailable."
		)

	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get(
				"intent_type",
				"refresh"
			)
		)
	).strip_edges().to_lower()
	var observable_projection_action: bool = action_id in [
		"observe_partial",
		"open_observable",
		"emit_observable_contract"
	]
	var standard_projection_action: bool = action_id in [
		"",
		"refresh",
		"open_hub",
		"set_section"
	]
	var result: Dictionary = {}
	var contract: Dictionary = {}

	if observable_projection_action:
		contract = emit_observable_contract(
			actor,
			{
				"active_section": str(
					payload.get(
						"section_id",
						"all"
					)
				),
				"status_text": str(
					payload.get(
						"status_text",
						(
							"Activity reality already exists "
							+ "and is observable."
						)
					)
				),
				"source": str(
					payload.get(
						"source",
						(
							"activities_hub_contract_engine."
							+ "observable_projection"
						)
					)
				)
			}
		)
		result = {
			"success": true,
			"type": "activities_hub_observable_projection"
		}
	elif standard_projection_action:
		result = _dict(
			_law().resolve_intent(
				actor,
				payload
			)
		)
		contract = _dict(
			result.get(
				"activities_hub_contract",
				{}
			)
		)

		if contract.is_empty():
			contract = emit_hub_contract(
				actor,
				{
					"active_section": str(
						payload.get(
							"section_id",
							"all"
						)
					),
					"status_text": str(
						result.get(
							"text",
							""
						)
					),
					"source": str(
						payload.get(
							"source",
							(
								"activities_hub_contract_engine."
								+ "authoritative_projection"
							)
						)
					)
				}
			)
	else:
		result = _dict(
			_law().resolve_intent(
				actor,
				payload
			)
		)
		contract = _dict(
			result.get(
				"activities_hub_contract",
				{}
			)
		)

		if not bool(
			payload.get(
				"include_projection_after_intent",
				false
			)
		):
			contract = {}
			result.erase("activities_hub_contract")
			result ["activities_hub_projection_rebuilt"] = false
			result ["activities_hub_projection_preserved"] = true
			result ["activities_action_input_frame_build"] = false

	if not contract.is_empty():
		result ["activities_hub_contract"] = contract

	result ["activities_hub_contract_engine_owned"] = true
	result ["activities_contract_engine_delegated"] = (
		not observable_projection_action
	)
	result ["ui_is_renderer_only"] = true
	last_report = result.duplicate(true)

	return result

func persist_section_lens(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	var law = _law()

	if (
		law == null
		or not law.has_method(
			"persist_section_lens"
		)
	):
		return _failure(
			"activities_law_unavailable",
			(
				"The Activities lens authority "
				+ "is not currently available."
			)
		)

	return _dict(
		law.persist_section_lens(
			actor,
			payload
		)
	)
func emit_observable_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		_law() == null
		or not _law().has_method(
			"emit_observable_contract"
		)
	):
		return _failure(
			"activities_law_unavailable",
			"Activities observable law is unavailable."
		)

	return _decorate_contract(
		_dict(
			_law().emit_observable_contract(
				actor,
				context
			)
		)
	)


func emit_hub_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		_law() == null
		or not _law().has_method(
			"emit_hub_contract"
		)
	):
		return _failure(
			"activities_law_unavailable",
			"Activities projection law is unavailable."
		)

	return _decorate_contract(
		_dict(
			_law().emit_hub_contract(
				actor,
				context
			)
		)
	)


func _decorate_contract(
	contract: Dictionary
) -> Dictionary:
	if contract.is_empty():
		return contract

	var decorated: Dictionary = contract.duplicate(true)
	decorated ["schema"] = str(
		decorated.get(
			"schema",
			HUB_SCHEMA
		)
	)
	decorated ["version"] = int(
		decorated.get(
			"version",
			HUB_VERSION
		)
	)
	decorated ["hub_orchestration_authority"] = ENGINE_SCHEMA
	decorated ["activity_law_authority"] = (
		"activities_contract_engine"
	)
	decorated ["ui_is_renderer_only"] = true

	return decorated


func _law():
	return (
		gs.activities_contract_engine
		if (
			gs != null
			and gs.activities_contract_engine != null
		)
		else null
	)

func _resolve_incarceration_intent_if_active(
		actor: Person,
		payload: Dictionary
) -> Dictionary:
	if (
		actor == null
		or gs == null
	):
		return {}

	var custody_authority = null
	var custody_contract: Dictionary = {}

	if (
		gs.prison_engine != null
		and gs.prison_engine.has_method(
			"resident_prison_reality_contract"
		)
	):
		custody_contract = _dict(
			gs.prison_engine.resident_prison_reality_contract(
				int(
					actor.id
				)
			)
		)

		if not custody_contract.is_empty():
			custody_authority = gs.prison_engine

	if (
		custody_contract.is_empty()
		and gs.jail_engine != null
		and gs.jail_engine.has_method(
			"resident_jail_reality_contract"
		)
	):
		custody_contract = _dict(
			gs.jail_engine.resident_jail_reality_contract(
				int(
					actor.id
				)
			)
		)

		if not custody_contract.is_empty():
			custody_authority = gs.jail_engine

	if custody_contract.is_empty():
		return {}

	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get(
				"intent_type",
				"refresh"
			)
		)
	).strip_edges().to_lower()
	var surface_contracts: Dictionary = _dict(
		custody_contract.get(
			"surface_contracts",
			{}
		)
	)
	var activities_contract: Dictionary = _dict(
		surface_contracts.get(
			"activities",
			{}
		)
	)

	if action_id in [
		"",
		"refresh",
		"open_hub",
		"set_section",
		"observe_partial",
		"open_observable",
		"emit_observable_contract"
	]:
		return {
			"success": true,
			"type": "incarceration_activities_projection",
			"activities_hub_contract": activities_contract,
			"activities_hub_contract_engine_owned": true,
			"activities_contract_engine_delegated": false,
			"ui_is_renderer_only": true
		}

	if action_id != "incarceration_activity":
		return _failure(
			"free_world_activity_blocked_by_incarceration",
			"Outside activities are unavailable while incarcerated."
		)

	if (
		custody_authority == null
		or not custody_authority.has_method(
			"resolve_incarceration_intent"
		)
	):
		return _failure(
			"incarceration_activity_authority_unavailable",
			"The current facility cannot resolve that activity."
		)

	return _dict(
		custody_authority.resolve_incarceration_intent(
			actor,
			payload
		)
	)
func _dict(
	value
) -> Dictionary:
	return (
		(value as Dictionary).duplicate(true)
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)


func _failure(
	reason: String,
	text: String
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"text": text,
		"ui_is_renderer_only": true
	}