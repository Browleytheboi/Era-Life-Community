extends Resource
class_name PersonalityEngine
var gs

func _init(_gs):
	gs = _gs

func generate_traits(npc: Person = null):
	var all_traits = [
		"Introvert", "Extrovert",
		"Loyal", "Impulsive",
		"Calm", "Jealous",
		"Kind", "Mean"
	]


	if npc == null:
		return

	var place_drift: Dictionary = {}
	if gs != null and gs.place_influence_engine != null:
		place_drift = gs.place_influence_engine.get_trait_drift(npc)
		_apply_place_trait_profile(npc, place_drift)


	if npc.traits.size() >= 3:
		return

	var roll_bonus: int = 0
	if typeof(place_drift) == TYPE_DICTIONARY:
		var profile_deltas: Dictionary = place_drift.get("profile_deltas", {})
		roll_bonus = int(clamp(
			abs(float(profile_deltas.get("aggression", 0.0))) +
			abs(float(profile_deltas.get("discipline", 0.0))) +
			abs(float(profile_deltas.get("volatility", 0.0))),
			0.0,
			12.0
		))


	if randi() % 100 > (25 + roll_bonus):
		return

	var weighted_traits: Dictionary = _build_place_weighted_traits(npc, all_traits, place_drift)
	var pick: String = _pick_weighted_trait(all_traits, weighted_traits)
	if pick == "":
		pick = all_traits [randi() % all_traits.size()]

	if pick not in npc.traits:
		npc.traits.append(pick)
func _apply_place_trait_profile(npc: Person, place_drift: Dictionary) -> void:
	if npc == null or typeof(place_drift) != TYPE_DICTIONARY:
		return

	var profile: Dictionary = {}
	if typeof(npc.place_trait_drift_profile) == TYPE_DICTIONARY:
		profile = npc.place_trait_drift_profile.duplicate(true)

	for key in ["aggression", "discipline", "romance_style", "caution", "loyalty", "volatility"]:
		profile [key] = clamp(float(profile.get(key, 50.0)) + float(place_drift.get("profile_deltas", {}).get(key, 0.0)), 0.0, 100.0)

	npc.place_trait_drift_profile = profile
	npc.ambition = clamp(float(npc.ambition) + float(place_drift.get("ambition_delta", 0.0)), 0.0, 100.0)

func _build_place_weighted_traits(_npc: Person, all_traits: Array, place_drift: Dictionary) -> Dictionary:
	var weights: Dictionary = {}
	for raw_trait in all_traits:
		weights [str(raw_trait)] = 1.0

	if typeof(place_drift) != TYPE_DICTIONARY:
		return weights

	var profile_deltas: Dictionary = place_drift.get("profile_deltas", {})
	var aggression: float = float(profile_deltas.get("aggression", 0.0))
	var discipline: float = float(profile_deltas.get("discipline", 0.0))
	var romance_style: float = float(profile_deltas.get("romance_style", 0.0))
	var caution: float = float(profile_deltas.get("caution", 0.0))
	var loyalty: float = float(profile_deltas.get("loyalty", 0.0))
	var volatility: float = float(profile_deltas.get("volatility", 0.0))

	weights ["Impulsive"] += max(0.0, aggression * 0.6) + max(0.0, volatility * 0.8)
	weights ["Mean"] += max(0.0, aggression * 0.8)
	weights ["Calm"] += max(0.0, discipline * 0.7) + max(0.0, caution * 0.3)
	weights ["Loyal"] += max(0.0, loyalty * 0.8) + max(0.0, discipline * 0.2)
	weights ["Kind"] += max(0.0, romance_style * 0.5) + max(0.0, loyalty * 0.5) - max(0.0, aggression * 0.35)
	weights ["Extrovert"] += max(0.0, romance_style * 0.7)
	weights ["Introvert"] += max(0.0, caution * 0.5)
	weights ["Jealous"] += max(0.0, volatility * 0.75) + max(0.0, romance_style * 0.2)

	var suggested_traits: Array = place_drift.get("suggested_traits", [])
	if typeof(suggested_traits) == TYPE_ARRAY:
		for raw_trait in suggested_traits:
			var trait_name: String = str(raw_trait)
			weights [trait_name] = float(weights.get(trait_name, 1.0)) + 1.5

	return weights

func _pick_weighted_trait(all_traits: Array, weights: Dictionary) -> String:
	var total_weight: float = 0.0
	for raw_trait in all_traits:
		total_weight += max(0.0, float(weights.get(str(raw_trait), 0.0)))

	if total_weight <= 0.0:
		return ""

	var roll: float = randf() * total_weight
	var running: float = 0.0
	for raw_trait in all_traits:
		var trait_name: String = str(raw_trait)
		running += max(0.0, float(weights.get(trait_name, 0.0)))
		if roll <= running:
			return trait_name

	return ""