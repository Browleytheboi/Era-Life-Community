

extends Resource
class_name RoyaltyRuntimeEngine

const ENGINE_SCHEMA:= "eralife.royalty_runtime_engine"
const ENGINE_VERSION:= 1
const STATE_SCHEMA:= "eralife.royalty_institution_state"
const STATE_VERSION:= 1
const STATE_KEY:= "royalty_institution_state"

const MAX_EVENT_HISTORY:= 240
const MAX_DECREE_HISTORY:= 160
const MAX_CEREMONY_HISTORY:= 160

var gs
var last_report: Dictionary = {}


func _init(
	_gs = null
) -> void:
	gs = _gs
	_ensure_state_shape()


func bootstrap_default_contracts() -> Dictionary:
	var state: Dictionary = _royalty_state_view_read_only()

	var institutions_raw: Variant = state.get(
		"institutions",
		{}
	)
	var houses_raw: Variant = state.get(
		"houses",
		{}
	)
	var person_index_raw: Variant = state.get(
		"person_index",
		{}
	)

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"bootstrap_mode": "constant_time_contract_only",
		"institution_count": (
			(institutions_raw as Dictionary).size()
			if typeof(institutions_raw) == TYPE_DICTIONARY
			else 0
		),
		"house_count": (
			(houses_raw as Dictionary).size()
			if typeof(houses_raw) == TYPE_DICTIONARY
			else 0
		),
		"indexed_actor_count": (
			(person_index_raw as Dictionary).size()
			if typeof(person_index_raw) == TYPE_DICTIONARY
			else 0
		),
		"continuous_ingress_authority": "ingest_actor",
		"legacy_reconstruction_authority": (
			"repair_from_legacy_state"
		),
		"ready_gate_member": false,
		"blocks_ui": false,
		"ui_is_renderer_only": true
	}

	return last_report.duplicate(true)


func ensure_world_institutions(
	context: Dictionary = {}
) -> Dictionary:
	var read_only_projection_requested: bool = (
		bool(
			context.get(
				"read_only_projection_requested",
				false
			)
		)
		or bool(
			context.get(
				"projection_read_only",
				false
			)
		)
		or bool(
			context.get(
				"read_only",
				false
			)
		)
	)

	if read_only_projection_requested:
		return _fail(
			"world_institution_reconstruction_forbidden_during_projection",
			(
				"Royalty world reconstruction is an authority mutation "
				+ "and may never execute from a read-only projection."
			)
		)

	var reconstruction_authorized: bool = (
		bool(
			context.get(
				"legacy_reconstruction",
				false
			)
		)
		or bool(
			context.get(
				"authority_reconstruction",
				false
			)
		)
	)

	if not reconstruction_authorized:
		return _fail(
			"world_institution_reconstruction_requires_authority",
			(
				"Whole-world royalty reconstruction requires an explicit "
				+ "migration or authority-reconstruction contract."
			)
		)

	var state: Dictionary = _ensure_state_shape()
	var ingested_count: int = 0

	for actor in _all_people():
		if not _person_has_royal_truth(actor):
			continue

		var ingest_report: Dictionary = ingest_actor(
			actor,
			{
				"source": str(
					context.get(
						"source",
						"ensure_world_institutions"
					)
				),
				"silent": true
			}
		)

		if bool(
			ingest_report.get(
				"success",
				false
			)
		):
			ingested_count += 1

	_ensure_realm_institutions(state)

	var repair_report: Dictionary = repair_state({
		"source": str(
			context.get(
				"source",
				"ensure_world_institutions"
			)
		),
		"allow_legacy_mirror_repair": true
	})

	state = _ensure_state_shape()
	state ["last_boot_year"] = _current_year()
	state ["last_boot_era"] = _current_era_name()
	state ["last_boot_at_ms"] = int(
		Time.get_ticks_msec()
	)
	state ["runtime_revision"] = int(
		state.get(
			"runtime_revision",
			0
		)
	) + 1

	_sync_state_back(state)

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"ingested_actor_count": ingested_count,
		"institution_count": _dict(
			state.get(
				"institutions",
				{}
			)
		).size(),
		"house_count": _dict(
			state.get(
				"houses",
				{}
			)
		).size(),
		"repair_report": repair_report,
		"ui_is_renderer_only": true
	}

	return last_report.duplicate(true)

func _finalize_ingested_institution_truth(
	institution: Dictionary
) -> Dictionary:
	if institution.is_empty():
		return {}

	var out: Dictionary = institution.duplicate(true)
	var member_ids: Array = _integer_array(
		out.get(
			"member_ids",
			[]
		)
	)
	var candidate_ids: Array = []

	for raw_member_id in member_ids:
		var member: Person = _person_by_id(
			int(raw_member_id)
		)

		if (
			member == null
			or not member.alive
			or member.exiled
			or not _person_has_royal_truth(
				member
			)
		):
			continue

		_append_unique_int(
			candidate_ids,
			int(member.id)
		)

	var monarch_id: int = _canonical_monarch_id(
		out,
		candidate_ids
	)

	out [
		"monarch_id"
	] = monarch_id
	out [
		"line_of_succession"
	] = _ordered_candidate_ids(
		candidate_ids,
		monarch_id
	)
	out [
		"claimant_ids"
	] = _claimant_ids_from_candidates(
		candidate_ids
	)
	out [
		"court_member_ids"
	] = member_ids.duplicate()
	out [
		"legitimacy"
	] = _institution_legitimacy(
		out
	)
	out [
		"stability"
	] = _institution_stability(
		out
	)
	out [
		"integrity_state"
	] = (
		"healthy"
		if monarch_id > 0
		else "vacant_throne"
	)

	var realm_id: int = int(
		out.get(
			"realm_id",
			-1
		)
	)
	var realm: Dictionary = {}

	if (
		realm_id > 0
		and gs != null
		and gs.realm_engine != null
		and typeof(
			gs.realm_engine.realms
		) == TYPE_DICTIONARY
	):
		var realm_raw: Variant = (
			gs.realm_engine.realms.get(
				realm_id,
				gs.realm_engine.realms.get(
					str(realm_id),
					{}
				)
			)
		)

		if typeof(realm_raw) == TYPE_DICTIONARY:
			realm = (
				realm_raw as Dictionary
			)

	if not realm.is_empty():
		out [
			"realm_name"
		] = str(
			realm.get(
				"name",
				out.get(
					"realm_name",
					"Unbound Realm"
				)
			)
		)
		out [
			"government_style"
		] = str(
			realm.get(
				"government_style",
				out.get(
					"government_style",
					"Monarchy"
				)
			)
		)
		out [
			"population"
		] = int(
			realm.get(
				"population",
				out.get(
					"population",
					0
				)
			)
		)
		out [
			"treasury"
		] = int(
			realm.get(
				"treasury",
				out.get(
					"treasury",
					0
				)
			)
		)
		out [
			"land"
		] = int(
			realm.get(
				"land",
				realm.get(
					"land_size",
					out.get(
						"land",
						0
					)
				)
			)
		)
		out [
			"military_stockpile"
		] = int(
			realm.get(
				"military_stockpile",
				out.get(
					"military_stockpile",
					0
				)
			)
		)
		out [
			"goods_stockpile"
		] = int(
			realm.get(
				"goods_stockpile",
				out.get(
					"goods_stockpile",
					0
				)
			)
		)
		out [
			"happiness"
		] = int(
			realm.get(
				"happiness",
				out.get(
					"happiness",
					50
				)
			)
		)
		out [
			"tax_rate"
		] = float(
			realm.get(
				"tax_rate",
				out.get(
					"tax_rate",
					10.0
				)
			)
		)
		out [
			"currency_name"
		] = str(
			realm.get(
				"currency_name",
				out.get(
					"currency_name",
					""
				)
			)
		)
		out [
			"allocation_reserve"
		] = int(
			realm.get(
				"allocation_reserve",
				out.get(
					"allocation_reserve",
					0
				)
			)
		)

	out [
		"updated_at_ms"
	] = int(
		Time.get_ticks_msec()
	)
	out [
		"ingest_finalized"
	] = true
	out [
		"ingest_finalization_is_actor_scoped"
	] = true

	return out
