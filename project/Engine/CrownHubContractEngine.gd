

extends Resource
class_name CrownHubContractEngine

const ENGINE_SCHEMA:= "eralife.crown_hub_contract_engine"
const ENGINE_VERSION:= 1
const HUB_SCHEMA:= "eralife.crown_hub_contract"
const HUB_VERSION:= 1
const LENS_STATE_KEY:= "crown_hub_lens_state"
signal resident_diplomacy_entry_published(
	actor_id: int,
	entry: Dictionary
)

var resident_crown_war_projection_jobs: Dictionary = {}
var gs
var last_report: Dictionary = {}
var resident_diplomacy_projection_jobs: Dictionary = {}
var resident_crown_contract_by_actor: Dictionary = {}
var resident_crown_action_cycle_by_actor: Dictionary = {}
func _init(
		_gs = null
) -> void:
		gs = _gs




		if (
			gs != null
			and gs.has_method(
				"ensure_war_contract_runtime_authority"
			)
		):
			gs.ensure_war_contract_runtime_authority()

		_ensure_lens_root()


func bootstrap_default_contracts() -> Dictionary:
		_ensure_lens_root()

		var war_authority_report: Dictionary = {}

		if (
			gs != null
			and gs.has_method(
				"ensure_war_contract_runtime_authority"
			)
		):
			war_authority_report = (
				gs.ensure_war_contract_runtime_authority()
			)

		var war_authority_hot: bool = (
			gs != null
			and gs.war_contract_engine != null
		)

		return {
			"success": true,
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"runtime_authority": "royalty_runtime_engine",
			"constitutional_authority": (
				"royalty_contract_engine"
			),
			"mod_authority": (
				"royalty_mod_contract_engine"
			),
			"war_authority": "war_contract_engine",
			"war_authority_hot": war_authority_hot,
			"war_authority_report": (
				war_authority_report.duplicate(false)
			),
			"war_authority_resident_before_observation": (
				war_authority_hot
			),
			"ui_is_renderer_only": true
		}
func _resident_diplomacy_population_rank_realm_key(
	realm_id: int,
	realm: Dictionary
) -> String:
	if bool(
		_resident_diplomacy_entry_is_era_kingdom(
			realm
		)
	):
		return "era_kingdom"




	var realm_name: String = str(
		realm.get(
			"name",
			realm.get(
				"country",
				""
			)
		)
	).strip_edges()

	if realm_name != "":
		var identity_key: String = (
			realm_name
			.to_lower()
			.strip_edges()
			.replace(".", "")
			.replace(",", "")
			.replace("'", "")
			.replace("’", "")
			.replace("-", "")
			.replace("_", "")
			.replace(" ", "")
		)

		if identity_key in [
			"us",
			"usa",
			"america",
			"unitedstates",
			"unitedstatesofamerica"
		]:
			return "realm:united_states"

		if identity_key in [
			"uk",
			"britain",
			"greatbritain",
			"unitedkingdom"
		]:
			return "realm:united_kingdom"

		if identity_key != "":
			return (
				"realm:name:%s"
				% identity_key
			)



	var source_key: String = str(
		realm.get(
			"entry_id",
			realm.get(
				"hidden_realm_id",
				realm.get(
					"realm_key",
					realm.get(
						"id",
						""
					)
				)
			)
		)
	).strip_edges()

	if source_key != "":
		return (
			"realm:source:%s"
			% source_key.to_lower()
		)

	return "realm:id:%d" % realm_id


func _resident_diplomacy_population_rank_contract() -> Dictionary:
	var rows: Array = []
	var seen_keys: Dictionary = {}

	if (
		gs != null
		and gs.realm_engine != null
	):
		var realms_raw: Variant = (
			gs.realm_engine.get(
				"realms"
			)
		)
		if typeof(realms_raw) == TYPE_DICTIONARY:
			var realms: Dictionary = (
				realms_raw as Dictionary
			)

			for raw_realm_id in realms.keys():
				var realm_id: int = int(
					raw_realm_id
				)
				if realm_id <= 0:
					continue

				var realm_raw: Variant = realms.get(
					raw_realm_id,
					{}
				)
				if typeof(realm_raw) != TYPE_DICTIONARY:
					continue

				var realm: Dictionary = (
					realm_raw as Dictionary
				)
				if realm.is_empty():
					continue

				var realm_key: String = (
					_resident_diplomacy_population_rank_realm_key(
						realm_id,
						realm
					)
				)
				if (
					realm_key == ""
					or seen_keys.has(
						realm_key
					)
				):
					continue

				seen_keys [
					realm_key
				] = true

				rows.append({
					"realm_key": realm_key,
					"realm_id": realm_id,
					"country": str(
						realm.get(
							"name",
							"Realm %d" % realm_id
						)
					),
					"population": maxi(
						0,
						int(
							realm.get(
								"population",
								0
							)
						)
					),
					"is_era_kingdom": false
				})

	if (
		gs != null
		and gs.many_realms_engine != null
	):
		var hidden_realms_raw: Variant = (
			gs.many_realms_engine.get(
				"hidden_realms"
			)
		)
		if typeof(hidden_realms_raw) == TYPE_DICTIONARY:
			var hidden_realms: Dictionary = (
				hidden_realms_raw as Dictionary
			)
			var era_kingdom_raw: Variant = (
				hidden_realms.get(
					"era_kingdom",
					{}
				)
			)

			if typeof(era_kingdom_raw) == TYPE_DICTIONARY:
				var era_kingdom: Dictionary = (
					era_kingdom_raw as Dictionary
				)

				if (
					not era_kingdom.is_empty()
					and not seen_keys.has(
						"era_kingdom"
					)
				):
					seen_keys [
						"era_kingdom"
					] = true

					rows.append({
						"realm_key": "era_kingdom",
						"realm_id": int(
							era_kingdom.get(
								"realm_id",
								-1
							)
						),
						"country": str(
							era_kingdom.get(
								"name",
								"Era Kingdom"
							)
						),
						"population": maxi(
							0,
							int(
								era_kingdom.get(
									"population",
									0
								)
							)
						),
						"is_era_kingdom": true
					})

	rows.sort_custom(
		func (
			left_raw: Variant,
			right_raw: Variant
		) -> bool:
			if (
				typeof(left_raw) != TYPE_DICTIONARY
				or typeof(right_raw) != TYPE_DICTIONARY
			):
				return false

			var left: Dictionary = (
				left_raw as Dictionary
			)
			var right: Dictionary = (
				right_raw as Dictionary
			)

			var left_population: int = int(
				left.get(
					"population",
					0
				)
			)
			var right_population: int = int(
				right.get(
					"population",
					0
				)
			)

			if left_population != right_population:
				return (
					left_population
					> right_population
				)




			return str(
				left.get(
					"realm_key",
					""
				)
			) < str(
				right.get(
					"realm_key",
					""
				)
			)
	)

	var rank_by_realm_key: Dictionary = {}
	var ordered_realm_keys: Array = []
	var revision_rows: Array = []

	for index in range(
		rows.size()
	):
		var row: Dictionary = (
			rows [index] as Dictionary
		)
		var realm_key: String = str(
			row.get(
				"realm_key",
				""
			)
		)
		var rank: int = index + 1

		row ["population_rank"] = rank
		row ["population_rank_total"] = rows.size()

		rank_by_realm_key [
			realm_key
		] = row
		ordered_realm_keys.append(
			realm_key
		)
		revision_rows.append(
			"%s:%d:%d"
			% [
				realm_key,
				rank,
				int(
					row.get(
						"population",
						0
					)
				)
			]
		)

	var revision: String = str(
		hash(
			revision_rows
		)
	)

	return {
		"schema": (
			"eralife.crown_hub."
			+ "diplomacy_population_rank_contract"
		),
		"version": 1,
		"rank_by_realm_key": rank_by_realm_key,
		"ordered_realm_keys": ordered_realm_keys,
		"realm_count": rows.size(),
		"revision": revision,
		"ranking_metric": "population_desc",
		"tie_breaker": "realm_key_asc",
		"ui_is_renderer_only": true
	}


func _attach_resident_diplomacy_population_rank(
	entry: Dictionary,
	rank_contract: Dictionary
) -> Dictionary:
	if entry.is_empty():
		return entry

	var out: Dictionary = entry.duplicate(false)

	if not rank_contract.is_empty():
		set_meta(
			"resident_diplomacy_population_rank_cache",
			rank_contract.duplicate(false)
		)

	var realm_key: String = str(
		out.get(
			"realm_key",
			""
		)
	).strip_edges()

	var realm_id: int = int(
		out.get(
			"realm_id",
			-1
		)
	)

	if (
		realm_key == ""
		and realm_id > 0
	):
		realm_key = (
			"realm:%d"
			% realm_id
		)

	var rank_map_raw: Variant = rank_contract.get(
		"rank_by_realm_key",
		{}
	)

	if typeof(
		rank_map_raw
	) != TYPE_DICTIONARY:
		return out

	var rank_map: Dictionary = (
		rank_map_raw as Dictionary
	)

	var rank_row_raw: Variant = rank_map.get(
		realm_key,
		{}
	)



	if (
		typeof(rank_row_raw) != TYPE_DICTIONARY
		and realm_id > 0
	):
		for raw_rank_row in rank_map.values():
			if typeof(
				raw_rank_row
			) != TYPE_DICTIONARY:
				continue

			var candidate: Dictionary = (
				raw_rank_row as Dictionary
			)

			if int(
				candidate.get(
					"realm_id",
					-1
				)
			) == realm_id:
				rank_row_raw = candidate
				break

	if typeof(
		rank_row_raw
	) != TYPE_DICTIONARY:
		return out

	var rank_row: Dictionary = (
		rank_row_raw as Dictionary
	)

	out [
		"population"
	] = int(
		rank_row.get(
			"population",
			out.get(
				"population",
				0
			)
		)
	)
	out [
		"population_rank"
	] = int(
		rank_row.get(
			"population_rank",
			0
		)
	)
	out [
		"population_rank_total"
	] = int(
		rank_row.get(
			"population_rank_total",
			0
		)
	)
	out [
		"population_rank_revision"
	] = str(
		rank_contract.get(
			"revision",
			""
		)
	)
	out [
		"population_rank_metric"
	] = "population_desc"
	out [
		"population_rank_authority"
	] = ENGINE_SCHEMA
	out [
		"population_rank_ui_owned"
	] = false

	return out
func _resident_diplomacy_read_only_person_snapshot(
	person_id: int
) -> Dictionary:
	if (
		gs == null
		or person_id <= 0
	):
		return {}

	if (
		gs.player != null
		and int(gs.player.id) == person_id
	):
		return {
			"person_id": person_id,
			"first_name": str(
				gs.player.first_name
			),
			"last_name": str(
				gs.player.last_name
			),
			"display_name": _person_name(
				gs.player
			),
			"royal_title": str(
				gs.player.royal_title
			),
			"civic_title": str(
				gs.player.civic_title
			),
			"job": str(
				gs.player.job
			),
			"runtime_person_hot": true,
			"dormant_snapshot": false
		}

	var active_npcs_raw: Variant = gs.get(
		"npcs"
	)

	if typeof(active_npcs_raw) == TYPE_ARRAY:
		for raw_person in active_npcs_raw:
			if not raw_person is Person:
				continue

			var person: Person = raw_person as Person

			if int(person.id) != person_id:
				continue

			return {
				"person_id": person_id,
				"first_name": str(
					person.first_name
				),
				"last_name": str(
					person.last_name
				),
				"display_name": _person_name(
					person
				),
				"royal_title": str(
					person.royal_title
				),
				"civic_title": str(
					person.civic_title
				),
				"job": str(
					person.job
				),
				"runtime_person_hot": true,
				"dormant_snapshot": false
			}

	var dormant_npcs_raw: Variant = null

	if "dormant_npcs" in gs:
		dormant_npcs_raw = gs.get(
			"dormant_npcs"
		)

	if typeof(dormant_npcs_raw) != TYPE_DICTIONARY:
		return {}

	var dormant_npcs: Dictionary = (
		dormant_npcs_raw as Dictionary
	)
	var snapshot_raw: Variant = dormant_npcs.get(
		person_id,
		dormant_npcs.get(
			str(person_id),
			{}
		)
	)

	if typeof(snapshot_raw) != TYPE_DICTIONARY:
		return {}

	var snapshot: Dictionary = (
		snapshot_raw as Dictionary
	)
	var first_name: String = str(
		snapshot.get(
			"first_name",
			""
		)
	).strip_edges()
	var last_name: String = str(
		snapshot.get(
			"last_name",
			""
		)
	).strip_edges()
	var display_name: String = str(
		snapshot.get(
			"display_name",
			snapshot.get(
				"name",
				""
			)
		)
	).strip_edges()

	if display_name == "":
		display_name = (
			"%s %s"
			% [
				first_name,
				last_name
			]
		).strip_edges()

	return {
		"person_id": person_id,
		"first_name": first_name,
		"last_name": last_name,
		"display_name": display_name,
		"royal_title": str(
			snapshot.get(
				"royal_title",
				""
			)
		),
		"civic_title": str(
			snapshot.get(
				"civic_title",
				""
			)
		),
		"job": str(
			snapshot.get(
				"job",
				""
			)
		),
		"runtime_person_hot": false,
		"dormant_snapshot": true,
	}
func _attach_war_projection(
	actor: Person,
	contract: Dictionary
) -> Dictionary:
	if (
		actor == null
		or contract.is_empty()
	):
		return contract

	var war_registry: Dictionary = {}

	if (
		gs != null
		and gs.war_contract_engine != null
	):
		war_registry = (
			gs.war_contract_engine
			.emit_war_registry_contract(
				{
					"realm_id": int(
						actor.realm_id
					),
					"actor_id": int(
						actor.id
					),
					"include_global_active_wars": true,
					"source": (
						"crown_hub_contract_engine."
						+ "attach_war_projection"
					)
				}
			)
		)

	var out: Dictionary = (
		_attach_war_registry_shell_projection(
			actor,
			contract,
			war_registry
		)
	)

	out [
		"war_projection_pending"
	] = true
	out [
		"war_projection_complete"
	] = false
	out [
		"war_rows_build_deferred"
	] = true

	return out
func _attach_war_registry_shell_projection(
	actor: Person,
	contract: Dictionary,
	war_registry: Dictionary
) -> Dictionary:
	if (
		actor == null
		or contract.is_empty()
	):
		return contract

	var out: Dictionary = (
		contract.duplicate(false)
	)
	var permissions: Dictionary = _dict(
		out.get(
			"permissions",
			{}
		)
	)
	var can_declare_war: bool = (
		_actor_can_declare_war(
			actor,
			permissions
		)
	)

	permissions [
		"can_declare_war"
	] = can_declare_war
	out [
		"permissions"
	] = permissions

	var diplomacy_entries: Array = _array(
		out.get(
			"diplomacy_country_entries",
			[]
		)
	)

	diplomacy_entries = (
		_patch_diplomacy_entries_with_war_registry(
			diplomacy_entries,
			war_registry
		)
	)

	var include_war_tab: bool = bool(
		war_registry.get(
			"dynamic_war_tab_required",
			false
		)
	)
	var section_surfaces: Dictionary = _dict(
		out.get(
			"section_surfaces",
			{}
		)
	).duplicate(false)

	if not section_surfaces.has(
		"war"
	):
		section_surfaces [
			"war"
		] = []

	out [
		"section_tabs"
	] = _section_tabs(
		include_war_tab
	)
	out [
		"section_surfaces"
	] = section_surfaces
	out [
		"war_registry_contract"
	] = war_registry
	out [
		"diplomacy_country_entries"
	] = diplomacy_entries
	out [
		"has_active_war"
	] = bool(
		war_registry.get(
			"has_active_war",
			false
		)
	)
	out [
		"has_global_active_war"
	] = bool(
		war_registry.get(
			"has_global_active_war",
			false
		)
	)
	out [
		"dynamic_war_tab_required"
	] = include_war_tab
	out [
		"war_ui_calls_engines_directly"
	] = false
	out [
		"war_registry_observation_mutated_world"
	] = false

	resident_crown_contract_by_actor [
		str(
			actor.id
		)
	] = out.duplicate(false)

	return out

func _patch_diplomacy_entries_with_war_registry(
	entries: Array,
	war_registry: Dictionary
) -> Array:
	var out: Array = []
	var active_wars: Array = _array(
		war_registry.get(
			"global_active_wars",
			war_registry.get(
				"active_wars",
				[]
			)
		)
	)

	for raw_entry in entries:
		var entry: Dictionary = _dict(
			raw_entry
		)

		if entry.is_empty():
			continue

		var effective_realm_id: int = int(
			entry.get(
				"war_realm_id",
				entry.get(
					"realm_id",
					-1
				)
			)
		)
		var active_war: Dictionary = {}

		for raw_war in active_wars:
			var war: Dictionary = _dict(
				raw_war
			)

			if war.is_empty():
				continue

			var attacker_ids: Array = _array(
				war.get(
					"attacker_side_realm_ids",
					[
						int(
							war.get(
								"attacker_realm_id",
								-1
							)
						)
					]
				)
			)
			var defender_ids: Array = _array(
				war.get(
					"defender_side_realm_ids",
					[
						int(
							war.get(
								"defender_realm_id",
								-1
							)
						)
					]
				)
			)

			if (
				effective_realm_id in attacker_ids
				or effective_realm_id in defender_ids
			):
				active_war = war
				break

		entry [
			"in_active_war"
		] = not active_war.is_empty()
		entry [
			"active_war_id"
		] = str(
			active_war.get(
				"war_id",
				""
			)
		)
		entry [
			"active_war_contract"
		] = active_war
		entry [
			"war_banner"
		] = (
			"AT WAR"
			if not active_war.is_empty()
			else ""
		)

		out.append(
			entry
		)

	return out

