extends Resource
class_name JailEngine

const CONTRACT_VERSION:= 1

var gs
var bookings: Dictionary = {}
var holding_cells: Dictionary = {}
var ledger: Array = []
var last_report: Dictionary = {}


var jail_facility_contract_by_id: Dictionary = {}




var resident_jail_reality_by_actor: Dictionary = {}
var jail_facility_members_by_id: Dictionary = {}
var jail_cellmate_by_actor: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func execute_booking(
		case_data: Dictionary,
		verdict: Dictionary = {},
		context: Dictionary = {}
) -> Dictionary:
	if (
		typeof(case_data) != TYPE_DICTIONARY
		or case_data.is_empty()
	):
		return {
			"success": false,
			"reason": "JailEngine needs a CaseObject."
		}

	var case_id: String = str(
		case_data.get(
			"case_id",
			""
		)
	).strip_edges()
	var participants: Dictionary = _safe_dictionary(
		case_data.get(
			"participants",
			{}
		)
	)
	var accused_id: int = int(
		participants.get(
			"accused",
			-1
		)
	)

	if (
		case_id == ""
		or accused_id <= 0
	):
		return {
			"success": false,
			"reason": "Booking needs case_id and accused id."
		}

	var sentence: Dictionary = _safe_dictionary(
		verdict.get(
			"sentence",
			{}
		)
	)
	var facility_contract: Dictionary = _jail_facility_contract(
		case_data,
		verdict,
		context
	)
	var facility_id: String = str(
		facility_contract.get(
			"facility_id",
			""
		)
	).strip_edges()

	if facility_id == "":
		return {
			"success": false,
			"reason": "Jail booking could not resolve a facility identity."
		}

	var incarceration_context: Dictionary = _build_jail_incarceration_context(
		case_data,
		verdict,
		facility_contract,
		context
	)

	var booking:= {
		"schema": "eralife.jail_booking",
		"version": CONTRACT_VERSION,
		"booking_id": "booking_%s" % case_id,
		"case_id": case_id,
		"accused_id": accused_id,
		"status": "booked",
		"incarceration_kind": "jail",
		"facility_id": facility_id,
		"holding_reason": str(
			context.get(
				"holding_reason",
				"post_verdict_transfer"
			)
		),
		"bail_allowed": bool(
			context.get(
				"bail_allowed",
				false
			)
		),
		"bail_amount": int(
			context.get(
				"bail_amount",
				0
			)
		),
		"verdict_outcome": str(
			verdict.get(
				"outcome",
				""
			)
		),
		"sentence_type": str(
			sentence.get(
				"type",
				"jail_holding"
			)
		),
		"sentence_years": int(
			sentence.get(
				"duration",
				0
			)
		),
		"facility_type": str(
			facility_contract.get(
				"facility_type",
				"Country Jail"
			)
		),
		"facility_label": str(
			facility_contract.get(
				"facility_label",
				"Country Jail"
			)
		),
		"security_level": str(
			facility_contract.get(
				"security_level",
				"Low"
			)
		),
		"incarceration_context": incarceration_context.duplicate(true),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	bookings [
		str(
			booking.get(
				"booking_id",
				""
			)
		)
	] = booking.duplicate(true)

	holding_cells [
		str(
			accused_id
		)
	] = booking.duplicate(true)


	_register_jail_resident(
		booking,
		facility_contract
	)

	_apply_jail_context_to_actor(
		accused_id,
		booking
	)



	_publish_jail_facility_residency(
		facility_id,
		"jail_booking"
	)

	last_report = _record(
		"jail_booking_created",
		booking
	)
	last_report ["incarceration_context_applied"] = true
	last_report ["incarceration_context"] = incarceration_context.duplicate(true)
	last_report ["resident_jail_reality_hot"] = (
		not resident_jail_reality_contract(
			accused_id
		).is_empty()
	)

	return last_report.duplicate(true)

func release_from_jail(
		accused_id: int,
		reason: String = "released"
) -> Dictionary:
	var key: String = str(
		accused_id
	)

	if not holding_cells.has(
		key
	):
		return {
			"success": false,
			"reason": "Actor is not in jail holding."
		}

	var booking: Dictionary = holding_cells.get(
		key,
		{}
	).duplicate(true)
	var facility_id: String = str(
		booking.get(
			"facility_id",
			""
		)
	).strip_edges()

	booking ["status"] = str(
		reason
	)
	booking ["released_at_ms"] = int(
		Time.get_ticks_msec()
	)

	holding_cells.erase(
		key
	)
	bookings [
		str(
			booking.get(
				"booking_id",
				""
			)
		)
	] = booking.duplicate(true)

	_unregister_jail_resident(
		accused_id,
		facility_id
	)

	var context_cleared: bool = (
		_clear_jail_context_from_actor(
			accused_id,
			reason
		)
	)

	if facility_id != "":
		_publish_jail_facility_residency(
			facility_id,
			"jail_release"
		)

	last_report = _record(
		"jail_release",
		booking
	)
	last_report ["incarceration_context_cleared"] = (
		context_cleared
	)
	last_report ["incarceration_owner_preserved"] = (
		not context_cleared
	)

	return last_report.duplicate(true)
func get_jail_rows(_context: Dictionary = {}) -> Array:
	var out: Array = []
	for raw_key in holding_cells.keys():
		var row: Dictionary = holding_cells.get(raw_key, {})
		out.append({
			"label": "Holding: person %d • case %s • %s" % [
				int(row.get("accused_id", -1)),
				str(row.get("case_id", "")),
				str(row.get("holding_reason", "holding"))
			],
			"kind": "jail_holding",
			"case_id": str(row.get("case_id", ""))
		})
	return out

func export_state() -> Dictionary:
	return {
		"schema": "eralife.jail_engine_state",
		"version": CONTRACT_VERSION,
		"bookings": bookings.duplicate(true),
		"holding_cells": holding_cells.duplicate(true),
		"facility_contract_by_id": jail_facility_contract_by_id.duplicate(true),
		"ledger": ledger.duplicate(true),
		"last_report": last_report.duplicate(true)
	}

func import_state(
		data: Dictionary
) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "JailEngine import data must be a Dictionary."
		}

	var bookings_raw: Variant = data.get(
		"bookings",
		{}
	)
	bookings = (
		bookings_raw.duplicate(true)
		if typeof(bookings_raw) == TYPE_DICTIONARY
		else {}
	)

	var holding_raw: Variant = data.get(
		"holding_cells",
		{}
	)
	holding_cells = (
		holding_raw.duplicate(true)
		if typeof(holding_raw) == TYPE_DICTIONARY
		else {}
	)

	var facility_raw: Variant = data.get(
		"facility_contract_by_id",
		{}
	)
	jail_facility_contract_by_id = (
		facility_raw.duplicate(true)
		if typeof(facility_raw) == TYPE_DICTIONARY
		else {}
	)

	var ledger_raw: Variant = data.get(
		"ledger",
		[]
	)
	ledger = (
		ledger_raw.duplicate(true)
		if typeof(ledger_raw) == TYPE_ARRAY
		else []
	)

	var last_report_raw: Variant = data.get(
		"last_report",
		{}
	)
	last_report = (
		last_report_raw.duplicate(true)
		if typeof(last_report_raw) == TYPE_DICTIONARY
		else {}
	)

	resident_jail_reality_by_actor.clear()
	jail_facility_members_by_id.clear()
	jail_cellmate_by_actor.clear()



	_rebuild_resident_jail_indexes_from_canonical_records()

	return {
		"success": true,
		"imported_at_ms": int(
			Time.get_ticks_msec()
		),
	}
