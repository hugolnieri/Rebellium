class_name CombatConfig
extends Resource
## Números gerais do combate (vida, buffers, mira assistida, dano recebido).

@export_group("Vida")
@export_range(1.0, 1000.0, 1.0) var max_hp: float = 100.0
## Tempo caído antes de reaparecer.
@export_range(0.0, 10.0, 0.1, "suffix:s") var respawn_delay: float = 1.5

@export_group("Entrada")
## Ticks que um clique de ataque fica guardado (permite apertar um pouco antes).
@export_range(0, 30, 1, "suffix:ticks") var attack_buffer_ticks: int = 10
## Segurar o botão esquerdo por este tempo solta o golpe pesado (toque = leve, ao soltar).
@export_range(1, 60, 1, "suffix:ticks") var heavy_hold_ticks: int = 16
## Tempo mínimo entre trocas de arma.
@export_range(0.0, 2.0, 0.01, "suffix:s") var swap_cooldown: float = 0.25

@export_group("Mira assistida")
## Desligado: o golpe sai sempre na direção da câmera.
@export var aim_assist_enabled: bool = false
## Distância máxima para o golpe virar sozinho para um alvo.
@export_range(0.0, 20.0, 0.1, "suffix:m") var aim_assist_range: float = 6.0
## Ângulo máximo entre a câmera e o alvo para a mira assistida.
@export_range(0.0, 180.0, 1.0, "suffix:°") var aim_assist_angle_deg: float = 55.0

@export_group("Golpes")
## Velocidade de movimento durante o golpe (× andar/correr). 1 = golpeia sem perder o passo.
@export_range(0.0, 1.5, 0.05) var attack_move_speed_multiplier: float = 1.0
## Espaço durante um golpe no chão interrompe o golpe e pula.
@export var attack_jump_cancel: bool = true
## Golpe (leve ou pesado) durante o dash corta o embalo do dash.
@export var attack_cancels_dash_momentum: bool = true

@export_group("Combo")
## Sem acertar por este tempo, o contador de combo zera.
@export_range(0.1, 5.0, 0.05, "suffix:s") var combo_timeout: float = 1.4

@export_group("Dano recebido")
## Atordoamento ao levar um golpe.
@export_range(0.0, 2.0, 0.01, "suffix:s") var hitstun: float = 0.35
## Multiplicador do recuo recebido.
@export_range(0.0, 3.0, 0.05) var received_knockback_multiplier: float = 1.0
