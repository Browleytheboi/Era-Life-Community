extends Resource
class_name WizardEngine

var gs

const CONTRACT_SCHEMA:= "eralife.wizard_contract"
const CONTRACT_VERSION:= 1
const WIZARD_LEVEL_MAX:= 100
const WAND_LEVEL_MAX:= 100
const COMPETITION_AGE:= 18

var active_contract: Dictionary = {}
var last_contract_report: Dictionary = {}
var wizard_reports: Array = []


func _init(_gs = null):
	gs = _gs
	set_contract({})


func set_contract(contract: Dictionary = {}) -> Dictionary:
	if typeof(contract) == TYPE_DICTIONARY and not contract.is_empty():
		active_contract = _merge_dict(_build_default_wizard_contract(), contract)
	else:
		active_contract = _build_default_wizard_contract()

	last_contract_report = {
		"schema": "eralife.wizard_contract_set_report",
		"version": CONTRACT_VERSION,
		"success": true,
		"contract_id": str(active_contract.get("id", "")),
		"set_at_ms": int(Time.get_ticks_msec())
	}
	return last_contract_report.duplicate(true)


func export_state() -> Dictionary:
	return _make_binary_safe({
		"schema": "eralife.wizard_engine_state",
		"version": CONTRACT_VERSION,
		"active_contract": active_contract.duplicate(true),
		"last_contract_report": last_contract_report.duplicate(true),
		"wizard_reports": wizard_reports.duplicate(true),
		"exported_at_ms": int(Time.get_ticks_msec())
	})


func import_state(data: Dictionary) -> Dictionary:
	if typeof(data) != TYPE_DICTIONARY:
		return {
			"success": false,
			"reason": "WizardEngine import_state expected a Dictionary."
		}

	var contract_raw: Variant = data.get("active_contract", {})
	if typeof(contract_raw) == TYPE_DICTIONARY:
		active_contract = _merge_dict(_build_default_wizard_contract(), contract_raw as Dictionary)
	else:
		active_contract = _build_default_wizard_contract()

	var report_raw: Variant = data.get("last_contract_report", {})
	if typeof(report_raw) == TYPE_DICTIONARY:
		last_contract_report = (report_raw as Dictionary).duplicate(true)

	var reports_raw: Variant = data.get("wizard_reports", [])
	if typeof(reports_raw) == TYPE_ARRAY:
		wizard_reports = (reports_raw as Array).duplicate(true)

	return {
		"success": true,
		"imported_at_ms": int(Time.get_ticks_msec())
	}


func _build_default_wizard_contract() -> Dictionary:
	return {
		"schema": CONTRACT_SCHEMA,
		"version": CONTRACT_VERSION,
		"id": "wizard_lineage",
		"lineage": {
			"family_power_rank": "elite",
			"parent_status": "former_champion",
			"siblings_count": 3,
			"heritage_trait_bias": ["intelligence", "willpower", "discipline", "imagination"]
		},
		"rules": {
			"magic_visibility": "hidden_from_humans",
			"age_of_trial": COMPETITION_AGE,
			"spell_learning_model": "progressive_mastery",
			"one_child_auto_full_wizard_at_trial_age": true
		},
		"progression": {
			"xp_sources": ["study", "practice", "duels", "artifacts", "ancient_library", "wand_growth"],
			"awakening_events": true,
		},
		"wand": {
			"starter": {
				"id": "training_wand",
				"name": "Training Wand",
				"tier": "training",
				"level": 1,
				"stability": 65,
				"power": 8
			},
			"tiers": ["training", "standard", "dueling", "ancient", "cursed", "cosmic"],
			"can_steal": true,
			"steal_failure": "council_heat"
		},
		"archetypes": {
			"duelist": {
				"skill_bias": "dueling",
				"stat_bias": "willpower",
				"growth": 1.15
			},
			"scholar": {
				"skill_bias": "spell_theory",
				"stat_bias": "smarts",
				"growth": 1.18
			},
			"chaos_caster": {
				"skill_bias": "wild_magic",
				"stat_bias": "imagination",
				"growth": 1.1,
				"backfire_multiplier": 1.35
			},
			"healer": {
				"skill_bias": "restoration",
				"stat_bias": "mental_health",
				"growth": 1.08
			},
			"dark_adept": {
				"skill_bias": "dark_magic",
				"stat_bias": "ambition",
				"growth": 1.22,
				"council_heat_multiplier": 1.55
			}
		},
		"spells": {
			"unlock_condition": "skill_threshold + knowledge",
			"failure_penalty": "backfire",
			"tiers": ["basic", "advanced", "forbidden"],
			"catalog": _build_spell_catalog()
		},
		"binding": {
			"oath": "do_not_reveal_magic",
			"enforcement": "council_stripping",
		},
		"competition": {
			"rounds": [
				"knowledge_trial",
				"spell_precision",
				"artifact_usage",
				"final_duel"
			],
			"audience": "wizard_council",
			"winner_reward": "full_wizard",
			"loser_policy": "sealed_family_magic"
		},
		"punishment": {
			"cheating": "strip_magic",
			"early_killing": "strip_magic + exile",
			"oath_break": "memory_seal + identity_fragments",
			"dark_magic_abuse": "council_trial"
		},
		"cross_systems": {
			"chi_magic_overload_threshold": 140,
			"overload_penalty": "instability_gain"
		},
		"consciousness_effects": {
			"pressure": 1.5,
			"ambition_bias": 1.3,
			"sibling_rivalry": 1.6,
			"fear_of_failure": 1.4
		}
	}


func _build_spell_catalog() -> Array:
	return [
		{
			"id": "light",
			"name": "Light",
			"tier": "basic",
			"school": "utility",
			"required_skill": 1,
			"required_knowledge": 0,
			"wand_level": 1,
			"description": "A simple glow spell used by young wizards learning focus."
		},
		{
			"id": "push",
			"name": "Push",
			"tier": "basic",
			"school": "force",
			"required_skill": 4,
			"required_knowledge": 2,
			"wand_level": 1,
			"description": "A short-range force burst."
		},
		{
			"id": "shield",
			"name": "Shield",
			"tier": "basic",
			"school": "defense",
			"required_skill": 8,
			"required_knowledge": 5,
			"wand_level": 2,
			"description": "A quick magical guard against small attacks."
		},
		{
			"id": "summon_burger_combo",
			"name": "Summon Burger Combo",
			"tier": "basic",
			"school": "conjuration_food",
			"required_skill": 10,
			"required_knowledge": 6,
			"wand_level": 2,
			"description": "Conjures a burger, fries, and drink into your inventory."
		},
		{
			"id": "accio_style_pull",
			"name": "Pull Object",
			"tier": "basic",
			"school": "utility",
			"required_skill": 14,
			"required_knowledge": 10,
			"wand_level": 4,
			"description": "Pulls a nearby object toward you."
		},
		{
			"id": "disarming_flash",
			"name": "Disarming Flash",
			"tier": "advanced",
			"school": "dueling",
			"required_skill": 28,
			"required_knowledge": 22,
			"wand_level": 12,
			"description": "A clean dueling spell that can knock a wand loose."
		},
		{
			"id": "mind_influence",
			"name": "Mind Influence",
			"tier": "advanced",
			"school": "mind",
			"required_skill": 35,
			"required_knowledge": 35,
			"wand_level": 18,
			"description": "Nudges a target's thoughts. Repeated abuse raises council heat."
		},
		{
			"id": "teleportation",
			"name": "Teleportation",
			"tier": "advanced",
			"school": "space",
			"required_skill": 52,
			"required_knowledge": 48,
			"wand_level": 30,
			"description": "Moves the caster across space. Failure can injure you."
		},
		{
			"id": "energy_control",
			"name": "Energy Control",
			"tier": "advanced",
			"school": "energy",
			"required_skill": 62,
			"required_knowledge": 55,
			"wand_level": 36,
			"description": "Balances magical output, chi flow, and raw force."
		},
		{
			"id": "soul_bind",
			"name": "Soul Bind",
			"tier": "forbidden",
			"school": "dark_magic",
			"required_skill": 78,
			"required_knowledge": 75,
			"wand_level": 55,
			"description": "A forbidden binding spell that permanently raises council heat."
		},
		{
			"id": "memory_rewrite",
			"name": "Memory Rewrite",
			"tier": "forbidden",
			"school": "mind",
			"required_skill": 84,
			"required_knowledge": 82,
			"wand_level": 62,
			"description": "Rewrites memory. Oath violations can fracture identity."
		},
		{
			"id": "reality_tear",
			"name": "Reality Tear",
			"tier": "forbidden",
			"school": "reality",
			"required_skill": 95,
			"required_knowledge": 94,
			"wand_level": 80,
			"description": "Rips a temporary wound through reality itself."
		}
	]


