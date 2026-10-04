extends PlayerState
## Subindo após um pulo (do chão, coyote, bunny hop ou fim de wall jump).


func physics_update(input: PlayerInput, delta: float) -> void:
	if player.try_wall_jump(input):
		return
	if cfg().dodge_allow_in_air and player.try_dodge(input):
		return
	player.apply_air_movement(input, delta)


func post_move(_input: PlayerInput) -> void:
	if player.is_on_floor() and player.velocity.y <= 0.0:
		machine.transition_to(&"Land", "tocou o chão")
	elif player.velocity.y <= 0.0:
		machine.transition_to(&"Fall", "ápice")
