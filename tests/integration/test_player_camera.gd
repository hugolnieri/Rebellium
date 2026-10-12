extends GutTest
## Câmera sobre o ombro: olha sempre para o yaw do InputReader (o mesmo que orienta o movimento), qualquer que seja a
## rotação que a cena dá ao Player ao instanciá-lo (o `top_level` da câmera guardava essa rotação e a vista ficava torta).

const Driver = preload("res://tests/helpers/player_driver.gd")

var d: Driver


func before_each() -> void:
	d = Driver.new()
	d.setup(self, Vector3(0, 0.05, 0))
	d.add_block(Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	await d.ready_physics(self)


## Para onde a câmera olha (yaw do mundo; frente = (−sin yaw, −cos yaw)).
func _view_yaw(player: Player) -> float:
	var forward := -(player.get_node("PlayerCamera") as PlayerCamera).camera.global_basis.z
	return atan2(-forward.x, -forward.z)


func _assert_views(player: Player, look_yaw: float, msg: String) -> void:
	player.input_reader.look_yaw = look_yaw
	await wait_process_frames(2)
	assert_almost_eq(wrapf(_view_yaw(player) - look_yaw, -PI, PI), 0.0, 0.001, msg)


func test_camera_looks_along_the_look_yaw() -> void:
	await _assert_views(d.player, 0.7, "a câmera olha para o yaw do InputReader")


func test_camera_ignores_the_rotation_a_scene_gives_the_player() -> void:
	var rotated := Driver.PLAYER_SCENE.instantiate() as Player
	rotated.external_control = true
	rotated.transform = Transform3D(Basis(Vector3.UP, 0.8), Vector3(5.0, 0.05, 0.0))
	d.world.add_child(rotated)
	await d.ready_physics(self)
	await _assert_views(rotated, 0.3, "a rotação inicial do Player não entra na vista")


func test_camera_stays_aligned_after_respawning_with_a_rotated_spawn() -> void:
	d.player.respawn(Transform3D(Basis(Vector3.UP, 0.8), Vector3(0.0, 0.05, 0.0)))
	await _assert_views(d.player, 0.8, "depois do respawn girado a câmera continua alinhada ao look_yaw")
