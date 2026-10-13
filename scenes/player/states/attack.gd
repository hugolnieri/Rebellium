extends PlayerState
## Golpe com a arma atual. Fases: preparação → acerto → recuperação (tempos do AttackData).
## - O golpe não trava o movimento: no chão continua andando/correndo pelo input (e gasta SP
##   correndo); no ar mantém o controle aéreo. `lunge_speed` > 0 ainda empurra na direção do golpe.
## - Na janela de acerto testa os alvos do grupo "hittable" (cada alvo leva no máximo 1 acerto).
## - A partir de `chain_after`, um clique guardado encadeia o próximo golpe do combo (ou o pesado).
## - A recuperação é cancelável por dash (dodge cancel) e por troca de arma (swap cancel).
## - No chão, Espaço pula a qualquer momento do golpe; o golpe continua no ar até o fim.
## O tempo do golpe conta em ticks próprios: o hitstop pausa o golpe.
## - Mergulho (golpe no pulo, `AttackData.plunge`): congela no ar (`plunge_hover_time`), desce reto com tudo
##   no ponto onde clicou (`plunge_speed`), acerta em volta no impacto (`plunge_impact_radius`) e fica preso
##   no chão levantando (`plunge_landing_time`), sem cancelar.
## - Golpe saído do dash no ar (`from_air_dash`): conta como golpe de chão (combo leve normal), gravidade
##   normal, velocidade de um pulo normal; sem direcional freia até parar no lugar do golpe.

enum Phase { STARTUP, ACTIVE, RECOVERY }
enum Plunge { NONE, HOVER, DIVE, LANDED }

var attack: AttackData
var kind: StringName = &""
var combo_index: int = 0
var direction: Vector3 = Vector3.FORWARD
## Golpe começou no ar (aéreo ou pesado aéreo): física aérea e termina ao tocar o chão.
var airborne: bool = false
## Gravidade no ar: a do golpe se ele começou no ar; gravidade normal se o pulo veio no meio do golpe.
var _gravity_scale: float = 1.0
## Golpe que saiu do meio de um dash no ar (conta como golpe de chão).
var from_air_dash: bool = false
var plunge: Plunge = Plunge.NONE
var _plunge_t: int = 0
var _hover_ticks: int = 0
var _landing_ticks: int = 1
## Ticks da descida até a pose de golpe chegar ao fim (só animação).
const PLUNGE_SWING_TICKS: int = 6

var _t: int = 0
var _startup_ticks: int = 1
var _active_ticks: int = 1
var _recovery_ticks: int = 1
var _chain_ticks: int = 1
var _hit_ids: Dictionary = {}


func enter(from: StringName, data: Dictionary) -> void:
	attack = data.attack
	kind = data.kind
	combo_index = data.get("combo_index", 0)
	direction = data.get("direction", Vector3.FORWARD)
	airborne = kind == CombatRules.KIND_AIR or not player.is_on_floor()
	from_air_dash = data.get("from_air_dash", false)
	_gravity_scale = attack.air_gravity_scale if airborne and not from_air_dash else 1.0
	plunge = Plunge.HOVER if attack.plunge and kind == CombatRules.KIND_AIR and airborne else Plunge.NONE
	_plunge_t = 0
	_hover_ticks = maxi(player.secs_to_ticks(attack.plunge_hover_time), 0)
	_landing_ticks = maxi(player.secs_to_ticks(attack.plunge_landing_time), 1)
	if airborne:
		player.air_action_used = true
	_t = 0
	_hit_ids.clear()
	_startup_ticks = maxi(player.secs_to_ticks(attack.startup), 0)
	_active_ticks = maxi(player.secs_to_ticks(attack.active), 1)
	_recovery_ticks = maxi(player.secs_to_ticks(attack.recovery), 0)
	_chain_ticks = player.secs_to_ticks(attack.chain_after)
	player.facing_override = direction
	if from == &"Dodge" and player.combat_config.attack_cancels_dash_momentum:
		# O golpe corta o dash: sobra no máximo a velocidade de andar.
		var horizontal := player.get_horizontal_velocity().limit_length(player.get_walk_speed())
		player.velocity.x = horizontal.x
		player.velocity.z = horizontal.z
	if plunge != Plunge.NONE:
		player.velocity = Vector3.ZERO  # congela onde clicou
	elif kind == CombatRules.KIND_AIR and attack.air_start_vertical_speed != 0.0:
		player.velocity.y = attack.air_start_vertical_speed
	GameEvents.attack_started.emit(player, attack, player.get_weapon(), kind)


func exit() -> void:
	player.facing_override = Vector3.ZERO


func is_recovery() -> bool:
	# O mergulho não tem recuperação cancelável: no chão ele fica preso até levantar.
	return plunge == Plunge.NONE and _t > _startup_ticks + _active_ticks


func get_phase() -> Phase:
	match plunge:
		Plunge.HOVER:
			return Phase.STARTUP
		Plunge.DIVE:
			return Phase.ACTIVE
		Plunge.LANDED:
			return Phase.RECOVERY
	if _t <= _startup_ticks:
		return Phase.STARTUP
	if _t <= _startup_ticks + _active_ticks:
		return Phase.ACTIVE
	return Phase.RECOVERY


