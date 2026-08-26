extends Resource
class_name ConsciousnessEngine

const CONSCIOUSNESS_VERSION:= 1
const CONSCIOUSNESS_SCHEMA:= "eralife.consciousness_contract"
const CONSCIOUSNESS_MEMORY_SCHEMA:= "eralife.consciousness_memory"
const MAX_MEMORY_INDEX_SIZE:= 250

var gs
var consciousness_index: Dictionary = {}
var consciousness_reports: Array = []
var last_consciousness_report: Dictionary = {}

func _init(_gs = null):
	gs = _gs

func export_state() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.consciousness_engine_state",
		"version": CONSCIOUSNESS_VERSION,
		"consciousness_index": consciousness_index.duplicate(true),
		"consciousness_reports": consciousness_reports.duplicate(true),
		"last_consciousness_report": last_consciousness_report.duplicate(true)
	})

func import_state(state: Dictionary) -> Dictionary:
	if typeof(state) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "ConsciousnessEngine import_state expected a Dictionary."
		}

	consciousness_index = _safe_dictionary(state.get("consciousness_index", {}))
	consciousness_reports = _safe_array(state.get("consciousness_reports", []))
	last_consciousness_report = _safe_dictionary(state.get("last_consciousness_report", {}))

	return {
		"success": true,
		"indexed_consciousness_count": consciousness_index.size(),
		"report_count": consciousness_reports.size()
	}

