extends Node
## Barramento global de eventos de feedback (autoload "GameEvents").
##
## A lógica de jogo apenas EMITE; VFX, som, HUD e o modo treino OUVEM.
## Nenhum sistema de gameplay deve depender de quem está ouvindo.

## Transição da máquina de estados de um jogador.
signal state_changed(player: Node, from_state: StringName, to_state: StringName, reason: String)
## Wall jump executado (qualquer variante). data: position, normal, velocity, technique.
signal wall_jump_executed(player: Node, data: Dictionary)
## Técnica avançada acertada: side_jump, reverse_wall_jump, back_coming, cancel, dodge_cancel, bunny_hop.
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
## Troca de arma pressionada (ainda sem armas: só o evento). slot começa em 1.
signal weapon_swap_pressed(player: Node, slot: int)
