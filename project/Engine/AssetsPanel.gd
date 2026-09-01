extends PanelContainer
class_name AssetsPanel

signal close_requested
signal action_requested(
	action_id: String,
	payload: Dictionary
)

const PANEL_SCHEMA:= "eralife.assets.panel"
const CONTRACT_VERSION:= 1

var host: Node = null
var gs: GameState = null
var actor: Person = null
var active_contract: Dictionary = {}
var active_render_signature: String = ""

var title_label: Label = null
var subtitle_label: Label = null
var wealth_label: Label = null
var status_label: Label = null
var action_grid: GridContainer = null
var faction_list: VBoxContainer = null
var vehicle_list: VBoxContainer = null
var property_list: VBoxContainer = null
var securities_label: Label = null


func _ready() -> void:
	_ensure_surface()


func bind_host(
	_host: Node,
	_gs: GameState = null
) -> void:
	host = _host
	gs = _gs

	# The panel reported count:0 while the resumed runtime held the vehicles, so the
	# panel and the restore are looking at different GameStates. Report which one this
	# binds to, and what it can actually see.
	EraLog.truth(
		"ERALIFE_ASSETS_BIND|gs=%s|vehicle_engine=%s|vehicle_rows=%d|player_id=%s"
		% [
			str(_gs.get_instance_id()) if _gs != null else "<null>",
			str(_gs != null and _gs.vehicle_engine != null),
			(
				_gs.vehicle_engine.vehicles.size()
				if _gs != null and _gs.vehicle_engine != null and typeof(_gs.vehicle_engine.vehicles) == TYPE_DICTIONARY
				else -1
			),
			str(_gs.player_id) if _gs != null else "-"
		]
	)

	# Print the actual owner keys and their types. If the store holds "1" (String)
	# while player_id is 1 (int), every lookup misses and the contract reports count:0
	# even though the data is present.
	if _gs != null and _gs.vehicle_engine != null and typeof(_gs.vehicle_engine.vehicles) == TYPE_DICTIONARY:
		var key_report: Array = []

		for raw_key in _gs.vehicle_engine.vehicles.keys():
			key_report.append("%s(%s)" % [str(raw_key), type_string(typeof(raw_key))])

		EraLog.truth(
			"ERALIFE_ASSETS_KEYS|gs=%s|owner_keys=%s|player_id_type=%s|direct_lookup_rows=%d"
			% [
				str(_gs.get_instance_id()),
				str(key_report),
				type_string(typeof(_gs.player_id)),
				_safe_array(_gs.vehicle_engine.vehicles.get(int(_gs.player_id), [])).size()
			]
		)

	_ensure_surface()


