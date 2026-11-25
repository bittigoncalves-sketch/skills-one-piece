# Skills One Piece

Jogo de ação 3D em **Godot 4.6** inspirado em One Piece: frutas do diabo com
habilidades próprias, estilos de luta, parkour e multiplayer cliente-servidor.

> Projeto pessoal em desenvolvimento. Os modelos 3D dos personagens foram gerados
> com IA (Meshy) e as animações vêm do [Mixamo](https://www.mixamo.com).

## Rodar

Precisa do **Godot 4.6** (baixado do site; não precisa de export templates).

```bash
./jogar.sh          # abre o jogo
./servidor.sh       # sobe um servidor dedicado (headless)
./jogar_ope.sh      # abre a arena com Ope Ope no Mi equipada
./jogar_goro.sh     # abre a arena com Goro Goro no Mi equipada
./jogar_yoru.sh     # abre a arena no modo espada (Yoru)
./jogar_mera.sh     # abre a arena com Mera Mera no Mi equipada
```

Os scripts acham o Godot sozinhos (`$GODOT`, PATH, ou pastas comuns de download).
Se não acharem: `GODOT=/caminho/do/godot ./jogar.sh`.

⚠️ **Primeira execução depois de clonar** demora alguns minutos: o `jogar.sh`
chama o `setup.sh` sozinho para importar os assets (~275 MB) e gerar o cache de
`class_name`. **Não pule esse passo** — a pasta `.godot/` não vai no repositório,
e sem o cache de `class_name` o `Main.gd` nem compila: o jogo abre em **tela
cinza** ao entrar no singleplayer. Para rodar à mão: `./setup.sh`.

O `jogar.sh` força o driver **wayland** de propósito — numa sessão Wayland o
XWayland quebra o mouse capturado ao andar. Em sessão X11 o Godot cai em x11
sozinho.

## Controles

| Ação | Tecla |
|---|---|
| Andar / correr | `WASD` (+ `Shift` corre) |
| Pular / parkour | `Espaço` — vault, salto longo, wall run, pouso; segurar contra parede = escalar |
| Câmera | Mouse — 1ª/3ª pessoa em `F5` |
| Ataque corpo a corpo | Botão **esquerdo** do mouse |
| Mira (com arma na mão) | Botão **direito** do mouse |
| Técnicas | `Z` `X` `C` `V` — segurar carrega/mira, soltar dispara |
| **Modo de combate** | `1` fruta · `2` estilo de luta · `3` espada |
| Menu de personagem e fruta | `M` |
| Observação (alvos e ataques através de paredes) | `E` |
| Quebra-combo | `G` |
| Corpo de Ferro | `F` |
| Ciclar fruta (depuração) | `T` |
| Ciclar personagem | `F6` — elenco trancado no `base`, ver `ELENCO_LIBERADO` |
| Menu principal | `ESC` |

⚠️ O modo de combate mudou em **2026-09-06**: era o `R` alternando entre dois
modos, e virou `1`/`2`/`3` quando a espada entrou como terceiro
([`Player.gd:771`](Player.gd#L771)). Documento que ainda mande apertar `R` está
velho.

No **Modo História**, `E` conversa com NPCs e abre lojas. `B` abre a tripulação:
arraste até seis membros para os cargos, acompanhe vida/fome, consuma comida ou
água e deposite a reserva do estoquista. A lista comporta até 16 membros.
Fome zero impede regeneração; sede zero mata após quatro dias do ciclo sem beber.
A campanha começa com vara de pesca → peixe raro → ferraria → três árvores → facção.
Detalhes e validação em [Sobrevivência e tripulação](docs/SOBREVIVENCIA_TRIPULACAO_CHECKPOINT.md).

## Multiplayer

Cliente-servidor com **ENet**, servidor-autoritário. O modo um-jogador roda o
mesmo código, com um servidor local.

**Na mesma rede local, ninguém precisa digitar nada:** quem hospeda vira um
farol (anúncio UDP em difusão a cada segundo) e quem entra clica em **CONECTAR
POR LAN**, que escuta a rede e conecta no primeiro host que responder. O IP vem
do próprio pacote, então máquina com várias placas (Wi-Fi, cabo, Docker, VPN) não
confunde. Medido: host achado em ~0,5 s. Ver
[`network/LanDiscovery.gd`](network/LanDiscovery.gd).

Para fora da LAN continua valendo o **ID da sala**: 7 caracteres que codificam o
IP do host em base32. Quem hospeda vê o ID no HUD; quem entra digita o ID — ou um
IP direto. (Difusão UDP não atravessa roteador.)

⚠️ O ID carrega um IP **privado**, então funciona na **mesma rede local**. Para
jogar pela internet é preciso port-forward da porta `24565` no roteador do host,
ou subir o `servidor.sh` numa máquina com IP público.

## Personagens e rig

> **Elenco: `base` e `bluebuddy`.** O `bluebuddy` (Meshy, skinnado, GLB) entrou
> em 2026-08-10 como personagem adicional — o `base` continua sendo o padrão e o
> rollback. Os demais seguem fora do menu — o trabalho de
> animação está concentrado nesse personagem. Ace, Nami, Barba Negra, Crocodile
> e Buggy continuam no projeto, mas fora do menu. Para liberar, acrescente o id
> em `Player.ELENCO_LIBERADO` e em `CHARS` (`src/ui/CharacterMenu.gd`).

Todos os personagens — voxel (`.scn`/`.glb`) e skinnados (`Skeleton3D` dos modelos
Meshy) — falam **um único rig lógico de 13 papéis**:

```
Torso, Neck, Head, UpperArm_L/R, ForeArm_L/R, Thigh_L/R, Shin_L/R, Foot_L/R
```

Nos personagens voxel esses são nomes de nós. Nos skinnados, o
[`SkeletonDriver`](src/anim/SkeletonDriver.gd) cria nós-proxy, deixa o
`ProceduralAnimator` girá-los como se fosse um rig por nós, e espelha o resultado
nos ossos. Assim a mesma animação serve os dois tipos.

Tamanhos podem variar entre personagens; nomes e hierarquia, não.

## A arena

O chão é uma **grade de lajes de 10 m** com **16 buracos quadrados** (12 de 1×1
célula e 4 de 2×2, semente fixa). Cair num buraco — ou ser jogado para fora da
plataforma — mata.

A rodada dura **10 minutos**. Derrubar alguém conta kill; quem cai leva morte, e
a kill vai para o último que causou dano nele nos últimos **10 s**. No fim da
rodada aparece um pódio de 8 s, todos respawnam com vida cheia e o placar zera.
A contagem é **autoridade do servidor** — ver
[`src/match/Scoreboard.gd`](src/match/Scoreboard.gd).

**Corpo a corpo** no botão esquerdo do mouse: soco direito → soco esquerdo →
chute, encadeáveis dentro de 2 s. Não gasta energia. Cada golpe usa um clipe
autoral de lado próprio, e a hitbox nasce no **frame do impacto** (medido, não
estimado). Ver [`src/combat/Melee.gd`](src/combat/Melee.gd).

> Os **inimigos não nascem mais no mapa** — o foco é luta entre jogadores. O
> código deles está inteiro em [`disabled/enemies/`](disabled/enemies/), ainda
> compilando; religar é uma linha. O dummy de treino continua no centro.

## Animação

Duas camadas que se somam:

- **Procedural** (`src/anim/ProceduralAnimator.gd`) — idle, caminhada, corrida,
  ar, escalada e parkour gerados em runtime a partir da velocidade e do estado.
  Reage à física.
- **Clipes do Mixamo** retargetados para os 13 papéis, para golpes e one-shots.

### Pipeline do Mixamo

O importador FBX do Godot perde as chaves de animação dos membros, então os FBX
passam pelo Blender antes:

```bash
blender --background --python tools/fbx_to_glb.py -- \
    "$PWD/assets/animations" "$PWD/assets/animations_glb"
godot --headless --path . -s tools/bake_mixamo.gd
```

Detalhes em [`docs/ANIMACOES_MIXAMO.md`](docs/ANIMACOES_MIXAMO.md).

## Documentação

O índice está dividido em **três blocos**: as frutas (uma página por fruta), os
documentos vivos (valem hoje) e o histórico por data (o *porquê* de decisões
antigas — nada ali é apagado).

### Akuma no Mi — uma página por fruta

| Arquivo | Conteúdo |
|---|---|
| [`docs/frutas/README.md`](docs/frutas/README.md) | **comece aqui**: índice, estado de cada fruta, e o que vale para todas (caminho do cast, escala de dano, recarga real, passivas) |
| [`docs/frutas/ope_ope.md`](docs/frutas/ope_ope.md) | ROOM, Shambles, Takt e Gamma Knife; modelos, poses, VFX, sons e lançador de treino próprios |
| [`docs/frutas/gura_gura.md`](docs/frutas/gura_gura.md) | tremor — investida do Z, captura do X, ultimate de 4 s, e a escala 2× |
| [`docs/frutas/gomu_gomu.md`](docs/frutas/gomu_gomu.md) · [`bara_bara`](docs/frutas/bara_bara.md) · [`buki_buki`](docs/frutas/buki_buki.md) · [`bomu_bomu`](docs/frutas/bomu_bomu.md) | Paramecias |
| [`docs/frutas/mera_mera.md`](docs/frutas/mera_mera.md) · [`hie_hie`](docs/frutas/hie_hie.md) · [`goro_goro`](docs/frutas/goro_goro.md) · [`yami_yami`](docs/frutas/yami_yami.md) · [`suna_suna`](docs/frutas/suna_suna.md) | Logias |
| [`docs/frutas/pika_pika.md`](docs/frutas/pika_pika.md) | **a fruta INICIAL** — luz: colisão, o som próprio e o que ficou em aberto |
| [`docs/PLANO_FRUTAS.md`](docs/PLANO_FRUTAS.md) · [`docs/AUDITORIA_FRUTAS.md`](docs/AUDITORIA_FRUTAS.md) | critérios de fruta funcional e o placar medido em 2026-08-10 |

### Documentos vivos

**Por onde começar**

| Arquivo | Conteúdo |
|---|---|
| [`docs/GUIA_DO_PROJETO.md`](docs/GUIA_DO_PROJETO.md) | **leia antes de escrever qualquer linha**: as regras que não se negociam e os 10 minutos de contexto |
| [`docs/ESTADO_ATUAL.md`](docs/ESTADO_ATUAL.md) | briefing para quem chega frio no projeto |
| [`docs/FILA_DE_TAREFAS.md`](docs/FILA_DE_TAREFAS.md) | o que está na fila |
| [`docs/AGENTES.md`](docs/AGENTES.md) | como o trabalho é dividido entre agentes especializados, e os dois agentes de **avaliação** |

**Guia prático — onde mexer e como**

| Arquivo | Conteúdo |
|---|---|
| [`docs/guia/COMO_TRABALHAR.md`](docs/guia/COMO_TRABALHAR.md) | o ciclo de trabalho esperado |
| [`docs/guia/ONDE_COLOCAR.md`](docs/guia/ONDE_COLOCAR.md) | a pasta certa para cada coisa, e a **fonte de verdade** de frutas, estilos e personagens |
| [`docs/guia/COMO_ESCREVER_SCRIPT.md`](docs/guia/COMO_ESCREVER_SCRIPT.md) | convenções de GDScript desta base |
| [`docs/guia/ASSETS_VISUAIS.md`](docs/guia/ASSETS_VISUAIS.md) | como construir um asset visual |
| [`docs/guia/ARMADILHAS.md`](docs/guia/ARMADILHAS.md) | as armadilhas desta base — cache de `class_name`, `.gdignore`, importação |
| [`docs/LIMITE_DE_TAMANHO.md`](docs/LIMITE_DE_TAMANHO.md) | limite de 900 linhas por script, o que já foi dividido e o plano do `Player.gd` |

**Combate**

| Arquivo | Conteúdo |
|---|---|
| [`docs/MODOS_DE_COMBATE.md`](docs/MODOS_DE_COMBATE.md) | **teclas 1/2/3**: fruta, estilo de luta e espada — e por que o terceiro valor exigiu um portão no cast |
| [`docs/COMBATE_ESPADA.md`](docs/COMBATE_ESPADA.md) | **a Yoru**: pega `handle`/`Hand_R`, as bolinhas do fio, o choque de espadas e o combo horizontal→vertical |
| [`docs/COMBATE_CORPO_A_CORPO.md`](docs/COMBATE_CORPO_A_CORPO.md) | o combo M1, frame data e a FSM |
| [`docs/MECANICAS.md`](docs/MECANICAS.md) | mecânicas de combate, visão geral |
| [`docs/ESTILOS_DE_LUTA.md`](docs/ESTILOS_DE_LUTA.md) | o segundo modo de combate (tecla `2`) |
| [`docs/ESTILO_PACIFISTA.md`](docs/ESTILO_PACIFISTA.md) | o estilo PACIFISTA (PX) |
| [`docs/RODADA_E_PLACAR.md`](docs/RODADA_E_PLACAR.md) | rodada, placar e morte |
| [`docs/MOVIMENTO.md`](docs/MOVIMENTO.md) | leitura de movimento, parkour e esquiva |
| [`docs/DIRECOES.md`](docs/DIRECOES.md) | a rosa dos ventos — **FRENTE = −Z** |

**Personagem, rig e animação**

| Arquivo | Conteúdo |
|---|---|
| [`docs/ANIMACOES_MIXAMO.md`](docs/ANIMACOES_MIXAMO.md) | pipeline, catálogo de clipes, limitações |
| [`docs/ESQUELETO.md`](docs/ESQUELETO.md) | o esqueleto do personagem e os 13 papéis canônicos |
| [`docs/PERSONAGEM_BASE_V2.md`](docs/PERSONAGEM_BASE_V2.md) | o personagem base V2 — fonte `.blend`, 134 ossos, IK |
| [`docs/CUSTOMIZACAO.md`](docs/CUSTOMIZACAO.md) | acessórios e cor — ⚠️ **bloqueada desde 2026-09-08** |
| [`docs/PLANO_ANIMACAO_PROCEDURAL.md`](docs/PLANO_ANIMACAO_PROCEDURAL.md) | animação procedural em tempo real |

**Arquitetura e qualidade**

| Arquivo | Conteúdo |
|---|---|
| [`docs/ARQUITETURA_PLAYER.md`](docs/ARQUITETURA_PLAYER.md) | **decisão de arquitetura**: componentes por domínio, 9 fases, e o princípio de posse de estado |
| [`docs/RELATORIO_PLAYER.md`](docs/RELATORIO_PLAYER.md) | mapa do `Player.gd` por domínio, estado compartilhado e a medição que embasou a decisão |
| [`docs/LISTA_DE_CORRECOES.md`](docs/LISTA_DE_CORRECOES.md) | bugs achados e **não** corrigidos, esperando decisão |
| [`docs/VALIDACAO.md`](docs/VALIDACAO.md) | a bateria automática (`./validar.sh`) e as armadilhas que ela resolve |
| [`docs/erros.md`](docs/erros.md) | **registro de bugs com causa raiz** — entradas mais recentes no topo |
| [`docs/NUMEROS_MEDIDOS.md`](docs/NUMEROS_MEDIDOS.md) | índice dos números medidos no jogo rodando |
| [`docs/PLANO_VISUAL.md`](docs/PLANO_VISUAL.md) · [`REVISAO_QUALIDADE_GRAFICA_2026-08-30.md`](docs/REVISAO_QUALIDADE_GRAFICA_2026-08-30.md) | melhoria visual qualitativa e o diagnóstico gráfico |

**Rede, plataformas e distribuição**

| Arquivo | Conteúdo |
|---|---|
| [`docs/MODO_CELULAR.md`](docs/MODO_CELULAR.md) | controles de toque |
| [`docs/HOSPEDAR_PARA_FORA.md`](docs/HOSPEDAR_PARA_FORA.md) | hospedar partida fora da rede de casa |
| [`docs/EXPORTAR_E_COMPARTILHAR.md`](docs/EXPORTAR_E_COMPARTILHAR.md) | gerar o executável e mandar para outra pessoa |
| [`disabled/enemies/README.md`](disabled/enemies/README.md) | inimigos desligados do mapa e como religar |

**Planos em aberto**

| Arquivo | Conteúdo |
|---|---|
| [`docs/PLANO_YORU.md`](docs/PLANO_YORU.md) · [`EXECUCAO_YORU.md`](docs/EXECUCAO_YORU.md) · [`YORU_IMPLEMENTACAO.md`](docs/YORU_IMPLEMENTACAO.md) | o plano da espada, as 8 ondas de agentes e a entrega de 09/09 |
| [`docs/PLANO_COMBATE_BATTLEGROUNDS.md`](docs/PLANO_COMBATE_BATTLEGROUNDS.md) | combate corpo a corpo estilo Battlegrounds |
| [`docs/PLANO_COMBATE_CONTEXTUAL.md`](docs/PLANO_COMBATE_CONTEXTUAL.md) | combate contextual — plano vivo |
| [`docs/PLANO_EQUILIBRIO_COMBATE.md`](docs/PLANO_EQUILIBRIO_COMBATE.md) | equilíbrio de dano, recarga e knockback |
| [`docs/PLANO_MERA_MERA.md`](docs/PLANO_MERA_MERA.md) · [`ESTUDO_MERA_MERA_CARGAS.md`](docs/ESTUDO_MERA_MERA_CARGAS.md) | remodelação da Mera Mera e o estudo de cargas |
| [`docs/GEAR2.md`](docs/GEAR2.md) | Gear 2 — a primeira transformação do jogo (slot `V` da Gomu) |

### Histórico por data — não apagar

Registram *o porquê* de decisões antigas e as armadilhas já pagas. Para o estado
**de hoje** de uma fruta, use `docs/frutas/`.

| Arquivo | Conteúdo |
|---|---|
| [`docs/historico/MUDANCAS_2026-08-06.md`](docs/historico/MUDANCAS_2026-08-06.md) | rig único, conserto do pipeline, Buki Buki |
| [`docs/historico/MUDANCAS_2026-08-10.md`](docs/historico/MUDANCAS_2026-08-10.md) | arena: buracos, placar, corpo a corpo, armas em .glb |
| [`docs/historico/MUDANCAS_2026-08-10_PARTE2.md`](docs/historico/MUDANCAS_2026-08-10_PARTE2.md) | rig, rebake dos 28 clipes, personagem novo, multiplayer, LAN |
| [`docs/historico/MUDANCAS_2026-08-11.md`](docs/historico/MUDANCAS_2026-08-11.md) | dash mais rápido; Buki Buki virou kit de FPS com munição |
| [`docs/historico/MUDANCAS_2026-08-21.md`](docs/historico/MUDANCAS_2026-08-21.md) | o sistema de dano virou um sistema |
| [`docs/historico/MUDANCAS_2026-08-22.md`](docs/historico/MUDANCAS_2026-08-22.md) | rede: o que o cliente via, o que não via e o que não conseguia fazer |
| [`docs/historico/MUDANCAS_2026-08-23.md`](docs/historico/MUDANCAS_2026-08-23.md) | som no dash, bonecos por interruptor, e a Yami consertada |
| [`docs/historico/MUDANCAS_2026-08-25.md`](docs/historico/MUDANCAS_2026-08-25.md) | o combo virou frame data, e a FSM ganhou as fases que faltavam |
| [`docs/PEDIDO_2026-08-12.md`](docs/PEDIDO_2026-08-12.md) | as 7 tarefas daquela sessão: charge-up, Goro repaginada, Black Hole nos pés, luneta, Karatê Tritão |
| [`docs/AUDITORIA_FASE6.md`](docs/AUDITORIA_FASE6.md) | a fase que extraiu o cast do `Player.gd`, com as notas de execução |

## Testes

Rodam headless, sem abrir o jogo:

```bash
godot --headless --path . -s tools/dev_tests/test_rig_unico.gd     # rig único
godot --headless --path . -s tools/dev_tests/test_anatomia_rig.gd  # pose sã
godot --headless --path . -s tools/dev_tests/test_buki_buki.gd     # fruta Buki Buki
godot --headless --path . -s tools/dev_tests/test_arena.gd         # arena (29 checagens)
```

O `test_arena.gd` sobe o jogo de verdade e cobre buracos do mapa, placar da
rodada, combate corpo a corpo e as armas em `.glb`.

`tools/dev_tests/captura_anim.gd` renderiza frames de um estado de animação para
inspeção visual, sem precisar jogar.
