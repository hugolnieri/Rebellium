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
	return color_wall_jump
