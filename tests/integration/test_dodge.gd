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
	d.step(1)
	var invulnerable_ticks := 1 if d.player.is_invulnerable else 0
	for i in 30:
		d.step(1)
		if d.player.is_invulnerable:
			invulnerable_ticks += 1
	assert_eq(invulnerable_ticks, 9, "0,15 s a 60 ticks")
	assert_false(d.player.is_invulnerable)


func test_neutral_dodge_goes_backward_relative_to_camera() -> void:
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
	d.step(40)
	assert_eq(d.state(), &"Idle")
