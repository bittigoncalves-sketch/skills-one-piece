# Checkpoint — itens das frutas do Mine Piece e falhas de poder (10/11/2026)

Pedido do dono: (1) testar fruta por fruta quais usam ou dropam itens e replicar esses itens fielmente; (2) replicar fielmente os poderes — algumas frutas falham.
Método: `tools/mine_piece/itens_das_frutas.py` (fecho transitivo das procedures de cada fruta no Java) + REA aberto sobre o jar (SHA-256 `349b36cd…bd765`
= o das fontes decompiladas) e extraído (`data/` do jar: loot tables e receitas) + `tools/dev_tests/varredura_frutas_do_mod.gd` (104 golpes).

## 1. Itens que as frutas usam/entregam (medido no Java; ruído de armas gerais removido)
| Fruta | Item | O que o mod faz | Fonte |
|---|---|---|---|
| Bisu Bisu | `biscuit` | técnica Z-Biscoito **entrega 1 biscoito** ao jogador (`giveItemToPlayer`) | `SkillBiscuitProcedure` |
| Bisu Bisu | `biscuit_armor_{helmet,body,legs,boots}`, `shield_biscuit`, `pretzel` | **receitas** do jar: 8 biscoitos (elmo `aaa/a a`…), escudo `aa/aa/aa`, pretzel `a/a/graveto` | `recipes/recipe_biscuit_*.json`, `recipe_pretzel.json` |
| Uta Uta | `forbidden_score` | segurar a partitura (+ o item no inventário) invoca Tot Musica; a procedure **consome** a partitura | `SummonTotMusica`, `KeyChangeTechniqueDevilFruit` |
| Uta Uta | `clothes_uta_1_{helmet,chestplate,boots}`, `clothes_uta_2_*`, `lance_uta`, `shield_uta` | ao invocar/escudo de notas **veste** o set e põe lança (mão) e escudo (off-hand) | `SummonTotMusica`, `NoteShield` |
| Mori Mori | `bone_meal` (vanilla) | efeito de adubo no bloco→grama (não sai do inventário) | `BlockToGrass` |
| Neko Leopard/Sabertiger, Supa, Ushi, Uo | `iron_sword` (vanilla) | o corpo **segura uma espada de ferro** durante Shugan/Gagan/Atomic Spurt/Spar Break/Kongo Kabura/Rankyaku e restaura o item original | `Shugan`, `Gagan`, `AtomicSpurt`, `SparBreak`, `SparklingDaisy`, `KongoKabura`, `RankyakuAmaneDachi` |
| Uta Uta | `milk_bucket` (vanilla) | consulta de balde de leite no handler de tecla | `KeyChangeTechniqueOnKeyPressed` |
| todas as frutas | `item_devil_fruit_<x>` | loot `loot_devil_fruit.json` (baú/gameplay) é a fonte das frutas no mod | `loot_tables/loot_devil_fruit.json` |
Armas/estilos (ACE, YORU, KIKOKU…) aparecem em TODAS as frutas por checagens genéricas de "arma na mão": não são itens da fruta.
`Aro Aro/Tori/Bomu/Gomu…` citam HOOK/YAKUZA_KASEN só em `GuardEffectStartedapplied` (guarda com arma): não é da fruta.

## 2. Estado no jogo (o gargalo)
`ItemHandlerHelper.giveItemToPlayer` e o `IItemHandler` do jogador **não têm mochila** (`McEntidade.Manipulador`: só mãos+armadura; `insertItem` devolve a pilha). Logo o biscoito,
a partitura e o set da Uta "somem". Os modelos já existem (`mapas/modelos/mpi_biscuit|forbidden_score|lance_uta|shield_uta|shield_biscuit|pretzel.glb`);
o corpo do PLAYER ainda não desenha `mpi_*` na mão (só `PersonagemMinePiece.equipar_na_mao`). Receitas do mod estão em `mapas/east_blue/receitas_do_mod.json`, sem bancada no jogo.

## 3. Varredura dos poderes (104 golpes, 26 frutas novas; 0 erros de script)
Não começaram na varredura completa: `kage/Shadow's Asgard` e `zushi/Meteor` (energia > máxima; conhecido) e 7 outros. **Os 7 começam todos quando rodados sozinhos**
(`tools/dev_tests/sonda_golpe_da_fruta.gd -- fruta:LETRA`, um golpe por processo): Hallowed Glacier Slash, Perfume Femur Magna, Unstoppable Donuts, Hand Pistol, Six King Gun,
Giant Rock Throwing e Spar Break. Causa: a varredura herda o golpe anterior ainda em curso (ruído de método), não defeito da fruta. Ajuste pendente na varredura: esperar `skill == 0` entre golpes.
Um `signal 11` do Godot apareceu uma vez numa sessão com 6 frutas seguidas (após Perfume Femur); **não reproduz** (Mero Mero isolada, 3/3 ok). Tratar como intermitente de motor, sem causa achada.
Limite: "começou" mede energia gasta, NÃO fidelidade. Golpes com `dano=0` no alvo (Perfume Magna, Donuts, Rock Throwing, Glacier Slash) podem ser legítimos (alcance/área) ou falha de acerto: a verificar contra o Java.

