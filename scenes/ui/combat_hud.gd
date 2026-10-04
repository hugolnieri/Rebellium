extends CanvasLayer
## HUD de combate: armas (slot atual), contador de combo, dano do combo, DPS e mira central.

## Janela usada para o cálculo de DPS.
const DPS_WINDOW: float = 3.0

var player: Player
var _weapons_label: Label
var _combo_label: Label
var _stats_label: Label
var _combo_hits: int = 0
var _combo_damage: float = 0.0
var _combo_timer: float = 0.0
var _recent: Array[Vector2] = []  # (tempo, dano)
var _time: float = 0.0
var _last_attack: String = "-"
var _pop: float = 0.0


func _ready() -> void:
	_weapons_label = _label(Control.PRESET_TOP_RIGHT, Vector2(-430, 16), 18, HORIZONTAL_ALIGNMENT_RIGHT)
	_weapons_label.custom_minimum_size = Vector2(410, 0)
	_combo_label = _label(Control.PRESET_CENTER_RIGHT, Vector2(-330, -120), 56, HORIZONTAL_ALIGNMENT_RIGHT)
	_combo_label.custom_minimum_size = Vector2(300, 0)
	_stats_label = _label(Control.PRESET_CENTER_RIGHT, Vector2(-330, -40), 16, HORIZONTAL_ALIGNMENT_RIGHT)
	_stats_label.custom_minimum_size = Vector2(300, 0)
	var crosshair := ColorRect.new()
	crosshair.color = Color(0.86, 0.84, 0.79, 0.7)
	crosshair.size = Vector2(4, 4)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-2, -2)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(crosshair)
	GameEvents.hit_landed.connect(_on_hit)
	GameEvents.attack_started.connect(func(who: Node, attack: Resource, _w: Resource, _k: StringName) -> void:
		if who == player:
			_last_attack = (attack as AttackData).display_name)


func _label(preset: Control.LayoutPreset, offset: Vector2, size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(preset)
	label.position += offset
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = align
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _on_hit(attacker: Node, _target: Node, info: Dictionary) -> void:
	if attacker != player:
		return
	_combo_hits += 1
	_combo_damage += info.get("damage", 0.0)
	_combo_timer = player.combat_config.combo_timeout
	_recent.append(Vector2(_time, info.get("damage", 0.0)))
	_pop = 1.0


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"local_player") as Player
		if player == null:
			return
	_time += delta
	_combo_timer -= delta
	if _combo_timer <= 0.0:
		_combo_hits = 0
		_combo_damage = 0.0
	while not _recent.is_empty() and _time - _recent[0].x > DPS_WINDOW:
		_recent.pop_front()
	var window_damage := 0.0
	for entry in _recent:
		window_damage += entry.y
	var parts: PackedStringArray = []
	for i in player.weapons.size():
		var weapon := player.weapons[i]
		var text := "[%d] %s" % [i + 1, weapon.display_name]
		parts.append(("▶ " + text + " ◀") if i == player.weapon_slot else text)
	_weapons_label.text = "\n".join(parts) + "\n[Q] alterna"
	var weapon_color := player.get_weapon().glow_color if player.get_weapon() != null else Color.WHITE
	_weapons_label.add_theme_color_override("font_color", weapon_color.lerp(Color.WHITE, 0.4))
	_pop = maxf(_pop - delta * 4.0, 0.0)
	_combo_label.visible = _combo_hits >= 2
	_combo_label.text = "%d HITS" % _combo_hits
	_combo_label.scale = Vector2.ONE * (1.0 + _pop * 0.25)
	_combo_label.add_theme_color_override("font_color", weapon_color.lerp(Color.WHITE, 0.25))
	_stats_label.text = "dano do combo  %d\nDPS (3 s)  %d\núltimo golpe  %s" % [
		roundi(_combo_damage), roundi(window_damage / DPS_WINDOW), _last_attack]
