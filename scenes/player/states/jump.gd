extends PlayerState
## Subindo após um pulo (do chão, coyote, bunny hop ou fim de wall jump).


func physics_update(input: PlayerInput, delta: float) -> void:
	player.apply_air_movement(input, delta)


func post_move(_input: PlayerInput) -> void:
	if player.is_on_floor() and player.velocity.y <= 0.0:
		machine.transition_to(&"Land", "tocou o chão")
	elif player.velocity.y <= 0.0:
		machine.transition_to(&"Fall", "ápice")