func has_wizard_magic(actor: Person) -> bool:
	if actor == null:
		return false
	if typeof(actor.wizard_profile) != TYPE_DICTIONARY:
		return false
	var profile: Dictionary = actor.wizard_profile
	if not bool(profile.get("is_wizard", false)):
		return false
	var magic_status: String = str(profile.get("magic_status", "active")).strip_edges().to_lower()
	return magic_status not in ["stripped", "sealed", "lost_by_human_marriage"]


func ensure_wizard_profile(actor: Person, context: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}
	if typeof(actor.wizard_profile) != TYPE_DICTIONARY:
		actor.wizard_profile = {}

	var base: Dictionary = _default_wizard_profile(actor)
	var merged: Dictionary = _merge_dict(base, actor.wizard_profile)
	merged = _normalize_wizard_profile(actor, merged, context)
	actor.wizard_profile = merged.duplicate(true)
	return merged.duplicate(true)


func _default_wizard_profile(_actor: Person) -> Dictionary:
	var starter_wand: Dictionary = _safe_dictionary(_safe_dictionary(active_contract.get("wand", {})).get("starter", {}))
	if starter_wand.is_empty():
		starter_wand = {
			"id": "training_wand",
			"name": "Training Wand",
			"tier": "training",
			"level": 1,
			"stability": 65,
			"power": 8
		}

	return {
		"schema": "eralife.person_wizard_profile",
		"version": CONTRACT_VERSION,
		"is_wizard": false,
		"wizard_blood_status": "human",
		"full_wizard": false,
		"magic_status": "inactive",
		"lineage_id": "",
		"family_power_rank": "ordinary",
		"archetype": "scholar",
		"skill": {
			"spellcraft": 0,
			"wand_control": 0,
			"spell_theory": 0,
			"dueling": 0,
			"artifact_lore": 0,
			"dark_magic": 0,
			"energy_balance": 50
		},
		"xp": {
			"study": 0,
			"practice": 0,
			"duels": 0,
			"library": 0,
			"wand": 0
		},
		"wand": starter_wand.duplicate(true),
		"known_spells": [],
		"spell_history": [],
		"dark_magic": {
			"exposure": 0,
			"temptation": 0,
			"used_forbidden_spell": false
		},
		"council": {
			"oath_violations": [],
			"heat": 0,
			"stripped": false,
			"exiled": false,
		},
		"competition": {
			"eligible_age": COMPETITION_AGE,
			"available": false,
			"entered": false,
			"resolved": false,
			"result": "",
			"rounds": [],
			"score": 0,
			"champion_year": -1
		},
		"energy": {
			"magic": 40,
			"chi": 0,
			"flow_balance": 100,
			"instability": 0
		},
		"family": {
			"parent_status": "",
			"sibling_rivalry": 0,
			"competition_sibling_ids": []
		},
		"last_updated_year": _current_year()
	}


func apply_birth_settings(actor: Person, settings: Dictionary = {}) -> Dictionary:
	if actor == null:
		return {}

	if gs != null and gs.has_method("is_feature_enabled") and not gs.is_feature_enabled("wizard_magic"):
		actor.wizard_profile = {}
		return {}

	var wants_wizard: bool = bool(settings.get("start_as_wizard", false)) \
or bool(settings.get("wizard_lineage_enabled", false)) \
or str(settings.get("wizard_blood_status", "")).strip_edges() != ""

	if not wants_wizard and not _has_wizard_parent(actor):
		return ensure_wizard_profile(actor, {
			"source": "birth_settings_no_wizard"
		})

	return _seed_wizard_family(actor, settings)


func assign_wizard_lineage(payload) -> void:
	if gs != null and gs.has_method("is_feature_enabled") and not gs.is_feature_enabled("wizard_magic"):
		return

	var actor: Person = _resolve_person_from_payload(payload)
	if actor == null:
		return

	if _has_wizard_parent(actor):
		var settings: Dictionary = {
			"source": "parental_wizard_inheritance",
			"wizard_lineage_enabled": true
		}
		_seed_wizard_child_from_parents(actor, settings)
	else:
		ensure_wizard_profile(actor, {
			"source": "npc_born_non_wizard"
		})


func bootstrap_wizard_lineages(source_npcs: Array = []) -> Dictionary:
	var report: Dictionary = {
		"schema": "eralife.wizard_bootstrap_report",
		"version": CONTRACT_VERSION,
		"seeded": 0,
		"checked": 0
	}

	if gs != null and gs.has_method("is_feature_enabled") and not gs.is_feature_enabled("wizard_magic"):
		return report

	for raw_actor in source_npcs:
		var actor: Person = raw_actor as Person
		if actor == null:
			continue

		report ["checked"] = int(report ["checked"]) + 1

		if actor == gs.player:
			continue
		if int(actor.age) < 18:
			continue
		if typeof(actor.wizard_profile) == TYPE_DICTIONARY and bool(actor.wizard_profile.get("is_wizard", false)):
			continue

		var chance: int = 2
		if int(actor.smarts) >= 75:
			chance += 1
		if int(actor.imagination) >= 60:
			chance += 1

		if randi() % 100 < chance:
			var profile: Dictionary = ensure_wizard_profile(actor, {
				"source": "bootstrap_wizard_lineage"
			})
			profile ["is_wizard"] = true
			profile ["wizard_blood_status"] = "full"
			profile ["full_wizard"] = true
			profile ["magic_status"] = "active"
			profile ["family_power_rank"] = _weighted_family_rank()
			profile ["lineage_id"] = "lineage_%s_%d" % [actor.last_name.to_lower(), int(actor.id)]
			profile ["archetype"] = _pick_wizard_archetype(actor)
			profile ["skill"] = _seed_adult_skill_profile(actor, profile)
			profile ["known_spells"] = _resolve_unlocked_spell_ids(profile)
			actor.wizard_profile = profile.duplicate(true)
			_add_trait_once(actor, "Wizard")
			report ["seeded"] = int(report ["seeded"]) + 1

	return report


func study_magic(actor: Person, source: String = "ancient_library") -> Dictionary:
	if not has_wizard_magic(actor):
		return _result(false, "Wizard Study", "You do not have active magic to study.", actor)

	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "study_magic"
	})
	var skill: Dictionary = _safe_dictionary(profile.get("skill", {}))
	var xp: Dictionary = _safe_dictionary(profile.get("xp", {}))

	var study_gain: int = 4 + int(clamp(float(actor.smarts) / 25.0, 0.0, 4.0))
	if str(source).to_lower().find("ancient") >= 0:
		study_gain += 2

	skill ["spell_theory"] = clamp(int(skill.get("spell_theory", 0)) + study_gain, 0, WIZARD_LEVEL_MAX)
	skill ["artifact_lore"] = clamp(int(skill.get("artifact_lore", 0)) + max(1, _int_div_floor(study_gain, 2)), 0, WIZARD_LEVEL_MAX)
	xp ["study"] = int(xp.get("study", 0)) + study_gain
	xp ["library"] = int(xp.get("library", 0)) + (study_gain if str(source).to_lower().find("library") >= 0 else 0)

	profile ["skill"] = skill
	profile ["xp"] = xp
	profile = _sync_spell_unlocks(actor, profile)
	profile = _balance_chi_and_magic(actor, profile)
	actor.wizard_profile = profile.duplicate(true)

	var text: String = "I studied spell theory at the ancient wizard library and felt my magic settle into clearer patterns."
	_remember(actor, text)

	return _result(true, "Ancient Wizard Library", "You studied spell theory. New knowledge settled into your wand hand.", actor, {
		"text": text,
		"profile": profile.duplicate(true)
	})


