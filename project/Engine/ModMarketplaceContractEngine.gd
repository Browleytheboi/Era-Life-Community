

extends RefCounted
class_name ModMarketplaceContractEngine

const ENGINE_SCHEMA:= "eralife.mod_marketplace_contract_engine"
const ENGINE_VERSION:= 1
const CATALOG_SCHEMA:= "eralife.mod_marketplace_catalog"
const CATALOG_VERSION:= 1
const MAX_CATALOG_ROWS:= 1000

var gs
var last_report: Dictionary = {}
var catalog_revision: int = 0


func _init(
	_gs = null
) -> void:
	gs = _gs


func bootstrap_default_contracts() -> Dictionary:
	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"catalog_schema": CATALOG_SCHEMA,
		"catalog_version": CATALOG_VERSION,
		"ui_is_renderer_only": true
	}


func resolve_intent(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	var action_id: String = str(
		payload.get(
			"action_id",
			payload.get(
				"intent_type",
				"refresh_marketplace"
			)
		)
	).strip_edges().to_lower()
	var report: Dictionary

	match action_id:
		"refresh_marketplace", "browse_marketplace", "search_marketplace":
			report = {
				"success": true,
				"type": "mod_marketplace_refreshed",
				"available_mods": fetch_available_mods(payload)
			}

		"install_mod":
			report = install_mod(
				str(
					payload.get(
						"mod_id",
						""
					)
				),
				payload
			)

		"uninstall_mod":
			report = uninstall_mod(
				str(
					payload.get(
						"mod_id",
						""
					)
				),
				payload
			)

		"check_compatibility":
			report = check_compatibility(
				_dict(
					payload.get(
						"mod_contract",
						payload.get(
							"marketplace_row",
							{}
						)
					)
				)
			)

		_:
			report = _failure(
				"unknown_marketplace_intent",
				"The mod marketplace does not recognize that intent."
			)

	report ["actor_id"] = (
		int(actor.id)
		if actor != null
		else -1
	)
	report ["ui_is_renderer_only"] = true
	last_report = report.duplicate(true)

	return report


func fetch_available_mods(
	context: Dictionary = {}
) -> Array:
	var rows_by_id: Dictionary = {}

	for raw_row in _local_catalog_rows():
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		_ingest_catalog_row(
			rows_by_id,
			raw_row as Dictionary,
			"local"
		)

	for raw_row in _network_catalog_rows():
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue
		_ingest_catalog_row(
			rows_by_id,
			raw_row as Dictionary,
			"network"
		)

	var installed_by_id: Dictionary = {}
	if _law() != null:
		for raw_summary in _law().installed_mod_summaries():
			if typeof(raw_summary) != TYPE_DICTIONARY:
				continue

			var summary: Dictionary = raw_summary as Dictionary
			var installed_id: String = _id(
				str(
					summary.get(
						"mod_id",
						""
					)
				)
			)
			if installed_id != "":
				installed_by_id [installed_id] = (
					summary.duplicate(true)
				)
				if not rows_by_id.has(installed_id):
					_ingest_catalog_row(
						rows_by_id,
						summary,
						"installed"
					)

	var search_text: String = str(
		context.get(
			"search_text",
			""
		)
	).strip_edges().to_lower()
	var category_filter: String = str(
		context.get(
			"category",
			""
		)
	).strip_edges().to_lower()
	var rows: Array = []

	for raw_mod_id in rows_by_id.keys():
		var mod_id: String = str(raw_mod_id)
		var row: Dictionary = _dict(
			rows_by_id.get(
				mod_id,
				{}
			)
		)
		var installed: Dictionary = _dict(
			installed_by_id.get(
				mod_id,
				{}
			)
		)

		row ["installed"] = not installed.is_empty()
		row ["enabled"] = bool(
			installed.get(
				"enabled",
				false
			)
		)
		row ["installed_version"] = str(
			installed.get(
				"release_version",
				""
			)
		)
		row ["compatibility"] = check_compatibility(row)
		row ["update_available"] = (
			_version_is_newer(
				str(
					row.get(
						"release_version",
						"0.0.0"
					)
				),
				str(
					installed.get(
						"release_version",
						"0.0.0"
					)
				)
			)
			if not installed.is_empty()
			else false
		)
		row ["rank_score"] = _rank_score(
			row,
			context
		)

		if (
			search_text != ""
			and not _row_matches_search(
				row,
				search_text
			)
		):
			continue

		if (
			category_filter != ""
			and category_filter != "all"
		):
			if str(
				row.get(
					"category",
					""
				)
			).strip_edges().to_lower() != category_filter:
				continue

		rows.append(row)

	rows.sort_custom(_catalog_row_precedes)

	if rows.size() > MAX_CATALOG_ROWS:
		rows.resize(MAX_CATALOG_ROWS)

	catalog_revision += 1
	return rows


func install_mod(
	mod_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_mod_id: String = _id(mod_id)

	if clean_mod_id == "":
		return _failure(
			"missing_mod_id",
			"A mod_id is required."
		)
	if _law() == null:
		return _failure(
			"missing_mod_law",
			"The mod authority is unavailable."
		)

	if _law().mod_registry.has(clean_mod_id):
		return _law().set_mod_enabled(
			clean_mod_id,
			true,
			context
		)

	var marketplace_row: Dictionary = _dict(
		context.get(
			"marketplace_row",
			{}
		)
	)
	var embedded_contract: Dictionary = _dict(
		context.get(
			"mod_contract",
			marketplace_row.get(
				"mod_contract",
				{}
			)
		)
	)
	var local_path: String = str(
		context.get(
			"local_path",
			marketplace_row.get(
				"local_path",
				""
			)
		)
	).strip_edges()

	if not embedded_contract.is_empty():
		var normalized: Dictionary = embedded_contract
		if (
			gs != null
			and gs.mod_loader != null
			and gs.mod_loader.has_method(
				"normalize_mod_contract"
			)
		):
			normalized = _dict(
				gs.mod_loader.normalize_mod_contract(
					embedded_contract,
					"marketplace://%s" % clean_mod_id
				)
			)

		var registration_report: Dictionary = (
			_law().register_mod_contract(
				clean_mod_id,
				normalized,
				{
					"source": (
						"mod_marketplace_embedded_contract"
					),
					"apply_runtime": true
				}
			)
		)
		registration_report ["type"] = "mod_installed"
		registration_report ["text"] = (
			"%s was installed." % clean_mod_id
		)
		return registration_report

	if local_path != "":
		if gs == null or gs.mod_loader == null:
			return _failure(
				"missing_mod_loader",
				"The ModLoader adapter is unavailable."
			)

		var loader_report: Dictionary = _dict(
			gs.mod_loader.load_mod_bundle_file(
				local_path,
				true
			)
		)
		if not bool(
			loader_report.get(
				"success",
				false
			)
		):
			return loader_report

		var bootstrap_report: Dictionary = (
			_law().bootstrap_from_loader({
				"source": (
					"mod_marketplace_local_install"
				),
				"apply_runtime": true
			})
		)
		return {
			"success": bool(
				bootstrap_report.get(
					"success",
					false
				)
			),
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"type": "mod_installed",
			"mod_id": clean_mod_id,
			"loader_report": loader_report,
			"bootstrap_report": bootstrap_report,
			"text": (
				"%s was installed from local storage."
				% clean_mod_id
			)
		}

	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"type": "mod_install_transport_required",
		"reason": "network_transport_required",
		"mod_id": clean_mod_id,
		"transport_contract": _dict(
			marketplace_row.get(
				"transport_contract",
				{}
			)
		),
		"text": (
			"This marketplace listing requires a network "
			+ "download transport before installation."
		)
	}


func uninstall_mod(
	mod_id: String,
	context: Dictionary = {}
) -> Dictionary:
	if _law() == null:
		return _failure(
			"missing_mod_law",
			"The mod authority is unavailable."
		)

	return _law().uninstall_mod(
		mod_id,
		context
	)


func check_compatibility(
	mod_contract: Dictionary
) -> Dictionary:
	var reasons: Array = []
	var warnings: Array = []
	var compatibility: Dictionary = _dict(
		mod_contract.get(
			"compatibility",
			{}
		)
	)

	var minimum_mod_schema: int = int(
		compatibility.get(
			"min_mod_contract_version",
			1
		)
	)
	if (
		minimum_mod_schema
		> ModContractEngine.MOD_SCHEMA_VERSION
	):
		reasons.append(
			"Requires ModContractEngine schema v%d; runtime supports v%d." % [
				minimum_mod_schema,
				ModContractEngine.MOD_SCHEMA_VERSION
			]
		)

	var provider_versions: Dictionary = _dict(
		compatibility.get(
			"provider_api_versions",
			{}
		)
	)
	for raw_provider_type in provider_versions.keys():
		var provider_type: String = str(
			raw_provider_type
		).strip_edges().to_lower()
		var requested_version: int = int(
			provider_versions.get(
				raw_provider_type,
				1
			)
		)
		var supported_version: int = int(
			ModContractEngine
				.PROVIDER_API_VERSIONS
				.get(
					provider_type,
					0
				)
		)
		if requested_version > supported_version:
			reasons.append(
				"Requires %s provider API v%d; runtime supports v%d." % [
					provider_type,
					requested_version,
					supported_version
				]
			)

	var required_mods: Array = _array(
		mod_contract.get(
			"required_mods",
			[]
		)
	)
	if _law() != null:
		for raw_required in required_mods:
			var required_id: String = _id(
				str(raw_required)
			)
			if (
				required_id != ""
				and not _law().mod_registry.has(
					required_id
				)
			):
				warnings.append(
					"Requires mod '%s'." % required_id
				)

	return {
		"compatible": reasons.is_empty(),
		"reasons": reasons,
		"warnings": warnings,
		"status": (
			"compatible"
			if reasons.is_empty()
			else "incompatible"
		)
	}


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA + ".state",
		"version": ENGINE_VERSION,
		"catalog_revision": catalog_revision,
		"last_report": last_report.duplicate(true)
	}


