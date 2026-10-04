extends GutTest
## Menu F2: gera um controle para cada número/bool do MovementConfig e aplica ao vivo.

const COURSE: PackedScene = preload("res://scenes/arenas/TrainingCourse.tscn")

var course: Node3D
var player: Player
var menu: CanvasLayer


func before_each() -> void:
	course = COURSE.instantiate() as Node3D
	player = course.get_node("Player") as Player
	player.external_control = true
	player.config = player.config.duplicate() as MovementConfig
	player.camera_config = player.camera_config.duplicate() as CameraConfig
	add_child_autofree(course)
	menu = course.get_node("DebugMenu") as CanvasLayer
	await wait_physics_frames(2)


func test_opening_menu_builds_controls_for_all_config_values() -> void:
	menu.set_open(true)
	assert_true(menu.visible)
	assert_false(player.input_reader.enabled, "jogador não se move com o menu aberto")
	var controls: Dictionary = menu._controls[player.config]
	for property in ConfigIO.get_editable_properties(player.config):
		assert_true(controls.has(property.name), "controle para %s" % property.name)
	assert_true(menu._controls.has(player.camera_config))
	menu.set_open(false)
	assert_true(player.input_reader.enabled)


func test_editing_a_control_changes_config_live() -> void:
	menu.set_open(true)
	var spin: SpinBox = menu._controls[player.config]["walk_speed"][1]
	spin.value = 8.5
	assert_eq(player.config.walk_speed, 8.5)
	var slider: HSlider = menu._controls[player.config]["walk_speed"][0]
	assert_eq(slider.value, 8.5, "slider acompanha a caixa numérica")
	var radius_spin: SpinBox = menu._controls[player.config]["body_radius"][1]
	radius_spin.value = 0.5
	assert_eq((player.body_shape.shape as CapsuleShape3D).radius, 0.5, "cápsula atualizada na hora")


func test_defaults_button_restores_values() -> void:
	menu.set_open(true)
	player.config.walk_speed = 12.0
	menu._defaults()
	assert_eq(player.config.walk_speed, 6.0)
	var spin: SpinBox = menu._controls[player.config]["walk_speed"][1]
	assert_eq(spin.value, 6.0)
