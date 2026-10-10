extends GutTest
## Arena flutuante (modelo do Blender): colisão do chão, muro interno serve para wall jump e queda
## da plataforma volta ao spawn.

const ARENA: PackedScene = preload("res://scenes/arenas/SkyArena.tscn")
const Driver = preload("res://tests/helpers/player_driver.gd")

var arena: Node3D
var player: Player
var d: Driver


func before_each() -> void:
	arena = ARENA.instantiate() as Node3D
	player = arena.get_node("Player") as Player
	player.external_control = true
	add_child_autofree(arena)
	d = Driver.new()
	d.attach(player, arena)
	await d.ready_physics(self)
	await wait_physics_frames(2)
	d.step(20)


func test_player_stands_on_the_platform_deck() -> void:
	assert_true(player.is_on_floor(), "pisa no chão gerado pelo Blender")
	assert_almost_eq(player.global_position.y, 0.0, 0.1)


func test_inner_wall_allows_wall_jump() -> void:
	# Da passarela (z = 21) correndo para o centro, o muro interno fica em z = 17.
	d.step_until(func() -> bool: return player.global_position.z < 19.0, 60, Vector2(0, 1))
	d.press_jump()
	d.step(1, Vector2(0, 1))
	assert_gt(d.step_until(func() -> bool: return player.wall_sensor.has_contact, 90, Vector2(0, 1)), 0,
		"encostou no muro interno")
	d.press_jump()
	d.step(1)
	assert_eq(player.get_state_name(), &"WallJump")


func test_falling_off_the_platform_respawns() -> void:
	player.respawn(Transform3D(Basis(), Vector3(40, -25, 0)))
	await wait_physics_frames(3)
	assert_almost_eq(player.global_position.z, 21.0, 0.2, "voltou ao spawn depois de cair")
