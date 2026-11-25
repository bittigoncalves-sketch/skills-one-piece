# Ilha dos Macacos, missões do Guarda, bússola e desenho por distância — plano (08/10/2026)

Pedido do dono: "adicionar mais uma ilha, a ilha dos macacos, está ilha ficará afastada
da ilha atual e será repleta de arvores gigantes. para chegar a esta ilha o jogador pode
navegar pelo mar ou então completar todas as missões do guarda da vila que cede as
missões o que facilita a busca".

## Decisões

**Respondidas pelo dono:**
- **Distância:** ~1,5 km, de 3 a 5 min de barco.
- **O que "facilita a busca":** uma BÚSSOLA que aponta para a ilha, recompensa por
  completar todas as missões do Guarda.
- **Missões novas do Guarda:** conseguir um pet, conseguir uma Akuma no Mi, vencer a
  corrida dos caranguejos e pescar 10 peixes.
- **Árvores gigantes:** ficam para depois.
- **Desenho por distância:** saindo de uma ilha e se afastando, ela passa a ser
  desenhada no mínimo (animais deixam de aparecer, construções viram blocos e assim por
  diante). Quando não dá mais para ver a ilha, ela deixa de ser desenhada.

**Minhas, declaradas (o dono pode trocar):**
- **Posição:** a ilha fica a LESTE, depois do porto, com centro em (1500, 0). O porto fica
  em x ≈ 300, então a travessia é de ~1,2 km.
- **Forma:** placa de 256 × 256 m (metade da inicial) mais o anel de praia; relevo em
  blocos de 64 m como a ilha inicial; morros no meio, até ~22 m.
- **Chão e acesso:** grama, chão de mata nas partes que vão receber as árvores gigantes
  depois, areia na costa, uma trilha de terra do píer até o centro, e o píer a oeste
  (virado para a ilha inicial).
- **Habitantes:** 4 bandos de macacos (o macaco da loja, territorial).
- **Teto de nível:** 20 na Ilha dos Macacos. O teto que vale é o da ilha mais avançada já
  visitada (salvo no progresso).
- **Missões:** em CADEIA, uma por vez, nesta ordem: bandidos → pet → Akuma no Mi →
  corrida → 10 peixes.
  - Só conta o que acontece DEPOIS de aceitar: o pet novo, a fruta comprada, a corrida
    vencida e o peixe pescado.
  - Recompensas: pet 150 XP + 20; fruta 200 XP + 30; corrida 250 XP + 40; peixes 200 XP +
    30, mais a bússola.
- **Bússola:** no canto da tela, abaixo das barras de vida e energia. Uma agulha aponta
  para a ilha, girando com a câmera, com a distância escrita ao lado. Some quando o
  jogador está na Ilha dos Macacos.
- **Desenho por distância, por ilha:**
  - PERTO (até 250 m da borda; **400 m depois da foto**, ver etapa 4): tudo.
  - LONGE (até 1,9 km): animais, NPCs, inimigos e objetos pequenos somem e param de
    processar; construções viram BLOCOS (uma caixa na cor da construção); árvores viram
    formas simples; o relevo fica.
  - OCULTA (além de 1,9 km): nada da ilha é desenhado.
  - Por que 1,9 km: a névoa exponencial (densidade 0,002) cobre ~98 % da cor a essa
    distância, então a ilha já não se vê.

## Etapas (cada uma com validação)

1. **Ilha:** a ferramenta `tools/mapa_ilha/gerar_ilha_dos_macacos.gd`. É idempotente,
   troca só as peças `macacos_*`, guarda cópia antes e não grava se o mapa mudar durante
   a execução. Validar com teste (placa, relevo, praia, mar entre as ilhas, píer,
   macacos) e foto do mar.
2. **Ilhas no jogo:** cadastro das ilhas, em qual ilha o jogador está, teto por ilha,
   aviso "Você chegou à Ilha dos Macacos" e save. Validar com teste.
3. **Missões em cadeia:** os 4 tipos de evento, a "?" que segue a missão atual, a bússola
   na última e a bússola na tela. Validar com teste e foto.
4. **Desenho por distância:** validar com teste de estados e medição do custo (objetos e
   chamadas de desenho) perto, longe e no mar, mais fotos.
5. Bateria vizinha, documentação e memória.

## Estado

