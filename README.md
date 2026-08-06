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

O **ID da sala** (7 caracteres) codifica o IP do host em base32. Quem hospeda vê
o ID no HUD; quem entra digita o ID — ou um IP direto.

⚠️ O ID carrega um IP **privado**, então funciona na **mesma rede local**. Para
jogar pela internet é preciso port-forward da porta `24565` no roteador do host,
ou subir o `servidor.sh` numa máquina com IP público.

## Personagens e rig

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

| Arquivo | Conteúdo |
|---|---|
| [`docs/ANIMACOES_MIXAMO.md`](docs/ANIMACOES_MIXAMO.md) | pipeline, catálogo de clipes, limitações |
| [`docs/erros.md`](docs/erros.md) | registro de bugs com causa raiz e correção |
| [`docs/MUDANCAS_2026-08-06.md`](docs/MUDANCAS_2026-08-06.md) | rig único, conserto do pipeline, Buki Buki |
| [`DOCUMENTACAO.md`](DOCUMENTACAO.md) | visão geral do projeto |

## Testes

Rodam headless, sem abrir o jogo:

```bash
godot --headless --path . -s tools/dev_tests/test_rig_unico.gd     # rig único
godot --headless --path . -s tools/dev_tests/test_anatomia_rig.gd  # pose sã
godot --headless --path . -s tools/dev_tests/test_buki_buki.gd     # fruta Buki Buki
```

`tools/dev_tests/captura_anim.gd` renderiza frames de um estado de animação para
inspeção visual, sem precisar jogar.
