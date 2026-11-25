# Checkpoint — Buggy: visual e primeiro encontro

**Estado atual:** combo, reação e corte concluídos com Claude; incremento 4 (punho destacado após jabs) concluído e validado. Ver última seção e `BOSS_BUGGY_DETACHED.md`. O histórico abaixo preserva as etapas anteriores.

Etapa inicial — 2026-09-12. Objetivo: auditar a base, integrar GLB temporário no Player/Dummy e documentar Boss/Boxe/Bara/cortes; não implementar kit de habilidades.

- Decisão do usuário: **ativar por opção de teste**; `./jogar_buggy.sh`. Lançamento `./jogar.sh` mantém originais.
- Auditoria e asset integrados. Fonte `~/Downloads/buggyBoss.glb`; cópia em `assets/models/bosses/buggy/`, SHA idêntico. Resource genérico em `src/characters/CharacterVisualDefinition.gd`.
- Mapa completo dos 13 papéis para 41 ossos; fit uniforme 1,5 m; orientação Y=180°. Materiais preservados. Mãos já fechadas na geometria, sem dedos articulados.
- Arquivos de integração: PlayerRig, BodyScanner, SkeletonDriver, Visual, guarda mínima em Player, TrainingDummy e AutoDummy; sem mudanças de controles, RPC ou dano. Preservar alterações anteriores/concorrentes da árvore.
- Novo teste: `tools/dev_tests/test_boss_buggy_visual.gd`, 52/52 verificações aprovadas. Capturas reais em `art_src/validation/buggy/`. Sonda de dano de dois peers com override: host e cliente aprovados.
- Documento obrigatório com 22 seções preenchidas: `docs/BOSS_BUGGY_IMPLEMENTATION_PLAN.md`; catálogo complementar: `BOSS_BUGGY_COMBAT_DESIGN.md`.
- Godot 4.6.3. Importação limpa e SHA em logs persistentes. `test_compila`: mesmos seis scripts studio com falha já observados antes. Teste específico sem erro de script; tentativa intermediária corrigiu referência estática ao CameraRig no harness -s.
- HEAD continua `1e54b52`. Não fazer reset/checkout/limpeza de trabalho alheio.
- Concluído: bateria rápida 71 passou / 10 falhou / 1 pulado; dez falhas já registradas antes. Logs persistidos. Plano e relatório de validação consolidados. Próxima etapa futura: primeiro incremento genérico Boss + jab, conforme roadmap; não iniciado nesta tarefa.
- Limites: não há CombatExecutor neste checkout. Boss/IA/Bara/Boxe/cortes são propostas. Falta preparar segmentação real, animações específicas e orçamento de performance do asset de 1,88M triângulos.

## Continuação autorizada — 12/09/2026

- Usuário pediu Buggy temporário no jogador pelo executor da área de trabalho e avanço do plano; escolheu **Boss na arena normal**. Substitui o limite anterior de somente planejamento para os incrementos 1/2.
- ~~Atalho real atualizado (`~/Área de trabalho/SKILLS ONE PIECE.desktop`) com `SOP_TEST_CHARACTER_TARGET=player ./jogar_buggy.sh`~~ — **revertido em 16/09/2026 a pedido do dono** (o jogador aparecia como Buggy no jogo do dia a dia; ver `docs/erros.md`); backup preservado em `art_src/validation/buggy_boss/desktop_before.desktop`. `test_option(actor)` filtra por grupo player. Originais e launcher normal preservados.
- Implementados `src/bosses/{BossActor,BossDefinition,BossAbility,BossBrain,BossController,BossCombat,BossVisual,BossEncounter}.gd`, `src/combat/boxing/BoxingPose.gd`, dados em `assets/bosses/buggy/`, HUD `BossHealthBar` e integração em Main.
- Vida/IA/retorno/morte única; jab esquerdo com guarda/telegraph/contato/recuperação/cancelamento. Reuso de DamageZone/CombatResolver/SwordSweep; spawn e estado autoritativos em rede com entrada tardia. Não implementadas fases/Bara/segmentação/recompensas.
- 41 verificações de ciclo/combate/IA aprovadas; rede de três processos com 16 verificações aprovadas. Capturas reais inspecionadas; corrigidos alcance incompatível com braço e sobreposição da barra com Ope.
- Bateria rápida concluída: **73 aprovados / 10 falhas / 1 pulado**, exatamente os mesmos dez testes com falha da etapa anterior. Logs e comparação em `art_src/validation/buggy_boss/`. Diff e documentação revisados; launcher e captura final aprovados. Próximo incremento: combos/percepção de boxe; Bara/partes dependem da segmentação. Registro detalhado: `docs/BOSS_BUGGY_PROGRESS.md`.

