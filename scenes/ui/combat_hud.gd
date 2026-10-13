extends CanvasLayer
## HUD de combate: armas (slot atual), contador de combo, dano do combo, DPS e mira central.

## Janela usada para o cálculo de DPS.
const DPS_WINDOW: float = 3.0

var player: Player
var _canvas: Control
var _combo_hits: int = 0
var _combo_damage: float = 0.0
var _combo_timer: float = 0.0
var _recent: Array[Vector2] = []  # (tempo, dano)
var _time: float = 0.0
var _last_attack: String = "-"
var _pop: float = 0.0


func _ready() -> void:
	_canvas = preload("res://scenes/ui/hud_canvas.gd").new()
	_canvas.combat = true
	add_child(_canvas)
	GameEvents.hit_landed.connect(_on_hit)
	GameEvents.attack_started.connect(func(who: Node, attack: Resource, _w: Resource, _k: StringName) -> void:
		if who == player:
			_last_attack = (attack as AttackData).display_name)

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
	_pop = maxf(_pop - delta * 4.0, 0.0)
	_canvas.player = player
	_canvas.combo_hits = _combo_hits
	_canvas.combo_damage = _combo_damage
	_canvas.dps = window_damage / DPS_WINDOW
	_canvas.last_attack = _last_attack
	_canvas.pop = _pop
