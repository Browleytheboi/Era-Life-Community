extends Resource
class_name PopulationShardEngine

var gs


var population_shards: Dictionary = {}


var lineage_ledger: Dictionary = {}

var active_contract: Dictionary = {}
var last_contract_report: Dictionary = {}
var last_spawn_report: Dictionary = {}
var truth_resolution_shard_queue: Array = []
var truth_resolution_shard_queue_keys: Dictionary = {}
var truth_resolution_shard_drain_running: bool = false
var truth_resolution_shard_drain_generation: int = 0
var truth_resolution_shard_timer_armed: bool = false
var truth_resolution_shard_timer_generation: int = -1
var truth_resolution_shard_next_allowed_ms: int = 0
var last_truth_resolution_shard_report: Dictionary = {}

const TRUTH_RESOLUTION_SHARDS_PER_DRAIN:= 1
const TRUTH_RESOLUTION_SHARD_MIN_GAP_MS:= 16
const CONTRACT_SCHEMA:= "eralife.population_shard_contract_engine"
const CONTRACT_VERSION:= 1

const YEARLY_TICK_CONTRACT:= "eralife.population.shard.yearly_tick"
const SPAWN_ENTITY_CONTRACT:= "population.shard.spawn_entity"

const EVENT_POPULATION_YEAR_TICK:= "population.year.tick"
const EVENT_POPULATION_SPAWN_ENTITY:= "population.shard.spawn_entity"

const SHARD_COLLAPSE_FAME_MAX:= 9
const SHARD_COLLAPSE_PRESTIGE_MAX:= 9
const SHARD_BATCH_YEARLY_LIMIT:= 2500

func _init(_gs):
	gs = _gs
	active_contract = build_default_population_shard_contract()

func _truth_resolution_world_epoch() -> int:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return 0

	return int(
		gs.scenario_state.get(
			"world_seed_ui_lens_epoch",
			0
		)
	)


func _truth_resolution_ui_yield_until_ms() -> int:
	if gs == null or typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return 0

	var guard_raw: Variant = gs.scenario_state.get(
		"runtime_guard",
		{}
	)
	var guard: Dictionary = (
		guard_raw as Dictionary
		if typeof(guard_raw) == TYPE_DICTIONARY
		else {}
	)

	return maxi(
		int(guard.get("ui_interaction_grace_until_ms", 0)),
		int(guard.get("truth_resolution_yield_until_ms", 0))
	)


func _truth_resolution_runtime_world_is_active() -> bool:
	if gs == null or gs.player == null:
		return false

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		return true

	if bool(
		gs.scenario_state.get(
			"menu_return_world_seed_terminated",
			false
		)
	):
		return false

	var runtime_domain: String = str(
		gs.scenario_state.get(
			"global_runtime_domain",
			""
		)
	).strip_edges().to_lower()

	return runtime_domain != "main_menu"


func _schedule_truth_resolution_shard_drain_next_frame(
	requested_generation: int
) -> void:
	if (
		requested_generation
		!= truth_resolution_shard_drain_generation
	):
		return

	if (
		truth_resolution_shard_timer_armed
		and truth_resolution_shard_timer_generation
		== requested_generation
	):
		return

	var scene_tree:= (
		Engine.get_main_loop() as SceneTree
	)

	if scene_tree == null:
		truth_resolution_shard_drain_running = false
		return

	var now_ms: int = int(
		Time.get_ticks_msec()
	)
	var delay_ms: int = maxi(
		16,
		truth_resolution_shard_next_allowed_ms
		- now_ms
	)
	var timer:= scene_tree.create_timer(
		float(delay_ms) / 1000.0,
		true,
		false,
		true
	)

	truth_resolution_shard_timer_armed = true
	truth_resolution_shard_timer_generation = (
		requested_generation
	)

	timer.timeout.connect(
		Callable(
			self,
			"_drain_truth_resolution_shard_queue_deferred"
		).bind(
			requested_generation
		),
		CONNECT_ONE_SHOT
	)

func reset_runtime() -> void:
	truth_resolution_shard_drain_generation += 1
	truth_resolution_shard_queue.clear()
	truth_resolution_shard_queue_keys.clear()
	truth_resolution_shard_drain_running = false
	truth_resolution_shard_next_allowed_ms = 0
	truth_resolution_shard_timer_armed = false
	truth_resolution_shard_timer_generation = -1

	last_truth_resolution_shard_report = {
		"success": true,
		"schema": (
			"eralife.population_shard_engine."
			+ "runtime_reset_report"
		),
		"generation": (
			truth_resolution_shard_drain_generation
		),
		"queue_size": 0,
		"at_ms": int(
			Time.get_ticks_msec()
		)
	}

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"population_shard_engine_runtime_reset_report"
		] = last_truth_resolution_shard_report.duplicate(
			false
		)



func _age_band(age: int) -> String:
	if age <= 4:
		return "0_4"
	if age <= 12:
		return "5_12"
	if age <= 17:
		return "13_17"
	if age <= 25:
		return "18_25"
	if age <= 40:
		return "26_40"
	if age <= 60:
		return "41_60"
	if age <= 80:
		return "61_80"
	return "81_plus"


func _build_shard_key_from_facts(facts: Dictionary) -> String:
	var era_name: String = _current_era_name()
	var realm_id: int = int(facts.get("realm_id", -1))
	var social_class: String = str(facts.get("social_class", "Commoner"))
	var gender: String = str(facts.get("gender", "Unknown"))
	var age_band: String = _age_band(int(facts.get("age", 0)))
	var home_country: String = str(facts.get("home_country", "UnknownCountry"))
	var bending_cohort: String = _bending_cohort_from_facts(facts)

	return "%s|realm_%s|%s|%s|%s|%s|%s" % [
		era_name,
		str(realm_id),
		home_country,
		social_class,
		gender,
		age_band,
		bending_cohort
	]




