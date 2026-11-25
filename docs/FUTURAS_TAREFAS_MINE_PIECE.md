# Futuras tarefas — o que o Mine Piece v14 tem e o jogo ainda NÃO importou (auditoria de 2026-11-09)

> **ATUALIZAÇÃO 10/11/2026:** parte desta lista foi executada na noite de 09→10/11. O estado atual e as CORREÇÕES a esta auditoria estão em
> [`CHECKPOINT_ITENS_1_A_10.md`](CHECKPOINT_ITENS_1_A_10.md) (ex.: `syncPlayerVariables` já existia; 273/282 entidades nascem; golpes de 1000/1250 são progressão por grade).


Auditoria de cobertura, só leitura. Nada do jogo foi alterado; o Godot e os testes NÃO foram rodados (outro processo usava a máquina).
Por isso "funcionando (testado)" aqui é **citação dos checkpoints** (`docs/MINE_PIECE_COMPLETO_MEDICAO.md`, `docs/FRUTAS_QUE_FALTAM.md`,
`docs/FORMAS_ZOAN.md`), não reexecução. O que eu medi de novo foi contagem e alcance estático.

## Como foi medido

- **Fontes do mod:** `~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14/` (mesmo SHA-256 `349b36cd…bd765` do jar `~/server_onepiece/mods/MinePiece-ver14-forge-1.20.1.jar`;
  o jar não foi aberto nem executado). 1076 procedures, 283 entidades registradas (282 classes), 64 `Model*.java`, 267 geo + 267 animation, 93 `player_animation`,
  34 sons, 42 partículas, 123 advancements, 65 estruturas, 3 dimensões.
- **Jogo:** contagem de arquivos em `src/minecraft/` (+ `gerado/procedures/`), `mapas/east_blue/*.json`, `mapas/modelos/`, `assets/mine_piece/`.
- **Scripts do repositório usados (`python3 -I`, só leitura):** `tools/mine_piece/medir_cobertura.py` e `inventariar_frutas.py`.
- **Alcance estático das procedures (medição nova desta auditoria):** grafo `procedure → Mc.proc(&"Outra")` sobre `src/minecraft/gerado/procedures/*.gd`.
  Raízes = qualquer `…Procedure` citada fora de `gerado/` (67) + procedures de entidades **que têm modelo/ficha no jogo** (92) + handlers de evento
  (`eventos_do_mod.json`, 38) + ganchos de efeito (`efeitos_do_mod.json`, 44). Resultado: **725 de 1076 alcançáveis; 351 sem nenhum caminho**.
  É um **teto**: alcançável no grafo ≠ executado/testado, e despacho dinâmico por string fora desses JSON não aparece.
- **Métodos de instância chamados nas procedures e sem `func` correspondente em `src/minecraft/*.gd`:** 154 nomes distintos (excluindo `execute*`);
  102 não são de renderização do cliente (lista em 2.3). Heurística por nome: pode haver método tratado por `call`/`_get` dinâmico.
- **`Mc._falta` em tempo de execução:** os contadores (`Mc.pedidos_sem_implementacao`) só existem com o jogo rodando; **não há relatório salvo**
  no repositório. Esta auditoria os substitui por análise estática; a medição em runtime continua pendente (ver "Como retomar").

Legenda de estado: **OK** = importado e citado como testado; **Parcial**; **Extraído** = dados/arquivos existem mas não ligados ao jogo; **Não importado**.

## Resumo

