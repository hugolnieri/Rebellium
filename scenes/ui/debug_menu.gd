extends CanvasLayer
## Menu de debug em jogo (F2): edita o MovementConfig (e a câmera) em tempo real e salva no .tres.
## Os controles são gerados a partir dos @export das classes: valor novo na config aparece aqui
## sem código extra.

const PANEL_WIDTH: float = 500.0

var player: Player
var _tabs: TabContainer
var _status: Label
var _built: bool = false
## { Resource: { property_name: [HSlider/CheckBox, SpinBox] } } para atualizar após recarregar.
var _controls: Dictionary = {}


func _ready() -> void:
	layer = 20
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug_menu"):
		set_open(not visible)
		get_viewport().set_input_as_handled()


func set_open(open: bool) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"local_player") as Player
		if player == null:
			return
	if not _built:
		_build()
	visible = open
	player.input_reader.enabled = not open
	player.input_reader.capture_mouse(not open)


func _build() -> void:
	_built = true
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.05, 0.92)
	style.border_color = Color(0.58, 0.28, 0.98)
	style.border_width_left = 2
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -PANEL_WIDTH
	add_child(panel)
	var root := VBoxContainer.new()
	panel.add_child(root)
	var title := Label.new()
	title.text = "AJUSTES AO VIVO  [F2 fecha]"
	title.add_theme_font_size_override("font_size", 18)
	root.add_child(title)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(_tabs)
	_add_tab("Movimento", player.config)
	_add_tab("Câmera", player.camera_config)
	_add_tab("Visual", player.feedback_config)
	_add_tab("Combate", player.combat_config)
	for weapon in player.weapons:
		_add_tab(weapon.display_name, weapon)
	var sound_manager := get_node_or_null(^"/root/SoundManager")
	if sound_manager != null:
		_add_tab("Áudio", sound_manager.get(&"config"))
	var buttons := HBoxContainer.new()
	root.add_child(buttons)
	_add_button(buttons, "Salvar no .tres", _save)
	_add_button(buttons, "Recarregar", _reload)
	_add_button(buttons, "Padrões", _defaults)
	_add_button(buttons, "Fechar", func() -> void: set_open(false))
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.text = "Mudanças valem na hora. 'Salvar' grava a aba atual em %s." % player.config.resource_path
	root.add_child(_status)


func _add_button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


func _add_tab(tab_name: String, resource: Resource) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = tab_name
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	scroll.set_meta(&"resource", resource)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_add_resource_rows(list, resource, "")


## Gera as linhas de um recurso; sub-recursos (ex.: golpes de uma arma) entram em seções próprias.
func _add_resource_rows(list: VBoxContainer, resource: Resource, prefix: String) -> void:
	_controls[resource] = {}
	var pending_header := ""
	var nested: Array[Resource] = []
	for property in ConfigIO.get_editable_properties(resource, true):
		if property.usage & PROPERTY_USAGE_GROUP:
			pending_header = property.name
			continue
		var value: Variant = resource.get(property.name)
		if value is Resource:
			nested.append(value)
			continue
		if value is Array:
			for item: Variant in value:
				if item is Resource:
					nested.append(item)
			continue
		var row := _make_row(resource, property)
		if row == null:
			continue
		if pending_header != "":
			# Cabeçalho só aparece se o grupo tiver controles (ignora grupos da classe base).
			_add_header(list, (prefix + " · " if prefix != "" else "") + pending_header,
				Color(0.12, 0.62, 1.0))
			pending_header = ""
		list.add_child(row)
	for child in nested:
		var title := String(child.get(&"display_name")) if child.get(&"display_name") != null \
			else child.resource_path.get_file()
		_add_header(list, "▶ " + title, Color(0.62, 1.0, 0.12))
		_add_resource_rows(list, child, title)


func _add_header(list: VBoxContainer, text: String, color: Color) -> void:
	var header := Label.new()
	header.text = "— %s —" % text.to_upper()
	header.add_theme_color_override("font_color", color)
	list.add_child(header)


