# Mar do Modo História — plano e estado (14/10/2026)

Pedido do dono (fiel): "construção do mar do modo história, começando pelo relevo marinho,
seguindo para os recifes de corais, embarcações naufragadas, esqueletos e ouro nas
embarcações, probabilidade de spawn de sea beast agressivo quando o jogador estiver
navegando pelo mar, peixes, renderização e aceleração de desempenho".

## Ponto de partida (medido no código, 14/10/2026)

- `src/world/fundo_do_mar.gd`: rampa lisa (smoothstep) da praia até −30 m em 150 m, plano
  até 600 m; um fundo por ilha, encontro no meio (x = 814) a −30 m; grade de 8 m; cor só
  pela profundidade; colisão em 4 faixas `HeightMapShape3D`. Além do alcance: vazio.
- Superfície `oceano_historia.gdshader` OPACA; visão submersa = tinta azul na HUD
  (`AguaHud`) + `LuzSubaquatica` (omni). Sem névoa, sem cáusticas.
- Bestas do mar (`src/historia/bestas_mar/`): só as colocadas no editor; serpente hostil,
  três pacíficas; bolhas e raio compressor. Barco (`src/historia/navios/barco.gd`) sem vida.
- Ilhas: inicial 512 × 512 m na origem; Macacos 256 × 256 m em (1500, 0). Porto a leste da
  inicial (vendedor em (248, 40)); vagas do cais a 36/45/63 m dependem do fundo.
- Loja já tem: 40 peixes (`pesca`), `skeleton`, `skull`, `large_bone`, `chest_gold`,
  `coins`, `gold_rocks`, `cannon`, navios. Não tem: corais, cascos quebrados.

## Decisões do dono (14/10/2026)

| tema | decisão |
|---|---|
| visão | **só mergulhando**: a superfície segue opaca; o investimento é a visão submersa |
| relevo | **plataforma 5–25 m** perto das ilhas (bancos de areia, dunas, rochas, recifes) + **mar aberto 60–80 m** entre as ilhas com fossa/cânion; naufrágios a 8–22 m (alcance do fôlego de 30 s) |
| tesouro | **esqueletos decorativos**; um **baú por naufrágio**, abre **uma vez por save**, 15–40 de ouro (a moeda das lojas) |
| besta navegando | surge por chance com o jogador navegando; **começa atacando o BARCO**; se o jogador a acertar, **passa a atacar o jogador** |

Pendente (perguntar na etapa E5): o que acontece quando o barco chega a zero de vida.

## Escolhas minhas (declaradas, ajustáveis)

- **Em sequência, sem agentes**: há outra sessão ativa (Phoenix) e arquivos compartilhados
  (`ModoHistoria.gd`, loja). Testes com `SOP_PORTA` próprio.
- **Relevo = um campo de altura ÚNICO em coordenadas do mundo**, levando em conta todas as
  ilhas; cada `FundoDoMar` só amostra esse campo na sua grade → a emenda no meio é contínua
  por construção (hoje ela depende de os dois chegarem a −30 m). Rede de segurança: plano
  de colisão abaixo do fundo mais fundo (o vazio além do alcance some).
- **Faixa do porto preservada**: os primeiros ~70 m da costa mantêm o perfil de hoje perto
  do píer (as vagas do cais são medidas contra o fundo).
- **Corais e peixes = tempo de jogo, determinísticos** (semente fixa), `MultiMesh` por
  espécie por bloco: milhares de instâncias não vão para o arquivo do mapa (como o
  `FundoDoMar`). **Naufrágios = peças do mapa vivo**, postas por ferramenta idempotente com
  backup, categoria nova `naufragios` na loja; o comportamento (esqueletos, baú) liga no
  jogo, como bestas e NPCs → o dono pode mover/apagar no editor.
- **Modelos novos** (corais, cascos naufragados) em Blender headless, fonte em
  `tools/blender/` + `art_src/mar/`. Peixes: os 40 modelos da loja, nado por vertex shader.

## Etapas

