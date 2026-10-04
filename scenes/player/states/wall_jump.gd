extends PlayerState
## Lançamento do wall jump: mantém a direção do lançamento sem controle aéreo por
## `wall_jump_lock_time`. No reverse wall jump o empurrão para frente continua até
## passar do topo da parede (senão a colisão comeria a velocidade horizontal).
## Cancel: troca de arma (1/2) até `cancel_window_ticks` do wall jump desfaz o lançamento.

var _launch_horizontal: Vector3 = Vector3.ZERO
var _hold_until_clear: bool = false


func enter(_from: StringName, data: Dictionary) -> void:
	_launch_horizontal = WallJumpMath.horizontal(player.velocity)
	_hold_until_clear = data.get("technique", &"") == MovementRules.TECH_REVERSE


func physics_update(input: PlayerInput, delta: float) -> void:
	if player.consume_cancel_press(input):
		player.apply_wall_jump_cancel()
		return
	var locked := machine.ticks_in_state() < player.secs_to_ticks(cfg().wall_jump_lock_time)
	var climbing := _hold_until_clear and player.wall_sensor.has_contact and player.velocity.y > 0.0
	if locked or climbing:
		player.velocity.x = _launch_horizontal.x
		player.velocity.z = _launch_horizontal.z
		player.apply_gravity(delta)
		return
	player.apply_air_movement(input, delta)
	machine.transition_to(&"Jump" if player.velocity.y > 0.0 else &"Fall", "fim do lançamento")


func post_move(_input: PlayerInput) -> void:
	if player.is_on_floor() and player.velocity.y <= 0.0:
		machine.transition_to(&"Land", "tocou o chão")
