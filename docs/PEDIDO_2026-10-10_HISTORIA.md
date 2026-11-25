# Pedido de 10/10/2026 — Modo História (checkpoint)

Pedido do dono (resumo fiel): marcador de missão (nos alvos até o fim; concluída, aponta
para o NPC que paga); Z da Pika paralisa o jogador, inclusive no ar, enquanto segura;
Z da Hie só dá imunidade ao gelo no 3º disparo, e só se acertar; V da Hie transforma o
terreno em volta em gelo (relevo, casas e árvores branco-azulados), sem crescer, nasce
com limite; NPC que vende barcos (1 moeda cada) e tirar os barcos do mapa; ciclo de dia e
noite (à noite enxerga normalmente); harpia ("águia" com investida e tornado): área
maior, anda direito entre as pedras, atacada alça voo e investe, depois da investida
ganha velocidade voando em volta dos picos; tornado mais rápido. Tudo no Modo História.

## Decisões do dono (10/10)
- Barco comprado: **fica seu**, salvo no progresso, nasce na água do porto ao lado do
  vendedor e **volta ao cais** ao abrir o jogo; um de cada tipo (bote, chalupa, galeão).
- Retirar **todos os 7** barcos do mapa (5 dirigíveis + 2 barcos-casa).
- Dia completo = **24 min** reais (1 min = 1 h do jogo).
- Execução **em sequência, sem agentes** (arquivos compartilhados).

## Interpretações minhas (declaradas, ajustáveis)
- "Tudo no Modo História": Pika Z, Hie Z e Hie V mudam só na história; arena intacta.
- Harpia = boss dos morros (`animais_morros_harpia`); a águia comum da floresta não muda.

## Ordem e estado
| # | frente | estado |
|---|---|---|
| 1 | barcos: retirar do mapa + vendedor + barco salvo | **feito** — `test_vendedor_de_barcos` 47/47 (mapa vivo) |
| 2 | marcador de missão | **feito** — `test_marcador_de_missao` 15/15 + fotos em `art_src/validation/marcador_de_missao/` |
| 3 | Pika Z paralisa segurando | **feito** — campo do Builder `ativacao.paralisar_segurando` (só história); `test_pika_z_paralisa` 7/7 com controle positivo (arena cai) |
| 4 | Hie Z imunidade só no 3º disparo | **feito** — campo `projeteis.imunidade_gelo` (só a 3ª salva), gelo estendido entre salvas (só história); `test_hie_z_imunidade` 10/10 com controle positivo |
| 5 | Hie V terreno de gelo com limite | **feito** — `EraDoGelo` (decal na camada `MapaMontador.CAMADA_CENARIO`, raio fixo 20 m, nasce em 0,35 s); `test_hie_v_gelo` 12/12 + fotos em `art_src/validation/hie_v_gelo/` |
| 6 | ciclo de dia e noite | **feito** — `CicloDiaNoite` (sol, lua, céu com estrelas, ambiente, névoa, exposição), F8 › Avançar 3 h; `test_ciclo_dia_noite` 15/15, meia-noite = 62 % da luz do meio-dia; fotos em `art_src/validation/ciclo_dia_noite/` |
| 7 | harpia: área, voo entre pedras, reação, órbita, tornado | **feito** — `voo_harpia.gd` + `combate_harpia.gd`, área 150 × 130 m, tornado 14 m/s; `test_harpia_voo` 16/16 (mapa vivo); investida, vendaval e apresentação verdes |

## O que mudou, por frente

**1. Barcos.** Mapa vivo sem nenhum barco (as 7 peças saíram; cópia em
`art_src/backups/mapa_historia/baseplate_antes_vendedor_barcos_*.json`). NPC
`npc_vendedor_barcos` (ficha em `NpcDaIlha.FICHAS`, remo fincado ao lado, loja
`src/historia/npcs/loja_de_barcos.gd`) posto na areia, no pé do píer largo (248, 40),
por `tools/mapa_ilha/colocar_vendedor_de_barcos.gd`. Vende todo modelo da categoria
"navios" que navega (bote, chalupa, galeão), 1 moeda; comprado vira "Trazer ao cais".
Save: `ProgressaoDoPersonagem.barcos`. A vaga é procurada em anéis em volta do vendedor
(`src/historia/navios/cais.gd`): água sob o casco inteiro, fundo abaixo do calado + 0,6 m,
volume livre de cenário e de outro barco, proa para o mar. Medido: bote a 36 m, chalupa a
45 m, galeão a 63 m (precisa de 3,9 m de fundo). Nome em português pela classe no leme.

