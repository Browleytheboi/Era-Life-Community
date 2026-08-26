extends Resource
class_name FoodEngine

const FOOD_SCHEMA:= "eralife.food_engine"
const FOOD_VERSION:= 1

const DEFAULT_MAX_HUNGER:= 100.0
const DEFAULT_STARTING_HUNGER:= 72.0
const STARVATION_THRESHOLD:= 18.0
const MALNUTRITION_THRESHOLD:= 35.0

var gs
var hunger_by_actor_id: Dictionary = {}







var hunger_state_mutex: Mutex = Mutex.new()

var nutrition_profiles: Dictionary = {}
var pantry_by_owner_id: Dictionary = {}
var food_ledger: Array = []
var last_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs
func seed_initial_hunger_for_population(people: Array, context: Dictionary = {}) -> Dictionary:
	var seeded: int = 0
	var skipped: int = 0
	var force: bool = bool(context.get("force", false))

	for raw_person in people:
		if raw_person == null or not (raw_person is Person):
			continue

		var person: Person = raw_person as Person
		var report: Dictionary = _seed_initial_hunger_profile_for_actor(person, force)
		if bool(report.get("seeded", false)):
			seeded += 1
		else:
			skipped += 1

	return {
		"success": true,
		"seeded": seeded,
		"skipped": skipped,
		"source": str(context.get("source", "seed_initial_hunger_for_population"))
	}

func _seed_initial_hunger_profile_for_actor(
	actor: Person,
	force: bool = false
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"seeded": false,
			"reason": "No actor supplied."
		}

	var actor_id: int = int(
		actor.id
	)

	if hunger_by_actor_id.has(actor_id) and not force:
		var existing_profile: Dictionary = (
			hunger_by_actor_id.get(
				actor_id,
				{}
			).duplicate(true)
		)

		if not _should_reseed_flat_default_hunger_profile(
			actor,
			existing_profile
		):
			return {
				"success": true,
				"seeded": false,
				"profile": existing_profile.duplicate(true)
			}

	var initial_hunger: float = _initial_hunger_for_actor(
		actor
	)
	var profile: Dictionary = {
		"actor_id": actor_id,
		"hunger": initial_hunger,
		"initial_hunger": initial_hunger,
		"initial_hunger_model": _initial_hunger_model_for_actor(
			actor
		),
		"seed_model": "class_income_food_security_v1",
		"last_quality": "initial",
		"last_food_id": "",
		"malnutrition_years": 0,
		"starvation_years": 0,
		"last_fed_year": (
			int(gs.year)
			if gs != null
			else 0
		),
		"updated_at_ms": int(
			Time.get_ticks_msec()
		)
	}

	_store_hunger_profile(
		actor_id,
		profile
	)

	nutrition_profiles [
		actor_id
	] = _build_initial_nutrition_profile(
		actor,
		profile
	)

	_sync_person_hunger(
		actor
	)

	return {
		"success": true,
		"seeded": true,
		"profile": profile.duplicate(true)
	}

func _should_reseed_flat_default_hunger_profile(actor: Person, profile: Dictionary) -> bool:
	if actor == null:
		return false
	if typeof(profile) != TYPE_DICTIONARY:
		return true

	if str(profile.get("seed_model", "")).strip_edges() != "":
		return false

	var current_hunger: float = float(profile.get("hunger", DEFAULT_STARTING_HUNGER))
	var last_food_id: String = str(profile.get("last_food_id", "")).strip_edges()
	var last_quality: String = str(profile.get("last_quality", "unknown")).strip_edges().to_lower()

	if abs(current_hunger - DEFAULT_STARTING_HUNGER) > 0.01:
		return false
	if last_food_id != "":
		return false
	if last_quality != "unknown" and last_quality != "":
		return false

	return true

func _build_initial_nutrition_profile(actor: Person, hunger_profile: Dictionary = {}) -> Dictionary:
	var actor_id: int = int(actor.id) if actor != null else -1
	var hunger_value: float = float(hunger_profile.get("hunger", DEFAULT_STARTING_HUNGER))
	var food_security: float = 0.0

	if actor != null:
		food_security = _food_security_score_for_actor(actor)

	var nutrition_value: float = clamp(58.0 + food_security + _stable_food_jitter(actor, "nutrition", -8.0, 8.0), 18.0, 96.0)
	if hunger_value <= MALNUTRITION_THRESHOLD:
		nutrition_value = clamp(nutrition_value - 12.0, 8.0, 96.0)

	return {
		"actor_id": actor_id,
		"nutrition": nutrition_value,
		"protein": clamp(48.0 + food_security * 0.35 + _stable_food_jitter(actor, "protein", -7.0, 7.0), 10.0, 100.0),
		"vitamins": clamp(48.0 + food_security * 0.3 + _stable_food_jitter(actor, "vitamins", -7.0, 7.0), 10.0, 100.0),
		"sugar_pressure": clamp(18.0 - food_security * 0.1 + _stable_food_jitter(actor, "sugar", -4.0, 8.0), 0.0, 100.0),
		"sodium_pressure": clamp(20.0 - food_security * 0.06 + _stable_food_jitter(actor, "sodium", -4.0, 10.0), 0.0, 100.0),
		"diet_quality": _diet_quality_from_food_security(food_security),
		"restricted_diet_flags": []
	}

