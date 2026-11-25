# Mine Piece completo — medição do que falta simular do Minecraft (23/10/2026)

Pedido do dono: "usar o rea para analisar o mod mine piece e implementar por completo ao jogo
primeiro medindo o que o skills one piece ainda precisa ou necessita simular do minecraft para que
o mod funcione".

## Fonte e integridade

- JAR: `MinePiece-ver14-forge-1.20.1.jar`, SHA-256 `349b36cd…3fbd765` — **o mesmo** no servidor
  (`~/server_onepiece/mods`) e nas duas instâncias do CurseForge.
- REA (`inspect_artifact`): 7275 arquivos, **todos com hash verificado, 0 contradições** de integridade.
  Evidência exportada: `export_evidence_bundle` (35 MB, fora do repositório).
- Fontes descompiladas usadas na medição: `~/dev/biblioteca-de-mecanicas/fontes-locais/minepiece-v14`
  (`ORIGEM.sha256` = o mesmo SHA). 2536 arquivos `.java`.
- ⚠️ O JAR chama o Minecraft por nomes **SRG** (`m_20256_`). `tools/mine_piece/srg_oficial.py` junta
  o mcp_config (ofuscado→SRG) com o mapeamento da Mojang (oficial→ofuscado) casando por DESCRITOR:
  64 225 nomes, 0 ambíguos. Sem isso, explosão/movimento/invocação pareciam não existir.

Reproduzir:

    python3 -I tools/mine_piece/medir_dependencias_minecraft.py     # o que o mod pede do Minecraft
    python3 -I tools/mine_piece/medir_cobertura.py                  # o que do conteúdo já está no jogo

## 1. Conteúdo do mod × jogo

| Conteúdo | No mod | No jogo |
|---|---|---|
| Personagens/criaturas (entidades) | 231 | 48 com modelo e ficha (`personagens.json`) |
| Projéteis/entidades de efeito | 47 | 0 como entidade (cada fruta traduzida recria os seus) |
| Frutas (tag `devil_fruit`) | 40 | 5 com executor nativo (Goro, Hie, Moku, Ope, Pika) |
| Estruturas | 65 | 61 importadas (`mpe_*`) |
| Sons | 34 | 10 |
| Efeitos do mod (MobEffect) | 34 | nenhum sistema compartilhado (lentidão e Mamaragan feitos dentro da fruta) |
| Conquistas ("grades", travam técnicas) | 123 | 0 (as frutas traduzidas ignoram a trava) |
| Itens | ~511 registros (213 roupas, 210 ovos de spawn, 32 frutas, 10 armas…) | — |
| Procedures (a lógica) | 1076 | traduzidas à mão as das 5 frutas, raid, nível/recompensa |

## 2. Sistemas do Minecraft que o mod usa (arquivos que dependem)

| Sistema | Arquivos | No jogo hoje |
|---|---|---|
| Animação GeckoLib (modelos + 267 animações) | 1082 | modelos convertidos (GEO→GLB); animações do mod **não** |
| NBT / dados persistentes (`getPersistentData`, comando `data` 107) | 1001 | metas avulsas por executor |
| Atributos (vida, dano, armadura, alcance, velocidade, empurrão, **SIZE**, **FORM**) | 702 | vida/força/armadura (`atributos_mine_piece`), resto por ficha; SIZE/FORM não |
| Itens e inventário | 678 | inventário próprio da história (não o do mod) |
| Sons | 596 | 10 de 34 importados |
| **Efeitos de poção** (35 do mod + 21 vanilla) | 575 | **sem sistema**: pontual por fruta |
| Blocos: ler/trocar/destruir (`setblock` 17, `fill`) — água 41, gelo, fogo, ar | 497 | **não existe** mundo de blocos mutável (o relevo em blocos é fixo) |
| Telas/HUD | 486 | HUD próprio |
| Dano e tipos de dano (35 tipos) | 286 | funil `CombatResolver` (sem tipo de dano) |
| **Comandos em texto** (data, particle, kill, setblock, effect, spreadplayers, playsound, scale, title, team, tp…) | 253 | **não existe** interpretador |
| Partículas (61 vanilla + 43 do mod) | 253 | por fruta (`VfxFrutaMinePiece`) |
| IA de mob (goals) | 244 | `cerebro_mine_piece` genérico para os 48 personagens |
| Movimento/teleporte | 222 | sim (corpo do jogador e NPC) |
| Variáveis do jogador (52: técnica, recompensa, fruta, forma, tripulação…) | 203 | parte em `ProgressaoDoPersonagem` |
| Invocar entidades | 192 | por técnica |
| Explosões | 170 | por técnica (sem explosão genérica) |
| Busca em área / projéteis / raycast | 133 / 95 / 72 | `MundoMinePiece.ataque_em_area` (22 usos) |
| Água/fluidos (SEA_POWER: fruta fraca na água) | 61 | água da história; fraqueza parcial |
| Fome | 51 | sobrevivência própria |
| Conquistas | 44 | não |
| Agendamento por tick | 32 | `MundoMinePiece.TICK` (0,05 s) |

## 3. A decisão de arquitetura (números)

As 1076 procedures chamam **358 métodos distintos** do Minecraft. Simulando os N mais usados:

| N | procedures 100 % cobertas |
|---|---|
| 50 | 26 % |
| 100 | 60 % |
| **150** | **88 %** |
| 200 | 94 % |
| 358 | 100 % |

"Coberta" = toda chamada tem equivalente; não inclui o comportamento das 283 entidades, as animações
GeckoLib nem diferenças de física (gravidade e tick já são os do Minecraft; colisão não).

## 4. Decisões do dono (23/10/2026)

- **Arquitetura: camada Minecraft + tradutor** — simular no Godot a API do Minecraft que o mod chama e
  converter as procedures em lote (Java → GDScript), revisando no jogo. Alternativa rejeitada: seguir
  traduzindo técnica por técnica à mão (5 frutas em várias sessões).
- **Escopo: o mod inteiro** — inclui haki, estilos de luta, formas, grades, Grand Line (em 20/10 o
  escopo eram só as frutas).
- **Primeira onda depois da base: personagens e IA.**

## 5. Plano (etapas verificáveis)

| # | Entrega | Validação | Depende |
|---|---|---|---|
| **E0** | Protótipo do tradutor (`tools/mine_piece/tradutor/`): procedure MCreator → GDScript contra a API da camada | % de procedures que viram GDScript que **compila** no Godot; meta ≥ 80 %. Abaixo disso, rever a arquitetura com o dono | — |
| E1 | Camada Minecraft (`src/minecraft/`): entidade-adaptador (Player, personagem, inimigo), NBT, efeitos (56), atributos (17), agendador por tick, dano com tipo, busca em área/raycast, explosão, blocos temporários na grade de 0,88 m, sons/partículas por nome, comandos (data, particle, kill, setblock, effect, tp, playsound, scale…) | testes por sistema contra números do Minecraft | E0 |
| E2 | Oráculo: procedures das frutas já traduzidas à mão (Goro/Hie/Moku/Ope/Pika) rodando pelo tradutor | mesmo dano, custo, alcance e tempo que a tradução manual | E1 |
| E3 | **Onda 1 — personagens e IA**: as 231 entidades (modelos GEO→GLB + animações GeckoLib, fichas, IA de goals, procedures `AI*`) | personagem do mod nasce, persegue, ataca com os golpes dele; chefes | E2 |
| E4 | Haki (3), estilos de luta, formas (Zoro, Sanji, haoshoku) | por técnica, contra o mod | E2 |
| E5 | As 35 frutas restantes (Logia → Paramecia → Zoan) | por fruta, contra o mod | E2 |
| E6 | Grades/conquistas (travas de técnica), itens e roupas, sons restantes, Grand Line | por sistema | E3–E5 |

Gatilho de revisão: se E0 ficar abaixo de 80 %, ou se E2 mostrar divergência de comportamento que a
camada não consiga fechar, parar e decidir com o dono antes de E3.

## 6. Checkpoint

- **23/10 ~13:40:** medição feita; decisões do dono; E0 começando.
- **23/10 ~15:00 — E0 CONCLUÍDA: 1075/1076 procedures compilam no Godot (99,9 %; meta 80 %).**
  - Tradutor `tools/mine_piece/tradutor/traduzir.py` (tree-sitter-java num venv local
    `tools/mine_piece/.venv`, fora do git): Java descompilado → `src/minecraft/gerado/procedures/*.gd`
    (fora do git: derivado do mod, regerável). Verificador: `tools/dev_tests/compilar_procedures_mine_piece.gd`.
  - Semente da camada: `src/minecraft/mc.gd` (`Mc`): registros, `proc`, `e` (instanceof), construção e
    estáticos genéricos — por enquanto devolvem null e CONTAM o pedido (`Mc.pedidos_sem_implementacao`).
  - Fora de propósito: `RenderSkyProcedure` (céu do cliente; no jogo o céu é do Godot).
  - Regras de tradução aprendidas: sobrecarga Java → `nome__N`; bloco solto → `if true:` (escopo);
    rótulo do descompilador → laço de uma volta; `_setval`/`_setvalx` do descompilador (lambda lê a última
    variante do bloco); palavras reservadas do GDScript em membros → `nome_`; atribuição e `i++` dentro de
    expressão → içados para a linha de antes.
  - Pendências medidas (o que a E1 implementa), por ocorrência: `new ResourceLocation` 2249,
    `BlockPos.containing` 1674, `new MobEffectInstance` 1125, `new Vec3` 812, `new CommandSourceStack` 637
    (comandos), `Component.literal/translatable` 813, `RandomSource.create` 324, `new ItemStack` 289,
    `Mth.nextDouble` 226, `new ClipContext` 214, `TagKey.create` 193, `new PlayerVariables` 191, `new AABB` 150.
    Relatório completo: `traduzir.py --relatorio ARQ.json`.
  - ⚠️ Compilar ≠ funcionar: `Mc.e()` ainda responde "não é" para todo tipo. O comportamento começa na E1.
  - Próximo: E1 — adaptador de entidade (Player/personagem/inimigo com getX, getPersistentData, hurt,
    addEffect…), NBT, efeitos, atributos, `instanceof` real, agendador; depois o oráculo da E2.
