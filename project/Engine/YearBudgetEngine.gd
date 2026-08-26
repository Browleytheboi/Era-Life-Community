extends Resource
class_name YearBudgetEngine

var gs
var lane_offsets: Dictionary = {}
var pipeline_running: bool = false
var pipeline_stage: int = 0
var pipeline_groups: Dictionary = {}

const NEAR_MIN_BUDGET:= 24
const NEAR_MAX_BUDGET:= 180
const MID_MIN_BUDGET:= 180
const MID_MAX_BUDGET:= 1100
const FAR_MIN_BUDGET:= 500
const FAR_MAX_BUDGET:= 2600
const DORMANT_MIN_BATCH:= 1200
const DORMANT_MAX_BATCH:= 9000
const COLLAPSE_MIN_BATCH:= 400
const COLLAPSE_MAX_BATCH:= 2600

func _init(_gs):
	gs = _gs




func process_near_npcs(npcs: Array) -> Dictionary:
	var partition: Dictionary = _resolve_lane_partition_from_cache(
		"near",
		npcs
	)
	var priority_raw: Variant = partition.get("priority", [])
	var regular_raw: Variant = partition.get("regular", [])
	var priority: Array = (
		priority_raw
		if typeof(priority_raw) == TYPE_ARRAY
		else []
	)
	var regular: Array = (
		regular_raw
		if typeof(regular_raw) == TYPE_ARRAY
		else []
	)

	var priority_cursor: int = int(
		lane_offsets.get("near_priority_cursor", 0)
	)
	var regular_cursor: int = int(
		lane_offsets.get("near_regular_cursor", 0)
	)




	var item_cap: int = 1
	var processed: int = 0

	while priority_cursor < priority.size() and processed < item_cap:
		var npc = priority [priority_cursor]
		if npc != null:
			_simulate_near_npc(npc)
		priority_cursor += 1
		processed += 1

	while (
		regular_cursor < regular.size()
		and processed < item_cap
	):
		var npc = regular [regular_cursor]
		if npc != null:
			_simulate_near_npc(npc)
		regular_cursor += 1
		processed += 1

	var is_complete: bool = (
		priority_cursor >= priority.size()
		and regular_cursor >= regular.size()
	)

	if is_complete:
		lane_offsets.erase("near_priority_cursor")
		lane_offsets.erase("near_regular_cursor")
		lane_offsets.erase("near_partition")
		lane_offsets.erase("near_partition_size")
	else:
		lane_offsets ["near_priority_cursor"] = priority_cursor
		lane_offsets ["near_regular_cursor"] = regular_cursor

	return {
		"is_complete": is_complete,
		"processed": processed,
		"priority_cursor": priority_cursor,
		"regular_cursor": regular_cursor,
		"priority_total": int(priority.size()),
		"regular_total": int(regular.size()),
		"max_items_per_quantum": item_cap,
		"progress": (
			float(priority_cursor + regular_cursor)
			/ float(maxi(1, priority.size() + regular.size()))
		)
	}

