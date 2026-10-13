# REBELLIUM — Contexto completo do projeto

Documento de passagem de bastão. Descreve **o jogo como está hoje** na branch
`claude/lucid-ramanujan-wy8xe5`, como o código se organiza, como se trabalha com o dono e o que está em aberto.
Em caso de divergência, **o código e os `.tres` mandam**: `docs/ESCOPO.md` e `docs/ROTEIRO_TESTE.md` são diários
de revisões e têm trechos antigos (ver seção 15). Regras curtas para agentes: `AGENTS.md` (e `CLAUDE.md`).

## 1. Resumo

- **Jogo**: ação acrobática em terceira pessoa, competitiva, 100% melee. **A movimentação é a habilidade principal**:
  quem domina wall jump, side jump, dash e cancels controla o espaço da arena.
- **Estágio**: protótipo jogável **single-player** (sem rede, sem música, arte ainda em evolução). Tudo é original:
  não usar nomes, assets ou termos de outros jogos.
- **Stack**: Godot 4.7.2-stable, GDScript **tipado**, física Jolt a 60 ticks fixos, testes GUT 9.7.1 (headless).
  Blender (módulo `bpy` 4.2.0, Python 3.11) gera por código o personagem, as animações, a arena e a espada.
- **Cena principal**: tela de preparação (`scenes/ui/Loadout.tscn`), com cinco mapas. A SkyArena
  conserva o caçador que reage e é arremessado pelo golpe pesado. O Revezamento é a arena do
  modo Touch Down: estação em oito (bases em quarto de círculo nas pontas, passarelas altas,
  voltas em U descendo ao trem no nível baixo, ponte alta com o núcleo no meio, escadas rolantes).
- **Qualidade**: 238 testes GUT passando e abertura headless sem erros nesta revisão.
- **Repositório**: `github.com/hugolnieri/Rebellium` (alguns commits do dono via Codex, como `614b4e2`). **Só existe uma branch no GitHub e ela é a padrão:
  `claude/lucid-ramanujan-wy8xe5`** (não há `main`).
- **Dono do projeto**: GitHub `hugolnieri`; fala português; testa no Windows (`C:\Dev\Rebellium`).

## 2. Como se trabalha com o dono

- **Idioma**: português, informal e direto. Respostas curtas, sem enrolação; listar no fim as decisões tomadas.
- **Pedidos**: costumam vir curtos, com uma imagem/desenho de referência. Trate o desenho como especificação. Quando
  houver ambiguidade, escolha a leitura mais provável, implemente e diga qual leitura usou (o dono corrige depois).
- **Ciclo**: o dono descreve a mudança → o agente implementa, roda os testes, commita e dá push → o dono puxa no Windows,
  joga e devolve feedback ("não ficou legal", "tá difícil de fazer X"). Desfazer um experimento que não agradou é normal
  e rápido (já aconteceu com passada agachada, calcanhar, reverse wall jump).
- **Como o dono atualiza o jogo** (não é especialista em git; dê sempre estes comandos prontos):
  ```
  cd C:\Dev\Rebellium
  git fetch origin
  git reset --hard origin/claude/lucid-ramanujan-wy8xe5
  ```
  Depois: fechar o Godot, **apagar a pasta `.godot`**, abrir o projeto, esperar importar e apertar F5.
  "Não mudou nada" quase sempre é cache do `.godot` ou não ter puxado.
- **Convenções de commit**: mensagem em português, título curto com prefixo do assunto (`arena: ...`, `fase-N: ...`),
  corpo em tópicos. Antes de commitar: `tools/run_tests.sh` passando e `godot --headless --quit-after 120` sem erros.
  O fluxo estabelecido é commit direto na branch padrão (o dono puxa dela). Não reescreva histórico; só abra PR se pedirem.
- **Documentação a cada revisão**: nova seção "Revisão: ..." em `docs/ESCOPO.md`, passos de teste em `docs/ROTEIRO_TESTE.md` e, se o
  estado do jogo mudou, este arquivo.
- **Preferências de design recorrentes**: movimento fluido e responsivo (virar na hora para a câmera, sem travar ao golpear);
  animação "natural" e feita à mão no Blender, não por filtros; números ajustáveis ao vivo (F2); nada de número mágico.

## 3. Ambiente e comandos

```bash
tools/install_godot.sh                       # instala o Godot 4.7.2 e cria o comando `godot` (Linux x86_64)
tools/run_tests.sh                           # importa o projeto e roda TODOS os testes (sai != 0 se falhar)
tools/run_tests.sh -gselect=test_sky_arena.gd   # um arquivo só
godot --headless --quit-after 120 --path .   # checagem de abertura sem erros
godot --path .                               # roda o jogo
godot --headless --import                    # reimporta (obrigatório após mudar glb/blend ou criar class_name novo)
python3 tools/gen_sfx.py                     # regera os sons (assets/sfx); requer numpy
python3 tools/blender/build_hero.py          # recria hero.blend + hero.glb (APAGA edições manuais do .blend)
python3 tools/blender/export_hero.py         # só exporta o hero.blend editado → hero.glb
python3 tools/blender/build_sky_arena.py     # recria a arena (art/arena/sky_arena.blend + assets/arena/sky_arena.glb)
python3 tools/blender/build_sword.py         # converte art/weapons/arc_blade_source.usdz → assets/weapons/arc_blade.glb
python3 tools/import_vroid.py arquivo.vrm nome   # personagem do VRoid Studio → assets/character/models/nome.glb (Pillow)
```

- Scripts do Blender: `pip install bpy==4.2.0 numpy` (a roda do bpy 4.2 exige **Python 3.11**; ~300 MB). Sem isso, tudo
  continua funcionando — só não dá para regenerar personagem/arena/espada. Os `.glb`/`.blend` já estão versionados.
- Se o ambiente do agente bloquear internet depois do setup, instale Godot e dependências no script de setup.
- `.gitignore`: `.godot/`, `*.blend1`, `__pycache__/`, `tools/.cache/`. `.gitattributes`: texto com `eol=lf`.

## 4. Controles

| Tecla | Ação |
|---|---|
| WASD | mover (relativo à câmera) |
| Mouse | olhar (clique captura o mouse; Esc solta) |
| Space | pular / wall jump |
| W, W (toque duplo) e segurar | sprint; no ar vira corrida no ar |
| Space + A/D | dash lateral (Space de novo no dash = cancela e pula; no ar planando, cancela o dash) |
| Botão esquerdo (ou J) | toque = golpe leve (sai ao **soltar**; cliques seguidos = combo); **segurar = golpe pesado**; no ar = **mergulho** |
| Botão direito (ou K) | golpe pesado direto |
| 1 / 2 / Q | Lâmina de Arco / Presa de Fase / alterna (junto do Space do wall jump = **cancel**) |
| V | troca o ombro da câmera |
| F1 / F2 / F3 / F4 | HUD de debug / menu de ajustes ao vivo / seleção de mapas / **menu de personagem** (modelo e cores) |
| R | reinicia (volta ao início; zera cronômetro no percurso e o bot/postes nas arenas) |

