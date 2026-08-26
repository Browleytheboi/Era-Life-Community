extends Resource
class_name PopulationLensViewer

const VIEWER_SCHEMA:= "eralife.population_lens_viewer"
const CONTRACT_VERSION:= 1

var host: Node = null


func bind_host(_host: Node) -> void:
	host = _host


func has_host() -> bool:
	return host != null and is_instance_valid(host)


func prepare_view_contract(
	view_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if view_contract.is_empty():
		return {}

	var incremental_renderer: bool = bool(
		context.get(
			"incremental_renderer",
			view_contract.get(
				"incremental_renderer_delta",
				false
			)
		)
	)
	var prepared: Dictionary = (
		view_contract.duplicate(
			not incremental_renderer
		)
	)
	var policy: Dictionary = (
		_default_lod_policy()
	)
	var policy_raw: Variant = context.get(
		"lod_policy",
		prepared.get(
			"lod_policy",
			{}
		)
	)

	if typeof(policy_raw) == TYPE_DICTIONARY:
		for raw_key in (
			policy_raw as Dictionary
		).keys():
			policy [
				raw_key
			] = (
				policy_raw as Dictionary
			).get(
				raw_key
			)

	prepared [
		"population_lens_schema"
	] = VIEWER_SCHEMA
	prepared [
		"population_lens_version"
	] = CONTRACT_VERSION
	prepared [
		"viewer_owns_visual_projection"
	] = true
	prepared [
		"ui_is_renderer_only"
	] = true
	prepared [
		"contracts_own_truth"
	] = true
	prepared [
		"viewer_owns_how_truth_is_seen"
	] = true
	prepared [
		"lod_policy"
	] = policy.duplicate(false)

	var temporal_year: int = int(
		context.get(
			"temporal_year",
			context.get(
				"render_year",
				prepared.get(
					"built_for_year",
					-999999
				)
			)
		)
	)

	if temporal_year != -999999:
		prepared [
			"temporal_filter_year"
		] = temporal_year

	if incremental_renderer:
		prepared [
			"incremental_renderer"
		] = true
		prepared [
			"graph_normalization_per_card_forbidden"
		] = true
		prepared [
			"deep_contract_copy_per_card"
		] = false

		return prepared

	prepared [
		"graph_node_contracts"
	] = _normalized_graph_contracts(
		prepared.get(
			"graph_node_contracts",
			{}
		),
		temporal_year
	)

	return prepared


func build_realm_population_surface(
	realm_id: int,
	realm_name: String,
	view_contract: Dictionary,
	context: Dictionary = {}
) -> Control:
	if not has_host():
		return null
	if realm_id <= 0 or view_contract.is_empty():
		return null

	var reason: String = str(context.get("reason", "population_lens_viewer_prewarm")).strip_edges()
	if reason == "":
		reason = "population_lens_viewer_prewarm"

	var prepared_contract: Dictionary = prepare_view_contract(view_contract, context)
	if prepared_contract.is_empty():
		return null

	var surface: Control = _build_surface_from_contract(
		realm_id,
		realm_name,
		prepared_contract,
		reason
	)
	if surface == null:
		return null

	_stamp_surface(surface, realm_id, realm_name, prepared_contract, context)
	_stamp_prebound_graph_nodes(surface, prepared_contract)
	_prime_surface_graph_state(surface, prepared_contract, context)

	return surface
func apply_incremental_realm_population_contract(
	surface: Control,
	realm_id: int,
	realm_name: String,
	view_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if not has_host():
		return {
			"success": false,
			"reason": "missing_host",
			"ui_is_renderer_only": true
		}

	if (
		surface == null
		or not is_instance_valid(
			surface
		)
		or realm_id <= 0
		or view_contract.is_empty()
	):
		return {
			"success": false,
			"reason": (
				"invalid_incremental_projection_request"
			),
			"realm_id": realm_id,
			"ui_is_renderer_only": true
		}

	var prepared_contract: Dictionary = (
		prepare_view_contract(
			view_contract,
			context
		)
	)
	if prepared_contract.is_empty():
		return {
			"success": false,
			"reason": "prepared_contract_empty",
			"realm_id": realm_id,
			"ui_is_renderer_only": true
		}

	var result_raw: Variant = _call_host(
		(
			"_population_lens_viewer_apply_incremental_"
			+ "realm_population_contract"
		),
		[
			surface,
			realm_id,
			realm_name,
			prepared_contract,
			context
		]
	)

	if typeof(result_raw) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": (
				"host_incremental_projection_missing"
			),
			"realm_id": realm_id,
			"ui_is_renderer_only": true
		}



	return result_raw as Dictionary
