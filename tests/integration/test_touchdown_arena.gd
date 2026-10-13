extends GutTest
## Fluxo real do modo: chão, núcleo, entrega, queda e fim da partida.

const ARENA: PackedScene = preload("res://scenes/arenas/TouchdownArena.tscn")

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
	assert_almost_eq(player.global_position.x, -33.0, 0.2)
	var shapes := arena.get_node("Platform").find_children("*", "CollisionShape3D", true, false)
	assert_gt(shapes.size(), 10, "o modelo importa pisos e obstáculos como colisores")
	for shape: CollisionShape3D in shapes:
		assert_true(shape.shape is ConvexPolygonShape3D, "colisões da arena são convexas")
	var space := arena.get_world_3d().direct_space_state
	for point: Vector2 in [Vector2(-33, 0), Vector2(-20, 0), Vector2(-10, 0),
			Vector2(0, 0), Vector2(10, 0), Vector2(20, 0), Vector2(33, 0),
			Vector2(-25, -6), Vector2(0, -12), Vector2(25, -6),
			Vector2(-25, 6), Vector2(0, 12), Vector2(25, 6)]:
		var from := Vector3(point.x, 5, point.y)
		var ray := PhysicsRayQueryParameters3D.create(from, Vector3(point.x, -3, point.y))
		var hit := space.intersect_ray(ray)
		assert_false(hit.is_empty(), "há piso nas três rotas em %s" % point)


func test_goal_requires_ball_from_center() -> void:
	player.respawn(Transform3D(Basis(), Vector3(35, 0.12, 0)))
	await wait_physics_frames(3)
	assert_eq(arena.score, 0, "a base sozinha não pontua")
	player.respawn(Transform3D(Basis(), Vector3(0, 0.12, 0)))
	await wait_physics_frames(3)
	assert_true(arena.carrying, "pegou o núcleo ao tocar o centro")
	assert_false(arena.ball.visible)
	player.respawn(Transform3D(Basis(), Vector3(35, 0.12, 0)))
	await wait_physics_frames(3)
	assert_eq(arena.score, 1, "entregou na base vermelha")
	assert_false(arena.carrying)
	assert_almost_eq(player.global_position.x, -33.0, 0.2, "nova rodada começa na base azul")


func test_fall_drops_ball_and_returns_player() -> void:
	arena.config.ball_reset_delay = 0.05
	player.respawn(Transform3D(Basis(), Vector3(0, 0.12, 0)))
	await wait_physics_frames(3)
	assert_true(arena.carrying)
	player.global_position = Vector3(0, -20, 0)
	await wait_physics_frames(3)
	assert_false(arena.carrying)
	assert_almost_eq(player.global_position.x, -33.0, 0.2)
	await wait_physics_frames(6)
	assert_true(arena.ball_available, "núcleo reaparece no meio após a queda")


func test_score_limit_ends_and_reset_starts_new_match() -> void:
	arena.config.score_limit = 1
	player.respawn(Transform3D(Basis(), Vector3(0, 0.12, 0)))
	await wait_physics_frames(3)
	player.respawn(Transform3D(Basis(), Vector3(35, 0.12, 0)))
	await wait_physics_frames(3)
	assert_eq(arena.score, 1)
	assert_true(arena.finished)
	arena.reset_match()
	assert_eq(arena.score, 0)
	assert_false(arena.finished)
	assert_true(arena.ball_available)