func _initial_hunger_for_actor(actor: Person) -> float:
	if actor == null:
		return DEFAULT_STARTING_HUNGER

	var explicit_hunger: float = -1.0
	if actor.get("hunger") != null:
		explicit_hunger = float(actor.get("hunger"))

	if explicit_hunger >= 0.0 and abs(explicit_hunger - DEFAULT_STARTING_HUNGER) > 0.01:
		return clamp(explicit_hunger, 0.0, DEFAULT_MAX_HUNGER)

	var food_security: float = _food_security_score_for_actor(actor)
	var base: float = 66.0 + food_security

	if int(actor.age) <= 2:
		base += 8.0
	elif int(actor.age) <= 12:
		base += 2.0
	elif int(actor.age) >= 70:
		base -= 3.0

	var jitter: float = _stable_food_jitter(actor, "initial_hunger", -14.0, 14.0)
	var outlier_roll: float = _stable_food_roll(actor, "initial_hunger_outlier")
	var outlier_adjustment: float = 0.0

	if outlier_roll <= 0.08:
		outlier_adjustment -= abs(_stable_food_jitter(actor, "hardship_outlier", 10.0, 26.0))
	elif outlier_roll >= 0.94:
		outlier_adjustment += abs(_stable_food_jitter(actor, "lucky_outlier", 8.0, 18.0))

	return clamp(base + jitter + outlier_adjustment, 4.0, DEFAULT_MAX_HUNGER)

func _initial_hunger_model_for_actor(actor: Person) -> Dictionary:
	return {
		"schema": "eralife.initial_hunger_model",
		"version": 1,
		"actor_id": int(actor.id) if actor != null else -1,
		"social_class": str(actor.social_class) if actor != null else "",
		"income": float(actor.income) if actor != null else 0.0,
		"bank_balance": float(actor.bank_balance) if actor != null else 0.0,
		"food_security_score": _food_security_score_for_actor(actor) if actor != null else 0.0
	}

func _food_security_score_for_actor(actor: Person) -> float:
	if actor == null:
		return 0.0

	var subject: Person = actor
	if int(actor.age) <= 15:
		var provider: Person = _food_security_provider_for_child(actor)
		if provider != null:
			subject = provider

	var score: float = 0.0
	score += _class_food_security_modifier(str(subject.social_class))
	score += _income_food_security_modifier(float(subject.income))
	score += _bank_food_security_modifier(float(subject.bank_balance))

	if _actor_has_trait_prefix(subject, "InPrison_"):
		score -= 10.0

	return clamp(score, -34.0, 28.0)

func _food_security_provider_for_child(child: Person) -> Person:
	if child == null or gs == null:
		return null

	var best_parent: Person = null
	var best_score: float = -9999.0

	for raw_parent_id in child.parents:
		var parent: Person = null
		var parent_id: int = int(raw_parent_id)

		if gs.has_method("get_or_reactivate_npc_by_id"):
			parent = gs.get_or_reactivate_npc_by_id(parent_id)
		elif gs.has_method("get_npc_by_id"):
			parent = gs.get_npc_by_id(parent_id)

		if parent == null or not parent.alive:
			continue

		var parent_score: float = _class_food_security_modifier(str(parent.social_class))
		parent_score += _income_food_security_modifier(float(parent.income))
		parent_score += _bank_food_security_modifier(float(parent.bank_balance))

		if parent_score > best_score:
			best_score = parent_score
			best_parent = parent

	return best_parent

func _class_food_security_modifier(class_key: String) -> float:
	var clean: String = str(class_key).strip_edges().to_lower()

	if clean.find("slave") != -1 or clean.find("enslaved") != -1:
		return -26.0
	if clean.find("peasant") != -1 or clean.find("poor") != -1 or clean.find("impoverished") != -1:
		return -22.0
	if clean.find("lower") != -1:
		return -17.0
	if clean.find("working") != -1:
		return -10.0
	if clean.find("common") != -1:
		return -4.0
	if clean.find("merchant") != -1 or clean.find("middle") != -1:
		return 5.0
	if clean.find("upper") != -1 or clean.find("wealth") != -1:
		return 10.0
	if clean.find("noble") != -1:
		return 14.0
	if clean.find("royal") != -1:
		return 18.0

	return 0.0

func _income_food_security_modifier(income_value: float) -> float:
	var income_amount: float = max(0.0, float(income_value))

	if income_amount <= 0.0:
		return -8.0
	if income_amount < 12000.0:
		return -14.0
	if income_amount < 30000.0:
		return -7.0
	if income_amount < 70000.0:
		return 2.0
	if income_amount < 150000.0:
		return 8.0

	return 14.0

func _bank_food_security_modifier(bank_value: float) -> float:
	var cash: float = float(bank_value)

	if cash < 50.0:
		return -8.0
	if cash < 500.0:
		return -5.0
	if cash < 2500.0:
		return -2.0
	if cash > 250000.0:
		return 10.0
	if cash > 50000.0:
		return 6.0

	return 0.0

func _diet_quality_from_food_security(food_security: float) -> String:
	if food_security <= -18.0:
		return "scarce"
	if food_security <= -8.0:
		return "cheap"
	if food_security >= 18.0:
		return "premium"
	if food_security >= 8.0:
		return "stable"
	return "mixed"

func _stable_food_roll(actor: Person, salt: String) -> float:
	if actor == null:
		return randf()

	var material: String = "%s|%s|%s|%s|%s" % [
		str(int(actor.id)),
		str(actor.first_name),
		str(actor.last_name),
		str(actor.age),
		str(salt)
	]
	var seed_value: int = int(hash(material))
	if seed_value < 0:
		seed_value = - seed_value
	if seed_value <= 0:
		seed_value = 1

	var rng:= RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randf()

