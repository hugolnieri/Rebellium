# REBELLIUM — Roteiro de teste manual (Fases 1–5)

Para rodar: `godot --path .` ou abra o projeto no editor e aperte F5. Abre a **arena de combate**.
**F3** alterna entre: arena de combate → percurso de treino → arena livre.

## Controles
| Tecla | Ação |
|---|---|
| WASD | mover (relativo à câmera) |
| Mouse | olhar (clique para capturar o mouse) |
| Space | pular / wall jump |
| W, W (toque duplo rápido) e segurar | sprint (soltar o W encerra) |
| Shift + A/D (ou W/S) | dash/dodge na direção (Shift antes ou depois da direção; Ctrl também serve) |
| Botão esquerdo (ou J) | golpe leve — cliques seguidos fazem o combo |
| Botão direito (ou K) | golpe pesado (gasta SP) |
| 1 / 2 / Q | Lâmina de Arco / Presa de Fase / alterna (também faz o **cancel** do wall jump) |
| V | trocar ombro da câmera |
| Esc | soltar o mouse |
| F1 | liga/desliga HUD de debug |
| F2 | menu de ajustes ao vivo (movimento, câmera, visual, combate, cada arma e golpe, áudio) |
| F3 | troca de cena |
| R | reinicia (volta ao início; no percurso zera cronômetro, na arena zera os postes) |

## HUD de debug (F1): o que cada linha diz
- **estado**: estado atual da máquina (Idle, Run, Sprint, Jump, Fall, WallJump, Dodge, Land) e há quantos ticks.
- **vel horiz / vel vertical / altura pés**: para conferir 6 m/s andando, 10 m/s em sprint e pulo de 2,2 m.
- **na parede**: normal da parede, há quantos ticks foi a entrada no contato, e se o topo/base estão perto.
  "topo: perto" significa que o reverse está disponível; "base: perto" significa que o back-coming está disponível.
- **wall jump**: `LIBERADO` ou o motivo do bloqueio (`sem parede`, `não veio de pulo`, `janela pós-pulo expirou`,
  `mesma parede`, `SP insuficiente`, `SP exausto`).
- **origem do ar**: `JUMP` (pulou) ou `FALL` (caiu de borda). Wall jump só com `JUMP`.
- **invulnerável**: `SIM` durante os 0,15 s iniciais do dodge.
- **transições / eventos**: as últimas trocas de estado (com motivo) e os últimos eventos/técnicas.

---

## Parte 1: controller base (arena livre ou largada do percurso)
1. **Andar**: segure W. A velocidade horizontal estabiliza em **6,00 m/s**, no estado `Run`.
2. **Sprint**: toque W duas vezes rápido (até 0,25 s) e segure. Deve chegar a **10,00 m/s** (`Sprint`), com o SP caindo **12 por segundo**.
   - Um toque só = anda. Soltar o W encerra o sprint.
   - Correndo, o personagem vira **na hora** para onde a câmera aponta, sem perder velocidade
     (`sprint_instant_turn`). Andando, vira com aceleração normal.
3. **Regeneração**: solte o W. O SP fica parado por **0,6 s** e depois sobe **25 por segundo** até 100.
4. **Exaustão**: faça sprint até zerar o SP.
   - A barra fica vermelha, aparece `EXAUSTO` e o estado volta para `Run`.
   - Sprint, dash e wall jump não funcionam até o SP voltar a **20**.
   - O evento `SP ZERADO` aparece no log, e depois `SP recuperado`.
5. **Pulo**: aperte Space parado. A "altura pés" máxima fica em **≈ 2,20 m**. Space no ar não faz nada (não existe pulo duplo).
6. **Coyote**: ande para fora de uma borda e aperte Space logo em seguida (até 5 ticks). O pulo sai, e a origem vira `JUMP`.
7. **Câmera**:
   - Encoste numa parede e gire a câmera: ela não atravessa a parede.
   - **V** troca de ombro com uma transição suave.
   - O FOV abre um pouco em alta velocidade.

