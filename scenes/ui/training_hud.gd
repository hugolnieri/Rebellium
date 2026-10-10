extends CanvasLayer
## HUD do modo treino: cronômetro, melhor tempo, checkpoint, quedas e técnicas da tentativa.

const TECHNIQUE_LABELS: Dictionary = {
	&"side_jump": "Side jump",
	&"back_coming": "Back-coming",
	&"cancel": "Cancel",
	&"dodge_cancel": "Dodge cancel",
	&"bunny_hop": "Bunny hop",
}

var course: Node
var _timer_label: Label
var _info_label: Label
var _banner: Label
var _banner_time_left: float = 0.0


func _ready() -> void:
	course = get_parent()
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	box.position = Vector2(-340, 16)
	box.custom_minimum_size = Vector2(320, 0)
	add_child(box)
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 40)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_timer_label)
	_info_label = Label.new()
	_info_label.add_theme_font_size_override("font_size", 15)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_info_label)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-300, 90)
	_banner.custom_minimum_size = Vector2(600, 0)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 28)
	_banner.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05))
	_banner.add_theme_constant_override("outline_size", 8)
	add_child(_banner)
	course.run_started.connect(func() -> void: _show_banner("VALENDO!", Color(0.86, 0.84, 0.79)))
	course.checkpoint_reached.connect(func(label: String) -> void:
		_show_banner("checkpoint: " + label, Color(0.12, 0.62, 1.0)))
	course.run_finished.connect(_on_finished)
	course.run_reset.connect(func() -> void: _show_banner("reset", Color(0.47, 0.49, 0.52)))
	GameEvents.technique_executed.connect(_on_technique)


func _on_finished(time_s: float, best_s: float, is_record: bool) -> void:
	var text := "CHEGADA  %s" % _fmt(time_s)
	if is_record:
		text += "  — NOVO RECORDE"
	else:
		text += "  (melhor %s)" % _fmt(best_s)
	_show_banner(text, Color(0.62, 1.0, 0.12) if is_record else Color(0.86, 0.84, 0.79))


func _on_technique(who: Node, technique: StringName, _data: Dictionary) -> void:
	if who != course.player:
		return
	var color: Color = course.player.feedback_config.get_technique_color(technique)
	_show_banner(String(TECHNIQUE_LABELS.get(technique, technique)).to_upper(), color)


func _show_banner(text: String, color: Color) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_time_left = 1.4


func _process(delta: float) -> void:
	_banner_time_left = maxf(_banner_time_left - delta, 0.0)
	_banner.modulate.a = clampf(_banner_time_left / 0.4, 0.0, 1.0)
	var status := "PRONTO — saia da largada" if not course.running and not course.finished \
		else ("FINALIZADO" if course.finished else "")
	_timer_label.text = _fmt(course.get_run_seconds())
	var lines: PackedStringArray = []
	if status != "":
		lines.append(status)
	lines.append("melhor da sessão  %s" % (_fmt(course.get_best_seconds()) \
		if course.best_ticks >= 0 else "--:--.--"))
	lines.append("checkpoint  %s   quedas  %d" % [course.get_checkpoint_label(), course.falls])
	lines.append("técnicas no percurso  %d" % course.get_total_techniques())
	for key: StringName in TECHNIQUE_LABELS:
		lines.append("%s  %d" % [TECHNIQUE_LABELS[key], int(course.technique_counts.get(key, 0))])
	lines.append("[R] reinicia   [F2] ajustes")
	_info_label.text = "\n".join(lines)


func _fmt(seconds: float) -> String:
	if seconds < 0.0:
		return "--:--.--"
	var minutes := int(seconds / 60.0)
	return "%02d:%05.2f" % [minutes, seconds - minutes * 60.0]