- **23/10 ~14:30 — spawn natural em todas as ilhas (pedido do dono) + E1 fatia 1.**
  - **Spawn natural** (`src/historia/east_blue/spawn_natural_mine_piece.gd`, regras do mod extraídas por
    `tools/mine_piece/extrair_spawn_natural.py` → `mapas/east_blue/spawn_natural.json`, 93 regras): tentativa de
    24–128 blocos do jogador no topo do relevo; peso; regra de região do mod (`(região OU 1 %) E 2,5 %`…) com a
    região vinda do MAR da ilha; bando; teto 8 MONSTER / 4 CREATURE; some > 128 blocos, 1/800 por tick > 32.
    24 personagens nascem hoje (id exato com ficha). F8 → "Spawn natural": liga/desliga + vivos/nascidos por ilha.
    Desligado sob `--script` (testes do mapa real não ganham hostis ao acaso). `test_spawn_natural_mine_piece` 17/17
    (11/11 ilhas; no Grand Line 0 de 24 do East Blue).
  - **E1 fatia 1** (`src/minecraft/`): `McEntidade` (adaptador em BLOCOS/ticks, yRot = 180° − rotation.y, vetor de
    visão do Minecraft, vida/`hurt` pelo funil do jogo, efeitos, atributos com a conta do Minecraft levando
    MAX_HEALTH ao corpo, NBT, capability), `McMundo` (tick 20/s, `getEntitiesOfClass`, variáveis do mod, placar),
    `McVec3`, `McAabb`, `McNbt`, `McEfeito`, `McAtributo`, `McRegistro`, `McTexto`, `McAleatorio`,
    `McTipoEntidade` (+ tags do mod: `tools/mine_piece/extrair_tags.py` → `mapas/east_blue/tags_de_entidade.json`),
    `McFonteDeDano`; variáveis do mod GERADAS de `MinepieceModVariables.java` (83, `gerar_variaveis.py`).
    `test_camada_minecraft` 27/27, com `ReturnEntitySizeProcedure` e `LogicAttackProcedure` reais (jogador pode
    atacar o Arlong; ninguém ataca a si mesmo).
  - **Medidor da IA** (`tools/dev_tests/medir_ia_mine_piece.gd`): 18 dos 24 personagens têm `AI<Nome>Procedure` e
    ela roda pela camada. Próximo (fatia 2 / onda 1), por frequência: `setSprinting`; ITENS na mão
    (`getMainHandItem`, alcance e dano de arma); `ItemStack.copy` e o mapa `ENTITY_DEVIL_FRUIT_MAP`;
    `instanceof Projectile`; ficha do mod por entidade (procedure do `baseTick`, imunidades do `hurt`, escala de
    `getDimensions`, `createAttributes`, metas) extraída das classes `entity/*Entity.java` — os 6 sem IA achada
    usam outro nome de procedure. Times (placar → tripulação) seguem contados.
- **23/10 ~14:40 — E1 fatia 2 (parcial; interrompida pelo limite de uso).**
  - Feito: itens (`src/minecraft/mc_item.gd`: `McItem` + `McItem.Pilha` = ItemStack com NBT/copy/is), equipamento
    na entidade (`getMainHandItem`, `setItemSlot`…), `setSprinting`, `instanceof` de projétil/item = falso para
    corpos do jogo; tradutor: bloco `static {}` → `_static_init`, `new HashMap/ArrayList` → `{}`/`[]`, métodos de
    coleção/Supplier por despacho da camada (`Mc.obter`, `Mc.por`, `Mc.adicionar`, `Mc.entradas`…).
  - Validação: `test_camada_minecraft` 27/27; compilação 1074/1076 — **regressão nova: `RaidSouthBlue20Procedure`
    deixou de compilar** com as regras de coleção (ver erro no log do verificador) — PRIMEIRO item da retomada.
  - Achado: a IA de cada entidade vem do `baseTick` da classe (piratas/marinheiros → `AIMobProcedure`, Buchi →
    `AIShamProcedure`, Alvida 2 → `AIAlvidaProcedure`, Zoro → `AIZoroProcedure`, Girl Icecream →
    `AICreatureProcedure`); a arma é equipada DENTRO da IA (ex.: `AIArlongProcedure`).
  - Próximo: (1) consertar RaidSouthBlue20; (2) rodar `medir_ia_mine_piece.gd` de novo e fechar o que sobrar;
    (3) extrair a ficha do mod por entidade (procedure do baseTick, imunidades do hurt, escala, atributos, metas);
    (4) DECISÃO DO DONO pendente: a IA do mod passa a dirigir os personagens no lugar do `cerebro_mine_piece`
    genérico, ou roda junto (o cérebro persegue/escolhe alvo e a IA do mod decide golpes)?
- **23/10 ~17:30 — E1 fatia 2 concluída + IA do mod ligada (atrás de chave).**
  - Regressão do RaidSouthBlue20 corrigida: `stream()` virou fluxo da camada (`src/minecraft/mc_fluxo.gd`: sorted,
    filter, map, findFirst, anyMatch, count…) + `Comparator.comparingDouble`. Compilação de volta a 1075/1076.
  - Ficha do mod por entidade: `tools/mine_piece/extrair_entidades.py` → `mapas/east_blue/entidades_do_mod.json`
    (282 entidades, 271 com IA no `baseTick`; ao nascer, imunidades, escala, `createAttributes`, metas). Os
    atributos do mod passam a ser a base no adaptador.
  - Tradutor: campos estáticos da classe reconhecidos (ENTITY_DEVIL_FRUIT_MAP); tags de ITEM e de BLOCO
    (`extrair_tags.py`); entidade com `getServer`, `getRotationVector`, `fallDistance`, montaria/fogo/ar…
  - Comandos em texto (`src/minecraft/mc_comandos.gd`): effect, kill, data merge entity (NoAI → cérebro para;
    Invulnerable → `damage_immune`, agora respeitada também pelo personagem; PersistenceRequired → o spawn natural
    não some com ele; Attributes), tp/teleport com `~`, attribute; seletores @s/@p/@a; `execute … run`. Os que
    dependem de sistemas por fazer (particle, playsound, title, advancement, team, setblock…) são CONTADOS.
  - `medir_ia_mine_piece.gd`: **24/24 personagens rodam a IA real do mod por 300 ticks, 0 erros, 0 pendências.**
  - **Decisão do dono: IA do mod JUNTO com o cérebro, atrás de chave.** `src/minecraft/ia_do_mod.gd` em todo
    `PersonagemMinePiece` (procedures do `baseTick` a 20 ticks/s; `finalizeSpawn` no 1º tick; argumentos pelo
    nome dos parâmetros). Começa DESLIGADA; F8 → "IA do mod (todos)". `test_ia_do_mod` 6/6: ligada, o Arlong
    ferido e com alvo saca a Kiribachi (comportamento do mod) e é marcado pirata pelo SetTagPirate.
  - Chave por personagem (o dono escolheu "liga por personagem"): hoje é UMA chave para todos — falta uma
    seleção por personagem no F8.
  - `test_camada_minecraft` 33/33 (+ seção de comandos).
  - Próximo (fatia 3): o VISUAL do que a IA já faz — item na mão desenhado (Kiribachi), partículas e sons
    por nome, animações GeckoLib das técnicas (`setAnimation`), projéteis/entidades de efeito do mod
    (`addFreshEntity`, 47 tipos); depois os 69 personagens sem modelo (onda 1).
