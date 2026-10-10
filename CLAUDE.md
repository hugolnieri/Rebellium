# REBELLIUM — regras do projeto

Jogo de ação acrobático em terceira pessoa, competitivo, 100% melee. A movimentação é a habilidade principal.
Tudo é original: não usar nomes, assets ou termos de outros jogos.

## Stack
- Godot 4.7.2-stable, GDScript **tipado** (tipos explícitos em variáveis, parâmetros e retornos).
- Física **Jolt** (`physics/3d/physics_engine`), **60 ticks fixos**. Toda física em `_physics_process`.
- Testes: GUT 9.7.1 (`addons/gut`), headless.
- Physics interpolation ligada: ao teleportar um corpo, chame `reset_physics_interpolation()`.

## Comandos
```bash
tools/install_godot.sh          # instala o Godot 4.7.2 e cria o comando `godot` (se faltar)
tools/run_tests.sh              # importa o projeto e roda TODOS os testes (sai != 0 se falhar)
tools/run_tests.sh -gselect=test_sp_pool.gd   # um arquivo só
godot --path .                  # roda o jogo (cena principal = arena flutuante; F3 alterna cenas)
python3 tools/gen_sfx.py        # regera os sons em assets/sfx (requer numpy)
python3 tools/blender/build_hero.py   # recria art/character/hero.blend + hero.glb (Blender: blender -b -P ...;
                                     # ou bpy do pip: pip install bpy==4.2.0). APAGA edições manuais do .blend
python3 tools/blender/export_hero.py  # só exporta o hero.blend editado → assets/character/hero.glb
python3 tools/blender/build_sky_arena.py  # recria a arena flutuante (art/arena/sky_arena.blend + assets/arena/sky_arena.glb)
```
Roteiro de teste manual: `docs/ROTEIRO_TESTE.md`.

## Arquitetura obrigatória
1. **Nenhum número mágico de gameplay.** Todo valor vem de um Resource em `config/`:
   - `config/movement_config.tres` → `MovementConfig` (movimento, pulo, SP, dodge, wall jump, técnicas)
   - `config/camera_config.tres` → `CameraConfig`
   - `config/feedback_config.tres` → `FeedbackConfig` (cores, VFX, personagem, molas da animação)
   - `config/combat_config.tres` → `CombatConfig` (vida, buffers, mira assistida, dano recebido)
   - `config/weapons/<arma>/weapon.tres` → `WeaponConfig`; cada golpe em `<golpe>.tres` → `AttackData`
   - `config/dummy_config.tres` → `DummyConfig` (postes de treino)
   - `config/audio_config.tres` → `AudioConfig` (volumes)
   Ao criar um valor novo, adicione `@export` na classe (com `@export_group` e faixa `@export_range`)
   e ele aparece automaticamente no menu de debug (F2).
2. **Input separado da lógica.** Só `scenes/player/input_reader.gd` toca em `Input`. Ele produz um
   `PlayerInput` por tick (direção, look, botões, ticks de pressionamento). Estados e regras só
   consomem `PlayerInput` — nunca `Input` diretamente. (Base para predição no multiplayer.)
3. **Máquina de estados explícita**, um script por estado em `scenes/player/states/`:
   Idle, Run, Sprint, Jump, Fall, WallJump, Dodge, Land, Attack, Hurt. Toda troca passa por
   `StateMachine.transition_to(nome, motivo)`, que loga e emite `GameEvents.state_changed`.
4. **Regras e matemática puras** em `scripts/core/` (`WallJumpMath`, `MovementRules`, `SPPool`,
   `CombatRules`, `HealthPool`):
   sem dependência de cena, cobertas por testes unitários.
5. **Feedback por eventos.** A lógica emite sinais no autoload `GameEvents`
   (`wall_jump_executed`, `technique_executed`, `attack_started`, `hit_landed`, ...). VFX, som
   (autoload `SoundManager`), HUD e modo treino apenas ouvem.
8. **Alvos de golpe** ficam no grupo `hittable` e implementam `take_hit(info) -> bool`,
   `get_hit_center()` e `get_hit_radius()` (Player e TrainingDummy).
9. **Hitstop** pausa a simulação do Player (`hitstop_ticks`); tempos de golpe contam em ticks
   próprios do estado Attack, então a pausa não encurta o golpe.
6. Tempo de gameplay medido em **ticks** (int) quando a janela é justa (bunny hop, cancel);
   em segundos (float, convertidos com o delta fixo) para durações longas.
7. Salvar configs sempre com `ConfigIO.save_full` (grava todos os valores; o ResourceSaver padrão
   omite os iguais ao padrão).

## Estrutura
```
config/            Resources .tres com TODOS os números de gameplay
scenes/player/     Player.tscn, câmera, input, estados, sensor de parede, VFX, `character_model.gd`
                   (só apresentação: toca os clipes do Blender do `hero.glb` (via `hero_clips.gd`) direto nos ossos,
                   com crossfade nas trocas; lê o
                   Player e nunca altera gameplay)
assets/character/  personagem exportado (hero.glb: malha + esqueleto + animações; ver CREDITS.md)
art/character/     hero.blend — fonte editável do personagem e das animações (Actions); `.gdignore`
art/arena/         sky_arena.blend — fonte editável da arena flutuante
assets/arena/      sky_arena.glb (objetos com sufixo "-col" viram colisão no Godot)
scenes/arenas/     arena de combate, postes de treino, percurso de treino, arena livre
scenes/ui/         HUD, HUD de debug (F1), menu de debug (F2)
scripts/core/      eventos, configs, regras puras, utilitários
tests/unit/        testes de lógica pura
tests/integration/ testes com o Player real e física headless; `test_training_course.gd` tem bots
                   que completam cada trecho do percurso (rode-os ao mexer em geometria ou config)
tests/helpers/     `player_driver.gd`: dirige o Player tick a tick com PlayerInput sintético
tools/             scripts de instalação e de teste
```

## Cenas
- `scenes/arenas/CombatArena.tscn`: postes de treino, HUD de combate, R reinicia.
- `scenes/arenas/SkyArena.tscn` (principal): arena flutuante sobre as nuvens (modelo do Blender), postes de treino;
  `sky_arena.gd` herda da arena de combate e anima holograma, drones, luzes e chamas.
- `scenes/arenas/TrainingCourse.tscn`: percurso de movimento, cronômetro, checkpoints.
- `scenes/arenas/Arena.tscn`: arena livre para experimentar.
- Todas incluem HUD, DebugHUD (F1) e DebugMenu (F2). F3 (autoload `SceneCycler`) alterna entre elas.

## Convenções
- Commits de fase: `fase-N: <resumo>`.
- Antes de commitar: `tools/run_tests.sh` passando e `godot --headless --quit-after 120` sem erros.
- Paleta greybox: preto, cinza escuro, branco sujo, metal. Acentos (vermelho, violeta, azul elétrico,
  verde ácido) para feedback. Exceção da direção de arte: o personagem (traje azul-marinho de gola alta,
  cabelo branco, descalço) e as armas com brilho próprio (ciano / laranja).
- Animações do personagem: Actions no `art/character/hero.blend` (poses-chave em
  `tools/blender/hero_animations.py`). O jogo amostra cada clipe por tempo normalizado (fase da passada,
  progresso do dash, fases do golpe); giros de corpo inteiro (mortais, estrela, giro do golpe) ficam no
  código (o osso Root no Blender é só prévia). Clipe novo/renomeado → ajustar `character_model.gd`.
- Nomes de armas, golpes e personagens são originais (nada de nomes de outros jogos).
