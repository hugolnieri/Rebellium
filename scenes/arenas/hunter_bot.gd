class_name HunterBot
extends TrainingDummy
## Caçador: o bot vermelho da arena. Corpo do personagem animado com os clipes do Blender (idle, hurt, launched,
## knockdown, getup). Não ataca, só reage: golpes leves o fazem cambalear e deslizar; o golpe PESADO o arremessa
## (velocidade = recuo do golpe × `launch_velocity_scale`). Depois de cair, ficar deitado e levantar, ele volta ao
## spawn do caçador. A etiqueta mostra a distância do último arremesso, para comparar a força dos golpes.
## Os números ficam em `DummyConfig` (grupo "Arremesso") e no F2 (aba "Alvos").

enum Phase { IDLE, STAGGER, LAUNCHED, DOWN, GETUP }

## Altura do centro do corpo deitado (o de pé é `HIT_HEIGHT`).
const LYING_HIT_HEIGHT: float = 0.35
## Sondas de colisão (raios) em relação à origem do corpo, que é a "barriga" quando ele está deitado.
const PROBE_HEIGHT: float = 0.4
const CEILING_MARGIN: float = 0.5
## Se o jogador estiver a menos disto do spawn, o caçador espera para voltar (não nasce em cima dele).
const RETURN_CLEARANCE: float = 1.2
## Brilho ao reaparecer no spawn.
const RETURN_FLASH: float = 0.25

## Fase atual (lida também pelos testes).
var phase: Phase = Phase.IDLE
## Velocidade do corpo (m/s); só vale fora do IDLE.
var velocity: Vector3 = Vector3.ZERO

var _puppet: HeroPuppet
var _phase_time: float = 0.0
## Muda a cada trecho novo (inclusive um novo arremesso): o boneco mistura a pose anterior com a nova.
var _phase_serial: int = 0
var _flight_duration: float = 1.0
var _launch_origin: Vector3 = Vector3.ZERO
var _launch_distance: float = 0.0


func _ready() -> void:
	super()
	# Com sync_to_physics o nó desfaz a posição na hora e só vale após o próximo passo da física; o caçador não
	# empurra ninguém, então a posição dele vale direto (e dá para testar tick a tick).
	sync_to_physics = false
	_face_the_player.call_deferred()


func _physics_process(delta: float) -> void:
	super(delta)
	step(delta)


func get_hit_center() -> Vector3:
	var height := HIT_HEIGHT
	match phase:
		Phase.LAUNCHED, Phase.DOWN:
			height = LYING_HIT_HEIGHT
		Phase.GETUP:
			var rise := smoothstep(0.0, 1.0, _phase_time / HeroClips.length_of(&"getup"))
			height = lerpf(LYING_HIT_HEIGHT, HIT_HEIGHT, rise)
	return global_position + Vector3.UP * height


func reset_target() -> void:
	super()
	_launch_distance = 0.0
	_come_home(true)


## Avança a simulação do caçador (movimento, fases e animação). Os testes chamam isto direto.
func step(delta: float) -> void:
	_phase_time += delta
	if global_position.y < config.fall_respawn_height:
		_come_home(true)
		return
	match phase:
		Phase.STAGGER:
			_step_slide(delta)
			if _phase_time >= HeroClips.length_of(&"hurt") and velocity.length_squared() < 0.0001:
				_set_phase(Phase.IDLE)
		Phase.LAUNCHED:
			_step_flight(delta)
		Phase.DOWN:
			_step_slide(delta)
			_update_distance()
			if _phase_time >= HeroClips.length_of(&"knockdown") + config.knockdown_time:
				_set_phase(Phase.GETUP)
		Phase.GETUP:
			if _phase_time >= HeroClips.length_of(&"getup") + config.return_delay:
				_come_home()
	_animate(delta)


func _build_body() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)
	_puppet = HeroPuppet.new()
	_pivot.add_child(_puppet)
	_puppet.paint(_target_material)


func _label_text() -> String:
	var text := super()
	if _launch_distance > 0.0:
		text += "\nARREMESSO %s m" % ("%.1f" % _launch_distance).replace(".", ",")
	return text


## Golpe pesado arremessa; os outros só empurram (e só se ele estiver de pé).
func _react(info: Dictionary) -> void:
	if info.get("kind", &"") == CombatRules.KIND_HEAVY:
		_launch(info)
	elif phase == Phase.IDLE or phase == Phase.STAGGER:
		_stagger(info)


func _stagger(info: Dictionary) -> void:
	var knockback: Vector3 = info.get("knockback", Vector3.ZERO)
	velocity = Vector3(knockback.x, 0.0, knockback.z) * config.hit_slide_scale
	_face_attacker(info)
	_set_phase(Phase.STAGGER)


func _launch(info: Dictionary) -> void:
	var knockback: Vector3 = info.get("knockback", Vector3.ZERO)
	var scale := config.launch_velocity_scale
	var up := maxf(knockback.y * scale, config.launch_min_up_speed)
	velocity = Vector3(knockback.x, 0.0, knockback.z) * scale + Vector3.UP * up
	_flight_duration = maxf(2.0 * up / config.launch_gravity, 0.2)
	_launch_origin = global_position
	_launch_distance = 0.0
	_face_attacker(info)
	_set_phase(Phase.LAUNCHED)


