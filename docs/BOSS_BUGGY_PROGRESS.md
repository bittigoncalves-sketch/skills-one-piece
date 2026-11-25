# Buggy — histórico de execução

> Estado mais recente (13/09/2026): combo alternado, reação a M1, corte e punho destacado após os jabs. Ver [BOSS_BUGGY_DETACHED.md](BOSS_BUGGY_DETACHED.md). As seções antigas abaixo registram cada etapa e suas medições.

Registro inicial atualizado em 12/09/2026. Continuação autorizada: Buggy temporário no jogador pelo atalho da área de trabalho; primeiro Boss e jab na **arena normal**, conforme escolha do usuário. Este registro atualiza o estado de execução do plano original, cuja auditoria permanece histórica.

## Como jogar

~~Abra **SKILLS ONE PIECE** na área de trabalho~~ — **16/09/2026: o atalho voltou a abrir o jogo normal (`jogar.sh`) a pedido do dono.** Para jogar com o visual do Buggy: `SOP_TEST_CHARACTER_TARGET=player ./jogar_buggy.sh`, que troca o visual do jogador e preserva o dos bonecos de treino. Não grava essa escolha na customização.

Buggy Boss nasce na arena normal, aproximadamente 18 m à frente do spawn quando esse ponto está livre. O sistema procura outro ponto seguro se houver obstáculo ou buraco. A barra vermelha mostra vida e distância. Aproximar-se a menos de 11 m, com linha de visão, inicia a perseguição. O limite do encontro é 22 m em torno do ponto de origem. Um novo encontro nasce ao entrar em outra partida; o cadáver não se regenera como o Dummy.

Para jogar com o personagem original nesta sessão, use `./jogar.sh`. Para desativar somente o Boss numa sessão, use `SOP_BOSS_ENABLED=0 ./jogar.sh`. O teste genérico `./jogar_buggy.sh` continua podendo vestir jogador e Dummies; a restrição ao jogador vem do ambiente do atalho.

O atalho anterior foi preservado em `art_src/validation/buggy_boss/desktop_before.desktop`. Restaurá-lo em `~/Área de trabalho/SKILLS ONE PIECE.desktop` reverte a mudança temporária do executor. Nenhum modelo original foi removido.

## Implementação

- `BossActor`, `BossDefinition` e `BossAbility`: corpo e dados próprios; 4096 HP, visual de 2,2 m, contrato `take_damage`, morte única e identidade independente de peer de jogador.
- `BossBrain` e `BossController`: percepção, perseguição, retorno, desvio local de obstáculos/buracos, gravidade, impulso recebido e interrupção por dano/congelamento/controles existentes.
- `BossEncounter`: spawn exclusivo do servidor, registro de definições, `MultiplayerSpawner` e `MultiplayerSynchronizer`. Replica posição, rotação, vida, morte, estado, ação, tempo, sequência e velocidade; suporta entrada tardia.
- `BossVisual` e `BoxingPose`: rig e materiais importados, guarda com punhos perto do rosto, jab esquerdo por IK sem esticar ossos, mão direita mantida em guarda, retorno e pose simples de morte. Áudio posicional de deslocamento da mão; dano no jogador usa feedback existente.
- `BossCombat`: varredura do punho real, subamostras temporais de até 1/120 s e parede física; reutiliza `SwordSweep`, `DamageZone`, `DamageSpec` e `CombatResolver`. O cliente não inicia ataques nem aplica dano.
- `BossHealthBar` e integração em `Main`: encontro visível na arena normal. Posicionamento conferido junto ao painel da Ope.

| Jab esquerdo | Valor |
|---|---:|
| Preparação | 0,48 s |
| Contato ativo | 0,18 s |
| Recuperação vulnerável | 0,72 s |
| Cooldown após terminar/cancelar | 1,25 s |
| Dano máximo por alvo/cast | 72 |
| Alcance de início entre corpos | 1,25 m |
| Raio da varredura do punho | 0,22 m |
| Knockback / hitstun | 5 / 0,18 s |