- **23/10 ~18:10 — o COMBATE do mod roda de ponta a ponta (técnicas, eventos, efeitos, entidades, projéteis).**
  - Achado 1: a IA só ESCOLHE a técnica (`skill` = família × 50 + índice); quem EXECUTA é o efeito `minepiece:skill`:
    `applyEffectTick` → `CursedTechniqueOnPotionActiveTickProcedure`. Ganchos dos 34 efeitos extraídos
    (`tools/mine_piece/extrair_efeitos.py` → `mapas/east_blue/efeitos_do_mod.json`; 22 com procedure) e ligados no
    `tick_efeitos` (ordem do `LivingEntity.tickEffects`: tick conforme `isDurationEffectTick`, ao começar, ao acabar).
  - Achado 2: eventos do Forge (`tools/mine_piece/extrair_eventos.py` → `eventos_do_mod.json`, 38 handlers):
    `src/minecraft/mc_evento.gd`; LivingTickEvent no tick da IaDoMod; LivingAttack/Hurt antes da armadura e
    LivingDamage depois no `take_damage` do personagem; LivingDeath no `_morrer` (tudo atrás da chave).
  - Corpos virtuais (`src/minecraft/mc_corpo_do_mod.gd`) para entidades do mod sem corpo no jogo (entity_strike,
    projéteis): `EntityType.create/spawn` e `new XEntity(...)`; IA própria do mod; projétil (`AbstractArrow`, 8) com
    física por tick (gravidade 0,05, arrasto 0,99), acerto no segmento, dano de flecha e ganchos onHitEntity/onHitBlock
    da classe (extraídos em `extrair_entidades.py`). Sem desenho ainda (contado "visual:entidade:<id>").
  - Camada: `McBloco` (leitura: pedra/água/ar pela física), raycast `clip`, `noCollision`/`isInWall`, explosão com a
    fórmula do Minecraft, fogo, regras de jogo do mod (geradas) e vanilla, navegação, metas (HurtByTarget → cérebro),
    `registryAccess` (fonte de dano das técnicas), itens com classe-base (`extrair_itens.py`), `McFluxo`, String.format.
  - `medir_ia_mine_piece.gd`: 24/24 por 600 ticks, **0 erros**; faltas = só times e VISUAL (partícula `crit`,
    `entity_strike`, sons `entity.wither.shoot`/`attack.sweep`/`gun_shot1`, explosão, `projectile_water_bullet`…).
  - `test_ia_do_mod` 10/10 — inclui o handler RatioDamage (afogamento +25 % da vida máx.) e, em TEMPO REAL, as técnicas
    do Arlong ferindo o jogador pelo funil do jogo.
  - Armadilhas de medição registradas: alvo invulnerável (a IA larga o alvo); vida máx. enorme (a regeneração devolve);
    ticks acelerados (a invulnerabilidade de 0,5 s do jogador é em tempo real); NoAI não anda (pôr perto).
  - Próximo (fatia 3 — VISUAL): partículas e sons do mod por nome (os 34 sons + `particle_*`), desenho dos corpos
    virtuais (modelos GeckoLib `entity_strike`, projéteis), animações das técnicas (`setAnimation`/GeckoLib) e item na
    mão; depois times (placar → tripulação) e chave por personagem no F8.
- **24/10 ~11:30 — fatia 3 (VISUAL) parte 1: sons, partículas e corpo das entidades de golpe.**
  - `tools/mine_piece/extrair_visual.py` (jar → `assets/mine_piece/visual/`, fora do git, + `mapas/east_blue/visual_do_mod.json`):
    33 eventos de som (.ogg), 42 partículas (quadros viram tira horizontal), texturas `slash_*`/`projectile_*`.
  - `src/minecraft/mc_visual.gd` (`McVisual`): `som` (AudioStreamPlayer3D, teto 24), `particula` (CPUParticles3D, teto 48;
    mod = tira animada; Minecraft puro = círculo suave + `ESTILO`), `corpo`/`texturizar` (plano duplo cruzado do `geo` de
    `entity_strike`; textura vem de `setTexture`, tamanho do atributo SIZE). Sons do Minecraft puro (`entity.wither.shoot`…)
    usam SUBSTITUTO_SOM (som do mod de timbre parecido) — ESCOLHA PROVISÓRIA de ouvido, não conferida no jogo.
  - Ligado em `McMundo.playSound/playLocalSound/sendParticles/explode` e `McCorpoDoMod`.
  - Medido: `medir_ia_mine_piece` 24/24 sem erro; faltas restantes só `placar:getPlayersTeam` (times). `test_camada_minecraft` 33/33,
    `test_ia_do_mod` 10/10. ⚠️ Headless não renderiza: o DESENHO (partículas, plano duplo, áudio real) NÃO foi visto nem ouvido.
  - ⚠️ Após criar classe nova com `class_name`, rodar `godot --headless --import` (cache de classes globais).
  - Falta da fatia 3: projéteis com desenho próprio (hoje `projectile_*` usa o plano duplo genérico), animações GeckoLib das
    técnicas (`setAnimation`), arma na mão (Kiribachi); depois times e chave por personagem no F8. Captura com GPU pendente.
- **24/10 ~12:00 — fatia 3 (VISUAL) parte 2: arma na mão e animações das técnicas.**
  - **Arma na mão:** `geo_para_glb.py --itens` gera `mpi_<item>.glb` (90 itens com modelo; o item sozinho no espaço do osso da
    mão, mesma transformação do GeckoLib) → `mapas/modelos/mpi_*` (fora do git; precisa `godot --headless --import`).
    `McEntidade.setItemSlot` avisa o corpo; `PersonagemMinePiece.equipar_na_mao` prende no osso `itemMainHand`/`itemOffHand`.
    Limite: a arma do CONSTRUTOR do personagem já vem embutida no `mp_*.glb`; sacar OUTRA arma por cima não apaga a embutida.
  - **Animações:** o mod toca animação ferindo com o tipo `start_animation` (999999) → handler `PlayAnimationEntity` (LivingAttackEvent)
    escolhe o clipe pelos atributos `animation_1/2` → `triggerAnim("procedure", nome)`. Agora: `McEntidade.hurt` com esse tipo
    só dispara o evento (nunca dá dano); `triggerAnim` → `PersonagemMinePiece.tocar_tecnica` (clipe de mesmo nome; em laço vale
    até o reset "empty" ou 10 s); `Mc.e(x, GeoEntity)` = tem modelo animado; reflexão `getClass().getField/getMethod` reduzida.
  - Efeitos colaterais consertados no caminho: `getAllEntities`, `.iterator()` (`Mc.iterador`), conquistas como stub "já
    concluído" (contadas: `conquista:*`), `entity.server`; **tradutor: `break rótulo` de dentro de laço aninhado** agora sobe
    por bandeira `_sair_<rótulo>` (antes virava `break` simples → laço infinito em `WhenEntityDieProcedure`).
  - Medido: compila 1075/1076; `medir_ia` 24/24 sem erro (faltas: times, conquista haoshoku, explosão-bloco); `test_ia_do_mod` 15/15
    (Kiribachi desenhada no osso da mão; `triggerAnim` toca `punch_right`; no combate real a IA disparou `sword_to_right`);
    `test_camada_minecraft` 33/33. ⚠️ Nada visto em GPU: a POSE da arma na mão (rotação/escala) e a fluidez dos clipes
    precisam de captura.
  - Próximo: captura com GPU (Arlong com Kiribachi + clipes), depois times (placar → tripulação) e chave por personagem no F8.
- **24/10 ~12:15 — DECISÃO DO DONO: todas as habilidades de todos os inimigos vêm do mod, fiéis a ele.**
  - Antes (23/10): `CerebroMinePiece` lançava skills do SKILL BUILDER (`SkillsPublicadas` `mpeb_*` + `ExecutorDeSkill`, só com
    nomes/faixas/chances portados da ficha do mod) e a IA do mod ficava atrás de chave desligada. Isso NÃO era fiel.
  - Agora: `IaDoMod.ligada = true` por padrão; com IA do mod achada para o personagem (24/24 têm), `_ia_do_mod_dirige()` faz o
    cérebro só perseguir/escolher alvo — quem escolhe e executa técnica é a IA do mod (`minepiece:skill` →
    `CursedTechniqueOnPotionActiveTickProcedure`). Sem IA do mod (ou chave desligada) o cérebro volta ao plano B (skills portadas).
  - Testes: `test_ia_do_mod` 15/15 (agora afirma "começa ligada"), `test_east_blue_personagens` 11/11 com a chave desligada
    (mede o plano B), `test_spawn_natural` 17/17, `test_raid` 14/14. `test_luta_mine_piece_rede` é de 2 processos (servidor+cliente):
    sozinho falha com "RPC sem peer" — NÃO reavaliado nesta mudança. Pendente: rodá-lo como par.
  - Fidelidade ainda NÃO provada para: as skills do mod que dependem de sistemas por fazer (blocos, conquistas, times, partículas
    de comando) — ver contadores `Mc.pedidos_sem_implementacao`. Gatilho: antes de declarar "fiel", medir por personagem o que cada
    técnica do mod pede e não existe.
  - Captura com GPU (`tools/dev_tests/captura_visual_mine_piece.gd`, 28 fotos): Kiribachi na mão com o dente de serra do mod,
    clipes `sword_to_right`/`sword_overhead` com a arma acompanhando o braço, `entity_strike` desenhado como arco azul,
    partículas por nome visíveis. Ressalvas vistas: a IA (agora ligada) caminha até o jogador, então partículas disparadas na origem
    ficam longe dele; explosão = bolha branca macia (falta o cinza/estilhaço do Minecraft); partículas do mod (`thunder_*`) saem
    pequenas — conferir escala por partícula.