func process_mid_npcs(npcs: Array) -> Dictionary:
	var partition_raw: Variant = pipeline_groups.get(
		"mid_partition",
		{}
	)
	var partition: Dictionary = (
		partition_raw
		if typeof(partition_raw) == TYPE_DICTIONARY
		else {}
	)
	if partition.is_empty():
		partition = _resolve_lane_partition_from_cache(
			"mid",
			npcs
		)

	var priority_raw: Variant = partition.get("priority", [])
	var regular_raw: Variant = partition.get("regular", [])
	var priority: Array = (
		priority_raw
		if typeof(priority_raw) == TYPE_ARRAY
		else []
	)
	var regular: Array = (
		regular_raw
		if typeof(regular_raw) == TYPE_ARRAY
		else []
	)

	var priority_cursor: int = int(
		lane_offsets.get("mid_priority_cursor", 0)
	)
	var regular_cursor: int = int(
		lane_offsets.get("mid_regular_cursor", 0)
	)
	var item_cap: int = 4
	var processed: int = 0

	while priority_cursor < priority.size() and processed < item_cap:
		var npc = priority [priority_cursor]
		if npc != null:
			_simulate_mid_npc(npc)
		priority_cursor += 1
		processed += 1

	while (
		regular_cursor < regular.size()
		and processed < item_cap
	):
		var npc = regular [regular_cursor]
		if npc != null:
			_simulate_mid_npc(npc)
		regular_cursor += 1
		processed += 1

	var is_complete: bool = (
		priority_cursor >= priority.size()
		and regular_cursor >= regular.size()
	)

	if is_complete:
		lane_offsets.erase("mid_priority_cursor")
		lane_offsets.erase("mid_regular_cursor")
		lane_offsets.erase("mid_partition")
		lane_offsets.erase("mid_partition_size")
	else:
		lane_offsets ["mid_priority_cursor"] = priority_cursor
		lane_offsets ["mid_regular_cursor"] = regular_cursor

	return {
		"is_complete": is_complete,
		"processed": processed,
		"priority_cursor": priority_cursor,
		"regular_cursor": regular_cursor,
		"priority_total": int(priority.size()),
		"regular_total": int(regular.size()),
		"max_items_per_quantum": item_cap,
		"progress": (
			float(priority_cursor + regular_cursor)
			/ float(maxi(1, priority.size() + regular.size()))
		)
	}

func process_far_npcs(npcs: Array) -> Dictionary:
	var partition_raw: Variant = pipeline_groups.get(
		"far_partition",
		{}
	)
	var partition: Dictionary = (
		partition_raw
		if typeof(partition_raw) == TYPE_DICTIONARY
		else {}
	)
	if partition.is_empty():
		partition = _resolve_lane_partition_from_cache(
			"far",
			npcs
		)

	var priority_raw: Variant = partition.get("priority", [])
	var regular_raw: Variant = partition.get("regular", [])
	var priority: Array = (
		priority_raw
		if typeof(priority_raw) == TYPE_ARRAY
		else []
	)
	var regular: Array = (
		regular_raw
		if typeof(regular_raw) == TYPE_ARRAY
		else []
	)

	var priority_cursor: int = int(
		lane_offsets.get("far_priority_cursor", 0)
	)
	var regular_cursor: int = int(
		lane_offsets.get("far_regular_cursor", 0)
	)
	var item_cap: int = 12
	var processed: int = 0

	while priority_cursor < priority.size() and processed < item_cap:
		var npc = priority [priority_cursor]
		if npc != null:
			_simulate_far_npc(npc)
		priority_cursor += 1
		processed += 1

	while (
		regular_cursor < regular.size()
		and processed < item_cap
	):
		var npc = regular [regular_cursor]
		if npc != null:
			_simulate_far_npc(npc)
		regular_cursor += 1
		processed += 1

	var is_complete: bool = (
		priority_cursor >= priority.size()
		and regular_cursor >= regular.size()
	)

	if is_complete:
		lane_offsets.erase("far_priority_cursor")
		lane_offsets.erase("far_regular_cursor")
		lane_offsets.erase("far_partition")
		lane_offsets.erase("far_partition_size")
	else:
		lane_offsets ["far_priority_cursor"] = priority_cursor
		lane_offsets ["far_regular_cursor"] = regular_cursor

	return {
		"is_complete": is_complete,
		"processed": processed,
		"priority_cursor": priority_cursor,
		"regular_cursor": regular_cursor,
		"priority_total": int(priority.size()),
		"regular_total": int(regular.size()),
		"max_items_per_quantum": item_cap,
		"progress": (
			float(priority_cursor + regular_cursor)
			/ float(maxi(1, priority.size() + regular.size()))
		)
	}
