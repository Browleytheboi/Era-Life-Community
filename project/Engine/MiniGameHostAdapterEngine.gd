extends Resource
class_name MiniGameHostAdapterEngine

const ENGINE_SCHEMA:= "eralife.minigame_host_adapter_engine"
const ENGINE_VERSION:= 1
const STATE_KEY:= "mini_game_host_adapter_state"

var gs: GameState = null
var state: Dictionary = {}


func _init(_gs: GameState = null) -> void:
	bind_game_state(_gs)


func bind_game_state(_gs: GameState) -> void:
	gs = _gs
	_ensure_state()


func enrich_property_space_contract(
	actor: Person,
	property_contract: Dictionary,
	reality_node: Dictionary,
	surface_contract: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var out: Dictionary = (
		surface_contract.duplicate(false)
	)

	var hosts: Array = (
		_hosts_for_property_surface(
			actor,
			property_contract,
			reality_node,
			out,
			context
		)
	)

	if hosts.is_empty():
		out [
			"minigame_hosts"
		] = []
		return out

	var room_actions_raw: Variant = out.get(
		"room_interaction_actions",
		[]
	)

	var room_actions: Array = (
		(room_actions_raw as Array).duplicate(false)
		if typeof(room_actions_raw) == TYPE_ARRAY
		else []
	)

	var current_room_id: String = str(
		out.get(
			"active_room",
			""
		)
	)

	var active_fixture_id: String = str(
		reality_node.get(
			"active_fixture",
			""
		)
	).strip_edges()

	var focus_required_fixture_ids: Dictionary = {}
	var current_room: Dictionary = _dict(
		out.get(
			"current_room",
			{}
		)
	)

	for raw_fixture in _array(
		current_room.get(
			"fixtures",
			[]
		)
	):
		var fixture: Dictionary = _dict(
			raw_fixture
		)
		var fixture_id: String = str(
			fixture.get(
				"fixture_id",
				""
			)
		).strip_edges()

		if (
			fixture_id != ""
			and bool(
				fixture.get(
					"requires_fixture_focus",
					false
				)
			)
		):
			focus_required_fixture_ids [
				fixture_id
			] = true

	var existing_host_action_index_by_fixture: Dictionary = {}

	for action_index in range(
		room_actions.size()
	):
		var raw_action: Variant = room_actions [
			action_index
		]

		if typeof(raw_action) != TYPE_DICTIONARY:
			continue

		var action: Dictionary = (
			raw_action as Dictionary
		)

		var action_id: String = str(
			action.get(
				"action_id",
				""
			)
		)

		var fixture_id: String = str(
			action.get(
				"fixture_id",
				""
			)
		)

		if (
			action_id == "open_minigame_host"
			and fixture_id != ""
		):
			existing_host_action_index_by_fixture [
				fixture_id
			] = action_index

	for raw_host in hosts:
		var host_contract: Dictionary = _dict(
			raw_host
		)

		var fixture_id: String = str(
			host_contract.get(
				"fixture_id",
				""
			)
		)

		if (
			fixture_id != ""
			and focus_required_fixture_ids.has(
				fixture_id
			)
			and active_fixture_id != fixture_id
		):
			continue

		var canonical_action: Dictionary = {
			"action_id": "open_minigame_host",
			"label": str(
				host_contract.get(
					"interaction_label",
					"Play Games"
				)
			),
			"room_id": current_room_id,
			"property_id": int(
				out.get(
					"property_id",
					-1
				)
			),
			"host_id": str(
				host_contract.get(
					"host_id",
					""
				)
			),
			"host_kind": str(
				host_contract.get(
					"host_kind",
					"arcade_machine"
				)
			),
			"fixture_id": fixture_id,
			"fixture_kind": str(
				host_contract.get(
					"host_kind",
					"arcade_machine"
				)
			),
			"provider_id": str(
				host_contract.get(
					"provider_id",
					""
				)
			),
			"multiplayer_mode": str(
				host_contract.get(
					"multiplayer_mode",
					""
				)
			),
			"launch_direct": bool(
				host_contract.get(
					"launch_direct",
					false
				)
			),
			"open_provider_setup": bool(
				host_contract.get(
					"open_provider_setup",
					false
				)
			),
			"tooltip": (
				"Open the persistent MiniGame reality available "
				+ "through this device."
			),
			"disabled": false,
			"intent_type": "minigame",
			"target_engine_property": (
				"mini_game_contract_engine"
			),
			"ui_is_renderer_only": true
		}

		if (
			fixture_id != ""
			and existing_host_action_index_by_fixture.has(
				fixture_id
			)
		):
			var existing_index: int = int(
				existing_host_action_index_by_fixture [
					fixture_id
				]
			)

			var existing_action: Dictionary = _dict(
				room_actions [
					existing_index
				]
			).duplicate(false)



			for canonical_key in canonical_action.keys():
				existing_action [
					canonical_key
				] = canonical_action [
					canonical_key
				]

			room_actions [
				existing_index
			] = existing_action
			continue

		room_actions.append(
			canonical_action
		)

	out [
		"room_interaction_actions"
	] = room_actions
	out [
		"minigame_hosts"
	] = hosts
	out [
		"minigame_host_count"
	] = hosts.size()
	out [
		"minigame_host_authority"
	] = ENGINE_SCHEMA
	out [
		"ui_is_renderer_only"
	] = true


	return out
func resolve_host_contract(actor: Person, payload: Dictionary = {}) -> Dictionary:
	_ensure_state()
	var host_id: String = str(payload.get("host_id", "")).strip_edges()
	var direct: Dictionary = _dict(payload.get("host_contract", {}))

	if not direct.is_empty():
		_register_host(direct)
		return direct.duplicate(true)

	var hosts: Dictionary = _dict(state.get("hosts", {}))
	var host: Dictionary = _dict(hosts.get(host_id, {}))
	if not host.is_empty():
		return host.duplicate(true)

	var host_kind: String = _id(str(payload.get("host_kind", "arcade_machine")))
	return _host_contract(
		actor,
		host_kind,
		str(payload.get("fixture_id", "")),
		int(payload.get("property_id", -1)),
		str(payload.get("room_id", "")),
		payload
	)


func emit_host_catalog(actor: Person, context: Dictionary = {}) -> Dictionary:
	_ensure_state()
	var rows: Array = []
	for raw_host in _dict(state.get("hosts", {})).values():
		var host: Dictionary = _dict(raw_host)
		var owner_actor_id: int = int(host.get("owner_actor_id", -1))
		if actor == null or owner_actor_id in [-1, int(actor.id)]:
			rows.append(host.duplicate(true))
	return {
		"success": true,
		"schema": "eralife.minigame_host_catalog_contract",
		"version": ENGINE_VERSION,
		"actor_id": int(actor.id) if actor != null else -1,
		"rows": rows,
		"context": context.duplicate(true),
		"truth_state": "hot",
		"authoritative_projection": true,
		"ui_is_renderer_only": true
	}


func export_state() -> Dictionary:
	_ensure_state()
	return state.duplicate(true)


func import_state(data: Dictionary) -> Dictionary:
	state = data.duplicate(true)
	_ensure_state()
	_publish_state()
	return { "success": true, "schema": ENGINE_SCHEMA, "version": ENGINE_VERSION}


func _hosts_for_property_surface(
	actor: Person,
	property_contract: Dictionary,
	_reality_node: Dictionary,
	surface_contract: Dictionary,
	context: Dictionary
) -> Array:
	var out: Array = []

	var property_id: int = int(
		surface_contract.get(
			"property_id",
			property_contract.get(
				"id",
				-1
			)
		)
	)

	var room_id: String = str(
		surface_contract.get(
			"active_room",
			""
		)
	)

	var current_room: Dictionary = _dict(
		surface_contract.get(
			"current_room",
			{}
		)
	)

	for raw_fixture in _array(
		current_room.get(
			"fixtures",
			[]
		)
	):
		var fixture: Dictionary = _dict(
			raw_fixture
		)

		var fixture_blob: String = (
			(
				"%s %s %s %s"
				% [
					str(
						fixture.get(
							"fixture_id",
							""
						)
					),
					str(
						fixture.get(
							"title",
							""
						)
					),
					str(
						fixture.get(
							"kind",
							""
						)
					),
					str(
						fixture.get(
							"label",
							""
						)
					)
				]
			)
			.to_lower()
		)

		var host_kind: String = (
			_host_kind_from_blob(
				fixture_blob
			)
		)

		if host_kind == "":
			continue



		var fixture_context: Dictionary = (
			context.duplicate(false)
		)

		for scalar_key in [
			"title",
			"label",
			"surface_text",
			"provider_id",
			"multiplayer_mode"
		]:
			if fixture.has(
				scalar_key
			):
				fixture_context [
					scalar_key
				] = str(
					fixture.get(
						scalar_key,
						""
					)
				)

		for bool_key in [
			"launch_direct",
			"open_provider_setup"
		]:
			if fixture.has(
				bool_key
			):
				fixture_context [
					bool_key
				] = bool(
					fixture.get(
						bool_key,
						false
					)
				)

		out.append(
			_host_contract(
				actor,
				host_kind,
				str(
					fixture.get(
						"fixture_id",
						""
					)
				),
				property_id,
				room_id,
				fixture_context
			)
		)




	return out
func _host_contract(
	actor: Person,
	host_kind: String,
	fixture_id: String,
	property_id: int,
	room_id: String,
	context: Dictionary = {},
	register_host: bool = true
) -> Dictionary:
	var clean_kind: String = _id(
		host_kind
	)
	var clean_fixture: String = _id(
		fixture_id
	)

	if clean_fixture == "":
		clean_fixture = (
			"%s_primary" % clean_kind
		)

	var host_id: String = (
		"minigame_host:%s:%d:%s:%s"
		% [
			clean_kind,
			property_id,
			_id(
				room_id
			),
			clean_fixture
		]
	)

	var host: Dictionary = {
		"schema": "eralife.minigame_host_contract",
		"version": ENGINE_VERSION,
		"host_id": host_id,
		"host_kind": clean_kind,
		"fixture_id": clean_fixture,
		"property_id": property_id,
		"room_id": room_id,
		"owner_actor_id": (
			int(
				actor.id
			)
			if actor != null
			else -1
		),
		"title": str(
			context.get(
				"title",
				_host_title(
					clean_kind
				)
			)
		),
		"interaction_label": str(
			context.get(
				"label",
				_interaction_label(
					clean_kind
				)
			)
		),


		"provider_id": _id(
			str(
				context.get(
					"provider_id",
					""
				)
			)
		),
		"multiplayer_mode": str(
			context.get(
				"multiplayer_mode",
				""
			)
		),
		"launch_direct": bool(
			context.get(
				"launch_direct",
				false
			)
		),
		"open_provider_setup": bool(
			context.get(
				"open_provider_setup",
				false
			)
		),

		"supported_provider_categories": (
			_categories_for_host(
				clean_kind
			)
		),
		"network_capabilities": {
			"split_screen": (
				clean_kind not in [
					"phone"
				]
			),
			"spectators": true,
			"tournaments": (
				clean_kind in [
					"arcade_machine",
					"internet_cafe_terminal",
					"future_vr_center",
					"holographic_device"
				]
			)
		},
		"virtual_fixture_projected": bool(
			context.get(
				"virtual_fixture_projected",
				false
			)
		),
		"ui_is_renderer_only": true
	}

	if register_host:
		_register_host(
			host
		)

	return host
func project_host_contract(
	actor: Person,
	payload: Dictionary = {}
) -> Dictionary:
	_ensure_state()

	var direct: Dictionary = _dict(
		payload.get(
			"host_contract",
			{}
		)
	)

	if not direct.is_empty():
		return direct.duplicate(false)

	var host_id: String = str(
		payload.get(
			"host_id",
			""
		)
	).strip_edges()

	if host_id != "":
		var hosts: Dictionary = _dict(
			state.get(
				"hosts",
				{}
			)
		)

		var resident_host: Dictionary = _dict(
			hosts.get(
				host_id,
				{}
			)
		)

		if not resident_host.is_empty():
			return resident_host.duplicate(false)

	var host_kind: String = _id(
		str(
			payload.get(
				"host_kind",
				"arcade_machine"
			)
		)
	)

	return _host_contract(
		actor,
		host_kind,
		str(
			payload.get(
				"fixture_id",
				""
			)
		),
		int(
			payload.get(
				"property_id",
				-1
			)
		),
		str(
			payload.get(
				"room_id",
				""
			)
		),
		payload,
		false
	)

func _register_host(host: Dictionary) -> void:
	var host_id: String = str(host.get("host_id", "")).strip_edges()
	if host_id == "":
		return
	var hosts: Dictionary = _dict(state.get("hosts", {}))
	hosts [host_id] = host.duplicate(true)
	state ["hosts"] = hosts
	if gs != null:
		if typeof(gs.entity_registry) != TYPE_DICTIONARY:
			gs.entity_registry = {}
		gs.entity_registry [host_id] = {
			"entity_id": host_id,
			"entity_kind": "minigame_host",
			"name": str(host.get("title", "MiniGame Host")),
			"host_kind": str(host.get("host_kind", "")),
			"property_id": int(host.get("property_id", -1)),
			"room_id": str(host.get("room_id", "")),
			"persistent": true,
			"observable": true
		}
	_publish_state()


func _host_kind_from_blob(blob: String) -> String:
	if blob.find("arcade") != -1 or blob.find("pinball") != -1:
		return "arcade_machine"
	if blob.find("school") != -1 and blob.find("computer") != -1:
		return "school_computer"
	if blob.find("internet") != -1 and blob.find("terminal") != -1:
		return "internet_cafe_terminal"
	if blob.find("console") != -1:
		return "home_console"
	if blob.find("computer") != -1 or blob.find("laptop") != -1:
		return "computer"
	if blob.find("phone") != -1:
		return "phone"
	if blob.find("television") != -1 or blob.find(" tv") != -1:
		return "television"
	if blob.find("vr") != -1:
		return "future_vr_center"
	if blob.find("holog") != -1:
		return "holographic_device"
	return ""


func _host_title(host_kind: String) -> String:
	match host_kind:
		"arcade_machine":
			return "Arcade Machine"
		"home_console":
			return "Home Console"
		"school_computer":
			return "School Computer"
		"internet_cafe_terminal":
			return "Internet Café Terminal"
		"phone":
			return "Phone"
		"television":
			return "Television Game Surface"
		"future_vr_center":
			return "Future VR Center"
		"holographic_device":
			return "Holographic Game Device"
		_:
			return "Computer"


func _interaction_label(host_kind: String) -> String:
	match host_kind:
		"arcade_machine":
			return "PLAY ARCADE MACHINE"
		"future_vr_center":
			return "ENTER VR GAME REALITY"
		"holographic_device":
			return "ACTIVATE HOLOGRAPHIC GAME"
		_:
			return "OPEN AVAILABLE GAMES"


func _categories_for_host(host_kind: String) -> Array:
	match host_kind:
		"arcade_machine":
			return ["fighting", "pinball", "air_hockey", "basketball", "rhythm", "retro"]
		"phone":
			return ["puzzle", "rhythm", "retro", "fishing"]
		"television", "home_console":
			return ["fighting", "sports", "rhythm", "puzzle", "retro"]
		_:
			return [
				"fighting",
				"fishing",
				"pool",
				"air_hockey",
				"pinball",
				"basketball",
				"rhythm",
				"puzzle",
				"retro"
			]


func _ensure_state() -> void:
	if state.is_empty() and gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		state = _dict(gs.scenario_state.get(STATE_KEY, {})).duplicate(true)
	if state.is_empty():
		state = {
			"schema": ENGINE_SCHEMA,
			"version": ENGINE_VERSION,
			"hosts": {},
			"updated_at_ms": int(Time.get_ticks_msec())
		}
	if typeof(state.get("hosts", {})) != TYPE_DICTIONARY:
		state ["hosts"] = {}


func _publish_state() -> void:
	state ["updated_at_ms"] = int(Time.get_ticks_msec())
	if gs == null:
		return
	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}
	gs.scenario_state [STATE_KEY] = state.duplicate(true)


func _id(value: String) -> String:
	return str(value).strip_edges().to_lower()


func _dict(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}


func _array(value: Variant) -> Array:
	return value as Array if typeof(value) == TYPE_ARRAY else []