| Categoria | Importado / total | % | Estado |
|---|---|---|---|
| Frutas (tag `devil_fruit`) | 40 / 40 carregadas pelo fluxo do mod (6 com executor nativo escrito à mão: goro, hie, moku, nikyu, ope, pika) | 100 % carga | Parcial: 26 delas só "o golpe começa" (varredura 08/11); fidelidade visual não conferida |
| Golpes das 26 frutas novas | 127 / 129 iniciam (faltam Kage `Shadow's Asgard` custo 1000 e Zushi `Meteor` 1250 > 600 de energia máx.) | 98 % | Parcial |
| Procedures traduzidas | 1076 / 1076 geradas; compilação 1075/1076 (checkpoint 04/11) | 100 % | OK (compila) |
| Procedures com caminho de execução | 725 / 1076 | 67 % | Parcial (teto) |
| Métodos Minecraft sem implementação | ≥102 nomes de servidor | — | Parcial |
| Personagens/criaturas (231) | 112 com ficha + modelo `mp_`; 114 só visual `mpx_` (nascem por procedure, sem ficha/spawn); 3 sem nada | 48 % completos / 98 % com visual | Parcial |
| Mobs genéricos (4) | 4 / 4 | 100 % | OK |
| Projéteis/efeitos (47) | 33 com modelo `mpx_`; 4 invisíveis por desenho do mod (certo); 10 sem modelo próprio | 79 % | Parcial |
| IA (`AI*Procedure`, 214) | 98 alcançáveis; 116 sem caminho (quase todas de personagens não importados) | 46 % | Parcial |
| Spawn natural | 93 regras extraídas; 24 personagens nascem | — | OK (testado 17/17) |
| Geo/animação GeckoLib (267) | embutidas nos GLB convertidos (114 `mp_` + 158 `mpx_`); sobreposição não medida | ~68 % (estimado) | Parcial |
| `Model*.java` (64) | 22 usados (20 nas formas Zoan + 2 `modelos_java`); 42 sem uso | 34 % | Parcial |
| Animações do jogador (`player_animation`) | 93 / 93 extraídas e ligadas (sem `position`/`scale`, sem rede) | 100 % | Parcial |
| Sons (arquivos) | 33 / 34 (falta `unlimited_void.ogg`; evento `guard` sem som mapeado) | 97 % | OK |
| Partículas do mod | 42 / 42 | 100 % | OK |
| Texturas (1430 arquivos) | não medido por arquivo; entidades 71 PNG + partículas 120 + 90 modelos de item; `mob_effect` 34 e `screens` 38 sem uso | — | Parcial |
| Itens "normais" (116 registros com lambda) | 116 / 116 extraídos (`itens_do_mod.json`); 90 modelos `mpi_*.glb` + 26 ícones de fruta | 100 % dados | Extraído: uso como item do jogador não verificado (IA equipa na mão do NPC) |
| Roupas/uniformes (213 peças, 71 classes `Clothes*/Uniform*`) | 0 como armadura do jogador; texturas `mp_*_clothes_*` só nos NPCs | ~0 % | Não importado (jogador) |
| Ovos de spawn (210) | n/a (o jogo tem spawn próprio) | — | Não aplicável |
| Blocos (7: iced_*, minepiece_spawner, sponge_super) | 0 / 7 como bloco jogável (só aparecem em estruturas/procedures) | 0 % | Não importado |
| Receitas (31) / loot tables (15) | 0 / 31; 0 / 15 | 0 % | Não importado |
| Conquistas (123) | 123 / 123 lidas e concedidas; travam golpes (18/18 testes) | 100 % lógica | Parcial: sem janela/lista, kit inicial não entregue, sem rede |
| Efeitos do mod (34) | 34 / 34 com ganchos (`efeitos_do_mod.json`) | 100 % | Parcial: sem ícone/HUD de efeito |
| Haki | 3 efeitos ligados; tecla/ação do Rei e entidades de haki sem caminho | ~50 % | Parcial |
| Estilos de luta / classes (`Select*`) | 0 / 23 (NPCs usam os `Skill*` via IA; o jogador não escolhe) | 0 % | Não importado |
| Formas Zoan do jogador | 14 / 14 modelos; formas gigantes (Pehkui) OK; nunca visto no jogo pelo dono | 100 % | Parcial |
| Estruturas | 61 / 65 (faltam `barrier`, `ocean`, `ocean_bottom`, `red_line`: técnicas) | 94 % | OK |
| Dimensões (Dream, Skypiea, Wano) | 0 / 3 | 0 % | Não importado |
| Worldgen (131 JSON: 9 biomas, 25 estruturas, 53 template_pool) | 0 (o jogo usa mapa de ilhas próprio) | 0 % | Não aplicável / decisão |
| Teclas do mod (20 procedures `Key*`) | 9 / 20 alcançáveis | 45 % | Parcial |
| GUIs/menus do mod (7) | 0 / 7 (tripulação, nome, seleção de técnica); o jogo tem HUD e tripulação próprios | 0 % | Não importado |
| Comandos do mod (4 classes) | 0 / 4 (PVP, villagers, bounty Lv0/Lv2) | 0 % | Não importado |
| Atributos do mod (7), game rules (14) | atributos FORM/SIZE sim; resto parcial; game rules não | — | Parcial |

---

## 1. Frutas e técnicas

**Importado:** `FrutasDoMod.FRUTAS` tem os 40 ids da tag (`src/combat/frutas_do_mod/frutas_do_mod.gd`); `ControladorFrutaDoMod` roda as procedures
(`KeyChangeTechniqueDevilFruit*`, `KeyStartTechniqueOn*`, `KeyTransformOnKeyPressed`). Teclas Z X C V B N, `J` transforma (nota: o checkpoint de 04/11 dizia `B`).
`tools/dev_tests/varredura_frutas_do_mod.gd` mediu que todos os golpes das 26 frutas "começam" (energia, entidades, dano).

**Falta (por prioridade):**
- **P1** — **Fidelidade das 26 frutas novas** (aro, batto, bisu, hito_hito_daibutsu, horo, imu, inu_inu×2, kage, kira, kiro, mero, mochi, mori, neko×2, riki, ryu_ryu×3, soru, supa, uo_uo_seiryu, ushi_ushi_giraffe, uta, zushi): nada foi jogado à mão; a varredura mede execução, não efeito. Esforço L (revisão visual/numérica fruta a fruta contra o mod). Depende de 2.3 (métodos ausentes) e 3 (partículas/sons que viram `Mc._falta`, ex.: `zushi_zushi/AIMeteor`).
- **P1** — `kage_kage/Shadow's Asgard` (1000) e `zushi_zushi/Meteor` (1250) não disparam: energia máxima 600. Decisão: elevar teto por fruta ou custo? Esforço S, precisa do dono.
- **P2** — Passivas: `SkillSoruPassive`, passiva "Giante" depende de `WhenRespawn`/`PlayerRespawned` do mod, que o jogo não chama. Esforço S–M.
- **P2** — Executores nativos só existem para 6 frutas; as outras 34 dependem 100 % das procedures. Aceitável (decisão do dono 03/11); gatilho: divergência medida contra o mod.
- **P3** — Desbloqueio por grade do `SkillSelector`/`KeyChangeTechniqueDevilFruit` já ligado a conquistas; falta a janela das conquistas (ver 8).

