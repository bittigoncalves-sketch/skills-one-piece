# FPS caindo para ~8 ao encontrar inimigos (2026-11-10)

**Sintoma:** ao começar o jogo e chegar perto de inimigos o FPS foi a ~8.

**Causa medida** (`tools/dev_tests/medir_cpu_perto_de_inimigos.gd`, mapa real, Cronometro do projeto): perto de um acampamento do East Blue um passo de
física passa de ~16 ms (≈ 31 ticks da `IaDoMod` por passo × ~0,9 ms). Acima do orçamento de 16,7 ms o Godot tenta recuperar rodando até
`max_physics_steps_per_frame` (padrão **8**) passos por quadro → quadro = 8 × 16 ms ≈ 130 ms ≈ **8 FPS**. É uma espiral: quanto mais lento, mais passos extras.
No quadro do pico foram 8 passos seguidos (252 ticks de IA num quadro só).

**Não foi o que mexi no dia:** M1 rápido, estamina, lâminas, barras do chefe e multiplicador dos inimigos, desligados um a um, não mudam o resultado.

**Mitigação aplicada:** `project.godot` → `[physics] common/max_physics_steps_per_frame=3`. Medido: pior quadro 126 → 64 ms; média da luta 72 → 48 ms.
Efeito colateral aceito: se a máquina não aguentar, o jogo roda em câmera lenta (até ~60% da velocidade) em vez de travar.

**Não resolvido (causa de fundo):** o custo da `IaDoMod` com ~92 personagens acordados. Reduzir `ALCANCE_ATIVO` (80 → 40 → 25 m) NÃO ajudou nas medições.
Próximos passos medidos como candidatos: orçamento de ticks de IA por passo com fila justa (rodízio), e olhar os ~17 ms de `PMP.move_and_slide`/hurtbox por passo.
GATILHO: se após o limite de passos o FPS ainda cair com muitos personagens, medir o orçamento de ticks por passo.

## Segunda etapa (2026-11-10): IA unificada + povoamento por ilha (pedido do dono)
**Pedido:** "em vez de IAs individuais por inimigo, a IA, quando não está próxima do jogador, é unificada, exceto boss; e o spawn das criaturas fica
restrito à ilha em que o jogador se encontra."

**Como ficou**
- `IaUnificada` (`src/historia/ia_unificada.gd`, UM nó no Modo História): a cada 0,5 s varre os inimigos (`PersonagemMinePiece`, `BonecoDeDuelo`);
  além de 80 m, fora de combate e sem dano recente, o inimigo fica DORMENTE (corpo e filhos — cérebro, IA do mod, executor, animação — não processam).
  Acorda a menos de 60 m (histerese), ao levar dano (`acordar_por_dano`) ou ao entrar em combate. O repouso dos dormentes (2 %/s da vida) é feito
  pelo próprio gerenciador numa passada só. **Chefes nunca dormem** (ficha `chefe`, grupos `chefes`/`boss`).
- `Povoamento` (`src/historia/povoamento.gd`): criatura de OUTRA ilha fica LATENTE (sai dos grupos, sem colisão, invisível, parada) e volta
  exatamente como estava. `ModoHistoria.trocar_povoada(id)` (ligado ao `DetectorDeIlha.ilha_atual`): ao trocar de ilha a antiga fica latente (animais
  descarregados) e a nova acorda — em LOTES de 3 por quadro, os mais perto primeiro (acordar 63 de uma vez era um engasgo de 945 ms).
- Spawn natural (`SpawnNaturalMinePiece.ilha_unica`) só nasce na ilha do jogador. O LOD ignora latentes.
- Vale na carga por distância (jogo normal). Na carga total (testes/headless, `carregar_tudo`) não restringe, para os testes antigos não dependerem de onde o jogador está.

**Medido** (`medir_cpu_perto_de_inimigos.gd`, física por quadro; `-- antes_10_11` / `base` / `novo`):
| | antes | só IA unificada | + ilha do jogador |
|---|---|---|---|
| inimigos ativos / nós | 124 / 43 mil | 124 / 43 mil | 20 / 21 mil |
| parado, longe (física) | 5,8 ms | 3,6 ms | 3,0 ms |
| luta com bandido (soma) | 22,7 ms | 21,0 ms | 20,0 ms |
| chegar a uma ilha com 63 do East Blue (pior quadro) | — | — | 53 ms (era 945 ms sem os lotes) |
| luta no acampamento East Blue (média / pior) | 64 / 142 ms | 67 / 127 ms | 24 / 26 ms |
A IA unificada sozinha NÃO resolve a luta no meio do acampamento (os de perto continuam acordados); quem resolve é não ter 92 personagens ativos ao mesmo tempo.

**Limites conhecidos:** animais e `InimigoDoMapa` ainda não entram na IA unificada (só o povoamento por ilha os cobre); encontros no MAR (bestas soltas) não são
de ilha e não foram restringidos; o chefe que renasce/vive fora da ilha do jogador também fica latente. Sem janela: não medi FPS real com GPU.
GATILHO: se a luta no meio de um acampamento grande ainda passar de 16 ms por passo, limitar quantos acordam por vez perto do jogador (orçamento de ticks de IA).

## Terceira etapa (2026-11-10): duas IAs unificadas — animais por locomoção, inimigos por facção (pedido do dono)
`IaUnificada` virou a BASE (motor de sono/despertar, histerese, coesão, repouso, fila de ativação em lotes). Dois gerenciadores independentes:
- **`IaDosAnimais`** (`ia_dos_animais.gd`): UMA IA para todos os animais (`AnimalDaIlha`, grupo `animais`; bestas do mar, grupo `bestas_do_mar`). A ÚNICA diferença
  é a locomoção — **voador** (corpo `voador`; acorda a 80 m, dorme além de 110 m), **aquático** (besta do mar; 60/90 m), **terrestre** (o resto; 50/70 m) —
  porque o que muda é o que o jogador enxerga de longe. Sem coesão nem facção. Chefes (harpia, serpente) nunca dormem.
- **`IaDosInimigos`** (`ia_dos_inimigos.gd`): UMA IA por FACÇÃO (`ficha.faccao`: `pirata:arlong`, `pirata:buggy`, `marinha`, `raid:*`, `mod`, `nenhuma`; os bonecos
  do ninho trazem o metadado `faccao` = `bandidos`/`bonecos`). Coesão de 30 m: quem está perto de um companheiro de facção acordado não congela no meio da luta;
  ALERTA: quem apanha acorda os aliados da MESMA facção a até 40 m por 8 s; o chefe é âncora da facção dele e nunca dorme. Raios 60/80 m.
Ganchos: `take_damage` de `PersonagemMinePiece`, `BonecoDeDuelo`, `AnimalDaIlha` e `Besta` chamam `IaUnificada.acordar_por_dano` (que avisa os gerenciadores).
Medido no mapa real (carga por distância): 70 animais gerenciados (64 terrestres, 5 voadores, 1 aquático), 59 dormindo longe do jogador.
Testes: `test_ia_por_grupo` (19 ok, nós sintéticos), `test_povoamento_e_ia_unificada` (13 ok, mapa real).
Limite: `InimigoDoMapa` (inimigo de peça do editor) ainda não entra em nenhum dos dois. GATILHO: se aparecer em medição, dar a ele a facção `mapa`.