func prime_graph_projection(view_contract: Dictionary, accent: Color, context: Dictionary = {}) -> void:
	if not has_host():
		return

	var prepared_contract: Dictionary = prepare_view_contract(view_contract, context)
	if prepared_contract.is_empty():
		return

	_call_host("_prime_crown_population_graph_render_pass", [prepared_contract, accent])

	var layer_raw: Variant = _call_host("_crown_population_graph_layer", [true])
	if layer_raw is Control:
		var layer: Control = layer_raw as Control
		_apply_graph_policy_to_layer(layer, prepared_contract)
		layer.set_meta("population_lens_graph_curve_mode", "bezier")
		layer.set_meta("population_lens_graph_anchor_points", ["left", "right", "top", "bottom"])
		layer.set_meta("population_lens_graph_line_weight_represents_bond", true)
		layer.set_meta("population_lens_graph_hover_fade_enabled", true)
		layer.set_meta("population_lens_graph_active_node_glow_enabled", true)
		layer.set_meta("population_lens_graph_connected_node_soft_glow_enabled", true)
		layer.set_meta("population_lens_graph_background_fade_alpha", 0.4)
		layer.set_meta("population_lens_graph_flow_animation_enabled", true)
		layer.set_meta("population_lens_graph_particles_enabled", true)
		layer.set_meta("population_lens_graph_parallel_lane_separation_enabled", true)
		layer.set_meta("population_lens_graph_expanded_mode_renders_all_edges", true)

func rebind_graph_nodes_from_surface(surface: Control) -> void:
	if surface == null or not is_instance_valid(surface):
		return
	if not has_host():
		return

	var graph_nodes: Dictionary = {}
	if surface.has_meta("population_lens_graph_nodes_prebound"):
		var nodes_raw: Variant = surface.get_meta("population_lens_graph_nodes_prebound", {})
		if typeof(nodes_raw) == TYPE_DICTIONARY:
			graph_nodes = (nodes_raw as Dictionary).duplicate(true)

	var view_contract: Dictionary = {}
	if surface.has_meta("population_lens_view_contract"):
		var contract_raw: Variant = surface.get_meta("population_lens_view_contract", {})
		if typeof(contract_raw) == TYPE_DICTIONARY:
			view_contract = (contract_raw as Dictionary).duplicate(true)

	if not graph_nodes.is_empty():
		var commit_result: Variant = _call_host(
			"_population_lens_viewer_commit_graph_node_index",
			[
				graph_nodes,
				view_contract
			]
		)
		if typeof(commit_result) == TYPE_DICTIONARY and bool((commit_result as Dictionary).get("success", false)):
			return

	_call_host("_rebind_crown_population_graph_nodes_from_surface", [surface])
func _build_surface_from_contract(
	realm_id: int,
	realm_name: String,
	view_contract: Dictionary,
	reason: String
) -> Control:
	var direct_surface_raw: Variant = _call_host(
		"_population_lens_viewer_build_realm_population_surface",
		[
			realm_id,
			realm_name,
			view_contract,
			reason
		]
	)
	if direct_surface_raw is Control:
		return direct_surface_raw as Control

	var legacy_surface_raw: Variant = _call_host(
		"_build_crown_population_ecosystem_surface_node",
		[
			realm_id,
			realm_name,
			view_contract,
			reason
		]
	)
	if legacy_surface_raw is Control:
		return legacy_surface_raw as Control

	return null