func practice_magic(actor: Person, focus: String = "wand_control") -> Dictionary:
	if not has_wizard_magic(actor):
		return _result(false, "Wizard Practice", "You do not have active magic to practice.", actor)

	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "practice_magic"
	})
	var skill: Dictionary = _safe_dictionary(profile.get("skill", {}))
	var xp: Dictionary = _safe_dictionary(profile.get("xp", {}))
	var wand: Dictionary = _safe_dictionary(profile.get("wand", {}))

	var gain: int = 3 + int(clamp(float(actor.imagination) / 28.0, 0.0, 4.0))
	var clean_focus: String = str(focus).strip_edges().to_lower()
	if clean_focus == "":
		clean_focus = "wand_control"

	match clean_focus:
		"dueling":
			skill ["dueling"] = clamp(int(skill.get("dueling", 0)) + gain, 0, WIZARD_LEVEL_MAX)
			skill ["spellcraft"] = clamp(int(skill.get("spellcraft", 0)) + max(1, _int_div_floor(gain, 2)), 0, WIZARD_LEVEL_MAX)
		"dark_magic":
			skill ["dark_magic"] = clamp(int(skill.get("dark_magic", 0)) + gain, 0, WIZARD_LEVEL_MAX)
			var dark: Dictionary = _safe_dictionary(profile.get("dark_magic", {}))
			dark ["exposure"] = clamp(int(dark.get("exposure", 0)) + gain, 0, 100)
			dark ["temptation"] = clamp(int(dark.get("temptation", 0)) + max(1, _int_div_floor(gain, 2)), 0, 100)
			profile ["dark_magic"] = dark
			_raise_council_heat(profile, max(1, _int_div_floor(gain, 2)))
		_:
			skill ["wand_control"] = clamp(int(skill.get("wand_control", 0)) + gain, 0, WIZARD_LEVEL_MAX)
			skill ["spellcraft"] = clamp(int(skill.get("spellcraft", 0)) + max(1, _int_div_floor(gain, 2)), 0, WIZARD_LEVEL_MAX)

	wand ["xp"] = int(wand.get("xp", 0)) + gain
	var next_wand_level: int = clamp(int(wand.get("level", 1)) + _int_div_floor(wand.get("xp", 0), 20), 1, WAND_LEVEL_MAX)
	wand ["level"] = next_wand_level

	xp ["practice"] = int(xp.get("practice", 0)) + gain
	xp ["wand"] = int(xp.get("wand", 0)) + gain

	profile ["skill"] = skill
	profile ["xp"] = xp
	profile ["wand"] = wand
	profile = _sync_spell_unlocks(actor, profile)
	profile = _balance_chi_and_magic(actor, profile)
	actor.wizard_profile = profile.duplicate(true)

	var text: String = "I practiced magic until my wand felt less like a tool and more like an extension of my hand."
	_remember(actor, text)

	return _result(true, "Wizard Practice", "You practiced magic. Your wand control and spellcraft improved.", actor, {
		"text": text,
		"profile": profile.duplicate(true)
	})


func steal_wand(actor: Person) -> Dictionary:
	if not has_wizard_magic(actor):
		return _result(false, "Wand Theft", "You do not have active magic.", actor)

	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "steal_wand"
	})
	var skill: Dictionary = _safe_dictionary(profile.get("skill", {}))
	var roll: int = randi_range(1, 100)
	var theft_score: int = roll + int(skill.get("spellcraft", 0)) + int(skill.get("dueling", 0)) + _int_div_floor(actor.smarts, 4)

	if theft_score >= 115:
		var wand: Dictionary = {
			"id": "stolen_dueling_wand_%d" % int(Time.get_ticks_msec()),
			"name": "Stolen Dueling Wand",
			"tier": "dueling",
			"level": clamp(18 + randi_range(0, 18), 1, WAND_LEVEL_MAX),
			"stability": clamp(58 + randi_range(0, 28), 1, 100),
			"power": clamp(28 + randi_range(0, 30), 1, 100),
			"stolen": true,
			"acquired_year": _current_year()
		}
		profile ["wand"] = wand
		actor.wizard_profile = profile.duplicate(true)

		var text: String = "I stole a stronger wand and felt its stolen magic recognize me."
		_remember(actor, text)

		return _result(true, "Wand Stolen", "You stole a stronger wand. The magic in it feels dangerous, but useful.", actor, {
			"text": text,
			"profile": profile.duplicate(true)
		})

	_raise_council_heat(profile, 18)
	actor.wizard_profile = profile.duplicate(true)

	var fail_text: String = "I tried to steal a wand and nearly got exposed to the Wizard Council."
	_remember(actor, fail_text)

	return _result(false, "Wand Theft Failed", "You failed to steal the wand. The Wizard Council felt a ripple in the oath network.", actor, {
		"text": fail_text,
		"profile": profile.duplicate(true)
	})


func cast_spell(actor: Person, spell_id: String, target: Person = null, context: Dictionary = {}) -> Dictionary:
	if not has_wizard_magic(actor):
		return _result(false, "Spell Failed", "You do not have active magic.", actor)

	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "cast_spell",
		"spell_id": spell_id
	})
	profile = _sync_spell_unlocks(actor, profile)

	var clean_spell_id: String = str(spell_id).strip_edges().to_lower()
	var spell: Dictionary = get_spell_by_id(clean_spell_id)
	if spell.is_empty():
		return _result(false, "Unknown Spell", "That spell is not registered in the wizard contract.", actor)

	var known_spells: Array = _safe_array(profile.get("known_spells", []))
	if clean_spell_id not in known_spells:
		return _result(false, "Spell Locked", "You have not learned that spell yet.", actor)

	var backfire: Dictionary = _spell_backfire_check(actor, profile, spell)
	if bool(backfire.get("backfired", false)):
		actor.wizard_profile = _safe_dictionary(backfire.get("profile", profile)).duplicate(true)
		return _result(false, "Spell Backfired", str(backfire.get("text", "The spell backfired.")), actor, {
			"profile": actor.wizard_profile.duplicate(true)
		})

	var school: String = str(spell.get("school", "")).strip_edges().to_lower()
	var popup_text: String = "You cast %s." % str(spell.get("name", clean_spell_id))
	var diary_text: String = "I cast %s." % str(spell.get("name", clean_spell_id))

	match school:
		"conjuration_food":
			_add_conjured_food(actor, clean_spell_id)
			popup_text = "You flicked your wand and a burger combo appeared in your inventory."
			diary_text = "I used magic to summon a burger combo into my inventory."
		"dark_magic":
			var dark: Dictionary = _safe_dictionary(profile.get("dark_magic", {}))
			dark ["used_forbidden_spell"] = true
			dark ["exposure"] = clamp(int(dark.get("exposure", 0)) + 12, 0, 100)
			profile ["dark_magic"] = dark
			_raise_council_heat(profile, 12)
			popup_text = "You cast forbidden magic. The spell worked, but the Council felt it."
			diary_text = "I cast forbidden magic and felt something in the oath network look back at me."
		"mind":
			_raise_council_heat(profile, 5)
			popup_text = "You used mind magic. The result was subtle, but not invisible."
			diary_text = "I used mind magic and felt the line between influence and violation blur."
		_:
			pass

	var history: Array = _safe_array(profile.get("spell_history", []))
	history.append({
		"spell_id": clean_spell_id,
		"name": str(spell.get("name", clean_spell_id)),
		"year": _current_year(),
		"target_id": int(target.id) if target != null else -1,
		"context": context.duplicate(true)
	})
	while history.size() > 60:
		history.pop_front()

	profile ["spell_history"] = history
	profile = _balance_chi_and_magic(actor, profile)
	actor.wizard_profile = profile.duplicate(true)
	_remember(actor, diary_text)

	return _result(true, str(spell.get("name", "Spell")), popup_text, actor, {
		"text": diary_text,
		"profile": profile.duplicate(true)
	})


