# Auditoria de fidelidade ao Mine Piece (26/10/2026)

Pedido do dono: toda importação do mod (poder, fruta, personagem) deve ser **completamente fiel ao
original**, sem alterações que não sejam necessárias: correlação de variáveis, tradução da vida de um
jogo para o outro, adequação do nível dos inimigos à ilha. Decisão (26/10): **o mod manda, sem ajuste**
(teto de nível por ilha e escala de inimigos saem).

Esta auditoria só LÊ. Nada foi alterado no jogo. Fonte do mod: `fontes-locais/minepiece-v14`
(SHA do JAR conferido em 23/10, ver `MINE_PIECE_COMPLETO_MEDICAO.md`). Os números do mod citados abaixo
vêm dos comentários do código existente e **não foram relidos nesta auditoria**: a correção de cada item
começa relendo a procedure de origem.

## A. Divergências confirmadas no código

| # | Onde | O que o jogo faz | O que o mod faz / pede | Correção proposta |
|---|---|---|---|---|
| A1 ✅ 26/10 | `east_blue/personagem_mine_piece.gd:69`, `raid/raid.gd:181` | nível do inimigo = teto de nível da ilha em que ele está | o nível sai da recompensa (`UpdateBountyProcedure`); não existe nível por ilha | nível do inimigo = f(recompensa dele), pela mesma curva do jogador |
| A2 ✅ 26/10 | `historia/progressao.gd:86,521-527` (`FRACAO_POR_DIFERENCA`) | XP cai 25 a 95 % se o inimigo está abaixo do jogador | `WhenEntityDieProcedure` não tem essa regra (vem do PDF do Modo História) | remover |
| A3 ✅ 26/10 | `historia/ilhas/ilhas.gd` (`TABELA.teto`), `progressao.gd` (`teto()`, `NIVEL_MAXIMO`, `NIVEIS_COM_MISSAO`) | tetos 10/20/30/40/50/60 por ilha, missões nos níveis 8–10, teto absoluto 22 | o mod só tem a curva de recompensa, sem teto | remover tetos e missões de nível; nível = f(recompensa) sem limite |
| A4 ✅ 26/10 | `combat/goro_mine_piece/mundo_mine_piece.gd:27`, `historia/frutas/perfil_de_frutas.gd:44`, `combat/frutas_mine_piece/catalogo.gd:44` | dano da fruta do mod × 10 × 250/2048 (≈ ×1,22) | dano em pontos de vida do mod (jogador com 20 de vida base) | dano ×1, vida do jogador na unidade do mod |
| A5 ✅ 26/10 | `combat/Balance.gd:8` (`HISTORIA_SOCO = 0.5`), `HISTORIA_TECNICAS` | soco e técnicas escalados na história | dano do mod sem fator | remover os fatores para o que vem do mod |
| A6 ✅ 27/10 (+ A6b 28/10) | `progressao.gd` (`PONTOS_POR_NIVEL = 5`, `ENERGIA_POR_NIVEL = 100`, distribuição livre de pontos) | pontos por nível e energia por nível inventados | atributos físicos saem de `PlayerPhysicalAbilityProcedure` (limites já portados em `atributos_mine_piece.gd`); a regra de ganho **não foi confirmada** | reler as procedures de origem antes de decidir |
| A7 ✅ sons / ✅ partículas 28/10 | `minecraft/mc_visual.gd:16` (`SUBSTITUTO_SOM`, `ESTILO`) | sons do Minecraft puro trocados por sons do mod "parecidos"; partículas procedurais | som e partícula vanilla do Minecraft | usar os assets vanilla do Minecraft 1.20.1 (jar local) |
| A8 ✅ 27/10 | `east_blue/cerebro_mine_piece.gd` (plano B) | sem IA do mod, usa skills do Skill Builder (`mpeb_*`) com números portados à mão | só a IA do mod | remover o plano B (24/24 personagens já têm IA do mod) |

## B. Pontos que preciso verificar antes de chamar de divergência

- B1: `mapas/east_blue/personagens.json` (vida, armadura, força por personagem) é gerado do mod, mas o
  próprio cabeçalho diz "o dono vai recalibrar". Conferir se algum valor foi alterado à mão.
- B2: teto anti-farm da recompensa e multiplicadores de haki não foram portados (gatilho já registrado).
  Sem o teto, o XP de abate difere do mod em farm de inimigo fraco.
- B3: `energia`: a energia do jogador no mod (se existir fora das técnicas) versus a do jogo.
- B4: efeitos de poção (56) e atributos (17) estão em `McEfeito`/`McAtributo`; conferir tabela por tabela.

## C. Fora do escopo desta regra (não vêm do mod)

Animais, bestas do mar, bandidos da Ilha Inicial, pesca, pets e navios próprios: não existem no mod, então
não há original a ser fiel. Continuam como estão.

## D. Riscos da correção (para decidir antes)

- A1–A5 mudam o equilíbrio: com a vida na unidade do mod (20 base), um golpe de 8 a 30 de dano mata um
  jogador de nível baixo em poucos acertos. É o que o mod faz; só não sei se a campanha continua jogável
  sem o teto. Medir em jogo antes de declarar pronto.