func ingest_actor(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"Royalty runtime could not ingest a missing actor."
		)




	if not _person_has_royal_truth(
		actor
	):
		return _fail(
			"actor_has_no_royal_truth",
			(
				"Royalty runtime rejected an actor whose immutable "
				+ "contracts do not contain royal truth."
			)
		)

	var state: Dictionary = _ensure_state_shape()
	var institutions: Dictionary = _dict(
		state.get(
			"institutions",
			{}
		)
	)
	var houses: Dictionary = _dict(
		state.get(
			"houses",
			{}
		)
	)
	var person_index: Dictionary = _dict(
		state.get(
			"person_index",
			{}
		)
	)

	var realm_id: int = _realm_id_for_actor(
		actor
	)
	var realm_name: String = _realm_name_for_actor(
		actor,
		realm_id
	)
	var house_id: String = _house_id_for_actor(
		actor
	)
	var institution_id: String = _institution_id(
		realm_id,
		realm_name,
		house_id
	)

	var institution: Dictionary = _dict(
		institutions.get(
			institution_id,
			{}
		)
	)

	if institution.is_empty():
		institution = _default_institution(
			institution_id,
			realm_id,
			realm_name
		)

	var member_ids: Array = _integer_array(
		institution.get(
			"member_ids",
			[]
		)
	)
	_append_unique_int(
		member_ids,
		int(actor.id)
	)
	institution ["member_ids"] = member_ids

	var court_member_ids: Array = _integer_array(
		institution.get(
			"court_member_ids",
			[]
		)
	)
	_append_unique_int(
		court_member_ids,
		int(actor.id)
	)
	institution ["court_member_ids"] = court_member_ids

	var claimant_ids: Array = _integer_array(
		institution.get(
			"claimant_ids",
			[]
		)
	)
	var is_claimant: bool = (
		bool(actor.deposed)
		or bool(actor.exiled)
		or (
			int(actor.succession_rank) > 0
			and int(actor.succession_rank) <= 12
		)
	)

	if is_claimant:
		_append_unique_int(
			claimant_ids,
			int(actor.id)
		)
	else:
		claimant_ids.erase(
			int(actor.id)
		)

	institution ["claimant_ids"] = claimant_ids

	if bool(actor.is_ruler):
		institution ["monarch_id"] = int(
			actor.id
		)

	if (
		actor.partner != null
		and bool(
			actor.partner.is_ruler
		)
	):
		institution ["consort_id"] = int(
			actor.id
		)

	institution ["house_id"] = (
		house_id
		if house_id != ""
		else str(
			institution.get(
				"house_id",
				""
			)
		)
	)
	institution ["realm_id"] = realm_id
	institution ["realm_name"] = realm_name
	institution ["active"] = true




	institution = _finalize_ingested_institution_truth(
		institution
	)
	institutions [
		institution_id
	] = institution

	var realm_institution_index: Dictionary = _dict(
		state.get(
			"realm_institution_index",
			{}
		)
	)

	if realm_id > 0:
		realm_institution_index [
			str(realm_id)
		] = institution_id

	state [
		"realm_institution_index"
	] = realm_institution_index

	var house: Dictionary = _dict(
		houses.get(
			house_id,
			{}
		)
	)

	if house.is_empty():
		house = {
			"schema": (
				"eralife.royal_house_contract"
			),
			"version": 1,
			"house_id": house_id,
			"display_name": _house_display_name(
				actor,
				house_id
			),
			"founder_id": int(actor.id),
			"member_ids": [],
			"realm_ids": [],
			"prestige": 50,
			"active": true,
			"created_at_ms": int(
				Time.get_ticks_msec()
			)
		}




	house [
		"display_name"
	] = _house_display_name(
		actor,
		house_id
	)
	house [
		"display_label"
	] = str(
		house.get(
			"display_name",
			"Royal House"
		)
	)

	var house_member_ids: Array = _integer_array(
		house.get(
			"member_ids",
			[]
		)
	)
	_append_unique_int(
		house_member_ids,
		int(actor.id)
	)
	house ["member_ids"] = house_member_ids

	var realm_ids: Array = _integer_array(
		house.get(
			"realm_ids",
			[]
		)
	)
	if realm_id > 0:
		_append_unique_int(
			realm_ids,
			realm_id
		)
	house ["realm_ids"] = realm_ids
	house ["active"] = true
	house ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	houses [house_id] = house

	person_index [str(int(actor.id))] = {
		"schema": (
			"eralife.royalty_person_runtime_index"
		),
		"version": 1,
		"actor_id": int(actor.id),
		"institution_id": institution_id,
		"house_id": house_id,
		"realm_id": realm_id,
		"role": _role_for_actor(actor),
		"title": str(actor.royal_title),
		"succession_rank": int(
			actor.succession_rank
		),
		"is_ruler": bool(actor.is_ruler),
		"is_royal": bool(actor.is_royal),
		"is_claimant": is_claimant,
		"deposed": bool(actor.deposed),
		"exiled": bool(actor.exiled),
		"alive": bool(actor.alive),
		"legitimacy": _legitimacy_for_actor(actor),
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	state ["institutions"] = institutions
	state ["houses"] = houses
	state ["person_index"] = person_index
	state ["runtime_revision"] = int(
		state.get(
			"runtime_revision",
			0
		)
	) + 1

	_sync_state_back(
		state
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"actor_id": int(actor.id),
		"institution_id": institution_id,
		"house_id": house_id,
		"realm_id": realm_id,
		"source": str(
			context.get(
				"source",
				"ingest_actor"
			)
		)
	}
func institution_for_actor(
	actor: Person
) -> Dictionary:
	if (
		actor == null
		or not _person_has_royal_truth(
			actor
		)
	):
		return {}

	var state: Dictionary = _royalty_state_view_read_only()

	if state.is_empty():
		return {}

	var person_index_raw: Variant = state.get(
		"person_index",
		{}
	)

	if typeof(person_index_raw) != TYPE_DICTIONARY:
		return {}

	var person_index: Dictionary = (
		person_index_raw as Dictionary
	)
	var row_raw: Variant = person_index.get(
		str(int(actor.id)),
		{}
	)

	if typeof(row_raw) != TYPE_DICTIONARY:
		return {}

	var row: Dictionary = row_raw as Dictionary
	var institution_id: String = str(
		row.get(
			"institution_id",
			""
		)
	).strip_edges()

	if institution_id == "":
		return {}

	var institutions_raw: Variant = state.get(
		"institutions",
		{}
	)

	if typeof(institutions_raw) != TYPE_DICTIONARY:
		return {}

	var institution_raw: Variant = (
		(institutions_raw as Dictionary).get(
			institution_id,
			{}
		)
	)

	if typeof(institution_raw) != TYPE_DICTIONARY:
		return {}

	return (
		institution_raw as Dictionary
	).duplicate(true)
func institution_for_realm(
	realm_id: int
) -> Dictionary:
	if realm_id <= 0:
		return {}

	var state: Dictionary = _royalty_state_view_read_only()

	if state.is_empty():
		return {}

	var realm_index_raw: Variant = state.get(
		"realm_institution_index",
		{}
	)

	if typeof(realm_index_raw) != TYPE_DICTIONARY:
		return {}

	var institution_id: String = str(
		(realm_index_raw as Dictionary).get(
			str(realm_id),
			""
		)
	).strip_edges()

	if institution_id == "":
		return {}

	var institutions_raw: Variant = state.get(
		"institutions",
		{}
	)

	if typeof(institutions_raw) != TYPE_DICTIONARY:
		return {}

	var institution_raw: Variant = (
		(institutions_raw as Dictionary).get(
			institution_id,
			{}
		)
	)

	if typeof(institution_raw) != TYPE_DICTIONARY:
		return {}

	return (
		institution_raw as Dictionary
	).duplicate(true)

func house_for_actor(
	actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	var institution: Dictionary = institution_for_actor(
		actor
	)
	var house_id: String = str(
		institution.get(
			"house_id",
			_house_id_for_actor(actor)
		)
	).strip_edges()

	if house_id == "":
		return {}

	var state: Dictionary = _royalty_state_view_read_only()

	if state.is_empty():
		return {}

	var houses_raw: Variant = state.get(
		"houses",
		{}
	)

	if typeof(houses_raw) != TYPE_DICTIONARY:
		return {}

	var house_raw: Variant = (
		(houses_raw as Dictionary).get(
			house_id,
			{}
		)
	)

	if typeof(house_raw) != TYPE_DICTIONARY:
		return {}

	return (
		house_raw as Dictionary
	).duplicate(true)

func line_of_succession_for_actor(
	actor: Person
) -> Array:
	return _integer_array(
		institution_for_actor(actor).get(
			"line_of_succession",
			[]
		)
	)


func court_for_actor(
	actor: Person
) -> Array:
	return _integer_array(
		institution_for_actor(actor).get(
			"court_member_ids",
			[]
		)
	)


func claimants_for_actor(
	actor: Person
) -> Array:
	return _integer_array(
		institution_for_actor(actor).get(
			"claimant_ids",
			[]
		)
	)


func current_monarch_for_actor(
	actor: Person
) -> Person:
	var institution: Dictionary = institution_for_actor(
		actor
	)

	return _person_by_id(
		int(
			institution.get(
				"monarch_id",
				-1
			)
		)
	)


func commit_abdication(
	actor: Person,
	heir_id: int = -1,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No monarch was supplied for abdication."
		)

	var institution: Dictionary = institution_for_actor(
		actor
	)

	if institution.is_empty():
		return _fail(
			"missing_institution",
			"That monarch has no observable royalty institution."
		)

	if int(
		institution.get(
			"monarch_id",
			-1
		)
	) != int(actor.id):
		return _fail(
			"actor_not_monarch",
			"Only the active monarch may abdicate."
		)

	var successor: Person = _person_by_id(heir_id)

	if successor == null:
		for raw_candidate_id in _integer_array(
			institution.get(
				"line_of_succession",
				[]
			)
		):
			var candidate: Person = _person_by_id(
				int(raw_candidate_id)
			)

			if (
				candidate != null
				and candidate.alive
				and not candidate.exiled
				and int(candidate.id) != int(actor.id)
			):
				successor = candidate
				break

	if successor == null:
		return _fail(
			"missing_successor",
			"No eligible successor is available."
		)

	actor.is_ruler = false
	actor.deposed = false
	actor.palace_owned = false
	actor.royal_title = "Former %s" % _ruler_title_for(
		actor
	)

	_commit_ruler_transition(
		successor,
		actor,
		{
			"source": str(
				context.get(
					"source",
					"royalty_runtime_abdication"
				)
			),
			"transition_type": "abdication"
		}
	)

	_record_event({
		"type": "royal_abdication",
		"former_monarch_id": int(actor.id),
		"new_monarch_id": int(successor.id),
		"realm_id": int(
			institution.get(
				"realm_id",
				-1
			)
		),
		"year": _current_year()
	})

	repair_state({
		"source": "commit_abdication"
	})

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "royal_abdication_committed",
		"former_monarch_id": int(actor.id),
		"new_monarch_id": int(successor.id),
		"text": "%s abdicated in favor of %s." % [
			_person_name(actor),
			_person_name(successor)
		]
	}


func appoint_heir(
	actor: Person,
	heir_id: int,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No monarch was supplied."
		)

	var institution: Dictionary = institution_for_actor(
		actor
	)

	if int(
		institution.get(
			"monarch_id",
			-1
		)
	) != int(actor.id):
		return _fail(
			"actor_not_monarch",
			"Only the active monarch may appoint an heir."
		)

	var heir: Person = _person_by_id(heir_id)

	if (
		heir == null
		or not heir.alive
		or heir.exiled
	):
		return _fail(
			"invalid_heir",
			"The selected heir is not eligible."
		)

	if gs.royalty_engine != null:
		if gs.royalty_engine.has_method(
			"set_designated_heir"
		):
			gs.royalty_engine.set_designated_heir(
				actor,
				heir
			)

	ingest_actor(
		heir,
		{
			"source": "appoint_heir"
		}
	)
	repair_state({
		"source": "appoint_heir"
	})

	_record_event({
		"type": "royal_heir_appointed",
		"monarch_id": int(actor.id),
		"heir_id": int(heir.id),
		"year": _current_year(),
		"context": context.duplicate(true)
	})

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "royal_heir_appointed",
		"monarch_id": int(actor.id),
		"heir_id": int(heir.id),
		"text": "%s was appointed heir." % _person_name(
			heir
		)
	}


