extends Resource
class_name RelationshipEngine

var gs
func _init(_gs):
	gs = _gs


func update_relationship(_player, _npc):
	if _player == null or _npc == null:
		return 0

	var base: int = _baseline_relationship_score(
		_player,
		_npc
	)

	if "Loyal" in _player.traits:
		base += 6

	if "Jealous" in _player.traits:
		base -= 8

	if gs.agent_memory_propagation_engine != null:
		base += (
			gs.agent_memory_propagation_engine
			.get_memory_modifier(
				_player,
				_npc
			)
		)

	if gs.dynasty_legacy_engine != null:
		base += (
			gs.dynasty_legacy_engine
			.get_relationship_modifier(
				_player,
				_npc
			)
		)

	return clamp(
		base,
		0,
		100
	)


func ensure_pair_relationship_baseline(
	a: Person,
	b: Person
) -> int:
	if (
		a == null
		or b == null
	):
		return 0

	var a_id: int = int(
		a.id
	)
	var b_id: int = int(
		b.id
	)



	if (
		a_id <= 0
		or b_id <= 0
	):
		return 0

	if a_id == b_id:
		return 100

	if typeof(a.affection) != TYPE_DICTIONARY:
		a.affection = {}

	if typeof(b.affection) != TYPE_DICTIONARY:
		b.affection = {}

	var a_has_b: bool = a.affection.has(
		b_id
	)
	var b_has_a: bool = b.affection.has(
		a_id
	)



	if not a_has_b:
		a.affection [b_id] = clampi(
			int(
				update_relationship(
					a,
					b
				)
			),
			0,
			100
		)

	if not b_has_a:
		b.affection [a_id] = clampi(
			int(
				update_relationship(
					b,
					a
				)
			),
			0,
			100
		)









	return clampi(
		int(
			a.affection.get(
				b_id,
				0
			)
		),
		0,
		100
	)


func observe_pair_relationship_baseline(
	observer: Person,
	target: Person
) -> int:
	if (
		observer == null
		or target == null
	):
		return 0

	if int(observer.id) == int(target.id):
		return 100

	if (
		typeof(observer.affection) == TYPE_DICTIONARY
		and observer.affection.has(
			int(target.id)
		)
	):
		return clampi(
			int(
				observer.affection.get(
					int(target.id),
					0
				)
			),
			0,
			100
		)




	return clampi(
		_baseline_relationship_score(
			observer,
			target
		),
		0,
		100
	)
func people_are_family(
	first_person: Person,
	second_person: Person
) -> bool:
	return _people_are_family(
		first_person,
		second_person
	)
func seed_family_and_stranger_bonds_for_actor(
	anchor: Person,
	context: Dictionary = {}
) -> Dictionary:
	if anchor == null or gs == null:
		return {
			"success": false,
			"seeded": 0,
			"reason": "Missing anchor or GameState."
		}

	if typeof(anchor.affection) != TYPE_DICTIONARY:
		anchor.affection = {}

	var target_ids_raw: Variant = context.get(
		"target_ids",
		[]
	)
	var target_ids: Array = (
		(target_ids_raw as Array).duplicate()
		if typeof(target_ids_raw) == TYPE_ARRAY
		else []
	)
	var explicit_target_scope: bool = not target_ids.is_empty()
	var include_strangers: bool = bool(
		context.get(
			"include_strangers",
			not explicit_target_scope
		)
	)
	var candidates: Array = []

	if explicit_target_scope:
		var seen_ids: Dictionary = {}

		for raw_target_id in target_ids:
			var target_id: int = int(
				raw_target_id
			)

			if (
				target_id <= 0
				or target_id == int(
					anchor.id
				)
			):
				continue

			var target_key: String = str(
				target_id
			)

			if seen_ids.has(
				target_key
			):
				continue

			seen_ids [
				target_key
			] = true

			var person: Person = null

			if gs.has_method(
				"get_npc_by_id"
			):
				person = gs.get_npc_by_id(
					target_id
				)

			if (
				person == null
				and gs.has_method(
					"get_or_reactivate_npc_by_id"
				)
			):
				person = gs.get_or_reactivate_npc_by_id(
					target_id
				)

			if person != null:
				candidates.append(
					person
				)
	else:


		candidates = gs.npcs.duplicate()

	var seeded: int = 0
	var family_seeded: int = 0
	var strangers_seeded: int = 0

	for raw_person in candidates:
		if (
			raw_person == null
			or not (
				raw_person is Person
			)
		):
			continue

		var person: Person = raw_person as Person

		if int(person.id) == int(anchor.id):
			continue

		var is_family: bool = _people_are_family(
			anchor,
			person
		)

		if (
			not explicit_target_scope
			and not include_strangers
			and not is_family
		):
			continue

		var before_has: bool = anchor.affection.has(
			int(
				person.id
			)
		)
		var score: int = ensure_pair_relationship_baseline(
			anchor,
			person
		)

		if not before_has:
			seeded += 1

			if is_family:
				family_seeded += 1
			elif score == 0:
				strangers_seeded += 1

	return {
		"success": true,
		"seeded": seeded,
		"family_seeded": family_seeded,
		"strangers_seeded": strangers_seeded,
		"anchor_id": int(
			anchor.id
		),
		"candidate_count": candidates.size(),
		"explicit_target_scope": explicit_target_scope,
		"include_strangers": include_strangers,
		"bounded_first_frame_contract": bool(
			context.get(
				"bounded_first_frame_contract",
				false
			)
		),
		"source": str(
			context.get(
				"source",
				"relationship_engine"
			)
		)
	}

