extends Resource
class_name PlaceInfluenceEngine

var gs

const MAX_YEARLY_SNAPSHOTS:= 12
const MAX_ECHO_STACK:= 6
const MAX_MEMORY_TAGS:= 10

const PRESSURE_CHANNELS:= [
	"violence",
	"romance",
	"ambition",
	"fame_drive",
	"risk",
	"discipline",
	"spirituality",
	"social_openness",
	"instability"
]

const DEFAULT_IDENTITY_RESIDUE:= {
	"birthplace_pride": 0.0,
	"homesickness": 0.0,
	"diaspora_belonging": 0.0,
	"local_acceptance": 0.0,
	"prejudice_exposure": 0.0,
	"nostalgia": 0.0,
	"return_home_pull": 0.0,
	"foreign_prestige": 0.0,
	"split_family_identity": 0.0,
	"language_drift": 0.0,
	"culture_drift": 0.0,
	"exile_weight": 0.0,
	"refugee_trauma": 0.0,
	"celebrity_transplant_heat": 0.0,
	"migrant_boxer_edge": 0.0
}

func _init(_gs):
	gs = _gs

func yearly_tick(_payload:= {}) -> void:
	if gs == null:
		return
	for raw_npc in gs.npcs:
		var npc: Person = raw_npc
		if npc == null:
			continue
		refresh_npc(npc, true)

func on_npc_born(payload: Dictionary) -> void:
	if gs == null:
		return
	var npc_id: int = int(payload.get("npc_id", -1))
	if npc_id <= 0:
		return
	var npc: Person = gs.get_or_reactivate_npc_by_id(npc_id)
	if npc == null:
		return
	npc.years_in_current_place = 0
	npc.total_place_moves = int(npc.migration_history.size())
	npc.last_place_shift_year = int(gs.year)
	refresh_npc(npc, false)

func on_npc_moved(payload: Dictionary) -> void:
	if gs == null:
		return
	var npc_id: int = int(payload.get("npc_id", -1))
	if npc_id <= 0:
		return
	var npc: Person = gs.get_or_reactivate_npc_by_id(npc_id)
	if npc == null:
		return
	npc.years_in_current_place = 0
	npc.total_place_moves = int(npc.migration_history.size())
	npc.last_place_shift_year = int(gs.year)
	refresh_npc(npc, false)

func refresh_npc(npc: Person, advance_residency:= true) -> Dictionary:
	if npc == null or gs == null:
		return {}

	_ensure_place_fields(npc)

	if gs.geo_engine != null and str(npc.settlement_id).strip_edges() == "":
		gs.geo_engine.bootstrap_person_place(npc)

	var current_settlement_id: String = str(npc.settlement_id).strip_edges()
	if current_settlement_id == "":
		return {}

	var previous_summary: Dictionary = {}
	if typeof(npc.place_identity_summary) == TYPE_DICTIONARY:
		previous_summary = npc.place_identity_summary

	var previous_settlement_id: String = str(previous_summary.get("current_settlement_id", ""))
	if advance_residency:
		if previous_settlement_id == "":
			npc.years_in_current_place = max(1, int(npc.years_in_current_place))
		elif previous_settlement_id == current_settlement_id:
			npc.years_in_current_place += 1
		else:
			npc.years_in_current_place = 1

	var current_packet: Dictionary = {}
	if gs.geo_engine != null:
		current_packet = gs.geo_engine.get_place_packet(current_settlement_id)

	var current_vector: Dictionary = _vector_from_packet(current_packet)
	var echo_stack: Array = _build_echo_stack(npc, current_settlement_id)
	var echo_vector: Dictionary = _collapse_echo_stack(echo_stack)
	var conflict_profile: Dictionary = _build_conflict_profile(npc, current_vector, echo_vector)
	var influence_strength: float = _compute_influence_strength(npc, conflict_profile)
	var residue_deltas: Dictionary = _build_identity_residue_deltas(npc, current_vector, conflict_profile)
	var trait_drift: Dictionary = _build_trait_drift_profile(npc, current_vector, conflict_profile)
	var adaptation_flags: Array = _build_adaptation_flags(npc, conflict_profile, influence_strength)
	var memory_tags: Array = _build_memory_tags(npc, current_packet, current_vector, conflict_profile, adaptation_flags)

	_apply_identity_residue_deltas(npc, residue_deltas)

	npc.place_echo_stack = echo_stack.duplicate(true)
	npc.place_conflict_profile = conflict_profile.duplicate(true)
	npc.place_trait_drift_profile = trait_drift.duplicate(true)
	npc.place_influence_strength = influence_strength
	npc.place_identity_tags = memory_tags.duplicate()
	npc.place_adaptation_flags = adaptation_flags.duplicate()

	npc.place_influence_profile = {
		"pressure_channels": current_vector.duplicate(true),
		"echo_pressure_channels": echo_vector.duplicate(true),
		"current_place_packet": current_packet.duplicate(true),
		"identity_residue_deltas": residue_deltas.duplicate(true),
		"dominant_channels": _top_channels(current_vector, 3),
		"conflict_total": float(conflict_profile.get("total", 0.0)),
		"influence_strength": influence_strength
	}

	npc.place_identity_summary = {
		"current_settlement_id": current_settlement_id,
		"current_place_name": str(npc.home_city),
		"birthplace_settlement_id": str(npc.birthplace_settlement_id),
		"origin_settlement_id": str(npc.origin_settlement_id),
		"years_in_current_place": int(npc.years_in_current_place),
		"total_place_moves": int(npc.total_place_moves),
		"dominant_channels": _top_channels(current_vector, 3),
		"pressure_vector": current_vector.duplicate(true),
		"echo_vector": echo_vector.duplicate(true),
		"conflict_profile": conflict_profile.duplicate(true),
		"influence_strength": influence_strength,
		"adaptation_flags": adaptation_flags.duplicate(),
		"memory_tags": memory_tags.duplicate(),
		"current_place_packet": current_packet.duplicate(true)
	}

	_append_yearly_snapshot(npc)

	return npc.place_identity_summary.duplicate(true)

