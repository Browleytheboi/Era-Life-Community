extends Resource
class_name SeedEngine

const SEED_CONTRACT_SCHEMA:= "eralife.seed_contract"
const SEED_CONTRACT_VERSION:= 1

const DEFAULT_DOMAIN_OFFSETS:= {
	"core": 0,
	"npc": 1,
	"npc_generation": 1,
	"economy": 2,
	"relationships": 3,
	"events": 4,
	"world": 5,
	"combat": 6,
	"reality_fusion": 7,
	"loot": 8,
	"school": 9,
	"career": 10
}

var gs
var seed_value: int = 0
var rng: RandomNumberGenerator
var rng_domains: Dictionary = {}
var seed_contract: Dictionary = {}
var last_seed_report: Dictionary = {}
var seed_materialized: bool = false
var seed_materialization_deferred: bool = false

func _init(_gs = null):
	gs = _gs
	rng = RandomNumberGenerator.new()
	seed_contract = _default_seed_contract()
func _seed_materialization_allowed(context: Dictionary = {}) -> bool:
	if bool(context.get("force_materialize", false)):
		return true
	if gs == null:
		return false

	if typeof(gs.scenario_state) == TYPE_DICTIONARY:


		if bool(gs.scenario_state.get("god_mode_candidate_seed_only", false)):
			return false

		if bool(gs.scenario_state.get("god_mode_life_prewarm_active", false)):
			return true
		if bool(gs.scenario_state.get("birth_shell_first_boot", false)):
			return true
		if bool(gs.scenario_state.get("materialize_world_seed_on_initialize", false)):
			return true
		if bool(gs.scenario_state.get("parallel_universe_entry", false)):
			return true

	if "awaiting_new_life" in gs and bool(gs.awaiting_new_life):
		return true

	return false



func initialize(seed_input: Variant = -1) -> Dictionary:
	if typeof(seed_input) == TYPE_DICTIONARY:
		return initialize_from_contract(
			seed_input as Dictionary
		)

	var resolved_seed: int = -1

	match typeof(seed_input):
		TYPE_NIL:
			resolved_seed = -1

		TYPE_INT, TYPE_FLOAT:
			resolved_seed = int(
				seed_input
			)

		TYPE_STRING:
			var text_value: String = str(
				seed_input
			).strip_edges()

			if text_value == "":
				resolved_seed = -1
			elif text_value.is_valid_int():
				resolved_seed = int(
					text_value
				)
			else:
				resolved_seed = derive_seed_from_text(
					text_value
				)

		_:
			resolved_seed = -1

	if (
		resolved_seed == -1
		and gs != null
	):
		if (
			"custom_settings" in gs
			and typeof(
				gs.custom_settings
			) == TYPE_DICTIONARY
		):
			var settings_seed_contract_raw: Variant = (
				gs.custom_settings.get(
					"seed_contract",
					{}
				)
			)

			if typeof(
				settings_seed_contract_raw
			) == TYPE_DICTIONARY:
				resolved_seed = int(
					(
						settings_seed_contract_raw
						as Dictionary
					).get(
						"seed",
						-1
					)
				)

			if resolved_seed <= 0:
				resolved_seed = int(
					gs.custom_settings.get(
						"world_seed",
						-1
					)
				)

	if (
		resolved_seed == -1
		and gs != null
	):
		if (
			"scenario_state" in gs
			and typeof(
				gs.scenario_state
			) == TYPE_DICTIONARY
		):
			var state_seed_contract_raw: Variant = (
				gs.scenario_state.get(
					"seed_contract",
					{}
				)
			)

			if typeof(
				state_seed_contract_raw
			) == TYPE_DICTIONARY:
				resolved_seed = int(
					(
						state_seed_contract_raw
						as Dictionary
					).get(
						"seed",
						-1
					)
				)

			if resolved_seed <= 0:
				resolved_seed = int(
					gs.scenario_state.get(
						"world_seed",
						-1
					)
				)

	var persistent_residency_host: bool = false

	if (
		gs != null
		and typeof(
			gs.scenario_state
		) == TYPE_DICTIONARY
	):
		persistent_residency_host = (
			str(
				gs.scenario_state.get(
					"reality_residency_intent_gateway_scope",
					""
				)
			).strip_edges().to_lower()
			== "persistent_residency_host"
		)




	if (
		resolved_seed <= 0
		and persistent_residency_host
	):
		last_seed_report = {
			"schema": "eralife.seed_report",
			"version": SEED_CONTRACT_VERSION,
			"success": true,
			"initialized": false,
			"deferred": true,
			"seed": 0,
			"reason": (
				"waiting_for_canonical_resident_seed"
			),
			"created_at_ms": int(
				Time.get_ticks_msec()
			)
		}

		gs.scenario_state [
			"seed_bootstrap_deferred"
		] = true
		gs.scenario_state [
			"seed_bootstrap_reason"
		] = "waiting_for_canonical_resident_seed"
		gs.scenario_state [
			"persistent_host_disposable_seed_forbidden"
		] = true
		gs.scenario_state [
			"persistent_host_world_seed_printed"
		] = false

		return last_seed_report.duplicate(false)

	if (
		resolved_seed > 0
		and seed_value == resolved_seed
		and not last_seed_report.is_empty()
	):
		var existing_report: Dictionary = (
			last_seed_report.duplicate(false)
		)

		existing_report [
			"idempotent_seed_claim"
		] = true
		existing_report [
			"world_seed_reprinted"
		] = false

		return existing_report

	if resolved_seed == -1:
		resolved_seed = randi()

	var contract: Dictionary = (
		_default_seed_contract()
	)

	contract ["seed"] = resolved_seed

	return initialize_from_contract(
		contract
	)