func _baseline_relationship_score(observer: Person, target: Person) -> int:
	if observer == null or target == null:
		return 0

	if int(observer.id) == int(target.id):
		return 100

	var role: String = _relationship_role_between(observer, target)

	match role:
		"parent_to_child":
			return _stable_relationship_score(observer, target, role, 82, 98)
		"baby_to_parent":
			return _stable_relationship_score(observer, target, role, 76, 96)
		"child_to_parent":
			return _stable_relationship_score(observer, target, role, 66, 92)
		"partner":
			return _stable_relationship_score(observer, target, role, 58, 88)
		"older_sibling_to_younger_sibling":
			var jealousy_penalty: int = _stable_relationship_score(observer, target, "sibling_jealousy", 0, 20)
			return clamp(_stable_relationship_score(observer, target, role, 58, 82) - jealousy_penalty, 35, 82)
		"younger_sibling_to_older_sibling":
			return _stable_relationship_score(observer, target, role, 52, 78)
		"sibling":
			return _stable_relationship_score(observer, target, role, 54, 80)
		"grandparent_to_grandchild":
			return _stable_relationship_score(observer, target, role, 62, 88)
		"grandchild_to_grandparent":
			return _stable_relationship_score(observer, target, role, 54, 78)
		"great_grandparent_to_great_grandchild":
			return _stable_relationship_score(observer, target, role, 56, 82)
		"great_grandchild_to_great_grandparent":
			return _stable_relationship_score(observer, target, role, 46, 70)
		"aunt_uncle_to_niece_nephew":
			return _stable_relationship_score(observer, target, role, 52, 76)
		"niece_nephew_to_aunt_uncle":
			return _stable_relationship_score(observer, target, role, 48, 72)
		"cousin":
			return _stable_relationship_score(observer, target, role, 42, 68)
		"friend":
			return _stable_relationship_score(observer, target, role, 55, 82)
		_:
			return 0
func crime_target_relationship_contract(
	observer: Person,
	target: Person
) -> Dictionary:
	if (
		observer == null
		or target == null
		or int(
			observer.id
		) == int(
			target.id
		)
	):
		return {
			"eligible": false,
			"classification": "invalid"
		}

	var role: String = _relationship_role_between(
		observer,
		target
	)

	var observer_has_edge: bool = (
		typeof(
			observer.affection
		) == TYPE_DICTIONARY
		and observer.affection.has(
			int(
				target.id
			)
		)
	)

	var target_has_edge: bool = (
		typeof(
			target.affection
		) == TYPE_DICTIONARY
		and target.affection.has(
			int(
				observer.id
			)
		)
	)

	var has_social_edge: bool = (
		observer_has_edge
		or target_has_edge
	)







	var allowed_family_role: bool = (
		role in [
			"partner",
			"baby_to_parent",
			"child_to_parent",
			"older_sibling_to_younger_sibling",
			"younger_sibling_to_older_sibling",
			"sibling",
			"grandchild_to_grandparent",
			"great_grandchild_to_great_grandparent",
			"niece_nephew_to_aunt_uncle"
		]
	)










	var classification: String = role

	var unrelated_stranger: bool = (
		role == "stranger"
	)







	var target_gender: String = str(
		target.gender
	).strip_edges().to_lower()

	var target_relationship_title: String = ""

	match role:
		"baby_to_parent", "child_to_parent":
			target_relationship_title = "Parent"

			if target_gender == "male":
				target_relationship_title = "Dad"
			elif target_gender == "female":
				target_relationship_title = "Mom"

		"parent_to_child":
			target_relationship_title = "Child"

			if target_gender == "male":
				target_relationship_title = "Son"
			elif target_gender == "female":
				target_relationship_title = "Daughter"

		"older_sibling_to_younger_sibling", \
