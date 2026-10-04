class_name CombatRules
extends RefCounted
## Regras puras do combate (sem cena), testáveis isoladamente.

const KIND_LIGHT: StringName = &"light"
const KIND_HEAVY: StringName = &"heavy"
const KIND_AIR: StringName = &"air"
const KIND_DASH: StringName = &"dash"


## O alvo (esfera em `target_center` com raio `target_radius`) está dentro do golpe?
## O golpe é um setor horizontal de raio `reach` e abertura `arc_deg` centrado em `forward`,
## com alcance vertical `vertical_reach` a partir de `origin`.
static func is_in_attack_area(origin: Vector3, forward: Vector3, target_center: Vector3,
		target_radius: float, reach: float, arc_deg: float, vertical_reach: float) -> bool:
	var to_target := target_center - origin
	if absf(to_target.y) > vertical_reach + target_radius:
		return false
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat.length()
	if distance > reach + target_radius:
		return false
	if arc_deg >= 360.0 or distance <= target_radius:
		return true
	var dir := Vector3(forward.x, 0.0, forward.z).normalized()
	var angle := rad_to_deg(dir.angle_to(flat / distance))
	# A borda do alvo conta: alarga o arco pelo ângulo que o raio do alvo ocupa.
	var widen := rad_to_deg(atan2(target_radius, distance))
	return angle <= arc_deg * 0.5 + widen


## Escolhe o índice do melhor alvo para a mira assistida (-1 se nenhum).
## Prefere o menor ângulo em relação à câmera; desempata pela distância.
static func pick_aim_target(origin: Vector3, forward: Vector3, centers: Array[Vector3],
		max_range: float, max_angle_deg: float) -> int:
	var best := -1
	var best_score := INF
	var dir := Vector3(forward.x, 0.0, forward.z).normalized()
	for i in centers.size():
		var flat := centers[i] - origin
		flat.y = 0.0
		var distance := flat.length()
		if distance > max_range or distance < 0.001:
			continue
		var angle := rad_to_deg(dir.angle_to(flat / distance))
		if angle > max_angle_deg:
			continue
		var score := angle + distance * 2.0
		if score < best_score:
			best_score = score
			best = i
	return best


## Próximo golpe do combo leve: índice seguinte ou -1 se o combo acabou.
## Um tick do clique de ataque com "segurar = pesado".
## Toque: o leve sai ao soltar. Segurando `hold_ticks`: sai o pesado (e o soltar é ignorado).
## `instant` (no ar / no dash): o leve sai já no aperto, sem carga.
## Retorna {charge_tick, light, heavy}; charge_tick = NEVER quando não há carga em andamento.
static func attack_charge_step(charge_tick: int, tick: int, pressed_now: bool, held: bool,
		hold_ticks: int, instant: bool) -> Dictionary:
	var result := {"charge_tick": charge_tick, "light": false, "heavy": false}
	if pressed_now:
		if instant:
			result.charge_tick = PlayerInput.NEVER
			result.light = true
			return result
		result.charge_tick = tick
	if result.charge_tick == PlayerInput.NEVER:
		return result
	if not held:
		result.light = true
		result.charge_tick = PlayerInput.NEVER
	elif tick - result.charge_tick >= hold_ticks:
		result.heavy = true
		result.charge_tick = PlayerInput.NEVER
	return result


static func next_combo_index(current_index: int, combo_size: int) -> int:
	var next := current_index + 1
	return next if next < combo_size else -1


## Vetor de recuo: horizontal na direção atacante→alvo, mais componente vertical.
static func knockback_vector(attacker_pos: Vector3, target_pos: Vector3, horizontal: float,
		vertical: float, fallback_dir: Vector3) -> Vector3:
	var flat := target_pos - attacker_pos
	flat.y = 0.0
	var dir := flat.normalized() if flat.length_squared() > 0.0001 \
		else Vector3(fallback_dir.x, 0.0, fallback_dir.z).normalized()
	return dir * horizontal + Vector3.UP * vertical