func emit_resident_crown_hub_contract_with_war(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var contract: Dictionary = (
		emit_resident_crown_hub_contract(
			actor,
			context
		)
	)

	if contract.is_empty():
		return contract

	return _attach_war_projection(
		actor,
		contract
	)

func _actor_can_declare_war(
	actor: Person,
	permissions: Dictionary
) -> bool:
	if (
		actor == null
		or not actor.alive
	):
		return false



	if bool(
		permissions.get(
			"can_declare_war",
			false
		)
	):
		return true



	if bool(
		actor.is_ruler
	):
		return true

	var civic_contract: Dictionary = (
		_civic_office_contract_for_actor(
			actor
		)
	)
	var authority_identity_texts: Array = [
		str(
			actor.royal_title
		).strip_edges().to_lower(),
		str(
			actor.civic_title
		).strip_edges().to_lower(),
		str(
			actor.job
		).strip_edges().to_lower(),
		str(
			civic_contract.get(
				"office",
				""
			)
		).strip_edges().to_lower(),
		str(
			civic_contract.get(
				"office_full_title",
				""
			)
		).strip_edges().to_lower(),
		str(
			civic_contract.get(
				"profile_job_label",
				""
			)
		).strip_edges().to_lower()
	]
	var war_authority_roles: Array = [
		"president",
		"prime minister",
		"chancellor",
		"emperor",
		"empress",
		"king",
		"queen"
	]

	for raw_identity_text in authority_identity_texts:
		var identity_text: String = str(
			raw_identity_text
		).strip_edges().to_lower()

		if identity_text == "":
			continue

		for raw_role in war_authority_roles:
			var role: String = str(
				raw_role
			).strip_edges().to_lower()

			if role == "":
				continue

			var role_matches: bool = (
				identity_text == role
				or identity_text.begins_with(
					"%s " % role
				)
				or identity_text.ends_with(
					" %s" % role
				)
				or identity_text.contains(
					" %s " % role
				)
			)

			if role_matches:
				return true

	return false

func _war_diplomacy_entries(
	actor: Person,
	permissions: Dictionary,
	war_registry: Dictionary
) -> Array:
	var entries: Array = []

	if (
		actor == null
		or gs == null
		or gs.realm_engine == null
	):
		return entries

	var actor_realm_id: int = int(
		actor.realm_id
	)
	var realms_raw: Variant = gs.realm_engine.get(
		"realms"
	)
	var realms: Dictionary = (
		realms_raw as Dictionary
		if typeof(realms_raw) == TYPE_DICTIONARY
		else {}
	)
	var active_wars: Array = _array(
		war_registry.get(
			"active_wars",
			[]
		)
	)

	for raw_realm_id in realms.keys():
		var realm_id: int = int(
			raw_realm_id
		)

		if realm_id <= 0:
			continue

		var realm: Dictionary = _dict(
			realms.get(
				raw_realm_id,
				{}
			)
		)

		if realm.is_empty():
			continue

		var preview: Dictionary = {}

		if (
			realm_id != actor_realm_id
			and gs.war_contract_engine != null
		):
			preview = (
				gs.war_contract_engine
				.emit_war_preview_contract({
					"attacker_realm_id": actor_realm_id,
					"defender_realm_id": realm_id,
					"year": int(gs.year),
					"era_key": str(
						gs.era
					),
					"source": (
						"crown_hub_contract_engine."
						+ "war_diplomacy_entries"
					)
				})
			)

		var active_war: Dictionary = {}

		for raw_war in active_wars:
			var war: Dictionary = _dict(
				raw_war
			)

			if (
				int(
					war.get(
						"attacker_realm_id",
						-1
					)
				) == realm_id
				or int(
					war.get(
						"defender_realm_id",
						-1
					)
				) == realm_id
			):
				active_war = war
				break

		entries.append({
			"country": str(
				realm.get(
					"name",
					"Unknown Realm"
				)
			),
			"realm_id": realm_id,
			"realm": realm,
			"population": int(
				realm.get(
					"population",
					0
				)
			),
			"capital_city": str(
				realm.get(
					"capital_city",
					"Capital City"
				)
			),
			"land_mi2": int(
				realm.get(
					"land",
					realm.get(
						"land_size",
						0
					)
				)
			),
			"treasury": int(
				realm.get(
					"treasury",
					0
				)
			),
			"currency_name": str(
				realm.get(
					"currency_name",
					"Treasury"
				)
			),
			"military_stockpile": int(
				realm.get(
					"military_stockpile",
					0
				)
			),
			"goods_stockpile": int(
				realm.get(
					"goods_stockpile",
					0
				)
			),
			"ruler_label": str(
				realm.get(
					"ruler_name",
					realm.get(
						"leader_name",
						"Unknown Leader"
					)
				)
			),
			"is_player_country": (
				realm_id == actor_realm_id
			),
			"is_era_kingdom": false,
			"can_declare_war": (
				bool(
					permissions.get(
						"can_declare_war",
						false
					)
				)
				and realm_id != actor_realm_id
				and bool(
					preview.get(
						"declaration_allowed",
						false
					)
				)
			),
			"war_preview_contract": preview,
			"active_war_id": str(
				active_war.get(
					"war_id",
					""
				)
			),
			"active_war_contract": active_war,
			"in_active_war": not active_war.is_empty(),
			"war_banner": (
				"IN A WAR"
				if not active_war.is_empty()
				else ""
			),
			"ui_is_renderer_only": true
		})

	return entries


func _war_section_rows(
	actor: Person,
	war_registry: Dictionary
) -> Array:
	var rows: Array = []
	var active_wars: Array = _array(
		war_registry.get(
			"global_active_wars",
			war_registry.get(
				"active_wars",
				[]
			)
		)
	)
	var history: Array = _array(
		war_registry.get(
			"war_history",
			[]
		)
	)
	var actor_realm_id: int = (
		int(
			actor.realm_id
		)
		if actor != null
		else -1
	)
	var observed_year: int = (
		int(
			gs.year
		)
		if gs != null
		else 0
	)

	for raw_active_war in active_wars:
		var active_war: Dictionary = _dict(
			raw_active_war
		)

		if active_war.is_empty():
			continue

		var war_id: String = str(
			active_war.get(
				"war_id",
				""
			)
		)
		var war_surface: Dictionary = {}

		if (
			gs != null
			and gs.war_contract_engine != null
			and war_id != ""
		):
			war_surface = (
				gs.war_contract_engine
				.emit_war_surface_contract(
					war_id,
					actor_realm_id
				)
			)

		var state: String = str(
			active_war.get(
				"state",
				"active"
			)
		).strip_edges().to_lower()
		var attacker_name: String = str(
			active_war.get(
				"attacker_name",
				"Attacking Realm"
			)
		)
		var defender_name: String = str(
			active_war.get(
				"defender_name",
				"Defending Realm"
			)
		)
		var observer_side: String = str(
			war_surface.get(
				"observer_side",
				""
			)
		)
		var actions: Array = []

		if state == "active":
			if observer_side != "":
				actions.append_array([
					{
						"action_id": (
							"set_war_strategy"
						),
						"label": "Mobilize",
						"enabled": true,
						"payload": {
							"war_id": war_id,
							"intent": "mobilize"
						}
					},
					{
						"action_id": (
							"set_war_strategy"
						),
						"label": "Invade City",
						"enabled": true,
						"payload": {
							"war_id": war_id,
							"intent": "invade_city"
						}
					},
					{
						"action_id": (
							"set_war_strategy"
						),
						"label": "Seek Treaty",
						"enabled": true,
						"payload": {
							"war_id": war_id,
							"intent": "seek_treaty"
						}
					}
				])

				var observer_realm_card: Dictionary = {}
				var observer_side_contract: Dictionary = _dict(
					war_surface.get(
						(
							"attacker_side"
							if observer_side == "attacker"
							else "defender_side"
						),
						{}
					)
				)

				for raw_realm_card in _array(
					observer_side_contract.get(
						"realm_cards",
						[]
					)
				):
					var realm_card: Dictionary = _dict(
						raw_realm_card
					)

					if int(
						realm_card.get(
							"realm_id",
							-1
						)
					) != actor_realm_id:
						continue

					observer_realm_card = realm_card
					break

				var elemental_capability: Dictionary = _dict(
					observer_realm_card.get(
						"elemental_war_capability",
						{}
					)
				)

				if (
					actor != null
					and bool(
						actor.is_ruler
					)
					and bool(
						elemental_capability.get(
							"enabled",
							false
						)
					)
				):
					var element_label: String = str(
						elemental_capability.get(
							"element",
							"Elemental"
						)
					).capitalize()

					actions.append_array([
						{
							"action_id": "set_war_strategy",
							"label": (
								"%s Strike • Military"
								% element_label
							),
							"enabled": true,
							"payload": {
								"war_id": war_id,
								"intent": "elemental_strike",
								"elemental_target": "military"
							}
						},
						{
							"action_id": "set_war_strategy",
							"label": (
								"%s Strike • Population"
								% element_label
							),
							"enabled": true,
							"payload": {
								"war_id": war_id,
								"intent": "elemental_strike",
								"elemental_target": "population"
							}
						},
						{
							"action_id": "set_war_strategy",
							"label": (
								"%s Strike • Infrastructure"
								% element_label
							),
							"enabled": true,
							"payload": {
								"war_id": war_id,
								"intent": "elemental_strike",
								"elemental_target": "infrastructure"
							}
						}
					])

				var ally_candidates: Array = _array(
					war_surface.get(
						"ally_candidates",
						[]
					)
				)
				if not ally_candidates.is_empty():
					var compact_ally_candidates: Array = []
					for raw_ally in ally_candidates:
						var ally: Dictionary = _dict(
							raw_ally
						)
						if ally.is_empty():
							continue

						var ally_realm_id: int = int(
							ally.get(
								"realm_id",
								-1
							)
						)
						if ally_realm_id <= 0:
							continue

						compact_ally_candidates.append({
							"realm_id": ally_realm_id,
							"name": str(
								ally.get(
									"name",
									"Ally"
								)
							),
							"relation_score": int(
								ally.get(
									"relation_score",
									0
								)
							),
							"relation_tier": str(
								ally.get(
									"relation_tier",
									"Ally"
								)
							)
						})

					if not compact_ally_candidates.is_empty():
						actions.append({
							"action_id": (
								"open_war_ally_picker"
							),
							"label": (
								"Ask an Ally to Join You"
							),
							"enabled": true,
							"payload": {
								"war_id": war_id,
								"ally_candidates": (
									compact_ally_candidates
								)
							}
						})
			else:
				actions.append({
					"action_id": "request_join_war",
					"label": (
						"Ask to Join %s"
						% attacker_name
					),
					"enabled": true,
					"payload": {
						"war_id": war_id,
						"join_side": "attacker"
					}
				})
				actions.append({
					"action_id": "request_join_war",
					"label": (
						"Ask to Join %s"
						% defender_name
					),
					"enabled": true,
					"payload": {
						"war_id": war_id,
						"join_side": "defender"
					}
				})

		elif (
			state == "awaiting_outcome"
			and int(
				active_war.get(
					"winner_realm_id",
					-1
				)
			) == actor_realm_id
		):
			for resolution in [
				"spare",
				"treaty",
				"annex"
			]:
				actions.append({
					"action_id": (
						"resolve_war_outcome"
					),
					"label": str(
						resolution
					).capitalize(),
					"enabled": true,
					"payload": {
						"war_id": war_id,
						"resolution": resolution
					}
				})

		rows.append({
			"row_kind": (
				"active_war"
				if state == "active"
				else "awaiting_outcome"
			),
			"title": (
				"AT WAR — %s vs %s"
				% [
					attacker_name,
					defender_name
				]
			),
			"description": (
				"Year %d • Active for %d years • "
				+ "Projected end %d • Projected winner: %s"
			) % [
				observed_year,
				int(
					active_war.get(
						"years_active",
						0
					)
				),
				int(
					active_war.get(
						"projected_end_year",
						observed_year + 1
					)
				),
				str(
					active_war.get(
						"projected_winner_name",
						"Unknown"
					)
				)
			],
			"data": {
				"war_id": war_id,
				"war_contract": active_war,
				"war_surface_contract": war_surface
			},
			"actions": actions
		})

	for raw_history_war in history:
		var history_war: Dictionary = _dict(
			raw_history_war
		)

		if history_war.is_empty():
			continue

		var history_war_id: String = str(
			history_war.get(
				"war_id",
				""
			)
		).strip_edges()
		var war_report: Dictionary = _dict(
			history_war.get(
				"war_report",
				{}
			)
		)

		if (
			war_report.is_empty()
			and gs != null
			and gs.war_contract_engine != null
			and history_war_id != ""
		):
			war_report = (
				gs.war_contract_engine
				.emit_war_history_report(
					history_war_id
				)
			)

		var history_title: String = "%s vs %s" % [
			str(
				history_war.get(
					"attacker_name",
					"Realm"
				)
			),
			str(
				history_war.get(
					"defender_name",
					"Realm"
				)
			)
		]
		var history_outcome: String = str(
			history_war.get(
				"outcome_resolution",
				history_war.get(
					"conclusion_reason",
					"unknown"
				)
			)
		).replace(
			"_",
			" "
		).capitalize()

		rows.append({
			"row_kind": "war_history",
			"title": history_title,
			"description": (
				"Winner: %s • %d–%d • Outcome: %s"
				% [
					str(
						war_report.get(
							"winner_name",
							"No Decisive Winner"
						)
					),
					int(
						war_report.get(
							"start_year",
							0
						)
					),
					int(
						war_report.get(
							"end_year",
							0
						)
					),
					history_outcome
				]
			),
			"data": {
				"war_id": history_war_id,
				"war_contract": history_war,
				"war_report": war_report
			},
			"actions": [
				{
					"action_id": (
						"view_war_report"
					),
					"label": "Read War Report",
					"enabled": true,
					"payload": {
						"war_report": (
							war_report
						)
					}
				}
			]
		})

	return rows

func prioritize_resident_crown_war_projection_target(
		actor: Person,
		context: Dictionary = {}
) -> Dictionary:
		if (
			actor == null
			or gs == null
			or gs.war_contract_engine == null
			or gs.realm_engine == null
		):
			return {
				"success": false,
				"reason": (
					"war_projection_authority_unavailable"
				)
			}

		var actor_id: int = int(actor.id)
		var actor_realm_id: int = int(
			context.get(
				"actor_realm_id",
				actor.realm_id
			)
		)
		var defender_realm_id: int = int(
			context.get(
				"defender_realm_id",
				-1
			)
		)

		if (
			actor_realm_id <= 0
			or defender_realm_id <= 0
			or defender_realm_id == actor_realm_id
		):
			return {
				"success": false,
				"reason": "missing_or_invalid_war_realm_id"
			}

		var base_contract: Dictionary = _dict(
			context.get(
				"base_contract",
				{}
			)
		)
		var permissions: Dictionary = _dict(
			base_contract.get(
				"permissions",
				{}
			)
		)
		var realms_raw: Variant = (
			gs.realm_engine.get(
				"realms"
			)
		)
		var realms: Dictionary = (
			realms_raw as Dictionary
			if typeof(realms_raw) == TYPE_DICTIONARY
			else {}
		)
		var realm_raw: Variant = realms.get(
			defender_realm_id,
			realms.get(
				str(defender_realm_id),
				{}
			)
		)
		var defender_realm: Dictionary = (
			realm_raw as Dictionary
			if typeof(realm_raw) == TYPE_DICTIONARY
			else {}
		)
		var relation_contract: Dictionary = {}
		var war_preview: Dictionary = {}
		var published_entry: Dictionary = {}
		var preview_hot: bool = false




		if not defender_realm.is_empty():
			relation_contract = (
				gs.war_contract_engine
				.emit_realm_relation_contract(
					actor_realm_id,
					defender_realm_id
				)
			)

			war_preview = (
				gs.war_contract_engine
				.emit_war_preview_contract(
					{
						"attacker_realm_id": actor_realm_id,
						"defender_realm_id": defender_realm_id,
						"defender_name": str(
							defender_realm.get(
								"name",
								"Target Realm"
							)
						),
						"year": int(gs.year),
						"era_key": (
							str(gs.era.name)
							if gs.era != null
							else ""
						),
						"source": (
							"crown_hub_contract_engine."
							+ "prioritize_war_preview_target_quantum"
						),
						"background_only": true,
						"blocks_ui": false,
						"ready_gate_member": false
					}
				)
			)

			preview_hot = (
				bool(
					war_preview.get(
						"success",
						false
					)
				)
				and not bool(
					war_preview.get(
						"preview_pending",
						false
					)
				)
			)

			if preview_hot:
				published_entry = (
					_resident_diplomacy_compact_entry(
						defender_realm_id,
						defender_realm,
						actor_realm_id,
						permissions,
						{},
						war_preview,
						relation_contract
					)
				)

				if not published_entry.is_empty():
					published_entry [
						"war_preview_pending"
					] = false
					published_entry [
						"war_preview_deferred"
					] = false
					published_entry [
						"war_preview_priority_target_resolved"
					] = true
					published_entry [
						"war_preview_background_owned"
					] = true
					published_entry [
						"war_preview_click_build_forbidden"
					] = true
					published_entry [
						"war_preview_render_build_forbidden"
					] = true
					published_entry [
						"war_preview_ready_gate_member"
					] = false




					var diplomacy_job: Dictionary = _dict(
						resident_diplomacy_projection_jobs.get(
							str(actor_id),
							{}
						)
					)

					if not diplomacy_job.is_empty():
						var diplomacy_entries: Array = _array(
							diplomacy_job.get(
								"entries",
								[]
							)
						).duplicate(false)

						for index in range(
							diplomacy_entries.size()
						):
							var candidate: Dictionary = _dict(
								diplomacy_entries [index]
							)

							if int(
								candidate.get(
									"realm_id",
									-1
								)
							) != defender_realm_id:
								continue

							diplomacy_entries [index] = (
								published_entry.duplicate(false)
							)
							break

						diplomacy_job [
							"entries"
						] = diplomacy_entries

						resident_diplomacy_projection_jobs [
							str(actor_id)
						] = diplomacy_job



					resident_diplomacy_entry_published.emit(
						actor_id,
						published_entry.duplicate(false)
					)

		var job_key: String = str(actor_id)
		var job: Dictionary = _dict(
			resident_crown_war_projection_jobs.get(
				job_key,
				{}
			)
		)



		var base_entries: Array = _array(
			base_contract.get(
				"diplomacy_country_entries",
				[]
			)
		)

		if (
			job.is_empty()
			and not base_entries.is_empty()
		):
			service_resident_crown_war_projection_quantum(
				actor,
				{
					"actor_id": actor_id,
					"actor_realm_id": actor_realm_id,
					"base_contract": base_contract,
					"source": (
						"crown_hub_contract_engine."
						+ "prioritize_war_preview"
					),
					"background_only": true,
					"blocks_ui": false,
					"ready_gate_member": false
				}
			)

			job = _dict(
				resident_crown_war_projection_jobs.get(
					job_key,
					{}
				)
			)

		var cursor: int = 0
		var priority_index: int = -1

		if not job.is_empty():
			var entries: Array = _array(
				job.get(
					"entries",
					[]
				)
			).duplicate(false)

			cursor = int(
				job.get(
					"entry_cursor",
					0
				)
			)

			for index in range(
				cursor,
				entries.size()
			):
				var candidate: Dictionary = _dict(
					entries [index]
				)

				if int(
					candidate.get(
						"realm_id",
						-1
					)
				) == defender_realm_id:
					priority_index = index
					break

			if (
				priority_index >= 0
				and priority_index != cursor
			):
				var displaced_entry: Variant = entries [cursor]
				entries [cursor] = entries [priority_index]
				entries [priority_index] = displaced_entry

			job ["entries"] = entries
			job [
				"priority_defender_realm_id"
			] = defender_realm_id
			job [
				"priority_installed_at_cursor"
			] = cursor
			job [
				"priority_target_preview_hot"
			] = preview_hot

			resident_crown_war_projection_jobs [
				job_key
			] = job

		return {
			"success": (
				preview_hot
				or not job.is_empty()
			),
			"schema": (
				"eralife.crown_hub."
				+ "war_projection_priority_contract"
			),
			"version": 2,
			"actor_id": actor_id,
			"attacker_realm_id": actor_realm_id,
			"defender_realm_id": defender_realm_id,
			"entry_cursor": cursor,
			"priority_index_before_swap": priority_index,
			"selected_preview_hot": preview_hot,
			"selected_preview_published": (
				not published_entry.is_empty()
			),
			"published_entry": (
				published_entry.duplicate(false)
			),
			"war_preview_contract": (
				war_preview.duplicate(false)
			),
			"next_quantum_targets_selected_realm": (
				priority_index >= 0
			),
			"background_only": true,
			"blocks_ui": false,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}
func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No Crown Hub observer could be resolved."
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
		"", "refresh", "open_hub":
			result = {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"version": ENGINE_VERSION,
				"type": "crown_hub_refreshed"
			}

		"observe_partial":
			result = {
				"success": true,
				"schema": ENGINE_SCHEMA,
				"version": ENGINE_VERSION,
				"type": "crown_hub_observable_projection"
			}
			var observable_contract: Dictionary = (
				emit_observable_contract(
					actor,
					payload
				)
			)
			result [
				"crown_hub_contract"
			] = _attach_war_projection(
				actor,
				observable_contract
			)
			result [
				"crown_hub_contract_engine_owned"
			] = true
			result [
				"ui_is_renderer_only"
			] = true
			last_report = result.duplicate(true)
			return result

		"set_section", "persist_section_lens":
			result = persist_section_lens(
				actor,
				payload
			)

		"preview_war":
			if (
				gs == null
				or gs.war_contract_engine == null
			):
				result = _fail(
					"war_contract_engine_unavailable",
					"WarContractEngine is unavailable."
				)
			else:
				result = (
					gs.war_contract_engine
					.emit_war_preview_contract(
						payload
					)
				)

		"declare_war":
			if (
				gs == null
				or gs.war_contract_engine == null
			):
				result = _fail(
					"war_contract_engine_unavailable",
					"WarContractEngine is unavailable."
				)
			else:
				var declaration_payload: Dictionary = (
					payload.duplicate(true)
				)
				declaration_payload [
					"attacker_realm_id"
				] = int(
					declaration_payload.get(
						"attacker_realm_id",
						actor.realm_id
					)
				)
				declaration_payload [
					"year"
				] = int(gs.year)
				result = (
					gs.war_contract_engine
					.declare_war_contract(
						declaration_payload
					)
				)
		"request_join_war":
			if (
				gs == null
				or gs.war_contract_engine == null
			):
				result = _fail(
					"war_contract_engine_unavailable",
					"WarContractEngine is unavailable."
				)
			else:
				var join_payload: Dictionary = (
					payload.duplicate(false)
				)
				join_payload [
					"actor_realm_id"
				] = int(
					join_payload.get(
						"actor_realm_id",
						actor.realm_id
					)
				)

				result = (
					gs.war_contract_engine
					.request_join_war(
						join_payload
					)
				)
		"bribe_era_kingdom":
			if (
				gs == null
				or gs.many_realms_engine == null
				or not gs.many_realms_engine.has_method(
					"resolve_era_kingdom_bribe_attempt"
				)
			):
				result = _fail(
					"era_kingdom_diplomacy_unavailable",
					"Era Kingdom diplomacy authority is unavailable."
				)
			else:
				result = (
					gs.many_realms_engine
					.resolve_era_kingdom_bribe_attempt(
						actor,
						payload
					)
				)
		"set_war_strategy":
			if (
				gs == null
				or gs.war_contract_engine == null
			):
				result = _fail(
					"war_contract_engine_unavailable",
					"WarContractEngine is unavailable."
				)
			else:
				var strategy_payload: Dictionary = (
					payload.duplicate(true)
				)
				strategy_payload [
					"actor_realm_id"
				] = int(
					strategy_payload.get(
						"actor_realm_id",
						actor.realm_id
					)
				)
				result = (
					gs.war_contract_engine
					.set_war_strategy(
						strategy_payload
					)
				)

		"resolve_war_outcome":
			if (
				gs == null
				or gs.war_contract_engine == null
			):
				result = _fail(
					"war_contract_engine_unavailable",
					"WarContractEngine is unavailable."
				)
			else:
				result = (
					gs.war_contract_engine
					.resolve_war_outcome(
						payload
					)
				)

		"provider_intent":
			if _mod_authority() == null:
				result = _fail(
					"missing_royalty_mod_authority",
					"RoyaltyModContractEngine is unavailable."
				)
			else:
				result = (
					_mod_authority()
					.resolve_provider_intent(
						actor,
						payload
					)
				)

		_:
			if _law() == null:
				result = _fail(
					"missing_royalty_law",
					"RoyaltyContractEngine is unavailable."
				)
			else:
				result = _law().resolve_intent(
					actor,
					payload
				)

	if (
		_runtime() != null
		and action_id not in [
			"preview_war",
			"declare_war",
			"set_war_strategy",
			"request_join_war",
			"resolve_war_outcome",
			"bribe_era_kingdom"
		]
	):
		_runtime().repair_state({
			"source": (
				"crown_hub_contract_engine."
				+ "resolve_intent"
			)
		})
	var resident_projection_action: bool = (
		action_id in [
			"declare_war",
			"set_war_strategy",
			"request_join_war",
			"resolve_war_outcome"
		]
	)

	if action_id == "preview_war":
		result ["crown_hub_contract_engine_owned"] = true
		result ["ui_is_renderer_only"] = true
		result ["war_preview_did_not_attach_registry_projection"] = true
		last_report = result.duplicate(false)
		return result

	if resident_projection_action:
		var resident_key: String = str(
			actor.id
		)
		var resident_raw: Variant = (
			resident_crown_contract_by_actor.get(
				resident_key,
				{}
			)
		)
		var resident_contract: Dictionary = (
			resident_raw as Dictionary
			if typeof(resident_raw) == TYPE_DICTIONARY
			else {}
		)

		if not resident_contract.is_empty():
			var shell_contract: Dictionary = (
				resident_contract.duplicate(false)
			)

			var section_surfaces: Dictionary = _dict(
				shell_contract.get(
					"section_surfaces",
					{}
				)
			).duplicate(false)
			if not section_surfaces.has(
				"war"
			):
				section_surfaces ["war"] = []

			shell_contract ["section_surfaces"] = (
				section_surfaces
			)
			shell_contract ["section_tabs"] = (
				_section_tabs(
					true
				)
			)
			shell_contract [
				"dynamic_war_tab_required"
			] = true
			shell_contract ["war_projection_pending"] = true
			shell_contract ["war_projection_complete"] = false
			shell_contract ["war_projection_phase"] = (
				"queued"
			)
			shell_contract [
				"war_registry_observation_deferred"
			] = true
			shell_contract [
				"war_action_receipt"
			] = {
				"action_id": action_id,
				"success": bool(
					result.get(
						"success",
						false
					)
				),
				"committed": bool(
					result.get(
						"committed",
						false
					)
				),
				"created_at_ms": int(
					Time.get_ticks_msec()
				)
			}

			resident_crown_contract_by_actor [
				resident_key
			] = shell_contract
			resident_crown_war_projection_jobs.erase(
				resident_key
			)

			result ["crown_hub_contract"] = shell_contract

		result ["war_projection_queued"] = true
		result ["war_projection_synchronously_attached"] = false
		result ["crown_hub_contract_engine_owned"] = true
		result ["ui_is_renderer_only"] = true
		last_report = result.duplicate(false)
		return result
	var crown_contract: Dictionary = (
		emit_crown_hub_contract(
			actor,
			{
				"active_section": str(
					payload.get(
						"section_id",
						_lens_for(actor).get(
							"active_section",
							"throne"
						)
					)
				),
				"status_text": str(
					result.get(
						"text",
						result.get(
							"message",
							""
						)
					)
				),
				"source": str(
					payload.get(
						"source",
						"crown_hub_contract_engine.resolve_intent"
					)
				)
			}
		)
	)
	result ["crown_hub_contract"] = _attach_war_projection(
		actor,
		crown_contract
	)
	result ["crown_hub_contract_engine_owned"] = true
	result ["ui_is_renderer_only"] = true
	last_report = result.duplicate(true)

	return result


func persist_section_lens(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No Crown Hub observer could be resolved."
		)

	var section_id: String = _section(
		str(
			payload.get(
				"section_id",
				"throne"
			)
		)
	)
	var lens: Dictionary = _lens_for(actor)
	lens ["active_section"] = section_id
	_commit_lens(
		actor,
		lens
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "crown_hub_lens_persisted",
		"actor_id": int(actor.id),
		"active_section": section_id,
		"simulation_mutation_performed": false,
		"ui_is_renderer_only": true
	}


func emit_observable_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No Crown Hub observer could be resolved."
		)

	var institution: Dictionary = (
		_runtime().institution_for_actor(actor)
		if _runtime() != null
		else {}
	)
	var summary: Dictionary = (
		_law().summary_for_actor(actor)
		if _law() != null
		else {}
	)
	var permissions: Dictionary = (
		_law().permissions_for_actor(actor)
		if _law() != null
		else {}
	)

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _person_name(actor),
		"title": "👑 CROWN HUB",
		"subtitle": (
			"Royal institutions are observable while "
			+ "constitutional truth reconciles."
		),
		"active_section": _section(
			str(
				context.get(
					"active_section",
					"throne"
				)
			)
		),
		"section_tabs": _section_tabs(),
		"summary": summary,
		"permissions": permissions,
		"institution": institution,
		"current_monarch": _person_projection(
			_person_by_id(
				int(
					institution.get(
						"monarch_id",
						-1
					)
				)
			)
		),
		"royal_family": [],
		"court": [],
		"dynasties": [],
		"claimants": [],
		"succession": [],
		"royal_authority": permissions,
		"realm_stability": int(
			institution.get(
				"stability",
				0
			)
		),
		"diplomatic_houses": [],
		"royal_assets": [],
		"royal_decrees": [],
		"ceremonies": [],
		"line_of_succession": [],
		"section_surfaces": (
			_observable_section_surfaces(
				summary,
				permissions
			)
		),
		"status_text": str(
			context.get(
				"status_text",
				(
					"Royal institution truth is observable "
					+ "while live state reconciles."
				)
			)
		),
		"truth_state": "observable_partial",
		"authoritative_projection": false,
		"surface_revision": "%d:%d:observable" % [
			int(actor.id),
			int(
				institution.get(
					"runtime_revision",
					0
				)
			)
		],
		"ui_is_renderer_only": true
	}