func open_for_actor(
	target_actor: Person,
	surface_contract: Dictionary = {}
) -> void:
	actor = target_actor
	_ensure_surface()

	if not surface_contract.is_empty():
		render_surface_contract(
			surface_contract
		)

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_INHERIT
func open_observable_partial(
	target_actor: Person,
	status_text: String = (
		"Asset truth is publishing live."
	)
) -> void:
	actor = target_actor
	_ensure_surface()

	var actor_id: int = (
		int(target_actor.id)
		if target_actor != null
		else -1
	)
	var actor_name: String = (
		(
			"%s %s"
			% [
				target_actor.first_name,
				target_actor.last_name
			]
		).strip_edges()
		if target_actor != null
		else "this life"
	)
	var bank_balance: int = (
		int(target_actor.bank_balance)
		if target_actor != null
		else 0
	)
	var bank_balance_text: String = (
		"$%d USD" % bank_balance
	)

	if (
		gs != null
		and gs.economy_engine != null
	):
		bank_balance_text = (
			gs.economy_engine.format_money(
				bank_balance
			)
		)

	render_surface_contract({
		"success": true,
		"schema": (
			"eralife.assets.surface.observable_partial"
		),
		"version": 1,
		"actor_id": actor_id,
		"actor_name": actor_name,
		"actor_age": (
			int(target_actor.age)
			if target_actor != null
			else -1
		),
		"title": "ASSETS • WEALTH",
		"subtitle": (
			"Property, mobility, and wealth truth for %s are publishing live."
			% actor_name
		),
		"bank_balance": bank_balance,
		"bank_balance_text": bank_balance_text,
		"property_rollup": {},
		"vehicle_rollup": {},
		"property_asset_rows": [],
		"vehicle_asset_rows": [],
		"faction_pressure_rows": [],
		"actions": [
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
		],
		"markets_and_securities_text": (
			"Market and securities truth will appear without requiring another click."
		),
		"total_asset_count": 0,
		"truth_state": "observable_partial",
		"status_text": status_text,
		"surface_signature": (
			"observable_partial_assets:%d:%d"
			% [
				actor_id,
				int(
					Time.get_ticks_msec()
				)
			]
		),
		"ui_is_renderer_only": true
	})

	if wealth_label != null:
		wealth_label.text = (
			"Available Wealth: %s • Controlled Assets: Publishing…"
			% bank_balance_text
		)

	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_INHERIT

	set_meta(
		"assets_surface_observable_partial",
		true
	)
	set_meta(
		"assets_surface_observable_partial_actor_id",
		actor_id
	)
	set_meta(
		"assets_surface_observable_partial_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
	set_meta(
		"assets_progressive_patch_property_started",
		false
	)
	set_meta(
		"assets_progressive_patch_vehicle_started",
		false
	)
	set_meta(
		"assets_progressive_patch_faction_started",
		false
	)
	set_meta(
		"assets_progressive_patch_property_count",
		0
	)
	set_meta(
		"assets_progressive_patch_vehicle_count",
		0
	)
func apply_progressive_surface_patch(
	patch: Dictionary
) -> void:
	if patch.is_empty():
		return

	_ensure_surface()

	var patch_actor_id: int = int(
		patch.get(
			"actor_id",
			-1
		)
	)

	if (
		actor != null
		and patch_actor_id > 0
		and patch_actor_id != int(actor.id)
	):
		return

	var patch_kind: String = str(
		patch.get(
			"patch_kind",
			""
		)
	).strip_edges().to_lower()

	match patch_kind:
		"head":
			var bank_text: String = str(
				patch.get(
					"bank_balance_text",
					""
				)
			)

			if bank_text != "":
				active_contract [
					"bank_balance_text"
				] = bank_text

			var actions_raw: Variant = patch.get(
				"actions",
				[]
			)

			if typeof(actions_raw) == TYPE_ARRAY:
				active_contract [
					"actions"
				] = actions_raw
				_render_actions()

			if wealth_label != null:
				wealth_label.text = (
					"Available Wealth: %s • Controlled Assets: Publishing…"
					% bank_text
				)

		"property_row":
			var property_raw: Variant = patch.get(
				"property_row",
				{}
			)

			if typeof(property_raw) != TYPE_DICTIONARY:
				return

			var property_row: Dictionary = (
				property_raw as Dictionary
			)

			var property_id: int = int(
				property_row.get(
					"asset_id",
					property_row.get(
						"property_id",
						-1
					)
				)
			)

			if property_id <= 0:
				return

			if not bool(
				get_meta(
					"assets_progressive_patch_property_started",
					false
				)
			):
				_clear_children(
					property_list
				)

				set_meta(
					"assets_progressive_patch_property_started",
					true
				)

			var card_preexisted: bool = (
				_property_asset_card_for_id(
					property_id
				) != null
			)

			_upsert_property_asset_card(
				property_row
			)

			if not card_preexisted:
				set_meta(
					"assets_progressive_patch_property_count",
					int(
						get_meta(
							"assets_progressive_patch_property_count",
							0
						)
					) + 1
				)
		"property_destination":
			_apply_property_destination_patch(
				patch
			)
		"vehicle_row":
			var vehicle_raw: Variant = patch.get(
				"vehicle_row",
				{}
			)

			if typeof(vehicle_raw) != TYPE_DICTIONARY:
				return

			var vehicle_row: Dictionary = (
				vehicle_raw as Dictionary
			)
			var vehicle_id: int = int(
				vehicle_row.get(
					"asset_id",
					-1
				)
			)

			if vehicle_id <= 0:
				return

			if not bool(
				get_meta(
					"assets_progressive_patch_vehicle_started",
					false
				)
			):
				_clear_children(
					vehicle_list
				)
				set_meta(
					"assets_progressive_patch_vehicle_started",
					true
				)

			# FIX: the clear above only runs once per panel lifetime, because
			# "assets_progressive_patch_vehicle_started" is set and never reset. On
			# every later visit to Assets the clear was skipped and this line appended
			# another card for the same vehicle -- one extra canoe per visit. Resetting
			# the flag on open handles the normal path; this guard makes the append
			# safe regardless of when the flag happens to be set.
			if not _card_exists_for_asset(
				vehicle_list,
				int(
					vehicle_row.get(
						"asset_id",
						vehicle_row.get(
							"id",
							-1
						)
					)
				)
			):
				vehicle_list.add_child(
					_asset_card(
						vehicle_row,
						Color(
							0.4,
							0.82,
							1.0,
							1.0
						),
						[
							{
								"action_id": "open_vehicle_asset",
								"label": "View Vehicle",
								"icon": " ",
								"asset_id": vehicle_id
							}
						]
					)
				)

			set_meta(
				"assets_progressive_patch_vehicle_count",
				int(
					get_meta(
						"assets_progressive_patch_vehicle_count",
						0
					)
				) + 1
			)

		"faction_row":
			var faction_raw: Variant = patch.get(
				"faction_row",
				{}
			)

			if typeof(faction_raw) != TYPE_DICTIONARY:
				return

			if not bool(
				get_meta(
					"assets_progressive_patch_faction_started",
					false
				)
			):
				_clear_children(
					faction_list
				)
				set_meta(
					"assets_progressive_patch_faction_started",
					true
				)

			_append_progressive_faction_row(
				faction_raw as Dictionary
			)

		"complete":
			var final_contract_raw: Variant = patch.get(
				"surface_contract",
				{}
			)

			if typeof(final_contract_raw) == TYPE_DICTIONARY:
				active_contract = (
					final_contract_raw as Dictionary
				).duplicate(false)

			var property_count: int = int(
				patch.get(
					"property_count",
					0
				)
			)
			var vehicle_count: int = int(
				patch.get(
					"vehicle_count",
					0
				)
			)

			if (
				property_count <= 0
				and not bool(
					get_meta(
						"assets_progressive_patch_property_started",
						false
					)
				)
			):
				_clear_children(
					property_list
				)
				property_list.add_child(
					_info_label(
						"No controlled real estate is currently observable."
					)
				)

			if (
				vehicle_count <= 0
				and not bool(
					get_meta(
						"assets_progressive_patch_vehicle_started",
						false
					)
				)
			):
				_clear_children(
					vehicle_list
				)
				vehicle_list.add_child(
					_info_label(
						"No controlled mobility assets."
					)
				)

			var bank_text: String = str(
				active_contract.get(
					"bank_balance_text",
					""
				)
			)

			if wealth_label != null:
				wealth_label.text = (
					"Available Wealth: %s • Controlled Assets: %d"
					% [
						bank_text,
						property_count + vehicle_count
					]
				)

			if status_label != null:
				status_label.text = (
					"Asset truth is live."
				)

			set_meta(
				"assets_progressive_patch_complete",
				true
			)
			set_meta(
				"assets_progressive_patch_completed_at_ms",
				int(
					Time.get_ticks_msec()
				)
			)

		_:
			return

	set_meta(
		"assets_progressive_patch_last_kind",
		patch_kind
	)
	set_meta(
		"assets_progressive_patch_last_at_ms",
		int(
			Time.get_ticks_msec()
		)
	)
func render_surface_contract(
	surface_contract: Dictionary
) -> void:
	_ensure_surface()



	var normalized: Dictionary = (
		surface_contract.duplicate(false)
		if typeof(surface_contract) == TYPE_DICTIONARY
		else {}
	)

	if normalized.is_empty():
		return

	var contract_actor_id: int = int(
		normalized.get(
			"actor_id",
			-1
		)
	)

	if (
		actor != null
		and contract_actor_id > 0
		and contract_actor_id != int(actor.id)
	):
		set_meta(
			"assets_surface_actor_mismatch_rejected",
			true
		)
		set_meta(
			"assets_surface_expected_actor_id",
			int(actor.id)
		)
		set_meta(
			"assets_surface_received_actor_id",
			contract_actor_id
		)
		set_meta(
			"assets_surface_actor_mismatch_at_ms",
			int(Time.get_ticks_msec())
		)
		return

	var action_signature_parts:= PackedStringArray()
	var actions_raw: Variant = normalized.get(
		"actions",
		[]
	)
	var actions: Array = (
		actions_raw as Array
		if typeof(actions_raw) == TYPE_ARRAY
		else []
	)

	for raw_action in actions:
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue

		var action: Dictionary = raw_action as Dictionary

		action_signature_parts.append(
			"%s:%s" % [
				str(
					action.get(
						"action_id",
						""
					)
				),
				str(
					bool(
						action.get(
							"disabled",
							false
						)
					)
				)
			]
		)

	var base_signature: String = str(
		normalized.get(
			"surface_signature",
			""
		)
	)
	var projection_signature: String = (
		"%s|actor:%d|age:%d|bank:%d|count:%d|actions:%s"
		% [
			base_signature,
			contract_actor_id,
			int(
				normalized.get(
					"actor_age",
					actor.age if actor != null else -1
				)
			),
			int(
				normalized.get(
					"bank_balance",
					0
				)
			),
			int(
				normalized.get(
					"total_asset_count",
					0
				)
			),
			"|".join(action_signature_parts)
		]
	)

	if (
		projection_signature == active_render_signature
		and not active_contract.is_empty()
	):
		active_contract = normalized
		return

	active_contract = normalized
	active_render_signature = projection_signature

	title_label.text = str(
		active_contract.get(
			"title",
			"ASSETS • WEALTH"
		)
	)
	subtitle_label.text = str(
		active_contract.get(
			"subtitle",
			"Property, mobility, and market access."
		)
	)
	wealth_label.text = (
		"Available Wealth: %s • Controlled Assets: %d"
		% [
			str(
				active_contract.get(
					"bank_balance_text",
					"$0 USD"
				)
			),
			int(
				active_contract.get(
					"total_asset_count",
					0
				)
			)
		]
	)



	_render_actions()
	_begin_progressive_asset_publication()

	securities_label.text = str(
		active_contract.get(
			"markets_and_securities_text",
			"Future wealth systems can join this contract."
		)
	)

	set_meta(
		"assets_surface_rendered_before_open",
		not visible
	)
	set_meta(
		"assets_surface_render_signature",
		active_render_signature
	)
	set_meta(
		"assets_surface_render_actor_id",
		contract_actor_id
	)
	set_meta(
		"assets_surface_bulk_row_render_forbidden",
		true
	)
	set_meta(
		"assets_surface_progressive_publication",
		true
	)
	set_meta(
		"assets_surface_last_rendered_at_ms",
		int(Time.get_ticks_msec())
	)
func _begin_progressive_asset_publication() -> void:
	var generation: int = int(
		get_meta(
			"assets_progressive_publication_generation",
			0
		)
	) + 1

	set_meta(
		"assets_progressive_publication_generation",
		generation
	)

	_clear_children(
		faction_list
	)
	_clear_children(
		vehicle_list
	)
	_clear_children(
		property_list
	)

	var truth_state: String = str(
		active_contract.get(
			"truth_state",
			""
		)
	).strip_edges().to_lower()
	var observable_partial: bool = (
		truth_state in [
			"",
			"cold",
			"resolving",
			"observable_partial"
		]
	)

	if observable_partial:
		faction_list.add_child(
			_info_label(
				"Faction pressure is resolving…"
			)
		)
		vehicle_list.add_child(
			_info_label(
				"Controlled mobility assets are resolving…"
			)
		)
		property_list.add_child(
			_info_label(
				"Controlled real estate is resolving…"
			)
		)

		status_label.text = str(
			active_contract.get(
				"status_text",
				"Asset truth is publishing live."
			)
		)

		set_meta(
			"assets_progressive_publication_active",
			false
		)
		set_meta(
			"assets_progressive_publication_partial",
			true
		)
		return

	var faction_rows_raw: Variant = active_contract.get(
		"faction_pressure_rows",
		[]
	)
	var vehicle_rows_raw: Variant = active_contract.get(
		"vehicle_asset_rows",
		[]
	)
	var property_rows_raw: Variant = active_contract.get(
		"property_asset_rows",
		[]
	)
	var faction_rows: Array = (
		faction_rows_raw as Array
		if typeof(faction_rows_raw) == TYPE_ARRAY
		else []
	)
	var vehicle_rows: Array = (
		vehicle_rows_raw as Array
		if typeof(vehicle_rows_raw) == TYPE_ARRAY
		else []
	)
	var property_rows: Array = (
		property_rows_raw as Array
		if typeof(property_rows_raw) == TYPE_ARRAY
		else []
	)

	set_meta(
		"assets_progressive_faction_rows",
		faction_rows
	)
	set_meta(
		"assets_progressive_vehicle_rows",
		vehicle_rows
	)
	set_meta(
		"assets_progressive_property_rows",
		property_rows
	)
	set_meta(
		"assets_progressive_faction_cursor",
		0
	)
	set_meta(
		"assets_progressive_vehicle_cursor",
		0
	)
	set_meta(
		"assets_progressive_property_cursor",
		0
	)
	set_meta(
		"assets_progressive_publication_rendered_count",
		0
	)

	var total_count: int = (
		faction_rows.size()
		+ vehicle_rows.size()
		+ property_rows.size()
	)

	set_meta(
		"assets_progressive_publication_target_count",
		total_count
	)
	set_meta(
		"assets_progressive_publication_active",
		total_count > 0
	)
	set_meta(
		"assets_progressive_publication_partial",
		false
	)

	if faction_rows.is_empty():
		faction_list.add_child(
			_info_label(
				"No active faction pressure is orbiting this life."
			)
		)

	if vehicle_rows.is_empty():
		vehicle_list.add_child(
			_info_label(
				"No controlled mobility assets."
			)
		)

	if property_rows.is_empty():
		property_list.add_child(
			_info_label(
				(
					"No owned, controlled, household, resident, "
					+ "tenant, guardian-backed, or belongings-backed "
					+ "property assets are currently observable."
				)
			)
		)

	if total_count <= 0:
		status_label.text = str(
			active_contract.get(
				"status_text",
				"Asset truth is live."
			)
		)
		return

	status_label.text = (
		"Publishing asset cards live… 0/%d"
		% total_count
	)

	_schedule_progressive_asset_publication_step(
		generation
	)


func _schedule_progressive_asset_publication_step(
	generation: int
) -> void:
	var tree:= get_tree()

	if tree == null:
		call_deferred(
			"_continue_progressive_asset_publication",
			generation
		)
		return

	tree.process_frame.connect(
		Callable(
			self,
			"_continue_progressive_asset_publication"
		).bind(
			generation
		),
		CONNECT_ONE_SHOT
	)


func _continue_progressive_asset_publication(
	generation: int
) -> void:
	if generation != int(
		get_meta(
			"assets_progressive_publication_generation",
			-1
		)
	):
		return

	if not bool(
		get_meta(
			"assets_progressive_publication_active",
			false
		)
	):
		return

	var faction_rows_raw: Variant = get_meta(
		"assets_progressive_faction_rows",
		[]
	)
	var vehicle_rows_raw: Variant = get_meta(
		"assets_progressive_vehicle_rows",
		[]
	)
	var property_rows_raw: Variant = get_meta(
		"assets_progressive_property_rows",
		[]
	)
	var faction_rows: Array = (
		faction_rows_raw as Array
		if typeof(faction_rows_raw) == TYPE_ARRAY
		else []
	)
	var vehicle_rows: Array = (
		vehicle_rows_raw as Array
		if typeof(vehicle_rows_raw) == TYPE_ARRAY
		else []
	)
	var property_rows: Array = (
		property_rows_raw as Array
		if typeof(property_rows_raw) == TYPE_ARRAY
		else []
	)

	var faction_cursor: int = int(
		get_meta(
			"assets_progressive_faction_cursor",
			0
		)
	)
	var vehicle_cursor: int = int(
		get_meta(
			"assets_progressive_vehicle_cursor",
			0
		)
	)
	var property_cursor: int = int(
		get_meta(
			"assets_progressive_property_cursor",
			0
		)
	)
	var published_row: bool = false

	if faction_cursor < faction_rows.size():
		var faction_raw: Variant = faction_rows [
			faction_cursor
		]

		set_meta(
			"assets_progressive_faction_cursor",
			faction_cursor + 1
		)

		if typeof(faction_raw) == TYPE_DICTIONARY:
			_append_progressive_faction_row(
				faction_raw as Dictionary
			)
			published_row = true

	elif vehicle_cursor < vehicle_rows.size():
		var vehicle_raw: Variant = vehicle_rows [
			vehicle_cursor
		]

		set_meta(
			"assets_progressive_vehicle_cursor",
			vehicle_cursor + 1
		)

		if typeof(vehicle_raw) == TYPE_DICTIONARY:
			var vehicle_row: Dictionary = (
				vehicle_raw as Dictionary
			)
			var vehicle_id: int = int(
				vehicle_row.get(
					"asset_id",
					-1
				)
			)

			if vehicle_id > 0 and not _card_exists_for_asset(
				vehicle_list,
				vehicle_id
			):
				vehicle_list.add_child(
					_asset_card(
						vehicle_row,
						Color(
							0.4,
							0.82,
							1.0,
							1.0
						),
						[
							{
								"action_id": "open_vehicle_asset",
								"label": "View Vehicle",
								"icon": " ",
								"asset_id": vehicle_id
							}
						]
					)
				)
				published_row = true

	elif property_cursor < property_rows.size():
		var property_raw: Variant = property_rows [
			property_cursor
		]

		set_meta(
			"assets_progressive_property_cursor",
			property_cursor + 1
		)

		if typeof(property_raw) == TYPE_DICTIONARY:
			var property_row: Dictionary = (
				property_raw as Dictionary
			)

			var property_id: int = int(
				property_row.get(
					"asset_id",
					property_row.get(
						"property_id",
						-1
					)
				)
			)

			if property_id > 0:
				_upsert_property_asset_card(
					property_row
				)

				published_row = true

	else:
		set_meta(
			"assets_progressive_publication_active",
			false
		)
		set_meta(
			"assets_progressive_publication_complete",
			true
		)
		set_meta(
			"assets_progressive_publication_completed_at_ms",
			int(Time.get_ticks_msec())
		)

		var final_status: String = str(
			active_contract.get(
				"status_text",
				""
			)
		).strip_edges()

		status_label.text = (
			final_status
			if final_status != ""
			else "Asset truth is live."
		)
		return

	var rendered_count: int = int(
		get_meta(
			"assets_progressive_publication_rendered_count",
			0
		)
	)

	if published_row:
		rendered_count += 1
		set_meta(
			"assets_progressive_publication_rendered_count",
			rendered_count
		)

	var target_count: int = int(
		get_meta(
			"assets_progressive_publication_target_count",
			0
		)
	)

	status_label.text = (
		"Publishing asset cards live… %d/%d"
		% [
			rendered_count,
			target_count
		]
	)

	_schedule_progressive_asset_publication_step(
		generation
	)


func _append_progressive_faction_row(
	row: Dictionary
) -> void:
	if row.is_empty():
		return

	var card: PanelContainer = _card_container(
		Color(
			0.76,
			0.58,
			1.0,
			1.0
		)
	)
	var card_content: VBoxContainer = (
		_card_content_container(
			card
		)
	)

	if card_content == null:
		return

	var text:= Label.new()
	text.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)
	text.text = (
		"%s • %s\n"
		+ "Pressure %.1f • Legitimacy %.1f • Hostility %.1f\n"
		+ "Claims %.1f • Contested %d • Hidden %.1f"
	) % [
		str(
			row.get(
				"name",
				"Faction"
			)
		),
		str(
			row.get(
				"kind",
				"faction"
			)
		).replace(
			"_",
			" "
		).capitalize(),
		float(
			row.get(
				"pressure",
				0.0
			)
		),
		float(
			row.get(
				"legitimacy",
				0.0
			)
		),
		float(
			row.get(
				"hostility",
				0.0
			)
		),
		float(
			row.get(
				"claim_pressure",
				0.0
			)
		),
		int(
			row.get(
				"contested_claims",
				0
			)
		),
		float(
			row.get(
				"hidden_instability",
				0.0
			)
		)
	]

	card_content.add_child(
		text
	)
	faction_list.add_child(
		card
	)