| # | etapa | resultado observável | arquivos | validação |
|---|---|---|---|---|
| E0 | linha de base | snapshot + números de GPU/CPU no mar ANTES | `tools/dev_tests/medir_mar.gd`, `~/dev/sop-snapshots/2026-10-14-mar-historia/` | tabela abaixo |
| E1 | relevo marinho | plataforma, bancos, dunas, rochas, talude, mar aberto 60–80 m, fossa entre as ilhas; material com ondulação de areia e rocha na encosta | `fundo_do_mar.gd` (+ campo de altura puro), shader do fundo | teste do perfil (profundidades por faixa, emenda, porto), `test_agua`, `test_ilha_dos_macacos`, `test_vendedor_de_barcos`, fotos |
| E2 | recifes de corais | manchas de recife na plataforma (3–18 m), 6+ formas de coral/alga, balanço | Blender `corais.py`, `src/historia/mar/recifes.gd` | contagem por zona, nenhum coral fora d'água/flutuando, custo medido, fotos |
| E3 | naufrágios | 3 cascos (galeão partido, chalupa tombada, bote emborcado) assentados no fundo, 8–22 m | Blender `naufragios.py`, loja `naufragios`, ferramenta de colocação, `naufragio.gd` | assentamento (sem flutuar/enterrar), colisão, editor abre/salva, fotos |
| E4 | esqueletos e ouro | esqueletos decorativos e baú com ouro; E abre uma vez por save | `naufragio.gd`, `progressao.gd` | abrir dá ouro, reabrir não, save/reload, sem ouro fora d'água |
| E5 | besta agressiva navegando | chance periódica em mar aberto, aviso, ataca o barco, troca para o jogador ao ser acertada, some longe | `src/historia/mar/encontros_no_mar.gd`, `besta_do_mar.gd`, `barco.gd` | probabilidade com semente, alvo barco → jogador, despawn, máx. 1 |
| E6 | peixes | cardumes perto dos recifes e no mar aberto, fogem do jogador | `src/historia/mar/cardumes.gd`, shader de nado | contagem, desvio do jogador, custo só perto/submerso |
| E7 | renderização e desempenho | névoa/absorção submersa, cáusticas, raios de luz, superfície vista de baixo; custo ≤ linha de base + orçamento | pós-processo submerso, `oceano_historia.gdshader`, LOD | `medir_mar.gd` antes/depois, fotos comparáveis |

## Estado

### E0 — linha de base: feita (14/10)
Snapshot `~/dev/sop-snapshots/2026-10-14-mar-historia/antes.tgz` (+ SHA256 do mapa e da loja).
`tools/dev_tests/medir_mar.gd` (GPU, v-sync desligado, 90 quadros por ponto, 1280×720):

| ponto | objetos | draws | primitivas | cpu ms | gpu ms | quadro ms |
|---|---|---|---|---|---|---|
| porto_superficie | 472 | 256 | 346 486 | 0,47 | 4,38 | 6,10 |
| plataforma_submersa | 482 | 261 | 346 520 | 0,47 | 4,61 | 5,83 |
| talude_submerso | 482 | 261 | 346 544 | 0,47 | 4,12 | 5,63 |
| norte_submerso | 518 | 298 | 218 994 | 0,44 | 4,59 | 5,81 |
| mar_meio_navegando | 472 | 256 | 346 486 | 0,37 | 4,57 | 4,80 |
| mar_meio_submerso | 482 | 261 | 346 544 | 0,39 | 4,37 | 4,72 |
| macacos_submerso | 695 | 369 | 519 376 | 0,56 | 5,15 | 5,46 |

### E1 — relevo marinho: feita (14/10)
- **Campo único** `src/world/relevo_marinho.gd` (`RelevoMarinho`, puro, semente fixa,
  `FastNoiseLite` em coordenadas do mundo): d < 60 m = rampa de antes; plataforma 60–160 m
  (~−12 → −16 m) com ondulação, baixios (+8 m), dunas (0,8 m, 26 m), afloramentos de rocha;
  talude 160–360 m com ravinas; mar aberto ~−64 m; fossa serpenteando na linha do meio
  entre ilhas (|d1 − d2|), fundo ~−80 m. Teto de navegação: nada além de 60 m sobe acima de
  5 m de água. `amostra()` devolve altura + máscaras (rocha, recife, duna) — **fonte única
  para os corais (E2)**.