## Parte 2: percurso de treino
O cronômetro começa ao **sair da área de largada** e para na **zona vermelha no topo da torre**.
Cair no fosso devolve você ao último checkpoint e soma uma queda; o cronômetro continua.
O canto superior direito mostra o melhor tempo da sessão e as técnicas usadas nesta tentativa.

### Trecho 1: corredor de paredes paralelas (fosso de 16 m)
- **Como passar**: corra em sprint (W, W) e entre no corredor em **diagonal** em direção a uma das paredes. Pule na
  linha vermelha e aperte Space a cada parede tocada (zigue-zague).
- **O que observar**:
  - Cada salto sai **espelhado**: o ângulo de entrada é igual ao de saída. Cada um custa **18 SP**.
  - A faísca sai na cor branca.
  - Você **ganha altura** a cada salto (≈ 1,5 m), atravessa em 3–4 wall jumps e cai na pista do trecho 2.
- **Para conferir**: o ajuste da câmera é **fino**.
  - Olhando reto pelo corredor, o salto puxa um pouco para a frente, mas ainda quica na parede oposta.
  - Virando a câmera para onde o salto vai levar, o zigue-zague fica mais limpo.
- **Teste negativo**: pular reto, sem tocar as paredes, cai no fosso.

### Trecho 2: vão largo (8 m) com parede lateral → **side jump**
- **Como passar**: na pista, corra em sprint em **diagonal para a esquerda**, rumo à parede de metal. Pule na
  linha azul, toque a parede e aperte Space.
- **O que observar**:
  - O salto lança **para a frente** por cima do vão, com faísca e brilho **azul elétrico**.
  - O banner mostra `SIDE JUMP` e o contador de side jump sobe.
- **Teste negativo**: sprint + pulo reto (sem a parede) **não alcança** o outro lado. Isso confirma que o vão exige o side jump.
- **Ajuste fino**: o peso da câmera é `wall_jump_camera_weight` (padrão 0,3). Olhar para a frente no salto
  estica a distância.

### Trecho 3: borda de 3,6 m → **reverse wall jump**
- **Como passar**: corra até a borda e pule a ~2 m dela, para tocar a parede perto do **ápice**. Aperte Space
  **logo que encostar** (janela justa: 6 ticks ≈ 0,1 s).
- **O que observar**:
  - Com os pés perto do topo, o HUD de debug mostra `topo: perto`.
  - O salto vai **para a frente e por cima** da borda.
  - A cor é **violeta** e o banner mostra `REVERSE WALL JUMP`.
- **Testes negativos**:
  - Encostar e apertar Space **tarde** dá um wall jump normal, que quica para trás.
  - Pular de longe e tocar baixo também dá o salto normal.

### Trecho 4: parede lisa de 4,4 m → **back-coming** + reverse
- **Como passar**:
  1. Encoste na parede segurando W. Pule e aperte Space de novo **logo em seguida** (pés a menos de 1 m do
     chão, janela de 6 ticks). Isso é o **back-coming**, com cor **verde ácido**: você sobe colado na parede.
  2. Perto do alto (o HUD mostra `topo: perto`), aperte Space mais uma vez. Esse segundo wall jump na
     **mesma parede** é liberado pelo back-coming e, perto do topo, vira **reverse**, que leva por cima.
- **O que observar**: o segundo salto acontece mesmo sendo a mesma parede. Sem o back-coming, o HUD mostra
  `bloqueado: mesma parede`.
- **Teste negativo**: um pulo + wall jump normal não sobe. O pulo simples nunca chega perto do topo de 4,4 m.

### Trecho 5: torre (chaminé) → **wall jumps encadeados**
- **Como passar**: entre na chaminé (entre a parede de metal baixa à esquerda e a alta à direita). Pule em
  direção a uma parede e aperte Space a cada contato, alternando entre as duas.