func _build_pipeline_groups(groups: Dictionary) -> Dictionary:
	var runtime_mailboxes = groups.get(
		"mailboxes",
		{}
	)

	if typeof(
		runtime_mailboxes
	) != TYPE_DICTIONARY:
		runtime_mailboxes = {}

	var mid: Array = groups.get(
		"mid",
		[]
	).duplicate()

	var far: Array = groups.get(
		"far",
		[]
	).duplicate()

	var mid_partition_source: Dictionary = (
		_partition_priority_people(
			mid
		)
	)

	var far_partition_source: Dictionary = (
		_partition_priority_people(
			far
		)
	)

	var mid_priority_raw: Variant = (
		mid_partition_source.get(
			"priority",
			[]
		)
	)

	var mid_regular_raw: Variant = (
		mid_partition_source.get(
			"regular",
			[]
		)
	)

	var far_priority_raw: Variant = (
		far_partition_source.get(
			"priority",
			[]
		)
	)

	var far_regular_raw: Variant = (
		far_partition_source.get(
			"regular",
			[]
		)
	)

	var mid_partition: Dictionary = {
		"priority": (
			mid_priority_raw
			if typeof(mid_priority_raw) == TYPE_ARRAY
			else []
		).duplicate(),
		"regular": (
			mid_regular_raw
			if typeof(mid_regular_raw) == TYPE_ARRAY
			else []
		).duplicate()
	}

	var far_partition: Dictionary = {
		"priority": (
			far_priority_raw
			if typeof(far_priority_raw) == TYPE_ARRAY
			else []
		).duplicate(),
		"regular": (
			far_regular_raw
			if typeof(far_regular_raw) == TYPE_ARRAY
			else []
		).duplicate()
	}

	var dormant_hot_raw: Variant = groups.get(
		"dormant_hot_ids",
		[]
	)

	var dormant_hot_ids: Array = (
		(dormant_hot_raw as Array).duplicate(false)
		if typeof(dormant_hot_raw) == TYPE_ARRAY
		else []
	)

	var dormant_hot_seen: Dictionary = {}

	for raw_id in dormant_hot_ids:
		var existing_id: int = int(
			raw_id
		)

		if existing_id > 0:
			dormant_hot_seen [
				existing_id
			] = true




	if (
		gs != null
		and gs.player != null
		and "dormant_npcs" in gs
	):
		var controlled: Person = gs.player
		var priority_ids: Array = []

		if controlled.partner != null:
			priority_ids.append(
				int(
					controlled.partner.id
				)
			)

		priority_ids.append_array(
			controlled.parents
		)

		priority_ids.append_array(
			controlled.children
		)

		priority_ids.append_array(
			controlled.friends
		)

		priority_ids.append_array(
			controlled.ex_partners
		)

		priority_ids.append_array(
			controlled.schoolmates
		)

		for raw_priority_id in priority_ids:
			var priority_id: int = int(
				raw_priority_id
			)

			if priority_id <= 0:
				continue

			if dormant_hot_seen.has(
				priority_id
			):
				continue

			if not gs.dormant_npcs.has(
				priority_id
			):
				continue

			dormant_hot_seen [
				priority_id
			] = true

			dormant_hot_ids.append(
				priority_id
			)

	return {
		"mid": mid,
		"far": far,
		"mid_partition": mid_partition,
		"far_partition": far_partition,
		"dormant_hot_ids": dormant_hot_ids,
		"quality_tier": str(
			groups.get(
				"quality_tier",
				"balanced"
			)
		),
		"runtime_context": groups.get(
			"runtime_context",
			{}
		).duplicate(true),
		"mailboxes": runtime_mailboxes
	}
func _resolve_lane_partition_from_cache(lane_key: String, people: Array) -> Dictionary:
	var cache_key: String = "%s_partition" % lane_key
	var cache_size_key: String = "%s_partition_size" % lane_key

	var cached_raw: Variant = lane_offsets.get(cache_key, {})
	var cached: Dictionary = cached_raw if typeof(cached_raw) == TYPE_DICTIONARY else {}

	if not cached.is_empty() and int(lane_offsets.get(cache_size_key, -1)) == people.size():
		return cached

	var partition_source: Dictionary = _partition_priority_people(people)
	var priority_raw: Variant = partition_source.get("priority", [])
	var regular_raw: Variant = partition_source.get("regular", [])

	cached = {
		"priority": (priority_raw if typeof(priority_raw) == TYPE_ARRAY else []).duplicate(),
		"regular": (regular_raw if typeof(regular_raw) == TYPE_ARRAY else []).duplicate()
	}

	lane_offsets [cache_key] = cached
	lane_offsets [cache_size_key] = people.size()
	return cached

