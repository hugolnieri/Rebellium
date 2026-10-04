class_name PlayerInput
extends RefCounted
## Snapshot do input de UM tick. A lógica de movimento só consome isto (nunca `Input`).
## Pensado para ser serializável e reproduzível (predição/rollback no multiplayer futuro).

const NEVER: int = -1_000_000

## Tick em que este input foi amostrado.
var tick: int = 0
## Direção de movimento local: x = direita, y = frente. Comprimento ≤ 1.
var move: Vector2 = Vector2.ZERO
## Orientação da câmera (rad). yaw = 0 olha para -Z.
var look_yaw: float = 0.0
var look_pitch: float = 0.0
var jump_held: bool = false
## Toque atual e anterior da tecla "frente" (sprint por toque duplo).
var forward_pressed_tick: int = NEVER
var forward_prev_pressed_tick: int = NEVER
## Tick do último aperto de cada botão (NEVER se nunca apertado).
var jump_pressed_tick: int = NEVER
## Dash explícito (testes / controles alternativos). No teclado o dash é Espaço + A/D,
## decidido pela lógica a partir de `jump_pressed_tick` + `move.x`.
var dodge_pressed_tick: int = NEVER
var weapon_swap_pressed_tick: int = NEVER
## Slot pedido na troca de arma: 1, 2... ou 0 = alternar para a outra.
var weapon_swap_slot: int = 0
var attack_light_pressed_tick: int = NEVER
var attack_heavy_pressed_tick: int = NEVER
var shoulder_swap_pressed: bool = false


func is_pressed_this_tick(press_tick: int) -> bool:
	return press_tick == tick


## Direção desejada no mundo (plano XZ), relativa à câmera. Comprimento ≤ 1.
func get_wish_direction() -> Vector3:
	var forward := get_camera_forward()
	var right := Vector3(cos(look_yaw), 0.0, -sin(look_yaw))
	var dir := right * move.x + forward * move.y
	return dir.limit_length(1.0)


## Frente horizontal da câmera, normalizada.
func get_camera_forward() -> Vector3:
	return Vector3(-sin(look_yaw), 0.0, -cos(look_yaw))


func has_move() -> bool:
	return move.length_squared() > 0.0001


func copy() -> PlayerInput:
	var c := PlayerInput.new()
	c.tick = tick
	c.move = move
	c.look_yaw = look_yaw
	c.look_pitch = look_pitch
	c.jump_held = jump_held
	c.forward_pressed_tick = forward_pressed_tick
	c.forward_prev_pressed_tick = forward_prev_pressed_tick
	c.jump_pressed_tick = jump_pressed_tick
	c.dodge_pressed_tick = dodge_pressed_tick
	c.weapon_swap_pressed_tick = weapon_swap_pressed_tick
	c.weapon_swap_slot = weapon_swap_slot
	c.attack_light_pressed_tick = attack_light_pressed_tick
	c.attack_heavy_pressed_tick = attack_heavy_pressed_tick
	c.shoulder_swap_pressed = shoulder_swap_pressed
	return c
