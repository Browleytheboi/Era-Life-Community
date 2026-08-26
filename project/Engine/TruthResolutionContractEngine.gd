extends Resource
class_name TruthResolutionContractEngine

const ENGINE_SCHEMA:= "eralife.truth_resolution_contract_engine"
const CONTRACT_VERSION:= 1

const US_CABINET_TARGET:= 15
const US_SENATE_TARGET:= 100
const US_SUPREME_COURT_TARGET:= 9
const US_GOVERNOR_TARGET:= 50
const US_CITIZEN_TARGET:= 200
const GENERIC_REALM_CITIZEN_TARGET:= 60
const GENERIC_REALM_ROYAL_COURT_TARGET:= 6
const GENERIC_REALM_NOBLE_COURT_TARGET:= 8
const GENERIC_REALM_EXECUTIVE_TARGET:= 6
const GENERIC_REALM_LEGISLATIVE_TARGET:= 12
const GENERIC_REALM_JUDICIAL_TARGET:= 5
const GENERIC_REALM_MILITARY_COMMAND_TARGET:= 6
const GENERIC_REALM_MASTER_TARGET:= 6
var gs = null
var truth_by_realm_key: Dictionary = {}
var last_report: Dictionary = {}
var bulk_resolution_depth: int = 0


func _init(_gs = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs) -> void:
		gs = _gs

		if (
			gs != null
			and gs.event_bus != null
		):
			gs.event_bus.subscribe(
				ActionEventTypes.NPC_DIED,
				self,
				"_on_population_government_officeholder_died",
				{
					"lane": "important",
					"allow_defer": true,
					"force_immediate": false,
					"subscription_priority": 38,
					"subscription_id": (
						"truth_resolution_"
						+ "federal_office_reconciliation"
					),
					"replay_on_subscribe": false
				}
			)

		_commit_registry()
func _on_population_government_officeholder_died(
		payload: Dictionary = {}
) -> void:
		var data_raw: Variant = payload.get(
			"data",
			{}
		)
		var data: Dictionary = (
			data_raw as Dictionary
			if typeof(data_raw) == TYPE_DICTIONARY
			else {}
		)
		var deceased_id: int = int(
			payload.get(
				"npc_id",
				data.get(
					"npc_id",
					-1
				)
			)
		)

		if deceased_id <= 0:
			return

		call_deferred(
			"_reconcile_united_states_supreme_court_after_death",
			deceased_id
		)


func _truth_supreme_court_node_is_chief(
		node: Dictionary
) -> bool:
		if node.is_empty():
			return false

		var office_raw: Variant = node.get(
			"civic_office_contract",
			{}
		)
		var office: Dictionary = (
			office_raw as Dictionary
			if typeof(office_raw) == TYPE_DICTIONARY
			else {}
		)
		var combined: String = (
			"%s|%s|%s|%s"
			% [
				str(node.get("job", "")),
				str(node.get("civic_title", "")),
				str(
					office.get(
						"role_label",
						""
					)
				),
				str(
					office.get(
						"office",
						""
					)
				)
			]
		).strip_edges().to_lower()

		return (
			combined.find(
				"chief justice"
			) >= 0
			or combined.find(
				"chief_justice"
			) >= 0
		)


func _truth_promote_supreme_court_node_to_chief(
		node: Dictionary
) -> Dictionary:
		var out: Dictionary = node.duplicate(true)
		var office_raw: Variant = out.get(
			"civic_office_contract",
			{}
		)
		var office: Dictionary = (
			(office_raw as Dictionary).duplicate(true)
			if typeof(office_raw) == TYPE_DICTIONARY
			else {}
		)

		out ["job"] = "Chief Justice"
		out ["civic_title"] = "Chief Justice"
		out ["role_label"] = "Chief Justice"
		out ["is_chief_justice"] = true

		office ["role_label"] = "Chief Justice"
		office ["office"] = _office_key_for_role(
			"Chief Justice",
			"judicial"
		)
		office ["branch"] = "judicial"
		office [
			"supreme_court_chief_office"
		] = true
		office [
			"truth_resolution_source"
		] = true

		out [
			"civic_office_contract"
		] = office

		return out


func _next_united_states_supreme_court_replacement_id(
		realm_id: int,
		packet: Dictionary
) -> int:
		var ordinal: int = (
			int(
				packet.get(
					"supreme_court_replacement_ordinal",
					0
				)
			) + 1
		)
		var existing_ids: Dictionary = {}
		var all_nodes_raw: Variant = packet.get(
			"all_nodes",
			[]
		)
		var all_nodes: Array = (
			all_nodes_raw as Array
			if typeof(all_nodes_raw) == TYPE_ARRAY
			else []
		)

		for raw_node in all_nodes:
			if typeof(raw_node) != TYPE_DICTIONARY:
				continue

			var node: Dictionary = (
				raw_node as Dictionary
			)
			var node_id: int = int(
				node.get(
					"id",
					-1
				)
			)

			if node_id > 0:
				existing_ids [node_id] = true

		var candidate: int = (
			900000000
			+ (realm_id * 100000)
			+ ordinal
		)

		while (
			existing_ids.has(candidate)
			or _person_by_id_safe(candidate) != null
		):
			ordinal += 1
			candidate = (
				900000000
				+ (realm_id * 100000)
				+ ordinal
			)

		packet [
			"supreme_court_replacement_ordinal"
		] = ordinal

		return candidate


func _reconcile_united_states_supreme_court_after_death(
		deceased_id: int
) -> void:
		if (
			gs == null
			or deceased_id <= 0
		):
			return

		for raw_key in truth_by_realm_key.keys():
			var packet_raw: Variant = (
				truth_by_realm_key.get(
					raw_key,
					{}
				)
			)

			if typeof(packet_raw) != TYPE_DICTIONARY:
				continue

			var packet: Dictionary = (
				(packet_raw as Dictionary).duplicate(true)
			)
			var government_model: String = str(
				packet.get(
					"government_model",
					""
				)
			).strip_edges().to_lower()

			if government_model != (
				"federal_presidential_republic"
			):
				continue

			var groups_raw: Variant = packet.get(
				"groups",
				{}
			)
			var groups: Dictionary = (
				(groups_raw as Dictionary).duplicate(true)
				if typeof(groups_raw) == TYPE_DICTIONARY
				else {}
			)
			var court_raw: Variant = groups.get(
				"supreme_court",
				[]
			)
			var court: Array = (
				(court_raw as Array).duplicate(true)
				if typeof(court_raw) == TYPE_ARRAY
				else []
			)
			var deceased_was_court_member: bool = false

			for raw_node in court:
				if typeof(raw_node) != TYPE_DICTIONARY:
					continue

				if int(
					(raw_node as Dictionary).get(
						"id",
						-1
					)
				) == deceased_id:
					deceased_was_court_member = true
					break

			if not deceased_was_court_member:
				continue

			var living_court: Array = []

			for raw_node in court:
				if typeof(raw_node) != TYPE_DICTIONARY:
					continue

				var node: Dictionary = (
					(raw_node as Dictionary).duplicate(true)
				)
				var node_id: int = int(
					node.get(
						"id",
						-1
					)
				)

				if (
					node_id <= 0
					or node_id == deceased_id
					or not bool(
						node.get(
							"alive",
							true
						)
					)
				):
					continue

				var runtime_person = (
					_person_by_id_safe(
						node_id
					)
				)

				if (
					runtime_person != null
					and not bool(
						_value(
							runtime_person,
							"alive",
							true
						)
					)
				):
					continue

				living_court.append(
					node
				)

			var chief_index: int = -1

			for i in range(
				living_court.size()
			):
				var node: Dictionary = (
					living_court [i]
				)

				if _truth_supreme_court_node_is_chief(
					node
				):
					chief_index = i
					break

			if (
				chief_index < 0
				and not living_court.is_empty()
			):
				living_court [
					0
				] = (
					_truth_promote_supreme_court_node_to_chief(
						living_court [0]
					)
				)
				chief_index = 0

			var realm_id: int = int(
				packet.get(
					"realm_id",
					-1
				)
			)
			var realm_name: String = str(
				packet.get(
					"realm_name",
					"United States"
				)
			).strip_edges()

			while living_court.size() < (
				US_SUPREME_COURT_TARGET
			):
				var replacement_id: int = (
					_next_united_states_supreme_court_replacement_id(
						realm_id,
						packet
					)
				)
				var needs_chief: bool = (
					living_court.is_empty()
					and chief_index < 0
				)
				var replacement_title: String = (
					"Chief Justice"
					if needs_chief
					else "Supreme Court Justice"
				)
				var replacement: Dictionary = (
					_make_truth_person(
						realm_id,
						realm_name,
						replacement_id,
						replacement_title,
						"judicial",
						"",
						"",
						45 + int(
							packet.get(
								"supreme_court_replacement_ordinal",
								0
							) % 24
						)
					)
				)

				replacement [
					"is_chief_justice"
				] = needs_chief
				replacement [
					"supreme_court_replacement"
				] = true
				replacement [
					"supreme_court_replacement_for_person_id"
				] = deceased_id

				living_court.append(
					replacement
				)

				if needs_chief:
					chief_index = (
						living_court.size() - 1
					)

			groups [
				"supreme_court"
			] = living_court
			packet ["groups"] = groups
			packet [
				"last_supreme_court_vacancy_person_id"
			] = deceased_id
			packet [
				"last_supreme_court_reconciliation_at_ms"
			] = int(
				Time.get_ticks_msec()
			)
			packet [
				"supreme_court_target"
			] = US_SUPREME_COURT_TARGET
			packet [
				"supreme_court_single_chief_required"
			] = true

			_refresh_truth_packet_counts(
				packet
			)

			truth_by_realm_key [
				str(raw_key)
			] = packet

			_seal_united_states_truth_to_realm_and_scenario(
				realm_id,
				realm_name,
				packet
			)



			_materialize_truth_nodes_as_runtime_people({
				"all_nodes": (
					living_court.duplicate(true)
				)
			})

			_ingest_truth_nodes_into_global_node_engine(
				realm_id,
				realm_name,
				{
					"all_nodes": (
						living_court.duplicate(true)
					)
				},
				{
					"source": (
						"truth_resolution_contract_engine."
						+ "supreme_court_vacancy_reconciliation"
					),
					"background_reconciliation": true,
					"ui_is_renderer_only": true
				}
			)

			_project_truth_packet_to_population_card_engine(
				realm_id,
				realm_name,
				packet,
				{
					"source": (
						"truth_resolution_contract_engine."
						+ "supreme_court_vacancy_projection"
					),
					"surface_already_exists": true,
					"background_reconciliation": true,
					"ready_door_may_not_wait": true,
					"ui_is_renderer_only": true
				}
			)

			last_report = {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"version": CONTRACT_VERSION,
				"reason": (
					"supreme_court_vacancy_reconciled"
				),
				"realm_id": realm_id,
				"realm_name": realm_name,
				"deceased_id": deceased_id,
				"supreme_court_count": (
					living_court.size()
				),
				"chief_index": chief_index,
				"background_reconciliation": true,
				"ui_is_renderer_only": true,
				"at_ms": int(
					Time.get_ticks_msec()
				)
			}

			_commit_registry()
			return

func reset_runtime() -> void:
	truth_by_realm_key.clear()
	last_report.clear()
	bulk_resolution_depth = 0

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state [
			"truth_resolution_contract_engine_runtime_reset"
		] = true
		gs.scenario_state [
			"truth_resolution_contract_engine_runtime_reset_at_ms"
		] = int(Time.get_ticks_msec())
func _truth_current_era_name() -> String:
	if gs == null:
		return "Modern Era"

	var era_value: Variant = _value(
		gs,
		"era",
		null
	)
	var direct_name: String = ""

	if typeof(era_value) == TYPE_STRING:
		direct_name = str(
			era_value
		).strip_edges()
	else:
		direct_name = str(
			_value(
				era_value,
				"name",
				""
			)
		).strip_edges()

	if (
		direct_name != ""
		and direct_name != "<null>"
	):
		return direct_name

	var settings_raw: Variant = _value(
		gs,
		"custom_settings",
		{}
	)

	if typeof(settings_raw) == TYPE_DICTIONARY:
		var configured_name: String = str(
			(settings_raw as Dictionary).get(
				"era_name",
				""
			)
		).strip_edges()

		if configured_name != "":
			return configured_name

	return "Modern Era"


func _truth_realm_dictionary(
	realm_id: int
) -> Dictionary:
	if (
		gs == null
		or gs.realm_engine == null
	):
		return {}

	var realms_raw: Variant = (
		gs.realm_engine.get(
			"realms"
		)
	)

	if typeof(realms_raw) != TYPE_DICTIONARY:
		return {}

	var realms: Dictionary = (
		realms_raw as Dictionary
	)
	var realm_raw: Variant = realms.get(
		realm_id,
		realms.get(
			str(realm_id),
			{}
		)
	)

	if typeof(realm_raw) != TYPE_DICTIONARY:
		return {}

	return realm_raw as Dictionary


func _truth_realm_city_pool(
	realm_id: int,
	realm_name: String
) -> Array:
	var realm: Dictionary = (
		_truth_realm_dictionary(
			realm_id
		)
	)
	var cities: Array = []
	var capital_city: String = str(
		realm.get(
			"capital_city",
			""
		)
	).strip_edges()

	if capital_city != "":
		cities.append(
			capital_city
		)

	for raw_key in [
		"subzones",
		"cities",
		"city_names",
		"major_cities"
	]:
		var rows_raw: Variant = realm.get(
			str(raw_key),
			[]
		)

		if typeof(rows_raw) != TYPE_ARRAY:
			continue

		for raw_city in rows_raw as Array:
			var city: String = str(
				raw_city
			).strip_edges()

			if (
				city != ""
				and city not in cities
			):
				cities.append(
					city
				)

	if cities.is_empty():
		var fallback_name: String = str(
			realm_name
		).strip_edges()

		if fallback_name == "":
			fallback_name = (
				"Realm %d"
				% realm_id
			)

		cities.append(
			fallback_name
		)

	return cities


func _truth_stable_pool_value(
	values: Array,
	seed_text: String,
	fallback: String
) -> String:
	if values.is_empty():
		return fallback

	var index: int = posmod(
		int(
			hash(
				seed_text
			)
		),
		values.size()
	)

	return str(
		values [index]
	).strip_edges()


func _truth_name_pool_for_era(
	era_name: String,
	gender: String,
	last_name_pool: bool = false
) -> Array:
	if (
		gs == null
		or gs.names_db == null
	):
		return []

	var male: bool = gender == "Male"
	var pool_key: String = "last_names"

	match era_name:
		"Ancient Era":
			pool_key = (
				"ancient_last"
				if last_name_pool
				else (
					"ancient_male"
					if male
					else "ancient_female"
				)
			)

		"Medieval Era":
			pool_key = (
				"medieval_last"
				if last_name_pool
				else (
					"medieval_male"
					if male
					else "medieval_female"
				)
			)

		"Industrial Era":
			pool_key = (
				"industrial_last"
				if last_name_pool
				else (
					"industrial_male"
					if male
					else "industrial_female"
				)
			)

		"Future Era":
			pool_key = (
				"future_last"
				if last_name_pool
				else (
					"future_male"
					if male
					else "future_female"
				)
			)

		_:
			pool_key = (
				"last_names"
				if last_name_pool
				else (
					"male_first"
					if male
					else "female_first"
				)
			)

	var pool_raw: Variant = (
		gs.names_db.get(
			pool_key
		)
	)

	if typeof(pool_raw) != TYPE_ARRAY:
		return []

	return pool_raw as Array