func initialize_from_contract(contract: Dictionary = {}) -> Dictionary:
	var resolved: Dictionary = _resolve_seed_contract(contract)
	var requested_seed: int = int(resolved.get("seed", -1))
	var allowed_to_materialize: bool = requested_seed > 0 or _seed_materialization_allowed(resolved)

	if requested_seed <= 0 and not allowed_to_materialize:
		seed_materialization_deferred = true
		seed_materialized = false
		seed_contract = resolved.duplicate(true)
		last_seed_report = {
			"schema": "eralife.seed_report",
			"version": SEED_CONTRACT_VERSION,
			"success": true,
			"mode": "deferred",
			"seed": -1,
			"reason": "seed_contract_waiting_for_creation_authority",
			"created_at_ms": int(Time.get_ticks_msec())
		}
		return last_seed_report.duplicate(true)

	if requested_seed <= 0:
		requested_seed = randi()

	if seed_materialized and seed_value == requested_seed:
		seed_contract = resolved.duplicate(true)
		seed_contract ["seed"] = seed_value
		last_seed_report = {
			"schema": "eralife.seed_report",
			"version": SEED_CONTRACT_VERSION,
			"success": true,
			"mode": "already_materialized",
			"seed": seed_value,
			"domain_count": rng_domains.size(),
			"domains": rng_domains.keys(),
			"created_at_ms": int(Time.get_ticks_msec())
		}
		_store_seed_contract_to_game_state()
		return last_seed_report.duplicate(true)

	seed_value = requested_seed
	seed_contract = resolved.duplicate(true)
	seed_contract ["seed"] = seed_value
	rng.seed = seed_value
	_rebuild_domain_rngs()
	seed_materialized = true
	seed_materialization_deferred = false
	last_seed_report = {
		"schema": "eralife.seed_report",
		"version": SEED_CONTRACT_VERSION,
		"success": true,
		"mode": "materialized",
		"seed": seed_value,
		"domain_count": rng_domains.size(),
		"domains": rng_domains.keys(),
		"created_at_ms": int(Time.get_ticks_msec())
	}
	_store_seed_contract_to_game_state()

	var source_text: String = str(resolved.get("source", "")).strip_edges().to_lower()
	var suppress_seed_output: bool = bool(resolved.get("suppress_seed_output", false))
	if source_text.find("prewarm") >= 0:
		suppress_seed_output = true

	if not suppress_seed_output:
		EraLog.truth("World Seed:", seed_value)

	return last_seed_report.duplicate(true)