- **O que observar**:
  - Você sobe ≈ 1,7 m por salto.
  - Ao chegar perto do topo da parede da esquerda, um Space rápido vira reverse e coloca você na **zona
    vermelha (chegada)**.
  - O banner mostra `CHEGADA` com o tempo; um recorde da sessão aparece em verde.
- **SP**: são 3–4 wall jumps (54–72 SP). Se chegar com pouco SP, espere regenerar antes de entrar.

## Parte 3: técnicas fora do percurso (arena livre ou qualquer trecho)
- **Cancel**: aperte **1** (ou 2) **junto** com o Space do wall jump (até 4 ticks antes ou depois).
  - O lançamento é desfeito: você mantém 50% da velocidade de entrada e cai junto à parede.
  - A cor é **vermelha** e o banner mostra `CANCEL`. O SP gasto não volta.
  - Apertar 1/2 sem wall jump só gera o evento `troca de arma` no log.
- **Bunny hop**: corra em sprint, pule e aperte Space de novo **até 3 ticks depois de aterrissar**.
  - A velocidade horizontal se mantém (ex.: 10 m/s mesmo sem segurar Shift).
  - Apertar um pouco antes de tocar o chão ou tarde demais dá um pulo normal, limitado à velocidade do chão.
- **Dash (dodge)**: Shift + A ou D dá um passo rápido para o lado (W/S também funcionam: 8 direções relativas à câmera).
  - Custa 20 SP, deixa um rastro azul e levanta poeira; o personagem continua de frente para a câmera e se inclina.
  - `invulnerável: SIM` dura 0,15 s.
  - Shift sozinho não faz nada (`dodge_requires_direction`).
- **Corrida no ar**: no ar, toque W duas vezes rápido (e segure).
  - Vira na hora para onde a câmera aponta. Acelera até a velocidade de sprint (10 m/s), mas **cai mais rápido** (gravidade ×1,7) e gasta 12 SP/s.
  - O HUD de debug mostra `CORRIDA NO AR`; o personagem mergulha para frente pedalando.
  - Acaba ao aterrissar, ao soltar o W ou com SP zerado. O sprint que vem do chão **não** acelera a queda.
- **Dash no ar**: depois de pular, Shift + direção dá um dash reto (sem cair durante o dash).
  - **Um por pulo**; recarrega ao aterrissar e a cada wall jump. Dá para emendar: wall jump → dash no ar → wall jump.
  - Durante o dash no ar, encostar numa parede e apertar Space já dá wall jump.
  - Ao terminar, você continua caindo com 9 m/s na direção do dash (`air_dodge_exit_speed`).
- **Dodge cancel**:
  - Shift + direção logo ao aterrissar interrompe a recuperação do `Land`.
  - Shift + direção durante a recuperação de outro dash emenda um segundo dash.
  - Durante o deslocamento do dash, um novo Shift não faz nada.
  - O banner mostra `DODGE CANCEL`.

## Parte 3b: personagem e polimento (observar)
- **Personagem**: corredor de armadura com animação procedural.
  - Passada acompanha a velocidade (mais longa e inclinada no sprint); a faixa nas costas levanta com a velocidade.
  - No ar: pose de pulo subindo e braços abertos caindo.
  - Wall jump: giro no ar; reverse: mortal para frente por cima da parede; back-coming: sem acrobacia.
  - Aterrissagem: agacha proporcional ao impacto. O visor e o corpo brilham na cor da técnica.
- **Sensação de velocidade**: acima de 8 m/s surgem linhas de velocidade nas bordas da tela, o FOV abre
  (até +18°), a câmera recua um pouco e treme de leve; tudo cresce até 17 m/s. Ajuste na aba Câmera do F2,
  grupo "Sensação de velocidade".
