extends Node
## Barramento global de eventos de feedback (autoload "GameEvents").
##
## A lógica de jogo apenas EMITE; VFX, som, HUD e o modo treino OUVEM.
## Nenhum sistema de gameplay deve depender de quem está ouvindo.

## Transição da máquina de estados de um jogador.
signal state_changed(player: Node, from_state: StringName, to_state: StringName, reason: String)
## Wall jump executado (qualquer variante). data: position, normal, velocity, technique.
signal wall_jump_executed(player: Node, data: Dictionary)
## Técnica avançada acertada: side_jump, back_coming, cancel, dodge_cancel, bunny_hop.
signal technique_executed(player: Node, technique: StringName, data: Dictionary)
## Dodge iniciado. direction em espaço do mundo.
signal dodged(player: Node, direction: Vector3)
## Jogador aterrissou. impact_speed = velocidade vertical (positiva) no impacto.
signal landed(player: Node, impact_speed: float)
## Pulo do chão executado.
signal jumped(player: Node)
## SP chegou a zero (jogador fica exausto).
signal sp_depleted(player: Node)
## SP recuperou o mínimo e as ações voltaram a ser permitidas.
signal sp_recovered(player: Node)
## Troca de arma pressionada (slot 1, 2... ou 0 = alternar).
signal weapon_swap_pressed(player: Node, slot: int)
## Arma efetivamente trocada.
signal weapon_changed(player: Node, weapon: Resource, slot: int)
## Golpe iniciado. kind: light, heavy, air, dash.
signal attack_started(player: Node, attack: Resource, weapon: Resource, kind: StringName)
## Golpe acertou. info: damage, knockback, point, attack, weapon, kind, hitstop_ticks.
signal hit_landed(attacker: Node, target: Node, info: Dictionary)
## Jogador levou dano.
signal player_hurt(player: Node, info: Dictionary)
## Vida do jogador zerou / jogador voltou.
signal player_died(player: Node)
signal player_respawned(player: Node)
## Passo no chão (para som). intensity 0–1 (andar → correr).
signal footstep(player: Node, intensity: float)
## Começou a correr (sprint no chão ou corrida no ar) — o personagem dá um gritinho.
signal sprint_started(player: Node)
## Poste agressivo: aviso antes do golpe e o golpe em si.
signal dummy_warning(dummy: Node)
signal dummy_attack(dummy: Node)
