# Estruturas do Mine Piece — ilhas por facção, navios e lojas (plano e checkpoint, 18/10/2026)

Pedido do dono: "as estruturas do mine piece e sua adaptação usando o rea: escala: dois blocos
são a altura do jogador + 10%. [...] cada bloco será tanto parte do asset quanto da hitbox, se
tenho dois blocos iguais esses dois blocos são unidos assim eliminando as partes que não são
necessárias [...] trazer também a textura de cada bloco." + "trazer o jogador para a última ilha
feita com a habilidade de pulo no ar e o dash, bem como a fruta da luz equipada e respawn nessa
nova ilha, para testes."

## Decisões do dono (18/10/2026)

- **Ilhas novas por facção:** Base da Marinha 153; Vila Foosha; Vila Shimotsuki; acampamento
  pirata; acampamento bandido; Wano (Heian + Yukaku); Water Seven; Shandora.
- **Posição/teto:** as do East Blue (Marinha, Foosha, Shimotsuki, acampamentos) EM VOLTA da Ilha
  do East Blue, teto 30; Wano, Water Seven e Shandora seguem a leste, teto maior.
- **Navios:** ancorados, sólidos e caminháveis, com tripulação da facção a bordo.
- **Lojas:** prédio do mod (`shop_weapon` / `shop_clothes`) + vendedores que já existem, em TODAS
  as ilhas (as 3 atuais também).
- **Blocos que não são cubo:** forma fiel (escada, laje, cerca, porta, vidro fino...).
- **Teste:** lançador separado, save de teste próprio; fruta **Pika Pika original** (`pika_pika`).

## Fatos verificados

- Fonte: `MinePiece-ver14-forge-1.20.1.jar` aberto com o `rea` (zip, SHA-256 `349b36cd…bd765`,
  igual ao `ORIGEM.sha256` da cópia em `~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14`).
  65 estruturas em `data/minepiece/structures/*.nbt`. O `rea` inventaria o arquivo mas não lê NBT:
  a leitura é do conversor (`tools/mine_piece/nbt.py`).
- Escala: colisor do jogador 1,6 m (`Player.gd`, `COLISOR_BASE`) → 2 blocos = 1,76 m → **1 bloco
  = 0,88 m**.
- Texturas: vanilla no jar local do Minecraft 1.20.1 (`~/Documents/curseforge/minecraft/Install/
  versions/1.20.1/1.20.1.jar`); `minepiece:*` no jar do mod; `vs_eureka:*` em
  `eureka-1201-1.6.3.jar` (local). **Faltam** 10 blocos `kimetsunoyaiba:*` (só Wano): textura
  vanilla substituta, marcada no relatório.
- Nas estruturas do East Blue, 22 % dos blocos não são cubo.

## Decisões técnicas (minhas, declaradas)

| Decisão | Benefício | Alternativa rejeitada | Gatilho de revisão |
|---|---|---|---|
| Formas pelos **modelos de bloco do próprio Minecraft** (blockstates + models JSON: variantes, multipart, herança, elementos) | todas as formas fiéis com um só renderizador, sem tabela à mão | código por tipo de bloco (centenas de casos) | bloco que sai errado na captura → caso especial |
| Faces escondidas entre blocos opacos somem; faces vizinhas de mesma textura e direção viram **um retângulo** (greedy) com textura repetida | menos triângulos, "blocos iguais unidos" | atlas sem união (repetição não funciona em atlas) | draw calls de uma ilha > 2.000 medidos → array de texturas num só material |
| Hitbox = malha `Colisao` dentro do `.glb` (casca externa dos sólidos unidos em caixas) | caminho que o catálogo já tem; uma forma por estrutura | milhares de `BoxShape3D` (nós demais); V-HACD (máx. 64 partes, fecha portas) | jogador prendendo em quina → caixas convexas |
| Sem hitbox: flores, tochas, placas, botões, tapetes finos < 1/16, trilhos, faixas | anda-se como no Minecraft | — | — |
| Arte FORA do git (`build/mine_piece/estruturas/`, `mapas/modelos/mpe_*`) | regra da arte provisória do Mine Piece | — | antes de lançar: trocar pela arte própria |
| Ignorados: ar, vazio de estrutura, barreira, jigsaw, bloco de estrutura, água, spawner | o jogo tem água e spawn próprios | — | — |

## Etapas

