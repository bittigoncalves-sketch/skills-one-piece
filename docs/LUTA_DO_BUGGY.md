# Luta do Buggy no ringue (22/11/2026)

Pedido do dono: o Buggy luta contra o jogador num **ringue de luta livre**, na mesma mecânica do treino (teclas Z/X/C) com o **mesmo tempo do treino** (1,2 s por tecla; decisão do dono em 22/11, 3ª rodada — era 0,6 s) e a tecla **F para defender**. Cada lutador tem **11 de vida**; 11 acertos do jogador vencem, vida do jogador a zero o Buggy vence. **Luvas vermelhas** nos dois. Recompensa: **350 moedas + 6500 XP** e libera a missão do **barril** (Alvida). Arte e falas: Codex; código: Claude.

## Como funciona
- **Quando (atualizado 22/11, 2ª rodada):** errar os copos JÁ entrega a missão `defender_a_vila` (sem a pergunta "aceita proteger a vila?"): treinar com o instrutor até o **nível 3** (onde ele recusa mais treino) e desafiar o Buggy. A bússola aponta o **instrutor** até o nível 3 e depois o **Buggy**; a da Alvida fica escondida para quem não venceu o Buggy. Saves antigos em `copos_errado`/`recusou` migram sozinhos (`RegrasDoDesafioBuggy.migrar`). Com o nível, chegar a 6 m do Buggy ou apertar **E** abre a fala; ao fim dela a luta começa. Perder não custa nada: dá para lutar de novo (E, depois de ~8 s).
- **Rodada:** sai UMA tecla. **Z/X/C** = ataque do jogador (acertou: soco, −1 do Buggy; errou: nada). **F** = o Buggy ataca (acertou: bloqueia; errou ou estourou o tempo: −1 do jogador). Sem mais de 3 rodadas do mesmo tipo em fila; ~40 % das rodadas são defesa. Esc desiste (sem punição).
- **Vitória:** `RegrasDaLutaDoBuggy.concluir` entrega a missão (6500 XP + 350 moedas da tabela `missoes.gd`) e grava a fase `luta_vencida`; `RegrasDaAlvida.venceu_o_buggy` aceita `copos_certo` **ou** `luta_vencida` (o barril abre). Idempotente.

## Código
`src/historia/buggy_cais/`: `regras_da_luta_do_buggy.gd` (contas), `luta_do_buggy.gd` (minigame: UI, golpes, luvas, câmera, falas), `ringue_do_buggy.gd` (ringue por código, texturas do Codex em `assets/textures/luta_do_buggy/`), integração em `desafio_do_buggy.gd` (`_pre_luta`, `_iniciar_luta`, `_ao_fim_da_luta`). Falas: `data/dialogos/luta_do_buggy.json` (de `docs/LUTA_DO_BUGGY_FALAS.md`). Luvas: o acessório `luvas_boxe_vermelhas` já existente (jogador `Hand_*`; Buggy `itemMainHand`/`itemOffHand`).

## Testes (headless)
`test_regras_da_luta_do_buggy` (25), `test_luta_do_buggy_no_mapa` (vitória, derrota, nova tentativa, luvas, ringue, pagamento); capturas: `tools/dev_tests/captura_luta_do_buggy.gd` (Weston).

## Interpretações do Claude, a confirmar
1. A mecânica das rodadas (ataque do jogador × ataque do Buggy em F) e a chance de 40 % de defesa.
2. Errar um ataque não tira vida; só defesa falha tira.
3. A luta é só para quem errou os copos e chegou ao nível 3 (`NIVEL_DA_LUTA`).
**GATILHO:** se o dono quiser a luta também para quem acertou os copos, mudar `resolver_copos`/`luta_disponivel`.

## 3ª rodada (22/11): golpes, guarda e barril
- **Z rápido / X carregado / C múltiplo**, como no treino, para o jogador **e para o Buggy**: Z = um jab; X = pausa para armar e impacto forte; C = três socos. Todos tiram **1** de vida (decisão do dono). O Buggy sorteia o golpe a cada ataque dele e o arma em câmera lenta durante a janela do F (modelo dele: `punch_right/left`, `punch_overhead`); se você erra um ataque, ele se defende (`guard`).
- **F = guarda de boxe com as duas mãos** (`POSE_DE_GUARDA`: punhos junto ao rosto, tronco agachado). Calibrado por captura (o antebraço direito do rig tem o sinal invertido).
- **Barril da Alvida:** só existe depois de **vencer o Buggy num dos dois jogos** — os copos (logo depois do baú do Barba Negra) ou o boxe da missão de revanche. `RegrasDaAlvida.liberar` exige `venceu_o_buggy`; quem recebeu o barril antes disso (sem vitória nem duelo) o perde até vencer.

## Marcadores em cada objetivo (22/11, 4ª rodada)
`src/ui/marcador_de_missao.gd` ganhou **objetivos registrados**: qualquer sistema liga um nó como objetivo de uma missão com `MarcadorDeMissao.marcar(no, missao, altura, ligado)` e o losango aparece enquanto a missão está aceita (até 6 mais perto por missão). Usos: o **instrutor** (revanche, falta nível) e o **Buggy** (copos; revanche com o nível) em `desafio_do_buggy.gd`; o **mímico** e o **baú** do resgate (`resgate_do_bau.gd`); **cachos, totens e fruto dourado** (`props_de_missao.gd`, somem ao colher). Por dado (`marcar: {"alvos_de_golpe": id}` em `missoes.gd`): **Gorila-rei** e **macacos saqueadores**. Teste: `test_marcadores_de_objetivo`.
