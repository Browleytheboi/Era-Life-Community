extends Resource
class_name WorkplaceEngine

var gs


var workplace_rosters: Dictionary = {}


var workplace_meta: Dictionary = {}


var npc_workplace: Dictionary = {}


func _init(_gs):
	gs = _gs


func _era_job_key(job_name: String) -> String:
	var era_name:= ""
	if gs.era != null:
		era_name = str(gs.era.get("name", "Unknown Era"))
	return "%s::%s" % [era_name, job_name]


func _make_workplace_id(job_name: String) -> String:
	var key = _era_job_key(job_name)
	if not workplace_meta.has(key):
		workplace_meta [key] = {
			"id": key,
			"job_name": job_name,
			"era_name": gs.era.get("name", "Unknown Era") if gs.era != null else "Unknown Era"
		}
		if not workplace_rosters.has(key):
			workplace_rosters [key] = []
	return key


func register_worker(npc: Person, job_name: String) -> void:
	if npc == null:
		return
	if job_name == "":
		return

	var workplace_id = _make_workplace_id(job_name)

	if not workplace_rosters.has(workplace_id):
		workplace_rosters [workplace_id] = []

	if npc.id not in workplace_rosters [workplace_id]:
		workplace_rosters [workplace_id].append(npc.id)

	npc_workplace [npc.id] = workplace_id
	npc.current_workplace_id = workplace_id
	_refresh_npc_coworkers(npc)
func register_worker_at_organization(
	npc: Person,
	job_name: String,
	organization_id: String,
	department_id: String,
	position_id: String,
	context: Dictionary = {}
) -> void:
	if npc == null:
		return

	var clean_organization_id: String = str(
		organization_id
	).strip_edges()
	var clean_department_id: String = str(
		department_id
	).strip_edges()

	if clean_organization_id == "":
		register_worker(
			npc,
			job_name
		)
		return

	if clean_department_id == "":
		clean_department_id = "general"

	var workplace_id: String = "%s::%s" % [
		clean_organization_id,
		clean_department_id
	]

	if not workplace_meta.has(workplace_id):
		workplace_meta [workplace_id] = {
			"id": workplace_id,
			"job_name": job_name,
			"era_name": (
				gs.era.get(
					"name",
					"Unknown Era"
				)
				if gs.era != null
				else "Unknown Era"
			),
			"organization_id": clean_organization_id,
			"organization_name": str(
				context.get(
					"organization_name",
					"Institution"
				)
			),
			"department_id": clean_department_id,
			"position_ids_by_actor": {},
		}

	if not workplace_rosters.has(workplace_id):
		workplace_rosters [workplace_id] = []

	var old_workplace_id: String = str(
		npc_workplace.get(
			npc.id,
			""
		)
	)

	if (
		old_workplace_id != ""
		and old_workplace_id != workplace_id
		and workplace_rosters.has(
			old_workplace_id
		)
	):
		workplace_rosters [
			old_workplace_id
		].erase(
			npc.id
		)

	if npc.id not in workplace_rosters [workplace_id]:
		workplace_rosters [
			workplace_id
		].append(
			npc.id
		)

	var metadata: Dictionary = workplace_meta [
		workplace_id
	]
	var positions_by_actor: Dictionary = (
		metadata.get(
			"position_ids_by_actor",
			{}
		)
	)

	positions_by_actor [
		int(npc.id)
	] = position_id

	metadata [
		"position_ids_by_actor"
	] = positions_by_actor
	workplace_meta [
		workplace_id
	] = metadata

	npc_workplace [
		npc.id
	] = workplace_id
	npc.current_workplace_id = workplace_id

	_refresh_npc_coworkers(
		npc
	)

func unregister_worker(npc: Person) -> void:
	if npc == null:
		return

	var workplace_id = str(npc_workplace.get(npc.id, ""))
	if workplace_id != "" and workplace_rosters.has(workplace_id):
		workplace_rosters [workplace_id].erase(npc.id)

	npc_workplace.erase(npc.id)
	npc.current_workplace_id = ""
	npc.coworkers.clear()


