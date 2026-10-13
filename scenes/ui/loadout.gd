extends Control
## Tela inicial: loadout vivo, seleção de mapa e entrada na partida.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const BACKDROP: Texture2D = preload("res://assets/ui/main_menu_arena.png")
const MAP_ATLAS: Texture2D = preload("res://assets/ui/map_previews.png")
const CYAN: Color = Color(0.23, 0.91, 1.0)
const WHITE: Color = Color(0.94, 0.97, 1.0)
const MUTED: Color = Color(0.62, 0.69, 0.78)
const DARK: Color = Color(0.025, 0.045, 0.075, 0.94)
const COLORS: Array[Array] = [
	["hair_color", "Cabelo", false], ["skin_color", "Pele", false],
	["eye_color", "Olhos", false], ["suit_color", "Traje", true],
	["seam_color", "Costuras", true], ["emblem_color", "Emblema", true],
]
const MAP_NAMES: Array[String] = ["ARENA CELESTE", "ARENA DE COMBATE", "PERCURSO", "ARENA LIVRE"]
const MAP_DETAILS: Array[String] = [
	"Caçador • arena vertical", "Combate • alvos de treino",
	"Movimento • percurso cronometrado", "Prática • espaço aberto",
]

var look: CharacterLook
var loadout: LoadoutConfig
var _selected_map: int = 0
var _models: Dictionary = {}
var _model_list: OptionButton
var _pickers: Dictionary = {}
var _hero_rows: Array[Control] = []
var _preview_player: Player
var _map_cards: Array[Button] = []
var _weapon_cards: Array[Button] = []
var _customize_overlay: Control
var _status: Label


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	look = CharacterLook.load_user()
	loadout = LoadoutConfig.load_user()
	SceneCycler.open_maps_on_ready = false
	_build_menu()


func _build_menu() -> void:
	var background := TextureRect.new()
	background.texture = BACKDROP
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.045, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_build_header()
	var body := HBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 94.0
	body.offset_bottom = -24.0
	body.offset_left = 34.0
	body.offset_right = -34.0
	body.add_theme_constant_override("separation", 22)
	add_child(body)
	_build_character_side(body)
	_build_match_side(body)


func _build_header() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size.y = 74.0
	bar.add_theme_stylebox_override("panel", _box(Color(0.012, 0.025, 0.047, 0.94), Color(0.11, 0.28, 0.38), 1, 14))
	add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)
	var logo := _label("R E B E L L I U M", 27, WHITE)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(logo)
	var play := _nav("JOGAR", true)
	play.pressed.connect(_close_customize)
	row.add_child(play)
	var equipment := _nav("LOADOUT", false)
	equipment.pressed.connect(_open_customize)
	row.add_child(equipment)
	var training := _nav("TREINO", false)
	training.pressed.connect(func() -> void:
		_close_customize()
		_select_map(2))
	row.add_child(training)
	var gap := Control.new()
	gap.custom_minimum_size.x = 64.0
	row.add_child(gap)
	row.add_child(_label("JOGADOR  /  LOCAL", 14, MUTED))


func _build_character_side(body: HBoxContainer) -> void:
	var side := Control.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.18
	body.add_child(side)
	var preview := SubViewportContainer.new()
	preview.stretch = true
	preview.anchor_right = 1.0
	preview.anchor_bottom = 1.0
	preview.offset_bottom = -188.0
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(preview)
	if DisplayServer.get_name() != "headless":
		_build_preview(preview)
	var strip := PanelContainer.new()
	strip.anchor_top = 1.0
	strip.anchor_right = 1.0
	strip.anchor_bottom = 1.0
	strip.offset_top = -181.0
	strip.add_theme_stylebox_override("panel", _box(Color(0.02, 0.04, 0.07, 0.88), Color(0.1, 0.36, 0.46), 1, 14))
	side.add_child(strip)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	strip.add_child(column)
	column.add_child(_label("LOADOUT EQUIPADO", 14, MUTED))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 9)
	cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(cards)
	for i: int in 2:
		var card := Button.new()
		card.text = "%02d   %s\n%s" % [i + 1, "LÂMINA DE ARCO" if i == 0 else "PRESA DE FASE",
			"ARMA INICIAL" if i == loadout.starting_weapon_slot else "DISPONÍVEL EM PARTIDA"]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_font_size_override("font_size", 15)
		card.pressed.connect(_select_weapon.bind(i))
		cards.add_child(card)
		_weapon_cards.append(card)
	var character := Button.new()
	character.text = "PERSONAGEM\nPersonalizar"
	character.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	character.add_theme_font_size_override("font_size", 15)
	character.pressed.connect(_open_customize)
	cards.add_child(character)
	_refresh_weapon_cards()