func _truth_identity_for_realm(
	realm_id: int,
	realm_name: String,
	person_id: int,
	index: int
) -> Dictionary:
	var era_name: String = (
		_truth_current_era_name()
	)
	var gender: String = (
		"Female"
		if posmod(
			person_id,
			2
		) == 1
		else "Male"
	)
	var city_pool: Array = (
		_truth_realm_city_pool(
			realm_id,
			realm_name
		)
	)
	var city: String = (
		_truth_stable_pool_value(
			city_pool,
			"%d:%d:city"
			% [
				person_id,
				index
			],
			str(
				realm_name
			)
		)
	)
	var first_name: String = (
		_truth_stable_pool_value(
			_truth_name_pool_for_era(
				era_name,
				gender,
				false
			),
			"%d:%d:first"
			% [
				person_id,
				index
			],
			"Resident"
		)
	)
	var last_name: String = ""

	if era_name == "Ancient Era":
		if (
			gs != null
			and gs.names_db != null
			and gs.names_db.has_method(
				"ancient_locative_last_name"
			)
		):
			last_name = str(
				gs.names_db.ancient_locative_last_name(
					city,
					realm_name
				)
			).strip_edges()
		else:
			last_name = (
				"of %s"
				% city
			)
	else:
		last_name = (
			_truth_stable_pool_value(
				_truth_name_pool_for_era(
					era_name,
					gender,
					true
				),
				"%d:%d:last"
				% [
					person_id,
					index
				],
				"of %s" % city
			)
		)

	return {
		"first_name": first_name,
		"last_name": last_name,
		"display_name": (
			"%s %s"
			% [
				first_name,
				last_name
			]
		).strip_edges(),
		"gender": gender,
		"city": city,
		"era_name": era_name
	}
func _generic_realm_government_profile(
	realm_id: int,
	realm_name: String
) -> Dictionary:
	var realm: Dictionary = (
		_truth_realm_dictionary(
			realm_id
		)
	)
	var government_style: String = str(
		realm.get(
			"government_style",
			realm.get(
				"government_model",
				"Monarchy"
			)
		)
	).strip_edges()
	var realm_kind: String = str(
		realm.get(
			"realm_kind",
			"state"
		)
	).strip_edges()
	var lower_truth: String = (
		"%s %s %s"
		% [
			government_style,
			realm_kind,
			realm_name
		]
	).to_lower()
	var government_model: String = "monarchy"

	if lower_truth.find(
		"constitutional monarchy"
	) >= 0:
		government_model = (
			"constitutional_monarchy"
		)
	elif (
		lower_truth.find("republic") >= 0
		or lower_truth.find("democracy") >= 0
		or lower_truth.find("federal") >= 0
	):
		government_model = "republic"
	elif lower_truth.find("empire") >= 0:
		government_model = "empire"
	elif (
		lower_truth.find("theocracy") >= 0
		or lower_truth.find(
			"temple state"
		) >= 0
	):
		government_model = "theocracy"
	elif (
		lower_truth.find("council") >= 0
		or lower_truth.find("tribe") >= 0
		or lower_truth.find("nomad") >= 0
		or lower_truth.find("temple") >= 0
	):
		government_model = "council"

	var section_titles: Dictionary = {}
	var section_subtitles: Dictionary = {}

	match government_model:
		"constitutional_monarchy":
			section_titles = {
				"sovereign": "THE CROWN",
				"royal_court": "ROYAL HOUSE",
				"noble_court": "NOBLE COURT",
				"executive": "EXECUTIVE MINISTRY",
				"legislative": "PARLIAMENT",
				"judicial": "HIGH JUDICIARY",
				"military_command": "DEFENSE COMMAND"
			}
			section_subtitles = {
				"sovereign": (
					"The constitutional sovereign and Crown office."
				),
				"royal_court": (
					"The royal family and household offices."
				),
				"noble_court": (
					"Titled houses and peerage authorities."
				),
				"executive": (
					"Ministers administering the elected government."
				),
				"legislative": (
					"Members of parliament and legislative chambers."
				),
				"judicial": (
					"Judges responsible for constitutional law."
				),
				"military_command": (
					"Commanders responsible for national defense."
				)
			}

		"empire":
			section_titles = {
				"sovereign": "IMPERIAL THRONE",
				"royal_court": "IMPERIAL COURT",
				"noble_court": "IMPERIAL NOBILITY",
				"executive": "IMPERIAL COUNCIL",
				"judicial": "IMPERIAL JUDICIARY",
				"military_command": "IMPERIAL HIGH COMMAND"
			}
			section_subtitles = {
				"sovereign": (
					"The emperor or empress holding imperial sovereignty."
				),
				"royal_court": (
					"The imperial household, heirs, and palace offices."
				),
				"noble_court": (
					"Provincial dynasties and titled imperial houses."
				),
				"executive": (
					"Ministers and governors administering the empire."
				),
				"judicial": (
					"Imperial judges and provincial magistrates."
				),
				"military_command": (
					"Generals, admirals, and frontier commanders."
				)
			}

		"theocracy":
			section_titles = {
				"sovereign": "SUPREME RELIGIOUS OFFICE",
				"royal_court": "HIGH CLERGY",
				"executive": "TEMPLE COUNCIL",
				"judicial": "SACRED TRIBUNAL",
				"military_command": "TEMPLE GUARD COMMAND"
			}
			section_subtitles = {
				"sovereign": (
					"The highest spiritual and temporal authority."
				),
				"royal_court": (
					"High priests, priestesses, and sacred offices."
				),
				"executive": (
					"The council administering temple-state affairs."
				),
				"judicial": (
					"Interpreters and enforcers of sacred law."
				),
				"military_command": (
					"Commanders responsible for temple defense."
				)
			}

		"republic":
			section_titles = {
				"executive": "EXECUTIVE BRANCH",
				"legislative": "LEGISLATIVE BRANCH",
				"judicial": "JUDICIAL BRANCH",
				"military_command": "MILITARY COMMAND"
			}
			section_subtitles = {
				"executive": (
					"The realm's executive offices and ministers."
				),
				"legislative": (
					"Senators, delegates, assembly members, and lawmakers."
				),
				"judicial": (
					"Judges, magistrates, and constitutional interpreters."
				),
				"military_command": (
					"Commanders responsible for organized defense."
				)
			}

		"council":
			section_titles = {
				"executive": "GOVERNING COUNCIL",
				"legislative": "COUNCIL ASSEMBLY",
				"judicial": "REALM TRIBUNAL",
				"military_command": "DEFENSE COMMAND"
			}
			section_subtitles = {
				"executive": (
					"Elders, chiefs, abbots, and governing councilors."
				),
				"legislative": (
					"The wider council that debates realm policy."
				),
				"judicial": (
					"Arbiters and keepers of customary law."
				),
				"military_command": (
					"Guardians and commanders of the realm."
				)
			}

		_:
			section_titles = {
				"sovereign": "SOVEREIGN",
				"royal_court": "ROYAL COURT",
				"noble_court": "NOBLE COURT",
				"executive": "CROWN COUNCIL",
				"judicial": "ROYAL JUDICIARY",
				"military_command": "ROYAL MILITARY COMMAND"
			}
			section_subtitles = {
				"sovereign": (
					"The ruler holding the realm's sovereign office."
				),
				"royal_court": (
					"The sovereign, consort, heirs, and royal household offices."
				),
				"noble_court": (
					"High houses and titled territorial authorities."
				),
				"executive": (
					"Ministers and officers administering the sovereign's realm."
				),
				"judicial": (
					"Judges and magistrates exercising the realm's law."
				),
				"military_command": (
					"Generals, marshals, admirals, and guard commanders."
				)
			}

	var element: String = str(
		realm.get(
			"native_element",
			realm.get(
				"element",
				""
			)
		)
	).strip_edges().to_lower()

	return {
		"realm_id": realm_id,
		"realm_name": realm_name,
		"government_model": government_model,
		"government_style": government_style,
		"realm_kind": realm_kind,
		"element": element,
		"elemental_realm": (
			bool(
				realm.get(
					"elemental_realm",
					false
				)
			)
			or element != ""
		),
		"capital_city": str(
			realm.get(
				"capital_city",
				""
			)
		),
		"city_pool": (
			_truth_realm_city_pool(
				realm_id,
				realm_name
			)
		),
		"leader_identity_contract": (
			realm.get(
				"leader_identity_contract",
				{}
			)
			if typeof(
				realm.get(
					"leader_identity_contract",
					{}
				)
			) == TYPE_DICTIONARY
			else {}
		),
		"section_titles": section_titles,
		"section_subtitles": section_subtitles,
		"era_name": _truth_current_era_name(),
		"ui_is_renderer_only": true
	}
func _append_population_truth_plan_range(
	out: Array,
	shard_kind: String,
	total: int,
	chunk_size: int,
	section_title: String = ""
) -> void:
	var safe_chunk: int = maxi(
		1,
		chunk_size
	)

	for start_index in range(
		0,
		maxi(
			0,
			total
		),
		safe_chunk
	):
		out.append({
			"shard_kind": shard_kind,
			"start_index": start_index,
			"count": mini(
				safe_chunk,
				total - start_index
			),
			"section_title": section_title
		})


