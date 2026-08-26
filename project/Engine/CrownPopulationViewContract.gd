extends Resource
class_name CrownPopulationViewContract

const VIEW_SCHEMA:= "eralife.crown_population_view_contract"
const CONTRACT_VERSION:= 1
const DEFAULT_LIMIT:= 20

var gs

func _init(_gs = null):
	gs = _gs


func build_population_view(realm_id: int, options: Dictionary = {}) -> Dictionary:
	if gs == null or gs.realm_engine == null:
		return {
			"success": false,
			"reason": "realm_engine_unavailable",
			"people": [],
			"rows": []
		}

	if realm_id <= 0:
		return {
			"success": false,
			"reason": "invalid_realm_id",
			"people": [],
			"rows": []
		}

	var limit: int = max(1, int(options.get("limit", DEFAULT_LIMIT)))
	var offset: int = max(0, int(options.get("offset", 0)))

	var people: Array = gs.realm_engine.derive_realm_residents(realm_id, false)
	people.sort_custom(func (a, b): return _person_sort_score(a, realm_id) > _person_sort_score(b, realm_id))

	var total: int = people.size()
	var end: int = min(total, offset + limit)
	var visible_people: Array = []
	if offset < total:
		visible_people = people.slice(offset, end)

	var rows: Array = []
	for person in visible_people:
		rows.append(_row_for_person(person, realm_id))

	return {
		"success": true,
		"schema": VIEW_SCHEMA,
		"version": CONTRACT_VERSION,
		"realm_id": realm_id,
		"limit": limit,
		"offset": offset,
		"total": total,
		"people": visible_people,
		"rows": rows,
		"source": str(options.get("source", "crown_population_view_contract")),
		"ui_is_renderer_only": true,
	}


func get_visible_people_for_realm(realm_id: int, options: Dictionary = {}) -> Array:
	var view: Dictionary = build_population_view(realm_id, options)
	return view.get("people", []) if typeof(view.get("people", [])) == TYPE_ARRAY else []


func _row_for_person(person, realm_id: int) -> Dictionary:
	if person == null:
		return {}

	return {
		"person_id": int(person.id),
		"name": "%s %s" % [str(person.first_name), str(person.last_name)],
		"age": int(person.age) if "age" in person else 0,
		"realm_id": realm_id,
		"is_ruler": bool(person.is_ruler) if "is_ruler" in person else false,
		"is_royal": bool(person.is_royal) if "is_royal" in person else false,
		"approval": int(person.approval) if "approval" in person else 0,
		"alive": bool(person.alive) if "alive" in person else true
	}


func _person_sort_score(person, realm_id: int) -> int:
	if person == null:
		return -999999

	var score: int = 0
	if "realm_id" in person and int(person.realm_id) == realm_id:
		score += 1000
	if "is_ruler" in person and bool(person.is_ruler):
		score += 500
	if "is_royal" in person and bool(person.is_royal):
		score += 250
	if "approval" in person:
		score += int(person.approval)

	score -= int(person.id) % 100
	return score