O mapa de input está em `project.godot`; **só `scenes/player/input_reader.gd` toca em `Input`**.

## 5. Arquitetura do código

**Autoloads**: `GameEvents` (sinais), `SceneCycler` (F3), `SoundManager`, `CharacterMenu` (F4, `scenes/ui/character_menu.gd`).

**Player** (`scenes/player/player.gd`, `CharacterBody3D`; origem do corpo nos pés; cápsula r 0,4 × h 1,8). Fluxo por tick:
`input → SP.update → estado.physics_update → move_and_slide → wall_sensor.update → estado.post_move → _update_visual`.
O `step(input, delta)` é público: os testes dirigem o Player tick a tick com `external_control = true`.
**O corpo do Player nunca gira** (rotação sempre identidade): movimento, câmera e visual usam o yaw do **mundo**, e
`visual.rotation.y` recebe um yaw mundial. Por isso `Player._place` (usado em `_ready` e em `respawn`) põe só a posição no corpo
e o yaw no `visual`. **A câmera (`PlayerCamera`) também nunca herda rotação**: ela é `top_level`, só os nós `Yaw`/`Pitch` giram
(com o `look_yaw`) e `_follow` zera a rotação do centro a cada quadro. Nenhuma cena instancia o Player girado.

**Máquina de estados explícita**, um script por estado em `scenes/player/states/`:
`Idle, Run, Sprint, Jump, Fall, WallJump, Dodge, Land, Attack, Hurt`. Toda troca passa por
`StateMachine.transition_to(nome, motivo)`, que loga e emite `GameEvents.state_changed`.

**Camada de dados/regras puras** (`scripts/core/`, sem dependência de cena, testáveis):
`WallJumpMath`, `MovementRules`, `SPPool`, `CombatRules`, `HealthPool`, `PlayerInput`, `ConfigIO`, `MeshFactory`, `GreyboxBlock`.

**Configs (Resources, em `config/`)** — todo número de gameplay mora aqui; cada valor é um `@export` (com `@export_group`
e `@export_range`) e aparece sozinho no F2:

| Arquivo | Classe | Conteúdo |
|---|---|---|
| `movement_config.tres` | `MovementConfig` | corpo, chão, pulo, SP, dash, wall jump, técnicas, rolamento |
| `camera_config.tres` | `CameraConfig` | câmera, FOV, tremor, sensação de velocidade |
| `feedback_config.tres` | `FeedbackConfig` | cores, VFX, personagem (ex.: `anim_blend_time` 0,14, `attack_blend_time` 0,06) |
| `combat_config.tres` | `CombatConfig` | vida, buffers, mira assistida, dano recebido |
| `weapons/<arma>/weapon.tres` + um `.tres` por golpe | `WeaponConfig`, `AttackData` | tempos, dano, alcance, arco, hitstop |
| `dummy_config.tres` | `DummyConfig` | postes/caçador: vida, regeneração, patrulha, ataque do agressivo e o **arremesso do caçador** (aba Alvos do F2) |
| `audio_config.tres` | `AudioConfig` | volumes |
| `character_look.tres` | `CharacterLook` | aparência padrão (modelo e cores; **não é gameplay**, o jogador salva a dele em `user://personagem.tres`) |

**Salvar config sempre com `ConfigIO.save_full`** (grava todos os valores; o `ResourceSaver` padrão omite os iguais ao padrão).

**Feedback por eventos**: a lógica emite sinais em `GameEvents` (`wall_jump_executed`, `technique_executed`, `attack_started`,
`hit_landed`, `dummy_warning`, ...). VFX (`scenes/player/feedback/feedback_vfx.gd`), som (`SoundManager`), HUD e modo treino só ouvem.

**Alvos de golpe**: grupo `hittable` com `take_hit(info) -> bool`, `get_hit_center()`, `get_hit_radius()` (Player, `TrainingDummy` e `HunterBot`).
**Hitstop** pausa a simulação do Player (`hitstop_ticks`); os tempos do golpe contam em ticks próprios do estado Attack.
**Tempo de gameplay** em ticks (int) quando a janela é justa (cancel); em segundos (float) para durações longas.
`physics_interpolation` está ligada: ao teleportar um corpo chame `reset_physics_interpolation()`.

**Apresentação (nunca altera gameplay)**: `character_model.gd` (modelo + animação), `hero_clips.gd`, `hero_puppet.gd` (o mesmo
esqueleto e os mesmos clipes, para o caçador), `attack_poses.gd`,
`weapon_visual.gd`, `weapon_trail.gd`, `player_camera.gd`, shaders `anime_toon.gdshader`, `outline.gdshader`, `speed_lines.gdshader`,
`blob_shadow.gd` (sombra redonda).

## 6. Movimentação (valores de `config/movement_config.tres`)

Regras de design registradas (de `ESCOPO.md`, ainda válidas):
- **Wall jump** só se o jogador entrou no ar por um pulo (ou wall jump) e ainda está em Jump ou dentro da janela pós-pulo
  (1,2 s). Cair de borda nunca habilita. **Dash no ar também bloqueia** até o próximo pulo do chão (`wall_jump_after_air_dash`
  desligado; F1 mostra "usou dash no ar"): o wall jump só vale com o pulo normal. A mesma parede não vale duas vezes seguidas.
- **Reflexão**: `v_out = v_in − 2 (v_in·n) n` no plano horizontal; o impulso vertical é somado à parte; a câmera ajusta a saída
  com peso (0,4) sem apontar para a parede. Saída ×1,25 (mín. 10, máx. 18 m/s) + 2 m/s para frente.
- **Impulso inicial** do wall jump ×1,6 que decai até a velocidade normal em 0,6 s.
- **Side jump**: wall jump com incidência ≥ 30° lança para a frente (faísca azul elétrico).
- **Cancel** (tecla 1/2 até 4 ticks do wall jump): desfaz o lançamento, mantém 50% da velocidade de entrada; SP não volta.
- **Pulo após aterrissar**: usa a velocidade normal do chão; não há janela de preservação de velocidade.
- **Dodge cancel**: dash interrompe a recuperação do Land e do próprio Dodge; golpe também corta o dash.

