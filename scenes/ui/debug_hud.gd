extends CanvasLayer
## HUD de debug (F1): estado, velocidades, SP, chão/parede, eventos e técnicas.
## Ouve GameEvents; nunca altera gameplay.

const EVENT_LOG_SIZE: int = 6

var player: Player
var _label: Label
var _events: Array[String] = []
var _last_event: String = "-"
var _last_technique: String = "-"
var _technique_counts: Dictionary = {}


func _ready() -> void:
	layer = 10
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(12, 12)
	add_child(panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 14)
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "monospace"])
	_label.add_theme_font_override("font", mono)
	panel.add_child(_label)
	GameEvents.wall_jump_executed.connect(func(_p: Node, d: Dictionary) -> void:
		_push_event("wall jump (%s)" % d.get("technique", "normal")))
	GameEvents.technique_executed.connect(_on_technique)
	GameEvents.dodged.connect(func(_p: Node, _d: Vector3) -> void: _push_event("dodge"))
	GameEvents.jumped.connect(func(_p: Node) -> void: _push_event("pulo"))
	GameEvents.landed.connect(func(_p: Node, s: float) -> void: _push_event("aterrissou (%.1f m/s)" % s))
	GameEvents.sp_depleted.connect(func(_p: Node) -> void: _push_event("SP ZERADO"))
	GameEvents.sp_recovered.connect(func(_p: Node) -> void: _push_event("SP recuperado"))
	GameEvents.weapon_swap_pressed.connect(func(_p: Node, slot: int) -> void:
		_push_event("troca de arma %d" % slot))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug_hud"):
		visible = not visible


func _on_technique(_p: Node, technique: StringName, _data: Dictionary) -> void:
	_last_technique = String(technique).to_upper()
	_technique_counts[technique] = int(_technique_counts.get(technique, 0)) + 1
	_push_event("TÉCNICA: %s" % _last_technique)


func _push_event(text: String) -> void:
	var tick := player.tick if player != null else 0
	_last_event = text
	_events.push_front("%6d  %s" % [tick, text])
	if _events.size() > EVENT_LOG_SIZE:
		_events.resize(EVENT_LOG_SIZE)


func _process(_delta: float) -> void:
	if not visible:
		return
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"local_player") as Player
		if player == null:
			return
	var p := player
	var lines: PackedStringArray = []
	lines.append("REBELLIUM debug  [F1 esconde | F2 menu]   FPS %d" % Engine.get_frames_per_second())
	lines.append("estado        %s  (%d ticks)" % [p.get_state_name(), p.state_machine.ticks_in_state()])
	lines.append("vel horiz     %6.2f m/s" % p.get_horizontal_speed())
	lines.append("vel vertical  %6.2f m/s" % p.velocity.y)
	lines.append("altura pés    %6.2f m" % p.global_position.y)
	lines.append("SP            %6.1f%s" % [p.sp.current, "  EXAUSTO" if p.sp.exhausted else ""])
	lines.append("no chão       %s" % ("sim" if p.is_on_floor() else "não"))
	lines.append("na parede     %s" % p.get_wall_debug_text())
	lines.append("origem do ar  %s   ticks desde pulo %s" % [Player.AirOrigin.keys()[p.air_origin],
		str(p.ticks_since(p.last_jump_tick)) if p.last_jump_tick > PlayerInput.NEVER else "-"])
	lines.append("invulnerável  %s" % ("SIM" if p.is_invulnerable else "não"))
	lines.append("último evento %s" % _last_event)
	lines.append("última técnica %s" % _last_technique)
	if not _technique_counts.is_empty():
		var parts: PackedStringArray = []
		for key: StringName in _technique_counts:
			parts.append("%s:%d" % [key, _technique_counts[key]])
		lines.append("técnicas      %s" % ", ".join(parts))
	lines.append("")
	lines.append("transições:")
	for line in p.state_machine.history.slice(0, 5):
		lines.append("  " + line)
	lines.append("eventos:")
	for line in _events:
		lines.append("  " + line)
	_label.text = "\n".join(lines)