func run_year_pipeline_immediate(groups: Dictionary) -> void:
	if gs == null:
		return

	start_year_pipeline(groups, false)
	flush_year_pipeline()
func start_year_pipeline(
		groups: Dictionary,
		deferred_start: bool = true
) -> void:
	if gs == null:
		return

	cancel_year_pipeline()
	pipeline_groups = _build_pipeline_groups(groups)
	pipeline_stage = 1
	pipeline_running = true
	lane_offsets.clear()
	lane_offsets ["pipeline_service_policy"] = "explicit_budgeted_service"
	lane_offsets ["deferred_start_requested"] = deferred_start
	lane_offsets ["pipeline_started_at_ms"] = int(Time.get_ticks_msec())



func cancel_year_pipeline() -> void:
	pipeline_running = false
	pipeline_stage = 0
	pipeline_groups = {}
	lane_offsets.clear()
	if gs != null and typeof(gs.dormant_runtime_sessions) == TYPE_DICTIONARY:
		gs.dormant_runtime_sessions.erase("year_budget_pipeline_dormant_tail")

func flush_year_pipeline() -> void:
	while pipeline_running:
		_drain_year_pipeline_step()
func _visible_age_up_runtime_owns_pipeline() -> bool:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return false

	var loading_raw: Variant = gs.scenario_state.get("loading_runtime", {})
	var loading: Dictionary = loading_raw if typeof(loading_raw) == TYPE_DICTIONARY else {}

	if loading.is_empty():
		return false

	if not bool(loading.get("active", false)):
		return false

	if bool(loading.get("is_complete", false)):
		return false

	var completion_state: String = str(loading.get("completion_state", "running")).strip_edges().to_lower()
	if completion_state == "complete":
		return false

	return true
func has_pending_year_pipeline() -> bool:
	return pipeline_running

func get_dormant_batch_limit() -> int:
	if gs == null:
		return 0

	var dormant_count: int = int(
		gs.dormant_npcs.size()
	)

	if dormant_count <= 0:
		return 0







	var quantum_item_cap: int = 24

	if typeof(
		gs.scenario_state
	) == TYPE_DICTIONARY:
		quantum_item_cap = int(
			gs.scenario_state.get(
				"dormant_population_runtime_quantum_item_cap",
				24
			)
		)

	quantum_item_cap = clampi(
		quantum_item_cap,
		1,
		64
	)

	return mini(
		dormant_count,
		quantum_item_cap
	)

func get_dormant_collapse_budget(overflow: int, candidate_count: int) -> int:
	if overflow <= 0 or candidate_count <= 0:
		return 0

	var max_possible: int = int(min(overflow, candidate_count))
	var represented: int = int(_represented_population())
	var budget: int = max_possible

	if represented > 35000:
		budget = int(min(budget, 450))
	elif represented > 12000:
		budget = int(min(budget, 700))
	elif represented > 4000:
		budget = int(min(budget, 1000))

	budget = int(max(budget, min(COLLAPSE_MIN_BATCH, max_possible)))
	budget = int(min(budget, min(COLLAPSE_MAX_BATCH, max_possible)))
	return int(max(0, budget))






func _drain_year_pipeline() -> void:
	if not pipeline_running:
		return



	_drain_year_pipeline_step()
func _drain_year_pipeline_step() -> void:
	match pipeline_stage:
		1:
			var mid_result: Dictionary = process_mid_npcs(pipeline_groups.get("mid", []))
			if bool(mid_result.get("is_complete", false)):
				pipeline_stage = 2
		2:
			var far_result: Dictionary = process_far_npcs(pipeline_groups.get("far", []))
			if bool(far_result.get("is_complete", false)):
				pipeline_stage = 3
		3:
			var tail_result: Dictionary = _run_world_tail_lane()
			if bool(tail_result.get("is_complete", false)):
				pipeline_stage = 0
				pipeline_running = false
				pipeline_groups.clear()
				lane_offsets.erase("world_tail_cursor")
		_:
			pipeline_stage = 0
			pipeline_running = false
			pipeline_groups.clear()