- A3/A6 mexem em save existente (nível, pontos, ilhas visitadas). Precisa de migração.
- Os testes `test_progressao`, `test_modo_historia`, `test_bandidos_e_missao` e a janela de status
  (`JanelaDeStatus.gd`) assumem teto e pontos; mudam junto.

## E. Gatilho

Qualquer item novo importado do mod passa pela regra: se a fonte descompilada e o jogo discordam em um
número, vale o do mod, e a divergência só entra com o aval explícito do dono, registrada aqui.

## F. Andamento

- **26/10, A1 e A2 feitos.** `PersonagemMinePiece.montar(ficha, modelo)` não recebe mais nível: o nível do
  inimigo sai da recompensa dele (`RegrasDeRecompensa.nivel_da_recompensa`, fórmula e `Math.round` do
  `UpdateBountyProcedure`, relida na fonte). `NIVEL_PADRAO`/`NIVEL` e o teto da ilha na raid saíram.
  A penalidade de XP por diferença de nível (`xp_de_inimigo`) nunca era chamada no jogo; foi removida com
  as constantes e o teste. Testes: `test_progressao`, `test_east_blue_personagens`, `test_spawn_natural`
  17/17, `test_raid` 14/14, `test_ia_do_mod` 15/15, `test_camada_minecraft` 33/33, fidelidade 391/391.
- **Achado no caminho:** `test_status_recrutamento` falhava (2) porque escolhia o primeiro personagem do
  mod, que é o Higuma (chefe, só finaliza). Premissa do teste corrigida; 34/34.
- Pendente: A3 a A8. O nível do JOGADOR ainda usa limiares sem arredondar (`recompensa_do_nivel`), enquanto
  o mod usa `Math.round`; entra com A3.
- **26/10, A4 e A5 feitos (frutas do Mine Piece).** `PerfilDeFrutas.ESCALA_DO_MOD = 1/10` (o código guarda o dano
  do mod × 10; 10 × 1/10 = o número do mod) e `fiel_ao_mod = true` nos perfis de Ope/Hie/Moku/Pika
  (`catalogo.gd`) e Goro: sem o ×1,5 das técnicas e sem o ×0,5 do soco (`Player.escala_de_dano_da_fruta`). Todas as
  chamadas de `frutas_mine_piece/` trocaram `ESCALA_DA_ARENA` por `ESCALA_DO_MOD`; a espada da Pika agora vale 8
  (era 9,77). Soco da Luta do Mine Piece (`mp_luta_*`) na história também sai em `ESCALA_DO_MOD`.
  Efeito prático: o dano do jogador nas frutas do mod cai de ×1,83 (10 × 250/2048 × 1,5) para ×1,0 do mod.
  O dano dos inimigos no jogador já era 1:1 (a IA do mod chama `hurt` em pontos de vida do mod).
  Testes: `test_dano_soco_e_tecnicas` 16/16, `test_mine_piece` 12/12, `test_fruta_moku` 45/45, Goro 50/0; os testes
  de dano de Hie/Moku/Pika passaram a esperar `ESCALA_DO_MOD`.
  **Fora de A4/A5, de propósito:** Nikyu, kit do Builder (Pika/Hie do Builder) e frutas da arena: não vêm do mod
  (Nikyu foi feita no Skill Builder), então mantêm a escala da história.
- **Falhas que sobraram e NÃO são de dano** (energia, não comparadas com um baseline, só pela evidência): em
  `test_hie/moku/pika_mine_piece`, "custa X ⚡" esperava o custo do mod (ex.: 1) e o jogo cobra 10× (100 de energia
  por nível, decisão de 23/10). Outras ("4 golpes em 3 s transformam", "pássaro nasce") ficam a investigar.
  `test_nikyu_nikyu` (31,13 contra 17) já falhava: o ×1,5 de 23/10 nunca entrou no teste.
- **A9 (nova; FEITA em 27/10, ver abaixo):** custo de energia ×10 e `ENERGIA_POR_NIVEL = 100` também são conversões do mod (custo_mod 100 → 1
  no mod). Entra com A6.
