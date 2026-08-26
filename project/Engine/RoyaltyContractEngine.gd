

extends Resource
class_name RoyaltyContractEngine

const ENGINE_SCHEMA:= "eralife.royalty_contract_engine"
const ENGINE_VERSION:= 1
const CONTRACT_SCHEMA:= "eralife.royalty_constitutional_contract"
const CONTRACT_VERSION:= 1

var gs
var constitutional_contract_registry: Dictionary = {}
var realm_contract_index: Dictionary = {}
var last_report: Dictionary = {}


func _init(
	_gs = null
) -> void:
	gs = _gs


func bootstrap_default_contracts() -> Dictionary:
	constitutional_contract_registry.clear()

	var legacy_contracts: Dictionary = {}

	if (
		gs != null
		and gs.royalty_engine != null
		and gs.royalty_engine.has_method(
			"export_succession_contracts"
		)
	):
		legacy_contracts = _dict(
			gs.royalty_engine.export_succession_contracts()
		)

	for raw_key in legacy_contracts.keys():
		var legacy: Dictionary = _dict(
			legacy_contracts.get(
				raw_key,
				{}
			)
		)

		register_constitutional_contract(
			_normalize_constitutional_contract(
				str(raw_key),
				legacy
			)
		)

	if constitutional_contract_registry.is_empty():
		register_constitutional_contract(
			_default_constitutional_contract()
		)

	if gs != null and gs.royalty_mod_contract_engine != null:
		gs.royalty_mod_contract_engine.rebuild_provider_cache({
			"source": (
				"royalty_contract_engine."
				+ "bootstrap_default_contracts"
			)
		})

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"constitutional_contract_count": (
			constitutional_contract_registry.size()
		),
		"ui_is_renderer_only": true
	}

	return last_report.duplicate(true)


func register_constitutional_contract(
	contract: Dictionary
) -> Dictionary:
	var normalized: Dictionary = (
		_normalize_constitutional_contract(
			str(
				contract.get(
					"id",
					contract.get(
						"contract_id",
						""
					)
				)
			),
			contract
		)
	)
	var validation: Dictionary = (
		validate_constitutional_contract(
			normalized
		)
	)

	if not bool(
		validation.get(
			"valid",
			false
		)
	):
		return {
			"success": false,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"validation": validation
		}

	var contract_id: String = str(
		normalized.get(
			"id",
			""
		)
	)
	constitutional_contract_registry [contract_id] = (
		normalized.duplicate(true)
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"contract_id": contract_id,
		"validation": validation
	}


func validate_constitutional_contract(
	contract: Dictionary
) -> Dictionary:
	var errors: Array = []
	var warnings: Array = []
	var contract_id: String = str(
		contract.get(
			"id",
			""
		)
	).strip_edges()

	if contract_id == "":
		errors.append(
			"A royalty constitutional contract requires id."
		)

	var succession: Dictionary = _dict(
		contract.get(
			"succession",
			{}
		)
	)

	if succession.is_empty():
		errors.append(
			"A royalty constitutional contract requires succession law."
		)

	if str(
		succession.get(
			"mode",
			""
		)
	).strip_edges() == "":
		errors.append(
			"Succession law requires mode."
		)

	var legitimacy: Dictionary = _dict(
		contract.get(
			"legitimacy",
			{}
		)
	)

	if legitimacy.is_empty():
		warnings.append(
			"Legitimacy law was absent; runtime defaults will apply."
		)

	var regency: Dictionary = _dict(
		contract.get(
			"regency",
			{}
		)
	)

	if regency.is_empty():
		warnings.append(
			"Regency law was absent; constitutional regency remains permissive."
		)

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings
	}


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No royalty actor could be resolved."
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
	var result: Dictionary

	match action_id:
		"", "refresh", "observe_partial", "open_hub":
			result = {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"version": ENGINE_VERSION,
				"type": "royalty_truth_observed",
				"text": "Royalty truth is observable."
			}

		"abdicate":
			result = _runtime().commit_abdication(
				actor,
				int(
					payload.get(
						"heir_id",
						payload.get(
							"target_id",
							-1
						)
					)
				),
				payload
			)

		"appoint_heir":
			result = _runtime().appoint_heir(
				actor,
				int(
					payload.get(
						"heir_id",
						payload.get(
							"target_id",
							-1
						)
					)
				),
				payload
			)

		"coronate":
			var candidate: Person = _person_by_id(
				int(
					payload.get(
						"candidate_id",
						payload.get(
							"target_id",
							int(actor.id)
						)
					)
				)
			)

			if candidate == null:
				candidate = actor

			result = _runtime().commit_coronation(
				candidate,
				payload
			)

		"establish_regency":
			result = _runtime().establish_regency(
				actor,
				int(
					payload.get(
						"regent_id",
						payload.get(
							"target_id",
							-1
						)
					)
				),
				payload
			)

		"end_regency":
			result = _runtime().end_regency(
				actor,
				payload
			)

		"marry_into_royalty":
			result = _resolve_royal_marriage(
				actor,
				payload
			)

		"claim_throne", "attempt_coup":
			result = _resolve_claim_throne(
				actor,
				payload
			)

		"royal_public_action":
			result = _resolve_public_action(
				actor,
				payload
			)

		"self_heal":
			result = self_heal(payload)

		_:
			result = _fail(
				"unknown_royalty_intent",
				"RoyaltyContractEngine does not recognize that intent."
			)

	result ["constitutional_authority"] = ENGINE_SCHEMA
	result ["ui_is_renderer_only"] = true
	last_report = result.duplicate(true)

	return result


