# PROJECT_CONTEXT — SKILLS ONE PIECE

> **Para agentes de IA** (Claude, Codex, Gemini) começando uma tarefa aqui. Denso de
> propósito: caminhos, contratos, armadilhas e onde ler mais. Versão para pessoas:
> [`docs/contexto/VISAO_GERAL.md`](docs/contexto/VISAO_GERAL.md).
> Escrito em 21/09/2026. Números e listas de arquivos que mudam **não** ficam aqui: saem do
> índice gerado ([`docs/contexto/INDICE.md`](docs/contexto/INDICE.md)). Manutenção: §13.

## 1. O que é

Jogo de ação 3D em **Godot 4.6.3 / GDScript**, cliente-servidor com ENet e
**servidor-autoritário**. Três modos, um só código de jogador:

- **Arena PvP** (`Main.gd`): frutas do diabo (Z/X/C/V), estilos de luta, espada, parkour.
  Quem mata é a QUEDA nos buracos, não o desgaste de vida.
- **Modo História** (`src/historia/ModoHistoria.gd`): campanha com progressão do PDF
  (`docs/references/modo_historia/`), combate corpo a corpo direcional estilo Chivalry 2.
- **Editor de mapa** (`src/editor_mapa/EditorDeMapa.gd`): estilo Roblox Studio; edita o
  mesmo arquivo que o Modo História lê.

Singleplayer roda o MESMO código do multiplayer, com servidor local na porta **24565**.

## 2. Ordem de leitura antes de agir

1. Este arquivo (regras e mapa).
2. O contexto da área: `docs/contexto/agentes/<area>.md` (tabela na §5).
3. Busca no índice para achar o código exato:
   `python3 tools/contexto/indice.py buscar "termos" [--area X] [--docs]`.
4. O documento dono do assunto (cada contexto de área aponta qual).
5. [`docs/GUIA_DO_PROJETO.md`](docs/GUIA_DO_PROJETO.md) e
   [`docs/guia/ARMADILHAS.md`](docs/guia/ARMADILHAS.md) antes de escrever GDScript.
6. [`docs/erros.md`](docs/erros.md) (busque com `--docs`): a causa raiz de todo defeito já achado.

## 3. Regras que não se negociam (detalhe no GUIA)

1. **`class_name` novo → `./checar_cache.sh`** (ou `--editor --quit`). Sem isso o jogo abre em
   TELA CINZA, sem erro visível. Os `jogar*.sh` já chamam.
2. **Compilar se prova com** `godot --headless --path . --script tools/dev_tests/test_compila.gd`
   — `--editor --quit` não prova nada.
3. **`add_child` antes de posicionar** (`global_position`/`look_at`). Exceção segura: `position`
   local com o pai na origem.
4. **Dano é do SERVIDOR.** VFX roda em todos; dano só no servidor. Vida viaja por RPC, nunca por
   `MultiplayerSynchronizer` (a autoridade do corpo é o cliente).
5. **Teto de 900 linhas por script** ([`docs/LIMITE_DE_TAMANHO.md`](docs/LIMITE_DE_TAMANHO.md)).
   Adiar a divisão exige GATILHO declarado no topo do arquivo.
6. **Validar com número**, não adjetivo. Teste bom tem controle que sabe reprovar (sabotagem).
7. **Dono decide feel e escopo**: pedido ambíguo em coisa cara volta como pergunta. Bug fora do
   escopo vira item em [`docs/LISTA_DE_CORRECOES.md`](docs/LISTA_DE_CORRECOES.md), não conserto por conta.
8. **Causa de erro vai para `docs/erros.md`** na mesma tarefa (sintoma, causa, evidência, correção,
   como detectar).

## 4. Ambiente

| o quê | onde / como |
|---|---|
| Godot (fora do PATH) | `/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64`, ou `./find_godot.sh` |
| Blender 5.2 (pipeline de arte) | `/home/gabriel-bitti/opt/blender/blender`; fontes em `art_src/` (tem `.gdignore`) |
| jogar | `./jogar.sh` (arena) · `./jogar_historia.sh` · `./jogar_<fruta>.sh` · `./jogar_buggy.sh` · `./servidor.sh` |
| bateria | `./validar.sh rapido` (em série: todos disputam a porta 24565; `SOP_PORTA` isola agentes em paralelo) |
| teste único | `godot --headless --path . --script tools/dev_tests/test_X.gd` |
| testes com tela | `test_melee_trava`, `test_segurar_ataque`, `test_toque`, `test_combate_historia_tela`, traço de locomoção — **capturam o mouse do desktop real**; pedir antes de rodar |
| pasta fora do jogo | precisa de `.gdignore` (senão o Godot importa: `art_src/`, `.claude/`, `multimodal/`, `tools/contexto/`) |
| agentes especializados | `~/.claude/agents/` (globais; gerados por `tools/agentes/gerar_agentes_*.py`). `.claude/agents/` do projeto NÃO é lido: a sessão abre em `~/dev` |