func import_state(
	data: Dictionary = {}
) -> Dictionary:
	catalog_revision = int(
		data.get(
			"catalog_revision",
			0
		)
	)
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


func _local_catalog_rows() -> Array:
	var rows: Array = []

	if gs == null:
		return rows

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		rows.append_array(
			_array(
				gs.scenario_state.get(
					"mod_marketplace_catalog",
					[]
				)
			)
		)



	if (
		gs.mod_bundle_contract_engine != null
		and gs.mod_bundle_contract_engine.has_method(
			"bundle_catalog_rows"
		)
	):
		rows.append_array(
			gs.mod_bundle_contract_engine
			.bundle_catalog_rows()
		)

	if (
		gs.mod_loader != null
		and gs.mod_loader.has_method(
			"export_registry"
		)
	):
		var loader_registry: Dictionary = _dict(
			gs.mod_loader.export_registry()
		)

		for raw_manifest in _dict(
			loader_registry.get(
				"mod_manifest_registry",
				{}
			)
		).values():
			if typeof(raw_manifest) == TYPE_DICTIONARY:
				rows.append(
					(raw_manifest as Dictionary)
					.duplicate(true)
				)

	return rows


func _network_catalog_rows() -> Array:
	if (
		gs == null
		or typeof(
			gs.scenario_state
		) != TYPE_DICTIONARY
	):
		return []

	return _array(
		gs.scenario_state.get(
			"network_mod_marketplace_catalog",
			[]
		)
	)