func _prime_surface_graph_state(
	surface: Control,
	view_contract: Dictionary,
	context: Dictionary = {}
) -> void:
	if surface == null or not is_instance_valid(surface):
		return

	var lod_policy: Dictionary = view_contract.get("lod_policy", {}) if typeof(view_contract.get("lod_policy", {})) == TYPE_DICTIONARY else _default_lod_policy()
	var graph_contracts: Dictionary = view_contract.get("graph_node_contracts", {}) if typeof(view_contract.get("graph_node_contracts", {})) == TYPE_DICTIONARY else {}

	surface.set_meta("population_lens_surface_ready", true)
	surface.set_meta("population_lens_surface_prebuilt_before_press", true)
	surface.set_meta("population_lens_surface_click_path_build_forbidden", true)
	surface.set_meta("population_lens_graph_contracts_prepared", graph_contracts.duplicate(true))
	surface.set_meta("population_lens_graph_lod_policy", lod_policy.duplicate(true))
	surface.set_meta("population_lens_graph_curve_mode", "bezier")
	surface.set_meta("population_lens_graph_anchor_points", ["left", "right", "top", "bottom"])
	surface.set_meta("population_lens_graph_line_weight_represents_bond", true)
	surface.set_meta("population_lens_graph_hover_fade_enabled", true)
	surface.set_meta("population_lens_graph_flow_animation_enabled", true)
	surface.set_meta("population_lens_graph_parallel_lane_separation_enabled", true)
	surface.set_meta("population_lens_graph_expanded_mode_renders_all_edges", true)
	surface.set_meta("population_lens_context", context.duplicate(true))


func _stamp_surface(
	surface: Control,
	realm_id: int,
	realm_name: String,
	view_contract: Dictionary,
	context: Dictionary = {}
) -> void:
	if surface == null or not is_instance_valid(surface):
		return

	var policy: Dictionary = view_contract.get("lod_policy", {}) if typeof(view_contract.get("lod_policy", {})) == TYPE_DICTIONARY else _default_lod_policy()

	surface.set_meta("population_lens_viewer", true)
	surface.set_meta("population_lens_viewer_schema", VIEWER_SCHEMA)
	surface.set_meta("population_lens_viewer_version", CONTRACT_VERSION)
	surface.set_meta("population_lens_context", context.duplicate(true))
	surface.set_meta("population_lens_realm_id", realm_id)
	surface.set_meta("population_lens_realm_name", str(realm_name).strip_edges())
	surface.set_meta("population_lens_view_contract", view_contract.duplicate(true))
	surface.set_meta("population_lens_lod_policy", policy.duplicate(true))
	surface.set_meta("population_lens_temporal_year", int(view_contract.get("temporal_filter_year", view_contract.get("built_for_year", -999999))))
	surface.set_meta("population_lens_ui_build_on_press_forbidden", true)
	surface.set_meta("population_lens_click_path_reveal_only", true)
	surface.set_meta("population_lens_contracts_own_truth", true)
	surface.set_meta("population_lens_viewer_owns_visual_projection", true)

func _stamp_prebound_graph_nodes(surface: Control, view_contract: Dictionary) -> void:
	if surface == null or not is_instance_valid(surface):
		return

	var nodes: Dictionary = {}
	_collect_prebound_graph_nodes_from_surface(surface, nodes)

	var graph_contracts: Dictionary = {}
	if typeof(view_contract.get("graph_node_contracts", {})) == TYPE_DICTIONARY:
		graph_contracts = view_contract.get("graph_node_contracts", {}).duplicate(true)

	surface.set_meta("population_lens_graph_nodes_prebound", nodes)
	surface.set_meta("population_lens_graph_nodes_prebound_count", nodes.size())
	surface.set_meta("population_lens_graph_contracts_prepared", graph_contracts)
	surface.set_meta("population_lens_graph_nodes_indexed_during_prewarm", true)
	surface.set_meta("population_lens_graph_click_path_scan_forbidden", true)
	surface.set_meta("population_lens_graph_click_path_rebind_forbidden", true)