## 5. Áreas e seus contextos

| área | código principal | contexto |
|---|---|---|
| Núcleo e jogador | `Player.gd`, `src/player/`, `autoload/GameFlow.gd`, `src/match/`, `src/entities/` | [agentes](docs/contexto/agentes/nucleo.md) · [pessoas](docs/contexto/pessoas/nucleo.md) |
| Combate da arena | `src/combat/` (fora `direcional/`), `src/items/` | [agentes](docs/contexto/agentes/combate.md) · [pessoas](docs/contexto/pessoas/combate.md) |
| Frutas e técnicas | `src/effects/`, `SkillSystem.gd`, `FruitPassiveSystem.gd` | [agentes](docs/contexto/agentes/frutas.md) · [pessoas](docs/contexto/pessoas/frutas.md) |
| Personagem, rig e animação | `src/anim/`, `src/customizacao/`, `CharacterBuilder.gd` | [agentes](docs/contexto/agentes/personagem.md) · [pessoas](docs/contexto/pessoas/personagem.md) |
| Modo História | `src/historia/`, `src/combat/direcional/` | [agentes](docs/contexto/agentes/historia.md) · [pessoas](docs/contexto/pessoas/historia.md) |
| Mundo e editor de mapa | `src/world/`, `src/editor_mapa/`, `mapas/` | [agentes](docs/contexto/agentes/mundo.md) · [pessoas](docs/contexto/pessoas/mundo.md) |
| Chefes e IA | `src/bosses/` | [agentes](docs/contexto/agentes/bosses.md) · [pessoas](docs/contexto/pessoas/bosses.md) |
| Rede e multiplayer | `network/`, RPCs do `Player.gd` | [agentes](docs/contexto/agentes/rede.md) · [pessoas](docs/contexto/pessoas/rede.md) |
| Interface e HUD | `src/ui/` | [agentes](docs/contexto/agentes/interface.md) · [pessoas](docs/contexto/pessoas/interface.md) |
| Visual, VFX e áudio | `src/fx/`, `src/audio/`, `VFX/` | [agentes](docs/contexto/agentes/visual.md) · [pessoas](docs/contexto/pessoas/visual.md) |
| Ferramentas, testes e pipeline | `tools/`, `validar.sh`, `multimodal/` | [agentes](docs/contexto/agentes/ferramentas.md) · [pessoas](docs/contexto/pessoas/ferramentas.md) |

Arquivo em mais de uma área (ex.: `src/effects/DamageZone.gd` é infraestrutura de combate, mas
mora com as frutas): vale a pasta. O mapa gerado diz a área de cada arquivo.

## 6. Arquitetura em uma página

- **Player = casca.** `Player.gd` liga entrada, locomoção, câmera, combate, rede e apresentação;
  a lógica foi partida em componentes (`src/player/`: `CameraRig`, `PlayerRig`, `MoveFrame`,
  `ParkourController`, `DashController`, `MeleeController`, `HealthController`, `CastController`…).
  Plano e razões: [`docs/ARQUITETURA_PLAYER.md`](docs/ARQUITETURA_PLAYER.md).
- **Locomoção:** só a etapa de locomoção escreve `velocity`
  ([`docs/MOVIMENTO.md`](docs/MOVIMENTO.md) §1). O corpo sempre encara a mira.
- **FSM de combate:** `src/player/hsm/` (Idle, AttackStartup/Active/Recovery, Stunned, Dashing).
  Todo dano recebido leva o jogador a `Stunned` (`Player._feedback_de_dano`).
- **Dano:** golpe descreve-se em `DamageSpec` → funil único `CombatResolver.aplicar` →
  `take_damage` do alvo. Hitbox de área: `DamageZone` (sai cedo fora do servidor). TODO número de
  dano mora em `src/combat/Balance.gd`.
- **Fruta:** tecla → `CastController` decide → RPC ao servidor → `_net_play_cast` em todos →
  `<Fruta>FX.cast(...)`. `_fire_skill` engole erro: golpe pode "rodar" sem hitbox.
- **Rig único de 13 papéis** (`Torso, Neck, Head, UpperArm_L/R, ForeArm_L/R, Thigh_L/R, Shin_L/R,
  Foot_L/R`); nos modelos skinados o `SkeletonDriver` cria proxies com os mesmos nomes.
