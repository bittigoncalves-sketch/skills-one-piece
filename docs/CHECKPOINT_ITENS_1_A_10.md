# Checkpoint — itens 1 a 10 da auditoria (início 09/11/2026 23:50)

Pedido do dono: "realizar todas do 1 ao 10 e ao final desligar o pc". Fonte: `docs/FUTURAS_TAREFAS_MINE_PIECE.md`.
Regra desta execução: cada item entra por FATIAS verificáveis (teste que falha antes/passa depois); o que não couber fica descrito aqui com gatilho.

| # | Item | Estado | Evidência / o que falta |
|---|---|---|---|
| 1 | Escolha de classe/estilo (`Select*`) pelo jogador | **PARCIAL (API)** | `src/combat/estilos_do_mod.gd`: `EstilosDoMod.escolher(jogador, id)` roda a `Select*` das 23 classes + 'sem estilo' (cada uma define `PlayerSkill1`: Zoro 1, Shanks 2, Kaido 3, Rokushiki 4, Mihawk 5, Espadachim 30, Lutador 31, Pistoleiro 32…) e `voltar_as_frutas`. `test_estilos_do_mod` 6/0, fluxo sem erro de script. Consertos no caminho: `removePermanentModifier` (atributos), `MinepieceConfig` (4 booleanos com os padrões do mod), `Mc.obter0` de primitivo, e `SelectedArmorEquip` substituída por no-op explícito (o jogo não tem armadura do Minecraft; ver item 9). **Falta (o grosso):** um controlador que LISTE e dispare as técnicas do estilo (números 1–20 de `KeyChangeTechniqueOnKeyPressed`/`Skill<Estilo>`), como o `ControladorFrutaDoMod` faz para frutas, e a aba ESTILO na central. Sem isso NÃO expus tela de escolha: o jogador escolheria e ficaria sem como usar. |
| 2 | Haki acionável | **FEITO (Rei)** | Tecla **H** → `KeyHaoshokuHakiOnKeyPressed` (`src/combat/teclas_do_mod.gd`, ligada na `HistoriaHud`). Sem a conquista `skill_haoshoku_haki` o mod avisa "Can't use it now"; com ela a técnica começa (skill 255) e o efeito `sovereign_haki` fica ativo. `test_teclas_do_mod` 8/0. **Falta:** Haki de Armamento/Observação como ação própria do jogador (o mod só os dá por habilidade/IA) e as entidades `entity_haoshoku_haki`/`entity_armament_haki` (corpo/IA). |
| 3 | Teclas do mod (Backstep/Forward/Space/BattleMode…) | **PARCIAL** | **G** = modo de batalha (`KeyBattleMode`; desligado bloqueia técnicas, como no mod; avisa na tela). Backstep/Forward/Espaço NÃO mapeados de propósito: o jogo tem esquiva, dash e pulo nativos (gatilho no cabeçalho de `teclas_do_mod.gd`). `ForOrca`, `P`, `ResetWASD` não ligadas. |
| 4 | Guarda/aparo/recarga do mod | **PARCIAL** | O dano que o JOGADOR recebe agora passa pelos eventos do mod (`LivingAttack/Hurt` antes, `LivingDamage` depois) em `JogadorDoMod.ao_receber_dano/dano_final`, ligado no `Player.take_damage` (guarda de reentrada). Prova: Haki de Armamento do mod reduz o dano (79,4 → 0,0); sem ele volta a 79,4; 50 golpes sem laço (`test_dano_do_jogador_pelo_mod` 5/0). **Falta:** o jogador APLICAR o efeito `minepiece:guard` (a guarda é efeito aplicado por procedures de IA; não achei o gatilho do jogador — provável Ctrl/sneak), aparo (`LogicGuardJust`) e a recarga visível (`LogicCooldown*`). Regressão geral: só as falhas já conhecidas. |
| 5 | Habilidades/slots de arma (`WeaponAbility*`, `Slot0–5`) | **PARCIAL (API)** | `src/combat/armas_do_mod.gd`: `ArmasDoMod.usar(jogador, id)` = `WeaponAbility` + `WeaponAbilityUsed` das 14 armas do mod; recarga REAL por item (`getCooldowns()` deixou de ser no-op). `test_armas_do_mod` 43/0. **Falta:** o jogador SEGURAR essas armas (o inventário do jogo não tem os itens do mod) e o clique direito que chama `usar` (gatilho no cabeçalho do arquivo). `Slot0–5`/`SlotUpdate` são a GUI de equipamento do Minecraft (containerMenu): não se aplicam. |
| 6 | Métodos de servidor ausentes | **FEITO** | `src/minecraft/mc_servidor.gd` (+ ganchos em McMundo/McEntidade/Mc.estatico): `getPlayerList().broadcastSystemMessage` (67 procedures), `players`, modo de jogo, `getFoodData`, `tame`, `getBlockEntity`, `getDifficulty`, `Minecraft.getInstance()…`. `syncPlayerVariables/syncData` já existiam (a auditoria errou). Teste `test_pacote_de_servidor` 14/0. Sobram: render/cliente (de propósito), `getLootTable`/`getRandomItems` (item 9), `getBiome`, `setTag`. |
| 7 | Personagens só-visual (114) | **AUDITORIA CORRIGIDA** | Medido com `tools/dev_tests/varredura_spawn_entidades_do_mod.gd`: das 282 entidades do mod, **273 nascem (`McCorpoDoMod`) com 0 erros de script**; as 9 que "não nascem" (ashura, corps_marine/pirates, entity_arrow/bird/dark_ball/gomu_arm/gryphon/tot_musica_arm) se encerram sozinhas em poucos quadros (projétil sem dono/spawner de bloco); 5 efeitos sem malha (haki, dynamite, impact). Ou seja, o que falta aos ~114 NÃO é nascer: é (a) ficha de balanceamento no `personagens.json` e (b) lugar no mapa/spawn natural — decisão de design do dono (onde e quando aparecem). Eles já nascem por `/minepiece summon` e pela IA do mod. |
| 8 | Fidelidade das 26 frutas + golpes > 600 de energia | **PARCIAL** | Os golpes de 1000/1250 NÃO são bug de energia: são progressão do mod (`ChangeTechniqueTest` limita o custo pela GRADE de recompensa: 1000 pede `grade_1500_m`, 1250 pede `grade_3000_m`; energia máx = 200×round((2+nível)/1,1)). `test_golpes_acima_da_energia` 7/0: Kage Asgard oferecido, desbloqueado e executa (gasta 1000). **Pendente:** Zushi Meteor (1250) é oferecido/desbloqueado mas termina no mesmo tick sem gastar energia (causa não achada; `LogicStart` vira falso após selecionar). Fidelidade das 26 frutas: só 'o golpe começa' (varredura de rotação 80/80); comparação com o mod original segue em aberto. |
| 9 | Dimensões / armadura / receitas / loot / modelos Java | **PARCIAL (dados)** | `tools/mine_piece/extrair_dados_do_mod.py` → `receitas_do_mod.json` (31), `loot_do_mod.json` (15), `modelos_java_todos.json` (64 modelos, com `mirror`). **Loot funcional**: `McLoot` + `getLootData().getLootTable(id).getRandomItems()` (a fruta aleatória `GetRandomItem` e o livro de habilidade agora executam). `test_dados_do_mod` 9/0. **Falta (não feito):** ligar receitas a uma bancada, usar os 64 modelos Java (só os de forma Zoan estão em uso), as 3 dimensões (Dream/Skypiea/Wano — exigem mapa novo, decisão de design), roupas como armadura do jogador (213 peças). |
| 10 | GUIs, comandos e janela de conquistas | **PARCIAL** | Janela de conquistas: aba CONQUISTAS da central (M), `src/ui/janela_de_conquistas.gd`, 108 conquistas que o jogador faz, `test_janela_de_conquistas` 9/0. Comandos: `/minepiece bounty set|add|limit|query` e `summon <região> pirate|marine <n>` via `McComandos` + `Contexto` + estáticos de argumento; `test_comandos_do_mod` 9/0 (caminho feliz do summon não exercitado). **Falta:** as 7 GUIs do mod (tripulação/recrutar/desfazer — o jogo tem as próprias), `CommandPVP`, `CommandVillagers`, raid por comando (nativo). |