func _register_jail_resident(
		booking: Dictionary,
		facility_contract: Dictionary
) -> void:
	var actor_id: int = int(
		booking.get(
			"accused_id",
			-1
		)
	)
	var facility_id: String = str(
		booking.get(
			"facility_id",
			facility_contract.get(
				"facility_id",
				""
			)
		)
	).strip_edges()

	if (
		actor_id <= 0
		or facility_id == ""
	):
		return

	jail_facility_contract_by_id [
		facility_id
	] = facility_contract.duplicate(true)

	var member_ids: Array = _safe_array(
		jail_facility_members_by_id.get(
			facility_id,
			[]
		)
	).duplicate(false)

	if actor_id not in member_ids:
		member_ids.append(
			actor_id
		)

	member_ids.sort()

	jail_facility_members_by_id [
		facility_id
	] = member_ids

	_assign_jail_cellmate(
		actor_id,
		facility_id
	)


func _unregister_jail_resident(
		actor_id: int,
		facility_id: String
) -> void:
	if actor_id <= 0:
		return

	var clean_facility_id: String = str(
		facility_id
	).strip_edges()
	var actor_key: String = str(
		actor_id
	)
	var former_cellmate_id: int = int(
		jail_cellmate_by_actor.get(
			actor_key,
			-1
		)
	)

	jail_cellmate_by_actor.erase(
		actor_key
	)

	if (
		former_cellmate_id > 0
		and int(
			jail_cellmate_by_actor.get(
				str(
					former_cellmate_id
				),
				-1
			)
		) == actor_id
	):
		jail_cellmate_by_actor.erase(
			str(
				former_cellmate_id
			)
		)

	resident_jail_reality_by_actor.erase(
		actor_key
	)

	if clean_facility_id == "":
		return

	var member_ids: Array = _safe_array(
		jail_facility_members_by_id.get(
			clean_facility_id,
			[]
		)
	).duplicate(false)

	member_ids.erase(
		actor_id
	)

	if member_ids.is_empty():
		jail_facility_members_by_id.erase(
			clean_facility_id
		)
	else:
		member_ids.sort()

		jail_facility_members_by_id [
			clean_facility_id
		] = member_ids

	if (
		former_cellmate_id > 0
		and former_cellmate_id in member_ids
	):
		_assign_jail_cellmate(
			former_cellmate_id,
			clean_facility_id
		)


func _assign_jail_cellmate(
		actor_id: int,
		facility_id: String
) -> int:
	if (
		actor_id <= 0
		or facility_id.strip_edges() == ""
	):
		return -1

	var actor_key: String = str(
		actor_id
	)
	var existing_cellmate_id: int = int(
		jail_cellmate_by_actor.get(
			actor_key,
			-1
		)
	)

	if (
		existing_cellmate_id > 0
		and _jail_actors_share_facility(
			actor_id,
			existing_cellmate_id
		)
	):
		return existing_cellmate_id

	var member_ids: Array = _safe_array(
		jail_facility_members_by_id.get(
			facility_id,
			[]
		)
	).duplicate(false)

	member_ids.sort()

	for raw_candidate_id in member_ids:
		var candidate_id: int = int(
			raw_candidate_id
		)

		if (
			candidate_id <= 0
			or candidate_id == actor_id
		):
			continue

		var candidate_cellmate_id: int = int(
			jail_cellmate_by_actor.get(
				str(
					candidate_id
				),
				-1
			)
		)

		if candidate_cellmate_id > 0:
			continue

		jail_cellmate_by_actor [
			actor_key
		] = candidate_id

		jail_cellmate_by_actor [
			str(
				candidate_id
			)
		] = actor_id

		return candidate_id

	jail_cellmate_by_actor [
		actor_key
	] = -1

	return -1


func _jail_actors_share_facility(
		first_actor_id: int,
		second_actor_id: int
) -> bool:
	if (
		first_actor_id <= 0
		or second_actor_id <= 0
	):
		return false

	var first_row: Dictionary = _safe_dictionary(
		holding_cells.get(
			str(
				first_actor_id
			),
			{}
		)
	)
	var second_row: Dictionary = _safe_dictionary(
		holding_cells.get(
			str(
				second_actor_id
			),
			{}
		)
	)

	if (
		first_row.is_empty()
		or second_row.is_empty()
	):
		return false

	var first_facility_id: String = str(
		first_row.get(
			"facility_id",
			""
		)
	).strip_edges()
	var second_facility_id: String = str(
		second_row.get(
			"facility_id",
			""
		)
	).strip_edges()

	return (
		first_facility_id != ""
		and first_facility_id == second_facility_id
	)


