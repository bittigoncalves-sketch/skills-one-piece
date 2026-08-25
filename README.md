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

### Editar animação no Blender

Desde 2026-08-25 o clipe do jogo vai e volta do Blender sem script no meio:

```bash
godot --headless --path . -s tools/exportar_para_blender.gd
#   abre assets/blender/rig_base_completo.glb no Blender (33 Actions), edita
godot --headless --path . -s tools/importar_do_blender.gd -- \
      assets/blender/rig_base_completo.glb
```

**Para continuar o trabalho de animação, comece por
[`docs/PLANO_ANIMACAO_FASES_2_3_4.md`](docs/PLANO_ANIMACAO_FASES_2_3_4.md)** —
é o ponto de entrada, e traz o que uma máquina nova precisa preparar antes.

## Documentação

O índice está dividido em **três blocos**: as frutas (uma página por fruta), os
documentos vivos (valem hoje) e o histórico por data (o *porquê* de decisões
antigas — nada ali é apagado).

### Akuma no Mi — uma página por fruta

| Arquivo | Conteúdo |
|---|---|
| [`docs/frutas/README.md`](docs/frutas/README.md) | **comece aqui**: índice, estado de cada fruta, e o que vale para todas (caminho do cast, escala de dano, recarga real, passivas) |
| [`docs/frutas/gura_gura.md`](docs/frutas/gura_gura.md) | tremor — investida do Z, captura do X, ultimate de 4 s, e a escala 2× |
| [`docs/frutas/gomu_gomu.md`](docs/frutas/gomu_gomu.md) · [`bara_bara`](docs/frutas/bara_bara.md) · [`buki_buki`](docs/frutas/buki_buki.md) | Paramecias |
| [`docs/frutas/mera_mera.md`](docs/frutas/mera_mera.md) · [`hie_hie`](docs/frutas/hie_hie.md) · [`goro_goro`](docs/frutas/goro_goro.md) · [`yami_yami`](docs/frutas/yami_yami.md) · [`suna_suna`](docs/frutas/suna_suna.md) | Logias |
| [`docs/PLANO_FRUTAS.md`](docs/PLANO_FRUTAS.md) · [`docs/AUDITORIA_FRUTAS.md`](docs/AUDITORIA_FRUTAS.md) | critérios de fruta funcional e o placar medido em 2026-08-10 |

### Documentos vivos

| Arquivo | Conteúdo |
|---|---|
| [`docs/PLANO_ANIMACAO_FASES_2_3_4.md`](docs/PLANO_ANIMACAO_FASES_2_3_4.md) | **ponto de entrada da animação**: o que falta (Fases 2, 3, 4), com alvos medidos e o preparo da máquina nova |
| [`docs/AUDITORIA_ANIMACAO.md`](docs/AUDITORIA_ANIMACAO.md) | os 11 achados medidos do sistema de animação e do esqueleto, e a Fase 1 implementada |
| [`docs/ANIMACOES_MIXAMO.md`](docs/ANIMACOES_MIXAMO.md) | pipeline, catálogo de clipes, limitações |
| [`docs/AGENTES.md`](docs/AGENTES.md) | como o trabalho é dividido entre agentes especializados |
| [`docs/LIMITE_DE_TAMANHO.md`](docs/LIMITE_DE_TAMANHO.md) | limite de 900 linhas por script, o que já foi dividido e o plano do `Player.gd` |
| [`docs/ARQUITETURA_PLAYER.md`](docs/ARQUITETURA_PLAYER.md) | **decisão de arquitetura**: componentes por domínio, 9 fases, e o princípio de posse de estado |
| [`docs/RELATORIO_PLAYER.md`](docs/RELATORIO_PLAYER.md) | mapa do `Player.gd` por domínio, estado compartilhado e a medição que embasou a decisão |
| [`docs/LISTA_DE_CORRECOES.md`](docs/LISTA_DE_CORRECOES.md) | bugs achados e **não** corrigidos, esperando decisão |
| [`docs/VALIDACAO.md`](docs/VALIDACAO.md) | a bateria automática (`./validar.sh`) e as armadilhas que ela resolve |
| [`docs/erros.md`](docs/erros.md) | registro de bugs com causa raiz e correção |
| [`DOCUMENTACAO.md`](DOCUMENTACAO.md) | visão geral do projeto |
| [`disabled/enemies/README.md`](disabled/enemies/README.md) | inimigos desligados do mapa e como religar |

### Histórico por data — não apagar

Registram *o porquê* de decisões antigas e as armadilhas já pagas. Para o estado
**de hoje** de uma fruta, use `docs/frutas/`.

| Arquivo | Conteúdo |
|---|---|
| [`docs/MUDANCAS_2026-08-06.md`](docs/MUDANCAS_2026-08-06.md) | rig único, conserto do pipeline, Buki Buki |
| [`docs/MUDANCAS_2026-08-10.md`](docs/MUDANCAS_2026-08-10.md) | arena: buracos, placar, corpo a corpo, armas em .glb |
| [`docs/MUDANCAS_2026-08-10_PARTE2.md`](docs/MUDANCAS_2026-08-10_PARTE2.md) | rig, rebake dos 28 clipes, personagem novo, multiplayer, LAN |
| [`docs/MUDANCAS_2026-08-11.md`](docs/MUDANCAS_2026-08-11.md) | dash mais rápido; Buki Buki virou kit de FPS com munição |
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