func get_available_spells(actor: Person) -> Array:
	if actor == null:
		return []

	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "get_available_spells"
	})
	profile = _sync_spell_unlocks(actor, profile)
	actor.wizard_profile = profile.duplicate(true)

	var known_spells: Array = _safe_array(profile.get("known_spells", []))
	var out: Array = []

	for raw_spell in _spell_catalog():
		if typeof(raw_spell) != TYPE_DICTIONARY:
			continue
		var spell: Dictionary = raw_spell
		var spell_id: String = str(spell.get("id", "")).strip_edges()
		if spell_id == "" or spell_id not in known_spells:
			continue
		out.append({
			"id": spell_id,
			"label": str(spell.get("name", spell_id)),
			"title": str(spell.get("name", spell_id)),
			"subtitle": "%s • %s" % [
				str(spell.get("tier", "basic")).capitalize(),
				str(spell.get("school", "magic")).capitalize()
			],
			"description": str(spell.get("description", "")),
			"tier": str(spell.get("tier", "basic")),
			"school": str(spell.get("school", "magic")),
			"action": "wizard.cast_spell",
			"spell_id": spell_id
		})

	return out


func get_spell_by_id(spell_id: String) -> Dictionary:
	var clean_spell_id: String = str(spell_id).strip_edges().to_lower()
	for raw_spell in _spell_catalog():
		if typeof(raw_spell) != TYPE_DICTIONARY:
			continue
		var spell: Dictionary = raw_spell
		if str(spell.get("id", "")).strip_edges().to_lower() == clean_spell_id:
			return spell.duplicate(true)
	return {}


func attempt_family_competition(actor: Person) -> Dictionary:
	if actor == null:
		return _result(false, "Wizard Competition", "No wizard was supplied.", actor)
	if not has_wizard_magic(actor):
		return _result(false, "Wizard Competition", "You do not have active magic.", actor)
	if int(actor.age) < COMPETITION_AGE:
		return _result(false, "Wizard Competition Locked", "You must be 18 before your family wizard competition.", actor)

	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "attempt_family_competition"
	})
	var competition: Dictionary = _safe_dictionary(profile.get("competition", {}))
	if bool(competition.get("resolved", false)):
		return _result(false, "Wizard Competition", "Your family wizard competition has already been resolved.", actor)

	var sibling_ids: Array = _sibling_ids(actor)
	if sibling_ids.is_empty() and bool(_safe_dictionary(_safe_dictionary(active_contract.get("rules", {}))).get("one_child_auto_full_wizard_at_trial_age", true)):
		profile = _make_full_wizard(actor, profile, "only_child_trial")
		actor.wizard_profile = profile.duplicate(true)
		var only_child_text: String = "I turned 18 as the only wizard child in my family, so the Council recognized me as the full wizard."
		_remember(actor, only_child_text)
		return _result(true, "Full Wizard", "You were the only child in your wizard family. At 18, the Council made you the full wizard.", actor, {
			"text": only_child_text,
			"profile": profile.duplicate(true)
		})

	var competitors: Array = [actor]
	for raw_sibling_id in sibling_ids:
		var sibling: Person = _get_npc(int(raw_sibling_id))
		if sibling != null:
			ensure_wizard_profile(sibling, {
				"source": "competition_preflight"
			})
			competitors.append(sibling)

	var scoreboard: Array = []
	var actor_score: int = 0

	for competitor_raw in competitors:
		var competitor: Person = competitor_raw as Person
		if competitor == null:
			continue
		var score: int = _competition_score(competitor)
		if competitor == actor:
			actor_score = score
		scoreboard.append({
			"person_id": int(competitor.id),
			"name": _person_name(competitor),
			"score": score
		})

	scoreboard.sort_custom(func (a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))

	var winner_id: int = int(_safe_dictionary(scoreboard [0]).get("person_id", -1)) if not scoreboard.is_empty() else int(actor.id)
	var won: bool = winner_id == int(actor.id)

	var rounds: Array = [
		{
			"id": "knowledge_trial",
			"label": "Knowledge Trial",
			"score": actor_score + randi_range(-5, 5)
		},
		{
			"id": "spell_precision",
			"label": "Spell Precision",
			"score": actor_score + randi_range(-8, 8)
		},
		{
			"id": "artifact_usage",
			"label": "Artifact Usage",
			"score": actor_score + randi_range(-10, 10)
		},
		{
			"id": "final_duel",
			"label": "Final Duel",
			"score": actor_score + randi_range(-12, 12)
		}
	]

	competition ["entered"] = true
	competition ["resolved"] = true
	competition ["rounds"] = rounds
	competition ["score"] = actor_score
	competition ["result"] = "won" if won else "lost"
	profile ["competition"] = competition

	if won:
		profile = _make_full_wizard(actor, profile, "family_competition_winner")
		for raw_loser in competitors:
			var loser: Person = raw_loser as Person
			if loser == null or loser == actor:
				continue
			_seal_family_magic(loser, "lost_family_competition")
		actor.wizard_profile = profile.duplicate(true)
		var win_text: String = "I won my family wizard competition and became the full wizard."
		_remember(actor, win_text)
		return _result(true, "Family Wizard Champion", "You survived every round, defeated your siblings, and became the full wizard.", actor, {
			"text": win_text,
			"scoreboard": scoreboard,
			"profile": profile.duplicate(true)
		})

	_seal_family_magic(actor, "lost_family_competition")
	var loss_text: String = "I lost my family wizard competition and felt my family magic seal itself away."
	_remember(actor, loss_text)
	return _result(false, "Competition Lost", "You lost the family wizard competition. Your family magic was sealed.", actor, {
		"text": loss_text,
		"scoreboard": scoreboard,
		"profile": actor.wizard_profile.duplicate(true)
	})


func wizard_duel(attacker: Person, defender: Person, context: Dictionary = {}) -> Dictionary:
	if attacker == null or defender == null:
		return {
			"success": false,
			"reason": "Missing duel participant."
		}
	if not has_wizard_magic(attacker):
		return _result(false, "Wizard Duel", "You do not have active magic.", attacker)

	var attacker_profile: Dictionary = ensure_wizard_profile(attacker, {
		"source": "wizard_duel_attacker"
	})
	var defender_profile: Dictionary = ensure_wizard_profile(defender, {
		"source": "wizard_duel_defender"
	})

	var attacker_power: int = _duel_power(attacker, attacker_profile)
	var defender_power: int = _duel_power(defender, defender_profile)
	var attacker_roll: int = attacker_power + randi_range(1, 40)
	var defender_roll: int = defender_power + randi_range(1, 40)

	var won: bool = attacker_roll >= defender_roll
	var damage: int = clamp(_int_div_floor(abs(attacker_roll - defender_roll), 3) + randi_range(3, 18), 3, 45)

	if won:
		defender.health = max(0.0, float(defender.health) - float(damage))
		practice_magic(attacker, "dueling")
		return _result(true, "Wizard Duel Won", "You out-cast %s and won the duel." % _person_name(defender), attacker, {
			"damage": damage,
			"defender_id": int(defender.id),
			"context": context.duplicate(true)
		})

	attacker.health = max(0.0, float(attacker.health) - float(damage))
	return _result(false, "Wizard Duel Lost", "%s read your wand movement and beat you in the duel." % _person_name(defender), attacker, {
		"damage": damage,
		"defender_id": int(defender.id),
		"context": context.duplicate(true)
	})


func yearly_tick(_payload = {}) -> Dictionary:
	var report: Dictionary = {
		"schema": "eralife.wizard_yearly_tick_report",
		"version": CONTRACT_VERSION,
		"processed": 0,
		"competition_ready": 0,
		"full_wizards_recognized": 0
	}

	if gs == null:
		return report
	if gs.has_method("is_feature_enabled") and not gs.is_feature_enabled("wizard_magic"):
		return report

	for raw_actor in gs.npcs:
		var actor: Person = raw_actor as Person
		if actor == null:
			continue
		if typeof(actor.wizard_profile) != TYPE_DICTIONARY:
			continue
		if not bool(actor.wizard_profile.get("is_wizard", false)):
			continue

		var profile: Dictionary = ensure_wizard_profile(actor, {
			"source": "wizard_yearly_tick"
		})
		report ["processed"] = int(report ["processed"]) + 1

		if actor != gs.player and has_wizard_magic(actor):
			_progress_npc_wizard_year(actor, profile)

		profile = ensure_wizard_profile(actor, {
			"source": "wizard_yearly_tick_post_progress"
		})

		var competition: Dictionary = _safe_dictionary(profile.get("competition", {}))
		if int(actor.age) >= COMPETITION_AGE and not bool(competition.get("resolved", false)):
			competition ["available"] = true
			profile ["competition"] = competition
			report ["competition_ready"] = int(report ["competition_ready"]) + 1

			if _sibling_ids(actor).is_empty() and bool(_safe_dictionary(_safe_dictionary(active_contract.get("rules", {}))).get("one_child_auto_full_wizard_at_trial_age", true)):
				profile = _make_full_wizard(actor, profile, "only_child_auto_yearly_tick")
				report ["full_wizards_recognized"] = int(report ["full_wizards_recognized"]) + 1

		profile = _balance_chi_and_magic(actor, profile)
		actor.wizard_profile = profile.duplicate(true)

	return report


