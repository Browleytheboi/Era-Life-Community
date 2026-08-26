extends Resource
class_name ActionDiscoveryEngine

var gs

func _init(_gs):
	gs = _gs





func generate_actions(person: Person) -> Array:
	var actions = []
	actions += _capability_actions(person)
	actions += _relationship_actions(person)
	actions += _economy_actions(person)
	actions += _asset_actions(person)
	actions += _cosmic_actions(person)
	return actions






func _capability_actions(p: Person) -> Array:

	var out = []
	var seen:= {}

	for cap in p.capabilities.nodes.keys():

		match cap:




			"Robbery":
				var weapon_name = _preferred_robbery_weapon()
				if weapon_name != "":
					_push_unique(out, seen, {
						"id": "crime_rob",
						"text": "Commit Robbery",
						"engine": "crime_engine",
						"method": "commit_crime",
						"args": ["Rob a Store", weapon_name]
					})







			"FireBlast":
				_push_unique(out, seen, {
					"id": "bending_attack_fire",
					"text": "Use Fire Blast",
					"engine": "crime_engine",
					"method": "commit_bending_crime",
					"requires_target": true,
					"target_type": "person",
					"move": "Fire Blast"
				})

			"WaterWhip":
				_push_unique(out, seen, {
					"id": "bending_attack_water",
					"text": "Use Water Whip",
					"engine": "crime_engine",
					"method": "commit_bending_crime",
					"requires_target": true,
					"target_type": "person",
					"move": "Water Whip"
				})

			"AirStrike":
				_push_unique(out, seen, {
					"id": "bending_attack_air",
					"text": "Use Air Strike",
					"engine": "crime_engine",
					"method": "commit_bending_crime",
					"requires_target": true,
					"target_type": "person",
					"move": "Air Strike"
				})

			"EarthCrush":
				_push_unique(out, seen, {
					"id": "bending_attack_earth",
					"text": "Use Earth Crush",
					"engine": "crime_engine",
					"method": "commit_bending_crime",
					"requires_target": true,
					"target_type": "person",
					"move": "Earth Crush"
				})




			"TeachBending":
				_push_unique(out, seen, {
					"id": "teach_bending",
					"text": "Teach Bending",
					"engine": "relationship_activities_engine",
					"method": "help_bending",
					"requires_target": true,
					"target_type": "person",
				})




			"RuleRealm":
				_push_unique(out, seen, {
					"id": "declare_war",
					"text": "Declare War",
					"engine": "realm_engine",
					"method": "declare_war",
					"requires_target": true,
					"target_type": "realm"
				})

	return out





func _relationship_actions(p: Person) -> Array:

	var out = []

	if p.partner != null:

		out.append({
			"id": "make_love",
			"text": "Make Love",
			"engine": "relationship_activities_engine",
			"method": "make_love",
			"args": [p.partner]
		})

		out.append({
			"id": "counseling",
			"text": "Relationship Counseling",
			"engine": "relationship_activities_engine",
			"method": "counseling",
			"args": [p.partner]
		})

	return out





func _economy_actions(p: Person) -> Array:
	var out = []
	if p.bank_balance > 1000:
		out.append({
			"id": "buy_property",
			"text": "Buy Property",
			"engine": "property_engine",
			"method": "buy_property"
		})
		out.append({
			"id": "buy_vehicle",
			"text": "Buy Vehicle",
			"engine": "vehicle_engine",
			"method": "buy_vehicle"
		})

	if gs != null and gs.migration_engine != null:
		out.append({
			"id": "migrate_somewhere",
			"text": "Migrate Somewhere",
			"engine": "migration_engine",
			"method": "open_player_migration_panel",
			"args": [p]
		})

	return out