func get_desire_bias(npc: Person) -> Dictionary:
	if npc == null:
		return {}
	if typeof(npc.place_identity_summary) != TYPE_DICTIONARY or npc.place_identity_summary.is_empty():
		refresh_npc(npc, false)

	var profile: Dictionary = npc.place_influence_profile if typeof(npc.place_influence_profile) == TYPE_DICTIONARY else {}
	var pressure: Dictionary = profile.get("pressure_channels", {})
	var packet: Dictionary = profile.get("current_place_packet", {})
	var conflict: Dictionary = npc.place_conflict_profile if typeof(npc.place_conflict_profile) == TYPE_DICTIONARY else {}

	var ambition: float = float(pressure.get("ambition", 0.0))
	var fame_drive: float = float(pressure.get("fame_drive", 0.0))
	var romance: float = float(pressure.get("romance", 0.0))
	var risk: float = float(pressure.get("risk", 0.0))
	var discipline: float = float(pressure.get("discipline", 0.0))
	var spirituality: float = float(pressure.get("spirituality", 0.0))
	var instability: float = float(pressure.get("instability", 0.0))
	var social_openness: float = float(pressure.get("social_openness", 0.0))
	var violence: float = float(pressure.get("violence", 0.0))

	var belonging_strain: float = float(conflict.get("belonging_strain", 0.0))
	var motivation_delta: float = ((discipline + ambition + spirituality * 0.55) - (instability * 0.9) - (belonging_strain * 0.8)) * 3.0
	var ambition_delta: float = ((ambition * 1.25) + (fame_drive * 0.75) + (float(packet.get("job_market", 0.5)) * 0.65) - (spirituality * 0.15)) * 2.5

	return {
		"motivation_delta": clamp(motivation_delta, -6.0, 6.0),
		"ambition_delta": clamp(ambition_delta, -5.0, 6.0),
		"impulse_weights": {
			"StartFight": violence * 4.0 + instability * 3.0,
			"CommitCrime": risk * 5.0 + instability * 3.5 + float(packet.get("crime_pressure", 0.0)) * 4.0,
			"Flirt": romance * 5.0 + social_openness * 3.0,
			"ConfessLove": romance * 4.5 + spirituality * 1.0,
			"Travel": social_openness * 3.5 + float(conflict.get("return_home_pull", 0.0)) * 2.0,
			"Train": discipline * 4.5 + float(packet.get("boxing_density", 0.0)) * 2.0,
			"SelfImprove": discipline * 4.5 + ambition * 2.5 + float(packet.get("school_quality", 0.0)) * 2.0,
			"QuitJob": belonging_strain * 4.0 + instability * 2.0,
			"BuySomething": fame_drive * 2.5 + ambition * 2.0
		},
		"goal_weights": {
			"GainPoliticalInfluence": float(packet.get("royal_influence", 0.0)) * 6.0 + ambition * 2.0,
			"IncreaseNetWorth": ambition * 4.0 + float(packet.get("job_market", 0.0)) * 4.0,
			"BecomeFamous": fame_drive * 6.0 + float(packet.get("fame_concentration", 0.0)) * 4.0,
			"FindPartner": romance * 5.0 + social_openness * 2.0,
			"HaveChild": spirituality * 2.0 + romance * 2.5,
			"ImproveSmarts": discipline * 4.5 + float(packet.get("school_quality", 0.0)) * 4.0,
			"TravelWorld": social_openness * 3.0 + float(conflict.get("return_home_pull", 0.0)) * 1.5,
			"DisruptOrder": instability * 5.0 + violence * 2.5
		},
		"place_tags": get_memory_place_tags(npc)
	}

