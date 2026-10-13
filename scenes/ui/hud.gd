extends CanvasLayer
## HUD de vida/SP e atalhos, somente leitura do jogador.
const HUD_CANVAS: Script = preload("res://scenes/ui/hud_canvas.gd")
var player: Player
var _canvas: Control

func _ready() -> void:
	_canvas = HUD_CANVAS.new()
	add_child(_canvas)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"local_player") as Player
	_canvas.player = player