func _run_world_tail_lane() -> Dictionary:
	if gs == null:
		return {
			"is_complete": true,
			"current_micro_lane": "complete"
		}

	var dormant_hot_ids: Array = pipeline_groups.get(
		"dormant_hot_ids",
		[]
	)
	var runtime_mailboxes = pipeline_groups.get("mailboxes", {})
	var delta_mailbox: Array = []
	if typeof(runtime_mailboxes) == TYPE_DICTIONARY:
		delta_mailbox = runtime_mailboxes.get("delta_packets", [])

	var tail_cursor: int = int(
		lane_offsets.get("world_tail_cursor", 0)
	)
	var dormant_session_key: String = "year_budget_pipeline_dormant_tail"



	match tail_cursor:
		0:
			var dormant_step: Dictionary = gs.simulate_dormant_population(
				-1,
				dormant_hot_ids,
				delta_mailbox,
				dormant_session_key
			)
			if not bool(dormant_step.get("is_complete", false)):
				lane_offsets ["world_tail_cursor"] = 0
				return {
					"is_complete": false,
					"current_micro_lane": "world_tail_dormant",
					"progress": float(
						dormant_step.get(
							"progress",
							0.0
						)
					)
				}
			tail_cursor = 1

		1:
			if gs.world_engine != null:
				var relationship_report: Dictionary = (
					gs.world_engine.update_relationships(
						48
					)
				)
				if not bool(
					relationship_report.get(
						"is_complete",
						true
					)
				):
					lane_offsets ["world_tail_cursor"] = 1
					return {
						"is_complete": false,
						"current_micro_lane": "world_tail_relationships",
						"progress": float(
							relationship_report.get(
								"progress",
								0.0
							)
						)
					}
			tail_cursor = 2

		2:
			if gs.red_bonnet_engine != null:
				gs.red_bonnet_engine.yearly_spawn_check()
			tail_cursor = 3

		3:
			if gs.artifacts_engine != null:
				gs.artifacts_engine.yearly_discovery_chance()
			tail_cursor = 4

		4:
			if gs.artifacts_engine != null:
				gs.artifacts_engine.cosmic_consequence()
			tail_cursor = 5

		5:
			if gs.dragonballs_engine != null:
				gs.dragonballs_engine.yearly_chance()
			tail_cursor = 6

		6:
			if gs.many_realms_engine != null:
				gs.many_realms_engine.yearly_discovery_chance()
			tail_cursor = 7

		7:
			if gs.fame_engine != null:
				gs.fame_engine.random_npc_becomes_famous()
			tail_cursor = 8

		8:
			if gs.vehicle_engine != null:
				gs.vehicle_engine.yearly_maintenance()
			tail_cursor = 9

		9:
			if gs.emergent_story_engine != null:
				gs.emergent_story_engine.yearly_tick()
			tail_cursor = 10

		10:
			if gs.population_lifecycle_manager != null:
				gs.population_lifecycle_manager.yearly_evaluate()
			else:
				gs._soft_unload_npcs()
			tail_cursor = 11

		11:
			if typeof(runtime_mailboxes) == TYPE_DICTIONARY:
				var mutation_box: Array = runtime_mailboxes.get(
					"mutation",
					[]
				)
				mutation_box.append({
					"type": "world_tail_lane_complete",
					"year": int(gs.year),
					"dormant_hot_count": int(dormant_hot_ids.size()),
					"remaining_dormant": int(gs.dormant_npcs.size())
				})
				runtime_mailboxes ["mutation"] = mutation_box
				runtime_mailboxes ["delta_packets"] = delta_mailbox

			lane_offsets.erase("world_tail_cursor")
			return {
				"is_complete": true,
				"current_micro_lane": "complete",
				"progress": 1.0
			}

		_:
			lane_offsets.erase("world_tail_cursor")
			return {
				"is_complete": true,
				"current_micro_lane": "complete",
				"progress": 1.0
			}

	lane_offsets ["world_tail_cursor"] = tail_cursor
	return {
		"is_complete": false,
		"current_micro_lane": "world_tail_%d" % tail_cursor,
		"progress": clampf(
			float(tail_cursor) / 11.0,
			0.0,
			0.99
		)
	}