func get_trait_drift(npc: Person) -> Dictionary:
	if npc == null:
		return {}
	if typeof(npc.place_identity_summary) != TYPE_DICTIONARY or npc.place_identity_summary.is_empty():
		refresh_npc(npc, false)

	var profile: Dictionary = npc.place_influence_profile if typeof(npc.place_influence_profile) == TYPE_DICTIONARY else {}
	var pressure: Dictionary = profile.get("pressure_channels", {})
	var conflict: Dictionary = npc.place_conflict_profile if typeof(npc.place_conflict_profile) == TYPE_DICTIONARY else {}
	var residue: Dictionary = npc.identity_residue if typeof(npc.identity_residue) == TYPE_DICTIONARY else {}

	var aggression_delta: float = (float(pressure.get("violence", 0.0)) * 2.4) + (float(pressure.get("risk", 0.0)) * 1.2) - (float(pressure.get("discipline", 0.0)) * 1.2)
	var discipline_delta: float = (float(pressure.get("discipline", 0.0)) * 2.8) - (float(pressure.get("instability", 0.0)) * 1.5)
	var romance_style_delta: float = (float(pressure.get("romance", 0.0)) * 2.6) + (float(pressure.get("social_openness", 0.0)) * 1.1)
	var caution_delta: float = (float(pressure.get("instability", 0.0)) * 2.0) + (float(conflict.get("belonging_strain", 0.0)) * 1.6) - (float(pressure.get("social_openness", 0.0)) * 0.6)
	var loyalty_delta: float = (float(pressure.get("spirituality", 0.0)) * 1.2) + (float(pressure.get("discipline", 0.0)) * 0.8) + (float(residue.get("diaspora_belonging", 0.0)) * 0.03)
	var volatility_delta: float = (float(pressure.get("instability", 0.0)) * 2.3) + (float(conflict.get("total", 0.0)) * 1.5) - (float(pressure.get("discipline", 0.0)) * 0.8)

	var suggested_traits: Array = []
	if aggression_delta > 1.3:
		suggested_traits.append("Impulsive")
	if discipline_delta > 1.2:
		suggested_traits.append("Calm")
	if loyalty_delta > 1.1:
		suggested_traits.append("Loyal")
	if romance_style_delta > 1.0:
		suggested_traits.append("Extrovert")
	if volatility_delta > 1.3:
		suggested_traits.append("Jealous")
	if caution_delta > 1.2 and "Calm" not in suggested_traits:
		suggested_traits.append("Introvert")

	return {
		"ambition_delta": clamp((float(pressure.get("ambition", 0.0)) * 2.0) - (float(conflict.get("nostalgia_pull", 0.0)) * 1.0), -3.0, 4.0),
		"profile_deltas": {
			"aggression": aggression_delta,
			"discipline": discipline_delta,
			"romance_style": romance_style_delta,
			"caution": caution_delta,
			"loyalty": loyalty_delta,
			"volatility": volatility_delta
		},
		"suggested_traits": suggested_traits
	}

func get_scenario_bias(npc: Person) -> Dictionary:
	if npc == null:
		return {}
	if typeof(npc.place_identity_summary) != TYPE_DICTIONARY or npc.place_identity_summary.is_empty():
		refresh_npc(npc, false)

	var profile: Dictionary = npc.place_influence_profile if typeof(npc.place_influence_profile) == TYPE_DICTIONARY else {}
	var pressure: Dictionary = profile.get("pressure_channels", {})
	var packet: Dictionary = profile.get("current_place_packet", {})
	var conflict: Dictionary = npc.place_conflict_profile if typeof(npc.place_conflict_profile) == TYPE_DICTIONARY else {}
	var tag_weights: Dictionary = {}
	for tag in get_memory_place_tags(npc):
		tag_weights [str(tag)] = float(tag_weights.get(str(tag), 0.0)) + 1.0

	return {
		"place_pressure": pressure.duplicate(true),
		"place_conflict": conflict.duplicate(true),
		"place_tag_weights": tag_weights.duplicate(true),
		"place_tags": get_memory_place_tags(npc),
		"place_identity_summary": get_place_identity_summary(npc),
		"current_place_packet": packet.duplicate(true),
		"category_weights": {
			"school": float(packet.get("school_quality", 0.0)) * 4.0 + float(pressure.get("discipline", 0.0)) * 3.0,
			"boxing": float(packet.get("boxing_density", 0.0)) * 5.0 + float(pressure.get("fame_drive", 0.0)) * 2.0,
			"crime": float(packet.get("crime_pressure", 0.0)) * 5.0 + float(pressure.get("instability", 0.0)) * 3.0,
			"career": float(packet.get("job_market", 0.0)) * 4.0 + float(pressure.get("ambition", 0.0)) * 3.0,
			"social": float(pressure.get("romance", 0.0)) * 3.0 + float(pressure.get("social_openness", 0.0)) * 4.0,
			"afterlife": float(pressure.get("spirituality", 0.0)) * 4.0 + float(packet.get("supernatural_presence", 0.0)) * 4.0,
			"general": float(conflict.get("total", 0.0)) * 2.5 + float(pressure.get("instability", 0.0)) * 1.5
		}
	}