A direção do golpe fica comprometida na preparação: sair lateralmente ou recuar permite esquivar. Dano e controle interrompem o ataque; acertar durante a recuperação reduz a vida do Boss normalmente. Não há invulnerabilidade, teleporte para acompanhar o alvo ou dano fora da trajetória física do punho.

## Área de detecção, dash de esquiva e pulo duplo — 13/09/2026

Pedido do dono: uma área de detecção ao redor do Boss que identifica projéteis do jogador, dash para desviar deles e pulo duplo. Decisões do dono:
- implementar direto, fora das ondas da equipe;
- conta **todo ataque do jogador em voo**;
- dash com **recarga de 3 s, só fora do próprio golpe**;
- pulo duplo para **projétil rasteiro, jogador no alto e cruzar buraco**.

- **Área de detecção** (`BossProjectileSensor`, Area3D de raio 12 m): enxerga `DamageZone` de jogador voando a pelo menos 8 m/s e não marcada como corpo a corpo (a Aú nasce a 26 m/s e fica de fora). Também enxerga a `YoruWave` pelo grupo `projetil_em_voo`. Calcula a passagem mais próxima da reta do projétil contra a cápsula e só considera ameaça o que acerta em até 0,6 s.
- **Dash** (`BossMobility`): 4 m em 0,22 s, perpendicular ao voo e para longe da linha. Se um lado cai em buraco ou bate em parede, vai para o outro. Não sai no ar, paralisado, em reação a M1 nem durante o próprio golpe.
- **Pulo duplo**: 12 + 10 m/s (altura ~2,25 m no simples, ~3,8 m no duplo).
  - Projétil rasteiro (passagem até 1,3 m dos pés) com o dash em recarga ou sem lado seguro: pula, com o segundo impulso no ápice.
  - Alvo no alto (piso medido por raio embaixo dele, então o jogador pulando não conta) a até 4 m e subida de pelo menos 0,7 m: pula até ele, com duplo se o simples não alcança.
  - Buraco no caminho do alvo, com até 11 m e chão firme do outro lado: cruza com o pulo duplo. O buraco grande (20 m) é contornado.
- **Rede**: `mobility`, `mobility_elapsed`, `jumps_used` e `dash_direction` são replicados. As poses (inclinação no dash, pernas recolhidas no pulo) aparecem no cliente.

Evidência:
- `tools/dev_tests/test_boss_mobilidade.gd`: **21 verificações, 0 falhas**.
  - Sensor: detecta o que vem, ignora o que se afasta, a hitbox parada e o ataque do próprio Boss, e enxerga a onda da Yoru.
  - Esquiva: o dash desvia sem dano (3,94 m de lado) e desvia também da **flecha de gelo real a 55 m/s**. Com o dash em recarga, pula o rasteiro com duplo e pousa. Com o dash gasto, um projétil alto acerta. Não esquiva durante o próprio golpe. Parede ou buraco de um lado: vai para o outro.
  - Pulo: sobe num bloco de 2 m usando o duplo, cruza o buraco de 10 m e não tenta o de 20 m.
- `test_boss_network.py`: **36 verificações, 0 falhas**. O cliente recebe o dash e o pulo duplo e anima as poses.
- Ciclo 54/0, recepção 31/0, corte 26/0, punho 28/0, arremesso 34/0.
- `capture_boss_mobilidade.gd`: 4 capturas com o renderizador real (parado, dash com a flecha passando, pulo, pulo duplo), inspecionadas.

**Limites:**
- A esquiva assume que o projétil voa em linha reta (teleguiados só são avaliados pelo trecho atual).
- A travessia de buraco e o pulo ao alto só olham o caminho reto até o alvo, sem planejar rota.
- **Gatilho:** se o boss desviar demais ao jogar, ajustar `DASH_COOLDOWN` ou `REACTION_WINDOW`.

## Alcance, fim do knockback, arremesso do jogador e flash de dano — 13/09/2026

Pedido do dono:
- o Boss não atacava com o jogador de frente, e o knockback fazia os golpes seguintes errarem;
- tirar o knockback e deixar só o último golpe arremessando, com o jogador deitando no chão como o Boss;
- ao levar dano, troca de cor e textura com piscada vermelha no jogador e no Boss.