## Combo de jabs — 12/09/2026 23:30+

- O Codex parou no meio: dados dos quatro golpes prontos, combate e visual ainda com um único jab. O Claude assumiu com autorização do usuário.
- Arquivos alterados: `BossCombat`, `BossVisual`, `BossDefinition` (`combo_break_distance` e ids únicos) e `BoxingPose` (lado). Arquivo novo: `BossTelegraph`. Testes: `test_boss_lifecycle` e `test_boss_network`. Captura nova: `capture_boss_combo.gd`.
- Validação: ciclo 50/0 e rede 17/0. Capturas inspecionadas. Bateria rápida: 73 aprovados / 10 falhas / 1 pulado, as mesmas 10 falhas de antes (log em `art_src/validation/buggy_boss/combo/rapido.log`).
- Próximo passo: testar jogando a leitura da preparação de 0,16 s dos socos 2–4 (ver o gatilho em PROGRESS).

## Recepção de M1 — 13/09/2026

- Arquivos novos: `src/bosses/BossHitReaction.gd`, `src/bosses/BossReactionPose.gd`, `tools/dev_tests/test_boss_recepcao.gd`, `tools/dev_tests/capture_boss_recepcao.gd`.
- Arquivos alterados: `BossActor`, `BossController`, `BossEncounter` (sync), `BossVisual`, `CombatResolver` (meta M1), `DamageZone`, `Melee`, `SwordBlade`, `YoruController` (1 linha).
- Validação: recepção 23/0, rede 19/0, ciclo 50/0, capturas inspecionadas. Bateria rápida: 74 aprovados / 10 falhas / 1 pulado, as mesmas 10 falhas com a mesma contagem de problemas (log em `art_src/validation/buggy_boss/recepcao/rapido.log`).
- Próximo passo: testar jogando a sensação do arremesso e a janela de 1,0 s com a Yoru.

## Balanço do tórax — 13/09/2026

- Arquivos: `BoxingPose` (tórax, cabeça e `rotate_bone`), `BossVisual.pose_at` (curvas), `BossReactionPose` (usa `BoxingPose.rotate_bone`), `test_boss_lifecycle` (+4 verificações), `capture_boss_torax.gd` (novo).
- Alcance do soco +0,14 m, com escolha do dono. Ciclo 54/0, recepção 23/0, rede 19/0.
- Próximo passo: jogar e ver se a carga de 0,14 rad fica legível nos jabs de 0,16 s de preparação (se ficar sutil demais, `TORSO_LOAD`).

## Corte contra quem foge — 13/09/2026

- Bateria rápida (rodada junto com a remoção de WASD, 13/09): 75 aprovados / 10 falhas / 1 pulado, mesmas 10 falhas conhecidas.
- Arquivos novos: `src/bosses/BossSlashAbility.gd`, `src/bosses/BossThrowPose.gd`, `tools/dev_tests/test_boss_corte.gd`, `tools/dev_tests/capture_boss_corte.gd`.
- Arquivos alterados: `BossAbility` (`telegraph_start`), `BossDefinition` (`slash`), `buggy_definition.tres`, `BossBrain` (`flee_rate`), `BossController` (decisão), `BossCombat` (corte), `BossVisual` (linha, frente do cliente, pose), `BossTelegraph` (início da marca), `YoruWave` (cores opcionais), `test_boss_network`.
- Validação: corte 26/0, rede 22/0, ciclo 54/0, recepção 23/0, capturas inspecionadas. Bateria rápida em `art_src/validation/buggy_boss/corte/rapido.log`.
- Próximo passo: jogar e calibrar `flee_speed` e o cooldown.

## Andar + clique empurrava o Boss — 13/09/2026

- Variações de WASD apagadas; contextuais, Aú e Mink contam como M1 no Boss. Detalhes em PROGRESS e `docs/erros.md`.
- Validação: recepção 31/0; contextuais, combo, launcher e counter OK. Bateria rápida 75/10/1 com as mesmas 10 falhas e a mesma contagem de problemas (`art_src/validation/buggy_boss/rapido_wasd.log`).
- Não alterados: queda esmagadora e Asas de Anjo ainda empurram o Boss.