| # | Entrega | Validação |
|---|---|---|
| E0 | Lançador de teste `jogar_teste_ilha.sh`: última ilha do cadastro, pulo no ar + dash, `pika_pika`, renasce lá; save de teste | teste headless: posição, capacidades, fruta, ponto de renascer |
| E1 | Conversor `tools/mine_piece/estrutura_para_glb.py` (NBT → `.glb` com textura + `Colisao`) | testes de unidade (união, faces escondidas, escada/laje/cerca); capturas lado a lado |
| E2 | Registro na loja (categoria `mine_piece_estruturas`) | catálogo carrega; colisão = malha própria |
| E3 | Gerador das 8 ilhas + posições + teto | teste: ilhas no cadastro, peças nas placas |
| E4 | Navios ancorados + tripulação da facção | teste: corpo de pé no convés; tripulação nasce |
| E5 | Lojas + vendedores em todas as ilhas | teste: tecla E abre a loja em cada ilha |
| E6 | Medição de desempenho (quadro com ilha à vista) + capturas por ilha | números antes/depois |

## Checkpoint

- **18/10 ~11:00:** levantamento feito, decisões tomadas. Próximo: E0 + E1.
- **18/10 ~11:10:** E0 ✅ `test_teste_de_ilha` 10/10 (nasce/renasce no East Blue, dash, pulo no ar,
  `pika_pika`, save real intocado). E1 ✅ 65 estruturas em 1 min (`build/mine_piece/estruturas/
  relatorio.json`); capturas `art_src/validation/estruturas_mine_piece/`. Medido: cerca era 73 % das faces
  do Baratie → faces cobertas somem + tiras coplanares (UV presa ao mundo, `uvlock`) + colisão de cerca/
  muro/portão como no Minecraft: Baratie 427k→211k tri de desenho, 477k→71k de colisão. E2 ✅ 61 na loja
  (`registrar_estruturas.gd`); catálogo ganhou `triangulos_colisao` (opcional). Próximo: E3 (ilhas).
- **18/10 ~11:40:** E3–E5 ✅ `gerar_ilhas_mine_piece.gd` (+ `ilha_procedural.gd`) gravou 483 peças no mapa
  vivo (cópia `art_src/backups/mapa_historia/baseplate_antes_ilhas_mine_piece_e91be39bdd4c.json`): 8 ilhas,
  12 navios, 22 tripulantes, 22 personagens em terra, 22 lojas com 33 vendedores (3 ilhas antigas por busca de
  lugar livre e plano). `test_ilhas_mine_piece` 31/31; capturas `art_src/validation/ilhas_mine_piece/`.
  Regressão: test_ilha_east_blue 7/7 (premissa ajustada: contava os `mp_*` de todas as ilhas),
  dos_macacos 29/0, lod 16/0, cadeia_do_guarda 46/0, npcs_e_lojas 54/0, terreno_mapa 56/0,
  east_blue_personagens 11/0, mine_piece 22/0, teste_de_ilha 10/10; test_ilha_inicial 2 falhas
  (pés na encosta) PRÉ-EXISTENTES — iguais com o mapa de antes.
- **E6 (medido, `medir_ilhas_mine_piece.gd`, vsync off, RTX 3050 6 GB):**

  | | antes | agora |
  |---|---|---|
  | abrir o Modo História | 12,9 s | 28,0 s |
  | memória estática | 681 MB | 1.229 MB |
  | memória de vídeo | 1.090 MB | 1.261 MB |
  | quadro no spawn da Ilha Inicial | 15,1 ms | 15,7–17,0 ms |
  | quadro na chegada do East Blue | 16,3 ms · 1.587 desenhos | 20,2–20,6 ms · 2.744 desenhos |

  Decomposição (variantes do mapa): fundo do mar ~7 s (é UMA grade sobre o retângulo de todas as
  placas + 600 m: 8 → 30 km²), estruturas ~2 s, relevo novo ~1 s, resto ~5 s (personagens,
  vendedores, substitutos de longe). Importar os `.glb` no Godot não mudou nada (medido).
  Sem as placas novas o desenho por distância não cuida das ilhas e o East Blue vai a 45 ms.

## Ilhas espalhadas e relevo adaptado (22/10/2026)

Pedido do dono: "espalhar as árvores e construções pelas demais ilhas no modo história, fazer o
relevo se adaptar a estas construções". Escolhas dele: **só as 8 ilhas do Mine Piece**; **as mesmas
construções, redistribuídas** (nada novo); **platô suave com o relevo baixo de antes**; **árvores por
bioma** (Wano cerejeira/pinheiro, Shandora e acampamentos palmeira, Foosha/Shimotsuki floresta
temperada, Marinha parque, Water Seven poucas árvores de cidade).