## RESULTADO (10/11/2026, ~00:50)
Nenhum dos 10 itens é "100 % fechado" — são tarefas de semanas. O que entrou, testado: **6 FEITO**, **2 (Haki do Rei) FEITO**, e fatias reais e testadas de 1, 3, 4, 5, 7 (medição), 8, 9 e 10.
Todas as suítes novas passam (pacote de servidor 14, golpes acima da energia 7, janela de conquistas 9, comandos do mod 9, teclas do mod 8, dano pelo mod 5, dados do mod 9,
armas do mod 43, estilos do mod 6, procedures otimizadas 13); a regressão de 37 suítes só mostra as falhas que já existiam (Goro 3 — custo de energia 396 em vez de 400;
Nikyu 3 — custos/recargas; Atiradores 4; projéteis visíveis 3; transformação na história 7 e Moku 20 por "Skills Builder desativado"). Nada foi commitado.

### O que falta, por item (ordem sugerida de valor)
1. **Estilos jogáveis** — controlador de técnicas de estilo (1–20) + aba ESTILO na central. É o maior buraco de jogabilidade.
2. **Haki de Armamento/Observação como ação do jogador** + corpos das entidades `*_haki`.
3. **Guarda/aparo**: achar o gatilho do efeito `minepiece:guard` do jogador (provável Ctrl) e ligar `LogicGuardJust`/recarga visível.
4. **Armas do mod no inventário** + clique direito → `ArmasDoMod.usar`.
5. **Zushi Meteor** (oferecido, desbloqueado, mas termina sem gastar energia — causa não achada).
6. **Receitas/bancada, 64 modelos Java em uso, roupas como armadura, 3 dimensões** (decisões de design do dono).
7. **Personagens**: onde/quando os ~114 aparecem no mapa (ficha de balanceamento + spawn) — decisão do dono.
8. **Backstep/Forward/Espaço**: só se o dono quiser as conquistas ligadas aos movimentos nativos.