func _stable_food_jitter(actor: Person, salt: String, low: float, high: float) -> float:
	if actor == null:
		return randf_range(low, high)

	var material: String = "%s|%s|%s|%s|%s" % [
		str(int(actor.id)),
		str(actor.first_name),
		str(actor.last_name),
		str(actor.age),
		str(salt)
	]
	var seed_value: int = int(hash(material))
	if seed_value < 0:
		seed_value = - seed_value
	if seed_value <= 0:
		seed_value = 1

	var rng:= RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng.randf_range(low, high)
func ensure_actor_food_profile(actor: Person) -> Dictionary:
	if actor == null:
		return {}

	var actor_id: int = int(actor.id)

	if not hunger_by_actor_id.has(actor_id):
		_seed_initial_hunger_profile_for_actor(actor, true)
	else:
		var existing_profile: Dictionary = hunger_by_actor_id.get(actor_id, {}).duplicate(true)
		if _should_reseed_flat_default_hunger_profile(actor, existing_profile):
			_seed_initial_hunger_profile_for_actor(actor, true)

	if not nutrition_profiles.has(actor_id):
		var profile: Dictionary = hunger_by_actor_id.get(actor_id, {}).duplicate(true)
		nutrition_profiles [actor_id] = _build_initial_nutrition_profile(actor, profile)

	_sync_person_hunger(actor)
	return hunger_by_actor_id [actor_id].duplicate(true)

func yearly_tick(
	_payload: Dictionary = {}
) -> Dictionary:
	if gs == null:
		return {
			"success": false,
			"reason": "GameState unavailable."
		}

	var runtime_managed_age_up: bool = (
		bool(
			_payload.get(
				"runtime_managed",
				false
			)
		)
		and str(
			_payload.get(
				"runtime_owner",
				""
			)
		).strip_edges().to_lower()
		== "age_up_runtime"
	)

	if runtime_managed_age_up:
		var target_year: int = int(
			_payload.get(
				"year",
				gs.year
			)
		)

		if int(
			get_meta(
				"food_yearly_runtime_completed_year",
				-999999
			)
		) == target_year:
			return {
				"schema": "eralife.food_yearly_tick_report",
				"version": FOOD_VERSION,
				"success": true,
				"is_complete": true,
				"already_applied": true,
				"year": target_year,
				"bounded_runtime": true
			}

		var state_raw: Variant = get_meta(
			"food_yearly_runtime_state",
			{}
		)

		var state: Dictionary = (
			state_raw as Dictionary
			if typeof(
				state_raw
			) == TYPE_DICTIONARY
			else {}
		)

		if (
			state.is_empty()
			or int(
				state.get(
					"year",
					-999999
				)
			) != target_year
		):
			state = {
				"year": target_year,
				"cursor": 0,
				"affected_count": 0,
				"processed_count": 0,
				"started_at_ms": int(
					Time.get_ticks_msec()
				)
			}

			set_meta(
				"food_yearly_runtime_state",
				state
			)

		_arm_food_yearly_runtime_service()

		return {
			"schema": "eralife.food_yearly_tick_report",
			"version": FOOD_VERSION,
			"success": true,
			"is_complete": false,
			"queued": true,
			"year": target_year,
			"bounded_runtime": true,
			"background_only": true,
			"blocks_ui": false,
			"idle_required": false
		}

	var affected: Array = []

	for actor in gs.npcs:
		if (
			actor == null
			or not actor.alive
		):
			continue

		var report: Dictionary = (
			yearly_tick_actor(
				actor
			)
		)

		if bool(
			report.get(
				"changed",
				false
			)
		):
			affected.append(
				report
			)

	last_report = {
		"schema": "eralife.food_yearly_tick_report",
		"version": FOOD_VERSION,
		"success": true,
		"affected_count": affected.size(),
		"affected": affected,
		"year": int(
			gs.year
		),
		"at_ms": int(
			Time.get_ticks_msec()
		)
	}

	return last_report.duplicate(true)
func _arm_food_yearly_runtime_service() -> void:
	var state_raw: Variant = get_meta(
		"food_yearly_runtime_state",
		{}
	)

	if (
		typeof(
			state_raw
		) != TYPE_DICTIONARY
		or (
			state_raw as Dictionary
		).is_empty()
	):
		return

	if bool(
		get_meta(
			"food_yearly_runtime_service_armed",
			false
		)
	):
		return

	var tree:= Engine.get_main_loop() as SceneTree

	if tree == null:
		return

	set_meta(
		"food_yearly_runtime_service_armed",
		true
	)

	var error: int = tree.process_frame.connect(
		Callable(
			self,
			"_service_food_yearly_runtime_quantum"
		),
		CONNECT_ONE_SHOT
	)

	if error != OK:
		set_meta(
			"food_yearly_runtime_service_armed",
			false
		)