func get_coworkers(npc: Person) -> Array:
	var out:= []
	if npc == null:
		return out

	var workplace_id = str(npc_workplace.get(npc.id, ""))
	if workplace_id == "":
		return out
	if not workplace_rosters.has(workplace_id):
		return out

	for other_id in workplace_rosters [workplace_id]:
		if int(other_id) == npc.id:
			continue
		var other = gs.get_or_reactivate_npc_by_id(int(other_id))
		if other != null and other.alive:
			out.append(other)

	return out


func has_coworkers(npc: Person) -> bool:
	return get_coworkers(npc).size() > 0


func ensure_minimum_coworkers(npc: Person, minimum_count: int = 2) -> void:
	if npc == null:
		return
	if npc.job == "":
		return
	if npc.age < 16:
		return
	var current = get_coworkers(npc)
	if current.size() >= minimum_count:
		_refresh_npc_coworkers(npc)
		return
	var needed = minimum_count - current.size()
	for i in range(needed):
		var coworker = gs.npc_factory.create_random_npc()
		if coworker == null:
			continue
		coworker.age = max(coworker.age, 16 if npc.age < 18 else 18)
		coworker.job = npc.job
		coworker.income = max(0.0, npc.income * randf_range(0.75, 1.1))
		coworker.satisfaction = randi_range(35, 75)
		coworker.job_performance = randi_range(35, 75)
		coworker.work_stress = randf_range(15.0, 65.0)
		coworker.current_workplace_id = ""
		gs.register_npc(coworker)
		register_worker(coworker, coworker.job)
		if gs.event_bus != null:
			gs.event_bus.emit(ActionEventTypes.COWORKER_ADDED, {
				"npc_id": coworker.id,
				"text": "%s joined the workplace as a %s." % [coworker.first_name, coworker.job],
				"job_name": coworker.job
			})
	_refresh_npc_coworkers(npc)

func sync_existing_worker(npc: Person) -> void:
	if npc == null:
		return

	if npc.job == "":
		return
	if (
		gs != null
		and gs.career_runtime_engine != null
	):
		var assignment: Dictionary = (
			gs.career_runtime_engine
			.assignment_for_actor(
				npc
			)
		)

		if not assignment.is_empty():
			var organization: Dictionary = (
				gs.career_runtime_engine
				.organization_for_actor(
					npc
				)
			)

			register_worker_at_organization(
				npc,
				str(
					assignment.get(
						"rank_title",
						npc.job
					)
				),
				str(
					assignment.get(
						"organization_id",
						""
					)
				),
				str(
					assignment.get(
						"department_id",
						""
					)
				),
				str(
					assignment.get(
						"position_id",
						""
					)
				),
				{
					"organization_name": str(
						organization.get(
							"name",
							"Institution"
						)
					),
				}
			)

			return
	if npc.age < 16:
		return
	register_worker(npc, npc.job)
	_refresh_npc_coworkers(npc)


func _refresh_npc_coworkers(npc: Person) -> void:
	if npc == null:
		return

	var ids:= []
	for c in get_coworkers(npc):
		ids.append(c.id)
	npc.coworkers = ids
func rebuild_loaded_workers() -> void:
	for workplace_id_key in workplace_rosters.keys():
		var workplace_id:= str(workplace_id_key)

		if not workplace_meta.has(workplace_id):
			var era_name:= "Unknown Era"
			var job_name:= workplace_id
			var parts:= workplace_id.split("::")

			if parts.size() >= 2:
				era_name = str(parts [0])
				job_name = str(parts [1])
			elif gs.era != null:
				era_name = str(gs.era.get("name", "Unknown Era"))

			workplace_meta [workplace_id] = {
				"id": workplace_id,
				"job_name": job_name,
				"era_name": era_name
			}

		var roster_value = workplace_rosters [workplace_id]
		if typeof(roster_value) != TYPE_ARRAY:
			continue

		for npc_id_value in roster_value:
			var npc: Person = gs.get_npc_by_id(int(npc_id_value))
			if npc == null:
				continue

			npc_workplace [npc.id] = workplace_id
			npc.current_workplace_id = workplace_id