| Tema | Valor atual |
|---|---|
| Chão | andar 6 m/s, sprint 10 m/s (toque duplo em W em ≤ 15 ticks), aceleração 60, desaceleração 120 m/s²; vira na hora para a câmera (andando, correndo e no ar) |
| Pulo | altura 2,35 m, subida 0,38 s, gravidade de queda ×1,6, velocidade terminal 30 m/s, coyote 5 ticks, buffer 4 ticks; o pulo do chão volta à velocidade de andar |
| Corrida no ar | aceleração 30, gravidade ×1,7, 12 SP/s |
| SP | 100; regenera 25/s após 0,6 s; exaustão até voltar a 20; dash 20, wall jump 18, sprint 12/s |
| Dash (dodge) | só lateral (limiar 0,75), 30 m/s no início que decai (curva 2,2), 0,65 s, invulnerável 0,15 s, recuperação 0,25 s, sai a 7 m/s com deslize final 14 m/s²; dash jump mantém 70%; **a direção segue a câmera** durante o dash e o deslize (`dodge_follows_camera`: dash para a esquerda continua à esquerda da câmera enquanto ela gira) |
| Dash no ar | 1 por pulo (recarrega no wall jump); planeia na 1ª metade (55% do tempo, gravidade ×0,12); sai a 9 m/s; Space cancela |
| Wall jump | custo 18 SP, altura 2,6 m, cola na parede 6 ticks (mortal para trás depois), sem controle 0,3 s, golpe bloqueado 0,45 s, pode encadear a partir de 0,08 s somente enquanto sobe |
| Detector de parede | alcance 0,2 m, normal máx. y 0,35, tolerância de 4 ticks |
| Pouso | queda ≥ 7 m/s → cambalhota **no lugar** (0,7 s); segurando direção ela rola para lá a 6 m/s; dash/golpe no ar cancelam o pouso |
| Corpo | cápsula r 0,4 × h 1,8; chão até 46°; `floor_snap_length` 0,3; **`floor_block_on_wall = false`** (ver seção 17) |

## 7. Combate

- **Valores globais** (`combat_config.tres`): vida 100, respawn 1,5 s, buffer do clique 20 ticks, **pesado = segurar o clique
  esquerdo por 16 ticks (~0,27 s)**, troca de arma 0,25 s, combo expira em 1,4 s, hitstun 0,35 s, mira assistida **desligada**
  (alcance 6, ângulo 55° se ligar), o golpe não trava o movimento (`attack_move_speed_multiplier` 1,0), pular durante o golpe
  mantém o golpe (`attack_jump_cancel`), golpe corta o impulso do dash.
- **Lâmina de Arco** (`config/weapons/arc_blade/`, ciano): combo leve de 3 — "Corte direito" (`slash_r`), "Corte de volta" (`slash_l`),
  "Golpe descendente" (`overhead`); pesado "Giro de arco" (`spin`, giro 360° para a direita, 15 SP); no pulo "Queda cortante"
  (`air.tres`, mergulho, 26 de dano); dash "Estocada relâmpago" (`dash_thrust`). Apoiada no ombro parado/andando (`rest_on_shoulder`).
- **Presa de Fase** (`config/weapons/phase_fang/`, laranja): adaga curva, anda ×1,08, combo leve de 4 — "Furada" (`jab`), "Corte reverso"
  (`backhand`), "Furada dupla" (`jab`), "Corte crescente" (`slash_r`); pesado "Lâmina ascendente" (`rising`, 12 SP, lança para cima);
  no pulo "Mergulho de fase" (`air.tres`, mergulho, 20 de dano); dash "Bote" (`dash_thrust`). Fica na mão (sem `rest_on_shoulder`).
- **Golpe no pulo = mergulho** (qualquer clique no ar: toque, segurar ou botão direito; também caindo ou saindo de wall jump):
  congela no ar onde clicou (`plunge_hover_time`, a espada sobe), desce reto com tudo (`plunge_speed` 32/36 m/s), acerta quem estiver
  embaixo/em volta no impacto (`plunge_impact_radius`), e fica **preso no chão** ajoelhado com a espada cravada até levantar
  (`plunge_landing_time` 0,55/0,45 s; sem dash, pulo, troca nem golpe). Valores no grupo "Mergulho" de cada `air.tres`.
- **Golpe no meio do dash no ar** conta como golpe de chão: combo leve normal (ou o pesado do chão), a velocidade cai para a de um
  pulo normal e, sem direcional, freia até parar no lugar do golpe (`air_dash_attack_stop_deceleration` 40 m/s²); a gravidade é a
  normal. Os cliques seguintes continuam o combo leve. No dash do chão o golpe continua sendo a estocada do dash.
- **Ritmo dos golpes**: recuperação ×1,4 do original e `chain_after = startup + active + 0,8·recovery` (ex.: `light_1` da Lâmina:
  startup 0,176 s, active 0,117 s, recovery 0,666 s, chain_after 0,826 s, dano 12, alcance 2,4 m, arco 150°).
- **Cancels**: dodge cancel e **swap cancel** (trocar de arma na recuperação); dash com invencibilidade contra golpe = **esquiva perfeita**.
- **Sensação de impacto**: hitstop, faíscas na cor da arma, tremor de câmera, números de dano, rastro (`weapon_trail.gd`).
- **Estado Hurt**: recuo e hitstun; vida zerada = caído ~1,5 s e volta ao início.
- **`TrainingDummy`** (`scenes/arenas/training_dummy.gd`, `AnimatableBody3D`): modos `STATIC`, `PATROL`, `AGGRESSIVE` (contra-ataca em
  área com aviso vermelho: 10 de dano, recuo). Mostra vida, números de dano e balança. Vida 300, regenera após 2,5 s.
  Exports de corpo: `body_color`, `title`. Pontos de extensão para subclasses: `_build_body()`, `_label_text()`, `_react(info)`
  (reação ao golpe; o poste balança) e `reset_target()`.
- **Caçador** (`scenes/arenas/HunterBot.tscn` + `hunter_bot.gd`, `class_name HunterBot extends TrainingDummy`): o bot vermelho,
  título "CAÇADOR". O corpo é um `HeroPuppet` (o `hero.glb` com os clipes do Blender, pintado de vermelho). **Não ataca**: reage,
  e **só o golpe pesado o arremessa**. Fases (`HunterBot.Phase`): `IDLE` (clipe `idle`; bloqueia o jogador) → `STAGGER` (golpe
  leve/aéreo/dash: clipe `hurt` e desliza = recuo horizontal × `hit_slide_scale`) → `LAUNCHED` (golpe pesado: voo balístico com
  velocidade = recuo do golpe × `launch_velocity_scale`, subida mínima `launch_min_up_speed`, gravidade `launch_gravity`; clipe
  `launched` amostrado pelo progresso do voo; raios detectam parede (rebote `launch_wall_bounce`), teto e chão) → `DOWN` (clipe
  `knockdown`; desliza com atrito `slide_friction` e fica `knockdown_time` deitado) → `GETUP` (clipe `getup`) → volta
  **teleportando** ao spawn do caçador (espera enquanto o jogador estiver a menos de 1,2 m dele) com um brilho branco. Voando,
  deitado ou levantando a colisão dele fica desligada (o jogador atravessa). A etiqueta mostra `ARREMESSO x,x m` (distância do último
  arremesso, para comparar a força dos golpes). Cair da plataforma (`fall_respawn_height`) o devolve ao spawn. Os números ficam no
  grupo "Arremesso (caçador)" do `DummyConfig`. `HunterBot.step(delta)` é público: os testes avançam o bot tick a tick.