func _service_food_yearly_runtime_quantum() -> void:
	set_meta(
		"food_yearly_runtime_service_armed",
		false
	)

	if gs == null:
		return

	var state_raw: Variant = get_meta(
		"food_yearly_runtime_state",
		{}
	)

	var state: Dictionary = (
		state_raw as Dictionary
		if typeof(
			state_raw
		) == TYPE_DICTIONARY
		else {}
	)

	if state.is_empty():
		return

	var target_year: int = int(
		state.get(
			"year",
			gs.year
		)
	)

	var cursor: int = clampi(
		int(
			state.get(
				"cursor",
				0
			)
		),
		0,
		gs.npcs.size()
	)

	var affected_count: int = int(
		state.get(
			"affected_count",
			0
		)
	)

	var processed_count: int = int(
		state.get(
			"processed_count",
			0
		)
	)

	var quantum_started_ms: int = int(
		Time.get_ticks_msec()
	)

	var processed_this_quantum: int = 0

	while (
		cursor < gs.npcs.size()
		and processed_this_quantum < 12
	):
		if (
			processed_this_quantum > 0
			and int(
				Time.get_ticks_msec()
			) - quantum_started_ms >= 1
		):
			break

		var actor: Person = (
			gs.npcs [
				cursor
			] as Person
		)

		cursor += 1
		processed_this_quantum += 1
		processed_count += 1

		if (
			actor == null
			or not actor.alive
		):
			continue

		if int(
			actor.get_meta(
				"last_food_yearly_runtime_year",
				-999999
			)
		) == target_year:
			continue

		var actor_report: Dictionary = (
			yearly_tick_actor(
				actor
			)
		)

		actor.set_meta(
			"last_food_yearly_runtime_year",
			target_year
		)

		if bool(
			actor_report.get(
				"changed",
				false
			)
		):
			affected_count += 1

	state [
		"cursor"
	] = cursor

	state [
		"affected_count"
	] = affected_count

	state [
		"processed_count"
	] = processed_count

	if cursor >= gs.npcs.size():
		last_report = {
			"schema": "eralife.food_yearly_tick_report",
			"version": FOOD_VERSION,
			"success": true,
			"affected_count": affected_count,
			"affected": [],
			"processed_count": processed_count,
			"year": target_year,
			"bounded_runtime": true,
			"is_complete": true,
			"at_ms": int(
				Time.get_ticks_msec()
			)
		}

		set_meta(
			"food_yearly_runtime_completed_year",
			target_year
		)

		set_meta(
			"food_yearly_runtime_state",
			{}
		)

		return

	set_meta(
		"food_yearly_runtime_state",
		state
	)

	_arm_food_yearly_runtime_service()
func yearly_tick_actor(actor: Person) -> Dictionary:
	if actor == null or not actor.alive:
		return {
			"success": false,
			"changed": false
		}

	ensure_actor_food_profile(actor)

	var actor_id: int = int(actor.id)
	var profile: Dictionary = (
		hunger_by_actor_id.get(
			actor_id,
			{}
		).duplicate(true)
	)
	var nutrition: Dictionary = (
		nutrition_profiles.get(
			actor_id,
			{}
		).duplicate(true)
	)
	var hunger_loss: float = _yearly_hunger_gain(actor)
	var parent_feed_report: Dictionary = {}

	if int(actor.age) <= 15:
		parent_feed_report = feed_child_from_family(actor)
		profile = hunger_by_actor_id.get(
			actor_id,
			{}
		).duplicate(true)
	else:
		profile ["hunger"] = clamp(
			float(
				profile.get(
					"hunger",
					DEFAULT_STARTING_HUNGER
				)
			) - hunger_loss,
			0.0,
			DEFAULT_MAX_HUNGER
		)

	var hunger: float = float(
		profile.get(
			"hunger",
			0.0
		)
	)
	var health_delta: float = 0.0
	var text: String = ""

	if hunger <= STARVATION_THRESHOLD:
		profile ["starvation_years"] = int(
			profile.get(
				"starvation_years",
				0
			)
		) + 1
		health_delta -= 18.0
		text = "I was starving. My body started breaking down."
	elif hunger <= MALNUTRITION_THRESHOLD:
		profile ["malnutrition_years"] = int(
			profile.get(
				"malnutrition_years",
				0
			)
		) + 1
		health_delta -= 6.0
		text = "I did not get enough food this year."
	else:
		profile ["starvation_years"] = 0
		profile ["malnutrition_years"] = 0

		if float(
			nutrition.get(
				"nutrition",
				70.0
			)
		) >= 75.0:
			health_delta += 1.0

	if health_delta != 0.0:
		_apply_health_pressure(
			actor,
			health_delta,
			{
				"source": "food_engine",
				"hunger": hunger,
				"nutrition": nutrition.duplicate(true)
			}
		)

	if (
		hunger <= 1.0
		and gs != null
		and gs.health_engine != null
		and gs.health_engine.has_method(
			"try_kill"
		)
	):
		gs.health_engine.try_kill(
			actor,
			"Starvation"
		)

	_store_hunger_profile(
		actor_id,
		profile
	)

	_sync_person_hunger(
		actor
	)

	var report:= {
		"success": true,
		"changed": true,
		"actor_id": actor_id,
		"hunger": hunger,
		"health_delta": health_delta,
		"parent_feed_report": parent_feed_report.duplicate(true),
		"text": text
	}

	if text != "":
		_record_food_event(
			"food_health_pressure",
			actor,
			report
		)

	return report
func apply_sustenance_to_actor(
	actor: Person,
	amount: float,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "No actor supplied."
		}

	ensure_actor_food_profile(actor)

	var actor_id: int = int(actor.id)
	var profile: Dictionary = hunger_by_actor_id.get(
		actor_id,
		{}
	).duplicate(true)
	var before_hunger: float = clamp(
		float(
			profile.get(
				"hunger",
				actor.hunger
				if actor.get("hunger") != null
				else DEFAULT_STARTING_HUNGER
			)
		),
		0.0,
		DEFAULT_MAX_HUNGER
	)
	var clean_amount: float = max(
		0.0,
		float(amount)
	)
	var after_hunger: float = clamp(
		before_hunger + clean_amount,
		0.0,
		DEFAULT_MAX_HUNGER
	)

	profile ["hunger"] = after_hunger
	profile ["last_quality"] = str(
		context.get(
			"quality",
			profile.get(
				"last_quality",
				"sustenance"
			)
		)
	)
	profile ["last_food_id"] = str(
		context.get(
			"food_id",
			profile.get(
				"last_food_id",
				"sustenance"
			)
		)
	)
	profile ["last_fed_year"] = (
		int(gs.year)
		if gs != null
		else int(
			profile.get(
				"last_fed_year",
				0
			)
		)
	)
	profile ["updated_at_ms"] = int(
		Time.get_ticks_msec()
	)

	_store_hunger_profile(
		actor_id,
		profile
	)

	_sync_person_hunger(actor)

	return {
		"success": true,
		"actor_id": actor_id,
		"hunger_before": before_hunger,
		"hunger_after": after_hunger,
		"hunger_delta": after_hunger - before_hunger,
		"hunger": after_hunger,
		"amount_requested": clean_amount,
		"source": str(
			context.get(
				"source",
				"sustenance"
			)
		),
		"profile": profile.duplicate(true)
	}
