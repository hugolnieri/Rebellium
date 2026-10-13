extends GutTest
## Fluxo real do modo: chão, núcleo, entrega, queda e fim da partida.

const ARENA: PackedScene = preload("res://scenes/arenas/TouchdownArena.tscn")
const Driver = preload("res://tests/helpers/player_driver.gd")

var arena: TouchdownArena
var player: Player


func before_each() -> void:
	arena = ARENA.instantiate() as TouchdownArena
	player = arena.get_node("Player") as Player
	player.external_control = true
	arena.config = arena.config.duplicate() as TouchdownConfig
	add_child_autofree(arena)
	await wait_physics_frames(3)


func test_spawn_and_blender_collisions() -> void:
	assert_almost_eq(player.global_position.x, -36.0, 0.2)
	var shapes := arena.get_node("Platform").find_children("*", "CollisionShape3D", true, false)
	assert_gt(shapes.size(), 10, "o modelo importa pisos e obstáculos como colisores")
	for shape: CollisionShape3D in shapes:
		assert_true(shape.shape is ConvexPolygonShape3D, "colisões da arena são convexas")
	var space := arena.get_world_3d().direct_space_state
	for point: Vector2 in [Vector2(-36, 0), Vector2(-20, 4.5),
			Vector2(0, 0), Vector2(20, 0), Vector2(36, 0),
			Vector2(-39, 14), Vector2(39, -14),
			Vector2(-18, 22), Vector2(18, -22)]:
		var from := Vector3(point.x, 11.5, point.y)
		var ray := PhysicsRayQueryParameters3D.create(from, Vector3(point.x, -3, point.y))
		ray.exclude = [player.get_rid()]
		var hit := space.intersect_ray(ray)
		assert_false(hit.is_empty(), "há piso em %s" % point)
	for sample: Vector3 in [Vector3(-36, 8, 0),
			Vector3(0, 0, 0),
			Vector3(36, 8, 0), Vector3(39, 9.4, -14),
			Vector3(0, 8, 0)]:
		var ray := PhysicsRayQueryParameters3D.create(
			Vector3(sample.x, sample.y + 1.5, sample.z),
			Vector3(sample.x, -3, sample.z))
		ray.exclude = [player.get_rid()]
		var hit := space.intersect_ray(ray)
		assert_almost_eq((hit.position as Vector3).y, sample.y, 0.25,
			"spawn alto, escada descendente, estação baixa e gol elevado em %s" % sample)
	for x: int in [-20, 20]:
		var ray := PhysicsRayQueryParameters3D.create(
			Vector3(x, 7, -signf(float(x)) * 4.5),
			Vector3(x, -3, -signf(float(x)) * 4.5))
		ray.exclude = [player.get_rid()]
		var hit := space.intersect_ray(ray)
		assert_gt((hit.position as Vector3).y, 3.0, "meio da escada fica acima da estação")
		assert_lt((hit.position as Vector3).y, 6.0, "meio da escada fica abaixo do spawn")


func test_high_spawn_station_and_enemy_goal_are_walkable() -> void:
	var d: Driver = Driver.new()
	d.attach(player, arena)
	player.respawn(Transform3D(Basis(), Vector3(-27, 8.12, 6)))
	await wait_physics_frames(2)
	d.look_yaw = -1.36
	var reached_station: int = d.step_until(
		func() -> bool: return player.global_position.x > -10.0,
		500, Vector2(0, 1))
	assert_gt(reached_station, 0, "desce do saguão azul à estação")
	assert_lt(player.global_position.y, 0.6)
	player.respawn(Transform3D(Basis(), Vector3(-24, 8.12, 0)))
	await wait_physics_frames(2)
	d.look_yaw = -PI / 2.0
	var crossed_bridge: int = d.step_until(
		func() -> bool: return player.global_position.x > 24.0,
		650, Vector2(0, 1))
	assert_gt(crossed_bridge, 0, "a ponte alta liga os dois terminais")
	assert_gt(player.global_position.y, 7.5)
	player.respawn(Transform3D(Basis(), Vector3(13, 0.12, -3)))
	await wait_physics_frames(2)
	d.look_yaw = -1.36
	var reached_enemy_spawn: int = d.step_until(
		func() -> bool: return player.global_position.x > 27.5,
		500, Vector2(0, 1))
	assert_gt(reached_enemy_spawn, 0, "atravessa a estação e sobe ao saguão inimigo")
	assert_gt(player.global_position.y, 7.5)
	player.respawn(Transform3D(Basis(), Vector3(39, 8.12, -6)))
	await wait_physics_frames(2)
	d.look_yaw = 0.0
	var reached_goal: int = d.step_until(
		func() -> bool: return player.global_position.z < -13.0,
		350, Vector2(0, 1))
	assert_gt(reached_goal, 0, "da base vermelha pela escada lateral até o gol; posição %s" % player.global_position)
	assert_gt(player.global_position.y, 9.0)


func test_jump_from_spawn_skips_part_of_grand_stairs() -> void:
	var d: Driver = Driver.new()
	d.attach(player, arena)
	player.respawn(Transform3D(Basis(), Vector3(-28.5, 8.12, 6)))
	await wait_physics_frames(2)
	d.look_yaw = -1.36
	d.press_jump()
	d.step(20, Vector2(0, 1), true)
	assert_gt(player.global_position.x, -27.0, "avança para além da borda do spawn")
	assert_gt(player.global_position.y, 8.0, "passa pelo ar acima da escadaria")
	var reached_station: int = d.step_until(
		func() -> bool: return player.global_position.x > -12.5,
		450, Vector2(0, 1), true)
	assert_gt(reached_station, 0, "o salto aterrissa e permite chegar ao núcleo")


func test_goal_requires_ball_from_center() -> void:
	player.respawn(Transform3D(Basis(), Vector3(39, 9.52, -14)))
	await wait_physics_frames(3)
	assert_eq(arena.score, 0, "a base sozinha não pontua")
	player.respawn(Transform3D(Basis(), Vector3(0, 0.12, 0)))
	await wait_physics_frames(3)
	assert_true(arena.carrying, "pegou o núcleo ao tocar o centro")
	assert_false(arena.ball.visible)
	player.respawn(Transform3D(Basis(), Vector3(39, 9.52, -14)))
	await wait_physics_frames(3)
	assert_eq(arena.score, 1, "entregou na base vermelha")
	assert_false(arena.carrying)
	assert_almost_eq(player.global_position.x, -36.0, 0.2, "nova rodada começa no saguão azul")


func test_fall_drops_ball_and_returns_player() -> void:
	arena.config.ball_reset_delay = 0.05
	player.respawn(Transform3D(Basis(), Vector3(0, 0.12, 0)))
	await wait_physics_frames(3)
	assert_true(arena.carrying)
	player.global_position = Vector3(0, -20, 0)
	await wait_physics_frames(3)
	assert_false(arena.carrying)
	assert_almost_eq(player.global_position.x, -36.0, 0.2)
	await wait_physics_frames(6)
	assert_true(arena.ball_available, "núcleo reaparece no meio após a queda")


func test_score_limit_ends_and_reset_starts_new_match() -> void:
	arena.config.score_limit = 1
	player.respawn(Transform3D(Basis(), Vector3(0, 0.12, 0)))
	await wait_physics_frames(3)
	player.respawn(Transform3D(Basis(), Vector3(39, 9.52, -14)))
	await wait_physics_frames(3)
	assert_eq(arena.score, 1)
	assert_true(arena.finished)
	arena.reset_match()
	assert_eq(arena.score, 0)
	assert_false(arena.finished)
	assert_true(arena.ball_available)