func on_marriage(payload) -> void:
	var pair: Array = _resolve_marriage_pair(payload)
	if pair.size() < 2:
		return

	var first_actor: Person = pair [0]
	var second_actor: Person = pair [1]

	_apply_human_marriage_rule(first_actor, second_actor)
	_apply_human_marriage_rule(second_actor, first_actor)


func strip_magic(actor: Person, reason: String = "council_stripping") -> Dictionary:
	if actor == null:
		return {}

	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "strip_magic",
		"reason": reason
	})
	profile ["magic_status"] = "stripped"
	profile ["full_wizard"] = false

	var council: Dictionary = _safe_dictionary(profile.get("council", {}))
	council ["stripped"] = true
	council ["stripped_reason"] = reason
	council ["stripped_year"] = _current_year()
	profile ["council"] = council

	actor.wizard_profile = profile.duplicate(true)
	_add_trait_once(actor, "Magic Stripped")

	var text: String = "The Wizard Council stripped my magic because of %s." % reason.replace("_", " ")
	_remember(actor, text)

	return _result(true, "Magic Stripped", "The Wizard Council stripped your abilities.", actor, {
		"text": text,
		"profile": profile.duplicate(true)
	})


func record_oath_violation(actor: Person, violation_id: String, severity: int = 1) -> Dictionary:
	if actor == null:
		return {}

	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "record_oath_violation"
	})
	var council: Dictionary = _safe_dictionary(profile.get("council", {}))
	var violations: Array = _safe_array(council.get("oath_violations", []))

	violations.append({
		"id": str(violation_id),
		"severity": severity,
		"year": _current_year()
	})

	council ["oath_violations"] = violations
	council ["heat"] = clamp(int(council.get("heat", 0)) + max(1, severity * 8), 0, 100)
	profile ["council"] = council
	actor.wizard_profile = profile.duplicate(true)

	if int(council.get("heat", 0)) >= 100:
		return strip_magic(actor, "oath_break")

	return _result(true, "Oath Violation", "The Council recorded an oath violation.", actor, {
		"profile": profile.duplicate(true)
	})


func punish_early_killing(actor: Person) -> Dictionary:
	var result: Dictionary = strip_magic(actor, "early_killing_before_family_competition")
	if actor != null:
		var profile: Dictionary = ensure_wizard_profile(actor, {
			"source": "punish_early_killing"
		})
		var council: Dictionary = _safe_dictionary(profile.get("council", {}))
		council ["exiled"] = true
		profile ["council"] = council
		actor.wizard_profile = profile.duplicate(true)
	return result


func _seed_wizard_family(actor: Person, settings: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "seed_wizard_family"
	})

	var lineage: Dictionary = _safe_dictionary(active_contract.get("lineage", {}))
	var family_rank: String = str(settings.get("wizard_family_power_rank", lineage.get("family_power_rank", "elite"))).strip_edges()
	if family_rank == "":
		family_rank = "elite"

	var lineage_id: String = "wizard_%s_%d" % [
		str(actor.last_name).to_lower(),
		int(actor.id)
	]

	var parents: Array = _resolve_birth_parents(actor)
	for parent_raw in parents:
		var parent_actor: Person = parent_raw as Person
		if parent_actor == null:
			continue
		var parent_profile: Dictionary = ensure_wizard_profile(parent_actor, {
			"source": "seed_parent_former_champion"
		})
		parent_profile ["is_wizard"] = true
		parent_profile ["wizard_blood_status"] = "full"
		parent_profile ["full_wizard"] = true
		parent_profile ["magic_status"] = "active"
		parent_profile ["lineage_id"] = lineage_id
		parent_profile ["family_power_rank"] = family_rank
		parent_profile ["archetype"] = _pick_wizard_archetype(parent_actor)
		parent_profile ["skill"] = _seed_adult_skill_profile(parent_actor, parent_profile)
		parent_profile ["known_spells"] = _resolve_unlocked_spell_ids(parent_profile)
		parent_profile ["competition"] = {
			"eligible_age": COMPETITION_AGE,
			"available": false,
			"entered": true,
			"resolved": true,
			"result": "former_champion",
			"rounds": [],
			"score": 100,
			"champion_year": _current_year() - max(1, int(parent_actor.age) - COMPETITION_AGE)
		}
		parent_actor.wizard_profile = parent_profile.duplicate(true)
		_add_trait_once(parent_actor, "Wizard")
		_add_trait_once(parent_actor, "Former Family Wizard Champion")

	profile ["is_wizard"] = true
	profile ["wizard_blood_status"] = str(settings.get("wizard_blood_status", "full")).strip_edges().to_lower()
	if str(profile.get("wizard_blood_status", "")) == "":
		profile ["wizard_blood_status"] = "full"
	profile ["full_wizard"] = false
	profile ["magic_status"] = "active"
	profile ["lineage_id"] = lineage_id
	profile ["family_power_rank"] = family_rank
	profile ["archetype"] = _pick_wizard_archetype(actor)
	profile ["known_spells"] = ["light"]
	profile ["family"] = {
		"parent_status": "former_champion",
		"sibling_rivalry": 35,
		"competition_sibling_ids": []
	}
	actor.wizard_profile = profile.duplicate(true)
	_add_trait_once(actor, "Wizard Heir")

	_ensure_wizard_siblings(actor, int(lineage.get("siblings_count", 3)), lineage_id, family_rank)

	var refreshed: Dictionary = ensure_wizard_profile(actor, {
		"source": "seed_wizard_family_post_siblings"
	})
	refreshed = _sync_spell_unlocks(actor, refreshed)
	actor.wizard_profile = refreshed.duplicate(true)

	var text: String = "I was born into a wizard family. My parents had already won their family competition, and one day my siblings and I would have to face our own."
	_remember(actor, text)

	return refreshed.duplicate(true)


func _seed_wizard_child_from_parents(actor: Person, settings: Dictionary = {}) -> Dictionary:
	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "seed_wizard_child_from_parents"
	})

	var parents: Array = _resolve_birth_parents(actor)
	var wizard_parent_count: int = 0
	var lineage_id: String = ""

	for parent_raw in parents:
		var parent_actor: Person = parent_raw as Person
		if parent_actor == null:
			continue
		if has_wizard_magic(parent_actor) or bool(_safe_dictionary(parent_actor.wizard_profile).get("is_wizard", false)):
			wizard_parent_count += 1
			if lineage_id == "":
				lineage_id = str(_safe_dictionary(parent_actor.wizard_profile).get("lineage_id", ""))

	profile ["is_wizard"] = wizard_parent_count > 0
	profile ["wizard_blood_status"] = "full" if wizard_parent_count >= 2 else "half"
	profile ["full_wizard"] = false
	profile ["magic_status"] = "active" if wizard_parent_count > 0 else "inactive"
	profile ["lineage_id"] = lineage_id
	profile ["family_power_rank"] = str(settings.get("wizard_family_power_rank", profile.get("family_power_rank", "ordinary")))
	profile ["archetype"] = _pick_wizard_archetype(actor)
	profile ["known_spells"] = ["light"] if wizard_parent_count > 0 else []

	actor.wizard_profile = profile.duplicate(true)

	if wizard_parent_count > 0:
		_add_trait_once(actor, "Half Wizard" if wizard_parent_count == 1 else "Wizard Heir")

	return profile.duplicate(true)


