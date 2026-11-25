# Relevo em blocos — plano e checkpoint (22/10/2026)

Pedido do dono: "substituição do relevo por blocagem, basicamente retirar blocos do minecraft
sem a textura, entre eles um bloco normal, meio bloco, bloco escada, novo bloco bloco lateral
que é um meio bloco só que na vertical. [...] cada ilha fica em cima de um único bloco gigante,
estes blocos compõem o relevo, o objetivo é usar o mínimo de dobras possíveis, a conexão das
dobras elimina a textura da conexão em outras palavras um único bloco se torna um só e sua
hitbox também, isso ocorre quando o jogo começa".

## Decisões do dono (22/10/2026)

- Bloco de **0,88 m** — a escala das estruturas do Mine Piece (2 blocos = jogador + 10 %).
- **Todas as 11 ilhas.**
- O jogador **sobe meio bloco sozinho** (0,44 m: meio bloco e escada andáveis; bloco inteiro pede pulo).
- **Uma cor só por enquanto**, mas cada bloco guarda o NOME do solo (grama, terra, areia, rocha,
  mata, leito) para receber cor depois.

## Decisões minhas (declaradas)

| Decisão | Benefício | Alternativa rejeitada | Gatilho de revisão |
|---|---|---|---|
| Fonte = as peças `terreno` do mapa (alturas), convertidas em blocos AO MONTAR o Modo História; arquivo e editor intactos | sem migração, editor continua editando o relevo | peça nova com voxels no arquivo (migra 11 ilhas, editor novo) | dono pedir editar bloco a bloco |
| Grade de **meios blocos** (0,44 m) alinhada à origem do mundo; os 4 tipos são combinações de 2×2×2 meios: bloco = 8, meio bloco = 4 de baixo, lateral = 4 de um lado, escada = 4 de baixo + 2 de um lado | todos os tipos cabem num mapa de alturas de 0,44 m → uma malha só, sem caso especial por tipo | malha por tipo de bloco | — |
| Célula ajustada ao relevo pela menor diferença entre: uniforme (bloco/meio bloco), ou dois lados (escada/lateral) com o lado alto em número PAR de meios — a única forma de empilhar sem sobra | sempre um tipo válido, nada flutuando | arredondar cada meio (gera formas fora da lista) | — |
| Fusão gulosa: topo = retângulos de mesma altura e mesma COR; paredes = faixas iguais ao longo da borda; faces de baixo e faces entre blocos cheios não existem | "mínimo de dobras"; a cor por solo depois só separa o que tiver cor diferente | uma face por bloco | contagem de faces de uma ilha > 200 mil → fusão 2D das paredes |
| Uma malha e UMA forma de colisão (malha côncava) por ilha, com a mesma geometria | hitbox = o que se vê, um corpo por ilha | caixas por bloco (milhares de formas) | jogador prender em aresta → caixas fundidas |
| No editor de mapa o relevo continua liso (é a fonte) | editor sem mudança | — | — |

## Etapas

| # | Entrega | Validação |
|---|---|---|
| E1 | `src/world/relevo_em_blocos.gd`: amostra, ajusta células, funde faces, gera malha + colisão | `test_relevo_em_blocos`: tipos, fusão (plano = 1 face de topo), sem faces internas, altura ≈ fonte |
| E2 | Modo História: um corpo de relevo por ilha; malha/colisão das peças `terreno` desligadas no jogo (água do rio continua); animais e pomar reconhecem o corpo novo; LOD | teste de montagem + testes das ilhas |
| E3 | Subida automática de meio bloco (Modo História) | teste: sobe meio bloco e escada andando, bloco inteiro barra |
| E4 | Estruturas do Mine Piece e platôs na grade de 0,88 m (gerador); medir o que flutua/enterra nas ilhas antigas | `test_ilhas_mine_piece` (piso rente ao bloco), `test_ilha_inicial` |
| E5 | Capturas GPU, tempo de abrir, quadro, faces/ilha | números antes/depois; gatilho: abrir +3 s → cache em disco / threads |

## Checkpoint