func get_opportunity_bias(npc: Person) -> Dictionary:
	if npc == null:
		return {}
	if typeof(npc.place_identity_summary) != TYPE_DICTIONARY or npc.place_identity_summary.is_empty():
		refresh_npc(npc, false)

	var profile: Dictionary = npc.place_influence_profile if typeof(npc.place_influence_profile) == TYPE_DICTIONARY else {}
	var pressure: Dictionary = profile.get("pressure_channels", {})
	var packet: Dictionary = profile.get("current_place_packet", {})
	var conflict: Dictionary = npc.place_conflict_profile if typeof(npc.place_conflict_profile) == TYPE_DICTIONARY else {}

	return {
		"action_bias": {
			"Start School": float(packet.get("school_quality", 0.0)) * 6.0 + float(pressure.get("discipline", 0.0)) * 3.5,
			"Enroll In Era School": float(packet.get("school_quality", 0.0)) * 7.0 + float(pressure.get("discipline", 0.0)) * 4.0,
			"Dual Enrollment": float(packet.get("school_quality", 0.0)) * 5.0 + float(pressure.get("ambition", 0.0)) * 3.0,
			"Interact With Classmates": float(pressure.get("social_openness", 0.0)) * 4.0 + float(pressure.get("romance", 0.0)) * 2.0,
			"Apply for Part Time Job": float(packet.get("job_market", 0.0)) * 5.0 + float(pressure.get("discipline", 0.0)) * 2.5,
			"Browse Part Time Jobs": float(packet.get("job_market", 0.0)) * 4.5 + float(pressure.get("ambition", 0.0)) * 2.0,
			"Apply for Full Time Job": float(packet.get("job_market", 0.0)) * 6.0 + float(pressure.get("ambition", 0.0)) * 3.5,
			"Browse Full Time Jobs": float(packet.get("job_market", 0.0)) * 5.5 + float(pressure.get("ambition", 0.0)) * 3.0,
			"Browse Famous Careers": float(packet.get("fame_concentration", 0.0)) * 7.0 + float(pressure.get("fame_drive", 0.0)) * 5.0,
			"Trade On The Silk Road": float(packet.get("job_market", 0.0)) * 3.5 + float(pressure.get("social_openness", 0.0)) * 2.0,
			"Train Bending": float(packet.get("supernatural_presence", 0.0)) * 5.0 + float(pressure.get("spirituality", 0.0)) * 4.0,
			"Start Boxing": float(packet.get("boxing_density", 0.0)) * 8.0 + float(pressure.get("risk", 0.0)) * 1.5 + float(pressure.get("fame_drive", 0.0)) * 2.0,
			"Train Boxing": float(packet.get("boxing_density", 0.0)) * 7.0 + float(pressure.get("discipline", 0.0)) * 2.5,
			"Book Boxing Match": float(packet.get("boxing_density", 0.0)) * 8.0 + float(pressure.get("fame_drive", 0.0)) * 2.5 + float(pressure.get("risk", 0.0)) * 1.5,
			"View Boxing Rivalries": float(packet.get("boxing_density", 0.0)) * 5.0 + float(pressure.get("violence", 0.0)) * 1.0,
			"Call Out Opponent": float(packet.get("boxing_density", 0.0)) * 4.5 + float(pressure.get("fame_drive", 0.0)) * 2.5,
			"Browse Property Market": float(packet.get("job_market", 0.0)) * 2.0 + float(conflict.get("return_home_pull", 0.0)) * 1.2,
			"Browse Vehicle Market": float(packet.get("job_market", 0.0)) * 2.0 + float(pressure.get("social_openness", 0.0)) * 1.2
		},
		"place_tags": get_memory_place_tags(npc)
	}

func get_memory_place_tags(npc: Person) -> Array:
	if npc == null:
		return []
	if typeof(npc.place_identity_summary) != TYPE_DICTIONARY or npc.place_identity_summary.is_empty():
		refresh_npc(npc, false)
	var tags: Array = []
	if typeof(npc.place_identity_tags) == TYPE_ARRAY:
		for raw_tag in npc.place_identity_tags:
			var tag: String = str(raw_tag)
			if tag == "":
				continue
			if tag not in tags:
				tags.append(tag)
	return tags

