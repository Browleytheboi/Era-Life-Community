extends Resource
class_name AssetsContractEngine

const ENGINE_SCHEMA:= "eralife.assets_contract_engine"
const ASSETS_SURFACE_SCHEMA:= "eralife.assets.surface_contract"
const SURFACE_PACK_SCHEMA:= "eralife.assets.prewarmed_surface_pack"
const CONTRACT_VERSION:= 1

var gs: GameState = null
var assets_surface_cache: Dictionary = {}
var surface_pack_cache: Dictionary = {}
var last_report: Dictionary = {}
var portfolio_observation_jobs: Dictionary = {}

func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()


func contract() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"authority": "assets_surface_contracts",
		"owns_ui": false,
		"portfolio_authorities": [
			"PropertyEngine",
			"VehicleEngine"
		],
		"market_authorities": [
			"PropertyMarketContractEngine",
			"DealershipContractEngine"
		],
		"surface_authority": ENGINE_SCHEMA,
		"supported_surfaces": [
			"assets",
			"property_market",
			"vehicle_market"
		],
		"ui_is_renderer_only": true
	}


func get_contract() -> Dictionary:
	return contract()

func prewarm_actor_assets_surface(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:




	return prewarm_actor_surface_pack(
		actor,
		context
	)
func _assets_observable_actions() -> Array:
	return [
		{
			"action_id": "look_for_property",
			"label": "Look For Property",
			"icon": " ",
			"disabled": false,
			"intent_mode": "reveal_resident_surface",
			"destination_surface": "property_market_contract_panel",
			"visible_click_work_forbidden": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		},
		{
			"action_id": "look_for_vehicles",
			"label": "Look For Vehicles",
			"icon": " ",
			"disabled": false,
			"intent_mode": "reveal_resident_surface",
			"destination_surface": "vehicle_market_contract_panel",
			"visible_click_work_forbidden": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		},
		{
			"action_id": "look_for_creatures",
			"label": "Look For Creatures",
			"icon": " ",
			"disabled": false,
			"intent_mode": "reveal_resident_surface",
			"destination_surface": "pet_shop_contract_panel",
			"visible_click_work_forbidden": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}
	]
func service_actor_portfolio_observation_quantum(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor == null:
		return {
			"success": false,
			"complete": true,
			"reason": "missing_actor"
		}

	var actor_id: int = int(
		actor.id
	)
	var job_key: String = _assets_surface_key(
		actor
	)

	if bool(
		context.get(
			"force_rebuild",
			false
		)
	):
		portfolio_observation_jobs.erase(
			job_key
		)
		assets_surface_cache.erase(
			job_key
		)

	var job_raw: Variant = (
		portfolio_observation_jobs.get(
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
		var property_bucket_keys: Array = []

		if (
			gs != null
			and gs.property_engine != null
			and typeof(
				gs.property_engine.properties
			) == TYPE_DICTIONARY
		):
			property_bucket_keys = (
				gs.property_engine.properties.keys()
			)

		var vehicle_rows: Array = []

		if (
			gs != null
			and gs.vehicle_engine != null
			and typeof(
				gs.vehicle_engine.vehicles
			) == TYPE_DICTIONARY
		):
			var vehicle_raw: Variant = (
				gs.vehicle_engine.vehicles.get(
					actor_id,
					[]
				)
			)

			if typeof(vehicle_raw) == TYPE_ARRAY:
				vehicle_rows = vehicle_raw as Array

		var faction_ids: Array = []

		if (
			gs != null
			and gs.universal_faction_engine != null
			and typeof(
				gs.universal_faction_engine.membership_index
			) == TYPE_DICTIONARY
		):
			var memberships_raw: Variant = (
				gs.universal_faction_engine.membership_index.get(
					str(actor_id),
					{}
				)
			)

			if typeof(memberships_raw) == TYPE_DICTIONARY:
				faction_ids = (
					(memberships_raw as Dictionary).keys()
				)

		job = {
			"actor_id": actor_id,
			"phase": "head",
			"property_bucket_keys": property_bucket_keys,
			"property_bucket_cursor": 0,
			"property_item_cursor": 0,
			"property_rows": [],
			"property_seen_ids": {},
			"belongings_categories": [
				"Real Estate",
				"Property",
				"Properties"
			],
			"belongings_category_cursor": 0,
			"belongings_item_cursor": 0,
			"vehicle_rows_source": vehicle_rows,
			"vehicle_cursor": 0,
			"vehicle_rows": [],
			"vehicle_seen_ids": {},
			"faction_ids": faction_ids,
			"faction_cursor": 0,
			"faction_edge_keys": [],
			"faction_edge_cursor": 0,
			"faction_current_id": "",
			"faction_contested_claims": 0,
			"faction_claim_pressure": 0.0,
			"faction_hidden_instability": 0.0,
			"faction_rows": [],
			"started_at_ms": int(
				Time.get_ticks_msec()
			),
			"ui_is_renderer_only": true
		}

		portfolio_observation_jobs [
			job_key
		] = job

	var patch: Dictionary = {
		"actor_id": actor_id,
		"patch_kind": ""
	}
	var phase: String = str(
		job.get(
			"phase",
			"head"
		)
	)

	match phase:
		"head":
			patch = {
				"actor_id": actor_id,
				"patch_kind": "head",
				"bank_balance": int(
					actor.bank_balance
				),
				"bank_balance_text": _format_money(
					int(
						actor.bank_balance
					)
				),
				"actions": _assets_observable_actions(),
				"truth_state": "observable_partial"
			}
			job ["phase"] = "properties"

		"properties":
			var property_store: Dictionary = {}

			if (
				gs != null
				and gs.property_engine != null
				and typeof(
					gs.property_engine.properties
				) == TYPE_DICTIONARY
			):
				property_store = (
					gs.property_engine.properties
				)

			var bucket_keys: Array = (
				job.get(
					"property_bucket_keys",
					[]
				) as Array
			)
			var bucket_cursor: int = int(
				job.get(
					"property_bucket_cursor",
					0
				)
			)
			var item_cursor: int = int(
				job.get(
					"property_item_cursor",
					0
				)
			)

			if bucket_cursor >= bucket_keys.size():
				job ["phase"] = "belongings"
			else:
				var bucket_key: Variant = (
					bucket_keys [
						bucket_cursor
					]
				)
				var bucket_owner_id: int = int(
					bucket_key
				)
				var bucket_raw: Variant = (
					property_store.get(
						bucket_key,
						[]
					)
				)
				var bucket: Array = (
					bucket_raw as Array
					if typeof(bucket_raw) == TYPE_ARRAY
					else []
				)

				if item_cursor >= bucket.size():
					job [
						"property_bucket_cursor"
					] = bucket_cursor + 1
					job [
						"property_item_cursor"
					] = 0
				else:
					job [
						"property_item_cursor"
					] = item_cursor + 1

					var raw_property: Variant = (
						bucket [
							item_cursor
						]
					)

					if typeof(raw_property) == TYPE_DICTIONARY:
						var property_data: Dictionary = (
							raw_property as Dictionary
						)
						var actor_parent_ids: Array = (
							actor.parents
							if typeof(actor.parents) == TYPE_ARRAY
							else []
						)
						var household_raw: Variant = (
							actor.get(
								"household_member_ids"
							)
						)
						var actor_household_ids: Array = (
							household_raw as Array
							if typeof(household_raw) == TYPE_ARRAY
							else []
						)
						var legal_owner_ids: Array = _safe_array(
							property_data.get(
								"owners",
								property_data.get(
									"legal_owner_ids",
									[]
								)
							)
						)
						var control_roles: Dictionary = _safe_dictionary(
							property_data.get(
								"control_roles",
								{}
							)
						)
						var control_owner_ids: Array = _safe_array(
							control_roles.get(
								"owner_ids",
								[]
							)
						)
						var resident_ids: Array = _safe_array(
							property_data.get(
								"resident_ids",
								property_data.get(
									"occupant_ids",
									property_data.get(
										"household_member_ids",
										[]
									)
								)
							)
						)
						var tenant_ids: Array = _safe_array(
							property_data.get(
								"tenant_ids",
								[]
							)
						)
						var observable: bool = (
							bucket_owner_id == actor_id
							or actor_id in legal_owner_ids
							or actor_id in control_owner_ids
							or actor_id in resident_ids
							or actor_id in tenant_ids
							or bucket_owner_id in actor_parent_ids
							or bucket_owner_id in actor_household_ids
						)

						if observable:
							var reason: String = (
								"household_or_resident_property"
							)

							if (
								bucket_owner_id == actor_id
								or actor_id in legal_owner_ids
								or actor_id in control_owner_ids
							):
								reason = "direct_property_store"
							elif actor_id in resident_ids:
								reason = "resident_of_property"
							elif actor_id in tenant_ids:
								reason = "tenant_of_property"
							elif bucket_owner_id in actor_parent_ids:
								reason = "child_or_household_under_owner"
							elif bucket_owner_id in actor_household_ids:
								reason = "co_resident_with_owner"

							var rows: Array = (
								job.get(
									"property_rows",
									[]
								) as Array
							)
							var seen: Dictionary = (
								job.get(
									"property_seen_ids",
									{}
								) as Dictionary
							)
							var before_count: int = (
								rows.size()
							)

							_append_visible_property_asset_row(
								property_data,
								actor,
								reason,
								bucket_owner_id,
								rows,
								seen
							)

							job [
								"property_rows"
							] = rows
							job [
								"property_seen_ids"
							] = seen

							if rows.size() > before_count:
								patch = {
									"actor_id": actor_id,
									"patch_kind": "property_row",
									"property_row": rows [
										rows.size() - 1
									]
								}

		"belongings":
			var categories: Array = (
				job.get(
					"belongings_categories",
					[]
				) as Array
			)
			var category_cursor: int = int(
				job.get(
					"belongings_category_cursor",
					0
				)
			)
			var item_cursor: int = int(
				job.get(
					"belongings_item_cursor",
					0
				)
			)

			if category_cursor >= categories.size():
				job ["phase"] = "vehicles"
			elif (
				gs == null
				or gs.belongings_engine == null
			):
				job ["phase"] = "vehicles"
			else:
				var inventory: Dictionary = (
					gs.belongings_engine.get_inventory(
						actor
					)
				)
				var category_name: String = str(
					categories [
						category_cursor
					]
				)
				var category_raw: Variant = (
					inventory.get(
						category_name,
						[]
					)
				)
				var category_items: Array = (
					category_raw as Array
					if typeof(category_raw) == TYPE_ARRAY
					else []
				)

				if item_cursor >= category_items.size():
					job [
						"belongings_category_cursor"
					] = category_cursor + 1
					job [
						"belongings_item_cursor"
					] = 0
				else:
					job [
						"belongings_item_cursor"
					] = item_cursor + 1

					var item_raw: Variant = (
						category_items [
							item_cursor
						]
					)

					if typeof(item_raw) == TYPE_DICTIONARY:
						var item: Dictionary = (
							item_raw as Dictionary
						)
						var asset_kind: String = str(
							item.get(
								"asset_kind",
								item.get(
									"category",
									""
								)
							)
						).strip_edges().to_lower()

						if (
							asset_kind == "property"
							or category_name == "Real Estate"
						):
							var rows: Array = (
								job.get(
									"property_rows",
									[]
								) as Array
							)
							var seen: Dictionary = (
								job.get(
									"property_seen_ids",
									{}
								) as Dictionary
							)
							var before_count: int = rows.size()

							_append_visible_property_asset_row(
								item,
								actor,
								"resident_belongings_projection",
								-1,
								rows,
								seen
							)

							job ["property_rows"] = rows
							job ["property_seen_ids"] = seen

							if rows.size() > before_count:
								patch = {
									"actor_id": actor_id,
									"patch_kind": "property_row",
									"property_row": rows [
										rows.size() - 1
									]
								}

		"vehicles":
			var source_rows: Array = (
				job.get(
					"vehicle_rows_source",
					[]
				) as Array
			)
			var cursor: int = int(
				job.get(
					"vehicle_cursor",
					0
				)
			)

			if cursor >= source_rows.size():
				job ["phase"] = "factions"
			else:
				job ["vehicle_cursor"] = cursor + 1

				var vehicle_raw: Variant = (
					source_rows [
						cursor
					]
				)

				if typeof(vehicle_raw) == TYPE_DICTIONARY:
					var vehicle: Dictionary = (
						vehicle_raw as Dictionary
					)
					var vehicle_id: int = int(
						vehicle.get(
							"id",
							-1
						)
					)
					var seen: Dictionary = (
						job.get(
							"vehicle_seen_ids",
							{}
						) as Dictionary
					)

					if (
						vehicle_id > 0
						and not seen.has(
							vehicle_id
						)
					):
						seen [vehicle_id] = true

						var display_name: String = str(
							vehicle.get(
								"nickname",
								""
							)
						).strip_edges()

						if display_name == "":
							display_name = str(
								vehicle.get(
									"display_name",
									vehicle.get(
										"model",
										vehicle.get(
											"type",
											"Vehicle"
										)
									)
								)
							)

						var vehicle_row: Dictionary = {
							"asset_id": vehicle_id,
							"display_name": display_name,
							"condition": int(
								round(
									float(
										vehicle.get(
											"condition",
											100.0
										)
									)
								)
							),
							"condition_label": str(
								vehicle.get(
									"condition_label",
									"Excellent"
								)
							),
							"operator_label": str(
								vehicle.get(
									"operator_label",
									"Personal"
								)
							),
							"route_label": str(
								vehicle.get(
									"assigned_route",
									"Local Use"
								)
							),
							"trade_role_label": str(
								vehicle.get(
									"trade_role",
									"Personal Travel"
								)
							)
						}

						var rows: Array = (
							job.get(
								"vehicle_rows",
								[]
							) as Array
						)
						rows.append(
							vehicle_row
						)
						job ["vehicle_rows"] = rows
						job ["vehicle_seen_ids"] = seen

						# DIAGNOSTIC: the vehicles array holds one canoe but two cards
						# render, so a row is being emitted twice. Report each append
						# with the running row count and the dedupe set.
						EraLog.truth(
							"ERALIFE_ASSET_VEHICLE_ROW|vehicle_id=%d|rows_now=%d|seen=%d"
							% [
								vehicle_id,
								rows.size(),
								seen.size()
							]
						)

						patch = {
							"actor_id": actor_id,
							"patch_kind": "vehicle_row",
							"vehicle_row": vehicle_row
						}

		"factions":
			var faction_ids: Array = (
				job.get(
					"faction_ids",
					[]
				) as Array
			)
			var faction_cursor: int = int(
				job.get(
					"faction_cursor",
					0
				)
			)

			if (
				faction_cursor >= faction_ids.size()
				or gs == null
				or gs.universal_faction_engine == null
			):
				job ["phase"] = "complete"
			else:
				var faction_id: String = str(
					faction_ids [
						faction_cursor
					]
				)
				var current_id: String = str(
					job.get(
						"faction_current_id",
						""
					)
				)

				if current_id != faction_id:
					var edges_raw: Variant = (
						gs.universal_faction_engine.relationship_graph.get(
							faction_id,
							{}
						)
					)
					var edges: Dictionary = (
						edges_raw as Dictionary
						if typeof(edges_raw) == TYPE_DICTIONARY
						else {}
					)

					job [
						"faction_current_id"
					] = faction_id
					job [
						"faction_edge_keys"
					] = edges.keys()
					job [
						"faction_edge_cursor"
					] = 0
					job [
						"faction_contested_claims"
					] = 0
					job [
						"faction_claim_pressure"
					] = 0.0
					job [
						"faction_hidden_instability"
					] = 0.0
				else:
					var edge_keys: Array = (
						job.get(
							"faction_edge_keys",
							[]
						) as Array
					)
					var edge_cursor: int = int(
						job.get(
							"faction_edge_cursor",
							0
						)
					)

					if edge_cursor < edge_keys.size():
						var edges_raw: Variant = (
							gs.universal_faction_engine.relationship_graph.get(
								faction_id,
								{}
							)
						)
						var edges: Dictionary = (
							edges_raw as Dictionary
							if typeof(edges_raw) == TYPE_DICTIONARY
							else {}
						)
						var edge_raw: Variant = (
							edges.get(
								edge_keys [
									edge_cursor
								],
								{}
							)
						)

						job [
							"faction_edge_cursor"
						] = edge_cursor + 1

						if typeof(edge_raw) == TYPE_DICTIONARY:
							var edge: Dictionary = (
								edge_raw as Dictionary
							)

							job [
								"faction_contested_claims"
							] = int(
								job.get(
									"faction_contested_claims",
									0
								)
							) + int(
								edge.get(
									"contested_claims",
									0
								)
							)

							job [
								"faction_claim_pressure"
							] = float(
								job.get(
									"faction_claim_pressure",
									0.0
								)
							) + float(
								edge.get(
									"claim_pressure",
									0.0
								)
							)

							if bool(
								edge.get(
									"contested_hidden_realm",
									false
								)
							):
								job [
									"faction_hidden_instability"
								] = float(
									job.get(
										"faction_hidden_instability",
										0.0
									)
								) + 1.0 + (
									float(
										edge.get(
											"hostility",
											0.0
										)
									) * 0.05
								)
					else:
						var faction_raw: Variant = (
							gs.universal_faction_engine.faction_registry.get(
								faction_id,
								{}
							)
						)
						var profile_raw: Variant = (
							gs.universal_faction_engine.pressure_model.get(
								faction_id,
								{}
							)
						)
						var faction: Dictionary = (
							faction_raw as Dictionary
							if typeof(faction_raw) == TYPE_DICTIONARY
							else {}
						)
						var profile: Dictionary = (
							profile_raw as Dictionary
							if typeof(profile_raw) == TYPE_DICTIONARY
							else {}
						)
						var pressure_value: float = float(
							profile.get(
								"pressure",
								0.0
							)
						)
						var hostility_value: float = float(
							profile.get(
								"hostility",
								0.0
							)
						)
						var legitimacy_value: float = float(
							profile.get(
								"legitimacy",
								0.0
							)
						)
						var faction_row: Dictionary = {
							"name": str(
								faction.get(
									"name",
									"Faction"
								)
							),
							"kind": str(
								faction.get(
									"kind",
									"faction"
								)
							),
							"pressure": pressure_value,
							"legitimacy": legitimacy_value,
							"hostility": hostility_value,
							"claim_pressure": float(
								job.get(
									"faction_claim_pressure",
									0.0
								)
							),
							"contested_claims": int(
								job.get(
									"faction_contested_claims",
									0
								)
							),
							"hidden_instability": float(
								job.get(
									"faction_hidden_instability",
									0.0
								)
							)
						}
						faction_row [
							"sort_value"
						] = (
							pressure_value
							+ float(
								faction_row [
									"claim_pressure"
								]
							)
							+ (
								hostility_value
								* 0.15
							)
							+ (
								float(
									faction_row [
										"hidden_instability"
									]
								) * 6.0
							)
						)

						var faction_rows: Array = (
							job.get(
								"faction_rows",
								[]
							) as Array
						)
						faction_rows.append(
							faction_row
						)
						job [
							"faction_rows"
						] = faction_rows
						job [
							"faction_cursor"
						] = faction_cursor + 1
						job [
							"faction_current_id"
						] = ""

						patch = {
							"actor_id": actor_id,
							"patch_kind": "faction_row",
							"faction_row": faction_row
						}

		"complete":
			var property_rows: Array = (
				job.get(
					"property_rows",
					[]
				) as Array
			)
			var vehicle_rows: Array = (
				job.get(
					"vehicle_rows",
					[]
				) as Array
			)
			var faction_rows: Array = (
				job.get(
					"faction_rows",
					[]
				) as Array
			)

			faction_rows.sort_custom(
				func (
					left_raw: Variant,
					right_raw: Variant
				) -> bool:
					var left: Dictionary = (
						left_raw as Dictionary
					)
					var right: Dictionary = (
						right_raw as Dictionary
					)

					return float(
						left.get(
							"sort_value",
							0.0
						)
					) > float(
						right.get(
							"sort_value",
							0.0
						)
					)
			)

			if faction_rows.size() > 5:
				faction_rows = faction_rows.slice(
					0,
					5
				)

			var surface_contract: Dictionary = {
				"success": true,
				"schema": ASSETS_SURFACE_SCHEMA,
				"version": CONTRACT_VERSION,
				"actor_id": actor_id,
				"actor_name": _person_label(
					actor
				),
				"actor_age": int(
					actor.age
				),
				"title": "ASSETS • WEALTH",
				"subtitle": (
					"Property, mobility, wealth pressure, and market access for %s."
					% _person_label(
						actor
					)
				),
				"bank_balance": int(
					actor.bank_balance
				),
				"bank_balance_text": _format_money(
					int(
						actor.bank_balance
					)
				),
				"property_rollup": {
					"asset_count": property_rows.size(),
					"visible_property_count": property_rows.size(),
					"truth_state": "hot"
				},
				"vehicle_rollup": {
					"asset_count": vehicle_rows.size(),
					"vehicle_count": vehicle_rows.size(),
					"truth_state": "hot"
				},
				"property_asset_rows": property_rows,
				"vehicle_asset_rows": vehicle_rows,
				"faction_pressure_rows": faction_rows,
				"actions": _assets_observable_actions(),
				"markets_and_securities_text": (
					"Stocks, funds, commodities, crypto, businesses, and future wealth systems can join this contract without changing the panel."
				),
				"total_asset_count": (
					property_rows.size()
					+ vehicle_rows.size()
				),
				"truth_state": "observable",
				"surface_signature": job_key,
				"cache_hit": false,
				"ui_is_renderer_only": true,
				"created_at_ms": int(
					Time.get_ticks_msec()
				)
			}

			assets_surface_cache [
				job_key
			] = surface_contract.duplicate(
				false
			)
			last_report = surface_contract.duplicate(
				false
			)

			portfolio_observation_jobs.erase(
				job_key
			)

			return {
				"success": true,
				"complete": true,
				"actor_id": actor_id,
				"surface_patch": {
					"actor_id": actor_id,
					"patch_kind": "complete",
					"property_count": property_rows.size(),
					"vehicle_count": vehicle_rows.size(),
					"surface_contract": surface_contract
				},
				"assets_surface_contract": surface_contract,
				"ui_is_renderer_only": true
			}

	portfolio_observation_jobs [
		job_key
	] = job

	return {
		"success": true,
		"complete": false,
		"actor_id": actor_id,
		"phase": str(
			job.get(
				"phase",
				phase
			)
		),
		"surface_patch": patch,
		"ui_is_renderer_only": true
	}
func _reconcile_actor_property_control_truth(
	actor: Person,
	source: String
) -> Dictionary:
	if actor == null:
		return {}

	var report: Dictionary = {
		"success": true,
		"actor_id": int(actor.id),
		"changed_property_count": 0,
		"source": source,
		"spousal_property_control_reconciled": false,
		"household_property_visibility_reconciled": true,
		"minor_child_property_visibility_reconciled": true,
		"ui_is_renderer_only": true
	}

	if (
		gs != null
		and gs.property_engine != null
		and gs.property_engine.has_method(
			"reconcile_spousal_property_ownership_for_actor"
		)
	):
		var spousal_report: Dictionary = _safe_dictionary(
			gs.property_engine.reconcile_spousal_property_ownership_for_actor(
				actor,
				source
			)
		)
		for raw_key in spousal_report.keys():
			report [
				raw_key
			] = spousal_report [
				raw_key
			]
		report [
			"spousal_property_control_reconciled"
		] = true

	report [
		"household_property_visibility_reconciled"
	] = true
	report [
		"minor_child_property_visibility_reconciled"
	] = true
	report [
		"asset_visibility_law"
	] = (
		"owned_or_household_resident_or_minor_child_of_owner"
	)

	return report
func _ensure_asset_surface_authorities() -> void:
	if gs == null:
		return

	if gs.property_market_contract_engine == null:
		gs.property_market_contract_engine = (
			PropertyMarketContractEngine.new(
				gs
			)
		)

	if gs.dealership_contract_engine == null:
		gs.dealership_contract_engine = (
			DealershipContractEngine.new(
				gs
			)
		)

	if gs.property_makeover_contract_engine == null:
		gs.property_makeover_contract_engine = (
			PropertyMakeoverContractEngine.new(
				gs
			)
		)

	for raw_engine in [
		gs.property_market_contract_engine,
		gs.dealership_contract_engine,
		gs.property_makeover_contract_engine
	]:
		var engine = raw_engine

		if (
			engine != null
			and engine.has_method(
				"bind_game_state"
			)
		):
			engine.bind_game_state(
				gs
			)

	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		gs.scenario_state [
			"assets_surface_authorities_resident"
		] = true
		gs.scenario_state [
			"assets_surface_authorities_resident_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
func prewarm_actor_surface_pack(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	_ensure_asset_surface_authorities()

	if actor == null:
		return _failure(
			"missing_actor",
			context
		)

	var force_rebuild: bool = bool(
		context.get(
			"force_rebuild",
			false
		)
	)

	var ownership_report: Dictionary = (
		_reconcile_actor_property_control_truth(
			actor,
			str(
				context.get(
					"source",
					"assets_surface_pack_prewarm"
				)
			)
		)
	)

	if int(
		ownership_report.get(
			"changed_property_count",
			0
		)
	) > 0:
		force_rebuild = true

	var pack_key: String = _surface_pack_key(
		actor,
		context
	)

	if (
		not force_rebuild
		and surface_pack_cache.has(pack_key)
	):
		var cached: Dictionary = _safe_dictionary(
			surface_pack_cache.get(
				pack_key,
				{}
			)
		)

		if _surface_pack_is_crr_hot(
			cached,
			actor
		):
			cached ["cache_hit"] = true
			cached ["requested_at_ms"] = int(
				Time.get_ticks_msec()
			)
			cached ["authoritative_hot"] = true
			cached ["visible_click_work_required"] = (
				false
			)
			last_report = cached.duplicate(true)
			return cached



		surface_pack_cache.erase(pack_key)

	var assets_contract: Dictionary = (
		emit_assets_surface_contract(
			actor,
			{
				"source": str(
					context.get(
						"source",
						"assets_surface_pack_prewarm"
					)
				),
				"force_rebuild": force_rebuild,
				"prewarm_only": true,
				"visible_click_work_forbidden": (
					true
				)
			}
		)
	)
	var property_market_contract: Dictionary = (
		_property_market_surface_contract(
			actor,
			context
		)
	)
	var vehicle_market_contract: Dictionary = (
		_vehicle_market_surface_contract(
			actor,
			context
		)
	)
	var vehicle_market_surface_deck: Dictionary = {}

	if (
		gs != null
		and gs.dealership_contract_engine != null
		and gs.dealership_contract_engine.has_method(
			"emit_market_surface_deck"
		)
	):
		vehicle_market_surface_deck = (
			gs.dealership_contract_engine
			.emit_market_surface_deck(
				actor,
				{
					"source": (
						"assets_surface_pack_prewarm"
					),
					"force_rebuild": force_rebuild,
					"prewarm_only": true,
					"ui_is_renderer_only": true
				}
			)
		)
	if not _market_surface_contract_is_renderable(
		property_market_contract,
		"property"
	):
		property_market_contract = (
			_observable_market_contract(
				"property",
				actor
			)
		)

	if not _market_surface_contract_is_renderable(
		vehicle_market_contract,
		"vehicle"
	):
		vehicle_market_contract = (
			_observable_market_contract(
				"vehicle",
				actor
			)
		)

	assets_contract ["actor_id"] = int(
		actor.id
	)
	property_market_contract ["actor_id"] = int(
		actor.id
	)
	vehicle_market_contract ["actor_id"] = int(
		actor.id
	)

	var authoritative_hot: bool = (
		_market_surface_contract_is_crr_hot(
			property_market_contract,
			"property"
		)
		and _market_surface_contract_is_crr_hot(
			vehicle_market_contract,
			"vehicle"
		)
	)

	var pack: Dictionary = {
		"success": true,
		"schema": SURFACE_PACK_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"property_ownership_reconciliation": (
			ownership_report.duplicate(true)
		),
		"actor_age": int(actor.age),
		"bank_balance": int(
			actor.bank_balance
		),
		"vehicle_market_surface_deck": vehicle_market_surface_deck.duplicate(true),
		"era_key": _current_era_key(),
		"year": _current_year(),
		"assets_surface_contract": (
			assets_contract.duplicate(true)
		),
		"property_market_surface_contract": (
			property_market_contract.duplicate(true)
		),
		"vehicle_market_surface_contract": (
			vehicle_market_contract.duplicate(true)
		),
		"surface_signature": pack_key,
		"prewarmed": true,
		"authoritative_hot": authoritative_hot,
		"truth_state": (
			"hot"
			if authoritative_hot
			else "observable_partial"
		),
		"visible_click_work_required": false,
		"visible_click_work_forbidden": true,
		"ui_is_renderer_only": true,
		"created_at_ms": int(
			Time.get_ticks_msec()
		),
		"cache_hit": false
	}

	surface_pack_cache [pack_key] = (
		pack.duplicate(true)
	)
	_commit_state()
	last_report = pack.duplicate(true)
	return pack

func prewarm_property_space_surface_for_actor(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	_ensure_asset_surface_authorities()

	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor",
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	var actor_id: int = int(
		actor.id
	)
	var property_id: int = int(
		payload.get(
			"property_id",
			-1
		)
	)

	if property_id <= 0:
		return {
			"success": false,
			"reason": "missing_property_id",
			"actor_id": actor_id,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}
	var surface_kind: String = str(
		payload.get(
			"surface_kind",
			"both"
		)
	).strip_edges().to_lower()

	if surface_kind not in [
		"interior",
		"makeover",
		"both"
	]:
		surface_kind = "both"
	if (
		gs == null
		or gs.property_makeover_contract_engine == null
		or not gs.property_makeover_contract_engine.has_method(
			"emit_property_space_contract"
		)
		or not gs.property_makeover_contract_engine.has_method(
			"emit_makeover_surface_contract"
		)
	):
		return {
			"success": false,
			"reason": "property_destination_contract_authority_unavailable",
			"actor_id": actor_id,
			"property_id": property_id,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}

	var property_owner_id: int = int(
		payload.get(
			"property_owner_id",
			actor_id
		)
	)
	var source: String = str(
		payload.get(
			"source",
			"assets_contract_engine.property_destination_prewarm"
		)
	)
	var interior_contract: Dictionary = {}
	var makeover_contract: Dictionary = {}

	if surface_kind in [
		"interior",
		"both"
	]:
		interior_contract = _safe_dictionary(
			gs.property_makeover_contract_engine
			.emit_property_space_contract(
				actor,
				{
					"actor_id": actor_id,
					"property_owner_id": property_owner_id,
					"property_id": property_id,
					"mode": "interior",
					"status_text": str(
						payload.get(
							"status_text",
							(
								"You enter through the front door "
								+ "and close it behind you."
							)
						)
					),
					"source": source,
					"prewarm_only": true,
					"read_only": true,
					"visible_click_work_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)

	if surface_kind in [
		"makeover",
		"both"
	]:
		makeover_contract = _safe_dictionary(
			gs.property_makeover_contract_engine
			.emit_makeover_surface_contract(
				actor,
				{
					"actor_id": actor_id,
					"property_owner_id": property_owner_id,
					"property_id": property_id,
					"mode": "makeover",
					"status_text": "",
					"source": source,
					"prewarm_only": true,
					"read_only": true,
					"visible_click_work_forbidden": true,
					"ready_gate_member": false,
					"ui_is_renderer_only": true
				}
			)
		)
	var interior_hot: bool = (
		not interior_contract.is_empty()
		and bool(
			interior_contract.get(
				"success",
				false
			)
		)
		and int(
			interior_contract.get(
				"property_id",
				-1
			)
		) == property_id
	)
	var makeover_hot: bool = (
		not makeover_contract.is_empty()
		and bool(
			makeover_contract.get(
				"success",
				false
			)
		)
		and int(
			makeover_contract.get(
				"property_id",
				-1
			)
		) == property_id
	)

	if interior_hot:
		interior_contract ["actor_id"] = actor_id
		interior_contract ["property_id"] = property_id
		interior_contract ["property_owner_id"] = property_owner_id
		interior_contract ["prewarmed"] = true
		interior_contract ["visible_click_work_required"] = false
		interior_contract ["visible_click_work_forbidden"] = true
		interior_contract ["ready_gate_member"] = false
		interior_contract ["ui_is_renderer_only"] = true

	if makeover_hot:
		makeover_contract ["actor_id"] = actor_id
		makeover_contract ["property_id"] = property_id
		makeover_contract ["property_owner_id"] = property_owner_id
		makeover_contract ["prewarmed"] = true
		makeover_contract ["visible_click_work_required"] = false
		makeover_contract ["visible_click_work_forbidden"] = true
		makeover_contract ["ready_gate_member"] = false
		makeover_contract ["ui_is_renderer_only"] = true

	if (
		interior_hot
		or makeover_hot
	):
		for raw_pack_key in surface_pack_cache.keys():
			var pack_key: String = str(
				raw_pack_key
			)
			var pack: Dictionary = _safe_dictionary(
				surface_pack_cache.get(
					raw_pack_key,
					{}
				)
			)

			if int(
				pack.get(
					"actor_id",
					-1
				)
			) != actor_id:
				continue

			var interior_by_id: Dictionary = _safe_dictionary(
				pack.get(
					"property_space_surface_contracts_by_id",
					{}
				)
			)
			var makeover_by_id: Dictionary = _safe_dictionary(
				pack.get(
					"property_makeover_surface_contracts_by_id",
					{}
				)
			)

			if interior_hot:
				interior_by_id [
					str(property_id)
				] = interior_contract.duplicate(true)

			if makeover_hot:
				makeover_by_id [
					str(property_id)
				] = makeover_contract.duplicate(true)

			pack [
				"property_space_surface_contracts_by_id"
			] = interior_by_id
			pack [
				"property_makeover_surface_contracts_by_id"
			] = makeover_by_id
			pack [
				"property_space_surface_contracts_actor_id"
			] = actor_id
			pack [
				"property_makeover_surface_contracts_actor_id"
			] = actor_id
			pack [
				"property_space_surface_contracts_ready_gate_member"
			] = false
			pack [
				"property_makeover_surface_contracts_ready_gate_member"
			] = false
			pack [
				"property_space_surface_contracts_build_on_click"
			] = false
			pack [
				"property_makeover_surface_contracts_build_on_click"
			] = false
			surface_pack_cache [
				pack_key
			] = pack.duplicate(true)



	return {
		"success": (
			interior_hot
			if surface_kind == "interior"
			else (
				makeover_hot
				if surface_kind == "makeover"
				else (
					interior_hot
					and makeover_hot
				)
			)
		),
		"schema": "eralife.assets.property_destination_prewarm_report",
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"property_owner_id": property_owner_id,
		"property_id": property_id,
		"property_space_surface_contract": (
			interior_contract.duplicate(true)
		),
		"property_makeover_surface_contract": (
			makeover_contract.duplicate(true)
		),
		"interior_surface_hot": interior_hot,
		"makeover_surface_hot": makeover_hot,
		"surface_kind": surface_kind,
		"property_destination_hot": (
			interior_hot
			and makeover_hot
		),
		"visible_click_work_required": false,
		"visible_click_work_forbidden": true,
		"ready_gate_member": false,
		"ui_is_renderer_only": true,
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _property_asset_row_from_dictionary(
	source_row: Dictionary,
	actor: Person,
	visibility_reason: String
) -> Dictionary:
	if source_row.is_empty():
		return {}

	var asset_id: int = int(
		source_row.get(
			"asset_id",
			source_row.get(
				"property_id",
				source_row.get(
					"id",
					-1
				)
			)
		)
	)

	if asset_id <= 0:
		return {}

	var display_name: String = str(
		source_row.get(
			"display_name",
			source_row.get(
				"name",
				source_row.get(
					"nickname",
					source_row.get(
						"type",
						"Property"
					)
				)
			)
		)
	).strip_edges()

	if display_name == "":
		display_name = "Property %d" % asset_id

	var owner_id: int = int(
		source_row.get(
			"owner_id",
			source_row.get(
				"controlled_actor_id",
				(
					int(actor.id)
					if actor != null
					else -1
				)
			)
		)
	)
	var legal_owner_ids: Array = _safe_array(
		source_row.get(
			"legal_owner_ids",
			source_row.get(
				"owners",
				[]
			)
		)
	)

	if (
		owner_id > 0
		and owner_id not in legal_owner_ids
	):
		legal_owner_ids.append(
			owner_id
		)

	if (
		actor != null
		and int(actor.id) > 0
		and legal_owner_ids.is_empty()
	):
		legal_owner_ids.append(
			int(actor.id)
		)

	return {
		"asset_id": asset_id,
		"property_id": asset_id,
		"id": asset_id,
		"display_name": display_name,
		"name": display_name,
		"address": str(
			source_row.get(
				"address",
				source_row.get(
					"location",
					"Unknown Address"
				)
			)
		),
		"asset_kind": "property",
		"category": "Real Estate",
		"property_type": str(
			source_row.get(
				"property_type",
				source_row.get(
					"type",
					"Property"
				)
			)
		),
		"condition": int(
			source_row.get(
				"condition",
				100
			)
		),
		"condition_label": str(
			source_row.get(
				"condition_label",
				"Excellent"
			)
		),
		"value": int(
			source_row.get(
				"value",
				source_row.get(
					"price",
					0
				)
			)
		),
		"legal_owner_ids": legal_owner_ids,
		"owner_id": (
			owner_id
			if owner_id > 0
			else (
				int(actor.id)
				if actor != null
				else -1
			)
		),
		"visible_to_actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"controlled_by_viewer": (
			actor != null
			and int(
				actor.id
			) in legal_owner_ids
		),
		"observable_asset_access": true,
		"visibility_reason": visibility_reason,
		"resident_asset_contract": true,
		"visible_click_work_forbidden": true,
		"ui_is_renderer_only": true
	}
func _append_visible_property_asset_row(
	source_row: Dictionary,
	actor: Person,
	visibility_reason: String,
	force_owner_id: int,
	visible_rows: Array,
	seen_ids: Dictionary
) -> bool:
	if actor == null:
		return false

	var actor_id: int = int(
		actor.id
	)

	var row: Dictionary = (
		_property_asset_row_from_dictionary(
			source_row,
			actor,
			visibility_reason
		)
	)

	if row.is_empty():
		return false

	var asset_id: int = int(
		row.get(
			"asset_id",
			-1
		)
	)

	if asset_id <= 0:
		return false

	if seen_ids.has(
		asset_id
	):
		return false

	if force_owner_id > 0:
		row [
			"owner_id"
		] = force_owner_id

	row [
		"visible_to_actor_id"
	] = actor_id
	row [
		"observable_asset_access"
	] = true
	row [
		"resident_asset_contract"
	] = true



	row [
		"enter_and_view_hot"
	] = false
	row [
		"property_destination_truth_state"
	] = "resolving"
	row [
		"property_destination_build_on_click"
	] = false
	row [
		"property_destination_ready_gate_member"
	] = false

	row [
		"visible_click_work_forbidden"
	] = true
	row [
		"ui_is_renderer_only"
	] = true

	visible_rows.append(
		row
	)

	seen_ids [
		asset_id
	] = true

	return true
func _visible_property_portfolio_payload_for_actor(
	actor: Person,
	_context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"rollup": {},
			"asset_rows": []
		}

	var actor_id: int = int(
		actor.id
	)
	var direct_payload: Dictionary = {
		"rollup": {},
		"asset_rows": []
	}

	if (
		gs != null
		and gs.property_engine != null
		and gs.property_engine.has_method(
			"get_property_portfolio_panel_payload"
		)
	):
		direct_payload = _safe_dictionary(
			gs.property_engine.get_property_portfolio_panel_payload(
				actor
			)
		)

	var visible_rows: Array = []
	var seen_ids: Dictionary = {}

	for raw_row in _safe_array(
		direct_payload.get(
			"asset_rows",
			[]
		)
	):
		_append_visible_property_asset_row(
			_safe_dictionary(raw_row),
			actor,
			"direct_property_portfolio",
			-1,
			visible_rows,
			seen_ids
		)

	var actor_parent_ids: Array = _safe_array(
		actor.get("parents")
		if actor.get("parents") != null
		else []
	)
	var actor_household_ids: Array = _safe_array(
		actor.get("household_member_ids")
		if actor.get("household_member_ids") != null
		else []
	)

	if (
		gs != null
		and gs.property_engine != null
		and typeof(
			gs.property_engine.get(
				"properties"
			)
		) == TYPE_DICTIONARY
	):
		var property_store: Dictionary = gs.property_engine.get(
			"properties"
		)

		for raw_bucket_id in property_store.keys():
			var bucket_owner_id: int = int(raw_bucket_id)

			for raw_property in _safe_array(
				property_store.get(
					raw_bucket_id,
					[]
				)
			):
				var property_data: Dictionary = _safe_dictionary(
					raw_property
				)

				if property_data.is_empty():
					continue

				var legal_owner_ids: Array = _safe_array(
					property_data.get(
						"owners",
						property_data.get(
							"legal_owner_ids",
							[]
						)
					)
				)
				var control_roles: Dictionary = _safe_dictionary(
					property_data.get(
						"control_roles",
						{}
					)
				)
				var control_owner_ids: Array = _safe_array(
					control_roles.get(
						"owner_ids",
						[]
					)
				)
				var resident_ids: Array = _safe_array(
					property_data.get(
						"resident_ids",
						property_data.get(
							"occupant_ids",
							property_data.get(
								"household_member_ids",
								[]
							)
						)
					)
				)
				var tenant_ids: Array = _safe_array(
					property_data.get(
						"tenant_ids",
						[]
					)
				)

				var actor_can_observe_property: bool = (
					bucket_owner_id == actor_id
					or actor_id in legal_owner_ids
					or actor_id in control_owner_ids
					or actor_id in resident_ids
					or actor_id in tenant_ids
					or bucket_owner_id in actor_parent_ids
					or bucket_owner_id in actor_household_ids
				)

				if not actor_can_observe_property:
					continue

				var reason: String = "household_or_resident_property"

				if (
					bucket_owner_id == actor_id
					or actor_id in legal_owner_ids
					or actor_id in control_owner_ids
				):
					reason = "direct_property_store"
				elif actor_id in resident_ids:
					reason = "resident_of_property"
				elif actor_id in tenant_ids:
					reason = "tenant_of_property"
				elif bucket_owner_id in actor_parent_ids:
					reason = "child_or_household_under_owner"
				elif bucket_owner_id in actor_household_ids:
					reason = "co_resident_with_owner"

				_append_visible_property_asset_row(
					property_data,
					actor,
					reason,
					bucket_owner_id,
					visible_rows,
					seen_ids
				)

	if (
		gs != null
		and gs.belongings_engine != null
		and gs.belongings_engine.has_method(
			"get_category_items"
		)
	):
		for category_name in [
			"Real Estate",
			"Property",
			"Properties"
		]:
			for raw_item in _safe_array(
				gs.belongings_engine.get_category_items(
					actor,
					category_name
				)
			):
				var item: Dictionary = _safe_dictionary(
					raw_item
				)
				var asset_kind: String = str(
					item.get(
						"asset_kind",
						item.get(
							"category",
							""
						)
					)
				).strip_edges().to_lower()

				if (
					asset_kind != "property"
					and category_name != "Real Estate"
				):
					continue

				_append_visible_property_asset_row(
					item,
					actor,
					"resident_belongings_projection",
					-1,
					visible_rows,
					seen_ids
				)

	var rollup: Dictionary = _safe_dictionary(
		direct_payload.get(
			"rollup",
			{}
		)
	)
	rollup ["visible_property_count"] = visible_rows.size()
	rollup ["direct_or_household_property_count"] = visible_rows.size()
	rollup ["asset_count"] = visible_rows.size()
	rollup ["truth_state"] = "hot"
	rollup ["visibility_law"] = (
		"owned_or_controlled_or_resident_or_tenant_or_household_or_belongings_projection"
	)

	return {
		"rollup": rollup,
		"asset_rows": visible_rows,
		"truth_state": "hot",
		"visible_click_work_forbidden": true,
		"ui_is_renderer_only": true
	}
func emit_assets_surface_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	if actor == null:
		return _failure(
			"missing_actor",
			context
		)

	var force_rebuild: bool = bool(
		context.get(
			"force_rebuild",
			false
		)
	)

	var ownership_report: Dictionary = (
		_reconcile_actor_property_control_truth(
			actor,
			str(
				context.get(
					"source",
					"assets_surface_contract"
				)
			)
		)
	)

	if int(
		ownership_report.get(
			"changed_property_count",
			0
		)
	) > 0:
		force_rebuild = true

	var cache_key: String = _assets_surface_key(
		actor
	)

	if (
		not force_rebuild
		and assets_surface_cache.has(cache_key)
	):
		var cached: Dictionary = _safe_dictionary(
			assets_surface_cache.get(
				cache_key,
				{}
			)
		)
		cached ["cache_hit"] = true
		cached ["requested_at_ms"] = int(
			Time.get_ticks_msec()
		)
		last_report = cached.duplicate(true)
		return cached

	var property_payload: Dictionary = {
		"rollup": {},
		"asset_rows": []
	}
	var vehicle_payload: Dictionary = {
		"rollup": {},
		"asset_rows": []
	}

	property_payload = (
		_visible_property_portfolio_payload_for_actor(
			actor,
			context
		)
	)

	if gs != null and gs.vehicle_engine != null:
		vehicle_payload = (
			gs.vehicle_engine
			.get_vehicle_portfolio_panel_payload(
				actor
			)
		)

	var property_rows: Array = _safe_array(
		property_payload.get(
			"asset_rows",
			[]
		)
	)
	var vehicle_rows: Array = _safe_array(
		vehicle_payload.get(
			"asset_rows",
			[]
		)
	)
	var actions: Array = [
		{
			"action_id": "look_for_property",
			"label": "Look For Property",
			"icon": "🏠",
			"disabled": false,
			"intent_mode": "reveal_resident_surface",
			"destination_surface": "property_market_contract_panel",
			"visible_click_work_forbidden": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		},
		{
			"action_id": "look_for_vehicles",
			"label": "Look For Vehicles",
			"icon": "🚗",
			"disabled": false,
			"intent_mode": "reveal_resident_surface",
			"destination_surface": "vehicle_market_contract_panel",
			"visible_click_work_forbidden": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		},
		{
			"action_id": "look_for_creatures",
			"label": "Look For Creatures",
			"icon": " ",
			"disabled": false,
			"intent_mode": "reveal_resident_surface",
			"destination_surface": "pet_shop_contract_panel",
			"visible_click_work_forbidden": true,
			"ready_gate_member": false,
			"ui_is_renderer_only": true
		}
	]

	var surface_contract: Dictionary = {
		"success": true,
		"schema": ASSETS_SURFACE_SCHEMA,
		"version": CONTRACT_VERSION,
		"actor_id": int(actor.id),
		"actor_name": _person_label(actor),
		"actor_age": int(actor.age),
		"title": "ASSETS • WEALTH",
		"subtitle": "Property, mobility, wealth pressure, and market access for %s." % _person_label(actor),
		"bank_balance": int(actor.bank_balance),
		"bank_balance_text": _format_money(
			int(actor.bank_balance)
		),
		"property_rollup": _safe_dictionary(
			property_payload.get(
				"rollup",
				{}
			)
		),
		"property_ownership_reconciliation": (
			ownership_report.duplicate(true)
		),
		"spousal_property_control_reconciled": true,
		"vehicle_rollup": _safe_dictionary(
			vehicle_payload.get(
				"rollup",
				{}
			)
		),
		"property_asset_rows": property_rows,
		"vehicle_asset_rows": vehicle_rows,
		"faction_pressure_rows": _faction_pressure_rows(
			actor
		),
		"actions": actions,
		"markets_and_securities_text": "Stocks, funds, commodities, crypto, businesses, and future wealth systems can join this contract without changing the panel.",
		"total_asset_count": (
			property_rows.size()
			+ vehicle_rows.size()
		),
		"truth_state": "observable",
		"surface_signature": cache_key,
		"cache_hit": false,
		"ui_is_renderer_only": true,
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	assets_surface_cache [cache_key] = (
		surface_contract.duplicate(true)
	)
	_commit_state()
	last_report = surface_contract.duplicate(true)
	return surface_contract
func _market_surface_contract_is_renderable(
	surface_contract: Dictionary,
	market_kind: String
) -> bool:
	if surface_contract.is_empty():
		return false

	var cards: Array = _safe_array(
		surface_contract.get(
			"listing_card_contracts",
			[]
		)
	)

	if not cards.is_empty():
		return true

	if (
		str(market_kind).to_lower() == "vehicle"
		and str(
			surface_contract.get(
				"surface_mode",
				""
			)
		) == "dealership_selector"
	):
		return not _safe_array(
			surface_contract.get(
				"dealership_contracts",
				[]
			)
		).is_empty()

	return false


func _market_surface_contract_is_crr_hot(
	surface_contract: Dictionary,
	market_kind: String
) -> bool:
	if not _market_surface_contract_is_renderable(
		surface_contract,
		market_kind
	):
		return false

	if not bool(
		surface_contract.get(
			"success",
			false
		)
	):
		return false

	return str(
		surface_contract.get(
			"truth_state",
			""
		)
	).to_lower() not in [
		"",
		"observable_partial",
		"missing_surface_contract",
		"resolving",
		"cold"
	]


func _surface_pack_is_crr_hot(
	pack: Dictionary,
	actor: Person
) -> bool:
	if (
		pack.is_empty()
		or actor == null
	):
		return false

	var actor_id: int = int(
		actor.id
	)

	if int(
		pack.get(
			"actor_id",
			-1
		)
	) != actor_id:
		return false

	var assets_contract: Dictionary = _safe_dictionary(
		pack.get(
			"assets_surface_contract",
			{}
		)
	)
	var property_contract: Dictionary = _safe_dictionary(
		pack.get(
			"property_market_surface_contract",
			{}
		)
	)
	var vehicle_contract: Dictionary = _safe_dictionary(
		pack.get(
			"vehicle_market_surface_contract",
			{}
		)
	)
	var assets_hot: bool = (
		not assets_contract.is_empty()
		and bool(
			assets_contract.get(
				"success",
				false
			)
		)
		and int(
			assets_contract.get(
				"actor_id",
				-1
			)
		) == actor_id
		and str(
			assets_contract.get(
				"truth_state",
				""
			)
		).strip_edges().to_lower() not in [
			"",
			"cold",
			"resolving",
			"observable_partial"
		]
	)
	var property_hot: bool = (
		_market_surface_contract_is_crr_hot(
			property_contract,
			"property"
		)
	)
	var vehicle_hot: bool = (
		_market_surface_contract_is_crr_hot(
			vehicle_contract,
			"vehicle"
		)
	)

	return (
		assets_hot
		and property_hot
		and vehicle_hot
	)
func cached_surface_pack_for_actor(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {}

	var key: String = _surface_pack_key(
		actor,
		context
	)

	return _safe_dictionary(
		surface_pack_cache.get(
			key,
			{}
		)
	)


func cache_market_surface_contract(
	actor: Person,
	market_kind: String,
	surface_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null or surface_contract.is_empty():
		return {}

	var key: String = _surface_pack_key(
		actor,
		context
	)
	var pack: Dictionary = _safe_dictionary(
		surface_pack_cache.get(
			key,
			{}
		)
	)

	if pack.is_empty():
		pack = prewarm_actor_surface_pack(
			actor,
			{
				"source": "assets_cache_market_surface_contract",
				"force_rebuild": false
			}
		)

	var clean_kind: String = str(
		market_kind
	).strip_edges().to_lower()

	if clean_kind == "property":
		pack ["property_market_surface_contract"] = (
			surface_contract.duplicate(true)
		)
	elif clean_kind == "vehicle":
		pack ["vehicle_market_surface_contract"] = (
			surface_contract.duplicate(true)
		)

	pack ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)
	pack ["cache_hit"] = false
	surface_pack_cache [key] = pack.duplicate(true)
	_commit_state()
	return pack


func invalidate_actor(
	actor_id: int,
	reason: String = "assets_truth_changed"
) -> Dictionary:
	var removed_assets: int = 0
	var removed_packs: int = 0
	var prefix: String = "%d|" % int(actor_id)

	for raw_key in assets_surface_cache.keys().duplicate():
		var key: String = str(raw_key)

		if key.begins_with(prefix):
			assets_surface_cache.erase(raw_key)
			removed_assets += 1

	for raw_key in surface_pack_cache.keys().duplicate():
		var key: String = str(raw_key)

		if key.begins_with(prefix):
			surface_pack_cache.erase(raw_key)
			removed_packs += 1

	_commit_state()

	return {
		"success": true,
		"schema": "eralife.assets.cache_invalidation_report",
		"actor_id": int(actor_id),
		"reason": reason,
		"removed_assets_surfaces": removed_assets,
		"removed_surface_packs": removed_packs,
		"invalidated_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func _property_market_surface_contract(
	actor: Person,
	context: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.property_market_contract_engine == null
		or not gs.property_market_contract_engine.has_method(
			"emit_market_surface_contract"
		)
	):
		return _observable_market_contract(
			"property",
			actor
		)

	var request_context: Dictionary = context.duplicate(true)
	request_context ["source"] = str(
		context.get(
			"source",
			"assets_contract_property_market_prewarm"
		)
	)
	request_context ["prewarm_only"] = true
	request_context ["ui_is_renderer_only"] = true
	request_context ["generic_resident_market_fallback_forbidden"] = true
	request_context ["authoritative_market_surface_required"] = true

	var surface: Dictionary = _safe_dictionary(
		gs.property_market_contract_engine.emit_market_surface_contract(
			actor,
			request_context
		)
	)

	if surface.is_empty():
		return _observable_market_contract(
			"property",
			actor
		)

	surface ["generic_resident_market_fallback_forbidden"] = true
	surface ["authoritative_market_surface_required"] = true
	surface ["ui_is_renderer_only"] = true

	return surface

func _vehicle_market_surface_contract(
	actor: Person,
	context: Dictionary
) -> Dictionary:
	if (
		gs == null
		or gs.dealership_contract_engine == null
		or not gs.dealership_contract_engine.has_method(
			"emit_market_surface_contract"
		)
	):
		return _observable_market_contract(
			"vehicle",
			actor
		)

	var request_context: Dictionary = context.duplicate(true)
	request_context ["source"] = str(
		context.get(
			"source",
			"assets_contract_vehicle_market_prewarm"
		)
	)
	request_context ["prewarm_only"] = true
	request_context ["ui_is_renderer_only"] = true
	request_context ["generic_resident_market_fallback_forbidden"] = true
	request_context ["authoritative_market_surface_required"] = true

	var surface: Dictionary = _safe_dictionary(
		gs.dealership_contract_engine.emit_market_surface_contract(
			actor,
			request_context
		)
	)

	if surface.is_empty():
		return _observable_market_contract(
			"vehicle",
			actor
		)

	surface ["generic_resident_market_fallback_forbidden"] = true
	surface ["authoritative_market_surface_required"] = true
	surface ["ui_is_renderer_only"] = true

	return surface
func prewarm_actor_portfolio_surface(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()
	_ensure_asset_surface_authorities()

	if actor == null:
		return _failure(
			"missing_actor",
			context
		)

	var assets_contract: Dictionary = (
		emit_assets_surface_contract(
			actor,
			{
				"source": str(
					context.get(
						"source",
						"assets_portfolio_surface_prewarm"
					)
				),
				"force_rebuild": bool(
					context.get(
						"force_rebuild",
						false
					)
				),
				"prewarm_only": true,
				"visible_click_work_forbidden": true,
				"ready_gate_member": false,
				"ui_is_renderer_only": true
			}
		)
	)
	var portfolio_hot: bool = (
		not assets_contract.is_empty()
		and bool(
			assets_contract.get(
				"success",
				false
			)
		)
		and int(
			assets_contract.get(
				"actor_id",
				-1
			)
		) == int(
			actor.id
		)
	)

	return {
		"success": portfolio_hot,
		"schema": (
			"eralife.assets.portfolio_residency_packet"
		),
		"version": CONTRACT_VERSION,
		"actor_id": int(
			actor.id
		),
		"actor_name": _person_label(
			actor
		),
		"assets_surface_contract": (
			assets_contract.duplicate(false)
		),
		"portfolio_hot": portfolio_hot,
		"property_market_surface_contract": {},
		"vehicle_market_surface_contract": {},
		"vehicle_market_surface_deck": {},
		"ready_gate_member": false,
		"visible_click_work_required": false,
		"visible_click_work_forbidden": true,
		"ui_is_renderer_only": true,
		"created_at_ms": int(
			Time.get_ticks_msec()
		)
	}
func _asset_catalog_expansion() -> Object:
	if gs == null:
		return null

	if gs.era_life_asset_catalog_expansion == null:
		return null

	if not (gs.era_life_asset_catalog_expansion is Object):
		return null

	return gs.era_life_asset_catalog_expansion as Object


func _observable_market_contract(
	market_kind: String,
	actor: Person = null
) -> Dictionary:
	var clean_market_kind: String = str(
		market_kind
	).strip_edges().to_lower()
	var is_property_market: bool = (
		clean_market_kind == "property"
	)
	var actor_id: int = (
		int(actor.id)
		if actor != null
		else -1
	)
	var label: String = (
		"PROPERTY MARKET"
		if is_property_market
		else "VEHICLE MARKET"
	)

	return {
		"success": false,
		"schema": (
			"eralife.market.property_market.surface_contract"
			if is_property_market
			else "eralife.market.vehicle_market.surface_contract"
		),
		"version": CONTRACT_VERSION,
		"actor_id": actor_id,
		"surface_mode": (
			"inventory"
			if is_property_market
			else "dealership_selector"
		),
		"title": label,
		"subtitle": (
			"Authoritative %s market surface is not resident."
			% clean_market_kind
		),
		"status_text": (
			"Generic resident-market fallback is retired. "
			+ "Only PropertyMarketContractEngine / DealershipContractEngine "
			+ "surfaces may render here."
		),
		"listing_card_contracts": [],
		"listing_count": 0,
		"filter_contracts": [],
		"dealership_contracts": [],
		"truth_state": "missing_authoritative_market_surface",
		"surface_signature": (
			"retired_generic_market_surface|%s|%d"
			% [
				clean_market_kind,
				actor_id
			]
		),
		"crr_fallback": true,
		"retired_fake_generic_market_surface": true,
		"catalog_authority": "",
		"blank_surface_impossible": true,
		"visible_click_work_required": false,
		"visible_click_work_forbidden": true,
		"ready_gate_member": false,
		"ui_is_renderer_only": true,
		"created_at_ms": int(Time.get_ticks_msec())
	}
func _faction_pressure_rows(
	actor: Person
) -> Array:
	var out: Array = []

	if (
		gs == null
		or actor == null
		or gs.universal_faction_engine == null
	):
		return out

	var faction_state: Dictionary = (
		gs.universal_faction_engine
		.export_state()
	)
	var membership_index: Dictionary = _safe_dictionary(
		faction_state.get(
			"membership_index",
			{}
		)
	)
	var pressure_model: Dictionary = _safe_dictionary(
		faction_state.get(
			"pressure_model",
			{}
		)
	)
	var relationship_graph: Dictionary = _safe_dictionary(
		faction_state.get(
			"relationship_graph",
			{}
		)
	)
	var faction_registry: Dictionary = _safe_dictionary(
		faction_state.get(
			"faction_registry",
			{}
		)
	)
	var memberships: Dictionary = _safe_dictionary(
		membership_index.get(
			str(int(actor.id)),
			{}
		)
	)

	for raw_faction_id in memberships.keys():
		var faction_id: String = str(
			raw_faction_id
		)
		var faction: Dictionary = _safe_dictionary(
			faction_registry.get(
				faction_id,
				{}
			)
		)
		var profile: Dictionary = _safe_dictionary(
			pressure_model.get(
				faction_id,
				{}
			)
		)
		var edges: Dictionary = _safe_dictionary(
			relationship_graph.get(
				faction_id,
				{}
			)
		)

		var contested_claims: int = 0
		var claim_pressure: float = 0.0
		var hidden_instability: float = 0.0

		for raw_other_id in edges.keys():
			var edge: Dictionary = _safe_dictionary(
				edges.get(
					raw_other_id,
					{}
				)
			)

			contested_claims += int(
				edge.get(
					"contested_claims",
					0
				)
			)
			claim_pressure += float(
				edge.get(
					"claim_pressure",
					0.0
				)
			)

			if bool(
				edge.get(
					"contested_hidden_realm",
					false
				)
			):
				hidden_instability += (
					1.0
					+ (
						float(
							edge.get(
								"hostility",
								0.0
							)
						)
						* 0.05
					)
				)

		var pressure_value: float = float(
			profile.get(
				"pressure",
				0.0
			)
		)
		var hostility_value: float = float(
			profile.get(
				"hostility",
				0.0
			)
		)
		var legitimacy_value: float = float(
			profile.get(
				"legitimacy",
				0.0
			)
		)

		out.append({
			"name": str(
				faction.get(
					"name",
					"Faction"
				)
			),
			"kind": str(
				faction.get(
					"kind",
					"faction"
				)
			),
			"pressure": pressure_value,
			"legitimacy": legitimacy_value,
			"hostility": hostility_value,
			"claim_pressure": claim_pressure,
			"contested_claims": contested_claims,
			"hidden_instability": hidden_instability,
			"sort_value": (
				pressure_value
				+ claim_pressure
				+ (hostility_value * 0.15)
				+ (hidden_instability * 6.0)
			)
		})

	out.sort_custom(func (
		left_raw: Variant,
		right_raw: Variant
	) -> bool:
		var left: Dictionary = _safe_dictionary(
			left_raw
		)
		var right: Dictionary = _safe_dictionary(
			right_raw
		)

		return float(
			left.get(
				"sort_value",
				0.0
			)
		) > float(
			right.get(
				"sort_value",
				0.0
			)
		)
	)

	if out.size() > 5:
		out = out.slice(0, 5)

	return out


func _assets_surface_key(
	actor: Person
) -> String:
	if actor == null:
		return ""

	return "%d|%s|%d|age:%d|bank:%d|assets" % [
		int(actor.id),
		_current_era_key(),
		_current_year(),
		int(actor.age),
		int(actor.bank_balance)
	]


func _surface_pack_key(
	actor: Person,
	_context: Dictionary = {}
) -> String:
	if actor == null:
		return ""



	return "%d|%s|%d|age:%d|surface_pack" % [
		int(actor.id),
		_current_era_key(),
		_current_year(),
		int(actor.age)
	]

func _current_era_key() -> String:
	if gs == null:
		return "modern"

	var era_text: String = ""

	if gs.era != null:
		era_text = str(
			gs.era.name
		).strip_edges().to_lower()

	if era_text.find("ancient") >= 0:
		return "ancient"

	if era_text.find("medieval") >= 0:
		return "medieval"

	if era_text.find("industrial") >= 0:
		return "industrial"

	if era_text.find("future") >= 0:
		return "future"

	return "modern"


func _current_year() -> int:
	return int(
		gs.year
		if gs != null
		else 0
	)


func _person_label(
	actor: Person
) -> String:
	if actor == null:
		return "Unknown"

	var label: String = (
		"%s %s" % [
			str(actor.first_name),
			str(actor.last_name)
		]
	).strip_edges()

	if label == "":
		label = "Person %d" % int(actor.id)

	return label


func _format_money(
	amount: int
) -> String:
	if gs != null and gs.economy_engine != null:
		return gs.economy_engine.format_money(
			amount
		)

	return "$%d USD" % amount


func _ensure_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	var stored: Dictionary = _safe_dictionary(
		gs.scenario_state.get(
			"assets_contract_engine_state",
			{}
		)
	)

	if stored.is_empty():
		return

	if assets_surface_cache.is_empty():
		assets_surface_cache = _safe_dictionary(
			stored.get(
				"assets_surface_cache",
				{}
			)
		)

	if surface_pack_cache.is_empty():
		surface_pack_cache = _safe_dictionary(
			stored.get(
				"surface_pack_cache",
				{}
			)
		)


func _commit_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["assets_contract_engine_state"] = {
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"assets_surface_cache": assets_surface_cache.duplicate(true),
		"surface_pack_cache": surface_pack_cache.duplicate(true),
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}


func _failure(
	reason: String,
	context: Dictionary = {}
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	var report: Dictionary = {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": CONTRACT_VERSION,
		"reason": reason,
		"context": context.duplicate(true),
		"ui_is_renderer_only": true,
		"failed_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	last_report = report.duplicate(true)
	return report


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []