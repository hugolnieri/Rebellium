extends RefCounted
## Ajudante de testes de integração: monta um mundo greybox, cria o Player com
## controle externo e o dirige tick a tick com PlayerInput sintético (sem `Input`).

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/Player.tscn")
const DT: float = 1.0 / 60.0

var player: Player
var world: Node3D
var look_yaw: float = 0.0
var jump_pressed_tick: int = PlayerInput.NEVER
var dodge_pressed_tick: int = PlayerInput.NEVER
var weapon_swap_pressed_tick: int = PlayerInput.NEVER
var weapon_swap_slot: int = 0
## Técnicas emitidas por GameEvents durante o teste (em ordem).
var techniques: Array[StringName] = []
var wall_jumps: Array[Dictionary] = []


## Cria o mundo como filho de `test` (liberado automaticamente). Chame `await ready_physics()` depois.
func setup(test: GutTest, spawn: Vector3, config_overrides: Dictionary = {}) -> void:
	world = Node3D.new()
	test.add_child_autofree(world)
	player = PLAYER_SCENE.instantiate() as Player
	player.external_control = true
	player.config = player.config.duplicate() as MovementConfig
	for key: String in config_overrides:
		player.config.set(key, config_overrides[key])
	player.position = spawn
	world.add_child(player)
	GameEvents.technique_executed.connect(_on_technique)
	GameEvents.wall_jump_executed.connect(_on_wall_jump)
	world.tree_exiting.connect(_disconnect)


## Usa um Player que já está numa cena (ex.: o percurso de treino).
func attach(existing_player: Player, existing_world: Node3D) -> void:
	player = existing_player
	world = existing_world
	GameEvents.technique_executed.connect(_on_technique)
	GameEvents.wall_jump_executed.connect(_on_wall_jump)
	world.tree_exiting.connect(_disconnect)


func _on_technique(who: Node, technique: StringName, _data: Dictionary) -> void:
	if who == player:
		techniques.append(technique)


func _on_wall_jump(who: Node, data: Dictionary) -> void:
	if who == player:
		wall_jumps.append(data)


func _disconnect() -> void:
	GameEvents.technique_executed.disconnect(_on_technique)
	GameEvents.wall_jump_executed.disconnect(_on_wall_jump)


## Adiciona um bloco estático (centro, tamanho).
func add_block(center: Vector3, size: Vector3) -> GreyboxBlock:
	var block := GreyboxBlock.new()
	block.size = size
	block.position = center
	world.add_child(block)
	return block


## Espera o servidor de física registrar os corpos recém-criados.
func ready_physics(test: GutTest) -> void:
	await test.wait_physics_frames(3)


func press_jump() -> void:
	jump_pressed_tick = player.tick + 1


func press_dodge() -> void:
	dodge_pressed_tick = player.tick + 1


func press_weapon_swap(slot: int = 1) -> void:
	weapon_swap_pressed_tick = player.tick + 1
	weapon_swap_slot = slot


func make_input(move: Vector2, sprint: bool) -> PlayerInput:
	var input := PlayerInput.new()
	input.tick = player.tick + 1
	input.move = move
	input.sprint_held = sprint
	input.look_yaw = look_yaw
	input.jump_held = jump_pressed_tick == input.tick
	input.jump_pressed_tick = jump_pressed_tick
	input.dodge_pressed_tick = dodge_pressed_tick
	input.weapon_swap_pressed_tick = weapon_swap_pressed_tick
	input.weapon_swap_slot = weapon_swap_slot
	return input


## Avança `ticks` ticks com o mesmo input de movimento.
func step(ticks: int = 1, move: Vector2 = Vector2.ZERO, sprint: bool = false) -> void:
	for i in ticks:
		player.step(make_input(move, sprint), DT)


## Avança até `predicate.call()` ser true ou estourar `max_ticks`. Retorna ticks usados (-1 se estourou).
func step_until(predicate: Callable, max_ticks: int, move: Vector2 = Vector2.ZERO,
		sprint: bool = false) -> int:
	for i in max_ticks:
		player.step(make_input(move, sprint), DT)
		if predicate.call():
			return i + 1
	return -1


func state() -> StringName:
	return player.get_state_name()


## Avança até tocar a parede `block` (retorna ticks, -1 se não tocou).
func step_until_wall(block: Node, max_ticks: int, move: Vector2 = Vector2.ZERO) -> int:
	var id := block.get_instance_id()
	return step_until(func() -> bool:
		return player.wall_sensor.has_contact and player.wall_sensor.collider_id == id \
			and player.wall_sensor.last_contact_tick == player.tick, max_ticks, move)