func consume_food(actor: Person, food_item: Dictionary, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}
	if typeof(food_item) != TYPE_DICTIONARY:
		return { "success": false, "reason": "Food item must be a Dictionary."}

	ensure_actor_food_profile(actor)

	var actor_id: int = int(actor.id)
	var profile: Dictionary = hunger_by_actor_id.get(actor_id, {}).duplicate(true)
	var nutrition: Dictionary = nutrition_profiles.get(actor_id, {}).duplicate(true)
	var food_id: String = str(food_item.get("id", food_item.get("food_id", "food"))).strip_edges()
	var quality: String = str(food_item.get("quality", "basic")).strip_edges()
	var hunger_restore: float = float(food_item.get("hunger_restore", 28.0))
	var nutrition_value: float = float(food_item.get("nutrition", 45.0))
	var spoilage: float = clamp(float(food_item.get("spoilage", 0.0)), 0.0, 1.0)

	if not _passes_dietary_rules(actor, food_item, context):
		return {
			"success": false,
			"reason": "Dietary rules blocked this food.",
			"food_id": food_id
		}

	if spoilage >= 0.85:
		hunger_restore *= 0.25
		nutrition_value *= 0.1
		_apply_health_pressure(actor, -8.0, {
			"source": "spoiled_food",
			"food_id": food_id
		})

	var sustenance_report: Dictionary = apply_sustenance_to_actor(actor, hunger_restore, {
		"source": str(context.get("source", "food_consumed")),
		"food_id": food_id,
		"quality": quality
	})

	profile = hunger_by_actor_id.get(actor_id, {}).duplicate(true)

	nutrition ["nutrition"] = clamp((float(nutrition.get("nutrition", 50.0)) * 0.7) + (nutrition_value * 0.3), 0.0, 100.0)
	nutrition ["protein"] = clamp(float(nutrition.get("protein", 50.0)) + float(food_item.get("protein", 0.0)), 0.0, 100.0)
	nutrition ["vitamins"] = clamp(float(nutrition.get("vitamins", 50.0)) + float(food_item.get("vitamins", 0.0)), 0.0, 100.0)
	nutrition ["sugar_pressure"] = clamp(float(nutrition.get("sugar_pressure", 0.0)) + float(food_item.get("sugar", 0.0)), 0.0, 100.0)
	nutrition ["sodium_pressure"] = clamp(float(nutrition.get("sodium_pressure", 0.0)) + float(food_item.get("sodium", 0.0)), 0.0, 100.0)
	nutrition ["diet_quality"] = quality
	nutrition_profiles [actor_id] = nutrition

	var text: String = "I ate %s." % str(food_item.get("name", food_id))
	var report:= {
		"success": true,
		"actor_id": actor_id,
		"food_id": food_id,
		"hunger": float(profile.get("hunger", 0.0)),
		"hunger_before": float(sustenance_report.get("hunger_before",
profile.get("hunger", 0.0))),
		"hunger_after": float(sustenance_report.get("hunger_after",
profile.get("hunger", 0.0))),
		"hunger_delta": float(sustenance_report.get("hunger_delta", 0.0)),
		"sustenance_report": sustenance_report.duplicate(true),
		"nutrition": nutrition.duplicate(true),
		"text": text
	}

	if gs != null and gs.weight_contract_engine != null and gs.weight_contract_engine.has_method("apply_food_intake"):
		var weight_report: Dictionary = gs.weight_contract_engine.apply_food_intake(actor, food_item, {
			"source": "food_engine.consume_food",
			"food_id": food_id,
			"hunger_before": float(report.get("hunger_before", 0.0)),
			"hunger_after": float(report.get("hunger_after", 0.0)),
			"hunger_delta": float(report.get("hunger_delta", 0.0))
		})
		report ["weight_report"] = weight_report.duplicate(true)

	_record_food_event("food_consumed", actor, report)
	return report
