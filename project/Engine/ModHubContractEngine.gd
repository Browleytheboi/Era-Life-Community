

extends RefCounted
class_name ModHubContractEngine

const ENGINE_SCHEMA:= "eralife.mod_hub_contract_engine"
const ENGINE_VERSION:= 1
const HUB_SCHEMA:= "eralife.mod_hub_contract"
const HUB_VERSION:= 1

var gs
var last_report: Dictionary = {}


func _init(
	_gs = null
) -> void:
	gs = _gs


func bootstrap_default_contracts() -> Dictionary:
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"root_authority": "mod_contract_engine",
		"marketplace_authority": (
			"mod_marketplace_contract_engine"
		),
		"ui_is_renderer_only": true
	}

func _bundle_authority():
	return (
		gs.mod_bundle_contract_engine
		if (
			gs != null
			and gs.mod_bundle_contract_engine != null
		)
		else null
	)
func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
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

	if action_id in [
		"refresh",
		"open_hub",
		"observe_partial",
		"set_section"
	]:
		result = {
			"success": true,
			"type": "mod_hub_refreshed"
		}
	elif action_id in [
		"enable_mod",
		"disable_mod",
		"reload_mods",
		"set_mod_setting",
		"provider_intent"
	]:
		if _law() == null:
			result = _failure(
				"missing_mod_law",
				"The mod authority is unavailable."
			)
		else:
			result = _law().resolve_mod_intent(
				actor,
				payload
			)
	elif action_id in [
		"browse_marketplace",
		"refresh_marketplace",
		"search_marketplace",
		"install_mod",
		"uninstall_mod",
		"check_compatibility"
	]:
		if _marketplace() == null:
			result = _failure(
				"missing_marketplace",
				"The mod marketplace is unavailable."
			)
		else:
			result = _marketplace().resolve_intent(
				actor,
				payload
			)
	elif action_id in [
		"install_bundle",
		"install_bundle_component",
		"remove_bundle_component",
		"enable_bundle",
		"disable_bundle",
		"prewarm_bundle_enable",
		"prewarm_bundle_disable",
		"uninstall_bundle",
		"open_bundle_menu",
		"refresh_bundle_menu"
	]:
		if _bundle_authority() == null:
			result = _failure(
				"missing_bundle_authority",
				(
					"The installable reality bundle "
					+ "authority is unavailable."
				)
			)
		else:
			result = _bundle_authority().resolve_intent(
				actor,
				payload
			)
	else:
		result = _failure(
			"unknown_mod_hub_intent",
			"The Mod Hub does not recognize that intent."
		)

	result ["mod_hub_contract"] = emit_mod_hub_contract(
		actor,
		{
			"active_section": str(
				payload.get(
					"section_id",
					"installed"
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
					"mod_hub_contract_engine.resolve_intent"
				)
			)
		}
	)
	result ["mod_hub_contract_engine_owned"] = true
	result ["ui_is_renderer_only"] = true
	last_report = result.duplicate(true)

	return result


func emit_observable_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	var actor_id: int = (
		int(actor.id)
		if actor != null
		else -1
	)
	var actor_name: String = _person_name(actor)
	var installed_rows: Array = []

	if _law() != null:
		installed_rows = _law().installed_mod_summaries()

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": actor_id,
		"actor_name": actor_name,
		"title": "🧩 MOD HUB",
		"subtitle": (
			"Installed reality systems are observable while "
			+ "the full ecosystem reconciles."
		),
		"active_section": _section(
			str(
				context.get(
					"active_section",
					"installed"
				)
			)
		),
		"identity_overview": _identity_overview(actor),
		"section_tabs": _section_tabs(),
		"installed_mods": installed_rows,
		"available_mods": [],
		"active_mod_effects": [],
		"modded_systems": [],
		"conflicts": [],
		"performance_budget": (
			_performance_budget_contract()
		),
		"status_text": str(
			context.get(
				"status_text",
				(
					"Mod reality is observable while marketplace "
					+ "and provider truth reconcile."
				)
			)
		),
		"truth_state": "observable_partial",
		"authoritative_projection": false,
		"surface_revision": "%d:%d:observable" % [
			actor_id,
			_registry_revision()
		],
		"ui_is_renderer_only": true
	}