func get_place_identity_summary(npc: Person) -> Dictionary:
	if npc == null:
		return {}
	if typeof(npc.place_identity_summary) != TYPE_DICTIONARY or npc.place_identity_summary.is_empty():
		refresh_npc(npc, false)
	return npc.place_identity_summary.duplicate(true)

func _ensure_place_fields(npc: Person) -> void:
	if typeof(npc.identity_residue) != TYPE_DICTIONARY:
		npc.identity_residue = {}
	for key in DEFAULT_IDENTITY_RESIDUE.keys():
		npc.identity_residue [key] = float(npc.identity_residue.get(key, DEFAULT_IDENTITY_RESIDUE [key]))

	if typeof(npc.place_echo_stack) != TYPE_ARRAY:
		npc.place_echo_stack = []
	if typeof(npc.place_influence_profile) != TYPE_DICTIONARY:
		npc.place_influence_profile = {}
	if typeof(npc.place_conflict_profile) != TYPE_DICTIONARY:
		npc.place_conflict_profile = {}
	if typeof(npc.place_trait_drift_profile) != TYPE_DICTIONARY:
		npc.place_trait_drift_profile = {}
	if typeof(npc.place_identity_summary) != TYPE_DICTIONARY:
		npc.place_identity_summary = {}
	if typeof(npc.place_yearly_snapshots) != TYPE_ARRAY:
		npc.place_yearly_snapshots = []
	if typeof(npc.place_adaptation_flags) != TYPE_ARRAY:
		npc.place_adaptation_flags = []
	if typeof(npc.place_identity_tags) != TYPE_ARRAY:
		npc.place_identity_tags = []

func _vector_from_packet(packet: Dictionary) -> Dictionary:
	if typeof(packet) != TYPE_DICTIONARY or packet.is_empty():
		return _blank_pressure_vector()

	var public_mood: float = _clamp01((float(packet.get("public_mood", 0.0)) + 1.0) * 0.5)
	var romance_norms: float = _clamp01(float(packet.get("romance_norms", 0.0)))
	var violence_norms: float = _clamp01(float(packet.get("violence_norms", 0.0)))
	var education_emphasis: float = _clamp01(float(packet.get("education_emphasis", 0.5)))
	var social_openness: float = _clamp01(float(packet.get("social_openness", 0.5)))
	var spirituality_pressure: float = _clamp01(float(packet.get("spirituality_pressure", float(packet.get("supernatural_presence", 0.0)) * 0.35)))
	var faction_density: float = _clamp01(float(packet.get("faction_density", 0.35)))
	var fame_concentration: float = _clamp01(float(packet.get("fame_concentration", 0.15)))
	var boxing_density: float = _clamp01(float(packet.get("boxing_density", 0.1)))
	var royal_influence: float = _clamp01(float(packet.get("royal_influence", 0.1)))
	var supernatural_presence: float = _clamp01(float(packet.get("supernatural_presence", 0.0)))
	var migrant_push: float = _clamp01(float(packet.get("migrant_push", 0.0)))
	var border_openness: float = _clamp01(float(packet.get("border_openness", 0.5)))
	var school_quality: float = _clamp01(float(packet.get("school_quality", 0.5)))
	var job_market: float = _clamp01(float(packet.get("job_market", 0.5)))
	var crime_pressure: float = _clamp01(float(packet.get("crime_pressure", 0.25)))
	var community_cohesion: float = _clamp01(float(packet.get("community_cohesion", 0.5)))

	var inferred_instability: float = max(crime_pressure, faction_density * 0.75)
	inferred_instability = max(inferred_instability, migrant_push)
	inferred_instability = max(inferred_instability, max(0.0, 1.0 - public_mood))
	var instability: float = _clamp01(float(packet.get("instability", inferred_instability)))

	return {
		"violence": _clamp01((violence_norms * 0.55) + (crime_pressure * 0.3) + (instability * 0.15)),
		"romance": _clamp01((romance_norms * 0.55) + (social_openness * 0.25) + (public_mood * 0.15) + (border_openness * 0.05)),
		"ambition": _clamp01((education_emphasis * 0.28) + (job_market * 0.24) + (fame_concentration * 0.22) + (royal_influence * 0.1) + (boxing_density * 0.08) + (community_cohesion * 0.08)),
		"fame_drive": _clamp01((fame_concentration * 0.7) + (social_openness * 0.15) + (boxing_density * 0.1) + (royal_influence * 0.05)),
		"risk": _clamp01((crime_pressure * 0.42) + (violence_norms * 0.22) + (instability * 0.24) + (boxing_density * 0.07) + ((1.0 - border_openness) * 0.05)),
		"discipline": _clamp01((education_emphasis * 0.45) + (school_quality * 0.35) + (spirituality_pressure * 0.15) + (community_cohesion * 0.05)),
		"spirituality": _clamp01((spirituality_pressure * 0.65) + (supernatural_presence * 0.2) + (royal_influence * 0.1) + (community_cohesion * 0.05)),
		"social_openness": _clamp01((social_openness * 0.55) + (border_openness * 0.25) + (community_cohesion * 0.1) + (romance_norms * 0.1)),
		"instability": instability
	}