## 4. Próximos passos (ordem)
1. (feito) Isolar os ❌. Agora: comparar efeito × Java nos golpes com dano=0 e nos 26 de 'só começa'; corrigir a espera entre golpes na varredura.
2. DECIDIDO pelo dono (10/11/2026): mochila FIEL ao Minecraft (slots, hotbar, crafting com as receitas do jar) e poderes primeiro. Camada de itens do jogador: mochila (`Manipulador.insertItem/extractItem` reais), `giveItemToPlayer`, `ReturnHaveItem`, item na mão do PLAYER (`mpi_*`), arte voxelizada (regra do dono).
3. Itens por fruta na ordem: Bisu Bisu (biscoito → armadura/escudo/pretzel), Uta Uta (partitura, set, lança, escudo), espada de ferro temporária (Shugan et al.), bone meal.
GATILHO: dividir este arquivo quando passar de 200 linhas.

## 5. Aliados invocados por frutas (Bisu Bisu e outras) — corrigido em 10/11/2026
Relato do dono: "a fruta do biscoito gera aliados e eles não estão interativos".
**Causa (medida):** `EntityType.create` devolvia sempre `McCorpoDoMod` (Node3D sem colisão, sem hurtbox, sem metas): o guerreiro de biscoito nascia, ficava parado (0,00 m em 2 s) e ninguém o via.
**Correção:** `src/minecraft/mc_aliado_do_mod.gd` (`McAliadoDoMod`) — as 7 criaturas invocadas por frutas (`biscuit_warrrior`, `entity_doppelman`, `entity_mini_hollow`,
`entity_negative_hollow`, `note_warrior_1/2`, `entity_muso_donatsu`) nascem como `PersonagemMinePiece` com ficha montada dos dados do mod (atributos + `.sized(l, a)` do Java × 0,88 m),
modelo `mpx_<id>` do mod, `IaDoMod` com o tick dela e `CerebroMinePiece`. Quando `SetSummonedEntity` grava o dono jogador: o corpo vira aliado (`invocados_do_jogador`, fora de `enemy` e de `AlvosDeGolpe`),
segue o dono (a "casa" dele é o dono), persegue inimigos pela hostilidade do próprio mod (`LogicAttackProcedure`), e inimigos comuns o escolhem como alvo (`CerebroMinePiece._candidatos/_hostil_a`).
**Teste:** `tools/dev_tests/test_aliados_invocados.gd` — 11 ok / 0 falhas (é PersonagemMinePiece, colisão, grupo, segue o dono, ferem o inimigo, inimigo o vê como alvo). Vizinhos: `test_controlador_fruta_do_mod`, `test_ia_do_mod`,
`test_ia_por_grupo` 19 ok, `test_dano_do_mod_no_jogador` 6 ok; `test_chefes_e_capangas` só a falha antiga ("dano recebido cai pela metade", armadura não linear).
**Não coberto / pendente:** nada visto em janela (só medição headless); `entity_negative_hollow` e `entity_muso_donatsu` somem sem a técnica do dono ativa (fiel ao `tick` do mod); Kumacy, Tot Musica, Zeus/Prometheus
e as demais criaturas ainda nascem como corpo virtual (ampliar `McAliadoDoMod.DIMENSOES` e medir com o mesmo teste); dano/IA do guerreiro não comparados golpe a golpe com o mod.

## 6. Bisu Bisu — pedidos de 10/11/2026 (tarde): dano do aliado, nome, biscoitos, HUD, inventário
- **Aliado sem dano:** o cérebro só enxergava `personagens_east_blue`; agora o aliado invocado ataca todo o grupo `enemy` (bonecos de duelo, bandidos do mapa, bestas, animais hostis, chefes) — `CerebroMinePiece._candidatos/_hostil_a`.
- **Nome:** a técnica da tecla V saía com chaves cruas ("entity.minepiece.biscuit_warrrior: minepiece.technique.shanks7"): o mod concatena `translatable().getString()` e o texto não era traduzido; `McTexto.traduzir` agora traduz as chaves dentro do texto ("Biscuit Warrior: Assault Attack"). A C continua "Biscuit Warrior" (nome do mod).
- **Biscoitos:** `ItensDoMod` + `ProgressaoDoPersonagem.itens_do_mod` (salvo). `ItemHandlerHelper.giveItemToPlayer` do mod agora entrega ao contador (a técnica Biscuit/B). Cada guerreiro de biscoito gasta 1 (`McTipoEntidade.create` devolve null sem biscoito); a técnica é recusada ANTES de gastar energia, com aviso no HUD (C = 1, V = 4 biscoitos).
- **Aliado do C não morre:** `McAliadoDoMod.Permanente` zera o `cnt_life` do `tick` do mod (3600 ticks) quando `DATA_move_mode == 0`; o da V (ataque, modo 1) segue temporário; morrem se o dono morrer/trocar de fruta (regra do mod).
- **HUD:** `ContadorDeItensHud` (ícone + ×N) logo abaixo do "M", reservando espaço no rastreador de missões. **Inventário:** aba PETS removida (a Tripulação faz o mesmo; testes de pets migrados para a `Companhia`); linhas de Akuma no Mi e frutas do pomar com ícone (`PerfilDeFrutas.imagem_na_loja`).
- **Testes:** `test_biscoitos_bisu_bisu` 15/0, `test_aliados_invocados` 11/0, `test_pets_comportamento` e `test_pet_caranguejo` ok após migrar. Falhas antigas fora do escopo: `test_vida_energia_historia` (8), `test_pomar_e_doma` ("Você chegou à Wano"). Nada visto em janela.
- **Decisão minha a confirmar:** o custo vale também para a V (4 guerreiros), senão ela contornaria a economia do C. Restringir só à C é trocar `GUERREIROS_POR_TECNICA`/`CUSTO_EM_ITEM`.