func record_lineage_from_snapshot(d: Dictionary) -> void:
	if typeof(d) != TYPE_DICTIONARY:
		return

	var npc_id:= int(d.get("id", -1))
	if npc_id <= 0:
		return

	var memories_raw: Variant = d.get("memories", [])
	var memories: Array = memories_raw if typeof(memories_raw) == TYPE_ARRAY else []
	var memory_start: int = max(0, memories.size() - 4)
	var recent_memories: Array = memories.slice(memory_start, memories.size())

	var affection_raw: Variant = d.get("affection", {})
	var affection: Dictionary = affection_raw if typeof(affection_raw) == TYPE_DICTIONARY else {}

	lineage_ledger [npc_id] = {
		"id": npc_id,
		"first_name": str(d.get("first_name", "")),
		"last_name": str(d.get("last_name", "")),
		"name": "%s %s" % [str(d.get("first_name", "")), str(d.get("last_name", ""))],
		"age": int(d.get("age", 0)),
		"alive": bool(d.get("alive", true)),
		"gender": str(d.get("gender", "")),
		"parents": d.get("parents", []).duplicate(),
		"children": d.get("children", []).duplicate(),
		"friends": d.get("friends", []).duplicate(),
		"partner_id": int(d.get("partner_id", -1)),
		"realm_id": int(d.get("realm_id", -1)),
		"social_class": str(d.get("social_class", "Commoner")),
		"fame": int(d.get("fame", 0)),
		"fame_tier": str(d.get("fame_tier", "None")),
		"dynasty_prestige": int(d.get("dynasty_prestige", 0)),
		"dynasty_origin": str(d.get("dynasty_origin", "")),
		"birth_city": str(d.get("birth_city", "")),
		"birth_country": str(d.get("birth_country", "")),
		"home_city": str(d.get("home_city", "")),
		"home_country": str(d.get("home_country", "")),
		"traits": d.get("traits", []).duplicate(),
		"memories": recent_memories.duplicate(true),
		"affection": affection.duplicate(true),
		"fate_arc": str(d.get("fate_arc", "")),
		"marital_status": str(d.get("marital_status", "Single")),
		"bending_type": str(d.get("bending_type", "none")),
		"bending_nation": str(d.get("bending_nation", "")),
		"is_royal": bool(d.get("is_royal", false)),
		"royal_title": str(d.get("royal_title", "")),
		"approval": int(d.get("approval", 50)),
		"is_ruler": bool(d.get("is_ruler", false)),
		"succession_rank": int(d.get("succession_rank", 99)),
		"exiled": bool(d.get("exiled", false)),
		"deposed": bool(d.get("deposed", false)),
		"palace_owned": bool(d.get("palace_owned", false)),
		"strategic_focus": str(d.get("strategic_focus", "")),
		"motivation": int(d.get("motivation", 50)),
		"ambition": int(d.get("ambition", 50)),
		"source_state": "lineage_only"
	}


func get_lineage_facts(npc_id: int) -> Dictionary:
	if not lineage_ledger.has(npc_id):
		return {}
	return lineage_ledger [npc_id].duplicate(true)





func can_collapse_snapshot_to_shard(d: Dictionary) -> bool:
	if typeof(d) != TYPE_DICTIONARY:
		return false

	if not bool(d.get("alive", true)):
		return false

	if int(d.get("fame", 0)) > SHARD_COLLAPSE_FAME_MAX:
		return false

	if int(d.get("dynasty_prestige", 0)) > SHARD_COLLAPSE_PRESTIGE_MAX:
		return false

	if int(d.get("partner_id", -1)) != -1:
		return false

	var children: Array = _safe_array(d.get("children", []))
	if children.size() > 0:
		return false

	if not _contract_allows_collapse_snapshot(d):
		return false

	return true




func collapse_snapshot_to_shard(d: Dictionary) -> bool:
	if not can_collapse_snapshot_to_shard(d):
		return false

	record_lineage_from_snapshot(d)

	var facts: Dictionary = {}
	if gs != null and gs.has_method("_extract_queryable_npc_facts"):
		facts = gs._extract_queryable_npc_facts(d)
	else:
		facts = _extract_fallback_queryable_facts(d)

	facts = _enrich_shard_facts_from_snapshot(d, facts)

	var key: String = _build_shard_key_from_facts(facts)

	if not population_shards.has(key):
		population_shards [key] = {
			"schema": "eralife.population.shard",
			"version": CONTRACT_VERSION,
			"key": key,
			"era_name": _current_era_name(),
			"world_profile": _resolve_population_world_profile({}),
			"realm_id": int(facts.get("realm_id", -1)),
			"home_country": str(facts.get("home_country", "")),
			"social_class": str(facts.get("social_class", "Commoner")),
			"gender": str(facts.get("gender", "Unknown")),
			"age_band": _age_band(int(facts.get("age", 0))),
			"bending_type": str(facts.get("bending_type", d.get("bending_type", "none"))),
			"bending_nation": str(facts.get("bending_nation", d.get("bending_nation", ""))),
			"bending_cohort": _bending_cohort_from_facts(facts),
			"count": 0,
			"sample_ids": [],
			"avg_health": 70.0,
			"avg_mental_health": 70.0,
			"avg_income": 0.0,
			"avg_bank_balance": 0.0,
			"dynasty_weights": {},
			"bending_weights": {},
			"buffer_pool": [],
			"last_contract_tick": {},
			"created_year": int(gs.year) if gs != null else 0,
			"updated_year": int(gs.year) if gs != null else 0
		}

	var shard: Dictionary = _safe_dictionary(population_shards.get(key, {}))
	shard ["count"] = int(shard.get("count", 0)) + 1
	shard ["updated_year"] = int(gs.year) if gs != null else int(shard.get("updated_year", 0))

	var sample_ids: Array = _safe_array(shard.get("sample_ids", []))
	if sample_ids.size() < 24:
		sample_ids.append(int(d.get("id", -1)))
	shard ["sample_ids"] = sample_ids

	var buffer_pool: Array = _safe_array(shard.get("buffer_pool", []))
	var buffered_snapshot: Dictionary = d.duplicate(true)
	buffered_snapshot ["_dormant"] = true
	buffered_snapshot ["_dormant_year"] = int(gs.year) if gs != null else 0
	buffered_snapshot ["_query_facts"] = facts.duplicate(true)
	buffer_pool.append(buffered_snapshot)

	while buffer_pool.size() > 12:
		buffer_pool.pop_front()

	shard ["buffer_pool"] = buffer_pool

	var last_name: String = str(d.get("last_name", ""))
	if last_name != "":
		var dyn: Dictionary = _safe_dictionary(shard.get("dynasty_weights", {}))
		dyn [last_name] = int(dyn.get(last_name, 0)) + 1
		shard ["dynasty_weights"] = dyn

	var bending_type: String = str(d.get("bending_type", "none")).strip_edges()
	if bending_type == "":
		bending_type = "none"

	var bending_weights: Dictionary = _safe_dictionary(shard.get("bending_weights", {}))
	bending_weights [bending_type] = int(bending_weights.get(bending_type, 0)) + 1
	shard ["bending_weights"] = bending_weights

	shard ["avg_health"] = _rolling_avg(
		float(shard.get("avg_health", 70.0)),
		int(shard ["count"]),
		float(d.get("health", 70.0))
	)

	shard ["avg_mental_health"] = _rolling_avg(
		float(shard.get("avg_mental_health", 70.0)),
		int(shard ["count"]),
		float(d.get("mental_health", 70.0))
	)

	shard ["avg_income"] = _rolling_avg(
		float(shard.get("avg_income", 0.0)),
		int(shard ["count"]),
		float(d.get("income", 0.0))
	)

	shard ["avg_bank_balance"] = _rolling_avg(
		float(shard.get("avg_bank_balance", 0.0)),
		int(shard ["count"]),
		float(d.get("bank_balance", 0.0))
	)

	population_shards [key] = shard
	return true

func _rolling_avg(current_avg: float, count_after: int, new_value: float) -> float:
	if count_after <= 1:
		return new_value
	return ((current_avg * float(count_after - 1)) + new_value) / float(count_after)