| Decisão (minha) | Benefício | Alternativa rejeitada | Gatilho de revisão |
|---|---|---|---|
| Lugar por "melhor candidato" com a semente da ilha (24 lugares válidos, fica o mais longe dos ocupados); giro em múltiplos de 90°; fora das encostas (desnível natural ≤ 3 m) | espalha pela ilha inteira, reproduzível, sem posição à mão | grade fixa (o de antes); física do `plantar_natureza.gd` (montar o mapa inteiro) | dono pedir bairros agrupados por vila → agrupar por família de molde |
| Platô RETANGULAR girado na pegada, altura = média do relevo sob ela, talude de 5 m; terra só sob o platô e nas trilhas | prédio rente ao chão sem os círculos marrons | círculo (praça) — sobrava chão plano e terra | — |
| Trilhas = árvore geradora mínima (chegada a oeste, praça, construções); ruas do molde (≥ 3× mais compridas que largas) deitadas no meio das trilhas mais longas | ruas com função, não soltas | rua como construção qualquer | — |
| Árvores no gerador, no relevo em memória: bosques por ruído (`clareira`), distância mínima, base com desnível ≤ 1 m, fora de trilhas, praça, platôs e areia | sem montar o mapa; idempotente (prefixo `mpi_`) | — | — |

Validação: `test_ilhas_mine_piece` **47/47** (16 novas: chão sob cada pegada a ≤ 0,16 m do piso do
molde; 872 árvores no chão e fora das construções). Regressão: `test_ilha_east_blue` ✅,
`test_teste_de_ilha` 10/10, `test_terreno_mapa` 0 falhas, `test_lod_das_ilhas` 0 falhas;
`test_npcs_e_lojas` falha PRÉ-EXISTENTE (o script não compila no `--script`: `GameFlow`/`FruitNet`;
aba `npc_comida`). Capturas antes/depois: `art_src/validation/ilhas_espalhadas/{antes,depois}/`.
Cópia do mapa: `art_src/backups/mapa_historia/baseplate_antes_ilhas_mine_piece_5cf2d9ac39a1.json`.

Custo medido (`medir_ilhas_mine_piece.gd`, mesmo dia, mesmos pontos, antes → agora): Wano do chão
15,8 → 16,9 ms; Foosha do chão 14,8 → 15,7 ms; Wano do alto 15,1 → 16,4 ms; Shandora 14,1 → 14,9 ms;
Inicial/East Blue iguais; vídeo +22 MB, memória +35 MB. Os absolutos deste dia estão piores que os de
18/10 nos DOIS mapas (East Blue 63 ms contra 20 ms) — ambiente mais lento, causa não investigada.
Gatilho: quadro de uma ilha nova > 20 ms medido em máquina sem carga → árvores iguais em MultiMesh
(o `MapaMontador` já anota essa saída).

## Pendências e gatilhos

- **Desempenho (decisão do dono pendente):** fundo do mar só perto das ilhas (em vez do retângulo);
  material único por estrutura (array de texturas — gatilho declarado: >2.000 desenhos, MEDIDO 2.744
  no East Blue); aproximar as ilhas da Grand Line. O `LodDasIlhas` tem o gatilho "4+ ilhas → descarregar
  de verdade"; agora são 11.
- **Não jogado à mão:** validação por testes headless e capturas.
- **Wano/Water Seven/Shandora sem inimigos próprios:** o mod só teve o East Blue extraído. Gatilho:
  extrair os personagens da Grand Line. Tripulações da Grand Line usam piratas do East Blue (fracos para teto 40–60).
- **Kimetsu (Wano):** 10 blocos com textura vanilla substituta (`SUBSTITUTOS` no conversor).
- **Blocos de entidade aproximados** (baú, placa, estandarte, cama, cabeça, sino, vaso): caixas.
- **Água das estruturas removida** (canais de Water Seven ficam secos; campo de Shimotsuki sem água).
- **Red Force, Going Merry, Baratie, Thousand Sunny, barco do Mihawk sem tripulação** (a tripulação
  nomeada já está em terra no East Blue ou não existe no mod extraído).
- **Arte provisória:** `.glb` `mpe_*` fora do git; recalibrar antes de lançar.
- **Dívida:** migrar `gerar_ilha_east_blue.gd`/`gerar_ilha_dos_macacos.gd` para `IlhaProcedural` na próxima
  mudança deles (conferir mapa idêntico).

## Como refazer

```bash
python3 -I tools/mine_piece/estrutura_para_glb.py              # 65 .glb + relatorio.json (~1 min)
G="$(./find_godot.sh)"
$G --headless --path . --script tools/mine_piece/registrar_estruturas.gd [-- --forcar]
$G --headless --path . --script tools/mapa_ilha/gerar_ilhas_mine_piece.gd
$G --headless --path . --import
$G --headless --path . --script tools/dev_tests/test_ilhas_mine_piece.gd
./jogar_teste_ilha.sh [--ilha=<id>] [--nivel=<n>]
```