1. **Ilha: feita (08/10/2026).**
   - **No mapa vivo:** 42 peças novas, gravadas por `tools/mapa_ilha/gerar_ilha_dos_macacos.gd`, com cópia
     `art_src/backups/mapa_historia/baseplate_antes_macacos_ed3d2ea0237c.json`. As 1251 peças que já existiam ficaram
     idênticas (conferido), e uma 2ª execução gerou o mesmo arquivo, byte a byte.
   - **A ilha:** o morro mais alto tem 23,1 m. O chão é 57 % mata (onde as árvores gigantes vão entrar), com trilha e
     clareira de terra e areia na costa. O píer fica a oeste, na altura do píer do porto. São 4 bandos, com 12 macacos.
   - **Fundo do mar:** agora há um por ilha (`FundoDoMar.montar_por_ilha`). Cada um avança até a metade do caminho
     (558 m), e os dois se encontram em x = 814 a −30 m, sem sobrepor. Para isso o passo da grade foi ajustado; com o
     passo cheio, sobrava uma faixa de 4 m.
   - **Validação:** `test_ilha_dos_macacos` deu 0 falhas, conferindo o arquivo, as emendas, o mar e o jogo de verdade
     (de pé na clareira, nadando no meio do caminho, 12 macacos nascidos). Fotos em
     `art_src/validation/ilha_dos_macacos/` (`capturar_ilha_dos_macacos.gd`).
   - **Testes vizinhos:** `test_agua` 0 falhas e `test_rotina_oceano_bestas` 32/32. O `test_ilha_inicial` tem as 2
     falhas antigas de pé na encosta, com os mesmos números (0,092 m); com o mapa de antes da ilha elas se repetem.
   - **Achados fora do escopo, na LISTA:** item 70 (o píer `dock_long` aparece sem tábuas, no porto também) e item 71
     (aviso do `frutas.json` lido como skill).
   - Os riscos pretos nas cristas dos morros, nas fotos, são o `Contorno` do estilo (pós-processo do WorldEnv). Não
     são fresta: continuam com a sombra desligada.
2. **Ilhas no jogo: feita (08/10/2026).**
   - **Cadastro único:** `src/historia/ilhas/ilhas.gd`, com nome, baseplate e teto (inicial 10, macacos 20). A forma de
     cada ilha sai do mapa: baseplates que se tocam formam uma ilha.
   - **Detector:** `DetectorDeIlha`, a cada 0,5 s, marca `progressao.ilha` ("" no mar). A 1ª pisada põe a ilha nas
     `ilhas_visitadas`, que vão para o save, e o teto passa a ser o da ilha mais avançada já visitada, com o XP guardado
     subindo na hora. O aviso diz "Você chegou à Ilha dos Macacos · nível máximo agora: 20"; nas chegadas seguintes, só
     o nome. A ilha onde se nasce não avisa.
   - **Save editado** com ilha fora do cadastro: o nível volta ao teto.
   - **Validação:** `test_progressao` TUDO OK; `test_ilha_dos_macacos` 0 falhas (nasce na inicial com teto 10, pisa na
     ilha, aviso, save, volta e chega de novo, mar = nenhuma ilha).
3. **Missões em cadeia e bússola: feita (08/10/2026).**
   - **Cadeia do Guarda:** bandidos → pet → Akuma no Mi → corrida → 10 peixes (`Missoes.TABELA`, `depois_de`), uma
     por vez. A "?", o contador e a janela seguem a missão da vez. Os eventos são contados na progressão:
     - **pet:** pet novo, domado, comprado ou dado pelo mapa;
     - **fruta:** fruta comprada ou comida;
     - **peixe:** só peixe da `TabelaDePeixes`;
     - **corrida:** 1º lugar com a corrida completada (o prêmio de moedas da corrida continua sendo completar em até
       5:00).
   - **Bússola:** é o prêmio da última missão (`desbloqueios["bussola"]`). Fica abaixo das barras de vida e energia;
     a agulha gira com a câmera, e ao lado aparecem o nome e a distância até a costa. Some na ilha e com menu aberto.
   - **F8:** "Bússola liga/desliga" e "Ir à Ilha dos Macacos" (põe o jogador no píer de lá).
   - **Corrigido no caminho:** a fala no alto da janela de loja só era lida ao abrir. Com a cadeia, depois de entregar,
     a linha mostrava a missão nova e a fala ainda era a antiga (foto). Agora ela é relida a cada atualização.
   - **Validação:** `test_cadeia_do_guarda` 38/38 e `test_bandidos_e_missao` 25/25 (ajustado: depois de entregar, a
     "?" segue amarela com a próxima missão). Fotos `bussola_na_tela.png` e `cadeia_pet_na_tela.png`.