Decisões do dono:
- o corte **mantém** o knockback;
- a derrubada nova vale **só para o golpe do Boss**;
- o flash é **vermelho com trama**;
- com o punho destacado do Codex no combo, **ele é o último** golpe e arremessa.

**Combo e alcance** (causa medida em `docs/erros.md`):
- Encostado no alvo também é alcance (`BossController.touching`).
- `jab`, `jab_right`, `jab_left` e `jab_finish` passam a ter knockback 0.
- `launch_horizontal`/`launch_vertical` (14/9) em `jab_finish` e `detached_fist`. Arremessa o **último golpe que sai**: o punho, se `detached.available()`; senão, o 4º soco (`BossCombat.launch_if_hit`, `_detached_follows`).
- Passo de boxeador (`BossCombat.step_velocity`, 5 m/s): na preparação e no contato, o corpo avança até `attack_distance`. O corte e o punho destacado não andam.
- Colisão do Boss em cápsula (raio 0,55): o contato fica igual em qualquer rotação.
- O cérebro ignora a "fuga" de quem está arremessado (`esta_arremessado`), para o corte não emendar num alvo deitado.

**Derrubada do jogador** (`src/player/player_arremesso.gd`):
- **Fases:** voa de costas → cai deitado (0,9 s) → levanta (0,7 s). O modelo gira pelos pés e mantém a altura de repouso do rig.
- **Rede:** o servidor chama `Player.receber_arremesso` → `net_arremesso` em todas as cópias. O dono aplica a velocidade e controla as fases pela física; as cópias remotas animam lendo o `net_on_floor` replicado.
- **Travas:** sem ataque (`_consume_input`) e sem habilidade (`begin_charge`) durante a sequência. O respawn cancela.
- **Escopo:** o finalizador M1 entre jogadores continua com a derrubada antiga, por escolha do dono.

**Flash de dano** (`FxUtil.flash_dano`):
- Sobreposição com shader: 3 piscadas vermelhas em 0,5 s, com listras correndo e granulado em coordenada de mundo, mais borda acesa.
- Um novo golpe reinicia o ciclo; no fim, volta o destaque de mira ou nada.
- **Jogador:** em `_feedback_de_dano` (toda cópia).
- **Boss:** quando a vida replicada cai (toda cópia).
- O boneco de treino e o Corpo de Ferro seguem com o `flash_red` antigo.

Evidência:
- `tools/dev_tests/test_boss_arremesso_jogador.gd`: **34 verificações, 0 falhas**.
  - Ataque a 1,4 m de frente e combo na diagonal a ~1,58 m: 288 de dano e o 4º soco arremessa.
  - Combo com punho disponível: 400 de dano e o punho arremessa. Combo com punho em recarga: 288 e o 4º soco arremessa.
  - Sem deslocamento do jogador antes do arremesso. Voo de 11,6 m, pico de 1,34 m, deitado a 1,57 rad, levanta.
  - Sem ataque ou habilidade durante a derrubada, sem corte emendado.
  - Flash: 3 piscadas terminando em zero, trama em todas as malhas do jogador e do Boss, reinício no golpe seguinte e material restaurado. Respawn cancela a derrubada.
- `test_boss_network.py`: **34 verificações, 0 falhas**.
  - O dono remoto voa, deita e levanta (11,55 m), e a cópia do servidor anima as mesmas fases.
  - O punho aplica 112 uma vez, medido na cópia do servidor (no cliente, a regeneração local se mistura com a correção autoritativa da vida).
- Ciclo 54/0, recepção 31/0, corte 26/0, punho destacado 28/0.
- `capture_boss_arremesso.gd`: 5 capturas com o renderizador real (flash no jogador, voo, deitado, levantando, flash no Boss), inspecionadas.

**Limites:**
- O colisor do jogador continua em pé enquanto ele está deitado.
- A pose de membros no voo é o tranco de dano genérico; deitado, os membros ficam neutros.
- **Gatilho:** se o passo de 5 m/s parecer perseguição teleguiada ao jogar, reduzir `STEP_SPEED` ou limitar o passo à preparação.

