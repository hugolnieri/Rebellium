# REBELLIUM — Escopo do MVP de movimentação (Fases 1–4)

## Visão
Ação acrobática em terceira pessoa, competitiva, 100% melee. A movimentação é a habilidade principal:
quem domina wall jumps, cancels e técnicas avançadas controla o espaço da arena.

## Fora do escopo (até agora)
Rede/multiplayer, arte final (modelos e animações feitos à mão), música.

## Fases
1. **Setup** — projeto Godot 4.7 + Jolt, GUT, InputMap remapeável, arena greybox.
2. **Controller base** — cápsula em CharacterBody3D, câmera sobre o ombro (SpringArm3D, troca de ombro),
   andar 6 m/s, sprint 10 m/s, pulo 2,2 m, sistema de SP (100 máx, regen 25/s após 0,6 s,
   sprint 12/s, exaustão até 20), HUD e HUD de debug (F1).
3. **Movimentação avançada** — dodge (8 direções, 20 SP, 0,15 s de invencibilidade), wall jump por
   reflexão (18 SP, só após pulo), side jump, reverse wall jump, back-coming, cancel, dodge cancel,
   bunny hop. Testes GUT de reflexão, SP, regra "só após pulo" e janela do bunny hop.
4. **Modo treino** — percurso (corredor, vão de side jump, torre, borda de reverse, parede lisa de
   back-coming), cronômetro, melhor tempo, reset (R), contador de técnicas, menu F2 que edita e
   salva o `MovementConfig`.

## Decisões de design registradas
- **Wall jump** só se o jogador entrou no ar por um pulo (ou wall jump) e ainda está em Jump ou dentro
  da janela pós-pulo. Cair de borda nunca habilita wall jump. Mesma parede não pode ser usada duas
  vezes seguidas (exceto após back-coming).
- **Reflexão:** `v_out = v_in - 2 (v_in·n) n` no plano horizontal; impulso vertical somado à parte.
  A câmera ajusta a direção de saída com peso configurável (padrão 0,3), sem apontar para a parede.
- **Reverse wall jump:** raio acima da cabeça não acha parede → lançamento para dentro/por cima (−n).
- **Back-coming:** contato perto da base (na janela justa) → sobe quase na vertical com um leve empurrão
  de volta para a parede, colado nela, e ganha um segundo wall jump na mesma parede. Esse segundo salto
  dispensa a janela justa; se estiver perto do topo, vira reverse e passa por cima.
- **Janela justa** (reverse/back-coming): Space até N ticks do contato com a parede.
- **Cancel:** tecla 1/2 até N ticks do wall jump zera o lançamento e mantém uma fração da velocidade
  de entrada. O SP gasto não volta.
- **Bunny hop:** pulo pressionado nos primeiros 3 ticks após aterrissar preserva a velocidade horizontal.
- **Dodge cancel:** dodge interrompe a recuperação do Land e do próprio Dodge.

## Revisão após o primeiro teste jogável
- **Controles:** dash = Shift + direção (A/D para os lados; Ctrl alternativo). Sprint = toque duplo em W
  e segurar.
- **Wall jump** mais alto (2,6 m); corredor e torre do percurso ficaram mais altos para manter o desafio.
- **Dash no ar** (um por pulo, recarrega ao aterrissar/wall jump) e **wall jump mais longo e rápido**:
  saída refletida ×1,1, empurrão de 2 m/s ao longo da parede no sentido do movimento, teto de 18 m/s,
  peso da câmera 0,4. A pista depois do corredor ficou 12 m maior e os trechos seguintes foram deslocados.
- **Corrida no ar** (toque duplo em W no ar): acelera até 10 m/s, gravidade ×1,7, gasta SP.
  **Sensação de velocidade**: linhas radiais (shader), FOV até +18°, recuo e tremor leve da câmera.
- **Personagem** procedural (primitivas + animação por código) no lugar da cápsula, mais sombra redonda,
  poeira e tremor leve de câmera. Tudo ajustável em `feedback_config.tres` / `camera_config.tres`.