## 7. Bisu Bisu — "os poderes pararam de dar dano e os aliados começaram a morrer" (10/11/2026, noite)
**Causa (minha, do contador de biscoitos):** `dar/gastar_item_do_mod` emitiam `ProgressaoDoPersonagem.mudou`; `ModoHistoria._ao_mudar_progresso` REAPLICA a progressão (reequipa a fruta) e grava o save a cada `mudou`.
Cada B (dá biscoito), cada C/V (gasta) reequipava a fruta no meio da técnica: o controlador era refeito, os golpes seguintes não começavam e o estado da fruta no mod era refeito — a regra do mod
(`AIBiscuitWarrior`: "dono sem a fruta Bisu Bisu → o aliado se descarta") mata os aliados. Medido: na varredura em sequência, V e B passaram a ✗ depois da C.
**Correção:** sinal próprio `itens_do_mod_mudaram` (HUD e save com 3 s de atraso em `ModoHistoria._salvar_itens_adiado`), sem reaplicar a progressão.
**Também corrigido:** (a) `get_meta("dono_no", null)` no cérebro logava um erro por quadro por personagem (17 mil erros em 3 min) — agora `has_meta`; (b) uma técnica recusada por falta de biscoito deixava o SOLTAR da tecla rodar sem início e sujava o estado — o soltar da tecla recusada é ignorado.
**Teste:** `test_biscoitos_bisu_bisu` 18/0 (dar/gastar não emite `mudou`; controlador e fruta seguem os mesmos; um `mudou` qualquer mantém a fruta equipada; V recusada sem gastar energia).
**Limite:** a soak de 3 min em harness próprio não reproduziu o relato fim a fim (o harness equipava fora da progressão); a prova é a causa medida + o teste de regressão. Nada visto em janela.

## 8. Bisu Bisu e raid — 10/11/2026, 20:17
- **NPCs sem dano na raid:** o "voltar o nível de dano" das 16:27 foi lido ao contrário. Medido em raid: com ×1 o golpe de um soldado tirava ~1,4 de 24 (6 %); restaurado ×3 (criaturas do mod), ×2 (animais), bandido 0,5 → ~4,3 por golpe (18 %). Registro em `BALANCEAMENTO_E_ANIMAIS_2026-11-10.md`.
- **Aliados "disparados" que morrem no fim (Assault Attack, a técnica de 4 guerreiros):** duas causas. (1) `McAliadoDoMod` ligava ao dono via `process_frame.connect`; criações no mesmo quadro (a V cria 4) descartavam as seguintes — só o 1º virava aliado, os outros ficavam `enemy`. Agora `call_deferred`. (2) O `tick` do mod mata os guerreiros do modo ataque com `kill @s` quando o ataque acaba e por `cnt_life`; `McComandos._matar` ignora o `kill` de quem tem `aliado_permanente` enquanto o dono vive (os dois modos, C e V). Também fechei o fogo amigo: aliado do jogador não fere nem é ferido por outro aliado nem pelo dono (`PersonagemMinePiece.take_damage`).
- **Teste:** `test_biscoitos_bisu_bisu` 19/0 (inclui "V: 4 guerreiros vivos e ligados ao dono 15 s depois"). `test_aliados_invocados` 11, `test_animais_ilha_toda_e_dano` 24, `test_dano_do_mod_no_jogador` 6, `test_ia_por_grupo` 19.
- **Limite:** não reproduzi uma raid completa com aliados sendo atacados (só soldados de raid contra o jogador e aliados com/sem inimigos); morte de aliado por golpe inimigo continua possível e é combate normal. Nada visto em janela.

## 9. Raid persistente e zona de combate — 10/11/2026, 20:42
- **Avanço da raid resetava ao reabrir o jogo:** o save guardava os estágios, mas o JSON os devolve como `1.0` e em Godot `[1.0].has(1)` é falso; `proximo_estagio` achava que nada fora vencido. `Raid.vencidos()` agora devolve inteiros. Só o menu (resetar personagem) zera. Teste: `test_raid_persistencia` (5 ok: salva em disco, recarrega, segue no estágio 3; personagem novo volta ao 1).
- **Zona de combate** (`src/historia/zona_de_combate.gd`, ligada em `ModoHistoria`): em combate (dano recente, raid em andamento ou inimigo em combate perto; sai 8 s depois) o desenho das ilhas encurta de 400 para 150 m (`LodDasIlhas.perto_ate`), a câmera enxerga até 300 m e as criaturas a mais de 90 m (+15 de folga) ficam latentes (`Povoamento`: somem, sem colisão, sem IA, sem renascer/spawn) e voltam ao fim do combate, em lotes. Nunca suspende chefes, inimigos de raid, invocados/pets nem quem está em combate. Teste: `test_zona_de_combate` 14/0; `test_lod_das_ilhas`, `test_raid_mine_piece`, `test_ia_por_grupo`, `test_povoamento_e_ia_unificada` sem falha.
- **Valores são palpite meu** (90/150/300 m, 8 s): ajuste as constantes de `ZonaDeCombate`. Limites: o encurtamento da câmera pode aparecer como "pop" no horizonte; o spawn do `Povoamento` por ilha e a raid já nascem perto (8–16 m); nada medido de FPS nem visto em janela.