- **Sombra redonda** embaixo do jogador: use para mirar a aterrissagem e medir a altura.
- **Poeira** ao pular, aterrissar forte e dar dash. **Tremor leve** de câmera no wall jump e em quedas fortes.
- Ajustes: aba **Visual** do F2 (animação, poeira, sombra) e aba **Câmera** (tremor).

## Parte 4: ajustes ao vivo (F2)
1. Aperte **F2**: o mouse é solto e o personagem para de receber input.
2. Mude `walk_speed` para 8 e feche: andar agora dá 8 m/s, sem reiniciar.
3. **Salvar no .tres** grava a aba atual (Movimento ou Câmera) **com todos os valores** em `config/*.tres`.
4. **Recarregar** volta ao que está salvo no disco. **Padrões** restaura os valores de fábrica, sem salvar.
5. Feche o jogo e abra `config/movement_config.tres` num editor de texto: os valores salvos estão lá.

### Onde mexer para cada sensação
| Sensação | Valores |
|---|---|
| Velocidade no chão | `walk_speed`, `sprint_speed`, `ground_acceleration`, `ground_deceleration` |
| Pulo "flutuante" × "seco" | `jump_height`, `jump_time_to_apex`, `fall_gravity_multiplier` |
| Controle no ar | `air_acceleration` |
| Corrida no ar | `air_sprint_enabled`, `air_sprint_acceleration`, `air_sprint_gravity_multiplier`, `air_sprint_sp_cost_per_second` |
| Sensação de velocidade (aba Câmera) | `speed_fx_start_speed`, `speed_fx_full_speed`, `speed_lines_max_alpha`, `speed_arm_bonus`, `max_speed_fov_bonus`, `speed_shake_trauma` |
| Dash no ar | `dodge_allow_in_air`, `air_dodge_max_per_air`, `air_dodge_refresh_on_wall_jump`, `air_dodge_suspends_gravity`, `air_dodge_exit_speed` |
| Sprint por toque duplo | `sprint_double_tap_ticks`, `sprint_forward_threshold` |
| Força do wall jump (altura 2,6 m; saída ×1,1 + 2 m/s para frente, até 18 m/s) | `wall_jump_forward_boost`, `wall_jump_height`, `wall_jump_horizontal_multiplier`, `wall_jump_min/max_horizontal_speed` |
| Quanto a câmera influencia o side jump | `wall_jump_camera_weight` |
| Facilidade das técnicas | `technique_window_ticks`, `cancel_window_ticks`, `bunny_hop_window_ticks` |
| Altura do reverse / back-coming | `reverse_probe_height`, `reverse_jump_height`, `back_coming_height`, `back_coming_max_feet_height` |
| Economia de SP | `sp_*`, `dodge_sp_cost`, `wall_jump_sp_cost`, `sprint_sp_cost_per_second` |

## Checklist do critério de pronto
- [ ] Completei o percurso usando wall jump (corredor/torre), side jump (vão), reverse (borda) e back-coming (parede lisa).
- [ ] Todos os números relevantes aparecem no F2 e no `config/movement_config.tres`.
- [ ] `tools/run_tests.sh` passa.


---

# Fase 5 — Combate (arena de combate)

## Parte 5: personagem e animação
1. Parado: postura de prontidão com a arma baixa à frente, respiração leve e o cabelo se mexendo.
2. Andando/correndo: quadril e tronco giram em sentidos opostos, o corpo inclina nas curvas, a lâmina vai
   para trás no sprint, o cabelo é jogado para trás pelo vento.
3. Pulo: a pose muda de forma contínua entre subindo (encolhido) e caindo (pernas buscando o chão).
4. Ao aterrissar forte o corpo afunda e volta com leve balanço (molas). Nada deve "estalar" de uma pose para outra.
- Ajustes: F2 → aba **Visual**, grupo "Molas da animação" (frequência maior = mais seco; amortecimento menor = mais balanço).

