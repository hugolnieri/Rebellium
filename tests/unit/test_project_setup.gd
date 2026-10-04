extends GutTest
## Garante que a configuração base do projeto não regrida.

const REQUIRED_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"jump", &"dodge", &"shoulder_swap", &"release_mouse",
	&"toggle_debug_hud", &"toggle_debug_menu", &"reset_course",
	&"weapon_slot_1", &"weapon_slot_2",
]


func test_input_actions_exist_and_have_events() -> void:
	for action in REQUIRED_ACTIONS:
		assert_true(InputMap.has_action(action), "Ação ausente: %s" % action)
		if InputMap.has_action(action):
			assert_gt(InputMap.action_get_events(action).size(), 0, "Ação sem tecla: %s" % action)


func test_physics_runs_at_60_fixed_ticks() -> void:
	assert_eq(ProjectSettings.get_setting("physics/common/physics_ticks_per_second"), 60)
	assert_eq(Engine.physics_ticks_per_second, 60)


func test_physics_engine_is_jolt() -> void:
	assert_eq(ProjectSettings.get_setting("physics/3d/physics_engine"), "Jolt Physics")


func test_game_events_autoload_present() -> void:
	var events := get_tree().root.get_node_or_null("GameEvents")
	assert_not_null(events)
	assert_true(events.has_signal("technique_executed"))


func test_arena_scene_loads() -> void:
	var scene: PackedScene = load("res://scenes/arenas/Arena.tscn")
	assert_not_null(scene)
	var arena := scene.instantiate()
	add_child_autofree(arena)
	assert_gt(arena.get_node("Geometry").get_child_count(), 5)