## 10. Limite de guerreiros e nível dos inimigos — 10/11/2026, 20:55
- **Máximo de 6 Biscuit Warriors** (`McAliadoDoMod.abrir_vaga`, chamado em `McTipoEntidade.create`): passando de 6 vivos, cada novo (C ou V) apaga o MAIS ANTIGO. Teste: `test_biscoitos_bisu_bisu` 22/0 (8 criados → 6 vivos, o 1º apagado, o 8º segue).
- **Nível dos inimigos** (`src/historia/nivel_dos_inimigos.gd`, ligado em `ModoHistoria`): criatura comum abaixo do piso (nível do jogador − 1) sobe até ele — nível na barra, vida ×(1+0,15/nível, teto 8) e dano ×(1+0,08/nível, teto 4; meta `fator_dano_nivel` lida por `JogadorDoMod`, `AnimalDaIlha` e o executor do boneco). Reaplica ao subir de nível, sem acumular; nunca baixa fortes; fora: chefes, inimigos de raid, aliados, pets, NPCs. Teste: `test_nivel_dos_inimigos` 10/0.
- **Coeficientes e piso são palpite meu** (a conta nível→vida/dano não existe no jogo); o XP do abate acompanha porque sai da vida/ataque da vítima. Nada visto em janela.

## 11. Pokébola: animação de captura e fogo amigo — 10/11/2026, 21:10
- **Animação** (`src/historia/captura/animacao_de_captura.gd`, chamada por `CapturaDeInimigos.acertou`): a criatura some para dentro da bola (escondida e congelada), a bola cai e CHACOALHA de um lado para o outro (`chacoalhadas` do sorteio Pokémon, 0–4); no sucesso solta TRÊS estrelas douradas (sem o texto "capturado"); no escape a bola abre e a criatura volta (texto "Escapou!" mantido). `Recrutamento.sortear_arremesso` só sorteia; a captura de verdade roda no clique (`capturar(alvo, false)`). Teste `test_animacao_de_captura` 16/0; `test_recrutar_mine_piece` ajustado (espera a animação) e passa.
- **Fogo amigo:** `CombatResolver.e_fogo_amigo` (usado no funil do jogo e em `McEntidade.hurt`, o das frutas do mod): ataque do jogador, de aliado invocado ou de pet não fere membro da tripulação (capturados), pet nem aliado invocado do jogador. Inimigos comuns seguem levando dano.
- **Limites:** arte da bola e das estrelas é provisória (cubos e "★" em Label3D); sons reaproveitam os do Minecraft; nada visto em janela. `test_trava_fruta_dano` falha ("fruta volta a funcionar após 1 s", espera por relógio real) — não toca o que mudei, mas não rodei A/B.

## 6. Acabamento visual das frutas Mine Piece do Modo História — 15/11/2026
Decisão do dono: acabamento ACIMA do mod (forma, tempo e dano seguem o mod). Feito em `vfx_fruta_mine_piece.gd`:
`_acabamento()` (fumaça do Moku branca em vez de cinza-parda, gelo frio, luz da Pika com bloom) e `onda_de_choque()` (anel aditivo),
ligada a: White Out (Moku), carga cheia de Ice Age/Ice Ball (Hie), Yasakani/Laser (Pika), pata (Nikyu).
Medido por captura antes/depois (`captura_fruta_mine_piece.gd`); testes: Hie 46/0, Pika 36/0, Nikyu 66/0 (as 3 falhas eram tolerância de teste: a energia regenera ~0,8 em 2 quadros com máx. 4000; tolerância 0,5→3,0).
Pendente (gatilho: próxima passada de VFX): Ope (só Stone Throwing, fiel ao mod), Ursus Shock/Kuma Punch sem anel próprio, as 40 frutas da camada traduzida.

### 6b. Funcionalidade — varredura das 40 frutas do mod, 15/11/2026
- **Partículas do mod em build exportado:** `McVisual._textura_arquivo` usava `Image.load_from_file("res://…png")` (40 avisos na varredura; em exportação o .png não existe, só o importado). Agora usa a textura importada (`load`) e deixa o arquivo cru só de reserva. Varredura: 0 avisos.
- **Varredura (`varredura_frutas_do_mod.gd`):** 13 golpes "sem começar" eram ruído (técnica e recarga do golpe anterior); agora cancela e zera a recarga antes de cada golpe. Rodados um por processo, quase todos começam. Restam por projeto: Meteor e Shadow's Asgard (custo > energia máxima de 600 da varredura), Flor de Buda (exige a forma Buda; teste dedicado 33/0) e Jigoku Tabi (nativa, exige a forma Zushi).
- **`test_flor_de_buda`:** estava quebrado por 3 causas de teste (referência estática ao controlador compilava o Player antes dos autoloads; conquistas não concedidas listavam 1 técnica; esperava 20 quadros fixos pela transformação de ~2 s). Corrigido: 33/0.
- **Não alterei regra de nenhuma técnica**: nada medido indicou defeito de mecânica nas 5 frutas nativas; Ope fere ao atravessar o alvo (23/0).
- Pendente: Ursus Shock/Kuma Punch sem anel; Kumacy, Zeus/Prometheus (Soru Soru) e Admiral/Marine invocados ainda como corpo virtual; golpes de dano 0 com alvo a 4 m (Stone Throwing da Riki, Perfume Femur Magna, Glacier Slash) a conferir contra o Java.