func commit_coronation(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No coronation candidate was supplied."
		)

	var institution: Dictionary = institution_for_actor(
		actor
	)
	var previous_monarch: Person = _person_by_id(
		int(
			institution.get(
				"monarch_id",
				-1
			)
		)
	)

	if (
		previous_monarch != null
		and previous_monarch.alive
		and int(previous_monarch.id) != int(actor.id)
		and not bool(
			context.get(
				"force_transition",
				false
			)
		)
	):
		return _fail(
			"living_monarch_exists",
			"A living monarch still holds the institution."
		)

	_commit_ruler_transition(
		actor,
		previous_monarch,
		{
			"source": str(
				context.get(
					"source",
					"commit_coronation"
				)
			),
			"transition_type": "coronation"
		}
	)

	_record_event({
		"type": "royal_coronation",
		"monarch_id": int(actor.id),
		"previous_monarch_id": (
			int(previous_monarch.id)
			if previous_monarch != null
			else -1
		),
		"year": _current_year()
	})

	repair_state({
		"source": "commit_coronation"
	})

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "royal_coronation_committed",
		"monarch_id": int(actor.id),
		"text": "%s was crowned." % _person_name(actor)
	}


func establish_regency(
	monarch: Person,
	regent_id: int,
	context: Dictionary = {}
) -> Dictionary:
	if monarch == null:
		return _fail(
			"missing_monarch",
			"No monarch was supplied for the regency."
		)

	var institution: Dictionary = institution_for_actor(
		monarch
	)
	var regent: Person = _person_by_id(regent_id)

	if regent == null or not regent.alive:
		return _fail(
			"invalid_regent",
			"The selected regent is unavailable."
		)

	institution ["regent_id"] = int(regent.id)
	institution ["regency_active"] = true
	institution ["regency_reason"] = str(
		context.get(
			"reason",
			"constitutional_regency"
		)
	)
	institution ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	_store_institution(institution)

	_record_event({
		"type": "royal_regency_established",
		"monarch_id": int(monarch.id),
		"regent_id": int(regent.id),
		"year": _current_year()
	})

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "royal_regency_established",
		"monarch_id": int(monarch.id),
		"regent_id": int(regent.id),
		"text": "%s became regent." % _person_name(regent)
	}