func _ensure_surface() -> void:
	if title_label != null and is_instance_valid(title_label):
		return

	name = "AssetsPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_INHERIT
	z_index = 244
	set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	set_meta(
		"schema",
		PANEL_SCHEMA
	)
	set_meta(
		"version",
		CONTRACT_VERSION
	)
	set_meta(
		"ui_is_renderer_only",
		true
	)
	set_meta(
		"visible_click_build_forbidden",
		true
	)
	add_theme_stylebox_override(
		"panel",
		_panel_style()
	)

	var margin:= MarginContainer.new()
	margin.add_theme_constant_override(
		"margin_left",
		22
	)
	margin.add_theme_constant_override(
		"margin_top",
		18
	)
	margin.add_theme_constant_override(
		"margin_right",
		22
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		18
	)
	add_child(margin)

	var root:= VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override(
		"separation",
		10
	)
	margin.add_child(root)

	var header:= HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_constant_override(
		"separation",
		12
	)
	root.add_child(header)

	var back_button:= Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(
		116,
		42
	)
	back_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	back_button.pressed.connect(func () -> void:
		close_requested.emit()
	)
	header.add_child(back_button)

	title_label = Label.new()
	title_label.text = "ASSETS • WEALTH"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.add_theme_font_size_override(
		"font_size",
		30
	)
	title_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.81, 0.42, 1.0)
	)
	header.add_child(title_label)

	subtitle_label = Label.new()
	subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_color_override(
		"font_color",
		Color(0.88, 0.92, 1.0, 0.86)
	)
	root.add_child(subtitle_label)

	wealth_label = Label.new()
	wealth_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wealth_label.add_theme_font_size_override(
		"font_size",
		16
	)
	wealth_label.add_theme_color_override(
		"font_color",
		Color(0.56, 1.0, 0.72, 0.96)
	)
	root.add_child(wealth_label)

	action_grid = GridContainer.new()
	action_grid.columns = 2
	action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_grid.add_theme_constant_override(
		"h_separation",
		10
	)
	action_grid.add_theme_constant_override(
		"v_separation",
		10
	)
	root.add_child(action_grid)

	var body_scroll:= ScrollContainer.new()
	body_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	body_scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
	)
	root.add_child(body_scroll)

	var columns:= HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override(
		"separation",
		14
	)
	body_scroll.add_child(columns)

	var left_column:= VBoxContainer.new()
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override(
		"separation",
		10
	)
	columns.add_child(left_column)

	var right_column:= VBoxContainer.new()
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_column.add_theme_constant_override(
		"separation",
		10
	)
	columns.add_child(right_column)

	left_column.add_child(
		_section_heading(
			"FACTION ORBIT / PRESSURE",
			Color(0.76, 0.58, 1.0, 1.0)
		)
	)
	faction_list = VBoxContainer.new()
	faction_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	faction_list.add_theme_constant_override(
		"separation",
		8
	)
	left_column.add_child(faction_list)

	left_column.add_child(
		_section_heading(
			"MOBILITY ASSETS",
			Color(0.4, 0.82, 1.0, 1.0)
		)
	)
	vehicle_list = VBoxContainer.new()
	vehicle_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vehicle_list.add_theme_constant_override(
		"separation",
		8
	)
	left_column.add_child(vehicle_list)

	right_column.add_child(
		_section_heading(
			"REAL ESTATE",
			Color(1.0, 0.73, 0.35, 1.0)
		)
	)
	property_list = VBoxContainer.new()
	property_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	property_list.add_theme_constant_override(
		"separation",
		8
	)
	right_column.add_child(property_list)

	right_column.add_child(
		_section_heading(
			"MARKETS / SECURITIES",
			Color(0.56, 1.0, 0.72, 1.0)
		)
	)
	securities_label = Label.new()
	securities_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	securities_label.add_theme_color_override(
		"font_color",
		Color(0.88, 0.94, 1.0, 0.84)
	)
	right_column.add_child(securities_label)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override(
		"font_color",
		Color(1.0, 0.76, 0.42, 0.9)
	)
	root.add_child(status_label)