- **31/10 ~17:50 — MOVIMENTAÇÃO DO MINECRAFT traduzida e no jogador (decisão do dono: "base vanilla + habilidades por cima").**
  - **Fonte:** o jar do cliente 1.20.1 que o CurseForge instalou (`~/Documents/curseforge/minecraft/Install/libraries/net/minecraft/client/1.20.1-…/…-slim.jar`),
    remapeado para os nomes oficiais com `ForgeAutoRenamingTool --reverse --map …-mappings.txt` e decompilado com o Vineflower de
    `~/dev/biblioteca-de-mecanicas/ferramentas/`. Saída fica FORA do git (código da Mojang). O "repositório rea" citado no pedido é um
    servidor MCP de agentes (`rea-agents`), não código do Minecraft — não foi usado.
  - **Traduzido** (`src/minecraft/mc_movimento.gd`, puro, blocos/ticks): `LivingEntity.aiStep/travel/jumpFromGround/handleRelative…`,
    `Entity.moveRelative/getInputVector/move` (pós-colisão), `Player.getFlyingSpeed/travel`, `LocalPlayer.aiStep` (entrada ×0,98, agachar ×0,3,
    regra da corrida), atrito/velocidade/pulo de bloco (gelo, slime, alma de areia, mel), água, lava, escada, queda lenta, levitação.
  - **Ponte** (`src/player/movimento_minecraft.gd`): ticks de 0,05 s sobre os quadros do `move_and_slide`; só o ramo "andar/pular/cair" da
    `_etapa_locomocao` — geppo, vault, wall run, escalada, esquiva e técnicas seguem por cima (escrita vertical externa é adotada).
    `LocomocaoChao.observar` mantém estado/rumo/inclinação para a animação. Chave: `MovimentoMinecraft.ligado` (a locomoção antiga continua).
  - **Validação:** `test_movimento_minecraft` 23/23 (andar 4,317 b/s, correr 5,612, pulo 1,2522 blocos/12 ticks, queda 3,92 b/tick, gelo, mel, alma
    de areia, água, escada); `test_movimento_minecraft_jogador` 5/5 no Player real (3,799 m/s; 4,939 m/s; 1,102 m = números × 0,88 m/bloco; geppo
    ainda impulsiona). Regressão: agachar, escalada, knockback, parkour_rede, sequência_parkour, roll/dash, camada 33/33, spawn 17/17, east_blue — verdes.
  - **Testes alterados de propósito** (expectativas da locomoção antiga): `test_locomocao_chao` roda com `ligado = false`; `test_agachar` (velocidade
    agachada e diagonal do Minecraft), `test_escalada` (mede 0,25 s após a borda, não 0,5 s).
  - **Quirks do original mantidos:** diagonal em pé = reta ÷ 0,98 (+2 %); diagonal AGACHADO = reta × √2 (corrigido só no 1.21.2).
  - **Pendências com gatilho:** (1) id do bloco sob os pés → atrito/velocidade/pulo (gelo etc.) — quando o relevo em blocos expor o id;
    (2) água e escada ainda são do `jogador_na_agua`/parkour — migrar quando o dono pedir; (3) chave F8 para alternar; (4) personagens do mod
    (`PersonagemMinePiece`) ainda andam pelo cérebro próprio, não por `McMovimento`.
- **31/10 ~19:05 — SÓ A MOVIMENTAÇÃO DO MINECRAFT + fidelidade: times, dano e slots.**
  - **Locomoção antiga removida** (decisão do dono): `Player._etapa_locomocao` só usa `MovimentoMinecraft`; sem a chave `ligado`; o
    parkour deixou de ter pulo simples/salto longo próprios (ficam vault, geppo, salto de parede); `LocomocaoChao` virou só publicador de
    estado/rumo/inclinação (`observar`); `test_locomocao_chao` removido (media a locomoção velha). Passivas de pulo das frutas entram como
    `multiplicador_pulo`. A buff de arrancada da Rocket (`fator_aceleracao`) NÃO tem mais efeito (era da locomoção velha).
  - **Dois bugs achados pelo medidor** (`medir_ia_mine_piece`): (1) estouro de pilha — o handler `WhenEntityTakesDamage` fere com
    `damage_combat` de dentro do evento e a guarda `is(TagKey forge:combat)` nunca casava: faltavam as **tags de dano** (`extrair_tags.py` →
    `tags_de_dano`; `McFonteDeDano.is_` consulta tag) e o **tipo do dano** se perdia entre `McEntidade.hurt` e `take_damage` (agora vai por meta
    `fonte_mc` até `IaDoMod._fonte`); (2) `get_meta(x, null)` do Godot 4 é "sem padrão" e dá erro.
  - **Camada:** placar real (`Equipe`, `addPlayerTeam/ToTeam`, `getPlayersTeam/getPlayerTeam`) com a ponte do jogo — o jogador e a facção
    "aliado" são UMA equipe (`tripulacao_do_jogador`); `EquipmentSlot.byTypeAndIndex`; `new CompoundTag`; `setShiftKeyDown`, `setCustomName`,
    `saveWithoutId`, `load`; `McRede` (pacotes do Forge absorvidos e contados `rede:*`); tradutor: `intValue/longValue/doubleValue/floatValue`.
  - **Medido:** compila 1075/1076 (RenderSky fora de propósito); `medir_ia_mine_piece` 24/24 com **0 erros de script** (eram 1115);
    bateria verde (camada 33/33, ia_do_mod, spawn 17/17, east_blue 3/3 execuções, movimento 23/23 + 5/5, agachar, escalada, knockback, parkour).
  - **Lacunas de fidelidade que sobram** (em quantos dos 24 personagens aparecem): `comando:particle` 23, `queueServerWork` 15 (agendador
    do servidor), `setBlock` 14 + `NbtUtils.writeBlockState` 11 + `falling_block` 11 (blocos), `comando:playsound` 13, `put:Object` 11,
    haki (`entity_armament_haki` 7, `entity_haoshoku_haki` 3), `entity_impact` 5, `levelEvent:2001` 3, tornado/…
  - **Time dos inimigos:** só aliado↔jogador está ligado; times de pirata/marinha dos inimigos seguem pelo cérebro do jogo (decisão pendente).
- **31/10 ~19:25 — PARTÍCULAS E SONS por comando (`particle`, `playsound`, `stopsound`).**
  - `McComandos._particula` (`particle <nome> [x y z [dx dy dz vel [n [force|normal]]]]`, `~` relativo, `dust r g b tam`) e `_som`
    (`playsound <som> <fonte> <alvos> [x y z [vol [tom]]]`), ligados ao `McVisual` já existente. Partícula que o 1.20.1 não conhece
    (`minecraft:smoke_large`, `minepiece:particle:blue` — typos do mod) é erro do comando no original: não faz nada e NÃO conta como falta
    (`McVisual.PARTICULAS_VANILLA`, lido do `ParticleTypes` do jar). Extrator de sons passou a ler `playsound X` em strings de comando:
    54 eventos vanilla extraídos, 0 sem arquivo.
  - **Bug de desenho achado e corrigido pela captura com GPU** (`captura_comandos_mine_piece.gd`, 14 comandos): `anim_speed` era
    `quadros ÷ vida` (11–32×); no Godot 4, 1 = a tira passa UMA vez na vida. A tira ia ao último quadro (transparente) em milissegundos:
    explosão, trovões e fumaça saíam invisíveis/pequenos. Agora animam inteiros. Isso vale também para `sendParticles` (partículas das
    procedures e do `explode`).
  - **Visto:** cloud, large_smoke, flame, dust (cor do comando), chama/trovão azul/gelo/flor/vaga-lume do mod, big_smoke, flash,
    explosão (nuvem grande) e flash_red. Partícula única nasce no centro do corpo e fica DENTRO da malha (só as bordas aparecem) — igual
    ao Minecraft; não é defeito.
  - **NÃO verificado:** o ÁUDIO (headless e captura não ouvem): só se provou que os 3 sons criaram `AudioStreamPlayer3D` com arquivo.
    Timbre/volume/tom dos sons vanilla por substituição continuam "de ouvido" pendentes. `thunder_black` ficou avermelhada: conferir
    contra o mod.
  - **Medido:** `test_camada_minecraft` 42/42 (+9 verificações de particle/playsound); `medir_ia` 24/24; `comando:particle` e
    `comando:playsound` saíram das lacunas. Restam: blocos (setBlock/falling_block/writeBlockState), `queueServerWork`, haki, impact.