func buy_and_consume(actor: Person, food_item: Dictionary, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var price: float = float(food_item.get("price", 0.0))
	var pay_report: Dictionary = _pay_for_food(actor, price, context)
	if not bool(pay_report.get("success", false)):
		return pay_report

	var consume_report: Dictionary = consume_food(actor, food_item, context)
	consume_report ["payment_report"] = pay_report.duplicate(true)
	return consume_report

func add_pantry_item(owner: Person, food_item: Dictionary, quantity: int = 1, _context: Dictionary = {}) -> Dictionary:
	if owner == null:
		return { "success": false, "reason": "No pantry owner supplied."}

	var owner_id: int = int(owner.id)
	if not pantry_by_owner_id.has(owner_id):
		pantry_by_owner_id [owner_id] = []

	var entry: Dictionary = food_item.duplicate(true)
	entry ["personal_item_id"] = str(entry.get("personal_item_id", _make_personal_food_item_id(owner, entry)))
	entry ["quantity"] = max(1, int(quantity))
	entry ["acquired_year"] = int(gs.year) if gs != null else 0
	entry ["expires_year"] = int(entry.get("expires_year", int(entry.get("acquired_year", 0)) + int(entry.get("shelf_life_years", 2))))
	entry ["spoilage"] = float(entry.get("spoilage", 0.0))
	pantry_by_owner_id [owner_id].append(entry)

	if gs != null and gs.belongings_engine != null:
		gs.belongings_engine.add_item(owner, entry, "Food", false)

	var report:= {
		"success": true,
		"owner_id": owner_id,
		"item": entry.duplicate(true),
		"quantity": int(entry.get("quantity", 1))
	}
	_record_food_event("pantry_item_added", owner, report)
	return report
func _make_personal_food_item_id(owner: Person, item: Dictionary) -> String:
	var owner_id: int = int(owner.id) if owner != null and "id" in owner else 0
	var base_id: String = str(item.get("id", item.get("food_id", "food"))).strip_edges()
	if base_id == "":
		base_id = "food"
	return "food.%d.%s.%d" % [
		owner_id,
		base_id.replace(" ", "_").to_lower(),
		int(Time.get_ticks_msec())
	]
func feed_child_from_family(child: Person) -> Dictionary:
	if child == null:
		return { "success": false, "reason": "No child supplied."}

	ensure_actor_food_profile(child)

	var family_provider: Person = _best_living_parent(child)
	var class_key: String = str(child.social_class) if child.get("social_class") != null else "Commoner"
	if family_provider != null and family_provider.get("social_class") != null:
		class_key = str(family_provider.social_class)

	var meal: Dictionary = _default_family_meal_for_class(class_key)
	if family_provider != null:
		var price: float = float(meal.get("price", 0.0))
		_pay_for_food(family_provider, price, {
			"source": "parent_feeding",
			"child_id": int(child.id)
		})

	var report: Dictionary = consume_food(child, meal, {
		"source": "parent_feeding",
		"provider_id": int(family_provider.id) if family_provider != null else -1
	})
	report ["provider_id"] = int(family_provider.id) if family_provider != null else -1
	return report

func cook_food(actor: Person, raw_food: Dictionary, recipe: Dictionary = {}, _context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return { "success": false, "reason": "No actor supplied."}

	var cooked:= raw_food.duplicate(true)
	cooked ["id"] = str(recipe.get("output_id", "cooked_%s" % str(raw_food.get("id", "food"))))
	cooked ["name"] = str(recipe.get("output_name", "Cooked %s" % str(raw_food.get("name", "Food"))))
	cooked ["quality"] = str(recipe.get("quality", cooked.get("quality", "home_cooked")))
	cooked ["hunger_restore"] = float(cooked.get("hunger_restore", 24.0)) + float(recipe.get("hunger_bonus", 8.0))
	cooked ["nutrition"] = clamp(float(cooked.get("nutrition", 45.0)) + float(recipe.get("nutrition_bonus", 10.0)), 0.0, 100.0)
	cooked ["spoilage"] = max(0.0, float(cooked.get("spoilage", 0.0)) - 0.15)
	cooked ["cooked_year"] = int(gs.year) if gs != null else 0

	if gs != null and gs.belongings_engine != null:
		gs.belongings_engine.add_item(actor, cooked, "Food", false)

	var report:= {
		"success": true,
		"actor_id": int(actor.id),
		"input": raw_food.duplicate(true),
		"output": cooked.duplicate(true),
		"text": "I cooked %s." % str(cooked.get("name", "food"))
	}
	_record_food_event("food_cooked", actor, report)
	return report

func decay_food_yearly(_payload: Dictionary = {}) -> Dictionary:
	var spoiled: Array = []
	if gs == null:
		return { "success": false, "reason": "GameState unavailable."}

	for owner_id in pantry_by_owner_id.keys():
		var next_items: Array = []
		for raw_item in pantry_by_owner_id.get(owner_id, []):
			if typeof(raw_item) != TYPE_DICTIONARY:
				continue
			var item: Dictionary = raw_item.duplicate(true)
			var expires_year: int = int(item.get("expires_year", int(gs.year) + 1))
			var spoilage: float = clamp(float(item.get("spoilage", 0.0)) + 0.2, 0.0, 1.0)
			item ["spoilage"] = spoilage
			if int(gs.year) > expires_year or spoilage >= 1.0:
				spoiled.append(item)
				continue
			next_items.append(item)
		pantry_by_owner_id [owner_id] = next_items

	return {
		"success": true,
		"spoiled_count": spoiled.size(),
		"spoiled": spoiled
	}

func get_food_status_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	if actor == null:
		return []

	ensure_actor_food_profile(actor)
	var profile: Dictionary = hunger_by_actor_id.get(int(actor.id), {})
	var nutrition: Dictionary = nutrition_profiles.get(int(actor.id), {})

	return [
		{
			"label": "Hunger: %d/100" % int(round(float(profile.get("hunger", 0.0)))),
			"value": float(profile.get("hunger", 0.0)),
			"kind": "hunger"
		},
		{
			"label": "Nutrition: %d/100 • %s" % [
				int(round(float(nutrition.get("nutrition", 0.0)))),
				str(nutrition.get("diet_quality", "mixed"))
			],
			"value": float(nutrition.get("nutrition", 0.0)),
			"kind": "nutrition"
		}
	]

func get_pantry_rows(context: Dictionary = {}) -> Array:
	var actor: Person = _actor_from_context(context)
	if actor == null:
		return []

	var out: Array = []
	var pantry: Array = pantry_by_owner_id.get(int(actor.id), [])
	for raw_item in pantry:
		if typeof(raw_item) != TYPE_DICTIONARY:
			continue
		var item: Dictionary = raw_item
		out.append({
			"label": "%s ×%d • spoilage %d%%" % [
				str(item.get("name", "Food")),
				int(item.get("quantity", 1)),
				int(round(float(item.get("spoilage", 0.0)) * 100.0))
			],
			"food_id": str(item.get("id", "")),
			"kind": "pantry_food"
		})
	return out

func export_state() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.food_engine_state",
		"version": FOOD_VERSION,
		"hunger_by_actor_id": hunger_by_actor_id.duplicate(true),
		"nutrition_profiles": nutrition_profiles.duplicate(true),
		"pantry_by_owner_id": pantry_by_owner_id.duplicate(true),
		"food_ledger": food_ledger.duplicate(true),
		"last_report": last_report.duplicate(true)
	})