func _render_actions() -> void:
	_clear_children(action_grid)

	for raw_action in _safe_array(
		active_contract.get(
			"actions",
			[]
		)
	):
		var action: Dictionary = _safe_dictionary(
			raw_action
		)
		var action_id: String = str(
			action.get(
				"action_id",
				""
			)
		)

		if action_id == "":
			continue

		var button:= Button.new()
		button.text = "%s %s" % [
			str(
				action.get(
					"icon",
					"✦"
				)
			),
			str(
				action.get(
					"label",
					"Action"
				)
			)
		]
		button.custom_minimum_size = Vector2(
			0,
			48
		)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = bool(
			action.get(
				"disabled",
				false
			)
		)
		button.tooltip_text = str(
			action.get(
				"disabled_reason",
				""
			)
		)
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
		)
		_style_action_button(
			button,
			Color(0.4, 0.82, 1.0, 1.0)
			if action_id == "look_for_vehicles"
			else Color(1.0, 0.73, 0.35, 1.0)
		)
		button.pressed.connect(func () -> void:
			action_requested.emit(
				action_id,
				{
					"actor_id": int(
						active_contract.get(
							"actor_id",
							-1
						)
					),
					"source": "assets_panel"
				}
			)
		)
		action_grid.add_child(button)


func _render_factions() -> void:
	_clear_children(faction_list)

	var rows: Array = _safe_array(
		active_contract.get(
			"faction_pressure_rows",
			[]
		)
	)

	if rows.is_empty():
		faction_list.add_child(
			_info_label(
				"No active faction pressure is orbiting this life."
			)
		)
		return

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(
			raw_row
		)
		var card: PanelContainer = _card_container(
			Color(0.76, 0.58, 1.0, 1.0)
		)
		var card_content: VBoxContainer = (
			_card_content_container(card)
		)

		if card_content == null:
			continue

		var text:= Label.new()
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.text = "%s • %s\nPressure %.1f • Legitimacy %.1f • Hostility %.1f\nClaims %.1f • Contested %d • Hidden %.1f" % [
			str(
				row.get(
					"name",
					"Faction"
				)
			),
			str(
				row.get(
					"kind",
					"faction"
				)
			).replace("_", " ").capitalize(),
			float(
				row.get(
					"pressure",
					0.0
				)
			),
			float(
				row.get(
					"legitimacy",
					0.0
				)
			),
			float(
				row.get(
					"hostility",
					0.0
				)
			),
			float(
				row.get(
					"claim_pressure",
					0.0
				)
			),
			int(
				row.get(
					"contested_claims",
					0
				)
			),
			float(
				row.get(
					"hidden_instability",
					0.0
				)
			)
		]
		card_content.add_child(text)
		faction_list.add_child(card)