func end_regency(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No royal actor was supplied."
		)

	var institution: Dictionary = institution_for_actor(
		actor
	)

	if institution.is_empty():
		return _fail(
			"missing_institution",
			"No royalty institution could be resolved."
		)

	institution ["regent_id"] = -1
	institution ["regency_active"] = false
	institution ["regency_reason"] = ""
	institution ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	_store_institution(institution)

	_record_event({
		"type": "royal_regency_ended",
		"actor_id": int(actor.id),
		"year": _current_year(),
		"context": context.duplicate(true)
	})

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "royal_regency_ended",
		"text": "The regency ended."
	}


func repair_state(
	context: Dictionary = {}
) -> Dictionary:
	var state: Dictionary = _ensure_state_shape()
	var institutions: Dictionary = _dict(
		state.get(
			"institutions",
			{}
		)
	)
	var person_index: Dictionary = _dict(
		state.get(
			"person_index",
			{}
		)
	)
	var repair_rows: Array = []

	for raw_institution_id in institutions.keys():
		var institution_id: String = str(
			raw_institution_id
		)

		var institution: Dictionary = _dict(
			institutions.get(
				institution_id,
				{}
			)
		)

		var valid_member_ids: Array = []
		var candidate_ids: Array = []

		for raw_member_id in _integer_array(
			institution.get(
				"member_ids",
				[]
			)
		):
			var member_id: int = int(
				raw_member_id
			)
			var member: Person = _person_by_id(
				member_id
			)

			if member == null:
				person_index.erase(
					str(member_id)
				)
				continue




			if not _person_has_royal_truth(
				member
			):
				person_index.erase(
					str(member.id)
				)
				continue

			_append_unique_int(
				valid_member_ids,
				int(member.id)
			)

			if (
				member.alive
				and not member.exiled
			):
				candidate_ids.append(
					int(member.id)
				)

			person_index [str(int(member.id))] = {
				"schema": (
					"eralife.royalty_person_runtime_index"
				),
				"version": 1,
				"actor_id": int(member.id),
				"institution_id": institution_id,
				"house_id": _house_id_for_actor(member),
				"realm_id": _realm_id_for_actor(member),
				"role": _role_for_actor(member),
				"title": str(member.royal_title),
				"succession_rank": int(
					member.succession_rank
				),
				"is_ruler": bool(member.is_ruler),
				"is_royal": bool(member.is_royal),
				"is_claimant": (
					bool(member.deposed)
					or bool(member.exiled)
					or (
						int(member.succession_rank) > 0
						and int(member.succession_rank) <= 12
					)
				),
				"deposed": bool(member.deposed),
				"exiled": bool(member.exiled),
				"alive": bool(member.alive),
				"legitimacy": _legitimacy_for_actor(member),
				"updated_at_ms": int(
					Time.get_ticks_msec()
				)
			}

		institution ["member_ids"] = valid_member_ids

		var monarch_id: int = _canonical_monarch_id(
			institution,
			candidate_ids
		)
		var previous_monarch_id: int = int(
			institution.get(
				"monarch_id",
				-1
			)
		)

		institution ["monarch_id"] = monarch_id
		institution ["line_of_succession"] = (
			_ordered_candidate_ids(
				candidate_ids,
				monarch_id
			)
		)
		institution ["claimant_ids"] = (
			_claimant_ids_from_candidates(
				candidate_ids
			)
		)
		institution ["court_member_ids"] = (
			valid_member_ids.duplicate()
		)
		institution ["legitimacy"] = (
			_institution_legitimacy(
				institution
			)
		)
		institution ["stability"] = (
			_institution_stability(
				institution
			)
		)
		institution ["integrity_state"] = (
			"healthy"
			if monarch_id > 0
			else "vacant_throne"
		)
		institution ["last_repaired_at_ms"] = int(
			Time.get_ticks_msec()
		)

		if (
			monarch_id > 0
			and monarch_id != previous_monarch_id
			and bool(
				context.get(
					"allow_legacy_mirror_repair",
					true
				)
			)
		):
			var monarch: Person = _person_by_id(
				monarch_id
			)
			var previous_monarch: Person = _person_by_id(
				previous_monarch_id
			)

			if monarch != null:
				_commit_ruler_transition(
					monarch,
					previous_monarch,
					{
						"source": "royalty_runtime_self_heal",
						"transition_type": (
							"integrity_repair"
						)
					}
				)

		institutions [institution_id] = institution
		repair_rows.append({
			"institution_id": institution_id,
			"monarch_id": monarch_id,
			"previous_monarch_id": previous_monarch_id,
			"member_count": valid_member_ids.size(),
			"integrity_state": str(
				institution.get(
					"integrity_state",
					"unknown"
				)
			)
		})

	state ["institutions"] = institutions
	state ["person_index"] = person_index
	state ["last_repair_report"] = {
		"source": str(
			context.get(
				"source",
				"repair_state"
			)
		),
		"rows": repair_rows.duplicate(true),
		"repaired_at_ms": int(
			Time.get_ticks_msec()
		)
	}
	state ["runtime_revision"] = int(
		state.get(
			"runtime_revision",
			0
		)
	) + 1

	_sync_state_back(
		state
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"repair_rows": repair_rows,
		"institution_count": institutions.size(),
	}


