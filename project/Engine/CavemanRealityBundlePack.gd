

extends RefCounted
class_name CavemanRealityBundlePack

const BUNDLE_SCHEMA:= "eralife.mod_bundle_contract"
const BUNDLE_VERSION:= 1
const BUNDLE_ID:= "eralife.caveman_reality_pack"
const ROOT_MOD_ID:= "eralife.caveman_pack"
const EXPERIENCE_ID:= "eralife.experience.caveman_survival"


static func bundle_contract() -> Dictionary:
	return {
		"schema": BUNDLE_SCHEMA,
		"version": BUNDLE_VERSION,
		"bundle_id": BUNDLE_ID,
		"root_mod_id": ROOT_MOD_ID,
		"experience_id": EXPERIENCE_ID,
		"name": "Caveman Reality Pack",
		"short_name": "Caveman Pack",
		"author": "EraLife",
		"release_version": "1.0.0",
		"unlock_survival_all_ages": {
			"type": "bool",
			"label": "All-Age Survival",
			"description": (
				"Temporarily removes age gates from survival actions. "
				+ "Turning it off restores the original age rules."
			),
			"default": false
		},
		"description": (
			"A hot-swappable prehistoric survival reality "
			+ "with tribal roles, contribution governance, "
			+ "resource economy, megafauna, and its own menu."
		),
		"featured": true,
		"first_party": true,
		"installed_by_default": false,
		"enabled_by_default": false,
		"component_order": component_order(),
		"all_in_one_component_ids": component_order(),
		"components": _components(),
		"experience_contract": _experience_contract(),
		"bundle_menu_contract": _bundle_menu_contract(),
		"compatibility": {
			"min_mod_contract_version": 3,
			"provider_api_versions": {
				"activities": 1,
				"roles": 1,
				"governance": 1,
				"economy_modes": 1,
				"fauna": 1,
				"era_overlays": 1,
				"world_taxonomy": 1,
				"birth_narratives": 1,
				"presentation": 1,
				"mod_menus": 1,
				"system_policies": 1
			}
		},
		"lifecycle": {
			"disable_policy": (
				"restore_base_provider_reality"
			),
			"uninstall_policy": (
				"preserve_bundle_save_slice"
			)
		},
		"default_settings": {
			"survival_intensity": 3,
			"megafauna_frequency": "Balanced",
			"unlock_survival_all_ages": false
		},
		"metadata": {
			"catalog_source": (
				"eralife_first_party_bundle_catalog"
			),
		}
	}


static func component_order() -> Array:
	return [
		"activities",
		"roles",
		"governance",
		"survival_economy",
		"fauna",
		"presentation",
		"birth_narrative",
		"bundle_menu"
	]


static func assembled_mod_contract(
	selected_component_ids: Array = []
) -> Dictionary:
	var selected: Array = (
		selected_component_ids.duplicate(true)
	)

	if selected.is_empty():
		selected = component_order()

	var components: Dictionary = _components()
	var providers: Array = []
	var normalized_selected: Array = []

	for raw_component_id in component_order():
		var component_id: String = str(
			raw_component_id
		)

		if component_id not in selected:
			continue

		var component: Dictionary = _dict(
			components.get(
				component_id,
				{}
			)
		)

		if component.is_empty():
			continue

		normalized_selected.append(component_id)
		providers.append_array(
			_array(
				component.get(
					"providers",
					[]
				)
			)
		)

	return {
		"schema": "eralife.mod_contract",
		"version": 3,
		"mod_id": ROOT_MOD_ID,
		"id": ROOT_MOD_ID,
		"bundle_id": BUNDLE_ID,
		"bundle_component_ids": normalized_selected,
		"experience_id": EXPERIENCE_ID,
		"name": "Caveman Reality Pack",
		"description": (
			"Turns the current EraLife reality into a "
			+ "prehistoric tribal survival experience "
			+ "without replacing identity or chronology."
		),
		"author": "EraLife",
		"release_version": "1.0.0",
		"enabled": false,
		"priority": 900,
		"conflict_policy": "highest_priority",
		"providers": providers,
		"permissions": {
			"execution_mode": "data_only",
			"trusted_ui_contracts": true,
			"bundle_service_routes": [
				"caveman_reality"
			]
		},
		"compatibility": _dict(
			bundle_contract().get(
				"compatibility",
				{}
			)
		),
		"settings_schema": {
			"survival_intensity": {
				"type": "int",
				"label": "Survival Intensity",
				"description": (
					"Controls resource pressure without "
					+ "changing provider topology."
				),
				"minimum": 1,
				"maximum": 5,
				"step": 1,
				"default": 3
			},
			"megafauna_frequency": {
				"type": "option",
				"label": "Megafauna Frequency",
				"options": [
					"Low",
					"Balanced",
					"High"
				],
				"default": "Balanced"
			}
		},
		"default_settings": {
			"survival_intensity": 3,
			"megafauna_frequency": "Balanced"
		},
		"experience_contract": _experience_contract(),
		"bundle_menu_contract": _bundle_menu_contract(),
		"metadata": {
			"first_party": true,
			"bundle_id": BUNDLE_ID,
			"experience_id": EXPERIENCE_ID,
			"selected_component_ids": normalized_selected,
		}
	}