"younger_sibling_to_older_sibling", \
"sibling":
			target_relationship_title = "Sibling"

			if target_gender == "male":
				target_relationship_title = "Brother"
			elif target_gender == "female":
				target_relationship_title = "Sister"

		"grandchild_to_grandparent":
			target_relationship_title = "Grandparent"

			if target_gender == "male":
				target_relationship_title = "Grandpa"
			elif target_gender == "female":
				target_relationship_title = "Grandma"

		"grandparent_to_grandchild":
			target_relationship_title = "Grandchild"

			if target_gender == "male":
				target_relationship_title = "Grandson"
			elif target_gender == "female":
				target_relationship_title = "Granddaughter"

		"great_grandchild_to_great_grandparent":
			target_relationship_title = "Great-Grandparent"

			if target_gender == "male":
				target_relationship_title = "Great-Grandpa"
			elif target_gender == "female":
				target_relationship_title = "Great-Grandma"

		"great_grandparent_to_great_grandchild":
			target_relationship_title = "Great-Grandchild"

			if target_gender == "male":
				target_relationship_title = "Great-Grandson"
			elif target_gender == "female":
				target_relationship_title = "Great-Granddaughter"

		"niece_nephew_to_aunt_uncle":
			target_relationship_title = "Aunt/Uncle"

			if target_gender == "male":
				target_relationship_title = "Uncle"
			elif target_gender == "female":
				target_relationship_title = "Aunt"

		"aunt_uncle_to_niece_nephew":
			target_relationship_title = "Niece/Nephew"

			if target_gender == "male":
				target_relationship_title = "Nephew"
			elif target_gender == "female":
				target_relationship_title = "Niece"

		"partner":
			target_relationship_title = "Partner"

		"friend":
			target_relationship_title = "Friend"

		"cousin":
			target_relationship_title = "Cousin"

		"stranger":
			target_relationship_title = "Unrelated stranger"

		_:
			target_relationship_title = role.replace(
				"_",
				" "
			).capitalize()

	if OS.is_debug_build():
		EraLog.truth(
			"ERALIFE_CRIME_PIPELINE_TRUTH"
			+ "|authority=RelationshipEngine"
			+ "|stage=candidate_evaluated"
			+ "|actor_id=%d" % int(
				observer.id
			)
			+ "|target_id=%d" % int(
				target.id
			)
			+ "|role=%s" % role
			+ "|eligible=%s" % str(
				allowed_family_role
				or unrelated_stranger
			)
			+ "|meaningful_relationship=%s" % str(
				allowed_family_role
			)
			+ "|unrelated_stranger=%s" % str(
				unrelated_stranger
			)
			+ "|at_ms=%d" % int(
				Time.get_ticks_msec()
			)
		)

	return {
		"eligible": (
			allowed_family_role
			or unrelated_stranger
		),
		"observer_id": int(
			observer.id
		),
		"target_id": int(
			target.id
		),
		"role": role,
		"classification": classification,
		"target_relationship_title": target_relationship_title,
		"relationship_title_perspective": "target_to_observer",
		"meaningful_relationship": allowed_family_role,
		"allowed_target_family_role": allowed_family_role,
		"unrelated_stranger": unrelated_stranger,
		"seeded_social_edge_present": has_social_edge,
		"target_policy_authority": (
			"relationship_engine"
		),
		"target_policy": (
			"partner_parents_ancestors_siblings_aunts_uncles"
		),
		"descendants_excluded": true,
		"friends_excluded": true,
		"cousins_excluded": true,
		"acquaintances_excluded": true,
		"read_only": true
	}