## 8. Personagem e animações

- **Modelo**: base VRoid "HairSample_Male" (**CC0**, ver `assets/character/CREDITS.md`) editada por `tools/blender/build_hero.py`:
  traje azul-marinho de gola alta com emblema, cabelo branco, olhos cinza, descalço. Fonte editável: `art/character/hero.blend`;
  o jogo carrega `assets/character/hero.glb` (malha + esqueleto + animações). Altura do modelo 1,91 m, escalado para 1,8 m.
- **Animações** = Actions do Blender definidas como poses-chave em `tools/blender/hero_animations.py` (Bezier, ciclos sem emenda,
  clavículas, dedos). **Clipes (o jogo procura pelo nome — não renomeie)**: `idle, walk, sprint, air_sprint, air, jump_flip,
  wall_stick, wall_flip, roll, cartwheel, dash, land, hurt, sword_rest`, os do caçador `launched` (0,8 s), `knockdown` (0,6 s) e
  `getup` (1,1 s), `plunge_land` (impacto do mergulho: ajoelhado, espada cravada, levanta) e os golpes `atk_<anim>`:
  `atk_slash_r, atk_slash_l, atk_overhead, atk_backhand, atk_spin, atk_air_slam, atk_dash_thrust, atk_jab, atk_rising`.
- **Runtime**: `hero_clips.gd` (`HeroClips`) converte cada clipe uma vez em quadros a 60 Hz (um `Quaternion` por osso animado +
  posição do quadril; ignora `Root`, `HairJoint*`, `J_Sec*`, `J_Adj*`). O jogo amostra por **tempo normalizado** (fase da passada,
  progresso do dash, fases do golpe). `character_model.gd` faz crossfade nas trocas (`anim_blend_time` 0,14 s; golpes 0,06 s),
  posiciona o soquete da arma a partir do osso da mão direita (`J_Bip_R_Hand`) e mistura parte do corpo no golpe andando
  (pernas seguem a passada). **Giros de corpo inteiro** (mortal do pulo, estrela do dash, mortal do wall jump, giro do pesado) são
  feitos em código no nó `_trick` (o osso `Root` no Blender é só prévia).
- **Qualquer personagem do VRoid**: os clipes saem sempre do `hero.glb`, mas `HeroClips.bind(esqueleto, quadril)` liga as poses a
  outro esqueleto **pelo nome dos ossos** (`HeroClips.Binding`): todo modelo do VRoid tem os mesmos `J_Bip_*` em T-pose com descanso
  neutro (o hero.glb também), então a rotação local vale direto; o quadril escala com a altura e modelos virados para +Z (VRM 1.0)
  são espelhados e girados 180°. Todo modelo é escalado para a mesma altura do herói (altura da cabeça em T-pose).
- **Menu de personagem (F4, autoload `CharacterMenu`, `scenes/ui/character_menu.gd`)** → `CharacterLook` (`scripts/core/character_look.gd`,
  padrão `config/character_look.tres`, salvo por jogador em `user://personagem.tres` ao fechar o menu): modelo (o herói ou os `.glb`
  de `assets/character/models/`), tintas de cabelo, pele e olhos (branco = original) e, só no herói, cores do traje, costuras e emblema.
  O traje do herói é recolorido no shader toon pela máscara `assets/character/hero_suit_mask.png` (gerada por `build_hero.py`:
  R = traje, G = costuras, B = emblema; fora do traje = pele), pela razão cor escolhida/cor original (mantém dobras e sombras).
  `CharacterModel.apply_look()` troca o corpo (recria a arma na mão nova) e as cores. Nos testes (controle externo) vale a aparência padrão.
- **Trazer um personagem do VRoid Studio**: exportar em VRM → `python3 tools/import_vroid.py arquivo.vrm nome` (só Python + Pillow)
  → `assets/character/models/nome.glb` (texturas reduzidas, nomes das expressões preservados para piscar, extensões do VRM tiradas)
  → aparece no F4. Já vem um: `vroid_casual` (o HairSample_Male CC0 com a roupa original do VRoid: moletom, calça e tênis).
- **Caçador**: `hero_puppet.gd` (`HeroPuppet`) instancia o mesmo `hero.glb`, liga os clipes (`HeroClips.bind`) e expõe
  `show_clip(chave, clipe, u, loop, delta)` (amostra o clipe por tempo normalizado e faz crossfade quando a `chave` muda) e `paint(material)`.
- A inclinação do corpo ao andar e no sprint vem das **poses do Blender** (`dodge_lean_deg`, 22°, controla a do dash). As molas de
  animação foram removidas — só o cabelo ainda balança por mola.
- **Editar animação**: abrir `art/character/hero.blend` → Action Editor → mexer na pose → aba Scripting → `exportar_para_o_jogo.py`
  → Run Script → o Godot reimporta o `hero.glb`. Rodar `build_hero.py` de novo **apaga** essas edições manuais.
- **Verificação visual**: capturas de tela do Godot em headless são pouco confiáveis; as animações foram verificadas por renders
  do Blender (Cycles, pois Workbench precisa de libEGL). O jogo real também dá para capturar sem GPU: `xvfb-run` +
  `LIBGL_ALWAYS_SOFTWARE=1 godot --display-driver x11 --rendering-method gl_compatibility ...` rodando uma cena temporária dentro do
  projeto (scripts `-s` não enxergam os autoloads); salve com `get_viewport().get_texture().get_image()` após `frame_post_draw`.

## 9. Armas (visual)

- **Lâmina de Arco**: modelo 3D **enviado pelo dono** (`art/weapons/arc_blade_source.usdz`, 12 MB), convertido por
  `tools/blender/build_sword.py` em `assets/weapons/arc_blade.glb` (1,25 m, malha decimada para ~35 mil triângulos, texturas 1024,
  1,2 MB). `weapon_visual.gd` instancia o glb, acrescenta um halo de energia que acende nos golpes e define os pontos do rastro.
  O material é escuro (clarear foi oferecido, o dono não respondeu).
- **Presa de Fase**: procedural (primitivas) em `weapon_visual.gd`.
- **Origem/licença da espada não está registrada** no repositório (`CREDITS.md` cobre só o personagem): confirmar com o dono.

## 10. Arena flutuante (`SkyArena`) — estado atual

Gerada por `tools/blender/build_sky_arena.py` (malhas, UVs e texturas por código/numpy) → `art/arena/sky_arena.blend` +
`assets/arena/sky_arena.glb`. **Todas as medidas são constantes no topo desse script**; mudar uma e rodar o script regenera tudo.

**Desenho do dono (legenda de cores usada nas conversas)**: vermelho = borda do mapa e as 4 travessas; azul = 4 muros curtos em
círculo; roxo = muro central; verde = passagens no roxo (com teto); amarelo = chão externo; laranja = chão interno; preto = base central.