func _publish_jail_facility_residency(
		facility_id: String,
		reason: String
) -> void:
	var clean_facility_id: String = str(
		facility_id
	).strip_edges()

	if clean_facility_id == "":
		return

	var member_ids: Array = _safe_array(
		jail_facility_members_by_id.get(
			clean_facility_id,
			[]
		)
	).duplicate(false)

	for raw_actor_id in member_ids:
		var actor_id: int = int(
			raw_actor_id
		)

		if actor_id <= 0:
			continue

		var contract: Dictionary = _compose_jail_reality_contract(
			actor_id,
			reason
		)

		if contract.is_empty():
			continue

		resident_jail_reality_by_actor [
			str(
				actor_id
			)
		] = contract.duplicate(false)


func _rebuild_resident_jail_indexes_from_canonical_records() -> void:
	resident_jail_reality_by_actor.clear()
	jail_facility_members_by_id.clear()
	jail_cellmate_by_actor.clear()

	for raw_key in holding_cells.keys():
		var actor_id: int = int(
			raw_key
		)
		var booking: Dictionary = _safe_dictionary(
			holding_cells.get(
				raw_key,
				{}
			)
		).duplicate(true)

		if (
			actor_id <= 0
			or booking.is_empty()
		):
			continue

		var facility_id: String = str(
			booking.get(
				"facility_id",
				""
			)
		).strip_edges()

		if facility_id == "":
			var incarceration_context: Dictionary = _safe_dictionary(
				booking.get(
					"incarceration_context",
					{}
				)
			)

			facility_id = str(
				incarceration_context.get(
					"facility_id",
					""
				)
			).strip_edges()

		if facility_id == "":
			facility_id = _legacy_jail_facility_id_from_booking(
				booking
			)

		booking ["facility_id"] = facility_id
		booking ["incarceration_kind"] = "jail"

		var facility_contract: Dictionary = _safe_dictionary(
			jail_facility_contract_by_id.get(
				facility_id,
				{}
			)
		)

		if facility_contract.is_empty():
			facility_contract = _jail_facility_contract_from_booking(
				booking
			)

			jail_facility_contract_by_id [
				facility_id
			] = facility_contract.duplicate(true)

		holding_cells [
			str(
				actor_id
			)
		] = booking.duplicate(true)

		var booking_id: String = str(
			booking.get(
				"booking_id",
				""
			)
		).strip_edges()

		if booking_id != "":
			bookings [
				booking_id
			] = booking.duplicate(true)

		_register_jail_resident(
			booking,
			facility_contract
		)

	for raw_facility_id in jail_facility_members_by_id.keys():
		_publish_jail_facility_residency(
			str(
				raw_facility_id
			),
			"state_hydration"
		)


func _legacy_jail_facility_id_from_booking(
		booking: Dictionary
) -> String:
	var incarceration_context: Dictionary = _safe_dictionary(
		booking.get(
			"incarceration_context",
			{}
		)
	)
	var era_name: String = str(
		incarceration_context.get(
			"era",
			_current_era_name()
		)
	).strip_edges()
	var facility_type: String = str(
		booking.get(
			"facility_type",
			"Country Jail"
		)
	).strip_edges()

	return (
		"jail:world:%s:%s"
		% [
			era_name.to_lower().replace(
				" ",
				"_"
			),
			facility_type.to_lower().replace(
				" ",
				"_"
			)
		]
	)


func _jail_facility_contract_from_booking(
		booking: Dictionary
) -> Dictionary:
	var incarceration_context: Dictionary = _safe_dictionary(
		booking.get(
			"incarceration_context",
			{}
		)
	)
	var facility_id: String = str(
		booking.get(
			"facility_id",
			""
		)
	).strip_edges()

	if facility_id == "":
		facility_id = _legacy_jail_facility_id_from_booking(
			booking
		)

	return {
		"schema": "eralife.incarceration_facility_contract",
		"version": CONTRACT_VERSION,
		"facility_id": facility_id,
		"facility_type": str(
			booking.get(
				"facility_type",
				"Country Jail"
			)
		),
		"facility_label": str(
			booking.get(
				"facility_label",
				booking.get(
					"facility_type",
					"Country Jail"
				)
			)
		),
		"incarceration_kind": "jail",
		"era": str(
			incarceration_context.get(
				"era",
				_current_era_name()
			)
		),
		"security_level": str(
			booking.get(
				"security_level",
				"Low"
			)
		),
		"rules": _safe_array(
			incarceration_context.get(
				"rules",
				[]
			)
		).duplicate(true),
		"restrictions": _safe_array(
			incarceration_context.get(
				"restrictions",
				[]
			)
		).duplicate(true),
		"immutable": true
	}


func resident_jail_reality_contract(
		actor_id: int
) -> Dictionary:
	if actor_id <= 0:
		return {}

	var raw_contract: Variant = resident_jail_reality_by_actor.get(
		str(
			actor_id
		),
		{}
	)

	if typeof(raw_contract) != TYPE_DICTIONARY:
		return {}

	return (
		raw_contract as Dictionary
	).duplicate(false)


func resident_incarceration_status_contract(
		actor_id: int
) -> Dictionary:
	if actor_id <= 0:
		return {}

	var booking: Dictionary = _safe_dictionary(
		holding_cells.get(
			str(
				actor_id
			),
			{}
		)
	)

	return {
		"schema": "eralife.jail.resident_incarceration_status",
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"active": not booking.is_empty(),
		"status": str(
			booking.get(
				"status",
				""
			)
		),
		"facility_id": str(
			booking.get(
				"facility_id",
				""
			)
		),
		"read_only": true,
		"truth_state": "hot"
	}


