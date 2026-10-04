class_name WallJumpMath
extends RefCounted
## Matemática pura do wall jump (sem cena). Tudo no plano horizontal (XZ).


## Normal da parede projetada no plano horizontal e normalizada.
static func horizontal_normal(normal: Vector3) -> Vector3:
	return Vector3(normal.x, 0.0, normal.z).normalized()


static func horizontal(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Reflexão especular: v_out = v_in − 2 (v_in · n) n. Ângulo de entrada = ângulo de saída.
## Se v_in não vai contra a parede (v_in · n ≥ 0), devolve v_in sem alterar.
static func reflect_horizontal(v_in: Vector3, normal: Vector3) -> Vector3:
	var n := horizontal_normal(normal)
	var v := horizontal(v_in)
	var into := v.dot(n)
	if into >= 0.0:
		return v
	return v - 2.0 * into * n


## Ângulo de incidência em graus, medido a partir da normal (0° = de frente para a parede).
static func incidence_angle_deg(v_in: Vector3, normal: Vector3) -> float:
	var v := horizontal(v_in)
	if v.length_squared() < 0.000001:
		return 0.0
	return rad_to_deg((-v).angle_to(horizontal_normal(normal)))


## Ângulo de saída em graus, medido a partir da normal.
static func exit_angle_deg(v_out: Vector3, normal: Vector3) -> float:
	var v := horizontal(v_out)
	if v.length_squared() < 0.000001:
		return 0.0
	return rad_to_deg(v.angle_to(horizontal_normal(normal)))


## Velocidade horizontal de saída do wall jump normal/side jump:
## reflexão → multiplicador → afastamento mínimo → velocidade mínima →
## ajuste fino pela câmera (peso; mantém ≥ (1 − peso) do afastamento) → teto de velocidade.
static func compute_exit_horizontal(v_in: Vector3, normal: Vector3, camera_forward: Vector3,
		cfg: MovementConfig) -> Vector3:
	var n := horizontal_normal(normal)
	var out := reflect_horizontal(v_in, n) * cfg.wall_jump_horizontal_multiplier
	var away := out.dot(n)
	if away < cfg.wall_jump_min_away_speed:
		out += n * (cfg.wall_jump_min_away_speed - away)
	var speed := clampf(out.length(), cfg.wall_jump_min_horizontal_speed,
		cfg.wall_jump_max_horizontal_speed)
	var dir := out.normalized() if out.length_squared() > 0.000001 else n
	# Ajuste fino: a câmera nunca tira mais que `peso` do afastamento refletido.
	var keep_away := maxf(cfg.wall_jump_min_away_speed,
		(1.0 - cfg.wall_jump_camera_weight) * out.dot(n) * speed / maxf(out.length(), 0.001))
	var min_away_ratio := clampf(keep_away / maxf(speed, 0.001), 0.0, 1.0)
	dir = apply_camera_adjust(dir, n, camera_forward, cfg.wall_jump_camera_weight, min_away_ratio)
	return dir * speed


## Puxa a direção de saída em direção à câmera com `weight` ∈ [0,1], sem nunca apontar
## para dentro da parede (componente de afastamento ≥ `min_away_ratio`).
static func apply_camera_adjust(dir: Vector3, n: Vector3, camera_forward: Vector3, weight: float,
		min_away_ratio: float) -> Vector3:
	var cam := horizontal(camera_forward)
	if weight <= 0.0 or cam.length_squared() < 0.000001:
		return dir
	var blended := dir.lerp(cam.normalized(), clampf(weight, 0.0, 1.0))
	if blended.length_squared() < 0.000001:
		blended = dir
	blended = blended.normalized()
	return enforce_min_away(blended, n, min_away_ratio)


## Garante que `dir` (unitário) tenha componente ao longo de n de pelo menos `min_ratio`.
static func enforce_min_away(dir: Vector3, n: Vector3, min_ratio: float) -> Vector3:
	var along := dir.dot(n)
	if along >= min_ratio:
		return dir
	var tangent := dir - n * along
	var tangent_len := sqrt(maxf(1.0 - min_ratio * min_ratio, 0.0))
	if tangent.length_squared() < 0.000001:
		return n
	return (tangent.normalized() * tangent_len + n * min_ratio).normalized()