4. **Desenho por distância: feito (08/10/2026).**
   - **Sistema:** `src/historia/ilhas/lod_das_ilhas.gd`, com estado por ilha pela distância da câmera até a placa
     e folga de 15 m contra pisca.
     - **PERTO, até 400 m:** tudo. Com 250 m a troca aparecia: a vila, ainda nítida a ~350 m, virava caixas.
     - **LONGE, até 1,9 km:** ficam relevo, placa, penhascos e fundo do mar. As construções (61) viram blocos na cor
       média do modelo, e as árvores (653) viram copas, em 2 MultiMesh por ilha. Somem os miúdos (384, inclusive o
       cais) e as entidades (5 NPCs e 6 ninhos de bandido), que também param de processar.
     - **OCULTA:** nada da ilha, nem o fundo do mar dela.
   - **Ao voltar:** cada entidade volta exatamente como estava (um inimigo morto esperando renascer segue escondido).
   - **De fora:** os animais já somem além de 80 m (`PopulacaoDeAnimais`). Os barcos andam entre ilhas e não entram.
   - **Cor do bloco:** média das cores lisas do modelo. Parte com textura usa a cor da categoria (copa ou pedra),
     porque a paleta "Atlas" dava branco e a leitura nos UVs dava bege nas pedras e preto nas folhas.
   - **Medido com GPU** (`medir_lod_das_ilhas.gd`, mesmas condições, v-sync desligado):

     | ponto | objetos | chamadas | quadro |
     |---|---|---|---|
     | meio do mar olhando a inicial | 4.702 → 802 | 2.592 → 650 | 8,96 → 6,98 ms |
     | Ilha dos Macacos olhando a inicial | 4.426 → 954 | 2.232 → 714 | 9,39 → 7,30 ms |
     | vila (PERTO) | 8.100 → 8.086 | 4.307 → 4.293 | sem mudança |

     A GPU segue em ~6–7 ms em todos os pontos (oceano, céu e contorno em tela cheia). A troca custa até 4 ms na
     chamada, e o quadro seguinte fica normal.
   - **Fotos:** `lod_antes_*` e `lod_depois_*`, mais a fronteira a 384 m e 424 m.
   - **Validação:** `test_lod_das_ilhas` 0 falhas (regra, vila, meio do mar, 2,3 km e volta).
   - **O que NÃO faz:** tirar da memória ou da física. Gatilho: memória medida acima do orçamento, ou 4+ ilhas.

5. **Bateria vizinha, documentação e memória: feitas (08/10/2026).**
   - 27 testes rodados pela cópia na memória do `validar.sh`: 25 passaram e 3 falharam.
   - `test_animais` era meu: contava os bichos do mapa inteiro contra o "~70" pedido para a Ilha Inicial, e com os
     12 macacos deu 83. Agora conta só os da inicial (71) e dá 0 falhas.
   - As outras duas são as conhecidas, com os mesmos números: `test_compila` (os 6 do studio) e `test_ilha_inicial`
     (pé na encosta 0,092 m e corrida +0,073 m; repetem com o mapa de antes da ilha).
   - Erros registrados em `docs/erros.md` (302–305). Novos itens da LISTA: 70, 71 e 72.

**Decisão do dono pendente (gatilho disparado):** a curva de XP acima do nível 10 (500 mil + 25 mil por nível) e o
título "Ápice" do 11 em diante tinham o gatilho "quando existir a 2ª ilha". Com o teto 20, do 10 ao 20 são ~6,4
milhões de XP; um macaco dá 12 e um bandido, 25 a 75. A curva e os títulos seguem como estão até o dono decidir.


---
## Etapa 6 — floresta gigante, macacos humanoides e Geppo (18/11/2026, pedido do dono)

Pedido: "uma grande floresta com árvores imensas, macacos humanoides e movimentação aérea com dash aéreo sem recarga e jumps no ar, técnica Geppo". Isto fecha o item "árvores gigantes: ficam para depois" da etapa 1.

- **Floresta** (`tools/mapa_ilha/gerar_floresta_macacos.gd`, idempotente, prefixo `macacos_floresta_`, cópia do mapa antes): 44 árvores imensas da loja (`floresta_tree_*`
  em escala 7–10× do tamanho padrão: copas de 40–80 m, 50–130 m de altura), 150 médias, 170 de sub-bosque (arbustos, cogumelos gigantes, pedras, troncos). Só em solo de mata,
  fora de trilha, clareira, praia e barranco. A placa continua 256 × 256 m — **GATILHO:** ampliar a placa se o dono quiser mais floresta (muda píer, bandos, fundo do mar e LOD).
- **Macacos humanoides:** `mp_macaco_humanoide` (16, 4 bandos) e o **Macaco-rei** (`mp_macaco_rei`, chefe, 180 de vida; solta baú de chefe). Corpo biped de origem do mod
  (`tools/mine_piece/criar_macaco_humanoide.py`, local/fora do git) com a PELE própria pixel-art (`tools/mine_piece/gerar_skin_macaco.py` → `assets/textures/macacos/`) aplicada por
  `UniformesFaccoes`; sem arma (o sabre embutido é escondido); fichas `original: true` em `mapas/east_blue/personagens.json`. Faltam: cauda e animações próprias de macaco.