func resident_target_access_contract(
		actor_id: int,
		target_id: int
) -> Dictionary:
	var actor_booking: Dictionary = _safe_dictionary(
		holding_cells.get(
			str(
				actor_id
			),
			{}
		)
	)

	if actor_booking.is_empty():
		return {
			"incarcerated": false,
			"allowed": true
		}

	var target_booking: Dictionary = _safe_dictionary(
		holding_cells.get(
			str(
				target_id
			),
			{}
		)
	)
	var facility_id: String = str(
		actor_booking.get(
			"facility_id",
			""
		)
	).strip_edges()

	return {
		"incarcerated": true,
		"actor_id": actor_id,
		"target_id": target_id,
		"facility_id": facility_id,
		"allowed": (
			not target_booking.is_empty()
			and target_id != actor_id
			and str(
				target_booking.get(
					"facility_id",
					""
				)
			).strip_edges() == facility_id
		),
		"population_scan_performed": false,
		"truth_state": "hot",
		"read_only": true
	}


func _jail_population_cards(
		actor_id: int,
		active_booking: Dictionary
) -> Array:
	var facility_id: String = str(
		active_booking.get(
			"facility_id",
			""
		)
	).strip_edges()

	if facility_id == "":
		return []

	var member_ids: Array = _safe_array(
		jail_facility_members_by_id.get(
			facility_id,
			[]
		)
	)
	var cellmate_id: int = int(
		jail_cellmate_by_actor.get(
			str(
				actor_id
			),
			-1
		)
	)
	var ordered_ids: Array = []

	if (
		cellmate_id > 0
		and cellmate_id != actor_id
		and cellmate_id in member_ids
	):
		ordered_ids.append(
			cellmate_id
		)

	for raw_member_id in member_ids:
		var detainee_id: int = int(
			raw_member_id
		)

		if (
			detainee_id <= 0
			or detainee_id == actor_id
			or detainee_id == cellmate_id
		):
			continue

		ordered_ids.append(
			detainee_id
		)

	var out: Array = []

	for detainee_id in ordered_ids:
		var booking: Dictionary = _safe_dictionary(
			holding_cells.get(
				str(
					detainee_id
				),
				{}
			)
		)

		if booking.is_empty():
			continue

		if str(
			booking.get(
				"facility_id",
				""
			)
		).strip_edges() != facility_id:
			continue

		var person = _actor_by_id(
			detainee_id
		)
		var person_name: String = (
			(
				"%s %s"
				% [
					str(
						person.first_name
					),
					str(
						person.last_name
					)
				]
			).strip_edges()
			if person != null
			else "Person %d" % detainee_id
		)
		var is_cellmate: bool = (
			detainee_id == cellmate_id
		)

		out.append({
			"kind": "jail_population_card",
			"card_kind": "person",
			"target_id": detainee_id,
			"person_id": detainee_id,
			"label": person_name,
			"name": person_name,
			"role": (
				"Cellmate"
				if is_cellmate
				else "Detainee"
			),
			"relationship_label": (
				"Cellmate"
				if is_cellmate
				else "Detainee"
			),
			"subtitle": (
				"%s • %s"
				% [
					(
						"Cellmate"
						if is_cellmate
						else "Detainee"
					),
					str(
						booking.get(
							"facility_label",
							"Jail"
						)
					)
				]
			),
			"facility_id": facility_id,
			"featured": is_cellmate,
			"cellmate": is_cellmate,
			"can_open_profile": true,
			"ui_is_renderer_only": true
		})

	return out


func _jail_crime_target_cards(
		population_cards: Array
) -> Array:
	var out: Array = []

	for raw_card in population_cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = raw_card as Dictionary
		var target_id: int = int(
			card.get(
				"target_id",
				-1
			)
		)

		if target_id <= 0:
			continue

		out.append({
			"kind": "crime_target",
			"label": str(
				card.get(
					"label",
					"Detainee"
				)
			),
			"target_id": target_id,
			"subtitle": str(
				card.get(
					"subtitle",
					"Current detainee"
				)
			),
			"relationship_label": str(
				card.get(
					"relationship_label",
					"Detainee"
				)
			),
			"target_source": (
				"incarceration_cellmate"
				if bool(
					card.get(
						"cellmate",
						false
					)
				)
				else "incarceration_facility_population"
			),
			"facility_id": str(
				card.get(
					"facility_id",
					""
				)
			),
			"actions": [],
		})

	return out


func resident_facility_contract_cards(
		exclude_facility_id: String = ""
) -> Array:
	var out: Array = []
	var clean_exclude: String = str(
		exclude_facility_id
	).strip_edges()

	for raw_facility_id in jail_facility_contract_by_id.keys():
		var facility_id: String = str(
			raw_facility_id
		).strip_edges()

		if (
			facility_id == ""
			or facility_id == clean_exclude
		):
			continue

		var contract: Dictionary = _safe_dictionary(
			jail_facility_contract_by_id.get(
				facility_id,
				{}
			)
		)

		if contract.is_empty():
			continue

		var member_count: int = _safe_array(
			jail_facility_members_by_id.get(
				facility_id,
				[]
			)
		).size()

		out.append({
			"kind": "incarceration_facility_card",
			"facility_id": facility_id,
			"incarceration_kind": "jail",
			"label": str(
				contract.get(
					"facility_label",
					contract.get(
						"facility_type",
						"Jail"
					)
				)
			),
			"subtitle": (
				"%s • %s • %d detainees"
				% [
					str(
						contract.get(
							"era",
							_current_era_name()
						)
					),
					str(
						contract.get(
							"security_level",
							"Low"
						)
					),
					member_count
				]
			),
			"security_level": str(
				contract.get(
					"security_level",
					"Low"
				)
			),
			"resident_count": member_count,
			"ui_is_renderer_only": true
		})

	return out