func _civic_office_contract_for_actor(
	actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	var raw_contract: Variant = (
		actor.civic_office_contract
	)

	if typeof(raw_contract) != TYPE_DICTIONARY:
		return {}

	return (
		raw_contract as Dictionary
	).duplicate(true)


func _actor_uses_civic_crown_projection(
	actor: Person
) -> bool:
	var civic_contract: Dictionary = (
		_civic_office_contract_for_actor(
			actor
		)
	)

	if civic_contract.is_empty():
		return false

	return (
		bool(
			civic_contract.get(
				"crown_hub_access",
				false
			)
		)
		and bool(
			civic_contract.get(
				"ruling_power_by_office",
				false
			)
		)
		and not bool(
			civic_contract.get(
				"is_royalty",
				false
			)
		)
	)


func _civic_realm_for_actor(
	actor: Person
) -> Dictionary:
	if (
		actor == null
		or gs == null
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
	var realm_id: int = int(
		actor.realm_id
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

	return (
		realm_raw as Dictionary
	).duplicate(true)


func _civic_constitutional_contract_for_actor(
	actor: Person,
	civic_contract: Dictionary,
	realm: Dictionary
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.checks_and_balances_contract_engine == null
		or not gs.checks_and_balances_contract_engine.has_method(
			"constitutional_contract_for_realm"
		)
	):
		return {}

	var realm_id: int = int(
		actor.realm_id
	)
	var realm_name: String = str(
		realm.get(
			"name",
			civic_contract.get(
				"country",
				actor.home_country
			)
		)
	).strip_edges()

	return _dict(
		gs.checks_and_balances_contract_engine.constitutional_contract_for_realm(
			realm_id,
			realm_name,
			{
				"government_model": str(
					civic_contract.get(
						"government_model",
						"federal_presidential_republic"
					)
				),
				"source": (
					"crown_hub_contract_engine."
					+ "civic_constitutional_projection"
				),
				"read_only": true,
				"ui_is_renderer_only": true
			}
		)
	)


func _crown_summary_with_civic_office(
	actor: Person,
	base_summary: Dictionary,
	civic_contract: Dictionary,
	realm: Dictionary
) -> Dictionary:
	var out: Dictionary = (
		base_summary.duplicate(true)
	)

	if not _actor_uses_civic_crown_projection(
		actor
	):
		return out

	var office: String = str(
		civic_contract.get(
			"office",
			""
		)
	).strip_edges()
	var full_title: String = str(
		civic_contract.get(
			"office_full_title",
			""
		)
	).strip_edges()
	var realm_name: String = str(
		realm.get(
			"name",
			civic_contract.get(
				"country",
				actor.home_country
			)
		)
	).strip_edges()
	var government_model: String = str(
		civic_contract.get(
			"government_model",
			realm.get(
				"government_model",
				"federal_presidential_republic"
			)
		)
	).strip_edges().to_lower()
	var base_happiness: int = clampi(
		int(
			out.get(
				"happiness",
				50
			)
		),
		0,
		100
	)
	var resolved_happiness: int = (
		base_happiness
	)








	if realm.has(
		"happiness"
	):
		resolved_happiness = clampi(
			int(
				realm.get(
					"happiness",
					base_happiness
				)
			),
			0,
			100
		)

	if office == "":
		office = full_title.trim_prefix(
			"The "
		)

	if office == "":
		office = "Elected Executive"

	if realm_name == "":
		realm_name = "United States"

	out [
		"title"
	] = office
	out [
		"office_full_title"
	] = full_title
	out [
		"realm_id"
	] = int(
		actor.realm_id
	)
	out [
		"realm_name"
	] = realm_name
	out [
		"house_id"
	] = "executive_branch"
	out [
		"house_name"
	] = "Executive Branch"
	out [
		"government_model"
	] = government_model
	out [
		"government_style"
	] = "Federal Presidential Republic"
	out [
		"federal_republic"
	] = true
	out [
		"royal_language_forbidden"
	] = true
	out [
		"standing"
	] = "Elected"
	out [
		"authority_tier"
	] = "elected"
	out [
		"approval"
	] = int(
		actor.approval
	)
	out [
		"legitimacy"
	] = int(
		actor.approval
	)
	out [
		"respect"
	] = int(
		actor.respect
	)
	out [
		"happiness"
	] = resolved_happiness
	out [
		"stability"
	] = int(
		realm.get(
			"stability",
			out.get(
				"stability",
				50
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
		"currency_name"
	] = str(
		realm.get(
			"currency_name",
			"USD"
		)
	)
	out [
		"military_stockpile"
	] = int(
		realm.get(
			"military_stockpile",
			0
		)
	)
	out [
		"goods_stockpile"
	] = int(
		realm.get(
			"goods_stockpile",
			0
		)
	)
	out [
		"allocation_pool"
	] = int(
		realm.get(
			"allocation_pool",
			realm.get(
				"treasury",
				0
			)
		)
	)
	out [
		"tax_rate"
	] = float(
		realm.get(
			"tax_rate",
			10.0
		)
	)
	out [
		"succession_rank"
	] = 99
	out [
		"claimant_pressure"
	] = 0.0
	out [
		"royal_succession_tension"
	] = 0.0
	out [
		"coup_pressure"
	] = float(
		realm.get(
			"coup_pressure",
			0.0
		)
	)
	out [
		"integrity_state"
	] = "constitutional"
	out [
		"alerts"
	] = _array(
		realm.get(
			"civic_alerts",
			[
				"No urgent federal alerts right now."
			]
		)
	)

	return out

func _crown_permissions_with_civic_office(
		actor: Person,
		base_permissions: Dictionary,
		civic_contract: Dictionary
) -> Dictionary:
		var out: Dictionary = base_permissions.duplicate(true)



		out ["can_mediate_citizens"] = (
			bool(out.get("court", false))
			and bool(out.get("open", false))
		)
		out ["can_manage_cabinet"] = false
		out ["can_first_family_actions"] = false
		out ["can_emergency_powers"] = bool(
			out.get(
				"law",
				false
			)
		)

		if not _actor_uses_civic_crown_projection(actor):
			out ["royal_language_forbidden"] = false
			return out

		var ruling_power_by_office: bool = bool(
			civic_contract.get(
				"ruling_power_by_office",
				false
			)
		)

		out ["open"] = true
		out ["throne"] = true
		out ["court"] = true
		out ["nation"] = true
		out ["allocation"] = true
		out ["diplomacy"] = true
		out ["law"] = true
		out ["dynasty"] = false
		out ["symbolic_only"] = false
		out ["is_claimant"] = false
		out ["is_high_in_line"] = false
		out ["authority_tier"] = "elected"
		out ["government_model"] = str(
			civic_contract.get(
				"government_model",
				"federal_presidential_republic"
			)
		)
		out ["can_abdicate"] = false
		out ["can_appoint_heir"] = false
		out ["can_coronate"] = false
		out ["can_establish_regency"] = false
		out ["can_end_regency"] = false
		out ["can_issue_decrees"] = false
		out ["can_manage_court"] = false
		out ["can_manage_cabinet"] = true
		out ["can_first_family_actions"] = true
		out ["can_mediate_citizens"] = false
		out ["can_manage_population"] = true
		out ["can_manage_allocation"] = true
		out ["can_use_diplomacy"] = true
		out ["can_realm_overview"] = true
		out ["can_law_review"] = true
		out ["can_emergency_powers"] = true
		out ["can_public_service"] = true
		out ["can_public_disservice"] = true
		out ["can_celebrity"] = true
		out ["can_honorific"] = false
		out ["can_execute"] = false
		out ["can_create_realm"] = false
		out ["can_set_government_style"] = false



		out ["can_expand_land"] = ruling_power_by_office
		out ["can_declare_war"] = ruling_power_by_office
		out ["royal_language_forbidden"] = true

		return out
func _resident_crown_expand_land_surface(
		actor: Person,
		summary: Dictionary,
		permissions: Dictionary
) -> Dictionary:
		var available: bool = bool(
			permissions.get(
				"can_expand_land",
				false
			)
		)
		var realm_name: String = str(
			summary.get(
				"realm_name",
				"Your Realm"
			)
		)
		var current_land: int = int(
			summary.get(
				"land",
				0
			)
		)
		var population: int = int(
			summary.get(
				"population",
				0
			)
		)
		var personal_wealth: int = (
			int(actor.bank_balance)
			if actor != null
			else 0
		)

		return {
			"schema": (
				"eralife.crown_hub."
				+ "action_surface_contract"
			),
			"version": 1,
			"surface_id": "expand_land",
			"section_id": "nation",
			"surface_kind": "choice_list",
			"title": "TERRITORIAL EXPANSION",
			"body": (
				"%s currently controls %d units of land with "
				+ "a population of %d.\n\n"
				+ "Leader authority is %s.\n"
				+ "Available personal expansion capital: %d.\n\n"
				+ "Choose the scale of territorial development. "
				+ "Each completed expansion becomes Realm truth before "
				+ "the Crown lens receives its updated projection."
			) % [
				realm_name,
				current_land,
				population,
				(
					"ACTIVE"
					if available
					else "UNAVAILABLE"
				),
				personal_wealth
			],
			"status_text": (
				"Territorial choices are prepublished by "
				+ "CrownHubContractEngine."
			),
			"options": [
				{
					"label": (
						"FRONTIER EXPANSION  •  +12 LAND  •  250,000"
					),
					"action_id": "expand_land_contract",
					"enabled": (
						available
						and personal_wealth >= 250000
					),
					"payload": {
						"gain": 12,
						"cost": 250000,
						"expansion_tier": "frontier"
					}
				},
				{
					"label": (
						"REGIONAL EXPANSION  •  +30 LAND  •  700,000"
					),
					"action_id": "expand_land_contract",
					"enabled": (
						available
						and personal_wealth >= 700000
					),
					"payload": {
						"gain": 30,
						"cost": 700000,
						"expansion_tier": "regional"
					}
				},
				{
					"label": (
						"MAJOR EXPANSION  •  +60 LAND  •  1,500,000"
					),
					"action_id": "expand_land_contract",
					"enabled": (
						available
						and personal_wealth >= 1500000
					),
					"payload": {
						"gain": 60,
						"cost": 1500000,
						"expansion_tier": "major"
					}
				}
			],
			"authority": {
				"leader_authority_live": available,
			},
			"build_on_click": false,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}
func _crown_action_cycle(
		actor_id: int
) -> int:
		return int(
			resident_crown_action_cycle_by_actor.get(
				str(actor_id),
				0
			)
		)


func _advance_crown_action_cycle(
		actor_id: int
) -> void:
		var key: String = str(actor_id)
		resident_crown_action_cycle_by_actor [key] = (
			int(
				resident_crown_action_cycle_by_actor.get(
					key,
					0
				)
			) + 1
		)


func _resident_crown_law_review_contract(
		actor: Person,
		summary: Dictionary,
		permissions: Dictionary
) -> Dictionary:
		var era_name: String = (
			str(gs.era.name)
			if (
				gs != null
				and gs.era != null
			)
			else "Modern Era"
		)
		var era_key: String = era_name.strip_edges().to_lower()
		var pool: Array = []

		match era_key:
			"ancient era", "ancient":
				pool = [
					{
						"title": "Burial Ground Protection Edict",
						"description": (
							"Ban hunting, looting, construction, and public games "
							+ "on burial grounds and ancestral sacred sites."
						),
						"risk_label": "Sacred public protection",
						"approval_on_sign": 10,
						"approval_on_veto": -11,
						"approval_on_revise": 3,
						"approval_on_delay": -2
					},
					{
						"title": "Daily Parent Reverence Law",
						"description": (
							"Require every child to tell a parent or guardian "
							+ "that they love them before sunset."
						),
						"risk_label": "Wacky but strangely popular",
						"approval_on_sign": 3,
						"approval_on_veto": 1,
						"approval_on_revise": 1,
						"approval_on_delay": 0
					},
					{
						"title": "Silence Against the State Edict",
						"description": (
							"Criminalize public criticism of the ruler, court, "
							+ "tax collectors, and military commanders."
						),
						"risk_label": "Villainous authoritarian law",
						"approval_on_sign": -22,
						"approval_on_veto": 14,
						"approval_on_revise": 3,
						"approval_on_delay": -5
					}
				]

			"medieval era", "medieval":
				pool = [
					{
						"title": "Protected Winter Orchard Law",
						"description": (
							"Stop nobles and armies from seizing the common "
							+ "orchard harvest during winter."
						),
						"risk_label": "Major commoner reform",
						"approval_on_sign": 13,
						"approval_on_veto": -15,
						"approval_on_revise": 4,
						"approval_on_delay": -3
					},
					{
						"title": "Mandatory Festival Outfit Compliment",
						"description": (
							"Require citizens attending royal festivals to "
							+ "compliment the ruler's outfit."
						),
						"risk_label": "Deeply unserious prestige law",
						"approval_on_sign": -1,
						"approval_on_veto": 4,
						"approval_on_revise": 1,
						"approval_on_delay": 0
					},
					{
						"title": "Peasant Travel Restriction",
						"description": (
							"Make it illegal for commoners to leave their home "
							+ "district without noble permission."
						),
						"risk_label": "Villainous freedom restriction",
						"approval_on_sign": -20,
						"approval_on_veto": 13,
						"approval_on_revise": 2,
						"approval_on_delay": -4
					}
				]

			"industrial era", "industrial":
				pool = [
					{
						"title": "Factory Child Safety Act",
						"description": (
							"Limit dangerous industrial labor for children and "
							+ "require recurring workplace inspections."
						),
						"risk_label": "Major humanitarian reform",
						"approval_on_sign": 16,
						"approval_on_veto": -20,
						"approval_on_revise": 6,
						"approval_on_delay": -5
					},
					{
						"title": "Polite Midnight Whistle Act",
						"description": (
							"Ban factory whistles after midnight unless the "
							+ "whistle has been officially certified as polite."
						),
						"risk_label": "Wacky nuisance regulation",
						"approval_on_sign": 2,
						"approval_on_veto": 2,
						"approval_on_revise": 1,
						"approval_on_delay": 0
					},
					{
						"title": "Seditious Pamphlet Ban",
						"description": (
							"Criminalize printed criticism of government, "
							+ "industry owners, and the military."
						),
						"risk_label": "Civil-liberty crisis",
						"approval_on_sign": -19,
						"approval_on_veto": 13,
						"approval_on_revise": 3,
						"approval_on_delay": -4
					}
				]

			"future era", "future":
				pool = [
					{
						"title": "Synthetic Memory Consent Act",
						"description": (
							"Require explicit consent before a corporation or "
							+ "government can simulate a citizen's memories."
						),
						"risk_label": "Fundamental cognitive-rights protection",
						"approval_on_sign": 17,
						"approval_on_veto": -20,
						"approval_on_revise": 6,
						"approval_on_delay": -5
					},
					{
						"title": "Mandatory Robot Thank-You Act",
						"description": (
							"Require citizens to thank every service robot at "
							+ "least once per completed transaction."
						),
						"risk_label": "Wacky machine-etiquette law",
						"approval_on_sign": 3,
						"approval_on_veto": 1,
						"approval_on_revise": 1,
						"approval_on_delay": 0
					},
					{
						"title": "Predictive Dissent Detention Act",
						"description": (
							"Permit detention based on an AI prediction that "
							+ "someone may criticize the government later."
						),
						"risk_label": "Extreme authoritarian danger",
						"approval_on_sign": -28,
						"approval_on_veto": 18,
						"approval_on_revise": 3,
						"approval_on_delay": -7
					}
				]

			_:
				pool = [
					{
						"title": "National Burial Ground Protection Act",
						"description": (
							"Ban hunting, commercial extraction, and construction "
							+ "on protected burial grounds."
						),
						"risk_label": "Timeless public protection",
						"approval_on_sign": 11,
						"approval_on_veto": -13,
						"approval_on_revise": 4,
						"approval_on_delay": -3
					},
					{
						"title": "Daily Parent Affection Act",
						"description": (
							"Require minors to say 'I love you' to a parent or "
							+ "guardian every day."
						),
						"risk_label": "Wacky family legislation",
						"approval_on_sign": 2,
						"approval_on_veto": 3,
						"approval_on_revise": 1,
						"approval_on_delay": 0
					},
					{
						"title": "Government Criticism Ban",
						"description": (
							"Make peaceful criticism of the government, its "
							+ "leader, or its institutions a criminal offense."
						),
						"risk_label": "Villainous civil-liberty attack",
						"approval_on_sign": -24,
						"approval_on_veto": 16,
						"approval_on_revise": 4,
						"approval_on_delay": -6
					}
				]

		var actor_id: int = int(actor.id)
		var realm_id: int = int(
			summary.get(
				"realm_id",
				actor.realm_id
			)
		)
		var year: int = (
			int(gs.year)
			if gs != null
			else 0
		)
		var cycle: int = _crown_action_cycle(
			actor_id
		)
		var seed_value: int = abs(
			int(
				hash(
					"%d|%d|%d|%d|%s"
					% [
						actor_id,
						realm_id,
						year,
						cycle,
						era_name
					]
				)
			)
		)
		var proposal: Dictionary = _dict(
			pool [
				seed_value % max(1, pool.size())
			]
		).duplicate(true)
		var federal_republic: bool = bool(
			permissions.get(
				"royal_language_forbidden",
				false
			)
		)
		var government_style: String = str(
			summary.get(
				"government_style",
				summary.get(
					"government_model",
					"State"
				)
			)
		).strip_edges()
		var vote_split: Dictionary = {}

		if federal_republic:
			var house_for: int = 180 + (
				seed_value % 170
			)
			var senate_for: int = 40 + (
				int(
					floor(
						float(seed_value) / 11.0
					)
				) % 41
			)
			vote_split = {
				"house_for": house_for,
				"house_against": 435 - house_for,
				"senate_for": senate_for,
				"senate_against": 100 - senate_for,
				"house_override_threshold": 290,
				"senate_override_threshold": 67
			}
			proposal ["institution_reading"] = (
				(
					"Congress passed this bill with a House vote of "
					+ "%d–%d and a Senate vote of %d–%d. "
					+ "The President may sign it, veto it, request revisions, "
					+ "or delay action. A veto can be overridden only if both "
					+ "chambers reach their two-thirds thresholds."
				)
				% [
					house_for,
					435 - house_for,
					senate_for,
					100 - senate_for
				]
			)
		elif (
			government_style.to_lower().find(
				"dictator"
			) >= 0
			or government_style.to_lower().find(
				"authoritarian"
			) >= 0
		):
			proposal ["institution_reading"] = (
				"The state council has submitted this law. "
				+ "The ruler's decision is final, but citizens, military "
				+ "factions, and regional authorities will react."
			)
		else:
			proposal ["institution_reading"] = (
				"The royal court has submitted this law. "
				+ "The sovereign has ultimate legal authority, while court, "
				+ "popular, dynastic, and military legitimacy will react."
			)

		proposal ["schema"] = (
			"eralife.crown_hub.law_review_contract"
		)
		proposal ["version"] = 1
		proposal ["proposal_id"] = (
			"law_%d_%d_%d_%d"
			% [
				actor_id,
				realm_id,
				year,
				cycle
			]
		)
		proposal ["actor_id"] = actor_id
		proposal ["realm_id"] = realm_id
		proposal ["era"] = era_name
		proposal ["government_style"] = government_style
		proposal ["federal_republic"] = federal_republic
		proposal ["vote_split"] = vote_split
		proposal ["veto_always_available"] = true
		proposal ["deterministic"] = true
		proposal ["ui_created_proposal"] = false
		proposal ["ui_is_renderer_only"] = true

		return proposal


func _resident_crown_action_surfaces(
		actor: Person,
		summary: Dictionary,
		permissions: Dictionary,
		constitutional_contract: Dictionary
) -> Dictionary:
		var law_contract: Dictionary = (
			_resident_crown_law_review_contract(
				actor,
				summary,
				permissions
			)
		)
		var federal_republic: bool = bool(
			permissions.get(
				"royal_language_forbidden",
				false
			)
		)
		var realm: Dictionary = _civic_realm_for_actor(
			actor
		)
		var realm_name: String = str(
			summary.get(
				"realm_name",
				"the realm"
			)
		)
		var capital_city: String = str(
			realm.get(
				"capital_city",
				"the capital"
			)
		)
		var subzones: Array = _array(
			realm.get(
				"subzones",
				[]
			)
		)
		var tour_label: String = (
			"Tour %s and the Realm"
			% capital_city
		)

		if not subzones.is_empty():
			tour_label = (
				"Tour %s, %s, and the Realm"
				% [
					capital_city,
					str(subzones [0])
				]
			)

		var law_options: Array = [
			{
				"label": (
					"SIGN THE BILL"
					if federal_republic
					else "SIGN / ENACT"
				),
				"action_id": "sign_bill",
				"payload": {
					"proposal": law_contract.duplicate(true)
				}
			},
			{
				"label": (
					"VETO THE BILL"
					if federal_republic
					else "VETO / REJECT"
				),
				"action_id": "veto_bill",
				"payload": {
					"proposal": law_contract.duplicate(true)
				}
			},
			{
				"label": "REQUEST REVISIONS",
				"action_id": "request_bill_revision",
				"payload": {
					"proposal": law_contract.duplicate(true)
				}
			},
			{
				"label": "DELAY THE DECISION",
				"action_id": "delay_bill",
				"payload": {
					"proposal": law_contract.duplicate(true)
				}
			}
		]

		return {
			"law_review": {
				"schema": (
					"eralife.crown_hub."
					+ "action_surface_contract"
				),
				"version": 1,
				"surface_id": "law_review",
				"section_id": "law",
				"surface_kind": "law_swipe",
				"title": (
					"FEDERAL LAW REVIEW"
					if federal_republic
					else "LAW REVIEW"
				),
				"law_review_contract": law_contract,
				"options": law_options,
				"status_text": (
					"Veto is always available. Constitutional consequences "
					+ "are resolved after the choice."
				),
				"ui_is_renderer_only": true
			},
			"celebrity": {
				"schema": (
					"eralife.crown_hub."
					+ "action_surface_contract"
				),
				"version": 1,
				"surface_id": "celebrity",
				"section_id": "court",
				"surface_kind": "choice_list",
				"title": (
					"EXECUTIVE PRESTIGE"
					if federal_republic
					else "ROYAL CELEBRITY"
				),
				"body": (
					"Prestige can raise fame and public energy, but excessive "
					+ "spectacle can create scandal and resentment."
				),
				"options": [
					{
						"label": "Host a Grand Gala",
						"action_id": "crown_celebrity_action",
						"payload": {
							"kind": "gala",
							"fame_delta": 7,
							"approval_delta": 3,
							"scandal_risk": 8
						}
					},
					{
						"label": "Major Media Appearance",
						"action_id": "crown_celebrity_action",
						"payload": {
							"kind": "media",
							"fame_delta": 9,
							"approval_delta": 2,
							"scandal_risk": 15
						}
					},
					{
						"label": "Prestige Charity Banquet",
						"action_id": "crown_celebrity_action",
						"payload": {
							"kind": "charity",
							"fame_delta": 5,
							"approval_delta": 6,
							"scandal_risk": 4
						}
					},
					{
						"label": "Prestige Tour Across %s" % realm_name,
						"action_id": "crown_celebrity_action",
						"payload": {
							"kind": "prestige_tour",
							"fame_delta": 8,
							"approval_delta": 5,
							"scandal_risk": 7
						}
					}
				],
				"ui_is_renderer_only": true
			},
			"public_service": {
				"schema": (
					"eralife.crown_hub."
					+ "action_surface_contract"
				),
				"version": 1,
				"surface_id": "public_service",
				"section_id": "court",
				"surface_kind": "choice_list",
				"title": "PUBLIC SERVICE",
				"body": (
					"Spend personal money, political attention, and time on "
					+ "citizens. Larger personal sacrifices create stronger "
					+ "approval and happiness effects."
				),
				"options": [
					{
						"label": "Donate 10,000 Personal Wealth",
						"action_id": "crown_public_service_action",
						"payload": {
							"kind": "donate",
							"amount": 10000
						}
					},
					{
						"label": "Donate 100,000 Personal Wealth",
						"action_id": "crown_public_service_action",
						"payload": {
							"kind": "donate",
							"amount": 100000
						}
					},
					{
						"label": "Donate 1,000,000 Personal Wealth",
						"action_id": "crown_public_service_action",
						"payload": {
							"kind": "donate",
							"amount": 1000000
						}
					},
					{
						"label": "Give a Unity Speech",
						"action_id": "crown_public_service_action",
						"payload": {
							"kind": "speech",
							"speech_type": "unity"
						}
					},
					{
						"label": "Give an Economic Speech",
						"action_id": "crown_public_service_action",
						"payload": {
							"kind": "speech",
							"speech_type": "economic"
						}
					},
					{
						"label": "Give a Reform Speech",
						"action_id": "crown_public_service_action",
						"payload": {
							"kind": "speech",
							"speech_type": "reform"
						}
					},
					{
						"label": tour_label,
						"action_id": "crown_public_service_action",
						"payload": {
							"kind": "realm_tour",
							"capital_city": capital_city,
							"subzones": subzones.duplicate(true)
						}
					},
					{
						"label": "Visit Hospitals and Care Centers",
						"action_id": "crown_public_service_action",
						"payload": {
							"kind": "hospital_visit"
						}
					},
					{
						"label": "Lead a Disaster Relief Tour",
						"action_id": "crown_public_service_action",
						"payload": {
							"kind": "relief_tour"
						}
					}
				],
				"ui_is_renderer_only": true
			},
			"public_disservice": {
				"schema": (
					"eralife.crown_hub."
					+ "action_surface_contract"
				),
				"version": 1,
				"surface_id": "public_disservice",
				"section_id": "court",
				"surface_kind": "choice_list",
				"title": "PUBLIC DISSERVICE",
				"body": (
					"Abuse public authority for short-term advantage. Theft and "
					+ "corruption can be discovered later and trigger scandal, "
					+ "criminal consequences, removal, or revolt."
				),
				"options": [
					{
						"label": "Steal 100,000 from the Treasury",
						"action_id": "crown_public_disservice_action",
						"payload": {
							"kind": "steal_treasury",
							"amount": 100000,
							"detection_risk": 18
						}
					},
					{
						"label": "Steal 1,000,000 from the Treasury",
						"action_id": "crown_public_disservice_action",
						"payload": {
							"kind": "steal_treasury",
							"amount": 1000000,
							"detection_risk": 38
						}
					},
					{
						"label": "Steal 10,000,000 from the Treasury",
						"action_id": "crown_public_disservice_action",
						"payload": {
							"kind": "steal_treasury",
							"amount": 10000000,
							"detection_risk": 68
						}
					},
					{
						"label": "Order a Corrupt Crackdown",
						"action_id": "crown_public_disservice_action",
						"payload": {
							"kind": "corrupt_crackdown"
						}
					},
					{
						"label": "Fund an Extravagant Vanity Project",
						"action_id": "crown_public_disservice_action",
						"payload": {
							"kind": "vanity_project"
						}
					}
				],
				"ui_is_renderer_only": true
			},
			"emergency_powers": {
				"schema": (
					"eralife.crown_hub."
					+ "action_surface_contract"
				),
				"version": 1,
				"surface_id": "emergency_powers",
				"section_id": "law",
				"surface_kind": "choice_list",
				"title": "EMERGENCY POWERS",
				"body": (
					"Emergency authority can temporarily increase control, but "
					+ "it causes legitimacy pressure. Martial law carries an "
					+ "especially high risk of immediate revolt."
				),
				"options": [
					{
						"label": "Declare Martial Law",
						"action_id": "emergency_power",
						"payload": {
							"kind": "martial_law",
							"approval_delta": -25,
							"happiness_delta": -24,
							"respect_delta": -10,
							"stability_delta": 14,
							"base_revolt_risk": 42
						}
					},
					{
						"label": "Impose an Emergency Curfew",
						"action_id": "emergency_power",
						"payload": {
							"kind": "emergency_curfew",
							"approval_delta": -10,
							"happiness_delta": -9,
							"respect_delta": -3,
							"stability_delta": 7,
							"base_revolt_risk": 14
						}
					},
					{
						"label": "Begin Emergency Rationing",
						"action_id": "emergency_power",
						"payload": {
							"kind": "emergency_rationing",
							"approval_delta": -4,
							"happiness_delta": -3,
							"respect_delta": 2,
							"stability_delta": 5,
							"base_revolt_risk": 4
						}
					}
				],
				"constitutional_contract": (
					constitutional_contract.duplicate(true)
				),
				"ui_is_renderer_only": true
			},
			"cabinet_management": {
				"schema": (
					"eralife.crown_hub."
					+ "action_surface_contract"
				),
				"version": 1,
				"surface_id": "cabinet_management",
				"section_id": "court",
				"surface_kind": "choice_list",
				"title": "CABINET MANAGEMENT",
				"body": (
					"Appointments are submitted through constitutional authority. "
					+ "Federal appointments may require Senate confirmation; "
					+ "cabinet dismissals remain executive actions."
				),
				"options": [
					{
						"label": "Appoint Secretary of State",
						"action_id": "appoint_official",
						"payload": {
							"office_title": "Secretary of State"
						}
					},
					{
						"label": "Appoint Treasury Secretary",
						"action_id": "appoint_official",
						"payload": {
							"office_title": "Treasury Secretary"
						}
					},
					{
						"label": "Appoint Defense Secretary",
						"action_id": "appoint_official",
						"payload": {
							"office_title": "Defense Secretary"
						}
					},
					{
						"label": "Dismiss a Cabinet Official",
						"action_id": "dismiss_cabinet",
						"payload": {}
					}
				],
				"ui_is_renderer_only": true
			},
			"first_family": {
				"schema": (
					"eralife.crown_hub."
					+ "action_surface_contract"
				),
				"version": 1,
				"surface_id": "first_family",
				"section_id": "dynasty",
				"surface_kind": "choice_list",
				"title": "FIRST FAMILY",
				"body": (
					"The First Family has no hereditary succession authority. "
					+ "Its choices affect public trust, visibility, privacy, "
					+ "security, and charitable reputation."
				),
				"options": [
					{
						"label": "Hold a First Family Public Appearance",
						"action_id": "crown_first_family_action",
						"payload": {
							"kind": "public_appearance"
						}
					},
					{
						"label": "Host a State Dinner",
						"action_id": "crown_first_family_action",
						"payload": {
							"kind": "state_dinner"
						}
					},
					{
						"label": "Launch a Family Charity Initiative",
						"action_id": "crown_first_family_action",
						"payload": {
							"kind": "charity_initiative"
						}
					},
					{
						"label": "Increase Family Privacy and Protection",
						"action_id": "crown_first_family_action",
						"payload": {
							"kind": "privacy_and_protection"
						}
					}
				],
				"ui_is_renderer_only": true
			}
		}

func _civic_crown_section_tabs() -> Array:
	return [
		{
			"id": "throne",
			"label": "OFFICE",
			"icon": " "
		},
		{
			"id": "court",
			"label": "CABINET",
			"icon": " "
		},
		{
			"id": "nation",
			"label": "NATION",
			"icon": " "
		},
		{
			"id": "allocation",
			"label": "BUDGET",
			"icon": " "
		},
		{
			"id": "diplomacy",
			"label": "DIPLOMACY",
			"icon": " "
		},
		{
			"id": "law",
			"label": "LAW",
			"icon": " "
		},
		{
			"id": "dynasty",
			"label": "FIRST FAMILY",
			"icon": " "
		}
	]


func _build_civic_crown_section_surfaces(
	actor: Person,
	summary: Dictionary,
	permissions: Dictionary,
	constitutional_contract: Dictionary
) -> Dictionary:
	var first_family_rows: Array = []

	if actor.partner != null:
		first_family_rows.append(
			_person_projection(
				actor.partner
			)
		)

	return {
		"throne": [
			{
				"row_kind": "executive_office_summary",
				"title": str(
					summary.get(
						"office_full_title",
						summary.get(
							"title",
							"Executive Office"
						)
					)
				),
				"subtitle": str(
					summary.get(
						"realm_name",
						"United States"
					)
				),
				"description": (
					"Approval %d • Stability %d • "
					+ "Constitutional executive authority"
				) % [
					int(
						summary.get(
							"approval",
							0
						)
					),
					int(
						summary.get(
							"stability",
							0
						)
					)
				],
				"data": summary.duplicate(true),
				"actions": []
			}
		],
		"court": [
			{
				"row_kind": "executive_cabinet",
				"title": "Federal Cabinet",
				"description": (
					"Executive departments and appointed "
					+ "constitutional officers."
				),
				"rows": [],
				"actions": []
			}
		],
		"nation": [
			{
				"row_kind": "federal_nation",
				"title": str(
					summary.get(
						"realm_name",
						"United States"
					)
				),
				"description": (
					"Population %d • Treasury %d • Land %d"
				) % [
					int(
						summary.get(
							"population",
							0
						)
					),
					int(
						summary.get(
							"treasury",
							0
						)
					),
					int(
						summary.get(
							"land",
							0
						)
					)
				],
				"data": summary.duplicate(true),
				"actions": []
			}
		],
		"allocation": [
			{
				"row_kind": "federal_budget",
				"title": "Federal Budget",
				"description": (
					"Treasury %d • Allocation Pool %d"
				) % [
					int(
						summary.get(
							"treasury",
							0
						)
					),
					int(
						summary.get(
							"allocation_pool",
							0
						)
					)
				],
				"data": summary.duplicate(true),
				"actions": []
			}
		],
		"diplomacy": [
			{
				"row_kind": "federal_diplomacy",
				"title": "Diplomatic Authority",
				"description": (
					"Foreign relations remain governed by "
					+ "constitutional checks and balances."
				),
				"data": permissions.duplicate(true),
				"actions": []
			}
		],
		"law": [
			{
				"row_kind": "constitutional_contract",
				"title": "Federal Constitutional Authority",
				"data": (
					constitutional_contract.duplicate(true)
				),
				"actions": []
			}
		],
		"dynasty": [
			{
				"row_kind": "first_family",
				"title": "First Family",
				"rows": first_family_rows,
				"actions": []
			}
		]
	}


func _stable_crown_surface_revision(
	actor: Person,
	institution: Dictionary,
	summary: Dictionary,
	permissions: Dictionary,
	succession_rows: Array,
	family_rows: Array,
	court_rows: Array,
	claimant_rows: Array,
	active_section: String,
	civic_contract: Dictionary
) -> String:
	var institution_semantics: Dictionary = {
		"institution_id": str(
			institution.get(
				"institution_id",
				""
			)
		),
		"realm_id": int(
			institution.get(
				"realm_id",
				actor.realm_id
			)
		),
		"monarch_id": int(
			institution.get(
				"monarch_id",
				-1
			)
		),
		"consort_id": int(
			institution.get(
				"consort_id",
				-1
			)
		),
		"regent_id": int(
			institution.get(
				"regent_id",
				-1
			)
		),
		"regency_active": bool(
			institution.get(
				"regency_active",
				false
			)
		),
		"member_ids": _array(
			institution.get(
				"member_ids",
				[]
			)
		),
		"court_member_ids": _array(
			institution.get(
				"court_member_ids",
				[]
			)
		),
		"claimant_ids": _array(
			institution.get(
				"claimant_ids",
				[]
			)
		),
		"legitimacy": int(
			institution.get(
				"legitimacy",
				0
			)
		),
		"stability": int(
			institution.get(
				"stability",
				0
			)
		),
		"population": int(
			institution.get(
				"population",
				0
			)
		),
		"treasury": int(
			institution.get(
				"treasury",
				0
			)
		),
		"land": int(
			institution.get(
				"land",
				0
			)
		)
	}
	var summary_semantics: Dictionary = {}

	for raw_key in [
		"title",
		"office_full_title",
		"realm_id",
		"realm_name",
		"government_model",
		"government_style",
		"approval",
		"legitimacy",
		"respect",
		"happiness",
		"stability",
		"population",
		"treasury",
		"land",
		"allocation_pool",
		"tax_rate",
		"standing",
		"integrity_state",
		"alerts",
		"federal_republic"
	]:
		var key: String = str(
			raw_key
		)

		summary_semantics [
			key
		] = summary.get(
			key,
			null
		)

	var people_semantics: Dictionary = {
		"succession": succession_rows,
		"family": family_rows,
		"court": court_rows,
		"claimants": claimant_rows
	}

	return "%d:%d:%s:%s:%s:%s:%s:%s:%d" % [
		int(
			actor.id
		),
		int(
			gs.year
			if gs != null
			else 0
		),
		active_section,
		str(
			hash(
				institution_semantics
			)
		),
		str(
			hash(
				summary_semantics
			)
		),
		str(
			hash(
				permissions
			)
		),
		str(
			hash(
				people_semantics
			)
		),
		str(
			hash(
				civic_contract
			)
		),
		_provider_revision()
	]

func emit_crown_hub_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No Crown Hub observer could be resolved."
		)

	if (
		_runtime() == null
		or _law() == null
	):
		return emit_observable_contract(
			actor,
			context
		)




	var civic_contract: Dictionary = (
		_civic_office_contract_for_actor(
			actor
		)
	)
	var civic_projection: bool = (
		_actor_uses_civic_crown_projection(
			actor
		)
	)
	var realm: Dictionary = (
		_civic_realm_for_actor(
			actor
		)
	)




	var institution: Dictionary = {}

	if not civic_projection:
		institution = (
			_runtime().institution_for_actor(
				actor
			)
		)

		if institution.is_empty():
			return emit_observable_contract(
				actor,
				context
			)

	var summary: Dictionary = (
		_law().summary_for_actor(
			actor
		)
	)
	var permissions: Dictionary = (
		_law().permissions_for_actor(
			actor
		)
	)

	summary = _crown_summary_with_civic_office(
		actor,
		summary,
		civic_contract,
		realm
	)
	permissions = (
		_crown_permissions_with_civic_office(
			actor,
			permissions,
			civic_contract
		)
	)

	var constitutional_contract: Dictionary = {}

	if civic_projection:
		constitutional_contract = (
			_civic_constitutional_contract_for_actor(
				actor,
				civic_contract,
				realm
			)
		)
	else:
		constitutional_contract = (
			_law().constitutional_contract_for_actor(
				actor
			)
		)

	var succession_report: Dictionary = {}
	var succession_rows: Array = []

	if not civic_projection:
		succession_report = (
			_law().evaluate_succession_for_institution(
				institution,
				{
					"source": (
						"crown_hub_contract_engine."
						+ "emit_crown_hub_contract"
					)
				}
			)
		)
		succession_rows = _array(
			succession_report.get(
				"candidates",
				[]
			)
		)

	var family_rows: Array = []

	if civic_projection:
		if actor.partner != null:
			family_rows.append(
				_person_projection(
					actor.partner
				)
			)
	else:
		family_rows = _people_projection(
			_array(
				institution.get(
					"member_ids",
					[]
				)
			)
		)

	var court_rows: Array = (
		[]
		if civic_projection
		else _people_projection(
			_array(
				institution.get(
					"court_member_ids",
					[]
				)
			)
		)
	)
	var claimant_rows: Array = (
		[]
		if civic_projection
		else _people_projection(
			_array(
				institution.get(
					"claimant_ids",
					[]
				)
			)
		)
	)
	var house: Dictionary = (
		{}
		if civic_projection
		else _runtime().house_for_actor(
			actor
		)
	)
	var dynasties: Array = []

	if not house.is_empty():
		dynasties.append(
			house.duplicate(true)
		)

	var mod_rows: Dictionary = (
		{}
		if civic_projection
		else _royalty_provider_rows(
			actor
		)
	)
	var section_surfaces: Dictionary = (
		_build_civic_crown_section_surfaces(
			actor,
			summary,
			permissions,
			constitutional_contract
		)
		if civic_projection
		else _build_section_surfaces(
			actor,
			institution,
			summary,
			permissions,
			family_rows,
			court_rows,
			claimant_rows,
			succession_rows,
			dynasties,
			mod_rows
		)
	)
	var active_section: String = _section(
		str(
			context.get(
				"active_section",
				_lens_for(
					actor
				).get(
					"active_section",
					"throne"
				)
			)
		)
	)
	var status_text: String = str(
		context.get(
			"status_text",
			""
		)
	).strip_edges()

	if status_text == "":
		if civic_projection:
			status_text = (
				"%s • Approval %d • Stability %d"
				% [
					str(
						summary.get(
							"realm_name",
							"United States"
						)
					),
					int(
						summary.get(
							"approval",
							0
						)
					),
					int(
						summary.get(
							"stability",
							0
						)
					)
				]
			)
		else:
			status_text = (
				(
					"%s • Legitimacy %d • Stability %d • "
					+ "%d successors • %d claimants"
				)
				% [
					str(
						summary.get(
							"realm_name",
							"Royal Institution"
						)
					),
					int(
						summary.get(
							"legitimacy",
							0
						)
					),
					int(
						summary.get(
							"stability",
							0
						)
					),
					succession_rows.size(),
					claimant_rows.size()
				]
			)

	var surface_revision: String = (
		_stable_crown_surface_revision(
			actor,
			institution,
			summary,
			permissions,
			succession_rows,
			family_rows,
			court_rows,
			claimant_rows,
			active_section,
			civic_contract
		)
	)

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": int(
			actor.id
		),
		"actor_name": _person_name(
			actor
		),
		"title": (
			" FEDERAL HUB"
			if civic_projection
			else " CROWN HUB"
		),
		"subtitle": (
			(
				"Executive office, cabinet, nation, budget, "
				+ "diplomacy, and constitutional law."
			)
			if civic_projection
			else (
				"Monarchy, dynasty, court, law, and succession "
				+ "as one institutional reality."
			)
		),
		"active_section": active_section,
		"section_tabs": (
			_civic_crown_section_tabs()
			if civic_projection
			else _section_tabs()
		),
		"summary": summary,
		"permissions": permissions,
		"institution": institution,
		"civic_office_contract": (
			civic_contract.duplicate(true)
		),
		"constitutional_contract": (
			constitutional_contract.duplicate(true)
		),
		"current_monarch": (
			{}
			if civic_projection
			else _person_projection(
				_person_by_id(
					int(
						institution.get(
							"monarch_id",
							-1
						)
					)
				)
			)
		),
		"current_office_holder": (
			_person_projection(
				actor
			)
			if civic_projection
			else {}
		),
		"royal_family": (
			[]
			if civic_projection
			else family_rows
		),
		"first_family": (
			family_rows
			if civic_projection
			else []
		),
		"court": court_rows,
		"dynasties": dynasties,
		"claimants": claimant_rows,
		"succession": succession_report,
		"royal_authority": permissions,
		"realm_stability": int(
			summary.get(
				"stability",
				institution.get(
					"stability",
					0
				)
			)
		),
		"diplomatic_houses": _array(
			institution.get(
				"diplomatic_houses",
				[]
			)
		),
		"royal_assets": (
			[]
			if civic_projection
			else _array(
				institution.get(
					"royal_assets",
					[]
				)
			)
		),
		"royal_decrees": (
			[]
			if civic_projection
			else _array(
				institution.get(
					"decrees",
					[]
				)
			)
		),
		"ceremonies": (
			[]
			if civic_projection
			else _array(
				institution.get(
					"ceremonies",
					[]
				)
			)
		),
		"line_of_succession": succession_rows,
		"mod_provider_rows": mod_rows,
		"section_surfaces": section_surfaces,
		"active_section_rows": _array(
			section_surfaces.get(
				active_section,
				[]
			)
		),
		"status_text": status_text,
		"truth_state": "hot",
		"authoritative_projection": true,
		"surface_revision": surface_revision,
		"crown_hub_layout_variant": (
			"federal_republic"
			if civic_projection
			else "royalty"
		),
		"federal_republic": civic_projection,
		"royal_language_forbidden": civic_projection,
		"runtime_authority": (
			"realm_engine"
			if civic_projection
			else "royalty_runtime_engine"
		),
		"constitutional_authority": (
			"checks_and_balances_contract_engine"
			if civic_projection
			else "royalty_contract_engine"
		),
		"mod_authority": (
			""
			if civic_projection
			else "royalty_mod_contract_engine"
		),
		"ui_is_renderer_only": true
	}
func _resident_diplomacy_entry_is_era_kingdom(
	realm: Dictionary
) -> bool:
	if realm.is_empty():
		return false

	var identity_markers: Array = [
		str(
			realm.get(
				"entry_id",
				""
			)
		),
		str(
			realm.get(
				"hidden_realm_id",
				""
			)
		),
		str(
			realm.get(
				"realm_key",
				""
			)
		),
		str(
			realm.get(
				"id",
				""
			)
		),
		str(
			realm.get(
				"name",
				""
			)
		)
	]

	for raw_marker in identity_markers:
		var marker: String = str(
			raw_marker
		).strip_edges().to_lower()

		if marker in [
			"era_kingdom",
			"era kingdom",
			"the era kingdom"
		]:
			return true

	return false


func _resident_diplomacy_element_key(
	realm: Dictionary
) -> String:
	var explicit_element: String = str(
		realm.get(
			"native_element",
			realm.get(
				"element",
				realm.get(
					"bending_element",
					""
				)
			)
		)
	).strip_edges().to_lower()

	if explicit_element in [
		"fire",
		"earth",
		"water",
		"air"
	]:
		return explicit_element

	var realm_name: String = str(
		realm.get(
			"name",
			""
		)
	).strip_edges().to_lower()

	if realm_name.find(
		"fire nation"
	) >= 0:
		return "fire"

	if (
		realm_name.find(
			"earth kingdom"
		) >= 0
		or realm_name.find(
			"earth nation"
		) >= 0
	):
		return "earth"

	if (
		realm_name.find(
			"water tribe"
		) >= 0
		or realm_name.find(
			"water nation"
		) >= 0
	):
		return "water"

	if (
		realm_name.find(
			"air nomad"
		) >= 0
		or realm_name.find(
			"air temple"
		) >= 0
	):
		return "air"

	return ""


func _resident_diplomacy_default_ruler_title(
	realm: Dictionary,
	element_key: String
) -> String:
	var realm_name: String = str(
		realm.get(
			"name",
			""
		)
	).strip_edges().to_lower()
	var government_text: String = (
		"%s %s"
		% [
			str(
				realm.get(
					"realm_kind",
					""
				)
			),
			str(
				realm.get(
					"government_style",
					realm.get(
						"government_model",
						""
					)
				)
			)
		]
	).strip_edges().to_lower()

	if realm_name.find(
		"fire nation"
	) >= 0:
		return "Fire Lord"

	if realm_name.find(
		"earth kingdom"
	) >= 0:
		return "Earth King"

	if realm_name.find(
		"water tribe"
	) >= 0:
		return "Chief"

	if element_key == "air":
		return "Air Council"

	if government_text.find(
		"empire"
	) >= 0:
		return "Emperor"

	if government_text.find(
		"kingdom"
	) >= 0:
		return "Monarch"

	if (
		government_text.find(
			"republic"
		) >= 0
		or government_text.find(
			"presidential"
		) >= 0
	):
		return "President"

	if government_text.find(
		"tribe"
	) >= 0:
		return "Chief"

	return "Head of State"

func _resident_diplomacy_strip_leader_prefix(
	value: String
) -> String:
	var out: String = str(
		value
	).strip_edges()

	while out != "":
		var lower_text: String = out.to_lower()

		if lower_text.begins_with(
			"leader:"
		):
			out = out.substr(
				"leader:".length()
			).strip_edges()
			continue

		if lower_text.begins_with(
			"leader -"
		):
			out = out.substr(
				"leader -".length()
			).strip_edges()
			continue

		if lower_text.begins_with(
			"leader —"
		):
			out = out.substr(
				"leader —".length()
			).strip_edges()
			continue

		break

	return out
func _resident_diplomacy_ruler_projection(
	realm: Dictionary
) -> Dictionary:
	if realm.is_empty():
		return {}

	var ruler_id: int = int(
		realm.get(
			"ruler_id",
			realm.get(
				"ruler_npc_id",
				realm.get(
					"leader_id",
					-1
				)
			)
		)
	)
	var leader_contract_raw: Variant = realm.get(
		"leader_identity_contract",
		realm.get(
			"ruler_identity_contract",
			{}
		)
	)
	var leader_contract: Dictionary = (
		leader_contract_raw as Dictionary
		if typeof(leader_contract_raw) == TYPE_DICTIONARY
		else {}
	)
	var leader_contract_person_id: int = int(
		leader_contract.get(
			"leader_person_id",
			leader_contract.get(
				"ruler_id",
				-1
			)
		)
	)
	var leader_contract_matches_ruler: bool = (
		ruler_id > 0
		and leader_contract_person_id == ruler_id
	)
	var leader_contract_authoritative: bool = (
		leader_contract_matches_ruler
		and bool(
			leader_contract.get(
				"authoritative_ruler_identity",
				false
			)
		)
		and not bool(
			leader_contract.get(
				"deterministic_realm_identity",
				false
			)
		)
	)
	var ruler_snapshot: Dictionary = (
		_resident_diplomacy_read_only_person_snapshot(
			ruler_id
		)
	)
	var canonical_person_hot: bool = (
		not ruler_snapshot.is_empty()
	)
	var ruler_name: String = ""
	var ruler_title: String = ""
	var explicit_label: String = ""

	if leader_contract_authoritative:
		ruler_name = str(
			leader_contract.get(
				"leader_name",
				leader_contract.get(
					"display_name",
					""
				)
			)
		).strip_edges()
		ruler_title = str(
			leader_contract.get(
				"leader_title",
				""
			)
		).strip_edges()
		explicit_label = (
			_resident_diplomacy_strip_leader_prefix(
				str(
					leader_contract.get(
						"leader_label",
						leader_contract.get(
							"display_label",
							""
						)
					)
				)
			)
		)
	else:
		ruler_name = str(
			realm.get(
				"ruler_name",
				realm.get(
					"leader_name",
					""
				)
			)
		).strip_edges()
		ruler_title = str(
			realm.get(
				"ruler_title",
				realm.get(
					"leader_title",
					realm.get(
						"head_of_state_title",
						""
					)
				)
			)
		).strip_edges()

	if canonical_person_hot:
		var canonical_name: String = str(
			ruler_snapshot.get(
				"display_name",
				""
			)
		).strip_edges()

		if canonical_name != "":
			ruler_name = canonical_name






		if ruler_title == "":
			for raw_title in [
				ruler_snapshot.get(
					"royal_title",
					""
				),
				ruler_snapshot.get(
					"civic_title",
					""
				),
				ruler_snapshot.get(
					"job",
					""
				)
			]:
				var candidate_title: String = str(
					raw_title
				).strip_edges()

				if candidate_title == "":
					continue

				ruler_title = candidate_title
				break

		if not leader_contract_authoritative:
			explicit_label = ""

	if ruler_title == "":
		for raw_title in [
			ruler_snapshot.get(
				"royal_title",
				""
			),
			ruler_snapshot.get(
				"civic_title",
				""
			),
			ruler_snapshot.get(
				"job",
				""
			)
		]:
			var candidate_title: String = str(
				raw_title
			).strip_edges()

			if candidate_title == "":
				continue

			ruler_title = candidate_title
			break

	var element_key: String = (
		_resident_diplomacy_element_key(
			realm
		)
	)

	if ruler_title == "":
		ruler_title = (
			_resident_diplomacy_default_ruler_title(
				realm,
				element_key
			)
		)

	var is_era_kingdom: bool = (
		_resident_diplomacy_entry_is_era_kingdom(
			realm
		)
	)

	if (
		is_era_kingdom
		and ruler_name == ""
	):
		ruler_name = "Prophecy Regent"

	if (
		is_era_kingdom
		and ruler_title in [
			"",
			"Head of State"
		]
	):
		ruler_title = "Prophecy Regent"

	var ruler_display: String = ""

	if explicit_label != "":
		ruler_display = explicit_label
	elif (
		ruler_name != ""
		and ruler_title != ""
		and ruler_name.to_lower()
		!= ruler_title.to_lower()
	):
		ruler_display = (
			"%s %s"
			% [
				ruler_title,
				ruler_name
			]
		).strip_edges()
	elif ruler_name != "":
		ruler_display = ruler_name
	elif ruler_title != "":
		ruler_display = ruler_title

	ruler_display = (
		_resident_diplomacy_strip_leader_prefix(
			ruler_display
		)
	)

	if ruler_display == "":
		ruler_display = (
			"%s Office Holder"
			% ruler_title
		).strip_edges()

	return {
		"ruler_id": ruler_id,
		"ruler_name": ruler_name,
		"ruler_title": ruler_title,
		"ruler_display": ruler_display,
		"ruler_label": (
			"Leader: %s"
			% ruler_display
		),
		"leader_identity_contract_hot": (
			not leader_contract.is_empty()
		),
		"leader_identity_contract_person_id": (
			leader_contract_person_id
		),
		"leader_identity_contract_matches_ruler": (
			leader_contract_matches_ruler
		),
		"leader_identity_contract_authoritative": (
			leader_contract_authoritative
		),
		"canonical_ruler_person_snapshot_hot": (
			canonical_person_hot
		),
		"canonical_ruler_person_identity_wins": (
			canonical_person_hot
		),
		"leader_identity_revision": int(
			realm.get(
				"leader_identity_revision",
				0
			)
		),
		"runtime_person_hot": bool(
			ruler_snapshot.get(
				"runtime_person_hot",
				false
			)
		),
		"dormant_snapshot_used": bool(
			ruler_snapshot.get(
				"dormant_snapshot",
				false
			)
		),
		"leader_prefix_count": 1
	}
func _resident_diplomacy_compact_entry(
	realm_id: int,
	realm: Dictionary,
	actor_realm_id: int,
	permissions: Dictionary,
	war_registry: Dictionary = {},
	war_preview: Dictionary = {},
	relation_contract: Dictionary = {}
) -> Dictionary:
	if realm.is_empty():
		return {}

	var realm_name: String = str(
		realm.get(
			"name",
			"Realm %d" % realm_id
		)
	).strip_edges()

	if realm_name == "":
		return {}

	var is_era_kingdom: bool = (
		_resident_diplomacy_entry_is_era_kingdom(
			realm
		)
	)
	var realm_key: String = (
		_resident_diplomacy_population_rank_realm_key(
			realm_id,
			realm
		)
	)



	var controlled_actor: Person = (
		gs.player
		if (
			gs != null
			and gs.player != null
			and int(
				gs.player.realm_id
			) == actor_realm_id
		)
		else null
	)
	var actor_realm_key: String = ""

	if controlled_actor != null:
		var actor_realm_name: String = str(
			controlled_actor.home_country
		).strip_edges()
		var civic_contract: Dictionary = (
			_civic_office_contract_for_actor(
				controlled_actor
			)
		)
		var civic_country: String = str(
			civic_contract.get(
				"country",
				""
			)
		).strip_edges()

		if civic_country != "":
			actor_realm_name = civic_country

		if actor_realm_name != "":
			actor_realm_key = (
				_resident_diplomacy_population_rank_realm_key(
					actor_realm_id,
					{
						"name": actor_realm_name
					}
				)
			)

	var is_player_country: bool = (
		realm_id > 0
		and (
			realm_id == actor_realm_id
			or (
				actor_realm_key != ""
				and realm_key == actor_realm_key
			)
		)
	)
	var projection_realm_id: int = (
		actor_realm_id
		if (
			is_player_country
			and actor_realm_id > 0
		)
		else realm_id
	)
	var population_browse_available: bool = (
		projection_realm_id > 0
		and not is_era_kingdom
		and not bool(
			realm.get(
				"hide_people_button",
				false
			)
		)
	)
	var effective_war_realm_id: int = (
		WarContractEngine.ERA_KINGDOM_WAR_REALM_ID
		if is_era_kingdom
		else projection_realm_id
	)
	var element_key: String = (
		_resident_diplomacy_element_key(
			realm
		)
	)




	var ruler_source: Dictionary = realm
	var controlled_actor_is_ruler: bool = false

	if controlled_actor != null:
		controlled_actor_is_ruler = (
			bool(
				controlled_actor.is_ruler
			)
			or _actor_uses_civic_crown_projection(
				controlled_actor
			)
		)

	if (
		is_player_country
		and controlled_actor != null
		and controlled_actor_is_ruler
	):
		ruler_source = realm.duplicate(false)
		ruler_source ["ruler_id"] = int(
			controlled_actor.id
		)
		ruler_source ["ruler_npc_id"] = int(
			controlled_actor.id
		)
		ruler_source ["leader_id"] = int(
			controlled_actor.id
		)
		ruler_source ["ruler_name"] = (
			_person_name(
				controlled_actor
			)
		)

		var civic_contract: Dictionary = (
			_civic_office_contract_for_actor(
				controlled_actor
			)
		)
		var authority_title: String = str(
			civic_contract.get(
				"office",
				civic_contract.get(
					"office_full_title",
					controlled_actor.royal_title
				)
			)
		).strip_edges()

		if authority_title.begins_with(
			"The "
		):
			authority_title = (
				authority_title.trim_prefix(
					"The "
				)
			)

		if authority_title == "":
			authority_title = str(
				controlled_actor.royal_title
			).strip_edges()

		if authority_title != "":
			ruler_source ["ruler_title"] = (
				authority_title
			)



		ruler_source.erase(
			"leader_identity_contract"
		)
		ruler_source.erase(
			"ruler_identity_contract"
		)

	var ruler_projection: Dictionary = (
		_resident_diplomacy_ruler_projection(
			ruler_source
		)
	)
	var realm_kind: String = str(
		realm.get(
			"realm_kind",
			"state"
		)
	).strip_edges().to_lower()
	var government_style: String = str(
		realm.get(
			"government_style",
			realm.get(
				"government_model",
				realm_kind
			)
		)
	).strip_edges()

	var can_interact: bool = (
		not is_player_country
		and not is_era_kingdom
	)
	var active_war: Dictionary = {}

	for raw_war in _array(
		war_registry.get(
			"global_active_wars",
			war_registry.get(
				"active_wars",
				[]
			)
		)
	):
		var candidate_war: Dictionary = _dict(
			raw_war
		)

		if candidate_war.is_empty():
			continue

		var attacker_ids: Array = _array(
			candidate_war.get(
				"attacker_side_realm_ids",
				[
					int(
						candidate_war.get(
							"attacker_realm_id",
							-1
						)
					)
				]
			)
		)
		var defender_ids: Array = _array(
			candidate_war.get(
				"defender_side_realm_ids",
				[
					int(
						candidate_war.get(
							"defender_realm_id",
							-1
						)
					)
				]
			)
		)

		if (
			effective_war_realm_id in attacker_ids
			or effective_war_realm_id in defender_ids
		):
			active_war = candidate_war
			break

	var relation_score: int = (
		100
		if is_player_country
		else int(
			relation_contract.get(
				"score",
				0
			)
		)
	)
	var relation_label: String = (
		"Domestic"
		if is_player_country
		else str(
			relation_contract.get(
				"tier_label",
				"Neutral"
			)
		)
	)
	var declaration_authority_available: bool = (
		can_interact
		and bool(
			permissions.get(
				"can_declare_war",
				false
			)
		)
	)
	var resolved_war_preview: Dictionary = (
		{}
		if is_player_country
		else war_preview.duplicate(false)
	)

	if (
		declaration_authority_available
		and resolved_war_preview.is_empty()
	):
		resolved_war_preview = {
			"success": true,
			"schema": "eralife.war.preview.pending_contract",
			"version": 1,
			"preview_pending": true,
			"truth_state": "observable_partial",
			"declaration_allowed": true,
			"attacker_realm_id": actor_realm_id,
			"defender_realm_id": projection_realm_id,
			"attacker": {
				"realm_id": actor_realm_id,
				"name": "Your Realm"
			},
			"defender": {
				"realm_id": projection_realm_id,
				"name": realm_name
			},
			"relation_contract": (
				relation_contract.duplicate(false)
			),
			"metrics": [],
			"ui_is_renderer_only": true
		}

	var preview_pending: bool = bool(
		resolved_war_preview.get(
			"preview_pending",
			false
		)
	)
	var declaration_door_available: bool = (
		declaration_authority_available
		and (
			preview_pending
			or bool(
				resolved_war_preview.get(
					"declaration_allowed",
					false
				)
			)
		)
	)
	var land_km2: int = maxi(
		0,
		int(
			realm.get(
				"land",
				realm.get(
					"land_area_km2",
					realm.get(
						"land_km2",
						realm.get(
							"land_size",
							0
						)
					)
				)
			)
		)
	)

	if (
		land_km2 > 0
		and land_km2 < 10000
		and not bool(
			realm.get(
				"land_contract_real_units",
				false
			)
		)
	):
		land_km2 *= 1000

	var land_mi2: int = int(
		round(
			float(
				land_km2
			) * 0.3861021585
		)
	)
	var out: Dictionary = {
		"country": realm_name,
		"realm_id": projection_realm_id,
		"source_realm_id": realm_id,
		"canonical_realm_id": projection_realm_id,
		"population_realm_id": projection_realm_id,
		"population_realm_name": realm_name,
		"population_browse_available": (
			population_browse_available
		),
		"population_observation_arms_on_selection": (
			population_browse_available
		),
		"war_realm_id": effective_war_realm_id,
		"realm_key": realm_key,
		"canonical_realm_key": realm_key,
		"realm_kind": realm_kind,
		"government_style": government_style,
		"population": int(
			realm.get(
				"population",
				0
			)
		),
		"capital_city": str(
			realm.get(
				"capital_city",
				"Capital City"
			)
		),
		"land_km2": land_km2,
		"land_area_km2": land_km2,
		"land_mi2": land_mi2,
		"land_area_mi2": land_mi2,
		"land_display_value": land_km2,
		"land_display_unit": "km²",
		"land_display_label": (
			"%d km²"
			% land_km2
		),
		"land_measurement_authority": (
			"realm_engine"
		),
		"treasury": int(
			realm.get(
				"treasury",
				0
			)
		),
		"currency_name": str(
			realm.get(
				"currency_name",
				"Treasury"
			)
		),
		"military_stockpile": int(
			realm.get(
				"military_stockpile",
				0
			)
		),
		"goods_stockpile": int(
			realm.get(
				"goods_stockpile",
				0
			)
		),
		"ruler_id": int(
			ruler_projection.get(
				"ruler_id",
				-1
			)
		),
		"ruler_name": str(
			ruler_projection.get(
				"ruler_name",
				"Unassigned"
			)
		),
		"ruler_title": str(
			ruler_projection.get(
				"ruler_title",
				"Head of State"
			)
		),
		"ruler_label": str(
			ruler_projection.get(
				"ruler_label",
				"Head of State: Unassigned"
			)
		),
		"relation_score": relation_score,
		"relation_tier": (
			"domestic"
			if is_player_country
			else str(
				relation_contract.get(
					"tier",
					"neutral"
				)
			)
		),
		"posture": relation_label,
		"trade_mood": str(
			realm.get(
				"trade_mood",
				"Open"
			)
		),
		"element": element_key,
		"is_elemental_realm": (
			element_key != ""
		),
		"is_player_country": is_player_country,
		"is_era_kingdom": is_era_kingdom,
		"in_active_war": (
			not active_war.is_empty()
		),
		"active_war_id": str(
			active_war.get(
				"war_id",
				""
			)
		),
		"active_war_contract": active_war,
		"war_banner": (
			"AT WAR"
			if not active_war.is_empty()
			else ""
		),
		"can_trade": can_interact,
		"can_gift": can_interact,
		"can_bribe": (
			not is_player_country
			and (
				can_interact
				or is_era_kingdom
			)
		),
		"special_bribe_confirmation_required": (
			is_era_kingdom
		),
		"can_declare_war": (
			declaration_door_available
		),
		"war_preview_contract": (
			resolved_war_preview.duplicate(false)
		),
		"war_preview_deferred": preview_pending,
		"war_preview_pending": preview_pending,
		"ui_is_renderer_only": true
	}

	var rank_contract_raw: Variant = get_meta(
		"resident_diplomacy_population_rank_cache",
		{}
	)
	var rank_contract: Dictionary = (
		(rank_contract_raw as Dictionary).duplicate(false)
		if typeof(rank_contract_raw) == TYPE_DICTIONARY
		else {}
	)



	if rank_contract.is_empty():
		rank_contract = (
			_resident_diplomacy_population_rank_contract()
		)
		set_meta(
			"resident_diplomacy_population_rank_cache",
			rank_contract.duplicate(false)
		)

	out = _attach_resident_diplomacy_population_rank(
		out,
		rank_contract
	)

	return out
func _resident_diplomacy_country_entries(
	actor: Person,
	summary: Dictionary,
	permissions: Dictionary = {}
) -> Array:
	var entries: Array = []

	if (
		actor == null
		or gs == null
		or gs.realm_engine == null
	):
		return entries

	var realms_raw: Variant = (
		gs.realm_engine.get(
			"realms"
		)
	)
	var realms: Dictionary = (
		realms_raw as Dictionary
		if typeof(realms_raw) == TYPE_DICTIONARY
		else {}
	)
	var actor_realm_id: int = int(
		summary.get(
			"realm_id",
			actor.realm_id
		)
	)
	var actor_realm_seen: bool = false
	var seen_realm_keys: Dictionary = {}

	for raw_realm_id in realms.keys():
		var realm_id: int = int(
			raw_realm_id
		)

		if realm_id <= 0:
			continue

		var realm: Dictionary = _dict(
			realms.get(
				raw_realm_id,
				{}
			)
		)

		if realm.is_empty():
			continue

		var entry: Dictionary = (
			_resident_diplomacy_compact_entry(
				realm_id,
				realm,
				actor_realm_id,
				permissions
			)
		)

		if entry.is_empty():
			continue

		var realm_key: String = str(
			entry.get(
				"realm_key",
				"realm:%d" % realm_id
			)
		)

		if seen_realm_keys.has(
			realm_key
		):
			continue

		seen_realm_keys [
			realm_key
		] = true

		if bool(
			entry.get(
				"is_player_country",
				false
			)
		):
			actor_realm_seen = true

		entries.append(
			entry
		)



	if gs.many_realms_engine != null:
		var hidden_realms_raw: Variant = (
			gs.many_realms_engine.get(
				"hidden_realms"
			)
		)
		var hidden_realms: Dictionary = (
			hidden_realms_raw as Dictionary
			if typeof(
				hidden_realms_raw
			) == TYPE_DICTIONARY
			else {}
		)
		var era_kingdom: Dictionary = _dict(
			hidden_realms.get(
				"era_kingdom",
				{}
			)
		)

		if not era_kingdom.is_empty():
			era_kingdom [
				"entry_id"
			] = "era_kingdom"
			era_kingdom [
				"hidden_realm_id"
			] = "era_kingdom"
			era_kingdom [
				"name"
			] = str(
				era_kingdom.get(
					"name",
					"Era Kingdom"
				)
			)

			var era_entry: Dictionary = (
				_resident_diplomacy_compact_entry(
					int(
						era_kingdom.get(
							"realm_id",
							-1
						)
					),
					era_kingdom,
					actor_realm_id,
					permissions
				)
			)

			if (
				not era_entry.is_empty()
				and not seen_realm_keys.has(
					"era_kingdom"
				)
			):
				era_entry [
					"realm_key"
				] = "era_kingdom"
				era_entry [
					"is_era_kingdom"
				] = true
				era_entry [
					"can_trade"
				] = false
				era_entry [
					"can_gift"
				] = false
				era_entry [
					"can_bribe"
				] = false
				era_entry [
					"can_declare_war"
				] = false

				seen_realm_keys [
					"era_kingdom"
				] = true
				entries.append(
					era_entry
				)



	if (
		not actor_realm_seen
		and actor_realm_id > 0
		and not summary.is_empty()
	):
		var actor_realm_projection: Dictionary = {
			"id": str(actor_realm_id),
			"realm_id": actor_realm_id,
			"name": str(
				summary.get(
					"realm_name",
					actor.home_country
				)
			),
			"realm_kind": str(
				summary.get(
					"realm_kind",
					"state"
				)
			),
			"government_style": str(
				summary.get(
					"government_style",
					"Monarchy"
				)
			),
			"population": int(
				summary.get(
					"population",
					0
				)
			),
			"capital_city": str(
				summary.get(
					"capital_city",
					"Capital City"
				)
			),
			"land": int(
				summary.get(
					"land",
					0
				)
			),
			"treasury": int(
				summary.get(
					"treasury",
					0
				)
			),
			"currency_name": str(
				summary.get(
					"currency_name",
					"Treasury"
				)
			),
			"military_stockpile": int(
				summary.get(
					"military_stockpile",
					0
				)
			),
			"goods_stockpile": int(
				summary.get(
					"goods_stockpile",
					0
				)
			),
			"ruler_id": int(actor.id),
			"ruler_name": _person_name(
				actor
			),
			"ruler_title": str(
				summary.get(
					"title",
					actor.royal_title
				)
			),
			"relation_score": 100,
			"diplomatic_posture": "Domestic",
			"trade_mood": "Open"
		}
		var actor_entry: Dictionary = (
			_resident_diplomacy_compact_entry(
				actor_realm_id,
				actor_realm_projection,
				actor_realm_id,
				permissions
			)
		)

		if not actor_entry.is_empty():
			actor_entry [
				"is_player_country"
			] = true

			var actor_entry_key: String = str(
				actor_entry.get(
					"realm_key",
					"realm:%d" % actor_realm_id
				)
			)

			if not seen_realm_keys.has(
				actor_entry_key
			):
				entries.append(
					actor_entry
				)

	return entries
func _resident_crown_core_section_surfaces(
	actor: Person,
	summary: Dictionary,
	permissions: Dictionary,
	constitutional_contract: Dictionary
) -> Dictionary:
	var surfaces: Dictionary = {
		"throne": [
			{
				"row_kind": "institution_summary",
				"title": str(
					summary.get(
						"title",
						"Royal"
					)
				),
				"subtitle": str(
					summary.get(
						"realm_name",
						"Unbound Realm"
					)
				),
				"description": (
					"Legitimacy %d • Stability %d • %s"
					% [
						int(
							summary.get(
								"legitimacy",
								0
							)
						),
						int(
							summary.get(
								"stability",
								0
							)
						),
						str(
							summary.get(
								"standing",
								"Stable"
							)
						)
					]
				),
				"data": summary.duplicate(false),
				"actions": []
			}
		],
		"court": [
			{
				"row_kind": "resident_court_pointer",
				"title": "Royal Court",
				"actor_id": int(
					actor.id
				),
				"actions": []
			}
		],
		"nation": [
			{
				"row_kind": "realm",
				"title": str(
					summary.get(
						"realm_name",
						"Royal Realm"
					)
				),
				"description": (
					"Population %d • Treasury %d • Land %d"
					% [
						int(
							summary.get(
								"population",
								0
							)
						),
						int(
							summary.get(
								"treasury",
								0
							)
						),
						int(
							summary.get(
								"land",
								0
							)
						)
					]
				),
				"data": summary.duplicate(false),
				"actions": []
			}
		],
		"allocation": [
			{
				"row_kind": "allocation",
				"title": "Royal Treasury",
				"data": summary.duplicate(false),
				"actions": []
			}
		],
		"diplomacy": [
			{
				"row_kind": (
					"resident_diplomacy_projection_pointer"
				),
				"title": "Diplomatic Countries",
				"description": (
					"Era realms are publishing through the "
					+ "bounded Crown diplomacy lane."
				),
				"data": {
					"entries": [],
					"entry_count": 0,
					"actor_id": int(
						actor.id
					),
					"actor_realm_id": int(
						summary.get(
							"realm_id",
							actor.realm_id
						)
					),
					"projection_state": "streaming",
					"diplomacy_projection_complete": false,
					"ui_is_renderer_only": true
				},
				"actions": []
			}
		],
		"law": [
			{
				"row_kind": "constitutional_contract",
				"title": "Constitutional Law",
				"data": (
					constitutional_contract.duplicate(false)
				),
				"actions": []
			}
		],
		"dynasty": [
			{
				"row_kind": "resident_dynasty_pointer",
				"title": "Dynasty and Succession",
				"data": {
					"actor_id": int(
						actor.id
					),
					"succession_rank": int(
						summary.get(
							"succession_rank",
							99
						)
					),
					"claimant_pressure": float(
						summary.get(
							"claimant_pressure",
							0.0
						)
					)
				},
				"actions": []
			}
		],
		"family": [
			{
				"row_kind": "resident_family_pointer",
				"title": "Royal Family",
				"actor_id": int(
					actor.id
				),
				"actions": []
			}
		],
		"resident_contract_metadata": [
			{
				"diplomacy_country_entry_count": 0,
				"diplomacy_projection_state": "streaming",
				"diplomacy_projection_complete": false,
				"permissions": permissions.duplicate(false),
				"ui_is_renderer_only": true
			}
		]
	}

	var action_surfaces: Dictionary = (
		_resident_crown_action_surfaces(
			actor,
			summary,
			permissions,
			constitutional_contract
		)
	)

	action_surfaces [
		"expand_land"
	] = _resident_crown_expand_land_surface(
		actor,
		summary,
		permissions
	)

	surfaces [
		"_action_surfaces"
	] = action_surfaces

	return surfaces
func resolve_crown_action_contract(
		actor: Person,
		payload: Dictionary = {}
) -> Dictionary:
		if actor == null:
			return _fail(
				"missing_actor",
				"No Crown actor could be resolved."
			)

		var action_id: String = str(
			payload.get(
				"action_id",
				""
			)
		).strip_edges().to_lower()
		var result: Dictionary = (
			_resolve_crown_domain_action(
				actor,
				action_id,
				payload
			)
		)

		if bool(
			result.get(
				"success",
				false
			)
		):
			resident_crown_contract_by_actor.erase(
				str(actor.id)
			)

		var resident_contract: Dictionary = (
			emit_resident_crown_hub_contract(
				actor,
				{
					"active_section": str(
						payload.get(
							"section_id",
							"throne"
						)
					),
					"source": (
						"crown_hub_contract_engine."
						+ "resolve_crown_action_contract"
					),
					"ready_gate_member": false
				}
			)
		)

		if not resident_contract.is_empty():
			result ["crown_hub_contract"] = (
				_attach_war_projection(
					actor,
					resident_contract
				)
			)

		result ["crown_hub_contract_engine_owned"] = true
		result ["ui_is_renderer_only"] = true
		result ["blocks_ui"] = false
		result ["ready_gate_member"] = false
		last_report = result.duplicate(true)

		return result


func _crown_domain_realm(
		actor: Person
) -> Dictionary:
		if (
			actor == null
			or gs == null
			or gs.realm_engine == null
		):
			return {}

		var realm_id: int = int(actor.realm_id)
		var raw_realm: Variant = (
			gs.realm_engine.realms.get(
				realm_id,
				gs.realm_engine.realms.get(
					str(realm_id),
					{}
				)
			)
		)

		return (
			(raw_realm as Dictionary).duplicate(true)
			if typeof(raw_realm) == TYPE_DICTIONARY
			else {}
		)


func _store_crown_domain_realm(
		actor: Person,
		realm: Dictionary
) -> void:
		if (
			actor == null
			or realm.is_empty()
			or gs == null
			or gs.realm_engine == null
			or int(actor.realm_id) <= 0
		):
			return

		gs.realm_engine.realms [
			int(actor.realm_id)
		] = realm


func _crown_contract_result(
		success: bool,
		action_id: String,
		title: String,
		text: String,
		extra: Dictionary = {}
) -> Dictionary:
		var result: Dictionary = extra.duplicate(true)
		result ["success"] = success
		result ["schema"] = (
			"eralife.crown_hub."
			+ "action_result_contract"
		)
		result ["version"] = 1
		result ["type"] = "crown_action_resolved"
		result ["action_id"] = action_id
		result ["text"] = text
		result ["popup_title"] = title
		result ["popup_text"] = text
		result ["popup_footer"] = (
			"Reality has already adopted this result."
		)
		result ["ui_is_renderer_only"] = true

		return result


func _resolve_crown_domain_action(
		actor: Person,
		action_id: String,
		payload: Dictionary
) -> Dictionary:
		var realm: Dictionary = _crown_domain_realm(
			actor
		)
		var result: Dictionary = {}

		match action_id:
			"sign_bill", "veto_bill", "request_bill_revision", "delay_bill":
				result = _resolve_crown_law_action(
					actor,
					realm,
					action_id,
					payload
				)

			"crown_celebrity_action":
				result = _resolve_crown_celebrity_action(
					actor,
					realm,
					payload
				)

			"crown_public_service_action":
				result = _resolve_crown_public_service_action(
					actor,
					realm,
					payload
				)

			"crown_public_disservice_action":
				result = _resolve_crown_public_disservice_action(
					actor,
					realm,
					payload
				)

			"emergency_power":
				result = _resolve_crown_emergency_action(
					actor,
					realm,
					payload
				)

			"appoint_official":
				result = _resolve_crown_cabinet_appointment(
					actor,
					realm,
					payload
				)

			"dismiss_cabinet":
				result = _resolve_crown_cabinet_dismissal(
					actor,
					realm,
					payload
				)

			"crown_first_family_action":
				result = _resolve_crown_first_family_action(
					actor,
					realm,
					payload
				)

			"commit_allocation":
				result = _resolve_crown_allocation_commit(
					actor,
					realm,
					payload
				)

			"expand_land_contract":
				result = _resolve_crown_expand_land_action(
					actor,
					realm,
					payload
				)

			_:
				return _fail(
					"unknown_crown_action_contract",
					(
						"CrownHubContractEngine does not recognize "
						+ "that Crown action."
					)
				)

		if bool(
			result.get(
				"success",
				false
			)
		):
			_store_crown_domain_realm(
				actor,
				realm
			)

		return result
func _resolve_crown_expand_land_action(
		actor: Person,
		realm: Dictionary,
		payload: Dictionary
) -> Dictionary:
		if actor == null:
			return _crown_contract_result(
				false,
				"expand_land_contract",
				"Expansion Unavailable",
				"No realm leader could be resolved."
			)

		if realm.is_empty():
			return _crown_contract_result(
				false,
				"expand_land_contract",
				"Expansion Unavailable",
				"You do not currently control a valid realm."
			)

		var civic_contract: Dictionary = (
			_civic_office_contract_for_actor(
				actor
			)
		)
		var ruling_power_by_office: bool = bool(
			civic_contract.get(
				"ruling_power_by_office",
				false
			)
		)
		var ruler_id: int = int(
			realm.get(
				"ruler_id",
				-1
			)
		)
		var leader_authority: bool = (
			bool(actor.is_ruler)
			or ruler_id == int(actor.id)
			or ruling_power_by_office
		)

		if not leader_authority:
			return _crown_contract_result(
				false,
				"expand_land_contract",
				"Expansion Unavailable",
				(
					"Territorial expansion requires current "
					+ "realm-leader authority."
				)
			)

		var cost: int = maxi(
			0,
			int(
				payload.get(
					"cost",
					0
				)
			)
		)
		var gain: int = maxi(
			0,
			int(
				payload.get(
					"gain",
					0
				)
			)
		)
		var expansion_tier: String = str(
			payload.get(
				"expansion_tier",
				"territorial"
			)
		).strip_edges().to_lower()

		if (
			cost <= 0
			or gain <= 0
		):
			return _crown_contract_result(
				false,
				"expand_land_contract",
				"Expansion Invalid",
				"That territorial expansion contract is invalid."
			)

		if int(actor.bank_balance) < cost:
			return _crown_contract_result(
				false,
				"expand_land_contract",
				"Expansion Unfunded",
				(
					"You do not have enough available wealth "
					+ "for that expansion."
				)
			)

		var land_before: int = int(
			realm.get(
				"land",
				realm.get(
					"land_size",
					0
				)
			)
		)
		var population_before: int = int(
			realm.get(
				"population",
				0
			)
		)
		var wealth_before: int = int(
			actor.bank_balance
		)
		var population_gain: int = int(
			round(
				float(gain) * 1200.0
			)
		)

		actor.bank_balance = (
			wealth_before - cost
		)
		realm ["land"] = (
			land_before + gain
		)
		realm ["population"] = (
			population_before
			+ population_gain
		)
		realm [
			"last_territorial_expansion_contract"
		] = {
			"actor_id": int(actor.id),
			"expansion_tier": expansion_tier,
			"land_gain": gain,
			"population_gain": population_gain,
			"cost": cost,
			"year": (
				int(gs.year)
				if gs != null
				else 0
			),
			"authority": (
				"CrownHubContractEngine"
			)
		}

		if gs != null:
			gs.push_world_feed(
				(
					"%s %s authorized a %s territorial "
					+ "expansion for %s."
				) % [
					str(actor.first_name),
					str(actor.last_name),
					expansion_tier,
					str(
						realm.get(
							"name",
							"the realm"
						)
					)
				],
				{
					"npc_id": int(actor.id),
					"personally_relevant": true,
					"category": "realm",
					"event_name": "crown_expand_land",
					"source": (
						"crown_hub_contract_engine"
					)
				}
			)

		return _crown_contract_result(
			true,
			"expand_land_contract",
			"Territory Expanded",
			(
				"%s gained %d land and %d population."
			) % [
				str(
					realm.get(
						"name",
						"Your realm"
					)
				),
				gain,
				population_gain
			],
			{
				"expansion_tier": expansion_tier,
				"land_before": land_before,
				"land_after": int(
					realm.get(
						"land",
						land_before
					)
				),
				"land_delta": gain,
				"population_before": population_before,
				"population_after": int(
					realm.get(
						"population",
						population_before
					)
				),
				"population_delta": population_gain,
				"wealth_before": wealth_before,
				"wealth_after": int(
					actor.bank_balance
				),
				"wealth_delta": - cost,
			}
		)
func _resolve_crown_law_action(
		actor: Person,
		realm: Dictionary,
		action_id: String,
		payload: Dictionary
) -> Dictionary:
		var proposal: Dictionary = _dict(
			payload.get(
				"proposal",
				payload
			)
		)

		if proposal.is_empty():
			return _crown_contract_result(
				false,
				action_id,
				"Law Review Failed",
				"No immutable law proposal was supplied."
			)

		var delta_key: String = "approval_on_delay"

		match action_id:
			"sign_bill":
				delta_key = "approval_on_sign"
			"veto_bill":
				delta_key = "approval_on_veto"
			"request_bill_revision":
				delta_key = "approval_on_revise"
			"delay_bill":
				delta_key = "approval_on_delay"

		var approval_delta: int = int(
			proposal.get(
				delta_key,
				0
			)
		)
		actor.approval = clamp(
			int(actor.approval) + approval_delta,
			0,
			100
		)

		if not realm.is_empty():
			realm ["approval"] = clamp(
				int(
					realm.get(
						"approval",
						actor.approval
					)
				) + approval_delta,
				0,
				100
			)

		var federal_republic: bool = bool(
			proposal.get(
				"federal_republic",
				false
			)
		)
		var vote_split: Dictionary = _dict(
			proposal.get(
				"vote_split",
				{}
			)
		)
		var veto_overridden: bool = false
		var enacted: bool = (
			action_id == "sign_bill"
		)

		if (
			action_id == "veto_bill"
			and federal_republic
		):
			veto_overridden = (
				int(
					vote_split.get(
						"house_for",
						0
					)
				) >= int(
					vote_split.get(
						"house_override_threshold",
						290
					)
				)
				and int(
					vote_split.get(
						"senate_for",
						0
					)
				) >= int(
					vote_split.get(
						"senate_override_threshold",
						67
					)
				)
			)
			enacted = veto_overridden

		var history: Array = _array(
			realm.get(
				"law_history",
				[]
			)
		)
		history.append({
			"proposal_id": str(
				proposal.get(
					"proposal_id",
					""
				)
			),
			"title": str(
				proposal.get(
					"title",
					"Proposed Law"
				)
			),
			"action_id": action_id,
			"actor_id": int(actor.id),
			"year": (
				int(gs.year)
				if gs != null
				else 0
			),
			"enacted": enacted,
			"veto_overridden": veto_overridden,
			"approval_delta": approval_delta,
			"constitutional_authority": (
				"checks_and_balances_contract_engine"
				if federal_republic
				else "royalty_contract_engine"
			)
		})
		realm ["law_history"] = history
		realm ["last_law_action_id"] = action_id
		realm ["last_law_title"] = str(
			proposal.get(
				"title",
				"Proposed Law"
			)
		)
		realm ["last_law_enacted"] = enacted
		realm ["last_law_veto_overridden"] = (
			veto_overridden
		)

		_advance_crown_action_cycle(
			int(actor.id)
		)

		var text: String = ""

		match action_id:
			"sign_bill":
				text = (
					"You signed '%s' into law. Approval %s%d."
					% [
						str(proposal.get("title", "the bill")),
						"+" if approval_delta >= 0 else "",
						approval_delta
					]
				)

			"veto_bill":
				if veto_overridden:
					text = (
						(
							"You vetoed '%s', but both chambers reached "
							+ "their two-thirds thresholds and overrode you. "
							+ "The bill became law. Approval %s%d."
						)
						% [
							str(proposal.get("title", "the bill")),
							"+" if approval_delta >= 0 else "",
							approval_delta
						]
					)
				else:
					text = (
						"You vetoed '%s'. The veto stands. Approval %s%d."
						% [
							str(proposal.get("title", "the proposal")),
							"+" if approval_delta >= 0 else "",
							approval_delta
						]
					)

			"request_bill_revision":
				text = (
					"You returned '%s' for revisions. Approval %s%d."
					% [
						str(proposal.get("title", "the proposal")),
						"+" if approval_delta >= 0 else "",
						approval_delta
					]
				)

			"delay_bill":
				text = (
					"You delayed action on '%s'. Approval %s%d."
					% [
						str(proposal.get("title", "the proposal")),
						"+" if approval_delta >= 0 else "",
						approval_delta
					]
				)

		return _crown_contract_result(
			true,
			action_id,
			"Law Review",
			text,
			{
				"proposal": proposal.duplicate(true),
				"approval_delta": approval_delta,
				"enacted": enacted,
				"veto_overridden": veto_overridden,
				"vote_split": vote_split.duplicate(true)
			}
		)
func _resolve_crown_celebrity_action(
		actor: Person,
		realm: Dictionary,
		payload: Dictionary
) -> Dictionary:
		var kind: String = str(
			payload.get(
				"kind",
				"gala"
			)
		).strip_edges().to_lower()
		var fame_delta: int = int(
			payload.get(
				"fame_delta",
				6
			)
		)
		var approval_delta: int = int(
			payload.get(
				"approval_delta",
				3
			)
		)
		var scandal_risk: int = clamp(
			int(
				payload.get(
					"scandal_risk",
					8
				)
			),
			0,
			100
		)
		var roll: int = abs(
			int(
				hash(
					"%d|%d|celebrity|%s|%d"
					% [
						int(actor.id),
						int(gs.year) if gs != null else 0,
						kind,
						_crown_action_cycle(int(actor.id))
					]
				)
			)
		) % 100
		var scandal_triggered: bool = (
			roll < scandal_risk
		)

		actor.fame = clamp(
			int(actor.fame) + fame_delta,
			0,
			100
		)
		actor.approval = clamp(
			int(actor.approval) + approval_delta,
			0,
			100
		)

		if scandal_triggered:
			actor.scandal = clamp(
				int(actor.scandal) + 6,
				0,
				100
			)
			actor.approval = clamp(
				int(actor.approval) - 4,
				0,
				100
			)

		if not realm.is_empty():
			realm ["approval"] = clamp(
				int(realm.get("approval", 50))
				+ approval_delta
				- (4 if scandal_triggered else 0),
				0,
				100
			)

		_advance_crown_action_cycle(
			int(actor.id)
		)

		var text: String = (
			"You completed a %s prestige event. Fame +%d and approval %s%d."
			% [
				kind.replace("_", " "),
				fame_delta,
				"+" if approval_delta >= 0 else "",
				approval_delta
			]
		)

		if scandal_triggered:
			text += (
				" The spectacle also produced a public scandal."
			)

		return _crown_contract_result(
			true,
			"crown_celebrity_action",
			"Prestige Event",
			text,
			{
				"fame_delta": fame_delta,
				"approval_delta": approval_delta,
				"scandal_triggered": scandal_triggered
			}
		)


func _resolve_crown_public_service_action(
		actor: Person,
		realm: Dictionary,
		payload: Dictionary
) -> Dictionary:
		var kind: String = str(
			payload.get(
				"kind",
				"public_service"
			)
		).strip_edges().to_lower()
		var approval_delta: int = 0
		var happiness_delta: int = 0
		var fame_delta: int = 0
		var text: String = ""

		match kind:
			"donate":
				var amount: int = max(
					0,
					int(
						payload.get(
							"amount",
							0
						)
					)
				)

				if amount <= 0:
					return _crown_contract_result(
						false,
						"crown_public_service_action",
						"Donation Failed",
						"No donation amount was supplied."
					)

				if int(actor.bank_balance) < amount:
					return _crown_contract_result(
						false,
						"crown_public_service_action",
						"Donation Failed",
						"You do not have enough personal wealth."
					)

				actor.bank_balance = (
					int(actor.bank_balance) - amount
				)
				approval_delta = clamp(
					2 + int(
						round(
							sqrt(
								float(amount) / 10000.0
							)
						)
					),
					2,
					18
				)
				happiness_delta = clamp(
					int(
						round(
							float(approval_delta) * 0.7
						)
					),
					1,
					13
				)
				fame_delta = clamp(
					int(
						round(
							float(approval_delta) * 0.35
						)
					),
					1,
					7
				)
				text = (
					"You donated %d of your personal wealth to public causes."
					% amount
				)

			"speech":
				var speech_type: String = str(
					payload.get(
						"speech_type",
						"unity"
					)
				).strip_edges().to_lower()

				match speech_type:
					"reform":
						approval_delta = 7
						happiness_delta = 5
						fame_delta = 4
					"economic":
						approval_delta = 5
						happiness_delta = 3
						fame_delta = 4
					"defense":
						approval_delta = 3
						happiness_delta = 1
						fame_delta = 5
					_:
						approval_delta = 6
						happiness_delta = 5
						fame_delta = 4

				text = (
					"You delivered a %s speech across the realm."
					% speech_type
				)

			"realm_tour":
				approval_delta = 9
				happiness_delta = 7
				fame_delta = 5
				text = (
					"You toured the capital, cities, states, and regional communities."
				)

			"hospital_visit":
				approval_delta = 7
				happiness_delta = 6
				fame_delta = 3
				text = (
					"You visited hospitals and public care centers."
				)

			"relief_tour":
				approval_delta = 11
				happiness_delta = 9
				fame_delta = 4
				text = (
					"You led a public disaster-relief tour."
				)

			_:
				approval_delta = 4
				happiness_delta = 3
				fame_delta = 2
				text = (
					"You completed a public-service duty."
				)

		actor.approval = clamp(
			int(actor.approval) + approval_delta,
			0,
			100
		)
		actor.fame = clamp(
			int(actor.fame) + fame_delta,
			0,
			100
		)

		if not realm.is_empty():
			realm ["approval"] = clamp(
				int(realm.get("approval", 50))
				+ approval_delta,
				0,
				100
			)
			realm ["happiness"] = clamp(
				int(realm.get("happiness", 50))
				+ happiness_delta,
				0,
				100
			)

		text += (
			" Approval +%d, citizen happiness +%d, and fame +%d."
			% [
				approval_delta,
				happiness_delta,
				fame_delta
			]
		)

		return _crown_contract_result(
			true,
			"crown_public_service_action",
			"Public Service",
			text,
			{
				"approval_delta": approval_delta,
				"happiness_delta": happiness_delta,
				"fame_delta": fame_delta
			}
		)


func _resolve_crown_public_disservice_action(
		actor: Person,
		realm: Dictionary,
		payload: Dictionary
) -> Dictionary:
		var kind: String = str(
			payload.get(
				"kind",
				"public_disservice"
			)
		).strip_edges().to_lower()
		var text: String = ""

		if kind == "steal_treasury":
			var requested_amount: int = max(
				0,
				int(payload.get("amount", 0))
			)
			var treasury: int = int(
				realm.get(
					"treasury",
					0
				)
			)
			var amount: int = min(
				requested_amount,
				max(0, treasury)
			)

			if amount <= 0:
				return _crown_contract_result(
					false,
					"crown_public_disservice_action",
					"Treasury Theft Failed",
					"The treasury has no available money to steal."
				)

			var detection_risk: int = clamp(
				int(
					payload.get(
						"detection_risk",
						35
					)
				),
				0,
				100
			)
			var roll: int = abs(
				int(
					hash(
						"%d|%d|treasury_theft|%d|%d"
						% [
							int(actor.id),
							int(gs.year) if gs != null else 0,
							amount,
							_crown_action_cycle(int(actor.id))
						]
					)
				)
			) % 100
			var caught: bool = roll < detection_risk

			if caught:
				actor.scandal = clamp(
					int(actor.scandal) + 24,
					0,
					100
				)
				actor.approval = clamp(
					int(actor.approval) - 20,
					0,
					100
				)
				realm ["approval"] = clamp(
					int(realm.get("approval", 50)) - 20,
					0,
					100
				)
				realm ["happiness"] = clamp(
					int(realm.get("happiness", 50)) - 10,
					0,
					100
				)
				text = (
					"You attempted to steal %d from the treasury and were caught."
					% amount
				)
			else:
				realm ["treasury"] = treasury - amount
				actor.bank_balance = (
					int(actor.bank_balance) + amount
				)
				actor.approval = clamp(
					int(actor.approval) - 6,
					0,
					100
				)
				realm ["approval"] = clamp(
					int(realm.get("approval", 50)) - 6,
					0,
					100
				)
				text = (
					"You secretly stole %d from the realm treasury."
					% amount
				)

			_advance_crown_action_cycle(
				int(actor.id)
			)

			return _crown_contract_result(
				true,
				"crown_public_disservice_action",
				"Treasury Theft",
				text,
				{
					"amount": amount,
					"caught": caught,
					"detection_risk": detection_risk
				}
			)

		var approval_delta: int = (
			-14
			if kind == "corrupt_crackdown"
			else -10
		)
		var happiness_delta: int = (
			-12
			if kind == "corrupt_crackdown"
			else -7
		)
		var scandal_delta: int = (
			16
			if kind == "vanity_project"
			else 12
		)

		actor.approval = clamp(
			int(actor.approval) + approval_delta,
			0,
			100
		)
		actor.scandal = clamp(
			int(actor.scandal) + scandal_delta,
			0,
			100
		)
		realm ["approval"] = clamp(
			int(realm.get("approval", 50))
			+ approval_delta,
			0,
			100
		)
		realm ["happiness"] = clamp(
			int(realm.get("happiness", 50))
			+ happiness_delta,
			0,
			100
		)

		text = (
			"You committed %s. Approval %d, happiness %d, and scandal +%d."
			% [
				kind.replace("_", " "),
				approval_delta,
				happiness_delta,
				scandal_delta
			]
		)

		return _crown_contract_result(
			true,
			"crown_public_disservice_action",
			"Public Disservice",
			text
		)


func _resolve_crown_emergency_action(
		actor: Person,
		realm: Dictionary,
		payload: Dictionary
) -> Dictionary:
		var kind: String = str(
			payload.get(
				"kind",
				"emergency_authority"
			)
		).strip_edges().to_lower()
		var approval_delta: int = int(
			payload.get(
				"approval_delta",
				-8
			)
		)
		var happiness_delta: int = int(
			payload.get(
				"happiness_delta",
				-6
			)
		)
		var respect_delta: int = int(
			payload.get(
				"respect_delta",
				-2
			)
		)
		var stability_delta: int = int(
			payload.get(
				"stability_delta",
				5
			)
		)
		var base_revolt_risk: int = int(
			payload.get(
				"base_revolt_risk",
				10
			)
		)

		actor.approval = clamp(
			int(actor.approval) + approval_delta,
			0,
			100
		)
		realm ["approval"] = clamp(
			int(realm.get("approval", 50))
			+ approval_delta,
			0,
			100
		)
		realm ["happiness"] = clamp(
			int(realm.get("happiness", 50))
			+ happiness_delta,
			0,
			100
		)
		realm ["respect_bias"] = clamp(
			int(realm.get("respect_bias", 0))
			+ respect_delta,
			-100,
			100
		)
		realm ["stability"] = clamp(
			int(realm.get("stability", 50))
			+ stability_delta,
			0,
			100
		)
		realm ["emergency_power_active"] = true
		realm ["emergency_power_kind"] = kind
		realm ["emergency_power_started_year"] = (
			int(gs.year)
			if gs != null
			else 0
		)

		var revolt_risk: int = clamp(
			base_revolt_risk
			+ max(
				0,
				50 - int(actor.approval)
			)
			+ max(
				0,
				35 - int(
					realm.get(
						"happiness",
						50
					)
				)
			),
			0,
			95
		)
		var revolt_roll: int = abs(
			int(
				hash(
					"%d|%d|%s|revolt|%d"
					% [
						int(actor.id),
						int(gs.year) if gs != null else 0,
						kind,
						_crown_action_cycle(int(actor.id))
					]
				)
			)
		) % 100
		var revolt_triggered: bool = (
			revolt_roll < revolt_risk
		)
		var revolt_outcome: String = ""
		var text: String = (
			"You invoked %s. Approval %d, happiness %d, respect %d, and stability %+d."
			% [
				kind.replace("_", " "),
				approval_delta,
				happiness_delta,
				respect_delta,
				stability_delta
			]
		)

		if revolt_triggered:
			var outcome_index: int = abs(
				int(
					hash(
						"%d|%d|%s|outcome"
						% [
							int(actor.id),
							int(gs.year) if gs != null else 0,
							kind
						]
					)
				)
			) % 3

			match outcome_index:
				0:
					revolt_outcome = "exile"
					actor.exiled = true
					actor.deposed = true
					actor.is_ruler = false
					text += (
						" The realm revolted, removed you, and exiled you."
					)

				1:
					revolt_outcome = "imprisonment"

					if (
						gs != null
						and gs.prison_engine != null
						and gs.prison_engine.has_method(
							"execute_sentence"
						)
					):
						gs.prison_engine.execute_sentence(
							{
								"case_id": (
									"martial_law_revolt_%d_%d"
									% [
										int(actor.id),
										int(gs.year)
									]
								),
								"participants": {
									"accused": int(actor.id)
								}
							},
							{
								"type": "prison",
								"duration": 12
							}
						)

					actor.deposed = true
					actor.is_ruler = false
					text += (
						" The realm revolted, removed you, and imprisoned you."
					)

				_:
					revolt_outcome = "death"

					if (
						gs != null
						and gs.health_engine != null
						and gs.health_engine.has_method(
							"try_kill"
						)
					):
						gs.health_engine.try_kill(
							actor,
							(
								"Killed during a revolt "
								+ "against emergency rule"
							)
						)

					text += (
						" The realm revolted and killed you."
					)

		_advance_crown_action_cycle(
			int(actor.id)
		)

		return _crown_contract_result(
			true,
			"emergency_power",
			"Emergency Powers",
			text,
			{
				"kind": kind,
				"revolt_risk": revolt_risk,
				"revolt_triggered": revolt_triggered,
				"revolt_outcome": revolt_outcome
			}
		)


func _best_cabinet_candidate(
		actor: Person,
		realm: Dictionary
) -> Person:
		if (
			actor == null
			or gs == null
		):
			return null

		var existing_ids: Array = _array(
			realm.get(
				"cabinet_member_ids",
				[]
			)
		)
		var best: Person = null
		var best_score: float = - INF

		for raw_person in gs.npcs:
			if not raw_person is Person:
				continue

			var candidate: Person = raw_person as Person

			if (
				not candidate.alive
				or int(candidate.age) < 18
				or int(candidate.id) == int(actor.id)
				or int(candidate.realm_id) != int(actor.realm_id)
				or int(candidate.id) in existing_ids
			):
				continue

			var score: float = (
				float(candidate.smarts) * 1.4
				+ float(candidate.approval)
				+ float(candidate.willpower) * 0.5
				- float(candidate.scandal) * 0.8
			)

			if score > best_score:
				best = candidate
				best_score = score

		return best


func _resolve_crown_cabinet_appointment(
		actor: Person,
		realm: Dictionary,
		payload: Dictionary
) -> Dictionary:
		var office_title: String = str(
			payload.get(
				"office_title",
				"Cabinet Official"
			)
		).strip_edges()
		var candidate: Person = _best_cabinet_candidate(
			actor,
			realm
		)

		if candidate == null:
			return _crown_contract_result(
				false,
				"appoint_official",
				"Cabinet Appointment",
				"No eligible cabinet candidate is currently resident."
			)

		var member_ids: Array = _array(
			realm.get(
				"cabinet_member_ids",
				[]
			)
		)

		if int(candidate.id) not in member_ids:
			member_ids.append(
				int(candidate.id)
			)

		var offices: Dictionary = _dict(
			realm.get(
				"cabinet_offices_by_person",
				{}
			)
		)
		offices [str(candidate.id)] = office_title

		realm ["cabinet_member_ids"] = member_ids
		realm ["cabinet_offices_by_person"] = offices
		candidate.civic_title = office_title
		candidate.job = office_title

		return _crown_contract_result(
			true,
			"appoint_official",
			"Cabinet Appointment",
			(
				"You appointed %s as %s. The appointment remains subject "
				+ "to every constitutional review attached to this action."
			)
			% [
				_person_name(candidate),
				office_title
			],
			{
				"target_id": int(candidate.id),
				"office_title": office_title
			}
		)


func _resolve_crown_cabinet_dismissal(
		_actor: Person,
		realm: Dictionary,
		payload: Dictionary
) -> Dictionary:
		var member_ids: Array = _array(
			realm.get(
				"cabinet_member_ids",
				[]
			)
		)

		if member_ids.is_empty():
			return _crown_contract_result(
				false,
				"dismiss_cabinet",
				"Cabinet Dismissal",
				"There are no cabinet officials to dismiss."
			)

		var target_id: int = int(
			payload.get(
				"target_id",
				member_ids [0]
			)
		)

		if target_id not in member_ids:
			target_id = int(member_ids [0])

		member_ids.erase(target_id)

		var offices: Dictionary = _dict(
			realm.get(
				"cabinet_offices_by_person",
				{}
			)
		)
		var former_office: String = str(
			offices.get(
				str(target_id),
				"Cabinet Official"
			)
		)
		offices.erase(str(target_id))

		realm ["cabinet_member_ids"] = member_ids
		realm ["cabinet_offices_by_person"] = offices

		var target: Person = (
			gs.get_npc_by_id(target_id)
			if gs != null
			else null
		)
		var target_name: String = (
			_person_name(target)
			if target != null
			else "The cabinet official"
		)

		if target != null:
			target.civic_title = ""

		return _crown_contract_result(
			true,
			"dismiss_cabinet",
			"Cabinet Dismissal",
			(
				"You dismissed %s from the office of %s."
				% [
					target_name,
					former_office
				]
			),
			{
				"target_id": target_id,
				"former_office": former_office
			}
		)

func _crown_contract_tax_delta(
		tax_rate: float,
		channel: String
) -> int:
		var clean_tax: float = clamp(
			tax_rate,
			0.0,
			40.0
		)

		if clean_tax <= 13.0:
			var relief: float = clamp(
				(13.0 - clean_tax) / 13.0,
				0.0,
				1.0
			)

			match channel:
				"happiness":
					return int(
						round(
							pow(relief, 0.88) * 24.0
						)
					)
				"approval":
					return int(
						round(
							pow(relief, 0.92) * 18.0
						)
					)
				"respect":
					return int(
						round(
							pow(relief, 0.96) * 12.0
						)
					)
				_:
					return 0

		var over_tax: float = clean_tax - 13.0

		match channel:
			"happiness":
				return clamp(
					-2 - int(
						round(
							pow(over_tax, 1.35) * 1.35
						)
					),
					-60,
					0
				)
			"approval":
				return clamp(
					-2 - int(
						round(
							pow(over_tax, 1.3) * 1.1
						)
					),
					-50,
					0
				)
			"respect":
				return clamp(
					-1 - int(
						round(
							pow(over_tax, 1.25) * 0.95
						)
					),
					-40,
					0
				)
			_:
				return 0


func _resolve_crown_allocation_commit(
		actor: Person,
		realm: Dictionary,
		payload: Dictionary
) -> Dictionary:
		if realm.is_empty():
			return _crown_contract_result(
				false,
				"commit_allocation",
				"Allocation Failed",
				"No canonical realm could be resolved."
			)

		if not bool(actor.is_ruler):
			return _crown_contract_result(
				false,
				"commit_allocation",
				"Allocation Failed",
				"Only the current realm leader may set allocation."
			)

		if int(
			realm.get(
				"allocation_last_set_year",
				-1
			)
		) == int(gs.year):
			return _crown_contract_result(
				false,
				"commit_allocation",
				"Allocation Locked",
				"Allocation has already been committed for this year."
			)

		var draft: Dictionary = _dict(
			payload.get(
				"draft",
				{}
			)
		)
		var tax_rate: float = clamp(
			float(draft.get("tax_rate", 10.0)),
			0.0,
			40.0
		)
		var treasury_pct: int = clamp(
			int(draft.get("treasury_pct", 34)),
			0,
			100
		)
		var military_pct: int = clamp(
			int(draft.get("military_pct", 33)),
			0,
			100
		)
		var goods_pct: int = clamp(
			int(draft.get("goods_pct", 33)),
			0,
			100
		)
		var total_pct: int = (
			treasury_pct
			+ military_pct
			+ goods_pct
		)

		if total_pct <= 0:
			treasury_pct = 34
			military_pct = 33
			goods_pct = 33
		elif total_pct != 100:
			var scale: float = 100.0 / float(total_pct)
			treasury_pct = int(
				round(float(treasury_pct) * scale)
			)
			military_pct = int(
				round(float(military_pct) * scale)
			)
			goods_pct = (
				100
				- treasury_pct
				- military_pct
			)

		var population: int = int(
			realm.get(
				"population",
				0
			)
		)
		var tax_revenue: int = 0

		if (
			gs.realm_engine != null
			and gs.realm_engine.has_method(
				"_calculate_realm_tax_revenue"
			)
		):
			tax_revenue = int(
				gs.realm_engine.call(
					"_calculate_realm_tax_revenue",
					population,
					tax_rate,
					realm
				)
			)

		var saved_reserve: int = int(
			realm.get(
				"allocation_reserve",
				0
			)
		)
		var available_pool: int = max(
			0,
			tax_revenue + saved_reserve
		)
		var treasury_amount: int = int(
			floor(
				float(available_pool)
				* float(treasury_pct)
				/ 100.0
			)
		)
		var military_budget: int = int(
			floor(
				float(available_pool)
				* float(military_pct)
				/ 100.0
			)
		)
		var goods_budget: int = int(
			floor(
				float(available_pool)
				* float(goods_pct)
				/ 100.0
			)
		)
		var military_unit_cost: int = max(
			1,
			int(
				realm.get(
					"military_unit_cost",
					4500
				)
			)
		)
		var goods_unit_cost: int = max(
			1,
			int(
				realm.get(
					"goods_unit_cost",
					200000
				)
			)
		)
		var military_units: int = int(
			floor(
				float(military_budget)
				/ float(military_unit_cost)
			)
		)
		var goods_units: int = int(
			floor(
				float(goods_budget)
				/ float(goods_unit_cost)
			)
		)
		var military_spent: int = (
			military_units * military_unit_cost
		)
		var goods_spent: int = (
			goods_units * goods_unit_cost
		)
		var carryover: int = max(
			0,
			available_pool
			- treasury_amount
			- military_spent
			- goods_spent
		)
		var happiness_delta: int = (
			_crown_contract_tax_delta(
				tax_rate,
				"happiness"
			)
		)
		var approval_delta: int = (
			_crown_contract_tax_delta(
				tax_rate,
				"approval"
			)
		)
		var respect_delta: int = (
			_crown_contract_tax_delta(
				tax_rate,
				"respect"
			)
		)

		realm ["tax_rate"] = tax_rate
		realm ["allocation_treasury_pct"] = treasury_pct
		realm ["allocation_military_pct"] = military_pct
		realm ["allocation_goods_pct"] = goods_pct
		realm ["allocation_reserve"] = carryover
		realm ["treasury"] = (
			int(realm.get("treasury", 0))
			+ treasury_amount
		)
		realm ["military_stockpile"] = (
			int(realm.get("military_stockpile", 0))
			+ military_units
		)
		realm ["goods_stockpile"] = (
			int(realm.get("goods_stockpile", 0))
			+ goods_units
		)
		realm ["allocation_last_set_year"] = int(gs.year)
		realm ["pending_tax_effect_year"] = int(gs.year) + 1
		realm ["pending_tax_happiness_delta"] = happiness_delta
		realm ["pending_tax_approval_delta"] = approval_delta
		realm ["pending_tax_respect_delta"] = respect_delta

		return _crown_contract_result(
			true,
			"commit_allocation",
			"Allocation Set",
			(
				"Taxes were set at %d%%. Treasury receives %d, "
				+ "military gains %d units, goods gain %d units, "
				+ "and %d carries forward. Next-year mood: "
				+ "happiness %+d, approval %+d, respect %+d."
			)
			% [
				int(round(tax_rate)),
				treasury_amount,
				military_units,
				goods_units,
				carryover,
				happiness_delta,
				approval_delta,
				respect_delta
			],
			{
				"tax_rate": tax_rate,
				"treasury_amount": treasury_amount,
				"military_units": military_units,
				"goods_units": goods_units,
				"carryover": carryover,
				"happiness_delta": happiness_delta,
				"approval_delta": approval_delta,
				"respect_delta": respect_delta
			}
		)
func _resolve_crown_first_family_action(
		actor: Person,
		realm: Dictionary,
		payload: Dictionary
) -> Dictionary:
		var kind: String = str(
			payload.get(
				"kind",
				"public_appearance"
			)
		).strip_edges().to_lower()
		var approval_delta: int = 0
		var happiness_delta: int = 0
		var fame_delta: int = 0

		match kind:
			"state_dinner":
				approval_delta = 3
				happiness_delta = 1
				fame_delta = 5
			"charity_initiative":
				approval_delta = 8
				happiness_delta = 6
				fame_delta = 4
			"privacy_and_protection":
				approval_delta = 1
				happiness_delta = 2
				fame_delta = -1
			_:
				approval_delta = 5
				happiness_delta = 3
				fame_delta = 4

		actor.approval = clamp(
			int(actor.approval) + approval_delta,
			0,
			100
		)
		actor.fame = clamp(
			int(actor.fame) + fame_delta,
			0,
			100
		)
		realm ["approval"] = clamp(
			int(realm.get("approval", 50))
			+ approval_delta,
			0,
			100
		)
		realm ["happiness"] = clamp(
			int(realm.get("happiness", 50))
			+ happiness_delta,
			0,
			100
		)

		return _crown_contract_result(
			true,
			"crown_first_family_action",
			"First Family",
			(
				"The First Family completed a %s action. "
				+ "Approval %+d, happiness %+d, and fame %+d."
			)
			% [
				kind.replace("_", " "),
				approval_delta,
				happiness_delta,
				fame_delta
			]
		)
func _resident_diplomacy_era_kingdom_surface() -> Dictionary:
	if (
		gs == null
		or gs.many_realms_engine == null
		or not gs.many_realms_engine.has_method(
			"emit_world_browser_hidden_surface_registry"
		)
	):
		return {}

	var registry_raw: Variant = (
		gs.many_realms_engine
		.emit_world_browser_hidden_surface_registry(
			{
				"source": (
					"crown_hub_contract_engine."
					+ "resident_diplomacy_projection"
				),
				"include_era_kingdom_preview": true,
				"ui_is_renderer_only": true
			}
		)
	)

	if typeof(registry_raw) != TYPE_DICTIONARY:
		return {}

	var registry: Dictionary = (
		registry_raw as Dictionary
	)
	var era_kingdom_raw: Variant = registry.get(
		"era_kingdom",
		{}
	)

	if typeof(
		era_kingdom_raw
	) != TYPE_DICTIONARY:
		return {}

	var era_kingdom: Dictionary = (
		era_kingdom_raw as Dictionary
	).duplicate(false)

	era_kingdom [
		"id"
	] = "era_kingdom"
	era_kingdom [
		"entry_id"
	] = "era_kingdom"
	era_kingdom [
		"hidden_realm_id"
	] = "era_kingdom"
	era_kingdom [
		"realm_key"
	] = "era_kingdom"
	era_kingdom [
		"name"
	] = str(
		era_kingdom.get(
			"name",
			"Era Kingdom"
		)
	)

	return era_kingdom
func service_resident_diplomacy_projection_quantum(
		actor: Person,
		context: Dictionary = {}
) -> Dictionary:
		if (
			actor == null
			or gs == null
			or gs.realm_engine == null
		):
			return {
				"success": false,
				"reason": "missing_diplomacy_projection_authority",
				"complete": false
			}

		var actor_id: int = int(
			actor.id
		)
		var job_key: String = str(
			actor_id
		)
		var job_raw: Variant = (
			resident_diplomacy_projection_jobs.get(
				job_key,
				{}
			)
		)
		var job: Dictionary = (
			job_raw as Dictionary
			if typeof(job_raw) == TYPE_DICTIONARY
			else {}
		)

		if job.is_empty():
			var realms_raw: Variant = (
				gs.realm_engine.get(
					"realms"
				)
			)
			var realms: Dictionary = (
				realms_raw as Dictionary
				if typeof(realms_raw) == TYPE_DICTIONARY
				else {}
			)
			var queued_realm_keys: Array = []

			for raw_realm_id in realms.keys():
				var realm_id: int = int(
					raw_realm_id
				)

				if (
					realm_id > 0
					and not queued_realm_keys.has(
						realm_id
					)
				):
					queued_realm_keys.append(
						realm_id
					)

			queued_realm_keys.sort()
			queued_realm_keys.append(
				"__era_kingdom__"
			)

			var seed_contract_raw: Variant = context.get(
				"base_contract",
				{}
			)
			var seed_contract: Dictionary = (
				seed_contract_raw as Dictionary
				if typeof(seed_contract_raw) == TYPE_DICTIONARY
				else {}
			)

			var population_rank_contract: Dictionary = (
				_resident_diplomacy_population_rank_contract()
			)

			job = {
				"actor_id": actor_id,
				"actor_realm_id": int(
					context.get(
						"actor_realm_id",
						actor.realm_id
					)
				),
				"realm_keys": queued_realm_keys,
				"cursor": 0,
				"entries": [],
				"seen_realm_keys": {},
				"permissions": (
					context.get(
						"permissions",
						{}
					) as Dictionary
					if typeof(
						context.get(
							"permissions",
							{}
						)
					) == TYPE_DICTIONARY
					else {}
				),
				"base_contract": (
					seed_contract.duplicate(false)
				),
				"population_rank_contract": (
					population_rank_contract
				),
				"population_rank_revision": str(
					population_rank_contract.get(
						"revision",
						""
					)
				),
				"started_at_ms": int(
					Time.get_ticks_msec()
				),
			}

		var realm_keys: Array = (
			job.get(
				"realm_keys",
				[]
			) as Array
		)
		var cursor: int = int(
			job.get(
				"cursor",
				0
			)
		)
		var entries: Array = (
			job.get(
				"entries",
				[]
			) as Array
		)
		var seen_realm_keys: Dictionary = (
			job.get(
				"seen_realm_keys",
				{}
			) as Dictionary
		)
		var permissions: Dictionary = (
			job.get(
				"permissions",
				{}
			) as Dictionary
		)
		var actor_realm_id: int = int(
			job.get(
				"actor_realm_id",
				actor.realm_id
			)
		)
		var published_entry: Dictionary = {}
		var published_war_preview_hot: bool = false

		if cursor < realm_keys.size():
			var raw_projection_key: Variant = (
				realm_keys [
					cursor
				]
			)
			var realm: Dictionary = {}
			var realm_id: int = -1

			if str(
				raw_projection_key
			) == "__era_kingdom__":
				realm = (
					_resident_diplomacy_era_kingdom_surface()
				)
				realm_id = int(
					realm.get(
						"realm_id",
						-1
					)
				)
			else:
				realm_id = int(
					raw_projection_key
				)

				var realms_raw: Variant = (
					gs.realm_engine.get(
						"realms"
					)
				)

				if typeof(realms_raw) == TYPE_DICTIONARY:
					var realms: Dictionary = (
						realms_raw as Dictionary
					)
					var realm_raw: Variant = realms.get(
						realm_id,
						realms.get(
							str(
								realm_id
							),
							{}
						)
					)

					if typeof(realm_raw) == TYPE_DICTIONARY:
						realm = (
							realm_raw as Dictionary
						)

			if not realm.is_empty():
				var is_era_kingdom: bool = (
					_resident_diplomacy_entry_is_era_kingdom(
						realm
					)
				)
				var relation_contract: Dictionary = {}
				var war_preview: Dictionary = {}

				if (
					gs.war_contract_engine != null
					and realm_id > 0
					and realm_id != actor_realm_id
					and not is_era_kingdom
				):
					relation_contract = (
						gs.war_contract_engine
						.emit_realm_relation_contract(
							actor_realm_id,
							realm_id
						)
					)
					war_preview = (
						gs.war_contract_engine
						.emit_war_preview_contract(
							{
								"attacker_realm_id": (
									actor_realm_id
								),
								"defender_realm_id": (
									realm_id
								),
								"defender_name": str(
									realm.get(
										"name",
										""
									)
								),
								"year": int(
									gs.year
								),
								"era_key": (
									str(
										gs.era.name
									)
									if gs.era != null
									else ""
								),
								"source": (
									"crown_hub_contract_engine."
									+ "resident_diplomacy_realm_quantum"
								),
								"background_only": true,
								"blocks_ui": false,
								"ready_gate_member": false
							}
						)
					)

				var entry: Dictionary = (
					_resident_diplomacy_compact_entry(
						realm_id,
						realm,
						actor_realm_id,
						permissions,
						{},
						war_preview,
						relation_contract
					)
				)

				var job_rank_contract_raw: Variant = job.get(
					"population_rank_contract",
					{}
				)
				if typeof(job_rank_contract_raw) == TYPE_DICTIONARY:
					entry = (
						_attach_resident_diplomacy_population_rank(
							entry,
							job_rank_contract_raw as Dictionary
						)
					)
				var entry_key: String = str(
					entry.get(
						"realm_key",
						""
					)
				).strip_edges()

				if (
					not entry.is_empty()
					and entry_key != ""
					and not seen_realm_keys.has(
						entry_key
					)
				):
					var entry_preview: Dictionary = _dict(
						entry.get(
							"war_preview_contract",
							{}
						)
					)
					var ordinary_foreign_realm: bool = (
						not bool(
							entry.get(
								"is_player_country",
								false
							)
						)
						and not bool(
							entry.get(
								"is_era_kingdom",
								false
							)
						)
					)
					var preview_hot: bool = (
						not entry_preview.is_empty()
						and bool(
							entry_preview.get(
								"success",
								false
							)
						)
						and not bool(
							entry_preview.get(
								"preview_pending",
								false
							)
						)
					)

					entry [
						"war_preview_deferred"
					] = (
						ordinary_foreign_realm
						and not preview_hot
					)
					entry [
						"war_preview_pending"
					] = (
						ordinary_foreign_realm
						and not preview_hot
					)
					entry [
						"war_preview_resolved_before_observation"
					] = (
						not ordinary_foreign_realm
						or preview_hot
					)
					entry [
						"war_preview_background_owned"
					] = true
					entry [
						"war_preview_click_build_forbidden"
					] = true
					entry [
						"war_preview_render_build_forbidden"
					] = true
					entry [
						"war_preview_ready_gate_member"
					] = false

					entries.append(
						entry
					)
					seen_realm_keys [
						entry_key
					] = true
					published_entry = (
						entry.duplicate(false)
					)
					published_war_preview_hot = (
						ordinary_foreign_realm
						and preview_hot
					)

			cursor += 1

		job [
			"cursor"
		] = cursor
		job [
			"entries"
		] = entries
		job [
			"seen_realm_keys"
		] = seen_realm_keys

		if not published_entry.is_empty():
			resident_diplomacy_entry_published.emit(
				actor_id,
				published_entry.duplicate(false)
			)

		if cursor < realm_keys.size():
			resident_diplomacy_projection_jobs [
				job_key
			] = job

			return {
				"success": true,
				"schema": (
					"eralife.crown_hub_contract_engine."
					+ "resident_diplomacy_quantum"
				),
				"actor_id": actor_id,
				"complete": false,
				"cursor": cursor,
				"total": realm_keys.size(),
				"published_count": entries.size(),
				"published_entry": (
					published_entry.duplicate(false)
				),
				"war_work_performed": (
					published_war_preview_hot
				),
				"blocks_ui": false,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}

		var all_war_previews_resident: bool = true

		for raw_entry in entries:
			var candidate_entry: Dictionary = _dict(
				raw_entry
			)

			if candidate_entry.is_empty():
				continue

			if (
				bool(
					candidate_entry.get(
						"is_player_country",
						false
					)
				)
				or bool(
					candidate_entry.get(
						"is_era_kingdom",
						false
					)
				)
			):
				continue

			var candidate_preview: Dictionary = _dict(
				candidate_entry.get(
					"war_preview_contract",
					{}
				)
			)

			if (
				candidate_preview.is_empty()
				or not bool(
					candidate_preview.get(
						"success",
						false
					)
				)
				or bool(
					candidate_preview.get(
						"preview_pending",
						false
					)
				)
			):
				all_war_previews_resident = false
				break

		var base_contract: Dictionary = (
			job.get(
				"base_contract",
				{}
			) as Dictionary
		)
		var section_surfaces_raw: Variant = (
			base_contract.get(
				"section_surfaces",
				{}
			)
		)
		var section_surfaces: Dictionary = (
			section_surfaces_raw as Dictionary
			if typeof(section_surfaces_raw) == TYPE_DICTIONARY
			else {}
		).duplicate(false)
		var diplomacy_revision: String = str(
			hash(
				entries
			)
		)

		section_surfaces [
			"diplomacy"
		] = [
			{
				"row_kind": (
					"resident_diplomacy_country_contract"
				),
				"title": "Diplomatic Countries",
				"description": (
					"%d era realms are published."
					% entries.size()
				),
				"data": {
					"entries": (
						entries.duplicate(false)
					),
					"entry_count": entries.size(),
					"actor_id": actor_id,
					"actor_realm_id": (
						actor_realm_id
					),
					"diplomacy_revision": (
						diplomacy_revision
					),
					"projection_state": "hot",
					"diplomacy_projection_complete": true,
					"war_preview_projection_complete": (
						all_war_previews_resident
					),
					"war_preview_projection_pending": (
						not all_war_previews_resident
					),
					"war_projection_pending": true,
					"ui_is_renderer_only": true
				},
				"actions": []
			}
		]

		var enriched_contract: Dictionary = (
			base_contract.duplicate(false)
		)

		enriched_contract [
			"section_surfaces"
		] = section_surfaces
		enriched_contract [
			"diplomacy_country_entries"
		] = entries.duplicate(false)
		enriched_contract [
			"diplomacy_revision"
		] = diplomacy_revision
		enriched_contract [
			"diplomacy_projection_complete"
		] = true
		enriched_contract [
			"diplomacy_projection_state"
		] = "hot"
		enriched_contract [
			"diplomacy_war_previews_resident"
		] = all_war_previews_resident
		enriched_contract [
			"war_preview_projection_complete"
		] = all_war_previews_resident
		enriched_contract [
			"war_preview_projection_pending"
		] = not all_war_previews_resident



		enriched_contract [
			"war_projection_pending"
		] = true
		enriched_contract [
			"war_projection_complete"
		] = false
		enriched_contract [
			"surface_revision"
		] = str(
			base_contract.get(
				"surface_revision",
				""
			)
		)
		enriched_contract [
			"diplomacy_population_rank_revision"
		] = str(
			job.get(
				"population_rank_revision",
				""
			)
		)
		enriched_contract [
			"diplomacy_population_rank_metric"
		] = "population_desc"
		enriched_contract [
			"diplomacy_population_rank_contract_owned"
		] = true
		resident_crown_contract_by_actor [
			str(
				actor_id
			)
		] = enriched_contract.duplicate(false)

		resident_diplomacy_projection_jobs.erase(
			job_key
		)

		return {
			"success": true,
			"schema": (
				"eralife.crown_hub_contract_engine."
				+ "resident_diplomacy_quantum"
			),
			"actor_id": actor_id,
			"complete": true,
			"cursor": cursor,
			"total": realm_keys.size(),
			"published_count": entries.size(),
			"crown_hub_contract": enriched_contract,
			"war_preview_projection_complete": (
				all_war_previews_resident
			),
			"blocks_ui": false,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}
func service_resident_diplomacy_population_rank_refresh(
	actor: Person,
	_context: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.realm_engine == null
	):
		return {
			"success": false,
			"reason": (
				"missing_diplomacy_population_rank_authority"
			),
			"population_rank_changed": false
		}

	var actor_id: int = int(
		actor.id
	)
	var actor_key: String = str(
		actor_id
	)
	var resident_raw: Variant = (
		resident_crown_contract_by_actor.get(
			actor_key,
			{}
		)
	)
	if typeof(resident_raw) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "missing_resident_crown_contract",
			"population_rank_changed": false
		}

	var resident_contract: Dictionary = (
		resident_raw as Dictionary
	)
	if resident_contract.is_empty():
		return {
			"success": false,
			"reason": "empty_resident_crown_contract",
			"population_rank_changed": false
		}

	var rank_contract: Dictionary = (
		_resident_diplomacy_population_rank_contract()
	)
	var next_revision: String = str(
		rank_contract.get(
			"revision",
			""
		)
	)
	var previous_revision: String = str(
		resident_contract.get(
			"diplomacy_population_rank_revision",
			""
		)
	)

	if (
		next_revision != ""
		and next_revision == previous_revision
	):
		return {
			"success": true,
			"schema": (
				"eralife.crown_hub."
				+ "diplomacy_population_rank_refresh"
			),
			"actor_id": actor_id,
			"population_rank_changed": false,
			"population_rank_revision": next_revision,
			"population_rank_deltas": [],
			"crown_hub_contract": resident_contract,
			"blocks_ui": false,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	var entries_raw: Variant = resident_contract.get(
		"diplomacy_country_entries",
		[]
	)
	var entries: Array = (
		(entries_raw as Array).duplicate(false)
		if typeof(entries_raw) == TYPE_ARRAY
		else []
	)

	var refreshed_entries: Array = []
	var changed_entries: Array = []

	for raw_entry in entries:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			continue

		var previous_entry: Dictionary = (
			raw_entry as Dictionary
		)
		var refreshed_entry: Dictionary = (
			_attach_resident_diplomacy_population_rank(
				previous_entry,
				rank_contract
			)
		)

		refreshed_entries.append(
			refreshed_entry
		)

		if (
			int(
				previous_entry.get(
					"population_rank",
					0
				)
			) != int(
				refreshed_entry.get(
					"population_rank",
					0
				)
			)
			or int(
				previous_entry.get(
					"population",
					0
				)
			) != int(
				refreshed_entry.get(
					"population",
					0
				)
			)
		):
			changed_entries.append(
				refreshed_entry
			)

	var updated_contract: Dictionary = (
		resident_contract.duplicate(false)
	)
	updated_contract [
		"diplomacy_country_entries"
	] = refreshed_entries
	updated_contract [
		"diplomacy_population_rank_revision"
	] = next_revision
	updated_contract [
		"diplomacy_population_rank_metric"
	] = "population_desc"
	updated_contract [
		"diplomacy_population_rank_contract_owned"
	] = true

	var section_surfaces_raw: Variant = (
		updated_contract.get(
			"section_surfaces",
			{}
		)
	)
	if typeof(section_surfaces_raw) == TYPE_DICTIONARY:
		var section_surfaces: Dictionary = (
			section_surfaces_raw as Dictionary
		).duplicate(false)

		var diplomacy_rows_raw: Variant = (
			section_surfaces.get(
				"diplomacy",
				[]
			)
		)
		if typeof(diplomacy_rows_raw) == TYPE_ARRAY:
			var diplomacy_rows: Array = (
				(diplomacy_rows_raw as Array).duplicate(false)
			)

			for index in range(
				diplomacy_rows.size()
			):
				var row_raw: Variant = diplomacy_rows [
					index
				]
				if typeof(row_raw) != TYPE_DICTIONARY:
					continue

				var row: Dictionary = (
					row_raw as Dictionary
				).duplicate(false)
				var data_raw: Variant = row.get(
					"data",
					{}
				)
				if typeof(data_raw) != TYPE_DICTIONARY:
					continue

				var data: Dictionary = (
					data_raw as Dictionary
				).duplicate(false)
				data ["entries"] = refreshed_entries
				data [
					"population_rank_revision"
				] = next_revision
				data [
					"population_rank_metric"
				] = "population_desc"

				row ["data"] = data
				diplomacy_rows [
					index
				] = row
				break

			section_surfaces [
				"diplomacy"
			] = diplomacy_rows
			updated_contract [
				"section_surfaces"
			] = section_surfaces

	resident_crown_contract_by_actor [
		actor_key
	] = updated_contract

	return {
		"success": true,
		"schema": (
			"eralife.crown_hub."
			+ "diplomacy_population_rank_refresh"
		),
		"actor_id": actor_id,
		"population_rank_changed": (
			not changed_entries.is_empty()
		),
		"population_rank_revision": next_revision,
		"population_rank_deltas": changed_entries,
		"population_rank_total": int(
			rank_contract.get(
				"realm_count",
				0
			)
		),
		"crown_hub_contract": updated_contract,
		"rank_computation_authority": ENGINE_SCHEMA,
		"blocks_ui": false,
		"ready_gate_member": false,
		"ui_is_renderer_only": true
	}
func resolve_crown_diplomacy_action_contract(
		actor: Person,
		payload: Dictionary = {}
) -> Dictionary:
		if actor == null:
			return _fail(
				"missing_actor",
				"No Crown actor could be resolved."
			)

		var action_id: String = str(
			payload.get(
				"action_id",
				""
			)
		).strip_edges().to_lower()
		var target_realm_id: int = int(
			payload.get(
				"realm_id",
				payload.get(
					"target_realm_id",
					-1
				)
			)
		)
		var country_name: String = str(
			payload.get(
				"country",
				"Foreign Realm"
			)
		).strip_edges()
		var is_era_kingdom: bool = (
			bool(
				payload.get(
					"is_era_kingdom",
					false
				)
			)
			or country_name.to_lower() == "era kingdom"
		)

		if is_era_kingdom:
			return _crown_contract_result(
				false,
				action_id,
				"Diplomacy Unavailable",
				(
					"The Era Kingdom does not accept "
					+ "ordinary realm diplomacy."
				),
				{
					"targeted_diplomacy_delta_only": true,
				}
			)

		var approval_before: int = int(
			actor.approval
		)
		var bank_before: int = int(
			actor.bank_balance
		)
		var scandal_before: int = int(
			actor.scandal
		)
		var event_name: String = ""
		var popup_title: String = "Diplomatic Action"
		var world_text: String = ""
		var result_text: String = ""

		match action_id:
			"country_envoy":
				actor.approval = clamp(
					int(actor.approval) + 1,
					0,
					100
				)
				event_name = "crown_country_envoy"
				popup_title = "Envoy Sent"
				world_text = (
					"%s sent a friendly envoy to %s."
					% [
						str(
							actor.first_name
						),
						country_name
					]
				)
				result_text = (
					"A friendly envoy was sent to %s."
					% country_name
				)

			"country_trade":
				actor.approval = clamp(
					int(actor.approval) + 2,
					0,
					100
				)
				event_name = "crown_country_trade"
				popup_title = "Trade Route Opened"
				world_text = (
					"%s %s opened a trade mission with %s."
					% [
						str(
							actor.first_name
						),
						str(
							actor.last_name
						),
						country_name
					]
				)
				result_text = (
					"You opened a trade mission with %s."
					% country_name
				)

			"country_gift":
				var gift_amount: int = 100000

				if int(actor.bank_balance) < gift_amount:
					return _crown_contract_result(
						false,
						action_id,
						"Diplomatic Gift Failed",
						(
							"You do not have enough money "
							+ "for that diplomatic gift."
						),
						{
							"targeted_diplomacy_delta_only": true,
							"summary_patch": {
								"approval": int(
									actor.approval
								)
							}
						}
					)

				actor.bank_balance = (
					int(actor.bank_balance)
					- gift_amount
				)
				actor.approval = clamp(
					int(actor.approval) + 1,
					0,
					100
				)
				event_name = "crown_country_gift"
				popup_title = "Diplomatic Gift Sent"
				world_text = (
					"%s %s sent a diplomatic gift to %s."
					% [
						str(
							actor.first_name
						),
						str(
							actor.last_name
						),
						country_name
					]
				)
				result_text = (
					"You sent a diplomatic gift to %s."
					% country_name
				)

			"country_bribe":
				var bribe_amount: int = 150000

				if int(actor.bank_balance) < bribe_amount:
					return _crown_contract_result(
						false,
						action_id,
						"Bribe Failed",
						(
							"You do not have enough money "
							+ "for that bribe."
						),
						{
							"targeted_diplomacy_delta_only": true,
							"summary_patch": {
								"approval": int(
									actor.approval
								)
							}
						}
					)

				actor.bank_balance = (
					int(actor.bank_balance)
					- bribe_amount
				)
				actor.scandal = clamp(
					int(actor.scandal) + 5,
					0,
					100
				)
				actor.approval = clamp(
					int(actor.approval) - 3,
					0,
					100
				)
				event_name = "crown_country_bribe"
				popup_title = "Bribe Sent"
				world_text = (
					"%s %s secretly bribed officials connected to %s."
					% [
						str(
							actor.first_name
						),
						str(
							actor.last_name
						),
						country_name
					]
				)
				result_text = (
					"You secretly bribed officials connected to %s."
					% country_name
				)

			_:
				return _fail(
					"unknown_diplomacy_action_contract",
					(
						"CrownHubContractEngine does not recognize "
						+ "that targeted diplomacy action."
					)
				)

		if (
			gs != null
			and world_text != ""
		):
			gs.push_world_feed(
				world_text,
				{
					"npc_id": int(
						actor.id
					),
					"personally_relevant": true,
					"category": "diplomacy",
					"event_name": event_name,
					"source": (
						"crown_hub_contract_engine"
					)
				}
			)

		var approval_after: int = int(
			actor.approval
		)
		var bank_after: int = int(
			actor.bank_balance
		)
		var scandal_after: int = int(
			actor.scandal
		)

		var result: Dictionary = _crown_contract_result(
			true,
			action_id,
			popup_title,
			result_text,
			{
				"category": "diplomacy",
				"event_name": event_name,
				"target_realm_id": target_realm_id,
				"country": country_name,
				"approval_before": approval_before,
				"approval_after": approval_after,
				"approval_delta": (
					approval_after
					- approval_before
				),
				"bank_balance_before": bank_before,
				"bank_balance_after": bank_after,
				"bank_balance_delta": (
					bank_after
					- bank_before
				),
				"scandal_before": scandal_before,
				"scandal_after": scandal_after,
				"scandal_delta": (
					scandal_after
					- scandal_before
				),
				"summary_patch": {
					"approval": approval_after
				},
				"targeted_diplomacy_delta_only": true,
				"blocks_ui": false,
				"ready_gate_member": false
			}
		)

		last_report = result.duplicate(true)

		return result
func service_resident_crown_war_projection_quantum(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if (
		actor == null
		or gs == null
		or gs.war_contract_engine == null
	):
		return {
			"success": false,
			"complete": true,
			"reason": "war_projection_authority_unavailable"
		}

	var actor_id: int = int(
		actor.id
	)
	var job_key: String = str(
		actor_id
	)
	var job_raw: Variant = (
		resident_crown_war_projection_jobs.get(
			job_key,
			{}
		)
	)
	var job: Dictionary = (
		job_raw as Dictionary
		if typeof(job_raw) == TYPE_DICTIONARY
		else {}
	)

	if job.is_empty():
		var base_raw: Variant = context.get(
			"base_contract",
			{}
		)
		var base_contract: Dictionary = (
			base_raw as Dictionary
			if typeof(base_raw) == TYPE_DICTIONARY
			else {}
		)
		var entries_raw: Variant = (
			base_contract.get(
				"diplomacy_country_entries",
				[]
			)
		)
		var entries: Array = (
			(entries_raw as Array).duplicate(false)
			if typeof(entries_raw) == TYPE_ARRAY
			else []
		)

		job = {
			"actor_id": actor_id,
			"actor_realm_id": int(
				context.get(
					"actor_realm_id",
					actor.realm_id
				)
			),
			"base_contract": (
				base_contract.duplicate(false)
			),
			"entries": entries,
			"entry_cursor": 0,
			"war_registry": {},
			"war_rows": [],
			"war_item_cursor": 0,
			"war_items": [],
			"phase": "registry"
		}

	var phase: String = str(
		job.get(
			"phase",
			"registry"
		)
	)
	var actor_realm_id: int = int(
		job.get(
			"actor_realm_id",
			actor.realm_id
		)
	)

	if phase == "registry":
		var war_registry: Dictionary = (
			gs.war_contract_engine
			.emit_war_registry_contract(
				{
					"realm_id": actor_realm_id,
					"include_global_active_wars": true,
					"source": (
						"crown_hub_contract_engine."
						+ "resident_war_registry_quantum"
					)
				}
			)
		)

		job [
			"war_registry"
		] = war_registry
		job [
			"phase"
		] = "entries"

		var war_items: Array = []

		for raw_war in _array(
			war_registry.get(
				"global_active_wars",
				war_registry.get(
					"active_wars",
					[]
				)
			)
		):
			war_items.append({
				"kind": "active",
				"war": raw_war
			})

		for raw_war in _array(
			war_registry.get(
				"war_history",
				[]
			)
		):
			war_items.append({
				"kind": "history",
				"war": raw_war
			})

		job [
			"war_items"
		] = war_items

		resident_crown_war_projection_jobs [
			job_key
		] = job

		var shell_contract: Dictionary = (
			_attach_war_registry_shell_projection(
				actor,
				job.get(
					"base_contract",
					{}
				) as Dictionary,
				war_registry
			)
		)

		shell_contract [
			"war_projection_pending"
		] = true
		shell_contract [
			"war_projection_complete"
		] = false
		shell_contract [
			"war_projection_phase"
		] = "entries"

		return {
			"success": true,
			"complete": false,
			"crown_hub_contract": shell_contract,
			"ui_is_renderer_only": true
		}

	if phase == "entries":
		var entries: Array = (
			job.get(
				"entries",
				[]
			) as Array
		)
		var cursor: int = int(
			job.get(
				"entry_cursor",
				0
			)
		)
		var published_entry: Dictionary = {}
		var war_registry: Dictionary = (
			job.get(
				"war_registry",
				{}
			) as Dictionary
		)

		if cursor < entries.size():
			var entry: Dictionary = _dict(
				entries [
					cursor
				]
			)
			var realm_id: int = int(
				entry.get(
					"realm_id",
					-1
				)
			)
			var realm: Dictionary = {}

			if bool(
				entry.get(
					"is_era_kingdom",
					false
				)
			):
				realm = (
					_resident_diplomacy_era_kingdom_surface()
				)
			elif (
				realm_id > 0
				and gs.realm_engine != null
			):
				var realms_raw: Variant = (
					gs.realm_engine.get(
						"realms"
					)
				)

				if typeof(realms_raw) == TYPE_DICTIONARY:
					var realms: Dictionary = (
						realms_raw as Dictionary
					)
					var realm_raw: Variant = realms.get(
						realm_id,
						realms.get(
							str(
								realm_id
							),
							{}
						)
					)

					if typeof(realm_raw) == TYPE_DICTIONARY:
						realm = (
							realm_raw as Dictionary
						)

			if not realm.is_empty():
				var effective_target_realm_id: int = (
					WarContractEngine
					.ERA_KINGDOM_WAR_REALM_ID
					if bool(
						entry.get(
							"is_era_kingdom",
							false
						)
					)
					else realm_id
				)
				var relation_contract: Dictionary = (
					gs.war_contract_engine
					.emit_realm_relation_contract(
						actor_realm_id,
						effective_target_realm_id
					)
				)
				var war_preview: Dictionary = {}

				if (
					realm_id > 0
					and realm_id != actor_realm_id
					and not bool(
						entry.get(
							"is_era_kingdom",
							false
						)
					)
				):
					war_preview = (
						gs.war_contract_engine
						.emit_war_preview_contract(
							{
								"attacker_realm_id": (
									actor_realm_id
								),
								"defender_realm_id": (
									realm_id
								),
								"defender_name": str(
									realm.get(
										"name",
										""
									)
								),
								"year": int(
									gs.year
								),
								"era_key": (
									str(
										gs.era.name
									)
									if gs.era != null
									else ""
								),
								"source": (
									"crown_hub_contract_engine."
									+ "resident_war_entry_quantum"
								)
							}
						)
					)

				var permissions: Dictionary = _dict(
					(
						job.get(
							"base_contract",
							{}
						) as Dictionary
					).get(
						"permissions",
						{}
					)
				)

				published_entry = (
					_resident_diplomacy_compact_entry(
						realm_id,
						realm,
						actor_realm_id,
						permissions,
						war_registry,
						war_preview,
						relation_contract
					)
				)

				if not published_entry.is_empty():
					entries [
						cursor
					] = published_entry

			cursor += 1
			job [
				"entry_cursor"
			] = cursor
			job [
				"entries"
			] = entries

		if cursor >= entries.size():
			job [
				"phase"
			] = "war_rows"

		resident_crown_war_projection_jobs [
			job_key
		] = job

		var partial_contract: Dictionary = (
			_attach_war_registry_shell_projection(
				actor,
				job.get(
					"base_contract",
					{}
				) as Dictionary,
				war_registry
			)
		)

		partial_contract [
			"diplomacy_country_entries"
		] = entries.duplicate(false)
		partial_contract [
			"war_last_published_entry"
		] = published_entry.duplicate(false)
		partial_contract [
			"war_projection_pending"
		] = true
		partial_contract [
			"war_projection_complete"
		] = false

		return {
			"success": true,
			"complete": false,
			"crown_hub_contract": partial_contract,
			"ui_is_renderer_only": true
		}

	if phase == "war_rows":
		var items: Array = (
			job.get(
				"war_items",
				[]
			) as Array
		)
		var cursor: int = int(
			job.get(
				"war_item_cursor",
				0
			)
		)
		var rows: Array = (
			job.get(
				"war_rows",
				[]
			) as Array
		)
		var registry: Dictionary = (
			job.get(
				"war_registry",
				{}
			) as Dictionary
		)

		if cursor < items.size():
			var item: Dictionary = _dict(
				items [
					cursor
				]
			)
			var single_war: Dictionary = _dict(
				item.get(
					"war",
					{}
				)
			)
			var mini_registry: Dictionary = {
				"global_active_wars": [],
				"active_wars": [],
				"war_history": []
			}

			if str(
				item.get(
					"kind",
					""
				)
			) == "history":
				mini_registry [
					"war_history"
				] = [
					single_war
				]
			else:
				mini_registry [
					"global_active_wars"
				] = [
					single_war
				]
				mini_registry [
					"active_wars"
				] = [
					single_war
				]

			rows.append_array(
				_war_section_rows(
					actor,
					mini_registry
				)
			)

			cursor += 1
			job [
				"war_item_cursor"
			] = cursor
			job [
				"war_rows"
			] = rows

			resident_crown_war_projection_jobs [
				job_key
			] = job

			var partial_contract: Dictionary = (
				_attach_war_registry_shell_projection(
					actor,
					job.get(
						"base_contract",
						{}
					) as Dictionary,
					registry
				)
			)

			partial_contract [
				"diplomacy_country_entries"
			] = (
				job.get(
					"entries",
					[]
				) as Array
			).duplicate(false)
			partial_contract [
				"war_projection_pending"
			] = true
			partial_contract [
				"war_projection_complete"
			] = false

			return {
				"success": true,
				"complete": false,
				"crown_hub_contract": partial_contract,
				"ui_is_renderer_only": true
			}

		job [
			"phase"
		] = "finalize"

	var final_registry: Dictionary = (
		job.get(
			"war_registry",
			{}
		) as Dictionary
	)
	var final_contract: Dictionary = (
		_attach_war_registry_shell_projection(
			actor,
			job.get(
				"base_contract",
				{}
			) as Dictionary,
			final_registry
		)
	)
	var final_entries: Array = (
		job.get(
			"entries",
			[]
		) as Array
	)
	var final_rows: Array = (
		job.get(
			"war_rows",
			[]
		) as Array
	)
	var section_surfaces: Dictionary = _dict(
		final_contract.get(
			"section_surfaces",
			{}
		)
	).duplicate(false)

	section_surfaces [
		"war"
	] = final_rows

	final_contract [
		"section_surfaces"
	] = section_surfaces
	final_contract [
		"diplomacy_country_entries"
	] = final_entries.duplicate(false)
	final_contract [
		"war_last_published_entry"
	] = {}
	final_contract [
		"war_projection_pending"
	] = false
	final_contract [
		"war_projection_complete"
	] = true

	resident_crown_contract_by_actor [
		job_key
	] = final_contract.duplicate(false)

	resident_crown_war_projection_jobs.erase(
		job_key
	)

	return {
		"success": true,
		"complete": true,
		"crown_hub_contract": final_contract,
		"ui_is_renderer_only": true
	}
func emit_resident_crown_hub_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No resident Crown Hub observer could be resolved."
		)

	if (
		_runtime() == null
		or _law() == null
	):
		return emit_observable_contract(
			actor,
			context
		)

	var active_section: String = _section(
		str(
			context.get(
				"active_section",
				context.get(
					"section_id",
					"throne"
				)
			)
		)
	)
	var institution: Dictionary = (
		_runtime().institution_for_actor(
			actor
		)
	)
	var civic_contract: Dictionary = (
		_civic_office_contract_for_actor(
			actor
		)
	)
	var civic_projection: bool = (
		_actor_uses_civic_crown_projection(
			actor
		)
	)
	var realm: Dictionary = (
		_civic_realm_for_actor(
			actor
		)
	)
	var summary: Dictionary = (
		_law().summary_for_actor(
			actor
		)
	)
	var permissions: Dictionary = (
		_law().permissions_for_actor(
			actor
		)
	)

	summary = _crown_summary_with_civic_office(
		actor,
		summary,
		civic_contract,
		realm
	)
	permissions = _crown_permissions_with_civic_office(
		actor,
		permissions,
		civic_contract
	)
	permissions [
		"can_declare_war"
	] = _actor_can_declare_war(
		actor,
		permissions
	)

	var constitutional_contract: Dictionary = (
		_civic_constitutional_contract_for_actor(
			actor,
			civic_contract,
			realm
		)
		if civic_projection
		else _law().constitutional_contract_for_actor(
			actor
		)
	)
	var section_surfaces: Dictionary = (
		_resident_crown_core_section_surfaces(
			actor,
			summary,
			permissions,
			constitutional_contract
		)
	)
	var section_tabs: Array = (
		_civic_crown_section_tabs()
		if civic_projection
		else _section_tabs()
	)
	var revision_semantics: Dictionary = {
		"actor_id": int(actor.id),
		"year": (
			int(gs.year)
			if gs != null
			else 0
		),
		"active_section": active_section,
		"institution_id": str(
			institution.get(
				"institution_id",
				""
			)
		),
		"monarch_id": int(
			summary.get(
				"monarch_id",
				-1
			)
		),
		"realm_id": int(
			summary.get(
				"realm_id",
				actor.realm_id
			)
		),
		"title": str(
			summary.get(
				"title",
				actor.royal_title
			)
		),
		"house_label": str(
			summary.get(
				"house_label",
				""
			)
		),
		"approval": int(
			summary.get(
				"approval",
				0
			)
		),
		"legitimacy": int(
			summary.get(
				"legitimacy",
				0
			)
		),
		"respect": int(
			summary.get(
				"respect",
				0
			)
		),
		"population": int(
			summary.get(
				"population",
				0
			)
		),
		"treasury": int(
			summary.get(
				"treasury",
				0
			)
		),
		"land": int(
			summary.get(
				"land",
				0
			)
		),
		"military_stockpile": int(
			summary.get(
				"military_stockpile",
				0
			)
		),
		"goods_stockpile": int(
			summary.get(
				"goods_stockpile",
				0
			)
		),
		"claimant_pressure": float(
			summary.get(
				"claimant_pressure",
				0.0
			)
		),
		"royal_succession_tension": float(
			summary.get(
				"royal_succession_tension",
				0.0
			)
		),
		"coup_pressure": float(
			summary.get(
				"coup_pressure",
				0.0
			)
		),
		"permissions": permissions,
		"civic_contract": civic_contract
	}
	var surface_revision: String = "%d:%d:%s:%s" % [
		int(actor.id),
		(
			int(gs.year)
			if gs != null
			else 0
		),
		active_section,
		str(
			hash(
				revision_semantics
			)
		)
	]
	var status_text: String = (
		"%s • Approval %d • Stability %d"
		% [
			str(
				summary.get(
					"realm_name",
					"Royal Realm"
				)
			),
			int(
				summary.get(
					"approval",
					0
				)
			),
			int(
				summary.get(
					"stability",
					0
				)
			)
		]
	)

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _person_name(
			actor
		),
		"title": (
			" FEDERAL HUB"
			if civic_projection
			else " CROWN HUB"
		),
		"subtitle": (
			(
				"Executive office, cabinet, nation, budget, "
				+ "diplomacy, and constitutional law."
			)
			if civic_projection
			else (
				"Monarchy, dynasty, court, law, and succession "
				+ "as one institutional reality."
			)
		),
		"active_section": active_section,
		"section_tabs": section_tabs,
		"summary": summary,
		"permissions": permissions,
		"institution": institution,
		"civic_office_contract": (
			civic_contract.duplicate(true)
		),
		"constitutional_contract": (
			constitutional_contract.duplicate(true)
		),
		"current_monarch": (
			_resident_diplomacy_read_only_person_snapshot(
				int(
					summary.get(
						"monarch_id",
						-1
					)
				)
			)
		),
		"current_office_holder": (
			_person_projection(
				actor
			)
			if civic_projection
			else {}
		),
		"royal_family": [],
		"first_family": [],
		"court": [],
		"dynasties": [],
		"claimants": [],
		"succession": {
			"candidates": [],
		},
		"royal_authority": permissions,
		"realm_stability": int(
			summary.get(
				"stability",
				0
			)
		),
		"diplomatic_houses": [],
		"royal_assets": [],
		"royal_decrees": [],
		"ceremonies": [],
		"line_of_succession": [],
		"mod_provider_rows": {},
		"section_surfaces": section_surfaces,
		"active_section_rows": _array(
			section_surfaces.get(
				active_section,
				[]
			)
		),
		"status_text": status_text,
		"truth_state": "hot",
		"authoritative_projection": true,
		"resident_projection": true,
		"war_projection_pending": true,
		"surface_revision": surface_revision,
		"crown_hub_layout_variant": (
			"federal_republic"
			if civic_projection
			else "royalty"
		),
		"federal_republic": civic_projection,
		"royal_language_forbidden": civic_projection,
		"ready_gate_member": false,
		"runtime_authority": (
			"realm_engine"
			if civic_projection
			else "royalty_runtime_engine"
		),
		"constitutional_authority": (
			"checks_and_balances_contract_engine"
			if civic_projection
			else "royalty_contract_engine"
		),
		"ui_is_renderer_only": true
	}

func export_state() -> Dictionary:
	return {
		"schema": (
			"eralife.crown_hub_contract_engine_state"
		),
		"version": ENGINE_VERSION,
		"lens_state": _lens_root().duplicate(true),
		"last_report": last_report.duplicate(true)
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	if gs != null:
		if typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY:
			gs.scenario_state = {}

		gs.scenario_state [LENS_STATE_KEY] = _dict(
			data.get(
				"lens_state",
				{}
			)
		)

	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)
	_ensure_lens_root()

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION
	}


