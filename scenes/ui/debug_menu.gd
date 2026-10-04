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
	_controls[resource] = {}
	var pending_header := ""
	for property in ConfigIO.get_editable_properties(resource, true):
		if property.usage & PROPERTY_USAGE_GROUP:
			pending_header = property.name
			continue
		var row := _make_row(resource, property)
		if row == null:
			continue
		if pending_header != "":
			# Cabeçalho só aparece se o grupo tiver controles (ignora grupos da classe base).
			var header := Label.new()
			header.text = "— %s —" % pending_header.to_upper()
			header.add_theme_color_override("font_color", Color(0.12, 0.62, 1.0))
			list.add_child(header)
			pending_header = ""
		list.add_child(row)


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
	var err := ConfigIO.save_full(resource)
	_status.text = ("Salvo em %s" % resource.resource_path) if err == OK \
		else "ERRO ao salvar (%s)" % error_string(err)


func _reload() -> void:
	var resource := _current_resource()
	var from_disk := ResourceLoader.load(resource.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	ConfigIO.copy_properties(from_disk, resource)
	_refresh(resource)
	_status.text = "Recarregado de %s" % resource.resource_path


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
			elif control is Range:
				(control as Range).set_value_no_signal(value)