func ensure_consciousness(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {}

	var existing: Dictionary = _person_consciousness_contract(person)
	var resolved: Dictionary = {}

	if existing.is_empty():
		resolved = _default_consciousness_contract(person, context)
	else:
		resolved = _resolve_consciousness_contract(existing, person, context)

	resolved = _apply_soul_seed_contract(resolved, person, context)
	resolved = _apply_life_stage_growth(resolved, person, context)
	resolved = _apply_reality_mode_adjustments(resolved, person, context)
	resolved = _apply_trait_adjustments(resolved, person, context)
	resolved = _apply_fantasy_adjustments(resolved, person, context)
	resolved = _apply_consciousness_archetype_adjustments(resolved, person, context)
	resolved = _apply_contractual_consciousness_pressure(resolved, person, context)
	resolved = _apply_status_and_role_adjustments(resolved, person, context)
	resolved = _normalize_consciousness_contract(resolved)

	person.consciousness_contract = resolved.duplicate(true)
	person.consciousness_state = _build_consciousness_state(person, resolved, context)

	var id_key: String = str(int(person.id))
	consciousness_index [id_key] = {
		"person_id": int(person.id),
		"name": _person_name(person),
		"age": int(person.age),
		"alive": bool(person.alive),
		"soul_seed_id": str(person.soul_seed_contract.get("soul_seed_id", "")) if typeof(person.soul_seed_contract) == TYPE_DICTIONARY else "",
		"contract": resolved.duplicate(true),
		"state": person.consciousness_state.duplicate(true),
		"updated_at_year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec())
	}

	return resolved.duplicate(true)
func remember(person: Person, text: String, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"reason": "Person missing."
		}

	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		return {
			"success": false,
			"reason": "Memory text empty."
		}

	var contract: Dictionary = ensure_consciousness(person, context)
	var memory_rules: Dictionary = _safe_dictionary(contract.get("memory", {}))
	var emotion_system: Dictionary = _safe_dictionary(contract.get("emotion_system", {}))

	var trauma_weight: float = float(memory_rules.get("trauma_weight", 1.4))
	var joy_weight: float = float(memory_rules.get("joy_weight", 1.2))
	var retention: float = float(memory_rules.get("retention", 0.7))
	var emotional_link: float = float(emotion_system.get("emotional_memory_link", 0.5))

	var emotional_weight: float = _memory_emotional_weight(clean_text, context, trauma_weight, joy_weight)
	var salience: float = clamp((retention * 0.65) + (emotional_weight * emotional_link * 0.35), 0.0, 2.5)

	var narrative_contract: Dictionary = _safe_dictionary(context.get("narrative_contract", {}))
	var memory_impact: Dictionary = _safe_dictionary(context.get("memory_impact", {}))
	var emotion_tags: Array = _infer_emotion_tags(clean_text, context)
	var current_year: int = _current_year()

	var memory_id: String = str(context.get("memory_id", "")).strip_edges()
	if memory_id == "":
		memory_id = "memory_%d_%d" % [int(person.id), int(Time.get_ticks_msec())]

	var memory: Dictionary = {
		"schema": CONSCIOUSNESS_MEMORY_SCHEMA,
		"version": CONSCIOUSNESS_VERSION,
		"memory_id": memory_id,
		"person_id": int(person.id),
		"person_name": _person_name(person),
		"text": clean_text,
		"original_text": str(context.get("original_text", clean_text)),
		"current_text": str(context.get("current_text", clean_text)),
		"year": current_year,
		"last_reinterpreted_year": current_year,
		"reinterpretation_count": 0,
		"reinterpretation_history": [],
		"age": int(person.age),
		"source": str(context.get("source", "consciousness_engine")),
		"memory_type": str(context.get("memory_type", "episodic")),
		"perspective": str(context.get("perspective", "first_person")),
		"tone": str(context.get("narrative_tone", context.get("tone", "neutral"))),
		"emotion_tags": emotion_tags,
		"salience": salience,
		"retention": retention,
		"emotional_weight": emotional_weight,
		"memory_impact": memory_impact.duplicate(true),
		"relationship_delta": int(context.get("relationship_delta", 0)),
		"event_name": str(context.get("event_name", "")),
		"category": str(context.get("category", "")),
		"shared_event_id": str(context.get("shared_event_id", "")),
		"conflicting_narrative_group": str(context.get("conflicting_narrative_group", "")),
		"narrative_contract": narrative_contract.duplicate(true),
		"cross_universe": bool(memory_rules.get("cross_universe_indexing", false)),
		"universe_seed": _current_world_seed(),
		"created_at_ms": int(Time.get_ticks_msec())
	}

	var memory_index: Array = _safe_array(person.consciousness_memory_index)
	memory_index.append(memory)
	while memory_index.size() > MAX_MEMORY_INDEX_SIZE:
		memory_index.pop_front()

	person.consciousness_memory_index = memory_index

	if person.memories == null:
		person.memories = []

	if not person.memories.has(clean_text):
		person.memories.append(clean_text)

	var impact_report: Dictionary = {}
	if not narrative_contract.is_empty() or not memory_impact.is_empty():
		impact_report = apply_narrative_memory_impact(person, narrative_contract, clean_text, {
			"source": "memory_written",
			"memory": memory.duplicate(true),
			"memory_impact": memory_impact.duplicate(true)
		})

	ensure_consciousness(person, {
		"source": "memory_written",
		"last_memory_salience": salience,
		"last_memory_tone": str(memory.get("tone", "neutral"))
	})

	var report: Dictionary = {
		"schema": "eralife.consciousness_memory_report",
		"version": CONSCIOUSNESS_VERSION,
		"success": true,
		"person_id": int(person.id),
		"person_name": _person_name(person),
		"memory": memory.duplicate(true),
		"impact_report": impact_report.duplicate(true)
	}

	_commit_report(report)
	return report.duplicate(true)

func evolve_year(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"reason": "Person missing."
		}

	var before: Dictionary = ensure_consciousness(person, context)
	var after: Dictionary = before.duplicate(true)

	var memory_rules: Dictionary = _safe_dictionary(after.get("memory", {}))
	var continuity: Dictionary = _safe_dictionary(after.get("continuity", {}))
	var awareness: Dictionary = _safe_dictionary(after.get("awareness", {}))
	var perception: Dictionary = _safe_dictionary(after.get("perception", {}))
	var learning: Dictionary = _safe_dictionary(after.get("learning_engine", {}))

	var age_value: int = int(person.age)

	if age_value < 6:
		awareness ["self_awareness"] = clamp(float(awareness.get("self_awareness", 0.2)) + 0.04, 0.05, 0.45)
		memory_rules ["retention"] = clamp(float(memory_rules.get("retention", 0.4)) + 0.03, 0.15, 0.65)
		continuity ["identity_drift"] = clamp(float(continuity.get("identity_drift", 0.2)) - 0.01, 0.05, 0.8)
	elif age_value < 18:
		awareness ["self_awareness"] = clamp(float(awareness.get("self_awareness", 0.45)) + 0.025, 0.2, 0.85)
		awareness ["meta_cognition"] = clamp(float(awareness.get("meta_cognition", 0.2)) + 0.02, 0.1, 0.75)
		learning ["adaptation_speed"] = clamp(float(learning.get("adaptation_speed", 0.7)) + 0.01, 0.3, 0.95)
	elif age_value < 65:
		continuity ["identity_drift"] = clamp(float(continuity.get("identity_drift", 0.1)) - 0.005, 0.02, 0.6)
		awareness ["meta_cognition"] = clamp(float(awareness.get("meta_cognition", 0.7)) + 0.005, 0.3, 0.9)
	else:
		memory_rules ["decay_rate"] = clamp(float(memory_rules.get("decay_rate", 0.05)) + 0.015, 0.02, 0.35)
		perception ["pattern_recognition"] = clamp(float(perception.get("pattern_recognition", 0.75)) + 0.01, 0.2, 1.0)

	memory_rules ["memory_bias"] = "emotion_weighted"

	after ["memory"] = memory_rules
	after ["continuity"] = continuity
	after ["awareness"] = awareness
	after ["perception"] = perception
	after ["learning_engine"] = learning

	var reinterpretation_report: Dictionary = _reinterpret_memory_index_for_year(person, after, context)

	person.consciousness_contract = _make_binary_safe(after)
	person.consciousness_state = _build_consciousness_state(person, after, context)

	var report: Dictionary = {
		"schema": "eralife.consciousness_evolution_report",
		"version": CONSCIOUSNESS_VERSION,
		"success": true,
		"person_id": int(person.id),
		"person_name": _person_name(person),
		"age": age_value,
		"before": before,
		"after": after,
		"reinterpretation_report": reinterpretation_report.duplicate(true)
	}

	_commit_report(report)
	return report.duplicate(true)
func apply_narrative_memory_impact(person: Person, narrative_contract: Dictionary = {}, text: String = "", context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"reason": "Person missing."
		}

	var contract: Dictionary = ensure_consciousness(person, {
		"source": "narrative_memory_impact_preflight"
	})

	var memory_impact: Dictionary = _safe_dictionary(context.get("memory_impact", {}))
	if memory_impact.is_empty():
		var memory_row: Dictionary = _safe_dictionary(context.get("memory", {}))
		memory_impact = _safe_dictionary(memory_row.get("memory_impact", {}))

	var trauma: float = clamp(float(memory_impact.get("trauma", 0.0)), 0.0, 1.0)
	var healing: float = clamp(float(memory_impact.get("healing", 0.0)), 0.0, 1.0)
	var resentment: float = clamp(float(memory_impact.get("resentment", 0.0)), 0.0, 1.0)
	var pride: float = clamp(float(memory_impact.get("pride", 0.0)), 0.0, 1.0)
	var memory_pressure: float = clamp(float(memory_impact.get("memory_pressure", trauma + resentment - healing)), 0.0, 1.0)

	var emotion_system: Dictionary = _safe_dictionary(contract.get("emotion_system", {}))
	var pressure_state: Dictionary = _safe_dictionary(contract.get("pressure_state", {}))
	var social_model: Dictionary = _safe_dictionary(contract.get("social_model", {}))
	var memory_rules: Dictionary = _safe_dictionary(contract.get("memory", {}))
	var continuity: Dictionary = _safe_dictionary(contract.get("continuity", {}))

	if trauma > 0.0:
		pressure_state ["trauma_load"] = clamp(float(pressure_state.get("trauma_load", 0.0)) + trauma * 0.12, 0.0, 1.0)
		emotion_system ["reactivity"] = clamp(float(emotion_system.get("reactivity", 0.6)) + trauma * 0.04, 0.0, 2.0)
		memory_rules ["trauma_weight"] = clamp(float(memory_rules.get("trauma_weight", 1.4)) + trauma * 0.08, 0.0, 3.0)

	if resentment > 0.0:
		pressure_state ["resentment_load"] = clamp(float(pressure_state.get("resentment_load", 0.0)) + resentment * 0.1, 0.0, 1.0)
		social_model ["trust_baseline"] = clamp(float(social_model.get("trust_baseline", 0.5)) - resentment * 0.04, 0.0, 1.0)

	if healing > 0.0:
		pressure_state ["healing_load"] = clamp(float(pressure_state.get("healing_load", 0.0)) + healing * 0.1, 0.0, 1.0)
		pressure_state ["trauma_load"] = clamp(float(pressure_state.get("trauma_load", 0.0)) - healing * 0.06, 0.0, 1.0)
		emotion_system ["recovery_rate"] = clamp(float(emotion_system.get("recovery_rate", 0.5)) + healing * 0.05, 0.0, 1.5)

	if pride > 0.0:
		pressure_state ["confidence_memory_load"] = clamp(float(pressure_state.get("confidence_memory_load", 0.0)) + pride * 0.08, 0.0, 1.0)
		continuity ["identity_drift"] = clamp(float(continuity.get("identity_drift", 0.1)) - pride * 0.02, 0.0, 1.0)

	if memory_pressure > 0.0:
		continuity ["identity_drift"] = clamp(float(continuity.get("identity_drift", 0.1)) + memory_pressure * 0.015, 0.0, 1.0)

	contract ["emotion_system"] = emotion_system
	contract ["pressure_state"] = pressure_state
	contract ["social_model"] = social_model
	contract ["memory"] = memory_rules
	contract ["continuity"] = continuity

	person.consciousness_contract = _normalize_consciousness_contract(contract)
	person.consciousness_state = _build_consciousness_state(person, person.consciousness_contract, {
		"source": "narrative_memory_impact",
		"text": text,
		"narrative_contract": narrative_contract.duplicate(true)
	})

	var report: Dictionary = {
		"schema": "eralife.narrative_memory_impact_report",
		"version": CONSCIOUSNESS_VERSION,
		"success": true,
		"person_id": int(person.id),
		"person_name": _person_name(person),
		"impact": memory_impact.duplicate(true),
		"contract": person.consciousness_contract.duplicate(true)
	}

	_commit_report(report)
	return report.duplicate(true)


func reinterpret_memories_for_person(person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"reason": "Person missing."
		}

	var contract: Dictionary = ensure_consciousness(person, {
		"source": "manual_memory_reinterpretation"
	})

	return _reinterpret_memory_index_for_year(person, contract, context)


func _reinterpret_memory_index_for_year(person: Person, contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"reason": "Person missing."
		}

	var memory_index: Array = _safe_array(person.consciousness_memory_index)
	if memory_index.is_empty():
		return {
			"success": true,
			"reinterpreted": 0,
			"memory_count": 0
		}

	var current_year: int = _current_year()
	var reinterpreted: int = 0
	var out: Array = []

	for raw_memory in memory_index:
		if typeof(raw_memory) != TYPE_DICTIONARY:
			out.append(raw_memory)
			continue

		var memory: Dictionary = raw_memory.duplicate(true)
		var allow_reinterpretation: bool = true

		var narrative_contract: Dictionary = _safe_dictionary(memory.get("narrative_contract", {}))
		var rendering: Dictionary = _safe_dictionary(narrative_contract.get("rendering", {}))
		if narrative_contract.size() > 0:
			allow_reinterpretation = bool(rendering.get("allow_reinterpretation", true))

		if not allow_reinterpretation:
			out.append(memory)
			continue

		var last_year: int = int(memory.get("last_reinterpreted_year", memory.get("year", current_year)))
		if last_year >= current_year:
			out.append(memory)
			continue

		var original_text: String = str(memory.get("original_text", memory.get("text", ""))).strip_edges()
		var previous_text: String = str(memory.get("current_text", memory.get("text", original_text))).strip_edges()
		var new_tone: String = _memory_reinterpretation_tone(person, contract, memory, context)
		var new_text: String = _reinterpret_memory_text(original_text, previous_text, new_tone, memory, contract)

		var history: Array = _safe_array(memory.get("reinterpretation_history", []))
		history.append({
			"year": current_year,
			"age": int(person.age),
			"previous_text": previous_text,
			"new_text": new_text,
			"tone": new_tone,
			"source": str(context.get("source", "consciousness_year_evolution")),
			"created_at_ms": int(Time.get_ticks_msec())
		})

		while history.size() > 12:
			history.pop_front()

		memory ["previous_text"] = previous_text
		memory ["current_text"] = new_text
		memory ["tone"] = new_tone
		memory ["last_reinterpreted_year"] = current_year
		memory ["reinterpretation_count"] = int(memory.get("reinterpretation_count", 0)) + 1
		memory ["reinterpretation_history"] = history

		reinterpreted += 1
		out.append(memory)

	person.consciousness_memory_index = out

	return {
		"success": true,
		"reinterpreted": reinterpreted,
		"memory_count": out.size(),
		"year": current_year
	}


func _memory_reinterpretation_tone(person: Person, contract: Dictionary, memory: Dictionary, _context: Dictionary = {}) -> String:
	var emotion_system: Dictionary = _safe_dictionary(contract.get("emotion_system", {}))
	var pressure_state: Dictionary = _safe_dictionary(contract.get("pressure_state", {}))
	var belief: Dictionary = _safe_dictionary(contract.get("belief_system", {}))
	var impact: Dictionary = _safe_dictionary(memory.get("memory_impact", {}))

	var trauma: float = clamp(float(impact.get("trauma", 0.0)), 0.0, 1.0)
	var healing: float = clamp(float(impact.get("healing", 0.0)), 0.0, 1.0)
	var resentment: float = clamp(float(impact.get("resentment", 0.0)), 0.0, 1.0)
	var faith_level: float = clamp(float(belief.get("faith_level", 0.0)), 0.0, 1.0)
	var recovery_rate: float = clamp(float(emotion_system.get("recovery_rate", 0.5)), 0.0, 1.5)
	var trauma_load: float = clamp(float(pressure_state.get("trauma_load", 0.0)), 0.0, 1.0)
	var resentment_load: float = clamp(float(pressure_state.get("resentment_load", 0.0)), 0.0, 1.0)

	if faith_level >= 0.72 and trauma >= 0.3:
		return "spiritual"
	if healing + recovery_rate >= trauma + resentment + 0.4:
		return "healing"
	if resentment + resentment_load >= 0.65:
		return "bitter"
	if trauma + trauma_load >= 0.7:
		return "numb"
	if int(person.satisfaction) >= 72:
		return "hopeful"

	return str(memory.get("tone", "neutral"))


func _reinterpret_memory_text(original_text: String, previous_text: String, tone: String, memory: Dictionary, _contract: Dictionary) -> String:
	var base_text: String = str(original_text).strip_edges()
	if base_text == "":
		base_text = str(previous_text).strip_edges()
	if base_text == "":
		return ""

	var years_old: int = max(0, _current_year() - int(memory.get("year", _current_year())))

	match str(tone).strip_edges().to_lower():
		"healing":
			if years_old >= 2:
				return base_text + " I still remember it, but it does not control me the same way anymore."
			return base_text
		"spiritual":
			if years_old >= 1:
				return base_text + " Over time, I started seeing it through faith."
			return base_text
		"bitter":
			if years_old >= 1:
				return base_text + " The older it gets, the more bitter it feels."
			return base_text
		"numb":
			if years_old >= 1:
				return base_text + " I remember the facts more clearly than the feeling."
			return base_text
		"hopeful":
			if years_old >= 1:
				return base_text + " I can feel myself growing around that memory."
			return base_text
		_:
			return base_text

func apply_consciousness_modifier(person: Person, modifier: Dictionary = {}) -> Dictionary:
	if person == null:
		return {
			"success": false,
			"reason": "Person missing."
		}

	var contract: Dictionary = ensure_consciousness(person, {
		"source": "modifier_preflight"
	})
	var modifier_id: String = str(modifier.get("id", modifier.get("modifier_id", ""))).strip_edges().to_lower()
	var intensity: float = clamp(float(modifier.get("intensity", 1.0)), 0.0, 10.0)

	if modifier_id == "":
		return {
			"success": false,
			"reason": "Modifier id missing."
		}

	match modifier_id:
		"mind_stone", "mind stone":
			var perception: Dictionary = _safe_dictionary(contract.get("perception", {}))
			var awareness: Dictionary = _safe_dictionary(contract.get("awareness", {}))
			var emotion_system: Dictionary = _safe_dictionary(contract.get("emotion_system", {}))
			var memory_rules: Dictionary = _safe_dictionary(contract.get("memory", {}))

			perception ["pattern_recognition"] = clamp(float(perception.get("pattern_recognition", 0.5)) + (0.12 * intensity), 0.0, 1.5)
			perception ["threat_detection"] = clamp(float(perception.get("threat_detection", 0.5)) + (0.08 * intensity), 0.0, 1.5)
			awareness ["meta_cognition"] = clamp(float(awareness.get("meta_cognition", 0.4)) + (0.1 * intensity), 0.0, 1.5)
			awareness ["reality_awareness"] = clamp(float(awareness.get("reality_awareness", 0.1)) + (0.05 * intensity), 0.0, 1.0)
			emotion_system ["emotional_memory_link"] = clamp(float(emotion_system.get("emotional_memory_link", 0.5)) + (0.08 * intensity), 0.0, 1.5)
			memory_rules ["memory_bias"] = "mind_stone_amplified"

			contract ["perception"] = perception
			contract ["awareness"] = awareness
			contract ["emotion_system"] = emotion_system
			contract ["memory"] = memory_rules

		"reality_fusion":
			var continuity: Dictionary = _safe_dictionary(contract.get("continuity", {}))
			continuity ["identity_drift"] = clamp(float(continuity.get("identity_drift", 0.1)) + (0.05 * intensity), 0.0, 1.0)
			continuity ["fusion_susceptibility"] = clamp(float(continuity.get("fusion_susceptibility", 0.3)) + (0.04 * intensity), 0.0, 1.0)
			contract ["continuity"] = continuity

		"afterlife_projection":
			var continuity_afterlife: Dictionary = _safe_dictionary(contract.get("continuity", {}))
			var awareness_afterlife: Dictionary = _safe_dictionary(contract.get("awareness", {}))
			continuity_afterlife ["body_anchor"] = "released"
			continuity_afterlife ["pure_consciousness"] = true
			awareness_afterlife ["reality_awareness"] = clamp(float(awareness_afterlife.get("reality_awareness", 0.2)) + 0.2, 0.0, 1.0)
			contract ["continuity"] = continuity_afterlife
			contract ["awareness"] = awareness_afterlife

		_:
			var residue: Dictionary = _safe_dictionary(person.identity_residue)
			residue ["unknown_consciousness_modifier"] = str(modifier_id)
			person.identity_residue = residue

	person.consciousness_contract = _make_binary_safe(contract)
	person.consciousness_state = _build_consciousness_state(person, contract, {
		"source": "modifier_applied",
		"modifier": modifier.duplicate(true)
	})

	var report: Dictionary = {
		"schema": "eralife.consciousness_modifier_report",
		"version": CONSCIOUSNESS_VERSION,
		"success": true,
		"person_id": int(person.id),
		"person_name": _person_name(person),
		"modifier_id": modifier_id,
		"intensity": intensity,
		"contract": person.consciousness_contract.duplicate(true)
	}

	_commit_report(report)
	return report.duplicate(true)

func project_afterlife_consciousness(
	person: Person,
	payload: Dictionary = {}
) -> Dictionary:
	if person == null:
		return {}




	var base: Dictionary = (
		_person_consciousness_contract(
			person
		)
	)

	if base.is_empty():
		return _make_binary_safe({
			"schema": "eralife.afterlife_consciousness_projection",
			"version": CONSCIOUSNESS_VERSION,
			"person_id": int(
				person.id
			),
			"person_name": _person_name(
				person
			),
			"cause": str(
				payload.get(
					"cause",
					person.cause_of_death
				)
			),
			"contract": {},
			"memory_index": _safe_array(
				person.consciousness_memory_index
			),
			"projection_pending": true,
			"background_only": true,
			"blocks_ui": false,
			"ready_gate_member": false,
			"projected_at_year": _current_year(),
			"projected_at_ms": int(
				Time.get_ticks_msec()
			)
		})

	var projected: Dictionary = base.duplicate(true)
	var continuity: Dictionary = _safe_dictionary(
		projected.get(
			"continuity",
			{}
		)
	)
	var memory_rules: Dictionary = _safe_dictionary(
		projected.get(
			"memory",
			{}
		)
	)
	var awareness: Dictionary = _safe_dictionary(
		projected.get(
			"awareness",
			{}
		)
	)

	continuity [
		"body_anchor"
	] = "released"
	continuity [
		"pure_consciousness"
	] = true
	continuity [
		"cross_universe_memory"
	] = true
	continuity [
		"identity_drift"
	] = clamp(
		float(
			continuity.get(
				"identity_drift",
				0.1
			)
		) + 0.08,
		0.0,
		1.0
	)

	memory_rules [
		"type"
	] = "persistent_afterlife_multiverse"
	memory_rules [
		"retention"
	] = clamp(
		float(
			memory_rules.get(
				"retention",
				0.7
			)
		) + 0.15,
		0.0,
		1.0
	)
	memory_rules [
		"cross_universe_indexing"
	] = true

	awareness [
		"reality_awareness"
	] = clamp(
		float(
			awareness.get(
				"reality_awareness",
				0.2
			)
		) + 0.25,
		0.0,
		1.0
	)
	awareness [
		"multiverse_awareness"
	] = clamp(
		float(
			awareness.get(
				"multiverse_awareness",
				0.05
			)
		) + 0.25,
		0.0,
		1.0
	)

	projected [
		"continuity"
	] = continuity
	projected [
		"memory"
	] = memory_rules
	projected [
		"awareness"
	] = awareness

	return _make_binary_safe({
		"schema": "eralife.afterlife_consciousness_projection",
		"version": CONSCIOUSNESS_VERSION,
		"person_id": int(
			person.id
		),
		"person_name": _person_name(
			person
		),
		"cause": str(
			payload.get(
				"cause",
				person.cause_of_death
			)
		),
		"contract": projected,
		"memory_index": _safe_array(
			person.consciousness_memory_index
		),
		"projection_pending": false,
		"background_only": true,
		"blocks_ui": false,
		"ready_gate_member": false,
		"projected_at_year": _current_year(),
		"projected_at_ms": int(
			Time.get_ticks_msec()
		)
	})
func _default_consciousness_contract(person: Person, context: Dictionary = {}) -> Dictionary:
	var age_value: int = int(person.age)
	var stage: Dictionary = _stage_defaults(age_value)
	var moral_axis: Array = _infer_moral_axis(person, context)
	var dominant_emotions: Array = _infer_dominant_emotions(person, context)
	var goal_priority: Array = _infer_goal_priority(person, context)

	return _make_binary_safe({
		"schema": CONSCIOUSNESS_SCHEMA,
		"version": CONSCIOUSNESS_VERSION,
		"identity": {
			"core_self": "persistent",
			"ego_strength": stage.get("ego_strength", 0.5),
			"adaptability": stage.get("adaptability", 0.5),
			"self_image_stability": stage.get("identity_stability", 0.5),
			"value_system": {
				"moral_axis": moral_axis,
				"flexibility": stage.get("value_flexibility", 0.5)
			}
		},
		"memory": {
			"type": "persistent_multiverse",
			"retention": stage.get("memory_retention", 0.5),
			"decay_rate": stage.get("memory_decay", 0.05),
			"compression": "semantic",
			"trauma_weight": 1.4,
			"joy_weight": 1.2,
			"memory_bias": "emotion_weighted",
			"cross_universe_indexing": false
		},
		"perception": {
			"biases": _infer_biases(person, context),
			"pattern_recognition": stage.get("pattern_recognition", 0.5),
			"emotional_filter": stage.get("emotional_filter", 0.5),
			"attention_span": stage.get("attention_span", 0.5),
			"threat_detection": stage.get("threat_detection", 0.5),
			"optimism_bias": stage.get("optimism_bias", 0.4)
		},
		"emotion_system": {
			"baseline_mood": clamp(float(person.satisfaction) / 100.0, 0.0, 1.0),
			"reactivity": stage.get("reactivity", 0.6),
			"recovery_rate": stage.get("recovery_rate", 0.5),
			"emotional_memory_link": stage.get("emotional_memory_link", 0.6),
			"dominant_emotions": dominant_emotions
		},
		"decision_engine": {
			"risk_tolerance": stage.get("risk_tolerance", 0.4),
			"goal_priority": goal_priority,
			"impulse_control": stage.get("impulse_control", 0.5),
			"delayed_gratification": stage.get("delayed_gratification", 0.5),
			"decision_style": stage.get("decision_style", "weighted_contextual")
		},
		"behavioral_patterns": {
			"habit_strength": stage.get("habit_strength", 0.5),
			"addiction_susceptibility": _addiction_susceptibility(person),
			"discipline": stage.get("discipline", 0.5),
			"social_adaptability": stage.get("social_adaptability", 0.5)
		},
		"continuity": {
			"cross_universe_memory": false,
			"identity_drift": stage.get("identity_drift", 0.1),
			"fusion_susceptibility": stage.get("fusion_susceptibility", 0.3),
			"fragmentation_threshold": stage.get("fragmentation_threshold", 0.6),
			"self_repair_rate": stage.get("self_repair_rate", 0.4)
		},
		"belief_system": {
			"faith_level": _infer_faith_level(person, context),
			"meaning_seeking": _infer_meaning_seeking(person, context),
			"existential_stability": stage.get("existential_stability", 0.5)
		},
		"awareness": {
			"self_awareness": stage.get("self_awareness", 0.5),
			"meta_cognition": stage.get("meta_cognition", 0.4),
			"reality_awareness": stage.get("reality_awareness", 0.05),
			"multiverse_awareness": stage.get("multiverse_awareness", 0.0)
		},
		"social_model": {
			"trust_baseline": stage.get("trust_baseline", 0.5),
			"attachment_style": _infer_attachment_style(person),
			"loyalty_strength": stage.get("loyalty_strength", 0.6),
			"status_sensitivity": stage.get("status_sensitivity", 0.5)
		},
		"learning_engine": {
			"learning_rate": stage.get("learning_rate", 0.6),
			"adaptation_speed": stage.get("adaptation_speed", 0.6),
			"failure_response": "reflect_and_retry"
		}
	})

func _stage_defaults(age_value: int) -> Dictionary:
	if age_value <= 3:
		return {
			"self_awareness": 0.12,
			"meta_cognition": 0.02,
			"memory_retention": 0.22,
			"memory_decay": 0.12,
			"identity_stability": 0.25,
			"ego_strength": 0.18,
			"adaptability": 0.85,
			"decision_style": "impulsive",
			"impulse_control": 0.12,
			"delayed_gratification": 0.05,
			"attention_span": 0.18,
			"pattern_recognition": 0.18,
			"emotional_filter": 0.15,
			"reactivity": 0.9,
			"recovery_rate": 0.45,
			"emotional_memory_link": 0.85,
			"identity_drift": 0.35,
			"fusion_susceptibility": 0.55,
			"fragmentation_threshold": 0.35,
			"self_repair_rate": 0.65,
			"learning_rate": 0.85,
			"adaptation_speed": 0.85,
			"discipline": 0.08,
			"habit_strength": 0.2,
			"social_adaptability": 0.75,
			"trust_baseline": 0.65,
			"loyalty_strength": 0.6,
			"status_sensitivity": 0.1,
			"existential_stability": 0.35
		}

	if age_value <= 12:
		return {
			"self_awareness": 0.35,
			"meta_cognition": 0.18,
			"memory_retention": 0.52,
			"memory_decay": 0.07,
			"identity_stability": 0.42,
			"ego_strength": 0.38,
			"adaptability": 0.75,
			"decision_style": "emotion_weighted",
			"impulse_control": 0.35,
			"delayed_gratification": 0.28,
			"attention_span": 0.42,
			"pattern_recognition": 0.42,
			"emotional_filter": 0.38,
			"reactivity": 0.75,
			"recovery_rate": 0.58,
			"emotional_memory_link": 0.82,
			"identity_drift": 0.24,
			"fusion_susceptibility": 0.45,
			"fragmentation_threshold": 0.45,
			"self_repair_rate": 0.58,
			"learning_rate": 0.8,
			"adaptation_speed": 0.78,
			"discipline": 0.32,
			"habit_strength": 0.45,
			"social_adaptability": 0.72,
			"trust_baseline": 0.55,
			"loyalty_strength": 0.7,
			"status_sensitivity": 0.35,
			"existential_stability": 0.5
		}

	if age_value <= 17:
		return {
			"self_awareness": 0.62,
			"meta_cognition": 0.45,
			"memory_retention": 0.72,
			"memory_decay": 0.05,
			"identity_stability": 0.55,
			"ego_strength": 0.62,
			"adaptability": 0.68,
			"decision_style": "identity_forming",
			"impulse_control": 0.48,
			"delayed_gratification": 0.42,
			"attention_span": 0.58,
			"pattern_recognition": 0.6,
			"emotional_filter": 0.62,
			"reactivity": 0.72,
			"recovery_rate": 0.54,
			"emotional_memory_link": 0.88,
			"identity_drift": 0.18,
			"fusion_susceptibility": 0.38,
			"fragmentation_threshold": 0.55,
			"self_repair_rate": 0.5,
			"learning_rate": 0.75,
			"adaptation_speed": 0.68,
			"discipline": 0.48,
			"habit_strength": 0.58,
			"social_adaptability": 0.68,
			"trust_baseline": 0.45,
			"loyalty_strength": 0.78,
			"status_sensitivity": 0.7,
			"existential_stability": 0.58
		}

	if age_value <= 64:
		return {
			"self_awareness": 0.8,
			"meta_cognition": 0.75,
			"memory_retention": 0.9,
			"memory_decay": 0.05,
			"identity_stability": 0.72,
			"ego_strength": 0.8,
			"adaptability": 0.6,
			"decision_style": "weighted_contextual",
			"impulse_control": 0.7,
			"delayed_gratification": 0.75,
			"attention_span": 0.65,
			"pattern_recognition": 0.75,
			"emotional_filter": 0.6,
			"reactivity": 0.7,
			"recovery_rate": 0.6,
			"emotional_memory_link": 0.85,
			"identity_drift": 0.1,
			"fusion_susceptibility": 0.3,
			"fragmentation_threshold": 0.6,
			"self_repair_rate": 0.4,
			"learning_rate": 0.7,
			"adaptation_speed": 0.6,
			"discipline": 0.8,
			"habit_strength": 0.7,
			"social_adaptability": 0.6,
			"trust_baseline": 0.4,
			"loyalty_strength": 0.85,
			"status_sensitivity": 0.6,
			"existential_stability": 0.7
		}

	return {
		"self_awareness": 0.86,
		"meta_cognition": 0.82,
		"memory_retention": 0.78,
		"memory_decay": 0.12,
		"identity_stability": 0.78,
		"ego_strength": 0.84,
		"adaptability": 0.42,
		"decision_style": "pattern_weighted",
		"impulse_control": 0.78,
		"delayed_gratification": 0.82,
		"attention_span": 0.58,
		"pattern_recognition": 0.9,
		"emotional_filter": 0.72,
		"reactivity": 0.55,
		"recovery_rate": 0.42,
		"emotional_memory_link": 0.92,
		"identity_drift": 0.08,
		"fusion_susceptibility": 0.22,
		"fragmentation_threshold": 0.62,
		"self_repair_rate": 0.28,
		"learning_rate": 0.42,
		"adaptation_speed": 0.36,
		"discipline": 0.86,
		"habit_strength": 0.86,
		"social_adaptability": 0.42,
		"trust_baseline": 0.35,
		"loyalty_strength": 0.9,
		"status_sensitivity": 0.45,
		"existential_stability": 0.78
	}

func _apply_life_stage_growth(contract: Dictionary, person: Person, _context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	out ["life_stage"] = _life_stage_for_age(int(person.age))
	out ["body_anchor"] = "alive" if bool(person.alive) else "dead"
	return out

func _apply_reality_mode_adjustments(contract: Dictionary, _person: Person, _context: Dictionary = {}) -> Dictionary:
	if gs == null:
		return contract

	var out: Dictionary = contract.duplicate(true)
	var mode: String = str(gs.reality_mode if "reality_mode" in gs else "realistic").strip_edges().to_lower()

	if mode in ["enhanced", "chaos", "fantasy"]:
		var awareness: Dictionary = _safe_dictionary(out.get("awareness", {}))
		var continuity: Dictionary = _safe_dictionary(out.get("continuity", {}))
		awareness ["reality_awareness"] = clamp(float(awareness.get("reality_awareness", 0.05)) + 0.08, 0.0, 1.0)
		continuity ["fragmentation_threshold"] = clamp(float(continuity.get("fragmentation_threshold", 0.6)) + 0.08, 0.0, 1.0)
		out ["awareness"] = awareness
		out ["continuity"] = continuity

	return out

func _apply_trait_adjustments(contract: Dictionary, person: Person, _context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	var traits: Array = _safe_array(person.traits)

	for raw_trait in traits:
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text == "":
			continue

		if trait_text.find("immortal") >= 0 or trait_text.find("vampire") >= 0:
			var memory_rules: Dictionary = _safe_dictionary(out.get("memory", {}))
			var continuity: Dictionary = _safe_dictionary(out.get("continuity", {}))
			var awareness: Dictionary = _safe_dictionary(out.get("awareness", {}))
			var emotion_system: Dictionary = _safe_dictionary(out.get("emotion_system", {}))

			memory_rules ["decay_rate"] = min(float(memory_rules.get("decay_rate", 0.05)), 0.02)
			memory_rules ["retention"] = clamp(float(memory_rules.get("retention", 0.7)) + 0.12, 0.0, 1.0)
			memory_rules ["memory_bias"] = "long_life_emotion_weighted"

			continuity ["cross_universe_memory"] = true
			continuity ["identity_drift"] = clamp(float(continuity.get("identity_drift", 0.1)) + 0.03, 0.0, 1.0)
			continuity ["fragmentation_threshold"] = clamp(float(continuity.get("fragmentation_threshold", 0.6)) + 0.08, 0.0, 1.0)

			awareness ["mortality_awareness"] = 1.0
			awareness ["time_depth_awareness"] = clamp(float(awareness.get("time_depth_awareness", 0.0)) + 0.35, 0.0, 1.0)

			emotion_system ["emotional_memory_link"] = clamp(float(emotion_system.get("emotional_memory_link", 0.6)) + 0.08, 0.0, 1.5)

			out ["memory"] = memory_rules
			out ["continuity"] = continuity
			out ["awareness"] = awareness
			out ["emotion_system"] = emotion_system

		if trait_text.find("vampire") >= 0:
			var behavioral_patterns: Dictionary = _safe_dictionary(out.get("behavioral_patterns", {}))
			var social_model: Dictionary = _safe_dictionary(out.get("social_model", {}))
			var perception: Dictionary = _safe_dictionary(out.get("perception", {}))

			behavioral_patterns ["hunger_loop_susceptibility"] = clamp(float(behavioral_patterns.get("hunger_loop_susceptibility", 0.0)) + 0.45, 0.0, 1.0)
			behavioral_patterns ["predatory_control"] = clamp(float(behavioral_patterns.get("predatory_control", 0.4)) - 0.08, 0.0, 1.0)

			social_model ["attachment_style"] = "possessive_adaptive"
			social_model ["loyalty_strength"] = clamp(float(social_model.get("loyalty_strength", 0.6)) + 0.1, 0.0, 1.0)

			perception ["threat_detection"] = clamp(float(perception.get("threat_detection", 0.5)) + 0.12, 0.0, 1.0)
			perception ["prey_pattern_recognition"] = clamp(float(perception.get("prey_pattern_recognition", 0.0)) + 0.35, 0.0, 1.0)

			out ["behavioral_patterns"] = behavioral_patterns
			out ["social_model"] = social_model
			out ["perception"] = perception

		if trait_text.find("reckless") >= 0:
			var decision: Dictionary = _safe_dictionary(out.get("decision_engine", {}))
			var emotion_reckless: Dictionary = _safe_dictionary(out.get("emotion_system", {}))

			decision ["risk_tolerance"] = clamp(float(decision.get("risk_tolerance", 0.4)) + 0.2, 0.0, 1.0)
			decision ["impulse_control"] = clamp(float(decision.get("impulse_control", 0.5)) - 0.15, 0.0, 1.0)
			decision ["decision_style"] = "high_risk_contextual"

			emotion_reckless ["reactivity"] = clamp(float(emotion_reckless.get("reactivity", 0.6)) + 0.08, 0.0, 1.2)

			out ["decision_engine"] = decision
			out ["emotion_system"] = emotion_reckless

		if trait_text.find("faith") >= 0 or trait_text.find("spiritual") >= 0 or trait_text.find("devout") >= 0:
			var belief_system: Dictionary = _safe_dictionary(out.get("belief_system", {}))
			var identity: Dictionary = _safe_dictionary(out.get("identity", {}))
			var value_system: Dictionary = _safe_dictionary(identity.get("value_system", {}))
			var moral_axis: Array = _safe_array(value_system.get("moral_axis", []))

			if "faith" not in moral_axis:
				moral_axis.push_front("faith")
			if "meaning" not in moral_axis:
				moral_axis.append("meaning")

			belief_system ["faith_level"] = clamp(float(belief_system.get("faith_level", 0.4)) + 0.25, 0.0, 1.0)
			belief_system ["meaning_seeking"] = clamp(float(belief_system.get("meaning_seeking", 0.5)) + 0.15, 0.0, 1.0)
			belief_system ["existential_stability"] = clamp(float(belief_system.get("existential_stability", 0.5)) + 0.12, 0.0, 1.0)

			value_system ["moral_axis"] = moral_axis
			identity ["value_system"] = value_system

			out ["belief_system"] = belief_system
			out ["identity"] = identity

	return out

func _apply_fantasy_adjustments(contract: Dictionary, person: Person, _context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	var traits: Array = _safe_array(person.traits)
	var bending_type: String = str(person.bending_type).strip_edges().to_lower()
	var is_avatar: bool = bending_type == "avatar" or bool(person.avatar_state_unlocked)

	if is_avatar:
		var awareness: Dictionary = _safe_dictionary(out.get("awareness", {}))
		var belief: Dictionary = _safe_dictionary(out.get("belief_system", {}))
		var continuity: Dictionary = _safe_dictionary(out.get("continuity", {}))
		var perception: Dictionary = _safe_dictionary(out.get("perception", {}))

		awareness ["reality_awareness"] = clamp(float(awareness.get("reality_awareness", 0.1)) + 0.12, 0.0, 1.0)
		awareness ["elemental_awareness"] = clamp(float(awareness.get("elemental_awareness", 0.0)) + 0.35, 0.0, 1.0)
		belief ["meaning_seeking"] = clamp(float(belief.get("meaning_seeking", 0.6)) + 0.1, 0.0, 1.0)
		continuity ["avatar_identity_pressure"] = clamp(float(continuity.get("avatar_identity_pressure", 0.0)) + 0.18, 0.0, 1.0)
		perception ["elemental_pattern_recognition"] = clamp(float(perception.get("elemental_pattern_recognition", 0.0)) + 0.28, 0.0, 1.0)

		out ["awareness"] = awareness
		out ["belief_system"] = belief
		out ["continuity"] = continuity
		out ["perception"] = perception

	for raw_trait in traits:
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text == "":
			continue

		if trait_text.find("wizard") >= 0 or trait_text.find("witch") >= 0 or trait_text.find("mage") >= 0:
			out = _apply_magic_consciousness_profile(out, "wizard_lineage", 0.35)

		if trait_text.find("fairy") >= 0 or trait_text.find("fae") >= 0:
			out = _apply_magic_consciousness_profile(out, "fae_binding", 0.45)

		if trait_text.find("ogre") >= 0 or trait_text.find("giant") >= 0:
			out = _apply_magic_consciousness_profile(out, "giant_scale_mind", 0.25)

		if trait_text.find("cursed") >= 0 or trait_text.find("hexed") >= 0:
			out = _apply_magic_consciousness_profile(out, "curse_pressure", 0.5)

		if trait_text.find("reality-touched") >= 0 or trait_text.find("cosmic") >= 0:
			out = _apply_magic_consciousness_profile(out, "cosmic_reality_touch", 0.6)

	return out
func _apply_consciousness_archetype_adjustments(contract: Dictionary, person: Person, context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	var archetype: Dictionary = _safe_dictionary(out.get("archetype", {}))
	var traits: Array = _safe_array(person.traits)
	var context_type: String = str(context.get("consciousness_type", "")).strip_edges().to_lower()

	if archetype.is_empty():
		archetype = {
			"type": "human",
			"subtype": "ordinary",
			"origin": "birth",
			"body_dependency": "normal",
			"mind_anchor": "brain"
		}

	for raw_trait in traits:
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text == "":
			continue

		if trait_text.find("vampire") >= 0:
			archetype ["type"] = "undead"
			archetype ["subtype"] = "vampire"
			archetype ["body_dependency"] = "blood_anchor"
			archetype ["mind_anchor"] = "bloodline_memory"

		elif trait_text.find("immortal") >= 0:
			archetype ["type"] = "immortal"
			archetype ["subtype"] = "long_lived"
			archetype ["body_dependency"] = "persistent_body"
			archetype ["mind_anchor"] = "accumulated_identity"

		elif trait_text.find("wizard") >= 0 or trait_text.find("witch") >= 0 or trait_text.find("mage") >= 0:
			archetype ["type"] = "magical"
			archetype ["subtype"] = "wizard"
			archetype ["mind_anchor"] = "spell_knowledge"

		elif trait_text.find("fairy") >= 0 or trait_text.find("fae") >= 0:
			archetype ["type"] = "fae"
			archetype ["subtype"] = "contractual_trickster"
			archetype ["mind_anchor"] = "names_and_promises"

		elif trait_text.find("ogre") >= 0:
			archetype ["type"] = "giantkin"
			archetype ["subtype"] = "ogre"
			archetype ["mind_anchor"] = "appetite_and_territory"

		elif trait_text.find("giant") >= 0:
			archetype ["type"] = "giantkin"
			archetype ["subtype"] = "giant"
			archetype ["mind_anchor"] = "scale_and_domain"

		elif trait_text.find("construct") >= 0 or trait_text.find("golem") >= 0 or trait_text.find("robot") >= 0:
			archetype ["type"] = "constructed"
			archetype ["subtype"] = "synthetic"
			archetype ["body_dependency"] = "core_directive"
			archetype ["mind_anchor"] = "command_lattice"

		elif trait_text.find("ghost") >= 0 or trait_text.find("spirit") >= 0:
			archetype ["type"] = "spiritual"
			archetype ["subtype"] = "disembodied"
			archetype ["body_dependency"] = "none"
			archetype ["mind_anchor"] = "memory_residue"

	if context_type != "":
		archetype ["type"] = context_type

	out ["archetype"] = archetype
	return out

func _apply_contractual_consciousness_pressure(contract: Dictionary, person: Person, context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	var pressure_state: Dictionary = _safe_dictionary(out.get("pressure_state", {}))
	var active_contracts: Array = _safe_array(context.get("active_contracts", []))
	var action_context: String = str(context.get("source", "")).strip_edges().to_lower()

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		var world_contracts_raw: Variant = gs.scenario_state.get("active_contracts", [])
		if typeof(world_contracts_raw) == TYPE_ARRAY:
			for raw_contract in world_contracts_raw:
				active_contracts.append(raw_contract)

	for raw_contract in active_contracts:
		if typeof(raw_contract) != TYPE_DICTIONARY:
			continue

		var contract_row: Dictionary = raw_contract
		var contract_id: String = str(contract_row.get("id", contract_row.get("contract_id", ""))).strip_edges().to_lower()
		var consciousness_effects: Dictionary = _safe_dictionary(contract_row.get("consciousness_effects", {}))

		if contract_id == "":
			continue

		if contract_id.find("rumpel") >= 0:
			pressure_state ["debt_dread"] = clamp(float(pressure_state.get("debt_dread", 0.0)) + float(consciousness_effects.get("fear_bias", 1.0)) * 0.08, 0.0, 1.0)
			pressure_state ["bargain_guilt"] = clamp(float(pressure_state.get("bargain_guilt", 0.0)) + float(consciousness_effects.get("guilt_weight", 1.0)) * 0.08, 0.0, 1.0)
			pressure_state ["obsession_loop"] = clamp(float(pressure_state.get("obsession_loop", 0.0)) + float(consciousness_effects.get("obsession_loop", 0.0)) * 0.1, 0.0, 1.0)

		elif contract_id.find("monkey") >= 0 or contract_id.find("paw") >= 0:
			pressure_state ["wish_paranoia"] = clamp(float(pressure_state.get("wish_paranoia", 0.0)) + 0.18, 0.0, 1.0)
			pressure_state ["desire_fear"] = clamp(float(pressure_state.get("desire_fear", 0.0)) + 0.12, 0.0, 1.0)

		elif contract_id.find("wizard") >= 0:
			pressure_state ["family_trial_pressure"] = clamp(float(pressure_state.get("family_trial_pressure", 0.0)) + float(consciousness_effects.get("pressure", 1.0)) * 0.08, 0.0, 1.0)
			pressure_state ["sibling_rivalry"] = clamp(float(pressure_state.get("sibling_rivalry", 0.0)) + float(consciousness_effects.get("sibling_rivalry", 1.0)) * 0.08, 0.0, 1.0)
			pressure_state ["fear_of_failure"] = clamp(float(pressure_state.get("fear_of_failure", 0.0)) + float(consciousness_effects.get("fear_of_failure", 1.0)) * 0.08, 0.0, 1.0)

	if action_context.find("crime") >= 0 or action_context.find("investigation") >= 0:
		pressure_state ["legal_pressure"] = clamp(float(pressure_state.get("legal_pressure", 0.0)) + 0.12, 0.0, 1.0)

	if not pressure_state.is_empty():
		out ["pressure_state"] = pressure_state
		out = _apply_pressure_state_to_consciousness(out, pressure_state, person)

	return out

func _apply_status_and_role_adjustments(contract: Dictionary, person: Person, context: Dictionary = {}) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	var role_text: String = str(context.get("role", context.get("social_role", ""))).strip_edges().to_lower()
	var title_text: String = ""

	if "title" in person:
		title_text = str(person.title).strip_edges().to_lower()
	elif "royal_title" in person:
		title_text = str(person.royal_title).strip_edges().to_lower()

	if role_text == "":
		role_text = title_text

	if role_text.find("king") >= 0 or role_text.find("queen") >= 0 or role_text.find("duke") >= 0 or role_text.find("duchess") >= 0 or role_text.find("lord") >= 0 or role_text.find("lady") >= 0:
		var social_model: Dictionary = _safe_dictionary(out.get("social_model", {}))
		var identity: Dictionary = _safe_dictionary(out.get("identity", {}))
		var pressure_state: Dictionary = _safe_dictionary(out.get("pressure_state", {}))

		identity ["public_self_pressure"] = clamp(float(identity.get("public_self_pressure", 0.0)) + 0.18, 0.0, 1.0)
		social_model ["status_sensitivity"] = clamp(float(social_model.get("status_sensitivity", 0.5)) + 0.18, 0.0, 1.0)
		pressure_state ["dynasty_pressure"] = clamp(float(pressure_state.get("dynasty_pressure", 0.0)) + 0.16, 0.0, 1.0)

		out ["identity"] = identity
		out ["social_model"] = social_model
		out ["pressure_state"] = pressure_state

	return out

func _apply_magic_consciousness_profile(contract: Dictionary, profile_id: String, intensity: float = 0.25) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	var awareness: Dictionary = _safe_dictionary(out.get("awareness", {}))
	var perception: Dictionary = _safe_dictionary(out.get("perception", {}))
	var memory: Dictionary = _safe_dictionary(out.get("memory", {}))
	var decision: Dictionary = _safe_dictionary(out.get("decision_engine", {}))
	var continuity: Dictionary = _safe_dictionary(out.get("continuity", {}))
	var belief: Dictionary = _safe_dictionary(out.get("belief_system", {}))

	var clean_profile: String = str(profile_id).strip_edges().to_lower()
	var amount: float = clamp(float(intensity), 0.0, 2.0)

	match clean_profile:
		"wizard_lineage":
			awareness ["magical_awareness"] = clamp(float(awareness.get("magical_awareness", 0.0)) + amount, 0.0, 1.0)
			perception ["spell_pattern_recognition"] = clamp(float(perception.get("spell_pattern_recognition", 0.0)) + amount, 0.0, 1.0)
			memory ["knowledge_encoding"] = "spell_theory_weighted"
			decision ["delayed_gratification"] = clamp(float(decision.get("delayed_gratification", 0.5)) + amount * 0.2, 0.0, 1.0)

		"fae_binding":
			awareness ["name_power_awareness"] = clamp(float(awareness.get("name_power_awareness", 0.0)) + amount, 0.0, 1.0)
			perception ["promise_detection"] = clamp(float(perception.get("promise_detection", 0.0)) + amount, 0.0, 1.0)
			memory ["memory_bias"] = "promise_weighted"
			decision ["risk_tolerance"] = clamp(float(decision.get("risk_tolerance", 0.4)) + amount * 0.1, 0.0, 1.0)

		"giant_scale_mind":
			perception ["scale_awareness"] = clamp(float(perception.get("scale_awareness", 0.0)) + amount, 0.0, 1.0)
			decision ["impulse_control"] = clamp(float(decision.get("impulse_control", 0.5)) - amount * 0.08, 0.0, 1.0)
			belief ["territorial_certainty"] = clamp(float(belief.get("territorial_certainty", 0.0)) + amount, 0.0, 1.0)

		"curse_pressure":
			continuity ["identity_drift"] = clamp(float(continuity.get("identity_drift", 0.1)) + amount * 0.12, 0.0, 1.0)
			memory ["trauma_weight"] = clamp(float(memory.get("trauma_weight", 1.4)) + amount * 0.2, 0.0, 3.0)
			awareness ["curse_awareness"] = clamp(float(awareness.get("curse_awareness", 0.0)) + amount, 0.0, 1.0)

		"cosmic_reality_touch":
			awareness ["reality_awareness"] = clamp(float(awareness.get("reality_awareness", 0.1)) + amount * 0.2, 0.0, 1.0)
			awareness ["multiverse_awareness"] = clamp(float(awareness.get("multiverse_awareness", 0.05)) + amount * 0.16, 0.0, 1.0)
			continuity ["fragmentation_threshold"] = clamp(float(continuity.get("fragmentation_threshold", 0.6)) + amount * 0.1, 0.0, 1.0)
			memory ["cross_universe_indexing"] = true

	out ["awareness"] = awareness
	out ["perception"] = perception
	out ["memory"] = memory
	out ["decision_engine"] = decision
	out ["continuity"] = continuity
	out ["belief_system"] = belief
	return out

func _apply_pressure_state_to_consciousness(contract: Dictionary, pressure_state: Dictionary, _person: Person) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)
	var emotion_system: Dictionary = _safe_dictionary(out.get("emotion_system", {}))
	var perception: Dictionary = _safe_dictionary(out.get("perception", {}))
	var decision: Dictionary = _safe_dictionary(out.get("decision_engine", {}))
	var continuity: Dictionary = _safe_dictionary(out.get("continuity", {}))
	var memory: Dictionary = _safe_dictionary(out.get("memory", {}))

	var pressure_load: float = _calculate_pressure_load(pressure_state)

	if pressure_load > 0.0:
		emotion_system ["reactivity"] = clamp(float(emotion_system.get("reactivity", 0.6)) + pressure_load * 0.08, 0.0, 1.5)
		perception ["threat_detection"] = clamp(float(perception.get("threat_detection", 0.5)) + pressure_load * 0.08, 0.0, 1.0)
		decision ["impulse_control"] = clamp(float(decision.get("impulse_control", 0.5)) - pressure_load * 0.04, 0.0, 1.0)
		continuity ["identity_drift"] = clamp(float(continuity.get("identity_drift", 0.1)) + pressure_load * 0.03, 0.0, 1.0)
		memory ["trauma_weight"] = clamp(float(memory.get("trauma_weight", 1.4)) + pressure_load * 0.08, 0.0, 3.0)

	out ["emotion_system"] = emotion_system
	out ["perception"] = perception
	out ["decision_engine"] = decision
	out ["continuity"] = continuity
	out ["memory"] = memory
	return out

func _normalize_consciousness_contract(contract: Dictionary) -> Dictionary:
	var out: Dictionary = contract.duplicate(true)

	var identity: Dictionary = _safe_dictionary(out.get("identity", {}))
	var memory: Dictionary = _safe_dictionary(out.get("memory", {}))
	var perception: Dictionary = _safe_dictionary(out.get("perception", {}))
	var emotion_system: Dictionary = _safe_dictionary(out.get("emotion_system", {}))
	var decision: Dictionary = _safe_dictionary(out.get("decision_engine", {}))
	var behavioral: Dictionary = _safe_dictionary(out.get("behavioral_patterns", {}))
	var continuity: Dictionary = _safe_dictionary(out.get("continuity", {}))
	var belief: Dictionary = _safe_dictionary(out.get("belief_system", {}))
	var awareness: Dictionary = _safe_dictionary(out.get("awareness", {}))
	var social: Dictionary = _safe_dictionary(out.get("social_model", {}))
	var learning: Dictionary = _safe_dictionary(out.get("learning_engine", {}))

	identity ["ego_strength"] = clamp(float(identity.get("ego_strength", 0.5)), 0.0, 1.5)
	identity ["adaptability"] = clamp(float(identity.get("adaptability", 0.5)), 0.0, 1.5)
	identity ["self_image_stability"] = clamp(float(identity.get("self_image_stability", 0.5)), 0.0, 1.5)

	memory ["retention"] = clamp(float(memory.get("retention", 0.5)), 0.0, 1.0)
	memory ["decay_rate"] = clamp(float(memory.get("decay_rate", 0.05)), 0.0, 1.0)
	memory ["trauma_weight"] = clamp(float(memory.get("trauma_weight", 1.4)), 0.0, 3.0)
	memory ["joy_weight"] = clamp(float(memory.get("joy_weight", 1.2)), 0.0, 3.0)

	perception ["pattern_recognition"] = clamp(float(perception.get("pattern_recognition", 0.5)), 0.0, 1.5)
	perception ["emotional_filter"] = clamp(float(perception.get("emotional_filter", 0.5)), 0.0, 1.5)
	perception ["attention_span"] = clamp(float(perception.get("attention_span", 0.5)), 0.0, 1.5)
	perception ["threat_detection"] = clamp(float(perception.get("threat_detection", 0.5)), 0.0, 1.5)
	perception ["optimism_bias"] = clamp(float(perception.get("optimism_bias", 0.4)), -1.0, 1.0)

	emotion_system ["baseline_mood"] = clamp(float(emotion_system.get("baseline_mood", 0.5)), -1.0, 1.0)
	emotion_system ["reactivity"] = clamp(float(emotion_system.get("reactivity", 0.6)), 0.0, 2.0)
	emotion_system ["recovery_rate"] = clamp(float(emotion_system.get("recovery_rate", 0.5)), 0.0, 1.5)
	emotion_system ["emotional_memory_link"] = clamp(float(emotion_system.get("emotional_memory_link", 0.6)), 0.0, 2.0)

	decision ["risk_tolerance"] = clamp(float(decision.get("risk_tolerance", 0.4)), 0.0, 1.5)
	decision ["impulse_control"] = clamp(float(decision.get("impulse_control", 0.5)), 0.0, 1.5)
	decision ["delayed_gratification"] = clamp(float(decision.get("delayed_gratification", 0.5)), 0.0, 1.5)

	behavioral ["habit_strength"] = clamp(float(behavioral.get("habit_strength", 0.5)), 0.0, 1.5)
	behavioral ["addiction_susceptibility"] = clamp(float(behavioral.get("addiction_susceptibility", 0.3)), 0.0, 1.5)
	behavioral ["discipline"] = clamp(float(behavioral.get("discipline", 0.5)), 0.0, 1.5)
	behavioral ["social_adaptability"] = clamp(float(behavioral.get("social_adaptability", 0.5)), 0.0, 1.5)

	continuity ["identity_drift"] = clamp(float(continuity.get("identity_drift", 0.1)), 0.0, 1.0)
	continuity ["fusion_susceptibility"] = clamp(float(continuity.get("fusion_susceptibility", 0.3)), 0.0, 1.0)
	continuity ["fragmentation_threshold"] = clamp(float(continuity.get("fragmentation_threshold", 0.6)), 0.05, 1.5)
	continuity ["self_repair_rate"] = clamp(float(continuity.get("self_repair_rate", 0.4)), 0.0, 1.5)

	belief ["faith_level"] = clamp(float(belief.get("faith_level", 0.4)), 0.0, 1.0)
	belief ["meaning_seeking"] = clamp(float(belief.get("meaning_seeking", 0.5)), 0.0, 1.0)
	belief ["existential_stability"] = clamp(float(belief.get("existential_stability", 0.5)), 0.0, 1.5)

	awareness ["self_awareness"] = clamp(float(awareness.get("self_awareness", 0.5)), 0.0, 1.5)
	awareness ["meta_cognition"] = clamp(float(awareness.get("meta_cognition", 0.4)), 0.0, 1.5)
	awareness ["reality_awareness"] = clamp(float(awareness.get("reality_awareness", 0.05)), 0.0, 1.0)
	awareness ["multiverse_awareness"] = clamp(float(awareness.get("multiverse_awareness", 0.0)), 0.0, 1.0)

	social ["trust_baseline"] = clamp(float(social.get("trust_baseline", 0.5)), 0.0, 1.0)
	social ["loyalty_strength"] = clamp(float(social.get("loyalty_strength", 0.6)), 0.0, 1.5)
	social ["status_sensitivity"] = clamp(float(social.get("status_sensitivity", 0.5)), 0.0, 1.5)

	learning ["learning_rate"] = clamp(float(learning.get("learning_rate", 0.6)), 0.0, 1.5)
	learning ["adaptation_speed"] = clamp(float(learning.get("adaptation_speed", 0.6)), 0.0, 1.5)

	out ["identity"] = identity
	out ["memory"] = memory
	out ["perception"] = perception
	out ["emotion_system"] = emotion_system
	out ["decision_engine"] = decision
	out ["behavioral_patterns"] = behavioral
	out ["continuity"] = continuity
	out ["belief_system"] = belief
	out ["awareness"] = awareness
	out ["social_model"] = social
	out ["learning_engine"] = learning

	return _make_binary_safe(out)

func _calculate_emotional_load(memory_index: Array, emotion_system: Dictionary) -> float:
	if memory_index.is_empty():
		return 0.0

	var total: float = 0.0
	var counted: int = 0
	var max_scan: int = min(memory_index.size(), 25)

	for i in range(memory_index.size() - max_scan, memory_index.size()):
		var raw_memory: Variant = memory_index [i]
		if typeof(raw_memory) != TYPE_DICTIONARY:
			continue

		var memory_row: Dictionary = raw_memory
		total += clamp(float(memory_row.get("emotional_weight", memory_row.get("salience", 1.0))), 0.0, 3.0)
		counted += 1

	if counted <= 0:
		return 0.0

	var reactivity: float = float(emotion_system.get("reactivity", 0.6))
	return clamp((total / float(counted)) * reactivity * 0.35, 0.0, 1.0)

func _calculate_pressure_load(pressure_state: Dictionary) -> float:
	if pressure_state.is_empty():
		return 0.0

	var total: float = 0.0
	var counted: int = 0

	for raw_key in pressure_state.keys():
		var value: Variant = pressure_state.get(raw_key)
		if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
			total += clamp(float(value), 0.0, 1.0)
			counted += 1

	if counted <= 0:
		return 0.0

	return clamp(total / float(counted), 0.0, 1.0)
func _apply_soul_seed_contract(contract: Dictionary, person: Person, context: Dictionary = {}) -> Dictionary:
	if person == null:
		return contract

	var soul_seed: Dictionary = {}

	if typeof(person.soul_seed_contract) == TYPE_DICTIONARY and not person.soul_seed_contract.is_empty():
		soul_seed = person.soul_seed_contract.duplicate(true)
	elif gs != null and gs.soul_seed_engine != null and gs.soul_seed_engine.has_method("ensure_soul_seed"):
		soul_seed = gs.soul_seed_engine.ensure_soul_seed(person, {
			"source": str(context.get("source", "consciousness_needs_soul_seed")),
			"world_seed": context.get("world_seed", -1),
			"role": context.get("role", "npc"),
		})

	if soul_seed.is_empty():
		return contract

	var out: Dictionary = contract.duplicate(true)
	var core: Dictionary = _safe_dictionary(soul_seed.get("core_identity", {}))
	var personality: Dictionary = _safe_dictionary(core.get("personality_vector", {}))
	var emotional_profile: Dictionary = _safe_dictionary(core.get("emotional_profile", {}))
	var decision_bias: Dictionary = _safe_dictionary(core.get("decision_bias", {}))
	var behavioral_curves: Dictionary = _safe_dictionary(soul_seed.get("behavioral_curves", {}))
	var destiny_pressure: Dictionary = _safe_dictionary(soul_seed.get("destiny_pressure", {}))

	var identity: Dictionary = _safe_dictionary(out.get("identity", {}))
	identity ["soul_seed_id"] = str(soul_seed.get("soul_seed_id", ""))
	identity ["soul_personality_vector"] = personality.duplicate(true)
	identity ["adaptability"] = clamp(
		(float(identity.get("adaptability", 0.5)) * 0.55) + (float(core.get("adaptability", 0.5)) * 0.45),
		0.0,
		1.5
	)
	identity ["core_self"] = "soul_seeded_persistent"
	out ["identity"] = identity

	var memory: Dictionary = _safe_dictionary(out.get("memory", {}))
	memory ["memory_bias"] = str(core.get("memory_bias", memory.get("memory_bias", "emotion_weighted")))
	out ["memory"] = memory

	var emotion_system: Dictionary = _safe_dictionary(out.get("emotion_system", {}))
	emotion_system ["soul_emotional_profile"] = emotional_profile.duplicate(true)
	emotion_system ["reactivity"] = clamp(
		(float(emotion_system.get("reactivity", 0.6)) * 0.65) + (float(emotional_profile.get("reactivity", 0.6)) * 0.35),
		0.0,
		2.0
	)
	emotion_system ["recovery_rate"] = clamp(
		(float(emotion_system.get("recovery_rate", 0.5)) * 0.65) + (float(emotional_profile.get("recovery_rate", 0.5)) * 0.35),
		0.0,
		1.5
	)
	out ["emotion_system"] = emotion_system

	var decision: Dictionary = _safe_dictionary(out.get("decision_engine", {}))
	decision ["soul_decision_bias"] = decision_bias.duplicate(true)
	decision ["risk_tolerance"] = clamp(
		(float(decision.get("risk_tolerance", 0.4)) * 0.6) + (float(decision_bias.get("risk_weight", 0.5)) * 0.4),
		0.0,
		1.5
	)
	decision ["impulse_control"] = clamp(
		(float(decision.get("impulse_control", 0.5)) * 0.65) + ((1.0 - float(decision_bias.get("impulse_weight", 0.5))) * 0.35),
		0.0,
		1.5
	)
	out ["decision_engine"] = decision

	var behavioral: Dictionary = _safe_dictionary(out.get("behavioral_patterns", {}))
	behavioral ["soul_behavioral_curves"] = behavioral_curves.duplicate(true)
	behavioral ["discipline"] = clamp(
		(float(behavioral.get("discipline", 0.5)) * 0.65) + ((1.0 - float(behavioral_curves.get("impulse_curve", 0.5))) * 0.35),
		0.0,
		1.5
	)
	out ["behavioral_patterns"] = behavioral

	var social: Dictionary = _safe_dictionary(out.get("social_model", {}))
	social ["loyalty_strength"] = clamp(
		(float(social.get("loyalty_strength", 0.6)) * 0.55) + (float(behavioral_curves.get("loyalty_curve", 0.6)) * 0.45),
		0.0,
		1.5
	)
	out ["social_model"] = social

	var learning: Dictionary = _safe_dictionary(out.get("learning_engine", {}))
	learning ["adaptation_speed"] = clamp(
		(float(learning.get("adaptation_speed", 0.6)) * 0.55) + (float(behavioral_curves.get("adaptation_curve", 0.6)) * 0.45),
		0.0,
		1.5
	)
	out ["learning_engine"] = learning

	var pressure_state: Dictionary = _safe_dictionary(out.get("pressure_state", {}))
	pressure_state ["destiny_pressure"] = float(destiny_pressure.get("weight", 0.0))
	pressure_state ["destiny_domains"] = destiny_pressure.get("domains", []) if typeof(destiny_pressure.get("domains", [])) == TYPE_ARRAY else []
	out ["pressure_state"] = pressure_state

	out ["soul_seed"] = soul_seed.duplicate(true)
	return _make_binary_safe(out)
func _resolve_consciousness_contract(contract: Dictionary, person: Person, context: Dictionary = {}) -> Dictionary:
	var base: Dictionary = _default_consciousness_contract(person, context)
	var out: Dictionary = _merge_dict(base, contract)
	out ["schema"] = CONSCIOUSNESS_SCHEMA
	out ["version"] = CONSCIOUSNESS_VERSION
	return _make_binary_safe(out)

func _build_consciousness_state(person: Person, contract: Dictionary, context: Dictionary = {}) -> Dictionary:
	var identity: Dictionary = _safe_dictionary(contract.get("identity", {}))
	var memory: Dictionary = _safe_dictionary(contract.get("memory", {}))
	var perception: Dictionary = _safe_dictionary(contract.get("perception", {}))
	var emotion_system: Dictionary = _safe_dictionary(contract.get("emotion_system", {}))
	var decision_engine: Dictionary = _safe_dictionary(contract.get("decision_engine", {}))
	var continuity: Dictionary = _safe_dictionary(contract.get("continuity", {}))
	var belief_system: Dictionary = _safe_dictionary(contract.get("belief_system", {}))
	var awareness: Dictionary = _safe_dictionary(contract.get("awareness", {}))
	var social_model: Dictionary = _safe_dictionary(contract.get("social_model", {}))
	var learning_engine: Dictionary = _safe_dictionary(contract.get("learning_engine", {}))
	var pressure_state: Dictionary = _safe_dictionary(contract.get("pressure_state", {}))
	var archetype: Dictionary = _safe_dictionary(contract.get("archetype", {}))

	var memory_index: Array = _safe_array(person.consciousness_memory_index)
	var fragmentation_threshold: float = max(0.01, float(continuity.get("fragmentation_threshold", 0.6)))
	var fragmentation: float = clamp(float(continuity.get("identity_drift", 0.0)) / fragmentation_threshold, 0.0, 2.0)
	var emotional_load: float = _calculate_emotional_load(memory_index, emotion_system)
	var pressure_load: float = _calculate_pressure_load(pressure_state)
	var coherence: float = clamp(
		float(identity.get("self_image_stability", 0.5))
		+ float(continuity.get("self_repair_rate", 0.4)) * 0.25
		- fragmentation * 0.25
		- emotional_load * 0.08
		- pressure_load * 0.08,
		0.0,
		1.0
	)

	return _make_binary_safe({
		"schema": "eralife.consciousness_state",
		"version": CONSCIOUSNESS_VERSION,
		"person_id": int(person.id),
		"person_name": _person_name(person),
		"life_stage": _life_stage_for_age(int(person.age)),
		"body_alive": bool(person.alive),
		"body_anchor": str(contract.get("body_anchor", "alive" if bool(person.alive) else "dead")),
		"memory_count": memory_index.size(),
		"core_self": str(identity.get("core_self", "persistent")),
		"consciousness_type": str(archetype.get("type", "human")),
		"consciousness_subtype": str(archetype.get("subtype", "ordinary")),
		"identity_stability": float(identity.get("self_image_stability", 0.5)),
		"identity_coherence": coherence,
		"fragmentation_pressure": fragmentation,
		"emotional_load": emotional_load,
		"pressure_load": pressure_load,
		"pure_consciousness": bool(continuity.get("pure_consciousness", false)),
		"cross_universe_memory": bool(continuity.get("cross_universe_memory", false)),
		"memory_retention": float(memory.get("retention", 0.5)),
		"memory_decay_rate": float(memory.get("decay_rate", 0.05)),
		"perception_biases": _safe_array(perception.get("biases", [])),
		"decision_style": str(decision_engine.get("decision_style", "weighted_contextual")),
		"dominant_emotions": _safe_array(emotion_system.get("dominant_emotions", [])),
		"faith_level": float(belief_system.get("faith_level", 0.0)),
		"reality_awareness": float(awareness.get("reality_awareness", 0.0)),
		"multiverse_awareness": float(awareness.get("multiverse_awareness", 0.0)),
		"attachment_style": str(social_model.get("attachment_style", "adaptive")),
		"learning_rate": float(learning_engine.get("learning_rate", 0.5)),
		"last_context_source": str(context.get("source", "unknown")),
		"updated_at_year": _current_year(),
		"updated_at_ms": int(Time.get_ticks_msec())
	})

func _person_consciousness_contract(person: Person) -> Dictionary:
	if person == null:
		return {}
	if typeof(person.consciousness_contract) == TYPE_DICTIONARY:
		return person.consciousness_contract.duplicate(true)
	return {}

func _life_stage_for_age(age_value: int) -> String:
	if age_value <= 3:
		return "infant"
	if age_value <= 12:
		return "child"
	if age_value <= 17:
		return "teen"
	if age_value <= 64:
		return "adult"
	return "elder"

func _memory_emotional_weight(text: String, context: Dictionary, trauma_weight: float, joy_weight: float) -> float:
	var lower_text: String = text.to_lower()
	var explicit_weight: float = float(context.get("emotional_weight", -1.0))
	if explicit_weight >= 0.0:
		return explicit_weight

	if lower_text.find("died") >= 0 or lower_text.find("death") >= 0 or lower_text.find("killed") >= 0 or lower_text.find("lost") >= 0:
		return trauma_weight

	if lower_text.find("love") >= 0 or lower_text.find("joy") >= 0 or lower_text.find("married") >= 0 or lower_text.find("won") >= 0:
		return joy_weight

	return 1.0

func _infer_emotion_tags(text: String, context: Dictionary = {}) -> Array:
	var tags: Array = _safe_array(context.get("emotion_tags", []))
	var lower_text: String = text.to_lower()

	if lower_text.find("died") >= 0 or lower_text.find("killed") >= 0:
		tags.append("grief")
	if lower_text.find("love") >= 0 or lower_text.find("married") >= 0:
		tags.append("connection")
	if lower_text.find("won") >= 0 or lower_text.find("promoted") >= 0:
		tags.append("achievement")
	if lower_text.find("god") >= 0 or lower_text.find("faith") >= 0:
		tags.append("faith")
	if lower_text.find("universe") >= 0 or lower_text.find("reality") >= 0:
		tags.append("reality_awareness")

	return tags

func _infer_moral_axis(person: Person, _context: Dictionary = {}) -> Array:
	var axis: Array = ["survival", "connection", "growth"]

	for raw_trait in _safe_array(person.traits):
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text == "":
			continue

		if trait_text.find("faith") >= 0 or trait_text.find("spiritual") >= 0:
			if "faith" not in axis:
				axis.push_front("faith")

		if trait_text.find("loyal") >= 0:
			if "loyalty" not in axis:
				axis.append("loyalty")

		if trait_text.find("ambitious") >= 0 or trait_text.find("driven") >= 0:
			if "ambition" not in axis:
				axis.append("ambition")

		if trait_text.find("reckless") >= 0:
			if "freedom" not in axis:
				axis.append("freedom")

	return axis

func _infer_dominant_emotions(person: Person, _context: Dictionary = {}) -> Array:
	var out: Array = []

	if int(person.ambition) >= 65:
		out.append("ambition")
	if int(person.mental_health) < 40:
		out.append("anxiety")
	if int(person.satisfaction) >= 70:
		out.append("joy")
	if out.is_empty():
		out = ["curiosity", "survival"]

	return out

func _infer_goal_priority(person: Person, _context: Dictionary = {}) -> Array:
	var out: Array = ["survival"]

	if int(person.ambition) >= 60:
		out.append("status")
	if person.partner != null or not _safe_array(person.children).is_empty():
		out.append("connection")
	if int(person.smarts) >= 65:
		out.append("mastery")

	if out.size() == 1:
		out.append("connection")

	return out

func _infer_biases(person: Person, _context: Dictionary = {}) -> Array:
	var out: Array = []

	if int(person.fame) > 20:
		out.append("status_aware")
	if int(person.mental_health) < 45:
		out.append("threat_sensitive")
	if int(person.smarts) > 70:
		out.append("pattern_seeking")

	if out.is_empty():
		out.append("trust_slow")

	return out

func _infer_faith_level(person: Person, _context: Dictionary = {}) -> float:
	var level: float = 0.4

	for raw_trait in _safe_array(person.traits):
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text == "":
			continue

		if trait_text.find("faith") >= 0 or trait_text.find("spiritual") >= 0 or trait_text.find("devout") >= 0:
			level += 0.3

		if trait_text.find("cursed") >= 0 or trait_text.find("haunted") >= 0:
			level += 0.08

	return clamp(level, 0.0, 1.0)

func _infer_meaning_seeking(person: Person, _context: Dictionary = {}) -> float:
	var base: float = 0.55
	base += clamp(float(person.imagination) / 300.0, 0.0, 0.3)
	base += clamp(float(person.smarts) / 500.0, 0.0, 0.2)
	return clamp(base, 0.0, 1.0)

func _infer_attachment_style(person: Person) -> String:
	if int(person.mental_health) >= 65 and int(person.satisfaction) >= 50:
		return "secure"
	if int(person.mental_health) < 35:
		return "anxious"
	return "adaptive"

func _addiction_susceptibility(person: Person) -> float:
	var value: float = 0.3

	for raw_trait in _safe_array(person.traits):
		var trait_text: String = str(raw_trait).strip_edges().to_lower()
		if trait_text == "":
			continue

		if trait_text.find("addict") >= 0:
			value += 0.35

		if trait_text.find("discipline") >= 0:
			value -= 0.15

		if trait_text.find("vampire") >= 0:
			value += 0.12

		if trait_text.find("reckless") >= 0:
			value += 0.08

	return clamp(value, 0.0, 1.0)

func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)

func _current_world_seed() -> int:
	if gs == null or gs.seed_engine == null:
		return 0
	if "seed_value" in gs.seed_engine:
		return int(gs.seed_engine.seed_value)
	return 0

func _person_name(person: Person) -> String:
	if person == null:
		return ""
	return ("%s %s" % [str(person.first_name), str(person.last_name)]).strip_edges()

func _commit_report(report: Dictionary) -> void:
	last_consciousness_report = _make_binary_safe(report)
	consciousness_reports.append(last_consciousness_report.duplicate(true))

	while consciousness_reports.size() > 100:
		consciousness_reports.pop_front()

	if gs != null and typeof(gs.scenario_state) == TYPE_DICTIONARY:
		gs.scenario_state ["last_consciousness_report"] = last_consciousness_report.duplicate(true)

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

func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)

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