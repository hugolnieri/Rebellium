extends Control
## Primitivas vetoriais do HUD; coordenadas em uma prancheta de 1600 × 900.
const WHITE: Color = Color(0.92, 0.94, 0.97)
var player: Player
var combat: bool = false
var combo_hits: int = 0
var combo_damage: float = 0.0
var dps: float = 0.0
var last_attack: String = "—"
var pop: float = 0.0
var _font: Font = ThemeDB.fallback_font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var factor: float = minf(viewport_size.x / 1600.0, viewport_size.y / 900.0)
	scale = Vector2.ONE * factor
	size = viewport_size / factor
	queue_redraw()

func _text(at: Vector2, value: String, font_size: int = 16, color: Color = WHITE) -> void:
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)

func _panel(rect: Rect2, accent: Color = Color.TRANSPARENT) -> void:
	if accent == Color.TRANSPARENT:
		accent = player.feedback_config.hud_accent_color
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	var points: PackedVector2Array = PackedVector2Array([
		Vector2(x + 14, y), Vector2(x + w, y), Vector2(x + w - 14, y + h), Vector2(x, y + h)])
	draw_colored_polygon(points, player.feedback_config.hud_panel_color)
	points.append(points[0])
	draw_polyline(points, Color(accent, 0.6), 1.0, true)

func _bar(at: Vector2, title: String, current: float, maximum: float, color: Color) -> void:
	_panel(Rect2(at, Vector2(510, 34)))
	_text(at + Vector2(22, 23), title)
	var start: Vector2 = at + Vector2(72, 6)
	var width: float = 320.0
	var fraction: float = clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	draw_rect(Rect2(start, Vector2(width, 22)), Color(0.07, 0.12, 0.16))
	if fraction > 0.0:
		var fill_width: float = width * fraction
		var bevel: float = minf(10.0, fill_width * 0.5)
		draw_colored_polygon(PackedVector2Array([start + Vector2(bevel, 0), start + Vector2(fill_width, 0),
			start + Vector2(fill_width - bevel, 22), start + Vector2(0, 22)]), color)
		draw_line(start + Vector2(bevel, 2), start + Vector2(fill_width, 2), color.lightened(0.35), 1.0, true)
	_text(at + Vector2(408, 23), "%d / %d" % [ceili(current), roundi(maximum)], 15)

func _draw() -> void:
	if not is_instance_valid(player):
		return
	if not combat:
		var feedback: FeedbackConfig = player.feedback_config
		_bar(Vector2(24, size.y - 116), "VIDA", player.health.current, player.health.maximum, feedback.hp_bar_color)
		_bar(Vector2(24, size.y - 74), "SP", player.sp.current, player.config.sp_max,
			feedback.sp_exhausted_color if player.sp.exhausted else feedback.sp_bar_color)
		if player.sp.exhausted:
			_text(Vector2(48, size.y - 124), "EXAUSTO", 14, feedback.sp_exhausted_color)
		var hints: Array[String] = ["F1  Dados", "F2  Ajustes", "F3  Arena", "F4  Personagem"]
		for i: int in hints.size():
			var at: Vector2 = Vector2(size.x - 510 + i * 122, size.y - 44)
			_text(at, hints[i], 14)
		return
	for i: int in player.weapons.size():
		var at: Vector2 = Vector2(size.x - 380, 28 + i * 50)
		var selected: bool = i == player.weapon_slot
		var accent: Color = player.feedback_config.hud_selected_color if selected else player.feedback_config.hud_accent_color
		_panel(Rect2(at, Vector2(356, 42)), accent)
		if selected:
			draw_line(at + Vector2(7, 8), at + Vector2(0, 34), accent, 4.0, true)
		# Silhueta original de lâmina, desenhada sem textura.
		draw_line(at + Vector2(34, 22), at + Vector2(100, 22), WHITE, 2.0, true)
		draw_line(at + Vector2(46, 16), at + Vector2(46, 28), accent, 2.0, true)
		_text(at + Vector2(120, 28), str(i + 1), 22, accent)
		_text(at + Vector2(153, 27), player.weapons[i].display_name, 17)
	_text(Vector2(size.x - 193, 48 + player.weapons.size() * 50), "Q   ALTERNAR", 14)
	var panel: Vector2 = Vector2(size.x - 254, size.y * 0.5 - 72)
	_panel(Rect2(panel, Vector2(230, 158)))
	draw_line(panel + Vector2(14, 13), panel + Vector2(14, 32), player.feedback_config.hud_accent_color, 3.0)
	_text(panel + Vector2(25, 29), "COMBATE", 18)
	var rows: Array[String] = ["Dano do combo", "DPS (3 s)", "Último golpe"]
	var values: Array[String] = [str(roundi(combo_damage)), str(roundi(dps)), last_attack]
	for i: int in rows.size():
		var y: float = panel.y + 60 + i * 30
		draw_line(Vector2(panel.x + 16, y + 9), Vector2(panel.x + 214, y + 9), Color(player.feedback_config.hud_accent_color, 0.15))
		_text(Vector2(panel.x + 16, y), rows[i], 14)
		var value_size: int = 13 if i == 2 else 16
		var available: float = 90.0
		var value: String = values[i]
		while _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size).x > available and value.length() > 2:
			value = value.left(value.length() - 2) + "…"
		var width: float = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, value_size).x
		_text(Vector2(panel.x + 214 - width, y), value, value_size)
	if combo_hits >= 2:
		_text(panel + Vector2(8, -22), "%d HITS" % combo_hits, roundi(38 + pop * 6), player.feedback_config.hud_accent_color)
	var center: Vector2 = size * 0.5
	draw_circle(center, 1.5, WHITE)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + direction * 10, center + direction * 17, Color(WHITE, 0.8), 1.0, true)
