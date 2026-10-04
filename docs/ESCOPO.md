# REBELLIUM — Escopo do MVP de movimentação (Fases 1–4)

## Visão
Ação acrobática em terceira pessoa, competitiva, 100% melee. A movimentação é a habilidade principal:
quem domina wall jumps, cancels e técnicas avançadas controla o espaço da arena.

## Fora do escopo desta etapa
Combate, armas, rede, personagens, animações, arte final, som.

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