## 2. Procedures

### 2.1 Totais
1076 geradas (`tools/mine_piece/tradutor/traduzir.py`), 1075 compilam (`tools/dev_tests/compilar_procedures_mine_piece.gd`, não rerodado hoje). 725 têm caminho no grafo; 351 não.

### 2.2 As 351 sem caminho (por família)
| Família | Qtd | Nomes (sem o sufixo `Procedure`) | Prioridade |
|---|---|---|---|
| `AI*` de personagens não importados | 116 | Akainu, AshuraDoji, Atmos, Bepo, Blenheim, Bramenko, Burgess, Cracker, Curiel, Denjiro, DrIndigo, EdwardNewgate, Enel, Fossa, Fujitora, Gaban, GeckoMoria, Hack, Haruta, Higuma, HodyJones, Imu, Inuarashi, Izo, Jabra, Jack, Jozu, Kaidou, Kaku, Kalifa, Katakuri, Kawamatsu, Kikunojo, Kinemon, King, Kingdew, Kizaru, Koala, Kurohige, Lilith, Lucci, Marco, Namur, Nekomamushi, Nero, Oars, Oden, PageOne, Perospero, Rakuyo, Rayleigh, Rockstar, Roger, Ryuma, SBear/SHawk/SShark/SSnake, ScratchmenApoo, Sengoku, Seraphim, Shiryu, Snack, SpeedJil, Stussy, Thatch, Tiger, TotMusica*, Ulti, VanOgre, VascoShot, Vista, WhosWho, XDrake, Yamakaji, Zeus, ZeusPrometheus… + projéteis `Arrow, Ball, Crack, DragonHead, Dynamite, EntityImpact, EntitySlash, FlameBall, GomuArm, Gryphon, IceBall, MiniHollow, MusoDonatsu, NegativeHollow, Note, ProjectileSlash/Sweep` | ver 3 |
| `Select*` (seleção de classe/estilo) | 23 | CelestialDragons, Curiel, Cyborg, Elizabello2, Fighter, Fishman, Garp, General, Giant, Gunman, Indigo, Kaido, Lunarian, Mihawk, Oden, Roger, Rokushiki, Sabo, Sanji, Shanks, Swordsman, Usopp, Zoro | **P1** |
| `Key*` do mod | 11 | BackstepOnKeyPressed/Released, BattleMode, ForOrca, ForwardOnKeyPressed/Released, HaoshokuHaki, P, ResetWASD, SpaceOnKeyReleased, SwitchTechnique | **P1** (mapear para o dash/pulo/guarda nativos do jogo) |
| `Logic*` (guarda, recarga, slots) | 14 | CantJustGuard, Cooldown, CooldownMagicOnly, DevilFruitUser, GuardJust, Guard, MoveAround, OverlayCombo/DoubleJump/Fly, Slot0–3 | **P1** (guarda/aparo do mod) |
| `Slot0–5`, `SlotUpdate`, `WeaponAbility`, `WeaponAbilityBackup`, `WeaponAbilityUsed` | 10 | habilidade das armas do mod (clique direito/slots) | **P1** |
| `Overlay*` / `OOverlay*` (HUD do mod) | 17 | o jogo tem HUD próprio; só reaproveitar dados | P3 |
| `Spawn*` / `Spawner*` (regiões e navios) | 24 | SpawnEastBlue…WestBlue, SpawnMarineCorps, SpawnPirateCorps, SpawnShip (MobyDick, OroJackson, RedForce, SaberOfXebec, ThousandSunny), SpawnerBaratie/Branch153/ShipAlvida/GoingMerry/MarineLarge1, SpawnSurface* | P2 (o jogo tem spawn natural próprio — 93 regras — mas os navios do mod não nascem por aqui) |
| `Raid*` | 6 | RaidStart(EastBlue/GrandLine/NewWorld/SouthBlue), RaiderFoundEnemy | P3 (raid é nativo em `src/historia/raid/raid.gd`; só auditar equivalência) |
| Tripulação/Pirata/Marinha | 18 | `Pirate*` 8, `Marine*` 4, `Return*` 12 (Member*, Bounty, CrewName…), `Member*`, `Order*`, `Button*` 4 | P2 (a tripulação do jogo é nativa — `docs/SOBREVIVENCIA_TRIPULACAO_CHECKPOINT.md`) |
| Comandos | 12 | `Command*` 8 (PVP, SummonMarine/Pirate, Villagers), `MinepieceCommand{Add,Query,Set}Bounty`, `SetBountyLimit` | P2 |
| Spawner block | 3 | `MinepieceSpawnerOnBlockRightClicked/OnTickUpdate`, `ReadIDfromBlock`, `WriteIDtoBlock` | P3 |
| Haki | 4 | `KeyHaoshokuHakiOnKeyPressed`, `AIEntityHaoshokuHaki`, `AIEntityArmamentHaki`, `EntityHaoshokuHaki2OnEntityTickUpdate` | **P1** |
| Outros | ~100 | `PvP*Spawn`, `OBattle/OBounty/OCost/…` (HUD), `Render*` (cliente), `Kleiders*`, `SizeEvent`, `SetupDimensions`, `WanoCountryFeature…`, `RifleProjectile*`, `MissileProjectile*`, `ProjectileLaser*`, `TreasureChestRightclicked`, `MinePieceGetCompass/GetFlag`, `FlameBlade1-3`, `Karate5000Shuto`, `Karyudon`, `Kamusari`, `Iai`, `IaiSuper` (golpes soltos de personagens sem IA ligada) | P2/P3 |