func _asset_actions(p: Person) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var property_actions: Array = []
	var vehicle_actions: Array = []

	if gs != null and gs.property_engine != null:
		property_actions = gs.property_engine.get_property_asset_actions(p)
		for action in property_actions:
			_push_unique(out, seen, action)

	if gs != null and gs.vehicle_engine != null:
		vehicle_actions = gs.vehicle_engine.get_vehicle_asset_actions(p)
		for action in vehicle_actions:
			_push_unique(out, seen, action)

	for action in _portfolio_actions(p, property_actions, vehicle_actions):
		_push_unique(out, seen, action)

	if gs != null and gs.property_engine != null and gs.property_engine.has_method("get_property_portfolio_panel_payload"):
		var property_payload: Dictionary = gs.property_engine.get_property_portfolio_panel_payload(p)
		var property_rollup: Dictionary = property_payload.get("rollup", {})
		if int(property_rollup.get("asset_count", 0)) > 0:
			_push_unique(out, seen, {
				"id": "portfolio_assets_property_surface",
				"text": "Open Estate Asset Surface",
				"engine": "action_discovery_engine",
				"method": "manage_property_portfolio",
				"args": [p]
			})

	if gs != null and gs.vehicle_engine != null and gs.vehicle_engine.has_method("get_vehicle_portfolio_panel_payload"):
		var vehicle_payload: Dictionary = gs.vehicle_engine.get_vehicle_portfolio_panel_payload(p)
		var vehicle_rollup: Dictionary = vehicle_payload.get("rollup", {})
		if int(vehicle_rollup.get("asset_count", 0)) > 0:
			_push_unique(out, seen, {
				"id": "portfolio_assets_vehicle_surface",
				"text": "Open Mobility Asset Surface",
				"engine": "action_discovery_engine",
				"method": "manage_vehicle_portfolio",
				"args": [p]
			})

	return out
func _portfolio_actions(p: Person, property_actions: Array, vehicle_actions: Array) -> Array:
	var out: Array = []
	if gs == null or p == null:
		return out

	var property_rollup: Dictionary = {}
	if gs.property_engine != null:
		property_rollup = gs.property_engine.get_asset_signal_rollup_for_owner(p)

	var vehicle_rollup: Dictionary = {}
	if gs.vehicle_engine != null:
		vehicle_rollup = gs.vehicle_engine.get_asset_signal_rollup_for_owner(p)

	var property_asset_count: int = int(property_rollup.get("asset_count", 0))
	var vehicle_asset_count: int = int(vehicle_rollup.get("asset_count", 0))

	var property_portfolio_tags: Dictionary = property_rollup.get("portfolio_tags", {})
	var vehicle_portfolio_tags: Dictionary = vehicle_rollup.get("portfolio_tags", {})

	if property_asset_count > 0:
		out.append({
			"id": "portfolio_review_estates",
			"text": "Review Estates",
			"engine": "action_discovery_engine",
			"method": "review_property_portfolio",
			"args": [p]
		})

	if property_asset_count >= 2 \
or int(property_portfolio_tags.get("dynastic_properties", 0)) >= 1 \
or int(property_portfolio_tags.get("rentals", 0)) >= 1 \
or int(property_portfolio_tags.get("safehouses", 0)) >= 1:
		out.append({
			"id": "portfolio_manage_holdings",
			"text": "Manage Holdings",
			"engine": "action_discovery_engine",
			"method": "manage_property_portfolio",
			"args": [p]
		})

	if _has_asset_action_suffix(property_actions, "_open_to_tenants"):
		out.append({
			"id": "portfolio_open_to_tenants",
			"text": "Open To Tenants",
			"engine": "action_discovery_engine",
			"method": "open_portfolio_to_tenants",
			"args": [p]
		})

	if vehicle_asset_count >= 2 \
