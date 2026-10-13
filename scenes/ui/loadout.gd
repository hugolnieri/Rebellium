extends Control
## Preparação da partida: aparência e arma inicial, depois escolha de um mapa existente.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const ACCENT: Color = Color(0.12, 0.83, 0.94)
const MUTED: Color = Color(0.56, 0.62, 0.72)
const COLORS: Array[Array] = [
	["hair_color", "Cabelo", false], ["skin_color", "Pele", false],
	["eye_color", "Olhos", false], ["suit_color", "Traje", true],
	["seam_color", "Costuras", true], ["emblem_color", "Emblema", true],
]
const MAP_NAMES: Array[String] = ["Arena Celeste", "Arena de Combate", "Percurso de Treino", "Arena Livre"]
const MAP_DETAILS: Array[String] = [
	"Plataforma flutuante • caçador no centro", "Duelo e treino de golpes",
	"Wall jumps, obstáculos e cronômetro", "Espaço livre para praticar",
]

var look: CharacterLook
var loadout: LoadoutConfig
var _models: Dictionary = {}
var _model_list: OptionButton
var _weapon_list: OptionButton
var _pickers: Dictionary = {}
var _hero_rows: Array[Control] = []
var _preview_player: Player
var _status: Label
var _content: HBoxContainer
var _stage: int = 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	look = CharacterLook.load_user()
	loadout = LoadoutConfig.load_user()
	_build_shell()
	if SceneCycler.open_maps_on_ready:
		SceneCycler.open_maps_on_ready = false
		_show_maps()
	else:
		_show_loadout()


func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color(0.025, 0.038, 0.07)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 20)
	margin.add_child(root)
	var brand := _label("REBELLIUM  /  PREPARAÇÃO", 16, MUTED)
	root.add_child(brand)
	_content = HBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 24)
	root.add_child(_content)
	_status = _label("", 15, MUTED)
	root.add_child(_status)


func _clear_content() -> void:
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_preview_player = null
	_pickers.clear()
	_hero_rows.clear()


func _show_loadout() -> void:
	_stage = 0
	_clear_content()
	var preview_panel := _panel()
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(preview_panel)
	var preview_column := VBoxContainer.new()
	preview_panel.add_child(preview_column)
	preview_column.add_child(_label("SEU PERSONAGEM", 26, Color.WHITE))
	preview_column.add_child(_label("Visualização da aparência escolhida", 14, MUTED))
	var preview := SubViewportContainer.new()
	preview.stretch = true
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(300, 330)
	preview_column.add_child(preview)
	if DisplayServer.get_name() == "headless":
		preview_column.add_child(_label("Prévia 3D disponível no jogo.", 14, MUTED))
	else:
		_build_preview(preview)
	var settings := _panel()
	settings.custom_minimum_size.x = 420
	_content.add_child(settings)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	settings.add_child(column)
	column.add_child(_label("LOADOUT", 30, Color.WHITE))
	column.add_child(_label("01  /  Personagem e arma", 15, ACCENT))
	column.add_child(_label("Modelo", 16, Color.WHITE))
	_model_list = OptionButton.new()
	_models = CharacterLook.available_models()
	var index: int = 0
	for model_name: String in _models:
		_model_list.add_item(model_name)
		if _models[model_name] == look.resolved_model_path():
			_model_list.select(index)
		index += 1
	_model_list.item_selected.connect(_on_model_selected)
	column.add_child(_model_list)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 180
	column.add_child(scroll)
	var colors := VBoxContainer.new()
	colors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(colors)
	for entry: Array in COLORS:
		var row := HBoxContainer.new()
		var label := _label(entry[1], 15, Color.WHITE)
		label.custom_minimum_size.x = 120
		row.add_child(label)
		var picker := ColorPickerButton.new()
		picker.edit_alpha = false
		picker.color = look.get(entry[0])
		picker.custom_minimum_size = Vector2(120, 32)
		var property: String = entry[0]
		picker.color_changed.connect(func(color: Color) -> void: _set_color(property, color))
		row.add_child(picker)
		colors.add_child(row)
		_pickers[property] = picker
		if entry[2]:
			_hero_rows.append(row)
	column.add_child(_label("Arma inicial", 16, Color.WHITE))
	_weapon_list = OptionButton.new()
	_weapon_list.add_item("Lâmina de Arco")
	_weapon_list.add_item("Presa de Fase")
	_weapon_list.select(clampi(loadout.starting_weapon_slot, 0, 1))
	_weapon_list.item_selected.connect(func(selected: int) -> void: loadout.starting_weapon_slot = selected)
	column.add_child(_weapon_list)
	column.add_child(_label("As duas armas continuam disponíveis com 1 e 2.", 14, MUTED))
	var next := _button("ESCOLHER MAPA  →")
	next.pressed.connect(_save_and_show_maps)
	column.add_child(next)
	_refresh_hero_rows()
	_status.text = "As escolhas são salvas neste computador. F4 também permite mudar a aparência durante a partida."