func export_state() -> Dictionary:
	var out: Dictionary = seed_contract.duplicate(true)
	out ["schema"] = SEED_CONTRACT_SCHEMA
	out ["version"] = SEED_CONTRACT_VERSION
	out ["seed"] = seed_value
	out ["domain_names"] = rng_domains.keys()
	out ["last_seed_report"] = last_seed_report.duplicate(true)
	return _make_binary_safe(out)

func import_state(state: Dictionary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "SeedEngine import_state expected a Dictionary."
		}

	return initialize_from_contract(state)

func enter_parallel_universe(contract: Dictionary = {}, context: Dictionary = {}) -> Dictionary:
	var resolved: Dictionary = _resolve_seed_contract(contract)

	if not resolved.has("seed") or int(resolved.get("seed", -1)) == -1:
		var source_path: String = str(context.get("path", context.get("source_path", ""))).strip_edges()
		var source_label: String = str(context.get("label", context.get("source_label", "parallel_universe"))).strip_edges()
		resolved ["seed"] = derive_seed_from_text("%s|%s|%d" % [
			source_path,
			source_label,
			int(Time.get_unix_time_from_system())
		])

	var report: Dictionary = initialize_from_contract(resolved)
	report ["parallel_universe_entry"] = true
	report ["context"] = _make_binary_safe(context)

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["last_parallel_universe_seed_report"] = report.duplicate(true)

	return report




func rand_int(minv: int, maxv: int) -> int:
	var low: int = min(minv, maxv)
	var high: int = max(minv, maxv)
	return rng.randi_range(low, high)

func rand_float() -> float:
	return rng.randf()

func rand_index(arr: Array) -> int:
	if arr.is_empty():
		return 0
	return rng.randi_range(0, arr.size() - 1)

func shuffle(arr: Array):
	shuffle_domain("core", arr)

func rand_int_domain(domain: String, minv: int, maxv: int) -> int:
	var domain_rng: RandomNumberGenerator = _rng_for_domain(domain)
	var low: int = min(minv, maxv)
	var high: int = max(minv, maxv)
	return domain_rng.randi_range(low, high)

func rand_float_domain(domain: String) -> float:
	return _rng_for_domain(domain).randf()

func rand_index_domain(domain: String, arr: Array) -> int:
	if arr.is_empty():
		return 0
	return rand_int_domain(domain, 0, arr.size() - 1)

func shuffle_domain(domain: String, arr: Array) -> void:
	if arr.size() <= 1:
		return

	for i in range(arr.size() - 1, 0, -1):
		var j: int = rand_int_domain(domain, 0, i)
		var temp: Variant = arr [i]
		arr [i] = arr [j]
		arr [j] = temp

func derive_seed_from_text(text: String) -> int:
	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		clean_text = "eralife.seed"
	return abs(int(hash(clean_text)))

func domain_seed(domain: String) -> int:
	var clean_domain: String = str(domain).strip_edges().to_lower()
	if clean_domain == "":
		clean_domain = "core"

	var domain_contract: Dictionary = _domain_contract(clean_domain)
	var offset: int = int(domain_contract.get("offset", DEFAULT_DOMAIN_OFFSETS.get(clean_domain, 1000 + abs(int(hash(clean_domain))) % 100000)))
	var salt: String = str(domain_contract.get("salt", clean_domain))
	var spread: int = abs(int(hash("%s|%s|%s" % [seed_value, clean_domain, salt]))) % 999983
	return int(seed_value) + offset + spread

func world_rule(name: String, fallback: Variant = null) -> Variant:
	var rules: Dictionary = _safe_dictionary(seed_contract.get("world_rules", {}))
	return rules.get(name, fallback)

