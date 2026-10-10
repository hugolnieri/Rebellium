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
   reflexão (18 SP, só após pulo), side jump, back-coming, cancel, dodge cancel,
   bunny hop. Testes GUT de reflexão, SP, regra "só após pulo" e janela do bunny hop.
4. **Modo treino** — percurso (corredor, vão de side jump, torre, borda, parede lisa de
   back-coming), cronômetro, melhor tempo, reset (R), contador de técnicas, menu F2 que edita e
   salva o `MovementConfig`.

## Decisões de design registradas
- **Wall jump** só se o jogador entrou no ar por um pulo (ou wall jump) e ainda está em Jump ou dentro
  da janela pós-pulo. Cair de borda nunca habilita wall jump. Mesma parede não pode ser usada duas
  vezes seguidas (exceto após back-coming).
- **Reflexão:** `v_out = v_in - 2 (v_in·n) n` no plano horizontal; impulso vertical somado à parte.
  A câmera ajusta a direção de saída com peso configurável (padrão 0,3), sem apontar para a parede.
- **Back-coming:** contato perto da base (na janela justa) → sobe quase na vertical com um leve empurrão
  de volta para a parede, colado nela, e ganha um segundo wall jump na mesma parede. Esse segundo salto
  dispensa a janela justa; segurando o direcional para a parede, vira um segundo back-coming (um
  lance extra por parede), senão se afasta da parede.
- **Janela justa** (back-coming): Space até N ticks do contato com a parede.
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

## Revisão: postura, cambalhota e cancels
- Parado com as pernas abertas; tronco inclina ao andar e mais no sprint.
- Wall jump com o personagem bem encolhido na parede; cambalhota rola com as costas no chão.
- Pulo cancela o golpe no chão; golpe leve ou pesado cancela o dash (corta o embalo).
- Dash no ar acelera a queda mais devagar (3 m/s, gravidade ×1,4).

## Revisão: estrela no dash e espada no ombro
- Cambalhota ao aterrissar mais longa (`roll_duration` 0,7 s).
- Dash vira uma estrela (cambalhota lateral), no chão e no ar (`dash_cartwheel`).
- Tronco mais inclinado: 26° andando, 45° no sprint.
- Lâmina de Arco apoiada no ombro parado e andando (`WeaponConfig.rest_on_shoulder`).

## Revisão: corpo inclinado, passada e ritmo do combo
- Inclinação do corpo inteiro a partir do quadril (coxas compensam, pés embaixo do corpo).
- Sprint com braços na horizontal (o ângulo do ombro desconta a inclinação do tronco).
- Passada nova por fases (apoio/balanço) com calcanhar, carga no joelho e impulso na ponta.
- Golpes leves mais lentos com intervalo maior entre os acertos do combo; buffer do clique 20 ticks.
- Lâmina de Arco encostada no ombro (pose resolvida para a lâmina tocar o topo do ombro).
- Dash no ar zera a queda acumulada antes de descer.

## Revisão: aterrissagem limpa e joelhos
- Dash ou golpe no ar cancelam a animação de impacto ao aterrissar (sem cambalhota nem agachamento).
- Joelhos sobem mais no balanço da passada, andando e correndo.

## Revisão: trote, mortal no pulo e giro para a direita
- Andar como trote (passada 3,4 m, fase de voo), sem giro de quadril que balançava o corpo inclinado.
- Pulo do chão com mortal para frente; altura do pulo 2,35 m (o máximo que mantém a parede lisa de
  4,4 m do percurso exigindo back-coming duplo).
- Pesado da Lâmina de Arco gira para a direita.

## Revisão: ações que continuam no chão, giro imediato e passada agachada
- Dash e golpe aéreos continuam ao tocar o chão (pouso limpo); só o pulo interrompe.
- Corpo e velocidade viram na hora para o input/câmera também andando.
- (Passada agachada com calcanhar para trás foi testada e desfeita.)

## Revisão: pulo segue a câmera
- No ar a direção vira na hora para o input relativo à câmera, sem perder velocidade (`air_instant_turn`).
- Andando o pé fica menos tempo no chão (`stance_fraction_walk` 0,32).

## Revisão: wall jump completo, dash deslizando e golpe no pulo
- Cambalhota segue o input/câmera como o pulo.
- Wall jump mais longo (×1,25, mín. 10 m/s, sem controle por 0,3 s), mortal completo (golpe/dash
  bloqueados 0,45 s; encadear wall jump liberado em 0,08 s) e direção mantida até pousar.
- Dash desliza mais (0,65 s, curva 1,1, saída 7 m/s, deslize final 14 m/s²).
- Pular durante o golpe mantém o golpe (continua no ar).

## Revisão: correções e passada baixa
- Corrigido: pular no meio de um golpe usava a gravidade reduzida de golpe aéreo (pulo alto demais).
- Dash pode cortar o mortal do wall jump; golpe continua bloqueado até o fim do mortal.
- Passada agachada com pernas resolvidas para os pés ficarem no chão (andando 9 cm, correndo 14 cm);
  pé andando no chão 25% do ciclo.
- Reverse vai bem mais para frente depois de passar da borda (`reverse_clear_speed`).

## Revisão: passada de volta, pulinho e pulo a andar
- Passada agachada desfeita; andando o corpo dá um pulinho a cada passo (`walk_hop_height`).
- Pulo do chão volta à velocidade de andar, inclusive após sprint/dash (`jump_resets_to_walk_speed`);
  o bunny hop preserva a velocidade de aterrissagem (útil com a corrida no ar).


## Revisão: cancelar dash no ar
- Space no meio do dash no ar cancela o dash (volta a cair, velocidade de andar; `air_dodge_jump_cancels`).

## Revisão: personagem e animações no Blender
- Personagem novo (base VRoid CC0 "HairSample_Male"): traje azul-marinho de gola alta com emblema,
  cabelo branco, olhos cinza, descalço. Montado por `tools/blender/build_hero.py`.
- Animações viram Actions do Blender em `art/character/hero.blend` (fonte editável); exportadas no
  `hero.glb` e amostradas pelo jogo por tempo normalizado (`scenes/player/hero_clips.gd`).
- Os parâmetros de forma da passada/poses saíram do F2 (agora se edita a pose no Blender); ritmo,
  giros, agachamento e molas continuam no F2.

## Revisão: reverse wall jump removido
- O reverse wall jump saiu do jogo. No lugar, o back-coming pode ser encadeado uma vez na mesma parede
  (Space segurando o direcional para a parede; `back_coming_chain_min_dot`): é assim que se sobe a borda
  de 3,6 m e a parede lisa de 4,4 m. Sem segurar, o segundo salto se afasta da parede, como antes.
- Torre: a parede de chegada baixou para 16,5 m e ficou mais larga; o último wall jump cai em cima dela.