- **HUD por modo** (`Hud` na arena, `HistoriaHud` na história), achada pelo grupo `"hud"` e
  chamada sempre com `has_method`.
- **Rede:** autoloads `ServerManager`, `ClientManager`, `FruitNet`, `GameFlow` (fachada dos modos).
- **Modo História:** combate direcional num executor próprio (`ExecutorCorpoACorpo`) que jogador e
  IA usam igual; números em `src/combat/direcional/estilos/*.tres`.

## 7. Convenções

- **FRENTE = −Z**; direita anatômica = **+X** no espaço local do modelo. Medir pose em espaço
  LOCAL (o mundo tem escala não uniforme — armadilha 8).
- Comentário explica o **porquê**, com data e origem quando é decisão ("decisão do dono, 16/09").
  Adiamento declara gatilho. Fonte única: número duplicado vira bug.
- Código novo usa nomes em **português** (`executor_corpo_a_corpo.gd`, `pedir_ataque`); código
  antigo mistura inglês (`Player.gd`, `take_damage`). Não renomeie o antigo por estética.
- Sem `SceneTreeTimer` para regra de jogo (não enxerga cancelamento — item 59 da lista); use
  relógio próprio e identidade de ação.
- Sem `Engine.time_scale` para hitstop (desacelera o mundo todo — item 60); hitstop é por ator.
- `InputMap` vazio por convenção; exceção única: `combate_atacar`/`combate_defender` (história).

## 8. Estado em 21/09/2026

- **Git:** ramo `pika-espada-modos-2026-09-06`, último commit **08/09**, ~555 entradas sem
  commit (várias frentes). Ponto de retorno por frente: snapshots + patches em
  `~/dev/sop-snapshots/` (decisão do dono, 16/09). Não commitar sem pedido.
- **Bateria headless:** 87 passam / 8 falham, e as 8 são débito conhecido: `test_balance`,
  `test_bara_combat`, `test_compila` (6 scripts de `tools/anim_editor/studio/`),
  `test_corte_horizontal`, `test_mera_z_saque`, `test_ope_animacoes`, `test_studio_playback`,
  `test_trava_fruta_dano`. Falha fora dessa lista é regressão sua até prova em contrário.
- **`Player.gd` tem ~4.550 linhas**, contra 1.498 ao fim da partição: o teto de 900 está furado e
  a extração continua pendente ([`docs/PLANO_COMBATE_HISTORIA.md`](docs/PLANO_COMBATE_HISTORIA.md) A1).
- **Modo História:** Fases 0–6 e 7a do combate direcional prontas (boxe); faltam o resto da
  Fase 7 e a Fase 8. Espada inicial equipável pelo N → ARMAS adicionada em 06/10/2026
  (mesmo executor direcional; `docs/ESPADA_HISTORIA_CHECKPOINT.md`). Inimigos do mapa ainda são estáticos; o boneco de duelo sai da
  janela M → TESTE. Barras de vida/energia na tela desde 21/09.
- **Socos por clique (07/10):** boxe alterna jab/ganchos/overhand sem gesto; janela
  de 1,2 s após o golpe. 58 contratos e 24 checks com tela aprovados. Dados em
  `src/combat/direcional/estilos/boxe.tres`; `docs/SEQUENCIA_SOCOS_CHECKPOINT.md`.
- **Bestas do mar (07/10):** `src/historia/bestas_mar/`; três espécies pacíficas com
  rotina na praia/água e reação ao dano; Sea Serpent hostil com bolhas. Nove clipes,
  integração dos modelos da loja; 64/64 testes headless e com tela. Detalhes:
  `docs/BESTAS_MAR_CHECKPOINT.md`.
- **Boss Buggy:** onda 1 do plano de IA concluída (13/09); ondas seguintes com agentes `boss-*`.
- **Z da espada da história (06/10):** giro de corpo/lâmina até primeiro inimigo,
  knockback e imunidade durante o giro; novo Z cancela, sem timeout.
  `src/historia/equipamentos/giro_da_espada.gd`, `test_giro_espada_historia.gd`.
- **Yoru (espada):** etapas do `docs/PLANO_YORU.md` com agentes `yoru-*`; item 54 (replicação).
- **Docs velhos conhecidos:** `docs/ESTADO_ATUAL.md` (12/09) ainda diz Player com 2.300 linhas;
  `mera_mera.md` e `gomu_gomu.md` têm tabelas de dano desatualizadas (ver `docs/frutas/README.md`).

## 9. Validação mínima por tipo de mudança