func self_heal(
	context: Dictionary = {}
) -> Dictionary:
	return repair_state(context)


func repair_from_legacy_state(
	context: Dictionary = {}
) -> Dictionary:
	return ensure_world_institutions({
		"source": str(
			context.get(
				"source",
				"repair_from_legacy_state"
			)
		),
		"legacy_reconstruction": true
	})


func yearly_tick(
	payload: Dictionary = {}
) -> Dictionary:
	if (
		gs != null
		and gs.royalty_engine != null
		and gs.royalty_engine.has_method(
			"run_legacy_yearly_tick"
		)
	):
		gs.royalty_engine.run_legacy_yearly_tick(
			payload
		)

	var report: Dictionary = repair_state({
		"source": "royalty_runtime_yearly_tick",
		"allow_legacy_mirror_repair": true
	})

	_record_event({
		"type": "royalty_yearly_tick",
		"year": _current_year(),
		"repair_count": _array(
			report.get(
				"repair_rows",
				[]
			)
		).size()
	})

	return report


func on_npc_died(
	payload = {}
) -> void:
	var actor: Person = _person_from_payload(payload)

	if actor != null:
		ingest_actor(
			actor,
			{
				"source": "royalty_runtime_npc_died",
				"silent": true
			}
		)

	repair_state({
		"source": "royalty_runtime_npc_died",
		"allow_legacy_mirror_repair": true
	})


func on_npc_married(
	payload = {}
) -> void:
	for actor in _people_from_payload(payload):
		if _person_has_royal_truth(actor):
			ingest_actor(
				actor,
				{
					"source": (
						"royalty_runtime_npc_married"
					),
					"silent": true
				}
			)

	repair_state({
		"source": "royalty_runtime_npc_married"
	})


func on_era_shift(
	_payload = {}
) -> void:
	repair_state({
		"source": "royalty_runtime_era_shift",
		"allow_legacy_mirror_repair": true
	})


func export_state() -> Dictionary:
	return {
		"schema": (
			"eralife.royalty_runtime_engine_state"
		),
		"version": ENGINE_VERSION,
		"state": _ensure_state_shape().duplicate(true),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	var imported_state: Dictionary = _dict(
		data.get(
			"state",
			data
		)
	)

	if imported_state.is_empty():
		imported_state = _default_state()

	if gs != null:
		gs.royalty_institution_state = (
			imported_state.duplicate(true)
		)

		if typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY:
			gs.scenario_state = {}

		gs.scenario_state [STATE_KEY] = (
			imported_state.duplicate(true)
		)

	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)

	_ensure_state_shape()

	var repair_report: Dictionary = repair_state({
		"source": "royalty_runtime_import",
		"allow_legacy_mirror_repair": true
	})

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"repair_report": repair_report
	}


func _ensure_realm_institutions(
	state: Dictionary
) -> void:
	if (
		gs == null
		or gs.realm_engine == null
		or typeof(
			gs.realm_engine.realms
		) != TYPE_DICTIONARY
	):
		return

	var institutions: Dictionary = _dict(
		state.get(
			"institutions",
			{}
		)
	)
	var realm_index: Dictionary = _dict(
		state.get(
			"realm_institution_index",
			{}
		)
	)

	for raw_realm_id in gs.realm_engine.realms.keys():
		var realm_id: int = int(
			raw_realm_id
		)
		var realm: Dictionary = _dict(
			gs.realm_engine.realms.get(
				raw_realm_id,
				{}
			)
		)
		var ruler_id: int = int(
			realm.get(
				"ruler_id",
				-1
			)
		)

		if ruler_id <= 0:
			continue

		var ruler: Person = _person_by_id(
			ruler_id
		)





		if (
			ruler == null
			or not _person_has_royal_truth(
				ruler
			)
		):
			realm_index.erase(
				str(realm_id)
			)
			continue

		var realm_name: String = str(
			realm.get(
				"name",
				"Realm %d" % realm_id
			)
		)
		var institution_id: String = _institution_id(
			realm_id,
			realm_name,
			""
		)
		var institution: Dictionary = _dict(
			institutions.get(
				institution_id,
				{}
			)
		)

		if institution.is_empty():
			institution = _default_institution(
				institution_id,
				realm_id,
				realm_name
			)

		institution ["monarch_id"] = ruler_id
		institution ["realm_id"] = realm_id
		institution ["realm_name"] = realm_name
		institution ["government_style"] = str(
			realm.get(
				"government_style",
				"Monarchy"
			)
		)
		institution ["treasury"] = int(
			realm.get(
				"treasury",
				0
			)
		)
		institution ["population"] = int(
			realm.get(
				"population",
				0
			)
		)
		institution ["land"] = int(
			realm.get(
				"land",
				realm.get(
					"land_size",
					0
				)
			)
		)
		institution ["updated_at_ms"] = int(
			Time.get_ticks_msec()
		)

		institutions [institution_id] = institution
		realm_index [str(realm_id)] = institution_id

	state ["institutions"] = institutions
	state ["realm_institution_index"] = realm_index
func _store_institution(
	institution: Dictionary
) -> void:
	var institution_id: String = str(
		institution.get(
			"institution_id",
			""
		)
	)

	if institution_id == "":
		return

	var state: Dictionary = _ensure_state_shape()
	var institutions: Dictionary = _dict(
		state.get(
			"institutions",
			{}
		)
	)
	institutions [institution_id] = (
		institution.duplicate(true)
	)
	state ["institutions"] = institutions
	state ["runtime_revision"] = int(
		state.get(
			"runtime_revision",
			0
		)
	) + 1
	_sync_state_back(state)


func _commit_ruler_transition(
	new_monarch: Person,
	previous_monarch: Person,
	context: Dictionary = {}
) -> void:
	if (
		gs == null
		or gs.royalty_engine == null
		or new_monarch == null
	):
		return

	if gs.royalty_engine.has_method(
		"commit_ruler_transition"
	):
		gs.royalty_engine.commit_ruler_transition(
			new_monarch,
			previous_monarch,
			context
		)


