extends GutTest
## Pular logo após aterrissar é um pulo normal, sem técnica nem velocidade preservada.

const Driver = preload("res://tests/helpers/player_driver.gd")
const FWD := Vector2(0, 1)
var d: Driver

func before_each() -> void:
	d = Driver.new()
	d.setup(self, Vector3.ZERO, {"jump_resets_to_walk_speed": false})
	d.add_block(Vector3(0, -0.5, 0), Vector3(400, 1, 400))
	await d.ready_physics(self)
	d.step(10)
	d.step(40, FWD, true)
	d.press_jump()
	d.step(1, FWD, true)

func _land() -> void:
	assert_gt(d.step_until(func() -> bool: return d.state() == &"Land", 120), 0)

func test_immediate_jump_after_landing_uses_ground_speed() -> void:
	_land()
	d.press_jump()
	d.step(1)
	assert_eq(d.state(), &"Jump")
	assert_lte(d.player.get_horizontal_speed(), d.player.get_walk_speed() + 0.01)
	assert_true(d.techniques.is_empty(), "pulo do chão não gera técnica")

func test_landing_no_longer_holds_air_speed() -> void:
	_land()
	d.step(2)
	assert_lt(d.player.get_horizontal_speed(), 10.0)
	assert_true(d.techniques.is_empty())

func test_buffered_jump_before_landing_remains_normal() -> void:
	d.step_until(func() -> bool:
		return d.player.velocity.y < 0.0 and d.player.global_position.y < 0.5, 120)
	d.press_jump()
	_land()
	d.step(2)
	assert_eq(d.state(), &"Jump")
	assert_lte(d.player.get_horizontal_speed(), d.player.get_walk_speed() + 0.01)
	assert_true(d.techniques.is_empty())