## Andar + clique empurrava o Boss — 13/09/2026

Relato do dono: com o jogador em movimento, o clique virava outro golpe e empurrava o Boss. Decisões do dono:
- **apagar de vez** as variações de movimento simples (W cotovelada, S chute recuando, A/D esquiva com gancho);
- **manter** o Lançamento (W no 4º golpe);
- as outras variações de clique **contam como M1 no Boss**.

- **Causa**: `ContextualMelee.resolver` trocava o M1 pelo contextual sempre que havia W/A/S/D no primeiro golpe. A `DamageZone` contextual não tinha a marca `corpo_a_corpo`, então o Boss aplicava o knockback do golpe (16/17/15).
- **Removido**: as quatro fichas, as quatro poses do `ProceduralAnimator`, `_recuo_contextual_livre` e as duas checagens no `Player`. No chão, o resolvedor só devolve o Lançamento.
- **Contam como M1 no Boss**: hitbox contextual (Lançamento, chute aéreo, chute de parede), Aú (`SpinKickFX`) e mordida e chute Mink (agora pelo `CombatResolver` com o dono como atacante). Contra jogadores nada muda.
- **Impulsos extras**: `BossActor.reage_ao_corpo_a_corpo()` faz o contextual dispensar counter, lançamento e sustento no Boss. Esses impulsos chegariam como um segundo `take_damage` sem marca.
- **Não alterados** (fora do que foi combinado): queda esmagadora (`AirSlamFX`) e Asas de Anjo seguem empurrando o Boss.

Evidência:
- `test_boss_recepcao.gd`: **31 verificações, 0 falhas**. W, S, A e D + clique pelo `MeleeController` real saem M1 e paralisam sem mover o Boss. Lançamento, chute aéreo, Aú e chute Mink também paralisam sem mover nem erguer.
- Testes contextuais reescritos:
  - `test_ataques_contextuais`: TUDO OK. Andar nas quatro direções + clique sai M1 sem pose contextual e acerta o boneco. O acerto alternado que apareceu era do boneco ainda deslizando do caso anterior, e o teste agora zera a velocidade.
  - `test_combo_contextual`: 2/0, com W segurado nos cliques 1–3 dando M1 e o 4º dando Lançamento.
  - `test_launcher`: 38/0.
  - `test_counter_hit`: 11/0.
  - `net_contextual_client_probe` passou a usar o Lançamento.
- `test_boss_recepcao` corrigido: o arremesso passou a ser medido a partir da posição anterior ao 3º soco (antes a espera em tempo real deixava a medição instável).
- A Aú entra no teste pelo caminho real do Player: chamar `SpinKickFX` direto não compila no harness `-s` por causa do autoload `ScreenFX`.

## Corte contra quem foge — 13/09/2026

Pedido do dono: o Boss lança um corte quando o jogador se afasta, com animação de arremesso e uma linha vermelha no chão antes do lançamento. Decisões do dono:
- o corte sai **só quando o jogador foge**;
- a postura é **como um arremesso de beisebol** (uma perna dobra e sobe, o apoio fica numa perna só);
- o perfil é **agressivo**;
- o corte **atravessa jogadores** e para em parede.

⚠️ **Diverge do plano de design**: `BOSS_BUGGY_COMBAT_DESIGN.md` §8 e §11 reservavam cortes para a fase 3 (Bara). O pedido atual prevalece. O corte vale desde já, sem fases.

| Corte (`corte`) | Valor |
|---|---:|
| Mira acompanhando o alvo | 0,30 s |
| Linha vermelha (mira travada) até o lançamento | 0,55 s |
| Lançamento (arremesso) / recuperação | 0,12 s / 0,55 s |
| Cooldown próprio | 4,0 s |
| Alcance / largura / velocidade | 18 m / 1,5 m / 26 m/s |
| Dano / knockback / hitstun | 90 / 14 / 0,35 s |
| Gatilho | alvo visível, entre 4 m e 18 m, se afastando a ≥ 2 m/s |