func _build_section_surfaces(
	actor: Person,
	institution: Dictionary,
	summary: Dictionary,
	permissions: Dictionary,
	family_rows: Array,
	court_rows: Array,
	claimant_rows: Array,
	succession_rows: Array,
	dynasties: Array,
	mod_rows: Dictionary
) -> Dictionary:
	var throne_rows: Array = [
		{
			"row_kind": "institution_summary",
			"title": str(
				summary.get(
					"title",
					"Vacant Throne"
				)
			),
			"subtitle": str(
				summary.get(
					"realm_name",
					"Unbound Realm"
				)
			),
			"description": (
				"Legitimacy %d • Stability %d • %s"
				% [
					int(
						summary.get(
							"legitimacy",
							0
						)
					),
					int(
						summary.get(
							"stability",
							0
						)
					),
					str(
						summary.get(
							"integrity_state",
							"unknown"
						)
					).replace(
						"_",
						" "
					).capitalize()
				]
			),
			"data": summary.duplicate(true),
			"actions": []
		}
	]

	if bool(
		permissions.get(
			"can_abdicate",
			false
		)
	):
		throne_rows.append({
			"row_kind": "action",
			"action_id": "abdicate",
			"title": "Abdicate",
			"description": (
				"Transfer the institution to the highest "
				+ "eligible successor."
			),
			"enabled": true
		})

	var dynasty_rows: Array = [
		{
			"row_kind": "succession_line",
			"title": "Line of Succession",
			"rows": succession_rows.duplicate(true),
			"actions": []
		},
		{
			"row_kind": "claimants",
			"title": "Claimants",
			"rows": claimant_rows.duplicate(true),
			"actions": []
		},
		{
			"row_kind": "dynasties",
			"title": "Dynasties",
			"rows": dynasties.duplicate(true),
			"actions": []
		}
	]

	if bool(
		permissions.get(
			"can_appoint_heir",
			false
		)
	):
		dynasty_rows.append({
			"row_kind": "action",
			"action_id": "appoint_heir",
			"title": "Appoint Heir",
			"description": (
				"Designate an eligible member of the "
				+ "institution as constitutional heir."
			),
			"requires_target": true,
			"target_rows": succession_rows.duplicate(true),
			"enabled": true
		})

	var court_surface: Array = [
		{
			"row_kind": "people",
			"title": "Royal Court",
			"rows": court_rows.duplicate(true),
			"actions": []
		}
	]
	court_surface.append_array(
		_array(
			mod_rows.get(
				"royal_court",
				[]
			)
		)
	)

	var law_surface: Array = [
		{
			"row_kind": "constitutional_contract",
			"title": "Constitutional Law",
			"data": (
				_law().constitutional_contract_for_actor(
					actor
				)
			),
			"actions": []
		},
		{
			"row_kind": "decrees",
			"title": "Royal Decrees",
			"rows": _array(
				institution.get(
					"decrees",
					[]
				)
			),
			"actions": []
		}
	]

	var nation_surface: Array = [
		{
			"row_kind": "realm",
			"title": str(
				summary.get(
					"realm_name",
					"Royal Realm"
				)
			),
			"description": (
				"Population %d • Treasury %d • Land %d"
				% [
					int(
						summary.get(
							"population",
							0
						)
					),
					int(
						summary.get(
							"treasury",
							0
						)
					),
					int(
						summary.get(
							"land",
							0
						)
					)
				]
			),
			"data": institution.duplicate(true),
			"actions": []
		}
	]

	var allocation_surface: Array = [
		{
			"row_kind": "allocation",
			"title": "Royal Treasury",
			"description": (
				"Treasury %d • Population %d • Stability %d"
				% [
					int(
						summary.get(
							"treasury",
							0
						)
					),
					int(
						summary.get(
							"population",
							0
						)
					),
					int(
						summary.get(
							"stability",
							0
						)
					)
				]
			),
			"data": summary.duplicate(true),
			"actions": []
		}
	]

	var diplomacy_surface: Array = [
		{
			"row_kind": "diplomatic_houses",
			"title": "Diplomatic Houses",
			"rows": _array(
				institution.get(
					"diplomatic_houses",
					[]
				)
			),
			"actions": []
		}
	]

	var family_surface: Array = [
		{
			"row_kind": "people",
			"title": "Royal Family",
			"rows": family_rows.duplicate(true),
			"actions": []
		}
	]

	throne_rows.append_array(
		_array(
			mod_rows.get(
				"coronation",
				[]
			)
		)
	)
	dynasty_rows.append_array(
		_array(
			mod_rows.get(
				"succession",
				[]
			)
		)
	)
	dynasty_rows.append_array(
		_array(
			mod_rows.get(
				"dynasty",
				[]
			)
		)
	)
	dynasty_rows.append_array(
		_array(
			mod_rows.get(
				"heraldry",
				[]
			)
		)
	)
	family_surface.append_array(
		_array(
			mod_rows.get(
				"royal_marriage",
				[]
			)
		)
	)
	law_surface.append_array(
		_array(
			mod_rows.get(
				"royal_inheritance",
				[]
			)
		)
	)

	return {
		"throne": throne_rows,
		"court": court_surface,
		"nation": nation_surface,
		"allocation": allocation_surface,
		"diplomacy": diplomacy_surface,
		"law": law_surface,
		"dynasty": dynasty_rows,
		"family": family_surface
	}