- **31/10 ~20:15 — AGENDADOR DO SERVIDOR + BLOCOS (B1–B4).** Decisões do dono: **cratera que se refaz**; blocos novos **sólidos, na grade
  de 0,88 m, com tempo de vida**.
  - **Agendador** (`McMundo.queueServerWork`, de `MinepieceMod.java`): todo item perde 1 no FIM de cada tick, roda quem chega a EXATAMENTE 0,
    na ordem de entrada; `ticks <= 0` nunca roda; trabalho agendado dentro de uma ação conta a partir do tick seguinte (o mod é assim).
  - **B1 blocos dinâmicos** (`McBlocosDinamicos`): `setBlock` põe o bloco numa SOBREPOSIÇÃO esparsa sobre o relevo (gelo, areia, terra… com
    colisão na camada do mundo; fogo, lava e água só desenho). Vida padrão 90 s (rede de segurança do jogo — o mod não tem vida e o que ele
    desfaz com `setBlock air` é honrado na hora), teto de 600 células (o mais antigo sai). `getBlockState` lê a sobreposição primeiro.
  - **B2 relevo cavável** (`McRelevoCavavel` + cortes reversíveis em `RelevoEmBlocos`): `setBlock air` num bloco de ilha vira um corte; no fim
    do quadro, por coluna, tira-se do TOPO para baixo (qualquer ordem de chamada); a malha e a colisão da ilha são refeitas numa THREAD
    (várias crateras = uma refeitura); em 3 min o corte se desfaz e quem ficou no buraco sobe (o relevo é uma casca: senão cairia pela ilha
    oca). **Achado:** a consulta física "há algo sólido aqui?" via ar todo o interior da ilha; `getBlockState` e o cavar agora leem o MAPA DE
    ALTURAS (`McRelevoCavavel.terra_em`). `RelevoDasIlhas` passou a manter `cor` (1 byte/meio, ~7,5 MB no total) e põe o corpo no grupo
    `relevo_em_blocos`. **Medido na `ilha_inicial` real (a maior, 1,6 M meios):** cratera de 179 blocos refeita em 875 ms fim a fim, sem travar.
  - **B3 bloco em queda** (`McBlocoQueda`, `minecraft:falling_block`): gravidade 0,04, arrasto 0,98, pousa pela física e vira bloco; 80 ao mesmo tempo.
  - **B4:** `NbtUtils.writeBlockState`, `Block.getId`, `Mc.por` em NBT, `McEntidade.load(BlockState)`, `levelEvent 2001` (som `block.stone.break`
    extraído + poeira), comandos `setblock` (destroy/keep/replace) e `fill` (replace [filtro], destroy, keep, hollow, outline; teto 4096).
  - **Visto com GPU na ilha real** (`captura_blocos_mine_piece.gd`): blocos sólidos de gelo/areia, a cratera com paredes em degrau, o entulho
    caindo e pousado, a ilha refeita. **Não visto/ouvido:** o som de quebrar bloco; fogo/lava/água como bloco só como desenho simples.
  - **Medido:** `test_camada_minecraft` 71/71; `test_relevo_cavavel_mine_piece` 14/14 (ilha sintética, raios reais); `medir_ia` 24/24 com 0 erros;
    bateria verde (relevo, descer_degrau, streaming, ia_do_mod, spawn, east_blue, movimento).
  - **Limites (com gatilho):** construções/árvores/vendedores sobre o relevo NÃO descem com a cratera; sem cavernas (cavar só o subsolo é contado
    `bloco:cavar_subsolo`); entulho que pousa em célula ocupada se perde (`bloco:queda_sem_lugar`, 14 no medidor — conferir se é empilhamento);
    fogo não queima nem fere; refeitura inteira da ilha (pedaços se a espera incomodar em ilhas > 1 M de meios); o medidor roda numa baseplate sem
    ilha, por isso `bloco:cavar_fora_de_ilha` aparece nele.
  - **Lacunas que sobram:** `entity_impact` 8, haki (`entity_haoshoku_haki`, `entity_armament_haki`), `MinepieceModAnimationMessage` 3, `hud:mensagem`.
- **31/10 ~21:20 — `entity_impact` (e as de haki): eram LACUNAS FALSAS — o mod nunca as desenha.**
  - O renderer do mod (`EntityImpactRenderer`, `EntityArmamentHakiRenderer`, `EntityHaoshokuHakiRenderer`) tem `isBodyVisible() = false` e
    textura `clear.png`: a entidade existe só pela IA (partículas, som, dano em área). `tools/mine_piece/extrair_invisiveis.py` lê isso dos
    renderers → `visual_do_mod.json: invisiveis`; `McVisual.e_invisivel` e `McCorpoDoMod.criar` não pedem mais desenho (desenhar seria inventar).
    Ordem de regeração do `visual_do_mod.json`: `extrair_visual` → `extrair_sons_minecraft` → `extrair_particulas_minecraft` → `extrair_invisiveis`.
  - **Visto com GPU** (`captura_impacto_mine_piece.gd`): sem corpo, só o círculo de nuvens e as faíscas no chão; a entidade some sozinha em 5 ticks.
    A IA delas passou a rodar INTEIRA e revelou `DecimalFormat` ausente (`HibashiraProcedure`): `McFormatoDecimal` (HALF_EVEN, ponto fixo).
  - **Bug meu corrigido:** o entulho (`McBlocoQueda`) escolhia a célula de pouso com `floor` e atravessava o chão não alinhado à grade (0,88 m):
    agora é `ceil` (primeira célula inteira acima da superfície). `bloco:queda_sem_lugar` 16–22 → 8 no medidor.
  - **Medido:** `test_camada_minecraft` 80/80; `medir_ia` 24/24, 0 erros de script. **Restam (24 personagens):** modelos GeckoLib sem conversão
    (`tornado`, `entity_bird`, `entity_ice_ball`, `entity_zeus`, `entity_impact_wave`, `entity_negative_hollow`, `entity_haoshoku_haki_2`,
    `entity_partisan`…: `geo_para_glb.py` existe), `MinepieceModAnimationMessage` (pacote de animação), `hud:mensagem`.
- **31/10 ~23:30 — modelos GeckoLib das entidades de efeito (tornado, zeus, bola de gelo, fênix, fantasma…).**
  - `tools/mine_piece/extrair_modelos_de_efeito.py`: id (`MinepieceModEntities`) → renderer → `XModel.java` (geo/animação/textura; a textura
    padrão vem do `defineSynchedData` da entidade) → `geo_para_glb.converter(sem_equipamento=True)`. **158 modelos** sem erro, em
    `assets/mine_piece/visual/modelos/mpx_<id>.glb` (git-ignorado; regerar: o script + `godot --headless --import`), manifesto em
    `visual_do_mod.json: modelos`; as 47 texturas alternativas de `setTexture("…")` do mod vão para `visual/entidades/`.
  - Jogo: `McVisual.modelo_de/_modelo/texturizar_modelo/tocar/ciclo_base`; `McCorpoDoMod` aceita `Node3D`, troca textura por `setTexture`,
    escala pelo atributo SIZE e toca `triggerAnim` (`tocar_tecnica`; "empty" volta ao ciclo base). Planos/sprites/míssil têm precedência;
    personagem com ficha criado por procedure (Kumacy) usa o `mp_<id>.glb` da loja.
  - **`entity_impact_wave` também é invisível** (textura `clear.png`): foi para `invisiveis`.
  - **Visto com GPU** (`captura_modelos_efeito_mine_piece.gd`): tornado escuro, fênix, bola de gelo em cubos, Zeus (nuvem com rosto), fantasma,
    partisan, com a textura do mod. **Medido:** `test_camada_minecraft` 88/88 (8 novos); `medir_ia` 24/24 com só `visual:entidade:tree_root` (era 9+).
  - **Restam:** `tree_root` (modelo Java escrito à mão, `Modelwooden_spear2` + camada `tex_ice` — mesmo caso do míssil: pede tradução das caixas);
    clipes: `entity_zeus` e `entity_prometheus` saíram SEM clipe no `.glb` (a animação do mod não tem trilha de osso utilizável: ver);
    escala/SIZE de cada modelo só conferida a olho; `hud:mensagem`.
- **03/11 — E2 (lado do JOGADOR pelo mod): o fluxo de teclas do mod já executa os golpes das frutas no jogador real.**
  - Fluxo: o jogador recebe a fruta pelas variáveis do mod (`PlayerDevilFruit`), `KeyChangeTechniqueDevilFruit` monta o golpe (nome, custo,
    número), `KeyStartTechniqueOnKeyPressed` carrega (segurar), `…OnKeyReleased` solta, e o efeito `minepiece:skill` →
    `CursedTechniqueOnPotionActiveTick` → `Skill<Fruta>` → golpe do mod executa. Nenhum skill builder, nenhum executor próprio.
  - Camada: `McEntidade.getInventory()` (armadura ligada ao equipamento, `setChanged`, `clearOrCountMatchingItems`; só mãos/armadura —
    mochila/hotbar do mod não existem no jogo), `isInWaterRainOrBubble`, `Vec3.atBottomCenterOf/atCenterOf/atLowerCornerOf`, `McVec3._xyz`
    tolerante (operando desconhecido vira falta `Vec3.operando`), comandos `spreadplayers` (só com `respectTeams`, como o 1.20.1: o literal
    `spreadplayers ~ ~ 5 10 @s` do mod é rejeitado no original e aqui) e `weather`.
  - Medido (`tools/dev_tests/sonda_jogador_mod.gd`, golpes 21–29 das 40 frutas, alvo Arlong a 4 m): **40/40 frutas escolhem golpe pelo mod;
    todas causam dano em algum golpe; 2 erros de script** (`isInWaterRainOrBubble` e `Vec3`, ambos corrigidos depois da varredura — **varredura
    ainda não repetida**). `test_jogador_mod` 11/11 (Gomu, Mera, Hie, Pika, Yami); `test_camada_minecraft` 88/88; `test_ia_do_mod` 15/15.
  - ⚠️ Armadilha: o recarregamento (`cooldown_time`) de uma fruta bloqueia a seguinte; teste que troca de fruta precisa de `removeAllEffects()`.
  - ⚠️ Achado: `entity_gomu_arm` nasce em (0,0,0) — `EntityType.create(world, …, BlockPos, …)` não aplica a posição. Não corrigido.
  - **Lacunas medidas do lado do jogador (por ocorrência nas 40 frutas):** `MinepieceModAnimationMessage` 2026 (o mod manda o NOME do clipe
    PlayerAnimator; 93 JSON em `assets/minepiece/player_animation/`, partes `body/torso/head/right_arm/left_arm/right_leg/left_leg`),
    `hud:mensagem` 170 (action bar), `conquista:…use_technique` 190, `bloco:cavar_fora_de_ilha` 1007 (baseplate do teste, não é falta),
    `comando:scale` 3 (Pehkui: formas gigantes), `visual:entidade:tree_root` 7.
  - **Pendências com decisão do dono:** (1) como o jogador DISPARA isso no jogo de verdade (hoje só por script): trocar a entrada/HUD das
    frutas pelo fluxo do mod; (2) como desenhar as animações do mod no corpo do jogador (retarget PlayerAnimator → rig do jogador).