func emit_mod_hub_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if _law() == null:
		return emit_observable_contract(
			actor,
			context
		)

	var installed_mods: Array = (
		_law().installed_mod_summaries()
	)
	var available_mods: Array = []

	if _marketplace() != null:
		available_mods = (
			_marketplace().fetch_available_mods(
				context
			)
		)

	var active_mod_effects: Array = []
	var modded_systems: Array = []
	var conflicts: Array = []
	var reality_bundles: Array = []
	var active_experience: Dictionary = {}
	var bundle_registry_revision: int = 0

	if _bundle_authority() != null:
		reality_bundles = (
			_bundle_authority().bundle_summaries()
		)
		active_experience = (
			_bundle_authority()
			.active_experience_contract()
		)
		bundle_registry_revision = int(
			_bundle_authority().registry_revision
		)

	available_mods = (
		_apply_bundle_state_to_marketplace_rows(
			available_mods,
			reality_bundles
		)
	)

	var installed_bundle_count: int = 0
	var enabled_bundle_count: int = 0

	for raw_bundle in reality_bundles:
		var bundle: Dictionary = _dict(
			raw_bundle
		)

		if bool(
			bundle.get(
				"installed",
				false
			)
		):
			installed_bundle_count += 1

		if bool(
			bundle.get(
				"enabled",
				false
			)
		):
			enabled_bundle_count += 1

	for raw_summary in _law().active_provider_summaries():
		if typeof(raw_summary) != TYPE_DICTIONARY:
			continue

		var summary: Dictionary = raw_summary as Dictionary
		modded_systems.append(
			summary.duplicate(true)
		)

		if bool(
			summary.get(
				"blocked",
				false
			)
		):
			conflicts.append(
				summary.duplicate(true)
			)
		elif int(
			summary.get(
				"active_count",
				0
			)
		) > 0:
			active_mod_effects.append({
				"provider_type": str(
					summary.get(
						"provider_type",
						""
					)
				),
				"target_id": str(
					summary.get(
						"target_id",
						""
					)
				),
				"active_provider_keys": _array(
					summary.get(
						"active_provider_keys",
						[]
					)
				),
				"resolution_policy": str(
					summary.get(
						"resolution_policy",
						""
					)
				)
			})

	for raw_conflict in (
		_law().provider_conflict_registry.values()
	):
		if typeof(raw_conflict) == TYPE_DICTIONARY:
			conflicts.append(
				(raw_conflict as Dictionary).duplicate(true)
			)

	var status_text: String = str(
		context.get(
			"status_text",
			""
		)
	).strip_edges()

	if status_text == "":
		status_text = (
			"%d installed mod records • "
			+ "%d reality bundles installed • "
			+ "%d bundles live • "
			+ "%d provider targets • "
			+ "%d conflicts"
		) % [
			installed_mods.size(),
			installed_bundle_count,
			enabled_bundle_count,
			modded_systems.size(),
			conflicts.size()
		]

	return {
		"success": true,
		"schema": HUB_SCHEMA,
		"version": HUB_VERSION,
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"actor_name": _person_name(actor),
		"title": "    MOD HUB",
		"subtitle": (
			"Install systems, reconcile providers, and expand "
			+ "the same continuous reality."
		),
		"active_section": _section(
			str(
				context.get(
					"active_section",
					"installed"
				)
			)
		),
		"identity_overview": _identity_overview(actor),
		"section_tabs": _section_tabs(),
		"installed_mods": installed_mods,
		"available_mods": available_mods,
		"active_mod_effects": active_mod_effects,
		"reality_bundles": reality_bundles,
		"installed_bundle_count": installed_bundle_count,
		"enabled_bundle_count": enabled_bundle_count,
		"active_experience_contract": active_experience,
		"bundle_transaction_authority": (
			"mod_bundle_contract_engine"
		),
		"modded_systems": modded_systems,
		"conflicts": conflicts,
		"quarantined_mods": (
			_law().quarantined_mods.values()
		),
		"performance_budget": (
			_performance_budget_contract()
		),
		"status_text": status_text,
		"truth_state": "hot",
		"authoritative_projection": true,
		"surface_revision": (
			"%d:%d:%d:%d:%d:%d:%d"
			% [
				(
					int(actor.id)
					if actor != null
					else -1
				),
				_registry_revision(),
				bundle_registry_revision,
				installed_mods.size(),
				installed_bundle_count,
				enabled_bundle_count,
				modded_systems.size()
			]
		),
		"provider_registration_authority": (
			"mod_contract_engine"
		),
		"marketplace_authority": (
			"mod_marketplace_contract_engine"
		),
		"ui_is_renderer_only": true
	}
