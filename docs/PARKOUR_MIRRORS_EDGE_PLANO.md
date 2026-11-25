# Reformulação da movimentação — plano e estado (02/10/2026)

Pedido do dono (especificação colada em 02/10/2026): movimentação inspirada principalmente
em **Mirror's Edge Catalyst** (complementos: Assassin's Creed Unity na escalada, Dying Light
no peso, Titanfall 2 na velocidade do wall run). Itens: 1 wall run com gravidade normal,
2 escalada frontal até a borda sem teleporte, 3 transições encadeadas preservando o
momentum, 4 giro ao inverter direção, 5 inclinação nas curvas, 6 arrancada, 7 frenagem.
Objetivo: `Corrida → curva → salto → Wall Run → salto → escalada → subir borda → corrida`
como um movimento só.

## Decisões do dono (02/10/2026)

- **Frente do corpo:** segue o MOVIMENTO correndo livre (giro, frenagem, inclinação); vira
  rápido para a MIRA ao atacar, usar skill ou mirar, e fica assim um instante. Substitui a
  regra de 27/08 "frente segue a mira" (docs/MOVIMENTO.md) fora do combate.
- **"Andar na superfície"** (parede vira chão, gasta energia — inspirado em Naruto,
  27/08): **removido de vez**, junto com a energia de parede.
- **Escalável:** campo por modelo na **loja** (como `atravessavel`); construções, rochas e
  muros marcados de início; relevo do terreno não escala. Wall run vale em qualquer parede
  vertical.
- **Animação:** classificação pedida e entregue (captura profissional 9 > Mixamo 7 >
  keyframe por mim 6 > vídeo→IA 5). O dono **baixou clipes do Mixamo** e pediu para usá-los.
  Por cima deles, camada em tempo real (IK de mãos/pés na parede/borda, inclinação,
  ajuste à altura da borda) no `ProceduralAnimator` — o IK do Godot 4.6 só serve a
  `Skeleton3D` e o personagem voxel é rig por nós.

- **Clipes que faltam** (agarrar/pendurar, ciclo de escalada, saltar da parede, virada
  correndo 180°, arrancada de pé): **eu faço por keyframe** no Blender, no estilo dos
  clipes Mixamo.