func _observable_section_surfaces(
	summary: Dictionary,
	permissions: Dictionary
) -> Dictionary:
	return {
		"throne": [
			{
				"row_kind": "institution_summary",
				"title": str(
					summary.get(
						"title",
						"Royal Institution"
					)
				),
				"description": (
					"Royal truth is becoming observable."
				),
				"data": summary.duplicate(true),
				"actions": []
			}
		],
		"court": [],
		"nation": [],
		"allocation": [],
		"diplomacy": [],
		"law": [],
		"dynasty": [],
		"family": [],
		"permissions": permissions.duplicate(true)
	}


func _royalty_provider_rows(
	actor: Person
) -> Dictionary:
	var out: Dictionary = {}

	if _mod_authority() == null:
		return out

	for provider_type in (
		RoyaltyModContractEngine
		.ROYALTY_PROVIDER_TYPES
	):
		out [provider_type] = (
			_mod_authority().emit_provider_rows(
				provider_type,
				actor,
				{
					"source": (
						"crown_hub_contract_engine"
					)
				}
			)
		)

	return out


func _people_projection(
	actor_ids: Array
) -> Array:
	var out: Array = []
	var seen: Dictionary = {}

	for raw_actor_id in actor_ids:
		var actor_id: int = int(raw_actor_id)

		if actor_id <= 0 or seen.has(actor_id):
			continue

		seen [actor_id] = true
		var actor: Person = _person_by_id(actor_id)

		if actor != null:
			out.append(
				_person_projection(actor)
			)

	return out