func _simulate_near_npc(npc) -> void:
	if npc == null or not npc.alive:
		return
	gs.health_engine.update_health(npc)
	gs.career_engine.update_career(npc)
	gs.personality_engine.generate_traits(npc)
	gs.fate_engine.assign_arc(npc)
	gs.desire_engine.yearly_tick(npc)
	gs.goal_planning_engine.yearly_update(npc)
	gs.desire_behavior_bridge.process_npc(npc)
	gs.capability_graph_engine.yearly_growth(npc)

func _simulate_mid_npc(npc) -> void:
	if npc == null or not npc.alive:
		return
	gs.health_engine.update_health(npc)
	gs.career_engine.update_career(npc)
	if randi() % 3 == 0:
		gs.personality_engine.generate_traits(npc)
	if randi() % 4 == 0:
		gs.desire_engine.yearly_tick(npc)

func _simulate_far_npc(npc) -> void:
	if npc == null or not npc.alive:
		return
	gs.spatial_culling_engine.simulate_far_npc(npc)

func _resolve_near_budget(total: int) -> int:
	if total <= 0:
		return 0

	var represented: int = int(_represented_population())
	var budget: int = total

	if represented > 35000:
		budget = int(ceil(float(total) * 0.45))
	elif represented > 12000:
		budget = int(ceil(float(total) * 0.7))
	elif represented > 4000:
		budget = int(ceil(float(total) * 0.9))

	budget = int(max(budget, min(NEAR_MIN_BUDGET, total)))
	budget = int(min(budget, min(NEAR_MAX_BUDGET, total)))
	return int(max(0, budget))

func _resolve_mid_budget(total: int) -> int:
	if total <= 0:
		return 0

	var represented: int = int(_represented_population())
	var budget: int = total

	if represented > 35000:
		budget = int(ceil(float(total) * 0.22))
	elif represented > 12000:
		budget = int(ceil(float(total) * 0.35))
	elif represented > 4000:
		budget = int(ceil(float(total) * 0.6))

	budget = int(max(budget, min(MID_MIN_BUDGET, total)))
	budget = int(min(budget, min(MID_MAX_BUDGET, total)))
	return int(max(0, budget))

func _resolve_far_budget(total: int) -> int:
	if total <= 0:
		return 0

	var represented: int = int(_represented_population())
	var budget: int = total

	if represented > 35000:
		budget = int(ceil(float(total) * 0.1))
	elif represented > 12000:
		budget = int(ceil(float(total) * 0.18))
	elif represented > 4000:
		budget = int(ceil(float(total) * 0.35))

	budget = int(max(budget, min(FAR_MIN_BUDGET, total)))
	budget = int(min(budget, min(FAR_MAX_BUDGET, total)))
	return int(max(0, budget))

func _represented_population() -> int:
	if gs == null:
		return 0

	var total: int = int(gs.npcs.size()) + int(gs.dormant_npcs.size())
	if gs.population_shard_engine != null:
		total += int(gs.population_shard_engine.get_total_sharded_population())
	return total




func _slice_people(lane_key: String, people: Array, budget: int) -> Array:
	if budget <= 0 or people.is_empty():
		return []

	if people.size() <= budget:
		lane_offsets [lane_key] = 0
		return people

	var start:= int(lane_offsets.get(lane_key, 0)) % people.size()
	var out: Array = []

	for i in range(min(budget, people.size())):
		out.append(people [(start + i) % people.size()])

	lane_offsets [lane_key] = (start + budget) % people.size()
	return out

func _partition_priority_people(people: Array) -> Dictionary:
	var priority: Array = []
	var regular: Array = []

	for npc in people:
		if npc == null:
			continue

		var keep_hot:= false
		if gs != null and gs.has_method("_npc_is_dormancy_protected"):
			keep_hot = bool(gs._npc_is_dormancy_protected(npc))

		if keep_hot:
			priority.append(npc)
		else:
			regular.append(npc)

	return {
		"priority": priority,
		"regular": regular
	}
func drain_pending_year_pipeline(max_stages: int = 1) -> void:
	if not pipeline_running:
		return




	var remaining: int = mini(
		maxi(1, max_stages),
		1
	)

	while pipeline_running and remaining > 0:
		_drain_year_pipeline_step()
		remaining -= 1