- **Controles (estilo Mirror's Edge):** Shift corre. Espaço correndo rente a parede lateral
  (15–60°) = wall run; Espaço no wall run = salta para longe. Saltar de frente contra
  parede escalável = agarra sozinho; W/S sobe/desce, A/D lado; Espaço = salta para trás;
  no topo com W sobe a borda sozinho. Ctrl solta da parede.
- **Ordem:** fatias 0 → 1 → 2 → 3 → 4, como na tabela.

## O que existe hoje (medido no código, 02/10/2026)

- `src/player/parkour_controller.gd` (555 linhas): wall run com gravidade a 12 % (piso
  −1,5 m/s); "andar na superfície" (`_na_parede`, energia); escalada antiga desligada;
  vault, salto longo, pouso de precisão, geppo.
- `Player.gd`: `SPEED` 4,2 m/s, sprint ×1,5 (6,3), `JUMP_VELOCITY` 16; frente segue a mira
  (`VELOCIDADE_FACING` 26). Sem arrancada, frenagem nem giro.
- Animação: procedural (`src/anim/ProceduralAnimator.gd`, 1.475 linhas) + clipes Mixamo
  assados (`tools/fbx_to_glb.py` → `tools/bake_mixamo.gd`), que hoje guardam SÓ a rotação
  de 13 papéis — sem quadril, mãos nem deslocamento do corpo.

## Clipes novos (`~/Downloads/Assets/animações importadas do mixamo`, 02/10 19:45)

Medidos no Blender (deslocamento do quadril; frente = −Y):

| clipe | duração | deslocamento | uso |
|---|---|---|---|
| Wall Run | 0,97 s | 1,9 m de lado, 2,3 m à frente, quadril até 1,96 m (pés na parede) | wall run (espelhado p/ o outro lado) |
| Diagonal Wall Run | 1,17 s | 1,7 + 1,7 m, sobe 1,13 m | wall run subindo |
| Climbing Up Wall | 2,03 s | sobe 1,26 m (de pé, mãos no topo) | subir a borda (com ajuste à altura) |
| Run To Stop (×2) | 0,93 s | freia em 0,81 m | frenagem |
| Sprint / running / walking | 0,57 / 0,73 / 1,07 s | 5,8 / 4,5 / 1,7 m/s | ciclos |
| Crouched To Sprinting | 0,53 s | sai agachado | arrancada (variante) |
| left / right turn | 1,07 s | parado, 90° | base do giro |
| jumping up, falling idle, hard landing, falling to roll | 0,27 / 0,73 / 2,03 / 1,50 s | — | salto, queda, pouso |
| Sprinting Forward Roll, Running Slide | 1,20 / 1,57 s | 5,8 / 6,7 m | rolamento, deslize |
| idle ×5, cobertura ×4, agachado ×2 | — | — | parado / extras |

**Faltam** para o item 2: agarrar/pendurar na parede, ciclo de escalada (subir/descer/
lado) e saltar da parede; também virada correndo (180°) e arrancada de pé.

## Etapas (fatias verticais — cada uma jogável e medida antes da próxima)

| # | fatia | entrega | estado |
|---|---|---|---|
| 0 | Base técnica | clipes novos no pipeline; baker grava quadril + deslocamento do corpo; tocador de clipes com mistura e ritmo pela velocidade no `ProceduralAnimator` | pendente |
| 1 | Chão | frente pelo movimento (mira no combate), arrancada, frenagem com derrapagem, giro (frear→girar→arrancar), inclinação nas curvas | física e frente ✅ 02/10 (`locomocao_chao.gd`, `test_locomocao_chao` 16/16); regressão corrigida 03/10 (ver abaixo); clipes (arrancada, frenagem, giro) entram com a fatia 0 |
| 2 | Wall run | gravidade normal, velocidade herdada e perdida aos poucos, entrada por ângulo/velocidade, salto para longe, mão na parede por IK; remove andar na superfície | ✅ 03/10 (`corrida_na_parede.gd`, `test_corrida_na_parede` 19/19; mão na parede por pose — IK de verdade entra com a fatia 0); andar na superfície, energia de parede e cambalhota de saída removidos |
| 3 | Escalada | campo `escalavel` na loja (+ marcação inicial), agarrar ao saltar contra a parede, escalar tipo escada com mãos/pés por IK, borda → subir (sem teleporte) → correr | ✅ 03/10 (`escalada.gd`, `test_escalada` 16/16; 109 modelos marcados por `tools/mapa_ilha/aplicar_escalaveis.gd`; loja: clique direito → "Escalável"); mãos/pés por pose procedural — IK e clipes de keyframe entram com a fatia 0 |
| 4 | Encadeamento e rede | buffers de entrada, preservação de momentum entre estados, sequência completa; estado replicado no multiplayer; sondas de medida + avaliador de animação | ✅ 03/10 exceto o avaliador: buffer do Espaço e coyote do wall run (`test_corrida_na_parede` 22/22), sequência completa do pedido (`test_sequencia_parkour` 6/6), apresentação replicada (`test_parkour_rede` 9/9). **Pendente:** avaliador de animação (agente parado no limite semanal até 06/10 18h) |

## Fatia 1 — o que a bateria pegou (03/10/2026)

- **Velocidade herdada acumulava o que era de um quadro.** Empurrão de dano, avanço do
  golpe e puxão do soco (`perform_melee_lunge`) somam velocidade DEPOIS da locomoção, só
  para o `move_and_slide` do quadro. Com a locomoção herdando a velocidade, isso se
  acumulava (empurrão lateral: 11,52 m em vez de 1,98 m). `LocomocaoChao.entrada()`: se a
  locomoção mandou no quadro anterior, herda a PRÓPRIA saída (deslizada nas paredes); se
  outro sistema mandou (dash, parkour, nado), a velocidade real. Teste H.
- Na água o `rumo` congelava (o nado não passa pela locomoção) e o corpo nadava de lado:
  `LocomocaoChao.acompanhar()`.
- O dash conta como combate: ele classifica frente/lado/trás pela MIRA.
- `test_combate_historia` media a regra antiga (corpo parado virando para a mira; andar a
  partir do repouso) — ajustado à regra nova sem afrouxar o critério.

## Fatia 2 — desenho do wall run (03/10/2026)

Texto do dono: "a parede continua sendo uma parede e a gravidade permanece normal"; "não
poderá ficar parado na parede. Conforme perde velocidade, a gravidade passa a dominar".
Então a gravidade aponta sempre para baixo e quem segura o corpo é a velocidade ao longo
da parede (`src/player/corrida_na_parede.gd`):

| parâmetro | valor | por quê |
|---|---|---|
| entrada | Espaço, velocidade horizontal ≥ 3,5 m/s, parede vertical a ≤ 0,9 m de lado (1,15 m na diagonal), também na altura do ombro | correr (4,2) basta; andar não; mureta não serve |
| ângulo de entrada | corrida a ≤ 60° do plano da parede | mais que isso é de frente → escalada (fatia 3) |
| impulso | vertical sobe a ≥ 5 m/s; velocidade ao longo = 95 % da horizontal | "velocidade parcialmente mantida" |
| sustentação | anula 72 % da gravidade a partir de 4 m/s, proporcional abaixo | perde velocidade → a gravidade domina |
| perda | 1,8 m/s² ao longo da parede | não dá para ficar parado |
| resultado (simulado = medido) | corrida 4,2 m/s: 0,83 s, sobe 1,13 m · sprint 6,3: 1,1 s, sobe 1,35 m | 1ª versão dava 0,58 s na corrida (pulo de lado) |
| fim | < 2,5 m/s, 1,8 s, parede some > 0,12 s, chão, Ctrl | |
| salto | normal × 7 + tangente × v × 0,85 + cima × 13 | "saltar para longe" sem matar o embalo |
| reentrada | mesma parede só após 0,35 s; a do outro lado na hora | parede → salto → parede |

Remove junto: andar na superfície (`_na_parede`, base da superfície, histerese), energia
de parede (`CUSTO_PAREDE_POR_SEG`, `parkour_gasta_energia`), cambalhota de saída da
superfície, e os medidores `medir_camera_e_parede.gd`/`medir_teclas_parede.gd`.

## Fatia 3 — escalada (03/10/2026)

`src/player/escalada.gd`. Estados: **escalando** (escada: W/S 2,2/2,8 m/s, A/D 1,6 m/s,
para na quina), **borda** (mãos no topo; pendurado, o corpo fica a 0,85 m abaixo do topo),
**subindo** (sobe rente à parede a 3,6 m/s até os pés passarem do topo, depois avança
0,9 m por cima a 3 m/s — trajetória, sem teleporte; maior passo medido 0,06 m/quadro) e
sai andando a ~3 m/s, a corrida retoma.

| item | regra |
|---|---|
| agarrar | no ar, indo de frente (≤ 50° da normal) contra parede com a meta `escalavel`; sem tecla. Sem direção pedida e parado contra a parede, não agarra (é preciso ir de frente) |
| pulo alto | o pulo do Civil sobe ~4 m: parede mais baixa que isso o corpo passa por cima e pousa — certo |
| Espaço | salta para trás: normal × 6 + 9 para cima |
| Ctrl / S no chão | solta |
| quem escala | meta `escalavel` no corpo da peça, posta pelo `MapaMontador` a partir da loja (`BibliotecaDeModelos.escalavel`); terreno e primitivas nunca |
| encadeamento | do wall run, saltar de frente contra parede escalável agarra (`avaliar` tenta a escalada quando o parkour não está assumido) |

## Fatia 4 — encadeamento e rede (03/10/2026)

- **Sequência do pedido medida** (`test_sequencia_parkour.gd`, câmera dirigindo a curva):
  `correndo → wall_run → ar → escalando → subindo → correndo`, sem "parado" no meio,
  curva inclinando 22°, maior passo 0,25 m/quadro (sem teleporte), menor velocidade
  horizontal fora da escalada 3,0 m/s, termina correndo a 4,2 m/s em cima.
- **Embalo entre estados:** quem sai do parkour entrega a velocidade real para a
  locomoção (`LocomocaoChao.entrada()`); a borda sai a 3 m/s para a corrida retomar.
- **Buffer** do Espaço 0,15 s para entrar na parede; **coyote** 0,15 s para saltar de uma
  parede que acabou no ar.
- **Rede:** `net_parkour`, `net_escalando`, `net_parede_lado`, `net_subida`,
  `net_inclinacao` na sincronização; a cópia remota reproduz inclinação e poses.

## Rodada de 03/10/2026 (tarde) — pedido do dono depois de jogar

| pedido | o que ficou | teste |
|---|---|---|
| "tira a animação de correr do Naruto e coloca uma da Mixamo" | corrida = clipes `running`/`sprint` (`_aplicar_corrida`), passada medida no rig, teto de cadência 5,0/7,5, olhar nivelado; silhueta Naruto removida | `test_corrida_mixamo` 22/22 (deslize do pé 6 %/4 %), `test_walk_run` (procedural) |
| "escala com as mãos para trás" | sinal do braço invertido na escalada/borda/subida/wall run/salto longo (+X = frente) | `medir_direcao_bracos` (fotos + 7 conferências) |
| "direção incorreta dos braços no nado" | corpo nadava de costas: `rumo` congelado na água (corrigido no começo do dia, `acompanhar`) | `test_nado_frente` |
| roll no Q, eliminando o dash | `DashController` virou roll: 4,5 m/0,55 s, i-frames 0,28 s, recarga 1,5 s, clipe `sprinting_forward_roll` | `test_roll_deslize` |
| deslize no Ctrl, só em movimento | `deslize.gd`: ≥ 3,5 m/s, passa por baixo (colisão/hurtbox pela metade), levanta só com espaço, Espaço pula com o embalo; botão no toque | `test_roll_deslize` |

## Contrato dos clipes de locomoção/parkour (fatia 0, 02/10/2026)

Formato do `.res` (o mesmo `Animation` dos 29 clipes antigos, com faixas NOVAS somadas;
o `ProceduralAnimator._apply_baked` antigo ignora papéis que o rig não tem, então os clipes
antigos e os chamadores atuais não mudam):

| faixa | tipo | conteúdo |
|---|---|---|
| `<Papel>:rotation` | VALUE Vector3 (euler) | igual ao de hoje: 13 papéis, 60 qps, euler contínuo |
| `Corpo:altura` | VALUE float | (altura do quadril no instante − altura do quadril em repouso) ÷ altura do quadril em repouso. Escala para qualquer personagem: multiplica pela altura do quadril dele |
| `Corpo:giro` | VALUE float | giro do quadril em volta do eixo vertical relativo ao 1º quadro (rad, sentido do jogo: + = para a esquerda), contínuo (sem salto de ±π). Esse giro é RETIRADO das rotações dos papéis (todas as poses ficam no referencial do quadril do 1º quadro girado de volta), para o jogo aplicá-lo uma vez só, no corpo. Viradas (`left_turn`, `right_turn`, `run_turn_180`) e `wall_jump_off` dependem disso |
| `Corpo:deslocamento` | VALUE Vector3 | posição do quadril relativa ao 1º quadro, no espaço do JOGO (frente = −Z, direita = +X, cima = +Y), ÷ altura do quadril em repouso. É o *root motion*: o jogo o usa para casar a velocidade física (arrancada, frenagem) e para guiar trajetórias (subir a borda, ajustado à altura real) |

Metadados no `Animation` (`set_meta`): `altura_quadril_m` (repouso do esqueleto de
origem), `origem` (arquivo), `espelhado` (bool).

**Espelho** (`<nome>_espelhado.res`): troca `_L`↔`_R`, euler (x, −y, −z), deslocamento
x → −x. Usado nos wall runs (parede do outro lado) e onde mais for preciso.

**Nomes** (snake_case, sem colidir com os 29 de hoje): `wall_run`, `diagonal_wall_run`,
`climbing_up_wall`, `run_to_stop`, `run_to_stop_2`, `sprint`, `running`, `walking`,
`crouched_to_sprinting`, `sprinting_forward_roll`, `running_slide`, `left_turn`,
`right_turn`, `jumping_up`, `falling_idle`, `falling_to_roll`, `hard_landing`, `idle`,
`idle_2` … `idle_5`, `stand_to_cover`, `stand_to_cover_2`, `cover_to_stand`,
`cover_to_stand_2`, `crouched_sneaking_left`, `crouched_sneaking_right`,
`left_cover_sneak`, `right_cover_sneak`.

**Clipes autorados por keyframe** (esqueleto `mixamorig` do X Bot do pacote, mesmo
pipeline): escalada — `hang_idle`, `jump_to_hang`, `climb_up_loop`, `climb_down_loop`,
`climb_shimmy_left`, `climb_shimmy_right`, `ledge_climb_up`, `wall_jump_off`; chão —
`run_start`, `run_turn_180`. Fonte em `art_src/animacoes_parkour/`.