func _restore_actor_id_keyed_state_map(
	raw: Variant
) -> Dictionary:
	var out: Dictionary = {}

	if typeof(raw) != TYPE_DICTIONARY:
		return out

	var source: Dictionary = raw as Dictionary

	for raw_key in source.keys():
		var actor_id: int = int(
			str(
				raw_key
			)
		)

		if actor_id <= 0:
			continue

		var value: Variant = source [
			raw_key
		]

		if typeof(value) == TYPE_DICTIONARY:
			out [
				actor_id
			] = (
				(value as Dictionary).duplicate(true)
			)
		elif typeof(value) == TYPE_ARRAY:
			out [
				actor_id
			] = (
				(value as Array).duplicate(true)
			)
		else:
			out [
				actor_id
			] = value

	return out
func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "FoodEngine import data must be a Dictionary."
		}




	var imported_hunger_registry: Dictionary = (
		_restore_actor_id_keyed_state_map(
			data.get(
				"hunger_by_actor_id",
				{}
			)
		)
	)
	var imported_nutrition_profiles: Dictionary = (
		_restore_actor_id_keyed_state_map(
			data.get(
				"nutrition_profiles",
				{}
			)
		)
	)
	var imported_pantry_registry: Dictionary = (
		_restore_actor_id_keyed_state_map(
			data.get(
				"pantry_by_owner_id",
				{}
			)
		)
	)

	hunger_state_mutex.lock()
	hunger_by_actor_id = imported_hunger_registry
	hunger_state_mutex.unlock()

	nutrition_profiles = imported_nutrition_profiles
	pantry_by_owner_id = imported_pantry_registry

	food_ledger = (
		data.get(
			"food_ledger",
			[]
		).duplicate(true)
		if typeof(
			data.get(
				"food_ledger",
				[]
			)
		) == TYPE_ARRAY
		else []
	)

	last_report = (
		data.get(
			"last_report",
			{}
		).duplicate(true)
		if typeof(
			data.get(
				"last_report",
				{}
			)
		) == TYPE_DICTIONARY
		else {}
	)

	if gs != null and gs.player != null:
		ensure_actor_food_profile(
			gs.player
		)

	return {
		"success": true,
		"imported_at_ms": int(
			Time.get_ticks_msec()
		),
	}
func _yearly_hunger_gain(actor: Person) -> float:
	var age_factor: float = 12.0
	if int(actor.age) <= 4:
		age_factor = 20.0
	elif int(actor.age) <= 12:
		age_factor = 16.0
	elif int(actor.age) >= 70:
		age_factor = 10.0

	var prison_factor: float = 0.0
	if _actor_has_trait_prefix(actor, "InPrison_"):
		prison_factor = 6.0

	return age_factor + prison_factor

func _default_family_meal_for_class(class_key: String) -> Dictionary:
	var clean: String = str(class_key).to_lower()
	if clean.find("upper") != -1 or clean.find("rich") != -1 or clean.find("royal") != -1:
		return {
			"id": "family_premium_meal",
			"name": "premium family meal",
			"quality": "high_quality",
			"hunger_restore": 36.0,
			"nutrition": 82.0,
			"protein": 8.0,
			"vitamins": 8.0,
			"price": 45.0
		}
	if clean.find("poor") != -1 or clean.find("lower") != -1:
		return {
			"id": "family_struggle_meal",
			"name": "cheap family meal",
			"quality": "cheap",
			"hunger_restore": 24.0,
			"nutrition": 38.0,
			"sodium": 8.0,
			"price": 4.0
		}
	return {
		"id": "family_basic_meal",
		"name": "basic family meal",
		"quality": "basic",
		"hunger_restore": 30.0,
		"nutrition": 58.0,
		"price": 14.0
	}

func _pay_for_food(actor: Person, amount: float, context: Dictionary = {}) -> Dictionary:
	if amount <= 0.0:
		return { "success": true, "skipped": true, "amount": 0.0}

	if gs != null and gs.bank_engine != null and gs.bank_engine.has_method("request_actor_bank_action"):
		return gs.bank_engine.request_actor_bank_action(actor, {
			"action": "withdraw",
			"amount": amount,
			"currency": "USD",
			"reason": "food_purchase"
		}, context)

	if actor.bank_balance < amount:
		return { "success": false, "reason": "Not enough money for food.", "amount": amount}

	actor.bank_balance -= amount
	return { "success": true, "mode": "legacy_bank_balance", "amount": amount}

func _passes_dietary_rules(actor: Person, food_item: Dictionary, context: Dictionary = {}) -> bool:
	var restriction_flags: Array = []
	if _actor_has_trait_prefix(actor, "InPrison_"):
		restriction_flags.append("prison_restricted")

	var blocked_tags: Array = context.get("blocked_food_tags", []) if typeof(context.get("blocked_food_tags", [])) == TYPE_ARRAY else []
	var food_tags: Array = food_item.get("tags", []) if typeof(food_item.get("tags", [])) == TYPE_ARRAY else []
	for tag in blocked_tags:
		if tag in food_tags:
			return false

	return true