**2. Marcador de missão.** `src/ui/marcador_de_missao.gd` (HUD, atrás das janelas). Campo
`marcar` em `Missoes.TABELA`: `{"inimigos": "bandido"}` marca cada bandido vivo;
`{"npc": tipo}` marca o NPC da tarefa (domador, vendedor de frutas, organizador,
pescador); meta cumprida → só o NPC que paga, com "?". Fora da tela: só o mais perto,
preso à borda (atrás da câmera vai para a lateral, não para a barra de itens).

**3. Pika Z.** Campo novo do Builder `ativacao.paralisar_segurando` ("Paralisa segurando,
até no ar (Modo História)"), ligado no `pika_raio_z.json` e em `tools/criar_pika_pika.gd`.
Vale só com perfil de frutas da história; golpe/captura/gelo (corpo não livre) continuam
mandando no corpo.

**4. Hie Z.** Campo do bloco de projétil `imunidade_gelo` ("Dá imunidade ao gelo ao
acertar (Modo História)"); no `Z_ice.json` só a `salva_2` dá. Na história, acerto em quem
já está congelado ESTICA o gelo (`IceFX.congelar(..., imunidade, estender)`): as três
salvas prendem sem soltar e a imunidade só vem no fim, se a 3ª acertar. Arena: igual a antes.

**5. Hie V.** `src/effects/era_do_gelo.gd`: decal de geada (texturas geradas em código,
preparadas no carregamento) só na camada `MapaMontador.CAMADA_CENARIO` (bit 11, posta no
cenário logo depois de montar o mapa — personagens, bichos, NPCs, barcos e mar fora),
raio fixo 20 m, nasce em 0,35 s com anel de choque, cristais assentados por raio (anel
denso na borda), névoa macia, lampejo frio; desbota no fim (50 s, o campo de antes).
Arena: o V antigo (placa que cresce).

**6. Dia e noite.** `src/world/ciclo_dia_noite.gd`, ligado no `ModoHistoria` depois do
`WorldEnv`. Sol de 6 h a 18 h, lua (2ª luz direcional) à noite, uma sombra por vez; céu,
nuvens, ambiente, névoa, contorno e exposição por paleta-chave; estrelas no `ceu.gdshader`
(uniforme `estrelas`, 0 na arena). Começa às 8 h (não salva a hora). F8 › Avançar 3 h.

**7. Harpia.** Território 150 × 130 m (`tools/mapa_ilha/ampliar_area_da_harpia.gd`);
enfrenta até 60 m. `voo_harpia.gd`: voa olhando 0,8 s à frente com uma esfera do corpo e
desvia pela superfície, folga de 4,5 m do chão, inclina na curva. Ronda os picos achados
no território (4 no mapa vivo: 50, 44, 35 e 32 m) — 9 m/s sozinha, 16 m/s em combate.
Ataque: chega a 21 m/s até o alcance → prepara (freando no ar) → investida → ARREMETE
(26 → 16 m/s, asas abrindo) e volta à ronda. Levou golpe: alça voo 0,45 s e investe mesmo
com recarga (no máximo 1 reação a cada 4 s; não com quem está no tornado dela). Depois do
vendaval volta a rondar enquanto o tornado vive. Tornado 14 m/s (rampa vertical ∝
velocidade). Fica ativa no LOD durante o combate.

## Validação (10/10/2026)
`test_vendedor_de_barcos` 47/47 · `test_marcador_de_missao` 15/15 · `test_pika_z_paralisa`
7/7 · `test_hie_z_imunidade` 10/10 · `test_hie_v_gelo` 12/12 · `test_ciclo_dia_noite`
15/15 (meia-noite = 62 % da luz do meio-dia, contraste 78 %) · `test_harpia_voo` 16/16 ·
`test_harpia_investida`/`_vendaval`/`_apresentacao` 0 falhas · `test_barcos_guardados_mapa`
(ajustado: mapa sem barcos, frota comprada atraca) 0 falhas · `test_ilha_inicial`: só as 2
conhecidas (encosta 0,092 / correndo +0,073). Fotos em `art_src/validation/`
(`marcador_de_missao`, `hie_v_gelo`, `ciclo_dia_noite`, `harpia_voo`).
Não medido: FPS do mapa completo com o decal do V e com a lua; playtest do dono.

## Escolhas minhas (ajustáveis) e gatilhos
- Raio do V 20 m; dia começa às 8 h; noite ≥ 45 % da luz do dia (medido 62 %).
- Harpia: raio de combate 60 m, velocidades 9/16/21/26 m/s, reação a cada 4 s, território
  encosta 20 m no do gorila. Tudo em `config_harpia.gd`.
- Vaga do galeão a 63 m do vendedor (fundo). Gatilho: o dono achar longe → píer próprio
  para o galeão ou vendedor mais perto do fundo.
- `progressao.gd` com 840 linhas: perto de 880, tirar ilhas/missões/barcos para arquivo próprio.