### 2.3 Procedures que "traduzem" mas chamam método do Minecraft sem implementação
(`syncPlayerVariables` = envio ao cliente; muitas chamadas ficam atrás de `instanceof ServerPlayer`, o que o jogo responde "não é" — validar em runtime antes de implementar.)

| Método | Procedures | Alcançáveis | Observação |
|---|---|---|---|
| `syncPlayerVariables` | 80 | 37 | rede/variável do jogador; no jogo é local — pode ser no-op documentado |
| `getPlayerList` + `broadcastSystemMessage` | 67 | 66 | mensagens globais (ex.: aviso de recompensa/raid) |
| `syncData` | 44 | 37 | idem |
| `getConnection` / `getPlayerInfo` / `getGameMode` / `setGameMode` | 28 / 27 / 27 / 7 | 23 / 23 / 23 / 5 | modo de jogo (aventura/espectador na morte/PvP) |
| `closeContainer`, `players`, `getBlockEntity` | 16, 16, 5 | 1, 8, 1 | menus e spawner |
| `tame`/`isTame`, `getFoodData`/`setFoodLevel`/`setSaturation`, `getDifficulty`, `getLootTable`/`getRandomItems`, `getRecipeManager`/`getRecipeFor`, `startRiding`, `startFallFlying`, `setPickUpDelay`, `getBiome`, `sendBlockUpdated` | 1–5 cada | — | pequenos; a lista completa sai do passo 4 de "Como retomar" |
| Estáticos sem caso (`Mc.estatico`): `ItemHandlerHelper.giveItemToPlayer` (9), `NetworkHooks.openScreen` (5), `EntityArgument.getEntities/getEntity`, `DoubleArgumentType.getDouble` (15), `StringArgumentType.getString`, `BoneMealItem.growCrop/growWaterPlant`, `ServerLifecycleHooks.getCurrentServer`, `MinepieceMod.addNetworkMessage`, `PlayerAnimationAccess/Registry` | — | — | comandos Lv2 e entrega de item |
| `new` sem caso (`Mc.novo`): `BulletEntity` 4, `MissileEntity` 2, `BoogerEntity` 2, `ProjectileWaterBulletEntity` 2, `ProjectileFlameEntity`, `PlayerVelocityPacket`, `Arrow` | — | — | projéteis sem corpo no jogo |
| Cliente/render (`Minecraft.getInstance` 44, `RenderSystem.*`, `Tesselator`, `LevelRenderer`, `KleidersSkinRenderer`, 20 `Model*` por `new`) | ~55 | — | **não importar** (render do Minecraft); o jogo desenha com GLB |

Esforço estimado: M para o pacote "servidor" (no-ops/respostas coerentes com o jogo) + L para `getLootTable`/receitas/`tame` se os itens e domesticação entrarem.

## 3. Entidades e personagens

**Importado:** 112 fichas em `mapas/east_blue/personagens.json` (zonas: grand_line 30, novo_mundo 25, ruivo 10, superficie 7, arlong_park 5, shells/syrup/baratie/loguetown 4 cada, …) com modelo `mp_*.glb`
(119 arquivos em `mapas/modelos/`), IA do mod ligada (`IaDoMod.ligada = true`), spawn natural de 24 deles, 4 mobs genéricos. 114 outros têm só o visual `mpx_*.glb`.