func _build_preview(container: SubViewportContainer) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 700)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var player := PLAYER_SCENE.instantiate() as Player
	player.external_control = true
	viewport.add_child(player)
	player.remove_from_group(&"local_player")
	player.remove_from_group(&"hittable")
	player.input_reader.enabled = false
	_preview_player = player
	get_tree().create_timer(0.1).timeout.connect(func() -> void:
		if is_instance_valid(player):
			player.model.apply_look(look))
	var gameplay_camera := player.get_node_or_null("PlayerCamera") as Node3D
	if gameplay_camera != null:
		var camera_node := gameplay_camera.find_child("Camera3D", true, false) as Camera3D
		if camera_node != null:
			camera_node.current = false
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.3, -3.7)
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 0.9, 0.0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
	light.light_energy = 2.0
	viewport.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.5, 1.8, -1.8)
	fill.light_energy = 1.2
	viewport.add_child(fill)


func _on_model_selected(selected: int) -> void:
	var path: String = _models.values()[selected]
	look.model_path = "" if path == CharacterLook.HERO_MODEL else path
	if is_instance_valid(_preview_player):
		_preview_player.model.apply_look(look)
	_refresh_hero_rows()


func _set_color(property: String, color: Color) -> void:
	look.set(property, color)
	if is_instance_valid(_preview_player):
		_preview_player.model.apply_look(look)


func _refresh_hero_rows() -> void:
	for row: Control in _hero_rows:
		row.visible = look.is_hero()


func _save_and_show_maps() -> void:
	var look_error := look.save_user()
	var loadout_error := loadout.save_user()
	if look_error != OK or loadout_error != OK:
		_status.text = "Não foi possível salvar o loadout. Verifique o acesso a user://."
		return
	_show_maps()


func _show_maps() -> void:
	_stage = 1
	_clear_content()
	var panel := _panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(_label("ESCOLHA A PARTIDA", 30, Color.WHITE))
	column.add_child(_label("02  /  Selecione um dos mapas disponíveis", 15, ACCENT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	column.add_child(grid)
	for i: int in SceneCycler.SCENES.size():
		var map_card := _button("%02d  %s\n%s\n\nENTRAR NA PARTIDA  →" % [i + 1, MAP_NAMES[i], MAP_DETAILS[i]])
		map_card.custom_minimum_size = Vector2(340, 170)
		map_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		map_card.pressed.connect(_start_match.bind(i))
		grid.add_child(map_card)
	var back := _button("←  VOLTAR AO LOADOUT")
	back.pressed.connect(_show_loadout)
	column.add_child(back)
	_status.text = "F3 durante a partida volta à seleção de mapa."


func _start_match(index: int) -> void:
	get_tree().change_scene_to_file(SceneCycler.SCENES[index])


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.105, 0.96)
	style.border_color = Color(0.15, 0.55, 0.66)
	style.set_border_width_all(1)
	style.set_content_margin_all(22)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 18)
	return button