func _canonical_monarch_id(
	institution: Dictionary,
	candidate_ids: Array
) -> int:
	var realm_id: int = int(
		institution.get(
			"realm_id",
			-1
		)
	)

	if (
		realm_id > 0
		and gs != null
		and gs.realm_engine != null
		and typeof(
			gs.realm_engine.realms
		) == TYPE_DICTIONARY
	):
		var realm: Dictionary = _dict(
			gs.realm_engine.realms.get(
				realm_id,
				{}
			)
		)
		var realm_ruler_id: int = int(
			realm.get(
				"ruler_id",
				-1
			)
		)
		var realm_ruler: Person = _person_by_id(
			realm_ruler_id
		)

		if (
			realm_ruler != null
			and realm_ruler.alive
			and not realm_ruler.exiled
			and _person_has_royal_truth(
				realm_ruler
			)
		):
			return realm_ruler_id

	var stored_monarch_id: int = int(
		institution.get(
			"monarch_id",
			-1
		)
	)
	var stored_monarch: Person = _person_by_id(
		stored_monarch_id
	)

	if (
		stored_monarch != null
		and stored_monarch.alive
		and not stored_monarch.exiled
		and _person_has_royal_truth(
			stored_monarch
		)
	):
		return stored_monarch_id

	for raw_candidate_id in candidate_ids:
		var candidate: Person = _person_by_id(
			int(raw_candidate_id)
		)

		if (
			candidate != null
			and candidate.alive
			and candidate.is_ruler
			and not candidate.exiled
			and _person_has_royal_truth(
				candidate
			)
		):
			return int(candidate.id)

	var ordered: Array = _ordered_candidate_ids(
		candidate_ids,
		-1
	)

	if not ordered.is_empty():
		return int(ordered [0])

	return -1


func _ordered_candidate_ids(
	candidate_ids: Array,
	monarch_id: int
) -> Array:
	var candidates: Array = []

	for raw_candidate_id in candidate_ids:
		var candidate: Person = _person_by_id(
			int(raw_candidate_id)
		)

		if (
			candidate == null
			or not candidate.alive
			or candidate.exiled
			or int(candidate.id) == monarch_id
			or not _person_has_royal_truth(
				candidate
			)
		):
			continue

		candidates.append(
			candidate
		)

	candidates.sort_custom(
		func (
			left: Person,
			right: Person
		) -> bool:
			var left_rank: int = int(
				left.succession_rank
			)
			var right_rank: int = int(
				right.succession_rank
			)

			if left_rank <= 0:
				left_rank = 9999
			if right_rank <= 0:
				right_rank = 9999

			if left_rank != right_rank:
				return left_rank < right_rank

			var left_legitimacy: int = (
				_legitimacy_for_actor(left)
			)
			var right_legitimacy: int = (
				_legitimacy_for_actor(right)
			)

			if left_legitimacy != right_legitimacy:
				return (
					left_legitimacy
					> right_legitimacy
				)

			if int(left.age) != int(right.age):
				return int(left.age) > int(right.age)

			return int(left.id) < int(right.id)
	)

	var out: Array = []

	for candidate in candidates:
		out.append(
			int(candidate.id)
		)

	return out


func _claimant_ids_from_candidates(
	candidate_ids: Array
) -> Array:
	var out: Array = []

	for raw_candidate_id in candidate_ids:
		var candidate: Person = _person_by_id(
			int(raw_candidate_id)
		)

		if candidate == null:
			continue

		if (
			candidate.deposed
			or candidate.exiled
			or (
				int(candidate.succession_rank) > 0
				and int(candidate.succession_rank) <= 12
			)
		):
			_append_unique_int(
				out,
				int(candidate.id)
			)

	return out


func _institution_legitimacy(
	institution: Dictionary
) -> int:
	var monarch: Person = _person_by_id(
		int(
			institution.get(
				"monarch_id",
				-1
			)
		)
	)

	if monarch == null:
		return 0

	return _legitimacy_for_actor(monarch)


func _institution_stability(
	institution: Dictionary
) -> int:
	var legitimacy: int = int(
		institution.get(
			"legitimacy",
			0
		)
	)
	var claimant_count: int = _integer_array(
		institution.get(
			"claimant_ids",
			[]
		)
	).size()
	var regency_penalty: int = (
		8
		if bool(
			institution.get(
				"regency_active",
				false
			)
		)
		else 0
	)

	return clampi(
		legitimacy
		- claimant_count * 4
		- regency_penalty,
		0,
		100
	)


func _role_for_actor(
	actor: Person
) -> String:
	if actor == null:
		return "unknown"

	if not _person_has_royal_truth(
		actor
	):
		return "non_royal"

	if actor.is_ruler:
		return "monarch"

	if (
		actor.partner != null
		and actor.partner.is_ruler
		and _person_has_royal_truth(
			actor.partner
		)
	):
		return "consort"

	if int(actor.succession_rank) == 1:
		return "heir"

	if actor.deposed or actor.exiled:
		return "claimant"

	if (
		int(actor.succession_rank) > 1
		and int(actor.succession_rank) <= 12
	):
		return "succession_line"

	if actor.is_royal:
		return "royal_family"

	return "nobility"


func _legitimacy_for_actor(
	actor: Person
) -> int:
	if actor == null:
		return 0

	return clampi(
		int(
			round(
				float(actor.approval) * 0.48
				+ float(actor.fame) * 0.22
				+ float(
					maxi(
						0,
						100 - int(actor.scandal)
					)
				) * 0.14
				+ (
					16.0
					if actor.is_ruler
					else 0.0
				)
			)
		),
		0,
		100
	)


func _ruler_title_for(
	actor: Person
) -> String:
	if (
		gs != null
		and gs.royalty_engine != null
		and gs.royalty_engine.has_method(
			"resolve_rank_title"
		)
	):
		return str(
			gs.royalty_engine.resolve_rank_title(
				actor,
				"ruler"
			)
		)

	return "Monarch"


func _record_event(
	event: Dictionary
) -> void:
	var state: Dictionary = _ensure_state_shape()
	var history: Array = _array(
		state.get(
			"event_history",
			[]
		)
	)

	event ["recorded_at_ms"] = int(
		Time.get_ticks_msec()
	)
	history.append(
		event.duplicate(true)
	)

	if history.size() > MAX_EVENT_HISTORY:
		history = history.slice(
			history.size() - MAX_EVENT_HISTORY,
			history.size()
		)

	state ["event_history"] = history
	_sync_state_back(state)

