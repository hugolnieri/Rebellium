class_name DummyConfig
extends Resource
## Números dos postes de treino (alvos do combate).

@export_group("Vida")
@export_range(1.0, 5000.0, 1.0) var max_hp: float = 300.0
## Sem apanhar por este tempo, o poste volta à vida cheia.
@export_range(0.1, 10.0, 0.1, "suffix:s") var regen_delay: float = 2.5
## Tempo "quebrado" depois de zerar a vida.
@export_range(0.1, 10.0, 0.1, "suffix:s") var broken_time: float = 1.2
## Raio do alvo para o teste de acerto.
@export_range(0.1, 2.0, 0.01, "suffix:m") var hit_radius: float = 0.45

@export_group("Balanço")
## Frequência e amortecimento da mola do balanço ao apanhar.
@export_range(0.5, 10.0, 0.1, "suffix:Hz") var wobble_frequency: float = 2.6
@export_range(0.0, 1.0, 0.01) var wobble_damping: float = 0.25
## Inclinação por unidade de recuo do golpe.
@export_range(0.0, 0.2, 0.001, "suffix:rad/(m/s)") var wobble_per_knockback: float = 0.035

@export_group("Patrulha")
@export_range(0.0, 20.0, 0.1, "suffix:m") var patrol_distance: float = 6.0
@export_range(0.0, 15.0, 0.1, "suffix:m/s") var patrol_speed: float = 2.5

@export_group("Contra-ataque")
## Intervalo entre golpes do poste agressivo.
@export_range(0.3, 10.0, 0.05, "suffix:s") var attack_interval: float = 2.6
## Aviso (brilho vermelho) antes do golpe: hora de dar dash.
@export_range(0.05, 3.0, 0.01, "suffix:s") var attack_windup: float = 0.6
@export_range(0.5, 8.0, 0.05, "suffix:m") var attack_radius: float = 2.8
@export_range(0.0, 100.0, 0.5) var attack_damage: float = 10.0
@export_range(0.0, 30.0, 0.5, "suffix:m/s") var attack_knockback: float = 7.0
@export_range(0.0, 0.5, 0.005, "suffix:s") var attack_hitstop: float = 0.06
