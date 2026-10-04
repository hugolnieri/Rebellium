class_name AudioConfig
extends Resource
## Volumes e variação dos efeitos sonoros (sons gerados por tools/gen_sfx.py).

@export_group("Volumes (dB)")
@export_range(-60.0, 12.0, 0.5, "suffix:dB") var master_db: float = -4.0
@export_range(-60.0, 12.0, 0.5, "suffix:dB") var combat_db: float = 0.0
@export_range(-60.0, 12.0, 0.5, "suffix:dB") var movement_db: float = -6.0
@export_range(-60.0, 12.0, 0.5, "suffix:dB") var footsteps_db: float = -16.0
@export_range(-60.0, 12.0, 0.5, "suffix:dB") var interface_db: float = -6.0

@export_group("Variação")
## Variação aleatória de tom (± fração) para não soar repetitivo.
@export_range(0.0, 0.5, 0.01) var pitch_variation: float = 0.08
## Passos mais rápidos soam um pouco mais agudos.
@export_range(0.0, 0.5, 0.01) var footstep_pitch_by_speed: float = 0.15
@export_range(1.0, 200.0, 1.0, "suffix:m") var max_distance: float = 60.0