func _apply_bundle_state_to_marketplace_rows(
	available_mods: Array,
	reality_bundles: Array
) -> Array:
	var bundle_state_by_mod_id: Dictionary = {}

	for raw_bundle in reality_bundles:
		var bundle: Dictionary = _dict(
			raw_bundle
		)
		var root_mod_id: String = str(
			bundle.get(
				"root_mod_id",
				""
			)
		).strip_edges().to_lower()
		var bundle_id: String = str(
			bundle.get(
				"bundle_id",
				""
			)
		).strip_edges().to_lower()

		if root_mod_id != "":
			bundle_state_by_mod_id [root_mod_id] = (
				bundle.duplicate(true)
			)

		if bundle_id != "":
			bundle_state_by_mod_id [bundle_id] = (
				bundle.duplicate(true)
			)

	var out: Array = []

	for raw_mod in available_mods:
		if typeof(raw_mod) != TYPE_DICTIONARY:
			continue

		var mod: Dictionary = (
			raw_mod as Dictionary
		).duplicate(true)
		var mod_id: String = str(
			mod.get(
				"mod_id",
				""
			)
		).strip_edges().to_lower()
		var bundle_state: Dictionary = _dict(
			bundle_state_by_mod_id.get(
				mod_id,
				{}
			)
		)

		if not bundle_state.is_empty():
			mod ["installed"] = bool(
				bundle_state.get(
					"installed",
					false
				)
			)
			mod ["enabled"] = bool(
				bundle_state.get(
					"enabled",
					false
				)
			)
			mod ["bundle_id"] = str(
				bundle_state.get(
					"bundle_id",
					""
				)
			)
			mod ["listing_kind"] = "reality_bundle"
			mod ["bundle_state_authority"] = (
				"mod_bundle_contract_engine"
			)

		out.append(mod)

	return out


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA + ".state",
		"version": ENGINE_VERSION,
		"last_report": last_report.duplicate(true)
	}


func import_state(
	data: Dictionary = {}
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


func _section(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()

	if clean not in [
		"bundles",
		"installed",
		"marketplace",
		"systems",
		"conflicts",
		"settings"
	]:
		return "bundles"

	return clean


func _section_tabs() -> Array:
	return [
		{
			"id": "bundles",
			"label": "REALITY BUNDLES",
			"icon": "🌍"
		},
		{
			"id": "installed",
			"label": "INSTALLED",
			"icon": "✅"
		},
		{
			"id": "marketplace",
			"label": "MARKETPLACE",
			"icon": "🛍️"
		},
		{
			"id": "systems",
			"label": "SYSTEMS",
			"icon": "⚙️"
		},
		{
			"id": "conflicts",
			"label": "CONFLICTS",
			"icon": "⚠️"
		},
		{
			"id": "settings",
			"label": "SETTINGS",
			"icon": "🎛️"
		}
	]


func _identity_overview(
	actor: Person
) -> Dictionary:
	return {
		"actor_id": (
			int(actor.id)
			if actor != null
			else -1
		),
		"name": _person_name(actor),
		"installed_mod_count": (
			_law().mod_registry.size()
			if _law() != null
			else 0
		),
		"enabled_mod_count": (
			_law().enabled_mod_ids.size()
			if _law() != null
			else 0
		),
		"provider_count": (
			_law().provider_registry.size()
			if _law() != null
			else 0
		),
		"conflict_count": (
			_law().provider_conflict_registry.size()
			if _law() != null
			else 0
		)
	}


func _performance_budget_contract() -> Dictionary:
	return {
		"max_mod_contract_bytes": (
			ModContractEngine.MAX_MOD_CONTRACT_BYTES
		),
		"max_provider_contract_bytes": (
			ModContractEngine.MAX_PROVIDER_CONTRACT_BYTES
		),
		"max_providers_per_mod": (
			ModContractEngine.MAX_PROVIDERS_PER_MOD
		),
		"max_rows_per_provider": (
			ModContractEngine.MAX_ROWS_PER_PROVIDER
		),
		"max_emitted_rows_per_target": (
			ModContractEngine.MAX_EMITTED_ROWS_PER_TARGET
		),
		"cache_rebuild_triggers": [
			"install",
			"enable",
			"disable",
			"uninstall",
			"reload"
		]
	}


func _registry_revision() -> int:
	return (
		int(_law().registry_revision)
		if _law() != null
		else 0
	)


func _person_name(
	actor: Person
) -> String:
	if actor == null:
		return "Current Life"

	var name_text: String = "%s %s" % [
		str(actor.first_name),
		str(actor.last_name)
	]
	name_text = name_text.strip_edges()

	return (
		name_text
		if name_text != ""
		else "Current Life"
	)


func _law():
	return (
		gs.mod_contract_engine
		if (
			gs != null
			and gs.mod_contract_engine != null
		)
		else null
	)


func _marketplace():
	return (
		gs.mod_marketplace_contract_engine
		if (
			gs != null
			and gs.mod_marketplace_contract_engine != null
		)
		else null
	)


func _dict(
	value: Variant
) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)
	return {}


func _array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)
	return []


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