- **`FundoDoMar` reescrito**: grade global de 4 m (antes 8 m) em blocos de 128 m, cada um
  da ilha mais perto, com `visibility_range_end` 420 m; colisão `HeightMapShape3D` por bloco
  (em pedaços de 32 m na costa, sem os de baixo da ilha); nó posicionado no centro da ilha
  (corrige o LOD — `docs/erros.md`); `AbismoDoMar` em volta da grade (antes: vazio além de
  600 m). Material próprio `src/world/fundo_do_mar.gdshader` (cor pela profundidade, rocha,
  substrato de recife, marcas de corrente na areia, emenda com a praia) com a luz cel de
  `src/fx/shaders/luz_cel.gdshaderinc`.
- **Testes:** `test_relevo_marinho` 0 falhas (perfil por faixa, folga, continuidade < 5 m em
  4 m, fossa contínua 25/25 a −81,8 m, colisão = campo na grade, sem buraco, abismo sem
  degrau, sabotagem) · `test_agua` 0 · `test_ilha_dos_macacos` 0 · `test_lod_das_ilhas` 0 ·
  `test_vendedor_de_barcos` 47/47 (vagas a 45/63 m, iguais) · `test_compila` só as 6 conhecidas.
  Montagem: 1,33 s no carregamento (gatilho: > 2 s ou 3ª ilha → montar em thread).
- **Medido depois** (mesmas condições): GPU 3,84–4,88 ms (antes 4,12–5,15), primitivas
  241 mil (antes 346 mil: o corte por distância dos blocos), +12 draws.

| ponto | objetos | draws | primitivas | cpu ms | gpu ms | quadro ms |
|---|---|---|---|---|---|---|
| porto_superficie | 484 | 268 | 240 958 | 0,46 | 3,90 | 5,29 |
| plataforma_submersa | 494 | 273 | 240 990 | 0,45 | 4,35 | 5,57 |
| talude_submerso | 493 | 272 | 238 968 | 0,44 | 4,13 | 5,28 |
| norte_submerso | 530 | 309 | 168 516 | 0,43 | 4,24 | 5,45 |
| mar_meio_navegando | 483 | 267 | 238 910 | 0,34 | 4,06 | 4,25 |
| mar_meio_submerso | 494 | 273 | 241 016 | 0,35 | 4,54 | 4,73 |
| macacos_submerso | 709 | 383 | 416 952 | 0,51 | 4,88 | 5,09 |

- **Pendências para a E7:** o `Contorno` desenha a silhueta das cristas do fundo como
  linhas pretas (mesma família do item 72); a superfície vista de baixo é a de cima; sem
  névoa, o talude e a fossa parecem "secos". Fotos: `art_src/validation/mar/medir_e1_*.png`.

### E2 — recifes de corais: feita (14/10)
- **Direção do dono (14/10): "One Piece vibrante".** 10 formas em
  `tools/blender/corais.py` → `art_src/blender/corais.blend` + `assets/models/mar/corais.glb`:
  ramo (chifre-de-alce roliço), cérebro (sulcos), leque (gorgônia, balança), tubos,
  mesa, anêmona (balança), alga/kelp (4,5 m, balança), bolhas, estrela, ouriço
  (224–1.872 triângulos). A cor de vértice carrega MÁSCARAS (gradiente, oclusão por
  raios, detalhe, peso do balanço); a COR é do material (`src/historia/mar/coral.gdshader`):
  4 paletas por espécie, escolhidas por instância, balanço no vértice, luz cel de água.
- **Plantio** `src/historia/mar/recifes.gd`: lê `RelevoMarinho.amostra` (recife, rocha,
  profundidade); colônias por ruído celular; algas em florestas (7–32 m); anêmonas/ouriços
  na rocha; estrelas e ouriços soltos na areia. Blocos de 64 m sob demanda (1 por quadro),
  um MultiMesh por espécie, alcance de desenho 120 m, escondidos com a câmera fora d'água.
  Sem colisão (gatilho: o dono pedir apoio nos corais grandes).