func _ensure_wizard_siblings(actor: Person, desired_sibling_count: int, lineage_id: String, family_rank: String) -> void:
	if gs == null or actor == null or gs.npc_factory == null:
		return

	var existing_sibling_ids: Array = _sibling_ids(actor)
	var needed: int = max(0, desired_sibling_count - existing_sibling_ids.size())

	for i in range(needed):
		var sibling: Person = gs.npc_factory.create_random_npc(false)
		if sibling == null:
			continue

		sibling.last_name = actor.last_name
		sibling.home_city = actor.home_city
		sibling.home_country = actor.home_country
		sibling.birth_city = actor.birth_city
		sibling.birth_country = actor.birth_country
		sibling.parents = actor.parents.duplicate()
		sibling.age = clamp(int(actor.age) + randi_range(-2, 2), 0, 17)

		var sibling_profile: Dictionary = ensure_wizard_profile(sibling, {
			"source": "seed_wizard_sibling"
		})
		sibling_profile ["is_wizard"] = true
		sibling_profile ["wizard_blood_status"] = "full"
		sibling_profile ["full_wizard"] = false
		sibling_profile ["magic_status"] = "active"
		sibling_profile ["lineage_id"] = lineage_id
		sibling_profile ["family_power_rank"] = family_rank
		sibling_profile ["archetype"] = _pick_wizard_archetype(sibling)
		sibling_profile ["known_spells"] = ["light"]
		sibling_profile ["skill"] = _seed_child_skill_profile(sibling, sibling_profile)
		sibling.wizard_profile = sibling_profile.duplicate(true)
		_add_trait_once(sibling, "Wizard Heir")

		gs.npcs.append(sibling)

		if gs.social_graph_engine != null:
			gs.social_graph_engine.connect_people(actor.id, sibling.id)

	var actor_profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "ensure_wizard_siblings_actor_refresh"
	})
	var family: Dictionary = _safe_dictionary(actor_profile.get("family", {}))
	family ["competition_sibling_ids"] = _sibling_ids(actor)
	family ["sibling_rivalry"] = clamp(25 + family ["competition_sibling_ids"].size() * 12, 0, 100)
	actor_profile ["family"] = family
	actor.wizard_profile = actor_profile.duplicate(true)


func _progress_npc_wizard_year(actor: Person, profile: Dictionary) -> void:
	if actor == null:
		return

	var skill: Dictionary = _safe_dictionary(profile.get("skill", {}))
	var xp: Dictionary = _safe_dictionary(profile.get("xp", {}))
	var archetype: String = str(profile.get("archetype", "scholar")).strip_edges().to_lower()

	var gain: int = 1 + int(clamp(float(actor.smarts + actor.imagination) / 75.0, 0.0, 4.0))
	if archetype == "scholar":
		skill ["spell_theory"] = clamp(int(skill.get("spell_theory", 0)) + gain + 1, 0, WIZARD_LEVEL_MAX)
	elif archetype == "duelist":
		skill ["dueling"] = clamp(int(skill.get("dueling", 0)) + gain + 1, 0, WIZARD_LEVEL_MAX)
	elif archetype == "dark_adept":
		skill ["dark_magic"] = clamp(int(skill.get("dark_magic", 0)) + gain + 1, 0, WIZARD_LEVEL_MAX)
		_raise_council_heat(profile, 1)
	else:
		skill ["spellcraft"] = clamp(int(skill.get("spellcraft", 0)) + gain, 0, WIZARD_LEVEL_MAX)

	skill ["wand_control"] = clamp(int(skill.get("wand_control", 0)) + gain, 0, WIZARD_LEVEL_MAX)
	xp ["practice"] = int(xp.get("practice", 0)) + gain
	xp ["study"] = int(xp.get("study", 0)) + max(1, _int_div_floor(gain, 2))

	profile ["skill"] = skill
	profile ["xp"] = xp
	profile = _sync_spell_unlocks(actor, profile)
	actor.wizard_profile = profile.duplicate(true)


func _sync_spell_unlocks(actor: Person, profile: Dictionary) -> Dictionary:
	var known_spells: Array = _safe_array(profile.get("known_spells", []))
	var unlocked: Array = _resolve_unlocked_spell_ids(profile)

	for spell_id in unlocked:
		if spell_id not in known_spells:
			known_spells.append(spell_id)
			_record_wizard_awakening(actor, spell_id)

	profile ["known_spells"] = known_spells
	return profile


func _resolve_unlocked_spell_ids(profile: Dictionary) -> Array:
	var out: Array = []
	var skill: Dictionary = _safe_dictionary(profile.get("skill", {}))
	var wand: Dictionary = _safe_dictionary(profile.get("wand", {}))
	var spellcraft: int = int(skill.get("spellcraft", 0))
	var theory: int = int(skill.get("spell_theory", 0))
	var wand_level: int = int(wand.get("level", 1))

	for raw_spell in _spell_catalog():
		if typeof(raw_spell) != TYPE_DICTIONARY:
			continue
		var spell: Dictionary = raw_spell
		var required_skill: int = int(spell.get("required_skill", 0))
		var required_knowledge: int = int(spell.get("required_knowledge", 0))
		var required_wand: int = int(spell.get("wand_level", 1))

		var school: String = str(spell.get("school", "")).strip_edges().to_lower()
		var school_skill: int = spellcraft
		if school == "dueling":
			school_skill = max(school_skill, int(skill.get("dueling", 0)))
		elif school == "dark_magic":
			school_skill = max(school_skill, int(skill.get("dark_magic", 0)))
		elif school == "energy":
			school_skill = max(school_skill, int(skill.get("energy_balance", 0)))

		if school_skill >= required_skill and theory >= required_knowledge and wand_level >= required_wand:
			out.append(str(spell.get("id", "")))

	return out


func _spell_backfire_check(actor: Person, profile: Dictionary, spell: Dictionary) -> Dictionary:
	var skill: Dictionary = _safe_dictionary(profile.get("skill", {}))
	var wand: Dictionary = _safe_dictionary(profile.get("wand", {}))
	var spellcraft: int = int(skill.get("spellcraft", 0))
	var wand_stability: int = int(wand.get("stability", 65))
	var required_skill: int = int(spell.get("required_skill", 0))
	var risk: int = clamp(required_skill - spellcraft + _int_div_floor(100 - wand_stability, 4), 0, 85)

	if randi_range(1, 100) > risk:
		return {
			"backfired": false,
			"profile": profile.duplicate(true)
		}

	var damage: int = clamp(5 + _int_div_floor(risk, 3), 5, 45)
	actor.health = max(0.0, float(actor.health) - float(damage))

	var energy: Dictionary = _safe_dictionary(profile.get("energy", {}))
	energy ["instability"] = clamp(int(energy.get("instability", 0)) + _int_div_floor(risk, 2), 0, 100)
	profile ["energy"] = energy

	return {
		"backfired": true,
		"profile": profile.duplicate(true),
		"text": "The spell backfired and burned through your energy flow."
	}


func _add_conjured_food(actor: Person, spell_id: String) -> void:
	if actor == null or gs == null:
		return

	var food_item: Dictionary = {
		"id": "wizard_%s_%d" % [spell_id, int(Time.get_ticks_msec())],
		"name": "Wizard Burger Combo",
		"display_name": "Wizard Burger Combo",
		"type": "Fast Food",
		"subtype": "Conjured Meal",
		"quantity": 1,
		"value": 12,
		"quality": 70,
		"acquired_year": _current_year(),
		"shelf_life_years": 1
	}

	if gs.food_engine != null and gs.food_engine.has_method("add_pantry_item"):
		gs.food_engine.add_pantry_item(actor, food_item, 1, {
			"source": "wizard_spell",
			"spell_id": spell_id
		})
	elif gs.belongings_engine != null and gs.belongings_engine.has_method("add_item"):
		gs.belongings_engine.add_item(actor, food_item, "Food", false)