| Elemento | Posição (m, a partir do centro) | Grossura | Altura acima do chão local |
|---|---|---|---|
| Borda vermelha (mureta) | r 24,5–26 | 1,5 | 2,25 (topo absoluto 3,45) |
| 4 travessas vermelhas | radiais de r = 20 até a borda, nos eixos ±X e ±Z do Godot | 0,6 | 2,25 |
| 4 muros azuis | r = 20 (19,7–20,3), 7 m de comprimento (±10°), nas diagonais | 0,6 | 2,25 |
| Muro roxo central | r 13,9–14,5 (centro 14,2) | 0,6 | 4,5 (topo absoluto ≈ 5,1) |
| 4 passagens verdes | no roxo, nas diagonais, 7 m de largura (±14,1°); teto 0,6 de espessura na altura do roxo | — | vão livre ≈ 3,9 |
| Chão em degradê | `h(r) = 1,2·(r−3,9)/20,6` para 3,9 ≤ r ≤ 24,5 (sobe do centro para a borda) | — | — |
| Base preta (centro) | r < 3,9, altura 0 (ponto mais baixo do jogo) | — | — |

- O roxo tem 4,5 m de altura; travessas e azuis têm 2,25 m. Todos os muros internos têm 0,6 m de grossura.
  Só a borda circular mantém 1,5 m de grossura e 2,25 m de altura. O pulo normal (2,35 m)
  passa por cima das travessas, dos azuis e da borda; o roxo pede wall jump ou passagem.
  Historicamente, o roxo baixou de 5,0 para 4,5 m e foi para dentro (antes r 15,5–17); a borda subiu de 1,4 para 2,25 m. Se o dono quiser outra leitura,
  basta ajustar `H_PURPLE`, `H_RED`, `RIM_TOP` no script.
- **Eixos**: Blender (x, y, z) → Godot (x, z, −y). Travessas e portas: Blender 0/90/180/270° = Godot +X/−Z/−X/+Z; muros azuis e passagens:
  45/135/225/315° = diagonais (+X,−Z), (−X,−Z), (−X,+Z), (+X,+Z).
- **Marcadores na cena**: `Spawn` em (8,23; 1,03; 19,86) com yaw 22,5° (olha para o centro; fica entre a travessa +Z e o muro azul
  (+X,+Z) — o spawn antigo em (0; 0,1; 21) cairia em cima de uma travessa; o corpo nasce sem rotação e o yaw vai para o `visual`); `HunterSpawn` em (0; 0; 0) com o `HunterBot` (filho do nó `Dummies`, que o R reinicia).
  Os 4 postes de treino antigos **saíram** desta arena (o dono: "só vai ter ele de bot"); CombatArena e percurso mantêm os deles.
- **Colisão**: objetos com sufixo **`-convcolonly`** no Blender viram `StaticBody3D + ConvexPolygonShape3D` no Godot (sem malha de
  triângulos, que enganchava nas emendas). **313 colisores**: `DeckCol` 96 (chão, topo plano por segmento seguindo o degradê),
  `RimCol` 96 (borda), `PurpleCol` 64 (muro roxo), `LintelCol` 32 (tetos das passagens), `BlueCol` 20, `SpokeCol` 4 (hexaedros) e
  `BaseCol` 1 (disco da base). Os muros e a mureta usam um bloco por segmento de ~3,8°. Paredes e muros começam enterrados
  (z = −1,2) para não deixar fresta no degradê; topo = chão local + altura. O teste exige que **toda** colisão da plataforma seja convexa.
- **Cenário** (`sky_arena.gd` herda de `combat_arena.gd`; nada aqui altera gameplay): céu procedural noturno, luz "Moon", glow e
  névoa; duas camadas de nuvens em shader (`clouds.gdshader`, y −45 e −110); cidade (`city.gdshader`, y −260) e 140 torres em
  `MultiMesh` (`tower.gdshader`, 140–650 m); 3 drones orbitando (r 31), 4 antenas com luz vermelha piscando, 6 propulsores com
  chama tremendo, treliça e cabos no casco; luz ciana no centro e duas luzes de parede (magenta/ciano). Cair da plataforma
  (y < −20) volta ao `Spawn`.
- **Neon**: faixas ciano/laranja/magenta nas faces do roxo, luz sob o teto das passagens, zebrado no chão, anéis no centro e contorno
  ciano na base.
- **Como mexer**: editar constantes de `build_sky_arena.py` → `python3 tools/blender/build_sky_arena.py` → `godot --headless --import`
  → `tools/run_tests.sh -gselect=test_sky_arena.gd`. O teste da arena tem raios/diagonais fixos (muro roxo em r 14,575, portas nas
  diagonais, spawn lido do marcador): atualize-o junto.

## 11. Outras cenas

- **`CombatArena.tscn`**: postes parados, móvel, agressivo e um no alto (plataforma com rampa), HUD de combate (hits, dano do combo, DPS), R reinicia.
- **`TrainingCourse.tscn`**: percurso de movimento com cronômetro, melhor tempo, checkpoints e contador de técnicas: corredor de
  paredes paralelas (fosso de 16 m), vão de 8 m (side jump), borda de 3,6 m e parede lisa de 4,4 m (cada uma com um **pilar** de frente:
  wall jump na face, no pilar e por cima — `LedgePillar` à direita da borda, `WallPillar` à esquerda da parede lisa), torre/chaminé
  (wall jumps encadeados; parede de chegada em 16,5 m). `test_training_course.gd` tem **bots que completam cada trecho** — rode-o ao
  mexer em geometria ou config de movimento.
- **`Arena.tscn`**: arena livre para experimentar.
- Todas incluem HUD, `DebugHUD` (F1) e `DebugMenu` (F2).

## 12. UI e debug

- **HUD**: SP e vida. **DebugHUD (F1)**: estado e tempo no estado, velocidades, altura dos pés, contato de parede, motivo de bloqueio
  do wall jump (`LIBERADO`/`sem parede`/`usou dash no ar`/`não veio de pulo`/`janela pós-pulo expirou`/`mesma parede`/`SP insuficiente`),
  pior quadro do último segundo (`ENGASGO` acima de 33 ms), origem do ar
  (`JUMP`/`FALL`), invulnerabilidade, últimas transições e eventos.
- **DebugMenu (F2)**: gerado a partir dos `@export` das configs (abas Movimento, Câmera, Visual, Combate, uma por arma/golpe, **Alvos** = `dummy_config.tres`, Áudio);
  edita ao vivo, **Salvar no .tres** (usa `ConfigIO.save_full`), **Recarregar**, **Padrões**. Editar `.tres` à mão funciona, mas o F2
  reescreve o arquivo inteiro.
- **Menu de personagem (F4)**: modelo e cores (ver seção 8). Só visual; salva ao fechar.

## 13. Áudio

Sons sintetizados por `tools/gen_sfx.py` (numpy) em `assets/sfx/*.wav` (golpes, impactos, passos, pulo, wall jump, dash, troca de arma,
técnica, esquiva perfeita, dano, aviso do poste, gritinho ao correr). `SoundManager` ouve `GameEvents`; volumes em `audio_config.tres`.
Sem música.

