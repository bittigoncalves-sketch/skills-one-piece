# Estado atual do projeto — briefing para quem chega frio

Atualizado em 2026-09-12. **Todo agente lê este arquivo antes de tocar em
qualquer coisa.** Ele existe porque o [`AGENTES.md`](AGENTES.md) diz que o agente
começa frio: o que não estiver escrito, ele redescobre gastando tempo, ou inventa.


**Modo História (14/09/2026)** — etapa 1 feita: baseplate lida de
`mapas/historia/baseplate.json` e jogador Civil (sem combate, dash, pulo duplo nem
técnicas). Etapa 2 (v1) feita: **editor de mapa** no menu (card JOGAR → ✏️ EDITOR),
estilo Roblox Studio, com desfazer, Explorer, seleção múltipla, quatro formas e
"Testar" com o jogador real; loja de .glb com categorias; Ctrl+G agrupa/separa.
**16/09/2026:** câmera de 3ª pessoa passou de 6 m para **4 m** e desceu para a **altura da cabeça**
(pivô `CAM_HEIGHT_TPS` 2,2 → 1,0; arena e Modo História), e o
atalho da área de trabalho voltou a abrir `jogar.sh` — o visual do boss Buggy só por `./jogar_buggy.sh`.
**Inimigos (16/09/2026):** peça cujo modelo está na categoria "inimigos" da loja tem vida 250,
pisca vermelho, some ao morrer e dá 5–20 XP ([MODO_HISTORIA.md §6a](MODO_HISTORIA.md)).
**Status (tecla M, 16/09/2026):** XP, níveis com barreira no 7, pontos, vida, energia,
skills e ouro do PDF, salvos em `user://historia/progresso.json`. Guia: [MODO_HISTORIA.md](MODO_HISTORIA.md).
Bateria em 16/09/2026, depois dos inimigos (`./validar.sh rapido`): **89 passam, 8 falham, 1 pulado** —
exatamente as 8 abaixo. (Mais cedo no mesmo dia foram 87/9/1: `test_sala_publica` depende do
ROTEADOR, UPnP "código 27", e voltou a passar sem mudança de rede.) Em 14/09 foram 84 / 8 / 1: As 8:
`test_balance`, `test_compila`, `test_corte_horizontal`, `test_mera_z_saque`,
`test_ope_animacoes`, `test_studio_playback`, `test_trava_fruta_dano` (as mesmas de
13/09) e `test_bara_combat` — nova, item 58 da lista de correções, isolada: falha
igual com as travas do Modo História desfeitas.

Atualização Yoru (09/09/2026): modo 3 com dois M1 e Z/X/C/V, rig base com
pega dupla, asset novo e servidor validando ações. Ver [implementação e
validação](YORU_IMPLEMENTACAO.md). `./jogar_yoru.sh` abre a arena equipada.

**Limpeza de 2026-09-12** — 77 arquivos saíram do repositório. O que mudou para
quem chega agora:

- **A raiz não tem mais scripts soltos de depuração.** Os 23 `test_*.gd`,
  `check.gd`, `create_arena.gd` e afins eram de sessões de caça a bug de agosto
  e ninguém chamava. Teste de verdade mora em `tools/dev_tests/` — é de lá que o
  `validar.sh` descobre a bateria, por glob `test_*.gd`. **Três sondas continuam
  na raiz de propósito** (`test_peer.gd`, `test_singleplayer.gd`,
  `test_spawner.gd`): elas não afirmam nada, e em `dev_tests/` o glob as rodaria
  como teste que "passa" sem verificar coisa alguma. O cabeçalho de cada uma
  explica isso.
- **A pasta `data/` não existe mais.** Os três JSON eram dados mortos — nenhum
  `.gd` carregava `res://data/`. A fonte de verdade está em `SkillSystem.gd`
  (frutas), `Balance.ESTILOS` (estilos) e `CharacterBuilder.gd` (personagens).
- **`DOCUMENTACAO.md` (raiz) foi removido.** Era uma segunda visão geral, de
  2026-08-02, divergente do `README.md` — e ainda mandava apertar `R` para trocar
  de modo de combate, gesto que morreu em 2026-09-06. Panorama e **controles**
  agora estão no [`README.md`](../README.md); as regras de quem escreve código,
  no [`GUIA_DO_PROJETO.md`](GUIA_DO_PROJETO.md).
- **Os `MUDANCAS_*.md` foram para [`historico/`](historico/).** Nada apagado.
- **`SkillsOnePiece.desktop` estava quebrado** desde agosto, apontando para
  `/home/administrador/`. Consertado. Ver [`erros.md`](erros.md).

Os `.blend` e o `tools/anim_editor/studio/` **não** foram tocados: são trabalho
seu em andamento, não rastreado pelo git.

### Débito da bateria em 2026-09-12 — 70 passam, 11 falham

