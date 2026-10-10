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


func test_gate_low_wall_blocks_walking_through() -> void:
	# Passagem na diagonal (+X, -Z): o muro baixo fecha a entrada andando.
	var dir := Vector3(1, 0, -1).normalized()
	player.respawn(Transform3D(Basis(), dir * 20.0 + Vector3.UP * 0.05))
	d.look_yaw = PI * 0.75  # olhando para o centro
	d.step(120, Vector2(0, 1))
	var r := Vector2(player.global_position.x, player.global_position.z).length()
	assert_gt(r, 16.9, "parou no muro baixo (r = %.2f)" % r)
	assert_true(player.is_on_floor())


func test_wall_collision_is_smooth_convex_blocks() -> void:
	var shapes := arena.get_node("Platform").find_children("*", "CollisionShape3D", true, false)
	assert_gt(shapes.size(), 100)
	for shape: CollisionShape3D in shapes:
		assert_true(shape.shape is ConvexPolygonShape3D, "colisão convexa (sem emendas de triângulos)")


func test_sliding_along_the_curved_wall_does_not_snag() -> void:
	# Passarela encostada no muro (r = 17,5), andando na tangente e empurrando para dentro: desliza.
	player.respawn(Transform3D(Basis(), Vector3(0, 0.05, 17.5)))
	d.look_yaw = PI * 0.5 - 0.35  # para -X, um pouco virado contra o muro
	d.step(20, Vector2(0, 1))
	var slowest := INF
	for i in 60:
		d.step(1, Vector2(0, 1))
		slowest = minf(slowest, player.get_horizontal_speed())
	assert_gt(slowest, 3.0, "não engancha nas emendas do muro (mínimo %.2f m/s)" % slowest)
