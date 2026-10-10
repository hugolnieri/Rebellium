class_name WallSensor
extends Node3D
## Detecta paredes ao redor do jogador e lembra a ENTRADA no contato
## (velocidade e tick em que o jogador chegou na parede), porque o move_and_slide
## remove a componente contra a parede nos ticks seguintes.

const PROBE_DIRECTIONS: int = 8
## Alturas das sondas horizontais, como fração da altura do corpo.
const PROBE_HEIGHT_RATIOS: Array[float] = [0.3, 0.7]
const FEET_PROBE_LIFT: float = 0.05

var player: Player
var has_contact: bool = false
## Normal horizontal (unitária) da parede em contato.
var normal: Vector3 = Vector3.ZERO
var contact_point: Vector3 = Vector3.ZERO
var collider_id: int = 0
var last_contact_tick: int = PlayerInput.NEVER
## Tick e velocidade horizontal no momento em que o jogador chegou na parede.
var entry_tick: int = PlayerInput.NEVER
var entry_velocity: Vector3 = Vector3.ZERO

var _was_approaching: bool = false


func setup(owner_player: Player) -> void:
	player = owner_player


## Chamar a cada tick depois do move_and_slide, com a velocidade de antes do slide.
func update(pre_slide_velocity: Vector3) -> void:
	var cfg := player.config
	var hit := _probe_walls()
	if hit.is_empty() and player.is_on_wall():
		hit = _hit_from_slide()
	if hit.is_empty():
		if has_contact and player.tick - last_contact_tick > cfg.wall_contact_grace_ticks:
			has_contact = false
			_was_approaching = false
		return
	var v := WallJumpMath.horizontal(pre_slide_velocity)
	var n: Vector3 = hit.normal
	var approaching := -v.dot(n) > cfg.wall_approach_min_speed
	var is_new: bool = not has_contact or hit.collider_id != collider_id
	if is_new or (approaching and (not _was_approaching or entry_tick == PlayerInput.NEVER)):
		entry_tick = player.tick
		entry_velocity = v
	_was_approaching = approaching
	has_contact = true
	normal = n
	contact_point = hit.point
	collider_id = hit.collider_id
	last_contact_tick = player.tick


## Esquece a entrada atual: a próxima aproximação registra uma nova (após pulo/wall jump).
func reset_entry() -> void:
	entry_tick = PlayerInput.NEVER
	entry_velocity = Vector3.ZERO
	_was_approaching = false


func clear() -> void:
	reset_entry()
	has_contact = false
	collider_id = 0


## Raio para baixo a partir dos pés: true se há chão perto (perto da base da parede).
func is_near_base() -> bool:
	var cfg := player.config
	var from := player.global_position + Vector3.UP * FEET_PROBE_LIFT
	var to := player.global_position + Vector3.DOWN * cfg.back_coming_max_feet_height
	return not _ray(from, to).is_empty()


func _probe_walls() -> Dictionary:
	var cfg := player.config
	var reach := cfg.body_radius + cfg.wall_detect_distance
	var best: Dictionary = {}
	var best_distance := INF
	for ratio in PROBE_HEIGHT_RATIOS:
		var origin := player.global_position + Vector3.UP * (cfg.body_height * ratio)
		for i in PROBE_DIRECTIONS:
			var angle := TAU * float(i) / PROBE_DIRECTIONS
			var dir := Vector3(sin(angle), 0.0, cos(angle))
			var result := _ray(origin, origin + dir * reach)
			if result.is_empty():
				continue
			var n: Vector3 = result.normal
			if absf(n.y) > cfg.wall_max_normal_y:
				continue
			var distance := origin.distance_to(result.position)
			if distance < best_distance:
				best_distance = distance
				best = {
					"normal": WallJumpMath.horizontal_normal(n),
					"point": result.position,
					"collider_id": result.collider_id,
				}
	return best


func _hit_from_slide() -> Dictionary:
	for i in player.get_slide_collision_count():
		var collision := player.get_slide_collision(i)
		var n := collision.get_normal()
		if absf(n.y) <= player.config.wall_max_normal_y:
			return {
				"normal": WallJumpMath.horizontal_normal(n),
				"point": collision.get_position(),
				"collider_id": collision.get_collider_id(),
			}
	return {}


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, player.collision_mask, [player.get_rid()])
	return player.get_world_3d().direct_space_state.intersect_ray(query)