func _other_jail_facility_cards(
		current_facility_id: String
) -> Array:
	var out: Array = resident_facility_contract_cards(
		current_facility_id
	)
	var seen: Dictionary = {}

	for raw_card in out:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		seen [
			str(
				(raw_card as Dictionary).get(
					"facility_id",
					""
				)
			)
		] = true

	if (
		gs != null
		and gs.prison_engine != null
		and gs.prison_engine.has_method(
			"resident_facility_contract_cards"
		)
	):
		var prison_cards: Array = gs.prison_engine.call(
			"resident_facility_contract_cards",
			current_facility_id
		)

		for raw_card in prison_cards:
			if typeof(raw_card) != TYPE_DICTIONARY:
				continue

			var card: Dictionary = raw_card as Dictionary
			var facility_id: String = str(
				card.get(
					"facility_id",
					""
				)
			).strip_edges()

			if (
				facility_id == ""
				or seen.has(
					facility_id
				)
			):
				continue

			seen [
				facility_id
			] = true

			out.append(
				card.duplicate(false)
			)

	out.sort_custom(
		func (left: Dictionary, right: Dictionary) -> bool:
			return str(
				left.get(
					"label",
					""
				)
			) < str(
				right.get(
					"label",
					""
				)
			)
	)

	return out


func _jail_navigation_labels(
		era_name: String
) -> Dictionary:
	match era_name:
		"Ancient Era":
			return {
				"world": "DUNGEON ",
				"life": "SENTENCE ",
				"school": "INSTRUCTION ",
				"activities": "CELL BLOCK ",
				"relationships": "PRISONERS / GUARDS ",
				"career": "LABOR ",
				"age_up": "SERVE TIME",
				"mods": "MODS"
			}

		"Medieval Era":
			return {
				"world": "DUNGEON ",
				"life": "SENTENCE ",
				"school": "REFORM ",
				"activities": "CELL BLOCK ",
				"relationships": "PRISONERS / GUARDS ",
				"career": "LABOR ",
				"age_up": "SERVE TIME",
				"mods": "MODS"
			}

		"Future Era":
			return {
				"world": "DETENTION BLOCK ",
				"life": "SENTENCE ",
				"school": "PROGRAMS ",
				"activities": "REC BLOCK ",
				"relationships": "DETAINEES / GUARDS ",
				"career": "FACILITY WORK ",
				"age_up": "SERVE TIME",
				"mods": "MODS"
			}

		_:
			return {
				"world": "FACILITY ",
				"life": "SENTENCE ",
				"school": "PROGRAMS ",
				"activities": "CELL BLOCK ",
				"relationships": "DETAINEES / GUARDS ",
				"career": "JAIL WORK ",
				"age_up": "SERVE TIME",
				"mods": "MODS"
			}


func _jail_facility_surface_contract(
		actor_id: int,
		booking: Dictionary,
		population_cards: Array
) -> Dictionary:
	return {
		"schema": "eralife.incarceration_facility_surface",
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"title": "FACILITY",
		"subtitle": str(
			booking.get(
				"facility_label",
				"Jail"
			)
		),
		"facility_id": str(
			booking.get(
				"facility_id",
				""
			)
		),
		"body_lines": [
			(
				"You are being held at %s."
				% str(
					booking.get(
						"facility_label",
						"Jail"
					)
				)
			),
			(
				"Security: %s"
				% str(
					booking.get(
						"security_level",
						"Low"
					)
				)
			),
			(
				"Other detainees currently resident here: %d"
				% population_cards.size()
			),
			(
				"Holding reason: %s"
				% str(
					booking.get(
						"holding_reason",
						"holding"
					)
				).capitalize()
			)
		],
		"truth_state": "hot",
		"projection_complete": true,
		"ui_is_renderer_only": true
	}


func _jail_sentence_surface_contract(
		actor_id: int,
		booking: Dictionary
) -> Dictionary:
	return {
		"schema": "eralife.incarceration_sentence_surface",
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"title": "SENTENCE",
		"subtitle": str(
			booking.get(
				"facility_label",
				"Jail"
			)
		),
		"body_lines": [
			(
				"Case: %s"
				% str(
					booking.get(
						"case_id",
						"Unknown"
					)
				)
			),
			(
				"Status: %s"
				% str(
					booking.get(
						"status",
						"booked"
					)
				).capitalize()
			),
			(
				"Bail: %s"
				% (
					"Available"
					if bool(
						booking.get(
							"bail_allowed",
							false
						)
					)
					else "Unavailable"
				)
			)
		],
		"truth_state": "hot",
		"projection_complete": true,
		"ui_is_renderer_only": true
	}