func _relationship_role_between(observer: Person, target: Person) -> String:
	if observer == null or target == null:
		return "stranger"

	if int(target.id) in _safe_person_id_array(observer, "parents"):
		if int(observer.age) <= 2:
			return "baby_to_parent"
		return "child_to_parent"

	if int(observer.id) in _safe_person_id_array(target, "parents"):
		return "parent_to_child"

	if observer.partner != null and int(observer.partner.id) == int(target.id):
		return "partner"
	if target.partner != null and int(target.partner.id) == int(observer.id):
		return "partner"

	if int(target.id) in _safe_person_id_array(observer, "friends"):
		return "friend"

	if _people_are_siblings(observer, target):
		if int(observer.age) >= int(target.age) + 2:
			return "older_sibling_to_younger_sibling"
		if int(target.age) >= int(observer.age) + 2:
			return "younger_sibling_to_older_sibling"
		return "sibling"

	if _is_grandparent_of(observer, target):
		return "grandparent_to_grandchild"
	if _is_grandparent_of(target, observer):
		return "grandchild_to_grandparent"

	if _is_great_grandparent_of(observer, target):
		return "great_grandparent_to_great_grandchild"
	if _is_great_grandparent_of(target, observer):
		return "great_grandchild_to_great_grandparent"

	if _is_aunt_uncle_of(observer, target):
		return "aunt_uncle_to_niece_nephew"
	if _is_aunt_uncle_of(target, observer):
		return "niece_nephew_to_aunt_uncle"

	if _people_are_cousins(observer, target):
		return "cousin"

	return "stranger"

func _people_are_family(a: Person, b: Person) -> bool:
	if a == null or b == null:
		return false

	var role: String = _relationship_role_between(a, b)
	return role != "stranger" and role != "friend"

func _people_are_siblings(a: Person, b: Person) -> bool:
	if a == null or b == null:
		return false

	var a_parents: Array = _safe_person_id_array(a, "parents")
	var b_parents: Array = _safe_person_id_array(b, "parents")

	for raw_parent_id in a_parents:
		if int(raw_parent_id) in b_parents:
			return true

	return false

func _is_grandparent_of(
	grandparent: Person,
	child: Person
) -> bool:
	if (
		grandparent == null
		or child == null
		or gs == null
	):
		return false

	var grandparent_id: int = int(
		grandparent.id
	)

	for raw_parent_id in _safe_person_id_array(
		child,
		"parents"
	):
		var parent_id: int = int(
			raw_parent_id
		)

		if grandparent_id in (
			_parent_ids_for_person_id_read_only(
				parent_id
			)
		):
			return true

	return false
func _parent_ids_for_person_id_read_only(
	person_id: int
) -> Array:
	var out: Array = []

	if (
		gs == null
		or person_id <= 0
	):
		return out

	var resident: Person = null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == person_id
	):
		resident = gs.player
	elif gs.has_method(
		"get_npc_by_id"
	):
		var resident_raw: Variant = gs.get_npc_by_id(
			person_id,
			false
		)

		if resident_raw is Person:
			resident = resident_raw as Person

	if resident != null:
		return _safe_person_id_array(
			resident,
			"parents"
		)

	if not gs.has_method(
		"get_dormant_npc_snapshot"
	):
		return out

	var snapshot_raw: Variant = (
		gs.get_dormant_npc_snapshot(
			person_id
		)
	)

	if typeof(snapshot_raw) != TYPE_DICTIONARY:
		return out

	var snapshot: Dictionary = (
		snapshot_raw as Dictionary
	)
	var parents_raw: Variant = snapshot.get(
		"parents",
		[]
	)

	if typeof(parents_raw) != TYPE_ARRAY:
		return out

	var parent_rows: Array = (
		parents_raw as Array
	)

	for raw_parent_id in parent_rows:
		var resolved_id: int = int(
			raw_parent_id
		)

		if (
			resolved_id <= 0
			or resolved_id in out
		):
			continue

		out.append(
			resolved_id
		)

	return out
func _is_great_grandparent_of(
	great_grandparent: Person,
	child: Person
) -> bool:
	if (
		great_grandparent == null
		or child == null
		or gs == null
	):
		return false

	var great_grandparent_id: int = int(
		great_grandparent.id
	)

	for raw_parent_id in _safe_person_id_array(
		child,
		"parents"
	):
		var parent_id: int = int(
			raw_parent_id
		)

		for raw_grandparent_id in (
			_parent_ids_for_person_id_read_only(
				parent_id
			)
		):
			var grandparent_id: int = int(
				raw_grandparent_id
			)

			if great_grandparent_id in (
				_parent_ids_for_person_id_read_only(
					grandparent_id
				)
			):
				return true

	return false
