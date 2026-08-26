extends Resource
class_name CareerSpaceContractEngine

const ENGINE_SCHEMA:= "eralife.career_space_contract_engine"
const ENGINE_VERSION:= 1
const SPACE_TYPE:= "career"
const DEFAULT_SHARD_SIZE:= 24
const MAX_SHARD_SIZE:= 48

var gs
var last_report: Dictionary = {}


func _init(_gs = null) -> void:
	gs = _gs


func export_state() -> Dictionary:
	return {
		"schema": ENGINE_SCHEMA + ".state",
		"version": ENGINE_VERSION,
		"last_report": last_report.duplicate(true)
	}


func import_state(data: Dictionary) -> Dictionary:
	last_report = _dict(
		data.get(
			"last_report",
			{}
		)
	)

	return {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION
	}


func resolve_space_contract(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No career-space observer could be resolved."
		)

	var runtime = _runtime()
	var law = _law()

	var assignment: Dictionary = (
		runtime.assignment_for_actor(
			actor
		)
		if runtime != null
		else {}
	)

	var organization: Dictionary = (
		runtime.organization_for_actor(
			actor
		)
		if runtime != null
		else {}
	)

	var preview_path_id: String = str(
		context.get(
			"preview_path_id",
			""
		)
	).strip_edges()

	var path: Dictionary = {}
	var preview_only: bool = false

	if (
		not assignment.is_empty()
		and law != null
	):
		path = law.get_path_definition(
			str(
				assignment.get(
					"path_id",
					""
				)
			)
		)

	elif (
		preview_path_id != ""
		and law != null
	):
		path = law.get_path_definition(
			preview_path_id
		)
		preview_only = not path.is_empty()

	var archetype: String = _archetype(
		path,
		organization,
		assignment
	)

	var zones: Array = _zones(
		archetype
	)

	var zone_ids: Array = []

	for raw_zone in zones:
		var zone: Dictionary = _dict(
			raw_zone
		)

		zone_ids.append(
			str(
				zone.get(
					"zone_id",
					"common_area"
				)
			)
		)

	var organization_id: String = str(
		organization.get(
			"organization_id",
			assignment.get(
				"organization_id",
				""
			)
		)
	)

	var path_id: String = str(
		path.get(
			"path_id",
			assignment.get(
				"path_id",
				preview_path_id
			)
		)
	)

	var space_id: String = _space_id(
		actor,
		organization_id,
		path_id,
		preview_only
	)

	var requested_zone: String = str(
		context.get(
			"zone_id",
			context.get(
				"entry_zone",
				""
			)
		)
	).strip_edges().to_lower()

	if requested_zone == "":
		requested_zone = (
			str(
				_dict(
					zones [0]
				).get(
					"zone_id",
					"common_area"
				)
			)
			if not zones.is_empty()
			else "common_area"
		)

	var coworker_shard: Dictionary = _empty_shard()

	if (
		not preview_only
		and not assignment.is_empty()
	):
		coworker_shard = _coworker_shard(
			actor,
			assignment,
			space_id,
			zone_ids,
			context
		)

	var coworker_rows: Array = _array(
		coworker_shard.get(
			"rows",
			[]
		)
	)

	var goods_rows: Array = _merchant_goods_rows(
		actor,
		archetype,
		path,
		organization
	)

	var presence_summary: Dictionary = {}

	if (
		not preview_only
		and _shared() != null
	):
		presence_summary = _shared().presence_summary(
			SPACE_TYPE,
			space_id,
			{
				"source": (
					"career_space_contract_engine."
					+ "read_only_presence_summary"
				),
				"projection_read_only": true,
				"min_population": 0,
				"max_population": 0
			}
		)

	last_report = {
		"success": true,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"actor_id": int(
			actor.id
		),
		"era_name": _era(),
		"space_type": SPACE_TYPE,
		"space_id": space_id,
		"space_name": _space_name(
			archetype,
			organization,
			path
		),
		"space_archetype": archetype,
		"organization_id": organization_id,
		"path_id": path_id,
		"preview_only": preview_only,
		"employed_space": not assignment.is_empty(),
		"current_zone_id": requested_zone,
		"zone_rows": _zone_rows(
			actor,
			space_id,
			zones,
			requested_zone,
			preview_only,
			coworker_rows,
			goods_rows
		),
		"department_rows": _department_rows(
			organization,
			assignment
		),
		"hierarchy_rows": _hierarchy_rows(
			actor,
			organization,
			path,
			assignment
		),
		"coworker_shard": coworker_shard,
		"goods_rows": goods_rows,
		"presence_summary": presence_summary,
		"shared_public_space_report": {
			"success": true,
			"mode": "read_only_presence_observation",
		},
		"spatial_reality_backed": (
			not preview_only
			and not assignment.is_empty()
		),
		"projection_read_only": true,
		"ui_is_renderer_only": true
	}

	return last_report.duplicate(true)