## Progresso 0–1 dentro da fase atual (para a animação procedural).
func get_phase_progress() -> float:
	match plunge:
		Plunge.HOVER:
			return float(_plunge_t) / maxf(_hover_ticks, 1)
		Plunge.DIVE:
			return float(_plunge_t) / PLUNGE_SWING_TICKS
		Plunge.LANDED:
			return float(_plunge_t) / _landing_ticks
	match get_phase():
		Phase.STARTUP:
			return float(_t) / maxf(_startup_ticks, 1)
		Phase.ACTIVE:
			return float(_t - _startup_ticks) / maxf(_active_ticks, 1)
	return float(_t - _startup_ticks - _active_ticks) / maxf(_recovery_ticks, 1)


## Mergulho já no chão, levantando (para a animação).
func is_plunge_landing() -> bool:
	return plunge == Plunge.LANDED


func physics_update(input: PlayerInput, delta: float) -> void:
	if plunge != Plunge.NONE:
		_plunge_update(input, delta)
		return
	_t += 1
	if is_recovery() and player.try_dodge(input):
		return
	if _try_jump_cancel(input):
		return
	if _t >= _chain_ticks and player.try_attack(input):
		return
	var phase := get_phase()
	if airborne and from_air_dash:
		_move_after_air_dash(input, delta)
	elif airborne:
		if _t == _startup_ticks + 1 and attack.air_active_vertical_speed != 0.0:
			player.velocity.y = attack.air_active_vertical_speed
		player.apply_air_movement(input, delta, _gravity_scale)
	elif phase != Phase.RECOVERY and attack.lunge_speed > 0.0:
		player.velocity.x = direction.x * attack.lunge_speed
		player.velocity.z = direction.z * attack.lunge_speed
		player.apply_gravity(delta)
	else:
		_move_on_ground(input, delta)
	if phase == Phase.ACTIVE:
		_check_hits(attack.reach, attack.arc_deg)
	if _t >= _startup_ticks + _active_ticks + _recovery_ticks:
		_finish(input)


## Congela → desce reto → preso no chão. Sem dash, pulo, troca nem outro golpe no meio.
func _plunge_update(input: PlayerInput, delta: float) -> void:
	_plunge_t += 1
	match plunge:
		Plunge.HOVER:
			player.velocity = Vector3.ZERO
			if _plunge_t > _hover_ticks:
				plunge = Plunge.DIVE
				_plunge_t = 0
				player.velocity = Vector3.DOWN * attack.plunge_speed
		Plunge.DIVE:
			player.velocity = Vector3.DOWN * attack.plunge_speed
			_check_hits(attack.reach, 360.0)
			if _plunge_t > player.secs_to_ticks(attack.plunge_max_time):
				machine.transition_to(&"Fall", "mergulho sem chão")
		Plunge.LANDED:
			player.velocity = Vector3(0.0, minf(player.velocity.y, 0.0), 0.0)
			player.apply_gravity(delta)
			if _plunge_t >= _landing_ticks:
				_finish(input)


## Golpe saído do dash no ar: andar no ar normal com direcional; sem ele, freia até parar ali.
func _move_after_air_dash(input: PlayerInput, delta: float) -> void:
	if input.has_move():
		player.apply_air_movement(input, delta)
		return
	var horizontal := player.get_horizontal_velocity().move_toward(Vector3.ZERO,
		player.combat_config.air_dash_attack_stop_deceleration * delta)
	player.velocity.x = horizontal.x
	player.velocity.z = horizontal.z
	player.apply_gravity(delta)


## Pulo durante o golpe (no chão): sai pulando SEM interromper o golpe, que segue no ar.
func _try_jump_cancel(input: PlayerInput) -> bool:
	if not player.combat_config.attack_jump_cancel or airborne or not player.is_on_floor():
		return false
	if not player.consume_jump_press(input, cfg().jump_buffer_ticks):
		return false
	player.do_jump("pulo durante o golpe", false)
	airborne = true
	_gravity_scale = 1.0  # pulo normal (a gravidade reduzida é só para golpes que começam no ar)
	return true  # o golpe continua; neste tick só sai o pulo (como no estado Jump)


## Golpe no chão sem perder o passo: anda ou corre (sprint ativo) pelo input.
func _move_on_ground(input: PlayerInput, delta: float) -> void:
	var multiplier := player.combat_config.attack_move_speed_multiplier
	if player.can_sprint(input):
		player.redirect_to_wish(input)
		player.apply_ground_movement(input, player.get_sprint_speed() * multiplier, delta)
		player.sp.drain(cfg().sprint_sp_cost_per_second * delta)
	else:
		player.redirect_to_wish(input, cfg().walk_instant_turn)
		player.apply_ground_movement(input, player.get_walk_speed() * multiplier, delta)


func post_move(_input: PlayerInput) -> void:
	if plunge == Plunge.DIVE and player.is_on_floor():
		# Impacto: acerta em volta e fica preso no chão levantando.
		plunge = Plunge.LANDED
		_plunge_t = 0
		airborne = false
		player.touch_down_during_action()
		_check_hits(attack.plunge_impact_radius, 360.0)
		return
	if plunge != Plunge.NONE:
		return
	if airborne and _t > 1 and player.is_on_floor():
		# O golpe continua até o fim no chão; só o pulo (ou dash na recuperação) interrompe.
		airborne = false
		player.touch_down_during_action()


func _check_hits(reach: float, arc_deg: float) -> void:
	var origin := player.get_hit_center()
	for target in player.get_hittables():
		var id := target.get_instance_id()
		if _hit_ids.has(id):
			continue
		var center: Vector3 = target.call(&"get_hit_center")
		var radius: float = target.call(&"get_hit_radius")
		if not CombatRules.is_in_attack_area(origin, direction, center, radius,
				reach, arc_deg, attack.vertical_reach):
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
