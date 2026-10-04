extends PlayerState
## Golpe com a arma atual. Fases: preparação → acerto → recuperação (tempos do AttackData).
## - O golpe não trava o movimento: no chão continua andando/correndo pelo input (e gasta SP
##   correndo); no ar mantém o controle aéreo. `lunge_speed` > 0 ainda empurra na direção do golpe.
## - Na janela de acerto testa os alvos do grupo "hittable" (cada alvo leva no máximo 1 acerto).
## - A partir de `chain_after`, um clique guardado encadeia o próximo golpe do combo (ou o pesado).
## - A recuperação é cancelável por dash (dodge cancel) e por troca de arma (swap cancel).
## O tempo do golpe conta em ticks próprios: o hitstop pausa o golpe.

enum Phase { STARTUP, ACTIVE, RECOVERY }

var attack: AttackData
var kind: StringName = &""
var combo_index: int = 0
var direction: Vector3 = Vector3.FORWARD

var _t: int = 0
var _startup_ticks: int = 1
var _active_ticks: int = 1
var _recovery_ticks: int = 1
var _chain_ticks: int = 1
var _hit_ids: Dictionary = {}


func enter(_from: StringName, data: Dictionary) -> void:
	attack = data.attack
	kind = data.kind
	combo_index = data.get("combo_index", 0)
	direction = data.get("direction", Vector3.FORWARD)
	_t = 0
	_hit_ids.clear()
	_startup_ticks = maxi(player.secs_to_ticks(attack.startup), 0)
	_active_ticks = maxi(player.secs_to_ticks(attack.active), 1)
	_recovery_ticks = maxi(player.secs_to_ticks(attack.recovery), 0)
	_chain_ticks = player.secs_to_ticks(attack.chain_after)
	player.facing_override = direction
	if kind == CombatRules.KIND_AIR and attack.air_start_vertical_speed != 0.0:
		player.velocity.y = attack.air_start_vertical_speed
	GameEvents.attack_started.emit(player, attack, player.get_weapon(), kind)


func exit() -> void:
	player.facing_override = Vector3.ZERO


func is_recovery() -> bool:
	return _t > _startup_ticks + _active_ticks


func get_phase() -> Phase:
	if _t <= _startup_ticks:
		return Phase.STARTUP
	if _t <= _startup_ticks + _active_ticks:
		return Phase.ACTIVE
	return Phase.RECOVERY


## Progresso 0–1 dentro da fase atual (para a animação procedural).
func get_phase_progress() -> float:
	match get_phase():
		Phase.STARTUP:
			return float(_t) / maxf(_startup_ticks, 1)
		Phase.ACTIVE:
			return float(_t - _startup_ticks) / maxf(_active_ticks, 1)
	return float(_t - _startup_ticks - _active_ticks) / maxf(_recovery_ticks, 1)


func physics_update(input: PlayerInput, delta: float) -> void:
	_t += 1
	if is_recovery() and player.try_dodge(input):
		return
	if _t >= _chain_ticks and player.try_attack(input):
		return
	var phase := get_phase()
	var airborne := kind == CombatRules.KIND_AIR
	if airborne:
		if _t == _startup_ticks + 1 and attack.air_active_vertical_speed != 0.0:
			player.velocity.y = attack.air_active_vertical_speed
		player.apply_air_movement(input, delta, attack.air_gravity_scale)
	elif phase != Phase.RECOVERY and attack.lunge_speed > 0.0:
		player.velocity.x = direction.x * attack.lunge_speed
		player.velocity.z = direction.z * attack.lunge_speed
		player.apply_gravity(delta)
	else:
		_move_on_ground(input, delta)
	if phase == Phase.ACTIVE:
		_check_hits()
	if _t >= _startup_ticks + _active_ticks + _recovery_ticks:
		_finish(input)


## Golpe no chão sem perder o passo: anda ou corre (sprint ativo) pelo input.
func _move_on_ground(input: PlayerInput, delta: float) -> void:
	var multiplier := player.combat_config.attack_move_speed_multiplier
	if player.can_sprint(input):
		player.redirect_to_wish(input)
		player.apply_ground_movement(input, player.get_sprint_speed() * multiplier, delta)
		player.sp.drain(cfg().sprint_sp_cost_per_second * delta)
	else:
		player.apply_ground_movement(input, player.get_walk_speed() * multiplier, delta)


func post_move(_input: PlayerInput) -> void:
	if kind == CombatRules.KIND_AIR and _t > 1 and player.is_on_floor():
		machine.transition_to(&"Land", "golpe aéreo tocou o chão")


func _check_hits() -> void:
	var origin := player.get_hit_center()
	for target in player.get_hittables():
		var id := target.get_instance_id()
		if _hit_ids.has(id):
			continue
		var center: Vector3 = target.call(&"get_hit_center")
		var radius: float = target.call(&"get_hit_radius")
		if not CombatRules.is_in_attack_area(origin, direction, center, radius,
				attack.reach, attack.arc_deg, attack.vertical_reach):
			continue
		_hit_ids[id] = true
		var hitstop := player.secs_to_ticks(attack.hitstop)
		var info := {
			"attacker": player, "damage": attack.damage, "attack": attack,
			"weapon": player.get_weapon(), "kind": kind, "hitstop_ticks": hitstop, "point": center,
			"knockback": CombatRules.knockback_vector(player.global_position, center,
				attack.knockback, attack.knockback_up, direction),
		}
		if target.call(&"take_hit", info):
			player.hitstop_ticks = maxi(player.hitstop_ticks, hitstop)
			GameEvents.hit_landed.emit(player, target, info)


func _finish(input: PlayerInput) -> void:
	if player.is_on_floor():
		machine.transition_to(player.ground_target_state(input), "fim do golpe")
	else:
		machine.transition_to(&"Fall", "fim do golpe no ar")