or int(vehicle_portfolio_tags.get("fleets", 0)) >= 1 \
or int(vehicle_portfolio_tags.get("stables", 0)) >= 1 \
or int(vehicle_portfolio_tags.get("hangars", 0)) >= 1 \
or int(vehicle_portfolio_tags.get("trade_routes", 0)) >= 1:
		out.append({
			"id": "portfolio_manage_fleet",
			"text": "Manage Fleet",
			"engine": "action_discovery_engine",
			"method": "manage_vehicle_portfolio",
			"args": [p]
		})

	if _has_asset_action_suffix(vehicle_actions, "_assign_driver"):
		out.append({
			"id": "portfolio_assign_driver",
			"text": "Assign Driver",
			"engine": "action_discovery_engine",
			"method": "assign_portfolio_driver",
			"args": [p]
		})

	if _has_asset_action_suffix(vehicle_actions, "_assign_captain"):
		out.append({
			"id": "portfolio_assign_captain",
			"text": "Assign Captain",
			"engine": "action_discovery_engine",
			"method": "assign_portfolio_captain",
			"args": [p]
		})

	return out


func review_property_portfolio(owner: Person) -> Dictionary:
	if gs == null or gs.property_engine == null or owner == null:
		return { "success": false, "text": "No property portfolio could be reviewed."}

	var rollup: Dictionary = gs.property_engine.get_asset_signal_rollup_for_owner(owner)
	if rollup.is_empty():
		return { "success": false, "text": "I don't own any estates to review."}

	var portfolio_tags: Dictionary = rollup.get("portfolio_tags", {})
	var text:= "I reviewed my estates: %d total" % int(rollup.get("asset_count", 0))

	var dynastic_count: int = int(portfolio_tags.get("dynastic_properties", 0))
	var rental_count: int = int(portfolio_tags.get("rentals", 0))
	var safehouse_count: int = int(portfolio_tags.get("safehouses", 0))
	var dependency_pressure: float = float(rollup.get("dependency_pressure", 0.0))

	if dynastic_count > 0:
		text += ", %d dynastic" % dynastic_count
	if rental_count > 0:
		text += ", %d rental" % rental_count
	if safehouse_count > 0:
		text += ", %d hidden" % safehouse_count
	if dependency_pressure > 0.0:
		text += ", upkeep pressure %.1f" % dependency_pressure

	text += "."
	return { "success": true, "text": text}


func manage_property_portfolio(owner: Person) -> Dictionary:
	if gs == null or gs.property_engine == null or owner == null:
		return { "success": false, "text": "No holdings could be managed."}
	var rollup: Dictionary = gs.property_engine.get_asset_signal_rollup_for_owner(owner)
	if rollup.is_empty():
		return { "success": false, "text": "I don't own enough property to manage as a portfolio."}
	var portfolio_tags: Dictionary = rollup.get("portfolio_tags", {})
	var text:= "I opened my holdings portfolio"
	if int(portfolio_tags.get("dynastic_properties", 0)) >= 1:
		text += " with a focus on legacy seats"
	if int(portfolio_tags.get("rentals", 0)) >= 1:
		text += ", tenant income"
	if int(portfolio_tags.get("safehouses", 0)) >= 1:
		text += ", and discreet locations"
	text += "."
	return {
		"success": true,
		"type": "open_property_portfolio_panel",
		"text": text,
		"owner_id": int(owner.id)
	}


func manage_vehicle_portfolio(owner: Person) -> Dictionary:
	if gs == null or gs.vehicle_engine == null or owner == null:
		return { "success": false, "text": "No fleet could be managed."}
	var rollup: Dictionary = gs.vehicle_engine.get_asset_signal_rollup_for_owner(owner)
	if rollup.is_empty():
		return { "success": false, "text": "I don't own enough mobility assets to manage as a fleet."}
	var portfolio_tags: Dictionary = rollup.get("portfolio_tags", {})
	var text:= "I opened fleet command: %d total mobility assets" % int(rollup.get("asset_count", 0))
	var fleet_count: int = int(portfolio_tags.get("fleets", 0))
	var stable_count: int = int(portfolio_tags.get("stables", 0))
	var hangar_count: int = int(portfolio_tags.get("hangars", 0))
	var trade_route_count: int = int(portfolio_tags.get("trade_routes", 0))
	var dependency_pressure: float = float(rollup.get("dependency_pressure", 0.0))
	if fleet_count > 0:
		text += ", %d fleet" % fleet_count
	if stable_count > 0:
		text += ", %d stable" % stable_count
	if hangar_count > 0:
		text += ", %d hangar" % hangar_count
	if trade_route_count > 0:
		text += ", %d trade-route" % trade_route_count
	if dependency_pressure > 0.0:
		text += ", logistics pressure %.1f" % dependency_pressure
	text += "."
	return {
		"success": true,
		"type": "open_vehicle_portfolio_panel",
		"text": text,
		"owner_id": int(owner.id)
	}