func move_actor_to_zone(
	actor: Person,
	zone_id: String,
	context: Dictionary = {}
) -> Dictionary:
	var clean_zone: String = str(
		zone_id
	).strip_edges().to_lower()

	if (
		actor == null
		or clean_zone == ""
	):
		return _fail(
			"missing_actor_or_zone",
			"That workplace location could not be accessed."
		)

	var contract: Dictionary = resolve_space_contract(
		actor,
		{
			"zone_id": clean_zone,
			"coworker_shard_offset": int(
				context.get(
					"coworker_shard_offset",
					0
				)
			),
			"projection_read_only": true,
		}
	)

	if not bool(
		contract.get(
			"success",
			false
		)
	):
		return contract

	var allowed: bool = false

	for raw_row in _array(
		contract.get(
			"zone_rows",
			[]
		)
	):
		if str(
			_dict(
				raw_row
			).get(
				"zone_id",
				""
			)
		) == clean_zone:
			allowed = true
			break

	if not allowed:
		return _fail(
			"unknown_career_zone",
			"That location does not exist in this workplace."
		)

	return {
		"success": true,
		"type": "career_workplace_location_accessed",
		"zone_id": clean_zone,
		"zone_label": _zone_label(
			clean_zone,
			_array(
				contract.get(
					"zone_rows",
					[]
				)
			)
		),
		"career_space_contract": contract,
		"text": "",
		"reality_mutated": false,
		"ui_is_renderer_only": true
	}


