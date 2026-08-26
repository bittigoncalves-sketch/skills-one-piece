# Estado atual do projeto — briefing para quem chega frio

Atualizado em 2026-08-26. **Todo agente lê este arquivo antes de tocar em
qualquer coisa.** Ele existe porque o [`AGENTES.md`](AGENTES.md) diz que o agente
começa frio: o que não estiver escrito, ele redescobre gastando tempo, ou inventa.

---

## 1. O que é o jogo

Arena PvP em Godot 4.6.3, cliente-servidor (ENet). Personagens voxel. Corpo a
corpo no botão esquerdo + quatro skills (Z/X/C/V) da Akuma no Mi equipada.

**A regra que explica quase todo número de balanceamento:** *quem mata é o
buraco, não o dano*. O mapa é uma grade de 20×20 células de 10 m com buracos
quadrados; cair abaixo de `Scoreboard.VOID_Y` (−40) mata. O combo inteiro tira
278 de uma vida de 2048.

---

## 2. Como rodar as coisas

As ferramentas **não estão todas no PATH**:

```bash
GODOT=/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64
BLENDER=/home/gabriel-bitti/opt/blender/blender     # 5.2 — também existe como `blender` no PATH

# prova de que o código COMPILA (a única que vale — ver §5)
"$GODOT" --headless --path . --script tools/dev_tests/test_compila.gd

# a bateria inteira: 34 passam, 0 falham, 1 pulado
./validar.sh rapido

# um teste só
"$GODOT" --headless --path . --script tools/dev_tests/test_arena.gd
```

### ⚠️ A PORTA 24565 NÃO É PARALELIZÁVEL

`GameFlow.start_singleplayer()` e `create_room()` hospedam numa porta **fixa**.
Dois processos que subam o jogo ao mesmo tempo — dois testes, dois agentes, uma
sonda e a bateria — dão:

```
Couldn't create an ENet host
```

e o teste reporta "a cena não subiu", que se confunde com defeito do jogo.

**Se você é um de vários agentes trabalhando em paralelo:** prefira verificação
que NÃO sobe o jogo (`test_compila.gd`, leitura de dado, medição de arquivo).
Quando precisar subir, espere e tente de novo; não conclua "quebrei alguma
coisa" na primeira falha de ENet.

---

## 3. Portões de medição que já existem

Este projeto não aceita "melhorou" sem número. O que existe hoje:

| ferramenta | responde |
|---|---|
| `tools/dev_tests/captura_visual.gd` | cinco cenas fixas + histograma (brilho médio, pico, % estourado, % preto) |
| `tools/dev_tests/medir_contorno.gd` | a silhueta tem contorno em 3 distâncias? |
| `tools/dev_tests/medir_banda.gd` | os funis usam o cel? a luz sai em degraus? a sombra tem borda dura? |
| `tools/dev_tests/medir_grade.gd` | a grade do chão cai na fronteira REAL da célula? |
| `tools/dev_tests/medir_frame_data.gd` | a vantagem no acerto é positiva? o combo encadeia? |
| `tools/dev_tests/test_frutas.gd` | cada fruta cria hitbox nos 4 slots? |

Todos precisam de tela (`DISPLAY=:1`) quando salvam PNG.

---

## 4. O que foi feito em 2026-08-25/26 (e que muda o chão de quem chega agora)

### Combate

- O combo M1 virou **frame data**: `startup`/`ativo`/`recuperacao` por golpe, em
  `src/combat/Melee.gd`. Trava de 0,40 s por golpe (era o clipe inteiro, 1,2-1,5 s).
- A FSM tem **três fases de ataque** + `Stunned`, em `src/player/hsm/`.
- Os quatro M1 foram **reautorados** (`tools/autorar_combo_m1.py`).
- ⚠️ **A vantagem no acerto é +0,55 s**, não os +0,21 s que o plano dizia. Sobram
  0,35 s de folga sobre o startup seguinte: **o alvo não tem janela para agir
  entre os golpes**. É o padrão do gênero, mas o contra-jogo (bloqueio) ainda
  não existe.

### Visual — as seis fases do [`PLANO_VISUAL.md`](PLANO_VISUAL.md) estão feitas

| | |
|---|---|
| Fase 1 | glow, névoa, tonemap, ambiente (`src/world/WorldEnv.gd`) |
| Fase 2 | contorno de silhueta (`src/fx/shaders/contorno.gdshader`) |
| Fase 3 | banda de luz (`src/fx/shaders/cel.gdshader` + `src/fx/Materiais.gd`) |
| Fase 4 | a grade do mapa desenhada no chão |
| Fase 5 | 28 sítios de emissão descartada → albedo HDR (`FxUtil.brilho`) |
| Fase 6 | HUD com identidade (`src/ui/Estilo.gd` + `BarraHud.gd`) |