func _jail_main_surface_contracts(
		actor_id: int,
		booking: Dictionary,
		population_cards: Array
) -> Dictionary:
	var cellmate_cards: Array = []
	var detainee_cards: Array = []

	for raw_card in population_cards:
		if typeof(raw_card) != TYPE_DICTIONARY:
			continue

		var card: Dictionary = (
			raw_card as Dictionary
		).duplicate(false)

		if bool(
			card.get(
				"cellmate",
				false
			)
		):
			cellmate_cards.append(
				card
			)
		else:
			detainee_cards.append(
				card
			)

	var relationship_tabs: Array = [
		{
			"id": "cellmate",
			"key": "cellmate",
			"label": "CELLMATE"
		},
		{
			"id": "detainees",
			"key": "detainees",
			"label": "DETAINEES"
		},
		{
			"id": "guards",
			"key": "guards",
			"label": "GUARDS"
		}
	]
	var relationship_sections: Dictionary = {
		"cellmate": {
			"schema": "eralife.relationships_hub.contract",
			"version": 2,
			"actor_id": actor_id,
			"title": "DETAINEES / GUARDS",
			"subtitle": str(
				booking.get(
					"facility_label",
					"Jail"
				)
			),
			"active_section_id": "cellmate",
			"tabs": relationship_tabs,
			"groups": [
				{
					"row_kind": "people_group",
					"title": "CELLMATE",
					"cards": cellmate_cards,
					"empty_text": "Cell assignment is still pending.",
					"columns": 3
				}
			],
			"truth_state": "hot",
			"projection_complete": true,
			"authoritative_projection": true,
			"ui_is_renderer_only": true
		},
		"detainees": {
			"schema": "eralife.relationships_hub.contract",
			"version": 2,
			"actor_id": actor_id,
			"title": "DETAINEES / GUARDS",
			"subtitle": str(
				booking.get(
					"facility_label",
					"Jail"
				)
			),
			"active_section_id": "detainees",
			"tabs": relationship_tabs,
			"groups": [
				{
					"row_kind": "people_group",
					"title": "DETAINEES",
					"cards": detainee_cards,
					"empty_text": "No other detainees are resident here.",
					"columns": 3
				}
			],
			"truth_state": "hot",
			"projection_complete": true,
			"authoritative_projection": true,
			"ui_is_renderer_only": true
		},
		"guards": {
			"schema": "eralife.relationships_hub.contract",
			"version": 2,
			"actor_id": actor_id,
			"title": "DETAINEES / GUARDS",
			"subtitle": str(
				booking.get(
					"facility_label",
					"Jail"
				)
			),
			"active_section_id": "guards",
			"tabs": relationship_tabs,
			"groups": [
				{
					"row_kind": "people_group",
					"title": "GUARDS",
					"cards": [],
					"empty_text": "No jail guard-person contracts are resident yet.",
					"columns": 3
				}
			],
			"truth_state": "hot",
			"projection_complete": true,
			"authoritative_projection": true,
			"ui_is_renderer_only": true
		}
	}
	var relationships: Dictionary = (
		relationship_sections [
			"cellmate"
		].duplicate(false)
	)
	relationships ["section_contracts"] = relationship_sections
	relationships ["incarceration_mode"] = true
	relationships ["ordinary_relationship_graph_suppressed"] = true

	var school: Dictionary = {
		"success": true,
		"schema": "eralife.school_hub.contract",
		"version": 1,
		"actor_id": actor_id,
		"title": "PROGRAMS",
		"subtitle": str(
			booking.get(
				"facility_label",
				"Jail"
			)
		),
		"active_section_id": "overview",
		"tabs": [
			{
				"id": "overview",
				"label": "PROGRAMS"
			}
		],
		"section_rows": [
			{
				"row_kind": "information",
				"title": "DETENTION PROGRAMS",
				"subtitle": "Ordinary school access is suspended while detained.",
				"lines": [
					"Only facility-authorized programs can appear here."
				]
			}
		],
		"truth_state": "hot",
		"projection_complete": true,
		"authoritative_projection": true,
		"incarceration_mode": true,
		"ordinary_school_suppressed": true,
		"ui_is_renderer_only": true
	}

	var activities: Dictionary = {
		"success": true,
		"schema": "eralife.activities_hub_contract",
		"version": 1,
		"actor_id": actor_id,
		"title": "CELL BLOCK",
		"subtitle": str(
			booking.get(
				"facility_label",
				"Jail"
			)
		),
		"active_section": "all",
		"section_tabs": [
			{
				"id": "all",
				"label": "ALL"
			},
			{
				"id": "cell_block",
				"label": "CELL BLOCK"
			}
		],
		"category_rows": [
			{
				"id": "cell_block",
				"label": "CELL BLOCK",
				"description": "Only detention-resident activities are available.",
				"actions": []
			}
		],
		"truth_state": "hot",
		"projection_complete": true,
		"authoritative_projection": true,
		"incarceration_mode": true,
		"ui_is_renderer_only": true
	}

	var empty_career_catalog: Dictionary = {
		"schema": "eralife.career_catalog_contract",
		"version": 2,
		"actor_id": actor_id,
		"lane": "full_time",
		"career_rows": [],
		"status_text": "No jail work assignments are currently resident.",
		"ui_is_renderer_only": true
	}
	var career: Dictionary = {
		"success": true,
		"schema": "eralife.career_hub_contract",
		"version": 1,
		"actor_id": actor_id,
		"title": "JAIL WORK",
		"subtitle": str(
			booking.get(
				"facility_label",
				"Jail"
			)
		),
		"active_section": "overview",
		"career_lane": "full_time",
		"section_tabs": [
			{
				"id": "overview",
				"label": "CURRENT"
			},
			{
				"id": "opportunities",
				"label": "ASSIGNMENTS"
			}
		],
		"identity_overview": {
			"actor_id": actor_id,
			"role": "Detainee",
			"context": str(
				booking.get(
					"facility_label",
					"Jail"
				)
			)
		},
		"overview_cards": [
			{
				"title": "DETENTION",
				"description": "Outside employment is unavailable while detained."
			}
		],
		"workload_contract": {
			"employed": false
		},
		"primary_job_actions": [],
		"opportunity_contract": empty_career_catalog,
		"opportunity_contract_by_lane": {
			"full_time": empty_career_catalog,
			"part_time": {
				"schema": "eralife.career_catalog_contract",
				"version": 2,
				"actor_id": actor_id,
				"lane": "part_time",
				"career_rows": [],
				"status_text": "Outside part-time employment is unavailable.",
				"ui_is_renderer_only": true
			}
		},
		"incarceration_mode": true,
		"truth_state": "hot",
		"authoritative_projection": true,
		"ui_is_renderer_only": true
	}

	return {
		"relationships": relationships,
		"school": school,
		"activities": activities,
		"career": career
	}