func yearly_tick(payload:= {}) -> Dictionary:
	var context: Dictionary = payload if typeof(payload) == TYPE_DICTIONARY else {}
	context ["source"] = str(context.get("source", "direct_compat_yearly_tick"))

	var contract: Dictionary = build_yearly_tick_contract(context)
	return execute_yearly_tick_contract(contract)


func on_population_year_tick(payload: Dictionary) -> void:
	var context: Dictionary = payload if typeof(payload) == TYPE_DICTIONARY else {}
	var contract: Dictionary = build_yearly_tick_contract(context)
	execute_yearly_tick_contract(contract)
func get_event_bus_contract() -> Dictionary:
	return {
		"schema": "eralife.event_bus_contract_layer",
		"version": 1,
		"id": "population_shard_event_bus_contract",
		"source_path": "runtime://population_shard_engine",
		"dispatch_lanes": [
			{
				"id": "population_ambient",
				"policy": "deferred",
				"priority": 140,
				"force_immediate": false,
				"defer_by_default": true,
				"queue_limit": 256
			}
		],
		"events": [
			{
				"id": "population_year_tick",
				"event": EVENT_POPULATION_YEAR_TICK,
				"lane": "population_ambient",
				"schema_policy": "warn",
				"allow_unknown_keys": true,
				"required_keys": ["year"],
				"optional_keys": ["shard_keys", "contract", "rules", "source"],
				"key_types": {
					"year": "int",
					"shard_keys": "array",
					"contract": "dictionary",
					"rules": "array",
					"source": "string"
				},
				"duplicate_keys": ["year", "source"],
				"duplicate_ttl_ms": 25,
				"replay_enabled": false
			},
			{
				"id": "population_spawn_entity",
				"event": EVENT_POPULATION_SPAWN_ENTITY,
				"lane": "important",
				"schema_policy": "warn",
				"allow_unknown_keys": true,
				"required_keys": ["contract"],
				"optional_keys": ["source", "selection", "lineage_restore", "filters"],
				"key_types": {
					"contract": "string",
					"source": "string",
					"selection": "string",
					"lineage_restore": "bool",
					"filters": "dictionary"
				},
				"duplicate_ttl_ms": 0,
				"replay_enabled": false
			}
		]
	}


func build_default_population_shard_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "population_shard_runtime_contract",
		"world_profiles": {
			"normal": {
				"collapse_block_traits": ["Immortal", "Ageless", "Undying"]
			},
			"ancient_medieval": {
				"collapse_block_traits": ["Immortal", "Ageless", "Undying"]
			},
			"sci_fi": {
				"collapse_block_traits": ["Immortal", "Ageless", "Undying", "Android", "Synthetic Immortal", "Digitized Consciousness"]
			},
			"avatar_bending": {
				"collapse_block_traits": ["Immortal", "Ageless", "Undying"],
			}
		},
		"era_profiles": {
			"Ancient Era": _ancient_population_rules(),
			"Medieval Era": _medieval_population_rules(),
			"Industrial Era": _industrial_population_rules(),
			"Modern Era": _modern_population_rules(),
			"Future Era": _future_population_rules()
		}
	}


func build_yearly_tick_contract(context: Dictionary = {}) -> Dictionary:
	var shard_keys: Array = []

	var raw_keys: Variant = context.get("shard_keys", [])
	if typeof(raw_keys) == TYPE_ARRAY:
		for raw_key in raw_keys:
			var clean_key: String = str(raw_key).strip_edges()
			if clean_key != "" and population_shards.has(clean_key):
				shard_keys.append(clean_key)

	if shard_keys.is_empty():
		for key in population_shards.keys():
			shard_keys.append(str(key))

	var era_name: String = str(context.get("era_name", _current_era_name())).strip_edges()
	if era_name == "":
		era_name = "Modern Era"

	var world_profile: String = _resolve_population_world_profile(context)
	var rules: Array = _rules_for_population_context(era_name, world_profile, context)

	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"contract": YEARLY_TICK_CONTRACT,
		"contract_id": "population_year_tick_%s_%s" % [era_name.replace(" ", "_").to_lower(), world_profile],
		"source": str(context.get("source", "population_shard_engine")),
		"inputs": {
			"year": int(context.get("year", int(gs.year) if gs != null else 0)),
			"era_name": era_name,
			"world_profile": world_profile,
			"shard_keys": shard_keys,
			"batch_limit": int(context.get("batch_limit", SHARD_BATCH_YEARLY_LIMIT))
		},
		"rules": rules,
		"cleanup": {
			"remove_empty_shards": true
		}
	}


func execute_yearly_tick_contract(contract: Dictionary) -> Dictionary:
	if population_shards.is_empty():
		last_contract_report = {
			"schema": "eralife.population.shard.yearly_tick_report",
			"version": CONTRACT_VERSION,
			"success": true,
			"processed": 0,
			"reason": "No population shards exist.",
			"contract": contract.duplicate(true)
		}
		return last_contract_report.duplicate(true)

	var inputs: Dictionary = _safe_dictionary(contract.get("inputs", {}))
	var rules: Array = _safe_array(contract.get("rules", []))
	var shard_keys: Array = _safe_array(inputs.get("shard_keys", []))
	var batch_limit: int = max(1, int(inputs.get("batch_limit", SHARD_BATCH_YEARLY_LIMIT)))
	var year_value: int = int(inputs.get("year", int(gs.year) if gs != null else 0))

	var processed: int = 0
	var deaths: int = 0
	var touched: Array = []

	for raw_key in shard_keys:
		if processed >= batch_limit:
			break

		var key: String = str(raw_key).strip_edges()
		if key == "" or not population_shards.has(key):
			continue

		var shard: Dictionary = _safe_dictionary(population_shards.get(key, {}))
		var count: int = int(shard.get("count", 0))
		if count <= 0:
			continue

		var before_count: int = count
		processed += 1

		for raw_rule in rules:
			if typeof(raw_rule) != TYPE_DICTIONARY:
				continue

			shard = _apply_yearly_rule_to_shard(shard, raw_rule as Dictionary, contract)

		var after_count: int = int(shard.get("count", before_count))
		deaths += max(0, before_count - after_count)

		shard ["updated_year"] = year_value
		shard ["last_contract_tick"] = {
			"contract": str(contract.get("contract", "")),
			"contract_id": str(contract.get("contract_id", "")),
			"year": year_value,
			"world_profile": str(inputs.get("world_profile", "")),
			"era_name": str(inputs.get("era_name", "")),
			"rule_count": rules.size()
		}

		population_shards [key] = shard
		touched.append(key)

	var cleanup_raw: Variant = contract.get("cleanup", {})
	var cleanup: Dictionary = cleanup_raw if typeof(cleanup_raw) == TYPE_DICTIONARY else {}
	if bool(cleanup.get("remove_empty_shards", true)):
		_cleanup_empty_shards()

	last_contract_report = {
		"schema": "eralife.population.shard.yearly_tick_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract": str(contract.get("contract", "")),
		"contract_id": str(contract.get("contract_id", "")),
		"year": year_value,
		"processed": processed,
		"deaths": deaths,
		"touched_shards": touched,
		"remaining_shards": population_shards.size(),
		"total_sharded_population": get_total_sharded_population(),
		"inputs": inputs.duplicate(true)
	}

	return last_contract_report.duplicate(true)