## Fase 5 — Combate melee básico
- **Personagem base** no estilo anime cyberpunk (referência de arte do usuário): traje preto com linhas
  roxas emissivas, cabelo branco espetado, olhos verdes, ombreiras/joelheiras, pulseira de energia.
  Feito de primitivas, animado por código com **molas por articulação** (sem poses rígidas).
- **Armas** (nomes originais):
  - **Lâmina de Arco** — espada de plasma ciano, lâmina bifurcada. Combo leve de 3, giro pesado 360°
    (15 SP), mergulho aéreo, estocada no dash.
  - **Presa de Fase** — adaga curva laranja, mais leve (+8% de velocidade). Combo leve de 4 rápido,
    lâmina ascendente pesada (lança para cima, 12 SP), mergulho aéreo, bote no dash.
- **Controles**: botão esquerdo = leve (combo), direito = pesado, 1/2 = arma, Q = alterna.
  No ar = golpe aéreo; durante o dash = golpe de dash.
- **Cancels**: recuperação do golpe cancelável por dash (dodge cancel) e por troca de arma
  (**swap cancel**). Dash com invencibilidade contra golpe = **esquiva perfeita**.
- **Sensação de impacto**: hitstop, faísca na cor da arma, tremor de câmera, números de dano, rastro do golpe.
- **Mira assistida**: o golpe vira para o alvo mais alinhado à câmera (alcance e ângulo configuráveis).
- **Arena de combate** com postes: parados, móvel, agressivo (contra-ataca com aviso vermelho) e no alto.
- **Sons** sintetizados (`tools/gen_sfx.py`): golpes, impactos, passos, pulo, wall jump, dash, troca de arma,
  técnicas, esquiva perfeita, dano, aviso do poste.

## Revisão após o teste do combate
- **Dash**: Space + A/D (sem Shift), só lateral, vai mais longe e desacelera. Space durante o dash cancela
  e pula mantendo 70% da velocidade (**dash jump**).
- **Cambalhota** ao aterrissar forte (cancelável com dash ou corrida); **mortal para trás** no wall jump
  pisando na parede; **gritinho** ao começar a correr.
- **Golpes** sem avanço e sem mira assistida por padrão (o personagem golpeia no lugar, para onde a câmera
  aponta). A mira assistida continua disponível em `combat_config.tres`.
- **Personagem bem modelado**: malha lisa (SDF + marching cubes) com esqueleto e pesos de pele, gerada por
  `tools/gen_character.py` em `assets/character/`. Toon shading, contorno por casco invertido, rosto com
  olhos verdes, cabelo em mechas. A animação por molas agora gira os ossos do esqueleto.

## Revisão: golpe em movimento e personagem anime
- **Golpe sem travar**: no chão o personagem continua andando ou correndo pelo input enquanto golpeia
  (`attack_move_speed_multiplier`); no ar mantém o controle aéreo.
- **Pesado segurando o clique esquerdo** (`heavy_hold_ticks`): toque = leve ao soltar; a arma brilha
  durante a carga. Botão direito continua como pesado direto.
- **Personagem**: modelo pronto do VRoid Studio ("Sakurada Fumiriya", **CC0**) adaptado por
  `tools/prepare_character.py`: roupas removidas, traje preto com linhas roxas emissivas desenhadas em 3D e
  assadas na textura, cabelo branco, olhos verdes, descalço. Shader toon próprio (sombra colorida com
  degrau suave, luz de borda, rosto quase sem sombra) e contorno. A animação por molas é convertida para
  o esqueleto do modelo (braços da T-pose), com dedos fechados na arma, piscar e sobrancelhas no golpe.

## Revisão: animação natural e ajustes de ar
- Parado com respiração e peso numa perna; sem inclinação lateral ao trocar de direção.
- Sprint com corrida "ninja" (tronco inclinado, braços para trás), também na corrida no ar.
- Dash no ar acelera a queda (`air_dodge_fall_speed`, `air_dodge_gravity_multiplier`).
- Wall jump cola o personagem na parede por `wall_jump_stick_ticks` antes do impulso.
- Pesado também no ar (segurar ou botão direito) e com animação mais longa (tempos dos `heavy.tres`).

