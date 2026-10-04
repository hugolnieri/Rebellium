class_name MovementRules
extends RefCounted
## Regras puras de movimentação (sem cena), testáveis isoladamente.

## Como o jogador entrou no ar.
enum AirOrigin { NONE, JUMP, FALL }

const TECH_NORMAL: StringName = &"normal"
const TECH_SIDE_JUMP: StringName = &"side_jump"
const TECH_REVERSE: StringName = &"reverse_wall_jump"
const TECH_BACK_COMING: StringName = &"back_coming"
const TECH_CANCEL: StringName = &"cancel"
const TECH_DODGE_CANCEL: StringName = &"dodge_cancel"
const TECH_BUNNY_HOP: StringName = &"bunny_hop"
const TECH_SWAP_CANCEL: StringName = &"swap_cancel"
const TECH_PERFECT_DODGE: StringName = &"perfect_dodge"
const TECH_DASH_JUMP: StringName = &"dash_jump"


static func seconds_to_ticks(seconds: float) -> int:
	return roundi(seconds * Engine.physics_ticks_per_second)


## Wall jump só se o jogador entrou no ar por um PULO e ainda está subindo (Jump)
## ou dentro da janela pós-pulo. Queda livre (saiu de uma borda) nunca permite.
static func can_wall_jump(air_origin: AirOrigin, in_jump_state: bool, ticks_since_jump: int,
		window_ticks: int) -> bool:
	if air_origin != AirOrigin.JUMP:
		return false
	return in_jump_state or ticks_since_jump <= window_ticks


## Bunny hop: aperto de pulo no tick da aterrissagem ou nos `window - 1` seguintes.
## Apertos ANTES de aterrissar (buffer) não contam.
static func is_bunny_hop(press_tick: int, land_tick: int, window_ticks: int) -> bool:
	var delta := press_tick - land_tick
	return delta >= 0 and delta < window_ticks


## Toque duplo: o segundo toque veio até `window` ticks depois do primeiro.
static func is_double_tap(press_tick: int, previous_press_tick: int, window_ticks: int) -> bool:
	if previous_press_tick <= PlayerInput.NEVER:
		return false
	var delta := press_tick - previous_press_tick
	return delta > 0 and delta <= window_ticks


## Janela justa relativa a um evento (contato com parede, wall jump): |aperto − evento| ≤ janela.
static func is_within_window(press_tick: int, event_tick: int, window_ticks: int) -> bool:
	return absi(press_tick - event_tick) <= window_ticks


## Classifica o wall jump. Topo tem prioridade sobre base (parede baixa = reverse).
static func classify_wall_jump(in_technique_window: bool, near_top: bool, near_base: bool,
		incidence_deg: float, side_min_deg: float) -> StringName:
	if in_technique_window and near_top:
		return TECH_REVERSE
	if in_technique_window and near_base:
		return TECH_BACK_COMING
	if incidence_deg >= side_min_deg:
		return TECH_SIDE_JUMP
	return TECH_NORMAL


## Direção do dash lateral (só esquerda/direita relativas à câmera) pelo sinal de `move_x`.
static func side_dash_direction(move_x: float, look_yaw: float) -> Vector3:
	var right := Vector3(cos(look_yaw), 0.0, -sin(look_yaw))
	return right * signf(move_x)


## Velocidade do dash no instante `t` (0–1): começa em `start`, cai até `end` com curva `power`.
static func dash_speed(t: float, start: float, end: float, power: float) -> float:
	return lerpf(end, start, pow(1.0 - clampf(t, 0.0, 1.0), power))


## Direção do dodge em 8 direções relativas à câmera (plano XZ, unitária).
static func dodge_direction(move: Vector2, look_yaw: float, neutral_backward: bool) -> Vector3:
	var local := move
	if local.length_squared() < 0.0001:
		local = Vector2(0.0, -1.0 if neutral_backward else 1.0)
	var step := PI / 4.0
	var angle := snappedf(atan2(local.x, local.y), step)
	var x := sin(angle)
	var y := cos(angle)
	var forward := Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))
	var right := Vector3(cos(look_yaw), 0.0, -sin(look_yaw))
	return (right * x + forward * y).normalized()