func _apply_yearly_rule_to_shard(shard: Dictionary, rule: Dictionary, _contract: Dictionary) -> Dictionary:
	var out: Dictionary = shard.duplicate(true)
	var op: String = str(rule.get("op", "")).strip_edges().to_lower()

	match op:
		"drift":
			var drift_field: String = str(rule.get("field", "")).strip_edges()
			if drift_field == "":
				return out

			var range_values: Array = _safe_array(rule.get("range", [0.0, 0.0]))
			var min_value: float = float(range_values [0]) if range_values.size() > 0 else 0.0
			var max_value: float = float(range_values [1]) if range_values.size() > 1 else 0.0
			out [drift_field] = float(out.get(drift_field, 0.0)) + randf_range(min_value, max_value)

		"clamp":
			var clamp_field: String = str(rule.get("field", "")).strip_edges()
			if clamp_field == "":
				return out

			out [clamp_field] = clamp(
				float(out.get(clamp_field, 0.0)),
				float(rule.get("min", 0.0)),
				float(rule.get("max", 100.0))
			)

		"mortality":
			var target_age_band: String = str(rule.get("age_band", "")).strip_edges()
			if target_age_band == "" or str(out.get("age_band", "")) != target_age_band:
				return out

			var count: int = int(out.get("count", 0))
			if count <= 0:
				return out

			var rate: float = clamp(float(rule.get("rate", 0.01)), 0.0, 1.0)
			var max_deaths: int = max(0, int(ceil(float(count) * rate)))

			if max_deaths <= 0:
				return out

			var death_rolls: int = randi_range(0, max_deaths)
			out ["count"] = max(0, count - death_rolls)

		"multiplier_chance":
			var multiplier_field: String = str(rule.get("field", "")).strip_edges()
			if multiplier_field == "":
				return out

			var chance: int = clamp(int(rule.get("chance", 0)), 0, 100)
			if randi() % 100 >= chance:
				return out

			var multiplier_range: Array = _safe_array(rule.get("range", [1.0, 1.0]))
			var multiplier_min: float = float(multiplier_range [0]) if multiplier_range.size() > 0 else 1.0
			var multiplier_max: float = float(multiplier_range [1]) if multiplier_range.size() > 1 else 1.0
			out [multiplier_field] = float(out.get(multiplier_field, 0.0)) * randf_range(multiplier_min, multiplier_max)

		"bending_power_shift":
			out = _apply_bending_power_shift_rule(out, rule)

		_:
			return out

	return out
func _ancient_population_rules() -> Array:
	return [
		{ "op": "drift", "field": "avg_income", "range": [-300.0, 500.0]},
		{ "op": "drift", "field": "avg_bank_balance", "range": [-500.0, 700.0]},
		{ "op": "drift", "field": "avg_health", "range": [-2.5, 0.3]},
		{ "op": "clamp", "field": "avg_health", "min": 0.0, "max": 100.0},
		{ "op": "drift", "field": "avg_mental_health", "range": [-1.4, 0.5]},
		{ "op": "clamp", "field": "avg_mental_health", "min": 0.0, "max": 100.0},
		{ "op": "mortality", "age_band": "0_4", "rate": 0.035},
		{ "op": "mortality", "age_band": "5_12", "rate": 0.014},
		{ "op": "mortality", "age_band": "13_17", "rate": 0.01},
		{ "op": "mortality", "age_band": "18_25", "rate": 0.014},
		{ "op": "mortality", "age_band": "26_40", "rate": 0.02},
		{ "op": "mortality", "age_band": "41_60", "rate": 0.045},
		{ "op": "mortality", "age_band": "61_80", "rate": 0.095},
		{ "op": "mortality", "age_band": "81_plus", "rate": 0.22},
		{ "op": "multiplier_chance", "field": "avg_income", "chance": 3, "range": [0.92, 1.04]}
	]


func _medieval_population_rules() -> Array:
	return [
		{ "op": "drift", "field": "avg_income", "range": [-450.0, 650.0]},
		{ "op": "drift", "field": "avg_bank_balance", "range": [-800.0, 900.0]},
		{ "op": "drift", "field": "avg_health", "range": [-2.1, 0.4]},
		{ "op": "clamp", "field": "avg_health", "min": 0.0, "max": 100.0},
		{ "op": "drift", "field": "avg_mental_health", "range": [-1.3, 0.6]},
		{ "op": "clamp", "field": "avg_mental_health", "min": 0.0, "max": 100.0},
		{ "op": "mortality", "age_band": "0_4", "rate": 0.028},
		{ "op": "mortality", "age_band": "5_12", "rate": 0.012},
		{ "op": "mortality", "age_band": "13_17", "rate": 0.009},
		{ "op": "mortality", "age_band": "18_25", "rate": 0.013},
		{ "op": "mortality", "age_band": "26_40", "rate": 0.018},
		{ "op": "mortality", "age_band": "41_60", "rate": 0.04},
		{ "op": "mortality", "age_band": "61_80", "rate": 0.085},
		{ "op": "mortality", "age_band": "81_plus", "rate": 0.2},
		{ "op": "multiplier_chance", "field": "avg_income", "chance": 4, "range": [0.93, 1.05]}
	]


func _industrial_population_rules() -> Array:
	return [
		{ "op": "drift", "field": "avg_income", "range": [-600.0, 1400.0]},
		{ "op": "drift", "field": "avg_bank_balance", "range": [-1200.0, 1900.0]},
		{ "op": "drift", "field": "avg_health", "range": [-1.8, 0.6]},
		{ "op": "clamp", "field": "avg_health", "min": 0.0, "max": 100.0},
		{ "op": "drift", "field": "avg_mental_health", "range": [-1.1, 0.7]},
		{ "op": "clamp", "field": "avg_mental_health", "min": 0.0, "max": 100.0},
		{ "op": "mortality", "age_band": "0_4", "rate": 0.02},
		{ "op": "mortality", "age_band": "5_12", "rate": 0.008},
		{ "op": "mortality", "age_band": "13_17", "rate": 0.007},
		{ "op": "mortality", "age_band": "18_25", "rate": 0.01},
		{ "op": "mortality", "age_band": "26_40", "rate": 0.014},
		{ "op": "mortality", "age_band": "41_60", "rate": 0.032},
		{ "op": "mortality", "age_band": "61_80", "rate": 0.07},
		{ "op": "mortality", "age_band": "81_plus", "rate": 0.16},
		{ "op": "multiplier_chance", "field": "avg_income", "chance": 5, "range": [0.94, 1.09]}
	]


