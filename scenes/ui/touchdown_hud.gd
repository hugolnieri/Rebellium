extends CanvasLayer
## HUD do objetivo, separado da lógica do modo.

var arena: TouchdownArena
var _score: Label
var _clock: Label
var _objective: Label


func _ready() -> void:
	layer = 8
	arena = get_parent() as TouchdownArena
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -210.0
	panel.offset_right = 210.0
	panel.offset_top = 12.0
	panel.offset_bottom = 118.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.015, 0.03, 0.065, 0.92)
	style.border_color = Color(0.28, 0.78, 1.0)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(column)
	_score = _label("TOUCH DOWN", 18, Color(0.56, 0.87, 1.0))
	column.add_child(_score)
	_clock = _label("03:00", 25, Color.WHITE)
	column.add_child(_clock)
	_objective = _label("PEGUE O NÚCLEO", 14, Color(1.0, 0.82, 0.92))
	column.add_child(_objective)


func _process(_delta: float) -> void:
	if not is_instance_valid(arena):
		return
	_score.text = "TOUCH DOWN   •   ENTREGAS %d/%d" % [arena.score, arena.config.score_limit]
	var seconds := ceili(arena.time_left)
	_clock.text = "%02d:%02d" % [seconds / 60, seconds % 60]
	if arena.finished:
		_objective.text = "PARTIDA CONCLUÍDA  •  R REINICIA" if arena.score >= arena.config.score_limit \
			else "TEMPO ESGOTADO  •  R REINICIA"
	elif arena.carrying:
		var meters := roundi(arena.player.global_position.distance_to(arena.goal.global_position))
		_objective.text = "LEVE À BASE VERMELHA  •  %d m" % meters
	elif arena.ball_available:
		var meters := roundi(arena.player.global_position.distance_to(arena.ball.global_position))
		_objective.text = "PEGUE O NÚCLEO NO CENTRO  •  %d m" % meters
	else:
		_objective.text = "NÚCLEO REAPARECENDO..."


func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