func exit_actor_space(
	actor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _fail(
			"missing_actor",
			"No actor could leave the workplace."
		)

	if _shared() == null:
		return _fail(
			"shared_public_space_unavailable",
			"Shared workplace-space authority is unavailable."
		)

	var contract: Dictionary = resolve_space_contract(
		actor,
		context
	)
	var result: Dictionary = _shared().exit_space(
		actor,
		SPACE_TYPE,
		str(
			contract.get(
				"space_id",
				""
			)
		),
		{
			"source": (
				"career_space_contract_engine.exit_actor_space"
			)
		}
	)
	result ["text"] = "I left the workplace."
	result ["reality_mutated"] = true

	return result


func _coworker_shard(
	actor: Person,
	_assignment: Dictionary,
	space_id: String,
	zone_ids: Array,
	context: Dictionary
) -> Dictionary:
	if _runtime() == null:
		return _empty_shard()

	var ids: Array = _runtime().coworker_ids_for_actor(
		actor
	)

	ids.sort_custom(
		func (
			left_raw: Variant,
			right_raw: Variant
		) -> bool:
			var left_person: Person = _person(
				int(
					left_raw
				)
			)

			var right_person: Person = _person(
				int(
					right_raw
				)
			)

			var left_assignment: Dictionary = (
				_runtime().assignment_for_actor(
					left_person
				)
				if left_person != null
				else {}
			)

			var right_assignment: Dictionary = (
				_runtime().assignment_for_actor(
					right_person
				)
				if right_person != null
				else {}
			)

			var left_rank: int = int(
				left_assignment.get(
					"rank_index",
					0
				)
			)

			var right_rank: int = int(
				right_assignment.get(
					"rank_index",
					0
				)
			)

			if left_rank != right_rank:
				return left_rank > right_rank

			return int(
				left_raw
			) < int(
				right_raw
			)
	)

	var offset: int = maxi(
		0,
		int(
			context.get(
				"coworker_shard_offset",
				0
			)
		)
	)

	var limit: int = clampi(
		int(
			context.get(
				"coworker_shard_size",
				DEFAULT_SHARD_SIZE
			)
		),
		1,
		MAX_SHARD_SIZE
	)

	var end_index: int = mini(
		ids.size(),
		offset + limit
	)

	var rows: Array = []
	var usable_zones: Array = zone_ids.duplicate()

	if usable_zones.is_empty():
		usable_zones = [
			"common_area"
		]

	for index in range(
		offset,
		end_index
	):
		var coworker: Person = _person(
			int(
				ids [index]
			)
		)

		if (
			coworker == null
			or not coworker.alive
		):
			continue

		var coworker_assignment: Dictionary = (
			_runtime().assignment_for_actor(
				coworker
			)
		)

		var status: String = _schedule_status(
			coworker,
			coworker_assignment
		)

		var zone_id: String = ""

		if status not in [
			"off_shift",
			"sick",
			"vacation"
		]:
			zone_id = str(
				usable_zones [
					_roll(
						"zone|%d|%d|%s"
						% [
							int(
								coworker.id
							),
							int(
								gs.year
							),
							space_id
						],
						0,
						usable_zones.size() - 1
					)
				]
			)

		rows.append(
			_coworker_card(
				actor,
				coworker,
				status,
				zone_id
			)
		)

	return {
		"schema": ENGINE_SCHEMA + ".coworker_shard",
		"version": ENGINE_VERSION,
		"rows": rows,
		"total": ids.size(),
		"offset": offset,
		"limit": limit,
		"next_offset": end_index,
		"has_more": end_index < ids.size(),
	}
func _zone_rows(
	_actor: Person,
	_career_space_identity: String,
	zones: Array,
	current_zone: String,
	preview_only: bool,
	coworker_rows: Array = [],
	goods_rows: Array = []
) -> Array:
	var out: Array = []

	for raw_zone in zones:
		var zone: Dictionary = _dict(
			raw_zone
		)

		var zone_id: String = str(
			zone.get(
				"zone_id",
				"common_area"
			)
		)

		var people: Array = []

		if not preview_only:
			for raw_person in coworker_rows:
				var person_row: Dictionary = _dict(
					raw_person
				)

				if str(
					person_row.get(
						"zone_id",
						""
					)
				) != zone_id:
					continue

				people.append(
					person_row
				)

		var zone_goods: Array = _goods_rows_for_zone(
			goods_rows,
			zone_id
		)

		out.append({
			"zone_id": zone_id,
			"label": str(
				zone.get(
					"label",
					zone_id.replace(
						"_",
						" "
					).capitalize()
				)
			),
			"icon": str(
				zone.get(
					"icon",
					" "
				)
			),
			"description": str(
				zone.get(
					"description",
					"A real workplace location."
				)
			),
			"current": zone_id == current_zone,
			"preview_only": preview_only,
			"people_count": people.size(),
			"people_rows": people,
			"goods_count": zone_goods.size(),
			"goods_rows": zone_goods,
			"action": {
				"action_id": "observe_workplace_zone",
				"zone_id": zone_id,
				"label": (
					"OPEN LOCATION"
					if zone_id == current_zone
					else "ACCESS"
				),
				"enabled": true,
			}
		})

	return out
func _merchant_goods_rows(
	actor: Person,
	archetype: String,
	_path: Dictionary,
	_organization: Dictionary
) -> Array:
	if archetype != "merchant":
		return []

	if (
		gs == null
		or gs.belongings_engine == null
		or not gs.belongings_engine.has_method(
			"emit_trade_goods_catalog_contract"
		)
	):
		return []

	var catalog: Dictionary = (
		gs.belongings_engine
		.emit_trade_goods_catalog_contract(
			actor,
			{
				"source": (
					"career_space_contract_engine."
					+ "merchant_goods_projection"
				),
				"projection_read_only": true,
			}
		)
	)

	return _array(
		catalog.get(
			"goods_rows",
			[]
		)
	)
func _goods_rows_for_zone(
	goods_rows: Array,
	zone_id: String
) -> Array:
	if zone_id not in [
		"market_floor",
		"warehouse",
		"contract_room",
		"loading_yard",
		"market_stall",
		"storage"
	]:
		return []

	var out: Array = []

	for raw_row in goods_rows:
		var row: Dictionary = _dict(
			raw_row
		).duplicate(false)

		if row.is_empty():
			continue

		row ["zone_id"] = zone_id
		row ["observable_in_workplace"] = true

		out.append(
			row
		)

	return out


func _department_rows(
	organization: Dictionary,
	assignment: Dictionary
) -> Array:
	var out: Array = []

	if _runtime() == null or organization.is_empty():
		return out

	for raw_id in _array(
		organization.get(
			"department_ids",
			[]
		)
	):
		var department: Dictionary = _runtime().department_by_id(
			str(
				raw_id
			)
		)
		var employees: int = 0
		var vacancies: int = 0

		for raw_position_id in _array(
			department.get(
				"position_ids",
				[]
			)
		):
			var position: Dictionary = _runtime().position_by_id(
				str(
					raw_position_id
				)
			)

			if str(
				position.get(
					"status",
					"vacant"
				)
			) == "filled":
				employees += 1
			else:
				vacancies += 1

		out.append({
			"department_id": str(
				raw_id
			),
			"title": str(
				department.get(
					"name",
					"Department"
				)
			),
			"current": str(
				raw_id
			) == str(
				assignment.get(
					"department_id",
					""
				)
			),
			"lines": [
				"Employees: %d" % employees,
				"Open positions: %d" % vacancies,
				"Career paths: %d"
				% _array(
					department.get(
						"path_ids",
						[]
					)
				).size()
			]
		})

	return out


func _hierarchy_rows(
	actor: Person,
	organization: Dictionary,
	path: Dictionary,
	assignment: Dictionary
) -> Array:
	if assignment.is_empty():
		return []

	return [
		{
			"depth": 0,
			"label": str(
				organization.get(
					"name",
					"Organization"
				)
			),
			"kind": "organization"
		},
		{
			"depth": 1,
			"label": str(
				assignment.get(
					"department_name",
					path.get(
						"department",
						"Department"
					)
				)
			),
			"kind": "department"
		},
		{
			"depth": 2,
			"label": str(
				path.get(
					"display_name",
					"Career Path"
				)
			),
			"kind": "career_path"
		},
		{
			"depth": 3,
			"label": str(
				assignment.get(
					"rank_title",
					actor.job
				)
			),
			"kind": "rank",
			"current_actor_id": int(
				actor.id
			),
			"current_actor_name": _name(
				actor
			),
		}
	]

func _coworker_card(
	observer: Person,
	coworker: Person,
	status: String,
	zone_id: String
) -> Dictionary:
	var assignment: Dictionary = (
		_runtime().assignment_for_actor(
			coworker
		)
		if _runtime() != null
		else {}
	)
	var mood_score: int = clampi(
		int(
			coworker.satisfaction
		)
		- int(
			round(
				float(
					coworker.work_stress
				) * 0.35
			)
		)
		+ _roll(
			"mood|%d|%d"
			% [
				int(
					coworker.id
				),
				int(
					gs.year
				)
			],
			-8,
			8
		),
		0,
		100
	)
	var mood: Dictionary = _mood(
		mood_score,
		status
	)

	return {
		"person_id": int(
			coworker.id
		),
		"name": _name(
			coworker
		),
		"role": str(
			assignment.get(
				"rank_title",
				coworker.job
			)
		),
		"path_id": str(
			assignment.get(
				"path_id",
				""
			)
		),
		"rank_index": int(
			assignment.get(
				"rank_index",
				0
			)
		),
		"department_id": str(
			assignment.get(
				"department_id",
				""
			)
		),
		"organization_id": str(
			assignment.get(
				"organization_id",
				""
			)
		),
		"rating": _stars(
			int(
				coworker.job_performance
			)
		),
		"mood": mood,
		"years_here": maxi(
			0,
			int(
				gs.year
			)
			- int(
				assignment.get(
					"started_year",
					gs.year
				)
			)
		),
		"schedule_status": status,
		"zone_id": zone_id,
		"zone_label": zone_id.replace(
			"_",
			" "
		).capitalize(),
		"current_activity": _activity(
			coworker,
			zone_id,
			status
		),
		"bond": _bond(
			observer,
			coworker
		),
		"actions": [
			{
				"action_id": (
					"start_coworker_conversation"
				),
				"target_id": int(
					coworker.id
				),
				"label": "TALK",
				"enabled": status == "on_shift"
			},
			{
				"action_id": (
					"open_coworker_profile"
				),
				"target_id": int(
					coworker.id
				),
				"label": "OPEN FULL PROFILE",
				"enabled": true
			}
		]
	}


func _schedule_status(
	person: Person,
	assignment: Dictionary
) -> String:
	var value: int = _roll(
		"schedule|%d|%d|%s"
		% [
			int(
				person.id
			),
			int(
				gs.year
			),
			str(
				assignment.get(
					"organization_id",
					""
				)
			)
		],
		0,
		99
	)

	if value < 4:
		return "sick"
	if value < 8:
		return "vacation"
	if value < 18:
		return "off_shift"
	if value < 24:
		return "late"

	return "on_shift"


func _mood(
	score: int,
	status: String
) -> Dictionary:
	if status == "sick":
		score = mini(
			score,
			35
		)
	if status == "late":
		score = mini(
			score,
			48
		)

	if score >= 78:
		return {
			"score": score,
			"label": "Thriving",
			"emoji": "😄"
		}
	if score >= 60:
		return {
			"score": score,
			"label": "Satisfied",
			"emoji": "🙂"
		}
	if score >= 42:
		return {
			"score": score,
			"label": "Tense",
			"emoji": "😕"
		}
	if score >= 24:
		return {
			"score": score,
			"label": "Frustrated",
			"emoji": "😠"
		}

	return {
		"score": score,
		"label": "Burned Out",
		"emoji": "😫"
	}


func _activity(
	person: Person,
	zone_id: String,
	status: String
) -> String:
	if status == "sick":
		return "Called out sick"
	if status == "vacation":
		return "On vacation"
	if status == "off_shift":
		return "Off shift"
	if status == "late":
		return "Running late"

	var map: Dictionary = {
		"break_room": [
			"Eating lunch",
			"Talking with coworkers",
			"Complaining about management",
			"Checking messages"
		],
		"cafeteria": [
			"Eating lunch",
			"Meeting coworkers",
			"Taking a short break"
		],
		"training_yard": [
			"Weapons practice",
			"Morning training",
			"Sparring"
		],
		"operating_room": [
			"Assisting a procedure",
			"Preparing equipment",
			"Leading surgery"
		],
		"classroom": [
			"Teaching a class",
			"Reviewing student work",
			"Preparing a lesson"
		],
		"forge": [
			"Working the anvil",
			"Heating metal",
			"Completing a commission"
		],
		"meeting_room": [
			"Attending a meeting",
			"Presenting progress",
			"Negotiating resources"
		],
		"laboratory": [
			"Running an experiment",
			"Reviewing research",
			"Calibrating equipment"
		]
	}
	var options: Array = _array(
		map.get(
			zone_id,
			[
				"Performing professional duties",
				"Coordinating with the department",
				"Working through an assignment"
			]
		)
	)

	return str(
		options [
			_roll(
				"activity|%d|%d|%s"
				% [
					int(
						person.id
					),
					int(
						gs.year
					),
					zone_id
				],
				0,
				options.size() - 1
			)
		]
	)


func _bond(
	observer: Person,
	target: Person
) -> int:
	if observer == null or target == null:
		return 0

	if (
		gs.relationship_engine != null
		and gs.relationship_engine.has_method(
			"ensure_pair_relationship_baseline"
		)
	):
		return clampi(
			int(
				gs.relationship_engine
				.ensure_pair_relationship_baseline(
					observer,
					target
				)
			),
			0,
			100
		)

	return clampi(
		int(
			observer.affection.get(
				int(
					target.id
				),
				0
			)
		),
		0,
		100
	)


func _archetype(
	path: Dictionary,
	organization: Dictionary,
	assignment: Dictionary
) -> String:
	if path.is_empty() and assignment.is_empty():
		return "career_discovery"

	var material: String = (
		"%s|%s|%s|%s"
		% [
			path.get(
				"path_id",
				""
			),
			path.get(
				"display_name",
				""
			),
			path.get(
				"organization_type",
				""
			),
			path.get(
				"institution",
				organization.get(
					"name",
					""
				)
			)
		]
	).to_lower()

	if _contains(
		material,
		[
			"hospital",
			"medicine",
			"physician",
			"nursing",
			"medical"
		]
	):
		return "hospital"

	if _contains(
		material,
		[
			"school",
			"education",
			"teaching",
			"monastic",
			"scholar"
		]
	):
		return "school"

	if _contains(
		material,
		[
			"knight",
			"legion",
			"military",
			"guard",
			"command"
		]
	):
		return (
			"castle"
			if _era() == "Medieval Era"
			else "military_base"
		)

	if _contains(
		material,
		[
			"painter",
			"painting",
			"illuminator",
			"photography",
			"photographer",
			"artist workshop",
			"portrait studio"
		]
	):
		return "artist_workshop"

	if _contains(
		material,
		[
			"restaurant",
			"fast food",
			"quick service",
			"bakery",
			"kitchen service",
			"dining service"
		]
	):
		return "restaurant"

	if _contains(
		material,
		[
			"grocery",
			"grocer",
			"supermarket",
			"store operations",
			"era-mart",
			"goldleaf",
			"nutripod exchange"
		]
	):
		return "grocery_store"

	if _contains(
		material,
		[
			"factory",
			"manufacturing",
			"production floor",
			"mill worker",
			"textile worker",
			"steel worker",
			"food fabrication"
		]
	):
		return "factory"

	if _contains(
		material,
		[
			"logistics",
			"warehouse",
			"delivery",
			"courier",
			"railway",
			"rail service",
			"river port",
			"dock worker",
			"cargo and loading",
			"drone dispatch"
		]
	):
		return "logistics"

	if _contains(
		material,
		[
			"maintenance",
			"facilities",
			"custodian",
			"building operations",
			"habitat operations"
		]
	):
		return "maintenance"

	if _contains(
		material,
		[
			"blacksmith",
			"smith",
			"forge",
			"craft"
		]
	):
		return "forge"

	if _contains(
		material,
		[
			"farm",
			"farmer",
			"agriculture",
			"harvest",
			"field operations",
			"irrigation"
		]
	):
		return "farm"

	if _contains(
		material,
		[
			"merchant",
			"trade",
			"commerce",
			"market"
		]
	):
		return "merchant"

	if _contains(
		material,
		[
			"law",
			"court",
			"legal",
			"attorney",
			"senate"
		]
	):
		return "legal"

	if _contains(
		material,
		[
			"police",
			"detective",
			"justice"
		]
	):
		return "police_station"

	if _contains(
		material,
		[
			"orbital",
			"interstellar",
			"planetary",
			"mars",
			"quantum",
			"reality stability",
			"space"
		]
	):
		return "orbital_station"

	if _contains(
		material,
		[
			"research",
			"science",
			"engineering",
			"laboratory"
		]
	):
		return "research_center"

	if _era() == "Ancient Era":
		return "ancient_institution"

	if _era() == "Medieval Era":
		return "guild_hall"

	return "office"

func _zones(
	archetype: String
) -> Array:
	match archetype:
		"career_discovery":
			return _discovery_zones()

		"hospital":
			return _zone_data([
				"lobby|Lobby|🏥|Patients, visitors, and staff enter here.",
				"emergency_department|Emergency Department|🚑|Urgent cases are treated here.",
				"nurses_station|Nurses Station|🩺|Care coordination happens here.",
				"operating_room|Operating Room|⚕️|Surgical teams work here.",
				"radiology|Radiology|🩻|Imaging and diagnosis happen here.",
				"cafeteria|Cafeteria|🍽️|Staff socialize here.",
				"meeting_room|Conference Room|📋|Reviews and handoffs happen here."
			])

		"school":
			return _zone_data([
				"entrance|Entrance|🏫|Students and staff enter here.",
				"classroom|Classroom|🧑‍🏫|Teaching happens here.",
				"teachers_lounge|Teachers Lounge|☕|Staff socialize here.",
				"library|Library|📚|Research and preparation happen here.",
				"principal_office|Head Office|🏛️|Leadership and discipline happen here.",
				"cafeteria|Cafeteria|🍎|Meals and social life happen here.",
				"hallways|Hallways|🚪|The institution's social flow passes here."
			])

		"castle":
			return _zone_data([
				"great_hall|Great Hall|🏰|The liege and hierarchy gather here.",
				"barracks|Barracks|🛏️|Knights and squires prepare here.",
				"training_yard|Training Yard|⚔️|Martial evaluation happens here.",
				"armory|Armory|🛡️|Equipment is maintained here.",
				"stables|Stables|🐎|Mounts are prepared here.",
				"watch_tower|Watch Tower|🔭|Threats are observed here.",
				"royal_court|Royal Court|👑|Honor and politics are decided here."
			])

		"military_base":
			return _zone_data([
				"command_center|Command Center|🎖️|Orders originate here.",
				"barracks|Barracks|🛏️|Personnel prepare here.",
				"training_yard|Training Field|🏃|Readiness is tested here.",
				"armory|Armory|🛡️|Equipment is maintained here.",
				"mess_hall|Mess Hall|🍲|Personnel socialize here.",
				"briefing_room|Briefing Room|🗺️|Missions are reviewed here."
			])
		"artist_workshop":
			return _zone_data([
				"studio_floor|Studio Floor| |Artists create and revise work here.",
				"pigment_room|Pigment Room| |Pigments, inks, plates, and materials are prepared here.",
				"patron_room|Patron Room| |Commissions and revisions are discussed here.",
				"drying_gallery|Drying Gallery| |Completed work rests before delivery.",
				"storage|Art Storage| |Materials and finished work are protected here.",
				"guild_hall|Guild Hall| |Standards, reputation, and advancement are decided here."
			])

		"restaurant":
			return _zone_data([
				"front_counter|Front Counter| |Customers place and receive orders here.",
				"kitchen|Kitchen| |Food preparation and service production happen here.",
				"prep_station|Preparation Station| |Ingredients and service stations are prepared here.",
				"dining_room|Dining Room| |Customers eat and interact here.",
				"service_window|Service Window| |Finished orders move into customer service here.",
				"storage|Food Storage| |Ingredients and supplies are stored here.",
				"manager_office|Manager Office| |Scheduling and performance reviews happen here.",
				"break_room|Break Room| |Workers recover and socialize here."
			])

		"grocery_store":
			return _zone_data([
				"entrance|Store Entrance| |Customers and workers enter here.",
				"checkout_lanes|Checkout Lanes| |Transactions and customer service happen here.",
				"store_aisles|Store Aisles| |Inventory is stocked and selected here.",
				"produce_section|Produce Section| |Fresh inventory is maintained here.",
				"stockroom|Stockroom| |Incoming inventory waits here.",
				"receiving_bay|Receiving Bay| |Deliveries are inspected and unloaded here.",
				"manager_office|Manager Office| |Scheduling and performance decisions happen here.",
				"break_room|Break Room| |Store workers recover and socialize here."
			])

		"factory":
			return _zone_data([
				"production_floor|Production Floor| |Core manufacturing happens here.",
				"machine_line|Machine Line| |Workers operate production machinery here.",
				"quality_control|Quality Control| |Finished output is inspected here.",
				"warehouse|Factory Warehouse| |Materials and completed goods are stored here.",
				"maintenance_bay|Maintenance Bay| |Failed machinery is repaired here.",
				"foreman_office|Foreman Office| |Production and performance are reviewed here.",
				"break_room|Break Room| |Workers recover and exchange news here."
			])

		"logistics":
			return _zone_data([
				"dispatch|Dispatch| |Routes and assignments are coordinated here.",
				"loading_bay|Loading Bay| |Cargo enters and leaves the institution here.",
				"warehouse|Warehouse| |Inventory waits for movement here.",
				"route_board|Route Board| |Timing and destination truth is tracked here.",
				"vehicle_yard|Vehicle Yard| |Transport equipment is prepared here.",
				"supervisor_office|Supervisor Office| |Performance and disruptions are reviewed here.",
				"break_room|Break Room| |Workers recover and socialize here."
			])

		"maintenance":
			return _zone_data([
				"service_desk|Service Desk| |Maintenance orders are received here.",
				"equipment_room|Equipment Room| |Tools and diagnostic equipment are stored here.",
				"active_site|Active Work Site| |Current repairs are performed here.",
				"supply_cage|Supply Cage| |Replacement materials are secured here.",
				"control_room|Control Room| |Facility systems are observed here.",
				"supervisor_office|Supervisor Office| |Work orders and performance are reviewed here.",
				"break_room|Break Room| |Workers recover and socialize here."
			])
		"forge":
			return _zone_data([
				"forge|Forge|🔥|Metal is heated and shaped here.",
				"anvil|Anvil Floor|🔨|Core craft work happens here.",
				"supply_room|Supply Room|📦|Materials are stored here.",
				"market_stall|Marketplace Stall|🛒|Goods are sold here.",
				"living_quarters|Living Quarters|🛏️|The household and apprentices recover here."
			])

		"farm":
			return _zone_data([
				"farmhouse|Farmhouse|🏡|Work is planned here.",
				"fields|Fields|🌾|Crops are maintained here.",
				"barn|Barn|🚜|Livestock and equipment are managed here.",
				"chicken_coop|Chicken Coop|🐔|Poultry is managed here.",
				"tool_shed|Tool Shed|🧰|Tools are repaired here.",
				"stable|Stable|🐴|Working animals are housed here.",
				"storage|Storage|📦|Harvest waits for market here."
			])

		"merchant":
			return _zone_data([
				"market_floor|Market Floor|🛍️|Buyers and rivals meet here.",
				"warehouse|Warehouse|📦|Goods are stored here.",
				"contract_room|Contract Room|📜|Deals and routes are negotiated here.",
				"guild_hall|Guild Hall|🏛️|Merchants coordinate here.",
				"loading_yard|Loading Yard|🚚|Goods move here.",
				"common_area|Common Area|☕|Trade information spreads here."
			])

		"legal":
			return _zone_data([
				"lobby|Lobby|⚖️|Clients and staff enter here.",
				"courtroom|Courtroom|🏛️|Cases are argued here.",
				"case_room|Case Room|📁|Evidence and strategy are reviewed here.",
				"archives|Legal Archives|📚|Precedent is stored here.",
				"meeting_room|Partner Meeting Room|📋|Cases and promotions are discussed here.",
				"break_room|Break Room|☕|Staff socialize here."
			])

		"police_station":
			return _zone_data([
				"front_desk|Front Desk|🚓|The public and officers enter here.",
				"evidence_room|Evidence Room|📦|Evidence is secured here.",
				"holding_cells|Holding Cells|🔒|Detainees await processing here.",
				"locker_room|Locker Room|🧥|Officers prepare here.",
				"parking_garage|Parking Garage|🚔|Patrols deploy here.",
				"captain_office|Captain Office|🎖️|Reviews happen here.",
				"break_room|Break Room|☕|Officers socialize here."
			])

		"orbital_station":
			return _zone_data([
				"command_deck|Command Deck|🛰️|Mission decisions happen here.",
				"laboratory|Research Laboratory|🧪|Experiments happen here.",
				"life_support|Life Support|🌬️|Survival systems are maintained here.",
				"observation_ring|Observation Ring|🌌|Space is observed here.",
				"crew_quarters|Crew Quarters|🛏️|Crew members recover here.",
				"ai_core|AI Core|🤖|AI systems coordinate operations here.",
				"hangar|Orbital Hangar|🚀|Missions deploy here."
			])

		"research_center":
			return _zone_data([
				"lobby|Research Lobby|🏢|Researchers enter here.",
				"laboratory|Laboratory|🧪|Experiments happen here.",
				"your_desk|Your Workstation|💻|Analysis happens here.",
				"meeting_room|Project Room|📊|Teams review work here.",
				"prototype_bay|Prototype Bay|🛠️|Systems are tested here.",
				"break_room|Break Room|☕|Researchers socialize here."
			])

		"ancient_institution":
			return _zone_data([
				"courtyard|Courtyard|🏺|Workers and officials gather here.",
				"prayer_hall|Prayer Hall|🕯️|Ritual authority is expressed here.",
				"archives|Archives|📜|State memory is preserved here.",
				"storage_rooms|Storage Rooms|📦|Supplies are kept here.",
				"official_chambers|Official Chambers|🏛️|Senior decisions happen here.",
				"common_area|Common Area|🍞|Workers eat and talk here."
			])

		"guild_hall":
			return _zone_data([
				"guild_hall|Guild Hall|🏛️|Members negotiate standards here.",
				"workshop|Workshop|🛠️|Daily work happens here.",
				"courtyard|Courtyard|🏰|Workers gather here.",
				"storage|Storage|📦|Supplies are kept here.",
				"dining_hall|Dining Hall|🍲|Members exchange news here.",
				"master_chamber|Master Chamber|🗝️|Promotion and politics happen here."
			])

		_:
			return _zone_data([
				"lobby|Lobby|🏢|Workers enter here.",
				"your_desk|Your Desk|💻|Assigned work happens here.",
				"open_office|Open Office|👥|Teams coordinate here.",
				"meeting_room|Meeting Rooms|📋|Projects and reviews happen here.",
				"manager_office|Manager Office|👔|Performance reviews happen here.",
				"break_room|Break Room|☕|Coworkers share news here.",
				"recreation_area|Recreation Area|🎮|Workers recover here.",
				"rooftop_terrace|Rooftop Terrace|🌇|Informal conversations happen here."
			])


func _discovery_zones() -> Array:
	match _era():
		"Ancient Era":
			return _zone_data([
				"marketplace|Marketplace|🏺|Observe trades and apprenticeships.",
				"temple_courtyard|Temple Courtyard|🕯️|Explore scribes and healers.",
				"military_field|Military Field|🛡️|Explore command careers.",
				"artisan_quarter|Artisan Quarter|🔨|Explore crafts."
			])

		"Medieval Era":
			return _zone_data([
				"guild_hall|Guild Hall|🏛️|Browse apprenticeships.",
				"castle_courtyard|Castle Courtyard|🏰|Explore knighthood.",
				"monastery|Monastery|📜|Explore scholarship and medicine.",
				"market_square|Market Square|🛒|Observe trade institutions."
			])

		"Industrial Era":
			return _zone_data([
				"employment_office|Employment Office|🏭|Browse industrial careers.",
				"university_board|University Board|🎓|Inspect education requirements.",
				"union_hall|Union Hall|🤝|Learn about labor and promotion.",
				"company_exhibition|Company Exhibition|🏢|Explore hiring institutions."
			])

		"Future Era":
			return _zone_data([
				"career_nexus|Career Nexus|🌌|Browse planetary and quantum careers.",
				"simulation_gallery|Profession Simulation Gallery|🧠|Preview workplaces.",
				"credential_matrix|Credential Matrix|🎓|Inspect futuristic credentials.",
				"interstellar_registry|Interstellar Registry|🚀|Explore off-world organizations."
			])

		_:
			return _zone_data([
				"career_center|Career Center|💼|Browse careers at any age.",
				"industry_gallery|Industry Gallery|🏢|Explore organizations.",
				"education_desk|Education Desk|🎓|Inspect degrees and licenses.",
				"networking_lounge|Networking Lounge|🤝|Learn about professional relationships."
			])


func _zone_data(
	rows: Array
) -> Array:
	var out: Array = []

	for raw_row in rows:
		var parts: PackedStringArray = str(
			raw_row
		).split(
			"|",
			true,
			3
		)

		if parts.size() < 4:
			continue

		out.append({
			"zone_id": str(
				parts [0]
			),
			"label": str(
				parts [1]
			),
			"icon": str(
				parts [2]
			),
			"description": str(
				parts [3]
			)
		})

	return out


func _space_name(
	archetype: String,
	organization: Dictionary,
	path: Dictionary
) -> String:
	var organization_name: String = str(
		organization.get(
			"name",
			""
		)
	).strip_edges()

	if organization_name != "":
		return organization_name

	if archetype == "career_discovery":
		return "%s Career Discovery" % _era()

	return str(
		path.get(
			"institution",
			path.get(
				"display_name",
				"Career Space"
			)
		)
	)


func _space_id(
	actor: Person,
	organization_id: String,
	path_id: String,
	preview_only: bool
) -> String:
	if organization_id != "":
		return "career::%s" % _slug(
			organization_id
		)

	if path_id != "":
		return (
			"career_preview::%s"
			if preview_only
			else "career::%s"
		) % _slug(
			path_id
		)

	return "career_discovery::%d::%s" % [
		int(
			actor.id
		),
		_slug(
			_era()
		)
	]


func _zone_label(
	zone_id: String,
	rows: Array
) -> String:
	for raw_row in rows:
		var row: Dictionary = _dict(
			raw_row
		)

		if str(
			row.get(
				"zone_id",
				""
			)
		) == zone_id:
			return str(
				row.get(
					"label",
					zone_id
				)
			)

	return zone_id.replace(
		"_",
		" "
	).capitalize()


func _empty_shard() -> Dictionary:
	return {
		"rows": [],
		"total": 0,
		"offset": 0,
		"limit": 0,
		"next_offset": 0,
		"has_more": false
	}


func _contains(
	material: String,
	needles: Array
) -> bool:
	for raw_needle in needles:
		if material.find(
			str(
				raw_needle
			).to_lower()
		) != -1:
			return true

	return false


func _stars(
	value: int
) -> String:
	var filled: int = clampi(
		int(
			round(
				float(
					value
				) / 20.0
			)
		),
		0,
		5
	)

	return (
		"★".repeat(
			filled
		)
		+ "☆".repeat(
			5 - filled
		)
	)


func _runtime():
	return (
		gs.career_runtime_engine
		if gs != null
		else null
	)


func _law():
	return (
		gs.career_contract_engine
		if gs != null
		else null
	)


func _shared():
	return (
		gs.shared_public_space_engine
		if gs != null
		else null
	)


func _person(
	actor_id: int
) -> Person:
	if gs == null or actor_id <= 0:
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == actor_id
	):
		return gs.player

	if gs.has_method(
		"get_or_reactivate_npc_by_id"
	):
		return gs.get_or_reactivate_npc_by_id(
			actor_id
		)

	if gs.has_method(
		"get_npc_by_id"
	):
		return gs.get_npc_by_id(
			actor_id
		)

	return null