func _build_match_side(body: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 510.0
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _box(DARK, Color(0.23, 0.51, 0.61), 1, 22))
	body.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	column.add_child(_label("PREPARE SUA PARTIDA", 28, WHITE))
	column.add_child(_label("ESCOLHA O MAPA", 14, MUTED))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 9)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(list)
	for i: int in SceneCycler.SCENES.size():
		var card := Button.new()
		card.custom_minimum_size.y = 84.0
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_select_map.bind(i))
		list.add_child(card)
		_map_cards.append(card)
		var card_row := HBoxContainer.new()
		card_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_row.offset_left = 8.0
		card_row.offset_right = -8.0
		card_row.offset_top = 6.0
		card_row.offset_bottom = -6.0
		card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_row.add_theme_constant_override("separation", 14)
		card.add_child(card_row)
		var thumb := TextureRect.new()
		var atlas := AtlasTexture.new()
		atlas.atlas = MAP_ATLAS
		atlas.region = Rect2((i % 2) * 836.0, (i / 2) * 470.0, 836.0, 470.0)
		thumb.texture = atlas
		thumb.custom_minimum_size = Vector2(140, 0)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_row.add_child(thumb)
		var info := VBoxContainer.new()
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_row.add_child(info)
		info.add_child(_label(MAP_NAMES[i], 18, WHITE))
		info.add_child(_label(MAP_DETAILS[i], 13, MUTED))
	_refresh_map_cards()
	var enter := Button.new()
	enter.text = "ENTRAR NA PARTIDA   →"
	enter.custom_minimum_size.y = 68.0
	enter.add_theme_font_size_override("font_size", 23)
	enter.add_theme_stylebox_override("normal", _box(Color(0.92, 0.21, 0.08), Color(1.0, 0.43, 0.20), 1, 12))
	enter.add_theme_stylebox_override("hover", _box(Color(1.0, 0.34, 0.10), Color(1.0, 0.63, 0.31), 1, 12))
	enter.add_theme_color_override("font_color", WHITE)
	enter.pressed.connect(_enter_match)
	column.add_child(enter)
	_status = _label("Clique em PERSONAGEM para mudar modelo e cores.  •  F3 retorna aos mapas.", 13, MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)


func _build_preview(container: SubViewportContainer) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 760)
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
	camera.position = Vector3(0.0, 1.3, -2.3)
	viewport.add_child(camera)
	camera.look_at(Vector3(0.0, 1.1, 0.0))
	camera.fov = 55.0
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35.0, 35.0, 0.0)
	light.light_energy = 2.0
	viewport.add_child(light)
	var fill := OmniLight3D.new()
	fill.position = Vector3(1.5, 1.8, -1.8)
	fill.light_energy = 1.2
	viewport.add_child(fill)


func _select_map(index: int) -> void:
	_selected_map = index
	_refresh_map_cards()


func _refresh_map_cards() -> void:
	for i: int in _map_cards.size():
		var color := CYAN if i == _selected_map else Color(0.19, 0.29, 0.37)
		var width := 2 if i == _selected_map else 1
		var normal := _box(Color(0.04, 0.08, 0.13, 0.9), color, width, 0)
		_map_cards[i].add_theme_stylebox_override("normal", normal)
		_map_cards[i].add_theme_stylebox_override("hover", _box(Color(0.08, 0.15, 0.21, 0.95), CYAN, 2, 0))
		_map_cards[i].add_theme_stylebox_override("pressed", normal)