func _make_row(resource: Resource, property: Dictionary) -> Control:
	var prop_name: String = property.name
	var type: int = property.type
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = prop_name
	label.custom_minimum_size = Vector2(220, 0)
	label.clip_text = true
	label.tooltip_text = prop_name
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(label)
	if type == TYPE_BOOL:
		var check := CheckBox.new()
		check.button_pressed = resource.get(prop_name)
		check.toggled.connect(func(on: bool) -> void: _set_value(resource, prop_name, on))
		row.add_child(check)
		_controls[resource][prop_name] = [check]
		return row
	if property.hint == PROPERTY_HINT_ENUM and (type == TYPE_STRING or type == TYPE_INT):
		var options := OptionButton.new()
		var items := String(property.hint_string).split(",")
		for item in items:
			options.add_item(item.get_slice(":", 0))
		var current: Variant = resource.get(prop_name)
		options.selected = items.find(current) if type == TYPE_STRING else int(current)
		options.item_selected.connect(func(index: int) -> void:
			_set_value(resource, prop_name, items[index].get_slice(":", 0) if type == TYPE_STRING else index))
		row.add_child(options)
		_controls[resource][prop_name] = [options]
		return row
	if type == TYPE_STRING:
		var line := LineEdit.new()
		line.text = resource.get(prop_name)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.text_submitted.connect(func(text: String) -> void: _set_value(resource, prop_name, text))
		row.add_child(line)
		_controls[resource][prop_name] = [line]
		return row
	if type == TYPE_COLOR:
		var picker := ColorPickerButton.new()
		picker.color = resource.get(prop_name)
		picker.custom_minimum_size = Vector2(120, 0)
		picker.color_changed.connect(func(color: Color) -> void: _set_value(resource, prop_name, color))
		row.add_child(picker)
		_controls[resource][prop_name] = [picker]
		return row
	if type != TYPE_FLOAT and type != TYPE_INT:
		return null
	var range_info := _parse_range(property.hint_string, type == TYPE_INT)
	var slider := HSlider.new()
	slider.min_value = range_info.min
	slider.max_value = range_info.max
	slider.step = range_info.step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var spin := SpinBox.new()
	spin.min_value = range_info.min
	spin.max_value = range_info.max
	spin.step = range_info.step
	spin.allow_greater = true
	spin.allow_lesser = true
	spin.suffix = range_info.suffix
	spin.custom_minimum_size = Vector2(120, 0)
	var value: float = resource.get(prop_name)
	slider.set_value_no_signal(value)
	spin.set_value_no_signal(value)
	slider.value_changed.connect(func(v: float) -> void:
		spin.set_value_no_signal(v)
		_set_value(resource, prop_name, int(v) if type == TYPE_INT else v))
	spin.value_changed.connect(func(v: float) -> void:
		slider.set_value_no_signal(v)
		_set_value(resource, prop_name, int(v) if type == TYPE_INT else v))
	row.add_child(slider)
	row.add_child(spin)
	_controls[resource][prop_name] = [slider, spin]
	return row


func _parse_range(hint: String, is_int: bool) -> Dictionary:
	var info := {"min": 0.0, "max": 100.0, "step": 1.0 if is_int else 0.01, "suffix": ""}
	var parts := hint.split(",")
	if parts.size() >= 2 and parts[0].is_valid_float() and parts[1].is_valid_float():
		info.min = parts[0].to_float()
		info.max = parts[1].to_float()
	if parts.size() >= 3 and parts[2].strip_edges().is_valid_float():
		info.step = parts[2].to_float()
	for part in parts:
		var p := part.strip_edges()
		if p.begins_with("suffix:"):
			info.suffix = p.trim_prefix("suffix:")
	return info


func _set_value(resource: Resource, prop_name: String, value: Variant) -> void:
	resource.set(prop_name, value)
	resource.emit_changed()
	_status.text = "%s = %s  (não salvo)" % [prop_name, str(value)]


func _current_resource() -> Resource:
	return _tabs.get_current_tab_control().get_meta(&"resource")


func _save() -> void:
	var resource := _current_resource()
	var err := ConfigIO.save_tree(resource)
	_status.text = ("Salvo em %s" % resource.resource_path) if err == OK \
		else "ERRO ao salvar (%s)" % error_string(err)


func _reload() -> void:
	var resource := _current_resource()
	_reload_tree(resource)
	_status.text = "Recarregado de %s" % resource.resource_path


func _reload_tree(resource: Resource) -> void:
	for child in ConfigIO.get_file_subresources(resource):
		_reload_tree(child)
	var from_disk := ResourceLoader.load(resource.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	ConfigIO.copy_properties(from_disk, resource)
	_refresh(resource)


func _defaults() -> void:
	var resource := _current_resource()
	var fresh: Resource = (resource.get_script() as Script).new()
	ConfigIO.copy_properties(fresh, resource)
	_refresh(resource)
	_status.text = "Valores padrão aplicados (não salvo)."


func _refresh(resource: Resource) -> void:
	var controls: Dictionary = _controls[resource]
	for prop_name: String in controls:
		var value: Variant = resource.get(prop_name)
		for control: Control in controls[prop_name]:
			if control is CheckBox:
				(control as CheckBox).set_pressed_no_signal(value)
			elif control is LineEdit:
				(control as LineEdit).text = value
			elif control is ColorPickerButton:
				(control as ColorPickerButton).color = value
			elif control is Range:
				(control as Range).set_value_no_signal(value)