- **22/10 ~23:00:** decisões tomadas; E1 em andamento.
- **22/10 ~23:20:** E1–E4 implementados.
  - **E1** `src/world/relevo_em_blocos.gd` + `test_relevo_em_blocos` 12/12 (plano = 5 faces; duas peças
    vizinhas = as mesmas 5 faces; rampa: ≤ 1 meio da fonte, degraus de 1 meio; penhasco com lateral;
    raio bate no topo do bloco).
  - **Tempo** (12 núcleos): 1ª versão 56 s para as 11 ilhas → caminho rápido para célula quase plana
    (< 0,5 meio de diferença: o uniforme sempre ganha), paredes sem alocação, amostragem sem chamada:
    Ilha Inicial 12,6 s → 2,9 s; ilhas em paralelo (`WorkerThreadPool`, só dados na thread): 7,2 s;
    **cache em `user://relevo_em_blocos/`** por chave das peças (+ `VERSAO`): **1,1 s** nas aberturas
    seguintes (0,2 s lendo, o resto é criar malha e colisão na thread principal). Gatilho: passar de 2 s
    → guardar também a malha e a forma prontas (`ResourceSaver`).
  - **Faces** (depois da fusão): Inicial 79.720; Macacos ~30 mil; East Blue ~23 mil; ilhas do Mine Piece
    4,5–14 mil.
  - **E2** `src/historia/ilhas/relevo_das_ilhas.gd`: um `StaticBody3D` por ilha (meta `relevo_em_blocos`
    e `ilha`); malha e colisão das peças `terreno` desligadas no jogo (água do rio fica); LOD trata como
    chão; animais (`_peca_do_chao`) e pomar reconhecem o corpo.
  - **E3** `src/player/subir_degrau.gd` (chamado em `Player._etapa_mover`, só cápsula/Modo História):
    `test_subir_degrau` 4/4. A cápsula tem raio 0,5 m: subindo só o passo do quadro ela pousava na quina
    (normal 0,55) — lá em cima avança passo + raio.
  - **E4** gerador do Mine Piece na grade (platô em múltiplo de 0,88 m; estrutura com as quinas nas
    linhas do mundo; árvores, gente e lojas das ilhas antigas pousam no bloco); `assentar_nos_blocos.gd`
    desceu 114 peças das ilhas antigas (cópia `baseplate_antes_assentar_blocos_dc8e20d474d4.json`).
    `medir_assentamento_blocos.gd`: **0 flutuando** nas 11 ilhas; 78 enterradas > 0,3 m (as 64 da
    Inicial já eram de propósito no liso).
  - Captura de Wano: faixa verde na costa = topo do bloco em 0 coincidindo com a placa → chão acima de 0
    tem pelo menos meio bloco (`_acima_do_zero`). A cor saía quase branca: faltava converter sRGB → linear
    na paleta (o `TerrenoDoMapa` converte) — corrigido, cor #9b9c92.
- **23/10 ~11:30 — testes de interação, travamento na descida, E5 (medição) e "ilha oca".**
  - **Bug "trava ao descer" (relato do dono):** causa = a parede subia `SOBRA` (3 mm) acima do topo,
    e a colisão é a mesma malha → lâmina na borda; a cápsula raspava a aresta (normal de chão) e
    parava. `_parede` sem SOBRA no topo + `VERSAO` 5 (o cache guardava a geometria velha).
    `test_descer_degrau` 1/8 → **8/8** (meio bloco, bloco, 2 e 4 blocos; de frente e diagonal).
    Registro em `docs/erros.md`.
  - **Ilhas de verdade:** `test_varredura_relevo` atravessa bordas retas de Inicial, Macacos, Wano e
    Shandora: **48/48** (23 descidas e 23 subidas de meio bloco; 2 puladas por esbarrar em
    estrutura). As ilhas reais quase não têm borda reta e larga com desnível ≥ 2 meios — esses
    ficam cobertos só pelos casos sintéticos.
  - **"Ilha oca" (decisão do dono: medir e cortar sobras):** o relevo JÁ é casca (mapa de alturas;
    sem face interna nem de baixo). A sobra estava nas 520 peças lisas: só escondidas, e a forma presa
    na meta `terreno_forma` (seleção do editor). Agora soltas, e `cor`/`tipos` também
    (`medir_memoria_relevo`): estática **1363,5 → 1180,6 MB**, vídeo **1331,3 → 1258,2 MB**.
  - **Fusão:** 8,05 M faces unitárias → 206 mil (39×; Macacos 16×, Mine Piece ~60–70×).
    Malha 1,24 M vértices sem índice; colisão 413 mil triângulos; `f` na CPU 28,6 MB.
  - **Renderização** (`medir_ilhas_mine_piece`, blocos × `--relevo-liso`): quadro igual ou menor
    em todos os 7 pontos (ex.: east_blue_alto 11,12 × 11,93 ms), chamadas de desenho menores. Exceção
    em primitivas: Inicial no spawn 1,51 M × 0,84 M — o relevo é UMA malha por ilha, o Godot não
    descarta pedaço fora da tela (e entra em cada cascata de sombra).
  - **Gatilhos deixados:** primitivas da malha única custarem quadro (Inicial no spawn > 10 ms) →
    partir o relevo da ilha em blocos de ~64 m; memória apertar → `f` em 16 bits e índice na malha
    (~3–4 MB, não compensa hoje).
  - Falhas da bateria que JÁ existiam sem esta mudança (conferido revertendo): `test_ilha_inicial`
    (pé −0,005 m correndo), `test_agua` (técnicas submerso), `test_compila`/`test_modo_historia`
    (ScreenFX/FruitNet/GameFlow não encontrados).