### Achados que corrigem a auditoria (`FUTURAS_TAREFAS_MINE_PIECE.md`)
- `syncPlayerVariables`/`syncData` já existiam; a lista de "métodos ausentes" só olhou `mc_*.gd`.
- 273 de 282 entidades nascem sem erro de script; "114 não nascem" estava errado.
- Os golpes de 1000/1250 são progressão por GRADE de recompensa, não bug de energia.

## Decisões tomadas sem o dono (ele estava ausente)
- Gate dos golpes 1000/1250 é a grade (conquista), não a energia: mantido como no mod (progressão).
- A janela de conquistas esconde as 14 automáticas do primeiro tick (gatilho `tick`).
- Raid por comando continua nativo (`src/historia/raid`), não redirecionado.
- Teclas: **H** = Haki do Rei e **G** = modo de batalha (M/Q/E/R/T/Y/F/J já eram do jogo); Backstep/Forward/Espaço ficam nativos.
- `SelectedArmorEquip` virou no-op explícito (o jogo não tem armadura do Minecraft) em `src/minecraft/otimizadas/`.
- NÃO foi criada tela de escolha de estilo: sem controlador de técnicas de estilo o jogador escolheria e não conseguiria usar.
- `test_ia_do_mod` ficou determinístico (deixa o Arlong ocioso antes do golpe): a intermitência era o handler do mod cancelando dano durante técnica, não regressão.

## Log
- 09/11 ~23:50 checkpoint criado; seguiu na madrugada de 10/11, na ordem: item 6, 8, 10 (janela + comandos), 2/3 (H, G), 4 (dano do jogador), 9 (dados + loot), 7 (medição), 5 (API de armas), 1 (API de estilos). Cada item: teste novo + regressão ampla.