- **03/11 (2) — O JOGADOR USA AS FRUTAS PELO FLUXO DO MOD (decisão do dono: "trocar pelo fluxo do mod"; animações por retarget).**
  - `src/combat/frutas_do_mod/`: `FrutasDoMod` (40 ids + perfil, sem depender do `Player`) e `ControladorFrutaDoMod` (herda o
    `ControladorFrutaMinePiece`: `Player`, HUD e `ModoHistoria` não mudam). R chama o `KeyChangeTechniqueDevilFruit` do mod, Z segura =
    `KeyStartTechniqueOnKeyPressed`, soltar = `…Released`; o efeito `minepiece:skill` executa o golpe. Lista de golpes do HUD vem do próprio mod
    (nome, custo), traduzida só na exibição (`McTexto.traduzir`, `mapas/east_blue/textos_do_mod.json`, 617 chaves; as procedures seguem com
    as chaves cruas porque comparam strings entre si). Energia ÚNICA: a do jogo; o que o mod gasta em `PlayerEnergy` volta a cada quadro.
    `ModoHistoria.equipar_fruta` e o save (`serializacao_do_progresso`) reconhecem os 40 ids. As fichas antigas (`*_mine_piece`) seguem pelo
    controlador antigo; os executores à mão continuam no código (oráculo da E2), sem uso para estes ids.
  - **Colisão de ids:** `gomu_gomu`, `ope_ope`, `bomu_bomu`, `tori_tori_phoenix` (e as outras 35 do mod) eram também frutas da ARENA/Builder com o
    mesmo id: no Modo História passam a ser as do mod. `test_frutas_na_historia` pula esses ids (50 → 15 conferem, 0 divergem).
  - **Medido:** `test_controlador_fruta_do_mod` 14/14 (Gomu e Mera: equipar → lista → Z segura/solta → dano → energia do jogo gasta → R troca),
    `test_jogador_mod` 11/11, `test_camada_minecraft` 88/88, `test_ia_do_mod` 15/15, 0 erros de script. `test_fruta_reconstruida` e
    `test_frutas_do_builder` falham por ambiente ("Skills Builder desativado, SOP_BUILDER=1") — não por esta mudança.
  - ⚠️ Armadilha de teste: tipo que depende do `Player` num script `--script` quebra a compilação ("Identifier not found: FruitNet", autoload).
  - **NÃO feito / com gatilho:** (1) animações do mod no corpo do jogador (retarget PlayerAnimator → rig; 93 clipes; o pacote
    `MinepieceModAnimationMessage` ainda só é CONTADO); (2) lentidão `movement_slowdown` e formas gigantes (`comando:scale`/Pehkui) não prendem/mudam
    o corpo do jogador; (3) `hud:mensagem` (action bar do mod) e as conquistas/grades não ligadas; (4) ~~`entity_gomu_arm` nasce em (0,0,0)~~ — NÃO era bug: o jogador do teste nasce na origem da baseplate e o braço nasce nele;
    (5) nada foi visto com GPU no jogador; (6) 38 das 40 frutas só foram varridas pela sonda, sem teste próprio; a varredura não foi repetida
    depois das correções de API.
- **03/11 (3) — ANIMAÇÕES DO MOD NO JOGADOR + lentidão + mensagens na tela.**
  - **Animações (retarget):** `tools/mine_piece/extrair_animacoes_do_jogador.py` (jar → `assets/mine_piece/visual/animacoes_jogador.json`, 93 clipes
    PlayerAnimator, 79 KB, git-ignorado) → `src/anim/pose_do_mod.gd` (`PoseDoMod`: conversão pura) → `src/anim/animacao_do_mod.gd` (`AnimacaoDoMod`,
    nó criado sob demanda no jogador) → meta `pose_do_mod` somado no `ProceduralAnimator` (gancho de 4 linhas ao lado de `pose_de_skill`; vale nos
    rigs voxel e skinnado porque o animador gira os 13 PAPÉIS). O pacote `MinepieceModAnimationMessage(clipe, alvo, override)` agora chega ao
    nó (`McRede.Animacao`): override=falso só toca se não houver clipe ativo; sem `hold_on_last_frame` o clipe termina e o corpo volta à locomoção.
  - **Convenção medida** (não suposta): rotação do rig = (−x, −y, +z) em ZYX; Torso = body·torso; Thigh = torso⁻¹·perna (no rig as pernas são filhas
    do Torso). Verificada pela DIREÇÃO do osso (`test_pose_do_mod` 12/12: braços à frente e convergindo em `both_arm_front`, sobem em `both_arm_up`).
    `test_animacao_do_mod` 14/14 no jogador real: pacote → braço sai do repouso no rig (z = −0,97 = frente) → volta ao fim; o golpe da Gomu escolhido
    pelo mod faz o mod mandar `punch_gomu_pistol1`.
  - **Visto com GPU** (`captura_animacao_do_mod.gd`, 8 clipes no meio de cada um): poses mudam de forma coerente com o nome (braços ao alto, soco, chute
    inclina o corpo, gear_2 curva o tronco). Enquadramento cortou as pernas e a câmera não é de frente: leitura geral, não conferência fina.
  - **NÃO aplicado (v1, com gatilho):** `position` do `body`/membros e `scale` dos clipes (agachar/dash/esticar braço) — ligar quando o rig tiver
    deslocamento de raiz; `easing` só `linear` e `easeOutExpo` (os dois que existem nos 93); clipes de outros jogadores (rede) não replicam; rig
    SKINNADO não testado; os 5 ossos de capa/armadura (`Mant*`, `armorRightArm`, `*_trans2`) ignorados.
  - **Lentidão:** `ControladorFrutaDoMod.controla_movimento/velocidade` — `movement_slowdown` da técnica em curso prende o corpo (−15 %/nível, a conta do
    Minecraft). **Mensagens:** `McEntidade.displayClientMessage` → `HistoriaHud.avisar` com o texto do mod traduzido (sem códigos `§`);
    `textos_do_mod.json` agora com 1438 chaves (`minepiece.*` inteiro). `test_controlador_fruta_do_mod` 23/23.
  - **Medido:** `test_pose_do_mod` 12/12, `test_animacao_do_mod` 14/14, `test_controlador_fruta_do_mod` 23/23, `test_jogador_mod` 11/11,
    `test_camada_minecraft` 88/88, `test_ia_do_mod` 15/15, 0 erros de script.
  - **Ainda falta:** `comando:scale` (Pehkui — formas gigantes: colisão/câmera do jogador, etapa de FORMAS); conquistas/grades (travas de técnica: hoje o
    stub as dá por concluídas, então TODA técnica está liberada — decisão de progressão do dono); `visual:entidade:tree_root`; clipes de
    `entity_zeus`/`entity_prometheus`; replicar animação em multiplayer; nova varredura das 40 frutas depois das correções.
