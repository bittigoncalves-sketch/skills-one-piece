# Ilha Inicial — relevo em blocos, rio, vila, floresta e porto

Estado em 01/10/2026. Pedido do dono: refazer o mapa do Modo História com os assets da
loja — relevo acima da baseplate, tudo o que estava em cima retirado e recolocado no
relevo no tamanho certo, um **rio em S cortando a ilha ao meio**, **floresta**, **vila**,
**porto** e o **coliseu** (futuro palco das invocações de pets e das lutas com chefes).
Decisões e andamento: `docs/MAPA_ILHA_CHECKPOINT.md`. Planta aprovada:
`art_src/validation/mapa_ilha/esboco_planta.png`.

## O que tem na ilha

| grupo (Explorer) | o que é |
|---|---|
| `relevo` | 64 blocos de terreno de 64 × 64 m (8 × 8), células de 2 m |
| `praia` | 36 blocos de areia em anel em volta da baseplate, descendo até abaixo do mar |
| `pontes` | 2 pontes de madeira (modelo novo), uma em cada cruzamento estrada × rio |
| `vila` | praça com chafariz, mercado, estalagem, ferreiro, capela, casas e periferia |
| `fazendas` | sítios, plantações, moinhos e feno ao norte da vila |
| `porto` | armazéns, três píeres saindo da praia para o mar, barris e caixotes |
| `navios` | galeão, chalupa, dois barcos-casa e botes atracados |
| `floresta` | metade oeste: pinheiros e árvores, morros com penhascos, serraria |
| `campos` / `coqueiros` | árvores soltas a leste; coqueiros na faixa de areia da ilha toda |
| `coliseu` | clareira plana no sudoeste |

O jogador nasce na praça da vila. Cada grupo seleciona e move junto (Ctrl+G separa um
nível); clique com Alt pega uma peça só. O mapa atual tem **1240 peças** após a
substituição da floresta em 08/10/2026: 123 aglomerados antigos deram lugar a
451 árvores individuais e 225 arbustos e plantas rasteiras, usando 19 modelos da
loja. Caminhos, relevo, água, construções e todas as peças fora da substituição
foram preservados. As árvores usam a colisão de tronco do GLB; plantas atravessáveis
seguem a configuração do catálogo.

A ferramenta pontual `tools/mapa_ilha/refazer_floresta.gd` recebe mapa de entrada
e de saída. Não executar o gerador da ilha inteira para atualizar apenas a mata.
Validação, capturas e backup: [checkpoint da floresta](FLORESTA_LOJA_CHECKPOINT.md).

## A peça `terreno` (nova)

Um bloco de relevo é uma peça comum do mapa — move, gira, estica, duplica, apaga e
desfaz como as outras —, com o campo `relevo` (formato completo em
`src/world/terreno_do_mapa.gd`):

- **alturas** em 1/10000 do tamanho Y da peça: esticar o bloco no gizmo estica o relevo;
- **solo** por célula: automático (rocha no íngreme, areia no baixo, grama no resto) ou
  pintado (terra das estradas, chão de mata, areia das margens, leito do rio);
- **água** por ponto (opcional): o rio. Superfície com shader próprio
  (`src/world/agua_rio.gdshader`): correnteza para o sul, cor pela profundidade real,
  espuma na beira. A água é visual — o jogador anda no leito.

A colisão e o clique do editor usam a malha do relevo: pisa-se na face que se vê, e uma
casa pousada no bloco continua clicável. Peça arrastada da loja pousa no relevo.

⚠️ **Emendas:** todos os blocos da ilha têm a mesma base (−1,5 m) e o mesmo tamanho Y.
Esticar UM bloco no eixo Y pelo gizmo desalinha a borda dele com os vizinhos (abre
degrau) — para mexer na altura, use o **pincel de relevo**.

## Pincel de relevo (editor, Ctrl+5)

Ferramenta **Relevo** na barra (ou Ctrl+5). Painel embaixo: modo, solo, raio e força.
- **Elevar**: segurar o botão esquerdo ergue o chão; **Shift** afunda. Queda suave na
  borda do pincel; não desce abaixo da base dos blocos.
- **Aplainar**: nivela na altura do ponto onde a pincelada começou (terreno de obra,
  estrada, platô).
- **Pintar solo**: grama, terra, areia, rocha, mata, leito ou automático.
- **[ e ]** mudam o raio (1 a 60 m). **ESC** no meio cancela a pincelada.
- Uma pincelada (apertar → soltar) = **um passo de desfazer** (Ctrl+Z).
- As **emendas continuam exatas** entre blocos (a altura nova de um ponto só depende da
  posição no mundo e da altura antiga — igual nos dois blocos que o dividem).