### 6c. Painel de técnicas (`TecnicasHud`) — 15/11/2026
- **Defeito (medido em captura):** o nome da técnica (termina em x=194) cobria o "faltam N s" (começa em x=180) e o texto "faltam 14,3 s" (~125 px) vazava dos 110 px do rótulo: "Ice Block: Pheas|faltam". Atingia toda fruta com nome longo (Hie, Moku, Pika, Nikyu).
- **Correção:** painel 300→390 px, `LARGURA_DO_ESTADO` 130, nome termina antes do estado e vira reticências ("Pheasan…"). Verificado por captura depois.
- `test_barra_de_itens` e `test_machado_habilidades` não compilam em `--script` (referência estática compila o Player antes dos autoloads; mesma causa do `test_flor_de_buda`): não validam este painel.
- **Stone Throwing da Riki dano 0:** fiel ao Java — as pedras nascem num cone de ±45° à frente do jogador (`StoneThrowingProcedure`) e voam na direção do olhar; alvo a 2–4 m é ultrapassado. Não é defeito.

### 6d. Pendências de "dano 0" fechadas — 15/11/2026
- **Unstoppable Donuts (Mochi Mochi N):** os dois `entity_muso_donatsu` NÃO atacam sozinhos (a `AIMusoDonatsuProcedure` os põe em modo 1/21–24 só quando o dono usa técnica). Medido: sem donuts, Punch Mochi (X) = 80 de dano no alvo; com donuts ativos = 184 (2,3×). Dano 0 ao invocar é o comportamento do mod.
- **Hallowed Glacier Slash:** `RangeAttack` dispara (dano 15, alcance 3 m, ao longo do corte a partir de y≈17); a mira da sonda é quase horizontal, então não alcança alvo no chão. Teste, não jogo.
- **Perfume Femur Magna:** acerta (8 a 10 m). **Stone Throwing:** ver 6c.
- Kuma Punch e Assault (Nikyu) ganharam anel na carga cheia.

### 6e. Frutas no Modo História: bugs achados pelos testes e logs — 15/11/2026
- **Tela de carregamento (bug de jogo, a cada partida):** `tela_de_carregamento._montar` adicionava o VBox (que já tinha pai) em vez do `PanelContainer`: erro "already has a parent" ×2 por partida e as listas "ETAPAS CONCLUÍDAS / ARQUIVOS LIDOS" não entravam na tela. Corrigido (`get_parent().get_parent()`); `test_carga_do_modo_historia`: 0 erros.
- **`test_frutas_acertam_npcs` (Bara C→inimigo = 0 só na corrida completa):** não era a Bara. O inimigo do mapa ficava deslocado por golpes anteriores (a Ope) e a bola passava ao lado; o teste agora o devolve ao lugar de origem a cada golpe, como já fazia com boneco e animal. Corrida completa 2× seguidas: 2 conferem / 0 divergem. (A Ope C→animal falhou uma vez: o bicho foge; instável, não recorrente.)
- **`test_frutas_na_historia` (suke_suke):** a Camuflagem Transparente é alternável — energia DRENADA enquanto invisível, recarga de 10 s só ao REVELAR (`Player._aplicar_invisibilidade`) e checada em `CastController.comecar`. O teste media antes de revelar. Agora valida o desenho real: 16 conferem / 0 divergem.

### 6f. Suke Suke Z — a camuflagem passa a ENGANAR os inimigos — 15/11/2026 (mudança de comportamento de skill)
- **Defeito de função:** a Camuflagem Transparente só deixava o modelo translúcido; nenhuma IA lia `_invisivel`, então todo inimigo continuava perseguindo o jogador "invisível".
- **Agora:** `Player.esta_camuflado()`; `CerebroDeInimigo._alvo_valido` e `CerebroMinePiece` (`_oculto`, `PERCEPCAO_DO_CAMUFLADO = 4 m`) ignoram o jogador camuflado a mais de 4 m e desistem de quem já o perseguia; a ≤ 4 m ainda o sentem. Valor de 4 m é decisão minha (ajustável).
- **Teste:** `tools/dev_tests/test_camuflagem_inimigos.gd` 6/0 (visível 10 m: vê; camuflado 10 m: perde; camuflado 2,5 m: sente; revelado: vê). `test_ia_por_grupo` 19/0, `test_aliados_invocados` 11/0.
- `test_inimigo_lutador` falha 5–7 asserts COM e SEM esta mudança (medido 3× cada): instabilidade anterior, não regressão.
- Limite: bosses da arena (`BossPerception`) e animais não leem a camuflagem ainda; atacar não revela o jogador (a decidir).

### 6g. Skills tornadas VISÍVEIS (pedido do dono, 15/11/2026) — substituem as anteriores
Descrição completa (≥10 linhas por skill) em `docs/frutas/SKILLS_MINE_PIECE_MODO_HISTORIA.md`.
- **Hie V (Ice Age):** `era_do_gelo_visivel.gd` — disco de geada que cresce com o raio do dano, 110 cristais, névoa, luz; integrado em `hie.gd`.
- **Moku X (White Vine):** funil procedural de 10 anéis no `tornado_moku.gd` + rastro de fumaça e anéis em `moku.gd`.
- **Nikyu Z (Pad Ho) e V (Kuma Punch):** anel + feixe (`VfxFrutaMinePiece.feixe`); anel na carga cheia do Assault.
- **Pika C/V (Yata no Kagami e Acceleration):** risco de luz no teleporte, coluna na subida e no mergulho.
- Novos helpers em `vfx_fruta_mine_piece.gd`: `onda_de_choque`, `feixe`, `rastro`.
- Testes: Hie 46/0, Pika 36/0, Nikyu 66/0, Moku 27/0, Ope 23/0. Ainda a melhorar (anotado na descrição): Ice Ball, Yasakani 29, rastro do Assault, Luta.