**Falta — 114 personagens só com visual (sem ficha, sem spawn, sem missão, IA do mod sem caminho):**
`kaidou, bepo, luffy_1, lucci_cp_9, lucci_cp_0, shanks_four_emperors, marshall_d_teach(_four_emperors), luffy_2_years_later, luffy_wano_country, s_hawk, s_snake, s_bear, s_shark, pad, zoro_2_years_later, zoro_onigashima, kizaru, blueno_cp_9, jabra_cp_9, biscuit_warrrior, charlotte_cracker/katakuri/linlin/perospero/snack, tiger, rubble, fujitora, ashura(_doji), ulti, page_one, stussy, kaku_cp_9/cp_0, king, akainu(_fleet_admira), yamakaji, momonga, stainless, doll, doberman, sanji_1/2_years_later/onigashima, shiryu(_2), koala, sengoku, hack, jesus_burgess(_2), franky_2_years_later, gecko_moria, oars, marco, silvers_rayleigh(_old), penguin, killer_whale, vista, jozu, jack, edward_newgate(_heyday), scopper_gaban(_old), ryuma(_human), kalifa_cp_9, atmos, fossa, haruta, speed_jil, blenheim, thatch, izo, kingdew, bramenko, rakuyo, namur, curiel, kouzuki_oden, gol_d_roger, uta, nekomamushi, inuarashi, denjiro, kinemon, scratchmen_apoo, kikunojo, kawamatsu, tot_musica(_energy), imu, note_warrior_1/2, lilith, monster_2, rockstar, x_drake, whos_who, nero, red_king, bluegrass, enel, ethanbaron_v_nusjuro, hody_jones, rock_fragment, vasco_shot, dr_indigo, van_augur(_2)`.
Agrupar por arco (cada pacote = ficha + zona + spawn + conquistas + teste de IA):
- **P1** — Marinha/CP9–CP0/Almirantes (akainu, kizaru, fujitora, sengoku, momonga, koala, lucci/kaku/kalifa/blueno/jabra) e Shichibukai/Yonkou (kaidou, marshall_d_teach, shanks_four_emperors, charlotte_linlin/katakuri/cracker/perospero/snack, edward_newgate): chefes que o mod usa em Grand Line/Novo Mundo (zonas já existem em `personagens.json`). Esforço L (≈40 fichas + armas + `equipamento_padrao`).
- **P2** — Wano (oden, kinemon, kikunojo, kawamatsu, denjiro, nekomamushi, inuarashi, ashura(_doji), yamato, ulti, page_one, x_drake, jack, king, queen, sanji/zoro/luffy_onigashima) e Baratie/outros (Enel, Moria, Oars, Hody Jones, Rayleigh, Roger, Gaban, Ryuma, Shiryu, Burgess, Van Augur…). Esforço L.
- **P3** — Variantes (`*_2_years_later`, `*_old`, `*_humanbeast`), Seraphim, `s_*` (Seraphim), mobs auxiliares (`doberman`, `doll`, `rubble`, `rock_fragment`, `vasco_shot`, `tree_root`, `corps_pirates`, `corps_marine` — esses 3 últimos sem visual algum).

**Falta — projéteis/efeitos (47):** 10 sem modelo próprio: `bullet`, `projectile_laser`, `projectile_laser_red`, `projectile_water_bullet`, `projectile_flame`, `missile`, `entity_dynamite`, `heart_bullet`, `booger`, `entity_ball` (a Modelball existe, `modelos_java.entity_ball` extraído, falta ligar). Esforço S–M. As 4 invisíveis (`entity_impact`, `entity_impact_wave`, `entity_haoshoku_haki`, `entity_armament_haki`) estão certas.
Dependência: 2.3 (`BulletEntity`, `MissileEntity`… via `Mc.novo`).

**Falta — formas humanbeast de NPC** (geo `*_humanbeast`: jabra, kaidou, king, lucci cp0/cp9, marco, queen, sengoku, ulti, whos_who, yamato, kaku, nasujuro): modelos existem, troca de forma do NPC não verificada.

## 4. Modelos, animações, texturas, sons, partículas

- **Falta P2** — 42 dos 64 `Model*.java` sem uso: `Modelclothes_{ace,elitabello,law,luffy,marine1,oden,pirate,uta,v_nasujuro}` (armaduras de corpo), `Modelhaoshoku_{head,left_arm,right_arm}` (Rei, braços negros), `Modeleno_effect_*_flame` (Enel), `Modelwings_lunarian_large(_fly)`, `Modellunarian_flame`, `Modellunarians`, `Modelwings_bat_bat_fly`, `Modeltoritori_phoenix_humanbeast_fly`, `Modelhorns_{kaido,yamato}`, `Modelfishman_fin`, `Modelenel_drum`, `Modelfist(_small)`, `Modellaser`, `Modelmissile`, `Modeldynamite`, `Modelperona(_player)`, `Modelpaws(_slim)`, `Modeloverlay(_slim)`, `Modelmori_mori_flower`, `Modelsanji_leg`, `Modelfeather_robe`, `Modelwooden_spear2`, `Modelleopard_human_beast(2)`, `Modelinu_inu_wolf_humanbeast_slim`. Extrator: `tools/mine_piece/extrair_modelos_java.py`. Esforço M.
- **Falta P2** — raças/asas (Lunarian, Fishman, Cyborg, gigante): ligadas aos `Select*` (1.2 / 6).
- **Falta P3** — Animações dos 93 clipes do jogador: `position`/`scale` não aplicados, easing só `linear`/`easeOutExpo`, sem replicação em rede, rig skinnado não testado.
- **Falta P3** — Variantes `_fly`/`_slim` das formas Zoan, forma 2 do Kaidou, `feather_robe`.
- **Falta P3** — Sons: `unlimited_void.ogg`, evento `minepiece:guard` (sem arquivo mapeado). Timbre dos 87 sons vanilla-substituídos só "de ouvido" pendente.
- **Falta P3** — Texturas: `textures/mob_effect` (34 ícones de efeito), `textures/screens` (38), `textures/block` (74, para os 7 blocos e estruturas já convertidas), `textures/item` (389; só os 90 itens com `mpi_` + 26 ícones de fruta). Medir cobertura exata por arquivo (não feito).
- **Falta P3** — Scale/Pehkui `reach` guardado e não lido pelo corpo a corpo; `width` não alarga o jogador.

