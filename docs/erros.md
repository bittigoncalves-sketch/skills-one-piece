# Registro de Erros — Skills One Piece

Todo erro encontrado no projeto, com o **motivo** de ter acontecido. Mantido pela
skill `registrar-erro`. Entradas mais recentes no topo.

O objetivo aqui não é o conserto — é a **causa**. Erro sem causa documentada volta.

---

## 2026-10-23 — Medidor e teste da IA do mod usavam o jogador INVULNERÁVEL: a IA largava o alvo e quase nenhuma técnica saía

**Sintoma:** `medir_ia_mine_piece.gd` mostrava só 1 partícula e 1 som em 600 ticks para 24 personagens; com os eventos do Forge ligados, `test_ia_do_mod` deixou de ver o Arlong sacar a Kiribachi.
**Causa raiz:** os dois punham `damage_immune` no jogador (hábito dos testes do jogo). Na camada, `isInvulnerable()` lê essa meta; a `EntityActiveProcedure` (LivingTickEvent) larga o alvo quando a `LogicAttackProcedure` diz que não pode atacar — e invulnerável não pode (como um jogador no criativo no Minecraft). Sem alvo, a IA não escolhe técnica. Raciocínio furado meu: tratei "poucas técnicas" como raridade do sorteio do mod.
**Evidência:** `EntityActiveProcedure.gd:187` (`if not LogicAttackProcedure.execute(world, entity, target): target_reset = true`); com o jogador vulnerável e vida alta, `test_ia_do_mod` voltou a 9/9.
**Descartado:** defeito na `IaDoMod` (a sonda mostrou o nó rodando e o tick à mão funcionando).
**Correção:** `tools/dev_tests/test_ia_do_mod.gd` e `tools/dev_tests/medir_ia_mine_piece.gd`: jogador vulnerável com vida muito alta (reposta a cada tick no medidor).
**Como detectar de novo:** medir IA do mod sem alvo atacável dá contagem de técnicas perto de zero; conferir `isInvulnerable()` do alvo antes de concluir que a IA "não ataca".

## 2026-10-23 — Vineflower renomeia `_setval` → `_setvalx` mas a lambda seguinte ainda lê `_setval` (Java descompilado inválido)

**Sintoma:** tradução de `EatDevilFruitProcedure`/`SelectedProcedure`/`PvPFinishProcedure` não compilava: `Cannot find member "copy" in base "bool"` em `capability.PlayerDevilFruit = _setval.copy()`.
**Causa raiz:** o MCreator declara `_setval` em blocos vizinhos com tipos diferentes; o descompilador renomeia as redeclarações (`ItemStack _setvalx`, `_setvalxx`...) mas NÃO atualiza a referência dentro da lambda `ifPresent(capability -> ...)`, que continua `_setval` (o boolean do bloco anterior). O Java descompilado já está errado ali.
**Evidência:** `EatDevilFruitProcedure.java:61-63` (`ItemStack _setvalx = ItemStack.EMPTY;` seguido de `= _setval.m_41777_()`), mesmo padrão em `PvPFinishProcedure.java:187-202, 389-400`.
**Descartado:** tabela de correção por arquivo (o padrão é sistemático, não pontual).
**Correção:** `tools/mine_piece/tradutor/traduzir.py`: ao declarar `nome`+`x…` com `nome` já declarado no método, `nome` vira apelido da variante NOVA naquele bloco. 1068 → 1075/1076 compilando.
**Como detectar de novo:** `tools/dev_tests/compilar_procedures_mine_piece.gd` (lista NAO_COMPILA).

## 2026-10-23 — Medição do Mine Piece contava "0 explosões / 1 movimento": o JAR chama o Minecraft por nomes SRG

**Sintoma:** primeira passada de `medir_dependencias_minecraft.py`: explosões 0, invocar entidades 0, movimento/teleporte 1 arquivo — impossível num mod de poderes.
**Causa raiz:** o JAR de produção (e o descompilado dele) usa nomes SRG nos métodos do Minecraft (`m_20256_` = setDeltaMovement, `m_255391_` = explode); só nomes do Forge e do mod ficam legíveis. Contagem por nome oficial não via nada.
**Evidência:** `ElThorFallProcedure.java` com `.m_128459_(` 23×, `.m_20299_(` 6×. Depois de juntar mcp_config (tsrg2) + Mojang por DESCRITOR (64 225 nomes, 0 ambíguos): explosões 170 arquivos, movimento 222, invocar 192.
**Descartado:** juntar só pelo nome ofuscado — dentro de uma classe vários membros dividem `a`/`f`; deu 10 candidatos para `m_20256_`.
**Correção:** `tools/mine_piece/srg_oficial.py` (cache em `~/.cache/skills-one-piece/srg_1.20.1.json`), usado pelo medidor e pelo tradutor.
**Como detectar de novo:** número zerado para sistema que o mod obviamente usa; `python3 -I tools/mine_piece/srg_oficial.py` deve mostrar `m_20256_ → setDeltaMovement`.

## 2026-10-23 — Save sem fruta carregava com a Ope Ope (Mine Piece): `CatalogoFrutasMinePiece.atual("")`

**Sintoma:** silencioso; achado pela regressão. `test_progressao` "carregar devolve exatamente o mesmo status" falhava, e na Rocket "nasce sem perfil de fruta" também.
**Causa raiz:** `CatalogoFrutasMinePiece.atual(id)` devolve a ficha cujo `substitui` é igual a `id`, lendo com `get("substitui", "")`. Uma ficha SEM o campo vale "" e casa com o id vazio, então `de_dict` transformava "sem fruta" em `ope_ope_mine_piece` em todo carregamento.
**Evidência:** sonda salvar/carregar: única diferença `fruta: salvo="" lido="ope_ope_mine_piece"`. Depois da correção, `test_progressao` TUDO OK.
**Descartado:** as mudanças de energia/teto de nível desta sessão (a sonda isolou só a fruta).
**Correção:** `src/combat/frutas_mine_piece/catalogo.gd` `atual()`: id vazio devolve vazio antes de procurar.
**Como detectar de novo:** `tools/dev_tests/test_progressao.gd` ("carregar devolve exatamente o mesmo status").

## 2026-10-23 — Meu corte de "soco −50 %" pegou também a espada (multiplicador era do CORPO, não do estilo)

**Sintoma:** `test_espada_historia`: golpe de espada da história caiu pela metade (13 onde se esperava 26, nas quatro direções).
**Causa raiz:** pus `Balance.HISTORIA_SOCO` em `ExecutorCorpoACorpo.multiplicador_de_dano`, que vale para TODO golpe do corpo. A espada (e o machado) da história não trocam o multiplicador — trocam o ESTILO (`trocar_estilo(espada.tres)`). Raciocínio furado: li que `aplicar_espada_de_fruta` salva/restaura o multiplicador e concluí que "a espada" cuidava disso, sem ver que a espada comum não passa por ali.
**Evidência:** 25/30 com o corte no corpo; 29/30 com o corte por estilo (a falha restante, "começa com mãos livres", acontece também com tudo neutralizado).
**Descartado:** o knockback Minecraft (rodada só com ele ligado não mexe no dano da espada).
**Correção:** `src/combat/direcional/executor_corpo_a_corpo.gd`: `multiplicador_desarmado` só vale quando `estilo == _estilo_desarmado` (o estilo recebido em `montar`); `ModoHistoria.instalar_combate_direcional` usa ele em vez de `multiplicador_de_dano`.
**Como detectar de novo:** `test_espada_historia` (dano por direção) e `test_dano_soco_e_tecnicas` (desarmado × 0,5, corpo × 1).

## 2026-10-23 — O pulinho do knockback do jogador nunca existiu: a pausa de impacto zerava a velocidade logo depois

**Sintoma:** silencioso; o dono pediu "adicionar knockback ... no jogador" porque o empurrão quase não se via.
**Causa raiz:** em `Player.take_damage`, `_aplicar_knockback` soma o componente vertical em `velocity.y` e, na linha seguinte, a "Impact Frame Hold" faz `velocity = Vector3.ZERO` e liga `_hitstop_timer` (60–160 ms em que o quadro retorna antes de mover). O vertical do empurrão era apagado sempre; só o horizontal (campo próprio do `HealthController`) sobrevivia, e ainda escalado pela vida (fraco com vida cheia) e começando depois da pausa.
**Evidência:** leitura do funil (`_aplicar_knockback` → `velocity = Vector3.ZERO` no mesmo `take_damage`); com o knockback Minecraft sem a pausa: pulinho 0,94 m e 2,18 m de empurrão, já no 2º quadro (`test_knockback_minecraft` 10/10).
**Descartado:** som ausente — `AudioFX.hurt` já era chamado em `_feedback_de_dano`; o problema era o som (baque 320→90 Hz de 0,22 s) pouco reconhecível, trocado por `AudioFX.dano_do_jogador`.
**Correção:** `src/player/knockback_minecraft.gd` (empurrão fixo 8 blocos/s, pulinho de 1 bloco, arrasto 0,91/atrito 0,546 por tick, 0,5 s invulnerável com "só a diferença"); `Player.take_damage` pula a pausa de impacto quando ele existe (Modo História, `ModoHistoria.instalar_combate_direcional`). A arena mantém o comportamento antigo.
**Como detectar de novo:** `tools/dev_tests/test_knockback_minecraft.gd`.

## 2026-10-23 — Correndo contra um meio bloco o jogador PULAVA (vault) em vez de subir como andando

**Sintoma:** relato do dono — "quando o jogador colidir com um meio bloco correndo ao invés de simular um pulo que é o que está acontecendo ele deve passar para cima do meio bloco como acontece ao andar normalmente".
**Causa raiz:** o VAULT automático do parkour (`ParkourController.aplicar_pulos`, Shift + W contra obstáculo baixo) roda na locomoção, ANTES do `SubirDegrau` (que só age no `_etapa_mover`). A sonda do joelho fica 0,4 m abaixo do centro — na altura do meio bloco (0,44 m) — e a de cima (0,7 m acima do centro) passa livre, então todo meio bloco/escada virava "obstáculo de vault" e o pulo (0,7 × força do pulo) disparava antes de o degrau ter chance.
**Evidência:** `test_subir_degrau` com Shift: pico 1,61 m acima do topo do meio bloco e 1,17 m na escada (4/6). Andando, 0,00 m.
**Descartado:** o `SubirDegrau` em si (andando ele sobe certo; correndo nem chegava a ser chamado com o corpo no chão).
**Correção:** `src/player/parkour_controller.gd` `_obstaculo_baixo_a_frente`: com a cápsula da história (`colisor_capsula`), se a frente está livre logo acima da altura que o `SubirDegrau` sobe (pés + `SubirDegrau.ALTURA` + 0,02, `_livre_acima_do_degrau`), é degrau e não há vault. Bloco inteiro (0,88 m) segue com vault.
**Como detectar de novo:** `tools/dev_tests/test_subir_degrau.gd` casos "CORRENDO" (pico acima do topo < 0,15 m) — 6/6.

## 2026-10-23 — Relevo liso substituído seguia em memória (malha escondida + forma presa na meta `terreno_forma`)

**Sintoma:** silencioso. O relevo em blocos substitui as 520 peças `terreno` no Modo História, mas a memória não caía como esperado.
**Causa raiz:** `relevo_das_ilhas.gd` só ESCONDIA a malha (`visible = false`) e DESLIGAVA a colisão (`disabled = true`) das peças lisas: recurso escondido continua alocado. Além disso, `MapaMontador.forma_de_selecao` guarda a forma côncava na meta `terreno_forma` do corpo (cache da seleção do editor). Por isso, mesmo com `shape = null`, a forma continuava viva (weakref ainda válido, 1 referência restante).
**Evidência:** `medir_memoria_relevo` (com janela): as lisas seguravam 3,19 M vértices e 1,06 M triângulos de colisão. Soltar `shape` mudou a estática em só −0,7 MB; uma sonda isolada mostrou que 1 M triângulos de ConcavePolygonShape3D custam +160 MB e voltam a 0 ao soltar → algo prendia. Depois da correção: estática 1363,5 → 1180,6 MB (−183 MB), vídeo 1331,3 → 1258,2 MB (−73 MB), lisas seguram 0 vértices e 0 triângulos.
**Descartado:** `OBJECT_RESOURCE_COUNT` não serve para isso (conta só recursos em cache de disco, ficou em 14699 o tempo todo); o LOD não religa a malha (ele mexe no corpo, não no filho `Malha`).
**Correção:** `src/historia/ilhas/relevo_das_ilhas.gd` — além de esconder e desligar: `m.mesh = null`, `c.shape = null`, `remove_meta("terreno_forma")` e `remove_meta("terreno_forma_chave")`; e solta `relevo.cor`/`relevo.tipos` (só servem para montar; −9 MB).
**Como detectar de novo:** `tools/dev_tests/medir_memoria_relevo.gd` — a linha "lisas substituídas ... ainda seguram" tem de dar 0 vértices e 0 tri.

## 2026-10-23 — Personagem preso ao descer do relevo em blocos (lâmina de 3 mm no topo das paredes)

**Sintoma:** relato do dono — "ao tentar descer do relevo de um bloco o personagem está travando". Andando com W até a borda de qualquer degrau, o jogador para com a frente da cápsula na quina e não cai.
**Causa raiz:** `RelevoEmBlocos._parede` estendia cada parede `SOBRA` (3 mm) ACIMA do topo (`y1 = alto*MEIO + SOBRA`) para tapar frestas de renderização. A colisão do relevo é a MESMA malha (ConcavePolygonShape3D), então toda borda ganhava uma lâmina de 3 mm saltada acima do chão. A base arredondada da cápsula encostava na aresta da lâmina; o contato numa aresta devolve normal quase vertical (0,1,0), o `move_and_slide` o trata como chão e gasta os 6 slides sem avançar. O `SubirDegrau` não ajuda porque só age quando o `test_move` acha PAREDE (normal y < 0,7).
**Evidência:** `test_descer_degrau` (degraus de 1 meio, 1, 2 e 4 blocos, de frente e na diagonal): 1/8 antes — centro parado em z ≈ 0,92 (frente da cápsula na borda) por 85–97 quadros, velocidade (0,0,−4,2), `is_on_floor` true, 6 colisões todas com normal (0,1,0). Só tirando a SOBRA do topo da parede: 8/8.
**Descartado:** `Agachar.limitar_borda` (só age agachado); `SubirDegrau` (não dispara descendo: o passo à frente não colide); escalada/wall run (logados false nos quadros parados).
**Correção:** `src/world/relevo_em_blocos.gd` — `_parede` usa `y1 = chave.z * MEIO` (sem SOBRA; o topo já avança SOBRA além da parede e cobre a junção) e `VERSAO` 4 → 5 (o cache em `user://relevo_em_blocos/` guardava a geometria antiga: sem subir a versão o jogo continuaria travando com o teste passando).
**Como detectar de novo:** `tools/dev_tests/test_descer_degrau.gd` (8 casos sintéticos) e `tools/dev_tests/test_varredura_relevo.gd` (atravessa 48 bordas reais de 4 ilhas; acusa "parado com SÓ CHÃO").

## 2026-10-22 — Relevo em blocos: quatro defeitos achados nas capturas e no teste

(docs/RELEVO_EM_BLOCOS_PLANO.md)
- **Cor quase branca.** Causa: a paleta gravava a cor sRGB direto no vértice; o shader lê a cor do vértice como LINEAR. O `TerrenoDoMapa` já convertia (`srgb_to_linear`). Escurecer a cor só mascarava. Detectar: cor de vértice nova → conferir a conversão.
- **Faixa verde na costa.** Causa: o relevo liso fica 4 cm acima da placa (y = 0); arredondado para meios blocos virava 0, e o topo do bloco coincidia com o topo da placa (z-fighting). Correção: chão acima de 0 tem pelo menos meio bloco (`_acima_do_zero`).
- **Pontinhos escuros no chão plano.** Causa: a fusão gulosa cria junções em T (canto de um retângulo no meio da aresta do vizinho), e a rasterização deixa frestas de 1 pixel. Correção: cada face avança 3 mm (`SOBRA`) sobre as vizinhas coplanares da mesma cor.
- **Jogador não subia o degrau.** Causa: a cápsula tem raio 0,5 m; erguida e avançada só o passo do quadro, pousava na QUINA (normal ≈ 0,55) e o teste rejeitava como "não é chão". Correção: lá em cima avança passo + raio (`subir_degrau.gd`).
- Premissas de teste que o relevo em blocos mudou: "encosta > 15°" (não existe mais face inclinada) e "colisor cujo nome começa com relevo" (`test_ilha_inicial`); árvore comparada ao relevo liso (`test_ilhas_mine_piece`).

## 2026-10-22 — Captura das ilhas parada após mudar o formato dos dados do gerador

**Sintoma:** `capturar_ilhas_mine_piece.gd` rodou ~10 min até o `timeout` e não regravou nenhuma imagem.
**Causa raiz:** `gerar_ilhas_mine_piece.gd` passou a guardar em `ILHAS[id]["estruturas"]` só os modelos (o lugar agora é sorteado); a captura lia `estruturas[0]` como `[modelo, posição, giro]`, deu erro de script na primeira ilha e a cena ficou aberta sem `quit()`.
**Evidência:** as capturas "depois" eram byte a byte iguais às de 18/10 (`cmp`).
**Correção:** a captura procura na cena a peça `mpi_<ilha>_estrutura_0` (a maior construção).
**Como detectar de novo:** ao mudar o formato de uma constante pública de gerador, `grep -rn "Gerador.ILHAS\|\[\"estruturas\"\]" tools/` e conferir o horário das capturas depois de rodar.

## 2026-10-21 — Fruta Mine Piece equipada sumia ao recarregar o save

**Sintoma:** com a Goro ou a Ope (Mine Piece) equipada, recarregar o progresso deixava o personagem sem fruta.
**Causa raiz:** `serializacao_do_progresso.gd` só aceitava em `fruta` ids do `SkillSystem` ou do Builder; as traduções do Mine Piece têm controlador próprio e não estão em nenhum dos dois.
**Evidência:** `ProgressaoDoPersonagem.de_dict` com `fruta = "ope_ope_mine_piece"` devolvia `""`; com a correção, o caso entra em `test_hie_mine_piece` e passa.
**Correção:** aceitar `CatalogoFrutasMinePiece.contem(id)` e a Goro; a migração `"substitui"` da ficha troca a versão antiga do Builder pela tradução.
**Como detectar de novo:** `test_hie_mine_piece` ("save: fruta Mine Piece equipada sobrevive ao recarregar").

## 2026-10-21 — `get_meta(chave, null)` dá erro quando a chave não existe

**Sintoma:** dezenas de "The object does not have any 'meta' values with the key 'gelo_hie_mine_piece'" no teste da Hie.
**Causa raiz:** no Godot 4.6, `null` como padrão de `get_meta` conta como "sem padrão"; a ausência da chave vira erro.
**Correção:** `has_meta(chave) and get_meta(chave) == …` em `gelo_hie.gd`.
**Como detectar de novo:** procurar `get_meta(` com `null` no segundo argumento.

## 2026-10-21 — Posição lida no `_ready` antes de ser atribuída (bola de gelo da Hie)

**Sintoma:** o golpe da Hie feria, mas ninguém ficava congelado; a bola de gelo sumia no primeiro tick.
**Causa raiz:** `gelo_hie.gd` guardava o ponto de prender no `_ready`, que roda dentro do `add_child` — antes de quem cria atribuir `global_position`. O ponto ficava na origem, o alvo "escapava" (≥ 1 bloco) e o gelo sumia.
**Correção:** o ponto é guardado no primeiro tick.
**Como detectar de novo:** em entidade criada com `add_child` + `global_position = …`, não ler a posição no `_ready`.

## 2026-10-18 — Ficha de frutas citando classe que tipa `Player` quebra testes `--script`

**Sintoma:** `test_goro_mine_piece` não compilava ("Identifier not found: FruitNet") e o Modo História nem nascia o jogador ("Nonexistent function 'new'").
**Causa raiz:** `PerfilDeFrutas` passou a citar `GoroGoroMinePiece.ID`; essa classe tipa `var ator: Player`, e o `Player.gd` usa o autoload `FruitNet`, que no `godot --script` ainda não é identificador quando o teste compila. Todo script que usa a ficha de frutas puxaria o Player junto.
**Evidência:** a falha some ao trocar a citação da classe pelo id em texto (`PerfilDeFrutas.GORO_MINE_PIECE`); o teste passou 50/50.
**Descartado:** erro nos scripts novos (compilam no `checar_compilacao`).
**Correção:** `src/historia/frutas/perfil_de_frutas.gd` usa o id em texto; o teste carrega os scripts da fruta com `load()` depois do jogo de pé.
**Como detectar de novo:** rodar qualquer teste da loja (`test_loja_frutas_precos`) depois de mexer em `PerfilDeFrutas`.

## 2026-10-18 — `const B := ClasseGlobal` não é expressão constante (Godot 4.6)

**Sintoma:** os cinco scripts da Goro Goro (Mine Piece) não compilavam: "Assigned value for constant "B" isn't a constant expression".
**Causa raiz:** apelido de `class_name` recém-criado em `const`; o analisador não o trata como constante.
**Evidência:** com `const B := preload("res://…/mundo_mine_piece.gd")` os cinco compilam.
**Descartado:** cache de classes desatualizado (`--import` rodado antes).
**Correção:** `preload` no apelido (src/combat/goro_mine_piece/*.gd).
**Como detectar de novo:** `tools/dev_tests/checar_compilacao.gd`.

## 2026-10-18 — Clarão por OmniLight de alcance grande desenha retângulo serrilhado no chão

**Sintoma:** na captura do El Thor, um retângulo claro de bordas em escada em volta do jogador.
**Causa raiz:** uma `OmniLight3D` nova por tick para cada "flash" do mod; a luz pontual sem sombra e de alcance grande aparece recortada pela iluminação em clusters do Forward+.
**Evidência:** captura `el_thor_0.30` antes/depois; com sprite somado (billboard, gradiente radial) o retângulo some.
**Descartado:** marca de impacto (é um disco escuro, outro elemento).
**Correção:** `VfxGoroMinePiece.clarao` sem luz.
**Como detectar de novo:** `tools/dev_tests/captura_goro_mine_piece.gd`, olhar o chão no El Thor.

## 2026-10-18 — Fumaça do mod com o tamanho errado vira parede de quadrados na câmera

**Sintoma:** com Sango, Mamaragan ou Raigo, a tela enchia de quadrados marrons pixelados.
**Causa raiz:** a contagem de partículas do mod é fiel (`round(range)` por tick em cada onda de impacto), mas as partículas do Minecraft são pequenas e somem; aqui eram quads de 2,2 m, opacos e sem esmaecer.
**Evidência:** capturas `sango_1.40`, `raigo_*` antes/depois.
**Descartado:** meteoro (a fumaça dele nasce a 130 m).
**Correção:** partículas com rampa de esmaecimento, 0,8 m, no máximo 6 por emissão de fumaça (`VfxGoroMinePiece`).
**Como detectar de novo:** a mesma captura.

## 2026-10-18 — DamageZone passava autor já liberado ao CombatResolver (argumento tipado)

**Sintoma:** "Invalid type in function 'aplicar'... argument 11 (previously freed)" durante a raid.
**Causa raiz:** inimigos da raid são removidos ao morrer, mas a zona de dano de um golpe deles continua viva e passava o `caster` liberado; antes ninguém era removido, por isso nunca aparecia.
**Evidência:** erro no log do `test_raid_mine_piece`; some com `is_instance_valid(caster)`.
**Descartado:** —
**Correção:** `src/effects/DamageZone.gd` passa `null` quando o autor já saiu da árvore.
**Como detectar de novo:** `test_raid_mine_piece` sem SCRIPT ERROR no log.

## 2026-10-18 — "Mesmo bando não fere" furado: autor do golpe adivinhado pelo mais perto

**Sintoma:** na raid, bandidos caíam sozinhos com o jogador parado e imune; o Higuma morria antes de o teste chegar a ele.
**Causa raiz:** `PersonagemMinePiece._quem_bateu` só sabia o autor real em golpe do jogador ou corpo a corpo; golpe de TÉCNICA de NPC caía no "mais perto do ponto do golpe" — o jogador cercado — e a regra de facção não reconhecia o colega.
**Evidência:** `ultimo_agressor` dos caídos = o corpo "1" (o jogador); com a autoria real, 0 quedas sozinhas e a raid passou 14/14.
**Descartado:** afogamento/queda (posições em terra), dano do jogador (imune, sem comando).
**Correção:** `socorro.marcar` grava `autor_do_dano` (o autor que o CombatResolver já recebe) e `_quem_bateu` o usa primeiro (src/historia/tripulantes/socorro.gd, src/historia/east_blue/personagem_mine_piece.gd). Vale também no mapa (rajada do Krieg nos piratas dele).
**Como detectar de novo:** `test_raid_mine_piece` ("sem abates as ondas param em 5 vivos").

## 2026-10-18 — AnimatableBody3D levado só pelo pai não carrega o jogador (velocidade de plataforma 0)

**Sintoma:** jogador em pé no convés dos navios do Mine Piece escorregava para a popa quando o navio andava (16,7 m de desvio em 4 s).
**Causa raiz:** o convés era um AnimatableBody3D filho do barco; movido só pela transformação do pai, ele não informa velocidade à física — `get_platform_velocity()` do jogador ficou (0,0,0) com o navio a 3,7 m/s.
**Evidência:** diagnóstico no jogo: plat_v 0 em todos os quadros; depois da correção plat_v 5,6 m/s ≈ barco 5,3 m/s e desvio 0,05–0,16 m em 4 s virando.
**Descartado:** exceção de colisão/camadas mudadas pelo leme (exceções [] e máscara 1 nos dois casos); o 0,98 m da 1ª rodada foi coincidência de movimento curto.
**Correção:** convés `top_level` e o barco define a transformação global dele em `_notification(TRANSFORM_CHANGED)` e após o balanço (`src/historia/navios/barco.gd`, `_sincronizar_conves`).
**Como detectar de novo:** `test_vendedor_de_barcos` ("o navio andou ... e o jogador foi junto no convés").

## 2026-10-18 — "Jogador não fica no convés": era o critério do teste, não a colisão

**Sintoma:** em 2 navios (pirata pequeno, Saber of Xebec 2) o jogador terminava ~2 m acima do lugar de convés; antes disso o raio do centro do navio batia no topo do mastro.
**Causa raiz:** o raio do centro achava o mastro, não o convés; e nos navios com tripulação hostil o jogador é empurrado (a imunidade tira o dano, não o empurrão). Minha hipótese de porão baixo (1,76 m) estava errada: medido, o chão do lugar estava exato (3,75) e o teto livre até 19–50 m.
**Evidência:** diagnóstico com raios no jogo: baixo=3.7497 para lugar 3.75; cima=50.8.
**Descartado:** colisão errada do convés; deslocamento do pivô do navio; porão baixo.
**Correção:** o teste põe o jogador num `lugares_conves` do conversor e exige "apoiado a bordo sem atravessar o convés"; o conversor passou a exigir folga 3×3×3 (mais seguro de qualquer forma).
**Como detectar de novo:** `test_ilhas_mine_piece` (31/31).

## 2026-10-18 — Ilhas viravam caixas nas capturas (desenho por distância ainda não reavaliado)

**Sintoma:** em `capturar_ilhas_mine_piece.gd`, Wano e Shandora apareciam como caixas cinza sem textura; a primeira ilha saía certa.
**Causa raiz:** `LodDasIlhas` só reavalia a cada 0,5 s; a foto saía 8 quadros depois de mover jogador e câmera, com a ilha ainda no estado LONGE (blocos).
**Evidência:** rodando só Wano (`--so=ilha_wano`) as casas saíram com textura; com 45 quadros de espera todas as ilhas saíram certas.
**Descartado:** modelo ausente na loja (sem aviso de "não encontrado" no log).
**Correção:** `_foto` espera 45 quadros (tools/dev_tests/capturar_ilhas_mine_piece.gd).
**Como detectar de novo:** captura com caixas cinza logo após teletransporte entre ilhas.

## 2026-10-18 — Teste com `var x: Player` não compila no `--script` (FruitNet)

**Sintoma:** `test_teste_de_ilha.gd` falhava ao carregar: "Identifier not found: FruitNet" em `Player.gd`, e o jogador não nascia.
**Causa raiz:** anotar o tipo `Player` no script de teste obriga o `Player.gd` a compilar ANTES de os autoloads (FruitNet) existirem no modo `godot --script`; o cache de classes não tinha culpa (refazê-lo não mudou nada).
**Evidência:** mesma falha antes e depois de `checar_cache.sh` + `--import`; trocando para `Node3D` + `get()/call()`, 10/10.
**Descartado:** cache de classes desatualizado.
**Correção:** `tools/dev_tests/test_teste_de_ilha.gd` e `test_ilhas_mine_piece.gd` usam `Node3D` (comentário no ponto).
**Como detectar de novo:** "Identifier not found: <Autoload>" ao carregar um teste — procurar tipo `Player` no teste.

## 2026-10-17 — Forja: tempo esgotado e posição da martelada

**Causas:** uma penalidade podia zerar `restante`, mas a desativação só ocorria no
próximo `_process`; outra entrada no mesmo quadro ainda podia avançar. A bancada
usava o próximo `alvo` para desenhar o impacto anterior, deslocando martelo/faíscas
para um ponto que ainda não havia sido golpeado. `acionar()` também reiniciava
qualquer estado inativo, incluindo uma forja já concluída.

**Correções:** esgotamento imediato após penalidade; a bancada guarda o índice
efetivamente martelado; conclusão e cancelamento não aceitam nova ação. Os atalhos
agora tratam teclado físico/lógico e numérico em `_input`, antes dos botões do GUI,
com descarte de repetição automática. `test_ferraria_controles.gd` valida esses
casos por eventos de teclado, inclusive com botão focado, e as três etapas.

## 2026-10-15 — Integração de sobrevivência: salvamento, coleta e reconstrução de UI

**Causas encontradas e corrigidas:** recompensas sem XP não emitiam `mudou` porque `ganhar_xp(0)` retorna cedo; o desligamento do sistema de sobrevivência podia regravar a campanha descartada durante reset; a coleta consultava plantas já liberadas em vez do tipo/id capturados no evento; a UI de pesca criava outro controle com o mesmo nome antes de remover o anterior. A integração agora salva recompensas mesmo sem XP, respeita `_reiniciando_campanha`, conta somente árvores pelo evento e remove o controle antes de `queue_free`.

**Evidência:** regressões `test_missao_madeira_reset`, `test_machado_madeira`, `test_pets_comportamento` e `test_sobrevivencia_integracao` passaram. Saves de teste usam caminhos próprios; não se usa a campanha pessoal como fixture.

## 2026-10-15 — Ferraria: retry, assinatura nativa e fome residual

**Causas:** reiniciar a ferraria zerava a etapa, mas preservava o índice do último alvo; uma função de desenho chamada `draw_ellipse` colidia com a API nativa do Godot 4.6; subtrações fracionárias podiam deixar um resíduo positivo de fome após quatro dias.

**Correções:** retry zera também `_alvo`; auxiliar renomeado `_elipse`; valores de fome/sede inferiores a 1e-6 são zerados. O teste de jornada cobre retry após falha e quatro dias em 4.000 passos. Capturas da bancada e da janela real estão em `art_src/validation/sobrevivencia/`.

## 2026-10-15 — Teste de loja congelado em 13 frutas

**Causa:** `test_npcs_e_lojas` exigia `frutas.size() == 13`, embora o catálogo já oferecesse 15 antes desta frente. Não era regressão de sobrevivência. Após revisão delegada ao Claude, a asserção passou a conferir o catálogo vigente, seus botões de compra e a exclusão de Rocket/Gear 2, preservando os testes reais de compra e saldo. Não houve alteração no catálogo de frutas.


## 2026-10-10 — Cristais do V da Hie (Era do Gelo) nasciam na origem do mundo

**Sintoma:** na foto do V da Hie no mapa vivo, nenhum cristal de gelo aparecia na vila, só o decal.
**Causa raiz:** `EraDoGelo` montava tudo no `_ready`, que roda DENTRO do `add_child` — antes do `global_position = centro` da linha seguinte. Os filhos relativos (decal, área) acompanharam quando o nó foi posto no lugar, mas os cristais são `top_level` com transform global calculada por raios: foram assentados em volta de (0, 0, 0), longe da vila.
**Evidência:** foto art_src/validation/hie_v_gelo/de_cima.png sem cristais na 1ª versão; depois da correção, 30 cristais na borda do círculo.
**Descartado:** material transparente/decal escondendo os prismas.
**Correção:** src/effects/era_do_gelo.gd:63 — `lancar` posiciona e só então chama `_montar()` (o `_ready` não monta mais).
**Como detectar de novo:** DISPLAY=:1 test_hie_v_gelo.gd -- --tela (foto de_cima.png com o anel de cristais).

## 2026-10-10 — Corpo solto pelo vento ao lado de outro nunca "pousava" (8 s preso em arremesso)

**Sintoma:** test_harpia_vendaval reprovou "cancelamento libera todos os tipos" e "camadas restauradas" depois que o tornado passou de 8 para 14 m/s: a vaca ficou com a meta `arremesso_vento` e camada 0 por 6 s, em pé no chão.
**Causa raiz:** `captura_vento._physics_process` só considerava pouso quando `move_and_collide(DOWN*0,08, true)` devolvia contato com normal.y > 0,55. Solta encostada no NPC e no pet soltos junto (o tornado mais rápido os levou ao mesmo ponto), a recuperação de penetração do `move_and_collide` devolvia o corpo ~1,5 cm por quadro e a varredura curta devolvia NULO — o pouso nunca vinha; só o relógio de 8 s (CharacterBody) encerrava.
**Evidência:** depuração por quadro: contato=false, vel.y=-1,2, y alternando −0,0133/−0,0209 por 4 s; a mesma cena com o tornado a 8 m/s passa (falhas=0) — o tempo/posição de soltura muda, o código não.
**Descartado:** a IA nova da Harpia investindo nos capturados (congelar a Harpia no teste não mudou nada); a rampa vertical nova do tornado; janela de 1 cm (o tremor de 1,5 cm zerava o contador a cada quadro).
**Correção:** src/historia/bosses/harpia/captura_vento.gd:235 — caindo há > 0,3 s e sem sair de uma faixa de 5 cm por 0,25 s = apoiado (queda de verdade anda ≥ 30 cm nesse tempo).
**Como detectar de novo:** tools/dev_tests/test_harpia_vendaval.gd (cenário tipos_e_cancelamento), teste original sem alteração.

## 2026-10-08 — Cor média de modelo pela textura saiu branca (paleta "Atlas") e, pelos UVs, bege/preta

**Sintoma:** no desenho por distância, as copas das palmeiras e os blocos das pedras saíram quase brancos; depois de ler a textura nos UVs, pedras bege, uma árvore preta e o pinheiro cinza.

**Evidência:** cor calculada por modelo (GPU): `palm_tree` f5f2ef (textura "Atlas" inteira), depois ce9b76; `arvore_verde_adulta` 000000; `rocks-fy3szrmvue` ce9b76 (igual à palmeira).

**Causa raiz:** muitos modelos usam uma paleta quase toda branca com quadradinhos de cor, então a média da textura inteira é branca. A leitura nos UVs também não fecha: há folhas recortadas por transparência (pixel preto sob alfa 0) e, provavelmente, UVs comprimidos na malha importada.

**Correção:** parte com textura entra com a cor da CATEGORIA (copa `#4f7040`, pedra `#7d786c`); as cores lisas do material continuam valendo (casas: média correta, conferida).

**Como detectar de novo:** imprimir a cor calculada dos modelos mais usados (script de conferência) antes de confiar nela; foto do LONGE comparada com a de antes.

**Lição:** não deduzir a cor de um modelo pela textura sem saber se ela é paleta. De longe, uma cor de categoria bem escolhida é melhor que uma média errada.

## 2026-10-08 — Janela de loja mostrava a fala da missão antiga depois de entregar (cadeia do Guarda)

**Sintoma:** na foto `cadeia_pet_na_tela.png`, o alto da janela do Guarda dizia "Bandidos montaram acampamento..." enquanto a linha já era "Um companheiro de viagem — Em andamento".

**Evidência:** a captura com GPU do `test_cadeia_do_guarda -- --tela`; o código de `JanelaDeLoja` só escrevia `_fala.text` em `abrir()`.

**Causa raiz:** a fala era lida só ao abrir a janela. Com uma missão por NPC isso passava; com a cadeia, entregar uma missão troca a missão da vez com a janela aberta, e `atualizar()` refazia as linhas mas não a fala.

**Correção:** `atualizar()` relê `loja.fala()`; o teste confere a fala no alto da janela depois de aceitar.

**Como detectar de novo:** o `test_cadeia_do_guarda` lê o rótulo `Fala` da janela; foto da janela depois de aceitar e de entregar.

**Lição:** quando um estado que a tela mostra passa a mudar com a tela aberta, todos os textos que dependem dele vão para a função de atualizar, não só a lista.

## 2026-10-08 — Dois fundos do mar se sobrepunham 4 m: a grade arredondava uma célula para cima

**Sintoma:** `test_ilha_dos_macacos` acusou "os fundos se encontram no meio sem sobrepor (um termina em x=818.0, o outro começa em x=814.0)".

**Evidência:** alcance de 558 m (metade do caminho), `lado` 814 m, `n = ceil(2·lado/8)+1 = 205` pontos: a grade ia de −814 até −814 + 204·8 = 818.

**Causa raiz:** `FundoDoMar` usava passo fixo de 8 m com o número de pontos arredondado para cima, então a grade passava até uma célula do `lado` pedido. Com uma ilha só, ninguém via; com duas, elas se cruzavam numa faixa coplanar.

**Correção:** o passo virou `_celula = 2·lado/(n−1)`: a grade termina exatamente em `lado` (na ilha inicial o passo continua 8,0).

**Como detectar de novo:** o teste compara o fim da malha de um fundo com o começo do outro (AABB das duas `Malha`).

**Lição:** quando uma grade precisa ENCOSTAR em outra, o tamanho é o requisito e o passo é derivado; arredondar o número de células muda a borda.

## 2026-10-08 — Lambda de várias linhas no GDScript de novo (dois testes novos não compilaram)

**Sintoma:** `test_ilha_dos_macacos` e `test_lod_das_ilhas` pararam no parse: "Expected closing ')' after call arguments" e "Cannot infer the type of ... because the value doesn't have a set type".

**Evidência:** a primeira rodada de cada teste; as linhas eram `_blocos.all(func(p) -> bool:` com o corpo na linha seguinte, e `var x := lista.all(...)`/`var ok_pier := not pier.is_empty() and pier["modelo"] == ...`.

**Causa raiz:** escrevi o padrão que já tinha quebrado o `test_bandidos_e_missao` horas antes. O GDScript não aceita corpo de lambda numa linha de continuação dentro de parênteses, e `:=` não infere tipo de expressão que passa por Variant (`Array.all`, índice de Dictionary).

**Correção:** laço `for` no lugar da lambda de várias linhas e tipo explícito (`var ok: bool = ...`).

**Como detectar de novo:** antes de rodar, `grep -n "func(.*):$" arquivo.gd` (lambda terminando a linha) e `grep -n ":= .*\.all(\|:= .*\[\"" arquivo.gd`.

**Lição:** lambda só de uma linha; o resto vira laço. Em `:=`, se o lado direito passa por Variant (dicionário, `all`, `any`, `get`), declarar o tipo.

## 2026-10-08 — `class_name` nova não existe para o jogo até o cache de classes ser refeito

**Sintoma:** o teste novo das barras de chefe parou na compilação com "Could not find type BarrasDeChefes in the current scope". A classe estava escrita, salva e certa.

**Evidência:** depois de `godot --headless --path . --import`, a classe apareceu em `.godot/global_script_class_cache.cfg` (antes, 0 ocorrências) e o mesmo teste passou 9/9 sem mudar uma linha.

**Causa raiz:** o Godot só registra `class_name` no cache global quando o projeto é escaneado (editor ou `--import`). Rodar `--script` não refaz o cache. O pior caso: `AnimalDaIlha` e `besta_do_mar.gd` já citavam `BarrasDeChefes.GRUPO`. Sem o `--import`, o jogo aberto pelo lançador falharia a compilação desses scripts, e o gorila, a harpia e as bestas nem montariam.

**Correção:** `--import` depois de criar a classe. Nos scripts auxiliares novos desta etapa (roupa do bandido, missões, contador na tela), usei `preload` em vez de `class_name`.

**Como detectar de novo:** depois de criar `class_name`, conferir `grep -c <Classe> .godot/global_script_class_cache.cfg` e rodar `test_compila`.

**Lição:** classe global nova é mudança de PROJETO, não só de arquivo. Para ajudante interno, `preload` evita a armadilha; quando a classe for global, o `--import` faz parte da entrega.

## 2026-10-08 — Medida da cabeça nivelada usava a mesma conta que nivela: 0,0° por construção

**Sintoma:** o teste da cabeça estabilizada das bestas deu exatamente 0,0° de inclinação, tombo e rumo em todas as posturas e espécies. Exatidão total numa medida física é suspeita.

**Evidência:** `animador.eixos_da_cabeca()` calculava os eixos da cabeça com `rel * pose * cabeca_no_corpo⁻¹`, a mesma relação que `_nivelar_cabeca()` impõe. Logo, devolvia a identidade sempre que a função rodava, certa ou errada.

**Causa raiz:** escrevi a régua reaproveitando a fórmula do próprio ajuste. Um teste assim só prova que a conta concorda consigo mesma.

**Correção:** régua independente em `test_bestas_postura_foca`: o vetor junta→boca da cabeça comparado com a besta parada em pé (inclinação e rumo) e o eixo lateral do osso contra a gravidade (tombo). Resultado: até 0,7° de diferença e 0° de tombo, com tombo máximo de 1,3° na curva inclinada. Controle com a estabilização desligada: −71° a −78° de inclinação, até 23° de rumo e 5–8° de tombo dormindo. A régua reprova o que deve reprovar.

**Como detectar de novo:** desconfiar de 0,0 exato; rodar a medida com o ajuste desligado.

**Lição:** é o mesmo erro de método da paridade prévia×jogo de 07/10 — validar o sistema contra si mesmo. A régua tem que vir de fora da conta.

## 2026-10-08 — Gerador das bestas só gravava rotação: a descida da raiz sumia no GLB

**Sintoma:** depois de reescrever as poses deitadas (postura de foca), a prévia do Blender mostrava a barriga encostada no chão. Medindo os ossos no Godot, porém, o corpo marcava y 2,2 em TODOS os clipes, deitados ou em pé: o corpo deitado ficaria 1,1 m acima da areia.

**Evidência:** sonda de alturas por osso no GLB importado (`corpo y2.2` igual em `idle` e `dormindo`). Depois da correção: `corpo y1.4` nos deitados (−0,75 m, o valor pedido).

**Causa raiz:** `tools/blender/animacoes_bestas_mar.py` atribuía `rotation_euler` E `location` a cada osso por quadro, mas só fazia `keyframe_insert` de `rotation_euler`. A posição valia só na cena aberta (por isso a prévia, que aplica a pose direto, mostrava certo) e não entrava na ação exportada. Até então nenhum clipe mexia na posição de osso nenhum, então o furo nunca tinha aparecido.

**Correção:** chave de `location` para o osso `raiz` (o único que desloca). Assado de novo; medido no Godot.

**Como detectar de novo:** medir no GLB importado, não na prévia do Blender. `test_bestas_postura_foca` mede a cabeça deitada a ≤ 40% da altura em pé e a área de dano comprida e baixa.

**Lição:** a prévia que aplica a pose direto não prova o que a exportação leva. A régua é o arquivo que o jogo carrega.

## 2026-10-07 — Clipes bakeados no espaço do esqueleto: golpes deitavam o boneco e espelhavam o antebraço

**Sintoma:** o dono relatou duas vezes que as animações do Skills Builder estavam "meio de lado" e depois "continuam bugadas, e muito parecidas". Nos golpes, o boneco tombava para trás ou de lado (o `uppercut_jab` chegava a deitar no chão) e a guarda saía com os antebraços abertos para fora.

**Evidência:** sonda `tools/dev_tests/medir_clipes_do_builder.gd`, direção de cada segmento no .glb do Mixamo × no Base tocando o .res. Erro médio: golpes de 28° a 50°, cobertura e furtividade de 66° a 120°; antebraço esquerdo do `punching` 100° (no original cruza para a guarda, no nosso aponta para fora); corrida 16° (pernas 5°). Fotos lado a lado com GPU (`capturar_clipes_x_mixamo.gd`): o original em pé, o nosso deitado nos mesmos instantes. O esqueleto do .glb fica sob um nó `Armature` girado e com escala 0,01.

**Causa raiz:** `tools/bake_mixamo.gd` convertia o giro de cada osso com o giro de 180° (yflip) no espaço do ESQUELETO. Esse espaço está girado 90° em X em relação ao mundo, então giro em torno da vertical virava giro em Z (tombo) e vice-versa. Giros em X (dobrar joelho, balançar a perna) passam intactos, e por isso a corrida parecia certa e serviu de "prova". Além disso, o baker ignorava que o repouso do Mixamo é a pose T e o zero do nosso rig tem os braços pendurados. O cabeçalho do baker até registrava "as faixas de rotação continuam na conversão de sempre, para casar com os clipes v1". Minha correção anterior do mesmo dia (`ClipesDeSkill.endireitar`, que tirava a inclinação lateral MÉDIA do tronco) tratou só o sintoma. E o teste de paridade prévia × jogo passou porque os dois tocavam o mesmo .res errado.

**Correção:** conversão v3 no baker: `global = yflip · A · pose · repouso⁻¹ · A⁻¹ · yflip⁻¹ · Q`, com A = giro do esqueleto no mundo e Q = do braço pendurado até a pose T (só braço e antebraço). O refino de chaves perto do gimbal passou a valer para todos os clipes (socos erguem o braço até x ≈ 90°). Os 61 clipes foram reassados (backup em `~/dev/_backups/skills-one-piece/animations-20261007-antes-do-rebake`), o `endireitar` saiu do jogo, da prévia e do catálogo, e o metadado `conversao = 3` vai em todo .res. Depois da correção: membros com erro médio de 3° a 6°, coluna de 5° a 11°, braço igual à abertura do zero do Base (19,2°, da proporção dele).

**Como detectar de novo:** `tools/dev_tests/test_fidelidade_dos_clipes.gd` compara 13 clipes (golpes que giram o corpo, guarda, corrida, roll, deslize, cobertura) com o .glb em 21 instantes. `test_animacoes_do_builder` exige `conversao = 3` em todo clipe da lista.

**Lição:** um teste que compara o sistema consigo mesmo (prévia × jogo, mesmo arquivo) não valida o conteúdo; a régua tem que ser a fonte. Um "controle" que só exercita um eixo (a corrida) esconde troca de eixos. E corrigir a média de um sintoma (inclinação do tronco) sem achar a causa empurra o defeito para frente: o dono percebeu de novo no mesmo dia.

## 2026-10-07 — Sonda de rede da Pika reprovou o C por azar: mínimo de dano num golpe de área sorteado

**Sintoma:** `net_pika_probe` reprovou na bateria: "C: a chuva cai no host mirado, 0.8 estouros de 40 (caiu 32.4)", mínimo 60. Na rodada anterior a mesma sonda tinha dado 6,4 estouros.

**Evidência:** o host registrou a chuva centrada nele (ponto mirado = o corpo dele). A queda é sorteada por igual num círculo de 9 m: segurando 1,1 s (70 bolinhas), um alvo parado no meio leva ~4 estouros em média, e 1 ou menos em ~11 % das vezes. O teste local (`test_pika_builder`, C inteiro) deu 7 estouros na mesma execução. Com o C inteiro e mínimo de 1 estouro: 4,8 e 8,8 em duas rodadas seguidas.

**Causa raiz:** eu (rodada 2) pus na sonda de REDE um mínimo de dano calibrado por uma única amostra de um golpe aleatório. A sonda tem de provar a rede (o servidor fere quem foi mirado), não a sorte do sorteio.

**Correção:** a sonda segura o C inteiro (112 bolinhas) e exige pelo menos um estouro no host.

**Como detectar de novo:** teste com limite de dano/acertos em golpe sorteado tem de vir com a conta da chance de reprovar por azar (deixá-la abaixo de ~1 %) ou medir o que é determinístico (centro, raio, quem fere).

**Lição:** golpe aleatório se testa pela regra e pela distribuição, nunca por um número de uma amostra só.

## 2026-10-07 — Bateria abortou com "erro de sintaxe" no validar.sh: outra frente editou o script durante a execução

**Sintoma:** a bateria completa das rodadas 4 e 5 parou depois dos testes headless com `./validar.sh: linha 196: erro de sintaxe próximo ao token inesperado '('` numa linha que é só um `echo`. Testes de cena, LAN, sondas de rede e a regressão de locomoção não rodaram.

**Evidência:** `validar.sh` foi modificado às 21:14:46, no meio da execução (que começou perto de 20:50). A frente das bestas do mar acrescentou `test_rotina_oceano_bestas` ao `args_de`. `bash -n validar.sh` passa no arquivo novo.

**Causa raiz:** o bash lê o script AOS POUCOS enquanto executa. Uma edição que muda o tamanho do texto antes do ponto em que ele está desloca o resto, e o bash passa a ler do meio de uma linha. Com várias frentes no mesmo repositório, qualquer uma pode mexer no `validar.sh` durante uma bateria de 45 min.

**Correção:** as seções que faltaram rodaram a partir do texto carregado inteiro na memória (`bash -c "$(cat validar.sh)" ./validar.sh <filtros>`): uma edição durante a execução não afeta mais a bateria.

**Como detectar de novo:** erro de sintaxe do bash numa linha inocente no meio de uma execução longa = o script mudou debaixo dela; comparar o mtime do `validar.sh` com o horário de início.

**Lição:** bateria longa num repositório com frentes paralelas roda a partir de uma cópia congelada do script.

## 2026-10-07 — Script "salvou" o Z na biblioteca do editor, mas na pasta errada (XDG do VSCode snap)

**Sintoma:** `criar_hie_hie.gd` imprimiu "Salva: user://skills_builder/Z_ice.json", mas o arquivo do dono (`~/.local/share/godot/app_userdata/SKILLS ONE PIECE/skills_builder/Z_ice.json`) continuou o de 11:01, e o `Z_ice_original` não apareceu lá.

**Evidência:** `echo $XDG_DATA_HOME` = `/home/gabriel-bitti/snap/code/264/.local/share`. Os arquivos novos estavam em `~/snap/code/264/.local/share/godot/app_userdata/SKILLS ONE PIECE/skills_builder/` (14:02).

**Causa raiz:** o terminal do Claude herda o `XDG_DATA_HOME` do VSCode em snap. O Godot rodado daqui resolve `user://` dentro do snap, e o jogo do dono (lançador da área de trabalho) resolve na pasta normal. A memória já tinha essa armadilha registrada (Spec Kit), mas eu não a apliquei ao `user://` do Godot. Na primeira rodada, além disso, o "Salvar" pediu confirmação para sobrescrever e o script não respondeu.

**Correção:** o rascunho original foi copiado como `Z_ice_original` e o `Z_ice` melhorado foi posto na pasta REAL do dono (idêntico ao publicado). No script, `ed._gravar()` (o "Substituir").

**Como detectar de novo:** antes de dizer que algo foi gravado em `user://` do dono, conferir o arquivo em `~/.local/share/godot/app_userdata/<projeto>/`. Para escrever lá daqui, rodar com `XDG_DATA_HOME=$HOME/.local/share`.

**Lição:** o `user://` dos meus testes (`~/snap/...`) não é o do jogo do dono; testes isolados ficam bem assim, mas os dados DELE moram na pasta normal.

## 2026-10-07 — Gelo da Hie não prendia outro jogador em rede, nem boneco/bicho/inimigo; o bloco ficava em cima da cabeça

**Sintoma:** achado ao preparar a Hie refeita ("todos os golpes congelam 0,7 s"). (1) Nenhum RPC de congelamento: o servidor marcava `is_frozen` na CÓPIA do jogador remoto, mas quem move o corpo é o cliente dono. (2) Boneco de duelo, inimigos do mapa e bichos não leem `is_frozen`: o bloco de gelo aparecia e o boneco seguia lutando dentro dele. (3) Foto: o bloco de gelo aparecia em cima da cabeça do boneco. (4) Teste removendo o alvo congelado: "Lambda capture at index 0 was freed".

**Evidência:** `grep is_frozen` só no Player, nos controladores de fruta, na montaria/comando e nas bestas do mar. A sonda nova `net_hie_*_probe` mede no cliente: congelado 0,70 s, 0,00 m andados com W apertado; o Z do host o congela 0,69 s. `test_hie_builder`: a física do boneco fica parada enquanto o gelo dura e volta depois. Bloco a +0,8 m de uma origem que já é o meio da cápsula.

**Causa raiz:** o congelamento foi escrito para o jogo local (`_congelar_alvo` aplica no nó onde a detecção acontece) e para o Player. A rede e os outros tipos de corpo nunca foram medidos. O bloco usava uma altura fixa pensada para origem no pé. Os temporizadores guardavam nós em funções anônimas.

**Correção:** `IceFX.congelar(alvo)`: 0,7 s com 0,5 s de imunidade (decisão do dono). O servidor decide e espalha (`Player.congelar_em_rede`). Quem não é jogador tem a física parada enquanto o gelo dura. O bloco fica no meio do corpo (`centro_do_corpo` nos bichos). Os temporizadores usam referências fracas (`_descongelar`/`_fim_da_imunidade`). X, C e o campo do V usam o mesmo `congelar`.

**Como detectar de novo:** todo efeito de controle (congelar, paralisar, lentidão) precisa de sonda com o ALVO num cliente e de teste com boneco/bicho/inimigo, não só com o jogador local.

**Lição:** status que trava movimento tem de chegar a quem move o corpo; e "o alvo respeita o efeito" se confere por tipo de corpo.

## 2026-10-07 — Rodada 4 do Builder: três erros de método (mapa, vigia de cena, pose com raiz)

**Sintoma:** (1) o "▶ Testar no jogo" abriu o Modo História sem mapa: "MapaArquivo recusado: JSON inválido" / "o arquivo não existe". (2) saindo do teste pelo menu, o catálogo de teste continuava forçado (`pasta_forcada` = user://teste_do_builder/skills). (3) a pose básica "Investida" deixava o pé da frente atrás (z +0,05).

**Evidência:** (1) `MapaArquivo.salvar` chama `para_texto`, que espera o mapa CARREGADO (Vector3/Color): "Cannot convert argument 1 from Array to Vector3". (2) depois de `back_to_menu`, `is_instance_valid(cena_antiga)` continuou verdadeiro por quadros. (3) o tronco é a raiz do rig: −30° nele giram as pernas para trás.

**Causa raiz:** (1) usei a API de salvar sem ler o formato que ela espera. (2) supus que a cena antiga é liberada no mesmo quadro da troca. (3) montei a pose como se o tronco fosse filho do quadril.

**Correção:** (1) o mapa vai como texto JSON no formato do arquivo. (2) a vigia compara com `current_scene`. (3) a inclinação do tronco é compensada nas coxas (+30°). Testes: `test_testar_no_jogo` 8/8 e `test_poses_basicas` 15/15.

**Como detectar de novo:** ler a função antes de chamar (tipos do dicionário); a troca de cena se detecta por `current_scene`; pose que inclina o tronco tem de medir os pés.

**Lição:** neste rig o tronco é a raiz; e "liberado" não acontece no mesmo quadro da troca de cena.

## 2026-10-07 — Clipes do Builder deixavam o personagem "meio de lado": tronco bakeado inclinado

**Sintoma:** relato do dono: "as animações estão incorretas, todas viram o personagem meio de lado, a única correta é a investida". Foto do jogo e da prévia no mesmo instante: no Ataque (`punching`) o corpo inteiro aparece tombado ~60° nos dois.

**Evidência:** inclinação LATERAL média do "para cima" do tronco por clipe: `running` −3°, `sprint` (Investida) 8°, `idle` 34°, `punching` 44°, `kicking` 46°, `bouncing_fight_idle` 51°, `roundhouse_kick` 73°; `idle_4`/`idle_5`/cobertura ~170° (de cabeça para baixo). O tronco é a RAIZ do corpo no rig A: a inclinação dele leva pernas e cabeça junto.

**Causa raiz:** o bake desses clipes deixou a orientação do quadril/coluna do Mixamo no tronco. Só os clipes da marcha (running/sprint) saíram retos, e eram os únicos que o jogo tocava pelo corpo inteiro. MEU erro na rodada 3: o teste de paridade prévia × jogo deu 0° e eu declarei as animações "corrigidas" sem olhar uma foto. Paridade prova que os dois fazem igual, não que estão certos.

**Correção:** `ClipesDeSkill.endireitar(clipe)` tira a inclinação lateral média do tronco (a para frente fica; os clipes que giram o corpo de propósito, como rolamentos e `dying`, não mudam). Aplicada na prévia, no jogador (`ProceduralAnimator.acao_endireitar`) e na cópia remota. `test_animacoes_do_builder` exige "nenhum clipe de lado na média", e as fotos de frente e de lado conferem.

**Como detectar de novo:** todo visual novo do Builder precisa de foto de frente e de lado; teste de paridade sozinho não basta. Para clipe bakeado, medir a postura média do tronco.

**Lição:** "prévia igual ao jogo" não quer dizer "certo"; a referência é o que se vê.

## 2026-10-07 — VFX ancorado num projétil ficava um quadro atrás da bola

**Sintoma:** `test_ancora_do_vfx`: "Projétil (a bola)" a 0,133 m no jogo e 0,067 m na prévia; as outras âncoras davam 0,000 m.

**Evidência:** 0,133 m = 8 m/s × 1/60 s (um quadro de física); 0,067 = 8 × 1/120 (um passo da prévia). Os blocos (VFX) são processados antes de `_avancar_manuais`/`_avancar_projeteis` no mesmo quadro.

**Causa raiz:** a âncora lia a posição do projétil ANTES de ele andar naquele quadro.

**Correção:** `_seguir_projeteis()` reposiciona os VFX de âncora "Projétil" depois do avanço (executor e prévia), sem mudar a ordem de disparo das outras skills.

**Como detectar de novo:** o que segue um objeto que se move no mesmo quadro tem de ser atualizado DEPOIS dele; medir com tolerância menor que velocidade × passo.

**Lição:** seguidor é atualizado depois do seguido.

## 2026-10-07 — Voo (F da Pika) saía de graça na história: a regeneração pagava o custo por segundo

**Sintoma:** `test_pika_builder`: "história, F: gasta energia voando (0.0 de 10 em 1 s)". Na arena gastava 266 de 4096.

**Evidência:** a história regenera 1/s (`PerfilDeFrutas.REGEN_DA_ARENA` = 1,0 numa barra de 10); o custo do voo era 5 %/s = 0,5/s. A arena regenera 0,5 %/s. Depois da correção: história 0,7 e arena 287 em 1 s (2 % + 5 %).

**Causa raiz:** escrevi o custo por segundo como fração da energia máxima sem contar a regeneração, que segue correndo enquanto se segura. O projeto já tinha resolvido o mesmo problema no dreno da invisibilidade da Suke (`Player.dreno_da_invisibilidade` soma a regeneração do modo), e eu não consultei.

**Correção:** `AtivacaoDoKit` cobra o custo por segundo LÍQUIDO: a fração mais a regeneração atual do dono (a do modo, ou a da arena).

**Como detectar de novo:** todo custo contínuo (por segundo) tem de ser medido nos DOIS modos com a energia cheia; gasto zero = a regeneração está pagando.

**Lição:** antes de criar um gasto contínuo, procurar os drenos que já existem no projeto e a regra deles.

## 2026-10-07 — Bloco Animação do Builder: a prévia tocava uma coisa e o jogo outra

**Sintoma:** relato do dono: "corrigir as animações atuais" do Skills Builder. O que se via no editor não era o que saía no jogo.

**Evidência:** `arena_preview._animar` tocava clipes do AnimationPlayer do modelo (Ataque = `punching`, Planar = `jump`, Investida = `run`, Vendaval = `groundsmash`). No jogo, `Player.tocar_animacao_de_skill` ligava uma POSE procedural antiga por `KitDoBuilder.POSES` (Ataque = `bomu_z_strike`, Planar = `air_slam_dive`...). Depois da correção, `test_animacoes_do_builder`: prévia × jogo no mesmo instante = 0,0° (roll 0,1°).

**Causa raiz:** dois sistemas para o mesmo campo, montados em momentos diferentes (a prévia com clipes, o jogo reaproveitando as poses que já existiam), sem teste que comparasse os dois. A prévia ainda punha uma inclinação do corpo ("Intensidade") que o jogo não tinha.

**Correção:** lista única `clipes_de_skill.gd` (61 clipes bakeados + 5 atalhos). No jogo, o clipe sai pelo "clipe de ação" do `ProceduralAnimator` (o caminho do roll do Q, já replicado em rede), no tempo do bloco. Na prévia, o mesmo arquivo lido por `ProceduralAnimator._clipe`, nos mesmos papéis. Intensidade = peso do clipe nos dois (`acao_peso`).

**Como detectar de novo:** campo do Builder que vira visual tem de ter teste de paridade prévia × jogo no mesmo instante (ossos, posição).

**Lição:** prévia que não usa o mesmo código/dado do jogo mente; o editor deve chamar a mesma fonte, não uma imitação.

## 2026-10-07 — Testes da rodada 2: premissa errada sobre recarga e tipos no GDScript

**Sintoma:** três falhas que eram do teste, não do jogo. (1) `test_intervalo_entre_golpes`: "a recarga do X anda durante o intervalo (3.00 → 3.00)". (2) `test_pika_builder` não carregou: "Cannot infer the type of tam0". (3) "argument 1 (previously freed) is not a subclass" em `_anotar_estouros`.

**Evidência:** (1) `Player._physics_process` já congela as recargas das OUTRAS teclas enquanto um golpe está em curso (`_slot_em_uso`), regra antiga. O Z da Goro estava em curso nos 0,3 s medidos. Armando o intervalo sem golpe em curso: 3,00 → 2,70. (2) `estrela.get_node(...).scale.x if ... else 0.0` não tem tipo inferível. (3) O executor da chuva termina sozinho, e um parâmetro tipado `Node` não aceita objeto liberado.

**Causa raiz:** (1) medi "o intervalo não pausa recargas" com um golpe real em curso, misturando duas regras. (2 e 3) armadilhas conhecidas do GDScript (inferência com ternário; tipar argumento que pode estar liberado).

**Correção:** (1) armar o intervalo direto, sem golpe em curso. (2) `var tam0: float`. (3) parâmetro `Variant` + `is_instance_valid`.

**Como detectar de novo:** antes de medir uma regra, listar as outras regras que mexem na mesma variável no mesmo instante. Valor lido por ternário vai tipado à mão; nó que pode sumir entra como `Variant`.

**Lição:** isolar a regra medida das regras vizinhas; o teste deve falhar só pelo que afirma.

## 2026-10-07 — Recarga do Z carregado contava desde o APERTO, não do disparo

**Sintoma:** foto do Z segurando (rodada 2): a HUD de técnicas mostrava "faltam 3,3 s" no Z ainda carregando; ao soltar depois de 2 s, sobravam ~3 s de recarga, e segurando 4 s quase nada.

**Evidência:** `AtivacaoDoKit._ativar` chama `trigger_skill_cooldown` no aperto para todos os modos. Em "Carregar e soltar" o golpe só sai no soltar. Depois da correção, `test_pika_builder`: "faltam 4,8 s de 5 depois de segurar 2 s".

**Causa raiz:** ao trocar o Z para "Carregar e soltar" eu revi a mira e o intervalo no soltar, mas não a recarga. Ela continuou presa ao momento do aperto, que era o certo só no "Pressionar".

**Correção:** no soltar (sem cancelar) de "Carregar e soltar", `trigger_skill_cooldown` de novo: a recarga e o intervalo entre golpes recomeçam do disparo. O aperto continua armando, para não abrir brecha de dois lançamentos.

**Como detectar de novo:** em todo golpe que separa aperto e disparo, conferir a recarga logo depois do disparo, com a tecla segurada bastante tempo.

**Lição:** mudar QUANDO um golpe sai obriga a revisar tudo o que conta a partir do lançamento: recarga, intervalo, mira e custo.

## 2026-10-07 — Chuva do C concentrada no meio passava do teto de dano da Pika

**Sintoma:** na sonda de rede, o C novo (chuva) tirou 385 do host em só 1,1 s segurando (12,8 estouros de 30), o teto inteiro do C antigo (384), com 5 de 8 ondas.

**Evidência:** `chuva_de_projeteis.quedas` sorteava o raio com `pow(randf, 0.75)`, que concentra os pontos no meio. Com 30 por estouro, no teste da história deu 13 estouros (390) segurando tudo. Com o sorteio uniforme (`sqrt(randf)`) e 40 por estouro: 7 estouros (280) num alvo parado no meio, segurando tudo.

**Causa raiz:** escolhi a concentração "no olho" para a chuva parecer mais certeira, sem conta de densidade. O alvo sempre fica no centro da área (o centro É o ponto mirado), e a concentração multiplicava os acertos nele. O dono pediu "ampla dispersão", que é o uniforme.

**Correção:** sorteio uniforme no círculo e 40 por estouro (`DANO_C` em `tools/criar_pika_pika.gd`); o teste imprime quantos estouros pegaram o boneco do meio.

**Como detectar de novo:** todo golpe de área sorteada precisa medir o dano num alvo PARADO no centro, segurando tudo, contra o teto do golpe que ele substitui.

**Lição:** distribuição de golpe em área é número de balanço, não estética: mede-se o acerto esperado no centro antes de escolher.

## 2026-10-07 — Teste contava o som do dash no FIM do dash; o som (relógio real) já tinha acabado

**Sintoma:** `test_q_rolar_e_dash` passou sozinho (10/10) e reprovou na bateria completa: "história, ar: anel de choque (+1) e som da esquiva (+0)".

**Evidência:** `AudioFX._dash_stream` gera 0,22 s de som e liga `finished → queue_free`; o dash dura 0,28 s (17 quadros de física). O teste contava os `AudioStreamPlayer3D` da cena só depois do laço do dash. Contando no quadro seguinte ao aperto: som +1 e anel +2 nos dois modos.

**Causa raiz:** misturei dois relógios. A física anda por quadro; o áudio (driver Dummy no headless) anda em tempo real. Com a máquina carregada pela bateria, cada quadro de física leva mais tempo de parede e o som de 0,22 s termina e se libera antes do 17º quadro. Sozinho, a máquina folgada deixava o som vivo por acaso.

**Correção:** o teste conta anel e som um quadro de física depois do aperto do Q (quando nascem), não no fim do dash. Rodado de novo: 10/10.

**Como detectar de novo:** teste que conta nós efêmeros (som, partícula com `queue_free` no fim) depois de esperar N quadros de física. Se o nó vive por tempo de parede, contar logo após o gatilho ou ligar um sinal.

**Lição:** efeito que se autodestrói por tempo real se mede no instante em que nasce; N quadros de física não equivalem a N/60 s quando a máquina está sob carga.

## 07/10/2026 — Pika refeita cobrava 0,4 de energia na história (fração do Builder no lugar da ficha)

**Sintoma:** `test_frutas_na_historia` reprovou "pika_pika: energia da ficha (2–5)". Z, X e C da Pika refeita gastavam 0,42 de energia, quando a ficha da fruta cobra 4.

**Evidência:** log da bateria de 07/10: "pika_pika/Z gastou 0.42 (ficha 4)" (o mesmo no X e no C). A recarga batia com a ficha (5/7/10 s).

**Causa raiz:** o custo do Builder é uma FRAÇÃO da energia máxima (4,4 % = os 180 de 4096 da arena). Eu pus o ramo "tecla pelo Builder" antes do da ficha em `Player.custo_de_energia_do_cast`. Na história a energia máxima é ~10 e a economia das frutas é a da ficha (2–5): a fração dava 0,4.

**Correção:** fruta inteira do Builder continua pela fração. Fruta da arena refeita usa a ficha quando há ficha (história) e a fração na arena (= 180). A ficha (`PerfilDeFrutas.da_arena`) deixou de sobrescrever o custo da tecla refeita.

**Como detectar de novo:** `test_frutas_na_historia` compara gasto × ficha de cada tecla de cada fruta.

**Lição:** número "em porcentagem da barra" não é a mesma unidade nos dois modos; ao trocar o dono de uma tecla, conferir a economia de cada modo, não só o dano.

## 07/10/2026 — reconstrução da Pika: armadilha do `as` repetida e sonda de rede mirando errado

**Sintoma:** quatro tropeços na reconstrução da Pika no Builder.
- O script de autoria não compilou ("Expected else after ternary").
- `skills_publicadas.gd` deixou de compilar.
- O editor recusou a duração de 0,5 s do Z.
- Na primeira sonda de rede, o Z e o X do cliente deram 0 de dano no host, enquanto o C acertava.

**Evidência:**
- **Autoria:** `0 if ok and teclas == ["Z","X","C"] as Array[String] else 1` no `criar_pika_pika.gd`.
- **Catálogo:** "There is already a variable named f" em `_ler_frutas`.
- **Duração:** "campo recusado configuracoes.duracao = 0.5", porque os blocos padrão da skill nova vão até 0,9 s.
- **Sonda:** o host imprimiu a cópia do cliente com o ponto mirado no chão a 7 m (Z), em y = −4,8 num buraco da arena (X) e, depois, com rumo −Z em vez dos 45° pedidos.

**Causa raiz:**
1. A precedência do `as` dentro de expressão, armadilha JÁ registrada (06/10), repetida.
2. Nome de variável igual a outro do mesmo escopo.
3. A ordem da autoria: a duração foi mudada antes de limpar a timeline.
4. A sonda posicionava o cliente sem pensar no jogo:
   - pitch fixo, com a câmera de ombro olhando para o chão;
   - partida escolhida sem conferir os buracos da arena;
   - `_yaw` trocado sem `_update_pivot`, e a mira do golpe sai da câmera.

**Correção:**
- Comparação por `size()` e `has()`.
- Variável renomeada.
- Timeline vazia antes da duração.
- Na sonda: mira de verdade (câmera → peito do host); partida do X escolhida entre 8 rumos pelo raio até o chão; `_update_pivot` ao reposicionar.
- Resultado: rede Z 98, X 156, C 4 acertos.

**Como detectar de novo:** compilar com `--check-only` cada script novo antes de rodar; em sonda de golpe dirigido, imprimir no servidor a posição e a mira da cópia do atacante no instante do golpe antes de culpar o jogo.

**Lição:** golpe que depende da mira ou da posição falha em rede por erro do TESTE tão facilmente quanto do jogo; medir o que o servidor vê separa os dois em uma rodada.

## 06/10/2026 — painel de tempo da corrida cobria os avisos da HUD da história

**Sintoma:** na foto do grid de frente, o aviso "Corrida de caranguejos! O Y fica travado até a chegada." aparecia por trás do painel de tempo, ilegível.

**Evidência:** `capturar_corrida_caranguejos.gd`, quadro `1b_grid_de_frente`: o painel ia de y = 96 a 190 e o aviso da `HistoriaHud` fica em y ≈ 144, no meio da tela.

**Causa raiz:** ao tirar o painel de cima das barras de vida, eu o desci para y = 96 no MEIO da tela, sem olhar onde a HUD da história põe os avisos.

**Correção:** o painel foi para o canto superior direito, crescendo para a esquerda, que está livre na HUD da história. Na nova foto o aviso aparece inteiro.

**Como detectar de novo:** HUD nova sobre a HUD da história se valida com foto num momento em que há aviso na tela (a montaria avisa ao montar).

**Lição:** antes de escolher o lugar de um painel, levantar o que já ocupa a tela, inclusive o que aparece só às vezes.

## 06/10/2026 — `test_npcs_e_lojas` quebrou com o NPC novo da corrida (contagem fixa em 3)

**Sintoma:** a bateria reprovou "exportador cria a aba NPCs e os três modelos" e "exportador é idempotente".

**Evidência:** `/tmp/validar_test_npcs_e_lojas.log`: a 2ª rodada respondeu "já está na loja" quatro vezes. O teste esperava `loja.ids().size() == 3`.

**Causa raiz:** o teste fixava o número de NPCs (3), e eu acrescentei a ficha `npc_corrida` (Organizador da corrida) sem procurar quem contava as fichas.

**Correção:** a conta virou `NpcDaIlha.FICHAS.size()` (um modelo por ficha, que é o que o teste quer provar). 44/44.

**Como detectar de novo:** ao acrescentar entrada numa tabela de fichas, procurar com `grep` os testes que contam a tabela (`size() == N`).

**Lição:** teste que conta itens de um catálogo deve derivar a conta do catálogo, não de um número.

## 06/10/2026 — corrida e loja de projéteis: defeitos que só as fotos e os números mostraram

**Sintoma:** com o código "pronto", seis defeitos apareceram:
- os 5 rivais com o mesmo tempo (164 s);
- o painel de tempo cortado ("Passarela dos ma…") e depois encostando nas barras de vida;
- os rivais com o casco igual ao do jogador;
- na loja de projéteis, a grade alargando o painel e apertando a prévia;
- bala, bomba e shuriken pretas na miniatura;
- o miolo da energia com aro e o rastro de fogo estourando em branco.

**Evidência:**
- **Relógio:** `test_corrida_de_caranguejos` imprimiu os 5 rivais com 164 s.
- **HUD:** fotos `capturar_corrida_caranguejos.gd`; o painel começava no meio da tela.
- **Casco:** medição dos materiais do caranguejo: `vertex_color_use_as_albedo` com albedo branco.
- **Grade da loja:** a medição do inspetor deu conteúdo de 256 px contra uma grade de 308 px.
- **Miniaturas, aro e fogo:** fotos `capturar_loja_de_projeteis.gd`.

**Causa raiz:**
- **Relógio:** parava quando o jogador chegava, e quem cruzava depois herdava o tempo dele.
- **HUD:** `PRESET_CENTER_TOP` sem `grow_horizontal = BOTH` cresce só para a direita, e o deslocamento ignorava as barras (que vão até y = 86).
- **Casco:** a cor vem dos VÉRTICES; tingir o albedo só multiplica o marrom e escurece.
- **Grade da loja:** 3 cartões de 100 px não cabem nos 256 px do inspetor.
- **Miniaturas:** metal espelhado reflete o fundo escuro e fica preto, e a câmera de frente encurta forma comprida.
- **Aro:** miolo opaco ganha o contorno toon.
- **Fogo:** partículas aditivas de alfa cheio empilham até o branco.

**Correção:**
- **Relógio:** segue até a volta à ilha; só o tempo do jogador fica fixo.
- **HUD:** cresce para os dois lados e fica abaixo das barras (y = 96).
- **Casco:** no lugar de tingir, bandeirola na cor do rival.
- **Grade da loja:** 2 colunas de 124 px.
- **Miniaturas:** foto com luz de preenchimento e de contorno, vista de lado (de cima para a shuriken) e aço menos metálico.
- **Aro e fogo:** miolo só de brilho e rastro de fogo com alfa 0,55.

**Como detectar de novo:** fotografar com GPU antes de declarar pronto, inclusive com a HUD da história ligada; ler o tempo de CADA corredor no teste, não só o do jogador.

**Lição:** teste headless passando não diz se a tela está certa; e um número igual para todos os corredores é sintoma, não coincidência.

## 06/10/2026 — IA dos caranguejos não passava do parkour (quatro erros de projeto meus)

**Sintoma:** nas primeiras corridas de teste, os 6 caranguejos caíram mais de 100 vezes cada nas ilhotas. Depois, empacaram antes dos degraus, e o do jogador (piloto automático do teste) caía em loop nas plataformas.

**Evidência:** traços por quadro de `test_corrida_de_caranguejos`/`_dbg_corrida`:
- pulo saindo 1,5 m antes da borda, pouso a 10 cm do começo da ilhota;
- velocidade lateral de 5,9 m/s na decolagem (pulo na diagonal);
- reaparecendo no meio das ilhotas, o próximo ponto já era a ilhota seguinte, sem marca de pulo;
- atravessando a lama na diagonal, chegava ao degrau a 2 m/s para a frente.

Depois das correções: o jogador completa em 163,8 s com 1 queda, e os 5 rivais terminam entre 167 e 195 s com 0 a 3 quedas.

**Causa raiz (quatro, todas do meu desenho):**
1. Marca de pulo 0,9 m antes da borda, mais uma margem de 0,7 m. O pulo seguia a direção da VELOCIDADE, então quem chegava de lado pulava na diagonal, pousava fora da linha e corrigia de lado de novo (zigue-zague).
2. O portão do meio das ilhotas guardava o índice do caminho DEPOIS da marca de pulo da própria ilha.
3. Os pulos dos degraus estavam no meio da pista, mas a IA vinha pela faixa seca da lama, do lado esquerdo.
4. O piloto do jogador no teste não era recolocado no caminho ao reaparecer; o dos rivais era.

**Correção:**
1. Marca na borda (0,15 m), aproximação já alinhada no meio da sobreposição entre ilhotas e pulo no rumo da pista. No ar o piloto mantém o rumo, e ele não corta caminho entre pontos de parkour.
2. O portão do meio aponta para o alinhamento da 5ª ilha, e cada portão tem a própria distância de volta; o reaparecimento acha o chão por raio.
3. Os degraus seguem a raia da faixa seca.
4. O controlador é dono do piloto do jogador (`piloto_do_jogador`) e o recoloca no caminho.

**Como detectar de novo:** o teste corre a volta inteira com o caranguejo do jogador e exige < 5:00 e os 5 rivais terminando. Ao travar, o traço por quadro (posição, chão, velocidade, ponto do caminho) mostra onde.

**Lição:** caminho de IA em parkour precisa respeitar o momento do pulo (velocidade e alinhamento antes da borda), não só os pontos; e todo reaparecimento precisa ressincronizar quem pilota.

## 06/10/2026 — caranguejo travava na quina entre rampa e deck (cilindro de fundo chato)

**Sintoma:** na corrida, o caranguejo subia a rampa a 8,5 m/s e parava de vez no alto (x = 143,12), com o comando mandando seguir. Todos os corredores empacavam no portão 5.

**Evidência:** traço quadro a quadro: `is_on_wall` verdadeiro, colisão com `deck_185` de normal (−1, 0, 0), velocidade 0. Pela geometria, o topo da rampa e o do deck têm a mesma altura (5,00 m, menos de 3 mm de diferença). Prolongar a rampa 0,6 m não mudou nada (mesmo x = 143,12).

**Causa raiz:** o corpo do caranguejo é um `CylinderShape3D` de FUNDO CHATO. Num declive, um disco nivelado se apoia pela borda de cima; subindo, a borda da frente encosta na quina do deck seguinte, que está na mesma altura, e o motor a lê como parede. Mexer na geometria só leva o degrau para a outra ponta da rampa.

**Correção:** `locomocao_de_montaria.gd` ganhou "subir quina baixa" (`DEGRAU_MAX` 0,15 m): com parede no passo, testa subir, andar e achar chão firme (normal.y ≥ 0,7), e só então sobe. O degrau de 0,5 m da pista continua exigindo pulo. Depois disso o caranguejo passa a rampa, e `test_nado_montaria` segue com 0 falhas.

**Como detectar de novo:** corpo de fundo chato (cilindro, caixa) que para em junção de peças: medir `is_on_wall` e a normal da última colisão no quadro em que a velocidade zera.

**Lição:** controlador de personagem com forma de fundo chato precisa de subida de quina; consertar cada junção da pista é enxugar gelo.

## 06/10/2026 — sobrescrevi um script de outra frente fora do git (`tools/dev_tests/capturar_corrida.gd`)

**Sintoma:** ao criar as fotos da corrida de caranguejos com o nome `capturar_corrida.gd`, a ferramenta de escrita respondeu "atualizado", não "criado". Já existia um script com esse nome, de outra frente.

**Evidência:** `tools/dev_tests/capturar_corrida.gd.uid` de 03/10 16:08; sessões do Codex de 01, 02, 05 e 06/10 listam o `.gd` como não versionado (`??`). Não há cópia no git, nos snapshots (`~/dev/sop-snapshots`), na lixeira nem nos logs do Claude, do Codex ou do Gemini (só listagens, nunca o conteúdo). O vizinho `captura_corrida.gd` (sprint do base_v2) sugere que era uma captura da animação de corrida a pé.

**Causa raiz:** escolhi um nome genérico para um arquivo novo sem conferir se ele já existia, numa pasta com centenas de scripts de captura não versionados de várias frentes. A escrita direta substitui o conteúdo sem perguntar.

**Correção:** o meu script virou `capturar_corrida_caranguejos.gd`; o nome antigo ficou livre para ser recriado. O conteúdo antigo está perdido; o dono foi avisado.

**Como detectar de novo:** antes de criar arquivo em `tools/dev_tests/` (ou qualquer pasta com arquivos fora do git), rodar `ls <caminho>*`; nome novo leva o assunto específico (ex.: `_caranguejos`), nunca só o tema genérico.

**Lição:** arquivo não versionado não tem desfazer. Conferir a existência ANTES de escrever, e tratar "atualizado" na resposta de uma escrita que devia ser nova como alarme na hora.

## 06/10/2026 — `get_meta(chave, null)` disparando erro a cada quadro (armadilha já conhecida, repetida)

**Sintoma:** a sonda de rede da Noro encheu o log com "The object does not have any 'meta' values with the key 'pose_de_skill'" a cada quadro, para todo jogador sem pose de skill. Os testes passavam porque o runner não reprova por `ERROR:`.

**Evidência:** backtrace `ProceduralAnimator.update (:670)` ← `Player._etapa_locomocao` ← `_physics_process`, centenas de linhas por processo em `net_kit_host_probe`/`net_kit_client_probe`. Depois da correção: 0 linhas com `pose_de_skill` nos dois logs e as conferências todas ✅.

**Causa raiz:** no Godot 4, `get_meta(nome, null)` não tem padrão: `null` como padrão equivale a não passar padrão, e o motor reclama quando a meta não existe. O projeto já tinha essa armadilha anotada em `src/effects/FxUtil.gd:313`, e eu a repeti ao ligar as poses do Builder no animador.

**Correção:** `has_meta` antes de `get_meta` em `ProceduralAnimator.gd`. A busca por `get_meta(..., null)` no código não acha outro caso.

**Lição:** antes de ler meta opcional, usar `has_meta`; nunca confiar em `null` como padrão. Ao fim de cada fatia, procurar `ERROR:` no log dos testes, não só os ✓.

## 06/10/2026 — feixe da Noro invisível visto de trás (câmera do jogador)

**Sintoma:** na foto lateral o feixe rosa aparecia inteiro; na câmera de ombro do jogador, que olha ao longo do feixe, ele quase sumia.

**Evidência:** `capturar_noro_noro.gd`, quadro "3_soltar": a vista lateral mostrava o tubo; na "3_soltar_jogo" só havia um traço fraco perto da mão. Com o piso no shader, a mesma foto mostra o feixe rosa até o boneco.

**Causa raiz:** o shader de brilho suave usava só o fresnel invertido (`pow(|N·V|, e)`) como alfa. Visto de ponta, a superfície do tubo fica quase paralela à visão, então N·V ≈ 0 e o alfa vai a zero na maior parte do tubo. Validar só pela vista lateral escondeu o defeito.

**Correção:** piso no brilho, `g = 0.3 + 0.7 * f`, usado no albedo e no alfa (`visual_de_skill.gd`).

**Lição:** efeito de fresnel precisa de piso quando a câmera pode olhar ao longo da forma. Sempre fotografar VFX também pela câmera real do jogo, não só por um ângulo bonito.

## 06/10/2026 — pose da skill do Builder apagada pelo clipe de corrida (Noro Noro)

**Sintoma:** no jogo, a pose "Soltar" da Noro Noro deixava o braço direito baixo. A prévia do Builder mostrava a pose certa.

**Evidência:** `test_noro_noro` mediu o UpperArm_R a 22° na pose "Soltar" (alvo ~90°). Depois da correção, a mesma medição dá carregar 15°, segurar 61°, soltar 89° e final 37°.

**Causa raiz:** o recuo da skill (movimento "Trás") faz o corpo andar, e o `ProceduralAnimator` toca o clipe Mixamo de corrida na parte de cima do corpo. A pose de skill era somada antes, mas o clipe de corrida reescrevia braços e tronco depois, porque o peso da pose (`_pose_skill_w`) não entrava na conta de `upper_free` (o que libera a parte de cima para o clipe).

**Correção:** `_pose_skill_w` passou a reduzir o `upper_free`: com pose de skill ativa, a parte de cima é da pose, como já acontece com golpes.

**Lição:** pose somada a um rig que tem várias camadas só vale se a camada de cima souber que ela existe. Medir o ângulo da junta no jogo, e não na prévia, é o que pega isso.

## 2026-10-06 — Citar no teste uma classe que pré-carrega o Player.gd quebra as classes de combate

**Sintoma:** `test_frutas_do_builder` travou até o timeout depois de "comer a comprada". O log mostrava "Identifier not found: FruitNet" no começo e, mais tarde, "Invalid call. Nonexistent function 'new' in base 'GDScript'" e "Cannot call method 'get' on a null value".
**Causa raiz:** o teste citava `CharacterMenu.new()`. O `CharacterMenu` pré-carrega o `Player.gd` (`PlayerScript`), então compilar o teste compila o Player ANTES de os autoloads (`FruitNet`, `GameFlow`) existirem. A compilação falha, e scripts dependentes (os atores do combate direcional) ficam marcados como quebrados. Quando o Modo História tenta criá-los, `new()` não existe e a função do teste para num `await` que nunca volta. É a mesma armadilha do `var p: Player` (registrada mais cedo), por outro caminho: qualquer classe que leve ao Player.
**Evidência:** com `load("res://src/ui/CharacterMenu.gd").new()` na hora de usar, o teste passa 22/22 sem nenhum erro de script.
**Descartado:** a fruta do Builder (as checagens de catálogo, compra e comer passavam; o defeito aparecia ao montar o combate da história).
**Correção:** `tools/dev_tests/test_frutas_do_builder.gd` carrega o `CharacterMenu` com `load()` no ponto de uso.
**Como detectar de novo:** "Nonexistent function 'new' in base 'GDScript'" num teste headless: procurar no topo do script de teste referências estáticas a classes que levam ao Player (Player, CharacterMenu, Hud…).

## 2026-10-06 — Laço de mira da auditoria desistia sem avisar e o retículo ficava no chão

**Sintoma:** em cada rodada da `test_frutas_acertam_npcs`, uma tecla diferente da Buki zerava só na vaca (V em 05/10, X e C em 06/10). Em outras rodadas a mesma tecla acertava.
**Causa raiz:** do teste. O laço `_mirar` tentava 14 vezes e saía calado se não convergisse. Contra o alvo mais baixo e perto (a vaca a 4 m), a câmera suavizada demora a assentar, e o laço desistia com o retículo no CHÃO a ~3 m (erro de 0,15–0,20 rad). A arma de tiro único (sniper, raio 0,16) vai do cano até esse ponto e passa ao lado da vaca. As de leque e rajada às vezes ainda raspavam, por isso parecia sorteio.
**Evidência:** sonda com o mesmo laço: nas posições 1 e 2 o raio bateu em "Mapa/baseplate" no ponto (−0,87; 0; −2,91) e (0,02; 0; −3,05); na posição 3, convergido (0,007 rad), bateu na vaca. Com 40 tentativas: Buki 14/4/14, 10/10/10, 19/9/19, 12/7/12, sem nenhum aviso de não convergência.
**Descartado:**
- máscara do raio de `mira.ponto_de_mira` (com mira certa ela pega a hurtbox da vaca, que é ponto válido nela);
- movimento da vaca (congelada, o C ainda zerou);
- o golpe da Buki.
**Correção:** `tools/dev_tests/test_frutas_acertam_npcs.gd` `_mirar`: 40 tentativas e aviso impresso quando não converge (o mesmo em `test_kit_do_builder_historia.gd`); a vaca fica congelada só enquanto a arma atira.
**Como detectar de novo:** "mira NÃO convergiu" na saída do teste; zero isolado em alvo baixo com arma de tiro único.

## 2026-10-06 — Fruta sem passiva herdava a velocidade e o pulo da fruta anterior

**Sintoma:** latente, achado ao ler `equip_fruit` para o Kit do Builder. Trocar de uma fruta com passiva (ex.: Pika ×1,25) para uma sem passiva deixava `speed_multiplier` e `jump_multiplier` como estavam.
**Causa raiz:** `equip_fruit` só escrevia os multiplicadores dentro do `if all_passives.has(fruit_id)`; não havia volta ao normal. Valia também para ficar sem fruta (`""`) depois de morrer.
**Evidência:** leitura do `Player.equip_fruit`: nenhum `speed_multiplier = 1.0` fora do ramo da passiva. O kit (sem passiva) herdaria o ×1,25 da Pika.
**Descartado:** `FruitPassiveSystem` (tem os dados certos; o buraco era a falta do reset).
**Correção:** `Player.gd` `equip_fruit`: `speed_multiplier = 1.0` e `jump_multiplier = 1.0` antes de aplicar a passiva da fruta nova.
**Como detectar de novo:** equipar Pika e depois o kit (ou nada) e ler `speed_multiplier`.

## 2026-10-06 — Teste com `var p: Player` não carrega e o Godot abre o jogo normal (trava até o timeout)

**Sintoma:** `test_kit_do_builder_historia` ficou rodando até o timeout de 600 s sem imprimir nenhuma checagem.
**Causa raiz:** tipar a variável do teste como `Player` faz o script de teste depender do `Player.gd` na compilação. Em `godot --script` os autoloads (`FruitNet`, `GameFlow`) ainda não viraram identificadores, então a compilação falha ("Identifier not found: FruitNet"). O teste não carrega, e o SceneTree segue com a cena principal do jogo, que não termina nunca.
**Evidência:** log com "Failed to load script ... test_kit_do_builder_historia.gd ... Compilation failed" seguido de "[Server] hospedando offline". Com `var p: Node3D` o teste roda (15/15).
**Descartado:** loop infinito no executor ou na ativação (nada do teste chegou a rodar).
**Correção:** `tools/dev_tests/test_kit_do_builder_historia.gd` usa `Node3D` e acessa o Player por propriedade/`get`, como os outros testes do projeto.
**Como detectar de novo:** teste que "trava" sem imprimir a 1ª linha: procurar "Failed to load script" no log. Nunca tipar `Player` em script de `--script`.

## 2026-10-06 — Soltar a tecla do kit atribuía uma ativação já liberada a variável tipada

**Sintoma:** "SCRIPT ERROR: Trying to assign invalid previously freed instance" ao soltar Z/X do Kit do Builder (11 vezes num teste).
**Causa raiz:** a ativação em modo "Pressionar" dispara e se libera sozinha no quadro seguinte (`queue_free`). Ao soltar a tecla, `cast_controller.soltar` fazia `var ativ: Node = _kit_ativacoes[slot]`. Atribuir nó liberado a variável TIPADA é erro antes de qualquer `is_instance_valid`. É a mesma armadilha já conhecida no projeto (árvore do TreeAndFruitGenerator, projéteis do executor).
**Evidência:** 11 erros no log de `test_kit_do_builder_historia`; depois de trocar para `Variant`, 0.
**Descartado:** o executor (já corrigido antes para a mesma armadilha nos projéteis).
**Correção:** `src/player/cast_controller.gd`, ramo do kit em `soltar` (e `abortar`): `var ativ: Variant`, `is_instance_valid` antes de usar.
**Como detectar de novo:** `grep "previously freed"` na saída dos testes; ler de dicionário/meta sempre em `Variant` e conferir antes de tipar.

## 2026-10-06 — Afirmei ao dono que a arena tinha "menu de frutas" sem conferir

**Sintoma:** na pergunta de como equipar o Kit do Builder, a opção recomendada dizia "na arena, pelo menu de frutas". O dono escolheu essa opção com base nisso.
**Causa raiz:** raciocínio furado meu. Presumi um seletor de frutas na arena por analogia com o Modo História (inventário N › FRUTAS) e com um comentário do Player ("Escolher QUAL fruta/estilo continua no menu do M"). Não abri o menu antes de citar. Na arena a fruta vem das árvores (`FruitNet.pickup`) e da tecla T (ciclo de teste); o menu do M escolhe personagem e estilo, não fruta.
**Evidência:** `CharacterMenu.gd` só tem `_on_pick(char_id)` e `_on_pick_style`; o único caminho de equipar na arena é `Main._on_collect` → `equip_fruit` e `_cycle_fruit` na tecla T.
**Descartado:** "menu do M escolhe fruta": o comentário era antigo; o menu tem as colunas PERSONAGENS e ESTILOS.
**Correção:** corrigi a premissa com o dono antes de implementar e perguntei de novo. Ele escolheu um botão no menu do M (`CharacterMenu._on_pick_kit` → `Player.pedir_kit_do_builder` → servidor → `FruitNet.pickup`).
**Como detectar de novo:** antes de citar uma tela numa opção para o dono, abrir o script dela (grep da função que faz o que digo que ela faz).

## 2026-10-06 — capturar_escala_animais.gd não compilava depois da mudança de assinatura de animar()

**Sintoma:** `tools/mapa_ilha/capturar_escala_animais.gd` dava "Too few arguments for animar(): expected 6, received 5".
**Causa raiz:** em 04/10, outra frente acrescentou `vel_correr` em `AnimadorDeAnimal.animar` e atualizou os chamadores do jogo, mas não esta ferramenta, que fica fora de `src/` e que o `test_compila` não cobre por inteiro.
**Evidência:** `--check-only` com 5 erros de parse; depois 0, e a captura gerou as 6 fotos (01_grandes … 06_chefes) com a tabela de alturas.
**Descartado:** nada mais quebrado na ferramenta.
**Correção:** `tools/mapa_ilha/capturar_escala_animais.gd` passa passeio e corrida da ficha, como `animal_da_ilha.gd`.
**Como detectar de novo:** `--check-only --script` nas ferramentas de `tools/` ao mudar assinatura pública.

## 2026-10-06 — Contêiner de golpes entrava na árvore um quadro depois: o 1º golpe nascia fora dela

**Sintoma:** "ERROR: Condition !is_inside_tree()" no Hiken (X da Mera) e na explosão dele. A Pika (`_mundo_pronto`) e a Goro já tinham contorno próprio para o mesmo problema.
**Causa raiz:** `Player._get_skills_container()` criava o `Skills_<jogador>` sob demanda com `add_child.call_deferred`, sem motivo registrado (vem de 21/08). No PRIMEIRO golpe da sessão, o efeito era adicionado a um nó ainda fora da árvore, e o `global_position` de tudo falhava. Na explosão do Hiken havia ainda um segundo erro, de ordem: posição global antes do `add_child`. No sol do V da Mera, a posição era dada no `_init`.
**Evidência:** backtrace apontando `_hiken (FireFX.gd)` no 1º disparo e `_init (FireFXGrande.gd:328)`; depois da correção, a auditoria da Mera rodou sem nenhum aviso, com o mesmo dano (6/31/31/78).
**Descartado:** a zona do Hiken (o dano já chegava: 31/31/31).
**Correção:**
- `Player.gd` `_get_skills_container`: adiciona no mesmo quadro, e deferido só se o pai ainda não estiver pronto;
- `FireFX.gd` `_hiken`: `add_child` antes da posição;
- `FireFXGrande.gd` `EnteiSunController`: posição inicial no `_ready`.
**Como detectar de novo:** `grep "is_inside_tree"` na saída de `SOP_FRUTAS=mera_mera test_frutas_acertam_npcs`.

## 2026-10-06 — Raio guiado do V da Pika empurrava o alvo para fora do próprio alcance

**Sintoma:** na primeira versão dos raios guiados (todo alvo a até 50 m), o boneco a 4 m parava em 35 de 94 de dano.
**Causa raiz:** erro meu de desenho. A zona do raio guiado nasce no centro do alvo e herdei o impulso de 8 m/s da chuva aleatória. A cada raio o alvo era arrastado para longe: em 4 s foi de 4 m para 59 m, saiu dos 50 m e parou de ser alvejado.
**Evidência:** sonda com log por segundo: posição z de −4,0 para −9,4, −19,3, −34,3, −54,0 e −59,0, com o dano parado em 35,2. Sem impulso: o boneco fica em −4,0 e chega a 93,75 (o teto 768 × 250/2048), e o de 60 m leva 0.
**Descartado:** fim prematuro do controlador (ctrl=true até 14 s) e teto global (o teto é por alvo, `CombatResolver._cobrar`).
**Correção:** `src/effects/PikaFXGrande.gd` `_raio_no_alvo`, com impulso 0 no raio guiado. A chuva aleatória mantém o empurrão a partir do ponto onde cai.
**Como detectar de novo:** dano que estaciona antes do teto em golpe de vários acertos: logar a posição do alvo, porque o impulso pode tirá-lo do alcance.

## 2026-10-06 — Shunshin (C da Goro) teleportava às cegas e matava no vazio

**Sintoma:** mirando um alvo próximo, o C da Goro jogava o jogador dentro do chão ("CAIU NO VOID! Morte instantânea"). Os golpes seguintes não saíam, porque a morte tira a fruta. O C também atravessava parede.
**Causa raiz:** `global_position += fwd × 12`, sem varrer o caminho. A mira para um alvo a 4 m desce ~11°, então o corpo ia 2,4 m para baixo do chão. Ficou assim porque o código estava marcado "NÃO MEXER" desde a repaginação da Goro; o dono liberou em 06/10.
**Evidência:** log da auditoria com "CAIU NO VOID" logo após o Shunshin; C 24/24/0 e V 0/0/0 em seguida. Depois: `test_goro_shunshin` 6/6 (rente ao chão Δy 0,00 m e 12,00 m; parada a 0,5 m da parede; no ar desce até y 0,83 com o chão em 0,80; tecla C real anda 12 m e mantém a fruta) e auditoria C 24/24/24.
**Descartado:** alcance da zona de dano (ela acerta da linha da mira; o problema era o corpo).
**Correção:** `src/effects/GoroFX.gd` `_teleportar`:
- `move_and_collide` com a cápsula do corpo;
- desliza em chão inclinado (normal.y ≥ 0,6) e para em parede ou corpo;
- de pé, descarta a parte da mira que aponta para baixo.
**Como detectar de novo:** `tools/dev_tests/test_goro_shunshin.gd`.

## 2026-10-05 — Auditoria: a metralhadora da Buki atirava onde a vaca ESTAVA

**Sintoma:** na bateria completa, `test_frutas_acertam_npcs` reprovou com "buki_buki/V→animal". Na rodada isolada anterior, a mesma tecla tinha acertado a vaca (3).
**Causa raiz:** do teste. O V da Buki segura 1,5 s para sacar a metralhadora antes do gatilho. O teste parava o bicho só antes de começar o golpe; a vaca voltava a passear (~1,2 m/s) e saía do retículo. Os tiros já miram certo, do cano até o ponto do retículo (`buki_controller.gd` `atirar`), então não havia paralaxe nem alvo ignorado.
**Evidência:** sonda com log a cada 5 quadros: estado=1 (andando), a vaca saindo de (0,6; −4,6) para (1,4; −5,5), o ângulo do retículo crescendo de 0,090 para 0,192 rad e dano 0. Com o ajuste, a auditoria da Buki e da Yami deu V 11/7/2.
**Descartado:** paralaxe (a bala sai do cano em direção ao ponto mirado) e filtro de alvo (Z, X e C da Buki acertavam a vaca).
**Correção:** `tools/dev_tests/test_frutas_acertam_npcs.gd`. Com arma sacada, o teste para o bicho, recoloca-o na raia e roda `_mirar` antes de apertar o gatilho, como o jogador faria.
**Como detectar de novo:** dano zero só em alvo que se mexe, com golpe que tem preparo longo: logar a posição do alvo e o ângulo do retículo durante o golpe.

## 2026-10-05 — Três artefatos da auditoria por raia (C da Pika, campos que vazam, C da Goro)

**Sintoma:** na `test_frutas_acertam_npcs`, o C da Pika e o V da Goro davam 0/0/0, o V da Hie passava do teto (160/120) e o C da Goro só acertava a primeira raia.
**Causa raiz:** o teste, não os golpes.
1. O C da Pika é de SEGURAR (`pika_c_active`: soltar encerra), e o teste soltava em 0,4 s, antes de a rajada começar (1,0 s).
2. O campo da Hie V (50 s, até 55 m) e a chuva da Pika V (44 m) continuavam ativos e alcançavam a raia seguinte, a 40 m: dois usos somados.
3. O C da Goro (Shunshin, `NÃO MEXER` por decisão do dono) teleporta 12 m pela mira. Mirando um alvo próximo, a mira desce ~11°, o corpo vai 2,4 m para baixo do chão e morre no vazio ("CAIU NO VOID"). Depois do respawn, os golpes seguintes não saíam, e por isso o V da Goro dava 0/0/0.
**Evidência:**
- sonda isolada: C da Pika segurado 2,7 s = 46,9 (teto 384 × 0,122);
- V da Goro isolado = 93,75;
- V da Hie isolado = 93,75;
- log da auditoria com "CAIU NO VOID" logo após o Shunshin.
**Descartado:** filtro de alvo e escala de dano. Isolados, os três golpes acertam e respeitam o teto.
**Correção:** `tools/dev_tests/test_frutas_acertam_npcs.gd`:
- `SEGURAR` (C da Pika, 170 quadros);
- `clear_spawned_skills` depois de cada medida;
- a Goro usa o C por último;
- `EXCECOES` impressas com motivo para o C da Goro (congelado pelo dono) e o V da Pika (chuva aleatória: ~25 % de acertar um alvo de 0,5 m por uso).
**Como detectar de novo:** zero em todas as raias ou dano acima do teto escalado: rodar a sonda de um golpe só antes de mexer no golpe.

## 2026-10-05 — Campo do V da Hie ignorava o inimigo do mapa (corpo estático)

**Sintoma:** o inimigo do mapa levava só o impacto do V da Hie (31). O boneco e a vaca levavam o campo inteiro.
**Causa raiz:** o tique do campo (0,2 s por 50 s) pulava quem não era `CharacterBody3D`. O inimigo do mapa do Modo História é `StaticBody3D`. O próprio `_congelar_alvo`, logo abaixo, já usava o critério certo de combatente: `has_method("take_damage")`.
**Evidência:** auditoria Hie V com 31 no inimigo contra 94 (teto 768 × 0,122) no boneco num uso isolado.
**Descartado:** escala/teto: os 160 e 120 vistos antes eram o campo da raia anterior (50 s, até 55 m) somando outro uso na raia a 40 m; isolado, o V para em 93,75.
**Correção:** `src/effects/IceFX.gd:363`. O filtro passa a ser `take_damage`; o cenário continua de fora.
**Como detectar de novo:** `SOP_FRUTAS=hie_hie` no `test_frutas_acertam_npcs.gd`.

## 2026-10-05 — Agarrão da investida da Gura passava por cima de bicho baixo

**Sintoma:** o Z da Gura acertava o inimigo e o boneco e zerava na vaca (12/12/0).
**Causa raiz:** o soco do Z só sai quando a esfera de detecção da investida (raio 1,2 m) encontra alguém. Ela ficava em `global_position + UP×1,0 + dir×1,5`. A origem do jogador já é o centro do corpo; com a Gura em escala 2 (centro a 1,6 m), a esfera ia de 1,4 a 3,8 m de altura. A vaca tem ~1,4 m: o corpo encostava nela, o tempo da investida acabava e nenhuma zona de dano nascia.
**Evidência:** sonda quadro a quadro: o jogador parou em z=−2,7 encostado na vaca (z=−4), sem nenhuma DamageZone durante 40 quadros, dano 0. Depois: 11,7 (96 × 0,122).
**Descartado:** direção da investida (o corpo chegava na vaca) e filtro de alvo (a vaca tem `take_damage`).
**Correção:** `Player.gd:4120`. A esfera fica no centro do corpo (`global_position + dir×1,5`).
**Como detectar de novo:** `SOP_FRUTAS=gura_gura` no `test_frutas_acertam_npcs.gd`; o Z tem de acertar a vaca.

## 2026-10-05 — Leque do Z da Pika saía da mão paralelo à mira de ombro

**Sintoma:** o Yasakani (Z da Pika) errava o inimigo a 4 m e raspava os outros: 0/2/3.
**Causa raiz:** cada raio sai de `caster + UP×1,25` (a mão), mas o centro do leque era `fwd`, a direção da mira, que sai da linha da câmera de ombro (~0,5 m de lado). O leque de ±0,17 rad corria paralelo ao retículo, deslocado.
**Evidência:** auditoria Z 0/2/3 antes; sonda contra o boneco depois: 3,4 de dano (2 raios de 1,7).
**Descartado:** alvo fora do grupo (os outros golpes da Pika acertam o inimigo) e o espalhamento do leque (o problema era o centro, não a abertura).
**Correção:** `src/effects/PikaFX.gd:209`. `_yasakani` calcula o ponto do retículo (`AlvosDeGolpe.ponto_mirado` da origem da mira, até 40 m) e `_disparar_um` abre o leque em torno de `ponto − mão`.
**Como detectar de novo:** `SOP_FRUTAS=pika_pika` no `test_frutas_acertam_npcs.gd`.

## 2026-10-05 — Sol do V da Mera voava paralelo à mira, 8 m acima, e explodia longe do alvo

**Sintoma:** o Entei (V da Mera) zerava no inimigo e no boneco a 4 m (0/0/62). Só a vaca às vezes levava dano.
**Causa raiz:** o sol nasce em `caster + UP×(7,5+escala) + dir×1,5` e voa em `dir`, a mira da câmera de ombro. Paralelo à linha do retículo e 8 m acima, ele passa por cima de quem está marcado e só desce até y≤0,9 uns 20 m adiante, fora dos 15 m da explosão. É a mesma paralaxe da Bara e da Gomu: golpe que nasce longe da linha da câmera precisa mirar o PONTO do retículo, não a direção.
**Evidência:** auditoria V da Mera 0/0/62 antes, 78/78/78 depois (o teto 640 × 0,122).
**Descartado:** filtro de alvo (o X e o C da Mera acertavam os três) e dano/teto (a explosão aplica o valor da carga).
**Correção:** `src/effects/FireFXGrande.gd:460` (`_rumo_ao_reticulo`, chamado em `shoot`). O sol procura o ponto com `AlvosDeGolpe.ponto_mirado` a partir da origem da mira (a linha da câmera, guardada em `_init`), até 60 m, e voa até lá.
**Como detectar de novo:** `SOP_FRUTAS=mera_mera` no `test_frutas_acertam_npcs.gd`.

## 2026-10-05 — Pinça do X da Bara fechava no fim do alcance e passava ao lado do alvo

**Sintoma:** o dono relatou que o X da Bara não funcionava. Mesmo com o Z e o V já corrigidos (mão mirando o ponto do retículo), o X acertava o inimigo largo e zerava no boneco e na vaca: 21/0/0.
**Causa raiz:** as duas mãos fazem um arco lateral `sin(t·π) × 1,2 m` e só se encontram em t=1, no alcance cheio de 6 m. Um alvo a 4 m fica em t≈0,67, onde cada mão está ~1,04 m para o lado. Alvo de 0,5 m passa entre as duas; só o capitão pirata, mais largo, encostava.
**Evidência:** `test_frutas_acertam_npcs` com SOP_FRUTAS=bara_bara: X 21/0/0 antes, 21/21/21 depois. Z, C e V seguiram 11/11/11, 29/29/29 e 70/70/70.
**Descartado:** mira/paralaxe (já corrigida: o Z e o V acertavam os três com a mesma mira) e alvo fora do grupo de golpe (o C e o V acertavam o mesmo boneco).
**Correção:** `src/combat/BaraController.gd:179`. Mão em curva com algo marcado pelo retículo usa alcance = distância até o ponto + 0,3 m (no máximo o alcance). A pinça fecha no alvo; sem alvo, segue fechando aos 6 m.
**Como detectar de novo:** `SOP_FRUTAS=bara_bara` no `tools/dev_tests/test_frutas_acertam_npcs.gd`; o X tem de acertar os três.

## 2026-10-05 — Mira do Modo História acertava a HURTBOX do próprio jogador (corpo grande da Gura)

**Sintoma:** com a Gura comida (corpo em escala 2), a câmera apontava exatamente para o boneco (erro < 0,01 rad) e a mira saía para (5,4; 0; −16,2), longe dele; os golpes iam tortos.
**Causa raiz:** `Player.mira_do_cast` lança o raio do retículo com a máscara padrão (todas as camadas) e exclui só o corpo do jogador. No Modo História o jogador tem uma `HurtboxDeCombate` — OUTRO corpo, na camada 21. Com o corpo dobrado, a câmera alta cruza essa hurtbox: o retículo "acertava" o próprio jogador.
**Evidência:** depois de tirar a camada das hurtboxes da máscara, o ponto do retículo cai em (0,3; 1,3; −3,6), no boneco, e a investida da Gura tira 11,7.
**Descartado:** suavização da câmera (o laço de mira convergiu); a paralaxe (já corrigida e ainda errava).
**Correção:** `mira_do_cast` com `collision_mask = ~HurtboxDeCombate.CAMADA` (na arena não há hurtbox: sem efeito lá).
**Como detectar de novo:** `test_frutas_acertam_npcs` (Gura); raio de mira de jogador = excluir as hurtboxes de combate.

## 2026-10-05 — Braço da Gomu e investidas (Gura Z, Bomu Z) andavam paralelos ao retículo

**Sintoma:** a Gomu Z batia no chão antes do inimigo do mapa; a investida da Gura passava ~1,7 m ao lado do boneco (só acertava o inimigo largo).
**Causa raiz:** mesma da mão da Bara: a direção vem da linha da câmera de ombro (`mira_do_cast`), e o golpe sai do OMBRO (Gomu) ou do CORPO (investidas). Com a direção da câmera, a trajetória é paralela à do retículo, deslocada e inclinada.
**Evidência:** sonda: zona da Gomu só tocou "baseplate"; velocidade da investida (6,6; 0; −15,5) com o boneco reto à frente. Depois: Gomu Z 10,7 no inimigo; investida 11,7 no boneco.
**Descartado:** alcance do braço (12 m), raio da esfera da investida (1,2 m).
**Correção:** `AlvosDeGolpe.ponto_mirado` (o ponto que o retículo marca); `GomuFX.cast` mira o braço até ele; `Player.rumo_ao_ponto_mirado` nas investidas da Gura e da Bomu; a Bara usa o mesmo ajudante.
**Como detectar de novo:** `test_frutas_acertam_npcs`; golpe novo que sai do corpo = mirar o ponto, não a direção.

## 2026-10-05 — tools/mapa_ilha/capturar_escala_animais.gd não compila mais (assinatura de animar mudou)

**Sintoma:** no `test_compila`, erro de parse em `capturar_escala_animais.gd:112`: "Too few arguments for animar() call. Expected at least 6 but received 5".
**Causa raiz:** `src/historia/animais/animador_de_animal.gd` (alterado em 04/10 22:03, outra frente) ganhou um parâmetro em `animar`; a ferramenta de captura (de 01/10) ficou com a chamada antiga.
**Evidência:** datas dos arquivos; mensagem do parser com a linha.
**Descartado:** mudanças desta rodada (não toquei no animador nem na ferramenta).
**Correção:** nenhuma — ferramenta de outra frente; avisar o dono.
**Como detectar de novo:** `test_compila` imprime o parse error (o contador não pega porque a ferramenta não é instanciável).

## 2026-10-05 — Medir golpe em NPC: cinco armadilhas do próprio teste

**Sintoma:** a auditoria das frutas × NPCs dava resultados que mudavam entre rodadas e colunas inteiras zeradas sem defeito no jogo.
**Causa raiz:** erros MEUS na medição: (1) a câmera SUAVIZA o giro — 2 quadros não bastam para o retículo assentar no alvo; (2) a física da vaca desligada deixava a vaca flutuando e tirava efeitos que dependem de física; ligada, a vaca FUGIA depois do 1º acerto e saía da raia; (3) a Gura V MATOU a vaca (dano real) e repor só a vida não a revive (colisão e grupo ficam desligados); (4) guardar a arma da Buki põe recarga no SERVIDOR e o saque da raia seguinte era recusado — só o primeiro alvo levava tiro; (5) no teste do editor, cliquei na alça do meio da borda (redimensiona) achando que arrastava a janela.
**Evidência:** sondas: vaca viva leva 11 da Suna e foge 8 m; vaca "morta" com camada 0 e sem grupo; `servidor_sacar` recusando por "slot quente"; retículo a 0,31–0,55 m do centro com 2 quadros.
**Descartado:** defeitos no jogo para essas colunas (com o teste corrigido elas acertam).
**Correção:** `test_frutas_acertam_npcs`: mira repete até assentar, animal via `reviver` a cada golpe, inimigo `_renascer`, `esquecer_recargas_do_servidor`, uma 2ª chance para alvo isolado em zero; `test_editor_de_janelas` clica fora das alças.
**Como detectar de novo:** coluna inteira zerada ou resultado que muda entre rodadas = desconfiar do teste antes do jogo; imprimir estado do alvo (`SOP_DEPURAR=1`).

## 2026-10-05 — Editor de janelas: SubViewportContainer com stretch redimensionou a TELA do jogo

**Sintoma:** na foto com GPU, a janela aparecia em tamanho real, cortada e deslocada, e a moldura de seleção não batia com o desenho; o teste sem tela passava.
**Causa raiz:** `SubViewportContainer.stretch = true` faz o SubViewport ter o tamanho do container (718×404), sobrescrevendo os 1280×720. As janelas se ancoram numa raiz de 1280×720 dentro de uma tela menor: aparece o canto, em escala 1:1, enquanto a seleção usava a escala 718/1280.
**Evidência:** foto antes (janela gigante, seleção em outro lugar) e depois (janela reduzida e seleção exata); o teste agora confere tela 1280×720 e imagem 16:9.
**Descartado:** conta de escala do canvas (estava certa para a imagem que deveria aparecer).
**Correção:** `src/editor_mapa/editor_de_janelas.gd` — SubViewport fixo de 1280×720 (fora de container) e um TextureRect com a imagem dele reduzida.
**Como detectar de novo:** `test_editor_de_janelas` ("a tela do jogo fica em 1280×720 e aparece REDUZIDA") + `capturar_editor_de_janelas.gd`.

## 2026-10-05 — Golpes que procuram alvo por grupo ignoravam o animal manso (e o pé como "centro")

**Sintoma:** Ope C/V, Kurouzu, vaga-lumes e mergulho da Pika, mão da Bara, mira de arma e alvo do corpo a corpo não pegavam o animal manso; a Ope C/V também não pegava animal nenhum.
**Causa raiz:** (1) o código das frutas procura alvo nos grupos "player"/"enemy"; o animal manso não é "enemy" (esse grupo manda o pet em guarda atacar e a visão do E destacar). (2) `OpeController.pick_target` traçava linha livre até `global_position` do candidato — no animal isso é o PÉ, e o raio batia na plataforma antes.
**Evidência:** vaca parada, viva e no grupo novo seguia de fora da Ope C/V até a escolha usar o centro do corpo; o boneco e o inimigo (origem no centro) já passavam.
**Descartado:** física desligada no alvo (a vaca viva também falhava), cooldown da ROOM.
**Correção:** grupo "alvo_de_golpe" + `AlvosDeGolpe.todos/npcs/e_alvo/centro` (src/combat/alvos_de_golpe.gd) nos pontos de busca das frutas; animal, inimigo do mapa e boneco entram no grupo; `AnimalDaIlha.centro_do_corpo`.
**Como detectar de novo:** `test_frutas_acertam_npcs`.

## 2026-10-05 — Bara Bara: Z, X e V nunca acertavam ninguém (a mão seguia uma reta paralela à mira)

**Sintoma:** o dono reportou que o Z, o X e o V da Bara não funcionavam no Modo História; a auditoria mediu 0 de dano em todos os alvos (o C, canhão, acertava).
**Causa raiz:** `BaraController._launch` mandava a mão para "corpo + mira × alcance". A mira (`mira_do_cast`) sai da linha da CÂMERA de ombro, deslocada do corpo; somada ao corpo ela vira uma reta paralela que passava ~1,2 m ao lado do alvo e mergulhava até 0,3 m do chão. Vale também na arena.
**Evidência:** sonda quadro a quadro: mão em (1,3; 0,3; −3,6) com o boneco em (0; 0,8; −4); depois de mirar cada mão do PRÓPRIO encaixe para o ponto do retículo, a mão vai reto a (0,2; 0,9; −3,5) e o Z tira 11.
**Descartado:** cancelamento do golpe (`is_casting` ficava true), energia, linha de visão da zona, uma primeira correção que só trocava a origem (a mão ainda partia do encaixe e divergia).
**Correção:** `_ponto_mirado` (primeiro corpo na linha da mira até o alcance) e cada mão vai do encaixe até ele e segue até o alcance.
**Como detectar de novo:** `test_frutas_acertam_npcs` (coluna da Bara).

## 2026-10-05 — Inimigo do mapa (colisão de malha OCA) escapava dos golpes de área das frutas

**Sintoma:** na auditoria das frutas da arena × NPCs da história, o inimigo do mapa (peça da loja, corpo estático) não levava dano de Gomu X/C, Gura Z/C/V, Mera Z/X, Bomu, Goro, Hie Z, Pika V — boneco e animal levavam.
**Causa raiz:** a colisão do modelo é uma ConcavePolygonShape3D (triângulos, oca). Uma Area3D (zona de golpe) que ENVOLVE o modelo inteiro ou nasce DENTRO dele não cruza triângulo nenhum, então não detecta o corpo; só a zona que encosta na superfície detecta. Os golpes de área quase sempre envolvem um alvo de 1,9 m.
**Evidência:** sonda com caixa em malha de triângulos: esfera encostando na superfície → vê; envolvendo → não vê; dentro → não vê. Com o núcleo sólido, Gomu X/C, Mera X/C, Bomu, Goro X e Buki passaram a acertar o inimigo.
**Descartado:** Jolt e "areas_detect_static_bodies" (o motor é o Godot Physics e a área vê corpo estático com caixa); máscara/camada (zona 1, peça 1).
**Correção:** `InimigoDoMapa.criar_nucleo_solido` — caixa sólida a 80 % da AABB da malha, dentro dela (não muda o contorno que o jogador toca).
**Como detectar de novo:** `tools/dev_tests/test_frutas_acertam_npcs.gd`; todo alvo com colisão de malha precisa de um volume sólido para as zonas.

## 2026-10-03 — Teste dos NPCs mediu "pés enterrados" contando malhas ESCONDIDAS

**Sintoma:** domador e vendedor reprovaram "pés no chão" (y −0,51); o pescador passava.
**Causa raiz:** erro MEU no teste: o ponto mais baixo somava toda `MeshInstance3D`, inclusive as armas escondidas que o `PlayerRig` pendura nas mãos (Buki, pistolas). Com o braço caído elas descem abaixo do chão; o pescador passava porque o braço da vara fica levantado.
**Evidência:** só com `is_visible_in_tree()` os três medem −0,02.
**Descartado:** a origem do NPC (já corrigida para o centro do corpo).
**Correção:** `tools/dev_tests/test_npcs_e_lojas.gd` mede só malhas visíveis (como o `test_ilha_inicial`).
**Como detectar de novo:** medida de corpo = sempre só o que se vê.

## 2026-10-03 — "gomu_gomu_gear2" aparecia como fruta à venda

**Sintoma:** o teste das lojas contou 14 frutas da arena, não 13.
**Causa raiz:** `SkillSystem.get_fruit_skills()` tem uma chave por KIT, e o Gear 2 da Gomu é um kit próprio (`gomu_gomu_gear2`) — é uma forma da Gomu, não uma fruta.
**Evidência:** lista impressa: [..., "gomu_gomu", "gomu_gomu_gear2", ...].
**Descartado:** —
**Correção:** `PerfilDeFrutas.frutas_da_arena` pula id que começa com outro id + "_" (forma de outra fruta).
**Como detectar de novo:** `test_npcs_e_lojas` exige 13 e sem "gomu_gomu_gear2".

## 2026-10-03 — Achado na arena: Mamaragan (V da Goro) cobra o custo DUAS vezes

**Sintoma:** na história o V da Goro esvaziava os 10 de energia (ficha 5).
**Causa raiz:** o V da Goro paga na carga e de novo ao soltar — na arena isso é 360 em vez de 180. Não é da adaptação: o kit veio fiel e escalado.
**Evidência:** linha do tempo da energia: 10,00 durante a carga → 0,02 ao soltar; recarga não aparece na janela de 2,5 s.
**Descartado:** escala da história, regeneração.
**Correção:** nenhuma (é o kit da arena, fora do pedido); o teste aceita 2× nesse golpe com GATILHO para tirar quando a arena for consertada.
**Como detectar de novo:** `test_frutas_na_historia` (`_vezes`).

## 2026-10-03 — Recarga "da tabela" (SkillSystem) não é a que a arena aplica

**Sintoma:** a ficha da história gerada da arena mostraria V = 60 s para a maioria das frutas.
**Causa raiz:** `SkillSystem.get_slot_cooldown` tem V 60 por padrão, mas o `Player.trigger_skill_cooldown` aplica a tabela fixa por tecla (V 25) para todas menos Ope/Bara/Rocket, e 10 s para Bomu e Suke. Duas fontes para o mesmo número.
**Evidência:** comparação no teste (toda fruta × tecla, `trigger_skill_cooldown` sem ficha): só bate depois da função única.
**Descartado:** —
**Correção:** `SkillSystem.recarga_da_arena` (a regra que o Player aplica) alimenta a ficha; na história o Player aplica a recarga da ficha. Comentário de GATILHO nas duas pontas.
**Como detectar de novo:** `test_frutas_na_historia` ("a recarga da ficha é a que a arena aplica").

## 2026-10-03 — Trocar de fruta invisível (Suke) deixava a camuflagem e o dreno correndo

**Sintoma:** no teste das frutas da arena, a Bara (testada logo depois da Suke) parecia cobrar ~1,8 de energia a mais em toda tecla.
**Causa raiz:** `equip_fruit` desliga o Gear 2 ao trocar de fruta, mas não a invisibilidade da Suke: `_invisivel` seguia true e o dreno por segundo continuava com a fruta nova. Vale na arena também (troca pelo T).
**Evidência:** sobra de 0,6/s × ~2,9 s ≈ 1,77 em cada tecla da Bara; sonda da Bara sozinha: 10 → 8 (custo 2 certo). Com a correção, a Bara passa com o custo da ficha.
**Descartado:** cobrança dupla no caminho da Bara (só `BaraNetwork.authorize` cobra).
**Correção:** `Player.equip_fruit` chama `revelar_invisibilidade()` ao trocar para outra fruta.
**Como detectar de novo:** `test_frutas_na_historia` (frutas em sequência, maior queda de energia por tecla).

## 2026-10-03 — Frutas da arena travadas no Modo História: energia de 180 cobrada direto em 13 lugares

**Sintoma:** na história (energia 10) a Ope recusava tudo ("Energia insuficiente."), o Gura Z e a rajada da Mera/Hie zeravam a energia, a invisibilidade da Suke esvaziava tudo na hora.
**Causa raiz:** além do caminho principal (que já usava `custo_de_energia_do_cast`), o custo da arena estava escrito direto: `cast_controller` (Ope, Pika C, carga, Gomu C, soltura), `BaraNetwork` (pedido, autorização, cobrança), `Player` (investida da Gura, servidor da Ope, `_net_play_cast`), a bala da rajada (`ENERGY_BULLET` 10) e o dreno da invisibilidade (55/s). MEU erro no caminho: a primeira busca por `ENERGY_SKILL` foi cortada por `| head` e deixou o Player.gd de fora — achei o resto só quando o teste mostrou "Energia insuficiente".
**Evidência:** sonda: Ope Z com energia 10/10 → `ope_feedback = "Energia insuficiente."`; depois da troca, `test_frutas_na_historia` 45/45 (as 13 frutas lançam todas as teclas com 2–5 de energia).
**Descartado:** `can_use_skills` (a história usa `can_use_fruit`), recarga, trava pós-fruta.
**Correção:** todos os pontos passam por `custo_de_energia_do_cast(slot)`; bala e dreno por `Player.energia_do_modo` (proporção da ficha) e `dreno_da_invisibilidade` (soma a regeneração da história). Na arena todos devolvem os números de antes.
**Como detectar de novo:** `test_frutas_na_historia`; `grep -n ENERGY_SKILL` SEM `head` antes de dizer que um custo passa todo pelo ajudante.

## 2026-10-03 — Janela de loja nasceu com 1.640 px de altura (cabeçalho fora da tela)

**Sintoma:** na foto, a loja do pescador era um painel escuro vazio da altura da tela inteira.
**Causa raiz:** o rótulo da fala do NPC tinha `autowrap` e `SIZE_EXPAND_FILL` dentro de um HBox, sem largura mínima. No primeiro layout a largura dele é 0, a quebra acontece letra por letra e a altura mínima explode; o `set_anchors_and_offsets_preset(CENTER, MINSIZE)` centralizou com esse tamanho inflado.
**Evidência:** janela P(497, −460) S(620, 1640) com min 493; com `custom_minimum_size.x` no rótulo, S(620, 493) e dentro da tela.
**Descartado:** a `ScrollContainer` (a lista media 122 px).
**Correção:** `src/ui/JanelaDeLoja.gd` (largura mínima na fala + recentralizar no quadro seguinte); o mesmo padrão corrigido no rótulo de vazio do `InventarioDaHistoria`.
**Como detectar de novo:** rótulo com `autowrap` dentro de container SEMPRE com `custom_minimum_size.x`; foto com GPU de toda janela nova.

## 2026-10-03 — HUD de técnicas da fruta (Modo História) estava FORA da tela desde 22/09

**Sintoma:** na foto com GPU, com a Rocket ativa, o menu de técnicas não aparecia; o `test_fruta_rocket_historia` passava porque só lia o texto das linhas.
**Causa raiz:** `TecnicasHud._montar` fazia `set_anchors_preset(BOTTOM_LEFT)` e depois `position = (20, -altura - 20)`. No Godot 4 `position` é no espaço do PAI (a CanvasLayer), não relativo à âncora: y negativo põe o painel ACIMA do topo da tela.
**Evidência:** `get_global_rect()` = P(20, −170) S(300, 150) com viewport 1280×720; depois da correção, P(20, 1110) na tela de teste e visível na foto.
**Descartado:** `visible` (era true), cor/transparência, ordem dos filhos da HUD.
**Correção:** `src/ui/TecnicasHud.gd` usa `offset_left/right/top/bottom` a partir da âncora inferior esquerda.
**Como detectar de novo:** `test_barra_de_itens` confere que o retângulo do menu cabe na tela (`Rect2.encloses`); HUD nova = checar retângulo, não só texto.

## 2026-10-03 — test_pomar_e_doma quebrou: o cavalo da vila agora vira pet ao carregar o mapa (teste espera 2 pets)

**Sintoma:** na bateria completa, "tentativa que falha gasta 1 fruta e não doma" falhou com o aviso certo ("…não confiou em você · 0% por fruta").
**Causa raiz:** `companhia.gd` (alterado 03/10 15:42, frente do Codex) passou a entregar o cavalo da vila do mapa como pet do jogador (`progressao.receber_pet_do_mapa`). O teste conta `prog.pets.size() == 2` (gaivota + caranguejo iniciais) — expectativa fixa que ficou velha. A doma em si funciona: a maçã é gasta e nenhum pet novo entra.
**Evidência:** cópia instrumentada do teste: antes `macas=30 pets=[gaivota, caranguejo, cavalo_da_vila_leve_1]`, depois `macas=29` e os mesmos 3 pets.
**Descartado:** pesca/barra de itens (a fruta na mão só é guardada com a vara ATIVA, e aqui não há vara); `_tentar_domar` (gastou 1 fruta e não adotou, como deve).
**Correção:** nenhuma ainda — teste da frente de pets/montarias; o certo é comparar com a contagem de ANTES da tentativa em vez do número fixo 2. Fica para quem dona a frente (ou o dono decidir).
**Como detectar de novo:** `test_pomar_e_doma` na bateria; em teste, nunca fixar a contagem de uma coleção que outras frentes alimentam — medir a diferença.

## 2026-10-03 — "x == [..] as Array[String] and ..." não compila: o `as` pega a expressão inteira

**Sintoma:** `test_pesca` não carregava: "Invalid cast. Cannot convert from bool to Array[String]".
**Causa raiz:** em GDScript o `as` tem precedência MENOR que `and`/`==`; `a == ["luta"] as Array[String] and b` vira `(a == ["luta"] and b) as Array[String]`, um cast de bool.
**Evidência:** a mensagem do parser cita bool → Array[String]; com parênteses `(["luta"] as Array[String])` compila e o teste roda.
**Descartado:** tipo do retorno de `itens()` (é `Array[String]` mesmo).
**Correção:** `tools/dev_tests/test_pesca.gd` e `test_barra_de_itens.gd` com o cast entre parênteses.
**Como detectar de novo:** todo `as` dentro de condição composta vai entre parênteses.

## 2026-10-03 — Script novo citava LocomocaoChao, que não tem class_name

**Sintoma:** `test_compila` passou de 6 para 7: `pescaria.gd` com "Identifier LocomocaoChao not declared in the current scope".
**Causa raiz:** `src/player/locomocao_chao.gd` não declara `class_name`; o `Player` o usa por `preload`. Supus que era global porque o nome aparece no Player como se fosse classe.
**Evidência:** `grep class_name src/player/locomocao_chao.gd` vazio; `test_compila` voltou a 6 depois da troca.
**Descartado:** cache de classes desatualizado (o `--import` já tinha rodado).
**Correção:** `src/historia/pesca/pescaria.gd` faz a mesma conta (`atan2(-x, -z)`, frente = −Z) com comentário apontando a origem.
**Como detectar de novo:** `test_compila` depois de todo script novo; antes de citar uma classe do Player, `grep -n "class_name" <arquivo>`.

## 2026-10-03 — Pintura do pescador pegava também as armas escondidas do rig

**Sintoma:** sonda das malhas do NPC listou a `BukiSniper` pintada de amarelo-capa.
**Causa raiz:** `PescadorDaIlha.tingir` pintava TODA `MeshInstance3D` debaixo do modelo; o `PlayerRig` pendura no modelo as pistolas da Mera e o arsenal da Buki (escondidos). Invisível hoje, mas qualquer arma que aparecesse sairia com a cor do casaco.
**Evidência:** `BukiSniper s0=(0.68, 0.53, 0.13)` (amarelo × fator de escuro) na sonda; as malhas do corpo se chamam todas `Geo_*_Runtime` (88 no .glb de origem).
**Descartado:** —
**Correção:** `src/historia/npcs/pescador_da_ilha.gd` `tingir` só pinta malhas cujo nome começa com `Geo_` (vale para o rig do jogo e para o .glb da loja).
**Como detectar de novo:** listar as malhas e cores do NPC montado (sonda) — nada fora de `Geo_*` pode ter a cor da capa.

## 2026-10-03 — Pesca: na mordida a boia não afundava (estado MORDENDO não mexia na boia)

**Sintoma:** ao escrever o teste da mordida percebi que a checagem só passava com um `or true` — a boia continuava boiando na janela de clique.
**Causa raiz:** o ramo `MORDENDO` de `Pescaria._physics_process` só tratava clique e tempo; quem posiciona a boia era o `_esperar` (estado anterior), então ela ficava parada na última posição da espera. A leitura principal da pesca ("a boia afunda → clique") não existia.
**Evidência:** depois da correção, `test_pesca` mede a boia 0,17 m abaixo da superfície durante a mordida (antes ficava a ~0,01 m).
**Descartado:** —
**Correção:** `src/historia/pesca/pescaria.gd`, ramo `Estado.MORDENDO`: boia a 0,18 m sob a superfície, tremendo, enquanto a janela dura.
**Como detectar de novo:** `test_pesca` "a mordida afunda a boia". E nunca deixar `or true` num `_ok`: teste vazio esconde exatamente o que deveria provar.

## 2026-10-03 — Teste da pesca acusou "corpo não vira para a boia" (0,76): base do modelo escalado sem normalizar

**Sintoma:** `test_pesca` falhou em "o corpo vira para a boia" com produto escalar 0,76 (≈40° de erro aparente).
**Causa raiz:** erro MEU no teste: medi a frente como `-modelo.global_basis.z` sem `orthonormalized()`. O `PlayerRig` escala o modelo (~0,76) para caber no corpo, então o vetor tinha comprimento 0,76 e o produto escalar com uma direção unitária nunca passaria de 0,76 — mesmo com o corpo virado certo.
**Evidência:** sonda quadro a quadro: `rotation.y` do modelo convergiu para −1,5708 (exatamente o yaw pedido pela meta `frente_forcada`) em 10 quadros; com `orthonormalized()` o teste mede 1,00.
**Descartado:** ordem dos ramos da frente no `Player._etapa_locomocao` (o ramo novo rodava), `_em_combate` e `combate_direcional.ocupado()` (ambos falsos).
**Correção:** `tools/dev_tests/test_pesca.gd` normaliza a base antes de comparar direções.
**Como detectar de novo:** produto escalar "redondo" igual à escala do modelo (0,76) é sinal de vetor não unitário; medir direções sempre com base normalizada.

## 2026-10-03 — Pescador (NPC) nascia enterrado 0,8 m: PlayerRig supõe a origem do dono no CENTRO do corpo

**Sintoma:** na foto do pescador, o corpo amarelo parecia deitado/agachado — as pernas estavam abaixo do chão.
**Causa raiz:** o `PlayerRig` (`_fit_model_to_body`) assenta os pés meia altura do colisor do jogador (0,8 m) ABAIXO da origem do dono, porque no `Player` e no `BonecoDeDuelo` a origem é o centro da cápsula (o ninho põe o boneco em `UP * (COLISOR.y/2 + 0,05)`). Eu pus a origem do NPC no chão da peça (`NinhoDeInimigo.pe_da_peca`) e montei o rig direto nele.
**Evidência:** ponto mais baixo das malhas do NPC em y = −0,82 com a origem no chão; −0,02 depois da correção (`test_npc_pescador`, "pés no chão").
**Descartado:** escala do modelo (o fit normaliza certo) e a altura da peça no mapa (a origem do NPC estava exatamente em (5, 0, 3)).
**Correção:** `src/historia/npcs/pescador_da_ilha.gd` — o rig vive num nó `Corpo` a `CENTRO_DO_CORPO = 0.8` acima da origem (chão); a meta de pose vai no `Corpo` (é o pai do animador).
**Como detectar de novo:** `test_npc_pescador.gd` mede o Y mais baixo das malhas (|y − chão| < 0,12); com `CENTRO_DO_CORPO = 0` ele falha (conferido). Todo dono novo de `PlayerRig` precisa ter a origem no centro do corpo ou um nó intermediário.

## 2026-10-03 — Função com corpo vazio depois de remover a única linha dela

**Sintoma:** `test_compila` acusaria o `Player.gd` (pego antes de rodar o jogo).
**Causa raiz:** ao remover o embalo da corrida (pedido do dono), apaguei a linha `_aceleracao_da_corrida.resetar()`, que era o CORPO INTEIRO de `_resetar_impulso_de_corrida()`, deixando a função vazia (erro de sintaxe em GDScript) e seis chamadores apontando para ela.
**Evidência:** `grep -n "func _resetar_impulso_de_corrida" -A2` mostrava a declaração seguida direto da próxima função.
**Descartado:** —
**Correção:** função e as 7 chamadas (6 no Player, 1 no `YoruNetwork.gd`) removidas; o diff confirmou que todas estavam no primeiro nível.
**Como detectar de novo:** ao remover uma linha, conferir se ela era a única do bloco; rodar `test_compila`.

## 2026-10-03 — Mapa vivo: barcos-casa sumiam e um barco sem leme derrubava a dica do HUD

**Sintoma:** no Modo História com o mapa de verdade, "Invalid access to property 'global_position' on Nil" em `comando.gd:46` a cada quadro, vindo da dica do HUD.
**Causa raiz:** `Navegacao.ligar_no_mapa` trocava TODA peça da categoria navios por um barco vivo sem conferir o retorno de `configurar` — que é falso para os três barcos-casa (casas na água, cenário por decisão da frente de barcos). A peça original era apagada (a casa sumia do mapa) e o barco quebrado, sem `leme`, entrava na lista de candidatos.
**Evidência:** depois da correção, mapa vivo com 5 barcos dirigíveis (galeão, chalupa, 3 botes) flutuando e 0 SCRIPT ERROR.
**Descartado:** erro no `candidato()` em si (a lista é que tinha um barco inválido).
**Correção:** `comando.gd` — só troca a peça quando `configurar` dá certo; senão descarta o barco novo e mantém a peça.
**Como detectar de novo:** `DISPLAY=:1 godot --path . --script tools/dev_tests/capturar_navios.gd` (mapa vivo; contar SCRIPT ERROR).

## 2026-10-03 — Barco: jogador em pé no convés segurava o casco (afundava 0,7–1,2 m)

**Sintoma:** chalupa e galeão parados ficavam 0,3–0,8 m abaixo da linha d'água em média (pior 1,2 m), quicando; andando ficavam certos.
**Causa raiz:** o barco é `CharacterBody3D` e usa `move_and_slide`, que trata o jogador como obstáculo: com o jogador em pé no convés, o casco batia nele por baixo (normal (0,−1,0), colisor "1" = o jogador) e não subia com a onda. Agravante: a mola de flutuação (ω≈3,7 rad/s, amortecimento sobre a velocidade absoluta) seguia a onda com ~46° de atraso de fase.
**Evidência:** traço das colisões do casco durante a flutuação: `1(CharacterBody3D) n=(−0.02,−0.9997,0.01)`; depois da correção pior desvio 0,01–0,12 m nos três navios, inclusive com o jogador em pé no convés por 3 s.
**Descartado:** critério de contato com a água (afrouxar de 0,45 m para 1,5 m não mudou os números); colisão com o fundo do mar.
**Correção:** `barco.gd` — exceção de colisão com os jogadores SÓ durante o `move_and_slide` do barco (a exceção do Godot vale para os dois lados: deixada ligada, o jogador atravessou o convés e caiu na água — medido); mola de flutuação 40/12 com amortecimento sobre a velocidade relativa à onda.
**Como detectar de novo:** `tools/dev_tests/test_navios.gd` ("flutua na linha d'água" e "com o jogador em pé no convés").

## 2026-10-03 — Ondas paradas para os barcos: get_shader_parameter devolve nulo

**Sintoma:** no jogo os barcos não balançavam e ficavam parados abaixo da linha d'água; o log enchia de "Invalid call. Nonexistent 'float' constructor" em `oceano_historia.gd:103` (milhões de linhas num teste de 10 s).
**Causa raiz:** `OceanoHistoria.superficie_em` lia `float(material.get_shader_parameter("tempo_fixo"))`. Uniforme nunca DEFINIDO no material volta `null` (o padrão do shader não sai por `get_shader_parameter`); `tempo_fixo` só era definido pelo `test_ondas_barcos`, que por isso passava — no jogo a amostragem estourava a cada chamada.
**Evidência:** `test_navios`: balanço 0,0° e desvio −0,28 m antes; depois 1,6–3,3° de balanço e desvio médio 0,00 m; zero SCRIPT ERROR.
**Descartado:** contrato da água (`superficie_em`/`normal_em` existem e o teste de ondas passa — ele só cobria o caminho com o uniforme definido).
**Correção:** `oceano_historia.gd` — `_param(nome, padrão)` lê o uniforme com valor padrão quando vem nulo.
**Como detectar de novo:** `tools/dev_tests/test_navios.gd` (balanço > 0,3°) e procurar "SCRIPT ERROR" no log.

## 2026-10-03 — Deslize: cápsula encolhida afundava no chão e a barra baixa bloqueava

**Sintoma:** deslizando contra uma barra a 1,0 m do chão, o corpo parava nela como se estivesse de pé.
**Causa raiz:** a cápsula do Modo História tem raio 0,5 m e não fica mais baixa que o próprio diâmetro; o código usava `max(alt/2, 2·raio)` = 1,01 m em vez de 0,80 m, mas baixava o centro em ¼ da altura INTEIRA (0,40 m) — a base ficava 0,1 m abaixo do chão, a física empurrava o corpo para cima e o topo passava de 1,0 m.
**Evidência:** altura medida da colisão deslizando: 1,01 m (antes) e 0,80 m (depois); a barra passou a ser atravessada por baixo (z −4,46 contra parado em z 0,50 de pé).
**Descartado:** teto/hurtbox (erro separado); posição da barra.
**Correção:** `Player._encolher_colisor` encolhe também o raio (`min(raio, alt/4)`) e o devolve exato ao levantar.
**Como detectar de novo:** `tools/dev_tests/test_roll_deslize.gd` seção G.

## 2026-10-03 — Deslize: teste de teto acusava teto em campo aberto (raio batia na própria hurtbox)

**Sintoma:** em `test_roll_deslize`, o deslize nunca levantava (colisão ficava em 0,80 m), rastejava a 1,80 m/s e o Espaço não pulava — tudo como se houvesse teto baixo em campo aberto.
**Causa raiz:** `Player._teto_livre()` lança raios do centro do corpo para cima excluindo só o RID do jogador. A hurtbox do combate (`HurtboxDeCombate`, um `StaticBody3D` FILHO do jogador, camada 1<<20) é encolhida junto no deslize, e o topo dela fica exatamente na origem do raio — o raio a acertava.
**Evidência:** com `par.collision_mask = ~HurtboxDeCombate.CAMADA`, o mesmo teste foi de 13/18 para 18/18 (levanta em 1,03 s, velocidade mínima 2,29 m/s, pulo vy 15,5).
**Descartado:** geometria do mapa (campo aberto do baseplate); velocidade de saída (o deslize preso era sintoma do teto, não causa).
**Correção:** `Player._teto_livre()` tira a camada da hurtbox da máscara do raio.
**Como detectar de novo:** `tools/dev_tests/test_roll_deslize.gd` seções F e H.

## 2026-10-03 — Nado com braços "ao contrário": corpo nadava de costas para o movimento

**Sintoma:** o dono relatou "direção incorreta dos braços na animação de nadar".
**Causa raiz:** na fatia 1 (02/10) a frente do corpo fora do combate passou a seguir `LocomocaoChao.rumo`, que só é atualizado pela locomoção de chão. Na água o nado tem controle próprio e não passa por ela: o `rumo` congelava no último valor de terra. Quem entrava na água vindo de outra direção nadava com o corpo virado para trás ou de lado, e a braçada (certa no espaço do modelo) remava contra o movimento.
**Evidência:** `tools/dev_tests/test_nado_frente.gd` com o jogador chegando à água virado para trás: sem a correção, W dá dot −1,000 entre a frente do corpo e o nado, D dá 0,000; com a correção, 1,000 nos três (W, D, S). Braçada isolada no animador conferida certa (mão 0,40 m à frente do ombro na entrada, −0,39 m no fim da puxada).
**Descartado:** pose do nado (`nado_poses.gd`) — usa +X à frente corretamente; giro do modelo pelo `jogador_na_agua.gd` (não mexe em rotação).
**Correção:** `LocomocaoChao.acompanhar()` chamado no ramo da água do `Player._etapa_locomocao` (03/10, antes do relato chegar): o `rumo` segue a velocidade do nado.
**Como detectar de novo:** `"$(./find_godot.sh)" --headless --path . --script tools/dev_tests/test_nado_frente.gd`.

## 2026-10-03 — Escalada com as mãos para trás: sinal do braço invertido (e copiado por mim)

**Sintoma:** o dono relatou "no momento que o personagem vai escalar ele escala com as mãos para trás — houve uma inversão na direção".
**Causa raiz:** no rig por nós, +X no `UpperArm` leva o braço para a FRENTE (−Z) — convenção escrita no próprio `ProceduralAnimator` (bloco do sprint). A pose `_climb` (julho/2026) usava −0,9 → −3,0 com o comentário errado "x muito negativo = pra cima"; ficou invisível porque a escalada esteve desligada de 27/08 a 03/10. Na fatia 3 eu COPIEI o mesmo sinal para borda e subida (−2,9) e para o braço de apoio do wall run (−0,35); o salto longo tinha o mesmo erro ("braços à frente" com −2,4). Os testes da escalada mediam posição do CORPO, nunca das mãos, e passaram.
**Evidência:** `medir_direcao_bracos.gd` (mão relativa ao ombro, frente = −Z): escalada −0,11 m em média, borda −0,20 m, subida −0,18 m (atrás). Depois da correção: +0,21, +0,16, +0,29 m (à frente); fotos laterais antes/depois.
**Descartado:** corpo virado para fora da parede (a frente do modelo apontava para dentro dela, dot 1,000); pose de nado (estava certa — o nado tinha outra causa, registrada à parte).
**Correção:** `src/anim/ProceduralAnimator.gd` — `_climb` +1,2 → +2,6 (cotovelo 1,2 → 0,05), borda +2,5, subida +2,5 → −0,2, apoio do wall run +0,35, salto longo +2,4.
**Como detectar de novo:** `DISPLAY=:1 godot --path . --script tools/dev_tests/medir_direcao_bracos.gd -- <pasta>` (7 conferências + fotos; na foto a frente do modelo fica à direita).

## 2026-10-03 — Câmera demorava a voltar ao parar depois da frenagem com derrapagem

**Sintoma:** `medir_camera_e_parede.gd` "parar traz a câmera de volta" reprovou: parado 4,05 m, correndo 6,28 m, "parou de novo" 5,15 m.
**Causa raiz:** o afastamento da câmera (`CameraRig._afastamento`) só volta quando a velocidade do corpo cai abaixo de 0,06 m/s. Até 02/10 soltar as teclas zerava a velocidade no ato; a frenagem da fatia 1 (`locomocao_chao.gd`, 15 m/s², derrapando 11 m/s²) faz o corpo levar 0,3–0,6 s para parar, e a câmera ficava longe esse tempo — contra a regra escrita dela ("parar é uma decisão do jogador e a câmera tem de obedecer na hora").
**Evidência:** 5,15 m = 4,05 + 1,10 (degrau "andando") 75 quadros (~0,46 s a ~163 qps) depois de soltar o sprint; com a correção, 4,10 m.
**Descartado:** problema de taxa da câmera (IDA 3,2 / VOLTA 6,0 inalteradas) — a volta nem começava.
**Correção:** `CameraRig.atualizar(..., parando)` zera o afastamento quando o jogador soltou as teclas no chão e a locomoção está freando; `Player._parando_por_vontade()`. Balanço e inclinação seguem a velocidade real.
**Como detectar de novo:** `DISPLAY=:1 godot --path . --script tools/dev_tests/medir_camera_e_parede.gd` (seção 2).

## 2026-10-03 — Locomoção que herda velocidade acumulava empurrão, avanço do golpe e puxão do soco

**Sintoma:** `test_combate_historia` reprovou "no preparo anda ×0,93 do controle (ficha ×0,60)": atacando andando, o corpo quase não freava.
**Causa raiz:** a fatia 1 (`src/player/locomocao_chao.gd`, 02/10) mudou a semântica de `velocity` de "reescrita todo quadro" para "estado integrado" (arrancada/frenagem herdam a velocidade anterior). Três sistemas somam velocidade de UM quadro DEPOIS da locomoção, calibrados para o modelo antigo: empurrão de dano (`HealthController.impulso_do_quadro`), avanço do golpe (`ExecutorCorpoACorpo.impulso_do_quadro`) e puxão do soco (`perform_melee_lunge`, 18 m/s pensado como 0,30 m num quadro). Herdados como entrada, passaram a se acumular. Não auditei quem escrevia em `velocity` depois da locomoção antes de declarar a fatia pronta.
**Evidência:** traço quadro a quadro: o golpe derruba a corrida para 2,52 m/s (4,2 × 0,6) e, a partir do quadro 9, sobe +0,59 m/s por quadro até 7,13 m/s. Empurrão lateral de 8 m/s correndo: 11,52 m de deslocamento contra 1,98 m da soma dos impulsos (5,8×).
**Descartado:** fator da ficha não aplicado (estava: `fator=0.60`, `effective_speed` correto); estado de combate não reconhecido (`_em_combate()` true, estado "combate").
**Correção:** `LocomocaoChao.entrada()` (src/player/locomocao_chao.gd) — se a locomoção mandou no quadro anterior, a entrada é a própria saída dela deslizada nas normais de parede da última colisão; se outro sistema mandou (dash, parkour, nado), a velocidade real, preservando o embalo entre sistemas. `Player._normais_de_parede()` e o ramo padrão de `_etapa_locomocao` passam a usá-la.
**Como detectar de novo:** `tools/dev_tests/test_locomocao_chao.gd` caso H (empurrão lateral desloca a soma dos impulsos ±25%: 1,98 vs 1,98 m; sem a correção 11,52 m) e `test_combate_historia` seção 7.

## 2026-10-02 — Workbench com color_type MATERIAL pinta de branco material com textura

**Sintoma:** a primeira foto da serpente nova no Blender saiu branca-acinzentada, parecendo que a textura marrom tinha sumido.
**Causa raiz:** o gerador põe a cor da pele numa textura de imagem ligada ao Principled, com a cor base do material em branco; no Workbench, `shading.color_type = 'MATERIAL'` usa a cor de viewport do material (branca) e ignora o nó de imagem.
**Evidência:** mesma cena com `color_type = 'TEXTURE'`: pele marrom e crista listrada corretas.
**Descartado:** perda de UV/imagem na solda/junção (o GLB exportado tinha a textura e o Godot mostrou certo).
**Correção:** fotos do Blender de modelos texturizados usam `color_type = 'TEXTURE'` (scripts de conferência e `animais_rig/fotos.py` já usam).
**Como detectar de novo:** modelo inteiro de uma cor só no Workbench enquanto o Godot mostra a textura.

## 2026-10-02 — Contorno anime (casca invertida) engrossou as próprias linhas de tinta

**Sintoma:** o topo da cabeça da serpente ficou cheio de borrões pretos grossos depois de ligar o estilo anime na importação.
**Causa raiz:** o passe de contorno (`grow` + `CULL_FRONT`) foi aplicado a TODOS os materiais, inclusive o das linhas de tinta (tubos finos pretos das rugas): a casca inflada de 7 cm em volta de um tubo de 4 cm triplicava a espessura do traço.
**Evidência:** comparação antes/depois em `art_src/validation/bestas_mar/anime/comparacao.png`: com o contorno nas rugas, traços de ~3x a espessura das bordas; sem ele, traços finos como no desenho.
**Descartado:** diminuir o `grow` geral (afinaria também a silhueta, que está na espessura certa).
**Correção:** `src/world/importacao/estilo_anime.gd`: material com "Tinta" no nome não ganha `next_pass` de contorno.
**Como detectar de novo:** olhar a vista 3/4 da captura; traço interno mais grosso que a borda do modelo = contorno sobre linha.

## 2026-10-02 — Sobrancelha "brava" da serpente modelada ao contrário (cara de triste)

**Sintoma:** na comparação com o quadro do anime, as sobrancelhas viraram dois calombos em cima da cabeça e escondiam os olhos; de frente a expressão não lia como raiva.
**Causa raiz:** erro meu de leitura da referência: modelei a crista da sobrancelha subindo da FRENTE-lado para a TRÁS-meio (ponta de dentro alta, de fora baixa). No V bravo do anime é o oposto: a ponta de dentro fica à frente e BAIXA, entre os olhos, e sobe para trás e para fora. Na cabeça que desce para o focinho, isso decide se a ruga "franze" ou "cai".
**Evidência:** `art_src/validation/bestas_mar/anime/comparacao.png` antes (calombos, olho como um risco vermelho) e depois de inverter `ang_crista` (44°→80° de trás para a frente) e o tubo `Sobrancelha`: V bravo e olhos vermelhos visíveis de frente.
**Descartado:** só aumentar o olho (continuava escondido sob o rolo da sobrancelha).
**Correção:** `tools/blender/bestas_mar.py` `serp_perfil` (relevo da sobrancelha e órbita) e `serp_cabeca` (tubo da sobrancelha da ponta de dentro, à frente, para trás e para fora; olhos no alto, olhando para a frente).
**Como detectar de novo:** `tools/capturar_serpente_anime.gd` — comparar a vista 3/4 com a referência antes de refinar detalhes.

## 2026-10-02 — Ida e volta pelo Blender vira o macaco (modelo do Sketchfab) de cabeça para baixo

**Sintoma:** o macaco importado no Blender, com clipes novos somados e exportado de novo, aparece no Godot de cabeça para baixo ao lado do original; a conferência osso a osso dá desvio de 2 m (104 % do tamanho) nos clipes ANTIGOS.
**Causa raiz:** no original a conversão de eixos e o deslocamento do esqueleto moram num nó-junta (`Armature_deform_01`: rotação −90° em X e translação (0; 0,4; 0), sob nós vazios do Sketchfab com escala 0,01). O importador glTF do Blender assa isso no repouso dos ossos; o exportador escreve as juntas sem devolver a rotação/deslocamento (no reexportado `Armature_deform_01` sai com rotação identidade) e acrescenta rotações de 90° nos nós vazios — a cadeia deixa de ser equivalente.
**Evidência:** `tools/mapa_ilha/comparar_clipes_riggados.gd` (bones em espaço do mundo): pior desvio 2,0477 em `monkey_run` t=0,44; foto lado a lado (original em pé, reexportado invertido); árvore de nós do GLB: original `Armature_deform_01 {translation [0,0.4,0], rotation [-0.707,0,0,0.707]}`, reexportado `{rotation identidade}`.
**Descartado:** soltar o esqueleto dos nós vazios mantendo a posição no mundo e apagá-los antes de exportar (desvio idêntico, 2,0477); renomear as ações (resolvido à parte: o Blender corta nome de ação acima de 63 caracteres e numera).
**Correção:** nenhuma ida e volta: o resultado quebrado foi apagado e a loja continua com o original (cmp idêntico). Clipes novos dos 7 modelos com ossos ficam para uma via que não reexporte o arquivo (decisão do dono pendente).
**Como detectar de novo:** rodar `comparar_clipes_riggados.gd` em qualquer modelo que passe pelo Blender antes de pô-lo na loja (falha acima de 1 % do tamanho).

## 2026-10-02 — Foto cortada lida como "peso da cabeça no peito" levou a uma correção que piorou 4 animais

**Sintoma:** depois de limitar a suavização dos pesos a arestas curtas (para "corrigir" a galinha), o lote dos 22 mostrou picos novos de estiramento: raposa 27,8 % e cavalo 9,8 % no dano, corgi 13,9 %, bisão 19 % no ataque — antes da mudança estavam em 0–3 %.
**Causa raiz:** erro meu de diagnóstico: na foto dos ossos da galinha o vermelho na frente parecia peso da cabeça no peito; era o PESCOÇO, porque o enquadramento 4:3 cortava o topo do bicho alto. Sem medir, mudei a suavização para ignorar arestas longas — e nos modelos de poucas faces a transição cauda/tronco e peito/perna só tem arestas longas (19–45 cm), que ficaram com fronteira dura.
**Evidência:** pesos medidos no peito da galinha: peito 0,86–1,00 (corretos); picos novos todos em arestas de 0,19 m (raposa, cauda), 0,12 m (cavalo, cauda) e 0,45 m (bisão, peito-perna), lados com `quadril 0.89` × `cauda_3 1.00`.
**Descartado:** a mudança da regra "rente ao chão" (afeta só vértices baixos, não as caudas).
**Correção:** `tools/blender/animais_rig/quadrupede.py` `suavizar`: todas as arestas entram de novo (fica só a ponderação pela distância); enquadramento das fotos corrigido para caber a altura (`rig_animais.py`, quadro 4:3).
**Como detectar de novo:** antes de mudar peso por causa de uma foto, medir os pesos do vértice (`pesos_peito.py`/`estica.py`); comparar o `ESTIRAMENTO` dos 22 antes e depois de qualquer mudança no código comum.

## 2026-10-02 — Cortar costuras entre perna e cauda abriu buracos na malha do corgi

**Sintoma:** depois de separar as "costuras" entre partes rígidas, o corgi no ataque mostrava o fundo através da coxa traseira e lascas brancas pontudas na junção com a cauda; a métrica de estiramento tinha melhorado (×19,8 → ×5,4), mas a foto de perto denunciou os buracos.
**Causa raiz:** erro meu de premissa: tratei toda aresta entre rótulos rígidos diferentes como "peças que só se encostam". No corgi a cauda e a parte de trás da coxa são a MESMA superfície (arestas manifold, 2 faces); `split_edges` + `vert_separate` transformaram essa superfície em borda aberta, que se abre quando a perna e a cauda se movem.
**Evidência:** 18 costuras cortadas no corgi e buraco visível em `attack` q9; com o corte restrito a arestas com 3+ faces: corgi 1 costura, raposa 3, cão/vaca/beagle 0, nenhum buraco nas fotos, e a mesma métrica dentro do limite para todos, exceto o corgi (13 %, ponta da cauda no chão entre as patas, invisível embaixo do corpo).
**Descartado:** a métrica de estiramento como prova suficiente (ela não vê buraco — buraco é encurtamento zero com borda aberta).
**Correção:** `tools/blender/animais_rig/quadrupede.py` `descosturar`: corta só arestas não-manifold entre partes rígidas; o resto da transição é da suavização dos pesos (`SUAVIZAR_PASSADAS`).
**Como detectar de novo:** foto de perto (`zoom` no `.blend` do rig) dos piores quadros apontados pelo `ESTIRAMENTO`, procurando fundo aparecendo através da malha.

## 2026-10-02 — Triângulos esticados até o chão: partes que se encostam na malha soldada

**Sintoma:** métrica de estiramento dos clipes: corgi ×19,8 no galope, cão ×4,5 no passo, bisão ×4,8 e ×27 ao pastar (espinho do peito ao chão).
**Causa raiz:** a solda (0,5 mm) junta partes que no modelo só se ENCOSTAM: a ponta da cauda do corgi toca as duas patas traseiras no chão, as coxas internas do cão se tocam, a ponta do casco do bisão fica fora do raio da busca da perna. Com pesos rígidos diferentes de cada lado da junção (pata E × pata D, pata × cauda, casco × pescoço) a face da junção estica quando as partes se afastam.
**Evidência:** `estica.py`: corgi v385 [cauda_3] — v196 [perna_tras_3.R], aresta de 2 cm a ×19,8; cão v346 em x = +0,05 rotulado perna DIREITA; bisão v481 (z −0,01) [pescoco 1.00] vizinho do casco.
**Descartado:** só `split_edges` nas arestas de costura (deixou 6 vértices gravata-borboleta, ligados só por vértice); re-rotular vértices de tronco vizinhos (subiu a fronteira e partiu o úbere da vaca: ×13).
**Correção:** `quadrupede.py`: `_rotular` (perna = linha de centro mais próxima; abaixo de 12 % da altura é pata), `descosturar` (SÓ arestas não-manifold entre partes rígidas — ver a entrada "costura abriu buracos" acima; normais por canto preservadas), topo da perna meio tronco e 3 passadas de suavização dos pesos. `rig_animais.py`: `medir_estiramento` em todo clipe.
**Como detectar de novo:** a linha `ESTIRAMENTO max ... % da altura` do `rig_animais.py` (aviso acima de 5 %).

## 2026-10-02 — Cauda marcada à mão saiu com os ossos invertidos (cauda_1 na ponta)

**Sintoma:** raposa com aresta esticada ×10 na morte entre `cauda_3` e a coxa; cauda do cão/corgi/raposa dobrando a partir da ponta.
**Causa raiz:** erro meu em `analisar`: a cauda SEGUIDA vem da ponta para a raiz e é invertida no fim (`c.linha = reversed(linha)`); os `pontos` do perfil eu escrevi da raiz para a ponta e passaram pela MESMA inversão — `cauda_1` foi parar na ponta e `cauda_3`, com peso 100 %, colado na anca.
**Evidência:** `estica.py` na raposa (death q24): v129 [cauda_3 1.00] em (0.08, 0.53, 0.49) — altura da raiz — vizinho de v10 [perna_tras_1.R]; ×10,5.
**Descartado:** raio do tubo da cauda grande demais (o defeito persistia com o raio menor).
**Correção:** `tools/blender/animais_rig/quadrupede.py` (`analisar`): `pontos` lidos em ordem reversa antes da inversão comum, com comentário do sentido.
**Como detectar de novo:** foto `<id>_ossos.png` com a legenda: `cauda_1` (magenta forte) tem de estar junto da anca.

## 2026-10-02 — Dano do animal saía no início do ataque, antes de a animação encostar

**Sintoma:** (achado ao ligar os clipes de ataque) `_tentar_atacar` aplicava `take_damage` no mesmo quadro de `animador.atacar()`; com a cabeçada de 0,9 s (impacto em 0,42 s) o jogador apanharia enquanto a vaca ainda recuava para armar.
**Causa raiz:** o ataque procedural antigo era uma investida de 0,45 s sem preparação, então dano imediato parecia certo; o clipe novo tem antecipação e o código não sabia o quadro do impacto.
**Evidência:** manifesto do rig: attack golpe = 0,42 s (cabeçada), 0,36 s (mordida), 0,78 s (empinar); o dano caía em t = 0.
**Descartado:** fração fixa do clipe (0,5): empinar acerta em 65 % e os modelos baixados têm tempos próprios.
**Correção:** campo `golpe_em` na `FichaDeAnimal` (gravado do manifesto por `tools/mapa_ilha/atualizar_animais_riggados.gd`); `AnimalDaIlha._tentar_atacar` agenda e `_acertar` confere alcance +0,6 m e vida no impacto (sair de perto na preparação = esquiva). `golpe_em` 0 mantém o comportamento antigo.
**Como detectar de novo:** ficha com `golpe_em` > 0 e teste de predador acertando o jogador parado (`test_animais`).

## 2026-10-02 — Seguidor de cauda atravessou o corpo da raposa (cauda tão larga quanto a anca)

**Sintoma:** esqueleto da raposa com a cadeia da cauda indo da ponta até o PEITO e a anca (R) mal posicionada; regiões de peso do tronco viraram cauda.
**Causa raiz:** o seguidor de membro (`rastrear`) para quando o contorno cresce de uma vez (fundiu no tronco). A cauda peluda da raposa tem contorno do tamanho da anca, então o salto nunca aconteceu e as fatias seguiram pelo tronco. O mesmo engano no teste de largura da traseira (`ext.x > 0,45 × largura`) tomou a cauda por anca.
**Evidência:** linha da cauda impressa começando em y = −0,25 (perto das patas da frente, z 0,41) em vez da anca (y ≈ +0,48).
**Descartado:** dica de ponta errada (a ponta foi achada na traseira certa).
**Correção:** `tools/blender/animais_rig/quadrupede.py`: traseira do tronco limitada a 12 % do comprimento atrás das patas traseiras; perfis de cauda larga/enrolada (raposa, cão) com `pontos` medidos na grade em `tools/blender/rig_animais.py`; cauda com < 3 pontos agora é erro explícito.
**Como detectar de novo:** a foto `<id>_ossos.png` (legenda de cores): cadeia `cauda_*` entrando no tronco ou `quadril` fora da anca.

## 2026-10-02 — Hitbox da vaca encolheu ao ganhar esqueleto (medida pelos ossos)

**Sintoma:** `test_animais` B1b: "hitbox da vaca do tamanho do corpo +30%" falhou com 2,24 m de comprimento (esperado > 2,5) logo depois de trocar a vaca pelo modelo riggado.
**Causa raiz:** `AnimalDaIlha._medidas_reais` mede bicho COM esqueleto pela origem dos ossos ×1,12 (feito para os modelos baixados, cuja caixa do arquivo não é confiável). No rig gerado, as origens param na junta da cabeça e na anca — focinho e traseira ficam de fora — então o corpo medido ficou ~13 % mais curto e estreito.
**Evidência:** caixa do catálogo inalterada (0,688 × 1,663 × 2,537) e hitbox 2,24 m antes; 2,58 m depois de usar a caixa para o rig próprio.
**Descartado:** mudança da malha na exportação (AABB da MeshInstance idêntica ao original: S (0.688, 1.663, 2.537)).
**Correção:** `src/historia/animais/animal_da_ilha.gd` `_medidas_reais`: esqueleto com osso `raiz` (rig de `tools/blender/rig_animais.py`) usa o tamanho padrão do catálogo; os baixados seguem pelos ossos.
**Como detectar de novo:** `tools/dev_tests/test_animais.gd` seção B1b (hitbox da vaca > 2,5 m).

## 2026-10-02 — Soldar vértices (remove_doubles) apagou o sombreamento chapado dos animais

**Sintoma:** depois de soldar a casca para fatiar/pesar, a vaca renderizou lisa, sem as facetas do modelo original.
**Causa raiz:** o .glb guarda o chapado como normais por canto (custom normals, 1231/1325 faces "smooth" com `custom_normal`). `bmesh.from_mesh/remove_doubles/to_mesh` não preserva essas normais personalizadas: ao juntar os vértices o Blender volta às normais interpoladas.
**Evidência:** foto de ossos 1 = vaca lisa; depois de guardar `me.corner_normals` antes da solda e reaplicar com `normals_split_custom_set`, as facetas voltam idênticas ao original (folha `cow_ossos.png`). Faces e cantos conferidos iguais (1325) antes de reaplicar.
**Descartado:** perder UV (UV é por canto e sobrevive à solda) e marcar tudo flat (o original não era 100 % flat).
**Correção:** `tools/blender/animais_rig/geometria.py` `preparar_malha`: guarda normais por canto, solda, confere faces/cantos e reaplica.
**Como detectar de novo:** comparar a foto do rig com a do modelo original na mesma luz; faces lisas onde havia facetas = normais perdidas.

## 2026-10-02 — Trilha NLA ativa sobrepõe a pose aplicada à mão (fotos do rig todas iguais)

**Sintoma:** a folha de quadros dos 6 clipes da vaca saiu com os 48 quadros idênticos (vaca parada), embora as poses mudassem.
**Causa raiz:** `Rig.gravar` criava cada ação e a empurrava para uma trilha NLA deixada ATIVA. Na avaliação do depsgraph (render, `view_layer.update`) o NLA reescreve os ossos com o quadro atual das trilhas, apagando a pose que `rig.aplicar` acabara de pôr nos pose bones.
**Evidência:** antes da correção 48/48 quadros iguais; com `trilha.mute = True` ao gravar, idle/walk/run/damage/attack/death aparecem distintos na mesma folha.
**Descartado:** pesos/modificador Armature quebrados (o `assentar` da morte, que roda ANTES de existir trilha, deformava a malha normalmente).
**Correção:** `tools/blender/animais_rig/movimento.py` (`Rig.gravar`): trilha nasce muda; `exportar` em `tools/blender/rig_animais.py` reativa todas antes do glTF (modo NLA_TRACKS).
**Como detectar de novo:** a folha `art_src/validation/animais_rig/<id>_clipes.png` com linhas iguais; ou conferir `arm.animation_data.nla_tracks[*].mute` antes de qualquer pose manual.

## 2026-10-01 — diagnóstico errado: "a bateria deixa a física 4× mais lenta"

**Sintoma:** o custo dos animais na fazenda pulou de ~1–1,7 ms para ~4,5 ms por quadro; atribuí à bateria (notebook descarregando, modo "powersave") e registrei isso na doc e na memória.

**Causa raiz:** duas coisas, nenhuma era a bateria. (1) A comparação misturava métodos: a medida "barata" (~24 µs por bicho) chamava `move_and_slide` 50 vezes seguidas no mesmo quadro; a realista chama uma vez por quadro com a velocidade de verdade. (2) Depois, o fundo do mar entrou como UMA HeightMapShape cobrindo o mapa inteiro, inclusive embaixo da ilha, e passou a ser testado em todo movimento (~0,9 ms).

**Evidência:** na tomada, sem o fundo do mar, o `move_and_slide` deu 2,38 ms para 22 bichos — o mesmo da bateria (2,47–2,83). Com o fundo em 4 faixas fora da ilha e a meia distância andando 1 quadro em 3: vila 0,97 ms, fazenda 1,43 ms (na tomada).

**Correção:** fundo do mar em 4 faixas em volta da ilha; LOD de meia distância (o gatilho que estava declarado). Doc e memória corrigidas.

**Como detectar de novo:** antes de culpar o ambiente, repetir a MESMA medição nas duas condições; e nunca comparar números de métodos diferentes.

## 2026-10-01 — tinta submersa não aparecia: Control filho de CanvasLayer com tamanho 0×0

**Sintoma:** na captura do mergulho, a tela não ficava azul embaixo d'água, embora a câmera estivesse submersa e a tinta marcada como visível.

**Causa raiz:** `AguaHud` (Control) é filho direto do `HistoriaHud` (CanvasLayer) e só chamava `set_anchors_preset(PRESET_FULL_RECT)` no `_ready`: o tamanho ficou 0×0, e a tinta (filha dele, também com âncoras de tela inteira) herdou o zero.

**Evidência:** depuração: `AguaHud size (0,0)`, `VisaoSubmersa visível=true size=(0,0)`. Depois de dimensionar pelo `get_viewport_rect()` a cada mudança, a captura submersa ficou azulada e a barra de FÔLEGO apareceu no lugar.

**Correção:** `AguaHud._process` ocupa o tamanho da tela (posição 0, `size` = viewport) e reposiciona a barra; a tinta acompanha.

**Como detectar de novo:** UI nova no HUD do Modo História — conferir `size` numa captura, não só `visible`.

## 2026-10-01 — append em PackedVector3Array guardado num dicionário não guardava nada

**Sintoma:** `colisao_troncos_arvores.gd` dizia "nenhum tronco achado" nos dois aglomerados, embora a malha "Wood" existisse com índices.

**Causa raiz:** `(grupos[r] as PackedVector3Array).append(v)` — os Packed*Array do Godot 4 são passados por VALOR: o `as` devolve uma cópia, o `append` vai para a cópia e o dicionário continua com o array vazio.

**Evidência:** depois de trocar por `Array` (referência) e converter no fim: 25 partes (12 depois de descartar galhos soltos) em `trees` e 10 em `pine_trees`.

**Correção:** acumular em `Array` e converter para `PackedVector3Array` só no fim; ou reatribuir `grupos[r] = arr` depois do `append`.

**Como detectar de novo:** coleção Packed* dentro de dicionário ou array: desconfiar de qualquer modificação no lugar.

## 2026-10-01 — teste "pés no chão nas encostas" media em cima da copa de um pinheiro

**Sintoma:** depois que os aglomerados `trees`/`pine_trees` passaram a colidir só pelos troncos (decisão do dono), `test_ilha_inicial` passou a reprovar "pés no chão nas encostas: maior folga 0,092 m" (limite 0,06).

**Causa raiz:** o ponto (−175, −150) do teste fica dentro de dois aglomerados `pine_trees`. Com a colisão antiga (malha inteira, folhagem inclusive), o raio de cima batia na COPA e o jogador era posto e medido em pé sobre ela: a encosta de 21° nunca foi medida ali. Sem a folhagem sólida, o raio chega ao relevo e mede a folga real do pé de baixo da encosta: ~3,5 cm do fundo arredondado da cápsula (r 0,5 a 21°) + ~6 cm do pé mais baixo do que o centro.

**Evidência:** os quatro raios do teste agora batem em `relevo_*`; a folga não muda esperando 7 s (não é animação atrasada); nenhum arquivo do jogador ou da animação mudou desde 12:10; o outro ponto de 23° (pés atravessados na encosta) dá 0,023.

**Correção:** nenhuma ainda — limitação antiga revelada, não regressão. Próximo passo: IK dos pés no relevo. O teste segue com o limite de 0,06 (não afrouxado).

**Como detectar de novo:** teste de "pé no chão" deve confirmar que o raio bateu no relevo (`peca_id` relevo_*), não em outra peça.

## 2026-10-01 — no jogo, nenhum animal tomava dano do soco

**Sintoma:** teste do dono em jogo: a águia feria o jogador, mas nenhum animal recebia dano.

**Causa raiz:** o soco do Modo História é uma varredura curta do punho, na altura do peito (alcança ~0,65 m à frente). O único volume do animal era a cápsula de ANDAR: um cilindro fino no centro do corpo (vaca: 2,3 m de corpo e raio 0,31). Bater na anca ou na cabeça passava no vazio; coelho, cão e ovelha ficavam inteiros abaixo do punho. O `test_animais` chamava `take_damage` direto e nunca provou o soco de verdade.

**Evidência:** medição com `_request_melee` real e o jogador encostado e virado: antes, só os grandes e só no centro; ovelha, cão e coelho nada. Depois da hitbox, a anca da vaca, ovelha (1,0 m), galinha (0,45 m), gato, sapo, lagarto e pato tomam dano.

**Correção:** `AnimalDaIlha` ganhou uma hitbox de interação (decisão do dono: corpo +30 %, altura mínima 1,6 m), filha do `Visual` (gira com o bicho), na camada da `HurtboxDeCombate` e sincronizada no servidor de física a cada quadro. Desliga ao morrer ou ser domado; o pet não tem (o dono não o fere). O teste agora dá soco de verdade.

**Como detectar de novo:** teste de dano tem de passar pelo golpe real, não por `take_damage` direto.

## 2026-10-01 — teste do pomar quebrou quando o mapa vivo ganhou árvores

**Sintoma:** `test_pomar_e_doma` passou 34/34 e, depois do plantio no mapa vivo, reprovou 6 checagens ("4 frutíferas no pomar (27)", galhos 135 de 20, doma sem animal perto).

**Causa raiz:** o teste monta uma CÓPIA do mapa vivo com 4 frutíferas próprias e contava TODAS as árvores do pomar como se fossem só as dele. Além disso punha o jogador na altura do primeiro objeto que o raio tocava: com troncos e pedras novos na floresta, ele parava em cima de um tronco, a mais de 3 m de altura do coelho.

**Evidência:** as 6 falhas somem ao contar só `teste_frutifera_*` e ao pôr o jogador na altura do próprio bicho; 34/34 de novo no mapa com 682 peças.

**Correção:** o teste filtra as próprias peças e usa contagens relativas (total − 1, total); `_encostar` usa a altura do animal.

**Como detectar de novo:** todo teste sobre cópia do mapa vivo deve funcionar com o mapa crescendo — conferir as asserções que contam "tudo".

## 2026-10-01 — frutas de 0,3 m sumiam na copa vista do chão

**Sintoma:** na primeira captura com GPU, a árvore frutífera de 7 m mostrava 2 das 5 frutas, como pontinhos meio cobertos pelas folhas; no topo da copa, nenhuma.

**Causa raiz:** escolhi o tamanho da fruta pela escala real (0,3 m) e sorteei os pontos em toda a copa (elevação −25° a +35°). Do chão, a 12 m, uma fruta de 0,3 m ocupa poucos pixels, e as do alto da copa ficam escondidas pela própria folhagem.

**Evidência:** captura `03_perto_arvore_verde_adulta` antes e depois; com 0,45 m e pontos entre −30° e +15° da copa, as frutas aparecem na borda de baixo, e as cerejas caídas ficam nítidas no chão.

**Correção:** frutas a 0,45 m (estilizadas), pontos na faixa média-baixa da copa e 0,6 do raio da fruta para fora da folhagem (`tools/blender/preparar_natureza.py`).

**Como detectar de novo:** fotografar da altura dos olhos do jogador, não de cima.

## 2026-10-01 — campo novo do catálogo sumia ao salvar (lista fixa no salvar_catalogo)

**Sintoma:** depois de marcar `crops` como atravessável, `test_ilha_inicial` e `test_editor_mapa` viram `atravessavel("crops") == false`; o campo não estava no `catalogo.json`.

**Causa raiz:** `BibliotecaDeModelos` tem TRÊS lugares por campo opcional: `_normalizar` (leitura), a lista de campos preservados em `adicionar` (reimportação) e `salvar_catalogo`, que monta cada entrada campo a campo. Pus o campo nos dois primeiros e esqueci o terceiro: em memória valia, no arquivo não.

**Evidência:** `grep atravessavel catalogo.json` vazio depois da primeira execução; com a linha no `salvar_catalogo`, aparece e os dois testes passam (4 plantações sem colisão; plantação inserida sem colisão, casa com).

**Correção:** `salvar_catalogo` grava `atravessavel`. Campo opcional novo na loja = mexer nos três lugares e testar RELENDO o arquivo (outra instância da biblioteca), não a mesma que gravou.

**Como detectar de novo:** os testes leem o catálogo do disco numa execução separada da ferramenta que gravou.

## 2026-10-01 — "pico de 10 ms" dos animais era um quadro isolado lido pelo monitor errado

**Sintoma:** a medição de custo mostrou a física com animais em 10,7 ms de média (pico 34 ms) na segunda passagem pela fazenda, contra 1,5 ms sem eles.

**Causa raiz:** dois problemas misturados. (1) `Performance.TIME_PHYSICS_PROCESS` só muda cerca de uma vez por segundo — o mesmo 32,52 ms se repetiu por 55 quadros seguidos. Um único quadro lento (o teleporte do jogador, que custou 33 ms de relógio enquanto os 23 bichos custaram 0,97 ms) virou "média" alta. (2) Havia também um defeito real, achado ao cronometrar bicho por bicho: uma ovelha raspando a plantação `crops` (colisão côncava de 35 mil triângulos de folha) gastava 2–5 ms por `move_and_slide`, e o detector de "empacou" não percebia porque media deslocamento, não progresso até o destino.

**Evidência:** cronometragem direta em volta do `_physics_process` de cada animal: antes, ovelha a 2–5 ms/quadro por ~5 s; depois, nenhum quadro acima de 1,5 ms por animal em 2.400 quadros e 23 bichos ativos a 0,3–1,6 ms/quadro no total.

**Correção:** o teste mede com cronômetro direto, não com o monitor. O passeio e a fuga só aceitam destino com caminho livre (raio na altura do joelho, recusando peça que não é relevo); "empacou" agora é 1,5 s sem chegar 0,5 m mais perto; `max_slides = 3`; bicho parado e apoiado pula o `move_and_slide`.

## 2026-10-01 — corgi com a pata 7 cm dentro do chão ao "pastar"

**Sintoma:** `test_animais.gd` mediu a base da malha do corgi 7 cm abaixo da origem do corpo com o bicho parado.

**Causa raiz:** o animador procedural dos 22 animais de malha única simulava "pastar" inclinando o CORPO INTEIRO (rot.x +0,16 rad) em volta da origem do modelo. Sem esqueleto não dá para baixar só a cabeça: a frente desce, e a pata dianteira (o canto da malha) entra no chão em comprimento/2 × sen(θ). O mesmo valia para o balanço do trote, o bote de ataque e o tombo da morte (deitar de lado afundava meio corpo).

**Evidência:** corgi −0,07 m na primeira rodada; depois da correção, os 22 estáticos dentro de ±3 cm, e a vaca trotando sobe e desce 0,06 m sem afundar.

**Correção:** `AnimadorDeAnimal` guarda os vértices da faixa mais baixa da malha (12 % da altura, até 96) e corrige cada pose para o pé mais baixo ficar na altura de repouso; o balanço do passo é somado depois. O "pastar" do quadrúpede virou olhar em volta (giro em Y), porque inclinar o corpo todo levantava a traseira.

## 2026-10-01 — Depois de andar na parede, os pés ficavam cerca de 81 cm acima do chão

**Sintoma:** no Modo História, andar na parede e voltar ao chão deixava o personagem flutuando, inclusive parado. A inclinação do corpo na parede também era apagada.
**Causa raiz:** `PlayerArremesso.apresentar()` roda após a orientação de locomoção em todo quadro. Mesmo inativo e sem arremesso anterior, tratava qualquer `modelo.rotation.x != 0` como pose sua a restaurar; zerava X e escrevia `_rest_y`, ainda inicializado em zero. O rig havia assentado a raiz em Y=-0,809861. A cambalhota acabava guardando a altura já errada como repouso. `cancelar()` tinha a mesma suposição de posse pela inclinação.
**Evidência:** três ciclos reais de W + pulo + agarrar parede + pulo de saída no mapa fixo do Modo História. Controle com os métodos antigos: raiz Y=0 e pés cerca de +0,80 m após cada pouso; 11 falhas no teste. Corrigido: raiz Y=-0,809861 nos três pousos, pés a menos de 4 cm do piso, zero falhas. Capturas comparáveis em Weston isolado também mostram a diferença.
**Correção:** `src/player/player_arremesso.gd` guarda explicitamente se tomou a pose em `iniciar()`. Só escreve ou restaura enquanto essa posse está pendente; ao terminar ou cancelar, devolve o controle. A restauração final considera também o deslocamento vertical residual e o cancelamento restaura Y mesmo se outra rotina já zerou X.
**Como detectar de novo:** `tools/dev_tests/test_pouso_parede.gd` cobre três ciclos de parede/pouso, posição dos pés, escala e arremesso inativo/ativo/finalizado/cancelado. `test_boss_arremesso_jogador.gd` cobre a derrubada real pelo chefe.

## 2026-10-01 — Corpo pairava ~14 cm acima do chão ao andar/correr: bob do quadril medido contra a altura AGACHADA

**Sintoma:** o dono viu (print de 01/10 11:25) os pés do jogador sem encostar no chão ao andar e correr, com a poeira dos pés saindo do chão abaixo deles, e perguntou se o modelo estava fora da hitbox.
**Causa raiz:** não era a hitbox. `ProceduralAnimator._bob_dos_pes` calcula quanto o quadril sobe/desce para o pé mais baixo encostar no chão, mas usava como referência `-_altura_quadril()` — a altura AGACHADA da marcha (0,70 da perna andando, 0,66 no sprint) — em vez da profundidade do pé na pose de REPOUSO, que é a que encosta no piso. A IK punha o pé de apoio exatamente nessa altura agachada, o bob dava zero e o quadril não descia: o corpo pairava (1 − 0,70) × perna ≈ 14 cm. Já tinha sido medido em 08/09 (`RigDetalhado.gd`, "paira 13-14 cm") e ficou anotado como pendente.
**Evidência:** pé mais baixo − chão, por quadro no chão: parado −2,3 cm; andando +14,0 (mín +10,6); correndo +13,3; boneco andando +12,3. Depois: andando +2,2 (−1,2 a +2,8), correndo −0,2, parado igual. `test_walk_run`: altura do pé de apoio continua variando 0,0000 e o deslize igual (45–46%).
**Descartado:** colisor (cápsula/caixa) e posição do modelo — parado o pé encosta (−2 cm) com os dois colisores; poeira (nasce a −0,92 m do corpo por desenho, não mede nada).
**Correção:** `src/anim/ProceduralAnimator.gd` — `_bob_dos_pes` devolve `_profundidade_do_pe_em_repouso() − mais_baixo` (mesma conta com as rotações de repouso). Vale para arena e história (mesmo animador).
**Como detectar de novo:** medir o ponto mais baixo do modelo contra o chão ANDANDO, não parado (`tools/dev_tests/medir_rig_detalhado.gd`, seção ASSENTAMENTO); um teste parado não pega.

## 2026-10-01 — Painel do pincel de relevo invadia o painel lateral no modo "Pintar solo"

**Sintoma:** na captura do editor com o pincel em "Pintar solo", o painel do pincel passava por baixo do painel lateral da direita e a "Força" ficava cortada.
**Causa raiz:** o painel era uma linha só, centrada no meio da TELA; com o seletor de solo visível ficava com ~800 px, mais largo que a faixa livre do 3D entre a loja (228 px à esquerda) e o painel lateral (310 px à direita).
**Evidência:** captura `pincel_3_rocha.png` antes/depois: em duas linhas e centrado na faixa livre, o painel cabe inteiro (~550 px).
**Descartado:** tamanho dos sliders sozinho (encurtar não resolvia a soma com o seletor).
**Correção:** `src/editor_mapa/painel_do_pincel.gd` em duas linhas (modos + solo; raio + força); `EditorDeMapa` desloca o centro do painel para o meio da faixa livre.
**Como detectar de novo:** captura do editor com a ferramenta Relevo em cada modo (o teste do pincel só confere comportamento, não layout).

## 2026-10-01 — Trocar o colisor do jogador por cápsula quebrou o combate: os golpes acertavam o colisor de MOVIMENTO

**Sintoma:** depois da cápsula (raio 0,4) no Modo História, `test_contato_historia` caiu com 14 problemas (8 de 20 golpes laterais sem contato, troca de jabs sem os dois acertos) e `test_defesa_historia` com 5.
**Causa raiz:** três coisas em cadeia. (1) A varredura do combate direcional (`SwordSweep`) acerta a forma de colisão do CORPO — a mesma que anda. Os ganchos foram afinados contra a caixa de 0,5 m de meia largura; a cápsula de 0,4 é mais estreita e os arcos passavam por fora. (2) A hurtbox separada criada para resolver isso, como `StaticBody3D` filho do corpo, fica UM QUADRO atrás no servidor de física (teleporte e `move_and_slide`). (3) Com raio 0,4 os lutadores chegavam a 0,8 m (a caixa os travava a 1,0 m): quem é processado primeiro avançava e acertava antes, e a troca simultânea de jabs deixava de existir.
**Evidência:** teste isolado da hurtbox: "servidor_x" sempre o valor do quadro anterior; com `sincronizar` a posição bate no mesmo quadro. Com hurtbox + raio 0,4: contato 14 → 2 problemas (só a troca); com raio 0,5: contato, defesa, aparo, combate e ilha verdes. `test_inimigo_lutador` falha 1 em 6 tanto com a caixa antiga quanto com a cápsula (instabilidade da IA que já existia).
**Descartado:** atraso da hurtbox como causa da troca de jabs (sincronizada, a falha continuou; era a distância entre corpos).
**Correção:** `src/combat/direcional/hurtbox_de_combate.gd` (caixa 1 × 1,6 × 1 na camada 21, sem `take_damage`, dono pela meta; `SwordSweep` a troca pelo dono e não a trata como parede; executor varre a camada; `ator.excluir` tira a própria); `sincronizar` logo após `move_and_slide` (Player, boneco); `RAIO_DA_CAPSULA` 0,5.
**Como detectar de novo:** `./validar.sh contato_historia defesa_historia aparo_historia combate_historia ilha_inicial`.

## 2026-10-01 — Jogador parava a 1,6–4,7 m das casas: trimesh com base/varanda baixa contra caixa sem degrau

**Sintoma:** andando contra casas da vila, o jogador parava às vezes a 1,6, 3,6 e 4,7 m da parede (em vez de ~0,5 m), contra nada visível na altura do peito.
**Causa raiz:** a colisão das casas era a malha visual inteira (trimesh). Bases de pedra, varandas e degraus baixos do kit são beiradas de poucos centímetros; a caixa do jogador não sobe degrau nenhum, então empacava na beirada, metros antes da parede. A trimesh ainda tem arestas soltas onde corpo nenhum desliza.
**Evidência:** antes (caixa + trimesh): paradas de 0,54 a 4,72 m da parede em 6 casas. Depois (cápsula + partes convexas, 97 construções, cobertura 99,3–100 %): mediana 0,47 m em 8 construções (`test_ilha_inicial`); partes desenhadas sobre a vila seguem telhado, paredes e base.
**Descartado:** modelo grande demais para trimesh (todas as casas < 12 mil triângulos, colisão era malha mesmo).
**Correção:** `BibliotecaDeModelos` — campo "colisao": "partes" + `<id>.colisao.json` (pontos das partes, com SHA do .glb; SHA diferente = volta à malha); `MapaMontador` pendura Colisao, Colisao_2…; editor desenha as partes (H); gerador `tools/mapa_ilha/gerar_colisao_de_construcoes.gd`.
**Como detectar de novo:** `test_ilha_inicial.gd` B ("encostando em N construções") e `test_terreno_mapa.gd` D4.

## 2026-10-01 — Pés do jogador flutuando até 27 cm em encosta: colisor CAIXA apoia numa quina

**Sintoma:** o dono notou "uma diferença notável entre os pés e o chão" na Ilha Inicial.
**Causa raiz:** o colisor do Player é uma `BoxShape3D` de fundo reto (1 × 1,6 × 1). Em encosta a caixa apoia numa QUINA (a borda de baixo da caixa no lado de cima do morro) e o centro — onde o modelo põe os pés — fica no ar. No chão plano da arena nunca apareceu; o relevo novo tem encosta em quase todo lugar.
**Evidência:** pé do modelo − chão (raio sob o centro): 0° −2 cm; 4,6° +11 cm; 21° +27 cm. Com cápsula (raio 0,4, altura 1,6): todos entre −2,4 e +1,6 cm; em `test_ilha_inicial` maior folga 2,2 cm.
**Descartado:** deslocamento do modelo em relação ao colisor (no plano o pé fica a −2 cm, encostado).
**Correção:** `Player.colisor_capsula` (CapsuleShape3D r 0,4 × 1,6), ligado SÓ no Modo História por `ModoHistoria.colocar_civil` (decisão do dono: arena continua com a caixa); `BonecoDeDuelo` também em cápsula; escala de raça e `topo_da_cabeca` tratam os dois formatos.
**Como detectar de novo:** `test_ilha_inicial.gd` B — "pés no chão nas encostas" (< 6 cm) e "colide como CÁPSULA".

## 2026-10-01 — Jogador travava no MEIO do deck liso: colisão = malha visual inteira, arestas rentes ao piso

**Sintoma:** com o topo do deck já liso (degrau medido 0,004 mm), o Player ainda parava a ~8 m da entrada da ponte; `is_on_wall()` verdadeiro com normal horizontal contra o caminho, mas `get_slide_collision` só listava contato de chão.
**Causa raiz:** a colisão da peça `modelo` era a malha INTEIRA do .glb (trimesh). No GodotPhysics cada triângulo conta sozinho: travessas dos cavaletes e o capeamento das cabeceiras encostam por baixo no plano do piso, e a aresta de cima dessas faces verticais vira uma "parede de altura zero" que prende a caixa do jogador (`BoxShape3D` 1 × 1,6 × 1).
**Evidência:** caixa simples (`CharacterBody3D` + mesma caixa) nascendo em cima do deck real travou a 11,9 m com e sem terreno; a mesma caixa num arco SINTÉTICO só com o piso (64, 16, 8 trechos e duas rampas) atravessou todos. Depois da malha `Colisao` (piso + paredes, 396 triângulos): o Player real atravessou as duas pontes (48,3 m e 46,0 m), `test_ilha_inicial` 20/20.
**Descartado:** vinco côncavo do arco em faixas (o sintético com 64 faixas passou); terreno furando o deck (terreno ≥ 1,4 m das pontas fica abaixo do deck; varredura terra × deck); degrau no topo (varredura de 5 em 5 cm, 0 saltos > 1 cm); estado de parkour (escalada/parede todos falsos).
**Correção:** `BibliotecaDeModelos` — malha cujo nome começa com "Colisao" vira a ÚNICA colisão do modelo, fica invisível e fora da caixa envolvente (`medir`, `_faces_do_modelo`, `_esconder_colisao`); `tools/blender/ponte_rio.py` exporta o objeto `Colisao`. Sem "Colisao", tudo como antes.
**Como detectar de novo:** `test_ilha_inicial.gd` (jogador atravessa as pontes) e `test_terreno_mapa.gd` D3 (malha de colisão separada e escondida).

## 2026-09-30 — Duas areias de cores diferentes lado a lado: modelo .glb (material comum) ao lado do terreno (cel shader)

**Sintoma:** nas capturas da ilha a praia tinha duas faixas: a areia do terreno (amarelada, viva) e, logo depois, os módulos de areia da loja (cinza-bege, chapados) — leitura de "praia dupla".
**Causa raiz:** o terreno usa o cel shader do jogo (luz em faixas, cor por vértice) e o módulo da loja usa o material do próprio .glb (StandardMaterial). Mesma cor nominal, sombreamento diferente; e o ambiente (`WorldEnv`) ainda soma +18 % de saturação, o que separa mais as duas.
**Evidência:** captura `06_porto` antes/depois; com o anel de praia feito de blocos de terreno a areia ficou contínua.
**Descartado:** cor do módulo (a cor nominal dele, #dec294, é praticamente a do terreno).
**Correção:** a praia virou um anel de blocos `terreno` em volta da baseplate (`_anel_de_praia`), descendo até abaixo do mar; o módulo de areia continua na loja, mas o gerador não o usa.
**Como detectar de novo:** ao misturar chão modelado (.glb) com terreno, comparar numa captura do jogo, não pela cor no arquivo.

## 2026-09-30 — Blocos de terreno com escalas verticais diferentes abriam degrau de até 0,56 m na foz do rio

**Sintoma:** o teste de emendas da Ilha Inicial achou 1.024 pontos da borda da ilha com altura diferente no bloco da ilha e no bloco do anel de praia; o pior, 0,56 m na foz do rio (uma parede/buraco entre a areia e o barranco).
**Causa raiz:** duas coisas. (1) O anel de praia começava SEMPRE em 4 cm, mas na foz o barranco do rio (aplicado depois da costa) subia a 0,6 m exatamente na borda. (2) Mesmo onde as duas alturas eram "iguais", a ilha guardava a altura em frações de 29 m (passo 2,9 mm) e o anel em frações de 3 m sobre base −1,5 (passo 0,3 mm): o mesmo ponto virava números diferentes — diferença de ~0,7 mm, acima do 0,5 mm que já deu pontinho preto na areia.
**Evidência:** script de depuração listou os pares (ex.: `relevo_4_0` y=0,597 × `praia_18` y=0,040 no mesmo ponto). Depois da correção: 5.697 pontos compartilhados, diferença máxima 0,000000 m.
**Descartado:** espaçamento dos pontos (vértice solto/T-junction): 1.024 pontos da borda, todos com par.
**Correção:** `tools/mapa_ilha/gerar_ilha.gd` — TODOS os blocos (ilha e praia) com a mesma base (−1,5 m) e o mesmo tamanho Y, uma função só (`_fracao`) para converter altura em inteiro, e o anel parte da altura EXATA do ponto de borda da ilha (`_altura_praia`).
**Como detectar de novo:** `test_ilha_inicial.gd` A2 — emendas exatas (< 0,5 mm) e nenhum ponto de borda sem par.

## 2026-09-30 — Jogador trava na entrada da ponte: colisor do Player é CAIXA e não sobe degrau

**Sintoma:** no teste da Ilha Inicial o jogador (Player real, W pressionado) parava a 4 m da ponte, `velocity` zerada, colisão com normal horizontal (0,93; 0; −0,37) = de volta pela estrada. Visualmente a ponte estava perfeita.
**Causa raiz:** o colisor do Player é uma `BoxShape3D` (`Player.COLISOR_BASE` 1 × 1,6 × 1, fundo reto) e `CharacterBody3D` com caixa não sobe degrau nenhum. A cabeceira de terra ficava 5 cm ABAIXO da ponta do deck (a ponta das tábuas tem face de 10 cm) — uma parede de 5 cm. Depois de corrigida a cabeceira, o jogador parou de novo a 6,8 m: o relevo geométrico de 2 cm das tábuas é uma sequência de degraus verticais.
**Evidência:** rastro do jogador a cada 20 quadros (`avanco` 4,34 m parado, colisor `ponte_vila_ponte_sul`); pés em y = 2,32 contra deck em 2,37. Com a terra a +3 cm o avanço passou para 6,8 m e parou na primeira tábua.
**Descartado:** guarda-corpo/pilares (o jogador estava no eixo, vão útil 4,36 m); ponte girada errada (o eixo bate com o rumo da estrada); queda no rio (menor altura sempre acima do deck).
**Correção:** `tools/mapa_ilha/gerar_ilha.gd` (`_cabeceiras`) põe a terra 3 cm ACIMA da ponta do deck — o deck emerge do chão sem face exposta; `tools/blender/ponte_rio.py` com topo do deck liso (tábuas só na cor).
**Como detectar de novo:** `tools/dev_tests/test_ilha_inicial.gd` atravessa as duas pontes com o Player de verdade e exige avançar o comprimento todo sem cair abaixo do deck.

## 2026-09-30 — pontinhos pretos na areia da praia (compressão de vértices da importação)

**Sintoma:** na captura `03_areia_perto.png` da praia apareciam 4 pontinhos pretos (3×3 px, RGB ~2,2,2) sobre a areia, sempre nos mesmos pixels. Ninguém tinha notado; a captura e o validador passavam.
**Causa raiz:** o GLB da areia tem 5 materiais (tons de areia), então vira 5 superfícies. A importação do Godot 4.6 comprime os vértices (`meshes/force_disable_compression=false`, padrão): cada superfície é quantizada em 16 bits pelo PRÓPRIO AABB, então o mesmo vértice compartilhado por duas cores cai em posições diferentes por submilímetros. Nas arestas entre cores abrem fendas e, quando uma cobre o centro de um pixel, o fundo escuro aparece. Num módulo de 32 m o passo da grade é ~0,5 mm — raro, mas visível.
**Evidência:** script descartável com a mesma câmera: 4 pontos com a malha importada; 4 com e sem LOD (`mesh_lod_threshold=0`); 4 recriando a malha a partir dos arrays já descomprimidos (a quantização persiste); 1 com o GLB carregado em runtime (outra quantização, outras fendas); **0** com a malha montada dos arrays crus do GLTF sem compressão. Raio da câmera nos 4 pixels acerta a própria `amostra_areia_2`; escondendo a areia os pontos somem.
**Descartado:** costura entre módulos (os pontos não caem nas linhas projetadas de z=-40/-72); geração de LOD (mesma contagem com LOD desligado); marcador desenhado pelo validador (ele não desenha nada).
**Correção:** `mapas/modelos/areia_praia_low_poly.glb.import:29` → `meshes/force_disable_compression=true` + reimportação. Recaptura: 0 pontos nas fotos 02/03/04; `tools/validar_praia.py --capturar` PASS (mar 25,95%), mapa preservado (sha 00945145…), `./validar.sh praia_oceano modo_historia editor_mapa loja_modelos grupos_editor` 5/5.
**Como detectar de novo:** contar pixels escuros isolados na areia (escuro < 70 com vizinhos a 2 px > 140) nas capturas de `art_src/validation/praia/`; deve dar 0. Vale para qualquer GLB grande com várias cores (terreno, rocha, cais).

## 2026-09-30 — Gaivota pousada ao lado do dono nunca decolaria: limiar de deslocamento comparado POR QUADRO

**Sintoma:** (pego na revisão, antes de rodar) no modo seguir, a gaivota pousada junto do dono deveria decolar quando ele andasse; a condição nunca disparava.
**Causa raiz:** `_dono_andou()` devolve o deslocamento do dono desde a ÚLTIMA leitura e atualiza a referência a cada quadro em que ele se moveu; comparar isso com 1 m nunca é verdade (a 4,2 m/s o dono anda 0,07 m por quadro).
**Evidência:** leitura do código: `_dono_antes` é reatribuído sempre que `andou > 0.05`; velocidade de caminhada 4,2 m/s a 60 Hz = 0,07 m/quadro.
**Descartado:** —
**Correção:** decolar pela VELOCIDADE do dono (> 1,5 m/s) ou distância > 4,5 m (`src/historia/pets/gaivota.gd`, `_no_chao`).
**Como detectar de novo:** limiar de distância só vale contra uma referência FIXA (onde pousou), nunca contra a posição do quadro anterior.

## 2026-09-30 — Inventário N aparecia como retângulo vazio da altura da tela: rótulo com quebra de linha sem largura

**Sintoma:** na captura, o inventário era um painel escuro de 600 px de largura e 720 de altura, sem cabeçalho nem conteúdo visíveis.
**Causa raiz:** a descrição de cada pet era um `Label` com `autowrap_mode` dentro de um VBox/HBox sem largura fixa; o Godot mede a altura mínima desse rótulo com largura ZERO (uma letra por linha), o painel crescia para milhares de pixels e, centralizado, mostrava só o meio vazio.
**Evidência:** `art_src/pets/gaivota/jogo/01_inventario_pets.png` antes (retângulo vazio) e depois de `custom_minimum_size.x = 340` (painel de 600×312 com tudo visível).
**Descartado:** `reset_size`/âncoras do painel — o tamanho mínimo já vinha errado do conteúdo.
**Correção:** largura mínima na descrição (`src/ui/InventarioDaHistoria.gd`, `_montar_pets`).
**Como detectar de novo:** todo `Label` com autowrap em container precisa de `custom_minimum_size.x`; teste visual com janela (headless não mostra) ou `get_combined_minimum_size().y` absurdo.

## 2026-09-30 — Catálogo da loja descarta campo desconhecido: campo novo precisa entrar em _normalizar E em salvar_catalogo

**Sintoma:** (evitado) marcar o boneco com `"comportamento"` direto no `catalogo.json` sumiria no próximo salvamento da loja.
**Causa raiz:** `BibliotecaDeModelos._normalizar` monta a entrada só com os campos que conhece (id, nome, sha256, centro, tamanho, triangulos, categorias) e `salvar_catalogo` grava só esses; qualquer outro campo é lido e jogado fora na primeira gravação (renomear, marcar categoria, importar).
**Evidência:** leitura de `src/world/biblioteca_modelos.gd` (`_normalizar` e `salvar_catalogo`); depois da mudança, o catálogo do dono comparado com a cópia: 263 modelos e categorias idênticos + a entrada nova com `comportamento` preservado.
**Descartado:** editar o JSON à mão.
**Correção:** `comportamento` entrou no normalizador (validado no alfabeto do id), no salvamento e ganhou `comportamento_do_modelo`/`definir_comportamento`.
**Como detectar de novo:** todo campo novo do catálogo: gravar, renomear um modelo e reler — o campo tem de sobreviver.

## 2026-09-30 — test_progressao: "100%," dentro de string formatada gerava ERROR no log há semanas

**Sintoma:** `ERROR: String formatting error: unsupported format character.` no log do `test_progressao`, que mesmo assim passava.
**Causa raiz:** a mensagem da checagem [9] era `"… 100%, −1 75%, … (%s)" % str(obtido)`: o `%` literal seguido de vírgula vira especificador inválido no operador `%` do GDScript; a formatação falha e a mensagem sai sem o valor.
**Evidência:** backtrace `_inimigos (tools/dev_tests/test_progressao.gd:140)`; a mesma linha estava assim na cópia de antes desta tarefa.
**Descartado:** erro do código de progressão — era só a mensagem do teste.
**Correção:** `%%` nos percentuais literais (`tools/dev_tests/test_progressao.gd:140`); log agora com 0 erros.
**Como detectar de novo:** "log limpo faz parte do PASS": `grep -c "^ERROR" log` depois de cada suíte, não só o código de saída.

## 2026-09-30 — Avisos do boneco ainda diziam "M → TESTE" depois de a seção ir para o F8

**Sintoma:** o aviso na tela ao invocar/derrotar o boneco de duelo mandava o jogador a "M → TESTE", seção que não existe mais na janela M.
**Causa raiz:** na tarefa da janela de Status (mesmo dia) eu movi as ferramentas para o F8 e atualizei docs e testes, mas procurei o caminho antigo só em `docs/`; os textos de `_hud.avisar(...)` em `src/historia/ModoHistoria.gd` (e três comentários) ficaram com o caminho velho.
**Evidência:** `grep -n "M → TESTE" src/historia/ModoHistoria.gd` → 2 avisos + 3 comentários, achados só na tarefa seguinte.
**Descartado:** —
**Correção:** avisos trocados para "F8 troca o modo"/"F8 invoca outro"; comentários do cabeçalho atualizados (`src/historia/ModoHistoria.gd`).
**Como detectar de novo:** depois de mover um caminho de interface, `grep -rn "<caminho antigo>" src docs tools`.

## 2026-09-30 — Janela de Status larga cortava as barras do HUD e ficava sob o aviso de nível

**Sintoma:** na captura da janela nova, "VIDA 20/20" e "ENERGIA 1…" apareciam cortadas pela borda esquerda da janela, e "Level Up!…"/"Você comeu a Rocket" caíam em cima da linha de Raça/Nível.
**Causa raiz:** com 1040 px a janela passou a cobrir x 120–1160 e y ~42: as barras do `VidaEnergiaHud` (x 20–360, y 20–86) ficaram meio por baixo; o `_aviso` (y 100–136) era criado DEPOIS da janela no mesmo CanvasLayer, então desenhava por cima. Pôr o aviso atrás também não bastou: com fundo a 96% o texto contornado vazava.
**Evidência:** capturas `status_historia/00`–`03` antes da correção; depois, as mesmas sem corte nem vazamento.
**Descartado:** mover o aviso para trás da janela (`move_child`) — vazava pelo fundo translúcido.
**Correção:** enquanto o Status está aberto, `HistoriaHud._process` esconde as barras do canto e o aviso (que fica armado e volta ao fechar) — `src/ui/HistoriaHud.gd`.
**Como detectar de novo:** captura com janela da tela de Status com aviso ativo; `test_modo_historia` confere aviso armado-e-escondido com a janela aberta e visível ao fechar.

## 2026-09-30 — Em headless a tela mede 1280×1280: teste de "cabe em 720" headless não prova nada

**Sintoma:** o teste de layout imprimiu `tela (1280.0, 1280.0)` para um projeto de 1280×720.
**Causa raiz:** rodando com `--headless` o viewport raiz não tem a janela de 1280×720 do projeto; o tamanho visível sai 1280×1280, então "a janela cabe na tela" passa com folga que em 720 não existe.
**Evidência:** a mesma janela, capturada com janela real (`--resolution 1280x720`), media 1040×674 e PRECISAVA de rolagem no estado bloqueado (578 px de conteúdo para 568 disponíveis) — o headless não acusou.
**Descartado:** —
**Correção:** a prova de altura vem da captura com janela (`get_root().get_visible_rect()` = 1280×720, `art_src/validation/status_historia/`); o teste headless ficou com o que ele consegue provar (conteúdo = altura mínima da rolagem, centralização, largura).
**Como detectar de novo:** imprimir `get_viewport_rect().size` em todo teste de layout; se não for a resolução do projeto, medir com janela.

## 2026-09-30 — ScrollContainer do Godot 4.6 tem TextureRect internos: "nenhuma imagem na janela" reprova à toa

**Sintoma:** checagem "nenhum ícone nem emoji na janela" reprovou com lista de caracteres vazia.
**Causa raiz:** `find_children("*", "TextureRect", true, false)` devolve dois `TextureRect` INTERNOS do `ScrollContainer` (as dicas de rolagem do Godot 4.6), escondidos e sem textura do projeto.
**Evidência:** sonda: `@ScrollContainer@15/@TextureRect@13` e `@TextureRect@14`, pai `ScrollContainer`.
**Descartado:** ícone de verdade na janela — não havia nenhum.
**Correção:** a checagem conta só `TextureRect` visível e com `texture` atribuída (`tools/dev_tests/test_modo_historia.gd`, `_visual_do_status`).
**Como detectar de novo:** ao procurar tipo de nó em UI com `find_children`, filtrar por `is_visible_in_tree()` e pelo recurso atribuído.

## 2026-09-30 — Seção TESTE da janela de Status "só em desenvolvimento" aparecia sempre para o dono

**Sintoma:** o dono via "+100 XP", "+1.000 XP", "Reiniciar campanha" etc. na janela de Status (M) jogando normalmente, e pediu para tirar da interface.
**Causa raiz:** a seção era guardada por `OS.is_debug_build()`, mas o projeto não tem export templates: o jogo SEMPRE roda pelo editor/lançador como build de desenvolvimento, então a guarda nunca escondia nada.
**Evidência:** `export_presets` sem template instalado (memória do projeto: "roda via lançador .desktop, sem export templates"); a seção aparecia em toda sessão.
**Descartado:** —
**Correção:** os botões foram para um painel próprio na F8 (`src/ui/FerramentasDeTeste.gd`), ainda só em desenvolvimento, fora da janela de Status; `ModoHistoria` liga os sinais no painel.
**Como detectar de novo:** `test_modo_historia` B9b ("a janela de Status não tem mais botões de teste" + controle no painel F8). Regra: "só em debug" não é esconder enquanto não houver build de exportação.

## 2026-09-30 — Duas sessões do Claude editando os mesmos arquivos da Rocket ao mesmo tempo

**Sintoma:** um `str.replace` meu no teste falhou por texto não encontrado; o arquivo tinha ganho, sozinho, testes quase idênticos aos que eu ia escrever.
**Causa raiz:** a sessão caiu no meio de uma pergunta (AskUserQuestion) e foi retomada em outro processo (PID 35991, 07:48); o processo antigo (PID 9799, 07:35) continuou trabalhando a mesma tarefa com o mesmo contexto e passou a escrever nos mesmos arquivos.
**Evidência:** `test_fruta_rocket_historia.gd` alterado às 07:49:53 e 07:50:26, depois da minha última leitura; dois `native-binary/claude` no `ps`.
**Descartado:** edição do dono ou do Codex — conteúdo e estilo idênticos aos meus (`_no_chao`, "decolou e VIROU o foguete").
**Correção:** parei de escrever e perguntei; o dono escolheu esta sessão; os testes da outra foram lidos, conferidos e mantidos.
**Como detectar de novo:** antes de editar após retomada, `stat -c %y` nos arquivos-alvo e `ps aux | grep native-binary/claude`.

## 2026-09-30 — Roteiro de captura: escrever Player._yaw sem _update_pivot() deixa a câmera parada

**Sintoma:** nas capturas o voo do F e os retículos do X pareciam sair ~34° à esquerda da mira.
**Causa raiz:** o roteiro escrevia `Player._yaw`/`_pitch` direto; quem gira a câmera é `_update_pivot()` (chamado pelo `_input` do mouse e por `aplicar_mira`). A câmera ficava em yaw 0 enquanto o jogo usava 0,6 — artefato do roteiro, não bug do jogo.
**Evidência:** sonda: `_yaw=0.6` → `-_cam.basis.z` = (0,0,−1), `RosaDosVentos.frente(0.6)` = (−0,56,0,−0,83), 34,4° de diferença; recaptura com `_update_pivot()` = voo e X reto para a mira.
**Descartado:** `_mira_do_voo` errado — em jogo real todo movimento de mouse passa por `_update_pivot()`, câmera e `_yaw` andam juntos.
**Correção:** roteiro de captura chama `j._update_pivot()` depois de mexer em yaw/pitch.
**Como detectar de novo:** em teste/captura que mexe em `_yaw`, comparar `-_cam.global_transform.basis.z` com `RosaDosVentos.frente(_yaw)`.

## 2026-09-30 — "ObjectDB instances leaked" na suíte da Rocket era SOM tocando no quit(), não timer pendente

**Sintoma:** `WARNING: ObjectDB instances leaked at exit` em 3 de 3 rodadas de `test_fruta_rocket_historia` (0 na linha de base), sem falha de checagem.
**Causa raiz:** o processo fechava com um `AudioStreamPlayer3D` ainda tocando (canhão do pilar do C / whoosh do puff); o motor reporta o `AudioStreamWAV` + `AudioStreamPlaybackWAV` em curso como vazados. Ficou visível porque o voo novo leva ~5,1 s e a seção do indicador só esperava 240 quadros (4 s): a fruta era tirada NO AR e o puff tocava perto do fim.
**Evidência:** sonda: sair 5 quadros após o pouso = aviso; 4 s depois = limpo. `--verbose`: `Leaked instance: AudioStreamWAV`, `AudioStreamPlaybackWAV`. Instrumentação no `_fim`: `TOCANDO: .../@AudioStreamPlayer3D@897 pos=0.72`.
**Descartado:** MEU 1º diagnóstico — "é o `FxUtil.autofree` (SceneTreeTimer + lambda) pendente no quit" — foi afirmado e implementado (troca por Timer filho) SEM checar as classes vazadas; o aviso continuou. Revertido para a convenção do projeto.
**Correção:** `_fim` espera o último som acabar (até 3 s) antes do `quit()`; espera do voo na seção 15 subiu para 480 quadros (`tools/dev_tests/test_fruta_rocket_historia.gd`).
**Como detectar de novo:** `grep -c leaked` no log; se aparecer, `--verbose` na menor sonda que reproduz e ler a linha `Leaked instance:`.

## 2026-09-30 — Vector3.slerp com vetores quase opostos enche o log de "axis must be normalized"

**Sintoma:** 38 linhas `ERROR: The axis Vector3 (-1.001923, 0.0, 0.0) must be normalized` numa rodada da suíte da Rocket (0 na linha de base).
**Causa raiz:** meu `_aproximar` em `forma_de_foguete.gd` usava `Vector3.slerp`; com os dois vetores quase opostos (nariz para cima × velocidade parada/para baixo) o eixo interno do Godot sai com norma 1,0019 > tolerância e `Basis.set_axis_angle` reclama. Minha guarda só pegava o caso EXATAMENTE oposto (cross < 1e-6).
**Evidência:** backtrace `_aproximar (forma_de_foguete.gd:113)` → `set_axis_angle (basis.cpp:843)`; depois da troca, 0 erros em 3 rodadas.
**Descartado:** —
**Correção:** rotação própria: `angle_to` + eixo `cross(...).normalized()` (perpendicular construído no caso oposto) + `rotated` — mesma técnica do `VooFoguete._girar`.
**Como detectar de novo:** `grep -c "must be normalized"` no log da suíte; log limpo é parte do PASS.

## 2026-09-30 — Voo da Rocket com quina: velocidade virava 77° num quadro

**Sintoma:** teste do nariz do foguete reprovou: pior alinhamento nariz·velocidade 0,21 na planagem.
**Causa raiz:** `VooFoguete` trocava a velocidade da fase IMPULSO (≈ 77° para cima, 14 m/s) pela da PLANANDO (horizontal, 9 m/s) no mesmo quadro — a trajetória tinha uma quina, e a malha, suavizada, ficava 78° atrás.
**Evidência:** amostra quadro a quadro: p0.02 = 0,21, recuperando até 1,00 em 0,15 s.
**Descartado:** afrouxar o teste para pular a virada — escondia o defeito real da trajetória.
**Correção:** arco de 0,30 s (`VooFoguete.ARCO`, smoothstep da velocidade de subida para a do rumo) + nariz acompanhando a 20/s em `forma_de_foguete.gd`; pior alinhamento 0,91 no arco, 0,99 na planagem medida pelo teste.
**Como detectar de novo:** `test_fruta_rocket_historia` seção 11 ("o nariz do foguete aponta para onde ele vai").

## 2026-09-30 — Rocket F (Blast Off): voo não virava pela câmera

**Sintoma:** "o F não está sendo possível a mudança de direção".
**Causa raiz:** `VooFoguete.velocidade` recebia `q.dir` (WASD em espaço de câmera) e só desviava o rumo no plano quando uma tecla estava apertada; girar a câmera com o mouse — o gesto natural para pilotar — não entrava na conta.
**Evidência:** sonda headless: câmera girada 90° → desvio 0°; D segurado → 88°; S → 176°.
**Descartado:** não era input bloqueado durante o voo (WASD chegava e virava).
**Correção:** o rumo persegue yaw/pitch da câmera (`Player._mira_do_voo`) a 3,2 rad/s, nariz limitado a ±60°, WASD fora (decisão do dono). Armadilha junto: a câmera 3ª pessoa DESCANSA com pitch −0,25 (14° para baixo) — sem tratar isso como nivelado (`PITCH_DE_DESCANSO`) o foguete mergulhava sozinho com o mouse parado.
**Como detectar de novo:** `test_fruta_rocket_historia` seção 11b (90° de câmera = 90° de rumo; D = 0°; mouse parado = variação < 0,3 m).

## 2026-09-30 — Rocket X (Air Strike): 4,3 m de chão sem dano entre as explosões

**Sintoma:** "espaçamento muito grande entre as áreas de dano do X".
**Causa raiz:** `mira_de_rocket.pontos_do_bombardeio` distribuía os 3 pontos por `alcance * (i+1)/pontos` com o alcance INTEIRO da ficha (25 m) → centros a 8,3 / 16,7 / 25 m com raio 2 m; a distância nem dependia da mira (a doc dizia "até a mira", o código usava sempre 25 m).
**Evidência:** 8,33 − 2·2 = 4,33 m de buraco entre vizinhas; depois da correção o golpe real mede centros a [2.5, 5.7, 8.9] m mirando reto e mirando o chão.
**Descartado:** não era o raio da ficha pequeno demais — com 25 m em 3 pontos, qualquer raio < 4,2 m deixaria buraco.
**Correção:** `distancias_do_bombardeio(raio, n)` = folga 0,5 + raio + 2·raio·(1−0,2)·i (encostadas, distância fixa — decisão do dono); deriva do RAIO para mexer no raio não reabrir buraco; `alcance` do X saiu do `rocket.tres` (`src/combat/mira_de_rocket.gd`).
**Como detectar de novo:** `test_fruta_rocket_historia` seção 12b (sobreposição > 0 e distâncias iguais com mira reta/baixa).

## 2026-09-30 — Rocket: "escapamento" com fogo acima da cabeça em qualquer golpe

**Sintoma:** o dono via, em QUALQUER ataque da Rocket (Z/X/C, arena e história), uma espécie de escapamento com fogo nascendo acima da cabeça do jogador.
**Causa raiz:** `rocket_vfx.gd` montava dois bocais metálicos (CylinderMesh + aro emissivo) com fogo, fumaça e OmniLight num nó `_motores` a +0,55 m + offset 0,25 m (≈ altura da cabeça, atrás dela) e acendia tudo com `impulso or sobrecarga`, onde `impulso` = `rocket_controller.ocupado()` — verdade em toda ação da fruta, não só nas de propulsão.
**Evidência:** leitura de `atualizar()`: `_motores.visible = impulso or sobrecarga`; chamada `_fx.atualizar(..., ocupado(), buff > 0)`. Depois da remoção, varredura em Z/X/C conta 0 partículas/luzes acesas no efeito (controle: a mesma varredura acha 3 na forma de foguete do F).
**Descartado:** não era o foguete do Z na mão (esse fica no antebraço) — embora a chaminha dele, acesa no preparo, também ficasse na altura da cabeça e tenha sido apagada até o disparo.
**Correção:** bocais, `_fogo`, `_fumaca`, `_luz` e `_particulas` removidos nos dois modos (decisão do dono); sobra `_ancora` invisível para o foguete na mão (`src/effects/rocket_vfx.gd`); `_missil_chama` só visível em voo.
**Como detectar de novo:** `test_fruta_rocket_historia` seção 14b (`_sem_escapamento`).

## 2026-09-22 — Erro de TIPO num script pré-carregado deixa o jogador SEM COLISOR (e ele atravessa o mundo)

**Sintoma:** no Modo História o jogador caía pelo chão sem parar, morria no void e renascia em ciclo (medido: y indo de 3 a −36, `vy` até −50, `is_on_floor()` sempre falso), e um alvo posto a 12 m sumia da linha de tiro. Parecia bug de colisão do mapa.
**Causa raiz:** uma linha minha em `src/combat/rocket_controller.gd` (`var rumo := alvo.global_position - at`, com `alvo: Node` sem tipo) não compilava. O `Player.gd` faz `preload("res://src/combat/rocket_controller.gd").new()` no `_ready`; com o script dependente quebrado, a chamada vira `Invalid call. Nonexistent function 'new' in base 'GDScript'` e **o `_ready` do Player aborta ali** — antes de criar o colisor (`Player.gd:724-731`), a câmera e o `OpeWeapon`. Corpo sem `CollisionShape3D` atravessa qualquer chão, e nada no jogo diz isso: o erro de parse fica no meio de milhares de linhas de log, e o sintoma aparece na física.
**Evidência:** sonda listando os filhos do jogador — `["PlayerRig", "CombatFSM", "PoeiraDoPe", "GPUParticles3D", "CombateDirecional"]`, sem colisor, sem `CameraRig`; a baseplate tinha colisor certo (`BoxShape3D` 512×2×512, `disabled=false`); log com `Parse Error ... rocket_controller.gd:400` → `Failed to compile depended scripts (Player.gd)` → `_ready (Player.gd:712)`.
**Descartado:** colisão do mapa de teste (o chão estava lá e ativo), camada/máscara (jogador 1/1, piso 1), e o próprio míssil (o jogador já caía sem fruta nenhuma).
**Correção:** tipar a variável (`var rumo: Vector3 = ...`). A regra do projeto que teria evitado o tempo perdido: **rodar `test_compila` depois de editar**, e não só antes.
**Como detectar de novo:** `godot --headless --path . --script tools/dev_tests/test_compila.gd` acusa em segundos. Em jogo, o sinal é o conjunto "jogador atravessa o chão + `is_on_floor()` sempre falso + sem câmera": procure `Parse Error` e `Failed to compile depended scripts` no início do log, não na física.

## 2026-09-21 — Pés do boneco de duelo cresciam a cada golpe, sem parar (escala acumulada no rig)

**Sintoma (reportado pelo dono):** o boneco "Ataca" invocado pela janela M tinha os pés crescendo a cada ataque, sem voltar — "um ciclo infinito de crescimento".
**Causa raiz:** o `AplicadorDePose` escrevia orientação global carregando a escala lida do próprio global: `pe.global_basis = Basis(q) * Basis.from_scale(pe.global_basis.get_scale())` (e o mesmo na IK da perna e, em outra forma, no `_apontar` dos braços). Isso só preserva a escala se TODA a cadeia acima tiver escala uniforme exata. A própria IK deixava a canela com erro numérico mínimo (0,9993/1,0006); com o pai assim, o pé ganhava cisalhamento global (~0,001) e a escrita `R × escala-das-colunas` transformava esse cisalhamento em escala LOCAL do pé — lida ANTES de a IK mover a canela. O `ProceduralAnimator` só escreve `rotation`, que PRESERVA a escala local: o erro de um quadro virava o ponto de partida do seguinte, e crescia cada vez mais rápido.
**Evidência:** sonda com o boneco "Ataca" real: pé R (1; 0,997; 1,003) com 2 golpes → (0,99; 0,61; 1,67) com 13; pé L (1,00; 1,86; 0,54). No `test_contato_historia`, depois das seções A–F, o pé chegou a (0,38; 0,00003; 233.120). Instrumentando cada bloco do `aplicar` em 600 quadros: rot 0, quadril 0, IK 0, braços 0, **escrita do pé 0,087** — e o animador 0. Boneco "Parado" (animador sozinho): 0 em 16 s.
**Descartado:** escala não uniforme do modelo (a cadeia inteira tem escala 1 e só a raiz 0,759, igual nos três eixos — medido nó a nó); o animador (0 de mudança medido); uma segunda fonte no jogador parado (a deriva dele no primeiro teste era o boneco avançando 0,25 m por jab até acertá-lo, e a reação rodando o aplicador nele). Uma réplica "limpa" só da perna não derivava: faltava o giro do tronco e da outra perna que semeiam o erro — por isso a instrumentação foi feita no `aplicar` real.
**Correção:** `AplicadorDePose._girar_global(osso, q)` escreve só a rotação LOCAL (`osso.quaternion = q_pai⁻¹ · q`), e a escala do osso nunca é lida nem escrita; usada no pé, na IK da perna e no `_apontar` (`src/combat/direcional/aplicador_de_pose.gd`). Precisão da pose inalterada (`medir_pose_combate`: 116 de 119 linhas idênticas, diferenças de 1–6 mm; deslize do pé travado 0,0 cm antes e depois).
**Como detectar de novo:** `test_contato_historia.gd` seção G (13 golpes seguidos, escala local dos 14 ossos escritos < 0,002 de 1 — reprovou antes com 233.119). Regra: **em rig, nunca `global_basis = R * from_scale(global_basis.get_scale())`; escreva rotação local.** O `YoruRig` tem o mesmo padrão (item 65 da lista).

## 2026-09-21 — Janela de status mostrava a vida 1 ponto acima da real depois de qualquer dano

**Sintoma:** 3 de dano num Civil de 20 e a janela M mostrava "18 / 20".
**Causa raiz:** `JanelaDeStatus` arredondava a vida para CIMA (`ceili`) para não mostrar "0" com o corpo vivo. Mas a regeneração (0,5%/s do máximo, a 10% disso por 5 s depois de apanhar) tira a vida do inteiro logo no quadro seguinte ao dano — e aí o teto sobe 1. O arredondamento resolvia o caso raro (vida entre 0 e 1) quebrando o comum (todo dano).
**Evidência:** sonda com o jogador real: `t+0.5s vida=17.0042 ceil=18 round=17`; `t+2.0s vida=17.0242 ceil=18`.
**Correção:** `VidaEnergiaHud.vida_exibida` — arredonda para o mais perto e nunca mostra 0 com vida > 0; usada pela barra nova e pela janela M (`JanelaDeStatus.gd:217`), para as duas telas nunca discordarem.
**Como detectar de novo:** `test_vida_energia_historia.gd`, seção 2–3 (espera 0,5 s de regeneração, exige a vida fora do inteiro como pré-condição e compara barra e janela).

## 2026-09-21 — Acerto no ATIVO cancelava o golpe do JOGADOR, não o do boneco (regra §7.1 furada só de um lado)

**Sintoma:** na troca de golpes, o golpe do jogador acertado no ATIVO acabava no quadro seguinte com motivo `impedido`; o do boneco, no mesmo papel, ia até o fim. Se o golpe do adversário chegasse primeiro, o do jogador nem conectava.
**Causa raiz:** `receber_acerto` ignora o acerto no ATIVO, mas o dano chega depois pelo funil comum: `Player.take_damage` → `_feedback_de_dano` → `_fsm.transition_to("Stunned")` em TODO dano (`Player.gd:2512-2513`). `AtorJogador.impedido()` era `not corpo_livre_para_golpe()`, que inclui o Stunned, e o executor cancela qualquer fase de golpe quando o ator está impedido. O `BonecoDeDuelo.take_damage` ignora hitstun, então o boneco nunca ficava impedido — daí a assimetria. A regra estava certa no executor e furada no adaptador: "jogador e IA pelo mesmo executor" não garante a mesma regra se os corpos reagem diferente ao dano.
**Evidência:** sonda com dois corpos reais — jogador em ATIVO recebendo o acerto pelo caminho do `_contato`: `ATIVO → 2 quadros depois NEUTRO, encerrado por 'impedido'`; boneco no mesmo caso: `continua ATIVO, encerrado por 'fim'`. Troca natural (dois jabs no mesmo quadro, 1,1 m), 3 de 3 rodadas: jogador `impedido`, boneco `fim`. A seção F nova do `test_contato_historia` reprovou 2 checagens antes da correção.
**Descartado:** passar hitstun 0 ao `CombatResolver` quando o defensor está no ATIVO — o Player atordoa mesmo assim (`RecepcaoDeDano.aplicar` usa no mínimo 0,05 s e a transição para Stunned é incondicional), e o executor cancelaria do mesmo jeito. Ignorar `impedido()` inteiro no golpe que trocou — morto ou derrubado continuaria socando.
**Correção:** `Player.corpo_livre_para_golpe(contar_atordoamento := true)` (`Player.gd:2366-2371`) e `AtorDeCombate.impedido(contar_atordoamento)` separam o atordoamento das travas duras; o executor marca `_id_que_trocou` no acerto do ATIVO (`executor_corpo_a_corpo.gd:306`) e, só para aquele golpe, pergunta pelas travas duras (`:358`). A marca morre com o `id_acao`. Depois do golpe, o atordoamento que sobrar ainda impede começar outro.
**Como detectar de novo:** `test_executor_corpo_a_corpo.gd` seção 14 (com controles: atordoado no PREPARO cai; golpe seguinte não herda a marca; trava dura cancela até o golpe que trocou) e `test_contato_historia.gd` seção F (dois corpos reais: acerto nas costas durante o ATIVO do jogador e troca de frente).

## 2026-09-17 — Chave de antecipação do quadril fazia o punho parar e estalar (abordagem descartada)

**Sintoma:** ao criar uma chave 45–75 ms antes do contato para o quadril liderar a cadeia, o jab passou a medir pico de 11,7–15,4 m/s (contra 7,9) e erro de IK de 1,3–1,5 cm.
**Causa raiz:** `ChaveDePose` tem UMA fração para o corpo inteiro. Segurar a mão na chave nova concentra todo o curso do punho no trecho seguinte (0,27 m em 45 ms) e o Hermite ainda soma tangente; o perfil medido mostrava o punho PARADO (0,0–0,2 m/s) entre 0,23 e 0,27 s e um estalo depois. Em golpes com ATIVO curto (overhand, 0,12 s) a chave caía a 15 ms do contato e o quadril girava 1067°/s.
**Evidência:** perfil de velocidade do alvo da mão, quadro a quadro: `0.233:0.0 0.250:0.1 0.267:0.2 0.283:2.3 0.300:1.9 0.317:4.1 0.333:11.7`.
**Descartado:** interpolar a mão proporcionalmente (o pico foi para o PREPARO) e antecipar 35% (11,8 m/s).
**Correção:** a escada da cadeia é autorada NUMA CHAVE QUE JÁ EXISTE (o começo do ATIVO dos ganchos e do overhand cai 50–60 ms antes do contato): quadril no valor do contato, coluna a 70%, peito a 15%. Resultado: peito − quadril = +78/+43/+39 ms, picos no ATIVO. O jab ficou sem escada, por decisão medida.
**Como detectar de novo:** sonda de cadeia (amostra `PoseDeCombate` a 1 kHz e imprime o instante do pico de cada elo) + o pico de velocidade por fase em `medir_pose_combate.gd`.

## 2026-09-17 — Script de autoria não era idempotente (inseria chave e editava chave existente)

**Sintoma:** rodar o `autorar_boxe_fase6.gd` duas vezes mudava o resultado: as chaves geradas se empilhavam e a escada era aplicada de novo sobre valores já laddered.
**Causa raiz:** a função inseria uma chave nova e, quando não cabia, alterava a chave anterior — as duas operações leem o estado atual do `.tres`, que é a saída da rodada anterior. Pior: `_indice_do_contato` procurava "a primeira chave do ATIVO com fração > 0", e a própria chave gerada passava a ocupar esse lugar.
**Evidência:** 33 → 35 → 37 sub-recursos em rodadas sucessivas; o overhand voltou a peito − quadril = +2 ms porque a escada foi calculada contra a chave errada.
**Correção:** a chave gerada é removida antes de gerar (o instante é determinístico) e a chave de contato passou a ser a do ATIVO com fração mais perto de 0,5; a escada dos ganchos e do overhand virou valor explícito no script. Confirmado: duas rodadas seguidas dão 33 chaves.
**Como detectar de novo:** rodar o script duas vezes e comparar `grep -c sub_resource` do `.tres`.

## 2026-09-17 — Posturas herdavam da própria pose, não da guarda do estilo (guarda erguida sem pés)

**Sintoma:** na captura da defesa, com o RMB segurado o jogador ficava de pernas esticadas e pés juntos, trocando de pé sem parar; o boneco (que não estava em guarda erguida) mantinha a base.
**Causa raiz:** `PoseDeCombate.guarda(chave)` e `reacao(guarda, pico)` completavam o que a pose não escreve com o PRIMEIRO argumento. O executor passava `pose_guarda_erguida` como esse argumento; ela não escreve pés → pés (0,0,0) = tornozelo na origem do corpo, e o pé de apoio via o alvo longe da âncora a cada quadro. O mesmo já zerava, desde a Fase 4, qualquer rotação que a guarda erguida/tranco/aparo não escrevessem — invisível enquanto a guarda do estilo não tinha giro de quadril.
**Evidência:** traço com RMB segurado: `pe_L=(0,0,0) quadril=(0,0,0)`, extensão da perna 0,521 (= perna inteira), pés alternando "passo"; depois da correção `pe_L=(−0,13, 0,17, −0,13)`, ambos "travado", extensão 0,462.
**Correção:** `pose_de_combate.gd` — `guarda(..., heranca)` e `reacao(..., heranca)`; o executor passa `estilo.guarda` em todas as posturas montadas sobre a guarda erguida.
**Como detectar de novo:** `test_pose_de_combate.gd` seção 3b — 7 posturas conferidas contra a base e o quadril da guarda, com controle que reprova sem a herança.

## 2026-09-17 — IK da perna supunha osso apontando para −Y: tornozelo 3,9 cm fora do alvo

**Sintoma:** no pivô dos ganchos o antepé "travado" deslizava 3–11 cm no chão; o desvio antepé × âncora ficava CONSTANTE em 0,039 m desde o primeiro quadro, mesmo com a perna parada.
**Causa raiz:** `_perna_ik` montava a base da coxa e da canela com o eixo −Y ao longo do osso. No `base_v2` o filho não está em −Y puro: `Shin_L` fica em (−0,026, −0,343) na coxa e `Foot_L` em (−0,025, −0,342) na canela (~4° cada). A base "certa" em −Y põe o filho real ~1,9 cm de lado por osso → 3,9 cm no tornozelo; girar o pé transformava esse erro constante em deslize. A IK dos braços não tinha o problema porque mira pelo vetor real até o filho (`_apontar`).
**Evidência:** 3,9 cm = 2 × 1,97 cm (componente lateral do antepé com o pé a −12°) — a primeira hipótese (vetor tornozelo→antepé errado) foi DESCARTADA medindo: calculado = real, (0,02, −0,115, −0,093) nos dois. Depois da correção: pé travado desliza 0,0 cm nos ganchos e no overhand; erro antepé × âncora ≤ 8 mm.
**Descartado:** sinal invertido da rotação do pé; escala do modelo (0,7585 uniforme).
**Correção:** `aplicador_de_pose.gd` `_perna_ik` — a base é `mundo * local.transposed()`, com o eixo do osso vindo de `filho.position` (local) e da direção até o alvo (mundo), mantendo a dobradiça no X.
**Como detectar de novo:** `tools/dev_tests/medir_pose_combate.gd` → "pior erro do pé travado (antepé × âncora)". Regra: IK por base montada usa a direção REAL do filho, nunca um eixo suposto.

## 2026-09-17 — Os dois pés davam passo ao mesmo tempo (overhand parecia corrida)

**Sintoma:** na captura lateral do overhand o jogador aparecia de pernas "retas" e pés juntos no contato; o boneco empurrado parecia correr.
**Causa raiz:** cada pé decidia soltar a âncora sozinho (longe do alvo ou fora do alcance). No avanço de 0,35 m os dois cruzavam o limite quase juntos e entravam em passo ao mesmo tempo — o corpo ficava sem apoio por ~0,1 s.
**Evidência:** traço por quadro: perna L em "passo" de 0,417 a 0,550 s e perna R de 0,483 a 0,617 s. As pernas, porém, NUNCA ficaram retas (quadril–tornozelo 0,41–0,49 m de 0,52) — a foto enganou; o defeito real era o apoio duplo no ar.
**Correção:** `aplicador_de_pose.gd` `_apoio` — um pé só solta se o outro está travado; overhand ganhou passo deliberado do pé da frente na carga (`autorar_boxe_fase6.gd`). Traço depois: pé da frente no ar 0,28–0,50 s, pé de trás arrasta 0,55–0,68 s.
**Como detectar de novo:** o traço por quadro do estado dos pés (sonda de depuração do pivô) — nunca "passo"/"solto" nos dois pés no mesmo quadro.

## 2026-09-17 — Segurar a guarda encurtava a recuperação: atacar com RMB segurado era sempre melhor

**Sintoma:** achado pelo agente `critico-de-combate` no portão das Fases 4–5. Com o RMB segurado e o LMB martelando, cada golpe saía antes do fim do anterior.
**Causa raiz:** a guarda pode interromper a RECUPERAÇÃO a partir de 60% dela (para defender mais cedo), e o `pedir_ataque` em GUARDA começava golpe na hora. Ao encerrar o golpe pela guarda, o executor esquecia quanto faltava da recuperação — a saída defensiva virou atalho ofensivo. O teste da Fase 4 AFIRMAVA o atalho ("da GUARDA se ataca direto" logo após a interrupção) e o teste de spam clicava sem guarda, então nada acusava.
**Evidência:** sabotando a correção, o menor intervalo entre dois inícios com RMB segurado mede jab 0,567 s (golpe 0,680), ganchos 0,767 (0,920), overhand 1,000 (1,220) — os mesmos números da conta do crítico.
**Correção:** `executor_corpo_a_corpo.gd` — `_t_recuperacao_pendente` gravado em `_tentar_guarda` (linha ~650); em NEUTRO/GUARDA/BAIXANDO o clique segue a regra do buffer (`_guardar_no_buffer`, ~712) e sai em `_soltar_buffer_pendente`; sofrer descarta o clique guardado.
**Como detectar de novo:** `test_executor_corpo_a_corpo.gd` seção 13 — para cada golpe, 3 s de RMB segurado + LMB por quadro: menor intervalo ≥ duração − 1 quadro, com a guarda tendo interrompido ≥ 2×.

## 2026-09-17 — "Uma finta por ataque" vazava pela guarda

**Sintoma:** achado pelo `critico-de-combate`: LMB, RMB (finta para a guarda), LMB de novo — o golpe reiniciado podia fintar outra vez, até acabar a postura.
**Causa raiz:** a trava da finta (`_fintou`) pertencia à identidade da AÇÃO. A finta para a guarda encerra a ação, e o golpe seguinte nascia com `_fintou = false` — a regra falava de "ataque", o código guardava por "id de ação".
**Evidência:** sabotando a correção, a sequência LMB → RMB → LMB → RMB dá 2 fintas (esperado 1).
**Correção:** `executor_corpo_a_corpo.gd` — `_t_finta_pendente` = preparo que faltava do golpe fintado para a guarda (~702); golpe começado antes disso herda a finta (~451).
**Como detectar de novo:** seção 13 do `test_executor_corpo_a_corpo.gd` (sequência acima + controle: passado o preparo fintado, o golpe novo volta a poder fintar).

## 2026-09-17 — Invariante da quebra de guarda olhava só o preparo mais rápido

**Sintoma:** quebrar a guarda com o overhand não rendia golpe nenhum — o defensor saía da quebra antes do jab chegar. A promessa da §7.5 ("quebrar tem de render um acerto") só valia para gancho e jab.
**Causa raiz:** a invariante era `quebra > preparo mais rápido`. Ela ignorava que quem quebrou ainda está no próprio golpe: o que sobra do ativo + a recuperação (overhand 0,67 s) vem ANTES do preparo do jab. A conta certa soma o resto do golpe mais longo.
**Evidência:** quebra por overhand: 0,12 − 0,02 + 0,55 (resto) + 0,32 (jab até o contato) ≈ 0,97 s contra quebra de 0,90 s. Com a invariante nova e quebra 1,10 s, `test_defesa_historia` mede: quebra por overhand + jab martelado → ACERTO com o jogador ainda em QUEBRA.
**Descartado:** "o teste da Fase 4 já provava" — ele quebrava com GANCHO (resto 0,48 s), o caso que cabia.
**Correção:** `estilo_corpo_a_corpo.gd:177` — `quebra > max(ativo + recuperação) + preparo mais rápido + FOLGA_DA_QUEBRA (0,10)`; `boxe.tres` `duracao_da_quebra` 0,9 → 1,1.
**Como detectar de novo:** `EstiloCorpoACorpo.validar()` recusa a ficha; `test_defesa_historia.gd` seção C varre quebra por gancho e por overhand.

## 2026-09-17 — Conta de "clique de reação cabe no buffer" sem o hitstop do contato

**Sintoma:** a proposta do crítico (buffer 0,25 s) prometia que um clique de reação 0,25 s depois de quebrar a guarda com gancho entraria; medido, o clique era descartado.
**Causa raiz:** a conta usou tempo de golpe como se fosse tempo real. O contato que quebra dá hitstop em quem bateu (gancho 0,055 s): o relógio da recuperação PARA, então 0,25 s reais depois do contato ainda faltavam ~0,285 s — acima do buffer. Aceitei a conta do relatório sem somar o hitstop, e o teste denunciou.
**Evidência:** `test_defesa_historia` com buffer 0,25: "quebra por PARA_ESQUERDA, jab num clique a 0,25 s" → só `QUEBRA_DE_GUARDA`, nenhum jab. Com buffer 0,30: `QUEBRA_DE_GUARDA, ACERTO`.
**Correção:** `boxe.tres` `buffer` 0,30 (cobre a recuperação inteira do jab; a cadência continua presa pela duração). O teste do buffer passou a usar o golpe de recuperação mais longa para provar o descarte cedo.
**Como detectar de novo:** a checagem acima em `test_defesa_historia.gd`. Regra: toda janela em segundos REAIS depois de um contato soma o hitstop desse contato.

## 2026-09-17 — Teste zerava `velocity` mas o empurrão do dano mora fora dela

**Sintoma:** `test_defesa_historia` passou a reprovar a pré-condição "posicionamentos válidos (2 inválidos)": logo depois de um jab acertar o jogador, ele aparecia 6–9 cm atrás do lugar do teletransporte.
**Causa raiz:** o knockback vive em `health_controller.gd:73` (`_empurrao`), somado à velocidade antes do `move_and_slide` e decaindo sozinho — de propósito, porque a locomoção ATRIBUI `velocity`. O posicionamento do teste zerava só `velocity`. Antes não aparecia porque a espera pela quebra dava tempo de o empurrão decair; o caso novo posiciona logo após o acerto.
**Evidência:** determinístico em duas rodadas: jogador em z 0,064 e 0,087 (esperado 0).
**Correção:** `tools/dev_tests/test_defesa_historia.gd` `_posicionar` zera `jogador._vida._empurrao` junto com a `velocity`.
**Como detectar de novo:** a própria pré-condição de posicionamento dos testes de dois corpos.

## 2026-09-17 — Scratchpad em /tmp some entre sessões: gerador auxiliar perdido

**Sintoma:** ao retomar a sessão, `cat > scratchpad/fase6/…` falhou com "Arquivo ou diretório inexistente"; os scripts auxiliares das Fases 1–5 (ex.: o gerador inicial do `boxe.tres`) não existiam mais.
**Causa raiz:** o scratchpad da sessão fica em `/tmp`, que foi limpo entre o fim de 16/09 e a retomada em 17/09. Só sobreviveu o que tinha sido copiado para `~/dev/sop-snapshots/…` (patches, cópias pré-fase, logs).
**Evidência:** `ls scratchpad/` com data de criação 17/09 14:36, vazio exceto o que acabava de ser criado.
**Descartado:** perda de dado do projeto — o `.tres` é a fonte canônica e os patches por fase estavam no snapshot.
**Correção:** nenhuma no código; instrumento que precise sobreviver vai para `tools/` ou para o snapshot da frente, não para o scratchpad.
**Como detectar de novo:** ao retomar sessão longa, `ls` no scratchpad antes de contar com arquivos dele.

## 2026-09-16 — Teletransportar dois CharacterBody3D no mesmo quadro: o segundo colide com a posição ANTIGA do primeiro

**Sintoma:** no teste de contato do combate direcional o boneco, posto a 1,10 m do jogador, aparecia a 1,25 m já no primeiro quadro de física — e um gancho deixava de alcançar.
**Causa raiz:** o jogador tinha avançado 0,25 m no golpe anterior; o teste o teletransportava de volta e, NO MESMO quadro, punha o boneco à frente. No passo de física seguinte o `move_and_slide` do boneco ainda enxergava o jogador na posição antiga (caixas sobrepostas em 0,1536 m) e o despenetrou 0,1545 m.
**Evidência:** sonda quadro a quadro (`q00` já em z = −1,25453, velocidade zero); isolado, sem o golpe antes, o boneco fica parado em −1,10 por 40 quadros.
**Descartado:** NÃO era o knockback do golpe anterior — hipótese minha, afirmada antes de medir; um `parar()` que zera empurrão e velocidade deu números idênticos, o que a derrubou.
**Correção:** mover o primeiro corpo, esperar 2 quadros de física, só então o segundo (`tools/dev_tests/test_contato_historia.gd`, `_posicionar`); o teste agora EXIGE os dois corpos no chão e à distância pedida (pré-condição contada).
**Como detectar de novo:** conferir a distância entre os corpos alguns quadros depois de posicioná-los; qualquer deslocamento com velocidade zero é despenetração.

---

## 2026-09-16 — Corpo criado sobreposto a outro vira plataforma e carrega o de cima

**Sintoma:** na captura de fotos do combate o boneco "sumia" da câmera lateral; o jogador estava a y = 2,40 (em cima da caixa de 1,6 m do boneco) e acompanhava cada teletransporte dele.
**Causa raiz:** o `BonecoDeDuelo` era adicionado à cena na ORIGEM, sobreposto ao jogador; a física despenetrou o jogador para CIMA. Parado em cima de outro corpo, o `CharacterBody3D` herda o deslocamento da "plataforma", então mover o boneco levava o jogador junto.
**Evidência:** rastreio quadro a quadro: `q00` jogador em (0; 2,40; −3,0) logo depois de o boneco ir para z = −3,0.
**Correção:** o boneco nasce longe antes do `add_child` (`position = (0; 0,8; −4)`) no teste de contato e no roteiro de captura.
**Como detectar de novo:** checar a altura dos corpos depois de montar a cena de teste (y do centro ≈ 0,8 na baseplate).

---

## 2026-09-16 — Golpe "perigoso" antes da hora: pico de velocidade do punho no PREPARO

**Sintoma:** medido no rig real (`medir_pose_combate.gd`), os quatro golpes do boxe tinham o pico de velocidade do punho no PREPARO (12–15 m/s), antes da janela em que podem acertar.
**Causa raiz:** duas. (1) A camada de pose entrava em 0,08 s: as mãos saíam dos braços caídos (y 0,82) para a guarda (y 1,24) em ~60 ms — um estalo. (2) Nos ganchos e no overhand a chave de entrada do ATIVO ficava longe da carga, e o grosso do arco acontecia no fim do preparo.
**Evidência:** tabela da sonda por quadro; depois da correção o pico caiu no ATIVO nos quatro (jab 8,5; ganchos 5,8; overhand 7,4 m/s).
**Correção:** postura de combate após cada ação (`EstiloCorpoACorpo.guarda_apos_acao`, 2,5 s), entrada de 0,18 s, chave de entrada perto da carga e chave de ápice no meio do ATIVO (`estilos/boxe.tres`).
**Como detectar de novo:** `godot --headless --path . --script tools/dev_tests/medir_pose_combate.gd` — a linha "pico de velocidade … na fase" tem de dizer ATIVO.

---

## 2026-09-16 — O `.tres` não grava campo igual ao padrão do script (o número fica no código)

**Sintoma:** o `boxe.tres` gerado não tinha `preparo`, fatores de movimento nem giro do jab.
**Causa raiz:** o `ResourceSaver` do Godot omite propriedades com o valor padrão da declaração. Com padrões "bons" no script (`preparo := 0.30`) o valor real morava no código, e mudar o padrão mudaria o golpe em silêncio — o oposto de dado versionado.
**Evidência:** a primeira versão do arquivo (só `dano` no jab); depois de padrões neutros, 20 campos explícitos.
**Correção:** padrões NEUTROS nos `Resource` do combate (tempo 0, movimento 1,0, giro livre, buffer 0), com `validar()` recusando tempo zero (`golpe_direcional.gd`, `estilo_corpo_a_corpo.gd`, `chave_de_pose.gd`).
**Como detectar de novo:** abrir o `.tres` e procurar os campos que o jogo usa; ausência = valor vindo do script.

---

## 2026-09-16 — Headless não captura o mouse: teste de clique "passa" sem chegar ao ataque

**Sintoma:** nenhum visível; um teste do Modo História afirmava "clique esquerdo não ataca" e passava.
**Causa raiz:** em `--headless`, `Input.mouse_mode = CAPTURED` não pega (continua VISIBLE). O clique entregue ao `Player._unhandled_input` cai no ramo que recaptura o mouse e sai antes do corpo a corpo — o "não atacou" é verdade por outro motivo.
**Evidência:** sonda de 3 linhas: antes 0, depois de atribuir 0, no quadro seguinte 0 (CAPTURED = 2).
**Correção:** o `test_combate_historia` só julga o clique com captura real e o `test_combate_historia_tela` roda no bloco com tela do `validar.sh`; o teste antigo ficou como item 64 da `LISTA_DE_CORRECOES.md`.
**Como detectar de novo:** em teste de input, afirmar `Input.mouse_mode == MOUSE_MODE_CAPTURED` antes de julgar o clique.

---

## 2026-09-16 — Citar uma classe que DEPENDE do Player num script `-s` envenena o Player

**Sintoma:** `test_combate_historia` não montava o jogador: "Nonexistent function 'new' in base 'GDScript'" em `colocar_civil`, depois de "Identifier not found: FruitNet" no Player.
**Causa raiz:** o teste citava `AtorJogador` pelo nome (`e.ator is AtorJogador`). Essa classe declara `var _jogador: Player`, então compilar o teste compila o Player — antes de os autoloads existirem num `godot -s` — e o Player fica marcado como falho no cache. A armadilha já documentada falava de `preload`; ela vale para qualquer classe citada que arraste o Player.
**Correção:** o teste compara `get_script().get_global_name()` em vez de citar a classe; `BonecoDeDuelo` é carregado por `load` e não cita `Player`.
**Como detectar de novo:** num teste `-s` que sobe o jogo, procurar referência por nome a classes de `src/combat/direcional/ator_jogador.gd` ou a qualquer script que tipa `Player`.

---

## 2026-09-16 — Hitbox do M1 agendada por timer sem identidade de ação (não cancelável)

**Sintoma:** não observado em jogo; achado na auditoria do combate do Modo História. Consequência esperada: golpe de punho interrompido no startup (hitstun, morte, troca de modo) ainda cria a `DamageZone` e pode acertar.
**Causa raiz:** `Melee.golpear` agenda a hitbox com `get_tree().create_timer(startup * s)` e o callback só confere `is_instance_valid(caster)`/`is_instance_valid(world)` (`src/combat/Melee.gd:660-663`). O golpe não tem id que o timer compare, e `MeleeController.cancelar_golpe` / `CombatStateStunned.enter` zeram só o estado do controlador — o timer já agendado não é alcançável.
**Evidência:** leitura do código nas linhas acima; contraste com `ContextualMelee`, que resolve o mesmo problema comparando `sequencia` e `token` antes de criar a zona (`src/combat/contextual_melee.gd:351-356`). O próprio `melee_controller.gd` já registra o mesmo antipadrão para a punição de whiff ("timer solto foi como a morte deixava `is_casting` pendurado").
**Descartado:** não é o `CombatStateStunned` deixando de cancelar — ele chama `cancelar_golpe()` (`CombatStateStunned.gd:39-43`); o problema é que cancelar não chega ao timer.
**Correção:** não aplicada (arena, fora do escopo da tarefa). Item 59 de `LISTA_DE_CORRECOES.md`. O combate novo do Modo História evita o padrão por projeto: relógio único por executor, cancelamento por id de ação, hitbox amostrada da pose (ver `PLANO_COMBATE_HISTORIA.md`, D4/D5).
**Como detectar de novo:** atacar com o punho, aplicar hitstun no atacante antes de 0,20 s e contar `DamageZone` nascidas no grupo `hitbox`; deve ser 0. Em revisão: `grep -n "create_timer" src/combat` e conferir se o callback compara uma identidade de ação.

---

## 2026-09-16 — Hit stop por `Engine.time_scale` global a cada acerto no servidor

**Sintoma:** não medido em partida; achado na auditoria do combate do Modo História. Consequência esperada: num host, cada acerto de qualquer `DamageZone` desacelera a simulação inteira (todos os corpos, todas as frutas) por 50 ms reais; os clientes não veem o efeito.
**Causa raiz:** `DamageZone._on_body` chama `GameFlow.hit_stop()` por corpo atingido (`src/effects/DamageZone.gd:331-333`), e `hit_stop` implementa a micro-pausa trocando `Engine.time_scale` para 0,06 (`autoload/GameFlow.gd:270-275`) — um recurso global usado para um feedback que é local ao impacto.
**Evidência:** leitura das linhas acima; `hit_stop` só é pulado em servidor dedicado ou se `time_scale < 1`.
**Descartado:** não empilha nem trava — o `await` usa timer que ignora `time_scale` e restaura 1,0.
**Correção:** não aplicada (arena). Item 60 de `LISTA_DE_CORRECOES.md`. O combate novo da história usa hitstop por ator (pausa do relógio do executor e do animador dos dois envolvidos), sem tocar `Engine.time_scale`.
**Como detectar de novo:** numa sonda de dois processos, registrar `Engine.time_scale` no host a cada quadro durante uma troca de golpes; qualquer valor < 1 fora de ultimate denuncia.

---

## 2026-09-16 — `test_px_tri_beam` reprovou depois de a câmera descer (defeito do TESTE)

**Sintoma.** Com a câmera na altura da cabeça, "o raio da câmera encontra o alvo preparado" passou a falhar sempre.
**Causa.** O teste põe o alvo 8 m à frente SEGUINDO a linha da câmera, com a mira no pitch de nascer (−0,25). Câmera a 4 m do chão deixava o alvo a 1,1 m; a 2,79 m, o alvo foi para y −0,24 — dentro do chão — e o raio batia na Plataforma. Sonda: `hit=Plataforma em (1.1, 0.0, -7.05)`.
**Correção.** O teste nivela a mira (`_pitch = 0`) antes de posicionar o alvo. O jogo não mudou.

## 2026-09-16 — `cp` com curinga escreveu num projeto que não era este

**Sintoma.** Ao preparar uma sonda, `cp arquivo ~/.local/share/godot/app_userdata/*/` copiou o JSON temporário para `[unnamed project]`.
**Causa.** Com vários diretórios no curinga, o `cp` trata só o ÚLTIMO como destino (os outros viram "origem", ignorados por serem pastas, erro escondido pelo `2>/dev/null`). Nem era preciso: o Godot abre caminho absoluto.
**Correção.** Cópia localizada com `find`, conferida idêntica com `cmp` e removida; nenhuma outra existia. Regra: nunca curinga como destino de `cp`; passar o caminho absoluto ao jogo.

---

## 2026-09-16 — `test_camera` travou mudo depois de citar `CameraRig` no script

**Sintoma.** Ao baixar a câmera (pivô 2,2 → 1,0), a checagem "a altura mudou mais de 1 m" do `test_camera` deixou de valer (a troca de 3ª para 1ª pessoa passou a ser 0,4 m). Ao reescrevê-la com `CameraRig.CAM_HEIGHT_TPS`, o teste parou de imprimir QUALQUER linha e morreu no `timeout`.
**Causa.** Script rodado com `-s` não enxerga autoloads na compilação; `CameraRig` depende deles, então citar a classe direto derruba a compilação do teste, que fica parado sem reportar. O `test_boss_buggy_visual` já avisava isso num comentário.
**Correção.** Ler as constantes do script do nó vivo: `rig.get_script().get_script_constant_map()`. A checagem nova confere as DUAS alturas exatas (mais forte que o "mudou > 1 m", que estava preso ao número antigo).
**Regra.** Teste com `-s` que fica sem saída nenhuma: suspeitar primeiro de referência estática a classe que usa autoload.

---

## 2026-09-16 — Jogador aparecia como o boss Buggy (e um erro ao ir da arena para o Modo História)

**Sintoma.** O dono abriu o jogo pelo atalho da área de trabalho e o jogador estava com o visual do boss Buggy, em qualquer modo.
**Causa raiz.** Não era código de jogo: em 12/09, no trabalho do boss, o atalho `~/Área de trabalho/SKILLS ONE PIECE.desktop` foi trocado de `jogar.sh` para `env SOP_TEST_CHARACTER_TARGET=player jogar_buggy.sh`. O `jogar_buggy.sh` exporta `SOP_TEST_CHARACTER_VISUAL=…buggy_boss_visual.tres`, e `CharacterVisualDefinition.test_option()` veste o grupo "player" com esse visual. O atalho do dia a dia virou um lançador de teste.
**Evidência.** Mesma sonda, arena → Modo História: sem a variável, `visual_teste=false` e personagem base; com a variável, `visual_teste=true`. O `desktop_before.desktop` guardado em `art_src/validation/buggy_boss/` mostra o `Exec` original.
**Correção.** Atalho restaurado byte a byte igual ao original (`Exec=…/jogar.sh`). O visual do Buggy continua disponível por `./jogar_buggy.sh`. Regra: atalho principal do dono não vira lançador de teste; teste ganha atalho ou script próprio.

**Erro junto, no log da mesma manhã:** `Trying to assign invalid previously freed instance` em `TreeAndFruitGenerator.respawn_fruit`. O `active_fruits_map` é ESTÁTICO e sobrevive à troca de cena; indo da arena para o Modo História, o `equip_fruit("")` do Civil devolve a fruta antiga a uma árvore já liberada, e `var node: Node3D = <instância morta>` quebra ANTES do `is_instance_valid`. *Correção:* ler como `Variant`, conferir validade, limpar a entrada (em `respawn_fruit` e `hide_fruit`). *Controle positivo:* com o código antigo a sonda arena → história dá 1 erro; com o novo, 0.

---

## 2026-09-16 — Janela de status: dois defeitos de layout vistos na captura

**1. Aviso de "Level Up" começava no meio da tela.** `set_anchors_and_offsets_preset(PRESET_CENTER_TOP, PRESET_MODE_MINSIZE)` foi chamado com o `Label` ainda VAZIO: o tamanho mínimo era 0, a caixa ficou com largura 0 no centro, e o texto escrito depois cresceu para a direita. *Correção:* faixa `PRESET_TOP_WIDE` com alinhamento central. *Regra:* âncora com `MINSIZE` só depois de o conteúdo existir — ou use faixa larga.

**2. A mira "+" do Player aparecia por cima da janela.** A mira é um `CanvasLayer` (camada 1) criado pelo Player, que entra na árvore DEPOIS da HUD, também na camada 1 — mesma camada, desenha por último. *Correção:* `HistoriaHud.layer = 5`.

*Evidência:* capturas `v3_status.png` / `v3_levelup.png` (weston GL + Vulkan); refeitas depois da correção.

---

## 2026-09-14 — Testes do Modo História quebraram porque o dono começou a usar o editor

**Sintoma.** Na bateria, `test_modo_historia` ("tem exatamente 1 peça") e `test_loja_modelos` (5 falhas) reprovaram; rodados sozinhos minutos antes, passavam.
**Causa raiz.** Os testes mediam o **mapa vivo** do projeto (`mapas/historia/baseplate.json`). Enquanto a bateria rodava, o dono importou 3 modelos na loja e salvou o mapa com 23 peças. Teste que afirma conteúdo de arquivo que o usuário edita é teste de foto, não de comportamento.
**Evidência.** O log listava peças `low_poly_pine_tree_3d_1`, `dirt_road_3d_model_1`; o arquivo tinha mtime 18:07, dentro da janela da bateria. A segunda falha da loja era a mesma classe: a miniatura da árvore já existia no cache de uma captura anterior.
**Correção.** Mapa fixo em `tools/dev_tests/fixtures/mapa_baseplate.json` para os três testes; `ModoHistoria.mapa_forcado` para o teste abrir o fixo; do mapa real só se exige que continue **válido**. O teste de miniatura prova "sem tela nenhuma foto NOVA é gerada", apagando a foto antes.

**Tropeço no conserto — `preload` em script de teste envenena o cache.** Pôr `preload("res://src/historia/ModoHistoria.gd")` no topo do teste compilou ModoHistoria → Player ANTES de os autoloads existirem no `godot -s`; o Player ficou no cache como "falhou" e o `load("res://Player.gd").new()` seguinte deu `Nonexistent function 'new'`. Carregar com `load()` depois do primeiro quadro resolve.
**Como detectar de novo.** Teste que usa arquivo de `mapas/` → usar fixture. Script de teste que precisa de cena do jogo → `load()` em tempo de execução, nunca `preload` no topo.

---

## 2026-09-14 — Loja de modelos: `ItemList` mede item velho logo depois de reconstruir

**Sintoma.** No `test_loja_modelos`, o clique num modelo da loja não inseria nada, embora o arraste do mesmo item funcionasse.
**Causa raiz.** O teste reconstruía a lista (limpar a busca) e, no MESMO quadro, pedia `ItemList.get_item_rect(0)` para saber onde clicar. O `ItemList` só recalcula a posição dos itens no quadro seguinte: o retângulo ainda era o da lista filtrada, e o clique caía fora do item.
**Evidência.** Sonda isolada, esperando 8 quadros antes de medir: o mesmo clique emite `inserir_pedido` e o mapa vai de 1 para 2 peças.
**Descartado.** Ordem de sinais (`gui_input` vem antes do `_gui_input`), `accept_event` do ItemList, conexão do sinal no editor — a sonda mostrou os três funcionando.
**Correção.** O teste espera 2 quadros depois de reconstruir a lista. A loja em si não mudou.
**Como detectar de novo.** Teste que clica em item de `ItemList`/`Tree` logo após `clear()`+`add_item` → esperar um quadro antes de medir o retângulo.

---

## 2026-09-14 — Editor de mapa: três defeitos achados pelo próprio teste e pela captura

**1. Renomear uma peça tirava a peça da seleção.**
*Causa raiz.* Renomear = remover o id antigo + incluir o novo. O editor poda a seleção no sinal `peca_removida`, e `OperacoesDoEditor.renomear` lia a seleção DEPOIS da transação: o id antigo já tinha saído, então a troca pelo novo nunca acontecia.
*Evidência.* `test_editor_mapa` D5: seleção vazia depois de renomear `caixa_1` → `torre`.
*Correção.* A seleção é lida antes de `hist.iniciar("Renomear")` (`src/editor_mapa/operacoes.gd`).

**2. O painel lateral crescia para fora da tela com várias peças selecionadas.**
*Causa raiz.* Um `Label` sem quebra de linha pede a largura do texto inteiro; o `VBoxContainer` lateral acompanha o filho mais largo e ignora o `offset_right`.
*Evidência.* Captura `editor_girar.png`: Explorer e Propriedades cortados na borda direita com "Cor, material e colisão valem para todas as peças."
*Correção.* `EstiloDoEditor.explicacao()` (autowrap + largura mínima 1) nos textos de explicação, e `clip_contents` no painel lateral.

**3. (Ferramenta de teste) `Viewport.push_input(evento)` errava o alvo do clique.**
*Causa raiz.* Sem o segundo argumento, `push_input` trata a posição como coordenada da JANELA e aplica o esticamento `canvas_items`. O teste gerava a posição com `Camera3D.unproject_position`, que já é coordenada do viewport.
*Evidência.* O clique sobre a caixa selecionava a `baseplate`, e o arraste do gizmo não movia nada. Com `push_input(evento, true)` o teste inteiro passa.
*Como detectar de novo.* Teste de interface que injeta mouse com posição vinda de `unproject_position` → sempre `push_input(evento, true)`.

---

## 2026-09-14 — Captura do jogo em `weston` com OpenGL sai só com céu (ou corrompida)

**Sintoma.** Ao conferir o Modo História num `weston --backend=headless` com `--rendering-driver opengl3`, o quadro mostrava só o céu e um fundo liso abaixo do horizonte: nem a baseplate nem o personagem. Parecia bug da cena nova.

**Causa raiz.** Ambiente, não jogo. Com o renderizador padrão do weston headless (pixman), o Godot cai no OpenGL por software (`llvmpipe`, perfil de compatibilidade), que não desenha direito o cel shader do projeto. Com Vulkan no mesmo weston a swapchain nem cria (`Unable to create swap chain`).

**Evidência.** A sonda no mesmo quadro dizia câmera em `(1.1, 4.49, 5.81)` atrás do jogador, malha da baseplate visível e modelo visível, ou seja, estado lógico correto. A **arena**, capturada do mesmo jeito, também saiu corrompida. Com `weston --renderer=gl` + `--rendering-driver vulkan`, o Godot pega a RTX 3050 e o quadro sai certo: baseplate com grade, personagem e sombra.

**Descartado.** Câmera enterrada, malha invisível, primeira pessoa, material faltando: todos conferidos na sonda.

**Correção.** Método de captura documentado em `docs/MODO_HISTORIA.md` §6: `weston --backend=headless --renderer=gl` + `--rendering-driver vulkan`. O caminho `opengl3` + pixman continua servindo para o estúdio de animação (cena simples), não para o jogo.

**Como detectar de novo.** Se a captura mostrar só céu, rode a mesma captura na arena. Se a arena também quebrar, o problema é o renderizador, não a cena.

---

## 2026-09-14 — Botão MODO HISTÓRIA empurrou CONFIGURAÇÕES para fora do menu

**Sintoma.** Com o card novo, o menu principal passou a somar 825 px numa tela de 720. CONFIGURAÇÕES ficou fora e CUSTOMIZAÇÃO cortada. Nenhum erro, nenhum teste vermelho.

**Causa raiz.** Acrescentei um card de 99 px (+10 de espaço) sem rodar `tools/dev_tests/medir_menu_principal.gd`. O menu **já estava a 4 px do limite** (716 de 720), e o aviso existia em comentário no `_create_main_button`, que eu não li antes de acrescentar. É a mesma classe de erro que criou a sonda (o botão de CUSTOMIZAÇÃO, em agosto).

**Evidência.** A sonda listou 14 controles fora da tela, com o último em `fim(718,807)`. Depois da correção: `✓ nenhum controle passa da tela`.

**Descartado.** Empilhar os dois botões dentro de um card JOGAR (~185 px): também não cabia, medido antes de codificar.

**Correção.** `MainMenu._create_play_card()`: SINGLEPLAYER e MODO HISTÓRIA lado a lado num card da altura do antigo (escolha do dono).

**Como detectar de novo.** Botão novo no menu → rodar a sonda com tela real (`--display-driver wayland` num weston headless ou `DISPLAY=:1`). Em `--headless` puro a tela vira 1280×1280 e a sonda não mede nada.

---

## 2026-09-14 — BaraPoses.gd deixado sem compilar pelo Codex derrubava o Player inteiro

**Sintoma.** `Parse Error: There is already a variable named "segment" declared in this scope` em `src/anim/BaraPoses.gd`. O `ProceduralAnimator` carrega o arquivo, então o Player não compilava e qualquer teste que sobe o jogo falhava.

**Causa raiz.** Dois restos de patch aplicados por substituição de texto, no fim da sessão do Codex (10:47, pouco antes de ele cair por limite de uso):
1. O laço das falanges usava `for segment in 3`, com o mesmo nome do `var segment` declarado antes na função.
2. `var side := ...` ficou recuado dentro do bloco depois do `continue`, e o `side` deixava de existir na linha seguinte.

O próprio Codex viu o erro às 10:50:24 e não chegou a corrigir.

**Evidência.** `--check-only` do arquivo reproduzia o erro; depois da correção, os 5 scripts da Bara passam.

**Correção.** Laço renomeado para `phalanx`; `side` voltou ao nível do `sign_side`.

**Como detectar de novo.** `"$GODOT" --headless --path . --script tools/dev_tests/test_compila.gd` depois de qualquer patch por script. `--check-only` sozinho não substitui (armadilha já registrada).

---

## 2026-09-13 — `test_move` com a cápsula apoiada no chão acusa o próprio piso

**Sintoma.** O dash de esquiva do Boss nunca saía: todo lado era julgado bloqueado e ele caía no pulo de reserva.

**Causa raiz.** `CharacterBody3D.test_move(global_transform, deslocamento_horizontal)` com o corpo encostado no chão reporta colisão com o piso (contato/margem), mesmo sem parede nenhuma no caminho.

**Evidência.** Sonda no mesmo ponto: com o transform levantado 8 cm, `test_move` devolveu `false` para os dois lados e a esquiva escolheu −Z. Depois da correção, o dash percorre 3,94 m e desvia da flecha de gelo real.

**Correção.** `BossMobility.dash_is_safe` testa a partir de `global_transform.translated(Vector3.UP * 0.08)`.

**Tropeços de medição no mesmo trabalho** (defeitos do teste, não do jogo):
- Um projétil de uma etapa anterior, já com `queue_free`, ainda existe por um quadro e gasta o dash da etapa seguinte. A fixture espera o Boss parado no chão e só então zera a recarga.
- Congelar a física SÓ do Boss para fotografar deixa o projétil voando e acertando o corpo parado.

**Como detectar de novo.** `test_boss_mobilidade.gd` ("parede de um lado", "Boss usa o dash").

---

## 2026-09-13 — Boss não atacava com o jogador de frente, e depois os socos erravam

**Sintoma (relatado pelo dono).** De frente para o Boss, ele não iniciava ataques. Quando iniciava, o knockback afastava o jogador e os golpes seguintes não acertavam.

**Causa raiz — três problemas encadeados.**
1. *Impasse de alcance.* `_decide` só atacava com `distance <= attack_distance` (1,25 m entre centros). Colado no jogador, o `safe_direction` via o próprio alvo como obstáculo e bloqueava todas as direções. Medido: o Boss parava em "chase" com velocidade zero a **1,29 m** e nunca atacava.
2. *Knockback 1,2–5 nos jabs.* Cada acerto afastava o alvo para ~1,5 m.
3. *Margem de alcance fina demais.* O punho estendido chega a ~0,97 m do centro do Boss (IK limitado pelo braço + raio 0,22). O combo emenda com o alvo a até 2,0 m (`combo_break_distance`), e "encostado na diagonal" dá ~1,58 m. Medido com sonda: a 1,55 m **todos** os socos passavam ao lado da caixa do jogador, mesmo sem knockback.

**Descartado (diagnóstico meu que se provou errado).** Primeiro culpei a caixa de colisão do Boss, que gira: a diagonal encosta mais longe. Troquei por cápsula e remedi: os socos continuaram errando a 1,54 m. A cápsula ficou (contato igual em qualquer rotação), mas **não** era a causa. O deslocamento lateral de 1 m na sonda também não era do jogo: o Boss tinha sido posto sobre algo no centro da arena.

**Correção.**
- `BossController.touching()`: encostado no alvo conta como alcance.
- Jabs 1–4 com knockback 0. Só o último golpe que sai no combo arremessa, com derrubada (punho destacado quando disponível; senão o 4º soco).
- `BossCombat.step_velocity()`: passo de boxeador. Na preparação e no contato, o corpo avança até `attack_distance`; a direção do soco segue travada.

**Evidência.** `test_boss_arremesso_jogador.gd` 34/0: a 1,4 m de frente o Boss ataca; na diagonal a ~1,58 m os quatro socos acertam (288) e o 4º arremessa; em combo real não há deslocamento do jogador antes do arremesso.

**Como detectar de novo.** O mesmo teste, blocos "encostado de frente" e "na diagonal". Qualquer mudança em alcance, IK ou colisão precisa manter o punho (~0,97 m) acima da face do alvo na distância em que o combo começa.

---

## 2026-09-13 — `get_meta(nome, null)` acusa erro quando a meta não existe

**Sintoma.** `ERROR: The object does not have any 'meta' values with the key '_flash_dano_mat'` no log, no primeiro flash de cada corpo.

**Causa raiz.** Em `Object.get_meta(name, default = null)`, passar `null` equivale a não passar padrão, e a Godot 4.6 registra erro para chave ausente.

**Correção.** `FxUtil.flash_dano` usa `has_meta` antes de `get_meta`.

**Como detectar de novo.** `grep -rn 'get_meta("[^"]*", null)'` e os logs de rede do Boss (`art_src/validation/buggy_boss/network/*.log`) sem `ERROR`.

---

## 2026-09-13 — andar + clique trocava o golpe e o novo golpe empurrava o Boss

**Sintoma (relatado pelo dono).** Com o jogador em movimento, o clique "ficava diferente" e o Boss era empurrado para trás, mesmo depois da recepção de M1 (paralisa/arremessa) já estar pronta.

**Causa raiz.** Dois fatores somados:
1. `ContextualMelee.resolver` escolhia cotovelada (W), chute recuando (S) ou esquiva com gancho (A/D) sempre que havia tecla de movimento no primeiro golpe do combo. Andar e clicar não produzia um M1.
2. A marca `corpo_a_corpo` só tinha sido posta nos caminhos do combo M1 (`Melee.golpear`, `SwordBlade`). A `DamageZone` criada por `ContextualMelee.golpear` não tinha a marca, e o Boss tratava o golpe como skill: `velocity += impulse` (knockback 15–17). O mesmo valia para a Aú e para a mordida e o chute Mink, que chamavam `take_damage` direto.

**Descartado.** Não era a `BossHitReaction`: acertos marcados continuavam paralisando nos testes. O que escapava era qualquer golpe de clique que não passasse pelo combo M1.

**Correção.**
- Variações de movimento simples apagadas por decisão do dono (fichas, poses, recuo, testes).
- `zona.corpo_a_corpo = true` no contextual e na Aú. Mordida e chute Mink passam pelo `CombatResolver` com `corpo_a_corpo_de = self`.
- `BossActor.reage_ao_corpo_a_corpo()` faz o contextual dispensar counter, lançamento e sustento, que chegariam como um segundo `take_damage` sem marca.

**Como detectar de novo.** `test_boss_recepcao.gd`, blocos "andar + clique" e "outras variações". Todo golpe de clique novo precisa marcar `corpo_a_corpo` (ou passar `corpo_a_corpo_de` ao `CombatResolver`); se não marcar, empurra o Boss.

---

## 2026-09-13 — o Boss recuava a cada soco porque não sabia distinguir um M1 de uma skill

**Sintoma (relatado pelo dono).** Nos golpes corpo a corpo do jogador (clique do mouse), o Buggy era empurrado para trás a cada acerto. O combo M1 não segurava o alvo no lugar.

**Causa raiz.** `BossActor.take_damage` soma `impulse` à velocidade para qualquer golpe, e o golpe chegava sem nenhuma informação de origem. `DamageZone` → `CombatResolver.aplicar` → `take_damage(amount, origin, impulse, hitstun)` não diz se o golpe é um M1 ou uma skill. Os quatro passos do punho têm `kb` 11/13/15/26 (`Melee.COMBO`), valores feitos para jogar jogadores no buraco. No Boss, esse empurrão virava recuo constante.

**Correção.** `CombatResolver.aplicar(..., corpo_a_corpo_de)` coloca a meta `golpe_corpo_a_corpo` (instance_id do atacante) só durante o `take_damage`. Quem marca: `DamageZone.corpo_a_corpo` (punho, em `Melee.golpear`), `SwordBlade.armar(..., corpo_a_corpo)` (espada do `Melee` e `M1_*` da `YoruController`). O Boss lê a meta em `BossHitReaction.receive`: o 1º e o 2º acerto seguido paralisam sem impulso, o 3º arremessa. Skills seguem o caminho antigo.

**Dois tropeços meus no caminho.**
1. *IK no quadro errado.* A pose de reação gira o `model` inteiro, mas a IK dos braços (`BoxingPose.arm`) mira pontos em espaço do ATOR e lê os ossos pelo `skeleton.global_transform`, que já traz o giro do quadro anterior. Com o corpo inclinado 1 rad no voo, as mãos iriam para lugares errados. Pego na revisão, antes de rodar: `BossVisual.pose_at` volta o `model` para `model_base` antes de qualquer IK, e o giro do corpo é aplicado por último.
2. *Medi o empurrão errado.* O teste acusou 0,47 m de recuo depois do 1º soco. A posição inicial tinha sido gravada ANTES do `Melee.golpear`, e nos 0,25 s de startup a IA do Boss andava (e desviava de lado) até o jogador. Medido a partir do instante do acerto: < 0,05 m.

**Evidência.** `tools/dev_tests/test_boss_recepcao.gd`: 23/23 (sem empurrão no 1º e 2º, arremesso de 7,3 m para longe do atacante, fases voo → chão → levantar, skill ainda empurra, M1 de espada conta, buraco mata). Rede: 19/19.

**Como detectar de novo.** `test_boss_recepcao.gd`. Qualquer golpe corpo a corpo novo que não passe a marca `corpo_a_corpo` volta a empurrar o Boss.

---

## 2026-09-12 — a pose congelou no primeiro quadro por causa de uma meta zerada

**Sintoma.** A coreografia nova do El Thor não acontecia: o `custom_pose` estava
certo, o peso da pose chegava a 1,00, e mesmo assim o braço do jogador **não
subia**. Nada no log. O teste de poses passava — porque ele amostra
`GoroPoses.sample()` direto e nunca passa pelo animador.

**Causa raiz.** O `ProceduralAnimator` lê o relógio do gesto assim:

```gdscript
_goro_golpe_t = float(get_parent().get_meta("goro_pose_t", _goro_golpe_t + delta))
```

O segundo argumento é o *default de quando a meta NÃO EXISTE*. Eu escrevi
`caster.set_meta("goro_pose_t", 0.0)` ao disparar o golpe achando que estava
"zerando o relógio" — mas a meta passou a existir, parada em 0,0, e o animador
passou a preferi-la ao próprio acumulador. A pose ficou eternamente no quadro
zero.

**O certo é `remove_meta`**, não `set_meta(…, 0.0)`: sem a meta, o default vale e
o relógio corre sozinho. Só o V publica esse valor, porque a carga dele não tem
duração prevista — e ele **remove a meta ao morrer**, senão o próximo golpe da
fruta nasceria lendo um relógio velho e parado.

**Por que demorou a aparecer.** Três camadas de verificação diziam "está certo":
o teste de poses (que não passa pelo animador), o peso da pose (que subia a
1,00) e a compilação. **Só a CAPTURA NO JOGO mostrou** — e ela existe por causa
do critério de prova visual da régua. Sem capturar, isso ia para o jogo como
"a pose que não pega".

**A lição:** `get_meta(nome, default)` só usa o default quando a chave **não
existe**. Escrever a chave com o valor do default não é neutro — é assumir o
controle daquele valor para sempre. Vale para todo `get_meta`/`get()` com
fallback: se o dono do valor não vai atualizá-lo todo quadro, ele não deve
escrevê-lo.

---

## 2026-09-12 — trocar o TIPO do material teria apagado a dissipação em silêncio

**Quase-erro, pego antes de entrar.** Ao dar um shader dedicado às nuvens da
Goro, `GoroFX.storm_cloud` passou a devolver `ShaderMaterial` no lugar de
`StandardMaterial3D`. Os dois pontos que dissipam nuvem — `ElThorController._dissipar`
e `MamaraganController._fechar_ceu` — faziam:

```gdscript
for m in _mats:
    if m is StandardMaterial3D:
        tw.tween_property(m, "albedo_color:a", 0.0, 0.85)
```

Com o tipo novo a condição **simplesmente não casa**. Não há erro, não há aviso,
o laço roda e não faz nada: as nuvens do El Thor e do Mamaragan ficariam
penduradas no céu para sempre, e o sintoma só apareceria jogando, minutos
depois, como "o mapa está enchendo de nuvem".

**Por que é fácil cair nessa.** `ShaderMaterial` não tem `albedo_color`; se o
`if` não existisse, o tween falharia alto e o problema apareceria no ato. Foi o
*type check* defensivo — escrito para proteger — que transformou uma falha
barulhenta em silêncio.

**Conserto:** `GoroFX.dissipar_material(tw, m, dur)`, um único lugar que anima
`shader_parameter/presence` em `ShaderMaterial` e `albedo_color:a` em
`StandardMaterial3D`.

**A lição:** ao trocar o TIPO de um objeto devolvido por uma fábrica, procure
todo `is <TipoAntigo>` no projeto antes de rodar qualquer teste — teste verde
não prova que o ramo ainda é alcançado. `grep -rn "is StandardMaterial3D"` custa
segundos.

---

## 2026-09-12 — o raycast de mira caía no fallback no primeiro golpe de cada vida

**Sintoma.** Ao remodelar o V da Goro para cair sobre o ponto de mira, o log
passou a acusar `Parameter "data.tree" is null` vindo de `FxUtil.autofree`. O
teste passava mesmo assim — e log sujo com teste verde é exatamente o caso que
a régua manda tratar como FAIL.

**Causa raiz — uma armadilha que o projeto JÁ CONHECIA em outros dois lugares.**
O `world` que chega aos efeitos é o `Skills_<jogador>` de
`Player._get_skills_container()`, e ele entra na cena por
`add_child.call_deferred(...)`. No **primeiro cast de cada vida** ele ainda não
está na árvore: `get_world_3d()` devolve null, `get_tree()` devolve null.

`FxUtil.autofree` e `YamiFX._find_closest_entity` já documentam isso. O que
ninguém tinha notado é que **`GoroFXGrande._ponto_de_mira` sofria do mesmo mal**:
sem espaço físico ele caía no fallback e devolvia um alvo a `alcance` metros à
frente com `y = 0`, ignorando a mira por completo.

**E isso valia para o El Thor desde sempre**, não só para o V novo. O X nunca
denunciou porque um alvo "à frente do jogador" é plausível demais: ninguém olha
uma coluna de raio caindo à frente e pensa "essa deveria estar 20 m adiante, na
parede que eu mirei".

**Conserto.** `_ponto_de_mira` agora procura o espaço físico no **`caster`**
primeiro — que está sempre na árvore — e só depois no `world`. E `FxUtil.autofree`
passou a checar `is_inside_tree()` antes de `get_tree()`, porque nó solto é o
caso NORMAL ali e não merecia erro no log.

**A lição:** quando o projeto já registrou uma armadilha duas vezes, vale procurar
a terceira ocorrência **antes** de ela aparecer. `grep` por quem recebe `world` e
chama `get_tree()`/`get_world_3d()` sem checar a árvore é barato; descobrir meses
depois que um golpe nunca seguiu a mira, não.

---

## 2026-09-12 — a fruta saiu verde-oliva no jogo e dourada no Blender

**Sintoma.** O modelo autoral da Goro Goro renderizava como ouro convincente no
preview do Blender (`fruit_preview.png`) e aparecia **verde-oliva** dentro da
arena. Nenhum erro no log: o asset carregava, o material estava certo, a cor é
que era outra.

**O que eu quase conclui errado.** Minha primeira hipótese foi que o cel-shading
do jogo dessatura tudo, e que eu teria de aceitar. Errado — e a medição
desmentiu em um quadro: pus a fruta da **Ope** ao lado da Goro na mesma cena, e a
Ope aparece **vermelha viva**. O render não dessatura nada; o problema era meu.

**Causa raiz.** A luz azulada do céu da arena empurra a razão **verde/vermelho**
para cima em cerca de **+0,15**. Um material com G/R = 0,79 em sRGB — que no
Blender passa por ouro — chega na tela com G/R entre **0,88 e 0,95**, ou seja,
amarelo puro, e na face em sombra isso lê como oliva. Para a fruta parecer ouro
no jogo, o material precisa sair do Blender com G/R perto de **0,52**: mais
alaranjado do que parece certo na fonte.

Números medidos por amostragem de pixel na captura, não a olho:

| | G/R no material | G/R na tela |
|---|---:|---:|
| 1ª tentativa | 0,79 | 0,88 – 0,95 |
| versão entregue | 0,52 | 0,68 – 0,73 |
| Ope, mesmo quadro | — | 0,21 – 0,25 |

**A lição, que vale para todo asset novo deste projeto:** *o preview do Blender
confere **geometria**, não cor.* Cor se confere **no jogo**, na arena de
verdade, e de preferência ao lado de um asset já aprovado — a Ope serve de
referência. E se confere **medindo o pixel**: "parece esverdeado" é opinião,
`G/R = 0,91` é fato, e foi o número que apontou a direção do conserto.

**Armadilha de segunda ordem.** No mesmo episódio, `cos(a) ** .6` explodiu com
`TypeError: found 'complex'` porque nos polos da esfera `cos(a)` chega a −1e−17,
e negativo elevado a expoente fracionário é complexo em Python. Potência
fracionária em coordenada esférica pede `max(x, 0.0)` sempre.

---

## 2026-09-12 — o lançador do jogo apontava para um usuário que não existe

**Sintoma:** nenhum, e é esse o problema. `SkillsOnePiece.desktop` está no
repositório desde agosto com `Exec=/home/administrador/dev/skills-one-piece/jogar.sh`
e `Icon=` no mesmo caminho. Clicar nele não faz nada — não abre janela, não
imprime erro, o ambiente gráfico só ignora a entrada.

**Causa raiz:** o arquivo foi escrito numa máquina cujo usuário era
`administrador` e commitado com o caminho absoluto embutido. O usuário desta
máquina é `gabriel-bitti`, então `/home/administrador/` simplesmente não existe.
Ninguém percebeu porque o jogo é aberto pelo `./jogar.sh` no terminal, caminho
que nunca passa pelo `.desktop`.

**O mesmo defeito estava em cinco scripts Python de Blender** —
`check_base.py`, `check_bones.py`, `abrir_animacao_blender.py`,
`exportar_base_rigged.py` e `abrir_base_blender.py` — todos com
`/home/administrador/...` cravado. Os quatro primeiros foram removidos na
limpeza de 2026-09-12 (pipeline superado pelo `tools/bake_mixamo.gd`); o
`abrir_base_blender.py` foi consertado para derivar a raiz de
`os.path.dirname(os.path.abspath(__file__))`.

**A lição:** caminho absoluto de `$HOME` em arquivo versionado é bomba-relógio —
quebra em outra máquina e falha **em silêncio**, sem stack trace que aponte a
causa. Em script do repositório, o caminho sai da posição do próprio arquivo.
Vale um `grep -rn "/home/" --include='*.py' --include='*.sh' --include='*.desktop'`
antes de commitar.

---

## 2026-09-12 — a documentação ensinava um controle que não existe mais

**Sintoma:** `DOCUMENTACAO.md` (raiz) mandava apertar **`R`** para alternar entre
fruta e estilo de luta, e `docs/guia/ONDE_COLOCAR.md` mandava editar
`data/akuma_no_mi.json` e `data/characters.json` para mexer em frutas e
personagens. Nenhuma das duas coisas funciona.

**Causa raiz — duas fontes divergentes envelhecendo em paralelo.** O `R` deixou
de existir em 2026-09-06, quando a espada entrou como terceiro modo e a troca
virou `1`/`2`/`3` (`Player.gd:771`). A pasta `data/` nunca chegou a ser lida:
**nenhum `.gd` do projeto carrega `res://data/`** — as frutas vivem em
`SkillSystem.gd`, os estilos em `Balance.ESTILOS`, os personagens em
`CharacterBuilder.gd`. O `characters.json` ainda dava 120 de vida ao Buggy,
quando o jogo trabalha com 2048.

**Por que passou tanto tempo:** `DOCUMENTACAO.md` e `README.md` cobriam o mesmo
assunto. O `GUIA_DO_PROJETO.md` até avisava que o primeiro estava velho — mas o
`README.md` continuava listando-o como "visão geral do projeto", então quem
chegava pelo README caía na versão errada. Documentação velha que *ninguém
marcou como velha* é indistinguível da atual.

**Conserto:** `DOCUMENTACAO.md` e `data/` removidos; a tabela de controles foi
refeita a partir do `Player.gd` e vive no `README.md`; `ONDE_COLOCAR.md` agora
aponta a fonte de verdade de cada assunto.

**A lição:** duas visões gerais do mesmo projeto não se mantêm sincronizadas —
uma delas vira armadilha. Melhor uma só, e um aviso de remoção onde a outra
estava. Documento que descreve **controle ou dado** precisa citar o arquivo e a
linha de onde a informação saiu, senão não há como saber que envelheceu.

---

## 2026-09-10 — a pose parada escrevia por cima do golpe, e eu culpei a árvore suja

**Sintoma:** `test_corte_horizontal` reprovava 9 de 22 asserções com a espada
PARADA nos 16 quadros do corte — mesmo x e z do primeiro ao último quadro. Depois
que a guarda nova entrou, virou 11 de 22, e os números denunciaram o culpado: a
espada estava presa exatamente em x=+0,78 / z=+1,53, que é a posição da própria
guarda, não uma posição qualquer.

**Causa raiz:** `Melee` + `ProceduralAnimator` executam o corte da espada SEM
passar pelo `YoruController`. Durante esse golpe o `action_id` do controlador
fica vazio, ele conclui que o jogador está parado e aplica a pose de idle — e
como roda com `process_physics_priority = 50`, depois do Player, é a escrita dele
que sobra. O corte inteiro acontecia e era apagado no mesmo quadro.

**Evidência:** `_golpe_procedural_em_curso()` (ler `_sword_slash_type >= 0` do
animador) e devolver o corpo ao caminho antigo levou o teste de 11 para 3
reprovações — abaixo das 9 que existiam antes de qualquer mudança de hoje. As 3
restantes são do próprio caminho antigo: mão esquerda a 0,84 m do cabo, fio a
37,4° e tronco girando 42,2°.

**Descartado — e este é o erro que mais importa aqui.** Eu tinha concluído, horas
antes, que essa falha vinha "de outra mudança não commitada da árvore". A
medição por worktree estava correta: o teste passa 22/22 no HEAD e continuava
passando com os sete arquivos da frente Yoru copiados por cima. O erro foi na
INFERÊNCIA: como o conserto exigia `YoruRig.gd` e `Player.gd`, que eu não havia
copiado, o conflito não podia se manifestar lá. Uma worktree prova o que roda
dentro dela, e nada sobre o que ficou de fora.

**Correção:** `src/combat/YoruController.gd` — `_golpe_procedural_em_curso()`, e
o `return` antes de aplicar a pose parada.

**Como detectar de novo:** número congelado é assinatura de sobrescrita, não de
animação parada — quando um teste de trajetória repete o MESMO valor em todos os
quadros, procurar quem escreve por último no mesmo nó, não o que deixou de
escrever. E ao inocentar o próprio trabalho por bisseção, conferir se os arquivos
copiados bastam para o defeito aparecer; senão o teste verde não prova nada.

---

## 2026-09-10 — o teste do avanço media a colisão, não a mecânica

**Sintoma:** o primeiro `medir_avanco_yoru.gd` deu "M1_1 acertando para antes:
0,85 m contra 1,40 m" e pareceu aprovar a mecânica nova. Mas o X, cuja passada
NÃO deve ser encurtada por acerto nenhum, também saiu com 0,85 m — o mesmo
número. Número igual para regras opostas é o sinal de que o teste não estava
medindo a regra.

**Causa raiz:** o alvo do fixture é um `StaticBody3D` na camada 1, a mesma que a
máscara do corpo do jogador. O `move_and_collide` do avanço batia no alvo e
parava ali. Os 0,85 m eram a distância até encostar no boneco, idêntica para
qualquer ação — o corte por `_conectou` nunca chegou a ser exercido.

**Evidência:** os três casos convergiram para 0,85 m, que é exatamente a folga
entre as caixas do jogador (0,4) e do alvo (0,5) na distância de teste de 1,3 m.
Com o alvo movido para a camada 2 — visível para a varredura da lâmina, que cobre
as camadas 1-4, e invisível para a máscara 1 do corpo — os números se separaram:
M1_1 1,40 contra 0,50, M1_2 1,80 contra 0,63, e o X ficou nos 2,80 m nos dois
casos, como manda a regra dele.

**Descartado:** não era o sinal `acertou` deixando de disparar (o `hits == 1` do
próprio teste provava o contrário), nem a janela do avanço.

**Correção:** `target.collision_layer = 2` em
`tools/dev_tests/medir_avanco_yoru.gd`, com o motivo escrito ao lado. E a
distância do caso curto do X passou a 4,1 m: com 1,3 m ele atravessa o alvo
durante a passada e a lâmina arma quando o boneco já ficou para trás.

**Como detectar de novo:** num teste de deslocamento, medir SEMPRE o par de casos
que deveria divergir. Um valor sozinho não distingue "a mecânica funcionou" de
"algo sólido estava no caminho".

---

## 2026-09-10 — o clarão de impacto era um quadrado dourado

**Sintoma:** a primeira captura do M1 novo mostrou, no lugar do flash de acerto,
um RETÂNGULO dourado sólido cobrindo o alvo. Os raios roxos da lâmina, na mesma
captura, saíram brancos.

**Causa raiz:** duas faces do mesmo engano — confiar na cor para dar forma ao que
é geometria e a faixa dinâmica. O clarão era um `QuadMesh` unshaded pintado de
dourado: sem textura, um quad aparece como o quadrado que ele é, porque nada
descreve a queda até a borda. E os raios usavam `Color(2,6 · 1,05 · 3,4)`, HDR
alto demais: passado certo ponto o bloom satura os três canais e a matiz some, de
modo que "mais roxo" vira branco.

**Evidência:** `art_src/previews` do momento do acerto, com o retângulo de bordas
retas visível sobre o boneco; e os raios sem nenhum resto de roxo ao lado de um
rastro roxo que aparecia normalmente no mesmo quadro.

**Correção:** `GradientTexture2D` radial em `YoruFX._textura_clarao()` para o
flash, e `COR_RAIO` reduzida para `Color(1,45 · 0,42 · 2,15)`. Na mesma passagem,
o miolo escuro do arco (`YoruFX.fita_do_clique`) precisou de alfa 1,0: com 0,88 o
fundo claro atravessava e o "quase preto" lia como lavanda.

**Como detectar de novo:** olhar a captura, não só o código. Um efeito aditivo
sobre fundo claro e um mesh sem textura são os dois casos em que o valor escrito
na constante e o que chega na tela deixam de ter relação.

---

## 2026-09-10 — a Yoru foi forjada com o gume no lado côncavo

**Sintoma:** o dono, olhando uma gravação de tela do M1, disse que "o local onde
deveria estar o corte está do lado errado da espada". Na tela, a faixa ciana que
marca o FIO corria pelo flanco quase reto da lâmina, e a barriga da curva — o lado
que o olho lê como gume numa cimitarra — estava marcada em âmbar como DORSO.

**Causa raiz:** a seção transversal em `tools/blender/yoru_master.py` prende a
aresta afiada em `center + half_width`, ou seja no lado +X do centro. Só que a
linha de centro fugia para −X (`center = -.095*sin(pi*t)*(.5+.5*t)`), o que joga a
barriga convexa para o lado OPOSTO ao da aresta. O gume acabou moído no flanco
côncavo e a barriga ficou grossa e cega: uma foice montada ao contrário. Numa
lâmina curva de gume único o corte vai no lado convexo, que é o que percorre mais
distância e encontra o alvo primeiro.

**Evidência:** seção medida direto no `yoru_v2.glb`, por faixa de altura. Em
y = 1,00 m o lado +X estava a +0,046 com espessura 0,0000 m (a aresta) e o lado −X
a −0,180 com 0,0034 m (o chanfro): o lado afiado era o de dentro da curva e o
alcance da barriga, o de fora. Depois da correção os mesmos cortes dão +0,180 com
0,0000 m e −0,046 com 0,0034 m — espelhados, com o gume na barriga.

**Descartado:** o marcador ciano/âmbar NÃO estava mentindo, e mexer nele teria
escondido o defeito. Ele, o nó autoral `edge_direction` (+X) e as duas constantes
`YoruRig.ROLAMENTO_*` são todos coerentes com a malha — o sistema inteiro estava
fiel a uma malha errada. Também não era orientação de empunhadura nem rolamento:
`medir_fio_yoru.gd` já dava fio·deslocamento positivo em todas as seis ações antes
da correção, e dá os mesmos números depois.

**Correção:** constante nomeada `BLADE_BELLY = .095`, agora POSITIVA, em
`tools/blender/yoru_master.py:36`, usada nas duas fórmulas da lâmina (linhas 274 e
296); mesmo sinal em `src/items/YoruSword.gd:129`, que desenha o marcador com uma
cópia da fórmula. Rebake do GLB pelo Blender. Nada mais no jogo mudou: como o gume
continua em +X, `edge_direction`, os rolamentos, a hitbox e as duas animações de
corte já aprovadas seguem válidos.

**Como detectar de novo:** `validate_export()` do próprio gerador agora quebra o
build — a mesh `Blade` tem de alcançar mais em +X (barriga 0,1489) do que em −X
(dorso 0,0840). Visualmente, `TAG=<nome> godot --path . --display-server x11 -s
tools/dev_tests/captura_fio_yoru.gd`: a faixa ciana tem de cair sobre a borda
convexa, não sobre a reta.

---

## 2026-09-10 — o Godot serviu a malha antiga depois do rebake, e a captura mentiu

**Sintoma:** logo depois de reexportar `yoru_v2.glb` com a curvatura espelhada, a
captura de conferência saiu com a faixa ciana FLUTUANDO NO AR ao lado da lâmina e
a âmbar enfiada no meio da chapa — nenhuma das duas sobre uma borda. Parecia que a
correção da fórmula do marcador tinha errado o alvo.

**Causa raiz:** o marcador é desenhado por código GDScript (lido do disco a cada
execução) e a lâmina vem do `.glb` (lido do CACHE de importação). Rodar o Godot com
`-s <script>` não dispara reimportação: ele carregou
`.godot/imported/yoru_v2.glb-<hash>.scn` de 09/09, a malha velha, e desenhou o
marcador novo em cima dela. Os dois lados da comparação vinham de versões
diferentes do mesmo asset.

**Evidência:** `.godot/imported/yoru_v2.glb-*.scn` com data de 09/09 14:15 enquanto
o `assets/models/weapons/yoru_v2.glb` já estava com 10/09 18:11. Apagado o cache e
reimportado, o `.scn` passou a 10/09 18:13 e a mesma captura saiu com o ciano
encostado na borda convexa.

**Correção:** nenhuma no código — é procedimento. Depois de reexportar qualquer
asset, rodar `godot --headless --editor --path . --quit` (ou apagar
`.godot/imported/<asset>-*`) ANTES de qualquer captura ou medição.

**Como detectar de novo:** comparar as datas de `assets/.../<asset>` e de
`.godot/imported/<asset>-*.scn`. Se o `.scn` for mais antigo, tudo que a tela
mostrar sobre esse asset está desatualizado. O mesmo cuidado que já valia para
validar parse com `--headless --editor` em vez de `--check-only`.

## 2026-09-10 — o sprint corria encarando o chão, e o teste ficava verde

**Sintoma:** nada visível numa olhada rápida — é justamente por isso que durou. No
SPRINT (Shift) o personagem corre com a cabeça apontada 13,5° abaixo do horizonte,
olhando para o próprio pé em vez de para onde vai. O `test_walk_run` aprovava o
item "cabeça estável" com +3,7°.

**Causa raiz:** o teste mede o olhar como `-Head.rotation.x - Torso.rotation.x`,
uma soma de DOIS elos. Isso era correto quando a cabeça pendurava direto no
tronco. Desde o `base_v2` (08/09/2026) a cadeia é
`Torso→SpineLower→SpineMid→Chest→Neck→NeckUpper→Head`, e o `RigDetalhado.marcha`
passou a inclinar `SpineMid` e `Chest` para frente — 24,3° de peito medidos no
sprint. Esses dois elos ficam ENTRE os dois que o teste soma, então a inclinação
que de fato chega à cabeça nunca entrava na conta. O `RigDetalhado` compensava a
torção (yaw) da coluna na cabeça, mas não a inclinação (pitch): o cabeçalho da
função só previa o eixo Y.

**Evidência:** `tools/dev_tests/medir_corrida.gd`, base a 7 m/s, pitch tirado do
`global_basis` da cabeça relativo à raiz do personagem — o que o olho vê:
`Torso -14,9° | Chest -24,3° | Head -13,5°`, contra os `+3,7°` que o
`test_walk_run` imprimia na mesma cena, no mesmo quadro.

**Descartado:** não era o `_lookat` (o pitch da mira entra por fora e estava em
0,0 na medição), não era o `lean` do `_locomotion` isolado (sozinho ele dá -14,9°,
e a cabeça já devolvia 11,2° disso), e não era o filtro de rigidez (a medição roda
240 quadros de estabilização antes de amostrar).

**Correção:** `src/anim/RigDetalhado.gd` — a devolução do olhar virou conta
derivada em vez de constante calibrada à mão (`_olhar_yaw`/`_olhar_pitch`, a
partir de `RESIDUO_OLHAR`/`RESIDUO_PITCH` e da soma de coeficientes que cada
regime aplica na coluna). A `corrida()` chama as duas; a `marcha()` chama o yaw e
dá exatamente o mesmo número de antes. Olhar do sprint: -13,5° → -1,2°.

**Como detectar de novo:** item **6b** do `tools/dev_tests/test_walk_run.gd`
("olhar REAL (com a coluna)"), que mede pelo `global_basis` da cabeça e reprova
acima de 12°. O item 6 antigo continua lá — os dois juntos mostram a divergência
entre a fórmula e a pose, que é o sintoma da classe inteira de erro. Instrumento
completo: `godot --headless --path . -s tools/dev_tests/medir_corrida.gd`.

⚠️ **A classe do erro, que é o que importa:** *teste que soma elos nomeados um a
um envelhece calado quando o rig ganha juntas no meio da cadeia.* O `base_v2`
trouxe 126 juntas onde havia 13; todo teste que cita `Torso` e `Head` na mesma
expressão precisa ser relido com essa pergunta — quem entrou no meio?

## 2026-09-10 — a manopla de girar apontava para um lado e o osso girava para outro

**Sintoma:** relatado pelo usuário a partir de uma captura. Selecionando o braço
com a ferramenta de girar, "o verde que deveria estar na horizontal está na
vertical". Os campos do painel mostravam `0°, 0°, 0°` na Pose T, corretamente,
mas os anéis do gizmo apareciam tortos.

**Causa raiz:** `view.gd` desenhava as manoplas de **girar** no `global_basis` do
próprio osso (`joint.global_basis` para `mode in ["rotation","scale"]`). Só que
`rotation` é um Euler **local**, que vive no espaço do **pai**. Nos ossos cuja
pose de repouso já é girada, os dois espaços divergem — e `_build_t_reference()`
gira justamente os braços para transformar a pose A do GLB numa T: o
`UpperArm_R` carrega `+70,80°` em `rotation.z` na própria Pose T. O anel era
desenhado 70,8° fora do eixo em que a rotação realmente acontecia. O mesmo basis
errado decidia o sinal do arraste.

**Evidência:** medindo, para cada eixo, em torno de que direção do mundo o osso
gira ao mudar 5° no campo, contra a direção em que o anel é desenhado
(produto escalar, 1,000 = alinhado):

| osso | ferramenta | eixo do OSSO | eixo do PAI |
|---|---|---|---|
| UpperArm_R | girar | **0,329** | 1,000 |
| UpperArm_R | tamanho | 1,000 | 0,329 |
| UpperArm_R | mover | 0,329 | 1,000 |
| Torso, Thigh_L, Head | todas | 1,000 | 1,000 |

Ou seja: **girar e mover pertencem ao pai; tamanho pertence ao osso.** Mover já
usava o pai e estava certo; tamanho já usava o osso e estava certo; só girar
estava no espaço errado. Ossos com repouso não-girado (tronco, coxa, cabeça)
casavam nos dois, e foi por isso que o defeito passou despercebido — ele só
aparece nos braços.

**Descartado:** não era a Pose T "errada" (o `displayed()` já zerava contra a
referência, medido em 10 ossos); não era o `_build_t_reference` (a T resultante
está correta, com os braços na horizontal); não era projeção de câmera.

**Correção:** `tools/anim_editor/studio/view.gd:147` — `tool_basis()` como fonte
única do espaço de cada ferramenta, usada no desenho das manoplas
(`view.gd:252`), nos ticks da régua (`view.gd:311`) e no sinal do arraste de
rotação (`view.gd:218`).

**Como detectar de novo:** `test_studio.gd` ganhou
`the <ferramenta> handle on <osso> points where the bone actually moves`, que
para cinco ossos e as três ferramentas compara o eixo desenhado com o eixo real
medido no rig. Revertendo `tool_basis` ao comportamento antigo, a suíte acusa os
dois braços com 0,329.

---

## 2026-09-10 — o "segurar pose" nunca chegou ao jogo: a chave-sombra era fundida na exportação

**Sintoma:** silencioso, ninguém tinha notado. O estúdio de animação mostrava a pose
segurando até saltar no ponto seguinte, e o jogo reproduzia o MESMO clipe subindo em
rampa linear. Nenhum aviso, nenhum erro; o `.tres` tinha tamanho e contagem de faixas
plausíveis (381).

**Causa raiz:** `Doc.animation()` representa o degrau inserindo uma "chave-sombra" com
o valor antigo logo antes da chave seguinte. A distância era
`minf(0.00001, intervalo*0.25)` — e como `0.00001` é sempre o menor dos dois, a sombra
ficava SEMPRE a 0,00001 s da próxima. **`Animation.track_insert_key` funde chaves quase
coincidentes**: a chave seguinte substituía a sombra na hora da inserção. A faixa saía
com 2 chaves em vez de 3 e o Godot interpolava linearmente entre elas.

**Evidência:** clipe de teste com braço em 0° no ponto 0,0 s e 90° no ponto 1,0 s, com
hold ligado. Faixa `UpperArm_R:rotation` exportada com **2 chaves** (`0.000000s`,
`1.000000s`); a sombra em `0.999990s` não existia. Amostrando o mesmo instante:

| t | editor | jogo |
|---|---|---|
| 0,25 s | 0° | 22,5° |
| 0,50 s | 0° | **45°** |
| 0,90 s | 0° | 81° |

Limiar de fusão medido em Godot 4.6.3: `0,00001 s` some, `0,0001 s` sobrevive.
Confirmado também depois de `ResourceSaver.save` + `ResourceLoader.load`, que é o
caminho real do jogo.

**Descartado:** não era o `StudioPlayback` (ele só chama `value_track_interpolate`, e
recebe a faixa já sem a sombra); não era o `.tres` corrompendo no disco (a fusão
acontece antes, no `track_insert_key` em memória); não era o `sample_keys` do editor,
que trata o hold corretamente.

**Correção:** `tools/anim_editor/studio/document.gd:9` — constante `HOLD_GAP := 0.001`
(com folga de 10× sobre o limiar medido, e ainda 3% de um quadro a 30 fps), usada em
`document.gd:186` como `end - minf(HOLD_GAP, intervalo*0.5)`.

**Como detectar de novo:** `test_studio.gd` ganhou a verificação
`held pose reads the same mid-segment`, que amostra o **meio** de um trecho segurado no
editor e na animação exportada e exige o mesmo número. Revertendo `HOLD_GAP` para
`0.00001` a suíte acusa 6 falhas.

---

## 2026-09-10 — o teste do export passava porque amostrava no único instante em que degrau e rampa concordam

**Sintoma:** a suíte fechava **77 verificações, 0 falhas** com o bug acima ativo. O
teste `export exact middle point matches editor` existia justamente para comparar
editor e exportação, e não viu nada.

**Causa raiz:** ele amostrava com `value_track_interpolate(track, .6)` — e `0,6 s` era
**exatamente o tempo de um ponto**. Em cima de uma chave, degrau e rampa devolvem o
mesmo valor por definição: o valor da própria chave. O teste media o único instante do
clipe onde os dois comportamentos são indistinguíveis. O nome dizia "middle point"
(ponto do meio, o terceiro de três), não "meio do trecho" — e isso mascarou a lacuna.

**Evidência:** `test_studio.gd:101` com `.6` contra pontos em `0,0 / 0,6 / 1,0`.
A verificação nova, amostrando em `0,25 / 0,5 / 0,75 / 0,9` (todos entre chaves),
acusa o bug imediatamente.

**Correção:** `tools/anim_editor/studio/test_studio.gd` — bloco novo que exporta um
clipe segurado, compara editor × animação em quatro instantes **entre** chaves, e
confere o resultado depois de passar pelo disco.

**Como detectar de novo:** ao testar interpolação, nunca amostre em cima de uma chave.
O valor da chave é o mesmo em qualquer modo de interpolação; só o miolo do trecho
distingue step, linear e curva.

---

## 2026-09-10 — todo ponto nascia em degrau, e o botão de suavizar age no ponto anterior

**Sintoma:** relatado pelo usuário — "ao levantar o braço de um boneco, o braço se
levanta instantaneamente quando o tempo da animação é atingido; deveria ocorrer de
forma lenta e gradual".

**Causa raiz:** duas coisas somadas. (1) `Doc.mark()` criava todo ponto novo com
`hold: true`, então o padrão da ferramenta era degrau — num clipe autorado com 20
pontos, **20 de 20 nasceram em degrau**. (2) O botão "Transição suave" edita o `hold`
do ponto **selecionado**, que governa o trecho que SAI dele. O animador seleciona por
instinto o ponto de destino (onde o braço já está levantado) e liga lá — o que não
muda nada, porque quem controla aquela passagem é o `hold` do ponto de ORIGEM. O
rótulo não dizia a direção e não havia "aplicar a todos os pontos".

**Evidência:** braço em T no ponto 0 e levantado no ponto 1,0 s dava
`[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 90]` graus ao longo do clipe. Ligando "Transição
suave" **no ponto de 1,0 s**: curva idêntica, `[0, …, 0, 90]`. Ligando no ponto de
`0,0 s`: `[0, 9, 18, 27, 36, 45, 54, 63, 72, 81, 90]`.

**Correção:** padrão invertido para interpolar — `document.gd:63` e `document.gd:66`
passam `hold: false` (decisão do usuário em 10/09/2026: alinhar com Blender/Maya/Godot,
degrau vira exceção marcada de propósito). Rótulo do botão passou a declarar a direção:
`main.gd:273` → "Suavizar até o próximo", com dica explicando que age no trecho que sai
do ponto.

**Como detectar de novo:** `test_studio.gd` verifica
`a new point interpolates by default`; o teste que exercia o degrau agora o liga
explicitamente com `transition(t, true)`.

---

## 2026-09-06 — mudar um rótulo do HUD encostou dois botões de toque

**Sintoma:** achado na revisão. A bateria fechou em **59 passou / 10 falhou**
contra a linha de base de 55/9 — uma falha NOVA: `test_toque`, com
"PULO×Z (77 px, precisa de 84)".

**Causa raiz:** o `ToqueHud` posiciona os botões **a partir da `SkillBar`**: a
coluna Z/X/C/V fica à ESQUERDA dela (`r.position.x - FOLGA - RAIO`) e a fileira
PULO/DASH/F é alinhada à DIREITA. Ou seja, a **largura da barra decide o
espaçamento dos botões** — e a largura da barra depende do TEXTO dentro dela.

Ao trocar os títulos de `"FRUTA: %s [R: Alternar]"` para `"FRUTA: %s [1]"`, a
barra estreitou, a borda esquerda andou para a direita, a coluna de skills foi
junto e encostou no PULO. Um rótulo de HUD quebrou o alcance do dedo no celular.

**Correção:** `custom_minimum_size.x = 300` na `SkillBar`. Não é cosmético: corta
a dependência entre texto e layout, então mudar rótulo deixa de mover botão.

**Como detectar de novo:** layout que se ancora em `get_global_rect()` de outro
controle herda TODAS as variações daquele controle, inclusive as de conteúdo.
Quem serve de âncora precisa de tamanho mínimo.

**O que isto diz sobre a revisão:** a falha não apareceu em nenhum dos testes que
eu rodava a cada mudança — só na bateria completa, e só porque `test_toque`
exige TELA (roda sem `--headless`). Rodar a bateria inteira contra uma linha de
base numérica é o que a pegou.


## 2026-09-06 — a lâmina TELEPORTAVA de um lado ao outro: `ease_out_expo` no corte

**Sintoma:** o corte não lia como corte. Medida a trajetória da ponta em espaço
LOCAL do personagem, ela saltava de x = +1,53 para x = −1,22 entre duas amostras
— 2,75 m sem passar pela frente. Não havia arco.

**Causa raiz:** a fase de golpe usava `ease_out_expo`, que completa

    10% da janela -> 50,0% do arco
    30% da janela -> 87,5% do arco
    50% da janela -> 96,9% do arco

Metade do corte acontecia nos primeiros 10% e o resto rastejava. `ease_out` é
uma curva de CHEGADA (rápida no começo, lenta no fim); um golpe precisa de uma
curva de PASSAGEM, rápida no meio.

**Correção:** `ease_corte`, uma curva em S (`x^n/(x^n+(1-x)^n)`): 0,4% aos 10%,
50% aos 50%, 99,6% aos 90%. A lâmina acelera entrando no centro, é mais rápida
ao cruzar e desacelera saindo.

**Como detectar de novo:** curva de easing errada não dá erro nem warning — dá
uma animação que "não parece certa". O sinal objetivo é amostrar a trajetória e
procurar SALTOS entre quadros consecutivos.

## 2026-09-06 — o golpe não tinha follow-through: a arma era freada no ar

**Sintoma:** achado ao conferir os 16 quadros de referência da especificação do
dono. No **quadro 11** ("final do corte, espada claramente à ESQUERDA") a espada
já estava em x = +1,33 — de volta ao lado DIREITO.

**Causa raiz:** a recuperação (`ease_out_elastic`) começava no instante exato em
que o corte terminava. Não havia inércia: a arma parava no fim do arco e voltava
num tranco. Uma Yoru de 1,38 m não para no fim do arco — ela passa um pouco, e é
esse excesso que comunica massa.

**Correção:** uma fase própria de follow-through entre o corte e a recuperação
(`FOLLOW_THROUGH` = 13% do clipe, `EXCESSO_INERCIA` = 0,18 além do ponto final),
alinhada com a faixa 65–78% que a especificação pede. Medido depois: quadro 11 em
x = −1,54, quadro 12 em x = −1,41.

**Como detectar de novo:** três fases (preparo, golpe, recuperação) descrevem um
soco, não um golpe com massa. Arma pesada precisa da quarta.

## 2026-09-06 — a hitbox abria com a espada ainda armada à direita

**Sintoma:** achado ao medir a trajetória contra a janela de dano. Com as fases
da animação coincidindo exatamente com `startup`/`ativo`, o fio cruzava a frente
do personagem a **92% da janela** — o dano nascia com a lâmina ainda no alto à
direita e fechava justamente quando ela cruzava.

**Causa raiz:** eu tinha derivado as fases da animação do frame data para elas
"não poderem divergir" — o que resolveu um problema (a defasagem de 0,102 s) e
criou outro. A lâmina é carregada pelo `ForeArm_R`, que anda com o frame
atrasado pela cadeia cinética; e a espada já parte da direita no repouso (ponta
em x = +0,97 local), então o fio só cruza o centro bem depois de o `frame` passar
pelo neutro. Igualdade de fases não é igualdade de posições.

**Correção:** `Melee.COMPENSACAO_CADEIA` adianta as fases da ANIMAÇÃO (e só
delas) em 0,077 do clipe. `startup`/`ativo` continuam sendo os números de jogo.
Medido depois: o cruzamento cai a 43% da janela.

**Como detectar de novo:** derivar B de A garante que eles mudam juntos, não que
significam a mesma coisa. Quando há atraso mecânico entre a causa e o efeito, a
ponte precisa do atraso escrito nela.


## 2026-09-06 — pus a varredura no tronco, e o personagem passou a girar em bloco

**Sintoma:** relato do dono — *"o personagem rotaciona correto, porém a animação
está permanecendo a mesma como se ele estivesse estático [...] cabeça e torso
ficam estáticos, pernas se dobram para manter o equilíbrio e os braços se movem
ao redor do torso"*.

**Causa raiz:** decisão minha, tomada para resolver OUTRO problema. A mão
esquerda soltava do cabo durante o corte, e uma busca por cinemática direta
provou que nenhum ângulo do braço esquerdo resolvia. Concluí que "quem gira num
corte de duas mãos é o CORPO" e mudei a varredura para o tronco (Y = 1,70 rad).

A empunhadura melhorou. E a animação morreu, porque neste rig:

    Torso
    ├── Neck / Head
    ├── UpperArm_R|L / ForeArm_R|L
    └── Thigh_R|L / Shin / Foot

O `Torso` é **pai de tudo**. Yaw nele roda cabeça, braços e pernas juntos: o
personagem girava numa bandeja. Eu tinha otimizado uma métrica (distância da mão
ao cabo) sem olhar o que ela custava na leitura do movimento.

**E contaminou uma medição.** Reportei "o pé direito avança 0,33 m" como passada;
era a perna sendo CARREGADA pela rotação do tronco. Passada de verdade tem de
sair da própria perna.

**Correção:** o giro voltou para os braços (Y grande em `UpperArm_R/L`, ambos no
mesmo sentido), o tronco ficou com 8,4° de yaw — só antecipação — e as pernas
ganharam flexão própria (42,8° e 34,7° de joelho) para segurar o arremesso.

**Custo declarado:** a mão esquerda se afasta 0,38 m do cabo contra 0,32 m na
versão de tronco. O ombro deste rig não translada, então alcance de braço é o
teto. O dono escolheu esta leitura sabendo do número.

**Como detectar de novo:** antes de mover um movimento para um osso "mais alto"
da cadeia, olhe QUEM SÃO OS FILHOS dele. Num rig com tronco-raiz, tudo que se
resolve girando o tronco se paga girando o personagem inteiro.

**A armadilha do teste:** a asserção que eu tinha escrito ("o pé esquerdo recua,
virando pivô") PASSAVA na versão errada, porque o tronco levava a perna. Ela
media o sintoma do defeito. Foi trocada por "as pernas dobram", que é o que o
dono pediu, e ganhou companhia: "o tronco fica quase parado", que é a guarda do
defeito em si.


## 2026-09-06 — a lâmina EMPINAVA no meio do corte horizontal

**Sintoma:** achado ao medir, a pedido do dono ("a direção da lâmina da espada
durante o movimento"). Rastreando o ângulo do fio com a vertical: 80° parado
(quase deitada, correto) e **43,8° no auge do golpe** — no meio do corte a
lâmina empinava 46° para fora da horizontal. Um corte horizontal com a lâmina
empinada bate de chapa.

**Causa raiz:** a espada nasce colada à mão com `rotation = ZERO` e daí em diante
é apenas CARREGADA pelo braço. Ela não tinha direção própria: o que o ombro e o
cotovelo fizessem com o antebraço, o fio herdava. Numa varredura horizontal a
cadeia do braço naturalmente rola, e a lâmina rolava junto.

**Por que a correção não podia vir dos ossos:** girar o antebraço para deitar a
lâmina moveria a MÃO junto, e a mão é o que segura o cabo — desfaria a
empunhadura de duas mãos que custou uma busca por cinemática direta.

**Correção:** a arma ganhou postura PRÓPRIA (`WeaponPoses.postura_da_arma`),
aplicada ao nó da espada em torno da origem dela, que é o `handle`, que é onde a
mão está. Gira o fio sem mover o ponto de pega.

**⚠️ E a primeira versão compensou na FASE ERRADA.** Usei o `frame` do tronco;
quem carrega a lâmina é o `ForeArm_R`, que anda com o frame atrasado em 0,06 (a
cadeia cinética). Resultado medido: ótimo no auge (89,1°) e mergulhando a 55,9°
na ENTRADA da janela ativa. Com o mesmo atraso do antebraço, a janela inteira
ficou entre 69,7° e 89,6°.

**Como detectar de novo:** quando uma correção acompanha uma causa que tem
atraso, ela precisa do MESMO atraso. Compensação certa no relógio errado
conserta um instante e estraga os vizinhos.

## 2026-09-06 — a base do corte era simétrica, e os dois pés terminavam do mesmo lado

**Sintoma:** achado ao medir ("a troca da posição dos pés"). Rastreando os pés no
eixo lateral do jogador durante o corte horizontal, os DOIS terminavam em −0,30
no auge — juntos, do mesmo lado. Lê como tropeço, não como passada.

**Causa raiz:** a pose das pernas era compartilhada pelos três cortes e usava
`absf(frame_torso)`:

```gdscript
add.call(off, "Thigh_R", Vector3(0.2,  0.5,  0.3) * absf(frame_torso) * w)
add.call(off, "Thigh_L", Vector3(0.2, -0.5, -0.3) * absf(frame_torso) * w)
```

O `absf` tira o SENTIDO: preparo e golpe abriam as coxas do mesmo jeito. E sendo
igual para os três tipos, nenhum deles tinha passada própria — as pernas só
seguiam o tronco por herança de transformada.

**Correção:** o bloco compartilhado ficou só com o agachamento (comum aos três) e
o corte horizontal ganhou passada própria, com `frame_torso` em vez de `absf`
para ter sentido, e com Shin e Foot entrando na conta. Medido depois: pé direito
avança 0,33 m cruzando, esquerdo recua 0,15 m virando pivô, e a base volta com
0,00 m de resto.

**Como detectar de novo:** `absf` num sinal de animação apaga a direção do
movimento. Serve para "quanto", nunca para "para que lado".


## 2026-09-06 — a lâmina passava 0,102 s antes de a hitbox nascer

**Sintoma:** pedido do dono — *"ajustar o tempo e fazer a animação horizontal
bater com o tempo do ataque"*.

**Causa raiz:** duas descrições independentes da mesma coisa. `WeaponPoses` tinha
as fases do golpe escritas à mão em **0,20 e 0,26 do ciclo**; a hitbox nascia em
`startup` e vivia `ativo` **segundos**, vindos de `Melee.COMBO_SWORD`. Nada
ligava um ao outro.

    corte horizontal (ciclo de 0,49 s)
      a lâmina VARRE em: 0,098 -> 0,127 s
      a hitbox VIVE em : 0,200 -> 0,290 s

Seis quadros de defasagem: o fio cruzava o alvo e o dano só aparecia depois, com
a espada já no arco de volta.

**Correção:** `Melee.fracao_do_golpe(i, arma)` deriva as fronteiras do mesmo
frame data que arma a hitbox, e o Player as passa para a animação. Erro medido
depois: **0,0000 s**. A janela do rastro segue as mesmas fronteiras — ela também
era fixa (0,18..0,32) e brilharia fora do corte.

**Como detectar de novo:** quando animação e mecânica descrevem o mesmo instante
em unidades diferentes (fração do ciclo contra segundos), elas vão divergir na
primeira vez que alguém mexer num lado só.

## 2026-09-06 — deduzi o sinal do giro pelos rótulos, e estava invertido

**Sintoma:** com a pose "corrigida", a lâmina ia para a ESQUERDA no preparo e
voltava para a direita no golpe — o contrário do pedido.

**Causa raiz:** li a convenção de sinal nos nomes das poses existentes. O tipo 0
chamava-se "Corte Direita para Esquerda" e usava Y negativo, o tipo 1 ("Esquerda
para Direita") usava positivo; concluí que Y negativo = esquerda. Rastreando a
ponta da lâmina no eixo lateral do jogador, o preparo levava a espada de +1,07 m
para −0,11 m — ou seja para a esquerda, com coeficiente negativo. Invertido.

**Evidência:** a curva da ponta por quadro, que também revelou outra coisa que eu
não tinha visto — o extremo mais à direita do clipe inteiro acontece no RECUO
(o `ease_out_elastic` devolve a espada), não no preparo. A primeira asserção do
teste comparava extremos GLOBAIS e reprovava um golpe correto.

**Correção:** coeficiente positivo, medido. E o teste passou a olhar só a IDA,
com a fronteira vindo de `fracao_do_golpe` em vez de um 0,75 escolhido a olho.

**Como detectar de novo:** rótulo não é medida. Num rig com eixos não óbvios, a
única fonte confiável de "para que lado isso gira" é rastrear um ponto e olhar
o número.

## 2026-09-06 — a empunhadura de duas mãos nunca existiu

**Sintoma:** achado ao medir, não relatado. O pedido era "ambos os braços
grudados na lâmina"; ao instrumentar, a mão esquerda estava a **0,875 m** do cabo
já no REPOUSO.

**Causa raiz:** a pose de descanso tinha o comentário *"Braço Esquerdo (segunda
mão no pomo/base da espada) cruza o corpo para alcançar o cabo"* — e os ângulos
não alcançavam nada. O comentário descrevia a intenção, não o resultado, e
ninguém tinha medido.

**Correção:** os ângulos saíram de uma BUSCA por cinemática direta (varredura dos
dois ossos do braço, medindo a distância da mão ao cabo a cada combinação), não
de tentativa e erro. 0,875 m -> 0,25 m no repouso, 0,38 m no pior instante do
golpe. O melhor alcançável no auge, por busca exaustiva, é 0,154 m.

**O que ficou como limite conhecido:** braços de um osso só, ombro que não
translada e a espada rígida no antebraço direito. Baixar de 0,38 m exige mudar o
RIG, não afinar mais ângulo — está escrito no teste, junto do número.

**Como detectar de novo:** comentário que afirma geometria ("alcança o cabo",
"aponta para o alvo", "fica na altura do peito") é hipótese até alguém medir.


## 2026-09-06 — o corte de espada usava o efeito do SOCO, e o rastro saía do cotovelo

**Sintoma:** relato do dono, com gravação de tela — *"o efeito do combate corpo a
corpo está acontecendo ao invés do efeito da espada"*. No vídeo dá para ver a
espada correta na mão, o HUD em `ESPADA: YORU [3]`, e mesmo assim os efeitos do
punho em tela.

**Eram DOIS defeitos independentes, com o mesmo sintoma.**

**1. O anel de choque do soco.** No ramo da espada eu chamei `Melee._impacto` de
propósito, com o comentário *"é o tempero visual do golpe, independente de onde
a hitbox mora"*. Errado: `_impacto` desenha um `TorusMesh` — a onda de choque que
o SOCO atravessa — nascendo a `alcance` metros à frente do peito. Com o punho
funciona, porque o punho chega lá. Com a espada o anel aparecia solto no ar, sem
relação nenhuma com onde a lâmina estava.

**2. O rastro saía do COTOVELO.** `ProceduralAnimator` desenhava a faixa entre
`ForeArm_R` e um ponto chutado a `(0, -1.8, 0)` dele — com o comentário honesto
"ponta da espada PRESUMIDA". Com a Yoru na mão a lâmina só começa 0,75 m depois
do cotovelo, então a faixa cobria o antebraço INTEIRO mais a lâmina: em tela,
uma chapa branca saindo do peito, apontando para um lado enquanto a espada
apontava para outro.

**Causa raiz comum:** os dois efeitos eram calculados a partir do CORPO (um
ponto à frente do peito; um osso do braço) em vez de virem da ARMA. Enquanto a
arma não existia como geometria conhecida, adivinhar era a única opção — e as
duas adivinhações ficaram no lugar depois que a Yoru passou a saber dizer onde
seu fio começa e acaba.

**Correção:** a arma diz. `YoruSword` expõe os nós `guarda` e `ponta`; o rastro
se pendura neles (`usar_lamina_no_rastro`), e o impacto nasce na BOLINHA que
encostou, não no nó da lâmina — que fica junto ao punho, e faria o clarão sair
do cabo. A bolinha viaja junto com o sinal (`bind`), porque sem ela o receptor
só sabe QUE encostou, não ONDE.

**Como detectar de novo:** efeito de arma calculado a partir de osso ou de
"tantos metros à frente" é palpite. Se a arma tem geometria, o efeito sai dela.

## 2026-09-06 — `current_scene` é nulo em script `-s`, e o efeito some sem avisar

**Sintoma:** o teste novo cobrou "o corte deixou um impacto na cena" e reprovou,
num código que funciona no jogo.

**Causa raiz:** `_faiscar` pendurava o efeito em `get_tree().current_scene`, que
é NULO num script rodado com `-s`. O `BaseTest` do projeto já registra a
armadilha com todas as letras: *"vários efeitos penduram nós em
`get_tree().current_scene`. Num script -s isso é nulo e o efeito some sem
avisar"*. Eu copiei o padrão de `_efeito_de_choque` sem lembrar do aviso.

**"Some sem avisar" é a parte ruim:** não há erro, não há warning — o efeito
simplesmente não acontece, e só um teste que o cobra revela.

**Correção:** `_palco_de_efeitos()` usa `current_scene` quando existe e cai para
a raiz da árvore quando não. Vale para o impacto do corte e para o choque de
espadas.


## 2026-09-06 — guardar a espada com `queue_free` deixava ela na mão pelo resto do quadro

**Sintoma:** o `test_modos_de_combate` acusou "sair do modo 3 não guardou a
Yoru" — mas o log da mesma execução dizia `[Yoru] guardada`. As duas coisas
eram verdade ao mesmo tempo.

**Causa raiz:** `sacar_ou_guardar_espada` zerava `_yoru` na hora e chamava
`queue_free()`, que só remove o nó no fim do quadro. Entre uma coisa e outra o
estado ficava partido: a variável dizia "sem espada" e a ÁRVORE ainda tinha uma
pendurada em `Hand_R`.

**Por que não é só um teste chato:** sacar de novo antes da varredura penduraria
uma SEGUNDA espada ao lado da que está morrendo — e o Godot a renomearia para
`Yoru2`, então `get_node_or_null("Yoru")` continuaria achando a morta. Trocar
1→3→1→3 rápido é exatamente o que se faz testando teclas novas.

**Correção:** `remove_child` antes do `queue_free`. O estado da mão passa a ser
verdadeiro no instante da troca.

**Como detectar de novo:** `queue_free` não é remoção, é agendamento. Quando um
nó representa ESTADO que outra coisa consulta no mesmo quadro (está na mão? está
equipado?), tire-o da árvore explicitamente — a variável e a árvore não podem
discordar nem por um quadro.


## 2026-09-06 — a Yoru crescia PARA TRÁS: os dois rigs têm o antebraço em eixos opostos

**Sintoma:** relato do dono — "yoru está no lado oposto ao qual deveria estar".

**Causa raiz:** o nó da mão nasce na ponta do antebraço, mas para lados opostos
do eixo Y local do osso conforme o tipo de personagem:

```gdscript
skinnado: item_handle.position = Vector3(0,  0.36, 0.0)   # fora da mão = +Y
voxel:    item_handle.position = Vector3(0, -0.36, 0.02)  # fora da mão = -Y
```

Tudo que é segurado cresce no PRÓPRIO +Y (a Yoru, e antes dela o `SwordPickup`,
cuja lâmina também subia em +Y a partir da mão). No personagem voxel — que é o
padrão do jogo — a arma crescia de volta pelo braço.

**Evidência:** medido no personagem real, o vetor mão→ponta da lâmina:

    antes:   frente -1,15 m   lado -0,55 m   (a ponta 1,15 m ATRÁS do jogador)
    depois:  frente +1,14 m   lado +0,63 m

**Correção:** `Hand_R` do rig voxel passa a nascer com `rotation.x = PI`. O
conserto mora no RIG, e não na espada, porque a diferença é do rig: resolvendo
na mão, qualquer item futuro nasce certo sem saber que os dois tipos existem.

**Como detectar de novo:** offset com sinal trocado entre dois ramos do mesmo
`if` é aviso de que os referenciais são diferentes, não de que um deles está
errado. Quem pendura coisa ali precisa da ORIENTAÇÃO, não só da posição.

## 2026-09-06 — golpe procedural sem clipe tinha duração ZERO, e saía 10x mais rápido

**Sintoma:** relato do dono — "o sistema de combate corpo a corpo por clique
ainda está em ação mesmo com a espada equipada, sendo que quem deveria estar em
efeito é a espada".

**Causa raiz:** os cortes de espada são PROCEDURAIS
(`WeaponPoses.two_handed_sword_slash`) e eu os declarei com `"anim": ""`. O
`Melee.duracao_tocada` começava por `clipe()`, que devolve `null` sem clipe, e
retornava **0.0** — antes mesmo de olhar o frame data. E o Player faz:

```gdscript
var speed = 1.0 / maxf(duracao, 0.1)     # 1.0 / 0.1 = 10x
```

O corte inteiro passava em 0,1 s: dois quadros. Em tela não aparecia espada
nenhuma e o que sobrava era a pose de repouso — indistinguível de "o combo de
punho continua no lugar da espada", que foi exatamente como o defeito chegou.

**Evidência:** sonda no jogo real, antes e depois:

    passo 0: duracao_tocada=0.000 s -> 10.0x     (frame data diz 0,490 s)
    passo 0: duracao_tocada=0.490 s ->  2.0x

**Correção:** quando não há clipe mas HÁ frame data, a duração é
`startup + ativo + recuperação`. E `clipe()` deixou de avisar "clipe ausente"
para `anim` vazio — golpe procedural não tem clipe, e isso é legítimo.

**Como detectar de novo:** um caminho que retorna 0.0 para "não sei" vira
divisão por um piso em algum lugar rio abaixo. O sintoma não é lentidão nem
erro: é uma animação rápida demais para ser vista, que lê como "não aconteceu".

## 2026-09-06 — o C da Pika travava o movimento por 3,7 s e soltar a tecla não devolvia o controle

**Sintoma:** relato do dono — "o personagem para de exibir animações após usar
o C".

**Causa raiz:** `YasakaniController` chamava `lock_movement(C_TOTAL, "C")`, ou
seja 3,7 s. E `Player.lock_movement` **não tem timer próprio** — o comentário
dele diz "ignora o timer (FSM cuida)", e só grava a meta `active_skill`. Soltar
o C encerrava a barragem mas não devolvia o movimento: o jogador largava a
tecla, ficava parado o resto do tempo sem animação de caminhada, e ainda por
cima caindo dos 7 m que o próprio C o teleportou para cima.

**⚠️ NÃO REPRODUZI HEADLESS, e está registrado assim de propósito.** Três sondas
(conclusão natural, segurar-e-soltar, e inspeção de estado) deram tudo limpo:
`custom_pose` vazio, `_charging` falso, FSM em `Idle`, ossos animando a 94,9%
do normal depois do golpe. A trava é a explicação mais provável do relato, não
uma causa confirmada em medição.

**Correção:** a trava passou a cobrir só o preparo (`C_RAJA_INICIO`, 1,0 s).
Dali em diante o jogador anda e mira enquanto desfere — que era a mecânica
pedida na mesma mensagem.

**Como detectar de novo:** `lock_movement` neste projeto NÃO é um temporizador;
é um rótulo. Quem tranca por N segundos precisa destrancar por conta própria, ou
trancar só pelo tempo que sabe cobrir.


## 2026-09-06 — o tipo do corte de espada era o ÍNDICE do passo, e funcionava por coincidência

**Sintoma:** nenhum — até o combo da espada mudar. Ao trocar os três passos
(corte D-E, corte E-D, vertical) pelo par pedido pelo dono (horizontal,
vertical), o segundo clique passaria a tocar o segundo corte **horizontal** e o
vertical nunca sairia.

**Causa raiz:** o Player pedia a pose assim:

```gdscript
_proc_anim.play_procedural_slash(passo, speed)   # `passo` é o ÍNDICE do combo
```

`play_procedural_slash(type, ...)` espera o TIPO da pose
(`WeaponPoses.two_handed_sword_slash`: 0 = horizontal D→E, 1 = horizontal E→D,
2 = vertical). Índice e tipo eram grandezas diferentes que por acaso tinham os
mesmos valores, porque o combo tinha três passos na mesma ordem dos três tipos.
Nada no código dizia que eram coisas distintas, e o acoplamento sobreviveu
justamente por nunca ter sido testado com outro tamanho de combo.

**Correção:** campo `slash_type` na tabela e acessor `Melee.slash_type(i)`. O
tipo passou a ser um dado do golpe; o índice voltou a ser só posição no combo.

**Como detectar de novo:** quando duas grandezas diferentes são passadas pela
mesma variável e "dá certo", o alinhamento é uma coincidência com prazo de
validade. Sinal típico: uma função recebe `i` do laço e o parâmetro dela se
chama outra coisa (`type`, `slot`, `id`).

**Vale notar que isto NÃO era um bug ainda** — era um bug esperando um requisito.
Só apareceu porque o combo mudou de tamanho.


## 2026-09-06 — o `test_frutas` não enxerga subclasse de `DamageZone`

**Sintoma:** depois de o C da Pika trocar 90 hitboxes de fragmento por um volume
único, a auditoria `test_frutas` reportou a fruta em **3/4 golpes com hitbox** —
num golpe que o `test_pika_c_area` prova, no mesmo dia, aplicar dano e paralisia
pelo funil normal.

**Causa raiz:** o reconhecimento de tipo do teste era por **caminho de arquivo**:

```gdscript
n.get_class() == tipo or n.get_script().resource_path.ends_with(tipo + ".gd")
```

O primeiro ramo nunca serve para script GDScript — `get_class()` devolve a
classe do ENGINE (`"Area3D"`), não o `class_name`. Então tudo depende do
segundo, que casa por ARQUIVO. Um nó de `ZonaBarragem extends DamageZone` tem o
`resource_path` do arquivo DELE (`PikaFXGrande.gd`), e simplesmente some da
conta. A hitbox existia; a sonda é que não alcançava.

**Por que ficou escondido até hoje:** `ZonaBarragem` é a **primeira** subclasse
de `DamageZone` do projeto (`grep -rn "extends DamageZone"` devolve uma linha
só). Enquanto todo mundo instanciava a classe base, a heurística por caminho
parecia correta.

**Correção:** `tipo == "DamageZone"` passa a usar `n is DamageZone`, que cobre a
hierarquia. Os outros tipos seguem no casamento por caminho — nenhum tem
subclasse hoje.

**Como detectar de novo:** em GDScript, `get_class()` NUNCA devolve o
`class_name`; comparar com ele dá falso silencioso. E casar `resource_path` por
arquivo é o mesmo bug esperando a primeira subclasse. Quando um teste pergunta
"é um X?", o operador é `is`.

**A tentação a evitar:** o atalho seria transformar a `ZonaBarragem` em
`DamageZone` pura para o teste voltar a vê-la — ou seja, deixar de herdar por
causa de uma sonda. Isso conserta o número e mantém o buraco armado para a
próxima subclasse.


## 2026-09-06 — nomear o nó ANTES do `add_child` sumiu com 90 fragmentos do teste

**Sintoma:** ao trocar o fragmento do C da Pika por um nó puramente visual, o
`test_pika_c_v` passou a acusar "1 fragmentos vivos" onde esperava pelo menos 3.
Uma sonda mostrou o absurdo: **39 rastros vivos e 1 fragmento** — os rastros são
criados um por fragmento, então os fragmentos existiam.

**Causa raiz:** eu inverti a ordem de duas linhas sem perceber que ela importa.

```gdscript
# antes (funcionava)        # depois (quebrou)
mundo.add_child(cabeca)     cabeca.name = "PikaFragmentoC"
cabeca.name = "PikaFragmentoC"   mundo.add_child(cabeca)
```

O Godot resolve colisão de nome entre irmãos de **duas formas diferentes**:

- nó que **já está na árvore** e recebe `name` colidindo → `PikaFragmentoC2`
- nó nomeado **antes** de entrar, colidindo no `add_child` → `@PikaFragmentoC@2`

O teste conta com `name.begins_with("PikaFragmentoC")`. O primeiro formato casa;
o segundo começa com `@` e não casa com nada. Os 90 fragmentos estavam lá, com
nome que ninguém procurava.

**Evidência:** sonda imprimindo os dois contadores lado a lado por 1,8 s —
`frag=1 rastro=39` em todos os quadros da barragem. Um fragmento (o primeiro,
que não colide com ninguém) mantinha o nome legível; os 89 seguintes não.

**Correção:** `add_child` primeiro, `name` depois — e um comentário na linha
dizendo que a ordem não é estilo.

**Como detectar de novo:** contagem por nome em Godot é frágil por natureza.
Quando um teste conta nós por `begins_with`, o código que os cria precisa nomear
DEPOIS de entrar na árvore. Sintoma típico: o contador trava em 1 (o único que
não colidiu) enquanto tudo o mais indica que os nós existem.


## 2026-09-06 — a varredura anti-túnel era um raio, e raio não tem espessura

**Sintoma:** projétil rápido da Pika Pika passava por dentro do adversário sem
acontecer nada. O jogador via a bola de luz atravessar o peito do outro e não
tinha como saber por que não contou.

**Causa raiz:** a `DamageZone` anda por teleporte (`global_position += vel *
delta`) e já tinha, desde 2026-08-12, uma varredura do caminho para não tunelar
— um `intersect_ray` do ponto anterior ao atual. O conserto de 2026-08-12
resolveu o caso do alvo **no eixo** e ninguém percebeu que só esse tinha sido
resolvido: raio é uma linha sem espessura, então entre dois quadros a hitbox
deixava de ser a esfera anunciada em `radius` e virava a **linha do centro**
dela. Quem passasse de raspão saía ileso. A hitbox de 0,32 m do Z valia 0,32 m
apenas no quadro em que a `Area3D` conseguisse ver a sobreposição.

**Evidência:** sonda em Godot 4.6.3, alvo-cápsula de raio 0,40 deslocado 0,45 m
do eixo, passo de 1,30 m (o do Z a 78 m/s):

    intersect_ray ....... PASSOU DIRETO
    cast_motion ......... acertou na fração 0,340 do passo

**Correção:** `src/effects/DamageZone.gd` — a varredura virou uma ESFERA
VARRIDA (`cast_motion` acha o instante do primeiro contato, `intersect_shape`
diz quem estava lá). Forma customizada continua no raio: a parede de tsunami da
Gura tem 12 m de profundidade justamente para não tunelar.

**A medição de custo quase levou à decisão errada.** A primeira medida deu
`cast_motion` 48× mais caro que `intersect_ray` e por pouco isso não virou
motivo para inventar uma aproximação com vários raios paralelos. O 48× era o
caso de **acerto**, que acontece uma vez na vida de cada projétil. No caso que
domina — voando no vazio — a diferença é 0,176 µs contra 0,105 µs, ou 21 µs por
quadro com 120 projéteis. Medir o caso raro e decidir por ele é o erro.

**Como detectar de novo:** hitbox de projétil só vale o raio anunciado se a
varredura tiver a MESMA forma do colisor. Varredura por raio num colisor
esférico é sempre uma hitbox menor do que a documentada.

## 2026-09-06 — o peso do acerto estava ligado num sinal que quase nunca saía

**Sintoma:** o Z da Pika acertava e o jogo não reagia — sem hitstop, sem tremor
de câmera, sem soco de FOV. A auditoria multimodal pontuou "feedback de
impacto" com **4/10**, o pior critério do golpe, e o código *tinha* os três.

**Causa raiz:** `PikaFX` ligava o peso em `cabeca.body_entered`. Esse sinal é da
`Area3D` e só nasce quando o motor de física vê a sobreposição naquele quadro.
Mas a 78 m/s quem detecta o acerto é quase sempre a varredura da própria
`DamageZone`, que chama `_on_body()` **direto** — e `_on_body()` não emite
`body_entered` nenhum. Havia dois caminhos de detecção e o peso só estava
pendurado em um deles, o menos usado.

**Evidência:** `DamageZone._varrer_caminho` chama `_on_body(corpo)`
diretamente; os sinais que `_on_body` emite são `collided_with_any`,
`antes_do_acerto` e `hit_landed` — `body_entered` não está entre eles.

**Correção:** passou para `hit_landed`, que sai nos dois caminhos e só para
corpo que recebe dano de verdade.

**Como detectar de novo:** quando uma classe tem detecção própria ALÉM do sinal
nativo do nó, todo consumidor precisa ouvir o sinal da classe, não o do nó. A
regra vale para qualquer coisa pendurada em `body_entered` de uma `DamageZone`.

## 2026-09-06 — gente e mapa na mesma camada: o X travava em quem devia atravessar

**Sintoma:** o Yata no Kagami (X) — a técnica de virar luz e cruzar o campo —
parava no meio do caminho quando passava perto de outro jogador.

**Causa raiz:** `_clampar` disparava um raio para achar parede à frente e
excluía **apenas o próprio caster**, com máscara cheia. Neste projeto os
personagens são `CharacterBody3D` na camada 1, a mesma do cenário — então
qualquer jogador no trajeto era lido como parede e a perna travava 1 m antes
dele. O golpe falhava exatamente na situação para a qual existe.

**Correção:** `PikaFX._corpos_a_ignorar()` exclui por RID todo mundo dos grupos
`player` e `enemy`. Gente não é parede.

**Como detectar de novo:** neste projeto não dá para separar personagem de
cenário por `collision_mask`. Quem precisa da distinção tem de excluir por RID,
via grupo — máscara não resolve.

## 2026-09-06 — o X podia largar o jogador em cima do buraco que mata

**Sintoma:** nenhum ainda — achado lendo o código durante o trabalho de
colisão, antes de alguém reclamar.

**Causa raiz:** a perna do ziguezague viaja em altura fixa (`_para.y = _de.y`) e
o único teste de colisão olhava para FRENTE (parede), nunca para BAIXO. A arena
tem 16 buracos quadrados e cair num deles mata (`Scoreboard.VOID_Y = -40`).
Dava para atravessar 21 m em linha reta e ser largado no ar sobre um buraco —
um botão de suicídio disfarçado de técnica de mobilidade.

**Correção:** `_com_chao()` recua o destino ao longo do próprio segmento até
achar chão, em 9 amostras.

**Como detectar de novo:** todo deslocamento que reposiciona o corpo por
`global_position` (em vez de `move_and_slide`) escapa da física inteira, não só
das paredes. Num mapa com vazio letal, "para onde vai" tem de incluir "tem chão
lá".

## 2026-09-06 — travar o golpe por falta de informação (erro meu, dentro da correção acima)

**Sintoma:** a primeira versão do `_com_chao` fez o X virar **no-op**: o
jogador apertava a tecla e não saía do lugar. O `test_pika_yasakani` acusou na
hora — lateral 0,0 m, avanço 0,0 m.

**Causa raiz:** quando nenhuma das 9 amostras achava chão, eu devolvia a origem
("não sei se é seguro, então não vai"). Mas as duas situações — "há um buraco
ali" e "não há colisor sob o segmento inteiro" — são informações diferentes, e
eu tratei as duas como perigo. No jogo isso quebra o X usado no AR, e na árvore
nua do teste (que não tem chão nenhum) quebrava tudo.

**Correção:** sem chão em amostra alguma = segue viagem. Só recua quando ACHOU
chão em algum ponto e o destino não tinha.

**Como detectar de novo:** sonda que não encontra nada está dizendo "não sei",
não "é perigoso". Interpretar ausência de dado como sinal negativo é o mesmo
erro de `if not resultado: assumir_o_pior()`.

## 2026-09-06 — o dublê do teste não sabia receber dano, e reprovou código certo

**Sintoma:** ao trocar o peso do acerto de `body_entered` para `hit_landed`, o
`test_pika_yasakani` passou a acusar "nenhum hitstop pedido ao acertar um corpo
do grupo 'enemy'" — num código que funciona no jogo.

**Causa raiz:** o alvo do teste era um `StaticBody3D` cru no grupo `enemy`, sem
`take_damage`. `hit_landed` só sai para corpo que recebe dano — e **todo corpo
atingível deste jogo tem `take_damage`**: Player, TrainingDummy, AutoDummy e
Enemy, os quatro. O dublê modelava algo que não existe, e enquanto o peso vinha
de `body_entered` (que não liga para isso) o defeito ficou escondido.

**Evidência:** `grep "func take_damage"` devolve os quatro tipos reais; nenhum
alvo do jogo é um corpo mudo.

**Correção:** o dublê virou `_AlvoFalso extends StaticBody3D` com
`take_damage`. Não foi "ajustar o teste para passar": foi tirar do teste uma
suposição que o jogo não sustenta.

**Perigo do atalho:** a saída fácil era voltar o sinal para `collided_with_any`,
que sai para qualquer corpo — e aí o teste passaria com o dublê irreal
**mantido**, deixando a mentira no lugar para a próxima pessoa.


## 2026-08-31 — quase apaguei 884 linhas do Codex com um `git checkout`

**Sintoma:** para saber se uma regressão era minha, revertí `Player.gd` e
`DamageZone.gd` com `git checkout --`. O `Player.gd` tinha **884 linhas não
commitadas** de outro agente (o `_girar_modelo` corrigido para a Gura Gura,
`FRUTA_INICIAL` mudada para `suke_suke`, e o combate contextual inteiro).

**Causa raiz:** tratei "reverter para comparar" como operação barata. Num
repositório onde outro agente trabalha e não commita, `git checkout --` é
destrutivo e silencioso: não avisa que está descartando trabalho, e o que
descarta não está em lugar nenhum. O arquivo tinha 884 linhas de diferença e eu
não olhei antes.

**Evidência:** `git diff --stat Player.gd` depois de restaurar: 884 linhas. O
trabalho só sobreviveu porque eu havia copiado os três arquivos para o
scratchpad antes — hábito, não decisão consciente de que havia algo a proteger.

**E a comparação ainda saiu errada:** revertendo o Player INTEIRO, eu não
testava "sem a minha mudança", e sim "sem a minha mudança E sem as 884 do
outro agente". O `test_melee_trava` passou, e eu quase conclui que a regressão
era minha. Refeito removendo **apenas** as minhas linhas, ele continuou
falhando — a mudança era do outro agente, e proposital.

**Correção:** para isolar uma mudança própria num arquivo compartilhado, tirar
só as próprias linhas (recorte pontual), nunca `git checkout` do arquivo.

**Como detectar de novo:** antes de qualquer `git checkout --`, rodar
`git diff --stat` no alvo. Se houver mais linhas do que as que eu escrevi,
alguém mais mexeu ali.

## 2026-08-29 — a asa não aponta para um lado: ela sobe E cai ao mesmo tempo

**Sintoma:** depois de pôr as asas "na vertical" a pedido do dono, ele mandou
outro print: a PONTA estava para cima e devia estar para baixo. Uma folha nova
(`lunarian 2`) mostrou por quê.

**Causa raiz:** a asa era tratada como uma peça RÍGIDA que aponta para alguma
direção, e toda a conversa girou em torno de "para cima ou para baixo?" — a
pergunta errada. Na folha ela faz as duas coisas ao mesmo tempo: o arco do dorso
SOBE do ombro até acima da cabeça, e as penas longas CAEM desse arco até a
altura do quadril. Perseguir um ângulo só nunca ia chegar lá, e cada ajuste
trocava um erro pelo outro — "vertical" me deu a ponta para cima, que era
exatamente o que ele não queria.

**Evidência:** a métrica antiga era um número — o ângulo da ponta — e por isso
não conseguia sequer EXPRIMIR a forma certa. Com duas medidas, o repouso passou
a ler topo do arco +0,69 (acima do ombro) e ponta das penas −0,90 (abaixo), que
é a silhueta da folha.

**Correção:** `src/customizacao/AsaLunar.gd` — a geometria virou um ARCO com
penas penduradas nele (`sin(t·π·0,72)` põe o pico a dois terços da envergadura,
onde fica a "mão" da asa), em duas camadas. As poses viraram desvios a partir de
uma forma que já está certa parada, em vez de tentativas de apontar a asa.

**Como detectar de novo:** `medir_visual_no_jogo` afere TOPO e PONTA
separadamente. Se a asserção voltar a ser um número só, ela volta a aprovar uma
asa que aponta toda para o mesmo lado.

**Padrão a levar adiante:** quando ajustes sucessivos trocam um defeito por
outro sem convergir, o problema costuma ser a métrica, não o valor. Uma forma
que precisa de duas medidas não cabe numa asserção de uma.

## 2026-08-29 — nenhum valor de inclinação punha a asa na vertical

**Sintoma:** o dono mandou um print e pediu as asas na vertical. Aumentar a
inclinação não resolvia: passava de um ponto e a asa PIORAVA.

**Causa raiz:** as penas crescem para TRÁS (+Z local, que é o comprimento
delas), e a inclinação gira em Z — o eixo que levanta a ENVERGADURA, não o
comprimento. Com a ponta a ~0,74 de recuo, o ângulo vertical tem um teto
geométrico: nenhum valor de inclinação a leva acima dele, porque o problema não
estava nela.

**Evidência:** varredura do ângulo real da ponta contra a inclinação escrita —
1,02 rad → +38,5°; 1,32 → +48,3°; **1,60 → +53,3° (o pico)**; 1,90 → +52,4°;
2,20 → +45,4°; 2,50 → +32,8°. A curva sobe, satura e desce.

**Descartado:** *o leque das penas*. Era a suspeita, e a inclinação em leque
(`-t * 0.30`, que apontava a ponta para baixo) foi reduzida — o pico subiu de
+53,1° para apenas +53,5°. A medição matou a hipótese em uma execução.

**Correção:** `src/customizacao/AsaLunar.gd` — um terceiro eixo, `pitch`, que
gira em X e é justamente o que leva +Z para +Y, levantando o COMPRIMENTO da
asa. Varredura 2-D de pitch × inclinação achou o par: `pitch −0,60` com
`inclinacao 1,70` dá +87,5°, com a ponta acima do ombro e quase sem
espalhamento lateral.

**Erro no meio da correção:** `_angulos_da_asa` continuou setando só dois eixos
depois que o terceiro entrou, e media a asa com o `pitch` do estado ANTERIOR —
"pulando" deu −13,7° em vez de −64,2° e reprovou uma pose correta. Pose
incompleta mede outra pose.

**Como detectar de novo:** quando aumentar um parâmetro parar de melhorar e
começar a piorar, o eixo está errado — varrer o parâmetro e olhar a curva custa
uma execução e mostra o teto na hora.

## 2026-08-29 — testei o parâmetro que escrevi, não o ângulo que saía

**Sintoma:** o dono olhou o print e disse "a asa está na horizontal", com a
asserção "a asa de repouso não é horizontal" passando verde.

**Causa raiz:** a asserção era `POSE["repouso"]["inclinacao"] > 0.35` — o
PARÂMETRO DE ENTRADA, não o resultado. E os dois não coincidem: as penas descem
ao longo da envergadura (`queda` mais o rebaixamento por `t`), e essa geometria
come cerca de 17° da elevação. Com 0,52 rad escritos (30°) a ponta da asa subia
+12,3°, que é horizontal a olho — exatamente o que ele viu. O teste confirmava
que eu tinha digitado 0,52; nunca perguntou onde a asa foi parar.

**Evidência:** ângulo vertical da ponta, medido: repouso +12,3°, andando +2,0°,
correndo −9,1°. Depois de calibrar CONTRA a medição: +38,7°, +13,1°, +4,9°, com
pulando em −45,5° e caindo em +48,4°.

**Segundo erro, no meio da correção:** a primeira medição do ângulo foi feita em
espaço GLOBAL, e a mesma pose deu +38,7° no boneco do menu e −40,3° no do jogo —
a rotação e a escala do modelo do jogador entravam na conta. "Para cima" e "para
trás" são do PERSONAGEM: o referencial certo é o pai da asa, e a medição passou
a ser `a.transform * ponta.position - a.position`.

**Correção:** `src/customizacao/AsaLunar.gd` — as cinco poses recalibradas
contra o ângulo medido, e a queda interna das penas reduzida (era ela que roubava
a elevação). `tools/dev_tests/medir_visual_no_jogo.gd` — `_angulos_da_asa` mede a
PONTA no espaço do ombro e afere os cinco casos do pedido.

**Como detectar de novo:** asserção sobre aparência tem de medir o que aparece.
Se o teste lê uma constante do próprio catálogo, ele só confirma que o número
foi digitado — e passa verde com a tela errada.

**Padrão a levar adiante:** quando o usuário e o teste discordam sobre o que está
na tela, o teste está medindo a coisa errada. É a terceira vez nesta sessão
(antes: a camada de material errada, e o eixo da própria rotação).

## 2026-08-29 — não dá para simular "andando" escrevendo em `velocity`

**Sintoma:** a asserção "andando no chão -> andando" reprovou. A sonda escrevia
`p.velocity = Vector3(6, 0, 0)` e lia o estado da asa quatro quadros depois:
vinha `repouso`, com velocidade plana 0,00.

**Causa raiz:** o `Player` RECALCULA a velocidade todo quadro de física a partir
do input (`MoveFrame.ler` → `_etapa_locomocao`). Escrever nela de fora dura
menos de um quadro — sem tecla pressionada, o próximo passo zera. A leitura do
estado estava certa; a SIMULAÇÃO é que não se sustentava.

**Descartado:** *injetar a tecla*. Foi a tentativa seguinte, e também não serviu:
medido, `velocidade plana 0,00` mesmo segurando W nesta sonda — `MoveFrame.ler`
depende de mouse capturado e menu fechado, e neste contexto o input não chega.

**Correção:** a regra virou função PURA — `AsaLunar.estado_de(no_chao, vel,
correndo)` — e `estado()` ficou só com a leitura dos três valores do corpo.
Assim os cinco estados são verificáveis sem mundo nenhum (incluindo "saltou
correndo → pulando, não correndo"), e o que ainda depende do corpo é testado no
que dá para provocar de verdade: o ar, onde a velocidade vertical persiste.

**Como detectar de novo:** se uma asserção sobre movimento só passa quando o
personagem se move, e o personagem não se move na sonda, o problema é o
acoplamento do teste ao mundo. Separar a regra da leitura resolve, e de quebra
permite testar os casos que o mundo não produz sob demanda.

**Padrão a levar adiante:** estado derivado de física é caro de provocar e
barato de calcular. Quando a decisão couber numa função de argumentos simples,
ela deve morar lá — não porque fica "mais limpo", mas porque passa a ser
testável nos casos que importam em vez de nos que o ambiente permite.

## 2026-08-29 — a chama parecia mal posicionada, e o UV é que estava invertido

**Sintoma:** a chama 2D das costas do Lunariano aparecia só ACIMA da cabeça,
como uma tocha boiando no ar, em vez de subir pelas costas. Ajustei a âncora
duas vezes achando que era posição.

**Causa raiz:** o `QuadMesh` do Godot tem o UV com **Y invertido** — `UV.y = 0`
é o TOPO do plano, não a base. A máscara de altura do shader
(`1.0 - smoothstep(0.15, 1.0, uv.y)`) foi escrita supondo o contrário, então
desenhava o fogo forte em cima e fraco embaixo: o oposto do pretendido. A chama
sempre esteve no lugar certo; o que estava errado era o DESENHO dentro dela.

**Evidência:** medida a posição em vez de olhada — a chama ia de y=1,73 a 2,98
no espaço do modelo, com a cabeça em 2,70. Ou seja, cobria as costas inteiras
desde antes de eu mexer em qualquer âncora. Depois de inverter o UV, o fogo
apareceu na base, no lugar em que já estava.

**Descartado:** *posição da âncora* e *oclusão pelo corpo* — as duas suspeitas
naturais, e as duas mortas pela mesma medição.

**Correção:** `src/fx/shaders/chama_lunar.gdshader` — `vec2 uv = vec2(UV.x, 1.0
- UV.y)` logo no começo do `fragment`.

**Como detectar de novo:** quando um efeito parecer estar no lugar errado,
imprimir a posição GLOBAL dele e a do corpo antes de mover qualquer coisa. Dois
ajustes de âncora foram gastos por não fazer isso primeiro.

---

## 2026-08-29 — medi o eixo da rotação e disse que a asa não se mexia

**Sintoma:** a asserção "a asa BATE de verdade" reprovou com variação exata de
`0.0000`, num batimento que estava funcionando.

**Causa raiz:** o teste comparava `basis.z` antes e depois, e o batimento é uma
rotação EM TORNO de Z — o eixo de uma rotação é justamente a coluna que ela não
mexe. Medi o único dos três eixos que não podia mudar.

**Evidência:** `_process` rodando (`_t = 0.3228` depois de 40 quadros) com
`basis.z` imóvel. Comparando as três colunas: variação 0,0842.

**Correção:** `tools/dev_tests/medir_visual_no_jogo.gd` soma a diferença das
três colunas da base, o que é robusto a qual eixo gira.

**Como detectar de novo:** ao medir rotação, nunca olhar uma coluna só — ou
saber qual é o eixo e olhar outra. É o terceiro caso desta sessão em que a sonda
reprovou algo que funcionava por estar olhando o lugar errado (os outros: a
coluna central da tela que cruzava o personagem, e o `surface_override_material`
enquanto o bug morava no `material_override`).

## 2026-08-29 — o menu apagava a cor da raça um quadro depois de pintá-la

**Sintoma:** achado ao conferir as raças novas: escolher Oni no menu pintava o
corpo de vermelho e a cor sumia em seguida. A raça continuava aplicada — as
peças estavam lá —, mas o corpo voltava ao cinza.

**Causa raiz:** a ação do botão de raça terminava com um `_pintar()`, sobra de
quando a TELA era dona da cor. Essa função lia `_cor_idx`, campo do menu que
deixou de ser escrito quando o estado migrou para o `Visual` e ficou preso em
−1 — e `-1` significa "original", cujo efeito é `material_override = null` em
todas as malhas. A sequência era: `Visual.aplicar` pinta de vermelho, a linha
seguinte apaga.

**Evidência:** clicando o botão "Oni" pelo caminho real, o corpo lia
`(0, 0, 0, 0)` (sem material) em vez de `(0.70, 0.16, 0.14)`. Depois de remover
a chamada: `(0.70, 0.16, 0.14)`.

**Por que dois testes deixaram passar:** ambos chamavam `Racas.aplicar` e
`Visual.aplicar` DIRETO. O defeito não estava em nenhuma das duas — estava no
que a tela fazia depois delas. Um teste que exercita só as funções nunca vê uma
regressão que mora no chamador.

**Correção:** `src/ui/CustomizacaoMenu.gd` — a chamada saiu, e a função
`_pintar` e os campos `_cor_idx`/`_cor_grupo` foram removidos por inteiro: eram
uma segunda fonte de verdade sobre a cor, que discordava da primeira. Quem pinta
é `Visual.pintar`, a mesma função que a partida usa.

**Como detectar de novo:** `medir_customizacao.gd` agora CLICA no botão "Oni"
(`_clicar`, que emite o `gui_input` como o jogador faria) e confere a cor
depois. É o único jeito de cobrir o que a tela faz além de chamar a função.

**Padrão a levar adiante:** ao mover um estado de um lugar para outro, o perigo
não é o código novo — é o código velho que continua lendo o campo antigo. Ele
compila, roda, e opera sobre um valor que ninguém mais atualiza.

## 2026-08-29 — test_segurar_ataque é INTERMITENTE (aberto, não é regressão)

**Sintoma:** `./validar.sh rapido` reprovou `test_segurar_ataque` com "o controle
não andou: a tecla não chegou. Medição inválida." numa execução em que só a arte
de fundo do menu de Customização tinha mudado — código que esse teste nem toca.

**Causa raiz:** não é o jogo: é o próprio teste se recusando a medir. Ele precisa
de TELA e injeta teclas por `Input.parse_input_event` numa janela real; quando a
tecla não é registrada a tempo, ele aborta de propósito em vez de reportar um
número falso — o que é a decisão certa dele. A fragilidade está na injeção, não
na mecânica testada.

**Evidência:** duas execuções seguidas do MESMO commit, sem nenhuma alteração
entre elas: a primeira saiu com código 1 e a segunda com 0. A suíte completa,
rodada de novo, deu 35 de pé e 0 falhas.

**Descartado:** *regressão da arte de fundo*. A mudança foi um `TextureRect` e a
transparência do SubViewport dentro do `CustomizacaoMenu`; `test_segurar_ataque`
não abre esse menu.

**Correção:** nenhuma ainda — fica registrado como flakiness conhecida. O
conserto de verdade é o teste esperar a tecla ser vista (condição) em vez de
contar quadros, que é o mesmo padrão de duas asserções instáveis já corrigidas
em 2026-08-27.

**Como detectar de novo:** ao ver essa mensagem, rodar o teste isolado duas
vezes. Se uma passa e outra não, é isto — e não a mudança que estava em curso.

## 2026-08-29 — ao entrar no jogo tudo virava azul (corpo E acessórios)

**Sintoma:** relato do dono — "bug encontrado na cor: ao logar a cor se torna
automaticamente azul, tanto do acessório quanto do jogador". A customização
aparecia certa por um instante e era substituída.

**Causa raiz:** são DUAS coisas no mesmo ponto, e as duas em `_tingir_modelo`.

1. *Por que azul:* no spawn o `Main` dá a cada peer uma cor da paleta
   (`Main.gd:237`) e o peer 1 — o único que existe no singleplayer — recebe a
   PRIMEIRA, que é azul. A chamada é `call_deferred` (`Main.gd:278`), ou seja
   roda DEPOIS de o rig estar montado e a customização aplicada, e pinta por
   cima. Sozinho no mundo não há quem distinguir: a cor de time não resolvia
   nada ali e só apagava a escolha do jogador.

2. *Por que o acessório junto:* `_tingir_modelo` varre TODAS as malhas do
   modelo, sem distinguir corpo de guarda-roupa. Pior, ele pinta por
   `material_override`, que no Godot VENCE o `surface_override_material` com que
   os acessórios são pintados — a cor original continuava intacta na camada de
   baixo, invisível.

**Evidência:** com a customização montada (pele, cabelo loiro, cartola), depois
de `aplicar_cor_do_jogador(0)` os três liam `(0.16, 0.42, 0.95)` — o azul da
paleta. Depois da correção: corpo `(0.94, 0.78, 0.63)`, cabelo `(0.9, 0.75,
0.32)`, cartola `(0.29, 0.29, 0.33)`.

**O código já sabia, e tinha deixado passar:** a nota de `_tingir_modelo`
registrava que uma arma da Buki na mão saía tingida junto e concluía que "não
vale complicar por isso enquanto for só cosmético". Era verdade enquanto a arma
voltava ao normal no saque seguinte; deixou de ser quando a Customização passou
a pendurar peças permanentes no mesmo modelo.

**Correção:** `Player._tingir_modelo` pula o que for adorno (`Visual.e_adorno`),
e desiste da pintura quando o jogador escolheu uma cor E não há outros peers —
em partida com gente a cor de time continua mandando, porque ali ela diz quem é
quem, e isso vale mais que a preferência estética.

**Erro meu, e o que ele ensina:** minha primeira medição disse que o acessório
NÃO tinha virado azul — duas asserções passaram enquanto o bug relatado estava
na tela. A sonda lia `surface_override_material` e o bug morava em
`material_override`, a camada que vence. Foi ler a camada errada, exatamente
como já tinha acontecido ao medir a coluna central da tela que cruzava o
personagem. Quando o relato do dono e a minha medição discordam, a suspeita
começa pela medição.

**Como detectar de novo:** `medir_visual_no_jogo.gd`, seções 6 e 7. A 7 é o
CONTROLE: sem ela, "consertar" o bug matando a cor de time passaria no teste e
quebraria a identificação de jogadores no PvP.

## 2026-08-29 — estado persistido contamina teste que não o zera

**Sintoma:** depois de ligar a customização ao mundo, o `medir_customizacao`
passou a reprovar quatro asserções que nada tinham a ver com a mudança —
"cenário montado: dois acessórios na cabeça", "equipar na MESMA parte não
empilha", "as quatro convivem no mesmo nó" e "começa sem olhos". O código
testado estava correto.

**Causa raiz:** o menu passou a chamar `Visual.carregar_uma_vez()` ao abrir, e
uma execução anterior — do `medir_visual_no_jogo`, que salva de propósito, ou do
jogo de verdade — tinha deixado um personagem montado em `user://visual.cfg`. O
boneco da prévia nascia com cabelo, boca, cartola e máscara, e toda contagem do
teste mudava. As asserções contavam acessórios sem controlar quantos já havia.

**Evidência:** 101 conferem / 5 divergem com o arquivo salvo; 107 / 0 depois de
zerar `Visual` no começo da sonda. Nenhuma linha do código de produção mudou
entre as duas execuções.

**Correção:** `tools/dev_tests/medir_customizacao.gd` zera o estado e marca
`Visual._carregado = true` antes de montar o menu, impedindo a releitura do
disco. A quinta falha era diferente e legítima: "há quatro categorias" virou
cinco, porque `cabelo` ganhou categoria própria.

**Como detectar de novo:** rodar a sonda duas vezes seguidas. Se a segunda
execução divergir da primeira, ela está lendo o que a primeira deixou no disco.

**Padrão a levar adiante:** no instante em que um sistema ganha persistência,
todo teste que o toca herda uma dependência invisível de execuções passadas — e
falha contando coisas que ninguém equipou naquela execução. O teste precisa
zerar o estado, não presumir que ele começa vazio.

## 2026-08-29 — o menu e a partida não usam a mesma cabeça, e o acessório não sabia disso

**Sintoma:** o chapéu de palha aparece esticado para trás na prévia do menu de
Customização, atravessando a nuca — e coroa, cartola e máscara da peste, recém
modeladas, saíam com o mesmo alongamento. No jogo, as mesmas peças assentam
certo.

**Causa raiz:** são DOIS modelos de personagem com cabeças diferentes. O menu
monta por `CharacterBuilder.build_character("base")`, cujo `Head` tem AABB
`tam(0,500, 0,500, 0,400)`; a partida monta pelo rig, cujo `Head` tem
`tam(0,500, 0,500, 0,740)` — quase o dobro da profundidade. O acessório é um
`.glb` de tamanho ABSOLUTO: a âncora sempre foi fração da caixa e se adaptava,
mas o tamanho não. Modelado para uma cabeça, sobra na outra.

**Evidência:** a divergência estava escrita no próprio repositório, em duas
tabelas que ninguém tinha comparado — `tools/blender/acessorios.py` documenta
`Head tam(0.500, 0.500, 0.400)` e `tools/blender/chapeu_palha.py` documenta
`tamanho (0,500, 0,500, 0,740)`. Cada uma foi medida num modelo diferente, e as
duas estavam certas sobre o modelo que mediram. Confirmado em runtime: o `Head`
do player é um `MeshInstance3D` com malha própria de 0,740 de profundidade, sem
filhos que pudessem inflar a união de AABBs.

**Descartado:** *escala do rig*. Era a suspeita imediata, e o próprio
`CustomizacaoMenu` tem uma nota dizendo que o modelo do `CharacterBuilder` vem
no tamanho nativo, "sem a escala que o rig aplica em partida". Mas escala
uniforme não muda proporção, e aqui largura e altura batem (0,500 nas duas) e só
a profundidade diverge — é geometria diferente, não escala.

**Correção:** `src/customizacao/Acessorios.gd` — a peça declara no catálogo a
caixa `ref` para a qual foi modelada, e `equipar()` aplica
`scale = caixa_real / ref`. Não-uniforme de propósito: o que muda entre as duas
cabeças é só a profundidade, e é só nela que a peça deve encolher. Declarado nas
seis peças novas e no chapéu de palha, que tinha o defeito desde que nasceu.

**Alcance não corrigido:** as outras cinco peças de `acessorios.py` (chinelo,
capa da marinha, colete, calção, espadas) foram modeladas pela tabela do MENU e
têm o mesmo descompasso ao contrário — a tabela do Torso também diverge (0,360
documentado contra 0,666 medido no rig). Ficaram sem `ref` porque estão fora do
que o dono pediu; a correção é uma linha por peça quando ele quiser.

**Como detectar de novo:** `medir_customizacao.gd` imprime a caixa do `Head` do
menu e afere posição em FRAÇÃO da caixa, não em metros — uma asserção em metros
passa num modelo e reprova no outro sem que a peça tenha nada de errado.

## 2026-08-28 — na parede o WASD girava 90°, porque a frente da câmera é horizontal

**Sintoma:** relato do dono — "as teclas A W S D na parede ficam invertidas: o W
e o S passam a ir para os lados e o A e o D para cima e para baixo. Ocorre
quando o jogador pula tendo como origem alguma parte próxima à lateral do
bloco."

**Causa raiz:** `_atualizar_base_da_superficie` montava a base do movimento com
`Basis.looking_at(proj, n)`, onde `proj` era a frente da CÂMERA projetada no
plano da parede. Só que `q.frente` vem de `RosaDosVentos.base_do_corpo(yaw)` —
a base do pivô **só com yaw, sem pitch**, de propósito, para o dash ser sempre
horizontal (`MoveFrame.ler`). Ou seja, `q.frente` é horizontal por construção, e
projetar um vetor horizontal no plano de uma parede a prumo devolve sempre a
tangente horizontal, nunca "subir". O eixo do W virava o lado e o do A/D virava
a vertical — 90° de rotação, exatamente o relato.

**Evidência:** `tools/dev_tests/medir_teclas_parede.gd`, deslocamento decomposto
nos dois eixos do plano da parede:

    câmera de frente ....... W subida +1,53 | lado +0,00   ✅
    câmera a 45 graus ...... W subida +0,07 | lado −1,45   ❌
    câmera ao longo ........ W subida +0,08 | lado −1,53   ❌
    câmera a 45 (outro lado) W subida +0,08 | lado +1,53   ❌

12 erros em 16 medições. Depois da correção: 16/16, com `lado +0,00` — sem
contaminação em nenhum ângulo.

**O que o caso "perto da lateral" tem de especial:** nada, no fim. Ele é só a
postura em que o jogador chega olhando ao LONGO da face em vez de encará-la. A
medição mostrou que o bug valia para todo ângulo menos um, e não para uma
geometria específica — o relato descrevia a situação em que ele é fácil de
provocar, não a condição que o causa.

**A inversão que explica tudo:** o único ângulo que funcionava era a câmera de
frente para a parede, e funcionava porque ali a projeção DEGENERA e o código
caía no fallback "para cima da parede". O caminho principal produzia o bug e o
caminho de exceção produzia o acerto — por isso a mecânica parecia funcionar
quando testada de frente, que é como se testa naturalmente.

**Descartado:** *degeneração numérica / histerese*. Era a suspeita natural, por
causa do bug intermitente de 2026-08-27 no mesmo arquivo (base por projeção
invertendo com 5° de mouse). Mas o erro aqui é de 90° exatos, estável e
reprodutível em todo ângulo — não é ruído perto do limiar, é o eixo errado.

**Correção:** `src/player/parkour_controller.gd` — a base agora se decide pela
GEOMETRIA da superfície, não pela câmera: em superfície vertical
(`LIMIAR_VERTICAL = 0.7`, ou seja mais de 45° de inclinação) a frente é o UP do
mundo projetado, "subir", e a câmera não entra na conta; em superfície
horizontal (topo, teto) segue a frente da câmera, que é o controle de chão de
sempre, com a histerese que já existia. A direita não é escolhida: com frente e
normal fixas ela sai da geometria, e sai concordando com a tela.

**Como detectar de novo:** `medir_teclas_parede.gd` mede o eixo dominante de
cada tecla em quatro ângulos de câmera. Se o dominante do W mudar conforme o
yaw, a base voltou a depender da câmera.

## 2026-08-28 — a cópia do dono regenera 10x mais rápido do que deveria (ABERTO)

**Sintoma:** na tela do próprio jogador a barra de vida sobe mais rápido do que
o servidor está curando. Medido: logo após um golpe, o servidor tinha 1920,0 e
a cópia do cliente marcava 1930,2 — 10,2 hp de vida que o servidor não deu, em
cerca de 1 s.

**Causa raiz:** a penalidade de combate (`PENALIDADE_DANO = 0.10`, que derruba a
regeneração de 10,24 hp/s para 1,02 hp/s nos 5 s seguintes a um dano) depende de
`_t_ultimo_dano`, e esse campo só é escrito por `HealthController.sofrer_dano()`
— que roda **no servidor**. Na cópia do dono a vida chega por
`net_vida_do_servidor` (Player.gd:1744), que escreve `_vida.vida` direto e não
toca em `_t_ultimo_dano`. Ou seja: a cópia que o jogador enxerga não sabe que
acabou de apanhar, sai da penalidade e regenera a taxa cheia. Como o corpo do
dono tem autoridade no processo dele, o `_physics_process` roda e a regen local
acontece de verdade.

**Evidência:** `net_dano_client_probe.gd`, item D. O corpo do host visto pelo
cliente — cópia remota, que não regenera ali — bate exato (1792,0 = 1792,0), e
só o corpo do próprio cliente deriva. A assimetria entre os dois números na
mesma leitura é o que aponta a regen local como causa, e não perda de pacote.

**Descartado:** *atraso de rede*. O RPC é `reliable` e a vida do host, medida na
mesma leitura, chega exata; se fosse transporte, os dois números erravam juntos.

**Alcance:** é divergência de APRESENTAÇÃO, não vantagem de jogo — a vida do
servidor continua sendo a verdadeira e sobrescreve no dano seguinte. O jogador
vê uma barra otimista entre um golpe e outro.

**Correção:** ainda não aplicada (o pedido era o teste). O conserto natural é
`net_vida_do_servidor` marcar o combate na cópia local quando `dano > 0` — o
mesmo instante em que já chama `_feedback_de_dano`.

**Como detectar de novo:** `net_dano_probe` no `validar.sh`, item D do relatório
do cliente. Ele imprime a deriva sempre; se um dia aparecer perto de zero, o
comportamento mudou e o item A pode voltar a ler a vida tardia em vez do degrau.

## 2026-08-28 — teto absoluto num sinal cuja escala eu mesmo mudei

**Sintoma:** ao desacelerar a marcha (pedido do usuário: animação mais lenta sem
mexer no deslocamento), `test_walk_run` passou a reprovar `base / WALK` com
"não achei período — a marcha não está ciclando". A animação estava ciclando
normalmente na tela.

**Causa raiz:** `_periodo()` julgava a qualidade do casamento da série com
tolerâncias **absolutas em radianos** (0,004 para "fecha bem" e 0,02 para
"aceita"), calibradas quando a coxa oscilava 87°. A desaceleração veio de baixar
o quadril (`H_CORRIDA` 0.80→0.70, `H_SPRINT` 0.76→0.66), o que **aumenta a
amplitude** da coxa para 112° — a perna precisa abrir mais para cobrir a mesma
passada com o quadril mais baixo. O resíduo do casamento escala junto com o
sinal, estourou 0,02, e o teste reprovou uma marcha correta. A propriedade que o
teste quer verificar ("a série se repete") é de **forma**, não de escala; o teto
não podia ser fixo.

**Evidência:** amplitude da coxa 87° → 112° (1,29×) exatamente quando a falha
apareceu; as outras três marchas, com amplitude ~103°, passaram raspando. Com o
teto proporcional (0,0132 × amplitude, a mesma fração que 0,02/1,518 rad
representava antes), as quatro passam mantendo o rigor relativo original.

**Descartado:** *falta de amostra*. A primeira hipótese foi que o ciclo mais
longo (33,4 quadros) não cabia na janela de 90 quadros; alonguei para 180 e a
falha **continuou idêntica** — o que matou a hipótese antes de eu mexer em
qualquer constante do jogo.

**Correção:** `tools/dev_tests/test_walk_run.gd:263` — `_periodo()` calcula
`_amplitude(s)` e deriva `fecha`/`aceita` como fração dela; o teto do erro de
loop virou `0,033 × amplitude`.

**Como detectar de novo:** sabotagem — `CADENCIA_ESCALA := 0.0` em
`src/anim/ProceduralAnimator.gd` faz o teste voltar a imprimir "não achei
período". Se não imprimir, o teto foi afrouxado demais e o teste está cego.

**Padrão a levar adiante:** quando eu mudo uma constante que altera a **escala**
de um sinal, todo limiar absoluto medido sobre esse sinal vira suspeito. O teste
não estava errado antes — ele estava amarrado a uma escala que deixou de valer.

---

## 2026-08-28 — detector de período só testava atrasos inteiros num ciclo fracionário

**Sintoma:** mesmo depois de passar, `base / WALK` fechava o loop com erro 0,0561
contra um teto de 0,0645 (87% do teto), enquanto as outras três marchas — de
qualidade idêntica — ficavam entre 0,0001 e 0,0062, duas ordens de grandeza
abaixo. Uma assertion prestes a piscar no próximo ajuste de constante.

**Causa raiz:** `_periodo()` só avaliava atrasos **inteiros** em quadros, mas o
ciclo real é fracionário (33,4 quadros). Nenhum atraso inteiro fecha nele: o
resíduo que sobrava não media a qualidade da marcha, media **o quanto um múltiplo
do ciclo por acaso caiu perto de um inteiro**. O próprio comentário do teste já
descrevia o fenômeno ("o ciclo real é fracionário e nenhum atraso inteiro fecha
nele") mas o tratava como limitação aceita em vez de defeito de medição.

**Evidência:** com amostragem sub-quadro o erro de `base / WALK` caiu de 0,0561
para 0,0155 (24% do teto) **sem nenhuma mudança na animação**. O atraso refinado
deu 66,80 quadros = 2 × 33,4, batendo com o ciclo medido de forma independente
por `_ciclo()` (cruzamentos de média) — duas medições por métodos diferentes
concordando.

**Correção:** `tools/dev_tests/test_walk_run.gd` — `_erro_no_atraso()` amostra a
série em atraso fracionário por interpolação linear, e `_refinar_atraso()` varre
±0,5 quadro em passos de 0,05 em torno do melhor atraso inteiro.

**Como detectar de novo:** se o erro de loop de uma marcha ficar acima de ~50% do
teto enquanto as demais ficam abaixo de 10%, é desalinhamento de amostragem, não
animação ruim — compare o atraso impresso com o `ciclo N frames` da mesma linha:
ele tem que ser um múltiplo inteiro dele.

## 2026-08-25 — o transformador que consertava 28 sítios quebrou 6 e esvaziou 3 blocos

**Sintoma:** depois de rodar um script que converteu "emissão → albedo HDR" em
16 arquivos, o projeto passou de 3 para **6 scripts sem compilar**, com erros
que não pareciam ter relação: `Cannot infer the type of "arma" variable`,
`... "papel" ...`, `... "tw" ...` — em arquivos que o script nem tocou.

**Causa raiz:** duas, as duas do script:

**1. Escopo por ARQUIVO em vez de por FUNÇÃO.** Ele colhia os nomes de variável
marcados como unshaded no arquivo inteiro. No `WaterFX.gd` há duas funções que
chamam o material de `m`:

```gdscript
static func _mat_agua(...):   # SOMBREADO
    var m := StandardMaterial3D.new()
static func _mat_luz(...):    # unshaded
    var m := StandardMaterial3D.new()
    m.shading_mode = ...UNSHADED
```

O `m` de `_mat_luz` marcou o nome, e o `m` de `_mat_agua` foi convertido junto.
Em material **sombreado a emissão FUNCIONA** — apagar ali não era conserto, era
regressão. Aconteceu em 6 sítios (`BukiFX`, `BukiProjeteis`, `FireFX` ×3,
`WaterFX`).

**2. Bloco esvaziado.** As três linhas de emissão às vezes são o corpo inteiro
de um `if energia > 0.0:`. Apagá-las deixa

```gdscript
	if energia > 0.0:
	return m
```

que é erro de sintaxe — e derruba **todo script que dependa daquele**, que é o
motivo de os erros aparecerem em arquivos não tocados. Aconteceu em 3 blocos.

**Correção:** os 6 sítios sombreados foram revertidos — em material SOMBREADO a
emissão funciona, apagar ali era regressão — e os 3 blocos esvaziados, refeitos à
mão. A contagem real de sítios a converter era **28**, não 32.

**Como detectar:** transformação em massa precisa de auditoria pós-fato, não só
de revisão do diff. As duas que usei:
- procurar linha terminada em `:` seguida de linha com indentação MENOR ou igual
  (bloco vazio);
- reconferir a premissa do transformador *por função*: para cada `brilho(`
  aplicado, o material daquela variável é unshaded **naquela função**?

A segunda achou os 6. Ambas ficaram no fim do trabalho: 28 conversões em
material unshaded, **0** em sombreado, **0** sítios com emissão ainda descartada.

**E o número mudou.** A heurística original dizia "32 sítios em 16 arquivos".
Contando por função, são **28** — os outros 4 eram material sombreado que a
janela de ±25 linhas juntou por engano. Contagem por proximidade de texto não é
contagem.

---

## 2026-08-25 — `SHADING_MODE_UNSHADED` descarta a emissão, e o jogo inteiro depende disso

**Sintoma:** liguei o glow no `WorldEnv` e NADA brilhou. As configurações
estavam certas (conferidas em runtime: `glow_enabled=true`, limiar 1,05,
intensidade 0,90, níveis 0/1,0/0,9/0,6/0,35/0/0) e o `Environment` era mesmo o
vivo — provei zerando a saturação e vendo a esfera ficar cinza.

**Causa raiz:** em material `StandardMaterial3D` com
`shading_mode = SHADING_MODE_UNSHADED`, a **emissão é ignorada**. A saída é só o
albedo, que é limitado a 1,0 — e o limiar do glow é 1,05. Nada cruza, nunca.

**Medido**, três esferas, halo no anel em volta com glow ligado menos desligado:

```
unshaded + emission_energy 4.0    +0,0000   <- não brilha
unshaded SÓ albedo                +0,0000   <- IDÊNTICO ao de cima, ao dígito
sombreada + emission_energy 4.0   +0,0355   <- brilha
unshaded + albedo 2.5 (HDR)       +0,0586   <- brilha MAIS
```

As duas primeiras linhas serem iguais ao dígito é a prova: a emissão não chega
ao buffer.

**Por que dói tanto neste projeto:** `unshaded + emissivo` é exatamente a receita
dos efeitos daqui — **32 combinações em 16 arquivos** (`FxUtil`, `YamiFX`,
`FireFX`, `GoroFX`, `GuraFX`, `Melee`, `BukiFX`…). Todas escrevem
`emission_energy_multiplier` entre 2,5 e 4,0 e **jogam esse número fora** desde
sempre. Ninguém notou porque, sem glow no projeto, emissão não fazia diferença
visível de qualquer jeito — dois defeitos que se escondiam um no outro.

**Correção:** albedo acima de 1,0 no lugar da emissão. Preserva o motivo de o
efeito ser unshaded (não escurecer quando o golpe passa pela sombra) e brilha
mais que o caminho sombreado. É trabalho da Fase 5 do `PLANO_VISUAL.md`.

**Como detectar:** glow é invisível quando nada passa do limiar. O teste é
sempre comparativo e com o objeto PARADO — minha primeira medição comparou
glow on/off em dois quadros diferentes de um efeito com `RigidBody3D` voando, e
os números mudaram por causa do movimento, não do glow. Emissivo estático,
mesma câmera, mede o anel em volta.

**Lição de método:** eu afirmei duas vezes, em documento, que ligar o glow faria
"os quatro golpes de nove frutas lerem sem tocar numa linha de VFX". Era
dedução a partir de `grep emission_energy_multiplier`, não medição. O grep
provava que a emissão era ESCRITA; não provava que ela era USADA.

---

## 2026-08-25 — a névoa não pode clarear ao longe e escurecer para baixo

**Sintoma:** o buraco do mapa, que aparecia VERDE (a cor do "chão" do céu
procedural, e portanto lia como grama), passou a aparecer AZUL-CLARO depois do
meu conserto — passou a ler como água. Troquei a cor do erro.

**Causa raiz:** tentei fazer um mecanismo só cumprir duas funções opostas. O
`Environment` tem **uma cor de névoa**. Ela precisa ser clara para a perspectiva
aérea funcionar à distância; e eu liguei `fog_height_density = 0.16` para
escurecer o poço com a mesma névoa. Descendo, ela satura — e névoa opaca CLARA
é o azul que apareceu. De quebra escondeu o plano escuro que eu tinha posto
em `y = −60` para ser o fundo.

**Medido** (cor no meio do poço, mesma câmera):

```
névoa on,  fundo on    (0,263  0,369  0,467)   azul lavado
névoa OFF, fundo on    (0,000  0,000  0,000)   preto
névoa OFF, fundo off   (0,000  0,000  0,016)   preto
```

Duas conclusões: quem lavava era a névoa sozinha, e o plano de fundo era
**redundante** — o `ground_bottom_color` escuro do céu já entrega preto.

**Correção:** `fog_height_density = 0` (o ar só clareia ao longe) e o poço
escurecido pelo céu. O plano foi removido: ele nunca seria visto de perto,
porque o jogador morre em `VOID_Y = −40`, seis metros acima de onde ele estava.

**Como detectar:** quando um ajuste "conserta" trocando um problema por outro
do mesmo tamanho, quase sempre é um mecanismo sendo usado para duas coisas
contrárias. Isolar é ligar e desligar cada um e medir o pixel.

---

## 2026-08-25 — `set_glow_level()` é base ZERO e o inspetor é base UM

**Sintoma:** `ERROR: Index p_level = 7 is out of bounds
(RenderingServer::MAX_GLOW_LEVELS = 7)`, no meio do log de subida.

**Causa raiz:** as propriedades aparecem como `glow_levels/1` .. `glow_levels/7`
no inspetor, então escrevi `set_glow_level(1..7)`. O método é **base zero**
(0..6). O nível 7 estourava e o nível 0 nunca era zerado — o glow ficava
configurado errado, com um erro que some no meio da saída.

**Correção:** `set_glow_level()` passou a ser chamado com índices **0..6**, e a
configuração é lida de volta em runtime para conferir.

**Como detectar:** erro de índice em `_ready` não derruba nada e não falha
teste. Vale conferir a configuração LENDO de volta em runtime
(`get_glow_level(i)`), que foi o que expôs o buraco no nível 0.

---

## 2026-08-25 — onze clipes retargetados têm o tronco tombado ~50°

**Sintoma:** nenhum reclamado, e é o que assusta. Descoberto ao montar o
personagem no Blender: toda pose animada saía "caída". A primeira suspeita foi
da minha conversão — era do dado.

**Causa raiz:** o retarget do Mixamo deixou uma ROLAGEM no `Torso` (eixo Z) que
nunca foi zerada. Medido no primeiro quadro dos 29 clipes: **11 passam de 25°**.

```
roundhouse_kick   −81,4°   (faixa −85,7 … −51,8 — NUNCA fica de pé)
kicking           −60,6°
gunplay           −53,8°
bouncing_idle     −50,7°
boxing_1 (jab)    −32,8°
```

**Confirmado no jogo, não só no JSON:** tocando `bouncing_fight_idle` por
`play_baked`, o vetor "para cima" do torso fica a **51,4° da vertical**.

**Por que ninguém viu:** dos 11, só dois estavam em uso no combo (`boxing_1` e
`roundhouse_kick`), e ali o defeito se confundia com o problema já conhecido de
LEITURA dos socos ("os dois liam igual", 2026-08-11). O resto do acervo é
material de reserva que nunca chegou à tela.

**Como detectar:** `Torso.z` no primeiro quadro de cada clipe. Ele deve estar
perto de zero — rolagem é o eixo que um humano quase não usa parado. Uma
varredura de 10 linhas sobre `tools/anim_editor/clips/*.json` acha todos.

**Correção:** os quatro M1 do combo foram REAUTORADOS
(`tools/autorar_combo_m1.py`), com portão medido que exige `|Torso.z| <= 20°`.
Os outros 7 clipes tombados continuam como estão — estão fora de uso e a lista
ficou registrada em `docs/ESQUELETO.md`, em ordem de gravidade.

---

## 2026-08-25 — a conferência do rig no Blender comparava o erro consigo mesma

**Sintoma:** o `.blend` gerado abria com a pose de repouso PERFEITA e todas as
poses animadas embaralhadas — e o script dizia "✓ a conta fecha, pior erro
0,4 mm".

**Causa raiz:** o Godot reporta `Node3D.rotation_order = 2`, que a documentação
dele chama de **YXZ**. A string equivalente no mathutils do Blender é **`ZXY`**:
as duas bibliotecas nomeiam a ordem de Euler em sentidos opostos. Eu usei
`'YXZ'`.

O que fez o defeito sobreviver a um teste foi outra coisa, e é a lição:
**a conferência comparava a cinemática direta com o Blender, e os dois liam o
Euler pela MESMA função.** Errando junto, concordavam. A pose de repouso
disfarçava porque com todos os ângulos em zero qualquer ordem acerta.

**Correção:** `'ZXY'` no mathutils (não `'YXZ'`), mais a âncora `ANCORA_COLUNAS`
medida DENTRO do Godot, que o script recusa montar se não reproduzir — e um
controle com os eixos errados de propósito, que precisa explodir.

**Como detectar:** teste sem referência EXTERNA não prova conversão. A correção
foi colar no script uma base medida dentro do Godot (`ANCORA_COLUNAS`) e
recusar montar se a conversão não a reproduzir. Junto entrou um CONTROLE: a
mesma conta com os eixos errados de propósito, que precisa explodir — se o
controle não reprovar, o teste não vale e o script também recusa.

Medido depois: âncora 3×10⁻⁷, pior erro 0,099 mm, controle 2,243 m.

**Lição de método:** todo teste de conversão precisa de (a) uma referência
externa e (b) um controle que falhe. Sem (b), "passou" e "não sabe reprovar"
são indistinguíveis — foi a mesma classe de cegueira do `transition_to`
silencioso registrado acima.

---

## 2026-08-25 — `Melee.clipe()` só achava `.res`, e o editor grava `.tres`

**Sintoma:** golpe sem animação nenhuma, com um `push_warning` de "clipe
ausente" que some no meio do log.

**Causa raiz:** o caminho era montado como `"res://assets/animations/%s.res"` —
extensão fixa. O editor de animação do próprio projeto
(`tools/anim_editor/clip.py::para_tres`) grava **`.tres`**, que o Godot carrega
exatamente igual. Ou seja: todo clipe AUTORAL era invisível para o combo.

**Como detectar:** `push_warning` não falha teste nenhum. Vale procurar
`"%s.res"`, `"%s.tres"` e afins — extensão escrita à mão é sempre uma aposta
sobre quem gravou o arquivo.

**Correção:** `clipe()` tenta `.tres` e depois `.res`.

---

## 2026-08-25 — o auto-mira e o lunge do corpo a corpo apontavam PARA TRÁS

**Sintoma:** nenhum visível, e é o que torna o caso instrutivo. O golpe acertava
normalmente (a hitbox sempre usou a direção certa), então nada parecia errado —
o que faltava era o auxílio: o jogador nunca era puxado para o alvo.

**Causa raiz:** `find_best_melee_target` e `perform_melee_lunge` calculavam a
frente como

```gdscript
var forward = -Vector3.FORWARD.rotated(Vector3.UP, _yaw)
```

`Vector3.FORWARD` **já é** `(0, 0, −1)`. Negá-la dá `(0, 0, +1)` — para trás. O
resto do combate usa `-Basis.from_euler(Vector3(0, yaw, 0)).z`
(`melee_controller.pedir`, que é quem posiciona a hitbox).

**Medido** (`dot` entre as duas expressões, três ângulos):

```
yaw= 0.00 | lunge/auto-mira=( 0.00, 0.00, 1.00)  hitbox=( 0.00, 0.00,-1.00)  dot=-1.00
yaw= 1.57 | lunge/auto-mira=( 1.00, 0.00, 0.00)  hitbox=(-1.00, 0.00, 0.00)  dot=-1.00
yaw= 3.14 | lunge/auto-mira=( 0.00, 0.00,-1.00)  hitbox=( 0.00, 0.00, 1.00)  dot=-1.00
```

−1,00 em todo yaw: exatamente opostas, não "um pouco fora".

**Duas consequências, ambas silenciosas:**

1. o cone frontal (`dot_prod > 0.0`) selecionava alvos **atrás** do jogador;
2. o lunge empurrava o corpo **para longe** do alvo recém-selecionado — e para
   longe de onde a hitbox ia nascer.

**Correção:** `find_best_melee_target` e `perform_melee_lunge` passaram a usar
`-Basis.from_euler(Vector3(0, yaw, 0)).z` — a MESMA expressão que o resto do
combate já usava para posicionar a hitbox.

**Como detectar:** duas expressões de "frente" no mesmo sistema é o cheiro. O
teste é uma linha: `print(a.dot(b))` para alguns yaws. `-Vector3.FORWARD` é
armadilha de nome — lê-se "a frente", vale o contrário.

**O que NÃO era bug:** o `lunge_force` de 18,0. Parece absurdo para um puxão de
0,30 m (§3.3 do plano), mas é impulso de UM QUADRO — `_etapa_locomocao` reescreve
`velocity.x/z` no quadro seguinte. 18 ÷ 60 = 0,30 m, o número-alvo. Quase
"corrigi" um valor correto por ler a unidade errada.

## 2026-08-25 — o estado "Stunned" era pedido em 7 pontos e NÃO EXISTIA

**Sintoma:** nenhum. É o pior tipo — o jogo não reclamava de nada, e cinco
mecânicas estavam desligadas em silêncio.

**Causa raiz:** `Player._feedback_de_dano` chamava `_fsm.transition_to("Stunned")`
e outros seis pontos checavam `_fsm.state.name == "Stunned"`. Nunca houve um nó
com esse nome: `PlayerStateMachine.transition_to` começa com

```gdscript
if not has_node(target_state_path):
    return
```

ou seja, a transição era um **no-op calado** e as seis comparações eram falsas
para sempre. O que estava morto por causa disso:

- `_request_melee` não recusava clique sob hitstun — dava para socar apanhando;
- `golpe_prende` nunca cedia ao tranco — atacar era imunidade a empurrão, o
  oposto do que o comentário ao lado afirmava;
- o wall bounce do knockback (depois do `move_and_slide`) nunca disparou uma vez;
- o combo breaker (G) exigia estar em "Stunned" e só conseguia ler o
  `_hitstop_timer`;
- `_slot_em_uso` nunca via combate travado por stun.

**Como detectar:** `grep -n 'transition_to("' *.gd src/**/*.gd` e conferir cada
alvo contra os `add_child` da montagem da FSM. Uma transição para nó inexistente
é indistinguível de uma transição que aconteceu — a máquina não avisa.

**Correção:** `src/player/hsm/CombatStateStunned.gd`, registrado no `_ready` do
Player junto com as outras fases, e uma nota no ponto de montagem dizendo que o
NOME DO NÓ é o endereço.

**Lição de método:** `return` silencioso em resolvedor de nome é o mesmo defeito
de classe do `_fire_skill` que "engole quase tudo" (ver `docs/frutas/README.md`):
o caminho de erro é indistinguível do caminho de sucesso. Onde não dá para
mudar a assinatura, o teste tem que afirmar a EXISTÊNCIA do alvo — foi o que
`src/tests/test_fsm.gd` passou a fazer.

---

## 2026-08-25 — tirar o boneco da cena derrubou a suíte `src/tests/` inteira

**Sintoma:** `>>> TEST FAIL (cenário não montou): TrainingDummy não encontrado em
TestArena.tscn` nos três testes de `src/tests/`. Nenhum deles rodou uma asserção
desde 2026-08-23.

**Causa raiz:** o commit de 2026-08-23 (interruptores F1/F2) tirou o nó
`TrainingDummy` do `TestArena.tscn` — correto, porque os bonecos passaram a ser
criados pelo SERVIDOR via `Main.pedir_dummy()` + `MultiplayerSpawner`. O que não
acompanhou foi o `BaseTest.gd`, que buscava o nó na cena e abortava sem ele.

**Por que passou despercebido:** o aborto é uma linha só, no fim de uma saída de
centenas de linhas de `MoveFrame: ...`, e a contagem "6 falham" da validação de
08-23 não distingue teste que FALHOU de teste que nem MONTOU. É exatamente a
"segunda armadilha" que o cabeçalho do próprio `BaseTest.gd` manda nunca deixar
passar — e passou.

**Correção:** o `BaseTest` monta o próprio boneco quando a cena não traz um.
Devolver o nó à cena seria o conserto errado: a cena deixou de ser o lugar dele
de propósito.

**Como detectar:** `grep -c "cenário não montou"` na saída da suíte. Vale a pena
o `validar.sh` tratar isso como categoria própria, separada de asserção falhada.

---

## 2026-08-25 — o corpo de teste nasce a 1,7 m da parede (falso negativo de dash)

**Sintoma:** no `test_fsm.gd`, a asserção "o corpo saiu de verdade" lia
**0,0 m/s** e acusava um dash que não tinha saído. O dash havia saído: medido a
**42,9 m/s** no quadro do disparo.

**Causa raiz:** duas coisas somadas.

1. O Player, montado em `SpawnPoint` (0, 1, 0), aparece em **z = −9,77** entre os
   quadros 2 e 3 — um teleporte de 9,77 m que ninguém pediu. **A causa disso
   continua ABERTA**; medido, não explicado (`velocity` é zero antes e depois, e
   `Scoreboard.RESPAWN` é (0, 6, 0), então não é o respawn).
2. A parede da arena está em z = −11,5 e a esquiva percorre ~12 m em 0,28 s. A
   asserção media dois quadros depois do disparo, quando o `move_and_slide` já
   tinha zerado a velocidade contra a parede.

**Correção (do teste):** medir no PRIMEIRO quadro da esquiva — que é também o
instante certo semanticamente — e reposicionar o corpo antes do round que mede
deslocamento.

**Como detectar:** asserção de movimento que lê exatamente 0,0 num corpo que
deveria estar voando é quase sempre colisão, não ausência de impulso. Imprimir
`is_on_wall()` e a posição junto com a velocidade separa os dois casos em um
quadro.

**Pendência:** o teleporte do item 1. Está registrado aqui para não se perder;
quem for mexer em spawn de teste começa por ele.

## 2026-08-23 — o Kurouzu (X da Yami) virava zumbi por um argumento faltando

**Sintoma:** relatado pelo dono — "o X da Yami Yami não está atraindo o inimigo e
não está desaparecendo após o uso". O orbe do buraco negro ficava colado na palma
da mão para sempre, e os X seguintes abriam e morriam sem puxar ninguém.

**Causa raiz:** `KurouzuController` chamava `caster.pedir_cancelar_hold("X")` com
UM argumento; `Player.pedir_cancelar_hold(slot, fruit)` pede DOIS. O erro de
runtime aborta a função em curso — e no caminho SEM captura o `queue_free()` vinha
na linha **seguinte**, então nunca rodava. O controlador virava zumbi: `_exit_tree`
é quem libera o `vortex_root`, e ele nunca disparava.

O segundo sintoma sai do mesmo zumbi. A linha `set_meta("yami_kurouzu_active",
false)` vem ANTES da chamada que falha, então continuava rodando a cada quadro.
Passados os 5 s de vida do zumbi, ela desligava o X **seguinte** no primeiro
quadro — o golpe nascia já cancelado. Não era o X que estava quebrado: era o X
anterior que não tinha morrido.

**Evidência:** sonda de dois processos e de processo único
(`--script` com `GameFlow.start_singleplayer`):

```
X nº1 sem alvo -> controladores vivos: 1 | orbes vivos: 1 | kurouzu_active=false
X nº2 (6 s depois, alvo a 8,81 m):
   kurouzu_active logo após comecar = true
   kurouzu_active 0,2 s depois      = false      <- o zumbi desligou
   controladores vivos: 2 | orbes vivos: 2       <- acumulando
SCRIPT ERROR: Invalid call to function 'pedir_cancelar_hold' in base
  'CharacterBody3D (Player)'. Expected 2 argument(s).
  at: KurouzuController._physics_process (res://src/effects/YamiFX.gd:542)
```

O erro repetia a **cada quadro de física**, indefinidamente.

**Descartado:** a oclusão (`cached_los`), a força de sucção, a guarda
`caster.is_multiplayer_authority()` e o teto `KUROUZU_DURATION` — todos corretos.
Com um alvo capturado o golpe puxava 8,42 m -> 1,78 m normalmente; o defeito só
aparece quando a tecla é solta **sem captura**, que é o caso comum em jogo.

**Correção:** `src/effects/YamiFX.gd:542` e `:684` passam a fruta
(`pedir_cancelar_hold("X", "yami_yami")`), e o `queue_free()` foi movido para
**antes** de tocar no caster — a saída do controlador não pode depender de uma
chamada externa dar certo.

**Como detectar de novo:** conjurar X sem ninguém por perto, soltar, e contar os
nós que respondem a `_throw_target` na árvore. Depois da correção: 0 controladores
e 0 orbes após 5 conjurações seguidas (contagem de cena estável em ~1.000 nós).

---

## 2026-08-23 — `world.get_tree()` é null no primeiro golpe de cada vida

**Sintoma:** a primeira conjuração do X da Yami em cada vida não marcava alvo
nenhum: sem `in_kurouzu`, sem o ícone `SUGADO`, sem os 4 s de silêncio. O vórtice
abria na mão e era só enfeite por ~150 ms.

**Causa raiz:** `YamiFX._find_closest_entity` fazia
`world.get_tree().get_nodes_in_group(...)`. O `world` é o `Skills_<jogador>` de
`Player._get_skills_container()`, que entra na cena por
`add_child.call_deferred(...)` — no primeiro cast ele **ainda não está na árvore**,
e `get_tree()` devolve null.

É literalmente a mesma armadilha que `FxUtil.autofree` documenta desde
2026-08-22, no mesmo repositório. Ela voltou porque a correção de lá foi aplicada
**num ponto só**, e não à classe de problema: qualquer código que receba `world`
como parâmetro está sujeito a ele.

**Evidência:**

```
SCRIPT ERROR: Cannot call method 'get_nodes_in_group' on a null value.
  at: _find_closest_entity (res://src/effects/YamiFX.gd:444)
  [1] _kurouzu  [2] cast  [3] _fire_skill  [4] _net_play_cast
```

O que mascarava: a revarredura do `KurouzuController` 150 ms depois roda a partir
de um nó já na árvore e achava o alvo. Por isso o golpe "quase" funcionava — a
distância no primeiro instante media 4,79 m em vez de 2,71 m.

**Correção:** `src/effects/YamiFX.gd:441` cai para
`Engine.get_main_loop() as SceneTree` quando `world.get_tree()` é null — o mesmo
SceneTree, sem depender de o nó estar pendurado.

**Como detectar de novo:** `grep -rn "world.get_tree()" src/effects/` deve voltar
vazio. Em jogo: conjurar o golpe na **primeira** vez de uma vida e procurar
`Cannot call method ... on a null value` no console.

---

## 2026-08-23 — o AutoDummy andava dentro do Black Hole

**Sintoma:** relatado pelo dono — "o C da Yami Yami não deve possibilitar que o
inimigo se mova". O boneco automático perseguia e socava normalmente com o poço
aberto em cima dele.

**Causa raiz:** `AutoDummy._physics_process` chama `super._physics_process(delta)`
e **continua**. O pai (`TrainingDummy`) sai cedo em `in_vortex`, `in_kurouzu` e
`in_black_hole`, mas `super` não interrompe o corpo do filho — o próprio arquivo
já documentava isso para a guarda de autoridade em 2026-08-22 e repetiu **só** o
`is_frozen`. As três metas de controle de multidão ficaram de fora.

**Evidência:** sonda em singleplayer com o C aberto, medindo os dois bonecos lado
a lado (`in_bh=true` nos dois o tempo todo):

```
             AutoDummy          TrainingDummy
t=5,4 s      0,18 m/s           0,32 m/s
t=5,7 s      1,45 m/s   <-      0,48 m/s
t=6,0 s      3,10 m/s   <-      0,40 m/s     (3,5 m/s = perseguição cheia)
```

O TrainingDummy fica nos ~0,4 m/s da sucção; o AutoDummy acelerava para a
velocidade de perseguição e escapava do poço.

**Descartado:** o jogador humano. Duas sondas de **dois processos** (host
conjurando/cliente vítima e o inverso), com W fisicamente segurado via
`Input.parse_input_event`, mostraram `velocity=(0,0,0)` na vítima durante todo o
poço — `Player._etapa_travamento` já respeitava `in_black_hole` nos dois sentidos
da rede. O deslocamento residual de 0,48 m/s era a sucção, não a tecla.

**Correção:** `src/entities/AutoDummy.gd` repete a mesma lista de metas do pai
antes de rodar a IA.

**Como detectar de novo:** abrir o C ao lado dos dois bonecos e comparar a
velocidade dos dois. Divergência = a IA está ignorando o controle.

---

## 2026-08-23 — `set_anchors_preset` sozinho: painel de HUD fora da tela

**Sintoma:** o painel novo dos bonecos de treino não aparecia no canto inferior
direito. Ao investigar, descobriu-se que o **painel de munição da Buki Buki
(`AmmoHud`) nunca tinha aparecido também** — erro silencioso desde que o arquivo
nasceu.

**Causa raiz:** `set_anchors_preset(PRESET_FULL_RECT)` recalcula as âncoras para
**manter** o retângulo atual, que num `Control` recém-criado é `(0,0)`. Todo
cálculo que parte de `size.x`/`size.y` resolve contra zero. O que faz o `Control`
preencher a viewport é `set_anchors_**and_offsets**_preset`.

**Evidência:** print do jogo rodando —

```
[DBG] DummyToggleHud visible=true  size=(0.0, 0.0)
[DBG]   ColorRect size=(250,72)  position=(-270,-92)   <- fora da tela
[DBG] AmmoHud size=(0.0, 0.0)
[DBG] MatchHud size=(1280.0, 1280.0)                   <- o que usa o preset certo
```

**Descartado:** `visible`, `mouse_filter`, ordem dos filhos na `CanvasLayer` e a
`z_index` — todos corretos.

**Correção:** `src/ui/DummyToggleHud.gd` e `src/ui/AmmoHud.gd` passam a usar
`set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)`.

**Como detectar de novo:** `grep -rn "set_anchors_preset(Control.PRESET_FULL_RECT)"
src/ui/` — em `_ready()` de HUD raiz, é sempre o errado. E, no jogo rodando,
imprimir `size` do nó: `(0,0)` num painel que deveria preencher a tela é o defeito.

**Lição de método (o erro é meu, e repetido):** o `MatchHud` documenta este exato
defeito desde 2026-08-12, com a mesma explicação, no mesmo repositório — e eu
escrevi a chamada errada de novo. O motivo de escapar é que **ela não vira erro em
teste nenhum**: compila, instancia, `visible` é `true`, os filhos existem, e todas
as sondas de árvore passam. Só a captura de tela do jogo rodando denuncia. Por isso
o `AmmoHud` conviveu meses com o defeito. Regra prática: HUD nova só conta como
entregue depois de **aparecer numa captura de tela**, nunca por sonda de árvore.

---

## 2026-08-10 — `--editor --quit` não detecta script que não compila

**Sintoma:** uma edição minha quebrou o `IceFX.gd` inteiro (usei a variável
`duration` num escopo onde ela não existe). A Ice Age parou de fazer **qualquer
coisa** — sem campo, sem congelamento, sem dano. E a checagem que eu vinha
usando a sessão toda, `godot --headless --path . --editor --quit`, reportou
**"0 erros"**.

Passei três rodadas de investigação achando que o problema era alcance da área
de efeito, posição do alvo e camada de colisão. Não era nada disso: a classe
não existia em tempo de execução.

**Causa raiz:** `--editor --quit` **reimporta assets e atualiza o cache de
`class_name`** — ele não *carrega* os scripts. Erro de sintaxe ou de
identificador não aparece nessa passada; só quando alguém tenta usar a classe,
em execução, e aí o sintoma é "o golpe não faz nada", que se confunde com bug de
gameplay.

**Evidência:** com o `IceFX` quebrado, `--editor --quit` → `0 erros`; o mesmo
projeto rodando o carregamento de verdade → `Parse Error: Identifier "duration"
not declared in the current scope`.

**Descartado:** não era alcance da área (o campo cresce de 0,35 a 11,0), não era
camada de colisão (dummy e player estão os dois na 1), não era posição do alvo.
Os três foram medidos antes de eu olhar para a compilação.

**Correção:** `tools/dev_tests/test_compila.gd` — carrega **todo** `.gd` do
projeto com `load()` e falha se algum voltar `null`.

```bash
godot --headless --path . --script tools/dev_tests/test_compila.gd
```

**Como detectar de novo:** rodar esse script depois de qualquer edição, e
**principalmente depois de edição automatizada** (`sed`, script de inserção) —
que é onde nasce o erro de variável fora de escopo, porque quem edita não está
lendo o entorno. `--editor --quit` continua útil para `class_name` novo e import
de asset; ele só não serve como prova de que o código compila.

---

## 2026-08-10 — Knockback não empurrava ninguém, nem em rede nem em um-jogador

**Sintoma:** relatado jogando — "jogador cliente e servidor não tomando knockback".

**Causa raiz — são DUAS, empilhadas:**

1. **A locomoção sobrescrevia o empurrão.** O bloco de movimento faz
   `velocity.x = dir.x * effective_speed` — **atribuição**, não soma. O
   `take_damage` somava o knockback em `velocity`, e no quadro seguinte a
   locomoção reescrevia X e Z do zero. Isso vale **inclusive em um-jogador**, e é
   por isso que os DOIS jogadores foram reportados sem knockback.
2. **Em rede, o servidor empurrava a cópia errada.** A `DamageZone` roda no
   servidor, então `take_damage` mexia na cópia que o servidor tem da vítima. Se
   a vítima é de outro peer, `velocity` ali não vale nada — a replicação traz a
   posição do dono no quadro seguinte e sobrescreve.

**Evidência:** teste com dois processos, servidor mandando empurrão de
`(0, 6, −40)` no cliente. Deslocamento medido: **0,00 m antes, 6,00 m depois**.

**Descartado:** não é força insuficiente nem `DamageZone` sem alcance — o log
`🚀 Knockback Final Aplicado` saía normalmente. O empurrão era calculado e
aplicado; só não sobrevivia ao quadro.

**Correção:**
- `_kb_impulso` — o componente horizontal do knockback virou um impulso próprio,
  que decai sozinho e é **somado depois** da locomoção escrever `velocity`, logo
  antes do `move_and_slide()`. O vertical continua indo direto em `velocity.y`,
  que a locomoção não reatribui.
- `net_apply_knockback` — o servidor manda o knockback **cru** para o DONO do
  corpo, e é lá que ele é escalado. Mandar o valor já calculado seria errado: as
  duas regras que o modelam (dobrar no ar, resistir andando contra) dependem de
  `is_on_floor()` e do **teclado da vítima** — e no servidor `Input.is_key_pressed`
  lê o teclado do host, não o de quem apanhou.

**Como detectar de novo:** teste de knockback tem que medir **deslocamento em
metros**, não a existência do log. E a regra geral: qualquer efeito que escreva
em `velocity` de fora do bloco de locomoção precisa ser um impulso separado —
`velocity` pertence à locomoção, que a reescreve todo quadro.

---

## 2026-08-10 — Fruta sem skills virava Gomu Gomu em silêncio

**Sintoma:** relatado jogando — "frutas equipadas diferente das que foram
adquiridas, por exemplo ope ope resulta em gomu gomu". E: "após a morte do
jogador cliente a fruta do jogador do servidor voltou a ser a gomu gomu".

**Causa raiz:** `Player._fire_skill` tinha

```gdscript
var fid := current_fruit_id if fruit_skills.has(current_fruit_id) else "gomu_gomu"
```

Um fallback **mudo**. Ele disparava em dois casos:

- **fruta sem skills:** o mapa planta 11 árvores, mas o `SkillSystem` só conhece
  9 frutas. `ope_ope`, `hito_hito_nika` e `tori_tori_phoenix` — **3 de 11** —
  entravam no inventário com o nome certo e davam os golpes da Gomu Gomu;
- **sem fruta nenhuma:** ao morrer o jogador larga a fruta
  (`current_fruit_id = ""`), e a partir daí os golpes saíam como Gomu Gomu, como
  se ele tivesse ganhado uma fruta ao morrer.

**Evidência:** cruzando o pool de árvores com o `SkillSystem` — 11 árvores, 9
frutas com poder, 3 órfãs. E `gura_gura` tem poderes mas **nenhuma árvore**, ou
seja, é impossível de obter jogando.

**Correção:**
- O pool de árvores passou a ser **derivado** de quem tem skills
  (`get_tree_definitions` filtra por `SkillSystem`), com log do que ficou de
  fora. As definições de arte continuam no arquivo — falta só dar poderes a elas.
- O fallback morreu. Sem fruta ou com fruta sem poderes, **o golpe não sai** e o
  jogo diz por quê.

**O que NÃO foi verificado:** o relato diz que a fruta do jogador do **servidor**
mudou quando o **cliente** morreu. Medido em dois processos, cada jogador larga
a **própria** fruta ao morrer, como esperado — não reproduzi o efeito cruzado. O
que o conserto garante é que "sem fruta" deixou de **parecer** Gomu Gomu. Se
ainda acontecer de uma fruta trocar de dono, o sintoma agora é visível em vez de
disfarçado.

**Como detectar de novo:** fallback silencioso em despacho de dados é armadilha —
ele transforma "faltou registrar" em "comportamento errado plausível". Se um id
não existe, falhe alto.

---

## 2026-08-10 — Pistola da Yami: o tiro do cliente não feria ninguém

**Sintoma:** relatado jogando — "Yami Yami: o jogador do servidor não toma dano
da pistola (Z) do cliente". No host funcionava.

**Causa raiz:** `_process_yami_pistol` chamava `YamiFX.bullet()` **direto**, sem
passar pelo servidor — ao contrário do `_request_bullet` da rajada Z, que já
fazia o trajeto certo. Como a `DamageZone` só aplica dano no servidor, a bala
disparada de um cliente existia **só na tela dele**.

No host o mesmo código funciona porque lá o local **é** o servidor — a mesma
classe de erro do bug da HUD no corpo errado.

**Correção:** o tiro passou a usar o trajeto que já existia —
`_do_server_bullet` no host, `_net_bullet_req.rpc_id(1, …)` no cliente. O
`_net_bullet_play` já despachava por fruta e trata `yami_yami`.

**Como detectar de novo:** todo efeito que causa dano precisa nascer no servidor.
Procure por `FX.*(get_tree().current_scene, …)` chamado de dentro de tratamento
de input local — é a assinatura do bug.

---

## 2026-08-10 — VFX do Gomu V ficava aceso no mapa para sempre

**Sintoma:** relatado jogando — "Gomu gomu está deixando um rastro luminoso
permanente no mapa quando o v é ativado".

**Causa raiz:** em `GomuRedHawk._spawn_explosion` o tween que apaga a luz era
criado com `create_tween()` — ou seja, **no próprio `GomuRedHawk`**. Só que esse
nó chama `queue_free()` no fim de `_impact()`. O nó morre, o tween morre junto,
o `tween_callback(light.queue_free)` nunca roda, e a `OmniLight3D` fica acesa.
**Uma luz órfã por uso do V.**

**Evidência:** contagem de nós da cena, 5 disparos seguidos: **+5 nós, todos
`OmniLight3D`** — exatamente 1,0 por disparo. Depois do conserto: **delta 0**.

**Correção:** o tween nasce na própria luz (`light.create_tween()`), que
sobrevive ao criador, mais um `FxUtil.autofree(light, 0.6)` como rede de
segurança. Na mesma passada saiu um segundo defeito: `global_position` era
escrito **antes** do `add_child`, e num nó fora da árvore isso devolve
`Transform3D()` com erro — o efeito nascia no centro do mapa em vez de na ponta
do braço. Corrigido no `GomuRedHawk` e no `GomuFX`; varredura confirmou 0
ocorrências restantes do padrão em `src/effects/` e `src/combat/`.

**Como detectar de novo:**
`godot --headless --path . --script tools/dev_tests/test_gomu_leak.gd -- V`
conta os nós antes e depois. Vazamento cresce **linear** com as repetições;
"ainda não terminou" não cresce. E a regra: tween que libera um nó tem que nascer
**no nó que ele libera**, nunca em quem o criou.

---

## 2026-08-10 — No cliente, a HUD inteira operava o corpo do HOST

**Sintoma:** relatado jogando. **Só no PC que ENTRA na sala**, nunca no que
hospeda: a energia não regenerava, nem depois de morrer, e as skills de fruta não
funcionavam.

**Causa raiz:** `Hud.gd`, `StatsHud.gd`, `SkillBar.gd` e `CharacterMenu.gd`
achavam o jogador com `get_tree().get_first_node_in_group("player")` — que
devolve o **primeiro da árvore**, não o **meu**. O servidor replica os players já
existentes para o peer novo **antes** de emitir `peer_connected`, então no
cliente o corpo do host entra primeiro e fica no índice 0. No host, o índice 0 é
o corpo dele mesmo.

**É essa a assimetria inteira:** `get_first_node_in_group` acerta no host e erra
no cliente, sempre. Por isso nunca apareceu em um-jogador — lá só existe um
corpo, e ele é o certo.

**Evidência**, medida no cliente com dois processos de verdade:

```
grupo[0] = '1'          auth=false   <- corpo do HOST
grupo[1] = '454688302'  auth=true    <- o meu
get_first_node_in_group('player') -> '1'
```

- **Energia:** a barra lia o fantasma do host. Aquele corpo não é autoridade, e
  `_physics_process` desvia para `_remote_process` antes da regen — que fica em
  `Player.gd:434`. Cada tecla ainda drenava 180 dele: **3916 → 3736 → 3556, sem
  nenhuma regeneração entre as leituras**. Ao morrer, `net_force_respawn()`
  repunha a energia do corpo **certo**, que a barra não mostrava.
- **Skills:** Z/X/C/V iam para o fantasma, e `_request_cast` corta em
  `not _is_authority` — nenhuma skill saía, cooldowns em 0.00 nos quatro slots.

**Descartado com medição:** `_is_authority` do cliente é **true** (o palpite
inicial de que estaria falso caiu); a ordem `set_multiplayer_authority` → `_ready`
está certa; as anotações `@rpc` são todas `any_peer` e não rejeitam nada; metas
`is_frozen`/`in_vortex`/`in_kurouzu`/`in_black_hole` ficam false; `is_suppressed`
false; `_movement_locked_timer` expira normalmente.

**Correção:** `Player.local_player(tree)` — devolve o corpo cuja
`is_multiplayer_authority()` é true, ou `null` (melhor nada que o errado). As 6
chamadas na UI passaram a usá-lo.

**Como detectar de novo:** `get_first_node_in_group` **não serve** para achar "o
meu" de nada em jogo em rede. Toda busca de nó de jogador tem que filtrar por
autoridade. E o teste precisa de **dois processos** — sondas em
`tools/dev_tests/net_host_probe.gd` e `net_client_probe.gd`.

⚠️ Armadilha da medição: em headless os frames correm muito mais rápido que o
tempo real, então contar `process_frame` como 1/60 s dá regeneração falsa
("+314 de 640 esperado" parecia meia-regen, era o relógio da sonda). Use
`Time.get_ticks_msec()`.

---

## 2026-08-10 — O timer de cast de uma skill apagava o `is_casting` da seguinte

**Sintoma:** encadear duas skills rápido faz a segunda sumir sem erro nenhum. Some
no cliente, no host e em um-jogador — no cliente é mais frequente.

**Causa raiz:** `_fire_skill` armava `create_timer(0.3)` para apagar
`is_casting`. Se a skill seguinte começasse dentro dessa janela, o timer da
**anterior** apagava o `is_casting` da **nova**. `Player.gd:446-447` lê isso como
"cast interrompido por dano" e zera `_charging`; aí `release_charge` cai no
`if not _charging: return` e o disparo nunca acontece.

**Evidência**, quadro a quadro em singleplayer:

```
release X feito.            is_casting=true  _charging=false
begin_charge('C')        -> _charging=true   is_casting=true
>>> _charging FOI ZERADO em 248 ms (Player.gd:447), is_casting=false
cooldown de C depois do release = 0.00   (a skill NÃO saiu)
```

**Correção:** `_cast_token` — `begin_charge` incrementa um contador, e o timer só
apaga `is_casting` se o token ainda for o do cast que o armou.

**Diagnóstico anterior corrigido:** eu tratei isto como bug **exclusivo do
cliente**. Não é — acontece nos três modos. O cliente sofre mais porque o timer
dele começa um round-trip de RPC depois (`_net_cast` → servidor →
`_net_play_cast`), o que empurra a janela de 0,3 s justo para cima da tecla
seguinte.

**Como detectar de novo:** temporizador que escreve em estado compartilhado
precisa carregar a identidade de quem o armou. O sintoma é sempre o mesmo —
funciona devagar, falha rápido.

---

## 2026-08-10 — O walk patinava 45% e a documentação afirmava 8%

**Sintoma:** `tools/dev_tests/test_walk_run.gd` reprovava nos 4 casos com deslize
de 45% (teto 10% no walk, 25% no run). Ninguém tinha rodado esse teste.

**Causa raiz:** identidade algébrica, não bug de conta:

```
v_pé = passada/π · ω    e    ω = π·v/passada · CADENCIA_ESCALA
   ⇒  v_pé = v · CADENCIA_ESCALA   ⇒  deslize = 1 − 0,55 = 45%
```

A **passada cancela**. Logo o deslize não depende do porte do personagem, da
passada nem da altura do quadril: `CADENCIA_ESCALA` é a única alavanca que existe
aqui, e o freio de 0,55 fixa 45% de patinação.

**Evidência:** `base` (perna 0,469 m) e `nami` (0,613 m) dão a MESMA velocidade de
pé, 2,31 m/s — foi essa coincidência impossível que denunciou. Deslize medido
fora do animador, reconstruindo o pé pelas rotações: 45,4 / 47,1 / 45,2 / 45,9%.

**Descartado:** não é constante comendo medida do corpo — a passada escala certo
com a perna (0,488 vs 0,655 m, razão 1,34 = 0,613/0,469). E `PASSADA_GANHO` está
**inerte**: trocar 1,6 por 1,3 não muda um milímetro, porque a passada pedida já
estoura o teto geométrico e é cortada por ele.

**Correção:** ⚖️ **nenhuma no comportamento, de propósito.** As duas saídas foram
medidas e as duas são piores: tirar o freio leva a cadência de 4,35 a 7,91
passos/s e *encolhe* a coxa de 87° para 72° (o walk frenético já rejeitado);
alongar a passada exigiria 1,83×, com o quadril a 10 cm do chão numa perna de
47 cm — impossível. Os 45% são preço escolhido. O que mudou foi o **teto do
teste** e o cabeçalho do `ProceduralAnimator`, que afirmava "8% de deslize" —
**número inventado**, sem medição por trás.

O conserto real é reduzir `Player.SPEED`: 4,2 m/s num corpo de 1,5 m equivale a
um humano a ~11 m/s.

**Como detectar de novo:** o teste **pedia a nota ao próprio animador**
(`anim.deslize()`) em vez de medir a pose que sai. Provado que mascarava: com
`CADENCIA_ESCALA = 1.0` o animador dizia **0%** enquanto a pose entregava **7%**
(walk) e **29%** (run, com `CADENCIA_MAX` mordendo sem ninguém ver). Hoje o teste
mede o pé na pose e tem teto de cadência, para ninguém "consertar" deslize
acelerando as pernas.

---

## 2026-08-10 — Proxies do rig se chamam `RoleProxy_<papel>`, e três sistemas procuram `<papel>`

**Sintoma:** ⚠️ **latente — ninguém viu ainda**, porque o elenco está trancado no
`base`, que é voxel. Passa a acontecer no instante em que um personagem
**skinnado** virar jogável: a pistola do Z (mera/hie) não aparece, o fôlego perde
a âncora da cabeça, e as armas da Buki Buki **flutuam na origem do mundo** em vez
de nascer no braço.

**Causa raiz:** no personagem voxel os papéis do rig são **nós com o nome do
papel** (`ForeArm_R`, `Head`). No skinnado não existem esses nós — o
`SkeletonDriver` cria proxies e os nomeia com prefixo:

```gdscript
# src/anim/SkeletonDriver.gd:106
p.name = "RoleProxy_" + role
```

Só que três lugares procuram o nome **puro**:

| lugar | busca | resultado no skinnado |
|---|---|---|
| `Player._attach_pistol()` | `find_child("ForeArm_L/R")` | `null` → pistola nunca aparece |
| `Player.gd:923` e `:973` | `find_child("Head")` | `null` → `_head_node` vazio |
| `BukiFX._membro()` | `find_child(papel)` | `null` → cai no fallback e pendura a arma em `current_scene` |

**Evidência:** medido nos 4 modelos Meshy — `find_child("ForeArm_R")` → `null`;
`find_child("RoleProxy_ForeArm_R")` → `Node3D`. O comentário no topo de
`BukiFX._membro()` afirma que "no skinnado o BodyScanner criou proxies com os
mesmos nomes" — **está errado**, e foi essa afirmação que escondeu o problema.

**Descartado:** não é o `SkeletonDriver` falhando em resolver papéis — ele
resolve **13/13** em todos os Meshy. O rig está certo; o que não bate é o nome
pelo qual os outros sistemas o procuram.

**Correção:** ⏳ pendente. O conserto barato é fazer o driver nomear o proxy com
o papel puro (`p.name = role`), o que conserta os três de uma vez. A alternativa
é os três aceitarem os dois nomes.

**Como detectar de novo:** teste que, para cada personagem **skinnado**, exija
`_membro(caster, "ForeArm_R") != null` e `_attach_pistol` produzir nó visível.
Hoje `tools/dev_tests/test_buki_buki.gd` roda só no `base` (voxel), onde os nós
existem de verdade — por isso passa verde com o bug presente.

---

## 2026-08-10 — Baker do Mixamo salva `.res` vazio e retorna sucesso

**Sintoma:** ⚠️ **latente.** Ao assar um `.glb` cujo esqueleto não use os nomes
`mixamorig_*` (por exemplo, um modelo Meshy exportado pelo Blender), o baker
grava o arquivo, **não emite erro nenhum** e reporta sucesso — mas o `.res` sai
com faixas sem uma única chave.

**Causa raiz:** o `MAP` em `tools/bake_mixamo.gd` (linhas 18-22) mapeia papel →
osso usando **só** nomes `mixamorig_*`. Quando nenhum casa, `rest` fica vazio e
os `continue` do laço pulam todas as inserções de chave. Não há checagem de
"quantos ossos eu encontrei?" antes de salvar.

**Evidência:** no modelo Meshy novo — `MAP` original: **0 de 12 ossos
encontrados**, `.res` salvo sem erro. Com aliases Meshy acrescentados
(`Spine`, `LeftArm`, `LeftForeArm`, …): **13/13**, e os 6 clipes assam com
121/42/53/19/27/31 chaves reais.

**Descartado:** não é o `GLTFDocument` nem o `fbx_to_glb.py` — o `.glb` de
entrada tem as curvas; é o mapeamento de nomes dentro do baker que não casa.

**Correção:** ✅ feita (2026-08-10). No `MAP` cada papel virou uma LISTA de
aliases, igual à `SkeletonDriver.BONE_ALIASES`, e o papel `Neck` entrou. O bake
agora **aborta** (`push_error` + saída 1) se resolver zero ossos ou inserir zero
chaves. Medido depois: esqueleto Meshy **13/13**, esqueleto `mixamorig_*`
**13/13**. Reassar o `punching` com o `MAP` novo devolve amplitude idêntica à de
antes (`SOMA_MEMBROS=533`) — os 28 clipes antigos não regridem.

Na mesma passada caíram mais dois defeitos do baker:

- **Um clipe por arquivo.** Ele pegava só o mais longo; um `.glb` de animações
  mescladas (o Meshy exporta assim, 6 clipes) perdia os outros 5. Agora assa
  todos: 1 clipe → nome do ARQUIVO (compatível com os 28 atuais, todos de um
  clipe `mixamo_com`), 2+ → nome do CLIPE em `snake_case`.
- **Salto de euler.** `Basis.get_euler()` devolve sempre o representante
  canônico, então duas poses vizinhas saíam como +179° e −179°: a faixa é
  LINEAR e o membro dava a volta longa. Medido nos 28 clipes antigos, **17 têm
  intervalos em que o membro percorre ~360° de giro espúrio entre duas chaves**
  (`armada` 359.8°, `dying` 361.3°, `kicking` 357.7°, `running_dive_roll`
  367.8°…). O baker agora escolhe, chave a chave, o euler EQUIVALENTE mais perto
  da chave anterior — as duas famílias da ordem YXZ, `(x,y,z)` e
  `(π−x, y+π, z+π)`, mais múltiplos de 2π por eixo. E passou a assar a 60 fps,
  porque a faixa é linear e a densidade de chaves é o único controle sobre o
  erro de interpolação. Nos clipes Meshy novos o percurso máximo entre chaves
  caiu para 17.2° (`left_uppercut`) e 12.4° (`right_upper_hook`).
  ⚠️ **Os 28 `.res` antigos continuam a 30 fps e com os saltos de ~360°** — só
  somem quando forem reassados (`-s tools/bake_mixamo.gd` sem filtro).

**Como detectar de novo:** depois de qualquer bake, rodar os dois:
`godot --headless --path . --script tools/dev_tests/medir_amplitude_res.gd`
(clipe vazio ou congelado acusa na hora; o tamanho do arquivo e a contagem de
faixas, não) e
`godot --headless --path . --script tools/dev_tests/medir_salto_res.gd`
(salto entre chaves vizinhas; a coluna `PERCURSO` é o giro que o membro faz de
verdade — é ela que denuncia o estalo, não o `EULER_max`, que incha perto do
gimbal sem que nada se mexa).

---

## 2026-08-10 — `hurricane_kick` toca com os membros congelados

**Sintoma:** o clipe existe, tem duração e chaves, e é ciclado normalmente no
"Teste de Animação" — mas em jogo o personagem só balança o tronco. Braços e
pernas ficam parados na pose de descanso.

**Causa raiz:** o defeito vem do **asset de origem**, não do baker.
`assets/animations_glb/hurricane_kick.glb` tem só **2 amostras de rotação em
todo osso de membro** (`LeftArm`, `LeftForeArm`, `LeftLeg`, `LeftUpLeg`,
`RightArm`, `RightForeArm`, `RightLeg`, `RightUpLeg`, `Spine`) e 56 no `Hips`.
Duas amostras com o mesmo valor = curva constante. É a **mesma falha de "1 chave
por osso" do importador FBX** descrita na seção 3 de
[`MUDANCAS_2026-08-06.md`](historico/MUDANCAS_2026-08-06.md), que se acreditava eliminada
pela conversão FBX→glTF via Blender: ela **sobreviveu neste arquivo**, que
provavelmente foi convertido a partir de um FBX já sem as curvas de membro.

**Evidência:** medindo amplitude de movimento (max−min por eixo, somada) nos
papéis do rig, no `.res` assado:

| clipe | braço D | braço E | perna D | perna E |
|---|---|---|---|---|
| `hurricane_kick` | **0°** | **0°** | **0°** | **0°** |
| `kicking` | 272° | 274° | 757° | 681° |

E no GLB de origem, amostras de rotação por osso: `hurricane_kick` = 2 em todo
membro / 56 no Hips; `kicking` = 69 em todos.

**Descartado:** não é o baker (`tools/bake_mixamo.gd`) e não é o pipeline —
varrendo os 28 GLBs pelo mesmo critério, **27 estão corretos e só este falha**.
Também não é falta de faixa: o `.res` tem as 12 faixas e 57 chaves, com valores
plausíveis; elas é que são todas iguais entre si.

**Correção:** ❌ **impossível localmente — o FBX de origem também não tem as
curvas.** A causa foi empurrada um nível para trás: não é o baker, não é o
`fbx_to_glb.py` e não é a conversão glTF. O **próprio `.fbx` baixado do Mixamo
já veio sem animação de membro**. Não há o que reconverter: o dado não existe em
lugar nenhum da cadeia local.

**Evidência da causa final** (medida em 2026-08-10, três leituras independentes):

1. `assets/animations/hurricane_kick.fbx` e
   `~/Downloads/animações importadas do mixamo/Hurricane Kick.fbx` são **o mesmo
   arquivo** (md5 `a07713de5041d24f0a33ebd7fa43231d`). Não existe um "original
   bom" guardado.

2. **Importado no Blender 5.2** (`bpy.ops.wm.fbx_import`), única action
   `mixamo.com`, 520 fcurves — chaves de rotação por osso:

   | osso | `hurricane_kick.fbx` | `kicking.fbx` |
   |---|---|---|
   | LeftArm / LeftForeArm / RightArm / RightForeArm | **1** | 69 |
   | LeftUpLeg / LeftLeg / RightUpLeg / RightLeg | **1** | 69 |
   | Spine | **1** | 69 |
   | Hips | 56 | 69 |

3. **Lido direto do binário FBX**, sem passar por importador nenhum (parser
   próprio, zlib + Connections), para descartar culpa do Blender. Mesmo
   resultado. Os dois arquivos têm estrutura idêntica — FBX v7700, 315
   `AnimationCurve`, 54 `AnimationCurveNode`, 67 `Model`, e **os dois takes**
   (`Take 001` e `mixamo.com`, layers `Base Layer` e `Layer0`). Histograma de
   chaves por curva:

   | | curvas com 1 chave | curvas com todas as chaves |
   |---|---|---|
   | `hurricane_kick.fbx` | **153** | 162 (56 chaves) |
   | `kicking.fbx` | 18 | 297 (69 chaves) |

   Checado também o **segundo take**: os 153 curvas órfãs (não referenciadas em
   nenhuma das 666 conexões) do `hurricane_kick` têm 56 chaves, mas só **3 delas
   têm amplitude > 1°** — e são as do `Hips`. No `kicking`, 130 das 153 órfãs
   têm amplitude > 1°. Ou seja: **nem o take escondido salva**. No arquivo
   inteiro, o `hurricane_kick` tem 8 curvas com movimento real, todas do quadril;
   o `kicking` tem 269.

**Desfecho (2026-08-10): o clipe foi ELIMINADO do projeto**, por decisão do dono.
Nenhum código o carregava — os dois testes que o usavam já tinham sido migrados
para o `kicking`. Removidos: o `.res`, o `.fbx`, o `.fbx.import`, o `.glb` e a
cópia do editor de animação (mais a entrada no `index.json` dele). A biblioteca
foi de 30 para 29 clipes.

**Como trazer de volta, se quiser:** baixar outra vez em mixamo.com e rodar
`./tools/importar_animacao.sh <arquivo.fbx>` — que reconverte, assa e **recusa**
o arquivo se ele vier quebrado de novo (foi testado exatamente contra este
clipe). O antigo continua recuperável pelo histórico do git e pelo backup em
`~/dev/_backups/skills-one-piece/animations-20260810-200658/`.
Enquanto isso não acontece, **nada quebra**: o clipe não é referenciado por
nenhum código de jogo — só por `tools/dev_tests/test_rig_unico.gd`,
`tools/dev_tests/test_anatomia_rig.gd` e pelo índice do editor de animação. O
combate corpo a corpo usa `punching` e `kicking`.

**Diagnóstico anterior corrigido:** a entrada dizia "provavelmente foi convertido
a partir de um FBX já sem as curvas de membro" — confirmado, e o "provavelmente"
pode cair. Também cai a suspeita sobre o importador FBX do Godot **neste caso
específico**: aqui ele não tinha nada para perder.

**Como detectar de novo:** contar amostras **POR OSSO** no GLB — nunca por
número de faixas, de chaves ou de canais. Os três dão "ok" num clipe totalmente
congelado (este arquivo tem os mesmos 195 canais e 65 nós animados do `kicking`,
que está perfeito). Varredura dos 28 clipes:

```bash
python3 - <<'EOF'
import json, struct, os, glob
MEMBROS = {"LeftArm","LeftForeArm","RightArm","RightForeArm",
           "LeftUpLeg","LeftLeg","RightUpLeg","RightLeg"}
for p in sorted(glob.glob("assets/animations_glb/*.glb")):
    d = open(p,'rb').read()
    j = json.loads(d[20:20+struct.unpack('<I', d[12:16])[0]].decode('utf-8'))
    if not j.get("animations"): print("SEM CLIPE:", p); continue
    a = j["animations"][0]
    nomes = {i: n.get("name","") for i, n in enumerate(j["nodes"])}
    am = [j["accessors"][a["samplers"][c["sampler"]]["output"]]["count"]
          for c in a["channels"]
          if c["target"]["path"] == "rotation"
          and nomes.get(c["target"]["node"],"").replace("mixamorig:","")
                   .replace("mixamorig_","") in MEMBROS]
    if am and max(am) <= 2:
        print("CONGELADO:", os.path.basename(p), "max", max(am), "amostras")
EOF
```

Varredura equivalente no **`.res` assado** (mede amplitude em graus por papel do
rig, que é o critério que importa de verdade — clipe congelado tem as mesmas 12
faixas e 57 chaves de um clipe bom):

```bash
godot --headless --path . --script tools/dev_tests/medir_amplitude_res.gd
```

Marca `<<< CONGELADO` quando a soma da amplitude dos 8 papéis de membro fica
abaixo de 10°. Rodado em 2026-08-10 nos 28 clipes: só o `hurricane_kick` acusa
(0° em todo membro, 380° no `Torso`); o segundo menor é o `gunplay` com 81°, e a
mediana fica perto de 1.100°.

E para conferir o **FBX** antes de converter (Blender 5.2 — a API nova trocou
`Action.fcurves` por `layers → strips → channelbags → fcurves`; código antigo
estoura `AttributeError`): contar `len(fc.keyframe_points)` das fcurves cujo
`data_path` contém `rotation`, agrupando pelo osso entre `pose.bones["…"]`. Osso
de membro com **1 chave** = arquivo veio quebrado do Mixamo.

---

## 2026-08-07 — Cópia da fórmula no teste escondeu a mudança no código

**Sintoma:** entrou o freio de cadência no animador, mas o teste de walk/run
continuou reportando o mesmo ciclo e o mesmo deslize de antes — sem acusar nada.

**Causa raiz:** o teste tinha a fórmula da cadência **replicada**
(`minf(PI * planar / passada, CADENCIA_MAX)`). Quando o animador ganhou o fator
de escala, a cópia ficou para trás e passou a medir um estado que não existia
mais.

**Evidência:** com `CADENCIA_ESCALA = 0.62` aplicado, o teste ainda dizia
"ciclo 25 quadros, deslize 0%" para o `base` — exatamente os números de antes.

**Correção:** `ProceduralAnimator` expõe `cadencia()` e `deslize()`, e o teste
chama essas. Fonte única.

**Como evitar de novo:** teste de cálculo **chama a função do código**. Se for
preciso reescrever a conta para testar, o que está sendo testado é a cópia.

**Achado junto:** o teste também não aplicava o `CHAR_TARGET_H` que o jogo aplica,
então media o `base` com perna de 1,66 m em vez de 0,69 m — a cadência calculada
não era a que roda em jogo.

---

## 2026-08-07 — Trava de elenco vazou: o jogo abria com o Crocodile

**Sintoma:** com o elenco trancado no `base`, o jogo continuava começando com o
**Crocodile**.

**Causa raiz:** pus o guarda em `Player.set_character()`, que parecia a porta de
entrada — mas não é. `_setup_character_model()` tem **quatro** chamadores, e o
que vazava era o `equip_fruit()`: ele troca a aparência conforme a fruta
(`suna_suna` → `crocodile`) e chama `_setup_character_model()` **direto**. E o
`Main` equipa `suna_suna` ao nascer ([Main.gd:108](../Main.gd)).

**Evidência:** no log do jogo, `🔄 Troca automática de aparência: comendo a fruta
[suna_suna] -> transformado em [crocodile]!` logo depois do spawn.

**Correção:** guarda movido para o topo de `_setup_character_model()` — o ponto
de estrangulamento por onde todos passam. `equip_fruit()` também checa a trava
**antes de anunciar**, senão o log dizia "transformado em crocodile" e carregava
o base logo abaixo.

**Como evitar de novo:** antes de pôr um guarda, `grep` por **todos** os
chamadores do método que de fato carrega — e proteger esse, não o que parece ser
a entrada. Teste: `tools/dev_tests/test_elenco_trancado.gd` cobre os 12 caminhos
(inicial, 5 frutas, 5 `set_character`, chamada direta).

---

## 2026-08-07 — Personagem voxelizado saiu deitado: a malha do Meshy já é Y-up

**Sintoma:** ao exportar a malha para o editor posicionar marcadores, os modelos
Meshy vinham com altura errada — a Nami com **0,55 m** em vez de 1,70.

**Causa raiz:** apliquei o giro de −90° em X da Armature **na malha também**. Mas
`mesh.get_aabb()` da Nami dá `(0.78, 1.70, 0.55)` — 1,70 na altura, ou seja **a
malha já está em Y-up**. Aquele giro existe para orientar o **esqueleto**, que é
Z-up. Aplicando nos dois, a altura vira profundidade e o personagem deita.

**Evidência:** antes 0,55 m; depois da correção, 1,70 m nos quatro modelos Meshy.

**Correção:** `tools/export_mesh.gd` — `_coletar()` guarda também a transformação
de **antes da Armature** e usa essa para malha skinnada.

**Como evitar de novo:** malha e esqueleto do Meshy vivem em espaços
**diferentes**. Para a malha, transformação de antes da Armature; para o
esqueleto, a basis do driver. Esta é a **quarta** aparição do Z-up neste projeto.

---

## 2026-08-07 — Exportação pela metade: trabalho dentro de pipe morre por SIGPIPE

**Sintoma:** o lançador do editor preparava os dados na primeira execução, mas só
os **rigs** apareciam. Os 28 clipes não eram gerados — e o log não acusava erro
nenhum.

**Causa raiz:** coloquei as duas exportações num subshell **canalizado para
`zenity --progress`**, para mostrar a barra. Quando a janela do zenity fecha (ou
sequer abre), o pipe quebra e o `echo` seguinte mata o subshell com **SIGPIPE** —
exatamente entre a primeira exportação e a segunda.

**Evidência:** log terminando em `RIGS EXPORTADOS: 6`, sem nenhuma linha da
exportação de clipes e sem mensagem de erro. Depois da correção:
`RIGS EXPORTADOS: 6` **e** `CLIPES EXPORTADOS: 28`.

**Correção:** `tools/anim_editor/abrir.sh` — as exportações rodam fora de
qualquer pipe; o aviso virou um `notify-send` solto. A verificação passou a
conferir os **arquivos gerados**, não o código de saída do pipeline.

**Como evitar de novo:** janela de progresso é só aviso. Trabalho nunca depende
dela, e o sucesso se mede pelo artefato produzido.

---

## 2026-08-07 — Rig skinnado exportado deitado e espalhado pelo chão

**Sintoma:** no editor de animação em Python, os personagens voxel montavam
certo, mas a Nami (e os outros modelos Meshy) viravam caixas soltas espalhadas
rente ao chão.

**Causa raiz:** duas coisas erradas de uma vez na exportação. Os proxies criados
pelo `SkeletonDriver` são **irmãos soltos** sob o `model_root` — o `position`
deles é **global**, não local ao papel-pai — e vivem no espaço do **esqueleto**,
que nos modelos Meshy é **Z-up**. Exportei `n.position` cru, como se fosse local
e Y-up.

**Evidência:** depois da correção, `Torso` y=1,185, `Head` +0,122 acima,
`Thigh_R` −0,36 abaixo do torso, `Shin_R` −0,36 abaixo da coxa — proporções
anatômicas. Antes, tudo se acumulava perto de y=0.

**Correção:** `tools/export_rig.gd` — no caminho skinnado, aplicar a basis
`_axis` do driver e subtrair a posição do papel-pai, usando
`SkeletonDriver.RIG_PARENT` (não dá para caminhar a árvore de nós, porque não
existe hierarquia entre os proxies).

**Como detectar de novo:** abrir o editor e olhar. Personagem deitado ou
espalhado = conversão de espaço, não cinemática. É a **terceira** vez que o Z-up
dos modelos Meshy morde neste projeto — ver as duas entradas anteriores.

---

## 2026-08-06 — Tela cinza ao abrir o singleplayer no clone do GitHub

**Sintoma:** o usuário baixou o repositório em outro computador; o menu abre, mas
ao entrar no singleplayer a tela fica **cinza permanente**.

**Causa raiz:** ao publicar, coloquei `.godot/` no `.gitignore` (150 MB de cache
regenerável). Dentro dela mora o `global_script_class_cache.cfg`, que registra
todos os `class_name` do projeto. Sem ele, **todo script que cita `MapBuilder`,
`Hud`, `TreeScatter` etc. falha ao parsear** — o `Main.gd` inteiro não carrega, a
cena fica sem script, e então não há mapa, nem player, nem câmera. O Godot desenha
uma cena 3D sem câmera com a clear color padrão: cinza.

**Evidência:** clonei o repo para `/tmp` e rodei — reproduziu na hora:

```
SCRIPT ERROR: Parse Error: Identifier "MapBuilder" not declared in the current scope.
ERROR: Failed to load script "res://Main.gd" with error "Parse error".
```

Depois do `--editor --quit` (que gera o cache): **0 erros**, modelo carrega normal.

**Descartado:** um diagnóstico externo atribuiu o cinza a um frame sem câmera
seguido de congelamento do `MapBuilder` com "2601 iterações / 7.800 nós". Não
procede: `OBSTACLE_COUNT = 90`, e `MapBuilder.build()` é chamado **direto no
`_ready()`** ([Main.gd:28](../Main.gd)), não dentro do `call_deferred`. O cinza
não é um frame — é permanente, porque o script nunca carregou.

**Correção:** `setup.sh` (importa assets + gera o cache), chamado
**automaticamente** por `jogar.sh`/`servidor.sh` quando o cache não existe, e
`find_godot.sh` — porque os scripts também tinham o caminho do Godot e do projeto
chumbados para a máquina do autor, o que quebraria em qualquer outro computador.

**Como detectar de novo:** clonar para uma pasta limpa e rodar. Se aparecer
`Parse Error: Identifier "<algum class_name>" not declared`, é o cache faltando.

---

## 2026-08-06 — Cadência da marcha: usei 2π onde era π

**Sintoma:** pé patinando no chão durante a caminhada, mesmo com a IK de pé.

**Causa raiz:** para o pé não deslizar, ele tem que recuar exatamente na
velocidade do corpo durante o apoio. Cada perna fica em apoio **metade** do ciclo,
e nessa metade o corpo avança **uma** passada — logo `ω = π·v/passada`. Eu usei
`2π`, o que dobra a cadência. Além disso a trajetória do pé no apoio precisa ser
**linear**: com senoide o pé varre rápido no meio e devagar nas pontas, enquanto o
corpo avança a velocidade constante — deslize garantido.

**Evidência:** com `2π` + senoide, o pé recuava a 2,2 m/s contra 4,2 m/s do corpo.
Com `π` + linear: **4,20 vs 4,20 — deslize 0%**.

**Correção:** `_passada()` e o avanço de fase em `ProceduralAnimator.update()`;
trajetória linear no apoio em `_perna_ik()`.

**Como detectar de novo:** `tools/dev_tests/test_walk_run.gd` compara
`(passada/π)·ω` com a velocidade do corpo.

---

## 2026-08-06 — Pé de apoio flutuando: bob por fórmula não fecha

**Sintoma:** mesmo com a IK, a altura do pé de apoio variava 2-9 cm ao longo do
ciclo.

**Causa raiz:** as rotações das juntas passam por um filtro de suavização
(`STIFFNESS`), mas eu calculava a subida do quadril por **fórmula**. Filtrar um
ângulo não é o mesmo que filtrar a altura resultante, então os dois nunca
cancelavam. Aumentar a rigidez reduzia mas não zerava.

**Correção:** inverter a lógica — `_bob_dos_pes()` **mede** a pose que de fato
saiu (já filtrada) e ajusta o quadril para o pé mais baixo encostar sempre na
mesma altura. E esse ajuste **não pode ser filtrado de novo**, senão reintroduz o
atraso que ele existe para cancelar.

**Evidência:** variação da altura do pé de apoio caiu para **0,0000**.

**Como detectar de novo:** `test_walk_run.gd`, item "altura do pé de apoio varia".

---

## 2026-08-06 — Ninguém planta o pé no chão ao andar (RESOLVIDO)

**Sintoma:** o personagem parece flutuar / quicar em vez de pisar. Visível na
gravação lateral do Barba Negra.

**Causa raiz:** `_locomotion` dobra os **dois** joelhos com o mesmo padrão, então no
cruzamento do ciclo as duas pernas estão dobradas ao mesmo tempo e o corpo afunda.
Não existe IK travando o pé de apoio no chão — nada garante que sempre haja um pé
plantado.

**Evidência:** profundidade do pé mais baixo em relação ao quadril, ao longo do ciclo:

| modelo | perna | variação | % da perna |
|---|---|---|---|
| blackbeard | 0,523 | 0,092 | 17,6% |
| ace | 0,639 | 0,152 | 23,8% |
| nami | 0,681 | 0,166 | 24,4% |
| crocodile | 0,686 | 0,186 | 27,1% |

Numa caminhada real o pé plantado fica parado e o quadril sobe/desce só ~5% — o
corpo vaulta sobre a perna de apoio. Aqui varia 5× mais.

**Correção:** ainda **não feita**. Precisa de IK de duas juntas por perna, com alvo
no chão durante a fase de apoio.

**Como detectar de novo:** `tools/dev_tests/debug_pisada.gd`. A variação do pé mais
baixo deveria ficar perto de zero.

---

## 2026-08-06 — Barba Negra parece anão (é o modelo, não a animação)

**Sintoma:** na gravação lateral, o tronco e o casaco ocupam quase toda a altura e as
pernas são dois tocos.

**Causa raiz:** proporção do modelo gerado pelo Meshy — a canela mede **0,184**
contra **0,338** da coxa, ou seja **54%**. Numa perna humana as duas são quase iguais.
O casacão cobrindo o quadril piora a leitura.

**Evidência:** comparando os quatro modelos Meshy — nami 88%, crocodile 75%, ace 68%,
**blackbeard 54%**. É o único fora da faixa.

**Correção:** nenhuma no animador — não é bug de animação. As saídas são regerar o
modelo no Meshy com proporção melhor, escalar o osso da canela, ou aceitar como
traço do personagem.

**Como evitar de novo:** antes de culpar o animador por silhueta estranha, medir
coxa/canela do modelo com `tools/dev_tests/debug_pisada.gd`.

---

## 2026-08-06 — Personagem anda ereto, sem inclinar o tronco (regressão minha)

**Sintoma:** reportado pelo usuário — "falta a orientação do corpo do jogador um
pouco para frente, o jogador está andando como se estivesse sempre reto para cima".

**Causa raiz:** ao corrigir o exagero do balanço de braço (entrada abaixo), eu
derrubei o `lean` de `lerpf(0.05, 0.35)` para `lerpf(0.02, 0.06)` **no mesmo
passo** — de 20° para 3°. O balanço estava errado; a inclinação não estava. Reduzi
tudo na mesma proporção em vez de dar alvo próprio a cada constante.

**Evidência:** inclinação média do tronco medida em 3,4° andando, contra os ~10°
que o movimento humano pede.

**Correção:** `lean = lerpf(0.05, 0.17, t)` com `+0.16` no sprint, e a cabeça
compensando `lean * 0.75` (era `0.5`) para o personagem não correr encarando o
chão. Resultado medido:

| | tronco | cabeça (local) | olhar resultante |
|---|---|---|---|
| andando | +9,7° | −7,3° | +2,4° |
| correndo | +18,9° | −14,2° | +4,7° |

**Como evitar de novo:** ao recalibrar um bloco de constantes de uma vez, cada uma
precisa do **seu** alvo. Escalar o bloco inteiro pelo mesmo fator quebra as que
estavam certas. Detectar com `tools/dev_tests/debug_inclinacao.gd`.

---

## 2026-08-06 — Personagem anda com os braços para cima

**Sintoma:** reportado pelo usuário — "a animação de walk e run está estranha e o
personagem está andando com os braços para cima". Confirmado em vídeo.

**Causa raiz:** amplitude do balanço calibrada em valores absurdos no
`ProceduralAnimator._locomotion`. `A_arm = lerpf(0.55, 1.55, speed01)` — e
**1,55 rad = 89°**. Como o braço parte do repouso **pendurado** (elevação −90°),
esses 89° o levavam até quase a **horizontal**. Correndo, o multiplicador `×1.4`
do sprint chegava a **124°**. Coxa e joelho tinham o mesmo exagero, só que menos
perceptível. Não era bug do rig skinnado — afetava voxel e skinnado igualmente.

**Evidência:** elevação do braço (arco-seno do Y da direção ombro→cotovelo) na
velocidade real do jogo:

| | antes | depois |
|---|---|---|
| Base (voxel) | −74° a **−21°** | −77° a −62° |
| Nami (skinnado) | −57° a **−21°** | −59° a −52° |

−21° é o braço quase na horizontal. Referência humana: braço balança ~20° andando
e ~45° correndo; coxa ~25° e ~40°.

**Correção:** `src/anim/ProceduralAnimator.gd`, `_locomotion()` — amplitudes
recalibradas contra movimento humano, com os valores em graus comentados ao lado.
`A_arm = lerpf(0.12, 0.35)` com `×2.2` no sprint; `A_thigh`, `A_knee`, `lean`,
`arm_out` e o giro de ombro na mesma proporção.

**Como detectar de novo:** `tools/dev_tests/debug_amplitude.gd`. A elevação do
braço andando tem que ficar perto de −75°; se chegar perto de −20°, está errado.
Capturas visuais com `tools/dev_tests/captura_anim.gd`.

---

## 2026-08-06 — Medir pose pelos nós-proxy do rig skinnado engana

**Sintoma:** meu diagnóstico disse que a perna da Nami varria **0,0°** enquanto a
do voxel varria 95° — conclusão de que o driver não funcionava.

**Causa raiz:** os proxies criados pelo `SkeletonDriver` só carregam **rotação**;
a posição deles nunca muda. Medir a direção de um membro por
`proxy_b.global_position - proxy_a.global_position` devolve sempre o mesmo vetor.

**Evidência:** ao trocar a medição para `get_bone_global_pose()` dos ossos reais,
convertida pelo `_axis` do driver, os números bateram: **95,2°** na Nami contra
**95,3°** no voxel.

**Correção:** nada no jogo — o erro era do diagnóstico. `debug_amplitude.gd` agora
lê os ossos quando o personagem é skinnado.

**Como evitar de novo:** em personagem skinnado, pose se mede nos **ossos**, nunca
nos proxies. Proxy é entrada do sistema, não saída.

---

## 2026-08-06 — Membros colapsam para dentro do corpo ao animar (modelos Meshy)

**Sintoma:** o usuário gravou o jogo e o Blackbeard ficava perfeito em repouso, mas
ao animar os braços e pernas encolhiam para dentro do tronco. Frames extraídos do
vídeo com `ffmpeg` confirmaram.

**Causa raiz:** o esqueleto dos modelos Meshy AI é **Z-up** — a altura está no eixo
Z (`Hips z=0.717`, `Spine z=1.068`, `Head z=1.219`) e a Armature carrega uma rotação
de −90° em X para corrigir. Os offsets do `ProceduralAnimator` são autorados em
**Y-up** e estavam sendo aplicados direto no espaço do osso, girando nos eixos
errados. Junto disso, o delta era acumulado pela hierarquia dos **ossos** em vez da
do **rig**, e ossos intermediários não mapeados (Shoulder, Spine01, Neck) eram
ignorados no meio da cadeia.

**Evidência:** medindo a anatomia em repouso, o pé saía **acima** do quadril
(`pé y=0.017` contra `quadril y=−0.038`) — anatomicamente impossível. Foi esse
absurdo que denunciou o eixo trocado.

**Correção:** `src/anim/SkeletonDriver.gd`, função `push()`, em 3 passos —
(1) acumular pela hierarquia do RIG (`W[papel] = W[pai] * offset`);
(2) conjugar para o espaço do esqueleto (`d_skel = A⁻¹ · W · A`, com `A` calculada
subindo a árvore até o holder); (3) compor com o repouso global e dividir pela pose
global do pai, percorrendo **todos** os ossos.

**Como detectar de novo:** `tools/dev_tests/test_anatomia_rig.gd`. Ele mede no
espaço do **personagem** — medir no espaço do osso engana por causa do Z-up. Pé
abaixo do quadril e comprimento de membro preservado são os dois critérios.

---

## 2026-08-06 — Todos os `.res` de animação estavam zerados (e sempre estiveram)

**Sintoma:** o estilo "Teste de Animação" mostrava o nome do golpe no HUD, mas o
personagem ficava parado na pose de descanso. Nunca funcionou — não foi regressão.

**Causa raiz:** o importador FBX do Godot (**ufbx**, `fbx/importer=0`) lê **1 chave
só** por osso de membro nos arquivos do Mixamo. Apenas `mixamorig_Hips` recebia
chaves reais (55 de posição, 26 de rotação). O baker então calculava delta zero para
todos os membros e gravava faixas válidas cheias de `Vector3.ZERO`.

**Evidência:** amostragem das 12 faixas de `hurricane_kick.res` em 0%, 25%, 50% e
75% do clipe — todas devolvendo `Vector3.ZERO`. As curvas **existem** no FBX:
`strings` acha 371 `AnimationCurve`, e o Blender importa **520 fcurves**. Os arquivos
regerados bateram byte a byte em tamanho com os antigos, provando que o bake é
determinístico e o problema era anterior.

**Descartado (não resolve):** `animation/trimming=false`,
`animation/remove_immutable_tracks=false`, `callback_mode_process = MANUAL` no mixer,
`advance()` no lugar de `seek()`.

**Correção:** passo novo de conversão **FBX → glTF pelo Blender headless**
(`tools/fbx_to_glb.py`), e o baker passou a ler `.glb` via `GLTFDocument`
(`tools/bake_mixamo.gd`). O Godot lê glTF com **57 chaves por osso**.

**Como detectar de novo:** amostrar as faixas do `.res` em vários instantes. Se
derem todas zero, o clipe está vazio. `BAKE FINAL: ok=N fail=0` **não** prova nada —
o baker considera sucesso um arquivo estruturalmente válido, mesmo zerado.

---

## 2026-08-06 — `root_node` errado no baker fazia o mixer ignorar todas as faixas

**Sintoma:** nenhuma faixa de osso resolvia ao tocar o clipe durante o bake.

**Causa raiz:** o baker fazia `ap.root_node = ap.get_path_to(skel.get_parent())`, mas
as faixas do glTF são `Armature/Skeleton3D:<osso>` — relativas à **raiz da cena**,
não ao pai do esqueleto.

**Evidência:** `AnimationMixer: couldn't resolve track: 'Armature/Skeleton3D:mixamorig_Hips'`.

**Correção:** `ap.root_node = ap.get_path_to(scene)` em `tools/bake_mixamo.gd`.

**Como detectar de novo:** o aviso `AnimationMixer: couldn't resolve track` no
console. Ele é fácil de perder no meio do log do bake, e **não** faz o bake falhar —
o `.res` sai zerado com `ok=N fail=0`. Ao mexer no baker, olhar o log inteiro.

---

## 2026-08-06 — `get_bone_global_pose()` fica obsoleto após `seek()` em headless

**Sintoma:** durante o bake, a pose do osso não mudava com o tempo — devolvia sempre
o valor do `t=0`, mesmo variando o `seek`.

**Causa raiz:** num script `extends SceneTree` sem frames rodando, o `Skeleton3D` não
recalcula as poses globais depois do `seek()` do AnimationPlayer. As poses **locais**
(`get_bone_pose`) atualizam na hora; as globais, não.

**Evidência:** amostrando `mixamorig_RightUpLeg` em t=0,0 / 0,4 / 0,8 / 1,2 s, a pose
local devolvia exatamente `(-1.141564, 0.277879, 2.344162)` nos quatro instantes.
Trocar `seek()` por `advance()` e pôr o mixer em `ANIMATION_CALLBACK_MODE_PROCESS_MANUAL`
não mudou nada.

**Correção:** compor a pose global à mão subindo a cadeia de pais pelas poses locais
(`_global_pose_basis` em `tools/bake_mixamo.gd`).

**Como detectar de novo:** amostrar o mesmo osso em instantes diferentes do clipe. Se
o valor repetir idêntico, a pose global está congelada — não é o clipe que está vazio.

---

## 2026-08-06 — Diagnóstico errado: acusei um rig que nem executava

**Sintoma:** afirmei com confiança que Base e Buggy estavam num rig quebrado, sem
cotovelo nem joelho.

**Causa raiz:** eu **li** `VoxelMeshes.build_buggy` e assumi que ela rodava. Não
verifiquei o caminho de execução: `CharacterBuilder.build_character` checa o `.scn`
**antes** de cair nas meshes voxel, e os `.scn` existem — então aquela função é
código morto.

**Evidência:** dump real dos modelos deu **13/13 papéis** em `base.scn`, `base.glb`,
`buggy.scn` e `buggy.glb`.

**Correção:** nada no código — era diagnóstico, não bug. O que mudou foi o método.

**Como evitar de novo:** antes de acusar uma função, confirmar qual **branch
realmente roda**. Ler o corpo da função não prova que ela é chamada.

---

## 2026-08-06 — Armadilhas de ambiente que custaram tempo

Quatro tropeços de ferramenta/configuração, cada um com causa e conserto.

### `godot` e `blender` não estão no PATH
**Sintoma:** `bash: godot: comando não encontrado` — o comando falha silenciosamente
dentro de um pipeline maior e o passo seguinte roda com dados velhos.
**Causa raiz:** os binários são baixados à mão, não instalados por pacote.
**Correção:** usar o caminho completo —
`/home/gabriel-bitti/Downloads/Godot_v4.6.3-stable_linux.x86_64` (o mesmo do
`jogar.sh`) e `/home/gabriel-bitti/opt/blender-5.2.0-linux-x64/blender`.
**Como detectar:** `which godot` vazio.

### Projeto sem git e sem backup
**Sintoma:** nenhum — o risco só aparece depois de perder algo.
**Causa raiz:** `skills-one-piece` não é repositório git e não há cópia.
**Correção:** antes de qualquer passo que sobrescreve arquivos em massa (o bake
sobrescreve 28 `.res`), conferir tamanho/hash antes e depois. Foi assim que confirmei
não ter destruído os `.res` antigos.
**Como detectar:** `git rev-parse --is-inside-work-tree` falhando.

### `extends SceneTree` precisa de `await process_frame`
**Sintoma:** `ERROR: Condition "!is_inside_tree()" is true. Returning: Transform3D()`
e todas as medições saem zeradas.
**Causa raiz:** em `_init()` a árvore de cena ainda não está viva, então
`global_position` não vale.
**Correção:** `func _init(): _run()` + `func _run(): await process_frame` antes de
qualquer medição.
**Como detectar:** o próprio erro acima no console — não ignorar, ele invalida o teste.

### Blender 4.4+ trocou a API de Action
**Sintoma:** `AttributeError: 'Action' object has no attribute 'fcurves'`.
**Causa raiz:** o sistema de *slots* substituiu `Action.fcurves` por
`layers/strips/channelbags`.
**Correção:** helper que tenta `act.fcurves` e cai para a travessia de
layers/strips/channelbags (`contar_fcurves` em `tools/fbx_to_glb.py`).
**Como detectar:** o `AttributeError` — e vale checar a versão antes de assumir a API.

### `class_name` novo derruba o jogo inteiro em TELA CINZA
**Sintoma:** clicar em JOGAR SINGLEPLAYER "não faz nada". O menu some, e fica uma
tela cinza. Parece bug do botão — não é.

**Causa raiz:** um `class_name` só existe se estiver no
`.godot/global_script_class_cache.cfg`, e esse cache **só é regenerado por
reimportação** (`--editor --quit`). Quando a Fase 2 da partição do Player criou
`class_name CameraRig`, o cache seguiu velho. Aí:

```
Parse Error: Could not find type "CameraRig" in the current scope.
Compile Error: Failed to compile depended scripts.
Invalid call. Nonexistent function 'local_player' in base 'GDScript'.
```

O `Player.gd` não compila; a cena do mundo depende dele; ninguém spawna; não há
câmera. **O clique funcionou o tempo todo** — o que quebrou foi a cena de
destino.

**Por que passou por todos os testes:** minha rotina roda `--editor --quit`
antes da suíte, o que regenera o cache. Ou seja, eu testava sempre no único
estado em que o bug não existe. O `jogar.sh` não roda isso.

**Correção:** `checar_cache.sh` (novo), chamado por `jogar.sh` e `servidor.sh`.
A checagem antiga era `[ ! -f cache ]` — pegava cache **ausente** (clone novo) e
nunca cache **defasado**. A nova compara os `class_name` do fonte com os do
cache e regenera quando falta algum.

**Como detectar:** rodar o jogo e procurar `Could not find type` /
`Failed to compile depended scripts` no console. Um `grep -c "NomeDaClasse"
.godot/global_script_class_cache.cfg` valendo 0 confirma.

**Lição de método:** *toda* fase seguinte da partição do Player cria classe
nova. Um bug que só aparece fora do ambiente de teste continua sendo um bug —
e preparar o ambiente antes de testar é justamente o que o esconde.

---

## 2026-08-27 — na parede o corpo só olhava para os lados

**Sintoma (relatado pelo dono):** andando pela parede, o personagem ficava sempre
virado para a direita ou para a esquerda.

**Causa raiz:** o MOVIMENTO usava a base da superfície (`frente·f + direita·r`),
mas a FRENTE DO CORPO usava `q.dir` — a direção **horizontal do mundo** —
projetada no plano. Numa parede vertical, `q.dir` do W é exatamente a componente
que a projeção anula: sobravam A e D, e o corpo nunca olhava para onde subia.

Movimento e olhar são a **mesma decisão**; tirá-los de fontes diferentes é a
mesma armadilha das cinco cópias da direção da frente que já custaram caro aqui.

**Correção:** a frente do corpo passou a sair da mesma
`base_da_superficie()` que o movimento, com os mesmos `q.f`/`q.r`.

**Evidência:** produto escalar entre para onde o corpo olha e a direção andada —
`+1,00` nas quatro teclas (para cima, para baixo, esquerda, direita).

**Como detectar de novo:** a asserção testa a frente **por tecla**. A anterior só
verificava que o corpo estava alinhado com a superfície, o que continuava
verdadeiro com o corpo virado para o lado errado.

---

## 2026-08-27 — duas asserções minhas eram INSTÁVEIS (passavam e reprovavam)

**Sintoma:** a mesma sonda dava `24/0` numa execução e `21/3` na seguinte, sem
nenhuma mudança de código.

**Causa raiz:** duas asserções apostavam em TEMPO em vez de esperar CONDIÇÃO.

1. *"nenhum efeito de tela"* exigia soma **exatamente** abaixo de 0,001. Os
   parâmetros do `ScreenFX` chegam a zero por interpolação e ainda têm resíduo de
   milésimos alguns quadros depois: reprovava por `0,0018`.
2. O teste do cancelamento esperava **"25 quadros"** pela carência de 0,25 s — uma
   aposta sobre o tempo de quadro. Quando chegava cedo, o espaço caía dentro da
   carência e **três** asserções caíam juntas.

**Correção:** limiar com folga de uma ordem de grandeza (0,01, bem abaixo do
visível) e espera de sobra no primeiro; espera por **condição**
(`_carencia_parede <= 0`) no segundo.

**Evidência:** três execuções seguidas em `24/0`.

**Como detectar de novo:** teste que oscila sem mudança de código é teste que
mede o relógio, não o programa. **Esperar condição, não contar quadros** — e
limiar de "efeito invisível" não é zero exato.

---

## 2026-08-27 — a direção na parede invertia com 5° de mouse (o bug intermitente)

**Sintoma (relatado pelo dono):** andando na parede o personagem ia "para o lado,
para o lado, para cima e assim por diante". **Não acontecia sempre** — só apareceu
depois de testar várias vezes.

**Causa raiz:** a base da superfície era recalculada TODO QUADRO a partir de
`q.frente` (a frente da câmera) **projetada** no plano da parede. Essa projeção
**degenera** quando a câmera olha direto para a superfície — que é exatamente o
que o jogador faz enquanto anda nela. Medido, numa parede de normal −Z:

```
yaw 175°   |projeção| = 0,087   frente = (−1, 0, 0)
yaw 180°   |projeção| = 0,000   frente =  indefinida
yaw 185°   |projeção| = 0,087   frente = (+1, 0, 0)
```

**Cinco graus de mouse invertem o eixo do movimento.** O W ia para um lado, para
o outro, e para cima quando caía no fallback. A intermitência não era mistério: o
defeito só existe perto desse ângulo.

**Correção:** a base virou **persistente com histerese**. Só se atualiza quando a
candidata está bem condicionada (`|projeção| > 0,35`, ~20° de folga em torno da
degeneração); fora disso, mantém a que já vale, reancorada na normal atual. E a
atualização é por `slerp`, nunca por substituição, para nunca saltar ao cruzar o
limiar.

Perto da degeneração a frente da câmera **não carrega informação** sobre o plano
da parede — congelar uma base boa é melhor que seguir uma ruim.

**Evidência:** com a câmera oscilando ±8° em torno do ângulo crítico, a maior
virada da base entre quadros vai de **180,0° → 0,0°**.

**Descartado:** trocar a fórmula da projeção (qualquer fórmula degenera no mesmo
ponto) e usar sempre "para cima da parede" (estável, mas tira o controle
relativo à câmera).

**Como detectar de novo:** a sonda mede a **base**, não o deslocamento. ⚠️ A
primeira versão segurava o W por 90 quadros e olhava para onde o corpo ia — mas a
7 m/s isso sobe 10 m, o jogador passa do TOPO do bloco e cai: o teste reprovava
por motivo legítimo e escondia o que se queria medir. A base existe sem o jogador
andar, e é o que o defeito atacava.

---

## 2026-08-27 — subir a parede não animava: o animador só enxerga o plano XZ

**Sintoma (relatado pelo dono):** andando para cima ou para baixo no bloco, a
animação não aparecia — andando de lado, aparecia.

**Causa raiz:** `ProceduralAnimator.update` mede a caminhada com
`Vector2(velocity.x, velocity.z).length()` — só o plano **horizontal do mundo**.
Subir a parede é movimento em **Y**, invisível para essa conta: o ciclo lia
velocidade zero e o corpo ficava parado. De lado funcionava porque aí o
movimento é mesmo horizontal.

**Evidência** (variação da pose do rig, por direção):

```
antes:   para cima ~0     para baixo ~0     para o lado ok
depois:  para cima 3,73   para baixo 4,05   para o lado 3,46
```

**Correção:** o Player decompõe a velocidade na base da **superfície** (quanto é
"para frente", quanto é "para o lado") e a reemite na base horizontal do corpo. O
animador recebe uma caminhada com a magnitude e a repartição certas, sem saber
que existe uma parede.

⚠️ E a base da superfície virou **fonte única** (`base_da_superficie()`), usada
pelo movimento E pela animação — as duas precisam da MESMA decomposição, e duas
cópias divergiriam.

**Como detectar de novo:** a asserção testava só o W. **Uma direção não cobre** —
foi exatamente por isso que o defeito passou.

---

## 2026-08-27 — cancelar a parede gastava um pulo duplo

**Sintoma:** largar a superfície com espaço consumia um geppo, punindo o jogador
por usar o cancelamento que a própria mecânica exige.

**Causa raiz:** zerar `_geppo` dentro de `_soltar_da_parede` não bastava —
`aplicar_pulos` roda **depois**, no mesmo quadro, vê o mesmo `espaco_agora` e
gasta de novo.

**Evidência:** `geppos` = 1 logo após o cancelamento; 0 depois do conserto.

**Correção:** uma marca de um quadro (`_consumiu_espaco`) diz que aquele toque já
foi usado, e `aplicar_pulos` sai sem fazer nada.

**Como detectar de novo:** conferir o CONTADOR depois do cancelamento, não só o
estado. Efeito colateral de ordem entre sistemas não aparece no estado final de
um só deles.

---

## 2026-08-27 — na parede só A e D andavam (a projeção anulava o W)

**Sintoma (relatado pelo dono):** fixado na parede, o jogador só conseguia se
mover para a direita ou esquerda.

**Causa raiz:** o movimento era `q.dir` **projetado** no plano da superfície. Mas
`q.dir` é **HORIZONTAL** — vem do yaw da câmera —, então numa parede vertical o W
produz exatamente a componente que aponta PARA DENTRO da parede, e a projeção a
anula. Sobravam só A e D, que já eram paralelos ao plano.

**Evidência** (deslocamento no plano da superfície, por tecla):

```
com o bug:   W 0,000   S 0,000   A 0,725   D 0,805
corrigido:   W 0,724   S 0,724   A 0,725   D 0,725
```

**Correção:** o movimento passou a ser montado numa **base da superfície** — a
normal é o "para cima", a frente é a da câmera projetada no plano, a direita sai
do produto vetorial. Aí `mov = frente·f + direita·r`, e W anda parede acima.

Projetar a direção final e montar a direção NA BASE CERTA parecem a mesma coisa e
não são: a projeção descarta informação que a base preserva.

**Como detectar de novo:** `medir_camera_e_parede.gd` mede **tecla por tecla**. A
versão anterior olhava só "está na parede" e passava com metade dos controles
mortos.

---

## 2026-08-27 — sem animação na parede: o animador achava que estava caindo

**Sintoma (relatado pelo dono):** nenhuma animação enquanto andava na parede.

**Causa raiz:** `ProceduralAnimator.update` decide entre ciclo de caminhada e
pose de ar pelo parâmetro `on_floor` — e o Player passava `is_on_floor()`, que na
parede é **false**. O animador tocava a pose de queda o tempo todo, e o corpo
ficava parado.

**Correção:** para o animador, a superfície **é** o chão:
`is_on_floor() or _parkour.na_parede()`.

E a velocidade vai **sem a componente de aderência** — aquele empurrão constante
contra a parede é contato, não deslocamento, e faria o ciclo de caminhada rodar
com o jogador parado.

**Como detectar de novo:** a sonda compara as rotações dos membros antes e
durante a caminhada; se não mudam, não há animação.

---

## 2026-08-27 — `global_basis` ortonormalizada DESTRÓI a escala (personagem 2,4× maior)

**Sintoma (relatado pelo dono):** ao colidir com a parede, o personagem
**aumentou de tamanho**.

**Causa raiz:** para orientar o corpo pela normal da superfície eu escrevi
`_char_model.global_basis = ...orthonormalized()`. Uma base ortonormalizada tem
escala **1** — e o modelo do jogador está em **0,4167**. Escrever a base repunha
a rotação e **jogava a escala fora**, deixando o personagem 2,4× maior.

Base carrega rotação E escala juntas; mexer numa sem repor a outra é perder a
outra.

**Evidência** (distância cabeça→pé, invariante à rotação):

```
com o bug:   antes 1,034  →  na parede 2,471   (2,4×)
corrigido:   antes 1,034  →  na parede 1,029
```

**Correção:** `_girar_modelo()` guarda `scale`, faz o slerp em bases
ortonormais e devolve `.scaled(escala)`.

**Como detectar de novo:** `medir_camera_e_parede.gd` mede o tamanho por
**distância entre ossos**, e a asserção reprova a versão com bug.

⚠️ **A primeira métrica que tentei estava errada:** o alcance em **Y do mundo**.
Ele CAI quando o corpo deita na parede — por ROTAÇÃO, não por tamanho — e a sonda
reprovava justamente o conserto. Tamanho se mede com grandeza invariante à
rotação.

---

## 2026-08-27 — a permanência na parede dependia da TECLA

**Sintoma (relatado pelo dono):** era preciso continuar segurando a tecla, quando
o pedido era um toque só.

**Causa raiz:** o estado sobrevivia consultando `_parede_frontal`, que vem de
`_normal_da_parede_escalavel(q.dir)` — **sem direção no teclado ela é ZERO**.
Soltar o W apagava a parede e o jogador caía. O fallback que eu pus "para
robustez" era exatamente o que reintroduzia a dependência que a mecânica veio
eliminar.

**Evidência:** com o W solto, `parede_frontal = (0,0,0)` e o estado caía.

**Correção:** só o que está **sob os pés** decide (um raio, que não olha para o
teclado). Mais alcance (2,0 m), origem do raio deslocada para fora da superfície
— raio que nasce dentro do sólido não reporta acerto — e uma **folga de 0,35 s**
antes de soltar, porque a superfície some por um quadro em quina ou degrau.

**Como detectar de novo:** a asserção "continua sem segurar tecla" agora observa
**180 quadros (≈3 s)**, não meia dúzia. Com poucos quadros ela passava mesmo com
o bug — o jogador só caía depois.

---

## 2026-08-27 — devolver a pose ao "zero" subiu o personagem 0,8 m

**Sintoma:** a cada dash para trás o personagem subia um pouco e ficava lá.

**Causa raiz:** o rolamento de costas move o modelo em Y/Z para girar em torno da
cintura, e no fim eu devolvia `position = 0`. Mas o repouso do modelo **não é
zero**: é **y = −0,80**, porque o rig o abaixa para os pés encostarem no chão.
Devolver a zero SUBIA o corpo 0,8 m.

**Evidência:**

```
repouso:        modelo y = −0,8000
após dash #1:   modelo y =  0,0000   ← subiu, e não voltou
após dash #2..5: 0,0000
```

Depois do conserto: −0,8000 antes e depois dos cinco dashes.

**Correção:** guardar a posição no primeiro quadro do giro e devolver a ELA.

**Como detectar de novo:** a asserção do `medir_dash.gd` comparava com ZERO e por
isso deixou o bug passar; agora compara com a pose de ANTES. **Repouso se guarda,
não se supõe** — é o mesmo erro da escala das raças, onde devolver `Vector3.ONE`
deformaria um rig que nasce com 1,8.

---

## 2026-08-27 — o anel do soco tinha rotação FIXA no mundo

**Sintoma (relatado pelo dono):** "o efeito visual que o clique libera aponta
sempre para a mesma direção".

**Causa raiz:** `Melee._impacto` fazia `m.rotation.x = PI * 0.5` — literalmente
uma rotação fixa. A POSIÇÃO do anel acompanhava o soco; a ORIENTAÇÃO, nunca.
Socar para o norte e para o sul desenhava o mesmo anel virado para o mesmo lado.
A função sequer RECEBIA a direção, embora quem a chamava (`Melee.golpear`) a
tivesse na mão.

**Evidência:** eixo do anel medido em 8 rumos — idêntico em todos antes, `+1,000`
contra a direção do golpe depois.

**Correção:** `_impacto` passou a receber `dir`, e o anel virou DUAS camadas: um
suporte que APONTA (`look_at`) e a malha girada −90° em X (o eixo de um
`TorusMesh` nasce em +Y e precisa virar −Z).

⚠️ **A primeira tentativa compôs uma `global_basis` e não sobreviveu ao tween:**
animar `scale` RECOMPÕE a base a partir de rotação + escala guardadas, e a
decomposição não voltava igual — o anel saía girado, com |dot| oscilando de 0,85
a 0,00 conforme o rumo. Separar apontar de girar resolve porque o tween passa a
mexer só na escala do suporte.

**Como detectar de novo:** `tools/dev_tests/medir_vfx_soco.gd`.

⚠️ **E três armadilhas de MEDIÇÃO, todas no mesmo teste:**
1. media o `−Z` do nó, mas o eixo de um toro é o `+Y` local — e com a rotação
   fixa antiga o `−Z` também apontava para cima, então a sonda dava o MESMO
   número no defeito e no conserto;
2. pegava os anéis dos BONECOS DE TREINO, que socam sozinhos: o resultado variava
   por rumo e não tinha relação nenhuma com o golpe medido — errado e
   convincente. Congelar os bonecos não basta; o que atrapalha é o anel que já
   estava a caminho;
3. o anel nasce com RETARDO, e com espera curta cada célula media o golpe
   ANTERIOR (atraso de exatamente um passo) — o mesmo defeito que a sonda das
   direções das skills já teve.

---

## 2026-08-27 — `SubViewport` sem `own_world_3d` compartilha o mundo da cena

**Sintoma:** o personagem da prévia do menu de Customização aparecia com a ARENA
inteira atrás dele.

**Causa raiz:** `SubViewport` nasce com `own_world_3d = false` e usa o mundo 3D da
cena que o contém. Tudo o que está na partida entra no quadro, e a luz que eu
adicionei ao viewport do menu ilumina o jogo.

**Evidência:** ligando `own_world_3d = true` o fundo passa a ser só a cor do
`Environment` do próprio viewport.

**Correção:** `_viewport.own_world_3d = true`, mais um `WorldEnvironment` e uma
`DirectionalLight3D` DENTRO do viewport — sem mundo próprio essas duas vazariam.

**Como detectar de novo:** prévia 3D em menu que mostra cenário do jogo, ou luz
que muda no jogo ao abrir um menu. A sonda confere o campo direto:
`_ok("o viewport tem mundo próprio", menu._viewport.own_world_3d)`.

---

## 2026-08-27 — enquadrar no `_ready` mede a hierarquia AINDA EM REPOUSO

**Sintoma:** a câmera da prévia nascia DENTRO do tronco do personagem; a tela
virava uma parede de cor lisa. Trocar os números da câmera não resolvia — só
mudava para outro lugar errado.

**Causa raiz:** o enquadramento é calculado da caixa do modelo, e a caixa vem de
`global_transform` de cada malha. O Godot **só propaga as transformações depois
que a árvore processa**. Calculando dentro do `_ready`, a hierarquia ainda está em
repouso e a união das AABBs sai errada.

**Evidência:** adiando um quadro, a caixa medida passou a ser
`pos (-0,9, 0, -0,36) tam (1,8, 3,6, 0,72)` — coerente com o modelo — e o
personagem apareceu inteiro no quadro.

**Descartado:** ajustar posição/FOV da câmera na mão (só troca um erro por
outro), e `force_update_transform` (resolve o sintoma sem explicar a ordem).

**Correção:** `await get_tree().process_frame` no `_ready` antes de enquadrar. E o
enquadramento é CALCULADO da caixa, não fixo — assim trocar de personagem ou
mudar a proporção do rig continua enquadrando.

**Como detectar de novo:** qualquer conta que use `global_transform` de nós
recém-adicionados. Se o resultado for absurdo mas o código parecer certo,
desconfie da ORDEM antes de desconfiar da conta.

---

## 2026-08-27 — ler DADO de uma classe pesada arrasta os autoloads dela

**Sintoma:** `SCRIPT ERROR: Compile Error: Identifier not found: FruitNet` ao rodar
a sonda do menu de Customização. Nada no menu fala de rede.

**Causa raiz:** o menu lia a paleta em `Player.CORES` — três cores. Referenciar
`Player` puxa o script inteiro (2.400 linhas) e, com ele, os AUTOLOADS de que
depende. O autoload `FruitNet` não existe ainda no momento em que uma sonda com
`-s` compila, e a compilação falha em cadeia.

**Evidência:** o erro não aparece em sondas anteriores nem no `master` sem as
mudanças — apareceu junto com o primeiro `Player.CORES` fora do `Player`.

**Correção:** a paleta saiu para `src/customizacao/Paleta.gd`, dado puro sem
dependência nenhuma. `Player.CORES` virou apelido (`const CORES := Paleta.CORES`),
então as dezenas de usos não mudaram e a fonte continua sendo uma só.

**Como detectar de novo:** erro de compilação citando um autoload em código que
não tem nada com o assunto dele. A pergunta certa não é "por que falta o
autoload", é **"por que esta tela depende da classe mais pesada do projeto para
ler dado?"** — dado deve morar em script que não depende de nada.

⚠️ E `--check-only --script <arquivo>` NÃO serve para diagnosticar isso: ele não
carrega autoloads, então acusa o mesmo erro em código que funciona. Para saber se
é real, use `tools/dev_tests/checar_compilacao.gd`, que roda no projeto completo.

---

## 2026-08-27 — o `:=` do GDScript não infere sobre Variant, e isso pegou 4 vezes

**Sintoma:** `Parse Error: Cannot infer the type of "X" variable because the value
doesn't have a set type.` O script inteiro deixa de carregar.

**Causa raiz:** iterar um `Array` ou `Dictionary` **não tipado** dá um `Variant`, e
qualquer método chamado nele devolve `Variant` — que o `:=` não consegue inferir.
Os quatro casos do mesmo dia:

```gdscript
for d in [Vector2i(6,0), ...]:      var vx := x + d.x            # ❌
for chave in dicionario:            var partes := chave.split("/")  # ❌
for x in _todos(no):                var pai := x.get_parent()     # ❌
```

Dois eram meus e dois de um agente — ou seja, não é distração de uma pessoa, é a
forma da linguagem.

**Evidência:** `medir_direcoes_skills.gd` (do agente) não carregava; três sondas
minhas quebraram na primeira execução com a mesma mensagem.

**Correção:** tipar a variável, ou o laço:

```gdscript
var passos: Array[Vector2i] = [...]      # laço tipado resolve na origem
var partes: PackedStringArray = String(chave).split("/")
var pai: Node = (x as Node).get_parent()
```

**Como detectar de novo:** o erro é de PARSE, então `--check-only` no arquivo já
denuncia — não precisa subir o jogo. Vale rodar antes de qualquer sonda nova:

```bash
godot --headless --path . --check-only --script res://tools/dev_tests/<sonda>.gd
```

**⚠️ E a armadilha vizinha, que custa mais caro:** pôr `await` numa função chamada
SEM `await` não dá erro nenhum — a função simplesmente ENCERRA ali, e o resto não
roda. Foi assim que uma sonda passou de 33 para 31 asserções em silêncio, e eu
quase tomei o placar menor por bom. Ver a entrada da conferência do rig no Blender:
teste que encolhe sozinho é primo do teste que compara o erro consigo mesmo.

---

## 2026-08-27 — as "discordâncias colisão↔visual" eram da SONDA, não do jogo

**Sintoma:** de 1.851 pontos de chão conferidos, 4 tinham o raio acertando a
`Plataforma` enquanto a tela mostrava o vazio. Parecia rasgo de renderização na
beirada dos buracos.

**Causa raiz:** duas falhas somadas, ambas da sonda `medir_blocos_sumindo.gd`.

**1. Limiar absoluto de cor.** O chão era pintado de verde puro e o teste exigia
`g > 0,35`. A névoa escurece o chão distante bem abaixo disso: a ~130 m o verde
puro chega como **(0,00 · 0,22 · 0,04)** — inconfundivelmente verde, e reprovado.
Isso acusava "o chão sumiu" na borda externa da plataforma, longe da câmera.

**2. Sem margem de silhueta.** Raio e rasterizador decidem coisas diferentes: o
raio acerta se a linha CRUZA o sólido; o pixel é pintado por COBERTURA, e na
quina a cobertura é parcial. Some a isso o `Contorno`, que pinta uma linha escura
**por cima** da silhueta — os últimos pixels da beirada da laje são contorno, não
chão. Discordar a milímetros da quina é o comportamento correto dos dois.

**Evidência:** os 3 casos que sobraram após corrigir (1) eram todos idênticos —
`y = −1,9946`, ou seja **5,4 mm** do canto de baixo (`PLATFORM_THICK = 2,0`), com
a mesma cor, sempre no rumo 100°. Consistência assim é geometria, não acaso. A
vizinhança fechou: no pixel discordante, **2 px para a esquerda** ou **4 px para
cima** já acham chão desenhado, e a cor lida é **(0,00 · 0,00 · 0,03)** — preto de
contorno.

**Descartado:** rasgo na face lateral da laje, culling da face, desencontro entre
a caixa de colisão e a instância do MultiMesh (as duas usam `Vector3(w,
PLATFORM_THICK, CELL)` na mesma origem — conferido no código).

**Correção:** `tools/dev_tests/medir_blocos_sumindo.gd` — detecção de chão por
**dominância de canal** em vez de limiar absoluto (não depende do brilho, logo
atravessa a névoa), mais uma **guarda de silhueta**: só conta como "sumiu" se
nenhum chão for desenhado num raio de 6 px. Nenhuma mudança no jogo.

**Como detectar de novo:** a sonda agora fecha em 1.851 pontos de chão e 3.880 de
bloco com **zero** discordâncias. Regra que fica: **sonda que compara raio com
pixel precisa de margem na silhueta** — sem ela, ela acusa a própria borda da
geometria. E **limiar absoluto de cor não sobrevive à névoa**; dominância, sim.


---

## 2026-08-27 — o chão escurecia em faixa porque o shader ESCREVIA `ALPHA`

**Sintoma:** o chão ganhava faixas escuras que mudavam ao girar a câmera. No mesmo
quadro, chão plano e mesma luz: metade esquerda 29,8% escurecida, direita 0,5%.

**Causa raiz:** `src/fx/shaders/cel.gdshader` fazia `ALPHA = cor.a;`. No Godot 4 a
transparência é decidida em tempo de **COMPILAÇÃO** — basta o shader **escrever**
em `ALPHA`, mesmo que o valor seja sempre 1,0, para o material inteiro ir para o
pipeline de transparência. Ali ele sai do prepass de profundidade e passa a ser
iluminado por outro caminho. `cor.a` era 1,0 nos **100 materiais** que usam o
shader (auditado em runtime): a transparência nunca foi usada, só o custo dela.

**Evidência:** bisseção, mesma cena/câmera/luz, linha de leitura validada por raio
(560 de 560 pixels acertam a `Plataforma`, zero blocos, zero céu):

| variante | esquerda |
|---|---|
| cel do jogo | 29,8% |
| mesmo `fragment()`, `light()` REMOVIDO | 29,8% |
| sem `light()` e sem grade | 29,8% |
| sem `render_mode` | 29,8% |
| **só sem a linha `ALPHA = cor.a;`** | **0,0%** |
| `StandardMaterial3D` (controle) | 0,5% |

Antes/depois em 96 casos (8 rumos × 3 posições × 2 alturas × 2 energias de sol):
rumo 90° 27,1%→0,7%; 135° 46,4%→1,1%; 225° 59,6%→1,8%. Nenhum caso piorou.

**Descartado (todos medidos, nenhum era):** cascata de sombra, grade do chão,
quantização do cel, contorno de tela, SSAO, névoa/perspectiva aérea, o `light()`
inteiro (removê-lo não muda nada) e o `render_mode`.

**Correção:** `src/fx/shaders/cel.gdshader` — a linha `ALPHA = cor.a;` removida.
Uma linha. Se algum dia precisar de superfície translúcida, faça uma VARIANTE do
shader; devolver a linha custa o chão inteiro.

**Como detectar de novo:** `tools/dev_tests/baseline_chao.gd` (esquerda deve ficar
abaixo de 5%) e `tools/dev_tests/checar_residuo_chao.gd`, que separa artefato de
sombra legítima. Regra geral: **no Godot 4 o que liga um caminho de renderização é
o shader ESCREVER no campo, não o valor escrito** — vale para `ALPHA`, `NORMAL`,
`AO` e afins.

---

## 2026-08-27 — minha métrica comparava metades da TELA sem conferir o que havia nelas

**Sintoma:** hipóteses eram "descartadas" uma após a outra sem que o número mudasse,
e o defeito parecia não ter causa. Também produziu a contradição *"trocar o material
resolve, mas parâmetro nenhum reproduz"*.

**Causa raiz (erro meu, de método):** eu media o escurecimento varrendo uma linha
de pixels e comparando a metade esquerda com a direita da TELA — **sem nunca
verificar se as duas metades mostram a mesma coisa**, e calculando a média sobre
pixels que incluíam os próprios escurecidos. Duas consequências:
1. bloco, céu e chão entravam na mesma conta;
2. **sombra de bloco legítima contava como defeito**, porque qualquer pixel abaixo
   de 92% da média era marcado.

Havia **duas causas sobrepostas** nos quadros medidos — o artefato de transparência
E sombra de verdade. Por isso nenhum toggle isolado zerava o número: cada um matava
só metade. Isso "inocentou" grade, SSAO e sombra cedo demais, e as três tiveram de
ser reabertas.

**Evidência:** com a métrica corrigida (cada pixel classificado por raio ANTES de
entrar na conta), a mesma cena mostra 560/560 pixels de `Plataforma` nas duas
metades — a comparação passou a valer. E desligando a sombra depois da correção,
os resíduos caem de 32%/40%/50% para 0,7%/0,8%/1,6%, provando que eram sombra.

**Correção:** `tools/dev_tests/baseline_chao.gd` classifica cada pixel por raio e
conta escurecimento só onde o pixel é mesmo o chão.

**Como detectar de novo:** antes de aceitar um veredito de "inocente", conferir se
a métrica olhava para o lugar certo. **Comparar número de um teste com número de
outro só vale se a métrica e a região forem as mesmas.** Corolário já pago duas
vezes: controle tem que ter o mesmo brilho do caso — testar com albedo branco não
prova nada, porque o branco satura no tonemap e esconde a variação.

---

## 2026-08-27 — eu diagnostiquei "o boneco desmonta" olhando pixel ampliado

**Sintoma:** vendo o vídeo do dono, afirmei que o personagem colapsava em
movimento — tronco tombado ~40°, pernas dobradas, cabeça sumida.

**Causa raiz (erro meu):** li "desmontado" num modelo voxel de poucos polígonos,
recortado e reescalado de um vídeo de 1316×736. Baixa resolução, pose inclinada e
um modelo sem cabeça destacada bastam para parecer quebrado. **Impressão sobre
pixel ampliado não é diagnóstico.**

**Evidência:** varrendo toda a faixa de mira do jogo (`_pitch` de +0,5 a −1,2),
parado e correndo: parado tronco 1,2°–2,6° e altura do rig 99,6%; correndo tronco
14,7° e altura 88,1%–88,4%, **sem variação por pitch**. A pose de corrida é uma
corrida agachada normal.

**Descartado no caminho:** os 4 clipes do combo M1 não têm faixa de rotação de
tronco (0,0° nos três eixos); `ProceduralAnimator.trigger_hitstop()` **nunca é
chamado** (o tremor é código morto); `balanco_torso` dá no máximo 6,9°; troca de
fruta, 2,7°.

**Correção:** nenhuma no código — não havia defeito. O alarme foi retirado.

**Como detectar de novo:** `medir_rig_por_pitch.gd`, `medir_corpo_encolhe.gd`,
`medir_tronco_combinado.gd`. Antes de afirmar que algo visual está quebrado,
medir a geometria — não descrever a imagem.

---

## 2026-08-26 — o portão visual do projeto nunca usou a câmera do jogo

**Sintoma:** defeitos visíveis em jogo (faixas ao girar a câmera) nunca apareciam
na bateria, que tem cinco cenas fixas justamente para isso.

**Causa raiz:** `tools/dev_tests/captura_visual.gd` **cria uma `Camera3D` própria**
e a posiciona na mão. Ele nunca passa pelo `CameraRig` (pivô → Ombro → SpringArm →
Camera3D), que é a câmera de verdade. Todo defeito que dependa da câmera do jogo
era invisível para a bateria **por construção** — e "olhar para trás" é exatamente
o que aquela sonda não sabe fazer.

**Evidência:** o defeito das faixas (29,8% de escurecimento) não aparece em
nenhuma das cinco cenas e aparece no primeiro rumo da sonda nova.

**Correção:** `tools/dev_tests/captura_giro.gd` — 8 rumos e 3 inclinações, pela
câmera do jogo, com entrada simulada por `InputEventKey` de verdade (o
`move_frame.gd` lê `Input.is_physical_key_pressed`, então tecla de mentira não
funciona).

**Como detectar de novo:** ao criar sonda visual, perguntar se ela passa pelo
mesmo caminho que o jogador vê. Sonda que monta o próprio caminho testa a si mesma.

---

## 2026-08-26 — "blocos invisíveis" não era descarte de renderização

**Sintoma:** o dono relatou blocos ficando invisíveis em jogo.

**Causa raiz:** nenhuma no culling — a explicação confortável estava errada. Culling
é o suspeito natural porque não gera erro nenhum: o objeto simplesmente não está lá.

**Evidência:** os 77 blocos pintados de vermelho puro; para cada um,
`unproject_position` + raio de oclusão + verificação de vermelho no pixel. **3.879
casos em 6 postos de observação, incluindo alturas de pulo (y = 8, 12 e 16): zero
sumidos.** Pintar de vermelho é o que tira a ambiguidade — bloco cinza contra chão
cinza é indistinguível por cor, e foi por isso que olhar capturas não decidia nada.

**Descartado:** culling por distância, por frustum e por altura de câmera.

**Correção:** nenhuma — não havia o defeito procurado. Achado lateral REAL, ainda
aberto: de 1.851 pontos de chão, **4** têm o raio acertando a `Plataforma` enquanto
a tela mostra o vazio; três deles em y ≈ −1,99, a face LATERAL da laje vista
através de um buraco.

**Como detectar de novo:** `tools/dev_tests/medir_blocos_sumindo.gd`.


## 2026-09-01 — tirar a Mera de `CARREGAVEIS` apagou o Z inteiro, sem erro nenhum

**Sintoma:** o dono pediu para "eliminar a necessidade de tempo para desferir ataques
de frutas na Mera Mera no Mi". Removida a Mera da lista de carregáveis, o Z deixou de
ter QUALQUER efeito: nenhuma pistola, nenhuma rajada, nenhuma mensagem no console.

**Causa raiz:** o Z da Mera só existia pelo caminho da CARGA. O `MeraZChargeNode` não
era só um relógio — era ele quem sacava as pistolas (`empunhar_pistolas_mera`) e quem
chamava `iniciar_rajada()` ao completar. O ramo de disparo imediato em `comecar()`
listava apenas `hie_hie`. Tirando a carga sem trazer o saque junto, sobrou um slot que
passa por todas as guardas e não faz nada.

**Por que passou despercebido:** o `test_mera_z_saque` acusou 7 falhas na hora, mas
todas com cara de "teste velho para regra nova" — o texto delas falava em carga, que o
dono acabara de mandar remover. A leitura preguiçosa é aposentar o teste; ele estava
certo e a habilidade é que estava morta.

**Correção:** `mera_mera` entrou na condição da rajada imediata em
`src/player/cast_controller.gd:comecar()`, levando junto o saque (as armas pulam o
coldre e nascem nas mãos) e o temporizador que as esconde ao fim do pente.

**Como detectar de novo:** `tools/dev_tests/test_mera_z_saque.gd`, reescrito para o
novo ciclo, com a asserção de controle `progresso_mera_z() == 0.0` — se a barra de
carga voltar, ela acusa.

**Lição:** quando um pedido remove uma ETAPA, procure o que mais morava dentro dela.
E teste que falha logo após uma mudança pedida merece leitura antes de conserto.

## 2026-09-01 — citar um `class_name` global num script `-s` zera os `preload` do Player

**Sintoma:** `test_trava_pos_fruta` jurava que a trava de 5 s não andava, com o console
cuspindo `Invalid call. Nonexistent function 'atualizar' in base 'Nil'` a cada quadro.
Uma réplica do mesmo teste, linha por linha, passava sempre.

**Causa raiz:** o teste citava `CastController.CARREGAVEIS` — o `class_name` GLOBAL —
no corpo do script. Isso obriga o GDScript a resolver a classe durante a compilação do
próprio teste, que roda antes de o projeto subir; nesse caminho as constantes `preload`
do `Player.gd` saem NULAS. Todos os controladores (`_corpo_de_ferro`, `_dash`, `_cast`,
`_melee`…) nascem nulos, `_etapa_estado_de_combate` aborta na PRIMEIRA linha e nenhum
relógio do jogador anda. O jogo real nunca passa por essa ordem de carga.

**Evidência:** mesmo nó, `is_inside_tree()=true`, `is_physics_processing()=true`,
`_corpo_de_ferro=<null>`. Trocado por `load("res://src/player/cast_controller.gd")`,
o mesmo teste foi de 8/10 para 10/10 sem tocar em uma linha de produção.

**Descartado (e caro):** "class_name não registrado, use preload" — migrei 9
controladores do `Player.gd` para `preload` antes de reparar que o `IronBodyController`
JÁ era preload e mesmo assim nascia nulo. A hipótese estava morta e eu não tinha olhado.
Revertido.

**Como detectar de novo:** num teste `extends SceneTree`, `in base 'Nil'` em massa
significa ordem de carga, não bug de produção. Prefira `load()` dentro da função a citar
`class_name` global no corpo do script.

**Lição:** hipótese que explica o sintoma não é hipótese confirmada. O contraexemplo
(`IronBodyController` já era preload) estava a um `grep` de distância, antes da correção.

## 2026-09-01 — `_char_model` não existe mais, e quem o procura falha calado

**Sintoma:** os Iron Punches nasciam (o nó da sequência subia, o teste via o golpe
acender) mas NENHUM braço era clonado. Zero erros no console.

**Causa raiz:** o código seguiu o padrão que já existia no projeto —
`_dono.get_node("_char_model")` seguido de `find_child`. Esse nó não existe: o modelo
mora em `CharacterRoot_<personagem>/SkinPivot/GLBModel_<personagem>/Torso/UpperArm_R`.
`has_node` devolve `false`, a função devolve `null` e o golpe segue em frente sem
braço nenhum — o mesmo silêncio de sempre.

**Achado lateral, ainda ABERTO:** `GuraChargeNode` (`src/player/cast_controller.gd`)
usa exatamente esse caminho morto para pendurar a `SeismicOrb` na mão durante a carga
do X da Gura. Lá também falha calado: a orb da carga simplesmente não aparece.

**Correção:** buscar a partir do próprio jogador (`_caster.find_child("UpperArm_R",
true, false)`), que funciona para qualquer personagem do elenco. E limpar do clone os
filhos que não são braço (`BukiArma_*`, `MeraPistol_*`), senão a sequência de socos
sairia atirando armas pelo mapa.

**Lição:** copiar um padrão do próprio repositório não prova que ele funciona —
prova que ele existe. `has_node` que dá `false` é a forma mais barata de um golpe
inteiro sumir sem log.

## 2026-09-01 — a régua errada: `mira_do_cast()["origem"]` já nasce 1,5 m à frente

**Sintoma:** o teste dos Iron Punches dizia que um alvo "a 1,4 m" não apanhava, com o
golpe medido percorrendo 1,92 m dos 2 m pedidos. Parecia alcance quebrado.

**Causa raiz:** o alvo era posicionado em `mira_do_cast()["origem"] + aim * 1,4`, e
aquela origem já é `global_position + UP + frente * 1,5`. O alvo "a 1,4 m" estava a
quase 3 m do ombro de onde o braço parte. O golpe estava certo desde o começo.

**Correção:** medir a distância a partir do CORPO (`p.global_position + UP * 1.0 + aim
* d`). Com a régua certa, o alvo perto leva os 176 de dano e o alvo a 5 m continua sem
levar nada — que é o controle do "até 2 metros".

**Lição:** a terceira vez nesta mesma sessão em que o defeito estava na medição, não
no jogo (as outras duas: o `class_name` global zerando os `preload`, e o relógio de
parede contra o relógio de física). Antes de mexer no código medido, conferir de onde
a régua parte.

## 2026-09-01 — medir nível numa rampa: a água subiu debaixo da régua

**Sintoma:** o teste da enchente acusava "água pela cintura mata" — o jogador
morria com o nível supostamente na altura do peito.

**Causa raiz:** o teste escrevia `flood_y` UMA vez e esperava 4 s. A água sobe
1,5 m/s por conta própria: no fim da espera o nível estava 6 m acima, com o
jogador submerso por completo. O jogo estava certo; a medida é que descrevia outro
cenário. O log entregou de graça — `nível 7.20, cabeça em 1.60`.

**Correção:** `_manter_nivel(y, segundos)`, que reescreve a linha d'água a cada
quadro. Com ela: água pela cintura não mata nem em 4 s, aos 1,5 s submerso ainda
está vivo, e passados os 3 s ele morre.

**Lição:** medir um valor que o próprio sistema move exige SEGURAR o valor, não
escrevê-lo uma vez. É a quarta medição errada da sessão — e, como nas outras três,
o número que denunciava o erro já estava impresso no log.

## 2026-09-01 — desempenho da enchente: V-Sync escondendo o custo, e a hipótese cara

**Sintoma:** o dono pediu para "garantir o bom desempenho quando a água começar".
A primeira medição deu **6,94 ms nos três casos** — arena seca, água subindo e
câmera submersa, todos idênticos.

**Causa raiz da medida inútil:** V-Sync. 6,94 ms é 144 Hz cravado, o teto do
monitor. Um número que não se move quando a cena muda não está medindo a cena.
Com `window_set_vsync_mode(VSYNC_DISABLED)` a diferença apareceu na hora: +13,5 %.

**Segundo defeito da mesma medição:** o caso "pior" (câmera submersa) custava
MENOS que o caso anterior — impossível se houvesse água na tela. Havia: o jogador
se afogava em 3 s, a fase terminava, a água sumia e a medição do pior caso estava
medindo a arena seca. Corrigido mantendo um segundo corpo vivo em cena, e
imprimindo `alagando=true/false` **junto de cada número** — uma medida de "durante
a enchente" feita com a enchente encerrada é pior que medida nenhuma, porque
parece boa notícia.

**Hipótese errada, e cara:** apostei que o custo era a `BoxMesh` sendo regerada a
cada quadro (mexer em `size` reconstrói os vértices). Troquei por caixa unitária +
escala e medi de novo: **+11,7 % → +12,3 %**, ou seja, nenhum ganho. O custo real
era a ILUMINAÇÃO POR PIXEL de uma superfície de 200 × 200 m;
`SHADING_MODE_UNSHADED` levou de +13,5 % para +2,1 %.

**O controle que fechou o diagnóstico:** medir a mesma fase com a água
ESCONDIDA. Sobrou +0,3 % — logo, a lógica (subida, varredura, afogamento) não
custa nada e o problema era 100 % de desenho. Sem esse controle eu teria seguido
otimizando a conta.

**Lição:** eu havia deixado no código um comentário afirmando que a troca da malha
custava +11,7 %, medido — e não custava nada. Comentário que declara medição tem
de citar a medição que sobreviveu à correção, senão vira folclore com aparência de
dado. Corrigido no arquivo.

## 2026-09-01 — a água subia em degraus, e o teste que reprovava a solução certa

**Sintoma:** o dono pediu para "garantir que a água suba gradualmente". A primeira
medição dizia GRADUAL — sem recuos, sem saltos. Mas dois números na mesma tabela
diziam o contrário: **menor passo 0,0000 m, maior 0,0250 m (2,4× a média)**.

**Causa raiz:** `flood_y` só muda no `_physics_process` (60 Hz) e a tela desenha a
~144 Hz. `AguaDaArena` copiava o valor cru, então metade dos quadros não subia
nada e a outra subia o dobro — degraus de 2,5 cm. O veredito "GRADUAL" era do meu
critério, que só olhava saltos grandes e recuos.

**Correção:** o nó visual ganhou nível próprio, que sobe por quadro de RENDER e
recebe o valor do servidor como correção amortecida. Passo máximo caiu de 2,4×
para 1,1× a média, com a mesma velocidade total (3,12 m em 300 quadros nos dois).

**Segundo erro, no teste:** o caso "com correção de rede" empurrava o nível a cada
**30 quadros**, que a 144 Hz é uma correção a cada 0,2 s — deriva de 1,5 m/s, coisa
que a rede não produz (`SYNC_INTERVAL` é 0,5 s). O teste estava mais duro que a
realidade. Corrigido para medir em TEMPO, não em quadros. (O estresse ainda
revelou algo real: com `AMORTECIMENTO` em 3/s sobrava resíduo entre pacotes e o
erro acumulado estourava o limite — subido para 8/s.)

**Terceiro erro, no critério:** o veredito exigia "passo máximo ≤ 2× a média" e
reprovava o caso com correção de rede por 0,4 mm. Absorver deriva EXIGE, por
definição, andar um pouco mais depressa por alguns quadros — o critério punia o
comportamento desejado. Trocado por um limite absoluto em metros (10 cm num
quadro), ancorado no que o olho vê: 2,8 cm não se enxerga, meio metro sim.

**Lição:** três defeitos na mesma medição, e nenhum no jogo. Quando um teste
reprova a solução que você acabou de justificar tecnicamente, reveja o critério
antes de mexer no código — mas leia o que ele mediu, porque o estresse exagerado
achou um resíduo verdadeiro no amortecimento.

## 30/09/2026 — juntas do pet deslocadas da pata (corrigido antes da entrega)

Na primeira captura do caranguejo, oito esferas das articulações apareciam flutuando. A malha da junta tinha vértices já deslocados para o joelho, enquanto o animador também posicionava seu nó no joelho: a translação era aplicada duas vezes. A fonte Blender agora cria a geometria da junta na origem local e coloca o nó na posição de repouso. A captura posterior não tem as esferas soltas, e `test_pet_caranguejo.gd` exige centro da AABB local da junta a menos de 0,01 m da origem. O teste físico sozinho tinha passado e não detectava esse defeito; a captura em Godot revelou a causa.

## 2026-10-06 — Espada da história cortava com o dorso e com a face larga

**Sintoma:** o fio não acompanhava o sentido do corte (correção pedida pelo usuário).

**Causa:** poses de punho em Euler reutilizavam a orientação do fio nos dois lados;
os ângulos laterais também varriam a ponta no sentido contrário ao gesto. O golpe
vertical conservava o plano horizontal da lâmina. Na geometria de `sword.glb`, o
comprimento é +Y e o fio afiado é -X (bisel converge a z=0 no lado -X).

**Correção:** orientações próprias para esquerda/direita/de cima em `espada.tres`;
SLERP dos punhos em `PoseDeCombate` evita voltas/inversões ao cruzar ±180°. As mãos,
pés, tronco e tempos mantêm seu contrato anterior. A varredura segue a mesma arma.

**Evidência:** `test_fio_espada_historia.gd` mede o produto escalar entre o fio físico
e a viagem transversal do centro da lâmina, quadro a quadro no ATIVO, com yaw 0°/90°.
Antes: esquerda mínimo -1,000 (dorso primeiro), vertical perto de 0 (face primeiro),
2/6 casos passaram. Depois: 6/6, mínimo ≥0,995 (~6°), com o deslocamento respeitando
o gesto. `test_espada_historia` também repete dano/defesa/inventário e cliques.
Logs e capturas: `art_src/validation/espada_historia_2026-10-06/direcao/`.

**Como detectar:** rodar ambos os testes. Dano correto sozinho não valida fio ou plano
de corte; capturar a lateral diferencia a lâmina horizontal do corte vertical.



## 2026-10-07 — montagem sem executor na entrada de combate

Durante a adição da sequência por cliques, conectar sinais em `montar` sem testar
executor nulo fez `test_entrada_corpo_a_corpo` imprimir erros de runtime mesmo
terminando com TUDO OK. O teste monta somente o leitor de gestos com executor
nulo; esse contrato continua válido. Correção: conectar sinais apenas quando
há executor, limpar sequência em cada montagem. Conferência: reler o log integral,
não só o contador final; regressões de entrada e sequência sem erros após o ajuste.


## 13/10/2026 — Coleta e encaixe da bicicleta Hie

- **Coleta parcial sem restauração:** a vegetação desligava `_process` quando a barra
  sumia; só árvores derrubadas tinham restauração. Agora a árvore ferida observa
  distância do lenhador mesmo após ocultar a barra e restaura três vidas ao sair
  de 3,5 m do tronco. Reserva no machado mantém um alvo e deduplica a ação.
  Detectar: `test_machado_madeira`, sensores sobrepostos, espera perto e afastamento.
- **Bicicleta com ciclista abaixo do selim (implementação):** pose de montaria aplicada
  sem alinhar o quadril à altura real do veículo. A captura expôs o problema;
  corrigido com encaixe no selim e IK nas mãos/pés. Centro real do colisor é 0,8 m,
  usado também para não enterrar o rastro no chão. Teste gráfico final 26/26.
- **Teste Hie antigo:** `test_hie_builder` espera 0,7 s totais no Z, mas a alteração
  de 10/10 prolonga o gelo entre salvas na história; medidos 1,72 s. Não mudar a regra
  aprovada para satisfazer esse teste. Testes específicos Z imunidade e V passam.
  Resultados e limites em `docs/MACHADO_BICICLETA_CHECKPOINT.md`.

## 13/10/2026 — Raça da campanha e validação das manobras

- **Raça perdida ao carregar:** `para_dict()` gravava `raca`, mas `de_dict()`
  nunca a lia. Corrigido com a lista humano/sharkman e fallback humano para campo
  ausente/inválido. Teste salva pela seleção real do status e recarrega do disco.
- **Barbatanas gigantes no rig atual:** reutilizar o catálogo antigo mediu a AABB
  dos descendentes do Torso, incluindo outras partes e adornos. Captura em execução
  expôs a proporção errada. A campanha usa `agua/visual_sharkman.gd`, com barbatanas
  em metros e encaixes nos ossos, e restaura os materiais ao retornar a Humano.
- **Teste de água falhou antes dos autoloads:** a nova assinatura com `j: Player`
  no componente `JogadorNaAgua` carregava Player cedo em sondas que citam a classe
  diretamente (`FruitNet` ainda não existia). A fronteira agora recebe `Node`;
  `--check-only --script tools/dev_tests/test_agua.gd` passou após a correção.
- **Sonda de nado ainda afundava:** guardar o item Fruta não desativa a Akuma;
  `fruta_em_uso()` consulta `fruta_ativa`. O teste racial isola a condição com
  `definir_fruta_ativa(false)`. Não alterar regras de fruta para esconder esse caso.
- **Referência antiga do traço de locomoção:** 462/492 quadros divergiram do arquivo
  esperado. Restaurar somente a expressão anterior de velocidade num projeto
  isolado gerou 492/492 quadros idênticos ao código final. Evidência em
  `art_src/validation/sharkman_manobras/{sharkman_traco_baseline,validar_traco_atual}.txt`.
  Não atualizar a referência automaticamente; a diferença antecede esta alteração.


## Magu Magu — integração e água (13/10/2026)

- **Onda visual passava pelo alvo sem dano:** a consulta de linha de visão partia exatamente da superfície do chão e a própria plataforma obstruía o raio. Origem elevada em 0,35 m para a onda; sonda pelo input passou de zero dano para 68,359, exatamente um acerto.
- **Placa solidificada gerava erro no quadro seguinte:** atribuía uma referência já liberada a uma variável tipada Node3D antes de validar. Verificação `is_instance_valid(placa.no)` agora precede a atribuição. Teste molha 100 placas e confirma remoção.
- **Teste não liberava poderes:** equipar a ficha diretamente não atualiza a capacidade dada pela progressão. A sonda passou a usar `progressao.comer_fruta`, como no jogo, e verifica energia/recarga além do efeito.
- **Captura com Compatibility acusava shader de contorno:** shader existente exige `hint_normal_roughness_texture`, disponível no Forward+. Capturas finais usam Forward+, sem modificar o contorno para acomodar um renderizador de teste inadequado.

Evidências: `art_src/validation/magu/funcional.log` e `historia_visual.log`.


## 14/10/2026 — revisão do modelo da fênix: dobra e deformação

- Sintomas durante a reconstrução: estalo ao abrir cotovelos; pontas das novas
  asas cortadas pelo chão; cintilação nas mechas mais finas.
- Causas: slerp da pose fechada diretamente para um alvo oscilante próximo de
  180° trocava o caminho do quaternion; teste antigo media apoio dos pés, mas
  não vértices das asas; deslocamento por normal excedia a espessura da mecha.
- Correções: transição até base fixa seguida da batida; ajuste da extensão das
  labaredas e dos ombros no repouso; onda comum a cada seção fechada, com os
  vértices das tampas compartilhando fase/ancoragem dos anéis.
- Evidência: teste do rig acusou 8 falhas na continuidade antes da correção;
  medição geométrica encontrou asas a -0,53 m em pé e -1,15 m sentadas no
  primeiro modelo desta revisão. Na entrega, test_phoenix_rig registra 0 falhas
  e valida também a folga do chão nas poses terrestres medidas.
- Reprodução e capturas: art_src/validation/phoenix_referencia_2026-10-14/.
  Esses números são da iteração desta tarefa, não uma medição do modelo antigo.


## 14/10/2026 — relevo marinho (docs/MAR_HISTORIA_PLANO.md, E1)

- **Fundo dos Macacos registrado na ilha inicial (latente desde 08/10):** os dois nós
  `FundoDoMar` ficavam na ORIGEM (a malha era escrita em coordenadas do mundo), e o
  `LodDasIlhas.registrar` decide a ilha de um nó pela `global_position`. O fundo dos
  Macacos entrava no "chão" da inicial: some/volta com a ilha errada. Correção: cada fundo
  é posicionado no centro da sua ilha e a geometria é local. Detectar:
  `test_relevo_marinho` ("posicionado na sua ilha").
- **Ruído "ridged" numa grade de 4 m vira quina:** a crista do ridged sobe ~0,5 em 4 m;
  com 4 m de amplitude, a colisão (interpolada entre amostras) errava até 2,7 m e havia
  degraus de 7 m entre vizinhos. Correção: rocha por manchas de simplex comum e ravinas
  como vales largos (|ruído| < 0,5). Detectar: `test_relevo_marinho` ("sem degrau",
  "interpolação").
- **Anéis concêntricos na areia (shader):** `fase = dot(pos, rumo(pos))` com o rumo
  variando pela posição cresce com a distância à origem e desenha círculos. Correção:
  direção fixa + domínio entortado por ruído.
- **Listras no fundo com sol baixo:** com a luz em faixas e o piso de sombra do mundo
  (0,16), qualquer ondulação de duna trocava de faixa. Não era geometria (diminuir as
  dunas não mudou a foto) nem sombra do oceano (ele não projeta). Correção no material
  do fundo: luz difusa de água (`sombra_min` 0,5, `suavidade` 0,16).
  Evidência: `art_src/validation/mar/medir_e1_*.png`.
- **Quadrados claros em volta do jogador mergulhando (E3, 14/10):** o `light()` em faixas
  usa `ATTENUATION` como teto de sombra; numa luz omni ela é a atenuação por DISTÂNCIA, e o
  piso (`sombra_min`) vazava para toda a área de tela do agrupamento do Forward+.
  Correção no `luz_cel.gdshaderinc`: só luz direcional usa o teto; omni/spot multiplica
  pela atenuação. O `cel.gdshader` ainda tem o vazamento (LISTA, item 75).
- **Bestas do mar não cabiam no mergulho (E5, 14/10):** o passeio das bestas vai a um
  ponto FIXO 100 m mar adentro (`populacao.pontos_da_costa`). O relevo novo pôs ali a
  plataforma rasa (11–13 m, decisão do dono) e as bestas têm 13–17 m: o corpo não submergia
  inteiro (`test_rotina_oceano_bestas` 29/32; A/B com o fundo antigo: 32/32). Correção: com o
  `RelevoMarinho`, o ponto segue para fora até ter água para o corpo inteiro (altura + 3 m:
  160–210 m); janela do teste 110 → 200 s. Detectar: `test_rotina_oceano_bestas`.
- **Peixes da loja não entram em MultiMesh direto (E6, 14/10):** têm esqueleto (malha crua de
  ~4 cm, o armature escala 100 e gira Y↔Z). `bake_mesh_from_current_skeleton_pose` falha
  ("skin registered with a valid skeleton": a skin só existe no servidor de renderização,
  nem dentro da árvore no headless). Na pose de repouso o skinning equivale à composição das
  transformações LOCAIS do nó da malha até a raiz — é o que `cardumes.gd` usa.
- **`get_shader_parameter` de uniforme nunca definido devolve null** (de novo, E5): o giro do
  redemoinho fazia `float(null)` a cada quadro. Guardar o valor no nó.
- **Cáusticas invisíveis (E7):** dois motivos somados — a escala (0,32/m dava células de
  3–6 m: claridade larga, não rede; medido fora do jogo) e o HDR (somar ~0,4 numa areia que
  passa de 2,0 em linear antes do tonemap quase não aparece). Escala 0,9/m, limiar nas
  linhas e força 2,8. Diagnóstico: modo de depuração pintando os fatores + diferença de
  pixel entre as duas capturas.
- **Projétil grande do Builder parado na saída (Cipó Branco, frutas Mine Piece, 17/10):** o
  acerto de 1,2 m nascendo a 1 m do chão encostava no piso; `collided_with_any` cravava o
  projétil no cenário no primeiro quadro (sonda: a zona ficou em z=−0,6 por 1,3 s, 0 acertos).
  Correção na skill: `raio_de_acerto` 0,7 com o desenho grande (o mesmo recurso da Pata
  Gigante). Regra: acerto ≤ altura de saída − folga. Detectar: `test_mine_piece`.
- **Linha "[F] F" no HUD de técnicas de toda fruta do Builder sem F (17/10):**
  `TecnicasHud._montar` perguntava só `pelo_builder(fruta, "F")`, que é verdadeiro para
  QUALQUER tecla de fruta do Builder. Agora exige `KitDoBuilder.tem("F", fruta)`.
- **Mancha clara em blocos no chão sob a explosão do Raio Pesado (17/10):** a luz omni da
  VFX "Explosão" (alcance 7 × escala) no ponto mirado longe; mesma família do vazamento omni
  do `cel.gdshader` (LISTA, item 75). Contorno na skill: escala < 1 (explosão sem luz).
  Evidência: `art_src/validation/mine_piece/pika_Z_2_acerto.png` (antes/depois nesta data).


## 20/10/2026 — Agachar: quina bloqueava a descida de degrau baixo

Na implementação do Ctrl agachar, a varredura descendente da cápsula encontrava
primeiro a quina lateral do bloco de cima, encerrando a consulta antes do piso
0,3 m abaixo. O jogador parava em x=2,35 m em vez de descer. A consulta agora
complementa esse contato com um raio sob o centro, limitado a meio bloco na
escala do corpo. `test_agachar.gd` mede x>3 m no degrau e mantém os controles
negativos de borda sem apoio, pulo e empurrão; resultado final 34/34.

A pose também mede as malhas da sola para acertar o apoio: a IK de dois ossos
sozinha ignorava tornozelo/dedos do rig detalhado. A sonda mede erro <0,01 m
entre sola e base física. Respawn limpa o agachar no próprio RPC, porque há
chamadas que não passam por `die_and_respawn`.

Regressão ampliada: câmera, parede, escalada, morte, rig, Q, caminhada e réplica
passaram. Compilação permanece com seis erros anteriores do editor de animação.
O teste da IA aquática tem 39/40 (alternância da bovina), reproduzido com o
agachar desativado; não corrigido nesta tarefa. O teste geral da água falhou
na primeira execução e passou com passo fixo tanto com quanto sem agachar;
sensibilidade do teste ao tempo/estado permanece por investigar.

## 2026-11-10 — "os inimigos aplicam empurrão mas a vida do jogador não diminui"
**Sintoma:** golpes de personagens do East Blue (mod) empurravam o jogador e davam efeitos, mas a vida nunca descia.
**Causa (medida, `McEntidade.hurt` instrumentado + trilha do `WhenEntityTakesDamageProcedure`):** em `Player.take_damage` o filtro de invulnerabilidade
do Minecraft (`KnockbackMinecraft.filtrar`, 0,5 s, "dano menor ou igual ao último é recusado") rodava ANTES dos eventos do mod. O golpe chega como
`minepiece:damage_curse` de ~19–29; o filtro o registrava como "último golpe". O handler do mod cancela esse golpe e REAPLICA um dano menor (~0,1–3, `damage_combat`)
dentro do mesmo evento; o filtro recusava a reaplicação ("menor ou igual ao último"). Nada entrava na vida; empurrão e efeitos do mod seguiam.
**Correção:** o filtro passou para DEPOIS dos eventos do mod (`ao_receber_dano` / `dano_final`) e avalia o dano FINAL. Antes: 0 golpes tiravam vida em 15 s; depois: 8–15 golpes,
alvida 32 → 25,8; arlong → 12,8; marinha → 20,1. Teste: `tools/dev_tests/test_dano_do_mod_no_jogador.gd`.
**Observações:** (1) o golpe do mod continua pequeno por desenho do próprio mod (reaplicação de 0,4–3 contra 32 de vida) — se parecer pouco, é calibragem, não bug;
(2) personagens do East Blue só miram o jogador conforme a facção/ódio do mod (provocados, trocavam o alvo para outros NPCs); (3) bandidos e animais nunca foram afetados.
**Armadilha:** teste com save novo (sem fruta) NÃO exercita o pipeline: só quem tem fruta do mod tem `JogadorDoMod`. Reproduzir com `fruta = aro_aro`.

## 2026-11-24 — HUD das técnicas escondia uma das duas "Yasakani Sacred Jewel" da Pika

**Sintoma.** O quadro de técnicas da Pika Pika (Mine Piece) mostrava 5 linhas (Z X B V N): a técnica da tecla C sumia.
**Causa raiz.** `TecnicasHud.atualizar_mine_piece` indexava as linhas pelo NOME da técnica; a Pika tem duas com o mesmo nome (24 e 29, custos 200 e 400), então a segunda sobrescrevia a primeira.
**Correção.** A chave da linha leva a tecla quando o nome se repete ("Yasakani Sacred Jewel (C)"). Conferido por captura (Weston isolado): as 6 linhas aparecem, cada uma com a própria recarga.
**Armadilha.** Chave de UI por nome de técnica só serve se o nome for único; qualquer fruta nova com golpes homônimos cairia no mesmo erro.
