extends Resource
class_name BoxingLegacyEngine

var gs
var family_legacy:= {}

func _init(_gs):
	gs = _gs

func yearly_tick(_payload:= {}) -> void:
	for npc in gs.npcs:
		if npc == null or not npc.alive:
			continue
		if not npc.boxing_profile.get("is_boxer", false):
			continue
		_ensure_family_legacy(npc)

func on_fight_completed(payload: Dictionary) -> void:
	var winner = gs.get_npc_by_id(int(payload.get("winner_id", -1)))
	if winner != null:
		_ensure_family_legacy(winner)
		var fam = family_legacy.get(winner.last_name, { "wins": 0, "titles": 0, "members": []})
		fam ["wins"] = int(fam.get("wins", 0)) + 1
		family_legacy [winner.last_name] = fam

func on_title_won(payload: Dictionary) -> void:
	var npc = gs.get_npc_by_id(int(payload.get("npc_id", -1)))
	if npc == null:
		return

	_ensure_family_legacy(npc)
	var fam = family_legacy [npc.last_name]
	fam ["titles"] = int(fam.get("titles", 0)) + 1
	family_legacy [npc.last_name] = fam

	var txt = "🧬 The %s family boxing legacy just grew stronger." % npc.last_name
	gs.event_bus.emit(ActionEventTypes.BOXING_FAMILY_LEGACY, {
		"npc_id": npc.id,
		"text": txt
	})

func _ensure_family_legacy(npc: Person) -> void:
	if not family_legacy.has(npc.last_name):
		family_legacy [npc.last_name] = {
			"members": [],
			"wins": 0,
			"titles": 0,
			"olympic_medals": 0
		}

	var fam = family_legacy [npc.last_name]
	if npc.id not in fam ["members"]:
		fam ["members"].append(npc.id)
	family_legacy [npc.last_name] = fam