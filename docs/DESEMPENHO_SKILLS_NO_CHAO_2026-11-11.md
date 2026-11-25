# Desempenho das skills ao colidir com o chão (11/11/2026)

**Pedido do dono:** "o bug acontece quando a skill colide com o chão — faça um teste de desempenho com as skills de todas as frutas em colisão com o solo."
**Método:** mapa REAL (relevo em blocos, ~43 mil nós), câmera apontada para o chão (`_pitch` −1,0), cada técnica Z X C V B N de cada fruta do mod, tecla segurada 1 s e solta, 1,5 s de observação, tempo de cada quadro de física. Headless, `MemoryMax` 5–7 GB (a primeira tentativa, sem teto, travou o computador).

## Como reproduzir
| O quê | Comando |
|---|---|
| Varredura de todas as técnicas (26 frutas, 103 técnicas) | `MIRA=chao godot --headless --path . --script tools/dev_tests/medir_skills_no_chao.gd` (`MIRA=ceu` = controle sem tocar o terreno) |
| Onde vai o tempo de UMA técnica (rótulos `McMundo.*` + quem chama) | `ALVOS="mori_mori:V,uo_uo_seiryu:Z:forma" godot --headless --path . --script tools/dev_tests/medir_skill_detalhe.gd` |
| Equivalência das procedures otimizadas | `tools/dev_tests/test_procedures_otimizadas.gd` (19 verificações) |

## Achados (medidos)
1. **`BlockToGrassProcedure`** varria o cubo `BlockRange × 2` inteiro (Mori Mori V: 64³ = 262 144 células, 393 mil `getBlockState`): **4,1–4,7 s num quadro**; Mori C 0,5 s. **Corrigido:** cópia otimizada (`src/minecraft/otimizadas/BlockToGrassProcedure.gd`) que visita só os blocos sobrepostos (≤ 600): **10 ms**, mundo idêntico à gerada.
2. **`BlockDestroyAllDirectionProcedure`** (a destruição de terreno por colisão) é o gargalo comum das skills que batem no chão (Kiro Kiro Z 2,9 s com 132 mil células; Leopard C, Giraffe C/V, Brachio Z, Uo Uo Gust). **Melhorada** (mesmo mundo): poda do cubo pela esfera, classificação por célula sem `BlockPos` (`McMundo.estado_da_celula`), 1 consulta por vizinho, testes de tag memorizados por bloco. Leopard C 471 → 219 ms; parte da procedure no Uo Uo C 305 → 28 ms.
3. **Troca da colisão do relevo (~150 ms por corte):** quando a técnica cava o chão, o relevo é recalculado numa thread, mas **anexar a forma de colisão do terreno inteiro custa ~70 ms por mudança de forma × 2 (tirar a antiga, pôr a nova) = ~148 ms no quadro** (ilha inicial: 465 mil vértices). Montar a forma na thread NÃO ajudou (o `set_faces` é barato; testei). É o que sobra no Uo Uo C (218 ms), Brachio Z, Giraffe C.
4. **Supa Supa C (1,1 s):** ~2 970 `getEntitiesOfClass` num quadro; não é o chão — é consulta repetida de entidades. Não tratado.

## Pendente (com gatilho)
- **Colisão do relevo em pedaços** (refazer só os afetados, ~16× menor): elimina o item 3. Mexe em `RelevoDasIlhas`, `RelevoEmBlocos` e `McRelevoCavavel`. *Gatilho:* decisão do dono (muda a montagem do terreno).
- **Volume de chamadas da `BlockDestroyAllDirection`** (1 530 por quadro no Leopard C, ~120 µs cada): reduzir o custo fixo por chamada ou agrupar. *Gatilho:* depois de medir a colisão em pedaços.
- ~~Queda do motor (SIGSEGV)~~ **Explicada como defeito do MEDIDOR, não do jogo.** Medido com `gdb` (queda na thread principal, threads de trabalho ociosas → não era corrida com o relevo; chamada virtual num objeto liberado) e com um gancho `tree_exiting` que mostrou a cadeia: a técnica mata um animal → `ganhar_xp` → `progressao.mudou` → `ModoHistoria.aplicar_progressao` → `equipar_fruta`, que **libera o controlador** (`fruta_mp.fruta_id != id`) porque o medidor equipava a fruta fora da progressão. O medidor guardava `c` e chamava `usar_tecla` nele depois. Com a guarda (buscar de novo + `is_instance_valid`): **0 quedas em 8 execuções** e a varredura completa de 103 técnicas terminou. O jogo real busca o controlador a cada tecla (`ControladorFrutaMinePiece.de(jogador)`) e a fruta está na progressão (o id bate), então esse caminho não ocorre em partida.
  *Ressalva honesta:* chamar o controlador JÁ liberado, ou removido e ainda não destruído, dá só erro de script / nada, e NÃO reproduziu o SIGSEGV isoladamente; o mecanismo exato da queda (uso depois da liberação num ponto que o teste não alcança) ficou sem prova direta. A correlação (guarda → 0 quedas; sem guarda → ~70%) e a pilha são as evidências.

- **Uo Uo Z transformada:** o relato original ("lag extremo ao disparar o Z") é o Demolition Gust (tornado) tocando o chão — coberto pelos itens 2 e 3 (varredura sem a forma: Gust 338 → 213 ms; o que sobra é a troca de colisão). Com a forma ativa não medi a mesma técnica de novo.

## Resultado final da varredura (103 técnicas, mapa real, câmera para o chão; exit 0, 0 quedas)
| Técnica | Antes (pior quadro) | Depois |
|---|---|---|
| Mori Mori V (BlockToGrass) | 3 516 ms | fora do top 15 |
| Kiro Kiro Z | 2 918 ms | 1 012 ms |
| Leopard C | 471 ms | 198 ms |
| Brachio Z | 420–512 ms | 279 ms |
| Uo Uo C (Demolition Gust) | 338–388 ms | 213 ms |
| Supa Supa C (consulta de entidades, não é o chão) | 1 169 ms | 1 137 ms (não tratado) |
Pior quadro > 100 ms: 16 → 11 técnicas. O piso restante (~150 ms) é a troca de colisão do relevo (item 3).

## Instrumentação deixada (só custa um `if` quando desligada)
`Cronometro` com rótulos `McMundo.getBlockState/terreno_solido/getEntitiesOfClass/setBlock/sendParticles/blocos_e_relevo_tick/relevo_*/BDAD_*` e `Cronometro.amostrar` (quem chama, por amostra de pilha).