## 14. Testes

`tools/run_tests.sh` (GUT, config em `.gutconfig.json`: pasta `res://tests/`, prefixo `test_`, sai ao terminar).
- **Unitários (7)**: áudio, regras de combate, `ConfigIO`, regras de movimento, setup do projeto, SP, matemática do wall jump.
- **Integração (13)**: pulo após pouso, modelo do personagem (clipes presentes), **customização** (`test_character_customization.gd`: modelo
  do VRoid com os clipes do herói, mesma altura, arma na mão nova, cores nos materiais, menu F4), combate (inclui o mergulho e o golpe
  no dash aéreo), arena de combate, menu de debug, dash (inclui "o dash segue a câmera"), chão,
  **arena flutuante** (inclui "W/A/S/D andam relativos à câmera e o personagem encara para onde anda"), **câmera**
  (`test_player_camera.gd`: a vista segue o `look_yaw` mesmo com o Player instanciado girado), percurso de treino (bots), wall jump e **caçador**
  (`test_hunter_bot.gd`: arremesso, rebote em parede, deslize, volta ao spawn, golpe pesado do Player real).
- **`tests/helpers/player_driver.gd`**: monta o mundo e dirige o Player tick a tick com `PlayerInput` sintético (`step`, `step_until`,
  `press_jump`, `look_yaw`, `add_dummy`, `add_block`...). Em testes de cena inteira use `player.external_control = true` e
  `await d.ready_physics(self)` antes de mover. Convenção do yaw: **frente = (−sin yaw, −cos yaw)**; yaw 0 olha para −Z.
- Em `.tscn`, o construtor `Transform3D(...)` lista a **base por linhas** (os 3 primeiros números são a primeira linha da matriz).

## 15. Documentação existente (e o que está velho)

- `CLAUDE.md` / `AGENTS.md`: regras de arquitetura e comandos (mantenha sincronizados).
- `docs/ESCOPO.md`: diário por fase/revisão com as decisões de design (útil para o "porquê"). **Trechos históricos**: molas e personagem de
  primitivas, `tools/gen_character.py` e `prepare_character.py` (não existem mais), arquibancada/telas/holograma da arena,
  objetos "-col" (hoje "-convcolonly"), números antigos (dash 24 m/s, pulo 2,2 m...).
- `docs/ROTEIRO_TESTE.md`: roteiro de teste manual com controles, HUD de debug, percurso e arena. **Desatualizado em**: o cabeçalho diz que
  abre a arena de combate (hoje abre a SkyArena; F3: SkyArena → CombatArena → percurso → arena livre), pulo "≈ 2,20 m" (hoje 2,35 m),
  dash "começa a 24 m/s" (hoje 30), "Parte 5" fala de molas da animação (removidas) e a mira assistida (desligada por padrão).
  A seção "Arena flutuante" está atual.
- `assets/character/CREDITS.md`: créditos do personagem (CC0).

## 16. Pipeline de assets (Blender)

- Tudo é gerado **por código** (sem assets de terceiros, exceto o VRoid CC0 e a espada enviada pelo dono). Os `.blend` são binários;
  para mudar a arena ou a espada, mude o script e regenere. `*.blend1` é ignorado.
- `import bpy` deve vir **antes** de `bmesh`/`mathutils`. Render de conferência: Cycles (Workbench falha sem libEGL).
- `export_scene.gltf(... export_yup=True ...)`: Blender (x, y, z) → Godot (x, z, −y).
- Após regenerar um `.glb`, rode `godot --headless --import` (o `run_tests.sh` já faz).
- `build_hero.py` também gera `assets/character/hero_suit_mask.png` (máscara do traje para o menu de personagem).
- Personagens do VRoid Studio entram por `tools/import_vroid.py` (sem Blender). O Godot importa VRM 0.0 direto como glTF; o script só
  deixa o arquivo leve e ajeita os nomes das expressões.

## 17. Armadilhas que já custaram tempo

1. **`floor_block_on_wall`**: o padrão do Godot (true) faz o corpo no chão **parar** ao encostar em parede em diagonal (inclusive nas
   emendas de um muro curvo). O projeto usa `false` (config `floor_block_on_wall`, aplicado em `Player.apply_body_config`): o corpo
   desliza. Se algo "trava" na parede, olhe isso primeiro.
2. **Colisão de arena**: use peças convexas (`-convcolonly`), não malha de triângulos. Emendas de triângulos enganchavam e mudavam a
   normal da parede de repente.
3. **`class_name` novo**: erros de "Could not find type" somem com `godot --headless --import` (cache de classes).
4. **Wall sensor**: o `move_and_slide` "come" a componente contra a parede; por isso o sensor guarda a velocidade de entrada
   (`pre_slide_velocity`, `entry_velocity`). Não use a velocidade pós-slide para decidir wall jump.
5. **Teleporte**: `reset_physics_interpolation()` (o `Player.respawn` já faz).
6. **Testes de arena**: a posição inicial do jogador vem do marcador `Spawn`; não fixe coordenadas.
7. **Mudar clipe/nome de animação** exige ajustar `character_model.gd` (e os `AttackData` em `config/weapons`).
8. **Config editada à mão vs F2**: o F2 salva com `save_full` e reordena/gera todos os valores.
9. **Python do Blender**: só 3.11 (roda `bpy` 4.2.0). Não migre o `bpy` sem testar os scripts.
10. **O corpo do Player nunca gira.** Atribuir `global_transform` com rotação ao Player (spawn, teleporte) faz o modelo andar de
    lado (aconteceu: 22,5° torto depois da arena nova). Use `Player.respawn`/`_place`: posição no corpo, yaw no `visual`.
    **O mesmo vale para a câmera**: `top_level = true` guarda a rotação que o pai tinha naquele instante (o `.tscn` da SkyArena
    instanciava o Player girado 22,5°), e a vista ficava 22,5° fora do movimento (W andava na diagonal da tela). Por isso o
    centro da câmera é zerado em `_follow` e o Player da SkyArena não tem rotação. Teste em `test_player_camera.gd` e
    `test_wasd_walk_relative_to_the_camera`. Para conferir no jogo real, meça câmera x movimento x modelo com a captura por software (seção 8).
11. **`AnimatableBody3D` com `sync_to_physics = true`** (o padrão) desfaz na hora a atribuição de `global_position` e só aplica
    no próximo passo da física. O `HunterBot` usa `sync_to_physics = false` (ele não empurra ninguém).
12. **Tipos Variant**: o projeto trata "variável inferida de Variant" como erro (ex.: `var s: String = fila.pop_front()`).
13. **Clipes x modelos**: o cache do `HeroClips` sai SEMPRE do hero.glb (`ensure_loaded`); outros modelos só se ligam a ele
    (`bind`). Não chame `load_from` com outro modelo (os personagens do VRoid nem têm animações).