func _person_projection(
	actor: Person
) -> Dictionary:
	if actor == null:
		return {}

	return {
		"actor_id": int(actor.id),
		"name": _person_name(actor),
		"title": str(actor.royal_title),
		"role": (
			_runtime_role(actor)
		),
		"age": int(actor.age),
		"alive": bool(actor.alive),
		"is_ruler": bool(actor.is_ruler),
		"is_royal": bool(actor.is_royal),
		"succession_rank": int(
			actor.succession_rank
		),
		"approval": int(actor.approval),
		"fame": int(actor.fame),
		"deposed": bool(actor.deposed),
		"exiled": bool(actor.exiled),
		"realm_id": int(actor.realm_id),
		"house_id": str(
			_runtime().house_for_actor(actor).get(
				"house_id",
				""
			)
			if _runtime() != null
			else ""
		),
		"ui_is_renderer_only": true
	}


func _runtime_role(
	actor: Person
) -> String:
	if actor == null:
		return "unknown"

	if actor.is_ruler:
		return "monarch"
	if int(actor.succession_rank) == 1:
		return "heir"
	if actor.deposed or actor.exiled:
		return "claimant"
	if actor.is_royal:
		return "royal_family"

	return "nobility"


func _section_tabs(
	include_war: bool = false
) -> Array:
	var tabs: Array = [
		{
			"id": "throne",
			"label": "THRONE",
			"icon": " "
		},
		{
			"id": "court",
			"label": "COURT",
			"icon": " "
		},
		{
			"id": "family",
			"label": "ROYAL FAMILY",
			"icon": " "
		},
		{
			"id": "nation",
			"label": "NATION",
			"icon": " "
		},
		{
			"id": "allocation",
			"label": "TREASURY",
			"icon": " "
		},
		{
			"id": "diplomacy",
			"label": "DIPLOMACY",
			"icon": " "
		},
		{
			"id": "law",
			"label": "LAW",
			"icon": " "
		},
		{
			"id": "dynasty",
			"label": "DYNASTY",
			"icon": " "
		}
	]

	if include_war:
		tabs.insert(
			6,
			{
				"id": "war",
				"label": "WAR",
				"icon": " ",
				"urgent": true
			}
		)

	return tabs

