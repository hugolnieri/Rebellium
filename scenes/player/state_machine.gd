class_name StateMachine
extends Node
## Máquina de estados explícita do jogador. Estados são nós-filhos (um script por estado).
## TODA transição passa por `transition_to`, que registra histórico, loga e emite sinais.

signal transitioned(from_state: StringName, to_state: StringName, reason: String)

const HISTORY_SIZE: int = 8

@export var initial_state: StringName = &"Idle"
## Imprime cada transição no console (útil para depurar; desligado por padrão).
@export var log_transitions: bool = false

var player: Player
var states: Dictionary = {}
var current: PlayerState
var current_name: StringName = &""
## Tick em que o estado atual começou.
var entered_tick: int = 0
## Últimas transições, mais recente primeiro: "tick  De → Para (motivo)".
var history: Array[String] = []


func setup(owner_player: Player) -> void:
	player = owner_player
	for child in get_children():
		if child is PlayerState:
			var state := child as PlayerState
			state.player = player
			state.machine = self
			states[StringName(state.name)] = state
	transition_to(initial_state, "init")


func physics_update(input: PlayerInput, delta: float) -> void:
	current.physics_update(input, delta)


func post_move(input: PlayerInput) -> void:
	current.post_move(input)


func has_state(state_name: StringName) -> bool:
	return states.has(state_name)


func is_in(state_name: StringName) -> bool:
	return current_name == state_name


## Ticks desde que o estado atual começou.
func ticks_in_state() -> int:
	return player.tick - entered_tick


func transition_to(state_name: StringName, reason: String = "", data: Dictionary = {}) -> void:
	assert(states.has(state_name), "Estado inexistente: %s" % state_name)
	var from := current_name
	if current != null:
		current.exit()
	current = states[state_name]
	current_name = state_name
	entered_tick = player.tick
	var line := "%6d  %s → %s%s" % [player.tick, from if from != &"" else &"-", state_name,
		(" (%s)" % reason) if reason != "" else ""]
	history.push_front(line)
	if history.size() > HISTORY_SIZE:
		history.resize(HISTORY_SIZE)
	if log_transitions:
		print("[SM] ", line)
	current.enter(from, data)
	transitioned.emit(from, state_name, reason)
	GameEvents.state_changed.emit(player, from, state_name, reason)
