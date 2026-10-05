class_name FeedbackConfig
extends Resource
## Cores e durações de feedback visual (greybox). Acentos só para feedback.

@export_group("Paleta")
@export var color_base_black: Color = Color(0.04, 0.04, 0.05)
@export var color_dark_grey: Color = Color(0.18, 0.18, 0.19)
@export var color_dirty_white: Color = Color(0.86, 0.84, 0.79)
@export var color_metal: Color = Color(0.47, 0.49, 0.52)
@export var accent_red: Color = Color(0.92, 0.12, 0.15)
@export var accent_violet: Color = Color(0.58, 0.28, 0.98)
@export var accent_electric_blue: Color = Color(0.12, 0.62, 1.0)
@export var accent_acid_green: Color = Color(0.62, 1.0, 0.12)

@export_group("Modelo")
## Velocidade com que a cápsula vira para a direção do movimento.
@export_range(0.5, 60.0, 0.5) var model_turn_speed: float = 16.0
## O corpo vira NA HORA para a direção do input/câmera (sem suavização).
@export var instant_facing: bool = true

@export_group("Animação procedural")
## Comprimento de um ciclo completo de passada (dois passos) andando / correndo.
@export_range(0.5, 6.0, 0.05, "suffix:m") var stride_length_walk: float = 3.4
@export_range(0.5, 8.0, 0.05, "suffix:m") var stride_length_sprint: float = 4.4
@export_range(0.0, 90.0, 1.0, "suffix:°") var leg_swing_deg: float = 42.0
@export_range(0.0, 120.0, 1.0, "suffix:°") var knee_bend_deg: float = 85.0
@export_range(0.0, 90.0, 1.0, "suffix:°") var arm_swing_deg: float = 38.0
## Inclinação do CORPO INTEIRO (a partir do quadril) andando; no sprint usa ninja_run_lean_deg.
@export_range(0.0, 45.0, 0.5, "suffix:°") var run_lean_deg: float = 26.0
@export_range(0.0, 45.0, 0.5, "suffix:°") var sprint_extra_lean_deg: float = 9.0
@export_range(0.0, 0.3, 0.005, "suffix:m") var run_bob_height: float = 0.05
## Velocidade de mistura entre poses (maior = mais seco).
@export_range(1.0, 60.0, 0.5) var pose_blend_speed: float = 16.0
## Pulo do chão vira mortal para frente (duração do giro).
@export var jump_flip_enabled: bool = true
@export_range(0.1, 2.0, 0.01, "suffix:s") var jump_flip_duration: float = 0.62
## Duração do mortal/giro do wall jump.
@export_range(0.05, 2.0, 0.01, "suffix:s") var flip_duration: float = 0.5
@export_range(0.0, 1.0, 0.01, "suffix:s") var land_crouch_time: float = 0.22
@export_range(0.0, 0.6, 0.01, "suffix:m") var land_crouch_depth: float = 0.2
## Velocidade de impacto que gera o agachamento máximo.
@export_range(1.0, 40.0, 0.5, "suffix:m/s") var land_crouch_full_speed: float = 16.0
@export_range(0.0, 45.0, 0.5, "suffix:°") var dodge_lean_deg: float = 22.0