- **04/11 — O QUE FALTAVA: posição dos clipes, varredura repetida, relâmpago, modelos Java, clipes de Zeus/Prometheus.**
  - **Posição dos clipes do jogador** (`PoseDoMod.amostrar_posicoes`, meta `posicoes_do_mod` somado em `posicoes_mine_piece.gd`): (−x, +y, +z) em px,
    1 px = 1,5/1,8/16 m (jogador 1,5 m ↔ 1,8 bloco); Torso = body + torso, coxa = perna − torso. Escala dos clipes segue NÃO aplicada. Medido:
    `death` desce 0,73 m e leva o Torso 0,52 m para trás (14 − 4 px); `gear_2` desce o Torso no jogador real e ele volta ao fim (`test_animacao_do_mod` 16/16).
  - **Varredura das 40 frutas repetida** (sonda, golpes 21–29, depois das correções): **360 golpes, 0 erros de script, 40/40 frutas causam dano**;
    `hud:mensagem` e `MinepieceModAnimationMessage` saíram das faltas. Sobram: `bloco:cavar_fora_de_ilha` (artefato da baseplate), `comando:scale`,
    `conquista:grade_3000_m`, `tree_root`/`entity_ball` (feitos abaixo), `lightning_bolt` (feito abaixo).
  - **Relâmpago `minecraft:lightning_bolt`** (Goro, Mamaragan, Abyss…): `McCorpoDoMod._passo_do_raio` com o ciclo do `LightningBolt` (vida 2, 1–3
    reclarões), 1ª batida com trovão + impacto e `thunderHit` (3 blocos em x/z, −3…+9 em y: 5 de dano `lightning_bolt` — a armadura reduz, como no
    vanilla — e fogo 8 s). Desenho `McVisual.raio` (coluna recortada de 40 m, 2 planos cruzados, luz de clarão). `test_raio_mine_piece` 7/7;
    visto com GPU: coluna branca recortada (um pouco acinzentada pelo tone mapping do céu).
  - **Modelos Java escritos à mão** (`tools/mine_piece/extrair_modelos_java.py` → `visual_do_mod.json: modelos_java`; `McVisual._modelo_java`):
    `tree_root` (21 peças, tex_wood) e `entity_ball` (58 peças, tex_black); peças aninhadas (translada + gira ZYX), escala pelo SIZE. Visto com
    GPU. NÃO feito: a camada de GELO sobre a raiz (`tex_ice`, condição `TreeRootDisplayCondition`) e o espelho (`mirror`) de 6 caixas da raiz.
  - **Zeus/Prometheus: NÃO era falta nossa** — `zeus.animation.json`/`prometheus.animation.json` do mod têm só um `idle` SEM ossos (114 bytes).
  - **Teste com carga:** `test_ia_do_mod` 14/15 uma vez com 9 processos em paralelo (invulnerabilidade de 0,5 s do jogador é em tempo real); sozinho
    15/15 duas vezes. Rodar essa bateria sem paralelismo.
  - **Rig skinnado do jogador:** inalcançável hoje (`ELENCO_LIBERADO` tranca o elenco) — teste removido em vez de furar a trava. O animador gira
    papéis, então deve valer; NÃO verificado.
  - **Ainda falta:** `comando:scale` (Pehkui — formas gigantes: etapa de FORMAS); conquistas/grades (decisão de progressão do dono, hoje tudo liberado);
    replicar animação do mod em rede; escala dos clipes; gelo da raiz.
- **04/11 (2) — CONQUISTAS DO MOD LIGADAS + FORMAS GIGANTES (pedido do dono: "ligar as conquistas e as formas gigantes").**
  - **Conquistas** (`src/minecraft/mc_conquistas.gd`, `jogador_do_mod.gd`; dados `mapas/east_blue/conquistas_do_mod.json` ← `tools/mine_piece/extrair_conquistas.py`):
    as 123 do mod DE VERDADE (antes: stub "já concluída" → toda técnica liberada). `getAdvancement/getOrStartProgress/award/revoke`, estado
    `{id: [critérios]}` em `ProgressaoDoPersonagem.conquistas_mod` (salvo junto, validado ao carregar: id e critério inventados somem). Concluir uma
    conquista dispara o `AdvancementEvent` (os handlers do mod concedem as habilidades que a grade libera: grade_30_m → skill_assault_attack…), aviso
    na tela e som. Comando `advancement grant|revoke … only|until|from|through|everything` (o `CompletedAdvancement` usa `until` para a cadeia de grades).
  - **Grades pela recompensa:** `JogadorDoMod` põe a recompensa do jogo (`recompensa_total`) em `PlayerBounty` e roda o `UpdateBountyProcedure` do mod
    (concede as grades 30 mil → 3 milhões; a cadeia `elif` do mod concede a MAIOR cruzada, as de baixo vêm pelo `until`). `PlayerLevel` é pré-igualado
    (cópia da conta, `nivel_do_mod`) para o `UpdateBounty` NÃO rodar `WhenRespawn` (cura e reescreve atributos que o jogo controla).
  - **O que as grades travam (medido):** a lista de golpes do mod. Gomu: 2 golpes no nível 1 → 3 com a recompensa alta (o Gatling pede grade). A lista do
    `ControladorFrutaDoMod` é refeita a cada conquista concluída. Mera, Pika, Goro, Hie e Yami não mudaram de tamanho com a recompensa 1,6 milhão.
  - **Conquistas por `tick` (14 raízes/abas):** concedidas ao ligar o jogador, SEM disparar o evento: o único handler que reage é o KIT INICIAL do mod
    (`StartMinePieceComplated`: livro seletor, bússola, bandeira de ataque) que o jogo não tem no inventário. Contado `conquista:kit_inicial_do_mod_nao_entregue`.
  - **Mensagem de recompensa:** o `UpdateBounty` do mod escreve "ganhou/perdeu recompensa" pelo HUD (`displayClientMessage`) além do aviso próprio do jogo:
    pode aparecer em dobro. Não suprimido (é o texto do mod).
  - **Tradutor:** referência de método LIGADA (`ref::metodo`) saía sem o objeto (`o.set()`): corrigido em `traduzir.py` (6 procedures regeneradas,
    compila 1075/1076); apareceu na `ChangeTechniqueTest` da Pika.
  - **Formas gigantes** (`scale set|add|subtract|get|reset pehkui:<height|width|reach>`): `McEntidade.escala/definirEscala` (teto 16×, piso 0,1×) →
    JOGADOR: `Player.definir_escala_de_forma` reaproveita o ponto único da raça (modelo + cápsula + hurtbox + câmera "os três ou nenhum"), tamanho =
    raça × forma; `escala_do_corpo()` também vale ao levantar do agachar. PERSONAGEM: `aplicar_escala_mc` (modelo, cápsula, hurtbox, rótulo). Corpo VIRTUAL:
    o desenho multiplica por `height`. `getBbHeight/getBbWidth/getEyeHeight` já devolvem a caixa escalada (é o que as procedures leem para alcance/partículas).
  - **Transformação (Zoan, `can_transform`):** tecla `B` no HUD (a do mod é `N`, ocupada pelo menu de frutas; Shift+B volta) →
    `ControladorFrutaDoMod.transformar` → `KeyTransformOnKeyPressed` do mod (atributo FORM, SIZE e Pehkui). Medido no jogador real: Hito Hito Daibutsu
    3,5×, Inu Inu Wolf e Neko Neko Leopard 1,5×, Ushi Ushi Giraffe 1,75×, Ryu Ryu Pteranodon forma 1 (SIZE 1), todas desfazem; trocar de fruta desfaz a forma.
    A passiva "Giante" do `WhenRespawn` (PlayerSkill1 = 10: 4/4/3) usa o mesmo comando.
  - **Visto com GPU** (`captura_forma_gigante_mine_piece.gd`, câmera REAL do jogo): jogador de 1,6 m → 6,4 m em pé no chão, câmera recua (y 5,8), Arlong pequeno ao lado.
  - **Medido:** `test_conquistas_mine_piece` 18/18, `test_formas_gigantes_mine_piece` 16/16, `test_controlador_fruta_do_mod` 27/27, `test_animacao_do_mod` 16/16,
    `test_pose_do_mod` 14/14, `test_jogador_mod` 11/11, `test_camada_minecraft` 88/88, `test_raio_mine_piece` 7/7, `test_frutas_na_historia` 0 divergem,
    `test_progressao`, `test_camera`, `test_escalada` e `test_agachar` verdes, `test_ia_do_mod` 15/15 (sozinho), 0 erros de script.
  - **NÃO feito / limites:** `reach` (Pehkui) é guardado mas o alcance do corpo a corpo do jogador não o lê; o `width` não alarga o jogador sozinho (cápsula e hurtbox
    são uniformes: manda o `height`); a PASSIVA Giante só roda se `WhenRespawn` rodar (o jogo não chama `PlayerRespawned` do mod); sem janela/lista de conquistas
    na tela (só o aviso ao concluir); o kit inicial do mod não é entregue; as conquistas não são sincronizadas em multiplayer.