func domain_rule(domain: String, name: String, fallback: Variant = null) -> Variant:
	var domain_contract: Dictionary = _domain_contract(domain)
	return domain_contract.get(name, fallback)




func _rebuild_domain_rngs() -> void:
	rng_domains.clear()

	var domains: Dictionary = _safe_dictionary(seed_contract.get("random_domains", {}))

	for raw_domain in DEFAULT_DOMAIN_OFFSETS.keys():
		var domain_name: String = str(raw_domain).strip_edges().to_lower()
		rng_domains [domain_name] = _build_domain_rng(domain_name)

	for raw_domain in domains.keys():
		var domain_name: String = str(raw_domain).strip_edges().to_lower()
		if domain_name == "":
			continue
		if not rng_domains.has(domain_name):
			rng_domains [domain_name] = _build_domain_rng(domain_name)

func _build_domain_rng(domain: String) -> RandomNumberGenerator:
	var domain_rng:= RandomNumberGenerator.new()
	domain_rng.seed = domain_seed(domain)
	return domain_rng

func _rng_for_domain(domain: String) -> RandomNumberGenerator:
	var clean_domain: String = str(domain).strip_edges().to_lower()
	if clean_domain == "":
		clean_domain = "core"

	if not rng_domains.has(clean_domain):
		rng_domains [clean_domain] = _build_domain_rng(clean_domain)

	return rng_domains [clean_domain]

func _domain_contract(domain: String) -> Dictionary:
	var clean_domain: String = str(domain).strip_edges().to_lower()
	if clean_domain == "":
		clean_domain = "core"

	var domains: Dictionary = _safe_dictionary(seed_contract.get("random_domains", {}))
	var raw: Variant = domains.get(clean_domain, {})
	if typeof(raw) == TYPE_DICTIONARY:
		return (raw as Dictionary).duplicate(true)

	return {}

func _default_seed_contract() -> Dictionary:
	return {
		"schema": SEED_CONTRACT_SCHEMA,
		"version": SEED_CONTRACT_VERSION,
		"seed": -1,
		"random_domains": {
			"core": {
				"offset": 0,
				"distribution": "uniform"
			},
			"npc_generation": {
				"offset": 1,
				"bias": "neutral",
				"distribution": "uniform"
			},
			"relationships": {
				"offset": 3,
				"volatility": 0.35,
				"rare_events_multiplier": 1.0
			},
			"economy": {
				"offset": 2,
				"inflation_curve": "steady",
				"market_noise": 0.2
			},
			"events": {
				"offset": 4,
				"rare_events_multiplier": 1.0
			},
			"reality_fusion": {
				"offset": 7,
				"distribution": "breach_weighted",
			}
		},
		"world_rules": {
			"luck_modifier": 1.0,
			"death_curve": "standard",
			"success_bias": "balanced"
		}
	}

func _resolve_seed_contract(contract: Dictionary) -> Dictionary:
	var out: Dictionary = _default_seed_contract()

	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		out = _merge_dict(out, contract)

	out ["schema"] = SEED_CONTRACT_SCHEMA
	out ["version"] = SEED_CONTRACT_VERSION
	return _make_binary_safe(out)

func _store_seed_contract_to_game_state() -> void:
	if gs == null:
		return

	if typeof(gs.scenario_state) != TYPE_DICTIONARY:
		gs.scenario_state = {}

	gs.scenario_state ["seed_contract"] = export_state()
	gs.scenario_state ["world_seed"] = seed_value

func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)

	for key in patch.keys():
		var patch_value: Variant = patch.get(key)
		if typeof(patch_value) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(out.get(key, {}), patch_value)
		else:
			out [key] = patch_value

	return out

func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out:= {}
			for key in value.keys():
				out [str(key)] = _make_binary_safe(value [key])
			return out
		TYPE_ARRAY:
			var arr:= []
			for item in value:
				arr.append(_make_binary_safe(item))
			return arr
		TYPE_COLOR:
			var c: Color = value
			return "#%s" % c.to_html(true)
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			return str(value)