func _is_aunt_uncle_of(
	adult_relative: Person,
	child: Person
) -> bool:
	if (
		adult_relative == null
		or child == null
		or gs == null
	):
		return false

	var adult_parent_ids: Array = (
		_safe_person_id_array(
			adult_relative,
			"parents"
		)
	)

	if adult_parent_ids.is_empty():
		return false

	for raw_child_parent_id in _safe_person_id_array(
		child,
		"parents"
	):
		var child_parent_id: int = int(
			raw_child_parent_id
		)
		var child_parent_parent_ids: Array = (
			_parent_ids_for_person_id_read_only(
				child_parent_id
			)
		)

		for raw_shared_parent_id in adult_parent_ids:
			if int(
				raw_shared_parent_id
			) in child_parent_parent_ids:
				return true

	return false

func _people_are_cousins(
	a: Person,
	b: Person
) -> bool:
	if (
		a == null
		or b == null
		or gs == null
	):
		return false

	for raw_a_parent_id in _safe_person_id_array(
		a,
		"parents"
	):
		var a_parent_id: int = int(
			raw_a_parent_id
		)
		var a_grandparent_ids: Array = (
			_parent_ids_for_person_id_read_only(
				a_parent_id
			)
		)

		if a_grandparent_ids.is_empty():
			continue

		for raw_b_parent_id in _safe_person_id_array(
			b,
			"parents"
		):
			var b_parent_id: int = int(
				raw_b_parent_id
			)
			var b_grandparent_ids: Array = (
				_parent_ids_for_person_id_read_only(
					b_parent_id
				)
			)

			for raw_grandparent_id in a_grandparent_ids:
				if int(
					raw_grandparent_id
				) in b_grandparent_ids:
					return true

	return false
func _safe_person_id_array(person: Person, property_id: String) -> Array:
	var out: Array = []
	if person == null:
		return out

	var raw_value: Variant = person.get(property_id)
	if typeof(raw_value) != TYPE_ARRAY:
		return out

	for raw_id in raw_value:
		var resolved_id: int = int(raw_id)
		if resolved_id <= 0:
			continue
		if resolved_id in out:
			continue
		out.append(resolved_id)

	return out

func _resolve_person(
	person_id: int
) -> Person:
	if (
		gs == null
		or person_id <= 0
	):
		return null

	if (
		gs.player != null
		and int(
			gs.player.id
		) == person_id
	):
		return gs.player

	if gs.has_method(
		"get_npc_by_id"
	):
		var resident_raw: Variant = gs.get_npc_by_id(
			person_id,
			false
		)

		if resident_raw is Person:
			return resident_raw as Person



	return null
func _stable_relationship_score(observer: Person, target: Person, salt: String, low: int, high: int) -> int:
	if observer == null or target == null:
		return low

	var material: String = "%s|%s|%s|%s|%s" % [
		str(int(observer.id)),
		str(int(target.id)),
		str(observer.first_name),
		str(target.first_name),
		str(salt)
	]
	var seed_value: int = int(hash(material))
	if seed_value < 0:
		seed_value = - seed_value
	if seed_value <= 0:
		seed_value = 1

	var rng:= RandomNumberGenerator.new()
	rng.seed = seed_value
	return int(rng.randi_range(low, high))