func _collect_prebound_graph_nodes_from_surface(root: Node, out: Dictionary) -> void:
	if root == null:
		return

	if root is PanelContainer and root.has_meta("crown_population_graph_node_contract"):
		var node_raw: Variant = root.get_meta("crown_population_graph_node_contract", {})
		if typeof(node_raw) == TYPE_DICTIONARY:
			var node_contract: Dictionary = node_raw
			var entity_id: String = str(node_contract.get("entity_id", "")).strip_edges()

			if entity_id != "":
				node_contract ["card"] = root
				node_contract ["population_lens_prebound"] = true
				node_contract ["population_lens_bound_during_prewarm"] = true
				out [entity_id] = node_contract

	for child in root.get_children():
		_collect_prebound_graph_nodes_from_surface(child, out)
func _apply_graph_policy_to_layer(layer: Control, view_contract: Dictionary) -> void:
	if layer == null or not is_instance_valid(layer):
		return

	var policy: Dictionary = view_contract.get("lod_policy", {}) if typeof(view_contract.get("lod_policy", {})) == TYPE_DICTIONARY else _default_lod_policy()

	layer.set_meta("population_lens_graph_layer", true)
	layer.set_meta("population_lens_graph_lod_policy", policy.duplicate(true))
	layer.set_meta("population_lens_hover_lod_max_edges", int(policy.get("hover_max_edges", 5)))
	layer.set_meta("population_lens_expanded_lod_max_edges", int(policy.get("expanded_max_edges", 9999)))
	layer.set_meta("population_lens_importance_weighting_enabled", true)
	layer.set_meta("population_lens_temporal_filter_year", int(view_contract.get("temporal_filter_year", view_contract.get("built_for_year", -999999))))
	layer.set_meta("population_lens_projection_space", "scroll_viewport")
	layer.set_meta("population_lens_viewer_owns_graph_projection", true)


func _normalized_graph_contracts(graph_contracts_raw: Variant, temporal_year: int = -999999) -> Dictionary:
	if typeof(graph_contracts_raw) != TYPE_DICTIONARY:
		return {}

	var graph_contracts: Dictionary = graph_contracts_raw as Dictionary
	var out: Dictionary = {}

	for raw_entity_id in graph_contracts.keys():
		var entity_id: String = str(raw_entity_id).strip_edges()
		if entity_id == "":
			continue

		var contract_raw: Variant = graph_contracts.get(raw_entity_id, {})
		if typeof(contract_raw) != TYPE_DICTIONARY:
			continue

		var contract: Dictionary = (contract_raw as Dictionary).duplicate(true)
		var edges_raw: Variant = contract.get("edges", [])
		var normalized_edges: Array = []

		if typeof(edges_raw) == TYPE_ARRAY:
			for raw_edge in edges_raw as Array:
				if typeof(raw_edge) != TYPE_DICTIONARY:
					continue

				var edge: Dictionary = (raw_edge as Dictionary).duplicate(true)
				if not _edge_is_temporally_visible(edge, temporal_year):
					continue

				var line_kind: String = _line_kind_from_edge(edge)
				var importance: float = _importance_weight_for_edge(edge)

				edge ["line_kind"] = line_kind
				edge ["importance_weight"] = importance
				edge ["lod_score"] = _lod_score_for_edge(edge, importance)
				edge ["population_lens_weighted"] = true
				edge ["population_lens_temporal_year"] = temporal_year

				normalized_edges.append(edge)

		normalized_edges.sort_custom(func (a, b):
			return float((a as Dictionary).get("lod_score", 0.0)) > float((b as Dictionary).get("lod_score", 0.0))
		)

		contract ["edges"] = normalized_edges
		contract ["edge_count"] = normalized_edges.size()
		contract ["population_lens_normalized"] = true
		contract ["population_lens_schema"] = VIEWER_SCHEMA
		out [entity_id] = contract

	return out