## Parte 6: golpes no poste
Ande até os três postes à frente (POSTE).
1. **Combo leve** (Lâmina de Arco): clique 3 vezes no ritmo → corte direito, corte de volta, golpe descendente.
   - Números de dano saem do poste, ele balança, a lâmina deixa rastro ciano, há uma pausa curta no impacto (hitstop)
     e a câmera treme de leve. O HUD da direita conta os hits, o dano do combo e o DPS.
   - Clicar rápido demais não pula etapas: o próximo golpe sai quando o atual permite (clique fica guardado ~0,16 s).
2. **Pesado** (botão direito): giro 360° que acerta em volta (teste com um poste atrás de você). Gasta 15 SP.
   No meio do combo leve, o botão direito vira finalizador.
3. **Troca de arma**: 2 (ou Q). Floreio da arma, flash e som de carga. A **Presa de Fase** tem combo de 4
   golpes rápidos, anda ~8% mais rápido e o pesado (lâmina ascendente) lança para cima.
4. **Mira assistida**: mire perto do poste (até ~55° de diferença, até 6 m) — o golpe vira sozinho para ele.

## Parte 7: golpes com movimento
1. **Golpe aéreo**: pule e clique → o personagem sobe um pouco e mergulha cortando. Suba na plataforma alta
   (rampa à esquerda) e mergulhe no poste lá em cima.
2. **Estocada no dash**: Shift + direção e clique durante o dash → avanço longo e rápido.
3. **Wall jump + golpe**: na chaminé (paredes de metal à direita), faça wall jumps e clique no ar.
4. **Poste móvel**: acompanhe o poste que vai e volta; use a mira assistida e a estocada.

## Parte 8: cancels e defesa
1. **Dodge cancel**: logo depois de um golpe acertar (na recuperação), Shift + direção → o dash interrompe a
   recuperação. Aparece `DODGE CANCEL`.
2. **Swap cancel**: na recuperação de um golpe, aperte 1/2/Q → a arma troca e a recuperação acaba na hora.
   Aparece `SWAP CANCEL` (dourado). Na preparação do golpe não funciona (é proposital).
3. **Poste agressivo** (área vermelha à direita): a cada ~2,6 s o anel do poste pisca vermelho com bipes e ele
   gira o braço acertando quem estiver na área (10 de dano, recuo).
   - Levando o golpe: a tela treme, o personagem recua (estado `Hurt`), a barra VIDA desce.
   - **Esquiva perfeita**: dê um dash no instante do golpe (0,15 s de invencibilidade) → nenhum dano,
     brilho branco e som de "cintilar". Aparece `PERFECT DODGE` no log.
   - Com a vida zerada: fica caído ~1,5 s e volta ao início com vida cheia.

## Parte 9: sons
Com som ligado, confira: zumbido de plasma nos cortes da Lâmina, sibilo curto na Presa, impacto elétrico no
acerto (mais grave no pesado), passos que aceleram com a corrida, pulo, aterrissagem, wall jump, dash,
carga ao trocar de arma, sino ao acertar técnica, bipes do poste agressivo.
- Volumes: F2 → aba **Áudio**. Para mudar o timbre: edite `tools/gen_sfx.py` e rode `python3 tools/gen_sfx.py`.

## Onde mexer (F2)
| Sensação | Aba / valores |
|---|---|
| Dano, alcance, velocidade de cada golpe | aba da arma → cada golpe: `damage`, `reach`, `arc_deg`, `startup`, `active`, `recovery`, `chain_after` |
| Peso do impacto | `hitstop` do golpe; aba Câmera → `shake_on_hit` |
| Avanço do golpe / estocada | `lunge_speed` do golpe |
| Golpe aéreo (flutuar e mergulhar) | `air_start_vertical_speed`, `air_active_vertical_speed`, `air_gravity_scale` |
| Mira assistida, buffer do clique, vida | aba Combate |
| Postes | `config/dummy_config.tres` (vida, recuperação, intervalo e aviso do agressivo) |