- **Fuga** (`BossBrain.flee_rate`): é o deslocamento do próprio alvo na direção Boss→alvo, suavizado. O Boss sendo arremessado ou andando não conta como fuga. Alvo parado longe continua sendo perseguido.
- **Dados**: `BossSlashAbility` estende `BossAbility` e fica em `BossDefinition.slash`. `telegraph_start()` diz quando a marca aparece (jab: 0; corte: `aim_time`).
- **Combate** (`BossCombat.begin_slash`/`_tick_slash`): a mira acompanha até `aim_time` e depois trava. A frente é uma `YoruWave`, com varredura contínua, parada em parede, um acerto por alvo por cast e dano só no servidor. Ela nasce no fim da preparação, e dano ou controle antes disso cancelam o corte sem lançar. `slash_path` corta a linha na primeira parede, ignorando personagens.
- **Linha**: é a mesma `BossTelegraph` do jab. A cápsula tem a largura do corte e o comprimento do trecho até a parede, e se enche do Boss até a ponta durante os 0,55 s.
- **Rede**: o cliente redesenha a linha a cada quadro e cria a própria frente, só visual, quando o lançamento chega pelo `action_elapsed` replicado. A `YoruWave` confere a autoridade antes de aplicar dano.
- **Animação** (`BossThrowPose`): poses-chave em espaço do ator, interpoladas com smoothstep, na ordem mira → carregado (joelho alto e para dentro, mão acima da cabeça e para trás, luva apontando) → impulso → mão por cima e à frente da cabeça → soltou (braço estendido, perna plantada, tronco girado e inclinado) → acompanhamento cruzado → guarda.
- `YoruWave` ganhou `core_color`/`edge_color` opcionais nos dados. O padrão continua sendo o da Yoru.

Evidência (em `art_src/validation/buggy_boss/corte/`):
- `tools/dev_tests/test_boss_corte.gd`: **26 verificações, 0 falhas**. Cobre o perfil; a pose (mão acima da cabeça e atrás, pé esquerdo 0,30 m acima do direito, mão volta à frente, perna desce, poses-chave sem salto, mão até 29 m/s); os gatilhos (parado não corta, fuga a menos de 4 m não corta, fuga além de 4 m corta); a mira e a linha (acompanha e trava, linha na direção e com o comprimento do corte, no chão, com a largura certa); o dano de 90 uma vez; o desvio lateral depois da linha; a travessia de alvos, a parada na parede e a linha terminando na parede; o cooldown; e o cancelamento por dano.
- `test_boss_network.py`: **22 verificações, 0 falhas**. O cliente vê a linha, cliente e servidor criam uma frente cada, e o jogador remoto leva 90 uma vez só.
- Ciclo 54/0 e recepção 23/0.
- `capture_boss_corte.gd`: 14 capturas com o renderizador real (6 poses de lado e de frente, linha e corte em voo), inspecionadas. Na inspeção corrigi a mão pouco para trás, a perna subindo para o lado e o corte quase preto.

**Limites:**
- A frente voa numa altura fixa. Pular por cima a evita, e ela passa por cima de buracos, onde a linha fica desenhada no nível do chão.
- A linha é cortada por um raio no centro da faixa. Um obstáculo baixo que pegue só a borda da faixa pode parar a frente antes do fim da linha.
- **Gatilho**: se jogar mostrar cortes em sequência demais contra quem só reposiciona, subir `flee_speed` (2 m/s) ou o cooldown (4 s).

## Balanço do tórax no soco — 13/09/2026

Pedido do dono: o tórax passa a balançar no soco. O dono escolheu **deixar o tórax somar alcance** e o padrão **carrega, gira e volta**.