- Passar do topo da caixa faz **todos os blocos crescerem juntos** (uma travadinha de
  ~0,3 s, uma vez).
- **Peças pousadas** na área do pincel (casas, árvores, pedras, o spawn) sobem e descem
  com o chão, no mesmo passo de desfazer.
- Custo medido na ilha: ~7 ms por quadro com raio 8 m, ~16 ms com raio 30 m num canto
  de 4 blocos.
- Não mexe na água do rio (o nível da água é do bloco, não do pincel).

## Pontes e a malha `Colisao`

O colisor do jogador é uma **caixa** (`Player.COLISOR_BASE`, fundo reto) e não sobe
degrau nenhum. Por isso a ponte tem:
- topo do deck liso (as tábuas são só cor) e a terra das cabeceiras 3 cm **acima** da
  ponta do deck — o deck emerge do chão sem face exposta;
- uma malha de colisão própria: o objeto **`Colisao`** dentro do .glb (piso liso + duas
  paredes no lugar do guarda-corpo). Regra geral da loja: se um .glb tem malha cujo nome
  começa com `Colisao`, SÓ ela é a colisão do modelo, e ela não aparece. Sem isso a
  colisão era a malha visual inteira, e as travessas rentes ao piso prendiam o jogador
  (ver `docs/erros.md`, 01/10/2026). Vale para qualquer modelo novo onde se anda por cima.

## Hitboxes (01/10/2026)

**Jogador (só no Modo História): cápsula** de 1,6 m × raio 0,5 no lugar da caixa
(`Player.colisor_capsula`, ligado em `ModoHistoria.colocar_civil`; o boneco de duelo
também). A caixa apoiava numa quina em encosta e os pés flutuavam até 27 cm a 21°; com a
cápsula ficam a poucos centímetros, e ela vence beirada de até ~15 cm. Raio 0,5 = meia
largura da caixa: dois lutadores param à mesma distância de antes (com 0,4 a troca
simultânea de jabs deixava de existir). A arena continua com a caixa.

**Pés ANDANDO (01/10/2026):** a animação de marcha fazia o corpo pairar ~14 cm acima
do chão ao andar e correr — parado sempre encostou, então nenhuma medição parada pegava.
Era o `ProceduralAnimator` medindo o pé de apoio contra a altura agachada da marcha; agora
mede contra a pose de repouso e o quadril desce o que a marcha agacha (pé a +2 cm andando,
0 cm correndo). Vale para a arena também (mesmo animador).

**Hurtbox de combate** (`HurtboxDeCombate`): o golpe acerta uma CAIXA 1 × 1,6 × 1 presa
ao corpo, numa camada de física só dela (21), e não a cápsula — todos os golpes foram
afinados contra a caixa. Ela é levada ao servidor de física logo depois do corpo andar
(um corpo filho fica um quadro atrás, o bastante para desempatar uma troca de golpes).

**Construções: partes convexas.** 97 modelos de construção (casas, torres, templos,
mercado, fazendas, prédios do porto, muralhas) colidem com até 12 volumes convexos que
envolvem a estrutura, gerados da própria malha (cobertura 99,3–100 %). O jogador para
rente à parede (~0,5 m do centro dele) em vez de empacar em base ou varanda baixa.
- Os pontos ficam em `mapas/modelos/<id>.colisao.json`, com o SHA do .glb: se o modelo
  for reimportado com outro conteúdo, a colisão volta a ser a malha (aviso no log) até
  rodar `tools/mapa_ilha/gerar_colisao_de_construcoes.gd` de novo (ou `-- <id>` para um).
- No editor, a tecla **H** (ou a seleção) desenha essas partes em verde.
- Hitbox própria da peça (painel de propriedades) continua mandando sobre as partes.
- Fora: plantações e campos (são chão), píeres (piso), coliseu (é para entrar),
  a ponte (tem `Colisao` própria) e os navios.

## Tamanho padrão da loja

A maioria dos modelos chegava minúscula (casa de 1,5 m para um personagem de 1,6 m).
Agora 158 modelos têm **tamanho padrão** no catálogo, e é nele que entram ao serem
arrastados da loja (o ↺ do painel volta a ele). A tabela, por tipo e medida contra o
jogador, é `tools/mapa_ilha/aplicar_tamanhos_padrao.gd`:

- kit medieval "first/second age" ×8 (cabana 6 m, casas 5–10 m, torre de vigia 12 m);
- kit "fantasy" ×2,6 (estalagem 9 m, ferreiro 8 m, moinho 12,5 m);
- templos altos ×6 (até 26 m); objetos soltos por altura (barril 1 m, carroça 2 m);
- natureza: pinheiros 13 m, árvores 11 m, coqueiros 7,5–8,5 m;
- navios pelo comprimento da ficha.

Modelo importado novo não tem padrão: entra no tamanho do arquivo, como antes.

## Navios

Categoria **navios** na loja com `boat`, `small_ship`, `ship` e os três barcos-casa
(`house-g7esjlfi4v`, `house-2kytqgs4rh`, `house`). Cada um tem uma **ficha** no catálogo
(`src/world/ficha_de_navio.gd`) — classe, comprimento, velocidade, curva, vida,
tripulação, carga e canhões —, com valores de partida por classe (bote, chalupa,
barco-casa, galeão). A dica da loja mostra a ficha. Ainda não há navegação: nada no jogo
lê esses números. O `house` parece estar de pé no arquivo (pela miniatura, o casco
aponta para cima) e por isso não foi posto no porto — conferir antes de usar.

## Animais (01/10/2026)

71 animais das 30 espécies da categoria **Animais**, em 30 **áreas de animais** (peça
`area_animais`: volume translúcido no editor, invisível no jogo, com espécie e
quantidade). Fazendas no nordeste, cães e gatos na vila, pelicanos no porto, caranguejos
na praia sul, búfalos e bisões na planície sudeste, caça e predadores na floresta oeste;
os chefes (gorila, harpia) presos a covis nos morros. Detalhes, decisões e números em
[ANIMAIS_CHECKPOINT.md](ANIMAIS_CHECKPOINT.md).

- Fonte das áreas iniciais: `tools/mapa_ilha/areas_de_animais.json`;
  `tools/mapa_ilha/colocar_areas_de_animais.gd` as **soma** ao mapa vivo (cópia antes,
  idempotente — troca só as peças `animais_*`; nunca regenera a ilha).
- Ficha de cada espécie no catálogo (`src/world/ficha_de_animal.gd`), gravada por
  `tools/mapa_ilha/aplicar_fichas_de_animais.gd` (a tabela aprovada pelo dono).
- Fotos: `tools/mapa_ilha/capturar_animais.gd` (precisa de tela).

**Modelo atravessável** (01/10/2026, decisão do dono): a plantação `crops` não colide —
a malha de folhas (35 mil triângulos) custava 2–5 ms por quadro a quem encostava. A loja
guarda `atravessavel` e o editor insere esses modelos com a caixa "Colisão" desligada;
`tools/mapa_ilha/aplicar_atravessaveis.gd` aplica às peças que já estão no mapa.

**Árvores, frutas e floresta** (01/10/2026): 88 modelos novos na loja (categorias Árvores,
Frutas, Floresta) e 168 peças plantadas no mapa vivo — pomares ao norte da vila e na
fazenda, pinhal nos morros e o Free Forest na floresta oeste. Frutas penduradas caem a
cada 5 min e domam herbívoros — ver [FRUTAS_E_DOMA_CHECKPOINT.md](FRUTAS_E_DOMA_CHECKPOINT.md).

**Cavalo da vila**: o `animals__farm__horse_1__base` (751 mil triângulos) foi trocado na
vila por `cavalo_da_vila_leve` (62 mil, colisão própria de 160 faces) — ver
[ANIMAIS_CHECKPOINT.md](ANIMAIS_CHECKPOINT.md).

## Regenerar

```bash
G="$(./find_godot.sh)"
"$G" --headless --path . --script tools/mapa_ilha/aplicar_tamanhos_padrao.gd   # tabela da loja (idempotente)
"$G" --headless --path . --script tools/mapa_ilha/gerar_ilha.gd                # GRAVA o mapa vivo
"$G" --headless --path . --script tools/dev_tests/test_ilha_inicial.gd         # confere
"$G" --path . --script tools/mapa_ilha/capturar_ilha.gd                        # fotos (precisa de tela)
"$G" --headless --path . --script tools/mapa_ilha/medir_montagem.gd            # tempo de montagem
```

⚠️ Depois de gerado, **o mapa é a fonte**: o gerador apaga o que o dono editou. Rodar só
com pedido dele. Ele regrava o mapa INTEIRO só com o que gera: apaga também a Ilha dos
Macacos, os bandidos e a natureza. Depois dele, rode de novo as ferramentas dessas peças. O desenho (rio, regiões, estradas, nascimento) mora em
`tools/mapa_ilha/planta.json`; `tools/mapa_ilha/esboco_planta.py` desenha a planta.
A ponte vem de `tools/blender/ponte_rio.py` (ver `art_src/ponte/LEIA-ME.md`) e entra na
loja por `tools/importar_ponte_na_loja.gd`, **sem compressão de vértices** no `.import`.

