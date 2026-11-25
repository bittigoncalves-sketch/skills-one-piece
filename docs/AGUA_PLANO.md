# Água: jogador e animais — plano e estado (01/10/2026)

Pedido do dono: interação de jogador e animais com a água — **água rasa deixa mais
lento** (dificuldade de andar), **natação** com flutuação e animação de nado, **mergulho**
— e **mais água embaixo do mar** (hoje não dá para mergulhar). Ordem combinada:
água rasa → nado do jogador → nado dos animais → fundo do mar e mergulho.

## Estado (01/10/2026, noite): etapas A1–A5 FEITAS

| etapa | o que ficou | arquivos |
|---|---|---|
| A1 serviço | `AguaDoMundo.nivel_em(x, z)`: mar (fora das baseplates, nível do `Oceano`) e rio (água do relevo, `TerrenoDoMapa.agua_local`); `submersao`, `fator_de_andar` | `src/historia/agua/agua_do_mundo.gd` |
| A2 água rasa | jogador e animais: canela −15 %, joelho −30 %, cintura −50 % (medido: 4,20 → 2,54 m/s com 41 % do corpo na água; vaca 0,80 → 0,40) | `Player.fator_da_agua`, `jogador_na_agua.gd`, `animal_da_ilha.gd` |
| A3 nado | água no peito → nada (2,6 m/s); boia com a cabeça fora; **Espaço sobe, Ctrl mergulha**; fôlego 30 s, depois −1 vida/s; sai andando pela praia. Usuário de fruta: não nada, afunda quando o corpo fica todo submerso, anda a 1,2 m/s no fundo, sem técnicas (voltam fora d'água). Pose de nado no animador (crawl andando, "pedalar" parado). Barra de FÔLEGO e tinta azul com a câmera submersa | `Player.gd` (`modo_na_agua`, `agua_vertical`), `jogador_na_agua.gd`, `ProceduralAnimator._swim`, `src/ui/AguaHud.gd` |
| A4 animais | mais de 65 % do corpo na água: boia (60 % submerso) e nada a metade da velocidade; nível da água consultado a cada 0,25 s | `animal_da_ilha.gd` |
| A5 fundo do mar | peça de mundo em tempo de jogo (como o `Oceano`): borda rente à praia lida do relevo, desce até −30 m em 150 m, plano até 600 m da costa; colisão em 4 faixas `HeightMapShape3D` EM VOLTA da ilha (uma forma só embaixo da ilha custava ~0,9 ms por quadro aos animais); cor por profundidade | `src/world/fundo_do_mar.gd` |

Validação: `tools/dev_tests/test_agua.gd` (26 checagens, 0 falhas) e fotos com GPU em
`art_src/validation/agua/` (`tools/mapa_ilha/capturar_agua.gd`).

Limitações conhecidas:
- O rio tem **no máximo 0,95 m** de água (59 % do corpo): dá pé em todo lugar — no rio
  só se anda devagar; o nado é no mar.
- O mar é **opaco**: de fora d'água, nadando, só aparecem cabeça e braços.
- O fundo do mar vale para UMA ilha (a caixa que envolve as baseplates). Gatilho: mapa
  com mais de uma ilha separada.
- O fundo do mar não aparece no editor de mapa (só no jogo), como o oceano não colide.

## Onde estávamos antes (medido no código, 01/10/2026)

- O mar é **só visual** (`src/world/oceano_historia.gd`): superfície a −0,65 m, sem colisão,
  sem natação ("primeira etapa" no próprio arquivo). Os pets já leem `Oceano.nivel`.
- O rio é água de verdade no RELEVO (`agua` por ponto do bloco de terreno): o leito é chão
  para a física; `TerrenoDoMapa.molhado_local` diz se um ponto é rio.
- Fora da ilha (além de ±256 m) **não há fundo**: quem passa da praia cai no vazio.

## Decisões do dono

- **Usuário de Akuma no Mi** (o Rocket, por exemplo): água rasa só deixa lento; **não
  consegue nadar**; **afunda no momento em que o corpo fica completamente submerso**.
- Implementação em etapas, **sem colidir com a sessão dos seabeasts** (ela cria modelos,
  ossos e as entradas na loja do editor).

## Etapas

| # | etapa | o que entrega | arquivos (novos ou tocados) |
|---|---|---|---|
| A1 | **Serviço de água** | uma pergunta só para todos: nível da água e profundidade num ponto (mar = `Oceano.nivel`; rio = `agua` do relevo) e quanto de um corpo está submerso | novo `src/world/agua_do_mundo.gd` |
| A2 | **Água rasa** | velocidade cai com a profundidade (canela −15 %, joelho −30 %, cintura −50 %), para jogador e animais; respingo leve ao entrar | `Player.gd` (só o fator de velocidade), `animal_da_ilha.gd` |
| A3 | **Nado do jogador** | água no peito → nadar: flutua com a cabeça para fora, velocidade de nado, animação procedural de nado (corpo deitado, braçada alternada, pernada); sai da água subindo na margem. Usuário de fruta não nada: anda devagar até submergir e então afunda | `Player.gd` (estado de nado), `src/anim/ProceduralAnimator.gd` (pose de nado) |
| A4 | **Nado dos animais** | herbívoro e predador atravessam água rasa devagar; na funda, nadam devagar com o corpo semissubmerso para a margem mais perta; passeio continua evitando o rio; pets seguem o dono nadando | `animal_da_ilha.gd`, `pet_domado.gd` |
| A5 | **Fundo do mar e mergulho** | anel de blocos de relevo além da praia descendo até o fundo (soma ao mapa vivo, como a natureza); mergulhar (Ctrl) e subir (Espaço); fôlego de 30 s; visão submersa (tinta azul e névoa) | ferramenta nova em `tools/mapa_ilha/`, `Player.gd`, ambiente |

## Cuidado com a outra sessão (seabeasts)

- **Não tocar**: arquivos de modelo e ossos dos seabeasts, entradas deles na loja, scripts
  deles. A água é um SERVIÇO que os seabeasts podem consultar depois (A1), sem depender
  deles.
- **A loja (`mapas/modelos/catalogo.json`) é compartilhada**: as duas sessões gravam o
  arquivo inteiro. Minhas ferramentas carregam a loja do disco e gravam em segundos; o
  risco é a outra sessão ter a loja aberta na memória (o editor) e gravar depois,
  desfazendo a minha gravação (ou eu a dela). Antes de gravar a loja: conferir a hora do
  arquivo e avisar o dono.
- Arquivos da outra sessão (conferido 19:30): `docs/BESTAS_MAR_CHECKPOINT.md`,
  `tools/blender/bestas_mar.py`, `tools/*bestas_mar*`, `tools/dev_tests/test_bestas_mar.gd`,
  `art_src/bestas_mar/`, `mapas/modelos/besta_mar_*.glb`, categoria `bestas_do_mar` da loja.
  O plano dela é só modelo, rig e loja — nada de água.
- O fundo do mar (A5) é onde os seabeasts vão viver: fazer o A5 só depois de combinar com
  o dono a área e a profundidade.

## Decisões do dono (01/10/2026, segunda rodada)

- **Fôlego de 30 s** submerso (barra na tela); acabou, perde vida aos poucos até subir —
  vale para todos, inclusive o usuário de fruta que afundou.
- **Fundo do mar**: da praia desce suave até **30 m** num anel de **~150 m** ao redor da
  ilha; depois, fundo plano a 30 m (mar aberto para os seabeasts).
- **Usuário de fruta afundado** anda **devagar pelo fundo** até a margem; sem técnicas
  enquanto submerso; o fôlego acabando tira vida.
- Teclas: **Ctrl desce**, **Espaço sobe** (decisão do dono).