func _apply_health_pressure(actor: Person, delta: float, _context: Dictionary = {}) -> void:
	if actor == null:
		return
	actor.health = clamp(float(actor.health) + delta, 0.0, 100.0)
	if delta < 0.0 and gs != null:
		var medical_pressure: float = abs(delta) * 12.0
		if gs.bank_engine != null and gs.bank_engine.has_method("request_actor_bank_action"):
			gs.bank_engine.request_actor_bank_action(actor, {
				"action": "withdraw",
				"amount": medical_pressure,
				"currency": "USD",
				"reason": "food_related_health_cost"
			}, {
				"source": "food_engine",
				"health_delta": delta
			})
func hunger_scalar_contract_for_actor(
	actor_id: int
) -> Dictionary:
	if actor_id <= 0:
		return {
			"success": false,
			"actor_id": actor_id,
			"reason": "invalid_actor_id"
		}




	hunger_state_mutex.lock()

	var profile_raw: Variant = hunger_by_actor_id.get(
		actor_id,
		{}
	)
	var profile: Dictionary = (
		(profile_raw as Dictionary).duplicate(false)
		if typeof(profile_raw) == TYPE_DICTIONARY
		else {}
	)

	hunger_state_mutex.unlock()

	if profile.is_empty():
		return {
			"success": false,
			"actor_id": actor_id,
			"reason": "hunger_profile_not_published",
			"authority": "FoodEngine",
			"read_only": true,
		}

	var hunger_raw: Variant = profile.get(
		"hunger",
		-1.0
	)

	if typeof(hunger_raw) not in [
		TYPE_INT,
		TYPE_FLOAT
	]:
		return {
			"success": false,
			"actor_id": actor_id,
			"reason": "hunger_scalar_not_numeric",
			"authority": "FoodEngine",
			"read_only": true,
		}

	return {
		"success": true,
		"schema": "eralife.food_engine.hunger_scalar_contract",
		"version": FOOD_VERSION,
		"actor_id": actor_id,
		"hunger": clampf(
			float(hunger_raw),
			0.0,
			DEFAULT_MAX_HUNGER
		),
		"authority": "FoodEngine",
		"read_only": true,
		"ui_is_renderer_only": true
	}
func _best_living_parent(child: Person) -> Person:
	if child == null or gs == null:
		return null
	for pid in child.parents:
		var parent: Person = gs.get_npc_by_id(int(pid))
		if parent != null and parent.alive:
			return parent
	return null

func _actor_from_context(context: Dictionary = {}) -> Person:
	if gs == null:
		return null
	var actor_id: int = int(context.get("actor_id", context.get("npc_id", -1)))
	if actor_id > 0 and gs.has_method("get_npc_by_id"):
		var actor: Person = gs.get_npc_by_id(actor_id)
		if actor != null:
			return actor
	return gs.player

func _actor_has_trait_prefix(actor: Person, prefix: String) -> bool:
	if actor == null:
		return false
	for raw_trait in actor.traits:
		if str(raw_trait).begins_with(prefix):
			return true
	return false
func _store_hunger_profile(
	actor_id: int,
	profile: Dictionary
) -> void:
	if actor_id <= 0:
		return

	var frozen_profile: Dictionary = (
		profile.duplicate(true)
	)

	hunger_state_mutex.lock()

	hunger_by_actor_id [
		actor_id
	] = frozen_profile

	hunger_state_mutex.unlock()
func _sync_person_hunger(actor: Person) -> void:
	if actor == null:
		return

	var scalar_contract: Dictionary = (
		hunger_scalar_contract_for_actor(
			int(actor.id)
		)
	)

	if not bool(
		scalar_contract.get(
			"success",
			false
		)
	):
		return

	if actor.get("hunger") != null:
		actor.hunger = clamp(
			float(
				scalar_contract.get(
					"hunger",
					DEFAULT_STARTING_HUNGER
				)
			),
			0.0,
			DEFAULT_MAX_HUNGER
		)
func sync_published_hunger_to_actor(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return {
			"success": false,
			"reason": "missing_actor"
		}

	var actor_id: int = int(
		actor.id
	)
	var scalar_contract: Dictionary = (
		hunger_scalar_contract_for_actor(
			actor_id
		)
	)

	if not bool(
		scalar_contract.get(
			"success",
			false
		)
	):
		return {
			"success": false,
			"reason": str(
				scalar_contract.get(
					"reason",
					"hunger_scalar_not_published"
				)
			),
			"actor_id": actor_id,
		}

	var hunger_value: float = clampf(
		float(
			scalar_contract.get(
				"hunger",
				DEFAULT_STARTING_HUNGER
			)
		),
		0.0,
		DEFAULT_MAX_HUNGER
	)

	if actor.get("hunger") != null:
		actor.hunger = hunger_value

	return {
		"success": true,
		"schema": "eralife.food_engine.published_hunger_person_mirror",
		"actor_id": actor_id,
		"hunger": hunger_value,
		"authority": "FoodEngine",
		"source": str(
			context.get(
				"source",
				"food_engine"
			)
		),
		"ready_gate_member": false
	}

func _record_food_event(event_name: String, actor: Person, payload: Dictionary = {}) -> void:
	var entry:= {
		"event_name": event_name,
		"actor_id": int(actor.id) if actor != null else -1,
		"payload": payload.duplicate(true),
		"year": int(gs.year) if gs != null else 0,
		"at_ms": int(Time.get_ticks_msec())
	}
	food_ledger.append(entry)

	if gs != null and gs.event_bus != null:
		gs.event_bus.emit(event_name, entry.duplicate(true))

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