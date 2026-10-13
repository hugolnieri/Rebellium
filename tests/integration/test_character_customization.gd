extends GutTest
## Menu de personagem (F4): troca de modelo (herói ↔ personagem do VRoid) com as mesmas animações, mesma altura,
## arma na mão, e as cores do `CharacterLook` chegando aos materiais.

const Driver = preload("res://tests/helpers/player_driver.gd")
const VROID := "res://assets/character/models/vroid_casual.glb"
const FWD := Vector2(0, 1)

var d: Driver


func before_each() -> void:
	d = Driver.new()
	d.setup(self, Vector3(0, 0.05, 0))
	d.add_block(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	await d.ready_physics(self)
	d.step(10)


func _model() -> CharacterModel:
	return d.player.model


func _skeleton() -> Skeleton3D:
	return _model()._skeleton


func _look(path: String = "") -> CharacterLook:
	var look := CharacterLook.new()
	look.model_path = path
	return look


func _animate(frames: int, move: Vector2 = Vector2.ZERO) -> void:
	for i in frames:
		d.step(1, move)
		_model()._process(1.0 / 60.0)


func _head_height() -> float:
	var skeleton := _skeleton()
	var head := skeleton.find_bone(CharacterModel.HEAD_BONE)
	return (skeleton.global_transform * skeleton.get_bone_global_rest(head)).origin.y - d.player.global_position.y


func test_vroid_models_are_listed_with_the_hero() -> void:
	var models := CharacterLook.available_models()
	assert_eq(models.values()[0], CharacterLook.HERO_MODEL, "o herói vem primeiro")
	assert_has(models.values(), VROID, "personagem do VRoid importado aparece no menu")


func test_switching_to_a_vroid_model_keeps_the_same_height() -> void:
	var hero_head := _head_height()
	_model().apply_look(_look(VROID))
	await get_tree().process_frame
	assert_eq(_model().get_model_path(), VROID)
	assert_almost_eq(_head_height(), hero_head, 0.02, "todo modelo fica com a altura do herói")


func test_vroid_model_plays_the_hero_clips_by_bone_name() -> void:
	_model().apply_look(_look(VROID))
	await get_tree().process_frame
	_animate(30, FWD)
	var skeleton := _skeleton()
	var thigh_l := skeleton.find_bone("J_Bip_L_UpperLeg")
	var thigh_r := skeleton.find_bone("J_Bip_R_UpperLeg")
	var widest := 0.0
	for i in 40:
		_animate(1, FWD)
		widest = maxf(widest, skeleton.get_bone_pose_rotation(thigh_l).angle_to(skeleton.get_bone_pose_rotation(thigh_r)))
	assert_gt(widest, 0.4, "o modelo do VRoid corre com a passada do herói")


func test_weapon_moves_to_the_new_model_hand() -> void:
	_model().apply_look(_look(VROID))
	_animate(10)
	await get_tree().process_frame
	await get_tree().process_frame
	var skeleton := _skeleton()
	var wrist := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone(CharacterModel.RIGHT_HAND_BONE))
	assert_not_null(_model().weapon_visual)
	assert_true(is_instance_valid(_model().weapon_visual))
	assert_lt(_model().weapon_visual.global_position.distance_to(wrist.origin), 0.12, "a arma foi junto para a mão nova")


func test_suit_colors_reach_the_hero_body_material() -> void:
	var look := _look()
	look.suit_color = Color(0.7, 0.05, 0.05)
	look.hair_color = Color(0.3, 0.8, 1.0)
	_model().apply_look(look)
	var body: ShaderMaterial = _model()._body_materials[0]
	assert_true(body.get_shader_parameter(&"use_recolor"), "o herói recolore o traje pela máscara")
	assert_eq(body.get_shader_parameter(&"suit_color"), look.suit_color)
	var hair: ShaderMaterial = _model()._hair_materials[0]
	assert_eq(hair.get_shader_parameter(&"tint"), d.player.feedback_config.hair_color * look.hair_color,
		"tinta do cabelo aplicada")


func test_vroid_model_keeps_its_clothes() -> void:
	_model().apply_look(_look(VROID))
	for material in _model()._body_materials:
		assert_false(material.get_shader_parameter(&"use_recolor"), "o traje do herói não vale no modelo do VRoid")


func test_blinks_on_the_vroid_model() -> void:
	_model().apply_look(_look(VROID))
	assert_gte(_model()._blink_shape, 0, "o importador manteve os nomes das expressões (piscar)")


func test_look_round_trips_through_a_file() -> void:
	var look := _look(VROID)
	look.eye_color = Color(0.2, 0.9, 0.3)
	var path := "user://test_personagem_tmp.tres"
	assert_eq(ConfigIO.save_full(look, path), OK)
	var back := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterLook
	assert_eq(back.model_path, VROID)
	assert_eq(back.eye_color, look.eye_color)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_character_menu_switches_model_and_colors() -> void:
	var menu := get_node("/root/CharacterMenu")
	menu.set_open(true, false)
	assert_true(menu.visible)
	assert_gte(menu.get_model_count(), 2)
	menu.select_model(menu.get_model_count() - 1)
	assert_ne(_model().get_model_path(), CharacterLook.HERO_MODEL, "trocou de modelo pelo menu")
	menu.select_model(0)
	assert_eq(_model().get_model_path(), CharacterLook.HERO_MODEL, "voltou para o herói")
	menu.set_color("suit_color", Color(0.1, 0.5, 0.2))
	assert_eq(_model()._body_materials[0].get_shader_parameter(&"suit_color"), Color(0.1, 0.5, 0.2))
	menu.set_open(false, false)
	assert_false(menu.visible)
	assert_true(d.player.input_reader.enabled, "o controle volta ao fechar")