## 5. Itens, armas, roupas, blocos, receitas, loot

- **Armas/itens (116):** modelos 3D extraídos (90 `mapas/modelos/mpi_*.glb`), mas **sem confirmação de que o jogador as empunhe com a habilidade do mod**: `WeaponAbility*`, `Slot0–5`, `ShieldNote`, `ShieldUta`, `PunkPistols`, `Kitetsu*`, `Kikoku`, `Enma`, `Yoru` (já há `YoruController` nativo), `Wado/Shusui` etc. **P1/P2**, esforço L: uma tarefa por arma com habilidade (clique direito). Dependência: 2.2 (`WeaponAbility*`, `Slot*`).
- **Roupas/uniformes (213 peças, 71 classes):** hoje só texturas `mp_*_clothes_*` nos NPCs via `equipamento_padrao.json`. Falta equipá-las no jogador (item, slot, modelo `Modelclothes_*`/`GenericArmorLayer`, `GetArmorType`, efeitos por conjunto). **P2**, esforço L; dependência: 4 (Models `clothes_*`).
- **Blocos (7):** `iced_dirt/leaves/log/planks/stone`, `minepiece_spawner`, `sponge_super` (+ block entity). O jogo tem blocos dinâmicos (`McBlocosDinamicos`) mas não esses tipos nem seus loot tables (8 JSON). **P3**, esforço M.
- **Receitas (31)** e **loot tables (15: `loot_devil_fruit`, 4 de baú, 2 de gameplay, 8 de bloco):** nenhum importado. A loja do jogo substitui parte (frutas a 1 moeda). **P2/P3**; esforço M (um conversor `extrair_receitas.py` e um sistema de baús/loot). Dependência: itens equipáveis (5.1).
- **Itens utilitários do mod:** `skill_selector` (livro), `pirate_flag`, `raid_flag`, `treasure_chest(_locked)`, `MinePieceGetCompass/GetFlag`, bússola/bandeira do kit inicial: **P2**, esforço S–M.

## 6. Haki, estilos de luta, Rokushiki, formas, advancements, recompensa, profissões, raças

- **Haki (Observação / Armamento / Rei):** efeitos `ObservationHAKI`, `ArmamentHaki`, `SovereignHAKI` têm ganchos; **sem ação do jogador**: `KeyHaoshokuHakiOnKeyPressed` (tecla M = 77), `AbilityHaoshokuProcedure` só via fruta/IA, entidades `entity_haoshoku_haki(_2)`/`entity_armament_haki` (IA sem caminho). O jogo tem `mpeb_haki_do_rei` (skill builder, NÃO é do mod). **P1**, esforço M. Dependência: tecla 11 `Key*` e `Select*`.
- **Estilos de luta / classes / Rokushiki:** `Select{Swordsman,Fighter,Gunman,Rokushiki,Fishman,Giant,Lunarian,Cyborg,Zoro,Sanji,Mihawk,Garp,Roger,Shanks,Oden,Kaido,Sabo,Usopp,Curiel,Indigo,CelestialDragons,Elizabello2,General}` + menu `SelectTechniqueMenu`. Os `Skill*` correspondentes executam para NPCs (102/103 alcançáveis; só `SkillTornadoUoUo` sem caminho), mas o **jogador não pode escolher** nenhum. Rokushiki: `SkillRokushiki`, `Shigan/Rankyaku/Soru/Tekkai/Geppo/Rokuogan` existem no mod. **P1**, esforço L. Dependência: janela de seleção (UI) + `UpdateSelectTechnique` + `PlayerSkill1` (variável do mod).
- **Formas / Gear / Haki do Kaidou:** Gear 2/3/4/5 (`Gear*`, `ChangeGear`) alcançáveis; Zoan humanbeast do jogador OK (14/14), formas de NPC ver 3; formas gigantes OK (16/16).
- **Conquistas (123):** concedidas e travando golpes; **falta** janela/lista de conquistas, sincronização multiplayer, entrega do kit inicial (`StartMinePiece…`), `AdvancementOther*` de tripulação. **P2**, esforço M.
- **Recompensa (bounty):** `UpdateBounty`/`PlayerLevel` ligados; **faltam** comandos `MinepieceCommand{Add,Query,Set}Bounty`, `OBounty`, `ReturnTotalBounty`, lista de procurados. **P3**.
- **Profissões/raças:** o mod tem `can_use_iron_body`, `can_use_moonwalk`, `can_use_ryuo`, `can_use_shave` (tags de entidade), Lunarian/Fishman/Giant/Cyborg (`Select*` + `Modellunarians`/`fishman_fin`). Nada ligado ao jogador. **P2**, esforço L.

## 7. Mundo