**O alvo declarado é cel-shading anime (One Piece).** Qualquer coisa nova tem
que caber nisso: cor chapada, linha escura, sem gradiente especular.

---

## 5. Armadilhas que já custaram tempo NESTA base

Além das do [`AGENTES.md`](AGENTES.md):

### ⚠️ Erro de runtime dentro de `await` vira TIMEOUT, não falha

Num script `-s` com `await`, um erro de execução **aborta a função** — o `quit()`
nunca roda e o processo fica pendurado até o timeout. O relatório diz "lento" ou
"travou", e a causa é uma linha errada.

Já aconteceu **três vezes** nesta base:
- `_movement_locked_timer` (campo removido) → `test_morte_limpa_cast` dava timeout de 120 s;
- o mesmo campo → `test_gura_animacoes` dizia "não consegui amostrar o corpo";
- `bool(...)` — **não existe construtor `bool()` em GDScript** → `medir_grade.gd` pendurou.

Sintoma de teste pendurado: procure erro de script antes de procurar lentidão.

### ⚠️ `SHADING_MODE_UNSHADED` descarta a emissão

Material unshaded devolve **só o albedo**, limitado a 1,0 — e o limiar do glow é
1,15. `emission_enabled` + `emission_energy_multiplier` em material unshaded não
fazem **nada**. Para brilhar, use `FxUtil.brilho(cor, energia)`, que põe o brilho
no albedo. Medido: unshaded+emissão dá halo idêntico a unshaded sem emissão nenhuma.

### ⚠️ `CanvasLayer` não é `CanvasItem`

Esconder a HUD com `if n is CanvasItem` não esconde nada — `Hud` estende
`CanvasLayer`. E shader de `canvas_item` **não enxerga profundidade**: contorno e
qualquer coisa que leia `DEPTH_TEXTURE` tem que ser shader `spatial`.

### ⚠️ `set_glow_level()` é base ZERO

Os nomes no inspetor são `glow_levels/1`..`/7`; o método é 0..6. Escrever 7
estoura com um erro que some no meio do log.

### ⚠️ `art_src/` tem `.gdignore` — não tire

O `.blend` do personagem mora ali. Sem o `.gdignore`, o Godot tenta importá-lo,
exige o Blender configurado no editor e **derruba a importação do projeto
inteiro** em headless, com a causa apontando para uma pasta que ninguém abre.

### ⚠️ Contagem por proximidade de texto não é contagem

"32 sítios" virou 28 ao contar **por função** em vez de por janela de ±25 linhas
com nomes de variável do arquivo todo. Duas funções que chamam o material de `m`
se confundem. Vale para qualquer varredura por `grep`.

---

## 6. Onde as coisas moram

```
Player.gd                    o jogador (2.300+ linhas) — ponto de contato de quase tudo
src/player/hsm/              a FSM de combate (Idle, AttackStartup/Active/Recovery, Stunned, Dashing)
src/combat/Melee.gd          frame data do combo, e a tabela de dano espelha Balance.gd
src/combat/Balance.gd        TODO número de dano do jogo
src/effects/                 as frutas (um arquivo por fruta) + DamageZone
src/fx/                      estilo de render: contorno, cel, ScreenFX, Materiais
src/world/                   MapBuilder (o mapa), WorldEnv (ar e luz), TreeScatter
src/ui/                      HUD — Estilo.gd manda na aparência
src/anim/                    rig, poses, ProceduralAnimator, SkeletonDriver
tools/dev_tests/             sondas e testes
docs/                        planos, erros.md (causa raiz de tudo), este arquivo
```

---

## 7. Documentos que valem ler antes de decidir

| doc | quando |
|---|---|
| [`erros.md`](erros.md) | **sempre.** Causa raiz de todo defeito já achado — evita reabrir |
| [`AGENTES.md`](AGENTES.md) | como o trabalho é dividido e o que um prompt precisa ter |
| [`PLANO_VISUAL.md`](PLANO_VISUAL.md) | o alvo de estilo e o catálogo de sugestões com custo |
| [`PLANO_COMBATE_BATTLEGROUNDS.md`](PLANO_COMBATE_BATTLEGROUNDS.md) | frame data, FSM, os bugs de rede B1-B6 |
| [`ESQUELETO.md`](ESQUELETO.md) | 13 papéis, o que o rig NÃO tem, os 11 clipes tombados |
| [`FILA_DE_TAREFAS.md`](FILA_DE_TAREFAS.md) | o que está pedido e não feito |
| [`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md) | defeitos achados e **não** corrigidos |
| [`frutas/README.md`](frutas/README.md) | como um golpe vai do dedo à hitbox, e o teto de dano |