func open_portfolio_to_tenants(owner: Person) -> Dictionary:
	if gs == null or gs.property_engine == null or owner == null:
		return { "success": false, "text": "No rental-ready estate could be found."}

	var actions: Array = gs.property_engine.get_property_asset_actions(owner)
	var match: Dictionary = _find_first_asset_action_with_suffix(actions, "_open_to_tenants")
	if match.is_empty():
		return { "success": false, "text": "None of my current estates are ready to open to tenants."}

	return gs.get(match.get("engine", "")).callv(match.get("method", ""), match.get("args", []))


func assign_portfolio_driver(owner: Person) -> Dictionary:
	if gs == null or gs.vehicle_engine == null or owner == null:
		return { "success": false, "text": "No driver-ready vehicle could be found."}

	var actions: Array = gs.vehicle_engine.get_vehicle_asset_actions(owner)
	var match: Dictionary = _find_first_asset_action_with_suffix(actions, "_assign_driver")
	if match.is_empty():
		return { "success": false, "text": "None of my current vehicles support assigning a driver."}

	return gs.get(match.get("engine", "")).callv(match.get("method", ""), match.get("args", []))


func assign_portfolio_captain(owner: Person) -> Dictionary:
	if gs == null or gs.vehicle_engine == null or owner == null:
		return { "success": false, "text": "No captain-ready vehicle could be found."}

	var actions: Array = gs.vehicle_engine.get_vehicle_asset_actions(owner)
	var match: Dictionary = _find_first_asset_action_with_suffix(actions, "_assign_captain")
	if match.is_empty():
		return { "success": false, "text": "None of my current mobility assets support assigning a captain."}

	return gs.get(match.get("engine", "")).callv(match.get("method", ""), match.get("args", []))


func _has_asset_action_suffix(actions: Array, suffix: String) -> bool:
	for raw_action in actions:
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue
		var action_id:= str(raw_action.get("id", ""))
		if action_id.ends_with(suffix):
			return true
	return false


func _find_first_asset_action_with_suffix(actions: Array, suffix: String) -> Dictionary:
	for raw_action in actions:
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = raw_action
		var action_id:= str(action.get("id", ""))
		if action_id.ends_with(suffix):
			return action
	return {}





func _cosmic_actions(_p) -> Array:

	var out = []

	if gs.dragonballs_engine.player_has_all():

		out.append({
			"id": "summon_shenron",
			"text": "Summon Shenron",
			"engine": "dragonballs_engine",
			"method": "make_wish"
		})

	if gs.artifacts_engine.player_has_all():

		out.append({
			"id": "forge_gauntlet",
			"text": "Forge Infinity Gauntlet",
			"engine": "artifacts_engine",
			"method": "forge_gauntlet"
		})

	return out





func _push_unique(arr: Array, seen: Dictionary, action: Dictionary) -> void:
	var id = action.get("id", "")
	if id == "":
		return
	if seen.has(id):
		return
	seen [id] = true
	arr.append(action)


func _preferred_robbery_weapon() -> String:


	var owned = gs.weapons_engine.get_inventory()
	for t in owned:
		var weapon_name = str(t).replace("Weapon_", "")
		if gs.weapons_engine.weapon_exists_in_era(weapon_name):
			return weapon_name


	var fallbacks = [
		"Knife",
		"Dagger",
		"Pocket Knife",
		"Plasma Dagger",
		"Shortsword",
		"Hand Axe"
	]

	for w in fallbacks:
		if gs.weapons_engine.weapon_exists_in_era(w):
			return w

	return ""