@export_range(0.0, 45.0, 0.5, "suffix:°") var max_bank_deg: float = 18.0
## Inclinação lateral nas curvas por (rad/s de giro × m/s). 0 = não balança ao trocar de direção.
@export_range(0.0, 0.2, 0.001) var bank_strength: float = 0.0
## Parado: respiração (período e amplitude no peito) e peso apoiado numa perna.
@export_range(1.0, 10.0, 0.1, "suffix:s") var breath_period: float = 4.2
@export_range(0.0, 10.0, 0.1, "suffix:°") var breath_depth_deg: float = 2.2
@export_range(0.0, 10.0, 0.1, "suffix:°") var idle_weight_shift_deg: float = 2.5
## Abertura das pernas parado (cada perna para fora).
@export_range(0.0, 25.0, 0.5, "suffix:°") var idle_stance_width_deg: float = 10.0
## Cambalhota: altura do centro do corpo encolhido (as costas encostam no chão no meio do giro).
@export_range(0.1, 1.0, 0.01, "suffix:m") var roll_ball_height: float = 0.36
## Dash como estrela (cambalhota lateral): giro completo durante o deslocamento do dash.
@export var dash_cartwheel: bool = true
## Sprint "ninja": corpo inteiro bem inclinado e braços esticados para trás.
@export_range(0.0, 60.0, 0.5, "suffix:°") var ninja_run_lean_deg: float = 45.0
## Ângulo dos braços no sprint em relação ao chão (0 = totalmente na horizontal, + = para cima).
@export_range(-45.0, 45.0, 1.0, "suffix:°") var ninja_arm_pitch_deg: float = 0.0
## Passada: fração do ciclo com o pé no chão andando / correndo e flexão do joelho de apoio.
@export_range(0.2, 0.8, 0.01) var stance_fraction_walk: float = 0.32
@export_range(0.2, 0.8, 0.01) var stance_fraction_run: float = 0.38
@export_range(0.0, 60.0, 1.0, "suffix:°") var stance_knee_walk_deg: float = 20.0
@export_range(0.0, 60.0, 1.0, "suffix:°") var stance_knee_run_deg: float = 32.0
## Elevação do joelho no balanço (coxa sobe além do passo) andando / correndo.
@export_range(0.0, 90.0, 1.0, "suffix:°") var knee_lift_walk_deg: float = 34.0
@export_range(0.0, 120.0, 1.0, "suffix:°") var knee_lift_run_deg: float = 55.0

@export_group("Molas da animação")
## Frequência/amortecimento das articulações na locomoção (menor amortecimento = mais balanço).
@export_range(0.5, 30.0, 0.1, "suffix:Hz") var anim_spring_frequency: float = 6.5
@export_range(0.05, 2.0, 0.01) var anim_spring_damping: float = 0.6
## Nos golpes as articulações respondem mais rápido.
@export_range(0.5, 40.0, 0.1, "suffix:Hz") var attack_spring_frequency: float = 15.0
@export_range(0.05, 2.0, 0.01) var attack_spring_damping: float = 0.8
## Cabelo: mola mole para movimento secundário.
@export_range(0.2, 15.0, 0.1, "suffix:Hz") var hair_spring_frequency: float = 2.8
@export_range(0.05, 2.0, 0.01) var hair_spring_damping: float = 0.3

@export_group("Personagem")
## Modelo em assets/character/hero.glb (tools/prepare_character.py). Linhas do traje: textura de
## emissão × tonalidade × energia.
@export var suit_glow_tint: Color = Color(1, 1, 1)
@export_range(0.0, 10.0, 0.1) var suit_glow_energy: float = 1.1
@export var hair_color: Color = Color(0.84, 0.85, 0.92)
## Toon: cor multiplicada na sombra, limiar e suavidade do degrau de luz.
@export var shade_color: Color = Color(0.62, 0.58, 0.72)
@export_range(-1.0, 1.0, 0.01) var shade_threshold: float = 0.05
@export_range(0.0, 0.5, 0.005) var shade_softness: float = 0.06
## Quanto o rosto recebe de sombra (0 = rosto sempre iluminado, como em anime).
@export_range(0.0, 1.0, 0.01) var face_shading: float = 0.25
## Tonalidade da pele do rosto (o rosto quase não recebe sombra; isto evita que estoure).
@export var face_tint: Color = Color(0.93, 0.89, 0.87)
@export var rim_color: Color = Color(0.75, 0.78, 1.0)
@export_range(0.0, 2.0, 0.01) var rim_strength: float = 0.35
## Contorno (casco invertido) estilo anime.
@export var outline_color: Color = Color(0.03, 0.025, 0.05)
@export_range(0.0, 0.03, 0.0005, "suffix:m") var outline_thickness: float = 0.004
## Dedos: mão direita fechada na arma, mão esquerda relaxada.
@export_range(0.0, 2.0, 0.01, "suffix:rad") var grip_curl: float = 1.25
@export_range(0.0, 2.0, 0.01, "suffix:rad") var relaxed_curl: float = 0.4
## Piscar.
@export_range(0.5, 10.0, 0.1, "suffix:s") var blink_interval: float = 3.6
@export_range(0.05, 0.5, 0.01, "suffix:s") var blink_duration: float = 0.14

