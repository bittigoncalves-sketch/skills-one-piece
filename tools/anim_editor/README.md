# Editor de Animação — Skills One Piece

Editor de keyframes para o rig de 13 papéis do jogo. Carrega o personagem,
mostra o esqueleto em 3D, e grava direto em `assets/animations/<nome>.tres`,
que o jogo carrega igual a um `.res`.

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
```

Rode de novo sempre que mexer num personagem ou assar animação nova.

---

## Fluxo

1. **Personagem** — escolha na lista. Se ele já tem ossos, eles aparecem.
   `<rig novo>` ou o botão **Criar ossos** gera os 13 papéis canônicos do zero,
   para um personagem que ainda não tem rig.
2. **Clipe** — abra um dos 28 do Mixamo para ajustar, ou **Novo** para começar do zero.
3. **Anime** — clique num osso (na lista ou direto no 3D), gire nos sliders,
   ande na linha do tempo, repita. Mexer num slider **já crava a chave** no
   instante atual; sem isso o ajuste sumiria ao avançar o tempo.
4. **Fechar loop** — copia a primeira chave de cada faixa para o fim. Sem isso a
   última pose não casa com a primeira e o ciclo dá um tranco.
5. **Exportar .tres** — grava em `assets/animations/`. No jogo: modo estilo (R)
   + estilo "Teste de Animação", e o clipe aparece no ciclo Z/X/C.

**Controles do 3D:** arrastar = orbitar · roda = zoom · clique num osso = selecionar.

---

## O que ele grava

Dois arquivos por clipe:

| Arquivo | Para quê |
|---|---|
| `tools/anim_editor/clips/<nome>.json` | formato de trabalho — reabre no editor |
| `assets/animations/<nome>.tres` | o que o jogo toca |

O `.tres` é `Animation` em **texto**, com faixas `"<Papel>:rotation"` — o mesmo
contrato que o baker do Mixamo produz em binário. `Player.play_style_anim()`
aceita os dois: procura `.res` primeiro, depois `.tres`.

---

## Convenções (as mesmas do jogo)

Quebrar qualquer uma faz a animação sair torta no runtime.

- Frente é **−Z**.
- O membro pende em **−Y**; girar **+X** leva a ponta para a **frente**.
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
| `rig.py` | os 13 papéis, cinemática direta, criação de rig do zero |
| `clip.py` | keyframes, interpolação, exportação `.tres` |
| `viewport.py` | render 3D no Canvas (algoritmo do pintor, sem GPU) |
| `rigs/`, `clips/` | dados gerados pelos exportadores do Godot |
