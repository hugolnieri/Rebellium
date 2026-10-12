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

@export_group("Arremesso (caçador)")
## Velocidade do arremesso do golpe pesado = recuo do golpe (`knockback`/`knockback_up` do AttackData) × este fator.
@export_range(0.2, 5.0, 0.05) var launch_velocity_scale: float = 1.4
## Subida mínima do arremesso: o golpe pesado sempre tira o alvo do chão.
@export_range(0.0, 25.0, 0.5, "suffix:m/s") var launch_min_up_speed: float = 7.5
@export_range(4.0, 60.0, 0.5, "suffix:m/s²") var launch_gravity: float = 18.0
## Folga entre o centro do corpo e a parede em que ele bate (a cabeça vai na frente).
@export_range(0.1, 2.0, 0.05, "suffix:m") var launch_wall_margin: float = 0.6
## Fração da velocidade horizontal que sobra depois de bater numa parede (rebote).
@export_range(0.0, 1.0, 0.01) var launch_wall_bounce: float = 0.25
## Fração da velocidade horizontal que sobra ao bater no chão (vira deslize).
@export_range(0.0, 1.0, 0.01) var landing_speed_keep: float = 0.5
## Atrito do deslize no chão (depois da queda e nos golpes que não arremessam).
@export_range(1.0, 80.0, 0.5, "suffix:m/s²") var slide_friction: float = 16.0
## Empurrão dos golpes que não arremessam = recuo horizontal do golpe × este fator.
@export_range(0.0, 4.0, 0.05) var hit_slide_scale: float = 1.5
## Tempo deitado depois da queda, antes de levantar.
@export_range(0.0, 5.0, 0.05, "suffix:s") var knockdown_time: float = 0.5
## Espera depois de levantar até voltar ao spawn do caçador.
@export_range(0.0, 5.0, 0.05, "suffix:s") var return_delay: float = 0.3
## Abaixo desta altura (caiu da plataforma) o caçador volta na hora ao spawn.
@export_range(-200.0, 0.0, 1.0, "suffix:m") var fall_respawn_height: float = -30.0
