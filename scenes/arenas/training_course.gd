extends Node3D
## Modo treino: cronômetro (sai da largada → chega na torre), melhor tempo da sessão,
## checkpoints, queda no fosso volta ao checkpoint, R reinicia e contador de técnicas.

signal run_started
signal run_finished(time_seconds: float, best_seconds: float, is_record: bool)
signal checkpoint_reached(label: String)
signal run_reset

## Abaixo desta altura o jogador volta ao último checkpoint.
@export var kill_height: float = -6.0

@onready var player: Player = $Player
@onready var checkpoints: Node3D = $Checkpoints
@onready var finish_zone: Area3D = $FinishZone

var running: bool = false
var finished: bool = false
var run_ticks: int = 0
var best_ticks: int = -1
var last_ticks: int = -1
var falls: int = 0
## Técnicas executadas na tentativa atual: { StringName: int }.
var technique_counts: Dictionary = {}
var current_checkpoint: Area3D
var start_checkpoint: Area3D


func _ready() -> void:
	for child in checkpoints.get_children():
		var area := child as Area3D
		area.body_entered.connect(_on_checkpoint_entered.bind(area))
	start_checkpoint = checkpoints.get_child(0) as Area3D
	start_checkpoint.body_exited.connect(_on_start_exited)
	finish_zone.body_entered.connect(_on_finish_entered)
	GameEvents.technique_executed.connect(_on_technique)
	current_checkpoint = start_checkpoint
	_respawn.call_deferred(start_checkpoint)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"reset_course"):
		reset_run()


func _physics_process(_delta: float) -> void:
	if running:
		run_ticks += 1
	if player.global_position.y < kill_height:
		falls += 1
		_respawn(current_checkpoint)


func get_run_seconds() -> float:
	return float(run_ticks) / Engine.physics_ticks_per_second


func get_best_seconds() -> float:
	return float(best_ticks) / Engine.physics_ticks_per_second if best_ticks >= 0 else -1.0


func get_checkpoint_label() -> String:
	return String(current_checkpoint.get_meta(&"label", current_checkpoint.name))


func get_total_techniques() -> int:
	var total := 0
	for key: StringName in technique_counts:
		total += int(technique_counts[key])
	return total


## Volta ao início, zera cronômetro e contador (tecla R).
func reset_run() -> void:
	running = false
	finished = false
	run_ticks = 0
	falls = 0
	technique_counts.clear()
	current_checkpoint = start_checkpoint
	_respawn(start_checkpoint)
	run_reset.emit()


func _respawn(checkpoint: Area3D) -> void:
	var t := checkpoint.global_transform
	var yaw := t.basis.get_euler().y
	player.respawn(Transform3D(Basis(Vector3.UP, yaw), t.origin))
	player.input_reader.look_yaw = yaw
	player.input_reader.look_pitch = deg_to_rad(player.camera_config.initial_pitch_deg)


func _on_start_exited(body: Node3D) -> void:
	if body != player or running or finished:
		return
	running = true
	run_ticks = 0
	falls = 0
	technique_counts.clear()
	run_started.emit()


func _on_checkpoint_entered(body: Node3D, area: Area3D) -> void:
	if body != player or area == current_checkpoint:
		return
	if area.get_index() < current_checkpoint.get_index() and running:
		return  # não regride checkpoint durante a tentativa
	current_checkpoint = area
	checkpoint_reached.emit(get_checkpoint_label())


func _on_finish_entered(body: Node3D) -> void:
	if body != player or not running:
		return
	running = false
	finished = true
	last_ticks = run_ticks
	var is_record := best_ticks < 0 or run_ticks < best_ticks
	if is_record:
		best_ticks = run_ticks
	run_finished.emit(get_run_seconds(), get_best_seconds(), is_record)


func _on_technique(who: Node, technique: StringName, _data: Dictionary) -> void:
	if who != player or finished:
		return
	technique_counts[technique] = int(technique_counts.get(technique, 0)) + 1