func _apply_human_marriage_rule(wizard_actor: Person, spouse_actor: Person) -> void:
	if wizard_actor == null or spouse_actor == null:
		return

	var profile: Dictionary = ensure_wizard_profile(wizard_actor, {
		"source": "human_marriage_rule"
	})

	if not bool(profile.get("full_wizard", false)):
		return
	if not has_wizard_magic(wizard_actor):
		return
	if has_wizard_magic(spouse_actor):
		return

	var spouse_profile: Dictionary = ensure_wizard_profile(spouse_actor, {
		"source": "human_marriage_spouse_check"
	})
	if bool(spouse_profile.get("is_wizard", false)):
		return

	profile ["magic_status"] = "lost_by_human_marriage"
	profile ["full_wizard"] = false

	var council: Dictionary = _safe_dictionary(profile.get("council", {}))
	council ["marriage_power_loss_year"] = _current_year()
	council ["marriage_power_loss_spouse_id"] = int(spouse_actor.id)
	profile ["council"] = council

	wizard_actor.wizard_profile = profile.duplicate(true)

	var text: String = "I married a full human and felt my full wizard power leave me."
	_remember(wizard_actor, text)


func _make_full_wizard(actor: Person, profile: Dictionary, source: String) -> Dictionary:
	profile ["full_wizard"] = true
	profile ["magic_status"] = "active"
	profile ["wizard_blood_status"] = "full"

	var energy: Dictionary = _safe_dictionary(profile.get("energy", {}))
	energy ["magic"] = 100
	energy ["flow_balance"] = max(80, int(energy.get("flow_balance", 100)))
	profile ["energy"] = energy

	var competition: Dictionary = _safe_dictionary(profile.get("competition", {}))
	competition ["resolved"] = true
	competition ["result"] = "won"
	competition ["champion_year"] = _current_year()
	competition ["source"] = source
	profile ["competition"] = competition

	_add_trait_once(actor, "Full Wizard")
	return profile


func _seal_family_magic(actor: Person, reason: String) -> void:
	if actor == null:
		return

	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "seal_family_magic"
	})
	profile ["magic_status"] = "sealed"
	profile ["full_wizard"] = false

	var council: Dictionary = _safe_dictionary(profile.get("council", {}))
	council ["sealed_reason"] = reason
	council ["sealed_year"] = _current_year()
	profile ["council"] = council

	actor.wizard_profile = profile.duplicate(true)


func _balance_chi_and_magic(actor: Person, profile: Dictionary) -> Dictionary:
	if actor == null:
		return profile

	var energy: Dictionary = _safe_dictionary(profile.get("energy", {}))
	var magic_value: int = int(energy.get("magic", 40))
	var chi_value: int = 0

	if str(actor.bending_type).strip_edges().to_lower() != "" and str(actor.bending_type).strip_edges().to_lower() != "none":
		chi_value = 35 + int(actor.bending_mastery.get(str(actor.bending_type), 0))
	elif typeof(actor.bending_mastery) == TYPE_DICTIONARY:
		for key in actor.bending_mastery.keys():
			chi_value = max(chi_value, int(actor.bending_mastery.get(key, 0)))

	energy ["chi"] = chi_value

	var overload_threshold: int = int(_safe_dictionary(_safe_dictionary(active_contract.get("cross_systems", {}))).get("chi_magic_overload_threshold", 140))
	var combined: int = magic_value + chi_value
	if combined > overload_threshold:
		var overage: int = combined - overload_threshold
		energy ["instability"] = clamp(int(energy.get("instability", 0)) + _int_div_floor(overage, 4), 0, 100)
		energy ["flow_balance"] = clamp(100 - _int_div_floor(overage, 2), 0, 100)
	else:
		energy ["flow_balance"] = clamp(int(energy.get("flow_balance", 100)) + 1, 0, 100)

	profile ["energy"] = energy
	return profile


func _competition_score(actor: Person) -> int:
	var profile: Dictionary = ensure_wizard_profile(actor, {
		"source": "competition_score"
	})
	var skill: Dictionary = _safe_dictionary(profile.get("skill", {}))
	var wand: Dictionary = _safe_dictionary(profile.get("wand", {}))

	var base: int = int(actor.smarts * 0.35) \
+ int(actor.imagination * 0.3) \
+ int(actor.ambition * 0.15) \
+ int(skill.get("spellcraft", 0)) \
+ int(skill.get("spell_theory", 0)) \
+ int(skill.get("dueling", 0)) \
+ int(wand.get("level", 1)) * 2

	return base + randi_range(1, 50)


func _duel_power(actor: Person, profile: Dictionary) -> int:
	var skill: Dictionary = _safe_dictionary(profile.get("skill", {}))
	var wand: Dictionary = _safe_dictionary(profile.get("wand", {}))
	return _int_div_floor(actor.smarts, 3) \
+ _int_div_floor(actor.imagination, 3) \
+ int(skill.get("spellcraft", 0)) \
+ int(skill.get("dueling", 0)) \
+ int(skill.get("wand_control", 0)) \
+ int(wand.get("level", 1)) * 2 \
+ int(wand.get("power", 8))


func _raise_council_heat(profile: Dictionary, amount: int) -> void:
	var council: Dictionary = _safe_dictionary(profile.get("council", {}))
	council ["heat"] = clamp(int(council.get("heat", 0)) + max(1, amount), 0, 100)
	profile ["council"] = council


func _record_wizard_awakening(actor: Person, spell_id: String) -> void:
	if actor == null:
		return

	var spell: Dictionary = get_spell_by_id(spell_id)
	var spell_name: String = str(spell.get("name", spell_id)).strip_edges()
	if spell_name == "":
		spell_name = spell_id

	var text: String = "I learned %s." % spell_name
	_remember(actor, text)

	if gs != null and gs.has_method("make_world_feed_entry") and gs.world_feed != null:
		if int(spell.get("required_skill", 0)) >= 50 or str(spell.get("tier", "")) == "forbidden":
			gs.world_feed.insert(0, gs.make_world_feed_entry("%s learned %s." % [_person_name(actor), spell_name], {
				"category": "wizard_magic",
				"event_name": "spell_unlocked",
				"npc_id": int(actor.id),
				"spell_id": spell_id
			}))


func _normalize_wizard_profile(actor: Person, profile: Dictionary, _context: Dictionary = {}) -> Dictionary:
	var skill: Dictionary = _safe_dictionary(profile.get("skill", {}))
	for key in ["spellcraft", "wand_control", "spell_theory", "dueling", "artifact_lore", "dark_magic", "energy_balance"]:
		skill [key] = clamp(int(skill.get(key, 0)), 0, WIZARD_LEVEL_MAX)
	profile ["skill"] = skill

	var wand: Dictionary = _safe_dictionary(profile.get("wand", {}))
	if wand.is_empty():
		wand = _safe_dictionary(_safe_dictionary(active_contract.get("wand", {})).get("starter", {}))
	wand ["level"] = clamp(int(wand.get("level", 1)), 1, WAND_LEVEL_MAX)
	wand ["stability"] = clamp(int(wand.get("stability", 65)), 1, 100)
	wand ["power"] = clamp(int(wand.get("power", 8)), 1, 100)
	profile ["wand"] = wand

	var competition: Dictionary = _safe_dictionary(profile.get("competition", {}))
	if int(actor.age) >= COMPETITION_AGE and bool(profile.get("is_wizard", false)) and not bool(competition.get("resolved", false)):
		competition ["available"] = true
	profile ["competition"] = competition

	profile ["last_updated_year"] = _current_year()
	return _make_binary_safe(profile)


func _seed_adult_skill_profile(actor: Person, _profile: Dictionary) -> Dictionary:
	var base: int = clamp(35 + _int_div_floor(actor.smarts, 3) + _int_div_floor(actor.imagination, 5), 20, 96)
	return {
		"spellcraft": clamp(base + randi_range(-8, 8), 0, WIZARD_LEVEL_MAX),
		"wand_control": clamp(base + randi_range(-6, 10), 0, WIZARD_LEVEL_MAX),
		"spell_theory": clamp(base + randi_range(-4, 14), 0, WIZARD_LEVEL_MAX),
		"dueling": clamp(base + randi_range(-10, 12), 0, WIZARD_LEVEL_MAX),
		"artifact_lore": clamp(base + randi_range(-12, 10), 0, WIZARD_LEVEL_MAX),
		"dark_magic": clamp(randi_range(0, 28), 0, WIZARD_LEVEL_MAX),
		"energy_balance": clamp(55 + randi_range(-10, 18), 0, WIZARD_LEVEL_MAX)
	}


