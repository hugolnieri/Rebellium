# AGENTS.md — REBELLIUM

Guia de entrada para agentes de código (Codex etc.). **Leia também `docs/CONTEXTO_PROJETO.md`**: estado completo do jogo, valores
de movimento e combate, medidas da arena, pipeline do Blender, armadilhas e pendências. O `CLAUDE.md` traz as mesmas regras para o
Claude Code: se mudar uma regra aqui, mude lá também.

## O projeto

REBELLIUM é um jogo de ação acrobática em terceira pessoa, competitivo e 100% melee. **A movimentação é a habilidade principal**
(wall jump, back-coming, side jump, dash, cancels, bunny hop). Hoje é um protótipo single-player (sem rede, sem música).
Tudo é original: **não use nomes, assets ou termos de outros jogos**.

Stack: Godot 4.7.2-stable, GDScript **tipado** (tipos explícitos em variáveis, parâmetros e retornos), física Jolt, **60 ticks fixos**,
testes GUT 9.7.1 (headless). Blender (`bpy` 4.2.0, Python 3.11) gera por código o personagem, as animações, a arena e a espada.

## Estado em uma olhada

- Cena principal: arena flutuante (`scenes/arenas/SkyArena.tscn`) com um **bot vermelho "caçador"** parado no centro, que só recebe dano
  (placeholder: o modo caçador ainda não foi definido). F3 alterna: SkyArena → CombatArena → TrainingCourse → Arena.
- Player com 10 estados (Idle, Run, Sprint, Jump, Fall, WallJump, Dodge, Land, Attack, Hurt), SP, dash lateral, wall jump por reflexão,
  back-coming encadeado (o reverse wall jump foi **removido**), cancels, bunny hop, rolamento no pouso.
- Duas armas: Lâmina de Arco (modelo 3D enviado pelo dono) e Presa de Fase (procedural), com combos leves, pesado (segurar o clique),
  golpes aéreos e de dash, hitstop, rastro, esquiva perfeita.
- Personagem (base VRoid CC0) e **todas as animações feitas no Blender** (`hero.blend` → `hero.glb`); o jogo as toca direto nos ossos
  (`HeroClips`) com crossfade. Menu F2 edita todas as configs ao vivo.
- **203 testes passam**; `godot --headless --quit-after 120` abre sem erros.
- Os dois últimos commits de arena (`677621f`, `e798e12`) **ainda não foram validados pelo dono dentro do jogo**.

## Comandos

```bash
tools/install_godot.sh                          # instala o Godot 4.7.2 e cria o comando `godot` (se faltar)
tools/run_tests.sh                              # importa o projeto e roda TODOS os testes (sai != 0 se falhar)
tools/run_tests.sh -gselect=test_sky_arena.gd   # um arquivo só
godot --headless --quit-after 120 --path .      # checagem de abertura sem erros
godot --headless --import                       # reimporta (após mudar glb/blend ou criar class_name novo)
godot --path .                                  # roda o jogo
python3 tools/gen_sfx.py                        # regera os sons (numpy)
python3 tools/blender/build_hero.py             # recria hero.blend + hero.glb (APAGA edições manuais do .blend)
python3 tools/blender/export_hero.py            # só exporta o hero.blend editado
python3 tools/blender/build_sky_arena.py        # recria a arena (art/arena/sky_arena.blend + assets/arena/sky_arena.glb)
python3 tools/blender/build_sword.py            # art/weapons/arc_blade_source.usdz -> assets/weapons/arc_blade.glb
```

Os scripts do Blender precisam de `pip install bpy==4.2.0 numpy` (só roda em Python 3.11). Sem isso o jogo e os testes funcionam
normalmente; os `.glb`/`.blend` já estão versionados. Se o ambiente bloquear internet depois do setup, instale tudo no script de setup.

## Regras de arquitetura (obrigatórias)

1. **Nenhum número mágico de gameplay.** Todo valor vem de um Resource em `config/`: `movement_config.tres` (`MovementConfig`),
   `camera_config.tres`, `feedback_config.tres`, `combat_config.tres`, `weapons/<arma>/weapon.tres` + um `.tres` por golpe
   (`WeaponConfig`, `AttackData`), `dummy_config.tres`, `audio_config.tres`. Valor novo = `@export` na classe (com `@export_group` e
   `@export_range`); ele aparece sozinho no menu F2.
2. **Input separado da lógica.** Só `scenes/player/input_reader.gd` toca em `Input`; ele produz um `PlayerInput` por tick. Estados e
   regras só consomem `PlayerInput`.
3. **Máquina de estados explícita**, um script por estado em `scenes/player/states/`. Toda troca passa por
   `StateMachine.transition_to(nome, motivo)` (loga e emite `GameEvents.state_changed`).
4. **Regras e matemática puras** em `scripts/core/` (`WallJumpMath`, `MovementRules`, `SPPool`, `CombatRules`, `HealthPool`): sem
   dependência de cena e com testes unitários.