func _modern_population_rules() -> Array:
	return [
		{ "op": "drift", "field": "avg_income", "range": [-800.0, 1200.0]},
		{ "op": "drift", "field": "avg_bank_balance", "range": [-1500.0, 2500.0]},
		{ "op": "drift", "field": "avg_health", "range": [-1.5, 0.5]},
		{ "op": "clamp", "field": "avg_health", "min": 0.0, "max": 100.0},
		{ "op": "drift", "field": "avg_mental_health", "range": [-1.0, 0.8]},
		{ "op": "clamp", "field": "avg_mental_health", "min": 0.0, "max": 100.0},
		{ "op": "mortality", "age_band": "0_4", "rate": 0.006},
		{ "op": "mortality", "age_band": "5_12", "rate": 0.003},
		{ "op": "mortality", "age_band": "13_17", "rate": 0.004},
		{ "op": "mortality", "age_band": "18_25", "rate": 0.006},
		{ "op": "mortality", "age_band": "26_40", "rate": 0.008},
		{ "op": "mortality", "age_band": "41_60", "rate": 0.018},
		{ "op": "mortality", "age_band": "61_80", "rate": 0.045},
		{ "op": "mortality", "age_band": "81_plus", "rate": 0.11},
		{ "op": "multiplier_chance", "field": "avg_income", "chance": 5, "range": [0.95, 1.08]}
	]


func _future_population_rules() -> Array:
	return [
		{ "op": "drift", "field": "avg_income", "range": [-500.0, 2500.0]},
		{ "op": "drift", "field": "avg_bank_balance", "range": [-900.0, 4200.0]},
		{ "op": "drift", "field": "avg_health", "range": [-0.5, 1.0]},
		{ "op": "clamp", "field": "avg_health", "min": 0.0, "max": 100.0},
		{ "op": "drift", "field": "avg_mental_health", "range": [-0.8, 1.0]},
		{ "op": "clamp", "field": "avg_mental_health", "min": 0.0, "max": 100.0},
		{ "op": "mortality", "age_band": "0_4", "rate": 0.003},
		{ "op": "mortality", "age_band": "5_12", "rate": 0.001},
		{ "op": "mortality", "age_band": "13_17", "rate": 0.001},
		{ "op": "mortality", "age_band": "18_25", "rate": 0.002},
		{ "op": "mortality", "age_band": "26_40", "rate": 0.003},
		{ "op": "mortality", "age_band": "41_60", "rate": 0.007},
		{ "op": "mortality", "age_band": "61_80", "rate": 0.018},
		{ "op": "mortality", "age_band": "81_plus", "rate": 0.045},
		{ "op": "multiplier_chance", "field": "avg_income", "chance": 7, "range": [0.98, 1.14]}
	]


func _rules_for_population_context(era_name: String, world_profile: String, context: Dictionary = {}) -> Array:
	var era_profiles: Dictionary = _safe_dictionary(active_contract.get("era_profiles", {}))
	var rules: Array = []

	var era_rules_raw: Variant = era_profiles.get(era_name, _modern_population_rules())
	var era_rules: Array = era_rules_raw if typeof(era_rules_raw) == TYPE_ARRAY else _modern_population_rules()

	for raw_rule in era_rules:
		if typeof(raw_rule) == TYPE_DICTIONARY:
			rules.append((raw_rule as Dictionary).duplicate(true))

	if world_profile == "avatar_bending":
		rules.append({
			"op": "bending_power_shift",
			"power_factor": 1.0,
			"income_multiplier_range": [1.0, 1.025],
			"health_drift_range": [0.0, 0.8],
			"mental_drift_range": [-0.2, 0.6]
		})

	var explicit_rules_raw: Variant = context.get("rules", [])
	if typeof(explicit_rules_raw) == TYPE_ARRAY:
		for raw_explicit_rule in explicit_rules_raw:
			if typeof(raw_explicit_rule) == TYPE_DICTIONARY:
				rules.append((raw_explicit_rule as Dictionary).duplicate(true))

	return rules


func _cleanup_empty_shards() -> void:
	var to_remove:= []
	for key in population_shards.keys():
		if int(population_shards [key].get("count", 0)) <= 0:
			to_remove.append(key)
	for key in to_remove:
		population_shards.erase(key)





func get_total_sharded_population() -> int:
	var total:= 0
	for key in population_shards.keys():
		total += int(population_shards [key].get("count", 0))
	return total


func get_realm_population(realm_id: int) -> int:
	var total:= 0
	for key in population_shards.keys():
		var shard = population_shards [key]
		if int(shard.get("realm_id", -1)) == realm_id:
			total += int(shard.get("count", 0))
	return total
func _current_era_name() -> String:
	if gs != null and gs.era != null:
		return str(gs.era.name)
	return "UnknownEra"


func _resolve_population_world_profile(context: Dictionary = {}) -> String:
	var explicit_profile: String = str(context.get("world_profile", context.get("population_world_profile", ""))).strip_edges().to_lower()
	if explicit_profile != "":
		return explicit_profile

	var era_name: String = _current_era_name()
	if era_name == "Ancient Era" or era_name == "Medieval Era":
		return "ancient_medieval"

	if era_name == "Future Era":
		return "sci_fi"

	if _has_bending_population_context():
		return "avatar_bending"

	return "normal"


func _has_bending_population_context() -> bool:
	if gs != null and gs.player != null:
		if str(gs.player.bending_type).strip_edges().to_lower() not in ["", "none"]:
			return true
		if str(gs.player.bending_nation).strip_edges() != "":
			return true

	for key in population_shards.keys():
		var shard: Dictionary = _safe_dictionary(population_shards.get(key, {}))
		if str(shard.get("bending_cohort", "")).strip_edges().to_lower() not in ["", "non_bender"]:
			return true

		var bending_weights: Dictionary = _safe_dictionary(shard.get("bending_weights", {}))
		for bending_key in bending_weights.keys():
			var clean_bending: String = str(bending_key).strip_edges().to_lower()
			if clean_bending not in ["", "none"]:
				return true

	return false


func _bending_cohort_from_facts(facts: Dictionary) -> String:
	var bending_type: String = str(facts.get("bending_type", "none")).strip_edges().to_lower()
	var bending_nation: String = str(facts.get("bending_nation", "")).strip_edges().to_lower()

	if bending_type == "" or bending_type == "none":
		return "non_bender"

	if bending_type == "avatar":
		return "avatar"

	if bending_nation != "":
		return "bender_%s_%s" % [
			bending_nation.replace(" ", "_"),
			bending_type.replace(" ", "_")
		]

	return "bender_%s" % bending_type.replace(" ", "_")