### 6h. "Todas as frutas do Modo História" — 15/11/2026
- **Medição de visibilidade** de 105 técnicas das 26 frutas só-do-mod (`captura_visibilidade_frutas.gd` + `medir`: % da imagem que muda contra a cena sem a técnica): 45 mudavam <8%. Camada genérica: partículas do mod 40→64 e ×1,75 de tamanho (`mc_visual.gd`), e anel de ativação da cor da fruta no soltar (`PoderDaFruta.ativacao`, tamanho pelo custo). Ganho médio medido pequeno (8,6% → ~9%): o gargalo é o efeito de cada técnica, não o tamanho da partícula.
- **Descrição de TODAS as técnicas** (107, ≥10 itens cada) gerada do código: `docs/frutas/SKILLS_FRUTAS_DO_MOD_GERADO.md` (gerador `tools/mine_piece/documentar_skills_do_mod.py`; lista de técnicas em `docs/frutas/tecnicas_do_mod.json`). 13 técnicas têm o procedure achado pelo NOME (marcado "aproximado"). O objetivo é INFERIDO do nome e dos efeitos.
- 5 nativas + Luta: `SKILLS_MINE_PIECE_MODO_HISTORIA.md` (à mão, com visual corrigido). Frutas da arena trazidas à história: uma página cada em `docs/frutas/<fruta>.md`.
- Dump/harness novos: `dump_tecnicas_do_mod.gd`, `listar_frutas_do_mod.gd`, `captura_visibilidade_frutas.gd`.

### 6i. Sinal de nascimento de entidade — reforço das piores skills do mod, 15/11/2026
- **Causa (medida):** técnicas do mod que criam entidades (clone, nota, corte, flecha, pedra) nasciam sem marca; só havia partículas "bokeh" genéricas.
- **Mudança:** `McTipoEntidade._sinalizar` + `PoderDaFruta.sinal_de_nascimento`: durante uma técnica do jogador, cada entidade criada ganha clarão + anel da COR DA FRUTA ao fim do quadro (tamanho: invocação 1,7 m > corte/flecha/energia 1,0 m > resto 0,7 m; limite de 1 sinal por 90 ms e 1,5 m).
- **Medição (6 frutas, 26 técnicas, mesma métrica):** média 8,6% → 10,7% da imagem; 19 de 26 subiram. Kage C 4,1→7,1; Leopard X 4,2→6,6; Giraffe X 4,2→6,6; Batto C 6,7→13,6; Uta X 7,0→11,1. Capturas: anel roxo na invocação do Kage, anel dourado no chute do Leopard.
- **Regressão:** `test_aliados_invocados` 11/0, `test_controlador_fruta_do_mod` 31/31. `test_biscoitos_bisu_bisu` 21/1 COM e SEM a mudança (falha "fruta do inventário tem imagem": asset local ausente, anterior).
- **Ainda baixa:** Uta Z 4,2→4,8 (nota pequena), Mero Z/X, Kage X. Gatilho: reforço individual quando entrar a próxima passada de VFX.

### 6j. Medição final de visibilidade e reforços individuais — 15/11/2026
Tabela completa e método em `docs/frutas/MEDICAO_VISIBILIDADE_FRUTAS.md`. Reforços: rastro em voo e piso do impacto (genéricos); Rubbles da Zushi (marcador roxo + rochas com brilho: 3,0% → 33,6%); Roundhouse Kick do Mero (4,3% → 15,7%); pauta da Uta (Note) e espinhos do Kage (Spiky Shadow Lizard) como assinaturas (`PoderDaFruta.assinatura`). Harness corrigido: energia 4000, `_recargas` por técnica e forma Buda para a Flor.

### 6k. Escolha de gênero ao entrar no Modo História × testes — 15/11/2026
- **Problema:** `ModoHistoria._escolher_corpo` abre `EscolhaCorpoHistoria` e ESPERA sempre que o save não tem `corpo`. Os 263 testes que chamam `start_story()` com progresso novo (e a medição de visibilidade) ficavam presos na tela (0 capturas).
- **Política de teste (`ModoHistoria`):** em execução automatizada (`GameFlow.executando_teste_automatizado()`, args com `tools/dev_tests/`) a escolha é feita sozinha: `corpo_de_teste` (padrão "masculino"), SALVA no progresso como a tela faria. `ModoHistoria.exigir_escolha_de_corpo = true` liga a interface real. Fora de teste nada muda: a tela aparece e nada vem escolhido.
- **Testes novos:** `test_escolha_de_corpo.gd` (28/0, precisa de janela por causa da prévia 3D: botões, nada por padrão, Entrar desabilitado até escolher, sinal com o tipo certo, Voltar vazio, história espera a tela, jogador nasce com o corpo escolhido, save guarda, tipo inválido recusado, contrato das mãos nos dois corpos) e `test_escolha_de_corpo_politica_de_teste.gd` (4/0, headless).
- **Regressão achada pelos testes:** com o corpo novo a Bara Bara respondia "Avatar sem mãos separáveis" e não lançava nada (`test_frutas_na_historia` 15/1). `BaraHandBinding` exige `Hand_L/R` com `Geo_Palm_*_Runtime` e `Geo_*_Runtime`; o corpo nomeava `Palma`/`Falange`. Renomeadas em `corpo_historia.gd` → 16/0 e checagem estrutural nos dois corpos.
- Amostra que segue passando com a política: hie/flor de buda/aliados/camuflagem/progressão/inimigos_historia.