func on_npc_born(
	payload = {}
) -> void:
	if (
		gs == null
		or gs.royalty_engine == null
	):
		return

	gs.royalty_engine.assign_royal_birth(payload)

	var actor: Person = _person_from_payload(payload)

	if (
		actor != null
		and _runtime() != null
	):
		_runtime().ingest_actor(
			actor,
			{
				"source": (
					"royalty_contract_engine.on_npc_born"
				)
			}
		)
		_runtime().repair_state({
			"source": (
				"royalty_contract_engine.on_npc_born"
			)
		})


func on_npc_married(
	payload = {}
) -> void:
	var people: Array = _people_from_payload(payload)

	if people.size() < 2:
		if _runtime() != null:
			_runtime().on_npc_married(payload)
		return

	var first: Person = people [0]
	var second: Person = people [1]

	if first == null or second == null:
		return

	if (
		first.is_royal
		and not second.is_royal
		and gs.royalty_engine != null
	):
		gs.royalty_engine.marry_into_royalty(
			second,
			first
		)
	elif (
		second.is_royal
		and not first.is_royal
		and gs.royalty_engine != null
	):
		gs.royalty_engine.marry_into_royalty(
			first,
			second
		)

	if _runtime() != null:
		_runtime().on_npc_married(payload)


func evaluate_succession_for_institution(
	institution: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if institution.is_empty():
		return _fail(
			"missing_institution",
			"No royalty institution was supplied."
		)

	var monarch: Person = _person_by_id(
		int(
			institution.get(
				"monarch_id",
				-1
			)
		)
	)
	var ordered_people: Array = []

	if (
		monarch != null
		and gs != null
		and gs.royalty_engine != null
		and gs.royalty_engine.has_method(
			"build_succession_line_for_ruler"
		)
	):
		ordered_people = gs.royalty_engine.build_succession_line_for_ruler(
			monarch
		)
	else:
		for raw_actor_id in _array(
			institution.get(
				"line_of_succession",
				[]
			)
		):
			var candidate: Person = _person_by_id(
				int(raw_actor_id)
			)

			if candidate != null:
				ordered_people.append(candidate)

	var rows: Array = []
	var rank: int = 1

	for candidate in ordered_people:
		if (
			candidate == null
			or not candidate.alive
			or candidate.exiled
			or (
				monarch != null
				and int(candidate.id) == int(monarch.id)
			)
		):
			continue

		rows.append({
			"rank": rank,
			"actor_id": int(candidate.id),
			"name": _person_name(candidate),
			"title": str(candidate.royal_title),
			"house_id": _house_id_for_actor(candidate),
			"legitimacy": _legitimacy_for_actor(candidate),
			"approval": int(candidate.approval),
			"fame": int(candidate.fame),
			"deposed": bool(candidate.deposed),
			"exiled": bool(candidate.exiled),
			"eligible": true
		})
		rank += 1

	var contract: Dictionary = (
		constitutional_contract_for_actor(
			monarch
			if monarch != null
			else _person_by_id(
				int(
					institution.get(
						"member_ids",
						[-1]
					) [0]
					if not _array(
						institution.get(
							"member_ids",
							[]
						)
					).is_empty()
					else -1
				)
			)
		)
	)

	return {
		"success": true,
		"schema": (
			"eralife.royalty_succession_projection"
		),
		"version": 1,
		"institution_id": str(
			institution.get(
				"institution_id",
				""
			)
		),
		"monarch_id": (
			int(monarch.id)
			if monarch != null
			else -1
		),
		"constitutional_contract": contract,
		"candidates": rows,
		"source": str(
			context.get(
				"source",
				"evaluate_succession_for_institution"
			)
		)
	}


func permissions_for_actor(
	actor: Person
) -> Dictionary:
	var out: Dictionary = {
		"open": false,
		"throne": false,
		"court": false,
		"nation": false,
		"allocation": false,
		"diplomacy": false,
		"law": false,
		"dynasty": false,
		"authority_tier": "none",
		"symbolic_only": false,
		"is_claimant": false,
		"is_high_in_line": false,
		"can_abdicate": false,
		"can_appoint_heir": false,
		"can_coronate": false,
		"can_establish_regency": false,
		"can_end_regency": false,
		"can_issue_decrees": false,
		"can_manage_court": false,
		"can_manage_population": false,
		"can_manage_allocation": false,
		"can_use_diplomacy": false
	}

	if actor == null or _runtime() == null:
		return out

	var institution: Dictionary = (
		_runtime().institution_for_actor(actor)
	)

	if institution.is_empty():
		return out

	var monarch_id: int = int(
		institution.get(
			"monarch_id",
			-1
		)
	)
	var is_monarch: bool = monarch_id == int(actor.id)
	var succession_rank: int = int(
		actor.succession_rank
	)
	var is_high_in_line: bool = (
		succession_rank > 0
		and succession_rank <= 5
	)
	var is_claimant: bool = (
		actor.deposed
		or actor.exiled
		or (
			succession_rank > 0
			and succession_rank <= 12
		)
	)
	var is_royal: bool = (
		actor.is_royal
		or str(actor.royal_title).strip_edges() != ""
	)
	var is_noble: bool = str(
		actor.social_class
	).strip_edges() == "Noble"

	out ["open"] = (
		is_monarch
		or is_royal
		or is_noble
		or is_claimant
	)
	out ["throne"] = bool(out ["open"])
	out ["court"] = (
		is_monarch
		or is_royal
		or is_noble
		or is_claimant
	)
	out ["nation"] = is_monarch or is_claimant
	out ["allocation"] = is_monarch
	out ["diplomacy"] = (
		is_monarch
		or is_high_in_line
		or is_claimant
	)
	out ["law"] = is_monarch or is_high_in_line
	out ["dynasty"] = bool(out ["open"])
	out ["symbolic_only"] = (
		is_royal
		and not is_monarch
		and not is_claimant
		and not is_high_in_line
	)
	out ["is_claimant"] = is_claimant
	out ["is_high_in_line"] = is_high_in_line

	if is_monarch:
		out ["authority_tier"] = "state"
	elif is_claimant:
		out ["authority_tier"] = "claimant"
	elif is_high_in_line:
		out ["authority_tier"] = "succession"
	elif is_royal:
		out ["authority_tier"] = "ceremonial"
	elif is_noble:
		out ["authority_tier"] = "noble"

	out ["can_abdicate"] = is_monarch
	out ["can_appoint_heir"] = is_monarch
	out ["can_coronate"] = (
		not is_monarch
		and (
			succession_rank == 1
			or actor.deposed
		)
	)
	out ["can_establish_regency"] = is_monarch
	out ["can_end_regency"] = bool(
		institution.get(
			"regency_active",
			false
		)
	) and (
		is_monarch
		or int(
			institution.get(
				"regent_id",
				-1
			)
		) == int(actor.id)
	)
	out ["can_issue_decrees"] = is_monarch
	out ["can_manage_court"] = is_monarch
	out ["can_manage_population"] = (
		is_monarch
		or is_high_in_line
	)
	out ["can_manage_allocation"] = is_monarch
	out ["can_use_diplomacy"] = bool(
		out ["diplomacy"]
	)

	return out

func _royalty_realm_projection_for_actor(
	actor: Person
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.realm_engine == null
		or typeof(
			gs.realm_engine.realms
		) != TYPE_DICTIONARY
	):
		return {}

	var realms: Dictionary = (
		gs.realm_engine.realms
	)
	var realm_id: int = int(
		actor.realm_id
	)

	if realm_id > 0:
		var direct_raw: Variant = realms.get(
			realm_id,
			realms.get(
				str(realm_id),
				{}
			)
		)

		if typeof(direct_raw) == TYPE_DICTIONARY:
			var direct: Dictionary = (
				direct_raw as Dictionary
			)

			if not direct.is_empty():
				return direct.duplicate(true)

	var identity_names: Array = []

	for raw_name in [
		str(actor.home_country),
		str(actor.birth_country),
		str(actor.bending_nation)
	]:
		var clean_name: String = str(
			raw_name
		).strip_edges()

		if (
			clean_name != ""
			and clean_name not in identity_names
		):
			identity_names.append(
				clean_name
			)

	for raw_realm_key in realms.keys():
		var realm_raw: Variant = realms.get(
			raw_realm_key,
			{}
		)

		if typeof(realm_raw) != TYPE_DICTIONARY:
			continue

		var realm: Dictionary = (
			realm_raw as Dictionary
		)

		if int(
			realm.get(
				"ruler_id",
				-1
			)
		) == int(actor.id):
			return realm.duplicate(true)

		var realm_name: String = str(
			realm.get(
				"name",
				""
			)
		).strip_edges()

		for raw_identity_name in identity_names:
			if realm_name.to_lower() == str(
				raw_identity_name
			).strip_edges().to_lower():
				return realm.duplicate(true)

	return {}


func _royalty_pressure_projection_for_actor(
	actor: Person
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or typeof(
			gs.transient_scenario_biases
		) != TYPE_DICTIONARY
	):
		return {}

	var raw_bias: Variant = (
		gs.transient_scenario_biases.get(
			int(actor.id),
			{}
		)
	)
	var bias: Dictionary = {}

	if typeof(raw_bias) == TYPE_ARRAY:
		var bias_rows: Array = (
			raw_bias as Array
		)

		if (
			not bias_rows.is_empty()
			and typeof(
				bias_rows [0]
			) == TYPE_DICTIONARY
		):
			bias = (
				bias_rows [0] as Dictionary
			)
	elif typeof(raw_bias) == TYPE_DICTIONARY:
		bias = (
			raw_bias as Dictionary
		)

	return _dict(
		bias.get(
			"faction_pressure",
			{}
		)
	)


func _royal_title_implies_reigning_authority(
	actor: Person
) -> bool:
	if actor == null:
		return false

	if bool(
		actor.is_ruler
	):
		return true

	var title_text: String = str(
		actor.royal_title
	).strip_edges().to_lower()

	if title_text == "":
		return false

	for raw_title in [
		"king",
		"queen",
		"emperor",
		"empress",
		"pharaoh",
		"fire lord",
		"earth king",
		"sultan",
		"sultana",
		"shah",
		"tsar",
		"czar",
		"monarch"
	]:
		var reigning_title: String = str(
			raw_title
		)

		if (
			title_text == reigning_title
			or title_text.begins_with(
				"%s " % reigning_title
			)
			or title_text.ends_with(
				" %s" % reigning_title
			)
		):
			return true

	return false


func _royalty_house_label_for_actor(
	actor: Person,
	house: Dictionary,
	realm_id: int
) -> String:
	if actor == null:
		return "House: Royal"

	var existing_label: String = str(
		house.get(
			"display_label",
			house.get(
				"display_name",
				""
			)
		)
	).strip_edges()

	if (
		existing_label.begins_with(
			"House ("
		)
		or existing_label.begins_with(
			"House:"
		)
	):
		return existing_label

	var family_name: String = str(
		actor.last_name
	).strip_edges()
	var origin: String = str(
		actor.dynasty_origin
	).strip_edges()
	var resolved_realm_id: int = realm_id

	if origin.begins_with(
		"royal_house:"
	):
		var parts: PackedStringArray = (
			origin.split(
				":",
				false
			)
		)

		if parts.size() >= 2:
			var parsed_family: String = str(
				parts [1]
			).strip_edges()

			if parsed_family != "":
				family_name = parsed_family

		if (
			resolved_realm_id <= 0
			and parts.size() >= 3
			and str(parts [2]).is_valid_int()
		):
			resolved_realm_id = int(
				parts [2]
			)
	elif origin != "":
		family_name = origin

	if family_name == "":
		family_name = "Royal"

	if resolved_realm_id > 0:
		return "House (%d): %s" % [
			resolved_realm_id,
			family_name
		]

	return "House: %s" % family_name
func summary_for_actor(
	actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	var institution: Dictionary = {}

	if _runtime() != null:
		institution = (
			_runtime().institution_for_actor(
				actor
			)
		)

	var stored_monarch: Person = _person_by_id(
		int(
			institution.get(
				"monarch_id",
				-1
			)
		)
	)
	var effective_monarch: Person = stored_monarch
	var actor_reigning_truth: bool = (
		_royal_title_implies_reigning_authority(
			actor
		)
	)




	if (
		effective_monarch == null
		and actor_reigning_truth
	):
		effective_monarch = actor

	var realm: Dictionary = (
		_royalty_realm_projection_for_actor(
			actor
		)
	)
	var realm_id: int = int(
		realm.get(
			"realm_id",
			realm.get(
				"id",
				institution.get(
					"realm_id",
					actor.realm_id
				)
			)
		)
	)
	var realm_name: String = str(
		realm.get(
			"name",
			institution.get(
				"realm_name",
				actor.home_country
			)
		)
	).strip_edges()

	if realm_name == "":
		realm_name = "Unbound Realm"

	var house: Dictionary = (
		_runtime().house_for_actor(
			actor
		)
		if _runtime() != null
		else {}
	)
	var house_label: String = (
		_royalty_house_label_for_actor(
			actor,
			house,
			realm_id
		)
	)
	var pressure: Dictionary = (
		_royalty_pressure_projection_for_actor(
			actor
		)
	)
	var claimant_ids: Array = _array(
		institution.get(
			"claimant_ids",
			[]
		)
	)
	var court_member_ids: Array = _array(
		institution.get(
			"court_member_ids",
			[]
		)
	)
	var succession_ids: Array = _array(
		institution.get(
			"line_of_succession",
			[]
		)
	)

	var approval: int = clampi(
		int(actor.approval),
		0,
		100
	)
	var calculated_legitimacy: int = clampi(
		int(
			round(
				(float(approval) * 0.65)
				+ (float(actor.fame) * 0.2)
				+ (
					15.0
					if effective_monarch == actor
					else 0.0
				)
				- (float(actor.scandal) * 0.18)
			)
		),
		0,
		100
	)
	var legitimacy: int = int(
		institution.get(
			"legitimacy",
			0
		)
	)

	if legitimacy <= 0:
		legitimacy = calculated_legitimacy

	var respect_bias: int = int(
		realm.get(
			"respect_bias",
			0
		)
	)
	var respect: int = clampi(
		int(
			round(
				(float(actor.fame) * 0.55)
				+ (
					float(
						maxi(
							0,
							100 - int(actor.scandal)
						)
					) * 0.2
				)
				+ (
					12.0
					if effective_monarch == actor
					else 0.0
				)
				+ float(respect_bias)
			)
		),
		0,
		100
	)
	var stability: int = int(
		institution.get(
			"stability",
			0
		)
	)

	if stability <= 0:
		stability = clampi(
			legitimacy
			- claimant_ids.size() * 4,
			0,
			100
		)

	var population: int = maxi(
		int(
			institution.get(
				"population",
				0
			)
		),
		int(
			realm.get(
				"population",
				0
			)
		)
	)
	var treasury: int = maxi(
		int(
			institution.get(
				"treasury",
				0
			)
		),
		int(
			realm.get(
				"treasury",
				0
			)
		)
	)

	if (
		treasury <= 0
		and realm.is_empty()
	):
		treasury = maxi(
			0,
			int(actor.bank_balance)
		)

	var land: int = maxi(
		int(
			institution.get(
				"land",
				0
			)
		),
		int(
			realm.get(
				"land",
				realm.get(
					"land_size",
					0
				)
			)
		)
	)
	var military_stockpile: int = maxi(
		int(
			institution.get(
				"military_stockpile",
				0
			)
		),
		int(
			realm.get(
				"military_stockpile",
				0
			)
		)
	)
	var goods_stockpile: int = maxi(
		int(
			institution.get(
				"goods_stockpile",
				0
			)
		),
		int(
			realm.get(
				"goods_stockpile",
				0
			)
		)
	)
	var happiness: int = clampi(
		int(
			realm.get(
				"happiness",
				institution.get(
					"happiness",
					actor.satisfaction
				)
			)
		),
		0,
		100
	)
	var tax_rate: float = clampf(
		float(
			realm.get(
				"tax_rate",
				institution.get(
					"tax_rate",
					10.0
				)
			)
		),
		0.0,
		40.0
	)
	var quality: float = float(
		realm.get(
			"quality",
			realm.get(
				"country_quality",
				50.0
			)
		)
	)
	var prosperity: float = float(
		realm.get(
			"prosperity",
			realm.get(
				"realm_quality",
				0.0
			)
		)
	)
	var taxable_income_per_citizen: float = maxf(
		24.0,
		120.0
		+ (quality * 6.0)
		+ (prosperity * 2.5)
		+ minf(
			80.0,
			float(land) * 0.04
		)
	)
	var total_tax_revenue: int = (
		maxi(
			0,
			int(
				round(
					float(population)
					* taxable_income_per_citizen
					* (tax_rate / 100.0)
				)
			)
		)
		if (
			population > 0
			and tax_rate > 0.0
		)
		else 0
	)
	var allocation_reserve: int = int(
		realm.get(
			"allocation_reserve",
			institution.get(
				"allocation_reserve",
				0
			)
		)
	)
	var allocation_pool: int = int(
		realm.get(
			"allocation_pool",
			allocation_reserve
			+ total_tax_revenue
		)
	)
	var claimant_pressure: float = float(
		pressure.get(
			"claim_pressure_total",
			pressure.get(
				"claimant_pressure",
				pressure.get(
					"claim_pressure",
					0.0
				)
			)
		)
	)
	var succession_tension: float = float(
		pressure.get(
			"royal_succession_tension",
			0.0
		)
	)
	var coup_pressure: float = float(
		pressure.get(
			"coup_pressure",
			0.0
		)
	)
	var standing: String = "Stable"

	if actor.exiled:
		standing = "Exiled"
	elif actor.deposed:
		standing = "Deposed"
	elif coup_pressure >= 18.0:
		standing = "Coup-prone"
	elif succession_tension >= 12.0:
		standing = "Succession-fragile"
	elif legitimacy >= 72:
		standing = "Dominant"
	elif legitimacy <= 35:
		standing = "Unstable"

	var actor_title: String = str(
		actor.royal_title
	).strip_edges()

	if (
		actor_title == ""
		and effective_monarch != null
	):
		actor_title = str(
			effective_monarch.royal_title
		).strip_edges()

	if actor_title == "":
		actor_title = (
			"Ruler"
			if effective_monarch == actor
			else "Royal"
		)

	var alerts: Array = []

	if actor.exiled:
		alerts.append(
			"You are operating from exile."
		)

	if actor.deposed:
		alerts.append(
			"Your authority is contested after deposition."
		)

	if succession_tension >= 10.0:
		alerts.append(
			"Succession pressure is heating up."
		)

	if coup_pressure >= 12.0:
		alerts.append(
			"Court and bloc pressure suggest coup risk."
		)

	if approval <= 35:
		alerts.append(
			"Public legitimacy is low."
		)



	if (
		effective_monarch == null
		and actor_title == ""
	):
		alerts.append(
			"The institution has no recognized monarch."
		)

	if alerts.is_empty():
		alerts.append(
			"No urgent crown alerts right now."
		)

	var integrity_state: String = str(
		institution.get(
			"integrity_state",
			"unknown"
		)
	)

	if (
		integrity_state in [
			"",
			"unknown",
			"uninitialized",
			"vacant_throne"
		]
		and actor_title != ""
	):
		integrity_state = (
			"actor_royal_truth_projected"
		)

	return {
		"institution_id": str(
			institution.get(
				"institution_id",
				""
			)
		),
		"realm_id": realm_id,
		"realm_name": realm_name,
		"government_style": str(
			realm.get(
				"government_style",
				institution.get(
					"government_style",
					"Monarchy"
				)
			)
		),
		"monarch_id": (
			int(effective_monarch.id)
			if effective_monarch != null
			else -1
		),
		"monarch_name": _person_name(
			effective_monarch
		),
		"title": actor_title,
		"actor_title": actor_title,
		"actor_id": int(actor.id),
		"actor_is_monarch": (
			effective_monarch == actor
		),
		"throne_vacant": (
			effective_monarch == null
		),
		"house_id": str(
			house.get(
				"house_id",
				institution.get(
					"house_id",
					""
				)
			)
		),
		"house_name": str(
			house.get(
				"display_name",
				actor.last_name
			)
		),
		"house_label": house_label,
		"approval": approval,
		"legitimacy": legitimacy,
		"respect": respect,
		"stability": stability,
		"population": population,
		"treasury": treasury,
		"land": land,
		"military_stockpile": military_stockpile,
		"goods_stockpile": goods_stockpile,
		"currency_name": str(
			realm.get(
				"currency_name",
				institution.get(
					"currency_name",
					""
				)
			)
		),
		"tax_rate": tax_rate,
		"happiness": happiness,
		"total_tax_revenue": total_tax_revenue,
		"allocation_reserve": allocation_reserve,
		"allocation_pool": allocation_pool,
		"regency_active": bool(
			institution.get(
				"regency_active",
				false
			)
		),
		"regent_id": int(
			institution.get(
				"regent_id",
				-1
			)
		),
		"succession_rank": int(
			actor.succession_rank
		),
		"succession_count": succession_ids.size(),
		"claimant_count": claimant_ids.size(),
		"court_count": court_member_ids.size(),
		"claimant_pressure": claimant_pressure,
		"royal_succession_tension": succession_tension,
		"coup_pressure": coup_pressure,
		"standing": standing,
		"alerts": alerts,
		"integrity_state": integrity_state,
	}

func constitutional_contract_for_actor(
	actor: Person
) -> Dictionary:
	if actor == null:
		return _default_constitutional_contract()

	if (
		gs != null
		and gs.royalty_engine != null
		and gs.royalty_engine.has_method(
			"get_succession_contract_for_ruler"
		)
	):
		var succession: Dictionary = _dict(
			gs.royalty_engine.get_succession_contract_for_ruler(
				actor
			)
		)

		if not succession.is_empty():
			var contract_id: String = str(
				succession.get(
					"id",
					"default.monarchy"
				)
			)

			if constitutional_contract_registry.has(
				contract_id
			):
				return _dict(
					constitutional_contract_registry.get(
						contract_id,
						{}
					)
				)

			return _normalize_constitutional_contract(
				contract_id,
				succession
			)

	return _default_constitutional_contract()


func self_heal(
	context: Dictionary = {}
) -> Dictionary:
	if _runtime() == null:
		return _fail(
			"missing_royalty_runtime",
			"RoyaltyRuntimeEngine is unavailable."
		)

	var runtime_report: Dictionary = (
		_runtime().repair_state(context)
	)

	if constitutional_contract_registry.is_empty():
		bootstrap_default_contracts()

	return {
		"success": bool(
			runtime_report.get(
				"success",
				false
			)
		),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"runtime_report": runtime_report,
		"constitutional_contract_count": (
			constitutional_contract_registry.size()
		)
	}


func export_state() -> Dictionary:
	return {
		"schema": (
			"eralife.royalty_contract_engine_state"
		),
		"version": ENGINE_VERSION,
		"constitutional_contract_registry": (
			constitutional_contract_registry.duplicate(true)
		),
		"realm_contract_index": (
			realm_contract_index.duplicate(true)
		),
		"last_report": last_report.duplicate(true),
		"exported_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	constitutional_contract_registry = _dict(
		data.get(
			"constitutional_contract_registry",
			{}
		)
	)
	realm_contract_index = _dict(
		data.get(
			"realm_contract_index",
			{}
		)
	)
	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)

	if constitutional_contract_registry.is_empty():
		bootstrap_default_contracts()

	return self_heal({
		"source": "royalty_contract_engine_import"
	})


func _resolve_royal_marriage(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	var target: Person = _person_by_id(
		int(
			payload.get(
				"target_id",
				payload.get(
					"partner_id",
					-1
				)
			)
		)
	)

	if target == null:
		return _fail(
			"missing_marriage_target",
			"No marriage target could be resolved."
		)

	if gs == null or gs.royalty_engine == null:
		return _fail(
			"missing_royalty_facade",
			"RoyaltyEngine is unavailable."
		)

	if actor.is_royal and not target.is_royal:
		gs.royalty_engine.marry_into_royalty(
			target,
			actor
		)
	elif target.is_royal and not actor.is_royal:
		gs.royalty_engine.marry_into_royalty(
			actor,
			target
		)
	else:
		return _fail(
			"royal_marriage_not_applicable",
			"The marriage does not introduce a new royal participant."
		)

	_runtime().ingest_actor(
		actor,
		{
			"source": "royal_marriage"
		}
	)
	_runtime().ingest_actor(
		target,
		{
			"source": "royal_marriage"
		}
	)
	_runtime().repair_state({
		"source": "royal_marriage"
	})

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "royal_marriage_committed",
		"actor_id": int(actor.id),
		"target_id": int(target.id),
		"text": "The marriage entered royalty institutional truth."
	}


func _resolve_claim_throne(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	var institution: Dictionary = (
		_runtime().institution_for_actor(actor)
	)
	var defender: Person = _person_by_id(
		int(
			payload.get(
				"defender_id",
				institution.get(
					"monarch_id",
					-1
				)
			)
		)
	)

	if defender == null:
		return _runtime().commit_coronation(
			actor,
			{
				"source": "vacant_throne_claim",
				"force_transition": true
			}
		)

	if (
		gs == null
		or gs.politics_engine == null
		or not gs.politics_engine.has_method(
			"attempt_coup"
		)
	):
		return _fail(
			"politics_engine_unavailable",
			"PoliticsEngine cannot resolve the throne claim."
		)

	var raw_result: Variant = (
		gs.politics_engine.attempt_coup(
			actor,
			defender
		)
	)

	_runtime().repair_state({
		"source": "claim_throne_resolution"
	})

	if typeof(raw_result) == TYPE_DICTIONARY:
		return (
			raw_result as Dictionary
		).duplicate(true)

	return {
		"success": bool(raw_result),
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "royal_throne_claim_resolved",
		"actor_id": int(actor.id),
		"defender_id": int(defender.id),
		"text": (
			"The throne claim succeeded."
			if bool(raw_result)
			else "The throne claim failed."
		)
	}


func _resolve_public_action(
	actor: Person,
	payload: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.royalty_engine == null
	):
		return _fail(
			"missing_royalty_facade",
			"RoyaltyEngine is unavailable."
		)

	var public_action: String = str(
		payload.get(
			"public_action",
			payload.get(
				"action",
				""
			)
		)
	).strip_edges().to_lower()

	var text: String = str(
		gs.royalty_engine.perform_public_action(
			actor,
			public_action
		)
	)

	_runtime().ingest_actor(
		actor,
		{
			"source": "royal_public_action"
		}
	)
	_runtime().repair_state({
		"source": "royal_public_action"
	})

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "royal_public_action_resolved",
		"public_action": public_action,
		"text": text
	}


func _normalize_constitutional_contract(
	contract_key: String,
	raw: Dictionary
) -> Dictionary:
	var contract_id: String = str(
		raw.get(
			"id",
			contract_key
		)
	).strip_edges()

	if contract_id == "":
		contract_id = "default.monarchy"

	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": contract_id,
		"display_name": str(
			raw.get(
				"display_name",
				"Monarchy"
			)
		),
		"succession": {
			"mode": str(
				raw.get(
					"succession_mode",
					"primogeniture"
				)
			),
			"direct_line_first": bool(
				raw.get(
					"direct_line_first",
					true
				)
			),
			"designated_heir_override": bool(
				raw.get(
					"designated_heir_override",
					true
				)
			),
			"single_active_ruler": bool(
				raw.get(
					"single_active_ruler",
					true
				)
			),
			"allow_deposed_claimants": bool(
				raw.get(
					"allow_deposed_claimants",
					false
				)
			),
			"gender_priority": _array(
				raw.get(
					"gender_priority",
					[]
				)
			),
			"weights": _dict(
				raw.get(
					"weights",
					{}
				)
			)
		},
		"legitimacy": {
			"approval_weight": 0.48,
			"fame_weight": 0.22,
			"scandal_inverse_weight": 0.14,
			"active_monarch_bonus": 16
		},
		"regency": {
			"allowed": true,
			"minimum_regent_age": 18,
		},
		"abdication": {
			"allowed": true,
		},
		"coronation": {
		},
		"jurisdiction": {
			"court": true,
			"dynasty": true,
			"realm": true,
			"ceremony": true,
			"royal_assets": true
		},
		"privileges": {
		},
		"metadata": {
			"legacy_contract_key": contract_key,
			"source": "royalty_engine_migration"
		}
	}