- **Dimensões (3):** `dream_dimension`, `skypiea_dimension`, `wano_country_dimension` (+ `dimension_type`, `RaidSkypieaProcedure`, `SetupDimensionsProcedure`, `WanoCountryFeature…`). **Não importadas.** O jogo tem ilhas por zona (East Blue completo; Grand Line só como `zona` de personagens). **P2**, esforço L cada. Decisão do dono: dimensão = mapa novo? (gatilho: Grand Line jogável).
- **Estruturas:** 61/65; faltam técnicas `barrier`, `ocean`, `ocean_bottom`, `red_line` (a Red Line como parede intransponível é uma decisão de mapa). Navios: `ship_*` importados como `mpe_*`; **não nascem pelo `SpawnShip*` do mod** (2.2). P2.
- **Worldgen (131 JSON):** 9 biomas, 25 estruturas + `structure_set`, 53 `template_pool` (vilas/navios compostos), 10 `configured_feature`/9 `placed_feature` (árvores de cerejeira, etc.), `FeatureRedLine`, `OceanFeature`. Não aplicável diretamente (mapa de ilhas próprio), mas as **vilas compostas** e `FlowerCapitalBiome*` são conteúdo. P3.
- **Spawn natural:** 93 regras extraídas, 24 personagens; **gap**: o `biome_modifier` (96 em `data/minepiece/forge`) cobre personagens ainda sem ficha (ver 3). Depende de 3.
- **Mortes e ciclo:** `CorpsMarine/CorpsPirates` (spawn em massa) e `Pirate/Marine Crew*` (2.2). P2.

## 8. UI, HUD, teclas, comandos, eventos, efeitos, atributos, variáveis

- **Teclas do mod (10 `KeyMapping`):** R/Z/X/S/Espaço/W/M/… — 9 de 20 procedures alcançáveis; faltam Backstep (S duplo), Forward (W duplo), Space (voo/duplo pulo), Haoshoku (M), BattleMode, ForOrca, P, SwitchTechnique, ResetWASD. O jogo tem dash/pulo próprios; **decidir equivalência** (P1, esforço M).
- **GUIs/menus do mod (7):** `GUIName`, `GUIPirateRecruit`, `GUIPiratesSetting(2)`, `GUIPiratesMemberSetting`, `DisbandReconfirmation`, `SelectTechnique`. O jogo tem tripulação e HUD próprios — traduzir só o que carregar regra (nome da tripulação, recrutar, desfazer, ordens `Order*`, `MemberStandby/Fire/Accompany`). P2/P3.
- **HUD de efeitos e recarga:** ícones `mob_effect` (34) e telas do mod (38 texturas) sem uso; `Overlay*`/`OOverlay*` (17 procedures de dados) sem consumo. P3.
- **Comandos (4 classes, 14 literais):** `CommandPVP`, `CommandVillagers`, `MinePieceCommandsLv0/Lv2`. Parcial: o jogo interpreta comandos vanilla (`McComandos`: data, particle, kill, setblock, fill, effect, tp, playsound, scale…), mas **não os do mod**. P2, esforço M.
- **Eventos:** 38 handlers de `eventos_do_mod.json` ligados (`LivingTick/Attack/Hurt/Damage/Death`, `AdvancementEvent`); eventos de cliente (`KleidersRender*Event`, `RenderEntity`, `RenderFog`, `RenderSky`) fora de propósito.
- **Efeitos (34):** ganchos OK; `GearEffect*`, `Mamaragan*`, `FlyEffect*`, `DoubleJumpEffect*`, `StunEffect*`, `EffectShadowsAsgard*` aparecem como alcançáveis só se o efeito for aplicado — **testar efeito por efeito** (P2).
- **Atributos (7) e variáveis (83 geradas):** `FORM`/`SIZE` ligados; os demais atributos do mod e as 14 `GameRules` (ex.: regras de PVP/raid) não. P3.
- **Rede:** pacotes `Key*Message`, `GUI*Message`, `SelectTechniqueButtonMessage`, `PlayerVelocityPacket` são contados (`McRede`) e não enviados; multiplayer das formas/animações/conquistas não replica. P3 (gatilho: multiplayer com fruta Zoan ou conquistas).

## 9. Outras lacunas relevantes

- **Itens de unidade de lógica:** `OnLivingEquipmentChange`, `ArrowPassThroughEvent`, `MinepieceConfig` (config), `CustomBiomeProvider` — leitura de config do mod não existe no jogo. P3.
- **Modo PVP do mod** (`CommandPVPStart`, `PvPAllSpawn/MarineSpawn/PirateCrewSpawn/RandomSpawn`): não importado. P3 (o jogo tem arena/rodada própria).
- **Compatibilidade** (`vs_eureka`, `kimetsunoyaiba`, `Pehkui`, `PlayerAnimator`, `Kleiders`): `Mc` responde "mod ausente"; `kimetsunoyaiba` (10 blocos de Wano) usa textura vanilla de reserva.
- **Fidelidade pendente declarada nos checkpoints:** áudio nunca ouvido; `thunder_black` avermelhado; formas Zoan nunca vistas pelo dono; `nikyu/moku/pika` etc. já têm executor mas "revisar no jogo" é pedido em aberto.

---

## Priorização consolidada