func _render_vehicle_assets() -> void:
	_clear_children(vehicle_list)

	# DIAGNOSTIC: report how many rows the panel was actually handed, versus how many
	# cards it is about to draw.
	EraLog.truth(
		"ERALIFE_ASSET_PANEL_VEHICLES|rows_received=%d"
		% _safe_array(active_contract.get("vehicle_asset_rows", [])).size()
	)

	var rows: Array = _safe_array(
		active_contract.get(
			"vehicle_asset_rows",
			[]
		)
	)

	if rows.is_empty():
		vehicle_list.add_child(
			_info_label(
				"No controlled mobility assets."
			)
		)
		return

	for raw_row in rows:
		var row: Dictionary = _safe_dictionary(
			raw_row
		)
		var asset_id: int = int(
			row.get(
				"asset_id",
				-1
			)
		)

		if asset_id <= 0:
			continue

		var card:= _asset_card(
			row,
			Color(0.4, 0.82, 1.0, 1.0),
			[
				{
					"action_id": "open_vehicle_asset",
					"label": "View Vehicle",
					"icon": "🚗",
					"asset_id": asset_id
				}
			]
		)
		vehicle_list.add_child(card)


func _render_property_assets() -> void:
	_clear_children(
		property_list
	)

	var rows: Array = _safe_array(
		active_contract.get(
			"property_asset_rows",
			[]
		)
	)

	if rows.is_empty():
		property_list.add_child(
			_info_label(
				(
					"No owned, controlled, household, resident, "
					+ "tenant, guardian-backed, or belongings-backed "
					+ "property assets are currently observable."
				)
			)
		)
		return

	for raw_row in rows:
		if typeof(raw_row) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = (
			raw_row as Dictionary
		)

		var asset_id: int = int(
			row.get(
				"asset_id",
				row.get(
					"property_id",
					-1
				)
			)
		)

		if asset_id <= 0:
			continue

		_upsert_property_asset_card(
			row
		)