func _ingest_catalog_row(
	rows_by_id: Dictionary,
	row: Dictionary,
	source_kind: String
) -> void:
	var mod_id: String = _id(
		str(
			row.get(
				"mod_id",
				row.get(
					"id",
					""
				)
			)
		)
	)
	if mod_id == "":
		return

	var normalized: Dictionary = row.duplicate(true)
	normalized ["mod_id"] = mod_id
	normalized ["id"] = mod_id
	normalized ["name"] = str(
		normalized.get(
			"name",
			mod_id
		)
	)
	normalized ["release_version"] = str(
		normalized.get(
			"release_version",
			normalized.get(
				"marketplace_version",
				"1.0.0"
			)
		)
	)
	normalized ["category"] = str(
		normalized.get(
			"category",
			"systems"
		)
	)
	normalized ["source_kind"] = str(
		normalized.get(
			"source_kind",
			source_kind
		)
	)
	normalized ["downloads"] = int(
		normalized.get(
			"downloads",
			0
		)
	)
	normalized ["rating"] = float(
		normalized.get(
			"rating",
			0.0
		)
	)
	normalized ["featured"] = bool(
		normalized.get(
			"featured",
			false
		)
	)
	normalized ["verified"] = bool(
		normalized.get(
			"verified",
			false
		)
	)

	if rows_by_id.has(mod_id):
		rows_by_id [mod_id] = _merge_catalog_rows(
			_dict(
				rows_by_id.get(
					mod_id,
					{}
				)
			),
			normalized
		)
	else:
		rows_by_id [mod_id] = normalized