static func marketplace_row() -> Dictionary:
	var contract: Dictionary = bundle_contract()

	return {
		"mod_id": ROOT_MOD_ID,
		"bundle_id": BUNDLE_ID,
		"listing_kind": "reality_bundle",
		"name": str(
			contract.get(
				"name",
				"Caveman Reality Pack"
			)
		),
		"description": str(
			contract.get(
				"description",
				""
			)
		),
		"author": "EraLife",
		"release_version": "1.0.0",
		"featured": true,
		"rating": 5.0,
		"downloads": 0,
		"installed": false,
		"bundle_contract": contract,
		"compatibility": {
			"compatible": true,
			"status": "compatible",
			"reasons": [],
			"warnings": []
		}
	}


static func _components() -> Dictionary:
	return {
		"activities": {
			"component_id": "activities",
			"name": "Caveman Activities",
			"description": (
				"Prehistoric survival actions."
			),
			"providers": [
				_activities_provider()
			]
		},
		"roles": {
			"component_id": "roles",
			"name": "Tribal Roles",
			"description": (
				"Contribution-based roles replace careers."
			),
			"providers": [
				_roles_provider(),
				_system_policy_provider()
			]
		},
		"governance": {
			"component_id": "governance",
			"name": "Tribal Governance",
			"description": (
				"Survival contribution, elders, and "
				+ "one tribe leader."
			),
			"providers": [
				_governance_provider()
			]
		},
		"survival_economy": {
			"component_id": "survival_economy",
			"name": "Resource Survival Economy",
			"description": (
				"Food, wood, stone, hide, bone, and fire."
			),
			"providers": [
				_economy_provider()
			]
		},
		"fauna": {
			"component_id": "fauna",
			"name": "Prehistoric Fauna",
			"description": (
				"Dinosaurs, sabre-tooth tigers, "
				+ "and short-faced bears."
			),
			"providers": [
				_fauna_provider()
			]
		},
		"presentation": {
			"component_id": "presentation",
			"name": "Prehistoric Presentation",
			"description": (
				"Contract-driven labels, navigation, "
				+ "taxonomy, and palette."
			),
			"providers": [
				_era_overlay_provider(),
				_world_taxonomy_provider(),
				_presentation_provider()
			]
		},
		"birth_narrative": {
			"component_id": "birth_narrative",
			"name": "Caveman Birth Narrative",
			"description": (
				"A newborn enters the diary through "
				+ "tribal survival truth."
			),
			"providers": [
				_birth_narrative_provider()
			]
		},
		"bundle_menu": {
			"component_id": "bundle_menu",
			"name": "Caveman Menu",
			"description": (
				"Generated Roles, Survival, Resources, "
				+ "and Tribe surfaces."
			),
			"providers": [
				_mod_menu_provider()
			]
		}
	}