func _property_asset_card_name(
	property_id: int
) -> String:
	return "PropertyAssetCard_%d" % property_id


func _asset_action_node_name(
	action_id: String,
	asset_id: int
) -> String:
	var clean_action_id: String = (
		action_id
		.strip_edges()
		.to_lower()
		.replace(
			" ",
			"_"
		)
		.replace(
			":",
			"_"
		)
	)

	return (
		"AssetAction_%s_%d"
		% [
			clean_action_id,
			asset_id
		]
	)


func _property_destination_hot_key(
	property_id: int
) -> String:
	var actor_id: int = int(
		active_contract.get(
			"actor_id",
			(
				int(
					actor.id
				)
				if actor != null
				else -1
			)
		)
	)

	return "%d:%d" % [
		actor_id,
		property_id
	]


func _property_asset_card_for_id(
	property_id: int
) -> PanelContainer:
	if (
		property_list == null
		or property_id <= 0
	):
		return null

	var candidate: Node = (
		property_list.get_node_or_null(
			NodePath(
				_property_asset_card_name(
					property_id
				)
			)
		)
	)

	if (
		candidate != null
		and candidate is PanelContainer
	):
		return candidate as PanelContainer

	return null


func _property_enter_affordance_hot(
	property_id: int
) -> bool:
	var hot_map_raw: Variant = get_meta(
		"property_destination_hot_by_id",
		{}
	)

	var hot_map: Dictionary = (
		hot_map_raw as Dictionary
		if typeof(hot_map_raw) == TYPE_DICTIONARY
		else {}
	)

	return bool(
		hot_map.get(
			_property_destination_hot_key(
				property_id
			),
			false
		)
	)