- `BoxingPose.apply(view, side, extension, preparation, torso_turn, torso_load)` gira o osso `Torso` **antes** da IK dos braços. Na preparação, o tronco torce para trás até 0,14 rad. No contato, gira para o lado do punho (0,30 rad) e inclina 0,10 rad à frente. A cabeça contra-gira 70% para manter os olhos no alvo, e a mão de guarda continua no queixo.
- As curvas ficam em `BossVisual.pose_at` e são contínuas entre as fases: a carga some enquanto o braço estende, e o giro volta com atraso na recuperação (de 15% a 90% dela). Os valores estão nas constantes `TORSO_*` de `BoxingPose`.
- **Alcance**: o punho estendido foi de 0,58 m para **0,72 m** à frente do centro do Boss (+0,14 m). A hitbox e a marca vermelha amostram a mesma pose, então acompanham sozinhas. `attack_distance` (1,25 m, distância para começar o combo) não mudou.
- `rotate_bone` saiu de `BossReactionPose` e foi para `BoxingPose`, que as duas poses usam.

Evidência (em `art_src/validation/buggy_boss/torax/`):
- `test_boss_lifecycle.gd`: **54 verificações, 0 falhas**. O ombro do punho avança 0,144 m (E) e 0,151 m (D), e o salto do tórax nas três fronteiras de fase é de 0,0000 rad.
- Recepção 23/0 e rede 19/0.
- `capture_boss_torax.gd`: 16 capturas com o renderizador real (guarda, carga, contato e recuperação, dos dois punhos, de frente e de cima), inspecionadas.
- A bateria rápida não foi repetida: a mudança ficou restrita aos scripts do Boss, cobertos pelos três testes acima.

## Recepção de M1 — 13/09/2026

Pedido do dono: os golpes corpo a corpo (clique do mouse) empurravam o Boss para trás. Agora os dois primeiros acertos seguidos paralisam o Boss e o terceiro o arremessa para longe. A reação ganhou animação própria. Decisões do dono: a contagem é por **acertos seguidos no Boss**, o Boss **pode morrer** se cair num buraco, e a animação é **voar, cair deitado e levantar**.

| Fase | Duração | Comportamento |
|---|---:|---|
| 1º e 2º acerto (`stagger`) | 0,9 s | Sem impulso nem deslocamento, sem atacar. Tranco que torce para um lado no 1º acerto e para o outro no 2º. |
| 3º acerto (`launched`) | até pousar | 13 m/s para longe do atacante + 9 m/s para cima (~7–8 m, pico ~1,3 m). Corpo de costas e arqueado. |
| Chão (`knockdown`) | 0,9 s | Deitado de costas com um quique curto. Atrito de 30 m/s² no chão. |
| Levantar (`getup`) | 0,7 s | Senta e volta a ficar de pé, até a guarda. |

- **Acertos seguidos**: mesmo atacante, com no máximo 1,0 s entre acertos (`CHAIN_WINDOW`). A contagem zera depois do arremesso, quando outro jogador bate ou quando a janela passa.
- **Quais golpes contam**: o punho (`Melee`, `DamageZone.corpo_a_corpo`), a espada do `Melee` e os `M1_*` da Yoru (`SwordBlade.armar(..., true)`). Chegam ao Boss pela meta `CombatResolver.META_CORPO_A_CORPO`, que só existe durante o `take_damage`. Skills continuam com impulso e hitstun antigos.
- **Boss no ar ou no chão**: um M1 causa dano, mas não reinicia a queda nem empurra. Isso evita prender o Boss num laço.
- **Rede**: `reaction`, `reaction_elapsed` e `reaction_count` são replicados. A pose (`BossReactionPose`) só lê esses campos e mistura as fases por rigidez exponencial.
- **Animação**: procedural, em espaço do ator (sem eixos locais do esqueleto Z-up do Meshy). Usa giro do corpo pelos pés, dobra de tronco e cabeça, e IK dos braços reaproveitando `BoxingPose.arm`.

Evidência (em `art_src/validation/buggy_boss/recepcao/`):
- `tools/dev_tests/test_boss_recepcao.gd`: **23 verificações, 0 falhas**, com golpe real do `Melee.golpear` e física real.
- `test_boss_network.py`: **19 verificações, 0 falhas**. O arremesso feito pelo cliente chega replicado e o cliente anima o voo.
- `test_boss_lifecycle.gd`: continua 50/0.
- `capture_boss_recepcao.gd`: 6 capturas com o renderizador real (tranco 1, tranco 2, voo, deitado, levantando, de pé), inspecionadas.