func update_relationships_for_npc(
	npc,
	max_neighbors_per_quantum: int = 1
) -> Dictionary:
	if gs == null or gs.social_graph_engine == null:
		return {
			"success": false,
			"reason": "relationship_runtime_unavailable",
			"is_complete": true,
			"cycle_complete": true,
			"processed_this_quantum": 0
		}

	var resolved_npc = npc





	if typeof(npc) == TYPE_DICTIONARY:
		var payload: Dictionary = npc as Dictionary
		var requested_npc_id: int = int(
			payload.get(
				"npc_id",
				payload.get(
					"actor_id",
					-1
				)
			)
		)

		resolved_npc = null

		if (
			gs.player != null
			and int(gs.player.id) == requested_npc_id
		):
			resolved_npc = gs.player
		elif (
			requested_npc_id > 0
			and gs.has_method(
				"get_npc_by_id"
			)
		):
			resolved_npc = gs.get_npc_by_id(
				requested_npc_id,
				false
			)

	if resolved_npc == null:
		return {
			"success": false,
			"reason": "relationship_runtime_npc_unavailable",
			"is_complete": true,
			"cycle_complete": true,
			"processed_this_quantum": 0,
		}

	var neighbors_raw: Variant = (
		gs.social_graph_engine.get_connections(
			int(resolved_npc.id)
		)
	)
	var neighbors: Array = (
		neighbors_raw as Array
		if typeof(neighbors_raw) == TYPE_ARRAY
		else []
	)
	var npc_key: String = str(
		int(resolved_npc.id)
	)

	var cursor_registry_raw: Variant = get_meta(
		"realtime_relationship_cursor_by_npc",
		{}
	)
	var cursor_registry: Dictionary = (
		cursor_registry_raw as Dictionary
		if typeof(cursor_registry_raw) == TYPE_DICTIONARY
		else {}
	)

	if neighbors.is_empty():
		cursor_registry.erase(
			npc_key
		)
		set_meta(
			"realtime_relationship_cursor_by_npc",
			cursor_registry
		)

		return {
			"success": true,
			"is_complete": true,
			"cycle_complete": true,
			"npc_id": int(resolved_npc.id),
			"processed_this_quantum": 0,
			"remaining": 0,
		}

	var cursor: int = clampi(
		int(
			cursor_registry.get(
				npc_key,
				0
			)
		),
		0,
		neighbors.size()
	)

	if cursor >= neighbors.size():
		cursor = 0

	var processed_this_quantum: int = 0
	var quantum_limit: int = clampi(
		max_neighbors_per_quantum,
		1,
		1
	)

	if (
		cursor < neighbors.size()
		and processed_this_quantum < quantum_limit
	):
		var other_id: int = int(
			neighbors [cursor]
		)



		cursor += 1
		processed_this_quantum += 1

		var other = null

		if (
			gs.player != null
			and int(gs.player.id) == other_id
		):
			other = gs.player
		elif (
			other_id > 0
			and gs.has_method(
				"get_npc_by_id"
			)
		):
			other = gs.get_npc_by_id(
				other_id,
				false
			)

		if other != null:
			var baseline: int = ensure_pair_relationship_baseline(
				resolved_npc,
				other
			)
			var delta: int = randi_range(
				-2,
				2
			)

			if gs.agent_memory_propagation_engine != null:
				delta += int(
					gs.agent_memory_propagation_engine.get_memory_modifier(
						resolved_npc,
						other
					) / 10
				)

			if gs.dynasty_legacy_engine != null:
				delta += int(
					gs.dynasty_legacy_engine.get_relationship_modifier(
						resolved_npc,
						other
					) / 10
				)

			resolved_npc.affection [other.id] = clamp(
				int(
					resolved_npc.affection.get(
						other.id,
						baseline
					)
				) + delta,
				0,
				100
			)

	var cycle_complete: bool = (
		cursor >= neighbors.size()
	)

	if cycle_complete:
		cursor_registry.erase(
			npc_key
		)
	else:
		cursor_registry [
			npc_key
		] = cursor

	set_meta(
		"realtime_relationship_cursor_by_npc",
		cursor_registry
	)

	return {
		"success": true,
		"is_complete": cycle_complete,
		"cycle_complete": cycle_complete,
		"npc_id": int(resolved_npc.id),
		"processed_this_quantum": processed_this_quantum,
		"cursor": cursor,
		"remaining": maxi(
			0,
			neighbors.size() - cursor
		),
		"intrinsically_bounded": true,
		"max_relationship_edges_per_quantum": 1
	}
func adjust_relationship(a: Person, b: Person, delta: int) -> void:
	if a == null or b == null:
		return

	if a.affection == null:
		a.affection = {}
	if b.affection == null:
		b.affection = {}

	var a_to_b: int = int(a.affection.get(b.id, update_relationship(a, b)))
	var b_to_a: int = int(b.affection.get(a.id, update_relationship(b, a)))

	a.affection [b.id] = clamp(a_to_b + int(delta), 0, 100)

	var mirrored_delta: int = int(round(float(delta) * 0.65))
	b.affection [a.id] = clamp(b_to_a + mirrored_delta, 0, 100)