- **14/11 — Pasta do modpack localizada + 1ª rodada da auditoria de frutas (pedido do dono: importar o mod fielmente; transformações e mecânicas falhavam).**
  - Instância: `~/Documents/curseforge/minecraft/Instances/One Piece - Sea World _ Mine Piece (Inspired by One Piece)` (217 mods). Jar do Mine Piece = o MESMO
    (`349b36cd…`, ver); GeckoLib 4.8.4, Pehkui 3.8.2, KubeJS 2001.6.5. `config/minepiece.toml` só tem 4 chaves (`forceNoSkills=false`, `hideSeaLocation=false`,
    `doVanillaMobSpawning=false`, `automaticallyEquip=true`); KubeJS só tem scripts de exemplo; `datapacks/` e `defaultconfigs/` vazios → o modpack NÃO altera o mod.
    Logo, falha de fidelidade = tradução/camada, não fonte diferente.
  - **Regressão medida:** `test_jogador_mod` 7/12 (era 11/11 em 04/11): `mera_mera`, `hie_hie`, `pika_pika`, `yami_yami` "feriu o alvo (0)" + `ITEM_HANDLER`
    (inventário do jogador). `FATOR_DE_PROJETIL=1.0` NÃO resolve. Passam: `test_camada_minecraft` 88/88, `test_controlador_fruta_do_mod` 31/31 (Mera acerta com a mira da
    câmera), `test_ia_do_mod` 15/15, `test_formas_gigantes_mine_piece` 16/16, `test_conquistas_mine_piece` 18/18. Causa NÃO identificada (hipótese: a sonda mira
    horizontal a 2,1 m de altura contra o Arlong; o Higan sai de uma bola de fogo que sobe, então ler o `dano=0` da sonda sozinho não prova bug do jogo).
  - **Risco de versão:** `src/minecraft/` (1117 `.gd`) e `tools/mine_piece/` estão FORA do git (só `gerado/` é ignorado de propósito). Sem histórico para bisseção.
    Gatilho: antes de qualquer refatoração grande da camada, o dono decide o commit.
  - **14/11 (2) — `test_jogador_mod` 12/12 de novo:** as 4 falhas eram do TESTE (não reposicionava o jogador entre frutas; Mera voa para onde a mira aponta, soltar cedo) e a asserção
    do `ITEM_HANDLER` (6 espaços) estava velha (a mochila entrou em 10/11). Sem regressão no jogo. Sonda e teste agora miram a câmera no peito do alvo.
  - **Varredura das 40 frutas** (`sonda_jogador_mod.gd`, golpes 21–29, 360 execuções, jogador real, alvo a 4 m): **0 erros de script**; única falta de camada nova = `bloco:queda_sem_lugar`
    (37 ocorrências, 13 frutas; maior: Kiro Kiro 18, Pika 5) — blocos que o mod faz cair sem célula livre no mundo de teste. `dano=0` NÃO prova defeito (golpes de buff/postura/forma/carga não ferem);
    fidelidade golpe a golpe exige comparar com o mod rodando (servidor `~/server_onepiece` tem o mesmo jar) — não feito.
  - **14/11 (3) — comparação ESTÁTICA (escolha do dono; o mod só dispara por pacote de tecla de cliente, sem cliente automatizável).** Cruzei os 51 stubs da camada
    (`pass`/`return null|false|…`) com o uso nas 1076 procedures: 30 são chamados. Cosméticos/inofensivos: `isClientSide`, `setChanged`, `swing`, `setSilent`, `getValue`
    (propriedade de bloco → false), `getGameModeForPlayer`. **Corrigidos (mudavam jogabilidade):** `setPierceLevel` (12 usos, ex. chamas do Higan = 50: o projétil atravessa n+1 alvos
    como `AbstractArrow.piercedEntities`; antes sumia no 1º) e `setNoGravity` (2 usos). `src/minecraft/mc_entidade.gd`, `mc_corpo_do_mod.gd`; teste novo `test_projetil_perfura` 6/6.
    Regressão: camada 88/88, jogador_mod 12/12, controlador 31/31, ia 15/15, raio 7/7, teclas 8/0. `test_aro_aro_seta` ("as três flechas voaram") **já falhava antes** (confirmado com os
    arquivos originais do backup) — não investigado.
  - **Stubs que ainda DIVERGEM e valem uma análise (não feitos):** `getBlockEntity` (15 usos, null), `setTicksFrozen/getTicksFrozen/getPercentFrozen` (Hie, 5 usos), `startRiding` (1),
    `getTeam/isAlliedTo` (fogo amigo/alianças), `getDifficulty` fixo NORMAL (4), `isLoaded` (9, false).
  - **14/11 (4) — congelamento, análise dos stubs restantes e Zoan nas formas.**
    - `setTicksFrozen/getTicksFrozen/getPercentFrozen/isFullyFrozen` implementados como o vanilla (140 ticks = congelado, cai 2/tick, 1 de dano a cada 40 ticks congelado); teste em `test_projetil_perfura` (9/9).
    - **Decididos como NÃO divergentes** (análise das procedures): `isLoaded` → false é FIEL (o modpack não tem `jujutsucraft` nem `hakminepiece`); `getBlockEntity` → null serve (o mundo voxel não tem
      blocos com entidade; só o spawner do mod e a cópia em `BlockDestroyAllDirection` o leem); `getTeam` (1 uso, sem times no jogo). **Escolha de design** a revisar: `getDifficulty` fixo NORMAL (o
      modpack usa `easy` em `options.txt`; afeta `GetDifficultyLevel` e o spawner do mod). `startRiding` (1 uso, Uta montada no dono) segue sem efeito.
    - **`reach` (Pehkui) NÃO implementado de propósito:** o mod só usa `reach 3` junto de `height 4` (forma gigante); o corpo escala 4× e os golpes do jogo varrem por ossos, então o alcance real já passa de 3×.
    - **Kit inicial do mod NÃO entregue de propósito:** livro seletor/bússola/`raid_flag` têm equivalentes no jogo (escolha de fruta própria, `jogo:bandeira`); entregar duplicaria sistemas.
    - **Teste novo `test_zoan_golpes_nas_formas`** (10 Zoan + Okuchi; `ZOAN_ONLY=a,b` filtra): transforma pelo controlador, roda cada golpe da forma sem faltas novas, volta à forma 0. Armadilha: o `ativo` do
      controlador é recalculado por quadro — esperar ~10 quadros depois de `removeAllEffects` antes de `transformar(true)`, senão o pedido é ignorado.
  - **14/11 (5) — `test_zoan_golpes_nas_formas` 33/33** (11 frutas Zoan: transforma → todos os golpes da forma sem faltas novas → volta à forma 0 com escala 1). A falha intermitente era do teste:
    a progressão (`fruta_a_equipar`) re-equipa o estilo base num `mudou` se a fruta não estiver registrada nela; o teste agora usa `comer_fruta` + `item_ativo="fruta"`.
    **Em aberto:** `getDifficulty` fixo NORMAL (modpack: easy), `startRiding` (Uta), `test_aro_aro_seta` (falha antiga), janela de conquistas, kit inicial/`reach` (decididos fora), rede (animação/conquistas),
    comparação golpe a golpe com o mod rodando (sem cliente automatizável) e o commit de `src/minecraft` + `tools/mine_piece` (aguardando decisão do dono).

### 14/11 (6) — `bloco:queda_sem_lugar`
Não era falta da camada: bloco em queda que pousa em célula ocupada se perde, igual ao `FallingBlockEntity` sem `dropItem`. O contador deixou de registrá-lo (`mc_bloco_queda.gd`); camada 88/88.

### 14/11 (7) — `test_aro_aro_seta` e Zoan
`test_aro_aro_seta` falhava por artefato do teste: zerava `c.recarga`, mas a recarga real é `_recargas[técnica]` (recalculada por tick), então o 2º tiro era recusado. Teste limpa `_recargas`; 9/9. Zoan reexecutado após a mudança em `mc_bloco_queda.gd`: 33/33.

### 14/11 (8) — conquistas, Uta, dificuldade (fechamento das pendências)
- **Janela de conquistas:** já existe e está ligada (`JanelaDeConquistas` no `HistoriaHud`, árvore de 108 conquistas). Testes: janela 9/0, árvore 11/0, conquistas do mod 18/18. A pendência da lista estava desatualizada.
- **`startRiding` (Uta):** só `AIUtaProcedure` o chama, e só se o dono for `TotMusicaEntity`. Nenhuma das duas entidades existe no jogo (sem classe, sem spawn), então o ramo nunca roda. Decisão: continua `false`. **Gatilho:** implementar (seguir o dono por tick, invisível se forma ≥ 2) quando Uta/Tot Musica entrarem no elenco.
- **`getDifficulty`:** fica NORMAL (o jogo tem a própria curva de dano; o modpack usa `easy`). **Gatilho:** revisitar se o dono quiser dano do mod idêntico ao do modpack.
- **Aberto de verdade:** commit de `src/minecraft` + `tools/mine_piece` (aguarda autorização), rede da animação/conquistas do mod em multiplayer, golpe a golpe contra o mod rodando (sem cliente automatizável).

### 14/11 (9) — rede: animação do mod replicada
- **Antes:** `MinepieceModAnimationMessage` tocava o clipe só no corpo do servidor (o meta `pose_do_mod` não é replicado) — os outros peers e o próprio dono não viam a pose.
- **Agora:** `McRede._tocar_animacao` toca local e, se o processo é o servidor, chama o RPC `Player._net_animacao_do_mod(clipe, sobrescrever)` nos outros peers (o receptor só aceita do peer 1, onde o mod roda: `ControladorFruta.servidor()`).
- **Prova:** `tools/dev_tests/test_animacao_do_mod_rede.py` (host + cliente ENet reais): os dois peers tocam o clipe do corpo do host E o do corpo do cliente — 2/2 em cada. Regressão: pose 14/14, camada 88/88, jogador 12/12.
- **Conquistas em rede: decisão.** `conquistas_mod` é estado da `ProgressaoDoPersonagem` local de cada jogador (salva no próprio arquivo; janela e árvore só leem). Não há o que replicar para os outros peers. **Gatilho:** se o modo história virar co-op com o servidor simulando o personagem de outro peer, as conquistas desse corpo precisam viver no servidor e ser enviadas ao dono.

### 14/11 (10) — versionado e fechamento
Dono autorizou (14/11): commit em branch separado + implementação dada por concluída com a comparação estática (sem cliente para golpe a golpe). Branch `mine-piece-camada` (commit 8f63584, 140 arquivos: `src/minecraft`, `tools/mine_piece`, testes e este doc; no `Player.gd` só o RPC da animação). Feito por índice temporário: o branch atual, o índice e a árvore do dono ficaram intocados. Atenção: o branch depende de arquivos de `src/` ainda fora do git no repositório (ex.: `src/combat/frutas_do_mod`, `src/anim`), então só roda junto com a árvore de trabalho atual.