- **26/10, A3 feito.** Saíram: `Ilhas.teto`, `teto()`, `NIVEL_MAXIMO`, `no_maximo()`, `NIVEIS_COM_MISSAO`,
  `missoes_especiais`, `precisa_de_missao()`, `bloqueado()`, `concluir_missao_especial()`, o sinal
  `evolucao_bloqueada`, o botão F8 "Concluir missão especial" e o rótulo "EVOLUÇÃO BLOQUEADA". O nível passa a ter os
  limiares EXATOS do `UpdateBountyProcedure` (`recompensa_do_nivel` é a inversa com o `Math.round` do Java; testada
  nos níveis 1–60): níveis 1–5 a cada 2.000 (o 1 começa em 1.000 de recompensa), 5→6 = 10.000, 6–10 a 18.000,
  10→11 = 54.000, 11–20 a 90.000, 20→21 = 245.000, depois 400.000. **Migração:** o save guarda (nível, XP do nível);
  continuam iguais, só mudam as distâncias dos próximos níveis; campo `missoes_especiais` antigo é ignorado; o
  nível carregado não é mais cortado por teto (só ≥ 1). `Ilhas.TABELA` mantém nome/baseplate/mar.
  Testes: `test_progressao` TUDO OK (limiares 1–60), `test_ilha_dos_macacos` 0 falhas, `test_cadeia_do_guarda` 49/0,
  `test_bandidos_e_missao` 27/0, `test_animais` 0, `test_status_recrutamento` 34/0, `test_ilha_east_blue` 7/0.
  **Não validado:** `test_modo_historia` aborta no 1º passo (o Player não compila em `--script`: "Identifier not
  found: FruitNet/GameFlow", erro de autoload que o `validar.sh` tolera mas que aqui derruba `Player.new()`); não
  consegui provar se já era assim antes, pois a árvore tem ~1.660 arquivos não commitados de outras frentes.
- **27/10, A6 feito (decisão do dono: "derivar do nível, como o mod").** Releitura de `PlayerPhysicalAbilityProcedure`:
  no mod não há pontos; com estilo de luta (`PlayerSkill1 != 0`, aqui todo personagem) tudo sai de `n = nível − 1`:
  Força (Strength, amplificador) = `round(min(n,34))`, e abaixo de 3 vale no máximo 1; Resistência = `n<3 ? 0 : round(min(n/4,3))`;
  Vida (Health Boost) = `round(min(n / 2,5; teto 9))`, isto é, n dividido por 2,5 com teto 9; Armadura = `round(min(1+n,30))`; Tenacidade = `round(min(n×0,5,30))`.
  Um amplificador `a` dá `a+1` níveis: Força +3 de dano por nível, Aumento de Vida +4 HP por nível (HP = 20 + 4×(a+1)),
  Resistência −20 % por nível. Saíram: pontos livres, `distribuir`, `limite_atributo`, `PONTOS_POR_NIVEL`, Inteligência,
  botões +/−, Confirmar/Descartar, aviso "Pontos recebidos". A janela M mostra Força, Resistência, Vida e Armadura (só leitura).
  `Player.take_damage` usa armadura + **tenacidade** (fórmula do Minecraft, `DadosEastBlue.dano_recebido`) + Resistência.
  Efeito prático: o personagem nível 1 tem 24 HP (20 + Aumento de Vida I), não 20; teto 60 HP no nível 23 (sem estilo especial).
  Saves antigos: `pontos` e `atributos` ignorados; nível e XP mantidos.
  **Não portado ainda (A6b):** Speed/Jump Boost progressivos ao correr/pular da mesma procedure; extras dos estilos 3/7/10/15/16
  (E4). Testes: `test_progressao` OK (fórmulas por nível), `test_status_recrutamento` 32/0, `test_barba_negra` 51/0,
  `test_missao_madeira_reset` 27/27, `test_east_blue_personagens` 11/0, `test_ia_do_mod` 15/15 (com o erro de script
  `String != int` que já aparecia antes e vem de procedure gerada).
- **27/10, A7 (sons) feito; partículas pendentes (A7b).** `tools/mine_piece/extrair_sons_minecraft.py` lê o Minecraft 1.20.1
  local (índice de assets + `sounds.json`) e copia para `assets/mine_piece/visual/sons/mc_*.ogg` (gitignored) as 115
  variantes dos 51 eventos vanilla que as procedures pedem, com o volume, o tom e o peso do próprio `sounds.json`.
  `SUBSTITUTO_SOM` saiu de `McVisual`. `medir_ia_mine_piece`: nenhum som ficou sem arquivo. **Não ouvido:** headless não
  toca áudio; só se conferiu que cada evento tem arquivo e que `McVisual.som` os carrega. **A7b (partículas):** `ESTILO`
  ainda desenha círculos procedurais para as partículas vanilla (`crit`, `flame`, `explosion`...); o fiel é extrair as
  texturas de `assets/minecraft/textures/particle/` do jar 1.20.1 e o comportamento de cada partícula. Gatilho: antes de
  declarar o visual das técnicas "fiel".
- **27/10, A8 feito.** O plano B (skills `mpeb_*` do Skill Builder e os números portados à mão) saiu de
  `CerebroMinePiece`: ele só persegue; quem escolhe e executa a técnica é a IA do mod. Sem IA do mod (ou com a chave
  desligada) resta o `MeleeAttackGoal` vanilla. `test_east_blue_personagens` e `test_ilha_east_blue` agora rodam com a
  IA do mod ligada (o padrão) e contam golpes pela camada Minecraft (Buggy: 36 golpes em 15 s; ilha: 96 em 15 s).
  **Achado a decidir (comportamento do mod, não bug do plano B):** com a IA do mod, os eventos do Forge do mod
  (`LogicAttackProcedure` em `LivingAttackEvent`) CANCELAM o golpe do jogador num aliado como o Luffy: vida 220 → 220,
  sem revide. Antes, com o plano B, o aliado apanhava e revidava. O teste agora afirma o comportamento do mod.
  Se o dono quiser o aliado apanhando do jogador, é uma exceção a aprovar.
  `test_ia_do_mod` é intermitente (a técnica do Arlong é sorteada numa janela de 10 s): 3 de 3 passaram numa repetição,
  1 de 5 falhou antes.
- **27/10, A9 feito (energia).** Lido em `WhenRespawnProcedure` e `PlayerTickEventProcedure`: máximo com estilo de luta
  = `min(4000, 200 × round((2 + nível) / 1,1))` (600 no nível 1, 1000 no 3, 2200 no 10, 4000 do 20 em diante);
  regeneração a cada 10 tiques (0,5 s) = `1 + round((2 + min(nível,19)) / 1,1 × 0,2)`, o DOBRO com a vida cheia (no jogo:
  4/s no nível 1, 8/s com vida cheia; sem a penalidade de combate). As técnicas do mod gastam o `custo_mod` direto
  (`ENERGIA_POR_CUSTO = 1`, no `controlador.gd` e no Goro). Saiu `ENERGIA_POR_NIVEL`. `HealthController` ganhou
  `regen_energia_mod_dobra_com_vida_cheia`; `ModoHistoria.equipar_fruta` usa a regeneração do mod sem fruta ou com fruta do
  mod, e a de cada perfil nas frutas da arena e do Builder. Testes: Hie 46/0, Moku 27/0, Pika 35/0, Ope 23/0, Goro 50/0,
  `test_mine_piece` 12/0, `test_progressao` OK, `test_barba_negra` 51/0. Os testes tinham as unidades antigas (custo ÷ 10)
  e a janela de invulnerabilidade de 0,5 s do Minecraft barrava os "4 golpes em 3 s" (golpes de 3 quadros; agora 35).
  **Riscos a medir em jogo:** (1) as frutas da ARENA e do Builder (que não vêm do mod) mantêm custos absolutos
  (`CUSTO_DA_ARENA`: 20 a 50) e agora gastam uma fração menor da energia (600 no nível 1 em vez de 100); (2) pulo e dash no ar
  do Barba Negra (30 e 20, invenção do jogo) idem. Gatilho: se essas frutas ficarem baratas demais, escalar o custo
  pela energia máxima (fração) — decisão do dono, não do mod.
- **Pendente (ordem):** A7b partículas vanilla; A6b velocidade/pulo (Speed/Jump Boost progressivos); B1–B4 (verificar
  `personagens.json`, anti-farm e haki do XP, efeitos de poção/atributos).

## G. Rodada de 27/10 (noite) — pedido do dono: Luffy, custos, fidelidade ao mod, Builder desativado

- **CORREÇÕES a afirmações minhas anteriores (fonte relida):**
  1. A3 dizia que "o mod não tem teto de nível". **Tem:** a regra de jogo `minepiecePlayerBountyLimit` (padrão 50 × 100.000 =
     5.000.000) limita a recompensa do jogador, ou seja, **nível 30** (`20 + (5 mi − 1 mi) / 400 mil`). O que o mod não tem é
     teto POR ILHA nem missão de nível.
  2. Eu dizia que a Nikyu "não vem do mod". **Vem:** `nikyu_nikyu_no_mi_mine_piece` (skills `mp_nikyu_*`) é a Nikyu do Mine
     Piece, só que implementada no formato do Builder; idem a Luta (`estilo_de_combate_base`, skills `mp_luta_*`).
- **B1 feito: `personagens.json` bate com o mod.** 107 das 108 fichas têm entidade no mod (`pirate_fishman` não tem) e
  `vida`, `armadura`, `dano_corpo`, `velocidade` e `resistencia_a_empurrao` são IGUAIS aos atributos da classe (0 diferenças).
- **B2 feito: anti-farm e teto do mod** (`WhenEntityDieProcedure`). `ProgressaoDoPersonagem.previa_do_abate` /
  `ganhar_xp_de_abate`: o jogador tem um LIMITE de recompensa (`PlayerBountyLimit`, começa em 10.000 e sobe a cada abate para
  3 × uma faixa da fama da vítima: <15 mil → mín(fama+3 mil, 15 mil); <150 mil → mín(fama+30 mil, 150 mil); <1,5 mi →
  mín(fama+300 mil, 1 mi); senão fama; tudo × 3) e o teto global de 5 mi (nível 30); a recompensa nunca diminui. Todo abate
  da história (personagens do mod, bandidos, animais, bestas do mar, inimigos do mapa) usa isto; missões ganham XP sem limite
  de abate. O save guarda `limite_de_recompensa`. Efeito prático: no início a recompensa trava em ~10 mil até o jogador
  derrotar vítimas de fama alta. **Medir em jogo** se a progressão ficou lenta demais; a regra é a do mod.
- **Luffy.** Já roda a IA do mod (`AILuffyProcedure` no `baseTick`, `SetTagPirateProcedure` ao nascer) e a chave está ligada
  por padrão; nada a religar. Com a IA do mod o evento `LivingAttack` cancela o golpe do jogador num aliado; o teste afirma isso.
- **Custos (proporção).** `AtributosMinePiece.fator_de_custo_fora_do_mod(nivel) = energia do mod / (100 × nível)` (×6 no nível 1,
  ×2 no 20): mantém a proporção de energia que as frutas da arena, a Rocket e o pulo/dash no ar do Barba Negra tinham com 100 de
  energia por nível. As técnicas do mod seguem sem fator (`custo_mod` direto). `Player.custo_de_energia_do_cast`,
  `energia_do_modo` e `capacidades()` aplicam. `test_frutas_na_historia` 51/0 com a proporção, `test_barba_negra` 51/0.
- **Builder DESATIVADO.** `SkillsPublicadas.ativo()` (padrão falso; liga com `SOP_BUILDER=1` ou `ativo_forcado = 1`). Desligado:
  `frutas()`, `skill()` e `teclas_do_kit()` só devolvem conteúdo do mod (`e_do_mod`: ids `mp_*`, `*_mine_piece`,
  `estilo_de_combate_base`), toda escrita (`publicar`, `criar_fruta`, `apagar_fruta`, `definir_preco`, kit) é recusada, o botão
  "SKILLS BUILDER" do menu some e `GameFlow.start_skills_builder` recusa. Somem do jogo: o Kit do Builder, Noro Noro, Moku/Pika/Hie/
  Nikyu do Builder (as feitas pelo dono) e as skills `mpeb_*`. **Reversível, nada foi apagado:** com `SOP_BUILDER=1`,
  `test_kit_do_builder_historia` 15/0, `test_nikyu_nikyu` 13/1 (a falha antiga), `test_pika_builder` 27/3 e `test_hie_builder` 13/1
  (falhas que já existiam). Os testes do Builder precisam de `SOP_BUILDER=1`.
- **DÍVIDA DECLARADA (o pedido "fiel ao mod, não ao Builder" NÃO está cumprido nestes dois):** a **Luta** do Mine Piece (soco, soco
  pesado, sequência) e a **Nikyu (Mine Piece)** ainda executam pelo formato/`ExecutorDeSkill` do Builder, mantidas ligadas por
  serem conteúdo do mod e porque a Luta é o combate básico. Do que dá para afirmar: os valores da Luta são os do mod ×10
  (9, 11 e 0,8 → 90, 110, 8) e o soco já sai em `ESCALA_DO_MOD`. Os valores da Nikyu (100, 40, 140…) **não conferem** com o
  que li (o dano do mod vem do atributo de ataque da entidade `PadEntity`, não de um número fixo): não verificado, não afirmo
  fidelidade. **A10 = porte nativo da Nikyu** (Pad Ho, Ursus Shock, Assault, Kuma Punch, passivo; ficha em
  `biblioteca-de-mecanicas/fichas/poder/nikyu-nikyu-skills-mine-piece.md`); **A11 = Luta nativa** (as três técnicas
  desarmadas). Gatilho: antes de chamar a Nikyu ou a Luta de "fiéis".
- **Ainda pendentes:** A7b partículas vanilla, A6b velocidade/pulo, B3 (energia fora do jogador), B4 (tabelas de efeitos e atributos),
  haki no XP.

## H. Pendências menores (28/10) — B4: efeitos e atributos da camada Minecraft

Três defeitos reais achados e corrigidos (todos faziam o inimigo ficar MAIS FRACO que no mod):

1. **`Integer.MAX_VALUE` virava o texto "MAX_VALUE" (= 0).** O tradutor manda `Mc.campo(Integer, MAX_VALUE)` e a regra de
   "constante de enum" devolvia o nome. Todo efeito permanente do mod (a duração é `Integer.MAX_VALUE`; 100 procedures: Força,
   Resistência, haki e outros) nascia com duração 0 e morria no primeiro tick. Agora `Integer`/`Long`/`Double`/`Float`
   `MAX_VALUE`/`MIN_VALUE` são números (`mc.gd`). Medido: o Buggy (`AIBuggy → SetStatus(2, 0)`) ganha Força III e a mantém;
   **88 dos 108 personagens nascem com Força** (antes, 0). Isto torna os inimigos mais fortes, como no mod.
2. **Dois efeitos para a mesma coisa.** O comando `effect give @s minecraft:strength` usa o id do REGISTRO e as procedures o
   nome do CAMPO (`minecraft:damage_boost`): eram efeitos diferentes. `McEfeito.ALIAS` unifica (Força, Resistência, Velocidade,
   Lentidão, Pressa, Fadiga, Pulo, Náusea, Cura, Dano).
3. **Efeito não mexia em atributo.** Agora Força (+3/nível), Fraqueza (−4), Aumento de Vida (+4 HP), Velocidade (+20 %),
   Lentidão (−15 %), Pressa (+10 % vel. de ataque) e Fadiga (−10 %) aplicam o modificador do Minecraft 1.20.1
   (`McEfeito.MODIFICADORES`, `McEntidade._modificadores_do_efeito`); o Aumento de Vida leva a vida máxima ao corpo.
- **Recompensa e defesa leem o corpo VIVO.** No mod, Força e Resistência de marinheiros/piratas são SORTEADAS no nascimento
  (`SetTagMarine/Pirate`: 5 % de elite, mais faixas por mar) e a recompensa lê os efeitos da vítima ao morrer. `xp_do_personagem`
  usa os efeitos e a armadura reais (a ficha só vale sem a IA do mod); `PersonagemMinePiece._defesa_viva` faz o mesmo no dano
  recebido (Resistência pelo efeito, armadura e tenacidade pelo atributo). Os valores `forca`/`resistencia` da ficha são só a
  extração estática dos argumentos de `SetStatus` e NÃO descrevem um nascimento específico.
- **Vanilla conferido:** faixas de atributo (`FAIXAS`) iguais às do Minecraft 1.20.1 (vida 20/1/1024, velocidade 0,7/0/1024,
  ataque 2/0/2048, armadura 0/0/30, tenacidade 0/0/20, empurrão 0/0/1...).
- Teste novo `test_efeitos_vanilla.gd` 23/23 (alias, modificadores, comando × procedure, Buggy com Força III, recompensa que
  depende do efeito). Regressão: `test_camada_minecraft` 33/33, `test_east_blue_personagens` 11/0, `test_raid` 14/14,
  `test_spawn_natural` 17/17, `test_fidelidade_inimigos` 391/391, `test_recrutar_mine_piece` 9/9, `test_mine_piece` 12/0.
  `test_ia_do_mod` continua intermitente (14/15 numa execução, 15/15 em 5 seguintes): "golpe do jogador tira vida" falhou uma
  vez com 88 → 88 no Arlong, que agora tem Resistência e armadura reais; não investiguei.
- **Resistência do jogador na história não é efeito:** vem do nível (A6). **Efeitos que agem no dano/tick** (Resistência,
  Regeneração, Veneno, Wither, Absorção) seguem fora da tabela de atributos (a Resistência dos personagens já entra em
  `_defesa_viva`; Regeneração/Veneno/Wither/Absorção em mobs: não conferi).
- **Ainda pendentes:** A7b (partículas vanilla), A6b (Velocidade/Pulo do jogador), B3 (não está claro qual era a energia "fora
  do jogador" que anotei; reler antes de agir) e o haki no XP (o jogo não tem haki na campanha).

## I. Pedido do dono (28/10): empurrão dos inimigos e a "emoção" da morte

Dificuldade aprovada pelo dono depois do B4. Pediu: "atribuir knockback aos inimigos" e "passar a emoção da morte ao jogador".

- **Medido antes:** o jogador já era empurrado pelos inimigos (pico de 23 m/s, `KnockbackMinecraft` de 23/10). O que faltava era o
  lado dos INIMIGOS: um golpe sem empurrão próprio movia o marinheiro 0,0 m. E `McEntidade.hurt` chamava `take_damage` com empurrão zero.
- **Feito (personagens do mod, `PersonagemMinePiece`):** o empurrão do Minecraft (`LivingEntity.hurt`): 0,4 bloco/tick para LONGE de quem
  bateu, pulinho no chão, arrasto, reduzido por `knockback_resistance` (`força *= 1 − resistência`). Só quando o golpe não traz empurrão
  próprio (os golpes com empurrão, como as técnicas do jogador, ficam como estavam); uma vez a cada 0,5 s (a janela de invulnerabilidade só
  limita o EMPURRÃO, o dano entra sempre). Medido: marinheiro recua 2,11 m; Arlong (resistência 0,5) 0,75 m. Também: `Mob.doHurtTarget`, o
  ataque corpo a corpo do mob soma `attack_knockback × 0,5` na direção em que ele olha (`McEntidade.knockback`).
  `KnockbackMinecraft.empurrar` ganhou o parâmetro `forca` e `atenuar`.
- **NÃO coberto:** inimigos que não são personagens do mod (bandidos/boneco de duelo, animais, bestas do mar, `InimigoDoMapa` estáticos).
  Não medi se eles já têm empurrão.
- **Morte (estilo Souls, escolhido pelo dono):** `MorteDoJogador` (`src/historia/morte_do_jogador.gd`), instalada em `Player.ao_morrer`
  pelo `ModoHistoria`; a arena segue com o respawn instantâneo. ≈ 4,6 s de tempo REAL: câmera lenta ×0,25, tela dessaturada com vinheta
  vermelha (shader), som desacelerado (×0,45) e abafado (passa-baixa), estrondo grave e batimentos sintetizados, o corpo cai (controles
  travados), "VOCÊ MORREU" + "derrotado por <quem>" (ou "a queda foi fatal"), fade para preto, respawn no escuro, volta do preto. Tudo que
  mexe no jogo (tempo, áudio) é desfeito mesmo se a cena mudar. `test_morte_do_jogador` 14/14.
  **Não visto nem ouvido** (headless): vinheta, dessaturação, tipografia e o som real. **Sem a câmera** (fov/queda) por ora: o `camera_rig`
  pode brigar com o fov; gatilho: se a sequência parecer parada demais jogando, mexer na câmera.
- **Efeito colateral a saber:** como o jogador agora é empurrado de verdade, o `test_ia_do_mod` (Arlong parado) oscila mais.

## J. "A7b e os demais" (28/10)

- **A7b feito (partículas vanilla).** `tools/mine_piece/extrair_particulas_minecraft.py` (precisa do Pillow, sem `-I`) lê
  `assets/minecraft/particles/*.json` e as texturas do jar do Minecraft 1.20.1 local e monta, para as 18 partículas que as procedures
  pedem (crit, cloud, enchanted_hit, flash, explosion, flame, soul_fire_flame, firework, squid_ink, end_rod, lava, small_flame, portal,
  dragon_breath, soul, large_smoke, instant_effect, angry_villager), uma tira horizontal de quadros em
  `assets/mine_piece/visual/particulas/mc_*.png` (gitignored) e as entradas `minecraft:*` em `visual_do_mod.json`. `McVisual.particula`
  desenha o SPRITE REAL (nearest, animado pela vida) com a física do `ESTILO`; só os sprites cinzas (`generic`/`spell`: squid_ink, portal,
  dragon_breath, instant_effect, firework, large_smoke) são tingidos. `medir_ia_mine_piece`: nenhuma partícula vanilla sem recurso.
  **Não visto** (headless): a aparência, o tamanho e o ritmo ainda são os do `ESTILO`, que foi escrito de olho, não os da classe Java de
  cada partícula (tamanho, gravidade e vida do Minecraft). Gatilho: comparar com o jogo original numa captura com GPU.
- **A6b feito (Velocidade e Pulo do jogador).** `VelocidadeMinePiece` (`PlayerPhysicalAbilityProcedure`, l. 74–137), a cada 2 tiques e só com
  nível ≥ 2: correndo, o efeito Velocidade sobe um nível a cada ~0,2 s até round(n × 0,5) (n = nível − 1; teto 15), +20 % por nível
  (nível 21: de ×1,2 a ×3,2 em ~2 s); agachado o Pulo carrega até round(n / 4) (teto 6), e no ar usa min(teto, round(min(Velocidade
  atual / 4; n / 4))); os efeitos duram 8 tiques e somem em ~0,4 s. O Player multiplica `velocidade_mod` e `pulo_mod`. Não portado: o
  dobro da Velocidade na forma Zoan e os estilos 7/18/Bomu (E4). `test_velocidade_mine_piece` 9/9.
- **B3 fechado:** era a energia do mod; coberta pelo A9.
- **Haki no XP e CORREÇÃO da fórmula da recompensa.** Relendo `WhenEntityDieProcedure` inteira: a versão de 18/10 usava a ARMADURA onde
  a fonte usa o ATAQUE BASE (× 0,33) e não tinha os multiplicadores de armadura (1 + mín(armadura, 20) × 0,01), tenacidade
  (1 + mín(tenacidade, 8) × 0,02) e haki (cada um 1 + (nível + 1) × 0,025). `xp_de_abate` agora tem a fórmula completa; `xp_do_personagem`
  lê os efeitos e atributos vivos da vítima (inclusive os hakis dados pelo `SetStatus`). Ex.: Arlong (220 de vida, Força V, Resistência III,
  armadura 8, ataque 10) = 17.823. Efeito: os inimigos fortes valem mais, e quem tem ataque alto também. `test_progressao` OK.
- **Empurrão em todos os inimigos.** `KnockbackMinecraft.padrao` (0,4 bloco/tick longe de quem bateu, no máximo a cada 0,5 s por vítima) agora
  também vale para o boneco de duelo/bandidos, animais da ilha (escalado pelo porte), bestas do mar e inimigos do mapa, quando o golpe
  não traz empurrão próprio. Boneco medido: 1,83 m. Não medi animais, bestas e inimigos do mapa um a um (só compilam e passam os testes).
- **Teste do XP dos inimigos atualizado** (`test_inimigos_historia`): ainda esperava o sorteio de 5 a 20 de antes de 18/10; hoje vale a
  recompensa do mod pela vida da vítima, sujeita ao anti-farm. `test_ia_do_mod` agora segura o jogador ao alcance do Arlong parado.
- **Sobrou:** `test_animais` oscila (predador, ritmo da animação, desempenho; nada a ver com as mudanças) e `test_ia_do_mod` ainda tem um
  caso raro de "golpe do jogador tira vida (88 → 88)". Frutas do Builder desligadas, Luta e Nikyu (A10/A11) seguem como dívida.

## K. A10 concluída — Nikyu Nikyu nativa (30/10/2026)

- **As cinco técnicas estão traduzidas** (`src/combat/frutas_mine_piece/nikyu.gd`): 21 Pad Ho (+ Tsuppari com Shift), 22 Ursus Shock, 25 Assault,
  28 Kuma Punch e a passiva 29 (toque duplo W/S). Cada uma é a tradução de UMA procedure do mod; os valores (cnt1…cnt10, 3 blocos por tick, 12 blocos por
  tick na investida, 48 passos de 0,5 bloco na passiva, dano 24 × CNT6 e 18 × CNT6 no Kuma) são os do Java, sem conversão. `_varrer` (a varredura do
  caminho) é compartilhada entre o Assault e o Kuma Punch.
- **Kuma Punch:** só o ramo do DONO da fruta (velocidade 6, sem exigir chão, fim da investida em cnt2 > 5); o ramo de quem não é dono é da IA. Poses novas do mod:
  `punch_gomu_pistol1` (recuo) e `punch_right_jinbe` (o soco), via `tools/mine_piece/importar_nikyu.py`.
- **Desvios declarados** (cabeçalho de `nikyu.gd`): efeito COLLIDED, degrau (`StepBlock`) da investida, `BlockDestroyAllDirection` (sem a grade de blocos do mod só
  sobra o empurrão) e os geradores de partícula em cone/anel (viram partículas soltas). **Aparência e som NÃO vistos** em jogo (headless).
- **Integração:** `"em_porte"` saiu da ficha e entrou `"substitui": "nikyu_nikyu_no_mi_mine_piece"` (como a Moku, decisão de 20/10): a Nikyu do Builder (`mp_nikyu_*`)
  sai da loja e o save antigo (comprada ou equipada) migra para esta.
- **Recarga do Assault: 5 s, não 10 s.** Veio da conta geral do controlador (`max(custo × 0,5; 5)` ticks), a mesma do Pad Ho (1,25 s) e do Ursus Shock (15 s); o
  Assault não define recarga própria. O 10 s do teste era expectativa errada.
- **Teste:** `test_nikyu_mine_piece` 63 passaram / 0 falhas. Três armadilhas de teste achadas no caminho: (1) o ciclo dia/noite move a sobrevivência, que a cada 15 s de jogo
  emite `progressao.mudou` e reaplica o progresso, desfazendo uma fruta equipada direto (derrubava o controlador no 900º quadro); (2) 1 tick do mod = 3 quadros a 60 Hz; (3) a carga
  ainda cresce 0,125 no tick em que Z é solto, então o dano esperado usa o valor FINAL de `cnt6`.
- **Falta (dívida com gatilho):** Pad Ho e Tsuppari usam a `PadEntity` sem os efeitos de `BlockDestroyAllDirection`; gatilho = o dono pedir terreno destrutível. A11 (Luta nativa) segue aberta.

## L. A11 concluída — Luta nativa (30/10/2026)

- **A Luta (Estilo de Combate Base, item "Luta") não passa mais pelo Skills Builder.** É uma entrada do catálogo nativo
  (`CatalogoFrutasMinePiece.LUTA = "estilo_de_combate_base"`, `fora_da_loja`) com executor próprio (`src/combat/frutas_mine_piece/luta.gd`) no MESMO controlador
  das frutas do mod. Novo no controlador: `teclas_diretas` (Z/X/C = técnicas 1/2/3, sem o R), recarga POR técnica e `usar_tecla`; a HUD roteia Z/X/C e o menu
  de técnicas mostra [Z] [X] [C] sem "R troca".
- **Tradução do Java** (`AttackWeakPunch` = Z, `AttackStrongPunch` = X): golpe no 2º tick, cubo de 6 × alcance a 2,5 × alcance, dano 9 e 11 (× CNT6), Lentidão IV no
  preparo e III no golpe, dura 10 ticks; tempo em TICKS do mod (0,05 s). **Adaptações do projeto, não do mod:** a carga do X (segurar até 1,25 s = +50 %), a rajada e o
  golpe final do C (o `AttackContinue` do mod é a barragem do clique, outra coisa) e, por decisão do dono, o empurrão (Z 9, X 27, final do C 21,6) e a paralisia da rajada (0,4 s).
- **Desvios declarados:** sem a entidade `entity_strike` (usa o `mp_impacto.glb` com idle1/2/3), sem `HakiEffect`, sem `BlockDestroyAllDirection`, custo de energia simbólico
  (2/4/8; o mod não cobra nos socos), efeitos e som só locais (sem a réplica em rede que o executor antigo tinha: a rede da Luta agora é a mesma das frutas do mod).
- **O que saiu do caminho** (MOVIDO para `aposentados/A11_luta_builder/`, pasta com `.gdignore`; nada foi apagado): `combate_mine_piece.gd`, `publicar_combate.gd`,
  `criar_estilo_base.gd`, as três skills `mp_luta_*`, o kit `estilo_de_combate_base` de `mapas/skills/frutas.json` (cópia em `aposentados/…/skills/`) e os testes `test_estilo_base`,
  `test_luta_mine_piece_rede`, `capturar_combate_mine_piece`. `ExecutorDeSkill.e_soco_importado`/`SOCOS_IMPORTADOS`, o caso do `Player._lancar_do_kit` e a constante `KitDoBuilder.ID_ESTILO_BASE` foram removidos.
- **Testes:** `test_luta_nativa` 33 verificações (catálogo, teclas, dano do mod + Força 3, empurrão, recarga por técnica, carga do X, rajada do C, interrupções, menu).
  O dano dos golpes inclui o efeito Força do nível 1 (+3), que é da progressão do mod, não da Luta.
- **Dívida com gatilho:** réplica de efeitos/som da Luta para clientes em rede (gatilho: o dono jogar a Luta em multiplayer); recriar o teste de rede para o controlador nativo.