func _name(
	person: Person
) -> String:
	if person == null:
		return "Unknown Person"

	var full_name: String = (
		"%s %s"
		% [
			str(
				person.first_name
			),
			str(
				person.last_name
			)
		]
	).strip_edges()

	return (
		full_name
		if full_name != ""
		else "Person %d"
		% int(
			person.id
		)
	)


func _era() -> String:
	return (
		str(
			gs.era.get(
				"name",
				"Unknown Era"
			)
		)
		if gs != null and gs.era != null
		else "Unknown Era"
	)


func _roll(
	material: String,
	minimum: int,
	maximum: int
) -> int:
	var low: int = mini(
		minimum,
		maximum
	)
	var high: int = maxi(
		minimum,
		maximum
	)
	var span: int = (
		high - low + 1
	)

	return (
		low
		if span <= 1
		else low
		+ posmod(
			int(
				str(
					material
				).hash()
			),
			span
		)
	)


func _slug(
	value: String
) -> String:
	var out: String = str(
		value
	).strip_edges().to_lower()

	for token in [
		" ",
		"-",
		"/",
		"\\",
		":",
		".",
		",",
		"'",
		"\""
	]:
		out = out.replace(
			token,
			"_"
		)

	while "__" in out:
		out = out.replace(
			"__",
			"_"
		)

	return out.trim_prefix(
		"_"
	).trim_suffix(
		"_"
	)


func _dict(
	value
) -> Dictionary:
	return (
		(value as Dictionary).duplicate(true)
		if typeof(value) == TYPE_DICTIONARY
		else {}
	)


func _array(
	value
) -> Array:
	return (
		(value as Array).duplicate(true)
		if typeof(value) == TYPE_ARRAY
		else []
	)


func _fail(
	reason: String,
	text: String
) -> Dictionary:
	EraLog.failure(
		get_script().resource_path.get_file(),
		str(reason)
	)
	return {
		"success": false,
		"schema": ENGINE_SCHEMA,
		"version": ENGINE_VERSION,
		"reason": reason,
		"text": text,
		"ui_is_renderer_only": true
	}