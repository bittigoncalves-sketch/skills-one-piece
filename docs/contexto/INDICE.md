# Índice do código — onde está e quanto pesa

> **Gerado** por `python3 tools/contexto/indice.py construir` — não edite à mão (a próxima
> construção apaga). Para achar código por assunto: `python3 tools/contexto/indice.py buscar "..."`.

505 arquivos `.gd` de jogo e ferramentas (108.089 linhas; sem `tools/dev_tests/`).
agrupados pela área do contexto (`docs/contexto/<area>.md`).

**Relevância ★1–★5** = 0,55·fan-in + 0,20·tamanho + 0,15·testes + 0,10·entrada (log, 0–1),
em faixas por posição (★5 = 5% do topo). **fan-in** = arquivos de jogo que o citam;
**testes** = `test_*.gd` que o citam. Arquivo com ★ alto e 0 testes é risco: muita gente
depende dele e nada o vigia.

| área | arquivos | linhas | ★5 | ★4 |
|---|---:|---:|---:|---:|
| [Núcleo e jogador](#nucleo) | 49 | 14172 | 3 | 8 |
| [Combate da arena](#combate) | 27 | 6657 | 5 | 3 |
| [Frutas e técnicas](#frutas) | 65 | 18301 | 3 | 6 |
| [Personagem, rig e animação](#personagem) | 36 | 8788 | 3 | 4 |
| [Modo História](#historia) | 98 | 18289 | 5 | 13 |
| [Mundo e editor de mapa](#mundo) | 37 | 9977 | 3 | 4 |
| [Chefes e IA](#bosses) | 19 | 1933 | 0 | 0 |
| [Rede e multiplayer](#rede) | 6 | 446 | 0 | 1 |
| [Interface e HUD](#interface) | 44 | 8468 | 1 | 6 |
| [Visual, VFX e áudio](#visual) | 11 | 1164 | 1 | 1 |
| [Ferramentas, testes e pipeline](#ferramentas) | 86 | 12909 | 0 | 0 |
| [Geral](#geral) | 27 | 6985 | 1 | 4 |

## Núcleo e jogador <a id="nucleo"></a>

Contexto: [`nucleo.md`](agentes/nucleo.md) (agentes) · [`nucleo.md`](pessoas/nucleo.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 5 | `Player.gd` | 5367 | 122 | 43 | O jogador: casca que liga entrada, movimento, câmera, combate, rede e apresentação (partição em docs/ARQUITETURA_PLAYER.md) |
| 5 | `autoload/GameFlow.gd` | 376 | 18 | 143 | GameFlow (AUTOLOAD) — fachada única dos 3 modos do jogo. |
| 5 | `src/player/player_rig.gd` (PlayerRig) | 452 | 14 | 5 | PLAYER RIG — o CORPO VISÍVEL do jogador: montar, medir, vestir. |
| 4 | `src/mechanics/RecepcaoDeDano.gd` | 208 | 12 | 0 | ANIMAÇÃO DE RECEPÇÃO DE DANO — a mecânica que NÃO EXISTIA. |
| 4 | `src/player/move_frame.gd` (MoveFrame) | 132 | 11 | 3 | MOVE FRAME — o que o jogador PEDIU neste quadro. |
| 4 | `src/entities/TrainingDummy.gd` | 213 | 10 | 16 | Boneco de treino (Fase 9) — usa o CORPO DO PLAYER (base). Fica imóvel no centro |
| 4 | `src/player/mira.gd` (Mira) | 101 | 10 | 3 | MIRA — para onde se aponta, e de onde o tiro sai. |
| 4 | `src/match/Scoreboard.gd` | 359 | 7 | 5 | PLACAR DA RODADA — kills, mortes e cronômetro. SERVIDOR-AUTORIDADE. |
| 4 | `src/player/melee_controller.gd` (MeleeController) | 349 | 6 | 3 | CORPO A CORPO — o combo do clique: soco direito, soco esquerdo, chute. |
| 4 | `src/entities/AutoDummy.gd` | 155 | 5 | 20 | Colorir o dummy de vermelho para diferenciar |
| 4 | `src/player/cast_controller.gd` (CastController) | 1303 | 4 | 5 | CAST — decidir SE e COMO conjurar. Passo 6c de docs/AUDITORIA_FASE6.md. |
| 3 | `src/mechanics/Knockback.gd` | 98 | 7 | 0 | KNOCKBACK — horizontal e vertical, num lugar só. |
| 3 | `src/player/hsm/PlayerState.gd` | 21 | 7 | 0 |  |
| 3 | `src/player/dash_controller.gd` (DashController) | 147 | 5 | 3 | ROLL — a esquiva do Q (era o DASH até 03/10/2026). |
| 3 | `src/player/health_controller.gd` (HealthController) | 195 | 5 | 1 | VIDA, ENERGIA E EMPURRÃO. |
| 3 | `src/player/capacidades.gd` (CapacidadesDoJogador) | 59 | 4 | 12 | CAPACIDADES DO JOGADOR — o que o corpo tem PERMISSÃO de fazer. |
| 3 | `src/player/camera_rig.gd` (CameraRig) | 283 | 3 | 2 | CAMERA RIG — a câmera do jogador e tudo que se sente através dela. |
| 3 | `src/utils/PlayerModelKit.gd` | 145 | 3 | 8 | Helpers SEM ESTADO extraídos do Player.gd: construção da pistola voxel, medição |
| 2 | `src/player/disparo_sustentado.gd` (DisparoSustentado) | 159 | 3 | 0 | DISPARO SUSTENTADO — a rajada Z (Mera/Hie) e a pistola da Yami. |
| 2 | `src/player/hsm/CombatStateIdle.gd` | 26 | 3 | 0 | PARADO — o estado em que tudo é permitido: mover, atacar, esquivar, (em |
| 2 | `src/player/BaraNetwork.gd` | 62 | 2 | 0 | Validação/custos e reconstrução tardia. RPCs ficam no caminho estável Player. |
| 2 | `src/player/buki_controller.gd` (BukiController) | 342 | 2 | 0 | BUKI BUKI NO MI — o arsenal: sacar, mirar, atirar, guardar. |
| 2 | `src/player/fall_impact_controller.gd` (FallImpactController) | 80 | 2 | 2 | Queda que ultrapassa a altura do pulo normal: poeira, pedrinhas e rachaduras |
| 2 | `src/player/hsm/CombatStateStunned.gd` | 47 | 2 | 0 | ATORDOADO — o estado que era REFERENCIADO EM SETE LUGARES E NÃO EXISTIA. |
| 2 | `src/player/hsm/PlayerStateMachine.gd` | 40 | 2 | 0 |  |
| 2 | `src/player/parkour_controller.gd` (ParkourController) | 250 | 2 | 0 | PARKOUR — os movimentos que usam o cenário: vault, salto longo, wall run, |
| 2 | `src/player/voo_foguete.gd` (VooFoguete) | 220 | 2 | 1 | BLAST OFF — o voo curto da Rocket (tecla F), Modo História. |
| 2 | `src/utils/TargetSystem.gd` | 83 | 2 | 0 | Sistema Genérico de Aquisição de Alvo |
| 2 | `src/match/AguaDaArena.gd` | 125 | 1 | 1 | A ÁGUA QUE ALAGA A ARENA no fim da rodada. |
| 2 | `src/player/OpeWeapon.gd` | 106 | 1 | 1 | Kikoku cerimonial: acompanha o dorso e o porte do avatar, sem tocar no combate. |
| 2 | `src/player/YoruNetwork.gd` | 248 | 1 | 0 | O nó de rede pertence ao servidor mesmo quando o Player pertence ao cliente. |
| 2 | `src/player/afterimage_trail.gd` (AfterimageTrail) | 76 | 1 | 2 |  |
| 2 | `src/player/asas_de_anjo.gd` (AsasDeAnjo) | 114 | 1 | 1 | ASAS DE ANJO — o golpe exclusivo do Skypean. |
| 2 | `src/player/corrida_na_parede.gd` | 245 | 1 | 0 | CORRIDA NA PAREDE (wall run) — fatia 2 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md |
| 2 | `src/player/escalada.gd` | 244 | 1 | 0 | ESCALADA FRONTAL — fatia 3 de docs/PARKOUR_MIRRORS_EDGE_PLANO.md (03/10/2026). |
| 2 | `src/player/gear2_controller.gd` (Gear2Controller) | 243 | 1 | 0 | GEAR 2 — a primeira TRANSFORMAÇÃO do jogo. |
| 2 | `src/player/locomocao_chao.gd` | 251 | 1 | 0 | LOCOMOÇÃO NO CHÃO — arrancada, frenagem, giro e curva (02/10/2026). |
| 2 | `src/player/player_arremesso.gd` (PlayerArremesso) | 153 | 1 | 4 | Arremesso com derrubada do JOGADOR (4º soco do Boss): voa de costas, cai |
| 2 | `Main.gd` | 323 | 0 | 1 | SKILLS ONE PIECE — orquestrador (mantido FINO de propósito). |
| 1 | `src/entities/PickupSpawner.gd` | 63 | 1 | 0 | Coletáveis de Akuma no Mi (adições), posicionados por fórmula: anel paramétrico. |
| 1 | `src/player/deslize.gd` | 115 | 1 | 0 | DESLIZE (Ctrl) — 03/10/2026. |
| 1 | `src/player/foot_dust_controller.gd` | 68 | 1 | 0 | Poeira de deslocamento: cartões 2D pequenos, sem física e sem hitbox. |
| 1 | `src/player/hsm/CombatStateAttackActive.gd` | 30 | 1 | 0 | ATIVO — a hitbox está no ar. |
| 1 | `src/player/hsm/CombatStateAttackRecovery.gd` | 57 | 1 | 0 | RECUPERAÇÃO — o rabo do golpe. O corpo ainda está preso, mas é AQUI que o |
| 1 | `src/player/hsm/CombatStateAttackStartup.gd` | 47 | 1 | 0 | STARTUP — do clique até a hitbox nascer. |
| 1 | `src/player/hsm/CombatStateDashing.gd` | 7 | 1 | 0 |  |
| 1 | `src/player/iron_body_controller.gd` (IronBodyController) | 66 | 1 | 1 | CORPO DE FERRO — a "defesa avançada" da Fase 6 do plano de combate. |
| 1 | `src/player/mira_de_fruta.gd` | 153 | 1 | 0 | O INDICADOR DE MIRA da fruta (23/09/2026). Enquanto a tecla está pressionada, mostra |
| 1 | `src/player/phoenix_controller.gd` | 166 | 1 | 0 | Forma e voo pertencem à fruta; movimento é consumido pelo Player na locomoção. |

## Combate da arena <a id="combate"></a>

Contexto: [`combate.md`](agentes/combate.md) (agentes) · [`combate.md`](pessoas/combate.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 5 | `src/combat/DamageSpec.gd` | 149 | 39 | 5 | O QUE UM GOLPE É — a descrição que viaja pela pipeline de combate. |
| 5 | `src/combat/CombatResolver.gd` | 145 | 36 | 6 | O FUNIL. Todo dano do jogo passa por aqui — com hitbox ou sem. |
| 5 | `src/combat/Balance.gd` | 357 | 23 | 8 | A TABELA. Todo número de dano do jogo mora aqui, e só aqui. |
| 5 | `src/combat/alvos_de_golpe.gd` (AlvosDeGolpe) | 95 | 23 | 5 | ALVOS DE GOLPE — quem um golpe de fruta pode PROCURAR (05/10/2026). |
| 5 | `src/combat/Melee.gd` | 877 | 12 | 8 | CORPO A CORPO — simples e eficaz, no botão esquerdo do mouse. |
| 4 | `src/combat/StatusFX.gd` | 129 | 10 | 1 | STATUS DO PERSONAGEM — o registro do que está acontecendo com você AGORA. |
| 4 | `src/combat/FightingStyles.gd` | 334 | 8 | 2 | Estilos de Luta (Karate Tritão, Pacifista, Mink, Boxe, Cyborg). |
| 4 | `src/combat/SwordBlade.gd` | 314 | 5 | 5 | Sete esferas presas ao fio, varridas entre ticks no servidor. Uma passagem |
| 3 | `src/combat/SwordSweep.gd` | 100 | 9 | 0 | Varredura linear de cada esfera entre dois ticks. A cápsula cobre a translação |
| 3 | `src/combat/beam_visual_3d.gd` (BeamVisual3D) | 75 | 6 | 2 | Cilindro emissivo que ocupa exatamente o segmento global `inicio -> fim`. |
| 3 | `src/combat/mira_de_rocket.gd` | 82 | 4 | 1 | ONDE O GOLPE DA ROCKET VAI CAIR — uma conta só, usada por quem aplica o dano |
| 3 | `src/combat/BaraController.gd` | 364 | 3 | 2 | Uma ação corporal autoritativa; as cópias recebem o estado das mesmas mãos. |
| 3 | `src/combat/YoruController.gd` | 415 | 3 | 1 | Relógio físico único: nenhuma callback de timer pode ressuscitar um ataque. |
| 3 | `src/combat/YoruWave.gd` | 246 | 3 | 2 | Frente finita de corte. Z voa; V exige piso em cada avanço de até 20 cm. |
| 3 | `src/combat/boxing/BoxingPose.gd` | 92 | 3 | 2 | IK de dois segmentos: mantém comprimento dos ossos e mãos fechadas do asset. |
| 3 | `src/combat/contextual_melee.gd` (ContextualMelee) | 502 | 3 | 4 | CORPO A CORPO CONTEXTUAL |
| 3 | `src/combat/OpeController.gd` | 466 | 2 | 2 | Cirurgia espacial. A esfera é estado persistente; os demais nós são casts |
| 3 | `src/items/YoruSword.gd` | 178 | 2 | 5 | GLB em metros: origem na pega direita, fio +Y, segunda pega -0,17 m. |
| 2 | `src/items/SwordPickup.gd` | 92 | 3 | 0 | Área de colisão (1 metro de raio) para detecção de passagem |
| 2 | `src/combat/YoruMoves.gd` | 23 | 2 | 2 | Tempos em segundos; dano final; distâncias em metros. Fonte única de gameplay. |
| 2 | `src/combat/laser_px.gd` (LaserPX) | 235 | 2 | 2 | PX LASER BEAM — o Z do estilo Pacifista. |
| 2 | `src/combat/px_thruster_lance.gd` (PXThrusterLance) | 191 | 1 | 0 | C do Pacifista. Preserva o cilindro amarelo de 15 m, a velocidade de 35 m/s |
| 2 | `src/combat/px_tri_beam.gd` (PXTriBeam) | 263 | 1 | 1 | Ultimate do Pacifista: os emissores da boca e das duas palmas convergem no |
| 2 | `src/combat/rocket_controller.gd` | 628 | 1 | 0 | Estado da Rocket no servidor. A autoridade do corpo NÃO decide trajetória/hit. |
| 2 | `src/combat/socos_de_ferro.gd` (SocosDeFerro) | 233 | 1 | 1 | PX IRON PUNCHES — o X do estilo Pacifista. |
| 1 | `src/combat/OpeDamageZone.gd` | 34 | 1 | 2 | A ROOM limita o acerto, inclusive se o adversário cruzar a borda enquanto |
| 1 | `src/combat/rocket_hitbox.gd` | 38 | 1 | 0 | Pulso cancelável: reutiliza o funil de dano, sem timer de gameplay. |

## Frutas e técnicas <a id="frutas"></a>

Contexto: [`frutas.md`](agentes/frutas.md) (agentes) · [`frutas.md`](pessoas/frutas.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 5 | `src/effects/FxUtil.gd` | 633 | 65 | 5 | Helpers para VFX 100% procedurais (sem texturas em disco): |
| 5 | `src/effects/DamageZone.gd` | 369 | 63 | 20 | Área de dano móvel: aplica dano + knockback em corpos com take_damage() (menos |
| 5 | `src/effects/AudioFX.gd` | 324 | 39 | 0 | Efeitos sonoros PROCEDURAIS (o projeto não tem assets de áudio). Gera WAVs curtos |
| 4 | `SkillSystem.gd` | 237 | 11 | 5 | SKILL SYSTEM — Definição e Execução de Habilidades (Z, X, C, V) |
| 4 | `TreeAndFruitGenerator.gd` | 626 | 10 | 3 | Gerador de 11 Árvores Místicas com Cores Únicas e Frutas 3D (Akuma no Mi) |
| 4 | `src/effects/FireFX.gd` | 458 | 9 | 0 | Geração de FOGO procedural e detalhada (Mera Mera no Mi). |
| 4 | `src/effects/BukiFX.gd` | 556 | 8 | 3 | BUKI FX — Buki Buki no Mi (fruta da Baby 5). Paramecia: o corpo vira arma. |
| 4 | `src/effects/IceFX.gd` | 524 | 7 | 3 | ICE FX — Geração de GELO procedural e detalhada (Hie Hie no Mi). |
| 4 | `src/effects/GoroFX.gd` | 508 | 6 | 1 | A coreografia da fruta. `preload` em vez de `class_name` pelo mesmo motivo |
| 3 | `src/effects/FxQuality.gd` | 36 | 5 | 1 | Orçamento visual por perfil. Não decide dano, hitbox nem telegraph essencial; |
| 3 | `src/effects/GomuAudio.gd` | 39 | 5 | 0 | Efeitos sonoros originais e determinísticos da Gomu Gomu no Mi, Gear 2 e Gear 3. |
| 3 | `src/effects/GoroFXGrande.gd` | 1142 | 5 | 0 | GORO GORO — OS DOIS ESPETÁCULOS: X (El Thor) e V (Mamaragan). |
| 3 | `src/effects/PikaAudio.gd` | 157 | 5 | 1 | Voz sonora da PIKA PIKA NO MI. |
| 3 | `src/effects/FireFXGrande.gd` | 532 | 4 | 0 | MERA MERA — OS GOLPES GRANDES. |
| 3 | `src/effects/GomuArm.gd` | 241 | 4 | 0 | Braço ELÁSTICO da Gomu Gomu (estilo Luffy). O OMBRO é a origem FIXA: o braço |
| 3 | `src/effects/YamiFX.gd` | 1046 | 4 | 0 | Geração visual e mecânica procedural da Yami Yami no Mi (Trevas / Gravidade Abissal). |
| 3 | `src/effects/GuraFX.gd` | 294 | 3 | 0 | Gura Gura no Mi (Tremor) — o foco é KNOCKBACK massivo (jogar pra fora do mapa). |
| 3 | `src/effects/GuraVNode.gd` | 512 | 3 | 1 | GURA GURA — V: "SEAQUAKE" (ultimate). REESCRITO DO ZERO em 2026-08-14. |
| 3 | `src/effects/MeraVfx.gd` | 118 | 3 | 1 | API visual da Mera Mera. O jogo continua dono da hitbox, da autoridade e do |
| 3 | `src/effects/era_do_gelo.gd` (EraDoGelo) | 444 | 3 | 1 | ERA DO GELO NO MODO HISTÓRIA — o V da Hie que CONGELA O LUGAR (10/10/2026). |
| 3 | `src/effects/rocket_vfx.gd` | 462 | 3 | 1 | Pool local de impactos, rastros, manchas, retículos e estilhaços. Só existe enquanto |
| 2 | `src/effects/BomuFX.gd` | 183 | 3 | 0 | Bomu Bomu no Mi — dois golpes explosivos, ambos carregáveis em 0,5 s. |
| 2 | `src/effects/GomuGatling.gd` | 123 | 3 | 0 |  |
| 2 | `src/effects/YoruAudio.gd` | 94 | 3 | 0 | Assinatura própria: ar cortado, aço ressonante e energia grave da Yoru. |
| 2 | `src/effects/YoruFX.gd` | 280 | 3 | 0 | Fagulhas de aço em ouro/verde; posição mundial fixa e vida finita. |
| 2 | `src/effects/BaraAudio.gd` | 40 | 2 | 0 | Sons mono produzidos offline. O limite por cena evita rajadas de V sobrepostas. |
| 2 | `src/effects/BukiProjeteis.gd` | 195 | 2 | 0 | A MUNIÇÃO DA BUKI BUKI — um modelo de bala por arma. |
| 2 | `src/effects/GomuFX.gd` | 305 | 2 | 1 | Geração visual e física procedural da Gomu Gomu no Mi (Borracha / Gear 3rd). |
| 2 | `src/effects/GomuRedHawk.gd` | 239 | 2 | 0 |  |
| 2 | `src/effects/GoroAudio.gd` | 61 | 2 | 0 | Assets mono de 48 kHz, sintetizados offline por `tools/generate_goro_audio.py`; |
| 2 | `src/effects/GuraShatterMesh.gd` | 78 | 2 | 0 | Gera um mesh 3D procedural usando SurfaceTool que simula o ar "rachando" no impacto. |
| 2 | `src/effects/MeraEmberBody.gd` | 170 | 2 | 1 | Corpo QUENTE e persistente da Mera: o punho do Hiken e o sol do Entei. |
| 2 | `src/effects/MeraGeometry.gd` | 261 | 2 | 1 | Geometria de fogo própria da Mera Mera. Malha e shader — sem partícula e sem |
| 2 | `src/effects/OpeAudio.gd` | 34 | 2 | 0 | Assets mono de 48 kHz, sintetizados offline; nenhuma síntese no frame de cast. |
| 2 | `src/effects/OpeGeometry.gd` | 104 | 2 | 0 | Original surgical geometry shared by the Ope effects. No particles or dynamic lights. |
| 2 | `src/effects/OpeSurgicalBurst.gd` | 193 | 2 | 0 | Spatial surgery has a precise silhouette: brackets, interrupted arcs and |
| 2 | `src/effects/OpeVfx.gd` | 65 | 2 | 0 | Visual API. Gameplay owns hit detection, authority and ROOM lifetime. |
| 2 | `src/effects/SandFX.gd` | 424 | 2 | 1 | Geração de AREIA procedural e detalhada para a Suna Suna no Mi. |
| 2 | `src/effects/SandTornado.gd` | 109 | 2 | 0 | X — Sables: comportamento do TORNADO de areia (a ref pede: puxa, levanta e causa |
| 2 | `src/effects/SeismicOrb.gd` | 59 | 2 | 0 | Esfera externa (vidro/distorção) |
| 2 | `src/effects/WaterFX.gd` | 701 | 2 | 0 | KARATE TRITÃO — a água como ARMA, não como enfeite. |
| 2 | `src/effects/phoenix/forma_phoenix.gd` | 427 | 2 | 1 | Fênix completa. Fonte autoral volumétrica e rig de pivôs rígidos. |
| 2 | `src/effects/phoenix/geometria_phoenix.gd` | 58 | 2 | 0 | Geometria autoral em unidades de jogo: seções de corpo, penas e fitas curvas. |
| 2 | `src/effects/phoenix/plumagem_phoenix.gd` | 192 | 2 | 0 | Fonte editável da plumagem: volumes fechados, sem cartões nem deformação. |
| 2 | `FruitPassiveSystem.gd` | 194 | 1 | 0 | Sistema de Habilidades Passivas das Akuma no Mi (Godot 4) |
| 2 | `src/effects/BaraVfx.gd` | 211 | 1 | 0 | Apresentação da Bara: marfim/magenta nas mãos e pólvora quente no canhão. |
| 2 | `src/effects/FirefliesFX.gd` | 227 | 1 | 0 | Controla o spawn e a reação em cadeia dos vagalumes de fogo |
| 2 | `src/effects/GomuGear3Punch.gd` | 271 | 1 | 0 | Gomu Gomu no Gear 3: Gigant Pistol (Soco Gigante). |
| 2 | `src/effects/MeraFireBurst.gd` | 208 | 1 | 1 | Fogo TRANSITÓRIO da Mera: clarão de cano, impacto, explosão e a marca no chão. |
| 2 | `src/effects/PikaFX.gd` | 716 | 1 | 2 | PIKA PIKA NO MI — a fruta da LUZ. |
| 2 | `src/effects/PikaFXGrande.gd` | 969 | 1 | 2 | C/V da Pika Pika. A densidade visual e a quantidade de hitboxes são |
| 2 | `src/effects/forma_de_foguete.gd` | 354 | 1 | 0 | FORMA DE FOGUETE — no Blast Off (F, Modo História) o jogador VIRA o foguete. |
| 2 | `src/effects/magu/tecnica_magu.gd` | 467 | 1 | 0 | Relógio e estados por conjuração. Dano só no servidor; visuais em cada peer. |
| 2 | `src/effects/magu/visual_magu.gd` | 259 | 1 | 0 | Fonte procedural editável; modelo canino já pertencente ao acervo do jogo. |
| 1 | `src/effects/AirSlamFX.gd` | 49 | 1 | 0 | Chute aéreo: pressão comprimida abre em anéis baixos e poeira, enquanto a |
| 1 | `src/effects/BurnStatus.gd` | 55 | 1 | 1 | A conjuração que acendeu a queimadura. Passar por ela mantém o dano por tempo |
| 1 | `src/effects/OpeRoomField.gd` | 86 | 1 | 0 | A transparent operative volume. Eight-pixel-like rim, sparse latitude wires; |
| 1 | `src/effects/OpeTaktVolley.gd` | 173 | 1 | 0 | Five rocks are staged here, but gameplay alone launches/stops them. World |
| 1 | `src/effects/PikaLightImpact.gd` | 46 | 1 | 0 | Clarão compartilhado pelos impactos do Yasakani e da Chuva de Luz. |
| 1 | `src/effects/SpinKickFX.gd` | 61 | 1 | 1 | Rastro preto e branco do chute giratório: duas faixas em sentidos opostos, |
| 1 | `src/effects/Tumbleweed.gd` | 55 | 1 | 0 |  |
| 1 | `src/effects/contextual_melee_fx.gd` (ContextualMeleeFX) | 112 | 1 | 0 | Apresentação leve para W/A/S/D. O nó fica preso ao atacante, portanto a |
| 1 | `src/effects/phoenix/efeito_phoenix.gd` | 85 | 1 | 0 | Efeito finito: relógio local cancelável e hitbox no funil autoritativo comum. |
| 1 | `src/effects/phoenix/labaredas_phoenix.gd` | 38 | 1 | 0 | Fonte de volumes de fogo: seção lenticular fechada sobre Bézier. |
| 1 | `src/effects/BaraFX.gd` | 12 | 0 | 0 | Entrada de compatibilidade para ferramentas: o kit antigo foi removido. |

## Personagem, rig e animação <a id="personagem"></a>

Contexto: [`personagem.md`](agentes/personagem.md) (agentes) · [`personagem.md`](pessoas/personagem.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 5 | `src/customizacao/Corpo.gd` | 86 | 38 | 6 | CORPO — traços do próprio personagem, não coisas vestidas. |
| 5 | `src/anim/ProceduralAnimator.gd` | 1754 | 27 | 12 | Animação PROCEDURAL em tempo real do rig articulado (nós, não skinado). |
| 5 | `src/customizacao/Visual.gd` | 297 | 24 | 5 | O QUE O JOGADOR ESCOLHEU — e a ÚNICA função que transforma isso num modelo. |
| 4 | `src/anim/BodyScanner.gd` | 118 | 11 | 8 | Fase 0 do sistema de animação procedural: VARRE o rig do personagem e mede o |
| 4 | `src/anim/GuraPoses.gd` | 446 | 7 | 1 | GURA GURA NO MI — as animações autorais dos quatro golpes. |
| 4 | `CharacterBuilder.gd` | 425 | 6 | 14 | CHARACTER BUILDER — Construtor Voxel 3D e Animações Procedurais (Godot 4) |
| 4 | `src/customizacao/Racas.gd` | 398 | 6 | 1 | RAÇAS — o que o corpo GANHA ou muda de proporção. |
| 3 | `src/customizacao/Paleta.gd` | 59 | 8 | 0 | AS CORES DE JOGADOR — dado puro, sem dependência de nada. |
| 3 | `src/anim/FruitPoses.gd` | 192 | 6 | 0 | POSES DE FRUTA — extraidas do ProceduralAnimator em 2026-08-14. |
| 3 | `src/anim/SkeletonDriver.gd` | 227 | 5 | 3 | Ponte entre o rig LÓGICO (13 papéis, nós-proxy) e um Skeleton3D real. |
| 3 | `src/anim/WeaponPoses.gd` | 293 | 5 | 0 | POSES DE ARMAS (Weapons) |
| 3 | `src/customizacao/Acessorios.gd` | 552 | 5 | 0 | CATÁLOGO DE ACESSÓRIOS — a fonte única do que se veste e de como se veste. |
| 3 | `src/customizacao/Adornos.gd` | 176 | 4 | 0 | O NÚCLEO COMUM DAS PEÇAS PENDURADAS NO CORPO. |
| 3 | `src/anim/GoroPoses.gd` | 201 | 3 | 1 | Coreografia autoral da GORO GORO NO MI. Tempo em segundos recebido do golpe; |
| 3 | `src/anim/RigDetalhado.gd` | 503 | 3 | 1 | RIG DETALHADO — as juntas que o personagem base ganhou em 08/09/2026. |
| 3 | `src/anim/SkeletalAnimator.gd` | 299 | 3 | 0 | Animador para personagens SKINNADOS (Skeleton3D + malha skinada, ex.: Meshy AI). |
| 3 | `src/anim/YoruRig.gd` | 410 | 3 | 2 | Curva da arma em coordenadas do rig; IK de dois segmentos sem esticar ossos. |
| 2 | `CharacterAnimator.gd` | 105 | 3 | 1 | Gerenciador da Máquina de Estados de Animações (Godot 4) |
| 2 | `VoxelMeshes.gd` | 358 | 2 | 0 | Construtores de MODELO VOXEL (rig por-nós) extraídos do CharacterBuilder: |
| 2 | `src/anim/MaguPoses.gd` | 59 | 2 | 0 | POSES DA MAGU MAGU NO MODO HISTÓRIA (14/10/2026). |
| 2 | `src/anim/PikaPoses.gd` | 73 | 2 | 0 | Poses autorais dos ataques de luz da Pika Pika. |
| 2 | `src/characters/CharacterVisualDefinition.gd` | 56 | 2 | 1 | Visual de ensaio. Não muda identidade, colisão, fruta ou autoridade do ator. |
| 2 | `src/anim/GomuPoses.gd` | 210 | 1 | 0 | Coreografia autoral da Gomu Gomu no Mi, Gear 2 e Gear 3. |
| 2 | `src/anim/OpePoses.gd` | 134 | 1 | 1 | Coreografia autoral do cirurgião: gesto deliberado, ação precisa, assentamento. |
| 2 | `src/anim/StudioPlayback.gd` | 108 | 1 | 1 | Authored studio clips use real node properties, isolated from legacy baked rotations. |
| 2 | `src/anim/rocket_poses.gd` | 120 | 1 | 1 | Ângulos autorais em graus; o animador aplica aos mesmos 13 papéis do rig. |
| 2 | `src/characters/BaraHandBinding.gd` | 182 | 1 | 1 | Partes visuais do Player. O combate fornece somente lado e transform global. |
| 2 | `src/customizacao/AsaLunar.gd` | 288 | 1 | 0 | AS ASAS NEGRAS DO LUNARIANO — em camadas de penas, e reagindo ao movimento. |
| 2 | `src/customizacao/MinkAnimado.gd` | 222 | 1 | 0 | Controlador de orelhas e caudas Mink penduradas no rig hierárquico. |
| 1 | `src/anim/BaraPoses.gd` | 126 | 1 | 0 | Coreografia em segundos: punho comprometido, pinça, artilharia e festival. |
| 1 | `src/anim/MeleePoses.gd` | 103 | 1 | 0 | POSES DO COMBO DESARMADO — postura de luta durante os clipes bakeados do |
| 1 | `src/anim/montaria_poses.gd` | 30 | 1 | 0 | Quadril no assento; pernas abraçam o animal, mãos apoiadas à frente. |
| 1 | `src/anim/nado_poses.gd` | 47 | 1 | 0 | Crawl do protagonista: entrada, apoio, puxada e recuperação com cotovelo alto. |
| 1 | `src/anim/navio_poses.gd` | 14 | 1 | 0 | Equilíbrio no convés e mãos à frente do posto de comando. |
| 1 | `src/anim/pesca_poses.gd` | 62 | 1 | 0 | PESCA (03/10/2026) — braços segurando a vara. Quem escolhe a pose é a `Pescaria` |
| 1 | `src/customizacao/ChamaLunar.gd` | 55 | 1 | 0 | A CHAMA DAS COSTAS DO LUNARIANO — 2D. |

## Modo História <a id="historia"></a>

Contexto: [`historia.md`](agentes/historia.md) (agentes) · [`historia.md`](pessoas/historia.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 5 | `src/historia/progressao.gd` (ProgressaoDoPersonagem) | 902 | 32 | 40 | PROGRESSÃO DO PERSONAGEM — o sistema de status do Modo História. Sem nó. |
| 5 | `src/combat/direcional/executor_corpo_a_corpo.gd` (ExecutorCorpoACorpo) | 824 | 16 | 10 | EXECUTOR DO COMBATE DIRECIONAL — Modo História. |
| 5 | `src/historia/agua/agua_do_mundo.gd` (AguaDoMundo) | 96 | 16 | 18 | ÁGUA DO MUNDO — onde há água e quanto de um corpo está dentro dela (01/10/2026). |
| 5 | `src/historia/frutas/perfil_de_frutas.gd` (PerfilDeFrutas) | 169 | 13 | 16 | OS NÚMEROS DE UMA FRUTA NO MODO HISTÓRIA. |
| 5 | `src/historia/ModoHistoria.gd` | 670 | 2 | 84 | MODO HISTÓRIA — orquestrador da cena (fino, como o `Main` da arena). |
| 4 | `src/combat/direcional/hurtbox_de_combate.gd` (HurtboxDeCombate) | 78 | 16 | 2 | HURTBOX DE COMBATE — o volume que o golpe ACERTA, separado do que o corpo |
| 4 | `src/combat/direcional/golpe_direcional.gd` (GolpeDirecional) | 159 | 12 | 13 | FICHA DE UM GOLPE — combate direcional do Modo História. |
| 4 | `src/historia/npcs/loja_de_npc.gd` (LojaDeNpc) | 47 | 10 | 3 | LOJA DE NPC — o que um NPC compra, vende ou dá (03/10/2026). Só regras: quem |
| 4 | `src/historia/pets/modo_do_pet.gd` (ModoDoPet) | 85 | 9 | 2 | OS COMPORTAMENTOS DE PET — livre, seguir, em guarda, agressivo (30/09/2026). |
| 4 | `src/historia/npcs/npc_da_ilha.gd` (NpcDaIlha) | 313 | 8 | 9 | NPC DA ILHA — os personagens com loja do Modo História (03/10/2026). |
| 4 | `src/combat/direcional/resolucao_de_contato.gd` (ResolucaoDeContato) | 100 | 7 | 6 | RESOLUÇÃO DE CONTATO — o que um golpe que tocou um corpo VIRA. |
| 4 | `src/historia/animais/animal_da_ilha.gd` (AnimalDaIlha) | 715 | 7 | 11 | ANIMAL DA ILHA — um bicho da categoria "Animais" vivendo no Modo História |
| 4 | `src/combat/direcional/boneco_de_duelo.gd` (BonecoDeDuelo) | 163 | 6 | 23 | BONECO DE DUELO — um oponente com o MESMO corpo e o MESMO executor do jogador. |
| 4 | `src/combat/direcional/estilo_corpo_a_corpo.gd` (EstiloCorpoACorpo) | 230 | 6 | 4 | ESTILO DE CORPO A CORPO — o conjunto de golpes que o executor usa. |
| 4 | `src/historia/missoes/missoes.gd` | 159 | 6 | 3 | MISSÕES DA ILHA (08/10/2026) — a tabela. O estado de cada uma mora no progresso |
| 4 | `src/historia/pesca/pescaria.gd` (Pescaria) | 429 | 6 | 1 | PESCARIA — o minigame de pesca do Modo História (03/10/2026). |
| 4 | `src/historia/animais/populacao_de_animais.gd` (PopulacaoDeAnimais) | 217 | 5 | 5 | POPULAÇÃO DE ANIMAIS — as áreas de animais do mapa viram bichos no Modo História |
| 4 | `src/historia/inimigo_do_mapa.gd` (InimigoDoMapa) | 176 | 5 | 6 | INIMIGO DO MAPA — peça `modelo` do Modo História cujo modelo está na categoria |
| 3 | `src/combat/direcional/chave_de_pose.gd` (ChaveDePose) | 109 | 5 | 1 | UMA POSE-CHAVE do combate direcional — um instante de um golpe (ou a guarda, |
| 3 | `src/historia/pesca/tabela_de_peixes.gd` (TabelaDePeixes) | 101 | 5 | 2 | TABELA DE PEIXES — o que a pesca sorteia (03/10/2026). |
| 3 | `src/historia/agua/jogador_na_agua.gd` (JogadorNaAgua) | 188 | 4 | 2 | JOGADOR NA ÁGUA — rasa, nado, mergulho e fôlego do personagem (01/10/2026). |
| 3 | `src/historia/animais/pet_domado.gd` (PetDomado) | 158 | 4 | 3 | PET DOMADO — o herbívoro que comeu a fruta e passou a seguir o jogador (01/10/2026). |
| 3 | `src/historia/frutas/tecnica_de_fruta.gd` (TecnicaDeFruta) | 41 | 4 | 1 | UMA TÉCNICA DE FRUTA NO MODO HISTÓRIA — a ficha, não o código do golpe. |
| 3 | `src/historia/npcs/npcs_da_ilha.gd` (NpcsDaIlha) | 95 | 4 | 5 | NPCs DA ILHA — os personagens postos no mapa pela loja (aba "NPCs") ganham |
| 3 | `src/historia/pesca/tensao_da_linha.gd` (TensaoDaLinha) | 118 | 4 | 1 | TENSÃO DA LINHA — a briga com o peixe fisgado, sem nada de cena (03/10/2026). |
| 3 | `src/combat/direcional/aplicador_de_pose.gd` (AplicadorDePose) | 453 | 3 | 1 | APLICADOR DE POSE — leva a pose do combate ao corpo, DEPOIS do animador. |
| 3 | `src/combat/direcional/ator_de_combate.gd` (AtorDeCombate) | 121 | 3 | 3 | O QUE O EXECUTOR PRECISA SABER DE UM CORPO — e só isso. |
| 3 | `src/combat/direcional/cerebro_de_inimigo.gd` (CerebroDeInimigo) | 211 | 3 | 1 | CÉREBRO DE INIMIGO — o boneco de duelo como inimigo do mapa (30/09/2026). |
| 3 | `src/combat/direcional/cerebro_de_treino.gd` (CerebroDeTreino) | 82 | 3 | 2 | CÉREBRO DE TREINO — a DECISÃO mais simples que faz um boneco lutar. |
| 3 | `src/combat/direcional/entrada_corpo_a_corpo.gd` (EntradaCorpoACorpo) | 224 | 3 | 4 | ENTRADA DO COMBATE DIRECIONAL — o jogador DECIDE aqui; o executor executa. |
| 3 | `src/combat/direcional/pose_de_combate.gd` (PoseDeCombate) | 208 | 3 | 1 | AVALIAÇÃO DA POSE — tempo de um golpe → pose do corpo. Função PURA. |
| 3 | `src/historia/corrida/corrida_de_caranguejos.gd` (CorridaDeCaranguejos) | 643 | 3 | 1 | CORRIDA DE CARANGUEJOS — o controlador (06/10/2026). |
| 3 | `src/historia/ninho_de_inimigo.gd` (NinhoDeInimigo) | 134 | 3 | 2 | NINHO DE INIMIGO — o lugar do mapa onde um inimigo que LUTA nasce e renasce. |
| 3 | `src/historia/pets/caranguejo.gd` | 302 | 3 | 0 | Companheiro do modo história. A raiz resolve física; o visual encara de lado. |
| 3 | `src/historia/corrida/pista_dos_caranguejos.gd` (PistaDosCaranguejos) | 486 | 2 | 1 | PISTA DOS CARANGUEJOS — o circuito da corrida, em DADO (06/10/2026). |
| 3 | `src/historia/navios/barco.gd` | 337 | 2 | 3 | Corpo vertical: yaw controla rumo; modelo, conves e leme acompanham as ondas. |
| 2 | `src/historia/ilhas/ilhas.gd` | 68 | 4 | 0 | ILHAS DO MODO HISTÓRIA (08/10/2026) — o cadastro: nome, baseplate e teto de nível. |
| 2 | `src/historia/pets/catalogo_de_pets.gd` (CatalogoDePets) | 49 | 4 | 0 | AS ESPÉCIES DE PET DO MODO HISTÓRIA — um lugar só (30/09/2026). |
| 2 | `src/combat/direcional/apresentacao_de_combate.gd` (ApresentacaoDeCombate) | 108 | 3 | 0 | APRESENTAÇÃO DO COMBATE DIRECIONAL — som e câmera, a partir dos sinais. |
| 2 | `src/combat/direcional/ator_jogador.gd` (AtorJogador) | 57 | 3 | 1 | ADAPTADOR DO JOGADOR para o executor do combate direcional. |
| 2 | `src/historia/pets/ficha_montaria.gd` | 50 | 3 | 1 | A categoria da loja é a classificação editável. Apenas pets vivos podem usá-la. |
| 2 | `src/historia/pomar/fruta_na_mao.gd` (FrutaNaMao) | 115 | 3 | 1 | FRUTA NA MÃO — a fruta do pomar que o jogador tirou do inventário (01/10/2026). |
| 2 | `src/historia/bestas_mar/colisao_agua.gd` | 35 | 2 | 0 | Volume varrido compartilhado pelos dois ataques; o primeiro obstáculo para a água. |
| 2 | `src/historia/bosses/harpia/captura_vento.gd` | 283 | 2 | 1 | Um dono temporário do movimento por ser vivo. A IA não disputa a órbita nem |
| 2 | `src/historia/bosses/harpia/pose_harpia.gd` | 186 | 2 | 1 | Pose autoral sobre o rig original. O modifier roda APÓS o AnimationPlayer; |
| 2 | `src/historia/bosses/harpia/vento_harpia.gd` | 190 | 2 | 1 | Vento editável, sem simulação de gameplay. Relógio absoluto fornecido pelo dono. |
| 2 | `src/historia/navios/perfil_barco.gd` | 107 | 2 | 0 | Pontos medidos nos GLBs, antes da escala do editor. +Z é popa no ator. |
| 2 | `src/historia/pesca/vara_de_pesca_visual.gd` (VaraDePescaVisual) | 225 | 2 | 1 | VARA DE PESCA — o que se VÊ da pesca (03/10/2026): a vara na mão direita, a |
| 2 | `src/historia/pets/animador_caranguejo.gd` | 94 | 2 | 0 | Rig rígido de oito patas: o pé apoia durante metade do ciclo e volta pelo ar. |
| 2 | `src/historia/pets/locomocao_de_montaria.gd` | 91 | 2 | 0 | LOCOMOÇÃO DA MONTARIA — a conta que move um pet montado, numa fonte só (06/10/2026). |
| 2 | `src/historia/pomar/pomar_da_ilha.gd` (PomarDaIlha) | 165 | 2 | 1 | POMAR DA ILHA — frutas penduradas nas árvores frutíferas do mapa (01/10/2026). |
| 2 | `src/combat/direcional/cor_dos_bracos.gd` (CorDosBracos) | 134 | 1 | 1 | COR DOS BRAÇOS — azul defendendo, vermelho atacando (30/09/2026). |
| 2 | `src/combat/direcional/depuracao_de_combate.gd` (DepuracaoDeCombate) | 89 | 1 | 1 | DEPURAÇÃO DO COMBATE DIRECIONAL — painel opcional com o estado do executor. |
| 2 | `src/historia/animais/animador_de_animal.gd` (AnimadorDeAnimal) | 357 | 1 | 0 | ANIMADOR DE ANIMAL — o corpo dos animais da ilha em movimento (01/10/2026). |
| 2 | `src/historia/bestas_mar/besta_do_mar.gd` | 596 | 1 | 0 | Animais marinhos colocados pela loja: rotina costeira ou boss de projéteis. |
| 2 | `src/historia/bestas_mar/bolha_de_agua.gd` | 72 | 1 | 2 | Projétil não teleguiado: nasce na boca no quadro de disparo, para no cenário. |
| 2 | `src/historia/bestas_mar/raio_compressor.gd` | 92 | 1 | 1 | Jato sustentado preso à boca, direção travada no disparo e dano único por alvo. |
| 2 | `src/historia/bosses/harpia/combate_harpia.gd` | 526 | 1 | 0 | IA e movimento de habilidades. Efeitos e pose são apresentação, sem dano próprio. |
| 2 | `src/historia/bosses/harpia/harpia_da_ilha.gd` | 46 | 1 | 2 | Especialização só do boss Harpia: conserva vida, território e respawn da fauna. |
| 2 | `src/historia/bosses/harpia/tornado_vendaval.gd` | 153 | 1 | 2 | Relógio único de cinco segundos: capturar alguém nunca reinicia o tornado. |
| 2 | `src/historia/corrida/cores_dos_caranguejos.gd` | 113 | 1 | 1 | CORES DOS CARANGUEJOS RIVAIS (06/10/2026). |
| 2 | `src/historia/corrida/obstaculos_da_pista.gd` | 354 | 1 | 0 | OBSTÁCULOS DA PISTA — o que se mexe na corrida de caranguejos (06/10/2026). |
| 2 | `src/historia/corrida/piloto_de_caranguejo.gd` | 146 | 1 | 1 | PILOTO DE CARANGUEJO — a IA dos rivais da corrida (06/10/2026). |
| 2 | `src/historia/equipamentos/bicicleta_de_gelo.gd` | 228 | 1 | 0 | História offline. Usa a etapa exclusiva de montaria do Player e sua colisão real. |
| 2 | `src/historia/equipamentos/giro_da_espada.gd` | 193 | 1 | 0 | Z da espada da história: giro contínuo; primeiro inimigo ou novo Z encerra. |
| 2 | `src/historia/ilhas/lod_das_ilhas.gd` | 273 | 1 | 1 | DESENHO POR DISTÂNCIA DAS ILHAS (08/10/2026, docs/ILHA_DOS_MACACOS_PLANO.md, etapa 4). |
| 2 | `src/historia/navios/comando.gd` | 327 | 1 | 1 | Interação do piloto; a física e a flutuação continuam pertencendo ao barco. |
| 2 | `src/historia/navios/esteira.gd` | 144 | 1 | 1 | Espuma com orçamento fixo: uma malha, até 40 marcas, sem emissores por frame. |
| 2 | `src/historia/npcs/loja_de_frutas.gd` | 41 | 1 | 3 | LOJA DO VENDEDOR DE FRUTAS (03/10/2026) — as Akuma no Mi da arena (singleplayer) |
| 2 | `src/historia/pets/companhia.gd` | 267 | 1 | 2 | Os pets do jogador que estão FORA do inventário, um corpo por pet. Pets colocados no |
| 2 | `src/historia/pets/gaivota.gd` | 457 | 1 | 0 | GAIVOTA — pet do Modo História que VOA (30/09/2026). |
| 2 | `src/historia/pets/montaria.gd` | 254 | 1 | 0 | Dono exclusivo da física durante a montaria. A IA do pet fica suspensa e volta |
| 2 | `src/historia/pomar/fruta_no_chao.gd` (FrutaNoChao) | 76 | 1 | 1 | FRUTA NO CHÃO — a fruta que caiu da árvore e virou item (01/10/2026). |
| 1 | `src/combat/direcional/ator_boneco.gd` (AtorBoneco) | 28 | 1 | 0 | ADAPTADOR DO BONECO DE DUELO para o executor do combate direcional. |
| 1 | `src/combat/direcional/impacto_de_combate.gd` (ImpactoDeCombate) | 112 | 1 | 0 | IMPACTO VISUAL DO COMBATE DIRECIONAL — o que se VÊ no ponto do contato. |
| 1 | `src/historia/agua/luz_de_mergulho.gd` | 32 | 1 | 0 | Preenchimento local do fundo do mar. Não altera o ambiente do ciclo dia/noite. |
| 1 | `src/historia/agua/visual_sharkman.gd` | 85 | 1 | 0 | Adaptação ao rig da campanha: medidas em metros, sem usar a AABB de toda |
| 1 | `src/historia/bandidos/roupa_de_bandido.gd` | 126 | 1 | 0 | ROUPA DE BANDIDO — o manequim Base vestido de bandido (08/10/2026). |
| 1 | `src/historia/bestas_mar/animador.gd` | 124 | 1 | 0 | Os clipes vêm dos .blend/GLB. Aqui ficam blend, loops e relógio de gameplay. |
| 1 | `src/historia/bestas_mar/populacao.gd` | 60 | 1 | 0 | Peças da loja viram criaturas só no jogo. O arquivo do mapa permanece intacto. |
| 1 | `src/historia/bestas_mar/preparo_de_agua.gd` | 39 | 1 | 0 | Gotas convergem à boca: esfera para a salva, anéis para a compressão. |
| 1 | `src/historia/bosses/harpia/config_harpia.gd` | 28 | 1 | 0 | Parâmetros do encontro; dano final na escala de vida da campanha. |
| 1 | `src/historia/bosses/harpia/pulso_de_ar.gd` | 60 | 1 | 1 | Acento de contato/lançamento em espaço do mundo, sem hitbox ou dano. |
| 1 | `src/historia/bosses/harpia/voo_harpia.gd` | 162 | 1 | 0 | Voo da Harpia entre as pedras (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md). |
| 1 | `src/historia/coleta/coleta_de_madeira.gd` | 40 | 1 | 0 | Registro só no runtime: o editor continua editando os mesmos modelos e colisões. |
| 1 | `src/historia/coleta/vegetacao_coletavel.gd` | 173 | 1 | 0 | Vida em golpes, independente do nível/dano; relógio de jogo respeita pausa. |
| 1 | `src/historia/equipamentos/bicicleta_de_gelo_visual.gd` | 82 | 1 | 0 | Fonte editável da bicicleta: rodas raiadas, quadro diamantado, garfo e pedaleira. |
| 1 | `src/historia/equipamentos/espada_da_historia.gd` | 80 | 1 | 0 | Equipamento exclusivo da história: cliques no executor comum; Z em GiroDaEspada. |
| 1 | `src/historia/equipamentos/machado_da_historia.gd` | 102 | 1 | 0 | Usa o relógio/IK/cancelamento do combate, mas só colhe vegetação, sem dano a NPCs. |
| 1 | `src/historia/ilhas/detector_de_ilha.gd` | 49 | 1 | 0 | DETECTOR DE ILHA (08/10/2026) — em qual ilha o jogador está. |
| 1 | `src/historia/missoes/loja_de_missao.gd` | 79 | 1 | 0 | CONVERSA DE MISSÃO (08/10/2026) — o NPC da "?" amarela usa a mesma janela das lojas |
| 1 | `src/historia/navios/cais.gd` | 97 | 1 | 0 | Vaga no cais (10/10/2026): onde um barco comprado atraca, perto do vendedor de barcos. |
| 1 | `src/historia/npcs/loja_da_corrida.gd` | 48 | 1 | 1 | ORGANIZADOR DA CORRIDA — a "loja" que inscreve na corrida de caranguejos (06/10/2026). |
| 1 | `src/historia/npcs/loja_de_barcos.gd` | 85 | 1 | 0 | VENDEDOR DE BARCOS (10/10/2026) — vende os barcos dirigíveis, 1 moeda cada. |
| 1 | `src/historia/npcs/loja_do_domador.gd` | 63 | 1 | 1 | LOJA DO DOMADOR (03/10/2026) — vende animais de estimação novos, 1 moeda cada. |
| 1 | `src/historia/npcs/loja_do_pescador.gd` | 65 | 1 | 0 | LOJA DO PESCADOR (03/10/2026) — dá a vara de graça e COMPRA os peixes pescados. |
| 1 | `src/historia/pets/animador_gaivota.gd` | 125 | 1 | 0 | Animação procedural da gaivota (30/09/2026). Fonte da geometria: |
| 1 | `src/historia/pets/bolhas_caranguejo.gd` | 41 | 1 | 0 | Emissão finita, sem dano. Cada rajada vive 2,4 s, mesmo se o pet for recolhido. |

## Mundo e editor de mapa <a id="mundo"></a>

Contexto: [`mundo.md`](agentes/mundo.md) (agentes) · [`mundo.md`](pessoas/mundo.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 5 | `src/world/biblioteca_modelos.gd` (BibliotecaDeModelos) | 937 | 46 | 36 | BIBLIOTECA DE MODELOS — os .glb importados pela LOJA do editor de mapa. |
| 5 | `src/world/mapa_montador.gd` (MapaMontador) | 373 | 16 | 24 | MAPA MONTADOR — transforma um mapa já VALIDADO (`MapaArquivo`) em nós. |
| 5 | `src/world/mapa_arquivo.gd` (MapaArquivo) | 475 | 13 | 42 | MAPA EM ARQUIVO — ler, validar e gravar o formato de mapa do Modo História. |
| 4 | `src/editor_mapa/documento_mapa.gd` (DocumentoMapa) | 317 | 10 | 7 | DOCUMENTO DO MAPA — o mapa aberto no editor, em memória. Não cria nó. |
| 4 | `src/world/MapBuilder.gd` | 306 | 10 | 4 | Mapa base FIXO = plataforma cinza EM GRADE (com buracos quadrados) + blocos cinza. |
| 4 | `src/world/terreno_do_mapa.gd` (TerrenoDoMapa) | 475 | 8 | 7 | TERRENO DO MAPA — a peça `terreno`: relevo por alturas, em blocos (30/09/2026). |
| 4 | `src/world/RosaDosVentos.gd` | 460 | 7 | 4 | ROSA DOS VENTOS — os pontos invisíveis que dizem para onde é cada lado. |
| 3 | `src/editor_mapa/ui_estilo.gd` (EstiloDoEditor) | 63 | 7 | 0 | Estilo único dos painéis do editor de mapa: escuro e opaco o bastante para ler |
| 3 | `src/world/WorldEnv.gd` | 311 | 6 | 0 | O AR E A LUZ — Fase 1 de docs/PLANO_VISUAL.md |
| 3 | `src/editor_mapa/selecao.gd` (SelecaoDoEditor) | 75 | 5 | 2 | SELEÇÃO do editor de mapa — quais peças (e/ou o spawn) estão selecionadas. |
| 3 | `src/world/ficha_de_animal.gd` (FichaDeAnimal) | 95 | 5 | 7 | FICHA DE ANIMAL — como um animal da loja vive na ilha (01/10/2026). |
| 3 | `src/editor_mapa/historico.gd` (HistoricoDeEdicao) | 203 | 4 | 3 | HISTÓRICO — desfazer/refazer do editor de mapa. |
| 3 | `src/editor_mapa/miniaturas.gd` (GeradorDeMiniaturas) | 169 | 4 | 0 | MINIATURAS da loja — uma foto de cada modelo, tirada num SubViewport isolado. |
| 3 | `src/editor_mapa/operacoes.gd` (OperacoesDoEditor) | 550 | 4 | 2 | OPERAÇÕES do editor de mapa — tudo o que MUDA o documento, sem nó nenhum. |
| 3 | `src/world/fundo_do_mar.gd` (FundoDoMar) | 244 | 4 | 3 | FUNDO DO MAR — o chão embaixo do oceano (01/10/2026, docs/AGUA_PLANO.md). |
| 3 | `src/editor_mapa/gizmo.gd` (GizmoDoEditor) | 286 | 3 | 3 | GIZMO — as alças de MOVER (setas), ESCALAR (bolinhas nas faces) e GIRAR |
| 3 | `src/editor_mapa/pincel_de_relevo.gd` (PincelDeRelevo) | 268 | 3 | 1 | PINCEL DE RELEVO — esculpir e pintar os blocos `terreno` no editor (01/10/2026). |
| 3 | `src/world/oceano_historia.gd` | 189 | 3 | 4 | Oceano visual do modo história/editor. Bases vêm do documento, nunca de uma |
| 3 | `src/editor_mapa/vista_mapa.gd` (VistaDoMapa) | 498 | 2 | 3 | VISTA DO MAPA — o documento desenhado na cena, peça a peça, em tempo real. |
| 3 | `src/editor_mapa/EditorDeMapa.gd` | 941 | 0 | 7 | EDITOR DE MAPA — orquestrador (etapa 2 do Modo História, docs/MODO_HISTORIA.md). |
| 2 | `src/editor_mapa/gizmo_matematica.gd` (GizmoMatematica) | 92 | 3 | 1 | MATEMÁTICA DO GIZMO — funções puras, sem nó, para poderem ser testadas. |
| 2 | `src/editor_mapa/propriedades.gd` (PropriedadesDoEditor) | 393 | 2 | 0 | PROPRIEDADES — os números da seleção, editáveis. |
| 2 | `src/world/ficha_de_navio.gd` (FichaDeNavio) | 84 | 2 | 1 | FICHA DE NAVIO — as propriedades de um barco da loja (30/09/2026). |
| 2 | `src/editor_mapa/barra.gd` (BarraDoEditor) | 144 | 1 | 1 | BARRA DE FERRAMENTAS do editor de mapa (topo da tela). |
| 2 | `src/editor_mapa/camera_livre.gd` (CameraLivre) | 110 | 1 | 5 | CÂMERA LIVRE do editor — os comandos do Roblox Studio, para quem vem de lá: |
| 2 | `src/editor_mapa/editor_de_janelas.gd` (EditorDeJanelas) | 588 | 1 | 1 | EDITOR DE JANELAS — o modo "Janelas" do editor de mapa (05/10/2026). |
| 2 | `src/editor_mapa/importador_glb.gd` (ImportadorDeModelos) | 130 | 1 | 4 | IMPORTADOR DE .glb — do computador para a biblioteca da loja. Sem nó. |
| 2 | `src/editor_mapa/loja.gd` (LojaDoEditor) | 497 | 1 | 1 | LOJA — os modelos .glb importados, no lado esquerdo do editor (o equivalente à |
| 2 | `src/world/ciclo_dia_noite.gd` (CicloDiaNoite) | 195 | 1 | 1 | CICLO DE DIA E NOITE DO MODO HISTÓRIA (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md). |
| 1 | `src/editor_mapa/explorer.gd` (ExplorerDoEditor) | 141 | 1 | 0 | EXPLORER — a lista do que existe no mapa: o Spawn e as peças, na ordem do |
| 1 | `src/editor_mapa/painel_do_pincel.gd` (PainelDoPincel) | 112 | 1 | 0 | PAINEL DO PINCEL DE RELEVO — aparece embaixo, no centro, com a ferramenta |
| 1 | `src/world/BaraFruitPickup.gd` | 45 | 1 | 0 | Coletável autoral: três faixas fechadas; coleta e respawn pertencem ao FruitNet. |
| 1 | `src/world/GomuFruitPickup.gd` | 35 | 1 | 0 | Modelo 3D autoral da Gomu Gomu no Mi; contrato de coleta/respawn em FruitNet. |
| 1 | `src/world/GoroFruitPickup.gd` | 46 | 1 | 0 | Modelo autoral da Goro Goro; o contrato de coleta/respawn continua em FruitNet. |
| 1 | `src/world/OpeFruitPickup.gd` | 35 | 1 | 0 | Modelo autoral; o contrato de coleta/respawn continua em FruitNet. |
| 1 | `src/world/TreeScatter.gd` | 35 | 1 | 0 | Distribui árvores de forma ALEATÓRIA em cima de blocos do mapa. |
| 1 | `src/world/importacao/estilo_anime.gd` | 60 | 0 | 0 | ESTILO ANIME NA IMPORTAÇÃO — sombreamento em faixas + contorno (02/10/2026). |

## Chefes e IA <a id="bosses"></a>

Contexto: [`bosses.md`](agentes/bosses.md) (agentes) · [`bosses.md`](pessoas/bosses.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 3 | `src/bosses/BossAbility.gd` | 34 | 6 | 2 | Dados imutáveis; relógio, orçamento e cooldown vivem no BossCombat. |
| 3 | `src/bosses/BossSlashAbility.gd` | 29 | 5 | 1 | Corte à distância lançado quando o alvo FOGE. Preparação em duas partes: a mira |
| 3 | `src/bosses/BossActor.gd` | 119 | 4 | 0 | Recepção de M1 (BossHitReaction): fase, tempo na fase e nº do acerto seguido. |
| 3 | `src/bosses/BossHitReaction.gd` | 114 | 4 | 2 | Recepção do corpo a corpo (M1) do jogador. Autoridade do servidor. |
| 3 | `src/bosses/BossMobility.gd` | 268 | 4 | 1 | Dash de esquiva e pulo duplo do Boss. Autoridade do servidor. |
| 3 | `src/bosses/BossVisual.gd` | 192 | 4 | 2 |  |
| 3 | `src/bosses/BossCombat.gd` | 313 | 3 | 2 | Combo = sequência de golpes da definição (ability + followups). Cada soco é um |
| 2 | `src/bosses/BossDetachedAbility.gd` | 14 | 4 | 3 | Um punho real como finalizador do combo; só a ida causa dano. |
| 2 | `src/bosses/BossProjectileSensor.gd` | 92 | 3 | 1 | Área de detecção ao redor do Boss: enxerga os ataques do JOGADOR em voo e diz |
| 2 | `src/bosses/BossReactionPose.gd` | 98 | 3 | 0 | Animação procedural da recepção de M1 do Boss: tranco (1º/2º acerto), voo |
| 2 | `src/bosses/BossBrain.gd` | 66 | 2 | 0 | Velocidade com que o ALVO se afasta do Boss (m/s, suavizada). Mede o |
| 2 | `src/bosses/BossController.gd` | 104 | 2 | 0 |  |
| 2 | `src/bosses/BossDefinition.gd` | 55 | 2 | 0 | Corte à distância contra quem foge. Opcional. |
| 2 | `src/bosses/BossDetachedAttack.gd` | 131 | 2 | 1 | Estado da parte separado do estado do golpe: interrupção recolhe sem dano; |
| 2 | `src/bosses/BossTelegraph.gd` | 73 | 1 | 2 | Marca vermelha no chão com a área de alcance do soco em curso: a cápsula que o |
| 2 | `src/bosses/BossThrowPose.gd` | 88 | 1 | 1 | Arremesso do corte, como um lançamento de beisebol: a perna esquerda dobra e |
| 1 | `src/bosses/BodyPartDefinition.gd` | 13 | 1 | 0 | Binding editável de uma parte preparada; nenhuma malha de Buggy no código comum. |
| 1 | `src/bosses/BossEncounter.gd` | 82 | 1 | 0 | Registro de definições: identidade nunca é inferida de peer_id ou nome visual. |
| 1 | `src/bosses/BossHandBinding.gd` | 48 | 1 | 1 | Malhas derivadas no plano do punho; o GLB original permanece intacto. |

## Rede e multiplayer <a id="rede"></a>

Contexto: [`rede.md`](agentes/rede.md) (agentes) · [`rede.md`](pessoas/rede.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 4 | `network/FruitNet.gd` | 37 | 11 | 1 | FRUIT NET (AUTOLOAD) — sincroniza a coleta de frutas. |
| 3 | `network/NetworkConfig.gd` | 39 | 7 | 1 | Constantes da camada de rede. Único lugar a mudar para servidor dedicado |
| 3 | `network/ServerManager.gd` | 72 | 2 | 1 | SERVER MANAGER (AUTOLOAD) — a AUTORIDADE de rede. |
| 3 | `network/ClientManager.gd` | 60 | 1 | 1 | CLIENT MANAGER (AUTOLOAD) — o lado CLIENTE. |
| 2 | `network/LanDiscovery.gd` | 120 | 2 | 1 | DESCOBERTA AUTOMÁTICA NA REDE LOCAL — entrar sem digitar nada. |
| 2 | `network/ExposicaoPublica.gd` | 118 | 1 | 1 | ABRIR A PORTA PARA FORA — hospedar para quem não está na mesma casa. |

## Interface e HUD <a id="interface"></a>

Contexto: [`interface.md`](agentes/interface.md) (agentes) · [`interface.md`](pessoas/interface.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 5 | `src/ui/Estilo.gd` | 65 | 36 | 2 | O ESTILO DO HUD — Fase 6 de docs/PLANO_VISUAL.md |
| 4 | `src/ui/layout_de_janelas.gd` (LayoutDeJanelas) | 199 | 11 | 1 | LAYOUT DE JANELAS — o que o EDITOR DE JANELAS mudou nas janelas do Modo |
| 4 | `src/ui/estilo_da_historia.gd` (EstiloDaHistoria) | 138 | 9 | 1 | O VISUAL DOS PAINÉIS DO MODO HISTÓRIA — janela M, inventário N, menu B. |
| 4 | `src/ui/HistoriaHud.gd` | 590 | 8 | 13 | HUD DO MODO HISTÓRIA — o mínimo para jogar e sair, e nada da arena. |
| 4 | `src/ui/ToqueHud.gd` | 372 | 7 | 1 | CONTROLES DE TOQUE — o jogo jogável com os dedos. |
| 4 | `src/ui/JanelaDeStatus.gd` | 686 | 6 | 1 | Editor de janelas (05/10/2026): o id desta janela no layout salvo. |
| 4 | `src/ui/MainMenu.gd` | 660 | 3 | 1 | MENU PRINCIPAL — SKILLS ONE PIECE (Estilo Clean Claro) |
| 3 | `src/ui/BarraHud.gd` | 45 | 5 | 1 | A BARRA DO HUD — vida, energia, e o que mais vier. |
| 3 | `src/ui/Hud.gd` | 233 | 5 | 0 | HUD fino: monta a barra de técnicas, inventário, menu de personagens e o menu principal. |
| 3 | `src/ui/JanelaDeLoja.gd` | 151 | 5 | 1 | JANELA DE LOJA (03/10/2026) — a loja do NPC com quem o jogador falou (E). |
| 3 | `src/ui/AmmoHud.gd` | 259 | 4 | 0 | MUNIÇÃO NA TELA — canto inferior direito. |
| 3 | `src/ui/FerramentasDeTeste.gd` | 185 | 4 | 1 | Editor de janelas (05/10/2026): o id desta janela no layout salvo. |
| 3 | `src/ui/MatchHud.gd` | 185 | 4 | 0 | HUD DA RODADA — cronômetro (topo-direito), tabela de kills/mortes e o painel |
| 3 | `src/ui/PescaHud.gd` | 89 | 4 | 1 | HUD DA PESCA (03/10/2026) — o medidor da briga, à direita do centro da tela. |
| 3 | `src/ui/SkillBar.gd` | 285 | 4 | 1 | Barra de técnicas no canto inferior direito, no estilo do OnePiece-Voxel |
| 3 | `src/ui/StatusEffectsHud.gd` | 197 | 4 | 0 | STATUS NA TELA — canto superior direito. |
| 3 | `src/ui/VidaEnergiaHud.gd` | 99 | 4 | 1 | Editor de janelas (05/10/2026): o id desta janela no layout salvo. |
| 3 | `src/ui/CustomizacaoMenu.gd` | 542 | 3 | 0 | MENU DE CUSTOMIZAÇÃO — acessórios e cor, com o personagem no meio. |
| 3 | `src/ui/TecnicasHud.gd` | 181 | 3 | 2 | AS TÉCNICAS DO ITEM ATIVO NA TELA — Modo História (22/09/2026). |
| 3 | `src/ui/InventarioDaHistoria.gd` | 501 | 2 | 4 | INVENTÁRIO DO MODO HISTÓRIA — tecla N (30/09/2026). |
| 2 | `src/ui/MenuDeComportamento.gd` | 87 | 3 | 1 | Editor de janelas (05/10/2026): o id desta janela no layout salvo. |
| 2 | `src/ui/StatsHud.gd` | 160 | 3 | 0 | HUD de status do jogador: barra de VIDA (verde, máx 2048), barra de ENERGIA (azul, |
| 2 | `src/ui/barras_de_chefes.gd` (BarrasDeChefes) | 97 | 3 | 1 | VIDA DOS CHEFES NO TOPO DA TELA (Modo História, 08/10/2026). |
| 2 | `src/ui/BarraDeItensHud.gd` | 135 | 2 | 2 | BARRA DE ITENS (1–6) — centro inferior do Modo História (03/10/2026). |
| 2 | `src/ui/CharacterMenu.gd` | 275 | 2 | 1 | Menu de PERSONAGENS CENTRALIZADO na tela (mesmo estilo da barra de técnicas: |
| 2 | `src/ui/DummyToggleHud.gd` | 154 | 2 | 0 | BONECOS DE TREINO — interruptor no canto inferior direito (2026-08-23). |
| 2 | `src/ui/PreviaDoPersonagem.gd` | 201 | 2 | 0 | A PRÉVIA 3D DO PERSONAGEM — o modelo de verdade num mundo só dele. |
| 2 | `src/ui/SpinKickHud.gd` | 62 | 2 | 1 | Recarga da aú: quarto quadrado da faixa superior, com ícone de giro. |
| 2 | `src/ui/TravaFrutaHud.gd` | 81 | 2 | 0 | Trava pós-fruta: o quinto quadrado da faixa superior. |
| 2 | `src/ui/catalogo_de_janelas.gd` (CatalogoDeJanelas) | 149 | 1 | 1 | CATÁLOGO DE JANELAS — as janelas do Modo História que o EDITOR DE JANELAS lista |
| 2 | `src/ui/marcador_de_missao.gd` | 218 | 1 | 0 | MARCADOR DE MISSÃO NA TELA (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md). |
| 1 | `src/ui/AguaHud.gd` | 73 | 1 | 0 | ÁGUA NO HUD — fôlego e visão submersa (01/10/2026, docs/AGUA_PLANO.md). |
| 1 | `src/ui/AirSlamHud.gd` | 70 | 1 | 1 | Vizinho da mordida no topo-direito: a bigorna caindo identifica a queda |
| 1 | `src/ui/BaraHud.gd` | 134 | 1 | 0 | Somente apresentação do estado replicado; não decide reserva, custo ou dano. |
| 1 | `src/ui/BossHealthBar.gd` | 59 | 1 | 0 | Observa o estado replicado; não simula vida nem concede recompensa. |
| 1 | `src/ui/FruitRecoveryHud.gd` | 70 | 1 | 1 | Quadrado da recuperação pós-dano. Mostra somente enquanto bloqueia frutas; |
| 1 | `src/ui/Inventory.gd` | 115 | 1 | 0 | Inventário em cinza e branco (grade 6×4). Abre/fecha via Hud (tecla I/TAB). |
| 1 | `src/ui/MinkBiteHud.gd` | 74 | 1 | 1 | Indicador compacto da investida Mink. Só aparece enquanto a técnica estiver |
| 1 | `src/ui/OpeRoomHud.gd` | 114 | 1 | 0 | Estado espacial do próprio jogador, separado dos cooldowns dos quatro slots. |
| 1 | `src/ui/SniperScope.gd` | 179 | 1 | 0 | LUNETA DA SNIPER — a vista pelo cano do fuzil da Buki Buki (slot C). |
| 1 | `src/ui/bussola_hud.gd` | 86 | 1 | 0 | BÚSSOLA NA TELA (08/10/2026) — aponta para a Ilha dos Macacos. |
| 1 | `src/ui/hud_da_corrida.gd` | 148 | 1 | 0 | HUD DA CORRIDA DE CARANGUEJOS (06/10/2026). |
| 1 | `src/ui/jogador_de_exemplo.gd` | 16 | 1 | 0 | JOGADOR DE EXEMPLO — o mínimo que as janelas da HUD leem de um corpo, para o |
| 1 | `src/ui/rastreador_de_missoes.gd` | 49 | 1 | 0 | MISSÕES EM ANDAMENTO NA TELA (08/10/2026): "Bandidos no campo — 2 / 5", e quando |

## Visual, VFX e áudio <a id="visual"></a>

Contexto: [`visual.md`](agentes/visual.md) (agentes) · [`visual.md`](pessoas/visual.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 5 | `src/fx/ScreenFX.gd` | 311 | 12 | 2 | SCREEN FX (AUTOLOAD) — overlay 2D TRANSPARENTE (alpha) de game feel: VINHETA |
| 4 | `src/fx/Materiais.gd` | 150 | 15 | 0 | A FÁBRICA DE MATERIAL — Fase 3 de docs/PLANO_VISUAL.md |
| 3 | `src/fx/Contorno.gd` | 74 | 7 | 0 | O NÓ DO CONTORNO — Fase 2 de docs/PLANO_VISUAL.md |
| 3 | `src/fx/ScreenShatterFX.gd` | 67 | 2 | 0 | Efeito visual de quebra de tela (Screen Shatter) para os impactos da Gura Gura no Mi. |
| 2 | `src/fx/WeaponTrail3D.gd` | 77 | 4 | 0 |  |
| 1 | `VFX/BreathVFX.gd` | 176 | 1 | 0 | VFX reutilizável — FÔLEGO do personagem enquanto corre. |
| 1 | `src/audio/components/character_audio.gd` (CharacterAudio) | 82 | 1 | 0 | res://scripts/audio/components/character_audio.gd |
| 1 | `src/audio/components/footstep_system.gd` (FootstepSystem) | 87 | 1 | 0 | res://scripts/audio/components/footstep_system.gd |
| 1 | `src/audio/audio_events.gd` | 21 | 0 | 0 | res://scripts/audio/audio_events.gd |
| 1 | `src/audio/audio_manager.gd` | 51 | 0 | 0 | res://scripts/audio/audio_manager.gd |
| 1 | `src/audio/sound_library.gd` | 68 | 0 | 0 | res://scripts/audio/sound_library.gd |

## Ferramentas, testes e pipeline <a id="ferramentas"></a>

Contexto: [`ferramentas.md`](agentes/ferramentas.md) (agentes) · [`ferramentas.md`](pessoas/ferramentas.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 2 | `src/tests/BaseTest.gd` | 210 | 1 | 2 | BASE DOS TESTES DE CENA (src/tests/*.gd) |
| 1 | `src/tests/test_anim.gd` | 207 | 0 | 0 | TESTE DO CORTE DE ESPADA — o golpe pega o TRONCO, não as PERNAS. |
| 1 | `src/tests/test_fsm.gd` | 307 | 0 | 0 | FSM DE COMBATE — as TRÊS fases do golpe e o DASH CANCEL. |
| 1 | `src/tests/test_physics.gd` | 189 | 0 | 0 | TESTE DE FÍSICA DO KNOCKBACK — o boneco tem que VOAR DE VERDADE. |
| 1 | `test_peer.gd` | 16 | 0 | 0 | ⚠️ `multiplayer` NÃO EXISTE NA `SceneTree` — é propriedade de `Node`. |
| 1 | `test_singleplayer.gd` | 19 | 0 | 0 | ⚠️ `multiplayer` NÃO EXISTE NA `SceneTree` — é propriedade de `Node`. |
| 1 | `test_spawner.gd` | 33 | 0 | 0 | ⚠️ `multiplayer` NÃO EXISTE NA `SceneTree` — é propriedade de `Node`. |
| 1 | `tools/anim_editor/studio/document.gd` | 197 | 0 | 0 | Versioned working document. Pure data: no scene or UI dependencies. |
| 1 | `tools/anim_editor/studio/main.gd` | 804 | 0 | 0 |  |
| 1 | `tools/anim_editor/studio/rig_scene.gd` | 194 | 0 | 0 | Same 1.5 m player height; the sword remains in world metres. |
| 1 | `tools/anim_editor/studio/selection.gd` | 62 | 0 | 0 | Anatomical selection is a view over the existing hierarchy, never a new rig. |
| 1 | `tools/anim_editor/studio/test_selection.gd` | 149 | 0 | 0 |  |
| 1 | `tools/anim_editor/studio/test_studio.gd` | 308 | 0 | 0 |  |
| 1 | `tools/anim_editor/studio/timeline.gd` | 112 | 0 | 0 |  |
| 1 | `tools/anim_editor/studio/view.gd` | 348 | 0 | 0 |  |
| 1 | `tools/bake_mixamo.gd` | 644 | 0 | 0 | Baker de animações Mixamo/Meshy -> rig por-nós do jogo. |
| 1 | `tools/bara_preview.gd` | 283 | 0 | 0 | Arena real com Bara equipada. -- --capture registra fases e custo do renderer. |
| 1 | `tools/base_v2_preview.gd` | 49 | 0 | 0 | Captures the actual Player model and a walking pose in Godot. |
| 1 | `tools/bestas_mar_comportamento_preview.gd` | 92 | 0 | 0 | Prova visual dos clipes nas quatro malhas reais, com rig e blend do jogo. |
| 1 | `tools/bestas_mar_preview.gd` | 275 | 0 | 0 | Captura os GLBs reais, o esqueleto importado e a loja real em mapa temporário. |
| 1 | `tools/build_bara_buggy_left_hand.gd` | 132 | 0 | 0 | Derivação reproduzível, sem alterar o GLB: corta a malha no plano do punho L para Bara Bara (Player). |
| 1 | `tools/build_buggy_hand.gd` | 132 | 0 | 0 | Derivação reproduzível, sem alterar o GLB: corta a malha no plano do punho R. |
| 1 | `tools/capturar_serpente_anime.gd` | 119 | 0 | 0 | SERPENTE ANIME x REFERÊNCIA — prova visual lado a lado (02/10/2026). |
| 1 | `tools/criar_estilo_base.gd` | 151 | 0 | 0 | ESTILO DE COMBATE BASE — Z e X feitas com o Skills Builder (14/10/2026). Fonte reproduzível. |
| 1 | `tools/criar_hie_hie.gd` | 172 | 0 | 0 | HIE HIE NO MI REFEITA NO SKILLS BUILDER — o Z novo (07/10/2026). Fonte reproduzível. |
| 1 | `tools/criar_moku_moku.gd` | 314 | 0 | 0 | MOKU MOKU NO MI REFEITA NO SKILLS BUILDER (11/10/2026). Fonte reproduzível. |
| 1 | `tools/criar_nikyu_nikyu.gd` | 204 | 0 | 0 | NIKYU NIKYU NO MI — feita com o Skills Builder (14/10/2026). Fonte reproduzível. |
| 1 | `tools/criar_noro_noro.gd` | 172 | 0 | 0 | NORO NORO NO MI — feita NO Skills Builder (06/10/2026). Fonte reproduzível. |
| 1 | `tools/criar_pika_pika.gd` | 289 | 0 | 0 | PIKA PIKA NO MI REFEITA NO SKILLS BUILDER (06/10/2026). Fonte reproduzível. |
| 1 | `tools/dump_skeletons.gd` | 58 | 0 | 0 | Diagnóstico: lista ossos dos modelos SKINNADOS e a árvore de nós dos modelos |
| 1 | `tools/engrossar_base.gd` | 93 | 0 | 0 | Engrossa o personagem BASE no eixo FRENTE/TRÁS (Z). |
| 1 | `tools/export_anims.gd` | 67 | 0 | 0 | Despeja as animações assadas (.res, formato BINÁRIO do Godot) em JSON, para o |
| 1 | `tools/export_mesh.gd` | 200 | 0 | 0 | Voxeliza a malha dos personagens para o editor em Python poder MOSTRAR o |
| 1 | `tools/export_rig.gd` | 163 | 0 | 0 | Exporta o PERFIL DO RIG de cada personagem para JSON, que o editor de animação |
| 1 | `tools/export_yoru_poses.gd` | 44 | 0 | 0 |  |
| 1 | `tools/exportar_fenix_anime.gd` | 28 | 0 | 0 | godot --headless --path . --script tools/exportar_fenix_anime.gd |
| 1 | `tools/gerar_pose_machado.gd` | 34 | 0 | 0 | Fonte reproduzível da animação: corte pesado de cima, com pega e arco próprios. |
| 1 | `tools/goro_preview.gd` | 191 | 0 | 0 | Abre a arena real com a Goro Goro equipada. -- --capture salva a revisão da |
| 1 | `tools/importar_areia_na_loja.gd` | 32 | 0 | 0 | Registra somente este asset; preserva modelos/categorias existentes. |
| 1 | `tools/importar_bandido_na_loja.gd` | 65 | 0 | 0 | PÕE O BANDIDO NA LOJA DO EDITOR, aba "inimigos" (08/10/2026). Idempotente. |
| 1 | `tools/importar_boneco_na_loja.gd` | 56 | 0 | 1 | PÕE O BONECO DE DUELO NA LOJA DO EDITOR, na aba "inimigos" (30/09/2026). |
| 1 | `tools/importar_caranguejo_na_loja.gd` | 30 | 0 | 0 | Registra/atualiza só o caranguejo, preservando todos os outros modelos e categorias. |
| 1 | `tools/importar_machado_madeira.gd` | 16 | 0 | 0 |  |
| 1 | `tools/importar_npcs_na_loja.gd` | 104 | 0 | 1 | PÕE OS NPCs NA LOJA DO EDITOR, na aba "NPCs" (03/10/2026). |
| 1 | `tools/importar_ponte_na_loja.gd` | 32 | 0 | 0 | Registra somente a ponte do rio (tools/blender/ponte_rio.py); preserva modelos/categorias existentes. |
| 1 | `tools/mapa_ilha/ampliar_area_da_harpia.gd` | 63 | 0 | 0 | TERRITÓRIO DA HARPIA MAIOR (10/10/2026, docs/PEDIDO_2026-10-10_HISTORIA.md). Idempotente. |
| 1 | `tools/mapa_ilha/aplicar_atravessaveis.gd` | 57 | 0 | 0 | MODELOS ATRAVESSÁVEIS — loja e mapa vivo (01/10/2026). |
| 1 | `tools/mapa_ilha/aplicar_escalaveis.gd` | 43 | 0 | 0 | MODELOS ESCALÁVEIS — marcação inicial na loja (03/10/2026). |
| 1 | `tools/mapa_ilha/aplicar_fichas_de_animais.gd` | 135 | 0 | 0 | FICHAS DE ANIMAL + TAMANHO REAL dos animais da loja (01/10/2026). |
| 1 | `tools/mapa_ilha/aplicar_tamanhos_padrao.gd` | 163 | 0 | 0 | TAMANHO PADRÃO + NAVIOS na loja (30/09/2026). |
| 1 | `tools/mapa_ilha/aplicar_xp_por_dificuldade.gd` | 37 | 0 | 0 | XP DE CADA ANIMAL PELA DIFICULDADE (08/10/2026). Idempotente. |
| 1 | `tools/mapa_ilha/atualizar_animais_riggados.gd` | 86 | 0 | 0 | ANIMAIS RIGGADOS NA LOJA — troca o modelo estático pelo riggado (02/10/2026). |
| 1 | `tools/mapa_ilha/capturar_agua.gd` | 120 | 0 | 0 | CAPTURA DA ÁGUA — nado, mergulho, fundo do mar (01/10/2026, docs/AGUA_PLANO.md). |
| 1 | `tools/mapa_ilha/capturar_animais.gd` | 131 | 0 | 0 | CAPTURA DOS ANIMAIS — fotos com GPU de verdade (01/10/2026). |
| 1 | `tools/mapa_ilha/capturar_clipes_animais.gd` | 122 | 0 | 0 | CLIPES DOS ANIMAIS NO GODOT — folha de quadros com GPU (02/10/2026). |
| 1 | `tools/mapa_ilha/capturar_escala_animais.gd` | 142 | 0 | 0 | ESCALA DOS ANIMAIS x PERSONAGEM — fotos lado a lado (01/10/2026). |
| 1 | `tools/mapa_ilha/capturar_ilha.gd` | 104 | 0 | 0 | CAPTURA DA ILHA — fotos com GPU de verdade do mapa montado (30/09/2026). |
| 1 | `tools/mapa_ilha/capturar_ilha_dos_macacos.gd` | 84 | 0 | 0 | CAPTURA DA ILHA DOS MACACOS — fotos com GPU de verdade (08/10/2026). |
| 1 | `tools/mapa_ilha/capturar_perfis_navios.gd` | 40 | 0 | 0 | Inspeção dos seis GLBs existentes; não altera catálogo nem mapa. |
| 1 | `tools/mapa_ilha/capturar_pomar.gd` | 147 | 0 | 0 | CAPTURA DO POMAR E DA DOMA — fotos com GPU no Modo História de verdade (01/10/2026). |
| 1 | `tools/mapa_ilha/clipes_dos_riggados.gd` | 443 | 0 | 0 | CLIPES QUE FALTAM NOS ANIMAIS QUE JÁ VIERAM COM OSSOS — gerados no Godot (02/10/2026). |
| 1 | `tools/mapa_ilha/colisao_troncos_arvores.gd` | 135 | 0 | 0 | COLISÃO SÓ NOS TRONCOS das árvores antigas da loja (01/10/2026). |
| 1 | `tools/mapa_ilha/colocar_areas_de_animais.gd` | 126 | 0 | 0 | ÁREAS DE ANIMAIS no mapa vivo da Ilha Inicial (01/10/2026). |
| 1 | `tools/mapa_ilha/colocar_bandidos_e_missao.gd` | 131 | 0 | 0 | BANDIDOS NO CAMPO ABERTO + GUARDA DA VILA (08/10/2026). Idempotente. |
| 1 | `tools/mapa_ilha/colocar_vendedor_de_barcos.gd` | 99 | 0 | 0 | VENDEDOR DE BARCOS NO PORTO + MAPA SEM BARCOS (10/10/2026). Idempotente. |
| 1 | `tools/mapa_ilha/comparar_clipes_riggados.gd` | 89 | 0 | 0 | CLIPES ANTIGOS INTACTOS? — original x reexportado pelo Blender (02/10/2026). |
| 1 | `tools/mapa_ilha/comparar_modelos.gd` | 88 | 0 | 0 | COMPARAR DOIS MODELOS DA LOJA lado a lado, com a luz do jogo (01/10/2026). |
| 1 | `tools/mapa_ilha/floresta_da_loja.gd` | 118 | 0 | 0 | Substituição pontual: só os aglomerados antigos do grupo floresta. |
| 1 | `tools/mapa_ilha/gerar_colisao_de_construcoes.gd` | 139 | 0 | 0 | COLISÃO DAS CONSTRUÇÕES em partes convexas (01/10/2026). |
| 1 | `tools/mapa_ilha/gerar_ilha.gd` | 913 | 0 | 0 | GERADOR DA ILHA INICIAL — relevo em blocos + assets da loja (30/09/2026). |
| 1 | `tools/mapa_ilha/gerar_ilha_dos_macacos.gd` | 442 | 0 | 0 | ILHA DOS MACACOS — a 2ª ilha do Modo História (08/10/2026). Idempotente. |
| 1 | `tools/mapa_ilha/importar_natureza_na_loja.gd` | 88 | 0 | 0 | NATUREZA NA LOJA — árvores, frutas e complementos de floresta (01/10/2026). |
| 1 | `tools/mapa_ilha/medir_montagem.gd` | 49 | 0 | 0 | MEDIR MONTAGEM — quanto o `MapaMontador` leva para montar um mapa (30/09/2026). |
| 1 | `tools/mapa_ilha/plantar_natureza.gd` | 169 | 0 | 0 | PLANTAR A NATUREZA no mapa vivo da Ilha Inicial (01/10/2026). |
| 1 | `tools/mapa_ilha/refazer_floresta.gd` | 24 | 0 | 0 | Exige entrada e saída explícitas. A aplicação ao mapa vivo ocorre após revisão. |
| 1 | `tools/mapa_ilha/trocar_cavalo_leve.gd` | 69 | 0 | 0 | CAVALO LEVE na loja e na vila (01/10/2026). |
| 1 | `tools/mapa_ilha/validar_floresta.gd` | 91 | 0 | 0 | -- <antes.json> <depois.json>. Usa cópia user:// para edição/desfazer/salvar. |
| 1 | `tools/mera_preview.gd` | 148 | 0 | 0 | Abre a arena real com a Mera equipada. `-- --capture` salva as fases em PNG. |
| 1 | `tools/nado_montaria_preview.gd` | 107 | 0 | 0 | Fixture visual: Player real, sem capturar mouse nem salvar a campanha. |
| 1 | `tools/ope_preview.gd` | 112 | 0 | 0 | Abre a arena real com Ope equipada. -- --capture salva fases reproduzíveis. |
| 1 | `tools/phoenix_preview.gd` | 23 | 0 | 0 | Arena real com a Phoenix equipada; não altera a fruta inicial nem o save da história. |
| 1 | `tools/praia_preview.gd` | 82 | 0 | 0 | Captura GPU do mapa real (só leitura) e areia em instâncias temporárias. |
| 1 | `tools/registrar_bestas_mar.gd` | 82 | 0 | 1 | Registra/reimporta as quatro bestas com IDs estáveis e tamanho nativo. |
| 1 | `tools/rocket_preview.gd` | 143 | 0 | 0 | Sem --capture: arena jogável com a Rocket equipada e controles originais. |
| 1 | `tools/yoru_arena.gd` | 57 | 0 | 0 | Arena real equipada; -- --capture executa os inputs e registra cada técnica. |
| 1 | `tools/yoru_preview.gd` | 72 | 0 | 0 |  |

## Geral <a id="geral"></a>

Contexto: [`geral.md`](agentes/geral.md) (agentes) · [`geral.md`](pessoas/geral.md) (pessoas)

| ★ | arquivo | linhas | fan-in | testes | o que é |
|---|---|---:|---:|---:|---|
| 5 | `src/skills_builder/kit_do_builder.gd` (KitDoBuilder) | 181 | 16 | 15 | O Kit do Builder: as skills publicadas do JOGADOR equipadas como uma fruta |
| 4 | `src/skills_builder/lentidao.gd` (Lentidao) | 60 | 12 | 2 | LENTIDÃO de skill do Builder (06/10/2026) — Noro Noro no Mi: "desacelerar qualquer ser |
| 4 | `src/skills_builder/executor_de_skill.gd` (ExecutorDeSkill) | 883 | 6 | 11 | Roda uma skill do Skills Builder num corpo DO JOGO (06/10/2026). |
| 4 | `src/skills_builder/skills_publicadas.gd` (SkillsPublicadas) | 413 | 6 | 15 | As skills do Builder que o JOGO usa (06/10/2026). |
| 4 | `src/skills_builder/dados_skill.gd` | 429 | 5 | 23 | Contrato de dados do Skills Builder. JSON contém valores, nunca recursos/código. |
| 3 | `src/skills_builder/estilo_builder.gd` | 70 | 5 | 0 |  |
| 3 | `src/skills_builder/catalogo_de_projeteis.gd` (CatalogoDeProjeteis) | 483 | 4 | 1 | LOJA DE PROJÉTEIS do Skills Builder (06/10/2026). |
| 3 | `src/skills_builder/poses_de_skill.gd` (PosesDeSkill) | 132 | 4 | 1 | POSES DO SKILLS BUILDER (06/10/2026) — pedido do dono: criar as poses de um golpe |
| 3 | `src/skills_builder/visual_de_skill.gd` | 532 | 4 | 0 | O que uma skill do Builder DESENHA e TOCA, numa fonte só (06/10/2026). |
| 3 | `src/skills_builder/clipes_de_skill.gd` | 74 | 3 | 2 | Clipes do bloco Animação do Skills Builder (07/10/2026). UMA lista para o editor, a |
| 3 | `src/skills_builder/arena_preview.gd` | 867 | 1 | 5 | Ensaio isolado: tempo fixo e seed estável tornam a timeline reproduzível. |
| 2 | `src/skills_builder/aura_de_lentidao.gd` | 156 | 3 | 0 | AURA DE LENTIDÃO (06/10/2026) — a leitura de "tempo esticado" da Noro Noro no Mi. |
| 2 | `src/skills_builder/chuva_de_projeteis.gd` | 49 | 2 | 0 | Projéteis em CHUVA (07/10/2026, C da Pika). Pedido do dono: "C deve ocorrer em uma |
| 2 | `src/skills_builder/transformacao_de_skill.gd` | 146 | 2 | 1 | Um bloco de transformação, compartilhado pela timeline da prévia e do jogo. |
| 2 | `src/skills_builder/usuario_de_skills.gd` (UsuarioDeSkills) | 118 | 2 | 1 | Um INIMIGO que usa as skills do Builder atribuídas a ele (06/10/2026). |
| 2 | `src/skills_builder/editor_de_poses.gd` | 206 | 1 | 0 | EDITOR DE POSES do Skills Builder (seção "Poses"). |
| 2 | `src/skills_builder/loja_de_projeteis.gd` | 184 | 1 | 0 | LOJA DE PROJÉTEIS — a grade da seção Projéteis do Skills Builder (06/10/2026). |
| 2 | `src/skills_builder/poses_basicas.gd` | 81 | 1 | 1 | POSES BÁSICAS do Skills Builder (07/10/2026). Pedido do dono: "adicionar poses |
| 2 | `src/skills_builder/teste_no_jogo.gd` | 238 | 1 | 0 | ▶ TESTAR NO JOGO do Skills Builder (07/10/2026). Pedido do dono: "adicionar uma |
| 2 | `src/skills_builder/timeline_skill.gd` | 301 | 1 | 0 | Timeline do Skills Builder. Trabalha sobre uma cópia do documento: o pai |
| 1 | `src/skills_builder/ativacao_do_kit.gd` | 161 | 1 | 0 | Uma tecla do Kit do Builder apertada (06/10/2026). A semântica de ativação é a da |
| 1 | `src/skills_builder/campo_de_fruta.gd` | 105 | 1 | 0 | O campo FRUTA da Identificação do Skills Builder (06/10/2026): a lista (Kit do Builder, |
| 1 | `src/skills_builder/quem_usa_skill.gd` (QuemUsaSkill) | 40 | 1 | 0 | QUEM usa uma skill do Builder (decisão do dono, 06/10/2026): a atribuição mora na |
| 1 | `src/skills_builder/seletor_transformacao.gd` | 52 | 1 | 0 | Escolha atômica da forma/modelo; editor guarda a mudança no desfazer/refazer. |
| 1 | `src/skills_builder/viagem_de_skill.gd` | 44 | 1 | 0 | A viagem de uma skill do Builder acabando antes (07/10/2026, X da Pika). |
| 1 | `src/skills_builder/visual_de_transformacao.gd` | 107 | 1 | 0 | Formas da transformação. Geometria visual pura, sem scripts/colisão do asset. |
| 1 | `src/skills_builder/SkillsBuilder.gd` | 873 | 0 | 0 | Editor de dados de habilidades com execução isolada. Não equipa skills na campanha. |