func _seed_child_skill_profile(actor: Person, _profile: Dictionary) -> Dictionary:
	var age_factor: int = clamp(int(actor.age) * 3, 0, 45)
	return {
		"spellcraft": clamp(age_factor + randi_range(0, 10), 0, WIZARD_LEVEL_MAX),
		"wand_control": clamp(age_factor + randi_range(0, 12), 0, WIZARD_LEVEL_MAX),
		"spell_theory": clamp(age_factor + randi_range(0, 12), 0, WIZARD_LEVEL_MAX),
		"dueling": clamp(age_factor + randi_range(0, 9), 0, WIZARD_LEVEL_MAX),
		"artifact_lore": clamp(age_factor + randi_range(0, 8), 0, WIZARD_LEVEL_MAX),
		"dark_magic": clamp(randi_range(0, 8), 0, WIZARD_LEVEL_MAX),
		"energy_balance": clamp(45 + randi_range(-10, 12), 0, WIZARD_LEVEL_MAX)
	}


func _pick_wizard_archetype(actor: Person) -> String:
	if actor == null:
		return "scholar"
	if int(actor.ambition) >= 75 and randi() % 100 < 28:
		return "dark_adept"
	if int(actor.smarts) >= int(actor.imagination):
		return "scholar"
	if int(actor.imagination) >= 75:
		return "chaos_caster"
	if int(actor.health) >= 80:
		return "duelist"
	return ["scholar", "duelist", "healer", "chaos_caster"] [randi() % 4]


func _weighted_family_rank() -> String:
	var roll: int = randi_range(1, 100)
	if roll >= 98:
		return "ancient"
	if roll >= 88:
		return "elite"
	if roll >= 55:
		return "established"
	return "minor"


func _spell_catalog() -> Array:
	var spells: Dictionary = _safe_dictionary(active_contract.get("spells", {}))
	var catalog_raw: Variant = spells.get("catalog", [])
	if typeof(catalog_raw) == TYPE_ARRAY:
		return (catalog_raw as Array).duplicate(true)
	return _build_spell_catalog()


func _has_wizard_parent(actor: Person) -> bool:
	if actor == null:
		return false
	for parent_raw in _resolve_birth_parents(actor):
		var parent_actor: Person = parent_raw as Person
		if parent_actor != null and typeof(parent_actor.wizard_profile) == TYPE_DICTIONARY:
			if bool(parent_actor.wizard_profile.get("is_wizard", false)):
				return true
	return false


func _resolve_birth_parents(actor: Person) -> Array:
	var out: Array = []
	if actor == null or gs == null:
		return out
	for raw_parent_id in actor.parents:
		var parent_actor: Person = _get_npc(int(raw_parent_id))
		if parent_actor != null:
			out.append(parent_actor)
	return out


func _sibling_ids(actor: Person) -> Array:
	var out: Array = []
	if actor == null or gs == null:
		return out

	for raw_npc in gs.npcs:
		var npc: Person = raw_npc as Person
		if npc == null or npc == actor:
			continue
		if int(npc.id) == int(actor.id):
			continue
		if npc.parents == actor.parents and not actor.parents.is_empty():
			if int(npc.id) not in out:
				out.append(int(npc.id))

	return out


func _resolve_person_from_payload(payload) -> Person:
	if payload is Person:
		return payload

	if typeof(payload) == TYPE_DICTIONARY:
		var row: Dictionary = payload
		if row.has("npc") and row.get("npc") is Person:
			return row.get("npc")
		if row.has("person") and row.get("person") is Person:
			return row.get("person")
		var npc_id: int = int(row.get("npc_id", row.get("person_id", -1)))
		return _get_npc(npc_id)

	return null


func _resolve_marriage_pair(payload) -> Array:
	var out: Array = []
	if typeof(payload) != TYPE_DICTIONARY:
		return out

	var row: Dictionary = payload
	var first_id: int = int(row.get("npc_id", row.get("person_id", row.get("a_id", -1))))
	var second_id: int = int(row.get("spouse_id", row.get("partner_id", row.get("b_id", -1))))

	var first_actor: Person = _get_npc(first_id)
	var second_actor: Person = _get_npc(second_id)

	if first_actor == null and row.get("npc") is Person:
		first_actor = row.get("npc")
	if second_actor == null and row.get("spouse") is Person:
		second_actor = row.get("spouse")
	if second_actor == null and row.get("partner") is Person:
		second_actor = row.get("partner")

	if first_actor != null:
		out.append(first_actor)
	if second_actor != null:
		out.append(second_actor)

	return out


func _get_npc(npc_id: int) -> Person:
	if gs == null or npc_id <= 0:
		return null
	if gs.has_method("get_npc_by_id"):
		return gs.get_npc_by_id(npc_id)
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc as Person
		if npc != null and int(npc.id) == npc_id:
			return npc
	return null


func _remember(actor: Person, text: String) -> void:
	if actor == null:
		return
	var clean_text: String = str(text).strip_edges()
	if clean_text == "":
		return

	if gs != null and gs.consciousness_engine != null and gs.consciousness_engine.has_method("remember"):
		gs.consciousness_engine.remember(actor, clean_text, {
			"source": "wizard_engine",
			"memory_type": "wizard_magic",
			"emotion_tags": ["magic", "family", "pressure"]
		})
	elif actor.memories != null and clean_text not in actor.memories:
		actor.memories.append(clean_text)


func _result(success: bool, title: String, popup_text: String, actor: Person = null, extra: Dictionary = {}) -> Dictionary:
	var out: Dictionary = extra.duplicate(true)
	out ["success"] = success
	out ["popup_title"] = title
	out ["popup_text"] = popup_text
	out ["popup_footer"] = "Tap anywhere to continue."
	if actor != null:
		out ["actor_id"] = int(actor.id)
		out ["actor_name"] = _person_name(actor)
	if not out.has("text"):
		out ["text"] = popup_text
	_commit_report(out)
	return out


func _commit_report(report: Dictionary) -> void:
	var safe_report: Dictionary = _make_binary_safe(report)
	wizard_reports.append(safe_report)
	while wizard_reports.size() > 120:
		wizard_reports.pop_front()
	last_contract_report = safe_report.duplicate(true)


func _person_name(actor: Person) -> String:
	if actor == null:
		return "Someone"
	var full_name: String = ("%s %s" % [str(actor.first_name), str(actor.last_name)]).strip_edges()
	if full_name == "":
		full_name = str(actor.name).strip_edges()
	if full_name == "":
		full_name = "Someone"
	return full_name


func _current_year() -> int:
	if gs == null:
		return 0
	return int(gs.year)


func _add_trait_once(actor: Person, trait_text: String) -> void:
	if actor == null:
		return
	var clean_trait: String = str(trait_text).strip_edges()
	if clean_trait == "":
		return
	if clean_trait not in actor.traits:
		actor.traits.append(clean_trait)


func _safe_dictionary(value: Variant) -> Dictionary:
	return EraUtils.safe_dictionary(value)

func _int_div_floor(value: Variant, divisor: Variant) -> int:
	var clean_divisor: float = max(0.001, float(divisor))
	return int(floor(float(value) / clean_divisor))
func _safe_array(value: Variant) -> Array:
	return EraUtils.safe_array(value)


func _merge_dict(base: Dictionary, patch: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key in patch.keys():
		var patch_value: Variant = patch.get(key)
		if typeof(patch_value) == TYPE_DICTIONARY and typeof(out.get(key, {})) == TYPE_DICTIONARY:
			out [key] = _merge_dict(out.get(key, {}), patch_value)
		else:
			out [key] = patch_value
	return out


func _make_binary_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var out: Dictionary = {}
			for key in value.keys():
				out [str(key)] = _make_binary_safe(value [key])
			return out
		TYPE_ARRAY:
			var arr: Array = []
			for item in value:
				arr.append(_make_binary_safe(item))
			return arr
		TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL:
			return value
		TYPE_NIL:
			return null
		_:
			return str(value)