**Limites:**
- A caixa de colisão continua em pé enquanto o Boss está deitado: golpes no ar acima do corpo ainda acertam.
- Com a Yoru, o intervalo entre o 2º e o 3º acerto (fim do `M1_2` + startup do `M1_1`) fica perto de 1,0 s. O arremesso pode não sair se o jogador clicar devagar. **Gatilho:** se isso acontecer ao jogar, aumentar `CHAIN_WINDOW` junto com `STAGGER_TIME`.

## Combo de jabs — 12/09/2026 (noite)

O Codex começou os dados (quatro golpes em `buggy_definition.tres`, `combo_index` replicado) e parou antes de ligar combate e visual. Esta sessão do Claude assumiu a partir daí, com autorização do usuário. **Os tempos abaixo substituem a tabela do jab esquerdo acima**, que era do jab único de 0,48 s.

| # | Golpe | Mão | Preparação | Ativo | Recuperação | Dano | Knockback / hitstun |
|---|---|---|---:|---:|---:|---:|---|
| 1 | `jab` | E | 0,24 s | 0,12 s | 0,10 s | 72 | 1,2 / 0,10 s |
| 2 | `jab_right` | D | 0,16 s | 0,12 s | 0,10 s | 72 | 1,2 / 0,10 s |
| 3 | `jab_left` | E | 0,16 s | 0,12 s | 0,10 s | 72 | 1,2 / 0,10 s |
| 4 | `jab_finish` | D | 0,16 s | 0,12 s | **0,60 s** (pausa) | 72 | 5 / 0,18 s |

Depois do combo, ou de uma interrupção, vem um cooldown de 0,65 s. Se os quatro socos acertarem, o total é de 288 de dano.

- **Um cast por soco** (`BossCombat._start_move`): cada soco tem hitbox, `DamageSpec` e direção próprios. O Boss mira de novo no alvo no início de cada preparação e não corrige a mira depois disso.
- **Encadeamento**: o próximo soco só começa se o alvo estiver vivo, visível e a no máximo `combo_break_distance` (2,0 m entre os corpos). Se não estiver, o combo termina e o cooldown começa. O que sobra de tempo no tick que fecha um soco é descartado: o soco seguinte começa no tick depois. Isso alonga o combo em até um tick por soco.
- **Mão da vez**: `BoxingPose.apply(view, side, …)` usa `GUARD` e `REACH` por mão. A mão que não golpeia fica no queixo. No cliente, o golpe é identificado pelo `action_id` replicado (`BossDefinition.move_for`), e `valid()` agora recusa ids repetidos.
- **Marca vermelha no chão** (`src/bosses/BossTelegraph.gd`): é uma cápsula com a largura do raio da hitbox (0,22 m). Ela vai da mão no início do contato até a mão totalmente estendida, projetada no piso. São as mesmas poses que a varredura de dano amostra, calculadas uma vez por soco em `BossVisual._aim_telegraph`. Na preparação a marca se preenche do Boss até a ponta, fica cheia durante o contato e some em 0,12 s na recuperação ou quando o Boss é interrompido. É só apresentação: não aplica dano.

Evidência do combo (logs e capturas em `art_src/validation/buggy_boss/combo/`):
- `test_boss_lifecycle.gd`: **50 verificações, 0 falhas**. Os socos alternam E, D, E, D. O dano é 288, com um acerto por soco. Não há cooldown entre os socos, e a pausa só vem depois do quarto. A marca fica no chão, à frente e do lado do punho da vez. O erro entre a ponta da marca e o punho estendido é inferior a 0,05 m (medido: ~0). A marca some fora do golpe, e sair do alcance depois do 1º soco encerra o combo com a pausa. Duas verificações antigas usavam instantes fixos (0,60 s e 0,50 s) do jab de 0,48 s e passaram a ler os tempos da definição.
- `test_boss_network.py`: **17 verificações, 0 falhas**, incluindo "cliente exibe a marca do punho em curso". O instante de entrada tardia (0,55 s) ficava além do fim do jab novo e foi trocado por preparação + 0,05 s.
- `capture_boss_combo.gd`: 8 capturas com o renderizador real (preparação e contato de cada soco).