## Punho destacado após os jabs — 13/09/2026

- Usuário confirmou os socos e o corte feitos com Claude e pediu próximo passo. Escolheu **punho destacado como continuação dos jabs** (incremento 4).
- Implementados `BodyPartDefinition`, `BossHandBinding`, `BossDetachedAbility`, `BossDetachedAttack`; integração mínima em Actor/Combat/Visual/Definition/Encounter e quinto golpe na definição Buggy.
- Separação real no pulso direito, com tampas e skin/UV/materiais preservados. Fonte `tools/build_buggy_hand.gd`; três `.res` e binding em `assets/models/bosses/buggy/detached/`. SHA do GLB original inalterado.
- Dano 112 só na ida; trajetória/aviso bloqueados por paredes; retorno sem dano; interrupção recolhe; morte limpa; estado/transform replicados e entrada tardia em voo testada.
- Parte 28/0 (inclui IA com física real); rede 32/0; jabs 54/0; recepção 31/0; corte 26/0. Capturas reais e comparação do pulso com o original inspecionadas. Bateria rápida: **76 aprovados / 10 falhas / 1 pulado**, mesmos dez testes com falha da base completa de recepção. Logs em `art_src/validation/buggy_detached/`; detalhes em `BOSS_BUGGY_DETACHED.md`.
- Próximo passo do roadmap: captura com soltura garantida; demais partes e fases ainda pendentes. Preservar o combo/corte/reação desenvolvidos com Claude e o binding configurável da mão.

## Alcance, arremesso do jogador e flash — 13/09/2026

- Encostado conta como alcance; jabs sem knockback; o último golpe que sai arremessa (punho destacado ou 4º soco); passo de boxeador; cápsula no Boss; derrubada do jogador em `src/player/player_arremesso.gd`; `FxUtil.flash_dano` no jogador e no Boss.
- Validação: arremesso 34/0, rede 34/0, ciclo 54/0, recepção 31/0, corte 26/0, punho destacado 28/0; 5 capturas inspecionadas; bateria rápida 77/10/1 com as mesmas 10 falhas e contagens (`art_src/validation/buggy_boss/arremesso_flash/rapido.log`).
- Próximo passo: jogar e calibrar `STEP_SPEED` (5 m/s) e a sensação do arremesso.

## Equipe de agentes para IA do Boss — 13/09/2026

- Plano `docs/PLANO_BOSS_IA.md`; gerador `tools/agentes/gerar_agentes_boss.py` (8 agentes boss-*, portas 25000-25070).
- Nenhuma onda executada. Próximo passo: onda 1 (`boss-auditor-linha-base`), após o dono decidir se roda já (agente genérico lendo o .md) ou depois de reiniciar a sessão.

- Onda 1 concluída (13/09 19:15): LINHA_DE_BASE.md com 5 bots × 4 rodadas; régua determinística com `--hitstop=0` (conferido: circulo repetido = CSV idêntico). Achados A1 (leash descarta alvo arremessado), A2/A3 (círculo: combo nunca fecha, 35% perseguindo sem atacar), A4 (kite: M1 do jogador paralisa antes do jab). Metas em revisão pelo dono antes da onda 2.
- Complemento onda 1 (13/09): bot zigzag (±35°, troca a cada 1,5 s) → corte acerta 23,8% (5/21; meta ≥ 50%), conferido por repetição (CSV idêntico). Achado A9: o bot kite MATA o Boss em 151 s (Boss faz 9,5 DPS; jab 0 contatos). Alvos −40%: strafe ≤ 46,8 s, circulo ≤ 45,0 s. Régua md5 77a72550. Próximo: onda 2 (boss-percepcao), aguardando ok do dono.

## Detecção de projéteis, dash e pulo duplo — 13/09/2026

- `BossProjectileSensor` (Area3D r 12 m) + `BossMobility` (dash 4 m/0,22 s, recarga 3 s; pulo duplo 12+10 m/s p/ rasteiro, alto, buraco 10 m). Fora das ondas, a pedido do dono; plano e agentes atualizados.
- Validação: mobilidade 21/0 (inclui flecha de gelo real), rede 36/0, demais testes do Boss sem falha, 4 capturas inspecionadas, bateria rápida 78/10/1 com as mesmas 10 falhas e contagens (`art_src/validation/buggy_boss/mobilidade/rapido.log`).
- Pendente: onda 2 (`boss-percepcao`) aguardando ok do dono.
