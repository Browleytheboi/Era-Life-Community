extends RefCounted
class_name MiniGameEcosystemContractPack

const CONTRACT_SCHEMA:= "eralife.minigame_ecosystem_contract_pack"
const CONTRACT_VERSION:= 1
const ROOT_PATH:= "res://MiniGameEcosystem"


static func contract() -> Dictionary:
	return {
		"schema": "eralife.game_state_contract",
		"version": 1,
		"state_id": "eralife_default_world",
		"name": "EraLife MiniGame Ecosystem",
		"description":
		(
			"Persistent contract-hosted minigame realities, multiplayer, "
			+ "scoreboards, achievements, replays, hosts, and Flash-like providers."
		),
		"conflict_policy": "merge",
		"engines":
		[
			_engine(
				"mini_game_runtime_engine",
				"MiniGameRuntimeEngine",
				"MiniGameRuntimeEngine.gd",
				3320,
				true,
				[
					"create_session",
					"session",
					"commit_session_state",
					"complete_session",
					"export_state",
					"import_state"
				]
			),
			_engine(
				"scoreboard_contract_engine",
				"ScoreboardContractEngine",
				"ScoreboardContractEngine.gd",
				3321,
				true,
				[
					"record_session_result",
					"emit_scoreboard_contract",
					"export_state",
					"import_state"
				]
			),
			_engine(
				"achievement_contract_engine",
				"AchievementContractEngine",
				"AchievementContractEngine.gd",
				3322,
				true,
				[
					"register_achievement_definitions",
					"evaluate_session",
					"emit_achievement_contract",
					"export_state",
					"import_state"
				]
			),
			_engine(
				"replay_contract_engine",
				"ReplayContractEngine",
				"ReplayContractEngine.gd",
				3323,
				true,
				[
					"begin_replay",
					"append_event",
					"finalize_replay",
					"emit_replay_contract",
					"export_state",
					"import_state"
				]
			),
			_engine(
				"multiplayer_contract_engine",
				"MultiplayerContractEngine",
				"MultiplayerContractEngine.gd",
				3324,
				true,
				[
					"resolve_intent",
					"participant_for_actor",
					"create_relationship_invitation",
					"create_eraccount_invitation",
					"accept_invitation",
					"emit_multiplayer_contract",
					"export_state",
					"import_state"
				]
			),
			_engine(
				"adobe_flash_contract_engine",
				"AdobeFlashContractEngine",
				"AdobeFlashContractEngine.gd",
				3325,
				true,
				[
					"bootstrap_default_contracts",
					"register_flash_reality_provider",
					"emit_flash_reality_contract",
					"emit_flash_world_adapter",
					"emit_flash_ui_projection",
					"export_state",
					"import_state"
				]
			),
			_engine(
				"mini_game_host_adapter_engine",
				"MiniGameHostAdapterEngine",
				"MiniGameHostAdapterEngine.gd",
				3326,
				true,
				[
					"enrich_property_space_contract",
					"resolve_host_contract",
					"emit_host_catalog",
					"export_state",
					"import_state"
				]
			),
			_engine(
				"mini_game_contract_engine",
				"MiniGameContractEngine",
				"MiniGameContractEngine.gd",
				3327,
				true,
				[
					"bootstrap_default_contracts",
					"register_provider",
					"resolve_intent",
					"emit_hub_contract",
					"emit_session_contract",
					"export_state",
					"import_state"
				]
			),
			_engine(
				"mini_game_hub_contract_engine",
				"MiniGameHubContractEngine",
				"MiniGameHubContractEngine.gd",
				3328,
				true,
				[
					"resolve_intent",
					"emit_observable_contract",
					"emit_hub_contract",
					"export_state",
					"import_state"
				]
			)
		],
		"metadata":
		{
			"architecture": "Reality -> Runtime -> Contract -> Provider -> Adapter -> Projection",
			"ui_is_renderer_only": true,
		}
	}


static func _engine(
	engine_id: String,
	class_name_value: String,
	file_name: String,
	boot_order: int,
	auto_save_slice: bool,
	required_methods: Array
) -> Dictionary:
	return {
		"id": engine_id,
		"runtime_property": engine_id,
		"class": class_name_value,
		"script_path": "%s/%s" % [ROOT_PATH, file_name],
		"boot_phase": "domain_extensions",
		"boot_order": boot_order,
		"required": true,
		"enabled": true,
		"allow_contract_instantiation": true,
		"instantiation_args": ["game_state"],
		"missing_engine_policy": "recover",
		"auto_save_slice": auto_save_slice,
		"snapshot_export_method": "export_state",
		"snapshot_import_method": "import_state",
		"required_methods": required_methods.duplicate(true),
		"metadata": {
			"ecosystem": "minigames",
			"ui_is_renderer_only": true,
		}
	}