func _merge_catalog_rows(
	base: Dictionary,
	incoming: Dictionary
) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for key in incoming.keys():
		var incoming_value: Variant = incoming.get(key)

		if (
			not out.has(key)
			or str(
				out.get(
					key,
					""
				)
			).strip_edges() == ""
		):
			out [key] = incoming_value
		elif key in [
			"downloads",
			"rating"
		]:
			out [key] = max(
				float(
					out.get(
						key,
						0.0
					)
				),
				float(incoming_value)
			)
		elif key in [
			"featured",
			"verified"
		]:
			out [key] = (
				bool(
					out.get(
						key,
						false
					)
				)
				or bool(incoming_value)
			)

	return out


func _rank_score(
	row: Dictionary,
	context: Dictionary
) -> float:
	var score: float = 0.0

	score += clamp(
		float(
			row.get(
				"rating",
				0.0
			)
		),
		0.0,
		5.0
	) * 100.0
	score += log(
		1.0 + max(
			0.0,
			float(
				row.get(
					"downloads",
					0
				)
			)
		)
	) * 20.0
	score += (
		250.0
		if bool(
			row.get(
				"featured",
				false
			)
		)
		else 0.0
	)
	score += (
		100.0
		if bool(
			row.get(
				"verified",
				false
			)
		)
		else 0.0
	)
	score += (
		50.0
		if bool(
			row.get(
				"installed",
				false
			)
		)
		else 0.0
	)
	score -= (
		10000.0
		if not bool(
			_dict(
				row.get(
					"compatibility",
					{}
				)
			).get(
				"compatible",
				true
			)
		)
		else 0.0
	)

	var preferred_types: Array = _array(
		context.get(
			"preferred_provider_types",
			[]
		)
	)
	for raw_type in _array(
		row.get(
			"provider_types",
			[]
		)
	):
		if raw_type in preferred_types:
			score += 35.0

	return score


func _catalog_row_precedes(
	a: Variant,
	b: Variant
) -> bool:
	var left: Dictionary = _dict(a)
	var right: Dictionary = _dict(b)
	var left_score: float = float(
		left.get(
			"rank_score",
			0.0
		)
	)
	var right_score: float = float(
		right.get(
			"rank_score",
			0.0
		)
	)

	if not is_equal_approx(
		left_score,
		right_score
	):
		return left_score > right_score

	return str(
		left.get(
			"mod_id",
			""
		)
	) < str(
		right.get(
			"mod_id",
			""
		)
	)


func _row_matches_search(
	row: Dictionary,
	search_text: String
) -> bool:
	var haystack: String = " ".join([
		str(
			row.get(
				"mod_id",
				""
			)
		),
		str(
			row.get(
				"name",
				""
			)
		),
		str(
			row.get(
				"description",
				""
			)
		),
		str(
			row.get(
				"author",
				""
			)
		),
		str(
			row.get(
				"category",
				""
			)
		),
		str(
			row.get(
				"tags",
				[]
			)
		)
	]).to_lower()

	return search_text in haystack


func _version_is_newer(
	candidate: String,
	installed: String
) -> bool:
	var left: Array = _version_parts(candidate)
	var right: Array = _version_parts(installed)

	for index in range(3):
		var left_value: int = int(left [index])
		var right_value: int = int(right [index])

		if left_value > right_value:
			return true
		if left_value < right_value:
			return false

	return false


func _version_parts(
	value: String
) -> Array:
	var clean: String = str(
		value
	).strip_edges()

	if clean.contains("-"):
		clean = clean.split(
			"-",
			false
		) [0]

	var parts: PackedStringArray = clean.split(
		".",
		false
	)
	var out: Array = [
		0,
		0,
		0
	]

	for index in range(
		min(
			3,
			parts.size()
		)
	):
		out [index] = int(parts [index])

	return out


func _law():
	return (
		gs.mod_contract_engine
		if (
			gs != null
			and gs.mod_contract_engine != null
		)
		else null
	)


func _id(
	value: String
) -> String:
	var clean: String = str(
		value
	).strip_edges().to_lower()
	clean = clean.replace(" ", "_")
	clean = clean.replace("-", "_")
	return clean


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