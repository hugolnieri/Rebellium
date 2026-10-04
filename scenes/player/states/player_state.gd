class_name PlayerState
extends Node
## Base dos estados do jogador. Cada estado:
##  - `physics_update`: antes do move_and_slide (define velocidade, pode transicionar).
##  - `post_move`: depois do move_and_slide (checa chão/parede, pode transicionar).
## Use sempre `machine.transition_to(...)` para trocar de estado.

var player: Player
var machine: StateMachine


func enter(_from: StringName, _data: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_input: PlayerInput, _delta: float) -> void:
	pass


func post_move(_input: PlayerInput) -> void:
	pass


## Conveniência: acesso à config de movimento.
func cfg() -> MovementConfig:
	return player.config