func _apply_bending_power_shift_rule(shard: Dictionary, rule: Dictionary) -> Dictionary:
	var out: Dictionary = shard.duplicate(true)
	var cohort: String = str(out.get("bending_cohort", "")).strip_edges().to_lower()

	if cohort == "" or cohort == "non_bender":
		return out

	var bending_type: String = str(out.get("bending_type", "none")).strip_edges().to_lower()
	if bending_type == "" or bending_type == "none":
		return out

	var income_range: Array = _safe_array(rule.get("income_multiplier_range", [1.0, 1.02]))
	var income_min: float = float(income_range [0]) if income_range.size() > 0 else 1.0
	var income_max: float = float(income_range [1]) if income_range.size() > 1 else 1.02

	var health_range: Array = _safe_array(rule.get("health_drift_range", [0.0, 0.5]))
	var health_min: float = float(health_range [0]) if health_range.size() > 0 else 0.0
	var health_max: float = float(health_range [1]) if health_range.size() > 1 else 0.5

	var mental_range: Array = _safe_array(rule.get("mental_drift_range", [-0.1, 0.4]))
	var mental_min: float = float(mental_range [0]) if mental_range.size() > 0 else -0.1
	var mental_max: float = float(mental_range [1]) if mental_range.size() > 1 else 0.4

	out ["avg_income"] = max(0.0, float(out.get("avg_income", 0.0)) * randf_range(income_min, income_max))
	out ["avg_health"] = clamp(float(out.get("avg_health", 70.0)) + randf_range(health_min, health_max), 0.0, 100.0)
	out ["avg_mental_health"] = clamp(float(out.get("avg_mental_health", 70.0)) + randf_range(mental_min, mental_max), 0.0, 100.0)

	return out


func _contract_allows_collapse_snapshot(d: Dictionary) -> bool:
	var traits: Array = _safe_array(d.get("traits", []))
	var world_profile: String = _resolve_population_world_profile({})
	var world_profiles: Dictionary = _safe_dictionary(active_contract.get("world_profiles", {}))
	var profile: Dictionary = _safe_dictionary(world_profiles.get(world_profile, {}))
	var blocked_traits: Array = _safe_array(profile.get("collapse_block_traits", ["Immortal", "Ageless", "Undying"]))

	for raw_trait in traits:
		var clean_trait: String = str(raw_trait).strip_edges().to_lower()
		if clean_trait == "":
			continue

		for raw_blocked in blocked_traits:
			var blocked_trait: String = str(raw_blocked).strip_edges().to_lower()
			if blocked_trait != "" and clean_trait == blocked_trait:
				return false

	return true

func _enrich_shard_facts_from_snapshot(d: Dictionary, facts: Dictionary) -> Dictionary:
	var out: Dictionary = facts.duplicate(true)

	if not out.has("realm_id"):
		out ["realm_id"] = int(d.get("realm_id", -1))
	if not out.has("home_country"):
		out ["home_country"] = str(d.get("home_country", d.get("birth_country", "UnknownCountry")))
	if not out.has("social_class"):
		out ["social_class"] = str(d.get("social_class", "Commoner"))
	if not out.has("gender"):
		out ["gender"] = str(d.get("gender", "Unknown"))
	if not out.has("age"):
		out ["age"] = int(d.get("age", 0))

	out ["bending_type"] = str(out.get("bending_type", d.get("bending_type", "none")))
	out ["bending_nation"] = str(out.get("bending_nation", d.get("bending_nation", "")))
	out ["bending_cohort"] = _bending_cohort_from_facts(out)

	return out


func _extract_fallback_queryable_facts(d: Dictionary) -> Dictionary:
	return {
		"realm_id": int(d.get("realm_id", -1)),
		"home_country": str(d.get("home_country", d.get("birth_country", "UnknownCountry"))),
		"social_class": str(d.get("social_class", "Commoner")),
		"gender": str(d.get("gender", "Unknown")),
		"age": int(d.get("age", 0)),
		"bending_type": str(d.get("bending_type", "none")),
		"bending_nation": str(d.get("bending_nation", ""))
	}


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)


func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)
func build_spawn_entity_contract(filters: Dictionary = {}) -> Dictionary:
	return {
		"contract": SPAWN_ENTITY_CONTRACT,
		"source": "population_shard_engine",
		"selection": str(filters.get("selection", "weighted_sample")),
		"lineage_restore": bool(filters.get("lineage_restore", true)),
		"filters": filters.duplicate(true)
	}


func on_population_spawn_entity(payload: Dictionary) -> void:
	var request: Dictionary = _normalize_spawn_entity_request(payload)

	if gs == null or gs.population_lifecycle_manager == null:
		last_spawn_report = {
			"schema": "eralife.population.shard.spawn_entity_report",
			"version": CONTRACT_VERSION,
			"success": false,
			"reason": "PopulationLifecycleManager unavailable.",
			"request": request.duplicate(true)
		}
		return

	if not gs.population_lifecycle_manager.has_method("materialize_person_from_shard"):
		last_spawn_report = {
			"schema": "eralife.population.shard.spawn_entity_report",
			"version": CONTRACT_VERSION,
			"success": false,
			"reason": "PopulationLifecycleManager missing materialize_person_from_shard().",
			"request": request.duplicate(true)
		}
		return

	var person = gs.population_lifecycle_manager.materialize_person_from_shard(request)

	last_spawn_report = {
		"schema": "eralife.population.shard.spawn_entity_report",
		"version": CONTRACT_VERSION,
		"success": person != null,
		"person_id": int(person.id) if person != null else -1,
		"person_name": ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges() if person != null else "",
		"request": request.duplicate(true)
	}


func _normalize_spawn_entity_request(payload: Dictionary) -> Dictionary:
	var request: Dictionary = payload.duplicate(true)

	if str(request.get("contract", "")).strip_edges() == "":
		request ["contract"] = SPAWN_ENTITY_CONTRACT

	if str(request.get("selection", "")).strip_edges() == "":
		request ["selection"] = "weighted_sample"

	if not request.has("lineage_restore"):
		request ["lineage_restore"] = true

	if not request.has("filters") or typeof(request.get("filters")) != TYPE_DICTIONARY:
		var filters: Dictionary = {}
		for key in ["realm_id", "home_country", "social_class", "gender", "age_band", "bending_type", "bending_nation", "bending_cohort"]:
			if request.has(key):
				filters [key] = request.get(key)
		request ["filters"] = filters

	return request