func _upsert_property_asset_card(
	property_row: Dictionary
) -> PanelContainer:
	var property_id: int = int(
		property_row.get(
			"asset_id",
			property_row.get(
				"property_id",
				-1
			)
		)
	)

	if property_id <= 0:
		return null

	var existing: PanelContainer = (
		_property_asset_card_for_id(
			property_id
		)
	)

	if existing != null:
		return existing

	var enter_hot: bool = (
		_property_enter_affordance_hot(
			property_id
		)
		or bool(
			property_row.get(
				"enter_and_view_hot",
				false
			)
		)
	)

	var card: PanelContainer = _asset_card(
		property_row,
		Color(
			1.0,
			0.73,
			0.35,
			1.0
		),
		[
			{
				"action_id": "open_property_asset",
				"label": "View Property",
				"icon": " ",
				"asset_id": property_id,
				"visible": true,
				"disabled": false
			},
			{
				"action_id": "enter_property",
				"label": "Enter & View",
				"icon": " ",
				"asset_id": property_id,
				"visible": enter_hot,
				"disabled": not enter_hot
			}
		]
	)

	card.name = (
		_property_asset_card_name(
			property_id
		)
	)

	card.set_meta(
		"property_asset_id",
		property_id
	)
	card.set_meta(
		"enter_and_view_hot",
		enter_hot
	)

	property_list.add_child(
		card
	)

	return card


func _apply_property_destination_patch(
	patch: Dictionary
) -> void:
	var property_id: int = int(
		patch.get(
			"property_id",
			-1
		)
	)

	if property_id <= 0:
		return

	var enter_hot: bool = bool(
		patch.get(
			"enter_and_view_hot",
			false
		)
	)

	var hot_map_raw: Variant = get_meta(
		"property_destination_hot_by_id",
		{}
	)

	var hot_map: Dictionary = (
		(hot_map_raw as Dictionary).duplicate(false)
		if typeof(hot_map_raw) == TYPE_DICTIONARY
		else {}
	)

	hot_map [
		_property_destination_hot_key(
			property_id
		)
	] = enter_hot

	set_meta(
		"property_destination_hot_by_id",
		hot_map
	)

	var card: PanelContainer = (
		_property_asset_card_for_id(
			property_id
		)
	)

	if card == null:
		return

	card.set_meta(
		"enter_and_view_hot",
		enter_hot
	)

	var button_raw: Node = card.find_child(
		_asset_action_node_name(
			"enter_property",
			property_id
		),
		true,
		false
	)

	if button_raw is Button:
		var button: Button = (
			button_raw as Button
		)

		button.visible = enter_hot
		button.disabled = not enter_hot
		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
			if enter_hot
			else Control.CURSOR_ARROW
		)

		var grid: GridContainer = (
			button.get_parent() as GridContainer
			if button.get_parent() is GridContainer
			else null
		)

		if grid != null:
			var visible_count: int = 0

			for child in grid.get_children():
				if (
					child is Button
					and (
						child as Button
					).visible
				):
					visible_count += 1

			grid.columns = maxi(
				1,
				visible_count
			)

	set_meta(
		"property_destination_last_property_id",
		property_id
	)
	set_meta(
		"property_destination_last_enter_hot",
		enter_hot
	)
	set_meta(
		"property_destination_button_streamed_live",
		enter_hot
	)
func _asset_card(
	row: Dictionary,
	accent: Color,
	actions: Array
) -> PanelContainer:
	var card: PanelContainer = (
		_card_container(
			accent
		)
	)

	# FIX support: stamp the card with the asset it represents. Two different code
	# paths draw into the same containers -- _render_vehicle_assets() (which clears
	# first) and _continue_progressive_asset_publication() (which appends without
	# clearing) -- so a single vehicle could end up with a card from each. The id
	# lets the appending path check whether a card already exists.
	card.set_meta(
		"assets_panel_card_asset_id",
		int(
			row.get(
				"asset_id",
				row.get(
					"id",
					-1
				)
			)
		)
	)

	var card_content: VBoxContainer = (
		_card_content_container(
			card
		)
	)

	if card_content == null:
		return card

	card_content.add_theme_constant_override(
		"separation",
		6
	)

	var title:= Label.new()
	title.text = str(
		row.get(
			"display_name",
			"Asset"
		)
	)
	title.add_theme_font_size_override(
		"font_size",
		17
	)
	title.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	card_content.add_child(
		title
	)

	var secondary_text: String = str(
		row.get(
			"address",
			row.get(
				"route_label",
				""
			)
		)
	)

	if secondary_text != "":
		var secondary:= Label.new()
		secondary.text = secondary_text
		secondary.autowrap_mode = (
			TextServer.AUTOWRAP_WORD_SMART
		)
		secondary.add_theme_color_override(
			"font_color",
			Color(
				0.84,
				0.9,
				1.0,
				0.78
			)
		)
		card_content.add_child(
			secondary
		)

	var condition_value: float = clampf(
		float(
			row.get(
				"condition",
				100.0
			)
		),
		0.0,
		100.0
	)

	var condition_header:= Label.new()
	condition_header.text = (
		"Condition %d%% • %s"
		% [
			int(
				round(
					condition_value
				)
			),
			str(
				row.get(
					"condition_label",
					"Maintained"
				)
			)
		]
	)
	condition_header.add_theme_color_override(
		"font_color",
		Color(
			accent.r,
			accent.g,
			accent.b,
			0.96
		)
	)
	card_content.add_child(
		condition_header
	)

	var condition_bar:= ProgressBar.new()
	condition_bar.min_value = 0.0
	condition_bar.max_value = 100.0
	condition_bar.value = condition_value
	condition_bar.show_percentage = false
	condition_bar.custom_minimum_size = Vector2(
		0,
		12
	)
	condition_bar.add_theme_stylebox_override(
		"background",
		_condition_style(
			accent,
			false
		)
	)
	condition_bar.add_theme_stylebox_override(
		"fill",
		_condition_style(
			accent,
			true
		)
	)
	card_content.add_child(
		condition_bar
	)

	var visible_action_count: int = 0

	for raw_action in actions:
		if typeof(raw_action) != TYPE_DICTIONARY:
			continue

		if bool(
			(raw_action as Dictionary).get(
				"visible",
				true
			)
		):
			visible_action_count += 1

	var asset_action_grid:= GridContainer.new()
	asset_action_grid.columns = maxi(
		1,
		visible_action_count
	)
	asset_action_grid.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	asset_action_grid.add_theme_constant_override(
		"h_separation",
		8
	)
	card_content.add_child(
		asset_action_grid
	)

	for raw_action in actions:
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

		var asset_id: int = int(
			action.get(
				"asset_id",
				-1
			)
		)

		var button:= Button.new()

		button.name = (
			_asset_action_node_name(
				action_id,
				asset_id
			)
		)

		button.text = "%s %s" % [
			str(
				action.get(
					"icon",
					"✦"
				)
			),
			str(
				action.get(
					"label",
					"Open"
				)
			)
		]

		button.visible = bool(
			action.get(
				"visible",
				true
			)
		)

		button.disabled = bool(
			action.get(
				"disabled",
				false
			)
		)

		button.custom_minimum_size = Vector2(
			0,
			40
		)

		button.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		button.mouse_default_cursor_shape = (
			Control.CURSOR_POINTING_HAND
			if (
				button.visible
				and not button.disabled
			)
			else Control.CURSOR_ARROW
		)

		_style_action_button(
			button,
			accent
		)

		button.set_meta(
			"asset_action_id",
			action_id
		)
		button.set_meta(
			"asset_id",
			asset_id
		)

		button.pressed.connect(
			func () -> void:
				action_requested.emit(
					action_id,
					{
						"actor_id": int(
							active_contract.get(
								"actor_id",
								-1
							)
						),
						"asset_id": asset_id,
						"source": (
							"assets_panel"
						)
					}
				)
		)

		asset_action_grid.add_child(
			button
		)

	return card