func _section(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	if clean not in [
		"throne",
		"court",
		"family",
		"nation",
		"allocation",
		"diplomacy",
		"war",
		"law",
		"dynasty"
	]:
		return "throne"

	return clean


func _lens_for(
	actor: Person
) -> Dictionary:
	var root: Dictionary = _lens_root()
	var actor_key: String = str(int(actor.id))
	var lens: Dictionary = _dict(
		root.get(
			actor_key,
			{}
		)
	)

	if lens.is_empty():
		lens = {
			"active_section": "throne"
		}

	return lens


func _commit_lens(
	actor: Person,
	lens: Dictionary
) -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var root: Dictionary = _lens_root()
	root [str(int(actor.id))] = lens.duplicate(true)
	gs.scenario_state [LENS_STATE_KEY] = root


func _ensure_lens_root() -> void:
	if gs == null:
		return

	if typeof(
		gs.scenario_state
	) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	if typeof(
		gs.scenario_state.get(
			LENS_STATE_KEY,
			{}
		)
	) != TYPE_DICTIONARY:
		gs.scenario_state [LENS_STATE_KEY] = {}


func _lens_root() -> Dictionary:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return {}

	return _dict(
		gs.scenario_state.get(
			LENS_STATE_KEY,
			{}
		)
	)


func _runtime_state() -> Dictionary:
	if (
		gs == null
		or typeof(
			gs.royalty_institution_state
		) != TYPE_DICTIONARY
	):
		return {}

	return _dict(
		gs.royalty_institution_state
	)


func _provider_revision() -> int:
	return (
		int(
			_mod_authority().registry_revision
		)
		if _mod_authority() != null
		else 0
	)


func _runtime():
	return (
		gs.royalty_runtime_engine
		if (
			gs != null
			and gs.royalty_runtime_engine != null
		)
		else null
	)


func _law():
	return (
		gs.royalty_contract_engine
		if (
			gs != null
			and gs.royalty_contract_engine != null
		)
		else null
	)


func _mod_authority():
	return (
		gs.royalty_mod_contract_engine
		if (
			gs != null
			and gs.royalty_mod_contract_engine != null
		)
		else null
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