func enqueue_truth_resolution_shards_for_realm(
	realm_id: int,
	realm_name: String = "",
	context: Dictionary = {}
) -> Dictionary:
	if gs == null or realm_id <= 0:
		return {
			"success": false,
			"reason": "missing_game_state_or_invalid_realm",
			"schema": CONTRACT_SCHEMA
		}

	if not _truth_resolution_runtime_world_is_active():
		return {
			"success": false,
			"reason": "world_runtime_not_active",
			"schema": CONTRACT_SCHEMA,
			"realm_id": realm_id,
		}

	var resolved_name: String = str(
		realm_name
	).strip_edges()

	if resolved_name == "":
		resolved_name = (
			_truth_resolution_realm_name_for_id(
				realm_id
			)
		)

	var shards: Array = (
		_truth_resolution_shards_for_realm(
			realm_id,
			resolved_name,
			context
		)
	)
	var queued_count: int = 0
	var queue_generation: int = (
		truth_resolution_shard_drain_generation
	)
	var world_epoch: int = (
		_truth_resolution_world_epoch()
	)

	for raw_shard in shards:
		if typeof(raw_shard) != TYPE_DICTIONARY:
			continue

		var shard: Dictionary = (
			raw_shard as Dictionary
		).duplicate(false)
		var shard_key: String = str(
			shard.get(
				"shard_key",
				""
			)
		).strip_edges()

		if shard_key == "":
			continue

		if truth_resolution_shard_queue_keys.has(
			shard_key
		):
			continue

		shard [
			"truth_resolution_drain_generation"
		] = queue_generation
		shard [
			"world_seed_ui_lens_epoch"
		] = world_epoch
		shard [
			"ui_input_must_win"
		] = true
		shard [
			"one_shard_per_timer_quantum"
		] = true
		shard [
			"one_shard_per_rendered_frame"
		] = false
		shard [
			"process_frame_service_forbidden"
		] = true
		shard [
			"recursive_call_deferred_forbidden"
		] = true
		shard [
			"queued_at_ms"
		] = int(
			Time.get_ticks_msec()
		)

		truth_resolution_shard_queue.append(
			shard
		)
		truth_resolution_shard_queue_keys [
			shard_key
		] = true
		queued_count += 1

	last_truth_resolution_shard_report = {
		"success": true,
		"schema": (
			"eralife.population_shard_engine."
			+ "truth_resolution_queue_report"
		),
		"realm_id": realm_id,
		"realm_name": resolved_name,
		"queued_count": queued_count,
		"queue_size": truth_resolution_shard_queue.size(),
		"generation": queue_generation,
		"world_seed_ui_lens_epoch": world_epoch,
		"one_shard_per_timer_quantum": true,
		"one_shard_per_rendered_frame": false,
		"process_frame_service_forbidden": true,
		"ui_input_must_win": true,
		"ready_door_may_not_wait": true,
		"ui_is_renderer_only": true,
		"at_ms": int(
			Time.get_ticks_msec()
		)
	}
	var player_control_released: bool = false

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		player_control_released = (
			bool(
				gs.scenario_state.get(
					"spawn_ready_live_ui_shell_released",
					false
				)
			)
			or bool(
				gs.scenario_state.get(
					"birth_shell_player_control_released",
					false
				)
			)
			or bool(
				gs.scenario_state.get(
					"spawn_ready_live_ui_shell_reconciled",
					false
				)
			)
		)

	if (
		player_control_released
		and not truth_resolution_shard_drain_running
	):
		request_truth_resolution_shard_drain(
			"enqueue_truth_resolution_shards_for_realm"
		)

	return last_truth_resolution_shard_report.duplicate(
		false
	)
func request_truth_resolution_shard_drain(
	reason: String = "truth_resolution_shard_drain_requested"
) -> void:
	if truth_resolution_shard_queue.is_empty():
		truth_resolution_shard_drain_running = false
		return

	if truth_resolution_shard_drain_running:
		return

	if not _truth_resolution_runtime_world_is_active():
		truth_resolution_shard_drain_running = false
		return

	truth_resolution_shard_drain_running = true

	var requested_generation: int = (
		truth_resolution_shard_drain_generation
	)

	if (
		gs != null
		and typeof(gs.scenario_state) == TYPE_DICTIONARY
	):
		gs.scenario_state [
			"truth_resolution_shard_drain_requested"
		] = true
		gs.scenario_state [
			"truth_resolution_shard_drain_reason"
		] = reason
		gs.scenario_state [
			"truth_resolution_shard_drain_generation"
		] = requested_generation
		gs.scenario_state [
			"truth_resolution_shard_drain_requested_at_ms"
		] = int(
			Time.get_ticks_msec()
		)
		gs.scenario_state [
			"truth_resolution_shard_drain_waits_for_rendered_frame"
		] = false
		gs.scenario_state [
			"truth_resolution_shard_drain_timer_owned"
		] = true
		gs.scenario_state [
			"truth_resolution_shard_drain_ready_gate_member"
		] = false

	_schedule_truth_resolution_shard_drain_next_frame(
		requested_generation
	)

func _drain_truth_resolution_shard_queue_deferred(
	requested_generation: int = -1
) -> void:
	if requested_generation < 0:
		requested_generation = (
			truth_resolution_shard_drain_generation
		)

	if (
		truth_resolution_shard_timer_generation
		== requested_generation
	):
		truth_resolution_shard_timer_armed = false
		truth_resolution_shard_timer_generation = -1

	if (
		requested_generation
		!= truth_resolution_shard_drain_generation
	):
		return

	if (
		gs == null
		or not _truth_resolution_runtime_world_is_active()
	):
		truth_resolution_shard_drain_running = false
		return

	if truth_resolution_shard_queue.is_empty():
		truth_resolution_shard_drain_running = false
		return

	var now_ms: int = int(
		Time.get_ticks_msec()
	)

	if now_ms < truth_resolution_shard_next_allowed_ms:
		_schedule_truth_resolution_shard_drain_next_frame(
			requested_generation
		)
		return

	if (
		not "truth_resolution_contract_engine" in gs
		or gs.truth_resolution_contract_engine == null
	):
		gs.truth_resolution_contract_engine = (
			TruthResolutionContractEngine.new(
				gs
			)
		)

	if (
		gs.truth_resolution_contract_engine == null
		or not gs.truth_resolution_contract_engine.has_method(
			"resolve_population_government_truth_shard"
		)
	):
		truth_resolution_shard_drain_running = false
		return

	var shard_raw: Variant = (
		truth_resolution_shard_queue.pop_front()
	)

	if typeof(shard_raw) != TYPE_DICTIONARY:
		_schedule_truth_resolution_shard_drain_next_frame(
			requested_generation
		)
		return

	var shard: Dictionary = (
		shard_raw as Dictionary
	)
	var shard_key: String = str(
		shard.get(
			"shard_key",
			""
		)
	).strip_edges()

	if shard_key != "":
		truth_resolution_shard_queue_keys.erase(
			shard_key
		)

	var shard_generation: int = int(
		shard.get(
			"truth_resolution_drain_generation",
			requested_generation
		)
	)
	var shard_world_epoch: int = int(
		shard.get(
			"world_seed_ui_lens_epoch",
			_truth_resolution_world_epoch()
		)
	)

	if (
		shard_generation
		!= truth_resolution_shard_drain_generation
		or shard_world_epoch
		!= _truth_resolution_world_epoch()
	):
		if truth_resolution_shard_queue.is_empty():
			truth_resolution_shard_drain_running = false
		else:
			_schedule_truth_resolution_shard_drain_next_frame(
				requested_generation
			)

		return

	var realm_id: int = int(
		shard.get(
			"realm_id",
			-1
		)
	)
	var realm_name: String = str(
		shard.get(
			"realm_name",
			""
		)
	)
	var quantum_started_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var shard_result: Dictionary = (
		gs.truth_resolution_contract_engine
		.resolve_population_government_truth_shard(
			realm_id,
			realm_name,
			shard,
			{
				"source": (
					"population_shard_engine_"
					+ "truth_resolution_timer_drain"
				),
				"surface_already_exists": true,
				"ready_door_may_not_wait": true,
				"one_shard_per_timer_quantum": true,
				"process_frame_service_forbidden": true,
				"ui_is_renderer_only": true
			}
		)
	)
	var quantum_finished_at_ms: int = int(
		Time.get_ticks_msec()
	)
	var quantum_elapsed_ms: int = maxi(
		0,
		quantum_finished_at_ms
		- quantum_started_at_ms
	)

	if (
		requested_generation
		!= truth_resolution_shard_drain_generation
		or not _truth_resolution_runtime_world_is_active()
	):
		truth_resolution_shard_drain_running = false
		return

	if gs.event_bus != null:
		gs.event_bus.emit(
			"population.truth.shard_resolved",
			{
				"source": "population_shard_engine",
				"realm_id": realm_id,
				"realm_name": realm_name,
				"shard": shard.duplicate(false),
				"shard_result": shard_result.duplicate(false),
				"one_shard_per_timer_quantum": true,
				"process_frame_service_forbidden": true,
				"ui_is_renderer_only": true
			}
		)

	var adaptive_gap_ms: int = clampi(
		maxi(
			TRUTH_RESOLUTION_SHARD_MIN_GAP_MS,
			quantum_elapsed_ms * 3
		),
		TRUTH_RESOLUTION_SHARD_MIN_GAP_MS,
		320
	)

	truth_resolution_shard_next_allowed_ms = (
		quantum_finished_at_ms
		+ adaptive_gap_ms
	)

	last_truth_resolution_shard_report = {
		"success": true,
		"schema": (
			"eralife.population_shard_engine."
			+ "truth_resolution_drain_report"
		),
		"drained": 1,
		"remaining": truth_resolution_shard_queue.size(),
		"generation": requested_generation,
		"world_seed_ui_lens_epoch": (
			_truth_resolution_world_epoch()
		),
		"one_shard_per_timer_quantum": true,
		"one_shard_per_rendered_frame": false,
		"process_frame_service_forbidden": true,
		"recursive_call_deferred_forbidden": true,
		"minimum_gap_ms": (
			TRUTH_RESOLUTION_SHARD_MIN_GAP_MS
		),
		"adaptive_gap_ms": adaptive_gap_ms,
		"quantum_elapsed_ms": quantum_elapsed_ms,
		"ready_door_may_not_wait": true,
		"ui_is_renderer_only": true,
		"at_ms": quantum_finished_at_ms
	}

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state [
			"population_shard_engine_last_truth_resolution_shard_report"
		] = last_truth_resolution_shard_report.duplicate(
			false
		)

	if truth_resolution_shard_queue.is_empty():
		truth_resolution_shard_drain_running = false
		return

	_schedule_truth_resolution_shard_drain_next_frame(
		requested_generation
	)