5. **Feedback por eventos.** A lógica emite sinais no autoload `GameEvents`; VFX, som (`SoundManager`), HUD e modo treino só ouvem.
6. **Tempo de gameplay em ticks** (int) quando a janela é justa (bunny hop, cancel); em segundos (float) para durações longas.
   Toda física em `_physics_process`. Com `physics_interpolation` ligada, ao teleportar um corpo chame `reset_physics_interpolation()`.
7. **Salvar config sempre com `ConfigIO.save_full`** (o `ResourceSaver` padrão omite valores iguais ao padrão).
8. **Alvos de golpe** ficam no grupo `hittable` e implementam `take_hit(info) -> bool`, `get_hit_center()`, `get_hit_radius()`.
9. **Hitstop** pausa a simulação do Player (`hitstop_ticks`); os tempos do golpe contam em ticks próprios do estado Attack.
10. **Apresentação nunca altera gameplay**: `character_model.gd` e o resto de `scenes/player/` visual só leem o Player.
11. Paleta greybox: preto, cinza escuro, branco sujo, metal; acentos (vermelho, violeta, azul elétrico, verde ácido) para feedback.
    Exceções: o personagem (traje azul-marinho de gola alta, cabelo branco, descalço) e as armas com brilho próprio (ciano / laranja).

## Como trabalhar com o dono

- **Português**, informal e direto; respostas curtas. O dono manda pedidos curtos, muitas vezes com um desenho/imagem: trate o desenho
  como especificação. Se algo for ambíguo, escolha a leitura mais provável, implemente e **liste no fim as decisões que tomou**.
- O dono **não é especialista em git**: dê sempre comandos prontos. "Não mudou nada" quase sempre é cache do `.godot` ou não ter puxado.
- Entrega: implemente → rode os testes e o headless → commit + push na branch padrão → diga como atualizar (comandos acima) e o que olhar.
- Desfazer um experimento que não agradou é normal e rápido. Não discuta; ajuste.
- Preferências recorrentes: movimento fluido (vira na hora para a câmera, golpear não trava o corpo), animação natural feita à mão no
  Blender (sem filtros), tudo ajustável ao vivo (F2).

## Armadilhas que já custaram tempo

- **`floor_block_on_wall`**: o padrão do Godot faz o corpo no chão parar ao encostar em parede em diagonal. O projeto usa `false`
  (`MovementConfig.floor_block_on_wall`, aplicado em `Player.apply_body_config`). Se algo "trava" na parede, olhe isso primeiro.
- **Colisão da arena** = peças convexas (objetos `-convcolonly` no glb viram `ConvexPolygonShape3D`); malha de triângulos enganchava.
- **`class_name` novo** → `godot --headless --import` (senão "Could not find type").
- **Eixos**: Blender (x, y, z) → Godot (x, z, −y). **Yaw**: frente = (−sin yaw, −cos yaw). Em `.tscn`, `Transform3D(...)` lista a base por linhas.
- **Clipes de animação** são procurados por nome em `character_model.gd`; não renomeie sem ajustar o código e os `AttackData`.
- **Wall jump** usa a velocidade de **entrada** na parede (`wall_sensor`), não a de depois do `move_and_slide` (que "come" a componente).
- Testes de cena inteira: `player.external_control = true`, `await d.ready_physics(self)` e a posição inicial vem do marcador `Spawn`.
- Rodar `build_hero.py` apaga edições manuais do `hero.blend`; rodar `build_sky_arena.py` sobrescreve o `.blend`/`.glb` da arena.

## Mapa do repositório

```
config/            Resources .tres com TODOS os números de gameplay
scenes/player/     Player.tscn, câmera, input, estados, sensor de parede, personagem (character_model.gd, hero_clips.gd), armas visuais
scenes/arenas/     SkyArena (principal), CombatArena, TrainingCourse, Arena, TrainingDummy, HunterBot
scenes/ui/         HUD, HUD de debug (F1), menu de debug (F2), HUD de combate e de treino
scripts/core/      eventos, configs, regras puras, utilitários
tests/unit/        testes de lógica pura (7 arquivos)
tests/integration/ testes com o Player real e física headless (10 arquivos); test_training_course.gd tem bots que completam o percurso
tests/helpers/     player_driver.gd: dirige o Player tick a tick com PlayerInput sintético
tools/             install_godot.sh, run_tests.sh, gen_sfx.py e tools/blender/ (build_hero, hero_animations, export_hero, build_sky_arena, build_sword)
art/               fontes editáveis (hero.blend, sky_arena.blend, arc_blade_source.usdz); `.gdignore`
assets/            o que o Godot carrega (hero.glb, sky_arena.glb, arc_blade.glb, sfx)
docs/              CONTEXTO_PROJETO.md (estado completo), ESCOPO.md (diário de decisões), ROTEIRO_TESTE.md (teste manual)
```

## Em aberto (detalhes na seção 19 de `docs/CONTEXTO_PROJETO.md`)

- Validação do dono no jogo das duas últimas arenas; definição do **modo caçador** (o bot é só um alvo).
- Espada: clarear o material e registrar origem/licença no `CREDITS.md` (o modelo foi enviado pelo dono).
- Trechos velhos em `ROTEIRO_TESTE.md`/`ESCOPO.md`; não há CI nem branch `main`.
