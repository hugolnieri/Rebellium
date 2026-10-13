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
	assert_almost_eq(player.global_position.x, -38.0, 0.2)
	var shapes := arena.get_node("Platform").find_children("*", "CollisionShape3D", true, false)
	assert_gt(shapes.size(), 10, "o modelo importa pisos e obstáculos como colisores")
	for shape: CollisionShape3D in shapes:
		assert_true(shape.shape is ConvexPolygonShape3D, "colisões da arena são convexas")
	var space := arena.get_world_3d().direct_space_state
	for point: Vector2 in [Vector2(-38, 0), Vector2(-29, 0), Vector2(-17, 0),
			Vector2(0, 0), Vector2(17, 0), Vector2(29, 0), Vector2(38, 0),
			Vector2(-38, 14), Vector2(38, 14),
			Vector2(0, -10), Vector2(0, 10)]:
		var from := Vector3(point.x, 9, point.y)
		var ray := PhysicsRayQueryParameters3D.create(from, Vector3(point.x, -3, point.y))
		ray.exclude = [player.get_rid()]
		var hit := space.intersect_ray(ray)
		assert_false(hit.is_empty(), "há piso em %s" % point)
	for sample: Vector3 in [Vector3(-38, 0, 0), Vector3(-17, 1.55, 0),
			Vector3(0, 2.4, 0), Vector3(17, 1.55, 0),
			Vector3(38, 0, 0), Vector3(38, 2.4, 14)]:
		var ray := PhysicsRayQueryParameters3D.create(
			Vector3(sample.x, 9, sample.z), Vector3(sample.x, -3, sample.z))
		ray.exclude = [player.get_rid()]
		var hit := space.intersect_ray(ray)
		assert_almost_eq((hit.position as Vector3).y, sample.y, 0.25,
			"spawn baixo, escada ascendente e estação/gol elevados em %s" % sample)


func test_spawn_ramp_and_both_stairs_are_walkable() -> void:
	var d: Driver = Driver.new()
	d.attach(player, arena)
	d.look_yaw = -PI / 2.0
	var reached_station: int = d.step_until(
		func() -> bool: return player.global_position.x > -4.0,
		650, Vector2(0, 1))
	assert_gt(reached_station, 0, "da base azul pela rampa e escada até a estação")
	assert_gt(player.global_position.y, 2.0)
	var reached_enemy_spawn: int = d.step_until(
		func() -> bool: return player.global_position.x > 37.0,
		650, Vector2(0, 1))
	assert_gt(reached_enemy_spawn, 0, "atravessa a estação e desce a escada inimiga")
	assert_lt(player.global_position.y, 0.4)
	d.look_yaw = PI
	var reached_goal: int = d.step_until(
		func() -> bool: return player.global_position.z > 13.0,
		350, Vector2(0, 1))
	assert_gt(reached_goal, 0, "da base vermelha pela escada lateral até o gol; posição %s" % player.global_position)
	assert_gt(player.global_position.y, 2.0)


func test_goal_requires_ball_from_center() -> void:
	player.respawn(Transform3D(Basis(), Vector3(38, 2.52, 14)))
	await wait_physics_frames(3)
	assert_eq(arena.score, 0, "a base sozinha não pontua")
	player.respawn(Transform3D(Basis(), Vector3(0, 2.52, 0)))
	await wait_physics_frames(3)
	assert_true(arena.carrying, "pegou o núcleo ao tocar o centro")
	assert_false(arena.ball.visible)
	player.respawn(Transform3D(Basis(), Vector3(38, 2.52, 14)))
	await wait_physics_frames(3)
	assert_eq(arena.score, 1, "entregou na base vermelha")
	assert_false(arena.carrying)
	assert_almost_eq(player.global_position.x, -38.0, 0.2, "nova rodada começa na base azul")


func test_fall_drops_ball_and_returns_player() -> void:
	arena.config.ball_reset_delay = 0.05
	player.respawn(Transform3D(Basis(), Vector3(0, 2.52, 0)))
	await wait_physics_frames(3)
	assert_true(arena.carrying)
	player.global_position = Vector3(0, -20, 0)
	await wait_physics_frames(3)
	assert_false(arena.carrying)
	assert_almost_eq(player.global_position.x, -38.0, 0.2)
	await wait_physics_frames(6)
	assert_true(arena.ball_available, "núcleo reaparece no meio após a queda")


func test_score_limit_ends_and_reset_starts_new_match() -> void:
	arena.config.score_limit = 1
	player.respawn(Transform3D(Basis(), Vector3(0, 2.52, 0)))
	await wait_physics_frames(3)
	player.respawn(Transform3D(Basis(), Vector3(38, 2.52, 14)))
	await wait_physics_frames(3)
	assert_eq(arena.score, 1)
	assert_true(arena.finished)
	arena.reset_match()
	assert_eq(arena.score, 0)
	assert_false(arena.finished)
	assert_true(arena.ball_available)