14. **Testes e `user://`**: nada de teste gravar `user://personagem.tres` (é a aparência salva do dono); o menu tem `set_open(false, false)`
    para fechar sem salvar e o Player de teste (controle externo) usa a aparência padrão.

## 18. Histórico resumido (do `git log`)

1. **Fases 1–4**: setup Godot 4.7 + Jolt + GUT, controller base (câmera sobre o ombro, SP, HUDs), dodge, wall jump por reflexão, side jump,
   back-coming, cancel, bunny hop, modo treino com percurso e menu F2 (`db025cc` … `ce30726`).
2. **Polimento de movimento**: controles de dash/sprint, corrida no ar, sensação de velocidade, personagem procedural, aba Visual do F2.
3. **Fase 5 – combate** (`5cf9d76` … `9c987ce`): armas, golpes, estados Attack/Hurt, vida, hitstop, postes, arena de combate, HUD, sons, F3.
4. **Ajustes pós-teste**: dash por Space + A/D, cambalhota, mortal no wall jump, golpes sem avanço/mira, depois golpe sem travar o movimento e
   pesado segurando o clique; personagem passou de primitivas → malha → VRoid CC0.
5. **Iterações de animação por código** (postura, trote, estrela no dash, pouso limpo, giros imediatos) — depois **refeitas no Blender**.
6. **Personagem e animações no Blender** (`9dda8c4`, `262877b`): hero.blend, clipes tocados direto nos ossos; **reverse wall jump removido**
   (`25443c4`); golpes com o corpo todo e impulsos que decaem (`995c8af`); golpes leves/pesados feitos à mão (`bb2cecd`).
7. **Arena flutuante** (`ebc2efc`, `425f949`, `b9e729e`, `677621f`, `e798e12`): plataforma sobre as nuvens vira a cena inicial; sem
   arquibancada/telas/globo; espada nova; colisão convexa; **desenho atual com travessas, muros azuis, roxo com passagens, degradê e caçador**.
8. **Caçador que voa** (`a407c2b`, merge `65fb0d1` com os commits do dono via Codex `9410095`…`4c416bd`): corpo do Player sem
   rotação, `HunterBot` com os clipes do personagem, golpe pesado arremessa, clipes `launched`/`knockdown`/`getup`, aba Alvos no F2.
9. **Câmera alinhada** (`5b67869`, o andar em diagonal de verdade): o centro da câmera herdava os 22,5° do Player instanciado girado
   na SkyArena; `PlayerCamera._follow` agora o zera, a cena instancia o Player sem rotação e há testes da câmera.
10. **Atraso de comandos** (`77f7d1a`, `0076490`): F1 mostra o pior quadro; parar ao soltar W ficou rápido (`ground_deceleration`
   45 → 120, `run_stop_rate`).
11. **Mergulho, dash e customização** (`9353741`): wall jump só com o pulo normal (dash no ar bloqueia), back-coming nunca passa por cima da
   parede (fim do reverse; trechos 3 e 4 do percurso ganharam pilares), dash segue a câmera, golpe no pulo vira mergulho (clipe
   `plunge_land`), golpe no dash aéreo = combo leve, menu de personagem F4 com modelos do VRoid (`tools/import_vroid.py`).

## 19. Em aberto

- **Validação do dono**: os últimos commits (arena `677621f`/`e798e12` e o caçador que voa) ainda não foram confirmados no jogo.
  Foram verificados por testes, renders do Blender e capturas do jogo real com render por software (sem GPU); falta olhar no
  Godot: neon, escala do bot, sensação do degradê e das passagens, **força do arremesso** (`launch_velocity_scale`) e as poses de
  voo, queda e levantar. Também falta a sensação do **mergulho** (tempo no ar, velocidade, tempo preso no chão), do **dash que segue
  a câmera** e do menu **F4** com um personagem exportado pelo próprio dono no VRoid Studio.
- **Atraso de comandos (pergunta sem resposta)**: o golpe leve só sai ao **soltar** o clique (para distinguir do pesado). Foi
  oferecido: leve ao apertar + pesado só no botão direito/segurando com aviso; ou pré-carregar os efeitos (faíscas, poeira, rastro
  criam materiais no primeiro uso e podem engasgar) e deixar MSAA/sombra configuráveis. O dono ainda não escolheu.
- **Modo caçador**: o bot vermelho agora reage e voa, mas continua **sem agir**. O dono ainda não definiu o que o caçador faz
  (ataques, perseguição, regras). Hoje ele volta ao spawn teleportando (simples e previsível); andar de volta fica como evolução.
- **Espada**: clarear o material (oferecido) e registrar origem/licença no `CREDITS.md`.
- **Docs**: atualizar os trechos velhos de `ROTEIRO_TESTE.md`/`ESCOPO.md` listados na seção 15.
- **Infra**: não há CI (um workflow que rode `tools/run_tests.sh` com Godot headless seria útil) e não há branch `main`.
- **Arena**: 313 corpos estáticos convexos (aceitável; dá para fundir se o desempenho pedir); não há botão de exportação dentro do
  Blender para a arena (só o script).
- **Fora do escopo por enquanto**: rede/multiplayer, música, arte final.

## 20. Glossário (termos do dono)

**poste** = `TrainingDummy`; **caçador** = futuro personagem/modo (hoje o bot vermelho, que reage e é arremessado); **leve/pesado** = golpes (clique/segurar);
**back-coming** = subida colada na parede após contato na base; **side jump** = wall jump que lança para a frente; **cancel** = 1/2 junto do
wall jump; **swap cancel** = trocar de arma na recuperação; **dodge cancel** = dash que corta a recuperação; **esquiva perfeita** = dash no
instante do golpe; **estrela** = dash em cambalhota lateral; **cambalhota** = rolamento do pouso forte; **mortal** = giro do pulo/wall jump;
**passarela/mureta/borda** = anel externo e seu muro baixo; **muro roxo/vermelho/azul/verde**, **travessa** (muro radial), **passagem** (porta com teto),
**degradê** (chão inclinado), **base preta** (centro): vocabulário do desenho da arena (seção 10).

## Revisão: preparação da partida e alturas dos muros

O projeto inicia em `scenes/ui/Loadout.tscn`. Primeiro se escolhem modelo, cores e arma
inicial, com prévia 3D; depois um dos quatro mapas (`SceneCycler.SCENES`). Aparência salva em
`user://personagem.tres` e arma inicial em `user://loadout.tres` via `ConfigIO.save_full`.
F3 durante uma partida abre a seleção de mapas; F4 ainda edita o personagem em jogo.

Na SkyArena, a revisão seguinte corrigiu a interpretação de "tamanho": trata-se da grossura,
não da altura. As alturas voltaram aos valores anteriores e a espessura dos muros internos
passou a 0,6 m; a borda circular conserva 1,5 m. O gerador Blender produz visual e
colisão juntos. Em sequências de wall jump, `MovementRules.can_chain_wall_jump` exige
velocidade vertical positiva depois do primeiro salto; o primeiro mantém a janela pós-pulo.
As descrições antigas de alturas e do F3 acima são históricas.