Limite de design: nos socos 2–4, a marca aparece 0,16 s antes do contato, menos que o tempo típico de reação. Ela avisa onde o punho vai chegar, mas desviar de cada soco isolado fica difícil. A saída mais legível é recuar ou sair para o lado depois do primeiro soco, que tem 0,24 s de preparação. **Gatilho para revisar:** se nos testes jogados o combo pegar os quatro socos com frequência mesmo com o jogador reagindo, subir a preparação dos socos 2–4 ou baixar o dano.

## Evidência

- `tools/dev_tests/test_boss_lifecycle.gd`: **41 verificações, zero falhas**. Arena e filtro de visual; alcance da mão e guarda; 30/60/120 Hz; contato único; preparação e recuperação; cooldown; interrupção; congelamento; frame longo; parede; alvo morto; perseguição com física real; retorno; placar sem identidade de Boss; dano de entrada por DamageZone; interrupção na janela ativa; morte e limpeza de hitbox.
- `python3 tools/dev_tests/test_boss_network.py`: **16 verificações, zero falhas**, três processos Godot com ENet local. Cliente durante jab recebe HP reduzido, ação/fase/tempo/sequência; tentativa de dano/início no cliente é rejeitada; jab do servidor aplica exatamente 72 no jogador remoto real; entrada após morte recebe cadáver sem hitbox ou reset. Logs `art_src/validation/buggy_boss/network/`.
- Godot 4.6.3, renderer real Forward+ em RTX 3050 Laptop, 1280×720: capturas da arena, guarda, preparação, contato, recuperação e morte em `art_src/validation/buggy_boss/`. Inspeção encontrou e corrigiu sobreposição da barra com Ope e alcance inicial maior que o braço.
- `bash -n` dos launchers, inicialização pelo launcher com filtro `player` e importação final/cache de classes: aprovados. A primeira tentativa de importação no sandbox registrou bloqueio dos sockets internos do editor; a repetição autorizada concluiu sem erros de script ou socket.
- `./validar.sh rapido`: **73 aprovados, 10 falhas, 1 pulado** (saída 1). A comparação com a etapa anterior (71/10/1) encontrou exatamente as mesmas dez falhas: `test_balance`, `test_buki_buki`, `test_compila`, `test_corte_horizontal`, `test_mera_z_saque`, `test_morte_limpa_cast`, `test_ope_animacoes`, `test_studio_playback`, `test_trava_fruta_dano` e `net_mp_probe`. Nenhum nome novo de teste com falha nesta bateria. Logs e comparação preservados em `art_src/validation/buggy_boss/rapido.log` e `regression_comparison.txt`. Isso não equivale a uma suíte global sem falhas.

Sondas antigas de sistemas isolados continuam sem Boss por padrão, reconhecidas pelo mesmo padrão de caminho usado por GameFlow para desligar AutoDummy. Testes do Boss habilitam `SOP_BOSS_ENABLED=1` explicitamente. O runner de rede deve ser executado separadamente: rodar seu GDScript sozinho apenas informa que faltam os peers.

## Limites e próximo incremento

Esta entrega cobre a base mínima em rede e o primeiro jab. Ainda faltam combos completos de boxe, fases 2/3, partes destacadas, ataques Bara, cortes horizontais/verticais, recompensas e reset de encontro dentro da mesma partida. A morte usa pose simples, sem ragdoll ou animação autoral de queda. Desvio local não garante solução de labirintos; controles básicos foram verificados, mas não toda combinação das frutas.

O GLB preservado tem aproximadamente 1,88 milhão de triângulos por instância. Não houve otimização/LOD nem medição comparativa de desempenho neste incremento. A execução em GPU comprova renderização, não aprovação de orçamento de performance.

Próximo passo do roadmap: ampliar percepção e estilo de boxe com combinações e variações legíveis, mantendo um cast e janelas verificáveis por golpe. A segmentação do asset continua sendo pré-requisito dos ataques com partes separadas.