func _edge_is_temporally_visible(edge: Dictionary, temporal_year: int) -> bool:
	if temporal_year == -999999:
		return true

	var from_year: int = int(edge.get("from_year", edge.get("valid_from_year", edge.get("started_year", -999999))))
	var to_year: int = int(edge.get("to_year", edge.get("valid_to_year", edge.get("ended_year", 999999))))

	if from_year != -999999 and temporal_year < from_year:
		return false
	if to_year != 999999 and temporal_year > to_year:
		return false

	return true


func _line_kind_from_edge(edge: Dictionary) -> String:
	var line_kind: String = str(edge.get("line_kind", "relationship")).strip_edges().to_lower()
	if line_kind != "" and line_kind != "relationship":
		return line_kind

	var tags: Array = edge.get("tags", []) if typeof(edge.get("tags", [])) == TYPE_ARRAY else []
	var label: String = str(edge.get("relationship_label", edge.get("label", ""))).strip_edges().to_lower()

	if _tags_have_any(tags, ["parent", "child", "sibling", "family"]) or label in ["parent", "child", "sibling", "mother", "father", "son", "daughter"]:
		return "family"
	if _tags_have_any(tags, ["spouse", "partner", "romance", "married", "dating"]) or label in ["spouse", "partner", "wife", "husband"]:
		return "romance"
	if _tags_have_any(tags, ["succession_heir", "heir", "line_of_succession"]):
		return "succession_heir"
	if _tags_have_any(tags, ["enemy", "rival", "conflict"]):
		return "conflict"
	if _tags_have_any(tags, ["political", "royal", "court", "noble", "realm"]):
		return "political"
	if _tags_have_any(tags, ["friend", "ally", "social"]):
		return "social"
	if _tags_have_any(tags, ["coworker", "market", "economic", "trade"]):
		return "economic"
	if _tags_have_any(tags, ["civic", "countryfolk", "same_city", "class_tie"]):
		return "civic"

	return "relationship"


func _importance_weight_for_edge(edge: Dictionary) -> float:
	var line_kind: String = _line_kind_from_edge(edge)
	var tags: Array = edge.get("tags", []) if typeof(edge.get("tags", [])) == TYPE_ARRAY else []
	var label: String = str(edge.get("relationship_label", edge.get("label", ""))).strip_edges().to_lower()

	if line_kind == "succession_heir":
		return 1.0
	if line_kind == "family" and (_tags_have_any(tags, ["parent", "child"]) or label in ["parent", "child", "mother", "father", "son", "daughter"]):
		return 0.97
	if line_kind == "romance":
		return 0.92
	if line_kind == "family":
		return 0.88
	if line_kind == "conflict":
		return 0.84
	if line_kind == "political":
		return 0.76
	if line_kind == "house":
		return 0.7
	if line_kind == "economic":
		return 0.58
	if line_kind == "social":
		return 0.46
	if line_kind == "civic":
		return 0.34

	return 0.22


func _lod_score_for_edge(edge: Dictionary, importance: float) -> float:
	var bond: float = float(clampi(int(edge.get("bond", 50)), 0, 100))
	var contract_weight: float = float(edge.get("weight", 1.0))
	return bond + (importance * 75.0) + (contract_weight * 8.0)


func _tags_have_any(tags: Array, wanted: Array) -> bool:
	for raw_tag in tags:
		var tag: String = str(raw_tag).strip_edges().to_lower()
		if wanted.has(tag):
			return true
	return false


func _default_lod_policy() -> Dictionary:
	return {
		"hover_max_edges": 5,
		"expanded_max_edges": 9999,
		"contracts_own_truth": true,
	}

func _call_host(method_name: String, args: Array = []) -> Variant:
	if not has_host():
		return null
	if not host.has_method(method_name):
		return null
	return host.callv(method_name, args)