### 6l. 2ª passada de visibilidade — 15/11/2026
Assinaturas por TIPO de golpe em `PoderDaFruta.assinatura` (chute circular, linha de tiro, pilar, aura ascendente) + feixe no White Fist nativo (`moku.gd`). Das 14 técnicas que estavam <8%, 10 passaram de 8%. Tabela atualizada em `docs/frutas/MEDICAO_VISIBILIDADE_FRUTAS.md` (121 técnicas: média 18,5%, mediana 13,9%; fortes 51, legíveis 64, fracas 5, quase invisíveis 1). Restam: Uta Z 5,4%, Kage X 7,2%, Pteranodon Z 7,3%, Batto B 7,5%, Leopard V 7,8% (todos perto do limite) e Mochi N (Donuts, 2,2%: ganhou assinatura mas o harness não o recapturou — a verificar).

### 6m. Mochi Mochi — rosquinhas e braços esticados; projéteis em prints — 15/11/2026
- **Verificado:** Unstoppable Donuts (N) cria 2 `entity_muso_donatsu` ATRÁS do usuário (como no anime), mas renderizavam AZUIS (textura cinza-clara sob a luz do céu) e o soco (Punch Mochi X / Elephant Gun C) aparecia só como clarões, sem braço.
- **Feito:** `McAliadoDoMod._tingir_de_mochi` (creme + brilho leve); `VfxFrutaMinePiece.braco_esticado` (cilindro + punho que estica, segura e recolhe) e `PoderDaFruta._bracos_de_mochi`: um braço da mão e de CADA rosquinha até o alvo (inimigo mais perto da mira ≤ 25 m, senão 9 m à frente). As rosquinhas são identificadas por `id_de` (o nó da 2ª nasce sem nome).
- **Teste:** `test_mochi_bracos.gd` 7/0 (2 rosquinhas, atrás, creme, 3 braços no pico, recolhem).
- **Projéteis em prints** (37 técnicas, 17 frutas, `captura_sequencia_fruta.gd`, câmera lateral): projéteis que persistem em voo ganharam NÚCLEO + HALO da cor da fruta e rastro denso (`PoderDaFruta.rastro_em_voo`): bala de coração do Mero e bala do Batto C passaram a ser orbes nítidos. Tiros instantâneos (Finger/Hand Pistol: Giraffe Z, Batto Z, Sabertiger Z, Wolf Z) mostram só o IMPACTO (o alvo já foi atingido no 2º quadro); um traçador que tentei não apareceu nos prints e foi REMOVIDO. A métrica % de imagem subestima projétil pequeno (média 8,1% → 8,0%): a prova é visual.
- Harness novo: `captura_sequencia_fruta.gd` (câmera por trás e de lado, quadro "antes", devolve a câmera do jogador à mira).

### 6n. Frutas da ARENA no Modo História — medição e projéteis — 15/11/2026
- Harness `captura_skill_fruta.gd` corrigido: (1) usa o caminho REAL da tecla (`begin_charge` → segurar → `release_charge`; antes `_fire_skill` direto pulava a carga: Goro X dava 0,7% e mede 88,5%); (2) câmera lateral mais perto e FOV 80°, para golpes que sobem (Entei). `nikyu_nikyu` NÃO é fruta da arena ("ainda não tem poderes implementados").
- Gancho central em `DamageZone.setup`: projétil de jogador com fruta, rápido (≥14 m/s) e pequeno (raio ≤1,2) ganha núcleo + halo + rastro da cor da fruta (`PoderDaFruta.rastro_em_voo`). Prints: tiro de gelo (Hie Z) e de fogo (Mera Z) deixam rastro de orbes luminosos. O Yami Z não passa por aí.
- A métrica % NÃO compara rodadas com câmeras diferentes (FOV mudou entre as rodadas 4 e 5).
- `test_frutas` (auditoria da arena) acusa "vazamento" em hie_hie (34 nós) e mera_mera (62; C sem hitbox): IDÊNTICO com e sem o gancho — anterior, não meu (efeitos longos como a Ice Age passam da janela de 8 s).