| mudou… | rode |
|---|---|
| qualquer `.gd` | `test_compila` + o teste da área (contexto da área lista) |
| `class_name` novo | `./checar_cache.sh` antes de qualquer teste |
| golpe de fruta | `test_frutas` (lento, ~8 min) do slot + página em `docs/frutas/` |
| nó de VFX | prova de que morre (critério do `test_gomu_leak`) |
| locomoção/física | traço de locomoção idêntico (com tela — pedir) |
| rede | sondas `net_*_probe` (dois processos) via `./validar.sh mp` |
| entrega | `./validar.sh rapido` e comparar com as 8 falhas conhecidas |

## 10. Onde está cada resposta

| pergunta | documento |
|---|---|
| regras de quem escreve código | [`docs/GUIA_DO_PROJETO.md`](docs/GUIA_DO_PROJETO.md) + [`docs/guia/`](docs/guia/ARMADILHAS.md) |
| panorama e controles do jogo | [`README.md`](README.md) |
| por que tal bug aconteceu | [`docs/erros.md`](docs/erros.md) |
| bugs achados e não corrigidos | [`docs/LISTA_DE_CORRECOES.md`](docs/LISTA_DE_CORRECOES.md) |
| o que já foi medido | [`docs/NUMEROS_MEDIDOS.md`](docs/NUMEROS_MEDIDOS.md) |
| o que está pedido e não feito | [`docs/FILA_DE_TAREFAS.md`](docs/FILA_DE_TAREFAS.md) |
| como dividir trabalho entre agentes | [`docs/AGENTES.md`](docs/AGENTES.md) |
| o que a bateria cobre | [`docs/VALIDACAO.md`](docs/VALIDACAO.md) |
| histórico de decisões | `docs/historico/`, `docs/PEDIDO_*.md` — nada ali é apagado |

## 11. Índice vetorial (onde está o código)

```bash
python3 tools/contexto/indice.py buscar "aparo riposte"            # código, 10 resultados
python3 tools/contexto/indice.py buscar "vida hud" --area interface -n 5
python3 tools/contexto/indice.py buscar "tela cinza" --docs         # só documentos
python3 tools/contexto/indice.py buscar "boneco" --testes           # inclui tools/dev_tests
```

Saída: `nota  arquivo:linha_inicial-linha_final  símbolo  [área ★relevância]`. TF-IDF por trecho
(função do GDScript, seção do Markdown), sem dependências; refaz sozinho quando algo muda (~1,5 s).
Acha por PALAVRA, não por sentido: busque sinônimos ("guarda defesa bloqueio"). Relevância ★1–5 =
fan-in + tamanho + testes + entrada; fórmula no topo de `tools/contexto/indice.py` e do mapa.
**★ alto com 0 testes = risco** (muitos dependem, nada vigia).

## 12. Armadilhas mais caras (lista completa no GUIA)

- Erro de runtime dentro de `await` num teste vira TIMEOUT, não falha.
- Objeto liberado compara igual a `null`; use `is_instance_valid`.
- `Area3D` detecta uma vez por quadro: projétil rápido atravessa — varra o caminho.
- Teste `-s` que cita (`preload`/tipo) uma classe que cita `Player` compila o Player antes dos
  autoloads e o envenena no cache: em teste, `load()` em tempo de execução.
- Headless não captura mouse: clique real só se testa com tela.
- `.tres` omite campo igual ao padrão: padrões de `Resource` neutros, número real explícito.
- Sonda que não imita o jogo mede o vazio: aqueça o corpo e use o caminho real de entrada.
- Em osso de rig, escreva **rotação local**; `global_basis = R * from_scale(global_basis.get_scale())`
  acumula escala (o animador guarda a escala local) — os pés do boneco cresceram sem parar (21/09).

## 13. Como manter este arquivo

- É curto de propósito (alvo 150–300 linhas). Detalhe de área vai no contexto da área; detalhe de
  sistema, no doc dono. Não copie tabelas que já têm dono: aponte.
- **Atualize a §8** quando a bateria mudar de patamar, um modo ganhar etapa ou o git mudar de
  estado (commit/merge). **Atualize a §5** quando surgir pasta nova em `src/`.
- `python3 tools/contexto/indice.py verificar` acusa caminho citado que não existe mais e contexto
  de área mais velho que o código dela. Rode ao fim de tarefa que criou/moveu arquivo.
- `python3 tools/contexto/indice.py construir` regenera o índice e o mapa `docs/contexto/INDICE.md`
  (a busca faz o mesmo sozinha quando algum arquivo ficou mais novo que o índice).
