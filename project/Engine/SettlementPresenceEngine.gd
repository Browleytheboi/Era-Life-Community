extends Resource
class_name SettlementPresenceEngine

var gs
var active_presence_by_settlement: Dictionary = {}

func _init(_gs):
	gs = _gs

func register_active_presence(npc: Person) -> void:
	if npc == null:
		return
	var settlement_id: String = str(npc.settlement_id)
	if settlement_id == "":
		return
	if not active_presence_by_settlement.has(settlement_id):
		active_presence_by_settlement [settlement_id] = []
	if int(npc.id) not in active_presence_by_settlement [settlement_id]:
		active_presence_by_settlement [settlement_id].append(int(npc.id))

func on_npc_moved(payload: Dictionary) -> void:
	if gs == null:
		return
	var npc_id: int = int(payload.get("npc_id", -1))
	if npc_id <= 0:
		return
	var npc: Person = gs.get_or_reactivate_npc_by_id(npc_id)
	if npc == null:
		return
	_rebuild_presence_for_npc(npc)

func yearly_tick(_payload:= {}) -> void:
	if gs == null or gs.player == null:
		return
	ensure_locality_feels_alive(gs.player)

func get_visible_npcs_for_observer(observer: Person, max_count:= 24) -> Array:
	var out: Array = []
	if observer == null or gs == null:
		return out

	var observer_settlement_id: String = str(observer.settlement_id)
	if observer_settlement_id == "":
		return out

	var ids: Array = active_presence_by_settlement.get(observer_settlement_id, [])
	for raw_id in ids:
		var npc: Person = gs.get_or_reactivate_npc_by_id(int(raw_id))
		if npc == null or npc == observer:
			continue
		out.append(npc)
		if out.size() >= max_count:
			return out

	var reactivated: Array = _reactivate_dormant_locals(observer_settlement_id, max_count - out.size())
	for npc in reactivated:
		if npc == null or npc == observer:
			continue
		out.append(npc)
		if out.size() >= max_count:
			return out

	var generated: Array = _generate_strangers_for_settlement(observer_settlement_id, max_count - out.size())
	for npc in generated:
		if npc == null or npc == observer:
			continue
		out.append(npc)
		if out.size() >= max_count:
			return out

	return out

func ensure_locality_feels_alive(observer: Person) -> void:
	if observer == null:
		return
	get_visible_npcs_for_observer(observer, 24)

func _rebuild_presence_for_npc(npc: Person) -> void:
	if npc == null:
		return

	for settlement_id in active_presence_by_settlement.keys():
		active_presence_by_settlement [settlement_id].erase(int(npc.id))

	register_active_presence(npc)

func _reactivate_dormant_locals(settlement_id: String, needed: int) -> Array:
	var out: Array = []
	if gs == null or needed <= 0:
		return out

	for raw_id in gs.dormant_npcs.keys():
		if out.size() >= needed:
			break
		var facts: Dictionary = gs.get_npc_facts_by_id(int(raw_id))
		if facts == {}:
			continue
		if str(facts.get("settlement_id", "")) != settlement_id:
			continue
		var npc: Person = gs.get_or_reactivate_npc_by_id(int(raw_id))
		if npc == null:
			continue
		register_active_presence(npc)
		out.append(npc)

	return out

func _generate_strangers_for_settlement(settlement_id: String, needed: int) -> Array:
	var out: Array = []
	if gs == null or gs.population_lifecycle_manager == null or gs.population_shard_engine == null or needed <= 0:
		return out

	var settlement: Dictionary = {}
	if gs.geo_engine != null:
		settlement = gs.geo_engine.get_settlement(settlement_id)

	for i in range(needed):
		var realm_id: int = int(settlement.get("realm_id", gs.player.realm_id if gs.player != null else -1))
		var shard: Dictionary = gs.population_lifecycle_manager._pick_matching_shard({
			"realm_id": realm_id
		})
		if shard.is_empty():
			continue

		var snap: Dictionary = gs.population_lifecycle_manager._generate_snapshot_from_shard(
			shard,
			{
				"realm_id": realm_id
			}
		)
		if snap.is_empty():
			continue

		snap ["settlement_id"] = settlement_id
		snap ["district_id"] = str(settlement.get("default_district_id", ""))
		snap ["locality_id"] = str(settlement.get("default_locality_id", ""))
		snap ["home_city"] = str(settlement.get("name", snap.get("home_city", "")))
		snap ["home_country"] = str(settlement.get("realm_name", snap.get("home_country", "")))

		var npc: Person = gs._deserialize_npc(snap)
		if npc == null:
			continue
		gs.register_npc(npc)
		register_active_presence(npc)
		out.append(npc)

	return out