func _build_echo_stack(npc: Person, current_settlement_id: String) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var history: Array = []
	if typeof(npc.migration_history) == TYPE_ARRAY:
		history = npc.migration_history

	for i in range(history.size() - 1, -1, -1):
		var entry: Dictionary = history [i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var settlement_id: String = str(entry.get("to_settlement_id", "")).strip_edges()
		if settlement_id == "" or settlement_id == current_settlement_id or seen.has(settlement_id):
			continue

		var packet_snapshot: Dictionary = {}
		var saved_packet = entry.get("to_place_packet", {})
		if typeof(saved_packet) == TYPE_DICTIONARY and not saved_packet.is_empty():
			packet_snapshot = saved_packet.duplicate(true)
		elif gs.geo_engine != null:
			packet_snapshot = gs.geo_engine.get_place_packet(settlement_id)

		var weight: float = 0.52 * pow(0.72, float(out.size()))
		if settlement_id == str(npc.birthplace_settlement_id):
			weight += 0.14
		if settlement_id == str(npc.origin_settlement_id):
			weight += 0.1
		weight = clamp(weight, 0.0, 1.0)
		if weight <= 0.04:
			continue

		out.append({
			"settlement_id": settlement_id,
			"weight": weight,
			"source": "migration_history",
			"vector": _vector_from_packet(packet_snapshot)
		})
		seen [settlement_id] = true

		if out.size() >= MAX_ECHO_STACK:
			break

	_append_static_echo(npc.birthplace_settlement_id, "birthplace", out, seen, current_settlement_id, 0.22)
	_append_static_echo(npc.origin_settlement_id, "origin", out, seen, current_settlement_id, 0.16)

	return out

func _append_static_echo(raw_settlement_id, source_label: String, out: Array, seen: Dictionary, current_settlement_id: String, weight: float) -> void:
	var settlement_id: String = str(raw_settlement_id).strip_edges()
	if settlement_id == "" or settlement_id == current_settlement_id or seen.has(settlement_id):
		return
	var packet: Dictionary = {}
	if gs.geo_engine != null:
		packet = gs.geo_engine.get_place_packet(settlement_id)
	if packet.is_empty():
		return
	out.append({
		"settlement_id": settlement_id,
		"weight": clamp(weight, 0.0, 1.0),
		"source": source_label,
		"vector": _vector_from_packet(packet)
	})
	seen [settlement_id] = true

func _collapse_echo_stack(echo_stack: Array) -> Dictionary:
	var out: Dictionary = _blank_pressure_vector()
	var total_weight: float = 0.0

	for entry in echo_stack:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var weight: float = float(entry.get("weight", 0.0))
		var vector: Dictionary = entry.get("vector", {})
		if typeof(vector) != TYPE_DICTIONARY:
			continue
		total_weight += weight
		for key in PRESSURE_CHANNELS:
			out [key] = float(out.get(key, 0.0)) + (float(vector.get(key, 0.0)) * weight)

	if total_weight <= 0.0:
		return out

	for key in PRESSURE_CHANNELS:
		out [key] = _clamp01(float(out.get(key, 0.0)) / total_weight)

	return out

func _build_conflict_profile(npc: Person, current_vector: Dictionary, echo_vector: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var total: float = 0.0

	for key in PRESSURE_CHANNELS:
		var diff: float = abs(float(current_vector.get(key, 0.0)) - float(echo_vector.get(key, 0.0)))
		out [key] = diff
		total += diff

	total /= max(1.0, float(PRESSURE_CHANNELS.size()))

	var residue: Dictionary = npc.identity_residue if typeof(npc.identity_residue) == TYPE_DICTIONARY else {}
	var homesickness: float = float(residue.get("homesickness", 0.0)) * 0.01
	var nostalgia: float = float(residue.get("nostalgia", 0.0)) * 0.01
	var return_home_pull: float = float(residue.get("return_home_pull", 0.0)) * 0.01
	var prejudice: float = float(residue.get("prejudice_exposure", 0.0)) * 0.01
	var local_acceptance: float = float(residue.get("local_acceptance", 0.0)) * 0.01

	out ["total"] = _clamp01(total)
	out ["belonging_strain"] = _clamp01((total * 0.45) + (homesickness * 0.35) + (prejudice * 0.25) - (local_acceptance * 0.2))
	out ["nostalgia_pull"] = _clamp01((total * 0.25) + (nostalgia * 0.55) + (return_home_pull * 0.2))
	out ["return_home_pull"] = _clamp01((return_home_pull * 0.6) + (homesickness * 0.2) + (total * 0.2))
	out ["adaptation_pride"] = _clamp01((local_acceptance * 0.55) + (float(npc.years_in_current_place) / 12.0) * 0.35 - (total * 0.2))
	return out

func _build_identity_residue_deltas(npc: Person, current_vector: Dictionary, conflict_profile: Dictionary) -> Dictionary:
	var years_factor: float = clamp(float(npc.years_in_current_place) / 8.0, 0.0, 1.0)

	return {
		"local_acceptance": ((float(current_vector.get("social_openness", 0.0)) * 1.4) + (float(current_vector.get("discipline", 0.0)) * 0.6) - (float(conflict_profile.get("belonging_strain", 0.0)) * 1.5)) * 1.4,
		"homesickness": (-0.95 * years_factor) + (float(conflict_profile.get("nostalgia_pull", 0.0)) * 0.8),
		"nostalgia": (-0.55 * years_factor) + (float(conflict_profile.get("nostalgia_pull", 0.0)) * 0.65),
		"return_home_pull": (-0.35 * years_factor) + (float(conflict_profile.get("return_home_pull", 0.0)) * 0.55),
		"foreign_prestige": float(current_vector.get("fame_drive", 0.0)) * 0.6 + float(current_vector.get("ambition", 0.0)) * 0.4,
		"culture_drift": float(current_vector.get("social_openness", 0.0)) * 0.85,
		"language_drift": float(current_vector.get("social_openness", 0.0)) * 0.6,
		"diaspora_belonging": float(conflict_profile.get("belonging_strain", 0.0)) * 0.45,
		"migrant_boxer_edge": float(current_vector.get("risk", 0.0)) * 0.55,
		"celebrity_transplant_heat": float(current_vector.get("fame_drive", 0.0)) * 0.85
	}

func _apply_identity_residue_deltas(npc: Person, deltas: Dictionary) -> void:
	for key in deltas.keys():
		var old_value: float = float(npc.identity_residue.get(str(key), 0.0))
		var delta: float = float(deltas.get(key, 0.0))
		npc.identity_residue [str(key)] = clamp(old_value + delta, 0.0, 100.0)

func _build_trait_drift_profile(_npc: Person, current_vector: Dictionary, conflict_profile: Dictionary) -> Dictionary:
	return {
		"aggression": (float(current_vector.get("violence", 0.0)) * 2.4) + (float(current_vector.get("risk", 0.0)) * 1.2) - (float(current_vector.get("discipline", 0.0)) * 1.2),
		"discipline": (float(current_vector.get("discipline", 0.0)) * 2.8) - (float(current_vector.get("instability", 0.0)) * 1.5),
		"romance_style": (float(current_vector.get("romance", 0.0)) * 2.6) + (float(current_vector.get("social_openness", 0.0)) * 1.1),
		"caution": (float(current_vector.get("instability", 0.0)) * 2.0) + (float(conflict_profile.get("belonging_strain", 0.0)) * 1.6) - (float(current_vector.get("social_openness", 0.0)) * 0.6),
		"loyalty": (float(current_vector.get("spirituality", 0.0)) * 1.2) + (float(current_vector.get("discipline", 0.0)) * 0.8),
		"volatility": (float(current_vector.get("instability", 0.0)) * 2.3) + (float(conflict_profile.get("total", 0.0)) * 1.5) - (float(current_vector.get("discipline", 0.0)) * 0.8)
	}

func _build_adaptation_flags(npc: Person, conflict_profile: Dictionary, influence_strength: float) -> Array:
	var out: Array = []
	if int(npc.years_in_current_place) <= 1:
		out.append("recent_arrival")
	if int(npc.years_in_current_place) >= 6 and float(conflict_profile.get("total", 0.0)) <= 0.28:
		out.append("fully_adapted")
	if int(npc.years_in_current_place) >= 10 and str(npc.birthplace_settlement_id) == str(npc.settlement_id):
		out.append("hometown_loyalist")
	if float(conflict_profile.get("total", 0.0)) >= 0.55:
		out.append("identity_conflict")
	if int(npc.migration_history.size()) >= 1 and influence_strength >= 0.6 and float(conflict_profile.get("total", 0.0)) <= 0.3:
		out.append("adapted_migrant")
	return out

func _build_memory_tags(npc: Person, packet: Dictionary, current_vector: Dictionary, conflict_profile: Dictionary, adaptation_flags: Array) -> Array:
	var tags: Array = []

	if float(current_vector.get("violence", 0.0)) >= 0.62:
		tags.append("place.violence_heavy")
	if float(current_vector.get("romance", 0.0)) >= 0.6:
		tags.append("place.romance_open")
	if float(current_vector.get("ambition", 0.0)) >= 0.64:
		tags.append("place.ambition_hub")
	if float(current_vector.get("fame_drive", 0.0)) >= 0.58:
		tags.append("place.fame_hub")
	if float(current_vector.get("risk", 0.0)) >= 0.6:
		tags.append("place.risk_heavy")
	if float(current_vector.get("discipline", 0.0)) >= 0.62:
		tags.append("place.disciplined")
	if float(current_vector.get("spirituality", 0.0)) >= 0.58:
		tags.append("place.spiritual")
	if float(current_vector.get("social_openness", 0.0)) >= 0.6:
		tags.append("place.socially_open")
	if float(current_vector.get("instability", 0.0)) >= 0.58:
		tags.append("place.unstable")
	if float(packet.get("boxing_density", 0.0)) >= 0.45:
		tags.append("place.boxing_scene")
	if float(packet.get("royal_influence", 0.0)) >= 0.45:
		tags.append("place.power_center")
	if float(packet.get("supernatural_presence", 0.0)) >= 0.35:
		tags.append("place.supernatural_corridor")
	if typeof(npc.diaspora_tags) == TYPE_ARRAY and not npc.diaspora_tags.is_empty():
		tags.append("identity.diaspora")
	if float(conflict_profile.get("belonging_strain", 0.0)) >= 0.48:
		tags.append("identity.displaced")
	if float(conflict_profile.get("adaptation_pride", 0.0)) >= 0.5:
		tags.append("identity.adaptation_pride")

	for flag in adaptation_flags:
		tags.append("identity.%s" % str(flag))

	var out: Array = []
	for raw_tag in tags:
		var tag: String = str(raw_tag).strip_edges()
		if tag == "":
			continue
		if tag not in out:
			out.append(tag)
		if out.size() >= MAX_MEMORY_TAGS:
			break

	return out

func _append_yearly_snapshot(npc: Person) -> void:
	var snapshots: Array = npc.place_yearly_snapshots
	if typeof(snapshots) != TYPE_ARRAY:
		snapshots = []

	if not snapshots.is_empty():
		var last_entry = snapshots [snapshots.size() - 1]
		if typeof(last_entry) == TYPE_DICTIONARY and int(last_entry.get("year", -999999)) == int(gs.year):
			snapshots.remove_at(snapshots.size() - 1)

	snapshots.append({
		"year": int(gs.year),
		"settlement_id": str(npc.settlement_id),
		"place_name": str(npc.home_city),
		"years_in_current_place": int(npc.years_in_current_place),
		"influence_strength": float(npc.place_influence_strength),
		"dominant_channels": npc.place_identity_summary.get("dominant_channels", []).duplicate(),
		"conflict_total": float(npc.place_conflict_profile.get("total", 0.0)),
		"adaptation_flags": npc.place_adaptation_flags.duplicate()
	})

	if snapshots.size() > MAX_YEARLY_SNAPSHOTS:
		snapshots = snapshots.slice(snapshots.size() - MAX_YEARLY_SNAPSHOTS, snapshots.size())

	npc.place_yearly_snapshots = snapshots

func _compute_influence_strength(npc: Person, conflict_profile: Dictionary) -> float:
	var years_factor: float = clamp(float(npc.years_in_current_place) / 8.0, 0.0, 1.0)
	var mobility_penalty: float = clamp(float(npc.migration_history.size()) * 0.04, 0.0, 0.35)
	var strength: float = 0.2 + (years_factor * 0.6) + ((1.0 - float(conflict_profile.get("total", 0.0))) * 0.1) - mobility_penalty

	if int(npc.last_place_shift_year) == int(gs.year):
		strength *= 0.55

	return clamp(strength, 0.1, 1.0)

func _top_channels(vector: Dictionary, count: int) -> Array:
	var scored: Array = []
	for key in PRESSURE_CHANNELS:
		scored.append({
			"key": str(key),
			"score": float(vector.get(key, 0.0))
		})
	scored.sort_custom(func (a, b): return float(a.get("score", 0.0)) > float(b.get("score", 0.0)))

	var out: Array = []
	for row in scored:
		if out.size() >= count:
			break
		if float(row.get("score", 0.0)) <= 0.0:
			continue
		out.append(str(row.get("key", "")))
	return out

func _blank_pressure_vector() -> Dictionary:
	var out: Dictionary = {}
	for key in PRESSURE_CHANNELS:
		out [key] = 0.0
	return out

func _clamp01(value: float) -> float:
	return clamp(value, 0.0, 1.0)