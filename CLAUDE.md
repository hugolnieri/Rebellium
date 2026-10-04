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
godot --path .                  # roda o jogo (cena principal = percurso de treino)
```
Roteiro de teste manual: `docs/ROTEIRO_TESTE.md`.

## Arquitetura obrigatória
1. **Nenhum número mágico de gameplay.** Todo valor vem de um Resource em `config/`:
   - `config/movement_config.tres` → `MovementConfig` (movimento, pulo, SP, dodge, wall jump, técnicas)
   - `config/camera_config.tres` → `CameraConfig`
   - `config/feedback_config.tres` → `FeedbackConfig` (cores e durações de VFX)
   Ao criar um valor novo, adicione `@export` na classe (com `@export_group` e faixa `@export_range`)
   e ele aparece automaticamente no menu de debug (F2).
2. **Input separado da lógica.** Só `scenes/player/input_reader.gd` toca em `Input`. Ele produz um
   `PlayerInput` por tick (direção, look, botões, ticks de pressionamento). Estados e regras só
   consomem `PlayerInput` — nunca `Input` diretamente. (Base para predição no multiplayer.)
3. **Máquina de estados explícita**, um script por estado em `scenes/player/states/`:
   Idle, Run, Sprint, Jump, Fall, WallJump, Dodge, Land. Toda troca passa por
   `StateMachine.transition_to(nome, motivo)`, que loga e emite `GameEvents.state_changed`.
4. **Regras e matemática puras** em `scripts/core/` (`WallJumpMath`, `MovementRules`, `SPPool`):
   sem dependência de cena, cobertas por testes unitários.
5. **Feedback por eventos.** A lógica emite sinais no autoload `GameEvents`
   (`wall_jump_executed`, `technique_executed`, `sp_depleted`, ...). VFX, som, HUD e modo treino
   apenas ouvem.
6. Tempo de gameplay medido em **ticks** (int) quando a janela é justa (bunny hop, cancel);
   em segundos (float, convertidos com o delta fixo) para durações longas.
7. Salvar configs sempre com `ConfigIO.save_full` (grava todos os valores; o ResourceSaver padrão
   omite os iguais ao padrão).

## Estrutura
```
config/            Resources .tres com TODOS os números de gameplay
scenes/player/     Player.tscn, câmera, input, estados, sensor de parede, VFX, `character_model.gd`
                   (personagem procedural: só apresentação, lê o Player e nunca altera gameplay)
scenes/arenas/     arena greybox + percurso de treino
scenes/ui/         HUD, HUD de debug (F1), menu de debug (F2)
scripts/core/      eventos, configs, regras puras, utilitários
tests/unit/        testes de lógica pura
tests/integration/ testes com o Player real e física headless; `test_training_course.gd` tem bots
                   que completam cada trecho do percurso (rode-os ao mexer em geometria ou config)
tests/helpers/     `player_driver.gd`: dirige o Player tick a tick com PlayerInput sintético
tools/             scripts de instalação e de teste
```

## Cenas
- `scenes/arenas/TrainingCourse.tscn` (principal): percurso, cronômetro, checkpoints, R reinicia.
- `scenes/arenas/Arena.tscn`: arena livre para experimentar.
- As duas incluem HUD, DebugHUD (F1) e DebugMenu (F2).

## Convenções
- Commits de fase: `fase-N: <resumo>`.
- Antes de commitar: `tools/run_tests.sh` passando e `godot --headless --quit-after 120` sem erros.
- Paleta greybox: preto, cinza escuro, branco sujo, metal. Acentos (vermelho, violeta, azul elétrico,
  verde ácido) só para feedback.