## Revisão: correção da grossura dos muros

O muro roxo, os quatro azuis e as quatro travessas vermelhas medem 0,6 m de grossura.
O roxo era 0,75 m e foi reduzido um pouco; as travessas eram 1,5 m e agora acompanham
os outros muros internos. A borda externa mantém 1,5 m de grossura. As alturas originais
foram restauradas: roxo 4,5 m; azuis, travessas e borda 2,25 m.


## Revisão: alinhamento do modelo ao heading

Ao nascer, `InputReader` copia `Player.global_rotation.y` para o yaw inicial da câmera, então W começa seguindo o heading do marcador (na SkyArena, 22,5°). Como `Visual` é filho local do `Player`, `Player._update_visual` converte o heading global em yaw local. Assim a câmera, a trajetória e o modelo começam alinhados. Validação manual no Godot ainda pendente.
Com `Player._place` (seção 5) o corpo já nasce sem rotação, então essa conversão é a identidade e vale só como salvaguarda;
`CombatArena._respawn` também já copia o yaw do marcador para a câmera, de modo que o alinhamento inicial não depende só do `InputReader`.

## Revisão: HUD vetorial

HUD de vida/SP com barras recortadas e valores; cartões de armas no canto superior direito,
painel de combate, mira e atalhos no rodapé. Renderização compartilhada em scenes/ui/hud_canvas.gd,
com escala proporcional à janela. FeedbackConfig expõe cores de painel, contorno e seleção no F2.
Alvos mantêm etiquetas e distância de arremesso e agora mostram barra de vida vermelha.

## Revisão: remoção do bunny hop e do back-coming

Bunny hop e back-coming não são mais técnicas jogáveis. O pouso deixa de preservar velocidade
por uma janela curta; pular em seguida aplica a velocidade normal do chão. Na parede, todo salto
usa a reflexão; a classificação distingue somente wall jump normal e side jump pelo ângulo de
entrada. A trava contra repetir a mesma parede permanece. O percurso usa wall jumps em pilares
para subir a borda e a parede lisa. F1, F2, HUD de treino e VFX não exibem mais as técnicas removidas.
As menções históricas anteriores neste documento descrevem versões antigas.

## Revisão: tela inicial integrada

`scenes/ui/Loadout.tscn` agora mostra em uma tela o personagem 3D, os dois cartões de arma
inicial, os quatro mapas e o botão de entrada. A personalização de modelo e cores abre como
modal sobre a tela e é salva via `CharacterLook`; a arma inicial usa `LoadoutConfig`.
Os cartões de mapas usam miniaturas em `assets/ui/map_previews.png`, e o fundo é
`assets/ui/main_menu_arena.png`. São ilustrações de interface originais, não cenas adicionais
nem mapas novos. A guia Treino seleciona `TrainingCourse`; não há recursos de rede ou loja.

## Revisão: Revezamento / Touch Down

`scenes/arenas/TouchdownArena.tscn` é um novo mapa solo. Sua fonte editável é
`art/arena/relay_arena.blend`; `tools/blender/build_relay_arena.py` gera o GLB com colisões
convexas, e `tools/blender/render_relay_preview.py` gera a miniatura do menu. A geometria tem
bases azul e vermelha, corredor direto e dois desvios laterais, mantendo a estrutura das
referências enviadas pelo dono com arte própria.

O jogador inicia na base azul, coleta o núcleo no centro e marca no gol vermelho. Ao pontuar,
reaparece na base inicial e o núcleo volta após breve intervalo. Cair da arena perde a posse;
dois bots de treino defendem a base adversária. Tempo, limite de entregas e dimensões das
áreas estão em `config/touchdown_config.tres`, editáveis pelo F2. HUD específico mostra posse,
distância, pontuação e cronômetro. É um protótipo de objetivo solo, sem rede nem times jogáveis.

## Revisão: topologia do Revezamento

O percurso foi corrigido com base na explicação do minimapa. Cada lado tem spawn baixo
(altura 0), rampa de saída, escada larga até a estação central (altura 2,4 m) e um gol
elevado ao lado do spawn, acessível por outra escada. O lado vermelho espelha o azul.
O núcleo fica na estação, não no mesmo piso do spawn. As escadas têm piso convexo inclinado
sob degraus visuais e paredes laterais com colisão para wall jumps; o patamar final se
sobrepõe ao piso do gol para não travar o Player. Um teste de integração percorre a rota
inteira com o Player real e verifica as alturas dos pisos por raycast.

## Revisão: nova seção vertical do Revezamento

A descrição da revisão anterior registra a primeira tentativa; a geometria atual inverte
essa seção vertical. Os spawns ficam a 8 m e a estação do núcleo a 0 m. Uma ponte alta liga
os terminais por cima de uma cápsula de trânsito aberta. Duas escadarias longas descem
dos terminais à estação; saltar da borda corta parte da escada. Duas rampas curvas em U,
com piso e colisores convexos segmentados, oferecem outro trajeto pelo exterior. Cada gol
fica a 9,4 m, ligado ao seu terminal por uma escada lateral curta. O lado vermelho gira a
planta azul 180°; no Godot o gol vermelho fica em (39, 11, -14). O `.blend` continua sendo
a fonte do GLB e da prévia do menu. Validar no jogo a leitura das distâncias e os saltos.

## Revisão: estação em oito do Revezamento

O mapa foi refeito a partir das vistas do Blender enviadas pelo dono (planta em oito).
Planta (Blender; Godot = (x, z, -y)), simétrica por rotação de 180°:
- Bases em quarto de círculo (raio 25) a 8 m: vermelha a noroeste, azul a sudeste, com galeria
  coberta (teto a 13,6 m, alcançável por wall jump), balcão curvo de 1,3 m protegendo o gol e um
  bloco retangular onde a ponte chega e o time nasce. Spawn azul no Godot: (40, 8, -3).
  Gol vermelho: (-32,4, 9,6, -9,9), área 6 × 3,2 × 6.
- Passarelas altas em x = ±26 viram voltas em U (raio 13; fora escadaria, dentro rampa; tela alta
  externa para wall jump, mureta interna, painel luminoso na curva) e descem à plataforma central.
- Plataforma central no nível 0 com o trem parado (teto a 3,9 m é piso).
- Ponte a 8 m em z = 0; o núcleo fica no largo do meio, (0, 9, 0). O largo tem abertura nos dois
  lados para cair no teto do trem.
- Escadas rolantes ligam cada pátio (lado da ponte) à plataforma central.
`build_relay_arena.py` gera tudo por código (sem edição manual no `.blend`); a prévia do menu usa
Cycles na CPU (`render_relay_preview.py`) para funcionar sem GPU. Os testes do modo têm bots que
fazem ponte → núcleo → gol, a volta em U, a escada rolante e a queda no teto do trem.