func _royalty_state_view_read_only() -> Dictionary:
	if gs == null:
		return {}

	var state_raw: Variant = gs.royalty_institution_state

	if typeof(state_raw) == TYPE_DICTIONARY:
		var state: Dictionary = state_raw as Dictionary

		if not state.is_empty():
			return state

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var scenario_state: Dictionary = (
			gs.scenario_state as Dictionary
		)
		var scenario_state_raw: Variant = scenario_state.get(
			STATE_KEY,
			{}
		)

		if typeof(scenario_state_raw) == TYPE_DICTIONARY:
			return scenario_state_raw as Dictionary

	return {}
func _ensure_state_shape() -> Dictionary:
	if gs == null:
		return _default_state()

	var state: Dictionary = _dict(
		gs.royalty_institution_state
	)

	if (
		state.is_empty()
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		state = _dict(
			gs.scenario_state.get(
				STATE_KEY,
				{}
			)
		)

	if state.is_empty():
		state = _default_state()

	for key in [
		"institutions",
		"houses",
		"person_index",
		"realm_institution_index",
		"provider_state"
	]:
		if typeof(
			state.get(
				key,
				{}
			)
		) != TYPE_DICTIONARY:
			state [key] = {}

	for key in [
		"event_history",
		"global_decrees",
		"global_ceremonies"
	]:
		if typeof(
			state.get(
				key,
				[]
			)
		) != TYPE_ARRAY:
			state [key] = []

	state ["schema"] = STATE_SCHEMA
	state ["version"] = STATE_VERSION

	if not state.has("runtime_revision"):
		state ["runtime_revision"] = 0

	_sync_state_back(state)
	return state


func _sync_state_back(
	state: Dictionary
) -> void:
	if gs == null:
		return

	gs.royalty_institution_state = state.duplicate(
		true
	)

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state [STATE_KEY] = state.duplicate(
		true
	)


func _default_state() -> Dictionary:
	return {
		"schema": STATE_SCHEMA,
		"version": STATE_VERSION,
		"institutions": {},
		"houses": {},
		"person_index": {},
		"realm_institution_index": {},
		"provider_state": {},
		"event_history": [],
		"global_decrees": [],
		"global_ceremonies": [],
		"runtime_revision": 0,
		"last_boot_year": -1,
		"last_boot_era": "",
		"last_repair_report": {}
	}


func _default_institution(
	institution_id: String,
	realm_id: int,
	realm_name: String
) -> Dictionary:
	return {
		"schema": (
			"eralife.royalty_institution_contract"
		),
		"version": 1,
		"institution_id": institution_id,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"government_style": "Monarchy",
		"active": true,
		"monarch_id": -1,
		"consort_id": -1,
		"regent_id": -1,
		"regency_active": false,
		"regency_reason": "",
		"house_id": "",
		"member_ids": [],
		"court_member_ids": [],
		"claimant_ids": [],
		"line_of_succession": [],
		"decrees": [],
		"ceremonies": [],
		"diplomatic_houses": [],
		"royal_assets": [],
		"legitimacy": 0,
		"stability": 0,
		"treasury": 0,
		"population": 0,
		"land": 0,
		"integrity_state": "uninitialized",
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func _institution_id(
	realm_id: int,
	realm_name: String,
	house_id: String
) -> String:
	if realm_id > 0:
		return "royalty.realm.%d" % realm_id

	var realm_slug: String = _slug(realm_name)

	if realm_slug != "":
		return "royalty.realm.%s" % realm_slug

	return "royalty.house.%s" % (
		house_id
		if house_id != ""
		else "unbound"
	)


func _house_id_for_actor(
	actor: Person
) -> String:
	if actor == null:
		return "house.unbound"

	if (
		gs != null
		and gs.royalty_engine != null
		and gs.royalty_engine.has_method(
			"house_key_for"
		)
	):
		var legacy_key: String = str(
			gs.royalty_engine.house_key_for(actor)
		).strip_edges()

		if legacy_key != "":
			return "house.%s" % _slug(legacy_key)

	var origin: String = str(
		actor.dynasty_origin
	).strip_edges()

	if origin == "":
		origin = str(actor.last_name).strip_edges()

	if origin == "":
		origin = "unbound_%d" % int(actor.id)

	return "house.%s" % _slug(origin)


func _house_display_name(
	actor: Person,
	house_id: String
) -> String:
	if actor == null:
		return "Royal House"

	var realm_id: int = _realm_id_for_actor(
		actor
	)
	var family_name: String = str(
		actor.last_name
	).strip_edges()
	var origin: String = str(
		actor.dynasty_origin
	).strip_edges()

	if origin.begins_with(
		"royal_house:"
	):
		var origin_parts: PackedStringArray = (
			origin.split(
				":",
				false
			)
		)

		if origin_parts.size() >= 2:
			var parsed_family_name: String = str(
				origin_parts [1]
			).strip_edges()

			if parsed_family_name != "":
				family_name = parsed_family_name

		if (
			realm_id <= 0
			and origin_parts.size() >= 3
			and str(
				origin_parts [2]
			).is_valid_int()
		):
			realm_id = int(
				origin_parts [2]
			)
	elif origin.begins_with(
		"house."
	):
		var parsed_origin: String = (
			origin.trim_prefix(
				"house."
			)
			.replace(
				"_",
				" "
			)
			.strip_edges()
			.capitalize()
		)

		if parsed_origin != "":
			family_name = parsed_origin
	elif origin != "":
		family_name = origin

	if family_name == "":
		var clean_house_id: String = str(
			house_id
		).strip_edges()

		if clean_house_id.begins_with(
			"house."
		):
			clean_house_id = (
				clean_house_id.trim_prefix(
					"house."
				)
			)

		family_name = (
			clean_house_id
			.replace(
				"_",
				" "
			)
			.strip_edges()
			.capitalize()
		)

	if family_name == "":
		family_name = "Royal"

	if realm_id > 0:
		return "House (%d): %s" % [
			realm_id,
			family_name
		]

	return "House: %s" % family_name
func _realm_id_for_actor(
	actor: Person
) -> int:
	if actor == null:
		return -1

	if int(actor.realm_id) > 0:
		return int(actor.realm_id)

	if (
		gs != null
		and gs.realm_engine != null
		and typeof(
			gs.realm_engine.realms
		) == TYPE_DICTIONARY
	):
		for raw_realm_id in gs.realm_engine.realms.keys():
			var realm: Dictionary = _dict(
				gs.realm_engine.realms.get(
					raw_realm_id,
					{}
				)
			)

			if int(
				realm.get(
					"ruler_id",
					-1
				)
			) == int(actor.id):
				return int(raw_realm_id)

	return -1


func _realm_name_for_actor(
	actor: Person,
	realm_id: int
) -> String:
	if (
		realm_id > 0
		and gs != null
		and gs.realm_engine != null
		and typeof(
			gs.realm_engine.realms
		) == TYPE_DICTIONARY
	):
		var realm: Dictionary = _dict(
			gs.realm_engine.realms.get(
				realm_id,
				{}
			)
		)
		var realm_name: String = str(
			realm.get(
				"name",
				""
			)
		).strip_edges()

		if realm_name != "":
			return realm_name

	if actor != null:
		for value in [
			str(actor.home_country),
			str(actor.bending_nation)
		]:
			var clean: String = str(value).strip_edges()

			if clean != "":
				return clean

	return "Unbound Realm"


func _all_people() -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if gs == null:
		return out

	if gs.player != null:
		seen [int(gs.player.id)] = true
		out.append(gs.player)

	for raw_actor in gs.npcs:
		var actor: Person = raw_actor

		if actor == null:
			continue
		if seen.has(int(actor.id)):
			continue

		seen [int(actor.id)] = true
		out.append(actor)

	return out


func _person_has_royal_truth(
	actor: Person
) -> bool:
	if actor == null:
		return false




	if _civic_office_preempts_royal_truth(
		actor
	):
		return false

	var succession_rank: int = int(
		actor.succession_rank
	)
	var valid_hereditary_rank: bool = (
		succession_rank > 0
		and succession_rank < 99
	)



	return (
		bool(
			actor.is_royal
		)
		or valid_hereditary_rank
		or str(
			actor.royal_title
		).strip_edges() != ""
		or str(
			actor.social_class
		).strip_edges() in [
			"Royal",
			"Noble"
		]
	)

func _civic_contract_preempts_royal_truth(
	contract: Dictionary
) -> bool:
	if contract.is_empty():
		return false



	if (
		contract.has("is_royalty")
		and bool(
			contract.get(
				"is_royalty",
				false
			)
		)
	):
		return false

	var government_model: String = str(
		contract.get(
			"government_model",
			""
		)
	).strip_edges().to_lower()
	var office: String = str(
		contract.get(
			"office",
			""
		)
	).strip_edges().to_lower()
	var explicitly_non_royal: bool = (
		contract.has(
			"is_royalty"
		)
		and not bool(
			contract.get(
				"is_royalty",
				false
			)
		)
	)

	return (
		government_model.contains(
			"republic"
		)
		or bool(
			contract.get(
				"elected_office",
				false
			)
		)
		or (
			explicitly_non_royal
			and (
				bool(
					contract.get(
						"ruling_power_by_office",
						false
					)
				)
				or office.contains(
					"president"
				)
			)
		)
	)


func _civic_office_preempts_royal_truth(
	actor: Person
) -> bool:
	if actor == null:
		return false





	var public_identity_raw: Variant = actor.get(
		"public_identity_contract"
	)

	if typeof(
		public_identity_raw
	) == TYPE_DICTIONARY:
		var public_identity: Dictionary = (
			public_identity_raw as Dictionary
		)

		if bool(
			public_identity.get(
				"royal_language_forbidden",
				false
			)
		):
			return true

	var civic_raw: Variant = actor.get(
		"civic_office_contract"
	)

	if typeof(
		civic_raw
	) != TYPE_DICTIONARY:
		return false

	return _civic_contract_preempts_royal_truth(
		civic_raw as Dictionary
	)
func _person_by_id(
	actor_id: int
) -> Person:
	if gs == null or actor_id <= 0:
		return null

	if (
		gs.player != null
		and int(gs.player.id) == actor_id
	):
		return gs.player

	var actor: Person = gs.get_npc_by_id(actor_id)

	if (
		actor == null
		and gs.has_method(
			"get_or_reactivate_npc_by_id"
		)
	):
		actor = gs.get_or_reactivate_npc_by_id(
			actor_id
		)

	return actor


func _person_from_payload(
	payload
) -> Person:
	if payload is Person:
		return payload

	if typeof(payload) == TYPE_DICTIONARY:
		var row: Dictionary = payload as Dictionary

		for key in [
			"npc",
			"person",
			"actor",
			"target"
		]:
			var value: Variant = row.get(
				key,
				null
			)

			if value is Person:
				return value

		for key in [
			"npc_id",
			"person_id",
			"actor_id",
			"target_id"
		]:
			var actor_id: int = int(
				row.get(
					key,
					-1
				)
			)

			if actor_id > 0:
				return _person_by_id(actor_id)

	return null


func _people_from_payload(
	payload
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if payload is Person:
		return [
			payload
		]

	if typeof(payload) != TYPE_DICTIONARY:
		return out

	var row: Dictionary = payload as Dictionary

	for key in [
		"npc",
		"person",
		"actor",
		"target",
		"partner",
		"person_a",
		"person_b",
		"spouse_a",
		"spouse_b"
	]:
		var value: Variant = row.get(
			key,
			null
		)

		if value is Person:
			var actor: Person = value

			if not seen.has(int(actor.id)):
				seen [int(actor.id)] = true
				out.append(actor)

	for key in [
		"npc_id",
		"person_id",
		"actor_id",
		"target_id",
		"partner_id",
		"person_a_id",
		"person_b_id"
	]:
		var actor_id: int = int(
			row.get(
				key,
				-1
			)
		)
		var actor: Person = _person_by_id(actor_id)

		if (
			actor != null
			and not seen.has(int(actor.id))
		):
			seen [int(actor.id)] = true
			out.append(actor)

	return out


func _current_year() -> int:
	return (
		int(gs.year)
		if gs != null
		else 0
	)


func _current_era_name() -> String:
	if gs == null or gs.era == null:
		return "Unknown Era"

	return str(
		gs.era.get(
			"name",
			"Unknown Era"
		)
	)


func _person_name(
	actor: Person
) -> String:
	if actor == null:
		return "Unknown Person"

	var full_name: String = "%s %s" % [
		str(actor.first_name),
		str(actor.last_name)
	]
	full_name = full_name.strip_edges()

	return (
		full_name
		if full_name != ""
		else "Person %d" % int(actor.id)
	)


func _append_unique_int(
	values: Array,
	value: int
) -> void:
	if value > 0 and value not in values:
		values.append(value)


func _integer_array(
	value
) -> Array:
	var out: Array = []

	if typeof(value) != TYPE_ARRAY:
		return out

	for raw_value in value as Array:
		var int_value: int = int(raw_value)

		if int_value > 0 and int_value not in out:
			out.append(int_value)

	return out


func _slug(
	value: String
) -> String:
	var out: String = str(
		value
	).strip_edges().to_lower()

	for token in [
		" ",
		"-",
		"/",
		"\\",
		":",
		".",
		",",
		"'",
		"\""
	]:
		out = out.replace(
			token,
			"_"
		)

	while "__" in out:
		out = out.replace(
			"__",
			"_"
		)

	return out.trim_prefix(
		"_"
	).trim_suffix(
		"_"
	)


func _dict(
	value
) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)

	return {}


func _array(
	value
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []


func _fail(
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