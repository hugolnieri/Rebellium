extends GutTest
## Bunny hop: pular dentro de 3 ticks após aterrissar preserva a velocidade horizontal.

const Driver = preload("res://tests/helpers/player_driver.gd")
const FWD := Vector2(0, 1)

var d: Driver


func before_each() -> void:
	d = Driver.new()
	# Mecânica do bunny hop isolada: o pulo do sprint mantém os 10 m/s (com a regra padrão
	# "pulo volta a andar", a velocidade alta vem da corrida no ar).
	d.setup(self, Vector3(0, 0, 0), {"jump_resets_to_walk_speed": false})
	d.add_block(Vector3(0, -0.5, 0), Vector3(400, 1, 400))
	await d.ready_physics(self)
	d.step(10)
	# Ganha 10 m/s com sprint (toque duplo em W), pula e solta o W no ar:
	# sem input, no chão a velocidade cai, então só o bunny hop preserva os 10 m/s.
	d.step(40, FWD, true)
	d.press_jump()
	d.step(1, FWD, true)


## Avança até aterrissar e devolve a velocidade horizontal no impacto.
func _land() -> float:
	var ticks := d.step_until(func() -> bool: return d.state() == &"Land", 120)
	assert_gt(ticks, 0, "aterrissou")
	return WallJumpMath.horizontal(d.player.pre_slide_velocity).length()


func _jump_speed_when_pressing_at(ticks_after_land: int) -> float:
	var landing_speed := _land()
	assert_almost_eq(landing_speed, 10.0, 0.1)
	d.step(ticks_after_land)
	d.press_jump()
	d.step(1)
	assert_eq(d.state(), &"Jump")
	return d.player.get_horizontal_speed()


func test_jump_on_first_tick_after_landing_preserves_speed() -> void:
	var speed := _jump_speed_when_pressing_at(0)
	assert_almost_eq(speed, 10.0, 0.05)
	assert_has(d.techniques, MovementRules.TECH_BUNNY_HOP)


func test_jump_on_third_tick_still_inside_window() -> void:
	# Aterrissou no tick L; apertos em L+1 e L+2 ainda estão na janela de 3 ticks (L, L+1, L+2).
	var speed := _jump_speed_when_pressing_at(1)
	assert_almost_eq(speed, 10.0, 0.05)
	assert_has(d.techniques, MovementRules.TECH_BUNNY_HOP)


func test_jump_after_window_loses_speed() -> void:
	var speed := _jump_speed_when_pressing_at(4)
	assert_lte(speed, 6.0 + 0.01, "fora da janela: velocidade limitada ao chão")
	assert_does_not_have(d.techniques, MovementRules.TECH_BUNNY_HOP)


func test_press_before_landing_is_not_a_bunny_hop() -> void:
	d.step_until(func() -> bool:
		return d.player.velocity.y < 0.0 and d.player.global_position.y < 0.5, 120)
	d.press_jump()  # buffer: apertou ~3 ticks antes de tocar o chão
	_land()
	assert_lt(d.player.current_input.jump_pressed_tick, d.player.land_tick)
	d.step(2)
	assert_eq(d.state(), &"Jump", "o buffer ainda gera um pulo normal")
	assert_does_not_have(d.techniques, MovementRules.TECH_BUNNY_HOP)
	assert_lte(d.player.get_horizontal_speed(), 6.0 + 0.01)


func test_window_size_comes_from_config() -> void:
	d.player.config.bunny_hop_window_ticks = 8
	var speed := _jump_speed_when_pressing_at(5)
	assert_almost_eq(speed, 10.0, 0.05)
	assert_has(d.techniques, MovementRules.TECH_BUNNY_HOP)
