class_name TouchdownArena
extends Node3D
## Protótipo solo de Touch Down: pega o núcleo central e o entrega na base vermelha.

@export var config: TouchdownConfig

@onready var player: Player = $Player
@onready var spawn: Marker3D = $Spawn
@onready var ball: Area3D = $Ball
@onready var ball_collision: CollisionShape3D = $Ball/CollisionShape3D
@onready var carried_ball: Node3D = $Player/CarriedBall
@onready var goal: Area3D = $EnemyGoal
@onready var goal_collision: CollisionShape3D = $EnemyGoal/CollisionShape3D
@onready var dummies: Node3D = $Dummies

var score: int = 0
var time_left: float = 0.0
var carrying: bool = false
var finished: bool = false
var ball_available: bool = true
var _ball_reset_left: float = 0.0


func _ready() -> void:
	if config == null:
		config = TouchdownConfig.new()
	config.changed.connect(_apply_config)
	_apply_config()
	time_left = config.duration
	carried_ball.visible = false
	ball.body_entered.connect(_on_ball_entered)
	goal.body_entered.connect(_on_goal_entered)
	GameEvents.player_died.connect(_on_player_died)
	_respawn_player.call_deferred()


func _exit_tree() -> void:
	if GameEvents.player_died.is_connected(_on_player_died):
		GameEvents.player_died.disconnect(_on_player_died)


func _apply_config() -> void:
	(ball_collision.shape as SphereShape3D).radius = config.pickup_radius
	(goal_collision.shape as BoxShape3D).size = Vector3(
		config.goal_width, config.goal_height, config.goal_depth)


func _physics_process(delta: float) -> void:
	if finished:
		return
	time_left = maxf(time_left - delta, 0.0)
	if time_left <= 0.0:
		_end_match()
		return
	if player.global_position.y < config.fall_reset_height:
		_drop_ball()
		_respawn_player()
	if not carrying and not ball_available and _ball_reset_left > 0.0:
		_ball_reset_left -= delta
		if _ball_reset_left <= 0.0:
			_restore_ball()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reset_course"):
		reset_match()


func _on_ball_entered(body: Node3D) -> void:
	if body != player or carrying or not ball_available or finished:
		return
	carrying = true
	ball_available = false
	ball.set_deferred(&"monitoring", false)
	ball.visible = false
	carried_ball.visible = true
	GameEvents.touchdown_ball_picked.emit(player)


func _on_goal_entered(body: Node3D) -> void:
	if body != player or not carrying or finished:
		return
	score += 1
	GameEvents.touchdown_scored.emit(player, score)
	carrying = false
	carried_ball.visible = false
	if score >= config.score_limit:
		_end_match()
		return
	_queue_ball_reset()
	_respawn_player()


func _on_player_died(who: Node) -> void:
	if who == player and carrying:
		_drop_ball()


func _drop_ball() -> void:
	if not carrying:
		return
	carrying = false
	carried_ball.visible = false
	_queue_ball_reset()


func _queue_ball_reset() -> void:
	ball_available = false
	ball.set_deferred(&"monitoring", false)
	ball.visible = false
	_ball_reset_left = config.ball_reset_delay
	if _ball_reset_left <= 0.0:
		_restore_ball()


func _restore_ball() -> void:
	if finished:
		return
	ball_available = true
	ball.visible = true
	ball.set_deferred(&"monitoring", true)
	_ball_reset_left = 0.0


func _respawn_player() -> void:
	if not is_instance_valid(player):
		return
	var at := spawn.global_transform
	var yaw := at.basis.get_euler().y
	player.respawn(Transform3D(Basis(Vector3.UP, yaw), at.origin))
	player.spawn_transform = at
	player.input_reader.look_yaw = yaw
	player.input_reader.look_pitch = deg_to_rad(player.camera_config.initial_pitch_deg)


func _end_match() -> void:
	finished = true
	ball.set_deferred(&"monitoring", false)
	ball.visible = false
	carried_ball.visible = false
	carrying = false


func reset_match() -> void:
	score = 0
	time_left = config.duration
	finished = false
	carrying = false
	carried_ball.visible = false
	for child: Node in dummies.get_children():
		var dummy := child as TrainingDummy
		if dummy != null:
			dummy.reset_target()
	_restore_ball()
	_respawn_player()