- **Orquestrador** `src/historia/mar/mar.gd`: o `ModoHistoria` chama uma vez; as etapas
  seguintes entram lá.
- **Testes:** `test_recifes` 0 falhas (9.793 instâncias na plataforma da inicial, 10/10
  espécies, nada raso/fora d'água/flutuando/enterrado, recife só na zona, determinístico,
  controles vazios, esconde fora d'água) · `test_relevo_marinho` 0 · `test_compila` só as
  6 conhecidas · `test_modo_historia` 89/90 — a falha é do Estilo de Combate Base (item 73
  da LISTA), não do mar.
- **Custo medido (A/B no mesmo ponto, com e sem o `Mar`):** recife denso +0,95 ms de GPU,
  +40 draws, +36 mil primitivas desenhadas (o LOD automático corta os ~458 mil brutos do
  bloco mais cheio); plataforma +0,36–0,58 ms; superfície e mar aberto ≈ 0.
- Fotos: `art_src/validation/mar/recifes_e2_*.png` (`tools/dev_tests/capturar_recifes.gd`).
  Revisão artística do dono pendente; a cara final depende da névoa submersa (E7).

### E3/E4 — naufrágios, esqueletos e ouro: feitas (14/10)
- **Modelos** `tools/blender/naufragios.py` → `art_src/blender/naufragios.blend` +
  `art_src/mar/naufragio_{galeao,chalupa,bote}.glb`: tábuas com espessura e cor própria,
  costelas expostas, convés com buracos, rombos, galeão PARTIDO (proa tombada ao lado),
  chalupa deitada, bote emborcado, mastro caído com vela rasgada (pano único), barris,
  canhões; marcadores `ponto_bau`/`ponto_esqueleto_*`. 10,6 mil / 4,8 mil / 2 mil triângulos.
- **Loja:** categoria nova `naufragios` (`tools/importar_naufragios_na_loja.gd`; 402 → 405).
- **Mapa vivo:** 5 peças `naufragio_1..5` (3 na inicial, 2 nos Macacos) por
  `tools/mapa_ilha/colocar_naufragios.gd` (idempotente; sítio = 8–22 m de água, chão plano
  sob o casco, fora de recife/rocha, ≥ 170 m do porto, ≥ 150 m entre si, casco ao longo da
  curva de nível). Cópia: `art_src/backups/mapa_historia/baseplate_antes_naufragios_3f1f19b9b36e.json`.
  1.287 → 1.292 peças.
- **No jogo** `src/historia/mar/naufragios.gd`: assenta pela menor altura sob o casco,
  madeira afundada (`naufragio.gdshader`: alga por cima no mundo, cracas, lodo), esqueletos
  da loja na pose final de "Death" (deitados, sem custo por quadro) + crânio, baú fechado
  com brilho fraco → E abre uma vez por save (galeão 40, chalupa 25, bote 15 de ouro) e vira
  o baú cheio de ouro. Save: `ProgressaoDoPersonagem.sistemas["mar"]["baus"]` (ponto
  genérico novo: `dados_de`/`gravar_dados`). HUD: registro genérico `ligar_interagivel`.
  LOD: naufrágio = "miúdo".
- **Testes:** `test_naufragios` 0 falhas (5 ligados, assentados sem canto flutuando, 8–22 m,
  material, colisão do casco por grade de raios, 11 esqueletos DEITADOS — cabeça < 0,5 m —,
  baú fechado com brilho, controle fora de alcance, E pela HUD paga 40 uma vez, save).
- **Achado e corrigido:** quadrados claros em volta do jogador mergulhando — vazamento da
  luz omni no `light()` em faixas (`docs/erros.md`; o `cel.gdshader` ainda tem: LISTA 75).
- Fotos: `art_src/validation/mar/naufragio_e3_*.png` (`tools/dev_tests/capturar_naufragios.gd`).

### E5 — besta agressiva navegando: feita (14/10)
- **Decisões do dono (14/10):** ~1 encontro a cada 5–6 min navegando; a besta começa
  atacando o BARCO e, se o jogador a acerta, passa a atacar o JOGADOR; barco a zero
  AFUNDA e é PERDIDO (compra-se outro no vendedor).
- **`src/historia/mar/encontros_no_mar.gd`:** sorteio a cada 20 s só PILOTANDO em mar
  aberto (≥ 150 m da costa, ≥ 25 m de água), chance `1 − e^(−20/330)` (média medida com
  semente: 5,75 min); aviso de 3 s (redemoinho em espiral `redemoinho.gdshader` + bolhas +
  aviso na tela); a besta surge a 38 m, à frente ±60°, com barra de vida no topo; espécie por
  peso (bovina 30, girafa 30, javali 25, serpente 15 — só com > 45 m de água); a coleira é a
  visão até o alvo; desiste aos 120 s, perto da costa, sem barco ou com o jogador a > 250 m
  (mergulha e some); folga de 90 s entre encontros. Abate paga XP pelo `_ao_abater_besta`.
  F8 › "Besta do mar no barco" força um encontro.
- **Barco** (`barco.gd`): `health` pela ficha (bote 150, chalupa 400, galeão 1500),
  `take_damage` × `FATOR_DE_DANO_NO_CASCO` 1,2 (medido: bote afunda em ~67 s de ataque
  contínuo; com 0,3 levava 268 s e nunca afundava num encontro), afunda em 4,5 s; o
  `Navegacao` solta o piloto na água, tira o barco da frota (`progressao.perder_barco`) e
  avisa; a dica do leme mostra o casco danificado. As bolhas e o raio aceitam o grupo
  `alvo_de_besta` (`colisao_agua.gd`).
- **Regressão achada e corrigida:** o passeio das bestas (ponto fixo 100 m mar adentro)
  caía na plataforma rasa — `populacao.pontos_da_costa` agora segue até ter água para o
  corpo inteiro (`docs/erros.md`). A/B: fundo antigo 32/32, relevo novo antes da correção
  29/32, depois 32/32.
- **Testes:** `test_encontros_no_mar` 0 falhas (probabilidade, controles, aviso, alvo barco,
  casco toma dano e jogador não, troca de alvo ao ser acertada, tempo até afundar,
  afundar = perdido e piloto solto, recuo, abate com XP, folga) · `test_navios` 42/42 ·
  `test_vendedor_de_barcos` 47/47 · `test_barcos_guardados_mapa` 0 · `test_rotina_oceano_bestas`
  32/32 (janela 110 → 200 s, passeio mais longe) · `test_comportamento_bestas_mar` 61/64 e
  `test_ataques_agua_bestas` 39/40 = as falhas já conhecidas da LISTA (08/10).
- Fotos: `art_src/validation/mar/encontro_e5_{aviso,ataque}.png` (`capturar_encontro.gd`).

### E6 — peixes: feita (14/10)
- **`src/historia/mar/cardumes.gd`:** os peixes da loja (`pesca`) têm ESQUELETO e MultiMesh não
  faz skinning — cada espécie é preparada uma vez: malha na pose de repouso pela composição
  das transformações locais até a raiz (o `bake_mesh_from_current_skeleton_pose` falha: a
  skin só é registrada no servidor de renderização), normalizada (comprimento 1, cabeça em
  −Z pela ponta mais larga), cada superfície com o material de nado (`peixe.gdshader`) e a
  cor original clareada/saturada (as da loja viravam silhueta num peixe de meio metro).
- **Tipos:** recife (10–24 peixes, 0,42–0,65 m), recife grande, mar aberto (atum, vermelho,
  espadarte), solitário (napoleão, tubarão, peixe-lua) e fossa (> 70 m: peixe-diabo,
  tubarão-duende, peixe-bolha). A CPU move só o CENTRO de cada cardume (vaguear em volta de
  casa, entre o fundo e a superfície, fugir do jogador a < 7 m); rabo e oscilação no
  shader, com `agitacao` por cardume na fuga. Só com a câmera submersa; blocos de 64 m
  determinísticos.
- **Teste:** `test_cardumes` 0 falhas (24 espécies normalizadas, onde cada tipo vive, casa na
  água, determinístico, vagueia perto de casa, não sai da água em 30 s, foge +5,6 m em 2 s
  contra 2,4 m calmo, agita, esconde fora d'água). Foto: `recifes_e6_cardume.png`.

### E7 — renderização submersa e desempenho: feita (14/10)
- **Visão submersa** `src/historia/mar/visao_submersa.gd` (só com a câmera debaixo d'água):
  cáusticas (`agua_causticas.gdshader`, soma de luz nas faces para cima, forte no raso),
  névoa da água + raios de luz (`agua_nevoa.gdshader`, cor pela profundidade da câmera e pela
  luz do ciclo dia/noite; desenha DEPOIS do `Contorno` → as linhas pretas do fundo somem na
  água — pendência da E1 resolvida), neve marinha em volta da câmera; a tinta chapada da
  `AguaHud` sai. **Superfície vista de baixo** (`oceano_historia.gdshader`, face de trás):
  janela de Snell clara olhando para cima, espelho escuro em ângulo rasante, ondulação.
- **Desempenho:** grupo `so_submerso` (302 blocos fundos do relevo, cascos e decoração dos
  naufrágios) escondido com a câmera fora d'água; blocos fundos com alcance 170 m (a névoa
  deixa ~1 % a 110 m); cardumes 80 m; recifes e peixes já escondidos fora d'água.
- **Medido (GPU, 1280×720, v-sync desligado, mesmas posições):**

| ponto | antes (gpu ms) | final (gpu ms) | final quadro ms |
|---|---|---|---|
| porto_superficie | 4,38 | 3,82 | 5,23 |
| plataforma_submersa | 4,61 | 4,99 | 6,00 |
| talude_submerso | 4,12 | 4,67 | 5,85 |
| norte_submerso | 4,59 | 4,96 | 6,00 |
| mar_meio_navegando | 4,57 | 4,08 | 4,27 |
| mar_meio_submerso | 4,37 | 4,03 | 4,42 |
| macacos_submerso | 5,15 | 5,39 | 5,80 |
| recife_denso (novo; sem o Mar 3,93) | — | 5,41 | 6,43 |

  Navegando e no porto ficou MAIS BARATO que antes (−0,5 ms); mergulhando, o mar inteiro
  (recifes, peixes, naufrágios, névoa, cáusticas) custa +0,2 a +0,55 ms sobre a linha de
  base, e +1,48 ms no recife mais denso. Primitivas: 346 mil → 214–260 mil.
- **Teste:** `test_visao_submersa` 0 falhas (grupo só-submerso, costa sempre à vista como
  controle, névoa/cáusticas/neve ligam e desligam, profundidade da câmera, tinta da HUD).
  Fotos: `art_src/validation/mar/medir_final_*.png`, `recifes_e7_*.png`.

## Fechamento (14/10/2026)

**Regressão da frente:** `test_relevo_marinho`, `test_recifes`, `test_naufragios`,
`test_encontros_no_mar`, `test_cardumes`, `test_visao_submersa`, `test_agua`,
`test_ilha_dos_macacos`, `test_lod_das_ilhas`, `test_praia_oceano`, `test_barcos_guardados_mapa`
0 falhas · `test_navios` 42/42 · `test_vendedor_de_barcos` 47/47 · `test_rotina_oceano_bestas`
32/32 · `test_compila` só as 6 conhecidas · `test_modo_historia` 1 falha = LISTA 73 (estilo base,
não é do mar) · `test_comportamento_bestas_mar` 61/64 e `test_ataques_agua_bestas` 39/40 = as
já conhecidas (LISTA, 08/10).

**Pendente de você (não validado por teste):** revisão artística dos corais, cascos, peixes
e da água em tela; playtest do encontro com besta no barco (dificuldade: bote afunda em
~67 s de ataque contínuo; a besta desiste aos 2 min); teclado/mouse físicos; rede (a
campanha é offline).

**Gatilhos declarados:** montagem do relevo > 2 s ou 3ª ilha → montar em thread;
corais sem colisão → esferas nas espécies grandes se pedir apoio; peixes atravessam cascos →
desvio se aparecer em captura; `cel.gdshader` passar a incluir `luz_cel.gdshaderinc` (LISTA
75); `progressao.gd` acima de 900 linhas (LISTA 74).