func _select_weapon(index: int) -> void:
	loadout.starting_weapon_slot = index
	_refresh_weapon_cards()
	_save_preferences()


func _refresh_weapon_cards() -> void:
	for i: int in _weapon_cards.size():
		_weapon_cards[i].text = "%02d   %s\n%s" % [i + 1,
			"LÂMINA DE ARCO" if i == 0 else "PRESA DE FASE",
			"ARMA INICIAL" if i == loadout.starting_weapon_slot else "DISPONÍVEL EM PARTIDA"]
		var color := CYAN if i == loadout.starting_weapon_slot else Color(0.20, 0.31, 0.38)
		_weapon_cards[i].add_theme_stylebox_override("normal", _box(Color(0.035, 0.065, 0.11, 0.94), color, 2, 10))
		_weapon_cards[i].add_theme_stylebox_override("hover", _box(Color(0.07, 0.12, 0.18, 0.97), CYAN, 2, 10))


func _enter_match() -> void:
	if _save_preferences():
		get_tree().change_scene_to_file(SceneCycler.SCENES[_selected_map])


func _save_preferences() -> bool:
	var look_error := look.save_user()
	var loadout_error := loadout.save_user()
	if look_error != OK or loadout_error != OK:
		_status.text = "Não foi possível salvar o loadout em user://."
		return false
	return true


func _open_customize() -> void:
	if is_instance_valid(_customize_overlay):
		return
	_customize_overlay = Control.new()
	_customize_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_customize_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.005, 0.013, 0.027, 0.52)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_customize_overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.56
	panel.anchor_right = 0.98
	panel.anchor_top = 0.10
	panel.anchor_bottom = 0.94
	panel.add_theme_stylebox_override("panel", _box(DARK, CYAN, 2, 22))
	_customize_overlay.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	column.add_child(_label("PERSONAGEM", 28, WHITE))
	column.add_child(_label("Modelo e cores • prévia ao vivo", 14, MUTED))
	column.add_child(_label("MODELO", 15, CYAN))
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
	column.add_child(scroll)
	var colors := VBoxContainer.new()
	colors.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	colors.add_theme_constant_override("separation", 10)
	scroll.add_child(colors)
	_pickers.clear()
	_hero_rows.clear()
	for entry: Array in COLORS:
		var row := HBoxContainer.new()
		row.add_child(_label(entry[1], 16, WHITE))
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var picker := ColorPickerButton.new()
		picker.edit_alpha = false
		picker.color = look.get(entry[0])
		picker.custom_minimum_size = Vector2(150, 34)
		var property: String = entry[0]
		picker.color_changed.connect(func(color: Color) -> void: _set_color(property, color))
		row.add_child(picker)
		colors.add_child(row)
		_pickers[property] = picker
		if entry[2]:
			_hero_rows.append(row)
	_refresh_hero_rows()
	var close := Button.new()
	close.text = "SALVAR E VOLTAR A JOGAR"
	close.custom_minimum_size.y = 58
	close.pressed.connect(_close_customize)
	column.add_child(close)


func _close_customize() -> void:
	if not is_instance_valid(_customize_overlay):
		return
	if not _save_preferences():
		return
	_customize_overlay.queue_free()
	_customize_overlay = null
	_pickers.clear()
	_hero_rows.clear()


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


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _nav(value: String, active: bool) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(125, 42)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", CYAN if active else MUTED)
	button.add_theme_stylebox_override("normal", _box(Color.TRANSPARENT, CYAN if active else Color.TRANSPARENT, 1 if active else 0, 4))
	button.add_theme_stylebox_override("hover", _box(Color(0.08, 0.17, 0.23, 0.9), CYAN, 1, 4))
	return button


func _box(bg: Color, border: Color, width: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(width)
	style.set_content_margin_all(margin)
	return style