static func _activities_provider() -> Dictionary:
	var rows: Array = caveman_activity_contracts()
	var routes: Dictionary = {}

	for raw_row in rows:
		if typeof(
			raw_row
		) != TYPE_DICTIONARY:
			continue

		var row: Dictionary = raw_row as Dictionary
		var row_id: String = str(
			row.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if row_id != "":
			routes [row_id] = _activity_route()

	return {
		"provider_id": "caveman.activities",
		"provider_type": "activities",
		"target_id": "activities_hub",
		"api_version": 1,
		"priority": 900,
		"conflict_policy": "replace",
		"allow_override": true,
		"replace_base_catalog": true,
		"rows": rows,
		"intent_routes": routes,
		"allowed_methods": [
			"perform_activity"
		]
	}
static func caveman_activity_contracts() -> Array:
	return [
		_activity_row(
			"listen_to_fire",
			"Listen to the Fire",
			"cave_baby",
			"Watch firelight move across the cave wall.",
			0,
			4
		),
		_activity_row(
			"reach_for_family",
			"Reach for a Familiar Face",
			"cave_baby",
			"Reach toward a parent, grandparent, or caregiver.",
			0,
			3
		),
		_activity_row(
			"crawl_across_hides",
			"Crawl Across the Hides",
			"cave_baby",
			"Explore the family's sleeping hides.",
			0,
			3
		),
		_activity_row(
			"babble_at_tribe",
			"Babble at the Tribe",
			"cave_baby",
			"Call out until the cave answers with familiar voices.",
			0,
			4
		),
		_activity_row(
			"nap_by_fire",
			"Nap by the Fire",
			"cave_baby",
			"Sleep near the tribe's protected warmth.",
			0,
			5
		),
		_activity_row(
			"play_with_smooth_stone",
			"Play with a Smooth Stone",
			"cave_baby",
			"Turn a safe river stone over in your hands.",
			1,
			6
		),
		_activity_row(
			"snuggle_parent",
			"Snuggle a Parent",
			"tribe_bonds",
			"Seek warmth and safety from a living parent.",
			0,
			130,
			{
				"relationship_kind": "parent"
			}
		),
		_activity_row(
			"listen_to_grandparent_story",
			"Listen to a Grandparent Story",
			"tribe_bonds",
			"Hear the tribe's memory from a living grandparent.",
			1,
			130,
			{
				"relationship_kind": "grandparent"
			}
		),
		_activity_row(
			"follow_gatherer",
			"Follow a Gatherer",
			"young_survival",
			"Learn where roots, berries, and safe plants are found.",
			3,
			11
		),
		_activity_row(
			"gather_kindling",
			"Gather Kindling",
			"young_survival",
			"Carry small dry branches back to the cave.",
			4,
			130,
			{
				"survival_age_gate": true
			}
		),
		_activity_row(
			"learn_animal_tracks",
			"Learn Animal Tracks",
			"young_survival",
			"Study spoor, prints, broken grass, and warning signs.",
			5,
			130,
			{
				"survival_age_gate": true
			}
		),
		_activity_row(
			"gather_roots_berries",
			"Gather Roots and Berries",
			"tribe_survival",
			"Search nearby territory for edible plants.",
			5,
			130,
			{
				"survival_age_gate": true
			}
		),
		_activity_row(
			"craft_stone_tools",
			"Craft Stone Tools",
			"tribe_survival",
			"Turn stone, wood, and bone into survival tools.",
			8,
			130,
			{
				"survival_age_gate": true
			}
		),
		_activity_row(
			"start_fire",
			"Start Fire",
			"tribe_survival",
			"Build and maintain the tribe's protective fire.",
			10,
			130,
			{
				"survival_age_gate": true
			}
		),
		_activity_row(
			"explore_territory",
			"Explore Territory",
			"tribe_survival",
			"Reveal caves, water, resources, and threats.",
			8,
			130,
			{
				"survival_age_gate": true
			}
		),
		_activity_row(
			"hunt_herd",
			"Hunt an Elk Herd",
			"tribe_survival",
			"Track prey and return with meat, hide, bone, and marrow.",
			12,
			130,
			{
				"survival_age_gate": true
			}
		),
		_activity_row(
			"share_food_with_tribe",
			"Share Food with the Tribe",
			"tribe_bonds",
			"Move food from personal inventory into the communal meal.",
			0,
			130
		),
		_activity_row(
			"make_wild_cave_love",
			"Make Wild Cave Love",
			"tribe_bonds",
			"Spend private time with your current adult partner.",
			18,
			130,
			{
				"requires_current_partner": true,
				"adult_partner_only": true
			}
		),
		_activity_row(
			"try_for_cave_baby",
			"Try for a Cave Baby",
			"tribe_bonds",
			"Attempt to create a child with your current adult partner.",
			18,
			130,
			{
				"requires_current_partner": true,
				"adult_partner_only": true
			}
		),
		_activity_row(
			"toggle_survival_age_unlock",
			"Unlock Survival Activities for Every Age",
			"runtime_service",
			"Switch between normal age gates and unrestricted survival play.",
			0,
			130,
			{
				"hidden_from_activities": true
			}
		),
		_activity_row(
			"give_resource_item",
			"Give Resource to Controlled Actor",
			"runtime_service",
			"Move one projected resource into personal inventory.",
			0,
			130,
			{
				"hidden_from_activities": true
			}
		),
		_activity_row(
			"cook_caveman_food",
			"Cook Caveman Food",
			"runtime_service",
			"Cook a meat item over the tribe's fire.",
			5,
			130,
			{
				"hidden_from_activities": true
			}
		),
		_activity_row(
			"share_food_with_person",
			"Share Caveman Food with Person",
			"runtime_service",
			"Give or share a food item with a selected tribe member.",
			0,
			130,
			{
				"hidden_from_activities": true
			}
		)
	]


static func _activity_row(
	row_id: String,
	label: String,
	category_id: String,
	description: String,
	minimum_age: int,
	maximum_age: int,
	extra: Dictionary = {}
) -> Dictionary:
	var row: Dictionary = {
		"id": row_id,
		"provider_action_id": row_id,
		"label": label,
		"title": label,
		"category_id": category_id,
		"description": description,
		"enabled": true,
		"eligibility": {
			"minimum_age": minimum_age,
			"maximum_age": maximum_age
		}
	}

	for raw_key in extra.keys():
		row [raw_key] = extra.get(
			raw_key
		)

	return row


static func _activity_route() -> Dictionary:
	return {
		"route_kind": "bundle_service_method",
		"bundle_id": BUNDLE_ID,
		"service_id": "caveman_reality",
		"method": "perform_activity"
	}





static func _roles_provider() -> Dictionary:
	return {
		"provider_id": "caveman.roles",
		"provider_type": "roles",
		"target_id": "primary_social_roles",
		"api_version": 1,
		"priority": 900,
		"conflict_policy": "replace",
		"allow_override": true,
		"rows": [
			_role(
				"infant",
				"Infant",
				0,
				2,
				0,
				false
			),
			_role(
				"child",
				"Tribe Child",
				3,
				11,
				0,
				false
			),
			_role(
				"hunter",
				"Hunter",
				12,
				130,
				0,
				false
			),
			_role(
				"gatherer",
				"Gatherer",
				8,
				130,
				0,
				false
			),
			_role(
				"tool_maker",
				"Tool Maker",
				12,
				130,
				0,
				false
			),
			_role(
				"fire_keeper",
				"Fire Keeper",
				10,
				130,
				0,
				false
			),
			_role(
				"scout",
				"Scout",
				12,
				130,
				0,
				false
			),
			_role(
				"shaman",
				"Shaman",
				18,
				130,
				2,
				true
			),
			_role(
				"elder",
				"Elder",
				45,
				130,
				4,
				true
			),
			{
				"id": "birth_giver",
				"label": "Birth Giver",
				"description": (
					"An adult reproductive and caregiving "
					+ "role. It is not a leadership rank "
					+ "and is never assigned to children."
				),
				"minimum_age": 16,
				"maximum_age": 55,
				"maximum_per_tribe": 0,
				"sex_requirement": "female",
				"assignment_mode": (
					"eligible_adult_reproductive_role"
				),
				"exclusive": false
			},
			{
				"id": "tribe_leader",
				"label": "Tribe Leader",
				"description": (
					"The tribe's singular authority, "
					+ "earned through survival contribution, "
					+ "legitimacy, and age."
				),
				"minimum_age": 18,
				"maximum_age": 130,
				"maximum_per_tribe": 1,
				"assignment_mode": (
					"highest_survival_contribution"
				),
				"minimum_survival_contribution": 60,
				"exclusive": true
			}
		],
		"intent_routes": {
			"assign_role": {
				"route_kind": "bundle_service_method",
				"bundle_id": BUNDLE_ID,
				"service_id": "caveman_reality",
				"method": "assign_role"
			}
		},
		"allowed_methods": [
			"assign_role"
		]
	}


static func _role(
	role_id: String,
	label: String,
	minimum_age: int,
	maximum_age: int,
	maximum_per_tribe: int,
	leadership_role: bool
) -> Dictionary:
	return {
		"id": role_id,
		"label": label,
		"minimum_age": minimum_age,
		"maximum_age": maximum_age,
		"maximum_per_tribe": maximum_per_tribe,
		"leadership_role": leadership_role,
		"assignment_mode": (
			"contribution_and_eligibility"
			if minimum_age >= 8
			else "age_band"
		),
		"exclusive": leadership_role
	}


static func _system_policy_provider() -> Dictionary:
	return {
		"provider_id": "caveman.system_policies",
		"provider_type": "system_policies",
		"target_id": "institution_availability",
		"api_version": 1,
		"priority": 900,
		"conflict_policy": "replace",
		"allow_override": true,
		"rows": [
			{
				"id": "career",
				"system_id": "career",
				"mode": "roles_only",
				"visible": false,
				"replacement_system_id": "roles",
				"reason": (
					"Formal careers do not exist. "
					+ "Contribution roles govern identity."
				)
			},
			{
				"id": "markets",
				"system_id": "markets",
				"mode": "tribal_stockpile",
				"visible": false,
				"replacement_system_id": "survival_resources"
			},
			{
				"id": "money",
				"system_id": "money",
				"mode": "resource_ledger",
				"visible": false,
				"replacement_system_id": "survival_resources"
			},
			{
				"id": "property",
				"system_id": "property",
				"mode": "cave_shelter_projection",
				"visible": true,
				"replacement_system_id": "cave_shelters",
			},
			{
				"id": "world_browser",
				"system_id": "world_browser",
				"mode": "tribes_and_clans",
				"visible": true,
				"replacement_system_id": "tribe_browser"
			},
			{
				"id": "royalty",
				"system_id": "royalty",
				"mode": "tribal_governance",
				"visible": true,
				"replacement_system_id": "tribe_governance"
			}
		]
	}


static func _governance_provider() -> Dictionary:
	return {
		"provider_id": "caveman.governance",
		"provider_type": "governance",
		"target_id": "primary_government",
		"api_version": 1,
		"priority": 900,
		"conflict_policy": "replace",
		"allow_override": true,
		"rows": [
			{
				"id": "tribal_contribution_governance",
				"government_type": (
					"tribal_contribution"
				),
				"display_name": "Tribe Governance",
				"leader_title": "Tribe Leader",
				"leader_role_id": "tribe_leader",
				"maximum_leaders": 1,
				"authority_basis": [
					"survival_contribution",
					"tribal_legitimacy",
					"elder_support",
					"physical_capability"
				],
				"succession_mode": (
					"contribution_consensus"
				),
				"council_role_ids": [
					"elder",
					"shaman"
				],
			}
		]
	}


static func _economy_provider() -> Dictionary:
	return {
		"provider_id": "caveman.economy",
		"provider_type": "economy_modes",
		"target_id": "primary_economy",
		"api_version": 1,
		"priority": 900,
		"conflict_policy": "replace",
		"allow_override": true,
		"rows": [
			{
				"id": "tribal_resource_survival",
				"display_name": "Survival Resources",
				"trade_mode": "barter_and_shared_stockpile",
				"resources": [
					_resource("elk_meat", "Elk Meat", "🫎", 10, true, true),
					_resource("rabbit_meat", "Rabbit Meat", "🐇", 8, true, true),
					_resource("bush_berries", "Bush Berries", "🫐", 15, true, false),
					_resource("wild_roots", "Wild Roots", "🌿", 12, true, false),
					_resource("marrow", "Bone Marrow", "🦴", 5, true, false),
					_resource("smoked_meat", "Smoked Meat", "🔥", 4, true, false),
					_resource("wood", "Wood", "🪵", 25, false, false),
					_resource("stone", "Stone", "🪨", 20, false, false),
					_resource("hide", "Hide", "◈", 8, false, false),
					_resource("bone", "Bone", "🦴", 6, false, false),
					_resource("fire", "Fire", "🔥", 1, false, false)
				]
			}
		]
	}


static func _resource(
	resource_id: String,
	label: String,
	icon: String,
	starting_amount: int,
	is_food: bool = false,
	requires_cooking: bool = false
) -> Dictionary:
	return {
		"id": resource_id,
		"label": label,
		"icon": icon,
		"starting_amount": starting_amount,
		"minimum": 0,
		"is_food": is_food,
		"requires_cooking": requires_cooking
	}


static func _fauna_provider() -> Dictionary:
	return {
		"provider_id": "caveman.fauna",
		"provider_type": "fauna",
		"target_id": "world_animals",
		"api_version": 1,
		"priority": 900,
		"conflict_policy": "namespace",
		"rows": [
			{
				"id": "dinosaur",
				"label": "Dinosaur",
				"species_family": "dinosaur",
				"danger": 92,
				"rarity": "rare",
				"habitats": [
					"forest",
					"swamp",
					"open_plain"
				]
			},
			{
				"id": "sabre_tooth_tiger",
				"label": "Sabre-Tooth Tiger",
				"species_family": (
					"prehistoric_feline"
				),
				"danger": 84,
				"rarity": "uncommon",
				"habitats": [
					"grassland",
					"cave",
					"forest"
				]
			},
			{
				"id": "short_faced_bear",
				"label": "Short-Faced Bear",
				"species_family": (
					"prehistoric_bear"
				),
				"danger": 88,
				"rarity": "uncommon",
				"habitats": [
					"forest",
					"mountain",
					"cave"
				]
			}
		]
	}


static func _era_overlay_provider() -> Dictionary:
	return {
		"provider_id": "caveman.era_overlay",
		"provider_type": "era_overlays",
		"target_id": "effective_era",
		"api_version": 1,
		"priority": 900,
		"conflict_policy": "replace",
		"allow_override": true,
		"rows": [
			{
				"id": "caveman_survival_overlay",
				"experience_id": EXPERIENCE_ID,
				"name": "Caveman Survival Reality",
				"display_name": "Caveman Era",
				"theme_key": "prehistoric",
				"job_pool": [],
				"part_time_job_pool": [],
				"famous_career_tracks": [],
				"career_mode": "roles_only",
				"economy_mode": "resource_survival",
				"government_mode": (
					"tribal_contribution"
				),
				"rights": {
					"banking": false,
					"survival_contribution": true
				},
			}
		]
	}


static func _world_taxonomy_provider() -> Dictionary:
	return {
		"provider_id": "caveman.world_taxonomy",
		"provider_type": "world_taxonomy",
		"target_id": "main_world_labels",
		"api_version": 1,
		"priority": 900,
		"conflict_policy": "replace",
		"allow_override": true,
		"rows": [
			{
				"id": "caveman_world_taxonomy",
				"labels": {
					"world": "TRIBES",
					"other_countries": "OTHER TRIBES",
					"other_realms": "OTHER CLANS",
					"country": "TRIBE",
					"city": "TERRITORY",
					"government": "TRIBAL AUTHORITY",
					"career": "ROLES",
					"money": "RESOURCES"
				}
			}
		]
	}


static func _presentation_provider() -> Dictionary:
	return {
		"provider_id": "caveman.presentation",
		"provider_type": "presentation",
		"target_id": "main_scene",
		"api_version": 1,
		"priority": 900,
		"conflict_policy": "replace",
		"allow_override": true,
		"rows": [
			{
				"id": (
					"caveman_main_scene_presentation"
				),
				"theme_key": "prehistoric",
				"surface_title": "CAVEMAN REALITY",
				"navigation_labels": {


					"world": "WORLD",
					"life": "LIFE",
					"school": "LEARNING",
					"activities": "SURVIVAL",
					"relationships": "TRIBE BONDS",
					"career": "ROLES",
					"mods": "MOD HUB",
					"age_up": "AGE UP"
				},
				"navigation_visibility": {
					"world": true,
					"life": true,
					"school": true,
					"activities": true,
					"relationships": true,
					"career": true,
					"mods": true,
					"age_up": true
				},
				"palette": {
					"background": "#17100C",
					"panel": "#2B1B12",
					"panel_alt": "#3A2618",
					"border": "#A9773F",
					"accent": "#E28B32",
					"accent_secondary": "#D8B36A",
					"text": "#F4DFC0",
					"text_muted": "#C7A77D",
					"danger": "#B84D34",
					"success": "#809B4F"
				},
				"material_language": [
					"stone",
					"charcoal",
					"hide",
					"firelight"
				]
			}
		]
	}

static func _birth_narrative_provider() -> Dictionary:
	return {
		"provider_id": "caveman.birth_narrative",
		"provider_type": "birth_narratives",
		"target_id": "life_diary_birth_intro",
		"api_version": 1,
		"priority": 900,
		"conflict_policy": "replace",
		"allow_override": true,
		"rows": [
			{
				"id": "caveman_newborn_intro",
				"minimum_age": 0,
				"maximum_age": 0,
				"replace_birth_body": true,
				"headline": (
					"A new life entered the tribe."
				),
				"lines": [
					(
						"Firelight moved across the cave "
						+ "walls as I drew my first breath."
					),
					(
						"The tribe gathered close, measuring "
						+ "my arrival against hunger, "
						+ "weather, and hope."
					),
					(
						"I was born into a world of stone, "
						+ "hide, bone, fire, and living memory."
					)
				]
			}
		]
	}


static func _mod_menu_provider() -> Dictionary:
	return {
		"provider_id": "caveman.bundle_menu",
		"provider_type": "mod_menus",
		"target_id": BUNDLE_ID,
		"api_version": 1,
		"priority": 900,
		"conflict_policy": "replace",
		"allow_override": true,
		"rows": [
			_bundle_menu_contract()
		]
	}


static func _bundle_menu_contract() -> Dictionary:
	var presentation_rows: Array = _array(
		_presentation_provider().get(
			"rows",
			[]
		)
	)
	var presentation: Dictionary = {}

	if not presentation_rows.is_empty():
		presentation = _dict(
			presentation_rows [0]
		)

	return {
		"schema": "eralife.bundle_menu_contract",
		"version": 1,
		"bundle_id": BUNDLE_ID,
		"title": "🪨 CAVEMAN MENU",
		"subtitle": (
			"The live control surface for this "
			+ "installed reality."
		),
		"default_section": "roles",
		"section_tabs": [
			{
				"id": "roles",
				"label": "ROLES",
				"icon": "🪨"
			},
			{
				"id": "survival",
				"label": "SURVIVAL STATUS",
				"icon": "🔥"
			},
			{
				"id": "resources",
				"label": "RESOURCES",
				"icon": "🦴"
			},
				{
				"id": "settings",
				"label": "REALITY CONTROLS",
				"icon": "⚙"
			},
			{
				"id": "tribe",
				"label": "TRIBE",
				"icon": "🏕️"
			}
		],
		"presentation": presentation
	}


static func _experience_contract() -> Dictionary:
	return {
		"schema": (
			"eralife.installable_reality_experience"
		),
		"version": 1,
		"experience_id": EXPERIENCE_ID,
		"bundle_id": BUNDLE_ID,
		"root_mod_id": ROOT_MOD_ID,
		"display_name": (
			"Caveman Survival Reality"
		),
		"effective_era_label": "Caveman Era",
		"identity_preservation": "required",
		"chronology_preservation": "required",
		"base_world_preservation": "required",
		"career_policy": "roles_only",
		"economy_policy": "resource_survival",
		"governance_policy": (
			"tribal_contribution"
		),
		"world_taxonomy_policy": (
			"tribes_and_clans"
		),
		"runtime_service_id": "caveman_reality",
		"disable_result": (
			"base_reality_restored"
		)
	}


static func _dict(
	value: Variant
) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return (
			value as Dictionary
		).duplicate(true)

	return {}


static func _array(
	value: Variant
) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return (
			value as Array
		).duplicate(true)

	return []