func emit_population_truth_shard_plan(
	realm_id: int,
	realm_name: String,
	_context: Dictionary = {}
) -> Array:
	var out: Array = []

	if _is_united_states_realm(
		realm_id,
		realm_name
	):
		_append_population_truth_plan_range(
			out,
			"executive",
			1,
			1,
			"EXECUTIVE OFFICE"
		)
		_append_population_truth_plan_range(
			out,
			"cabinet",
			US_CABINET_TARGET,
			3,
			"PRESIDENT'S CABINET"
		)
		_append_population_truth_plan_range(
			out,
			"supreme_court",
			US_SUPREME_COURT_TARGET,
			3,
			"SUPREME COURT"
		)
		_append_population_truth_plan_range(
			out,
			"senate",
			US_SENATE_TARGET,
			5,
			"SENATE"
		)
		_append_population_truth_plan_range(
			out,
			"governors",
			US_GOVERNOR_TARGET,
			5,
			"STATE GOVERNORS"
		)
		_append_population_truth_plan_range(
			out,
			"citizens",
			US_CITIZEN_TARGET,
			10,
			"CIVILIAN SOCIAL CLASSES"
		)

		return out

	var profile: Dictionary = (
		_generic_realm_government_profile(
			realm_id,
			realm_name
		)
	)
	var model: String = str(
		profile.get(
			"government_model",
			"monarchy"
		)
	)
	var titles: Dictionary = (
		profile.get(
			"section_titles",
			{}
		) as Dictionary
	)

	match model:
		"republic":
			_append_population_truth_plan_range(
				out,
				"executive",
				GENERIC_REALM_EXECUTIVE_TARGET,
				3,
				str(
					titles.get(
						"executive",
						"EXECUTIVE BRANCH"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"legislative",
				GENERIC_REALM_LEGISLATIVE_TARGET,
				4,
				str(
					titles.get(
						"legislative",
						"LEGISLATIVE BRANCH"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"judicial",
				GENERIC_REALM_JUDICIAL_TARGET,
				3,
				str(
					titles.get(
						"judicial",
						"JUDICIAL BRANCH"
					)
				)
			)

		"constitutional_monarchy":
			_append_population_truth_plan_range(
				out,
				"sovereign",
				1,
				1,
				str(
					titles.get(
						"sovereign",
						"THE CROWN"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"royal_court",
				4,
				2,
				str(
					titles.get(
						"royal_court",
						"ROYAL HOUSE"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"noble_court",
				6,
				3,
				str(
					titles.get(
						"noble_court",
						"NOBLE COURT"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"executive",
				GENERIC_REALM_EXECUTIVE_TARGET,
				3,
				str(
					titles.get(
						"executive",
						"EXECUTIVE MINISTRY"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"legislative",
				GENERIC_REALM_LEGISLATIVE_TARGET,
				4,
				str(
					titles.get(
						"legislative",
						"PARLIAMENT"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"judicial",
				GENERIC_REALM_JUDICIAL_TARGET,
				3,
				str(
					titles.get(
						"judicial",
						"HIGH JUDICIARY"
					)
				)
			)

		"theocracy":
			_append_population_truth_plan_range(
				out,
				"sovereign",
				1,
				1,
				str(
					titles.get(
						"sovereign",
						"SUPREME RELIGIOUS OFFICE"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"royal_court",
				6,
				3,
				str(
					titles.get(
						"royal_court",
						"HIGH CLERGY"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"executive",
				6,
				3,
				str(
					titles.get(
						"executive",
						"TEMPLE COUNCIL"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"judicial",
				4,
				2,
				str(
					titles.get(
						"judicial",
						"SACRED TRIBUNAL"
					)
				)
			)

		"empire":
			_append_population_truth_plan_range(
				out,
				"sovereign",
				1,
				1,
				str(
					titles.get(
						"sovereign",
						"IMPERIAL THRONE"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"royal_court",
				GENERIC_REALM_ROYAL_COURT_TARGET,
				3,
				str(
					titles.get(
						"royal_court",
						"IMPERIAL COURT"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"noble_court",
				GENERIC_REALM_NOBLE_COURT_TARGET,
				4,
				str(
					titles.get(
						"noble_court",
						"IMPERIAL NOBILITY"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"executive",
				GENERIC_REALM_EXECUTIVE_TARGET,
				3,
				str(
					titles.get(
						"executive",
						"IMPERIAL COUNCIL"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"judicial",
				5,
				3,
				str(
					titles.get(
						"judicial",
						"IMPERIAL JUDICIARY"
					)
				)
			)

		"council":
			_append_population_truth_plan_range(
				out,
				"executive",
				8,
				4,
				str(
					titles.get(
						"executive",
						"GOVERNING COUNCIL"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"legislative",
				8,
				4,
				str(
					titles.get(
						"legislative",
						"COUNCIL ASSEMBLY"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"judicial",
				4,
				2,
				str(
					titles.get(
						"judicial",
						"REALM TRIBUNAL"
					)
				)
			)

		_:
			_append_population_truth_plan_range(
				out,
				"sovereign",
				1,
				1,
				"SOVEREIGN"
			)
			_append_population_truth_plan_range(
				out,
				"royal_court",
				GENERIC_REALM_ROYAL_COURT_TARGET,
				3,
				str(
					titles.get(
						"royal_court",
						"ROYAL COURT"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"noble_court",
				GENERIC_REALM_NOBLE_COURT_TARGET,
				4,
				str(
					titles.get(
						"noble_court",
						"NOBLE COURT"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"executive",
				GENERIC_REALM_EXECUTIVE_TARGET,
				3,
				str(
					titles.get(
						"executive",
						"CROWN COUNCIL"
					)
				)
			)
			_append_population_truth_plan_range(
				out,
				"judicial",
				4,
				2,
				str(
					titles.get(
						"judicial",
						"ROYAL JUDICIARY"
					)
				)
			)

	_append_population_truth_plan_range(
		out,
		"military_command",
		GENERIC_REALM_MILITARY_COMMAND_TARGET,
		3,
		str(
			titles.get(
				"military_command",
				"MILITARY COMMAND"
			)
		)
	)

	if bool(
		profile.get(
			"elemental_realm",
			false
		)
	):
		_append_population_truth_plan_range(
			out,
			"masters",
			GENERIC_REALM_MASTER_TARGET,
			3,
			"BENDING MASTERS"
		)

	_append_population_truth_plan_range(
		out,
		"citizens",
		GENERIC_REALM_CITIZEN_TARGET,
		10,
		"CIVILIAN SOCIAL CLASSES"
	)

	return out
func resolve_population_and_government_truth_for_realms(realm_ids: Array = [], context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return _fail("missing_game_state", context)

	var ids: Array = _resolve_realm_ids(realm_ids)
	var should_shard: bool = bool(context.get("background_truth_resolution", false)) \
or bool(context.get("truth_may_complete_after_observation", false)) \
or bool(context.get("surface_already_exists", false)) \
or bool(context.get("ready_door_may_not_wait", false)) \
or bool(context.get("ontology_only_ready_gate", false)) \
or bool(context.get("skip_runtime_materialization", false))

	if should_shard and gs.population_shard_engine != null and gs.population_shard_engine.has_method("enqueue_truth_resolution_shards_for_realm"):
		var queued: Array = []
		var failed_queue: Array = []

		for raw_realm_id in ids:
			var realm_id: int = int(raw_realm_id)
			if realm_id <= 0:
				continue

			var realm_name: String = _realm_name_for_id(realm_id)
			var queue_report: Dictionary = gs.population_shard_engine.enqueue_truth_resolution_shards_for_realm(
				realm_id,
				realm_name,
				{
					"source": str(context.get("source", "truth_resolution_sharded_request")),
					"truth_may_complete_after_observation": true,
					"surface_already_exists": true,
					"ready_door_may_not_wait": true,
					"ui_is_renderer_only": true
				}.merged(context, true)
			)

			if bool(queue_report.get("success", false)):
				queued.append({
					"realm_id": realm_id,
					"realm_name": realm_name,
					"queued_count": int(queue_report.get("queued_count", 0))
				})
			else:
				failed_queue.append({
					"realm_id": realm_id,
					"realm_name": realm_name,
					"reason": str(queue_report.get("reason", "shard_queue_failed"))
				})

		last_report = {
			"success": failed_queue.is_empty(),
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"reason": "truth_resolution_shards_queued" if failed_queue.is_empty() else "truth_resolution_shard_queue_failures",
			"queued": queued.duplicate(true),
			"failed": failed_queue.duplicate(true),
			"ready_door_may_not_wait": true,
			"ui_is_renderer_only": true,
			"at_ms": int(Time.get_ticks_msec())
		}

		_commit_registry()
		return last_report.duplicate(true)

	var resolved: Array = []
	var failed: Array = []

	bulk_resolution_depth += 1

	for raw_realm_id in ids:
		var realm_id: int = int(raw_realm_id)
		if realm_id <= 0:
			continue

		var realm_name: String = _realm_name_for_id(realm_id)
		var result: Dictionary = {}

		if _is_united_states_realm(realm_id, realm_name):
			result = _resolve_united_states_population_and_government_truth(realm_id, realm_name, context)
		else:
			result = _resolve_generic_realm_population_truth(realm_id, realm_name, context)

		if bool(result.get("success", false)):
			resolved.append(realm_id)
		else:
			failed.append({
				"realm_id": realm_id,
				"realm_name": realm_name,
				"reason": str(result.get("reason", "truth_resolution_failed"))
			})

	bulk_resolution_depth = maxi(0, bulk_resolution_depth - 1)

	last_report = {
		"success": failed.is_empty(),
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"reason": "population_and_government_truth_resolved" if failed.is_empty() else "population_and_government_truth_failures",
		"resolved": resolved.duplicate(true),
		"failed": failed.duplicate(true),
		"resolved_count": resolved.size(),
		"failed_count": failed.size(),
		"ready_gate_truth_complete": failed.is_empty(),
		"ui_is_renderer_only": true,
		"at_ms": int(Time.get_ticks_msec())
	}

	_commit_registry()
	return last_report.duplicate(true)
func resolve_population_government_truth_shard(
	realm_id: int,
	realm_name: String,
	shard: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if gs == null:
		return _fail("missing_game_state", context)

	if realm_id <= 0:
		return {
			"success": false,
			"reason": "invalid_realm_id",
			"schema": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	var resolved_name: String = str(realm_name).strip_edges()
	if resolved_name == "":
		resolved_name = _realm_name_for_id(realm_id)

	if _is_united_states_realm(realm_id, resolved_name):
		return _resolve_united_states_population_government_truth_shard(
			realm_id,
			resolved_name,
			shard,
			context
		)

	return _resolve_generic_population_truth_shard(
		realm_id,
		resolved_name,
		shard,
		context
	)


func _resolve_united_states_population_government_truth_shard(
		realm_id: int,
		realm_name: String,
		shard: Dictionary,
		context: Dictionary = {}
) -> Dictionary:
		var packet: Dictionary = (
			_ensure_population_government_truth_packet_shell(
				realm_id,
				realm_name,
				true
			)
		)
		var groups: Dictionary = (
			packet.get(
				"groups",
				{}
			)
			if typeof(
				packet.get(
					"groups",
					{}
				)
			) == TYPE_DICTIONARY
			else {}
		)

		var shard_kind: String = str(
			shard.get(
				"shard_kind",
				""
			)
		).strip_edges().to_lower()
		var start_index: int = int(
			shard.get(
				"start_index",
				0
			)
		)
		var count: int = maxi(
			0,
			int(
				shard.get(
					"count",
					0
				)
			)
		)

		match shard_kind:
			"executive":
				_resolve_us_executive_truth_shard(
					groups,
					realm_id,
					realm_name
				)

			"cabinet":
				_resolve_us_cabinet_truth_shard(
					groups,
					realm_id,
					realm_name,
					start_index,
					count
				)

			"senate":
				_resolve_us_senate_truth_shard(
					groups,
					realm_id,
					realm_name,
					start_index,
					count
				)

			"supreme_court":
				_resolve_us_supreme_court_truth_shard(
					groups,
					realm_id,
					realm_name,
					start_index,
					count
				)

			"governors":
				_resolve_us_governor_truth_shard(
					groups,
					realm_id,
					realm_name,
					start_index,
					count
				)

			"citizens":
				_resolve_citizen_truth_shard(
					groups,
					realm_id,
					realm_name,
					start_index,
					count
				)

			_:
				return {
					"success": false,
					"reason": "unknown_truth_shard_kind",
					"schema": ENGINE_SCHEMA,
					"realm_id": realm_id,
					"realm_name": realm_name,
					"shard": shard.duplicate(true),
					"ui_is_renderer_only": true
				}

		var senate_phase_complete: bool = (
			shard_kind in [
				"governors",
				"citizens"
			]
			or (
				shard_kind == "senate"
				and (
					start_index + count
				) >= US_SENATE_TARGET
			)
		)

		if senate_phase_complete:
			_reconcile_united_states_senate_cardinality(
				groups,
				realm_id,
				realm_name
			)

		packet ["groups"] = groups

		_refresh_truth_packet_counts(
			packet
		)
		_seal_united_states_leader_truth_only(
			realm_id,
			realm_name,
			packet
		)

		if bool(
			packet.get(
				"truth_complete",
				false
			)
		):
			_seal_united_states_truth_to_realm_and_scenario(
				realm_id,
				realm_name,
				packet
			)

		truth_by_realm_key [
			_realm_key(
				realm_id,
				realm_name
			)
		] = packet

		_project_truth_packet_to_population_card_engine(
			realm_id,
			realm_name,
			packet,
			{
				"source": (
					"truth_resolution_contract_engine."
					+ "us_truth_shard_projection"
				),
				"senate_cardinality_reconciled": (
					senate_phase_complete
				),
				"ui_is_renderer_only": true
			}.merged(
				context,
				true
			)
		)

		var senate_rows: Array = (
			groups.get(
				"senate",
				[]
			) as Array
			if typeof(
				groups.get(
					"senate",
					[]
				)
			) == TYPE_ARRAY
			else []
		)

		last_report = {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": CONTRACT_VERSION,
			"reason": "united_states_truth_shard_resolved",
			"realm_id": realm_id,
			"realm_name": realm_name,
			"shard_kind": shard_kind,
			"start_index": start_index,
			"count": count,
			"senate_count": senate_rows.size(),
			"senate_target": US_SENATE_TARGET,
			"senate_cardinality_reconciled": senate_phase_complete,
			"truth_complete": bool(
				packet.get(
					"truth_complete",
					false
				)
			),
			"ready_door_may_not_wait": true,
			"ui_is_renderer_only": true,
			"at_ms": int(
				Time.get_ticks_msec()
			)
		}

		_commit_registry()

		return last_report.duplicate(true)
func _reconcile_united_states_senate_cardinality(
		groups: Dictionary,
		realm_id: int,
		realm_name: String
) -> void:
		var senate_raw: Variant = groups.get(
			"senate",
			[]
		)
		var senate: Array = (
			senate_raw as Array
			if typeof(senate_raw) == TYPE_ARRAY
			else []
		)
		var seen_ids: Dictionary = {}
		var state_names: Array = (
			PopulationCardContractEngine
			.UNITED_STATES_STATE_NAMES
			.duplicate(true)
		)

		for raw_node in senate:
			if typeof(raw_node) != TYPE_DICTIONARY:
				continue

			var node: Dictionary = (
				raw_node as Dictionary
			)
			var person_id: int = int(
				node.get(
					"id",
					node.get(
						"person_id",
						-1
					)
				)
			)

			if person_id > 0:
				seen_ids [
					person_id
				] = true

		for i in range(
			US_SENATE_TARGET
		):
			var expected_id: int = _truth_id(
				realm_id,
				300,
				i
			)

			if seen_ids.has(
				expected_id
			):
				continue

			var state_index: int = (
				int(
					floor(
						float(i) / 2.0
					)
				)
				% state_names.size()
			)
			var state_name: String = str(
				state_names [
					state_index
				]
			)
			var party: String = (
				"Democratic"
				if i % 2 == 0
				else "Republican"
			)

			_append_truth_group_node_unique(
				senate,
				_make_truth_person(
					realm_id,
					realm_name,
					expected_id,
					"%s Senator of %s" % [
						party,
						state_name
					],
					"senate",
					state_name,
					party,
					30 + int(i % 36)
				)
			)

			seen_ids [
				expected_id
			] = true

		groups [
			"senate"
		] = senate

func _resolve_generic_population_truth_shard(
	realm_id: int,
	realm_name: String,
	shard: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	var packet: Dictionary = (
		_ensure_population_government_truth_packet_shell(
			realm_id,
			realm_name,
			false
		)
	)
	var groups_raw: Variant = packet.get(
		"groups",
		{}
	)
	var groups: Dictionary = (
		groups_raw as Dictionary
		if typeof(groups_raw) == TYPE_DICTIONARY
		else {}
	)
	var shard_kind: String = str(
		shard.get(
			"shard_kind",
			""
		)
	).strip_edges().to_lower()
	var start_index: int = int(
		shard.get(
			"start_index",
			0
		)
	)
	var count: int = maxi(
		0,
		int(
			shard.get(
				"count",
				0
			)
		)
	)

	match shard_kind:
		"sovereign", \
"royal_court", \
"noble_court", \
"executive", \
"legislative", \
"judicial", \
"military_command", \
"masters":
			_resolve_generic_role_truth_shard(
				groups,
				realm_id,
				realm_name,
				shard_kind,
				start_index,
				count
			)

		"citizens":
			_resolve_citizen_truth_shard(
				groups,
				realm_id,
				realm_name,
				start_index,
				count
			)

		_:
			return {
				"success": false,
				"reason": (
					"unknown_generic_truth_shard_kind"
				),
				"schema": ENGINE_SCHEMA,
				"realm_id": realm_id,
				"realm_name": realm_name,
				"shard": shard.duplicate(false),
				"ui_is_renderer_only": true
			}

	var resolved_raw: Variant = packet.get(
		"resolved_shard_keys",
		{}
	)
	var resolved_shard_keys: Dictionary = (
		resolved_raw as Dictionary
		if typeof(resolved_raw) == TYPE_DICTIONARY
		else {}
	)
	var shard_key: String = str(
		shard.get(
			"shard_key",
			"%s:%d:%d"
			% [
				shard_kind,
				start_index,
				count
			]
		)
	)

	resolved_shard_keys [
		shard_key
	] = true
	packet [
		"groups"
	] = groups
	packet [
		"resolved_shard_keys"
	] = resolved_shard_keys

	_refresh_truth_packet_counts(
		packet
	)

	truth_by_realm_key [
		_realm_key(
			realm_id,
			realm_name
		)
	] = packet

	_project_truth_packet_to_population_card_engine(
		realm_id,
		realm_name,
		packet,
		{
			"source": (
				"truth_resolution_contract_engine."
				+ "generic_truth_shard_projection"
			),
			"ui_is_renderer_only": true
		}.merged(
			context,
			true
		)
	)

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"reason": (
			"generic_population_truth_shard_resolved"
		),
		"realm_id": realm_id,
		"realm_name": realm_name,
		"shard_kind": shard_kind,
		"start_index": start_index,
		"count": count,
		"truth_complete": bool(
			packet.get(
				"truth_complete",
				false
			)
		),
		"ready_door_may_not_wait": true,
		"ui_is_renderer_only": true,
		"at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_commit_registry()

	return last_report.duplicate(false)
func _generic_realm_role_titles(
	profile: Dictionary,
	shard_kind: String
) -> Array:
	var era_name: String = str(
		profile.get(
			"era_name",
			"Modern Era"
		)
	)
	var model: String = str(
		profile.get(
			"government_model",
			"monarchy"
		)
	)
	var element: String = str(
		profile.get(
			"element",
			""
		)
	).strip_edges().capitalize()

	match shard_kind:
		"sovereign":
			var leader_raw: Variant = profile.get(
				"leader_identity_contract",
				{}
			)
			var leader: Dictionary = (
				leader_raw as Dictionary
				if typeof(
					leader_raw
				) == TYPE_DICTIONARY
				else {}
			)
			var leader_title: String = str(
				leader.get(
					"leader_title",
					""
				)
			).strip_edges()

			if leader_title != "":
				return [
					leader_title
				]

			match model:
				"empire":
					return [
						"Emperor or Empress"
					]

				"theocracy":
					return [
						"Supreme Religious Leader"
					]

				"council":
					return [
						"High Elder"
					]

				_:
					return [
						"King or Queen"
					]

		"royal_court":
			match model:
				"empire":
					return [
						"Imperial Consort",
						"Crown Prince",
						"Crown Princess",
						"Imperial Chamberlain",
						"Keeper of the Imperial Seal",
						"Palace Steward"
					]

				"theocracy":
					return [
						"High Priest",
						"High Priestess",
						"Temple Oracle",
						"Sacred Archivist",
						"Keeper of Relics",
						"Chief Ritual Officer"
					]

				_:
					return [
						"Royal Consort",
						"Heir Apparent",
						"Prince",
						"Princess",
						"Royal Steward",
						"Keeper of the Royal Seal"
					]

		"noble_court":
			if model == "empire":
				return [
					"Imperial Duke",
					"Imperial Duchess",
					"Satrap",
					"Provincial Governor",
					"Margrave",
					"Noble House Lord",
					"Noble House Lady",
					"Court Patrician"
				]

			if era_name == "Ancient Era":
				return [
					"Vizier",
					"Nomarch",
					"High Priest",
					"High Priestess",
					"Palace Scribe",
					"Provincial Governor",
					"Noble House Lord",
					"Noble House Lady"
				]

			return [
				"Duke",
				"Duchess",
				"Marquess",
				"Marchioness",
				"Count",
				"Countess",
				"Lord",
				"Lady"
			]

		"executive":
			match model:
				"republic":
					return [
						"Head of Government",
						"Minister of State",
						"Minister of the Treasury",
						"Minister of Foreign Affairs",
						"Minister of the Interior",
						"Chief Administrator",
						"Public Works Minister",
						"Trade Minister"
					]

				"council":
					return [
						"High Elder",
						"Council Elder",
						"Temple Abbot",
						"Clan Chief",
						"Keeper of Stores",
						"Diplomatic Councilor",
						"Master of Works",
						"Community Steward"
					]

				"theocracy":
					return [
						"First Hierophant",
						"Temple Chancellor",
						"Keeper of Offerings",
						"Sacred Diplomat",
						"Temple Works Master",
						"High Scribe"
					]

				"empire":
					return [
						"Imperial Chancellor",
						"Imperial Treasurer",
						"Grand Vizier",
						"Provincial Prefect",
						"Master of Imperial Works",
						"Imperial Envoy"
					]

				_:
					return [
						"Chancellor",
						"Royal Treasurer",
						"Royal Steward",
						"Minister of Grain",
						"Diplomatic Envoy",
						"Master of Works"
					]

		"legislative":
			if model == "constitutional_monarchy":
				return [
					"Member of Parliament",
					"Upper Chamber Peer",
					"Commons Delegate",
					"Provincial Representative"
				]

			if model == "council":
				return [
					"Council Delegate",
					"Clan Representative",
					"Temple Representative",
					"Guild Representative"
				]

			return [
				"Senator",
				"Assembly Delegate",
				"Councilor",
				"Provincial Representative"
			]

		"judicial":
			if model == "theocracy":
				return [
					"Chief Sacred Judge",
					"Canon Magistrate",
					"Temple Arbiter",
					"Keeper of Sacred Law"
				]

			return [
				"Chief Judge",
				"High Magistrate",
				"Realm Justice",
				"Circuit Magistrate",
				"Keeper of Law"
			]

		"military_command":
			return [
				"Supreme Commander",
				"General",
				"Marshal",
				"Admiral",
				"Captain of the Guard",
				"Frontier Commander"
			]

		"masters":
			return [
				(
					"%s Grandmaster"
					% element
				).strip_edges(),
				(
					"%s Master"
					% element
				).strip_edges(),
				(
					"%s Master"
					% element
				).strip_edges(),
				(
					"%s Instructor"
					% element
				).strip_edges(),
				(
					"%s Guardian"
					% element
				).strip_edges(),
				(
					"%s Sage"
					% element
				).strip_edges()
			]

	return [
		"Realm Official"
	]
func _project_truth_packet_to_population_card_engine(
	realm_id: int,
	realm_name: String,
	packet: Dictionary,
	context: Dictionary = {}
) -> void:
	if gs == null:
		return
	if packet.is_empty():
		return
	if gs.population_card_contract_engine == null:
		return
	if not gs.population_card_contract_engine.has_method("project_truth_packet_for_realm"):
		return

	gs.population_card_contract_engine.project_truth_packet_for_realm(
		realm_id,
		realm_name,
		packet,
		{
			"source": "truth_resolution_contract_engine.project_truth_packet_to_population_card_engine",
			"surface_already_exists": true,
			"truth_may_be_partial": true,
			"ready_door_may_not_wait": true,
			"ui_is_renderer_only": true
		}.merged(context, true)
	)
func _ensure_population_government_truth_packet_shell(
	realm_id: int,
	realm_name: String,
	is_us: bool
) -> Dictionary:
	var key: String = _realm_key(
		realm_id,
		realm_name
	)
	var existing_raw: Variant = (
		truth_by_realm_key.get(
			key,
			{}
		)
	)
	var existing: Dictionary = (
		existing_raw as Dictionary
		if typeof(
			existing_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var required_groups: Dictionary = (
		_empty_truth_groups(
			is_us
		)
	)
	var profile: Dictionary = (
		{
			"government_model": (
				"federal_presidential_republic"
			),
			"government_style": "Federal Republic",
			"section_titles": {},
			"section_subtitles": {},
			"era_name": _truth_current_era_name()
		}
		if is_us
		else _generic_realm_government_profile(
			realm_id,
			realm_name
		)
	)
	var shard_plan: Array = (
		emit_population_truth_shard_plan(
			realm_id,
			realm_name,
			{}
		)
	)
	var realm: Dictionary = (
		_truth_realm_dictionary(
			realm_id
		)
	)
	var leader_identity_revision: int = int(
		realm.get(
			"leader_identity_revision",
			0
		)
	)

	if not existing.is_empty():
		var groups_raw: Variant = existing.get(
			"groups",
			{}
		)
		var groups: Dictionary = (
			groups_raw as Dictionary
			if typeof(
				groups_raw
			) == TYPE_DICTIONARY
			else {}
		)

		for raw_group_key in required_groups.keys():
			var group_key: String = str(
				raw_group_key
			)

			if typeof(
				groups.get(
					group_key,
					[]
				)
			) != TYPE_ARRAY:
				groups [
					group_key
				] = []

		var previous_leader_revision: int = int(
			existing.get(
				"leader_identity_revision",
				0
			)
		)

		if (
			leader_identity_revision > 0
			and previous_leader_revision
			!= leader_identity_revision
		):
			var leadership_groups: Array = (
				[
					"executive"
				]
				if is_us
				else [
					"sovereign",
					"royal_court"
				]
			)

			for raw_group_key in leadership_groups:
				var leadership_group_key: String = str(
					raw_group_key
				)

				if groups.has(
					leadership_group_key
				):
					groups [
						leadership_group_key
					] = []

			var resolved_raw: Variant = existing.get(
				"resolved_shard_keys",
				{}
			)
			var resolved_shard_keys: Dictionary = (
				resolved_raw as Dictionary
				if typeof(
					resolved_raw
				) == TYPE_DICTIONARY
				else {}
			)

			for raw_shard_key in (
				resolved_shard_keys.keys().duplicate()
			):
				var shard_key: String = str(
					raw_shard_key
				)
				var leadership_shard: bool = false

				for raw_group_key in leadership_groups:
					var leadership_group_key: String = str(
						raw_group_key
					)

					if shard_key.contains(
						":%s:"
						% leadership_group_key
					):
						leadership_shard = true
						break

				if leadership_shard:
					resolved_shard_keys.erase(
						raw_shard_key
					)

			existing [
				"resolved_shard_keys"
			] = resolved_shard_keys
			existing [
				"truth_complete"
			] = false
			existing [
				"truth_state"
			] = "partial"
			existing [
				"persistent_ontology_complete"
			] = false
			existing [
				"leader_identity_revision_reconciled"
			] = true

		existing [
			"groups"
		] = groups
		existing [
			"government_profile"
		] = profile
		existing [
			"expected_shard_count"
		] = shard_plan.size()
		existing [
			"leader_identity_revision"
		] = leader_identity_revision

		if typeof(
			existing.get(
				"resolved_shard_keys",
				{}
			)
		) != TYPE_DICTIONARY:
			existing [
				"resolved_shard_keys"
			] = {}

		return existing

	return {
		"schema": (
			"eralife.truth_resolution."
			+ "population_government_packet"
		),
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"country": (
			"United States"
			if is_us
			else realm_name
		),
		"government_model": (
			"federal_presidential_republic"
			if is_us
			else str(
				profile.get(
					"government_model",
					"monarchy"
				)
			)
		),
		"government_profile": profile,
		"leader_identity_revision": (
			leader_identity_revision
		),
		"expected_shard_count": shard_plan.size(),
		"resolved_shard_keys": {},
		"truth_complete": false,
		"truth_state": "partial",
		"persistent_ontology_complete": false,
		"hydration_optional": true,
		"runtime_people_materialization_deferred": true,
		"global_node_ingestion_deferred": true,
		"groups": required_groups,
		"all_nodes": [],
		"counts": {},
		"ui_is_renderer_only": true,
		"resolved_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _truth_era_job_pool() -> Array:
	if (
		gs == null
		or not "era_engine" in gs
		or gs.era_engine == null
		or not gs.era_engine.has_method(
			"get_job_pool"
		)
	):
		return []

	var jobs_raw: Variant = (
		gs.era_engine.get_job_pool()
	)

	if typeof(jobs_raw) != TYPE_ARRAY:
		return []

	return (
		jobs_raw as Array
	).duplicate(false)


func _truth_social_class_for_job(
	era_name: String,
	job: String,
	index: int
) -> String:
	var key: String = str(
		job
	).strip_edges().to_lower()

	match era_name:
		"Ancient Era":
			if (
				key.find("priest") >= 0
				or key.find("oracle") >= 0
				or key.find("scribe") >= 0
				or key.find("scholar") >= 0
				or key.find("astrolog") >= 0
				or key.find("astronom") >= 0
			):
				return "Temple and Learned Class"

			if (
				key.find("merchant") >= 0
				or key.find("trader") >= 0
				or key.find("jeweler") >= 0
				or key.find("perfume") >= 0
				or key.find("wine") >= 0
			):
				return "Merchant Class"

			if (
				key.find("smith") >= 0
				or key.find("maker") >= 0
				or key.find("mason") >= 0
				or key.find("brick") >= 0
				or key.find("potter") >= 0
				or key.find("weaver") >= 0
				or key.find("shipwright") >= 0
				or key.find("fletcher") >= 0
			):
				return "Artisan Class"

			if (
				key.find("guard") >= 0
				or key.find("soldier") >= 0
				or key.find("chariot") >= 0
			):
				return "Military Class"

			if (
				key.find("slave") >= 0
				or key.find("servant") >= 0
				or key.find("laborer") >= 0
				or key.find("water carrier") >= 0
				or key.find("dock") >= 0
			):
				return "Servant and Laboring Class"

			return "Commoner and Agrarian Class"

		"Medieval Era":
			if (
				key.find("knight") >= 0
				or key.find("guard") >= 0
				or key.find("squire") >= 0
				or key == "page"
			):
				return "Martial Retainer Class"

			if (
				key.find("priest") >= 0
				or key.find("monk") >= 0
				or key.find("nun") >= 0
				or key.find("scholar") >= 0
			):
				return "Clergy and Learned Class"

			if (
				key.find("merchant") >= 0
				or key.find("innkeeper") >= 0
				or key.find("money") >= 0
			):
				return "Merchant Class"

			if (
				key.find("smith") >= 0
				or key.find("mason") >= 0
				or key.find("tailor") >= 0
				or key.find("weaver") >= 0
				or key.find("carpenter") >= 0
				or key.find("wheelwright") >= 0
				or key.find("leather") >= 0
				or key.find("chandler") >= 0
			):
				return "Guild Artisan Class"

			if (
				key.find("peasant") >= 0
				or key.find("farm") >= 0
			):
				return "Peasant Class"

			return "Laboring Commoner Class"

		"Industrial Era":
			if (
				key.find("doctor") >= 0
				or key.find("pharmacist") >= 0
				or key.find("teacher") >= 0
				or key.find("bookkeeper") >= 0
				or key.find("bank") >= 0
				or key.find("inventor") >= 0
			):
				return "Professional and Middle Class"

			if (
				key.find("foreman") >= 0
				or key.find("shopkeeper") >= 0
				or key.find("clerk") >= 0
				or key.find("secretary") >= 0
			):
				return "Lower Middle Class"

			if (
				key.find("engineer") >= 0
				or key.find("machinist") >= 0
				or key.find("electrician") >= 0
				or key.find("mechanic") >= 0
				or key.find("printer") >= 0
				or key.find("plumber") >= 0
			):
				return "Skilled Working Class"

			if (
				key.find("factory") >= 0
				or key.find("miner") >= 0
				or key.find("mill") >= 0
				or key.find("dock") >= 0
				or key.find("textile") >= 0
				or key.find("warehouse") >= 0
			):
				return "Industrial Working Class"

			return "Laboring Poor"

		"Future Era":
			if (
				key.find("director") >= 0
				or key.find("architect") >= 0
				or key.find("diplomat") >= 0
				or key.find("lawyer") >= 0
			):
				return "Core Professional Class"

			if (
				key.find("engineer") >= 0
				or key.find("surgeon") >= 0
				or key.find("programmer") >= 0
				or key.find("specialist") >= 0
				or key.find("analyst") >= 0
			):
				return "Advanced Technical Class"

			if (
				key.find("miner") >= 0
				or key.find("construction") >= 0
				or key.find("terraform") >= 0
				or key.find("operator") >= 0
			):
				return "Frontier Working Class"

			return "Service and Support Class"

		_:
			if (
				key.find("executive") >= 0
				or key.find("investor") >= 0
				or key.find("lawyer") >= 0
				or key.find("doctor") >= 0
				or key.find("entrepreneur") >= 0
			):
				return "Upper Professional Class"

			if (
				key.find("teacher") >= 0
				or key.find("nurse") >= 0
				or key.find("account") >= 0
				or key.find("engineer") >= 0
				or key.find("developer") >= 0
			):
				return "Middle Class"

			if (
				key.find("mechanic") >= 0
				or key.find("construction") >= 0
				or key.find("factory") >= 0
				or key.find("driver") >= 0
				or key.find("warehouse") >= 0
			):
				return "Working Class"

			if (
				key.find("retail") >= 0
				or key.find("restaurant") >= 0
				or key.find("fast food") >= 0
				or key.find("support") >= 0
			):
				return "Service Class"

	var fallback_classes: Array = [
		"Upper Class",
		"Middle Class",
		"Skilled Working Class",
		"Working Class",
		"Lower Class"
	]

	return str(
		fallback_classes [
			index % fallback_classes.size()
		]
	)


func _truth_civilian_profile_for_index(
	era_name: String,
	index: int
) -> Dictionary:
	var era_jobs: Array = (
		_truth_era_job_pool()
	)
	var job: String = "Resident"

	if not era_jobs.is_empty():
		job = str(
			era_jobs [
				index % era_jobs.size()
			]
		).strip_edges()

	if job == "":
		job = "Resident"

	return {
		"social_class": (
			_truth_social_class_for_job(
				era_name,
				job,
				index
			)
		),
		"job": job,
		"job_source": "EraEngine.get_job_pool",
		"era_name": era_name
	}


func _empty_truth_groups(
	is_us: bool
) -> Dictionary:
	if is_us:
		return {
			"executive": [],
			"cabinet": [],
			"senate": [],
			"supreme_court": [],
			"governors": [],
			"citizens": []
		}

	return {
		"sovereign": [],
		"royal_court": [],
		"noble_court": [],
		"executive": [],
		"legislative": [],
		"judicial": [],
		"military_command": [],
		"masters": [],
		"citizens": []
	}


func _resolve_us_executive_truth_shard(groups: Dictionary, realm_id: int, realm_name: String) -> void:
	var executive: Array = groups.get("executive", []) if typeof(groups.get("executive", [])) == TYPE_ARRAY else []

	var president_id: int = -1
	var first_partner_id: int = -1

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		president_id = int(gs.scenario_state.get("presidential_parent_contract_president_id", -1))
		first_partner_id = int(gs.scenario_state.get("presidential_parent_contract_first_partner_id", -1))

	var president = _person_by_id_safe(president_id)
	if president != null:
		_append_truth_group_node_unique(
			executive,
			_truth_node_from_runtime_person(president, realm_id, realm_name, "President", "executive", "", "Independent")
		)

	var vice_president: Dictionary = _make_truth_person(
		realm_id,
		realm_name,
		_truth_id(realm_id, 100, 0),
		"Vice President",
		"executive",
		"",
		"Independent",
		45
	)
	_append_truth_group_node_unique(executive, vice_president)

	var first_partner = _person_by_id_safe(first_partner_id)
	if first_partner != null:
		_append_truth_group_node_unique(
			executive,
			_truth_node_from_runtime_person(first_partner, realm_id, realm_name, _first_partner_role_from_person(first_partner), "executive", "", "")
		)

	groups ["executive"] = executive


func _resolve_us_cabinet_truth_shard(groups: Dictionary, realm_id: int, realm_name: String, start_index: int, count: int) -> void:
	var cabinet: Array = groups.get("cabinet", []) if typeof(groups.get("cabinet", [])) == TYPE_ARRAY else []
	var titles: Array = _us_cabinet_titles()

	var end_index: int = mini(titles.size(), start_index + count)
	for i in range(start_index, end_index):
		_append_truth_group_node_unique(
			cabinet,
			_make_truth_person(
				realm_id,
				realm_name,
				_truth_id(realm_id, 200, i),
				str(titles [i]),
				"cabinet",
				"",
				"",
				42 + int(i % 20)
			)
		)

	groups ["cabinet"] = cabinet


func _resolve_us_senate_truth_shard(groups: Dictionary, realm_id: int, realm_name: String, start_index: int, count: int) -> void:
	var senate: Array = groups.get("senate", []) if typeof(groups.get("senate", [])) == TYPE_ARRAY else []
	var state_names: Array = PopulationCardContractEngine.UNITED_STATES_STATE_NAMES.duplicate(true)

	var end_index: int = mini(US_SENATE_TARGET, start_index + count)
	for i in range(start_index, end_index):
		var state_index: int = int(floor(float(i) / 2.0)) % state_names.size()
		var state_name: String = str(state_names [state_index])
		var party: String = "Democratic" if i % 2 == 0 else "Republican"

		_append_truth_group_node_unique(
			senate,
			_make_truth_person(
				realm_id,
				realm_name,
				_truth_id(realm_id, 300, i),
				"%s Senator of %s" % [party, state_name],
				"senate",
				state_name,
				party,
				30 + int(i % 36)
			)
		)

	groups ["senate"] = senate


func _resolve_us_supreme_court_truth_shard(groups: Dictionary, realm_id: int, realm_name: String, start_index: int, count: int) -> void:
	var supreme_court: Array = groups.get("supreme_court", []) if typeof(groups.get("supreme_court", [])) == TYPE_ARRAY else []

	var end_index: int = mini(US_SUPREME_COURT_TARGET, start_index + count)
	for i in range(start_index, end_index):
		var justice_title: String = "Chief Justice" if i == 0 else "Supreme Court Justice"

		_append_truth_group_node_unique(
			supreme_court,
			_make_truth_person(
				realm_id,
				realm_name,
				_truth_id(realm_id, 500, i),
				justice_title,
				"judicial",
				"",
				"",
				45 + int(i % 28)
			)
		)

	groups ["supreme_court"] = supreme_court


func _resolve_us_governor_truth_shard(groups: Dictionary, realm_id: int, realm_name: String, start_index: int, count: int) -> void:
	var governors: Array = groups.get("governors", []) if typeof(groups.get("governors", [])) == TYPE_ARRAY else []
	var state_names: Array = PopulationCardContractEngine.UNITED_STATES_STATE_NAMES.duplicate(true)

	var end_index: int = mini(US_GOVERNOR_TARGET, start_index + count)
	for i in range(start_index, end_index):
		var state_name: String = str(state_names [i % state_names.size()])
		var party: String = "Republican" if i % 2 == 0 else "Democratic"

		_append_truth_group_node_unique(
			governors,
			_make_truth_person(
				realm_id,
				realm_name,
				_truth_id(realm_id, 600, i),
				"%s Governor of %s" % [party, state_name],
				"state_governor",
				state_name,
				party,
				35 + int(i % 30)
			)
		)

	groups ["governors"] = governors


func _resolve_citizen_truth_shard(groups: Dictionary, realm_id: int, realm_name: String, start_index: int, count: int) -> void:
	var citizens: Array = groups.get("citizens", []) if typeof(groups.get("citizens", [])) == TYPE_ARRAY else []

	for i in range(start_index, start_index + count):
		_append_truth_group_node_unique(
			citizens,
			_make_citizen_truth_person(
				realm_id,
				realm_name,
				_truth_id(realm_id, 700, i),
				i
			)
		)

	groups ["citizens"] = citizens


func _append_truth_group_node_unique(group: Array, node: Dictionary) -> void:
	if typeof(node) != TYPE_DICTIONARY or node.is_empty():
		return

	var person_id: int = int(node.get("id", node.get("person_id", -1)))
	if person_id <= 0:
		return

	for raw_existing in group:
		if typeof(raw_existing) != TYPE_DICTIONARY:
			continue

		var existing: Dictionary = raw_existing
		if int(existing.get("id", existing.get("person_id", -1))) == person_id:
			return

	group.append(node)


func _refresh_truth_packet_counts(
	packet: Dictionary
) -> void:
	var groups_raw: Variant = packet.get(
		"groups",
		{}
	)
	var groups: Dictionary = (
		groups_raw as Dictionary
		if typeof(groups_raw) == TYPE_DICTIONARY
		else {}
	)
	var all_nodes: Array = []
	var counts: Dictionary = {}
	var seen_node_ids: Dictionary = {}

	for raw_key in groups.keys():
		var key: String = str(
			raw_key
		)
		var group_raw: Variant = groups.get(
			key,
			[]
		)
		var group: Array = (
			group_raw as Array
			if typeof(group_raw) == TYPE_ARRAY
			else []
		)

		counts [
			key
		] = group.size()

		for raw_node in group:
			if typeof(raw_node) != TYPE_DICTIONARY:
				continue

			var node: Dictionary = (
				raw_node as Dictionary
			)
			var node_id: int = int(
				node.get(
					"id",
					node.get(
						"person_id",
						-1
					)
				)
			)
			var node_key: String = (
				str(
					node_id
				)
				if node_id > 0
				else str(
					hash(
						node
					)
				)
			)

			if seen_node_ids.has(
				node_key
			):
				continue

			seen_node_ids [
				node_key
			] = true
			all_nodes.append(
				node
			)

	packet [
		"all_nodes"
	] = all_nodes
	packet [
		"counts"
	] = counts
	packet [
		"resolved_at_ms"
	] = int(
		Time.get_ticks_msec()
	)

	var is_us: bool = (
		str(
			packet.get(
				"government_model",
				""
			)
		).strip_edges().to_lower()
		== "federal_presidential_republic"
	)
	var complete: bool = false

	if is_us:
		complete = (
			int(
				counts.get(
					"cabinet",
					0
				)
			) >= US_CABINET_TARGET
			and int(
				counts.get(
					"senate",
					0
				)
			) >= US_SENATE_TARGET
			and int(
				counts.get(
					"supreme_court",
					0
				)
			) >= US_SUPREME_COURT_TARGET
			and int(
				counts.get(
					"governors",
					0
				)
			) >= US_GOVERNOR_TARGET
			and int(
				counts.get(
					"citizens",
					0
				)
			) >= US_CITIZEN_TARGET
		)
	else:
		var resolved_raw: Variant = packet.get(
			"resolved_shard_keys",
			{}
		)
		var resolved_shard_keys: Dictionary = (
			resolved_raw as Dictionary
			if typeof(
				resolved_raw
			) == TYPE_DICTIONARY
			else {}
		)
		var expected_shard_count: int = int(
			packet.get(
				"expected_shard_count",
				0
			)
		)

		complete = (
			expected_shard_count > 0
			and resolved_shard_keys.size()
			>= expected_shard_count
			and int(
				counts.get(
					"citizens",
					0
				)
			) >= GENERIC_REALM_CITIZEN_TARGET
		)

	packet [
		"truth_complete"
	] = complete
	packet [
		"truth_state"
	] = (
		"complete"
		if complete
		else "partial"
	)
	packet [
		"persistent_ontology_complete"
	] = complete

func _truth_node_from_runtime_person(
	person,
	realm_id: int,
	realm_name: String,
	role_label: String,
	branch: String,
	state_name: String,
	party: String
) -> Dictionary:
	var person_id: int = int(_value(person, "id", -1))
	var clean_role: String = str(role_label).strip_edges()
	var clean_branch: String = str(branch).strip_edges().to_lower()
	var clean_state: String = str(state_name).strip_edges()
	var clean_party: String = str(party).strip_edges()

	return {
		"id": person_id,
		"first_name": str(_value(person, "first_name", "")),
		"last_name": str(_value(person, "last_name", "")),
		"name": "%s %s" % [str(_value(person, "first_name", "")), str(_value(person, "last_name", ""))],
		"age": int(_value(person, "age", 35)),
		"alive": bool(_value(person, "alive", true)),
		"realm_id": realm_id,
		"home_country": "USA",
		"birth_country": "USA",
		"home_state": clean_state,
		"birth_state": clean_state,
		"job": clean_role,
		"civic_title": clean_role,
		"social_class": "Upper Class",
		"is_royal": false,
		"is_ruler": clean_role.to_lower().find("president") >= 0,
		"royal_title": "",
		"succession_rank": 99,
		"truth_state": "partial",
		"civic_office_contract": {
			"schema": "eralife.civic_office_contract",
			"version": 1,
			"government_model": "federal_presidential_republic",
			"country": "United States",
			"realm_id": realm_id,
			"realm_name": realm_name,
			"role_label": clean_role,
			"office": _office_key_for_role(clean_role, clean_branch),
			"branch": clean_branch,
			"state_name": clean_state,
			"party": clean_party,
			"truth_resolution_source": true,
			"ui_is_renderer_only": true
		},
	}


func _first_partner_role_from_person(person) -> String:
	var job_text: String = str(_value(person, "job", "")).strip_edges()
	if job_text in ["First Lady", "First Gentleman"]:
		return job_text

	var gender_key: String = str(_value(person, "gender", "")).strip_edges().to_lower()
	return "First Gentleman" if gender_key == "male" else "First Lady"


func _seal_united_states_leader_truth_only(realm_id: int, _realm_name: String, _packet: Dictionary) -> void:
	if gs == null or realm_id <= 0:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var president_id: int = int(gs.scenario_state.get("presidential_parent_contract_president_id", -1))
	var first_partner_id: int = int(gs.scenario_state.get("presidential_parent_contract_first_partner_id", -1))

	gs.scenario_state ["presidential_parent_contract_us_realm_id"] = realm_id
	gs.scenario_state ["presidential_parent_contract_federal_population_blocks_ready"] = false
	gs.scenario_state ["presidential_parent_contract_federal_population_pending_after_player_control"] = true

	if gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}

		var president = _person_by_id_safe(president_id)
		var president_name: String = _truth_person_display_name(president)

		realm ["id"] = realm_id
		realm ["realm_id"] = realm_id
		realm ["name"] = "United States"
		realm ["country"] = "United States"
		realm ["government_style"] = "Republic"
		realm ["government_model"] = "federal_presidential_republic"
		realm ["federal_republic_population_contract"] = true
		realm ["federal_republic_population_blocks_ready"] = false
		realm ["ruler_id"] = president_id
		realm ["ruler_npc_id"] = president_id
		realm ["leader_id"] = president_id
		realm ["president_person_id"] = president_id
		realm ["first_partner_person_id"] = first_partner_id
		realm ["ruler_name"] = president_name
		realm ["leader_name"] = president_name
		realm ["leader_title"] = "President of the United States"
		realm ["surface_ruler_office"] = "President of the United States"
		realm ["truth_state"] = "partial"

		gs.realm_engine.realms [realm_id] = realm


func verify_population_and_government_truth_for_realms(realm_ids: Array = [], context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return _fail("missing_game_state", context)

	var ids: Array = _resolve_realm_ids(realm_ids)
	var verified: Array = []
	var failed: Array = []

	for raw_realm_id in ids:
		var realm_id: int = int(raw_realm_id)
		if realm_id <= 0:
			continue

		var realm_name: String = _realm_name_for_id(realm_id)
		var key: String = _realm_key(realm_id, realm_name)

		if not truth_by_realm_key.has(key):
			failed.append({
				"realm_id": realm_id,
				"realm_name": realm_name,
				"reason": "missing_truth_packet"
			})
			continue

		var packet: Dictionary = truth_by_realm_key.get(key, {})
		var groups: Dictionary = packet.get("groups", {}) if typeof(packet.get("groups", {})) == TYPE_DICTIONARY else {}

		if _is_united_states_realm(realm_id, realm_name):
			var senate: Array = groups.get("senate", []) if typeof(groups.get("senate", [])) == TYPE_ARRAY else []
			var governors: Array = groups.get("governors", []) if typeof(groups.get("governors", [])) == TYPE_ARRAY else []
			var supreme_court: Array = groups.get("supreme_court", []) if typeof(groups.get("supreme_court", [])) == TYPE_ARRAY else []
			var cabinet: Array = groups.get("cabinet", []) if typeof(groups.get("cabinet", [])) == TYPE_ARRAY else []
			var citizens: Array = groups.get("citizens", []) if typeof(groups.get("citizens", [])) == TYPE_ARRAY else []

			if senate.size() < US_SENATE_TARGET:
				failed.append({ "realm_id": realm_id, "realm_name": realm_name, "reason": "us_senate_truth_incomplete", "actual": senate.size(), "required": US_SENATE_TARGET})
				continue
			if governors.size() < US_GOVERNOR_TARGET:
				failed.append({ "realm_id": realm_id, "realm_name": realm_name, "reason": "us_governor_truth_incomplete", "actual": governors.size(), "required": US_GOVERNOR_TARGET})
				continue
			if supreme_court.size() < US_SUPREME_COURT_TARGET:
				failed.append({ "realm_id": realm_id, "realm_name": realm_name, "reason": "us_supreme_court_truth_incomplete", "actual": supreme_court.size(), "required": US_SUPREME_COURT_TARGET})
				continue
			if cabinet.size() < US_CABINET_TARGET:
				failed.append({ "realm_id": realm_id, "realm_name": realm_name, "reason": "us_cabinet_truth_incomplete", "actual": cabinet.size(), "required": US_CABINET_TARGET})
				continue
			if citizens.size() < US_CITIZEN_TARGET:
				failed.append({ "realm_id": realm_id, "realm_name": realm_name, "reason": "us_citizen_truth_incomplete", "actual": citizens.size(), "required": US_CITIZEN_TARGET})
				continue

		verified.append(realm_id)

	var success: bool = failed.is_empty()

	return {
		"success": success,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"reason": "truth_verified" if success else "truth_verification_failed",
		"verified": verified.duplicate(true),
		"failed": failed.duplicate(true),
		"ready_gate_truth_complete": success,
		"ui_is_renderer_only": true,
		"at_ms": int(Time.get_ticks_msec())
	}


func population_truth_nodes_for_realm(realm_id: int, realm_name: String = "") -> Array:
	var resolved_name: String = str(realm_name).strip_edges()
	if resolved_name == "":
		resolved_name = _realm_name_for_id(realm_id)

	var packet: Dictionary = _truth_packet_for_realm_any_alias(realm_id, resolved_name)
	if packet.is_empty():
		return []

	var nodes: Array = packet.get("all_nodes", []) if typeof(packet.get("all_nodes", [])) == TYPE_ARRAY else []
	return nodes.duplicate(true)


func government_truth_report_for_realm(realm_id: int, realm_name: String = "") -> Dictionary:
	var resolved_name: String = str(realm_name).strip_edges()
	if resolved_name == "":
		resolved_name = _realm_name_for_id(realm_id)

	var packet: Dictionary = _truth_packet_for_realm_any_alias(realm_id, resolved_name)

	if packet.is_empty():
		return {
			"success": false,
			"reason": "truth_packet_missing",
			"realm_id": realm_id,
			"realm_name": resolved_name,
			"schema": ENGINE_SCHEMA,
			"truth_state": "missing",
			"read_only": true,
			"ui_is_renderer_only": true
		}

	var complete: bool = bool(packet.get("truth_complete", false))
	var meets_minimums: bool = true

	if _is_united_states_realm(realm_id, resolved_name):
		meets_minimums = _truth_packet_meets_united_states_minimums(packet)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"realm_id": realm_id,
		"realm_name": str(packet.get("realm_name", resolved_name)),
		"truth_packet": packet.duplicate(true),
		"truth_complete": complete,
		"truth_state": "complete" if complete and meets_minimums else "partial",
		"persistent_ontology_complete": bool(packet.get("persistent_ontology_complete", complete and meets_minimums)),
		"meets_minimums": meets_minimums,
		"read_only": true,
		"ui_is_renderer_only": true
	}
func _truth_packet_for_realm_any_alias(realm_id: int, realm_name: String = "") -> Dictionary:
	if realm_id <= 0:
		return {}

	var aliases: Array = _truth_lookup_names_for_realm(realm_id, realm_name)

	for raw_name in aliases:
		var alias_name: String = str(raw_name).strip_edges()
		if alias_name == "":
			continue

		var alias_key: String = _realm_key(realm_id, alias_name)
		if truth_by_realm_key.has(alias_key):
			var direct_packet: Dictionary = truth_by_realm_key.get(alias_key, {})
			if typeof(direct_packet) == TYPE_DICTIONARY:
				return direct_packet.duplicate(true)

	for raw_key in truth_by_realm_key.keys():
		var packet_raw: Variant = truth_by_realm_key.get(raw_key, {})
		if typeof(packet_raw) != TYPE_DICTIONARY:
			continue

		var packet: Dictionary = packet_raw
		if int(packet.get("realm_id", -1)) == realm_id:
			return packet.duplicate(true)

	if _is_united_states_realm(realm_id, realm_name):
		for raw_key in truth_by_realm_key.keys():
			var us_packet_raw: Variant = truth_by_realm_key.get(raw_key, {})
			if typeof(us_packet_raw) != TYPE_DICTIONARY:
				continue

			var us_packet: Dictionary = us_packet_raw
			var country_key: String = str(us_packet.get("country", "")).strip_edges().to_lower()
			var name_key: String = str(us_packet.get("realm_name", "")).strip_edges().to_lower()
			if country_key in ["united states", "united states of america", "usa", "u.s.", "u.s.a.", "america"] \
or name_key in ["united states", "united states of america", "usa", "u.s.", "u.s.a.", "america"]:
				return us_packet.duplicate(true)

	return {}


func _truth_lookup_names_for_realm(realm_id: int, realm_name: String = "") -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	var push_name:= func (raw_name) -> void:
		var name: String = str(raw_name).strip_edges()
		if name == "":
			return

		var key: String = name.to_lower()
		if seen.has(key):
			return

		out.append(name)
		seen [key] = true

	push_name.call(realm_name)
	push_name.call(_realm_name_for_id(realm_id))

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var us_realm_id: int = int(gs.scenario_state.get("presidential_parent_contract_us_realm_id", -1))
		if us_realm_id == realm_id:
			push_name.call("United States")
			push_name.call("United States of America")
			push_name.call("USA")
			push_name.call("America")

	if gs != null and gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(realm_raw) == TYPE_DICTIONARY:
			var realm: Dictionary = realm_raw
			push_name.call(realm.get("name", ""))
			push_name.call(realm.get("country", ""))
			push_name.call(realm.get("realm_contract_resolved_from_country", ""))

	return out


func _truth_packet_meets_united_states_minimums(packet: Dictionary) -> bool:
	if typeof(packet) != TYPE_DICTIONARY:
		return false

	var groups_raw: Variant = packet.get("groups", {})
	if typeof(groups_raw) != TYPE_DICTIONARY:
		return false

	var groups: Dictionary = groups_raw
	var cabinet: Array = groups.get("cabinet", []) if typeof(groups.get("cabinet", [])) == TYPE_ARRAY else []
	var senate: Array = groups.get("senate", []) if typeof(groups.get("senate", [])) == TYPE_ARRAY else []
	var supreme_court: Array = groups.get("supreme_court", []) if typeof(groups.get("supreme_court", [])) == TYPE_ARRAY else []
	var governors: Array = groups.get("governors", []) if typeof(groups.get("governors", [])) == TYPE_ARRAY else []
	var citizens: Array = groups.get("citizens", []) if typeof(groups.get("citizens", [])) == TYPE_ARRAY else []

	if cabinet.size() < US_CABINET_TARGET:
		return false
	if senate.size() < US_SENATE_TARGET:
		return false
	if supreme_court.size() < US_SUPREME_COURT_TARGET:
		return false
	if governors.size() < US_GOVERNOR_TARGET:
		return false
	if citizens.size() < US_CITIZEN_TARGET:
		return false

	return true

func _resolve_united_states_population_and_government_truth(realm_id: int, realm_name: String, context: Dictionary = {}) -> Dictionary:
	var key: String = _realm_key(realm_id, realm_name)

	var force_rebuild: bool = bool(context.get("force_rebuild", false)) \
or bool(context.get("repair_incomplete_truth", false)) \
or bool(context.get("projection_truth_repair", false))

	if truth_by_realm_key.has(key) and not force_rebuild:
		var existing: Dictionary = truth_by_realm_key.get(key, {})
		if bool(existing.get("truth_complete", false)) and _truth_packet_meets_united_states_minimums(existing):
			return {
				"success": true,
				"reason": "truth_already_resolved",
				"realm_id": realm_id,
				"realm_name": realm_name,
				"schema": ENGINE_SCHEMA
			}

		truth_by_realm_key.erase(key)

	var groups: Dictionary = {
		"executive": [],
		"cabinet": [],
		"senate": [],
		"supreme_court": [],
		"governors": [],
		"citizens": []
	}

	var all_nodes: Array = []
	var state_names: Array = PopulationCardContractEngine.UNITED_STATES_STATE_NAMES.duplicate(true)
	var cabinet_titles: Array = _us_cabinet_titles()

	var vice_president: Dictionary = _make_truth_person(
		realm_id,
		realm_name,
		_truth_id(realm_id, 100, 0),
		"Vice President",
		"executive",
		"",
		"Independent",
		45
	)
	groups ["executive"].append(vice_president)
	all_nodes.append(vice_president)

	for i in range(cabinet_titles.size()):
		var cabinet_node: Dictionary = _make_truth_person(
			realm_id,
			realm_name,
			_truth_id(realm_id, 200, i),
			str(cabinet_titles [i]),
			"cabinet",
			"",
			"",
			42 + int(i % 20)
		)
		groups ["cabinet"].append(cabinet_node)
		all_nodes.append(cabinet_node)

	for i in range(US_SENATE_TARGET):
		var state_index: int = int(floor(float(i) / 2.0)) % state_names.size()
		var state_name: String = str(state_names [state_index])
		var party: String = "Democratic" if i % 2 == 0 else "Republican"
		var senator: Dictionary = _make_truth_person(
			realm_id,
			realm_name,
			_truth_id(realm_id, 300, i),
			"%s Senator of %s" % [party, state_name],
			"senate",
			state_name,
			party,
			30 + int(i % 36)
		)
		groups ["senate"].append(senator)
		all_nodes.append(senator)

	for i in range(US_SUPREME_COURT_TARGET):
		var justice_title: String = "Chief Justice" if i == 0 else "Supreme Court Justice"
		var justice: Dictionary = _make_truth_person(
			realm_id,
			realm_name,
			_truth_id(realm_id, 500, i),
			justice_title,
			"judicial",
			"",
			"",
			45 + int(i % 28)
		)
		groups ["supreme_court"].append(justice)
		all_nodes.append(justice)

	for i in range(US_GOVERNOR_TARGET):
		var governor_state: String = str(state_names [i % state_names.size()])
		var governor_party: String = "Republican" if i % 2 == 0 else "Democratic"
		var governor: Dictionary = _make_truth_person(
			realm_id,
			realm_name,
			_truth_id(realm_id, 600, i),
			"%s Governor of %s" % [governor_party, governor_state],
			"state_governor",
			governor_state,
			governor_party,
			35 + int(i % 30)
		)
		groups ["governors"].append(governor)
		all_nodes.append(governor)

	for i in range(US_CITIZEN_TARGET):
		var citizen: Dictionary = _make_citizen_truth_person(
			realm_id,
			realm_name,
			_truth_id(realm_id, 700, i),
			i
		)
		groups ["citizens"].append(citizen)
		all_nodes.append(citizen)

	var packet: Dictionary = {
		"schema": "eralife.truth_resolution.population_government_packet",
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"country": "United States",
		"government_model": "federal_presidential_republic",
		"truth_complete": true,
		"groups": groups.duplicate(true),
		"all_nodes": all_nodes.duplicate(true),
		"counts": {
			"executive_truth_nodes": groups ["executive"].size(),
			"cabinet": groups ["cabinet"].size(),
			"senate": groups ["senate"].size(),
			"supreme_court": groups ["supreme_court"].size(),
			"governors": groups ["governors"].size(),
			"citizens": groups ["citizens"].size()
		},
		"ui_is_renderer_only": true,
		"resolved_at_ms": int(Time.get_ticks_msec())
	}

	var ontology_only_ready_gate: bool = bool(context.get("ready_gate_truth_resolution", false)) \
or bool(context.get("ontology_only_ready_gate", false)) \
or bool(context.get("skip_runtime_materialization", false))

	packet ["truth_resolution_stage"] = "ontology_only_ready_gate" if ontology_only_ready_gate else "full_runtime_hydration"
	packet ["runtime_people_materialization_deferred"] = ontology_only_ready_gate
	packet ["global_node_ingestion_deferred"] = ontology_only_ready_gate
	packet ["persistent_ontology_complete"] = true
	packet ["hydration_optional"] = true

	_seal_united_states_truth_to_realm_and_scenario(realm_id, realm_name, packet)

	truth_by_realm_key [key] = packet

	if not ontology_only_ready_gate:
		_materialize_truth_nodes_as_runtime_people(packet)
		_ingest_truth_nodes_into_global_node_engine(realm_id, realm_name, packet, context)

	_commit_registry()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"reason": "united_states_population_and_government_truth_resolved",
		"realm_id": realm_id,
		"realm_name": realm_name,
		"counts": packet ["counts"].duplicate(true),
		"persistent_ontology_complete": true,
		"runtime_people_materialized": not ontology_only_ready_gate,
		"runtime_people_materialization_deferred": ontology_only_ready_gate,
		"ui_is_renderer_only": true
	}
func _materialize_truth_nodes_as_runtime_people(packet: Dictionary) -> void:
	if gs == null:
		return

	var all_nodes: Array = packet.get("all_nodes", []) if typeof(packet.get("all_nodes", [])) == TYPE_ARRAY else []
	if all_nodes.is_empty():
		return

	if not ("npcs" in gs) or typeof(gs.npcs) != TYPE_ARRAY:
		return

	var existing_by_id: Dictionary = {}

	if "npcs" in gs:
		for raw_npc in gs.npcs:
			if raw_npc == null:
				continue
			var npc_id: int = int(_value(raw_npc, "id", -1))
			if npc_id > 0:
				existing_by_id [npc_id] = raw_npc

	if gs.player != null:
		var player_id: int = int(_value(gs.player, "id", -1))
		if player_id > 0:
			existing_by_id [player_id] = gs.player

	for raw_node in all_nodes:
		if typeof(raw_node) != TYPE_DICTIONARY:
			continue

		var node: Dictionary = raw_node
		var person_id: int = int(node.get("id", -1))
		if person_id <= 0:
			continue

		var person = existing_by_id.get(person_id, null)
		if person == null:
			person = Person.new()
			person.id = person_id
			gs.npcs.append(person)
			existing_by_id [person_id] = person

		_apply_truth_node_to_runtime_person(person, node)

		if "next_id" in gs:
			gs.next_id = maxi(int(gs.next_id), person_id + 1)

	if gs.has_method("_rebuild_npc_index"):
		gs._rebuild_npc_index()


func _apply_truth_node_to_runtime_person(person, node: Dictionary) -> void:
	if person == null or typeof(node) != TYPE_DICTIONARY:
		return

	person.first_name = str(node.get("first_name", "Jordan")).strip_edges()
	person.last_name = str(node.get("last_name", "Brooks")).strip_edges()
	person.name = "%s %s" % [person.first_name, person.last_name]
	person.age = int(node.get("age", 30))
	person.alive = bool(node.get("alive", true))
	person.realm_id = int(node.get("realm_id", -1))
	person.home_country = str(node.get("home_country", "United States")).strip_edges()
	person.birth_country = str(node.get("birth_country", person.home_country)).strip_edges()
	person.home_state = str(node.get("home_state", "")).strip_edges()
	person.birth_state = str(node.get("birth_state", "")).strip_edges()
	person.job = str(node.get("job", "")).strip_edges()
	person.civic_title = str(node.get("civic_title", person.job)).strip_edges()
	person.social_class = str(node.get("social_class", "Upper Class")).strip_edges()
	person.is_royal = false
	person.is_ruler = bool(node.get("is_ruler", false))
	person.royal_title = ""
	person.succession_rank = 99

	var contract_raw: Variant = node.get("civic_office_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		person.civic_office_contract = (contract_raw as Dictionary).duplicate(true)


func _seal_united_states_truth_to_realm_and_scenario(realm_id: int, _realm_name: String, packet: Dictionary) -> void:
	if gs == null or realm_id <= 0:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var groups: Dictionary = packet.get("groups", {}) if typeof(packet.get("groups", {})) == TYPE_DICTIONARY else {}

	var cabinet_ids: Array = _truth_ids_from_group(groups, "cabinet")
	var senate_ids: Array = _truth_ids_from_group(groups, "senate")
	var supreme_court_ids: Array = _truth_ids_from_group(groups, "supreme_court")
	var governor_ids: Array = _truth_ids_from_group(groups, "governors")
	var citizen_ids: Array = _truth_ids_from_group(groups, "citizens")
	var executive_ids: Array = _truth_ids_from_group(groups, "executive")

	var president_id: int = int(gs.scenario_state.get("presidential_parent_contract_president_id", -1))
	var first_partner_id: int = int(gs.scenario_state.get("presidential_parent_contract_first_partner_id", -1))

	if president_id > 0 and not executive_ids.has(president_id):
		executive_ids.insert(0, president_id)

	if first_partner_id > 0 and not executive_ids.has(first_partner_id):
		executive_ids.append(first_partner_id)

	gs.scenario_state ["presidential_parent_contract_federal_executive_ids"] = executive_ids.duplicate(true)
	gs.scenario_state ["presidential_parent_contract_federal_cabinet_ids"] = cabinet_ids.duplicate(true)
	gs.scenario_state ["presidential_parent_contract_federal_senate_ids"] = senate_ids.duplicate(true)
	gs.scenario_state ["presidential_parent_contract_federal_supreme_court_ids"] = supreme_court_ids.duplicate(true)
	gs.scenario_state ["presidential_parent_contract_federal_governor_ids"] = governor_ids.duplicate(true)
	gs.scenario_state ["presidential_parent_contract_federal_citizen_ids"] = citizen_ids.duplicate(true)

	gs.scenario_state ["presidential_parent_contract_federal_population_complete"] = true
	gs.scenario_state ["presidential_parent_contract_federal_population_stream_complete"] = true
	gs.scenario_state ["presidential_parent_contract_federal_population_stream_running"] = false
	gs.scenario_state ["presidential_parent_contract_federal_population_pending_after_player_control"] = false
	gs.scenario_state ["presidential_parent_contract_federal_population_deferred_before_ready"] = false
	gs.scenario_state ["presidential_parent_contract_federal_population_blocks_ready"] = false
	gs.scenario_state ["presidential_parent_contract_us_realm_id"] = realm_id

	if gs.player != null:
		var player_country: String = str(_value(gs.player, "home_country", _value(gs.player, "birth_country", ""))).strip_edges().to_lower()
		if player_country in ["united states", "united states of america", "usa", "u.s.", "u.s.a.", "america"]:
			gs.player.realm_id = realm_id
			gs.scenario_state ["player_realm_id_corrected_by_truth_resolution"] = realm_id

	if gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var realm_raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		var realm: Dictionary = realm_raw if typeof(realm_raw) == TYPE_DICTIONARY else {}

		var president = _person_by_id_safe(president_id)
		var president_name: String = _truth_person_display_name(president)

		realm ["id"] = realm_id
		realm ["realm_id"] = realm_id
		realm ["name"] = "United States"
		realm ["country"] = "United States"
		realm ["government_style"] = "Republic"
		realm ["government_model"] = "federal_presidential_republic"
		realm ["federal_republic_population_contract"] = true
		realm ["federal_republic_population_stream_complete"] = true
		realm ["federal_republic_population_blocks_ready"] = false
		realm ["ruler_id"] = president_id
		realm ["ruler_npc_id"] = president_id
		realm ["leader_id"] = president_id
		realm ["president_person_id"] = president_id
		realm ["first_partner_person_id"] = first_partner_id
		realm ["ruler_name"] = president_name
		realm ["leader_name"] = president_name
		realm ["leader_title"] = "President of the United States"
		realm ["surface_ruler_office"] = "President of the United States"
		realm ["federal_executive_person_ids"] = executive_ids.duplicate(true)
		realm ["federal_cabinet_person_ids"] = cabinet_ids.duplicate(true)
		realm ["federal_senate_person_ids"] = senate_ids.duplicate(true)
		realm ["federal_supreme_court_person_ids"] = supreme_court_ids.duplicate(true)
		realm ["federal_governor_person_ids"] = governor_ids.duplicate(true)
		realm ["federal_citizen_person_ids"] = citizen_ids.duplicate(true)

		gs.realm_engine.realms [realm_id] = realm


func _truth_ids_from_group(groups: Dictionary, key: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var group_raw: Variant = groups.get(key, [])
	var group: Array = group_raw if typeof(group_raw) == TYPE_ARRAY else []

	for raw_node in group:
		if typeof(raw_node) != TYPE_DICTIONARY:
			continue

		var node: Dictionary = raw_node
		var person_id: int = int(node.get("id", -1))
		if person_id <= 0:
			continue
		if seen.has(person_id):
			continue

		out.append(person_id)
		seen [person_id] = true

	return out


func _person_by_id_safe(person_id: int):
	if gs == null or person_id <= 0:
		return null
	if gs.player != null and int(_value(gs.player, "id", -1)) == person_id:
		return gs.player
	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(person_id)
	if gs.has_method("get_or_reactivate_npc_by_id"):
		return gs.get_or_reactivate_npc_by_id(person_id)
	return null


func _truth_person_display_name(person) -> String:
	if person == null:
		return "Unknown"

	var first_name: String = str(_value(person, "first_name", "")).strip_edges()
	var last_name: String = str(_value(person, "last_name", "")).strip_edges()
	var full_name: String = "%s %s" % [first_name, last_name]
	full_name = full_name.strip_edges()

	if full_name != "":
		return full_name

	return str(_value(person, "name", "Unknown")).strip_edges()


func _resolve_generic_realm_population_truth(realm_id: int, realm_name: String, context: Dictionary = {}) -> Dictionary:
	var key: String = _realm_key(realm_id, realm_name)

	if truth_by_realm_key.has(key):
		var existing: Dictionary = truth_by_realm_key.get(key, {})
		if bool(existing.get("truth_complete", false)):
			return {
				"success": true,
				"reason": "truth_already_resolved",
				"realm_id": realm_id,
				"realm_name": realm_name,
				"schema": ENGINE_SCHEMA
			}

	var citizens: Array = []
	var all_nodes: Array = []

	for i in range(GENERIC_REALM_CITIZEN_TARGET):
		var citizen: Dictionary = _make_citizen_truth_person(
			realm_id,
			realm_name,
			_truth_id(realm_id, 900, i),
			i
		)
		citizens.append(citizen)
		all_nodes.append(citizen)

	var groups: Dictionary = {
		"citizens": citizens
	}

	var packet: Dictionary = {
		"schema": "eralife.truth_resolution.population_government_packet",
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"truth_complete": true,
		"groups": groups.duplicate(true),
		"all_nodes": all_nodes.duplicate(true),
		"counts": {
			"citizens": citizens.size()
		},
		"ui_is_renderer_only": true,
		"resolved_at_ms": int(Time.get_ticks_msec())
	}

	truth_by_realm_key [key] = packet
	_ingest_truth_nodes_into_global_node_engine(realm_id, realm_name, packet, context)
	_commit_registry()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"reason": "generic_realm_population_truth_resolved",
		"realm_id": realm_id,
		"realm_name": realm_name,
		"counts": packet ["counts"].duplicate(true),
		"ui_is_renderer_only": true
	}


func _make_truth_person(
	realm_id: int,
	realm_name: String,
	person_id: int,
	role_label: String,
	branch: String,
	state_name: String,
	party: String,
	age: int
) -> Dictionary:
	var clean_role: String = str(role_label).strip_edges()
	var clean_branch: String = str(branch).strip_edges().to_lower()
	var clean_state: String = str(state_name).strip_edges()
	var clean_party: String = str(party).strip_edges()

	var first_name: String = _first_name_for(person_id)
	var last_name: String = _last_name_for(person_id)

	var contract: Dictionary = {
		"schema": "eralife.civic_office_contract",
		"version": 1,
		"government_model": "federal_presidential_republic",
		"country": "United States",
		"realm_id": realm_id,
		"realm_name": realm_name,
		"role_label": clean_role,
		"office": _office_key_for_role(clean_role, clean_branch),
		"branch": clean_branch,
		"state_name": clean_state,
		"party": clean_party,
		"truth_resolution_source": true,
		"ui_is_renderer_only": true
	}

	return {
		"id": person_id,
		"first_name": first_name,
		"last_name": last_name,
		"age": age,
		"alive": true,
		"realm_id": realm_id,
		"home_country": "USA",
		"birth_country": "USA",
		"home_state": clean_state,
		"birth_state": clean_state,
		"job": clean_role,
		"civic_title": clean_role,
		"civic_office_contract": contract.duplicate(true),
		"social_class": "Upper Class",
		"is_royal": false,
		"is_ruler": false,
		"royal_title": "",
		"succession_rank": 99,
		"parents": [],
		"children": [],
		"partner": null,
	}


func _make_citizen_truth_person(
	realm_id: int,
	realm_name: String,
	person_id: int,
	index: int
) -> Dictionary:
	var identity: Dictionary = (
		_truth_identity_for_realm(
			realm_id,
			realm_name,
			person_id,
			index
		)
	)
	var era_name: String = str(
		identity.get(
			"era_name",
			"Modern Era"
		)
	)
	var civilian_profile: Dictionary = (
		_truth_civilian_profile_for_index(
			era_name,
			index
		)
	)
	var job: String = str(
		civilian_profile.get(
			"job",
			"Resident"
		)
	)
	var social_class: String = str(
		civilian_profile.get(
			"social_class",
			"Commoner"
		)
	)

	return {
		"id": person_id,
		"first_name": str(
			identity.get(
				"first_name",
				"Resident"
			)
		),
		"last_name": str(
			identity.get(
				"last_name",
				""
			)
		),
		"name": str(
			identity.get(
				"display_name",
				"Resident"
			)
		),
		"display_name": str(
			identity.get(
				"display_name",
				"Resident"
			)
		),
		"gender": str(
			identity.get(
				"gender",
				"Unknown"
			)
		),
		"age": 18 + int(
			posmod(
				index * 5 + person_id,
				58
			)
		),
		"alive": true,
		"realm_id": realm_id,
		"home_country": realm_name,
		"birth_country": realm_name,
		"home_city": str(
			identity.get(
				"city",
				""
			)
		),
		"birth_city": str(
			identity.get(
				"city",
				""
			)
		),
		"job": job,
		"role_label": job,
		"civic_title": "",
		"civic_office_contract": {},
		"government_branch": "civilian",
		"social_class": social_class,
		"is_royal": false,
		"is_ruler": false,
		"royal_title": "",
		"succession_rank": 99,
		"parents": [],
		"children": [],
		"partner": null,
		"approval": 35 + int(
			posmod(
				person_id,
				56
			)
		),
		"influence": 20 + int(
			posmod(
				person_id * 3,
				61
			)
		),
		"truth_state": "partial",
		"truth_resolution_stage": "observable",
		"era_name": era_name,
	}
func _make_generic_realm_role_truth_person(
	realm_id: int,
	realm_name: String,
	person_id: int,
	index: int,
	role_label: String,
	branch: String,
	social_class: String,
	is_royal: bool,
	is_ruler: bool
) -> Dictionary:
	var identity: Dictionary = (
		_truth_identity_for_realm(
			realm_id,
			realm_name,
			person_id,
			index
		)
	)
	var profile: Dictionary = (
		_generic_realm_government_profile(
			realm_id,
			realm_name
		)
	)
	var leader_contract_raw: Variant = profile.get(
		"leader_identity_contract",
		{}
	)
	var leader_contract: Dictionary = (
		leader_contract_raw as Dictionary
		if typeof(
			leader_contract_raw
		) == TYPE_DICTIONARY
		else {}
	)
	var first_name: String = str(
		identity.get(
			"first_name",
			"Resident"
		)
	)
	var last_name: String = str(
		identity.get(
			"last_name",
			""
		)
	)
	var display_name: String = str(
		identity.get(
			"display_name",
			"Resident"
		)
	)
	var resolved_role: String = str(
		role_label
	).strip_edges()

	if (
		is_ruler
		and not leader_contract.is_empty()
	):
		var leader_first: String = str(
			leader_contract.get(
				"first_name",
				""
			)
		).strip_edges()
		var leader_last: String = str(
			leader_contract.get(
				"last_name",
				""
			)
		).strip_edges()
		var leader_name: String = str(
			leader_contract.get(
				"leader_name",
				leader_contract.get(
					"display_name",
					""
				)
			)
		).strip_edges()
		var leader_title: String = str(
			leader_contract.get(
				"leader_title",
				""
			)
		).strip_edges()

		if leader_first != "":
			first_name = leader_first

		if leader_last != "":
			last_name = leader_last

		if leader_name != "":
			display_name = leader_name
		else:
			display_name = (
				"%s %s"
				% [
					first_name,
					last_name
				]
			).strip_edges()

		if leader_title != "":
			resolved_role = leader_title

	if resolved_role == "":
		resolved_role = "Realm Official"

	return {
		"id": person_id,
		"first_name": first_name,
		"last_name": last_name,
		"name": display_name,
		"display_name": display_name,
		"gender": str(
			identity.get(
				"gender",
				"Unknown"
			)
		),
		"age": 24 + int(
			posmod(
				index * 7 + person_id,
				48
			)
		),
		"alive": true,
		"realm_id": realm_id,
		"home_country": realm_name,
		"birth_country": realm_name,
		"home_city": str(
			identity.get(
				"city",
				""
			)
		),
		"birth_city": str(
			identity.get(
				"city",
				""
			)
		),
		"job": resolved_role,
		"role_label": resolved_role,
		"civic_title": (
			""
			if is_royal
			else resolved_role
		),
		"civic_office_contract": {
			"office": resolved_role,
			"role_label": resolved_role,
			"branch": branch,
			"realm_id": realm_id,
			"realm_name": realm_name
		},
		"government_branch": branch,
		"social_class": social_class,
		"is_royal": is_royal,
		"is_ruler": is_ruler,
		"royal_title": (
			resolved_role
			if is_royal
			else ""
		),
		"succession_rank": (
			0
			if is_ruler
			else (
				index + 1
				if branch == "royal_court"
				else 99
			)
		),
		"parents": [],
		"children": [],
		"partner": null,
		"approval": 45 + int(
			posmod(
				person_id,
				46
			)
		),
		"influence": 40 + int(
			posmod(
				person_id * 3,
				56
			)
		),
		"truth_state": "partial",
		"truth_resolution_stage": "observable",
		"era_name": str(
			identity.get(
				"era_name",
				"Modern Era"
			)
		),
	}
func _generic_realm_runtime_person_role_label(
	person: Person,
	fallback: String
) -> String:
	if person == null:
		return str(
			fallback
		).strip_edges()

	for raw_value in [
		person.royal_title,
		person.civic_title,
		person.job,
		fallback
	]:
		var value: String = str(
			raw_value
		).strip_edges()

		if value != "":
			return value

	return "Realm Official"


func _generic_realm_runtime_people(
	realm_id: int
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	if gs == null:
		return out

	if (
		gs.player != null
		and gs.player.alive
		and int(
			gs.player.realm_id
		) == realm_id
	):
		var player_id: int = int(
			gs.player.id
		)

		if player_id > 0:
			seen [
				player_id
			] = true
			out.append(
				gs.player
			)

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc

		if (
			npc == null
			or not npc.alive
			or int(
				npc.realm_id
			) != realm_id
		):
			continue

		var npc_id: int = int(
			npc.id
		)

		if (
			npc_id <= 0
			or seen.has(
				npc_id
			)
		):
			continue

		seen [
			npc_id
		] = true
		out.append(
			npc
		)

	return out


func _generic_realm_live_authority_people(
	realm_id: int,
	shard_kind: String
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var realm: Dictionary = (
		_truth_realm_dictionary(
			realm_id
		)
	)
	var ruler_id: int = int(
		realm.get(
			"ruler_id",
			-1
		)
	)
	var ruler: Person = (
		_person_by_id_safe(
			ruler_id
		) as Person
		if ruler_id > 0
		else null
	)

	if (
		ruler == null
		or not ruler.alive
		or int(
			ruler.realm_id
		) != realm_id
	):
		ruler = null

		for raw_person in _generic_realm_runtime_people(
			realm_id
		):
			var candidate: Person = raw_person

			if (
				candidate != null
				and candidate.alive
				and bool(
					candidate.is_ruler
				)
			):
				ruler = candidate
				break

	var clean_kind: String = str(
		shard_kind
	).strip_edges().to_lower()

	if clean_kind == "sovereign":
		if ruler != null:
			out.append(
				ruler
			)

		return out

	if clean_kind == "royal_court":
		if (
			ruler != null
			and ruler.partner != null
			and ruler.partner.alive
			and int(
				ruler.partner.realm_id
			) == realm_id
		):
			var partner_id: int = int(
				ruler.partner.id
			)

			if partner_id > 0:
				seen [
					partner_id
				] = true
				out.append(
					ruler.partner
				)

		var ranked_royals: Array = []

		for raw_person in _generic_realm_runtime_people(
			realm_id
		):
			var person: Person = raw_person

			if (
				person == null
				or not person.alive
			):
				continue

			var person_id: int = int(
				person.id
			)

			if (
				person_id <= 0
				or person_id == ruler_id
				or seen.has(
					person_id
				)
			):
				continue

			var has_royal_truth: bool = (
				bool(
					person.is_royal
				)
				or bool(
					person.is_ruler
				)
				or str(
					person.royal_title
				).strip_edges() != ""
				or (
					int(
						person.succession_rank
					) > 0
					and int(
						person.succession_rank
					) < 99
				)
			)

			if not has_royal_truth:
				continue

			ranked_royals.append(
				person
			)

		ranked_royals.sort_custom(
			func (
				left_raw,
				right_raw
			) -> bool:
				var left: Person = left_raw
				var right: Person = right_raw
				var left_rank: int = int(
					left.succession_rank
				)
				var right_rank: int = int(
					right.succession_rank
				)

				if left_rank != right_rank:
					return left_rank < right_rank

				return int(
					left.id
				) < int(
					right.id
				)
		)

		for raw_person in ranked_royals:
			var person: Person = raw_person
			var person_id: int = int(
				person.id
			)

			if seen.has(
				person_id
			):
				continue

			seen [
				person_id
			] = true
			out.append(
				person
			)

		return out

	if clean_kind == "noble_court":
		for raw_person in _generic_realm_runtime_people(
			realm_id
		):
			var person: Person = raw_person

			if (
				person == null
				or not person.alive
			):
				continue

			var person_id: int = int(
				person.id
			)

			if (
				person_id <= 0
				or person_id == ruler_id
				or seen.has(
					person_id
				)
			):
				continue

			var social_class: String = str(
				person.social_class
			).strip_edges().to_lower()
			var title: String = str(
				person.royal_title
			).strip_edges().to_lower()
			var noble_truth: bool = (
				social_class == "noble"
				or title.contains(
					"duke"
				)
				or title.contains(
					"duchess"
				)
				or title.contains(
					"lord"
				)
				or title.contains(
					"lady"
				)
				or title.contains(
					"count"
				)
				or title.contains(
					"marqu"
				)
			)

			if not noble_truth:
				continue

			seen [
				person_id
			] = true
			out.append(
				person
			)

	return out


func _generic_realm_truth_node_from_runtime_person(
	person: Person,
	realm_id: int,
	realm_name: String,
	shard_kind: String,
	fallback_role: String
) -> Dictionary:
	if person == null:
		return {}

	var display_name: String = (
		_truth_person_display_name(
			person
		)
	)
	var role_label: String = (
		_generic_realm_runtime_person_role_label(
			person,
			fallback_role
		)
	)
	var civic_contract: Dictionary = (
		person.civic_office_contract.duplicate(
			false
		)
		if typeof(
			person.civic_office_contract
		) == TYPE_DICTIONARY
		else {}
	)
	var home_country: String = str(
		person.home_country
	).strip_edges()
	var birth_country: String = str(
		person.birth_country
	).strip_edges()

	if home_country == "":
		home_country = realm_name

	if birth_country == "":
		birth_country = realm_name

	return {
		"id": int(
			person.id
		),
		"person_id": int(
			person.id
		),
		"first_name": str(
			person.first_name
		),
		"last_name": str(
			person.last_name
		),
		"name": display_name,
		"display_name": display_name,
		"gender": str(
			person.gender
		),
		"age": int(
			person.age
		),
		"alive": bool(
			person.alive
		),
		"realm_id": realm_id,
		"home_country": home_country,
		"birth_country": birth_country,
		"home_city": str(
			person.home_city
		),
		"birth_city": str(
			person.birth_city
		),
		"job": str(
			person.job
		),
		"role_label": role_label,
		"civic_title": str(
			person.civic_title
		),
		"civic_office_contract": civic_contract,
		"government_branch": shard_kind,
		"social_class": str(
			person.social_class
		),
		"is_royal": bool(
			person.is_royal
		),
		"is_ruler": bool(
			person.is_ruler
		),
		"royal_title": str(
			person.royal_title
		),
		"succession_rank": int(
			person.succession_rank
		),
		"approval": int(
			person.approval
		),
		"influence": int(
			person.fame
		),
		"truth_state": "hot",
		"truth_resolution_stage": "runtime_person",
		"runtime_person_hot": true,
		"synthetic_vacancy_fill": false,
		"runtime_identity_authoritative": true,
	}
func _resolve_generic_role_truth_shard(
	groups: Dictionary,
	realm_id: int,
	realm_name: String,
	shard_kind: String,
	start_index: int,
	count: int
) -> void:
	var group: Array = (
		groups.get(
			shard_kind,
			[]
		)
		if typeof(
			groups.get(
				shard_kind,
				[]
			)
		) == TYPE_ARRAY
		else []
	)
	var profile: Dictionary = (
		_generic_realm_government_profile(
			realm_id,
			realm_name
		)
	)
	var roles: Array = (
		_generic_realm_role_titles(
			profile,
			shard_kind
		)
	)
	var live_authority_people: Array = (
		_generic_realm_live_authority_people(
			realm_id,
			shard_kind
		)
	)
	var base_salt: int = 800
	var social_class: String = "Government"
	var is_royal: bool = false

	match shard_kind:
		"sovereign":
			base_salt = 810
			social_class = "Sovereign"
			is_royal = true

		"royal_court":
			base_salt = 820
			social_class = "Royal Family"
			is_royal = true

		"noble_court":
			base_salt = 830
			social_class = "Nobility"

		"executive":
			base_salt = 840
			social_class = "Government"

		"legislative":
			base_salt = 850
			social_class = "Government"

		"judicial":
			base_salt = 860
			social_class = "Government"

		"military_command":
			base_salt = 870
			social_class = "Military Elite"

		"masters":
			base_salt = 880
			social_class = "Master Class"

	for i in range(
		start_index,
		start_index + count
	):
		var role_label: String = (
			str(
				roles [
					i % roles.size()
				]
			)
			if not roles.is_empty()
			else "Realm Official"
		)
		var node: Dictionary = {}



		if (
			i >= 0
			and i < live_authority_people.size()
		):
			var runtime_person: Person = (
				live_authority_people [
					i
				] as Person
			)

			if (
				runtime_person != null
				and runtime_person.alive
			):
				node = (
					_generic_realm_truth_node_from_runtime_person(
						runtime_person,
						realm_id,
						realm_name,
						shard_kind,
						role_label
					)
				)


		if node.is_empty():
			node = (
				_make_generic_realm_role_truth_person(
					realm_id,
					realm_name,
					_truth_id(
						realm_id,
						base_salt,
						i
					),
					i,
					role_label,
					shard_kind,
					social_class,
					is_royal,
					shard_kind == "sovereign"
				)
			)
			node [
				"synthetic_vacancy_fill"
			] = true
			node [
				"runtime_identity_authoritative"
			] = false

		_append_truth_group_node_unique(
			group,
			node
		)

	groups [
		shard_kind
	] = group
func _ingest_truth_nodes_into_global_node_engine(realm_id: int, realm_name: String, packet: Dictionary, context: Dictionary = {}) -> void:
	if gs == null:
		return
	if gs.global_node_contract_engine == null:
		gs.global_node_contract_engine = GlobalNodeContractEngine.new(gs)
	if gs.global_node_contract_engine == null:
		return
	if not gs.global_node_contract_engine.has_method("ingest_node_graph_packet"):
		return

	var nodes_by_id: Dictionary = {}
	var all_nodes: Array = packet.get("all_nodes", []) if typeof(packet.get("all_nodes", [])) == TYPE_ARRAY else []

	for raw_node in all_nodes:
		if typeof(raw_node) != TYPE_DICTIONARY:
			continue

		var node: Dictionary = raw_node
		var person_id: int = int(node.get("id", -1))
		if person_id <= 0:
			continue

		var node_id: String = "truth_person:%d" % person_id
		nodes_by_id [node_id] = {
			"schema": "eralife.truth_resolution.global_node_packet",
			"id": node_id,
			"person_id": person_id,
			"display_name": "%s %s" % [str(node.get("first_name", "")), str(node.get("last_name", ""))],
			"realm_id": realm_id,
			"realm_name": realm_name,
			"role_label": str(node.get("job", "")),
			"source_engine": ENGINE_SCHEMA,
			"ui_is_renderer_only": true
		}

	gs.global_node_contract_engine.ingest_node_graph_packet(
		"truth_resolution_population_government",
		{
			"schema": "eralife.truth_resolution.global_node_graph_packet",
			"version": CONTRACT_VERSION,
			"scope_id": "truth_population_government:%d" % realm_id,
			"realm_id": realm_id,
			"realm_name": realm_name,
			"nodes_by_id": nodes_by_id,
			"edges": [],
			"truth_complete": true,
			"ui_is_renderer_only": true
		},
		{
			"source": ENGINE_SCHEMA,
			"realm_id": realm_id,
			"realm_name": realm_name,
			"ui_is_renderer_only": true
		}.merged(context, true)
	)


func _resolve_realm_ids(realm_ids: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_realm_id in realm_ids:
		var realm_id: int = int(raw_realm_id)
		if realm_id <= 0:
			continue
		if seen.has(realm_id):
			continue

		out.append(realm_id)
		seen [realm_id] = true

	if out.is_empty() and gs != null and gs.player != null:
		var player_realm_id: int = int(_value(gs.player, "realm_id", -1))
		if player_realm_id > 0 and not seen.has(player_realm_id):
			out.append(player_realm_id)
			seen [player_realm_id] = true

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var us_realm_id: int = int(gs.scenario_state.get("presidential_parent_contract_us_realm_id", -1))
		if us_realm_id > 0 and not seen.has(us_realm_id):
			out.append(us_realm_id)
			seen [us_realm_id] = true

	return out

func _realm_name_for_id(realm_id: int) -> String:
	if gs != null and gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(raw) == TYPE_DICTIONARY:
			var realm: Dictionary = raw
			var name: String = str(realm.get("name", realm.get("country", ""))).strip_edges()
			if name != "":
				return name

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		if int(gs.scenario_state.get("presidential_parent_contract_us_realm_id", -1)) == realm_id:
			return "United States"

	return "Realm %d" % realm_id


func _realm_key(realm_id: int, realm_name: String) -> String:
	return "%d:%s" % [realm_id, str(realm_name).strip_edges().to_lower()]


func _is_united_states_realm(realm_id: int, realm_name: String) -> bool:
	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		if int(gs.scenario_state.get("presidential_parent_contract_us_realm_id", -1)) == realm_id:
			return true

	var key: String = str(realm_name).strip_edges().to_lower()
	return key in [
		"united states",
		"united states of america",
		"usa",
		"u.s.",
		"u.s.a.",
		"america"
	]


func _truth_id(realm_id: int, band: int, index: int) -> int:
	return 800000000 + (realm_id * 10000) + (band * 100) + index


func _first_name_for(truth_seed: int) -> String:
	var names: Array = [
		"Jordan",
		"Morgan",
		"Taylor",
		"Casey",
		"Riley",
		"Avery",
		"Cameron",
		"Quinn",
		"Reese",
		"Parker",
		"Dakota",
		"Rowan"
	]

	var name_index: int = abs(truth_seed) % names.size()
	return str(names [name_index])

func _last_name_for(truth_seed: int) -> String:
	var names: Array = [
		"Brooks",
		"Hayes",
		"Carter",
		"Reed",
		"Bennett",
		"Price",
		"Foster",
		"Bell",
		"Ward",
		"Ross",
		"Cooper",
		"Bailey"
	]

	var shifted_seed: int = int(floor(abs(float(truth_seed)) / 7.0))
	var name_index: int = shifted_seed % names.size()
	return str(names [name_index])


func _us_cabinet_titles() -> Array:
	return [
		"Secretary of State",
		"Secretary of the Treasury",
		"Secretary of Defense",
		"Attorney General",
		"Secretary of the Interior",
		"Secretary of Agriculture",
		"Secretary of Commerce",
		"Secretary of Labor",
		"Secretary of Health and Human Services",
		"Secretary of Housing and Urban Development",
		"Secretary of Transportation",
		"Secretary of Energy",
		"Secretary of Education",
		"Secretary of Veterans Affairs",
		"Secretary of Homeland Security"
	]


func _office_key_for_role(role_label: String, branch: String) -> String:
	var clean_role: String = str(role_label).strip_edges().to_lower()
	var clean_branch: String = str(branch).strip_edges().to_lower()

	if clean_role.find("vice president") >= 0:
		return "vice president"
	if clean_role.find("president") >= 0 and clean_role.find("vice") < 0:
		return "president"
	if clean_role.find("senator") >= 0:
		return "senator"
	if clean_role.find("governor") >= 0:
		return "governor"
	if clean_role.find("chief justice") >= 0:
		return "chief justice"
	if clean_role.find("supreme court justice") >= 0:
		return "supreme court justice"
	if clean_role.find("attorney general") >= 0:
		return "attorney general"
	if clean_role.find("secretary") >= 0:
		return clean_role

	match clean_branch:
		"senate":
			return "senator"
		"state_governor":
			return "governor"
		"governor":
			return "governor"
		"judicial":
			return "supreme court justice"
		"supreme_court":
			return "supreme court justice"
		"cabinet":
			return clean_role
		_:
			return clean_role


func _value(source, key: String, fallback = null):
	if source == null:
		return fallback
	if typeof(source) == TYPE_DICTIONARY:
		return (source as Dictionary).get(key, fallback)
	if key in source:
		return source.get(key)
	return fallback


func _commit_registry() -> void:
	if gs == null:
		return

	if bulk_resolution_depth > 0:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}



	gs.scenario_state [
		"truth_resolution_contract_engine_registry"
	] = {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"realm_truth_count": truth_by_realm_key.size(),
		"truth_by_realm_key": (
			truth_by_realm_key.duplicate(false)
		),
		"last_report": last_report.duplicate(false),
		"ready_door_may_not_wait": true,
		"ui_is_renderer_only": true
	}

func _fail(reason: String, context: Dictionary = {}) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	last_report = {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"reason": reason,
		"context": context.duplicate(true),
		"ui_is_renderer_only": true,
		"at_ms": int(Time.get_ticks_msec())
	}
	_commit_registry()
	return last_report.duplicate(true)