## Voo balístico (o corpo é a "barriga para cima", cabeça na frente): bate em paredes (rebote), em tetos e no chão.
func _step_flight(delta: float) -> void:
	velocity.y -= config.launch_gravity * delta
	var origin := global_position
	var probe := origin + Vector3.UP * PROBE_HEIGHT
	var motion := velocity * delta
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	if flat.length() > 0.01:
		var wall := _ray(probe, probe + flat.normalized() * (flat.length() * delta + config.launch_wall_margin))
		if not wall.is_empty() and absf((wall.normal as Vector3).y) < 0.5:
			var normal := Vector3((wall.normal as Vector3).x, 0.0, (wall.normal as Vector3).z).normalized()
			flat = (flat - 2.0 * flat.dot(normal) * normal) * config.launch_wall_bounce
			velocity = Vector3(flat.x, velocity.y, flat.z)
			motion = Vector3(0.0, motion.y, 0.0)
	var next := origin + motion
	if velocity.y > 0.0:
		var ceiling := _ray(probe, next + Vector3.UP * (PROBE_HEIGHT + CEILING_MARGIN))
		if not ceiling.is_empty() and (ceiling.normal as Vector3).y < -0.5:
			velocity.y = 0.0
			next.y = origin.y
	else:
		var ground := _ray(probe, next + Vector3.DOWN * 0.05)
		if not ground.is_empty() and (ground.normal as Vector3).y > 0.5:
			global_position = ground.position
			_land()
			return
	global_position = next
	_update_distance()


func _land() -> void:
	velocity = Vector3(velocity.x, 0.0, velocity.z) * config.landing_speed_keep
	_set_phase(Phase.DOWN)
	_update_distance()


## Deslize no chão com atrito (cambaleando ou depois da queda); para na parede e segue o relevo do chão.
func _step_slide(delta: float) -> void:
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := maxf(flat.length() - config.slide_friction * delta, 0.0)
	if speed <= 0.0:
		velocity = Vector3.ZERO
		return
	flat = flat.normalized() * speed
	velocity = flat
	var probe := global_position + Vector3.UP * PROBE_HEIGHT
	var wall := _ray(probe, probe + flat * delta + flat.normalized() * config.launch_wall_margin)
	if not wall.is_empty() and absf((wall.normal as Vector3).y) < 0.5:
		velocity = Vector3.ZERO
		return
	global_position += flat * delta
	_snap_to_floor()


func _snap_to_floor() -> void:
	var ground := _ray(global_position + Vector3.UP * PROBE_HEIGHT, global_position + Vector3.DOWN)
	if not ground.is_empty():
		global_position = ground.position
		return
	# Sem chão embaixo (escorregou para fora): cai como num arremesso, já deitado.
	velocity.y = 0.0
	_flight_duration = 1.0
	_set_phase(Phase.LAUNCHED)
	_phase_time = _flight_duration


func _update_distance() -> void:
	var offset := global_position - _launch_origin
	_launch_distance = Vector2(offset.x, offset.z).length()


func _set_phase(next: Phase) -> void:
	phase = next
	_phase_time = 0.0
	_phase_serial += 1
	# De pé (ou cambaleando) ele bloqueia o jogador; voando, deitado ou levantando, não.
	_collision.set_deferred(&"disabled", next != Phase.IDLE and next != Phase.STAGGER)


func _animate(delta: float) -> void:
	match phase:
		Phase.IDLE:
			_puppet.show_clip(_phase_serial, &"idle", _phase_time / HeroClips.length_of(&"idle"), true, delta)
		Phase.STAGGER:
			_puppet.show_clip(_phase_serial, &"hurt", _phase_time / HeroClips.length_of(&"hurt"), false, delta)
		Phase.LAUNCHED:
			_puppet.show_clip(_phase_serial, &"launched", _phase_time / _flight_duration, false, delta)
		Phase.DOWN:
			_puppet.show_clip(_phase_serial, &"knockdown", _phase_time / HeroClips.length_of(&"knockdown"), false,
				delta)
		Phase.GETUP:
			_puppet.show_clip(_phase_serial, &"getup", _phase_time / HeroClips.length_of(&"getup"), false, delta)


## Volta ao spawn (espera se o jogador estiver em cima, a não ser que `force`).
func _come_home(force: bool = false) -> void:
	if not force and _player_in_the_way():
		return
	global_position = _home
	velocity = Vector3.ZERO
	_set_phase(Phase.IDLE)
	_face_the_player()
	_flash_left = RETURN_FLASH


func _player_in_the_way() -> bool:
	var player := get_tree().get_first_node_in_group(&"local_player") as Node3D
	if player == null:
		return false
	var offset := player.global_position - _home
	return Vector2(offset.x, offset.z).length() < RETURN_CLEARANCE


func _face_attacker(info: Dictionary) -> void:
	var attacker: Variant = info.get("attacker")
	if attacker is Node3D:
		_face_toward((attacker as Node3D).global_position)


func _face_the_player() -> void:
	var player := get_tree().get_first_node_in_group(&"local_player") as Node3D
	if player != null:
		_face_toward(player.global_position)


## O boneco olha para o ponto (o "para frente" do herói é −Z).
func _face_toward(point: Vector3) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length() > 0.01 and _puppet != null:
		_puppet.rotation.y = atan2(-to.x, -to.z)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var exclude: Array[RID] = [get_rid()]
	for node in get_tree().get_nodes_in_group(&"local_player"):
		if node is CollisionObject3D:
			exclude.append((node as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, exclude)
	return get_world_3d().direct_space_state.intersect_ray(query)
