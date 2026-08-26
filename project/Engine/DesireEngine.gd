extends Resource
class_name DesireEngine

var gs

func _init(_gs):
	gs = _gs






var CORE_IDENTITY_DRIVES = [
	"power",
	"love",
	"legacy",
	"wealth",
	"fame",
	"freedom",
	"knowledge",
	"chaos"
]

var IMPULSE_POOL = [
	"Flirt",
	"BuySomething",
	"StartFight",
	"ConfessLove",
	"QuitJob",
	"CommitCrime",
	"Travel",
	"Train",
	"SelfImprove"
]





func _ensure_initialized(npc):
	if npc.desires == null:
		npc.desires = {
			"core": [],
			"active": [],
			"impulses": []
		}

	if npc.desires.core.size() == 0:
		_generate_core_drive(npc)


func _generate_core_drive(npc):
	var pick = CORE_IDENTITY_DRIVES [randi() % CORE_IDENTITY_DRIVES.size()]
	npc.desires.core.append(pick)


	match pick:
		"power":
			npc.ambition += 15
		"wealth":
			npc.ambition += 10
		"fame":
			npc.ambition += 10
		"knowledge":
			npc.ambition += 5
		"chaos":
			npc.motivation += 5

	npc.ambition = clamp(npc.ambition, 0, 100)
	if npc.strategic_focus == "":
		npc.strategic_focus = pick




func yearly_tick(npc = null):


	if typeof(npc) == TYPE_DICTIONARY:
		return


	if npc == null:
		for n in gs.npcs:
			_process_npc_year(n)
	else:
		_process_npc_year(npc)


func _process_npc_year(npc):
	if not npc.alive:
		return
	_ensure_initialized(npc)

	var bias: Dictionary = {}
	if gs.afterlife_influence_engine != null:
		bias = gs.afterlife_influence_engine.get_transient_bias_for_npc(int(npc.id))
		gs.afterlife_influence_engine.apply_year_opening_bias(npc, bias)

	var place_bias: Dictionary = {}
	if gs.place_influence_engine != null:
		place_bias = gs.place_influence_engine.get_desire_bias(npc)
		npc.motivation = clamp(float(npc.motivation) + float(place_bias.get("motivation_delta", 0.0)), 0.0, 100.0)
		npc.ambition = clamp(float(npc.ambition) + float(place_bias.get("ambition_delta", 0.0)), 0.0, 100.0)


	npc.motivation += randi_range(-5, 5)
	npc.motivation = clamp(npc.motivation, 0, 100)


	if randi() % 100 < 40:
		_generate_impulse(npc, place_bias)


	if npc.ambition > 60 and randi() % 100 < 35:
		_generate_active_goal(npc, place_bias)


	if randi() % 100 < 20:
		npc.ambition += randi_range(1, 3)
	npc.ambition = clamp(npc.ambition, 0, 100)





func _generate_impulse(npc, place_bias:= {}):
	var pick: String = ""
	if gs.afterlife_influence_engine != null:
		pick = gs.afterlife_influence_engine.pick_biased_impulse(npc, IMPULSE_POOL)

	var impulse_weights: Dictionary = {}
	if typeof(place_bias) == TYPE_DICTIONARY:
		impulse_weights = place_bias.get("impulse_weights", {})
	if typeof(impulse_weights) != TYPE_DICTIONARY:
		impulse_weights = {}

	if pick == "" and not impulse_weights.is_empty():
		pick = _pick_weighted_string(IMPULSE_POOL, impulse_weights)

	if pick == "":
		pick = str(IMPULSE_POOL [randi() % IMPULSE_POOL.size()])

	if pick not in npc.desires.impulses:
		npc.desires.impulses.append(pick)


	if npc.desires.impulses.size() > 3:
		npc.desires.impulses.pop_front()





func _generate_active_goal(npc, place_bias:= {}):
	var core = npc.desires.core [0]

	var goal_candidates: Dictionary = {
		"GainPoliticalInfluence": 0.0,
		"IncreaseNetWorth": 0.0,
		"BecomeFamous": 0.0,
		"FindPartner": 0.0,
		"HaveChild": 0.0,
		"ImproveSmarts": 0.0,
		"TravelWorld": 0.0,
		"DisruptOrder": 0.0
	}

	match core:
		"power":
			goal_candidates ["GainPoliticalInfluence"] += 4.0
		"wealth":
			goal_candidates ["IncreaseNetWorth"] += 4.0
		"fame":
			goal_candidates ["BecomeFamous"] += 4.0
		"love":
			goal_candidates ["FindPartner"] += 4.0
		"legacy":
			goal_candidates ["HaveChild"] += 4.0
		"knowledge":
			goal_candidates ["ImproveSmarts"] += 4.0
		"freedom":
			goal_candidates ["TravelWorld"] += 4.0
		"chaos":
			goal_candidates ["DisruptOrder"] += 4.0

	var place_goal_weights: Dictionary = {}
	if typeof(place_bias) == TYPE_DICTIONARY:
		place_goal_weights = place_bias.get("goal_weights", {})
	if typeof(place_goal_weights) != TYPE_DICTIONARY:
		place_goal_weights = {}

	for key in goal_candidates.keys():
		goal_candidates [key] = float(goal_candidates.get(key, 0.0)) + float(place_goal_weights.get(key, 0.0))

	var goal: String = _pick_weighted_string(goal_candidates.keys(), goal_candidates)

	if goal == "":
		match core:
			"power":
				goal = "GainPoliticalInfluence"
			"wealth":
				goal = "IncreaseNetWorth"
			"fame":
				goal = "BecomeFamous"
			"love":
				goal = "FindPartner"
			"legacy":
				goal = "HaveChild"
			"knowledge":
				goal = "ImproveSmarts"
			"freedom":
				goal = "TravelWorld"
			"chaos":
				goal = "DisruptOrder"

	if gs.afterlife_influence_engine != null:
		goal = gs.afterlife_influence_engine.pick_biased_goal(npc, core, goal)

	if goal != "" and goal not in npc.desires.active:
		npc.desires.active.append(goal)


	if npc.desires.active.size() > 2:
		npc.desires.active.pop_front()
func _pick_weighted_string(options: Array, weights: Dictionary) -> String:
	if options.is_empty():
		return ""

	var total_weight: float = 0.0
	for raw_option in options:
		var option: String = str(raw_option)
		total_weight += max(0.0, float(weights.get(option, 0.0)))

	if total_weight <= 0.0:
		return ""

	var roll: float = randf() * total_weight
	var running: float = 0.0
	for raw_option in options:
		var option: String = str(raw_option)
		running += max(0.0, float(weights.get(option, 0.0)))
		if roll <= running:
			return option

	return str(options [options.size() - 1])





func on_fame_spike(payload):

	var npc_id = payload.get("npc_id", -1)
	var npc = gs.get_npc_by_id(npc_id)

	if npc == null:
		return

	_ensure_initialized(npc)


	npc.ambition += 10
	npc.motivation += 10

	npc.ambition = clamp(npc.ambition, 0, 100)
	npc.motivation = clamp(npc.motivation, 0, 100)


func on_npc_died(payload):

	var _npc_id = payload.get("npc_id", -1)

	for npc in gs.npcs:

		if not npc.alive:
			continue

		_ensure_initialized(npc)


		if "legacy" in npc.desires.core:
			npc.motivation += 10

		if "love" in npc.desires.core:
			npc.motivation += 5

		npc.motivation = clamp(npc.motivation, 0, 100)