func _truth_resolution_shards_for_realm(
		realm_id: int,
		realm_name: String,
		context: Dictionary = {}
) -> Array:
		var out: Array = []
		var is_us: bool = (
			_truth_resolution_surface_is_united_states(
				realm_id,
				realm_name
			)
		)

		if (
			gs == null
			or not "truth_resolution_contract_engine" in gs
			or gs.truth_resolution_contract_engine == null
		):
			if gs != null:
				gs.truth_resolution_contract_engine = (
					TruthResolutionContractEngine.new(
						gs
					)
				)

		if (
			gs != null
			and gs.truth_resolution_contract_engine != null
			and gs.truth_resolution_contract_engine.has_method(
				"emit_population_truth_shard_plan"
			)
		):
			var plan_raw: Variant = (
				gs.truth_resolution_contract_engine
				.emit_population_truth_shard_plan(
					realm_id,
					realm_name,
					context
				)
			)
			var plan: Array = (
				plan_raw as Array
				if typeof(plan_raw) == TYPE_ARRAY
				else []
			)

			for raw_spec in plan:
				if typeof(raw_spec) != TYPE_DICTIONARY:
					continue

				var spec: Dictionary = (
					raw_spec as Dictionary
				)
				var shard_kind: String = str(
					spec.get(
						"shard_kind",
						""
					)
				).strip_edges().to_lower()
				var start_index: int = int(
					spec.get(
						"start_index",
						0
					)
				)
				var count: int = maxi(
					0,
					int(
						spec.get(
							"count",
							0
						)
					)
				)

				if shard_kind == "" or count <= 0:
					continue

				var shard: Dictionary = (
					_truth_resolution_shard_packet(
						realm_id,
						realm_name,
						shard_kind,
						start_index,
						count,
						context
					)
				)

				shard ["section_title"] = str(
					spec.get(
						"section_title",
						""
					)
				)
				shard [
					"government_structure_contract_owned"
				] = true

				out.append(
					shard
				)

		if not out.is_empty():
			return out



		if is_us:
			return []



		for citizen_start in range(
			0,
			60,
			10
		):
			out.append(
				_truth_resolution_shard_packet(
					realm_id,
					realm_name,
					"citizens",
					citizen_start,
					10,
					context
				)
			)

		return out
func _truth_resolution_shard_packet(
	realm_id: int,
	realm_name: String,
	shard_kind: String,
	start_index: int,
	count: int,
	context: Dictionary = {}
) -> Dictionary:
	var clean_kind: String = str(shard_kind).strip_edges().to_lower()
	var shard_key: String = "truth:%d:%s:%d:%d" % [realm_id, clean_kind, start_index, count]

	return {
		"schema": "eralife.population_shard_engine.truth_resolution_shard",
		"version": CONTRACT_VERSION,
		"shard_key": shard_key,
		"realm_id": realm_id,
		"realm_name": realm_name,
		"shard_kind": clean_kind,
		"start_index": start_index,
		"count": count,
		"context": context.duplicate(true),
		"surface_already_exists": true,
		"ready_door_may_not_wait": true,
		"ui_is_renderer_only": true
	}


func _truth_resolution_surface_is_united_states(realm_id: int, realm_name: String) -> bool:
	var key: String = str(realm_name).strip_edges().to_lower()
	var compact: String = key.replace(".", "").replace(" ", "").replace("-", "")

	if compact in ["usa", "us", "unitedstates", "unitedstatesofamerica", "america"]:
		return true

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var us_realm_id: int = int(gs.scenario_state.get("presidential_parent_contract_us_realm_id", -1))
		if us_realm_id > 0 and us_realm_id == realm_id:
			return true

	return false


func _truth_resolution_realm_name_for_id(realm_id: int) -> String:
	if gs != null and gs.realm_engine != null and "realms" in gs.realm_engine and typeof(gs.realm_engine.realms) == TYPE_DICTIONARY:
		var raw: Variant = gs.realm_engine.realms.get(realm_id, {})
		if typeof(raw) == TYPE_DICTIONARY:
			var realm: Dictionary = raw
			var name: String = str(realm.get("name", realm.get("country", ""))).strip_edges()
			if name != "":
				return name

	return "Realm %d" % realm_id