# Editor de Animação — Skills One Piece

Editor de keyframes para o rig de 13 papéis do jogo. Carrega o personagem,
mostra o esqueleto em 3D, e grava direto em `assets/animations/<nome>.tres`,
que o jogo carrega igual a um `.res`.

> **Elenco trancado no `base`.** O editor e o jogo estão restritos ao personagem
> `base` — é nele que a animação está sendo feita. Os outros modelos continuam
> no projeto, só não são selecionáveis. Para liberar: `ELENCO_LIBERADO` em
> `Player.gd`, `CHARS` em `src/ui/CharacterMenu.gd` e `PERSONAGENS` nos dois
> exportadores.

Python puro, **só biblioteca padrão** (tkinter). Sem instalar nada.

```bash
python3 tools/anim_editor/main.py
```

---

## Antes da primeira vez

O editor não lê os formatos do Godot (`.scn`, `.fbx`, `.res` são binários).
Quem exporta é o próprio Godot, em dois passos:

```bash
GODOT=/caminho/do/godot
$GODOT --headless --path . -s tools/export_rig.gd     # personagens -> rigs/*.json
$GODOT --headless --path . -s tools/export_anims.gd   # 28 clipes   -> clips/*.json
$GODOT --headless --path . -s tools/export_mesh.gd    # malhas      -> meshes/*.json
```

Rode de novo sempre que mexer num personagem ou assar animação nova. O lançador
da área de trabalho faz isso sozinho na primeira vez.

---

## Criar rig por marcadores

Método igual ao do Meshy: você marca as juntas **sobre o modelo** e o esqueleto
sai com os comprimentos **reais** daquele personagem — em vez de proporções
chutadas.

Botão **Criar rig (marcadores)**. São 7 tipos, 12 pontos:

| Marcador | Pontos | Vira |
|---|---|---|
| Queixo | 1 | `Neck` → `Head` |
| Ombros | A / B | `UpperArm_L/R` |
| Cotovelos | A / B | `ForeArm_L/R` |
| Pulsos | A / B | ponta do antebraço |
| Virilha | 1 | origem do `Torso` (quadril) |
| Joelhos | A / B | `Shin_L/R` |
| Tornozelos | A / B | `Foot_L/R` |

- **Botão direito** sobre o modelo marca o ponto ativo; ele avança sozinho para o
  próximo slot vazio.
- **Simetria** ligada espelha A em B no plano X — é o que evita ombro torto.
- **Sugerir posições** parte de um palpite por proporção humana, para você só
  corrigir em vez de colocar 12 pontos do zero.
- A espessura de cada osso é **medida na malha** (`Malha.raio_em`), então braço
  fino e tronco largo saem certos.

Por que importa: o Barba Negra do Meshy veio com a **canela a 54% da coxa** (o
resto do elenco fica em 74–88%) — é o que faz ele parecer anão. Re-rigado por
marcadores, sai **99%**.

**Modelo novo:** largue o `.glb`/`.fbx` em `assets/models/inbox/` e rode
`export_mesh.gd` — ele aparece na lista para ser rigado.

---

## Fluxo

1. **Personagem** — escolha na lista. Se ele já tem ossos, eles aparecem. Se não
   tem, use **Criar rig (marcadores)** acima. `<rig canônico>` é a saída de
   emergência: 13 ossos de proporção fixa, sem precisar do modelo.
2. **Clipe** — abra um dos 28 do Mixamo para ajustar, ou **Novo** para começar do zero.
3. **Anime** — clique num osso (na lista ou direto no 3D), gire nos sliders,
   ande na linha do tempo, repita. Mexer num slider **já crava a chave** no
   instante atual; sem isso o ajuste sumiria ao avançar o tempo.
4. **Fechar loop** — copia a primeira chave de cada faixa para o fim. Sem isso a
   última pose não casa com a primeira e o ciclo dá um tranco.
5. **Exportar .tres** — grava em `assets/animations/`. No jogo: modo estilo (R)
   + estilo "Teste de Animação", e o clipe aparece no ciclo Z/X/C.

**Controles do 3D:** arrastar = orbitar · roda = zoom · clique num osso = selecionar.

### Preferir o Blender

Este editor continua sendo o caminho leve (Python puro, sem instalar nada) para
ajustar um clipe. Para autoria de verdade, o caminho agora é o Blender:

```bash
GODOT=/caminho/do/godot
# .res -> .glb (todos os clipes num arquivo, cada um vira uma Action)
$GODOT --headless --path . -s tools/exportar_para_blender.gd
#   ... edita em assets/blender/rig_base_completo.glb ...
# .glb -> .res
$GODOT --headless --path . -s tools/importar_do_blender.gd -- assets/blender/rig_base_completo.glb
```

A ida-e-volta é verificada por `tools/dev_tests/test_ida_e_volta_blender.gd`,
que está no `./validar.sh rapido`: **os 33 clipes voltam com a duração idêntica
e desvio ≤ 0,999°** — a tolerância da decimação que o importador aplica. O
transporte glTF em si é exato (0,000°).

---

## O que ele grava

Dois arquivos por clipe:

| Arquivo | Para quê |
|---|---|
| `tools/anim_editor/clips/<nome>.json` | formato de trabalho — reabre no editor |
| `assets/animations/<nome>.tres` | o que o jogo toca |

O `.tres` é `Animation` em **texto**, com faixas de caminho **hierárquico**
(`"Torso/Neck/Head:rotation"`) — o mesmo contrato que o baker do Mixamo produz
em binário. `Player.play_style_anim()` aceita os dois: procura `.res` primeiro,
depois `.tres`.

O caminho sai da hierarquia REAL do personagem carregado (`Rig.pais`), não de
uma tabela fixa: um modelo pode ter o nó `Neck` e outro não. O contrato canônico
está em `src/anim/RigContrato.gd`, e o `rig.py` o espelha em `PAI_CANONICO` /
`caminho()`.

> ⚠️ Até 2026-08-25 o caminho era plano (`"Head:rotation"`). Isso **tocava** no
> jogo — o `ProceduralAnimator` resolve o papel lendo a string — mas não
> resolvia como `NodePath`, e por isso o clipe não abria no dock de animação do
> Godot nem atravessava o exportador glTF. Era a porta fechada do Blender. Ver
> [`docs/AUDITORIA_ANIMACAO.md`](../../docs/AUDITORIA_ANIMACAO.md).

---

## Convenções (as mesmas do jogo)

Quebrar qualquer uma faz a animação sair torta no runtime.

- Frente é **−Z**.
- O membro pende em **−Y**; girar **+X** leva a ponta para a **frente**.
- **`Head` pende do `Neck`**, e o `Neck` do `Torso`. Declarar `Head` sob `Torso`
  (como este editor e o resto do projeto faziam) põe a rotação do pescoço DUAS
  VEZES na cabeça — até 64° de giro parasita.
- Rotação é Euler XYZ aplicado como `Rz · Ry · Rx` (igual ao `Basis` do Godot).
- A rotação editada é **offset sobre a pose de repouso**, não absoluta — mesma
  semântica do `ProceduralAnimator`.

### Personagem skinnado

Os modelos do Meshy (nami, ace, blackbeard, crocodile) têm esqueleto **Z-up**,
com a Armature girada −90° em X. O `export_rig.gd` converte tudo para o espaço
do personagem antes de gravar o JSON, então o editor sempre trabalha em Y-up.
Se um personagem aparecer **deitado ou espalhado pelo chão**, é essa conversão
que falhou — não a cinemática do editor.

---

## Arquivos

| Arquivo | Papel |
|---|---|
| `main.py` | janela, linha do tempo, ligação entre as partes |
| `rig.py` | os 13 papéis, cinemática direta, rig canônico |
| `clip.py` | keyframes, interpolação, exportação `.tres` |
| `viewport.py` | render 3D no Canvas (algoritmo do pintor, sem GPU) |
| `rigger.py` | janela de marcadores (o método do Meshy) |
| `markers.py` | os 7 tipos de marcador e a derivação dos 13 ossos |
| `mesh.py` | malha voxelizada do personagem |
| `abrir.sh` | lançador: acha o Python, prepara os dados, abre |
| `rigs/`, `clips/`, `meshes/` | dados gerados pelos exportadores do Godot |

> A malha vem só como **casca** (voxel de superfície) e é desenhada com **um
> retângulo por voxel**, não um cubo de 6 faces. Com ~2000 voxels, 6 faces cada
> daria 12000 itens de canvas e o tkinter engasgaria.