func _compose_jail_reality_contract(
		actor_id: int,
		reason: String
) -> Dictionary:
	var booking: Dictionary = _safe_dictionary(
		holding_cells.get(
			str(
				actor_id
			),
			{}
		)
	)

	if booking.is_empty():
		return {}

	var actor = _actor_by_id(
		actor_id
	)
	var facility_id: String = str(
		booking.get(
			"facility_id",
			""
		)
	).strip_edges()
	var population_cards: Array = _jail_population_cards(
		actor_id,
		booking
	)
	var cellmate_id: int = int(
		jail_cellmate_by_actor.get(
			str(
				actor_id
			),
			-1
		)
	)
	var facility_surface: Dictionary = _jail_facility_surface_contract(
		actor_id,
		booking,
		population_cards
	)
	var sentence_surface: Dictionary = _jail_sentence_surface_contract(
		actor_id,
		booking
	)
	var surface_contracts: Dictionary = _jail_main_surface_contracts(
		actor_id,
		booking,
		population_cards
	)

	return {
		"schema": "eralife.jail_reality_contract",
		"version": 2,
		"actor_id": actor_id,
		"active": true,
		"incarceration_kind": "jail",
		"identity": {
			"name": (
				(
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
				if actor != null
				else "Person %d" % actor_id
			),
			"status": str(
				booking.get(
					"status",
					"booked"
				)
			)
		},
		"facility": {
			"facility_id": facility_id,
			"type": str(
				booking.get(
					"facility_type",
					"Jail"
				)
			),
			"label": str(
				booking.get(
					"facility_label",
					"Jail"
				)
			),
			"security_level": str(
				booking.get(
					"security_level",
					"Low"
				)
			),
			"era": str(
				_safe_dictionary(
					booking.get(
						"incarceration_context",
						{}
					)
				).get(
					"era",
					_current_era_name()
				)
			)
		},
		"incarceration_state": {
			"schema": "eralife.incarceration_state",
			"version": CONTRACT_VERSION,
			"active": true,
			"kind": "jail",
			"status": str(
				booking.get(
					"status",
					"booked"
				)
			),
			"facility_id": facility_id,
			"case_id": str(
				booking.get(
					"case_id",
					""
				)
			)
		},
		"incarceration_context": _safe_dictionary(
			booking.get(
				"incarceration_context",
				{}
			)
		),
		"navigation_labels": _jail_navigation_labels(
			_current_era_name()
		),
		"cellmate_id": cellmate_id,
		"cellmate_assignment_pending": cellmate_id <= 0,
		"population_cards": population_cards,
		"nearby_prisoner_cards": population_cards,
		"crime_target_cards": _jail_crime_target_cards(
			population_cards
		),
		"other_facility_cards": _other_jail_facility_cards(
			facility_id
		),
		"facility_surface_contract": facility_surface,
		"sentence_surface_contract": sentence_surface,
		"surface_contracts": surface_contracts,
		"tab_context_map": _incarceration_tab_context_map(
			"jail"
		),
		"truth_state": "hot",
		"projection_complete": true,
		"progressive_observability": true,
		"observation_required": false,
		"source": "jail_engine",
		"publication_reason": reason,
		"immutable": true,
		"ui_is_renderer_only": true,
		"published_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _build_jail_incarceration_context(case_data: Dictionary, verdict: Dictionary, facility_contract: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var sentence: Dictionary = _safe_dictionary(verdict.get("sentence", {}))
	var current_year: int = int(gs.year) if gs != null else 0
	var sentence_years: int = int(sentence.get("duration", 0))
	var sentence_months: int = max(0, sentence_years * 12)

	return {
		"schema": "eralife.incarceration_context",
		"version": CONTRACT_VERSION,
		"current_context": "incarcerated",
		"incarceration_kind": "jail",
		"facility_type": str(facility_contract.get("facility_type", "Country Jail")),
		"facility_label": str(facility_contract.get("facility_label", "Country Jail")),
		"era": str(facility_contract.get("era", "Modern Era")),
		"security_level": str(facility_contract.get("security_level", "Low")),
		"status": "booked",
		"case_id": str(case_data.get("case_id", "")),
		"sentence_type": str(sentence.get("type", "jail_holding")),
		"sentence_years": sentence_years,
		"sentence_months": sentence_months,
		"years_served": 0,
		"months_served": 0,
		"years_remaining": sentence_years,
		"started_year": current_year,
		"rules": _safe_array(facility_contract.get("rules", [])).duplicate(true),
		"restrictions": _safe_array(facility_contract.get("restrictions", [])).duplicate(true),
		"tab_context_map": _incarceration_tab_context_map("jail"),
		"facility_id": str(
			facility_contract.get(
				"facility_id",
				""
			)
		),
		"source": "jail_engine",
		"created_at_ms": int(Time.get_ticks_msec())
	}


func _apply_jail_context_to_actor(
		accused_id: int,
		booking: Dictionary
) -> void:
	var actor = _actor_by_id(
		accused_id
	)

	if actor == null:
		return

	var context: Dictionary = _safe_dictionary(
		booking.get(
			"incarceration_context",
			{}
		)
	)

	if context.is_empty():
		return

	actor.current_context = "incarcerated"
	actor.incarceration_state = {
		"schema": "eralife.incarceration_state",
		"version": CONTRACT_VERSION,
		"active": true,
		"status": "booked",
		"kind": "jail",
		"facility_id": str(
			booking.get(
				"facility_id",
				""
			)
		),
		"facility_type": str(
			booking.get(
				"facility_type",
				"Country Jail"
			)
		),
		"case_id": str(
			booking.get(
				"case_id",
				""
			)
		),
		"booking_id": str(
			booking.get(
				"booking_id",
				""
			)
		),
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}
	actor.incarceration_context = context.duplicate(true)
	actor.incarceration_stats = _default_jail_stats(
		context
	)

	if (
		typeof(actor.traits) == TYPE_ARRAY
		and not actor.traits.has(
			"InJail"
		)
	):
		actor.traits.append(
			"InJail"
		)


func _clear_jail_context_from_actor(
		accused_id: int,
		reason: String = "released"
) -> bool:
	var actor = _actor_by_id(
		accused_id
	)

	if actor == null:
		return false

	var next_traits: Array = []

	for raw_trait in actor.traits:
		var trait_text: String = str(
			raw_trait
		)

		if trait_text == "InJail":
			continue

		next_traits.append(
			trait_text
		)

	actor.traits = next_traits

	var active_state: Dictionary = _safe_dictionary(
		actor.incarceration_state
	)
	var active_owner_kind: String = str(
		active_state.get(
			"kind",
			""
		)
	).strip_edges().to_lower()



	if (
		active_owner_kind != ""
		and active_owner_kind != "jail"
	):
		return false

	if str(
		actor.current_context
	).strip_edges().to_lower() == "incarcerated":
		actor.current_context = "free"

	actor.incarceration_state = {
		"schema": "eralife.incarceration_state",
		"version": CONTRACT_VERSION,
		"status": str(
			reason
		),
		"kind": "jail",
		"released_at_ms": int(
			Time.get_ticks_msec()
		)
	}
	actor.incarceration_context = {}
	actor.incarceration_stats = {}

	return true
func _jail_facility_contract(
		case_data: Dictionary,
		verdict: Dictionary = {},
		context: Dictionary = {}
) -> Dictionary:
	var era_name: String = _current_era_name()
	var sentence: Dictionary = _safe_dictionary(
		verdict.get(
			"sentence",
			{}
		)
	)
	var crime: Dictionary = _safe_dictionary(
		case_data.get(
			"crime",
			{}
		)
	)
	var severity: float = clamp(
		float(
			crime.get(
				"severity",
				0.25
			)
		),
		0.0,
		1.0
	)
	var security_level: String = _security_level_from_severity(
		severity,
		int(
			sentence.get(
				"duration",
				0
			)
		)
	)

	var facility_type: String = "Country Jail"
	var rules: Array = [
		"Holding cell",
		"Restricted movement",
		"Guard supervision"
	]
	var restrictions: Array = [
		"no_work",
		"limited_family_contact",
		"no_travel"
	]

	match era_name:
		"Ancient Era":
			facility_type = "Dungeon"
			rules = [
				"Chains",
				"Public punishment risk",
				"Arbitrary release rules"
			]
			restrictions = [
				"no_travel",
				"guarded_cell",
				"public_shame"
			]

		"Medieval Era":
			facility_type = "Castle Dungeon"
			rules = [
				"Dungeon holding",
				"Nobility privilege checks",
				"Torture risk"
			]
			restrictions = [
				"no_travel",
				"guarded_cell",
				"limited_family_contact"
			]

		"Industrial Era":
			facility_type = "County Jail"
			rules = [
				"Early formal booking",
				"Hard holding conditions",
				"Labor pressure"
			]
			restrictions = [
				"no_travel",
				"limited_family_contact",
				"guarded_cell"
			]

		"Future Era":
			facility_type = "AI Detention Block"
			rules = [
				"Behavior tracking",
				"AI guard observation",
				"Predictive risk scoring"
			]
			restrictions = [
				"no_travel",
				"surveillance",
				"limited_family_contact"
			]

		_:
			facility_type = "Country Jail"
			rules = [
				"Booking",
				"Holding cell",
				"Guard supervision"
			]
			restrictions = [
				"no_travel",
				"limited_family_contact"
			]

	var resolved_facility_type: String = str(
		context.get(
			"facility_type",
			facility_type
		)
	).strip_edges()

	if resolved_facility_type == "":
		resolved_facility_type = facility_type

	var resolved_facility_label: String = str(
		context.get(
			"facility_label",
			resolved_facility_type
		)
	).strip_edges()

	if resolved_facility_label == "":
		resolved_facility_label = resolved_facility_type

	var world_id: String = str(
		context.get(
			"world_id",
			case_data.get(
				"world_id",
				"world"
			)
		)
	).strip_edges()

	if world_id == "":
		world_id = "world"

	var facility_id: String = str(
		context.get(
			"facility_id",
			""
		)
	).strip_edges()

	if facility_id == "":
		facility_id = (
			"jail:%s:%s:%s"
			% [
				world_id.to_lower().replace(
					" ",
					"_"
				),
				era_name.to_lower().replace(
					" ",
					"_"
				),
				resolved_facility_type.to_lower().replace(
					" ",
					"_"
				)
			]
		)

	return {
		"schema": "eralife.incarceration_facility_contract",
		"version": CONTRACT_VERSION,
		"facility_id": facility_id,
		"facility_type": resolved_facility_type,
		"facility_label": resolved_facility_label,
		"incarceration_kind": "jail",
		"era": era_name,
		"security_level": security_level,
		"rules": rules.duplicate(true),
		"restrictions": restrictions.duplicate(true),
		"immutable": true
	}


func _default_jail_stats(context: Dictionary) -> Dictionary:
	var security_level: String = str(context.get("security_level", "Low"))
	var heat: int = 15
	var safety: int = 72

	match security_level:
		"Medium":
			heat = 28
			safety = 62
		"High":
			heat = 44
			safety = 48
		"Maximum":
			heat = 62
			safety = 34

	return {
		"safety": safety,
		"respect": 30,
		"mental_stability": 58,
		"guard_heat": heat,
		"contraband_risk": 10
	}


func _jail_world_snapshot(facility_contract: Dictionary) -> Dictionary:
	return {
		"population_label": str(facility_contract.get("facility_type", "Jail")),
		"total_inmates": 12,
		"factions": ["Loners", "Cell Block Regulars"],
		"recent_events": ["A guard changed shifts.", "Someone shouted from another cell."],
		"live_counter": true
	}


func _incarceration_tab_context_map(kind: String) -> Dictionary:
	return {
		"world": "%s_population" % kind,
		"life": "%s_daily_routine" % kind,
		"school": "%s_rehab_classes" % kind,
		"activities": "%s_yard_gym_contraband" % kind,
		"relationships": "%s_inmates_guards_household" % kind,
		"career": "%s_jobs" % kind
	}


func _security_level_from_severity(severity: float, years: int = 0) -> String:
	if severity >= 0.82 or years >= 25:
		return "Maximum"
	if severity >= 0.58 or years >= 10:
		return "High"
	if severity >= 0.32 or years >= 3:
		return "Medium"
	return "Low"


func _actor_by_id(actor_id: int):
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


func _current_era_name() -> String:
	if gs != null and gs.era != null:
		if typeof(gs.era) == TYPE_DICTIONARY:
			return str(gs.era.get("name", gs.era.get("id", "Modern Era")))
		return str(gs.era.name)
	return "Modern Era"


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)
func _record(event_name: String, payload: Dictionary = {}) -> Dictionary:
	var entry:= {
		"event_name": event_name,
		"payload": payload.duplicate(true),
		"year": int(gs.year) if gs != null and gs.get("year") != null else 0,
		"at_ms": int(Time.get_ticks_msec())
	}
	ledger.append(entry)

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(event_name, {
			"source": "jail_engine",
			"case_id": str(payload.get("case_id", "")),
			"accused_id": int(payload.get("accused_id", -1)),
			"text": "A jail booking was processed."
		})

	return {
		"success": true,
		"event_name": event_name,
		"entry": entry.duplicate(true)
	}