func _default_constitutional_contract() -> Dictionary:
	return _normalize_constitutional_contract(
		"default_monarchy",
		{
			"id": "default.monarchy.primogeniture",
			"display_name": "Primogeniture Monarchy",
			"succession_mode": "primogeniture",
			"direct_line_first": true,
			"designated_heir_override": true,
			"single_active_ruler": true,
			"allow_deposed_claimants": false,
			"gender_priority": [],
			"weights": {
				"designated_heir": 100000.0,
				"direct_child": 35000.0,
				"descendant": 18000.0,
				"age": 120.0,
				"approval": 2.0,
				"fame": 1.0,
				"smarts": 1.0,
				"willpower": 1.0
			}
		}
	)


func _runtime():
	if gs == null:
		return null

	return gs.royalty_runtime_engine


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

	if typeof(payload) != TYPE_DICTIONARY:
		if payload is Person:
			out.append(payload)
		return out

	var row: Dictionary = payload as Dictionary

	for key in [
		"actor",
		"target",
		"partner",
		"person_a",
		"person_b",
		"spouse_a",
		"spouse_b",
		"npc"
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
		"actor_id",
		"target_id",
		"partner_id",
		"person_a_id",
		"person_b_id",
		"npc_id"
	]:
		var actor: Person = _person_by_id(
			int(
				row.get(
					key,
					-1
				)
			)
		)

		if (
			actor != null
			and not seen.has(int(actor.id))
		):
			seen [int(actor.id)] = true
			out.append(actor)

	return out


func _house_id_for_actor(
	actor: Person
) -> String:
	if actor == null:
		return ""

	if _runtime() != null:
		return str(
			_runtime().house_for_actor(actor).get(
				"house_id",
				""
			)
		)

	return ""


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