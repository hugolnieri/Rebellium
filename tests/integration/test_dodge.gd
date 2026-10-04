extends GutTest
## Dodge: custo, invencibilidade, 8 direções, bloqueio com SP zerado e dodge cancel.

const Driver = preload("res://tests/helpers/player_driver.gd")

var d: Driver


func before_each() -> void:
	d = Driver.new()
	d.setup(self, Vector3(0, 0, 0))
	d.add_block(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	await d.ready_physics(self)
	d.step(10)


func test_dodge_costs_20_sp_and_moves_in_input_direction() -> void:
	var start := d.player.global_position
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_almost_eq(d.player.sp.current, 80.0, 0.01)
	d.step(20)
	var moved := d.player.global_position - start
	assert_gt(moved.x, 2.5, "passo rápido para a direita")
	assert_almost_eq(moved.z, 0.0, 0.01)


func test_invulnerability_lasts_0_15_s() -> void:
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	var invulnerable_ticks := 1 if d.player.is_invulnerable else 0
	for i in 30:
		d.step(1)
		if d.player.is_invulnerable:
			invulnerable_ticks += 1
	assert_eq(invulnerable_ticks, 9, "0,15 s a 60 ticks")
	assert_false(d.player.is_invulnerable)


func test_dash_without_direction_does_nothing_by_default() -> void:
	d.press_dodge()
	d.step(5)
	assert_ne(d.state(), &"Dodge", "Shift sozinho não dá dash")
	assert_eq(d.player.sp.current, 100.0)


func test_shift_then_direction_inside_buffer_dashes() -> void:
	d.press_dodge()
	d.step(2)
	d.step(1, Vector2(-1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_lt(d.player.velocity.x, -10.0, "dash para a esquerda (Shift + A)")


func test_neutral_dodge_goes_backward_relative_to_camera() -> void:
	d.player.config.dodge_requires_direction = false
	d.press_dodge()
	d.step(5)
	assert_gt(d.player.velocity.z, 10.0, "sem direção: passo para trás (+Z com câmera olhando -Z)")


func test_no_dodge_when_exhausted() -> void:
	d.player.sp.current = 1.0
	d.player.sp.drain(1.0)
	assert_true(d.player.sp.exhausted)
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_ne(d.state(), &"Dodge")


func test_dodge_cancels_land_recovery() -> void:
	d.press_jump()
	d.step(1)
	d.step_until(func() -> bool: return d.state() == &"Land", 120)
	d.press_dodge()
	d.step(1, Vector2(-1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_has(d.techniques, MovementRules.TECH_DODGE_CANCEL)


func test_dodge_cancels_its_own_recovery_but_not_the_dash() -> void:
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	d.press_dodge()
	d.step(1, Vector2(-1, 0))
	assert_almost_eq(d.player.sp.current, 80.0, 0.01, "durante o deslocamento não cancela")
	d.step(d.player.secs_to_ticks(d.player.config.dodge_duration) + 1)
	assert_true(d.player.state_machine.current.is_recovery())
	d.press_dodge()
	d.step(1, Vector2(-1, 0))
	assert_has(d.techniques, MovementRules.TECH_DODGE_CANCEL)
	assert_almost_eq(d.player.sp.current, 60.0, 0.01)
	assert_lt(d.player.velocity.x, -10.0, "novo dodge para a esquerda")


func test_dodge_returns_to_ground_state() -> void:
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	d.step(40)
	assert_eq(d.state(), &"Idle")


func test_air_dash_once_per_jump_flat_and_refilled_on_landing() -> void:
	d.press_jump()
	d.step(8)
	var y_before := d.player.global_position.y
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_eq(d.state(), &"Dodge")
	assert_almost_eq(d.player.velocity.y, 0.0, 0.001, "dash no ar é reto")
	assert_almost_eq(d.player.sp.current, 80.0, 0.01)
	d.step(5, Vector2(1, 0))
	assert_almost_eq(d.player.global_position.y, y_before, 0.05, "não caiu durante o dash")
	d.step(6)
	assert_ne(d.state(), &"Dodge")
	assert_false(d.player.is_on_floor())
	d.press_dodge()
	d.step(1, Vector2(-1, 0))
	assert_ne(d.state(), &"Dodge", "só um dash por pulo")
	d.step_until(func() -> bool: return d.player.is_on_floor(), 120)
	d.step(10)
	d.press_jump()
	d.step(6)
	d.press_dodge()
	d.step(1, Vector2(-1, 0))
	assert_eq(d.state(), &"Dodge", "recarregou ao aterrissar")


func test_air_dash_keeps_momentum_and_returns_to_fall() -> void:
	d.press_jump()
	d.step(20)
	d.press_dodge()
	d.step(1, Vector2(0, 1))
	d.step(d.player.secs_to_ticks(d.player.config.dodge_duration) + 1)
	assert_true(d.state() == &"Fall" or d.state() == &"Jump")
	assert_almost_eq(d.player.get_horizontal_speed(), d.player.config.air_dodge_exit_speed, 0.5)


func test_air_dash_can_be_disabled() -> void:
	d.player.config.dodge_allow_in_air = false
	d.press_jump()
	d.step(8)
	d.press_dodge()
	d.step(1, Vector2(1, 0))
	assert_ne(d.state(), &"Dodge")
