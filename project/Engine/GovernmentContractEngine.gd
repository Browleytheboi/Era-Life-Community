extends Resource
class_name GovernmentContractEngine

var gs

func _init(_gs = null):
	gs = _gs


func government_contract_for_realm(realm: Dictionary, context: Dictionary = {}) -> Dictionary:
	var realm_name: String = str(realm.get("name", realm.get("country", ""))).strip_edges()
	var government_model: String = str(realm.get("government_model", "")).strip_edges()
	var government_style: String = str(realm.get("government_style", "")).strip_edges()
	var era_name: String = str(context.get("era_name", realm.get("era_name", ""))).strip_edges()

	if government_model == "":
		government_model = _infer_government_model(realm_name, government_style, era_name)

	if government_style == "":
		government_style = _style_for_model(government_model)

	return {
		"schema": "eralife.government_contract",
		"version": 1,
		"realm_name": realm_name,
		"government_style": government_style,
		"government_model": government_model,
		"branch_contract": branch_contract_for_model(government_model, realm),
		"observable_population_policy": {
			"ready_door_may_not_wait": true,
			"ui_is_renderer_only": true
		}
	}


func branch_contract_for_model(government_model: String, _realm: Dictionary = {}) -> Dictionary:
	var clean_model: String = str(government_model).strip_edges().to_lower()

	match clean_model:
		"federal_presidential_republic":
			return {
				"schema": "eralife.government_branch_contract",
				"version": 1,
				"government_model": "federal_presidential_republic",
				"branches": {
					"executive": { "target": 2, "section": "federal_executive"},
					"cabinet": { "target": 16, "section": "federal_cabinet"},
					"senate": { "target": 100, "section": "federal_senate"},
					"judicial": { "target": 9, "section": "federal_supreme_court"},
					"state_governor": { "target": 50, "section": "federal_governor"},
					"civilian": { "target": 150, "section": "citizen"}
				},
				"full_population_total": 327,
				"ready_door_may_not_wait": true,
				"ui_is_renderer_only": true
			}

		"constitutional_monarchy":
			return {
				"schema": "eralife.government_branch_contract",
				"version": 1,
				"government_model": "constitutional_monarchy",
				"branches": {
					"royal_house": { "target": 4, "section": "royals"},
					"ministers": { "target": 12, "section": "officials"},
					"nobility": { "target": 18, "section": "nobles"},
					"civilian": { "target": 120, "section": "citizen"}
				},
				"ready_door_may_not_wait": true,
				"ui_is_renderer_only": true
			}

		"monarchy":
			return {
				"schema": "eralife.government_branch_contract",
				"version": 1,
				"government_model": "monarchy",
				"branches": {
					"royal_house": { "target": 6, "section": "royals"},
					"nobility": { "target": 24, "section": "nobles"},
					"masters": { "target": 12, "section": "masters"},
					"civilian": { "target": 120, "section": "citizen"}
				},
				"ready_door_may_not_wait": true,
				"ui_is_renderer_only": true
			}

		_:
			return {
				"schema": "eralife.government_branch_contract",
				"version": 1,
				"government_model": clean_model if clean_model != "" else "generic_government",
				"branches": {
					"officials": { "target": 8, "section": "officials"},
					"civilian": { "target": 100, "section": "citizen"}
				},
				"ready_door_may_not_wait": true,
				"ui_is_renderer_only": true
			}


func _infer_government_model(realm_name: String, government_style: String, era_name: String) -> String:
	var name_key: String = str(realm_name).strip_edges().to_lower()
	var style_key: String = str(government_style).strip_edges().to_lower()
	var era_key: String = str(era_name).strip_edges().to_lower()

	if name_key in ["usa", "united states", "united states of america"]:
		return "federal_presidential_republic"

	if style_key.find("monarchy") != -1:
		if era_key in ["modern era", "future era"]:
			return "constitutional_monarchy"
		return "monarchy"

	if style_key.find("republic") != -1:
		return "republic"

	if style_key.find("democracy") != -1:
		return "democracy"

	if style_key.find("empire") != -1:
		return "empire"

	if style_key.find("theocracy") != -1:
		return "theocracy"

	return "generic_government"


func _style_for_model(government_model: String) -> String:
	var clean_model: String = str(government_model).strip_edges().to_lower()

	match clean_model:
		"federal_presidential_republic":
			return "Republic"
		"constitutional_monarchy":
			return "Monarchy"
		"monarchy":
			return "Monarchy"
		"republic":
			return "Republic"
		"democracy":
			return "Democracy"
		"empire":
			return "Empire"
		"theocracy":
			return "Theocracy"
		_:
			return "Government"