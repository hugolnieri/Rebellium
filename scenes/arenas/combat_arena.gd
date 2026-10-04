extends Node3D
## Arena de combate: chão simples, postes de treino, R volta ao início e zera os postes.

## Abaixo desta altura o jogador volta ao spawn.
@export var kill_height: float = -6.0

@onready var player: Player = $Player
@onready var spawn: Marker3D = $Spawn
@onready var dummies: Node3D = $Dummies


func _ready() -> void:
	_respawn.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reset_course"):
		reset()


func _physics_process(_delta: float) -> void:
	if player.global_position.y < kill_height:
		_respawn()


func reset() -> void:
	for child in dummies.get_children():
		var dummy := child as TrainingDummy
		if dummy == null:
			continue  # números de dano flutuando
		dummy.total_damage = 0.0
		dummy.hp = dummy.config.max_hp
	_respawn()


func _respawn() -> void:
	var t := spawn.global_transform
	var yaw := t.basis.get_euler().y
	player.respawn(Transform3D(Basis(Vector3.UP, yaw), t.origin))
	player.spawn_transform = player.global_transform
	player.input_reader.look_yaw = yaw
	player.input_reader.look_pitch = deg_to_rad(player.camera_config.initial_pitch_deg)