### 6o. Bateria de testes (frutas e Modo História) — 15/11/2026
`./validar.sh fruta mine_piece mochi aliado zushi buda biscoito escolha_de_corpo xp_flutuante camuflagem historia`: 39 ok, 20 falhas/tempo na 1ª passada. Corrigido (teste desatualizado, não bug de jogo):
- `test_corpo_historia`: liga `exigir_escolha_de_corpo` (exercita a tela REAL) → 144 OK/0.
- `test_modo_historia` → TUDO OK: espera o jogador nascer (120 quadros fixos não bastavam); `is HistoriaHud` (arrastava o Player antes dos autoloads) vira checagem por script; Civil nasce com `estilo_de_combate_base` (item Luta), não fruta; o renascimento no vazio leva >30 quadros; vida/energia vêm da progressão (24/600), não de literais 20/10; o controle de ataque desliga o clique de blocos (V5); a janela de status mede a barra de rolagem real.
- `test_vida_energia_historia` → TUDO OK: números da progressão; a vida fica fracionária pelo dano reduzido (não por regeneração) e o teste usa `VidaEnergiaHud.vida_exibida`.
- `validar.sh`: os testes do Skills Builder recebem `SOP_BUILDER=1` (fruta_moku 45/0, transformacao_historia 20/20 ligados).
Ainda abertos (não classificados como meus): combate/contato/defesa_historia, magu_historia (0 problemas = queda), loja_frutas_precos (miniatura da Buda; HUD a 1024 px), trava_fruta_dano, biscoitos (imagem do inventário), timeouts de frutas/rocket/giro/fio.
- `test_magu_historia` 46/6 → 48/4: o esperado usava a escala da arena (0,122); o jogo aplica 0,1 (`p.escala_de_dano_da_fruta`). Restam 4 (idênticas COM e SEM o gancho do `DamageZone`, ou seja, anteriores): perfil "possui Z/X/C/V" (a lista de slots mudou), Z/X "acerta alvo gigante" (hits=0) e C "velocidade 2× corrida" (11,40 vs 12,6: a velocidade de corrida mudou). A 3ª (gigante) pode ser defeito real de acerto em alvo de 26 m: a investigar.
- **`test_magu_historia` 52/0 (era 46/6).** Defeito de JOGO achado: o cão da Magu (C) devia ser "exatamente 2× a corrida" (regra do dono), mas com o movimento do Minecraft (31/10/2026, ×1,3 de corrida feito pelo `McMovimento`) o `Player` ainda usava 1,5 fixo e o cão saía 2,3× a corrida (11,40 contra 4,94 m/s). Agora `SPEED × mult × (3,0 com Shift | 2,6 sem)` → 9,88 m/s = 2,000× a corrida medida (a velocidade do cão cai ~13%). Demais correções eram do teste: escala de dano 0,1 (não 0,122), hurtbox do gigante na camada 4 (na 1 virava "parede"), perfil lido antes da troca de fruta assíncrona (a Magu é fruta do mod: perfil sem slots), e a velocidade agora medida por RAZÃO contra a corrida real.
- Muso Donuts: tentáculos de mochi VERIFICADOS em print (câmera larga por trás, 0,03–0,5 s). `test_combate_historia` (mobilidade no preparo ×0,84 contra ficha ×0,60), `test_contato_historia` e `test_defesa_historia` seguem falhando: dependem de números de ficha/escala e da inércia da locomoção do Minecraft — decisão de design do dono, não de teste defasado simples.
- `test_loja_frutas_precos` 195/195: a Buda tem miniatura própria (`buda_loja.png`, fora do padrão `_mine_piece.png`) e a 1024 px o canvas do projeto (stretch "expand") é 1280 de largura, então o canto da fome/sede se mede pelo viewport.
- `test_biscoitos_bisu_bisu` 22/0: o inventário vive na janela central e só redesenha as listas VISÍVEL; o teste abre pela API da HUD (`alternar_inventario`).
- **Timeouts da bateria:** `test_fio_espada_historia`/`test_giro_espada_historia`/`test_fruta_rocket_historia` esperavam 120 quadros fixos e, sem jogador, o script abortava SEM `quit` (travava até o timeout): agora esperam o jogador e os dois da espada FALHAM RÁPIDO (9 s) dizendo que `EspadaDaHistoria._visual` é nulo (a espada foi retrabalhada com o Epic Fight; testes legados). `test_frutas` ganhou 1200 s no `validar.sh` (16 frutas). `test_frutas_do_builder` 22/0 com `SOP_BUILDER=1`.
- **`test_fruta_rocket_historia` 42 → 1 falha:** o Civil nasce com a Luta na mão (soltar antes de testar "sem fruta"), a ficha custa 20 × `fator_de_custo_fora_do_mod` (120 no nível 1), e tirar a fruta devolve o estilo base. Resta a guarda: o bloqueio mede 16,5 contra 13,5 esperado (+3,0 de dano extra no bloqueio, vindo da reforma da defesa) — divergência REAL deixada à vista.
- **A/B controlado do gancho de projétil na arena** (`captura_skill_fruta.gd`, mesma câmera, gancho em `DamageZone.setup` ligado × desligado): Hie Z 1,2% → 3,0%; Mera Z 1,0% → 1,9%; Rocket Z 1,3% = 1,3%; Yami Z 0,5% = 0,5% (os dois últimos não passam por esse caminho / o Yami Z não dispara no harness). Ganho real mas pequeno em número (o projétil é um orbe pequeno no quadro largo); a prova visual está nos prints.
- `test_trava_fruta_dano` ✅✅: equipa a Suke Suke (a fruta inicial da arena já não é ela) e espera 72 quadros de FÍSICA (a trava de 1,0 s conta física; 1,08 s de relógio deixava sobrar 0,05 s).
- **Arena, câmera única** (`docs/frutas/MEDICAO_VISIBILIDADE_ARENA.md`): 59 golpes, mediana 4,6%, 26 <4%. Anel de ativação em `Player._fire_skill` (golpes de fruta da arena): A/B nos 10 mais fracos 1,5% → 1,9% (pequeno); vazamentos de `test_frutas` idênticos com/sem (anteriores).
- Rocket: a guarda deixa passar 16,5 contra 13,5 esperado em UM evento de dano (não dois); origem do +3,0 não isolada — aberta.