## Números medidos (01/10/2026)

- Montagem do mapa: ~1,5 s com cache frio (≈1,2 s é a 1ª leitura dos .glb), ~0,3 s com
  a loja carregada; Modo História e editor abrem a ilha em ~2,7 s.
- Quadro: 7,2 ms em média e 8,3 ms na vista mais pesada (1600 × 900, RTX 3050).
- Gatilho declarado em `src/world/mapa_montador.gd`: abrir > 3 s ou quadro > 16 ms →
  malha dos blocos em disco e árvores num MultiMesh.

## Testes

- `tools/dev_tests/test_terreno_mapa.gd` — formato, malha, colisão, emendas, editor
  (clique, pouso, loja no tamanho padrão) e o catálogo real (navios, tamanhos, ponte).
- `tools/dev_tests/test_pincel_relevo.gd` — pincel: elevar/abaixar, aplainar, pintar,
  emendas exatas, crescimento conjunto, peças e spawn acompanhando, um passo de
  desfazer, e o uso no editor com mouse (Ctrl+5, cursor, [ ], pincelada, Ctrl+Z).
- `tools/dev_tests/test_ilha_inicial.gd` — o mapa: grupos, emendas exatas, nada no
  rio, nada flutuando/enterrado, nascimento livre; e o **jogador de verdade** nascendo
  na praça, com os pés no chão nas encostas, atravessando as duas pontes andando e
  encostando rente nas casas.
- `tools/dev_tests/test_animais.gd` — fichas, peça `area_animais`, áreas do mapa vivo e,
  no Modo História, nascimento, pés no chão, os quatro comportamentos, chefe preso,
  morte (+1 XP), renascer, nível de detalhe, animação e custo.

## Próximos passos (decisão do dono, 01/10/2026)

1. ~~Pincel de esculpir o relevo no editor~~ — feito (acima).
2. ~~Animais espalhados com comportamento e área de nascimento~~ — feito (acima).
3. Inimigos na ilha — a categoria "inimigos" da loja ainda vai receber mais modelos.

## Bandidos e o Guarda da vila (08/10/2026)

- **Acampamentos:** dois, em campo aberto — norte em (56, −92), entre os bosques e as
  fazendas, e sul em (−20, 84), na estrada perto da ponte. Cada um tem fogueira, toras
  e 3 bandidos de sentinela.
- **Guarda:** o Guarda da vila (missão dos bandidos) fica na praça, a 7 m do
  nascimento.
- **Fonte:** `tools/mapa_ilha/colocar_bandidos_e_missao.gd`. É idempotente: troca só as
  peças `bandidos_*`, guarda cópia em `art_src/backups/mapa_historia/` e não grava se
  o mapa mudar durante a execução.
- **Como os lugares foram escolhidos:** varredura do mapa por chão plano e seco, sem
  peça a menos de 19 m, longe de áreas de animais e a mais de 75 m da vila; conferidos
  em foto.

## Ilha dos Macacos (08/10/2026)

- **Onde:** a placa `baseplate_macacos` tem 256 × 256 m, com centro em (1500, 0). Fica a
  1.116 m de mar da placa inicial, a leste do porto.
- **O que tem:**
  - relevo em 4 × 4 blocos com o MESMO fundo (−1,5) e a mesma altura de bloco da
    inicial, como o pincel de relevo exige;
  - morros até 23,1 m, clareira e trilha de terra do píer até ela;
  - 57 % de chão de mata, onde as árvores gigantes vão entrar;
  - anel de praia com a conta da inicial;
  - píer (`dock_long`) na costa oeste;
  - 4 bandos de macacos (12).
- **Grupos:** "ilha_dos_macacos", com relevo, praia, porto e animais dentro.
- **Fonte:** `tools/mapa_ilha/gerar_ilha_dos_macacos.gd`. É idempotente (troca só
  `macacos_*` e `baseplate_macacos`), guarda cópia em `art_src/backups/mapa_historia/` e
  não grava se o mapa mudar durante a execução. `-- --saida=<arquivo>` grava em outro
  lugar, para prévia.
- **Mar:** um fundo do mar por ilha (`FundoDoMar.montar_por_ilha`), e cada um vai até a
  metade do caminho.
- **Fotos e teste:** `tools/mapa_ilha/capturar_ilha_dos_macacos.gd` e
  `tools/dev_tests/test_ilha_dos_macacos.gd`.

