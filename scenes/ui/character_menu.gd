extends CanvasLayer
## Menu de personagem (F4, autoload `CharacterMenu`): escolhe o modelo (o herói ou personagens do VRoid trazidos
## por tools/import_vroid.py) e as cores: cabelo, pele e olhos (tintas: branco = original) e, no herói, traje,
## costuras e emblema. Só visual; as mudanças valem na hora e ficam salvas ao fechar (user://personagem.tres).

const PANEL_WIDTH: float = 400.0
## Propriedade do CharacterLook → rótulo; as do traje só existem no herói.
const COLORS: Array[Array] = [
	["hair_color", "Cabelo", false], ["skin_color", "Pele", false], ["eye_color", "Olhos", false],
	["suit_color", "Traje", true], ["seam_color", "Costuras", true], ["emblem_color", "Emblema", true],
]

var player: Player
var look: CharacterLook
var _built: bool = false
var _model_list: OptionButton
var _models: Dictionary = {}
var _pickers: Dictionary = {}
var _hero_rows: Array[Control] = []
var _status: Label


func _ready() -> void:
	layer = 21
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_character_menu"):
		set_open(not visible)
		get_viewport().set_input_as_handled()


## Abre/fecha. Ao fechar, salva a aparência do jogador (`save` = false nos testes).
func set_open(open: bool, save: bool = true) -> void:
	if open:
		player = get_tree().get_first_node_in_group(&"local_player") as Player
		if player == null:
			return
		look = CharacterLook.load_user()
		var current := player.model.get_model_path()
		look.model_path = "" if current == CharacterLook.HERO_MODEL else current
		if not _built:
			_build()
		_refresh()
	elif visible and save and look != null:
		var err := look.save_user()
		if err != OK:
			push_warning("Não salvou a aparência (%s)." % error_string(err))
	visible = open
	if player != null and is_instance_valid(player):
		player.input_reader.enabled = not open
		player.input_reader.capture_mouse(not open)


## Escolhe um modelo pela posição na lista (0 = herói).
func select_model(index: int) -> void:
	var path: String = _models.values()[index]
	look.model_path = "" if path == CharacterLook.HERO_MODEL else path
	_apply()


func set_color(property: String, color: Color) -> void:
	look.set(property, color)
	_apply()


func get_model_count() -> int:
	return _models.size()


func _apply() -> void:
	if player != null and is_instance_valid(player):
		player.model.apply_look(look)
	for row in _hero_rows:
		row.visible = look.is_hero()
	_status.text = "Muda na hora; salva ao fechar (F4)."


func _build() -> void:
	_built = true
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.05, 0.92)
	style.border_color = Color(0.12, 0.62, 1.0)
	style.border_width_right = 2
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	panel.offset_right = PANEL_WIDTH
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	panel.add_child(root)
	var title := Label.new()
	title.text = "PERSONAGEM  [F4 fecha]"
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)
	root.add_child(_row_label("Modelo"))
	_model_list = OptionButton.new()
	_model_list.item_selected.connect(select_model)
	root.add_child(_model_list)
	var hint := Label.new()
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.text = "Personagens do VRoid Studio: exporte em VRM e rode tools/import_vroid.py (ver docs)."
	hint.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	root.add_child(hint)
	for entry in COLORS:
		var row := HBoxContainer.new()
		var label := _row_label(entry[1])
		label.custom_minimum_size = Vector2(120, 0)
		row.add_child(label)
		var picker := ColorPickerButton.new()
		picker.edit_alpha = false
		picker.custom_minimum_size = Vector2(160, 28)
		var property: String = entry[0]
		picker.color_changed.connect(func(color: Color) -> void: set_color(property, color))
		row.add_child(picker)
		root.add_child(row)
		_pickers[property] = picker
		if entry[2]:
			_hero_rows.append(row)
	var tints := Label.new()
	tints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tints.text = "Cabelo, pele e olhos tingem a cor do modelo (branco = original)."
	tints.add_theme_color_override("font_color", Color(0.6, 0.62, 0.68))
	root.add_child(tints)
	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	var defaults := Button.new()
	defaults.text = "Cores padrão"
	defaults.pressed.connect(_reset_colors)
	buttons.add_child(defaults)
	var close := Button.new()
	close.text = "Fechar e salvar"
	close.pressed.connect(func() -> void: set_open(false))
	buttons.add_child(close)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status)


func _row_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _refresh() -> void:
	_models = CharacterLook.available_models()
	_model_list.clear()
	var current := look.resolved_model_path()
	var index := 0
	for label: String in _models:
		_model_list.add_item(label)
		if _models[label] == current:
			_model_list.select(index)
		index += 1
	for property: String in _pickers:
		(_pickers[property] as ColorPickerButton).color = look.get(property)
	_apply()


func _reset_colors() -> void:
	var fresh := CharacterLook.new()
	for entry in COLORS:
		look.set(entry[0], fresh.get(entry[0]))
	_refresh()