func _section_heading(
	text: String,
	accent: Color
) -> Label:
	var label:= Label.new()
	label.text = text
	label.add_theme_font_size_override(
		"font_size",
		16
	)
	label.add_theme_color_override(
		"font_color",
		accent
	)
	return label


func _info_label(
	text: String
) -> Label:
	var label:= Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override(
		"font_color",
		Color(0.84, 0.9, 1.0, 0.78)
	)
	return label


func _card_container(
	accent: Color
) -> PanelContainer:
	var card:= PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override(
		"panel",
		_card_style(accent)
	)

	var margin:= MarginContainer.new()
	margin.name = "CardMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override(
		"margin_left",
		12
	)
	margin.add_theme_constant_override(
		"margin_top",
		10
	)
	margin.add_theme_constant_override(
		"margin_right",
		12
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		10
	)
	card.add_child(margin)

	var content:= VBoxContainer.new()
	content.name = "CardContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(
		"separation",
		6
	)
	margin.add_child(content)

	return card


func _card_content_container(
	card: PanelContainer
) -> VBoxContainer:
	if card == null or not is_instance_valid(card):
		return null

	var existing: Node = card.get_node_or_null(
		"CardMargin/CardContent"
	)

	if existing is VBoxContainer:
		return existing as VBoxContainer



	var margin:= MarginContainer.new()
	margin.name = "CardMargin"
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override(
		"margin_left",
		12
	)
	margin.add_theme_constant_override(
		"margin_top",
		10
	)
	margin.add_theme_constant_override(
		"margin_right",
		12
	)
	margin.add_theme_constant_override(
		"margin_bottom",
		10
	)
	card.add_child(margin)

	var content:= VBoxContainer.new()
	content.name = "CardContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(
		"separation",
		6
	)
	margin.add_child(content)

	return content

func _panel_style() -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.03, 0.045, 0.99)
	style.border_color = Color(1.0, 0.76, 0.34, 0.7)
	style.set_border_width_all(2)
	style.set_corner_radius_all(16)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	style.shadow_size = 18
	return style


func _card_style(
	accent: Color
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = Color(
		accent.r * 0.1,
		accent.g * 0.1,
		accent.b * 0.1,
		0.96
	)
	style.border_color = Color(
		accent.r,
		accent.g,
		accent.b,
		0.46
	)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_top = 9.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 9.0
	return style


func _style_action_button(
	button: Button,
	accent: Color
) -> void:
	for state in [
		"normal",
		"hover",
		"pressed",
		"focus"
	]:
		var style:= StyleBoxFlat.new()
		var intensity: float = 0.13
		var border_alpha: float = 0.45

		if state == "hover" or state == "focus":
			intensity = 0.23
			border_alpha = 0.84
		elif state == "pressed":
			intensity = 0.34
			border_alpha = 1.0

		style.bg_color = Color(
			accent.r * intensity,
			accent.g * intensity,
			accent.b * intensity,
			0.98
		)
		style.border_color = Color(
			accent.r,
			accent.g,
			accent.b,
			border_alpha
		)
		style.set_border_width_all(1)
		style.set_corner_radius_all(8)
		button.add_theme_stylebox_override(
			state,
			style
		)

	button.add_theme_color_override(
		"font_color",
		Color.WHITE
	)
	button.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)
	button.add_theme_color_override(
		"font_pressed_color",
		Color.WHITE
	)


func _condition_style(
	accent: Color,
	filled: bool
) -> StyleBoxFlat:
	var style:= StyleBoxFlat.new()
	style.bg_color = (
		Color(
			accent.r,
			accent.g,
			accent.b,
			0.94
		)
		if filled
		else Color(0.06, 0.07, 0.1, 0.96)
	)
	style.set_corner_radius_all(6)

	if not filled:
		style.border_color = Color(
			accent.r,
			accent.g,
			accent.b,
			0.28
		)
		style.set_border_width_all(1)

	return style


func _card_exists_for_asset(
	container: Node,
	asset_id: int
) -> bool:
	# FIX: the progressive publication path appends cards without clearing the
	# container, so anything already drawn by the full renderer stayed put and the
	# same vehicle appeared twice -- one card per path. Skip an asset that is already
	# on screen instead of stacking another copy.
	if container == null or asset_id <= 0:
		return false

	for child in container.get_children():
		if int(
			child.get_meta(
				"assets_panel_card_asset_id",
				-1
			)
		) == asset_id:
			return true

	return false


func _clear_children(
	node: Node
) -> void:
	if node == null:
		return

	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


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