| Prio | Tarefa | Depende de | Esforço |
|---|---|---|---|
| **P1** | Escolha de classe/estilo de luta pelo jogador (`Select*` 23 + `SelectTechniqueMenu` + `SkillSelector`) | UI nova; `UpdateSelectTechnique` | L |
| **P1** | Haki do Rei / Armamento / Observação acionáveis (`KeyHaoshokuHaki`, entidades `*_haki`) | teclas | M |
| **P1** | Teclas do mod ou equivalentes: Backstep, Forward, Space (voo/duplo pulo), BattleMode | decisão de mapeamento com o dono | M |
| **P1** | Guarda/aparo/recarga do mod (`LogicGuard*`, `LogicCooldown*`, `GuardMobEffect`) | — | M |
| **P1** | Habilidade das armas do mod (`WeaponAbility*`, `Slot0–5`) | 5 (armas equipáveis) | L |
| **P1** | Pacote de métodos de servidor ausentes (`broadcastSystemMessage`, `syncPlayerVariables`, `getPlayerList`, `getGameMode`…) | rodar medidor em runtime | M |
| **P1** | Conferência de fidelidade das 26 frutas novas + 2 golpes > 600 de energia | decisão de energia | L |
| **P1** | Personagens de alto impacto sem ficha (Marinha/CP/Almirantes/Yonkou, 114 só visuais) | `Mc.novo`/modelos Java | L |
| **P2** | Dimensões Dream / Skypiea / Wano | mapa novo | L (3×) |
| **P2** | Roupas/uniformes como armadura do jogador (213 peças) | `Modelclothes_*` | L |
| **P2** | Receitas (31) e loot tables (15), baús de tesouro, bússola/bandeira | itens | M |
| **P2** | Comandos do mod (PVP, bounty, villagers), tripulação (`Order*`, `Member*`), janela de conquistas | UI | M |
| **P2** | 42 `Model*.java` restantes (asas Lunarian, braços do Rei, chamas do Enel, chifres…) | extrator Java | M |
| **P3** | Blocos do mod (7), HUD de efeitos, texturas de screens, `reach`/`width` Pehkui, multiplayer de formas/animações/conquistas | gatilhos abaixo | S–M |

---

## Como retomar (reauditar)

```bash
cd ~/dev/skills-one-piece
python3 -I tools/mine_piece/medir_cobertura.py [--saida /tmp/cob.json]     # entidades, frutas, itens, estruturas, sons, conquistas
python3 -I tools/mine_piece/inventariar_frutas.py                          # 39 frutas, 185 seleções, fontes com SHA-256
python3 -I tools/mine_piece/medir_dependencias_minecraft.py                # o que o mod pede do Minecraft (358 métodos)
godot --headless --path . --script tools/dev_tests/compilar_procedures_mine_piece.gd   # compila as 1076 procedures (esperado 1075/1076)
godot --headless --path . --script tools/dev_tests/medir_ia_mine_piece.gd -- <ids>     # IA por personagem + contadores Mc._falta
godot --headless --path . --script tools/dev_tests/varredura_frutas_do_mod.gd -- <fruta…>  # aperta cada golpe das frutas
python3 ~/dev/agent-skills-suite/scripts/resumo_teste.py -- godot --headless --path . --script tools/dev_tests/test_camada_minecraft.gd
```
`Mc.pedidos_sem_implementacao` (em memória) é o relatório real de "pedidos sem implementação": imprimir ao fim de `medir_ia_mine_piece.gd` e da varredura de frutas
e anexar aqui (ainda não existe relatório salvo).

Alcance estático das procedures (esta auditoria) — esboço reproduzível, `python3 -I`:
1. `allp` = nomes em `src/minecraft/gerado/procedures/*.gd`; `edges[p]` = `Mc.proc(&"X")` e `…Procedure` citados no corpo.
2. raízes = `…Procedure` citadas em `src/**/*.gd` fora de `gerado/`; strings de procedure em `entidades_do_mod.json` (só entidades com modelo/ficha), `eventos_do_mod.json`, `efeitos_do_mod.json`.
3. fecho transitivo sobre `edges`; `sem caminho = allp − alcançadas`.
4. Métodos ausentes: `.metodo(` nas procedures menos `func metodo` em `src/minecraft/*.gd` e menos `execute*`.

## Gatilhos (quando reauditar)

- Depois de **regerar as procedures** (`traduzir.py`) ou mudar `Mc.estatico/novo/campo` → rodar compilação + alcance + métodos ausentes.
- Depois de **atualizar o mod** (novo jar: conferir SHA-256 em `ORIGEM.sha256`; 283 entidades / 1076 procedures / 123 advancements como linha de base).
- Quando **qualquer** personagem do item 3 ganhar ficha: rerodar `medir_cobertura.py` e o spawn natural.
- Quando o dono **jogar** as 26 frutas novas, as formas Zoan e o áudio: converter "executa" em "fiel" ou abrir defeito em `docs/LISTA_DE_CORRECOES.md`.
- Antes de começar **multiplayer** com Zoan, conquistas ou animações do mod: replicação (item 8 / rede).
- Quando o grafo de alcance passar de **80 %** (hoje 67 %) ou os métodos ausentes de servidor caírem abaixo de 20: reavaliar o escopo "mod inteiro".
- Se uma das **decisões em aberto** for tomada (energia das frutas 1000/1250; dimensão = mapa novo; tripulação nativa vs. do mod; mapeamento de teclas): atualizar este arquivo no mesmo commit.