As 11 falhas são **anteriores à limpeza** e nenhuma vem dela: a limpeza só apagou
arquivos que ninguém referenciava e editou `.md` — **nenhum `.gd` de jogo foi
modificado**. Antes de culpar uma mudança sua por qualquer uma delas, confira se
já está nesta lista.

| Teste | Origem da falha |
|---|---|
| `test_compila`, `test_studio_playback` | `tools/anim_editor/studio/` — trabalho **em andamento, não rastreado**: `eased_anim`/`eased_track` sem tipo inferível e um `preload("res://rig_scene.gd")` que não existe |
| `test_balance` | `pika_pika/Z` alcança 98 de um teto de 200 — detectado em **2026-09-06**, registrado em [`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md) |
| `test_corte_horizontal` | as 3 reprovações do caminho antigo da espada, com os números já documentados em [`erros.md`](erros.md): mão esquerda a 0,84 m do cabo, fio a 37,4°, tronco girando 42,2° |
| `test_buki_buki`, `test_mera_z_saque`, `test_morte_limpa_cast`, `test_ope_animacoes`, `test_trava_fruta_dano`, `net_mp_probe`, `traco_locomocao` | débito que já existia na árvore suja — ver [`LISTA_DE_CORRECOES.md`](LISTA_DE_CORRECOES.md) |

⚠️ A árvore tem trabalho seu não commitado (`Player.gd` entre outros). Esse
número de falhas é o da **árvore suja**, não o de um `main` limpo.

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

# a bateria inteira — em 2026-09-12: 70 passam, 11 falham (ver §débito abaixo)
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
| [`NUMEROS_MEDIDOS.md`](NUMEROS_MEDIDOS.md) | **antes de repetir uma medição.** O índice de tudo que já foi medido nesta base |
| [`MOVIMENTO.md`](MOVIMENTO.md) | mexer em locomoção, parkour, esquiva ou nas travas de movimento |
| [`RODADA_E_PLACAR.md`](RODADA_E_PLACAR.md) | rodada, kills, morte, respawn — e o padrão de mandar RPC para a cópia certa |
| [`ESTILOS_DE_LUTA.md`](ESTILOS_DE_LUTA.md) | o **outro** modo de combate (tecla R), e por que ele custa 60 s |

## Árvores em voxel (2026-11-04)
- **Arena:** `TreeAndFruitGenerator.create_tree_3d` usa `ArvoreVoxel.malha(forma)` — 6 formas (carvalho, pinheiro, palmeira, acácia, baobá, salgueiro), uma fixa por fruta (`forma_da_arvore`); cores por fruta preservadas.
- **Modo História:** 58 `.glb` de árvore/toco/bosque em `mapas/modelos/` regerados por `tools/trocar_arvores_por_voxel.gd` (cores naturais por família). Só o visual mudou: caixa, `Colisao*`, `Fruta_*` e catálogo (sha/triângulos) foram mantidos; bosques `trees`/`pine_trees` ganharam colisão em partes nova.
- **Validação:** `tools/dev_tests/test_arvores_voxel_modelos.gd` (58 modelos) e `test_arvore_voxel.gd` (arena).
- **Reverter:** originais e catálogo em `art_src/backups/arvores_antes_voxel_2026-11-04/` (copiar de volta + `--import`).
- **Gatilho:** `art_src/natureza/*.glb` são as fontes antigas; se algum script copiá-las para `mapas/modelos/`, rode a ferramenta de novo.

## Correção de faces + animais em voxel (2026-11-04)
- **Árvores "transparentes":** o Godot trata a ordem HORÁRIA como face frontal e o gerador emitia a anti-horária (as faces de perto sumiam). Corrigido em `ArvoreVoxel._face`; `ArvoreVoxel.faces_invertidas` guarda isso na ferramenta e nos testes.
- **Animais:** `tools/voxelizar_animais.gd` grava `mapas/modelos/<id>.voxel.scn` (32 modelos: os 30 com ficha de animal + 2 cavalos; bestas do mar ficam de fora). `BibliotecaDeModelos.instanciar` troca só a malha (`_aplicar_voxel`): esqueleto, Skin, AnimationPlayer e clipes são os do .glb. Cada cubo leva a cor da textura (cor por vértice) e o osso dominante. Reverter = apagar os `*.voxel.scn`.
- **Validação:** `tools/dev_tests/test_animais_voxel.gd` (32 animais).
- **Conhecido:** rigs com malha em T-pose (gorila, harpia/águia) mostram cubos inclinados no repouso sem animação; em animação ficam conectados. `test_nado_montaria` trava/falha ("invocar caranguejo") com e sem voxel.
- **Gatilho:** peixes (`pesca`), `piranha/shark/tentacle/worm` e `mordu` NÃO foram voxelizados (escopo a confirmar); para incluir, estender a seleção em `voxelizar_animais.gd`.