@export_group("Poeira e sombra")
@export_range(0, 100, 1) var dust_amount: int = 14
@export_range(0.05, 2.0, 0.01, "suffix:s") var dust_lifetime: float = 0.45
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var dust_speed: float = 2.5
## Impacto mínimo para levantar poeira ao aterrissar.
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var dust_min_land_speed: float = 6.0
@export var dust_color: Color = Color(0.55, 0.54, 0.52, 0.8)
@export_range(0.05, 2.0, 0.01, "suffix:m") var shadow_radius: float = 0.45
@export_range(0.0, 1.0, 0.01) var shadow_max_alpha: float = 0.55
## Altura em que a sombra some (ajuda a medir a altura no ar).
@export_range(1.0, 60.0, 0.5, "suffix:m") var shadow_max_distance: float = 20.0

@export_group("HUD")
@export var sp_bar_color: Color = Color(0.12, 0.62, 1.0)
@export var sp_exhausted_color: Color = Color(0.92, 0.12, 0.15)
@export var hp_bar_color: Color = Color(0.62, 1.0, 0.12)

@export_group("Técnicas (cores)")
@export var color_wall_jump: Color = Color(0.86, 0.84, 0.79)
@export var color_side_jump: Color = Color(0.12, 0.62, 1.0)
@export var color_reverse_wall_jump: Color = Color(0.58, 0.28, 0.98)
@export var color_back_coming: Color = Color(0.62, 1.0, 0.12)
@export var color_cancel: Color = Color(0.92, 0.12, 0.15)
@export var color_dodge_cancel: Color = Color(0.4, 0.85, 1.0)
@export var color_bunny_hop: Color = Color(0.85, 1.0, 0.45)
@export var color_dodge_trail: Color = Color(0.12, 0.62, 1.0)
@export var color_swap_cancel: Color = Color(1.0, 0.75, 0.2)
@export var color_perfect_dodge: Color = Color(0.85, 0.95, 1.0)

@export_group("VFX")
## Vida de cada "fantasma" do rastro do dodge.
@export_range(0.02, 2.0, 0.01, "suffix:s") var trail_lifetime: float = 0.25
@export_range(1, 10, 1, "suffix:ticks") var trail_spawn_interval_ticks: int = 2
@export_range(0.0, 1.0, 0.01) var trail_start_alpha: float = 0.45
@export_range(1, 200, 1) var spark_amount: int = 28
@export_range(0.05, 2.0, 0.01, "suffix:s") var spark_lifetime: float = 0.35
@export_range(0.5, 30.0, 0.5, "suffix:m/s") var spark_speed: float = 6.0
## Tempo que a cápsula brilha na cor da técnica.
@export_range(0.0, 1.0, 0.01, "suffix:s") var body_flash_time: float = 0.22
@export_range(0.0, 16.0, 0.1) var body_flash_energy: float = 3.0


## Cor de feedback de uma técnica pelo nome do sinal.
func get_technique_color(technique: StringName) -> Color:
	match technique:
		&"side_jump": return color_side_jump
		&"reverse_wall_jump": return color_reverse_wall_jump
		&"back_coming": return color_back_coming
		&"cancel": return color_cancel
		&"dodge_cancel": return color_dodge_cancel
		&"bunny_hop": return color_bunny_hop
		&"swap_cancel": return color_swap_cancel
		&"perfect_dodge": return color_perfect_dodge
	return color_wall_jump
