extends GutTest
## Salvar configs: o .tres gravado contém TODOS os valores e recarrega idêntico.

const PATH := "user://test_movement_config.tres"


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_save_full_writes_every_property_and_round_trips() -> void:
	var cfg := MovementConfig.new()
	cfg.walk_speed = 7.25
	cfg.bunny_hop_window_ticks = 5
	cfg.dodge_neutral_backward = false
	assert_eq(ConfigIO.save_full(cfg, PATH), OK)
	var text := FileAccess.get_file_as_string(PATH)
	var properties := ConfigIO.get_editable_properties(cfg)
	assert_gt(properties.size(), 50)
	for property in properties:
		assert_string_contains(text, "\n%s = " % property.name)
	var loaded := ResourceLoader.load(PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as MovementConfig
	assert_not_null(loaded)
	for property in properties:
		assert_eq(loaded.get(property.name), cfg.get(property.name), property.name)


func test_project_tres_files_load_with_expected_defaults() -> void:
	var cfg := load("res://config/movement_config.tres") as MovementConfig
	assert_eq(cfg.walk_speed, 6.0)
	assert_eq(cfg.sprint_speed, 10.0)
	assert_eq(cfg.jump_height, 2.2)
	assert_eq(cfg.dodge_sp_cost, 20.0)
	assert_eq(cfg.dodge_invulnerability, 0.15)
	assert_eq(cfg.wall_jump_sp_cost, 18.0)
	assert_eq(cfg.wall_jump_camera_weight, 0.4)
	assert_eq(cfg.bunny_hop_window_ticks, 3)
	assert_not_null(load("res://config/camera_config.tres") as CameraConfig)
	assert_not_null(load("res://config/feedback_config.tres") as FeedbackConfig)


func test_copy_properties_restores_defaults() -> void:
	var cfg := MovementConfig.new()
	cfg.walk_speed = 99.0
	ConfigIO.copy_properties(MovementConfig.new(), cfg)
	assert_eq(cfg.walk_speed, 6.0)