- **Geppo:** `ProgressaoDoPersonagem.aprender_geppo` (5 pulos no ar por voo, dash no ar sem recarga e sem energia, pulo sem energia; `CapacidadesDoJogador.geppo/saltos_no_ar`),
  ensinado pelo **Mestre do Geppo** (`npc_mestre_geppo`, `loja_do_mestre_geppo.gd`, na clareira central) por 2000 moedas. Decisões minhas a confirmar: 5 pulos, 2000 moedas, sem custo de energia.
- **Testes:** `test_floresta_macacos` 11/11, `test_geppo` 20/20, `test_ilha_dos_macacos`, `test_lod_das_ilhas`, `test_npcs_e_lojas` 23/23. Capturas: `capturar_ilha_dos_macacos.gd` (vistas 11–13).
- **Limites:** sob as copas a ilha fica escura (sombra das árvores) e os macacos leem escuros nessa sombra; nada medido de desempenho da floresta nova (~380 peças a mais).

### Etapa 6b — plataformas do Geppo e baú do topo (18/11/2026)
8 plataformas de madeira em espiral (raio ~7,5 m, 3,4 m de degrau, de ~5 m a ~28 m) em volta da árvore imensa mais perto da clareira, a última maior, com o **baú fixo do topo**
(`BausDeChefe.garantir_fixo`, uma vez por personagem, força de chefe forte). Testado só por geometria (`test_floresta_macacos` 14/14): a subida de fato com o Geppo
(5 pulos no ar por voo) NÃO foi jogada nem medida. Sob a copa a visão é escura (captura `plat_longe`, câmera dentro da folhagem).

### Etapa 6c — cauda, legibilidade e desempenho (18/11/2026)
- **Cauda** (`src/historia/east_blue/cauda_de_macaco.gd`): 6 cubos presos às costas do `torso` do biped (o modelo é hierarquia de nós, sem esqueleto), curvando para cima e balançando; só visual. Animações próprias de macaco (trepar, pular de árvore) continuam faltando.
- **Legibilidade:** sob as copas o macaco lia cinza-azulado; a pele ganhou emissão própria (×0,5 da mesma textura) e voltou a ler marrom (captura conferida).
- **Desempenho** medido em jogo na Ilha dos Macacos: ~50 FPS (20 ms/quadro, 18,5 mil nós, ~1.080 draw calls) com a floresta; ver também `docs/DECORACAO_DAS_ILHAS.md`.

### Etapa 6d — subida validada e comportamento (18/11/2026)
- **Plataformas do Geppo VALIDADAS jogando:** `test_geppo_plataformas` usa um robô de teclado (W + Espaço, física real do jogador): com o Geppo sobe as 8 plataformas (de y 5 a ~29 m); sem o Geppo não passa da 1ª (`-- --sem-geppo`).
- **Macacos saltam:** o `mpeb_ataque_salto` do mod é só uma animação de golpe por cima (clipe `head_overhead`), não um pulo; por isso os macacos ganharam um SALTO DE PERSEGUIÇÃO próprio
  (`PersonagemMinePiece._salto_de_perseguicao`, ficha `"salta": true`): perseguindo de 5 a 13 m, no chão, o macaco dá um pulo longo em cima do alvo (impulso 14 m/s + 9 m/s vertical), recarga de 4,5 s.
  `test_macaco_salta` 9/9 testa a DECISÃO (faixa, recarga, alvo morto). **Não observei o salto numa perseguição real:** no teste em jogo o macaco acabava colado ao jogador antes de a faixa valer
  (coleira de casa e velocidade do mod) — ver o salto em campo aberto na ilha é pendência. Trepar em árvores continua não feito.
- Reimportei as texturas dos macacos (os sabres embutidos geravam 321 px; `voxelizar_texturas.py` os reduz): `test_texturas_voxel` 284/0.

### Etapa 6e — bateria completa (19/11/2026)
`validar.sh rapido`: 278 ok, 96 falhas, 1 pulada. Única falha causada por esta meta: `test_streaming_de_ilhas`
(esperava < 100 peças na Ilha dos Macacos; agora 438 pela floresta) — corrigida, 19/19.
As demais (água, animais, barras de chefe, rede do Builder/Pika/Hie, timeouts de 120 s etc.) não tocam arquivos
alterados aqui; `test_animais` oscila entre execuções (8→11 falhas) sem relação com a floresta.
Sem linha de base limpa (árvore de trabalho muito suja), a comparação é por inspeção, não por medição.
Gatilho: ao criar um commit limpo dessa meta, rodar a bateria no commit anterior para separar regressão de falha antiga.
